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
require "evalhook/tree_processor"

begin
require "evalmimic"
$evalmimic_defined = true
rescue LoadError
$evalmimic_defined = false
end

module EvalHook

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

    def partialruby_context
      unless @partialruby_context
        @partialruby_context = PartialRuby::Context.new
        @partialruby_context.pre_process do |tree|
          EvalHook::TreeProcessor.new(self).process(tree)
        end
      end
      @partialruby_context
    end

    def base_namespace=( obj )
      if obj.instance_of? Symbol
        @base_namespace = obj
      else
        @base_namespace = obj.to_s.to_sym
      end
    end

    def hooked_gvar(global_id) #:nodoc:
      ret = handle_gvar(global_id)
      if ret
        ret.value
      else
        eval(global_id.to_s)
      end
    end

    def hooked_const(name) #:nodoc:
      ret = handle_const(name)
      if ret
        ret.value
      else
         Object.const_get(name)
       end
    end

    def hooked_colon2(context,name) #:nodoc:
      ret = handle_colon2(context, name)
      if ret
        ret.value
      else
         context.const_get(name)
      end
    end

    def hooked_cdecl(klass, const_id, value) #:nodoc:
      ret = handle_cdecl( klass, const_id, value )

      if ret then
        klass = ret.klass
        const_id = ret.const_id
        value = ret.value
      end

      klass.const_set(const_id, value)
    end

    def hooked_gasgn(global_id, value) #:nodoc:
      ret = handle_gasgn(global_id, value)

      if ret then
        global_id = ret.global_id
        value = ret.value
      end
      eval("#{global_id} = value")
    end

    class HookedCallValue
      def initialize(value)
        @value = value
      end
      def call(*args)
        @value
      end
    end

    def hooked_method(receiver, mname, klass = nil) #:nodoc:
      m = nil
      is_method_missing = false

      unless klass
        m = begin
          receiver.method(mname)
        rescue
          is_method_missing = true
          receiver.public_method(:method_missing)
        end
        klass = m.owner
      else
        m = klass.instance_method(mname).bind(receiver)
      end

      ret = handle_method(klass, receiver, mname )

      if ret.kind_of? RedirectHelper::MethodRedirect
        klass = ret.klass
        mname = ret.method_name
        receiver = ret.recv

        begin
          m = ret.klass.instance_method(ret.method_name).bind(ret.recv)
        rescue
          m = ret.recv.method(ret.method_name)
        end
      end

      if is_method_missing
        orig_m = m
        m = lambda{|*x| orig_m.call(mname,*x) }
      end
      m
    end

    def hooked_variable_method(receiver, mname, _binding) #:nodoc:
      local_vars = _binding.eval("local_variables").map(&:to_s)
      if local_vars.include? mname.to_s
        HookedCallValue.new( _binding.eval(mname.to_s) )
      else
        is_method_missing = false
        m = begin 
          receiver.method(mname)
        rescue
          is_method_missing = true
          receiver.method(:method_missing)
        end

        klass = m.owner
        ret = handle_method(klass, receiver, mname )

        if ret.kind_of? RedirectHelper::MethodRedirect
          klass = ret.klass
          mname = ret.method_name
          receiver = ret.recv

          begin
            m = ret.klass.instance_method(ret.method_name).bind(ret.recv)
          rescue
            m = ret.recv.method(ret.method_name)
          end
        end

        if is_method_missing
          orig_m = m
          m = lambda{|*x| orig_m.call(mname,*x) }
        end
        m
      end
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

    def hooked_xstr(str) #:nodoc:
      runstr = handle_xstr(str) || str
    end

    def evalhook_i(code, b_ = nil, name = "(eval)", line = 1)
      packet(code).run(b_,name,line)
    end

    # Creates a packet of preprocessed ruby code to run it later
    # , useful to execute the same code repeatedly and avoid heavy
    # preprocessing of ruby code all the times.
    #
    # See EvalHook::Packet for more information
    #
    # Example:
    #
    #   hook_handler = HookHandler.new
    #
    #   pack = hook_handler.packet('print "hello world\n"')
    #   10.times do
    #     pack.run
    #   end
    def packet(code)
      partialruby_context.packet(code)
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

    def private_method_check(recv, mname)
      begin
        recv.public_method(mname) 
      rescue NameError 
        begin
          recv.public_method(:method_missing) 
        rescue NameError
          raise NoMethodError
        end
      end
      recv
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
