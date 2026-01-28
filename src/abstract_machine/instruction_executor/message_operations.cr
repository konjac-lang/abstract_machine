module AbstractMachine
  module InstructionExecutor
    module MessageOperations
      extend self

      # MESSAGE_SEND
      # Send message to another process
      # Stack Before: [... target_process_id, message]
      # Stack After: [...]
      private def execute_message_send(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 2, "MESSAGE_SEND")

        message_value = process.stack.pop
        target_value = process.stack.pop

        target_process_id = resolve_target_process_id(target_value, "MESSAGE_SEND")

        target = @engine.processes.find { |actual_process| actual_process.address == target_process_id && actual_process.state != Process::State::DEAD }

        unless target
          raise Exceptions::InvalidAddress.new("MESSAGE_SEND target process #{target_process_id} not found or dead")
        end

        # Check mailbox capacity
        if target.mailbox.size >= @engine.configuration.max_mailbox_size
          handle_mailbox_full(process, target, message_value)
          return Value::Context.null
        end

        # Create and send message
        message = Message::Context.new(
          sender: process.address,
          value: message_value,
          needs_ack: @engine.configuration.enable_message_acknowledgments?,
          ttl: @engine.configuration.default_message_ttl
        )

        target.mailbox.push(message)

        # Wake up target if waiting for messages
        maybe_wake_receiver(target, message)

        Value::Context.null
      end

      # MESSAGE_SEND_AFTER
      # Schedule message to be sent after delay
      # Stack Before: [... target_process_id, message, delay_seconds]
      # Stack After: [... timer_reference]
      private def execute_message_send_after(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 3, "MESSAGE_SEND_AFTER")

        delay_value = process.stack.pop
        message_value = process.stack.pop
        target_value = process.stack.pop

        unless delay_value.numeric?
          raise Exceptions::TypeMismatch.new("MESSAGE_SEND_AFTER requires numeric delay in seconds")
        end

        target_process_id = resolve_target_process_id(target_value, "MESSAGE_SEND_AFTER")
        delay_seconds = delay_value.to_f64

        if delay_seconds < 0
          raise Exceptions::Value.new("MESSAGE_SEND_AFTER delay cannot be negative")
        end

        # Schedule the delayed message
        timer_ref = @engine.timer_manager.schedule_message(
          sender: process.address,
          target: target_process_id,
          message: message_value,
          delay: delay_seconds.seconds
        )

        result = Value::Context.new(timer_ref.to_i64)
        process.stack.push(result)

        result
      end

      # MESSAGE_RECEIVE
      # Receive next message from mailbox (blocking)
      # Stack Before: [...]
      # Stack After: [... message]
      private def execute_message_receive(process : Process::Context) : Value::Context
        process.counter += 1

        if process.mailbox.empty?
          # Block waiting for message
          process.state = Process::State::WAITING
          process.waiting_for = nil
          process.waiting_since = Time.utc
          process.waiting_timeout = nil
          process.counter -= 1 # Re-execute when woken

          @engine.scheduler.wait_for_message(process, nil, nil)

          return Value::Context.null
        end

        # Get next message
        message = process.mailbox.shift
        return Value::Context.null unless message

        # Send acknowledgment if required
        send_ack_if_needed(process, message)

        # Check for blocked senders
        @engine.check_blocked_sends(process)

        process.stack.push(message.value)
        message.value
      end

      # MESSAGE_RECEIVE_WITH_TIMEOUT
      # Receive message with timeout
      # Stack Before: [... timeout_seconds]
      # Stack After: [... message_or_null, received_boolean]
      private def execute_message_receive_with_timeout(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MESSAGE_RECEIVE_WITH_TIMEOUT")

        timeout_value = process.stack.pop

        unless timeout_value.numeric?
          raise Exceptions::TypeMismatch.new("MESSAGE_RECEIVE_WITH_TIMEOUT requires numeric timeout")
        end

        timeout_seconds = timeout_value.to_f64

        if !process.mailbox.empty?
          # Message available immediately
          message = process.mailbox.shift
          return Value::Context.null unless message

          send_ack_if_needed(process, message)
          @engine.check_blocked_sends(process)

          process.stack.push(message.value)
          process.stack.push(Value::Context.new(true))

          return message.value
        end

        if timeout_seconds <= 0
          # Immediate timeout, no message
          process.stack.push(Value::Context.null) # null
          process.stack.push(Value::Context.new(false))

          return Value::Context.null
        end

        # Block with timeout
        process.state = Process::State::WAITING
        process.waiting_for = nil
        process.waiting_since = Time.utc
        process.waiting_timeout = timeout_seconds.seconds
        process.counter -= 1 # Re-execute when woken

        @engine.scheduler.wait_for_message(process, nil, timeout_seconds.seconds)

        Value::Context.null
      end

      # MESSAGE_RECEIVE_SELECTIVE
      # Receive message matching pattern
      # Operand: Array(Instruction) - pattern matching function
      # Stack Before: [...]
      # Stack After: [... matched_message]
      private def execute_message_receive_selective(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("MESSAGE_RECEIVE_SELECTIVE requires instruction array operand")
        end

        matcher_instructions = instruction.value.to_instructions

        # Search mailbox for matching message
        matched_message = find_matching_message(process, matcher_instructions)

        if matched_message
          send_ack_if_needed(process, matched_message)
          @engine.check_blocked_sends(process)

          process.stack.push(matched_message.value)
          return matched_message.value
        end

        # No match - block waiting
        process.state = Process::State::WAITING
        process.waiting_for = Value::Context.new(matcher_instructions) # Store matcher
        process.waiting_since = Time.utc
        process.waiting_timeout = nil
        process.counter -= 1 # Re-execute when woken

        @engine.scheduler.wait_for_message(process, process.waiting_for, nil)

        Value::Context.null
      end

      # MESSAGE_RECEIVE_SELECTIVE_WITH_TIMEOUT
      # Receive matching message with timeout
      # Operand: Array(Instruction) - pattern matching function
      # Stack Before: [... timeout_seconds]
      # Stack After: [... message_or_null, received_boolean]
      private def execute_message_receive_selective_with_timeout(process : Process::Context, instruction : Instruction::Operation) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MESSAGE_RECEIVE_SELECTIVE_WITH_TIMEOUT")

        timeout_value = process.stack.pop

        unless timeout_value.numeric?
          raise Exceptions::TypeMismatch.new("MESSAGE_RECEIVE_SELECTIVE_WITH_TIMEOUT requires numeric timeout")
        end

        unless instruction.value.instructions?
          raise Exceptions::TypeMismatch.new("MESSAGE_RECEIVE_SELECTIVE_WITH_TIMEOUT requires instruction array operand")
        end

        timeout_seconds = timeout_value.to_f64
        matcher_instructions = instruction.value.to_instructions

        # Search mailbox for matching message
        matched_message = find_matching_message(process, matcher_instructions)

        if matched_message
          send_ack_if_needed(process, matched_message)
          @engine.check_blocked_sends(process)

          process.stack.push(matched_message.value)
          process.stack.push(Value::Context.new(true))

          return matched_message.value
        end

        if timeout_seconds <= 0
          # Immediate timeout, no match
          process.stack.push(Value::Context.null) # null
          process.stack.push(Value::Context.new(false))

          return Value::Context.null
        end

        # Block with timeout
        process.state = Process::State::WAITING
        process.waiting_for = Value::Context.new(matcher_instructions)
        process.waiting_since = Time.utc
        process.waiting_timeout = timeout_seconds.seconds
        process.counter -= 1 # Re-execute when woken

        @engine.scheduler.wait_for_message(process, process.waiting_for, timeout_seconds.seconds)

        Value::Context.null
      end

      # MESSAGE_PEEK
      # Peek at next message without consuming it
      # Stack Before: [...]
      # Stack After: [... message_or_null]
      private def execute_message_peek(process : Process::Context) : Value::Context
        process.counter += 1

        if message = process.mailbox.peek
          result = message.value.clone
        else
          result = Value::Context.null # null
        end

        process.stack.push(result)
        result
      end

      # MESSAGE_MAILBOX_SIZE
      # Get number of messages in current process mailbox
      # Stack Before: [...]
      # Stack After: [... size]
      private def execute_message_mailbox_size(process : Process::Context) : Value::Context
        process.counter += 1

        result = Value::Context.new(process.mailbox.size.to_i64)
        process.stack.push(result)

        result
      end

      # MESSAGE_CANCEL_TIMER
      # Cancel a scheduled delayed message
      # Stack Before: [... timer_reference]
      # Stack After: [... success_boolean]
      private def execute_message_cancel_timer(process : Process::Context) : Value::Context
        process.counter += 1
        check_stack_size(process, 1, "MESSAGE_CANCEL_TIMER")

        timer_ref_value = process.stack.pop

        unless timer_ref_value.integer? || timer_ref_value.unsigned_integer?
          raise Exceptions::TypeMismatch.new("MESSAGE_CANCEL_TIMER requires an integer timer reference")
        end

        timer_ref = timer_ref_value.to_i64.to_u64

        success = @engine.timer_manager.cancel(timer_ref)

        result = Value::Context.new(success)
        process.stack.push(result)

        result
      end

      # Resolve target process ID from various formats
      private def resolve_target_process_id(target_value : Value::Context, operation : String) : UInt64
        if target_value.integer? || target_value.unsigned_integer?
          process_id = target_value.to_i64
          if process_id < 0
            raise Exceptions::Value.new("#{operation} process ID cannot be negative")
          end
          process_id.to_u64
        elsif target_value.string?
          # Look up by registered name
          name = target_value.to_s
          if process_id = @engine.process_registry.lookup(name)
            process_id
          else
            raise Exceptions::InvalidAddress.new("#{operation} no process registered as '#{name}'")
          end
        elsif target_value.symbol?
          # Look up by registered name (symbol)
          name = target_value.to_symbol.to_s
          if process_id = @engine.process_registry.lookup(name)
            process_id
          else
            raise Exceptions::InvalidAddress.new("#{operation} no process registered as '#{name}'")
          end
        else
          raise Exceptions::TypeMismatch.new("#{operation} requires integer process ID or registered name")
        end
      end

      # Handle mailbox full situation
      private def handle_mailbox_full(
        sender : Process::Context,
        target : Process::Context,
        message_value : Value::Context,
      )
        case @engine.configuration.mailbox_full_behavior
        when :fail
          raise Exceptions::MailboxOverflow.new("Target mailbox is full")
        when :drop
          # Silently drop the message
          return
        when :block
          # Block the sender
          message = Message::Context.new(
            sender: sender.address,
            value: message_value,
            needs_ack: @engine.configuration.enable_message_acknowledgments?,
            ttl: @engine.configuration.default_message_ttl
          )

          sender.state = Process::State::BLOCKED
          sender.blocked_sends << {target.address, message}
          @engine.scheduler.block_on_send(sender)
        end
      end

      # Wake up a receiver if they're waiting for this message
      private def maybe_wake_receiver(target : Process::Context, message : Message::Context)
        return unless target.state == Process::State::WAITING

        # Check if message matches what they're waiting for
        should_wake = if target.waiting_for.nil?
                        true # Waiting for any message
                      elsif target.waiting_for.not_nil!.instructions?
                        # Would need to run matcher - for now, wake and let them re-check
                        true
                      else
                        # Pattern match
                        target.mailbox.matches_pattern?(message.value, target.waiting_for.not_nil!)
                      end

        if should_wake
          @engine.queue_process_for_reactivation(target)
        end
      end

      # Send acknowledgment if message requires it
      private def send_ack_if_needed(process : Process::Context, message : Message::Context)
        return unless message.needs_ack && @engine.configuration.enable_message_acknowledgments?

        ack = Message::Acknowledgment.new(message.id, process.address, :processed)

        if sender = @engine.processes.find { |actual_process| actual_process.address == message.sender }
          sender.mailbox.add_ack(ack)
        end
      end

      # Find a message matching the given pattern function
      private def find_matching_message(
        process : Process::Context,
        matcher_instructions : Array(Instruction::Operation),
      ) : Message::Context?
        process.mailbox.messages.each_with_index do |message, index|
          # Run matcher function with message value
          result = execute_inline_function(process, matcher_instructions, [message.value])

          if result.to_bool
            # Found match - remove from mailbox
            process.mailbox.remove_at(index)
            return message
          end
        end

        nil # No match found
      end
    end
  end
end
