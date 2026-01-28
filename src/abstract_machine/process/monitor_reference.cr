module AbstractMachine
  module Process
    # Monitor reference for tracking monitors
    struct MonitorReference
      getter id : UInt64
      getter watcher : UInt64
      getter watched : UInt64
      getter created_at : Time

      @@counter : UInt64 = 0_u64

      def initialize(@watcher : UInt64, @watched : UInt64)
        @id = @@counter += 1
        @created_at = Time.utc
      end

      def ==(other : MonitorReference) : Bool
        @id == other.id
      end

      def hash(hasher)
        hasher = @id.hash(hasher)
        hasher
      end
    end
  end
end
