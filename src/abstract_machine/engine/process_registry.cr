module AbstractMachine
  module Engine
    # Process Registry for named processes
    class ProcessRegistry
      Log = ::Log.for(self)

      property processes : Hash(String, UInt64)
      property registry_mutex : Mutex

      def initialize
        @processes = {} of String => UInt64
        @registry_mutex = Mutex.new
      end

      def register(name : String, process_address : UInt64) : Bool
        @registry_mutex.synchronize do
          if @processes.has_key?(name)
            return false
          end
          @processes[name] = process_address
          true
        end
      end

      def unregister(name : String) : Bool
        @registry_mutex.synchronize do
          @processes.delete(name) != nil
        end
      end

      def lookup(name : String) : UInt64?
        @registry_mutex.synchronize do
          @processes[name]?
        end
      end

      def registered_names : Array(String)
        @registry_mutex.synchronize do
          @processes.keys.to_a
        end
      end
    end
  end
end
