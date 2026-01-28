module AbstractMachine
  module Supervisor
    module Child
      # Defines what type of child process this is
      enum Type
        Worker     # Regular process (does work, no children)
        Supervisor # Process that itself supervises other children
      end
    end
  end
end
