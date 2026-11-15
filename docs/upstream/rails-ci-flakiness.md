# Rails CI flakiness (FLK1, 2026-11-15)

Which tests and jobs fail intermittently on rails/rails main, why, and what we fixed. The fixes go upstream as one
bundled PR (queue item [FLK1](../../bench/upstream/pr-queue/items/FLK1.md)), one commit per cause.

## Summary

- **Data:** every Buildkite build of `rails/rails` from 133700 to 136649 (Sep 17 to Nov 15), plus the logs of all
  2,617 failed jobs. In scope: main and pull requests into main, 2,430 builds (651 on main), 246 of them red (32 on
  main).
- **The biggest cause by volume is outside Rails.** 689 failed jobs are Buildkite agent interruptions (exit -1,
  "Received cancellation signal"); Buildkite retries them automatically, so they rarely turn a build red. The
  activejob integration job fails in 330 of 1,816 runs on main, but it is soft-failed and never turns a build red.
- **The flake that turned the most builds red is outside Rails too:** activemodel `RailtieTest` (17 red builds) hits
  a Ruby bug with `require` inside a Ractor. Main already guards against it.
- **Fixed in the PR (two commits, head fdd771cf79), with before and after rates:**
  - `ServerTimingTest`, three tests: compared the header with `sleep` lengths under fixed tolerances. 189/200 failing
    before, 0/200 after, on GitHub runners with the CPU throttled the way a container limited to 2 CPUs is.
  - `AsynchronousQueriesTest#test_async_query_retries_connection_failure` (sqlite3:ractor): the Ractor proxy looked
    the main pool up again by name and role at unpin and unpinned nothing, so the writing pool stayed pinned for later
    tests. 15/120 failing before, 0/120 after on GitHub runners (120 distinct seeds), with the three tests
    involved in random order; both CI seeds fail on main and pass with the fix.
