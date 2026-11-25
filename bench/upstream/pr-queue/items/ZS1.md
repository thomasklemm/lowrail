---
id: ZS1
repo: ruby/ruby
kind: perf
area: ZJIT, sends with a Symbol block argument
reviewer: "tekknolagi and k0kubun (ZJIT), rafaelfranca (author of the branch the first commit comes from)"
branch: thomasklemm/zjit-symbol-block-arg
head: "5b3e0d0be5"
base: master
built_on: "a43519979c"
depends_on: []
stacked_on:
alternative_of:
impact: "foo(&:sym) to ISEQ and C callees no longer falls back to a dynamic send under ZJIT; railsbench on Rails main: 42,441 of 115,090 block-arg fallbacks per iteration"
rank: 1
risky: true
state: ready
pr: 19912
note: "2026-11-25 round 4 for thermos-opus (orb T-01a21185-ec85-712d-8af9-d0b1f62beb3a): head 5b3e0d0be52c2d20b2dab51a82ee7868b57200a1 on master a43519979c (round 3 rebased clean), pushed as thomasklemm/zjit-symbol-block-arg-4, PR branch untouched; d43d039601 ZJIT (Rafael author, Thomas co-author), 5b3e0d0be5 tests (Thomas). No existing machinery records which guard exited, so new IseqPayload bool exited_for_block_arg_refinements (pattern of was_invalidated_for_singleton_class_creation), set on the new BlockArgRefinements exit for the frame-state ISEQ; the next version leaves the send dynamic, guard stays; +23 -2 in 5 files; new per-ISEQ state for XrXr in reply 2. refined_method_cost.rb: master 2 compiled/0 exits, bdcfceb5ee 8/30/399,738 no_side_exits fallbacks, head 4/5/0. Tests: zjit-test 2051/2052 (SIGPROF), btest t1+t2 2148/2148, cli 34/0, core 1380/0, all probes identical; railsbench as round 3. Record: docs/upstream/zjit-symbol-block.md round 4. Needs thermos-sol and thermos-opus on 5b3e0d0be5. Earlier: 2026-11-25 (coordinator): fork master now equals ruby master, so fork pushes work again; bdcfceb5ee (from zs1-3.bundle, sha256 checked) pushed as new fork branch thomasklemm/zjit-symbol-block-arg-3. PR branch untouched. 2026-11-25 round 3 for thermos-sol (orb T-01a21185-ec85-712d-8af9-d0b1f62beb3a): head bdcfceb5eecaa0b7060f2df13958308ea8690624 on master f63048e942 (05ae429a7b ZJIT, Rafael author, Thomas co-author; bdcfceb5ee tests, Thomas); not on the fork (workflow scope), bundle bench/upstream/zs1/round3/zs1-3.bundle sha256 208954879c51b0c9202b9abefc99545f496f793a79b8e755e3b1eb8eb9ae7f2b, verified in a fresh clone of master 0988275a9b with the same commit and tree SHAs. Against 2e3108fc05 (+71 -31, 5 files): GuardAnyBitSet on the RBASIC flags of the Symbol#to_proc CME (GC-tracked Const, METHOD_ENTRY_BASIC_FLAG = RUBY_FL_USER7, i.e. IMEMO_FL_USER2), original send snapshot, recompile, next to the patch points; comments at codegen.rs block_arg_symbol and the two interpreter lines in hir.rs removed; new regression test_send_symbol_block_arg_to_proc_redefined_with_itself_keeps_proc_identity (the reviewer probe); using-after-compile test uses flat_map; commit message drops the equivalence claim; four snapshots move. Removing the guard fails the new test and the four snapshots. Tests (dev build): zjit-test 2051/2052 (SIGPROF test only), btest t1 and t2 2148/2148, test_zjit_cli 34/0 failures, core 1380/0 failures; zs1_probe identical at t1, t2p1, default, N=40; round-2 probes including proc_identity_probe identical in interpreter, t1, t2 and default (2e3108fc05 printed false at t1). railsbench: send_block_arg_not_nil 2,440,814 (master) -> 2,200,733, one_or_more_complex_arg_pass 2,133,480 -> 1,930,477, rb_vm_send 4,732,653 -> 4,289,569, no unhandled_block_arg exit. Body unchanged: its basic-method sentence is true with the guard. Needs thermos-sol (and thermos-opus) on bdcfceb5ee. Earlier: 2026-11-25 fix round for XrXr (orb T-01a21185-ec85-712d-8af9-d0b1f62beb3a): new head 2e3108fc05 on master f63048e942, two commits (f858d208e8 ZJIT, Rafael author, Thomas co-author; 2e3108fc05 tests, Thomas), meant for thomasklemm/zjit-symbol-block-arg-2; NOT on the fork: the push was refused because the token lacks the workflow scope (master changed .github/workflows since the fork synced), so Thomas pushes it or a token with workflow scope is needed; bundle and patches in bench/upstream/zs1/round2/. Change: the VM commit and both run-time helpers (rb_vm_symbol_block_handler, rb_zjit_symbol_block_handler) are gone; the Symbol itself is the callee frame block handler; Symbol#to_proc stays PatchPoint MethodRedefined plus RootBoxOnly as before; the refinements check is a HIR guard (new GetCref insn calling rb_vm_get_cref on cfp->ep, LoadField :refinements, GuardBitEquals nil, recompile), skipped when policy.no_side_exits. Same-definition redefinition of Symbol#to_proc no longer exits: compiled code passes the Symbol, the interpreter calls to_proc; identical results (same Proc object, lambda?, arity, backtraces) without refinements, and the guard exits under them. New test test_send_symbol_block_arg_with_refinements_activated_after_compile (top-level using after compile; ISEQ, C and variadic C); removing the guard fails it, test_send_symbol_block_arg_with_refinements, the self-redefinition test and four snapshots. Evidence (dev build, x86-64): make zjit-test 2050/2051, the one failure test_profile_frames_during_direct_jit_to_jit_entry (SIGPROF, as on master in orbs); btest --zjit-call-threshold=1 and =2 2148/2148 each; test_zjit_cli 34 tests 0 failures; proc/refinement/symbol/method/call/yield/lambda/array/enum/settracefunc/backtrace at threshold 1 1380 tests 0 failures; zs1_probe.rb diffs empty at t1, t2p1, default and default N=40 after normalizing Thread addresses; round2 probes (redefinition, using after compile, same definition) identical in interpreter, t1, t2. railsbench (ruby-bench, Rails 8.1.4.1, 10+10 itr, master f63048e942 vs head): send_block_arg_not_nil 2,440,814 -> 2,200,740, one_or_more_complex_arg_pass 2,133,480 -> 1,930,477, rb_vm_send 4,732,653 -> 4,289,576, no unhandled_block_arg exit (cref guard never fires; no using in Rails main lib or railsbench gems except irb). Body: second and third paragraph rewritten (no VM commit, guard on refinements); numbers kept (from fbbb9cee7b; same sends specialized, no refinements there). Needs thermos-sol and thermos-opus on 2e3108fc05, then Thomas for push, body PATCH and replies (drafts in docs/upstream/zjit-symbol-block.md). 2026-11-24 20:29 UTC: XrXr CHANGES_REQUESTED. codegen.rs:1213 (r4686073773): do the Symbol#to_proc check as a HIR speculation with the existing machinery, not at runtime. vm_args.c:1150 (r4686108643): speculate the refinements check away; start with a guard that loads cref and checks nil, since the active refinements are generally stable under a cref. Fix round started 2026-11-25. 2026-11-18 (post-inline_block check on master 825d71e673, which force-inlines Primitive.inline_block methods): scratch merge of head into 825d71e673, --enable-zjit=dev, not pushed. make zjit-test 2029/2030, the one failure test_profile_frames_during_direct_jit_to_jit_entry (SIGPROF, also fails in the full master run here, 2013/2014); btest --zjit-call-threshold=1 2148/2148. No snapshot moved. Claimed effect still exists: on master, a.map(&:succ), a.each(&:succ), 3.times(&:succ), 1.then(&:succ) and foo(&:succ) are Send with block argument is not nil and a.reject(&:odd?) is Complex argument passing; with the PR they are SendDirect / CCallWithFrame (one dynamic send fewer per call). The Symbol-block send is a SendDirect, not inlined, so force-inlining does not take these sites; the yield inside map/each/times to the Symbol block handler stays generic invokeblock on both, as the commit message says. Still merges clean (git merge-tree) with master a4beace140 (vm_eval.c only, not rebuilt). No rebuild needed; branch untouched, nothing posted. 2026-11-17: rebased onto master b4ade67ba5 for the merge conflict on #19912 and pushed with a lease on fbbb9cee7b; new head aa36fa0ea4, still three commits, now mergeable. git range-diff: the VM commit (74aa7d4f79) and the test commit (aa36fa0ea4) are unchanged (=); the ZJIT commit (30e0ca73f6) differs only in the Array#zip snapshot in opt_tests.rs, which takes master's new LoadSP and StoreField lines and renumbered values and keeps its block= operand. No code change was needed for master's side-exit stack maps or HIR renumbering; no other snapshot changed. Authors, author dates, messages and the Co-authored-by trailer are unchanged, no Amp trailer. arm64 (ARM1, T-01a1e00a-99a3-7183-9a14-acf3268bdc46): zjit-test 2,272 of 2,272, Symbol-block filter 61 of 61, test_zjit_cli 34 tests with no failure (dev and release), btest at threshold 2 2,148 of 2,148, probe diffs against the interpreter empty at t1, t2p1 and default N=40 and under GC.stress, counters as on fbbb9cee7b. The passes below are on fbbb9cee7b, whose code this head keeps. Earlier: reopened 2026-11-15 after skipkayhil closed rails/rails#59803 with 'Let's fix this in the JITs?'; three commits: the VM extraction (Thomas), the Symbol part of Rafael França's Shopify/ruby zjit-perf/blockarg-direct-send 3f17d8950e (he is its author, Thomas co-author; coordinator: the design is his) and the tests; fbbb9cee7b has the tree of 89e2da1571 (git diff empty), on which all three passes had no must-fix and arm64 was green (ARM1); the coordinator had the VM extraction split out as its own commit and the message rewrapped, so the passes on fbbb9cee7b are confirm passes limited to tree identity, split, authorship and messages; earlier heads dcd4bd2b79, 7eddd8bfce, 09d8e5308e; no LLM disclosure and no separate ping to Rafael (coordinator); the ZJIT commit is +212 -55, so the tracker rule applies and the coordinator asks Thomas: nothing opens and nothing is posted on Shopify/ruby#1014 until he answers; record docs/upstream/zjit-symbol-block.md"
waived:
  - {reviewer: thermos, head: "fbbb9cee7b", by: "coordinator, 2026-11-15", reason: "three independent passes on the exact head (Fable adversarial on exactness and invalidation, with a readability and ZJIT-style note), a mutation check of every guard, and arm64 coverage by ARM1"}
