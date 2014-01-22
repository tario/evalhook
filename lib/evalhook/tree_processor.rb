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
require "partialruby"
require "sexp_processor"

module EvalHook
  class TreeProcessor < SexpProcessor
    def initialize(hook_handler)
      super()
      @hook_handler = hook_handler
      @def_scope = Array.new
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
      # create a global_variable name
      unless @hh_ref_global_name
        global_variable_name = "$hook_handler_" + rand(10000000000).to_s
        eval("#{global_variable_name} = @hook_handler")

        @hh_ref_global_name = global_variable_name.to_sym
      end

      s(:gvar, @hh_ref_global_name)
    end

    def process_gasgn(tree)

      args1 = s(:arglist, s(:lit, tree[1]), process(tree[2]))

      s(:call, hook_handler_reference, :hooked_gasgn, args1)
    end


    def process_call(tree)
      original_receiver = tree[1]

      receiver = if original_receiver
        s(:call, hook_handler_reference, :private_method_check, s(:arglist,process(original_receiver),s(:lit,tree[2])))
      else
        s(:self)
      end

      firstcall = nil
      if tree[1] == nil and (tree[3] == s(:arglist) or tree[3] == nil)
        firstcall = s(:call,
            hook_handler_reference,
            :hooked_variable_method,
            s(:arglist, receiver, s(:lit, tree[2]), s(:call, nil, :binding, s(:arglist)))
            )
      else
        firstcall = s(:call,
            hook_handler_reference,
            :hooked_method,
            s(:arglist, receiver, s(:lit, tree[2]))
            )
      end

      arglist = s(:arglist)
      if tree[3]
        if tree[3][0] == :arglist
          arglist = tree[3]
        else
          tree[3..-1].each do |st|
            arglist << st
          end
        end
      end

      s(:call, firstcall, :call, process(arglist) || s(:arglist))
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

          args1 = s(:arglist, base_class_tree, s(:lit, const_id), process(value_tree))

          s(:call, hook_handler_reference, :hooked_cdecl, args1 )
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

    def process_module(tree)
      module_name_tree = tree[1]
      if module_name_tree.instance_of? Sexp
        if module_name_tree.first == :colon3
          module_name_tree = process_colon3(module_name_tree)
        end
      end

      class_scope(nil) {
        module_tree = s(:module, module_name_tree)
        tree[2..-1].each do |subtree|
          module_tree << process(subtree)
        end
        module_tree
      }
    end

    def class_scope(class_name)
      @def_scope.push(class_name)
      ret = yield
      @def_scope.pop
      ret
    end

    def process_class(tree)
      class_name_tree = tree[1]
      if class_name_tree.instance_of? Sexp
        if class_name_tree.first == :colon3
          class_name_tree = process_colon3(class_name_tree)
        end
      end

      if tree[2]
        class_scope(tree[1]) do
          class_tree = s(:class, class_name_tree, process(tree[2]))
          tree[3..-1].map(&method(:process)).each(&class_tree.method(:<<))
          class_tree
        end
      else
        class_scope(tree[1]) do
          class_tree = s(:class, class_name_tree, nil)
          tree[3..-1].map(&method(:process)).each(&class_tree.method(:<<))
          class_tree
        end
      end
    end

    def process_colon2(tree)
      name = tree[2].to_s
      args = s(:arglist, process(tree[1]), s(:str, name))
      s(:call, hook_handler_reference, :hooked_colon2, args)
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
      args = s(:arglist, s(:str, name))
      s(:call, hook_handler_reference, :hooked_const, args)
    end

    def process_defn(tree)
      @last_args = tree[2]
      @last_method_name = tree[1]

      s(tree[0],tree[1],tree[2],*tree[3..-1].map(&method(:process)))
    end

    def superclass_call_tree
      current_class_call = nil

      def_class = @def_scope.last
      if def_class.instance_of? Symbol
        current_class_call = s(:const, def_class)
        s(:call, current_class_call, :superclass, s(:arglist))
      elsif def_class.instance_of? Sexp
        current_class_call = def_class
        s(:call, current_class_call, :superclass, s(:arglist))
      elsif def_class.instance_of? String
        s(:call, s(:self), :class, s(:arglist))
      else
        current_class_call = s(:call, nil, :raise, s(:arglist, s(:const, :SecurityError)))
        s(:call, current_class_call, :superclass, s(:arglist))
      end
    end

    def process_super(tree)

          receiver = s(:self)

          firstcall = s(:call, hook_handler_reference,
                :hooked_method,
                s(:arglist, receiver, s(:lit,@last_method_name), superclass_call_tree))

          # pass the args passed to super
          s(:call, firstcall, :call, process(s(:arglist, *tree[1..-1])))
    end

    def process_defs(tree)
      block_tree = class_scope( "" ) {
        s(:block, *tree[4..-1].map(&method(:process)))
      }
      s(:defs, process(tree[1]), tree[2], tree[3], block_tree)
    end

    def process_zsuper(tree)

          receiver = s(:self)

          firstcall = s(:call, hook_handler_reference,
                :hooked_method,
                s(:arglist, receiver, s(:lit,@last_method_name), superclass_call_tree))

          # pass the args of the current defn
          args = s(:arglist)
          @last_args[1..-1].each do |arg_sym|
            if arg_sym.to_s[0] == "*"
              args << s(:splat, s(:lvar, arg_sym.to_s[1..-1].to_sym))
            else
              args << s(:lvar, arg_sym)
            end
          end

          s(:call, firstcall, :call, args)
    end

end
end
