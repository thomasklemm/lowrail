#include <ruby.h>

/* Do not expose internal class objects (which objspace must sometimes wrap).
 * Pointer equality also rejects eigenclasses, including private overrides and
 * singleton prepends, when the expected holder is an ordinary class. No Ruby
 * dispatch, allocation, eigenclass materialization or GC operation occurs. */
static VALUE
lowrail_exact_class(VALUE self, VALUE object, VALUE expected)
{
    return CLASS_OF(object) == expected ? Qtrue : Qfalse;
}

void
Init_lowrail_native(void)
{
    VALUE lowrail = rb_define_module("Lowrail");
    VALUE native = rb_define_module_under(lowrail, "Native");
    rb_define_singleton_method(native, "exact_class?", lowrail_exact_class, 2);
}
