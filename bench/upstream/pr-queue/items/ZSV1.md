---
id: ZSV1
repo: ruby/ruby
kind: perf
area: ZJIT, setinstancevariable profiling
reviewer: "tekknolagi (filed Shopify/ruby#1122; his #19858 did the same for getinstancevariable)"
branch: thomasklemm/zjit-setivar-real-class-2
head: "47b2ed7110"
base: master
built_on: "4414d3ea25"
depends_on: []
stacked_on:
alternative_of:
impact: "eligible ordinary objects with singleton classes get shape-specialized ivar writes instead of recompile exits and a generic final-version fallback; lobsters -584 generic setivar per iteration (replayed master/master-aa/branch stats, bench/upstream/zsv1/results-2.md); railsbench and shipit generic-write totals unchanged, but Shipit fallback reasons shift -81/+81; no speed claim"
rank: 2
risky: false
state: in-review
pr:
note: "2026-11-18 (coordinator): applied the confirm's two text must-fixes verbatim: body lead-in is now \"ZJIT stats per iteration for lobsters:\" and the #1122 comment draft says \"On lobsters, it removes 584 generic writes per iteration.\" Ruby head 47b2ed7110 unchanged; needs a text-only confirm. 2026-11-18 thermos-sol confirm of exact 47b2ed7110: changes, text only. Comments, executable/test equivalence, qualified commit message, single-commit packaging and lobsters -584 evidence accepted; all six stats diffs replay byte-for-byte. The body still falsely says Shipit setivar counters are unchanged, and the comment says only lobsters is touched: raw Shipit fallback reasons shift -81/+81 below the filter's 100 cutoff, with totals unchanged. Cut those comparisons and the body A/A-methodology clause, then confirm the text on this same head; no new Ruby code fix needed. Detailed confirm in bench/upstream/zsv1/thermos-review.md; builder tests in results-2.md. Public drafts preserved as reviewed; not opened or posted. Earlier exact-head pass retained below."
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

The body above is the -2 draft for `47b2ed7110`, reviewed with **changes remaining in the text only**. The
[confirm record](../../zsv1/thermos-review.md#confirm-of-revision-2-2026-11-18) verifies the four original findings
and explains the required cuts to the body and comment draft. The code, comments, message and packaging are
accepted; the retained stats support lobsters -584, but not the claim that every Shipit setivar counter is
unchanged. Builder tests and raw-data provenance are in [results-2.md](../../zsv1/results-2.md). No runtime guard
needs weakening or replacing: only the recorded class changes, and the store checks the actual receiver's shape.
