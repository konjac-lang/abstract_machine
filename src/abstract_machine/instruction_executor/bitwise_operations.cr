module AbstractMachine
  module InstructionExecutor
    module BitwiseOperations
      extend self

      # BITWISE_AND
      # Bitwise AND of two integer values
      # Stack Before: [... a, b]
      # Stack After: [... (a & b)]
      private def execute_bitwise_and(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BITWISE_AND")

        b = process.stack.pop
        a = process.stack.pop

        unless a.integer? || a.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_AND requires integer operands, got #{a.type}")
        end

        unless b.integer? || b.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_AND requires integer operands, got #{b.type}")
        end

        result = if a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 & b.to_u64)
                 else
                   Value::Context.new(a.to_i64 & b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # BITWISE_OR
      # Bitwise OR of two integer values
      # Stack Before: [... a, b]
      # Stack After: [... (a | b)]
      private def execute_bitwise_or(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BITWISE_OR")

        b = process.stack.pop
        a = process.stack.pop

        unless a.integer? || a.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_OR requires integer operands, got #{a.type}")
        end

        unless b.integer? || b.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_OR requires integer operands, got #{b.type}")
        end

        result = if a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 | b.to_u64)
                 else
                   Value::Context.new(a.to_i64 | b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # BITWISE_XOR
      # Bitwise XOR of two integer values
      # Stack Before: [... a, b]
      # Stack After: [... (a ^ b)]
      private def execute_bitwise_xor(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BITWISE_XOR")

        b = process.stack.pop
        a = process.stack.pop

        unless a.integer? || a.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_XOR requires integer operands, got #{a.type}")
        end

        unless b.integer? || b.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_XOR requires integer operands, got #{b.type}")
        end

        result = if a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 ^ b.to_u64)
                 else
                   Value::Context.new(a.to_i64 ^ b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # BITWISE_NOT
      # Bitwise NOT (complement) of integer value
      # Stack Before: [... a]
      # Stack After: [... (~a)]
      private def execute_bitwise_not(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "BITWISE_NOT")

        a = process.stack.pop

        unless a.integer? || a.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_NOT requires an integer operand, got #{a.type}")
        end

        result = if a.unsigned_integer?
                   Value::Context.new(~a.to_u64)
                 else
                   Value::Context.new(~a.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # BITWISE_SHIFT_LEFT
      # Shift bits left by specified count
      # Stack Before: [... value, count]
      # Stack After: [... (value << count)]
      private def execute_bitwise_shift_left(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BITWISE_SHIFT_LEFT")

        count = process.stack.pop
        value = process.stack.pop

        unless value.integer? || value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_SHIFT_LEFT requires integer value, got #{value.type}")
        end

        unless count.integer? || count.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_SHIFT_LEFT requires integer count, got #{count.type}")
        end

        shift_amount = count.to_i64.to_i32

        # Guard against negative or excessive shift amounts
        if shift_amount < 0
          raise Exceptions::Value.new("BITWISE_SHIFT_LEFT shift count cannot be negative")
        end

        if shift_amount >= 64
          # Shifting by 64 or more bits results in zero
          result = if value.unsigned_integer?
                     Value::Context.new(0_u64)
                   else
                     Value::Context.new(0_i64)
                   end
        else
          result = if value.unsigned_integer?
                     Value::Context.new(value.to_u64 << shift_amount)
                   else
                     Value::Context.new(value.to_i64 << shift_amount)
                   end
        end

        process.stack.push(result)
        result
      end

      # BITWISE_SHIFT_RIGHT
      # Arithmetic shift bits right by specified count (sign-extending)
      # Stack Before: [... value, count]
      # Stack After: [... (value >> count)]
      private def execute_bitwise_shift_right(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BITWISE_SHIFT_RIGHT")

        count = process.stack.pop
        value = process.stack.pop

        unless value.integer? || value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_SHIFT_RIGHT requires integer value, got #{value.type}")
        end

        unless count.integer? || count.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_SHIFT_RIGHT requires integer count, got #{count.type}")
        end

        shift_amount = count.to_i64.to_i32

        # Guard against negative shift amounts
        if shift_amount < 0
          raise Exceptions::Value.new("BITWISE_SHIFT_RIGHT shift count cannot be negative")
        end

        if shift_amount >= 64
          # Arithmetic shift: fills with sign bit
          result = if value.unsigned_integer?
                     Value::Context.new(0_u64)
                   else
                     # For signed, fill with sign bit (all 1s if negative, all 0s if positive)
                     Value::Context.new(value.to_i64 < 0 ? -1_i64 : 0_i64)
                   end
        else
          # Crystal's >> is arithmetic shift for signed integers
          result = if value.unsigned_integer?
                     Value::Context.new(value.to_u64 >> shift_amount)
                   else
                     Value::Context.new(value.to_i64 >> shift_amount)
                   end
        end

        process.stack.push(result)
        result
      end

      # BITWISE_SHIFT_RIGHT_UNSIGNED
      # Logical shift bits right by specified count (zero fill)
      # Stack Before: [... value, count]
      # Stack After: [... (value >>> count)]
      private def execute_bitwise_shift_right_unsigned(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BITWISE_SHIFT_RIGHT_UNSIGNED")

        count = process.stack.pop
        value = process.stack.pop

        unless value.integer? || value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_SHIFT_RIGHT_UNSIGNED requires integer value, got #{value.type}")
        end

        unless count.integer? || count.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BITWISE_SHIFT_RIGHT_UNSIGNED requires integer count, got #{count.type}")
        end

        shift_amount = count.to_i64.to_i32

        # Guard against negative shift amounts
        if shift_amount < 0
          raise Exceptions::Value.new("BITWISE_SHIFT_RIGHT_UNSIGNED shift count cannot be negative")
        end

        if shift_amount >= 64
          # Logical shift fills with zeros, so result is always 0
          result = Value::Context.new(0_u64)
        else
          # Convert to unsigned for logical shift, then shift
          unsigned_value = value.to_i64.to_u64!
          result = Value::Context.new(unsigned_value >> shift_amount)
        end

        process.stack.push(result)
        result
      end
    end
  end
end
