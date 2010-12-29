/*

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

*/

#include <ruby.h>
#include <env.h>
#include <node.h>

VALUE m_EvalHook ;
VALUE c_HookHandler;

#define nd_3rd   u3.node

ID method_call;
ID method_hooked_method;
ID method_local_hooked_method;
ID method_private_hooked_method;
ID method_public_hooked_method;
ID method_protected_hooked_method;
ID method_public, method_private, method_protected;

ID method_set_hook_handler;

struct BLOCK {
    NODE *var;
    NODE *body;
    VALUE self;
    struct FRAME frame;
    struct SCOPE *scope;
    VALUE klass;
    NODE *cref;
    int iter;
    int vmode;
    int flags;
    int uniq;
    struct RVarmap *dyna_vars;
    VALUE orig_thread;
    VALUE wrapper;
    VALUE block_obj;
    struct BLOCK *outer;
    struct BLOCK *prev;
};

struct METHOD {
    VALUE klass, rklass;
    VALUE recv;
    ID id, oid;
    int safe_level;
    NODE *body;
};


void process_node(NODE* node, VALUE handler);

void patch_local_call_node(NODE* node, VALUE handler) {
	NODE* args1 = NEW_LIST(NEW_LIT(ID2SYM(node->nd_mid)));
	NODE* args2 = NEW_LIST(NEW_LIT(handler));

	node->nd_recv = NEW_CALL(NEW_SELF(), method_local_hooked_method, args1);
	node->nd_recv = NEW_CALL(node->nd_recv, method_set_hook_handler, args2);
	node->nd_mid = method_call;

	nd_set_type(node, NODE_CALL);
}

void patch_call_node(NODE* node, VALUE handler) {
	NODE* args1 = NEW_LIST(NEW_LIT(ID2SYM(node->nd_mid)));
	NODE* args2 = NEW_LIST(NEW_LIT(handler));

	node->nd_recv = NEW_CALL(node->nd_recv, method_hooked_method, args1);
	node->nd_recv = NEW_CALL(node->nd_recv, method_set_hook_handler, args2);

	node->nd_mid = method_call;
}

struct global_entry {
    struct global_variable *var;
    ID id;
};

void process_individual_node(NODE* node, VALUE handler) {
	ID id = node->nd_mid;

	switch (nd_type(node)) {
		case NODE_XSTR:{

			NODE* args1 = NEW_LIST(NEW_LIT(node->nd_lit));
			node->nd_recv = NEW_LIT(handler);
			node->nd_mid = rb_intern("handle_xstr");
			node->nd_args = args1;

			nd_set_type(node, NODE_CALL);
			break;
		}
		case NODE_DXSTR:{
			rb_raise(rb_eSecurityError, "Forbidden node type xstr (system call execution)");
		}
		case NODE_COLON3: {

			NODE* args1 = NEW_LIST(NEW_LIT(ID2SYM(node->u2.id)));

			node->nd_recv = NEW_LIT(handler);
			node->nd_mid = rb_intern("handle_colon3");
			node->nd_args = args1;

			nd_set_type(node, NODE_CALL);
			break;
		}
/*		case NODE_LASGN:
		case NODE_IASGN:
		case NODE_DASGN:
		case NODE_CVASGN:
		case NODE_CVDECL:*/
		case NODE_GASGN: {

				NODE* args1;
				NODE* args2 = NEW_LIST(node->nd_value);

				if (node->nd_entry != 0) {
					args1 = NEW_LIST(NEW_LIT(ID2SYM(node->nd_entry->id)));
				} else {
					args1 = NEW_LIST(NEW_LIT(ID2SYM(rb_intern("unknown_global"))));
				}

				node->nd_recv = NEW_CALL(NEW_LIT(handler), rb_intern("hooked_gasgn"), args1);
				node->nd_mid = rb_intern("set_value");
				node->nd_args = args2;

				nd_set_type(node, NODE_CALL);
			break;
		}
		case NODE_CDECL: {

			NODE* else_node = node->nd_else;
			NODE* head_node = node->nd_head;
			NODE* base_class;

			ID vid;

			if (node->nd_vid == 0) {
				base_class = else_node;
				vid = node->nd_else->nd_mid;
			} else {
				base_class = NEW_LIT( (ruby_cref->nd_clss));
				vid = node->nd_vid;
			}


			NODE* args1 = NEW_LIST(base_class);
			NODE* args2 = NEW_LIST(NEW_LIT(ID2SYM(vid)));
			NODE* args3 = NEW_LIST(node->nd_value);

			node->nd_recv = NEW_CALL(NEW_LIT(handler), rb_intern("hooked_cdecl"), args1);
			node->nd_recv = NEW_CALL(node->nd_recv, rb_intern("set_id"), args2);
			node->nd_mid = rb_intern("set_value");
			node->nd_args = args3;

			nd_set_type(node, NODE_CALL);
			break;
		}


		case NODE_SUPER:
		case NODE_ZSUPER: {
			node->nd_mid = rb_intern("hooked_super");
			node->nd_recv = NEW_LIT(handler);
			nd_set_type(node, NODE_CALL);
			break;
		}
		case NODE_FCALL: {
			if (id == method_public) break;
			if (id == method_private) break;
			if (id == method_protected) break;

			patch_local_call_node(node, handler);
			break;
		}

		case NODE_CALL: {
			patch_call_node(node, handler);
			break;

		}
		case NODE_VCALL: {
			if (id == method_public) break;
			if (id == method_private) break;
			if (id == method_protected) break;

			patch_local_call_node(node, handler);

			break;
		}
	}
}

