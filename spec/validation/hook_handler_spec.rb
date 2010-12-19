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
end