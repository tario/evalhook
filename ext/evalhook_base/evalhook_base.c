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

struct tag {
    rb_jmpbuf_t buf;
    struct FRAME *frame;
    struct iter *iter;
    VALUE tag;
    VALUE retval;
    struct SCOPE *scope;
    VALUE dst;
    struct tag *prev;
    int blkid;
};

extern struct BLOCK *ruby_block;
#define PROT_NONE   Qfalse	/* 0 */
#define PROT_THREAD Qtrue	/* 2 */
#define PROT_FUNC   INT2FIX(0)	/* 1 */
#define PROT_LOOP   INT2FIX(1)	/* 3 */
#define PROT_LAMBDA INT2FIX(2)	/* 5 */
#define PROT_YIELD  INT2FIX(3)	/* 7 */

#define TAG_RAISE	0x6


static VALUE
evalhook(self, src, scope, file, line)
    VALUE self, src, scope;
    const char *file;
    int line;
{
    struct BLOCK *data = NULL;
    volatile VALUE result = Qnil;
    struct SCOPE * volatile old_scope;
    struct BLOCK * volatile old_block;
    struct RVarmap * volatile old_dyna_vars;
    VALUE volatile old_cref;
    struct FRAME frame;
    NODE *nodesave = ruby_current_node;
    volatile int iter = ruby_frame->iter;
    volatile int safe = ruby_safe_level;
    int state;

    if (!NIL_P(scope)) {
	if (!rb_obj_is_proc(scope)) {
	    rb_raise(rb_eTypeError, "wrong argument type %s (expected Proc/Binding)",
		     rb_obj_classname(scope));
	}

	Data_Get_Struct(scope, struct BLOCK, data);
	/* PUSH BLOCK from data */
	frame = data->frame;
	frame.tmp = ruby_frame;	/* gc protection */
	ruby_frame = &(frame);
	old_scope = ruby_scope;
	ruby_scope = data->scope;
	old_block = ruby_block;
	ruby_block = data->prev;
	old_dyna_vars = ruby_dyna_vars;
	ruby_dyna_vars = data->dyna_vars;
	old_cref = (VALUE)ruby_cref;
	ruby_cref = data->cref;
	if ((file == 0 || (line == 1 && strcmp(file, "(eval)") == 0)) && data->frame.node) {
	    file = data->frame.node->nd_file;
	    if (!file) file = "__builtin__";
	    line = nd_line(data->frame.node);
	}

	self = data->self;
	ruby_frame->iter = data->iter;
    }
    else {
	if (ruby_frame->prev) {
	    ruby_frame->iter = ruby_frame->prev->iter;
	}
    }
    if (file == 0) {
	ruby_set_current_source();
	file = ruby_sourcefile;
	line = ruby_sourceline;
    }
    PUSH_CLASS(data ? data->klass : ruby_class);
    ruby_in_eval++;
    if (TYPE(ruby_class) == T_ICLASS) {
	ruby_class = RBASIC(ruby_class)->klass;
    }
    PUSH_TAG(PROT_NONE);
    if ((state = EXEC_TAG()) == 0) {
	NODE *node;

	ruby_safe_level = 0;
	result = ruby_errinfo;
	ruby_errinfo = Qnil;
	node = compile(src, file, line);
	ruby_safe_level = safe;
	if (ruby_nerrs > 0) {
	    compile_error(0);
	}
	if (!NIL_P(result)) ruby_errinfo = result;
	result = eval_node(self, node);
    }
    POP_TAG();
    POP_CLASS();
    ruby_in_eval--;
	ruby_frame->iter = iter;
    ruby_current_node = nodesave;
    ruby_set_current_source();
    if (state) {
	if (state == TAG_RAISE) {
	    if (strcmp(file, "(eval)") == 0) {
		VALUE mesg, errat, bt2;
		ID id_mesg;

		id_mesg = rb_intern("mesg");
		errat = get_backtrace(ruby_errinfo);
		mesg = rb_attr_get(ruby_errinfo, id_mesg);
		if (!NIL_P(errat) && TYPE(errat) == T_ARRAY &&
		    (bt2 = backtrace(-2), RARRAY_LEN(bt2) > 0)) {
		    if (!NIL_P(mesg) && TYPE(mesg) == T_STRING) {
			if (OBJ_FROZEN(mesg)) {
			    VALUE m = rb_str_cat(rb_str_dup(RARRAY_PTR(errat)[0]), ": ", 2);
			    rb_ivar_set(ruby_errinfo, id_mesg, rb_str_append(m, mesg));
			}
			else {
			    rb_str_update(mesg, 0, 0, rb_str_new2(": "));
			    rb_str_update(mesg, 0, 0, RARRAY_PTR(errat)[0]);
			}
		    }
		    RARRAY_PTR(errat)[0] = RARRAY_PTR(bt2)[0];
		}
	    }
	    rb_exc_raise(ruby_errinfo);
	}
	JUMP_TAG(state);
    }

    return result;
}



static VALUE
rb_f_evalhook(argc, argv, self)
    int argc;
    VALUE *argv;
    VALUE self;
{
    VALUE src, scope, vfile, vline;
    const char *file = "(eval)";
    int line = 1;

    rb_scan_args(argc, argv, "13", &src, &scope, &vfile, &vline);
    if (ruby_safe_level >= 4) {
	StringValue(src);
	if (!NIL_P(scope) && !OBJ_TAINTED(scope)) {
	    rb_raise(rb_eSecurityError, "Insecure: can't modify trusted binding");
	}
    }
    else {
	SafeStringValue(src);
    }
    if (argc >= 3) {
	StringValue(vfile);
    }
    if (argc >= 4) {
	line = NUM2INT(vline);
    }

    if (!NIL_P(vfile)) file = RSTRING(vfile)->ptr;

    return evalhook(self, src, scope, file, line);
}


extern void Init_evalhook_base() {
	rb_define_global_function("evalhook", rb_f_evalhook, -1 ) ;
}
