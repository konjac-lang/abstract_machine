module AbstractMachine
  module Exceptions
    class UndefinedFunction < Exception
      def initialize(message : String? = nil, cause : Exception? = nil)
        super(message, cause)
      end
    end
  end
end
