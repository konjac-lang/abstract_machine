module AbstractMachine
  module Exceptions
    # Raised when an unknown or unsupported instruction is encountered
    class InvalidInstruction < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