void process_recursive_node(NODE* node, VALUE handler ) {

  switch (nd_type(node)) {

    case NODE_BLOCK:
      {
        while (node) {
          process_node(node->nd_head, handler);
          node = node->nd_next;
        }
      }
      break;

    case NODE_FBODY:
    case NODE_DEFINED:
    case NODE_COLON2:
      process_node(node->nd_head, handler);
      break;

    case NODE_MATCH2:
    case NODE_MATCH3:
      process_node(node->nd_recv, handler);
      process_node(node->nd_value, handler);
      break;

    case NODE_BEGIN:
    case NODE_OPT_N:
    case NODE_NOT:
      process_node(node->nd_body, handler);
      break;

    case NODE_IF:
      process_node(node->nd_cond, handler);
      if (node->nd_body) {
	      process_node(node->nd_body, handler);
      }
      if (node->nd_else) {
	      process_node(node->nd_else, handler);
      }
      break;

  case NODE_CASE:
    if (node->nd_head != NULL) {
      process_node(node->nd_head, handler);
    }
    node = node->nd_body;
    while (node) {
      process_node(node, handler);
      if (nd_type(node) == NODE_WHEN) {                 /* when */
        node = node->nd_next;
      } else {
        break;                                          /* else */
      }
    }
    break;

  case NODE_WHEN:
    process_node(node->nd_head, handler);
    if (node->nd_body) {
      process_node(node->nd_body, handler);
    }
    break;

  case NODE_WHILE:
  case NODE_UNTIL:
    process_node(node->nd_cond, handler);
    if (node->nd_body) {
      process_node(node->nd_body, handler);
    }
    break;

  case NODE_BLOCK_PASS:
    process_node(node->nd_body, handler);
    process_node(node->nd_iter, handler);
    break;

  case NODE_ITER:
  case NODE_FOR:
    process_node(node->nd_iter, handler);
    if (node->nd_var != (NODE *)1
        && node->nd_var != (NODE *)2
        && node->nd_var != NULL) {
	    process_node(node->nd_var, handler);
    }
    process_node(node->nd_body, handler);
    break;

  case NODE_BREAK:
  case NODE_NEXT:
    if (node->nd_stts)
	    process_node(node->nd_stts, handler);

    break;

  case NODE_YIELD:
    if (node->nd_stts)
      process_node(node->nd_stts, handler);

    break;

  case NODE_RESCUE:
    process_node(node->nd_1st, handler);
    process_node(node->nd_2nd, handler);
    process_node(node->nd_3rd, handler);
    break;

  /*
  // rescue body:
  // begin stmt rescue exception => var; stmt; [rescue e2 => v2; s2;]* end
  // stmt rescue stmt
  // a = b rescue c
  */

  case NODE_RESBODY:
      if (node->nd_3rd) {
        process_node(node->nd_3rd, handler);
      }
      process_node(node->nd_2nd, handler);
      process_node(node->nd_1st, handler);
    break;

  case NODE_ENSURE:
    process_node(node->nd_head, handler);
    if (node->nd_ensr) {
    process_node(node->nd_ensr, handler);
    }
    break;

  case NODE_AND:
  case NODE_OR:
      process_node(node->nd_1st, handler);
      process_node(node->nd_2nd, handler);
    break;

  case NODE_FLIP2:
  case NODE_FLIP3:
    process_node(node->nd_beg, handler);
    process_node(node->nd_end, handler);
    break;

  case NODE_DOT2:
  case NODE_DOT3:
    process_node(node->nd_beg, handler);
    process_node(node->nd_end, handler);
    break;

  case NODE_RETURN:
    if (node->nd_stts)
      process_node(node->nd_stts, handler);
    break;

  case NODE_ARGSCAT:
  case NODE_ARGSPUSH:
    process_node(node->nd_head, handler);
    process_node(node->nd_body, handler);
    break;

  case NODE_CALL:
  case NODE_FCALL:
  case NODE_VCALL:
    if (nd_type(node) != NODE_FCALL) {
    	if (node->nd_recv) process_node(node->nd_recv, handler);
	 }
     if (node->nd_args || nd_type(node) != NODE_FCALL) {
      	if (node->nd_args) process_node(node->nd_args, handler);
     }
    break;

  case NODE_SUPER:
    process_node(node->nd_args, handler);
    break;

  case NODE_BMETHOD:
    {
      struct BLOCK *data;
      Data_Get_Struct(node->nd_cval, struct BLOCK, data);

      if (data->var == 0 || data->var == (NODE *)1 || data->var == (NODE *)2) {
      } else {
	      process_node(data->var, handler);
      }
      process_node(data->body, handler);
    }
    break;

#if RUBY_VERSION_CODE < 190
  case NODE_DMETHOD:
    {
      struct METHOD *data;
      Data_Get_Struct(node->nd_cval, struct METHOD, data);
      process_node(data->body, handler);

      break;
    }
#endif

  case NODE_METHOD:
    // You should not ever get here. parse_tree_for_meth passes nd_body
    process_node(node->nd_body, handler);
    break;

  case NODE_SCOPE:
    process_node(node->nd_next, handler);
    break;

  case NODE_OP_ASGN1:
    process_node(node->nd_recv, handler);
#if RUBY_VERSION_CODE < 185
    process_node(node->nd_args->nd_next, handler);
#else
    process_node(node->nd_args->nd_2nd, handler);
#endif
    process_node(node->nd_args->nd_head, handler);
    break;

  case NODE_OP_ASGN2:
    process_node(node->nd_recv, handler);
    process_node(node->nd_value, handler);
    break;

  case NODE_OP_ASGN_AND:
  case NODE_OP_ASGN_OR:
    process_node(node->nd_head, handler);
    process_node(node->nd_value, handler);
    break;

  case NODE_MASGN:
    if (node->nd_head) {
    process_node(node->nd_head, handler);
    }
    if (node->nd_args) {
      if (node->nd_args != (NODE *)-1) {
	    process_node(node->nd_args, handler);
      }
    }
    if (node->nd_value) {
	    process_node(node->nd_value, handler);
    }
    break;

  case NODE_LASGN:
  case NODE_IASGN:
  case NODE_DASGN:
  case NODE_CVASGN:
  case NODE_CVDECL:
  case NODE_GASGN:
    process_node(node->nd_value, handler);
    break;

  case NODE_CDECL:
    if (node->nd_vid) {
    } else {
      process_node(node->nd_else, handler);
    }
    process_node(node->nd_value, handler);
    break;

  case NODE_DASGN_CURR:
    if (node->nd_value) {
      process_node(node->nd_value, handler);
    }
    break;

  case NODE_ALIAS:            /* u1 u2 (alias :blah :blah2) */
#if RUBY_VERSION_CODE < 185
#else
    process_node(node->nd_1st, handler);
    process_node(node->nd_2nd, handler);
#endif
    break;

  case NODE_UNDEF:            /* u2    (undef name, ...) */
#if RUBY_VERSION_CODE < 185
#else
    process_node(node->nd_value, handler);
#endif
    break;

  case NODE_HASH:
    {
      NODE *list;

      list = node->nd_head;
      while (list) {
	    process_node(list->nd_head, handler);
        list = list->nd_next;
      }
    }
    break;

  case NODE_ARRAY:
      while (node) {
	    process_node(node->nd_head, handler);
        node = node->nd_next;
      }
    break;

  case NODE_DSTR:
  case NODE_DSYM:
  case NODE_DXSTR:
  case NODE_DREGX:
  case NODE_DREGX_ONCE:
    {
      NODE *list = node->nd_next;
      while (list) {
        if (list->nd_head) {
		  process_node(list->nd_head, handler);
        }
        list = list->nd_next;
      }
    }
    break;

  case NODE_DEFN:
  case NODE_DEFS:
    if (node->nd_defn) {
      if (nd_type(node) == NODE_DEFS)
	    process_node(node->nd_recv, handler);

      process_node(node->nd_defn, handler);
    }
    break;

  case NODE_CLASS:
  case NODE_MODULE:
    if (nd_type(node->nd_cpath) == NODE_COLON2 && ! node->nd_cpath->nd_vid) {
    } else {
      process_node(node->nd_cpath, handler);
    }

    if (nd_type(node) == NODE_CLASS) {
      if (node->nd_super) {
        process_node(node->nd_super, handler);
      }
    }
    process_node(node->nd_body, handler);
    break;

  case NODE_SCLASS:
    process_node(node->nd_recv, handler);
    process_node(node->nd_body, handler);
    break;

  case NODE_ARGS: {
    NODE *optnode;
    optnode = node->nd_opt;
    if (optnode) {
	  process_node(node->nd_opt, handler);
    }
  }  break;

  case NODE_NEWLINE:
    process_node(node->nd_next, handler);
    break;

  case NODE_SPLAT:
  case NODE_TO_ARY:
  case NODE_SVALUE:             /* a = b, c */
    process_node(node->nd_head, handler);
    break;

  case NODE_ATTRASGN:           /* literal.meth = y u1 u2 u3 */
    /* node id node */
    if (node->nd_1st == RNODE(1)) {
//      add_to_parse_tree(self, current, NEW_SELF(), locals);
    } else {
        process_node(node->nd_1st, handler);
    }
    process_node(node->nd_3rd, handler);
    break;

  case NODE_EVSTR:
    process_node(node->nd_2nd, handler);
    break;


#if RUBY_VERSION_CODE >= 190
  case NODE_ERRINFO:
  case NODE_VALUES:
  case NODE_PRELUDE:
  case NODE_LAMBDA:
    puts("no worky in 1.9 yet");
    break;
#endif

  /* Nodes we found but have yet to decypher */
  /* I think these are all runtime only... not positive but... */
  case NODE_MEMO:               /* enum.c zip */
  case NODE_CREF:
  /* #defines: */
  /* case NODE_LMASK: */
  /* case NODE_LSHIFT: */
  default:
    break;
  }
}

