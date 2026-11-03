# ZJIT: interpolate Integers and Modules without `to_s` (bet Z5, Shopify/ruby#1091)

Shortlist item 1 ([zjit-shortlist.md](zjit-shortlist.md)). [Shopify/ruby#1091](https://github.com/Shopify/ruby/issues/1091)
(tekknolagi, open, unassigned) asks ZJIT to optimize `to_s` of Integer and similar receivers in `objtostring`.
tekknolagi pointed at the `cruby_methods` pattern of [ruby/ruby#19587](https://github.com/ruby/ruby/pull/19587)
and cc'd tenderworks (Aaron Patterson).

**Result.** Built on [`thomasklemm/zjit-objtostring-int-module`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-objtostring-int-module)
at [`ecb863fda0`](https://github.com/thomasklemm/ruby/commit/ecb863fda0d79a37a59c635bdc08d248326703d1)
(master `9f2e54518e` + 1 commit, 6 files, +249). It removes ZJIT's extra `to_s` string at monomorphic
Integer and Module interpolation sites. That cuts ZJIT's allocations beyond the interpreter by 41% on lobsters and
65% on shipit. On instructions, shipit gains −0.21%, all in GC, and lobsters and railsbench show no effect beyond
noise. **Not submitted:** the comment on #1091 comes first ("How we take an item", step 2). Its draft is at the end.

## Ownership check (2026-11-03)

* #1091: no assignee. Two comments, both tekknolagi: "cc @tenderworks" and the pointer to #19587.
* ruby/ruby PRs: no open ZJIT PR on `objtostring` or Integer/Module `to_s` (searched `objtostring`,
  `ZJIT to_s`, `ZJIT Integer to_s`, `interpolation ZJIT`). Aaron Patterson's open ZJIT PRs are #18771 (as
  tenderworks: array reads on a virtual heap) and #19434, #18834 (as tenderlove: Array#fetch, array ptr). The last `objtostring` work is #17499 (tekknolagi, merged June 2026, moved the specialization
  into HIR build, left `TODO(max): Handle polymorphic profiles`). #19587 (merged 2026-10-30) folds
  `nil/true/false.to_s` to their frozen strings.
* k0kubun's `zjit-lobsters7` (83 commits, Shopify/ruby#1039): no commit touches `to_s`, `objtostring` or
  interpolation.
* Our own [#19665](https://github.com/ruby/ruby/pull/19665) is the YJIT version (open). This is the ZJIT
  counterpart with the same semantics.

Why not `cruby_methods` as in #19587: `nil.to_s` always returns the same frozen string, so an annotation on
`NilClass#to_s` is exact for every call. `Integer#to_s` and `Module#to_s` must return a new mutable string to an
ordinary caller (`5.to_s << "x"`). Only interpolation may use a shared frozen string. That is what
`vm_objtostring()` does in the interpreter, so the change belongs at the `objtostring` site and not in a method
annotation.

## The gap

`vm_objtostring()` interpolates a Fixnum with `rb_fix_to_s()`, which returns a shared frozen string for 0..9, and a
Class or Module with its frozen name (`rb_mod_name()`), when `#to_s` is the original cfunc (`check_cfunc`). Since
#17499, ZJIT emits `GuardType` + `Send :to_s` for a profiled non-String, which becomes a `CCallVariadic` of
`Integer#to_s` or a `CCallWithFrame` of `Module#to_s`. Both allocate a new string.

```ruby
def t(i) = "t#{i}"              # interpreter 1 object, ZJIT 2 (i = 3)
def u(m) = "#{m} Update"        # interpreter 1 object, ZJIT 2 (m = a named class)
```

Rails sites: `JoinDependency#aliases` `"t#{i}_r#{j}"` (`join_dependency.rb:178`, +2,350 strings per shipit
iteration), `time_ago_in_words` in the lobsters benchmark (+414), and `"#{self} Update"` / `"#{self} Create"`
(`persistence.rb:236/229`, all nine census apps).

## Change

In HIR build, when `objtostring` profiles one Fixnum or one Module class (`monomorphic_summary`), and
`rb_callable_method_entry(klass, :to_s)` is the original `rb_int_to_s` or `rb_mod_to_s`:

* `PatchPoint NoSingletonClass` (unless it is already a singleton class), `NoTracePoint` and
  `MethodRedefined(klass, to_s)`, the same patch points as a cfunc call;
* `GuardType` of the profiled type;
* `CCallWithFrame` of `rb_fix_to_s` or `rb_zjit_mod_objtostring` (a 4-line helper in `zjit.c`:
  `rb_mod_name()`, else `rb_mod_to_s()`). It has a frame because `Module#to_s` of a singleton class calls
  `#inspect`.

A refined `to_s` is a different method entry at the site and keeps the send path, like `check_cfunc`. Polymorphic
profiles keep the existing `CondBranchHasType` + `Send`.

## Tests

| Test | master | branch |
| --- | --- | --- |
| `hir::opt_tests::test_optimize_objtostring_profiled_fixnum` (snapshot) | **fails**: `CCallVariadic v18, :Integer#to_s` | `GuardType Fixnum`, `CCallWithFrame :Integer#to_s` (`rb_fix_to_s`) |
| `hir::opt_tests::test_optimize_objtostring_profiled_module` (snapshot) | **fails**: `v41:BasicObject = CCallWithFrame :Module#to_s` | `v21:StringExact = CCallWithFrame :Module#to_s` (`rb_zjit_mod_objtostring`) |
| `hir::opt_tests::test_optimize_objtostring_profiled_module_with_redefined_to_s_falls_back_to_send` | passes | passes (a singleton `to_s` is inlined as before) |
| `codegen::tests::test_objtostring_integer_and_module_allocations` | **fails**: `[2, 2, 2]` objects | `[1, 1, 1]`, as in the interpreter; values for 3, −12, 2⁴⁰ and named classes/modules |
| `codegen::tests::test_objtostring_anonymous_and_singleton_module` | passes | passes (`#<Class:0x…>`, `#<Class:#<Object:…>>`) |
| `codegen::tests::test_objtostring_{integer,module}_to_s_redefined_after_compile` | passes | passes (`"x"`, `"mod!"` after redefinition) |
| `codegen::tests::test_objtostring_refined_to_s` | passes | passes (refined sites call the refinement, others do not) |

Two existing snapshots change as intended: `test_fold_any_to_string_with_known_string_exact` (an Integer
interpolation, `CCallVariadic Integer#to_s` → `CCallWithFrame` of `rb_fix_to_s`) and
`test_dead_string_interp_raise_block_folds_to_unreachable` (renumbered values only).

* `make zjit-test` (nextest 0.9.151): **1,947 / 1,947 pass**. One earlier run aborted only in the SIGPROF sampling
  test `test_profile_frames_during_direct_jit_to_jit_entry`, which was already flaky on master in Z1.
* `make btest RUN_OPTS=--zjit-call-threshold=1`: **PASS all 2,141**.
* Hand check against the interpreter: `[t(3), t(-5), t(Foo), t(Class.new), t(Object.new.singleton_class)]` and
  `class Integer; def to_s = "x"; end` give the same results.

## Rails effect

ruby/ruby master `9f2e54518e` (`~/rubies/m3`) against the branch (`~/rubies/z5`), same configure flags, same gems.
ruby-bench `73918b2`, harnesses as in [zjit-gap-census.md](zjit-gap-census.md#pins-and-method).

**Counters** (ZJIT stats, per iteration, master → branch). Each `objtostring` hit was a `to_s` send that became a
`CCallVariadic`. The branch's call is still counted as `Integer#to_s`, so the drop shows in `not_inlined_cfuncs`:

| | railsbench | lobsters | shipit |
| --- | ---: | ---: | ---: |
| `Integer#to_s` not inlined | 2,000 → 2,000 | 5,573 → 1,303 | 4,094 → 299 |
| `Module#to_s` not inlined | 0 | 22 → 0 | 10 → 0 |
| dynamic sends, side exits | unchanged | unchanged | unchanged |

railsbench's 2,000 are explicit `.to_s` calls, not interpolation.

**Allocations** (objects per iteration, `ruby_bench_allocs.rb`, median of each round, two rounds):

| | interpreter | ZJIT master | ZJIT branch | ZJIT extra over interpreter |
| --- | ---: | ---: | ---: | ---: |
| railsbench | 1,729,932 | 1,734,045 | 1,734,067 | 4,113 → 4,135 (noise ±200) |
| lobsters | 645,578 | 647,154 | 646,509 | **1,576 → 931** (−645, −0.10%) |
| shipit | 1,133,866 | 1,137,701 | 1,135,227 | **3,835 → 1,361** (−2,474, −0.22%) |

Only 0..9 and named modules avoid a string. Integers ≥ 10 allocate in the interpreter too, which is why
lobsters drops 645 objects for 4,270 sites.

**Callgrind, ZJIT, total Ir per iteration with GC (millions), A/A runs `a / b`:**

| | master | branch | branch − master |
| --- | ---: | ---: | ---: |
| railsbench | 4,931.4 / 4,935.2 | 4,935.0 / 4,924.9 | −0.07% (A/A 0.08% / 0.21%; nothing changes here) |
| lobsters | 3,265.9 / 3,265.8 | 3,270.2 / 3,268.1 | +0.10%, malloc layout (below) |
| shipit | 3,954.1 / 4,030.5 | 3,945.7 / 3,950.1 | a pair **−0.21%**; b unusable (A/A 1.9%) |

* shipit, a pair: GC functions (`gc_mark`, `gc_sweep_page`, …) −9.5 M of 393.8 M, everything else +1.1 M. The b
  pair is in different warmup phases (the shipit phase change noted in Z1), so it is not used.
* lobsters, b pair: the +2.3 M comes from glibc. `memcpy` from `_int_realloc` +2.05 M at identical `realloc` call counts
  (57,844 per window), and `memset` +1.0 M at identical call counts. That is the malloc heap layout of a
  different binary, not work the change executes. Without those two functions the branch is −0.02%. The
  saving it should show (645 objects, about 0.4 M with GC) is below what Callgrind can resolve here.

**Census apps** (`script/census run --stats` and `--aa --modes interp,zjit`, Rails main `b10c3acfe9`, per request):

| | Fizzy | Lobsters | Campfire |
| --- | ---: | ---: | ---: |
| `Integer#to_s` not inlined | 107 → 80 | 148 → 107 | 29 → 24 |
| `Module#to_s` not inlined | 4.6 → 4.6 | 0.55 → 0.36 | 1.07 → 1.01 |

ZJIT objects per request: 17 of 34 workloads fell by ≥ 1 (A/A: 5 of 34), median −0.7, largest −25 (a Lobsters
page). Interpreter controls did not move (median 0.0).

## Not covered: polymorphic Module sites

`"#{self} Update"` in `persistence.rb` sees a different model class (singleton class) per call, so its profile is
polymorphic and keeps `Send :to_s`. With two classes alternating, ZJIT still allocates 2 objects per call and the
interpreter 1. That is the `TODO(max): Handle polymorphic profiles` from #17499. A follow-up could call a
`vm_objtostring`-like helper that checks the method entry at run time. It is left for the issue discussion.
The census apps show 1–5 such calls per request.

## Hash#size (Shopify/ruby#808): left out

`Hash#size` is already a leaf `CCall` (`annotate!(rb_cHash, "size", types::Fixnum, no_gc, leaf, elidable)`).
ruby-bench calls it 2,000 / 972 / 1,984 times per iteration, so an `RHASH_SIZE` load saves at most a few tens of
thousands of instructions: about 0.001% of Ir, below the bar. #808 is also about the Bignum lie in `length`/`size`
return types, which is a separate fix.

## Comment draft for #1091 (not posted)

> We'd like to take this one if nobody is on it. Data from Rails apps: at a monomorphic site, ZJIT interpolates an
> Integer or a Module by sending `to_s`, which allocates. `vm_objtostring()` returns the shared frozen string for
> 0..9 or the module's name, so ZJIT allocates one string more than the interpreter. This can't go in
> `cruby_methods` like #19587, because `Integer#to_s` must stay mutable for ordinary calls. It fits at the
> `objtostring` site in HIR build: when the profiled Fixnum or Module still has the original `to_s` (same check
> as `check_cfunc`, with a `MethodRedefined` patch point), call `rb_fix_to_s` or a name helper.
>
> | per iteration, ZJIT | lobsters | shipit |
> | --- | ---: | ---: |
> | `to_s` sends at interpolation | 4,270 → 0 | 3,795 → 0 |
> | objects beyond the interpreter | 1,576 → 931 | 3,835 → 1,361 |
> | Ir (Callgrind, with GC) | within noise | −0.21%, all GC |
>
> Polymorphic Module sites (AR's `"#{self} Update"` across models) would stay as they are, per the TODO from
> #17499. If you already have this on a branch, say so and we'll drop ours.
