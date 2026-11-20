---
id: OTS1
repo: ruby/ruby
kind: perf
area: ZJIT, objtostring guards
reviewer: "thermos-sol approves -3; precedent k0kubun's #19603 (coerce_to guards recompile)"
branch: thomasklemm/zjit-objtostring-recompile-3
head: "f431e8a74c"
base: master
built_on: "21ee43fb1e"
depends_on: []
stacked_on:
alternative_of:
impact: "removes a permanent side exit: a String-profiled interpolation that also sees a Symbol exits on every such call; lobsters guard_type_failure 677 -> 139 per iteration (content_tag_string), side exits 10,167 -> 9,629 (two runs each on -2); the recompiled version keeps FixnumToString and rb_mod_name for profiled Integers and Modules, so none of the default-config probe modes allocates more than master (diagnostic Callgrind slopes -1.6% to -3.5% on String-led mixes, the rest within A/A); run_benchmarks.rb within A/A on the old head"
rank: 3
risky: false
state: ready
pr: 19982
note: "2026-11-20 thermos-sol approves whole PR on f431e8a74c including rebase, no code must-fix. Reply snapshot clause corrected locally to block/instruction IDs only. Full zjit-test twice: 2016 pass, one SIGPROF failure; clean base reproduces it (2014 pass, one failure), isolated head 0/3 on this orb. btest t1/t2 2148 each, objtostring 18/18, base negative controls and seven-configuration differential pass; details below. Still needs thermos-opus on this head and Thomas's corrected-reply OK. 2026-11-20 fix round -3 (answers tekknolagi's discussion_r4635641256): fork branch thomasklemm/zjit-objtostring-recompile-3 @ f431e8a74c = the -2 commit rebased unchanged onto master 21ee43fb1e (522a37c28c) plus one commit that skips String buckets before creating an arm block; snapshot IDs only. Builder's zjit-test 2016/2017 (only the known SIGPROF flake, passes alone 3/3), btest t1/t2 2148 each. The PR still points at 6a3dc53c87: not pushed to the PR branch, no reply posted, body unchanged. 2026-11-19 21:56 UTC: tekknolagi inline review on hir.rs:11231 (discussion_r4635641256): \"seems this should skip the `is_string` cases, no?\" In the polymorphic arms a String bucket reaches try_objtostring_cfunc, which returns None, so its arm block is left unused; the String case is already handled by the first CondBranchHasType. Fix round started 2026-11-20 on branch -3. 2026-11-18 (post-inline_block check on master 825d71e673, which force-inlines Primitive.inline_block methods): scratch merge of head into 825d71e673, --enable-zjit=dev, not pushed. make zjit-test 2015/2016, the one failure test_profile_frames_during_direct_jit_to_jit_entry (SIGPROF, also fails in the full master run here, 2013/2014); btest --zjit-call-threshold=1 2148/2148. No test or snapshot moved. Still merges clean (git merge-tree) with master a4beace140 (vm_eval.c only, not rebuilt). No rebuild needed; branch untouched, nothing posted. 2026-11-18 15:10 UTC: Thomas marked the PR ready for review. 2026-11-18 (opened, Thomas approved a draft after a green review): ruby/ruby#19982 as a draft at 6a3dc53c87 after the thermos-sol approve (17a88daf). 2026-11-18 (Thomas): open as a ruby/ruby draft once the thermos-sol review on the head approves. 2026-11-18 thermos-sol approves exact head 6a3dc53c87: both rubrics applied directly by one reviewer, including a fresh design check; no must-fix. Independently passed zjit-test 2,016/2,016 and btest t1/t2 2,148 each, reproduced both base failures and the old-head conversion loss, and reran release costs with the pinned tool and A/A. The previous changes verdict on 2cc3e0de4d is superseded for -2, not erased. Module conversion still declines in a final version; see the review's explicit allocation boundary. The permanent-exit exception waives the timing-evidence gate only. Not opened; no fork push or upstream post."
passes:
  - {reviewer: thermos-sol, orb: T-01a1ee95-733f-70d2-80da-ed3434c4e36b, head: "2cc3e0de4d", date: 2026-11-18, verdict: changes, open: "P2: mixed Integer/Module interpolation loses specialized conversions after recompile (release allocation regression); narrow the change or preserve those conversions. Body and commit message overgeneralize frozen strings; cut that clause. Remove body pins/setup and unqualified two-runs claim. No semantic divergence found; both rubrics applied directly by one reviewer, as requested."}
  - {reviewer: thermos-sol, orb: T-01a1eecc-1498-73e9-88f9-20ed54fd2455, head: "6a3dc53c87", date: 2026-11-18, verdict: approve, open: "No must-fix. Both Thermos rubrics applied directly, including the fresh polymorphic-arm design check. Exact-head tests and negative controls executed; release allocations/slopes rerun with pinned Callgrind totals and A/A; body, message, guards, comments and identity checked. Final-version Module fallback remains an explicit limitation, not a universal allocation-parity claim."}
  - {reviewer: thermos-sol, orb: T-01a1f995-3889-767b-a2bf-4ea3525b61d2, head: "f431e8a74c", date: 2026-11-20, verdict: approve, open: "No code must-fix on the whole rebased PR. Both rubrics applied directly without delegation. Corrected the reply's snapshot clause locally: only block/instruction IDs change; the unreachable String block was never printed. Two full zjit-test runs: 2016 passed, one SIGPROF failure, 15 skipped; clean exact base reproduces it (2014 passed, one failed), isolated head 0/3. btest t1/t2 2148 each; restored-head objtostring tests 18/18; both new tests fail on base production. Interpreter/base/head differential probes match in seven configurations. Needs the same-head thermos-opus pass and Thomas's reply approval; nothing posted or pushed to Ruby."}
---

# ZJIT: Recompile when an objtostring String guard fails

When `objtostring` has only seen Strings, ZJIT guards that the value is a String. That guard didn't recompile, so any other value side-exited on every call for as long as that version stayed. It now recompiles, like `coerce_to`'s since #19603.

