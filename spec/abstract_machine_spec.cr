require "./spec_helper"

describe AbstractMachine do
  it "has a version number" do
    expect(AbstractMachine::VERSION).not_to be_nil
  end
end
