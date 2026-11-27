# Rails 8 default stack census: Solid Queue, Solid Cache, Solid Cable, Turbo broadcasts

Every `rails new` on Rails 8 ships Solid Queue, Solid Cache and Solid Cable, and Turbo broadcasts through Action
Cable. The [background census](background-census.md) measured jobs, mail, storage and cable work in 12 apps, but
through the test adapter and an inline pub/sub, so the stack's own loops (enqueue into the database, the worker's
and dispatcher's polls, claim and finish, cache reads and writes, the cable writer and listener) were never
measured. This round measures them, per operation, on Rails main.

**Result.** 21 operations, SQLite and PostgreSQL, released gems and their main branches, each with an A/A.

* **The idle loops are the frequent ones.** A Solid Cable listener polls every 0.1 s per process forever, a Solid
  Queue worker every 0.1 s (Fizzy) to 1 s (default, Loomio), the dispatcher every second. An idle poll costs
  0.6–1.0 M instructions (worker `*`, dispatcher, cable listener), 2.7–3.3 M for a worker with seven queues.
* **The cable listener spends half of an idle poll in Active Record's query cache**, which can never answer it
  (one query per executor run, cleared when the run completes). **SCB1** removes that: −14.5% instructions per
  idle poll in the body benchmark, −25% in the census app with 20 streams.
* **Enqueue** (2.1 M instructions, 690 objects on SQLite) is mostly Active Record insert work; the one stack-owned
  piece, `create_or_find_by!`'s savepoint for the ready execution, is SSQ1, held (below).
* **Cache reads** are dominated by native work (Zlib inflate and Marshal of the entry, SHA-256 key hashes);
  nothing small and exact in Solid Cache.
