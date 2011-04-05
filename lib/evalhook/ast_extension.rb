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
require "ruby_parser"

class Sexp
  def map_ast_nodes

    ret_tree = self.dup
    (0..self.count-1).each do |i|
      subtree = ret_tree[i]

      if subtree.instance_of? Sexp
        replace_subtree = yield(subtree)

        if replace_subtree != subtree then
          ret_tree[i] = replace_subtree
        else
          subtree.map_nodes do |*x| yield(*x) end
        end
      end

    end

    ret_tree

  end
end
