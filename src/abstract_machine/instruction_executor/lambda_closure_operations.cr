module AbstractMachine
  module InstructionExecutor
    module LambdaClosureOperations
      extend self

      # LAMBDA_CREATE
      # Create a lambda from instruction array and captures
      # Operand: Tuple(Array(Instruction), Array(String)) - (body, capture_names)
      # Stack Before: [...]
      # Stack After: [... lambda]
      private def execute_lambda_create(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        # Extract body instructions and capture names from operand
        unless instruction.value.lambda_create_tuple?
          raise Exceptions::TypeMismatch.new("LAMBDA_CREATE requires a tuple operand (instructions, capture_names)")
        end

        tuple = instruction.value.to_lambda_create_tuple
        body_instructions = tuple[0]
        capture_names = tuple[1]

        # Build captured environment from current scope
        captured_environment = Hash(String, Value::Context).new

        capture_names.each do |var_name|
          # Try globals first
          if val = process.globals[var_name]?
            captured_environment[var_name] = val.clone
            # Then try locals (would need to resolve by name - simplified here)
          end
        end

        # Create the lambda
        lambda = Lambda::Context.new(
          instructions: body_instructions,
          variables: [] of String, # Parameters defined separately or inferred
          captured_environment: captured_environment
        )

        result = Value::Context.new(lambda)
        process.stack.push(result)

        result
      end

      # LAMBDA_INVOKE
      # Invoke a lambda with arguments from stack
      # Operand: UInt8 (argument count)
      # Stack Before: [... lambda, arg1, arg2, ..., argN]
      # Stack After: [... result]
      private def execute_lambda_invoke(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("LAMBDA_INVOKE requires an integer argument count")
        end

        arg_count = instruction.value.to_i64.to_i32

        # Need lambda + arg_count values on stack
        check_stack_size(process, arg_count + 1, "LAMBDA_INVOKE")

        # Pop arguments in reverse order
        arguments = Array(Value::Context).new(arg_count)
        arg_count.times do
          arguments.unshift(process.stack.pop)
        end

        # Pop the lambda
        lambda_value = process.stack.pop

        unless lambda_value.lambda?
          raise Exceptions::TypeMismatch.new("LAMBDA_INVOKE requires a lambda value")
        end

        lambda = lambda_value.to_lambda

        # Execute the lambda
        result = execute_lambda(process, lambda, arguments)

        process.stack.push(result)
        result
      end

      # LAMBDA_BIND
      # Partially apply arguments to a lambda
      # Operand: UInt8 (number of arguments to bind)
      # Stack Before: [... lambda, arg1, arg2, ..., argN]
      # Stack After: [... partially_applied_lambda]
      private def execute_lambda_bind(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("LAMBDA_BIND requires an integer argument count")
        end

        bind_count = instruction.value.to_i64.to_i32

        # Need lambda + bind_count values on stack
        check_stack_size(process, bind_count + 1, "LAMBDA_BIND")

        # Pop arguments to bind in reverse order
        bound_args = Array(Value::Context).new(bind_count)
        bind_count.times do
          bound_args.unshift(process.stack.pop)
        end

        # Pop the lambda
        lambda_value = process.stack.pop

        unless lambda_value.lambda?
          raise Exceptions::TypeMismatch.new("LAMBDA_BIND requires a lambda value")
        end

        original_lambda = lambda_value.to_lambda

        # Create a new lambda with bound arguments
        # The new lambda will prepend bound_args to any call arguments
        partial_lambda = Lambda::Partial.new(
          original: original_lambda,
          bound_arguments: bound_args
        )

        result = Value::Context.new(partial_lambda)
        process.stack.push(result)

        result
      end

      # Execute a lambda with given arguments
      private def execute_lambda(
        process : Process::Context,
        lambda : Lambda::Context,
        arguments : Array(Value::Context),
      ) : Value::Context
        # Handle partial application
        actual_lambda = lambda
        actual_arguments = arguments

        if lambda.is_a?(Lambda::Partial)
          partial = lambda.as(Lambda::Partial)
          # Prepend bound arguments
          actual_arguments = partial.bound_arguments + arguments
          actual_lambda = partial.original
        end

        # Save current execution state
        saved_counter = process.counter
        saved_instructions = process.instructions
        saved_locals = process.locals.dup
        saved_frame_pointer = process.frame_pointer
        saved_closure = process.current_closure

        # Set up lambda execution environment
        process.current_closure = actual_lambda
        process.instructions = actual_lambda.instructions
        process.counter = 0_u64
        process.frame_pointer = process.locals.size

        # Bind arguments to local variables
        actual_lambda.variables.each_with_index do |_param_name, index|
          if index < actual_arguments.size
            process.locals << actual_arguments[index]
          else
            process.locals << Value::Context.null # Default to null
          end
        end

        # Also add extra arguments beyond declared parameters
        if actual_arguments.size > actual_lambda.variables.size
          (actual_lambda.variables.size...actual_arguments.size).each do |i|
            process.locals << actual_arguments[i]
          end
        end

        # Set up captured environment as globals (temporary)
        saved_globals = Hash(String, Value::Context).new
        actual_lambda.captured_environment.each do |name, value|
          saved_globals[name] = process.globals[name]? || Value::Context.null
          process.globals[name] = value
        end

        # Execute lambda instructions
        result = Value::Context.null

        while process.counter < process.instructions.size
          instruction = process.instructions[process.counter]

          # Check for return
          if instruction.code == Instruction::Code::CONTROL_RETURN ||
             instruction.code == Instruction::Code::CONTROL_RETURN_VALUE
            if !process.stack.empty?
              result = process.stack.pop
            end
            break
          end

          result = execute(process, instruction)
        end

        # Get result from stack if available
        if result.null? && !process.stack.empty?
          result = process.stack.pop
        end

        # Restore captured globals
        saved_globals.each do |name, value|
          if value.null?
            process.globals.delete(name)
          else
            process.globals[name] = value
          end
        end

        # Restore execution state
        process.instructions = saved_instructions
        process.counter = saved_counter
        process.locals = saved_locals
        process.frame_pointer = saved_frame_pointer
        process.current_closure = saved_closure

        result
      end
    end
  end
end
