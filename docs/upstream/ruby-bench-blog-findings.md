# What `blog` finds that railsbench and lobsters miss (2026-11-06)

**Question (Thomas, via the coordinator).** Before the blog benchmark ([RBW1](../../bench/upstream/pr-queue/items/RBW1.md))
goes upstream: what can it measure and find that railsbench and lobsters miss? Callgrind Ir with A/A controls first,
wall time as the second check. No upstream posts.

**Short answer.** blog's value is its per-request split, not its total. Its headline number moves like railsbench's
and lobsters' for every change we tried, but only blog can say *which* kind of request moved: Rails main speeds reads up
by 9–14% (Ir per request) while leaving create paths flat, because Active Record does 11% more calls per write. Changes confined to
the save path are invisible to railsbench and lobsters (they make no saves in their timed iterations); blog sees a
2% save-path slowdown as +2.3% Ir. Wall time on a 4-vCPU orb detects it in none of the three. A per-query cost
(PM1b) shows the same size on all three; sqlite3 #770 shows only on lobsters (−0.09%) and #769 nowhere. YJIT and
ZJIT speed blog's writes up as much as its reads.

**Setup.** ruby-bench `thomasklemm/blog-benchmark` at **`65151273f6`** plus three experiment-only commits (branch
`v-exp`, `2950871`), which the numbers below all come from:
- blog opens and rolls back its own transaction when `pin_connection!` doesn't. Rails main removed the transaction
  from `pin_connection!` in 9e8fe3955b ("Introduce Ractor connection handler, pool, and proxy", 2026-07-10); without
  this, blog's writes accumulate on Rails main. **The benchmark at 65151273f6 doesn't roll back on Rails 8.2** (fixed in a233212fad, verified on both);
  this must be fixed before or soon after it goes upstream.
- lobsters' route generator logs in without a rendered CSRF token and sends `Sec-Fetch-Site: same-origin` (8.2
  defaults to header-only CSRF).
- lobsters and railsbench load 8.1 defaults (`load_defaults "8.1"`): on 8.2 defaults Herb's ERB fails on lobsters'
  `users/tree.html.erb`. So "Rails main" below means main's code on 8.1 defaults, for all three benchmarks.
Ruby 4.0.9 interpreter unless noted. Callgrind: `audit.rb` (round 4), fixed heap (`RUBY_GC_HEAP_*_INIT_SLOTS`), boot plus
2 warmups dropped, 5 measured iterations, 2 processes; A/A is the spread of the two process means. Iterations where
the arms ran a different number of major GCs are dropped from both arms (`gcmatch.rb`).

## 1. Rails 8.1.4.1 vs Rails main (cadf0fc8d6)

| Ir per iteration | 8.1.4.1 | main | change | A/A (8.1 / main) |
| --- | ---: | ---: | ---: | ---: |
| blog | 4.310e9 | 3.956e9 | −8.2% | 0.026% / 0.015% |
| railsbench | 7.413e9 | 6.493e9 | −12.4% | 0.009% / 0.009% |
| lobsters | 3.678e9 | 3.390e9 | −7.8% | 0.026% / 0.013% |

The totals say "main is faster" everywhere. blog's per-request Callgrind (one iteration, GC disabled during it,
a dump around every request; process A/A per kind within 0.1%) says where:

| request (count per iteration) | 8.1.4.1 Ir | main Ir | change |
| --- | ---: | ---: | ---: |
| GET show (193) | 8.82M | 7.93M | −10.1% |
| GET index (33) | 18.40M | 16.64M | −9.6% |
| GET new (39) | 6.21M | 5.63M | −9.3% |
| GET show.json (14) | 2.88M | 2.48M | −14.0% |
| POST comment, 302 (44) | 12.25M | 12.06M | −1.6% |
| POST article, 302 (24) | 8.70M | 8.74M | +0.5% |
| PATCH article, 303 (14) | 9.26M | 9.24M | −0.3% |
| DELETE article, 303 (15) | 11.55M | 10.64M | −7.9% |
| POST article, 422 (15) | 16.15M | 15.58M | −3.5% |

