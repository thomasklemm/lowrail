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
impact: "an ivar write on an extended object gets a shape guard instead of side-exiting and then writing generically: micro 475 -> 392 Ir per call; lobsters -584 generic setivars per iteration, railsbench and shipit unchanged"
rank: 2
risky: false
state: built
pr:
note: "Built 2026-11-17 night; not opened. Stated ask (#1122, tekknolagi) but almost no Rails reach; efegokdemir's Shopify/ruby#1126 for the same issue was closed only because it targeted the wrong repo, so check for a ruby/ruby PR from him before anything is posted. Comment draft in docs/upstream/zjit-shortlist.md. No review passes yet."
passes: []
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
