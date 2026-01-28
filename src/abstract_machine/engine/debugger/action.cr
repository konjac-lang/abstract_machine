module AbstractMachine
  module Engine
    module Debugger
      enum Action
        Continue # Resume normal execution
        Step     # Execute one instruction then break
        StepOver # Execute until next instruction in current call frame
        Abort    # Stop the process
      end
    end
  end
end
