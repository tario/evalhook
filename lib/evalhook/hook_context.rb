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

module EvalHook
  class HookContext < PartialRuby::PureRubyContext

    def initialize(hook_handler)
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

    def ruby_emul_colon3(tree)
      if @hook_handler.base_namespace
        emul s(:colon2, const_path_emul(@hook_handler.base_namespace.to_s), tree[1])
      else
        super tree
      end
    end

    def ruby_emul_call(tree)

      method_name = tree[2]

      if (method_name == :local_hooked_method or
         method_name == :hooked_method or
         method_name == :set_hook_handler or
         method_name == :binding
         )

         return super tree
      end

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

      super s(:call, secondcall, :call, tree[3])
    end

    def ruby_emul_dxstr(tree)

      dstr_tree = tree.dup
      dstr_tree[0] = :dstr

      args = s(:arglist, dstr_tree )

      emul s(:call, s(:lit, @hook_handler), :hooked_xstr, args)
    end

    def ruby_emul_xstr(tree)
      args = s(:arglist, s(:lit, tree[1]) )

      emul s(:call, s(:lit, @hook_handler), :hooked_xstr, args)
    end

    def ruby_emul_cdecl(tree)
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
      thirdcall = s(:call, secondcall, :set_value, args3)

      emul thirdcall
    end

    def ruby_emul_gasgn(tree)
      args1 = s(:arglist, s(:lit, tree[1]))
      args2 = s(:arglist, tree[2] )

      firstcall = s(:call, s(:lit, @hook_handler), :hooked_gasgn, args1 )
      secondcall = s(:call, firstcall, :set_value, args2)
      emul secondcall
    end
  end
end
