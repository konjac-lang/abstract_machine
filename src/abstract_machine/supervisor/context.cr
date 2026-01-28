module AbstractMachine
  module Supervisor
    # Supervisor manages a set of child processes according to a restart strategy
    class Context
      Log = ::Log.for(self)

      getter address : UInt64
      getter strategy : RestartStrategy
      getter max_restarts : Int32
      getter restart_window : Time::Span
      getter children : Array(Tuple(Child::Specification, UInt64?)) # (specification, current_process_id)
      getter restart_histories : Hash(String, RestartHistory)

      @engine : Engine::Context
      @start_order : Array(String) # Track order for RestForOne

      def initialize(
        @engine : Engine::Context,
        @address : UInt64,
        @strategy : RestartStrategy = RestartStrategy::OneForOne,
        @max_restarts : Int32 = 3,
        @restart_window : Time::Span = 5.seconds,
      )
        @children = [] of Tuple(Child::Specification, UInt64?)
        @restart_histories = {} of String => RestartHistory
        @start_order = [] of String
      end

      # Add a child specification
      def add_child(specification : Child::Specification) : UInt64?
        @restart_histories[specification.id] = RestartHistory.new(specification)

        # Start the child
        process_id = start_child(specification)

        if process_id
          @children << {specification, process_id}
          @start_order << specification.id
          Log.info { "Supervisor <#{@address}>: Started child '#{specification.id}' as <#{process_id}>" }
        else
          @children << {specification, nil}
          Log.error { "Supervisor <#{@address}>: Failed to start child '#{specification.id}'" }
        end

        process_id
      end

      # Start a child process from its specification
      private def start_child(specification : Child::Specification) : UInt64?
        process = @engine.create_process(
          instructions: specification.instructions.map(&.clone)
        )

        # Copy subroutines and globals
        specification.subroutines.each { |name, subroutine| process.subroutines[name] = subroutine }
        specification.globals.each { |name, value| process.globals[name] = value.clone }

        # Link supervisor to child
        @engine.link_registry.link(@address, process.address)

        # Register the process
        @engine.processes << process

        process.address
      rescue ex
        Log.error { "Failed to start child '#{specification.id}': #{ex.message}" }
        nil
      end

      # Handle a child exit
      def handle_child_exit(process_id : UInt64, reason : Process::Reason::Context) : Bool
        # Find the child
        child_index = @children.index { |(specification, current_process_id)| current_process_id == process_id }
        return false unless child_index

        specification, _ = @children[child_index]
        @children[child_index] = {specification, nil}

        Log.info { "Supervisor <#{@address}>: Child '#{specification.id}' <#{process_id}> exited: #{reason.type}" }

        # Determine if we should restart
        should_restart = case specification.restart
                         when .permanent?
                           true
                         when .transient?
                           !reason.normal?
                         when .temporary?
                           false
                         else
                           false
                         end

        unless should_restart
          Log.debug { "Supervisor <#{@address}>: Not restarting '#{specification.id}' (restart=#{specification.restart}, reason=#{reason.type})" }
          return true
        end

        # Check restart limits
        history = @restart_histories[specification.id]
        unless history.record_restart
          Log.error { "Supervisor <#{@address}>: Child '#{specification.id}' exceeded restart limit (#{specification.max_restarts} in #{specification.restart_window})" }
          handle_restart_limit_exceeded(specification.id)
          return false
        end

        # Apply restart strategy
        case @strategy
        when .one_for_one?, .simple_one_for_one?
          restart_one(child_index)
        when .one_for_all?
          restart_all
        when .rest_for_one?
          restart_from(child_index)
        end

        true
      end

      # Restart a single child
      private def restart_one(index : Int32)
        specification, _ = @children[index]

        if new_process_id = start_child(specification)
          @children[index] = {specification, new_process_id}
          Log.info { "Supervisor <#{@address}>: Restarted child '#{specification.id}' as <#{new_process_id}>" }
        else
          Log.error { "Supervisor <#{@address}>: Failed to restart child '#{specification.id}'" }
        end
      end

      # Restart all children (for one_for_all strategy)
      private def restart_all
        Log.info { "Supervisor <#{@address}>: Restarting all children" }

        # Stop all children in reverse order
        @children.reverse_each do |(specification, process_id)|
          if process_id
            terminate_child(process_id, specification)
          end
        end

        # Clear current pids
        @children = @children.map { |(specification, _)| {specification, nil.as(UInt64?)} }

        # Restart all in original order
        @children.each_with_index do |(specification, _), i|
          if new_process_id = start_child(specification)
            @children[i] = {specification, new_process_id}
            Log.info { "Supervisor <#{@address}>: Restarted child '#{specification.id}' as <#{new_process_id}>" }
          end
        end
      end

      # Restart from a specific index (for rest_for_one strategy)
      private def restart_from(start_index : Int32)
        Log.info { "Supervisor <#{@address}>: Restarting children from index #{start_index}" }

        # Stop children from start_index to end in reverse order
        ((start_index...@children.size).to_a.reverse).each do |i|
          specification, process_id = @children[i]
          if process_id
            terminate_child(process_id, specification)
          end
          @children[i] = {specification, nil}
        end

        # Restart from start_index to end
        (start_index...@children.size).each do |i|
          specification, _ = @children[i]
          if new_process_id = start_child(specification)
            @children[i] = {specification, new_process_id}
            Log.info { "Supervisor <#{@address}>: Restarted child '#{specification.id}' as <#{new_process_id}>" }
          end
        end
      end

      # Terminate a child process
      private def terminate_child(process_id : UInt64, specification : Child::Specification)
        process = @engine.processes.find { |actual_process| actual_process.address == process_id }
        return unless process

        case specification.shutdown
        when .brutal?
          process.state = Process::State::DEAD
          process.reason = Process::Reason::Context.kill
        when .timeout?
          # Send shutdown signal and wait
          signal_shutdown(process)
          wait_for_exit(process, specification.shutdown_timeout)
        when .infinity?
          signal_shutdown(process)
          # Wait forever (or until process dies)
          while process.state != Process::State::DEAD
            sleep 10.milliseconds
          end
        end

        Log.debug { "Supervisor <#{@address}>: Terminated child '#{specification.id}' <#{process_id}>" }
      end

      # Signal a process to shut down gracefully
      private def signal_shutdown(process : Process::Context)
        # Send a shutdown message
        message = Message::Context.new(
          @address,
          Value::Context.new({
            "signal" => Value::Context.new("shutdown"),
            "from"   => Value::Context.new(@address.to_i64),
          } of String => Value::Context)
        )
        process.mailbox.push(message)
      end

      # Wait for a process to exit with timeout
      private def wait_for_exit(process : Process::Context, timeout : Time::Span)
        deadline = Time.utc + timeout
        while process.state != Process::State::DEAD && Time.utc < deadline
          sleep 10.milliseconds
        end

        # Force kill if still alive
        if process.state != Process::State::DEAD
          process.state = Process::State::DEAD
          process.reason = Process::Reason::Context.kill
        end
      end

      # Handle when a child exceeds its restart limit
      private def handle_restart_limit_exceeded(child_id : String)
        case @strategy
        when .one_for_one?, .simple_one_for_one?
          # Just log, child remains dead
          Log.warn { "Supervisor <#{@address}>: Child '#{child_id}' will not be restarted" }
        when .one_for_all?, .rest_for_one?
          # Supervisor itself should fail
          Log.error { "Supervisor <#{@address}>: Shutting down due to restart limit exceeded" }
          shutdown
        end
      end

      # Shut down the supervisor and all children
      def shutdown
        Log.info { "Supervisor <#{@address}>: Shutting down" }

        @children.reverse_each do |(specification, process_id)|
          if process_id
            terminate_child(process_id, specification)
          end
        end

        @children.clear
        @restart_histories.clear
        @start_order.clear
      end

      # Get the process_id of a child by id
      def whereis(child_id : String) : UInt64?
        @children.find { |(specification, _)| specification.id == child_id }.try { |(_, process_id)| process_id }
      end

      # Get count of running children
      def running_children : Int32
        @children.count { |(_, process_id)| process_id != nil }
      end

      # Get status of all children
      def child_status : Array(NamedTuple(id: String, process_id: UInt64?, restarts: Int32))
        @children.map do |(specification, process_id)|
          history = @restart_histories[specification.id]?
          {
            id:         specification.id,
            process_id: process_id,
            restarts:   history.try(&.restart_count) || 0,
          }
        end
      end
    end
  end
end
