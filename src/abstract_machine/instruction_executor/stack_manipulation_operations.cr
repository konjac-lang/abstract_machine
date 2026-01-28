module AbstractMachine
  module InstructionExecutor
    module StackManipulationOperations
      extend self

      # STACK_POP
      # Remove and discard the top value from the stack
      # Stack Before: [... a]
      # Stack After: [...]
      private def execute_stack_pop(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STACK_POP")
        process.stack.pop
      end

      # STACK_DUPLICATE
      # Copy the top value and push the copy onto the stack
      # Stack Before: [... a]
      # Stack After: [... a, a]
      private def execute_stack_duplicate(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "STACK_DUPLICATE")
        check_stack_capacity(process)

        value = process.stack.last.clone
        process.stack.push(value)

        value
      end

      # STACK_DUPLICATE_SECOND
      # Copy the second value from top and push onto stack (OVER)
      # Stack Before: [... a, b]
      # Stack After: [... a, b, a]
      private def execute_stack_duplicate_second(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STACK_DUPLICATE_SECOND")
        check_stack_capacity(process)

        value = process.stack[process.stack.size - 2].clone
        process.stack.push(value)

        value
      end

      # STACK_SWAP
      # Exchange the top two values on the stack
      # Stack Before: [... a, b]
      # Stack After: [... b, a]
      private def execute_stack_swap(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STACK_SWAP")

        first = process.stack.pop
        second = process.stack.pop

        process.stack.push(first)
        process.stack.push(second)

        Value::Context.null
      end

      # STACK_ROTATE_UP
      # Rotate the top three values upward (third becomes top)
      # Stack Before: [... a, b, c]
      # Stack After: [... b, c, a]
      private def execute_stack_rotate_up(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STACK_ROTATE_UP")

        c = process.stack.pop
        b = process.stack.pop
        a = process.stack.pop

        process.stack.push(b)
        process.stack.push(c)
        process.stack.push(a)

        Value::Context.null
      end

      # STACK_ROTATE_DOWN
      # Rotate the top three values downward (top becomes third)
      # Stack Before: [... a, b, c]
      # Stack After: [... c, a, b]
      private def execute_stack_rotate_down(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "STACK_ROTATE_DOWN")

        c = process.stack.pop
        b = process.stack.pop
        a = process.stack.pop

        process.stack.push(c)
        process.stack.push(a)
        process.stack.push(b)

        Value::Context.null
      end

      # STACK_REMOVE_SECOND
      # Remove the second value from stack, keeping top (NIP)
      # Stack Before: [... a, b]
      # Stack After: [... b]
      private def execute_stack_remove_second(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STACK_REMOVE_SECOND")

        top = process.stack.pop
        process.stack.pop # discard second
        process.stack.push(top)

        top
      end

      # STACK_TUCK
      # Copy the top value and insert beneath the second value
      # Stack Before: [... a, b]
      # Stack After: [... b, a, b]
      private def execute_stack_tuck(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "STACK_TUCK")
        check_stack_capacity(process)

        b = process.stack.pop
        a = process.stack.pop

        process.stack.push(b.clone)
        process.stack.push(a)
        process.stack.push(b)

        b
      end

      # STACK_DEPTH
      # Push the current stack depth onto the stack
      # Stack Before: [... (n items)]
      # Stack After: [... (n items), n]
      private def execute_stack_depth(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_capacity(process)

        depth = Value::Context.new(process.stack.size.to_i64)
        process.stack.push(depth)

        depth
      end

      # STACK_PICK
      # Copy the nth item from top onto the stack
      # Operand: UInt32 (index from top, 0 = top)
      # Stack Before: [... a_n, ... a_1, a_0]
      # Stack After: [... a_n, ... a_1, a_0, a_n]
      private def execute_stack_pick(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STACK_PICK requires an integer index operand")
        end

        n = instruction.value.to_i64.to_i32

        if n < 0
          raise Exceptions::Value.new("STACK_PICK index cannot be negative: #{n}")
        end

        # n=0 means top of stack, n=1 means second from top, etc.
        check_stack_size(process, n + 1, "STACK_PICK")
        check_stack_capacity(process)

        # Index from the end: stack.size - 1 is top, stack.size - 1 - n is nth from top
        index = process.stack.size - 1 - n
        value = process.stack[index].clone
        process.stack.push(value)

        value
      end

      # STACK_ROLL
      # Move the nth item from top to the top of stack
      # Operand: UInt32 (index from top, 0 = no-op)
      # Stack Before: [... a_n, ... a_1, a_0]
      # Stack After: [... a_(n-1), ... a_1, a_0, a_n]
      private def execute_stack_roll(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.integer? || instruction.value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("STACK_ROLL requires an integer index operand")
        end

        n = instruction.value.to_i64.to_i32

        if n < 0
          raise Exceptions::Value.new("STACK_ROLL index cannot be negative: #{n}")
        end

        # n=0 is a no-op (top stays at top)
        if n == 0
          check_stack_size(process, 1, "STACK_ROLL")
          return process.stack.last
        end

        # n=1 means swap top two, n=2 means rotate top three, etc.
        check_stack_size(process, n + 1, "STACK_ROLL")

        # Remove the nth item from top and push it to the top
        index = process.stack.size - 1 - n
        value = process.stack.delete_at(index)
        process.stack.push(value)

        value
      end
    end
  end
end
