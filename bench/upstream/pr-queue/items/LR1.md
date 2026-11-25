---
id: LR1
repo: rails/rails
kind: perf
area: Active Record, connection pool
reviewer: "byroot (merged #59844)"
branch: thomasklemm/lease-registry-lockless-hit
head: "7e342de11f12e6ee056e6c7ff5df713b2518e03c"
base: main
built_on: "cf0325a832"
depends_on: []
stacked_on:
alternative_of:
impact: "Unreleased since #59844 (cole-robertson, merged by byroot 2026-11-19): LeaseRegistry#lease takes a Mutex on every lease_connection, with_connection and active_connection? call. SELECTs through an adapter that is already leased make no registry lookup (10 of 10 held-adapter select_value calls, 0 lease calls, TracePoint on the exact head). Census 11 (unverified: the final c11c10/c11m/c11m2 per-workload method labels were never committed and could not be recovered, and the retained method net covers 7 apps / 64 workloads): LeaseRegistry#lease self 0.091% of all interpreted Ir, 69 of 71 workloads in 8/8 apps, +0.075% with #checkout_lease and Lease#terminated?. Bisect (replayed): +3.9k to +4.5k Ir per association reset/load at #59844, objects unchanged. Exact head, script/upstream-bench base/head/base, Ruby 4.0.9, interpreter: lease_connection -9.2%, with_connection -8.5%, has_many reset/load -0.8%, has_one -1.0%, belongs_to -1.1%, joins to_sql -0.8% (A/A <= 0.10%); YJIT JIT-flat: lease_connection -13.8%, with_connection -13.0% (A/A <= 0.12%), association and joins cells not JIT-flat, no YJIT claim; benchmark-ips YJIT: lease_connection +33% (A/A 11.7%), has_one reset/load +4.6% (A/A 0.9%). Fresh-context miss: +9.6% / +10.6% (about +700 / +500 Ir) per bare miss, fresh-fiber with_connection still -2.7% / -2.0%. Master e8167b0ddd interpreter -0.6% to -9.2% (A/A <= 0.05%); ZJIT cohort rejected (no invalidation_count), no loss observed. Census 11 (docs/upstream/rails-main-census-11.md#lr1-exact-head-evidence)."
rank: 8
risky: true
state: built
pr:
note: "2026-11-25 (census 11): built on main cf0325a832, one line (self[context] || synchronize { fetch_or_store }). Exactness argument: WeakKeyMap#[] and #clear are each atomic (GVL on MRI, the map's own mutex elsewhere, #59887), so a lockless hit returns a lease that existed before any concurrent clear, which is the locked lookup's 'before clear' ordering; a miss still creates under @lease_mutex, so new leases get the current flag. Tests: connection_pool, connection_handler, connection_swapping_nested, reaper, query_cache: SQLite 277 runs 1573 assertions 0F 2 skips; PostgreSQL 277 runs 1600 assertions 0F. Ownership: no open rails/rails PR changes LeaseRegistry#lease (all 1336 open PRs checked by thermos-sol and Astra: 20 touch the abstract pool, #44478, #45122, #46409, #46805, #49337, #49425, #55792, #57089, #57253, #57517, #57771, #58490, #58587, #58731, #58802, #59172, #59699, #59701, #59822, #59885; none changes LeaseRegistry#lease or weak_key_map.rb); #59844's review (byroot) has no performance discussion; #59883 closed, #59887 merged (non-MRI deadlock follow-up); not in our queue. risky: concurrency, so Astra is required. 2026-11-25 (after astra and thermos-sol): exact-head evidence in bench/upstream/census11/body/{LR1,LR1-miss,LR1-master-zjit} and census 11 #lr1-exact-head-evidence; body rewritten per both reviews (no per-query claim, reset/load labels, disconnect sentence, provenance clause, benchmark-ips lead, one instruction table). Needs: Thomas's OK. Raw: docs/upstream/data/rails-main-census-11/raw/lr1, bisect/."
passes:
  - {reviewer: astra, head: "7e342de11f12e6ee056e6c7ff5df713b2518e03c", date: 2026-11-25, verdict: changes, open: "Code and commit pass both Thermos rubrics; no concurrency defect found. Before opening, replace the census-only body table with script/upstream-bench evidence and a benchmark-ips lead, and delete the universal per-query claim (10 held-adapter SELECTs made zero registry lookups). CRuby/JRuby/TruffleRuby registry stress, threaded/fiber/scheduler association probes, disconnect races, fork and SQLite/PostgreSQL suites passed. See docs/upstream/rails-main-census-11.md#lr1-astra-review."}
  - {reviewer: thermos-sol, head: "7e342de11f12e6ee056e6c7ff5df713b2518e03c", orb: "T-01a2132c-5d2a-7632-8c18-9a2c4923b2e7", date: 2026-11-25, verdict: changes, open: "Both Thermos rubrics applied directly without delegation. No code correctness or structural defect found; creation/insertion stays serialized with clear/flag rotation, and old hits retain termination/revalidation. Exact-head SQLite 277 tests/1573 assertions/2 skips and PostgreSQL 277/1600/0 skips, both 0 failures/errors. Removing checkout lease revalidation makes two existing tests produce 1 failure/1 error on each adapter; controls pass 2/9. Registry schedules: 24 tests/220 assertions across parent/head and native/non-MRI map wrapper on MRI, all pass; no real JRuby/TruffleRuby certification. Interpreter replay confirms readers -1.03% to -1.19%, joins -0.78%, A/A <= 0.04%, objects unchanged. Must fix before opening: cut every-query wording, label reset/load measurements accurately, shorten the concurrent-clear sentence and add provenance; complete exact-head benchmark-ips/body evidence, full JIT gates and pinned master x ZJIT with A/A plus a fresh-context miss control. Old YJIT rows lack full counters, so no certified joins claim. Ownership: all 1336 open PRs checked, 20 touch the pool, none changes LeaseRegistry#lease or WeakKeyMap; introducing/follow-up discussions do not require hit locking. Eight-app method aggregates cannot be replayed here: retained method net covers seven apps/64 workloads. Thomas author/committer, no trailers. Details and smallest fixes: docs/upstream/rails-main-census-11.md#lr1. Independent Astra and Thomas's decision remain separate; no Rails changes or posts."}
