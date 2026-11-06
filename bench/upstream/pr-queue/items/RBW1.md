---
id: RBW1
repo: ruby/ruby-bench
kind: perf
area: new benchmark (writes)
reviewer: claude-code
branch: thomasklemm/blog-benchmark
head: "65151273f6"
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
note: "Thomas opens it as a draft after his final review. The claude-code pass (with thermos) changed the head to 65151273f6; skeptic passes are on 950a2bc27d and Sol has not run, so per the review gates skeptic and Sol still need a pass on 65151273f6"
passes:
  - {reviewer: skeptic, head: "7277a4bced", date: 2026-11-06, verdict: changes, open: "commit message overclaims about lobsters; image_processing loads libvips at boot; dead code; README gaps; all applied"}
  - {reviewer: skeptic, head: "950a2bc27d", date: 2026-11-06, verdict: nits, open: "body: fsync wording, lobsters A/A caveat, savepoint wording, 'timed iteration'; applied to the body. Commit message keeps 'None of them submits a form' (lobsters' login POST is setup, not timed)"}
  - {reviewer: thermos, head: "950a2bc27d", date: 2026-11-06, verdict: changes, open: "run in the claude-code pass; correctness: bootsnap shared iseq cache, frozen clock drops updated_at (both fixed in 65151273f6); maintainability: trim Gemfile, visit tuple layout, setup/iteration ensure shape (judgment, not changed)"}
  - {reviewer: claude-code, head: "65151273f6", date: 2026-11-06, verdict: approve, open: "Reviewed 950a2bc27d with thermos (correctness + maintainability). Fixed in the amended commit: the frozen clock dropped updated_at from 13 of 14 UPDATEs (now advances 1 s per visit, 14/14); bootsnap's iseq cache in tmp/ was shared by builds with the same RUBY_DESCRIPTION (DISABLE_BOOTSNAP); commit message 'None of them submits forms' (lobsters' setup login POST) now 'In their timed iterations'; README notes the dual MIT/Apache license, bootsnap, the clock and non-precompiled assets. Body: the A/A clause said blog 'within 1%' (record: 1.28%) and is cut with the Callgrind/four-dates sentence; clock wording. Verified on 4.0.9: 15 iterations restore rows, max ids and sqlite_sequence in all four DBs, DB files byte-identical after the run, allocations 1.063M +-0.05% (+0.1% vs 950a2bc). Gem trim measured: fresh bundle install 34.3 s full vs 28.6 s without kamal/thruster/dev/test; the 70 s was head compiling sqlite3+nokogiri, which production needs. Fork CI run 42247699359 on 65151273f6: 15/15 green, blog ran on Linux ruby/head, Windows ruby/head and TruffleRuby. Not changed (judgment): visit tuple layout, setup begin/ensure, Gemfile trim, body length ~400 words vs the 150-word guide."}
---

The Rails benchmarks here mostly read. In their timed iterations none of them submits a form, fails a validation, or runs after-commit callbacks and broadcasts; lobsters' only writes are its read-ribbon bookkeeping, and its route generator leaves POSTs out ("For now, skip it"). Real apps spend much of their time saving records: validations, callbacks, transactions, INSERT/UPDATE/DELETE and enqueuing jobs.

This adds `blog`, a small app that writes. It is Sam Ruby's [create-blog](https://github.com/roundhouse-rb/roundhouse/blob/aa60799f53b36084c6311ffcda8f14e746eebf79/scripts/create-blog) (MIT): `rails new --css tailwind` on Rails 8.1.4.1 with Article and Comment scaffolds, validations and Turbo broadcasts. It keeps the production defaults of `rails new`: SQLite, Solid Cache, Solid Queue, Solid Cable, Propshaft and importmap, with no external services. The built Tailwind CSS is checked in, so nothing is built at setup. Its README lists the few changes to the generated app.

An iteration calls the app in-process, like railsbench, with 200 seeded visits (about 420 requests): the index, articles and their JSON; creating, updating and deleting articles; adding and deleting comments; and a create that fails validation with a 422. Each write submits the CSRF token from the page's form and follows the redirect, and every response is checked for its status and a body marker or redirect target. The iteration runs in one transaction per database that is rolled back at the end, as in Rails tests, so every iteration starts from the same rows and IDs. `Time.now` starts at a fixed date and advances one second per visit, so the work doesn't depend on the date.

What it leaves out: nothing ever commits, so a real COMMIT and its WAL write aren't measured. Saves run as savepoints inside the iteration's transaction, and commit callbacks run when each savepoint is released, as they do in Rails tests. Solid Cable inserts each broadcast in the request instead of batching it on its writer thread, so the insert lands in the transaction. Solid Queue jobs are enqueued but not run.

| ms per iteration | interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| blog | 1,537 | 920 | 995 |
| lobsters | 1,127 | 662 | 750 |

Allocations per iteration varied by less than 0.1% between iterations, with no growth. Times are Ruby master with `./run_benchmarks.rb --interleave` on one 4-vCPU VM, so they are rough.

Would a write workload like this be welcome? Happy to reshape it.
