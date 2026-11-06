---
id: DRV6
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: fix
area: CI, three intermittent or broken jobs on main
reviewer: flavorjones
branch: thomasklemm/fix-intermittent-ci
head: "cfd14a42c755ee6e218811916ba8adc68b2230d3"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Makes main's CI green again: sqlcipher on Windows (red on every run since MSYS2 dropped the mingw64 package) and two intermittent test failures. Unblocks green CI for DRV1/DRV2 and every other PR."
rank: 19
risky: false
state: ready
pr: 773
note: "Bundles DRV3, DRV4 and DRV5 (Thomas, 2026-11-06, to stay within the per-repo cap) as three commits cherry-picked unchanged onto 48091f4694 (patch-identical to 3966a52d0f, bfdb863448, ccd8267678). Fork CI with all three: 134/134 green, run 42213230921."
passes:
  - {reviewer: sol, head: "cfd14a42c755ee6e218811916ba8adc68b2230d3", date: 2026-11-06, verdict: nits, open: "Opening line, MSVCRT sentence, shorter busy-timeout paragraph; applied."}
  - {reviewer: claude-code, head: "cfd14a42c755ee6e218811916ba8adc68b2230d3", date: 2026-11-06, verdict: approve, open: "Reviewed body after Sol nits (a190280); no change. Each commit patch- and message-identical to 3966a52d0f/bfdb863448/ccd8267678, all on 48091f4694 (still upstream main); Thomas as author and committer, no trailers. Fork run 42213230921 (134/134) ran on c9701eac, whose first three commits have this head's tree; probe commit only adds a push trigger."}
  - {reviewer: claude-code, head: "3966a52d0fd6ce1130f190b1d18dfcbab2eb1fa8", date: 2026-11-06, verdict: approve, open: "DRV3 commit, reviewed separately."}
  - {reviewer: claude-code, head: "bfdb86344843c59eb041823fdff3e8c39c33ced8", date: 2026-11-06, verdict: approve, open: "DRV4 commit, reviewed separately."}
  - {reviewer: claude-code, head: "ccd8267678d524c7ea72e4a7a988dc8a5a0d80d3", date: 2026-11-06, verdict: approve, open: "DRV5 commit, reviewed separately."}
---

# Fix three CI failures on main

This fixes one broken CI job and two intermittent test failures on `main`, one commit each.

**sqlcipher on Windows** fails at setup with `error: target not found: mingw-w64-x86_64-sqlcipher` since the [scheduled run of 2026-11-04](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/41797589777/job/126465995083). MSYS2 stopped building sqlcipher for MINGW64 in msys2/MINGW-packages#32999 and now ships it only for ucrt64, clang64 and clangarm64. The job now uses `ruby: ucrt`, as the `test` job does.

**`test_replacing_a_collation_releases_the_previous_comparator`** fails now and then on Windows with `Expected: 1, Actual: 2` ([run](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/40731984446/job/124301317903)). The comparators are registered on the test thread, so a stale reference can stay in a slot that the conservative stack scan reads. They are now registered on a short-lived thread, as the neighbouring tests already do, and the same goes for the case-insensitive variant from #764. Both tests still fail if replaced comparators stay pinned.

**`test_busy_timeout`** fails now and then on Linux with `Expected 0.99... to be >= 1.0` ([run](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/40111817141/job/120926732901)). The discard tests leave a forked child unwaited for, and its SIGCHLD can cut short one of SQLite's busy-handler sleeps in a later test, since `unixSleep` doesn't resume `nanosleep()` after a signal ([traced run on my fork](https://github.com/thomasklemm/sqlite3-ruby/actions/runs/42212187429/job/127873273475)). The helper now waits for the child, as the other fork helpers do. Replaying the failing main run with its seed and file order failed 5 of 5 times before and passed 5 of 5 after.

With all three, [CI on my fork](https://github.com/thomasklemm/sqlite3-ruby/actions/runs/42213230921) passes every job.
