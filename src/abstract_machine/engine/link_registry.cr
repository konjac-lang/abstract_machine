module AbstractMachine
  module Engine
    # Manages bidirectional links between processes
    # When a linked process dies, all linked processes receive exit signals
    class LinkRegistry
      Log = ::Log.for(self)

      # Links are stored bidirectionally
      @links : Hash(UInt64, Set(UInt64))
      @monitors : Hash(UInt64, Set(Process::MonitorReference))     # Processes being monitored by key
      @monitored_by : Hash(UInt64, Set(Process::MonitorReference)) # Processes monitoring key
      @trap_exit : Set(UInt64)                                     # Processes that trap exits
      @mutex : Mutex

      def initialize
        @links = Hash(UInt64, Set(UInt64)).new { |h, k| h[k] = Set(UInt64).new }
        @monitors = Hash(UInt64, Set(Process::MonitorReference)).new { |h, k| h[k] = Set(Process::MonitorReference).new }
        @monitored_by = Hash(UInt64, Set(Process::MonitorReference)).new { |h, k| h[k] = Set(Process::MonitorReference).new }
        @trap_exit = Set(UInt64).new
        @mutex = Mutex.new
      end

      # Create a bidirectional link between two processes
      def link(pid1 : UInt64, pid2 : UInt64) : Bool
        return false if pid1 == pid2

        @mutex.synchronize do
          @links[pid1].add(pid2)
          @links[pid2].add(pid1)
          Log.debug { "Linked processes <#{pid1}> <-> <#{pid2}>" }
        end
        true
      end

      # Remove a bidirectional link between two processes
      def unlink(pid1 : UInt64, pid2 : UInt64) : Bool
        @mutex.synchronize do
          removed1 = @links[pid1].delete(pid2)
          removed2 = @links[pid2].delete(pid1)
          if removed1 || removed2
            Log.debug { "Unlinked processes <#{pid1}> <-> <#{pid2}>" }
            true
          else
            false
          end
        end
      end

      # Check if two processes are linked
      def linked?(pid1 : UInt64, pid2 : UInt64) : Bool
        @mutex.synchronize do
          @links[pid1].includes?(pid2)
        end
      end

      # Get all processes linked to a given process
      def get_links(process_id : UInt64) : Array(UInt64)
        @mutex.synchronize do
          @links[process_id].to_a
        end
      end

      # Create a unidirectional monitor from watcher to watched
      # Returns a Process::MonitorReference that can be used to demonitor
      def monitor(watcher : UInt64, watched : UInt64) : Process::MonitorReference
        ref = Process::MonitorReference.new(watcher, watched)

        @mutex.synchronize do
          @monitors[watcher].add(ref)
          @monitored_by[watched].add(ref)
          Log.debug { "Process <#{watcher}> monitoring <#{watched}> (ref: #{ref.id})" }
        end

        ref
      end

      # Remove a monitor by reference
      def demonitor(ref : Process::MonitorReference) : Bool
        @mutex.synchronize do
          removed1 = @monitors[ref.watcher].delete(ref)
          removed2 = @monitored_by[ref.watched].delete(ref)
          if removed1 || removed2
            Log.debug { "Demonitored ref #{ref.id}" }
            true
          else
            false
          end
        end
      end

      # Get all monitor refs for processes that watcher is monitoring
      def get_monitors(watcher : UInt64) : Array(Process::MonitorReference)
        @mutex.synchronize do
          @monitors[watcher].to_a
        end
      end

      # Get all monitor refs for processes monitoring watched
      def get_watchers(watched : UInt64) : Array(Process::MonitorReference)
        @mutex.synchronize do
          @monitored_by[watched].to_a
        end
      end

      # Enable trap_exit for a process
      # When enabled, exit signals become messages instead of killing the process
      def trap_exit(process_id : UInt64, enable : Bool = true)
        @mutex.synchronize do
          if enable
            @trap_exit.add(process_id)
            Log.debug { "Process <#{process_id}> now trapping exits" }
          else
            @trap_exit.delete(process_id)
            Log.debug { "Process <#{process_id}> no longer trapping exits" }
          end
        end
      end

      # Check if a process traps exits
      def traps_exit?(process_id : UInt64) : Bool
        @mutex.synchronize do
          @trap_exit.includes?(process_id)
        end
      end

      # Clean up all links and monitors for a process that has exited
      # Returns tuple of (linked_processes, monitor_refs_to_notify)
      def cleanup(process_id : UInt64) : Tuple(Array(UInt64), Array(Process::MonitorReference))
        @mutex.synchronize do
          # Get linked processes
          linked = @links[process_id].to_a

          # Remove from all linked processes
          linked.each do |other|
            @links[other].delete(process_id)
          end
          @links.delete(process_id)

          # Get watchers (processes monitoring this one)
          watchers = @monitored_by[process_id].to_a

          # Clean up monitor references
          watchers.each do |ref|
            @monitors[ref.watcher].delete(ref)
          end
          @monitored_by.delete(process_id)

          # Clean up monitors this process was watching
          @monitors[process_id].each do |ref|
            @monitored_by[ref.watched].delete(ref)
          end
          @monitors.delete(process_id)

          # Remove from trap_exit set
          @trap_exit.delete(process_id)

          {linked, watchers}
        end
      end

      # Get statistics about links and monitors
      def stats : NamedTuple(links: Int32, monitors: Int32, trapping: Int32)
        @mutex.synchronize do
          total_links = @links.values.map(&.size).sum // 2
          total_monitors = @monitors.values.map(&.size).sum
          {
            links:    total_links,
            monitors: total_monitors,
            trapping: @trap_exit.size,
          }
        end
      end
    end
  end
end
