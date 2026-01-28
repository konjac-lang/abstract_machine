module AbstractMachine
  module Exceptions
    # Raised when type conversion fails
    class Conversion < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
