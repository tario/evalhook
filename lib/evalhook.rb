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
require "evalhook"
require "evalhook_base"
require "evalhook/redirect_helper"
require "evalhook/multi_hook_handler"


class Object
  def local_hooked_method(mname)
    EvalHook::HookedMethod.new(self,mname,true)
  end
  def hooked_method(mname)
    EvalHook::HookedMethod.new(self,mname,false)
  end
end

module EvalHook

  # used internally
  class HookedMethod

    def initialize(recv, m,localcall)
      @recv = recv
      @m = m
      @localcall = localcall
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

      klass = @klass || @recv.method(@m).owner
      method_name = @m
      recv = @recv

      if method_handler
      ret = method_handler.handle_method(klass, recv, method_name )
      end

      if ret.kind_of? RedirectHelper::MethodRedirect
        klass = ret.klass
        method_name = ret.method_name
        recv = ret.recv
      end

      if block_given?
        klass.instance_method(method_name).bind(recv).call(*args) do |*x|
          yield(*x)
        end
      else
        klass.instance_method(method_name).bind(recv).call(*args)
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

    # used internally
    class HookCdecl
      def initialize(klass, hook_handler)
        @klass = klass
        @hook_handler = hook_handler
      end

      def set_id(const_id)
        @const_id = const_id
        self
      end

      def set_value(value)
        klass = @klass
        const_id = @const_id

        ret = @hook_handler.handle_cdecl( @klass, @const_id, value )

        if ret then
          klass = ret.klass
          const_id = ret.const_id
          value = ret.value
        end

        klass.const_set(const_id, value)
      end
    end

    # used internally
    class HookGasgn
      def initialize(global_id, hook_handler)
        @global_id = global_id
        @hook_handler = hook_handler
      end

      def set_value(value)
        global_id = @global_id

        ret = @hook_handler.handle_gasgn(@global_id, value)

        if ret then
          global_id = ret.global_id
          value = ret.value
        end

        eval("#{global_id} = value")
      end
    end

    # used internally
    def hooked_cdecl(context)
      HookCdecl.new(context,self)
    end

    # used internally
    def hooked_gasgn(global_id)
      HookGasgn.new(global_id,self)
    end

    # Overwrite to handle the assignment/creation of global variables. By default do nothing but assign the variable. See examples
    def handle_gasgn(*args)
      nil
    end

    # Overwrite to handle the assignment/creation of constants. By default do nothing but assign the variable. See examples
    def handle_cdecl(*args)
      nil
    end

    def handle_xstr(*args)
      nil
    end

    # Overwrite to handle the method calls. By default do nothing and the methods are called normally
    def handle_method(klass,recv,method_name)
      nil
    end

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

    def hooked_xstr(str)
      runstr = handle_xstr(str) || str
    end

    def evalhook_i(code, b_ = nil, name = "(eval)", line = 1)

      EvalHook.validate_syntax code

      code = "
        retvalue = nil
        EvalHook.double_run do |run|
          ( if (run)
            retvalue = begin
              #{code}
            end
            EvalHook::FakeEvalHook
          else
            EvalHook
          end ).hook_block(ObjectSpace._id2ref(#{object_id}))
        end
        retvalue
       "
      eval(code, b_, name, line)

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