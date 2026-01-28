module AbstractMachine
  module Message
    class Acknowledgment
      property message_id : UInt64
      property receiver : UInt64
      property status : Symbol # :delivered, :processed, :rejected, :timed_out

      def initialize(@message_id : UInt64, @receiver : UInt64, @status : Symbol)
      end
    end
  end
end
