# blog experiments (2026-11-06)

Scripts and raw results behind [ruby-bench-blog-findings.md](../../../../docs/upstream/ruby-bench-blog-findings.md).
Tree: ruby-bench `65151273f6` plus `v-exp.diff`. `mkvariant.sh` builds the Rails/sqlite3 variants, `cg_batch.sh` runs
the Callgrind batch with `../../ruby_bench_round4/audit.rb`, `gcmatch.rb` compares them with GC-matched iterations,
`wall_batch.sh`/`jitall.sh` run the wall checks. Preloads (`ruby -r`): `per_request.rb` (Callgrind dump per request),
`calls_per_request.rb`, `sql_per_request.rb`, `wall_per_request.rb`, `slow.rb` (save-path busy loop, `SLOW_N` turns),
`prof2.rb` (StackProf; `hot.rb` summarises).
