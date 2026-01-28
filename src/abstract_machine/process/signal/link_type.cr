module AbstractMachine
  module Process
    module Signal
      enum LinkType
        Link    # Bidirectional link
        Monitor # Unidirectional monitor
      end
    end
  end
end
