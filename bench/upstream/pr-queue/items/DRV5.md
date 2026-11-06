---
id: DRV5
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: fix
area: Tests, busy_timeout and fork helpers
reviewer: flavorjones
branch: thomasklemm/reap-forked-test-child
head: "ccd8267678d524c7ea72e4a7a988dc8a5a0d80d3"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Fixes the intermittent Linux failure of IntegrationPendingTestCase#test_busy_timeout (Expected 0.99... >= 1.0), seen on main and on #769/#770 musl jobs; unblocks green CI for DRV1/DRV2."
rank: 22
risky: false
state: superseded
pr:
note: "Test-only: in_a_forked_process now waits for its child. Cause: SQLite's busy handler counts sleeps and unixSleep's nanosleep(&sp, NULL) doesn't resume after EINTR; the unreaped discard-test child's SIGCHLD lands in a later busy wait. Evidence: shim-attributed failing run on the fork (job 127873273475, SIGCHLD from the test_close_does_not_discard_readonly_connections child); replay of main run 40111817141 (seed 28717, CI file order, e80ff06, Ruby 3.2.11) failed 5/5 before and passed 5/5 after (reviewer: 9/10 and 10/10). Tolerance unchanged; another handled signal could still shorten the wait, none found in the suite."
passes:
  - {reviewer: claude-code, head: "cecb57f3585f7415f79b53c258f154f6801130b8", date: 2026-11-06, verdict: nits, open: "'by 7 ms' to 'about 7.5 ms'; replay paragraph and remaining-risk sentence suggested; all applied."}
  - {reviewer: claude-code, head: "ccd8267678d524c7ea72e4a7a988dc8a5a0d80d3", date: 2026-11-06, verdict: approve, open: "Separate Claude Code subagent review of head and body; tree identical to cecb57f, no trailers, lines <= 72."}
  - {reviewer: sol, head: "ccd8267678d524c7ea72e4a7a988dc8a5a0d80d3", date: 2026-11-06, verdict: nits, open: "Body: one sleep vs whole timeout wording, drop second main link and spacing detail; applied by coordinator."}
---

# test: wait for the child forked by the discard tests

`IntegrationPendingTestCase#test_busy_timeout` fails now and then on Linux with `Expected 0.99... to be >= 1.0`, including on main ([run 40111817141](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/40111817141/job/120926732901)). SQLite's default busy handler counts each of its 1 to 100 ms sleeps as complete, but `unixSleep` doesn't resume `nanosleep()` after a signal, so a handled SIGCHLD can shorten one sleep and make the busy timeout return early.

`TestDiscardDatabase#in_a_forked_process` returns once the child has closed the pipe, without waiting for it to exit, so its SIGCHLD can arrive during a later test. In a [failing run on my fork](https://github.com/thomasklemm/sqlite3-ruby/actions/runs/42212187429/job/127873273475), with an `LD_PRELOAD` shim that logs interrupted sleeps, the SIGCHLD from `test_close_does_not_discard_readonly_connections`'s child cut a 25 ms busy-handler sleep short by about 7.5 ms. This waits for the child, as the other fork helpers do.

Replaying that main run locally with its seed and file order failed 5 of 5 times before this change and passed 5 of 5 after it.
