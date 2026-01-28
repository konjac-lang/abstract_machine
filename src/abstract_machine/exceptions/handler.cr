module AbstractMachine
  module Exceptions
    # Exception handler frame for try-catch
    struct Handler
      getter catch_address : UInt64
      getter stack_size : Int32
      getter call_stack_size : Int32
      getter locals_size : Int32
      getter frame_pointer : Int32

      def initialize(@catch_address : UInt64, @stack_size : Int32, @call_stack_size : Int32, @locals_size : Int32, @frame_pointer : Int32)
      end
    end
  end
end
