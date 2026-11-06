# ruby-bench: what is worth contributing upstream (2026-11-03)

Overview of all our ruby-bench work: [ruby-bench.md](ruby-bench.md).

[ruby/ruby-bench](https://github.com/ruby/ruby-bench) gives the Ruby and ZJIT teams their headline numbers, and it
is our source of truth for ZJIT speed claims ([DECISIONS](../DECISIONS.md#evidence-and-measurement)). This page
checks the pain points recorded in our docs, looks for gaps in the suite, and ranks candidate improvements by their
value to the maintainers. It is an evaluation only. Nothing was built upstream, and nothing was opened or posted.
[Round 2](#round-2-five-topics-checked-and-the-prs-opened-2026-11-05) (2026-11-05, at the end) checks five more topics
and records the PRs that opened from them. [Round 3](#round-3-rails-benchmarks-on-windows-2026-11-05) prepares a PR that runs
erubi-rails, lobsters and railsbench in the Windows CI job. [Round 4](#round-4-analyze-for-the-other-database-benchmarks-2026-11-05)
finds that no other database benchmark needs #565's `ANALYZE`. [Round 4: determinism](#round-4-determinism-2026-11-05)
finds one benchmark whose work changes from run to run (lobsters, with the date) and prepares two alternative fixes.

**Pins.** Ruby master [`a8b095a07e`](https://github.com/ruby/ruby/commit/a8b095a07e55adf429839d4642027e832e30d3a7),
release build (`-O3 -ggdb3`, `--enable-zjit --enable-yjit`), the same build as [zjit-yjit-gap](zjit-yjit-gap.md).
ruby-bench [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2fc1a84702fea63e06f64d179751d69df4)
(2026-10-29, current `main`). One 8-vCPU orb, so wall times are noisy; counts are not. Upstream search: all 38
issues and 519 PRs in ruby/ruby-bench (titles, plus bodies and comments of every related one),
[rubybench/rubybench](https://github.com/rubybench/rubybench) (the daily runner behind the published numbers) and
the ruby-bench jobs in ruby/ruby's CI and `tool/zjit_diff.rb`.

## Recommendation

| rank | candidate | value to maintainers | size, risk | upstream state | contribute? |
|---|---|---|---|---|---|
| 1 | Significance stars come from one process per Ruby, so identical builds get `*`–`***` | high: `tool/zjit_diff.rb` in ruby/ruby shows these stars on ZJIT changes | issue first; a `--runs N` PR is M, low risk | not raised; p-values added in #479 | **yes: issue with an A/A repro, PR only if wanted** |
| 2 | lobsters and shipit keep `Rails.cache` in `tmp/cache` on disk (`:file_store`) | medium-low: removes a concurrent-run 500, cross-run state in iteration 1, ~2% filesystem time in lobsters | 2 lines, low risk; score moves ~2% | not raised | **yes: one small PR** |
| 3 | lobsters' 2023 fixture fell out of its time windows: 16 of 114 requests render empty lists | medium, but changes the workload | M, medium | not raised; nearest is #527 (rubys, ANALYZE) | no, not now |
| 4 | ZJIT stats cover boot + warmup + window; YJIT's are reset at `run_benchmark` (#352) | low: ratios are unchanged | S, but changes `compile_time` | YJIT side done in #352 | no |
| 5 | Built-in Callgrind/Ir mode | low for them: `HARNESS=perf PERF='stat -e instructions'` already counts instructions after warmup on hosts with a PMU | M | #533 (open, prefix command) would allow a `valgrind` prefix | no |
| 6 | Rails-main variant of the Rails benchmarks | low: tried in 2023 and dropped; releases are tracked within weeks | M–L, ongoing upkeep | #64, #242, #253, #278, #321, #456 | no |
| 7 | Writes, jobs, mailers in the Rails workloads | medium in principle | L, design-owned | lobsters' author skipped POSTs on purpose | no |
| 8 | ZJIT memory flags for app-sized runs | none for ruby-bench: 0 out-of-memory at defaults | S | – | no |
| – | lobsters planner statistics (`ANALYZE`) | high (~15% of lobsters wall time) | S | **taken**: #527, alanwu asked rubys for the PR | no (theirs) |

I would contribute **two things**: an issue about the significance stars (rank 1), and a two-line PR that moves
the lobsters and shipit caches to `:memory_store` (rank 2). Everything else either already exists, belongs to
someone else, helps only our orbs, or changes the workloads more than the evidence justifies.

**Decision (Thomas, 2026-11-03).** Rank 2 is prepared as a PR but not opened: fork branch
[`thomasklemm/memory-cache-store`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/memory-cache-store)
at `c4d362b000`, on ruby-bench `73918b2`. A Sol check comes before it opens. Rank 1 is not opened at all (DECISIONS:
small, well-reviewed PRs, no issue discussions we can't add much to); its evidence stays below. Ranks 3–8: nothing.
On the branch, three concurrent lobsters processes all exit 0, the cache event counts match the numbers below, and
the per-route response sizes and story counts of all 114 lobsters requests match the file-store run.

**Opened 2026-11-04** as [ruby/ruby-bench#564](https://github.com/ruby/ruby-bench/pull/564) (07:01 UTC; head
`a920bf4259` since 08:28 UTC, one commit); state in the [ledger](contributions.md#benchmarks--rubyruby-bench).

## 1. Significance stars treat iterations of one process as independent samples

**What happens.** `--pvalue` (and the stars that always print next to the ratio) run Welch's t-test over the measured
iterations of one process per executable
([`results_table_builder.rb:463`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/lib/results_table_builder.rb#L463),
[`misc/stats.rb:5`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/misc/stats.rb#L5)).
The iterations inside a process share that process's GC placement, heap layout, hash seed and compile decisions, so
the test only sees within-process noise. A difference between two processes of the same build reads as significant.

**A/A, measured.** Same binary, same flags, `./run_benchmarks.rb --no-sudo --interleave --pvalue -e 'zjitA::ruby
--zjit' -e 'zjitB::ruby --zjit'`, default iterations (15 warmup, 10 measured), four rounds:

| round | lobsters A / B (ms) | ratio | railsbench A / B (ms) | ratio | shipit A / B (ms) | ratio |
|---|---|---|---|---|---|---|
| 1 | 863.6 ± 4.3% / 807.2 ± 1.7% | 1.070 (**) | 1720.1 ± 2.9% / 1673.9 ± 1.3% | 1.028 (*) | 1352.2 ± 1.6% / 1358.1 ± 4.2% | 0.996 |
| 2 | 773.7 ± 2.5% / 837.2 ± 7.3% | 0.924 (*) | 1689.8 ± 1.7% / 1692.0 ± 1.9% | 0.999 | – | – |
| 3 | 826.6 ± 2.4% / 776.5 ± 3.2% | 1.065 (***) | 1685.4 ± 1.5% / 1668.5 ± 0.7% | 1.010 (p 0.086) | – | – |
| 4 | 775.3 ± 2.1% / 773.8 ± 2.2% | 1.002 | 1662.0 ± 2.2% / 1676.0 ± 2.2% | 0.992 | – | – |

Four of nine identical-build comparisons are marked significant at p < 0.05; about 0.45 would be expected. Over
the eight lobsters processes the per-process mean varies with a CV of 4.4% (range 11.6%), while each process reports
2–4% stddev over 10 iterations, a standard error near 1%.

**It is not only orb noise.** Our orbs are VMs, and maintainers will rightly say that tuned bare metal is quieter
(#354, #533, #549, #557). But identical processes also do different amounts of work. Callgrind counts, which no
machine noise touches, differ between runs of the same build by 0.10% (railsbench), 0.88% (lobsters) and 1.96%
(shipit) per iteration with GC included, from one extra minor or major GC in the window
([zjit-yjit-gap](zjit-yjit-gap.md#totals)). On a machine where one process's iterations vary by 1%, a 10-iteration
window has a standard error near 0.3%, so a 1–2% work difference between two processes gets stars even there.

**Who relies on it.** jhawthorn on #479: significance "is one of the most important numbers". ruby/ruby's
[`tool/zjit_diff.rb`](https://github.com/ruby/ruby/blob/a8b095a07e55adf429839d4642027e832e30d3a7/tool/zjit_diff.rb#L54-L67)
(ruby/ruby#16160) runs `--chruby 'before;after'` with one process each and shows these stars on ZJIT changes; the
example in #16160 marks railsbench `0.974 (*)`.

**Upstream state.** p-values came in #479 (eightbitraptor, merged 2026-02-18). No issue or PR mentions
per-process variance or repeated processes. #562 (XrXr, open) removes GC time from zjit_diff timings, which is a
related but different problem.

**Size and risk.** Two possible fixes, for the maintainers to choose: (a) a `--runs N` option that starts N
interleaved processes per executable and tests the per-process means (or a nested model), with stars only when
N ≥ 2; (b) at minimum a README note and a legend line saying that the stars reflect within-process noise only.
(a) is medium (runner loop, JSON shape for repeated blobs, table code, tests); the Ractor path already merges
several processes per benchmark (`RactorBreakdown.merge`), so there is a pattern to follow. Risk is low; it is
opt-in.

**Why an issue first.** The area has an active owner (eightbitraptor: #479, #481, #483, #541), and the design
choice (how many runs, which test) is theirs. An issue with the A/A table and the Callgrind cross-process numbers is
a bug report about a wrong statistical claim, not a data comment; it would offer the `--runs` PR. This is the one
place where the etiquette's "PR is the claim" rule points to an issue instead. Not opened: Thomas decided on
2026-11-03 to stay with small, well-reviewed PRs, so this stays here as evidence.

**2026-11-06:** prepared as a PR, not opened: [Round 5](#round-5-significance-across-processes-2026-11-06).

## 2. lobsters and shipit keep their Rails cache on disk in `tmp/cache`

**What happens.** lobsters sets `config.cache_store = :file_store, "#{config.root}/tmp/cache/"`
([`config/application.rb:48`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/benchmarks/lobsters/config/application.rb#L48)),
inherited from the 2023 import (bdb2718), not a choice made for the benchmark. shipit sets no store, so Rails uses
its default file store in `tmp/cache`. The layout reads the inbox count through `Rails.cache.fetch` on every logged-in
request ([`user.rb:594`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/benchmarks/lobsters/app/models/user.rb#L594)),
and `/replies/unread` and `/replies/comments` write and delete that key. shipit renders its stacks, commits and
deploys through fragment caching.

**Evidence** ([`ruby_bench_cache_probe.rb`](../../bench/upstream/ruby_bench_cache_probe.rb), counts and summed
durations of `cache_*.active_support` events per measured iteration):

| | lobsters, file store | lobsters, memory store | shipit, file store | shipit, memory store |
|---|---|---|---|---|
| reads / writes / deletes per iteration | 118 / 18 / 8 | 118 / 18 / 8 | 249 / 0 / 0 | 249 / 0 / 0 |
| time in cache reads, writes, deletes (ZJIT) | 21.7 ms of ~870 ms (≈2.5%) | 1.7 ms | 14.5 ms (≈0.7%) | 2.4 ms |
| the same, interpreter | 24.7 ms of ~1,220 ms (≈2.0%) | 2.5 ms | – | – |

* **Same work for the app.** The hit and miss pattern is identical (8 regenerations of the inbox count per lobsters
  iteration in both stores). Per-route response sizes and story counts for all 114 lobsters requests are
  byte-identical between the stores ([`ruby_bench_lobsters_routes.rb`](../../bench/upstream/ruby_bench_lobsters_routes.rb)).
  What the file store adds is filesystem syscalls and a Marshal round trip, about 20 ms per lobsters iteration
  in every mode. It is constant non-Ruby work, so it slightly dilutes JIT ratios, the same argument as #527.
* **Concurrent runs fail.** Three ZJIT lobsters processes started together in one checkout: two exited with
  `HTTP status is 500 instead of 200 for req 27/114, "/replies/unread"`, from
  `Errno::ENOENT … rb_file_s_rename (…/tmp/cache/.user3A123Aunread_replies…, …/tmp/cache/927/BE0/user%3A12%3Aunread_replies)`.
  `FileStore#delete` removes empty directories while another process renames into them. With `:memory_store` the
  same three processes all exit 0. This is the 500 recorded in [zjit-yjit-gap](zjit-yjit-gap.md#result) and
  [zjit-iseq-leads](zjit-iseq-leads.md).
* **Iteration 1 depends on the previous run.** A cold `tmp/cache` costs lobsters 2 extra regenerations (the 20 KB
  users tree and the inbox count, +88 ms) and shipit 84 fragment writes (105 ms of file writes alone) plus the
  fragment renders. A warm `tmp/cache` from an earlier run skips them. `--chruby 'before;after'` runs `before` first,
  so on a fresh checkout `after` inherits the warm cache, and the "after 1st itr" column favours it.
  rubybench runs `git clean -dfx` only after all three configurations, so its interpreter run is cold and its YJIT and
  ZJIT runs are warm; its published averages exclude iteration 1, so they are not affected.

**Upstream state.** No issue or PR mentions `tmp/cache`, `file_store` or the race. Precedents for determinism fixes
of this kind: #116 (seed the RNG), #140 (stable seed timestamps), #162 (`Random` over `SecureRandom`), and on #527
alanwu: "We've historically been fine with benchmark changes to align them with what we care about".

**Size and risk.** Two lines: `config.cache_store = :memory_store` in lobsters' `application.rb` and shipit's
`environments/production.rb`. Lobsters gets ~2% faster in every mode (a small score step, accepted on #527);
the process keeps its cache semantics, minus the disk. No one upstream runs lobsters concurrently (rubybench and
ruby/ruby CI run sequentially), so the honest pitch is determinism of iteration 1 and removing filesystem time
from the timed region; the race is a side effect.

## 3. lobsters' fixture is older than its time windows

The fixture's 11,000 stories were all created on 2023-07-18 (users from 2023-05-08), but several routes filter by
time: `/active` (3 days), `/recent` (10 days) and `/top?length=1d|1w|1y`. Since July 2024 those 16 of 114 requests
per iteration render an empty list (about 2.6 KB, 0 stories), while `/newest` renders 25 stories (61 KB). The drift
has stopped (every window has expired), so trend lines are stable now; the cost is coverage: 14% of the requests
exercise the empty branch of the story list.

A fix would shift the fixture's timestamps relative to the current time at boot, or freeze time. Either changes
what lobsters measures (16 more list renders per iteration) and touches the same fixture rubys is changing for #527.
Not worth an unsolicited PR; worth raising only if a maintainer asks about lobsters' route mix.

## 4. ZJIT stats include boot and warmup

The default harness resets YJIT stats at the start of `run_benchmark` (#352) but not ZJIT's
([`harness/default.rb:42`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/harness/default.rb#L42)),
and both are read at the end, so they include the 15 warmup iterations. Measured with per-iteration
`ZJIT_BENCH_STATS` deltas and [`ruby_bench_stats_window.rb`](../../bench/upstream/ruby_bench_stats_window.rb):

| ZJIT, `--zjit-stats-quiet` | outside the measured window | boot share | whole process ÷ 25 vs window per iteration |
|---|---|---|---|
| railsbench `dynamic_send_count` | 60.3% | 0.8% | +0.8% |
| lobsters `dynamic_send_count` | 64.6% | 11.4% | +13.1% |
| shipit `dynamic_send_count` | 60.4% | 0.8% | +1.0% |
| side exits (railsbench / lobsters / shipit) | 61.0% / 63.9% / 60.7% | 2.3% / 7.8% / 1.3% | +2.4% / +10.8% / +1.8% |

Ratios barely move (railsbench dynamic/send 7.02% in the window vs 6.99% whole-process, shipit 11.72% vs 11.66%,
lobsters 10.55% vs 10.07%), and `misc/zjit_diff.rb` compares two builds with the same boot and warmup. Compile
counters are 99.5%+ outside the window, and k0kubun reads `compile_time` as a whole-process number (#387, #498,
#501), so a reset would change a metric they use. Per-iteration deltas of any counter already exist
(`--zjit-stats=KEYS`, #398). Our [`ruby_bench_jit_stats.rb`](../../bench/upstream/ruby_bench_jit_stats.rb) stays
local; at most, mirroring #352's boot exclusion would be a one-line follow-up if someone asks.

## 5. Callgrind/Ir mode

We fall back to Callgrind because the orb has no hardware PMU (`/sys/bus/event_source/devices` lists only
`breakpoint msr software tracepoint uprobe`). On the bare-metal machines the ZJIT team benchmarks on,
`HARNESS=perf PERF='stat -e instructions'` already counts instructions after warmup
([`harness/perf.rb`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/harness/perf.rb)).
A Callgrind harness needs either a compiled client-request extension (our
[`ruby_bench_callgrind.rb`](../../bench/upstream/ruby_bench_callgrind.rb) with `bench/callgrind.c`) or
`callgrind_control`. It would serve PMU-less VMs, which is our setup, not theirs. #533 (rwstauner, open) would add a
prefix command that makes `valgrind --instr-atstart=no` possible without a new harness. Not contributing.

## 6. A Rails-main variant

railsbench and lobsters lock Rails 8.1.1, shipit 8.1.2 and erubi-rails still 8.0.3 (#456 moved the others to 8.1);
the latest release is 8.1.4 (2026-09-24) and 8.2 is unreleased. lobsters started on Rails edge in 2023 (#242, "Get it on rails edge") with a git ref (#253, added
because the edge lock kept failing to install) and moved to releases with 7.1 (#278); since then maintainers bump on
each minor within weeks (#321 "closer to what we can improve", #360, #456). The cost of not tracking main is real
but small: lead 8 (`singleton_class_seen` on `IndexedRow::Mutable#fetch`) runs 1,220 times per lobsters census
operation on Rails main but is worth only 0 / 0.2 / 0.1 M Ir of the ZJIT−YJIT gap per ruby-bench iteration
([zjit-iseq-leads](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03)). It will appear when 8.2 ships and
ruby-bench bumps. Lowrail's census already measures Rails main; a variant upstream would add upkeep the
maintainers chose to drop. A patch bump to 8.1.4 is also not worth a PR: Rails performance changes land on main,
not in 8.1.x (Thomas asked for the 8.1.4.1 bump on 2026-11-05; see round 2); erubi-rails' move to 8.1 is the same routine bump the maintainers did for the others.

## 7. Coverage against real apps

All five Rails benchmarks are read-only. railsbench is a scaffold (index, show, jbuilder JSON); lobsters is 114
logged-in GETs across 25 route patterns; shipit is HTML plus a JSON API; erubi-rails renders one view; activerecord
preloads `has_many`. Our census of about 20 apps ([census](census.md)) measures 97 workloads, including writes
(validations, callbacks, transactions, INSERT/UPDATE compilation), jobs and mailers. None of those paths run in
ruby-bench. Adding them is the maintainers' design call: lobsters' route generator says "POSTs are harder here …
For now, skip it", and a write workload must not accumulate state across iterations. Not an unsolicited PR.

## The six pain points from our docs

| pain point | verdict |
|---|---|
| Wall-time A/A noise is large, so we use Callgrind Ir | **Confirmed** in the orb (section 1); upstream works on bare-metal stability (#354, #533 open; #483, #549, #556, #557 merged). Callgrind stays our method; the fix that helps them is section 1 |
| shipit Ir is bimodal between runs | **Explained, not a suite bug.** GC-excluded runs agree within 0.27% ([zjit-yjit-gap](zjit-yjit-gap.md#totals)); the bimodality is one extra major GC in the window plus ZJIT recompiles after `require "useragent"` (ruby/ruby#19617, k0kubun, open). Upstream #562 covers GC-removed timings |
| Two lobsters processes sharing `tmp/cache` produced a 500 | **Reproduced** (2 of 3 concurrent processes; section 2) |
| Rails 8.1, not main | **Confirmed**, deliberate upstream policy (section 6) |
| The ZJIT default memory can OOM in app-sized runs | **Not on ruby-bench.** At the defaults (64 MiB code, 128 MiB total) with `--zjit-stats`: `compile_error_out_of_memory` 0, code region 12.3 / 42.2 / 34.9 MB, total 21.2 / 67.2 / 55.5 MB (railsbench / lobsters / shipit), `failed_iseq_count` 0. Without stats, lobsters uses 25.6 MB of code. The OOMs were census apps (Fizzy, fizzy-mysql, lobsters on Rails main) |
| Stats need a custom harness | **Partly.** Ratios and per-iteration estimates are close for railsbench and shipit, not for lobsters' boot (section 4). The custom harness stays local |

**Warmup is sufficient for both JITs.** Per-iteration counts over 40 iterations (`ZJIT_BENCH_STATS` /
`YJIT_BENCH_STATS`): side exits and dynamic sends are flat from iteration 4. ZJIT still compiles about 3 ISEQs per
lobsters iteration in iterations 16–25 (3.9 ms of compile time in a ~1,300 ms iteration, 0.3%), YJIT about 11. Mean
iteration times: ZJIT lobsters 1,377 ms (iterations 6–15), 1,301 ms (16–25), 1,319 ms (26–40); railsbench and
shipit are flat within noise from iteration 6. No change needed.

**Smaller observations, no action.** shipit sets `SECRET_KEY_BASE = SecureRandom.hex(128)` per run
([`benchmark.rb:13`](https://github.com/ruby/ruby-bench/blob/73918b2fc1a84702fea63e06f64d179751d69df4/benchmarks/shipit/benchmark.rb#L12));
the key length is fixed, so the work does not change. tekknolagi's open #425 asks about the distribution of
`blank?` receivers in large apps; the census could answer it, but that is a data comment on an idea thread, so it
stays here unless he asks again.

## Method and receipts

* Build: `../configure --enable-yjit --enable-zjit --disable-install-doc optflags=-O3 debugflags=-ggdb3` at
  `a8b095a07e`, installed to `~/rubies/m-a8b095`.
* Each experiment ran in its own copy of ruby-bench (`cp -a`), so no two runs shared `tmp/cache` or the railsbench
  database except in the deliberate concurrency test.
* A/A: `./run_benchmarks.rb --no-sudo --interleave --pvalue -e 'zjitA::ruby --zjit' -e 'zjitB::ruby --zjit'
  railsbench lobsters shipit`, then three more rounds of `lobsters railsbench`, sequential, alone on the orb
  (`setarch -R` and `taskset -c 1` applied by the runner).
* Cache probe: `WARMUP_ITRS=5 MIN_BENCH_ITRS=5` (lobsters), `WARMUP_ITRS=1|2 MIN_BENCH_ITRS=2` (shipit), cold and
  warm iteration-1 runs with `WARMUP_ITRS=0 MIN_BENCH_ITRS=1` after removing `tmp/cache` or not. Concurrency:
  three `WARMUP_ITRS=0 MIN_BENCH_ITRS=25` lobsters processes started together, file store versus memory store.
* Stats window and warmup: `WARMUP_ITRS=15 MIN_BENCH_ITRS=25 MIN_BENCH_TIME=0`, ZJIT `--zjit --zjit-stats-quiet`
  with `ZJIT_BENCH_STATS=compiled_iseq_count,side_exit_count,dynamic_send_count,send_count,compile_time_ns,compile_error_out_of_memory`,
  YJIT `--yjit --yjit-stats=quiet` with the YJIT equivalents; three benchmarks in parallel (counts only).
* Fixture dates: `SELECT min(created_at), max(created_at)` on `benchmarks/lobsters/db/production.sqlite3`
  (stories, comments, users) and shipit's `production.committed.sqlite3` (2025-07-02).

# Round 2: five topics checked and the PRs opened (2026-11-05)

The coordinator assigned five topics: the Rails 8.1.4.1 bump, JIT compiles in the measured window, planner
statistics for shipit, the nondeterministic lobsters `/reply` pages and, added later because ruby-bench main CI was
red, shipit's nokogiri. Every topic that passed our checks and a skeptical subagent review opened as its own PR on
ruby/ruby-bench, next to #565 (DECISIONS, 2026-11-05: ruby-bench PRs may open side by side). The other topics are
recorded below with their data. Nothing else was posted.

**Pins.** ruby-bench main [`00f0f8b`](https://github.com/ruby/ruby-bench/commit/00f0f8beab27edb11c0253cc630f91f17d1f1891)
(#564 merged). Ruby 4.0.9 (mise build). Ruby master
[`7f9638f41e`](https://github.com/ruby/ruby/commit/7f9638f41e250d4f3b43daabaa645516994dd7e5), built with `--enable-yjit
--enable-zjit optflags=-O3 debugflags=-ggdb3`. JRuby 10.1.2.0 on Temurin 21, used only for lockfile checks. The orb
has 8 vCPUs, so wall times are noisy and instruction counts are not.

| # | topic | verdict | PR / record | head |
| --- | --- | --- | --- | --- |
| 0 | shipit's nokogiri 1.19.1 doesn't build on Ruby head on Windows | **PR** | [ruby/ruby-bench#566](https://github.com/ruby/ruby-bench/pull/566) | `8f5b27211c` |
| 1 | Rails 8.1.4.1 for lobsters, railsbench, shipit (and activerecord) | **PR** | [ruby/ruby-bench#567](https://github.com/ruby/ruby-bench/pull/567) | `971006363a` |
| 2 | YJIT and ZJIT still compile in the measured window | **issue draft**, back to the coordinator | [below](#2-yjit-and-zjit-still-compile-in-the-measured-window) | – |
| 3 | `ANALYZE` for shipit's fixture | **no PR**: 6 of 23 plans change, ≈0.14 ms per pass | [below](#3-planner-statistics-for-shipit) | – |
| 4 | lobsters `/reply` pages differ between runs | **no PR**: a minutes counter from `Time.now`, same work | [below](#4-the-lobsters-reply-pages) | – |

## 0. shipit's nokogiri on Ruby head (ruby/ruby-bench#566)

**Cause.** Every run of ruby-bench's `Test benchmarks` workflow on main since 2026-10-30 failed; the last green run
was 2026-10-29 (40899297599). In each one, only `benchmark-default-windows (head)` and the `all-tests` summary fail.
In run 41944045400 shipit's `bundle install` stops compiling nokogiri 1.19.1: `xml_node_set.c:382:33: error: passing
argument 2 of 'rb_range_beg_len' from incompatible pointer type [-Wincompatible-pointer-types]`, expected
`rb_len_t *` (`long long int *`). ruby/ruby@cc3ba11012 (2026-10-09) changed `rb_range_beg_len`, `rb_str_subpos`,
`rb_arithmetic_sequence_beg_len_step` and `ruby_enc_find_basename`/`extname` to take `rb_len_t *`. `rb_len_t` is
`long` everywhere except 64-bit mswin (ruby/ruby@4e746b14fd) and, since
[oneclick/rubyinstaller2-packages@0f441be052](https://github.com/oneclick/rubyinstaller2-packages/commit/0f441be052)
(2026-10-29 21:04 UTC, "Enable 64 bit rb_len_t in ruby-head … to early raise issues with that change in gems"),
RubyInstaller's ruby-head (MinGW), which the job uses. That commit, not ruby/ruby@4b95d69fc4 (mswin warning flags,
which MinGW doesn't use), is why 10-29 passed and 10-30 failed; the coordinator's brief named 4b95d69fc4, and the
reviewer caught it. The job's GCC reports the mismatch as an error (`-Wincompatible-pointer-types` is an error by default since GCC 14).

**Scope.** Of the benchmarks the Windows job runs, only shipit locks a nokogiri older than 1.19.5. lobsters,
railsbench and erubi-rails lock 1.18.9 but are excluded there (`EXCLUDES: erubi-rails,graphql-native,lobsters,railsbench`).
The other native gems shipit compiled on head in that run (json, bigdecimal, erb, stringio, date, io-console, nio4r,
psych, puma, websocket-driver, sqlite3, msgpack) built; none of their sources calls the five changed functions.
nokogiri 1.19.5 switched to `rb_len_t` (sparklemotion/nokogiri#3711) and 1.19.7 also builds on 4.1.0-preview1
(#3755); the bundled libxml2, libxslt, zlib and libiconv versions are the same as in 1.19.1.

**Change.** `bundle lock --update nokogiri --conservative` in `benchmarks/shipit`: four lines (both platform
entries and their checksums). Local checks on Linux: shipit installs and runs on Ruby 4.0.9 and on master, and all
57 requests of one pass return 200 with bodies identical to 1.19.1 (CSRF tokens stripped).

**CI.** The fork never ran Actions (forks need a click in the UI), so on the coordinator's instruction the PR opened
directly and its own CI was the proof. Run 42000663489 on `8f5b27211c`: all 15 checks pass. In `benchmark-default-windows (head)` nokogiri 1.19.7 compiled with native extensions and shipit ran (benchmark 66 of 75), and `all-tests` is green for the first time on this base.

**Body (as opened; [file](../../bench/upstream/ruby_bench_round2/nokogiri-body.md), edited once after #567 opened to name it):**

> This bumps nokogiri in shipit's Gemfile.lock from 1.19.1 to 1.19.7 to fix the `benchmark-default-windows (head)` job, which has failed on every run on main since 2026-10-30 (the last passing run was on 2026-10-29).
>
> In that job, shipit's `bundle install` fails compiling nokogiri 1.19.1 (run 41944045400): `xml_node_set.c:382:33: error: passing argument 2 of 'rb_range_beg_len' from incompatible pointer type [-Wincompatible-pointer-types]`. ruby/ruby@cc3ba11012 changed `rb_range_beg_len` to take `rb_len_t *`, and on 2026-10-29 RubyInstaller's ruby-head build made `rb_len_t` 64 bits (oneclick/rubyinstaller2-packages@0f441be052), so it no longer matches nokogiri's `long`. Elsewhere `rb_len_t` is still `long`, which is why the Linux head job passes. nokogiri switched to `rb_len_t` in 1.19.5 (sparklemotion/nokogiri#3711), and 1.19.7 also compiles against Ruby 4.1.0-preview1 (sparklemotion/nokogiri#3755).
>
> Of the benchmarks the Windows job runs, only shipit is affected: lobsters, railsbench and erubi-rails lock nokogiri 1.18.9, but that job already excludes them. #567, the Rails 8.1.4.1 bump, makes the same nokogiri change in shipit's Gemfile.lock; the two PRs merge cleanly in either order.
>
> On Linux, with Ruby 4.0.9 and with Ruby master 7f9638f41e, shipit installs and runs. All 57 requests of one benchmark pass return 200 and the same bodies as with 1.19.1, apart from CSRF tokens.

## 1. Rails 8.1.4.1

**How the maintainers bump.** Patch bumps are one PR across every Rails benchmark with lockfile changes only:
#411 (k0kubun, 8.0.2.1 → 8.0.3, five lockfiles, "to fix the following warning"), #456 (byroot, 8.1 for all but
shipit, which followed in 5806cbd). So this is one PR, and it includes `benchmarks/activerecord` (activerecord 8.1.1,
as #411 and #456 did). erubi-rails stays on 8.0.3: moving it to 8.1 is a minor upgrade, outside this brief. The
2026-11-03 evaluation (section 6) called a patch bump not worth a PR; Thomas asked for it, and it now also carries
the 8.1.4.1 security fixes and rails-html-sanitizer 1.7.2.

**Change.** `bundle lock --update <the Rails gems in each Gemfile> --conservative` for lobsters and shipit. Both
locks also move loofah 2.24/2.25.0 → 2.25.3, rails-html-sanitizer → 1.7.2 and nokogiri → 1.19.7, because Action
View 8.1.4.1 requires `rails-html-sanitizer >= 1.7.2`, which requires `nokogiri >= 1.19.5`. For lobsters the resolver
added a `nokogiri (1.19.7-x86_64-linux-gnu)` entry the lock never had (its `PLATFORMS` lists `x86_64-linux`); it was
removed again so the lock keeps building nokogiri from source as on main.

railsbench and activerecord don't resolve with any Bundler (4.0.12, 4.0.20) on CRuby: their `GIT` source for
k0kubun's activerecord-jdbc-adapter fork (#530) has empty specs, and `bundle lock` fails with "jdbc-sqlite3 >= 3.8,
< 4.A could not be found". Under JRuby the resolve succeeds but drops the `ruby` and `x86_64-linux` platforms.
Their locks were therefore edited with [`relock_railsbench.py`](../../bench/upstream/ruby_bench_round2/relock_railsbench.py),
which copies the spec blocks and checksums Bundler produced for lobsters (same Rails gems, same sanitizer chain) and
moves nokogiri's ruby, `-java` and `-x86_64-linux-gnu` entries to 1.19.7 with checksums from rubygems.org. Checks:
`bundle install` on Ruby 4.0.9 leaves both locks byte-identical; JRuby 10.1.2.0 installs main's lock and the new one
the same way (both rewrite the lock identically apart from the bumped versions, activerecord 8.1.4.1 with arjdbc
80.0.pre1 loads).

**Responses.** With [`dump_harness.rb`](../../bench/upstream/ruby_bench_round2/dump_harness.rb) and
[`cmp_dumps.rb`](../../bench/upstream/ruby_bench_round2/cmp_dumps.rb), one warmup pass, then every request of the
next pass, Ruby 4.0.9: lobsters 114 of 114 return 200 and are identical to main except the five `/reply` pages,
which differ in the minutes counter (topic 4); shipit 57 of 57 return 200, identical; railsbench 2,000 of 2,000
return 200, identical after normalizing timestamps (`db:seed` recreates its 100 posts with the current time).

**Timing.** Ruby 4.0.9, base then bump, two rounds ([`bump_bench.sh`](../../bench/upstream/ruby_bench_round2/bump_bench.sh)); mean of the 10 iterations after 10 warmups, ms:

| | interpreter main | interpreter bump | YJIT main | YJIT bump |
| --- | ---: | ---: | ---: | ---: |
| railsbench | 2,649 / 2,609 | 2,670 / 2,673 | 1,197 / 1,249 | 1,226 / 1,254 |
| lobsters | 924 / 980 | 946 / 959 | 552 / 562 | 580 / 562 |
| shipit | 1,731 / 1,685 | 1,685 / 1,663 | 781 / 826 | 826 / 811 |

Only railsbench interpreted is consistently slower (+1.6%, both bump runs above both main runs); the rest moves
within the run-to-run spread. Callgrind instructions per iteration, interpreter, fixed heap
(`RUBY_GC_HEAP_0..4_INIT_SLOTS` from [bench.md](../bench.md)), `ruby_bench_ir.rb` with two Gemfile copies per tree,
against `base-a`:

| | main A/A (`base-b`) | bump-a | bump-b |
| --- | ---: | ---: | ---: |
| railsbench | −0.081% | +1.522% | +1.408% |
| lobsters | +0.034% | +0.806% | +1.012% |
| shipit | +0.030% | +1.059% | +1.148% |

**Claimed:** Rails 8.1.4.1 costs 0.8–1.5% interpreter instructions per iteration over 8.1.1/8.1.2. Not attributed
(Rails gems and the sanitizer chain move together); it matches the impact run's +0.85% for the 8.1 backports on
railsbench ([rails-82-impact](rails-82-impact.md#ruby-bench-instructions-per-iteration)), so the 8.1.x patch line is
the likely source. A lead for a later Callgrind diff, not posted. A first Callgrind run without the fixed heap failed
its A/A (railsbench +3.6%, shipit −2.9%) and is not used. YJIT instruction counts were not run.

**Reviewer findings applied.** The dependency chain is loofah 2.25.3 → nokogiri ≥ 1.19.5 (not rails-html-sanitizer);
the first draft's "wall time within the spread" was wrong for railsbench interpreted; the body says erubi-rails stays
on 8.0 as in #456. nobu's open #461 touches the same lockfiles but already conflicts with main in all of them; not
mentioned (DECISIONS: collaborative, not credit-seeking). TruffleRuby and Windows coverage of railsbench and lobsters
with nokogiri 1.19.7 come only from the PR's CI.

**Body (as opened; [file](../../bench/upstream/ruby_bench_round2/rails-bump-body.md)):**

> This bumps lobsters, railsbench, shipit and activerecord from Rails 8.1.1 (shipit 8.1.2) to 8.1.4.1, the latest 8.1 release. Only Gemfile.lock files change. Action View 8.1.4.1 requires rails-html-sanitizer 1.7.2, which needs loofah 2.25.3, which needs nokogiri 1.19.5 or later, so those move too. erubi-rails stays on Rails 8.0, as in #456. #566 makes the same nokogiri change in shipit; the two PRs merge cleanly in either order.
>
> `bundle lock --update` fails for railsbench and activerecord on CRuby because of the JRuby-only git source from #530, so I copied versions and checksums from the new lobsters lock (nokogiri -java from rubygems.org). `bundle install` on Ruby 4.0.9 leaves both unchanged, and JRuby 10.1.2.0 rewrites them the same way it rewrites main's.
>
> All 2,000 railsbench, 114 lobsters and 57 shipit requests return 200 with the same bodies as on main, apart from CSRF tokens and timestamps.
>
> Rails 8.1.4.1 runs about 1–1.5% more instructions per iteration (Callgrind, Ruby 4.0.9 interpreter, fixed heap, two processes per tree; main vs main within 0.1%): railsbench +1.4–1.5%, shipit +1.1%, lobsters +0.8–1.0%. Wall time from two runs is too noisy to confirm this.

## 2. YJIT and ZJIT still compile in the measured window

**Measured.** [`jit_counts.sh`](../../bench/upstream/ruby_bench_round2/jit_counts.sh): the stock default harness with
`WARMUP_ITRS=0 MIN_BENCH_ITRS=60 MIN_BENCH_TIME=0`, per-iteration deltas via `YJIT_BENCH_STATS=compiled_block_count,compiled_iseq_count,invalidation_count,compile_time_ns`
(4.0.9 `--yjit`) and `ZJIT_BENCH_STATS=compiled_iseq_count,compiled_side_exit_count,compile_time_ns,code_region_bytes`
(master `--zjit`), two processes per cell, eight at a time, each in its own copy of ruby-bench. Summaries with
[`counts_table.rb`](../../bench/upstream/ruby_bench_round2/counts_table.rb); raw output in
[`counts/`](../../bench/upstream/ruby_bench_round2/counts/).

| | last iteration with a compile | window 16–25 (default) | 31–40 (`--warmup=30`) | 51–60 (`--warmup=50`) |
| --- | ---: | ---: | ---: | ---: |
| YJIT railsbench | 59 | 7–74 blocks, 0.01–0.02% | 38–52 blocks, 0.01% | 18–19 blocks, 0.01% |
| YJIT lobsters | never stops (60) | ≈2,010 blocks, 112 ISEQs, 0.88–0.93% | ≈1,700 blocks, 76 ISEQs, 0.65% | ≈300 blocks, 28 ISEQs, 0.16% |
| YJIT shipit | never stops (60) | ≈1,267 blocks, 52 ISEQs, 0.32% | 134–203 blocks, 0.05% | 346–394 blocks, 0.10% |
| YJIT erubi-rails | 51–56 | 3–9 blocks, 0.00–0.01% | 32 blocks, 0.01% | 6–12 blocks, 0.01% |
| ZJIT railsbench | 39–42 | 2 ISEQs, 0.01% | 1–2 ISEQs, 0.01% | 0 |
| ZJIT lobsters | 49 | 26 ISEQs, 0.31–0.34% | 14 ISEQs, 0.27% | 0 |
| ZJIT shipit | 49 | 4–5 ISEQs, 0.05–0.07% | 6–7 ISEQs, 0.06% | 0 |
| ZJIT erubi-rails | 31 | 2 ISEQs, 0.02% | 1 ISEQ, 0.02% | 0 |

Percentages are `compile_time_ns` over the wall time of the same ten iterations. Mean iteration times do not trend
after iteration 16 beyond run-to-run noise (YJIT lobsters 617/579 ms in 16–25, 593/604 ms in 26–40, 634/594 ms in
41–60). This matches the impact run: lobsters' window gained about 3,400 YJIT blocks there.

**How ruby-bench chooses warmup.** `harness/default.rb` runs `WARMUP_ITRS` (default 15), then at least
`MIN_BENCH_ITRS` (10) and `MIN_BENCH_TIME` (10 s). `run_benchmarks.rb --warmup=N` sets `WARMUP_ITRS` for every
benchmark; `benchmarks.yml` has `desc`, `category`, `ractor`, `single_file`, `default_harness` and pinning keys but no
warmup key. `harness/warmup.rb` (MAD threshold) is the opt-in alternative. Downstream,
[rubybench](https://github.com/rubybench/rubybench/blob/bd5a8e6a84165006a8b365541ddfbec374774bd9/lib/ruby_bench.rb#L10-L12)
passes `--warmup=30` for YJIT and ZJIT runs since rubybench/rubybench#30 (eightbitraptor, merged 2026-11-04; its body
says speed.ruby-lang.org uses 50); ruby/ruby's `tool/zjit_diff.rb` calls `run_benchmarks.rb` with the default 15.

**Verdict: no PR.** A per-benchmark warmup would need a new `benchmarks.yml` key and harness plumbing, and it would
not make YJIT flat on lobsters or shipit even at 50. The compile time left in the window is under 1% (YJIT
lobsters) and under 0.1% elsewhere with 30 warmup iterations, the published runs already use 30, and YJIT is in
maintenance mode. The issue draft below is for the coordinator and Thomas; it is not opened (new issues need
Thomas's OK).

**For Lowrail's JIT-flat gate.** ZJIT on master is flat after 50 warmup iterations on all four; YJIT 4.0.9 never is on
lobsters and shipit within 60. A YJIT row on those two can only pass with a much longer warmup, or with a gate that
allows a stated compile-time share.

**Issue draft (not opened; [file](../../bench/upstream/ruby_bench_round2/warmup-issue-draft.md)):**

> **Title:** The default 15 warmup iterations leave YJIT and ZJIT compiling in the measured window of the Rails benchmarks
>
> With the default harness (15 warmup iterations, then at least 10 measured iterations and 10 seconds), YJIT and ZJIT still compile new code during the measured iterations of railsbench, lobsters, shipit and erubi-rails. I counted compiles per iteration with `YJIT_BENCH_STATS=compiled_block_count,compiled_iseq_count,compile_time_ns` (Ruby 4.0.9, `--yjit`) and `ZJIT_BENCH_STATS=compiled_iseq_count,compile_time_ns` (Ruby master 7f9638f41e, `--zjit`), `WARMUP_ITRS=0 MIN_BENCH_ITRS=60`, on ruby-bench 00f0f8b, two processes each:
>
> | | last iteration with a compile | compile time in iterations 16–25 | 31–40 | 51–60 |
> | --- | ---: | ---: | ---: | ---: |
> | YJIT railsbench | 59 | 0.01–0.02% | 0.01% | 0.01% |
> | YJIT lobsters | 60 (never stops) | 0.88–0.93% | 0.65% | 0.16% |
> | YJIT shipit | 60 (never stops) | 0.32% | 0.05% | 0.10% |
> | YJIT erubi-rails | 51–56 | 0.01% | 0.01% | 0.01% |
> | ZJIT railsbench | 39–42 | 0.01% | 0.01% | 0 |
> | ZJIT lobsters | 49 | 0.31–0.34% | 0.27% | 0 |
> | ZJIT shipit | 49 | 0.05–0.07% | 0.06% | 0 |
> | ZJIT erubi-rails | 31 | 0.02% | 0.02% | 0 |
>
> The percentages are compile time over the wall time of those 10 iterations. In iterations 16–25, YJIT compiles about 2,000 blocks per lobsters process and 1,270 per shipit process.
>
> rubybench already passes `--warmup=30` for JIT runs (rubybench/rubybench#30), and with 50 warmup iterations ZJIT compiles nothing in the window on any of the four. The remaining cost is small; the question is whether `run_benchmarks.rb` should default to a longer JIT warmup for these benchmarks, so local runs and `tool/zjit_diff.rb` measure the same steady state as the published numbers. `benchmarks.yml` has no per-benchmark warmup setting today.

## 3. Planner statistics for shipit

`db/production.committed.sqlite3` has no `sqlite_stat1`; its largest tables are `commits` (150 rows), `statuses`
(141), `tasks` and `schema_migrations` (78). [`plans_harness.rb`](../../bench/upstream/ruby_bench_round2/plans_harness.rb)
records every SELECT of one pass after one warmup pass (Ruby 4.0.9, SQLite 3.50.3, sqlite3 gem 2.7.3), prints
`EXPLAIN QUERY PLAN` before and after `ANALYZE` on the same in-memory connection, and times each statement with its
recorded binds (median of 5 × 2,000 executions):

* 23 distinct SELECTs, 4,275 executions per pass. `ANALYZE` takes 0.3–0.5 ms and writes 38 rows.
* 6 plans change (275 executions per pass): the `commits` range queries use the primary key instead of
  `index_commits_on_stack_id` (240 executions), the three-row `users` and `repositories` lookups and the `stacks`
  list switch to a scan, and the `tasks` `LIMIT` query reads the primary key in order instead of sorting.
* SQLite time per pass for those six: 1.13 → 0.99 ms; for all 23: 49.9 → 49.5 ms, within the timing's spread. A shipit
  iteration takes about 1,700 ms interpreted and 800 ms with YJIT, so the gain is below 0.02%.

**Verdict: no PR.** Unlike lobsters (#565, 10.8 → 0.08 ms on the hottest query), shipit's tables are too small for a
plan to matter.

## 4. The lobsters `/reply` pages

`/comments/:id/reply` renders `comments/_commentbox.html.erb`, which says "This story is almost 90 days old and will
stop accepting comments in N minutes" with N = `((comment.story.created_at - Story::COMMENTABLE_DAYS.days.ago) / 60).floor`.
`days.ago` reads `Time.now`, so N falls by one per minute: two runs 28 minutes apart rendered `-1606878` and
`-1606906`, and that is the only difference after stripping CSRF tokens (runs within the same minute are
byte-identical). The guard `(story.created_at - 1.hour).before?(90.days.ago)` has been true for every story since the
fixture's stories (all created 2023-07-18) passed 90 days in October 2023, so the same branch renders every time,
and N keeps seven digits until about 2042 (10,000,000 minutes is 19 years after the window closed in October 2023). Same queries, same template, same
length (2,572 bytes).

**Verdict: no PR.** The work per iteration does not vary; at most the text, by one digit in about 2042. #565's body already
calls these pages run-dependent.

## Method and receipts (round 2)

* Scripts in [`bench/upstream/ruby_bench_round2/`](../../bench/upstream/ruby_bench_round2/); each benchmark ran in
  its own checkout or `cp -a` copy, so no two processes shared `tmp/` or railsbench's database.
* Wall time: [`bump_bench.sh`](../../bench/upstream/ruby_bench_round2/bump_bench.sh), `WARMUP_ITRS=10
  MIN_BENCH_ITRS=10 MIN_BENCH_TIME=0`, `setarch -R taskset -c 1`, one process at a time, base then bump, two rounds.
* Instructions: `actionview_cpu/ruby_bench_ir.rb run --benches railsbench,lobsters,shipit --modes interpreter`
  with variants `base-a`, `base-b`, `bump-a`, `bump-b` (Gemfile copies with main's and the branch's locks), cachegrind,
  4-iteration minus 1-iteration run after 2 warmups.
* Reviews: a skeptical subagent per PR (facts against the logs and commits, outsider read of the body); its findings
  are in each section.

# Round 3: Rails benchmarks on Windows (2026-11-05)

ruby-bench's `benchmark-default-windows` job sets `EXCLUDES: erubi-rails,graphql-native,lobsters,railsbench`, because
nokogiri 1.18.9 builds from source there and its bundled libiconv fails to compile (erubi-rails, lobsters,
railsbench), graphql-c_parser's token names clash with Windows headers (graphql-native) and stackprof fails to build
(lobsters). #567 moves lobsters and railsbench to nokogiri 1.19.7. Tested on our fork
([thomasklemm/ruby-bench](https://github.com/thomasklemm/ruby-bench)) after Actions were enabled there (the workflow
itself also had to be switched from `disabled_fork` to active), with fork-internal PRs against a copy of #567's
branch (`ci-base/rails-8.1.4.1` = `971006363a`). All of them were closed without a comment.

| benchmark | on #567 alone | what it needs | Ruby 4.0.9 | head |
| --- | --- | --- | --- | --- |
| railsbench | runs | nothing (nokogiri 1.19.7 from #567) | precompiled `x64-mingw-ucrt` gem | built from source |
| erubi-rails | fails: nokogiri 1.18.9, `loop_wchar.h: conflicting types for 'mbrtowc'` | its own nokogiri 1.19.7 bump (#567 leaves it on Rails 8.0.3 and nokogiri 1.18.9) | runs | runs |
| lobsters | fails: stackprof 0.2.28 (`unknown type name 'siginfo_t'`, `sigaction`, `setitimer`) | `gem 'stackprof', platforms: :mri`, as in railsbench | runs | runs |
| graphql-native | fails: graphql-c_parser 1.1.3, `'FLOAT'`, `'INPUT'`, `'INT'` redeclared | not fixable by a bump: 1.1.4 (latest, 2026-08-03) keeps the same enum names | stays excluded | stays excluded |

**stackprof.** 0.2.28 (2026-02-13) is the latest release and has no Windows support (POSIX signals, `setitimer`,
pthreads, no `_WIN32` guard). lobsters lists it only in its `development` group; the benchmark runs with
`RAILS_ENV=production` and `Bundler.require(*Rails.groups)` and never requires it. Bundler's `mri?` is
`!windows? && RUBY_ENGINE == "ruby"`, so the platform filter drops it on Windows (and TruffleRuby, whose job already
excludes lobsters). `bundle lock` leaves lobsters' Gemfile.lock unchanged.

**erubi-rails.** `bundle _4.0.12_ lock --update nokogiri --conservative` on Ruby 4.0.9: four lines, the two nokogiri
entries and their checksums (Bundler 4.0.20 would also rewrite `BUNDLED WITH` and drop the bundler checksum, so the
lock's own Bundler was used).

**Fork runs.**

* [42012865642](https://github.com/thomasklemm/ruby-bench/actions/runs/42012865642): #567 with EXCLUDES emptied.
  Both Windows entries fail with erubi-rails, graphql-native and lobsters; railsbench runs.
* [42012872942](https://github.com/thomasklemm/ruby-bench/actions/runs/42012872942): plus the erubi-rails bump.
  erubi-rails runs; graphql-native and lobsters (stackprof) fail.
* [42013201457](https://github.com/thomasklemm/ruby-bench/actions/runs/42013201457): plus the stackprof change. Only
  graphql-native fails.
* [42018186964](https://github.com/thomasklemm/ruby-bench/actions/runs/42018186964): the final commit with
  `EXCLUDES: graphql-native`. All 15 checks pass; both `benchmark-default-windows` entries run erubi-rails, lobsters,
  railsbench and shipit. The run was on `2695979940`; the branch head `dd76311099` differs only in the commit message
  (reviewer: "installs", not "builds").

**Dependency.** lobsters and railsbench need #567's nokogiri, so the PR depends on #567. Branch
[`thomasklemm/windows-rails-benchmarks`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/windows-rails-benchmarks)
@ `dd76311099`, one commit on `971006363a`. **Opened 2026-11-05 as
[ruby/ruby-bench#568](https://github.com/ruby/ruby-bench/pull/568)** before #567 merged (Thomas: enable the Windows
benchmarks now), with one sentence at the top saying it includes #567's commit until then. When #567 merges: rebase
onto upstream main, push with `--force-with-lease`, check that the diff is down to the three files, and the PR's
own CI repeats the check on the merged base.

**Review.** A skeptical subagent checked every claim against the job logs and code and found the change minimal and
correct (one concern: removing the Rails exclusions from the Windows job). Applied: name the graphql-c_parser cause
and that 1.1.4 doesn't fix it, "both `benchmark-default-windows` jobs" instead of "both Windows jobs", and wait for
the final run before linking it. Its point that the body should say it depends on #567 became the opening sentence
once the PR opened before #567.

**Body (as opened; [file](../../bench/upstream/ruby_bench_round3/windows-body.md)):**

> This builds on #567 and includes its commit until #567 merges; I'll rebase then.
>
> This runs erubi-rails, lobsters and railsbench in the `benchmark-default-windows` job, so only graphql-native stays excluded there.
>
> They were excluded because nokogiri 1.18.9 builds from source on Windows and its bundled libiconv fails to compile. #567 moved lobsters and railsbench to nokogiri 1.19.7, which installs on Windows with Ruby 4.0 (the precompiled x64-mingw-ucrt gem) and with head (built from source). erubi-rails gets the same bump here.
>
> lobsters was also excluded because stackprof fails to build. stackprof 0.2.28, the latest release, uses POSIX signals and timers that MinGW doesn't have. lobsters lists it only in its development group, which the benchmark doesn't load, so it now gets `platforms: :mri`, as in railsbench's Gemfile. Gemfile.lock doesn't change.
>
> graphql-native stays excluded: graphql-c_parser uses FLOAT, INT, INPUT, INTERFACE and TokenType as C names, which the Windows headers already define, and 1.1.4, the latest release, still does. rmosolgo/graphql-ruby#5877 fixes that.
>
> In this run on my fork, both `benchmark-default-windows` jobs pass and run all three benchmarks: https://github.com/thomasklemm/ruby-bench/actions/runs/42018186964

## graphql-c_parser on Windows (rmosolgo/graphql-ruby#5877)

graphql-native stays excluded from the Windows job because graphql-c_parser doesn't compile with RubyInstaller
(MinGW). `ruby.h` → `ruby/win32.h` → `winsock2.h` → `windows.h` brings in five names the extension also uses: `FLOAT`
and `INT` (`minwindef.h` typedefs), `INPUT` (`winuser.h` struct), `INTERFACE` (a `commdlg.h` macro that expands to
`IPrintDialogServices`) and `TokenType` (an enumerator in `winnt.h`). The brief and the first patch covered only the
first three; the reviewer found the other two in the same CI log, and fork run
[42026599629](https://github.com/thomasklemm/ruby-bench/actions/runs/42026599629) on that first patch confirmed them
(`lexer.rl:168:2` and `lexer.rl:194:3`, cancelled after the Ruby 4.0.9 job failed). No issue or PR in graphql-ruby
mentions Windows; its CI is Ubuntu-only. Latest release 1.1.4 (2026-08-03) has the same names.

**Change.** Branch
[`thomasklemm/c-parser-windows-token-names`](https://github.com/thomasklemm/graphql-ruby/tree/thomasklemm/c-parser-windows-token-names)
@ `115a3c84e5`, one commit on graphql-ruby master `6b4bef2522`, four files (+235 −223, almost all generated):
`%define api.token.prefix {GRAPHQL_}` in `parser.y` (replacing a blank line, so no `#line` shifts) and `return
GRAPHQL_YYEOF`; in `lexer.rl` the enumerators `FLOAT`, `INT`, `INPUT`, `INTERFACE` become `*_LITERAL` (as
`TYPE_LITERAL` already is), with explicit cases keeping the symbols `:INPUT` and `:INTERFACE`, and `enum TokenType`
becomes `GraphQLTokenType`. Token numbers (`200 + tt` against the `%token` values) and Bison's `yytname` are
unchanged, so error messages stay the same (`query_spec.rb:722` asserts `unexpected INT ("1")`). Alternatives: renaming
in `parser.y` changes messages; `#undef` can't remove typedefs or enumerators; `WIN32_LEAN_AND_MEAN` leaves
`minwindef.h`, `winuser.h` and `winnt.h`.

**Generated files.** Bison 3.8.2 (Debian) reproduces master's `parser.c` byte for byte, so `parser.c` is regenerated.
Ragel 7.0.4 (built from source with colm 0.14.7, the Rakefile's version) does not reproduce master's `lexer.c`
(indentation and `#line` self-references differ), so
[`apply_lexer_step1.py`](../../bench/upstream/ruby_bench_round3/apply_lexer_step1.py) and
[`apply_lexer_step2.py`](../../bench/upstream/ruby_bench_round3/apply_lexer_step2.py) apply to the committed file
exactly the content lines Ragel changes, copy Ragel's `lexer.rl` `#line` numbers and renumber self-references as
line + 1 (the committed file's rule). Checked: content equals Ragel's output ignoring whitespace, `lexer.rl` `#line`
sequence identical, 0 self-references off.

**Linux, Ruby 4.0.9.** `GRAPHQL_CPARSER=1 rake test`: 2,754 tests, 0 failures, 0 errors, 4 skips. `rake test`: 2,712
tests, 0 failures, 13 skips. Runs in parallel with other suites hit the timing assertions in
`async_dataloader_spec.rb:300` / `nonblocking_dataloader_spec.rb:209` on master and branch alike; solo runs pass. A probe
(tokens of `interface`, `input`, `extend`, ints, floats; five parse errors; printed AST) is byte-identical to master.
A MinGW-w64 12.2 syntax check with a Ruby-header shim reproduces CI's errors on master; the first patch's `lexer.c`
still had 2 (`INTERFACE`, `TokenType`), the final branch has none in any extension file.

**Windows.** Fork run [42034420178](https://github.com/thomasklemm/ruby-bench/actions/runs/42034420178): graphql-native
from the branch (Gemfile `git:` source, `EXCLUDES` without graphql-native), all 15 checks green; it compiled and ran on
Ruby 4.0.9 (300.3 ms) and head 4.1.0dev `64ae80dd36` (238.0 ms). It ran on #566's commit, because on main the head job
also fails on shipit's nokogiri 1.19.1 (run [42029534044](https://github.com/thomasklemm/ruby-bench/actions/runs/42029534044):
graphql-native ran on both, only shipit failed). Fork PRs #6 and #7 are closed; Actions stay off on
thomasklemm/graphql-ruby (0 runs).

**Review.** A skeptical subagent found the `INTERFACE` and `TokenType` blocker (fixed), confirmed token numbers,
`yytname`, `#line` numbers and that nothing else uses the names, scanned the MinGW headers for further collisions (none;
`TRUE`/`FALSE` only in strings, `GRAPHQL_` unused), and asked for solo test runs as evidence, "MinGW" instead of
"Windows" and a shorter body (applied). Not verified: mswin/MSVC (the Windows SDK has the same two definitions). It
suggested dropping the Lowrail footer as promotional; kept, as DECISIONS asks for it on bug and compatibility PRs and
graphql-ruby's contributing guide has no rule against it. No CHANGELOG entry: the maintainer writes
`graphql-c_parser/CHANGELOG.md` at release time, contributor PRs (#5856, #5864, #5870) don't touch it.

**Status.** Opened 2026-11-05 as [rmosolgo/graphql-ruby#5877](https://github.com/rmosolgo/graphql-ruby/pull/5877)
(head `115a3c84e5`) after the coordinator's go, with the footer link pinned to Lowrail `de05fe1376`. #568's
graphql-native sentence was edited once to name all five clashing names and link #5877. The Amp GitHub App can't
access rmosolgo/graphql-ruby or ruby/ruby-bench, so neither PR has a comment subscription; the coordinator watches
them. **Follow-up:** once a graphql-c_parser release contains the
fix, ruby-bench can drop `graphql-native` from the Windows `EXCLUDES` (#568 already links #5877).

**Body (as opened; [file](../../bench/upstream/ruby_bench_round3/graphql-c-parser-body.md)):**

> graphql-c_parser doesn't compile on Windows with RubyInstaller (MinGW). There, `ruby.h` includes `windows.h`, which declares `FLOAT`, `INT` and `INPUT` as types, defines `INTERFACE` as a macro and declares `TokenType` as an enumerator. The extension uses these names for its token constants, so 1.1.4 fails with errors such as `lexer.rl:161:2: error: 'FLOAT' redeclared as different kind of symbol`.
>
> This adds `%define api.token.prefix {GRAPHQL_}` to `parser.y`, which renames only the generated C constants, so error messages such as `unexpected INT ("2")` stay the same. In the lexer, the four enumerators become `*_LITERAL`, like `TYPE_LITERAL`, and the enum becomes `GraphQLTokenType`. The emitted token symbols and numbers don't change.
>
> `parser.c` is regenerated with Bison 3.8.2. My Ragel 7.0.4 build formats `lexer.c` differently from the committed file, so I applied only the lines Ragel changes, with `#line` numbers updated.
>
> On Linux the test suite passes with and without `GRAPHQL_CPARSER=1`. On Windows, ruby-bench's graphql-native benchmark built from this branch compiles and runs on Ruby 4.0 and head: https://github.com/thomasklemm/ruby-bench/actions/runs/42034420178
>
> ---
>
> <sub>Found while enabling more benchmarks on Windows in ruby/ruby-bench#568, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/de05fe1376e714a2f1f30bc3c6de47fdd69b181c/docs/upstream/ruby-bench-improvements.md#round-3-rails-benchmarks-on-windows-2026-11-05), my research project.</sub>

## graphql-native on Windows: graphql-c_parser 1.2.0 in #568

rmosolgo merged rmosolgo/graphql-ruby#5877 (`aaae57a1eb`) and released graphql-c_parser 1.2.0 on 2026-11-05 15:56 UTC
("I just shipped this change in graphql-c_parser 1.2.0"); the coordinator reacted with 👍, no comment. Because #568 had
no review yet, the last exclusion went into #568 itself as a second commit rather than a new PR (coordinator's call).

**Change.** Commit `41c21df1ac` on `dd76311099`. In graphql-native's Gemfile.lock, `bundle _4.0.12_ lock --update
graphql-c_parser --conservative` moves graphql-c_parser from 1.1.3 to 1.2.0 (two lines; checksum `8120ef0a…` matches
rubygems.org). graphql stays at 2.5.11: 1.2.0 needs `graphql >= 2.2.10`, its `lib/graphql/c_parser.rb` is
byte-identical to 1.1.3's, and everything the extension looks up in graphql (`Lexer::VALID_STRING`, `BlockString`,
`ParseError`, the 35 node classes) exists in 2.5.11 with matching arities (reviewer). In the workflow,
`benchmark-default-windows` goes back to the plain `ruby run_benchmarks.rb` it had before k0kubun's 13e09f7
introduced `EXCLUDES`; nothing else reads `EXCLUDES`. Pushed without a rewrite (no force).

**Linux output.** For `negotiate.gql` (81 KB), 1.1.3 and 1.2.0 give identical token streams (5,262 tokens) and
identical AST dumps with positions (2,939 nodes, compared with object addresses stripped) and the same printed query.

**Cost** ([scripts and numbers](../../bench/upstream/ruby_bench_round3/graphql_c_parser_cost/)). Cachegrind, Ruby 4.0.9
interpreter, `RUBY_GC_HEAP_0..4_INIT_SLOTS` from [bench.md](../bench.md), 3 warmup iterations of 100 parses, then
(6 iterations − 1 iteration) / 5, two processes per version:

| | per iteration (Ir) | against 1.1.3 a |
| --- | ---: | ---: |
| 1.1.3 a | 2,604,134,169 | – |
| 1.1.3 b | 2,597,373,050 | −0.26% (A/A) |
| 1.2.0 a | 2,656,381,153 | +2.01% |
| 1.2.0 b | 2,656,375,983 | +2.01% |

**Claimed:** graphql-c_parser 1.2.0 runs 2.0–2.3% more interpreter instructions per graphql-native iteration than
1.1.3, outside the 0.26% A/A. Per function (cg_diff): `lexer.c:tokenize` +36.3M, `yyparse` +9.4M, lexer.rl/emit
lines +10M, `memcpy` −6.3M of +52M. The deltas are exact multiples of 100 parses, so they are deterministic. The cost comes
from the regenerated lexer and parser between 1.1.3 and 1.2.0: the Ragel character table widened for BOM handling,
`emit` checks number boundaries on every number token (ydah), Bison has 191 rules instead of 185, and 1.1.4 adds
`YYSTACK_USE_ALLOCA`. It does not come from #5877's renames, which keep every token number. The A/A gap is almost all
one `memcpy` item and GC timing (reviewer). It is not attributed to individual commits and not posted beyond the body
sentence; graphql-native's results shift by this on every platform. YJIT was not measured.

**Fork run** [42063514767](https://github.com/thomasklemm/ruby-bench/actions/runs/42063514767) on `41c21df1ac`
against the #567 copy (fork PR #8, closed without a comment): all 15 checks green. Both Windows jobs build
graphql-c_parser 1.2.0 from source and run graphql-native (288.9 ms on 4.0.9, 325.5 ms on head 4.1.0dev `64ae80dd36`)
next to erubi-rails, lobsters, railsbench and shipit. #568's own upstream run 42063486254 on the same head is green too.

**Review.** A skeptical subagent confirmed the lock and workflow changes and the measurement. Applied: the title
"Stop excluding benchmarks from the Windows CI job" instead of "Run all benchmarks on Windows" (ractor-harness
benchmarks don't run in that job anyway), a separate paragraph saying Linux results shift too, and that the cost is
not #5877's renames.

**PR state.** [ruby/ruby-bench#568](https://github.com/ruby/ruby-bench/pull/568), head `41c21df1ac`, two commits on
#567's. k0kubun merged #567 (`20cd3483c7`, 18:48 UTC) and then #568 (`0897d76aa2`, 18:49 UTC) on 2026-11-05, so no rebase was needed. With this, ruby-bench's Windows job excludes nothing.

**Body (as edited; [file](../../bench/upstream/ruby_bench_round3/windows-body.md)):**

> This builds on #567 and includes its commit until #567 merges; I'll rebase then.
>
> This runs erubi-rails, graphql-native, lobsters and railsbench in the `benchmark-default-windows` job, so it no longer excludes any benchmark.
>
> They were excluded because nokogiri 1.18.9 builds from source on Windows and its bundled libiconv fails to compile. #567 moved lobsters and railsbench to nokogiri 1.19.7, which installs on Windows with Ruby 4.0 (the precompiled x64-mingw-ucrt gem) and with head (built from source). erubi-rails gets the same bump here.
>
> lobsters was also excluded because stackprof fails to build. stackprof 0.2.28, the latest release, uses POSIX signals and timers that MinGW doesn't have. lobsters lists it only in its development group, which the benchmark doesn't load, so it now gets `platforms: :mri`, as in railsbench's Gemfile. Gemfile.lock doesn't change.
>
> graphql-native moves from graphql-c_parser 1.1.3 to 1.2.0 (released 2026-11-05), which includes rmosolgo/graphql-ruby#5877: it renames the C token names that clashed with Windows headers. graphql stays at 2.5.11.
>
> This also changes graphql-native on Linux. It returns the same tokens and AST for `negotiate.gql`, but runs about 2% more instructions per iteration (Cachegrind, Ruby 4.0.9 interpreter, fixed heap, two runs each; two runs of 1.1.3 differ by 0.3%). The extra instructions are in the C lexer and parser that 1.1.4 and 1.2.0 regenerated for their number, BOM and parser-stack changes, not in #5877's renames.
>
> In this run on my fork, both `benchmark-default-windows` jobs pass and run all four benchmarks: https://github.com/thomasklemm/ruby-bench/actions/runs/42063514767

## Follow-up: where graphql-native's 2% went

The +2.1% from graphql-c_parser 1.1.3 to 1.2.0 is almost all a679c9dff8 (BOM support, +1.66%). The pure-Ruby parser
got +24% more expensive between graphql 2.5.11 and master, almost all from one commit (2a8d95680b, +22.74%). Per-commit
tables, two exact candidate fixes and the rejected variants are in [graphql-ruby.md](graphql-ruby.md).

# Round 4: ANALYZE for the other database benchmarks (2026-11-05)

Thomas asked whether #565 should also run `ANALYZE` in the other benchmarks that use a database, as further commits in the
same PR. `ANALYZE` changes no query, only plans, and every benchmark it touches loses comparability with its
rubybench history, so each one needs its own gain. Rule: add it only if the plan change saves about 1% of an iteration
(time or Ir) beyond the A/A, or measurably narrows the run-to-run spread.

**Pins.** ruby-bench main `00f0f8b`, unchanged since round 2, so shipit was not re-run. Ruby 4.0.9 (mise build);
sqlite3 gem 2.7.3 (railsbench, activerecord) and 1.7.3 (sequel). Variants are `cp -a` copies of main (`base-a`, `base-b`)
and of main plus one `ANALYZE` line right after the data exists (`anlz-a`, `anlz-b`): railsbench after
`config/environment` (its `db:seed` runs in `use_gemfile`), activerecord after the inserts, sequel after the 10,000
creates.

| benchmark | `sqlite_stat1` after setup | statements per pass | plans changed | SQLite time per pass, before → after | Ir per iteration (A/A; ANALYZE a, b) | wall median, interp / YJIT (main → ANALYZE) | output |
| --- | --- | --- | --- | --- | --- | --- | --- |
| railsbench | no | 2 (1,970 `id = ?` lookups, 30 full scans) | 0 | 19.5 → 14.5 ms (other run 15.4 → 14.2) | 7.350 G (+0.13%; −0.15%, −0.01%) | 3,555 → 3,556 ms / 1,734 → 1,744 ms | 102 routes, all 200, bodies identical |
| activerecord | no | 2 (posts `ORDER BY id LIMIT`, comments `post_id IN (100 binds)`), 10 each | 0 | 25.5 → 27.6 ms (20.5 → 20.6) | 2.065 G (+0.26%; +0.12%, +0.07%) | 251 → 248 ms / 88 → 92 ms | rows identical |
| sequel | no | 1 shape (`id = N`, literals inlined), 1,000 | 0 | 2.39 → 2.60 ms (2.41 → 2.43) | 394 M (−1.28%; +1.87%, −1.00%) | 59 → 58 ms / 38 → 38 ms | rows identical |
| erubi-rails | – | no database: Active Record not loaded (`active_record/railtie` commented out, no `database.yml`), no SQLite file open | – | – | – | – | – |
| shipit (round 2) | no | 23 SELECTs, 4,275 | 6 (275 executions) | 1.13 → 0.99 ms for the six | – | – | identical |

Wall ranges over five interleaved rounds (5 warmup + 20 iterations, `setarch -R taskset -c 1`, one process at a time):
railsbench interpreter 3,492–3,597 vs 3,518–3,777 ms, YJIT 1,727–1,776 vs 1,705–1,797 ms; activerecord 247–259 vs
245–259 ms, YJIT 86–89 vs 88–93 ms; sequel 57–62 vs 55–61 ms, YJIT 37–39 vs 38–40 ms. No spread narrows; the only
outside-range moves (railsbench's 3,777 ms, activerecord YJIT +4.5%) go the wrong way and have no plan change behind
them.

**Why nothing changes.** railsbench, activerecord and sequel have no index besides the primary key
(activerecord's `comments.post_id` is unindexed), so SQLite has only rowid lookups and full scans to choose from.
The SQLite time differences come from timing repeated statements in one process (the two harness runs disagree in
sign), not from plans. railsbench's 5 ms would be 0.14% of an iteration even if real, and Ir doesn't show it.

**Verdict: no commits.** No benchmark meets the rule; #565 stays at `41985a9f3b`, one commit, and fork CI was not
needed. Its body got one paragraph (PATCH via REST, 18:29 UTC, no comment) so maintainers see why only lobsters
changes:

> The other database benchmarks don't get `ANALYZE`. In railsbench, activerecord and sequel it changes no query plan, since their tables have no index besides the primary key. In shipit it changes 6 of 23 plans, but saves under 0.02% of an iteration. erubi-rails doesn't load Active Record.

**Review.** A skeptical subagent checked every claim against code and data (no index, no plan change, erubi-rails,
shipit's 0.02%, harness coverage of Sequel's logger and IN-list binds, no other DB benchmark in the suite; rubocop
only mentions SQLite in fixture text) and found them true. Applied: its wording ("changes no query plan", split
sentences, "doesn't load Active Record").

**Receipts** in [`bench/upstream/ruby_bench_round4/`](../../bench/upstream/ruby_bench_round4/):
[`db_plans_harness.rb`](../../bench/upstream/ruby_bench_round4/db_plans_harness.rb) (round 2's plans harness plus
Sequel, response hashes, row identity), `plans-*.txt`/`.json`, [`ir.rb`](../../bench/upstream/ruby_bench_round4/ir.rb)
and `ir-summary.md` (cachegrind, fixed heap from [bench.md](../bench.md), (4 − 1 iterations) / 3 after 2 warmups),
[`wall.sh`](../../bench/upstream/ruby_bench_round4/wall.sh) with `wall-results.txt` and `wall-summary.txt`, and the
body before and after.

# Round 4: determinism (2026-11-05)

**Question (Thomas).** Does ruby-bench measure only Ruby execution, or also work that changes from process to process
or from run to run? Out of scope: ASLR, CPU pinning and turbo (already handled by the runner), `ANALYZE` (the
section above), warmup and JIT compilation (decided against), and the lobsters `/reply` countdown (output only).

**Method.** [`audit.rb`](../../bench/upstream/ruby_bench_round4/audit.rb) runs the default harness under Cachegrind
on Ruby 4.0.9 with the fixed heap from [bench.md](../bench.md), with
[`cg_harness.rb`](../../bench/upstream/ruby_bench_round4/cg_harness.rb) dumping Ir and `GC.stat` per iteration. Two
processes per benchmark, each in its own `git worktree` copy (so they share no `tmp/`, logs or databases), 5 warmup
and 5 measured iterations. Process A/A is the difference between the two processes' mean Ir per measured iteration;
max-itr is the largest single-iteration difference within a process. A deterministic benchmark gives a small A/A.

## Process A/A (ruby-bench `00f0f8b`, interpreter)

34 benchmarks finished, including every headline and Rails benchmark; the rest of the sweep (the remaining
`other` and micro benchmarks) was still running when this round closed, so no claim is made for them.

| A/A | benchmarks |
|---|---|
| ≤ 0.01% | addressable-merge, addressable-parse, addressable-setters, addressable-join, binarytrees, blurhash, chunky-png, fannkuchredux, gcbench, graphql, liquid-c, matmul, railsbench |
| 0.01–0.08% | activerecord 0.023, addressable-* 0.016–0.070, erubi 0.058, erubi-rails 0.076, hexapdf 0.027, liquid-compile/il/render 0.028–0.036, lobsters 0.048, mail 0.022, rubocop 0.024, ruby-lsp 0.023, sequel 0.080, shipit 0.031 |
| > 0.1% | **etanni 0.199%**, **psych-load 0.188%**, grape 0.103% |

Allocation and GC counts are identical across processes in all three outliers. etanni with
[`fixrand`](../../bench/upstream/ruby_bench_round4/fixrand/fixrand.c) (an `LD_PRELOAD` that returns a fixed
`getrandom` seed, so the hash seed and `Random::DEFAULT` seed are the same in each process) has A/A 0.0000% (Ir
3.876e9), and so has psych-load (Ir 1.741e10), so their spread is the per-process hash seed changing hash-table
probe lengths. grape (0.103%, at the threshold) looks the same but was not rerun. Recorded, not fixed: a per-process
hash seed is a property of Ruby, and fixing it in the benchmark would hide a real cost.

**In-process iteration spread** (max-itr): erubi 3.7%, sequel 2.5%, hexapdf 0.96%, lobsters 0.57%. Their A/A is
≤ 0.08%, so iterations differ the same way in every process (GC timing over a fixed heap). Record-only.

## Leads checked

- **Unseeded randomness (ruled out).** `lib/harness.rb:16` already runs `Random.srand(1337)` before every benchmark,
  so `rand`, `sample`, `shuffle` and `Random.alphanumeric` in activerecord, json_parse_float, fluentd, sequel,
  rubykon, optcarrot and lobsters give the same sequence in every process. Control: rubykon with an extra
  [`seed.rb`](../../bench/upstream/ruby_bench_round4/seed.rb) preload, A/A 0.0086% → 0.0075%, allocations
  identical. `SecureRandom` (lobsters session ids and CSRF tokens) stays random; it changes bytes, not work.
- **Wall-clock date (one real problem: lobsters).** With libfaketime at five dates (2026-11-05, 2026-12-25,
  2027-06-28, 2027-11-05, 2031-11-05), activerecord, erubi-rails, railsbench, shipit, sequel, mail and fluentd
  allocate exactly the same per iteration. lobsters does not: 648,912–657,811 objects per iteration across four
  dates, a 1.37% spread. Cause, measured with [`dst_probe.rb`](../../bench/upstream/ruby_bench_round4/dst_probe.rb):
  lobsters runs in US Central time, and when a lookback such as `70.days.ago` crosses a DST change,
  `TimeWithZone` refetches the tzinfo period (1,476 refetches per pass on 2026-11-05, 285 on 2027-01-20, 0 in
  July). On Dec 25 and Jun 28 a holiday logo also renders. Callgrind: main 3.775e9 Ir on 2026-11-05 vs 3.759e9 on
  2027-06-28.
- **Per-process hash seed.** See etanni above; recorded, not fixed.
- **GC state across iterations, files written during iterations, ENV/locale/TZ.** Not traced one by one: the
  Rails benchmarks log to STDOUT at `:error`, the caches are `:memory_store` since #564, lobsters and shipit use
  `:memory:` databases (railsbench a file database, A/A 0.0035%), and the A/A table shows no outlier beyond the
  three above, and those three allocate and collect identically in every process.

## The PRs (two alternatives for lobsters)

Both fix `Time.now` during boot and inside the benchmark block (the harness keeps the real clock, including
`HARNESS=chain`), release it in `ensure`, and move `TRACK_AR_TIME` to the monotonic clock. `travel_to` was rejected:
its stubs add about 7.3K objects per pass.

- [ruby/ruby-bench#571](https://github.com/ruby/ruby-bench/pull/571), branch `thomasklemm/lobsters-fixed-clock`,
  head `33e9aa45be` on main `ad63bf8`: clock at 2026-07-01 12:00 UTC. Allocations across the four dates
  648,872–648,916 (spread 0.007%, main 1.37%); responses byte-identical after blanking random fields; 0 refetches.
  Callgrind Ir per iteration with the real clock: 3.638e9 vs main 3.658e9 (−0.55%, both A/A ≤ 0.008%). History
  step: up to −1.35% objects. Marked ready 2026-11-05 21:08 UTC with upstream CI green (15/15) on that head. [Body](../../bench/upstream/ruby_bench_round4/lobsters-fixed-clock-body.md).
- [ruby/ruby-bench#572](https://github.com/ruby/ruby-bench/pull/572), branch `thomasklemm/lobsters-clock-near-fixture`,
  head `f94d3a10df`: clock at 2023-07-19 01:00 UTC, next to the 2023 fixture, so the 16 time-filtered requests
  render 25 stories each; `/top` binds `Time.current` and uses `-N DAY` (on main `'- 1 DAY'` is NULL, so `/top`
  was always empty). Date spread 0.003%. Deliberate workload change: +44% objects against main; Callgrind with the
  real clock 5.989e9 Ir per iteration (+64% against main, A/A 0.008%). Marked ready 2026-11-05 21:04 UTC with
  upstream CI green (15/15) on that head.

Callgrind under libfaketime can't show the date effect: libfaketime adds its own Ir and noise (A/A 0.06–0.41%), and
main and #571 both spread about 0.4–0.5% in Ir across 2026-11-05, 2026-12-25 and 2027-06-28 (main 3.759–3.778e9,
#571 3.768–3.783e9). Allocation counts are the date evidence; the real-clock Callgrind runs are the cost evidence.
  [Body](../../bench/upstream/ruby_bench_round4/lobsters-clock-near-fixture-body.md).

Both bodies say lobsters' rubybench history takes a step. Reviews: four skeptic passes and four Sol passes (the
coordinator's) across heads `300f401d18` → `1e5933cc08` → `b63e9d89b1` → `33e9aa45be` / `f94d3a10df`; findings
fixed on the way: `travel_to` overhead, broken `TRACK_AR_TIME`, frozen file names under `HARNESS=chain`, a boot
exception leaving the clock frozen, and body overclaims. Final passes: Sol approve on both heads, skeptic nits only
(body length and rounding, not applied). Fork CI was dropped for this round (Lowrail `184a6f5`); upstream CI is the
gate. Pass records: [RB571](../../bench/upstream/pr-queue/items/RB571.md),
[RB572](../../bench/upstream/pr-queue/items/RB572.md).

**Receipts** in [`bench/upstream/ruby_bench_round4/`](../../bench/upstream/ruby_bench_round4/): `audit.rb`,
`cg_harness.rb`, `seed.rb`, `freeze.rb`, `fixrand/`, `dst_probe.rb`, `raw_dump.rb`/`raw_cmp.rb` (response
comparison), `route_dump.rb`/`route_table.rb` (per-request counts), and the two bodies.

# Round 5: significance across processes (2026-11-06)

**Question (Thomas).** Fix [rank 1](#1-significance-stars-treat-iterations-of-one-process-as-independent-samples) as a small PR:
`--pvalue` and its stars test the iterations of one process per Ruby, so identical builds get `*`–`***`.

**Upstream state, rechecked.** #479 (eightbitraptor) added Welch's t-test; in its discussion k0kubun asked to keep the
table narrow, and jhawthorn called significance "one of the most important numbers"; #492 gated the stars behind
`--pvalue`. No issue or PR raises per-process variance or repeated processes. Open PRs don't overlap: #562 (XrXr,
GC time in zjit_diff), #354 and #533 (rwstauner, machine tuning), #541 (eightbitraptor, GC tables), #573
(tekknolagi, side exits). Nothing since #479 changes how runs or stats work. No rejection, nobody working on it.

## A/A on main `ad63bf8`

Ruby 4.0.9 (YJIT and interpreter; this orb has no ZJIT build), 4-vCPU VM, `--no-sudo --interleave --pvalue`, ten
identical executables per invocation, default iterations. "All pairs": main's single-process test on every pair of
processes. "--runs 5": Welch over per-process means, 200 random 5-against-5 splits of the same ten processes
(correlated resamples).

| bench | process-mean CV | median in-process stddev | main: all pairs starred | per-process means, 5 v 5 |
|---|---:|---:|---:|---:|
| fib interp / yjit | 2.80% / 1.88% | 2.2% / 9.7% | 60% / 44% | 7% / 5% |
| lobsters interp / yjit | 4.87% / 6.45% | 4.3% / 5.9% | 47% / 49% | 4% / 2% |
| railsbench interp / yjit | 3.52% / 3.02% | 4.8% / 3.6% | 18% / 51% | 2% / 8% |
| respond_to interp / yjit | 2.21% / 1.28% | 5.1% / 17.6% | 36% / 47% | 5% / 9% |
| str_concat interp / yjit | 1.53% / 1.96% | 6.6% / 7.4% | 49% / 76% | 4% / 1% |
| all | | | 214 / 450 (48%) | 92–103 / 2,000 (≈5%) |

## The fix

[`thomasklemm/pvalue-across-processes`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/pvalue-across-processes),
head `b633985a3d` on main `ad63bf8`, one commit (+297/−26, of which tests +171). `--runs N` runs each benchmark in N
processes per Ruby through the existing `--interleave` loop, flipping the Ruby order every round;
`BenchmarkRunner.merge_runs` concatenates the per-iteration series and records `warmup_itrs_per_run` and
`bench_itrs_per_run`; the table splits them back and runs the existing `Stats.welch_p_value` on the N process
means (timing and GC ratio columns). With one process the p-value is N/A and `--pvalue` warns. 1st itr averages
each process's first iteration. `--runs` refuses the Ractor harness (its per-count Hashes aren't merged).

**Why this shape.** Process means are the independent unit; Welch on them reuses the existing stats code and needs
no dependency. A nested model would add little at N = 3–10 and more code. The Roundhouse paired protocol (median
pairwise ratio, Tukey trimming, bootstrap interval, tolerance verdict) is sounder for gating but is a new statistic
and a new output, far beyond a fix to an existing column; the interleaved, order-flipped rounds are the part of it
that fits and are kept. **Default unchanged** (one process): `--runs N` costs N× wall time, and rubybench and
`tool/zjit_diff.rb` would get slower without asking. Instead the single-process stars go away, because 48–60%
false positives on identical builds are not a usable signal; zjit_diff users get N/A plus a warning until they pass
`--bench-args --runs=N`.

**After, end to end on the branch.** Four identical YJIT Rubies, `--runs 5`, five benchmarks: 2 of 30 comparisons at
p < 0.05 (fib A–C 0.018, lobsters B–D 0.026); main's test on the same 100 processes: 566 of 950 pairs (60%).

**Real differences (A/B, `--runs 5`, against YJIT).** Interpreter `***` on railsbench (p 7e-9), fib, str_concat. A
preloaded spin loop ([`slow.rb`](../../bench/upstream/ruby_bench_pvalue/slow.rb), nominal 2% and 5%) measured
extra time per iteration fib 1.9% / 6.6% (p 0.12 / 4e-5 `***`), str_concat 7.1% / 11.4% (`*` / `**`), railsbench 1.6% / 1.9% (p 0.44 /
0.31, not detected: railsbench processes vary ~3% here).

**Wall time.** Linear in N: the branch A/A ran 100 processes in 2,156 s, against ~430 s for one process each; the
A/B (3 benchmarks × 4 Rubies × 5) took 1,531 s.

**Review.** Claude Code skeptic subagent, three passes: `b1da15b` changes (body overstated the railsbench slowdown;
new behaviour untested; 1st itr from the first process only; Ractor reason), `cca922aa81` nits, `aed07e8d8f`
approve. Kept: the displayed ratio is the pooled mean while the test uses unweighted process means (≤0.1% here);
odd N lets one Ruby go first once more per benchmark. Fork CI: `test.yml` runs only on `main` and PRs, so the same
tree was pushed with a one-line trigger as `ci/pvalue-across-processes` (`5e7f158`): all 15 jobs green, run 42242520205; the branch was deleted after. Item:
[RB-PV](../../bench/upstream/pr-queue/items/RB-PV.md), state reviewed, not opened.

**Final independent pass (Claude Code Thermos, correctness + maintainability, on `aed07e8d8f`): nits, fixed as
`b633985a3d`.** With `--runs`, every benchmark got a GC row, because the run sizes counted as GC activity; now left
out. The tests let a p-value over raw iterations, dropped GC run sizes and an even split pass; a new asymmetric test
(process means checked against scipy) catches all three, and the Ractor refusal test checks its message. The body's
slowdowns now state extra time (they were 1 − ratio). Checked and correct: Welch on N = 2 and unequal N (matches
scipy), zero variance, missing run data (N/A), a failed run (the whole Ruby is dropped), N = 1 output and order
unchanged, 1st itr, Ractor refusal (`bench_by_ractors` would keep process 1 only), every number in the commit
message (103 = 49 + 54 per mode). Kept: pooled ratio vs process-mean test; odd N balanced across the suite only;
scalars from process 1. Fork CI on the same tree (`f961b53`, run 42249192428): 15/15 green, branch deleted.

**Receipts** in [`bench/upstream/ruby_bench_pvalue/`](../../bench/upstream/ruby_bench_pvalue/): `collect.sh`
(main A/A), `collect2.sh` (branch A/B and A/A), `analyze.rb` (`RUBY_BENCH=<checkout> ruby analyze.rb 5 <(zcat
data/aa_yjit_rep1.json.gz)`), `slow.rb`, `data/` (JSON gzipped, tables), `commit-message.txt`, `pr-body.md`.

# Round 6: a write benchmark, `blog` (2026-11-06)

**Question (Thomas, via the coordinator).** Section 7 found that every Rails benchmark in ruby-bench only reads. Build
a write workload as a new benchmark, so existing histories don't move, and prepare it as a draft PR. Upstream
search first: no issue or PR in ruby/ruby-bench proposes or rejects a write benchmark; the nearest are lobsters'
route-generator comment ("POSTs are harder here … For now, skip it") and noahgibbs in #245 ("If we ever *do* expand to
more of the full life cycle (add more POSTs, create and delete stories and comments, etc.)…").

**Why not lobsters.** The first prototype reused lobsters' app, fixture and login; Thomas stopped it in favour of a
current `rails new` app. What it found:
- Its writes depend on the date twice: lobsters needs #571's fixed clock, and the 2023 fixture is older than the
  time windows (`Story#accepting_comments?` is 90 days, the comment rate limit is 5 minutes per parent).
- Short IDs come from `OpenSSL::Random` (`extras/utils.rb`), unseeded, so `ShortId` collision checks and the
  generated URLs differ per run.
- `Rails.cache` (MemoryStore since #564) survives a rollback and would need clearing per iteration. `Keystore`
  counters, which were suspected too, are a database table (`keystores`), so a rollback covers them.
- Per-form CSRF tokens are on, so the login form's token (the one `RouteGenerator` keeps) fails on other forms.
- Mentions and replies send mail over SMTP (`delivery_method :smtp`), which the benchmark would have to switch to
  `:test`; and the XHR comment create rendered a 500 (missing `_postedreply` for the form's format) until the request
  sent an HTML `Accept`.

**The benchmark.** Branch [`thomasklemm/blog-benchmark`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/blog-benchmark),
head `65151273f6` (after the claude-code pass; `950a2bc27d` before), one commit on ruby-bench main `ad63bf8`. The app is Sam Ruby's
[create-blog](https://github.com/roundhouse-rb/roundhouse/blob/aa60799f53b36084c6311ffcda8f14e746eebf79/scripts/create-blog)
(MIT or Apache-2.0, used under MIT, license kept), generated once with `RAILS_NEW_VERSION=8.1.4.1`. Changes to the generated tree, all listed in
its README: credentials, `.github`, `.ruby-version` and `image_processing` removed (libvips loaded at boot on hosts that
have it, 5 `VIPS-WARNING` lines on Windows CI), `config.yjit = false`, built `tailwind.css` checked in (no Tailwind
binary needed, so Windows works), lockfile platforms `ruby` and `x86_64-linux`.
- 200 seeded visits per iteration, about 417 Rack requests: GET html 279, POST 83, DELETE 19, PATCH 14, GET json 22.
  Time share: 61% GET html, 35% form submissions. Writes take the CSRF token from the page's form; a create with an
  empty title returns 422; every response's status and a body marker or `Location` are checked.
- Rollback: `pin_connection!(false)` on all four writing pools (primary, cable, queue, cache), `unpin_connection!` at
  the end. Saves are savepoints, after-commit callbacks run on RELEASE (the outer transaction is not joinable), as in
  Rails tests.
- Broadcasts: real Turbo rendering. Solid Cable's batching writer thread is replaced with the gem's own synchronous
  `SolidCable::Message.broadcast`, so the insert lands in the transaction and doesn't depend on thread timing. The
  `*_later` broadcasts are Solid Queue inserts. Every iteration asserts 117 Cable messages and 82 new jobs.
- Clock: `Time.now` fixed at 2026-07-01 12:00 UTC during boot and the iteration, as in #571.

**Evidence** (Ruby 4.0.9 unless noted; scripts in [`bench/upstream/ruby_bench_blog/`](../../bench/upstream/ruby_bench_blog/)):
- **Rollback:** [`rollback_check.rb`](../../bench/upstream/ruby_bench_blog/rollback_check.rb), 30 iterations (25 on
  the final head): row counts, max id and `sqlite_sequence` of every table in all four databases equal before and
  after every iteration and equal to the start; inside each iteration, before the rollback, 14 values had changed
  (articles 3→12 rows, max id 27; comments 3→18, max id 47; 117 Cable messages; Solid Queue jobs 6→88).
- **Determinism:** allocations per iteration over 30 measured iterations, fixed heap
  ([`alloc_summary.rb`](../../bench/upstream/ruby_bench_blog/alloc_summary.rb)): means 1,061,042–1,061,084 at four
  libfaketime dates (2026-11-06, 2026-12-25, 2027-03-20, 2027-06-28; 0.004% apart), spread within a run
  0.048–0.076%, first ten vs last ten iterations equal within 0.01% (no growth). With every random byte fixed
  ([`fixed_bytes.rb`](../../bench/upstream/ruby_bench_blog/fixed_bytes.rb)) the spread stays (1,057,237–1,057,478),
  so it is not session or token bytes; cause not traced. Callgrind (round 4's `audit.rb`, 3 warmup, 25 measured,
  2 processes): 4.299e9 Ir per iteration, process A/A 0.035%, within-process spread 2.9% (lobsters, same method, 10
  iterations: 3.673e9, A/A 0.005%, within 4.5%).
- **Stability:** `./run_benchmarks.rb --interleave` with two copies of each of interp, YJIT and ZJIT (Ruby master
  `0236df4`), two rounds. A/A: blog 1.28/0.03/0.95% and 5.72/4.88/3.67%, lobsters 5.15/3.52/11.48% and
  3.79/6.91/0.75% (round 2 ran alongside the reviewer's runs). Iteration means, round 1: blog 1,537 / 920 / 995 ms,
  lobsters 1,127 / 662 / 750 ms; railsbench 2,963 ms and shipit 2,300 ms on the interpreter.
- **Distinctness:** StackProf, 5 iterations after 3 warmup ([`prof.rb`](../../bench/upstream/ruby_bench_blog/prof.rb),
  [`prof_report.rb`](../../bench/upstream/ruby_bench_blog/prof_report.rb), inclusive): blog 18.4% in
  save/destroy/transaction frames, 17.4% commit/save callbacks, 13.6% Turbo broadcasts, 7.8% Solid Queue enqueue,
  6.5% INSERT/UPDATE/DELETE; lobsters 0.2% and railsbench 0.0% in any write path. View rendering: 41 / 46 / 26%.
- **Harnesses:** default, once, gc, stats, perf, chain (gc,once), stackprof and vernier finish for blog as for
  lobsters; warmup, continuous and mplr run until stopped, like lobsters; bips fails for every benchmark
  (`benchmark-ips` not installed). Fork CI: [thomasklemm/ruby-bench#16](https://github.com/thomasklemm/ruby-bench/pull/16)
  (fork-internal, CI only): 15/15 green on `950a2bc27d` (run 42239521787), including both Windows jobs and TruffleRuby; on `7277a4bced` Windows ruby took 1,627 ms per iteration and TruffleRuby 7.7 s.

**Overlap with railsbench.** Both are SQLite scaffold apps rendering HTML and JSON, but railsbench is GET-only on an
older Sprockets tree without Turbo or Solid. blog adds what railsbench never runs: forms with CSRF, strong
parameters, validations including a 422 re-render, savepoints and after-commit callbacks, `dependent: :destroy`,
Turbo stream rendering, Solid Cable and Solid Queue inserts, flash and redirects, and the 8.1 defaults (Propshaft,
importmap, `allow_browser`). Their reads overlap; a maintainer could see blog's GETs as railsbench-like.

**What it leaves out.** No real COMMIT/WAL write; no job runs (the queue only fills); Solid Cache is unused by the
app; generator leftovers (kamal, thruster, dev and test gems) are kept as generated. Fresh `bundle install` on Ruby
4.0.9 (4 vCPU): 34.3 s as generated, 28.6 s without them (38 fewer gems, 4 fewer small C extensions:
`bcrypt_pbkdf`, `ed25519`, `bindex`, `debug`). The earlier "about 70 s" was Ruby head compiling `sqlite3` (85 s) and
`nokogiri` (70 s), which production needs; trimming would not remove it.

**Reviews.** Skeptic pass 1 on `7277a4bced`: changes (commit message said lobsters never writes, gave a reason for
skipping POSTs it doesn't give, and said lobsters has a fixed clock on main; `image_processing` host-dependence; dead
code; README gaps). All applied in `950a2bc27d`. Skeptic pass 2 on `950a2bc27d`: nits, all on the body (WAL write rather
than fsync, lobsters' own A/A next to the table, savepoint wording), applied; it rechecked every number in the body
against the result files. Not applied: "in the timed iteration" in the commit message (lobsters' login POST runs at
setup). The evidence runs used the tree before `image_processing` was dropped; the timed work is unchanged, boot RSS
fell from 157 to 127 MiB. Queue item: [RBW1](../../bench/upstream/pr-queue/items/RBW1.md).
Claude Code pass on `950a2bc27d` (thermos: correctness and maintainability subagents plus own probes): two
should-fixes confirmed and fixed in `65151273f6`. The fixed clock made 13 of 14 article UPDATEs skip `updated_at`
(same timestamp); it now advances one second per visit (14/14 write it, allocations +0.1%). Bootsnap's iseq cache in
`tmp/` is keyed on `RUBY_DESCRIPTION`, so two builds of one revision would share bytecode; `benchmark.rb` sets
`DISABLE_BOOTSNAP` (railsbench also has bootsnap off). Commit message now says "in their timed iterations"; README
notes the dual license, the clock, bootsnap and non-precompiled assets (Propshaft resolver, about 0.7% of
allocations). Body: the A/A clause ("within 1%" for blog, record 1.28%) and the Callgrind and four-date sentence are
cut, the clock sentence updated. Rechecked on `65151273f6`, Ruby 4.0.9: 15 iterations restore every table in all four
databases, the four files are byte-identical after the run, allocations 1.063M per iteration within 0.05%. The
table's times are from `950a2bc27d`. Skeptic and Sol have not run on `65151273f6`.
Body: [blog-body.md](../../bench/upstream/ruby_bench_blog/blog-body.md).

# Round 7: what `blog` finds that railsbench and lobsters miss (2026-11-06)

Measured on `65151273f6` plus three experiment-only commits; tables and caveats in
[ruby-bench-blog-findings.md](ruby-bench-blog-findings.md). In short: blog's totals move like the others', but its
per-request split shows Rails main's 8–12% gain is a read gain (create paths flat, +11% Active Record calls per
write); a 2% save-path slowdown is +2.3% Ir in blog and invisible to railsbench and lobsters (no saves in their timed
iterations); per-query and driver changes (PM1b, sqlite3 #769/#770) show the same size or smaller in blog; no JIT gap
on writes. Rails main's `pin_connection!` no longer opens a transaction (9e8fe3955b), so blog at `65151273f6` does
not roll back on Rails 8.2.
