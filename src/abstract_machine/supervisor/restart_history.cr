module AbstractMachine
  module Supervisor
    # Tracks restart history for a child
    class RestartHistory
      property restarts : Array(Time)
      property specification : Child::Specification

      def initialize(@specification : Child::Specification)
        @restarts = [] of Time
      end

      # Record a restart and check if we've exceeded the limit
      def record_restart : Bool
        now = Time.utc

        # Remove old restarts outside the window
        cutoff = now - @specification.restart_window
        @restarts.reject! { |t| t < cutoff }

        # Add new restart
        @restarts << now

        # Check if we've exceeded the limit
        @restarts.size <= @specification.max_restarts
      end

      def restart_count : Int32
        now = Time.utc
        cutoff = now - @specification.restart_window
        @restarts.count { |t| t >= cutoff }
      end

      def clear
        @restarts.clear
      end
    end
  end
end
