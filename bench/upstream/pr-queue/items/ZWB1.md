---
id: ZWB1
repo: ruby/ruby
kind: perf
area: ZJIT, compile time (iseq_may_write_block_code)
reviewer: "k0kubun (asked for IseqPayload on #19962 and for a per-compile cache on #19680), tekknolagi (asked on #19962 to reopen #19680)"
branch: thomasklemm/zjit-cache-may-write-block-code-4
head: "25e91f0d07"
base: master
built_on: "3a19e2efcf"
depends_on: []
stacked_on:
alternative_of: "tenderlove's open #19962 (same cache in the ISEQ params bit field); only one of them should land"
impact: "#19962's 4,000-call method: compile_time_ns 11.35-11.89 s on master (master-aa 10.98-11.44 s) -> 3.27-3.60 s, 3 runs each; no payload is created (payload counts on railsbench, lobsters, shipit equal to master); IseqPayload stays 152 bytes (gdb on master and -4)"
rank: 1
risky: false
state: built
pr:
note: "-4 (2026-11-18) takes thermos-sol's and claude-code's review of -3: the cache borrows only may_write_block_code through the raw pointer instead of a second whole-payload &mut while gen_iseq() holds one (UB under Stacked Borrows in a reduced Miri model, bench/upstream/zwb1/miri; -4 is clean under Stacked and Tree Borrows); payload_ptr_as_mut import dropped. Not fixed here: the overlapping whole-payload &mut that master already has for the compiled ISEQ (add_iseq_to_hir, CompilePolicy::new while gen_iseq's reference is live); a separate change if a reviewer asks. Text: no opcode-variant claim (tracing turns opt_invokebuiltin_delegate_leave into opt_invokebuiltin_delegate; neither is scanned), worst case qualified, quadratic predates stack maps, no unchanged-alloc claim, body cut to one native stats diff, test without the ask-twice loop and cache-state assert. One commit on 3a19e2efcf. #19680's branch untouched (8cedf94b75); the coordinator thread pushes and posts after a confirm pass."
passes:
  - {reviewer: claude-code, head: "82c529aa2e", orb: T-01a1ebca-06fe-74a0-bfb2-9eb5a87e98d5, date: 2026-11-18, verdict: changes, open: "superseded by -3. Must-fix (taken in -3): iseq_may_write_block_code() created payloads for payload-less callee ISEQs (gen_send_iseq_direct :1938), railsbench (3 iterations) zjit_alloc_bytes 7,515,644 -> 7,522,788 (+7,144 B = 47 x 152 B) on every run, gdb counts 2,702 -> 2,745 rb_iseq_set_jit_payload calls (274 from this function), so 'the payload doesn't grow' hid exactly the permanent memory k0kubun objected to on 11-04. Claim fix: JITFrames per CCall with a frame called it before #18960 too (checked on a1ec8907bc^); #18960 added the per-side-exit JITFrame in build_side_exit. Otherwise sound: 152 B on both release builds (gdb, 2-byte tail padding on master), 4,000-call program master 13.20/13.66 s -> 3.54/3.57 s, zjit_alloc_bytes 5,191,369 both; zjit-test 2014/2015, btest 1 and 2 all 2148, test_zjit_cli+test_optimization 143 at 1 and 2; cross-check build (cached answer asserted equal to a fresh scan) 0 stale over railsbench (>=65,536 checks), btest 1, probe"}
  - {reviewer: thermos-sol, orb: T-01a1ebfc-9329-7435-b540-a21f11c85c76, head: "25e91f0d07", date: 2026-11-18, verdict: changes, open: "Parallel independent correctness/security and maintainability reviews, adjudicated here. MUST-FIX P2 (codegen.rs:3482): payload_ptr_as_mut creates a second whole-payload mutable reference while gen_iseq retains its reference from :344 across gen_iseq_body and uses it at :370/:378; gen_entry_point :2927 -> JITFrame::new_iseq -> cache reaches the same ISEQ on ordinary compilation. Smallest fix: borrow only may_write_block_code directly through the raw pointer (also removes the new conversion import), not the whole payload; keep the no-create accessor. Reduced Miri model in this orb's .amp/in/orb-backup/alias-probe: base passed, head reported UB at original-reference budget write after whole-payload retag, field-only form passed; not an observed Ruby miscompilation. MUST-FIX text: tracing does not always preserve the same bare opcode (iseq.c:4073-4077 converts opt_invokebuiltin_delegate_leave to opt_invokebuiltin_delegate); both are outside the five-opcode set, so the predicate is preserved but body/commit explanation must say that or be cut. Scanner returns early: qualify whole-bytecode/quadratic claims as worst case in body/commit. Replace whole-program alloc/counter 'unchanged' with no additional payloads and measured alloc within A/A (only micro alloc totals are exactly equal). DECISIONS: delete narrating test comment; trim added wrapper commentary to necessary why; remove exact cache-state/internal-state assertions from upstream perf test and keep allocation evidence in record. Cut long run-by-run/A/A body and duplicate comment evidence; use meaningful native ZJIT stats diff, omit within-noise app changes. Evidence: exact one-commit parent verified, diff --check clean, fresh master 3a19e2efcf merges cleanly (tree c5782f667d); both PR discussions/inline comments and issue opened with gh; stack-map history 0b9d58fc53 confirms side-exit addition. Traced all four production callers and entry/side-exit frame paths: current/inlined ISEQs already have payloads, callees/blocks may not; 4,000-call win remains at threshold 2. No stale predicate found across profiling/tracing/GC operand rewrites; free clears and drops payload, compaction has no new pointer, compile/stub VM lock disables GC and excludes Ractor races. Numbers match supplied record: nine micro alloc totals 5,190,585; app branch/base deltas 2,140/4,953/4,379 bytes are below A/A 6,671/12,076/12,364; temporary counter rows match shortlist. 152-byte layout and raw benchmark provenance not independently measured; require exact-build size evidence or cut numeric claim. No Ruby build, TracePoint differential or suites run here (another reviewer owns runtime tests). Full sentence audit and findings: https://ampcode.com/artifacts/zwb1-thermos-review-0f8ffee1-efaf-4d2a-8eba-965405afa8f3"}
  - {reviewer: claude-code, head: "25e91f0d07", orb: T-01a1ebca-06fe-74a0-bfb2-9eb5a87e98d5, date: 2026-11-18, verdict: changes, open: "Code: no must-fix of mine (thermos-sol's aliasing P2 and the opcode-variant wording stand; the wording is also in the new doc comment: 'rewrites keep the bare opcodes' is false for opt_invokebuiltin_delegate_leave, iseq.c:4079; say the rewrites don't add or remove the sends the scan looks for). Note for -4: the same overlapping &mut IseqPayload exists on master for the compiled ISEQ via add_iseq_to_hir (hir.rs:9545) and CompilePolicy::new (hir.rs:2960) while gen_iseq's :344 reference is live. Checked: every FrameState iseq gets its payload in add_iseq_to_hir, and gen_iseq creates the compiled one; cross-check build (assert cached == fresh scan, log payload-less calls) 0 stale and 0 JITFrames for a payload-less ISEQ over railsbench 3 iterations (>=65,536 checks, 359 payload-less callee scans as on master), #19962's program (>=16,384 checks), probe at thresholds 1 and 2. Payloads (gdb on rb_iseq_set_jit_payload, railsbench 3 iterations) master 2,702 / -3 2,702 with identical callers; zjit_alloc_bytes 7,515,644 both, every run. 4,000-call program interleaved master 14.38/13.89 s -> 3.58/3.62 s, zjit_alloc_bytes 5,191,369 both. 152 B (gdb). Probe (blocks, super/zsuper, ..., send, define_method, binding, rescue, global and targeted TracePoint, 60 rounds of ISEQ churn with GC.compact, a Ractor): identical output master vs -3 in the interpreter, ZJIT at 1, 2 and --zjit-max-versions=1. zjit-test 2014/2015 on -3 and 2013/2014 on master, the one failure both times test_profile_frames_during_direct_jit_to_jit_entry (SIGPROF not delivered, only in the full run; alone 10/10 master, 10/10 -2, 5/5 -3); the new test fails at :10432 with get_or_create put back; btest 1 and 2 all 2148; test_zjit_cli+test_optimization 143 tests at 1 and 2. Messages max 70 columns, no trailers, merges clean on 3a19e2efcf. MUST-FIX comment draft: (1) '#18960 added a call per side exit, which makes compiling one large method quadratic' - it was quadratic before (the old #19680 body; 3.53 -> 2.32 s at N=4000 pre-#18960); write 'on top of the one per CCall with a frame, so one large method rescans far more often: #19962's 4,000-call method spends about 11 s in compile_lir here'. (2) 'zjit_alloc_bytes and the number of payloads are unchanged' sits above alloc numbers that differ by 2-4 KB; write 'it adds no payloads (same count as master below)' or quote the identical 7,515,644 runs. Nits: body 'zjit_alloc_bytes ... don't change' vs its own table (the later A/A sentence reconciles it; same fix fine); comment 'about 11 s' add 'here' (tenderlove saw 5.6 s); the test's ask-twice loop and its comment are covered by the final assert_eq; body's single-run railsbench compile_time_ns (1.41 -> 1.24 s) reads as a win nobody claims, maybe drop that column. Recommendation: put -4 on the reopened #19680 (force-push its branch, new body, mark ready, fixed comment); don't offer it on #19962 separately"}
