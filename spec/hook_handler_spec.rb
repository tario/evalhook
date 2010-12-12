require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler" do
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

end

