---
id: ZSV1
repo: ruby/ruby
kind: perf
area: ZJIT, setinstancevariable profiling
reviewer: "tekknolagi (filed Shopify/ruby#1122; his #19858 did the same for getinstancevariable)"
branch: thomasklemm/zjit-setivar-real-class-3
head: "ca3ea90482"
base: master
built_on: "3b188d0dd5"
depends_on: []
stacked_on:
alternative_of:
impact: "eligible ordinary objects with singleton classes get shape-specialized ivar writes instead of recompile exits and a generic final-version fallback; lobsters -584 generic setivar per iteration (master/master-aa/branch stats, unchanged on master 3b188d0dd5, bench/upstream/zsv1/results-3.md); railsbench and shipit generic-write totals unchanged, but Shipit fallback reasons shift -81/+81; no speed claim"
rank: 2
risky: false
state: reviewed
pr:
note: "2026-11-25 (-3, rebase for the draft PR under the 2026-11-25 DECISIONS exception): thomasklemm/zjit-setivar-real-class-3 ca3ea90482, 47b2ed7110 cherry-picked clean onto master 3b188d0dd5 (435 commits later), same authorship and author date, committer Thomas Klemm, no trailers; range-diff is `=`. Master has not fixed or replaced it (setinstancevariable still uses profile_self; #1122 open; Shopify/ruby#1126 closed 2026-11-13; no open ruby/ruby PR overlaps); the hold trigger is met, #19976 and #19982 merged today. Dev build: zjit-test 2036 passed/15 skipped, both HIR tests pass, btest t1 and t2 2148/2148, rebuilt 33-row probe (original stayed in the archived review orb; now kept as zsv1/probe.rb) identical to the interpreter at t1/t2 and with max-versions=1. Lobsters stats on the new base reproduce -584 exactly (11,405 -> 10,821; master A/A identical), so the body is unchanged; railsbench unchanged, Shipit -81/+81 as before. Record: bench/upstream/zsv1/results-3.md. Before opening: thermos-sol and Astra on exact head ca3ea90482 (DECISIONS exception); no PR opened, nothing posted. 2026-11-18 22:30 UTC (coordinator): tekknolagi reviewed #19976 and #19659 today, which met the earlier hold condition. Still held, with a sharper trigger: open ZSV1 once tekknolagi approves or merges #19976 or #19659, so we don't add a fourth ZJIT request while two of his reviews are in flight. Head 47b2ed7110 merges clean with master bdff3c5d66 (after #17864); the evening stats pass (zjit-stats-2026-11-18-evening.md) finds no larger free ZJIT lead. 2026-11-18 (Thomas and coordinator): held, neither opened nor commented on Shopify/ruby#1122. Small effect (584 of about 772k dynamic dispatches per lobsters iteration, no change in railsbench/shipit totals) while ruby/ruby#19912, #19976 and #19982 have no maintainer response; revisit when one of them gets one. 2026-11-18 thermos-sol text-only confirm: approve, no must-fixes, exact Ruby head 47b2ed7110 unchanged. Both cuts in Lowrail 899e36d9 are confirmed: the body names only lobsters and the comment claims only its 584 fewer generic writes per iteration. Independently rechecked the three raw lobsters counters, zero A/A movement and byte-identical diff replay. Prior code, guard, comment, message and packaging findings are closed; both earlier passes retained below. Record: bench/upstream/zsv1/thermos-review.md, Text-only confirm of revision 2. No speed claim, fork push, PR or upstream post; posting still requires the usual approval."
passes:
  - reviewer: thermos-sol
    orb: "T-01a1ef67-4308-7296-a24a-80471f35f540"
    head: "fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d"
    date: 2026-11-18
    verdict: changes
    open: >-
      Both Thermos rubrics applied directly by the sole reviewer, without subagents or other threads.
      No introduced correctness/security or structural defect found; exact-shape/frozen/layout guards,
      fallbacks, write barriers and profile GC relocation remain intact. Must trim redundant added comments;
      supply replayable base/A-A/head evidence or cut the 475/475/392 and lobsters -584 figures; qualify
      ordinary singleton receivers and cut body test/A-A narration; package one coherent fix commit on
      refreshed master and re-review. Exact head zjit-test: 2016 passed/15 skipped; btest t1: 2148 passed;
      selected Ruby suites: 323 tests/15405 assertions at each threshold, no failures/errors/skips.
      Base control: 2013 passed/1 SIGPROF assertion failure/15 skipped, no retry.
      The 33-row probe matches base/head interpreters and ZJIT t1/t2, also max-versions=1.
      Diagnostic micro: 1000000 generic writes on base, 0 on head; no certified speed claim because
      invalidation_count is absent. Original app figures remain unverified. Applies cleanly to master
      4414d3ea25, 30 commits after base; live Ruby/Shopify searches found no replacement.
      Full guard trace, sentence audit, cold-profile stress results, commands and limitations in
      bench/upstream/zsv1/thermos-review.md. Ruby branch and public drafts unchanged; no upstream action.
  - reviewer: thermos-sol
    orb: "T-01a1ef67-4308-7296-a24a-80471f35f540"
    head: "47b2ed7110f84ca76cc7aa6e767a1119e62c09a3"
    date: 2026-11-18
    verdict: changes
    open: >-
      Both rubrics applied solo. No code must-fix remains: only comment lines differ from the reviewed
      implementation/tests, and the new base does not change their guard/GC/transition consumers.
      Comments, qualified message and one-commit packaging accepted. Exact head rebuilt; both selected HIR
      tests pass, and all 33 probe rows match interpreter/ZJIT t1/t2 and both max-versions=1 modes.
      Nine raw stats archives validated;
      all six branch/A-A diffs replay byte-for-byte, and three lobsters counters independently drop 584
      per iteration with zero A/A movement. Remaining text must-fix: cut the body's other-app/A-A clause
      and the comment's only-lobsters claim. Shipit no-side-exits 41029 -> 40948 and not-T_OBJECT
      7891 -> 7972 are -81/+81, not unchanged or A/A noise; total generic writes stay 48920.
      No timing or instruction claim is certified. Record: bench/upstream/zsv1/thermos-review.md,
      Confirm of revision 2. Public drafts and Ruby branch unchanged; no upstream action.
  - reviewer: thermos-sol
    orb: "T-01a1ef67-4308-7296-a24a-80471f35f540"
    head: "47b2ed7110f84ca76cc7aa6e767a1119e62c09a3"
    date: 2026-11-18
    verdict: approve
    open: >-
      None. Text-only confirm of both cuts in Lowrail 899e36d9 on the unchanged Ruby head.
      Reread the complete public body and comment draft against the retained stats and prior guard trace.
      The false other-app comparisons and body A/A-methodology clause are gone. Raw lobsters counts
      independently confirm dynamic_setivar_count 11405 -> 10821, no_side_exits 5956 -> 5372 and
      ccall_rb_vm_setinstancevariable 11345 -> 10761, exactly -584 each per iteration, with zero A/A movement.
      The retained lobsters diff replays byte-for-byte. Carries forward the solo correctness/security
      and maintainability review, exact-head tests and packaging audit above; no new code review or
      suite rerun claimed. All must-fixes closed. No speed claim or upstream action.
      Record: bench/upstream/zsv1/thermos-review.md, Text-only confirm of revision 2.
  - reviewer: thermos-sol
    orb: "T-01a2129c-eccf-7381-ba7b-5a5579c681dd"
    head: "ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5"
    date: 2026-11-25
    verdict: approve
    open: >-
      None. Both Thermos rubrics applied directly by the sole reviewer, without delegation or other threads.
      Verified exact fork head and parent 3b188d0dd5, one Thomas-authored/committed fix with no trailers,
      range-diff = after 435 master commits. Re-audited shape transitions, actual-receiver layout/frozen/shape
      guards, write barriers, profile marking/relocation, updated side-exit stack maps, recompile and final-version
      fallback policy. No introduced correctness/security or maintainability defect; L0, no new guard needed.
      Fresh dev build: zjit-test 2036 passed/15 skipped; btest thresholds 1 and 2 each 2148 passed;
      five selected Ruby suites each 327 tests/15429 assertions, no failures/errors/skips.
      Retained 33-row probe matches the interpreter at both thresholds, also max-versions=1.
      Supplemental RHS mutation/fiber/compaction/young-value checks match in six ZJIT modes; HIR confirms
      shape guards and stores after callbacks. One class_of mutation makes both new HIR tests fail with
      NoProfileSetIvar; restored exact source passes both. All nine stats-3 archives validate and all six
      diffs replay byte-for-byte; lobsters -584 independently confirmed, Shipit -81/+81 retained.
      Body and commit message accepted sentence by sentence. No speed claim, Ruby push, PR or upstream post.
      Record: bench/upstream/zsv1/thermos-review.md, Exact-head confirm of revision 3.
  - reviewer: astra
    orb: "T-01a2129c-f593-70d9-98f1-4854b086903d"
    head: "ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5"
    date: 2026-11-25
    verdict: approve
    open: >-
      None. First Astra pass covers the whole change with both Thermos rubrics applied directly,
      without delegation. Exact-head dev build: zjit-test 2036 passed/15 skipped; btest thresholds
      1 and 2 each 2148 passed. Retained 33-row probe and new 21-row adversarial probe (23 with Box)
      match the interpreter; explicit exhaustion, GC/compaction, shared T_OBJECT/T_STRUCT layout
      and two-version no_side_exits probes pass. max-versions=1 alone does not force no_side_exits.
      Routing mutation kills both added HIR tests; restoring the head passes both. All six stats-3
      diffs replay byte-for-byte; lobsters -584 is exact, not a speed claim. Audited guards,
      transition ownership, profile GC relocation, body and commit message; no code or text must-fix.
      Cold deep-extension cost and controls are recorded, with seven replayable probes.
      Record: bench/upstream/zsv1/thermos-review.md, Astra full review of revision 3.
      No Ruby push, PR opening or upstream post.
