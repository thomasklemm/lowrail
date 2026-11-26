# Profile hot lines across the census apps (2026-11-26)

`script/profile-hotlines` over a lowrail-profile capture of each census app's own test suite. The cross-app ranking
with its ownership checks is [docs/upstream/profile-hotlines-census-2026-11-26.md](../../../docs/upstream/profile-hotlines-census-2026-11-26.md),
the top lines of each app are in [per-app.md](per-app.md), and the candidates are below.

## Method

* **Apps:** the 20 distinct apps of `script/census`'s `APPS`: 23 configurations, without `fizzy-mysql`,
  `mastodon-nops` and `lago-nops`, which run copies of the same apps. Each app's source is
  `script/corpus APP hl-APP --source-only` at its corpus pin, with `fixtures/corpus/APP.patch` where one exists and
  without script/census's production overlays, because these runs are test suites. The Blog is
  `LOWRAIL_CORPUS_RUBY=4.0.7 script/corpus real-blog-r4 hl-blog`: its entropy policy pins Ruby 4.0.7, and 4.0.9 is
  refused. Each app runs on its own `.ruby-version` (mise binaries) and its own `Gemfile.lock`
  ([locks](locks)). Discourse and Docuseal pin Ruby only in the lock.
* **Gem:** `gem build lowrail-profile.gemspec` from `gem/` at Lowrail main `f9337e06` gave
  `lowrail-profile-0.1.0.rc1.gem` (sha256 `74dc80b1400a2703a38cb1e3a416c836bf1a09fc7058926b0c64c72a22073773`).
  [run.sh](run.sh) installs it with `gem install --local` and adds a `Gemfile.lowrail` with only
  `gem "lowrail-profile", "0.1.0.rc1", group: [:development, :test], require: false`. This is the install path of
  profile_release/2026-11-25. Nothing was published.
* **Per app:** [apps/APP.sh](apps) holds the command, env and test-database preparation. `plain` runs the command
  with the app's own Gemfile, and `profiled` runs `bundle exec lowrail-profile --timeout 5400 --out profiled --
  COMMAND` (two runs). Both use `SEED=1234`, `DISABLE_SPRING=1` and `PARALLEL_WORKERS=1`, one process at a time on a
  2-CPU, 4 GB orb. Services were PostgreSQL 17 (with pgvector), Redis and memcached, all local and throwaway.
* **Outcomes:** [outcomes.rb](outcomes.rb) is profile_release's script, with digits masked too, since RSpec
  documentation lines carry record IDs (CASA). The profiled log must hold plain's outcomes exactly once per run.
* **Ranking:** `BUNDLE_GEMFILE=<any Gemfile> script/profile-hotlines --check 30 --top 40 --not-lead
  'prosopite=…' --not-lead 'bullet=…' --not-lead 'chewy=…' @bench/upstream/profile_hotlines_census/apps.txt`. Bundler's
  lock parser needs some Gemfile to resolve the path gems in Chatwoot's and Discourse's locks.
* **Kept per app:** `profiled/{capture.json,command.txt,report.md,report.json.gz}`, `plain.outcomes`,
  `profiled.outcomes`, `summary.txt` (exit codes, wall times, outcome check) and the last 40 lines of each log.

## Suites, outcomes on and off

18 of 20 apps ran. In every one the per-test outcomes with the profiler matched those without it. CodeTriage's one
difference is a log artifact: its first plain run prints `git clone` output into
`ParseDocsTest#test_Can_parse_yard_docs`'s line, as noted on 2026-11-25. The test passes in all runs.

