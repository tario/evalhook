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

end