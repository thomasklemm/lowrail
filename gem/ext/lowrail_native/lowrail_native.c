#include <ruby.h>

static ID id_each;
static ID id_each_with_object;

/* Do not expose internal class objects (which objspace must sometimes wrap).
 * Pointer equality also rejects eigenclasses, including private overrides and
 * singleton prepends, when the expected holder is an ordinary class. No Ruby
 * dispatch, allocation, eigenclass materialization or GC operation occurs. */
static VALUE
lowrail_exact_class(VALUE self, VALUE object, VALUE expected)
{
    return CLASS_OF(object) == expected ? Qtrue : Qfalse;
}

/* Pricing primitive for the audited, unrefined props iterator sites only.
 * Never cache dispatch: hooks can be suppressed and visibility can change
 * without a hook. CLASS_OF rejects subclasses AND existing eigenclasses.
 * The BASIC flag alone does not check public visibility. In the MRI versions
 * covered by native_props_test, boundp's undocumented flags 1|2 exclude both
 * private and protected entries, without respond_to_missing? or Ruby dispatch.
 * No private VM structs are copied. Unsupported builds refuse, not guess.
 * This does NOT certify arbitrary caller refinements, artifact admission or
 * main-Ractor execution; the existing outer guard must retain those duties. */
static VALUE
lowrail_plain_hash_iteration(VALUE self, VALUE object)
{
#if defined(HAVE_RB_METHOD_BASIC_DEFINITION_P) && defined(HAVE_RB_METHOD_BOUNDP)
    return CLASS_OF(object) == rb_cHash &&
        rb_method_basic_definition_p(rb_cHash, id_each) &&
        rb_method_basic_definition_p(rb_cHash, id_each_with_object) &&
        rb_method_boundp(rb_cHash, id_each, 3) == 1 &&
        rb_method_boundp(rb_cHash, id_each_with_object, 3) == 1 ? Qtrue : Qfalse;
#else
    return Qfalse;
#endif
}

void
Init_lowrail_native(void)
{
    VALUE lowrail = rb_define_module("Lowrail");
    VALUE native = rb_define_module_under(lowrail, "Native");
    id_each = rb_intern("each");
    id_each_with_object = rb_intern("each_with_object");
    rb_define_singleton_method(native, "exact_class?", lowrail_exact_class, 2);
    rb_define_singleton_method(native, "plain_hash_iteration?", lowrail_plain_hash_iteration, 1);
}
