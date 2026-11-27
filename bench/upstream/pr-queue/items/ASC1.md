---
id: ASC1
repo: rails/rails
kind: perf
area: Active Record, associations, connection lookup
reviewer:
branch: thomasklemm/association-load-one-connection-lookup
head: "2b46f50bda446b9d84c3c86ac2f90bec4b7df6db"
base: main
built_on: "2e299253f9"
introduced_by:
depends_on: []
tracker: []
stacked_on:
alternative_of:
evidence: [docs/upstream/data/rails-82-leads, bench/upstream/census13r/body/ASC1, bench/upstream/census13r/body/ASC1-master, bench/upstream/census13r/data/probe]
impact: "Every association load through the statement cache (belongs_to, has_one, has_many, through, polymorphic; every Rails app) resolved the model's connection pool twice: association_scope_cache took the connection in its own with_connection block, then find_target took it again to run the statement; without a leased connection that was two checkouts. The split dates from fa048105d1 (2024-05, with_connection replacing lease_connection); reflection.rb's signature changed again in 7249a66350 (unreleased, #59120). Census, Rails main 2e299253f9, Ruby 4.0.10, 4 apps / 36 workloads, interpreted Ir per request: median -0.26%, max -0.91%; per app medians blog +0.16%, casa -0.26%, react-starter-kit -0.40%, redprints-cfp -0.39% (docs/upstream/data/rails-82-leads/per-workload.tsv), A/A median -0.03%, p90 |d| 0.32%. Exact head, script/upstream-bench, Ruby 4.0.10, interpreter: belongs_to load -3.1%, has_one -3.0%, has_many (3 rows) -2.4% (A/A <= 0.06%), objects unchanged; YJIT cells not JIT-flat, no claim. Connection-lookup lead of the Rails 8.2 round (census 12: 0.81% mean, 68/71; this round 0.75%, 33/36): pool resolution costs about 13.9k Ir per Base.connection_pool call on 4.0.10. Lifetime: runs on Ruby master and Rails main."
rank: 1
risky: true
state: built
pr:
note: "2026-11-27 (Rails 8.2 leads round, docs/upstream/rails-82-leads-2026-11-27.md): built and measured; risky because connection handling (critical per DECISIONS), so Astra runs adversarially after thermos-sol. Differential probe (bench/upstream/census13r/probe.rb, data/probe): identical records and SQL with prepared statements on and off, unleased and leased, async, through, polymorphic, strict_loading; only difference one checkout fewer per unleased load. Tests: associations/**, associations_test, reflection, statement_cache, finder, strict_loading on SQLite: 2336 runs, 8041 assertions, 0 failures. Wall time (benchmark-ips YJIT, --wall YJIT and master ZJIT) runs on an a1.xxlarge orb. Ownership hits: #59212 (bruno-costanzo, skip building the scope on the statement-cache path) changes find_target above these lines, a different concern; git merge-tree with its head is clean. #55002 and #58804 are strict-loading fixes elsewhere in the file. No open PR changes association_scope_cache."
ownership: {date: 2026-11-27, checked: ["open PRs naming find_target, association_scope_cache that change activerecord/lib/active_record/associations/association.rb, activerecord/lib/active_record/reflection.rb"], hits: ["names find_target, changes its file (6 open PRs name it): rails/rails#59212 (PR, open, bruno-costanzo): Don't build the association scope when the reader uses the statement cache","names find_target, changes its file (6 open PRs name it): rails/rails#55002 (PR, open, dewski): Enforce strict loading violations for associations where joins are disabled","names find_target, changes its file (6 open PRs name it): rails/rails#58804 (PR, open, drsharp): Fix has_one_attached/has_many_attached strict_loading raising on attach"]}
passes: []
---

# Look up the connection once per association load

While profiling a few Rails apps, it turned out that association loads through the statement cache resolve the model's connection pool twice. `Association#find_target` fetches the cached statement inside one `with_connection` block and runs it in another, so the pool's specification name, role, shard and lease are looked up again, and without a leased connection a connection is checked out and back in twice.

This fetches the statement inside the block that runs it, so both steps use the same connection. Records and SQL are unchanged; without a leased connection, a load now checks out once instead of twice.

Callgrind instructions per load, Ruby 4.0.10, no JIT, objects unchanged:

| | main | this change |
|---|---:|---:|
| belongs_to | 512,155 | 496,346 |
| has_one | 546,596 | 530,339 |
| has_many, 3 rows | 666,752 | 650,905 |
