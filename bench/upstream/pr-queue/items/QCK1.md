---
id: QCK1
repo: rails/rails
kind: perf
area: Active Record, query cache
reviewer:
branch: thomasklemm/query-cache-key-hash-once
head: "1e29210c886662fdbf337a2b2e36252171c37eb5"
base: main
built_on: "2e299253f9"
introduced_by:
depends_on: []
tracker: []
stacked_on:
alternative_of:
evidence: [docs/upstream/data/rails-82-leads, bench/upstream/census13r/body/QCK1, bench/upstream/census13r/body/QCK1-master, bench/upstream/census13r/data/probe, bench/upstream/census13r/data/qck1-thermos-sol-2026-11-27.tar.xz]
impact: "Every query with binds under the query cache (on by default in requests and jobs; every Rails app). QueryCache::Store's LRU deletes and reinserts the key on a hit and deletes before inserting on a miss (85742ce529, 2024-01), so each lookup hashed [sql, binds] twice: the SQL string and every bind. #59518 (merged 2026-11-27) memoized QueryAttribute#hash, and #59505 removed a third hash on a miss; what is left is the second full key hash (about 7.2k Ir for a 2-bind key on 4.0.10). Census, Rails main 2e299253f9 (#59518 included), Ruby 4.0.10, 4 apps / 36 workloads, interpreted Ir per request: median -0.27%, casa median -0.48%, max -0.71%, A/A median -0.03%, p90 |d| 0.32%. Exact head, script/upstream-bench, Ruby 4.0.10, interpreter: find hit -3.7%, find miss -2.7%, where with 3 binds hit -2.0%, miss -1.8% (A/A <= 0.05%), objects unchanged; YJIT find hit -7.3% JIT-flat (A/A 0.15%), other YJIT cells not JIT-flat. Master 0d399335b7 (body/QCK1-master): interpreter -2.0% to -3.3%; ZJIT, all JIT-flat, A/A <= 0.05%: find miss -5.1%, hit -7.5%, where 3 binds miss -4.1%, hit -4.9%. Measured commit b41aaa307b (fork ref thomasklemm/qck1-measured-b41aaa307b) has the same tree as the head. Lifetime: runs on Ruby master and Rails main."
rank: 2
risky: true
state: built
pr:
note: "2026-11-27 (after thermos-sol changes on e1978ba23b): head 1e29210c88. Key is now Struct.new(:sql, :binds) with a memoized hash, so equality is the built-in composite eql? as Array's was (fixes the private-eql?/Array-subclass/false-eql? differences the review reproduced); the cost-narration comment is gone; body and commit say hits and synchronous misses hash twice (an async miss hashes once and stores nothing). No new test: Struct equality is the same built-in composite as Array's, existing select_all/exists? cache tests cover distinct-but-equal keys, and DECISIONS keeps tests to plausible regressions; the reviewer's exotic cases are in its probe. Probe byte-identical to main (ps on/off); query_cache, bind_parameter, finder on SQLite with the branch Gemfile: 373 runs, 0 failures. Body numbers, census label and a1.xxlarge timing are rerun on this head; the table below is from e1978ba23b until replaced. New helper rule (DECISIONS 0734f6de): the avoidable work is in Store's LRU, shared by both lookups; the fix is one Key type used by both, no caller fast path. Earlier: 2026-11-27 (Rails 8.2 leads round, docs/upstream/rails-82-leads-2026-11-27.md): built and measured; risky because caching (critical per DECISIONS), so Astra runs adversarially after thermos-sol. Differential probe (bench/upstream/census13r/probe.rb, data/probe): byte-identical to main for hits, misses, eviction at max size 3, string and JSON binds, raw find_by_sql binds, async, uncached, lock and write-clears, prepared statements on and off. Tests: the first run loaded main's activerecord through main's Gemfile and is void; rerun with the branch Gemfile, activerecord SQLite suite on the head tree: 10,485 runs, 37,484 assertions, 0 failures, 4 errors (sqlite_rake_test needs the sqlite3 CLI; fails the same on main), 52 skips. Known boundary: switchman (unreleased support for 8.2, declares activerecord < 8.2) overrides cache_sql with its own [sql, binds] keys; those still work, only lookup_sql_cache (async) would not hit them. Wall time runs on an a1.xxlarge orb."
ownership: {date: 2026-11-27, checked: ["open PRs naming initialize, eql?, lookup_sql_cache, cache_sql that change activerecord/lib/active_record/connection_adapters/abstract/query_cache.rb"], hits: []}
passes:
  - {reviewer: thermos-sol, head: "1e29210c886662fdbf337a2b2e36252171c37eb5", orb: T-01a21eb9-c0e3-733d-b394-fbdeda571174, date: 2026-11-27, verdict: changes, open: "Both rubrics personally, no delegation. Key#eql? newly raises for private equality on bind Array/SQL String arguments and loses Array's identity shortcut; use built-in composite equality (Struct experiment keeps allocations and most gain) plus a behavioural regression test. Delete the added cost comment. Narrow twice-per-query claims to hits/synchronous misses and fix equality before claiming it unchanged. Relevant own-Gemfile SQLite and PostgreSQL suites pass on both trees. Worst measured input is an empty-cache short-SQL async miss, +0.7% Ir, A/A 0.00052%, objects unchanged; not a wall-time claim. Sentence audit, exactness, Switchman boundary and raw archive in docs/upstream/rails-82-leads-2026-11-27.md, QCK1 thermos-sol. Pending a1.xxlarge benchmark-ips text needs a short confirm."}
---

# Hash query cache keys with binds once per lookup

While profiling a few Rails apps, query cache lookups showed up hashing their key twice. The store keeps entries in insertion order for its LRU eviction, so a hit deletes its key and inserts it again, and a miss deletes the key before inserting the result. For a query with binds the key is `[sql, binds]`, so the SQL string and every bind are hashed twice on each hit and each synchronous miss.

This makes the key a small Struct of the SQL and the binds that memoizes its hash. Equality is unchanged: Struct compares its members with `eql?`, as the array did.

Callgrind instructions per query with the query cache enabled, Ruby 4.0.10, no JIT, objects unchanged:

| | main | this change |
|---|---:|---:|
| `Post.find(id)`, hit | 244,840 | 235,672 |
| `Post.find(id)`, miss | 321,182 | 312,662 |
| `where` with 3 binds, hit | 540,910 | 529,898 |
| `where` with 3 binds, miss | 604,053 | 592,998 |
