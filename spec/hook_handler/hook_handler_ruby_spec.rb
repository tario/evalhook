require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler ruby basics" do

  class X
    def foo

    end
  end

  def test_hook_handler
    EvalHook::HookHandler.new
  end

  it "should call singleton methods" do

    test_hook_handler.evalhook("
         x = X.new
         def x.bar
         end
         x.bar
      ")
  end

  it "should call 'global' functions" do

    test_hook_handler.evalhook("
         def bar
         end
         bar
      ")
  end

end