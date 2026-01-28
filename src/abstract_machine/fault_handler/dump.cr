module AbstractMachine
  module FaultHandler
    # Crash dump for post-mortem debugging
    class Dump
      getter process_address : UInt64
      getter registered_name : String?
      getter reason : Process::Reason::Context
      getter stack_trace : Array(Value::Context)
      getter call_stack : Array(UInt64)
      getter counter : UInt64
      getter locals : Array(Value::Context)
      getter mailbox_size : Int32
      getter timestamp : Time

      def initialize(process : Process::Context, @reason : Process::Reason::Context)
        @process_address = process.address
        @registered_name = process.registered_name
        @stack_trace = process.stack.map(&.clone)
        @call_stack = process.call_stack.dup
        @counter = process.counter
        @locals = process.locals.map(&.clone)
        @mailbox_size = process.mailbox.size
        @timestamp = Time.utc
      end

      def to_s : String
        String.build do |str|
          str << "=== CRASH DUMP ===\n"
          str << "Process: <#{@process_address}>"
          str << " (#{@registered_name})" if @registered_name
          str << "\n"
          str << "Time: #{@timestamp}\n"
          str << "Exit Reason: #{@reason}\n"
          str << "Counter: #{@counter}\n"
          str << "Stack Size: #{@stack_trace.size}\n"
          str << "Call Stack: #{@call_stack.inspect}\n"
          str << "Locals: #{@locals.size}\n"
          str << "Mailbox Size: #{@mailbox_size}\n"

          if @stack_trace.any?
            str << "\nStack (top 10):\n"
            @stack_trace.last(10).reverse_each.with_index do |val, i|
              str << "  #{i}: #{val.inspect}\n"
            end
          end

          if @reason.stacktrace.any?
            str << "\nException Stacktrace:\n"
            @reason.stacktrace.first(20).each do |line|
              str << "  #{line}\n"
            end
          end

          str << "=== END CRASH DUMP ===\n"
        end
      end
    end
  end
end
