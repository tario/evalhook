require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler hooks" do

  it "should raise NoMethodError when trying to call private method" do
    hh = EvalHook::HookHandler.new
    lambda {
      hh.evalhook("{}.system('ls -l')", binding)
    }.should raise_error(NoMethodError)
  end


  it "should raise NoMethodError when trying to call private method" do
    hh = EvalHook::HookHandler.new
    lambda {
      hh.evalhook("
          class CALL_SPEC_TEST
              def foo
                bar
              end
            private
              def bar
              end
          end

          CALL_SPEC_TEST.new.foo
        ", binding)
    }.should_not raise_error
  end

  class XDefinedOutside55
    def method_missing(name)
      name
    end
  end
  XDefinedOutside55_ins = XDefinedOutside55.new

  context "when there is method_missing defined" do
    it "shouldn't raise NoMethodError when trying to call a public method NOT defined" do
      hh = EvalHook::HookHandler.new
      lambda {
        hh.evalhook("
          XDefinedOutside55_ins.foo
          ", binding).should be == :foo
      }.should_not raise_error
    end
  end

  class XDefinedOutside56
    def method_missing(name, param1)
      name
    end
  end
  XDefinedOutside56_ins = XDefinedOutside56.new
  
  context "when there is method_missing defined (two arguments)" do
    it "shouldn't raise NoMethodError when trying to call a public method NOT defined" do
      hh = EvalHook::HookHandler.new
      lambda {
        hh.evalhook("
          XDefinedOutside56_ins.foo(1)
          ", binding).should be == :foo
      }.should_not raise_error
    end
  end
end