# Campfire PR rework (2026-11-18)

Scope: our eight open basecamp/once-campfire PRs (#320, #345, #346, #347, #350, #352, #374, #417), rebuilt on current
`main` (`7b80988`, Puma 8.0.3) with the smallest diff, after the
[rules review](rules-review-2026-11-18-ecosystem.md) of the same day. It replaces that review's `-lean` rebuilds.
Thomas approved: removing the trailers from all eight PR branches, adopting namespaceMarcello's two #350 commits
(`af77995`, `6077be9`) with him as author, and fixing Codex's two valid #347 findings.

The builder's recommendations below are superseded by the [thermos-sol confirmation](#thermos-sol-confirmation)
at the end of this record. In particular, the queue-first backup is an improvement, not a coherent two-database
snapshot, and a restored claimed job does not necessarily fail as `ProcessMissingError` at boot.
The [fix round](#fix-round--3) then replaced the `-2` heads of #345, #346, #347, #417 and #352 with `-3` heads.

New fork branches with the suffix `-2` on thomasklemm/once-campfire. Thomas Klemm is author and committer with the
original author dates, except namespaceMarcello's two commits (his authorship and dates, Thomas as committer).
Each commit was checked with `git cat-file commit` and `%(trailers:only)`: none has a trailer, and none contains
Amp, Claude, Claude-Session or Cursor lines. No PR branch was pushed and nothing was posted. Proposed bodies are in
the [items](../../bench/upstream/pr-queue/items); a "For Thomas" section at the end of each item holds the review
replies and closing comments, which are not posted.

Tests: on Ruby 4.0.9, every branch passed the full `bin/rails test` with 0 failures (2 skips, the libvips loaders,
as on main) and `bin/rubocop` reported no offenses on the whole tree. Main itself: 649 runs, 0 failures.

| PR | New branch | Head | Diff against main | Recommendation |
| --- | --- | --- | --- | --- |
| #320 | `cursor/bot-key-header-not-path-8545-2` | `2b433b61d6` | 8 files +54 −6 (lean +246 −15) | push |
| #345 | `deps/solid-cache-2` | `19e5d8f8cd` | 9 files +61 −6 (lean +144 −9) | push |
| #346 | `feat/solid-queue-cutover-2` | `ab3cc5f4fe` | 26 files +259 −87 (lean +446 −69) | push |
| #347 | `deps/solid-cable-removal-2` | `260c05071e` | 36 files +367 −155 (lean +669 −146) | push |
| #417 | `feat/retry-interrupted-jobs-2` | `9b11cb7c4a` | 29 files +333 −87 (lean +525 −69) | push |
| #352 | `claude/project-thread-1ks0h3-2` | `59f8a80bf6` | 3 files +17 −7 (lean +32 −8) | push |
| #350 | `perf/native-fragment-cache-2` | `6d3d7c72c8` | 33 files +353 −228 (lean +436 −237) | close in favour of #412/#413; the branch exists if Thomas keeps it |
| #374 | none | | | close, superseded by #370 |

Stack: #345 ← #347 and #346 ← #347, #346 ← #417. #347 has to carry both, since removing Redis needs the cache and the
jobs off it. #417 only builds on Solid Queue. #350 no longer depends on #345: its shared fragments work with any
`Rails.cache`, Redis today. #347-2 is #345-2, then #346-2 replayed on it (`58bddc0`, same change, conflicts only in
`database.yml`, `post-restore`, `compare_http.rb` and `Gemfile.lock`), then the Cable commit.

## Still relevant upstream?

- **#374: superseded.** Sam Ruby's #370 (merged 2026-10-21, `c8f74a0`) keeps the last computed script sources
  keyed by importmap, base URL, host and relative root, so after a worker's first page `script_locations` doesn't
  run. #374 now saves about 1 ms on a worker's first page per host. rubys said on #374 that the two compose,
  which is true, but that one millisecond isn't worth a reviewer's time. Closing comment in the item.
- **#350: mostly superseded by open PRs from rubys.** Main already keys message fragments by content
  (`FragmentCache::ContentKey`). namespaceMarcello measured (49% vs 91% fragment hits) that the gap comes from
  scoping those keys by viewer and session. #412 (rubys, one file, shown as APPROVED, though the only approving
  review listed is Copilot's) removes that scope. #413 (rubys, on #412) takes the key-derivation cost out with a
  database-maintained presentation version, the same cost Marcello's stored-value commits attack. What only #350
  has: cross-worker sharing through `Rails.cache`, page runs around mentions and attachments, and the MemoryStore
  swap. Those are larger and arguable. Recommendation: close #350 in favour of #412/#413, thanking Marcello for
  the load runs and the 500 fix. If Thomas keeps it, `perf/native-fragment-cache-2` is the head (built as approved,
  with Marcello's commits). Marcello's 500 (a body stored as invalid text) is real on main too: his regression test
  fails on `7b80988` with `ActionView::Template::Error: invalid byte sequence in UTF-8`, so it is worth a small PR
  of its own whichever way #350 goes. Open question.
- **#345/#346/#347/#417: still relevant.** Upstream has an unmerged `solid-trifecta` branch (Stanko K.R.,
  2026-07-21, `094ef7b`, no PR) and the closed #159. Nothing on main moved off Redis. "GPT on behalf of DHH"
  reviewed #345 and #346 in October and asked for operational checks before adopting them, not for a different
  design. namespaceMarcello's #389 (open) removes kredis on its own; #347-2 removes it too, and either one can
  take it.
- **#320: relevant.** #272 is open; main still reads `params[:bot_key]`, and the log scrubber covers only the Rails
  log.
- **#352: relevant.** Both filter files are unchanged on main.

## Per PR

### #320 Bearer auth for bot routes — `2b433b61d6`

What changed: one commit instead of nine, 13 lines of app code. `bot_authentication` reads the key from
`authenticate_with_http_token`, else from `params[:bot_key]`, as main does. The key-free `bot` routes sit next to
the `:bot_key` ones. The `Link` header uses `url_for(next_page)`, so it follows the path the request used, checked:
legacy `…/rooms/1/<key>/messages?before=…`, header `…/rooms/1/bot/messages?before=…`. The webhook adds
`room.api_path`, and the bots page shows the header form. Dropped from the lean branch: the separate
`require_bot_authentication` with its 401s, the fail-closed handling of a blank header, refusing a signed-in session
on bot routes, ignoring query and body `bot_key`, `room.bot_key` in the webhook payload (the bot already holds its
key), the self-hosting doc section, the routes comment and 120 lines of tests. Each of those kept or tightened
behaviour no bot relies on. An unauthenticated bot request redirects as on main instead of a new 401. An invalid
Bearer with a valid path key is refused (redirect), checked.

Tests: two in `by_bots_controller_test` (create with the header on the key-free path; the key-free path without a
header redirects), one pagination test (header request's `Link` has no key and the next page loads with the
header), plus the webhook payload and bots page assertions updated. Mutant: with the header read removed, 2 of 26
fail. 652 runs, 0 failures.

Guards: `authenticate_with_http_token { |token| token } || params[:bot_key]`. The header comes first, and the path key
is the documented fallback for existing bots. Comments: none added.

Boundary I accept (not in the body): a `?bot_key=` query still authenticates, as on main for every route.

### #345 Solid Cache — `19e5d8f8cd`

What changed: one commit. Gemfile, `cache.yml` (installer template, 256 MB `max_size`), `cache_schema.rb`,
`database.yml` cache entries for production and performance, `production.rb`, the restore hook deletes the cache
database, the self-hosting restore command calls the hook instead of repeating it, and the HTTP benchmark runs
`db:prepare` before Puma. Dropped: `docs/upgrades/solid-cache.md`, the README/self-hosting paragraphs, the
`APP_ROOT`/env rewrite of `post-restore` and its 55-line test, the `schema_dump` keys (Rails derives
`cache_schema.rb` from the name), the 30-day `max_age` (the installer leaves it commented out), and the trailing
blank line removed from `schema.rb`.

Verified: a production `db:prepare` creates `production_cache.sqlite3`, `Rails.cache` is a `SolidCache::Store` and
round-trips, the cache connection has `wal_autocheckpoint` 1000 and the primary 0. 649 runs, 0 failures.

Comments: `# Caching` (Gemfile section header, the file's own style). `# Replace the default in-process memory cache
store with a durable alternative.` (the line Rails' generator writes there). `# The checkpoint contender only
checkpoints the primary database.` in `database.yml` (else a reader copies `wal_autocheckpoint: 0` from the default
block). `cache.yml`'s commented `max_age` line (installer template). Guards: none.

### #346 Solid Queue — `ab3cc5f4fe`

What changed: one commit. Codex's P1 is fixed where it starts: the queue is no longer disposable.
`script/admin/prepare-backup` snapshots the queue database, then the primary. `hooks/post-restore` restores both
(a loop over the two names in main's own shape), so a `Room::DestroyJob` or `RemoveBannedContentJob` still queued
at the backup runs after a restore. Checked in production mode: enqueue a `RemoveBannedContentJob`, back up, delete
the queue database, run the hook, then `bin/jobs` picks the job up (1 finished, 0 failed). A job that was running at
the backup comes back claimed by a dead process, and Solid Queue fails it with `ProcessMissingError` at boot. #417
retries it for room deletion; banned-content removal stays failed (open question below).

Also: Procfile `workers: bundle exec bin/jobs`, `bin/jobs` and `queue_schema.rb` from the 1.7.2 installer,
`queue.yml` (installer plus 0.1 s worker polling as Resque had, plus `performance`), `recurring.yml` (the installer's
cleanup task), `bin/boot` runs `db:prepare` before both processes (`system "bin/rails db:prepare", exception:
true`) and `bin/start-app` no longer does, the bundler-audit resque-web ignores go, the two checkpoint comments say
Solid Queue instead of Resque. The benchmarks get `--baseline-image` (Copilot's #347 thread, here because this commit
removes Resque's gems) and `db:prepare` before Puma. The queue keeps its own `pool: 5` (dhh's review).

Dropped from the lean branch: `ApplicationJob.enqueue_together` and its around_action and test (a posting-throughput
optimisation from Marcello's measurement, +16% posts/s; it belongs in its own PR), `shutdown_timeout = 8` (also its
own change; #417 now retries an interrupted room deletion), on_start/stop hooks for dispatcher and scheduler (one
contender per host is elected by flock, and the worker's is enough), `docs/upgrades/solid-queue.md` with the Resque
drain (Redis in the container doesn't persist, `config/redis.conf` `save ""`, so a restart already drops Resque's
queue; the drain only covered the upgrade itself), the post-restore test, `APP_ROOT`.

Tests: no new ones. The behaviour is in shell hooks that main doesn't test, and I checked it end to end as above.
Open question whether to add a hook test in `test/script`. 649 runs, 0 failures. `bin/jobs` started the supervisor
and a worker with polling 0.1.

Guards: none. Comments: `config/initializers/solid_queue.rb` `# Stop before forking, as Puma does, so workers don't
inherit the contender's flock.` (else the hooks look redundant next to the initializer that starts it).
`database.yml` `# Three worker threads plus the poller and heartbeat, whatever the web server's thread count.`
(else someone folds `pool` back into the default) and the checkpoint line as in #345. `prepare-backup` `# The queue
goes first, so the primary snapshot has every record its jobs refer to.` (else the order looks arbitrary). The
checkpoint comments in `sqlite_wal_checkpoint.rb` and its initializer are upstream's, with Resque renamed.

### #347 Solid Cable — `260c05071e`

What changed: the Cable commit on #345-2 and #346-2. `cable.yml` uses solid_cable in development, performance and
production (generator settings), test keeps `test`. Cable databases for development, performance and production.
Redis goes: Procfile line, `config/redis.conf`, the `redis` and `kredis` gems, the Debian package, `bin/setup`'s
container, CI's services. Development caching uses `:memory_store`. The restore hook deletes cache and cable
databases in one loop. The `room.rb` comment says "a broadcast per member" instead of "a Redis round trip".

Codex P2 (async cable in development): fixed. `config/puma.rb` starts `processor_count * 0.666` workers in
development too, so development uses Solid Cable like production. Checked: a broadcast from one process reached a
subscriber in another through `development_cable.sqlite3`. Codex P1: fixed in #346-2 and carried here. Codex's
benchmark-bundle P2 and performance-queue P2: obsolete (`--baseline-image`, `performance` in `queue.yml`), resolved
by Thomas.

The three Copilot threads:
- `bench/compare_http.rb:49` baseline image: fixed (`--baseline-image`, now in #346-2 where Resque's gems go).
- `bench/compare_http.rb:51` `db:prepare` on the after side: fixed (in #345-2, for both sides: a frozen seed
  needs the baseline's migrations too, and the seed is copied fresh every round).
- `docs/upgrades/solid-queue.md:15` `Resque.queue_sizes`: the finding was wrong (resque 2.7.0 `lib/resque.rb:583`
  defines it, checked in the bundle) and is now moot, since the guide is gone.
- Codex P2 on #350 (`production.rb:72`, `db:prepare` before the benchmark's Puma): valid on the old #350 head,
  obsolete on #350-2 (no new database) and fixed in #345-2 where the cache database arrives.

Tests: 649 runs, 0 failures. Guards: none. Comments: the cable entry repeats #345's checkpoint line.

### #417 Retry interrupted jobs — `9b11cb7c4a`

What changed: the lean commit on #346-2. The class comment goes from four lines to one (`# Solid Queue fails the job
a stopped or killed worker was running. Retry it where running it again is harmless.`). The message mentions
restores (a claimed job comes back as `ProcessMissingError`). Test unchanged: one test, six asserts (retried,
counted, wrong error left, unsafe jobs left, cap). 650 runs, 0 failures.

Guards: the `INTERRUPTIONS` error check, the `RETRYABLE` allowlist and `MAX_RETRIES` are the policy, each asserted.
`rescue ActiveRecord::RecordNotFound` covers a job retried or discarded by hand between the read and the lock.
Comments: the class line (why only these jobs), `# FailedExecution#retry resets the job's execution count, so it's
counted here instead.` (else someone calls `retry`), `# Retried or discarded by hand in the meantime.` (why a rescue
is fine), the test environment line (why tests get a queue database while jobs use the test adapter).

### #352 Presentation filters — `59f8a80bf6`

What changed: `applicable?` converts to plain text only when there is one unfurled URL (`if url =
solo_unfurled_url`). The lean branch's `to_html.include?` pre-check, its constant and the memo go: that is 247 vs
235 µs per message, 5%, not worth a second test of the same thing. `SanitizeTags` walks the elements and checks a
`Set`. The test with the `to_plain_text` expectation goes (it pinned the implementation). The nested-forbidden-tags
test stays: it checks output, and passes on main too, a regression guard for the new walk.

Checked: filtered HTML byte-identical to main on all 13 fixture bodies plus 7 adversarial ones (tweet URL with a
mention, `img onerror`, style/iframe/object/form, code block with `data-language`, figure, empty, plain text).
Micro: [cf352_filters.txt](../../bench/upstream/campfire-rework/cf352_filters.txt), main 673–695 µs, new 247–248
µs per message, no JIT. That is a quick in-process micro, not a `script/upstream-bench` run. Open question.
650 runs, 0 failures.

Guards: `if url = solo_unfurled_url` is the change itself, skipping the conversion. Comments: none (the lean
branch's two are gone; the code says it).

### #350 Shared fragments — `6d3d7c72c8` (recommend close)

Built on main, not on #345: `Rails.cache` is Redis there, and the namespace and content keys work the same. The
first commit is the lean diff squashed. The README says "shared by every worker" instead of "Solid Cache in
production", and the self-hosting paragraph about `GIT_REVISION` goes (self-hosters run official images).
Then namespaceMarcello's `af77995` and `6077be9`, unchanged except the context comment their hunk sits under
(conflict resolution only), with his authorship and dates and the Co-Authored-By lines dropped. Their tests: with
the base key, 2 of 38 fragment/helper tests error. 662 runs, 0 failures.

Guards: `messages.respond_to?(:preload_associations)` (search passes a plain relation, pages pass `Message::Page`).
`perform_caching`'s `@rendering_request && !transaction_open?` (detached broadcasts and uncommitted renders must not
fill a shared cache). Marcello's `/<action-text-attachment/i` (other writers' markup isn't normalised) and `&.b`
(stored bytes may not be UTF-8). Comments, after trimming: the `message_runs` line (why runs), `cache_message_actions`
(why it can be shared), the key line (why not `updated_at`), Marcello's two (his, kept as written), the
`text_message_presentation` line, the `_message.html.erb` one about bumping the key, `fragment_caching.rb`'s one line,
`pagination.rb`'s first line and its `Defer …` scope line (upstream's, reworded by the PR), `version.rb`'s one line.
Removed: `cached_responses.rb` "One immutable snapshot …", the second line above `cache_message_actions`, the second
line in `pagination.rb`; the multi-line ones went to one line each.

