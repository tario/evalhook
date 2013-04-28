require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler hooks" do

  it "should raise NoMethodError when tring to call private method" do
    hh = EvalHook::HookHandler.new
    lambda {
      hh.evalhook("{}.system('ls -l')", binding)
    }.should raise_error(NoMethodError)
  end


  it "should raise NoMethodError when tring to call private method" do
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

end