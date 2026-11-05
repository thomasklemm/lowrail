Fixes #149.

[rails/rails@01e33f8](https://github.com/rails/rails/commit/01e33f82f829b12273eb66e9fff80bbb36daf12b) made the internal `query_*` methods default to `materialize_transactions: false` on Rails main (8.2.0.alpha). When the try lock is the first statement in a transaction, its `query_value(sql)` now runs before the lazy `BEGIN`, so `pg_try_advisory_xact_lock` is released when that statement ends. This passes `materialize_transactions: true` on the try path, behind the same `internal_exec_query` check as the blocking path, so Rails 8.1 and earlier are unchanged.

The new tests hold a `transaction: true` lock (exclusive, then shared) taken first in its transaction and check that an exclusive try lock returns false. Both fail on Rails main without this change. Full suite on Rails 8.1.4.1 and main `3ba9e53d7e` (Ruby 4.0.9, PostgreSQL 15, MariaDB 10.11): green except `TrilogyMultiAdapterIsolationTest`, which fails on master here too because MySQL and Trilogy share one local MariaDB server.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/f38c7012d8fc0902025e9ef1d5399309622fc1e8/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
