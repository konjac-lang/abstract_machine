module AbstractMachine
  module Supervisor
    module Child
      # Restart type for individual children
      enum RestartType
        Permanent # Always restart
        Transient # Restart only on abnormal exit
        Temporary # Never restart
      end
    end
  end
end
