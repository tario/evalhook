require "rubygems"
require "evalhook"

class Hook < EvalHook::HookHandler
	def handle_method(klass, recv, method_name)
		print "called #{klass}##{method_name} over #{recv}\n"
		nil
	end
end

h = Hook.new
h.evalhook('print "hello world\n"')
