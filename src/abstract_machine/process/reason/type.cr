module AbstractMachine
  module Process
    module Reason
      enum Type
        Normal         # Clean shutdown
        Kill           # Forcefully killed (untrappable)
        Shutdown       # Requested shutdown (trappable)
        Exception      # Crashed with exception
        Timeout        # Timed out waiting
        InvalidProcess # Target process doesn't exist
        Custom         # User-defined reason
      end
    end
  end
end
