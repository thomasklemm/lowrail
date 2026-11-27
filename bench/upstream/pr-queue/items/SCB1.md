---
id: SCB1
repo: rails/solid_cable
fork: thomasklemm/solid_cable
kind: perf
area: Listener#listen (the poll loop)
reviewer: npezza93
branch: thomasklemm/listener-without-query-cache
head: "ef534cc9414375d5c97339a4c05bb8f3c50fe81a"
base: main
built_on: "40dd29ffdc"
depends_on: []
stacked_on:
alternative_of:
impact: "Every process with Solid Cable (the Rails 8 default cable adapter, 24.7 M downloads) polls every 0.1 s by default, idle or not. With 20 subscribed streams an idle poll runs -14.5% instructions without a JIT and -23.2% under YJIT (A/A <= 0.03%), 3 fewer objects; on a1.xxlarge under YJIT: benchmark-ips +15.9%, wall cohort 204.7 -> 174.2 us per poll, -14.8% [-15.3%, -14.3%] with A/A -0.9% [-1.5%, +0.1%], 30 rounds, JIT-flat (body/SC1-xxl). The one-message case is not JIT-flat at --warmup 500 and is not claimed. The saving grows with the number of streams (one bind per stream in the cache key). Path runs on Ruby master and Rails main; ZJIT on master 0d399335b7: idle poll -23.7% instructions, one message -13.9% (A/A <= 0.04%, JIT-flat)."
evidence: [bench/upstream/solid_stack/body/SC1, bench/upstream/solid_stack/body/SC1-xxl, bench/upstream/solid_stack/body/SC1-zjit, bench/upstream/solid_stack/raw/probes-p1-p2.tar.gz, bench/upstream/solid_stack/sc1_differential.rb, bench/upstream/solid_stack/raw/scb1-thermos-sol-20261127.tar.gz]
rank: 1
risky: true
state: built
pr:
note: "2026-11-27 (T-01a21e77): built from the Rails 8 default stack census (docs/upstream/solid-stack-census.md). risky: query caching and connection state on the listener thread (critical per DECISIONS), so Astra runs adversarially after thermos-sol approves. Differential identical on SQLite and PostgreSQL; suite 47/47 on SQLite, PostgreSQL, Rails 7.2, Rails main."
ownership: {date: 2026-11-27, checked: ["open PRs naming listen that change lib/action_cable/subscription_adapter/solid_cable.rb"], hits: []}
passes:
  - reviewer: thermos-sol
    head: "ef534cc9414375d5c97339a4c05bb8f3c50fe81a"
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

The listener runs every poll inside an executor run, and Active Record turns the query cache on for every executor run. A poll runs one query and the run's cache is cleared when it completes, so the cache never answers a poll, but each poll still builds a cache key from the SQL and one bind per subscribed channel, hashes it and stores the result.

This polls under `uncached`, which turns the query cache off for Solid Cable's connection on the listener thread for the duration of the poll. The poll runs the same query and delivers the same messages.

| One idle listener poll with 20 subscribed channels | main | this branch |
| --- | ---: | ---: |
| Time per poll, Ruby 4.0.10 with YJIT | 205 µs | 174 µs (−15%) |
| Instructions, no JIT / YJIT | 1,698,352 / 930,367 | −14.5% / −23.2% |

The saving grows with the number of subscribed channels.

## For Thomas

What is wrong: Solid Cable's listener thread asks the database every 0.1 seconds for new messages. Each check runs
inside a Rails executor run, and Rails switches the query cache on for every executor run. The cache is emptied at
the end of each run and every check asks only once, so it can never help, but Active Record still builds and hashes
a cache key that contains every subscribed channel. What changes: the check runs inside `Message.uncached { }`.
Why it's safe: the same query runs and returns the same rows; only the unused cache lookup and store are skipped,
only for the cable connection, only on the listener thread.
