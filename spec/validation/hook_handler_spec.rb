require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler flaws" do

  it "should validate invalid syntax" do

    hh = EvalHook::HookHandler.new

    lambda {
      hh.evalhook("
            0
            end
            if (true)
        ")
    }.should raise_error(SyntaxError)

  end

  it "should validate as OK empty string" do
    hh = EvalHook::HookHandler.new
    hh.evalhook("")
  end
end