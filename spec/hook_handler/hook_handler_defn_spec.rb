require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler defn" do

  class XXZ
    def bar
    end
  end

  it "should execute two lines on defn" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.evalhook("
      def foo(x)
        x.bar
        x.bar
      end", binding)

    xxz = XXZ.new
    xxz.should_receive(:bar).twice
    foo(xxz)
  end

  it "should execute two lines on defs" do
    hook_handler = EvalHook::HookHandler.new

    hook_handler.evalhook("
      def set_foo(obj)
        def obj.foo(x)
          x.bar
          x.bar
        end
      end", binding)

    obj = Object.new
    set_foo(obj)

    xxz = XXZ.new
    xxz.should_receive(:bar).twice
    obj.foo(xxz)
  end

end