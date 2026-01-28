module AbstractMachine
  module Engine
    class BuiltInFunctionRegistry
      Log = ::Log.for(self)

      alias Function = Proc(Engine::Context, Process::Context, Array(Value::Context), Value::Context)

      getter table : Hash(Tuple(String, String, Int32), Function)
      getter modules : Set(String)

      def initialize
        @table = {} of Tuple(String, String, Int32) => Function
        @modules = Set(String).new
      end

      # Register a function
      def register(module_name : String, function_name : String, arity : Int32, &block : Function)
        @table[{module_name, function_name, arity}] = block
        @modules.add(module_name)
        Log.debug { "Registered #{module_name}.#{function_name}/#{arity}" }
      end

      # Call a function
      def call(engine : Engine::Context, process : Process::Context,
               module_name : String, function_name : String, arguments : Array(Value::Context)) : Value::Context
        key = {module_name, function_name, arguments.size}
        if built_in_function = @table[key]?
          Log.debug { "Process <#{process.address}>: #{module_name}.#{function_name}/#{arguments.size} args=#{arguments.map(&.inspect)}" }
          result = built_in_function.call(engine, process, arguments)
          Log.debug { "Process <#{process.address}>: #{module_name}.#{function_name}/#{arguments.size} => #{result.inspect}" }
          result
        else
          Log.error { "Process <#{process.address}>: Undefined #{module_name}.#{function_name}/#{arguments.size}" }
          raise Exceptions::UndefinedFunction.new("Undefined built-in function: #{module_name}.#{function_name}/#{arguments.size}")
        end
      end

      # Check if the function exists
      def exists?(module_name : String, function_name : String, arity : Int32) : Bool
        @table.has_key?({module_name, function_name, arity})
      end

      # List all functions for a module
      def functions(module_name : String) : Array(Tuple(String, Int32))
        @table.keys
          .select { |mod, _, _| mod == module_name }
          .map { |_, func, arity| {func, arity} }
      end

      # Get the size of the call table
      def size : Int32
        @table.size
      end
    end
  end
end
