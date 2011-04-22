require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler hooks" do

  class X2
    def foo
      9
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

    x = X2.new
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

  it "should intercept constant access" do
    hh = EvalHook::HookHandler.new
    def hh.handle_const(context, name)
       const_value(77)
    end

    TEST_CONSTANT_12345 = 8
    hh.evalhook("TEST_CONSTANT_12345").should be == 77
  end

  it "should allow change constant values using hooking" do
    hh = EvalHook::HookHandler.new
    def hh.handle_const(context, name)
       if (name == "Object")
         nil
       else
         const_value(77)
       end
    end

    TEST_CONSTANT_12346 = 8
    hh.evalhook("Object::TEST_CONSTANT_12346").should be == 77
  end

  it "should allow change global variable values using hooking" do
    hh = EvalHook::HookHandler.new
    def hh.handle_gvar(global_id)
       global_value(88)
    end

    $test_global_12345 = 9
    hh.evalhook("$test_global_12345").should be == 88
  end

  it "should intercept constant access" do
    hh = EvalHook::HookHandler.new

    hh.should_receive(:handle_const).with(Object,"A")

    hh.evalhook("A")
  end

  module TestModule321
  end

  it "should intercept nested constant access" do
    hh = EvalHook::HookHandler.new

    hh.should_receive(:handle_const).once.with(Object,"TestModule321")
    hh.should_receive(:handle_const).once.with(TestModule321,"B")

    hh.evalhook("TestModule321::B")
  end

end