---

# Look up an existing connection lease without the registry mutex

While profiling association loads in a few Rails apps, it turned out that since #59844 `LeaseRegistry#lease` takes a mutex on every call, and with it `lease_connection`, `with_connection` and `active_connection?`. The mutex is needed when a lease is created, so that it gets the terminated flag of the registry that stores it. This returns an existing lease without it; a lookup that misses, as on a thread's or fiber's first call, still creates the lease under the mutex. A concurrent disconnect can still invalidate a returned lease, just as it can immediately after a synchronized lookup.

```ruby
# SQLite in memory; the author has three posts and a profile.
Benchmark.ips do |x|
  x.report("lease_connection") { ActiveRecord::Base.lease_connection }
  x.report("has_one reset/load") { author.association(:profile).reset; author.profile }
end
```

Ruby 4.0.9 with YJIT, best of three runs on one core:

```
main
    lease_connection      1.601M (± 2.7%) i/s
  has_one reset/load     14.238k (± 8.4%) i/s
this change
    lease_connection      2.018M (± 5.4%) i/s
  has_one reset/load     14.828k (± 7.4%) i/s
```

Callgrind instructions per call, Ruby 4.0.9, no JIT, objects unchanged:

| | main | this change |
|---|---:|---:|
| `lease_connection` | 14,215 | 12,905 |
| has_many reset/load, 3 rows | 717,925 | 712,157 |
| has_one reset/load | 597,788 | 591,717 |
| `Author.joins(:posts).to_sql` | 355,262 | 352,581 |
