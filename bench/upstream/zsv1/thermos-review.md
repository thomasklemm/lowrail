# ZSV1 Thermos review — 2026-11-18

Verdict: **changes**, on exactly `fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d`.
No introduced correctness, security or structural-maintainability defect was found in the code audit or
executed probes. Publication is blocked by the added comments, unsupported body numbers, body wording and
commit packaging described below. This is a review pass, not permission to open or push a Ruby PR.

Reviewer: `thermos-sol`, thread `T-01a1ef67-4308-7296-a24a-80471f35f540`. Both Thermos rubrics were applied
directly by the same reviewer, as requested; no other reviewer, subagent or thread was used. Read `AGENTS.md`,
`docs/PLAN.md`, `docs/DECISIONS.md` and the queue format first. The Ruby branch and public drafts are unchanged.

## Scope and current upstream

Base: `7919a47d467ba961b8912fa61e0ee1fe0ff4ef0c`. Two commits, two files, +106/-1; production code is +21/-1
in `zjit/src/profile.rs`. The fork ref still points at the reviewed full SHA. Its first commit is
`93d62841745cadbe54e83968fa6b31e727353182`, which adds the two tests with side-exit snapshots; the head changes
the profiler and the snapshots. Both commits have Thomas's author/committer identity and no trailers.

Ruby master fetched for this review: `4414d3ea25fe74f06bf13370b06973544bbc1dd4` (2026-11-18 15:35 UTC).
It is 30 commits beyond the base. Neither changed file, nor `zjit/src/hir.rs`, `shape.c` or `object.c`, differs
between that base and master. `git merge-tree --write-tree origin/master HEAD` succeeds, and the exact
base-to-head patch passes `git apply --cached --check` against an alternate index loaded from master.
**It still applies; master does not contain the fix.** This is an application/source check, not a test of a
rebased build.

After the independent code audit, read the following live sources with `gh api`:

