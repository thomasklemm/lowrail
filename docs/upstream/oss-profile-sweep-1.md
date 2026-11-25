# OSS profile sweep 1: lowrail-profile 0.1.0.rc1 on six unfamiliar Rails apps (2026-11-25)

Bet (a) of [DECISIONS](../DECISIONS.md) "Next bets after the first three": run lowrail-profile on open-source Rails
apps outside the corpus, as a field test before 0.1 and as a source of upstream fixes with real callers.

## Result

* **Six apps, Rails 7.2.3 to 8.1.4.1 and Ruby 3.3.14 to 4.0.9.** Each was installed the way a stranger would install
  it and profiled on its own suite. Every app had the same per-test outcomes plain and profiled, in every capture.
  Five of the six trees stayed unchanged. On Dawarich the profiled run rewrote a tracked file (T4).
* **A/A compare** exits 0 on Redmine, Solidus, Huginn and Dawarich. On Forem (serial) an unchanged head exits 1 with
  three regressions and two improvements, each the same in both of head's windows (T9). On
  openstreetmap-website, a suite with 8 parallel workers, it exits 1 on unchanged code, and so does the README's second-head CI job (T3).
* **Four tool problems that matter for 0.1.** T1: a `path:` gem outside `Rails.root` disappears from the report.
  T2: controller tests count nothing, contrary to the README. T3: compare false-alarms on parallel suites. T4: the
  seed variable reaches nested rspec runs and changes what the app writes. T1–T4 were sent to the builder thread as
  they turned up. T1, T2 and T4 are fixed on main (rerun below); T3 is being fixed there. Smaller ones are T5–T10.
* **Ranked findings** (share of request allocations, averaged over the five apps that serve requests):
  rqrcode_core's `rszf` is first at 5.0% (23% of Dawarich, 1.8% of Redmine) and unowned. cancancan's rule
  construction is next among production lines (1.8% Solidus, 0.9% openstreetmap-website) and unowned. Prosopite
  (8.2% of openstreetmap-website) is test-only. Most Rails lines are one object per operation and already in
  Lowrail's census data, our queue or upstream. Hashie's line in Forem is fixed upstream in 5.2.0, which Forem does
  not run yet.
