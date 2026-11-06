---
id: RBW1
repo: ruby/ruby-bench
kind: perf
area: new benchmark (writes)
reviewer: claude-code
branch: thomasklemm/blog-benchmark
head: "a233212fad"
base: main
built_on: "ad63bf8"
depends_on: []
stacked_on:
alternative_of:
impact: first ruby-bench workload that writes (validations, callbacks, transactions, Turbo broadcasts)
rank: 3
risky: false
state: reviewed
pr:
note: "Thomas approved preparing it as a draft; the coordinator runs Sol and opens it. a233212fad (amended from 65151273f6) opens and rolls back the iteration transaction itself when pin_connection! does not (Rails main after rails 9e8fe3955b); all four databases restored after each of 25 iterations on 8.1.4.1 and on main cadf0fc8d6, and 65151273f6 on main fails to restore (control). Body gained a what-it-finds paragraph from docs/upstream/ruby-bench-blog-findings.md and moved the rest under Details. Skeptic and Sol have not run on a233212fad"
passes:
  - {reviewer: skeptic, head: "7277a4bced", date: 2026-11-06, verdict: changes, open: "commit message overclaims about lobsters; image_processing loads libvips at boot; dead code; README gaps; all applied"}
  - {reviewer: skeptic, head: "950a2bc27d", date: 2026-11-06, verdict: nits, open: "body: fsync wording, lobsters A/A caveat, savepoint wording, 'timed iteration'; applied to the body. Commit message keeps 'None of them submits a form' (lobsters' login POST is setup, not timed)"}
  - {reviewer: thermos, head: "950a2bc27d", date: 2026-11-06, verdict: changes, open: "run in the claude-code pass; correctness: bootsnap shared iseq cache, frozen clock drops updated_at (both fixed in 65151273f6); maintainability: trim Gemfile, visit tuple layout, setup/iteration ensure shape (judgment, not changed)"}
  - {reviewer: claude-code, head: "65151273f6", date: 2026-11-06, verdict: approve, open: "Reviewed 950a2bc27d with thermos (correctness + maintainability). Fixed in the amended commit: the frozen clock dropped updated_at from 13 of 14 UPDATEs (now advances 1 s per visit, 14/14); bootsnap's iseq cache in tmp/ was shared by builds with the same RUBY_DESCRIPTION (DISABLE_BOOTSNAP); commit message 'None of them submits forms' (lobsters' setup login POST) now 'In their timed iterations'; README notes the dual MIT/Apache license, bootsnap, the clock and non-precompiled assets. Body: the A/A clause said blog 'within 1%' (record: 1.28%) and is cut with the Callgrind/four-dates sentence; clock wording. Verified on 4.0.9: 15 iterations restore rows, max ids and sqlite_sequence in all four DBs, DB files byte-identical after the run, allocations 1.063M +-0.05% (+0.1% vs 950a2bc). Gem trim measured: fresh bundle install 34.3 s full vs 28.6 s without kamal/thruster/dev/test; the 70 s was head compiling sqlite3+nokogiri, which production needs. Fork CI run 42247699359 on 65151273f6: 15/15 green, blog ran on Linux ruby/head, Windows ruby/head and TruffleRuby. Not changed (judgment): visit tuple layout, setup begin/ensure, Gemfile trim, body length ~400 words vs the 150-word guide."}
---

The Rails benchmarks here mostly read. In their timed iterations none of them submits a form, fails a validation, or runs after-commit callbacks, while real apps spend much of their time saving records.

This adds `blog`, Sam Ruby's [create-blog](https://github.com/roundhouse-rb/roundhouse/blob/aa60799f53b36084c6311ffcda8f14e746eebf79/scripts/create-blog) (MIT): a `rails new --css tailwind` app on Rails 8.1.4.1 with Article and Comment scaffolds, validations and Turbo broadcasts, on the default SQLite, Solid Cache, Queue and Cable stack with no external services. Each iteration makes about 420 in-process requests: reads, creates, updates, deletes, comments and a create that fails with 422, with real CSRF tokens and every response checked. Each iteration runs in one transaction per database that is rolled back at the end, as in Rails tests, with a fixed clock.

What it finds and what it doesn't is below. Would a write workload like this be welcome? Happy to reshape it.

### What it finds, and what it doesn't

It catches changes the other Rails benchmarks never run. A small busy loop injected into `save` and `destroy` adds 2.3% to blog's instructions per iteration, and that code doesn't run at all in railsbench's or lobsters' iterations. Its per-request split also shows where a Rails change lands: on Rails main, reads get 9–14% cheaper while creates stay flat. It adds nothing for per-query or database-driver changes, which move all three benchmarks alike, and its total alone says little, since about two thirds of it is reads much like railsbench's.

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

Allocations per iteration varied by less than 0.1% between iterations, with no growth. Times are Ruby master with `./run_benchmarks.rb --interleave` on one 4-vCPU VM, so they are rough.
