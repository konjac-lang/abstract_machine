module AbstractMachine
  module Exceptions
    # Raised when a stack overflow occurs
    class StackOverflow < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
