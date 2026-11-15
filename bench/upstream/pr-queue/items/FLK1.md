---
id: FLK1
repo: rails/rails
fork: thomasklemm/rails
kind: fix
area: CI flakiness (Action Pack Server-Timing tests, Active Record Ractor proxy pinning)
reviewer: yahonda
branch: thomasklemm/fix-flaky-ci-tests
head: "bc520a6a17"
base: main
built_on: "8217632cf8"
depends_on: []
impact: "Two causes of red builds unrelated to the change under test (5 red builds in Sep 17–Nov 15, 3 on main): Server-Timing sleep tolerances, and a Ractor proxy pin that leaks into later sqlite3:ractor tests."
rank: 41
risky: true
state: in-review
pr:
note: "Bundled flake fixes, one commit per cause; record docs/upstream/rails-ci-flakiness.md. risky because the second commit changes Ractor proxy pinning. Review orbs: claude-code T-01a1df43-c4b2-76c7-9b56-e863e94d97f3, opus T-01a1df43-cdbe-723b-8292-cadbac75cbc2. The restart.txt commit (b4661e4891) was dropped after the opus pass: CI runs the app on a tmpfs and the touch comes tens of ms after Puma records the mtime, so the same-tick cause does not explain CI (both CI failures failed the run and its retry). TestUnconnectedAdapter left to rails/rails#59174 (open, Kutomore, steered by matthewd). The body keeps before/after counts because the FLK1 bet asks for them."
passes:
  - {reviewer: opus, orb: T-01a1df43-cdbe-723b-8292-cadbac75cbc2, head: "4c2ab2a6816f2d789d1ece0b172af7ee7d298bc0", date: 2026-11-15, verdict: changes, open: "Code fine. Must-fix: body counts and the loops sentence (counts kept per the bet, sentence made self-contained, restart row gone); restart commit message claimed a few ms gap, measured 24-44 ms (commit dropped). Nits applied: empty @pinned_pools keys deleted; record restart numbers added. Nits not applied: shorter server_test comment (commit dropped), partials.size assert. Rates: Server-Timing 133/200 -> 0/200 (cpu.max 2 CPUs, 4 hogs); restart amplified 0/100 -> 0/100; async order 7/60 -> 0/60; sqlite3:ractor seeds 20983 and 6870 fail on main, pass on head. Mutations caught; differential probe of pin/unpin (shared pool, swap, removed, discarded, worker Ractors) changed only as intended."}
---

# Fix two causes of intermittent CI failures

While going through two months of Buildkite failures on main, and on pull requests whose failing job had nothing to do with their change, I found two causes that keep turning builds red: one in Action Pack's Server-Timing tests and one in the Active Record Ractor connection proxy. Each costs a contributor a rerun and a reviewer a look at a failure their change didn't cause. Each commit explains its cause.

| Test | Cause | Failing before | After |
|---|---|---:|---:|
| `ServerTimingTest`, the nested and sibling event tests | compared the header with `sleep` lengths under fixed tolerances | 188/200 | 0/200 |
| `AsynchronousQueriesTest#test_async_query_retries_connection_failure` (sqlite3:ractor) | the Ractor proxy unpinned a different main pool than it pinned, so the writing pool stayed pinned for later tests | 7/60 | 0/60 |

The counts come from repeated runs that make each failure likely: the Server-Timing tests on two CPUs shared with four busy processes, and the async test together with the two tests that set it up, in random order. Only the second commit changes library code: the proxy now unpins the main pool it pinned, as `ConnectionPool` itself does.
