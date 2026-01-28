module AbstractMachine
  module InstructionExecutor
    module LogicalOperations
      extend self

      # LOGICAL_AND
      # Logical AND of two boolean values
      # Stack Before: [... a, b]
      # Stack After: [... (a && b)]
      # Note: Values are coerced to boolean (falsy: null, false; truthy: all else)
      private def execute_logical_and(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "LOGICAL_AND")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(a.to_bool && b.to_bool)
        process.stack.push(result)

        result
      end

      # LOGICAL_OR
      # Logical OR of two boolean values
      # Stack Before: [... a, b]
      # Stack After: [... (a || b)]
      # Note: Values are coerced to boolean
      private def execute_logical_or(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "LOGICAL_OR")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(a.to_bool || b.to_bool)
        process.stack.push(result)

        result
      end

      # LOGICAL_NOT
      # Logical NOT of a boolean value
      # Stack Before: [... a]
      # Stack After: [... (!a)]
      # Note: Value is coerced to boolean
      private def execute_logical_not(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "LOGICAL_NOT")

        a = process.stack.pop

        result = Value::Context.new(!a.to_bool)
        process.stack.push(result)

        result
      end

      # LOGICAL_XOR
      # Logical XOR of two boolean values
      # Stack Before: [... a, b]
      # Stack After: [... (a ^^ b)]
      # Note: True if exactly one operand is truthy
      private def execute_logical_xor(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "LOGICAL_XOR")

        b = process.stack.pop
        a = process.stack.pop

        a_bool = a.to_bool
        b_bool = b.to_bool

        # XOR: true if exactly one is true (not both, not neither)
        result = Value::Context.new(a_bool != b_bool)
        process.stack.push(result)

        result
      end
    end
  end
end
