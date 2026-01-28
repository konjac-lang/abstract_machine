module AbstractMachine
  module Exceptions
    # Raised when the VM detects an invalid address
    class InvalidAddress < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
