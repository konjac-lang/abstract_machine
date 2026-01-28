module AbstractMachine
  module BuiltInFunctions
    module TypeOperations
      extend self

      # TYPE_GET
      # Get the type of the top value as a symbol
      # Stack Before: [... value]
      # Stack After: [... type_symbol]
      # Note: Returns :null, :boolean, :integer, :unsigned_integer, :float,
      #       :string, :symbol, :array, :map, :binary, :lambda, :custom
      private def execute_type_get(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_GET")

        value = process.stack.pop

        type_symbol = case
                      when value.null?             then :null
                      when value.boolean?          then :boolean
                      when value.integer?          then :integer
                      when value.unsigned_integer? then :unsigned_integer
                      when value.float?            then :float
                      when value.string?           then :string
                      when value.symbol?           then :symbol
                      when value.array?            then :array
                      when value.map?              then :map
                      when value.binary?           then :binary
                      when value.lambda?           then :lambda
                      when value.custom?           then :custom
                      else                              :unknown
                      end

        result = Value::Context.new(type_symbol)
        process.stack.push(result)

        result
      end

      # TYPE_CHECK
      # Check if top value is of specified type
      # Operand: Symbol (type name)
      # Stack Before: [... value]
      # Stack After: [... boolean]
      private def execute_type_check(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CHECK")

        value = process.stack.pop

        # Get the type to check from operand
        type_to_check = if instruction.value.symbol?
                          instruction.value.to_symbol
                        elsif instruction.value.string?
                          instruction.value.to_s.downcase
                        else
                          raise Exceptions::TypeMismatch.new("TYPE_CHECK requires a symbol or string operand")
                        end

        is_type = check_value_type(value, type_to_check)

        result = Value::Context.new(is_type)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_STRING
      # Convert top value to its string representation
      # Stack Before: [... value]
      # Stack After: [... string]
      private def execute_type_convert_to_string(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_STRING")

        value = process.stack.pop

        result = Value::Context.new(value.to_s)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_INTEGER
      # Convert top value to integer
      # Stack Before: [... value]
      # Stack After: [... integer]
      private def execute_type_convert_to_integer(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_INTEGER")

        value = process.stack.pop

        int_val = case
                  when value.integer?
                    value.to_i64
                  when value.unsigned_integer?
                    value.to_u64.to_i64
                  when value.float?
                    value.to_f64.to_i64
                  when value.string?
                    value.to_s.to_i64? || raise Exceptions::Conversion.new(
                      "TYPE_CONVERT_TO_INTEGER cannot convert string '#{value}' to integer"
                    )
                  when value.boolean?
                    value.to_bool ? 1_i64 : 0_i64
                  when value.null?
                    0_i64
                  else
                    raise Exceptions::Conversion.new(
                      "TYPE_CONVERT_TO_INTEGER cannot convert #{value.type} to integer"
                    )
                  end

        result = Value::Context.new(int_val)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_UNSIGNED_INTEGER
      # Convert top value to unsigned integer
      # Stack Before: [... value]
      # Stack After: [... unsigned_integer]
      private def execute_type_convert_to_unsigned_integer(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_UNSIGNED_INTEGER")

        value = process.stack.pop

        uint_val = case
                   when value.unsigned_integer?
                     value.to_u64
                   when value.integer?
                     int_val = value.to_i64
                     if int_val < 0
                       raise Exceptions::Conversion.new(
                         "TYPE_CONVERT_TO_UNSIGNED_INTEGER cannot convert negative integer #{int_val}"
                       )
                     end
                     int_val.to_u64
                   when value.float?
                     float_val = value.to_f64
                     if float_val < 0
                       raise Exceptions::Conversion.new(
                         "TYPE_CONVERT_TO_UNSIGNED_INTEGER cannot convert negative float #{float_val}"
                       )
                     end
                     float_val.to_u64
                   when value.string?
                     value.to_s.to_u64? || raise Exceptions::Conversion.new(
                       "TYPE_CONVERT_TO_UNSIGNED_INTEGER cannot convert string '#{value}'"
                     )
                   when value.boolean?
                     value.to_bool ? 1_u64 : 0_u64
                   when value.null?
                     0_u64
                   else
                     raise Exceptions::Conversion.new(
                       "TYPE_CONVERT_TO_UNSIGNED_INTEGER cannot convert #{value.type}"
                     )
                   end

        result = Value::Context.new(uint_val)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_FLOAT
      # Convert top value to floating point number
      # Stack Before: [... value]
      # Stack After: [... float]
      private def execute_type_convert_to_float(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_FLOAT")

        value = process.stack.pop

        float_val = case
                    when value.float?
                      value.to_f64
                    when value.integer?
                      value.to_i64.to_f64
                    when value.unsigned_integer?
                      value.to_u64.to_f64
                    when value.string?
                      value.to_s.to_f64? || raise Exceptions::Conversion.new(
                        "TYPE_CONVERT_TO_FLOAT cannot convert string '#{value}' to float"
                      )
                    when value.boolean?
                      value.to_bool ? 1.0 : 0.0
                    when value.null?
                      0.0
                    else
                      raise Exceptions::Conversion.new(
                        "TYPE_CONVERT_TO_FLOAT cannot convert #{value.type} to float"
                      )
                    end

        result = Value::Context.new(float_val)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_BOOLEAN
      # Convert top value to boolean
      # Stack Before: [... value]
      # Stack After: [... boolean]
      # Note: null and false are falsy, everything else is truthy
      private def execute_type_convert_to_boolean(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_BOOLEAN")

        value = process.stack.pop

        result = Value::Context.new(value.to_bool)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_SYMBOL
      # Convert top value to symbol
      # Stack Before: [... value]
      # Stack After: [... symbol]
      private def execute_type_convert_to_symbol(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_SYMBOL")

        value = process.stack.pop

        symbol_val = case
                     when value.symbol?
                       value.to_symbol
                     when value.string?
                       string = value.to_s
                       if string.empty?
                         raise Exceptions::Conversion.new(
                           "TYPE_CONVERT_TO_SYMBOL cannot convert empty string to symbol"
                         )
                       end
                       string.to_symbol
                     else
                       # Convert to string first, then to symbol
                       string = value.to_s
                       if string.empty?
                         raise Exceptions::Conversion.new(
                           "TYPE_CONVERT_TO_SYMBOL cannot convert #{value.type} to symbol (empty result)"
                         )
                       end
                       string.to_symbol
                     end

        result = Value::Context.new(symbol_val)
        process.stack.push(result)

        result
      end

      # TYPE_CONVERT_TO_BINARY
      # Convert top value to binary data
      # Stack Before: [... value]
      # Stack After: [... binary]
      # Note: Strings are converted using UTF-8 encoding
      private def execute_type_convert_to_binary(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "TYPE_CONVERT_TO_BINARY")

        value = process.stack.pop

        binary_val = case
                     when value.binary?
                       value.to_binary
                     when value.string?
                       value.to_s.to_slice
                     when value.integer?
                       # Convert integer to 8-byte big-endian representation
                       int_to_binary(value.to_i64)
                     when value.unsigned_integer?
                       # Convert unsigned integer to 8-byte big-endian representation
                       uint_to_binary(value.to_u64)
                     when value.float?
                       # Convert float to 8-byte IEEE 754 representation
                       float_to_binary(value.to_f64)
                     else
                       # Default: convert to string, then to bytes
                       value.to_s.to_slice
                     end

        result = Value::Context.new(binary_val)
        process.stack.push(result)

        result
      end

      # =========================================================================
      # HELPER METHODS
      # =========================================================================

      # Check if value matches the specified type
      private def check_value_type(value : Value::Context, type_name : Symbol | String) : Bool
        type_string = type_name.to_s.downcase

        case type_string
        when "null", "nil"
          value.null?
        when "boolean", "bool"
          value.boolean?
        when "integer", "int", "int64"
          value.integer?
        when "unsigned_integer", "uint", "uint64", "unsigned"
          value.unsigned_integer?
        when "float", "float64", "double"
          value.float?
        when "str", "string"
          value.string?
        when "symbol", "sym"
          value.symbol?
        when "array", "list"
          value.array?
        when "map", "hash", "dict", "dictionary"
          value.map?
        when "binary", "bytes"
          value.binary?
        when "lambda", "function", "func"
          value.lambda?
        when "numeric", "number"
          value.numeric?
        when "custom"
          value.custom?
        else
          # Check against custom type name
          value.custom? && value.custom_type == type_name.to_s
        end
      end

      # Convert Int64 to 8-byte big-endian binary
      private def int_to_binary(value : Int64) : Slice(UInt8)
        bytes = Slice(UInt8).new(8)
        (0..7).each do |i|
          bytes[7 - i] = ((value >> (i * 8)) & 0xFF).to_u8
        end
        bytes
      end

      # Convert UInt64 to 8-byte big-endian binary
      private def uint_to_binary(value : UInt64) : Slice(UInt8)
        bytes = Slice(UInt8).new(8)
        (0..7).each do |i|
          bytes[7 - i] = ((value >> (i * 8)) & 0xFF).to_u8
        end
        bytes
      end

      # Convert Float64 to 8-byte IEEE 754 binary representation
      private def float_to_binary(value : Float64) : Slice(UInt8)
        bytes = Slice(UInt8).new(8)
        # Use unsafe to reinterpret float bits as integer
        bits = value.unsafe_as(UInt64)
        (0..7).each do |i|
          bytes[7 - i] = ((bits >> (i * 8)) & 0xFF).to_u8
        end
        bytes
      end
    end
  end
end
