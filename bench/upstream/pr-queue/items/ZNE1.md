---
id: ZNE1
repo: ruby/ruby
kind: perf
area: ZJIT, opt_neq
reviewer: "tekknolagi (polymorphic dispatch, #15949) or nozomemein (BasicObject#!= builtin, #19162)"
branch: thomasklemm/zjit-polymorphic-neq
head: "52d41cc992"
base: master
built_on: "fc4cd8872b"
depends_on: []
stacked_on:
alternative_of:
impact: "a `!=` with more than one receiver class (nil or Symbol, Integer or nil, model classes) is specialized per class instead of staying a dynamic send; about 5x on a tag_options-shaped micro; lobsters -10,323 and shipit -30,074 polymorphic sends per iteration, app times within A/A"
rank: 3
risky: true
state: in-review
pr:
note: "DECISIONS exception of 2026-11-15, answers skipkayhil's close of rails/rails#59811. Thomas opens it as a draft once claude-code, opus and fable approve the head and ARM1 (T-01a1e00a-99a3-7183-9a14-acf3268bdc46) reports arm64 green. Record: docs/upstream/zjit-not-equal.md."
passes: []
---

# ZJIT: Specialize polymorphic opt_neq

`x != y` on nil, Symbols and plain objects is everywhere in Ruby and Rails code, and all of them use `BasicObject#!=`. Since #19162 ZJIT inlines it when the call site sees one receiver class. With more than one, the `!=` stays a dynamic send. Action View's `tag_options` has such a site, `type != :aria`, where `type` is nil or a Symbol. rails/rails#59811 rewrote that line for the JITs and was closed with ["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59811#issuecomment-6895930722), so this handles the pattern in ZJIT.

`opt_neq` had its own arm in the HIR builder, because its `!=` call data is the second operand. That arm skipped the dispatch on profiled receiver classes that the other `opt_*` instructions get. It now shares their arm. Each profiled class takes the path a monomorphic `!=` already takes, behind a type check: `!=` and `==` are resolved for that class under their `MethodRedefined` patch points, and a receiver the profile has not seen takes the original send. So this adds no new assumption.

The micro is the `tag_options` condition with nil and Symbol types. The apps are within the noise of master against master (`master-aa`); railsbench runs no polymorphic `!=`.

```
master: ruby 4.1.0dev (2026-11-15T12:58:58Z master fc4cd8872b) +ZJIT +PRISM [x86_64-linux]
master-aa: ruby 4.1.0dev (2026-11-15T12:58:58Z master fc4cd8872b) +ZJIT +PRISM [x86_64-linux]
branch: ruby 4.1.0dev (2026-11-15T16:33:27Z zjit-polymorphic-neq 52d41cc992) +ZJIT +PRISM [x86_64-linux]

--------------  -------------  --------------  ------------  -----------------  --------------  ----------------  -------  ---------  -------------  -------  ---------
bench             master (ms)  master-aa (ms)   branch (ms)  master-aa 1st itr  branch 1st itr  master/master-aa  p-value        sig  master/branch  p-value        sig
neq_nil_symbol  184.6 ± 17.5%   157.2 ± 14.0%  31.8 ± 17.1%              0.968           3.237       1.175 (***)  3.4e-05  p < 0.001    5.810 (***)  1.1e-27  p < 0.001
--------------  -------------  --------------  ------------  -----------------  --------------  ----------------  -------  ---------  -------------  -------  ---------

----------  -------------  --------------  -------------  -----------------  --------------  ----------------  -------  --------  -------------  -------  ---
bench         master (ms)  master-aa (ms)    branch (ms)  master-aa 1st itr  branch 1st itr  master/master-aa  p-value       sig  master/branch  p-value  sig
lobsters     885.5 ± 5.2%    939.8 ± 5.8%   850.1 ± 9.4%              0.940           0.968         0.942 (*)    0.036  p < 0.05          1.042    0.268
railsbench  1793.6 ± 7.6%  1800.6 ± 12.0%  1706.0 ± 3.6%              0.889           0.889             0.996    0.935                    1.051    0.104
shipit      1474.7 ± 7.8%   1395.1 ± 6.3%  1417.7 ± 3.9%              0.923           0.952             1.057    0.118                    1.040    0.204
----------  -------------  --------------  -------------  -----------------  --------------  ----------------  -------  --------  -------------  -------  ---
```

ZJIT stats per iteration, lobsters and then shipit, leaving out what also moves between two runs of master:

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
