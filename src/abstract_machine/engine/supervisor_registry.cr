module AbstractMachine
  module Engine
    # Registry for supervisors
    class SupervisorRegistry
      @supervisors : Hash(UInt64, Supervisor::Context)
      @mutex : Mutex

      def initialize
        @supervisors = {} of UInt64 => Supervisor::Context
        @mutex = Mutex.new
      end

      def register(supervisor : Supervisor::Context)
        @mutex.synchronize do
          @supervisors[supervisor.address] = supervisor
        end
      end

      def unregister(address : UInt64)
        @mutex.synchronize do
          @supervisors.delete(address)
        end
      end

      def get(address : UInt64) : Supervisor::Context?
        @mutex.synchronize do
          @supervisors[address]?
        end
      end

      def find_supervisor_of(process_id : UInt64) : Supervisor::Context?
        @mutex.synchronize do
          @supervisors.values.find do |sup|
            sup.children.any? { |(_, child_process_id)| child_process_id == process_id }
          end
        end
      end

      def all : Array(Supervisor::Context)
        @mutex.synchronize do
          @supervisors.values.dup
        end
      end
    end
  end
end
