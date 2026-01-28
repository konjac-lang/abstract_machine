module AbstractMachine
  module Exceptions
    # Raised when jump target is invalid
    class InvalidJumpTarget < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
