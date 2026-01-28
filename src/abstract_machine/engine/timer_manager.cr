module AbstractMachine
  module Engine
    class TimerManager
      Log = ::Log.for(self)

      @timers : Hash(UInt64, Tuple(Time, UInt64, UInt64, Value::Context))
      @next_id : UInt64

      def initialize
        @timers = {} of UInt64 => Tuple(Time, UInt64, UInt64, Value::Context)
        @next_id = 0_u64
      end

      # Schedule a message to be sent after a delay
      def schedule_message(
        sender : UInt64,
        target : UInt64,
        message : Value::Context,
        delay : Time::Span,
      ) : UInt64
        id = @next_id
        @next_id += 1

        delivery_time = Time.utc + delay
        @timers[id] = {delivery_time, sender, target, message}

        Log.debug { "Timer #{id}: scheduled message from <#{sender}> to <#{target}> for delivery at #{delivery_time}" }

        id
      end

      # Cancel a scheduled timer
      def cancel(timer_ref : UInt64) : Bool
        if @timers.has_key?(timer_ref)
          @timers.delete(timer_ref)
          Log.debug { "Timer #{timer_ref}: cancelled" }
          true
        else
          Log.debug { "Timer #{timer_ref}: not found (already fired or invalid)" }
          false
        end
      end

      # Get all timers that are due for delivery
      def get_due_timers : Array(Tuple(UInt64, UInt64, UInt64, Value::Context))
        now = Time.utc
        due = [] of Tuple(UInt64, UInt64, UInt64, Value::Context)

        @timers.each do |id, (delivery_time, sender, target, message)|
          if delivery_time <= now
            due << {id, sender, target, message}
          end
        end

        # Remove the due timers
        due.each { |id, _, _, _| @timers.delete(id) }

        due
      end

      # Check if there are any pending timers
      def has_pending? : Bool
        !@timers.empty?
      end

      # Get the time until the next timer fires (for sleep optimization)
      def time_until_next : Time::Span?
        return nil if @timers.empty?

        now = Time.utc
        min_time = @timers.values.min_of { |delivery_time, _, _, _| delivery_time }

        span = min_time - now
        span > Time::Span.zero ? span : Time::Span.zero
      end

      # Get count of pending timers
      def size : Int32
        @timers.size
      end

      # Clear all timers
      def clear
        @timers.clear
        Log.debug { "All timers cleared" }
      end
    end
  end
end
