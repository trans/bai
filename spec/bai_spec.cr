require "./spec_helper"

describe Bai do
  it "exposes a version string" do
    Bai::VERSION.should eq("0.1.0")
  end

  it "returns success for help output" do
    Bai.run(["--help"]).should eq(0)
  end
end
