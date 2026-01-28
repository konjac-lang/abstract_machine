module AbstractMachine
  module BuiltInFunctions
    module StringOperations
      extend self

      # STRING_CONCATENATE
      # Concatenate two strings
      # Stack Before: [... string1, string2]
      # Stack After: [... (string1 + string2)]
      private def execute_string_concatenate(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_CONCATENATE")

        string2 = process.stack.pop
        string1 = process.stack.pop

        unless string1.string? && string2.string?
          raise Exceptions::TypeMismatch.new("STRING_CONCATENATE requires two string values")
        end

        result = Value::Context.new(string1.to_s + string2.to_s)
        process.stack.push(result)

        result
      end

      # STRING_LENGTH
      # Get the length of a string in characters
      # Stack Before: [... string]
      # Stack After: [... length]
      private def execute_string_length(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_LENGTH")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_LENGTH requires a string value")
        end

        result = Value::Context.new(string.to_s.size.to_i64)
        process.stack.push(result)

        result
      end

      # STRING_SUBSTRING
      # Extract a substring from a string
      # Stack Before: [... string, start_index, length]
      # Stack After: [... substring]
      private def execute_string_substring(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STRING_SUBSTRING")

        length = process.stack.pop
        start_index = process.stack.pop
        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_SUBSTRING requires a string value")
        end

        unless (start_index.integer? || start_index.unsigned_integer?) &&
               (length.integer? || length.unsigned_integer?)
          raise Exceptions::TypeMismatch.new("STRING_SUBSTRING requires integer start_index and length")
        end

        str = string.to_s
        start_i = start_index.to_i64.to_i32
        len = length.to_i64.to_i32

        if start_i < 0 || start_i > str.size
          raise Exceptions::IndexOutOfBounds.new("STRING_SUBSTRING start index #{start_i} out of bounds (string length: #{str.size})")
        end

        result = Value::Context.new(str[start_i, len]? || "")
        process.stack.push(result)

        result
      end

      # STRING_INDEX_OF
      # Find first index of substring (returns -1 if not found)
      # Stack Before: [... string, search_string]
      # Stack After: [... index]
      private def execute_string_index_of(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_INDEX_OF")

        search_string = process.stack.pop
        string = process.stack.pop

        unless string.string? && search_string.string?
          raise Exceptions::TypeMismatch.new("STRING_INDEX_OF requires two string values")
        end

        index = string.to_s.index(search_string.to_s)
        result = Value::Context.new(index ? index.to_i64 : -1_i64)
        process.stack.push(result)

        result
      end

      # STRING_LAST_INDEX_OF
      # Find last index of substring (returns -1 if not found)
      # Stack Before: [... string, search_string]
      # Stack After: [... index]
      private def execute_string_last_index_of(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_LAST_INDEX_OF")

        search_string = process.stack.pop
        string = process.stack.pop

        unless string.string? && search_string.string?
          raise Exceptions::TypeMismatch.new("STRING_LAST_INDEX_OF requires two string values")
        end

        index = string.to_s.rindex(search_string.to_s)
        result = Value::Context.new(index ? index.to_i64 : -1_i64)
        process.stack.push(result)

        result
      end

      # STRING_SPLIT
      # Split string by delimiter into array of strings
      # Stack Before: [... string, delimiter]
      # Stack After: [... array_of_strings]
      private def execute_string_split(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_SPLIT")

        delimiter = process.stack.pop
        string = process.stack.pop

        unless string.string? && delimiter.string?
          raise Exceptions::TypeMismatch.new("STRING_SPLIT requires two string values")
        end

        parts = string.to_s.split(delimiter.to_s)
        array = parts.map { |actual_process| Value::Context.new(actual_process).as(Value::Context) }

        result = Value::Context.new(array)
        process.stack.push(result)

        result
      end

      # STRING_JOIN
      # Join array of strings with separator
      # Stack Before: [... array_of_strings, separator]
      # Stack After: [... joined_string]
      private def execute_string_join(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_JOIN")

        separator = process.stack.pop
        array_value = process.stack.pop

        unless array_value.array?
          raise Exceptions::TypeMismatch.new("STRING_JOIN requires an array as first argument")
        end

        unless separator.string?
          raise Exceptions::TypeMismatch.new("STRING_JOIN requires a string separator")
        end

        array = array_value.to_a
        strings = array.map do |value|
          value.to_s # Allow any type, convert to string
        end

        result = Value::Context.new(strings.join(separator.to_s))
        process.stack.push(result)

        result
      end

      # STRING_TRIM
      # Remove leading and trailing whitespace
      # Stack Before: [... string]
      # Stack After: [... trimmed_string]
      private def execute_string_trim(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_TRIM")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_TRIM requires a string value")
        end

        result = Value::Context.new(string.to_s.strip)
        process.stack.push(result)

        result
      end

      # STRING_TRIM_START
      # Remove leading whitespace only
      # Stack Before: [... string]
      # Stack After: [... trimmed_string]
      private def execute_string_trim_start(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_TRIM_START")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_TRIM_START requires a string value")
        end

        result = Value::Context.new(string.to_s.lstrip)
        process.stack.push(result)

        result
      end

      # STRING_TRIM_END
      # Remove trailing whitespace only
      # Stack Before: [... string]
      # Stack After: [... trimmed_string]
      private def execute_string_trim_end(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_TRIM_END")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_TRIM_END requires a string value")
        end

        result = Value::Context.new(string.to_s.rstrip)
        process.stack.push(result)

        result
      end

      # STRING_TO_UPPERCASE
      # Convert string to uppercase
      # Stack Before: [... string]
      # Stack After: [... uppercase_string]
      private def execute_string_to_uppercase(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_TO_UPPERCASE")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_TO_UPPERCASE requires a string value")
        end

        result = Value::Context.new(string.to_s.upcase)
        process.stack.push(result)

        result
      end

      # STRING_TO_LOWERCASE
      # Convert string to lowercase
      # Stack Before: [... string]
      # Stack After: [... lowercase_string]
      private def execute_string_to_lowercase(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_TO_LOWERCASE")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_TO_LOWERCASE requires a string value")
        end

        result = Value::Context.new(string.to_s.downcase)
        process.stack.push(result)

        result
      end

      # STRING_REPLACE
      # Replace all occurrences of substring
      # Stack Before: [... string, search_string, replacement_string]
      # Stack After: [... result_string]
      private def execute_string_replace(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STRING_REPLACE")

        replacement = process.stack.pop
        search = process.stack.pop
        string = process.stack.pop

        unless string.string? && search.string? && replacement.string?
          raise Exceptions::TypeMismatch.new("STRING_REPLACE requires three string values")
        end

        result = Value::Context.new(string.to_s.gsub(search.to_s, replacement.to_s))
        process.stack.push(result)

        result
      end

      # STRING_REPLACE_FIRST
      # Replace first occurrence of substring only
      # Stack Before: [... string, search_string, replacement_string]
      # Stack After: [... result_string]
      private def execute_string_replace_first(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STRING_REPLACE_FIRST")

        replacement = process.stack.pop
        search = process.stack.pop
        string = process.stack.pop

        unless string.string? && search.string? && replacement.string?
          raise Exceptions::TypeMismatch.new("STRING_REPLACE_FIRST requires three string values")
        end

        result = Value::Context.new(string.to_s.sub(search.to_s, replacement.to_s))
        process.stack.push(result)

        result
      end

      # STRING_STARTS_WITH
      # Test if string starts with prefix
      # Stack Before: [... string, prefix]
      # Stack After: [... boolean]
      private def execute_string_starts_with(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_STARTS_WITH")

        prefix = process.stack.pop
        string = process.stack.pop

        unless string.string? && prefix.string?
          raise Exceptions::TypeMismatch.new("STRING_STARTS_WITH requires two string values")
        end

        result = Value::Context.new(string.to_s.starts_with?(prefix.to_s))
        process.stack.push(result)

        result
      end

      # STRING_ENDS_WITH
      # Test if string ends with suffix
      # Stack Before: [... string, suffix]
      # Stack After: [... boolean]
      private def execute_string_ends_with(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_ENDS_WITH")

        suffix = process.stack.pop
        string = process.stack.pop

        unless string.string? && suffix.string?
          raise Exceptions::TypeMismatch.new("STRING_ENDS_WITH requires two string values")
        end

        result = Value::Context.new(string.to_s.ends_with?(suffix.to_s))
        process.stack.push(result)

        result
      end

      # STRING_CONTAINS
      # Test if string contains substring
      # Stack Before: [... string, search_string]
      # Stack After: [... boolean]
      private def execute_string_contains(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_CONTAINS")

        search_string = process.stack.pop
        string = process.stack.pop

        unless string.string? && search_string.string?
          raise Exceptions::TypeMismatch.new("STRING_CONTAINS requires two string values")
        end

        result = Value::Context.new(string.to_s.includes?(search_string.to_s))
        process.stack.push(result)

        result
      end

      # STRING_CHARACTER_AT
      # Get character at specified index as single-character string
      # Stack Before: [... string, index]
      # Stack After: [... character_string]
      private def execute_string_character_at(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_CHARACTER_AT")

        index = process.stack.pop
        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_CHARACTER_AT requires a string value")
        end

        unless index.integer? || index.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STRING_CHARACTER_AT requires an integer index")
        end

        str = string.to_s
        idx = index.to_i64.to_i32

        if idx < 0 || idx >= str.size
          raise Exceptions::IndexOutOfBounds.new("STRING_CHARACTER_AT index #{idx} out of bounds (string length: #{str.size})")
        end

        result = Value::Context.new(str[idx].to_s)
        process.stack.push(result)

        result
      end

      # STRING_CHARACTER_CODE_AT
      # Get Unicode code point of character at index
      # Stack Before: [... string, index]
      # Stack After: [... code_point]
      private def execute_string_character_code_at(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_CHARACTER_CODE_AT")

        index = process.stack.pop
        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_CHARACTER_CODE_AT requires a string value")
        end

        unless index.integer? || index.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STRING_CHARACTER_CODE_AT requires an integer index")
        end

        str = string.to_s
        idx = index.to_i64.to_i32

        if idx < 0 || idx >= str.size
          raise Exceptions::IndexOutOfBounds.new("STRING_CHARACTER_CODE_AT index #{idx} out of bounds (string length: #{str.size})")
        end

        result = Value::Context.new(str[idx].ord.to_i64)
        process.stack.push(result)

        result
      end

      # STRING_FROM_CHARACTER_CODE
      # Create single-character string from Unicode code point
      # Stack Before: [... code_point]
      # Stack After: [... character_string]
      private def execute_string_from_character_code(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_FROM_CHARACTER_CODE")

        code_point = process.stack.pop

        unless code_point.integer? || code_point.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STRING_FROM_CHARACTER_CODE requires an integer code point")
        end

        code = code_point.to_i64.to_i32

        if code < 0 || code > 0x10FFFF
          raise Exceptions::Value.new("STRING_FROM_CHARACTER_CODE invalid Unicode code point: #{code}")
        end

        begin
          char = code.chr
          result = Value::Context.new(char.to_s)
          process.stack.push(result)
          result
        rescue
          raise Exceptions::Value.new("STRING_FROM_CHARACTER_CODE invalid Unicode code point: #{code}")
        end
      end

      # STRING_REPEAT
      # Repeat string a specified number of times
      # Stack Before: [... string, count]
      # Stack After: [... repeated_string]
      private def execute_string_repeat(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STRING_REPEAT")

        count = process.stack.pop
        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_REPEAT requires a string value")
        end

        unless count.integer? || count.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STRING_REPEAT requires an integer count")
        end

        n = count.to_i64.to_i32

        if n < 0
          raise Exceptions::Value.new("STRING_REPEAT count cannot be negative: #{n}")
        end

        result = Value::Context.new(string.to_s * n)
        process.stack.push(result)

        result
      end

      # STRING_REVERSE
      # Reverse the characters in a string
      # Stack Before: [... string]
      # Stack After: [... reversed_string]
      private def execute_string_reverse(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_REVERSE")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_REVERSE requires a string value")
        end

        result = Value::Context.new(string.to_s.reverse)
        process.stack.push(result)

        result
      end

      # STRING_PAD_START
      # Pad string at start to reach target length
      # Stack Before: [... string, target_length, pad_string]
      # Stack After: [... padded_string]
      private def execute_string_pad_start(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STRING_PAD_START")

        pad_string = process.stack.pop
        target_length = process.stack.pop
        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_PAD_START requires a string value")
        end

        unless target_length.integer? || target_length.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STRING_PAD_START requires an integer target_length")
        end

        unless pad_string.string?
          raise Exceptions::TypeMismatch.new("STRING_PAD_START requires a string pad_string")
        end

        str = string.to_s
        target = target_length.to_i64.to_i32
        pad = pad_string.to_s

        if pad.empty?
          raise Exceptions::Value.new("STRING_PAD_START pad_string cannot be empty")
        end

        result = if str.size >= target
                   Value::Context.new(str)
                 else
                   padding_needed = target - str.size
                   full_padding = (pad * ((padding_needed // pad.size) + 1))[0, padding_needed]
                   Value::Context.new(full_padding + str)
                 end

        process.stack.push(result)
        result
      end

      # STRING_PAD_END
      # Pad string at end to reach target length
      # Stack Before: [... string, target_length, pad_string]
      # Stack After: [... padded_string]
      private def execute_string_pad_end(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STRING_PAD_END")

        pad_string = process.stack.pop
        target_length = process.stack.pop
        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_PAD_END requires a string value")
        end

        unless target_length.integer? || target_length.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STRING_PAD_END requires an integer target_length")
        end

        unless pad_string.string?
          raise Exceptions::TypeMismatch.new("STRING_PAD_END requires a string pad_string")
        end

        str = string.to_s
        target = target_length.to_i64.to_i32
        pad = pad_string.to_s

        if pad.empty?
          raise Exceptions::Value.new("STRING_PAD_END pad_string cannot be empty")
        end

        result = if str.size >= target
                   Value::Context.new(str)
                 else
                   padding_needed = target - str.size
                   full_padding = (pad * ((padding_needed // pad.size) + 1))[0, padding_needed]
                   Value::Context.new(str + full_padding)
                 end

        process.stack.push(result)
        result
      end

      # STRING_CONVERT_TO_BINARY
      # Convert string to binary data using UTF-8 encoding
      # Stack Before: [... string]
      # Stack After: [... binary]
      private def execute_string_convert_to_binary(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STRING_CONVERT_TO_BINARY")

        string = process.stack.pop

        unless string.string?
          raise Exceptions::TypeMismatch.new("STRING_CONVERT_TO_BINARY requires a string value")
        end

        result = Value::Context.new(string.to_s.to_slice)
        process.stack.push(result)

        result
      end
    end
  end
end
