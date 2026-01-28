module AbstractMachine
  module Exceptions
    # Raised when a runtime exception occurs
    class Runtime < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
