---
id: SCB1
repo: rails/solid_cable
fork: thomasklemm/solid_cable
kind: perf
area: Listener#listen (the poll loop)
reviewer: npezza93
branch: thomasklemm/listener-without-query-cache
head: "155a2fbe9878ca820a593abf1cb22df646010d2e"
base: main
built_on: "40dd29ffdc"
depends_on: []
stacked_on:
alternative_of:
impact: "By default (query cache on, the Rails 8 cable template's 0.1 s polling), each started Solid Cable listener (24.7 M downloads; started lazily on the first subscription) polls with one bind per subscribed channel. With 20 channels an idle poll runs -14.5% instructions without a JIT, -23.2% under YJIT, -23.7% under ZJIT on master (A/A <= 0.06%, JIT-flat), 3 fewer objects; benchmark-ips under YJIT on a1.xxlarge +15.9% (body/SC1-xxl; wall cohort -14.8%, A/A interval contains 0). The saving depends on the bind count: on SQLite 998 channels -31.9%, 999 channels and more (no binds past the limit) -0.3%. Worst measured cost: zero channels +5.1% instructions, query_cache: false +2.9% (thermos-sol record), no wall-time loss shown. Path runs on Ruby master and Rails main."
evidence: [bench/upstream/solid_stack/body/SC1, bench/upstream/solid_stack/body/SC1-xxl, bench/upstream/solid_stack/body/SC1-zjit, bench/upstream/solid_stack/raw/probes-p1-p2.tar.gz, bench/upstream/solid_stack/sc1_differential.rb, bench/upstream/solid_stack/raw/scb1-thermos-sol-20261127.tar.gz]
rank: 1
risky: true
state: built
pr:
note: "2026-11-27 (T-01a21e77, after thermos-sol changes on ef534cc): head 155a2fbe98 amends only the commit message (tree identical, same parent 40dd29ffdc); body, impact and For Thomas qualified (default cache, started listener, the pool Solid Cable uses, shared primary pool), scaling sentence cut, body leads with benchmark-ips from SC1-xxl. ZJIT --wall on a1.xxlarge pending. Earlier: built from the Rails 8 default stack census (docs/upstream/solid-stack-census.md). risky: query caching and connection state on the listener thread (critical per DECISIONS), so Astra runs adversarially after thermos-sol approves. Differential identical on SQLite and PostgreSQL; suite 47/47 on SQLite, PostgreSQL, Rails 7.2, Rails main."
ownership: {date: 2026-11-27, checked: ["open PRs naming listen that change lib/action_cable/subscription_adapter/solid_cable.rb"], hits: []}
passes:
  - reviewer: thermos-sol
    head: "155a2fbe9878ca820a593abf1cb22df646010d2e"
    date: 2026-11-27
    orb: T-01a21eb4-4fce-7727-bded-abfba4ffb64e
    verdict: changes
    open: >-
      No demonstrated code defect; shared-helper rule passes. Qualify default/subscribed polls, lazy listener reach
      and shared-pool wording in body/commit/impact; cut unconditional scaling and correct inclusive 51% attribution;
      supply required master ZJIT --wall A/A evidence; lead body with existing SC1-xxl benchmark-ips row.
      Full sentence-by-sentence audit, exactness checklist, suites, PR 91/96 combinations, measured worst input
      and exclusions in docs/upstream/solid-stack-census.md (SCB1 detailed review, 2026-11-27).
---

# Poll for messages without the query cache

The listener polls inside an executor run, and by default Active Record enables the query cache for every executor run. A poll runs its query once and the cache is cleared when the run completes, so the cache never answers a poll. With subscribed channels, each poll still builds a cache key from the SQL and its binds, one per channel, hashes it and stores the result.

This polls under `uncached`, which turns the query cache off for the pool Solid Cable uses (the primary pool when Solid Cable has no database of its own), on the listener thread only, and restores it when the poll ends. The poll runs the same query and delivers the same messages.

| One idle listener poll with 20 subscribed channels | main | this branch |
| --- | ---: | ---: |
| benchmark-ips, Ruby 4.0.10 with YJIT | 4.6k i/s | 5.3k i/s (+16%) |
| Instructions, no JIT / YJIT | 1,698,352 / 930,367 | −14.5% / −23.2% |

## For Thomas

What is wrong: once something subscribes, Solid Cable's listener thread asks the database every 0.1 seconds (the
default) for new messages. Each check runs inside a Rails executor run, and by default Rails switches the query
cache on for every executor run. The cache is emptied at
the end of each run and every check asks only once, so it can never help, but Active Record still builds and hashes
a cache key that contains every subscribed channel. What changes: the check runs inside `Message.uncached { }`.
Why it's safe: the same query runs and returns the same rows; only the unused cache lookup and store are skipped,
only for the pool Solid Cable uses (the primary pool if it has no database of its own), only on the listener
thread, and the previous setting comes back after each check.
