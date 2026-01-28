module AbstractMachine
  module InstructionExecutor
    module ExceptionHandlingOperations
      extend self

      # EXCEPTION_THROW
      # Throw an exception
      # Stack Before: [... error_value]
      # Stack After: N/A (unwinds stack)
      private def execute_exception_throw(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "EXCEPTION_THROW")

        error_value = process.stack.pop

        # Build exception object if not already structured
        exception_value = if error_value.map? && error_value.to_h.has_key?("type")
                            error_value
                          else
                            build_exception_value(error_value, process)
                          end

        # Try to find an exception handler
        if handler = process.exception_handlers.pop?
          unwind_to_handler(process, handler, exception_value)
        else
          # No handler - process terminates with exception
          process.state = Process::State::DEAD
          reason = Process::Reason::Context.exception(exception_value)

          # Notify fault handler
          @engine.fault_handler.handle_exit(process, reason)

          raise Exceptions::Unhandled.new("Unhandled exception: #{exception_value}")
        end

        Value::Context.null
      end

      # EXCEPTION_RETHROW
      # Re-throw the current exception in a catch block
      # Stack Before: [...]
      # Stack After: N/A (continues unwinding)
      private def execute_exception_rethrow(process : Process::Context) : Value::Context
        process.counter += 1

        # Get current exception from process context
        exception_value = process.current_exception

        unless exception_value
          raise Exceptions::Runtime.new("EXCEPTION_RETHROW called outside of catch block")
        end

        # Try to find next exception handler
        if handler = process.exception_handlers.pop?
          unwind_to_handler(process, handler, exception_value)
        else
          # No handler - process terminates
          process.state = Process::State::DEAD
          reason = Process::Reason::Context.exception(exception_value)

          @engine.fault_handler.handle_exit(process, reason)

          raise Exceptions::Unhandled.new("Unhandled rethrown exception: #{exception_value}")
        end

        Value::Context.null
      end

      # EXCEPTION_TRY_BEGIN
      # Begin a try block
      # Operand: Int64 (offset to catch block)
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_exception_try_begin(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("EXCEPTION_TRY_BEGIN requires an integer catch offset")
        end

        catch_offset = instruction.value.to_i64
        catch_address = (process.counter.to_i64 + catch_offset).to_u64

        # Validate catch address
        if catch_address >= process.instructions.size.to_u64
          raise Exceptions::InvalidJumpTarget.new(
            "EXCEPTION_TRY_BEGIN catch address #{catch_address} out of bounds"
          )
        end

        # Push exception handler
        handler = Exceptions::Handler.new(
          catch_address: catch_address,
          stack_size: process.stack.size,
          call_stack_size: process.call_stack.size,
          locals_size: process.locals.size,
          frame_pointer: process.frame_pointer
        )

        process.exception_handlers.push(handler)

        Value::Context.null
      end

      # EXCEPTION_TRY_END
      # End a try block (normal exit)
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_exception_try_end(process : Process::Context) : Value::Context
        process.counter += 1

        if process.exception_handlers.empty?
          raise Exceptions::Runtime.new("EXCEPTION_TRY_END without matching EXCEPTION_TRY_BEGIN")
        end

        # Pop the handler (try block completed normally)
        process.exception_handlers.pop

        # Clear current exception if we were in a catch block
        process.current_exception = nil

        Value::Context.null
      end

      # EXCEPTION_CATCH
      # Entry point for catch block
      # Stack Before: N/A (exception context)
      # Stack After: [... exception_value]
      private def execute_exception_catch(process : Process::Context) : Value::Context
        process.counter += 1

        # Exception value is already on the stack from unwind_to_handler
        # Store it in process context for potential rethrow
        if !process.stack.empty?
          process.current_exception = process.stack.last
        end

        Value::Context.null
      end

      # EXCEPTION_GET_STACKTRACE
      # Get current stack trace as array
      # Stack Before: [...]
      # Stack After: [... stacktrace_array]
      private def execute_exception_get_stacktrace(process : Process::Context) : Value::Context
        process.counter += 1

        stacktrace = build_stacktrace(process)

        result = Value::Context.new(stacktrace)
        process.stack.push(result)

        result
      end

      # Handle a Crystal exception that occurred during execution
      def handle_crystal_exception(process : Process::Context, exception : Exception) : Bool
        exception_value = build_exception_value_from_crystal(exception, process)

        if handler = process.exception_handlers.pop?
          unwind_to_handler(process, handler, exception_value)
          true
        else
          false
        end
      end

      # Unwind stack to exception handler
      private def unwind_to_handler(
        process : Process::Context,
        handler : Exceptions::Handler,
        exception_value : Value::Context,
      )
        # Restore stack to handler's saved size
        while process.stack.size > handler.stack_size
          process.stack.pop
        end

        # Restore call stack
        while process.call_stack.size > handler.call_stack_size
          process.call_stack.pop
        end

        # Restore locals
        while process.locals.size > handler.locals_size
          process.locals.pop
        end

        # Restore frame pointer
        process.frame_pointer = handler.frame_pointer

        # Restore saved instructions if we were in indirect call
        if process.saved_instructions_stack && process.saved_instructions_stack.not_nil!.size > handler.call_stack_size
          while process.saved_instructions_stack.not_nil!.size > handler.call_stack_size
            process.instructions = process.saved_instructions_stack.not_nil!.pop
          end
        end

        # Push exception value for catch block
        process.stack.push(exception_value)

        # Store current exception for potential rethrow
        process.current_exception = exception_value

        # Jump to catch block
        process.counter = handler.catch_address

        # Ensure process is alive
        process.state = Process::State::ALIVE
      end

      # Build exception value from any value
      private def build_exception_value(error_value : Value::Context, process : Process::Context) : Value::Context
        exception_map = Hash(String, Value::Context).new

        exception_map["type"] = Value::Context.new(:exception)

        if error_value.string?
          exception_map["message"] = error_value
          exception_map["error"] = Value::Context.new(:error)
        elsif error_value.symbol?
          exception_map["message"] = Value::Context.new(error_value.to_symbol.to_s)
          exception_map["error"] = error_value
        elsif error_value.map?
          # Merge in existing map data
          error_value.to_h.each do |key, value|
            exception_map[key] = value
          end
          exception_map["message"] ||= Value::Context.new("Unknown error")
        else
          exception_map["message"] = Value::Context.new(error_value.to_s)
          exception_map["error"] = Value::Context.new(:error)
        end

        # Add stacktrace
        exception_map["stacktrace"] = Value::Context.new(build_stacktrace(process))

        # Add process info
        exception_map["process"] = Value::Context.new(process.address.to_i64)
        exception_map["counter"] = Value::Context.new(process.counter.to_i64)

        Value::Context.new(exception_map)
      end

      # Build exception value from Crystal exception
      def build_exception_value_from_crystal(exception : Exception, process : Process::Context) : Value::Context
        exception_map = Hash(String, Value::Context).new

        exception_map["type"] = Value::Context.new(:exception)
        exception_map["message"] = Value::Context.new(exception.message || "Unknown error")
        exception_map["error"] = Value::Context.new(exception.class.name)

        # Add AbstractMachine stacktrace
        exception_map["stacktrace"] = Value::Context.new(build_stacktrace(process))

        # Add Crystal backtrace if available
        if bt = exception.backtrace?
          crystal_trace = bt.first(10).map { |line| Value::Context.new(line).as(Value::Context) }
          exception_map["crystal_backtrace"] = Value::Context.new(crystal_trace)
        end

        exception_map["process"] = Value::Context.new(process.address.to_i64)
        exception_map["counter"] = Value::Context.new(process.counter.to_i64)

        Value::Context.new(exception_map)
      end

      # Build stacktrace array
      def build_stacktrace(process : Process::Context) : Array(Value::Context)
        trace = [] of Value::Context

        # Current location
        trace << build_stack_frame(process.counter, process.instructions, nil)

        # Call stack frames
        process.call_stack.reverse_each do |return_address|
          trace << build_stack_frame(return_address, process.instructions, nil)
        end

        trace
      end

      # Build a single stack frame entry
      def build_stack_frame(
        address : UInt64,
        instructions : Array(Instruction::Operation),
        subroutine_name : String?,
      ) : Value::Context
        frame = Hash(String, Value::Context).new

        frame["address"] = Value::Context.new(address.to_i64)

        # Try to get instruction info at address
        if address < instructions.size
          instruction = instructions[address]
          frame["instruction"] = Value::Context.new(instruction.code.to_s)
        end

        if subroutine_name
          frame["function"] = Value::Context.new(subroutine_name)
        end

        Value::Context.new(frame)
      end
    end
  end
end
