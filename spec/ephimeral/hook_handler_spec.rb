require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler flaws" do

  it "should raise SecurityError exception when try to run code with backsticks" do

    hh = EvalHook::HookHandler.new

    lambda {
      hh.evalhook("`ls -l`")
    }.should raise_error(SecurityError)

  end

  it "should raise SecurityError exception when try to run code with %x system calls" do

    hh = EvalHook::HookHandler.new

    lambda {
      hh.evalhook("%x[ls -l]")
    }.should raise_error(SecurityError)

  end

end