require "rubygems"
require "evalhook"

class Hook < EvalHook::HookHandler
	# global variable assignment/creation
	def handle_gasgn( global_name, new_value)
		print "assignment of #{global_name} = #{new_value}\n"
		nil
	end

	# constant assignment/creation
	def handle_cdecl( container, const_name, new_value)
		print "assignment of #{container}::#{const_name} = #{new_value}\n"
		nil
	end
end

h = Hook.new
h.evalhook('
$a = 4
A = 4', binding)
