#include <ruby.h>
#include <ruby/vm.h>

/* Isolated uncontended copy of the epoch CAS, not a VM mutation benchmark. */
static unsigned long counter;
__attribute__((noinline)) static unsigned long empty_one(void) {
    __asm__ __volatile__("" ::: "memory");
    return 1;
}
__attribute__((noinline)) static unsigned long bump_one(void) {
    unsigned long old = __atomic_load_n(&counter, __ATOMIC_RELAXED);
    while (old < (unsigned long)FIXNUM_MAX &&
           !__atomic_compare_exchange_n(&counter, &old, old + 1,
                                        1, __ATOMIC_RELAXED, __ATOMIC_RELAXED)) {}
    return 1;
}
static VALUE empty(VALUE self, VALUE count) {
    unsigned long n = NUM2ULONG(count), sum = 0;
    for (unsigned long i = 0; i < n; i++) sum += empty_one();
    return ULONG2NUM(sum);
}
static VALUE checks(VALUE self, VALUE count, VALUE token) {
    unsigned long n = NUM2ULONG(count), sum = 0;
    for (unsigned long i = 0; i < n; i++) sum += rb_vm_method_token_valid_p(token);
    return ULONG2NUM(sum);
}
static VALUE bumps(VALUE self, VALUE count) {
    unsigned long n = NUM2ULONG(count), sum = 0;
    for (unsigned long i = 0; i < n; i++) sum += bump_one();
    return ULONG2NUM(sum);
}
void Init_vm_token_native(void) {
    VALUE mod = rb_define_module("VMTokenNative");
    rb_define_singleton_method(mod, "empty", empty, 1);
    rb_define_singleton_method(mod, "checks", checks, 2);
    rb_define_singleton_method(mod, "bumps", bumps, 1);
}
