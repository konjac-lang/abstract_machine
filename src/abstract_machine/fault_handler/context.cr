module AbstractMachine
  module FaultHandler
    # Central handler for process faults and exit propagation
    class Context
      Log = ::Log.for(self)

      @engine : Engine::Context
      @pending_signals : Channel(Tuple(UInt64, Process::Signal::Context))
      @running : Bool

      def initialize(@engine : Engine::Context)
        @pending_signals = Channel(Tuple(UInt64, Process::Signal::Context)).new(1000)
        @running = false
      end

      # Start the fault handler in a fiber
      def start
        return if @running
        @running = true

        spawn do
          Log.debug { "Monitoring for signal handlers" }
          while @running
            begin
              select
              when signal = @pending_signals.receive
                target_process_id, exit_signal = signal
                deliver_signal(target_process_id, exit_signal)
              when timeout(100.milliseconds)
                # Check for any cleanup needed
              end
            rescue Channel::ClosedError
              break
            end
          end
          Log.debug { "Demonitoring the signal handlers" }
        end
      end

      # Stop the fault handler
      def stop
        @running = false
        @pending_signals.close
      end

      # Handle a process exit - propagate signals to linked/monitoring processes
      def handle_exit(process : Process::Context, reason : Process::Reason::Context)
        # Skip if already dead
        return if process.state == Process::State::DEAD

        Log.info { "FaultHandler: Process <#{process.address}> exited: #{reason.type}" }

        # Store exit reason on process and mark dead
        process.reason = reason

        # Mark the process dead in the scheduler
        @engine.scheduler.mark_dead(process)

        # Get linked processes and monitors
        linked, monitors = @engine.link_registry.cleanup(process.address)

        # Send exit signals to linked processes
        linked.each do |linked_process_id|
          signal = Process::Signal::Context.new(process.address, reason, Process::Signal::LinkType::Link)
          queue_signal(linked_process_id, signal)
        end

        # Send DOWN messages to monitoring processes
        monitors.each do |ref|
          down = Process::DownMessage.new(ref, process.address, reason)
          deliver_down_message(ref.watcher, down)
        end

        # Notify supervisor if any
        notify_supervisor(process.address, reason)

        # Unregister from process registry
        if name = process.registered_name
          @engine.process_registry.unregister(name)
        end
      end

      # Queue a signal for delivery
      private def queue_signal(target_process_id : UInt64, signal : Process::Signal::Context)
        @pending_signals.send({target_process_id, signal})
      rescue Channel::ClosedError
        Log.warn { "FaultHandler: Cannot queue signal, channel closed" }
      end

      # Deliver a signal to a process
      private def deliver_signal(target_process_id : UInt64, signal : Process::Signal::Context)
        process = @engine.processes.find { |actual_process| actual_process.address == target_process_id }
        return unless process
        return if process.state == Process::State::DEAD

        Log.debug { "FaultHandler: Delivering exit signal to <#{target_process_id}> from <#{signal.from}>" }

        # Check if process traps exits
        if @engine.link_registry.traps_exit?(target_process_id) && signal.reason.trappable?
          # Convert signal to message
          message = Message::Context.new(signal.from, signal.to_value)
          process.mailbox.push(message)

          # Wake up if waiting
          if process.state == Process::State::WAITING
            @engine.queue_process_for_reactivation(process)
          end

          Log.debug { "FaultHandler: Process <#{target_process_id}> trapped exit signal" }
        else
          # Kill the process - handle_exit will mark it dead in scheduler
          handle_exit(process, signal.reason)
        end
      end

      # Deliver a DOWN message to a monitoring process
      private def deliver_down_message(target_process_id : UInt64, down : Process::DownMessage)
        process = @engine.processes.find { |actual_process| actual_process.address == target_process_id }
        return unless process
        return if process.state == Process::State::DEAD

        message = Message::Context.new(down.process, down.to_value)
        process.mailbox.push(message)

        # Wake up if waiting
        if process.state == Process::State::WAITING
          @engine.queue_process_for_reactivation(process)
        end

        Log.debug { "FaultHandler: Delivered DOWN message to <#{target_process_id}>" }
      end

      # Notify supervisor of child exit
      private def notify_supervisor(process_id : UInt64, reason : Process::Reason::Context)
        if supervisor = @engine.supervisor_registry.find_supervisor_of(process_id)
          supervisor.handle_child_exit(process_id, reason)
        end
      end

      # Kill a process with a specific reason
      def kill_process(process_id : UInt64, reason : Process::Reason::Context)
        process = @engine.processes.find { |actual_process| actual_process.address == process_id }
        return unless process
        return if process.state == Process::State::DEAD

        process.state = Process::State::DEAD
        handle_exit(process, reason)
      end

      # Send an exit signal to a process (like Erlang's exit/2)
      def exit_process(from : UInt64, to : UInt64, reason : Process::Reason::Context)
        signal = Process::Signal::Context.new(from, reason, Process::Signal::LinkType::Link)
        queue_signal(to, signal)
      end
    end
  end
end
