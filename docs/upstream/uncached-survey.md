# Where else does skipping the query cache pay? (2026-11-28)

SCB1 ([rails/solid_cable#105](https://github.com/rails/solid_cable/pull/105)) wraps the Solid Cable listener's poll in
`uncached`: the poll runs inside an executor run with Active Record's query cache on, but the cache can never answer
it, and keying the cache cost about half an idle poll. This round asks where else the same pattern pays: code that
runs often with the cache enabled, where the cache provably never hits and its bookkeeping is a measurable share.

**Result: nowhere else that is large.** No new queue item. The query cache's cost per miss grows with the number of
binds (each bind is hashed into the key), so it is large only for a query with a long `IN` list and little else
around it. Solid Cable's listener poll is that case. Everywhere else checked, either the path already skips the cache,
there is no Active Record query in a cached context, or the saving is a few percent. For Solid Queue's poller, the
change costs more on idle polls than it saves on busy ones.

## Pins and method

* Rails main [`5888defcb3`](https://github.com/rails/rails/commit/5888defcb3) (2026-11-27, includes
  rails#59505 and rails#59518). Rails 8.1.4.1 for the 8.1 rows. Ruby 4.0.10 (interpreter, YJIT); ZJIT on Ruby master
  `0d399335b7`. good_job 4.24.1, solid_queue 1.7.2.
* Callgrind instructions per call with `script/upstream-bench`: base run twice (A/A), candidate once, JIT-flat gate
  on every window. Measured on an a1.xxlarge orb
  ([thread](https://ampcode.com/threads/T-01a21f36-0ef1-70a5-b917-c363bee79174)); raw dumps, commands and tables in
  [`bench/upstream/uncached_survey/runs/`](../../bench/upstream/uncached_survey/runs). Scripts:
  [`qc_model.rb`](../../bench/upstream/uncached_survey/qc_model.rb) (one executor run plus one SELECT with N binds,
  as a poll loop runs it), [`sq_body.rb`](../../bench/upstream/uncached_survey/sq_body.rb) (Solid Queue worker and
  dispatcher polls, idle and busy, on SQLite), [`gj_body.rb`](../../bench/upstream/uncached_survey/gj_body.rb)
  (good_job dequeue on PostgreSQL), [`orb_run.sh`](../../bench/upstream/uncached_survey/orb_run.sh), candidate
  diffs in [`patches/`](../../bench/upstream/uncached_survey/patches).
* The ir-sq interpreter cells come from the raw dumps ((n200 − n0) / 200 from each dump's `totals:`); that cohort
  was stopped after its interpreter cells and has no table.md.

## Ranked table

| # | Path | How often | Saving: interp / YJIT / ZJIT (instructions per call) | Exact? | Upstream discussion |
| --- | --- | --- | --- | --- | --- |
| 1 | Solid Cable listener poll (`broadcast_messages`) | every 0.1 s per process, idle or not | −14.5% / −23.2% / −23.7% per idle poll (census) | **Yes**: one SELECT per executor run, and the run clears the cache when it completes | SCB1, [solid_cable#105](https://github.com/rails/solid_cable/pull/105) (ours, open) |
| 2 | Solid Queue dispatcher poll, busy: `Poller#with_polling_volume` under `SolidQueue::Record.uncached` | each dispatch of due scheduled jobs (dispatcher polls every 1 s) | 10 due jobs −2.3% / not JIT-flat (−3.2%) / not JIT-flat (−4.5%); 100 due −2.9% / not JIT-flat (−4.1%) / not JIT-flat (−5.9%) | Yes (see below) | none (searched solid_queue for "uncached", "query cache") |
| 3 | good_job dequeue (`advisory_lock` CTE `.to_a` under `uncached`) | each scheduler run (poll every 10 s by default, plus each LISTEN wake-up) | idle: — / −1.0% / −1.1%; dequeue and perform: — / −0.2% / −0.3%, both not JIT-flat | Yes: one dequeue SELECT, first in its `reloader.wrap` | none; good_job#979 (2023) is about `table_exists?` |
| 4 | Solid Queue worker claim (same patch) | each claim of ready jobs | 3 jobs −0.4% / not JIT-flat (−0.6%) / −0.7% | Yes | none |
| — | Solid Queue idle polls (same patch) | every 0.1–1 s per worker, every 1 s per dispatcher | **worse**: worker +1.3% / +0.6% / +0.5%; dispatcher +2.4% / +1.4% / +3.1% | Yes | Bet S census measured the idle case before (+1.5%) |
| — | Rails batches (`find_each`, `in_batches`) | — | already `skip_query_cache!` | — | — |
| — | Solid Cache reads and writes | — | already `uncached(dirties: false)` ("Skip the query cache entirely", solid_cache #71, 2023; `dirties:` since 2024) | — | — |
| — | Action Cable PostgreSQL adapter | — | LISTEN on a raw connection; no Active Record query | — | — |
| — | good_job notifier tick (process heartbeat) | every 1 s | `refresh_if_stale` checks staleness in memory; when stale it writes (UPDATE, cleanup DELETE), which the cache never answers | — | — |
| — | delayed_job (active_record backend) | worker loop | no executor around the loop, so no query cache; `reserve` is an UPDATE | — | — |
| — | que | — | raw PG, no Active Record queries in the loop | — | — |
| — | flipper (Active Record adapter) | poller thread; one `get_all` per request | the poller runs without an executor; a request reads once | — | — |
| — | sidekiq-cron, mission_control-jobs, rails_semantic_logger | — | no Active Record poll loop found (read, not measured) | — | — |
| — | Active Storage, Action Mailbox, Action Text jobs | per job | one-off jobs with a few queries; no loop | — | — |
| — | `ActiveRecord::Migration::CheckPending` (development) | per request | checks pending migrations only when a migration file changes (file watcher), not per request | — | — |


### What the query cache costs one miss (model)

`qc_model.rb`: one executor run with the query cache hooks and one `Item.where(channel_hash: [...]).to_a` inside,
cached against `uncached`. Rails main, instructions per call:

| Binds, rows | interp | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| 1, none | +0.3% | −4.1% | −4.5% |
| 20, none | −18.6% | −27.4% | −32.7% |
| 100, none | −28.6% | not JIT-flat (−39.7%) | −46.0% |
| 20 binds, 20 rows | −13.7% | −21.3% | −25.7% |

Rails 8.1.4.1, ZJIT: −6.8%, −34.3%, −48.4%, −26.1%. All A/A ≤ 0.52%.

**Why it scales with binds.** `cache_sql` keys on `[sql, binds]`, and `Store#compute_if_absent` hashes the key on
`delete` and again on the insert, so every bind is hashed twice. rails#59518 memoized `QueryAttribute#hash`, but an
`IN` list's binds are `ActiveModel::Attribute::WithCastValue` (built by `Arel::Nodes::HomogeneousIn`), whose `hash`
builds `[class, name, value_before_type_cast, type]` and `Type::Value#hash` another array on each call. A TracePoint
diff of one 20-bind query on main: 40 calls each of `Attribute#hash` and `Type::Value#hash` and their readers, all
gone under `uncached`. With one or two binds, the cache's cost is about what `uncached` itself costs (pool lookup,
`disable_query_cache`'s save and restore), which is why the Solid Queue idle polls get slower.

## Exactness

`uncached` is exact where the cache cannot return a hit: no earlier SELECT with the same SQL and binds in the same
executor run since the cache was last cleared. Writes (`exec_query`, `execute`, inserts, updates, deletes) clear it
by default; `SELECT ... FOR UPDATE` (`locked` arel) is never cached.

* **Solid Queue poller.** Each poll is one executor run (`Poller#start_loop`). Traced with every query in one run
  (`sql.active_record`, cache enabled): dispatcher, 10 due jobs: 9 queries, 5 SELECTs, 0 hits, 0 (sql, binds)
  repeats without a write between; worker claim of 3: 7 queries, 0 hits, 0 repeats; idle polls: 4 and 3 queries, 0
  hits. By code: `dispatch_next_batch` locks (`non_blocking_lock`, never cached), then `Job.where(id:)`,
  `insert_all` (clears), the ready and blocked look-ups and the delete; concurrency-limited jobs go through
  `Semaphore.lock` (locked) and writes. The worker reads pauses once, locks the candidates, inserts (clears), then
  loads the claims. A repeat with no write between does not exist on these paths, so the patch is exact; it is
  dropped for its effect.
* **good_job dequeue.** `GoodJob.perform_inline`/`Scheduler` run `performer.next` in one `reloader.wrap`; the
  dequeue `SELECT ... pg_try_advisory_lock` is the first query of that run, so the cache cannot hold it. A hit
  would be wrong rather than slow (it would skip taking the advisory locks), but none is possible. Dropped for its
  effect.

## Lead, not built: the miss cost itself

Where a hit is possible (requests), `uncached` is not exact, so the lever there is a cheaper cache key, as
rails#59505 and rails#59518 (both by sampokuokkanen, merged 2026-11-01 and 2026-11-27) did. The rest of the per-bind
cost on main is `WithCastValue#hash` for `IN` lists. Memoizing it is not obviously exact: its value is the caller's
object (a String can be mutated after the query, `test_query_cache_handles_mutated_binds`), unlike
`QueryAttribute`'s memoized `value_for_database`. That is an active line of someone else's work; recorded here,
not built.

## Decisions

* No queue items: SCB1 stays the one PR from this pattern. Solid Queue poller (`uncached` around the poll), held as a
  parked idea: it makes the frequent idle polls slower (ZJIT +3.1% dispatcher) and the busy dispatch gain is 2–6%,
  partly not JIT-flat. good_job dequeue: dropped, about 1%.
* Wall time: one ZJIT cohort of the Solid Queue body, 8 rounds (below). The planned 30-round YJIT, ZJIT and model cohorts
  (6–8 hours of a1.xxlarge) were dropped, since the instruction counts already decide and nothing opens.

## Wall time (a1.xxlarge)

`runs/wall-sq-zjit`: Ruby master `0d399335b7` with ZJIT, solid_queue 1.7.2 against the poller patch, 8 rounds. The
time is thread CPU per call with GC off, taking the 10th-percentile window per process; the change is the median over
rounds. Eight rounds is below the harness's 10-round minimum, so no row carries a claim.

| Case | main | uncached | Change [95%] | A/A [95%] | Note |
| --- | ---: | ---: | ---: | ---: | --- |
| worker poll, idle | 202.83 µs | 204.58 µs | +0.7% [−1.7, +3.8] | −0.3% [−4.7, +2.6] | JIT-flat |
| dispatcher poll, idle | 229.90 µs | 237.40 µs | +3.0% [+0.5, +5.9] | −0.7% [−3.8, +0.9] | not JIT-flat |
| dispatcher poll, 10 due jobs | 6.721 ms | 6.581 ms | −3.2% [−6.9, +2.0] | −1.1% [−5.5, +2.4] | not JIT-flat |
| dispatcher poll, 100 due jobs | 25.941 ms | 24.633 ms | −4.4% [−11.8, +1.7] | −2.7% [−9.2, +2.0] | JIT-flat |
| worker claim, 3 jobs | 4.483 ms | 4.497 ms | −0.4% [−4.8, +5.5] | −1.8% [−6.6, +2.8] | JIT-flat |

The wall times point the same way as the instruction counts: the dispatcher's idle poll is slower (+3.0%, matching the
+3.1% in instructions) and busy dispatch is a few percent faster. Every interval except the idle dispatcher's
includes zero.
