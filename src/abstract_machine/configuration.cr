module AbstractMachine
  class Configuration
    property max_processes : Int32 = 100
    property max_stack_size : Int32 = 1000
    property max_mailbox_size : Int32 = 100
    property max_instructions_per_cycle : Int32 = 10
    property max_reductions_per_slice : UInt64 = 4000_u64
    property execution_delay : Time::Span = 0.001.seconds
    property iteration_limit : Int32 = 10000
    property default_message_ttl : Time::Span = 30.seconds
    property default_receive_timeout : Time::Span = 5.seconds
    property mailbox_full_behavior : Symbol = :block # :block, :drop, :fail
    property? auto_reactivate_processes : Bool = true
    property? enable_message_acknowledgments : Bool = false
    property message_cleanup_interval : Time::Span = 5.seconds
  end
end
