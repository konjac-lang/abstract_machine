module AbstractMachine
  module Process
    # Thread-safe mailbox for actor-style message passing
    # Each process has its own isolated mailbox
    class Mailbox
      Log = ::Log.for(self)

      # Regular messages waiting to be received
      getter messages : Array(Message::Context)
      # Acknowledgments for delivered/processed messages (if enabled)
      getter acknowledgments : Array(Message::Acknowledgment)
      # Maximum number of messages before full (configurable)
      getter capacity : Int32
      # Mutex for thread-safe operations
      getter mailbox_mutex : Mutex

      def initialize(@capacity : Int32 = 100)
        @messages = [] of Message::Context
        @acknowledgments = [] of Message::Acknowledgment
        @mailbox_mutex = Mutex.new(:reentrant) # Reentrant to allow nested locks if needed
      end

      # Add a message to the mailbox
      # Returns true if successful, false if mailbox is full
      def push(message : Message::Context) : Bool
        @mailbox_mutex.synchronize do
          if @messages.size >= @capacity
            return false
          end
          @messages << message
          true
        end
      end

      # Remove and return the oldest message (FIFO)
      def shift : Message::Context?
        @mailbox_mutex.synchronize do
          @messages.shift?
        end
      end

      # Return the oldest message without removing it
      def peek : Message::Context?
        @mailbox_mutex.synchronize do
          @messages.first?
        end
      end

      # Find and remove the first message matching the given pattern
      # Used by RECEIVE_SELECT
      def select(pattern : Value::Context) : Message::Context?
        @mailbox_mutex.synchronize do
          index = @messages.index do |msg|
            matches_pattern?(msg.value, pattern)
          end

          if index
            @messages.delete_at(index)
          else
            nil
          end
        end
      end

      # Check if a message value matches a pattern
      # Supports:
      # - Null pattern → matches anything
      # - Exact value match
      # - Map pattern matching (partial map with null wildcards)
      def matches_pattern?(value : Value::Context, pattern : Value::Context) : Bool
        return true if pattern.null? # Wildcard: match any message

        if pattern.map? && value.map?
          pattern_map = pattern.to_h
          value_map = value.to_h

          pattern_map.all? do |k, v|
            value_map.has_key?(k) && (v.null? || value_map[k] == v)
          end
        else
          value == pattern
        end
      end

      # Is the mailbox empty?
      def empty? : Bool
        @mailbox_mutex.synchronize do
          @messages.empty?
        end
      end

      # Current number of messages
      def size : Int32
        @mailbox_mutex.synchronize do
          @messages.size
        end
      end

      # Remove all expired messages (based on TTL)
      def cleanup_expired_messages : Int32
        @mailbox_mutex.synchronize do
          initial_size = @messages.size
          @messages.reject!(&.expired?)
          initial_size - @messages.size
        end
      end

      # Remove message at specific index
      def remove_at(index : Int32) : Message::Context?
        @mailbox_mutex.synchronize do
          if index >= 0 && index < @messages.size
            @messages.delete_at(index)
          else
            nil
          end
        end
      end

      # Store a message acknowledgment (delivery/processed)
      def add_ack(acknowledgment : Message::Acknowledgment)
        @mailbox_mutex.synchronize do
          @acknowledgments << acknowledgment
        end
      end
    end
  end
end
