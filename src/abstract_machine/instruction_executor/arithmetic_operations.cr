module AbstractMachine
  module InstructionExecutor
    module ArithmeticOperations
      extend self

      # ARITHMETIC_ADD
      # Add two numeric values
      # Stack Before: [... a, b]
      # Stack After: [... (a + b)]
      private def execute_arithmetic_add(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_ADD")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_ADD requires two numeric values")
        end

        result = if a.float? || b.float?
                   Value::Context.new(a.to_f64 + b.to_f64)
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 + b.to_u64)
                 else
                   Value::Context.new(a.to_i64 + b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_SUBTRACT
      # Subtract top value from second value
      # Stack Before: [... a, b]
      # Stack After: [... (a - b)]
      private def execute_arithmetic_subtract(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_SUBTRACT")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_SUBTRACT requires two numeric values")
        end

        result = if a.float? || b.float?
                   Value::Context.new(a.to_f64 - b.to_f64)
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 - b.to_u64)
                 else
                   Value::Context.new(a.to_i64 - b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_MULTIPLY
      # Multiply two numeric values
      # Stack Before: [... a, b]
      # Stack After: [... (a * b)]
      private def execute_arithmetic_multiply(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_MULTIPLY")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_MULTIPLY requires two numeric values")
        end

        result = if a.float? || b.float?
                   Value::Context.new(a.to_f64 * b.to_f64)
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 * b.to_u64)
                 else
                   Value::Context.new(a.to_i64 * b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_DIVIDE
      # Divide second value by top value
      # Stack Before: [... a, b]
      # Stack After: [... (a / b)]
      private def execute_arithmetic_divide(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_DIVIDE")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_DIVIDE requires two numeric values")
        end

        # Check for division by zero
        is_zero = if b.float?
                    b.to_f64 == 0.0
                  elsif b.unsigned_integer?
                    b.to_u64 == 0
                  else
                    b.to_i64 == 0
                  end

        if is_zero
          raise Exceptions::DivisionByZero.new("ARITHMETIC_DIVIDE division by zero")
        end

        result = if a.float? || b.float?
                   Value::Context.new(a.to_f64 / b.to_f64)
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 // b.to_u64)
                 else
                   Value::Context.new(a.to_i64 // b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_MODULO
      # Compute remainder of second value divided by top value
      # Stack Before: [... a, b]
      # Stack After: [... (a % b)]
      private def execute_arithmetic_modulo(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_MODULO")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_MODULO requires two numeric values")
        end

        # Check for modulo by zero
        is_zero = if b.float?
                    b.to_f64 == 0.0
                  elsif b.unsigned_integer?
                    b.to_u64 == 0
                  else
                    b.to_i64 == 0
                  end

        if is_zero
          raise Exceptions::DivisionByZero.new("ARITHMETIC_MODULO modulo by zero")
        end

        result = if a.float? || b.float?
                   Value::Context.new(a.to_f64 % b.to_f64)
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(a.to_u64 % b.to_u64)
                 else
                   Value::Context.new(a.to_i64 % b.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_NEGATE
      # Negate the top numeric value (unary minus)
      # Stack Before: [... a]
      # Stack After: [... (-a)]
      private def execute_arithmetic_negate(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_NEGATE")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_NEGATE requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(-a.to_f64)
                 elsif a.unsigned_integer?
                   # Negating unsigned converts to signed
                   Value::Context.new(-a.to_i64)
                 else
                   Value::Context.new(-a.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_ABSOLUTE
      # Compute absolute value of top numeric value
      # Stack Before: [... a]
      # Stack After: [... |a|]
      private def execute_arithmetic_absolute(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_ABSOLUTE")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_ABSOLUTE requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(a.to_f64.abs)
                 elsif a.unsigned_integer?
                   # Unsigned is already non-negative
                   Value::Context.new(a.to_u64)
                 else
                   Value::Context.new(a.to_i64.abs)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_INCREMENT
      # Add 1 to the top numeric value
      # Stack Before: [... a]
      # Stack After: [... (a + 1)]
      private def execute_arithmetic_increment(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_INCREMENT")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_INCREMENT requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(a.to_f64 + 1.0)
                 elsif a.unsigned_integer?
                   Value::Context.new(a.to_u64 + 1)
                 else
                   Value::Context.new(a.to_i64 + 1)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_DECREMENT
      # Subtract 1 from the top numeric value
      # Stack Before: [... a]
      # Stack After: [... (a - 1)]
      private def execute_arithmetic_decrement(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_DECREMENT")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_DECREMENT requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(a.to_f64 - 1.0)
                 elsif a.unsigned_integer?
                   Value::Context.new(a.to_u64 - 1)
                 else
                   Value::Context.new(a.to_i64 - 1)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_POWER
      # Raise second value to the power of top value
      # Stack Before: [... base, exponent]
      # Stack After: [... (base ** exponent)]
      private def execute_arithmetic_power(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_POWER")

        exponent = process.stack.pop
        base = process.stack.pop

        unless base.numeric? && exponent.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_POWER requires two numeric values")
        end

        # Power operation always uses float for precision
        result = Value::Context.new(base.to_f64 ** exponent.to_f64)

        process.stack.push(result)
        result
      end

      # ARITHMETIC_FLOOR
      # Round down to nearest integer (toward negative infinity)
      # Stack Before: [... a]
      # Stack After: [... floor(a)]
      private def execute_arithmetic_floor(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_FLOOR")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_FLOOR requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(a.to_f64.floor.to_i64)
                 elsif a.unsigned_integer?
                   # Integer floor is itself
                   Value::Context.new(a.to_u64)
                 else
                   # Integer floor is itself
                   Value::Context.new(a.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_CEILING
      # Round up to nearest integer (toward positive infinity)
      # Stack Before: [... a]
      # Stack After: [... ceil(a)]
      private def execute_arithmetic_ceiling(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_CEILING")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_CEILING requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(a.to_f64.ceil.to_i64)
                 elsif a.unsigned_integer?
                   # Integer ceiling is itself
                   Value::Context.new(a.to_u64)
                 else
                   # Integer ceiling is itself
                   Value::Context.new(a.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_ROUND
      # Round to nearest integer (half up)
      # Stack Before: [... a]
      # Stack After: [... round(a)]
      private def execute_arithmetic_round(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARITHMETIC_ROUND")

        a = process.stack.pop

        unless a.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_ROUND requires a numeric value")
        end

        result = if a.float?
                   Value::Context.new(a.to_f64.round.to_i64)
                 elsif a.unsigned_integer?
                   # Integer round is itself
                   Value::Context.new(a.to_u64)
                 else
                   # Integer round is itself
                   Value::Context.new(a.to_i64)
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_MINIMUM
      # Return the smaller of two numeric values
      # Stack Before: [... a, b]
      # Stack After: [... min(a, b)]
      private def execute_arithmetic_minimum(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_MINIMUM")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_MINIMUM requires two numeric values")
        end

        result = if a.float? || b.float?
                   Value::Context.new(Math.min(a.to_f64, b.to_f64))
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(Math.min(a.to_u64, b.to_u64))
                 else
                   Value::Context.new(Math.min(a.to_i64, b.to_i64))
                 end

        process.stack.push(result)
        result
      end

      # ARITHMETIC_MAXIMUM
      # Return the larger of two numeric values
      # Stack Before: [... a, b]
      # Stack After: [... max(a, b)]
      private def execute_arithmetic_maximum(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARITHMETIC_MAXIMUM")

        b = process.stack.pop
        a = process.stack.pop

        unless a.numeric? && b.numeric?
          raise Exceptions::TypeMismatch.new("ARITHMETIC_MAXIMUM requires two numeric values")
        end

        result = if a.float? || b.float?
                   Value::Context.new(Math.max(a.to_f64, b.to_f64))
                 elsif a.unsigned_integer? && b.unsigned_integer?
                   Value::Context.new(Math.max(a.to_u64, b.to_u64))
                 else
                   Value::Context.new(Math.max(a.to_i64, b.to_i64))
                 end

        process.stack.push(result)
        result
      end
    end
  end
end
