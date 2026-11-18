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
impact: "eligible ordinary objects with singleton classes get shape-specialized ivar writes instead of recompile exits and a generic final-version fallback; lobsters -584 generic setivar per iteration (master/master-aa/branch stats, bench/upstream/zsv1/results-2.md), railsbench and shipit setivar counters unchanged; no time claim"
rank: 2
risky: false
state: in-review
pr:
note: "2026-11-18 -2 47b2ed7110: fix round for thermos-sol changes on fe6ea9ef84. One commit on master 4414d3ea25 (old branch kept); test comments and constructor doc comment removed, rationale cut to one why-line; ordinary singleton receivers and the existing layout/frozen/capacity checks named in message and body; micro figures cut; lobsters -584 re-measured as a master/master-aa/branch ZJIT stats diff with raw JSON (bench/upstream/zsv1/results-2.md). zjit-test 2016 passed/15 skipped; btest t1 and t2 2148; selected suites 323 tests/15405 assertions at t1 and t2. Needs a fresh pass on 47b2ed7110. Not opened, nothing posted. Earlier: 2026-11-18 thermos-sol: changes on exact fe6ea9ef84; no demonstrated correctness/security or structural defect, but trim added comments, substantiate or remove body numbers, qualify ordinary singleton receivers and cut test/A-A narration, then package one fix commit on a refreshed base and re-review. Applies cleanly to Ruby master 4414d3ea25; live Ruby/Shopify searches found no replacement PR, and #1122 remains unassigned. Detailed pass and sentence audit in bench/upstream/zsv1/thermos-review.md. Ruby branch, PR body and comment draft unchanged; not opened. Historical almost-zero Rails reach remains unverified."
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

The profiler records an ordinary object with a singleton class as "other" (#19540), so an ivar write on an `extend`ed object has no profile. It side-exits to recompile, and once the ISEQ has used up its versions the final version writes the ivar generically.

`setinstancevariable` uses the profiled class only for shape transitions, and the interpreter looks those up with the real class (`obj_get_owner_class()` in shape.c). This profiles that class instead, so these writes get the same shape guard as any other object's, still subject to the existing layout, frozen and capacity checks. #19858 did the same for `getinstancevariable` by profiling only the shape.

Fixes Shopify/ruby#1122

ZJIT stats per iteration for lobsters, leaving out counters that move as much between two runs of master; railsbench and shipit show no change in setivar counters:

```diff
-dynamic_setivar_count: 11,405
+dynamic_setivar_count: 10,821 (-584)
-setivar_fallback_no_side_exits: 5,956
+setivar_fallback_no_side_exits: 5,372 (-584)
```

## For Thomas

The body above is the -2 draft for `47b2ed7110`, not yet reviewed. What changed for each must-fix of the
[2026-11-18 Thermos record](../../zsv1/thermos-review.md), the tests and the stats evidence (raw data, A/A) are in
[results-2.md](../../zsv1/results-2.md). The stats diff omits `ccall_rb_vm_setinstancevariable` (−584, the same
calls). The micro figures were cut rather than re-measured. No runtime guard needs weakening or replacing: only the recorded class changes, and
the existing store still checks the actual receiver's shape.
