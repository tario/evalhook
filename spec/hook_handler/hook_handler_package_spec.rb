require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler" do

  it "should return package of code" do
    hh = EvalHook::HookHandler.new

    lambda {
      hh.packet("0")
    }.should_not raise_error

  end

  it "should execute package of code" do
    hh = EvalHook::HookHandler.new

    lambda {
      hh.packet("0").run(binding).should be == 0
    }.should_not raise_error

  end
end