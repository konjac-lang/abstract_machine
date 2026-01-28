module AbstractMachine
  module Instruction
    class Subroutine
      getter name : String
      getter instructions : Array(Operation)
      getter start_address : UInt64

      def initialize(@name : String, @instructions : Array(Operation), @start_address : UInt64)
      end
    end
  end
end
