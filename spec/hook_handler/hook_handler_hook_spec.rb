require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler hooks" do

  class TestHookHandler < EvalHook::HookHandler
    def handle_method(klass, recv, method_name)
      if (method_name == :foo)
        return redirect_method(klass, recv, "bar")
      end

      nil
    end

    def handle_gasgn(global_id, value)
      if global_id == :$test_global_variable
        return redirect_gasgn(global_id, 7)
      end

      nil
    end

    def handle_cdecl(context, name, value)
      if (name == :TEST_CONSTANT)
        return redirect_cdecl(context, name, 7)
      end

      nil
    end

  end

  class X
    def foo
    end

    def bar
      4
    end
  end

  it "should intercept and change method calls" do
    hh = TestHookHandler.new

    x = X.new
    x.should_receive(:bar)
    hh.evalhook("x.foo", binding).should be == 4
  end

  it "should intercept and change global variable assignments" do
    hh = TestHookHandler.new

    hh.evalhook("$test_global_variable = 9")
    $test_global_variable.should be == 7
  end

  it "should intercept and change constant assignments" do
    hh = TestHookHandler.new

    hh.evalhook("TEST_CONSTANT = 9")
    TEST_CONSTANT.should be == 7
  end

end