---

# ZJIT: Cache iseq_may_write_block_code() on the ISEQ payload

`iseq_may_write_block_code()` scans an ISEQ's bytecode until it finds an instruction that may write `cfp->block_code`, so an ISEQ without one is scanned to the end. Each JITFrame for a CCall with a frame calls it, and stack maps (#18960) added a call per side exit on top, so compiling one large method rescans it far more often. The 4,000-call method from #19962 shows it.

This keeps the answer on the ISEQ's payload when it has one. The ISEQ being compiled always has one by then, so its repeated checks read the cache. ISEQs without a payload are scanned as before, and no payload is created for this. ISEQs loaded from IBF need nothing extra, since the cache fills at compile time. Profiling and tracing rewrite instructions in place but never add or remove the ones the scan looks for, so the cached answer stays valid. The `Option<bool>` fits in `IseqPayload`'s padding, so the payload stays 152 bytes.

Fixes Shopify/ruby#1064

#19962's program, `--zjit-call-threshold=2 --zjit-stats`:

```diff
-compile_time:                                                  11,107ms
+compile_time:                                                  3,403ms
-compile_lir_time:                                              11,065ms
+compile_lir_time:                                              3,363ms
 zjit_alloc_bytes:                                             5,195,558
```

## Comment draft (not posted)

New head. Since this was closed, stack maps (#18960) added a call per side exit on top of the one per CCall with a frame, so one large method rescans far more often: #19962's 4,000-call method spends about 11 s in `compile_lir` here. The cache is now used only when the ISEQ already has a payload, which the ISEQ being compiled always does, so it adds no payloads.

```
#19962's program, --zjit-call-threshold=2, compile_time_ns, three runs each
master  11891150378 11354019287 11847351244
branch   3446299425  3604310423  3270415818

ruby-bench, payloads created (temporary counter), railsbench / lobsters / shipit
master  2640 / 4945 / 4865
branch  2640 / 4945 / 4865
```
