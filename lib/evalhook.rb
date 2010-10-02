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


class Object
  def local_hooked_method(mname)
    EvalHook::HookedMethod.new(self,mname,true)
  end
  def hooked_method(mname)
    EvalHook::HookedMethod.new(self,mname,false)
  end
end

module EvalHook

  class HookedMethod
    def initialize(recv, m,localcall)
      @recv = recv
      @m = m
      @localcall = localcall
    end

    def set_hook_handler(method_handler)
      @method_handler = method_handler
      self
    end

    def set_class(klass)
      @klass = klass
      self
    end

    def call(*args)
      method_handler = @method_handler
      ret = nil

      klass = @klass || @recv.method(@m).owner
      method_name = @m
      recv = @recv

      if method_handler
      ret = method_handler.handle_method(klass, recv, method_name )
      end

      if ret.instance_of? RedirectHelper::MethodRedirect
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

  class FakeEvalHook
    def self.hook_block(*args)
    end
  end

  class HookHandler

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

    def evalhook(*args)

      EvalHook.method_handler = self

      args[0] = "
        retvalue = nil
        EvalHook.double_run do |run|
          ( if (run)
            retvalue = begin
              #{args[0]}
            end
            EvalHook::FakeEvalHook
          else
            EvalHook
          end ).hook_block(ObjectSpace._id2ref(#{object_id}))
        end
        retvalue
       "
      eval(*args)

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