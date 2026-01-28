module AbstractMachine
  module Process
    # DOWN message sent when monitored process exits
    struct DownMessage
      getter ref : MonitorReference
      getter process : UInt64
      getter reason : Reason::Context

      def initialize(@ref : MonitorReference, @process : UInt64, @reason : Reason::Context)
      end

      def to_value : Value::Context
        hash = Hash(String, Value::Context).new
        hash["signal"] = Value::Context.new("DOWN")
        hash["ref"] = Value::Context.new(@ref.id.to_i64)
        hash["process"] = Value::Context.new(@process.to_i64)
        hash["reason"] = @reason.to_value
        Value::Context.new(hash)
      end
    end
  end
end
