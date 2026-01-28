module AbstractMachine
  module Exceptions
    # Raised when the encoding fails
    class Encoding < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
