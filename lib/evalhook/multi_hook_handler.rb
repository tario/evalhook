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
module EvalHook

class HookHandler

end

class MultiHookHandler < HookHandler
  def initialize
    @nested_hook_handlers = Array.new
  end

  # Add a nested hook handler to the hook handler chain (see examples)
  def add(nested_hh)
    @nested_hook_handlers << nested_hh
  end

  def handle_method(klass, recv, method_id)
    lastret = nil

    @nested_hook_handlers.each do |hh|
      currret = hh.handle_method(klass, recv, method_id)

      lastret = currret || lastret

      if (currret)
        klass = currret.klass
        recv = currret.recv
        method_id = currret.method_name
      end
    end

    lastret
  end

  def handle_cdecl(*args)
    lastret = nil

    @nested_hook_handlers.each do |hh|
      currret = hh.handle_cdecl(*args)
      lastret = currret || lastret
    end

    lastret
  end

  def handle_gasgn(*args)

    lastret = nil

    @nested_hook_handlers.each do |hh|
      currret = hh.handle_gasgn(*args)
      lastret = currret || lastret
    end

    lastret
  end

  def handle_xstr(str)

    lastret = nil

    @nested_hook_handlers.each do |hh|
      lastret = hh.handle_xstr(str)
      str = lastret || str
    end

    lastret
  end

end

end
