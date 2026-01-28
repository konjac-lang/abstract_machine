module AbstractMachine
  module Exceptions
    # Raised when array index out of bounds access
    class IndexOutOfBounds < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
