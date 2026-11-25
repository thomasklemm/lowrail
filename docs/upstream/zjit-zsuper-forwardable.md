# ZJIT: zsuper with keyword parameters into a `(...)` method (Shopify/ruby#1133)

Stand: 2026-11-25. Fix on the fork branch
[thomasklemm/ruby `zjit-zsuper-forwardable`](https://github.com/thomasklemm/ruby/tree/zjit-zsuper-forwardable), commit
[`2dc14101c3`](https://github.com/thomasklemm/ruby/commit/2dc14101c3c62b4555e6efaa471ad5e63e5a6ac5) on k0kubun/ruby
`zjit-headline2` `f2c3f457ff`. Nothing was posted on the issue and no PR opened (DECISIONS, Pull requests).

## Cause

[58b019f6fe](https://github.com/k0kubun/ruby/commit/58b019f6fe) ("ZJIT: Specialize zsuper from methods with keyword
parameters") turns the zsuper's `newhash :k, k` + `invokesuper ZSUPER|KW_SPLAT|KW_SPLAT_MUT` into a direct send with
explicit keywords: it replaces the Hash operand with the keyword values and plans the call with a synthetic
`CallerArguments` that says `KWARG`. A forwardable callee (`def m(...)`) doesn't use the planned parameters, though:
`can_direct_send` returns early for it, and `gen_send_iseq_direct` copies the argument operands onto the callee frame
and passes the call site's own callinfo (`cd->ci`) as the `...` local. That callinfo still says `KW_SPLAT` with
argc 2 (`a`, Hash), but the slots now hold `a` and the value of `k`. The callee's `super`/`(...)` then reads the value
of `k` as the keyword Hash: `no implicit conversion of Integer into Hash` (`Array` in Rails, where the value is
`returning:`). Before 58b019f6fe (`2d609d397d`), `KW_SPLAT` made the whole zsuper unspecializable, so it went through
the dynamic `invokesuper`, which the interpreter handles via `vm_call_iseq_forwardable` with the right callinfo.

## Fix

Keep the Hash for a forwardable callee; `can_direct_send` then refuses the `KW_SPLAT` call
(`complex_arg_pass_param_forwardable`), as before 58b019f6fe, and the zsuper stays dynamic:

```diff
-                            let caller_args = if let Some(pairs) = &static_kw_splat {
+                            // A forwardable callee takes the zsuper's callinfo as is, which has the Hash.
+                            let caller_args = if let Some(pairs) = static_kw_splat.as_ref().filter(|_| unsafe { super_iseq.params() }.flags.forwardable() == 0) {
```

Handling it correctly instead (a new callinfo with `KWARG` for the `...` local) would need a new imemo callinfo per
site; not worth it for a first fix, and the dynamic path is what headline2's parent did.

## Why threshold 1 is affected too

With `--zjit-call-threshold=1` the first compile has no profile (`rb_zjit_profile_threshold = 0`), so the zsuper has no
profiled super CME and stays dynamic (`SuperNoProfiles`); that is why the standalone repro prints ok. But when a
guard in the method fails and the version is invalidated, the ISEQ runs its profiling window in the interpreter before
the next compile, and the second version has a super profile and specializes the zsuper. Apps hit that (CASA: 2,271
of 2,992 at threshold 1). Repro (`.amp/in/orb-backup/t1_recompile.rb` in this orb, same as the second new test): `Top#m` does `a + 1` before `super`, one call with
`1.5` misses the guard; at threshold 1 headline2 raises, the fix prints ok (`Top#m` interpreter calls: 7).

## Other shapes the commit converts

All match the interpreter on headline2 at threshold 2 without the fix, and at thresholds 2 and 1 with it, except the `(...)` callees
(direct and through a prepended module), which fail without it. Checked: `(x, ...)` callee, anonymous `**` and `*` in
the caller, `&`/`&b` and a block, `ruby2_keywords` callee and middle method, positional Hash and `*rest` callees,
`**nil` callee (ArgumentError as expected), kwrest callee, bmethod, unknown keyword and too-many-arguments errors,
optional positional. The `def m(x, ...)` callee passed even without the fix; why it isn't specialized was not traced,
and the fix covers it either way (it checks the forwardable flag).

## Tests and results (2026-11-25, orb)

* New Rust tests in `zjit/src/codegen_tests.rs` (`test/ruby/test_zjit.rb` was ported to the Rust harness in
  `3beab86629`; `test_zjit_cli.rb` is what remains): `test_zsuper_with_keyword_params_to_forwardable`
  (`assert_compiles`, threshold 2) and `..._to_forwardable_after_recompile` (threshold 1, one guard miss, then 100
  calls). **Both fail without the fix** (Ruby exception in the callback) and pass with it.
* `make zjit-test` (feature `disasm`): 2,352 passed, 0 failed.
* `make test-all TESTS=test/ruby/test_zjit_cli.rb`: 35 tests, 0 failures.
* `test_keyword.rb` + `test_super.rb` with `--zjit-call-threshold=2` and `=1`: 166 tests, 3,060 assertions, 0 failures
  each.
* Repro `bench/upstream/ruby-differential/repros/zsuper_kw_fwd.rb`, five modes (interp, `--yjit`, `--zjit`, threshold
  1, threshold 2): headline2 fails `--zjit` and threshold 2; with the fix all ok.
* Model of Rails main's PostgreSQL `insert(…, returning:)` → `QueryCache#insert(...)` → abstract `insert` chain: without
  the fix `QueryCache#insert: no implicit conversion of Array into Hash` at `--zjit` and threshold 2 (the Discourse
  error); with it ok in all five modes.
* Not run here: Discourse and CASA specs (the app copies, Postgres template and Rubies live in the differential orb of
  T-01a2142b-3470-7519-bbb3-d6a3972a9cfd). The CASA threshold-1 check
  (`spec/callbacks/case_contact_metadata_callback_spec.rb`, 15 of 16 failing on headline2) is still open.

## headline3

58b019f6fe is in `zjit-headline3` as `c3c92dd544` with the same line, so headline3 needs the same fix, and it applies
unchanged: the commit cherry-picks cleanly onto `e0fc4df7ca` (local `a46f4b055a`, not pushed). On a headline3 build,
the repro, the threshold-1 recompile repro and the insert-chain model fail without it, as on headline2, and pass in
all five modes with it; the 90 `super` Rust tests pass, the two new ones included. zjit-sfr-exp/* was not checked.
