module AbstractMachine
  module Engine
    module Debugger
      class Breakpoint
        getter id : UInt64
        getter? enabled : Bool = true
        getter hit_count : Int32 = 0
        property ignore_count : Int32 = 0

        @@next_id : UInt64 = 0_u64

        @condition : Process::Context -> Bool

        def initialize(&@condition : Process::Context -> Bool)
          @id = @@next_id
          @@next_id += 1
        end

        def check(process : Process::Context) : Bool
          return false unless @enabled

          if @condition.call(process)
            @hit_count += 1

            # Skip if we haven't hit ignore_count yet
            if @hit_count <= @ignore_count
              return false
            end

            true
          else
            false
          end
        end

        def enable : self
          @enabled = true
          self
        end

        def disable : self
          @enabled = false
          self
        end

        def reset_hit_count : self
          @hit_count = 0
          self
        end
      end
    end
  end
end
