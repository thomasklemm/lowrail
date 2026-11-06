The Rails benchmarks here mostly read. In their timed iterations none of them submits a form, fails a validation, or runs after-commit callbacks, while real apps spend much of their time saving records.

This adds `blog`, Sam Ruby's [create-blog](https://github.com/roundhouse-rb/roundhouse/blob/aa60799f53b36084c6311ffcda8f14e746eebf79/scripts/create-blog) (MIT): a `rails new --css tailwind` app on Rails 8.1.4.1 with Article and Comment scaffolds, validations and Turbo broadcasts, on the default SQLite, Solid Cache, Queue and Cable stack with no external services. Each iteration makes about 420 in-process requests: reads, creates, updates, deletes, comments and a create that fails with 422, with real CSRF tokens and every response checked. Each iteration runs in one transaction per database that is rolled back at the end, as in Rails tests, with a fixed clock.

What it finds and what it doesn't is below. Would a write workload like this be welcome? Happy to reshape it.

### What it finds, and what it doesn't

It catches changes the other Rails benchmarks never run. A small busy loop injected into `save` and `destroy` adds 2.3% to blog's instructions per iteration, and that code doesn't run at all in railsbench's or lobsters' timed iterations. Its per-request split also shows where a Rails change lands: from Rails 8.1.4.1 to main, reads take 9–14% fewer instructions while creates stay flat. It overlaps with railsbench and lobsters on per-query and database-driver overhead, and in our A/B runs it didn't separate those changes better. Its total alone says little, since about two thirds of it is reads much like railsbench's. The measurements are in [this record](https://github.com/thomasklemm/lowrail/blob/bfe17841b1529509f60f09554b5468681517eaf0/docs/upstream/ruby-bench-blog-findings.md).

### Details

- **Requests.** 200 seeded visits: the index, articles and their JSON; creating, updating and deleting articles; adding and deleting comments; and the 422. Each write GETs the form, submits its CSRF token and follows the redirect. Every response is checked for its status and a body marker or redirect target.
- **Rollback.** `benchmark.rb` pins each database's connection and opens a non-joinable transaction. Rails 8.1 opens it in `pin_connection!`; Rails main no longer does, so the benchmark opens it itself when none is open. Saves run as savepoints, and commit callbacks run when each savepoint is released, as in Rails tests. Each iteration checks the Solid Cable messages and Solid Queue jobs it wrote.
- **Clock.** `Time.now` starts at a fixed date and advances one second per visit, so the work doesn't depend on the date and updates still write `updated_at`.
- **Left out.** Nothing commits, so a real COMMIT and its WAL write aren't measured. Solid Cable inserts each broadcast in the request rather than on its batching writer thread. Solid Queue jobs are enqueued but never run.
- **Changes to the generated app** are listed in the benchmark's README; the built Tailwind CSS is checked in, so nothing is built at setup.

| ms per iteration | interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| blog | 1,537 | 920 | 995 |
| lobsters | 1,127 | 662 | 750 |

Allocations per iteration varied by less than 0.1% after two warmups, with no growth over 28 iterations. Times are Ruby master with `./run_benchmarks.rb --interleave` on one 4-vCPU VM, so they are rough.
