require "rubygems"
require "evalhook"

class Hook < EvalHook::HookHandler
	
	include RedirectHelper
	
	def handle_method(klass, recv, method_name)
		print "called #{klass}##{method_name} over #{recv}\n"
		
		if method_name == :print
			# change the method_name to alternative_print
			redirect_method(klass, recv, "alternative_print")
		else
			nil # do nothing
		end
		
	end
end

module Kernel
	def alternative_print(*args)
		print "alternative ", *args
	end
end

h = Hook.new
h.evalhook('print "hello world\n"')
