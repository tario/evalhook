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

#define nd_3rd   u3.node

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


void process_node(NODE* node);

void process_individual_node(NODE* node) {

	switch (nd_type(node)) {
		case NODE_FCALL: {
			struct NODE* args;
			args = NEW_LIST(NEW_LIT(ID2SYM(node->nd_mid)));
			node->nd_recv = NEW_CALL(NEW_SELF(), rb_intern("hooked_method"), args);
			node->nd_mid = rb_intern("call");
			nd_set_type(node, NODE_CALL);
			break;
		}

		case NODE_CALL:
		case NODE_VCALL: {
			struct NODE* args;
			args = NEW_LIST(NEW_LIT(ID2SYM(node->nd_mid)));
			node->nd_recv = NEW_CALL(node->nd_recv, rb_intern("hooked_method"), args);
			node->nd_mid = rb_intern("call");
			break;
		}
	}
}

void process_recursive_node(NODE* node ) {
  switch (nd_type(node)) {

    case NODE_BLOCK:
      {
        while (node) {
          process_node(node->nd_head);
          node = node->nd_next;
        }
      }
      break;

    case NODE_FBODY:
    case NODE_DEFINED:
    case NODE_COLON2:
      process_node(node->nd_head);
      break;

    case NODE_MATCH2:
    case NODE_MATCH3:
      process_node(node->nd_recv);
      process_node(node->nd_value);
      break;

    case NODE_BEGIN:
    case NODE_OPT_N:
    case NODE_NOT:
      process_node(node->nd_body);
      break;

    case NODE_IF:
      process_node(node->nd_cond);
      if (node->nd_body) {
	      process_node(node->nd_body);
      }
      if (node->nd_else) {
	      process_node(node->nd_else);
      }
      break;

  case NODE_CASE:
    if (node->nd_head != NULL) {
      process_node(node->nd_head);
    }
    node = node->nd_body;
    while (node) {
      process_node(node);
      if (nd_type(node) == NODE_WHEN) {                 /* when */
        node = node->nd_next;
      } else {
        break;                                          /* else */
      }
    }
    break;

  case NODE_WHEN:
    process_node(node->nd_head);
    if (node->nd_body) {
      process_node(node->nd_body);
    }
    break;

  case NODE_WHILE:
  case NODE_UNTIL:
    process_node(node->nd_cond);
    if (node->nd_body) {
      process_node(node->nd_body);
    }
    break;

  case NODE_BLOCK_PASS:
    process_node(node->nd_body);
    process_node(node->nd_iter);
    break;

  case NODE_ITER:
  case NODE_FOR:
    process_node(node->nd_iter);
    if (node->nd_var != (NODE *)1
        && node->nd_var != (NODE *)2
        && node->nd_var != NULL) {
	    process_node(node->nd_var);
    }
    process_node(node->nd_body);
    break;

  case NODE_BREAK:
  case NODE_NEXT:
    if (node->nd_stts)
	    process_node(node->nd_stts);

    break;

  case NODE_YIELD:
    if (node->nd_stts)
      process_node(node->nd_stts);

    break;

  case NODE_RESCUE:
    process_node(node->nd_1st);
    process_node(node->nd_2nd);
    process_node(node->nd_3rd);
    break;

  /*
  // rescue body:
  // begin stmt rescue exception => var; stmt; [rescue e2 => v2; s2;]* end
  // stmt rescue stmt
  // a = b rescue c
  */

  case NODE_RESBODY:
      if (node->nd_3rd) {
        process_node(node->nd_3rd);
      }
      process_node(node->nd_2nd);
      process_node(node->nd_1st);
    break;

  case NODE_ENSURE:
    process_node(node->nd_head);
    if (node->nd_ensr) {
    process_node(node->nd_ensr);
    }
    break;

  case NODE_AND:
  case NODE_OR:
      process_node(node->nd_1st);
      process_node(node->nd_2nd);
    break;

  case NODE_FLIP2:
  case NODE_FLIP3:
    process_node(node->nd_beg);
    process_node(node->nd_end);
    break;

  case NODE_DOT2:
  case NODE_DOT3:
    process_node(node->nd_beg);
    process_node(node->nd_end);
    break;

  case NODE_RETURN:
    if (node->nd_stts)
      process_node(node->nd_stts);
    break;

  case NODE_ARGSCAT:
  case NODE_ARGSPUSH:
    process_node(node->nd_head);
    process_node(node->nd_body);
    break;

  case NODE_CALL:
  case NODE_FCALL:
  case NODE_VCALL:
    if (nd_type(node) != NODE_FCALL) {
    	if (node->nd_recv) process_node(node->nd_recv);
	 }
     if (node->nd_args || nd_type(node) != NODE_FCALL) {
      	if (node->nd_args) process_node(node->nd_args);
     }
    break;

  case NODE_SUPER:
    process_node(node->nd_args);
    break;

  case NODE_BMETHOD:
    {
      struct BLOCK *data;
      Data_Get_Struct(node->nd_cval, struct BLOCK, data);

      if (data->var == 0 || data->var == (NODE *)1 || data->var == (NODE *)2) {
      } else {
	      process_node(data->var);
      }
      process_node(data->body);
    }
    break;

#if RUBY_VERSION_CODE < 190
  case NODE_DMETHOD:
    {
      struct METHOD *data;
      Data_Get_Struct(node->nd_cval, struct METHOD, data);
      process_node(data->body);

      break;
    }
#endif

  case NODE_METHOD:
    // You should not ever get here. parse_tree_for_meth passes nd_body
    process_node(node->nd_body);
    break;

  case NODE_SCOPE:
    process_node(node->nd_next);
    break;

  case NODE_OP_ASGN1:
    process_node(node->nd_recv);
#if RUBY_VERSION_CODE < 185
    process_node(node->nd_args->nd_next);
#else
    process_node(node->nd_args->nd_2nd);
#endif
    process_node(node->nd_args->nd_head);
    break;

  case NODE_OP_ASGN2:
    process_node(node->nd_recv);
    process_node(node->nd_value);
    break;

  case NODE_OP_ASGN_AND:
  case NODE_OP_ASGN_OR:
    process_node(node->nd_head);
    process_node(node->nd_value);
    break;

  case NODE_MASGN:
    if (node->nd_head) {
    process_node(node->nd_head);
    }
    if (node->nd_args) {
      if (node->nd_args != (NODE *)-1) {
	    process_node(node->nd_args);
      }
    }
    if (node->nd_value) {
	    process_node(node->nd_value);
    }
    break;

  case NODE_LASGN:
  case NODE_IASGN:
  case NODE_DASGN:
  case NODE_CVASGN:
  case NODE_CVDECL:
  case NODE_GASGN:
    process_node(node->nd_value);
    break;

  case NODE_CDECL:
    if (node->nd_vid) {
    } else {
      process_node(node->nd_else);
    }
    process_node(node->nd_value);
    break;

  case NODE_DASGN_CURR:
    if (node->nd_value) {
      process_node(node->nd_value);
    }
    break;

  case NODE_ALIAS:            /* u1 u2 (alias :blah :blah2) */
#if RUBY_VERSION_CODE < 185
#else
    process_node(node->nd_1st);
    process_node(node->nd_2nd);
#endif
    break;

  case NODE_UNDEF:            /* u2    (undef name, ...) */
#if RUBY_VERSION_CODE < 185
#else
    process_node(node->nd_value);
#endif
    break;

  case NODE_HASH:
    {
      NODE *list;

      list = node->nd_head;
      while (list) {
	    process_node(node->nd_head);
        list = list->nd_next;
        if (list == 0)
          rb_bug("odd number list for Hash");
	    process_node(node->nd_head);
        list = list->nd_next;
      }
    }
    break;

  case NODE_ARRAY:
      while (node) {
	    process_node(node->nd_head);
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
          switch (nd_type(list->nd_head)) {
          case NODE_STR:
		    process_node(list->nd_head);
            break;
          case NODE_EVSTR:
		    process_node(list->nd_head);
            break;
          default:
		    process_node(list->nd_head);
            break;
          }
        }
        list = list->nd_next;
      }
    }
    break;

  case NODE_DEFN:
  case NODE_DEFS:
    if (node->nd_defn) {
      if (nd_type(node) == NODE_DEFS)
	    process_node(node->nd_recv);

      process_node(node->nd_defn);
    }
    break;

  case NODE_CLASS:
  case NODE_MODULE:
    if (nd_type(node->nd_cpath) == NODE_COLON2 && ! node->nd_cpath->nd_vid) {
    } else {
      process_node(node->nd_cpath);
    }

    if (nd_type(node) == NODE_CLASS) {
      if (node->nd_super) {
        process_node(node->nd_super);
      }
    }
    process_node(node->nd_body);
    break;

  case NODE_SCLASS:
    process_node(node->nd_recv);
    process_node(node->nd_body);
    break;

  case NODE_ARGS: {
    NODE *optnode;
    optnode = node->nd_opt;
    if (optnode) {
	  process_node(node->nd_opt);
    }
  }  break;

  case NODE_NEWLINE:
    process_node(node->nd_next);
    break;

  case NODE_SPLAT:
  case NODE_TO_ARY:
  case NODE_SVALUE:             /* a = b, c */
    process_node(node->nd_head);
    break;

  case NODE_ATTRASGN:           /* literal.meth = y u1 u2 u3 */
    /* node id node */
    if (node->nd_1st == RNODE(1)) {
//      add_to_parse_tree(self, current, NEW_SELF(), locals);
    } else {
        process_node(node->nd_1st);
    }
    process_node(node->nd_3rd);
    break;

  case NODE_EVSTR:
    process_node(node->nd_2nd);
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
    rb_warn("Unhandled node #%d type '%i'", nd_type(node), nd_type(node));
    break;
  }
}

void process_node(NODE* node) {
	if (node) {
	process_recursive_node(node);
	process_individual_node(node);
	}
}


VALUE hook_block(VALUE self) {
	process_node(ruby_frame->node->nd_recv);
}


extern void Init_evalhook_base() {
	m_EvalHook = rb_define_module("EvalHook");
	rb_define_singleton_method(m_EvalHook, "hook_block", hook_block, 0);
}
