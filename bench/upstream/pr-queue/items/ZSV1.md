---
id: ZSV1
repo: ruby/ruby
kind: perf
area: ZJIT, setinstancevariable profiling
reviewer: "tekknolagi (filed Shopify/ruby#1122; his #19858 did the same for getinstancevariable)"
branch: thomasklemm/zjit-setivar-real-class
head: "fe6ea9ef84"
base: master
built_on: "7919a47d46"
depends_on: []
stacked_on:
alternative_of:
impact: "eligible ordinary objects with singleton classes get shape-specialized ivar writes instead of recompile exits and a generic final-version fallback; original micro and application numbers below are unverified author claims, not approved speed evidence"
rank: 2
risky: false
state: in-review
pr:
note: "2026-11-18 thermos-sol: changes on exact fe6ea9ef84; no demonstrated correctness/security or structural defect, but trim added comments, substantiate or remove body numbers, qualify ordinary singleton receivers and cut test/A-A narration, then package one fix commit on a refreshed base and re-review. Applies cleanly to Ruby master 4414d3ea25; live Ruby/Shopify searches found no replacement PR, and #1122 remains unassigned. Detailed pass and sentence audit in bench/upstream/zsv1/thermos-review.md. Ruby branch, PR body and comment draft unchanged; not opened. Historical almost-zero Rails reach remains unverified."
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
---

# ZJIT: Profile the real class for setinstancevariable

The profiler records an object whose class is a singleton class as "other" (#19540), so an ivar write on an `extend`ed object has no profile. It side-exits to recompile, and once the ISEQ has used up its versions the final version writes the ivar generically.

`setinstancevariable` uses the profiled class only for shape transitions, and the interpreter looks those up with the real class (`obj_get_owner_class()` in shape.c). This profiles that class instead, so these writes get the same shape guard as any other object's. #19858 did the same for `getinstancevariable` by profiling only the shape.

Fixes Shopify/ruby#1122

The first commit adds two HIR tests that show today's `SideExit NoProfileSetIvar`; the second changes the profile and their snapshots.

A write in a loop, `O = C.new.extend(M)` with `def bump = @a = 1` (Callgrind, `--zjit`, slope over 200,000 calls, `master-aa` a second build of master):

```
master:     475 Ir per call  (setivar_fallback_no_side_exits: 999,869 of 1,000,000 calls)
master-aa:  475 Ir per call
branch:     392 Ir per call  (no generic writes, no side exits)
```

ZJIT stats per iteration for lobsters, leaving out counters that move as much between two runs of master; railsbench and shipit show no change beyond that:

```diff
-dynamic_setivar_count: 11,382
+dynamic_setivar_count: 10,798 (-584)
-setivar_fallback_no_side_exits: 5,951
+setivar_fallback_no_side_exits: 5,367 (-584)
```

## For Thomas

The draft above is preserved as reviewed, not approved for posting. The
[2026-11-18 Thermos record](../../zsv1/thermos-review.md) explains the required comment, evidence, wording and
commit-packaging edits. No runtime guard needs weakening or replacing: only the recorded class changes, and
the existing store still checks the actual receiver's shape.