## Open questions for Thomas

1. Close #374 (superseded by #370) and #350 (in favour of #412/#413)? The closing comments are in the items. If #350
   stays, `perf/native-fragment-cache-2` replaces its head.
2. Marcello's invalid-body 500 reproduces on main: ask him to open it as its own PR, or one of ours on #412's base?
3. #346-2 drops the batched enqueue and the 8 s shutdown timeout, which were measured improvements but are
   separate changes. Reopen them as follow-ups after #346 merges?
4. A job running at backup time comes back failed (`ProcessMissingError`); #417 retries room deletion, while
   banned-content removal stays failed, as #417 decided for unbans. And between the two snapshots, a job enqueued
   after the queue copy is missing (milliseconds; queue first is the safer order). Fine as is?
5. #346-2 has no hook test; add one in `test/script` with a path override, or leave the hooks untested as on main?
6. #352's body number comes from a quick micro; rerun it with `script/upstream-bench` before posting?
7. kredis: #347-2 removes it, and Marcello's #389 does too. Leave it in #347, or drop it there and let #389 take it?

## Thermos-sol confirmation

Reviewer: `thermos-sol`, [review thread](https://ampcode.com/threads/T-01a1eeb5-7700-72fe-bf46-08ff46efc3ad),
2026-11-18. Both correctness/security and maintainability rubrics were self-performed; no other reviewer,
subagent or thread was started. Record reviewed at Lowrail `aec098fb3dcd3ff9b13a9c9279d56c2e951b0417`.
All seven proposed heads descend from Campfire `7b809885a194f4c2f06f4f43e8e34704968f543e`. The existing queue
`head`/`branch` fields continue to identify published PRs; each new code pass names the proposed head instead.
CF374's closure-only pass names current main, not an unreviewed PR head.

| Item | Exact proposed head | Verdict |
| --- | --- | --- |
| CF320 | `2b433b61d6f39808717c8ecc5346415fe00e7e45` | approve |
| CF345 | `19e5d8f8cd8ef5fd72edd03afc2c3a42f44304d0` | changes: unnecessary and misleading generated comments |
| CF346 | `ab3cc5f4fef286cac3ea4bd8048eb9e7ffcaa2c3` | changes: residual backup consistency gap; false comment and restore claims |
| CF347 | `260c05071eb99b53eeff3ae74dcead9aa1611309` | changes: inherits CF345/346; development Cable fix confirmed |
| CF417 | `9b11cb7c4ae7b9d825095b2556792c5afdeec39d` | changes for inherited CF346; own retry commit approved |
| CF352 | `59f8a80bf6f5b0fcd24eaafcacaab8eee4e762e6` | changes: dense-input slowdown in the size sweep; proposed body number excluded |
| CF350 | `6d3d7c72c84057c81dfc937be0f98e77a4f07ff6` | changes if retained; agree close in favour of narrower CF412/413 |
| CF374 | `7b809885a194f4c2f06f4f43e8e34704968f543e` (current main, closure check) | approve closure, not a PR-head code approval; qualify supersession |

### Executed checks and negative controls

I independently ran `mise exec ruby@4.0.9 -- bin/rails test` and
`mise exec ruby@4.0.9 -- bin/rubocop` in a separate detached worktree for each exact head, with installed locked
bundles, prepared test databases and a local Redis. Every normal-suite result had zero failures/errors and the same two
libvips-loader skips as clean main. Every whole-tree RuboCop result had no offenses.

| Tree | Rails tests | Assertions | RuboCop files |
| --- | ---: | ---: | ---: |
| main `7b80988` | 649 | 3,921 | 335 |
| CF320 | 652 | 3,932 | 335 |
| CF345 | 649 | 3,921 | 335 |
| CF346 | 649 | 3,921 | 334 |
| CF347 | 649 | 3,921 | 334 |
| CF417 | 650 | 3,927 | 336 |
| CF352 | 650 | 3,922 | 335 |
| CF350 | 662 | 3,974 | 334 |

Harnesses and raw logs are retained under `.amp/in/orb-backup/` in the review thread, not upstream. Decisive
suite logs are `main-test.log`, `cf320-test.log`, `cf345-test.log`, `cf346-test.log` and
`cf{347,417,352,350}-test-isolated.log`; lint logs are `cfNNN-rubocop.log`. Excessive parallel supplemental runs
on this two-core/four-GB orb stalled, so the normal suites were rerun sequentially. Initial contention failures
remain in the earlier logs. An early supplemental CF346 `test:system` attempt stalled/timed out and was cancelled.

Supplemental browser verification also ran on every exact head. CF320 and CF345 passed `bin/rails test:system`.
CF346 completed with a sign-in assertion failure and a Selenium stale-element error, both in
`SystemTestHelper#sign_in` before the affected composer tests. Clean main separately failed the same `a.btn`
sign-in assertion before its unfurling test. The inspected main/CF346 captures show the authenticated Designers
room, not an authentication error; the cause is not established, and this is **not** a claim that CF346's browser
suite is green or that every failure is proved unrelated. Its normal suite is green as above.

The monolithic CF347 browser run was killed after 17 tests by the memory cgroup (kernel OOM log confirmed).
The remaining four heads were then run sequentially with one fresh process per existing browser-test file:
`bin/rails test test/system/FILE_test.rb`. No app, test or browser-option change was made. All eight files per
head completed, covering the full 30-test browser set, with zero failures/errors. The failed and killed attempts
are retained, not replaced by green logs. These are local results, not hosted CI.

| Tree | Browser tests | Assertions | Failures | Errors | Execution |
| --- | ---: | ---: | ---: | ---: | --- |
| main `7b80988` | 30 | 216 | 1 | 0 | single process |
| CF320 | 30 | 221 | 0 | 0 | single process |
| CF345 | 30 | 221 | 0 | 0 | single process |
| CF346 | 30 | 212 | 1 | 1 | single process |
| CF347 | 30 | 221 | 0 | 0 | eight file-bounded processes, after OOM |
| CF417 | 30 | 221 | 0 | 0 | eight file-bounded processes |
| CF352 | 30 | 221 | 0 | 0 | eight file-bounded processes |
| CF350 | 30 | 221 | 0 | 0 | eight file-bounded processes |

Browser logs: `main-system-isolated.log`, `cf{320,345,346,347}-system-isolated.log`,
`system-suites.log`, `system-bounded.log` and `cf{347,417,352,350}-system-*_test.log` in the review thread's
scratch directory. The per-item normal-suite counts refer to the first table, not a blanket browser approval.

- CF320: `auth_probe.rb` added five scratch integration cases, 28 assertions, all passing. Substituting main's
  authentication method made two shipped controller cases and three scratch cases fail (31 tests, five
  failures in `cf320-auth-base.log`). A valid header wins over a valid path key; an invalid nonempty Bearer
  does not fall back to a valid path key. Blank/malformed/Basic headers only fall back with a valid legacy
  credential, and a key-free route without a credential rejects. Bot access to another room and a human-only
  controller still rejects. Pagination follows the authenticated route. Removing the new 401s or blank-header
  fail-closed branch is not a demonstrated security regression: main's session, CSRF and authorization checks
  still run, and possessing the fallback key already authorizes the legacy request. Query-key fallback is an
  inherited main boundary, not a newly accepted credential.
- CF345: production `db:prepare` created the cache DB; `Rails.cache` round-tripped through `SolidCache::Store`;
  primary/cache `wal_autocheckpoint` were 0/1000 (`cf345-production.log`). No new shipped test claims to fail
  on main.
- CF346 and CF347: production `backup_probe.rb` loaded the real `script/admin/prepare-backup`, retained an
  existing ready job and a claimed job/process row, then injected actual `Room#destroy_later` between the two
  snapshots. Both exact heads reproduced **primary room=1, memberships=0; queue deletion job=0**, checking the
  exact newly enqueued job ID, not just the class count (`cf346-backup.log`, `cf347-backup.log`). The real
  `hooks/post-restore` restored the ready job, claim and process. The boot orphan check left the claim alone;
  aging/pruning the dead process produced `SolidQueue::Processes::ProcessPrunedError`, not `ProcessMissingError`
  (`cf346-restore.log`, `cf347-restore.log`). CF347 also delivered a development Solid Cable broadcast across
  two actual processes (`cf347-cable.log`). Neither head adds a backup regression test.
- CF417: the shipped six-assertion test fails with `perform` disabled (`cf417-no-retry.log`). A further two
  scratch cases/26 assertions exercised all three interruption classes, the purge allowlist, exactly three
  retries and ordinary-error exclusion (`cf417-boundaries.log`). The policy is not merely inferred from an
  empty or entirely excluded queue.
- CF352: restoring both main filter methods still passes the new nested-tags test: 20 filter tests/83
  assertions pass (`cf352-differential-fixtures.log`). It is a semantic regression guard, not evidence of a
  pre-existing bug. Differential execution was byte-identical on 13 fixture bodies, ten adversarial inputs,
  three 1.26-MB absent/early/late forbidden-tag inputs and a 3,000-element body. The dense-input slowdown in
  the first stress run survived a new/old/old/new repeat with GC between windows, described below. The
  coordinator is independently remeasuring the ordinary-message number in the proposed body; that number
  is still outside this pass, whereas the input-shape regression is a code finding.
- CF350: with the helper before Marcello's commits (`2fc4620`), the 38 fragment/helper cases give two encoding
  errors; the exact head passes all 38/203 assertions (`cf350-fragments.log`). The added invalid-text room
  test separately errors on clean main with `ActionView::Template::Error: invalid byte sequence in UTF-8`
  (`cf350-main-invalid-body.log`). The stored-row and attachment cases are regression guards too; do not
  claim each fails the previous key. The new `Rails.cache.expects(:fetch).never` case pins the implementation,
  not a user-visible result, and should be removed if the branch survives.

### Required changes and maintainer judgment

**CF346/347 restore safety.** Queue-first is safer than deliberately throwing away the queue on restore, but
it does not establish a coherent backup. A request in the gap can commit deletion state to the primary snapshot
without its cleanup job being in the earlier queue snapshot. This is a real caller:
[`Room#destroy_later` removes memberships, then enqueues](https://github.com/thomasklemm/once-campfire/blob/ab3cc5f4fef286cac3ea4bd8048eb9e7ffcaa2c3/app/models/room.rb#L51-L59),
and the documented self-hosting path explicitly runs the snapshot inside a running container
([backup instructions](https://github.com/thomasklemm/once-campfire/blob/ab3cc5f4fef286cac3ea4bd8048eb9e7ffcaa2c3/docs/self-hosting.md#L177-L180)).
Running jobs may also finish/delete primary rows after the queue copy, contradicting "the primary snapshot has
every record its jobs refer to." This is a residual loss boundary, not proof that main's nonpersistent Resque
was safer. Do not report Codex's cleanup-loss P1 fully fixed. Either establish quiescence/reconciliation across
the pair, or have Thomas explicitly accept the residual semantics and disclose them. Add a hook-level regression
case for the chosen contract; do not hide the gap by testing only a quiet queue. Delete the false order comment
and corresponding commit-message claim. CF417 cannot recover a job absent from the restored queue.

The running-job explanation must distinguish normal orphan startup from restoring a queue **with process rows**.
In the latter, the restored process remains until stale-process pruning, then produces `ProcessPrunedError`.
CF417 handles that class too. Banned-content removal intentionally remains outside its retry allowlist because
the user may have been unbanned. The item draft and P1 reply have been corrected; the earlier builder statements
above about universal boot-time `ProcessMissingError` are superseded here.

**CF352 dense-input regression.** `dense_filters_probe.rb` evaluates the exact proposed methods against main
through `TextMessagePresentationFilters.apply`, checks exact output, forces GC between windows and runs new,
old, old, new. No other suite ran alongside it. For `"<span>x</span>" * 90_000` (1,260,000 bytes), both versions
return exactly the input, but the new windows take **115,093 / 149,879 ms**, versus **16,598 / 16,970 ms** on
main (`cf352-dense.log`). The earlier stress run was 128,944 versus 15,222 ms; it was not dismissed as noise.
At 3,000 elements the new windows were 248–408 versus 391–456 ms; at 12,000, 1,957/2,013 versus 1,476/1,777 ms.
These are diagnostic shape controls, not a publication-quality speed table. The regression is repeatable in
both orders and is material even though this is not a normal chat message. DECISIONS requires this size sweep
precisely to catch improvements measured only where they win. Keeping only the solo-link shortcut with main's
tag selector gives 15,112/15,387 ms on the same dense input (`cf352-solo-control.log`), isolating the added
cost to the tag pass. Do not publish this synthetic row upstream.

After the builder supplied a specific explanation, I independently checked installed Nokogiri 1.19.5:
`XML::DocumentFragment#css` (`lib/nokogiri/xml/document_fragment.rb:173–178`) delegates to `children.css`;
`NodeSet#css` (`node_set.rb:85–91`) unions a result for each child; `+` aliases `|`, whose C implementation
copies the accumulated set (`ext/nokogiri/xml_node_set.c:252–267`). Every allowed top-level span matches `*`,
so these growing unions make the new selection quadratic; main's exclusion selector keeps the unions empty
on that input. `source.xpath(".//*")` evaluates once on the fragment instead. My direct primitive control
at 3,000/6,000/12,000 spans gave CSS 0.082/0.240/1.853 s versus XPath 0.0012/0.0017/0.0093 s, with identical
node identities/order (`cf352-xpath-primitive.log`). A mixed nested fragment also matched all 300 nodes in
order. The full filter differential with just that replacement was byte-identical on all 13 fixtures,
ten adversarial, three large absent/early/late and 3,000-element inputs, including forbidden parents and
SVG/MathML; selection order matched on every input (`cf352-xpath-differential.log`).

**The right must-fix is the one-line `css("*")` → `xpath(".//*")` substitution, not reverting the whole tag
change.** It removes the identified per-child unions without a new guard, abstraction or explanatory comment,
and preserves the set-based walk and solo-link saving. The scratch full dense XPath variant was 13.6/41.3 s
against interleaved main's 21.3/21.9 s while a browser suite ran; those noisy windows are retained in
`cf352-xpath-dense.log`, not certified as a performance result. The original uncontended regression and the
primitive/source attribution establish the requested fix. This does not approve an unbuilt replacement head;
rerun its suites and ordinary-message/large-input measurements after rebuilding. No Campfire source was edited.

**Guards and comments, all changed lines checked against DECISIONS.**

- CF320's header-first `|| params[:bot_key]` is the ordinary Rails helper plus the real legacy caller; keep it.
  No new comment. Do not restore blanket 401/session/blank-header machinery without a contract needing it.
- CF345 has no speculative guard. Keep the local Gemfile section label and the one-line checkpoint reason:
  copying the primary's zero into the cache would otherwise leave its WAL unchecked. Cut the new production
  "Replace the default in-process memory cache" comment (the base is Redis, and it narrates the change).
  Cut `cache.yml`'s optional `max_age` explanation/commented setting: generator provenance does not exempt it
  from the no-unnecessary-comments rule. These are required `changes`, not nits.
- CF346's post-restore `-f` preserves main's missing-snapshot behavior; do not replace it with speculative
  modes. The queue pool reason, primary-only checkpoint reason and pre-fork flock reason explain real
  hazards and can stay as short local comments. Existing checkpoint comments only rename Resque. The queue-first
  comment is false and must go. The sequential two-DB operation needs a consistency contract, not a new
  generic backup abstraction. CF347 inherits this and CF345's comments; its own checkpoint line is useful,
  and the existing room comment's Redis-to-broadcast wording is appropriate.
- CF417's error-class filter, two-job allowlist, retry cap and `RecordNotFound` race rescue all protect real
  policy or manual retry/discard. Keep them. The one-line class policy, execution-counter reason, manual-race
  rescue reason and test-DB reason would not be improved by narrating more implementation detail. The own
  commit is direct and cohesive; the full head is blocked only by its CF346 parent.
- CF352's sole-unfurled-URL guard avoids real unnecessary attachment/mention rendering. The element-name set
  has no new defensive branch and no comment. Its shape is readable, but that does not override the dense-input
  regression above; no compatibility wrapper or speculative guard is the remedy.
- CF350's preloading capability check serves real `Message::Page` and search relations; its request-render and
  transaction gates exclude detached broadcasts/uncommitted data. Direct-room, attachment and embedded-tag
  exclusions protect actual viewer-specific metadata; case-insensitive stored-byte matching and nil-safe `.b`
  handle Marcello's reproduced inputs. Keep locale/origin/mount/deployment namespaces and the byte-size bound.
  The relocated record-cache version/budget/transaction, persisted/unchanged-record and epoch rechecks still
  protect real cache admission and foreign writes. No arbitrary-object fallback needs adding. However, cut
  the public-helper narration above `message_runs`/`cache_message_actions`/`perform_caching`, the multi-line
  stored-value/body explanations (including Marcello's), the redundant collection-cached-text comment and
  the pagination scope narration. Attribution is not a comment-rule exception. Keep a short why for the
  timestamp-independent key and unversioned-build namespace. The `_message` key-bump reminder explains an
  otherwise invisible deployment obligation, but trim its "cached once" narration. No file crosses 1,000
  lines; separate the local-cache MemoryStore rewrite from fragment sharing if reviving this branch. The
  pagination diff only rewords comments; it is not a pagination behavior change.

**Proposed bodies and For Thomas, sentence by sentence.** The reviewed drafts stay in the items, unposted.
CF320's credential-log problem, route, pagination, page and webhook statements agree with the callers and probes;
the casing/webhook reply is current. CF345's DB creation, cold cache, checkpoint, disposable restore and benchmark
preparation statements agree with the executed production probe and source. CF346's Resque restart loss and
worker/pool statements agree with the configs and Marcello's linked run; its unconditional restore sentence
needed the missing-jobs/running-jobs boundary. The draft also cuts the Docker-run validation sentence under
Leave out. The batching/timeout reply keeps unrelated optimizations separate.
CF347's dependency paragraph, removed Redis consumers, multi-worker development reason and transient restore
statements agree with the diff and broadcast probe; its proposed P1 "Fixed" reply must not be sent unchanged.
The baseline-image and `db:prepare` review threads remain addressed; `Resque.queue_sizes` was present in 2.7.0
and the removed guide makes that thread moot. CF417's interruption classes, cadence, cap, allowlist and
non-idempotent-job exclusions agree with the code/probes; it does not promise recovery of missing queue rows.
The two stacked bodies' short SHA clauses are explicitly permitted by DECISIONS' fixed stacked-body format,
not general-purpose validation prose.

CF352's "has an unfurled link" was tightened to **one**; "fifty" was cut (the actual allowlist has 54 names).
The equivalent-output and walk/set statements are supported by the differential inputs. Its original commit
message also says "fifty"; use "a long selector" if that message is rebuilt. The numeric table is deliberately
not certified or replaced by this pass. CF350's key dependencies/fresh-render/local-cache statements agree with
source and tests; sharing needs a shared store, and independently booted applications need a stable
`GIT_REVISION` to share namespaces. An unversioned build intentionally gets a different namespace each boot,
but sibling Puma workers inherit the parent's namespace: `config/puma.rb` loads the environment before forking.
Do not overstate this as requiring a revision for all cross-worker reuse. The actual independent-boot boundary
is now explicit in the draft. Its Marcello sentence is supported by his two original commits, the negative
controls and the opened load-run
comment; it does not reuse his earlier timings as an exact-head speed claim. No test counts, commands, rejected
variants or internal review history belong in any proposed upstream body. These remain in this record instead.

**Closure decisions.** Agree close CF350 in favour of the narrower open #412/#413, not because they include
everything: cross-worker sharing, mixed cacheable runs and the MemoryStore swap remain unique. The own branch
is too broad for that common goal; the invalid-body failure deserves a separate small correctness fix whichever
option wins. Agree close CF374 for the now-cached common path. Merged #370 (`c8f74a0`) uses a **one-entry last-key
cache**, not a map of all hosts forever: alternating base URL/host/mount keys still recompute. The old "once per
worker and host" note and "runs once per worker now" closing sentence were overstatements and are corrected in
the item. This approves the proposed closure, not the old head/body's stale per-request premise. No new CF374
head was supplied, so no new CF374 suite/identity approval is claimed. Its pass names current main, not the
unchanged published head `af857b016152cfd9bd3ce707c1ec899403a3e668`, so a closure-only approval cannot satisfy
the queue's code-review gates on that PR head.

**Identity.** `git cat-file commit` and `git log --format='%(trailers:only)'` were inspected for all nine unique
rebuilt commits (plus the replayed queue commit in CF347). Thomas is author and committer except the two
Marcello commits, whose author is Marcello Costagliola; Thomas is their committer. The original **author**
timestamps/timezones match, including Marcello's `1793085139 +0100` and `1793090210 +0100`. Rebuilt committer
dates are new on 2026-11-18, not preserved original committer dates. Thus this confirms the builder's stated
author-date preservation, not a stronger both-dates-preserved claim. Every inspected message is trailer-free;
no Amp/Claude/Cursor attribution line was inserted. Raw objects are in `identity.txt` in the review thread.

Delivery scope: only this Lowrail record and the eight queue-item review/draft updates; no fork/PR branch push,
review submission, comment, closure or other upstream post is authorized by or performed in this pass.

## Fix round (-3)

After the thermos-sol confirmation. New fork branches with the suffix `-3`, built with `/usr/bin/git commit-tree`
on main `7b80988`, Thomas Klemm as author and committer, original author dates; `git cat-file commit` and
`%(trailers:only)` show no trailer and no Amp, Claude or Cursor line on any of the six commits. Not pushed to a
PR branch, nothing posted. #320 is already on its PR (coordinator, `2b433b61d6`); #350 and #374 are closed.

| PR | Branch | Head | Diff against main | Suite (Ruby 4.0.9) | RuboCop |
| --- | --- | --- | --- | --- | --- |
| #345 | `deps/solid-cache-3` | `0605b38aad` | 9 files +58 −6 | 649 runs, 0 failures | 335 files, clean |
| #346 | `feat/solid-queue-cutover-3` | `2394bc3997` | 28 files +300 −87 | 650 runs, 0 failures | 335 files, clean |
| #347 | `deps/solid-cable-removal-3` | `8b22b56402` | 38 files +405 −155 | 650 runs, 0 failures | 335 files, clean |
| #417 | `feat/retry-interrupted-jobs-3` | `1791623703` | own commit 3 files +67 | 651 runs, 0 failures | 337 files, clean |
| #352 | `claude/project-thread-1ks0h3-3` | `dd74f7028c` | 3 files +17 −7 | 650 runs, 0 failures | 335 files, clean |

Skips are the two libvips loaders, as on main. Stack: #345-3 ← #347-3 (#346-3 replayed as `8e17a98fbd`, then the
`-2` Cable commit with an identical diff) and #346-3 ← #417-3.

**#345.** The `-2` commit minus the production "Replace the default in-process memory cache store" comment and
`cache.yml`'s commented `max_age` lines. Message unchanged. Comments left: the Gemfile section header and the
`database.yml` checkpoint line. Guards: none.

**#346.** Reconciliation checked and rejected: `Room#destroy_later` leaves a closed room without memberships, and an
admin can leave a closed room the same way (`Rooms::ClosedsController#update` revokes any members), so re-enqueuing
`Room::DestroyJob` for such rooms after a restore could delete a live room. Re-running banned users' removals would
cover only that half. Copying both files at the same instant would not help either: the room's update and its job
are separate commits in separate databases. So the gap is accepted as stated (pending Thomas), in the commit message
and the body: a job enqueued while the backup runs can be missing, so a room deleted in that moment comes back closed
and without members, with its messages; a job running at the backup comes back claimed by its process and fails
once that process is pruned (`ProcessPrunedError`). The queue-first comment and the matching message sentence are
gone. New test `test/script/admin/prepare_backup_test.rb` (in the style of `reset_password_test.rb`): it loads the
real script with a claimed job (process row included) and a queued one, then reads both backup files. It fails on
the `-2` script with the queue snapshot removed (`no such table: solid_queue_jobs`). The hook itself
(`hooks/post-restore`, `/rails` paths) stays untested, as on main. The test environment's queue database moves here
from #417, since the backup test needs it. Comments added: `# SQLite can't back up a connection in the middle of a
write transaction.` above `use_transactional_tests = false` (else someone turns them back on; inside the fixture
transaction the backup copies zero pages). Others as in `-2`.

**#347.** Inherits both; the Cable commit is unchanged. No Codex P1 reply until Thomas decides #346's gap.

**#417.** The approved retry commit on `2394bc3997`, minus the test queue database and its message paragraph. Body
adds: "A job missing from a restored queue isn't there to retry." Guards and comments as in `-2`.

**#352.** `source.css("*")` → `source.xpath(".//*")` and "a long selector of" in the message (first built as
`015240e9e2` with "fifty", replaced on the fork branch by `dd74f7028c`, same tree). Byte-identical to main on the 13
fixture bodies plus 7 adversarial ones. No dense-input test: a timing test would be flaky. Guards and comments as in
`-2`. Dense timings, one call each, no JIT, one Callgrind process on the other CPU
([cf352_dense.txt](../../bench/upstream/campfire-rework/cf352_dense.txt)):

| `<span>x</span>` × | main | `-2` `59f8a80bf6` | `-3` `015240e9e2` | main again |
| ---: | ---: | ---: | ---: | ---: |
| 3,000 | 0.56 s | 0.61 s | 0.23 s | 0.49 s |
| 12,000 | 1.77 s | 1.72 s | 0.73 s | 1.68 s |
| 90,000 | 15.57 s | 94.37 s | 6.69 s | 21.27 s |

Body number: `script/upstream-bench`, declared cohort in
[cf352_cohort.md](../../bench/upstream/campfire-rework/cf352_cohort.md). The `-2` cohort
([interp](../../bench/upstream/campfire-rework/body/CF352-interp/table.md),
[YJIT](../../bench/upstream/campfire-rework/body/CF352-yjit/table.md)) is diagnostic only. Its YJIT table was
computed by hand from `raw/`: the run was stopped during its last window, so one A/A is missing and that row makes no
claim. Instructions per call, no JIT: −53.6% to −65.7%, A/A ≤ 0.13%. The `-3` cohort, candidate `015240e9e2`
(same tree as `dd74f7028c`), gives the body table
([interp](../../bench/upstream/campfire-rework/body/CF352-3-interp/table.md); the script's header comment was rewrapped
mid-run, comments only):

| No JIT | Instructions, main | `-3` | Change | A/A | Objects, main → `-3` |
| --- | ---: | ---: | ---: | ---: | ---: |
| plain | 1,797,206 | 734,556 | −59.1% | 0.00% | 451 → 286 |
| mention + link | 3,403,479 | 1,101,044 | −67.6% | 0.33% | 820 → 365 |
| formatted list | 3,216,595 | 1,407,040 | −56.3% | 0.07% | 891 → 521 |
| Lexxy paragraphs | 2,950,623 | 999,700 | −66.1% | 0.08% | 576 → 384 |

`body/CF352-3-yjit` is still running and not committed; it goes into the record when it finishes, not into the body.

**Browser suites.** The sign-in failure is main's, not ours. `sign_in` asserts `a.btn` "Designers", which is in the
sidebar, a turbo frame loaded by a second request after the room renders (`sidebar_turbo_frame_tag(src:
user_sidebar_path)`), within Capybara's default 2 s. Likely cause, not proven: on a loaded orb that request takes longer, and the frame
replacing itself would explain the stale element too; the review's captures show the signed-in room, consistent with
that. It failed the same way on clean main in the review. Here, one process per file, `-3` #346 signed in 18 times in composer, unfurling
links and sending messages, with 0 sign-in failures. This orb's Chrome for Testing 158 rejects Capybara 3.40's
`Storage.clearDataForOrigin(origin: "*")` in every teardown, on main too (`* is not a valid URL`), so these runs are
not green; they only show sign-in. The CF347 OOM was the four-GB orb running all 30 browser tests in one process;
per file they pass (review).

### Open questions (fix round)

1. #346: accept the stated residual gap between the two snapshots?
2. #350 and #374: closed upstream on 2026-11-18 (Lowrail `f44cdb21`); nothing left to decide.
3. #352: the body uses the `-3` no-JIT table; the YJIT run follows in the record only.
