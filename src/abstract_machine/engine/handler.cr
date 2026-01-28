module AbstractMachine
  module Engine
    class Handler
      @block : Process::Context, Instruction::Operation -> Value::Context

      def initialize(&block : Process::Context, Instruction::Operation -> Value::Context)
        @block = block
      end

      def call(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        @block.call(process, instruction)
      end
    end
  end
end
