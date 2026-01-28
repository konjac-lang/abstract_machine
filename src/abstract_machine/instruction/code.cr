module AbstractMachine
  module Instruction
    enum Code : UInt16
      # Operations that manipulate the data stack without performing computation.

      STACK_POP
      # Description: Remove and discard the top value from the stack
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [...]
      # Errors: StackUnderflow if stack is empty

      STACK_DUPLICATE
      # Description: Copy the top value and push the copy onto the stack
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... a, a]
      # Errors: StackUnderflow if stack is empty

      STACK_DUPLICATE_SECOND
      # Description: Copy the second value from top and push onto stack (OVER)
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... a, b, a]
      # Errors: StackUnderflow if fewer than 2 values

      STACK_SWAP
      # Description: Exchange the top two values on the stack
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... b, a]
      # Errors: StackUnderflow if fewer than 2 values

      STACK_ROTATE_UP
      # Description: Rotate the top three values upward (third becomes top)
      # Operand: None
      # Stack Before: [... a, b, c]
      # Stack After: [... b, c, a]
      # Errors: StackUnderflow if fewer than 3 values

      STACK_ROTATE_DOWN
      # Description: Rotate the top three values downward (top becomes third)
      # Operand: None
      # Stack Before: [... a, b, c]
      # Stack After: [... c, a, b]
      # Errors: StackUnderflow if fewer than 3 values

      STACK_REMOVE_SECOND
      # Description: Remove the second value from stack, keeping top (NIP)
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... b]
      # Errors: StackUnderflow if fewer than 2 values

      STACK_TUCK
      # Description: Copy the top value and insert beneath the second value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... b, a, b]
      # Errors: StackUnderflow if fewer than 2 values

      STACK_DEPTH
      # Description: Push the current stack depth onto the stack
      # Operand: None
      # Stack Before: [... (n items)]
      # Stack After: [... (n items), n]

      STACK_PICK
      # Description: Copy the nth item from top onto the stack
      # Operand: None
      # Stack Before: [... a_n, ... a_1, a_0, n]
      # Stack After: [... a_n, ... a_1, a_0, a_n]
      # Errors: StackUnderflow if n exceeds stack depth

      STACK_ROLL
      # Description: Move the nth item from top to the top of stack
      # Operand: None
      # Stack Before: [... a_n, ... a_1, a_0, n]
      # Stack After: [... a_(n-1), ... a_1, a_0, a_n]
      # Errors: StackUnderflow if n exceeds stack depth

      # Operations that push constant/literal values onto the stack.

      PUSH_NULL
      # Description: Push a null value onto the stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... null]

      PUSH_BOOLEAN_TRUE
      # Description: Push boolean true onto the stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... true]

      PUSH_BOOLEAN_FALSE
      # Description: Push boolean false onto the stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... false]

      PUSH_INTEGER
      # Description: Push a signed 64-bit integer onto the stack
      # Operand: Int64
      # Stack Before: [...]
      # Stack After: [... integer]

      PUSH_UNSIGNED_INTEGER
      # Description: Push an unsigned 64-bit integer onto the stack
      # Operand: UInt64
      # Stack Before: [...]
      # Stack After: [... unsigned_integer]

      PUSH_FLOAT
      # Description: Push a 64-bit floating point number onto the stack
      # Operand: Float64
      # Stack Before: [...]
      # Stack After: [... float]

      PUSH_STRING
      # Description: Push a string value onto the stack
      # Operand: String
      # Stack Before: [...]
      # Stack After: [... string]

      PUSH_SYMBOL
      # Description: Push a symbol (interned string) onto the stack
      # Operand: String (the symbol name)
      # Stack Before: [...]
      # Stack After: [... symbol]

      PUSH_CUSTOM
      # Description: Push a custom/user-defined value onto the stack
      # Operand: Any (custom value)
      # Stack Before: [...]
      # Stack After: [... custom_value]

      PUSH_INSTRUCTIONS
      # Description: Push an instruction array (code block) onto the stack
      # Operand: Array(Instruction)
      # Stack Before: [...]
      # Stack After: [... instructions]

      # Numeric arithmetic operations. Operate on Integer, UnsignedInteger, Float.
      # Type promotion: If either operand is Float, result is Float.

      ARITHMETIC_ADD
      # Description: Add two numeric values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a + b)]
      # Errors: TypeMismatch if operands are not numeric

      ARITHMETIC_SUBTRACT
      # Description: Subtract top value from second value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a - b)]
      # Errors: TypeMismatch if operands are not numeric

      ARITHMETIC_MULTIPLY
      # Description: Multiply two numeric values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a * b)]
      # Errors: TypeMismatch if operands are not numeric

      ARITHMETIC_DIVIDE
      # Description: Divide second value by top value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a / b)]
      # Errors: DivisionByZero if b is zero, TypeMismatch if not numeric

      ARITHMETIC_MODULO
      # Description: Compute remainder of second value divided by top value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a % b)]
      # Errors: DivisionByZero if b is zero, TypeMismatch if not numeric

      ARITHMETIC_NEGATE
      # Description: Negate the top numeric value (unary minus)
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (-a)]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_ABSOLUTE
      # Description: Compute absolute value of top numeric value
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... |a|]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_INCREMENT
      # Description: Add 1 to the top numeric value
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (a + 1)]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_DECREMENT
      # Description: Subtract 1 from the top numeric value
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (a - 1)]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_POWER
      # Description: Raise second value to the power of top value
      # Operand: None
      # Stack Before: [... base, exponent]
      # Stack After: [... (base ** exponent)]
      # Errors: TypeMismatch if operands are not numeric

      ARITHMETIC_FLOOR
      # Description: Round down to nearest integer (toward negative infinity)
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... floor(a)]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_CEILING
      # Description: Round up to nearest integer (toward positive infinity)
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... ceil(a)]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_ROUND
      # Description: Round to nearest integer (half up)
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... round(a)]
      # Errors: TypeMismatch if operand is not numeric

      ARITHMETIC_MINIMUM
      # Description: Return the smaller of two numeric values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... min(a, b)]
      # Errors: TypeMismatch if operands are not numeric

      ARITHMETIC_MAXIMUM
      # Description: Return the larger of two numeric values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... max(a, b)]
      # Errors: TypeMismatch if operands are not numeric

      # Bitwise operations on integer values.

      BITWISE_AND
      # Description: Bitwise AND of two integer values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a & b)]
      # Errors: TypeMismatch if operands are not integers

      BITWISE_OR
      # Description: Bitwise OR of two integer values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a | b)]
      # Errors: TypeMismatch if operands are not integers

      BITWISE_XOR
      # Description: Bitwise XOR of two integer values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a ^ b)]
      # Errors: TypeMismatch if operands are not integers

      BITWISE_NOT
      # Description: Bitwise NOT (complement) of integer value
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (~a)]
      # Errors: TypeMismatch if operand is not an integer

      BITWISE_SHIFT_LEFT
      # Description: Shift bits left by specified count
      # Operand: None
      # Stack Before: [... value, count]
      # Stack After: [... (value << count)]
      # Errors: TypeMismatch if operands are not integers

      BITWISE_SHIFT_RIGHT
      # Description: Arithmetic shift bits right by specified count
      # Operand: None
      # Stack Before: [... value, count]
      # Stack After: [... (value >> count)]
      # Errors: TypeMismatch if operands are not integers

      BITWISE_SHIFT_RIGHT_UNSIGNED
      # Description: Logical shift bits right by specified count (zero fill)
      # Operand: None
      # Stack Before: [... value, count]
      # Stack After: [... (value >>> count)]
      # Errors: TypeMismatch if operands are not integers

      # Value comparison operations. All push a boolean result.

      COMPARISON_EQUAL
      # Description: Test if two values are equal (structural equality)
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a == b)]

      COMPARISON_NOT_EQUAL
      # Description: Test if two values are not equal
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a != b)]

      COMPARISON_IDENTICAL
      # Description: Test if two values are identical (reference equality)
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a === b)]

      COMPARISON_NOT_IDENTICAL
      # Description: Test if two values are not identical
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a !== b)]

      COMPARISON_LESS_THAN
      # Description: Test if second value is less than top value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a < b)]
      # Errors: TypeMismatch if values are not comparable

      COMPARISON_LESS_THAN_OR_EQUAL
      # Description: Test if second value is less than or equal to top value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a <= b)]
      # Errors: TypeMismatch if values are not comparable

      COMPARISON_GREATER_THAN
      # Description: Test if second value is greater than top value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a > b)]
      # Errors: TypeMismatch if values are not comparable

      COMPARISON_GREATER_THAN_OR_EQUAL
      # Description: Test if second value is greater than or equal to top value
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a >= b)]
      # Errors: TypeMismatch if values are not comparable

      COMPARISON_IS_NULL
      # Description: Test if top value is null
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (a == null)]

      COMPARISON_IS_NOT_NULL
      # Description: Test if top value is not null
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (a != null)]

      # Boolean logic operations.

      LOGICAL_AND
      # Description: Logical AND of two boolean values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a && b)]
      # Note: Values are coerced to boolean (falsy: null, false; truthy: all else)

      LOGICAL_OR
      # Description: Logical OR of two boolean values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a || b)]
      # Note: Values are coerced to boolean

      LOGICAL_NOT
      # Description: Logical NOT of a boolean value
      # Operand: None
      # Stack Before: [... a]
      # Stack After: [... (!a)]
      # Note: Value is coerced to boolean

      LOGICAL_XOR
      # Description: Logical XOR of two boolean values
      # Operand: None
      # Stack Before: [... a, b]
      # Stack After: [... (a ^^ b)]
      # Note: True if exactly one operand is truthy

      VARIABLE_LOAD_LOCAL
      # Description: Push local variable value onto stack
      # Operand: UInt16 (variable slot index)
      # Stack Before: [...]
      # Stack After: [... value]
      # Errors: UndefinedVariable if slot not initialized

      VARIABLE_STORE_LOCAL
      # Description: Pop stack value into local variable
      # Operand: UInt16 (variable slot index)
      # Stack Before: [... value]
      # Stack After: [...]

      VARIABLE_LOAD_GLOBAL
      # Description: Push global variable value onto stack
      # Operand: String (variable name)
      # Stack Before: [...]
      # Stack After: [... value]
      # Errors: UndefinedVariable if name not defined

      VARIABLE_STORE_GLOBAL
      # Description: Pop stack value into global variable
      # Operand: String (variable name)
      # Stack Before: [... value]
      # Stack After: [...]

      VARIABLE_LOAD_UPVALUE
      # Description: Load captured variable from enclosing scope (for closures)
      # Operand: UInt16 (upvalue index)
      # Stack Before: [...]
      # Stack After: [... value]

      VARIABLE_STORE_UPVALUE
      # Description: Store value into captured variable (for closures)
      # Operand: UInt16 (upvalue index)
      # Stack Before: [... value]
      # Stack After: [...]

      # Operations for controlling program execution flow.

      CONTROL_JUMP
      # Description: Unconditional jump to absolute instruction address
      # Operand: Int64 (target address)
      # Stack Before: [...]
      # Stack After: [...]

      CONTROL_JUMP_FORWARD
      # Description: Jump forward by relative offset
      # Operand: UInt32 (forward offset)
      # Stack Before: [...]
      # Stack After: [...]

      CONTROL_JUMP_BACKWARD
      # Description: Jump backward by relative offset
      # Operand: UInt32 (backward offset)
      # Stack Before: [...]
      # Stack After: [...]

      CONTROL_JUMP_IF_TRUE
      # Description: Jump if top of stack is truthy (consumes condition)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [...]

      CONTROL_JUMP_IF_FALSE
      # Description: Jump if top of stack is falsy (consumes condition)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [...]

      CONTROL_JUMP_IF_TRUE_KEEP
      # Description: Jump if top of stack is truthy (keeps condition on stack)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [... condition]

      CONTROL_JUMP_IF_FALSE_KEEP
      # Description: Jump if top of stack is falsy (keeps condition on stack)
      # Operand: Int64 (target address or relative offset)
      # Stack Before: [... condition]
      # Stack After: [... condition]

      CONTROL_CALL
      # Description: Call a named subroutine
      # Operand: String (subroutine name)
      # Stack Before: [...]
      # Stack After: [...]
      # Side Effects: Pushes return address to call stack

      CONTROL_CALL_DYNAMIC
      # Description: Call subroutine by name from stack
      # Operand: None
      # Stack Before: [... subroutine_name]
      # Stack After: [...]
      # Side Effects: Pushes return address to call stack

      CONTROL_CALL_INDIRECT
      # Description: Call instruction array from stack
      # Operand: None
      # Stack Before: [... instructions]
      # Stack After: [...]
      # Side Effects: Pushes return address to call stack

      CONTROL_CALL_BUILT_IN_FUNCTION
      # Description: Call a built-in function
      # Operand: Array [module_name, function_name, arity]
      # Stack Before: [... arg1, arg2, ..., argN]
      # Stack After: [... result]

      CONTROL_RETURN
      # Description: Return from subroutine to caller
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]
      # Side Effects: Pops return address from call stack
      # Note: If call stack is empty, terminates process

      CONTROL_RETURN_VALUE
      # Description: Return from subroutine with a value
      # Operand: None
      # Stack Before: [... return_value]
      # Stack After: [... return_value]
      # Side Effects: Pops return address from call stack

      CONTROL_HALT
      # Description: Halt process execution cleanly
      # Operand: None
      # Stack Before: [...]
      # Stack After: N/A (process terminated)
      # Side Effects: Sets process state to DEAD

      CONTROL_NO_OPERATION
      # Description: Do nothing (placeholder instruction)
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]

      # Operations for creating and invoking lambda functions.

      LAMBDA_CREATE
      # Description: Create a lambda from instruction array and captures
      # Operand: Tuple(Array(Instruction), Array(String)) - (body, capture_names)
      # Stack Before: [...]
      # Stack After: [... lambda]
      # Note: Captures variables from current scope by name

      LAMBDA_INVOKE
      # Description: Invoke a lambda with arguments from stack
      # Operand: UInt8 (argument count)
      # Stack Before: [... lambda, arg1, arg2, ..., argN]
      # Stack After: [... result]

      LAMBDA_BIND
      # Description: Partially apply arguments to a lambda
      # Operand: UInt8 (number of arguments to bind)
      # Stack Before: [... lambda, arg1, arg2, ..., argN]
      # Stack After: [... partially_applied_lambda]

      # Operations for managing concurrent processes.

      PROCESS_SPAWN
      # Description: Spawn a new process with given instruction array
      # Operand: None
      # Stack Before: [... instructions]
      # Stack After: [... new_process_id]
      # Side Effects: Creates new process in READY state

      PROCESS_SPAWN_LINKED
      # Description: Spawn new process and link it to current process atomically
      # Operand: None
      # Stack Before: [... instructions]
      # Stack After: [... new_process_id]
      # Side Effects: Creates process and bidirectional link

      PROCESS_SPAWN_MONITORED
      # Description: Spawn new process and monitor it from current process
      # Operand: None
      # Stack Before: [... instructions]
      # Stack After: [... new_process_id, monitor_reference]
      # Side Effects: Creates process and unidirectional monitor

      PROCESS_SELF
      # Description: Push current process ID onto stack
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... self_process_id]

      PROCESS_EXIT
      # Description: Terminate current process with reason
      # Operand: None
      # Stack Before: [... reason]
      # Stack After: N/A (process terminated)
      # Side Effects: Sets process state to DEAD, notifies linked/monitoring processes

      PROCESS_EXIT_REMOTE
      # Description: Send exit signal to another process
      # Operand: None
      # Stack Before: [... target_process_id, reason]
      # Stack After: [...]
      # Side Effects: May terminate target depending on trap settings

      PROCESS_KILL
      # Description: Force terminate a process (untrappable)
      # Operand: None
      # Stack Before: [... target_process_id]
      # Stack After: [...]
      # Side Effects: Unconditionally terminates target process

      PROCESS_SLEEP
      # Description: Pause current process execution for duration
      # Operand: None
      # Stack Before: [... seconds]
      # Stack After: [...]
      # Side Effects: Sets process to WAITING until timeout

      PROCESS_YIELD
      # Description: Voluntarily yield execution to scheduler
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]
      # Side Effects: Allows other processes to run

      PROCESS_LINK
      # Description: Create bidirectional link between processes
      # Operand: None
      # Stack Before: [... other_process_id]
      # Stack After: [...]
      # Side Effects: Links die together

      PROCESS_UNLINK
      # Description: Remove bidirectional link between processes
      # Operand: None
      # Stack Before: [... other_process_id]
      # Stack After: [...]

      PROCESS_MONITOR
      # Description: Create unidirectional monitor of another process
      # Operand: None
      # Stack Before: [... target_process_id]
      # Stack After: [... monitor_reference]
      # Note: Monitor receives DOWN message when target dies

      PROCESS_DEMONITOR
      # Description: Remove monitor of another process
      # Operand: None
      # Stack Before: [... monitor_reference]
      # Stack After: [... success_boolean]

      PROCESS_TRAP_EXIT_ENABLE
      # Description: Enable exit signal trapping for current process
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]
      # Side Effects: Exit signals become messages instead of termination

      PROCESS_TRAP_EXIT_DISABLE
      # Description: Disable exit signal trapping for current process
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]

      PROCESS_IS_ALIVE
      # Description: Check if a process is alive
      # Operand: None
      # Stack Before: [... process_id]
      # Stack After: [... boolean]

      PROCESS_GET_INFO
      # Description: Get information about a process
      # Operand: None
      # Stack Before: [... process_id]
      # Stack After: [... info_map_or_null]
      # Note: Returns null if process doesn't exist

      PROCESS_REGISTER
      # Description: Register current process with a name
      # Operand: String (name)
      # Stack Before: [...]
      # Stack After: [... success_boolean]
      # Side Effects: Associates name with current process ID

      PROCESS_UNREGISTER
      # Description: Remove name registration
      # Operand: String (name)
      # Stack Before: [...]
      # Stack After: [... success_boolean]

      PROCESS_WHEREIS
      # Description: Look up process ID by registered name
      # Operand: String (name)
      # Stack Before: [...]
      # Stack After: [... process_id_or_null]

      PROCESS_SET_FLAG
      # Description: Set a process flag
      # Operand: None
      # Stack Before: [... flag_name, value]
      # Stack After: [... old_value]

      PROCESS_GET_FLAG
      # Description: Get a process flag value
      # Operand: None
      # Stack Before: [... flag_name]
      # Stack After: [... value]

      # Operations for inter-process communication.

      MESSAGE_SEND
      # Description: Send message to another process
      # Operand: None
      # Stack Before: [... target_process_id, message]
      # Stack After: [...]
      # Side Effects: Message added to target's mailbox

      MESSAGE_SEND_AFTER
      # Description: Schedule message to be sent after delay
      # Operand: None
      # Stack Before: [... target_process_id, message, delay_seconds]
      # Stack After: [... timer_reference]
      # Side Effects: Timer scheduled

      MESSAGE_RECEIVE
      # Description: Receive next message from mailbox (blocking)
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... message]
      # Side Effects: Sets process to WAITING if mailbox empty

      MESSAGE_RECEIVE_WITH_TIMEOUT
      # Description: Receive message with timeout
      # Operand: None
      # Stack Before: [... timeout_seconds]
      # Stack After: [... message_or_null, received_boolean]
      # Side Effects: Returns after timeout if no message

      MESSAGE_RECEIVE_SELECTIVE
      # Description: Receive message matching pattern
      # Operand: Array(Instruction) - pattern matching function
      # Stack Before: [...]
      # Stack After: [... matched_message]
      # Note: Function receives [message] and returns [boolean]
      # Side Effects: Skips non-matching messages

      MESSAGE_RECEIVE_SELECTIVE_WITH_TIMEOUT
      # Description: Receive matching message with timeout
      # Operand: Array(Instruction) - pattern matching function
      # Stack Before: [... timeout_seconds]
      # Stack After: [... message_or_null, received_boolean]

      MESSAGE_PEEK
      # Description: Peek at next message without consuming it
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... message_or_null]

      MESSAGE_MAILBOX_SIZE
      # Description: Get number of messages in current process mailbox
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... size]

      MESSAGE_CANCEL_TIMER
      # Description: Cancel a scheduled delayed message
      # Operand: None
      # Stack Before: [... timer_reference]
      # Stack After: [... success_boolean]

      # Operations for supervisor trees and fault tolerance.

      SUPERVISOR_START_CHILD
      # Description: Start a child process under supervisor
      # Operand: None
      # Stack Before: [... supervisor_process_id, child_specification]
      # Stack After: [... child_process_id]
      # Note: child_specification is a map with restart strategy

      SUPERVISOR_STOP_CHILD
      # Description: Stop a supervised child process
      # Operand: None
      # Stack Before: [... supervisor_process_id, child_id]
      # Stack After: [... success_boolean]

      SUPERVISOR_RESTART_CHILD
      # Description: Restart a supervised child process
      # Operand: None
      # Stack Before: [... supervisor_process_id, child_id]
      # Stack After: [... new_child_process_id]

      SUPERVISOR_LIST_CHILDREN
      # Description: List all children of a supervisor
      # Operand: None
      # Stack Before: [... supervisor_process_id]
      # Stack After: [... children_array]
      # Note: Returns array of child info maps

      SUPERVISOR_COUNT_CHILDREN
      # Description: Count children of a supervisor
      # Operand: None
      # Stack Before: [... supervisor_process_id]
      # Stack After: [... count]

      # Operations for structured exception handling.

      EXCEPTION_THROW
      # Description: Throw an exception
      # Operand: None
      # Stack Before: [... error_value]
      # Stack After: N/A (unwinds stack)
      # Side Effects: Unwinds call stack until handler found

      EXCEPTION_RETHROW
      # Description: Re-throw the current exception in a catch block
      # Operand: None
      # Stack Before: [...]
      # Stack After: N/A (continues unwinding)
      # Errors: Must be in exception handler

      EXCEPTION_TRY_BEGIN
      # Description: Begin a try block
      # Operand: Int64 (offset to catch block)
      # Stack Before: [...]
      # Stack After: [...]
      # Side Effects: Pushes exception handler onto handler stack

      EXCEPTION_TRY_END
      # Description: End a try block (normal exit)
      # Operand: None
      # Stack Before: [...]
      # Stack After: [...]
      # Side Effects: Pops exception handler from handler stack

      EXCEPTION_CATCH
      # Description: Entry point for catch block
      # Operand: None
      # Stack Before: N/A (exception context)
      # Stack After: [... exception_value]
      # Note: Receives the thrown exception

      EXCEPTION_GET_STACKTRACE
      # Description: Get current stack trace as array
      # Operand: None
      # Stack Before: [...]
      # Stack After: [... stacktrace_array]
    end
  end
end
