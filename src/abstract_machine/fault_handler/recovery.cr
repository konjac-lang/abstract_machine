module AbstractMachine
  module FaultHandler
    # Error recovery strategies
    module Recovery
      # Attempt to recover a process that crashed
      def self.try_recover(engine : Engine::Context, process : Process::Context, exception : Exception) : Bool
        Log.for(self).debug { "Attempting recovery for <#{process.address}>: #{exception.message}" }

        # Check if process has an error handler subroutine
        if error_handler = process.subroutines["__error_handler__"]?
          begin
            # Push error info onto stack
            error_value = Value::Context.new({
              "type"    => Value::Context.new("exception"),
              "message" => Value::Context.new(exception.message || "unknown"),
              "counter" => Value::Context.new(process.counter.to_i64),
            } of String => Value::Context)

            process.stack.push(error_value)

            # Jump to error handler
            process.call_stack.push(process.counter)
            process.counter = error_handler.start_address
            process.state = Process::State::ALIVE

            Log.for(self).info { "Process <#{process.address}> recovered with error handler" }
            return true
          rescue
            Log.for(self).warn { "Error handler failed for <#{process.address}>" }
          end
        end

        false
      end

      # Create a crash dump for debugging
      def self.create_crash_dump(process : Process::Context, reason : Process::Reason::Context) : Dump
        Dump.new(process, reason)
      end
    end
  end
end
