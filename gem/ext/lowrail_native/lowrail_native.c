#include <ruby.h>
#include <ruby/vm.h>

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

/* Fork-only experiment. No Ruby VM internals are copied into the extension. */
static void
lowrail_token_mark(void *ptr)
{
    rb_gc_mark(*(VALUE *)ptr);
}

static const rb_data_type_t lowrail_token_type = {
    "Lowrail::MethodToken",
    {lowrail_token_mark, RUBY_TYPED_DEFAULT_FREE, NULL},
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE
lowrail_method_token(VALUE self, VALUE klass, VALUE name)
{
#if defined(HAVE_RB_VM_METHOD_TOKEN) && defined(HAVE_RB_VM_METHOD_TOKEN_VALID_P)
    VALUE *ptr;
    VALUE obj = TypedData_Make_Struct(rb_cObject, VALUE, &lowrail_token_type, ptr);
    VALUE token = rb_vm_method_token(klass, rb_to_id(name));
    if (NIL_P(token)) return Qnil;
    RB_OBJ_WRITE(obj, ptr, token);
    return obj;
#else
    return Qnil;
#endif
}

static VALUE
lowrail_method_tokens_valid(VALUE self, VALUE tokens)
{
    Check_Type(tokens, T_ARRAY);
#if defined(HAVE_RB_VM_METHOD_TOKEN) && defined(HAVE_RB_VM_METHOD_TOKEN_VALID_P)
    for (long i = 0; i < RARRAY_LEN(tokens); i++) {
        VALUE token = RARRAY_AREF(tokens, i);
        if (NIL_P(token)) return Qfalse;
        VALUE *ptr = rb_check_typeddata(token, &lowrail_token_type);
        if (!rb_vm_method_token_valid_p(*ptr)) return Qfalse;
    }
    return Qtrue;
#else
    return Qfalse;
#endif
}

/* Existing public-header alternative, including Method's allocation. */
static VALUE
lowrail_same_method(VALUE self, VALUE receiver, VALUE name, VALUE saved)
{
    return rb_equal(saved, rb_obj_method(receiver, name));
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
    rb_define_singleton_method(native, "method_token", lowrail_method_token, 2);
    rb_define_singleton_method(native, "method_tokens_valid?", lowrail_method_tokens_valid, 1);
    rb_define_singleton_method(native, "same_method?", lowrail_same_method, 3);
}
