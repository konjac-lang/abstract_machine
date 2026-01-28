module AbstractMachine
  module Exceptions
    # Raised when an unhandled exception occurs
    class Unhandled < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
