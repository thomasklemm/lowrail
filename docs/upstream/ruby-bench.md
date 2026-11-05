# ruby-bench: what it is, what we did there, why it matters to Lowrail

Overview of our work around [ruby/ruby-bench](https://github.com/ruby/ruby-bench). The per-round evidence (numbers,
logs, reviews, PR bodies as opened) is in [ruby-bench-improvements.md](ruby-bench-improvements.md); this page links
to it instead of repeating it. Status as of 2026-11-05.

## How ruby-bench and rubybench work

* **ruby/ruby-bench** (formerly yjit-bench) is the Ruby core and JIT teams' benchmark suite: about 80 benchmarks
  from micro (fib, nbody) to apps with vendored, locked Gemfiles: railsbench (a Rails scaffold), lobsters (114
  logged-in GETs on a copy of lobste.rs), shipit (Shopify's deploy tool, HTML and JSON), erubi-rails,
  activerecord, graphql-native, fluentd, rubocop and others. `benchmarks.yml` lists them with category and
  harness.
* `./run_benchmarks.rb -e name::ruby …` runs each benchmark in its own process per Ruby (pinned with
  `setarch -R` and `taskset`, turbo off unless `--turbo`/`--no-sudo`). The default harness runs 15 warmup
  iterations, then at least 10 iterations and 10 seconds, and reports the mean of the measured iterations, ratios
  between Rubies and (since #479) p-values. Other harnesses swap the loop: `gc` (per-iteration GC stats), `ractor`,
  `perf`, `stats`, `once` and more. `YJIT_BENCH_STATS`/`ZJIT_BENCH_STATS` record JIT counters per iteration.
  `misc/zjit_diff.rb` compares two builds' results and ZJIT stats; ruby/ruby's `tool/zjit_diff.rb` drives it.
* Its CI (`Test benchmarks`) runs every benchmark once on Ruby 4.0, head and TruffleRuby on Linux, on 4.0 and head
  on Windows, plus the ractor categories. Before #568, the Windows job excluded erubi-rails, graphql-native,
  lobsters and railsbench.
* **[rubybench/rubybench](https://github.com/rubybench/rubybench)** is the daily runner behind the published
  numbers: it runs ruby-bench on Ruby master with the interpreter, YJIT and ZJIT (JIT runs with `--warmup=30` since
  rubybench/rubybench#30) and publishes the history, which the Ruby and Rails maintainers read for trend lines
  and regressions. It runs `git clean -dfx` only after all three configurations.

## What we have done

| when | what | state | record |
| --- | --- | --- | --- |
| 2026-11-03 | Round 1: evaluated the suite against our pain points, ranked eight candidates | two picked, the rest recorded | [round 1](ruby-bench-improvements.md#recommendation) |
| 2026-11-04 | [#564](https://github.com/ruby/ruby-bench/pull/564): lobsters and shipit keep `Rails.cache` in memory instead of `tmp/cache` (concurrent runs crashed, iteration 1 depended on the previous run) | **merged** 2026-11-05 by k0kubun | [section 2](ruby-bench-improvements.md#2-lobsters-and-shipit-keep-their-rails-cache-on-disk-in-tmpcache) |
| 2026-11-05 | [#565](https://github.com/ruby/ruby-bench/pull/565): `ANALYZE` on lobsters' in-memory DB, for rubys' issue #527 (hottest query 10.8 → 0.08 ms) | open; B1 may add commits | [ledger](contributions.md) |
| 2026-11-05 | Round 2: five topics. [#566](https://github.com/ruby/ruby-bench/pull/566) shipit nokogiri 1.19.7 (main's Windows head job red since 2026-10-30); [#567](https://github.com/ruby/ruby-bench/pull/567) Rails 8.1.4.1 for four benchmarks | both open, CI green | [round 2](ruby-bench-improvements.md#round-2-five-topics-checked-and-the-prs-opened-2026-11-05) |
| 2026-11-05 | Round 3: [#568](https://github.com/ruby/ruby-bench/pull/568) runs every benchmark on Windows (stacked on #567); needed [rmosolgo/graphql-ruby#5877](https://github.com/rmosolgo/graphql-ruby/pull/5877), merged and released as graphql-c_parser 1.2.0 the same day | #568 open, CI green | [round 3](ruby-bench-improvements.md#round-3-rails-benchmarks-on-windows-2026-11-05) |
| 2026-11-05 | Round 4: determinism audit, Callgrind instructions per iteration across processes for every benchmark | in progress (its own thread) | to be added to the record |
| 2026-11-05 | Round 4 follow-up: lobsters' 1.35% more work near a DST change is Active Support's `TimeWithZone` looking the same local time up in tzinfo twice; exact two-line fix on a fork branch (657.9K → 648.9K objects on 2026-11-05) | fix on `thomasklemm/twz-reuse-local-period`, nothing opened | [DST record](ruby-bench-dst.md) |
| 2026-11-05 | Others' open PRs triaged; fixes verified and notes drafted for #562 and #539 | drafts only, nothing posted | [ruby_bench_others](../../bench/upstream/ruby_bench_others/README.md) |
| – | How ruby-bench should measure GC cost (prompted by tekknolagi on our closed ruby/ruby#19685) | owned by G2 | G2's record (planned under `bench/upstream/ruby_bench_gc/`) |

**Decisions along the way.**

* Significance-star issue (round 1, rank 1: one process per Ruby, so identical builds get stars): **not opened**
  (DECISIONS: small reviewed PRs over issue discussions); evidence kept.
* Warmup issue (round 2, topic 2: YJIT and ZJIT still compile in the measured window): **drafted, not opened**. The
  compile share left is under 1%, rubybench already uses 30 warmups, YJIT is in maintenance mode, and new issues
  need Thomas's OK.
* shipit `ANALYZE`, lobsters `/reply` counters, lobsters' expired time windows, a Rails-main variant, write
  workloads, a Callgrind harness, ZJIT stats windowing: recorded, **no PR** (gain too small, workload change, or the
  maintainers' design call).
* ruby/ruby-bench PRs may open side by side (Thomas, 2026-11-05), unlike other gems' two-PR cap. #568 opened
  before #567 merged and says so in its first sentence; it is rebased once #567 lands.
* No fork CI for ruby-bench any more (Thomas, 2026-11-05): ruby/ruby-bench runs our PRs' workflows without approval
  since our first merges, so a PR opens upstream as a **draft** once local measurements and the first review are done,
  and is marked ready after the last review pass and green CI there. Earlier fork-internal PRs against `ci-base/*`
  were closed without comments.
* No comments on others' PRs without Thomas's OK; nobu's #461 overlaps our lockfiles and is not mentioned in our
  bodies.

## Open PRs by others

Full table, diagnoses and drafts: [ruby_bench_others](../../bench/upstream/ruby_bench_others/README.md).

| PR | what | recommendation |
| --- | --- | --- |
| #562 XrXr, zjit_diff with GC time removed | CI red from its WIP commit (`RubyVM::ZJIT.stats` nil or missing); 4-line fix verified on 4.0.9 and master, with and without ZJIT | [draft note](../../bench/upstream/ruby_bench_others/pr562-note.md), Thomas decides |
| #539 luke-gruber, gc_balloon | approved but red: `GC.start(global:)` is 4.1-only; on today's main also the renamed harness paths | [draft note](../../bench/upstream/ruby_bench_others/pr539-note.md), Thomas decides |
| #461 nobu, forked dependencies | mostly landed on main already; conflicts regardless of our PRs | no action |
| #354, #533 rwstauner, CPU isolation | `--no-sudo` landed as #474; nice, cpusets, SMT still open; irrelevant to instruction counts | no action |
| #541 eightbitraptor, GC per-ruby table | README conflict only | no action |
| #467 luke-gruber, thread category | waits on a maintainer design call | no action |

## How this feeds back into Lowrail and the community

**What Lowrail relies on.** Lowrail's own speed claims (AGENTS.md invariant 4) are `lowrail bench` runs on apps
against the same app without Lowrail ([bench.md](../bench.md)), not ruby-bench. Our upstream work does rely on it:
DECISIONS ("Where claims come from") makes ruby-bench with A/A the source of ZJIT speed claims, every rails/rails
and ruby/ruby body states its railsbench, lobsters and shipit effect, and ruby/ruby PRs need a measurable
ruby-bench effect. Our Callgrind runs ([`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb))
and JIT-stats harnesses run those three benchmarks locally. So a flaw in them is a flaw in our evidence.

**Determinism.** An A/A only means something if two processes do the same work. #564 removed the cross-run cache
state and the concurrent-run crash we hit when running benchmarks side by side, and #565 runs `ANALYZE` after
lobsters restores its in-memory database, so its hottest query takes 0.08 ms instead of 10.8 ms. Round 4 checks
every benchmark for work that differs between processes. For
maintainers reading rubybench, the same fixes make a step in the trend line mean a change in Ruby, not in the
benchmark; #564's body says lobsters' score moved by about 2% once, and why.

**Current pins.** Rails 8.1.4.1 (#567) and nokogiri 1.19.7 (#566) keep the Rails benchmarks on what apps run today
and building on Ruby head. Our Rails PRs are measured on these benchmarks, so a pin far behind Rails 8.1's patch
line measures code users no longer run; #567 itself costs 0.8–1.5% interpreter instructions, which we recorded
rather than hid.

**Windows coverage.** #568 makes the Windows job run every benchmark. Before it, a Windows-only failure in the Rails
benchmarks or graphql-c_parser was invisible: the graphql-c_parser build failure on MinGW became
rmosolgo/graphql-ruby#5877 and a release, and #566 came from Ruby head's 64-bit `rb_len_t` on Windows breaking
nokogiri. RubyInstaller and gem maintainers get that signal from ruby-bench's CI before users hit it.

**Diagnoses others can use.** Where others' PRs are blocked by something we can verify (#562, #539), we prepare
the fix and a short note, and Thomas decides whether to post it. The GC-time findings from #562 also feed G2's GC
measurement work.
