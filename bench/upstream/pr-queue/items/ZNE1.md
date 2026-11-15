---
id: ZNE1
repo: ruby/ruby
kind: perf
area: ZJIT, opt_neq
reviewer: "tekknolagi (polymorphic dispatch, #15949) or nozomemein (BasicObject#!= builtin, #19162)"
branch: zjit-opt-neq-polymorphic
head: "18d33e8a24"
base: master
built_on: "fc4cd8872b"
depends_on: []
stacked_on:
alternative_of:
impact: "a `!=` with more than one receiver class (nil or Symbol, Integer or nil, model classes) is specialized per class instead of staying a dynamic send; 4.6x on a tag_options-shaped micro (4.4x to 5.1x in three rounds); lobsters -10,323 and shipit -30,074 polymorphic sends per iteration, app times within A/A"
rank: 3
risky: true
state: ready
pr: 19909
note: "DECISIONS exception of 2026-11-15, answers skipkayhil's close of rails/rails#59811. claude-code (nits), opus (nits) and fable (approve) have no must-fix on head 18d33e8a24, so Thomas can open it as a draft once the thermos gate is passed or waived; arm64 is green (ARM1, T-01a1e00a-99a3-7183-9a14-acf3268bdc46: zjit-test 2,241 of 2,241 on 18d33e8a24; probe, btest and Active Model on 52d41cc992, same code). Earlier head 52d41cc992 was on fork branch zjit-polymorphic-neq, deleted 2026-11-15 after the PR opened; 18d33e8a24 changes one test, one test comment and the commit message. The body shows the three-way run_benchmarks output with the master-against-master columns by the coordinator's instruction for this item. The diff is 259 changed lines, 229 of them tests and snapshots, so the thermos gate applies or needs a waiver. Record: docs/upstream/zjit-not-equal.md."
waived:
  - {reviewer: thermos, head: "18d33e8a24", by: "coordinator, 2026-11-15", reason: "26 changed lines in hir.rs, the rest tests and snapshots; three independent passes on the exact head (Fable adversarial on exactness and invalidation, 22 attack scripts in 9 configurations and about 1,280 fuzz run pairs), a guard-removal check against the new tests, and arm64 coverage by ARM1. Optional nits left as is: the commit message's invalidation paragraph (would need a new head) and the 169-word body"}
passes:
  - {reviewer: claude-code, orb: T-01a1e017-0b4b-7405-a5c9-6e381e0a03bb, head: "52d41cc992", date: 2026-11-15, verdict: changes, open: "body only: over 150 words, two tables, a sentence that contradicted its table; code, tests, probe and 14 guard-breaking scripts without a finding; commit-message wording nits applied in 18d33e8a24"}
  - {reviewer: opus, orb: T-01a1e017-14c1-7599-8e9c-3e9b47151185, head: "52d41cc992", date: 2026-11-15, verdict: changes, open: "superfluous first sentence of the comment in test_opt_neq_polymorphic_refined, fixed in 18d33e8a24; 13 scripts and 7 mutations without a finding; body too long"}
  - {reviewer: fable, orb: T-01a1e017-1db1-700f-a67e-f8584f45187d, head: "52d41cc992", date: 2026-11-15, verdict: nits, open: "adversarial on exactness and invalidation: 189 script-configuration pairs and 1,170 fuzz run pairs, no master/branch difference; test_opt_neq_polymorphic did not discriminate the fallback Send (fixed in 18d33e8a24); say no new kind of assumption (applied)"}
  - {reviewer: opus, orb: T-01a1e017-14c1-7599-8e9c-3e9b47151185, head: "18d33e8a24", date: 2026-11-15, verdict: changes, open: "code, tests, comments and commit message without a must-fix; body said master-aa is a second build of master while the numbers shown used one binary twice; fixed by the pinned rounds, which use a second build"}
  - {reviewer: fable, orb: T-01a1e017-1db1-700f-a67e-f8584f45187d, head: "18d33e8a24", date: 2026-11-15, verdict: approve, open: "198 attack-script pairs and 108 new fuzz pairs without a difference; corrected the record: NoSingletonClass is the only guard when the class check folds away for a constant receiver, as on master"}
  - {reviewer: opus, orb: T-01a1e017-14c1-7599-8e9c-3e9b47151185, head: "18d33e8a24", date: 2026-11-15, verdict: nits, open: "body at Lowrail 0541b1a: block, round choice and stats claims recomputed from the committed files; applied: the body says the table is the quietest of three rounds, stats-diff header reworded, record corrected on railsbench in rounds 1 and 2"}
  - {reviewer: claude-code, orb: T-01a1e017-0b4b-7405-a5c9-6e381e0a03bb, head: "18d33e8a24", date: 2026-11-15, verdict: nits, open: "body at Lowrail f55ebfc, every sentence recomputed from the committed files; optional and not applied: the commit message's last paragraph could also name a singleton class on an instance of a profiled class as an invalidation trigger (would need a new head); body is 169 words"}
