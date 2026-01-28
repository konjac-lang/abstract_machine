module AbstractMachine
  module Process
    module Signal
      # Represents a signal sent between processes
      struct Context
        getter from : UInt64 # Process that exited
        getter reason : Reason::Context
        getter link_type : LinkType

        def initialize(@from : UInt64, @reason : Reason::Context, @link_type : LinkType = LinkType::Link)
        end

        def to_value : Value::Context
          hash = Hash(String, Value::Context).new
          hash["signal"] = Value::Context.new("EXIT")
          hash["from"] = Value::Context.new(@from.to_i64)
          hash["reason"] = @reason.to_value
          hash["link_type"] = Value::Context.new(@link_type.to_s)
          Value::Context.new(hash)
        end
      end
    end
  end
end
