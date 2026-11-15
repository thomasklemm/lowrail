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
impact: "a `!=` with more than one receiver class (nil or Symbol, Integer or nil, model classes) is specialized per class instead of staying a dynamic send; 4.8x on a tag_options-shaped micro; lobsters -10,323 and shipit -30,074 polymorphic sends per iteration, app times within A/A"
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

The micro is the `tag_options` condition with nil and Symbol types. The apps are within the master-against-master noise; railsbench has no polymorphic `!=`.

```
master: ruby 4.1.0dev (2026-11-15T12:58:58Z master fc4cd8872b) +ZJIT +PRISM [x86_64-linux]
master-aa: ruby 4.1.0dev (2026-11-15T12:58:58Z master fc4cd8872b) +ZJIT +PRISM [x86_64-linux]
branch: ruby 4.1.0dev (2026-11-15T12:58:58Z zjit-polymorphic-neq fc4cd8872b) +ZJIT +PRISM [x86_64-linux]

--------------  -------------  --------------  ------------  -----------------  --------------  ----------------  -------  ---------  -------------  -------  ---------
bench             master (ms)  master-aa (ms)   branch (ms)  master-aa 1st itr  branch 1st itr  master/master-aa  p-value        sig  master/branch  p-value        sig
neq_nil_symbol  153.8 ± 12.1%   184.3 ± 28.1%  31.7 ± 17.8%              1.250           6.125       0.835 (***)  6.7e-04  p < 0.001    4.849 (***)  1.5e-43  p < 0.001
--------------  -------------  --------------  ------------  -----------------  --------------  ----------------  -------  ---------  -------------  -------  ---------

----------  -------------  --------------  -------------  -----------------  --------------  ----------------  -------  ---  -------------  -------  --------
bench         master (ms)  master-aa (ms)    branch (ms)  master-aa 1st itr  branch 1st itr  master/master-aa  p-value  sig  master/branch  p-value       sig
lobsters     778.6 ± 3.9%    775.2 ± 6.9%   814.2 ± 8.7%              0.968           0.953             1.004    0.870               0.956    0.191
railsbench  1732.6 ± 4.7%   1687.5 ± 4.1%  1638.0 ± 3.6%              1.085           0.992             1.027    0.220           1.058 (*)    0.012  p < 0.05
shipit      1460.2 ± 7.2%  1590.9 ± 11.0%  1443.9 ± 4.1%              1.023           1.049             0.918    0.073               1.011    0.692
----------  -------------  --------------  -------------  -----------------  --------------  ----------------  -------  ---  -------------  -------  --------
```

ZJIT stats per iteration, lobsters and then shipit:

```diff
-send_fallback_send_polymorphic: 10,816
+send_fallback_send_polymorphic: 493 (-10323)
```

```diff
-ccall_rb_vm_opt_send_without_block: 1,051,321
+ccall_rb_vm_opt_send_without_block: 1,014,738 (-36583)
-send_fallback_send_polymorphic: 30,333
+send_fallback_send_polymorphic: 259 (-30074)
```
