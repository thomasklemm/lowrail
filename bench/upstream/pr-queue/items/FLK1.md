---
id: FLK1
repo: rails/rails
fork: thomasklemm/rails
kind: fix
area: CI flakiness (Action Pack Server-Timing tests, Active Record Ractor proxy pinning)
reviewer: yahonda
branch: thomasklemm/fix-flaky-ci-tests
head: "866942ff69"
base: main
built_on: "8217632cf8"
depends_on: []
impact: "Two causes of red builds unrelated to the change under test (5 red builds in Sep 17–Nov 15, 3 on main): Server-Timing sleep tolerances, and a Ractor proxy pin that leaks into later sqlite3:ractor tests."
rank: 41
risky: true
state: in-review
pr:
note: "Body counts from run 43721043566 (before at 8217632cf8, after pinned to 866942ff69): Server-Timing 189/200 -> 0/200, async order 14/120 -> 0/120. claude-code and opus approve 866942ff69; risky (Ractor proxy pinning), so the Astra slot still needs a Fable or Astra pass from a third orb before reviewed. Bundled flake fixes, one commit per cause; record docs/upstream/rails-ci-flakiness.md. risky because the second commit changes Ractor proxy pinning. Review orbs: claude-code T-01a1df43-c4b2-76c7-9b56-e863e94d97f3, opus T-01a1df43-cdbe-723b-8292-cadbac75cbc2. The restart.txt commit (b4661e4891) was dropped after the opus pass: CI runs the app on a tmpfs and the touch comes tens of ms after Puma records the mtime, so the same-tick cause does not explain CI (both CI failures failed the run and its retry). TestUnconnectedAdapter left to rails/rails#59174 (open, Kutomore, steered by matthewd). The body keeps before/after counts because the FLK1 bet asks for them."
passes:
  - {reviewer: opus, orb: T-01a1df43-cdbe-723b-8292-cadbac75cbc2, head: "4c2ab2a6816f2d789d1ece0b172af7ee7d298bc0", date: 2026-11-15, verdict: changes, open: "Code fine. Must-fix: body counts and the loops sentence (counts kept per the bet, sentence made self-contained, restart row gone); restart commit message claimed a few ms gap, measured 24-44 ms (commit dropped). Nits applied: empty @pinned_pools keys deleted; record restart numbers added. Nits not applied: shorter server_test comment (commit dropped), partials.size assert. Rates: Server-Timing 133/200 -> 0/200 (cpu.max 2 CPUs, 4 hogs); restart amplified 0/100 -> 0/100; async order 7/60 -> 0/60; sqlite3:ractor seeds 20983 and 6870 fail the async test on main; on head 20983 and random seed 59226 are clean, 6870 has 0F plus 4E from a missing sqlite3 CLI in the reviewer orb. Mutations caught; differential probe of pin/unpin (shared pool, swap, removed, discarded, worker Ractors) changed only as intended."}
  - {reviewer: opus, orb: T-01a1df43-cdbe-723b-8292-cadbac75cbc2, head: "bc520a6a1734378df7c11ed14798fc2a54204366", date: 2026-11-15, verdict: approve, open: "Confirm pass. Two commits on 8217632cf8; proxy.rb diff since 4c2ab2a681 only deletes an empty stack key under the same lock; rubocop clean. Differential probe identical to 4c2ab2a under both ARCONNs (shared pool, swap, replaced, removed, discarded, worker Ractors). ractor_connection_handling_test.rb 62 runs 0F 0E under sqlite3 and sqlite3_ractor; regression test errors with the lib reverted. Async loop 0/60 on head (7/60 on main). Author/committer Thomas, no trailers. Body claims checked against the runs; counts table accepted per the bet."}
  - {reviewer: claude-code, orb: T-01a1df43-c4b2-76c7-9b56-e863e94d97f3, head: "bc520a6a1734378df7c11ed14798fc2a54204366", date: 2026-11-15, verdict: nits, open: "No must-fix. Nits applied in 866942ff69 (tree identical): proxy message names the replaced/removed-pool change; Server-Timing message 61 to 85 ms (Buildkite 61.41-85.16); GitHub after side pinned to the head SHA (run 43721043566); host-dependent before rates in the record. Counts: Server-Timing main 51/100 -> 0/100 (cgroup 2 CPUs, 4 hogs); async loop 7/60 -> 0/60; sqlite3:ractor seeds 6870/20983 fail on main, clean on head (also random 27149); handling test 62 runs green under both ARCONNs; restart amplified 0/100 on main (supports the drop). Mutations caught; differential probe S1-S10 changed only as intended, @pinned_pools empty after each. No comments added, rubocop and diff --check clean, identity right, no trailers."}
  - {reviewer: opus, orb: T-01a1df43-cdbe-723b-8292-cadbac75cbc2, head: "866942ff697f2f0fd9d7349a173009599c97cf0d", date: 2026-11-15, verdict: approve, open: "Message-only confirm: range-diff shows only the two message hunks, tree cc222892ce identical to bc520a6a17. 61 to 85 ms matches its throttled main loop (61.23-85.13); proxy sentence matches its probe (replaced/removed pool unpinned to depth 0, discarded skipped). Identity Thomas, no trailers."}
  - {reviewer: claude-code, orb: T-01a1df43-c4b2-76c7-9b56-e863e94d97f3, head: "866942ff697f2f0fd9d7349a173009599c97cf0d", date: 2026-11-15, verdict: approve, open: "Message-only confirm: both trees unchanged (cc222892ce), git diff bc520a6a17..866942ff69 empty, range-diff shows the two message edits; replaced/removed sentence matches probes S4-S7 and ConnectionPool; 61 to 85 ms checked in the five Buildkite actionpack logs (85.16, 74.05, 79.11, 61.41, 82.89). Identity Thomas, no trailers, lines <= 72."}
---

# Fix two causes of intermittent CI failures

While going through two months of Buildkite failures on main, and on pull requests whose failing job had nothing to do with their change, I found two causes that keep turning builds red: one in Action Pack's Server-Timing tests and one in the Active Record Ractor connection proxy. Each costs a contributor a rerun and a reviewer a look at a failure their change didn't cause. Each commit explains its cause.

| Test | Cause | Failing before | After |
|---|---|---:|---:|
| `ServerTimingTest`, the nested and sibling event tests | compared the header with `sleep` lengths under fixed tolerances | 189/200 | 0/200 |
| `AsynchronousQueriesTest#test_async_query_retries_connection_failure` (sqlite3:ractor) | the Ractor proxy unpinned a different main pool than it pinned, so the writing pool stayed pinned for later tests | 14/120 | 0/120 |

The counts come from repeated runs that make each failure likely: the Server-Timing tests on two CPUs shared with four busy processes, and the async test together with the two tests that set it up, in random order. Only the second commit changes library code: the proxy now unpins the main pool it pinned, as `ConnectionPool` itself does.
