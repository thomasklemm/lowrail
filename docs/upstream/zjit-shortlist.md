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
| 1 | #1064 cache `iseq_may_write_block_code` on `IseqPayload` | tekknolagi and k0kubun on ruby/ruby#19962, today | a 4,000-call method 10.9–12.0 s → 3.3–3.4 s of compile time; no new payloads, app alloc within A/A | ours (assigned), #19680 reopened by tekknolagi; tenderlove's #19962 is open | **built, ZWB1 -3** |
| 2 | #1106 `String#dup` on `StringExact` without ivars | tekknolagi's issue | 25k / 4k / 6k calls per iteration become frameless; micro −7.5% Ir per call, apps about 0.015% | free (no assignee, comment or PR; not in #1039) | **built, ZSD1** |
| 3 | #1122 profile the real class for `setinstancevariable` | tekknolagi's issue | micro −17% Ir per write; lobsters −584 generic writes per iteration, others 0 | free (efegokdemir's attempt was on the wrong repo) | **built, ZSV1** |
| 4 | #1130 one stack-overflow check for all inlined frames | tekknolagi's issue (design note, no comments) | net −0.74 M / −8 k / +0.23 M checks per iteration (railsbench / lobsters / shipit), at most 0.05% of Ir | free | **measured, not built** |
| 5 | #1129 / #1107 constant folds | tekknolagi's issues | unmeasured, small | free | not built |
| 6 | 15a attr_reader in a final version | none | lobsters / shipit share of 148k / 327k | free (#1039 row 78 unassigned) | old build, not rebased |
| 7 | lead 3 polymorphic recompile (ZL3) | answered on #776, waits for the team | largest on lobsters and shipit | ours | held |

Not taken: anything in k0kubun's #1039 rows (yield dispatch, polymorphic and megamorphic sends, ivar shape tables),
tekknolagi's backend redesign (#1077), #1120 (design), the protected-send PR (closed 11-04, not rebuilt).

## ZWB1: `iseq_may_write_block_code()` on the payload (built, -3)

Branch [`thomasklemm/zjit-cache-may-write-block-code-3`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-cache-may-write-block-code-3)
@ `35d9707959`, one commit on `7919a47d46` (merges cleanly onto `3a19e2efcf`), 3 files, +37/−2. Queue item
[ZWB1](../../bench/upstream/pr-queue/items/ZWB1.md) holds the replacement body and the comment draft.

* **Why -3.** The review of -2 (`82c529aa2e`) found that `get_or_create_iseq_payload()` in the check created payloads
  for callee ISEQs that never get one otherwise (`gen_send_iseq_direct`). Temporary counter on payload creation,
  railsbench / lobsters / shipit, one iteration: master 2,640 / 4,945 / 4,865, -2 2,689 / 5,019 / 4,944, -3 2,640 /
  4,945 / 4,865. That is the permanent memory k0kubun objected to on 11-04. -3 reads the payload without creating
  one and scans as before when there is none. The ISEQ being compiled always has a payload by then
  (`update_self_is_heap_object` and `compile_iseq` create it), so the large method keeps the full win.
* **Wording.** "Every JITFrame since stack maps" overstated #18960: JITFrames for CCalls with a frame already called
  it; #18960 added the call per side exit.
* **Numbers.** #19962's program, `--zjit-call-threshold=2`, 3 runs each: master `compile_time_ns` 11.98 / 10.90 /
  11.42 s, master-aa 11.09 / 11.45 / 10.95 s, branch 3.33 / 3.32 / 3.45 s; `zjit_alloc_bytes` 5,190,585 in all nine.
  (The reviewer saw master at 13.2–13.7 s on another machine; the earlier 11.64 s was one run.) ruby-bench
  `zjit_alloc_bytes` and `compiled_iseq_count` are within the master A/A on all three apps.
* **Tests** (`--enable-zjit=dev`): `make zjit-test` 2,014 of 2,015 (the known SIGPROF
  `test_profile_frames_during_direct_jit_to_jit_entry`, fails on master too); btest at `--zjit-call-threshold=1` and
  `=2` all 2,148; `test_zjit_cli.rb` and `test_optimization.rb` at default and threshold 1, 143 tests, 0 failures.
  Generated code is unchanged by construction (same answer, cached or not).
* **State.** tekknolagi reopened #19680 on 2026-11-17 22:27. Thomas approved pushing -3 to #19680's branch, the new
  body, marking it ready and the comment, after a confirm pass; the coordinator thread does that, not this one.

## ZSV1: the real class for `setinstancevariable` (built)

Branch [`thomasklemm/zjit-setivar-real-class`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-setivar-real-class)
@ `fe6ea9ef84`, two commits on `7919a47d46`, 2 files, +106/−1 (production code +21/−1 in `zjit/src/profile.rs`).
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
* **Numbers.** Micro (`O = C.new.extend(M)`, `def bump = @a = 1`, Callgrind slope over 200,000 calls): master 475,
  master-aa 475, branch 392 Ir per call; master writes 999,869 of 1,000,000 generically. Apps: lobsters −584 generic
  writes per iteration, railsbench and shipit unchanged (shipit's 54 moved to `not_t_object`). No time claim.
* **Tests** (`--enable-zjit=dev`): `make zjit-test` 2,015 of 2,016 (the same SIGPROF test); btest at thresholds 1
  and 2 all 2,148; `test_zjit_cli`, `test_optimization`, `test_shapes`, `test_object`, `test_variable` at both
  thresholds 323 tests, 0 failures. Differential probe (extended, subclassed, frozen, `instance_variable_set` and
  >70-shape receivers, class ivars): identical output from the interpreter and from ZJIT at threshold 1, 2 and
  `--zjit-max-versions=1`, on master and the branch.
* **Recommendation.** It answers #1122 and is small, but has almost no Rails reach; it is a tidy follow-up to
  #19858 rather than a performance PR. Before anything is posted, check that efegokdemir hasn't refiled #1126 on
  ruby/ruby.

### Comment draft for #1122 (not posted)

> `setinstancevariable` uses the profiled class only for the shape transition, and the interpreter takes that from
> the real class (`obj_get_owner_class()`), so profiling `rb_obj_class(obj)` is enough. With that, a write on an
> `extend`ed object gets a shape guard instead of `SideExit NoProfileSetIvar`, and once the ISEQ is out of versions,
> a guarded store instead of a generic write: 475 → 392 instructions per write in a loop. On ruby-bench it only
> touches lobsters (−584 generic writes per iteration). Branch:
> https://github.com/thomasklemm/ruby/commit/fe6ea9ef84. OK to open it on ruby/ruby?

## ZSD1: `String#dup` on bare Strings (built 2026-11-17)

Branch [`thomasklemm/zjit-string-dup`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-string-dup)
@ `c71669b114`, one commit on `7919a47d46`, 8 files, +138/−11 (production code about 30 lines in
`cruby_methods.rs`, `hir.rs`, `cruby.rs`, `stats.rs` and the bindings). Queue item
[ZSD1](../../bench/upstream/pr-queue/items/ZSD1.md).

* **Ownership (checked 2026-11-17).** #1106 has no assignee and no comments; no open or closed ruby/ruby PR mentions
  `String#dup` with ZJIT; none of #1039's 83 rows touches string copies.
* **What it does.** `annotate!(rb_cString, "dup", inline_string_dup)`: when the receiver is likely `StringExact`
  and its profiled shape has no ivars, guard `StringExact`, guard `shape_id & SHAPE_ID_HAS_IVAR_MASK == 0` (new
  `guard_no_ivars`, side-exit reason `GuardNoIvars`), and emit `StringCopy`. That is `rb_str_dup_m`'s
  `BARE_STRING_P` check. Subclasses, strings with ivars and redefined `dup` keep `CCallWithFrame`. No return-type
  annotation, because `String#dup` on a subclass returns the subclass. `SHAPE_ID_HAS_IVAR_MASK` was added to the
  bindings by hand: `make zjit-bindgen` fails in this orb on a gcc-configured build (an unrelated
  `jit_bindgen_constants` replacement), so CI's bindgen check is the one to confirm it.
* **One difference, not observable to Ruby code:** `rb_ec_str_resurrect` embeds an embedded source of any length;
  `str_duplicate` shares a buffer for embedded sources above 256 bytes. Same contents, encoding and flags.
* **Numbers.** Micro (compiled loop keeping `s.dup` of a 20-byte String, Callgrind slope over 200,000 calls,
  threshold 2): master 388, master-aa 388, branch 359 Ir per call (−7.5%). Stats per iteration (15 warmup + 10,
  512/1024 MiB, 0 OOM; diff filtered against a second master build): `ccall_String#dup` railsbench 25,218 → 0,
  lobsters 4,243 → 43, shipit 5,663 → 12, all moved to `rb_ec_str_resurrect`; no `exit_guard_no_ivars_failure`. At
  29 Ir per call that is about 0.7 M Ir per railsbench iteration (0.015%), below the Callgrind A/A, so no app run
  and no time claim. The larger saving tekknolagi's issue hints at, an inline allocation for runtime strings like
  `gen_string_copy`'s constant fast path, is not in this change.
* **Tests** (`--enable-zjit=dev`, head `c71669b114`): `make zjit-test` 2,017 of 2,018 (the SIGPROF test that fails
  on master in this orb); two new HIR tests and two codegen tests; two existing snapshots
  (`test_no_elide_freeze_with_unfrozen_str`, `test_no_elide_uminus_with_unfrozen_str`) now show the inlined copy.
  btest at thresholds 1 and 2: all 2,148. `test_zjit_cli`, `test_optimization`, `test_string`,
  `test_string_memory` at thresholds 1 and 2: 653 tests, 0 failures. Differential probe (18 receivers: literal,
  frozen, interned, shared, 5,000 bytes, binary, UTF-8, US-ASCII, capacity, with ivars, with object_id, extended,
  singleton, two subclasses, one with `initialize_copy`; plus a mid-run redefinition of `String#dup`): identical
  output from the interpreter and ZJIT at thresholds 1 and 2 and `--zjit-max-versions=1`, on master and the branch.

### Comment draft for #1106 (not posted)

> A bare String (class String, no ivars) can take the same `StringCopy` as `dupstring`: guard `StringExact` and
> `shape_id & SHAPE_ID_HAS_IVAR_MASK == 0`, which is `rb_str_dup_m`'s `BARE_STRING_P`. Everything else keeps the C
> call. On ruby-bench that takes all of railsbench's 25k `String#dup` calls per iteration off `CCallWithFrame`
> (lobsters 4.2k, shipit 5.6k), and a loop of `s.dup` goes from 388 to 359 instructions per call. The allocation
> itself is still `rb_ec_str_resurrect`; an inline allocation for strings not known at compile time would be a
> separate step. Branch: https://github.com/thomasklemm/ruby/commit/c71669b114. OK to open it on ruby/ruby?

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
