module AbstractMachine
  module FaultHandler
    # Crash dump storage
    class Storage
      @dumps : Array(Dump)
      @max_dumps : Int32
      @mutex : Mutex

      def initialize(@max_dumps : Int32 = 100)
        @dumps = [] of Dump
        @mutex = Mutex.new
      end

      def store(dump : Dump)
        @mutex.synchronize do
          @dumps << dump
          while @dumps.size > @max_dumps
            @dumps.shift
          end
        end
      end

      def get(address : UInt64) : Dump?
        @mutex.synchronize do
          @dumps.find { |d| d.process_address == address }
        end
      end

      def all : Array(Dump)
        @mutex.synchronize do
          @dumps.dup
        end
      end

      def recent(n : Int32 = 10) : Array(Dump)
        @mutex.synchronize do
          @dumps.last(n)
        end
      end

      def clear
        @mutex.synchronize do
          @dumps.clear
        end
      end
    end
  end
end
