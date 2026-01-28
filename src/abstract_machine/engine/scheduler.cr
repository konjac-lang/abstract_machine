module AbstractMachine
  class Scheduler
    Log = ::Log.for(self)

    # Priority-based run queues
    @run_queues : Hash(Process::Priority, Deque(Process::Context))

    # Processes waiting for messages (no timeout)
    @wait_queue : Set(Process::Context)

    # Processes waiting with timeout: {deadline, process}
    @timed_wait_queue : Array(Tuple(Time, Process::Context))

    # Blocked on full mailbox
    @blocked_queue : Set(Process::Context)

    def initialize(@engine : Engine::Context)
      @run_queues = {
        Process::Priority::Max    => Deque(Process::Context).new,
        Process::Priority::High   => Deque(Process::Context).new,
        Process::Priority::Normal => Deque(Process::Context).new,
        Process::Priority::Low    => Deque(Process::Context).new,
      }
      @wait_queue = Set(Process::Context).new
      @timed_wait_queue = [] of Tuple(Time, Process::Context)
      @blocked_queue = Set(Process::Context).new
    end

    # Add a new process to the scheduler
    def enqueue(process : Process::Context)
      case process.state
      when .alive?
        @run_queues[process.priority].push(process)
      when .waiting?
        if process.waiting_timeout
          deadline = Time.utc + process.waiting_timeout.not_nil!
          @timed_wait_queue << {deadline, process}
          @timed_wait_queue.sort_by! { |t, _| t } # Keep sorted by deadline
        else
          @wait_queue.add(process)
        end
      when .blocked?
        @blocked_queue.add(process)
      end
    end

    # Get next process to run (O(1) for each priority level)
    def next_runnable : Process::Context?
      Process::Priority.each do |priority|
        queue = @run_queues[priority]
        unless queue.empty?
          return queue.shift
        end
      end
      nil
    end

    # Move process to run queue
    def make_runnable(process : Process::Context)
      # Remove from other queues first
      @wait_queue.delete(process)
      @timed_wait_queue.reject! { |_, actual_process| actual_process.address == process.address }
      @blocked_queue.delete(process)

      process.state = Process::State::ALIVE
      process.waiting_for = nil
      process.waiting_since = nil
      process.waiting_timeout = nil

      @run_queues[process.priority].push(process)
      Log.debug { "Process <#{process.address}> now runnable" }
    end

    # Move process to wait queue (blocked on receive)
    def wait_for_message(process : Process::Context, pattern : Value::Context? = nil, timeout : Time::Span? = nil)
      process.state = Process::State::WAITING
      process.waiting_for = pattern
      process.waiting_since = Time.utc
      process.waiting_timeout = timeout

      if timeout
        deadline = Time.utc + timeout
        @timed_wait_queue << {deadline, process}
        @timed_wait_queue.sort_by! { |t, _| t }
      else
        @wait_queue.add(process)
      end

      Log.debug { "Process <#{process.address}> waiting for message" }
    end

    # Move process to blocked queue (mailbox full)
    def block_on_send(process : Process::Context)
      process.state = Process::State::BLOCKED
      @blocked_queue.add(process)
      Log.debug { "Process <#{process.address}> blocked on send" }
    end

    # Called when a message is delivered to a process
    def notify_message_delivered(process : Process::Context, message : Message::Context)
      # Check if process is waiting for this message
      if @wait_queue.includes?(process)
        if process.waiting_for.nil? || matches_pattern?(message.value, process.waiting_for.not_nil!)
          @wait_queue.delete(process)
          make_runnable(process)
        end
      end

      # Check timed wait queue
      @timed_wait_queue.each_with_index do |(_, actual_process), index|
        if actual_process.address == process.address
          if process.waiting_for.nil? || matches_pattern?(message.value, process.waiting_for.not_nil!)
            @timed_wait_queue.delete_at(index)
            make_runnable(process)
            break
          end
        end
      end
    end

    # Check and handle expired timeouts
    def check_timeouts : Array(Process::Context)
      now = Time.utc
      expired = [] of Process::Context

      while !@timed_wait_queue.empty? && @timed_wait_queue.first[0] <= now
        deadline, process = @timed_wait_queue.shift

        process.stack.push(Value::Context.new(false)) # Timeout indicator
        process.state = Process::State::ALIVE
        process.waiting_for = nil
        process.waiting_since = nil
        process.waiting_timeout = nil

        @run_queues[process.priority].push(process)
        expired << process

        Log.debug { "Process <#{process.address}> receive timeout expired" }
      end

      expired
    end

    # Check if blocked processes can now send
    def check_blocked : Array(Process::Context)
      unblocked = [] of Process::Context

      @blocked_queue.each do |process|
        process.blocked_sends.reject! do |target_address, message|
          target = @engine.processes.find { |actual_process| actual_process.address == target_address }

          if target && target.mailbox.size < @engine.configuration.max_mailbox_size
            if target.mailbox.push(message)
              process.remove_dependency(target_address)
              notify_message_delivered(target, message)
              true # Remove from blocked_sends
            else
              false
            end
          else
            false
          end
        end

        if process.blocked_sends.empty?
          unblocked << process
        end
      end

      unblocked.each do |process|
        @blocked_queue.delete(process)
        make_runnable(process)
      end

      unblocked
    end

    # Mark process as dead and remove from all queues
    def mark_dead(process : Process::Context)
      @run_queues.each_value { |q| q.reject! { |actual_process| actual_process.address == process.address } }
      @wait_queue.delete(process)
      @timed_wait_queue.reject! { |_, actual_process| actual_process.address == process.address }
      @blocked_queue.delete(process)

      Log.debug { "Process <#{process.address}> marked dead" }
    end

    # Re-enqueue a process that yielded (hit reduction limit)
    def yield_process(process : Process::Context)
      return unless process.state.alive?
      @run_queues[process.priority].push(process)
    end

    # Stats for debugging
    def stats : NamedTuple(run: Int32, wait: Int32, timed_wait: Int32, blocked: Int32)
      run_count = @run_queues.values.sum(&.size)
      {
        run:        run_count,
        wait:       @wait_queue.size,
        timed_wait: @timed_wait_queue.size,
        blocked:    @blocked_queue.size,
      }
    end

    # Check if any work remains
    def has_work? : Bool
      @run_queues.values.any? { |q| !q.empty? } ||
        !@wait_queue.empty? ||
        !@timed_wait_queue.empty? ||
        !@blocked_queue.empty?
    end

    private def matches_pattern?(value : Value::Context, pattern : Value::Context) : Bool
      @engine.processes.first?.try(&.mailbox.matches_pattern?(value, pattern)) || false
    end
  end
end