| App | Ruby, Rails | Command | Tests (plain) | Profiled vs plain | Counted (run 1) | Wall plain / profiled |
| --- | --- | --- | --- | --- | --- | --- |
| blog | 4.0.7, 8.1.4 | `bin/rails test -v` | 21 runs, 0 failures | identical | 12 requests | 2s / 5s |
| campfire | 4.0.7, 8.2.0.alpha | `bin/rails test -v` | 634 runs, 0 failures, 2 skips | identical | 666 requests, 16 jobs, 19 Cable | 37s / 96s |
| casa | 4.0.7, 8.1.4 | `rspec spec/requests` | 935 examples, 0 failures | identical | 975 requests, 42 mails | 55s / 160s |
| chatwoot | 3.4.4, 7.2.3.1 | `rspec spec/controllers/api` | 1,436 examples, 1 failure (both) | identical | 1,468 requests, 13 jobs | 329s / 767s |
| codetriage | 4.0.7, 8.1.4 | `bin/rails test --verbose` | 222 runs, 0 failures | identical but the log artifact | 100 requests, 13 jobs | 7s / 16s |
| discourse | 4.0.7, 8.1.4 | `rspec` list, topics, posts, categories, tags, search request specs | 1,700 examples, 0 failures | identical | 3,021 requests | 212s / 485s |
| fizzy | 4.0.7, 8.1.4 | `bin/rails test test/controllers -v` | 50 runs, 0 failures | identical | 96 requests | 14s / 33s |
| flow | 4.0.9, 8.1.4 | `bin/rails test test/controllers -v` | 452 runs, 0 failures | identical | 181 requests, 2 jobs | 584s / 1210s |
| hackatime | 4.0.6, 8.1.3.1 | `bin/rails test -v` | 794 runs, 0 failures | identical | 666 requests, 91 jobs | 39s / 91s |
| lobsters | 4.0.9, 8.1.3.1 | `rspec` | 927 examples, 0 failures | identical | 815 requests, 18 jobs | 36s / 79s |
| loomio | 4.0.9, 8.1.3.1 | `bin/rails test test/controllers -v` | 1,491 runs, 0 failures, 1 skip | identical | 68 requests, 559 jobs, 53 mails | 192s / 427s |
| mastodon | 4.0.9, 8.1.4 | `rspec spec/requests spec/controllers` | 2,296 examples, 0 failures, 1 pending | identical | 2,032 requests, 75 jobs | 157s / 368s |
| pingcrm | 4.0.7, 8.1.4 | `bin/rails test:all -v` | 26 runs, 25 errors (both) | identical | 73 requests | 23s / 31s |
| react-starter-kit | 4.0.1, 8.1.4 | `rspec`, no system specs | 35 examples, 0 failures | identical | 33 requests | 2s / 4s |
| redprints-cfp | 3.4.3, 8.1.3 | `rspec`, no system specs | 50 examples, 0 failures | identical | 34 requests | 4s / 8s |
| sure | 3.4.9, 8.1.3.1 | `bin/rails test "test/controllers/[a-l]*_test.rb" -v` | 1,140 runs, 0 failures | identical | 2,596 requests | 131s / 462s |
| thinkroom | 3.4.2, 8.1.3.1 | `bin/rails test -v` | 833 runs, 0 failures | identical | 1,061 requests, 9 jobs, 58 Cable | 23s / 70s |
| writebook | 4.0.7, 8.1.4 | `bin/rails test -v` | 119 runs, 0 failures | identical | 150 requests | 24s / 53s |

## Failures and narrowed suites

* **Docuseal: no suite.** `rails_helper` fails to load without the profiler too.
  * After installing `libleptonica6`, the next error is `lib/pdfium.rb`: it needs Docuseal's own pdfium build
    (`FPDF_HasOnlyDSSChanges`).
  * docusealco/pdfium-binaries ships it only for musl and macOS. bblanchon's glibc build lacks the symbol, and
    attaching it raises `FFI::NotFoundError` at boot.
  * Running it needs Alpine, as its Dockerfile does, or a glibc build of that fork.
* **Lago: no suite.** `spec_helper`'s `before(:suite)` cleans the ClickHouse database
  (`DatabaseCleaner[:active_record, db: Clickhouse::BaseRecord]`) and fails with `Failed to open TCP connection to
  clickhouse:8123`, plain and profiled alike. It needs a ClickHouse service, which this orb did not have.
* **PingCRM: counts, but not a passing suite.** Its only request-serving tests are Selenium system tests. 25 of 26
  error in `Capybara.reset_sessions!` with `invalid argument: * is not a valid URL` (Chrome 158), identically on and
  off. The 73 requests counted are what ran before each error.
* **Chatwoot:** one API example fails with and without the profiler (`PATCH /api/v1/accounts/{id}` returns 422).
  The Vite build ran out of Node heap twice, at 2 GB and 3 GB caps, on the 4 GB orb. So `VITE_RUBY_AUTO_BUILD=false`
  and only `spec/controllers/api` (JSON) ran.
* **Sure:** the second, stack-walking profiled run grew to 2.9 GB RSS and was killed by the OOM killer for all of
  `test/controllers` (both runs), for all 112 top-level controller files, and for those with `--runs 1`. The
  `[a-l]*` files (50 files, 1,140 tests) fit.
* **Discourse:**
  * It needs libvips ≥ 8.18, and Debian 13 ships 8.16. vips 8.18.7 was built from the release tarball
    (sha256 `5baaead3…3bf94`) into `/opt/vips818` and put in the system loader for its run only, as in the field
    test.
  * All of `spec/requests` (about 6,400 examples) reached 1.2 GB RSS halfway through the plain run, with 9
    failures by then, so it was stopped. The six core controller spec files ran instead.
* **Builds the suites needed:**
  * Loomio's Vue build needs Node 26 (its `devEngines`). Without it, 42 controller tests error on a missing
    `public/vue/index.html`.
  * Flow's Vite build was needed too: without it, 85 tests error with `can't find entrypoints/admin.css`.
  * Flow's database user defaults to `postgres` (`DB_USERNAME`).
* **Subsets as in the field test:** Fizzy runs controllers only, because the full suite has 7 `Current#reset_all`
  errors without the gem. CASA runs request specs, Mastodon request and controller specs, and Loomio controllers.
  Redprints and the starter kit run without system specs.

## Reading the ranking

The score is a line's share of an app's request objects, averaged over all 18 apps. Most of the top 40 is Rails, and
nearly every row outside Rails is either one app's or already owned. Ownership by row (the record has each check's
facts):

