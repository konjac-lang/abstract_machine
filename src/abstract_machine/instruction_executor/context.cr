require "./**"

module AbstractMachine
  module InstructionExecutor
    class Context
      Log = ::Log.for(self)

      include StackManipulationOperations
      include PushLiteralValueOperations
      include ArithmeticOperations
      include BitwiseOperations
      include LogicalOperations
      include ComparisonOperations
      include VariableOperations
      include ControlOperations
      include LambdaClosureOperations
      include ProcessLifecycleOperations
      include MessageOperations
      include SupervisorOperations
      include ExceptionHandlingOperations

      property engine : Engine::Context

      def initialize(@engine : Engine::Context)
      end

      # Helper method to check stack size
      private def check_stack_size(process : Process::Context, required : Int32, operation : String)
        if process.stack.size < required
          raise Exceptions::StackUnderflow.new("#{operation} requires #{required} values on stack, found #{process.stack.size}")
        end
      end

      # Helper method to check stack capacity
      private def check_stack_capacity(process : Process::Context)
        if process.stack.size >= @engine.configuration.max_stack_size
          raise Exceptions::StackOverflow.new("Stack overflow (max: #{@engine.configuration.max_stack_size})")
        end
      end

      # Executes a single instruction for the given process
      def execute(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        return Value::Context.null if process.state != Process::State::ALIVE

        Log.debug { "Process <#{process.address}>: Executing #{instruction.code}" }

        # Check for custom handler
        if handler = @engine.custom_handlers[instruction.code]?
          return handler.call(process, instruction)
        end

        begin
          case instruction.code
          # STACK OPERATIONS
          when Instruction::Code::STACK_POP              then execute_stack_pop(process)
          when Instruction::Code::STACK_DUPLICATE        then execute_stack_duplicate(process)
          when Instruction::Code::STACK_DUPLICATE_SECOND then execute_stack_duplicate_second(process)
          when Instruction::Code::STACK_SWAP             then execute_stack_swap(process)
          when Instruction::Code::STACK_ROTATE_UP        then execute_stack_rotate_up(process)
          when Instruction::Code::STACK_ROTATE_DOWN      then execute_stack_rotate_down(process)
          when Instruction::Code::STACK_REMOVE_SECOND    then execute_stack_remove_second(process)
          when Instruction::Code::STACK_TUCK             then execute_stack_tuck(process)
          when Instruction::Code::STACK_DEPTH            then execute_stack_depth(process)
          when Instruction::Code::STACK_PICK             then execute_stack_pick(process, instruction)
          when Instruction::Code::STACK_ROLL             then execute_stack_roll(process, instruction)
            # PUSH OPERATIONS
          when Instruction::Code::PUSH_NULL             then execute_push_null(process)
          when Instruction::Code::PUSH_BOOLEAN_TRUE     then execute_push_boolean_true(process)
          when Instruction::Code::PUSH_BOOLEAN_FALSE    then execute_push_boolean_false(process)
          when Instruction::Code::PUSH_INTEGER          then execute_push_integer(process, instruction)
          when Instruction::Code::PUSH_UNSIGNED_INTEGER then execute_push_unsigned_integer(process, instruction)
          when Instruction::Code::PUSH_FLOAT            then execute_push_float(process, instruction)
          when Instruction::Code::PUSH_STRING           then execute_push_string(process, instruction)
          when Instruction::Code::PUSH_SYMBOL           then execute_push_symbol(process, instruction)
          when Instruction::Code::PUSH_CUSTOM           then execute_push_custom(process, instruction)
          when Instruction::Code::PUSH_INSTRUCTIONS     then execute_push_instructions(process, instruction)
            # ARITHMETIC OPERATIONS
          when Instruction::Code::ARITHMETIC_ADD       then execute_arithmetic_add(process)
          when Instruction::Code::ARITHMETIC_SUBTRACT  then execute_arithmetic_subtract(process)
          when Instruction::Code::ARITHMETIC_MULTIPLY  then execute_arithmetic_multiply(process)
          when Instruction::Code::ARITHMETIC_DIVIDE    then execute_arithmetic_divide(process)
          when Instruction::Code::ARITHMETIC_MODULO    then execute_arithmetic_modulo(process)
          when Instruction::Code::ARITHMETIC_NEGATE    then execute_arithmetic_negate(process)
          when Instruction::Code::ARITHMETIC_ABSOLUTE  then execute_arithmetic_absolute(process)
          when Instruction::Code::ARITHMETIC_INCREMENT then execute_arithmetic_increment(process)
          when Instruction::Code::ARITHMETIC_DECREMENT then execute_arithmetic_decrement(process)
          when Instruction::Code::ARITHMETIC_POWER     then execute_arithmetic_power(process)
          when Instruction::Code::ARITHMETIC_FLOOR     then execute_arithmetic_floor(process)
          when Instruction::Code::ARITHMETIC_CEILING   then execute_arithmetic_ceiling(process)
          when Instruction::Code::ARITHMETIC_ROUND     then execute_arithmetic_round(process)
          when Instruction::Code::ARITHMETIC_MINIMUM   then execute_arithmetic_minimum(process)
          when Instruction::Code::ARITHMETIC_MAXIMUM   then execute_arithmetic_maximum(process)
            # BITWISE OPERATIONS
          when Instruction::Code::BITWISE_AND                  then execute_bitwise_and(process)
          when Instruction::Code::BITWISE_OR                   then execute_bitwise_or(process)
          when Instruction::Code::BITWISE_XOR                  then execute_bitwise_xor(process)
          when Instruction::Code::BITWISE_NOT                  then execute_bitwise_not(process)
          when Instruction::Code::BITWISE_SHIFT_LEFT           then execute_bitwise_shift_left(process)
          when Instruction::Code::BITWISE_SHIFT_RIGHT          then execute_bitwise_shift_right(process)
          when Instruction::Code::BITWISE_SHIFT_RIGHT_UNSIGNED then execute_bitwise_shift_right_unsigned(process)
            # LOGICAL OPERATIONS
          when Instruction::Code::LOGICAL_AND then execute_logical_and(process)
          when Instruction::Code::LOGICAL_OR  then execute_logical_or(process)
          when Instruction::Code::LOGICAL_NOT then execute_logical_not(process)
          when Instruction::Code::LOGICAL_XOR then execute_logical_xor(process)
            # COMPARISON OPERATIONS
          when Instruction::Code::COMPARISON_EQUAL                 then execute_comparison_equal(process)
          when Instruction::Code::COMPARISON_NOT_EQUAL             then execute_comparison_not_equal(process)
          when Instruction::Code::COMPARISON_IDENTICAL             then execute_comparison_identical(process)
          when Instruction::Code::COMPARISON_NOT_IDENTICAL         then execute_comparison_not_identical(process)
          when Instruction::Code::COMPARISON_LESS_THAN             then execute_comparison_less_than(process)
          when Instruction::Code::COMPARISON_LESS_THAN_OR_EQUAL    then execute_comparison_less_than_or_equal(process)
          when Instruction::Code::COMPARISON_GREATER_THAN          then execute_comparison_greater_than(process)
          when Instruction::Code::COMPARISON_GREATER_THAN_OR_EQUAL then execute_comparison_greater_than_or_equal(process)
          when Instruction::Code::COMPARISON_IS_NULL               then execute_comparison_is_null(process)
          when Instruction::Code::COMPARISON_IS_NOT_NULL           then execute_comparison_is_not_null(process)
            # VARIABLE OPERATIONS
          when Instruction::Code::VARIABLE_LOAD_LOCAL    then execute_variable_load_local(process, instruction)
          when Instruction::Code::VARIABLE_STORE_LOCAL   then execute_variable_store_local(process, instruction)
          when Instruction::Code::VARIABLE_LOAD_GLOBAL   then execute_variable_load_global(process, instruction)
          when Instruction::Code::VARIABLE_STORE_GLOBAL  then execute_variable_store_global(process, instruction)
          when Instruction::Code::VARIABLE_LOAD_UPVALUE  then execute_variable_load_upvalue(process, instruction)
          when Instruction::Code::VARIABLE_STORE_UPVALUE then execute_variable_store_upvalue(process, instruction)
            # CONTROL FLOW OPERATIONS
          when Instruction::Code::CONTROL_JUMP                   then execute_control_jump(process, instruction)
          when Instruction::Code::CONTROL_JUMP_FORWARD           then execute_control_jump_forward(process, instruction)
          when Instruction::Code::CONTROL_JUMP_BACKWARD          then execute_control_jump_backward(process, instruction)
          when Instruction::Code::CONTROL_JUMP_IF_TRUE           then execute_control_jump_if_true(process, instruction)
          when Instruction::Code::CONTROL_JUMP_IF_FALSE          then execute_control_jump_if_false(process, instruction)
          when Instruction::Code::CONTROL_JUMP_IF_TRUE_KEEP      then execute_control_jump_if_true_keep(process, instruction)
          when Instruction::Code::CONTROL_JUMP_IF_FALSE_KEEP     then execute_control_jump_if_false_keep(process, instruction)
          when Instruction::Code::CONTROL_CALL                   then execute_control_call(process, instruction)
          when Instruction::Code::CONTROL_CALL_DYNAMIC           then execute_control_call_dynamic(process)
          when Instruction::Code::CONTROL_CALL_INDIRECT          then execute_control_call_indirect(process)
          when Instruction::Code::CONTROL_CALL_BUILT_IN_FUNCTION then execute_control_call_built_in_function(process, instruction)
          when Instruction::Code::CONTROL_RETURN                 then execute_control_return(process)
          when Instruction::Code::CONTROL_RETURN_VALUE           then execute_control_return_value(process)
          when Instruction::Code::CONTROL_HALT                   then execute_control_halt(process)
          when Instruction::Code::CONTROL_NO_OPERATION           then execute_control_no_operation(process)
            # LAMBDA OPERATIONS
          when Instruction::Code::LAMBDA_CREATE then execute_lambda_create(process, instruction)
          when Instruction::Code::LAMBDA_INVOKE then execute_lambda_invoke(process, instruction)
          when Instruction::Code::LAMBDA_BIND   then execute_lambda_bind(process, instruction)
            # PROCESS OPERATIONS
          when Instruction::Code::PROCESS_SPAWN             then execute_process_spawn(process)
          when Instruction::Code::PROCESS_SPAWN_LINKED      then execute_process_spawn_linked(process)
          when Instruction::Code::PROCESS_SPAWN_MONITORED   then execute_process_spawn_monitored(process)
          when Instruction::Code::PROCESS_SELF              then execute_process_self(process)
          when Instruction::Code::PROCESS_EXIT              then execute_process_exit(process)
          when Instruction::Code::PROCESS_EXIT_REMOTE       then execute_process_exit_remote(process)
          when Instruction::Code::PROCESS_KILL              then execute_process_kill(process)
          when Instruction::Code::PROCESS_SLEEP             then execute_process_sleep(process)
          when Instruction::Code::PROCESS_YIELD             then execute_process_yield(process)
          when Instruction::Code::PROCESS_LINK              then execute_process_link(process)
          when Instruction::Code::PROCESS_UNLINK            then execute_process_unlink(process)
          when Instruction::Code::PROCESS_MONITOR           then execute_process_monitor(process)
          when Instruction::Code::PROCESS_DEMONITOR         then execute_process_demonitor(process)
          when Instruction::Code::PROCESS_TRAP_EXIT_ENABLE  then execute_process_trap_exit_enable(process)
          when Instruction::Code::PROCESS_TRAP_EXIT_DISABLE then execute_process_trap_exit_disable(process)
          when Instruction::Code::PROCESS_IS_ALIVE          then execute_process_is_alive(process)
          when Instruction::Code::PROCESS_GET_INFO          then execute_process_get_info(process)
          when Instruction::Code::PROCESS_REGISTER          then execute_process_register(process, instruction)
          when Instruction::Code::PROCESS_UNREGISTER        then execute_process_unregister(process, instruction)
          when Instruction::Code::PROCESS_WHEREIS           then execute_process_whereis(process, instruction)
          when Instruction::Code::PROCESS_SET_FLAG          then execute_process_set_flag(process)
          when Instruction::Code::PROCESS_GET_FLAG          then execute_process_get_flag(process)
            # MESSAGE OPERATIONS
          when Instruction::Code::MESSAGE_SEND                           then execute_message_send(process)
          when Instruction::Code::MESSAGE_SEND_AFTER                     then execute_message_send_after(process)
          when Instruction::Code::MESSAGE_RECEIVE                        then execute_message_receive(process)
          when Instruction::Code::MESSAGE_RECEIVE_WITH_TIMEOUT           then execute_message_receive_with_timeout(process)
          when Instruction::Code::MESSAGE_RECEIVE_SELECTIVE              then execute_message_receive_selective(process, instruction)
          when Instruction::Code::MESSAGE_RECEIVE_SELECTIVE_WITH_TIMEOUT then execute_message_receive_selective_with_timeout(process, instruction)
          when Instruction::Code::MESSAGE_PEEK                           then execute_message_peek(process)
          when Instruction::Code::MESSAGE_MAILBOX_SIZE                   then execute_message_mailbox_size(process)
          when Instruction::Code::MESSAGE_CANCEL_TIMER                   then execute_message_cancel_timer(process)
            # SUPERVISOR OPERATIONS
          when Instruction::Code::SUPERVISOR_START_CHILD    then execute_supervisor_start_child(process)
          when Instruction::Code::SUPERVISOR_STOP_CHILD     then execute_supervisor_stop_child(process)
          when Instruction::Code::SUPERVISOR_RESTART_CHILD  then execute_supervisor_restart_child(process)
          when Instruction::Code::SUPERVISOR_LIST_CHILDREN  then execute_supervisor_list_children(process)
          when Instruction::Code::SUPERVISOR_COUNT_CHILDREN then execute_supervisor_count_children(process)
            # EXCEPTION OPERATIONS
          when Instruction::Code::EXCEPTION_THROW          then execute_exception_throw(process)
          when Instruction::Code::EXCEPTION_RETHROW        then execute_exception_rethrow(process)
          when Instruction::Code::EXCEPTION_TRY_BEGIN      then execute_exception_try_begin(process, instruction)
          when Instruction::Code::EXCEPTION_TRY_END        then execute_exception_try_end(process)
          when Instruction::Code::EXCEPTION_CATCH          then execute_exception_catch(process)
          when Instruction::Code::EXCEPTION_GET_STACKTRACE then execute_exception_get_stacktrace(process)
          else
            raise Exceptions::InvalidInstruction.new("Unknown instruction: #{instruction.code}")
          end
        rescue ex : Exception
          handle_execution_exception(process, ex)
        end
      end

      # Execute inline instruction array with arguments
      def execute_inline_function(
        process : Process::Context,
        instructions : Array(Instruction::Operation),
        arguments : Array(Value::Context),
      ) : Value::Context
        # Save current state
        saved_counter = process.counter
        saved_instructions = process.instructions
        saved_locals = process.locals.dup
        saved_frame_pointer = process.frame_pointer

        # Set up function environment
        process.instructions = instructions
        process.counter = 0_u64
        process.frame_pointer = process.locals.size

        # Push arguments as locals
        arguments.each { |arg| process.locals << arg }

        # Execute instructions
        result = Value::Context.null

        while process.counter < process.instructions.size
          instruction = process.instructions[process.counter]
          result = execute(process, instruction)

          # Check for RETURN
          if instruction.code == Instruction::Code::CONTROL_RETURN ||
             instruction.code == Instruction::Code::CONTROL_RETURN_VALUE
            break
          end
        end

        # Get result from stack if available
        if !process.stack.empty?
          result = process.stack.pop
        end

        # Restore state
        process.instructions = saved_instructions
        process.counter = saved_counter
        process.locals = saved_locals
        process.frame_pointer = saved_frame_pointer

        result
      end

      # Handle exceptions during instruction execution
      def handle_execution_exception(process : Process::Context, ex : Exception) : Value::Context
        # Try to handle with AbstractMachine exception handlers
        if handle_crystal_exception(process, ex)
          return Value::Context.null
        end

        # No handler - process dies
        Log.error { "Process <#{process.address}>: Unhandled error: #{ex.message}" }

        process.state = Process::State::DEAD
        @engine.scheduler.mark_dead(process)

        # Build a AbstractMachine exception value from the Crystal exception
        exception_value = build_exception_value_from_crystal(ex, process)
        reason = Process::Reason::Context.exception(exception_value) # Pass the AbstractMachine exception value
        process.reason = reason
        @engine.fault_handler.handle_exit(process, reason)

        Value::Context.null
      end
    end
  end
end
