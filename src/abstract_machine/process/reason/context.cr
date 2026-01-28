module AbstractMachine
  module Process
    # Represents the reason a process exited
    module Reason
      class Context
        getter type : Type
        getter message : String
        getter exception : Value::Context?
        getter stacktrace : Array(String)
        getter timestamp : Time

        def initialize(@type : Type, @message : String = "", @exception : Value::Context? = nil)
          @stacktrace = [] of String
          @timestamp = Time.utc
        end

        def initialize(@type : Type, @message : String, @stacktrace : Array(String))
          @exception = nil
          @timestamp = Time.utc
        end

        # Factory methods for common exit reasons
        def self.normal : Context
          new(Type::Normal, "normal")
        end

        def self.kill : Context
          new(Type::Kill, "killed")
        end

        def self.shutdown(reason : String = "shutdown") : Context
          new(Type::Shutdown, reason)
        end

        def self.exception(exception : Value::Context) : Context
          # Extract message from the AbstractMachine exception value
          message = if exception.map?
                      if msg = exception.to_h["message"]?
                        msg.to_s
                      else
                        "Unknown error"
                      end
                    else
                      exception.to_s
                    end

          reason = new(Type::Exception, message, exception)

          # Extract stacktrace from the AbstractMachine exception value
          if exception.map?
            if stacktrace_value = exception.to_h["stacktrace"]?
              if stacktrace_value.array?
                stacktrace_value.to_a.each do |frame|
                  if frame.map?
                    address = frame.to_h["address"]?.try(&.to_i64) || 0
                    instruction = frame.to_h["instruction"]?.try(&.to_s) || "unknown"
                    function = frame.to_h["function"]?.try(&.to_s)

                    frame_string = if function
                                     "#{function} @ #{address} (#{instruction})"
                                   else
                                     "@ #{address} (#{instruction})"
                                   end
                    reason.stacktrace << frame_string
                  else
                    reason.stacktrace << frame.to_s
                  end
                end
              end
            end

            # Also check for Crystal backtrace if available
            if backtrace_value = exception.to_h["crystal_backtrace"]?
              if backtrace_value.array?
                backtrace_value.to_a.each do |line|
                  reason.stacktrace << "[Crystal] #{line}"
                end
              end
            end
          end

          reason
        end

        def self.timeout : Context
          new(Type::Timeout, "timeout")
        end

        def self.invalid_process : Context
          new(Type::InvalidProcess, "invalid_process")
        end

        def self.custom(message : String) : Context
          new(Type::Custom, message)
        end

        # Check if this is a "normal" exit (shouldn't trigger restarts)
        def normal? : Bool
          @type == Type::Normal || @type == Type::Shutdown
        end

        # Check if this exit should propagate to linked processes
        def propagates? : Bool
          @type != Type::Normal
        end

        # Check if this exit can be trapped
        def trappable? : Bool
          @type != Type::Kill
        end

        def to_s : String
          case @type
          when .normal?          then "normal"
          when .kill?            then "killed"
          when .shutdown?        then "shutdown: #{@message}"
          when .exception?       then "exception: #{@message}"
          when .timeout?         then "timeout"
          when .invalid_process? then "invalid_process"
          when .custom?          then @message
          else                        "unknown"
          end
        end

        def inspect : String
          "Reason(#{@type}: #{@message})"
        end

        # Convert to a Value for message passing
        def to_value : Value::Context
          hash = Hash(String, Value::Context).new
          hash["type"] = Value::Context.new(@type.to_s)
          hash["message"] = Value::Context.new(@message)
          hash["timestamp"] = Value::Context.new(@timestamp.to_unix.to_i64)

          # Include exception details if available
          if ex = @exception
            if ex.map?
              # Copy relevant exception fields
              exception_hash = ex.to_h
              if message = exception_hash["message"]?
                hash["exception_message"] = message
              end
              if error = exception_hash["error"]?
                hash["exception_error"] = error
              end
              if stacktrace = exception_hash["stacktrace"]?
                hash["exception_stacktrace"] = stacktrace
              end
            end
          end

          Value::Context.new(hash)
        end
      end
    end
  end
end