* [Shopify/ruby#1122](https://github.com/Shopify/ruby/issues/1122): open, unassigned, no comments; the ask is
  “We need that one for the shape transition tree anyway.” Its timeline has only the closed overlapping
  [Shopify/ruby#1126](https://github.com/Shopify/ruby/pull/1126), not a new Ruby PR.
* #1126 is efegokdemir's same real-class profiling approach, closed unmerged. The
  [maintainer comment](https://github.com/Shopify/ruby/pull/1126#issuecomment-6862802144) asks for ruby/ruby rather
  than Shopify/ruby; it is not a technical rejection. Read its full one-file diff too.
* `search/issues` across open and closed ruby/ruby PRs for `setinstancevariable`, `setivar`, `"real class"`,
  `"Profile the real class"`, `1122`, recent `singleton`, and `author:efegokdemir` found no replacement PR.
  The author's only three results are #19789, #19790 and #19791. A direct all-state pull query for this fork
  head/branch returns no PR. These are time-bounded search results, not a claim about unpublished branches.
  Separate all-state Shopify issue searches for `setinstancevariable`, `setivar` and `"real class"` found
  #1122 plus older optimization/burndown issues, not a newer replacement ask. Search responses were complete.
* [ruby/ruby#19858](https://github.com/ruby/ruby/pull/19858) merged as `b721561cf4` on November 12. It removes
  class profiling for reads; it does not implement the write-side change. Read
  [ruby/ruby#19540](https://github.com/ruby/ruby/pull/19540) as the source of the singleton retention policy.
* Checked [Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039)'s assignment table and
  [#1120](https://github.com/Shopify/ruby/issues/1120). The owned ivar shape-table work and broader
  no-singleton assumptions are related, not this specific profiling fix. Reviewed the potentially related
  ruby/ruby #17865 (RData stores), #19891 (type cleanups), #19959 (singleton invalidation) and #19791
  (distribution compression) diffs/metadata: none takes over this fix.

## Correctness/security rubric

Cold read: for `setinstancevariable` only, capture the same shape and layout flags as before, replace the
recorded singleton class with the real class, and retain that class through the existing profiling barrier.
All other profiled bytecodes keep their previous policy.

* `ProfiledType::real_class` preserves immediate, RObject, extended-storage and embedded-Struct flags from
  `new`; native `rb_obj_class`, not a Ruby `class` send, walks singleton/ICLASS wrappers. Subclasses stay
  subclasses. It neither calls app code nor eagerly creates a singleton class.
* `observe_profiled_type` still performs the ISEQ-to-class write barrier (`profile.rs:192`). Profile classes
  are marked movable and relocated by `gc.rs:114-143` through `each_object`/`each_object_mut`. No singleton
  class or receiver is newly retained by this path; no field or per-profile allocation type is added.
* The class is used by `prepare_optimized_setivar` only when computing a missing-ivar transition
  (`hir.rs:6513-6574`). For the accepted T_OBJECT path, `shape.c:808-826,896-918` uses the same `rb_obj_class`.
  Its special class/module-owned imemo case does not apply to that path. Class/module, String, Array, Hash
  and other unsupported layouts retain the generic store; this is not a promise to specialize all extended
  Ruby values.
* No class guard needs replacing: the store is layout-dependent, not method-lookup-dependent.
  `dispatch_setivar`/`dispatch_ivar` still guard heap-ness and exact shape, or branch to a generic fallback in
  the final version (`hir.rs:8731-8806,8846-8895,11065-11121`). Frozen status and layout are part of the shape;
  frozen, complex and capacity-changing cases are still refused. The flags are not inferred from the new
  real class. The ordinary write barrier remains in `emit_optimized_setivar`.
* A value-producing callback or suspended fiber can change the receiver before the write; the shape check
  belongs to the later store, so an entry-time assumption is not substituted for it. No method-resolution,
  tracing, Ractor or feature-flag guard was removed. Exactness checklist items 1, 2, 4, 6 and 7 were probed;
  implicit conversions, accumulator adoption and require/config changes (3, 5 and 8) are not introduced here.

Exact-head trace anchors: [profile filter and barrier](https://github.com/thomasklemm/ruby/blob/fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d/zjit/src/profile.rs#L178-L194),
[real-class lookup](https://github.com/thomasklemm/ruby/blob/fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d/object.c#L258-L291),
[interpreter transition owner](https://github.com/thomasklemm/ruby/blob/fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d/shape.c#L807-L826),
[store eligibility and transition](https://github.com/thomasklemm/ruby/blob/fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d/zjit/src/hir.rs#L6513-L6574),
[shape dispatch and fallback](https://github.com/thomasklemm/ruby/blob/fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d/zjit/src/hir.rs#L8731-L8806),
and [movable profile references](https://github.com/thomasklemm/ruby/blob/fe6ea9ef84bfbb6fdd7fd5091737ae0231183a3d/zjit/src/gc.rs#L114-L143).

The differential probe emits 33 rows, with addresses normalized only inside exception messages. It checks
assignment return values and stored values, existing/new/removed ivars, extended receivers before the first
profile, ordinary/subclass/mixed classes, a raising singleton `class` override, late extension and prepend,
0/1/3/10/70/150 extra ivars, 180 distinct class-shape branches, new heap values across minor GC, compaction
verification, anonymous-class GC, frozen cold/late/new-ivar writes, freezing and growing during the RHS,
String subclasses and non-T_OBJECT receivers, immediate errors, a suspended fiber, a thread-local receiver,
and an actual non-owner Ractor class write. The interpreter's expected errors include FrozenError and
Ractor::IsolationError, not rescued setup failures.

## Maintainability rubric and required edits

The implementation is L0: small helpers in the canonical profiler, patterned after `profile_self_shape` and
`shape_only`, with the existing distribution and GC machinery reused. No new mode, branch scattered through
HIR/codegen, wrapper type or generic guard API is warranted. `profile.rs` goes 597 to 617 lines; the existing
large HIR snapshot file grows by 85 lines without crossing a new 1,000-line boundary. No structural refactor is
justified by this diff. Ruby flog/RuboCop metrics do not apply to the changed Rust methods.

Required before publication:

1. **Trim the added comments** (`profile.rs:244-246,394`; `hir/opt_tests.rs:13009-13010,13051`). The test names
   and bodies already explain existing versus new ivars; delete those three test-comment lines. Delete the
   constructor doc comment that restates its name. The real-class rationale can stay, if needed, as one short
   why-line, not the three-line implementation explanation. These are required changes under DECISIONS,
   including comments in tests, not optional nits. None is a public-method RDoc leak.
2. **Remove or substantiate the numbers.** No ZSV1 micro script, original raw Callgrind dumps, fixed-heap
   controls, per-window JIT counters, or app base/A/A/head results are committed. The shortlist repeats the
   figures; it is not independent evidence. The review's new diagnostic loop confirms the changed mechanism,
   not the exact original 475/475/392 or lobsters 11,382/10,798 and 5,951/5,367 figures. Supply replayable pinned
   evidence, or cut these figures from the body and comment draft. Do not turn instruction counts or fewer
   generic stores into a time/request-speed claim. The explicit team ask and removed permanent fallback are
   exceptions to the ruby-bench speed-effect requirement; they do not certify numbers.
3. **Shorten and qualify the body and commit message.** “An object whose class is a singleton class” is too
   broad: the existing filter exempts top-level self, blockparamproxy, Class and Module. Say “an ordinary
   object with a singleton class.” Shape-specialized stores remain conditional on the existing layout,
   frozen/complex and capacity checks. Cut the paragraph narrating the first/second commits, the A/A build
   and Callgrind methodology from the PR body; those belong here. Keep supported ZJIT evidence in the tools'
   own format rather than the hand-written micro summary. The current stats diff's format is the right kind
   of evidence, but its values still need backing. The comment draft must lose the same unsupported figures.
4. **Make one coherent fix commit on a refreshed base before publication**, per DECISIONS' commit rule.
   The first of these two commits deliberately asserts the missed-optimization snapshots which the second
   immediately replaces. Preserve the final tests, identity and reason; do not publish that scaffolding as a
   separate finished change. A new Ruby head needs a fresh pass. This review does not modify that branch.

## Sentence audit

| Draft claim | Checked against | Result |
| --- | --- | --- |
| Title: profile the real class for setinstancevariable | Exact `profile.rs` diff | Accurate. |
| Singleton-class receivers are “other” | `observe_profiled_type`, #19540 | Correct for ordinary objects, not the exempt values above; qualify in body and message. |
| Missing profile causes recompile exit, then generic final-version write | `dispatch_ivar`, final-version policy, differential micro | Correct for the affected path; it is not universal for every singleton value. |
| Only shape transitions use the profiled class | `prepare_optimized_setivar`, `SetIvarSpec`, `dispatch_setivar` | Correct; no method lookup is replaced. |
| Interpreter obtains it from the real class | `obj_get_owner_class`, `rb_obj_class` | Correct on the accepted T_OBJECT path; class/module-owned imemos have a different case. |
| These writes get the same shape guard | Exact HIR tests and guard path | Correct for eligible object layouts; existing generic fallbacks remain. |
| #19858 did the read-side counterpart using shape only | Live PR and merged source | Correct; it did not already fix writes. |
| Fixes Shopify/ruby#1122 | Live issue ask, micro mechanism | Reasonable linkage, not maintainer approval to publish. |
| First commit adds two missed-optimization tests; second changes snapshots | Both exact commit diffs | True, but remove this test/history narration from the body and squash for publication. |
| Micro 475/475/392 and 999,869 generic writes out of a million | No original retained evidence found | Unverified original absolutes; review probe differs in setup, so do not silently substitute its numbers. |
| Lobsters -584 generic writes; railsbench/shipit within A/A | Only shortlist prose and draft diff found | Not independently verified; retain as historical author claims, not approved body evidence. |

Both exact commit messages were read. The production commit's reason and title are clear, and its
`obj_get_owner_class` argument is sound within the supported path; qualify the singleton blanket statement.
The issue URL is correctly cross-repository, unlike a bare `#1122`. The test-only commit has only a title.
No code comment is necessary to repeat this reasoning.

## Execution evidence and limitations

Built the exact head on Linux x86-64 with GCC 14.2.0, Rust 1.100.0 and bootstrap Ruby 4.0.9:
`./autogen.sh; ./configure --enable-zjit=dev --disable-install-doc --without-jemalloc; make -j2`.
Installed cargo-nextest 0.9.152 from its checksum-verified release archive, without changing project setup.

* Exact head, `make -j2 zjit-test ZJIT_TESTS=-j2`: **2,016 passed, 15 skipped**, no failure. Both new snapshots
  pass. The same command on the exact base runs 2,014 tests: **2,013 passed, 1 failed, 15 skipped**. The failure
  is `test_profile_frames_during_direct_jit_to_jit_entry`, aborting because “rb_profile_frames was not called
  from SIGPROF handler” at `codegen_tests.rs:7619`. That test and its signal handler are unchanged by this
  patch. This reproduces the historical failure on the base, not an introduced failure; its underlying
  timing/signal cause was not diagnosed. Neither suite was retried until green.
* Exact-head btest at threshold 1: **PASS all 2,148 tests**, with the existing “Fiber count: 10000 (skipping)”
  line. The shortlist's historical threshold-2 btest result was not independently rerun in this pass.
* Exact-head `test_zjit_cli`, `test_optimization`, `test_shapes`, `test_object`, `test_variable`, each run at
  thresholds 1 and 2 with `TESTOPTS=-j2`: **323 tests, 15,405 assertions, 0 failures, 0 errors, 0 skips** per
  run. These are new results, separate from the shortlist's historical test report.
* The 33-row differential probe matches the interpreter with `miniruby` on head and with full `ruby` on both
  exact base and head, at ZJIT thresholds 1 and 2, each also with `--zjit-max-versions=1`. Both interpreter
  controls match too. Each process exits 0. No arbitrary JIT tuning option was passed to the interpreter.
* A separate existing-ivar loop on an extended C instance warms 100 calls of 1,000 writes, runs GC, disables
  GC and then measures. Base's million-write window makes **1,000,000 generic stores**, head's makes **0**;
  both windows have zero side exits, zero OOM compile errors and unchanged compiled-ISEQ/failed-ISEQ/
  compiled-exit counters. Base's 30 no-profile setivar exits occurred in warm-up, not the measured window.
  However this revision has **no `invalidation_count` statistic**, even with `--zjit-stats-quiet`;
  DECISIONS' documented JIT-flat gate
  and [body-numbers](../../../docs/upstream/body-numbers.md) therefore cannot certify it. Missing is not zero.
* Diagnostic Callgrind 3.24.0 on that dev `miniruby`, fixed `RUBY_GC_HEAP_INIT_BYTES=33554432`,
  `--smc-check=all-non-file`, whole-process totals at 50,000/250,000 calls: base 512,566,754/597,174,420 Ir,
  head 413,204,833/432,948,233 Ir (slopes 423.03833 and 98.717 per added call). This different harness is not
  a reproduction of the body's 475/392 absolute values. It has no independent A/A rebuild or heap-control
  cohort and cannot pass the JIT-flat gate, so these are diagnostic counts, not a certified speed claim.
  No brk overflow was reported.
* Constructed the losing case too: many cold write methods on an object with a deep `extend` chain. Native
  `rb_obj_class` walks that chain; the added lookup happens while collecting profiles (five samples per
  instruction by default), not on every warmed specialized store. `cold-profile.rb` defines 100 distinct
  existing-ivar writers and calls each 29 times with the default threshold of 30. Whole-process Callgrind
  counts with the same fixed initial heap and options are below. All six processes exit 0 and check the final
  stored value. These single diagnostic runs include setup and profiling, deliberately not a JIT-flat window;
  no A/A or percentage/regression claim is made. The 1,000-module stress row stays in the record, not a body.

  | Extension modules | Base Ir | Head Ir |
  | --- | ---: | ---: |
  | 0 | 113,371,610 | 113,394,315 |
  | 1 | 114,428,146 | 114,706,472 |
  | 1,000 | 173,451,216 | 180,161,447 |

Review working files and copied logs are under `.amp/in/orb-backup/zsv1-review/` in this thread's orb;
original log paths are `/tmp/zsv1-*`. The differential script is `probe.rb`, SHA-256
`fde3f5de2a60ace4c7b340b3e0aeffb2dc532db4bbec518c605d031f59515fa8`; the mechanism loop is `micro.rb`, SHA-256
`17a2e3b1c5aaac191e0e093ac776470971c6ab47595de19c9e0997ceb2799d6f`; `cold-profile.rb` is
`4c2d5674a10c7decb57488cdd7793b41f25894e619f4f817f3a999d9fe628877`.

Commands use that scratch Ruby checkout, a PATH containing bootstrap Ruby and cargo-nextest, and the same
configure options on base and head. For uninstalled full Ruby, prepend the checkout, `lib`, `.ext/common`
and `.ext/x86_64-linux` to `RUBYLIB` so `rbconfig` and built extensions are found. The executed test/probe forms
are:

```sh
make -j2 zjit-test ZJIT_TESTS=-j2
make btest RUN_OPTS='--zjit --zjit-call-threshold=1'
make test-all TESTOPTS=-j2 RUN_OPTS='--zjit --zjit-call-threshold=1' \
  TESTS='ruby/test_zjit_cli ruby/test_optimization ruby/test_shapes ruby/test_object ruby/test_variable'
# Also run the selected Ruby suite at threshold 2.
./ruby ../probe.rb
./ruby --zjit --zjit-call-threshold=1 ../probe.rb
# Also threshold 2, then both with --zjit-max-versions=1; diff the 33 rows.
./miniruby --disable-gems --zjit --zjit-stats-quiet ../micro.rb 1000000
RUBY_GC_HEAP_INIT_BYTES=33554432 valgrind --tool=callgrind --smc-check=all-non-file \
  --callgrind-out-file=../head-50000.cg \
  ./miniruby --disable-gems --zjit --zjit-stats-quiet ../micro.rb 50000
# Also 250000, and both windows on the base, keeping the raw dumps.
RUBY_GC_HEAP_INIT_BYTES=33554432 valgrind --tool=callgrind --smc-check=all-non-file \
  --callgrind-out-file=../head-cold-1000.cg \
  ./miniruby --disable-gems --zjit ../cold-profile.rb 100 1000
# Also depths 0 and 1, and all three on base.
```

Original application counters and a release ruby-bench speed comparison were not rerun. This review does not
claim AArch64, sanitizer or nondefault-GC validation. No setup repair, Ruby fork push, upstream post or PR opening
was performed.

## Confirm of revision 2 (2026-11-18)

Verdict: **changes**, on exactly `47b2ed7110f84ca76cc7aa6e767a1119e62c09a3`. Both rubrics were applied directly
by the same `thermos-sol` reviewer, without another reviewer, subagent or thread. **No code must-fix remains.**
The remaining required edit is a false other-app comparison in the public drafts; cutting that comparison also
removes the remaining A/A-methodology narration. This is not a request to change the Ruby implementation.

The fix-round input is [results-2.md](results-2.md), retained on Lowrail `bbc076c8`. The Ruby fork ref fetched for
this confirm is `thomasklemm/zjit-setivar-real-class-2`, at the exact head above.

### Four-findings closure check

| Original finding | Confirm result |
| --- | --- |
| Redundant comments | **Closed.** Both test comments (three lines) and the constructor doc comment are gone. The sole added comment is one why-line connecting real-class profiling to the interpreter's transition owner. It explains the choice rather than narrating the implementation. |
| Unsupported numbers | **Closed for the remaining positive claim.** Micro figures are cut. All nine gzip files are valid and identify the expected Ruby build and 10 measured iterations. All six retained branch/A/A diffs regenerate byte-for-byte. The lobsters -584 is independently recovered from three raw counters, with zero A/A movement for those counters. No timing, instruction or request-speed claim is certified. |
| Body and commit wording | **Partly closed; one must-fix remains below.** The message and body now qualify ordinary singleton receivers and preserve layout/frozen/capacity boundaries. Test-history and micro methodology are gone. The new blanket claim about other apps is false, and the stats lead-in still narrates the A/A filter. |
| Commit packaging | **Closed.** Exactly one commit, with direct parent `4414d3ea25fe74f06bf13370b06973544bbc1dd4`, Thomas Klemm as author and committer, and no trailers. The final tests are in that commit. |

### Correctness/security and maintainability confirm

`git diff fe6ea9ef84 47b2ed7110 -- zjit/src/profile.rs zjit/src/hir/opt_tests.rs` contains only the comment
edits above. Comparing both files after removing comment-only lines yields byte-identical text, including the
Ruby test programs and HIR snapshots. Neither file nor `hir.rs`, `gc.rs`, `shape.c` or `object.c` changed between
the old base and the new base. The original guard/barrier/fallback audit therefore still applies; no new type,
branch, guard, state, allocation or abstraction is introduced by the fix round. Maintainability remains L0.

Current Ruby master at this confirm is `353c293c1b1171916bd7c82f73751b01f2fb4cb4`. Those relevant files also have
no drift from the new base, and `git merge-tree --write-tree origin/master 47b2ed7110` succeeds. This is a clean
application check, not a claim that the current-master combination was rebuilt. The original upstream-overlap
search was not repeated as part of this four-finding confirm.

Rebuilt the exact head in this review checkout with `make -j2 miniruby ruby`, using the earlier dev configure
and toolchain. Ran:

```sh
make zjit-test "ZJIT_TESTS=-j1 -E 'test(test_setivar_singleton_receiver)'"
```

Both selected HIR tests pass; 2,029 other tests are filtered out. The same retained 33-row differential probe
passes again with the rebuilt full Ruby: interpreter, ZJIT threshold 1 and 2, and both with
`--zjit-max-versions=1`. All five processes exit 0 and emit identical rows; the interpreter output also matches
the original review's output. This rechecks mutation/frozen/layout/GC/fiber/Ractor boundaries on the new exact
head, without treating comment-only source equality as fresh runtime execution. The builder's full
2,016-test, btest and selected Ruby-suite results in `results-2.md` were not rerun in this confirm.

### Raw stats replay

Read `stats/run.sh`, `../zne1/stats_harness.rb` and `../zne1/stats_diff.rb`, not only their summaries. The harness
resets counters after warm-up and retains non-zero integer totals over 10 iterations. Dividing those totals by
the stored iteration count gives:

| Workload / counter | Master | Master A/A | Branch |
| --- | ---: | ---: | ---: |
| lobsters: `dynamic_setivar_count` | 11,405 | 11,405 | 10,821 |
| lobsters: `setivar_fallback_no_side_exits` | 5,956 | 5,956 | 5,372 |
| lobsters: `ccall_rb_vm_setinstancevariable` | 11,345 | 11,345 | 10,761 |
| railsbench: `dynamic_setivar_count` | 4,060 | 4,060 | 4,060 |
| railsbench: `setivar_fallback_no_side_exits` | 30 | 30 | 30 |
| railsbench: `setivar_fallback_not_t_object` | 4,030 | 4,030 | 4,030 |
| shipit: `dynamic_setivar_count` | 48,920 | 48,920 | 48,920 |
| shipit: `ccall_rb_vm_setinstancevariable` | 48,883 | 48,883 | 48,883 |
| shipit: `setivar_fallback_no_side_exits` | 41,029 | 41,029 | 40,948 |
| shipit: `setivar_fallback_not_t_object` | 7,891 | 7,891 | 7,972 |

The printed lobsters -584 values are exact, not rounding artifacts. Railsbench's setivar family is unchanged.
Shipit's two fallback-reason changes cancel, leaving its total generic writes unchanged. They are **not** A/A
noise: master and master-aa match on both. Each 81-per-iteration movement is below the diff tool's absolute
100 cutoff; the no-side-exits change also misses its 1% cutoff. Thus an empty filtered diff does not establish
that no underlying counter changed.

The unrelated railsbench `ccall_rb_hash_new` row remains in the retained diff and is not claimed in the body.
No raw values were edited or baseline regenerated. The raw Shipit window also records 2/0/1 compiled ISEQs and
39/0/13 compiled side exits (master/master-aa/branch totals); it is not JIT-flat even before considering the
missing `invalidation_count`. Counter evidence is accepted as diagnostic mechanism/reach evidence, not as a
speed measurement. The team-requested-change exception is unchanged.

Replay performed from the Lowrail root, decompressing into the review's scratch directory, for each of
`lobsters`, `railsbench` and `shipit`:

```sh
gzip -t bench/upstream/zsv1/stats/*.json.gz
work=.amp/in/orb-backup/zsv1-review
mkdir -p "$work"
for b in lobsters railsbench shipit; do
  for side in master master-aa branch; do
    gzip -cd "bench/upstream/zsv1/stats/stats-$side-$b.json.gz" > "$work/confirm-$side-$b.json"
  done
  ruby bench/upstream/zne1/stats_diff.rb "$work/confirm-master-$b.json" \
    "$work/confirm-branch-$b.json" "$work/confirm-master-$b.json" \
    "$work/confirm-master-aa-$b.json" --pct 1 > "$work/confirm-$b.diff"
  diff -u "bench/upstream/zsv1/stats/stats-$b.diff" "$work/confirm-$b.diff"
  ruby bench/upstream/zne1/stats_diff.rb "$work/confirm-master-$b.json" \
    "$work/confirm-master-aa-$b.json" --pct 1 > "$work/confirm-aa-$b.diff"
  diff -u "bench/upstream/zsv1/stats/stats-aa-$b.diff" "$work/confirm-aa-$b.diff"
done
```

All six `diff` commands exit 0. The decompressed JSON, replay output and build/probe logs are retained under
`.amp/in/orb-backup/zsv1-review/` with a `confirm-` prefix. This confirms the retained data's arithmetic and
filtering; it does not independently reproduce the builder's three release builds or rerun the applications.

### Remaining required draft edit

The item body says “railsbench and shipit show no change in setivar counters”; its `impact` and the shortlist
overview made the same blanket claim. The comment draft says “it only touches lobsters.” The raw Shipit rows
above contradict these statements. `results-2.md` itself correctly records the -81/+81 redistribution.

Prefer cutting, not explaining more upstream:

* Replace the item's entire stats lead-in with **“ZJIT stats per iteration for lobsters:”**. This also removes
  the A/A-methodology clause, which belongs in this record under DECISIONS.
* Replace the comment's “On ruby-bench it only touches lobsters” with **“On lobsters, it removes 584 generic
  writes per iteration.”** The supported positive finding needs no exclusivity claim.

The review updates the queue's internal impact/note and shortlist status to avoid repeating the false summary,
but leaves the actual public drafts as reviewed. Only this text correction needs confirming if the Ruby head
stays unchanged; the code does not need another fix round or a new branch for this finding.

## Text-only confirm of revision 2 (2026-11-18)

Verdict: **approve**, no must-fixes, on unchanged Ruby head
`47b2ed7110f84ca76cc7aa6e767a1119e62c09a3`. Read the complete item body and shortlist comment draft after
Lowrail `899e36d9`. The live fork ref still resolves to that exact Ruby head. Both requested cuts are present:

* The body lead-in is now “ZJIT stats per iteration for lobsters:”, with no other-app comparison or A/A narration.
* The comment now says “On lobsters, it removes 584 generic writes per iteration.” It no longer claims that
  lobsters is the only affected workload.

Independently parsed the three retained `stats/stats-{master,master-aa,branch}-lobsters.json.gz` files with
Ruby `Zlib` and `JSON`, checked their Ruby pins and 10-iteration denominators, and divided integer totals exactly:
`dynamic_setivar_count` 11,405 / 11,405 / 10,821; `setivar_fallback_no_side_exits` 5,956 / 5,956 / 5,372;
`ccall_rb_vm_setinstancevariable` 11,345 / 11,345 / 10,761. Every branch delta is exactly -584 per iteration and
every A/A delta is zero. Repeated the lobsters replay command above with a `text-confirm-` scratch prefix;
`diff -u stats/stats-lobsters.diff` against the regenerated output exits 0. Both printed body rows and the
comment's generic-write claim are supported without rounding or an exclusivity claim.

The rest of the drafts retain the previously audited mechanism and guard boundaries. All four original
findings and the final text finding are closed. This scoped text-only confirm carries forward the solo
correctness/security and maintainability review, exact-head execution and packaging audit above; it is not a
new Ruby build, suite run, application run, master-application check or upstream-overlap search. No speed claim
is certified. The public drafts are unchanged by this pass; no fork push, PR opening or upstream post was made.

## Exact-head confirm of revision 3 (2026-11-25)

Verdict: **approve**, **no must-fixes**, on exactly
[`ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5`](https://github.com/thomasklemm/ruby/commit/ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5).
Reviewer: `thermos-sol`, thread `T-01a2129c-eccf-7381-ba7b-5a5579c681dd`. Applied both Thermos rubrics directly,
without subagents, delegation or another thread. This is a fresh code, text and execution confirm on the new
base, not merely a carry-forward of the November 18 approval. Astra's separate exact-head gate is not waived.

### Pins, packaging and upstream drift

Cloned the fork into `.amp/in/orb-backup/zsv1-confirm/ruby`, checked out the full head detached, and verified
`git ls-remote` still resolves `refs/heads/thomasklemm/zjit-setivar-real-class-3` to it. Its direct parent is
`3b188d0dd5b23bbf94831a890ca907b92420c22d`. Exactly one fix commit, two files, +100/-1; author and committer
are Thomas Klemm `<github@tklemm.eu>`, author date retained, no trailers. The complete commit message is
byte-identical to `47b2ed7110`'s. Independently ran:

```text
$ git rev-list --count 4414d3ea25..3b188d0dd5
435
$ git range-diff 4414d3ea25..47b2ed7110 3b188d0dd5..ca3ea90482
1:  47b2ed7110 = 1:  ca3ea90482 ZJIT: Profile the real class for setinstancevariable
```

Read the full old-base/new-base diffs, not only the changed Ruby patch. `profile.rs`, `shape.c`, `shape.h`,
`hir_type/`, distribution and options are unchanged. The only `object.c` changes allocate Class/Struct/Data
inline fields; `rb_obj_class()` and its non-calling singleton/ICLASS walk are unchanged. The `gc.rs` addition
is a SAFETY comment, not a change to profile marking or relocation.

The HIR/codegen changes do not alter `prepare_optimized_setivar`, `emit_optimized_setivar`, `dispatch_setivar`,
`dispatch_ivar`, shape guards, `CompilePolicy::new`, `exit_recompile` or profile reset policy. They do change
machinery used by exits: `PendingJITFrame` delays stable allocation until after exit deduplication; stack maps
now distinguish method receiver slots from block frames; readonly C-frame GC updates are handled in C; and
`iseq_may_write_block_code` has a per-payload cache. Traced these through `build_side_exit`,
`compile_exit_stack_map`, `PendingJITFrame::alloc`, `StackMapWriter::prev_frame` and `vm.c`'s decoder/update.
The setivar miss still carries the current bytecode snapshot and compiled outer ISEQ for recompilation.
The new `may_write_block_code` field neither replaces nor aliases the profile's class reference. No new
dependency on method lookup or singleton invalidation is introduced by the profiled real class.

After the independent code audit, read live issue/PR metadata with `gh api`: Shopify/ruby#1122 remains open
with its shape-transition ask and no comments; #1126 is closed/unmerged, with the maintainer asking for
ruby/ruby submissions rather than rejecting the mechanism. Reread #19540's policy and #19858's read-side
change. An all-state query for this exact fork branch returns no Ruby PR; current open `setivar` and
`"real class"` searches show no replacement. These are scoped live checks, not an exhaustive unpublished-work
claim. No PR discussion, comment, branch or other external state was changed.

### Correctness/security rubric

Cold read: only `setinstancevariable` records the receiver's real class, retaining its original shape and
layout flags; every store still checks the actual receiver and uses the existing fallback if ineligible.

* **Class ownership.** `profile.rs:89,245-252,392-395` invokes native `rb_obj_class`, not a Ruby `class` method.
  It does not allocate a singleton class or invoke application code; subclasses remain subclasses.
  `prepare_optimized_setivar` reads the class only to create a missing-ivar shape transition. The ordinary
  T_OBJECT path matches `shape.c:808-826,896-928`'s owner. The class/module-owned fields-imemo exception is
  outside this fast path. Profiles remain instruction/snapshot-local in `ProfileOracle`, not a new exact-class
  fact for unrelated sends.
* **Layout and frozen checks.** Immediate writes retain the raising generic path. Accepted stores require
  RObject layout or Extended layout with the T_OBJECT flag; Class/Module, String and other layouts fall back.
  Frozen/complex shapes, Extended missing-ivar transitions, complex new shapes and capacity growth are still
  refused. No checks were relaxed merely because the class is now real.
* **Actual-receiver guards.** Heap and exact-shape checks precede the store, including after callbacks or
  fiber suspension. Shape includes frozen, layout and capacity bits. The class is not needed for method
  dispatch at this instruction; adding a singleton/class guard would defeat the intended sharing without
  protecting an additional store invariant. Each retained guard protects an immediate/layout, frozen,
  storage-index or capacity property, not an arbitrary user-method restriction.
* **Writes and GC.** `emit_optimized_setivar` still writes the proper embedded/fields storage, emits the
  normal value write barrier and updates the shape when required. The profile's ISEQ-to-class write barrier
  remains at `profile.rs:192`; `each_object`/`each_object_mut` and `gc.rs:114-151` mark the real class movable
  and relocate it. No receiver/singleton class is newly retained by this profile. No new raw ownership or
  untracked GC field is added.
* **Exits and policy.** Missing profiles still recompile in speculative versions. On final versions,
  `dispatch_ivar` uses shape branches with the generic store on mismatch; a missing eligible profile uses
  the generic path. The generic call retains exception/frame materialization and Ractor checks. The change
  does not disable TracePoint, method-resolution, Ractor or ZJIT feature gates.

No introduced correctness or security defect found. The exactness probe covers singleton overrides,
subclasses/non-T_OBJECT values, native-call boundaries, mid-RHS mutation, fibers, frozen errors and GC.
No implicit conversion, accumulator adoption, require ordering or config assumption is added here.

### Maintainability rubric

**L0, approve.** The two small helpers live in the canonical profiler and mirror `profile_self_shape` and
`shape_only`; the existing observation, distribution and barrier code is reused. A mode parameter on
`profile_self`, a second profile type or special branches in HIR/codegen would add concepts rather than remove
them. No scattered feature checks, wrapper layer, new optionality, cast-heavy boundary or cross-module API.
`profile.rs` grows 597 to 614 lines; the existing HIR snapshot file grows 30,008 to 30,090, crossing no new
1,000-line boundary. Splitting that existing suite is unrelated to this fix. The sole added comment is one
why-line explaining the non-obvious transition-owner choice on a private Rust helper; no redundant test
comments or public Ruby documentation are added. Ruby flog/RuboCop metrics do not apply to this Rust diff.
The prior cold-profiling/deep-extend losing case remains relevant: the extra native class walk is profiling
work, not a per-specialized-store operation; its implementation and sampling policy have not changed.

### Body and commit message, sentence by sentence

Read the complete current item body against the exact source and [results-3.md](results-3.md). Read the complete
commit message, not just its title. The body is unchanged by this pass.

| Sentence or claim | Current-head check | Verdict |
| --- | --- | --- |
| Title: profile the real class for setinstancevariable | Only that opcode switches to `profile_self_real_class`. | Accurate. |
| Body sentence 1: ordinary singleton receivers are recorded as “other”, so an extended object's write lacks a profile (#19540) | Parent's `profile_self` and unchanged singleton filter; live #19540 explains retention. The ordinary-object qualification excludes its exemptions. | Accurate problem statement. |
| Body sentence 2: recompile exit, then generic write after versions are exhausted | Empty-profile branch of `dispatch_ivar`, compile/version policy and `exit_recompile`. | Accurate for the affected path. |
| Body sentence 3: class is used only for transitions; interpreter uses real class | `prepare_optimized_setivar`'s sole class read and `obj_get_owner_class` on accepted T_OBJECTs. | Accurate. |
| Body sentence 4: profile that class; same shape guard, subject to layout/frozen/capacity checks | New helper plus unchanged preparation, dispatch and emit paths; both HIR snapshots and runtime probes. | Accurate, no all-layout support promise. |
| Body sentence 5: #19858 did the read-side counterpart with shape-only profiling | Merged #19858 metadata and current `profile_self_shape`. It did not already fix writes. | Accurate. |
| Fixes Shopify/ruby#1122 | Live issue asks for precisely this real-class profile for shape transitions. | Correct cross-repository reference. |
| Lobsters heading and the two numeric rows | Parsed raw stats-3 integer totals and denominators; replayed diffs below. | Exact counter claims, not speed claims. |
| Message sentence 1: “other” avoids retaining singleton class | Parent filter and live #19540. | Accurate. |
| Message sentence 2: extended write had no profile, side-exited, then final generic write | Same empty-profile/version path as body sentence 2. | Accurate. |
| Message sentence 3: only transition consumer, real interpreter owner | Same source anchors as body sentence 3. | Accurate. |
| Message sentence 4: profile real class; preserve shape/layout/frozen/capacity boundaries | Exact diff and unchanged store guards. | Accurate. |
| Message Fixes URL | Resolves to the live issue above; the message is identical to the approved prior one. | Accepted. |

All nine `stats-3/*.json.gz` archives pass `gzip -t`. Parsed pins identify base `3b188d0dd5` (both independent
builds), head `ca3ea90482`, and 10 measured iterations. Replayed `zne1/stats_diff.rb` with `--pct 1`, with and
without the A/A arguments as in the earlier confirm: all six retained diff files match byte-for-byte.
Independently divided the raw totals: lobsters `dynamic_setivar_count` is 11,405 / 11,405 / 10,821;
`setivar_fallback_no_side_exits` 5,956 / 5,956 / 5,372; `ccall_rb_vm_setinstancevariable`
11,345 / 11,345 / 10,761 (base / A-A / head). All three fall exactly 584, A/A zero. Railsbench's write counters
are unchanged. Shipit's total remains 48,920 while its reasons move 41,029 → 40,948 and 7,891 → 7,972,
not A/A noise. The body correctly makes neither an exclusivity claim nor an unchanged-other-counters claim.
The historical comment draft still references the old head and is not a newly prepared post; no comment is
authorized or posted here. No runtime/instruction-speed claim is certified and no application benchmark was
rerun by this reviewer.

### Fresh exact-head execution and mutation

Linux x86-64, GCC 14.2.0, Rust 1.100.0, bootstrap Ruby 4.0.9, cargo-nextest 0.9.152 (release archive SHA-256
verified). Out-of-tree build in `.amp/in/orb-backup/zsv1-confirm/build`:
`./autogen.sh`, then `../ruby/configure --enable-zjit=dev --disable-install-doc --without-jemalloc; make -j6`.
The generated config says `ZJIT_SUPPORT=dev` and enables `disasm,runtime_checks`; executable version pins
`ca3ea90482`. All results below are from this review, not copied from the builder.

* `make zjit-test ZJIT_TESTS=-j1`: **2,036 run, 2,036 passed, 15 skipped**. Both added HIR tests and
  `test_profile_frames_during_direct_jit_to_jit_entry` pass on the first run; no retry-to-green.
* `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'`, then threshold 2:
  **PASS all 2,148 tests each**. Both retain “Fiber count: 10000 (skipping)”.
* `make test-all TESTOPTS=-j2 RUN_OPTS='--zjit --zjit-call-threshold=1'`
  `TESTS='ruby/test_zjit_cli ruby/test_optimization ruby/test_shapes ruby/test_object ruby/test_variable'`,
  then threshold 2: **327 tests, 15,429 assertions, zero failures/errors/skips each**. These are current-base
  counts, not the old base's 323 / 15,405.
* Retained `probe.rb`, SHA-256 `1a19a60172b2a704c7823e9a503a8e6968951924a9ca9007f76967fc9b14a521`:
  interpreter plus ZJIT thresholds 1 and 2, each also with `--zjit-max-versions=1`; all **33 rows identical**,
  all exit 0. Inspected actual outputs, including FrozenError and the non-owner Ractor IsolationError;
  these are not identical swallowed setup errors. For uninstalled full Ruby, `RUBYLIB` contains build root,
  `.ext/common`, `.ext/x86_64-linux` and source `lib`.
* Supplemental scratch `boundaries.rb` explicitly asserts return values, stored values and untouched neighboring
  ivars when a callback grows/freezes the receiver **inside** the writer's RHS, and when a fiber suspends there.
  Frozen cases assert that no store occurred. Anonymous-class writers collect 29 calls before compaction at
  threshold 30, then compile/use both existing and transitioning stores with young heap values and minor GC.
  Interpreter and six ZJIT modes (thresholds 1/2/30, each default/max-versions=1) all pass and match. A separate
  `--zjit-dump-hir`/`--zjit-log-compiled-iseqs` execution confirms the writers compile, with shape checks and
  `StoreField` **after** `InvokeProc`/`Fiber.yield`, so the default-threshold check is not generic-only evidence.
  This exercises compaction but does not establish that a particular class moved in every process.
* **One mutation:** changed only `ProfiledType::real_class`'s assignment from native `rb_obj_class(obj)` to
  `obj.class_of()`, deliberately restoring singleton profiling. Ran
  `make zjit-test "ZJIT_TESTS=-j1 -E 'test(test_setivar_singleton_receiver)'"`:
  **2 run, 0 passed, 2 failed, 2,049 skipped**, make exit 2. Both failures replace the expected shape guard/store
  with `SideExit NoProfileSetIvar recompile`; this is a regression assertion failure, not a compiler failure.
  Restored the exact assignment and reran the identical command: **2 passed, 2,049 skipped**, exit 0.
  `git diff --exit-code HEAD` and `git status --short` in the Ruby checkout are clean. No snapshots were accepted.

Logs are `/tmp/zsv1-confirm-{configure,build,zjit-test,btest-1,btest-2,test-all-1,test-all-2,mutation,restored}.log`,
also retained with the probe outputs, supplemental script and HIR under `.amp/in/orb-backup/zsv1-confirm/`.
No sanitizer, AArch64, alternate-GC, independent base build or new speed measurement is claimed in this pass.
Only Lowrail's item/review record is changed; no Ruby branch push, PR opening or upstream post.

## Astra full review of revision 3 (2026-11-25)

**Approve; no must-fixes or maintainability findings.** Reviewed the whole change at
[`ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5`](https://github.com/thomasklemm/ruby/commit/ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5),
not a delta from a Sol pass. Reviewer: `astra`, thread
[`T-01a2129c-f593-70d9-98f1-4854b086903d`](https://ampcode.com/threads/T-01a2129c-f593-70d9-98f1-4854b086903d).
Applied both Thermos rubrics directly; no delegation or other threads. The fetched fork branch is
`thomasklemm/zjit-setivar-real-class-3`, with direct parent `3b188d0dd5b23bbf94831a890ca907b92420c22d`.
One commit, two files, +100/-1; Thomas is author and committer, with no trailers. Read its entire message,
the item's body and For Thomas, both results records, retained probe, stats harness/diff and raw `stats-3/`.
No Ruby branch was pushed, no PR opened, and nothing posted upstream.

### Receiver, guard and GC audit

* `profile.rs:89,244-253,392-396`: only `setinstancevariable` uses the new constructor. It preserves the
  **actual receiver's** shape and flags from `ProfiledType::new`, replacing only the class with native
  `rb_obj_class`. This does not dispatch the Ruby `class` method. `object.c:258-291` walks singleton/ICLASS
  superclasses through the prime classext; all Box paths end at the same real class. Singleton methods,
  singleton-class ivars, extension/prepend chains and method lookup are not substituted with class methods.
* The transition-owner claim is exact for the supported ordinary-object path, **not a universal claim about
  class/module ivar storage**. `shape.c:808-826,896-925` uses `rb_obj_class(obj)` for an ordinary object;
  class/module-owned field imemos instead use their owner's singleton class. Those class/module layouts do
  not get a `SetIvarSpec`, so recording `Class`/`Module` cannot build their transitions from the wrong owner.
  Boxable classes use `Other` layout; ordinary classes/modules use `RClass`. Both take the existing generic
  operation, preserving Box storage and Ractor ownership checks.
* `hir.rs:6517-6577`: immediates are rejected before any shape access. An accepted spec has RObject layout,
  or Extended layout with a sampled T_OBJECT flag; frozen and complex shapes are refused. Existing fields
  need no class. A missing field uses the real class for the transition; a complex result, changed capacity
  or missing field on an Extended RObject is refused. Shape edges describe the same field layout across
  classes; the class argument controls variation/max-field accounting, not a different offset scheme.
  No speculative transition is performed against a singleton's own ivars or methods.
* `hir.rs:6399-6409,6580-6624,8750-8819,8865-8904,11084-11136`: the store checks the full shape on the
  actual receiver after RHS evaluation. `shape.h` includes capacity, layout, frozen/shareable, complex and
  object-ID bits in that shape. Heap checks protect shape loads; exact shape guards protect offsets and
  frozen/capacity assumptions. A later freeze, growth, deletion or fiber suspension cannot reuse only an
  entry-time check. The ordinary write barrier applies to the actual ivar storage, including field imemos.
* A subtle boundary was checked rather than assuming shape IDs uniquely identify builtin types:
  **an Extended T_OBJECT and a T_STRUCT can have identical full shapes**. They can then share the existing
  field store even though T_STRUCT samples alone are not selected for specialization. This is safe: both
  keep `fields_obj` at the same offset after `RBasic`, and missing-field transitions on Extended objects are
  refused. `shape.c:1217-1235`, `internal/struct.h:28-43`, `shape.h` and the RObject/RTypedData definitions
  agree. The shared-layout probe asserts full shape equality, performs 100 compiled Struct writes after
  ordinary-object warmup with **0 generic writes**, preserves its Struct payload and still raises on freeze.
  At thresholds 2/30 it records 1,206/968 JIT instructions. String/Array/Hash generic-table layouts do not
  shape-match this path.
* `ProfileOracle` binds profiles to the specific instruction snapshot (`hir.rs:9357-9400,9722-9727`);
  the real class of a write is not reused as a method-dispatch class at later sends. After a store the
  receiver is refined only to a heap object. Existing send/inlining/TracePoint guards remain unchanged.
* GC: `observe_profiled_type` still barriers the **recorded class** against its ISEQ before insertion.
  `IseqProfile::each_object[_mut]` visits it in the distribution's arrays; `gc.rs:115-153` marks it movable
  and updates it through `rb_gc_location`. There is no new unmarked pointer, hash key, cached raw class or
  Ruby allocation/callback inside `rb_obj_class`. The real class does not retain the ordinary receiver's
  singleton class. Executed minor collections, anonymous-class profile compaction and reference verification.
  The isolated retention probe leaves **0/100** singleton-bearing ordinary objects alive; each tested
  compaction reports **448 moved T_CLASS objects**.

### Fresh execution, mutation and final-version coverage

Linux x86-64, GCC 14.2.0, Rust 1.100.0, bootstrap Ruby 4.0.9, checksum-verified cargo-nextest 0.9.152.
Built from the exact head with `./autogen.sh`,
`./configure --enable-zjit=dev --disable-install-doc --without-jemalloc`, and `make -j2`.

| Check | Result |
| --- | --- |
| `make zjit-test ZJIT_TESTS=-j2` | **2,036 passed, 15 skipped**; includes both added HIR tests and the formerly flaky SIGPROF test, with no retry. |
| `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` | **PASS all 2,148 tests** (114.21 s); existing “Fiber count: 10000 (skipping)” line. |
| Same btest at threshold 2 | **PASS all 2,148 tests** (109.42 s); same skip notice. |
| Retained `probe.rb` | **33 identical rows**: interpreter vs thresholds 1, 2, 30, each with default versions and max-versions=1. Full Ruby interpreter also matches miniruby. |
| New `astra-probes/adversarial.rb` | **21 asserted rows**, or **23 with RUBY_BOX=1**. Each interpreter control matches thresholds 1, 2, 30, with default versions and max-versions=1, plus threshold 100 / num-profiles=90. Full Ruby interpreter and threshold 2 also match. |
| New `exhaust.rb` | After explicit global shape exhaustion, 100 extended objects become complex and retain the correct sum 4,950; interpreter and thresholds 1, 2, 30 match. |
| New `retention.rb` | Interpreter and thresholds 1, 2, 30, 100 (num-profiles=90) all report 0/100 live weak references; compaction verifies moved references. |
| Routing mutation | Change only `setinstancevariable` back to `profile_self`: **both added HIR tests fail**, 0 passed / 2 failed / 2,049 filtered, with `SideExit NoProfileSetIvar recompile` replacing the optimized store. |
| Restore | Restore that line, rebuild miniruby/full Ruby: **both tests pass**, 2 passed / 2,049 filtered. Ruby tracked diff is empty again. No snapshot was accepted. |

The new asserted rows cover singleton-owned metadata and overridden methods (including a raising `class`),
unrelated real classes sharing shapes, BasicObject, class/module/eigenclass receivers, generic and typed
layouts, immediate/immutable receivers, 0/2/3/8/30/126/200 initial ivars, actual shape-variation exhaustion,
deletions/object IDs, old receivers with young heap values, anonymous classes, RHS mutation and suspension,
and independent Box-local classes and builtin-class ivars. Unlike the retained probe's catch-all row helper,
unexpected exceptions fail these probes; their expected values are explicit. Ordinary and Box-enabled
adversarial outputs also match the old-routing mutant at threshold 2.

**`--zjit-max-versions=1` does not by itself test `no_side_exits`.** `CompilePolicy::new` requires a previously
invalidated version as well as reaching the limit. The dedicated `final-version.rb` uses max-versions=2,
threshold=2 and inline-threshold=0. Inspected its HIR: first a recompile shape guard, then shape branches
with optimized stores and a `SetIvar` fallback. After warmup it asserts **0 generic stores for 100 matching
writes**, then changes the receiver's shape and asserts **100 generic stores and 100 no-side-exits fallbacks
for 100 unmatched writes**. Freezing preserves the old value and raises FrozenError. Semantic output matches
the interpreter. This is stronger evidence for this boundary than treating the earlier max-versions=1 runs
as final-version coverage; it is not a new code finding.

`mechanism.rb`, with 1,000 warmup calls and inlining disabled, checks a 100,000-write window: the old-routing
mutant executes **100,000 generic writes / 100,000 no-side-exits fallbacks**; exact head executes **0 / 0**.
Both execute 1,000,011 JIT instructions, with zero compiled ISEQs, no-profile-setivar exits and OOM errors in
that window, and the same final value 99,999. An initial 100-call warmup was insufficient for the control to
reach its final version: it exited once and interpreted the measured loop. That preliminary zero was not
counted as optimization evidence. No timing/JIT-flat claim is inferred.

An initial GC probe also handed singleton **classes** to generic sends/WeakRef construction and found 16/200
live weak references. The old-routing mutant reproduces exactly 16/200: profiling class/module receivers is
an existing exception and can retain those classes and attached objects. The isolated retained probe tests
ordinary-object profiling without introducing that other retaining path; it passes on both implementations.
The rejected probe and both failure outputs remain in scratch, not hidden as a passing check.

### Maintainability and cold-profile cost

No structural regression: the production diff is 18 additions / 1 deletion in the canonical profiler,
`profile.rs` grows 597 → 614 lines, and the two HIR snapshots add 82 lines to an already-large test module.
No new file crosses 1,000 lines. The helpers mirror `profile_self_shape`/`shape_only`, reuse the existing
distribution/barrier machinery, and avoid changing HIR, codegen or generic dispatch. Generalizing those
small profiling entry points with a mode/closure would add concepts without reducing meaningful complexity.
The sole added why-comment identifies the interpreter's transition owner; the tests add no redundant comments.

The losing input is many cold write methods on a receiver with a deep extension chain: `rb_obj_class` must
walk it during sampling. Ran `cold.rb` (100 distinct writers, 29 calls each, below the default compile threshold),
with fixed initial heap 33,554,432 bytes and Callgrind 3.24.0 `--smc-check=all-non-file`:

| Extension depth | Old-routing mutant Ir | Exact-head Ir |
| --- | ---: | ---: |
| 0 | 112,252,669 | 112,314,839 |
| 1 | 113,468,014 | 113,713,348 |
| 1,000 | 170,889,615 | 177,679,180 |

All six runs check the written value and exit 0. These are **whole-process diagnostic counts**, with setup
and profiling, no A/A/heap-control cohort or JIT-flat certification. The control is a one-line routing mutant,
not a separately built pristine base. This records the expected cold cost; it is not a speed claim. The walk
does not occur in the warmed store and is limited to sampling windows (five samples by default).

### Body and evidence audit

Every public sentence and the commit message are supported:

| Claim | Independent check |
| --- | --- |
| Ordinary singleton-bearing receivers become “other” under the old profiler | Read `observe_profiled_type` and live ruby/ruby PR 19540 with `gh api`; its top-level/Class/Module exemptions do not change the affected ordinary-object case. |
| Missing profile leads to recompilation, then generic final-version writes | Traced `dispatch_ivar`, `CompilePolicy`, `exit_recompile`; killed the routing mutant with both HIR tests and measured its generic final-version loop. |
| The class is used only for shape transitions; interpreter uses the real class | Re-read the complete SetIvar profile consumers and `obj_get_owner_class`; class/module-owned imemos are excluded as explained above. |
| Existing shape/layout/frozen/capacity checks remain | Exact diff plus guard trace and executed boundary probes above. |
| PR 19858 is the read-side shape-only counterpart | Read live PR 19858 and current `profile_self_shape`; it changes reads, not writes. |
| Fixes the requested profiling issue | Live Shopify issue 1122 is open and asks for the real class for the transition tree; implemented routing matches that request. |
| Lobsters -584 generic writes per iteration | Independently parsed all nine `stats-3/*.json.gz`, checked Ruby pins and denominators of 10, and replayed all six retained diffs byte-for-byte. |

Lobsters master / A-A / head per iteration: `dynamic_setivar_count` **11,405 / 11,405 / 10,821**;
`setivar_fallback_no_side_exits` **5,956 / 5,956 / 5,372**; `ccall_rb_vm_setinstancevariable`
**11,345 / 11,345 / 10,761**. All three deltas are exactly -584, no rounding and zero A/A movement.
Railsbench totals remain 4,060. Shipit totals remain 48,920 with the already-recorded -81/+81 fallback
redistribution. The public body correctly makes neither an other-app exclusivity claim nor a speed claim.
The For Thomas explanation that the actual receiver's shape remains guarded is sound; its approval status
is updated to include this pass without treating it as the separate Sol approval.

### Replay and limits

New scripts are retained in [`astra-probes/`](astra-probes/), so they do not depend on a reviewer orb surviving.
From the built Ruby directory, with `PROBES` set to that absolute directory and `RUBYLIB` including the build
directory, `lib`, `.ext/common` and `.ext/x86_64-linux` for full Ruby:

```sh
./miniruby "$PROBES/adversarial.rb"
./miniruby --zjit --zjit-call-threshold=2 "$PROBES/adversarial.rb"
# Also thresholds 1/30, each with --zjit-max-versions=1; repeat with RUBY_BOX=1.
./miniruby --zjit --zjit-call-threshold=100 --zjit-num-profiles=90 "$PROBES/adversarial.rb"
./miniruby --zjit --zjit-call-threshold=2 --zjit-max-versions=2 \
  --zjit-inline-threshold=0 --zjit-stats-quiet "$PROBES/final-version.rb"
./miniruby --zjit --zjit-call-threshold=2 --zjit-inline-threshold=0 \
  --zjit-stats-quiet "$PROBES/shared-layout.rb"
./miniruby --zjit --zjit-call-threshold=2 "$PROBES/exhaust.rb"
./ruby --zjit --zjit-call-threshold=100 --zjit-num-profiles=90 "$PROBES/retention.rb"
./miniruby --zjit --zjit-inline-threshold=0 --zjit-stats-quiet "$PROBES/mechanism.rb"
RUBY_GC_HEAP_INIT_BYTES=33554432 valgrind --tool=callgrind --smc-check=all-non-file \
  --callgrind-out-file="$WORK/cold-1000.cg" ./miniruby --zjit "$PROBES/cold.rb" 1000
make zjit-test "ZJIT_TESTS=-j2 -E 'test(test_setivar_singleton_receiver)'"
```

Build/test logs, interpreter/JIT output pairs, mutation failures, HIR and raw Callgrind dumps are retained in
`.amp/in/orb-backup/zsv1-astra/` in this thread. The application workloads/release builds were **not rerun**;
the application claim is a replay/audit of the committed raw evidence, not an independent benchmark cohort.
No pristine-base full suite, AArch64, sanitizer or alternate-GC run is claimed. The seven retained scripts
are review probes, not new production code or a mandatory test matrix. No guard weakening or Ruby code edit
is requested by this review.
