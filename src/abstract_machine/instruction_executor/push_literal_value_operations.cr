module AbstractMachine
  module InstructionExecutor
    module PushLiteralValueOperations
      extend self

      # PUSH_NULL
      # Push a null value onto the stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... null]
      private def execute_push_null(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_capacity(process)

        value = Value::Context.null
        process.stack.push(value)

        value
      end

      # PUSH_BOOLEAN_TRUE
      # Push boolean true onto the stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... true]
      private def execute_push_boolean_true(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_capacity(process)

        value = Value::Context.new(true)
        process.stack.push(value)

        value
      end

      # PUSH_BOOLEAN_FALSE
      # Push boolean false onto the stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... false]
      private def execute_push_boolean_false(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_capacity(process)

        value = Value::Context.new(false)
        process.stack.push(value)

        value
      end

      # PUSH_INTEGER
      # Push a signed 64-bit integer onto the stack
      # Operand: Int64
      # Stack Before: [...]
      # Stack After: [... integer]
      private def execute_push_integer(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer?
          raise Exceptions::TypeMismatch.new("PUSH_INTEGER requires an integer operand")
        end

        check_stack_capacity(process)

        value = Value::Context.new(instruction.value.to_i64)
        process.stack.push(value)

        value
      end

      # PUSH_UNSIGNED_INTEGER
      # Push an unsigned 64-bit integer onto the stack
      # Operand: UInt64
      # Stack Before: [...]
      # Stack After: [... unsigned_integer]
      private def execute_push_unsigned_integer(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PUSH_UNSIGNED_INTEGER requires an unsigned integer operand")
        end

        check_stack_capacity(process)

        value = Value::Context.new(instruction.value.to_u64)
        process.stack.push(value)

        value
      end

      # PUSH_FLOAT
      # Push a 64-bit floating point number onto the stack
      # Operand: Float64
      # Stack Before: [...]
      # Stack After: [... float]
      private def execute_push_float(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.float?
          raise Exceptions::TypeMismatch.new("PUSH_FLOAT requires a float operand")
        end

        check_stack_capacity(process)

        value = Value::Context.new(instruction.value.to_f64)
        process.stack.push(value)

        value
      end

      # PUSH_STRING
      # Push a string value onto the stack
      # Operand: String
      # Stack Before: [...]
      # Stack After: [... string]
      private def execute_push_string(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("PUSH_STRING requires a string operand")
        end

        check_stack_capacity(process)

        value = Value::Context.new(instruction.value.to_s)
        process.stack.push(value)

        value
      end

      # PUSH_SYMBOL
      # Push a symbol (interned string) onto the stack
      # Operand: String (the symbol name)
      # Stack Before: [...]
      # Stack After: [... symbol]
      private def execute_push_symbol(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string? || instruction.value.symbol?
          raise Exceptions::TypeMismatch.new("PUSH_SYMBOL requires a string or symbol operand")
        end

        check_stack_capacity(process)

        value = Value::Context.new(instruction.value.to_symbol)
        process.stack.push(value)

        value
      end

      # PUSH_CUSTOM
      # Push a custom/user-defined value onto the stack
      # Operand: Any (custom value)
      # Stack Before: [...]
      # Stack After: [... custom_value]
      private def execute_push_custom(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_capacity(process)

        value = if instruction.value.is_a?(Value::Context)
                  instruction.value
                else
                  Value::Context.new(instruction.value)
                end

        process.stack.push(value)

        value
      end

      # PUSH_INSTRUCTIONS
      # Push an instruction array (code block) onto the stack
      # Operand: Array(Instruction::Operation)
      # Stack Before: [...]
      # Stack After: [... instructions]
      private def execute_push_instructions(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("PUSH_INSTRUCTIONS requires an instruction array operand")
        end

        check_stack_capacity(process)
        process.stack.push(instruction.value)

        instruction.value
      end
    end
  end
end
