require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler" do

  it "should accept specified source name" do
    hh = EvalHook::HookHandler.new

    begin
      hh.evalhook("raise '0'",binding, "sourcename", 1)
    rescue Exception => e
      e.backtrace.join.include?("sourcename").should be == true
    end
  end
end