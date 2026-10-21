# frozen_string_literal: true

require "mkmf"
have_func("rb_method_basic_definition_p", "ruby.h")
have_func("rb_method_boundp", "ruby.h")
create_makefile("lowrail_native")
