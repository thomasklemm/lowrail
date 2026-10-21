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

#if defined(HAVE_RB_VM_METHOD_TOKEN) && defined(HAVE_RB_VM_METHOD_TOKEN_VALID_P)
/* One C-owned vector, not one Ruby wrapper per dependency. The hidden Array
 * owns/compacts the raw VM values; no raw token ever reaches Ruby code. */
static void
lowrail_tokens_mark(void *ptr)
{
    rb_gc_mark_movable(*(VALUE *)ptr);
}

static void
lowrail_tokens_compact(void *ptr)
{
    *(VALUE *)ptr = rb_gc_location(*(VALUE *)ptr);
}

static const rb_data_type_t lowrail_tokens_type = {
    "Lowrail::MethodTokens",
    {lowrail_tokens_mark, RUBY_TYPED_DEFAULT_FREE, NULL, lowrail_tokens_compact},
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED
};

static VALUE
lowrail_method_tokens(VALUE self, VALUE entries)
{
    Check_Type(entries, T_ARRAY);
    VALUE *ptr;
    VALUE object = TypedData_Make_Struct(rb_cObject, VALUE, &lowrail_tokens_type, ptr);
    VALUE tokens = rb_obj_hide(rb_ary_new_capa(RARRAY_LEN(entries)));
    RB_OBJ_WRITE(object, ptr, tokens);
    for (long i = 0; i < RARRAY_LEN(entries); i++) {
        VALUE entry = RARRAY_AREF(entries, i);
        Check_Type(entry, T_ARRAY);
        if (RARRAY_LEN(entry) != 2) rb_raise(rb_eArgError, "expected [Class, method id]");
        VALUE token = rb_vm_method_token(RARRAY_AREF(entry, 0), rb_to_id(RARRAY_AREF(entry, 1)));
        if (NIL_P(token)) return Qnil;
        rb_ary_push(tokens, token);
    }
    return object;
}

static VALUE
lowrail_method_tokens_valid(VALUE self, VALUE object)
{
    VALUE tokens = *(VALUE *)rb_check_typeddata(object, &lowrail_tokens_type);
    for (long i = 0; i < RARRAY_LEN(tokens); i++) {
        if (!rb_vm_method_token_valid_p(RARRAY_AREF(tokens, i))) return Qfalse;
    }
    return Qtrue;
}
#endif

void
Init_lowrail_native(void)
{
    VALUE lowrail = rb_define_module("Lowrail");
    VALUE native = rb_define_module_under(lowrail, "Native");
    id_each = rb_intern("each");
    id_each_with_object = rb_intern("each_with_object");
    rb_define_singleton_method(native, "exact_class?", lowrail_exact_class, 2);
    rb_define_singleton_method(native, "plain_hash_iteration?", lowrail_plain_hash_iteration, 1);
#if defined(HAVE_RB_VM_METHOD_TOKEN) && defined(HAVE_RB_VM_METHOD_TOKEN_VALID_P)
    rb_define_singleton_method(native, "method_tokens", lowrail_method_tokens, 1);
    rb_define_singleton_method(native, "method_tokens_valid?", lowrail_method_tokens_valid, 1);
#endif
}
