# Rails main on Ruby master: framework suites and a new app (2026-11-04)

Rails' Buildkite CI runs Ruby 3.3, 3.4 and 4.0, so breaks that appear on Ruby master show up late. This round ran
every Rails framework suite on Rails main with a fresh Ruby master build, twice, against Ruby 4.0.9 with the same
lockfile, plus a `rails new` app with a scaffold. It refreshes [ruby-4.1-readiness](ruby-4.1-readiness.md) (master
`fef67df224`, Rails `9b116f1fed`, this morning) and adds PostgreSQL, a second run on each Ruby and the generated
app.

**Result.** No new break. Every failure that happens only on master, and in both master runs, is one we already
know: three Ruby-side Ractor bugs or rule changes that are reported upstream, and two Rails Ractor tests that rely on
behaviour Ruby now forbids, both reported on rails/rails. Nothing gets a Rails branch in this round (reasons
[below](#why-no-rails-branch)). There is one new warning, from the irb version Rails locks. The generated app
behaves the same on both Rubies. Of the three problems found earlier today, the strscan one and the
`bundle exec ruby -rGEM` one still reproduce on this build. The second one also hits default gems: in Rails' own
checkout, `bundle exec ruby -rjson` fails on master.

## Pins and method

* **Ruby master:** `5888302d4f` (`ruby 4.1.0dev (2026-11-04T15:37:16Z master 5888302d4f) +PRISM [x86_64-linux]`),
  11 commits after `fef67df224`. Built with `--enable-yjit --enable-zjit --disable-install-doc --enable-shared`,
  GCC 12.2.0, into `~/rubies/master`. Default gems include strscan 3.1.9.dev, json 3.1.0 and bundler 4.1.0.beta3.
* **Control:** Ruby 4.0.9 (`3e93b23afc`, mise).
* **Rails:** main [`088a9ad445`](https://github.com/rails/rails/commit/088a9ad445105e705e972e899b85463b96d11109)
  (2026-11-04), one worktree per Ruby. The committed `Gemfile.lock` was installed with `BUNDLE_FROZEN=true` on both
  Rubies; both run Bundler 4.0.12 (from `BUNDLED WITH`), and neither worktree's lockfile changed.
* **Suites:** activesupport, activemodel, activerecord (sqlite3, and PostgreSQL 15.19), actionpack, actionview,
  actionmailer, actionmailbox, activejob (inline, async, test), actioncable, activestorage, actiontext, railties.
  Each Ruby has its own PostgreSQL, Redis and memcached, so the two Rubies ran at the same time. Seed 4242.
* **Runs:** two full passes per Ruby (`ma`, `mb` on master; `c409a`, `c409b` on 4.0.9). A failure counts only if it
  is missing from the 4.0.9 runs and present in both master runs.
* **Extra passes:** actionpack and actionview again with `--exclude=/[Rr]actor/`, because the Ractor `[BUG]` below
  aborts or hangs the full task on master and so hides the rest of the suite. The 60 Ractor tests of those two
  frameworks also ran one per process on master. Nine railties files ran again after the generated-app gems were
  installed into each Ruby's system gem directory (see [Environment](#environment)).
* **Scripts:** [fixtures/corpus/ruby-master-rails](../../fixtures/corpus/ruby-master-rails): `run.sh` and `lane.sh`
  for the suites (with a stall watchdog), `files.sh` for single railties files, `compare.rb` for per-test and
  per-warning comparison, `ractor_names.sh` and `ractor_each.sh` for the isolated Ractor pass
  ([results](../../fixtures/corpus/ruby-master-rails/ractor-isolated-master.tsv)), `app.sh` for the generated app.

## Results

Tests, failures, errors and skips per component. 4.0.9 is the second control run; the first agrees apart from
environment fixes made between the two (sqlite3 CLI, poppler, `yarn install`).

| Component | 4.0.9 | master A | master B |
| --- | --- | --- | --- |
| activesupport | 6895 / 0 / 0 / 60 | 6895 / 0 / **1** / 60 | 6895 / 0 / **1** / 60 |
| activemodel | 1250 / 0 / 0 / 0 | 1253 / 0 / **1** / 0 | 1253 / 0 / **1** / 0 |
| activerecord sqlite3 | 10284 / 0 / 0 / 52 | 10284 / 0 / 4 / 52 ¹ | 10284 / 0 / 0 / 52 |
| activerecord PostgreSQL | 11205 / 0 / 4 / 31 ² | 11205 / 0 / 4 / 31 ² | 11205 / 0 / 4 / 31 ² |
| actionpack | 4518 / 0 / 0 / 0 | `[BUG]`, hang ³ | `[BUG]`, hang ³ |
| actionpack without Ractor tests | 4490 / 0 / 0 / 0 | 4490 / 0 / 0 / 0 | 4490 / 0 / 0 / 0 |
| actionview | 3379 / 0 / 0 / 0 | 2951 / 0 / **4** / 0, then `[BUG]` ³ | 2951 / 0 / **4** / 0, then `[BUG]` ³ |
| actionview without Ractor tests | 3347 / 0 / 0 / 0 | 3347 / 0 / 0 / 0 | 3347 / 0 / 0 / 0 |
| actionmailer | 286 / 0 / 0 / 0 | same | same |
| actionmailbox | 125 / 0 / 0 / 0 | same | same |
| activejob | 1025 / 0 / 0 / 0 | same | same |
| actioncable | 275 / 0 / 0 / 0 | same | same |
| activestorage | 713 / 0 / 0 / 78 | same | same |
| actiontext | 373 / 0 / 0 / 0 | same | same |
| railties | 2801 / 17 / 32 / 0 ⁴ | same tests | same tests |
| railties, 9 files rerun with system gems | 435 / 3 / 7 / 0 ⁴ | same tests | same tests |

¹ Run A on master started before the sqlite3 CLI was installed; the same 4 structure dump tests failed in control
run A. ² `ForeignTableTest` can't reach its `postgres_fdw` server in this setup, on both Rubies. ³ Ractor `[BUG]`,
row R2 below. activemodel runs 3 more tests on master because three tests are guarded by `RUBY_VERSION >= "4.1"`. ⁴ The
same tests fail on both Rubies, from the environment or Rails' lockfile (row E below).

### Failures only on master, stable in both runs

All are already reported upstream; none is new in this round.

| # | Test | Failure | Class | Cause | Upstream |
| --- | --- | --- | --- | --- | --- |
| R1 | activesupport `NotificationSubscriptionTest#test_record_and_set_subscriptions_when_using_a_regexp` | `Ractor::Error: can not copy ActiveSupport::Notifications::Fanout::Registry object` | (b) Ruby bug | `Ractor.make_shareable(copy: true)` rejects the graph since per-Ractor GC (GH-18194) | Bug #22267, open |
| R2 | actionpack `ControllerInstanceTests#test_action_methods_is_ractor_safe_by_default`; actionview `ObjectRenderingRactorTest`, `DigestorRactorTest`, `LookupContextRactorTest` | `[BUG] rb_objspace_reachable_objects_from_local: set is owned by another Ractor`. The actionpack task then waits forever for the dead worker. | (b) Ruby bug | `f0439cdfa7` | Bug #22419, open; fix ruby/ruby#19283, open. The hang: rails/rails#59037, open |
| R3 | actionview `FileSystemResolverRactorTest#test_non-strict_templates_compile_inside_a_non-main_Ractor` | `Ractor::IsolationError: can not modify FileSystemResolverRactorTest::FakeView because it is created by another Ractor` | (a) deliberate Ruby change | Feature #22226: only the Ractor that created a class may modify it. A non-main Ractor compiles a template method into a view class the main Ractor created. | rails/rails#58736 (issue by yahonda), open, no PR |
| R4 | activemodel `NamingUsingRelativeModelNameTest#test_accessible_from_a_ractor` | `Ractor::RemoteError`: the test stubs `I18n` inside a Ractor | (a) deliberate Ruby change | Same rule; `I18n::Config` also fails in a non-main Ractor | rails/rails#58974 (I18n in non-main Ractors), open |

Which R2 tests crash varies between runs. Run one per process on master, 56 of the 60 Action Pack and Action
View Ractor tests pass, `test_action_methods_is_ractor_safe_by_default` and `ObjectRenderingRactorTest` crash
with the `[BUG]` every time (6 of 6), `FileSystemResolverRactorTest` fails as in R3, and
`DateHelperRactorTest#test_select_datetime_renders_inside_a_non-main_Ractor` crashed once and then passed 12 of 12
reruns. With every Ractor test excluded, actionpack and actionview are identical on both Rubies.

### Why no Rails branch

R3 and R4 are class (a), but neither is a small fix. R3's test comment already expects this ("This might stop
working with https://bugs.ruby-lang.org/issues/22226, which would require compiling into a Ractor-local container
instead"). Fixing it means changing where frozen non-strict templates are compiled in a Ractor, which is part of
the Ractor work Étienne Barrié is doing in Action View (`285464aaca`, `2649a10da7`). R4 waits on #58974. Both are
design work that the maintainers own, so I didn't build anything. Making R3's test pass by defining the view
class inside the Ractor would hide the real limitation, not fix it.

### New warning only on master

| Warning | Where | Class | Fixed in |
| --- | --- | --- | --- |
| `irb-1.15.2/lib/irb/ext/loader.rb:16: warning: the fallback to Object for alias of 'load' in module 'IRB::IrbLoader' is deprecated and will be removed in Ruby 4.3` (and `'require'` on line 17) | railties, whenever IRB loads; Rails' lockfile has irb 1.15.2 | (c) gem in the bundle, against a deliberate Ruby deprecation (NEWS: alias fallback to Object) | ruby/irb#1256 (merged 2026-09-24), which no release has yet: 1.18.0 is from 2026-04-22 and still warns ([readiness](ruby-4.1-readiness.md#new-warnings-only-on-master)) |

No other warning line is new on master, in any suite.

### Environment

**E (railties, both Rubies, 49 tests in the full run, 10 after the rerun):** the app generator tests run
`bin/rails` under `Bundler.with_unbundled_env`, so the generated app looks for importmap-rails and friends in the
system gem directory, as in Rails' CI image. After installing the generated app's bundle into each Ruby's system gem
directory, the nine affected files ran again on each Ruby, twice: 39 of the 49 tests now pass on both Rubies. The
other 10 fail the same way on both: two console colour tests (no TTY), a server started on port 3000, two command
tests, one app update with a hyphenated app name, and 4 `SprocketsAssetsTest` tests. The sprockets ones come from
Rails main's lockfile: json 3.0.1 no longer accepts the `create_additions` option that sprockets 4.2.1 passes, and
sprockets 4.3.0 fixed compatibility with json 3. That is the same on 4.0.9, so it doesn't count here, but it means
Rails main's railties suite has 4 failures with its own lockfile wherever sprockets' manifest code runs.

Setup this needed, in case another orb repeats it: an `en_US.UTF-8` locale for PostgreSQL's `createdb
--lc-collate`, the `sqlite3` and `pdftoppm` binaries, `yarn install` in each worktree, and Redis and memcached.

Harness slip: I edited `run.sh` while both Rubies were executing it, so bash read the new file part-way through a
run. That garbled control run A's railties log and master run A's (already hung) actionpack run. Control A's
railties ran again afterwards; the noted results above come from intact logs only.

## Generated app

`rails new --dev` from each worktree, then `bin/rails g scaffold Post title:string body:text published:boolean`,
`db:migrate`, `bin/rails test`, `test:system`, production `assets:precompile`, `db:prepare`, `eager_load!` and
`Post.count`, `zeitwerk:check`, and a booted Puma: `GET /up`, `/posts`, `/posts/new`, `POST /posts` with the
form's CSRF token, and the digested stylesheet. Done twice per Ruby from fresh apps
([app.sh](../../fixtures/corpus/ruby-master-rails/app.sh)).

* Both Rubies, both times: generator exit 0, 7 runs / 11 assertions / 0 failures, 0 system tests (the scaffold
  generates none), precompile exit 0, zeitwerk "All is good!", and 200 / 200 / 200 / 302 / 200 from the server.
  Production `eager_load!` and `Post.count` (0) are fine in the second pass; the first pass's script didn't prepare
  the production database, which failed the same way on both Rubies. No warning with `RUBYOPT=-W` on
  `bin/rails test`.
* Production eager loading with `BUNDLE_WITHOUT=development:test` works on master too: prism reaches the
  production bundle through railties → irb 1.18 → prism, so a default app does not hit rails/rails#59611's
  `LoadError`. It still matters for apps that lock an older irb.
* Lockfile differences come from Ruby and Bundler, not Rails: on master, Bundler 4.1.0.beta3 locks nokogiri,
  sqlite3, ffi and herb as `ruby` platform source gems (with mini_portile2), because their precompiled gems don't
  cover 4.1 yet, so `bundle install` compiles them. It locks erb 6.1.0 (the default gem) instead of 6.0.7. Expect
  the precompiled gems to cover 4.1 once these gems release for it.

## The three problems found earlier today, on this build

* **prism (rails/rails#59611):** not visible in these suites, because Rails' own Gemfile has prism and the generated
  app gets it through irb (above).
* **strscan 3.1.9.dev and `Journey::Parser`** ([repro](actionpack-request-path.md)): unchanged on `5888302d4f`;
  `skip(/./)` at a misaligned position still returns nil in Shift_JIS and UTF-16LE, where 4.0.9 raises.
* **`bundle exec ruby -rGEM`** ([Ruby 1](ruby-4.1-readiness.md#ruby-1-bundle-exec-ruby--rgem-ignores-the-lockfile)):
  unchanged, and it also hits default gems, with no other copy installed. A Gemfile with only `gem "json",
  "3.0.1"`, an empty `GEM_HOME` and `GEM_PATH`: `bundle exec ruby -rjson -e 'puts JSON::VERSION'` prints `3.0.1` on
  4.0.9 and raises `Gem::LoadError: You have already activated json 3.1.0, but your Gemfile requires json 3.0.1` on
  master ([repro](../../fixtures/corpus/ruby-master-rails/bundle_exec_dash_r_default_gem.sh)). Rails main locks json
  3.0.1, so `bundle exec ruby -rjson …` fails in Rails' own checkout on master. This is a stronger argument for the
  issue than the rainbow example: every project that locks a default gem at a version other than the one Ruby
  ships is affected. Not filed; Thomas decides.