void process_node(NODE* node, VALUE handler) {
	if (node) {
	process_recursive_node(node, handler);
	process_individual_node(node, handler);
	}
}

VALUE hook_method_tree(VALUE self, VALUE rb_method) {

	struct METHOD* method;
	Data_Get_Struct(rb_method,struct METHOD,method);

	NODE* node = method->body->nd_defn;
	process_node(node, self);

	return Qnil;
}


VALUE hook_block(VALUE self, VALUE handler) {
	process_node(ruby_frame->node->nd_recv, handler);
}

VALUE caller_method(VALUE self, VALUE rblevel) {
	int level = FIX2INT(rblevel);

	struct FRAME* frame = ruby_frame;
	while(level--) frame = frame->prev;

	return ID2SYM(frame->orig_func);
}

VALUE caller_class(VALUE self, VALUE rblevel) {
	int level = FIX2INT(rblevel);

	struct FRAME* frame = ruby_frame;
	while(level--) frame = frame->prev;

	return frame->last_class;
}

VALUE caller_obj(VALUE self, VALUE rblevel) {
	int level = FIX2INT(rblevel);

	struct FRAME* frame = ruby_frame;
	while(level--) frame = frame->prev;

	return frame->self;
}


static void
blk_mark(data)
    struct BLOCK *data;
{
    while (data) {
	rb_gc_mark_frame(&data->frame);
	rb_gc_mark((VALUE)data->scope);
	rb_gc_mark((VALUE)data->var);
	rb_gc_mark((VALUE)data->body);
	rb_gc_mark((VALUE)data->self);
	rb_gc_mark((VALUE)data->dyna_vars);
	rb_gc_mark((VALUE)data->cref);
	rb_gc_mark(data->wrapper);
	rb_gc_mark(data->block_obj);
	data = data->prev;
    }
}

