---
id: DRV4
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: fix
area: Tests, collation comparator release
reviewer: flavorjones
branch: thomasklemm/collation-release-test-thread
head: "bfdb86344843c59eb041823fdff3e8c39c33ced8"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Fixes the intermittent Windows failure of test_replacing_a_collation_releases_the_previous_comparator (Expected 1, Actual 2), seen on main and on #769; unblocks green CI for DRV1/DRV2."
rank: 21
risky: false
state: reviewed
pr:
note: "Test-only: registrations wrapped in Thread.new { ... }.join like the neighbouring tests, in this test (from #723) and its case-insensitive sibling (#764/70c3baf). Windows probe (fork branch probe/collation-flake): full suite 1/30 failures on main vs 0/30 fixed (Ruby 3.3); loop of the body 5/92,000 survivors on the test thread vs 0/92,000 on another thread. Both tests still fail with an append-only snapshot mutant. Open for a separate change: the ReleasableComparator comment ('used by one test only') is stale since #764 subclasses it."
passes:
  - {reviewer: claude-code, head: "68817f09a31a85c21bfe6ca5e44d11a1793fde8b", date: 2026-11-06, verdict: nits, open: "Commit message claimed a later GC always frees it (probe data mixed); body wording; both applied."}
  - {reviewer: claude-code, head: "bfdb86344843c59eb041823fdff3e8c39c33ced8", date: 2026-11-06, verdict: approve, open: "Separate Claude Code subagent review of head and body; tree identical to 68817f09a3, mutant, rubocop and links confirmed, no trailers."}
---

# test: register the released comparators on another thread

`test_replacing_a_collation_releases_the_previous_comparator` fails now and then on Windows with `Expected: 1, Actual: 2`, including on main ([push run 40731984446](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/40731984446/job/124301317903), [scheduled run 41797589777](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/41797589777/job/126472770998)). The comparators are registered on the test thread, so a stale reference to a replaced one can remain in a register or stack slot that the conservative machine-stack scan reads, and that comparator survives the `GC.start`.

This registers them on a short-lived thread, as the neighbouring tests already do for the same reason, and does the same in the case-insensitive variant added in #764. Both tests still fail if replaced comparators stay pinned.

On Windows with Ruby 3.3, 30 full suite runs of main failed this test once and 30 runs with this change passed. In 92,000 iterations of a loop around the test body on Ruby 3.3 and 4.0, a replaced comparator survived the `GC.start` 5 times; with the registration on another thread, none did.
