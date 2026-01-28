module AbstractMachine
  module InstructionExecutor
    module ComparisonOperations
      extend self

      # COMPARISON_EQUAL
      # Test if two values are equal (structural equality)
      # Stack Before: [... a, b]
      # Stack After: [... (a == b)]
      private def execute_comparison_equal(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_EQUAL")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(values_equal?(a, b))
        process.stack.push(result)

        result
      end

      # COMPARISON_NOT_EQUAL
      # Test if two values are not equal
      # Stack Before: [... a, b]
      # Stack After: [... (a != b)]
      private def execute_comparison_not_equal(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_NOT_EQUAL")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(!values_equal?(a, b))
        process.stack.push(result)

        result
      end

      # COMPARISON_IDENTICAL
      # Test if two values are identical (reference equality)
      # Stack Before: [... a, b]
      # Stack After: [... (a === b)]
      private def execute_comparison_identical(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_IDENTICAL")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(values_identical?(a, b))
        process.stack.push(result)

        result
      end

      # COMPARISON_NOT_IDENTICAL
      # Test if two values are not identical
      # Stack Before: [... a, b]
      # Stack After: [... (a !== b)]
      private def execute_comparison_not_identical(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_NOT_IDENTICAL")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(!values_identical?(a, b))
        process.stack.push(result)

        result
      end

      # COMPARISON_LESS_THAN
      # Test if second value is less than top value
      # Stack Before: [... a, b]
      # Stack After: [... (a < b)]
      private def execute_comparison_less_than(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_LESS_THAN")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(compare_values(a, b, "COMPARISON_LESS_THAN") < 0)
        process.stack.push(result)

        result
      end

      # COMPARISON_LESS_THAN_OR_EQUAL
      # Test if second value is less than or equal to top value
      # Stack Before: [... a, b]
      # Stack After: [... (a <= b)]
      private def execute_comparison_less_than_or_equal(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_LESS_THAN_OR_EQUAL")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(compare_values(a, b, "COMPARISON_LESS_THAN_OR_EQUAL") <= 0)
        process.stack.push(result)

        result
      end

      # COMPARISON_GREATER_THAN
      # Test if second value is greater than top value
      # Stack Before: [... a, b]
      # Stack After: [... (a > b)]
      private def execute_comparison_greater_than(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_GREATER_THAN")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(compare_values(a, b, "COMPARISON_GREATER_THAN") > 0)
        process.stack.push(result)

        result
      end

      # COMPARISON_GREATER_THAN_OR_EQUAL
      # Test if second value is greater than or equal to top value
      # Stack Before: [... a, b]
      # Stack After: [... (a >= b)]
      private def execute_comparison_greater_than_or_equal(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "COMPARISON_GREATER_THAN_OR_EQUAL")

        b = process.stack.pop
        a = process.stack.pop

        result = Value::Context.new(compare_values(a, b, "COMPARISON_GREATER_THAN_OR_EQUAL") >= 0)
        process.stack.push(result)

        result
      end

      # COMPARISON_IS_NULL
      # Test if top value is null
      # Stack Before: [... a]
      # Stack After: [... (a == null)]
      private def execute_comparison_is_null(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "COMPARISON_IS_NULL")

        a = process.stack.pop

        result = Value::Context.new(a.null?)
        process.stack.push(result)

        result
      end

      # COMPARISON_IS_NOT_NULL
      # Test if top value is not null
      # Stack Before: [... a]
      # Stack After: [... (a != null)]
      private def execute_comparison_is_not_null(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "COMPARISON_IS_NOT_NULL")

        a = process.stack.pop

        result = Value::Context.new(!a.null?)
        process.stack.push(result)

        result
      end

      # Structural equality comparison
      # Compares values by their content, not identity
      private def values_equal?(a : Value::Context, b : Value::Context) : Bool
        # Different types handling
        # Numeric types can be compared across types
        if a.numeric? && b.numeric?
          if a.float? || b.float?
            return a.to_f64 == b.to_f64
          elsif a.unsigned_integer? && b.unsigned_integer?
            return a.to_u64 == b.to_u64
          else
            return a.to_i64 == b.to_i64
          end
        end

        # Null comparison
        if a.null? && b.null?
          return true
        end

        # Different primitive types are not equal
        if a.primitive_type != b.primitive_type
          return false
        end

        # Same type comparisons
        case
        when a.boolean?
          a.to_bool == b.to_bool
        when a.string?
          a.to_s == b.to_s
        when a.symbol?
          a.to_symbol == b.to_symbol
        when a.array?
          arrays_equal?(a, b)
        when a.map?
          maps_equal?(a, b)
        when a.binary?
          a.to_binary == b.to_binary
        when a.lambda?
          # Lambdas are equal only if same reference
          a.pointer == b.pointer
        when a.custom?
          a.custom_type == b.custom_type && a.pointer == b.pointer
        else
          false
        end
      end

      # Reference/identity equality comparison
      # For primitives, same as structural equality
      # For collections, checks if same object (same pointer)
      private def values_identical?(a : Value::Context, b : Value::Context) : Bool
        # Different types are never identical
        if a.primitive_type != b.primitive_type
          return false
        end

        # For primitives, identical means equal value
        case
        when a.null?
          true
        when a.boolean?
          a.to_bool == b.to_bool
        when a.integer?
          a.to_i64 == b.to_i64
        when a.unsigned_integer?
          a.to_u64 == b.to_u64
        when a.float?
          a.to_f64 == b.to_f64
        when a.string?
          # Strings are immutable, so we can compare by value
          a.to_s == b.to_s
        when a.symbol?
          a.to_symbol == b.to_symbol
        else
          # For reference types (arrays, maps, lambdas, binary, custom),
          # check pointer equality
          a.pointer == b.pointer
        end
      end

      # Compare two values for ordering
      # Returns: negative if a < b, zero if a == b, positive if a > b
      private def compare_values(a : Value::Context, b : Value::Context, operation : String) : Int32
        # Numeric comparison
        if a.numeric? && b.numeric?
          if a.float? || b.float?
            a_f = a.to_f64
            b_f = b.to_f64
            # Handle NaN cases - NaN comparisons are undefined
            if a_f.nan? || b_f.nan?
              raise Exceptions::TypeMismatch.new(
                "#{operation} cannot compare NaN values"
              )
            end
            return a_f <=> b_f || 0
          elsif a.unsigned_integer? && b.unsigned_integer?
            return a.to_u64 <=> b.to_u64
          else
            return a.to_i64 <=> b.to_i64
          end
        end

        # String comparison (lexicographic)
        if a.string? && b.string?
          return a.to_s <=> b.to_s
        end

        # Symbol comparison (by name)
        if a.symbol? && b.symbol?
          return a.to_symbol.to_s <=> b.to_symbol.to_s
        end

        # Binary comparison (lexicographic byte comparison)
        if a.binary? && b.binary?
          return compare_binary(a.to_binary, b.to_binary)
        end

        # Array comparison (element by element)
        if a.array? && b.array?
          return compare_arrays(a, b, operation)
        end

        # Types are not comparable
        raise Exceptions::TypeMismatch.new(
          "#{operation} cannot compare #{a.type} with #{b.type}"
        )
      end

      # Compare two arrays element by element
      private def compare_arrays(a : Value::Context, b : Value::Context, operation : String) : Int32
        a_arr = a.to_a
        b_arr = b.to_a

        min_length = Math.min(a_arr.size, b_arr.size)

        min_length.times do |i|
          cmp = compare_values(a_arr[i], b_arr[i], operation)
          return cmp if cmp != 0
        end

        # If all compared elements are equal, shorter array is "less"
        a_arr.size <=> b_arr.size
      end

      # Check if two arrays are structurally equal
      private def arrays_equal?(a : Value::Context, b : Value::Context) : Bool
        a_arr = a.to_a
        b_arr = b.to_a

        return false if a_arr.size != b_arr.size

        a_arr.size.times do |i|
          return false unless values_equal?(a_arr[i], b_arr[i])
        end

        true
      end

      # Check if two maps are structurally equal
      private def maps_equal?(a : Value::Context, b : Value::Context) : Bool
        a_map = a.to_h
        b_map = b.to_h

        return false if a_map.size != b_map.size

        a_map.each do |key, value|
          return false unless b_map.has_key?(key)
          return false unless values_equal?(value, b_map[key])
        end

        true
      end

      # Compare two binary values lexicographically
      private def compare_binary(a : Slice(UInt8), b : Slice(UInt8)) : Int32
        min_length = Math.min(a.size, b.size)

        min_length.times do |i|
          cmp = a[i] <=> b[i]
          return cmp if cmp != 0
        end

        a.size <=> b.size
      end
    end
  end
end
