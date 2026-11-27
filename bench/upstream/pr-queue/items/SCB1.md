---
id: SCB1
repo: rails/solid_cable
fork: thomasklemm/solid_cable
kind: perf
area: Listener#listen (the poll loop)
reviewer: npezza93
branch: thomasklemm/listener-without-query-cache
head: "2cb1842043643d85ddee68aa48d02fd219305d56"
base: main
built_on: "40dd29ffdc"
depends_on: []
stacked_on:
alternative_of:
impact: "By default (query cache on, the Rails 8 cable template's 0.1 s polling), each started Solid Cable listener (24.7 M downloads; started lazily on the first subscription) polls with subscribed channels. With 20 channels an idle poll runs -14.5% instructions without a JIT, -23.2% under YJIT, -23.7% under ZJIT on master (A/A <= 0.06%, JIT-flat); ZJIT wall cohort on master 0d399335b7, a1.xxlarge, 30 rounds: idle 215.4 -> 182.3 us -15.0% [-15.4%, -14.5%] (A/A -0.1% [-0.9%, +0.9%]), one message -6.9% [-8.0%, -5.7%] (A/A +0.3% [-1.0%, +1.2%]), every window JIT-flat (body/SC1-zjit-wall, measured on 155a2fbe98, same tree), 3 fewer objects; benchmark-ips under YJIT on a1.xxlarge +15.9% (body/SC1-xxl; wall cohort -14.8%, A/A interval contains 0). The saving depends on the query shape: on SQLite 998 channels (999 binds) -31.88%, 999 channels (no binds) -0.274%, 65,536 channels (1.4 MB SQL) -0.372% (thermos-sol record). Worst measured cost: zero channels +5.1% instructions, query_cache: false +2.9% (thermos-sol record), no wall-time loss shown. Path runs on Ruby master and Rails main."
evidence: [bench/upstream/solid_stack/body/SC1, bench/upstream/solid_stack/body/SC1-xxl, bench/upstream/solid_stack/body/SC1-zjit, bench/upstream/solid_stack/body/SC1-zjit-wall, bench/upstream/solid_stack/raw/probes-p1-p2.tar.gz, bench/upstream/solid_stack/sc1_differential.rb, bench/upstream/solid_stack/raw/scb1-thermos-sol-20261127.tar.gz, bench/upstream/solid_stack/raw/scb1-confirm-155a2fbe-20261127.tar.gz, bench/upstream/solid_stack/raw/scb1-confirm-2cb18420-20261127.tar.gz]
rank: 1
risky: true
state: built
pr:
note: "2026-11-27 (T-01a21e77, after the thermos-sol confirm on 155a2fbe): head 2cb1842043 rewords the commit message again (no one-bind-per-channel claim), tree and parent unchanged; impact gives the 998/999/65,536 points. Earlier, after thermos-sol changes on ef534cc: head 155a2fbe98 amends only the commit message (tree identical, same parent 40dd29ffdc); body, impact and For Thomas qualified (default cache, started listener, the pool Solid Cable uses, shared primary pool), scaling sentence cut, body leads with benchmark-ips from SC1-xxl. ZJIT --wall on a1.xxlarge is committed in body/SC1-zjit-wall and verified by the final thermos-sol confirm. Earlier: built from the Rails 8 default stack census (docs/upstream/solid-stack-census.md). risky: query caching and connection state on the listener thread (critical per DECISIONS), so Astra runs adversarially after thermos-sol approves. Differential identical on SQLite and PostgreSQL; suite 47/47 on SQLite, PostgreSQL, Rails 7.2, Rails main."
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
  - reviewer: thermos-sol
    head: "155a2fbe9878ca820a593abf1cb22df646010d2e"
    date: 2026-11-27
    orb: T-01a21eb4-4fce-7727-bded-abfba4ffb64e
    verdict: changes
    open: >-
      Confirm: tree and parent identical; fresh SQLite/PG differential and state probes match. Default-cache,
      lazy-listener and shared-pool body wording, inclusive attribution and benchmark-ips lead confirmed.
      Remaining: cut one-bind-per-channel generalization from body/commit/impact (999 channels has zero binds);
      report measured 999/65536 costs separately rather than all larger counts as -0.3%; qualify the record's
      primary-pool-keeps-cache sentence as separate pools only. Must inspect committed master ZJIT --wall A/A
      cohort before unconditional approval; no waiver for the pending run. No new code defect or complexity.
      See SCB1 confirm review in docs/upstream/solid-stack-census.md and scb1-confirm-155a2fbe-20261127.tar.gz.
  - reviewer: thermos-sol
    head: "2cb1842043643d85ddee68aa48d02fd219305d56"
    date: 2026-11-27
    orb: T-01a21eb4-4fce-7727-bded-abfba4ffb64e
    verdict: approve
    open: >-
      None. All prior findings closed: body/commit cache-key wording, measured query-shape points, separate/shared
      primary-pool qualification and required master ZJIT wall cohort verified. Independent audit of all 90 raw
      processes confirms idle -15.0%, one message -6.9%, passing A/A intervals and all timed windows JIT-flat.
      Same tree and parent carry the full review and exactness checklist; fresh SQLite/PG differential and state
      probes are byte-identical base/head. L0; body follows PR description rules. No fork push or upstream post.
      See final confirm in docs/upstream/solid-stack-census.md and scb1-confirm-2cb18420-20261127.tar.gz.
---

# Poll for messages without the query cache

The listener polls inside an executor run, and by default Active Record enables the query cache for every executor run. A poll runs its query once and the cache is cleared when the run completes, so the cache never answers a poll. With subscribed channels, each poll still builds and hashes a cache key before storing the result.

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
a cache key for it before storing the result. What changes: the check runs inside `Message.uncached { }`.
Why it's safe: the same query runs and returns the same rows; only the unused cache lookup and store are skipped,
only for the pool Solid Cable uses (the primary pool if it has no database of its own), only on the listener
thread, and the previous setting comes back after each check.
