---
id: ZSD1
repo: ruby/ruby
kind: perf
area: ZJIT, String#dup
reviewer: "tekknolagi (filed Shopify/ruby#1106)"
branch: thomasklemm/zjit-string-dup-3
head: "baed628ce1"
base: master
built_on: "3a19e2efcf"
depends_on: []
stacked_on:
alternative_of:
impact: "String#dup on a bare String becomes a frameless rb_str_dup call (StringDup): micro 397 -> 387 Ir per call (A/A 397/397 and 387/387; 250 -> 240 with a fixed heap); railsbench ccall_String#dup 25,218 -> 0, all to rb_str_dup; about 0.005% of a railsbench iteration, no app claim"
rank: 3
risky: false
state: built
pr:
note: "-3 (2026-11-18) fixes the thermos-sol review's two must-fixes on f991b4aa33. (1) Allocation policy: the inline is now a new StringDup instruction, a leaf call to rb_str_dup with gen_prepare_leaf_call_with_gc, instead of StringCopy, so a large embedded source is shared like str_duplicate does; memsize matches the interpreter at every size (thermos_allocation_probe memory: 40 bytes per copy from 232 bytes, was 512). (2) Tracing: Function::assume_no_newobj_hook declines the inline while a NEWOBJ hook is active and otherwise adds PatchPoint NoNewObjHook, the invariant the GC inline allocator already uses, so enabling ObjectSpace tracing later invalidates the code; allocation_class_path/method_id stay [String, :dup] early and late at t1, t2 and max-versions=1. The -2 frozen filter in gen_string_copy is reverted (StringCopy only comes from literals again); test_string_dup_of_mutated_constant still passes. Cost: the gain drops from -29 to -10 Ir per call (rb_str_dup does rb_obj_class, the embed-size check and GET_EC), and production code grows to about 60 lines (50 without blanks and comments). Both are at the stop rule's edge, not past it: the Callgrind A/A is exact (0 Ir), so -10 is outside it. Kept as built; whether a 0.005% change is worth tekknolagi's time is the open call. Measurements, provenance and tests in bench/upstream/zsd1/results-3.txt and zsd3-raw/; new probe zsd3_probe.rb. Needs a fresh review of baed628ce1 before posting. Not opened; comment draft in docs/upstream/zjit-shortlist.md."
passes:
  - reviewer: thermos-sol
    orb: "T-01a1ec04-d888-7083-8490-875ee40d1eb6"
    head: "f991b4aa33"
    date: 2026-11-18
    verdict: changes
    open: >-
      Two reproduced P2 must-fixes, absent on exact base 3a19e2efcf: (1) StringCopy changes String#dup's deliberate allocation policy; a frozen embedded 300-byte argument costs 512 instead of 40 bytes per copy (10,000 retained copies: 5,120,000 vs 400,000 bytes); 232 content bytes already cross the 256-byte allocation cutoff. Keep the guards but use an allocating-leaf rb_str_dup/StringDup, not literal StringCopy. (2) ObjectSpace allocation tracing can report the caller's class/method instead of String#dup, before or after warmup; decline dup inlining while NEWOBJ tracing is active and install NoNewObjHook invalidation for every accepted dup inline. Existing YJIT shares this diagnostic limitation, but base ZJIT does not. No further content/encoding/dispatch/GC/Ractor defect found; mutable-constant fix is sound, including mutable elements of frozen arrays/hashes.
      Dev builds of both pins; make zjit-test head 2,019 passed/15 skipped, base 2,013 passed/1 failed/15 skipped (confirmed known SIGPROF test, which passed in this head run); btest t1/t2 PASS all 2,148 each; requested Ruby files t1/t2 657 tests/39,844 assertions each plus default-excluded memory-leak supplement 16 tests/194 assertions each, all without failures/errors/skips. Existing probes and new 113-line-output differential probe ran interpreter/t1/t2/t1-max-versions=1/t2-max-versions=1 on both pins; only new differences are tracing attribution, plus the same pre-existing 305/303 allocation count. Focused allocation probe reproduces both findings at t1/t2 and t2-max-versions=1.
      Sentence audit and exact evidence in bench/upstream/zsd1/thermos-review.md, with two new probes and verbatim base/head allocation logs. Before publication correct the Ruby-observability, cutoff, same-flags, unconditional DTrace and fallback wording; qualify runtime-valued allocation and supply original benchmark revisions/raw evidence (stored results corroborate -29, not all displayed absolutes). Prefer a narrow allocating leaf preserving canonical dup policy; no unrelated guard-API refactor. Ruby branch and public drafts left unchanged; no fork push or public post.
  - {reviewer: claude-code, orb: "T-01a1ebdb-b3e7-77a3-a7d4-9c0f1748ea4d", head: "c71669b114", date: 2026-11-18, verdict: changes, open: "MUST-FIX (code, new head): wrong results on a constant receiver. With BUF = +'abc' and def f = BUF.dup, opt_getconstant_path folds BUF to Const Value, String#dup inlines to StringCopy on it, and gen_string_copy takes its constant fast path (rb_zjit_str_resurrect_fastpath), which bakes the compile-time bytes, length and flags of a source it assumes is a frozen dupstring literal: after BUF << 'xyz', force_encoding, replace or clear, f still returns 'abc', UTF-8, 3 bytes at thresholds 1 and 2 (bench/upstream/zsd1/const2.rb; master and the interpreter are right). Smallest fix (bench/upstream/zsd1/fix.diff): in gen_string_copy, ruby_object().filter(|src| src.is_frozen()), so an unfrozen constant takes rb_ec_str_resurrect, plus codegen test test_string_dup_of_mutated_constant, which fails on c71669b114 and passes with the fix; fix build: zjit-test 2,018/2,019, probe identical. Body and draft then need no number change (the micro passes the String as an argument). Rest checked: BARE_STRING_P is exactly StringExact plus SHAPE_ID_HAS_IVAR_MASK (complex shapes included, object_id excluded, like rb_obj_shape_has_ivars); frozen, interned, Ractor-shareable sources dup unfrozen; encoding, coderange, shared and >256-byte embedded sources, broken UTF-8, UTF-16LE, capacity strings, singleton and extended strings (NoSingletonClass), a singleton dup, refinement, prepend on String, redefinition and restore mid-run, ivars added after compilation (side exit, correct), allocation tracing (EC_NEWOBJ_OF, allocation_sourcefile set), TracePoint c_call and GC.stat allocations, GC.compact: probe.rb 62 lines identical interpreter vs ZJIT t1/t2 on master and the fix, 2 lines differ on the head (the constant). Tests on the head: zjit-test 2,017/2,018 (master 2,013/2,014; the same SIGPROF test fails on both), btest t1/t2 all 2,148, test_zjit*/test_string*/test_optimization t1/t2 657 tests 0 failures. make zjit-bindgen regenerates byte-identical bindings once rustfmt is installed (the panic on jit_bindgen_constants is a missing rustfmt, not gcc), so the hand-added constant matches. Micro reproduces as a delta: master 397/397, head 368/368 Ir per call default heap, 250 -> 221 with a 32 MiB heap (gcc release builds, not be01989e4d), so -29 holds and the absolute 388/359 is build-specific. railsbench ccall_String#dup 25,218 (both master runs) -> 0, rb_ec_str_resurrect 558/497 -> 25,780, no guard exits; lobsters and shipit not rerun. Shape is right for a maintainer: reuses StringCopy and the existing GuardNoBitsSet, mirrors YJIT jit_rb_str_dup. Nits: the two-line doc comment on inline_string_dup could be one line; RUBY_DTRACE_CREATE_HOOK(STRING) now fires for String#dup (dtrace only), worth a clause in the body's one-difference sentence; GuardNoIvars could side-exit with recompile like GuardType. Record fixes for the note: the bindgen cause is rustfmt; the earlier 18-receiver probe had no constant receiver."}
