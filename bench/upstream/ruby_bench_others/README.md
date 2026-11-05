# Others' open PRs on ruby/ruby-bench (2026-11-05)

Triage of every open ruby/ruby-bench PR not by us, with verified diagnoses and drafted notes. **Nothing here is
posted**: comments on others' PRs need Thomas's OK ([DECISIONS](../../../docs/DECISIONS.md#no-comments-on-others-prs-without-thomass-approval-thomas-2026-11-04)).
Overview and context: [docs/upstream/ruby-bench.md](../../../docs/upstream/ruby-bench.md).

**Pins.** ruby-bench main `00f0f8b`. Ruby 4.0.9 three ways: mise build without ZJIT, and
`~/rubies/4.0.9-zjit` (tarball, `--enable-yjit --enable-zjit optflags=-O3`); Ruby master `aed61e36b3`
(2026-11-05, same flags). 4-vCPU orb.

**Fork CI state.** The three fork runs (42079217004, 42081299470, control 42079221738) were still queued, with no
job started, when this was committed (2026-11-05 18:35 UTC). Both notes say "CI passes on my fork"; that sentence
stays unverified, and the notes unpostable, until those runs are green.

## Triage

| PR | author | what it does | state, CI cause | overlap with our work | our possible help | recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| [#562](https://github.com/ruby/ruby-bench/pull/562) | XrXr | `misc/zjit_diff.rb` also compares iteration times minus GC time (harness-gc runs); WIP commit records ZJIT side exits per iteration in `harness/gc.rb` | draft, mergeable; CI red since its WIP commit 211380e5f3 (run 40052237877): `RubyVM::ZJIT.stats` is nil or missing | same goal as the determinism round and G2's GC-measurement work | verified 4-line fix, [note](pr562-note.md) | **help with draft** (Thomas decides) |
| [#539](https://github.com/ruby/ruby-bench/pull/539) | luke-gruber | adds `gc_balloon` (major GC over old garbage, heap shrink) | approved (eightbitraptor), mergeable but red: `GC.start(global:)` is 4.1-only; on today's main also the old harness names | none | verified 3-line fix, [note](pr539-note.md) | **help with draft** (Thomas decides) |
| [#461](https://github.com/ruby/ruby-bench/pull/461) | nobu | follow-up to #455: fork/git-pin stackprof, concurrent-ruby, yajl-ruby for ruby/ruby#15447 (removed deprecated C APIs) | draft, conflicts with main in all 7 lockfiles; review comments by eregon (use concurrent-ruby 1.3.6) and byroot (unused gem) | same lockfiles as #566/#567/#568 | none needed: mostly done on main already (below) | **no action** |
| [#533](https://github.com/ruby/ruby-bench/pull/533) | rwstauner | env var for a custom prefix command (his isolcpus/nice/SMT script) | open, mergeable, no review | none; would allow a `valgrind` prefix | – | **no action** |
| [#354](https://github.com/ruby/ruby-bench/pull/354) | rwstauner | cpusets, `nice`, SMT sibling off, parent moved off the CPU | conflicts (`run_benchmarks.rb`); author points to #533 as the simpler alternative | none | – | **no action** |
| [#541](https://github.com/ruby/ruby-bench/pull/541) | eightbitraptor | "GC per ruby" table for 3+ rubies | conflicts in `README.md` only | GC reporting (G2 must complement it) | – | **no action** (maintainer's own PR; trivial conflict for him) |
| [#467](https://github.com/ruby/ruby-bench/pull/467) | luke-gruber | `--category thread` and a mixed IO/CPU threads benchmark | conflicts in `test/run_benchmarks_integration_test.rb`; author asks whether it should be a real or pseudo-category, unanswered since 2026-01 | none | the open question is a maintainer design call | **no action** |

## #562: zjit_diff, GC time removed

**Cause.** Only the second commit (211380e5f3, "[WIP] GC harness per iteration ZJIT side_exit_count") breaks CI;
the PR's earlier head 67d77a3f8c (run 40040877615) was green. `harness/gc.rb:86` runs
`RubyVM::ZJIT.stats(:side_exit_count) - last` every iteration, which fails three ways in run 40052237877:

* Linux 4.0.9 and head without `--zjit`: `rb_zjit_stats` returns nil when ZJIT is off → `NoMethodError: undefined method '-' for nil`.
* Windows 4.0.7 and head (built without ZJIT): `NameError: uninitialized constant RubyVM::ZJIT`.
* TruffleRuby: `uninitialized constant RubyVM`.

It is not only gcbench: string_malloc_pressure, the other `default_harness: gc` benchmark, fails the same way,
interpreted and with YJIT. Two further problems:

* On 4.0.9 `side_exit_count` is nil even with `--zjit`: 4.0's `rb_zjit_stats` returns before the exit counters
  unless `--zjit-stats` is on (`zjit/src/stats.rs`, "End of default stats"). On master it is a default counter.
* The delta subtracts the previous *delta*, not the previous total. 4.0.9 `--zjit-stats-quiet` on gcbench, before:
  warmup [95, 1], bench [96, 2, 98]; after the fix: [0, 1], [1, 1, 2] (the 95 exits happen before `run_benchmark`).

**Fix** ([diff](pr562-fix.diff)): read the baseline once if `defined?(RubyVM::ZJIT.enabled?) && RubyVM::ZJIT.enabled?`
(the guard `lib/harness.rb:221` uses), keep the last total, and emit the two `side_exit_count_*` keys only when
there are samples. Branch [`thomasklemm/zjit-diff-gc-side-exits`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/zjit-diff-gc-side-exits)
@ `4a9514d424` (XrXr's two commits on main `00f0f8b` + one commit). Not opened as a PR: it is a fix to his WIP commit.

**Verified** ([`pr562_matrix.sh`](pr562_matrix.sh), gcbench, `WARMUP_ITRS=2 MIN_BENCH_ITRS=3`):

| Ruby | before | after |
| --- | --- | --- |
| 4.0.9 without ZJIT, interpreter / `--yjit` | NameError / NameError | ok / ok |
| 4.0.9 with ZJIT, interpreter / `--yjit` / `--zjit` | NoMethodError ×3 | ok, no side-exit keys |
| 4.0.9 `--zjit-stats-quiet` | runs, wrong deltas | correct deltas |
| master interpreter / `--yjit` | NoMethodError ×2 | ok |
| master `--zjit` | runs ([5, 0], [5, 0, 5]) | [0, 0], [0, 0, 0] |

Fork CI: run [42079217004](https://github.com/thomasklemm/ruby-bench/actions/runs/42079217004) on
`ci/zjit-diff-gc-side-exits` (the same three commits on `ci-base/shipit-nokogiri`, i.e. with #566, because main's
Windows head job is red on shipit's nokogiri; fork PR #10, closed without a comment).

**Review.** A skeptical subagent reran the 11-combination matrix in clean worktrees and confirmed every claim
and that the fix never crashes, also on 4.0 `--zjit` without stats, where the baseline is nil and no keys are
written; `misc/zjit_diff.rb` never reads the `side_exit_count_*` keys, so its output is unchanged. Applied: the
first draft's "instead of 0, 1, 1, 1, 2" mixed two changes (the subtraction fix gives 95, 1, 1, 1, 2; reading the
counter before the loop removes the 95 boot exits); "Rubies built without ZJIT (the Windows jobs here)" instead
of "Windows builds"; the note names its CI base (current main plus #566, not the PR's older base `1bcb7ad`).

**GC-time accounting** (sent to G2, [thread](https://ampcode.com/threads/T-01a1acd4-0301-77ae-9f72-c4d0a5730fe1),
which owns GC measurement now). Checked in `gc/default/default.c` on 4.0.9 and master:

* zjit_diff subtracts `gc_marking_time_bench + gc_sweeping_time_bench`, deltas of `GC.stat(:marking_time)` and
  `(:sweeping_time)`, each truncated to whole ms. `GC.stat(:time)` is `ns_to_ms(mark_ns + sweep_ns)`, so the two
  fields don't sum to it exactly. Per iteration, (marking + sweeping ms) − `GC.total_time` delta: gcbench 4.0.9
  −1.26 to +1.53 ms against 151–238 ms of GC (11.5% of the iteration); master −0.85 to +1.13 ms against 76–115 ms
  (7.2%). The harness already stores `gc_total_time_bench` (ns resolution, same mark + sweep), which would remove
  the "whole milliseconds" caveat in zjit_diff.
* The clock is CPU time: 4.0 `CLOCK_PROCESS_CPUTIME_ID` (whole process), master `CLOCK_THREAD_CPUTIME_ID` (the
  collecting thread; its source comment cites 131 ms reported for 3 ms of GC with eight busy ractors). Same for
  single-ractor pinned runs; on 4.0 ractor runs over-count. Time the GC thread is descheduled is not subtracted.
* Covered on both: major and minor marking, every incremental marking step and `gc_rest`, every lazy sweep step,
  and compaction (inside `gc_sweeping_enter`/`exit`). Each step is charged to the iteration it runs in, so
  garbage made in iteration N and swept lazily in N+1 is removed from N+1, which is what #562 intends.
* Not covered: GC entry/exit and the VM barrier, heap growth and page allocation in the allocation slow path,
  finalizers. No per-major/per-minor time split, only counts.
* Master: `GC.stat` is the current Ractor's objspace; a global GC is charged to the Ractor that started it.

No A/A of GC time was measured here (orb wall time too noisy: gcbench 1,379–1,862 ms per iteration); that is G2's.

## #539: gc_balloon

**Cause.** `GC.start(global: false)` raises `unknown keyword: :global` on 4.0.7 and TruffleRuby 40.0.0 (run
37012289451); the keyword exists only on 4.1 (`GC.method(:start).parameters` on master includes `[:key, :global]`,
on 4.0.9 it doesn't). Second, not yet visible in its CI: main renamed the harnesses on 2026-10-20 (a1c61f6
`harness-gc/harness.rb` → `harness/gc.rb`, bcee592 `harness/loader` → `lib/harness/loader`), so the PR's
`default_harness: harness-gc` and `require_relative '../harness/loader'` fail on today's main on every Ruby
(`cannot load such file -- .../harness/harness-gc`). GitHub shows it mergeable because the files don't conflict.

**Options.** benchmarks.yml has no Ruby-version or engine key (its keys: `desc`, `category`, `single_file`,
`default_harness`, `ractor`, `ractor_only`, `ractor_scenario`, `no_pinning`), and a CI `--excludes` would hide it
everywhere but head. The convention on main is a feature check: ractor-conservative-stack sets
`GC_START_KWARGS[:global] = false if GC.method(:start).parameters.include?([:key, :global])`. Before 4.1 there is
one object space, so a plain `GC.start` is the same local major GC.

**Fix** ([diff](pr539-fix.diff)): `LOCAL_MAJOR_ONLY = GC.method(:start).parameters.include?([:key, :global])`
(the check `harness/ractor.rb:39` makes), so the existing `GC.start` branch picks the plain call before 4.1, plus
the two renamed paths. Branch
[`thomasklemm/gc-balloon-current-main`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/gc-balloon-current-main)
@ `1348887947` (luke-gruber's commit on main `00f0f8b` + one commit). The first version (`aeba8b9631`) added a
`GC_START_KWARGS` Hash constant like ractor-conservative-stack's but without its `Ractor.make_shareable`; the
reviewer found that worker Ractors then raise `Ractor::IsolationError` under the ractor harness the benchmark is
written for (CI can't see it: gc_balloon has no `ractor: true`, so the ractor jobs never run it).

**Verified.** gc harness: 4.0.9 interpreter and YJIT, master interpreter, YJIT and ZJIT (41 / 40 / 50 GCs, 9 majors
in iteration 1). Ractor harness with `RUBY_BENCH_RACTORS=2`: 4.0.9 and master, and master with
`RUBY_BENCH_RACTOR_GC=1`. `./run_benchmarks.rb --no-sudo gc_balloon` on 4.0.9. Fork CI: fixed
[42081299470](https://github.com/thomasklemm/ruby-bench/actions/runs/42081299470) on `e32baa2aa0` (fork PR #9); the PR's commit
alone on main, as a control, [42079221738](https://github.com/thomasklemm/ruby-bench/actions/runs/42079221738)
(fork PR #11). Both on `ci-base/shipit-nokogiri`; PRs closed without comments.

**Review.** A skeptical subagent confirmed the errors, the keyword support per version, the renames and that
benchmarks.yml has no version gate (an `--excludes` would hide the failure). It found the Ractor blocker above and
the smaller `LOCAL_MAJOR_ONLY` form (applied), and asked for "only Ruby master accepts that keyword" (4.1 is
unreleased), for naming the LoadError, and for not implying YJIT and ZJIT ran on 4.0.9 (applied).

## #461: forked dependencies for removed C APIs

nobu's draft pins git sources so benchmarks build after ruby/ruby#15447 (Misc #21768, removed deprecated C APIs;
merged 2026-05-28). Since then main has absorbed most of it:

* stackprof: tmm1/stackprof#240 (postponed-job API) released in 0.2.28 (2026-02-13); main's railsbench and lobsters
  lock 0.2.28 (nobu's own a46e02b). #461 still pins a git revision of 0.2.27.
* yajl-ruby: brianmario/yajl-ruby#232 was closed unmerged; main's fluentd already uses the yajl-ruby git master
  (nobu's 15f1ca5, 2026-05-26), which has the typed-data commit.
* concurrent-ruby: ruby-concurrency/concurrent-ruby#1096 is released in 1.3.6; shipit locks 1.3.6, the other six
  benchmarks 1.3.5 (eregon's review comment asks for 1.3.6). The fix is in the C code of the separate
  `concurrent-ruby-ext` gem; the `concurrent-ruby` gem these lockfiles install has no C files (its `ext/` is Java
  for JRuby), and main's head job passes with 1.3.5 (run 42052401843,
  `benchmark-default (head)` on ruby 4.1.0dev `5888302d4f`).

**Overlap with ours.** #566/#567/#568 change none of these gems (no `concurrent-ruby`, `stackprof` or `yajl-ruby`
line in their diffs) apart from #568's `platforms: :mri` on lobsters' stackprof line, which #461 also edits.
`git merge-tree` against main and against each of our heads: #461 conflicts in the same 7 lockfiles either way,
plus `benchmarks/lobsters/Gemfile` after #568. So order doesn't matter for it, and our PRs neither supersede nor
newly break it. **No note**: the only useful thing to say would be that most of it already landed, which is
overlap commentary on a maintainer's draft (DECISIONS: collaborative, not credit-seeking).

## #354 and #533: CPU isolation

`--no-sudo` (k0kubun's request on #354) landed separately as #474 (2026-02-12). Still missing on main: `nice`,
cpusets, taking the SMT sibling offline and moving the parent off the benchmark CPU (#354), or a hook for a
machine-specific script that does it (#533). Main pins with `setarch -R` and `taskset -c` and disables turbo.
Not relevant to the determinism audit (round 4): it compares Callgrind instruction counts, which don't depend on
CPU placement, and lists ASLR, pinning and turbo as out of scope. It matters for wall-time comparisons on
bare-metal machines, which we don't run. No action.

## #541 and #467

#541 (eightbitraptor, a maintainer) conflicts only in `README.md`; resolving it is trivial for him, and G2's GC
reporting has to build on its per-ruby table rather than duplicate it. #467 waits on a maintainer decision about
categories. Neither has a question we can answer. No action.
