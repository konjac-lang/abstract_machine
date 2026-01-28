module AbstractMachine
  module InstructionExecutor
    module ProcessLifecycleOperations
      extend self

      # PROCESS_SPAWN
      # Spawn a new process with given instruction array
      # Stack Before: [... instructions]
      # Stack After: [... new_process_id]
      private def execute_process_spawn(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_SPAWN")

        instructions_value = process.stack.pop

        instructions = if instructions_value.instructions?
                         instructions_value.to_instructions
                       elsif instructions_value.lambda?
                         instructions_value.to_lambda.instructions
                       else
                         raise Exceptions::TypeMismatch.new("PROCESS_SPAWN requires instructions or lambda")
                       end

        new_process = @engine.create_process(instructions: instructions)
        new_process.parent = process.address if new_process.responds_to?(:parent=)

        @engine.processes << new_process
        @engine.scheduler.enqueue(new_process)

        result = Value::Context.new(new_process.address.to_i64)
        process.stack.push(result)

        result
      end

      # PROCESS_SPAWN_LINKED
      # Spawn new process and link it to current process atomically
      # Stack Before: [... instructions]
      # Stack After: [... new_process_id]
      private def execute_process_spawn_linked(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_SPAWN_LINKED")

        instructions_value = process.stack.pop

        instructions = if instructions_value.instructions?
                         instructions_value.to_instructions
                       elsif instructions_value.lambda?
                         instructions_value.to_lambda.instructions
                       else
                         raise Exceptions::TypeMismatch.new("PROCESS_SPAWN_LINKED requires instructions or lambda")
                       end

        new_process = @engine.create_process(instructions: instructions)
        new_process.parent = process.address if new_process.responds_to?(:parent=)

        # Create bidirectional link atomically
        @engine.link_registry.link(process.address, new_process.address)

        @engine.processes << new_process
        @engine.scheduler.enqueue(new_process)

        result = Value::Context.new(new_process.address.to_i64)
        process.stack.push(result)

        result
      end

      # PROCESS_SPAWN_MONITORED
      # Spawn new process and monitor it from current process
      # Stack Before: [... instructions]
      # Stack After: [... new_process_id, monitor_reference]
      private def execute_process_spawn_monitored(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_SPAWN_MONITORED")

        instructions_value = process.stack.pop

        instructions = if instructions_value.instructions?
                         instructions_value.to_instructions
                       elsif instructions_value.lambda?
                         instructions_value.to_lambda.instructions
                       else
                         raise Exceptions::TypeMismatch.new("PROCESS_SPAWN_MONITORED requires instructions or lambda")
                       end

        new_process = @engine.create_process(instructions: instructions)
        new_process.parent = process.address if new_process.responds_to?(:parent=)

        # Create unidirectional monitor
        monitor_ref = @engine.link_registry.monitor(process.address, new_process.address)

        @engine.processes << new_process
        @engine.scheduler.enqueue(new_process)

        # Push both process ID and monitor reference
        process.stack.push(Value::Context.new(new_process.address.to_i64))
        process.stack.push(Value::Context.new(monitor_ref))

        Value::Context.new(new_process.address.to_i64)
      end

      # PROCESS_SELF
      # Push current process ID onto stack
      # Stack Before: [...]
      # Stack After: [... self_process_id]
      private def execute_process_self(process : Process::Context) : Value::Context
        process.counter += 1

        result = Value::Context.new(process.address.to_i64)
        process.stack.push(result)

        result
      end

      # PROCESS_EXIT
      # Terminate current process with reason
      # Stack Before: [... reason]
      # Stack After: N/A (process terminated)
      private def execute_process_exit(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_EXIT")

        reason_value = process.stack.pop
        reason_string = reason_value.to_s

        reason = case reason_string
                 when "normal" then Process::Reason::Context.normal
                 when "kill"   then Process::Reason::Context.kill
                 else               Process::Reason::Context.custom(reason_string)
                 end

        process.state = Process::State::DEAD
        process.reason = reason

        # Notify linked and monitoring processes
        @engine.fault_handler.handle_exit(process, reason)
        @engine.scheduler.mark_dead(process)

        Value::Context.null
      end

      # PROCESS_EXIT_REMOTE
      # Send exit signal to another process
      # Stack Before: [... target_process_id, reason]
      # Stack After: [...]
      private def execute_process_exit_remote(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "PROCESS_EXIT_REMOTE")

        reason_value = process.stack.pop
        target_value = process.stack.pop

        unless target_value.integer? || target_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_EXIT_REMOTE requires an integer process ID")
        end

        target_process_id = target_value.to_i64.to_u64
        reason_string = reason_value.to_s

        reason = case reason_string
                 when "normal" then Process::Reason::Context.normal
                 when "kill"   then Process::Reason::Context.kill
                 else               Process::Reason::Context.custom(reason_string)
                 end

        @engine.fault_handler.exit_process(process.address, target_process_id, reason)

        Value::Context.null
      end

      # PROCESS_KILL
      # Force terminate a process (untrappable)
      # Stack Before: [... target_process_id]
      # Stack After: [...]
      private def execute_process_kill(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_KILL")

        target_value = process.stack.pop

        unless target_value.integer? || target_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_KILL requires an integer process ID")
        end

        target_process_id = target_value.to_i64.to_u64
        target = @engine.processes.find { |actual_process| actual_process.address == target_process_id && actual_process.state != Process::State::DEAD }

        if target
          target.state = Process::State::DEAD
          target.reason = Process::Reason::Context.kill

          # Kill is untrappable - directly handle exit
          @engine.fault_handler.handle_exit(target, Process::Reason::Context.kill)
          @engine.scheduler.mark_dead(target)
        end

        Value::Context.null
      end

      # PROCESS_SLEEP
      # Pause current process execution for duration
      # Stack Before: [... seconds]
      # Stack After: [...]
      private def execute_process_sleep(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_SLEEP")

        duration_value = process.stack.pop

        unless duration_value.numeric?
          raise Exceptions::TypeMismatch.new("PROCESS_SLEEP requires a numeric duration in seconds")
        end

        seconds = duration_value.to_f64

        if seconds > 0
          process.state = Process::State::WAITING
          process.waiting_since = Time.utc
          process.waiting_timeout = seconds.seconds

          @engine.scheduler.enqueue(process)
        end

        Value::Context.null
      end

      # PROCESS_YIELD
      # Voluntarily yield execution to scheduler
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_process_yield(process : Process::Context) : Value::Context
        process.counter += 1

        # Re-enqueue process at end of queue
        @engine.scheduler.yield_process(process)

        Value::Context.null
      end

      # PROCESS_LINK
      # Create bidirectional link between processes
      # Stack Before: [... other_process_id]
      # Stack After: [...]
      private def execute_process_link(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_LINK")

        other_value = process.stack.pop

        unless other_value.integer? || other_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_LINK requires an integer process ID")
        end

        other_process_id = other_value.to_i64.to_u64

        # Verify target process exists
        target = @engine.processes.find { |actual_process| actual_process.address == other_process_id && actual_process.state != Process::State::DEAD }

        if target
          @engine.link_registry.link(process.address, other_process_id)
        else
          # Linking to dead/non-existent process - send exit signal if trapping
          if @engine.link_registry.traps_exit?(process.address)
            # Send DOWN message
            down_msg = create_down_message(other_process_id, Process::Reason::Context.invalid_process)
            process.mailbox.push(down_msg)
          else
            # Terminate this process
            process.state = Process::State::DEAD
            process.reason = Process::Reason::Context.invalid_process
            @engine.fault_handler.handle_exit(process, Process::Reason::Context.invalid_process)
          end
        end

        Value::Context.null
      end

      # PROCESS_UNLINK
      # Remove bidirectional link between processes
      # Stack Before: [... other_process_id]
      # Stack After: [...]
      private def execute_process_unlink(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_UNLINK")

        other_value = process.stack.pop

        unless other_value.integer? || other_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_UNLINK requires an integer process ID")
        end

        other_process_id = other_value.to_i64.to_u64

        @engine.link_registry.unlink(process.address, other_process_id)

        Value::Context.null
      end

      # PROCESS_MONITOR
      # Create unidirectional monitor of another process
      # Stack Before: [... target_process_id]
      # Stack After: [... monitor_reference]
      private def execute_process_monitor(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_MONITOR")

        target_value = process.stack.pop

        unless target_value.integer? || target_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_MONITOR requires an integer process ID")
        end

        target_process_id = target_value.to_i64.to_u64
        target = @engine.processes.find { |actual_process| actual_process.address == target_process_id }

        monitor_ref = @engine.link_registry.monitor(process.address, target_process_id)

        # If target is already dead, send immediate DOWN message
        if target.nil? || target.state == Process::State::DEAD
          reason = target ? (target.reason || Process::Reason::Context.normal) : Process::Reason::Context.invalid_process
          down_msg = create_down_message(target_process_id, reason, monitor_ref.id)
          process.mailbox.push(down_msg)
        end

        result = Value::Context.new(monitor_ref)
        process.stack.push(result)

        result
      end

      # PROCESS_DEMONITOR
      # Remove monitor of another process
      # Stack Before: [... monitor_reference]
      # Stack After: [... success_boolean]
      private def execute_process_demonitor(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_DEMONITOR")

        reference_value = process.stack.pop

        unless reference_value.monitor_reference?
          raise Exceptions::TypeMismatch.new("PROCESS_DEMONITOR requires a monitor reference")
        end

        monitor_ref = reference_value.to_monitor_reference
        success = @engine.link_registry.demonitor(monitor_ref)

        result = Value::Context.new(success)
        process.stack.push(result)

        result
      end

      # PROCESS_TRAP_EXIT_ENABLE
      # Enable exit signal trapping for current process
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_process_trap_exit_enable(process : Process::Context) : Value::Context
        process.counter += 1

        @engine.link_registry.trap_exit(process.address, true)
        process.flags["trap_exit"] = Value::Context.new(true)

        Value::Context.null
      end

      # PROCESS_TRAP_EXIT_DISABLE
      # Disable exit signal trapping for current process
      # Stack Before: [...]
      # Stack After: [...]
      private def execute_process_trap_exit_disable(process : Process::Context) : Value::Context
        process.counter += 1

        @engine.link_registry.trap_exit(process.address, false)
        process.flags["trap_exit"] = Value::Context.new(false)

        Value::Context.null
      end

      # PROCESS_IS_ALIVE
      # Check if a process is alive
      # Stack Before: [... process_id]
      # Stack After: [... boolean]
      private def execute_process_is_alive(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_IS_ALIVE")

        pid_value = process.stack.pop

        unless pid_value.integer? || pid_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_IS_ALIVE requires an integer process ID")
        end

        process_id = pid_value.to_i64.to_u64
        target = @engine.processes.find { |actual_process| actual_process.address == process_id }

        alive = target && target.state != Process::State::DEAD

        result = Value::Context.new(alive)
        process.stack.push(result)

        result
      end

      # PROCESS_GET_INFO
      # Get information about a process
      # Stack Before: [... process_id]
      # Stack After: [... info_map_or_null]
      private def execute_process_get_info(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_GET_INFO")

        pid_value = process.stack.pop

        unless pid_value.integer? || pid_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("PROCESS_GET_INFO requires an integer process ID")
        end

        process_id = pid_value.to_i64.to_u64
        target = @engine.processes.find { |actual_process| actual_process.address == process_id }

        if target
          info = build_process_info(target)
          result = Value::Context.new(info)
        else
          result = Value::Context.null # null
        end

        process.stack.push(result)
        result
      end

      # PROCESS_REGISTER
      # Register current process with a name
      # Operand: String (name)
      # Stack Before: [...]
      # Stack After: [... success_boolean]
      private def execute_process_register(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("PROCESS_REGISTER requires a string name operand")
        end

        name = instruction.value.to_s

        success = @engine.process_registry.register(name, process.address)

        if success
          process.registered_name = name
        end

        result = Value::Context.new(success)
        process.stack.push(result)

        result
      end

      # PROCESS_UNREGISTER
      # Remove name registration
      # Operand: String (name)
      # Stack Before: [...]
      # Stack After: [... success_boolean]
      private def execute_process_unregister(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("PROCESS_UNREGISTER requires a string name operand")
        end

        name = instruction.value.to_s

        # Only allow unregistering if this process owns the name
        current_owner = @engine.process_registry.lookup(name)
        success = current_owner == process.address && @engine.process_registry.unregister(name)

        if success && process.registered_name == name
          process.registered_name = nil
        end

        result = Value::Context.new(success)
        process.stack.push(result)

        result
      end

      # PROCESS_WHEREIS
      # Look up process ID by registered name
      # Operand: String (name)
      # Stack Before: [...]
      # Stack After: [... process_id_or_null]
      private def execute_process_whereis(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("PROCESS_WHEREIS requires a string name operand")
        end

        name = instruction.value.to_s

        if process_id = @engine.process_registry.lookup(name)
          result = Value::Context.new(process_id.to_i64)
        else
          result = Value::Context.null # null
        end

        process.stack.push(result)
        result
      end

      # PROCESS_SET_FLAG
      # Set a process flag
      # Stack Before: [... flag_name, value]
      # Stack After: [... old_value]
      private def execute_process_set_flag(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "PROCESS_SET_FLAG")

        new_value = process.stack.pop
        flag_name_value = process.stack.pop

        unless flag_name_value.string? || flag_name_value.symbol?
          raise Exceptions::TypeMismatch.new("PROCESS_SET_FLAG requires a string or symbol flag name")
        end

        flag_name = flag_name_value.to_s
        old_value = process.flags[flag_name]? || Value::Context.null

        process.flags[flag_name] = new_value

        # Handle special flags
        if flag_name == "trap_exit"
          @engine.link_registry.trap_exit(process.address, new_value.to_bool)
        end

        process.stack.push(old_value)
        old_value
      end

      # PROCESS_GET_FLAG
      # Get a process flag value
      # Stack Before: [... flag_name]
      # Stack After: [... value]
      private def execute_process_get_flag(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "PROCESS_GET_FLAG")

        flag_name_value = process.stack.pop

        unless flag_name_value.string? || flag_name_value.symbol?
          raise Exceptions::TypeMismatch.new("PROCESS_GET_FLAG requires a string or symbol flag name")
        end

        flag_name = flag_name_value.to_s
        value = process.flags[flag_name]? || Value::Context.null

        process.stack.push(value)
        value
      end

      # Build process info map
      private def build_process_info(target : Process::Context) : Hash(String, Value::Context)
        info = Hash(String, Value::Context).new

        info["address"] = Value::Context.new(target.address.to_i64)
        info["state"] = Value::Context.new(target.state.to_s)
        info["registered_name"] = target.registered_name ? Value::Context.new(target.registered_name.not_nil!) : Value::Context.null
        info["mailbox_size"] = Value::Context.new(target.mailbox.size.to_i64)
        info["stack_size"] = Value::Context.new(target.stack.size.to_i64)
        info["counter"] = Value::Context.new(target.counter.to_i64)
        info["reductions"] = Value::Context.new(target.reductions.to_i64)
        info["priority"] = Value::Context.new(target.priority.to_s)
        info["created_at"] = Value::Context.new(target.created_at.to_unix.to_i64)
        info["parent"] = target.parent ? Value::Context.new(target.parent.not_nil!.to_i64) : Value::Context.null

        # Get links
        links = @engine.link_registry.get_links(target.address)
        info["links"] = Value::Context.new(links.map { |l| Value::Context.new(l.to_i64).as(Value::Context) })

        # Get monitors
        monitors = @engine.link_registry.get_monitors(target.address)
        info["monitors"] = Value::Context.new(monitors.map { |m| Value::Context.new(m).as(Value::Context) })

        info["trap_exit"] = Value::Context.new(@engine.link_registry.traps_exit?(target.address))

        info
      end

      # Create a DOWN message for monitor notifications
      private def create_down_message(
        target_process_id : UInt64,
        reason : Process::Reason::Context,
        monitor_ref : UInt64? = nil,
      ) : Message::Context
        down_info = Hash(String, Value::Context).new
        down_info["type"] = Value::Context.new(:down)
        down_info["process"] = Value::Context.new(target_process_id.to_i64)
        down_info["reason"] = Value::Context.new(reason.to_s)
        down_info["monitor_ref"] = monitor_ref ? Value::Context.new(monitor_ref.to_i64) : Value::Context.null

        Message::Context.new(
          sender: 0_u64, # System message
          value: Value::Context.new(down_info),
          needs_ack: false,
          ttl: nil
        )
      end
    end
  end
end
