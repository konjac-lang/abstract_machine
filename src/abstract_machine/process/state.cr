module AbstractMachine
  module Process
    enum State
      ALIVE
      STALE
      WAITING # Waiting for messages
      BLOCKED # Blocked on full mailboxes
      DEAD

      def waiting? : Bool
        self == WAITING || self == BLOCKED
      end

      def runnable? : Bool
        self == ALIVE
      end
    end
  end
end
