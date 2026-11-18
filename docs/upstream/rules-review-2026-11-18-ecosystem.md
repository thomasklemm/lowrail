# Rules review of the open ecosystem PRs (2026-11-18)

Scope: the 36 open non-rails/ruby PRs in [pr-queue/items](../../bench/upstream/pr-queue/items) listed below, checked against
the two rules recorded today in [DECISIONS](../DECISIONS.md#submission-queue-2026-11-03) (`a85fd9b9` guards, `9fa887a3`
comments), against [PR descriptions / Leave out](../DECISIONS.md#pr-descriptions-thomas-2026-11-03-to-11-05), and for
what needs updating (conflicts, red CI caused by us, unanswered questions, body claims that no longer match the head or
master). The coordinator added two scopes: the bodies of I18N764, I18N765, INR436 and RK3 (body only), and the Amp/Claude
trailers in the Campfire PRs. RK3, INR436, I18N764 and I18N765 code was left alone; SC1 was only reviewed.

Guards reuse [guard-simplification-2026-11-18](guard-simplification-2026-11-18.md) and add a second look at what it kept.
The comment audit is fresh: every comment line added in each PR diff, lib and tests, from the merge base to the head
(`.amp/in/orb-backup/comments.rb`).

Nothing upstream-visible changed: no PR branch was pushed, nothing was posted, no body was PATCHed. New work is on fork
branches with the suffix `-lean`. Single-PR candidates are one commit on the PR's base (TAP2748 on current main),
Thomas Klemm author and committer, the original author date, `/usr/bin/git commit-tree`, no trailers (checked with
`git cat-file commit` and `%(trailers:only)`). Proposed bodies are in the items, unposted; each changed item has a dated
note line. One temporary branch, `thomasklemm/master-ci-baseline` on the cells-rails fork (master's commit, to get a
master CI run), was created and deleted again; forks don't run that workflow, so nothing ran.

## Status on GitHub

- All 36 PRs are open; every fork branch is at the item's `head`.
- `script/pr-queue status`: MERGE is `clean` for all 36, no conflicts. BASE-MOVED: CF345/346/347/350/417 only on
  `Gemfile.lock`, TZ2 six commits on `zoneinfo_reader.rb` (Phil Ross, 2026-11-16, merged #170 and simplified pack
  templates; our lines are untouched and `make_signed_int64` is still on master, so TZ2's body stays true).
- Red CI: only CELLS75 (16 of 19 jobs), not ours (below). DRV1/DRV2 135/135, IMP336 45/45, ruby-bench 15/15, Campfire
  8 + 1 skipped, RACK2550 16/16, PSH289 16/16, TAP2748 2/2, DS1 green. WAL150, RMP670, LAGO91, SC1, RCP550–552, RCR1670,
  I18N763, I18N766, BD562, TZ1, TZ2 and NOKO3759 have workflows `action_required` (first-time contributor approval) or no
  checks: nothing for us to fix.
- Maintainer questions: none unanswered. apotonick's 2026-11-05 question on CELLS75 ("what is Lowrail?") was answered by
  Thomas the same day, no follow-up. flavorjones (NOKO3759, DRV1, DRV2) said he'd review; Thomas's TAP2748 ping (11-17)
  has no reply. Unanswered contributor and bot threads are on CF350 and CF347 (below).
- Amp/Claude trailers: every open Campfire PR has commits with `Amp-Thread-ID`, `Co-authored-by: Amp`,
  `Co-Authored-By: Claude Opus 5.5` or `Claude-Session` lines (CF320 also has Cursor Agent commits with
  `Co-authored-by: Thomas Klemm`). Trailer-free rebuilds below; rewriting the PR branches is Thomas's call.

## Ranking of proposals

| Rank | Item | Proposal | Fork branch, SHA | Checks | Thomas decides |
| --- | --- | --- | --- | --- | --- |
| 1 | I18N763 | `!locale.equal?(fallback)` → `locale != fallback`; drop the test built on a locale with its own `==` | `thomasklemm/fallback-locale-identity-lean` `54bd38deb6` | `rake test` 1607 runs 0 F/E; probe: objects 14 → 12 and 22 → 20 like the head, same on_fallback calls | adopt (lease-push, body PATCH) |
| 2 | TAP2748 | drop the `namespace == Object` clause, comment to one line, one commit on current main instead of commit + merge; body trimmed | `fix/skip-unused-active-support-configurable-lean` `dd72843fdf` | both Configurable CLI specs pass, `srb tc` clean, RuboCop clean; reflection_spec's 3 failures are the same on main | adopt |
| 3 | RCP551 | drop the literal-nonnegative-count guard (any count corrects to `[0, n].chars`), drop the CLI spec and the negative-count spec | `thomasklemm/fix-471-string-chars-lean` `9678439296` | `rake default` 9,367 examples 0 F, 126 files no offenses | adopt; negative count now raises NoMethodError instead of ArgumentError (cop is `Safe: false`) |
| 4 | RCP550 | drop the `--safe` CLI spec and the rewritten constant comment; one commit instead of two; body without Validation | `thomasklemm/chain-array-ownership-lean` `4a8d45fd01` | `rake default` 9,364 examples 0 F, 126 files no offenses | adopt |
| 5 | Campfire ×8 | trailer-free rebuilds with identical trees (CF320 plus the upstream log-scrubber comment restored, CF352 plus comments shortened); bodies without Verification sections and stale SHAs | see the CF sections | trees identical to the heads; CF352 content-filter tests 21 runs 0 F, RuboCop (omakase) clean on changed files | whether to rewrite eight open PR branches (force-push) |
| 6 | Bodies | Leave-out cleanup of 29 bodies (counts, commands, SHAs, Ruby lists, review history), including I18N764, I18N765, INR436, RK3 | items | read against DECISIONS | PATCH the bodies |
| 7 | I18N766 | the four-line comment to the proposed one line; drop the standalone-require test (it covers `fallbacks.rb`, which the PR doesn't touch) | `thomasklemm/fiber-storage-check-once-lean` `82a4e905d2` | `rake test` 1608 runs 0 F; mutant without the fallback check: 1 F | adopt |
| 8 | ruby-bench ×4 | comments to one line: RB-PV (3 → 1), RB569 (three comments, 10 → 3 lines), RB570 (test, 2 → 1), RBW1 (seven benchmark comments, 15 → 4 lines, comment-only) | RB-PV `eab160f192`, RB569 `bad4d5a33b`, RB570 `72d6a6d5c4`, RBW1 `eb8364d248` | suite 370/365/358 runs 0 F (1 E = rmagick not built here, same on main); RBW1 syntax OK, diff has 0 non-comment lines | adopt (lease-push four ready PRs) |
| 9 | WAL150 | test comment 2 → 1 line | `thomasklemm/materialize-try-lock-transaction-lean` `f636c07984` | transaction_test 7 runs 0 F (PostgreSQL 17, MariaDB, Rails 8.1.4.1) | adopt with the Rails 8.2 update the body promises |
| 10 | IMP336 | `if nonce.nil?` → `if nonce` (a false nonce gets the cached tags, without `nonce="false"`); drop the false-nonce assertion | `thomasklemm/preload-tag-allocations-lean` `71e08b02ec` | `rake test` 106 runs 0 F (repo has no RuboCop in its bundle) | adopt or keep; this one changes output for a `false` nonce |

Open threads that need a reply or a fix, not code from me: CF350 (namespaceMarcello's 2026-10-27 comment, a 500 on
invalid stored bodies, two commits offered) and CF347 (two Codex findings still valid, two obsolete). Both are below.

## Per item

### WAL150 (ClosureTree/with_advisory_lock#150, draft)

Guard `respond_to?(:internal_exec_query, true)`: kept, the file's own check for the blocking path in the same method.
Comments: lib `# Rails < 8.2` and `# Rails 8.2+ - materialize …` keep (mirror the blocking branch above them); test
two-line comment above `try_lock_while_held`: shorten, built. Body: the full-suite sentence (Rails pins, Ruby,
PostgreSQL/MariaDB versions) cut. Needs: nothing now; the draft waits for Rails 8.2 beta, as its body says.

### RMP670 (MiniProfiler/rack-mini-profiler#670)

Guard `next if !should_measure?`: kept, the same line opens every other subscriber in the file. No comments. Body fine.
No change.

### TAP2748 (Shopify/tapioca#2748)

Guards, second look: the `namespace == Object || start_with?("::")` clause goes (only `register_cname` passes a namespace,
with a bare name the regexp can't match). Kept: the regexp (the target), `defined?(::ActiveSupport)` (non-Rails gems),
`autoload?(:Configurable)` (apps that loaded it, covered by the positive-control spec), `gem_version >= 8.1` (on 8.0 the
autoload is pending too but loading it doesn't warn, so skipping it would drop Configurable from RBIs). Comments: the
two-line comment → one line, built. Spec `skip(...)` lines keep (the hosted matrix runs Rails 8.0). The head is the
commit plus a merge of main; the lean branch is one commit on current main `070a69be`. Body: the Tests section listed
commands and counts (79 tests, 571 assertions …) and "reproduces on current main and 0.20.0"; cut to three short
sections in the template's headings. The ping of 11-17 has no reply.

### CF320 (basecamp/once-campfire#320)

Guards: `request.authorization.nil? ? path key : bearer key` (documented fallback), `next_page_url`'s branch (legacy vs
header link) keep. Comments: `# Keep the key out of the link when it arrived in a header.` keep; routes `# Literal "bot"
must stay above :bot_key …` keep (stops a reorder); the PR rewrote upstream's four-line comment in
`log_scrubbing_formatter.rb` into three different lines: remove that change, upstream's comment is still accurate.
Trailers: 8 commits; `db633a55c6`, `1d12149037`, `69bdc323d3`, `e7fc7edf4b` (Cursor Agent, `Co-authored-by: Thomas
Klemm`), `a462a738f6` (Claude, Claude-Session), `61cca8f7c4`, `5bf2557dec`, `fb03d706ed` (Amp-Thread-ID). Built
`cursor/bot-key-header-not-path-8545-lean` `fd3d1493ca`: the eight commits with identical trees, Thomas as author and
committer, original dates, no trailers, plus one commit "Keep the log scrubber comment as it was" (the PR no longer
touches that file). Body (147 words) fine.

### CF345 (basecamp/once-campfire#345)

No added guards. Comments: Gemfile `# Caching` keep (the Gemfile's own section headers); `config/database.yml` two-line
checkpoint comment shorten to one ("Only the primary DB has a checkpoint contender; keep SQLite's auto-checkpoint
here."); `production.rb` `# Persist the Rails cache in its own SQLite database.` keep (Rails' generated config style);
`hooks/post-restore` cache line keep. Trailers: all 8 commits (`2ff0da66a0` … `e369cd69c2` Amp, `8c8551b005` Claude).
Built `deps/solid-cache-lean` `58e0ca9af4` (identical trees). Body: the Verification section (run counts, "Before
pushing", rebase history) cut. Comment trim not built; see the stack note under CF347.

### CF346 (basecamp/once-campfire#346)

No added guards beyond `return yield if pending_enqueues` (nesting, a real caller). Comments: `messages_controller` one
line keep; `ApplicationJob.enqueue_together` four lines shorten to one ("Written in one queue transaction when the block
ends, even if it raises or its DB transaction rolls back."); `database.yml` pool line keep, checkpoint two lines
shorten; `solid_queue.rb` shutdown two lines shorten ("Docker kills the container 10 s after SIGTERM; leave a running
job 8 of them."), flock three lines shorten ("The checkpoint contender holds a flock, so each forked process starts
its own."); edits to existing comments in `sqlite_wal_checkpoint` keep; `recurring.yml` examples keep (installer
template); `post-restore` two lines keep. Trailers: 5 commits (`30cc18a7f9`, `8b355201b5`, `4682c0f455` Amp;
`fd886a8120`, `d4ce22b0e2` Claude), shared with CF347 and CF417. Built `feat/solid-queue-cutover-lean` `3703ab13b4`.
Body: Verification section cut; the stale "Before pushing `0853d7a`" (head is `cbee3f930e`) goes with it. Codex's P1 on
#347 (restore drops queued `Room::DestroyJob` / `RemoveBannedContentJob`) applies to this PR, which introduced the
disposable queue.

### CF347 (basecamp/once-campfire#347)

Comments as CF345 + CF346, plus `bench/compare_http.rb` two-line note keep, `room.rb` edit keep, `post-restore` three
lines shorten. Trailers: 17 commits (CF345's and CF346's chains plus `5e8ec29c3f`, `0f5cfc8961` Amp and
`cbd2494665`, `0d5b91edae`, `775adcdfaa` Claude). Built `deps/solid-cable-removal-lean` `6120514d7d`; its first five
commits are the same objects as CF346's and CF417's rebuilds (`10c391d707`), so the stack stays shared. Body:
Verification section cut (stale "Before pushing `6277f5b`").

The four unresolved chatgpt-codex-connector threads:
- `hooks/post-restore:15` P1, restore drops pending deletion jobs: still valid on the head and unanswered. Proposal: a
  reply that the queue is disposable by design plus a fix in #346, for example re-enqueueing `Room::DestroyJob` for
  closed rooms still holding messages and `RemoveBannedContentJob` for banned users with visible messages after restore
  (`post-restore` or a boot check). Thomas decides; not built.
- `config/cable.yml:12` P2, `async` in development across Puma workers: valid (`config/puma.rb` starts
  `processor_count * 0.666` workers in development too). Proposal: `solid_cable` in development, or one worker in
  development. Not built.
- `bench/compare_http.rb:49` P2, one image for both sides: obsolete, `--baseline-image` (9300e44) answers it; reply with
  the commit and resolve.
- `config/queue.yml:21` P2, missing `performance` section: obsolete, the head has it; resolve.

The two Copilot threads are answered (9300e44, Resque 2.7's `queue_sizes`) but unresolved.

Stack note: the comment trims for CF345/346/347/350/417 are not built. They touch shared commits; once Thomas decides on
the trailer rewrite, they go in as one trim commit per layer on top of the `-lean` branches.

### CF350 (basecamp/once-campfire#350)

Guard `messages.respond_to?(:preload_associations)`: kept, search results reach `message_runs` as plain relations/Arrays.
Comments: `messages_helper.rb` run comment three lines → one; the `updated_at` key comment two → one; the
`text_message_presentation` two → one; `pagination.rb` two → one; `cached_responses.rb` "One immutable snapshot …"
remove (says what); `_message.html.erb` "Bump message_fragment_cache_key …" keep; `fragment_caching.rb` keep;
`version.rb` two → one. Trailers: 13 commits (CF345's 8, `449693ece4` Amp, `d10c5a5307`, `eb053851e0`, `7d356f4ab0`,
`49e1b2d588` Claude). Built `perf/native-fragment-cache-lean` `003666b584`. Body: review history ("Oracle reviewed …"),
the rejected variant, stale SHAs (`3a59b4e`/`f5be953`) and the verification counts cut; still about 1,000 words because
of namespaceMarcello's measurement sections.

Unanswered: namespaceMarcello's comment of 2026-10-27 ([issuecomment-6437614380](https://github.com/basecamp/once-campfire/pull/350#issuecomment-6437614380))
offers two commits (`af77995`, `6077be9` on `namespaceMarcello:raw-fragment-keys`) that key fragments by stored values
and fix a 500 in `message_fragment_cacheable?` for a body stored as invalid text. They cherry-pick cleanly onto the head.
There is no review thread from him; the one open review thread is Codex's P2 (`production.rb:72`, run `db:prepare` before
the benchmark's Puma), still valid on this head (#347 fixed it in its own `compare_http.rb`). Proposal: take his two
commits (they carry his authorship) and reply; Thomas decides.

### CF352 (basecamp/once-campfire#352)

Guards: `!url.nil? &&` and the `to_html.include?` pre-check are the change itself (skip `to_plain_text` and the selector
search). Comments: three multi-line comments shortened to one line each, built. Trailers: the one commit (Claude,
`Co-Authored-By` and `Claude-Session`). Built `claude/project-thread-1ks0h3-lean` `670f8ce0df`, message without the two
trailer lines. `bin/rails test test/helpers/content_filters_test.rb` 21 runs 0 F; RuboCop clean. Body: Verification
counts and the ABBA methodology cut, table cut to three rows.

### CF374 (basecamp/once-campfire#374)

No guards. Comment `# Use URI.join's parser once for the common base, rather than once per import.` keep (stops someone
inlining it back). Trailer: the one commit (Amp-Thread-ID). Built `thomasklemm/faster-csp-script-locations-lean`
`1164efd653` (identical tree). Body (494 words, Validation with counts, "Reviewed with Oracle … (Thermos)", cohort
methodology) cut to three paragraphs and a two-row table. rubys's comment (composes with #370) needs no reply.

### CF417 (basecamp/once-campfire#417)

Guards in `RetryInterruptedJobsJob`: the error-class check, the allowlist and the retry cap are the policy, each covered
by the test. Comments: class comment four lines → one; `FailedExecution#retry resets …` keep; `Retried or discarded by
hand in the meantime.` keep; `test.rb` keep; inherited CF346 comments as there. Trailers: 5 of its 8 commits, all shared with
CF346. Built `feat/retry-interrupted-jobs-lean` `3c13b55961`. Body: "Before pushing `e9b24d9`" (stale,
head `eb8c6d9ce8`) and counts cut; the interruption table stays.

### DS1 (discourse/discourse#45658)

No guards, no comments. Body: the test-run paragraph (spec counts on Rails 8.1.4.1 and main) cut.

### LAGO91 (getlago/lago-expression#91)

No guards, no comments. Body: the Testing section (commands, example counts, `b51db981f6`) and the rb-sys pin cut.

### SC1 (pond/scimitar#172, draft, held; review only)

Guard `parsers.frozen? ? parsers.dup : parsers` with a write-back if frozen: more than a maintainer would write; the
writer-only form `e81365a6e0` is simpler but Sol and Astra marked it P2 (Rails ≤ 8.1 code holding an earlier reference).
Thomas's call, unchanged. No comments in lib or spec. Body (101 words) fine. Nothing built.

### RACK2550 (rack/rack#2550, approved by jeremyevans)

Guard `Array === value`: the file's own line. No comments. Body: Ruby master SHA and the "two runs differ …, best of
seven" methodology cut.

### IMP336 (rails/importmap-rails#336)

Guards, second look: `nonce.nil?` exists only to keep a `false` nonce rendered as `nonce="false"`, a value Rails'
generator doesn't produce; a maintainer writes `if nonce`. Built, with the `false` assertion dropped. `request&.` keep
(mailers). Comment: `# :nodoc:` directive keep. Body: the raw benchmark-ips output with the Ruby revision line → a
two-row table.

### PSH289 (rails/propshaft#289)

No guards, no comments. Body fine (the table heading says what was measured). No change.

### RCP550 (rubocop/rubocop-performance#550)

No guards. Comments: the `@safety` and `@example` YARD text is the documentation this PR delivers, keep. The two-line
rewrite of the `ALWAYS_RETURNS_NEW_ARRAY` comment: remove, and drop only the original's now-wrong second line ("after
they're called it's safe to mutate …"). The `--safe` CLI spec tests RuboCop's handling of `Safe: false`, not this cop:
drop. Built as one commit. Body: Validation section (master SHA, pins, app table with SHAs, private app, example counts)
and the 1,321-examples anecdote cut; the template's checklist stays.

### RCP551 (rubocop/rubocop-performance#551)

Guards, second look: `args.first.int_type? && !args.first.value.negative?` for `first`/`take` keeps ArgumentError for a
negative literal and skips dynamic counts; with `Safe: false` that's more than needed, and `[0, n].chars` still raises
for a negative `n` (NoMethodError instead of ArgumentError) and matches for every other count. Kept: `args.count > 1`
(two-argument `[]` changes shape) and `type?(:int, :range)` for `[]`/`slice` (a dynamic index can't be told apart). Drop
the CLI spec (tests RuboCop, not the cop) and the negative-count spec. Built; changelog and commit message updated. Body:
"Validated on Ruby 3.1.2" with counts and the 10,234-comparison line cut; the count bullet now says what changed.

### RCP552 (rubocop/rubocop-performance#552)

Documentation-only PR; the `@safety` text is its content (four short paragraphs, maintainers' call on length). Body:
"Verified on Ruby 4.0.8" with counts cut. No code change.

### RCR1670 (rubocop/rubocop-rails#1670)

Guard `MATERIALIZING_METHODS.include?` is the fix. No comments. Body: Ruby/AR/sqlite3 pins, run-by-run object counts,
"16 failures with the upstream cop" and the Validation section (SHA, commands, counts) cut; the reproduction script
stays in its details block.

### I18N763 (ruby-i18n/i18n#763)

Guard, second look: `!locale.equal?(fallback)` plus a test with a locale object whose `==` lies exist only so such an
object behaves as before; locales are Symbols or Strings. `locale != fallback` is what a maintainer writes and settles
Symbols the same way (String vs Symbol still falls through to the `to_s` comparison). Built; the commit message drops the
`equal?` paragraph. Body: "(1,608 runs)", Testing section and the weird-`==` sentence cut.

### I18N766 (ruby-i18n/i18n#766)

Guard `FIBER_STORAGE || Fiber.respond_to?(:[])` kept (fiber-storage gem on Ruby 3.1, a real caller; dropping the
fallback fails the retained test). Comment: the sweep's one line ("Fiber[] can still be defined later, e.g. by the
fiber-storage gem on Ruby 3.1.") passes the rule: it stops someone simplifying the check to the constant. Built. The
test `fallbacks can be set when the fallbacks backend is required on its own` covers `fallbacks.rb`, which this PR
doesn't change: drop. Body: "(1,609 runs)", Testing section and the `I18n.fallbacks` sentence cut.

### BD562 (ruby/bigdecimal#562)

No guards (the `uval == 0` branch exists on master), no comments. tompng's thread is answered (moved into
`rb_uint64_convert_to_BigDecimal`, 11-10) and outdated. Body: the Ruby list (2.6.10/3.4.12/4.0.9/master), the
"not a speed claim" sentence and the 50-line reproduction script cut; table kept.

### RB-PV, RB569, RB570, RB571, RBCG1, RBW1 (ruby/ruby-bench)

Guards kept as in the sweep (feature detection for Ruby < 4.1 and modular GCs, nil checks for data the runner writes).
Comments: RB-PV p-value comment 3 → 1; RB569 `collection_records_supported?` 2 → 1, `marking_times_since` 5 → 1 (the
signature and return line say the rest), `collection_series` 3 → 1, `harness/gc.rb` global-GC line keep, two test
comments keep (they explain expected values); RB570 test comment 2 → 1; RB571 `# Avoid calendar-dependent DST …` keep
(the other lines are upstream's, re-indented); RBCG1 one line keep; RBW1 seven `benchmark.rb` comments cut or shortened,
trailing `# what Turbo sends`-style notes and the generated Rails app's comments keep (generator output, listed in the
README). Bodies: RB-PV's "How this was measured" details (commands, SHA) cut; others fine.

### NOKO3759 (sparklemotion/nokogiri#3759)

No guards. The moved comment `# 'children' is a smell here` is upstream's. Body: "two runs … differ by less than 0.3%",
"Objects were counted on 1.19.7" and "The suite passes on CRuby 4.0.9 …" cut; the template's three questions stay.

### DRV1, DRV2 (sparklemotion/sqlite3-ruby#769, #770)

DRV1: no guards or comments. DRV2: `#ifndef TRUFFLERUBY` keep (Astra's finding); `length > 1` keep on a second look,
dropping it adds one store per single-column row. No comments. Bodies: "These measurements use SQLite 3.40.1 …" cut.

### CELLS75 (trailblazer/cells-rails#75)

Guard `if defined?(ActionView::Helpers::NavigationHelper)` keep (Rails < 8.2). Its trailing comment
`# link_to, button_to, current_page? (Rails 8.2+)` keep, matching the `FormHelper` line above it.

Red jobs (run 42038773640), none ours: Rails 6.0 on Ruby 2.5–3.0 `uninitialized constant
ActiveSupport::LoggerThreadSafeLevel::Logger` at boot (concurrent-ruby 1.3.8); Rails 7.1/7.2/8.0 on Ruby 3.0–3.2
`SimpleFormTest` (newer simple_form drops `aria-required`, 1 of 78; the new LinkCell test passes); Ruby 3.3 with
Rails 7.1/7.2 `line_filtering.rb … wrong number of arguments` (Minitest 6.0.6); Ruby head `cannot load such file --
ostruct`. The three green jobs are Rails 5.2. Locally on Ruby 4.0.9 with `gemfiles/8.0.gemfile`, master and the PR fail
the same way (ostruct). Master's last CI run was November 2024; forks don't run the workflow, so there is no master run
to link. Thomas's 11-05 comment already says this and offers a CI fix; his 11-15 decision (leave as is) stands.
apotonick's comment is answered. Body fine.

### TZ1, TZ2 (tzinfo/tzinfo#175, #171)

TZ1 guard `return true if equal?(tti)` is the change. TZ2 no guards. No comments. Bodies: TZ1's Rails main SHA,
`rake test`/fork-CI line and the differential sentence cut; TZ2's fork-CI line cut. Phil Ross merged #170 on 11-16, so
the repo is active again.

## Bodies only (coordinator addendum)

- **I18N764**: "(1,608 runs, 2,676 assertions)", the Testing section, the 20-app census and the three rows "measured on
  the original guarded version" cut; the table keeps the two rows reproduced on the simple head (String 23 → 21, Symbol
  29 → 27).
- **I18N765**: "(1,608 runs, 2,680 assertions)", the Testing section and the instruction and census sentences that were
  not rerun cut; the three object rows were reproduced on the head.
- **INR436**: the live body has a Checks section (Ruby/Rails pairs, 1102/1098/1098 examples, commands) that the
  inertia-rails template doesn't ask for (it asks for Summary, Test plan, Checklist). No proposal: while this review ran,
  skryukov took the PR over (head `02fd0511ae`), and the item says no body edits from us unless he asks.
- **RK3**: cut to about 330 words: the 300,000-string differential with its Ruby/cgi lists, the allocator methodology,
  the "earlier revision" note, the CGI history (2.4/2.7/4.0), the fork-CI paragraph and the per-app no-YJIT numbers.
  Kept: what changes and the boundaries a reviewer asks about (`*`/`~`, String subclasses, non-ASCII-compatible
  encodings, `BasicObject`, instance variables on the escape fast path), one table, one app sentence (YJIT).

No change needed in the bodies of CF320, PSH289, RMP670, RB569, RB570, RB571, RBCG1, RBW1, SC1, CELLS75; the Campfire
migration bodies (CF346, CF347, CF350) stay long because of the measurement sections namespaceMarcello contributed.
