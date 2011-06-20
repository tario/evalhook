require "rubygems"
require "evalhook"

class NilClass
  def strip
    ""
  end
end

$top_level_binding = binding

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
      hook_handler.evalhook(expr, binding).should be == expected

    end
  end

  it "should allow reference to global variables" do
     hook_handler = EvalHook::HookHandler.new

     $global_variable_test = 5
     hook_handler.evalhook("$global_variable_test", binding).should be == $global_variable_test
  end

  it "should allow reference to constants" do
     hook_handler = EvalHook::HookHandler.new

     ::CONSTANTTEST = 5
     hook_handler.evalhook("CONSTANTTEST", binding).should be == CONSTANTTEST
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

  class ::X
    def foo
      3
    end
  end

  it "should allow method calls" do
    hook_handler = EvalHook::HookHandler.new
    hook_handler.evalhook("X.new.foo", binding).should be(X.new.foo)
  end

  it "should capture method calls" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_method).with(X.class,X,:new)
    hook_handler.should_receive(:handle_method).with(X,anything(),:foo)

    hook_handler.evalhook("X.new.foo", binding)
  end

  it "should capture constant assignment" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_cdecl).with(Object,:TEST_CONSTANT,4)
    hook_handler.evalhook("TEST_CONSTANT = 4", binding)

  end

  it "should capture global assignment" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_gasgn).with(:$test_global_variable,4)
    hook_handler.evalhook("$test_global_variable = 4", binding)

  end

  it "should capture system exec with backsticks" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_xstr).with("echo test")
    hook_handler.evalhook("`echo test`", binding)

  end

  it "should capture system exec with backsticks and dynamic strings" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_xstr).with("echo test")
    hook_handler.evalhook("`echo \#{}test`", binding)

  end

  it "should capture system exec with %x" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.should_receive(:handle_xstr).with("echo test")
    hook_handler.evalhook("%x[echo test]", binding)
  end


  module ::B

  end
  module ::A
    module B
      class C

      end

    end
  end

  it "should allow define base_namespace" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = ::A
    hook_handler.evalhook("::B", binding).should be == ::A::B
  end

  it "should allow define base_namespace (const)" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = ::A
    hook_handler.evalhook("::B", binding).should be == ::A::B
  end

  class ::C1
    def foo
      "C1#foo"
    end
  end
  module ::A1
    class C1
      def foo
        "A1::C1#foo"
      end
    end
  end

  it "should allow define base_namespace (class)" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = ::A1
    hook_handler.evalhook("class ::C1
            def foo
              'A1::C1#foo at evalhook'
            end
        end" , binding)

    C1.new.foo.should be == "C1#foo" # C1#foo class remains unchanged
    A1::C1.new.foo.should be == "A1::C1#foo at evalhook" # A1::C1#foo changes
  end


  class ::C2
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
    ", binding)

    C2.new.foo.should be == "::C2#foo at evalhook"
  end

  module ::A1
    module A2

    end
  end


  it "should allow define base_namespace (3 levels)" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.base_namespace = ::A1::A2
    hook_handler.evalhook("class ::C1
            def foo
              'A1::A2::C1#foo at evalhook'
            end
        end", binding)

    C1.new.foo.should be == "C1#foo" # C1#foo class remains unchanged
    A1::A2::C1.new.foo.should be == "A1::A2::C1#foo at evalhook" # A1::C1#foo changes
  end

  it "should allow declaring classes with ::" do
    EvalHook::HookHandler.new.evalhook("class Fixnum::TestClass12345; end", binding)
  end

  module ::TestInheritedClassMethodError
    class A
        def self.foo
            'Foo'
        end
    end

    class B < A
    end
  end

  it "inherited class method should execute" do
    hh = EvalHook::HookHandler.new
    hh.evalhook('TestInheritedClassMethodError::B.foo', binding)
  end

  it "should allow declaring modules with ::" do
    EvalHook::HookHandler.new.evalhook("module Fixnum::TestModule12345; end", binding)
  end

  module ::TestModule12347
  end

  it "should allow assignment of constants nested on modules" do
    EvalHook::HookHandler.new.evalhook("TestModule12347::A = 9", binding)
  end

  class ::XTEST44
    def foo(a)
      a+1
    end
  end
  it "should pass arguments on super" do
    EvalHook::HookHandler.new.evalhook('
      class ::YTEST44 < XTEST44
        def foo(a)
          super
        end
      end
      ::YTEST44.new.foo(9)
    ', binding).should be == 10
  end

  it "should pass arguments on super (explicitly)" do
    EvalHook::HookHandler.new.evalhook('
      class ::YTEST45 < XTEST44
        def foo(a)
          super(a)
        end
      end
      ::YTEST45.new.foo(9)
    ', binding).should be == 10
  end

  it "should pass arguments on super with three levels" do
    EvalHook::HookHandler.new.evalhook('
      class ::YTEST46 < XTEST44
        def foo(a)
          super(a)
        end
      end

      class ::ZTEST46 < ::YTEST46
        def foo(a)
          super(a)
        end
      end
      ::ZTEST46.new.foo(9)
    ', binding).should be == 10

  end

  it "should raise SecurityError when use super outside a class" do

    lambda {

    EvalHook::HookHandler.new.evalhook('
      module ::MODULETEST48
        def foo(a)
          super(a)
        end
      end

      class ::XTEST48 < XTEST44
        include ::MODULETEST48
      end
      ::XTEST48.new.foo(9)
    ', binding)

    }.should raise_error(SecurityError)

  end

  it "should raise SecurityError when use super inside a module nested on class" do

    lambda {

    EvalHook::HookHandler.new.evalhook('

      class ::CLASSTEST49
        module MODULETEST49
          def foo(a)
            super(a)
          end
        end
      end

      class ::YTEST49 < XTEST44
        include CLASSTEST49::MODULETEST49
      end
      ::YTEST49.new.foo(9)
    ', binding)

    }.should raise_error(SecurityError)

  end

  it "should pass arguments on super with no arguments throught three levels" do
    EvalHook::HookHandler.new.evalhook('
      class ::YTEST50 < XTEST44
        def foo(a)
          super
        end
      end

      class ::ZTEST50 < ::YTEST50
        def foo(a)
          super
        end
      end
      ::ZTEST50.new.foo(9)
    ', binding).should be == 10

  end

  it "should raise SecurityError when use super with no arguments outside a class" do

    lambda {

    EvalHook::HookHandler.new.evalhook('
      module ::MODULETEST51
        def foo(a)
          super
        end
      end

      class ::XTEST51 < ::XTEST44
        include ::MODULETEST51
      end
      ::XTEST51.new.foo(9)
    ', binding)

    }.should raise_error(SecurityError)

  end

  it "should raise SecurityError when use super with no arguments inside a module nested on class" do

    lambda {

    EvalHook::HookHandler.new.evalhook('

      class ::CLASSTEST52
        module MODULETEST52
          def foo(a)
            super
          end
        end
      end

      class ::YTEST52 < ::XTEST44
        include ::CLASSTEST52::MODULETEST52
      end
      ::YTEST52.new.foo(9)
    ', binding)

    }.should raise_error(SecurityError)

  end

  it "should execute super call from singleton methods" do
    EvalHook::HookHandler.new.evalhook('

      class ::CLASSTEST53
        def bar(a)
            a+1
        end
      end

      obj = ::CLASSTEST53.new

      def obj.bar(a)
        super(a+1)
      end
      obj.bar(10)
    ', binding).should be == 12
  end

  it "should reference constants in same context" do
    EvalHook::HookHandler.new.evalhook("XCONSTANT=9; XCONSTANT", binding).should be == 9
  end

  it "should reference classes in same context" do
    EvalHook::HookHandler.new.evalhook("class XCLASS; end; XCLASS", $top_level_binding)
  end

  it "should reference modules in same context" do
    EvalHook::HookHandler.new.evalhook("module XMODULE; end; XMODULE", $top_level_binding)
  end

end

