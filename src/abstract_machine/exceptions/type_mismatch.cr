module AbstractMachine
  module Exceptions
    # Raised when an instruction receives a value of the wrong type
    class TypeMismatch < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