static void
blk_free(data)
    struct BLOCK *data;
{
    void *tmp;

    while (data) {
	frame_free(&data->frame);
	tmp = data;
	data = data->prev;
	free(tmp);
    }
}



/*
 *  call-seq:
 *     binding -> a_binding
 *
 *  Returns a +Binding+ object, describing the variable and
 *  method bindings at the point of call. This object can be used when
 *  calling +eval+ to execute the evaluated command in this
 *  environment. Also see the description of class +Binding+.
 *
 *     def getBinding(param)
 *       return binding
 *     end
 *     b = getBinding("hello")
 *     eval("param", b)   #=> "hello"
 */

static VALUE
rb_f_evalhook(argc, argv, recv)
	int argc;
	VALUE* argv;
	VALUE recv;
{


	VALUE bind = Qnil;
 	VALUE file = Qnil;
 	VALUE line = Qnil;

 	if (argc == 0) {
		return rb_funcall2(recv,rb_intern("evalhook_i"), 0, 0);
 	}

 	if (argc > 1) bind = argv[1];
 	if (argc > 2) file = argv[2];
 	if (argc > 3) line = argv[3];

	if (argc < 2) argc = 2;

	if (bind == Qnil) {
		bind = rb_funcall(recv, rb_intern("binding"),0);
		argv[1] = bind;

		struct BLOCK* data;
		Data_Get_Struct(bind, struct BLOCK, data);

		data->self = data->frame.prev->prev->self;
	}

	if (file == Qnil) {
		argc = 2;
	}

	return rb_funcall2(recv,rb_intern("evalhook_i"), argc, argv);
}

