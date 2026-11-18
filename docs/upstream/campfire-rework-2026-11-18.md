# Campfire PR rework (2026-11-18)

Scope: our eight open basecamp/once-campfire PRs (#320, #345, #346, #347, #350, #352, #374, #417), rebuilt on current
`main` (`7b80988`, Puma 8.0.3) with the smallest diff, after the
[rules review](rules-review-2026-11-18-ecosystem.md) of the same day. It replaces that review's `-lean` rebuilds.
Thomas approved: removing the trailers from all eight PR branches, adopting namespaceMarcello's two #350 commits
(`af77995`, `6077be9`) with him as author, and fixing Codex's two valid #347 findings.

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

Reviews: none run on the `-2` heads yet. The thermos-sol confirm in progress reviews the `-lean` heads; the
coordinator decides which passes the `-2` heads need.