* **Already changed upstream (upgrade):**
  * json `parse` (#1, 12 apps; 21% of Thinkroom's objects, from vite_ruby re-reading its manifest on every lookup
    with auto-build on, so test only) is not in json 3.2.0.
  * sqlite3 `get_metadata` (#19) is gone in 2.10.2.
  * hashie `convert_key` (#36, 5 apps on 5.1.0) returns `Symbol#name` on master.
  * Rails `token_list`, `get_oid_type`, `tag_option`, `build_handle` and `broadcast_logger` have changed on main,
    but no release has them yet.
* **Owned by an open PR:**
  * rack `split_header` (#33, 17 apps) is taken by rack/rack#2520 (record: [RK4](../rk4/README.md)).
  * rack `path` and `clean_path_info` are covered by #2520 and #2302.
  * nokogiri `namespaces` by #2310 (file only).
  * Rails `html_safe`, `cast_result`, `deep_dup`, `expand_from_hash` and others have open PRs on their files; read
    each before counting it.
* **Ours:**
  * tzinfo `new!` (TZ1, TZ2 in that repository), hashie `method_suffix` and `log_collision?` (HM1, HD1),
    rack-mini-profiler `shorten_identifier` (#670), i18n fallbacks (C2, I18N763, I18N764), nokogiri (NOKO3759).
  * Queue items in other repositories were matched only by repository, so check that an item covers the line
    before relying on it.
* **Test-only, not leads:** prosopite and bullet (N+1 detection in test), and chewy `Strategy#debug` (#11, 5.7% of
  Mastodon's objects). chewy's method returns unless `Chewy.logger.debug?`, and the line is `caller.detect`.
* **Unowned and in many apps:**

| Line | Apps | Score | What allocates | Lowrail item |
| --- | ---: | ---: | --- | --- |
| activesupport `ERB::Util.xml_name_escape` `name = name.to_s` ([util.rb:143](https://github.com/rails/rails/blob/c3466ea00d7121798e3aa3144ffdf7174b81d8cb/activesupport/lib/active_support/core_ext/erb/util.rb#L143)) | 16 | 0.22% | a String per Symbol attribute key: `tag_options` escapes every key (main still calls it, `tag_helper.rb:1641`); Sure 1,132 objects per request | none (TO1, held, writes attributes into the tag's string, not the key) |
| activerecord `Arel::Table#[]` (`Attribute.new(table, name)`) | 18 | 0.38% | one Struct per attribute reference; Discourse 1.95% | none; one object per operation, census data |
| activemodel `Attribute.from_database`, AR `Relation#initialize`/`initialize_copy`, predicate builder `references`/`convert_dot_notation_to_hash` | 17–18 | 0.18–0.36% | one object per attribute or relation, by design | none; census data |
| actionpack `NamedRouteCollection#helper_names` | 16 | 0.31% | every route name as a String, from `AbstractController::UrlFor.action_methods`: once per controller class, so the 4–27% reach | none |
| tzinfo `Timestamp.for_time` `time.subsec` | 18 | 0.19% | a Rational per sub-second Time converted | none (TZ1/TZ2 change other methods); inherent to the stored value |
| concurrent-ruby `SafeInitialization#new` (lead) | 17 | 0.08% | the `*args` splat Array per object created | none |

* **Leads outside Rails that the script names:** rails_vite `manifest_path` (#2, React starter kit only;
  `Rails.root.join` on every build check), http_accept_language `sanitize_available_locales` (Discourse and
  Mastodon; no release since 2017), typeid `UUID#string` (Lobsters only, as on 2026-11-25; no release since 2024-04), concurrent-ruby (above),
  and bootsnap `storage_to_output` (Discourse's I18n load, 0.1% reach: one-time).

## Suggested items

1. **activesupport `xml_name_escape` for Symbol keys.** This is the one unowned line that is both broad (16 apps)
   and avoidable. A Symbol's `name` is frozen and allocates nothing, and the escape returns the name it is given
   when it is safe. Check first whether any caller mutates the returned String: the method is public. As a Rails
   change it waits under the rails/rails cap.
2. **concurrent-ruby `SafeInitialization#new`.** Taking `(...)` instead of `(*args, &block)` would save one Array
   per object created, in 17 apps, but only 0.08%. Measure it first: Ruby may already elide the splat with YJIT.
3. **rails_vite `Config#manifest_path`.** Memoizing the default path, as `build_dir` already allows, would take 11.6%
   of the React starter kit's request objects. That covers only the test and development auto-build check, so it is
   one app and not production: weak.

Outcome of 1 and 2 (2026-11-26, [hotline_candidates](../hotline_candidates/README.md)): neither was built. On Rails
main, `append_tag_option` already passes `Symbol#name` to `xml_name_escape` (rails/rails#59117), so item 1 saves
nothing there (XNE1, superseded). Item 2 is far below the bar on a whole request, and on main its six objects per
request (Active Record's async-query session) are built only for async queries (rails/rails#59373) (CRSI1, held).

Not suggested: `helper_names` (once per controller class), `Arel::Table#[]` and the other one-object-per-operation
Rails rows (census data already has them), tzinfo `for_time` (the Rational is the value it stores), and
http_accept_language (dormant since 2017, two apps).
