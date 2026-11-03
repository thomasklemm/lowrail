# ruby-bench: what is worth contributing upstream (2026-11-03)

[ruby/ruby-bench](https://github.com/ruby/ruby-bench) gives the Ruby and ZJIT teams their headline numbers, and it
is our source of truth for ZJIT speed claims ([DECISIONS](../DECISIONS.md#evidence-and-measurement)). This page
checks the pain points recorded in our docs, looks for gaps in the suite, and ranks candidate improvements by their
value to the maintainers. It is an evaluation only. Nothing was built upstream, and nothing was opened or posted.

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
not in 8.1.x; erubi-rails' move to 8.1 is the same routine bump the maintainers did for the others.

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
