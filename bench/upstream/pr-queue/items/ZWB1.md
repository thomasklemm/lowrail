---
id: ZWB1
repo: ruby/ruby
kind: perf
area: ZJIT, compile time (iseq_may_write_block_code)
reviewer: "k0kubun (asked for IseqPayload on #19962 and for a per-compile cache on #19680), tekknolagi (asked on #19962 to reopen #19680)"
branch: thomasklemm/zjit-cache-may-write-block-code-3
head: "35d9707959"
base: master
built_on: "7919a47d46"
depends_on: []
stacked_on:
alternative_of: "tenderlove's open #19962 (same cache in the ISEQ params bit field); only one of them should land"
impact: "#19962's 4,000-call method: compile_time_ns 10.9-12.0 s (master, master-aa, 3 runs each) -> 3.32-3.45 s; no payload is created (payload count and zjit_alloc_bytes on railsbench, lobsters, shipit within the master A/A); IseqPayload stays 152 bytes"
rank: 1
risky: false
state: built
pr:
note: "-3 replaces -2 after the review found -2 created 49 / 74 / 79 extra payloads on railsbench / lobsters / shipit (callee ISEQs via gen_send_iseq_direct), the permanent memory k0kubun objected to on 11-04. tekknolagi reopened the PR on 2026-11-17 22:27; Thomas approved pushing -3 to its branch, replacing the body, marking it ready and posting the comment once a confirm pass approves it (done from the coordinator thread). Merges cleanly onto 3a19e2efcf."
passes:
  - {reviewer: thermos-sol, orb: T-01a1ebfc-9329-7435-b540-a21f11c85c76, head: "35d9707959", date: 2026-11-18, verdict: changes, open: "Parallel independent correctness/security and maintainability reviews, adjudicated here. MUST-FIX P2 (codegen.rs:3482): payload_ptr_as_mut creates a second whole-payload mutable reference while gen_iseq retains its reference from :344 across gen_iseq_body and uses it at :370/:378; gen_entry_point :2927 -> JITFrame::new_iseq -> cache reaches the same ISEQ on ordinary compilation. Smallest fix: borrow only may_write_block_code directly through the raw pointer (also removes the new conversion import), not the whole payload; keep the no-create accessor. Reduced Miri model in this orb's .amp/in/orb-backup/alias-probe: base passed, head reported UB at original-reference budget write after whole-payload retag, field-only form passed; not an observed Ruby miscompilation. MUST-FIX text: tracing does not always preserve the same bare opcode (iseq.c:4073-4077 converts opt_invokebuiltin_delegate_leave to opt_invokebuiltin_delegate); both are outside the five-opcode set, so the predicate is preserved but body/commit explanation must say that or be cut. Scanner returns early: qualify whole-bytecode/quadratic claims as worst case in body/commit. Replace whole-program alloc/counter 'unchanged' with no additional payloads and measured alloc within A/A (only micro alloc totals are exactly equal). DECISIONS: delete narrating test comment; trim added wrapper commentary to necessary why; remove exact cache-state/internal-state assertions from upstream perf test and keep allocation evidence in record. Cut long run-by-run/A/A body and duplicate comment evidence; use meaningful native ZJIT stats diff, omit within-noise app changes. Evidence: exact one-commit parent verified, diff --check clean, fresh master 3a19e2efcf merges cleanly (tree c5782f667d); both PR discussions/inline comments and issue opened with gh; stack-map history 0b9d58fc53 confirms side-exit addition. Traced all four production callers and entry/side-exit frame paths: current/inlined ISEQs already have payloads, callees/blocks may not; 4,000-call win remains at threshold 2. No stale predicate found across profiling/tracing/GC operand rewrites; free clears and drops payload, compaction has no new pointer, compile/stub VM lock disables GC and excludes Ractor races. Numbers match supplied record: nine micro alloc totals 5,190,585; app branch/base deltas 2,140/4,953/4,379 bytes are below A/A 6,671/12,076/12,364; temporary counter rows match shortlist. 152-byte layout and raw benchmark provenance not independently measured; require exact-build size evidence or cut numeric claim. No Ruby build, TracePoint differential or suites run here (another reviewer owns runtime tests). Full sentence audit and findings: https://ampcode.com/artifacts/zwb1-thermos-review-0f8ffee1-efaf-4d2a-8eba-965405afa8f3"}
---

# ZJIT: Cache iseq_may_write_block_code() on the ISEQ payload

