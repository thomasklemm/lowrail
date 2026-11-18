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
