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
module RedirectHelper
  module MethodRedirect
  end

#
#Internal class used for return method redirection messages
#Example:
# ...
# class X
#   def foo
#   end
# end
# def handle_method
#   return RedirectHelper::Redirect.new(X, X.new, :foo)
# end

  class Redirect
    include MethodRedirect

    attr_reader :klass
    attr_reader :recv

    def method_name
      @method
    end

    def initialize(klass, recv, m, unhook = nil)
      @klass = klass
      @recv = recv
      @method = m
    end
  end

end