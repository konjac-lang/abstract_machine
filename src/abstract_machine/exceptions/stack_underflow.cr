module AbstractMachine
  module Exceptions
    # Raised when a stack underflow occurs
    class StackUnderflow < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
