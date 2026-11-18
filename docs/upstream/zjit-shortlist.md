# ZJIT shortlist: where we can help (2026-11-17)

Refresh of the 2026-11-03 triage on ruby/ruby master `7919a47d46` (2026-11-17 22:17 UTC): 135 open Shopify/ruby
issues (the ZJIT ones read for assignees and comments), the 71 open ruby/ruby PRs with "ZJIT" in the title, and the
27 merged since 11-03. Claim status comes from assignees, open PRs and comments only. Nothing was posted upstream.

Ranking rule (PR retrospective of 2026-11-17): an item with a stated ask, an issue or comment from a ZJIT maintainer
or a Rails PR closed with "fix it in the JITs", ranks above an unasked one; each change stays well under ZS1's 672
lines and uses #19909's evidence format. Nothing opens until ZS1 (ruby/ruby#19912) gets a response.

## What changed since 11-03

* **Did not move:** tekknolagi's `send(:sym)` ruby/ruby#19583 (draft, last update 11-03) and k0kubun's
  ruby/ruby#19617 (recompile invalidated final versions, last update 11-03). `Kernel#dup` in Ruby
  ([zjit-cfunc-paths](zjit-cfunc-paths.md#kerneldup-in-ruby-tekknolagis-question)) stays blocked on both, and the
  #1058 attempt stays withdrawn.
* **Merged and relevant to our leads:** tekknolagi's ruby/ruby#19858 profiles only the shape for
  `getinstancevariable`, so singleton receivers are no longer "other" there. railsbench's
  `getivar_fallback_no_side_exits` is now 0 (lead 15b is done for reads; lobsters 148,534 and shipit 326,606 per
  iteration remain, lead 15a/15c). XrXr's stack maps (ruby/ruby#18960) made `iseq_may_write_block_code()` a large
  compile-time cost again (below). Our ZNE1 (#19909) merged 11-16.
* **New issues from the team, all unassigned:** #1106 `String#dup`, #1107 fold `IsMethodCFunc` to false, #1110
  locals after last use, #1113 shared arrays in `Array#[]=` (tenderlove's ruby/ruby#19863, approved), #1119 Valgrind
  translations, #1120 no-singleton assumptions (design), #1122 profile the real class for `setinstancevariable`,
  #1124 validator and dead code (bug), #1129 fold `IsBitEqual` on disjoint types, #1130 hoist stack-overflow checks
  of inlined frames, #1103 compressed profiles (efegokdemir's ruby/ruby#19791 open), #1104 precise caches, #1127
  `Proc#call` with keywords (nozomemein's ruby/ruby#19901 open).
* **Ours, open, no response:** ZS1 #19912 (since 11-15), #19659 and #19681 (last activity 11-15).
* **#1064 came back.** tenderlove opened ruby/ruby#19962 today: since stack maps, his 4,000-call method spends
  5.6 s in LIR instead of 1.4 s, and he caches the scan in the ISEQ's params bits. XrXr asked for another place for
  the bit, k0kubun pointed to `IseqPayload` "like #19680 did", and tekknolagi asked: "Perhaps we should re-open the
  other one now that this is a bigger compile time sink?" #1064 is still assigned to us.
* **efegokdemir** opens ZJIT PRs against Shopify/ruby for many fresh issues (#1111 protected calls, #1117, #1126 for
  #1122, …); tekknolagi closed them asking for ruby/ruby PRs. He may refile any of them on ruby/ruby.

## Rails relevance, master `7919a47d46`

ZJIT stats per iteration, ruby-bench `73918b2` with `reaping_frequency: 0`, 15 warmup and 10 measured iterations,
`--zjit-exec-mem-size=512 --zjit-mem-size=1024`, `RUBY_GC_HEAP_INIT_BYTES=32 MiB`, no out-of-memory compile errors
(railsbench / lobsters / shipit):

| counter | railsbench | lobsters | shipit |
| --- | ---: | ---: | ---: |
| dynamic sends | 1,075,941 | 775,453 | 1,835,621 |
| `send_polymorphic_fallback` (lead 3) | 30,483 | 272,334 | 774,234 |
| `send_megamorphic` | 189,766 | 108,239 | 123,483 |
| `getivar_fallback_no_side_exits` (15a/15c) | 0 | 148,534 | 326,606 |
| `setivar_fallback_no_side_exits` | 30 | 5,951 | 41,002 |
| `ccall_Kernel#dup` | 60,215 | 19,223 | 49,533 |
| `ccall_String#dup` | 25,218 | 4,243 | 5,663 |

railsbench's top megamorphic sites are Rails' `extend`ed logger (`Logger#level` 51,922, `local_level` 25,961,
`debug?`, `info?`): the singleton receivers count as "other" in the send profile, which is #1120's design question,
not a free fix. shipit's 41,002 generic ivar writes are `Relation#reset` and `#initialize` in final versions, not
singleton receivers.

## Ranked

| # | item | ask | Rails relevance | owner | state |
| --- | --- | --- | --- | --- | --- |
| 1 | #1064 cache `iseq_may_write_block_code` on `IseqPayload` | tekknolagi and k0kubun on ruby/ruby#19962, today | a 4,000-call method 11.0–11.9 s → 3.3–3.6 s of compile time; no new payloads, app alloc within A/A | ours (assigned), #19680 reopened by tekknolagi; tenderlove's #19962 is open | **built, ZWB1 -4** |
| 2 | #1106 `String#dup` on `StringExact` without ivars | tekknolagi's issue | 25k / 4k / 6k calls per iteration become frameless; micro −2.5% Ir per call (−10), railsbench about 0.005% | free (no assignee, comment or PR; not in #1039) | **built, ZSD1 -3** (near both stop limits) |
| 3 | #1122 profile the real class for `setinstancevariable` | tekknolagi's issue | generic fallback removed for eligible extended objects; lobsters −584 generic writes per iteration (stats with A/A) | free (no replacement for the closed wrong-repo attempt found on 11-18) | **ZSV1 -2 built, needs a pass** |
| 4 | #1130 one stack-overflow check for all inlined frames | tekknolagi's issue (design note, no comments) | net −0.74 M / −8 k / +0.23 M checks per iteration (railsbench / lobsters / shipit), at most 0.05% of Ir | free | **measured, not built** |
| 5 | #1129 / #1107 constant folds | tekknolagi's issues | unmeasured, small | free | not built |
| 6 | 15a attr_reader in a final version | none | lobsters / shipit share of 148k / 327k | taken 2026-11-18: tekknolagi's draft ruby/ruby#18616 (11-16 head) covers final versions | old build, not rebased, stays unopened |
| 7 | lead 3 polymorphic recompile (ZL3) | answered on #776, waits for the team | largest on lobsters and shipit | ours | held |

Not taken: anything in k0kubun's #1039 rows (yield dispatch, polymorphic and megamorphic sends, ivar shape tables),
tekknolagi's backend redesign (#1077), #1120 (design), the protected-send PR (closed 11-04, not rebuilt).

## ZWB1: `iseq_may_write_block_code()` on the payload (built, -4)

Branch [`thomasklemm/zjit-cache-may-write-block-code-4`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-cache-may-write-block-code-4)
@ `25e91f0d07`, one commit on master `3a19e2efcf`, 3 files, +34/−2. Queue item
[ZWB1](../../bench/upstream/pr-queue/items/ZWB1.md) holds the body and the comment draft.

* **History.** -2 (`82c529aa2e`) created payloads for callee ISEQs (the permanent memory k0kubun objected to on
  11-04). -3 (`35d9707959`) only used existing payloads but turned the raw pointer into a second whole-payload
  `&mut` while `gen_iseq()` holds one. -4 borrows only the `may_write_block_code` field through the raw pointer.
* **Miri.** `bench/upstream/zwb1/miri` models `gen_iseq()` holding its `&mut` while `gen_entry_point()` and a side
  exit read the cache. -3's shape: UB under Stacked Borrows. -4's shape: clean under Stacked and Tree Borrows. Master
  already has overlapping whole-payload `&mut`s for the compiled ISEQ (`add_iseq_to_hir`, `CompilePolicy::new`); not
  in this change.
* **Numbers.** #19962's program, `--zjit-call-threshold=2`, `compile_time_ns` over 3 runs: master 11.89 / 11.35 /
  11.85 s, master-aa 11.44 / 11.22 / 10.98 s, -4 3.45 / 3.60 / 3.27 s; `zjit_alloc_bytes` 5,190,585 in all nine.
  Payloads created (temporary counter, one iteration), railsbench / lobsters / shipit: master 2,640 / 4,945 /
  4,865, -4 the same. `size_of::<IseqPayload>()` 152 on master and -4 (gdb on the release builds).
* **Tests** (`--enable-zjit=dev`, `25e91f0d07`): `make zjit-test` 2,015 of 2,015 (the SIGPROF test passed this run);
  btest at thresholds 1 and 2 all 2,148; `test_zjit_cli.rb` and `test_optimization.rb` at the default threshold and
  at 1, 143 tests, 0 failures.
* **State.** #19680's branch is untouched. The coordinator thread pushes -4 there, replaces the body, marks it ready
  and posts the comment after a confirm pass.

## ZSV1: the real class for `setinstancevariable` (-2, body changes requested)

Branch [`thomasklemm/zjit-setivar-real-class-2`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-setivar-real-class-2)
@ `47b2ed7110`, one commit on `4414d3ea25`, 2 files, +100/−1 (production code +18/−1 in `zjit/src/profile.rs`).
The `thermos-sol` confirm accepts the code, comment cleanup, message and single-commit packaging. All six
retained stats diffs replay byte-for-byte, supporting lobsters −584 generic writes per iteration. One text
must-fix remains: Shipit's generic-write total is unchanged, but fallback reasons shift −81/+81, so cut the
body's “setivar counters unchanged” and the comment's “only touches lobsters” comparisons, plus the body's
A/A-methodology clause. No new Ruby code fix is needed. Full
[confirm](../../bench/upstream/zsv1/thermos-review.md#confirm-of-revision-2-2026-11-18); builder tests and raw
stats provenance in [results-2.md](../../bench/upstream/zsv1/results-2.md). The bullets below describe the first build,
`thomasklemm/zjit-setivar-real-class` @ `fe6ea9ef84` (two commits on `7919a47d46`, +106/−1).
Queue item [ZSV1](../../bench/upstream/pr-queue/items/ZSV1.md).

* **What it does.** `setinstancevariable` gets `profile_self_real_class`, which records `rb_obj_class(obj)` instead
  of the singleton class. The class is used only for shape transitions
  (`rb_shape_transition_add_ivar_no_warnings`), and the interpreter looks them up with the real class
  (`obj_get_owner_class()`), so the transition is the one the interpreter makes. The real class is not a singleton
  class, so `observe_profiled_type` keeps it. `definedivar` is not changed: it uses only the shape and could take
  #19858's `profile_self_shape`, but it has no Rails reach.
* **Mechanism.** Two HIR tests: an `extend`ed receiver writing an existing ivar and one adding an ivar. On master
  both are `SideExit NoProfileSetIvar recompile`; on the branch a shape guard and `StoreField` (and the shape write
  for the transition).
* **Original numbers (unverified in review).** Micro (`O = C.new.extend(M)`, `def bump = @a = 1`, Callgrind slope over 200,000 calls): master 475,
  master-aa 475, branch 392 Ir per call; master writes 999,869 of 1,000,000 generically. Apps: lobsters −584 generic
  writes per iteration, railsbench and shipit unchanged (shipit's 54 moved to `not_t_object`). No time claim.
* **Original test report** (`--enable-zjit=dev`): `make zjit-test` 2,015 of 2,016 (the same SIGPROF test); btest at thresholds 1
  and 2 all 2,148; `test_zjit_cli`, `test_optimization`, `test_shapes`, `test_object`, `test_variable` at both
  thresholds 323 tests, 0 failures. Differential probe (extended, subclassed, frozen, `instance_variable_set` and
  >70-shape receivers, class ivars): identical output from the interpreter and from ZJIT at threshold 1, 2 and
  `--zjit-max-versions=1`, on master and the branch.
* **Thermos review (2026-11-18).** `thermos-sol`, exact `fe6ea9ef84`, **changes**; both rubrics applied by the
  sole reviewer, without subagents or other threads. No introduced correctness/security or structural defect
  found; existing shape/layout/frozen guards and GC barriers remain intact. Must trim redundant comments,
  substantiate or cut the original body numbers, qualify ordinary singleton receivers, remove body test/A-A
  narration, and package one coherent fix commit on refreshed master. The historical numbers above and the
  draft below are retained as author claims, not approved posting text. Full guard trace, sentence audit and
  new execution evidence: [review record](../../bench/upstream/zsv1/thermos-review.md).
* **Upstream check (2026-11-18).** Applies cleanly to master `4414d3ea25` (30 commits beyond the base, no
  relevant file drift). #1122 is open/unassigned with no comments; #1126 is closed/unmerged, and Ruby PR
  searches, the issue timeline and efegokdemir's PR list show no replacement. #19858 handles reads only.
* **Recommendation.** It answers the team's request with a small change; almost-zero Rails reach remains a
  historical claim, not a new verified measurement. Do not publish the current comments/body or claim speed
  from the diagnostic micro. Address the review, then obtain a fresh exact-head pass and the usual posting
  approval. The Ruby branch and drafts were not changed by the review.

### Comment draft for #1122 (not posted; -2, changes requested)

> `setinstancevariable` uses the profiled class only for the shape transition, and the interpreter takes that from
> the real class (`obj_get_owner_class()`), so profiling `rb_obj_class(obj)` is enough. With that, a write on an
> `extend`ed object gets a shape guard instead of `SideExit NoProfileSetIvar`, and once the ISEQ is out of versions,
> a guarded store instead of a generic write. On ruby-bench it only touches lobsters (−584 generic writes per
> iteration). Branch: https://github.com/thomasklemm/ruby/commit/47b2ed7110. OK to open it on ruby/ruby?

## ZSD1: `String#dup` on bare Strings (built, -3 on 2026-11-18)

Branch [`thomasklemm/zjit-string-dup-3`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-string-dup-3)
@ `baed628ce1`, one commit on `3a19e2efcf`, 10 files, +187/−15 (production code about 60 lines in
`cruby_methods.rs`, `hir.rs`, `codegen.rs`, `cruby.rs`, `stats.rs`, `gc_fastpath.rs` and the bindings; -2 had about
30). Queue item [ZSD1](../../bench/upstream/pr-queue/items/ZSD1.md); evidence
[`results-3.txt`](../../bench/upstream/zsd1/results-3.txt) and `bench/upstream/zsd1/zsd3-raw/`.

* **Ownership (checked 2026-11-17).** #1106 has no assignee and no comments; no open or closed ruby/ruby PR mentions
  `String#dup` with ZJIT; none of #1039's 83 rows touches string copies.
* **What it does.** `annotate!(rb_cString, "dup", inline_string_dup)`: when the receiver is likely `StringExact`,
  its profiled shape has no ivars and no NEWOBJ hook is active, add `PatchPoint NoNewObjHook`, guard `StringExact`,
  guard `shape_id & SHAPE_ID_HAS_IVAR_MASK == 0` (`guard_no_ivars`, side-exit reason `GuardNoIvars`), and emit
  `StringDup`, a leaf call to `rb_str_dup` with `gen_prepare_leaf_call_with_gc`. The guards are `rb_str_dup_m`'s
  `BARE_STRING_P`. Subclasses, strings with ivars and a redefined `dup` are dispatched as before. No return-type
  annotation, because `String#dup` on a subclass returns the subclass.
* **Why -3.** The thermos-sol review of `f991b4aa33` found two regressions against master. `StringCopy`
  (`rb_ec_str_resurrect`) embeds an embedded source of any size, while `str_duplicate` shares the buffer when an
  embedded copy would need more than 256 bytes (232 content bytes here): 512 instead of 40 bytes per copy of a
  frozen 300-byte String, visible to `ObjectSpace.memsize_of`. And without the C frame, ObjectSpace allocation
  tracing named the caller instead of `String#dup`. -3 calls `rb_str_dup` instead and reuses the `NoNewObjHook`
  invariant of the GC inline allocator (new `Function::assume_no_newobj_hook`). The -2 frozen filter in
  `gen_string_copy` is reverted, since `StringCopy` again only copies literals.
* **Numbers** (release builds, GCC 14.2, each measured twice). Micro (compiled loop keeping `s.dup` of a 20-byte
  String, Callgrind slope over 200,000 calls, threshold 2): master 397/397, -3 387/387 Ir per call (−10, −2.5%);
  250 → 240 with a 32 MiB heap. -2 saved 29: `rb_str_dup` does `rb_obj_class`, the embed-size check and `GET_EC`
  that `rb_ec_str_resurrect` skips. railsbench (ruby-bench `73918b2`, 15 warmup + 10): `ccall_String#dup`
  25,218 / 25,218 → 0, `ccall_rb_str_dup` 0 → 25,218, no `GuardNoIvars` or `NoNewObjHook` exits. That is about
  0.25 M Ir per iteration (0.005%), so no app run and no time claim; lobsters and shipit not rerun.
* **Stop rule.** Neither limit is passed, both are close: the Callgrind A/A is exact, so −10 is outside it, and the
  production code is about 60 lines (50 without blanks and comments). Kept as built; whether a 2.5% micro gain is
  worth sending is the open call.
* **Tests** (`--enable-zjit=dev`, `baed628ce1`): `make zjit-test` 2,018 of 2,019 (the SIGPROF test that fails on
  master in this orb). btest at thresholds 1 and 2: all 2,148. `test_zjit_cli`, `test_optimization`, `test_string`,
  `test_string_memory`, `test_stringchar` at thresholds 1 and 2: 657 tests, 39,844 assertions, 0 failures; memory-leak
  supplement 16 tests, 0 failures. `make zjit-bindgen` reproduces the bindings. Differential, interpreter vs ZJIT at
  thresholds 1 and 2, each with `--zjit-max-versions=1`, and the review's single-profile modes: `probe.rb`,
  `const_probe.rb`, `thermos_probe.rb`, `thermos_allocation_probe.rb` (early, late, memory) and the new
  `zsd3_probe.rb` (636 lines: sizes 0 to 3,000 around the cutoff in five encodings, frozen, mutable, interned and large
  embedded sources, memsize and storage, constants mutated after compilation; tracing started before and after
  warmup) all identical, except `probe.rb`'s allocation count 305 vs 303 at threshold 1 with max-versions 1, which
  master shows too. Needs a fresh review of `baed628ce1` before posting.

### Comment draft for #1106 (not posted)

> A bare String (class String, no ivars) can skip the `String#dup` frame: guard `StringExact` and
> `shape_id & SHAPE_ID_HAS_IVAR_MASK == 0`, which is `rb_str_dup_m`'s `BARE_STRING_P`, then call `rb_str_dup` as a
> leaf. Other receivers are dispatched normally. It uses `rb_str_dup` rather than `dupstring`'s `StringCopy`,
> which would embed copies of large embedded strings that `String#dup` shares, and it isn't inlined while
> allocation tracing is on, so `ObjectSpace` still attributes the copy to `String#dup`. On railsbench that takes
> all 25k `String#dup` calls per iteration off `CCallWithFrame`, but a loop of `s.dup` only goes from 397 to 387
> instructions per call, about 0.005% of a railsbench iteration. An inline allocation for runtime strings
> would be a separate step. Branch: https://github.com/thomasklemm/ruby/commit/baed628ce1. Worth opening on
> ruby/ruby at that size?

## #1130: one stack-overflow check for inlined frames (measured 2026-11-17, not built)

Each `PushInlineFrame` runs `gen_stack_overflow_check` (lea, cmp, jbe: 3 instructions on the hot path). The issue
proposes one depth check at the entry to the host function F instead. Measurement build: master `7919a47d46` plus
two counters (patch in the orb at `.amp/in/orb-backup/inline-frame-counters.patch`, not pushed). One counter counts
each inlined frame push. The other counts each entry to a function that has at least one `PushInlineFrame`, which is
where the hoisted check would run. Per iteration, ruby-bench, 15 warmup + 10 measured:

| | inlined frame pushes | entries to hosts | pushes per entry | checks saved | Ir saved (×3) | share of iteration |
| --- | --- | --- | --- | --- | --- | --- |
| railsbench | 2,408,855 | 1,665,888 | 1.45 | 742,967 | about 2.2 M | 0.045% (A/A 0.03%) |
| lobsters | 823,623 | 815,741 | 1.01 | 7,882 | about 0.02 M | 0.001% (A/A 0.01%) |
| shipit | 1,976,706 | 2,206,369 | 0.90 | −229,663 | about −0.7 M | +0.018% (A/A 0.03%) |

Iteration totals and A/A are the master Callgrind windows from zjit-leads.md (4,904 / 2,499 / 3,761 M Ir). The
Ir column is count × 3, not a new Callgrind run: the effect is too small to show up in an app window. Most host
functions take one inlined path per call, and many entries never reach the inlined call (shipit has more entries
than pushes), so a check at entry often replaces nothing. The ceiling, where the caller's existing check for F's
frame also covers inline depth, removes every push check: about 7.2 / 2.5 / 5.9 M Ir (0.15% / 0.10% / 0.16%).
That needs the caller to know F's final inlining depth, which changes when F recompiles. Interpreter entries would
still need a check at entry. Stop here unless tekknolagi wants the caller-side version, or #1023's
virtual inline frames change the costs. No comment draft: there is no result worth reporting on the issue.

## How we take an item

1. Measure the Rails effect first (ruby-bench counters, Callgrind with A/A), and check for a stated ask.
2. Comment on the issue with that data before writing a PR, and wait for no objection.
3. Then review (claude-code plus the adversarial pass) and open through the queue, after ZS1 has a response.
