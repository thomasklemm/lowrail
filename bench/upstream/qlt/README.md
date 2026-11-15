# QLT: query log tags and prepared statements

Record: [p-map.md, QLT](../../../docs/upstream/p-map.md#query-log-tags-and-prepared-statements-qlt). Raw output:
[`data/p-map/qlt/`](../../../docs/upstream/data/p-map/qlt/).

Census copies `censusqlt-blog`, `censusqlt-lobsters` (`script/census setup --corpus censusqlt`, Rails 50c54eed06,
Ruby 4.0.9; Lobsters with activerecord-typedstore at 263050a196) and `censusqltpg-blog` (a copy of the Blog with
its primary database on PostgreSQL and `pg` in the census Gemfile). Each copy's production.rb ends its configure
block with the `eval` line that `config.rb` names.

* `probe_matrix.sh`: queries, SQLite compiles and their wall time, statement pool sizes and PG backend CPU per request.
* `ir_matrix.sh` (`ir.sh`): Callgrind instructions per request; `split.sh`: SQLite's share of them.
* `ips_matrix.sh` (`ips.rb`, summarized by `ips_best.rb`): benchmark-ips, interleaved with an A/A.
* `pg_server.sh`: PostgreSQL backend CPU per request, three rounds.
* `statements.rb`: statement pool size after every workload; `binds.rb`: binds per Lobsters story page.