---

# ZJIT: Specialize polymorphic opt_neq

`x != y` on nil, Symbols and plain objects uses `BasicObject#!=`, which ZJIT inlines since #19162 when a call site sees one receiver class. With more than one it stays a dynamic send, as in `type != :aria && type != :class` in Action View's `tag_options`, where `type` is nil or a Symbol. My rails/rails#59811 rewrote that line and was closed with ["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59811#issuecomment-6895930722).

`opt_neq` had its own arm in the HIR builder, because its `!=` call data is the second operand, and that arm skipped the dispatch on profiled receiver classes that other sends get. It now shares their arm: each profiled class takes the path a monomorphic `!=` already takes, with the same patch points, and any other class takes the original send.

`neq_nil_symbol` runs that condition in a loop, and `master-aa` is a second build of master; the table is the quietest of three rounds. lobsters and shipit lose about 10,000 and 30,000 polymorphic sends per iteration; their times stay within noise.

```
master: ruby 4.1.0dev (2026-11-15T12:58:58Z master fc4cd8872b) +ZJIT +PRISM [x86_64-linux]
master-aa: ruby 4.1.0dev (2026-11-15T12:58:58Z master fc4cd8872b) +ZJIT +PRISM [x86_64-linux]
branch: ruby 4.1.0dev (2026-11-15T17:35:02Z zjit-opt-neq-polymorphic 18d33e8a24) +ZJIT +PRISM [x86_64-linux]

--------------  -------------  --------------  -------------  -----------------  --------------  ----------------  -------  ---  -------------  -------  ---------
bench             master (ms)  master-aa (ms)    branch (ms)  master-aa 1st itr  branch 1st itr  master/master-aa  p-value  sig  master/branch  p-value        sig
lobsters        787.7 ± 10.7%    782.1 ± 5.7%   785.9 ± 9.3%              1.082           1.074             1.007    0.863               1.002    0.963
railsbench      1660.6 ± 4.0%   1668.1 ± 2.6%  1701.3 ± 3.9%              1.033           0.945             0.995    0.779               0.976    0.208
shipit          1347.1 ± 3.3%   1345.9 ± 6.1%  1346.4 ± 4.8%              0.991           0.997             1.001    0.969               1.000    0.981
neq_nil_symbol   144.9 ± 6.6%    146.4 ± 8.9%   31.6 ± 20.9%              1.108           5.238             0.990    0.497         4.583 (***)  2.0e-65  p < 0.001
--------------  -------------  --------------  -------------  -----------------  --------------  ----------------  -------  ---  -------------  -------  ---------
```

ZJIT stats per iteration for lobsters, then shipit, leaving out counters that move as much between two runs of master:

```diff
-ccall_String#==: 1,359
+ccall_String#==: 1,242 (-117)
-ccall_rb_vm_opt_send_without_block: 434,680
+ccall_rb_vm_opt_send_without_block: 423,868 (-10813)
-dynamic_send_count: 783,048
+dynamic_send_count: 772,237 (-10811)
-getivar_fallback_no_side_exits: 144,858
+getivar_fallback_no_side_exits: 143,037 (-1821)
-not_inlined_cfuncs_String#==: 1,359
+not_inlined_cfuncs_String#==: 1,242 (-117)
-send_fallback_send_polymorphic: 10,816
+send_fallback_send_polymorphic: 493 (-10323)
```

```diff
-ccall_rb_vm_opt_send_without_block: 1,051,321
+ccall_rb_vm_opt_send_without_block: 1,014,738 (-36583)
-dynamic_send_count: 1,877,801
+dynamic_send_count: 1,841,220 (-36581)
-send_fallback_send_polymorphic: 30,333
+send_fallback_send_polymorphic: 259 (-30074)
```
