# Bet Z3: remaining ZJIT send fallbacks on Rails requests

2026-10-22. **Z3 closed with two owner-admitted candidates.** This research
thread posted no upstream PR, issue or comment. Dedicated owner-authorized
PR threads subsequently opened [protected sends (#19483)](https://github.com/ruby/ruby/pull/19483)
and [explicit block parameters (#19484)](https://github.com/ruby/ruby/pull/19484).
Their current heads/reviews are owned by those threads, not certified by the
historical measurements here. No whole-request speed claim.

Follow-up: a second owner-admitted candidate removes **27 Fizzy / 0 blog
final sends per request** by admitting guarded Proc sends to explicit block
parameters. Its [standalone-master commit, corrected site attribution and
controls](zjit-block-param-send.md) are published separately. The original
census below remains the pre-prototype control, not the combined result.

The control is Ruby [46631773](https://github.com/thomasklemm/ruby/commit/46631773dd402e769190decb23ea44f64cd69dfc),
including literal kwrest atop #19478. The Ruby and Lowrail evidence branches
are both `thomasklemm/zjit-fallbacks-2`.
[Machine-readable evidence](zjit-fallbacks-2.json) retains both seeds, every
timing round, nonzero call-site counters, global counters, response digests,
binary hashes, test receipts and instruction-count attribution.

Ruby research commit:
[`cbc1f16`](https://github.com/thomasklemm/ruby/commit/cbc1f16c87887793c2cbf8d06d42feb035416403).
The orb's git wrapper injected an unwanted Amp-Thread-ID trailer. The owner
directed that this published research commit remain unchanged and that a
[dedicated PR thread](https://ampcode.com/threads/T-01a16491-667b-7255-a01e-0a8b8c861e86)
recreate the clean master-based commit; this research thread opens no PR.
Author and committer are Thomas Klemm <github@tklemm.eu>. Future commits use
`/usr/bin/git -c core.hooksPath=/dev/null` to bypass that wrapper.

## Count-ranked remaining reasons

Counts are increments per request, not percentages or time shares.
Rows are sorted by the sum of the two apps' seed means, not by
estimated savings. Values agree across seeds unless a range is shown.
Planner kwrest counts are a separate, overlapping diagnostic, not another
send to add to this table. The top eligible **small** fix is rank 3, not the
highest raw count.
The original upstream assessments below precede the two PR handoffs linked
above; the count baseline has not been regenerated after those handoffs.

| Rank / reason | Blog | Fizzy | Fix sketch / upstream status / verdict |
|---|---:|---:|---|
| 1. `invokeblock_polymorphic_miss` | 297 | 523 | Dispatch more handler kinds, refresh misses or support megamorphic block ISEQs. `Array#each` alone is 284/504. Master still falls back; open RFC [#19389](https://github.com/ruby/ruby/pull/19389) already contains IFUNC/Proc/Symbol dispatch, reprofiling and megamorphic dispatch. **Defer: overlap and not one clean guard change.** |
| 2. `send_polymorphic_fallback` | 64 | 398 | Broaden receiver dispatch or improve profiles. Leading sites include `BasicObject#!=` (10/24) and Arel visitor `class` (0/20). Master retains the fallback; [#19443](https://github.com/ruby/ruby/pull/19443) and [#18616](https://github.com/ruby/ruby/pull/18616) address shape data, not all these misses. **Defer: receiver-distribution/size trade-off, no universal tiny fix.** |
| 3. `send_not_optimized_need_permission` | 87 | 353 | Guard actual runtime caller self against defining class/module; keep receiver CME guards. InheritableOptions `_get` contributes 73/302, WhereClause `predicates` 8/18. Master still refuses; no matching focused open PR found, including inspection of #19389's diff. **Prototype: 87 -> 1 / 353 -> 9, draft-eligible.** |
| 4. `invokeblock_not_specialized` | 121 | 276 | Extend exact-arity/simple-block specialization to additional argument/throw/handler shapes. `Array#map` is 54/188. Master has explicit simple-ISEQ/arity/auto-splat/throw restrictions; [#18244](https://github.com/ruby/ruby/pull/18244), #19389 and [#17864](https://github.com/ruby/ruby/pull/17864) overlap. **Defer: do not just remove refusal checks.** |
| 5. `send_block_arg_not_nil` | 143 | 226 | Broaden passed-block support beyond current eligible ISEQ sends. `_read_attribute -> fetch_value` is 36/30, `mon_synchronize -> synchronize` 22/39. [#19077](https://github.com/ruby/ruby/pull/19077) handles inlined ISEQ `&proc`, explicitly not generic yield-on-Proc; [#19351](https://github.com/ruby/ruby/pull/19351) covers a literal proxy case. **Defer: generic C/block-handler semantics, not a safe blanket admission.** |
| 6. `one_or_more_complex_arg_pass` | 156 | 194.96–195 | Split caller flags/callee setup before selecting a bounded subcase. `Rack#fetch_header -> fetch` is 29/26. Residual kwrest 31/88 includes runtime forwarding/splats/blocks, beyond the literal patch; RFC #19389 includes caller kw-splats. **Follow-up prototype: explicit block parameters remove 27 Fizzy sends, owner-admitted; other subcases deferred.** |
| 7. `sendforward_not_specialized` | 114 | 200 | Profile forwarded callinfo and specialize simple positional forwarding. Fizzy WhereClause `empty?` alone is 31. Already open as [#18326](https://github.com/ruby/ruby/pull/18326); master still has the generic fallback. **Do not duplicate.** |
| 8. `send_not_optimized_method_type` | 26.887–27 | 100.887–101 | Mostly null lookup (8.887–9 / 77.887–78) and optimized targets with blocks (18/23). Fizzy asset-host and relative-root misses are 34 each. Preserve method_missing and block semantics. **Defer: not a single unsupported method-type fix.** |
| 9. `send_not_optimized_method_type_optimized` | 21 | 96 | Guard/profile the method name for dynamic `send`, plus separate block-call support. Subtypes are send 21/89 and block_call 0/7; Arel visitor `send` alone is 61 on Fizzy. Master handles Call/Struct access, not these cases. **Investigated next: dynamic symbol-value profiling and call reshaping needed, not a small literal-symbol rewrite; deferred.** |
| 10. `send_polymorphic` | 22 | 80 | Improve receiver specialization; tag `to_s` contributes 7/30. Existing profiling/shape PRs overlap partly. **Defer: profiling/code-size question.** |
| 11. `send_megamorphic` | 11 | 59 | Guarded common-case dispatch may help selected sites, but raising the specialization limit is not a correctness/performance argument. **Defer.** |
| 12. `super_complex_args_pass` | 27 | 37.977–38 | Needs positional/keyword/block super-call setup, not ordinary send admission. **Defer.** |
| 13. `invokesuperforward_not_specialized` | 12 | 19 | Forwarded super needs the original super method and caller flags. **Defer; adjacent to #18326, not established coverage by that PR.** |
| 14. `super_from_block` | 10 | 12 | Recover lexical method and block environment correctly. **Defer.** |
| 15. `super_call_with_block` | 2 | 5 | Preserve implicit/explicit block and callee frame semantics. **Defer.** |
| 16. `super_polymorphic` | 2–2.017 | 3–3.017 | Mixed receiver/super lookup, including a small entropy-harness component. **Defer.** |
| 17. `super_not_optimized_method_type` | 1 | 1 | Response-body setter super targets an attrset. Reuse super-call guards and ivar-writing machinery, preserving arity/block/complex-argument refusals. Current master still refuses; open/closed super/attrset/attr_writer PR searches found no focused duplicate. **Investigated and declined: one call/request, a new guarded lowering rather than a stale refusal; not prototyped.** |

Master was refreshed/checked at
[`8ff4ae1`](https://github.com/ruby/ruby/commit/8ff4ae135d438314090f0dc23916601ef9c444d5).
All 761 open PRs were collected, titles/bodies searched, focused candidates
read, and the broad #19389's 77 commit subjects and relevant file diffs
inspected. These are overlap assessments, not claims that those PRs fix all
observed sites or have passed these fixtures.

The later open/closed PR search `repo:ruby/ruby is:pr ZJIT protected`
returned seven results and no matching protected-dispatch improvement.
`CONTRIBUTING.md`, `doc/contributing/contributing.md`, and
`doc/contributing/making_changes_to_ruby.md` were read. No project AGENTS or
PR template was present in the checked master tree. No AI/LLM-contribution
ban was found in these contribution docs or `.github`; this is a scoped
repository-policy check, not a claim about unpublished project policy.

## Final disposition under the owner's value cutoff

No third prototype or additional timing cohort was run. The accepted
protected-send reduction is **86 blog / 344 Fizzy final sends per request**;
the accepted explicit-block-parameter reduction is **0 / 27**. These are
separate comparisons against the same pre-prototype control, **not a
measured combined build**. The [follow-up evidence](zjit-block-param-send.md)
corrects planner double-counting: the surviving nine add-bind-related
fallbacks are SQLString yields, not unused-block warnings. A
[dedicated stats PR thread](https://ampcode.com/threads/T-01a164eb-e13a-77e9-a92c-591a0d8f21c1)
owns any optimizer-counter fix; none was made here.

The final read-only inspection refreshed upstream `master` (still
[`8ff4ae1`](https://github.com/ruby/ruby/commit/8ff4ae135d438314090f0dc23916601ef9c444d5))
and RFC #19389, and searched
open/closed PRs for ZJIT super, attrset and attr_writer. Both seeds locate
the sole attrset-super fallback at `ActionController::Metal#response_body=`,
`metal.rb:238`, bytecode offset 29: exactly **1 / 1** per request. Merged
[#15993](https://github.com/ruby/ruby/pull/15993) explicitly left attrset
targets after handling C-function super calls; current master still handles
ISEQ/CFUNC targets only.

An attrset implementation could reuse `emit_super_call_guards`, require one
argument and emit `SetIvar` with the attr ID from the resolved method entry,
returning the assigned value. A field-store fast path additionally needs
receiver/shape guards and the existing frozen/complex-object fallbacks.
This is a new guarded lowering, not another redundant refusal to remove;
arity, block handling, alias/redefinition invalidation and exceptional
behavior would need their own witnesses. At one call per request, this was
declined rather than declared exact or measured profitable.

The stopping decision is **not** a claim that all remaining counts above
ten are covered upstream. Dynamic `send` remains **21 / 89** (61 Fizzy Arel
visitor calls), and receiver-polymorphic fallback remains **64 / 398**.
The former needs symbol-value profiling/guards, target lookup, permissions
and call reshaping; the latter needs receiver-distribution/code-size
decisions, not a blanket increase in specialization limits. Neither yielded
another small, clearly exact admission. Method-missing sites must retain
lookup/invalidation semantics. Super complex arguments are **27 / 38** in
aggregate but no individual site exceeds six; super-from-block is **10 / 12**
with no individual site above five and requires lexical environment/CME
recovery.

The leading yield/block/forwarding/exception areas overlap #19077, #19389,
#18326, #18759 and #18244 as detailed in the ranking; overlap is not proven
complete coverage. These larger projects and the unclaimed remaining gaps
stay in the ledger. Under the requested small-change/value cutoff, Z3 ends
with its two admitted candidates and no additional candidate handoff.

## Side exits and coverage limits

Seeded diagnostic side exits/request are blog **36.02 / 36.15**, Fizzy
**48.03 / 48.15** (seeds 0/1). The major reason is exception-handler entry:
**26 / 37**, with I18n `translate` (8 on blog), Journey `evaluate` (6/10),
and SQLite statement `each` (2/5). Open
[#18759](https://github.com/ruby/ruby/pull/18759) already implements exception
entries; #18244 and RFC #19389 cover related throwing/continuation work.
Other reasons include unhandled bytecodes (3/5), unhandled block arguments
(2/2), blog inflector method-redefinition patchpoints (4/0), and type guards.
The entropy/snapshot harness adds small fractional counts; raw counters and
locations are retained rather than rounded away. Exception entries are
attributed by method with offset 0, **not** the exact resume PC.

The unseeded stats screen instead has exception entries 26/36 and total
exits 36.0033/48.0033. Do not mix those counts with the seeded census.
Instrumentation adds increments for each final send fallback, planner
failure and exit; it is used only for census, never for timing. Final-send
site totals reconcile exactly with their global reason counters in both
seeds. Planner reasons overlap final-send reasons.

Campfire was skipped: a third master bundle, assets and deterministic state
were not a cheap extension of the two prepared fixtures. No Campfire claim.
This is a request-path census, not full Rails tests or `lowrail verify`.

## Protected-send prototype

The runtime permission check uses the caller's **current self**, not a class
cached per ISEQ. The owner can be a module; internal ICLASS is normalized to
the module. The existing IsA code generator calls `rb_obj_is_kind_of` for
these owners. Failure exits to the original VM send at its original PC.
The receiver method-entry guard/invalidation remains in place. Inlined
frames and refined entries retain VM dispatch; private/FCALL behavior is
unchanged. The debug IsA validator now admits Class or Module, matching the
instruction's actual runtime contract.

The final four-file source/test diff **applies cleanly to master alone**;
it does not depend on #19478 or literal kwrest. This was checked using
`GIT_INDEX_FILE=/tmp/betz3/master-index git read-tree upstream/master` and
`git apply --cached --check` on that temporary index. Measurements are
stacked on 46631773; there is no master-alone build/performance claim.

Base/A/A/patch exact checks match at seeds 0 and 1, including body/full
headers and each complete 300-response sequence. Permission counts become
**1 / 9**, total final-send counts fall by exactly **86 / 344** per request,
and side-exit counts are unchanged. No Lowrail/app specialization was used.

Tests cover shared-ISEQ callers with varying runtime self, subclass/sibling
callers, module-owned methods, singleton-class callers, refinements and
protected/public/private changes after compilation. All twelve combinations
of base/measured/final variant and interpreter/YJIT/ZJIT/no-inline ZJIT have
identical semantic-output SHA256, including GC compaction checking.

`make zjit-check ZJIT_TEST_FEATURES=disasm ZJIT_TESTS='-j 4'` passes
**1,894 Rust tests (15 skipped)** and **27 CLI tests / 7,394 assertions**.
Keyword/call/method suites pass in all four modes: **280 tests / 4,541
assertions** each. Removing the complete permission guard makes sibling
and unauthorized singleton callers return 47 instead of raising; restoring
it passes. An earlier mutation that removed only GuardBitEquals left an
unused module-IsA instruction and failed the debug Class-only validator,
not the semantic assertion; it is not presented as semantic proof. This
exposed the validator correction. A first test invocation also lacked the
required disasm feature; the corrected command and final green run are kept.

## Performance controls, including the retained YJIT caveat

One cohort only: ten rotated paired rounds, CPU 2, interpreter/YJIT/ZJIT,
base/A/A/patch, two million iterations of the inherited-Hash-default-block
micro in [jit_protected_send.rb](../bench/experiments/jit_protected_send.rb).
Result is 26 per iteration; allocations are unchanged. The separate
2,000-iteration stats run reduces permission fallbacks **4,000 -> 0**, with
no compilation or side exits in the window. Every round is retained.

| Mode | Patch elapsed change, 95% interval | A/A, 95% interval |
|---|---|---|
| Interpreter | +1.04% [-5.50%, +8.60%] | -0.79% [-5.71%, +2.72%] |
| YJIT | **+3.61% [+1.26%, +6.80%]** | **+1.90% [-1.77%, +7.67%]** |
| ZJIT | **-36.45% [-38.75%, -34.95%]** | -0.63% [-4.47%, +3.15%] |

The YJIT A/A arm existed. Its wide interval and the resolved patch-wall
slowdown are caveats, not deleted observations. All executable source
changes are under `zjit/`; no changed ZJIT compiler path executes under
`--disable-zjit --yjit`. Literal "no ZJIT code runs" would be too strong:
unchanged boot/annotation initialization runs even with ZJIT disabled.
Callgrind's `zjit.h:yjit_compile` is a YJIT C wrapper, not ZJIT compilation.

Fixed-getrandom-seed, GC-disabled Callgrind windows use the unchanged
[client extension](../bench/callgrind.c) and
[startup seed shim](../bench/experiments/jit_literal_kwrest_seed.c).
The shim is **never** used in app or timing runs. Raw Ir:

| Mode / binary | N=0 | N=5,000 | N=10,000 |
|---|---:|---:|---:|
| Interpreter base / A/A / timed patch / final patch | 3,056 | 16,198,056 | 32,393,056 |
| YJIT base / A/A / timed patch | 889,446 | 10,494,681 | 19,859,681 |
| YJIT final patch | 889,460 | 10,494,695 | 19,859,695 |

The final source adds only the debug-validator Module correction after the
timed version. Normalizing LLVM symbol suffixes, the sole text-symbol size
change is `Function::validate_types`: 5,839 -> 5,871 bytes. The final YJIT
**+14 Ir is constant at every N**, entirely in unchanged hashbrown insertion
of pointer-keyed YJIT Block entries during seam compilation. Full function
attribution is in JSON. N=0-subtracted Ir is identical at both nonzero N:
interpreter **16,195,000 / 32,390,000**; YJIT **9,605,235 / 18,970,235**.
The owner explicitly admitted this layout effect: equality applies to
workload-dependent Ir. This is **draft-eligible**, not strict raw-total
equality or equal wall time. No timing cohort was rerun after the validator
edit. A final-Ir probe initially used a different cwd/absolute script path;
that non-comparable probe is retained separately, not used for admission.

No fixed-heap whole-request benchmark, JIT-flat YJIT window, AArch64 run,
hosted CI, full ruby-spec or full Rails suite is claimed.

## Reproduction

Reuse [Z2's fixtures and bundle/entropy recipes](zjit-literal-kwrest.json)
and [the pinned master bundles](jit-internals.json), not newly resolved
dependencies. NativeBench is pinned at
`6510cd2f2cd4384fcf648c638f5f720d00c8d9c8`. The evidence JSON includes the
actual configs, seed/asset preparation source, policies, bundle files and
commands; paths under `/tmp/betz3` are disposable orb paths.

Build 46631773 with `--enable-yjit=stats --enable-zjit=stats
--disable-install-doc`, save base-ruby, apply only
[zjit_fallbacks_census.patch](../bench/experiments/zjit_fallbacks_census.patch)
for the diagnostic build, then remove instrumentation before compiling the
protected-send variant. `jit_hooks.rb run CONFIG NEW_OUTPUT` performs the
exact/stats/census phases. It uses the pre-existing entropy fixture with
`requests: 300`; an initial attempt omitted that required budget and failed
closed before any accepted census. `jit_hooks.rb micro CONFIG OUTPUT` runs
the single rotated timing cohort. Full flags and raw worker data are in JSON.
