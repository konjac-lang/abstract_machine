module AbstractMachine
  module InstructionExecutor
    module SupervisorOperations
      extend self

      # SUPERVISOR_START_CHILD
      # Start a child process under supervisor
      # Stack Before: [... supervisor_process_id, child_specification]
      # Stack After: [... child_process_id]
      # Note: child_specification is a map with restart strategy
      private def execute_supervisor_start_child(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "SUPERVISOR_START_CHILD")

        child_spec_value = process.stack.pop
        supervisor_value = process.stack.pop

        unless supervisor_value.integer? || supervisor_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("SUPERVISOR_START_CHILD requires integer supervisor process ID")
        end

        unless child_spec_value.map?
          raise Exceptions::TypeMismatch.new("SUPERVISOR_START_CHILD requires a map child specification")
        end

        supervisor_process_id = supervisor_value.to_i64.to_u64

        # Get the supervisor
        supervisor = @engine.supervisor_registry.get(supervisor_process_id)
        unless supervisor
          raise Exceptions::Runtime.new("SUPERVISOR_START_CHILD target #{supervisor_process_id} is not a supervisor")
        end

        # Parse child specification
        child_spec = parse_child_specification(child_spec_value.to_h)

        # Start the child
        child_process_id = supervisor.add_child(child_spec)

        if child_process_id
          result = Value::Context.new(child_process_id.to_i64)
        else
          raise Exceptions::Runtime.new("SUPERVISOR_START_CHILD failed to start child")
        end

        process.stack.push(result)
        result
      end

      # SUPERVISOR_STOP_CHILD
      # Stop a supervised child process
      # Stack Before: [... supervisor_process_id, child_id]
      # Stack After: [... success_boolean]
      private def execute_supervisor_stop_child(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "SUPERVISOR_STOP_CHILD")

        child_id_value = process.stack.pop
        supervisor_value = process.stack.pop

        unless supervisor_value.integer? || supervisor_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("SUPERVISOR_STOP_CHILD requires integer supervisor process ID")
        end

        supervisor_process_id = supervisor_value.to_i64.to_u64

        # Get the supervisor
        supervisor = @engine.supervisor_registry.get(supervisor_process_id)
        unless supervisor
          raise Exceptions::Runtime.new("SUPERVISOR_STOP_CHILD target #{supervisor_process_id} is not a supervisor")
        end

        # Resolve child ID
        child_id = resolve_child_id(child_id_value)

        # Find and stop the child
        child_process_id = if child_id.is_a?(String)
                             supervisor.whereis(child_id)
                           else
                             child_id.as(UInt64)
                           end

        success = false
        if child_process_id
          # Find child index and terminate
          child_index = supervisor.children.index { |(spec, process_id)| process_id == child_process_id }
          if child_index
            spec, _ = supervisor.children[child_index]

            # Get the process and terminate it
            child_process = @engine.processes.find { |actual_process| actual_process.address == child_process_id }
            if child_process
              child_process.state = Process::State::DEAD
              child_process.reason = Process::Reason::Context.normal
              @engine.scheduler.mark_dead(child_process)
            end

            # Update supervisor's child list
            supervisor.children[child_index] = {spec, nil}
            success = true
          end
        end

        result = Value::Context.new(success)
        process.stack.push(result)

        result
      end

      # SUPERVISOR_RESTART_CHILD
      # Restart a supervised child process
      # Stack Before: [... supervisor_process_id, child_id]
      # Stack After: [... new_child_process_id]
      private def execute_supervisor_restart_child(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "SUPERVISOR_RESTART_CHILD")

        child_id_value = process.stack.pop
        supervisor_value = process.stack.pop

        unless supervisor_value.integer? || supervisor_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("SUPERVISOR_RESTART_CHILD requires integer supervisor process ID")
        end

        supervisor_process_id = supervisor_value.to_i64.to_u64

        # Get the supervisor
        supervisor = @engine.supervisor_registry.get(supervisor_process_id)
        unless supervisor
          raise Exceptions::Runtime.new("SUPERVISOR_RESTART_CHILD target #{supervisor_process_id} is not a supervisor")
        end

        # Resolve child ID
        child_id = resolve_child_id(child_id_value)

        # Find the child specification
        child_index = if child_id.is_a?(String)
                        supervisor.children.index { |(spec, _)| spec.id == child_id }
                      else
                        supervisor.children.index { |(_, process_id)| process_id == child_id.as(UInt64) }
                      end

        new_process_id : UInt64? = nil

        if child_index
          spec, current_process_id = supervisor.children[child_index]

          # Stop existing process if running
          if current_process_id
            child_process = @engine.processes.find { |actual_process| actual_process.address == current_process_id }
            if child_process
              child_process.state = Process::State::DEAD
              child_process.reason = Process::Reason::Context.normal
              @engine.scheduler.mark_dead(child_process)
            end
          end

          # Start new process
          new_process = @engine.create_process(
            instructions: spec.instructions.map(&.clone)
          )

          # Copy subroutines and globals
          spec.subroutines.each { |name, subroutine| new_process.subroutines[name] = subroutine }
          spec.globals.each { |name, value| new_process.globals[name] = value.clone }

          # Link supervisor to child
          @engine.link_registry.link(supervisor_process_id, new_process.address)

          # Register the process
          @engine.processes << new_process
          @engine.scheduler.enqueue(new_process)

          # Update supervisor's child list
          supervisor.children[child_index] = {spec, new_process.address}
          new_process_id = new_process.address
        end

        result = if new_process_id
                   Value::Context.new(new_process_id.to_i64)
                 else
                   Value::Context.null # null
                 end

        process.stack.push(result)
        result
      end

      # SUPERVISOR_LIST_CHILDREN
      # List all children of a supervisor
      # Stack Before: [... supervisor_process_id]
      # Stack After: [... children_array]
      # Note: Returns array of child info maps
      private def execute_supervisor_list_children(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "SUPERVISOR_LIST_CHILDREN")

        supervisor_value = process.stack.pop

        unless supervisor_value.integer? || supervisor_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("SUPERVISOR_LIST_CHILDREN requires integer supervisor process ID")
        end

        supervisor_process_id = supervisor_value.to_i64.to_u64

        # Get the supervisor
        supervisor = @engine.supervisor_registry.get(supervisor_process_id)
        unless supervisor
          raise Exceptions::Runtime.new("SUPERVISOR_LIST_CHILDREN target #{supervisor_process_id} is not a supervisor")
        end

        # Build children info array
        children_array = supervisor.children.map do |(spec, process_id)|
          history = supervisor.restart_histories[spec.id]?

          info = Hash(String, Value::Context).new
          info["id"] = Value::Context.new(spec.id)
          info["process_id"] = process_id ? Value::Context.new(process_id.to_i64) : Value::Context.null
          info["restart"] = Value::Context.new(spec.restart.to_s.downcase)
          info["type"] = Value::Context.new(spec.type.to_s.downcase)
          info["restarts"] = Value::Context.new((history.try(&.restart_count) || 0).to_i64)

          # Get current state if process exists
          if process_id
            child_process = @engine.processes.find { |actual_process| actual_process.address == process_id }
            info["state"] = Value::Context.new(child_process ? child_process.state.to_s : "UNKNOWN")
          else
            info["state"] = Value::Context.new("STOPPED")
          end

          Value::Context.new(info).as(Value::Context)
        end

        result = Value::Context.new(children_array)
        process.stack.push(result)

        result
      end

      # SUPERVISOR_COUNT_CHILDREN
      # Count children of a supervisor
      # Stack Before: [... supervisor_process_id]
      # Stack After: [... count]
      private def execute_supervisor_count_children(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "SUPERVISOR_COUNT_CHILDREN")

        supervisor_value = process.stack.pop

        unless supervisor_value.integer? || supervisor_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("SUPERVISOR_COUNT_CHILDREN requires integer supervisor process ID")
        end

        supervisor_process_id = supervisor_value.to_i64.to_u64

        # Get the supervisor
        supervisor = @engine.supervisor_registry.get(supervisor_process_id)
        unless supervisor
          raise Exceptions::Runtime.new("SUPERVISOR_COUNT_CHILDREN target #{supervisor_process_id} is not a supervisor")
        end

        # Count running children
        count = supervisor.running_children

        result = Value::Context.new(count.to_i64)
        process.stack.push(result)

        result
      end

      # Resolve child ID from value (can be PID or string name)
      private def resolve_child_id(child_id_value : Value::Context) : String | UInt64
        if child_id_value.integer? || child_id_value.unsigned_integer?
          child_id_value.to_i64.to_u64
        elsif child_id_value.string?
          child_id_value.to_s
        elsif child_id_value.symbol?
          child_id_value.to_symbol.to_s
        else
          raise Exceptions::TypeMismatch.new("Child ID must be integer PID or string name")
        end
      end

      # Parse child specification from map to Child::Specification
      private def parse_child_specification(spec_map : Hash(String, Value::Context)) : Supervisor::Child::Specification
        # Required: id
        id = if spec_map["id"]?
               id_value = spec_map["id"].not_nil!
               if id_value.string?
                 id_value.to_s
               elsif id_value.symbol?
                 id_value.to_symbol.to_s
               else
                 raise Exceptions::TypeMismatch.new("Child specification 'id' must be string or symbol")
               end
             else
               # Generate unique ID
               "child_#{Random.rand(1_000_000)}"
             end

        # Required: instructions
        instructions = if spec_map["instructions"]?
                         instr_value = spec_map["instructions"].not_nil!
                         if instr_value.instructions?
                           instr_value.to_instructions
                         elsif instr_value.lambda?
                           instr_value.to_lambda.instructions
                         else
                           raise Exceptions::TypeMismatch.new("Child specification 'instructions' must be instructions or lambda")
                         end
                       else
                         raise Exceptions::Value.new("Child specification requires 'instructions' field")
                       end

        # Optional: restart strategy (default: :permanent)
        restart = if spec_map["restart"]?
                    restart_value = spec_map["restart"].not_nil!
                    str = if restart_value.symbol?
                            restart_value.to_symbol.to_s
                          elsif restart_value.string?
                            restart_value.to_s
                          else
                            "permanent"
                          end

                    case str
                    when "permanent" then Supervisor::Child::RestartType::Permanent
                    when "temporary" then Supervisor::Child::RestartType::Temporary
                    when "transient" then Supervisor::Child::RestartType::Transient
                    else                  Supervisor::Child::RestartType::Permanent
                    end
                  else
                    Supervisor::Child::RestartType::Permanent
                  end

        # Optional: shutdown strategy
        shutdown = if spec_map["shutdown"]?
                     shutdown_value = spec_map["shutdown"].not_nil!
                     if shutdown_value.numeric?
                       Supervisor::Child::ShutdownType::Timeout
                     elsif shutdown_value.symbol? || shutdown_value.string?
                       str = shutdown_value.to_s
                       case str
                       when "brutal", "brutal_kill" then Supervisor::Child::ShutdownType::Brutal
                       when "infinity"              then Supervisor::Child::ShutdownType::Infinity
                       else                              Supervisor::Child::ShutdownType::Timeout
                       end
                     else
                       Supervisor::Child::ShutdownType::Timeout
                     end
                   else
                     Supervisor::Child::ShutdownType::Timeout
                   end

        # Optional: shutdown timeout
        shutdown_timeout = if spec_map["shutdown"]? && spec_map["shutdown"].not_nil!.numeric?
                             spec_map["shutdown"].not_nil!.to_i64.milliseconds
                           elsif spec_map["shutdown_timeout"]?
                             spec_map["shutdown_timeout"].not_nil!.to_i64.milliseconds
                           else
                             5000.milliseconds
                           end

        # Optional: type
        child_type = if spec_map["type"]?
                       type_value = spec_map["type"].not_nil!
                       str = if type_value.symbol?
                               type_value.to_symbol.to_s
                             elsif type_value.string?
                               type_value.to_s
                             else
                               "worker"
                             end

                       case str
                       when "worker"     then Supervisor::Child::Type::Worker
                       when "supervisor" then Supervisor::Child::Type::Supervisor
                       else                   Supervisor::Child::Type::Worker
                       end
                     else
                       Supervisor::Child::Type::Worker
                     end

        # Optional: max_restarts
        max_restarts = if spec_map["max_restarts"]?
                         spec_map["max_restarts"].not_nil!.to_i64.to_i32
                       else
                         3
                       end

        # Optional: restart_window
        restart_window = if spec_map["restart_window"]?
                           spec_map["restart_window"].not_nil!.to_f64.seconds
                         else
                           5.seconds
                         end

        # Optional: subroutines
        subroutines = Hash(String, Instruction::Subroutine).new
        if spec_map["subroutines"]? && spec_map["subroutines"].not_nil!.map?
          # Would need to parse subroutines - simplified for now
        end

        # Optional: globals
        globals = Hash(String, Value::Context).new
        if spec_map["globals"]? && spec_map["globals"].not_nil!.map?
          spec_map["globals"].not_nil!.to_h.each do |key, value|
            globals[key] = value
          end
        end

        Supervisor::Child::Specification.new(
          id: id,
          instructions: instructions,
          restart: restart,
          shutdown: shutdown,
          shutdown_timeout: shutdown_timeout,
          type: child_type,
          max_restarts: max_restarts,
          restart_window: restart_window,
          subroutines: subroutines,
          globals: globals
        )
      end
    end
  end
end
