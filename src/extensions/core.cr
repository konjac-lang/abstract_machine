require "./*"

struct Symbol
  def to_s
    (to_i < 0 ? AbstractMachine::Extensions::Symbol.to_s(self) : previous_def).to_s
  end

  def ==(other)
    return false unless other.is_a? Symbol
    to_s == other.to_s
  end

  def ==(other : Symbol)
    (to_i * other.to_i) < 0 ? to_s == other.to_s : to_i == other.to_i
  end
end

class String
  def to_symbol
    AbstractMachine::Extensions::Symbol.for self
  end
end
