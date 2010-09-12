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

VALUE hook_block(VALUE self) {
	rb_yield(Qnil);
}


extern void Init_evalhook_base() {
	m_EvalHook = rb_define_module("EvalHook");
	rb_define_singleton_method(m_EvalHook, "hook_block", hook_block, 0);
}
