module AbstractMachine
  module Process
    # Manages creation and scheduling of processes
    class Manager
      Log = ::Log.for(self)

      # Next available process address
      @next_address : UInt64 = 1_u64

      def initialize(@engine : Engine::Context)
      end

      # Create a new process with its own instruction list
      # This enables true isolation: each process runs different code
      def create_process(
        instructions : Array(Instruction::Operation) = [] of Instruction::Operation,
        start_address : UInt64 = 0_u64,
      ) : Context
        process = Context.new(@next_address, instructions)
        @next_address += 1
        process.counter = start_address
        Log.debug { "Created new Process <#{process.address}>" }
        process
      end

      # All currently runnable processes
      def active_processes(exclude : Set(UInt64)) : Array(Context)
        @engine.processes
          .select { |process| process.state == State::ALIVE && !exclude.includes?(process.address) }
          .sort_by! { |process| -process.priority.value } # Higher priority first
      end

      # Waiting processes that now have matching messages
      def waiting_processes_ready(exclude : Set(UInt64)) : Array(Context)
        @engine.processes.select do |process|
          process.state == State::WAITING &&
            !process.mailbox.empty? &&
            !exclude.includes?(process.address)
        end
      end

      # Waiting processes whose timeout has expired
      def processes_with_expired_timeouts(exclude : Set(UInt64)) : Array(Context)
        @engine.processes.select do |process|
          process.state == State::WAITING &&
            process.wait_timed_out? &&
            !exclude.includes?(process.address)
        end
      end

      # Blocked processes that might now be able to send
      def blocked_processes_ready(exclude : Set(UInt64)) : Array(Context)
        @engine.processes.select do |process|
          process.state == State::BLOCKED &&
            process.blocked_sends.any? &&
            !exclude.includes?(process.address)
        end
      end

      # Execute instructions up to reduction limit per process (preemptive scheduling)
      def execute_active_processes(active : Array(Context), completed : Set(UInt64)) : Bool
        progress = false

        active.each do |process|
          process.reductions = 0_u64 # Reset reductions for this time slice

          max_reductions = case process.priority
                           when .low?    then @engine.configuration.max_reductions_per_slice // 4
                           when .normal? then @engine.configuration.max_reductions_per_slice
                           when .high?   then @engine.configuration.max_reductions_per_slice * 2
                           when .max?    then @engine.configuration.max_reductions_per_slice * 4
                           else               @engine.configuration.max_reductions_per_slice
                           end

          while process.reductions < max_reductions
            # Safety check: prevent out-of-bounds access
            if process.counter >= process.instructions.size
              process.state = State::DEAD
              completed.add(process.address)
              break
            end

            # Stop if process is no longer runnable (blocked on receive, etc.)
            break unless process.state == State::ALIVE

            instruction = process.instructions[process.counter]
            @engine.execute(process, instruction)
            progress = true

            if process.state == State::DEAD
              completed.add(process.address)
              break
            end
          end

          Log.debug { "Process <#{process.address}> yielded after #{process.reductions} reductions" } if process.reductions > 0
        end

        progress
      end

      # Resume processes that timed out on receive
      def handle_timeout_processes(timeouts : Array(Context)) : Bool
        return false if timeouts.empty?

        timeouts.each do |process|
          Log.debug { "Process <#{process.address}> RECEIVE timeout expired" }
          process.state = State::ALIVE
          process.waiting_for = nil
          process.waiting_since = nil
          process.waiting_timeout = nil
          process.stack.push(Value::Context.new(false)) # Indicate timeout
          @engine.queue_process_for_reactivation(process)
        end

        true
      end

      # Reactivate waiting processes that received messages
      def reactivate_waiting_processes(waiting : Array(Context)) : Bool
        return false if waiting.empty?

        waiting.each do |process|
          Log.debug { "Reactivating Process <#{process.address}> due to new message" }
          process.state = State::ALIVE
          process.waiting_for = nil
          process.waiting_since = nil
          process.waiting_timeout = nil
          @engine.queue_process_for_reactivation(process)
        end

        true
      end

      # Unblock processes that were blocked on full mailboxes
      def unblock_blocked_processes(blocked : Array(Context)) : Bool
        return false if blocked.empty?

        blocked.each do |process|
          Log.debug { "Unblocking Process <#{process.address}> (mailbox has space)" }
          process.state = State::ALIVE
          # Note: actual resend happens in Engine#check_blocked_sends
          @engine.queue_process_for_reactivation(process)
        end

        true
      end

      # Mark processes that reached end of code as dead
      def update_process_states(completed : Set(UInt64))
        @engine.processes.each do |process|
          if process.counter >= process.instructions.size && process.state == State::ALIVE
            Log.debug { "Process <#{process.address}> reached end of code" }
            process.state = State::DEAD
            completed.add(process.address)
          end
        end
      end

      def cleanup_expired_messages
        removed_total = 0
        @engine.processes.each do |process|
          removed = process.mailbox.cleanup_expired_messages
          removed_total += removed if removed > 0
        end
        Log.debug { "Cleaned up #{removed_total} expired messages across all mailboxes" } if removed_total > 0
      end

      # Proper deadlock detection using wait-for graph + cycle detection
      def detect_deadlock : Bool
        # Build directed graph: A → B means "A is waiting for B"
        graph = Hash(UInt64, Set(UInt64)).new { |h, k| h[k] = Set(UInt64).new }

        @engine.processes.each do |process|
          next unless process.state.waiting?

          process.dependencies.each do |target_address|
            graph[process.address] << target_address
          end
        end

        return false if graph.empty?

        visited = Set(UInt64).new
        recursion_stack = Set(UInt64).new

        # Use a block + local variable to avoid any shadowing issues
        detect_cycle = uninitialized Proc(UInt64, Bool)

        detect_cycle = ->(node : UInt64) : Bool do
          visited.add(node)
          recursion_stack.add(node)

          graph[node].each do |neighbor|
            if visited.includes?(neighbor)
              if recursion_stack.includes?(neighbor)
                Log.warn { "Deadlock cycle detected: Process <#{node}> is waiting on <#{neighbor}>" }
                return true
              end
            else
              return true if detect_cycle.call(neighbor)
            end
          end

          recursion_stack.delete(node)
          false
        end

        graph.keys.each do |node|
          next if visited.includes?(node)
          return true if detect_cycle.call(node)
        end

        false
      end

      # Debug helper: dump current VM state
      def dump_state : String
        {
          processes: @engine.processes.map { |process|
            {
              address:         process.address,
              state:           process.state.to_s,
              counter:         process.counter,
              code_size:       process.instructions.size,
              stack_size:      process.stack.size,
              mailbox_size:    process.mailbox.size,
              blocked_sends:   process.blocked_sends.size,
              registered_name: process.registered_name,
            }
          },
          next_address: @next_address,
        }.to_pretty_json
      end
    end
  end
end