passes:
  - {reviewer: astra, head: "bdcfceb5eecaa0b7060f2df13958308ea8690624", orb: T-01a21206-053e-70de-a4ac-3bbadd53e8c0, date: 2026-11-25, verdict: approve, open: "both Thermos rubrics personally, full PR, no delegation. Correctness approval only: no additional correctness/maintainability must-fix or nit; Opus's known performance blocker remains for round 4, not re-investigated per coordinator. GC-tracked CME, mask/offset C assertions, GetCref effects and snapshots checked. Independent interpreter comparisons 127/127, repeated after restoring exact head; includes identity, forwarding, exceptions, compaction, late using, mutations and suspended fiber/Ractor frames. Wrong flag/cref guards fail own probes and 5/19 and 7/19 Symbol tests; wrong C-call exit state fails CLI overflow regression. Restored 19/19 and overflow 1/26 assertions; source diff empty. Dev zjit-test 2051/2052, 15 skipped, SIGPROF abort independently reproduced on base Rust control 2033/2034; btest t1/t2 2148/2148 each, CLI 34/7907, core 1380/64214 with one skip, no failures/errors. No arm64/new benchmark. Details in record's thermos-astra subsection. No Ruby push/post."}
  - {reviewer: astra, head: "5b3e0d0be52c2d20b2dab51a82ee7868b57200a1", orb: T-01a21206-053e-70de-a4ac-3bbadd53e8c0, date: 2026-11-25, verdict: changes, open: "round-4 delta confirm, both rubrics personally. Must-fix: exit_block_arg_refinements writes shared IseqPayload through &mut without the VM lock; c_callable only selects ABI. GDB on unchanged head stopped two Ractor threads on the same ISEQ with rb_vm_locked_p() == 0 (12 recorded entries). A non-atomic true store still races; payload_ptr_as_mut requires exclusive access. Smallest fix: wrap the new callback's payload update in with_vm_lock; temporary patch validated, GDB lock == 1, Symbol tests 19/19 and Ractor/lifetime probes pass. Existing unlocked exit_recompile fast path is separate. Inlining ownership, tracked ISEQ constant, payload initialization/free and compaction checked; lifetime HIR retains parent's plain specialization while refined inline leaf becomes dynamic. Exact head: zjit-test 2051/2052, SIGPROF only, 15 skipped; btest t1/t2 2148/2148 each; original 127 differential comparisons plus 6 new lifetime/Ractor comparisons match. Ordinary outputs do not detect the race. No additional nit. Fix not retained or pushed to Ruby; details and diagnostics in record."}
  - {reviewer: opus, head: "7eddd8bfce", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: changes, open: "no behaviour difference found; must-fix: body called Array#map a C method and gave one fallback reason for both callee kinds, and a profiled-Symbol guard was emitted in front of a C-callee send that stays dynamic (splat, kwargs); all three fixed in 09d8e5308e, with the optional points taken: one helper for the patch points, behaviour test for the C-callee patch points, trivial-inliner skip removed, CCallVariadic prints its block"}
  - {reviewer: fable, head: "7eddd8bfce", orb: T-01a1e02a-5156-7535-b82d-6fdecf19860d, date: 2026-11-15, verdict: changes, open: "must-fix: with RUBY_BOX=1 a box that redefines Symbol#to_proc got the plain Symbol as block handler; fixed in 09d8e5308e (no specialization once a non-root box exists, RootBoxOnly patch point, CLI test). Leaf-call, GC and invalidation questions settled with source lines and runs; readability: reads like the surrounding code, asked for the patch-point helper and the CCallVariadic printer, both done"}
  - {reviewer: claude-code, head: "7eddd8bfce", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: changes, open: "must-fix: Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc)) clears the basic flag in place without invalidating the entry, so the patch point never fired and compiled code kept the refined lambda; fixed in 09d8e5308e (the conversion checks the watched entry's flag and exits, with a test). Body Array#map sentence fixed"}
  - {reviewer: opus, head: "09d8e5308e", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: nits, open: "no must-fix; the three earlier must-fixes are resolved and the flag check and box check read correctly; found that removing PatchPoint RootBoxOnly fails no test and that no program needs it; optional points taken in 89e2da1571: commit message wording (line length, 'no box has been created with Ruby::Box.new'), cfunc_callee renamed, zjit.c comment shortened; not taken: carrying the to_proc entry in BlockArgSymbol"}
  - {reviewer: claude-code, head: "09d8e5308e", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: nits, open: "no must-fix; flag check equivalent to rb_method_basic_definition_p in 16 single changes, 8 sequences with GC.compact and under RUBY_BOX=1; exit after the leaf call right; nits taken in 89e2da1571: the self-redefinition test now fails on all three paths (proc and Proc.new as C callees), the redefined-after-compile warm-up, the bindgen allowlist entry, commit message line length"}
  - {reviewer: opus, head: "89e2da1571", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: approve, open: "delta from 09d8e5308e read and rerun: zjit-bindgen regenerates cruby_bindings.inc.rs with no diff; the self-redefinition test covers SendDirect, CCallWithFrame and CCallVariadic and fails without the flag check; removing the Symbol#to_proc patch point at any one call site fails the redefined-after-compile test; probe and break scripts match. Optional: five lines of commit 1's message are 73 characters"}
  - {reviewer: fable, head: "89e2da1571", orb: T-01a1e02a-5156-7535-b82d-6fdecf19860d, date: 2026-11-15, verdict: nits, open: "no must-fix, adversarial on exactness, invalidation and GC: 396 combinations of a Symbol#to_proc change, setup and timing match at four settings; the baked entry survives compaction; the only code that changes the basic bit of an existing entry is vm_method.c:1851 and all three ways to reach it are handled; the Qundef exit is built from the original send's frame state. Optional, not applied: recompile on the Qundef exit (it exits on every call after a same-definition define), a guard in front of a dynamic send for an argc mismatch and for an ISEQ callee that ignores its block, carrying the entry from the patch point to codegen; body should mention the run-time flag check (done). RootBoxOnly and the GC preparation have no failing test and no failing program. Readability: reads like the code around it"}
  - {reviewer: claude-code, head: "89e2da1571", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: approve, open: "delta from 09d8e5308e is two tests, a rename, a comment and the bindgen entry; zjit-bindgen regenerates cruby_bindings.inc.rs byte-identical; removing the patch points on one path fails the redefined-after-compile test ([4, [30], 30], [300, [4], 30], [300, [30], 4]) and removing the flag check fails the self-redefinition test; single-threaded zjit-test 2007/2007, CLI 34 tests, probe and break scripts match. Optional: five 73-character lines in commit 1's message; body to be cut (done)"}
  - {reviewer: opus, head: "fbbb9cee7b", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: approve, open: "confirm pass on the split: same tree object as 89e2da1571 (63d226b442), and 8aedcce4ca has the tree of 656ae95dbc; b7dfd487a6 touches only vm_args.c and vm_core.h, 8aedcce4ca only zjit.c and zjit/, fbbb9cee7b only tests; authors, committer and trailers as intended; no message line over 72 characters. Optional, would need a new head: 8aedcce4ca's 'extracted unchanged' reads as if that commit extracted it; a Co-authored-by for Rafael on the VM commit (Thomas's call)"}
  - {reviewer: claude-code, head: "fbbb9cee7b", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: approve, open: "confirm pass on the split: tree 63d226b442 as on 89e2da1571; b7dfd487a6 holds the whole VM change (the 22 removed lines equal the added body apart from indentation) and nothing of ZJIT, 8aedcce4ca nothing of the VM; authors, committer and trailers as intended, no Amp trailer; no message line over 72 characters, and 8aedcce4ca's message is word for word the old one. Optional: 'extracted unchanged in the previous commit'; would leave it"}
  - {reviewer: fable, head: "fbbb9cee7b", orb: T-01a1e02a-5156-7535-b82d-6fdecf19860d, date: 2026-11-15, verdict: nits, open: "confirm pass on the split, no must-fix and no new point: same tree as 89e2da1571, the split is clean, authorship and messages as intended (longest lines 71, 72 and 72 characters). The optional points are those of the pass on 89e2da1571; the coordinator decided against the recompile on the flag-check exit"}
  - {reviewer: thermos-sol, head: "2e3108fc0558f076a7acbbd1eaf2f5acd534f603", orb: T-01a211b5-8b72-7106-b650-4a78d8f8a461, date: 2026-11-25, verdict: changes, open: "both rubrics personally, no delegation. Must-fix: same-definition redefinition clears the basic bit without invalidation; passing the Symbol delays conversion and changes Proc identity when the callee evicts the cache before reading &b (interpreter true, ZJIT false). Keep patch points and add a HIR METHOD_ENTRY_BASIC guard with original-send snapshot/recompile; temporary guard and new behavior regression validated. Correct the false equivalence in commit message/reply and remove redundant new comments at codegen.rs:1209 and hir.rs:5238. NULL cref is not reachable from valid Ruby frames executing this HIR; no nullable wrapper needed. Authorship matches existing PR (Rafael author, Thomas co-author/committer; dates refreshed). Optional: new using-after-compile test uses map, an ISEQ under ZJIT; use flat_map for real fixed-C coverage. Dev zjit-test 2050/2051 plus 15 skipped, SIGPROF abort reproduced with base Rust control; btest t1 and t2 2148/2148 each, CLI 34/7907 assertions, core 1380/64214 assertions, one skip. Matrix 144/144 matches uncompiled JIT-enabled control; deleting cref guard fails 7/20; restored exact-head Symbol filter 18/18; bindgen identical. Details and conditional corrected reply in docs/upstream/zjit-symbol-block.md; supersedes note's same-Proc equivalence claim."}
  - {reviewer: thermos-sol, head: "bdcfceb5eecaa0b7060f2df13958308ea8690624", orb: T-01a211b5-8b72-7106-b650-4a78d8f8a461, date: 2026-11-25, verdict: approve, open: "confirm pass, both rubrics personally, no delegation: exact bundle/head/base verified; all prior must-fixes and coverage nit resolved, no new finding. METHOD_ENTRY_BASIC_FLAG equals IMEMO_FL_USER2/RUBY_FL_USER7 (524288, bit 19), checked with C-header assertions; GC-tracked CME, flags load, original-send snapshot/recompile correct. Identity probe now true in all six modes; removing only flag guard fails identity test plus four snapshots (5/19), restored head 19/19. Fresh dev zjit-test 2051/2052 with 15 skipped, same previously base-reproduced SIGPROF abort; btest t1/t2 2148/2148 each; CLI 34 tests/7907 assertions, core 1380/64214 with one skip, no failures/errors. Matrix 144/144 matches uncompiled JIT-enabled control; 16/16 other probe comparisons and 2/2 forced-compaction comparisons match interpreter; bindgen identical. Body, both final replies, comments and commit messages checked; prior NULL-cref/authorship conclusions unchanged. Details and final reply texts in docs/upstream/zjit-symbol-block.md, round-3 confirm subsection. No Ruby push or posting."}
  - {reviewer: thermos-opus, head: "bdcfceb5eecaa0b7060f2df13958308ea8690624", orb: T-01a211e6-8d3e-7275-8670-15f9b0547aa7, date: 2026-11-25, verdict: changes, open: "both rubrics personally, no delegation; exact bundle/head/base verified. Must-fix: a caller whose cref already has refinements (code under `using` with foo(&:sym)) exits on the cref guard, recompiles into the same specialization, and after four versions lands in a no_side_exits version that drops every other speculation in the method: refined_method_cost.rb against master f63048e942 has compiled_iseq_count 2 -> 8, side exits 0 -> 30, getivar fallback no_side_exits 0 -> 399,738 (wall 3.6 s -> 3.9 s, dev build, indicative only). Smallest fix: once the cref guard has exited for an ISEQ, compile its next version without the Symbol specialization (a per-ISEQ bit set on that exit; the generic send stays), keeping the guard for a later using; a compile-time look at the entry frame's cref alone misses stub-compiled and inlined callees. New per-ISEQ state, so the tracker rule may apply (coordinator's call); reply 2 then needs one sentence on it. Shape: PatchPoints plus a flag guard and GetCref plus nil guard is what XrXr asked for; no existing HIR loads a cref, and the flag guard is needed because vm_method.c reuses an equal definition without invalidation (a VM fix would be its own PR). Nits: GetCref is a C call per send (local-EP case could be a load); body numbers are from fbbb9cee7b. Reply 1 correct as is. Tests: zjit-test 2051/2052 (SIGPROF only, 15 skipped), btest t1 and t2 2148/2148, CLI 34/7907, core 1380/64214 with 1 skip; mutations: flag guard 5/21 fail, cref guard 7/21 fail, exit_state in the C-call stack check fails the CLI overflow test; 13 Symbol#to_proc mutations x 3 settings and cref-frame, inline, late-using probes identical to the interpreter."}
  - {reviewer: thermos-opus, head: "5b3e0d0be52c2d20b2dab51a82ee7868b57200a1", orb: T-01a211e6-8d3e-7275-8670-15f9b0547aa7, date: 2026-11-25, verdict: changes, open: "confirm pass, both rubrics personally. Rebase clean (range-diff: tests =, ZJIT commit differs only in the fix). Round-3 must-fix resolved: refined_method_cost 4 compiles/5 exits/0 no_side_exits; inlined refined callee marks itself, caller keeps its speculation (4/5). Must-fix, agreeing with Astra: exit_block_arg_refinements creates/writes the IseqPayload without the VM lock (payload.rs:146 assumes it); with_vm_lock as in -5. GC/free fine (refined_iseq is a GC-tracked Opnd::Value). Nit: no test fails without the bit or with the wrong ISEQ marked, acceptable under the no-internal-state rule. Reply 2: question moved to the end (text in record). Tests: zjit-test 2051/2052 (SIGPROF), btest t1/t2 2148/2148, CLI 34/7907; probes 28/28, mutations 39/39, Ractor+compaction 9/9 identical."}
