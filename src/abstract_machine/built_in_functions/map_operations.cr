module AbstractMachine
  module BuiltInFunctions
    module MapOperations
      extend self

      # MAP_CREATE_EMPTY
      # Create a new empty map
      # Stack Before: [...]
      # Stack After: [... {}]
      private def execute_map_create_empty(process : Process::Context) : Value::Context
        process.counter += 1

        result = Value::Context.new(Hash(String, Value::Context).new)
        process.stack.push(result)

        result
      end

      # MAP_CREATE_FROM_STACK
      # Create map from alternating key-value pairs on stack
      # Operand: UInt32 (number of key-value pairs)
      # Stack Before: [... k1, v1, k2, v2, ..., kN, vN]
      # Stack After: [... {k1: v1, k2: v2, ..., kN: vN}]
      private def execute_map_create_from_stack(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        count = if instruction.value.integer? || instruction.value.unsigned_integer?
                  instruction.value.to_i64.to_i32
                else
                  raise Exceptions::TypeMismatch.new("MAP_CREATE_FROM_STACK requires integer count operand")
                end

        # Need count * 2 values on stack (key-value pairs)
        check_stack_size(process, count * 2, "MAP_CREATE_FROM_STACK")

        map = Hash(String, Value::Context).new

        # Pop pairs in reverse order to maintain correct insertion order
        pairs = Array(Tuple(String, Value::Context)).new(count)
        count.times do
          value = process.stack.pop
          key_value = process.stack.pop

          key = if key_value.string?
                  key_value.to_s
                elsif key_value.symbol?
                  key_value.to_symbol.to_s
                else
                  # Convert to string for key
                  key_value.to_s
                end

          pairs.unshift({key, value})
        end

        # Build map in correct order
        pairs.each do |key, value|
          map[key] = value
        end

        result = Value::Context.new(map)
        process.stack.push(result)

        result
      end

      # MAP_SIZE
      # Get the number of key-value pairs in a map
      # Stack Before: [... map]
      # Stack After: [... size]
      private def execute_map_size(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MAP_SIZE")

        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_SIZE requires a map")
        end

        result = Value::Context.new(map_value.to_h.size.to_i64)
        process.stack.push(result)

        result
      end

      # MAP_GET
      # Get value associated with key (returns null if not found)
      # Stack Before: [... map, key]
      # Stack After: [... value_or_null]
      private def execute_map_get(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "MAP_GET")

        key_value = process.stack.pop
        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_GET requires a map")
        end

        key = convert_to_map_key(key_value)
        map = map_value.to_h

        result = map[key]? || Value::Context.null
        process.stack.push(result.clone)

        result
      end

      # MAP_GET_OR_DEFAULT
      # Get value associated with key, or default if not found
      # Stack Before: [... map, key, default_value]
      # Stack After: [... value]
      private def execute_map_get_or_default(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "MAP_GET_OR_DEFAULT")

        default_value = process.stack.pop
        key_value = process.stack.pop
        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_GET_OR_DEFAULT requires a map")
        end

        key = convert_to_map_key(key_value)
        map = map_value.to_h

        result = map[key]? || default_value
        process.stack.push(result.clone)

        result
      end

      # MAP_SET
      # Set value for key (returns new map)
      # Stack Before: [... map, key, value]
      # Stack After: [... new_map]
      private def execute_map_set(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "MAP_SET")

        value = process.stack.pop
        key_value = process.stack.pop
        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_SET requires a map")
        end

        key = convert_to_map_key(key_value)

        # Create a copy for immutability
        new_map = map_value.to_h.dup
        new_map[key] = value

        result = Value::Context.new(new_map)
        process.stack.push(result)

        result
      end

      # MAP_DELETE
      # Remove key from map (returns new map)
      # Stack Before: [... map, key]
      # Stack After: [... new_map]
      private def execute_map_delete(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "MAP_DELETE")

        key_value = process.stack.pop
        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_DELETE requires a map")
        end

        key = convert_to_map_key(key_value)

        # Create a copy for immutability
        new_map = map_value.to_h.dup
        new_map.delete(key)

        result = Value::Context.new(new_map)
        process.stack.push(result)

        result
      end

      # MAP_HAS_KEY
      # Check if map contains a key
      # Stack Before: [... map, key]
      # Stack After: [... boolean]
      private def execute_map_has_key(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "MAP_HAS_KEY")

        key_value = process.stack.pop
        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_HAS_KEY requires a map")
        end

        key = convert_to_map_key(key_value)
        map = map_value.to_h

        result = Value::Context.new(map.has_key?(key))
        process.stack.push(result)

        result
      end

      # MAP_KEYS
      # Get all keys as an array
      # Stack Before: [... map]
      # Stack After: [... keys_array]
      private def execute_map_keys(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MAP_KEYS")

        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_KEYS requires a map")
        end

        map = map_value.to_h
        keys = map.keys.map { |k| Value::Context.new(k).as(Value::Context) }

        result = Value::Context.new(keys)
        process.stack.push(result)

        result
      end

      # MAP_VALUES
      # Get all values as an array
      # Stack Before: [... map]
      # Stack After: [... values_array]
      private def execute_map_values(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MAP_VALUES")

        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_VALUES requires a map")
        end

        map = map_value.to_h
        values = map.values.map { |v| v.as(Value::Context) }

        result = Value::Context.new(values)
        process.stack.push(result)

        result
      end

      # MAP_ENTRIES
      # Get all entries as array of [key, value] pairs
      # Stack Before: [... map]
      # Stack After: [... entries_array]
      private def execute_map_entries(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MAP_ENTRIES")

        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_ENTRIES requires a map")
        end

        map = map_value.to_h
        entries = map.map do |key, value|
          pair = [Value::Context.new(key).as(Value::Context), value.as(Value::Context)]
          Value::Context.new(pair).as(Value::Context)
        end

        result = Value::Context.new(entries)
        process.stack.push(result)

        result
      end

      # MAP_MERGE
      # Merge two maps (second map's values override first's)
      # Stack Before: [... map1, map2]
      # Stack After: [... merged_map]
      private def execute_map_merge(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "MAP_MERGE")

        map2_value = process.stack.pop
        map1_value = process.stack.pop

        unless map1_value.map? && map2_value.map?
          raise Exceptions::TypeMismatch.new("MAP_MERGE requires two maps")
        end

        map1 = map1_value.to_h
        map2 = map2_value.to_h

        # Create merged map (map2 values override map1)
        merged = map1.dup
        map2.each do |key, value|
          merged[key] = value
        end

        result = Value::Context.new(merged)
        process.stack.push(result)

        result
      end

      # MAP_FOR_EACH
      # Execute function for each key-value pair
      # Operand: Array(Instruction) - the function to execute
      # Stack Before: [... map]
      # Stack After: [...]
      private def execute_map_for_each(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MAP_FOR_EACH")

        map_value = process.stack.pop

        unless map_value.map?
          raise Exceptions::TypeMismatch.new("MAP_FOR_EACH requires a map")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("MAP_FOR_EACH requires instruction array operand")
        end

        map = map_value.to_h
        instructions = instruction.value.to_instructions

        map.each do |key, value|
          key_value = Value::Context.new(key)
          execute_inline_function(process, instructions, [key_value, value])
        end

        Value::Context.null # Return null
      end

      # Convert a value to a string key for map operations
      private def convert_to_map_key(key_value : Value::Context) : String
        if key_value.string?
          key_value.to_s
        elsif key_value.symbol?
          key_value.to_symbol.to_s
        elsif key_value.integer? || key_value.unsigned_integer?
          key_value.to_i64.to_s
        else
          # Convert to string representation
          key_value.to_s
        end
      end
    end
  end
end
