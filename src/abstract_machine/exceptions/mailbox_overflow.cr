module AbstractMachine
  module Exceptions
    # Raised when a process's mailbox is full and cannot accept more messages
    class MailboxOverflow < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
