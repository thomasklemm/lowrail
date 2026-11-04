# Ruby 4.1 readiness: Rails and the census gems on master (2026-11-04)

Ruby 4.1 ships on 2026-12-25. This page records what still breaks in Rails and the gems the census apps load most
when they run on Ruby master, with and without `--zjit`, against Ruby 4.0.9 as the control. It builds on
[gems-on-master](gems-on-master.md) and the [ecosystem sweep](ruby-4.1-ecosystem.md) and does not repeat what they
already found and fixed (C-extension API removals, Bundler `---` config, `SEPARATOR_PAT`, cbor, commonmarker,
temporalio).

**Result.** Seven breaks happen only on master. Two are Ractor regressions in Ruby that are already reported, and
one is a Rails test that relies on behaviour Ruby now forbids. Three are new:

* **Rails:** prism is a bundled gem in 4.1, and Rails main requires it without declaring it. There is a Rails
  fix for this (+4 lines), opened as rails/rails#59611 on 2026-11-04.
* **Ruby:** `bundle exec ruby -rGEM` loads the globally installed version of GEM instead of the locked one.
* **Ruby:** the default net-http 0.10.0 breaks every HTTP response read when an app locks net-protocol 0.2.2.

The json 3 break in Active Support 8.0 is fixed on `8-0-stable`, but no release has the fix. Nothing fails only
with ZJIT. Only R1 is opened (rails/rails#59611); the Ruby-side findings are not filed.

## Pins and method

* **Ruby master:** `fef67df224`, `ruby 4.1.0dev (2026-11-04T09:55:16Z master fef67df224) +PRISM`, built with YJIT
  and ZJIT into `~/rubies/master`. Every suite ran twice on it: once plain and once with `RUBYOPT=--zjit`.
* **Control:** Ruby 4.0.9 (`3e93b23afc`).
* **Rails:** main `9b116f1fed`, one worktree per Ruby so runs don't share `tmp/` or databases. Suites:
  activesupport, activemodel, activerecord (sqlite3 and sqlite3-ractor), actionpack, actionview, actionmailer,
  actionmailbox, activejob, actioncable, activestorage, actiontext, railties. Redis and memcached ran as one
  service per Ruby.
* **Gems:** each gem's own suite at its latest release tag, with its own lockfile: rack, i18n, concurrent-ruby,
  nokogiri, tzinfo, mail, zeitwerk, globalid, json, bootsnap, puma, sprockets, propshaft, importmap-rails,
  turbo-rails, sqlite3, pg, trilogy.
* **Comparison:** per test, by name, plus every warning line, between the three runs. A failure or warning counts
  only if it is missing from the 4.0.9 run.
* **Scripts and repros:** [fixtures/corpus/ruby-41-readiness](../../fixtures/corpus/ruby-41-readiness): `run.sh`,
  `all.sh` and `one.sh` for Rails, `gems.sh` for the gems, `compare.rb` for the comparison, and `repro/`.

## Breakages that happen only on master

| Component | Failure | Cause | Upstream status | Our proposed action |
| --- | --- | --- | --- | --- |
| Action View, Railties (Rails main) | `LoadError: cannot load such file -- prism` from `ActionView.eager_load!`, template digests (`RenderParser`, the default `:ruby` render tracker since `load_defaults "8.1"`), the test runner and `bin/rails notes`, in an app that doesn't otherwise get prism into its bundle ([Gemfile](../../fixtures/corpus/ruby-41-readiness/repro/prism-app.Gemfile)) | **Rails bug.** prism became a bundled gem (Feature #22379, `a1efb9ae6b`), and #56631 removed Rails main's Ripper fallbacks because Ruby 3.3 ships prism as a default gem; Rails main requires it without declaring it. On Ruby 3.3–4.0 the default gem supplies it; on master only another gem in the bundle does (minitest 6, irb ≥ 1.17, rdoc, rbs or rubocop-ast). 8.1 keeps Ripper fallbacks for these parsing paths (8.1.4's `Template#spot` still has a conditional `require "prism"`). | No issue or PR found (searched "prism dependency", "prism bundled gem", "cannot load such file -- prism"). | **R1, opened as rails/rails#59611**: `s.add_dependency "prism"` in both gemspecs ([below](#r1-declare-prism-as-a-dependency)). |
| Ruby (gem_prelude), seen in nokogiri | `bundle exec ruby -rGEM` activates the globally installed GEM rather than the locked version; with an older version locked it raises `Gem::LoadError: You have already activated …`. nokogiri's 4 `TestVersionInfo` errors on master come from this. | **Ruby regression.** `c3c0e280d0` and `cadf8e79a6` (Feature #21951): `gem_prelude.rb` no longer sets Bundler up early when error_highlight and friends are autoloaded, and command-line `-r` runs before RUBYOPT's `-rbundler/setup`. That loses Feature #19089's behaviour. | ruby/ruby#18400 changed the test spec instead of the behaviour. No issue found. | Repro and paragraph for Thomas ([below](#ruby-1-bundle-exec-ruby--rgem-ignores-the-lockfile)). Don't file without his OK. |
| Ruby (default net-http), seen in importmap-rails | `NameError: uninitialized constant Net::ReadLimitExceeded` in `Net::HTTPResponse.read_line` on **every** HTTP response, when the lockfile has net-protocol 0.2.2 and doesn't lock net-http. In the census, Fizzy and Writebook lock exactly that. | **Ruby regression (default gem dependency).** Master's default net-http 0.10.0 calls `readuntil(…, limit:)` and rescues `Net::ReadLimitExceeded`, both new in net-protocol 0.3.0. Its gemspec does declare `net-protocol >= 0.3.0`, but Bundler doesn't resolve default gems the Gemfile doesn't mention, so the locked 0.2.2 wins. 0.2.2's `readuntil` raises ArgumentError on `limit:`, and the `rescue` clause then raises the NameError. On 4.0.9 the default net-http 0.9.1 works with 0.2.2. | No issue or PR found in ruby/net-http, ruby/net-protocol or ruby/ruby. | Repro and paragraph for Thomas ([below](#ruby-2-default-net-http-0100-and-a-locked-net-protocol-022)). For apps: `bundle update net-protocol`. |
| Active Support (all versions with Regexp subscribers) | `ActiveSupport::Notifications` with a Regexp subscriber: `Ractor.make_shareable(…, copy: true)` raises when the object graph holds a shareable Proc next to a Set or Time. | **Ruby regression.** Bisected to GH-18194 (per-Ractor GC): native copy rejects T_DATA, and `dea2cdac` removed the Marshal fallback. | Bug #22267, open (reported by yahonda). | Watch. [Repro](../../fixtures/corpus/ruby-41-readiness/repro/ractor_copy_shareable_proc.rb). |
| Action Pack, Action View (master and ZJIT) | `[BUG] rb_objspace_reachable_objects_from_local: set is owned by another Ractor`; the parallel run then hangs. Rails nightly on Buildkite has timed out the actionpack and actionview jobs on main every day since about 2026-10-12. | **Ruby regression** from `f0439cdfa7`. | Bug #22419, open; fix in ruby/ruby#19283 (open since 2026-10-14). rails/rails#59037 open for the hang. | Watch; re-run actionpack/actionview once #19283 merges. [Repro](../../fixtures/corpus/ruby-41-readiness/repro/ractor_frozen_set_ivar.rb). |
| Action View `FileSystemResolverRactorTest` | Fails on master (class ownership in Ractors, Feature #22226). The other Action View Ractor tests crash with the `[BUG]` above. | **Rails test vs. new Ruby rule** (class ownership). | rails/rails#58736 open. | Watch. |
| Active Model `NamingUsingRelativeModelNameTest#test_accessible_from_a_ractor` (master and ZJIT) | Fails: the test calls `I18n.stub` inside a Ractor. | **Test relies on behaviour Ruby now forbids**: master raises when a Ractor modifies a class another Ractor created (`3f2e84dd`, 2026-09-10). Even without the stub, `I18n::Config` class variables fail in a non-main Ractor. The test was enabled for 4.1 on 2026-09-18 (`8d3c0f0403`). Rails nightly fails on the same test. | No report for this test; rails/rails#58974 is open for I18n in non-main Ractors, which it depends on. | Watch #58974. The test can't pass until I18n works in Ractors; no candidate from us. |

## Breaks in released versions or old lockfiles

These fail on master but are fixed on Rails main or in a newer gem release. They matter on day one because many
apps won't upgrade first.

| Component | Failure | Cause | Upstream status | Our proposed action |
| --- | --- | --- | --- | --- |
| Active Support 7.0 – 8.0.5.2, 8.1.0 – 8.1.3.1 | `ArgumentError` from json on `to_json`/`JSON.generate` calls with options. globalid's suite gets 34 errors on master because it locks Active Support 8.0.3. | json 3.1.0 is the default gem on 4.1 and rejects unknown options: 7.0–8.0 pass `quirks_mode`, and 8.1.0–8.1.3.1 pass options positionally. Active Support 8.0 doesn't depend on json, so apps get the default 3.1.0. [Repro](../../fixtures/corpus/ruby-41-readiness/repro/activesupport_json3.rb). | Fixed on main (#58601), in 8.1.4 and 7.2.4, and on `8-0-stable` (`2786de26c6`), but no 8.0 release has it; 8.0.5.2 is still broken. Rails 8.0 gets security fixes only until 2026-11-07. | Record it. Apps on 8.0 should upgrade, or pin `json < 3`. Pinning json 2.21.2 makes globalid's suite pass. |
| propshaft (its lockfile) | `LoadError: cannot load such file -- tsort` | Locks railties 8.0.2, which doesn't declare the tsort dependency; tsort became a bundled gem. With railties 8.1.4.1: 151/151 pass. | Fixed in railties ≥ 8.0.3 / 8.1. | None; lockfile only. |
| importmap-rails (its lockfile) | byebug 12 doesn't install on master; with byebug 13 the suite hits the net-http break above. | byebug 12's C extension uses removed API (known). | byebug 13 released. | None beyond the net-http row. |
| Old Bundler | `Pathname::SEPARATOR_PAT` | Known, [ecosystem sweep](ruby-4.1-ecosystem.md#2-pathnameseparator_pat-bundler--4011). | Fixed in Bundler 4.0.12. | None. |

## New warnings only on master

| Component | Warning | Cause | Upstream status | Our proposed action |
| --- | --- | --- | --- | --- |
| Active Model 8.0.5.2 and 7.2.4 | "the fallback to Object for alias … is deprecated", from `alias :read_attribute_for_validation :send` and the `respond_to?`/`send` aliases. | Ruby `1c0b1be0` deprecates aliasing a method that a module only gets from Object. | Rails main and 8.1 are clean. | Record it. Only a warning; fixed by upgrading to 8.1. |
| irb 1.18.0 | Same alias warning. | Same. | Fixed on irb master (ruby/irb#1256), which Ruby master bundles. | None. |
| Active Support 7.2, 8.0 | `method redefined; discarding old rfc3339` | Master's `time.rb` now defines `Time.rfc3339` (line 658), which these versions also define in `core_ext/time/calculations.rb:69`. | Main is clean. | None. |
| sass 3.7.4 (sprockets suite), puma test helpers | `literal string will be frozen`, `method redefined` | The compare script flagged these, but they appear the same number of times on 4.0.9 (3,630 each for sass); the "new" lines are dot-progress interleaving. | — | None; not a 4.1 change. |

URI RFC3986 and CGI deprecation warnings also show on 4.0.9 with `-w`, so they are not 4.1 findings.

## Same on all three Rubies (no 4.1 issue)

* **Rails:** activerecord (sqlite3 and sqlite3-ractor), actionmailer, actionmailbox, activejob, actioncable,
  activestorage, actiontext. activesupport and activemodel differ only by the rows above. actionpack and
  actionview differ only by the Ractor `[BUG]` and hang.
* **railties:** the only master-only failures are 4 `AppGeneratorTest` app-update tests. The generated app can't
  find turbo-rails or solid_cache in master's global gem directory. This looks like the environment (gems not
  installed for master), but I didn't confirm it by installing them.
* **Gems:** rack, i18n, mail, concurrent-ruby, json, sprockets, bootsnap, sqlite3, zeitwerk (528 tests), tzinfo,
  nokogiri apart from the 4 errors above, propshaft with railties 8.1, globalid with json pinned.
  pg has 10 environment failures in every run, and turbo-rails has 20 errors from the missing browser in every run.
* **puma 8.0.2:** 840 runs on each Ruby (run with `ulimit -n 65536`; at the default 1,024 every Ruby aborts with
  `EMFILE`). `test_certs_not_expired` fails everywhere because the example certificate has expired. On master,
  `test_tls_v1_rejection` and `test_tls_v1_1_rejection` also fail, but that comes from the build: master here links
  the system OpenSSL 3.0.22 and 4.0.9 links OpenSSL 3.5.5. 3.0 rejects with "unexpected eof while reading", which
  the test's regexp doesn't list. Same openssl gem (4.0.2) on both.
* **ZJIT:** no test fails only with `--zjit`, in Rails or in any gem.

## Upstream context

* **Rails CI on Ruby head:** Rails nightly (Buildkite) on main fails activemodel and activesupport on the same
  tests as here: the Ractor I18n test and the Notifications Regexp subscriber (Bug #22267). It also fails railties
  `[rack-head]`, and actionpack and actionview time out (Bug #22419).
* **Already fixed in Rails:** tenderlove's "fix tests on Ruby master" (`34df91481d`) fixed the
  `TR_ESCAPE_SUPPORTED` check for `String#tr` with a Hash. yahonda's `79d818e36a` fixed a comparison-validation
  test. #58601 fixed the json 3 options. Nothing here overlaps with them.

## R1: declare prism as a dependency

* **Change:** add `s.add_dependency "prism"` to `actionview/actionview.gemspec` and `railties/railties.gemspec`,
  plus the two PATH lines in `Gemfile.lock` (+4 lines). Opened as [rails/rails#59611](https://github.com/rails/rails/pull/59611) from
  `thomasklemm:thomasklemm/declare-prism-dependency` @ `4a837183ea`, rebased onto main `1ca7528bac` (first version
  `00339f7e89` on `9b116f1fed`) ([patch](../../fixtures/corpus/ruby-41-readiness/rails-declare-prism-dependency.patch)).
* **Why both gemspecs:** railties gets prism through actionpack → actionview anyway. But railties requires prism
  itself (`test_parser.rb`, `source_annotation_extractor.rb`), and Rails declares each gem's direct requires, as it
  does for tsort and irb in railties.
* **Why no version:** this matches Active Support's unversioned `base64`, `drb`, `bigdecimal` and `json`. (Not
  `cgi`: #55037 removed that dependency; and tsort is declared `>= 0.2`. The first body cited both, wrongly.) Every API Rails calls already
  exists in prism 0.19.0, the version Ruby 3.3 ships. `Template#spot` needs 1.0 and already checks
  `Prism::VERSION`. None of prism 2.0's breaking changes touch these APIs.
* **Why not `Ruby::Prism`:** only `Template#spot` uses it, to match the nodes error_highlight reports. Using it in
  three more files would copy the `defined?(Ruby::Prism)` branch into each of them and tie them to the
  interpreter's node API.
* **Exactness:**
  * On master and 4.0.9, the app from the repro Gemfile resolves prism 2.1.0, and `eager_load!` and the test
    runner work. `bundle lock` on the base reproduces the lockfile change byte for byte.
  * `dependency_tracker_test` passes 59/59 and `test_parser_test` 10/10.
  * RenderParser output is identical under prism 1.9.0 and 2.1.0.
* **Loading, precisely:** `ActionView.eager_load!` always needs prism, because `RenderParser` is eager-autoloaded
  and requires it at the top of the file. The `:ruby` dependency tracker loads it through `RenderParser`. The test
  runner (`test_parser.rb`) and `bin/rails notes` (`source_annotation_extractor.rb`) require it when they run, not
  on every boot.
* **Side effect (notes only, not in the body):** apps on Ruby 3.3–4.0 that don't lock prism yet add it to their
  lockfile on their next update. That doesn't by itself force a compile, because Bundler can use the installed
  default gem; an online resolve may pick a newer release, and prism 2.1 has precompiled platform gems. JRuby and
  TruffleRuby use prism's FFI backend and build libprism only on a source install.
* **Version:** unversioned, like Active Support's `base64`, `drb`, `bigdecimal` and `json`. Sol rates a `>= 0.19.0` floor low severity and
  optional; offer it if a maintainer asks.
* **Review:**
  * Readability gate: L0 (four lines in the existing pattern).
  * Correctness subagent: approve, no blockers.
  * Maintainability subagent: approve with nits about the commit message (why not `Ruby::Prism`, the render
    tracker as the main reason, a `Ref:` line). All three are addressed in the amended commit.
  * No CHANGELOG entry, following the tsort, cgi, json and securerandom precedents.
  * Sol: open after fixes; no defect in the patch, keep both gemspecs. Its points (cite #56631, call #22379 a
    Feature, no "only through other gems" claim, narrow the 8.1 statement, precise loading, no compile claims) are
    in the rewritten commit message and body.
  * Preflight before opening: main refreshed to `1ca7528bac` (no change to the three files), rebased,
    `bundle lock --local` reproduces the lockfile byte for byte, no overlapping PR or issue.
  * Second review after opening (Thomas asked; an Opus subagent and Astra via Codex): both keep the code. The Opus
    subagent reproduced the `LoadError` on master in a scratch app and regenerated the lockfile byte for byte. The
    body was then rewritten (by the coordinating thread, not here); the commit stays `4a837183ea`. Changes: the
    `cgi`/`tsort` precedent replaced by Active Support's unversioned gems; how narrow the gap is (irb ≥ 1.17,
    minitest 6, rdoc 8 and rubocop-ast bring prism in on a fresh resolve, so only lockfiles without any of them
    break; released 8.1 isn't affected); the ticket cited as `a1efb9ae6b` plus ruby-lang #22379 without a
    Bug/Feature label, because NEWS.md says Bug and the tracker says Feature.
* **Follow-up lead (not built):** Rails CI tests only prism 1.9.0, the version in Rails' `Gemfile.lock`, while an
  app without a constraint resolves prism 2.x (2.1.0 on master and 4.0.9 here). We checked `RenderParser` output
  under 1.9.0 and 2.1.0 once by hand; nothing in Rails CI keeps checking 2.x.
* **Upstream search:** nothing covers this. Related but different: #59213 and #59217 (where prism loads), #59034
  (`Ruby::Prism` in `spot`), #59465 and #47442.

### R1 body, current (edited after the second review): Declare Prism dependencies in Action View and Railties

> Ruby master, targeting 4.1, turns prism from a default gem into a bundled gem (ruby/ruby@a1efb9ae6b, [ruby-lang #22379](https://bugs.ruby-lang.org/issues/22379)), so under Bundler `require "prism"` only works when prism is in the bundle. #56631 removed the Ripper fallbacks because Ruby 3.3 ships prism as a default gem, so Action View and Railties now require prism without declaring it.
>
> Most apps get prism indirectly today, since irb >= 1.17, minitest 6, rdoc 8 and rubocop-ast depend on it. An app whose lockfile has none of them, for example one with an older irb locked, gets a `LoadError` on Ruby master from `ActionView.eager_load!` and Ruby-based dependency tracking, and from the test runner and `bin/rails notes` when they run. Released 8.1 still has the Ripper fallback and isn't affected.
>
> This declares `prism` in both gemspecs, since each requires it directly. It is unversioned, as Active Support does for `base64`, `drb`, `bigdecimal` and `json`, so the default gem on Ruby 3.3 to 4.0 keeps satisfying it. `Template#spot` keeps its `Ruby::Prism` handling.

## Ruby-side findings for Thomas

Both are new, minimal and unreported. Filing an issue or a PR needs your OK; nothing is filed.

### Ruby 1: `bundle exec ruby -rGEM` ignores the lockfile

[Repro](../../fixtures/corpus/ruby-41-readiness/repro/bundle_exec_dash_r.sh): with rainbow 2.2.2 locked and 3.1.1
installed globally, `bundle exec ruby -rrainbow -e 'puts Gem.loaded_specs["rainbow"].version'` prints `2.2.2` on
4.0.9. On master it raises `Gem::LoadError: You have already activated rainbow 3.1.1, but your Gemfile requires
rainbow 2.2.2`.

Since Feature #19089 (Ruby 3.3), RubyGems set Bundler up while it loaded, so a gem named with `-r` on the command
line already came from the lockfile. On master, `c3c0e280d0` and `cadf8e79a6` (Feature #21951) made `gem_prelude.rb`
skip that early setup whenever error_highlight, did_you_mean and syntax_suggest are autoloaded, which is the
default; its comment assumes that RUBYOPT's `-rbundler/setup` is early enough. Command-line `-r` then runs before the `-rbundler/setup` that `bundle exec` puts in RUBYOPT, so it
activates the newest installed version. ruby/ruby#18400 adjusted the test spec to the new order instead of keeping
the behaviour. This affects any tool or test that runs `bundle exec ruby -r…` (nokogiri's `TestVersionInfo` is one),
so I think it is worth a ruby/ruby issue that cites #19089 and the two commits.

### Ruby 2: default net-http 0.10.0 and a locked net-protocol 0.2.2

[Repro](../../fixtures/corpus/ruby-41-readiness/repro/net-protocol-022): a Gemfile with only
`gem "net-protocol", "0.2.2"` and a script that does `Net::HTTP.get` against a local TCPServer. On 4.0.9 it prints
`{net_http: "0.9.1", net_protocol: "0.2.2"}` and `"ok"`. On master it prints `{net_http: "0.10.0", net_protocol:
"0.2.2"}` and then raises `uninitialized constant Net::ReadLimitExceeded (NameError)` from `response.rb:164`.

Master's default net-http 0.10.0 reads every status and header line with `sock.readuntil("\n", …, limit:)` and
rescues `Net::ReadLimitExceeded`; both come from net-protocol 0.3.0. Its gemspec declares `net-protocol >= 0.3.0`,
but Bundler only resolves gems the Gemfile or lockfile mentions, so the default net-http loads next to whatever
net-protocol is locked. Many apps lock net-protocol through mail, net-smtp, net-imap or net-pop. Of our 19 census
lockfiles, 5 lock 0.2.2, and 2 of them (Fizzy, Writebook) don't lock net-http either. So every outgoing HTTP
request in those apps fails on 4.1 until they run `bundle update net-protocol`. The narrowest fix is in net-http:
fall back to the old unlimited read when `Net::BufferedIO#readuntil` doesn't take `limit:`. Alternatively, Ruby's
NEWS could tell users to update net-protocol. I'd propose it to ruby/net-http as an issue first.
