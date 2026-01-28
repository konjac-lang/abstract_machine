require "concurrent"

module AbstractMachine
  module Message
    class Context
      property sender : UInt64
      property value : Value::Context
      property id : UInt64
      property needs_ack : Bool
      property timestamp : Time
      property ttl : Time::Span?

      @@next_id : UInt64 = 1_u64
      @@id_mutex = Mutex.new

      def initialize(
        @sender : UInt64,
        @value : Value::Context,
        @needs_ack : Bool = false,
        @ttl : Time::Span? = nil,
      )
        @id = @@id_mutex.synchronize do
          current = @@next_id
          @@next_id += 1
          current
        end
        @timestamp = Time.utc
      end

      # Returns true if the message has a TTL and has expired
      def expired? : Bool
        if ttl = @ttl
          Time.utc > @timestamp + ttl
        else
          false # No TTL → never expires
        end
      end
    end
  end
end
