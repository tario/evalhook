=begin

This file is part of the evalhook project, http://github.com/tario/evalhook

Copyright (c) 2010 Roberto Dario Seminara <robertodarioseminara@gmail.com>

evalhook is free software: you can redistribute it and/or modify
it under the terms of the gnu general public license as published by
the free software foundation, either version 3 of the license, or
(at your option) any later version.

evalhook is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.  see the
gnu general public license for more details.

you should have received a copy of the gnu general public license
along with evalhook.  if not, see <http://www.gnu.org/licenses/>.

=end
require "partialruby"
require "evalhook/redirect_helper"
require "evalhook/multi_hook_handler"
require "evalhook/hook_handler"
require "evalhook/tree_processor"

begin
require "evalmimic"
$evalmimic_defined = true
rescue LoadError
$evalmimic_defined = false
end


class Object
  def _local_hooked_method(mname,_binding)
    EvalHook::HookedMethod.new(self,mname,_binding)
  end
  def _hooked_method(mname,_binding)
    EvalHook::HookedMethod.new(self,mname,_binding)
  end
end

module EvalHook

  # used internally
  class HookedMethod

    def initialize(recv, m,_binding, method_handler = nil)
      @recv = recv
      @m = m
      @_binding = _binding
      @method_handler = method_handler
    end

    # used internally
    def set_hook_handler(method_handler)
      @method_handler = method_handler
      self
    end

    # used internally
    def set_class(klass)
      @klass = klass
      self
    end

    # used internally
    def call(*args)
      method_handler = @method_handler
      ret = nil

      method_name = @m
      if args.length == 0
        local_vars = @_binding.eval("local_variables").map(&:to_s)
        if local_vars.include? method_name.to_s
          return @_binding.eval(method_name.to_s)
        end
      end

      klass = @klass || @recv.method(@m).owner
      recv = @recv

      if method_handler
      ret = method_handler.handle_method(klass, recv, method_name )
      end

      if ret.kind_of? RedirectHelper::MethodRedirect
        klass = ret.klass
        method_name = ret.method_name
        recv = ret.recv
      end

      method_object = nil

      begin
        method_object = klass.instance_method(method_name).bind(recv)
      rescue
        method_object = recv.method(method_name)
      end

      if block_given?
        method_object.call(*args) do |*x|
          yield(*x)
        end
      else
        method_object.call(*args)
      end
    end
  end

  # used internally
  class FakeEvalHook
    def self.hook_block(*args)
    end
  end

  class HookHandler

    include RedirectHelper

    attr_accessor :base_namespace

    def initialize
      super
      self.base_namespace = Object
    end

    def base_namespace=( obj )
      if obj.instance_of? Symbol
        @base_namespace = obj
      else
        @base_namespace = obj.to_s.to_sym
      end
    end

    # used internally
    def hooked_gvar(global_id)
      ret = handle_gvar(global_id)
      if ret
        ret.value
      else
        eval(global_id.to_s)
      end
    end

    # used internally
    def hooked_const(name)
      ret = handle_const(name)
      if ret
        ret.value
      else
         Object.const_get(name)
       end
    end

    # used internally
    def hooked_colon2(context,name)
      ret = handle_colon2(context, name)
      if ret
        ret.value
      else
         context.const_get(name)
      end
    end

    # used internally
    def hooked_cdecl(klass, const_id, value)
      ret = handle_cdecl( klass, const_id, value )

      if ret then
        klass = ret.klass
        const_id = ret.const_id
        value = ret.value
      end

      klass.const_set(const_id, value)
    end

    # used internally
    def hooked_gasgn(global_id, value)
      ret = handle_gasgn(global_id, value)

      if ret then
        global_id = ret.global_id
        value = ret.value
      end
      eval("#{global_id} = value")
    end

    def hooked_method(receiver, mname, _binding)
      EvalHook::HookedMethod.new(receiver,mname,_binding,self)
    end

    def local_hooked_method(receiver, mname, _binding)
      EvalHook::HookedMethod.new(receiver,mname,_binding,self)
    end

    # Overwrite to handle the assignment/creation of global variables. By default do nothing but assign the variable. See examples
    def handle_gasgn(*args)
      nil
    end

    # Overwrite to handle the assignment/creation of constants. By default do nothing but assign the variable. See examples
    def handle_cdecl(*args)
      nil
    end

    # Overwrite to handle the evaluation o colon3 nodes (access to global namespace)
    def handle_colon3(*args)
      nil
    end

    # Overwrite to handle the evaluation o xstr nodes (execution of shell commands)
    def handle_xstr(*args)
      nil
    end

    # Overwrite to handle the method calls. By default do nothing and the methods are called normally
    def handle_method(klass,recv,method_name)
      nil
    end

    # Overwrite to handle const read access
    def handle_const(name)
      nil
    end

    def handle_colon2(context,name)
      nil
    end

    # Overwrite to handle global variable read access
    def handle_gvar(global_id)
      nil
    end

    # used internally
    def hooked_super(*args)
      hm = caller_obj(2).hooked_method(caller_method(2))
      hm.set_class(caller_class(2).superclass)
      hm.set_hook_handler(self)

      if block_given?
        hm.call(*args) do |*x|
          yield(*x)
        end
      else
        hm.call(*args)
      end
    end

    # used internally
    def hooked_xstr(str)
      runstr = handle_xstr(str) || str
    end

    def evalhook_i(code, b_ = nil, name = "(eval)", line = 1)

      EvalHook.validate_syntax code

      tree = RubyParser.new.parse code

      context = PartialRuby::PureRubyContext.new

      tree = EvalHook::TreeProcessor.new(self).process(tree)

      emulationcode = context.emul tree

      eval emulationcode, b_, name, line

    end

    if ($evalmimic_defined)

      define_eval_method :evalhook

      # used internally
      def internal_eval(b_, original_args)
        raise ArgumentError if original_args.size == 0
        evalhook_i(original_args[0], original_args[1] || b_, original_args[2] || "(eval)", original_args[3] || 0)
      end

    else
      def evalhook(*args)
        evalhook_i(*args)
      end
    end

  end

	module ModuleMethods

   attr_accessor :method_handler

   def double_run
     yield(false)
     yield(true)
   end
	end

  class << self
    include ModuleMethods
  end
end