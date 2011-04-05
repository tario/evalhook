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

module EvalHook
  def self.sexp_map_nodes(sexp)

    ret_tree = sexp.dup

    (0..sexp.count-1).each do |i|
      subtree = ret_tree[i]

      if subtree.instance_of? Sexp
        replace_subtree = yield(subtree.dup)

         if replace_subtree != subtree then
           ret_tree[i] = replace_subtree
         else
           ret_tree[i] = EvalHook.sexp_map_nodes(subtree) do |*x| yield(*x) end
         end
      end

    end

    ret_tree


  end
end

class Sexp
  def map_nodes
    if block_given?

      replaced_tree = yield(self.dup)
      if replaced_tree == self

        EvalHook.sexp_map_nodes(replaced_tree) do |*x|
          yield(*x)
        end
      else
        replaced_tree
      end
    else
      self.dup
    end
  end
end
