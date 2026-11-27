# ZJIT − YJIT gap on Rails main: handoff (2026-11-27)

Stopped at the coordinator's request before the round was finished. **No wall-time ratio was measured**, so there
is no ranked gap list yet. What exists: the tooling, one counter run per build and benchmark, sampled call-site
traces, and the upstream survey. Nothing here was reviewed, and nothing was posted or opened upstream.
The next thread is T-01a21e9d-3d0a-74d4-85be-35a8e58786d0.

## Pins

* Ruby master [`0d399335b7`](https://github.com/ruby/ruby/commit/0d399335b7) (2026-11-27 16:40 UTC), release build,
  `--enable-yjit --enable-zjit optflags=-O3`. YJIT and ZJIT on this one build.
* Headline branch: k0kubun/ruby `zjit-headline6` [`5c4239a16d`](https://github.com/k0kubun/ruby/commit/5c4239a16d),
  97 commits on master `c10bc4c5aa` (2026-11-26), same configure. Between its base and the master pin, `yjit/` has
  two commits (a disp_size fix and the `opt_getconstantpath` storage change), so its ZJIT can be compared with
  master's YJIT only with that caveat.
* Rails main [`2e299253f9`](https://github.com/rails/rails/commit/2e299253f9), ruby-bench
  [`43d41e2`](https://github.com/ruby/ruby-bench/commit/43d41e2) with railsbench, lobsters and shipit pointed at
  that Rails by path (`Gemfile.main`), prism added, `reaping_frequency: 0` and `verify_timeout: 1000000`, the
  config lines Rails 8.2 defaults need (combined-effect round 3's patch) and shipit-engine 0.45.0 vendored with the
  `ReviewStack` patch. All three run on Rails main.
* Census apps Campfire and Writebook, corpus `censusz3`, same Rails, master overlays.
* ZJIT flags `--zjit-exec-mem-size=512 --zjit-mem-size=1024`; `compile_error_out_of_memory` is 0 in every stats run
  ([`data/stats-table-oom.txt`](data/stats-table-oom.txt); the census totals omit zero counters).

## Scripts (this directory)

| file | what it does |
| --- | --- |
| `setup.sh` | builds both Rubies at the pins, prepares ruby-bench and the two census copies, snapshots their databases |
| `wall_harness.rb`, `wall_run.sh` | one timed ruby-bench process: warmup and timed iterations through one loop, JIT counters read after every iteration, a timed iteration in which they moved is marked not flat |
| `wall_queue.sh` | one timing lane: per round master YJIT and ZJIT twice each (the A/A) and the headline ZJIT once, ABBA order, pinned |
| `wall_table.rb` | ratios with bootstrap intervals over rounds, A/A, rejected iterations. **Never run on real data**; on the smoke data (10 warmup iterations, nothing flat) it printed an empty table |
| `stats_queue.sh`, `stats_table.rb` | counters per iteration (`--zjit-stats-quiet`, `--yjit-stats=quiet`) and sampled fallback/exit traces |
| `census_stats.sh` | the same per operation for the census apps |
| `trace_sites.rb` | top call sites per reason from `jit_parity_fxt.rb` summaries |

`script/census run --wall` (harness command `wall`) is new and does for the census workload mix what
`wall_harness.rb` does for ruby-bench; `CENSUS_WALL_SKIP` drops workloads by name.

## What was measured

All on this thread's a1.large orb, several processes at a time, so **counts only, no timing**.

* Counters, 100 warmup and 10 counted iterations, fixed heap, one run per cell, no A/A:
  [`data/stats-table.md`](data/stats-table.md) (railsbench / lobsters / shipit, master ZJIT, headline ZJIT, master
  YJIT). Raw JSONs in `data/stats.tar.gz`.
* Census apps, 200 warmup operations per workload, then 20 each: [`data/census-table.md`](data/census-table.md).
* Traces (1 in 100, 25 warmup and 10 counted iterations, whole process) summarized by reason and call site, two
  frames deep: `data/sites.tar.gz` (`*-master.tsv`, `*-h6.tsv`, and `*-top.md` with the eight largest sites per
  reason). The census traces are 1 in 20 and master only. Scaled by 100/35, the trace totals match the counters
  (railsbench: getivar 199k against 201k, block argument 114k against 115k). The `.fxt` files (37–53 MB each) were
  not kept.
* Upstream survey, 2026-11-27: 132 open Shopify/ruby issues, 68 open and 18 recently merged ruby/ruby ZJIT PRs,
  the headline6 commit list and the titles of 202 commits on six of k0kubun's experiment branches:
  `data/upstream-survey.tar.gz`.

## What the counters say (unreviewed)

Dynamic sends per iteration, railsbench / lobsters / shipit:

| | master ZJIT | headline ZJIT | master YJIT |
| --- | ---: | ---: | ---: |
| dynamic sends | 575k / 622k / 1,427k | 171k / 125k / 327k | 389k / 334k / 659k |
| side exits | 4.0k / 8.1k / 7.0k | 13 / 1.2k / 3 | 9.0k / 3.1k / 7.0k |

Campfire and Writebook show the same order per operation: 6,168 / 19,182 on master, 1,651 / 3,726 on the headline
branch, 2,899 / 9,288 under YJIT.

* **On master ZJIT still sends dynamically 1.5–2.2× as often as YJIT**, on Rails main as on Rails 8.1. The largest
  reasons are the known ones: generic ivar reads without a shape profile (170k / 233k / 658k), polymorphic
  fallback (24k / 263k / 705k), megamorphic sends, `&block` arguments (115k / 51k / 147k), `(...)` forwarding,
  protected sends (47k / 16k / 36k), `Kernel#send`.
* **Each of those reasons is gone or much smaller on headline6**, which is being upstreamed commit by commit
  (merged: ruby/ruby#20113, #20137; open: #20192, #20193, #20197). On it ZJIT sends dynamically less than half as
  often as YJIT.
* **YJIT falls back at several of the same sites**, so they are not a gap against it: `send_forwarding`
  46k / 27k / 103k equals ZJIT's `sendforward_not_specialized`, and `invokesuper_forwarding` 20k / 2.5k / 6.7k
  equals `invokesuperforward_not_specialized`. YJIT's `super` fallbacks add up to about 59k / 35k / 30k, against
  47k / 9k / 42k for ZJIT on headline6.
* **What headline6 leaves**, per iteration: `invokeblock_not_specialized` 45k / 22k / 46k (largest site: the
  `yield` of `Array#each` under `Fanout#iterate_guarding_exceptions`, `collection.each(&block)`, 18k on
  railsbench); `send_not_optimized_method_type` 39k / 8.5k / 13k (`ActiveSupport::Callbacks` `make_lambda`
  lambdas, callbacks.rb:399 and :422); `super` from a method that got a block 4.0k / 1.3k / 21k (on shipit almost
  all `AssociationRoute::Cache#fetch_or_store`, association_route.rb:189, new on Rails main); generic ivar reads
  after a shape-chain miss 168k / 166k / 400k; generic ivar writes after a shape-chain miss on shipit (58k, led by
  `Relation#reset`); `WhereClause#empty?`
  forwarding with more than one callinfo on shipit (52k); and 18k `&:value!` sends in
  `LazyIndexedAttributeSet#fetch_value_at!` on shipit, although the branch has "Send Symbol block arguments
  directly". Why that site still falls back there was not looked at.
* **Every residue reason found so far has a matching commit title on k0kubun's experiment branches** (read from
  `zjit-headline-exp/super13`, `/super`, `/rails2`, `/invokeblock-on-tip`, `/mega` and `zjit-dev`): "Pass the
  frame's block on through super to an ISEQ method", "Specialize super with a literal block to an ISEQ method",
  "Specialize super(...) on the profiled callinfo", "Dispatch yield directly to Procs that wrap ISEQ blocks",
  "Read class instance variables through the (shape, name) cache". No PR or assigned issue exists for them, so by
  the queue rule they are free, but building one would duplicate his work. Matched by title only; the commits
  were not read.

So far nothing new and unowned has turned up, and **no Rails candidate**: the Rails-side shapes seen
(`&:value!` in `fetch_value_at!`, protected `_get` in `InheritableOptions`) are VB1 (closed upstream) and OO1
(held), both JIT-side by the rule that Rails doesn't take JIT workarounds.

## Half-done

* **Wall time on a1.xxlarge: not measured.** The timing thread
  (T-01a21e90-600b-773d-a55b-d611f0dc1b4c) built both Rubies and was in the census step of `setup.sh` when it was
  stopped; no lane ran and it committed nothing. Its orb still has the builds; the thread is stopped, not
  archived.
* **The JIT-flat gate under wall time.** In the probes ZJIT stopped compiling after iteration 30–66 on all three
  benchmarks and after 260 of 350 cycles on Campfire; YJIT was flat on railsbench after iteration 31 but compiled
  again at iterations 310 and 305 of 310 on lobsters and shipit, and was not flat after 350 cycles of Campfire.
  Neither JIT was flat on Writebook. The harness therefore rejects single timed iterations instead of
  whole processes and counts them; whether that leaves enough flat iterations for YJIT is untested.
* **Probe timings** (`data/wall-probe.tar.gz`) come from unpinned, concurrent processes on a1.large and say nothing
  about the ratio. They were only used to choose the warmup (150 iterations).
* **Writebook grows per cycle**: "POST page" adds a page and every later request renders a longer book (a
  5-cycle window went from about 640 ms to 3,860 ms over 350 cycles). `wall_queue.sh` skips that workload and restores the database snapshot
  before every process; this was smoke-tested only.
* The headline-branch census traces (`ht`) and any per-ISEQ stats build were not run.
* No doc under `docs/upstream/`, no entry in `zjit-iseq-leads.md`, no queue item.

## What I would do next

1. Run the timing as planned on a1.xxlarge (the stopped thread's orb or a new one): `setup.sh`, then five lanes
   on cores 2, 4, 6, 8, 10 with idle siblings, `wall_queue.sh OUT CPU TARGET 1 6` (10 rounds for the census apps),
   then `wall_table.rb`. First check on one lane that timed iterations stay flat under YJIT; if not, decide the
   gate before spending the hour.
2. Rank by the measured ratios, and price the residue reasons with micros on the same orb (ZJIT on master and on
   headline6 against YJIT): `yield` to a forwarded `&block` in `Array#each`, `super` passing the frame's block,
   `make_lambda` lambdas, `&:value!` into `cast_value`.
3. Find out why `fetch_value_at!`'s `&:value!` still falls back on headline6 (18k per shipit iteration). If it is
   a limit of our own ruby/ruby#19912, that is the one item here that is ours.
4. Check the residue against k0kubun's branches by reading the commits, not only their titles, then write the
   leads into `docs/upstream/zjit-iseq-leads.md` as taken or free.

## Looked at and dropped

* shipit on Rails 8.1 and the 11-25 pins: not rerun; all three ruby-bench apps were moved to Rails main instead.
* Fizzy and the census Lobsters: not set up (round 2 found both failing on Rails main before any JIT).
* The per-ISEQ stats branch: not rebased onto the pin; the sampled traces gave the sites.
* Traces at 1 in 20 over 110 iterations: stopped at 200–640 MB per file and replaced by 1 in 100 over 35.
