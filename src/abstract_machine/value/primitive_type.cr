module AbstractMachine
  module Value
    # Enum for efficient type identification of primitive types
    enum PrimitiveType : UInt8
      Null
      Integer
      UnsignedInteger
      Float
      String
      Symbol
      Boolean
      Map
      Array
      Binary
      Lambda
      Instructions
      Custom
    end
  end
end
