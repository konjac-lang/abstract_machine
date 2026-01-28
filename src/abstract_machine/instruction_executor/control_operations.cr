module AbstractMachine
  module InstructionExecutor
    module ControlOperations
      extend self

      # CONTROL_JUMP
      # Unconditional jump to absolute instruction address
      # Operand: Int64 (target address)
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_control_jump(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP requires an integer target address")
        end

        target = instruction.value.to_i64

        if target < 0 || target >= process.instructions.size
          raise Exceptions::InvalidJumpTarget.new(
            "CONTROL_JUMP to invalid address: #{target} (valid range: 0-#{process.instructions.size - 1})"
          )
        end

        process.counter = target.to_u64

        Value::Context.null
      end

      # CONTROL_JUMP_FORWARD
      # Jump forward by relative offset
      # Operand: UInt32 (forward offset)
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_control_jump_forward(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP_FORWARD requires an integer offset")
        end

        offset = instruction.value.to_i64

        if offset < 0
          raise Exceptions::Value.new("CONTROL_JUMP_FORWARD offset must be non-negative: #{offset}")
        end

        target = process.counter.to_i64 + offset

        if target >= process.instructions.size
          raise Exceptions::InvalidJumpTarget.new(
            "CONTROL_JUMP_FORWARD to invalid address: #{target} (max: #{process.instructions.size - 1})"
          )
        end

        process.counter = target.to_u64

        Value::Context.null
      end

      # CONTROL_JUMP_BACKWARD
      # Jump backward by relative offset
      # Operand: UInt32 (backward offset)
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_control_jump_backward(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP_BACKWARD requires an integer offset")
        end

        offset = instruction.value.to_i64

        if offset < 0
          raise Exceptions::Value.new("CONTROL_JUMP_BACKWARD offset must be non-negative: #{offset}")
        end

        target = process.counter.to_i64 - offset

        if target < 0
          raise Exceptions::InvalidJumpTarget.new(
            "CONTROL_JUMP_BACKWARD to invalid address: #{target} (min: 0)"
          )
        end

        process.counter = target.to_u64

        Value::Context.null
      end

      # CONTROL_JUMP_IF_TRUE
      # Jump if top of stack is truthy (consumes condition)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [...]
      private def execute_control_jump_if_true(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_JUMP_IF_TRUE")

        condition = process.stack.pop

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP_IF_TRUE requires an integer offset")
        end

        if condition.to_bool
          offset = instruction.value.to_i64
          target = process.counter.to_i64 + offset

          if target < 0 || target >= process.instructions.size
            raise Exceptions::InvalidJumpTarget.new(
              "CONTROL_JUMP_IF_TRUE to invalid address: #{target}"
            )
          end

          process.counter = target.to_u64
        end

        Value::Context.null
      end

      # CONTROL_JUMP_IF_FALSE
      # Jump if top of stack is falsy (consumes condition)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [...]
      private def execute_control_jump_if_false(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_JUMP_IF_FALSE")

        condition = process.stack.pop

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP_IF_FALSE requires an integer offset")
        end

        unless condition.to_bool
          offset = instruction.value.to_i64
          target = process.counter.to_i64 + offset

          if target < 0 || target >= process.instructions.size
            raise Exceptions::InvalidJumpTarget.new(
              "CONTROL_JUMP_IF_FALSE to invalid address: #{target}"
            )
          end

          process.counter = target.to_u64
        end

        Value::Context.null
      end

      # CONTROL_JUMP_IF_TRUE_KEEP
      # Jump if top of stack is truthy (keeps condition on stack)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [... condition]
      private def execute_control_jump_if_true_keep(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_JUMP_IF_TRUE_KEEP")

        condition = process.stack.last # Peek, don't pop

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP_IF_TRUE_KEEP requires an integer offset")
        end

        if condition.to_bool
          offset = instruction.value.to_i64
          target = process.counter.to_i64 + offset

          if target < 0 || target >= process.instructions.size
            raise Exceptions::InvalidJumpTarget.new(
              "CONTROL_JUMP_IF_TRUE_KEEP to invalid address: #{target}"
            )
          end

          process.counter = target.to_u64
        end

        condition
      end

      # CONTROL_JUMP_IF_FALSE_KEEP
      # Jump if top of stack is falsy (keeps condition on stack)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [... condition]
      private def execute_control_jump_if_false_keep(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_JUMP_IF_FALSE_KEEP")

        condition = process.stack.last # Peek, don't pop

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("CONTROL_JUMP_IF_FALSE_KEEP requires an integer offset")
        end

        unless condition.to_bool
          offset = instruction.value.to_i64
          target = process.counter.to_i64 + offset

          if target < 0 || target >= process.instructions.size
            raise Exceptions::InvalidJumpTarget.new(
              "CONTROL_JUMP_IF_FALSE_KEEP to invalid address: #{target}"
            )
          end

          process.counter = target.to_u64
        end

        condition
      end

      # CONTROL_CALL
      # Call a named subroutine
      # Operand: String (subroutine name)
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_control_call(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("CONTROL_CALL requires a string subroutine name")
        end

        subroutine_name = instruction.value.to_s
        subroutine = process.subroutines[subroutine_name]?

        unless subroutine
          raise Exceptions::UndefinedSubroutine.new("CONTROL_CALL subroutine not found: '#{subroutine_name}'")
        end

        # Save return address and frame pointer
        process.call_stack.push(process.counter)

        # Set up new frame
        saved_frame_pointer = process.frame_pointer
        process.frame_pointer = process.locals.size

        # Store saved frame pointer for restoration on return
        # (Could also push to call_stack or a separate frame stack)

        # Jump to subroutine
        process.counter = subroutine.start_address

        Value::Context.null
      end

      # CONTROL_CALL_DYNAMIC
      # Call subroutine by name from stack
      # Operand: None
      # Stack Before: [... subroutine_name]
      # Stack After: [...]
      private def execute_control_call_dynamic(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_CALL_DYNAMIC")

        name_value = process.stack.pop

        unless name_value.string? || name_value.symbol?
          raise Exceptions::TypeMismatch.new("CONTROL_CALL_DYNAMIC requires a string or symbol subroutine name")
        end

        subroutine_name = name_value.to_s
        subroutine = process.subroutines[subroutine_name]?

        unless subroutine
          raise Exceptions::UndefinedSubroutine.new("CONTROL_CALL_DYNAMIC subroutine not found: '#{subroutine_name}'")
        end

        # Save return address
        process.call_stack.push(process.counter)

        # Set up new frame
        process.frame_pointer = process.locals.size

        # Jump to subroutine
        process.counter = subroutine.start_address

        Value::Context.null
      end

      # CONTROL_CALL_INDIRECT
      # Call instruction array from stack
      # Operand: None
      # Stack Before: [... instructions]
      # Stack After: [...]
      private def execute_control_call_indirect(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_CALL_INDIRECT")

        instructions_value = process.stack.pop

        unless instructions_value.instructions? || instructions_value.lambda?
          raise Exceptions::TypeMismatch.new("CONTROL_CALL_INDIRECT requires instructions or lambda")
        end

        # Save current execution state
        process.call_stack.push(process.counter)

        # Save current instructions reference (need to restore on return)
        # This requires storing additional state - using a separate stack or encoding

        if instructions_value.lambda?
          lambda = instructions_value.to_lambda

          # Set up lambda environment
          process.current_closure = lambda
          lambda.captured_environment.each do |name, value|
            process.globals[name] = value
          end

          # Execute lambda instructions
          process.saved_instructions_stack ||= [] of Array(Instruction::Operation)
          process.saved_instructions_stack.not_nil!.push(process.instructions)
          process.instructions = lambda.instructions
        else
          instructions = instructions_value.to_instructions
          process.saved_instructions_stack ||= [] of Array(Instruction::Operation)
          process.saved_instructions_stack.not_nil!.push(process.instructions)
          process.instructions = instructions
        end

        process.frame_pointer = process.locals.size
        process.counter = 0_u64

        Value::Context.null
      end

      # CONTROL_CALL_BUILT_IN_FUNCTION - Call a built-in function
      # Operand: Array [module_name, function_name, arity]
      # Stack Before: [... arg1, arg2, ..., argN]
      # Stack After: [... result]
      private def execute_control_call_built_in_function(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        call_information = instruction.value.to_a
        module_name = call_information[0].to_s
        function_name = call_information[1].to_s
        arity = call_information[2].to_i64.to_i32

        check_stack_size(process, arity, "CONTROL_CALL_BUILT_IN_FUNCTION")

        arguments = [] of Value::Context
        arity.times { arguments.unshift(process.stack.pop) }

        result = @engine.call_built_in_function(process, module_name, function_name, arguments)
        process.stack.push(result)
        result
      end

      # CONTROL_RETURN
      # Return from subroutine to caller
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_control_return(process : Process::Context) : Value::Context
        process.counter += 1

        if process.call_stack.empty?
          # No caller - terminate process
          process.state = Process::State::DEAD
          return Value::Context.null
        end

        # Restore return address
        return_address = process.call_stack.pop

        # Restore saved instructions if we did indirect call
        if process.saved_instructions_stack && !process.saved_instructions_stack.not_nil!.empty?
          process.instructions = process.saved_instructions_stack.not_nil!.pop
          process.current_closure = nil
        end

        # Restore frame (truncate locals to frame pointer)
        # Note: This is simplified - a full implementation would restore the previous frame pointer
        process.counter = return_address

        Value::Context.null
      end

      # CONTROL_RETURN_VALUE
      # Return from subroutine with a value
      # Operand: None
      # Stack Before: [... return_value]
      # Stack After: [... return_value]
      private def execute_control_return_value(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "CONTROL_RETURN_VALUE")

        return_value = process.stack.pop

        if process.call_stack.empty?
          # No caller - terminate process, but keep return value accessible
          process.state = Process::State::DEAD
          process.stack.push(return_value)
          return return_value
        end

        # Restore return address
        return_address = process.call_stack.pop

        # Restore saved instructions if we did indirect call
        if process.saved_instructions_stack && !process.saved_instructions_stack.not_nil!.empty?
          process.instructions = process.saved_instructions_stack.not_nil!.pop
          process.current_closure = nil
        end

        # Push return value for caller
        process.stack.push(return_value)
        process.counter = return_address

        return_value
      end

      # CONTROL_HALT
      # Halt process execution cleanly
      # Operand: None
      # Stack Before: [...]
      # Stack After: N/A (process terminated)
      private def execute_control_halt(process : Process::Context) : Value::Context
        process.counter += 1
        process.state = Process::State::DEAD
        process.reason = Process::Reason::Context.normal

        Value::Context.null
      end

      # CONTROL_NO_OPERATION
      # Do nothing (placeholder instruction)
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_control_no_operation(process : Process::Context) : Value::Context
        process.counter += 1

        Value::Context.null
      end
    end
  end
end
