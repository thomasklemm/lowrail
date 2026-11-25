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
impact: "Unreleased since #59844 (cole-robertson, merged by byroot 2026-11-19): LeaseRegistry#lease takes a Mutex on every lease_connection/with_connection/active_connection?, i.e. on every query. Census 11 c11m: LeaseRegistry#lease self 0.091% of all interpreted Ir, 69 of 71 workloads in 8/8 apps, median 0.107%, max 0.261% (inclusive up to 0.77%). Bisect: +3.9k to +4.5k Ir per association reader at #59844, objects unchanged. Lockless hit, interpreter: has_many -1.03%, has_one -1.07%, belongs_to -1.19%, joins -0.78% (A/A <= 0.04%); YJIT flat cells: joins -1.4% (A/A 0.05%), readers within A/A. Census 11 (docs/upstream/rails-main-census-11.md#lr1)."
rank: 8
risky: true
state: built
pr:
note: "2026-11-25 (census 11): built on main cf0325a832, one line (self[context] || synchronize { fetch_or_store }). Exactness argument: WeakKeyMap#[] and #clear are each atomic (GVL on MRI, the map's own mutex elsewhere, #59887), so a lockless hit returns a lease that existed before any concurrent clear, which is the locked lookup's 'before clear' ordering; a miss still creates under @lease_mutex, so new leases get the current flag. Tests: connection_pool, connection_handler, connection_swapping_nested, reaper, query_cache: SQLite 277 runs 1573 assertions 0F 2 skips; PostgreSQL 277 runs 1600 assertions 0F. Ownership: no open rails/rails PR changes LeaseRegistry#lease (8 open PRs touch connection_pool.rb: #59698, #57253, #59885, #59822, #59701, #59699, #59172, #58802); #59844's review (byroot) has no performance discussion; #59883 closed, #59887 merged (non-MRI deadlock follow-up); not in our queue. risky: concurrency, so Astra is required. Needs: a thermos pass with a concurrency probe (disconnect during lookup, JRuby/TruffleRuby path via the non-MRI WeakKeyMap), a body benchmark from script/upstream-bench with a benchmark-ips lead, Ruby master x ZJIT micro, Thomas's OK. Raw: docs/upstream/data/rails-main-census-11/raw/lr1, bisect/."
passes: []
---

# Look up an existing connection lease without the registry mutex

Since #59844, `LeaseRegistry#lease` takes a mutex on every call, so `lease_connection`, `with_connection` and `active_connection?` do too, once or more per query. The mutex is needed when a lease is created, so that it gets the terminated flag of the registry that stores it. This returns an existing lease without it; a lookup that misses still creates the lease under the mutex.

A lease found without the mutex is one that existed before any concurrent `disconnect` cleared the registry, which is what the locked lookup returns when it runs first, and `disconnect` still marks it terminated.

Callgrind instructions per call, Ruby 4.0, no JIT, objects unchanged:

| | main | this change |
|---|---:|---:|
| `author.posts` (has_many, 3 rows) | 673,718 | 666,795 |
| `author.profile` (has_one) | 541,443 | 535,631 |
| `Author.joins(:posts).to_sql` | 356,642 | 353,877 |
