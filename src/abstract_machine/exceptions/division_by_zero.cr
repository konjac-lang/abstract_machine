module AbstractMachine
  module Exceptions
    # Raised when division by zero
    class DivisionByZero < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
