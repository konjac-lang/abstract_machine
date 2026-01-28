module AbstractMachine
  module Exceptions
    # Raised when subroutine is undefined
    class UndefinedSubroutine < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
