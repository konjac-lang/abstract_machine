module AbstractMachine
  module Engine
    module Debugger
      class Context
        Log = ::Log.for(self)

        @breakpoints : Array(Breakpoint) = [] of Breakpoint
        @step_mode : Bool = false
        @step_over_depth : Int32? = nil
        @handler : (Process::Context, Instruction::Operation?) -> Action

        def initialize(&@handler : (Process::Context, Instruction::Operation?) -> Action)
        end

        def add_breakpoint(&condition : Process::Context -> Bool) : Breakpoint
          bp = Breakpoint.new(&condition)
          @breakpoints << bp
          bp
        end

        def add_breakpoint_at(address : UInt64) : Breakpoint
          add_breakpoint { |actual_process| actual_process.counter == address }
        end

        def remove_breakpoint(id : UInt64) : Bool
          breakpoints.reject! { |breakpoint| breakpoint.id == id }
          breakpoints.any? { |breakpoint| breakpoint.id == id }
        end

        def clear_breakpoints
          @breakpoints.clear
        end

        def breakpoints : Array(Breakpoint)
          @breakpoints
        end

        def should_break?(process : Process::Context, instruction : Instruction::Operation?) : Bool
          # Check step mode
          if @step_mode
            return true
          end

          # Check step-over mode
          if depth = @step_over_depth
            if process.call_stack.size <= depth
              @step_over_depth = nil
              return true
            end
          end

          # Check breakpoints
          @breakpoints.any?(&.check(process))
        end

        def handle(process : Process::Context, instruction : Instruction::Operation?) : Action
          @step_mode = false

          Log.debug { "Debugger: Process <#{process.address}> stopped at #{process.counter}" }

          action = @handler.call(process, instruction)

          case action
          when .step?
            @step_mode = true
          when .step_over?
            @step_over_depth = process.call_stack.size
          when .abort?
            process.state = Process::State::DEAD
          end

          action
        end

        def stepping? : Bool
          @step_mode || @step_over_depth != nil
        end

        def reset
          @step_mode = false
          @step_over_depth = nil
        end
      end
    end
  end
end
