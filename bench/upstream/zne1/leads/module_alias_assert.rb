# On a RUBY_DEBUG build this aborts with
#   vm_method.c:508: Assertion Failed: clear_method_cache_by_id_in_class:RB_TYPE_P(owner, RUBY_T_CLASS): owner: T_MODULE
# No ZJIT and no `!=` involved: a module aliases a method that a class owns, the alias is called through
# an including class, then the module defines the method itself.
module M; end
class C; include M; end
M.class_eval { alias_method(:foo, :equal?) }
C.new.foo(1)
M.class_eval { def foo(other) = 2 }
p C.new.foo(1)
