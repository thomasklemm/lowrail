# Rails 8.2 pre-beta: census suites on 8.1.4.1 and main (casa, chatwoot, discourse, flow, loomio, mastodon, sure)

One slice of the round (the other eleven ran on the coordinator's orb). Rails trees: `r81` = v8.1.4.1
`3f290b759c`, `main` = rails/rails `088fc0cf61`; merge base `8ae3d84277` (2,568 first-parent merges to main).

## Method

* Copies `script/corpus APP hl-APP --source-only`, apps/APP.sh commands and subsets unchanged (Sure `[a-l]*`,
  Discourse's six core request spec files: both kept for comparability, though this orb has 8 CPUs and 15 GB).
* Gem from `gem/` at Lowrail `ca1e6f44`: `lowrail-profile-0.1.0.rc1.gem` sha256
  `88db58eb0b3eb89e46932784805fb647bd6d54ee63f4b0d966cd10a941d87934`.
* `run.sh APP r81|main`, two profiled runs, each as an `amp orb service` unit. Extra prep the 2026-11-26 run did by
  hand: Flow `bin/vite build` (Node 24, yarn via corepack), Loomio `vue/` build (Node 26, npm 11.16.0), Discourse
  libvips 8.18.7 (tarball sha256 `5baaead3…3bf94`) in `/opt/vips818`, put in the system loader only for Discourse's
  runs.
* **m2** (supplementary, not the harness): where main fails to bundle, `m2/run-m2.sh APP m2` is `run.sh` on main
  plus the smallest Gemfile change that lets it resolve and boot (`m2/m2-APP.sed`), so the suite can show what fails
  behind the bundle failure. Gemfile.m2 changes: casa caxlsx at its merged marcel-2 commit `4e01c737` and
  amazing_print 3.0.0; flow `marcel ~> 2.0`; sure lookbook 2.3.17; discourse `activejob` gem plus
  `require "active_job/railtie"` (m2-discourse.application.rb.txt).
* Confirmation reruns without the profiler: `m2/confirm.sh APP TREE FILE...` (the app's command on those files,
  `BUNDLE_GEMFILE=Gemfile.TREE`), results in `APP/confirm/`.
* `compare.rb` tables: [compare-main.md](compare-main.md) (r81 vs main) and [compare-m2.md](compare-m2.md)
  (r81 vs m2). Its per-test counts undercount where deprecation warnings print inside a Minitest outcome line
  (Loomio main: `render_in` without options, #50623's deprecation, 1,070 times; Flow m2: constant warnings); the
  run totals in each `summary.txt` are complete.

## Outcomes

| App | 8.1.4.1 (2 runs) | main (2 runs) | main + m2 adaptation |
| --- | --- | --- | --- |
| casa | 935 examples, 0 failures | bundle fails (marcel) | 935 examples, 0 failures |
| chatwoot | bundle fails | bundle fails | — |
| discourse | 1,700 examples, 0 failures | rails_helper LoadError `active_job` (0 examples) | 1,700 examples, 0 failures |
| flow | 452 runs, 0 failures, 0 errors | bundle fails (marcel) | 452 runs, 409 errors |
| loomio | 1,491 runs, 0 failures, 1 skip | 1,491 runs, 0 failures, 1 skip | — |
| mastodon | 2,296 examples, 7 failures, 1 pending | 2,296 examples, 1,953 failures, 1 pending | — |
| sure | 1,140 runs, 0 failures, 0 errors | bundle fails (marcel) | 1,140 runs, 91 errors |

Not main-only:

* **Chatwoot** locks Rails 7.2.3.1 and cannot resolve on either tree:
  `administrate-field-belongs_to_search >= 0.10.0 depends on rails >= 4.2, < 8.0`. Same as in the boot check.
* **Mastodon's 7 failures on 8.1.4.1** are `Vary` header expectations (`expected nil, got "Accept,
  X-Requested-With"`; webfinger `expected "Origin", got "Accept, X-Requested-With, Origin"`). They come from
  8.1.4.1's security commit 7a955ca367 "Vary rendered responses by negotiation headers" (the hot-lines run, on
  8.1.4, had 0). They fail on main too, there first on group 5.
* Mastodon's first main attempt (`main/summary.first-attempt.txt`): `bundle install --quiet` reported success but
  left pg, nokogiri, ffi, mini_portile2 and google-protobuf uninstalled for the lock, which added the
  `x86_64-linux` platform; a second `bundle install` built them. Environment, not Rails.

## Main-only failures, confirmed

Each group: passes in both r81 runs, fails in both main (or m2) runs, reproduced on main without the profiler and
passing on 8.1.4.1 the same way.

### 1. marcel 2: bundle fails on main (casa, flow, sure)

* Error: `every version of activestorage depends on marcel ~> 2.0` against casa's caxlsx 4.5.0 (`marcel ~> 1.0`),
  Flow's own `gem "marcel", "~> 1.0"`, and Sure's lookbook 2.3.11 (`marcel ~> 1.0`, fixed from 2.3.15).
* Commit: 60fe6c3a7a "Upgrade to Marcel 2 for Active Storage content type detection" (#58549, Jeremy Daer,
  2026-08-28), which bumps `~> 1.0` to `~> 2.0` on purpose.
* Classification: deliberate Rails change; gems and apps adapt.
* Ownership: caxlsx merged "Soften marcel dependency version constraint" (#542, 2026-09-07) but has no release
  after it (latest 4.5.0, 2026-06-09). lookbook #804 is released (2.3.17 allows `>= 1.0`). Flow's pin is its own.
  No queue item.

### 2. amazing_print 2.0.0 calls `ActiveSupport::LogSubscriber.colorize_logging` (casa, behind group 1)

* Error at boot, in `Bundler.require`: `undefined method 'colorize_logging' for class ActiveSupport::LogSubscriber`,
  `amazing_print-2.0.0/lib/amazing_print/ext/active_support.rb:45`, from `config/application.rb:7`
  (`casa/m2-amazing_print-2.0.0/`).
* Commit: 54264bde59 (#55900 "Make framework log subscribers to consume structured events"); aebcb61520 moved the
  setting to `ActiveSupport.colorize_logging` without a class-level reader.
* Classification: deliberate Rails change (no deprecation); the gem adapts.
* Ownership: amazing_print 3.0.0 (2026-09-17, #158) uses `ActiveSupport.try(:colorize_logging) ||
  ActiveSupport::LogSubscriber.try(:colorize_logging)`; casa's lock is still on 2.0.0. Our rails/rails #59628
  (deprecation restore) was closed 2026-11-10. With 3.0.0 all 935 examples pass on main.

### 3. Discourse: `LoadError: cannot load such file -- active_job` loading rails_helper

* Frames: `actionmailer/lib/action_mailer/test_helper.rb:4` (`require "active_job"`) ←
  `action_mailer/railtie.rb:67` (`on_load(:action_dispatch_integration_test) { include ActionMailer::TestHelper }`)
  ← `action_dispatch/testing/integration.rb:749` ← `require "rspec/rails"` at `spec/rails_helper.rb:39`.
  Discourse's Gemfile lists seven Rails components without activejob.
* Commit: ed17c90871 (#59820 "Break hard dependency between Action Mailer and Active Job", byroot, 2026-11-16).
* Classification: Rails bug. The gemspec drops activejob, but the railtie still includes `ActionMailer::TestHelper`
  in every integration test, and that file still requires `active_job` (as do `mail_delivery_job.rb` and
  `ActionMailer.deliver_all_later`). Any app bundling actionmailer without activejob fails to load integration or
  request tests. (Alternative reading: the app adapts by bundling activejob, which the CHANGELOG suggests only for
  standalone `deliver_later`.)
* Ownership: our AM3 (#59987, merged 2026-11-26, in 088fc0cf) removed the `load_defaults` delivery_job that raised
  at boot; it does not cover the test helper. UG82M (#59986, merged) documents the railtie change. No open rails/rails
  issue or PR on the test helper (searched `ActionMailer::TestHelper active job`, `cannot load such file --
  active_job`, cross-references of #59820).
* Behind it (with only the activejob gem added, `discourse/m2-activejob-only` in the run log):
  `uninitialized constant RSpec::Mocks::ArgumentMatchers` at `spec/support/mocks.rb:10`. On 8.1.4.1 the mailer
  railtie loaded `active_job/railtie`, ActiveJob was defined at boot, and rspec-rails then loads its Active Job
  matchers, which pull in rspec-mocks' matchers; on main ActiveJob is not defined after boot. That is the documented
  #59820 change (UG82M) plus the app relying on a transitive require: the app adapts.

### 4. Flow: `scope :default_order` collides with Active Record's new query method

* Error (409 of 452 tests, both runs; confirmed 17 of 21 in `test/controllers/api/v1/terminal_sessions_controller_test.rb`,
  0 on 8.1.4.1): `ArgumentError: You tried to define a scope named "default_order" on the model "CompanyMembership",
  but Active Record already defined a class method with the same name.` at `app/models/company_membership.rb:34`,
  loaded from `test/factories/users.rb:40`.
* Commit: 3e150a707a (#39525 "Add support for default order", Dan Ungureanu, merged 2026-05-28), which adds
  `default_order` to `Querying`'s delegated methods.
* Classification: deliberate Rails change (new public API); the app renames its scope.
* Ownership: no rails/rails issue or PR on the name collision (open default_order PRs #59416 and #37807 are about
  reorder and first/last). No queue item.

### 5. Mastodon: `RemoteIp::GetIp#filter_proxies` removed (1,900 of 1,953 failures)

* Error: `undefined method 'filter_proxies' for an instance of ActionDispatch::RemoteIp::GetIp` at
  `lib/action_dispatch/remote_ip_extensions.rb:64` (Mastodon's prepended `calculate_ip`), from
  `spec/support/signed_request_helpers.rb:5`.
* Commit: 562f0ef2ce (#56805 "Optimize calculating remote IP address", fatkodima, 2026-02-18).
* Classification: app use of private API (`filter_proxies` was private, `# :doc:`).
* Ownership: our R1 (#59630, deprecation restore) closed 2026-11-06 ("Rails doesn't deprecate internal APIs").
  Mastodon main still calls it (file last changed in #41506, 2026-11-04); no Mastodon issue or PR found.

### 6. Mastodon: `PredicateBuilder#build_bind_attribute` takes an attribute now (53 failures)

* Error: `undefined method 'name' for an instance of String` at
  `activerecord/lib/active_record/relation/predicate_builder.rb:129` ←
  `app/models/concerns/status/safe_reblog_insert.rb:64` (`build_bind_attribute(attr.name, attribute.value)`) ←
  its `_insert_record` override, on every reblog insert.
* Commit: 3ba36ddb69 (#58479 "Query predicate expressions for Active Record types, take 2", matthewd, 2026-08-25):
  `build_bind_attribute(column_name, value)` became `build_bind_attribute(attribute, value)`.
* Classification: app use of private API (`PredicateBuilder` is `# :nodoc:`; `_insert_record` too).
* Ownership: our ZM1 (#59663, column-name compatibility) closed ("We don't deprecate internal APIs"). Mastodon main
  still has the call; no Mastodon PR found.
* Confirmed with group 5: `reblogged_by_accounts_spec.rb` and `bookmarks_spec.rb`, 8 of 8 fail on main (4 each),
  0 of 8 on 8.1.4.1.

### 7. Sure: array-form `find_by_sql` now sends bind parameters (91 errors)

* Errors (both m2 runs and plain, 91 of 372 runs in the 10 affected files; 0 on 8.1.4.1):
  * `PG::SyntaxError: syntax error at or near "$1"` for `generate_series(DATE :start_date, DATE :end_date, …)`,
    `app/models/balance/chart_series_builder.rb:108` (`query_data`), reached from accountable sparklines, accounts,
    cash-flow preview, impersonation, insights and loans pages.
  * `PG::UndefinedFunction: operator does not exist: date >= integer` for `inflow_candidates.date - :date_window`,
    `app/models/family/auto_transfer_matchable.rb:53` (`transfer_match_candidates`), reached from accounts, auto
    matches, budget categories and FinanceKit accounts.
  * 4 `InFailedSqlTransaction` errors that follow these in the same test.
* Commit: adf307b03b (#58427 "Use bind parameters for array-form arguments in find_by_sql / count_by_sql", kamipo,
  2026-08-09). Bisecting merges was not possible (Sure's view_component 4.12.0 needs
  `ActionView::Template.template_handler_extensions`, absent at that merge's parents), so main was run with the one
  line of #58427 in `querying.rb` reverted (`sure/confirm/rv58427.diff`): the same 10 files then pass
  (372 runs, 0 errors).
* Classification: deliberate Rails change (CHANGELOG entry) that breaks working SQL on PostgreSQL without a
  deprecation: typed literals (`DATE :d`) and untyped arithmetic (`date - :n`) that interpolation allowed. Apps adapt
  by casting (`CAST(:d AS date)`, `:n::integer`). Borderline Rails regression for 8.2.
* Ownership: our PR59565 (#59565, open, ready) adds a hint to the syntax-error case and names #58427 as the 8.2
  regression; it does not cover `date >= integer`. #59642 (merged) changed bound-literal grouping, unrelated. No
  open issue reporting the break.

## Files

`APP/TREE/{summary.txt, profiled.outcomes, profiled/{capture.json,command.txt,report.md,report.json.gz},
install.tail.txt, profiled.tail.txt}` for TREE r81, main and (casa, discourse, flow, sure) m2; `APP/confirm/`;
`locks/APP.Gemfile.TREE.lock`; `m2/` scripts.
