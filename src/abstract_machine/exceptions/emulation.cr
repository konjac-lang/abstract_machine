module AbstractMachine
  module Exceptions
    # Context exception class for all Virtual Machine errors
    class Emulation < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
