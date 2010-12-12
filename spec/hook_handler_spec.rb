require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler" do
     it "should throw exception when call evalhook with no parameters" do
		hook_handler = EvalHook::HookHandler.new



		lambda {
			hook_handler.evalhook
		}.should raise_error(ArgumentError)
     end
end

