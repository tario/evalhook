require "rubygems"
require "evalhook"

include EvalHook

class Hook1 < HookHandler
	def handle_method(klass,recv,method_name)
		
		if method_name == :foo
			redirect_method(klass,recv,:bar)
		else
			nil
		end
	end
end

class Hook2 < HookHandler
	def handle_method(klass,recv,method_name)

		if method_name == :bar
			redirect_method(klass,recv,:test1)
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
	
	def test1
		print "test1\n"
	end
end


x = X.new
x.foo # foo

mmh = MultiHookHandler.new
mmh.add( Hook1.new )	# :foo => :bar
mmh.add( Hook2.new )   # :bar => :test1

mmh.evalhook("x.foo") # test1
mmh.evalhook("x.bar") # test1



