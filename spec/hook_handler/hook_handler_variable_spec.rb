require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler visitor" do
  it "block paramters should not shadow method names" do
    ctx = EvalHook::HookHandler.new
    ctx.evalhook("(1..3).map{|to_s| 'a'.to_s}").should be == eval("(1..3).map{|to_s| 'a'.to_s}")
  end
end
 