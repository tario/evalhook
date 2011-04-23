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
     hook_handler.evalhook("a", binding).should be == a
  end


  class N
    def foo(hook_handler)
      @a = 5
      hook_handler.evalhook("@a", binding)
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
      class C

      end

    end
  end

  it "should allow define base_namespace" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = :A
    hook_handler.evalhook("::B").should be == A::B
  end

  it "should allow define base_namespace (const)" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = A
    hook_handler.evalhook("::B").should be == A::B
  end

  class C1
    def foo
      "C1#foo"
    end
  end
  module A1
    class C1
      def foo
        "A1::C1#foo"
      end
    end
  end

  it "should allow define base_namespace (class)" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = A1
    hook_handler.evalhook("class ::C1
            def foo
              'A1::C1#foo at evalhook'
            end
        end")

    C1.new.foo.should be == "C1#foo" # C1#foo class remains unchanged
    A1::C1.new.foo.should be == "A1::C1#foo at evalhook" # A1::C1#foo changes
  end


  class C2
    def foo
      "C2#foo"
    end
  end

  it "should default base_namespace to Object" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.evalhook("

        module Z
          class ::C2
              def foo
                '::C2#foo at evalhook'
              end
          end

        end
    ")

    C2.new.foo.should be == "::C2#foo at evalhook"
  end

  module A1
    module A2

    end
  end


  it "should allow define base_namespace (3 levels)" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = A1::A2
    hook_handler.evalhook("class ::C1
            def foo
              'A1::A2::C1#foo at evalhook'
            end
        end")

    C1.new.foo.should be == "C1#foo" # C1#foo class remains unchanged
    A1::A2::C1.new.foo.should be == "A1::A2::C1#foo at evalhook" # A1::C1#foo changes
  end

  it "should use current binding when not specified" do
    a = 9
    EvalHook::HookHandler.new.evalhook("a").should be == 9
  end

  it "should allow declaring classes with ::" do
    EvalHook::HookHandler.new.evalhook("class Fixnum::TestClass12345; end")
  end

  it "should allow declaring modules with ::" do
    EvalHook::HookHandler.new.evalhook("module Fixnum::TestModule12345; end")
  end

  module TestModule12347
  end

  it "should allow assignment of constants nested on modules" do
    EvalHook::HookHandler.new.evalhook("TestModule12347::A = 9")
  end

end