---

# ZJIT: Send Symbol block arguments directly

Under ZJIT, a send with a Symbol block argument such as `foo(&:sym)` stays a dynamic send. rails/rails#59803 worked around that in Active Record and was closed with ["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59803#issuecomment-6895904455). This is the send side of that fix, the Symbol case that #18180 left for later (Shopify/ruby#1014).

A static Symbol block argument now compiles to `SendDirect` for ISEQ callees and to `CCallWithFrame` or `CCallVariadic` for C functions such as `Array#reject`, with the Symbol as the callee frame's block handler. The send is specialized only while `Symbol#to_proc` is basic and no `Ruby::Box` has been created, and a guard exits to the interpreter when the caller's cref has refinements. The callee's `yield` is unchanged.

The first commit is the Symbol part of Rafael Mendonça França's [`zjit-perf/blockarg-direct-send`](https://github.com/Shopify/ruby/tree/zjit-perf/blockarg-direct-send) branch, ported to master. His branch also sends forwarded block parameters directly; that part is left to Shopify/ruby#1039.

`attr-read` runs the attribute reads of rails/rails#59803, and `symbol-block` runs `one(i, &:itself)` and `[1, 2, 3].map(&:itself)`. `master-again` is the same build of master a second time; the apps do not move beyond noise.