The recompiled version takes the polymorphic path, which sent `#to_s` for everything that isn't a String. It now keeps the monomorphic path's Integer and Module conversions for the types the profile saw, because `#to_s` allocates a new string where `rb_fix_to_s()` shares one for 0..9 and `rb_mod_name()` returns a named module's name. The Integer and Module guards are unchanged.

On lobsters, Action View's `TagBuilder#content_tag_string` interpolates a tag name that is a String in most calls and a Symbol in about one in six:

```diff
-exit_guard_type_failure:      677
+exit_guard_type_failure:      139
-side_exit_count:           10,167
+side_exit_count:            9,629
```

(ZJIT stats per lobsters iteration.)

## For Thomas

### Fix round -3, 2026-11-20 (tekknolagi's inline comment)

tekknolagi on [hir.rs:11231](https://github.com/ruby/ruby/pull/19982#discussion_r4635641256), 2026-11-19: "seems
this should skip the `is_string` cases, no?" He is right. The first `CondBranchHasType v, String` already sends
every String to the String block, including subclasses: a String subclass profiles as `StringSubclass` bits with a
`TypeExact` class, which is inside `types::String`. `polymorphic_arms` groups buckets by bit-equal `Type`, and that
type comes from the bucket's class, so all buckets of an arm agree on `is_string()`. A String arm therefore never
runs; before the fix it created a block and a `RefineType`, then `try_objtostring_cfunc` returned `None` and the
block stayed unreachable.

Branch [`thomasklemm/zjit-objtostring-recompile-3`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-objtostring-recompile-3)
@ [`f431e8a74c`](https://github.com/thomasklemm/ruby/commit/f431e8a74c0a2d9910115a485b42d8651a81c405), two commits on
master `21ee43fb1e` (its tip on 2026-11-20): [`522a37c28c`](https://github.com/thomasklemm/ruby/commit/522a37c28c6725ab2633fe21392e7bbde63630d5)
is `6a3dc53c87` rebased unchanged (`git range-diff` reports `=`, clean `merge-tree`, same message), and
`f431e8a74c` "ZJIT: Skip String arms in polymorphic objtostring" adds the fix. A separate commit lets him review
the answer on its own; squash it if he prefers. Both made with `/usr/bin/git commit-tree`, Thomas Klemm as author
and committer, no trailers. The -2 branch is untouched.

```diff
                             for (expected, buckets) in polymorphic_arms(&summary) {
+                                if buckets[0].is_string() {
+                                    continue;
+                                }
                                 let arm_block = fun.new_block(insn_idx);
```

Tests: no new test. The two snapshots of the PR's own tests change only block and instruction IDs because the
unreachable String block and its `RefineType` are no longer allocated; no printed block disappears. A refused
non-String arm (the Symbol bucket in `test_objtostring_guard_failure_recompiles`) still leaves an unreachable block;
he didn't ask about that, and avoiding it would duplicate the helper's eligibility checks (see the -2 review).

`--enable-zjit=dev --disable-yjit --without-jemalloc`, exact head: `make zjit-test` 2,016 passed, 1 failed, 15
skipped, twice; the failure both times is `test_profile_frames_during_direct_jit_to_jit_entry` ("rb_profile_frames
was not called from SIGPROF handler"), which passes alone three times out of three and failed the same way in
master's full run here on 2026-11-18. `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: 2,148 passed
each. No new measurement: the change only removes a block that was never reachable.

The body stays accurate. Nothing pushed to the PR branch and nothing posted.

Reply draft for his comment:

> Yes, thanks. The String branch before the arms already takes every String, subclasses included, so a String
> arm could never run and its block was left unused. f431e8a skips String buckets before creating an arm block;
> the two snapshots only change block and instruction IDs. I also rebased onto master.

### thermos-sol review of -3, 2026-11-20

Verdict: **approve**, no code must-fix, on exact head
[`f431e8a74c0a2d9910115a485b42d8651a81c405`](https://github.com/thomasklemm/ruby/commit/f431e8a74c0a2d9910115a485b42d8651a81c405),
two commits on `21ee43fb1ea46e168a148b174ca1ce95c080e7cf`. This reviewer loaded Thermos and applied both its
correctness/security and maintainability rubrics directly, without subagents or other threads, as requested.
This pass covers the whole PR, its rebase, both commit messages, the body and the reply draft. It does not replace
the requested same-head thermos-opus pass or Thomas's approval of the reply. Only this Lowrail record was edited.

**Rebase and scope.** `git range-diff 6a3dc53c87^..6a3dc53c87 21ee43fb1e..522a37c28c` reports `=`.
`git merge-tree --write-tree 21ee43fb1e 6a3dc53c87` succeeds and gives exactly `522a37c28c^{tree}`
(`88d8189d2e9540596d74f9ba7f5ba267b75c0319`). The whole candidate is two Rust files, +169/−4; production is
+22/−2. Inspected the intervening ZJIT payload/codegen cache change and forced `Primitive.inline_block` annotations,
the latter's snapshot changes, and the adjacent VM method/call changes. The objtostring helper, profile/type
contracts, recompile path and dispatch code have not changed underneath the rebased patch. Fresh execution below
exercises the new master's forced Array#map/each inlining with objtostring guards and arms inside compiled owners.

**Correctness and surviving guards.** Cold read: use a String unchanged; otherwise try each profiled non-String
type for which the existing helper can convert directly; send `to_s` for the rest; merge the result. Only a failed
monomorphic String guard now requests recompilation. The [dispatch](https://github.com/thomasklemm/ruby/blob/f431e8a74c0a2d9910115a485b42d8651a81c405/zjit/src/hir.rs#L11201-L11260)
keeps the original pre-instruction exit state: no user conversion has run before its patchpoints or the Module
name guard. `side_exit_with_recompile` identifies the compiled owner even for an inline frame; `exit_recompile`
observes its exit/version budgets and invalidation re-stubs incoming calls and re-enables profiling. No new
profiling state, instruction, invalidation mechanism or unbounded retry policy is introduced.

* The monomorphic String guard protects direct interpolation and retains its existing no-singleton patchpoint.
  The polymorphic String branch tests `T_STRING`, not exact String class, matching `vm_objtostring`'s bypass of `to_s`.
* Each conversion arm's type branch dominates its `RefineType`. `polymorphic_arms` creates nonempty groups of
  bit-equal `Type::from_profiled_type` values; those distinguish class and immediate/heap representation, not shape.
  Thus `buckets[0]` is sufficient for both the new skip and the existing shape-independent conversion helper.
  `ProfiledType::is_string` includes subclasses; their `StringSubclass` bits plus `TypeExact` class remain inside
  `types::String`. Non-Module singleton profiles go to `other`, not an unsafe arm.
* The unchanged helper checks the original C function and emits its existing `NoSingletonClass`, `NoTracePoint`
  and `MethodRedefined` patchpoints. Fixnums cannot gain singleton classes. Redefined/refined methods and singleton
  overrides still use invalidation/send paths; String overrides are intentionally bypassed as in the interpreter.
* The Module/Class arm still refuses a final-version conversion and guards the name's String result, because
  anonymous modules may have no name and must use `to_s`/`inspect`. Empty and both megamorphic profile kinds retain
  the generic non-String send. The Integer/Module monomorphic receiver guards are byte-unchanged against base.

**Maintainability.** L1 for the whole PR: a bounded extension of the existing objtostring owner using canonical
dispatch and conversion machinery, no new helper/type/state or copied conversion eligibility checks. Both files
already exceed 1,000 lines; neither crosses that boundary. The new `continue` removes known-useless construction
at the right layer. Moving it into the conversion helper would be too late; a general dispatch abstraction would
obscure the different snapshot/profile contracts of sends and these direct conversions. No obvious simplification
justifies a broader refactor. Other refused candidates leave bounded unreachable blocks, ignored by RPO-based
inference/cleanup/lowering; removing those would split or duplicate the helper's contract. No production comment
was added. The test phase comments distinguish profiling, compilation and invalidation calls in the surrounding
test idiom; snapshot fallback annotations are generated output. No comment or guard needs removal.

**Executed verification, x86_64 Linux.** Fresh build with `--enable-zjit=dev --disable-yjit --disable-install-doc
--without-jemalloc`, GCC 14.2.0, Rust 1.100.0, bootstrap Ruby 4.0.9, cargo-nextest 0.9.152.

* `make zjit-test RUN_OPTS='--zjit --zjit-call-threshold=1'`, then `=2`: each **2,016 passed, one failed, 15 skipped**.
  `RUN_OPTS` does not configure Rust tests: their harness sets threshold 2 itself and tests may override it.
  Both commands were executed, but they are two full suite runs, not two Rust threshold configurations.
* The only failure is `test_profile_frames_during_direct_jit_to_jit_entry` at `codegen_tests.rs:7619`,
  `rb_profile_frames was not called from SIGPROF handler`. Three fixed isolated head runs also fail (0/3), unlike
  the builder's 3/3 on its orb. A clean checkout/build of exact base `21ee43fb1e` reproduces the identical failure
  in the full suite: **2,014 passed, one failed, 15 skipped**. This is a verified base failure, not a green suite
  or a newly demonstrated regression. Its timing/signal root cause was not established here.
* `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: **PASS all 2148 tests** each, on exact head.
* Keeping the candidate tests but using exact base production makes both new tests fail at expected 2 / actual 1
  versions (`opt_tests.rs:10457` and `:10535`). After restoring/rebuilding exact head,
  `make zjit-test ZJIT_TESTS=test_objtostring`: **18 passed**. Fork source is clean and restored to the reviewed SHA.
* The committed 227-row `ots1_2_diff_probe.rb` and a separate 129-row focused probe match interpreter/base/head in
  seven configurations: thresholds 1, 2, 30; threshold 2 with max-versions 1; threshold 2 with max-versions 2 / exit
  budget 1; threshold 2 without inlining; threshold 60 with 40 profiles. The focused cases cover String subclasses
  with raising `to_s`, distinct shapes and singleton overrides, binary/frozen strings, Integer boundaries/Bignum,
  Module subclasses, named/anonymous modules/classes, private and non-String/String-subclass conversion results,
  exceptions, core-method redefinition/restoration, singleton creation/removal, GC compaction and suspended fibers.
  Optimized HIR dumps with threshold 2 / exit budget 1 show `FixnumToString` and `rb_mod_name` arms, including inside
  inlined owners, so this is not only fallback coverage. The original exit probe gives base 10,000 type exits /
  two new compiles versus head 6 exits / three new compiles at threshold 2, with identical output.
* Repeated the existing eight allocation probe modes at N=60,000 on base/head dev binaries: 120,014 objects in
  each non-custom mode and 140,014 for custom, with zero compiles/invalidation time/ZJIT-allocation deltas in each
  measured region. The documented worst boundary remains: head String/Module with max-versions 2 allocates 140,014
  and sends 20,000 times, versus 120,014 / zero sends on base and default head. Values still agree. No new release
  instruction-count, native-speed or app benchmark is claimed; ARM64 and app suites were not run.

**Reply draft, sentence by sentence.** “Yes, thanks” acknowledges a concrete correct review observation. The first
technical sentence is accurate: the String branch covers subclasses and the attempted String conversion returned
`None`, leaving an unconnected block. The first clause of the next sentence is accurate: `f431e8a` skips whole
String groups before `new_block`. Its original “the two snapshots only lose that block” clause was imprecise:
the unreachable block was never printed. Extracting both affected test bodies at `522a37c28c` and `f431e8a74c`,
then normalizing only `bb[0-9]+` and `v[0-9]+`, makes them byte-identical. The first test still prints 12 blocks
across its two snapshots and the second 11. Corrected that clause above to “the two snapshots only change block
and instruction IDs,” and corrected the supporting explanation. “I also rebased onto master” is verified by the
range-diff/merge-tree and exact parent above. The corrected draft is accurate; it remains unposted for Thomas.

**Body, messages and upstream context.** Checked the PR discussion only after the code audit: the sole inline
comment is tekknolagi's stated String question, with no additional review finding. Live PR head is still
`6a3dc53c87` on the -2 branch and its body matches this item's upstream body. The title and first three sentences
match the base/head guard, negative controls and merged [coerce_to precedent](https://github.com/ruby/ruby/pull/19603).
The conversion sentences match `try_objtostring_cfunc`, `vm_objtostring` and `numeric.c:4106` (shared Fixnum strings
only for 0..9); the Integer/Module guards are unchanged. The Lobsters sentence is supported by the saved trace
and class file (2,500 Strings, 538 Symbols). Recomputed the saved two base and two -2 runs: type exits 677.2 → 139.2,
total exits 10,166.3–10,166.7 → 9,628.8–9,628.9 per iteration, supporting every displayed number and its label.
These remain historical -2 measurements, not fresh app measurements on the new base. Both commit messages agree
with the code and that evidence; both commits have Thomas as author/committer and empty trailers. The permanent-exit
exception remains applicable to the timing-evidence gate only. No Ruby branch push, body edit, review or comment
was made; the pending Opus pass and Thomas's corrected-reply approval remain separate gates.

### Rebuild -2, 2026-11-18

Branch [`thomasklemm/zjit-objtostring-recompile-2`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-objtostring-recompile-2)
@ [`6a3dc53c87`](https://github.com/thomasklemm/ruby/commit/6a3dc53c874f5b9df4f6d6a2fe2fe091b5aab7cb), one commit on
master `9de06831e3` (still the tip of ruby/ruby master at build time), Thomas Klemm as author and committer, no
trailers, made with `/usr/bin/git commit-tree`. 2 files, +166/−4, production +18/−2 in `zjit/src/hir.rs`
([ots1-2.diff](../../zjit-stats/ots1-2.diff)). The old branch and `2cc3e0de4d` are untouched. Not opened, nothing posted.

**What changed against `2cc3e0de4d`.** Only the String guard recompiles; the Integer, Module and other-class guards
are back to master. The polymorphic `objtostring` path (no monomorphic profile) used to branch on String and send
`#to_s` for everything else. It now first branches on each profiled type for which `try_objtostring_cfunc` applies
(`polymorphic_summary` + `polymorphic_arms`, the same helpers `send`/`opt_send_without_block` use for their
polymorphic dispatch), and that arm gets the monomorphic path's `FixnumToString` or `rb_mod_name` conversion with
its existing patchpoints. Everything else still falls to the `#to_s` send. Described out loud: "If it is a String,
use it. Otherwise, for each type the profile saw that the monomorphic path converts without a send, check for that
type and convert it the same way. Anything else sends `to_s`."

**How #19603 and ZJIT handle polymorphic profiles.** #19603 only switched `coerce_to`'s guard to
`guard_type_recompile` (plus making `newrange` recompile); it relies on the next version taking whatever path the
new profile selects. For `objtostring` that path was a generic send (the `TODO(max): Handle polymorphic profiles`
case), which is exactly what lost the conversions. Sends already dispatch polymorphic receivers with
`CondBranchHasType` arms per profiled type and a generic fallback; this patch applies that shape to `objtostring`'s
non-String side only. Megamorphic profiles (more than 8 types) still send `#to_s` for every non-String, which is
why the Integer and Module guards are kept as they are: recompiling them would trade master's conversion for sends
on such sites.

**Guards and comments.** No guard policy or guard type is widened. Surviving changed guard: the String guard
(protects direct concatenation; now `guard_type_recompile`, the file's idiom). The new dispatch arms are branches; each arm's
conversion keeps the existing original-C-function check, no-singleton patchpoint and method-redefined patchpoint
from `try_objtostring_cfunc`, and the Module arm keeps its final-version refusal and String-result guard. The
Fixnum/Module `GuardType` that `try_objtostring_cfunc` emits is removed as redundant after the arm's `RefineType`
(visible in the snapshot). No production comment added. An arm block whose conversion is refused stays unreachable
and is dropped from the RPO; a reviewer may prefer creating it only after the check. Readability: L1 (17 new lines
in an existing branch, no new helper, type or state).

**Tests.** `test_objtostring_guard_failure_recompiles` (same logic as the old head, snapshot IDs updated: String
warmup, then Symbols, expects version 2 with the polymorphic path) and new `test_objtostring_guard_failure_keeps_fixnum_to_string`
(String warmup, then small Integers; expects version 2 with `CondBranchHasType v10, Fixnum` and `FixnumToString`
before the `to_s` fallback). Two existing String snapshots gain `recompile`; the five Integer/Module/Array snapshot
changes of the old head are gone.

* Fail without the fix: with production `hir.rs` from `2cc3e0de4d`, the new test fails at the snapshot (version 2
  has `Send :to_s` where it expects `FixnumToString`); the old test's version-count assertion passes, but its -2
  snapshot also fails because refused arm blocks changed the instruction and block IDs. With master's `hir.rs`,
  both fail at the version count (`left: 2, right: 1`, `opt_tests.rs:10419` and `:10497`).
* `--enable-zjit=dev`, `make zjit-test`: **2,016 passed**, 15 skipped (the profiler-signal test passed this time).
  `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: **2,148 passed** each.
* Differential ([ots1_2_diff_probe.rb](../../zjit-stats/ots1_2_diff_probe.rb), 227 rows: four sites warmed on
  String, Integer, Module and Symbol, then 16 value kinds including 0/9/10/−1/Bignum, anonymous module and class,
  String subclass, binary String, singleton `to_s` on a named module, `Integer#to_s` and `Module#to_s` redefined and
  restored after compile; compares value, encoding, frozenness and class): release master and -2 match the
  interpreter at thresholds 1, 2, 30, threshold 2 with exit budget 1, with max-versions 2, and with
  inline-threshold 0. `--zjit-dump-hir-opt` confirms the Fixnum and Class arms compile in the mixed sites.

**Reviewer's reproducer, repeated.** Release builds `--enable-zjit --disable-yjit --disable-install-doc
--without-jemalloc` in one build dir with only `zjit/src/hir.rs` swapped; GCC 14.2.0, Rust 1.100.0. Probe
[ots1_review_cost.rb](../../zjit-stats/ots1_review_cost.rb) with two added modes (`string_integer`,
`string_module`). Allocations at N=600,000 on core 1; Callgrind from the pinned `script/bench-valgrind` tool (3.19.0
+ brk patch, tool sha256 `257b28c0…`), Ir from the `totals:` line, slope = N=10,000 minus N=1,000, core 0. Old head
= `2cc3e0de4d`, narrow = only the String guard recompiles (no arms), new = `6a3dc53c87`, all guards + arms =
`2cc3e0de4d` plus the arms (not pushed). Raw: [ots1-2-cost.json](../../zjit-stats/raw/ots1-2-cost.json).

| Input cycle | Allocations: base / old head / narrow / new | Slope vs base, round 1: old head / narrow / new | Round 2: new / all guards + arms |
| --- | ---: | ---: | ---: |
| String only | 1,200,014 / 1,200,014 / 1,200,014 / 1,200,014 | −0.53% / −0.48% / −0.46% | −0.39% / −0.25% |
| Five Strings, one Symbol | 1,200,014 / 1,200,014 / 1,200,014 / 1,200,014 | −1.03% / −2.11% / −1.59% | −2.01% / −0.80% |
| Five small Integers, one Symbol | 1,200,014 / 2,200,014 / 1,200,014 / 1,200,014 | +40.03% / +0.24% / +0.37% | −0.36% / −1.73% |
| Five small Integers, one String | 1,200,014 / 2,200,014 / 1,200,014 / 1,200,014 | +34.93% / −0.41% / −0.80% | −0.09% / −3.08% |
| Five named classes, one Symbol | 1,200,014 / 2,200,014 / 1,200,014 / 1,200,014 | +13.91% / +1.07% / +1.20% | +0.03% / −23.17% |
| Five Strings, one small Integer | 1,200,014 / 1,400,014 / 1,400,014 / 1,200,014 | +4.74% / +5.02% / −2.83% | −3.54% / −3.79% |
| Five Strings, one named class | 1,200,014 / 1,400,014 / 1,400,014 / 1,200,014 | +3.04% / +3.72% / −2.95% | −2.70% / −2.72% |

A/A: base round 2 vs round 1 −0.41% to +0.69%; new round 2 vs round 1 −0.59% to +0.30%. Compiles in every
measured region: 0. Exits on -2 are master's for the Integer- and Module-led cycles (100,000 / 500,000: their guards
still don't recompile) and 0 for the String-led ones; -2 makes no dynamic sends except the 200,000 Symbol `to_s` in
the String/Symbol cycle. The narrow variant (the first suggestion in the review) still adds 200,000 objects and
+3.7–5.0% slope on String-led cycles that see an Integer or a named class, which is why the arms are needed.
Diagnostic micros: default heap, GC on, no isolation; not admitted prices or lobsters speed estimates; native
times not claimed.

**Lobsters ZJIT stats** (release master and -2 installs, ruby-bench `8083f57`, `run.sh`, 15 warmup + 10 measured,
two runs each; raw `lob-master-rerun{1,2}` and `lob-ots1-2-{1,2}`):

```diff
-exit_guard_type_failure:              677.2      677.2
+exit_guard_type_failure:              139.2      139.2
-side_exit_count:                   10,166.3   10,166.7
+side_exit_count:                    9,628.9    9,628.8
-ccall_rb_zjit_materialize_frames:   1,204.3    1,204.7
+ccall_rb_zjit_materialize_frames:     666.9      666.8
-send_fallback_send_polymorphic:       493.0      493.0
+send_fallback_send_polymorphic:     1,574.0    1,574.0
-dynamic_send_count:               772,269.1  772,265.5
+dynamic_send_count:               773,337.8  773,340.3
```

Every counter that moves beyond the run-to-run spread moves the same way as on the old head (`lob-ots1`), so on
lobsters -2 and `2cc3e0de4d` are indistinguishable: the Integer/Module guards never fail there. No `run_benchmarks.rb`
round was made for -2.

**Open for the next review.** (1) This is new polymorphic lowering, which the review said needs a fresh design
check. (2) The "all guards + arms" variant also removes the Integer/Module permanent exits and was the best in
round 2 (−23% on the class cycle), at the cost of sends on megamorphic Integer/Module sites; not built, since no
measured app has such an exit. (3) Body and commit message rewritten: no frozen-string claim, no pins or setup, no
two-runs claim, exit diff labeled as ZJIT stats per iteration.

### thermos-sol review of -2, 2026-11-18

Verdict: **approve**, no must-fix, on exact head
[`6a3dc53c874f5b9df4f6d6a2fe2fe091b5aab7cb`](https://github.com/thomasklemm/ruby/commit/6a3dc53c874f5b9df4f6d6a2fe2fe091b5aab7cb),
one commit on `9de06831e37534f8a163e598cc0c6903c7687430`. Both Thermos rubrics were applied directly by this
reviewer, without another reviewer, subagent or thread. The fork commit and proposed upstream body were not edited.

**Fresh design check.** The [new dispatch](https://github.com/thomasklemm/ruby/blob/6a3dc53c874f5b9df4f6d6a2fe2fe091b5aab7cb/zjit/src/hir.rs#L11200-L11260)
fits ZJIT's existing HIR builder: keep the String branch first; for each profiled type the existing conversion helper
accepts, branch on that type and convert; otherwise send `to_s`; merge the result. `polymorphic_arms` groups equal
HIR types, so every bucket in an arm has the same exact class and representation relevant to this helper. Using
`buckets[0]` is sound: these conversions do not consume shape information. Unlike send specialization, the helper
does its lookup and conversion directly; it does not resolve the receiver later from the polymorphic profile.
It therefore needs neither send's fresh Snapshot nor its copied per-arm profile entries. `RefineType` is dominated
by the matching branch, and inference removes the helper's now-redundant receiver guard.

The [conversion helper](https://github.com/thomasklemm/ruby/blob/6a3dc53c874f5b9df4f6d6a2fe2fe091b5aab7cb/zjit/src/hir.rs#L4695-L4738)
retains the original-C-function check and `NoSingletonClass`, `MethodRedefined` and `NoTracePoint` patchpoints.
Fixnums need no singleton patchpoint because they cannot acquire a singleton class. Module/class arms retain the
String-result guard because `rb_mod_name` can return nil for anonymous modules, plus the refusal in a final version.
The original pre-instruction exit state is valid: no user code or other observable conversion has run before those
checks. Redefinition, singleton creation, refinements and tracing therefore still take the existing invalidation or
send paths. String receivers bypass `to_s`, including overrides, just as `vm_objtostring` does.

Empty and both megamorphic profile kinds produce no conversion arms and keep the generic non-String send.
`--zjit-num-profiles=40 --zjit-call-threshold=60 --zjit-inline-threshold=0` independently produced a megamorphic
`mega_site` HIR with String dispatch plus `Send ... megamorphic call site`, without conversion arms. The existing
version budget still bounds recompilation, including inlined owners; at max-versions 1 the String exits remain.

**Maintainability and scope.** L1: a small, idiomatic extension beside the code that already owns `objtostring`,
not a new profiling, invalidation or dispatch mechanism. Both Rust files were already above 1,000 lines; no new
helper, state, type, wrapper or instruction was added. Refused candidates leave bounded, unreachable construction
blocks; RPO-based inference, cleanup and lowering ignore them. This causes snapshot ID churn but no runtime branch.
Avoiding that would duplicate the helper's eligibility checks or split its contract merely to save temporary HIR;
there is no clear structural simplification worth requiring. No added production comment or defensive guard needs
removal. The test phase comments explain why the repeated calls are necessary and match
`test_coerce_to_guard_failure_recompiles`. The Module name guard is necessary, not a speculative defensive check.

Prefer **-2**, not “all guards + arms”: it fixes the measured String-led site and preserves the existing conversion
paths without changing Integer/Module guard policy on sites for which there is no app evidence. The more ambitious
variant's class micro win does not justify broadening this patch, especially with its megamorphic fallback cost.
The fork branch still resolves to the reviewed head and contains only the String guard change plus the arms; the
alternative is not on that branch. Reusing the established dispatch and conversion machinery here does not require
a new design mechanism or policy exception. Ruby master has advanced since the build; this pass certifies the stated
base/head, not a later integration.

**Executed tests and exactness.** Fresh dev build (`--enable-zjit=dev --disable-yjit --disable-install-doc
--without-jemalloc`), `make zjit-test`: **2,016 passed, 15 skipped**, including the profiler-signal test.
`make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: **2,148 passed each**. Rust tests set their own
thresholds; `RUN_OPTS` controls btest, not the Rust harness. Keeping the candidate tests and replacing only production
`hir.rs` with byte-identical master makes both new tests fail at expected 2 / actual 1 versions. With old-head
production, the conversion test fails because version 2 sends instead of using `FixnumToString`; the older test's
version assertion passes but its updated snapshot fails on IDs only. Restored head: both pass again. Corrected the
builder's “unchanged” / “old test passes” wording above rather than treating that snapshot-only failure as a bug.

The committed 227-row probe and a separate 52-row focused probe match interpreter/base/head in dev at thresholds
1, 2, 30, no inlining, max-versions 1, max-versions 2 with exit budget 1, and threshold 60 with 40 profiles; release
base/head also match at thresholds 1, 2, 30, max-versions 2 / exit budget 1 and threshold 60 / 40 profiles. The focused
probe compiles Integer, Module, Class and Module-subclass arms before redefining/restoring core methods, adding and
removing singleton `to_s`, prepending an override and activating lexical refinements. It also checks a previously
unreached interpolation, GC compaction, anonymous modules, non-String and String-subclass conversion results,
exceptions and fiber suspension. HIR dumps confirm the arms actually compiled; this is not only a fallback test.
No semantic divergence found. ARM64 and app suites were not run.

**Independent release cost rerun.** One checkout/build directory, only production `hir.rs` swapped, same release
configuration as the builder, GCC 14.2.0 and Rust 1.100.0. The unchanged
[`ots1_review_cost.rb`](../../zjit-stats/ots1_review_cost.rb) ran in eight modes, twice per binary; allocations at
N=600,000 and Callgrind slopes at N=10,000 minus N=1,000, core 0. The tool was built with `script/bench-valgrind`:
3.19.0 plus the same verified brk patch, local tool SHA `0b357640414f672d8b6f0031eedcabf2581a6b402cb89ebfa1db2a9847d78dd8`.
Ir is extracted from **`totals:`**, not the rounded log summary. Full extracted totals, counter deltas, binary
digests and tool manifest: [ots1-2-review-sol-cost.json](../../zjit-stats/raw/ots1-2-review-sol-cost.json).

| Input cycle | Allocations, base / -2 | Slope vs base, round 1 | Round 2 |
| --- | ---: | ---: | ---: |
| String only | 1,200,014 / 1,200,014 | −0.32% | −0.32% |
| Five Strings, one Symbol | 1,200,014 / 1,200,014 | −1.04% | −1.86% |
| Five small Integers, one Symbol | 1,200,014 / 1,200,014 | +0.56% | −0.36% |
| Five small Integers, one String | 1,200,014 / 1,200,014 | −0.46% | −0.42% |
| Five named classes, one Symbol | 1,200,014 / 1,200,014 | +0.01% | +0.11% |
| Five Strings, one small Integer | 1,200,014 / 1,200,014 | −2.84% | −3.07% |
| Five Strings, one named class | 1,200,014 / 1,200,014 | −3.06% | −3.20% |
| Five Strings, one custom object | 1,400,014 / 1,400,014 | −1.09% | −1.60% |

Largest same-binary A/A slope spread: **0.624%**. Every native and Callgrind measurement window has zero compiles,
invalidation time and `zjit_alloc_bytes` delta. The prior default-mode allocation regression is absent. These are
diagnostic micros with default heap, GC enabled and no CPU isolation, not admitted prices or an app-speed claim;
no cohort was repeated until green. No native time is claimed.

**Explicit boundary, not universal allocation parity.** The helper intentionally refuses a Module conversion in
the final version. A separate dev run of `MODE=string_module N=60000` gives 120,014 objects on base and default -2,
but 140,014 objects and 20,000 sends on -2 with `--zjit-max-versions=2`; values still match. Megamorphic or unprofiled
types likewise retain sends. This is the existing conservative final-version policy, not a correctness defect or
a reason to widen the Integer/Module guards. The allocation claim is limited to the measured default modes, now
made explicit in `impact`.

**Lobsters and upstream text, sentence by sentence.** Recomputed the two committed base reruns and two -2 runs:
677.2 → 139.2 type exits, 10,166.3–10,166.7 → 9,628.8–9,628.9 total exits, 1,204.3–1,204.7 → 666.8–666.9 frame
materializations, polymorphic-send counter 493 → 1,574. Compile failures, failed ISEQs and OOM counters are zero in
boot/warmup and measured stats. The class-count file gives 2,500 String and 538 Symbol calls, supporting “about one in six”; the trace names
`content_tag_string`. This pass checked the saved app stats, not a fresh Lobsters or `run_benchmarks.rb` execution.

* Title and first three body/commit sentences accurately describe the old String guard and permanent exits while
  that version remains installed. Base tests and the reproducer demonstrate this, subject to the existing budget.
* The `coerce_to` sentence matches the existing helper and the opened, merged [precedent](https://github.com/ruby/ruby/pull/19603).
* The polymorphic-path and retained-conversion sentences match the dispatch/helper and `vm_objtostring`.
  `rb_fix_to_s` shares strings only for 0..9; `Module#to_s` allocates where a named module's `rb_mod_name` does not.
  The former overgeneralization about frozen strings is gone. Existing eligibility and final-version limits remain.
* “The Integer and Module guards are unchanged” is true against the exact base; the commit's final explanation
  about more than eight profile types matches `DISTRIBUTION_SIZE` and both megamorphic summary kinds.
* The Lobsters sentence, four diff lines and per-iteration label are supported by the raw data. The body has no
  test counts, commands, pins, setup, review history, rejected variants, Lowrail link or timing disclaimer. It does
  not claim a speedup or repeated timing win. The commit explains the scope without importing our internal process.

DECISIONS' permanent-exit exception waives only the outside-A/A timing evidence requirement; it neither licenses a
new mechanism nor excuses regressions, unwanted comments, inaccurate prose or unapproved posting. This pass finds
none requiring a fork/body change. Thomas's separate conditional draft approval remains recorded; this thread did
not exercise it. `/usr/bin/git cat-file commit HEAD` confirms Thomas Klemm `<github@tklemm.eu>` as both author and
committer, exactly the stated parent, and no trailers (`interpret-trailers --parse` is empty). Candidate source is
restored byte-for-byte and the fork worktree is clean. No fork push, PR, comment or other upstream mutation was made.

### thermos-sol review, 2026-11-18

Verdict: **changes** on exact head `2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9`,
one commit on `9de06831e37534f8a163e598cc0c6903c7687430`. This reviewer applied both
Thermos rubrics directly, without another reviewer, subagent or thread. The proposed
body above and the fork commit were not edited.

**Must fix: the Integer/Module guard changes discard useful conversion fast paths.**
At [hir.rs:4709](https://github.com/thomasklemm/ruby/blob/2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9/zjit/src/hir.rs#L4709)
and [hir.rs:4717](https://github.com/thomasklemm/ruby/blob/2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9/zjit/src/hir.rs#L4717),
letting a mixed site recompile changes more than its exit count. After an Integer-only
warmup, `[1, 2, 3, 4, 5, ""]` makes the old version retain `FixnumToString` on Integers
and interpret the String calls. The new version instead branches on String and sends
`to_s` for the Integers. For 0..9 this loses the shared frozen conversions and adds two
allocations on each Integer call in the tag-shaped probe. The named-module case also
loses the allocation-saving `rb_mod_name` path. Narrow the candidate to the demonstrated
String case or preserve these conversions after recompilation, then remeasure the
changed scope. This is a performance regression, not a Ruby return-value difference.

[Reproducer](../../zjit-stats/ots1_review_cost.rb), with
[raw counts and controls](../../zjit-stats/raw/ots1-review-sol-cost.json). Both release
builds use `--enable-zjit --disable-yjit --disable-install-doc --without-jemalloc`, GCC
14.2 and Rust 1.100.0, on x86_64 Linux. Each process warms 200 monomorphic calls, then
1,000 mixed calls, and runs GC before measuring. For example, run each binary with
`MODE=integer_string N=600000 ruby --zjit --zjit-stats-quiet bench/upstream/zjit-stats/ots1_review_cost.rb`.

| Input cycle | Allocations, base / head, 600,000 calls | Extra dynamic sends on head |
| --- | ---: | ---: |
| String only | 1,200,014 / 1,200,014 | 0 |
| Five Strings, one Symbol | 1,200,014 / 1,200,014 | 200,000 |
| Five small Integers, one String | 1,200,014 / 2,200,014 | 1,000,000 |
| Five named classes, one Symbol | 1,200,014 / 2,200,014 | 1,200,000 |

The Integer/String allocation result repeated exactly. HIR dumps independently show
`FixnumToString` in base and the first head version, then polymorphic `Send :to_s` in
the second head version. All measured probe regions have zero compiles,
`invalidation_time_ns` and `zjit_alloc_bytes` deltas.

Two diagnostic Callgrind rounds on core 0, comparing the whole-process instruction
slope between N=1,000 and N=10,000, give String-only −0.24% to +0.12%, String/Symbol
−2.16% to −1.68%, Integer/String +35.04% to +35.34%, and named-class/Symbol +12.84% to
+13.17%. Largest same-binary A/A slope difference: 0.49%. GC is enabled and the heap
is the default, not fixed or certified, so these are diagnostic micros, not admitted
performance prices or lobsters speed estimates. Native times are not claimed.

For the requested String/Symbol shape, the extra sends therefore do not outweigh the
saved exits in this diagnostic. That does not price the actual lobsters request. The
committed `run_benchmarks/round1.txt` and `round2.txt` still show no effect outside A/A,
in either direction; the record's estimated 0.05% saving has no measured cost model.
The wider Integer/Module change cannot be justified just by showing fewer exits.

**Must fix: cut inaccurate and process-heavy upstream text.** Sentence-by-sentence:

* Title: accurately names the change.
* First body sentence, also the commit message's first sentence: “an Integer or a
  Module becomes its frozen string” is false as a general description. `rb_fix_to_s`
  reuses frozen strings only for 0..9; larger Fixnums allocate, Bignums and custom
  `to_s` methods take sends, and anonymous modules need the fallback. Verified by
  reading `numeric.c:4106`, `vm_insnhelper.c:6552` and `try_objtostring_cfunc`. Cut the
  Integer/Module overview rather than adding all those qualifications.
* Second body sentence and the corresponding commit sentence: correct. The base
  guards have no recompile metadata; the probe below observes permanent exits while
  the old version remains installed.
* Third body sentence and the commit's final sentence: the existing helper and
  recompilation lifecycle support them. Opened the merged
  [coerce_to precedent](https://github.com/ruby/ruby/pull/19603) and inspected its
  `f91fd23296` change; no new recompile policy or state is introduced here.
* Lobsters sentence, also the commit's middle paragraph: supported by the class
  counts and sampled `content_tag_string` exit in the committed raw files. The class
  file actually sums to 538 Symbol calls and 2,500 String calls, not the supporting
  record's 533 Symbols; “about one in six” remains accurate.
* Four stats lines: recomputed directly from `lob1.json.gz`, `lob2.json.gz`,
  `lob-ots1.json.gz` and `lob-ots2.json.gz`; the rounded values are correct. No timing
  claim is implied by showing only a clearly labeled exit diff.
* Final parenthesis: remove the pin and setup details under DECISIONS' body rules.
  Its unqualified “two runs per build agree” also overstates railsbench coverage:
  only one head railsbench raw run is committed. Keep “ZJIT stats per iteration” as
  the label for the diff. Railsbench's measured counters are materially unchanged,
  but that is not a claim about throughput.

The permanent-exit exception explicitly permits exit evidence without an
outside-A/A `run_benchmarks.rb` win. It does not turn an exit decrease into a speed
claim or waive a demonstrated regression. It does not itself override the ruby/ruby
moratorium; Thomas's separate draft approval, retained above from concurrent main,
requires a passing review and this pass does not approve. The narrow existing-helper
change follows the merged precedent; new polymorphic lowering or a new recompile
policy would need a fresh design check.

**Correctness and invalidation.** The helper preserves the same guard types and
frame states, adds `Recompile`, and updates inferred types through the canonical
path. Traced lowering through `side_exit_with_recompile`, the LIR exit-state save,
`exit_recompile`, the exit budget, `invalidate_iseq_version`, incoming-call re-stubs
and accumulated/re-enabled profiles. It invalidates the compiled owner, including an
inlined site's owner; it does not resume midway through stale machine code. At the
version limit, `exit_recompile` returns without invalidation; the added metadata does
not create unbounded versions. The resulting fallback still handles arbitrary
receivers and `anytostring` results.

An interpreter/base/head differential probe produced identical 137-row output for
each of six configurations: thresholds 1, 2 and 30, threshold 2 without inlining,
threshold 2 with max-versions 1, and threshold 2 with max-versions 2 / exit budget 1.
It seeded separate sites with String, Integer, named Module and a custom object,
then changed receivers through String, Symbol, nil, booleans, negative/0/9/10 and big
Integers, Float, named/anonymous modules/classes, String subclasses and singleton
methods, frozen/binary/UTF-8 Strings, private/custom/missing `to_s`, String-subclass
and non-String conversion results, exceptions and wrong arity. It compared results,
encoding, mutability, exception class/message and conversion-call counts, and checked
singleton addition/removal, `extend`, prepend/redefinition, GC compaction and a fiber
suspended inside `to_s`. Release base/head also matched the interpreter. No semantic
or security defect was demonstrated. ARM64 and app suites were not run.

**Guards and comments.** All four changed guards have a contract reason: String
protects direct concatenation; Fixnum protects `rb_fix_to_s`; the profiled Module
class protects `rb_mod_name`; the other receiver guard supplies a sound type to send
specialization. Their recompile helper is the file's canonical idiom. Existing
original-C-function and no-singleton checks preserve redefined/refined/singleton
`to_s`; Module ancestry/immediate checks protect the C argument; its final-version
policy and String-result guard handle anonymous names. The String singleton
patchpoint's existing TODO is unchanged. No guard is new or widened, and none is
added for arbitrary objects outside Ruby's contract. No production comment was
added. The five new test phase annotations explain why repeated identical calls are
not redundant, in the exact style of `test_coerce_to_guard_failure_recompiles`; keep
them. The `SendFallbackReason` text is generated snapshot output, not prose added to
explain the patch. Both files were already far over 1,000 lines. No new layer,
wrapper, state, branch or structural regression; readability L0.

**Executed checks and identity.** Built exact head with `--enable-zjit=dev` and ran
`make zjit-test`: **2,015 passed**, 15 platform/configuration skips, including a pass
of `test_profile_frames_during_direct_jit_to_jit_entry`. Rust tests set their own
thresholds; `RUN_OPTS` applies to btest, not to the Rust harness. Independently ran
`make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and the same at threshold 2:
**2,148 passed at each threshold**. The known signal flake did not occur in this run.

Replaced only production `hir.rs` with its byte-identical base version, keeping the
new test: `make zjit-test ZJIT_TESTS=test_objtostring_guard_failure_recompiles` fails
at `opt_tests.rs:10419`, expected 2 versions, actual 1, before checking the snapshot.
The unchanged test passed on head. The committed `ots1_probe.rb` reports 10,000
type-guard exits / no new version on base versus 5 exits / one new version on head,
on both dev and release builds. Restored the candidate source and confirmed a clean
fork worktree at the exact reviewed head. `/usr/bin/git cat-file commit HEAD`
confirms Thomas Klemm `<github@tklemm.eu>` as author and committer, exactly one
parent (the stated base), and no trailers; `/usr/bin/git log -1 --format='%(trailers:only)' HEAD`
is empty. No fork push, PR, comment or other upstream mutation was made.
