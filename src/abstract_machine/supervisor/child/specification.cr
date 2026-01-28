module AbstractMachine
  module Supervisor
    module Child
      # Child specification for supervisor
      class Specification
        property id : String
        property instructions : Array(Instruction::Operation)
        property subroutines : Hash(String, Instruction::Subroutine)
        property globals : Hash(String, Value::Context)
        property type : Type
        property restart : RestartType
        property shutdown : ShutdownType
        property shutdown_timeout : Time::Span
        property max_restarts : Int32
        property restart_window : Time::Span

        def initialize(
          @id : String,
          @instructions : Array(Instruction::Operation) = [] of Instruction::Operation,
          @subroutines : Hash(String, Instruction::Subroutine) = {} of String => Instruction::Subroutine,
          @globals : Hash(String, Value::Context) = {} of String => Value::Context,
          @type : Type = Type::Worker,
          @restart : RestartType = RestartType::Permanent,
          @shutdown : ShutdownType = ShutdownType::Timeout,
          @shutdown_timeout : Time::Span = 5.seconds,
          @max_restarts : Int32 = 3,
          @restart_window : Time::Span = 5.seconds,
        )
        end

        def clone : Specification
          Specification.new(
            id: @id,
            instructions: @instructions.map(&.clone),
            subroutines: @subroutines.dup,
            globals: @globals.transform_values(&.clone),
            restart: @restart,
            shutdown: @shutdown,
            shutdown_timeout: @shutdown_timeout,
            max_restarts: @max_restarts,
            restart_window: @restart_window
          )
        end
      end
    end
  end
end
