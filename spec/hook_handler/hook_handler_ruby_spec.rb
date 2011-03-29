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
      ", binding)
  end

  it "should allow creation of locals" do
    # FAILED due an incompatibility of default ruby with rspec
    # test_hook_handler.evalhook("local_test = 1")
    # local_test.should be == 1
  end

  it "should allow assignment of locals" do
    local_test = nil
    test_hook_handler.evalhook("local_test = 1", binding)
    local_test.should be == 1
  end

end