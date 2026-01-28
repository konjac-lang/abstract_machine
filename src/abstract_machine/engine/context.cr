require "./**"

module AbstractMachine
  module Engine
    class Context
      Log = ::Log.for(self)

      property processes : Array(Process::Context) = [] of Process::Context
      property configuration : Configuration = Configuration.new
      property custom_handlers : Hash(Instruction::Code, Handler) = {} of Instruction::Code => Handler
      property process_registry : ProcessRegistry = ProcessRegistry.new
      property delayed_messages : Array(Tuple(Time, UInt64, UInt64, Value::Context)) = [] of Tuple(Time, UInt64, UInt64, Value::Context)
      property reactivation_queue : Array(Process::Context) = [] of Process::Context
      property last_cleanup_time : Time = Time.utc
      property debugger : Debugger::Context? = nil

      # Built-in function registry
      property built_in_function_registry : BuiltInFunctionRegistry = BuiltInFunctionRegistry.new

      # Fault tolerance properties
      property link_registry : LinkRegistry = LinkRegistry.new
      property supervisor_registry : SupervisorRegistry = SupervisorRegistry.new
      property timer_manager : TimerManager = TimerManager.new
      property storage : FaultHandler::Storage = FaultHandler::Storage.new

      @executor : InstructionExecutor::Context?
      @fault_handler : FaultHandler::Context?
      @scheduler : Scheduler?

      @next_process_address : UInt64 = 1_u64

      def initialize
        Log.debug { "Initializing the Engine" }
      end

      def executor : InstructionExecutor::Context
        @executor ||= InstructionExecutor::Context.new(self)
      end

      def fault_handler : FaultHandler::Context
        @fault_handler ||= FaultHandler::Context.new(self)
      end

      def scheduler : Scheduler
        @scheduler ||= Scheduler.new(self)
      end

      def on_instruction(code : Code, &block : Process::Context, Instruction::Operation -> Value::Context)
        @custom_handlers[code] = Handler.new(&block)
      end

      def attach_debugger(&handler : (Process::Context, Instruction::Operation?) -> Debugger::Action) : Debugger::Context
        @debugger = Debugger::Context.new(&handler)
        @debugger.not_nil!
      end

      def detach_debugger
        @debugger = nil
      end

      def execute(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        return Value::Context.null if process.state != Process::State::ALIVE

        if debug_action = check_debugger(process, instruction)
          return Value::Context.null if debug_action.abort?
        end

        process.reductions += 1 if process.responds_to?(:reductions)

        begin
          executor.execute(process, instruction)
        rescue ex : Exceptions::Emulation
          handle_process_exception(process, ex)
          Value::Context.new(ex)
        rescue ex : Exception
          handle_process_exception(process, ex)
          Value::Context.new(ex)
        end
      end

      def call_built_in_function(process : Process::Context, module_name : String, function_name : String, arguments : Array(Value::Context)) : Value::Context
        @built_in_function_registry.call(self, process, module_name, function_name, arguments)
      end

      def register_built_in_function(module_name : String, function_name : String, arity : Int32, &block : BuiltInFunctionRegistry::Function)
        @built_in_function_registry.register(module_name, function_name, arity, &block)
      end

      def handle_process_exception(process : Process::Context, exception : Exception)
        Log.error { "Process <#{process.address}>: #{exception.message}" }

        return if executor.handle_execution_exception(process, exception)
        return if FaultHandler::Recovery.try_recover(self, process, exception)

        mark_process_dead(process, exception)
      end

      def queue_process_for_reactivation(process : Process::Context)
        @reactivation_queue << process unless @reactivation_queue.includes?(process)
      end

      def schedule_delayed_message(sender : UInt64, recipient : UInt64, value : Value::Context, delay_seconds : Float64)
        delivery_time = Time.utc + delay_seconds.seconds
        @delayed_messages << {delivery_time, sender, recipient, value}
        Log.debug { "Scheduled message from <0.#{sender}> to <0.#{recipient}> for delivery at #{delivery_time}" }
      end

      def check_blocked_sends(process : Process::Context)
        @processes.each do |actual_process|
          next unless actual_process.state == Process::State::BLOCKED
          try_unblock_send(actual_process, process)
        end
      end

      def deliver_delayed_messages : Int32
        messages_delivered = 0

        # Handle timer_manager scheduled messages
        timer_manager.get_due_timers.each do |_, sender, recipient, value|
          if deliver_single_message(sender, recipient, value)
            messages_delivered += 1
          end
        end

        # Handle legacy delayed_messages (if still used)
        now = Time.utc
        messages_to_deliver = @delayed_messages.select { |time, _, _, _| time <= now }

        messages_to_deliver.each do |_, sender, recipient, value|
          if deliver_single_message(sender, recipient, value)
            messages_delivered += 1
          end
        end

        @delayed_messages.reject! { |time, _, _, _| time <= now }
        messages_delivered
      end

      def run
        fault_handler.start
        iterations = 0

        loop do
          iterations += 1

          break if iterations >= @configuration.iteration_limit

          Log.debug { "Scheduler stats: #{scheduler.stats}" }

          perform_scheduler_checks
          process = scheduler.next_runnable
          Log.debug { "Next runnable process: #{process ? "<#{process.address}>" : "nil"}" }

          unless process
            Log.debug { "No runnable process, checking if scheduler has work..." }
            if scheduler.has_work?
              Log.debug { "Scheduler has work (waiting/blocked processes), sleeping..." }
              sleep 1.millisecond
              next
            else
              Log.debug { "Scheduler has no work, breaking loop" }
              break
            end
          end

          Log.debug { "Executing process <#{process.address}>" }
          execute_process_slice(process)
          handle_process_result(process)

          Fiber.yield
        end

        fault_handler.stop
        Log.info { "VM completed after #{iterations} iterations" }
      end

      def create_supervisor(
        strategy : Supervisor::RestartStrategy = Supervisor::RestartStrategy::OneForOne,
        max_restarts : Int32 = 3,
        restart_window : Time::Span = 5.seconds,
      ) : Supervisor::Context
        sup_process = create_process(instructions: [] of Instruction::Operation)
        @processes << sup_process

        supervisor = Supervisor::Context.new(self, sup_process.address, strategy, max_restarts, restart_window)
        @supervisor_registry.register(supervisor)
        supervisor
      end

      def spawn_process(instructions : Array(Instruction::Operation)) : Process::Context
        process = create_process(instructions: instructions)
        @processes << process
        scheduler.enqueue(process)
        process
      end

      def spawn_link(parent : Process::Context, instructions : Array(Instruction::Operation)) : Process::Context
        child = create_process(instructions: instructions)
        child.parent = parent.address if child.responds_to?(:parent=)
        @processes << child
        @link_registry.link(parent.address, child.address)
        scheduler.enqueue(child)
        child
      end

      def spawn_monitor(parent : Process::Context, instructions : Array(Instruction::Operation)) : Tuple(Process::Context, Process::MonitorReference)
        child = create_process(instructions: instructions)
        child.parent = parent.address if child.responds_to?(:parent=)
        @processes << child
        ref = @link_registry.monitor(parent.address, child.address)
        scheduler.enqueue(child)
        {child, ref}
      end

      def exit_process(process_id : UInt64, reason : String)
        reason_value = map_reason_string(reason)
        fault_handler.kill_process(process_id, reason_value)
      end

      def fault_tolerance_statistics : NamedTuple(links: Int32, monitors: Int32, trapping: Int32, supervisors: Int32, crash_dumps: Int32)
        link_statistics = @link_registry.stats
        {
          links:       link_statistics[:links],
          monitors:    link_statistics[:monitors],
          trapping:    link_statistics[:trapping],
          supervisors: @supervisor_registry.all.size,
          crash_dumps: @storage.all.size,
        }
      end

      def inspect_process(address : UInt64) : String?
        process = processes.find { |actual_process| actual_process.address == address }
        return nil unless process

        {
          address:       process.address,
          state:         process.state,
          counter:       process.counter,
          stack:         process.stack.map(&.to_s),
          mailbox:       process.mailbox.size,
          call_stack:    process.call_stack.to_a,
          frame_pointer: process.frame_pointer,
          links:         @link_registry.get_links(process.address),
          traps_exit:    @link_registry.traps_exit?(process.address),
        }.to_json
      end

      def create_process(
        instructions : Array(Instruction::Operation) = [] of Instruction::Operation,
        start_address : UInt64 = 0_u64,
      ) : Process::Context
        process = Process::Context.new(@next_process_address, instructions)
        @next_process_address += 1
        process.counter = start_address
        Log.debug { "Created Process <#{process.address}>" }
        process
      end

      private def check_debugger(process : Process::Context, instruction : Instruction::Operation)
        return nil unless dbg = @debugger
        return nil unless dbg.should_break?(process, instruction)
        dbg.handle(process, instruction)
      end

      private def mark_process_dead(process : Process::Context, exception : Exception)
        process.state = Process::State::DEAD
        process.exception_handlers.clear

        exception_value = build_exception_value(exception, process)
        reason = Process::Reason::Context.exception(exception_value)
        process.reason = reason if process.responds_to?(:reason=)

        dump = FaultHandler::Recovery.create_crash_dump(process, reason)
        @storage.store(dump)

        fault_handler.handle_exit(process, reason)
      end

      private def build_exception_value(exception : Exception, process : Process::Context) : Value::Context
        if executor.responds_to?(:build_exception_value_from_crystal)
          executor.build_exception_value_from_crystal(exception, process)
        else
          hash = Hash(String, Value::Context).new
          hash["type"] = Value::Context.new(:exception)
          hash["message"] = Value::Context.new(exception.message || "Unknown error")
          hash["error"] = Value::Context.new(exception.class.name)
          Value::Context.new(hash)
        end
      end

      private def try_unblock_send(blocked_process : Process::Context, target_process : Process::Context)
        blocked_process.blocked_sends.each_with_index do |(target_address, message), index|
          if target_address == target_process.address && target_process.mailbox.size < @configuration.max_mailbox_size
            if target_process.mailbox.push(message)
              Log.debug { "Unblocked send from <0.#{blocked_process.address}> to <0.#{target_process.address}>" }
              blocked_process.blocked_sends.delete_at(index)
              blocked_process.remove_dependency(target_process.address)

              if blocked_process.blocked_sends.empty?
                blocked_process.state = Process::State::ALIVE
                queue_process_for_reactivation(blocked_process)
              end

              return
            end
          end
        end
      end

      private def deliver_single_message(sender : UInt64, recipient : UInt64, value : Value::Context) : Bool
        target = processes.find { |actual_process| actual_process.address == recipient && actual_process.state != Process::State::DEAD }
        return false unless target

        message = Message::Context.new(sender, value, @configuration.enable_message_acknowledgments?)
        return false unless target.mailbox.size < @configuration.max_mailbox_size && target.mailbox.push(message)

        Log.debug { "Delivered delayed message from <0.#{sender}> to <0.#{recipient}>" }

        if target.state == Process::State::WAITING ||
           (target.state == Process::State::STALE && @configuration.auto_reactivate_processes?)
          if target.waiting_for.nil? ||
             target.mailbox.matches_pattern?(message.value, target.waiting_for.not_nil!)
            queue_process_for_reactivation(target)
          end
        end

        true
      end

      private def perform_scheduler_checks
        deliver_delayed_messages
        process_reactivation_queue
        scheduler.check_timeouts
        scheduler.check_blocked
      end

      private def process_reactivation_queue
        while process = @reactivation_queue.shift?
          Log.debug { "Reactivating process <#{process.address}>" }
          scheduler.make_runnable(process)
        end
      end

      private def handle_no_runnable_processes
        if scheduler.has_work?
          sleep 1.millisecond
        else
          return
        end
      end

      private def execute_process_slice(process : Process::Context)
        process.reductions = 0_u64
        max_reductions = @configuration.max_reductions_per_slice

        while process.reductions < max_reductions && process.state.alive?
          break if process.counter >= process.instructions.size

          instruction = process.instructions[process.counter]
          execute(process, instruction)
        end
      end

      private def handle_process_result(process : Process::Context)
        case process.state
        when .alive?
          if process.counter >= process.instructions.size
            process.state = Process::State::DEAD
            scheduler.mark_dead(process)
            fault_handler.handle_exit(process, Process::Reason::Context.normal)
          else
            scheduler.yield_process(process)
          end
        when .waiting?
          # Already handled by the instruction that set the state
        when .blocked?
          # Already handled by the instruction that set the state
        when .dead?
          # Process is already dead, nothing to do here
        end
      end

      private def map_reason_string(reason : String) : Process::Reason::Context
        case reason
        when "normal"   then Process::Reason::Context.normal
        when "kill"     then Process::Reason::Context.kill
        when "shutdown" then Process::Reason::Context.shutdown
        else                 Process::Reason::Context.custom(reason)
        end
      end
    end
  end
end