---
# ZJIT: Inline String#dup on bare Strings

`String#dup` on a String whose class is exactly String and whose shape has no ivars copies it with `str_duplicate()` and doesn't call `initialize_copy` (`rb_str_dup_m`). ZJIT called it with a frame. It now guards `StringExact` and a shape without ivars and calls `rb_str_dup()`, which makes the same copy, as a leaf call without a frame (new `StringDup` instruction). Other receivers are dispatched as before, and a receiver that had ivars when it was profiled is not inlined, so the guard doesn't side-exit on every call.

Fixes Shopify/ruby#1106

This isn't the `StringCopy` that `dupstring` uses: `rb_ec_str_resurrect()` embeds an embedded source of any size, while `str_duplicate()` shares the source's buffer when an embedded copy would need more than 256 bytes (232 content bytes here), which `ObjectSpace.memsize_of` shows.

Without `String#dup`'s frame, `ObjectSpace` allocation tracing would attribute the copy to the caller, so the inline is skipped while a NEWOBJ hook is active, and a `NoNewObjHook` patch point invalidates the code when one is enabled later, like the inline allocator does.

A compiled loop that keeps `s.dup` of a 20-byte String (Callgrind, `--zjit-call-threshold=2`, slope over 200,000 calls; release builds of `3a19e2efcf` and this commit, GCC 14.2; each built and measured twice):

```
master:  397 Ir per call (A/A 397)
branch:  387 Ir per call (A/A 387)
```

ZJIT stats per iteration for railsbench (ruby-bench `73918b2`, 15 warmup + 10 iterations; two master runs agree on both counters):

```diff
-ccall_String#dup: 25,218
+ccall_String#dup: 0
-ccall_rb_str_dup: 0
+ccall_rb_str_dup: 25,218
```
