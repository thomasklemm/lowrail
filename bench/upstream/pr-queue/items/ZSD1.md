---
id: ZSD1
repo: ruby/ruby
kind: perf
area: ZJIT, String#dup
reviewer: "tekknolagi (filed Shopify/ruby#1106)"
branch: thomasklemm/zjit-string-dup
head: "c71669b114"
base: master
built_on: "7919a47d46"
depends_on: []
stacked_on:
alternative_of:
impact: "String#dup on a bare String becomes StringCopy without a frame: micro 388 -> 359 Ir per call (A/A 388); String#dup C calls per iteration railsbench 25,218 -> 0, lobsters 4,243 -> 43, shipit 5,663 -> 12; no app-level claim (about 0.015% of a railsbench iteration)"
rank: 3
risky: false
state: built
pr:
note: "Built 2026-11-17 night; not opened (ZS1 waits for a response). Stated ask (Shopify/ruby#1106, tekknolagi, unassigned, no comments, no PR). The binding constant was added by hand because zjit-bindgen fails in this orb (gcc-configured build); CI's bindgen check would catch a mismatch. The release build used for numbers is be01989e4d, which differs from the head only in two accepted HIR snapshots. Comment draft in docs/upstream/zjit-shortlist.md. No review passes yet."
passes:
  - {reviewer: claude-code, orb: "T-01a1ebdb-b3e7-77a3-a7d4-9c0f1748ea4d", head: "c71669b114", date: 2026-11-18, verdict: changes, open: "MUST-FIX (code, new head): wrong results on a constant receiver. With BUF = +'abc' and def f = BUF.dup, opt_getconstant_path folds BUF to Const Value, String#dup inlines to StringCopy on it, and gen_string_copy takes its constant fast path (rb_zjit_str_resurrect_fastpath), which bakes the compile-time bytes, length and flags of a source it assumes is a frozen dupstring literal: after BUF << 'xyz', force_encoding, replace or clear, f still returns 'abc', UTF-8, 3 bytes at thresholds 1 and 2 (bench/upstream/zsd1/const2.rb; master and the interpreter are right). Smallest fix (bench/upstream/zsd1/fix.diff): in gen_string_copy, ruby_object().filter(|src| src.is_frozen()), so an unfrozen constant takes rb_ec_str_resurrect, plus codegen test test_string_dup_of_mutated_constant, which fails on c71669b114 and passes with the fix; fix build: zjit-test 2,018/2,019, probe identical. Body and draft then need no number change (the micro passes the String as an argument). Rest checked: BARE_STRING_P is exactly StringExact plus SHAPE_ID_HAS_IVAR_MASK (complex shapes included, object_id excluded, like rb_obj_shape_has_ivars); frozen, interned, Ractor-shareable sources dup unfrozen; encoding, coderange, shared and >256-byte embedded sources, broken UTF-8, UTF-16LE, capacity strings, singleton and extended strings (NoSingletonClass), a singleton dup, refinement, prepend on String, redefinition and restore mid-run, ivars added after compilation (side exit, correct), allocation tracing (EC_NEWOBJ_OF, allocation_sourcefile set), TracePoint c_call and GC.stat allocations, GC.compact: probe.rb 62 lines identical interpreter vs ZJIT t1/t2 on master and the fix, 2 lines differ on the head (the constant). Tests on the head: zjit-test 2,017/2,018 (master 2,013/2,014; the same SIGPROF test fails on both), btest t1/t2 all 2,148, test_zjit*/test_string*/test_optimization t1/t2 657 tests 0 failures. make zjit-bindgen regenerates byte-identical bindings once rustfmt is installed (the panic on jit_bindgen_constants is a missing rustfmt, not gcc), so the hand-added constant matches. Micro reproduces as a delta: master 397/397, head 368/368 Ir per call default heap, 250 -> 221 with a 32 MiB heap (gcc release builds, not be01989e4d), so -29 holds and the absolute 388/359 is build-specific. railsbench ccall_String#dup 25,218 (both master runs) -> 0, rb_ec_str_resurrect 558/497 -> 25,780, no guard exits; lobsters and shipit not rerun. Shape is right for a maintainer: reuses StringCopy and the existing GuardNoBitsSet, mirrors YJIT jit_rb_str_dup. Nits: the two-line doc comment on inline_string_dup could be one line; RUBY_DTRACE_CREATE_HOOK(STRING) now fires for String#dup (dtrace only), worth a clause in the body's one-difference sentence; GuardNoIvars could side-exit with recompile like GuardType. Record fixes for the note: the bindgen cause is rustfmt; the earlier 18-receiver probe had no constant receiver."}
---

# ZJIT: Inline String#dup on bare Strings

`String#dup` on a String whose class is exactly String and whose shape has no ivars copies it with `str_duplicate()` and doesn't call `initialize_copy` (`rb_str_dup_m`). ZJIT called it with a frame. It now guards `StringExact` and a shape without ivars, and emits the `StringCopy` that `dupstring` already uses, which calls `rb_ec_str_resurrect()` without a frame. Other receivers keep the C call, and a receiver profiled with ivars is not inlined, so the guard doesn't side-exit on every call.

Fixes Shopify/ruby#1106

`StringCopy` embeds an embedded source of any length, while `str_duplicate()` shares a buffer for embedded sources above 256 bytes; the contents, encoding and flags are the same.

A compiled loop that keeps `s.dup` of a 20-byte String (Callgrind, `--zjit-call-threshold=2`, slope over 200,000 calls, `master-aa` a second build of master):

```
master:     388 Ir per call
master-aa:  388 Ir per call
branch:     359 Ir per call
```

ZJIT stats per iteration for railsbench, lobsters, then shipit, leaving out counters that move as much between two runs of master:

```diff
-ccall_String#dup: 25,218
+ccall_String#dup: 0 (-25218)
-ccall_rb_ec_str_resurrect: 625
+ccall_rb_ec_str_resurrect: 25,852 (+25227)
```

```diff
-ccall_String#dup: 4,243
+ccall_String#dup: 43 (-4200)
-ccall_rb_ec_str_resurrect: 2,041
+ccall_rb_ec_str_resurrect: 6,202 (+4162)
```

```diff
-ccall_String#dup: 5,663
+ccall_String#dup: 12 (-5651)
-ccall_rb_ec_str_resurrect: 56
+ccall_rb_ec_str_resurrect: 5,726 (+5670)
```
