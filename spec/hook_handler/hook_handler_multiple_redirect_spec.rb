require "rubygems"
require "evalhook"

describe EvalHook::MultiHookHandler, "multiple hook handler redirect" do

   class ::X
     def self.foo

     end
   end

   handles = [
    [:handle_method, "X.foo"],
    [:handle_cdecl, "TEST_CONSTANT = 4"],
    [:handle_gasgn, "$test_global_variable = 4"] ]

   handles.each do |handle|
    it "should recall #{handle[0]} in correct order" do
      hook_handler = EvalHook::MultiHookHandler.new

      nested_handler_1 = EvalHook::HookHandler.new
      nested_handler_2 = EvalHook::HookHandler.new
      hook_handler.add nested_handler_1
      hook_handler.add nested_handler_2

      nested_handler_1.should_receive(handle[0])
      nested_handler_2.should_receive(handle[0])

      hook_handler.evalhook(handle[1])
    end
  end

   class X_
     def foo
      nil
     end

     def bar
       nil
     end
   end


  it "should handle redirects on recall of handle_method" do
      hook_handler = EvalHook::MultiHookHandler.new

      nested_handler_1 = EvalHook::HookHandler.new
      nested_handler_2 = EvalHook::HookHandler.new
      hook_handler.add nested_handler_1
      hook_handler.add nested_handler_2

      x = X_.new

      def nested_handler_1.handle_method(klass, recv, m )
        RedirectHelper::Redirect.new(klass, recv, :bar)
      end

      nested_handler_2.should_receive(:handle_method).
                        with(X_, x, :bar).
                        and_return(nil)

      hook_handler.evalhook("x.foo", binding)


  end

end
