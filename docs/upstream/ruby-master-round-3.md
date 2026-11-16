# Ruby master round 3: the census apps' own suites on master (2026-11-16)

Round 3 of the Ruby 4.1 readiness work, functional part only: the census apps' own test suites against Rails main, each
run on Ruby 4.0.9, on Ruby master, and on master with `RUBYOPT=--zjit`, compared per test by name and by warning line.
Round 1 ([ruby-4.1-readiness](ruby-4.1-readiness.md), 2026-11-04) ran Rails' component suites and the census gems'
suites; round 2 ([ruby-master-round-2](ruby-master-round-2.md), 2026-11-14) measured costs. Ruby 4.1 ships on
2026-12-25. Everything ran on a MacBook Air M3 (arm64, macOS 26.7.1), so this page makes no speed claims. Nothing was
posted, filed or pushed outside Lowrail.

**Short answer.** No test fails only on master, with or without ZJIT, in the 9 census apps that ran here (4,666 tests
and examples). The master-only breaks are at install time, in C extensions that use APIs Ruby 4.1 removed (Feature
#21768): **bluecloth 2.2.0** (CodeTriage), with no fixed release, and **rbtrace 0.5.4** (CodeTriage), fixed in 0.5.5.
Master also prints two new deprecation warnings from gems: mocha 3.1.0 and skylight 7.1.1 alias a method that a module
gets only from Object (Bug #22276). Both Ruby-side findings of 2026-11-04 still reproduce on the new master. ruby/net-http#362
is closed: Bundler now warns about the downgrade, but the error remains.

## Pins

* **Ruby master:** [`d2a6a9d9fa`](https://github.com/ruby/ruby/commit/d2a6a9d9fa6365e7657457364c3d6784c636fb3a),
  `ruby 4.1.0dev (2026-11-16T00:27:01Z HEAD d2a6a9d9fa) +ZJIT +PRISM [arm64-darwin25]`, release build
  `--enable-zjit` (`tools/zjit-build.sh` in lowrail-bench, Homebrew openssl@3 via `PKG_CONFIG_PATH`).
* **Control:** Ruby 4.0.9 (`3e93b23afc`, OpenSSL 3.5.5), lowrail-bench `rubies/a`.
* **Rails main:** [`78039119db`](https://github.com/rails/rails/commit/78039119db862ad739d41677a840f3657fb34d93)
  (merge of #59797, 2026-11-15).
* **Apps** (the census pins in `script/corpus`):

| App | Pin | Overlay before the Rails bump |
| --- | --- | --- |
| Campfire | [`af4dd9fd59`](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5) | `campfire-r82.patch` |
| Writebook | [`7478e2c7b1`](https://github.com/basecamp/writebook/commit/7478e2c7b109e688a6fa4745bac123e72b5cef84) | `writebook-r82.patch` |
| Fizzy | [`77eada1c8e`](https://github.com/basecamp/fizzy/commit/77eada1c8ead75c39f7fda5c80f322bcf5a9adb5) | `fizzy-r82.patch`, round 2's [`fizzy-rails-main-uuid.patch`](../../fixtures/corpus/ruby-master-round-2/fizzy-rails-main-uuid.patch) |
| Thinkroom | [`f7865d0122`](https://github.com/kieranklaassen/thinkroom/commit/f7865d012245e8efd7b75206e06488c05d598744) | `inertia-chatwoot-census/thinkroom.patch` |
| react-starter-kit | [`f8081935e9`](https://github.com/inertia-rails/react-starter-kit/commit/f8081935e9bda68f8ef1ec53dc7eed19c819ee68) | `rails-main-census-5/react-starter-kit.patch` |
| Redprints CFP | [`6080fc24fb`](https://github.com/evilmartians/redprints-cfp/commit/6080fc24fbf0015f7e5a5ae932e903731502c65a) | `rails-main-census-5/redprints-cfp.patch` |
| PingCRM | [`22464f822d`](https://github.com/ledermann/pingcrm/commit/22464f822dcf59c4425993dd623780ad44497fda) | `rails-main-census-5/pingcrm.patch` |
| CodeTriage | [`d1868f8634`](https://github.com/codetriage/codetriage/commit/d1868f8634e97a111a7fca49d58cc776d206007e) | `rails-main-census-5/codetriage.patch` |
| Hackatime | [`74deec42b2`](https://github.com/hackclub/hackatime/commit/74deec42b2556f96ee25116e161fc1581bd72f27) | `inertia-chatwoot-census/hackatime.patch` |
| Lobsters (not run) | [`366e211675`](https://github.com/lobsters/lobsters/commit/366e21167521eccd4c10a125cff45142c237275d) | `rails-main-census-5/lobsters.patch` |

## Method

Scripts: [fixtures/corpus/ruby-master-round-3](../../fixtures/corpus/ruby-master-round-3); [`all.sh`](../../fixtures/corpus/ruby-master-round-3/all.sh) has every per-app invocation as it ran.

* **One bundle for all three runs.** [`prep.sh`](../../fixtures/corpus/ruby-master-round-3/prep.sh) resets the
  app to its pin plus the overlay, points the Rails git pin at `78039119db`, drops `ruby file: ".ruby-version"`
  (two Rubies share the lockfile), and locks with 4.0.9. The rest of the lockfile stays put, apart from what Rails
  main forces (rails-html-sanitizer 1.7.2, hence loofah 2.25.3 and nokogiri 1.19.7) and the `ruby` platform:
  nokogiri, sqlite3, herb, ffi and pg have no precompiled 4.1 builds, so master compiles them from source. The bumps
  below apply to every Ruby, so the three runs differ only in the interpreter. Lockfile diffs:
  [`locks.tar.gz`](data/ruby-master-round-3/locks.tar.gz).
* **Runs.** [`run.sh`](../../fixtures/corpus/ruby-master-round-3/run.sh) runs `db:test:prepare`, then
  `rails test -v` (minitest) or `rspec` with JSON output (RSpec), seed 4242, without system or browser tests,
  `RUBYOPT=-W:deprecated`, 4 workers. Hackatime ran with 1 worker (below). PostgreSQL apps use a `r3_`-prefixed
  database per app and Ruby on the local server (Postgres.app 18.6). [`chain.sh`](../../fixtures/corpus/ruby-master-round-3/chain.sh)
  runs one app on all three labels in turn.
* **Comparison.** [`compare.rb`](../../fixtures/corpus/ruby-master-round-3/compare.rb) parses every test's name and
  result (`Class#test = … = .`, or RSpec's per-example JSON) and every `warning:` and deprecation line, normalized
  for paths, addresses and PIDs. A failure counts only if 4.0.9 passes the same test; a warning counts only if 4.0.9
  never prints it. Output: [`compare.txt`](data/ruby-master-round-3/compare.txt).
* **ZJIT is on in the ZJIT runs.** `bin/rails runner` reports `RubyVM::ZJIT.enabled? == true`, and Writebook's model
  tests under `--zjit --zjit-stats` compile 5,957 ISEQs and run 141.9 M instructions in ZJIT code (117 runs pass). The
  forked test workers inherit `RUBYOPT`.

## Results per app

Results on the three Rubies are identical in every app: the same tests, the same results, the same failure messages.

| App | Suite | Tests | 4.0.9 = master = master --zjit | New warnings on master |
| --- | --- | ---: | --- | --- |
| Campfire | `rails test` | 634 | 1 F | mocha |
| Writebook | `rails test` | 310 | 1 F, 1 E | — |
| Fizzy | `rails test` | 1,787 | 1 F, 4 E, 4 skips | mocha |
| Thinkroom | `rails test` | 833 | 2 F, 1 E | — |
| react-starter-kit | `rspec` | 35 | 0 F | — |
| Redprints CFP | `rspec` | 50 | 3 F | — |
| PingCRM | `rails test` | 1 (its other 4 tests are system tests) | 0 F | — |
| CodeTriage | `rails test` (CI's `rake test` directories) | 222 | 6 E | mocha, skylight |
| Hackatime | `rails test`, 1 worker | 794 | 1 F | — |
| Lobsters | — | — | not run on Rails main ([below](#apps-not-run)) | — |

The failures that happen everywhere are the app or environment: `VipsLoaderPolicyTest#test_denies_NIFTI_files_through_niftiload`
(Campfire, Writebook, Fizzy) depends on how Homebrew's libvips 8.18.7 was built; Writebook's `URI::Generic#request_uri`,
Fizzy's `CGI.parse`, CodeTriage's mailer tests and the rest fail the same way on 4.0.9 ([`compare.txt`](data/ruby-master-round-3/compare.txt)
lists each one with its message).

## Breaks that happen only on master

| # | Where | Failure | Cause | Bisect | Existing report | Proposed next step |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | **bluecloth 2.2.0** (CodeTriage's Gemfile) | `bundle install` fails on master: `bluecloth.c:135: error: call to undeclared function 'Data_Wrap_Struct'`, then `OBJ_INFECT`. Builds on 4.0.9. | Ruby 4.1 removed the untyped data API and the taintedness macros (Feature #21768, deliberate, in NEWS) | Not bisected; the error names the removed symbol: [`f84110e601`](https://github.com/ruby/ruby/commit/f84110e601) "Remove old APIs to allocate a data object", [`a26f528b3b`](https://github.com/ruby/ruby/commit/a26f528b3b) (RData), [`a3ac83b7b8`](https://github.com/ruby/ruby/commit/a3ac83b7b8) and [`cd26647f53`](https://github.com/ruby/ruby/commit/cd26647f53) (taintedness), all on master after the 4.0 branch | None found. bluecloth's last release is 2.2.0 (2011-11-01); ged/bluecloth is a mirror and the gem is unmaintained | CodeTriage doesn't reference `BlueCloth` in `app/`, `lib/` or `config/`; removing `gem "bluecloth"` is the app's fix. Add bluecloth to [gems-on-master](gems-on-master.md) as "no fix, unmaintained". |
| 2 | **rbtrace 0.5.4** (CodeTriage) | `bundle install` fails on master: `rbtrace.c:1160: error: incompatible function pointer types passing 'VALUE (VALUE, VALUE)' to parameter of type 'rb_block_call_func_t'`. Builds on 4.0.9. | Ruby 4.1 removed `rb_postponed_job_register_one` (Feature #21768). `extconf.rb`'s `have_func` then misses it, and rbtrace falls back to a `trap("URG")` proc whose callback has the old two-argument prototype, which clang rejects | Not bisected; [`b66b500816`](https://github.com/ruby/ruby/commit/b66b500816) "Remove postponed job APIs deprecated for 2 years" | Fixed in **rbtrace 0.5.5**, which uses `rb_postponed_job_preregister`/`rb_postponed_job_trigger` and `RB_BLOCK_CALL_FUNC_ARGLIST` (diffed the two gems) | None upstream. CodeTriage needs `bundle update rbtrace`. Add it to gems-on-master. |

Repro for both, outside any app: [`gem_builds.sh`](../../fixtures/corpus/ruby-master-round-3/gem_builds.sh)
([output](data/ruby-master-round-3/gem_builds.txt)): `gem install bluecloth -v 2.2.0` and `rbtrace -v 0.5.4` succeed
on 4.0.9 and fail on master; `rbtrace -v 0.5.5` succeeds on both.

**macOS or arm64?** Neither depends on the platform: both come from symbols that are gone from master's headers, so
the Linux build fails the same way. bluecloth fails at an implicit declaration, which clang and GCC 14 treat as an
error by default. rbtrace's fallback path fails at an incompatible function pointer, which is an error in clang
16 and later and in GCC 14 and later. That is the reasoning, not a Linux run; the coordinator can confirm with
`gem_builds.sh` in an orb.

For the suite run, CodeTriage's Gemfile drops bluecloth and locks rbtrace 0.5.5 on all three Rubies.

## New warnings only on master

| Gem | Warning | Cause | Existing report | Proposed next step |
| --- | --- | --- | --- | --- |
| mocha 3.1.0 (Campfire, Fizzy, CodeTriage) | `object_methods.rb:20: warning: the fallback to Object for alias of 'method' in module 'Mocha::ObjectMethods' is deprecated and will be removed in Ruby 4.3` | `alias_method :_method, :method` in a module (Bug #22276; Ruby `1c0b1be0`, already noted for Active Model 8.0 and irb on 11-04) | freerange/mocha#804 (Earlopain, open since 2026-09-21, "under-investigation") removes the alias; mocha main still has it | Watch #804. It is only a warning until 4.3, but every mocha user sees it once per run. |
| skylight 7.1.1 (CodeTriage) | `helpers.rb:202: warning: the fallback to Object for alias of 'singleton_class' in module 'Skylight::Helpers::ClassMethods' is deprecated …` | `alias __sk_singleton_class singleton_class` in `ClassMethods` (Bug #22276) | None found; skylight main still has the line, and 7.2.0.beta (2026-11-04) is the latest release. skylight takes reports by support email | Thomas decides whether to tell skylight; the fix is to define `__sk_singleton_class` as a method. |

## Bumps on every Ruby (known gem breaks, not new)

* Writebook: redcarpet 3.6.0 → 3.6.1 (`Data_Get_Struct`, [gems-on-master](gems-on-master.md)).
* Fizzy: round 2's `uuid_primary_keys.rb` shim for the Rails main recursion (`SystemStackError` in
  `UuidPrimaryKeyDefault#build_schema_context`; it fails the same way on 4.0.9).
* react-starter-kit and Lobsters: rspec-rails 8.0.x → **8.1.0**. On Rails main, 8.0.x fails to load mailer specs
  with `FrozenError: can't modify frozen Hash: {}` on every Ruby (L1 in [app-suites](app-suites.md)). rspec-rails
  8.1.0 is now released and fixes it.
* Lobsters: commonmarker 2.6.3 → 2.10.1 and stackprof → 0.2.28 ([frontier-master](../../fixtures/corpus/frontier-master/README.md)).
* Thinkroom: commonmarker 2.10.0 → 2.10.1; its `.bundle/config` holding only `---` removed.
* Redprints CFP: `force_ruby_platform` for sqlite3, nokogiri, herb and ffi, because bundlebun ships only platform gems,
  so the lockfile can't add the `ruby` platform.
* Thinkroom, react-starter-kit, Redprints CFP and PingCRM: Vite assets built once (`vite build` for the test
  environment), shared by all three runs. Without them, 142 of Thinkroom's tests error on every Ruby.

## Apps not run

* **Lobsters:** blocked on Rails main for every Ruby. Its `before(:suite)` hook fails with `ArgumentError: User has
  no attribute 'prefers_color_scheme' to define a reader for`: Rails main
  [`d74214f745`](https://github.com/rails/rails/commit/d74214f745) ("Delay attribute definition until the schema is
  loaded", part of rails/rails#59141) raises for activerecord-typedstore 1.6.0's store keys. That is a Rails-main and
  gem matter, not Ruby 4.1. Round 2 worked around it for the census only, with
  [`census_typedstore_rails_main.rb`](../../fixtures/corpus/ruby-master-round-2/census_typedstore_rails_main.rb). Lobsters' AGENTS.md
  refuses LLM contributions, so I didn't shim its code for this run.
* **CASA:** needs a Rails-main overlay that doesn't exist yet (its overlay pins Rails 8.1.4), and most of its
  coverage is system specs. Not attempted.
* **Sure, Mastodon, Discourse, Chatwoot, Lago, Loomio, Docuseal:** need Redis and, for several, more services
  (Elasticsearch, memcached); not set up here. Flow can't install on master (temporalio, round 1). Wikino was not
  attempted.

## Non-findings

* **Redprints CFP example names under ZJIT.** One RSpec example's generated description contains a
  `Faker::Lorem.sentence` title, and the ZJIT run's title differed in three runs. It isn't ZJIT. Rerunning in another
  order gives both titles on master and on master with `--zjit`; the title depends on which run came before in the
  same app copy. With a trace hook on Faker's draws loaded, master and ZJIT write identical 2,120-line traces. The example passes everywhere.
* **macOS fork crashes, also on 4.0.9.** PingCRM's forked workers segfaulted in libpq's GSSAPI probe (fixed with
  `PGGSSENCMODE=disable`). Hackatime's aborted on `+[UIFontDescriptor initialize] may have been in progress in another
  thread when fork() was called` and then segfaulted in `_os_log_preferences_refresh`; it ran with 1 worker.
  `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` is set for every run.
* **CodeTriage's `bin/rails test -v` without paths** prints "rails: version unknown" on every Ruby; it ran with its test
  directories listed, as CI's `rake test` does.

## The two Ruby-side findings of 2026-11-04, on `d2a6a9d9fa`

[`earlier.sh`](../../fixtures/corpus/ruby-master-round-3/earlier.sh) reruns round 1's repros
([output](data/ruby-master-round-3/earlier.txt)).

1. **`bundle exec ruby -rGEM` ignores the lockfile: still broken.** With rainbow 2.2.2 locked and 3.1.1 installed,
   4.0.9 prints `2.2.2`, and master raises `Gem::LoadError: You have already activated rainbow 3.1.1, but your Gemfile
   requires rainbow 2.2.2`. `gem_prelude.rb` hasn't changed since `cadf8e7933` and `c3c0e280d0`. Still no report:
   the nearest is Bug #22295 (`ruby -rGEM` under `RUBY_BOX=1`), a different path. Next step unchanged: a ruby/ruby
   issue that cites Feature #19089 and the two commits, if Thomas agrees.
2. **Default net-http 0.10.0 with a locked net-protocol 0.2.2: the error remains, and Bundler now warns.** Master still raises
   `uninitialized constant Net::ReadLimitExceeded (NameError)` from `response.rb:164`. `bundle install` on master
   now prints "Your bundle downgrades the following default gems shipped with ruby 4.1.0.dev: net-protocol 0.2.2
   (default: 0.4.0)", from rhenium's ruby/rubygems#10026 (synced as `9e16f8e19f`). ruby/net-http#362 stays closed as
   completed (hsbt, 2026-11-10), with no further comments. Next step: none upstream; apps run `bundle update
   net-protocol` or add net-http to the Gemfile.

## Limits

* One machine (arm64 macOS). The two install breaks come from header removals, which are platform-independent; no
  test failure needed a Linux check.
* System and browser tests were not run, and Hackatime ran without parallel workers.
* Seed 4242 only, one run per Ruby; Redprints CFP also ran three times per Ruby.
