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
require "sexp_processor"

module EvalHook


  class TreeProcessor < SexpProcessor
    def initialize(hook_handler)
      super()
      @hook_handler = hook_handler
      self.require_empty = false
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

      args1 = s(:arglist, s(:lit, tree[1]))
      args2 = s(:arglist, process(tree[2]))

      firstcall = s(:call, hook_handler_reference, :hooked_gasgn, args1)

      s(:call, firstcall, :set_value, args2)

    end


    def process_call(tree)

          original_receiver = tree[1]

          receiver = process(original_receiver|| s(:self))

          args1 = s(:arglist, s(:lit, tree[2]), s(:call, nil, :binding, s(:arglist)))
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

          s(:call, secondcall, :call, process(tree[3]))
    end

    def process_cdecl(tree)

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
          args3 = s(:arglist, process(value_tree))

          firstcall = s(:call, hook_handler_reference, :hooked_cdecl, args1 )
          secondcall = s(:call, firstcall, :set_id, args2)

          s(:call, secondcall, :set_value, args3)
    end

    def process_dxstr(tree)
       dstr_tree = tree.dup
       dstr_tree[0] = :dstr

       args = s(:arglist, process(dstr_tree) )
       s(:call, hook_handler_reference, :hooked_xstr, args)
    end

    def process_xstr(tree)
      args = s(:arglist, s(:lit, tree[1]) )
      s(:call, hook_handler_reference, :hooked_xstr, args)
    end

    def process_colon2(tree)
      name = tree[2].to_s
      args = s(:arglist, process(tree[1]), s(:str, name))
      s(:call, hook_handler_reference, :hooked_const, args)
    end

    def process_colon3(tree)
      if @hook_handler.base_namespace
        s(:colon2, const_path_emul(@hook_handler.base_namespace.to_s), tree[1])
      else
        s(:colon3, tree[1])
      end
    end

    def process_gvar(tree)
      name = tree[1]

      args = s(:arglist, s(:lit, name))
      s(:call, hook_handler_reference, :hooked_gvar, args)
    end

    def process_const(tree)
      name = tree[1].to_s
      args = s(:arglist, s(:const, :Object), s(:str, name))
      s(:call, hook_handler_reference, :hooked_const, args)
    end
  end
end
