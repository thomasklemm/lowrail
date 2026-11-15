---
id: ZS1
repo: ruby/ruby
kind: perf
area: ZJIT, sends with a Symbol block argument
reviewer: "tekknolagi and k0kubun (ZJIT), rafaelfranca (author of the branch the first commit comes from)"
branch: thomasklemm/zjit-symbol-block-arg
head: "89e2da1571"
base: master
built_on: "3be2b028a7"
depends_on: []
stacked_on:
alternative_of:
impact: "foo(&:sym) to ISEQ and C callees no longer falls back to a dynamic send under ZJIT; railsbench on Rails main: 42,441 of 115,090 block-arg fallbacks per iteration"
rank: 1
risky: true
state: reviewed
pr:
note: "reopened 2026-11-15 after skipkayhil closed rails/rails#59803 with 'Let's fix this in the JITs?'; first commit is the Symbol part of Rafael França's Shopify/ruby zjit-perf/blockarg-direct-send (3f17d8950e), he is its author (coordinator: the design is his); the coordinator opens the draft after the three passes approve on the head; earlier heads dcd4bd2b79, 7eddd8bfce, 09d8e5308e; arm64 green on all four heads including 89e2da1571 (ARM1: zjit-test 2249/2249, test_zjit_cli 34 tests, probe diffs empty, zjit-bindgen leaves cruby_bindings.inc.rs unchanged); 89e2da1571 differs from 09d8e5308e in two tests, a rename, a comment and the bindgen entry, no generated code; all three passes on 89e2da1571 without a must-fix; body carries the run_benchmarks output and stats diff of the final code; record docs/upstream/zjit-symbol-block.md"
waived:
  - {reviewer: thermos, head: "89e2da1571", by: "coordinator, 2026-11-15", reason: "three independent passes on the exact head (Fable adversarial on exactness and invalidation, with a readability and ZJIT-style note), a mutation check of every guard, and arm64 coverage by ARM1"}
passes:
  - {reviewer: opus, head: "7eddd8bfce", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: changes, open: "no behaviour difference found; must-fix: body called Array#map a C method and gave one fallback reason for both callee kinds, and a profiled-Symbol guard was emitted in front of a C-callee send that stays dynamic (splat, kwargs); all three fixed in 09d8e5308e, with the optional points taken: one helper for the patch points, behaviour test for the C-callee patch points, trivial-inliner skip removed, CCallVariadic prints its block"}
  - {reviewer: fable, head: "7eddd8bfce", orb: T-01a1e02a-5156-7535-b82d-6fdecf19860d, date: 2026-11-15, verdict: changes, open: "must-fix: with RUBY_BOX=1 a box that redefines Symbol#to_proc got the plain Symbol as block handler; fixed in 09d8e5308e (no specialization once a non-root box exists, RootBoxOnly patch point, CLI test). Leaf-call, GC and invalidation questions settled with source lines and runs; readability: reads like the surrounding code, asked for the patch-point helper and the CCallVariadic printer, both done"}
  - {reviewer: claude-code, head: "7eddd8bfce", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: changes, open: "must-fix: Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc)) clears the basic flag in place without invalidating the entry, so the patch point never fired and compiled code kept the refined lambda; fixed in 09d8e5308e (the conversion checks the watched entry's flag and exits, with a test). Body Array#map sentence fixed"}
  - {reviewer: opus, head: "09d8e5308e", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: nits, open: "no must-fix; the three earlier must-fixes are resolved and the flag check and box check read correctly; found that removing PatchPoint RootBoxOnly fails no test and that no program needs it; optional points taken in 89e2da1571: commit message wording (line length, 'no box has been created with Ruby::Box.new'), cfunc_callee renamed, zjit.c comment shortened; not taken: carrying the to_proc entry in BlockArgSymbol"}
  - {reviewer: claude-code, head: "09d8e5308e", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: nits, open: "no must-fix; flag check equivalent to rb_method_basic_definition_p in 16 single changes, 8 sequences with GC.compact and under RUBY_BOX=1; exit after the leaf call right; nits taken in 89e2da1571: the self-redefinition test now fails on all three paths (proc and Proc.new as C callees), the redefined-after-compile warm-up, the bindgen allowlist entry, commit message line length"}
  - {reviewer: opus, head: "89e2da1571", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: approve, open: "delta from 09d8e5308e read and rerun: zjit-bindgen regenerates cruby_bindings.inc.rs with no diff; the self-redefinition test covers SendDirect, CCallWithFrame and CCallVariadic and fails without the flag check; removing the Symbol#to_proc patch point at any one call site fails the redefined-after-compile test; probe and break scripts match. Optional: five lines of commit 1's message are 73 characters"}
  - {reviewer: fable, head: "89e2da1571", orb: T-01a1e02a-5156-7535-b82d-6fdecf19860d, date: 2026-11-15, verdict: nits, open: "no must-fix, adversarial on exactness, invalidation and GC: 396 combinations of a Symbol#to_proc change, setup and timing match at four settings; the baked entry survives compaction; the only code that changes the basic bit of an existing entry is vm_method.c:1851 and all three ways to reach it are handled; the Qundef exit is built from the original send's frame state. Optional, not applied: recompile on the Qundef exit (it exits on every call after a same-definition define), a guard in front of a dynamic send for an argc mismatch and for an ISEQ callee that ignores its block, carrying the entry from the patch point to codegen; body should mention the run-time flag check (done). RootBoxOnly and the GC preparation have no failing test and no failing program. Readability: reads like the code around it"}
  - {reviewer: claude-code, head: "89e2da1571", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: approve, open: "delta from 09d8e5308e is two tests, a rename, a comment and the bindgen entry; zjit-bindgen regenerates cruby_bindings.inc.rs byte-identical; removing the patch points on one path fails the redefined-after-compile test ([4, [30], 30], [300, [4], 30], [300, [30], 4]) and removing the flag check fails the self-redefinition test; single-threaded zjit-test 2007/2007, CLI 34 tests, probe and break scripts match. Optional: five 73-character lines in commit 1's message; body to be cut (done)"}
