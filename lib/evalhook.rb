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


class Object
  def hooked_method(m)
    EvalHook::HookedMethod.new(self,m)
  end
end

module EvalHook
  class HookedMethod
    def initialize(recv, m)
      @recv = recv
      @m = m
    end
    def call(*args)
      @recv.send(@m, *args)
    end
  end

  class FakeEvalHook
    def self.hook_block
    end
  end

	module ModuleMethods

   def double_run
     yield(false)
     yield(true)
   end

   def evalhook(*args)


      args[0] = "
        EvalHook.double_run do |run|
          ( if (run)
            #{args[0]}
            EvalHook::FakeEvalHook
          else
            EvalHook
          end ).hook_block

        end
       "
      eval(*args)

   end
	end

  class << self
    include ModuleMethods
  end
end