require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler hooks" do

  class X
    def foo
    end

    def bar
      4
    end
  end

  it "should intercept and change method calls" do
    hh = EvalHook::HookHandler.new
    def hh.handle_method(klass, recv, method_name)
      redirect_method(klass, recv, :bar)
    end

    x = X.new
    hh.evalhook("x.foo", binding).should be == 4
  end

  it "should intercept and change global variable assignments" do
    hh = EvalHook::HookHandler.new
    def hh.handle_gasgn(global_id, value)
      redirect_gasgn(global_id, 7)
    end

    hh.evalhook("$test_global_variable = 9")
    $test_global_variable.should be == 7
  end

  it "should intercept and change constant assignments" do
    hh = EvalHook::HookHandler.new
    def hh.handle_cdecl(context, name, value)
       redirect_cdecl(context,name,7)
    end

    hh.evalhook("TEST_CONSTANT = 9")
    TEST_CONSTANT.should be == 7
  end

end