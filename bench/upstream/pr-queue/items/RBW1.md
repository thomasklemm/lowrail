---
id: RBW1
repo: ruby/ruby-bench
kind: perf
area: new benchmark (writes)
reviewer:
branch: thomasklemm/blog-benchmark
head: "950a2bc27d"
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
note: "Thomas opens it as a draft after his final review. Only skeptic passes; queue rules also want Sol and, with ~2,000 changed lines (mostly the generated app), thermos"
passes:
  - {reviewer: skeptic, head: "7277a4bced", date: 2026-11-06, verdict: changes, open: "commit message overclaims about lobsters; image_processing loads libvips at boot; dead code; README gaps; all applied"}
  - {reviewer: skeptic, head: "950a2bc27d", date: 2026-11-06, verdict: nits, open: "body: fsync wording, lobsters A/A caveat, savepoint wording, 'timed iteration'; applied to the body. Commit message keeps 'None of them submits a form' (lobsters' login POST is setup, not timed)"}
---

# Add a blog benchmark that writes

The Rails benchmarks here mostly read. In their timed iterations none of them submits a form, fails a validation, or runs after-commit callbacks and broadcasts; lobsters' only writes are its read-ribbon bookkeeping, and its route generator leaves POSTs out ("For now, skip it"). Real apps spend much of their time saving records: validations, callbacks, transactions, INSERT/UPDATE/DELETE and enqueuing jobs.

This adds `blog`, a small app that writes. It is Sam Ruby's [create-blog](https://github.com/roundhouse-rb/roundhouse/blob/aa60799f53b36084c6311ffcda8f14e746eebf79/scripts/create-blog) (MIT): `rails new --css tailwind` on Rails 8.1.4.1 with Article and Comment scaffolds, validations and Turbo broadcasts. It keeps the production defaults of `rails new`: SQLite, Solid Cache, Solid Queue, Solid Cable, Propshaft and importmap, with no external services. The built Tailwind CSS is checked in, so nothing is built at setup. Its README lists the few changes to the generated app.

An iteration calls the app in-process, like railsbench, with 200 seeded visits (about 420 requests): the index, articles and their JSON; creating, updating and deleting articles; adding and deleting comments; and a create that fails validation with a 422. Each write submits the CSRF token from the page's form and follows the redirect, and every response is checked for its status and a body marker or redirect target. The iteration runs in one transaction per database that is rolled back at the end, as in Rails tests, so every iteration starts from the same rows and IDs. `Time.now` is fixed while the app runs, as proposed for lobsters in #571.

What it leaves out: nothing ever commits, so a real COMMIT and its WAL write aren't measured. Saves run as savepoints inside the iteration's transaction, and commit callbacks run when each savepoint is released, as they do in Rails tests. Solid Cable inserts each broadcast in the request instead of batching it on its writer thread, so the insert lands in the transaction. Solid Queue jobs are enqueued but not run.

| ms per iteration | interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| blog | 1,537 | 920 | 995 |
| lobsters | 1,127 | 662 | 750 |

Allocations per iteration varied by at most 0.08% over 30 iterations, with no growth, and their mean was the same within 0.004% on four dates. Instructions per iteration (Callgrind) differed by 0.035% between two processes. Times are Ruby master with `./run_benchmarks.rb --interleave` on one 4-vCPU VM, so they are rough: a second copy of each Ruby landed within 1% for blog but 5% (interpreter) and 11% (ZJIT) off for lobsters.

Would a write workload like this be welcome? Happy to reshape it.