* **Broadcasts** are dominated by `JSON::Encoding#escape!` (native `tr!`, already looked at in
  [serialization-cpu](serialization-cpu.md)) and, for `broadcast_refresh_to`, by `URI::GID.build` in uri (the
  background census's uri lead).
* **Gem main vs release:** no operation moves outside its A/A on either database.

## Pins, app and method

* Rails main [`2e299253f9`](https://github.com/rails/rails/commit/2e299253f9) (2026-11-27). Ruby 4.0.10 (the pin
  since 2026-11-27); ZJIT on Ruby master `0d399335b7`. Released gems: solid_queue 1.7.2, solid_cache 1.0.10,
  solid_cable 4.1.0, turbo-rails 2.0.23; main: solid_queue `b9c646a` (= 1.7.2), solid_cache `da70ef4`,
  solid_cable `40dd29f`, turbo-rails `10d72f2`.
* **Which census apps use the stack** (Gemfile.lock on their default branches, 2026-11-27): Fizzy (all three Solid
  gems, Turbo), Loomio (all three, Turbo; Redis cable when configured), Lobsters (Solid Queue and Cache),
  redprints-cfp and AixleHQ/flow (Solid Queue), hackatime (Solid Cache), thinkroom (Solid Cable). Campfire and
  Writebook use Resque; Mastodon, Discourse, Chatwoot, CodeTriage, Docuseal, Lago and Sure use Sidekiq.
* **Reach** (rubygems.org, 2026-11-27): turbo-rails 96.5 M downloads, solid_queue 32.0 M, solid_cache 28.0 M,
  solid_cable 24.7 M; all three Solid gems are in every Rails 8 `rails new`.
* **App:** a `rails new` from Rails main with the four databases as generated, made reproducible by
  [`setup.sh`](../../bench/upstream/solid_stack/setup.sh) and its `app_overlay`. Payloads follow Fizzy: its
  `config/queue.yml` (worker `*` at 0.1 s; Loomio's seven-queue worker at 1 s), `config/cable.yml` (polling 0.1 s),
  `config/cache.yml` (the default store options), a Card model with `broadcasts_refreshes`, a one-record-argument
  job shaped like `NotifyRecipientsJob`, a card partial (6.3 KB cached fragment, 1.1 KB stream message) and
  20 notification fragments for `read_multi`.
* **Harness:** [`harness.rb`](../../bench/upstream/solid_stack/harness.rb) builds a worker and dispatcher as
  `bin/jobs` does (registered, threads not started), the server's cable adapter with its writer thread stopped,
  and a listener with 20 streams that runs one iteration of its own `listen` loop per op. Each op starts from empty
  queue tables. 200 warm-up ops, then objects (two GC-free windows of 40 and 80 ops) and Callgrind with census 8's
  instruction sampler (40 ops). [`run.sh`](../../bench/upstream/solid_stack/run.sh) runs one label,
  [`round.sh`](../../bench/upstream/solid_stack/round.sh) four in parallel (release A/A, main A/A),
  [`report.rb`](../../bench/upstream/solid_stack/report.rb) tabulates.
* **Raw data:** [`raw/census-r1-sqlite-r2-pg.tar.gz`](../../bench/upstream/solid_stack/raw) (every label's JSON
  and Valgrind log) and `raw/probes-p1-p2.tar.gz` (the SCB1 and SSQ1 probes).

## Per operation

Interpreter, Ruby 4.0.10, released gems; A/A is the second release run against the first. Most ops' A/A is within
±1.5%; the few large ones are single-op windows that hit SQLite's file I/O differently and are not ranked on.

| Op | SQLite objects | SQLite Ir/op | A/A | PG objects | PG Ir/op | A/A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| queue enqueue (record argument) | 690 | 2,113,696 | +0.4% | 638 | 2,070,884 | −3.7% |
| queue enqueue scheduled (wait 5 min) | 876 | 2,314,868 | −0.5% | 824 | 2,188,454 | +0.2% |
| queue perform_all_later (10 jobs) | 2,378 | 6,963,291 | +0.5% | 2,388 | 5,872,153 | +0.0% |
| queue worker poll, idle (`*`) | 230 | 630,251 | (+22%) | 209 | 733,121 | −0.0% |
| queue worker poll, idle (7 queues) | 1,038 | 2,662,192 | −0.0% | 1,071 | 3,315,501 | −0.0% |
| queue dispatcher poll, idle | 223 | 664,008 | +0.2% | 200 | 699,993 | +0.0% |
| queue job cycle (enqueue, claim, perform, finish) | 1,994 | 6,018,099 | −3.1% | 1,863 | 6,070,070 | −1.7% |
| cache read hit (6 KB fragment) | 95 | 305,049 | −0.9% | 105 | 392,647 | +0.0% |
| cache read miss | 84 | 176,581 | +0.3% | 83 | 218,063 | −1.5% |
| cache write (6 KB fragment) | 198 | 940,842 | −1.7% | 146 | 798,787 | −1.0% |
| cache fetch hit (record key) | 104 | 367,479 | −0.3% | 107 | 411,595 | +0.3% |
| cache fetch miss and write | 241 | 310,683 | +0.1% | 190 | 387,278 | −0.0% |
| cache read_multi (20 fragments) | 612 | 1,536,789 | −3.8% | 837 | 2,090,821 | −0.6% |
| cable broadcast (enqueue to writer) | 13 | 139,912 | +0.0% | 13 | 138,318 | +0.2% |
| cable writer flush (batch of 4) | 244 | 1,235,332 | −0.1% | 254 | 1,025,522 | −0.4% |
| cable listener poll, idle (20 streams) | 159 | 979,210 | +0.7% | 161 | 860,562 | +1.3% |
| cable listener poll, 1 message | 305 | 1,789,781 | (−8.8%) | 314 | 1,623,132 | −2.3% |
| turbo broadcast_refresh_to record | 85 | 211,423 | (−28%) | 85 | 121,250 | +0.5% |
| turbo broadcast_replace_to (render partial) | 129 | 380,810 | −0.1% | 129 | 375,441 | +0.2% |
| turbo broadcast_prepend_later_to (enqueue) | 790 | 2,394,529 | +1.4% | 737 | 2,215,434 | −0.2% |
| turbo ActionBroadcastJob perform | 358 | 793,838 | −0.8% | 358 | 785,682 | +0.2% |

Note: the census harness ran the listener poll through an executor run plus `with_polling_volume`; the SCB1 probe
and body run it through `listen` itself, which adds the executor's own callbacks.

## Ranked by reach × frequency

| # | Loop | Runs | Where the instructions go | Lead |
| ---: | --- | --- | --- | --- |
| 1 | Solid Cable listener poll | every 0.1 s per process (Puma worker, job process), idle or not | 51% in `QueryCache#cache_sql` → `Store#compute_if_absent`, `Attribute#hash`, `Type::Value#hash`: the key over the SQL and every stream's hash | **SCB1**, built |
| 2 | Solid Queue worker poll | every 0.1–1 s per worker | `QueueSelector`: `Pause.all.pluck` every poll (22% of a `*` poll), and for a list with prefixes one `DISTINCT … LIKE` query plus one transaction and `SELECT … FOR UPDATE` per queue (7 queues: 4.2× a `*` poll) | SSQ2, held |
| 3 | Solid Queue dispatcher poll | every 1 s | one `pluck` under a transaction; `Time#change` Rationals from `Time.current` binds | none |
| 4 | Solid Cache read / fetch | per cached fragment, per request | `LazyEntry#value`: Zlib inflate and Marshal (native, 27–36%); `BoundSqlLiteral` placeholder scan (7%); SHA-256 key hash (native) | none |
| 5 | Turbo broadcasts | per model change with `broadcasts_*` | `JSONGemCoderEncoder#escape!` native `tr!` (29–80%); `URI::GID.build` in uri (37% of `broadcast_refresh_to`) | covered: serialization-cpu, uri lead |
| 6 | Solid Queue enqueue | per `perform_later` | AR insert path (sqlite3 `Statement#initialize`, `_insert_record`); `create_or_find_by!` for the ready execution adds a savepoint | SSQ1, held |
| 7 | Solid Cache `read_multi` | per collection render with `cached: true` | `key_hash_for` SHA-256 per key (19%, native `Digest`) | none |
| 8 | Solid Cable writer flush | per batch of broadcasts | AR `insert_all`; `channel_hash_for` SHA-256 + `unpack1` per message | none |

## Upstream state (2026-11-27)

* **solid_queue:** active, merging outside PRs: 12 outside PRs merged on 2026-11-02/03 (andrewfader, ydah, ceritium,
  afurm and others), maintainer rosa. 17 open; open #833 (`dispatchable_on_enqueue?`) touches `prepare_for_execution`
  next to SSQ1, #837 touches claiming. 1.7.2 = main.
* **solid_cache:** quiet: last non-Dependabot merge 2026-07-21 (djmb, \"Fix tests on Rails main\"); 12 open PRs,
  several on `lock_and_write` and failsafe, none on the read path.
* **solid_cable:** active and merging outside PRs: #101 (cole-robertson) and #103 (jonasporto) on 2026-11-22,
  npezza93 maintaining. Open: #91 (rewrites `broadcast_messages` for late commits), #96 (listener error reporting),
  #102 (writer), #93 (duration parsing), #104 (docs). None touches the query cache; #91 changes the method SCB1
  wraps only from the outside (SCB1 wraps the call in `listen`, so it rebases cleanly either way).
* **turbo-rails:** merged four outside PRs on 2026-11-22; broadcasts' hot lines are in Rails and uri.

## Candidate SCB1: poll for messages without the query cache (solid_cable)

Branch [`thomasklemm/listener-without-query-cache`](https://github.com/thomasklemm/solid_cable/tree/thomasklemm/listener-without-query-cache)
`ef534cc` on main `40dd29f`. One line in `Listener#listen`:

```ruby
with_polling_volume { ::SolidCable::Message.uncached { broadcast_messages } }
```

**Mechanism.** `listen` runs every poll inside `Rails.application.executor.run!`, and Active Record's executor hook
enables the query cache on every pool for the run (`query_cache_enabled` is true for the cable pool during the
poll on main, false on the branch; probe `.amp/in/orb-backup/sc1_mechanism.rb`, both on the census app). The poll
runs one `SELECT` per run and the run's `complete!` clears the cache, so a lookup never hits, but each poll builds
the key `[sql, binds]` with one bind per subscribed stream, hashes it (`Attribute#hash`, `Type::Value#hash`) and
stores the result. With 20 streams that is about half of an idle poll; the cost grows with the number of streams.

**Exactness.** Described out loud: \"while polling, the listener does not use the query cache for the Solid Cable
connection.\"

* The poll's one query was never answered from the cache (each run sees an empty cache), so results are the same.
  The block contains no writes. `uncached` restores the previous state afterwards, also on exceptions (ensure).
* It changes only `SolidCable::Message`'s pool's query-cache flag on the listener thread; the primary pool keeps
  its cache (probe: `primary: true` on both sides).
* An app that subscribes to `sql.active_record` sees `cached: nil` on both sides for the poll query (differential).
* Checklist items 1–8: the change adds no call on a user-supplied object; `Message.uncached` is Active Record API
  since 2.x, with `dirties:` since 7.2 (not used); `connects_to` and sharding unaffected (`uncached` acts on the
  class's current pool); load order unchanged.
* **Differential** ([`sc1_differential.rb`](../../bench/upstream/solid_stack/sc1_differential.rb)): ten polls through
  `listen` itself (idle, one message, three with one unsubscribed channel, a late subscriber, a batch of five, after
  an unsubscribe, idle, inside an outer `ActiveRecord::Base.cache` and `Message.cache` block, 202 channels),
  polling logs silenced and not: received payloads per subscriber, `last_id`, every channel's last id and every
  query (SQL, cached or run, bind count) byte-identical between main and the branch, on SQLite and PostgreSQL.
* solid_cable's suite: 47 runs, 0 failures on the branch with SQLite, PostgreSQL, Rails 7.2 and Rails main (and
  on main with SQLite and PostgreSQL).

**Shared-helper check** (DECISIONS 2026-11-27, "Fix the shared helper"). The query-cache work comes from Active
Record's executor hook, which turns the cache on for every pool in every executor run; that is right for requests,
so the fix belongs with the poll loop that can never hit it, not in Rails. In solid_cable, `listen` is the only
poll loop and `broadcast_messages` has no other caller, so SCB1 is in the one shared place; it copies no helper
logic and adds no one-caller fast path. The other poll loops in the stack, Solid Queue's `Poller` (shared by the
worker and dispatcher), gain nothing from the same change: their claim and dispatch queries lock (`FOR UPDATE`),
which already skips the cache, and the `Pause` pluck has no binds. Measured on Rails main with the same harness,
polls wrapped in `SolidQueue::Record.uncached`, two runs per side: worker `*` 580,017 / 580,724 → 588,959 / 589,918
Ir (+1.5%), seven queues 2,579,393 / 2,580,535 → 2,569,004 / 2,572,378 (−0.4%), dispatcher 639,907 / 699,940 →
722,267 / 648,882 (inside its spread). Not built.

**Body numbers:** `bench/upstream/solid_stack/body/SC1` (Ruby 4.0.10, released Rails 8.1.4.1, interpreter, YJIT,
benchmark-ips) and `body/SC1-zjit` (Ruby master `0d399335b7`, ZJIT). Idle poll with 20 streams: −14.5% instructions
without a JIT, −23.2% YJIT, −23.7% ZJIT on master, 3 fewer objects; one new message −8.9% / −13.8% / −13.9%. Every
base A/A ≤ 0.06%, every JIT window flat. benchmark-ips under YJIT on a1.large: idle +14.8% (A/A 0.5%); one message
+3.2% (A/A 2.3%, no claim). On a1.xxlarge (`body/SC1-xxl`, YJIT): idle poll
benchmark-ips +15.9%, wall cohort 204.7 → 174.2 µs, −14.8% [−15.3%, −14.3%], A/A −0.9% [−1.5%, +0.1%], 30 rounds,
JIT-flat. The one-message case compiled a block in several processes at `--warmup 500`: not JIT-flat, no claim, and
the body doesn't use it.

## Held and dropped

| ID | Lead | Numbers | Why not now |
| --- | --- | --- | --- |
| SSQ1 | Solid Queue enqueue: `ReadyExecution.create!` instead of `create_or_find_by!` for a just-created job (no savepoint) | enqueue 690 → 628 objects (−62), 2.116 M → 1.982 M Ir (−6.3%); job cycle 5.72 M → 5.56 M Ir (−2.8%), −61 objects; A/A ≤ 0.2% (SQLite, probe p1/p2) | `ready` is shared with release and retry paths where an execution can already exist; `create_or_find_by!` there is deliberate (`46f2d7e`, \"Avoid replacing executions\", for Mission Control). Splitting it needs a branch for the fresh-job case, and open #833 reworks `prepare_for_execution` right next to it. Held until #833 settles. |
| SSQ2 | Solid Queue worker poll: `Pause.all.pluck` and the prefix `DISTINCT` query run on every poll | `paused_queues` 22% of a `*` idle poll (138 k of 630 k Ir); 7-queue list 2.66 M Ir, 1,038 objects | Re-reading pauses every poll is how a pause takes effect without restarting the worker; caching them changes behaviour. Per-queue transactions are the design for queue order. Not exact. |
| SCB2 | Solid Cable writer: `channel_hash_for` per message | 3–13% of a flush (SHA-256 + `unpack1`) | Native digest; the hash is the stored key. Nothing to remove. |
| SCA1 | Solid Cache: `LazyEntry#value` inflate and load | 27–36% of a read hit | Native Zlib and Marshal on the payload; the work is the read. |
| SCA2 | Arel `visit_Arel_Nodes_BoundSqlLiteral` placeholder `scan` on Solid Cache's cached SQL | 7% of a read hit, 13% of a miss | Rails; census 3 recorded the same scan (`to_sql.rb:826`) and left it. Solid Cache caches the SQL string but goes through `Arel.sql(sql, *binds)` every call; a cheaper call shape is Solid Cache's to choose, and the effect per read is ~20 k Ir. Recorded, not built. |
| – | `escape!`, `URI::GID.build`, `Time#change` Rationals, query-cache key hashing in general | see rankings | Covered: [serialization-cpu](serialization-cpu.md), background census uri lead, CP-4 (not exact), #59518 (open, another author). |

## Limits

* One app shaped after Fizzy, not the census apps themselves: Fizzy and Loomio boot on Rails main in the census
  corpus with their test adapters, and their production stack config needs separate databases the corpus doesn't
  provision. The payloads and configs are theirs.
* The pollers run on the measuring thread with their own threads stopped; Solid Queue's heartbeat and the
  supervisor are not measured.
* No YJIT or ZJIT pass over the whole census table; the candidate has its own (queue item).