Writes are 32% of blog's Ir (8.1.4.1). The SQL each request runs is identical on both (1,610 statements per
iteration, 1,081 of them in writes). Ruby method calls per POST comment (TracePoint, 44 requests): 12,151 → 12,727.
By namespace: Active Record/Active Model/Arel **+705** (6,301 → 7,006, +11%), Active Support +169, Action Pack +20,
other −313. The new calls are main's query-intent and connection-lease machinery: `QueryIntent#processed_sql`,
`#compile_arel!`, `#type_casted_binds` (+29–37 each), `ConnectionPool.used_pools!` and `UsedPoolSet#add` (+37),
`LeaseRegistry#lease` (+31), `schema_loaded?`/`schema_context` (+94 each), lazy attribute sets
(`LazyAttributeSet#fetch_value!` +71, `Attribute#value!` +58) and `Ractor.main?` (+45). On reads the routing,
rendering and CSRF-token savings outweigh them; on the create paths they cancel the savings. railsbench and
lobsters cannot show this: their totals move by the read gains only. Ledger: [main-regressions.md W1](main-regressions.md#w1-create-paths-dont-share-mains-gain-candidate-2026-11-06-no-fix).

Wall time agrees (`run_benchmarks.rb`, default harness, 3 alternated process pairs, 4.0.9 interpreter, fixed heap):

| ms per iteration | 8.1.4.1 | main | change |
| --- | ---: | ---: | ---: |
| blog | 1,763 (processes 1,785 / 1,770 / 1,734) | 1,602 (1,672 / 1,565 / 1,570) | −9.1% (t = 4.2) |
| railsbench | 2,963 (2,980 / 3,003 / 2,905) | 2,656 (2,681 / 2,654 / 2,633) | −10.3% (t = 9.3) |

## 2. Our changes as A/B

| Ir change | blog | railsbench | lobsters |
| --- | ---: | ---: | ---: |
| PM1b (`3510f6e151`) vs its base, Rails main | +0.64% (A/A 0.04%) | +0.72% (A/A 0.02%) | +0.57% (one process, same GC schedule as main's; see below) |
| sqlite3 #769 (`f1709a4f53`) vs base gem | +0.013% (A/A 0.013%) | −0.030% (A/A 0.085%) | −0.001% (A/A 0.025%) |
| sqlite3 #770 (`6c212edd9c`) vs base gem | −0.012% (A/A 0.013%) | −0.063% (A/A 0.069%) | −0.094% (A/A 0.020%) |

- PM1b costs about the same on all three (about 16k Ir per statement on blog's 1,610). blog has no edge: two
  thirds of its statements are in writes, but a per-query cost is a per-query cost.
- The sqlite3 base is the locally built 2.10.2 from `48091f4` (2.10.2.900); #769 and #770 are 2.10.2.901/.902.
  Moving railsbench and lobsters from 2.7.3 to the base gem alone changed them −0.53% and +0.18% (raw).
- #770 (row arrays) shows only on lobsters, which loads many multi-column rows; blog loads few rows per request.
  #769 (string binds) is flat everywhere. This agrees with their own records: no whole-request saving established.
- lobsters' second PM1b process grew its heap (1,917 pages vs 1,516) and ran an extra major GC; its first process
  gives +0.57%. lobsters' raw summary first showed #770 at −1.08%: a major GC that landed in the base arm only.
  Matching iterations by GC count removes it. Per-iteration Ir in lobsters swings ±3% with GC placement.

## 3. Sensitivity: a slowdown in the save path only

A preload prepends a busy loop to `ActiveRecord::Transactions#save`, `#save!` and `#destroy` (`slow.rb`). blog calls
them 305 times per iteration; railsbench 0; lobsters 15, all in setup (the count does not change with 1 or 3
iterations). Calibrated on blog with Callgrind: 400 turns per call +0.41%, 2,000 turns +2.31% (linear; the 0-turn
wrapper costs nothing measurable).

| Ir, 2,000 turns per call | blog | railsbench | lobsters |
| --- | ---: | ---: | ---: |
| change vs 8.1.4.1 | +2.31% | +0.075% | +1.08% raw, ≈ +0.2% after dropping one extra major GC |

railsbench's and lobsters' differences are not the slowdown: the preload's TracePoint adds 144M (railsbench) and
375M (lobsters) Ir to boot, which moves heap state and GC placement in the iterations.

Wall, `run_benchmarks.rb --runs=5 --pvalue --interleave` (ruby-bench `pvalue-across-processes` @ `69767b3206`,
cherry-picked onto the same tree), control is the same preload with 0 turns, doses from the calibration:

| wall, 5 processes per arm | control ms (process sd) | 1.0% dose | 2.0% dose |
| --- | ---: | ---: | ---: |
| blog | 1,744 (2.4%) | 1,698, ctl/slow 1.027, p = 0.23 | 1,741, ctl/slow 1.002, p = 0.94 |
| railsbench | 2,911 (1.2%) | – | 2,911, 1.000, p = 0.99 |
| lobsters | 1,234 (5.8%) | – | 1,218, 1.014, p = 0.70 |

Nothing detects it in wall time on this orb: process means vary 1.2–5.8% (blog 2.4–4.8%), so five processes
resolve about 6% on blog. Callgrind sees blog's 2% at 0.03% A/A; railsbench and lobsters cannot see it at all,
because their timed iterations never call save. Detecting a 2% write-path change takes blog **and** Ir.

## 4. Ruby 4.0.9 vs master (0236df43c2), interpreter / YJIT / ZJIT

blog per request kind, wall ms per iteration (`wall_per_request.rb`: 30 warmup iterations, 20 timed, 2 processes
per configuration, fixed heap):

| ms per iteration | 4.0.9 interp | 4.0.9 YJIT | master interp | master YJIT | master ZJIT |
| --- | ---: | ---: | ---: | ---: | ---: |
| reads (GET) | 1,086 | 602 (1.81×) | 1,094 | 589 (1.86×) | 617 (1.77×) |
| writes | 609 | 326 (1.87×) | 603 | 331 (1.82×) | 328 (1.84×) |
| POST comment | 268 | 140 (1.92×) | 266 | 144 (1.85×) | 143 (1.86×) |
| POST article 422 | 75 | 45 (1.66×) | 74 | 42 (1.75×) | 44 (1.68×) |
| GET show | 704 | 386 (1.82×) | 709 | 383 (1.85×) | 399 (1.78×) |
| GET index | 202 | 112 (1.80×) | 212 | 109 (1.94×) | 117 (1.80×) |

No JIT gap on writes: YJIT and ZJIT speed writes up as much as reads. ZJIT trails YJIT on master by about 5% on
reads (show and index) and not on writes; process totals vary 1–13% (4.0.9 interpreter 1,817 / 1,594 ms), so this
is a lead, not a finding. The 422 re-render has the smallest JIT speedup on every JIT. Master's interpreter is
within 1% of 4.0.9 on both. Whole benchmarks for context
(`run_benchmarks.rb --interleave`, one process per configuration, so ±5%):

| ms per iteration | 4.0.9 interp | 4.0.9 YJIT | master interp | master YJIT | master ZJIT | ZJIT vs YJIT (master) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 1,794 | 967 | 1,578 | 912 | 939 | +2.9% |
| railsbench | 2,871 | 1,620 | 2,830 | 1,556 | 1,584 | +1.8% |
| lobsters | 1,184 | 696 | 1,176 | 643 | 687 | +6.9% |

blog is not harder for either JIT than railsbench or lobsters. (blog's 4.0.9 interpreter process here was noisy,
±9.7% between iterations.)

## 5. Write-path hot spots (blog, 8.1.4.1, StackProf cpu, 10 iterations, % of all samples)

Write actions are 25.3% of samples (32% of Ir including their routing and rendering). Inside them:

| spot | share | reach (guess) |
| --- | ---: | --- |
| after-commit callbacks (`committed!`) | 15.3% | every app with `after_commit`/`*_commit` hooks; here it is the Turbo broadcasts |
| Turbo `broadcast_*_later_to` → Active Job enqueue → `SolidQueue::Job.enqueue` | 8.4% (Job.enqueue 7.9%) | every `perform_later` on Solid Queue, the 8.x default; one enqueue is a full Active Record create with its own savepoint, callbacks and two INSERTs (job, ready execution); 82 per iteration, roughly 4M Ir each (share × Ir, an estimate) |
| Turbo sync broadcast (`broadcast_*_to`): partial render 3.3%, Solid Cable INSERT 3.0% | 6.6% | apps using `broadcasts_to`/Turbo Streams |
| INSERT compilation and execution (`_insert_record`) | 5.0% | every create |
| SQLite execute (`raw_execute`; `Statement#prepare` as hot as `#step`, 0.8% each) | 5.3% | every write; worth checking which statements miss the statement cache |
| savepoint begin | 0.6% | every save in a transaction (tests, nested transactions) |
| `redirect_to` | 0.7% | every successful form |
| `dependent: :destroy` | 0.6% | apps with dependent associations |
| validations (`valid?`) | 0.7% | every save; cheap here (presence and length only) |
| strong parameters (`params.expect`) | 0.4% | every form |

The surprise is the ratio: Turbo's after-commit work (15.3%) is three times all INSERTs together (5.0%, which already
include the job and Cable rows) and twenty times the validations. In a default 8.x app with `broadcasts_to`, the cost
of a write is mostly what hangs off `after_commit`, and half of that is enqueuing a Solid Queue job.

## What blog finds / doesn't find

Finds:
- Changes to the save path, callbacks, transactions, job enqueue and broadcasts: railsbench and lobsters run none of
  them in their timed iterations, so a 2% save-path slowdown is +2.3% Ir in blog and never runs in them.
- *Where* a Rails change lands, via its per-request split: main's 8–12% gain is a read gain; create paths are flat
  because Active Record makes 11% more calls per write.
- Where write cost goes in a default 8.x app (section 5): candidates for Rails work on Turbo broadcasts and Solid
  Queue enqueue that no other ruby-bench benchmark exercises.

Doesn't find:
- Per-query or driver-level costs better than the others (PM1b, sqlite3 #769/#770: same size or smaller in blog).
- Real COMMIT/WAL cost, job execution, Solid Cable's batched writer thread, concurrency.
- Its totals alone: 68% of its Ir is reads that look like railsbench's.
- Small changes in wall time on a shared VM: here only Ir resolves 2%.

Before it goes upstream: its rollback relies on `pin_connection!` opening a transaction, which Rails main dropped
(9e8fe3955b). The experiment commit in `v-exp.diff` opens and rolls back the transaction itself when none is open.

Scripts and raw results: [bench/upstream/ruby_bench_blog/experiments/](../../bench/upstream/ruby_bench_blog/experiments/).
