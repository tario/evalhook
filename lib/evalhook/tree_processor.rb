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
require "sexp_processor"

module EvalHook


  class TreeProcessor < SexpProcessor
    def initialize(hook_handler)
      super()
      @hook_handler = hook_handler
    end

    def const_path_emul(code)
      if code.instance_of? Array
        if (code.size == 1)
          s(:const, code[-1].to_sym)
        else
          s(:colon2, const_path_emul(code[0..-2]), code[-1].to_sym)
        end
      else
        const_path_emul code.split("::")
      end
    end

    def hook_handler_reference
      s(:call, s(:const, :ObjectSpace), :_id2ref, s(:arglist, s(:lit, @hook_handler.object_id)))
    end

    def process_gasgn(tree)

      tree.shift

      args1 = s(:arglist, s(:lit, tree.shift))
      args2 = s(:arglist, process(tree.shift))

      firstcall = s(:call, hook_handler_reference, :hooked_gasgn, args1)

      s(:call, firstcall, :set_value, args2)

    end


    def process_call(tree)

          tree.shift
          original_receiver = tree.shift

          receiver = process(original_receiver|| s(:self))

          args1 = s(:arglist, s(:lit, tree.shift), s(:call, nil, :binding, s(:arglist)))
          args2 = s(:arglist, hook_handler_reference)

          firstcall = nil
          secondcall = nil

          if original_receiver
            firstcall = s(:call, receiver, :local_hooked_method, args1)
            secondcall = s(:call, firstcall, :set_hook_handler, args2)
          else
            firstcall = s(:call, receiver, :hooked_method, args1)
            secondcall = s(:call, firstcall, :set_hook_handler, args2)
          end

          s(:call, secondcall, :call, process(tree.shift))
    end

    def process_cdecl(tree)

        tree.shift

          const_tree = tree.shift
          value_tree = tree.shift

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
          args3 = s(:arglist, process(value_tree))

          firstcall = s(:call, hook_handler_reference, :hooked_cdecl, args1 )
          secondcall = s(:call, firstcall, :set_id, args2)

          s(:call, secondcall, :set_value, args3)
    end

    def process_dxstr(tree)
       dstr_tree = tree.dup
       dstr_tree[0] = :dstr

       while not tree.empty?
       tree.shift
       end

       args = s(:arglist, process(dstr_tree) )

       s(:call, hook_handler_reference, :hooked_xstr, args)
    end

    def process_xstr(tree)
      tree.shift
      args = s(:arglist, s(:lit, tree.shift) )
      s(:call, hook_handler_reference, :hooked_xstr, args)
    end

    def process_colon3(tree)
      if @hook_handler.base_namespace
        tree.shift
        s(:colon2, const_path_emul(@hook_handler.base_namespace.to_s), tree.shift)
      else
        ret = s(:colon3, tree[1])

        tree.shift
        tree.shift

        ret

      end
    end
  end
end
