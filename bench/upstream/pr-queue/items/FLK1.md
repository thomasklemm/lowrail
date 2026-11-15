---
id: FLK1
repo: rails/rails
fork: thomasklemm/rails
kind: fix
area: CI flakiness (Action Pack Server-Timing tests, railties server restart test, Active Record Ractor proxy pinning)
reviewer: yahonda
branch: thomasklemm/fix-flaky-ci-tests
head: "4c2ab2a681"
base: main
built_on: "8217632cf8"
depends_on: []
impact: "Three causes of red builds unrelated to the change under test (12 red builds in Sep 17–Nov 15, 6 on main): Server-Timing sleep tolerances, a restart.txt mtime tick race, and a Ractor proxy pin that leaks into later sqlite3:ractor tests."
rank: 41
risky: true
state: built
pr:
note: "Bundled flake fixes, one commit per cause; record docs/upstream/rails-ci-flakiness.md. risky because the third commit changes Ractor proxy pinning (Astra slot needs a Fable or Astra pass). TestUnconnectedAdapter left to rails/rails#59174 (open, Kutomore, steered by matthewd)."
passes: []
---

# Fix three causes of intermittent CI failures

While going through two months of Buildkite failures on main, and on pull requests whose failing job had nothing to do with their change, I found three causes in Rails' own tests and in the Ractor connection proxy that keep turning builds red. Each one costs a contributor a rerun and a reviewer a look at a failure the change didn't cause. Each commit explains its cause.

| Test | Cause | Failing before | After |
|---|---|---:|---:|
| `ServerTimingTest`, the nested and sibling event tests | compared the header with `sleep` lengths under fixed tolerances | 188/200 | 0/200 |
| `ServerTest#test_restart_rails_server_with_custom_pid_file_path` | `bin/rails restart` can touch `tmp/restart.txt` within the same timestamp tick in which Puma recorded it, so Puma never sees a change | 32/100 | 0/100 |
| `AsynchronousQueriesTest#test_async_query_retries_connection_failure` (sqlite3:ractor) | the Ractor proxy unpinned a different main pool than it pinned, so the writing pool stayed pinned for later tests | 7/60 | 0/60 |

The loops make each cause likely: two CPUs shared with busy processes, a touch right after the server boots, and the three tests involved in random order. Only the third commit changes library code: the proxy now unpins the main pool it pinned, as `ConnectionPool` itself does.
