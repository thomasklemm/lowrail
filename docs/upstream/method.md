# How Lowrail finds and measures upstream changes

Lowrail runs real open-source Rails apps on Rails main, finds work that the framework does on every request and
that it could avoid, and proposes the smallest exact change upstream. This page explains how candidates are chosen,
what is measured before a PR is opened, and what the merged changes add up to.

## 1. Find: an allocation census of real apps

[`script/census`](census.md) moves about 20 open-source apps onto one pinned Rails main commit and runs their
request, job and mailer workloads: 251 workloads in [census 7](rails-main-census-7.md), on SQLite, PostgreSQL and
MySQL, in the interpreter and under YJIT. The apps include Mastodon, Discourse, Lobsters, Chatwoot, Sure, Fizzy,
Campfire, Writebook, Loomio and CASA. Each app keeps its own code; only Rails and the gems it needs change.

For every workload the census counts the objects allocated per source line. Allocation counts are deterministic,
so small differences are measurable across many apps at once, unlike wall time. Every round runs twice as an A/A
pair to show the noise floor.

Lines are ranked by breadth first (how many apps reach them), then by objects per workload. A line that every app
runs on every request ranks above a large saving in one app. Before anything is built, open and closed PRs that
touch the line are searched, so known work is not duplicated.

## 2. Build: the smallest exact change

A candidate must behave exactly as before for every caller, not only for the apps measured: the same calls on user
objects, in the same order, with subclasses, frozen and mutated arguments, exceptions and overridden methods
covered. Each candidate is checked against the original by a differential harness, plus the framework's own test
suites with `RAILS_STRICT_WARNINGS=1`. Two independent model reviews (correctness and
maintainability) read every change before it is opened.

A change that makes the code noticeably harder to read is shrunk or dropped, even when it is exact and saves work.

## 3. Price: per call, per benchmark, per app

Each candidate is measured three ways, always against the same commit without it, run twice as an A/A pair:

* **Per call:** objects, and Callgrind instruction counts with GC disabled, on Ruby 4.0.7 (interpreter and YJIT)
  and Ruby master (ZJIT). Wall time on shared machines is noisier than these effects, so instruction counts carry
  the comparison.
* **ruby-bench:** railsbench, lobsters and shipit, to place the change in a whole benchmark. Most single changes
  are within noise there, and the PR says so.
* **The census again:** how many workloads move, and by how much.

A candidate whose CPU gain stays within the A/A and that adds code is not opened.

## 4. What the merged changes add up to

Single changes are small by design. Measured together, as Rails main against the same commit with the merged PRs
reverted ([combined effect](combined-effect.md)):

* **11 PRs**, 16 apps, 206 workloads: 1.66% fewer allocations (interpreter) and 1.64% (YJIT); every app moves, no
  workload allocates more.
* **22 PRs**, on Ruby master: 3.27% fewer allocations interpreted and 3.21% under ZJIT on 9 apps; ZJIT runs 0.54%
  (railsbench) and 0.49% (lobsters) fewer instructions per iteration, outside the A/A.

These are allocation and instruction savings. For the 11 PRs, wall time on railsbench and lobsters was a tie
within the A/A and GC runs per iteration did not change, so no request speedup is claimed.

## What Lowrail does not do

* Claim speed from allocation counts.
* Change Rails only to suit one JIT: ZJIT findings go to the [ZJIT tracker](https://github.com/Shopify/ruby/issues)
  instead.
* Hide what was not changed: rejected candidates and the reasons are recorded next to the accepted ones
  ([contributions](contributions.md)).