```
master: ruby 4.1.0dev (2026-11-15T09:48:53Z HEAD 3be2b028a7) +ZJIT +PRISM [x86_64-linux]
master-again: ruby 4.1.0dev (2026-11-15T09:48:53Z HEAD 3be2b028a7) +ZJIT +PRISM [x86_64-linux]
symbol-block-arg: ruby 4.1.0dev (2026-11-15T19:16:23Z HEAD fbbb9cee7b) +ZJIT +PRISM [x86_64-linux]
ruby-bench: 73918b2fc1a84702fea63e06f64d179751d69df4-dirty

------------  -------------  -----------------  ---------------------  --------------------  ------------------------  -------------------  -----------------------
bench           master (ms)  master-again (ms)  symbol-block-arg (ms)  master-again 1st itr  symbol-block-arg 1st itr  master/master-again  master/symbol-block-arg
lobsters      1006.3 ± 9.5%       972.7 ± 5.3%          1009.8 ± 7.8%                 1.110                     1.122                1.035                    0.996
railsbench    1525.8 ± 8.3%      1511.5 ± 5.3%          1511.2 ± 7.1%                 1.205                     1.109                1.009                    1.010
shipit        1235.9 ± 6.8%      1339.7 ± 7.6%          1283.4 ± 6.4%                 0.943                     0.972                0.923                    0.963
attr-read      300.5 ± 3.3%       305.4 ± 6.6%           249.9 ± 4.8%                 1.112                     1.065                0.984                    1.202
symbol-block   370.6 ± 6.7%      431.4 ± 13.2%           306.0 ± 9.7%                 1.018                     1.072                0.859                    1.211
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

## For Thomas

**2026-11-25 thermos-opus confirm on `5b3e0d0be5`: changes, VM lock only.** The refined-caller fix works, also for inlined callees; the only must-fix is Astra's missing VM lock, fixed in `-5`. Reply 2 with the question last is in [the record](../../../../docs/upstream/zjit-symbol-block.md#thermos-opus-confirm-on-5b3e0d0be5-changes-the-vm-lock-only-2026-11-25).

**2026-11-25 thermos-opus: changes on `bdcfceb5ee`.** Correct in every probe, and the shape is what XrXr asked for. One must-fix: a send under `using` exits on the cref guard, recompiles into the same specialization and, after four versions, ends in a `no_side_exits` version that drops the method's other speculation (8 compiles, 30 exits and 399,738 getivar fallbacks where master has 2, 0 and 0). Fix: after the cref guard exits, leave that send dynamic in the next version; reply 2 then gets one sentence. See [the record](../../../../docs/upstream/zjit-symbol-block.md#thermos-opus-on-bdcfceb5ee-changes-2026-11-25).

**2026-11-25 thermos-sol: changes on `2e3108fc05`.** The note's claim that passing the Symbol always gives the
same Proc without refinements is disproved by
[`proc_identity_probe.rb`](../../zs1/round2/proc_identity_probe.rb). Same-definition redefinition skips
invalidation, and the callee can evict the Proc cache before ZJIT converts the Symbol. Add a HIR basic-bit guard
with the original send snapshot and recompile, plus this behavior regression. A temporary implementation passes
the regression and all 12 Symbol behavioral tests; it is not part of the reviewed head.

The body's basic-method promise is not true until that guard exists. The first commit's same-result claim and
the original first review reply need correction; the round record now contains a replacement reply conditional
on the fix. Delete the redundant new comments at `codegen.rs:1209` and `hir.rs:5238–5239` under DECISIONS. Optional:
use `flat_map`, not `map`, for the new test's claimed fixed-arity C callee.

**2026-11-25 round 3, head `bdcfceb5ee`:** the basic-bit guard, the regression test, the comment deletions, the
`flat_map` change and the commit message correction are in; see the round-3 record in
[zjit-symbol-block.md](../../../../docs/upstream/zjit-symbol-block.md#round-3-for-thermos-sol-2026-11-25).

**thermos-sol confirm: approve.** All prior must-fixes and the coverage nit are resolved on this exact head;
no new finding. The flag mask is independently checked, the standalone identity probe now matches, and deleting
the new guard fails the new behavior test. Both reply drafts and the unchanged body are correct on this head.
Fresh execution and final reply texts are in
[the confirm record](../../../../docs/upstream/zjit-symbol-block.md#thermos-sol-confirm-approve-2026-11-25).

NULL cref is not reachable from valid Ruby ISEQ frames executing this HIR; the nonnull helper is appropriate.
Rafael's author identity and Thomas's co-author trailer match the PR's existing ZJIT commit. XrXr's requested HIR
shape is now implemented with no remaining blocker from this confirm pass. The initial evidence and sentence audit
are in [the fix-round record](../../../../docs/upstream/zjit-symbol-block.md#thermos-sol-on-2e3108fc05-changes-2026-11-25).
