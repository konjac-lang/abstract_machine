module AbstractMachine
  module Supervisor
    # Supervision strategy determines how to handle child failures
    enum RestartStrategy
      OneForOne       # Only restart the failed child
      OneForAll       # Restart all children when one fails
      RestForOne      # Restart the failed child and all children started after it
      SimpleOneForOne # Like one_for_one but for dynamic children with same spec
    end
  end
end
