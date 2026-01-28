module AbstractMachine
  module Exceptions
    # Raised when an undefined variable is referenced
    class UndefinedVariable < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
