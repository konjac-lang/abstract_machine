module AbstractMachine
  module Extensions
    class Symbol
      @@map = Array(String).new
      @@head : UInt64 = (:Symbol.unsafe_as(Pointer(Void)).address & 0xffffffff00000000_u64) + 0xFFFFFFFF

      def self.for(s : String)
        i = @@map.index(s) || (raise AbstractMachine::AbstractMachine::Exceptions::Emulation.new("You've reached a dangerous amount of runtime symbols - good luck! (sadly Crystal doesn't support symbols and requires such hacks)") if @@map.size >= 0xFFFFFFFF; @@map << s; @@map.size - 1)
        Pointer(Void).new(@@head - i).unsafe_as ::Symbol
      end

      def self.to_s(sym : ::Symbol)
        (j = sym.to_i) < 0 ? @@map[(j*-1) - 1] : nil
      end
    end
  end
end