---

# ZJIT: Profile the real class for setinstancevariable

The profiler records an ordinary object with a singleton class as "other" (#19540), so an ivar write on an `extend`ed object has no profile. It side-exits to recompile, and once the ISEQ has used up its versions the final version writes the ivar generically.

`setinstancevariable` uses the profiled class only for shape transitions, and the interpreter looks those up with the real class (`obj_get_owner_class()` in shape.c). This profiles that class instead, so these writes get the same shape guard as any other object's, still subject to the existing layout, frozen and capacity checks. #19858 did the same for `getinstancevariable` by profiling only the shape.

Fixes Shopify/ruby#1122

ZJIT stats per iteration for lobsters:

```diff
-dynamic_setivar_count: 11,405
+dynamic_setivar_count: 10,821 (-584)
-setivar_fallback_no_side_exits: 5,956
+setivar_fallback_no_side_exits: 5,372 (-584)
```

## For Thomas

Rebased as `ca3ea90482` on master `3b188d0dd5` (range-diff `=`, lobsters −584 unchanged, body unchanged;
[results-3.md](../../zsv1/results-3.md)).
The [exact-head thermos-sol confirm](../../zsv1/thermos-review.md#exact-head-confirm-of-revision-3-2026-11-25)
and [Astra's full review](../../zsv1/thermos-review.md#astra-full-review-of-revision-3-2026-11-25)
**both approve that exact head with no must-fixes**, each applying both Thermos rubrics independently.
Astra adds adversarial/Box/GC and shared-layout probes, explicit final-version coverage and a killed routing
mutation. The body and commit message are approved; the -584 counter claim is verified, not a speed claim.
The body above and the comment draft are **approved with no must-fixes** for head `47b2ed7110`.
The [text-only confirm](../../zsv1/thermos-review.md#text-only-confirm-of-revision-2-2026-11-18) closes the final
wording finding and carries forward the code, comments, message and packaging review. The retained stats
support lobsters -584 generic writes per iteration, not a speed claim or a claim about every other app's
counters. Builder tests and raw-data provenance are in [results-2.md](../../zsv1/results-2.md). No runtime guard
needs weakening or replacing: only the recorded class changes, and the store checks the actual receiver's shape.
Nothing is opened or posted; the usual upstream approval still applies.
