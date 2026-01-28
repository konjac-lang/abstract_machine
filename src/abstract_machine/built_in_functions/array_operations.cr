module AbstractMachine
  module BuiltInFunctions
    module ArrayOperations
      extend self

      # ARRAY_CREATE_EMPTY
      # Create a new empty array
      # Stack Before: [...]
      # Stack After: [... []]
      private def execute_array_create_empty(process : Process::Context) : Value::Context
        process.counter += 1

        array = Array(Value::Context).new
        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end

      # ARRAY_CREATE_WITH_SIZE
      # Create array with specified size, filled with null
      # Stack Before: [... size]
      # Stack After: [... array]
      private def execute_array_create_with_size(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_CREATE_WITH_SIZE")

        size_value = process.stack.pop

        unless size_value.integer? || size_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("ARRAY_CREATE_WITH_SIZE requires an integer size")
        end

        size = size_value.to_i64.to_i32

        if size < 0
          raise Exceptions::Value.new("ARRAY_CREATE_WITH_SIZE size cannot be negative: #{size}")
        end

        # Reasonable limit to prevent memory exhaustion
        max_size = 10_000_000
        if size > max_size
          raise Exceptions::Value.new("ARRAY_CREATE_WITH_SIZE size #{size} exceeds maximum (#{max_size})")
        end

        array = Array(Value::Context).new(size) { Value::Context.null }
        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end

      # ARRAY_CREATE_FROM_STACK
      # Create array from top N stack values
      # Operand: UInt32 (count)
      # Stack Before: [... v1, v2, ..., vN]
      # Stack After: [... [v1, v2, ..., vN]]
      private def execute_array_create_from_stack(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        count = if instruction.value.integer? || instruction.value.unsigned_integer?
                  instruction.value.to_i64.to_i32
                else
                  raise Exceptions::TypeMismatch.new("ARRAY_CREATE_FROM_STACK requires integer count operand")
                end

        check_stack_size(process, count, "ARRAY_CREATE_FROM_STACK")

        # Pop values in reverse order to maintain correct order in array
        values = Array(Value::Context).new(count)
        count.times do
          values.unshift(process.stack.pop)
        end

        result = Value::Context.new(values)
        process.stack.push(result)

        result
      end

      # ARRAY_LENGTH
      # Get the number of elements in an array
      # Stack Before: [... array]
      # Stack After: [... length]
      private def execute_array_length(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_LENGTH")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_LENGTH requires an array")
        end

        result = Value::Context.new(array_value.to_a.size.to_i64)
        process.stack.push(result)

        result
      end

      # ARRAY_GET
      # Get element at specified index
      # Stack Before: [... array, index]
      # Stack After: [... value]
      private def execute_array_get(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_GET")

        index_value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_GET requires an array")
        end

        unless index_value.integer? || index_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("ARRAY_GET requires an integer index")
        end

        array = array_value.to_a
        index = index_value.to_i64.to_i32

        # Support negative indexing
        if index < 0
          index = array.size + index
        end

        if index < 0 || index >= array.size
          raise Exceptions::IndexOutOfBounds.new("ARRAY_GET index #{index} out of bounds (array length: #{array.size})")
        end

        result = array[index].clone
        process.stack.push(result)

        result
      end

      # ARRAY_SET
      # Set element at specified index (returns new array)
      # Stack Before: [... array, index, value]
      # Stack After: [... new_array]
      private def execute_array_set(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "ARRAY_SET")

        value = process.stack.pop
        index_value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_SET requires an array")
        end

        unless index_value.integer? || index_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("ARRAY_SET requires an integer index")
        end

        array = array_value.to_a.dup # Create a copy for immutability
        index = index_value.to_i64.to_i32

        # Support negative indexing
        if index < 0
          index = array.size + index
        end

        if index < 0 || index >= array.size
          raise Exceptions::IndexOutOfBounds.new("ARRAY_SET index #{index} out of bounds (array length: #{array.size})")
        end

        array[index] = value

        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end

      # ARRAY_PUSH
      # Append element to end of array (returns new array)
      # Stack Before: [... array, value]
      # Stack After: [... new_array]
      private def execute_array_push(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_PUSH")

        value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_PUSH requires an array")
        end

        array = array_value.to_a.dup
        array.push(value)

        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end

      # ARRAY_POP
      # Remove and return last element of array
      # Stack Before: [... array]
      # Stack After: [... new_array, value]
      private def execute_array_pop(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_POP")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_POP requires an array")
        end

        array = array_value.to_a

        if array.empty?
          raise Exceptions::IndexOutOfBounds.new("ARRAY_POP on empty array")
        end

        new_array = array[0...-1]
        popped_value = array.last

        process.stack.push(Value::Context.new(new_array))
        process.stack.push(popped_value)

        popped_value
      end

      # ARRAY_UNSHIFT
      # Prepend element to beginning of array (returns new array)
      # Stack Before: [... array, value]
      # Stack After: [... new_array]
      private def execute_array_unshift(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_UNSHIFT")

        value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_UNSHIFT requires an array")
        end

        array = array_value.to_a.dup
        array.unshift(value)

        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end

      # ARRAY_SHIFT
      # Remove and return first element of array
      # Stack Before: [... array]
      # Stack After: [... new_array, value]
      private def execute_array_shift(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_SHIFT")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_SHIFT requires an array")
        end

        array = array_value.to_a

        if array.empty?
          raise Exceptions::IndexOutOfBounds.new("ARRAY_SHIFT on empty array")
        end

        shifted_value = array.first
        new_array = array[1..]

        process.stack.push(Value::Context.new(new_array))
        process.stack.push(shifted_value)

        shifted_value
      end

      # ARRAY_SLICE
      # Extract a slice of array elements
      # Stack Before: [... array, start_index, length]
      # Stack After: [... sliced_array]
      private def execute_array_slice(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "ARRAY_SLICE")

        length_value = process.stack.pop
        start_value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_SLICE requires an array")
        end

        unless (start_value.integer? || start_value.unsigned_integer?) &&
               (length_value.integer? || length_value.unsigned_integer?)
          raise Exceptions::TypeMismatch.new("ARRAY_SLICE requires integer start and length")
        end

        array = array_value.to_a
        start_index = start_value.to_i64.to_i32
        length = length_value.to_i64.to_i32

        # Support negative indexing
        if start_index < 0
          start_index = array.size + start_index
        end

        if start_index < 0 || start_index > array.size
          raise Exceptions::IndexOutOfBounds.new("ARRAY_SLICE start index #{start_index} out of bounds (array length: #{array.size})")
        end

        # Clamp length to available elements
        actual_length = Math.min(length, array.size - start_index)
        actual_length = Math.max(actual_length, 0)

        sliced = array[start_index, actual_length]

        result = Value::Context.new(sliced)
        process.stack.push(result)

        result
      end

      # ARRAY_CONCATENATE
      # Concatenate two arrays
      # Stack Before: [... array1, array2]
      # Stack After: [... concatenated_array]
      private def execute_array_concatenate(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_CONCATENATE")

        array2_value = process.stack.pop
        array1_value = process.stack.pop

        unless array1_value.array? && array2_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_CONCATENATE requires two arrays")
        end

        concatenated = array1_value.to_a + array2_value.to_a

        result = Value::Context.new(concatenated)
        process.stack.push(result)

        result
      end

      # ARRAY_INDEX_OF
      # Find first index of value in array (returns -1 if not found)
      # Stack Before: [... array, value]
      # Stack After: [... index]
      private def execute_array_index_of(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_INDEX_OF")

        search_value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_INDEX_OF requires an array")
        end

        array = array_value.to_a
        index = -1_i64

        array.each_with_index do |element, i|
          if values_equal?(element, search_value)
            index = i.to_i64
            break
          end
        end

        result = Value::Context.new(index)
        process.stack.push(result)

        result
      end

      # ARRAY_CONTAINS
      # Check if array contains a value
      # Stack Before: [... array, value]
      # Stack After: [... boolean]
      private def execute_array_contains(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_CONTAINS")

        search_value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_CONTAINS requires an array")
        end

        array = array_value.to_a
        found = array.any? { |element| values_equal?(element, search_value) }

        result = Value::Context.new(found)
        process.stack.push(result)

        result
      end

      # ARRAY_REVERSE
      # Reverse the order of elements in array
      # Stack Before: [... array]
      # Stack After: [... reversed_array]
      private def execute_array_reverse(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_REVERSE")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_REVERSE requires an array")
        end

        reversed = array_value.to_a.reverse

        result = Value::Context.new(reversed)
        process.stack.push(result)

        result
      end

      # ARRAY_SORT
      # Sort array in ascending order
      # Stack Before: [... array]
      # Stack After: [... sorted_array]
      private def execute_array_sort(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_SORT")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_SORT requires an array")
        end

        array = array_value.to_a

        # Sort using comparison helper
        sorted = array.sort do |a, b|
          compare_values_for_sort(a, b)
        end

        result = Value::Context.new(sorted)
        process.stack.push(result)

        result
      end

      # ARRAY_MAP
      # Apply function to each element, returning new array
      # Operand: Array(Instruction) - the mapping function
      # Stack Before: [... array]
      # Stack After: [... mapped_array]
      private def execute_array_map(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_MAP")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_MAP requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_MAP requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        mapped = array.map do |element|
          execute_inline_function(process, instructions, [element])
        end

        result = Value::Context.new(mapped)
        process.stack.push(result)

        result
      end

      # ARRAY_FILTER
      # Filter array by predicate function
      # Operand: Array(Instruction) - the predicate function
      # Stack Before: [... array]
      # Stack After: [... filtered_array]
      private def execute_array_filter(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_FILTER")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_FILTER requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_FILTER requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        filtered = array.select do |element|
          result = execute_inline_function(process, instructions, [element])
          result.to_bool
        end

        result = Value::Context.new(filtered)
        process.stack.push(result)

        result
      end

      # ARRAY_REDUCE
      # Reduce array to single value using accumulator function
      # Operand: Array(Instruction) - the reducer function
      # Stack Before: [... array, initial_value]
      # Stack After: [... result]
      private def execute_array_reduce(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "ARRAY_REDUCE")

        initial_value = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_REDUCE requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_REDUCE requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        accumulator = initial_value
        array.each do |element|
          accumulator = execute_inline_function(process, instructions, [accumulator, element])
        end

        process.stack.push(accumulator)
        accumulator
      end

      # ARRAY_FOR_EACH
      # Execute function for each element (no return value)
      # Operand: Array(Instruction) - the function to execute
      # Stack Before: [... array]
      # Stack After: [...]
      private def execute_array_for_each(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_FOR_EACH")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_FOR_EACH requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_FOR_EACH requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        array.each do |element|
          execute_inline_function(process, instructions, [element])
        end

        Value::Context.null # Return null
      end

      # ARRAY_FIND
      # Find first element matching predicate
      # Operand: Array(Instruction) - the predicate function
      # Stack Before: [... array]
      # Stack After: [... element_or_null]
      private def execute_array_find(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_FIND")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_FIND requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_FIND requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        found = array.find do |element|
          result = execute_inline_function(process, instructions, [element])
          result.to_bool
        end

        result = found || Value::Context.null # Return null if not found
        process.stack.push(result)

        result
      end

      # ARRAY_EVERY
      # Check if all elements satisfy predicate
      # Operand: Array(Instruction) - the predicate function
      # Stack Before: [... array]
      # Stack After: [... boolean]
      private def execute_array_every(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_EVERY")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_EVERY requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_EVERY requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        all_match = array.all? do |element|
          result = execute_inline_function(process, instructions, [element])
          result.to_bool
        end

        result = Value::Context.new(all_match)
        process.stack.push(result)

        result
      end

      # ARRAY_SOME
      # Check if any element satisfies predicate
      # Operand: Array(Instruction) - the predicate function
      # Stack Before: [... array]
      # Stack After: [... boolean]
      private def execute_array_some(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_SOME")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_SOME requires an array")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("ARRAY_SOME requires instruction array operand")
        end

        array = array_value.to_a
        instructions = instruction.value.to_instructions

        any_match = array.any? do |element|
          result = execute_inline_function(process, instructions, [element])
          result.to_bool
        end

        result = Value::Context.new(any_match)
        process.stack.push(result)

        result
      end

      # ARRAY_FLATTEN
      # Flatten nested arrays by one level
      # Stack Before: [... array]
      # Stack After: [... flattened_array]
      private def execute_array_flatten(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_FLATTEN")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_FLATTEN requires an array")
        end

        array = array_value.to_a
        flattened = Array(Value::Context).new

        array.each do |element|
          if element.array?
            element.to_a.each { |e| flattened << e }
          else
            flattened << element
          end
        end

        result = Value::Context.new(flattened)
        process.stack.push(result)

        result
      end

      # ARRAY_UNIQUE
      # Remove duplicate values from array
      # Stack Before: [... array]
      # Stack After: [... unique_array]
      private def execute_array_unique(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "ARRAY_UNIQUE")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("ARRAY_UNIQUE requires an array")
        end

        array = array_value.to_a
        unique = Array(Value::Context).new

        array.each do |element|
          already_exists = unique.any? { |u| values_equal?(u, element) }
          unique << element unless already_exists
        end

        result = Value::Context.new(unique)
        process.stack.push(result)

        result
      end

      # Compare values for sorting
      private def compare_values_for_sort(a : Value::Context, b : Value::Context) : Int32
        # Same type comparison
        if a.numeric? && b.numeric?
          if a.float? || b.float?
            a_f = a.to_f64
            b_f = b.to_f64
            # NaN values sort to the end for stability
            a_nan = a_f.nan?
            b_nan = b_f.nan?
            if a_nan && b_nan
              return 0
            elsif a_nan
              return 1 # NaN sorts after everything
            elsif b_nan
              return -1 # Everything sorts before NaN
            end
            return a_f <=> b_f || 0
          elsif a.unsigned_integer? && b.unsigned_integer?
            return a.to_u64 <=> b.to_u64
          else
            return a.to_i64 <=> b.to_i64
          end
        end

        if a.string? && b.string?
          return a.to_s <=> b.to_s
        end

        # Different types: sort by type name for stability
        a.type <=> b.type
      end
    end
  end
end
