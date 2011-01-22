require "rubygems"
require "evalhook"

include EvalHook

class DenyFooFilter < HookHandler
	def handle_method(klass,recv,method_name)
	
		if method_name == :foo
			raise SecurityError
		else
			nil
		end
	end
end

class RedirectFooToBar < HookHandler
	def handle_method(klass,recv,method_name)

		if method_name == :foo
			redirect_method(klass,recv,:bar)
		else
			nil
		end
	end
end

class X
	def foo
		print "foo\n"
	end
	
	def bar
		print "bar\n"
	end
end


x = X.new
x.foo # foo

mmh = MultiHookHandler.new
mmh.add( DenyFooFilter.new )	
mmh.add( RedirectFooToBar.new )

begin
mmh.evalhook("x.foo")
rescue SecurityError
print "foo method filtered by a SecurityError exception\n"
end


mmh = MultiHookHandler.new
mmh.add( RedirectFooToBar.new )
mmh.add( DenyFooFilter.new )	

mmh.evalhook("x.foo")