---

# ZJIT: Send Symbol block arguments directly

Under ZJIT, a send with a Symbol block argument such as `foo(&:sym)` stays a dynamic send. rails/rails#59803 worked around that in Active Record and was closed with ["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59803#issuecomment-6895904455). This is the send side of that fix, the Symbol case that #18180 left for later (Shopify/ruby#1014).

A static Symbol block argument now compiles to `SendDirect` for ISEQ callees and to `CCallWithFrame` or `CCallVariadic` for C functions such as `Array#reject`. The Symbol becomes the block handler through the code `vm_caller_setup_arg_block` already runs for it, so refinements behave as in the interpreter. The send is specialized only while `Symbol#to_proc` is basic and no `Ruby::Box` has been created. The callee's `yield` is unchanged.

The first commit is the Symbol part of Rafael Mendonça França's [`zjit-perf/blockarg-direct-send`](https://github.com/Shopify/ruby/tree/zjit-perf/blockarg-direct-send) branch, ported to master. His branch also sends forwarded block parameters directly; that part is left to Shopify/ruby#1039.

`attr-read` runs the attribute reads of rails/rails#59803, and `symbol-block` runs `one(i, &:itself)` and `[1, 2, 3].map(&:itself)`. `master-again` is the same build of master a second time; the apps do not move beyond noise.

