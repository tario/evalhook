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
require "partialruby"
require "evalhook/ast_extension"

module EvalHook
  class TreeProcessor

    def initialize(hook_handler)
      @hook_handler = hook_handler
    end

    def process(tree)

      tree.map_nodes do |tree|
        nodetype = tree.first

        if nodetype == :gasgn
          args1 = s(:arglist, s(:lit, tree[1]))
          args2 = s(:arglist, tree[2] )

          firstcall = s(:call, s(:lit, @hook_handler), :hooked_gasgn, args1)

          s(:call, firstcall, :set_value, args2)
        elsif nodetype == :call

          method_name = tree[2]

          args1 = s(:arglist, s(:lit, method_name), s(:call, nil, :binding, s(:arglist)))
          args2 = s(:arglist, s(:lit, @hook_handler))

          receiver = tree[1] || s(:self)

          firstcall = nil
          secondcall = nil

          if tree[1]
            firstcall = s(:call, receiver, :local_hooked_method, args1)
            secondcall = s(:call, firstcall, :set_hook_handler, args2)
          else
            firstcall = s(:call, receiver, :hooked_method, args1)
            secondcall = s(:call, firstcall, :set_hook_handler, args2)
          end

          s(:call, secondcall, :call, tree[3])

        elsif nodetype == :cdecl

          const_tree = tree[1]
          value_tree = tree[2]

          base_class_tree = nil
          const_id = nil

          unless const_tree.instance_of? Symbol
            if const_tree[0] == :colon2
              base_class_tree = const_tree[1]
              const_id = const_tree[2]
            elsif const_tree[0] == :colon3
              base_class_tree = s(:lit, Object)
              const_id = const_tree[1]
            end
          else
            base_class_tree = s(:lit, Object)
            const_id = const_tree
          end

          args1 = s(:arglist, base_class_tree)
          args2 = s(:arglist, s(:lit, const_id))
          args3 = s(:arglist, value_tree)

          firstcall = s(:call, s(:lit, @hook_handler), :hooked_cdecl, args1 )
          secondcall = s(:call, firstcall, :set_id, args2)

          s(:call, secondcall, :set_value, args3)

        else
          tree
        end
      end


    end
  end
end
