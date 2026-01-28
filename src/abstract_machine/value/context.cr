module AbstractMachine
  module Value
    # Represents a dynamically-typed value in the virtual machine with support for primitive types and extensible custom types
    class Context
      getter primitive_type : PrimitiveType
      getter pointer : Pointer(Void)
      getter custom_type : ::String?

      class_getter null : Context = Context.new(nil)

      # Create a null value
      def initialize
        @primitive_type = PrimitiveType::Null
        @pointer = Pointer(Void).null
        @custom_type = nil
      end

      # Create an integer value
      def initialize(object : Int64)
        @primitive_type = PrimitiveType::Integer
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create an unsigned integer value
      def initialize(object : UInt64)
        @primitive_type = PrimitiveType::UnsignedInteger
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a float value
      def initialize(object : Float64)
        @primitive_type = PrimitiveType::Float
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a string value
      def initialize(object : String)
        @primitive_type = PrimitiveType::String
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a symbol value
      def initialize(object : Symbol)
        @primitive_type = PrimitiveType::Symbol
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a boolean value
      def initialize(object : Bool)
        @primitive_type = PrimitiveType::Boolean
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a map value
      def initialize(object : Hash(::String, Context))
        @primitive_type = PrimitiveType::Map
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create an array value
      def initialize(object : ::Array(Context))
        @primitive_type = PrimitiveType::Array
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a binary value from Slice(UInt8)
      def initialize(slice : Slice(UInt8))
        owned = Slice(UInt8).new(slice.size)
        owned.copy_from(slice)
        @primitive_type = PrimitiveType::Binary
        @pointer = Box.box(owned)
        @custom_type = nil
      end

      # Create a null value from nil
      def initialize(object : Nil)
        @primitive_type = PrimitiveType::Null
        @pointer = Pointer(Void).null
        @custom_type = nil
      end

      # Create a tuple value for (UInt64, Context) - used by SEND
      def initialize(object : Tuple(UInt64, Context))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "Tuple(UInt64, AbstractMachine::AbstractMachine::Value::Context)"
      end

      # Create a tuple value for (Context, Float64) - used by RECEIVE_TIMEOUT
      def initialize(object : Tuple(Context, Float64))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "Tuple(Context, Float64)"
      end

      # Create a tuple value for (UInt64, Context, Float64) - used by SEND_AFTER
      def initialize(object : Tuple(UInt64, Context, Float64))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "Tuple(UInt64, Context, Float64)"
      end

      # Create a tuple value for lambda creation (instructions, capture_names)
      def initialize(object : Tuple(::Array(Instruction::Operation), ::Array(::String)))
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "LambdaCreateTuple"
      end

      # Create a lambda value
      def initialize(object : Lambda::Context)
        @primitive_type = PrimitiveType::Lambda
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create an instructions value (array of operations)
      def initialize(object : ::Array(Instruction::Operation))
        @primitive_type = PrimitiveType::Instructions
        @pointer = Box.box(object)
        @custom_type = nil
      end

      # Create a monitor reference value
      def initialize(object : Process::MonitorReference)
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = "MonitorReference"
      end

      # Create a custom/generic value for any other type
      def initialize(object : Object)
        @primitive_type = PrimitiveType::Custom
        @pointer = Box.box(object)
        @custom_type = object.class.to_s
      end

      # Returns the type as a string for backward compatibility
      def type : ::String
        case @primitive_type
        when .null?             then "Null"
        when .integer?          then "Integer"
        when .unsigned_integer? then "UnsignedInteger"
        when .float?            then "Float"
        when .string?           then "String"
        when .symbol?           then "Symbol"
        when .boolean?          then "Boolean"
        when .map?              then "Map"
        when .array?            then "Array"
        when .binary?           then "Binary"
        when .lambda?           then "Lambda"
        when .instructions?     then "Instructions"
        when .custom?
          case @custom_type
          when "MonitorReference" then "MonitorReference"
          else                         @custom_type || "Unknown"
          end
        else "Unknown"
        end
      end

      # Check if value is an array
      def array? : Bool
        @primitive_type.array?
      end

      # Check if value is an integer
      def integer? : Bool
        @primitive_type.integer?
      end

      # Check if value is an unsigned integer
      def unsigned_integer? : Bool
        @primitive_type.unsigned_integer?
      end

      # Check if value is a float
      def float? : Bool
        @primitive_type.float?
      end

      # Check if value is a string
      def string? : Bool
        @primitive_type.string?
      end

      # Check if value is a symbol
      def symbol? : Bool
        @primitive_type.symbol?
      end

      # Check if value is a boolean
      def boolean? : Bool
        @primitive_type.boolean?
      end

      # Check if value is a map
      def map? : Bool
        @primitive_type.map?
      end

      # Check if value is binary
      def binary? : Bool
        @primitive_type.binary?
      end

      # Check if value is null
      def null? : Bool
        @primitive_type.null?
      end

      # Check if value is a lambda
      def lambda? : Bool
        @primitive_type.lambda?
      end

      # Check if value is an instruction array
      def instructions? : Bool
        @primitive_type.instructions?
      end

      # Check if value is a monitor reference
      def monitor_reference? : Bool
        @primitive_type.custom? && @custom_type == "MonitorReference"
      end

      # Check if value is a custom type
      def custom? : Bool
        @primitive_type.custom?
      end

      # Check if value is numeric (integer, unsigned integer, or float)
      def numeric? : Bool
        @primitive_type.integer? || @primitive_type.unsigned_integer? || @primitive_type.float?
      end

      # Check if value is a tuple type
      def tuple? : Bool
        @primitive_type.custom? && @custom_type.try(&.starts_with?("Tuple")) || false
      end

      # Check if value is a lambda create tuple
      def lambda_create_tuple? : Bool
        @primitive_type.custom? && @custom_type == "LambdaCreateTuple"
      end

      # Convert value to Int64
      def to_i64 : Int64
        case @primitive_type
        when .integer?          then Box(Int64).unbox(@pointer)
        when .unsigned_integer? then Box(UInt64).unbox(@pointer).to_i64
        when .float?            then Box(Float64).unbox(@pointer).to_i64
        when .boolean?          then Box(Bool).unbox(@pointer) ? 1_i64 : 0_i64
        else
          raise Exceptions::Emulation.new("Cannot convert #{type} to integer")
        end
      end

      # Convert value to UInt64
      def to_u64 : UInt64
        case @primitive_type
        when .unsigned_integer? then Box(UInt64).unbox(@pointer)
        when .integer?
          value = Box(Int64).unbox(@pointer)
          raise Exceptions::Emulation.new("Cannot convert negative integer to unsigned integer") if value < 0
          value.to_u64
        when .float?
          value = Box(Float64).unbox(@pointer)
          raise Exceptions::Emulation.new("Cannot convert negative float to unsigned integer") if value < 0
          value.to_u64
        when .boolean? then Box(Bool).unbox(@pointer) ? 1_u64 : 0_u64
        else
          raise Exceptions::Emulation.new("Cannot convert #{type} to unsigned integer")
        end
      end

      # Convert value to Float64
      def to_f64 : Float64
        case @primitive_type
        when .float?            then Box(Float64).unbox(@pointer)
        when .integer?          then Box(Int64).unbox(@pointer).to_f64
        when .unsigned_integer? then Box(UInt64).unbox(@pointer).to_f64
        when .boolean?          then Box(Bool).unbox(@pointer) ? 1.0 : 0.0
        else
          raise Exceptions::Emulation.new("Cannot convert #{type} to float")
        end
      end

      # Convert value to String
      def to_s : ::String
        case @primitive_type
        when .null?             then "null"
        when .integer?          then Box(Int64).unbox(@pointer).to_s
        when .unsigned_integer? then Box(UInt64).unbox(@pointer).to_s
        when .float?            then Box(Float64).unbox(@pointer).to_s
        when .boolean?          then Box(Bool).unbox(@pointer).to_s
        when .string?           then Box(::String).unbox(@pointer)
        when .symbol?           then Box(Symbol).unbox(@pointer).to_s
        when .map?
          hash = Box(Hash(::String, Context)).unbox(@pointer)
          "{#{hash.map { |k, v| "#{k}: #{v}" }.join(", ")}}"
        when .array?
          arr = Box(::Array(Context)).unbox(@pointer)
          "[#{arr.map(&.to_s).join(", ")}]"
        when .binary?
          slice = Box(Slice(UInt8)).unbox(@pointer)
          "<Binary(#{slice.size} bytes)>"
        when .lambda?
          lambda = Box(Lambda::Context).unbox(@pointer)
          "<Lambda(#{lambda.variables.size} params, #{lambda.instructions.size} instructions)>"
        when .instructions?
          instructions = Box(::Array(Instruction::Operation)).unbox(@pointer)
          "<Instructions(#{instructions.size})>"
        when .custom?
          if @custom_type == "MonitorReference"
            ref = to_monitor_reference
            "#<Monitor #{ref.id} watcher:#{ref.watcher} → #{ref.watched}>"
          else
            "<#{@custom_type}>"
          end
        else
          "<unknown>"
        end
      end

      # Convert value to Symbol
      def to_symbol : Symbol
        raise Exceptions::Emulation.new("Cannot convert #{type} to symbol") unless symbol?
        Box(Symbol).unbox(@pointer)
      end

      # Convert value to Bool
      def to_bool : Bool
        case @primitive_type
        when .boolean?          then Box(Bool).unbox(@pointer)
        when .integer?          then Box(Int64).unbox(@pointer) != 0_i64
        when .unsigned_integer? then Box(UInt64).unbox(@pointer) != 0_u64
        when .float?            then Box(Float64).unbox(@pointer) != 0.0
        when .string?           then !Box(::String).unbox(@pointer).empty?
        when .symbol?           then !to_s.empty?
        when .map?              then !Box(Hash(::String, Context)).unbox(@pointer).empty?
        when .array?            then !Box(::Array(Context)).unbox(@pointer).empty?
        when .binary?           then !to_binary.empty?
        when .null?             then false
        when .lambda?           then true
        when .instructions?     then !to_instructions.empty?
        when .custom?
          if @custom_type == "MonitorReference"
            true
          else
            true
          end
        else false
        end
      end

      # Convert value to Hash
      def to_h : Hash(::String, Context)
        raise Exceptions::Emulation.new("Cannot convert #{type} to hash") unless @primitive_type.map?
        Box(Hash(::String, Context)).unbox(@pointer)
      end

      # Convert value to Array
      def to_a : ::Array(Context)
        raise Exceptions::Emulation.new("Cannot convert #{type} to array") unless @primitive_type.array?
        Box(::Array(Context)).unbox(@pointer)
      end

      # Convert value to Slice(UInt8)
      def to_binary : Slice(UInt8)
        raise Exceptions::Emulation.new("Cannot convert #{type} to binary") unless binary?
        Box(Slice(UInt8)).unbox(@pointer)
      end

      # Unbox as Tuple(UInt64, Context)
      def to_send_tuple : Tuple(UInt64, Context)
        unless @custom_type == "Tuple(UInt64, AbstractMachine::AbstractMachine::Value::Context)"
          raise Exceptions::Emulation.new("Cannot convert #{type} to Tuple(UInt64, Context)")
        end
        Box(Tuple(UInt64, Context)).unbox(@pointer)
      end

      # Unbox as Tuple(Context, Float64)
      def to_receive_timeout_tuple : Tuple(Context, Float64)
        unless @custom_type == "Tuple(Context, Float64)"
          raise Exceptions::Emulation.new("Cannot convert #{type} to Tuple(Context, Float64)")
        end
        Box(Tuple(Context, Float64)).unbox(@pointer)
      end

      # Unbox as Tuple(UInt64, Context, Float64)
      def to_send_after_tuple : Tuple(UInt64, Context, Float64)
        unless @custom_type == "Tuple(UInt64, Context, Float64)"
          raise Exceptions::Emulation.new("Cannot convert #{type} to Tuple(UInt64, Context, Float64)")
        end
        Box(Tuple(UInt64, Context, Float64)).unbox(@pointer)
      end

      # Unbox as lambda creation tuple (instructions, capture_names)
      def to_lambda_create_tuple : Tuple(::Array(Instruction::Operation), ::Array(::String))
        unless @custom_type == "LambdaCreateTuple"
          raise Exceptions::Emulation.new("Cannot convert #{type} to LambdaCreateTuple")
        end
        Box(Tuple(::Array(Instruction::Operation), ::Array(::String))).unbox(@pointer)
      end

      # Convert value to instruction array
      def to_instructions : ::Array(Instruction::Operation)
        raise Exceptions::TypeMismatch.new("Cannot convert #{type} to instructions") unless instructions?
        Box(::Array(Instruction::Operation)).unbox(@pointer)
      end

      # Convert value to Process::MonitorReference
      def to_monitor_reference : Process::MonitorReference
        unless monitor_reference?
          raise Exceptions::Emulation.new("Cannot convert #{type} to MonitorReference")
        end
        Box(Process::MonitorReference).unbox(@pointer)
      end

      # Convert value to Lambda::Context
      def to_lambda : Lambda::Context
        raise Exceptions::Emulation.new("Cannot convert #{type} to lambda") unless @primitive_type.lambda?
        Box(Lambda::Context).unbox(@pointer)
      end

      # Create a deep copy of the value
      def clone : Context
        case @primitive_type
        when .null?             then Context.null
        when .integer?          then Context.new(to_i64)
        when .unsigned_integer? then Context.new(to_u64)
        when .float?            then Context.new(to_f64)
        when .string?           then Context.new(Box(::String).unbox(@pointer).dup)
        when .symbol?           then Context.new(to_symbol)
        when .boolean?          then Context.new(to_bool)
        when .map?
          cloned_hash = Hash(::String, Context).new
          to_h.each { |k, v| cloned_hash[k] = v.clone }
          Context.new(cloned_hash)
        when .array?        then Context.new(to_a.map(&.clone))
        when .binary?       then Context.new(to_binary)
        when .lambda?       then Context.new(to_lambda.clone)
        when .instructions? then Context.new(to_instructions.map(&.clone))
        when .custom?
          if @custom_type == "MonitorReference"
            Context.new(to_monitor_reference) # struct → value copy
          else
            self # Most custom types are not cloned deeply
          end
        else
          raise Exceptions::TypeMismatch.new("Cannot clone unsupported value type: #{type}")
        end
      end

      # Check equality between two values
      def ==(other : Context) : Bool
        return false unless @primitive_type == other.primitive_type
        case @primitive_type
        when .null?             then true
        when .integer?          then to_i64 == other.to_i64
        when .unsigned_integer? then to_u64 == other.to_u64
        when .float?            then to_f64 == other.to_f64
        when .string?           then to_s == other.to_s
        when .symbol?           then to_symbol == other.to_symbol
        when .boolean?          then to_bool == other.to_bool
        when .map?              then to_h == other.to_h
        when .array?            then to_a == other.to_a
        when .binary?           then to_binary == other.to_binary
        when .lambda?           then @pointer == other.pointer
        when .instructions?     then @pointer == other.pointer # Reference equality
        when .custom?
          if @custom_type == "MonitorReference" && other.custom_type == "MonitorReference"
            to_monitor_reference == other.to_monitor_reference
          else
            @custom_type == other.custom_type && @pointer == other.pointer
          end
        else
          false
        end
      end

      # Return the raw string value for inspection
      def inspect : ::String
        case @primitive_type
        when .null?   then "null"
        when .string? then "\"#{to_s}\""
        when .symbol? then ":#{to_s}"
        when .binary? then "<<#{to_binary.join(", ")}>>"
        else               "#{to_s}"
        end
      end
    end
  end
end
