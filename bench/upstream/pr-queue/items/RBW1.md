---
id: RBW1
repo: ruby/ruby-bench
kind: perf
area: new benchmark (writes)
reviewer: claude-code
branch: thomasklemm/blog-benchmark
head: "d761531b83"
base: main
built_on: "0e67be03ef"
depends_on: []
stacked_on:
alternative_of:
impact: first ruby-bench workload that writes (validations, callbacks, transactions, Turbo broadcasts)
rank: 3
risky: false
state: draft
pr: 575
note: "upstream CI 15/15 green on the 2026-11-14 head; Thomas approved preparing it as a draft; the coordinator runs Sol and opens it. a233212fad (amended from 65151273f6) opens and rolls back the iteration transaction itself when pin_connection! does not (Rails main after rails 9e8fe3955b); all four databases restored after each of 25 iterations on 8.1.4.1 and on main cadf0fc8d6, and 65151273f6 on main fails to restore (control). Body gained a what-it-finds paragraph from docs/upstream/ruby-bench-blog-findings.md and moved the rest under Details. Fork CI run 42289316995 on a233212fad: 15/15 green, including Windows ruby and head; fork PR #16 closed. Sol on a233212fad: changes, applied in 537f5752f5 (README JRuby note; body driver-overlap wording, record link, iteration count). 537f5752f5 differs from a233212fad only by two README lines; fork CI did not run on it (PR #16 closed, test.yml runs on PRs and main), so run 42289316995 covers the code. Skeptic has not run on a233212fad or later; Sol confirm pending on 537f5752f5; 2026-11-14: rebased onto 0e67be03ef without changes (range-diff identical to 537f5752f5) and force-pushed with a lease; the passes below are on 537f5752f5, the same patch"
passes:
  - {reviewer: skeptic, head: "7277a4bced", date: 2026-11-06, verdict: changes, open: "commit message overclaims about lobsters; image_processing loads libvips at boot; dead code; README gaps; all applied"}
  - {reviewer: skeptic, head: "950a2bc27d", date: 2026-11-06, verdict: nits, open: "body: fsync wording, lobsters A/A caveat, savepoint wording, 'timed iteration'; applied to the body. Commit message keeps 'None of them submits a form' (lobsters' login POST is setup, not timed)"}
  - {reviewer: thermos, head: "950a2bc27d", date: 2026-11-06, verdict: changes, open: "run in the claude-code pass; correctness: bootsnap shared iseq cache, frozen clock drops updated_at (both fixed in 65151273f6); maintainability: trim Gemfile, visit tuple layout, setup/iteration ensure shape (judgment, not changed)"}
  - {reviewer: claude-code, head: "65151273f6", date: 2026-11-06, verdict: approve, open: "Reviewed 950a2bc27d with thermos (correctness + maintainability). Fixed in the amended commit: the frozen clock dropped updated_at from 13 of 14 UPDATEs (now advances 1 s per visit, 14/14); bootsnap's iseq cache in tmp/ was shared by builds with the same RUBY_DESCRIPTION (DISABLE_BOOTSNAP); commit message 'None of them submits forms' (lobsters' setup login POST) now 'In their timed iterations'; README notes the dual MIT/Apache license, bootsnap, the clock and non-precompiled assets. Body: the A/A clause said blog 'within 1%' (record: 1.28%) and is cut with the Callgrind/four-dates sentence; clock wording. Verified on 4.0.9: 15 iterations restore rows, max ids and sqlite_sequence in all four DBs, DB files byte-identical after the run, allocations 1.063M +-0.05% (+0.1% vs 950a2bc). Gem trim measured: fresh bundle install 34.3 s full vs 28.6 s without kamal/thruster/dev/test; the 70 s was head compiling sqlite3+nokogiri, which production needs. Fork CI run 42247699359 on 65151273f6: 15/15 green, blog ran on Linux ruby/head, Windows ruby/head and TruffleRuby. Not changed (judgment): visit tuple layout, setup begin/ensure, Gemfile trim, body length ~400 words vs the 150-word guide."}
  - {reviewer: sol, head: "a233212fad", date: 2026-11-06, verdict: changes, open: "1 JRuby: native sqlite3, no JDBC or exclusion (README note added; ruby-bench has no per-engine exclusion, lobsters and shipit do the same); 2 body said driver changes move all three alike (#770 shows only on lobsters; reworded); 3 the 2.3% and 9-14% lacked provenance (pinned link to the findings record); 4 'no growth' unqualified (now 28 iterations after two warmups). No rollback leak; transaction design sound"}
  - {reviewer: claude-code, head: "537f5752f5", date: 2026-11-06, verdict: approve, open: "Delta 65151273f6..a233212fad (own non-joinable transaction when pin_connection! has none, as Rails main test_fixtures does) plus the Sol points. Rails 8.1.4.1: 30 iterations, all four DBs restored, files byte-identical; per iteration one BEGIN and one ROLLBACK on each of primary, cable, queue and cache, no COMMIT, 101 primary and 164 queue SAVEPOINT/RELEASE pairs; the in-iteration 117 Cable / 82 job assertions pass, so after_commit broadcasts fire on RELEASE. Rails main 8e8a9bb3 (8.2.0.alpha): identical transaction counts, 6 iterations restored, files byte-identical. 9e8fe3955b confirmed to remove begin/rollback from pin/unpin. Allocations 1.063M, spread 0.050% over 28 iterations, first vs last ten -0.004%. Body line 9 against ruby-bench-blog-findings.md: 2.3%, 9-14% (reads 9.3-14.0%), creates flat (-1.6/+0.5/-0.3%) and two thirds reads (68%) hold; the driver claim did not (fixed). Revisions are named in the linked record, not the body (no SHAs in PR bodies). Commit clean: Thomas both, no trailers."}
  - {reviewer: sol, head: "537f5752f5", date: 2026-11-06, verdict: approve, open: "confirm pass: all four a233212fad points resolved (JRuby README note, driver claim scoped to the A/B runs, provenance pinned, no-growth qualified); none"}
waived:
  - {reviewer: thermos, head: "537f5752f5", by: coordinator, reason: "Thermos ran on 950a2bc27d in the claude-code pass (fixes in 65151273f6); the delta since is the rollback fix (own transaction when pin_connection! has none) plus README/body, approved by claude-code and Sol on this head; most of the 3,600 lines are the generated app"}
---

# Add a blog benchmark that writes

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