* **Rerun on main c68afc98** (same gem sha256 as the builder's): Dawarich's tree and swagger.yaml stay unchanged
  (T4 fixed); Solidus's `solidus_core` lines are now a gem group of 424.6 objects per request (T1 fixed);
  `--timeout` stops Huginn at 30 s with exit 124. Outcomes match plain in every run. New: T9 and T10.
* **Two fork branches, queue items in state `built`.**
  [RQ1](../../bench/upstream/pr-queue/items/RQ1.md): `thomasklemm/rqrcode_core` `thomasklemm/rszf-without-bignums`
  @ `51c099c822`, 45,453 → 6,055 objects per TOTP QR code (−86.7%).
  [CC1](../../bench/upstream/pr-queue/items/CC1.md): `thomasklemm/cancancan` `thomasklemm/rule-construction-allocations`
  @ `2a5e8c71d1`, 57 → 47 objects per six-rule ability, −2.9% instructions without JIT and −4.4% with YJIT. A third
  unowned lead (posthog-rails's header scan, 1.1% of Dawarich at 100% reach) was not built: that repository requires
  signed commits and changesets (below). Nothing was opened or posted upstream.

## Install and method

* **Gem:** `gem build lowrail-profile.gemspec` in `gem/` at Lowrail main `aa4422c8` (the profiler files are those of
  `687f168b` and of the final receipts), sha256 `f569d5f5ebbf20902d4cdc84dc7fc5e7b895efd2b90988cd6e16898de0a86d31`,
  the same as [the final receipts](../../bench/upstream/profile_release/2026-11-25-final/README.md).
  `gem install --local` into Ruby 3.3.14, 3.4.13 and 4.0.9 (mise), then one Gemfile line per app,
  `gem "lowrail-profile", group: [:development, :test], require: false`, and `bundle install`. Nothing else in the
  app changed, apart from the setup its own CI does (database config, `.env`, assets).
* **Per app:** a plain suite with `SEED=1234` / `--seed 1234` and per-test output (`bin/rails test -v`,
  `rspec --format documentation`). Then `bundle exec lowrail-profile --out tmp/lowrail-profile -- COMMAND` (the
  default two runs), with the per-test outcomes of both runs diffed against plain. The tree was snapshotted before
  and after: `git status`, the hash of every tracked or unignored file, and the list of ignored paths
  ([tree.sh](../../bench/upstream/oss_profile_sweep_1/tree.sh)). Two more captures, `aa` and `head`, gave
  `compare base head --aa aa`.
* **Services:** PostgreSQL 17 (with pgvector and PostGIS), Redis 8.0 and memcached, all local in the orb. The orb ran
  up to four suites at once on 8 cores, so the wall times below are rough.
* **Ranking:** [rank.rb](../../bench/upstream/oss_profile_sweep_1/rank.rb) reads each app's `report.json`
  (`ranked`, request windows, dev/test work left out). It takes each line's all-requests objects per request as a
  share of the app's objects per request, and averages the share over the five apps with requests. It matches a
  line across apps by file, method and source text from each app's own bundle, so the same Rails line at another
  line number counts once.
* **Receipts:** [bench/upstream/oss_profile_sweep_1](../../bench/upstream/oss_profile_sweep_1) holds, per app and
  capture, `report.md`, `capture.json`, `command.txt` and `report.json.gz`, plus outcome lists, tree snapshots,
  compare outputs, log tails and each bundle's paths. The per-process TSVs (`run1/`, `run2/`, up to 100 MB per
  capture) are not kept; `report.json` holds everything the report reads.

## Apps

| App | Commit | Ruby / Rails | Suite profiled | Requests / jobs / mails counted | Outcomes plain vs profiled | Tree | A/A compare |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [Redmine](https://github.com/redmine/redmine) | `638024fbc38dd96cfa8a750b84f71fc2e37130ec` | 3.4.13 / 8.1.4.1, SQLite | `bin/rails test -v`, 6,130 runs | 920 / 2,229 / 1,337 | identical (6,127 lines), 0 F | unchanged | exit 0 |
| [Solidus](https://github.com/solidusio/solidus) API | `600c7f73f66da3c46a52b028d19b1b7a229eb644` | 3.3.14 / 7.2.3 (`RAILS_VERSION='~> 7.2.0'`), rack 2.2.26, SQLite | `rspec` in `api/`, 716 examples | 704 / 0 / 0 | identical (1,028), 0 F | unchanged | exit 0 |
| [Huginn](https://github.com/huginn/huginn) | `4d4fa3f49383bfd621b6b7abc05e1c70fa0c0001` | 3.4.13 / 8.1.4.1, PostgreSQL | `rspec --exclude-pattern 'spec/features/**/*_spec.rb'`, 2,041 examples | 0 / 89 / 0 (T2) | identical (2,601), 0 F | unchanged | exit 0 (jobs) |
| [Forem](https://github.com/forem/forem) | `c5bd9e11c27ba4ac0b4cc1f1cfba27a5de156597` | 3.3.14 / 8.0.5, PostgreSQL + Redis | `rspec spec/requests`, 5,278 examples | 6,765 / 0 / 18 | identical (8,469), 0 F | unchanged | exit 1: 3 regressions, 2 improvements on unchanged code (T9) |
| [Dawarich](https://github.com/Freika/dawarich) | `f6b79c9b826f1d1e1ff7e0e3d7d1b252084dddfe` | 4.0.9 / 8.1.4.1, PostGIS + Redis | `rspec spec/requests`, 3,078 examples (+298 in its nested rswag run) | 4,069 / 4 / 0 | suite identical (4,331 lines); the nested run's 298 in another order (T4), 0 F | `swagger/v1/swagger.yaml` rewritten (T4) | exit 0 |
| [openstreetmap-website](https://github.com/openstreetmap/openstreetmap-website) | `20ae45eccd0bc1efff1125a04429b79d6c74bfbb` | 4.0.9 / 8.1.4.1, PostgreSQL + memcached | `bin/rails test -v`, 2,757 runs, 8 workers | 4,230 / 42 / 15 | identical (2,757) in all 4 parallel and 5 serial captures, 0 F | unchanged | **exit 1 (T3)**; serially exit 0, and the plant exits 1 |

The commits are each app's default branch on 2026-11-25. The only local commit on each is the Gemfile line, and the
lock change on top of it. Forem's `vendor/cache` received the `.gem`, and Bundler deleted six cached gems the lock no
longer listed; those were restored and only the new `.gem` was committed.

**Skipped:** Consul Democracy (`6e00be91ee`): its request specs are few (22), and every system spec runs through
headless Chrome, which hung in the orb. Huginn's 43 feature specs fail plain in this orb as well (Selenium:
"invalid argument: * is not a valid URL"), so they are left out of both runs.

### Overhead

Suite time as each framework reports it, with up to four suites running at once on the orb:

| App | Plain | Run 1 (counting) | Run 2 (also attribution) |
| --- | ---: | ---: | ---: |
| Redmine | 373.7 s | 407.6 s (+9%) | 532.7 s (+43%) |
| Solidus API | 68.5 s | 71.9 s (+5%) | 93.0 s (+36%) |
| Huginn | 59.2 s | 58.0 s (−2%) | 57.7 s (−3%) |
| Forem | 621 s | 801 s (+29%) | 1,035 s (+67%) |
| Dawarich | 524 s | 561 s (+7%) | 746 s (+42%) |
| openstreetmap-website (8 workers) | 75.2 s | 70.1 s | 82.9 s |

These are in the README's range (4–9% counting, 31–87% attribution), apart from Forem's counting run. That run
overlapped with three other suites, so its +29% is not a clean number.

## Tool problems

Plain descriptions. Repro detail is in the receipts and was sent to the builder thread
(T-01a19978-214a-7547-8319-0117b72a0dc7).

* **T1. A `path:` gem outside `Rails.root` is silently missing from the report.** In Solidus's API suite,
  `Rails.root` is `api/spec/dummy` and `solidus_core` is a `path: "../core"` gem. `run1`'s TSV puts 331,538 of
  8,720,639 request objects (3.8%) on `solidus/core/...` lines, and `report.json` has none of them.
  `ProfileReport#classify` files such a path under "other", which is never ranked, and no table says how much
  was left out. Related: the engine's own `api/app` lines are charged through `LOWRAIL_PROFILE_ROOT` (cwd) but
  keyed by `Rails.root`, so "Your code" lists absolute paths (`/home/user/oss/solidus/api/app/...`) instead of
  `APP/...`. Monorepos and engines with a dummy app hit both.
* **T2. Controller tests count nothing.** The README's troubleshooting says "Profile integration, controller, request
  or system tests". `ActionController::TestCase` and rspec-rails controller specs never go through
  `Rails::Engine#call`. Redmine has 2,258 functional tests and 671 integration tests, and only 920 requests were
  counted. Huginn's controller specs count 0 requests (89 jobs). An app with only controller tests and no jobs gets
  "no runs with requests" and a README that suggests what it already does.
* **T3. compare false-alarms on a parallelized suite.** openstreetmap-website runs 8 worker processes. On unchanged
  code, `compare base head --aa aa` exits 1 with four action regressions: NotesController#index 8,167.85 →
  27,067.7 (floor 3,846.4), ChangesetsController#index +4,031, Oauth2AuthorizationsController#create +2,416 and
  Traces::IconsController#show +25.5. A second head exits 1 too (NotesController#index → 25,927.1,
  UserBlocksController#index +1,323.65), so the README's CI job fails on unchanged code. Warm leaves out each
  process's first request of an action, and the workers split the tests anew in each capture, so the A/A pair
  understates the noise. The builder thread's fix makes compare treat a multi-process capture as insufficient
  evidence (exit 2, "profile with PARALLEL_WORKERS=1"). The serial captures below were made for that fix.
* **T4. The seed reaches nested rspec runs.** Dawarich's `after(:suite)` runs `rake rswag:generate`, which starts a
  child `rspec spec/swagger` and writes `swagger/v1/swagger.yaml`. lowrail-profile sets
  `SPEC_OPTS=--seed 1234`, which the child inherits. The child then orders its examples differently, and the
  tracked file is rewritten (5,963 lines reordered) in every capture (`base`, `aa`, `head`). A plain run with
  `--seed 1234` leaves it clean. Isolated: `RSWAG_GENERATING=1 rake rswag:generate` leaves the file unchanged, and
  with `SPEC_OPTS="--seed 1234"` it rewrites it. README guarantee 1 ("No app changes") does not hold for such suites.
* **T5. A jobs-only report reads as requests.** Huginn's report has an "Objects per request 0.0" column. Its "Top
  lines outside the app" table is headed "Warm: objects per request" for job windows, and compare prints "Objects
  per request (all, by run): base 0.0 / 0.0". The numbers are per job.
* **T6. A missing report.json reads as another version.** `compare base /nonexistent/report.json --aa aa` exits 2
  with "head is not a report.json of this lowrail-profile (no capture metadata)". The exit code is right; the message
  should say the file does not exist. It came up while a capture was still writing.
* **T7. The ledger misses known upstream fixes on top lines.** It reports what its authors track, as the README says,
  but two top lines here had fixes it does not know. rails/rails#58719 (jhawthorn, merged 2026-09-10, not in
  8.1.x) rewrites `broadcast_logger.rb:129`. hashie#613 (merged 2026-10-23, in 5.2.0) fixes Forem's top Hashie line.
  Neither got a ledger cell. Not a bug, but the cell is empty exactly where a team would want "upgrade".
* **T8. Install friction, not tool bugs.** With a `vendor/cache` (Forem), `bundle install` copies the `.gem` there,
  and the team has to commit it. Huginn's Gemfile needs a `.env` before `bundle install` runs at all. Neither is
  lowrail-profile's, but a stranger meets them before the first run.
* **T9. compare flags a serial suite's unchanged head.** Forem runs in one process. Base, A/A and head are
  captures of the same commit, about 30 minutes apart. compare exits 1: `ResponseTemplatesController#update` is
  +126.1 (floor 20.0) and `ModerationsController#article` +57.0. Each head value is the same in both of head's
  windows (15,154.5 and 15,154.3 against 15,028.3 in all four base and A/A windows), so the noise floor cannot
  see it. The app does more work in the later capture. The cause (time, Redis state or data carried between
  captures) is not identified. Receipts: `forem/forem-compare.txt`.
* **T10. A timed-out capture's report.md does not say so.** With `--timeout 30` on Huginn, lowrail-profile stops
  run 1 after 31 s, exits 124, and leaves no processes. compare then exits 2 ("head's command exited [124]"). But
  report.md is written from the partial run and reads like a complete one-run report. Only capture.json has
  `"timed_out":[1]`.

What worked as documented: the install, `require: false` (nothing loaded outside the command), the C counter
compiling once per Ruby into `~/.cache`, exit status passthrough, the Rails 7.2 / Ruby 3.3 / rack 2 floor (Solidus),
ledger cells on Redmine and openstreetmap-website (rails#59605, #59613, #59235, i18n#763–765), and `--out`'s marker.

## Ranked findings

The top 20 lines outside the app, by mean share of request allocations
([rank.md](../../bench/upstream/oss_profile_sweep_1/rank.md); Huginn served no requests):

| # | Line | Mean | Redmine | Solidus | Forem | Dawarich | OSM | Ownership |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | `rqrcode_core/qrcode/qr_util.rb:93` `rszf` | 5.00% | 1.79% | | | 23.19% | | **Unowned → RQ1 built** |
| 2 | `prosopite.rb:419` `subscribe` (`caller_locations`) | 1.65% | | | | | 8.24% | Test-group gem (N+1 detection), not production cost; prosopite#66 and #91 merged on this callback. Not pursued |
| 3 | `cancan/ability.rb:145` `can` | 0.53% | | 1.79% | | | 0.88% | **Unowned → CC1 built** (with #17 and `rule.rb:31/121/133`, `rules.rb:24/28`) |
| 4–5, 15–16 | `rgeo/coord_sys/cs/entities.rb:184–197` `to_wkt` | 0.51% each | | | | 2.56% | 0.01% | No PR in rgeo/rgeo touches it. One app, 3% reach (track creation, demo data). Lead, not built |
| 6 | `action_view/helpers/tag_helper.rb:318` `tag_option` | 0.51% | 0.67% | | 0.20% | 0.65% | 1.03% | Ours: TO1 (held), TE2 (closed), PM2 (closed), K6 (ready) in this area; census-backlog, rails-slots |
| 7, 13 | `core_ext/string/output_safety.rb:242/71` `html_safe` | 0.42%, 0.35% | 0.71% | | 0.19% | 0.41% | 0.80% | One SafeBuffer per call. Ours in the area: TE1 (held), FB1 (draft), K6, RK3 |
| 8 | `active_model/attribute.rb:9` `from_database` | 0.41% | 0.13% | 0.50% | 0.63% | 0.21% | 0.56% | One Attribute per column read. In census 9/10 data; K1 (ready, #59800) is in this area |
| 9, 18 | `relation/where_clause.rb:29/15` `merge`, `+` | 0.41%, 0.33% | 0.53% | 0.89% | 0.17% | 0.12% | 0.32% | In census 10 and activerecord-cpu ranks; MB1 (ready, #59810), A1 (ready, #59851), CW1 (merged, #59642) in the area |
| 10 | `broadcast_logger.rb:129` `#{method}` | 0.37% | 0.47% | 0.74% | 0.51% | 0.13% | 0.03% | **Fixed on Rails main**: rails#58719 (jhawthorn, merged 2026-09-10, not in 8.1.x); not in the ledger (T7) |
| 11 | `arel/table.rb:85` `[]` | 0.37% | 0.58% | 0.67% | 0.26% | 0.16% | 0.18% | One Arel attribute per column reference. In census 9/10 data; no PR found. Not pursued |
| 12 | `postgresql_adapter.rb:864` `get_oid_type` | 0.37% | | | 1.13% | 0.22% | 0.48% | **Ours**: rails#59560, merged 2026-11-03, not released (in the ledger) |
| 14 | `rqrcode_core/qrcode/qr_polynomial.rb:32` `multiply` | 0.35% | 0.11% | | | 1.62% | | Same QR path as #1; not built |
| 17 | `cancan/rule.rb:137` `wrap` | 0.33% | | 1.10% | | | 0.56% | `[object]` for the action and subject is the rule's own state; CC1 trims the two surrounding objects only |
| 19 | `i18n/backend/fallbacks.rb:98` | 0.28% | 0.06% | 0.03% | 0.27% | | 1.06% | **Ours**: ruby-i18n/i18n#763–766 open (the report shows "open upstream work") |
| 20 | `hashie/mash.rb:374` `convert_key` | 0.27% | | | 1.36% | 0.00% | | **Fixed upstream**: hashie#613 (2026-10-23), in 5.2.0 and 6.0.0; Forem locks 5.1.0. Upgrade, nothing to build |

Below the top 20, one unowned line stands out by reach: posthog-rails
`posthog/rails/tracing_headers.rb:77` `normalize_header_name`. It is 1.10% of Dawarich's request objects, with 100%
reach. When a tracing header is absent, `extract_header` walks the whole Rack env and builds an upcased, translated
copy of every key (two Strings per key, about 350 objects per request). No PR in PostHog/posthog-ruby touches the
file since its creation (#144, 2026-05-18; #149 was docs). The fix is small: skip ASCII keys whose length matches
no target before normalizing. It was not built, because posthog-ruby's AGENTS.md requires signed commits on main and
a changeset, and CONTRIBUTING asks for the agent context of each PR. Thomas decides whether that is worth a third
branch.

Built afterwards as [PHR1](../../bench/upstream/pr-queue/items/PHR1.md) (2026-11-25), held: the branch
`thomasklemm/tracing-headers-allocations` @ `a58f8d2022` is not pushed; its commit is kept as
[phr1.patch](../../bench/upstream/oss_profile_sweep_1/phr1.patch). posthog-ruby needs signed PR
commits, not only on main: rulesets on main require signatures and squash merges, and GitHub's docs say unsigned
head commits can block a squash merge. Every fork PR merged since the org ruleset of 2026-08-05 has only verified
commits. 369 → 93 objects per `RequestContext#call` (73 env keys, Rails 8.1), −39.1% instructions without JIT and
−51.1% with YJIT. On Dawarich's request specs the line falls from 341.8 to 28.9 objects per request
([receipts](../../bench/upstream/oss_profile_sweep_1/dawarich/phr1)).

Ownership checks for RQ1 and CC1, in full in the queue items:

* **rqrcode_core:** every PR (48) and issue in whomwah/rqrcode_core. #28 (2021, "Alternative ZFRS to improve memory
  allocation") added `RQRCODE_CORE_ARCH_BITS` instead of changing the default, and the maintainer was unsure about
  64→32 for every user. Since #51 (2026, 2.1.0) the README recommends `ARCH_BITS=32`, and the default is still
  64-bit. `5f6de84`, which introduced the line, is referenced only by #28. RQ1 keeps the default and the env var and
  returns the unmasked shift only where the mask cannot change the result. Not in our queue or the bundled ledger.
* **cancancan:** every open PR (none) and the closed or merged ones on performance and rules: #920/#887 (`can?`
  speed-up), #843/#798 (rule compression), #714 (rules index). None touches `parse_attributes_from_extra_args` or
  `subjects.compact`. The 4.x branch has the same two lines. Not in our queue or the ledger.

## Fork branches

| Item | Repository and branch | Head on base | Checks | Body numbers |
| --- | --- | --- | --- | --- |
| [RQ1](../../bench/upstream/pr-queue/items/RQ1.md) | [thomasklemm/rqrcode_core `thomasklemm/rszf-without-bignums`](https://github.com/thomasklemm/rqrcode_core/tree/thomasklemm/rszf-without-bignums) | `51c099c822` on main `ca75f7a55a` | `rake test` 103 runs, 0 failures with ARCH_BITS 64 and 32. standardrb clean. The new test fails without the masked path. `rszf` equals the old formula on 261,495 / 132,759 cases, and the QR text of 304 strings is identical | [body/RQ1](../../bench/upstream/oss_profile_sweep_1/body/RQ1): objects 45,453 → 6,055 (interpreter and YJIT, A/A identical). Objects only ([objects.sh](../../bench/upstream/oss_profile_sweep_1/objects.sh), upstream-bench's objects worker with the fixed heap), because a 3,000-call Callgrind warm-up at about 35 ms per call takes hours. No instruction or time claim |
| [CC1](../../bench/upstream/pr-queue/items/CC1.md) | [thomasklemm/cancancan `thomasklemm/rule-construction-allocations`](https://github.com/thomasklemm/cancancan/tree/thomasklemm/rule-construction-allocations) | `2a5e8c71d1` on main `021b13cf76` (3.7.1) | `DB=sqlite rspec` 716 examples, 0 failures (Ruby 3.4.13 / AR 8.1, Ruby 3.3.14 / AR 7.2). rubocop clean. 80 rule shapes build identical rules and index on main and branch. Not run: `DB=postgres` | [body/CC1](../../bench/upstream/oss_profile_sweep_1/body/CC1) (`script/upstream-bench`, Ruby 4.0.9): objects 57 → 47; instructions −2.9% without JIT (A/A 0.02%) and −4.4% with YJIT (A/A 0.08%, JIT-flat in 6 windows) |

Both commits are authored and committed by Thomas Klemm `<github@tklemm.eu>` through `script/commit`, with no
trailers (checked with `%(trailers:only)` before the push). No PR was opened. Each item waits for its passes.

## openstreetmap-website serially (for T3's fix)

With `PARALLEL_WORKERS=1` (one process), five captures of the same commit, about 9.5 minutes each with two runs
(s1 565 s, s2 554 s, s3 588 s, s4 578 s, s5 575 s). s5 plants `Array.new(200) { Object.new }` as the first line of
`NotesController#index` ([osm/osm-s5.patch](../../bench/upstream/oss_profile_sweep_1/osm/osm-s5.patch)). Every
run of every capture has the same 2,757 outcomes as plain.

| base / head / A/A | Exit | Rows |
| --- | ---: | --- |
| s1 / s3 / s2, s2 / s3 / s1, s1 / s2 / s3, s2 / s4 / s3, s1 / s4 / s3 | 0 | none |
| s1 / s5 / s2 | 1 | NotesController#index 26,401.9 → 26,570.4 (+168.5, floor 26.57) |
| s3 / s5 / s4 | 1 | the same row (+168.1) |

So the gate the README promises holds for this app serially, on the current gem. The plant adds 201 objects per
call and shows +168 per request. The guess is that some of the 19 index requests stop in a before_action (not
checked). Copies of all nine OSM reports went to the builder's fix thread (T-01a212a2-a3bd-7002-a549-a5dd24a73d25)
as proof for T3's fix.

## Rerun on main c68afc98

The builder fixed T1, T2, T4 and two of its own items (`run*/` deleted after the report unless `--keep-runs`;
`--timeout`). A `gem build` of `gem/lowrail-profile.gemspec` at c68afc98 has sha256
`17b7f302f34b42e968c354c7d70a0dbcb8d2d7baf147a151d862123dd960b295`, the same as the builder's build. It was installed
with `gem install --local` into Ruby 3.3.14, 3.4.13 and 4.0.9. The Gemfile line and lockfile stayed the same
(`0.1.0.rc1`). Receipts are in each app's `r2/`, `t30/` and `t600/` directories and its `*-r2-*` and `*-t*` files.

| App | Capture | Exit | Outcomes against plain | Tree | What it shows |
| --- | --- | ---: | --- | --- | --- |
| Dawarich | `r2`, 1,351 s (run 1 479 s, run 2 796 s) | 0 | suite identical in both runs (4,331 lines). After that comes the nested rswag dry-run's "slowest examples" list, which changes between any two runs | `swagger/v1/swagger.yaml` sha256 `89552bf6…` before and after; `git status` empty. The only difference is ignored `tmp/storage/` files the app writes in every run | T4 fixed |
| Solidus API | `r2`, 187 s (run 1 70.7 s, run 2 87.5 s) | 0 | identical (1,028 lines), both runs | unchanged | T1 fixed: "By gem" has `gem: solidus_core` at 424.6 warm objects per request (top line `permission_sets/base.rb:42` 94.7). Your code lists `app/controllers/...` instead of absolute paths. No "Not attributed" line, because `unclassified` is empty (the line appears only when it is not; Dawarich's reads 0.01 per request, "0.0% of all", in `(erb)`). `r2/` holds only report.md, report.json, capture.json and command.txt |
| Huginn | `t30`: `--timeout 30` | 124 after 31 s | — | unchanged | run 1 stopped; no rspec process left; no run 2. compare exits 2 ("head's command exited [124]"). report.md does not say it timed out (T10) |
| Huginn | `t600`: `--timeout 600`, 130 s | 0 | identical (2,601 lines), both runs | unchanged | `--timeout` without a timeout changes nothing; compare against the earlier base and A/A exits 0 |

Not tool bugs: the first Dawarich attempt failed at load because I left `DATABASE_PASSWORD=postgres` out of the
environment (`dawarich-r2-wrongpw.tail.txt`). The first Solidus attempt failed because I left out
`BUNDLE_WITHOUT=lint:release`. On the failed Dawarich attempt, both runs ran and `run1/` and `run2/` stayed
(no report to build from them).

compare of the new captures against the old gem's base and A/A: Solidus exits 1 with 64 rows, all `solidus_core`
lines going from 0 to their value. That is T1's fix showing, not a regression. Dawarich exits 1 with 23 actions up by
about 0.2% (for example `Achievements::CollectiblesController#show` +1,284 on 511,754) and two error-page lines. That
is the same later-capture drift as Forem's (T9). Neither is an A/A, because the two gems differ.