`iseq_may_write_block_code()` scans an ISEQ's whole bytecode. JITFrames for CCalls with a frame already called it, and stack maps (#18960) added a call per side exit, so compiling one large method rescans it once per call site and becomes quadratic in method size. The 4,000-call method from #19962 shows it.

This keeps the answer on the ISEQ's payload when it has one. The ISEQ being compiled always has a payload by then, so its repeated checks read the cache. Callee and block ISEQs without a payload are scanned as before, and no payload is created just for this, so `zjit_alloc_bytes` and the number of payloads don't change. The cache is filled lazily at compile time, so ISEQs loaded from IBF need nothing extra. Profiling and tracing rewrite instructions only into variants of the same opcode, which `rb_iseq_bare_opcode_at_pc()` normalizes, so the cached answer stays valid. The `Option<bool>` fits in `IseqPayload`'s padding, so the payload doesn't grow (152 bytes before and after).

Fixes Shopify/ruby#1064

#19962's program (`n = 4000`, `--zjit-call-threshold=2 --zjit-stats-quiet`), three runs each; master-aa is a second build of master:

```
master     run 1  compile_time_ns: 11984524787  compile_lir_time_ns: 11932607905  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
master     run 2  compile_time_ns: 10899149255  compile_lir_time_ns: 10853525037  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
master     run 3  compile_time_ns: 11418361395  compile_lir_time_ns: 11368298109  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
master-aa  run 1  compile_time_ns: 11086115827  compile_lir_time_ns: 11042385292  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
master-aa  run 2  compile_time_ns: 11454296847  compile_lir_time_ns: 11409478356  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
master-aa  run 3  compile_time_ns: 10945650216  compile_lir_time_ns: 10898880863  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
branch     run 1  compile_time_ns:  3325284974  compile_lir_time_ns:  3285272304  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
branch     run 2  compile_time_ns:  3321562569  compile_lir_time_ns:  3278947573  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
branch     run 3  compile_time_ns:  3447826831  compile_lir_time_ns:  3400999066  zjit_alloc_bytes: 5190585  compiled_iseq_count: 4
```

ruby-bench, `--zjit --zjit-stats-quiet`, 2 warmup + 1 iteration:

```
railsbench master:    zjit_alloc_bytes=8037849  compile_time_ns=1406847963 compiled_iseq_count=2596
railsbench master-aa: zjit_alloc_bytes=8044520  compile_time_ns=1446044724 compiled_iseq_count=2596
railsbench branch:    zjit_alloc_bytes=8035709  compile_time_ns=1236088401 compiled_iseq_count=2596
lobsters   master:    zjit_alloc_bytes=17757376 compile_time_ns=4579372904 compiled_iseq_count=5881
lobsters   master-aa: zjit_alloc_bytes=17769452 compile_time_ns=4261788584 compiled_iseq_count=5880
lobsters   branch:    zjit_alloc_bytes=17752423 compile_time_ns=4191311635 compiled_iseq_count=5880
shipit     master:    zjit_alloc_bytes=16346694 compile_time_ns=3681801431 compiled_iseq_count=5805
shipit     master-aa: zjit_alloc_bytes=16359058 compile_time_ns=3792946214 compiled_iseq_count=5805
shipit     branch:    zjit_alloc_bytes=16342315 compile_time_ns=3524031659 compiled_iseq_count=5805
```

`zjit_alloc_bytes` on the branch is within the difference between the two master builds on all three apps.

## Comment draft (not posted)

New head. Since this was closed, stack maps (#18960) added an `iseq_may_write_block_code()` call per side exit, which makes compiling one large method quadratic: #19962's 4,000-call method spends about 11 s in `compile_lir`. The cache now never creates a payload: it is used only when the ISEQ already has one, which the ISEQ being compiled always does, so `zjit_alloc_bytes` and the number of payloads are unchanged.

```
#19962's program, --zjit-call-threshold=2, three runs each
master     compile_time_ns: 11984524787 10899149255 11418361395  zjit_alloc_bytes: 5190585
master-aa  compile_time_ns: 11086115827 11454296847 10945650216  zjit_alloc_bytes: 5190585
branch     compile_time_ns:  3325284974  3321562569  3447826831  zjit_alloc_bytes: 5190585

ruby-bench, payloads created (temporary counter) / zjit_alloc_bytes
railsbench master: 2640 / 8044514   branch: 2640 / 8042427
lobsters   master: 4945 / 17769923  branch: 4945 / 17765632
shipit     master: 4865 / 16359108  branch: 4865 / 16354879
```

The full ruby-bench numbers with a second master build are in the description.
