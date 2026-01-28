module AbstractMachine
  module InstructionExecutor
    module VariableOperations
      extend self

      # VARIABLE_LOAD_LOCAL
      # Push local variable value onto stack
      # Operand: UInt16 (variable slot index)
      # Stack Before: [...]
      # Stack After: [... value]
      private def execute_variable_load_local(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("VARIABLE_LOAD_LOCAL requires an integer index operand")
        end

        index = instruction.value.to_i64.to_i32

        # Calculate actual index relative to frame pointer
        actual_index = process.frame_pointer + index

        if actual_index < 0 || actual_index >= process.locals.size
          raise Exceptions::UndefinedVariable.new(
            "VARIABLE_LOAD_LOCAL invalid slot index: #{index} (actual: #{actual_index}, locals size: #{process.locals.size})"
          )
        end

        value = process.locals[actual_index].clone
        process.stack.push(value)

        value
      end

      # VARIABLE_STORE_LOCAL
      # Pop stack value into local variable
      # Operand: UInt16 (variable slot index)
      # Stack Before: [... value]
      # Stack After: [...]
      private def execute_variable_store_local(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "VARIABLE_STORE_LOCAL")

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("VARIABLE_STORE_LOCAL requires an integer index operand")
        end

        index = instruction.value.to_i64.to_i32
        value = process.stack.pop

        # Calculate actual index relative to frame pointer
        actual_index = process.frame_pointer + index

        # Expand locals array if needed
        while process.locals.size <= actual_index
          process.locals.push(Value::Context.null)
        end

        process.locals[actual_index] = value

        value
      end

      # VARIABLE_LOAD_GLOBAL
      # Push global variable value onto stack
      # Operand: String (variable name)
      # Stack Before: [...]
      # Stack After: [... value]
      private def execute_variable_load_global(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("VARIABLE_LOAD_GLOBAL requires a string name operand")
        end

        name = instruction.value.to_s
        value = process.globals[name]?

        unless value
          raise Exceptions::UndefinedVariable.new("VARIABLE_LOAD_GLOBAL undefined variable: '#{name}'")
        end

        process.stack.push(value.clone)

        value
      end

      # VARIABLE_STORE_GLOBAL
      # Pop stack value into global variable
      # Operand: String (variable name)
      # Stack Before: [... value]
      # Stack After: [...]
      private def execute_variable_store_global(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "VARIABLE_STORE_GLOBAL")

        unless instruction.value.string?
          raise Exceptions::TypeMismatch.new("VARIABLE_STORE_GLOBAL requires a string name operand")
        end

        name = instruction.value.to_s
        value = process.stack.pop

        process.globals[name] = value

        value
      end

      # VARIABLE_LOAD_UPVALUE
      # Load captured variable from enclosing scope (for closures)
      # Operand: UInt16 (upvalue index)
      # Stack Before: [...]
      # Stack After: [... value]
      private def execute_variable_load_upvalue(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("VARIABLE_LOAD_UPVALUE requires an integer index operand")
        end

        index = instruction.value.to_i64.to_i32

        # Upvalues are stored in the current lambda's captured environment
        # Access through the process's current closure context
        closure = process.current_closure

        if closure.nil?
          raise Exceptions::Runtime.new("VARIABLE_LOAD_UPVALUE called outside of closure context")
        end

        upvalues = closure.upvalues

        if index < 0 || index >= upvalues.size
          raise Exceptions::UndefinedVariable.new(
            "VARIABLE_LOAD_UPVALUE invalid upvalue index: #{index} (upvalues size: #{upvalues.size})"
          )
        end

        value = upvalues[index].clone
        process.stack.push(value)

        value
      end

      # VARIABLE_STORE_UPVALUE
      # Store value into captured variable (for closures)
      # Operand: UInt16 (upvalue index)
      # Stack Before: [... value]
      # Stack After: [...]
      private def execute_variable_store_upvalue(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "VARIABLE_STORE_UPVALUE")

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("VARIABLE_STORE_UPVALUE requires an integer index operand")
        end

        index = instruction.value.to_i64.to_i32
        value = process.stack.pop

        # Upvalues are stored in the current lambda's captured environment
        closure = process.current_closure

        if closure.nil?
          raise Exceptions::Runtime.new("VARIABLE_STORE_UPVALUE called outside of closure context")
        end

        upvalues = closure.upvalues

        if index < 0 || index >= upvalues.size
          raise Exceptions::UndefinedVariable.new(
            "VARIABLE_STORE_UPVALUE invalid upvalue index: #{index} (upvalues size: #{upvalues.size})"
          )
        end

        upvalues[index] = value

        value
      end
    end
  end
end
