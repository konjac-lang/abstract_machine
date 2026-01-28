module AbstractMachine
  module Lambda
    class Context
      property instructions : Array(Instruction::Operation)
      property variables : Array(String)
      property captured_environment : Hash(String, Value::Context)
      property upvalues : Array(Value::Context)

      def initialize(
        @instructions : Array(Instruction::Operation),
        @variables : Array(String) = [] of String,
        @captured_environment : Hash(String, Value::Context) = Hash(String, Value::Context).new,
        @upvalues : Array(Value::Context) = [] of Value::Context,
      )
      end

      def clone : Context
        Context.new(
          instructions: @instructions.dup,
          variables: @variables.dup,
          captured_environment: @captured_environment.transform_values(&.clone),
          upvalues: @upvalues.map(&.clone)
        )
      end
    end

    # For partial application
    class Partial < Context
      property original : Context
      property bound_arguments : Array(Value::Context)

      def initialize(@original : Context, @bound_arguments : Array(Value::Context))
        super(
          instructions: @original.instructions,
          variables: @original.variables,
          captured_environment: @original.captured_environment,
          upvalues: @original.upvalues
        )
      end
    end
  end
end
