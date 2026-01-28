module AbstractMachine
  module Supervisor
    module Child
      # Shutdown behavior for children
      enum ShutdownType
        Brutal   # Kill immediately
        Timeout  # Wait for graceful shutdown with timeout
        Infinity # Wait forever for graceful shutdown
      end
    end
  end
end
