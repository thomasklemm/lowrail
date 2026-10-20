/* Export the existing sampler's retained frame metadata after collection.
 * The sampling loop, roots, windows and counters are unchanged. */
#include "hotspots.c"

static VALUE details(VALUE self) {
    VALUE ids = rb_hash_new(), frames = rb_ary_new(), stacks = rb_ary_new();
    for (unsigned r = 0; r < used; r++) {
        VALUE stack = rb_ary_new(), counts = rb_ary_new();
        for (int i = 0; i < records[r].depth; i++) {
            VALUE frame = records[r].frames[i];
            VALUE path = rb_profile_frame_absolute_path(frame);
            if (!RB_TYPE_P(path, T_STRING)) path = rb_profile_frame_path(frame);
            if (!RB_TYPE_P(path, T_STRING) || !strcmp(StringValueCStr(path), "<cfunc>")) continue;
            VALUE key = ULL2NUM((uintptr_t)frame), id = rb_hash_aref(ids, key);
            if (NIL_P(id)) {
                id = LONG2NUM(RARRAY_LEN(frames));
                VALUE method = rb_profile_frame_qualified_method_name(frame);
                if (NIL_P(method)) method = rb_profile_frame_full_label(frame);
                rb_ary_push(frames, rb_ary_new_from_args(3, path, method, rb_profile_frame_first_lineno(frame)));
                rb_hash_aset(ids, key, id);
            }
            rb_ary_push(stack, id);
        }
        for (int w = 0; w < WINDOWS; w++) rb_ary_push(counts, ULL2NUM(records[r].counts[w]));
        rb_ary_push(stacks, rb_ary_new_from_args(2, stack, counts));
    }
    VALUE result = rb_hash_new();
    rb_hash_aset(result, rb_str_new_cstr("frames"), frames);
    rb_hash_aset(result, rb_str_new_cstr("stacks"), stacks);
    return result;
}

void Init_lowrail_hotspots_detail(void) {
    Init_lowrail_hotspots();
    VALUE mod = rb_const_get(rb_cObject, rb_intern("HotspotProbe"));
    rb_define_singleton_method(mod, "details", details, 0);
}
