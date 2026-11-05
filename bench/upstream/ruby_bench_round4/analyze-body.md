Fixes #527. I didn't see a PR from @rubys yet, so I opened this one.

As @alanwu-shopify-inc suggested there, `benchmark.rb` now runs `ANALYZE` on the in-memory copy right after the backup restore, instead of shipping statistics in the fixture. `production.sqlite3` has no `sqlite_stat1`, so SQLite runs the hottest-stories query (`/`, `/recent`, `/rss`) through `index_stories_on_merged_story_id` and sorts in a temp B-tree, instead of reading `hotness_idx` in order and stopping at the LIMIT. With statistics, that query takes 0.08 ms instead of 10.8 ms here (SQLite 3.54.1, the repro from #527). `ANALYZE` itself takes about 30 ms and runs before warmup.

Ruby 4.0.7 on Linux x86_64, average of the 20 iterations after 5 warmups, with the runs interleaved:

| | before | after |
| --- | ---: | ---: |
| interpreter (5 runs each) | 1,348–1,565 ms, median 1,479 | 1,319–1,366 ms, median 1,359 |
| YJIT (2 runs each) | 896, 910 ms | 809, 831 ms |

The runs without statistics also vary more. All 114 responses are still 200, and each pass still runs 11,198 SQL queries. Every response except the five `/reply` pages, which differ from run to run anyway, is byte-identical with and without statistics. As with #564, lobsters results from before and after this change are not directly comparable.

The other database benchmarks don't get `ANALYZE`. In railsbench, activerecord and sequel it changes no query plan, since their tables have no index besides the primary key. In shipit it changes 6 of 23 plans, but saves under 0.02% of an iteration. erubi-rails doesn't load Active Record.