VALUE validate_syntax(VALUE self, VALUE code) {

	NODE* node = rb_compile_string("(eval)", code, 1);

	if (node == 0) {
		rb_raise(rb_eSyntaxError,"");
	}

	return Qnil;
}


extern void Init_evalhook_base() {
	m_EvalHook = rb_define_module("EvalHook");

/*
Class to create hook instances for specific handling of method calls and/or const and global assignment

=== Example:

Hook of method calls

	require "rubygems"
	require "evalhook"

	class Hook < EvalHook::HookHandler
		def handle_method(klass, recv, method_name)
			print "called #{klass}##{method_name} over #{recv}\n"
			nil
		end
	end

	h = Hook.new
	h.evalhook('print "hello world\n"')




See README for more examples

*/
	c_HookHandler = rb_define_class_under(m_EvalHook, "HookHandler", rb_cObject);

	rb_define_singleton_method(m_EvalHook, "hook_block", hook_block, 1);
	rb_define_singleton_method(m_EvalHook, "validate_syntax", validate_syntax, 1);

	rb_define_method(c_HookHandler, "hook_method_tree", hook_method_tree, 1);

	rb_define_method(c_HookHandler, "caller_method", caller_method, 1);
	rb_define_method(c_HookHandler, "caller_class", caller_class, 1);
	rb_define_method(c_HookHandler, "caller_obj", caller_obj, 1);

	method_local_hooked_method = rb_intern("local_hooked_method");
	method_hooked_method = rb_intern("hooked_method");
	method_call = rb_intern("call");
	method_private = rb_intern("private");
	method_public = rb_intern("public");
	method_protected = rb_intern("protected");
	method_set_hook_handler = rb_intern("set_hook_handler");

    rb_define_method(c_HookHandler, "evalhook", rb_f_evalhook, -1);
}
