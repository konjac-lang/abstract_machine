module AbstractMachine
  module BuiltInFunctions
    module BinaryOperations
      extend self

      # BINARY_LENGTH
      # Get length of binary data in bytes
      # Stack Before: [... binary]
      # Stack After: [... length]
      private def execute_binary_length(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "BINARY_LENGTH")

        binary_value = process.stack.pop

        unless binary_value.binary?
          raise Exceptions::TypeMismatch.new("BINARY_LENGTH requires binary data")
        end

        result = Value::Context.new(binary_value.to_binary.size.to_i64)
        process.stack.push(result)

        result
      end

      # BINARY_CONCATENATE
      # Concatenate two binary values
      # Stack Before: [... binary1, binary2]
      # Stack After: [... (binary1 + binary2)]
      private def execute_binary_concatenate(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BINARY_CONCATENATE")

        binary2 = process.stack.pop
        binary1 = process.stack.pop

        unless binary1.binary? && binary2.binary?
          raise Exceptions::TypeMismatch.new("BINARY_CONCATENATE requires two binary values")
        end

        slice1 = binary1.to_binary
        slice2 = binary2.to_binary

        # Create new slice with combined size
        combined = Slice(UInt8).new(slice1.size + slice2.size)
        combined.copy_from(slice1)
        combined[slice1.size, slice2.size].copy_from(slice2)

        result = Value::Context.new(combined)
        process.stack.push(result)

        result
      end

      # BINARY_SLICE
      # Extract a slice of binary data
      # Stack Before: [... binary, start_index, length]
      # Stack After: [... binary_slice]
      private def execute_binary_slice(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "BINARY_SLICE")

        length = process.stack.pop
        start_index = process.stack.pop
        binary_value = process.stack.pop

        unless binary_value.binary?
          raise Exceptions::TypeMismatch.new("BINARY_SLICE requires binary data")
        end

        unless (start_index.integer? || start_index.unsigned_integer?) &&
               (length.integer? || length.unsigned_integer?)
          raise Exceptions::TypeMismatch.new("BINARY_SLICE requires integer start_index and length")
        end

        binary = binary_value.to_binary
        start_i = start_index.to_i64.to_i32
        len = length.to_i64.to_i32

        if start_i < 0 || start_i > binary.size
          raise Exceptions::IndexOutOfBounds.new(
            "BINARY_SLICE start index #{start_i} out of bounds (binary length: #{binary.size})"
          )
        end

        # Clamp length to available data
        actual_length = Math.min(len, binary.size - start_i)
        actual_length = Math.max(0, actual_length)

        sliced = Slice(UInt8).new(actual_length)
        if actual_length > 0
          sliced.copy_from(binary[start_i, actual_length])
        end

        result = Value::Context.new(sliced)
        process.stack.push(result)

        result
      end

      # BINARY_GET_BYTE
      # Get byte value at specified index
      # Stack Before: [... binary, index]
      # Stack After: [... byte_value]
      private def execute_binary_get_byte(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "BINARY_GET_BYTE")

        index = process.stack.pop
        binary_value = process.stack.pop

        unless binary_value.binary?
          raise Exceptions::TypeMismatch.new("BINARY_GET_BYTE requires binary data")
        end

        unless index.integer? || index.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BINARY_GET_BYTE requires an integer index")
        end

        binary = binary_value.to_binary
        idx = index.to_i64.to_i32

        if idx < 0 || idx >= binary.size
          raise Exceptions::IndexOutOfBounds.new(
            "BINARY_GET_BYTE index #{idx} out of bounds (binary length: #{binary.size})"
          )
        end

        result = Value::Context.new(binary[idx].to_i64)
        process.stack.push(result)

        result
      end

      # BINARY_SET_BYTE
      # Set byte value at specified index (returns new binary)
      # Stack Before: [... binary, index, byte_value]
      # Stack After: [... new_binary]
      private def execute_binary_set_byte(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "BINARY_SET_BYTE")

        byte_value = process.stack.pop
        index = process.stack.pop
        binary_value = process.stack.pop

        unless binary_value.binary?
          raise Exceptions::TypeMismatch.new("BINARY_SET_BYTE requires binary data")
        end

        unless index.integer? || index.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BINARY_SET_BYTE requires an integer index")
        end

        unless byte_value.integer? || byte_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BINARY_SET_BYTE requires an integer byte value")
        end

        binary = binary_value.to_binary
        idx = index.to_i64.to_i32
        byte = byte_value.to_i64

        if idx < 0 || idx >= binary.size
          raise Exceptions::IndexOutOfBounds.new(
            "BINARY_SET_BYTE index #{idx} out of bounds (binary length: #{binary.size})"
          )
        end

        if byte < 0 || byte > 255
          raise Exceptions::Value.new(
            "BINARY_SET_BYTE byte value #{byte} out of range (must be 0-255)"
          )
        end

        # Create new binary with modified byte (immutable semantics)
        new_binary = Slice(UInt8).new(binary.size)
        new_binary.copy_from(binary)
        new_binary[idx] = byte.to_u8

        result = Value::Context.new(new_binary)
        process.stack.push(result)

        result
      end

      # BINARY_CONVERT_TO_STRING
      # Convert binary data to string using UTF-8 decoding
      # Stack Before: [... binary]
      # Stack After: [... string]
      private def execute_binary_convert_to_string(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "BINARY_CONVERT_TO_STRING")

        binary_value = process.stack.pop

        unless binary_value.binary?
          raise Exceptions::TypeMismatch.new("BINARY_CONVERT_TO_STRING requires binary data")
        end

        binary = binary_value.to_binary

        begin
          str = String.new(binary)
          # Validate UTF-8 by checking if it's valid
          unless str.valid_encoding?
            raise Exceptions::Encoding.new("BINARY_CONVERT_TO_STRING invalid UTF-8 encoding")
          end
          result = Value::Context.new(str)
        rescue e : ArgumentError
          raise Exceptions::Encoding.new("BINARY_CONVERT_TO_STRING invalid UTF-8 encoding: #{e.message}")
        end

        process.stack.push(result)
        result
      end

      # BINARY_CREATE
      # Create binary data of specified size filled with zeros
      # Stack Before: [... size]
      # Stack After: [... binary]
      private def execute_binary_create(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "BINARY_CREATE")

        size_value = process.stack.pop

        unless size_value.integer? || size_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("BINARY_CREATE requires an integer size")
        end

        size = size_value.to_i64.to_i32

        if size < 0
          raise Exceptions::Value.new("BINARY_CREATE size cannot be negative: #{size}")
        end

        # Reasonable size limit to prevent memory exhaustion
        max_size = 100_000_000 # 100 MB
        if size > max_size
          raise Exceptions::Value.new("BINARY_CREATE size #{size} exceeds maximum allowed (#{max_size})")
        end

        # Create zero-filled binary
        binary = Slice(UInt8).new(size, 0_u8)

        result = Value::Context.new(binary)
        process.stack.push(result)

        result
      end

      # BINARY_FROM_ARRAY
      # Create binary data from array of byte values
      # Stack Before: [... array_of_bytes]
      # Stack After: [... binary]
      private def execute_binary_from_array(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "BINARY_FROM_ARRAY")

        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("BINARY_FROM_ARRAY requires an array")
        end

        array = array_value.to_a
        binary = Slice(UInt8).new(array.size)

        array.each_with_index do |value, i|
          unless value.integer? || value.unsigned_integer?
            raise Exceptions::TypeMismatch.new(
              "BINARY_FROM_ARRAY array element at index #{i} is not an integer"
            )
          end

          byte = value.to_i64

          if byte < 0 || byte > 255
            raise Exceptions::Value.new(
              "BINARY_FROM_ARRAY byte value #{byte} at index #{i} out of range (must be 0-255)"
            )
          end

          binary[i] = byte.to_u8
        end

        result = Value::Context.new(binary)
        process.stack.push(result)

        result
      end

      # BINARY_TO_ARRAY
      # Convert binary data to array of byte values
      # Stack Before: [... binary]
      # Stack After: [... array_of_bytes]
      private def execute_binary_to_array(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "BINARY_TO_ARRAY")

        binary_value = process.stack.pop

        unless binary_value.binary?
          raise Exceptions::TypeMismatch.new("BINARY_TO_ARRAY requires binary data")
        end

        binary = binary_value.to_binary
        array = binary.map { |byte| Value::Context.new(byte.to_i64).as(Value::Context) }

        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end
    end
  end
end
