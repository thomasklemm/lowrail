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
optional positional. Review correction: `def m(x, ...)` does not have the `forwardable` flag. Prism gives it
ordinary rest/keyword/block locals instead of a saved callinfo; only bare `def m(...)` uses the optimized
forwardable frame (`prism_compile.c:6379–6390`). The outer zsuper can specialize safely for `(x, ...)`;
the callee's own splatted super stays dynamic. It does not need the new exclusion.

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

## Astra review, both Thermos rubrics (2026-11-25)

**Verdict: approve `2dc14101c3c62b4555e6efaa471ad5e63e5a6ac5`; no must-fix in the Ruby change.**
Reviewed independently of the author in [this thread](https://ampcode.com/threads/T-01a214a7-4022-7060-91cf-eacfc0be2f69).
Both correctness/security and maintainability rubrics were applied by one Astra reviewer, as requested, without
subagents or additional threads. This is not two independent review passes. Nothing was posted or pushed to Ruby.

The cause and commit message are accurate. The smallest safe fix is the one already present: convert the Hash
only when the resolved callee does not need the original callinfo. Keep the original arguments otherwise and
let the existing direct-call eligibility check select dynamic dispatch. No replacement callinfo or new helper
is needed. The one added comment explains the otherwise invisible frame contract; it is worth keeping.
The condition is local to the argument conversion, uses the same forwardable exclusion as neighboring call
rewrites, and introduces no new state or abstraction. Both Rust files already exceed 1,000 lines; this small
change does not justify splitting them. Ruby complexity metrics do not apply to this Rust change.

### Dispatch and frame checks

* **The mismatch is observable in HIR.** Without the fix, the `Top#m` direct call receives `a` and `k`, not
  `{k: k}`. With it, `InvokeSuper` retains the Hash and records complex argument passing. At threshold 1 the
  recompile repro reaches the forwardable refusal (197 executions in the stats run), rather than passing merely
  because it never compiles. `Top#m` has seven interpreter calls, as the author's record says.
* **Aliases and copied methods:** the super optimizer follows aliases before reading the target ISEQ's flags
  (`hir.rs:7456–7477`). Its invalidation dependency remains on the lookup entry. An aliased forwardable method
  and `define_method` from an unbound forwardable method both fail on base and pass with the fix.
* **Bmethods, refinements, missing methods:** keyword-super conversion is inside the ISEQ branch, not the
  bmethod branch. A Proc-defined method and a refined method entry retain dynamic dispatch; a missing super
  target falls back before conversion, allowing `method_missing`. These three cases matched the interpreter
  both before and after the fix. A copied Method/UnboundMethod that remains an ISEQ is covered by the flag check.
* **Changing targets:** specialized non-forwardable targets keep the existing method-entry patchpoint and
  current-method-entry guard (`hir.rs:7315–7353`). Compilation and invalidation use the VM lock. Redefinition,
  alias replacement and prepend from inside `Top#m`, plus replacement while it is suspended in a Fiber, all
  pass with the fix; each fails on base after the new forwardable target becomes hot. Removing the intermediate
  method also passes. The mutation stats confirm a method invalidation, not just an uncompiled control.
* **Polymorphism and recompilation:** the super profile supplies a current method entry only when monomorphic
  (`profile.rs:634–642`); a different live entry is guarded, and a polymorphic profile is refused. One shared
  module method used above both a regular target and a forwardable target matches the interpreter with the fix.
  A new compilation runs the same exclusion; there is no first-version-only condition.
* **Non-forwardable callees do not consume this incoming callinfo.** `gen_send_iseq_direct` passes `forwarded_ci`
  only in its `forwarding` arm (`codegen.rs:2455–2470` on the reviewed commit). Otherwise it passes planned locals,
  keyword bits and the block handler. `*`, `**`, `&`, anonymous forwarding, and `(x, ...)` read those locals and
  construct their own outgoing arguments. The `ruby2_keywords` and `**nil` refusals remain intact. Probes cover
  these forms, positional Hash conversion, keyword defaults and errors. Both `super` and `other(...)` in a bare
  forwardable callee are protected; the latter is not a separate hole.

### Builds, negative controls and limitations

Built on x86-64 Linux with GCC 14.2.0, Rust 1.100.0, baseruby 4.0.9 and cargo-nextest 0.9.152:
`./autogen.sh`, `./configure --enable-zjit=dev --enable-yjit --disable-install-doc`, `make -j2`.
Each base control keeps the two new tests but removes the implementation fix. The headline3 check used
`git cherry-pick --no-commit 2dc14101c3` on `e0fc4df7caa482a4b58c87123af8a3f643d8a109`, without conflict.
The patched files are byte-identical to the headline2 fix; the resulting tree is
`4659b7ba940cfadc93efed4c1411ca6a0668f394`. No Ruby commit was created by this review.

`make zjit-test CARGO=cargo ZJIT_TEST_FEATURES=disasm ZJIT_TESTS='-j 2'`:

| Build | Passed | Failed | Skipped by default |
| --- | ---: | ---: | ---: |
| headline2 base + new tests | 2,349 | 3 | 15 |
| headline2 fixed | 2,351 | 1 | 15 |
| headline3 base + new tests | 2,349 | 3 | 15 |
| headline3 fixed | 2,351 | 1 | 15 |

**The full suite was not green here.** All four runs fail
`test_profile_frames_during_direct_jit_to_jit_entry`: `rb_profile_frames was not called from SIGPROF handler`,
followed by abort on the Rust panic across the callback boundary. The unchanged base reproduces it; it is not
introduced by this fix. The other two failures on each base are exactly the new regression tests, with
`no implicit conversion of Integer into Hash`. No failure was suppressed or rerun until green.

On each fixed build, the CLI suite passes (35 tests, 8,346 assertions), and `test_keyword.rb` + `test_super.rb`
pass with ZJIT explicitly enabled at thresholds 1 and 2 (166 tests, 3,060 assertions each). After restoring the
final mutation experiment, the headline3 super-filtered Rust run passes all 90 tests.

The differential harness runs 27 adversarial shapes plus the three recorded repros (basic, threshold-1
recompile, insert chain), each in interpreter, YJIT, default ZJIT, ZJIT threshold 1 and threshold 2 modes.
**All 150 runs pass on each fixed build.** Each base has the same 51 failing runs; the other 99 match the
interpreter. Checks assert expected values and compare output, including exception class and message.
Additional shapes include zero positional arguments, two keywords, nil/false/Array/Hash keyword values,
frozen values and receiver, and a block added after no-block warmup. The scripts add no implicit-conversion
callbacks; the transformed operand is a compiler-created Hash, not a caller-supplied object to coerce.

Mutation checks show what the tests discriminate:

* Checking the caller's `frame_state_iseq` instead of the callee's `super_iseq` fails both new tests.
* Disabling all static keyword-super conversions passes the two new behavior tests but fails the existing
  `test_zsuper_with_keyword_params_optimizes`. The new tests are regression tests, not a guarantee that unrelated
  specialization remains enabled; the existing optimization test supplies that control.

**Findings and smallest fixes:** no Ruby-code finding. Corrected the `(x, ...)` explanation above, and recorded
the reproducible baseline sampling-test failure rather than repeating the author's all-green suite result.
No app suites, arm64 execution, Ractor scheduling experiment or performance measurements were run in this pass;
the insert script is a model, not a Discourse/CASA test. The pass covers the two named headline pins, not other
branches or a future Ruby head.

Raw logs, HIR/stats, source diffs, all probe sources, per-mode outcomes and reproduction commands are retained in
[`zsuper-forwardable-astra-2026-11-25.tar.gz`](../../bench/upstream/ruby-differential/evidence/zsuper-forwardable-astra-2026-11-25.tar.gz).
