require "rubygems"
require "evalhook"

class NilClass
  def strip
    ""
  end
end

describe EvalHook::HookHandler, "hook handler defaults" do
   it "should throw exception when call evalhook with no parameters" do
  		hook_handler = EvalHook::HookHandler.new

  		lambda {
  			hook_handler.evalhook
  		}.should raise_error(ArgumentError)
   end

  exprlist = ["1+1", "[1,2,3].map{|x| x*2}"]

  exprlist.each do |expr|
    it "should eval expresion '#{expr}' same as eval" do
      hook_handler = EvalHook::HookHandler.new

      expected = eval(expr)
      hook_handler.evalhook(expr).should be == expected

    end
  end

  it "should allow reference to global variables" do
     hook_handler = EvalHook::HookHandler.new

     $global_variable_test = 5
     hook_handler.evalhook("$global_variable_test").should be == $global_variable_test
  end

  it "should allow reference to constants" do
     hook_handler = EvalHook::HookHandler.new

     CONSTANTTEST = 5
     hook_handler.evalhook("CONSTANTTEST").should be == CONSTANTTEST
  end

  it "should allow reference to local variables" do
     hook_handler = EvalHook::HookHandler.new

     a = 5
     hook_handler.evalhook("a").should be == a
  end


  class N
    def foo(hook_handler)
      @a = 5
      hook_handler.evalhook("@a")
    end
  end


  it "should allow reference to instance variables" do
     hook_handler = EvalHook::HookHandler.new
     N.new.foo(hook_handler).should be == 5
  end

  class X
    def foo
      3
    end
  end

  it "should allow method calls" do
    hook_handler = EvalHook::HookHandler.new
    hook_handler.evalhook("X.new.foo").should be X.new.foo
  end

  it "should capture method calls" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_method).with(X.class,X,:new)
    hook_handler.should_receive(:handle_method).with(X,anything(),:foo)

    hook_handler.evalhook("X.new.foo")
  end

  it "should capture constant assignment" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_cdecl).with(Object,:TEST_CONSTANT,4)
    hook_handler.evalhook("TEST_CONSTANT = 4")

  end

  it "should capture global assignment" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_gasgn).with(:$test_global_variable,4)
    hook_handler.evalhook("$test_global_variable = 4")

  end

  it "should capture system exec with backsticks" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_xstr).with("echo test")
    hook_handler.evalhook("`echo test`")

  end

  it "should capture system exec with backsticks and dynamic strings" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_xstr).with("echo test")
    hook_handler.evalhook("`echo \#{}test`")

  end

  it "should capture system exec with %x" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_xstr).with("echo test")
    hook_handler.evalhook("%x[echo test]")
  end


  module B

  end
  module A
    module B

    end
  end

  it "should allow define base_namespace" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = :A
    hook_handler.evalhook("::B").should be == A::B
  end

end