```
master: ruby 4.1.0dev (2026-11-15T09:48:53Z HEAD 3be2b028a7) +ZJIT +PRISM [x86_64-linux]
master-again: ruby 4.1.0dev (2026-11-15T09:48:53Z HEAD 3be2b028a7) +ZJIT +PRISM [x86_64-linux]
symbol-block-arg: ruby 4.1.0dev (2026-11-15T18:34:39Z HEAD 656ae95dbc) +ZJIT +PRISM [x86_64-linux]
ruby-bench: 73918b2fc1a84702fea63e06f64d179751d69df4-dirty

------------  -------------  -----------------  ---------------------  --------------------  ------------------------  -------------------  -----------------------
bench           master (ms)  master-again (ms)  symbol-block-arg (ms)  master-again 1st itr  symbol-block-arg 1st itr  master/master-again  master/symbol-block-arg
lobsters       960.4 ± 8.3%       954.9 ± 7.9%           917.2 ± 4.9%                 1.041                     0.974                1.006                    1.047
railsbench    1531.6 ± 7.4%      1521.8 ± 7.0%          1524.6 ± 6.0%                 1.017                     0.994                1.006                    1.005
shipit        1295.4 ± 9.4%     1411.5 ± 11.5%          1399.0 ± 6.8%                 1.042                     1.105                0.918                    0.926
attr-read      308.4 ± 7.2%       303.4 ± 5.9%           270.6 ± 9.7%                 0.997                     0.998                1.016                    1.139
symbol-block   380.6 ± 7.3%       367.9 ± 7.3%          310.2 ± 10.5%                 0.972                     1.105                1.035                    1.227
------------  -------------  -----------------  ---------------------  --------------------  ------------------------  -------------------  -----------------------
```

ZJIT stats for 25 iterations of railsbench, then lobsters, then shipit, leaving out counters that move as much between two runs of master:

```diff
 calls to C functions from JIT code:
-  rb_vm_send: 5,945,619
+  rb_vm_send: 4,879,037
-send fallback reasons (total): 23,062,604
+send fallback reasons (total): 21,996,028
 send fallback reasons:
-  send_block_arg_not_nil: 2,880,681
+  send_block_arg_not_nil: 2,068,088
-  one_or_more_complex_arg_pass: 2,631,868
+  one_or_more_complex_arg_pass: 2,377,877
-dynamic_send_count: 23,062,604
+dynamic_send_count: 21,996,028
-iseq_optimized_send_count: 78,334,168
+iseq_optimized_send_count: 79,584,504
-vm_write_stack_count: 72,548,064
+vm_write_stack_count: 71,735,501
```

```diff
 calls to C functions from JIT code:
-  rb_vm_send: 2,385,653
+  rb_vm_send: 1,664,764
-send fallback reasons (total): 21,240,260
+send fallback reasons (total): 20,527,432
 send fallback reasons:
-  send_block_arg_not_nil: 1,430,280
+  send_block_arg_not_nil: 951,550
-  one_or_more_complex_arg_pass: 987,312
+  one_or_more_complex_arg_pass: 745,157
-dynamic_send_count: 21,240,260
+dynamic_send_count: 20,527,432
-iseq_optimized_send_count: 46,404,245
+iseq_optimized_send_count: 46,915,275
-non_variadic_cfunc_optimized_send_count: 14,617,275
+non_variadic_cfunc_optimized_send_count: 14,795,608
-guard_type_count: 98,542,681
+guard_type_count: 99,553,608
```

```diff
-not inlined C methods (total): 37,368,932
+not inlined C methods (total): 37,749,771
 not inlined C methods:
-  Enumerable#flat_map: 343,572
+  Enumerable#flat_map: 371,774
 calls to C functions from JIT code:
-  rb_vm_send: 5,364,592
+  rb_vm_send: 4,115,154
-send fallback reasons (total): 44,569,405
+send fallback reasons (total): 43,091,646
 send fallback reasons:
-  send_polymorphic_fallback: 21,397,981
+  send_polymorphic_fallback: 21,169,657
-  send_block_arg_not_nil: 4,163,172
+  send_block_arg_not_nil: 3,294,392
-  one_or_more_complex_arg_pass: 1,663,755
+  one_or_more_complex_arg_pass: 1,283,100
-dynamic_send_count: 44,569,405
+dynamic_send_count: 43,091,646
-iseq_optimized_send_count: 85,127,837
+iseq_optimized_send_count: 86,225,319
-non_variadic_cfunc_optimized_send_count: 19,246,354
+non_variadic_cfunc_optimized_send_count: 19,567,384
-vm_write_stack_count: 86,844,780
+vm_write_stack_count: 85,747,865
```
