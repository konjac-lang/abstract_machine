module AbstractMachine
  module Instruction
    class Operation
      Log = ::Log.for(self)

      getter code : Code
      getter value : Value::Context

      def initialize(@code : Code, @value : Value::Context = Value::Context.new(nil))
      end

      def clone : Operation
        Operation.new(@code, @value.clone)
      end
    end
  end
end
