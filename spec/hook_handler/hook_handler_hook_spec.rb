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
    def hh.handle_const(name)
       const_value(77)
    end

    TEST_CONSTANT_12345 = 8
    hh.evalhook("TEST_CONSTANT_12345").should be == 77
  end

  it "should allow change constant values using hooking" do
    hh = EvalHook::HookHandler.new
    def hh.handle_colon2(context, name)
       const_value(77)
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

   hh.should_receive(:handle_const).with("A") {
	RedirectHelper::Value.new(0)
   }

    hh.evalhook("A")
  end

  module TestModule321
  end

  it "should intercept nested constant access" do
    hh = EvalHook::HookHandler.new

    hh.should_receive(:handle_const).once.with("TestModule321") {
	RedirectHelper::Value.new(TestModule321)
    }
    
    hh.should_receive(:handle_colon2).once.with(TestModule321,"B") {
	RedirectHelper::Value.new(0)
    }

    hh.evalhook("TestModule321::B")
  end

  it "should intercept global_variable access" do
    hh = EvalHook::HookHandler.new

    hh.should_receive(:handle_gvar).with(:$global_variable_test)

    hh.evalhook("$global_variable_test")
  end


  class X
    def foo
    end
  end

  class Y < X
  end

  it "should intercept super as a method call" do
    h = EvalHook::HookHandler.new

    # reference to X for inheritance
    h.should_receive(:handle_const).with("X")

    # reference to Y
    h.should_receive(:handle_const).with("Y")

    # call to new
    h.should_receive(:handle_method).with(Y.class,Y,:new)

    # first Y#foo call
    h.should_receive(:handle_method).with(Y,anything(),:foo)

    # super call
    h.should_receive(:handle_method).with(X,anything(),:foo)

    h.evalhook('

      class Y < X
        def foo
          super
        end
      end
      Y.new.foo

    ', binding)
  end

  class X2
    def foo(a)
      a+1
    end
  end

  class Y2 < X2
  end

  it "should intercept super with explicit arguments as a method call" do
    h = EvalHook::HookHandler.new

    # reference to X for inheritance
    h.should_receive(:handle_const).with("X2")

    # reference to Y
    h.should_receive(:handle_const).with("Y2")

    # call to new
    h.should_receive(:handle_method).with(Y2.class,Y2,:new)

    # first Y#foo call
    h.should_receive(:handle_method).with(Y2,anything(),:foo)

    # super call
    h.should_receive(:handle_method).with(X2,anything(),:foo)

    h.evalhook('

      class Y2 < X2
        def foo(a)
          super(a)
        end
      end
      Y2.new.foo(9)

    ', binding).should be == 10
   end

end