- **Already fixed, or with an open fix by someone else:** 9 more flakes, listed below. `TestUnconnectedAdapter` has
  an open fix (rails/rails#59174) that matthewd steered; our first fix for it was the approach he turned down, so we
  dropped it.
- **Left:** `ServerTest#test_restart_rails_server_with_custom_pid_file_path` (cause on CI not established; a
  commit was built and dropped, see below), the engine `commands_test.rb` hang (cause unknown, not reproduced; open candidate rails/rails#53215),
  `MultipleFixtureConnectionsTest` and `InstrumentationTest` (not reproduced).

## Method

`scrape_builds.py` reads the public Buildkite build list; `fetch_logs.py` downloads the raw log of every failed or
retried job; `parse_logs.py` extracts each failing test with its seed, message and job. A failure counts as
**isolated** (a flake rather than a breakage) when the test failed in fewer than half of the sibling jobs that ran
the same suite in that build (same framework and adapter, other Rubies or Rack versions). Jobs that have no siblings,
such as `activerecord sqlite3:ractor`, are judged by hand: same seed reproducing, or failures spread over unrelated
pull requests. A pull-request failure is unrelated when the PR does not touch the failing framework. The scripts
and their outputs are in Lowrail's orb backup (`flk1/`), not in git.

Reproduction ran in the `buildkite_base` image built from rails/buildkite-config (Ruby 4.0.9; a Ruby 3.4 variant for
the engine hang), with the same services (MySQL `mysql:lts`, Postgres, Redis, Memcached), the seeds from the failing
logs, CPU limits (`docker --cpus 2` with busy processes) and repeated runs. Fork CI on thomasklemm/rails (branch
`flk1-flake-loops`, workflow `flk1-loops.yml`) ran the before and after loops on GitHub runners: runs 43710141822
(plain and stress-ng) and 43711709644 (throttled and amplified). Rails' own Buildkite was not available to us: the
rates below are from our loops, and the CI frequency is what Buildkite recorded.

## Ranked list

Builds that failed the test, of the 2,430 in scope; "red" counts builds whose final state is failed.

| # | Test or job | Builds | Red | Main | Seen | Jobs | Cause | Status |
|---|---|---:|---:|---:|---|---|---|---|
| 1 | Buildkite agent interruption (exit -1) | 689 jobs | rare | – | whole window | all | agent lost or cancelled | outside Rails, retried automatically |
| 2 | activejob integration job | 330/1,816 runs on main | 0 | – | whole window | activejob integration | queue adapters against live services | soft-failed, not investigated |
| 3 | activemodel `RailtieTest` (5 tests) | 23 | 17 | 0 | Sep 18–Nov 5 | activemodel (4.0) | Ruby bug: `require` in a Ractor breaks `Kernel#require`'s alias chain (Ruby #22273, #22263) | mitigated on main |
| 4 | `ServerTest#test_restart_rails_server_with_custom_pid_file_path` | 7 | 7 | 3 | Oct 29–Nov 14 | railties (3.3, 4.0, rack-2, rack-3-0) | Puma never sees the touch; cause on CI not established | not fixed (commit dropped) |
| 5 | `RactorsTest#test_jobs_are_performed_from_a_non-main_Ractor` | 22 | 4 | 1 | Sep 21–Oct 15 | railties (4.0) [rack-head] | `ractorize!` on nil during the Ractor work | stopped after Oct 15 |
| 6 | `HerbCheckerTest` | 24 | 7 | 1 | Sep 24–Nov 4 | railties (4.0) [rack-head] | Herb 0.11 behaviour | fixed upstream (#58874) |
| 7 | `FieldOrderedValuesTest` (19 tests) | 9 | 9 | 4 | Nov 4–5 | activerecord postgresql | order-dependent | fixed upstream (a712a0a9bc) |
| 8 | `StrictLoadingTest#test_strict_loading_with_has_many_through_preloaded…` | 9 | 8 | 2 | Nov 5–13 | activerecord mysql2, trilogy, postgresql | missing `authors` fixtures | fixed upstream (b835fe05b8) |
| 9 | `EagerAssociationTest#test_preload_has_many_through_with_source_type…` | 6 | 6 | 2 | Oct 30–Nov 3 | activerecord postgresql | order-dependent | fixed upstream (#59578) |
| 10 | `SQLite3AutoRollbackTest` | 6 | 6 | 0 | Oct 10–21 | activerecord sqlite3:ractor | ROLLBACK after SQLite rolled back | fixed upstream (#59033) |
| 11 | `TestUnconnectedAdapter` (3 tests) | 5 | 5 | 1 | Oct 18–Nov 9 | activerecord sqlite3:ractor | order: runs first after `models/contact.rb` leased its fake-adapter pools | open fix by others (#59174, issue #59173) |
| 12 | `ServerTimingTest` (3 tests) | 5 | 4 | 2 | Oct 15–Nov 4 | actionpack (3.3, 3.4, 4.0) | `sleep`-based tolerances | **fixed in FLK1** |
| 13 | railties `test/engine/commands_test.rb` hang | 20 jobs | 4 | – | Sep–Nov | railties (3.3, 3.4) | unknown | open candidate #53215 |
| 14 | `MultipleFixtureConnectionsTest#test_uses_writing_connection_for_fixtures` | 4 | 4 | 0 | Oct 18–Nov 9 | activerecord sqlite3:ractor | `no such table: dogs`, once `database is locked` | not investigated |
| 15 | `FullStackConsoleTest#test_reload_command_fires_preparation_and_cleanup_callbacks` | 4 | 4 | 1 | Oct 6–Nov 8 | railties | console output race | fixed upstream (#59708) |
| 16 | `InstrumentationTest#test_no_instantiation_notification_when_no_records` | 3 | 3 | 0 | Oct 16–Nov 5 | activerecord mysql2 | a `Book` row with `author_id` 100 left by another test | not reproduced |
| 17 | `ConnectionPoolThreadTest#test_checkout_fairness` | 3 | 2 | 1 | Sep 27 | activerecord mysql2, trilogy | thread scheduling | fixed upstream (79c16379a3); 7-2-stable still fails |
| 18 | `AsynchronousQueriesTest#test_async_query_retries_connection_failure` | 2 | 1 | 1 | Oct 20–Nov 11 | activerecord sqlite3:ractor | Ractor proxy leaves the writing pool pinned | **fixed in FLK1** |

Breakages that look like flakes in a raw count, but fail in every job of a build until a fix lands:
`MemCacheStoreTest#test_local_cache_should_deserialize_entries_on_multi_get` (35 builds, Oct 28 to Nov 9, every
Ruby), `ConnectionTest#test_character_set_connection_is_configured` on trilogy (trilogy 2.13.2 dropped cp932; fixed by
rails/rails#59463, later failures are PRs on older bases), the railties rack-2 job exiting 6 (Bundler cannot resolve
Rack 2 against actionpack's `rack >= 3.2.8`), and the Sprockets manifest test on 8-1-stable only (a1375572d17f has
no backport).

## Fixed in the PR

### Server-Timing tests compare with the events, not with sleeps

`test_nested_events_of_the_same_name_are_not_double_counted`, `test_sibling_events_of_the_same_name_still_accumulate`
and `test_nested_events_of_a_different_name_are_not_subtracted` (added in #58800 on Sep 17) checked the header against
the sleep lengths: for example 40 ms ± 20 for a partial that sleeps 10 + 20 + 10 ms. A sleep guarantees only its
minimum; a descheduled thread overshoots, and CI saw 61 to 83 ms. The tests now subscribe to the same events while
the middleware runs and compare the header with those events' own durations (the outer event for nested events of
one name, the sum for siblings, each event for different names).

| Loop | Before (main 8217632cf8) | After |
|---|---:|---:|
| orb, `docker --cpus 2`, 4 busy Ruby processes | 97/100 | 0/100 |
| GitHub runner, cgroup `cpu.max` 2 CPUs, 4 busy processes (run 43711709644) | 188/200 | 0/200 |
| GitHub runner, idle and `stress-ng --cpu 8` without a quota (run 43710141822) | 0/600 | 0/600 |

The before rate depends on the host: 97/100 in our orb (`docker --cpus 2`), 188/200 on GitHub runners, 133/200 and 51/100 in the two review orbs (cgroup `cpu.max` 2 CPUs with 4 busy processes); every after run was 0. The CI failures reported 61.41 to 85.16 ms against 40 ± 20 (builds 134657, 134681, 134967, 135436, 136058). The GitHub after side of runs 43710141822 and 43711709644 checked out the branch by name (an earlier head with the same actionpack change); run 43721043566 pins it to head 866942ff69, whose Server-Timing commit fd0e61b728 is unchanged in fdd771cf79: 189/200 before (93 + 96), 0/200 after; the PR body cites this run. The Fable review orb, with a 1-CPU quota and 4 busy processes, got 200/200 before and 0/200 after, and 1/200 before without a quota.

The failure needs the thread stalled for longer than the tolerance, which a CPU quota does and fair scheduling on an
unthrottled host does not. Mutation checks: summing nested same-name events fails the same-name test, and
subtracting children of another name fails the different-name test, so the new tests still catch the bugs #58800
fixed.

### Unpin the main pool the Ractor proxy pinned

Both CI failures (builds 134980 on main, seed 20983, and 136537, seed 6870) reproduce deterministically with their
seed at their commit and on main 8217632cf8; the connection failure is attempted once instead of twice. Probing the
failing order: the async executor gets the main writing pool's *pinned* connection during this non-transactional
test, and that connection's `@raw_connection_dirty` was set by
`TransactionTest#test_checking_in_connection_reenables_lazy_transactions` (`raw_connection`). A pinned connection is
never checked out again, so `clean!` never resets the flag, and a dirty connection is not restorable after a
reconnect, so `ConnectionFailed` is not retried.

The pin that outlives its test comes from `DatabaseSelectorTest#test_can_write_while_reading_from_replicas_if_explicit`
(and any test that calls `establish_connection` for a new role under transactional fixtures). The fixtures'
`!connection.active_record` subscriber runs `setup_shared_connection_pool`, which makes the new reading role point at
the writing pool config, then pins the new proxy pool. Through the proxy, `pin_main_connection!` resolves the main
pool by name and role at that moment and gets the **writing** pool (depth 1 → 2). At teardown the fixtures unpin before they
restore the reading pool (`teardown_shared_connection_pool` comes last), and `unpin_main_connection!` looks up name,
role and pool token again and unpins nothing: while the roles still share a pool the lookup finds the writing pool
under another pool token and skips it, and in `DatabaseSelectorTest` the test's own teardown
(`clean_up_connection_handler`) has already removed the reading role, so the lookup finds no pool (traced on main by
the Fable review; our probe saw `main=` empty at that unpin). Either way the writing pool's depth never returns to 0 (pin log: depth stayed ≥ 1 from that test to the end of the
run, 2,483 pin events). With the plain sqlite3 adapter `ConnectionPool#unpin_connection!` acts on the pool object it
pinned, so the bug is proxy-only.

The fix records, on the main side, which pool each proxy pin pinned (a stack per proxy pool key) and unpins that pool,
skipping it if it was discarded meanwhile. Regression test
`ProxyConnectionPoolTest#test_unpin_releases_the_main_pool_that_was_pinned` pins and unpins while the reading role
shares the writing pool, the order the fixtures use: on main it fails with `Expected: 0, Actual: 1` (one busy
connection left on the writing pool) under both `ARCONN=sqlite3` and `sqlite3_ractor`, with the fix it passes.
`test_unpin_in_a_forked_child_skips_the_discarded_main_pool` covers the `discarded?` guard: in a forked child the
inherited pin stack names the parent's pool, which the fork discarded; without the guard the child's unpin raises
`NoMethodError`. It passes on main too (main finds a new pool under another token there and unpins nothing), so it
guards the new code, not the bug. Fable also noted that the pin stack is per proxy pool key and shared by all
Ractors: if the pool swap falls between two Ractors' pins, the first unpin releases the other Ractor's pool; the end
state is right, and main leaves both pinned.

| Loop | Before (main 8217632cf8) | After |
|---|---:|---:|
| orb, the three tests in seeded random class order, seeds 1–120 | 15/120 | 0/120 |
| Fable review orb, `bin/test` with the three files (same tests, other shuffles per seed), 120 seeds | 12/120 | 0/120 |
| orb, full `sqlite3:test:ractor` with CI seeds 6870 and 20983 | 2/2 | 0/2 |
| orb, full `sqlite3:test:ractor` seeds 1, 2 and full `test:sqlite3` seed 6870 | – | 0 failures, 0 errors |

About 1 in 8 is consistent with the share of class orders (1 in 6) that run the pinning test, then the dirtying test,
then the retry test; the Fable review measured that every run in the order DatabaseSelector, Transaction, Async
fails and no other order does (with `async_loop.sh`, main fails seeds 5 12 13 17 26 43 59 80 96 102 108 109 110
111 118). The earlier GitHub runs 43715792755 and 43721043566 used seeds 1–60 in both shards, so their "14/120"
was 7/60 counted twice (Fable). Run 43725460078 gives each shard its own seeds (1–60, 61–120), after side pinned to
fdd771cf79: 15/120 before, 0/120 after; the PR body cites it.

## Already fixed or owned by someone else

- `TestUnconnectedAdapter`: `test/models/contact.rb` establishes fake-adapter connections for `Contact` and
  `ContactSti` and leases them while the file loads. When the seed runs `TestUnconnectedAdapter` first (about one
  seed in 550; all 5 CI failures had it first), its `discard_pools!` discards those pools and the teardown checks
  the leases back into discarded pools through the Ractor proxy. Reproduced: CI seed 34557 at f367f5e571 and at main
  8217632cf8 (2 errors), and 40/40 runs with all test files loaded and only `TestUnconnectedAdapter` run, on GitHub.
  rails/rails#59174 (Kutomore, open) removes the needless `discard_pools!`, as matthewd asked; yahonda closed the
  proxy-side variant #59284 as a duplicate. Our first commit was that proxy-side variant (0/40 after), so we dropped it.
- `RailtieTest` (activemodel): reproduced 40/40 at #59655's head 3a7c3857; 0/40 on main 8217632cf8 (all seeds 1–40).
  Main skips the Ractor tests before Ruby 4.1 (#58780) and runs new Ractor tests in
  `ActiveSupport::Testing::Isolation`; a new unguarded `on_ractor` test would bring it back.
- `FieldOrderedValuesTest`, `StrictLoadingTest`, `EagerAssociationTest`, `FullStackConsoleTest`,
  `test_checkout_fairness`, `SQLite3AutoRollbackTest`, `HerbCheckerTest`: fixed on main by the commits in the table;
  later failures are pull requests on older bases.

## Not fixed

### Server restart test: a commit built and dropped

`ServerTest#test_restart_rails_server_with_custom_pid_file_path` waits up to 100 s for Puma's "Restarting" after
`rails("restart")` touches `tmp/restart.txt`. rails/rails#59588 (yahonda, Nov 4) fixed one race in it (the plugin
detecting the touch before the server ran); it failed twice after that, in builds 136351 (main, Nov 9, seed 42753)
and 136623 (#59803, Nov 14, seed 32620). In both, nothing at all was printed after "Use Ctrl-C to stop", and the file
took 205 s while the test's profile shows 101.8 s per attempt, so **the run and its minitest-retry attempt both
failed**: whatever stops the restart held for two fresh apps in a row on that host.

We built a fix on the hypothesis that the touch keeps restart.txt's mtime unchanged: Puma's tmp_restart plugin creates
the file at boot, records its mtime and restarts only on a strictly later one, so a touch inside the same timestamp
tick is never seen. The commit (b4661e4891, kept on `flk1-before-drop` in the local clone) pre-dated restart.txt by
60 s. Evidence for the mechanism: a touch that keeps the mtime reproduces the symptom exactly (100 s silence), and a
variant that touches in-process right after boot failed 32/100 in our orb (4 ms tick) and 0/100 with the pre-date.
The opus review showed it does not explain CI: its orb (250 Hz) gave 0/100 for the same variant (the touch landed
4–8 ms, 1–2 ticks, after Puma's recording), the real `rails("restart")` path touches 24–44 ms after (our orb: 12–44
ms), GitHub runners gave 0/100, and on CI the app lives in a tmpfs at `/rails/tmp` whose timestamps advance at least
every tick (10 ms at `CONFIG_HZ=100`). Two consecutive failures do not fit a race inside one tick. The CI seeds pass
on main in the CI image (2/2), so it is not test order. The commit was dropped: the pre-date would also cover a
backward clock step or coarse timestamps, but we cannot show that either happens on Rails' agents. Next step that
only Rails' Buildkite can take: on failure, print restart.txt's mtime at boot and after the touch, and the plugin
thread's state.

- **Engine `commands_test.rb` hang** (railties, Ruby 3.3 and 3.4, mostly shard 10 of 12): 20 jobs hit the 30-minute
  timeout. Mapping the seeds shows the hung test is `test_server_command_work_inside_engine` 18 times and
  `test_server_command_broadcast_logs` twice. Not reproduced: 120 spawn and TERM cycles of the server in the Ruby 3.4
  image and 40 full runs of the file passed. A PTY that nobody reads after "Listening on" can block the server's
  shutdown output; rails/rails#53215 (open) replaces the PTY with a pipe and reads while a request runs, which
  would also remove that, but whether it is this hang is unproven.
- **`MultipleFixtureConnectionsTest`** (sqlite3:ractor, 4 builds, none on main) and **`InstrumentationTest`**
  (mysql2, 3 builds): `InstrumentationTest` did not reproduce with CI seed 61981 at b579d52271 (10,428 runs, 0
  failures); `MultipleFixtureConnectionsTest` was not investigated.

## Reviews

See the queue item for the passes.

## Data

In Lowrail's orb backup, `flk1/`: `scrape_builds.py`, `fetch_logs.py`, `parse_logs.py`, `rank.py`, `flakes.py`,
`redcauses.py`, `jobstats.py`; outputs in `flk1/data/` (`builds.jsonl`, `failures.jsonl`, `flakes.txt`, `rank.txt`,
`redcauses.txt`, the job logs); loops and probes in `flk1/loops/`.
