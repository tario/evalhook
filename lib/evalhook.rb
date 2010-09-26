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
  def hooked_method(mname)
    EvalHook::HookedMethod.new(self,mname)
  end
end

module EvalHook

  class HookedMethod
    def initialize(recv, m)
      @recv = recv
      @m = m
    end
    def call(*args)
      method_handler = EvalHook.method_handler
      ret = nil

      if method_handler
      ret = method_handler.handle_method(@recv.method(@m).owner, @recv, @m )
      end

      if ret.instance_of? RedirectHelper::MethodRedirect
        if block_given?
          ret.klass.instance_method(ret.method_name).bind(ret.recv).call(*args) do |*x|
            yield(*x)
          end
        else
          ret.klass.instance_method(ret.method_name).bind(ret.recv).call(*args)
        end
      else
        if block_given?
          @recv.send(@m, *args) do |*x|
            yield(*x)
          end
        else
          @recv.send(@m, *args)
        end
      end
    end
  end

  class FakeEvalHook
    def self.hook_block
    end
  end

  class HookHandler
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
          end ).hook_block
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