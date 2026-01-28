require "./emulation"

module AbstractMachine
  module Exceptions
    # Raised when the VM detects a deadlock situation
    class Deadlock < Emulation
    end
  end
end
