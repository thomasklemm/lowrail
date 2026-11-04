# Real Rails apps' own suites on rails main vs 8-1-stable (2026-11-04)

Goal: unreleased regressions on main that hit real apps. Rails main `8b06b0eb98` against 8-1-stable `6e09124217`
(both as `path:` gems), Ruby 4.0.9, one app checkout per Rails version. The two bundles differ only in Rails and
the gems Rails main itself requires (herb, marcel 2.1, ractor-dispatch, psych, stringio). Control: 8-1-stable
runs twice. A failure counts only if it shows up on main while 8-1 is stable.

Classes: (a) Rails regression, (b) deliberate Rails change, (c) a gem in the bundle that is incompatible with main,
(d) the app's own use of private API. Known from C16's ecosystem round (`thomasklemm/ecosystem-tests`), not
redone here: E1 WeakSet require, E2 SQLite table-name case, E3 `colorize_logging`, E4 minitest floor, I1
overridden `primary_key` (#59622).

## Summary

| App | Suite | 8-1-stable ×2 | main | Findings |
|---|---|---|---|---|
| Redmine trunk `41cd39c` | `rails test`, 6116 runs, SQLite | clean, clean | boot fails; after workaround 1 F, 3 E | S1 (b), S2 (b) |
| Lobsters `b6ea255` | rspec, 927 examples, SQLite | 0 F, 0 F | every feature spec fails to load; after rspec-rails pin 3 F | L1 (c), L2 (a), fixed by #59625 |
| Solidus `ed00fc8` | core rspec, 4487 examples; api rspec, 684 examples; SQLite | clean ×2 (core and api) | core clean; api 1 F ×2 | SO1 (b) |
| Sure `e658686` | `rails test`, 14313 runs, PostgreSQL 18.6 + Redis | 0 F, 0 F | 13 F, 472 E | SU1 (a), SU2 (b, record only), SU3–SU5 (b/c) |
| Writebook `d57c62b` | `rails test`, 313 runs, plus 3 system tests; SQLite | its lock (main `3a49610`): 4 F ×2 (libvips, environment) | same 4 F ×2; system clean | no main-only failure; WB1 (c, deprecation) |
| Forem `5f0276d` | rspec, 16542 examples, PostgreSQL 15 + Redis | 5 F, 5 F (1 flake each) | boot needs 4 bumps and 3 app shims; then 1690 main-only F | F1 (a), FO1–FO3 (c/d), deprecations (b) |
| Chatwoot `a8364f9` (CE) | rspec, 7632 examples, PostgreSQL 16 + pgvector, Redis | 63 F (port fallout, also on main); failing files twice more: same | 1 gem shim (boot); 148 main-only F, 145 stable | CW1 (a), CW2 (d, restore?), CW3–CW5 (b), SU4, SU5, L1 |
| Private Rails app with Inertia Rails (anonymized) | `rails test`, PostgreSQL 18.6, 8 workers | clean, clean | all main-only failures from one call (PI1); otherwise clean | PI1 (c, our #59574), PI2 (a, lead), PI3 (a, perf, built) |

## Findings

**S1 (b): `Rack::Sendfile` only added when `x_sendfile_header` is configured.** b37aeee32f (#56915, CHANGELOG
entry). Redmine's [`config.middleware.insert_before Rack::Sendfile, Rack::ContentLength`](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/config/application.rb#L79) raises `No such middleware to
insert before: Rack::Sendfile` on boot. Redmine's [`test_download_should_set_sendfile_header`](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/test/integration/attachments_test.rb#L213) stubs
`Rack::Sendfile#variation`, so it fails too. The same removal was made once before (19ac034bdc) and reverted in 2013
(207fa5c11d, #11440). Rack has ignored the `X-Sendfile-Type` request header since 3.2.3 (CVE-2025-61780), so the
only remaining unconfigured trigger is `env["sendfile.type"]`. Code search finds only Discourse and logster setting
it, both to `""` to disable sendfile, which still works. The repro is
[sendfile_type.rb](../../bench/upstream/app_suites/sendfile_type.rb): 8-1 returns an `X-Sendfile` header with an
empty body; main streams the file. The upgrade guide said nothing, so this is a docs-only note:
[patch](../../bench/upstream/app_suites/s1-upgrade-guide-rack-sendfile.patch),
[body](../../bench/upstream/app_suites/s1-body.md). Branch `thomasklemm/upgrade-guide-rack-sendfile` @ `5da102ad62`
on main `8b06b0eb98`; Sol: open with nits, nits applied. Workaround for the rest of the Redmine run (main checkout
only): insert before `ActionDispatch::Static`.

**S2 (b): `link_to`, `button_to` and `current_page?` moved to `NavigationHelper`.** 07f4b45e29 (#55410, CHANGELOG:
"Extract …"), requested by a maintainer, with no deprecation. A class that includes only
`ActionView::Helpers::UrlHelper` loses `link_to`. Redmine's [`Redmine::Hook::ViewListener`](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/lib/redmine/hook/view_listener.rb#L32) does, so 3
[`Redmine::Hook::ManagerTest`](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/test/unit/lib/redmine/hook_test.rb#L46) tests fail with `undefined method 'link_to'`, and so does every plugin hook that builds
links. GitHub code search shows about 2.6k hits for `include ActionView::Helpers::UrlHelper`. Swapping the include
works on main ([check](../../bench/upstream/app_suites/navhelper.rb)), but `NavigationHelper` doesn't exist on 8-1; keeping `UrlHelper` and adding `include NavigationHelper if defined?(…)` works on both ([check](../../bench/upstream/app_suites/navhelper_compat.rb)).
No compat code; docs-only note:
[patch](../../bench/upstream/app_suites/s2-upgrade-guide-navigation-helper.patch),
[body](../../bench/upstream/app_suites/s2-body.md). Branch `thomasklemm/upgrade-guide-navigation-helper` @
`3db35ffc1c` on main `8b06b0eb98`; S1 and S2 merge with each other and with main `fa03095c6f` cleanly.

**L1 (c): rspec-rails 8.0.x mutates the frozen `default_url_options`.** baa1ca5f2f (#58483) freezes the
controller-level `default_url_options` (no CHANGELOG entry). rspec-rails' `FeatureExampleGroup` does
`default_url_options[:host] ||= …`, so every `type: :feature` spec fails to load with `FrozenError`. rspec-rails fixed
this on main in 9fb6f4f0a3 (2026-08-21), but no release has it; the latest is 8.0.4 from March. It needs a release
before Rails 8.2. Both Lobsters bundles were then pinned to that rspec-rails ref (identical, the only extra gem
change).

**L2 (a): positional URL helper argument with an empty `to_param`, with a host default.** Lobsters'
`stories_spec.rb` check_url_dupe json (3 examples) calls `Routes.story_short_id_url(story)` on an unsaved story
(`short_id == ""`), with `default_url_options[:host]` set. On 8-1 this goes through the general path and gives
`http://localhost:3000/s/`. On main it raises `UrlGenerationError`. Bisected to 8e36346c17 (#59479), which keeps the
optimized helpers when only reserved default options such as `:host` apply; the optimized helper rejects empty
arguments. Repro: [empty_param.rb](../../bench/upstream/app_suites/empty_param.rb) (`HOST=example.com`). Already
fixed by our open #59625 (head 2b4a97089a): with it, the repro and Lobsters' `stories_spec.rb` (33/33) pass. No new
patch.

**Deprecations seen on main only (Redmine):** `verify_authenticity_token` skipping,
`config.active_record.raise_on_assign_to_attr_readonly`, `Mime::SET`.

## Solidus

Solidus has no lockfile. Both bundles were resolved from its Gemfile with `rails` replaced by the path gem, and
the 8-1 lock was copied for main. `solidus_core.gemspec` caps Rails at `< 8.2`; both checkouts have it raised to
`< 8.3`. The bundle has rack 2.2.25 and rspec-rails 8.0.4.

**SO1 (b): attachments are analyzed before validation under 8.2 defaults.** Api `images_spec.rb:79` corrupts the blob
key and expects `attachment_width` to be nil; main returns 1. Solidus' dummy app calls
`load_defaults("#{MAJOR}.#{MINOR}")`, so on main it gets `active_storage.analyze = :immediately` (activestorage
CHANGELOG "Analyze attachments before validation"). The metadata is stored at attach time, and the missing file is
never read. Apps on 8.1 defaults are unaffected. L1 didn't apply: core and api have no feature or mailer example
groups.

## Mastodon

`a255155`, PostgreSQL 17 and Redis, flatware. L1 hit the mailer specs as well (rspec-rails 9fb6f4f0a3 also fixes
`MailerExampleGroup`), so both bundles pin that rspec-rails ref. First main run: 2462 failures in 7984 examples.

**R1 (d, documented): `GetIp#filter_proxies` removed without deprecation.** 752cc3915d (#56805, fatkodima, perf)
replaced it with `first_non_proxy`. On 8-1 it was private but marked `# :doc:`. Mastodon's
[`lib/action_dispatch/remote_ip_extensions.rb`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/lib/action_dispatch/remote_ip_extensions.rb#L18) prepends its own `calculate_ip`, which calls
[`filter_proxies([remote_addr] + ips).first`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/lib/action_dispatch/remote_ip_extensions.rb#L57) (shortened); that accounts for 2169 of the failures, in 368 spec files. Fix (Thomas's
decision): restore it as a deprecated private `:doc:` method with 8-1's body (all non-proxy IPs, in order),
warning through `ActionDispatch.deprecator`, to be removed in Rails 9.0, pointing to `first_non_proxy`. The fast
path is untouched. Test: IPv4, IPv6, a Regexp proxy and an all-proxy list against 8-1's results, plus
`assert_deprecated`; it fails on main with `NoMethodError`. A differential script gives identical output on
8-1-stable and on the branch, including an identical `IPAddr::InvalidAddressError` for a non-IP entry.
`request_test.rb` 200 runs green; RuboCop clean. Mastodon with the branch and without the app shim: the 368 files
run 2232 examples, 0 of them `filter_proxies` failures. The 25 that remain also fail either in the shimmed main run
or in the 8-1 run under a shared REDIS_URL.
[patch](../../bench/upstream/app_suites/r1-remote-ip-filter-proxies-deprecation.patch),
[body](../../bench/upstream/app_suites/r1-body.md). Branch `thomasklemm/remote-ip-filter-proxies-deprecation` @
`54e07d2dba` on main `d09361d7cf` (Sol: open with nits, applied: concrete migration in the message, `assert_deprecated(/filter_proxies/, …)`, neutral CHANGELOG, body wording).

**M1 (d): `PredicateBuilder#build_bind_attribute` takes an Arel attribute.** 4f1ff11da3 (CHANGELOG). Mastodon's
[`Status::SafeReblogInsert`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/models/concerns/status/safe_reblog_insert.rb#L64) passes `attr.name`; about 220 failures. `PredicateBuilder` is `:nodoc:`; record only.

To compare the rest, the main checkout carries two app-side shims (pass `attr`; define `filter_proxies` in
Mastodon's extension). Main with shims: 44 failures. The 8-1 controls run one after another on the default
Redis (an earlier 8-1 run with `REDIS_URL` set had 63 environment failures, from redis_configuration_spec and
feed specs).

**Mastodon main-only failures after the shims (44 on main; the second 8-1 control has 8, all of which also fail on
main):** the remaining 36 are all explained.
* 12 (b): `statuses_spec` expects `Vary: Accept, Accept-Language, Cookie` and gets `…, Sec-Fetch-Site`. Main's
  Sec-Fetch-Site CSRF protection appends to `Vary` (f5a1915f1d, 7fcee2255b; CHANGELOG).
* 11 (b, S2): [`REST::NotificationSerializer`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/serializers/rest/notification_serializer.rb#L5) and [`REST::NotificationGroupSerializer`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/serializers/rest/notification_group_serializer.rb#L5) include only
  `ActionView::Helpers::UrlHelper` and call [`link_to`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/serializers/concerns/notification_fallback_concern.rb#L82).
* 9 (c): view specs fail with `FrozenError` on `["", "action_view/test_case/test"]`. fd5ffed45b freezes
  `ViewPaths._prefixes` (for Ractors), and rspec-rails prepends to `lookup_context.prefixes`. Fixed in rspec-rails
  570b2b0a79 (#2915, 2026-09-02), after our pin and unreleased.
* 3 (b): `precision: nil` datetime columns are now cast to microseconds in memory ("Report PostgreSQL default
  timestamp and time precision as 6", CHANGELOG). `user_spec` (2) and `post_status_service_spec` (1) compare
  against a nanosecond `Time`.
* 1 (b): the enum `ArgumentError` now lists the valid values (CHANGELOG).
* Failing on both: webfinger and outboxes `Vary` (the backported "Vary rendered responses by negotiation
  headers", 7a955ca367 on 8-1-stable), the embed `Vary`, and the `strip_tags` HTML-entity check.

No (a) in Mastodon.

## Sure

we-promise/sure `e658686` (Maybe's active fork; maybe-finance/maybe is archived), Ruby 3.4.9, PostgreSQL 18.6 and
Redis, Rails main `8b06b0eb98`. lookbook 2.3.11 pins `marcel ~> 1.0`, which conflicts with main, so both locks were
moved to lookbook 2.3.15 (`bundle lock --conservative --update lookbook`); otherwise the locks differ only in Rails
gems. Both 8-1 controls: 14313 runs, 0 failures. Main: 13 failures, 472 errors, all explained below.

**SU1 (a): anonymous cache store subclasses can't be created.** c6127f884e (#58061, "Fix some FrozenErrors for
ractorized application") moved the `LocalCache` key into `initialize`, built from `self.class.name.underscore`, which
is nil for `Class.new(ActiveSupport::Cache::MemoryStore)`. Sure's
[`TransactionsControllerTest`](https://github.com/we-promise/sure/blob/e658686d5ba7a55734ae9f42683618aa42342b74/test/controllers/transactions_controller_test.rb#L1799) builds such a store
(1 error). On 8-1 the store worked and only `with_local_cache` raised. Repro:
[local_cache_anon.rb](../../bench/upstream/app_suites/local_cache_anon.rb). No issue or PR found. Fix: `name.to_s`,
test in `memory_store_test.rb` that fails on main; Active Support cache tests (without Redis/Memcached) 410 runs green,
RuboCop clean. [patch](../../bench/upstream/app_suites/su1-local-cache-anonymous-store.patch),
[body](../../bench/upstream/app_suites/su1-body.md). Branch `thomasklemm/local-cache-anonymous-store` @ `2b02aad60c`
on main `7a78da5a55`. With it, that Sure test gets past the cache and then hits SU2.

**SU2 (b, record only): `find_by_sql`/`count_by_sql` array arguments are now bind parameters.** Bisected to
8c4ed25f0a (#58427, kamipo, CHANGELOG; its parent passes). With prepared statements on PostgreSQL, a placeholder
after a type name becomes `DATE $1` (`syntax error at or near "$1"`), and `date - $1` makes PostgreSQL infer the
parameter as a date (`invalid input syntax for type date`) or the comparison as `date >= integer`. `where` behaved
this way on 8-1 already; with prepared statements off, all forms work on both. Repro:
[typed_literal.rb](../../bench/upstream/app_suites/typed_literal.rb) (`PS=1`/`PS=0`). About 432 of Sure's errors:
[`generate_series(DATE :start_date, …)`](https://github.com/we-promise/sure/blob/e658686d5ba7a55734ae9f42683618aa42342b74/app/models/balance/chart_series_builder.rb#L159) and
[`date BETWEEN inflow_candidates.date - :date_window …`](https://github.com/we-promise/sure/blob/e658686d5ba7a55734ae9f42683618aa42342b74/app/models/family/auto_transfer_matchable.rb#L320)
(shortened), plus the 4 Financekit failures, which pass with `prepared_statements=false` (the transfer matcher's
error rolls back the downstream transaction). Our open #59565 adds a cast hint for the `DATE $1`/`IS $1` syntax
error, but not for the arithmetic case. Deliberate change with a CHANGELOG entry, and `where` already binds this way on 8.1, so record only (decided
2026-11-04): no Rails PR, no comment on #58427. The app-side fix is an explicit cast such as `CAST(:d AS date)`.

**SU3 (b): `disable_referential_integrity` on PostgreSQL 18.4+ re-checks foreign keys.** 7051ca8a45 (#57378,
CHANGELOG: restoring `ENFORCED` checks existing rows). Sure's
[`disable_referential_integrity { User.delete_all }`](https://github.com/we-promise/sure/blob/e658686d5ba7a55734ae9f42683618aa42342b74/test/models/user_test.rb#L1091) leaves `api_keys` rows
pointing at deleted users, so restoring raises `InvalidForeignKey` (3 errors). On PostgreSQL < 18.4 the trigger path
is unchanged.

**SU4 (b): Redis cache store needs `redis-client >= 0.28.0`.** 5843a7b7f2 (CHANGELOG); Sure locks 0.25.0
(2 `LoadError`s).

**SU5 (c): activerecord-import 2.2.0 calls the removed private `validation_context=`.** 0f9d127083 (#58220, "Remove
unused Active Model internals"); [import.rb in 2.2.0](https://github.com/zdennis/activerecord-import/blob/6aec1e78060f15a8d39f31592225848e9e35f2b7/lib/activerecord-import/import.rb#L82) calls
`model.send(:validation_context=, validation_context)`. Released 3.0.0 and 3.0.1 no longer call it. 18 errors plus 9
import count failures (`Entry.count` unchanged) in `TransactionImportTest` and `TradeImportTest`.

## Not run yet

Chatwoot or Forem (paused under the orb-time rule).

## once-campfire

`a05ee90` follows rails main and calls `load_defaults 8.2`, so 8-1-stable can't boot it. Main `8b06b0eb98`: 649
runs, 0 failures.

## Writebook

basecamp/writebook `d57c62b` (default branch `main`,
[`d57c62bc19`](https://github.com/basecamp/writebook/tree/d57c62bc19edac3930d3860a2584757f1d45d07c)), Ruby 3.4.12,
SQLite. Writebook tracks Rails main and locks `3a4961048a` (2026-01-13), which is the base here instead of
8-1-stable: two runs on its own lock, then two on main pinned to `7a78da5a55` (2026-11-04), 3970 commits later. The
main checkout changes only the Gemfile's rails line (`ref:`) and the resolved lock. Main's own gemspecs need
globalid ≥ 1.4.0 (52306a97cf, "Introduce `ActiveJob::DeserializationError::RecordNotFound`"), marcel 2.1.0, herb
0.11.1 and ractor-dispatch 0.3.0. globalid fits the locked Rails too, so both sides moved from 1.3.0 to 1.4.0
(`bundle update --conservative globalid`); the other three can't apply to the lock side (its activestorage pins
`marcel ~> 1.0`; herb and ractor-dispatch are new to main). Otherwise the two locks have identical gems.
Writebook's test env doesn't raise on deprecations (`disallowed_deprecation_warnings = []`, `:stderr`), so new ones
are read from the logs.

Results, `bin/rails test` (313 runs) and `bin/rails test:system` (3 runs, headless Chrome 157): locked Rails 4 F,
4 F, system clean ×2; main 4 F, 4 F, system clean ×2. The 4 failures are the same on all four runs:
`VipsLoaderPolicyTest` expects ICO, PSD, BMP and SVG loads to be blocked, and the orb's libvips 8.14 still allows
them (environment). No failure happens only on main, so there is nothing to bisect and no fork branch.

Harness note: a first main run with a hand-edited lock (revision changed, globalid left at 1.3.0) raised
`NameError: uninitialized constant GlobalID::Locator::RecordNotFound` in `BookTest`. Bundler didn't recheck the git
gemspec's new `globalid >= 1.4.0`. A resolved lock gets 1.4.0 and the test passes, so it isn't a Rails issue; main
locks for this harness are resolved with `bundle lock --conservative --update` over all Rails gems.

**WB1 (c, deprecation only): propshaft 1.x reads `Mime::EXTENSION_LOOKUP`.** f6c709e747 deprecates `Mime::SET`,
`Mime::LOOKUP` and `Mime::EXTENSION_LOOKUP` (actionpack CHANGELOG), so Writebook's main runs print 784 warnings
from propshaft 1.0.0's `asset_paths_by_type`. The latest release still has it:
[`Mime::EXTENSION_LOOKUP[content_type]`](https://github.com/rails/propshaft/blob/eb5957157c2e59fabff5b15c710826670fd66c27/lib/propshaft/load_path.rb#L36)
(shortened) and
[`exts_to_watch  = Mime::EXTENSION_LOOKUP.map(&:first)`](https://github.com/rails/propshaft/blob/eb5957157c2e59fabff5b15c710826670fd66c27/lib/propshaft/load_path.rb#L55)
in propshaft 1.3.2. Fixed on propshaft main, unreleased:
[d028d5fd65](https://github.com/rails/propshaft/commit/d028d5fd65791051f11e83be1bf82b31e37b9b4c) (2026-07-02,
"Don't use Mime::EXTENSION_LOOKUP directly"). An app on propshaft ≤ 1.3.2 that disallows this warning
would raise in asset lookups. Record only; propshaft needs a release before Rails 8.2. The only
other deprecation, `config.active_support.to_time_preserves_timezone`, prints on both sides.

## Forem

forem/forem `5f0276d` (default branch `main`,
[`5f0276dce1`](https://github.com/forem/forem/tree/5f0276dce15e3859f7bf4d39c5460efbdc398288)), Ruby 3.3.13 (Forem
pins 3.3.0; main needs ≥ 3.3.5), PostgreSQL 15.19 with pgvector 0.8.1, Redis 7, headless Chrome 157 for the 77
system spec files. Rails main `7a78da5a55` for every run, the fix branch and the bisects; 8-1-stable `6e09124217`.
Full rspec suite, 1394 files and 16542 examples, in 4 processes with one database and Redis db each, `--seed 4242`,
files split by size (about 30 minutes of CPU, 9 minutes wall per run). Forem's test env raises on deprecations;
both trees keep that and only log Devise 4.9.4's route mapper warning ("received a hash argument … removed in Rails
8.2"), which both trees emit.

**Lockfiles.** Forem locks Rails 8.0.5. The 8-1 lock comes from `bundle lock --conservative --update rails`, which
also moved action_text-trix, jbuilder, loofah, metainspector, nokogiri and rails-html-sanitizer. Both locks then took
four bumps, each to the lowest version that works. The main lock was resolved from the 8-1 lock and differs only in
the Rails gems and what main itself requires (herb 0.11.1, marcel 2.1.0, ractor-dispatch 0.3.0). Only main needs the
four bumps, so each is (c):

| Bump | Why main needs it | 8-1 |
|---|---|---|
| amazing_print 2.0.0 → 3.0.0 (Gemfile `~> 3.0`) | 2.0.0 reads `LogSubscriber.colorize_logging` at load, so boot fails (E3, our #59628) | boots with 2.0.0 |
| bullet 8.1.3 → 8.3.0 | 8.1.3 raises "Bullet does not support active_record 8.2.0.alpha"; 8.3.0 is the first with `active_record82` | 8.1.3 fine |
| carrierwave 3.1.3 → 3.1.4 | 3.1.3 pins `marcel ~> 1.0.0`, main's activestorage needs marcel 2 | 3.1.3 fine |
| rspec-rails 6.1.1 → `570b2b0a79` (git, pulls rspec 3.13) | L1: 11 mailer spec files fail to load with `FrozenError`; the ref also has the `_prefixes` fix | 6.1.1 fine |

**Main checkout only, app side** (each one otherwise stops boot, so the whole suite):
[`require_dependency`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/config/initializers/devise.rb#L2)
→ `require` in 8 files (deprecated, CHANGELOG); [`rescue_from ActionController::InvalidAuthenticityToken`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/controllers/application_controller.rb#L50)
→ `InvalidCrossOriginRequest` (deprecated constant, raises at class load); and the FO2 shim below. The main test
databases are copies of the 8-1-loaded schema, because F1 stops `db:schema:load` on main.

Results: 8-1 5 F and 5 F (4 shared, one flaky each: `award_thumbs_up_spec`, `local_redis/sync_spec`); main 1695 F,
of which 1690 never fail on 8-1. Every one is classified below; F1 is the only (a).

**F1 (a): array columns of extension types with a default can't be created.** Forem's
[`t.ltree "target_geolocations", default: [], array: true`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/db/schema.rb#L727)
stops `db:schema:load` at `display_ads` with `TypeError: can't quote Array`; `citext[]` and `hstore[]` fail the same
way. Bisected to e8af4f09a2 ("Use well-known PG OIDs while defining built-in coders", #57013, merged as ca86130159):
the type map now loads OIDs on demand, and `lookup_cast_type` returns `ActiveModel::Type::Value` for an OID it hasn't
loaded. Not in S1–SU5, R2-x, E1–E4 or AR-1–AR-4; no issue or PR found. Repro:
[pg_extension_array.rb](../../bench/upstream/app_suites/pg_extension_array.rb) (an enum array default fails on both
trees and is not part of this). Fix: load the OID first when the type map lacks it, as `get_oid_type` does; one test
in `ltree_test.rb` that fails on main with the `TypeError`. PostgreSQL adapter and migration tests 1587 runs green,
schema dumper/migration/defaults 179 runs green, RuboCop clean; Forem's schema then loads all 135 tables.
[patch](../../bench/upstream/app_suites/f1-pg-extension-array-default.patch),
[body](../../bench/upstream/app_suites/f1-body.md). Branch `thomasklemm/pg-extension-array-default` @ `2a4e5c1ebc` on
main `7a78da5a55` (rechecked on the freshly fetched main, which is still `7a78da5a55`).
**Held: covered by open [#57785](https://github.com/rails/rails/pull/57785) (yes).** That PR (Halvanhelv, head
`157169cb29`, last updated 2026-09-27, for #52944's cross-database schema cache) makes `lookup_cast_type` resolve
through `get_oid_type`, the same change. On main `7a78da5a55` its `quoting.rb` hunk and tests apply cleanly; the
`model_schema.rb` hunk and the CHANGELOG conflict with main, so the `type_for_column` fallback was ported by hand
unchanged. With it: our `ltree_test.rb` test passes (ltree, citext, hstore and enum tests 83 runs, 0 F); the repro
creates ltree[], citext[] and hstore[] columns with defaults (`{a.b}`, `{A}`, the hstore literal); Forem's
`db:schema:load` loads all 135 tables, with `target_geolocations` defaulting to `'{}'::ltree[]`. Our branch stays
unopened; the body carries Sol's nits in case it is ever needed on its own. Pointed out on #57785 with Thomas's approval on 2026-11-04 ([comment](https://github.com/rails/rails/pull/57785#issuecomment-6641269976)). Also noted on the causing PR #57013 with a pointer to #57785, with Thomas's approval ([comment](https://github.com/rails/rails/pull/57013#issuecomment-6641636728)).

**FO1 (c): flipper-active_record 1.4.2 passes the table name positionally.** [`::Arel::Table.new(@feature_class.table_name.to_sym)`](https://github.com/flippercloud/flipper/blob/50a8207ada6c93fd4c29bcee683660b7351647a7/lib/flipper/adapters/active_record.rb#L106)
(v1.4.2) raises `wrong number of arguments` since b1650993b0 (#57829, `Arel::Table` is `:nodoc:`). 163 failures,
order-dependent: once `spec/initializers/flipper_spec.rb` reloads the initializer, every later request spec in that
process fails in the memoizer's `preload_all`. Fixed on flipper main (`arel_table`), unreleased. Already covered by our
open #59574: with it, flipper_spec plus `follows_bulk_show_spec` pass 8/8 with the deprecation warning. Not bisected.

**FO2 (c)/(d): jsonapi-serializer 2.2.0 overrides `HasOne.define_accessors(mixin, reflection)`.**
[has_one.rb#L7](https://github.com/jsonapi-serializer/jsonapi-serializer/blob/37235057df7f33a1561c3313eaac87d2549fdc55/lib/extensions/has_one.rb#L7)
(v2.2.0, the last release, 2021; unchanged on its default branch). ddf56d4b43 (#59393) changed the private builder
signature to `(model, reflection, mixin)`, so loading `User` raises `ArgumentError` and the app doesn't boot: the shim
(main checkout only, an initializer that redefines the override with the new signature) hides all 16542 examples.
Private API, so no Rails fix; the gem would need a release.

**FO3 (b)+(d): Forem's `LocalRedisCacheStore` subclasses `RedisCacheStore` and uses redis-rb's API.**
[`pipeline.eval(VALUE_AND_TTL, keys: [key])`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/lib/active_support/cache/local_redis_cache_store.rb#L128)
hits `RedisClient::Pipeline#eval` (private) since 5843a7b7f2 moved the store to redis-client (CHANGELOG): 49 failures
in the store, `local_redis/sync` and `metrics` specs. [`bypass_local_cache`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/lib/active_support/cache/local_redis_cache_store.rb#L39)
is the private method removed in 4f594320e4 (R2-16): 3 more.

**Deprecations that only main emits, raised by Forem's test env** (examples failing):
* 1350: `` `verify_authenticity_token` is deprecated … use `skip_forgery_protection` ``, from
  [`skip_before_action :verify_authenticity_token`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/controllers/api/v1/api_controller.rb#L9)
  and 20 other controllers (31 of them show up as a 422 in `user_roles_spec`).
* 67: `` Calling `protect_from_forgery` without specifying a strategy is deprecated `` (CHANGELOG), from
  [omniauth_callbacks_controller.rb#L11](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/controllers/omniauth_callbacks_controller.rb#L11).
* 33: `exec_update is deprecated` / `exec_delete is deprecated`, from
  [billboard_event.rb#L56](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/models/billboard_event.rb#L56),
  [article_activity.rb#L209](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/models/article_activity.rb#L209)
  and [bulk_sql_delete.rb#L11](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/services/bulk_sql_delete.rb#L11)
  (7 of them in `Organizations::DeleteWorker`, which rescues and reports the error).
* 8: `ActionController::InvalidAuthenticityToken has been deprecated` (the app's other references, in
  `metal_telemetry_fast_path.rb` and `valid_request.rb`).
* 2 (c): `Mime::EXTENSION_LOOKUP is deprecated`, from Devise 4.9.4's
  [`Mime::EXTENSION_LOOKUP[format.to_s]`](https://github.com/heartcombo/devise/blob/d5a48b49dcb95941f864180296ad68683e205edc/app/controllers/devise_controller.rb#L99);
  fixed on Devise main, unreleased (5.0.4 still has it).
* `Passing a Redis or ConnectionPool instance via the :redis configuration … is deprecated` fails one store spec,
  counted in FO3.
* Boot-level, worked around above: `require_dependency is deprecated` and `InvalidAuthenticityToken`.

**The rest (15):**
* 4 (b): `precision: nil` timestamps cast to microseconds (as in Mastodon); 1 (b): the enum `ArgumentError` lists the
  valid values.
* 2 (b): a null byte in a slug now raises `ActiveRecord::NullByteError` (a `StatementInvalid`), which Forem's
  `rescue ArgumentError` no longer catches; the CHANGELOG says so.
* 3 (b): `framework_defaults_spec` reads `ActionView::Helpers::UrlHelper.button_to_generates_button_tag` (now on
  `NavigationHelper`, S2) and `raise_on_assign_to_attr_readonly` (deprecated, nil).
* 1: E1 (`WeakSet` not required), in a spec that boots `descendants_tracker` on its own.
* 3 (d): `ServerWarmup.preload_view_templates!` reads the resolver's private
  [`@unbound_templates`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/app/lib/server_warmup.rb#L247),
  which main turns into a plain Hash after eager loading (25f2e02c9a, 2afdfaf660), so the warmup skips it.
* 1 (d): `comment_creator_spec` checks that a delegator responds to every `Comment.instance_methods`, which now
  includes the new protected `association_cache` (d432679e04).

## Chatwoot

chatwoot/chatwoot `a8364f9` (default branch `develop`,
[`a8364f9c43`](https://github.com/chatwoot/chatwoot/tree/a8364f9c4385b12b4f217649c1dad23755459215)), Ruby 3.4.4 (its
pin) on both trees, PostgreSQL 16.15 with pgvector, Redis 7.0. Rails main `7a78da5a55` for every run, the bisects and
the fix branch; 8-1-stable `6e09124217`. Community edition as in its CI (`enterprise/` and `spec/enterprise` removed),
668 spec files and 7632 examples in 8 processes with one database and Redis db each, files split round-robin, Vite
assets built once per tree (about 4 minutes wall per run). Chatwoot's test env prints deprecations to stderr, so
main-only ones are read from the logs.

**Port to 8.x, identical on both trees.** Chatwoot locks Rails 7.2.3.1 and doesn't boot on 8.x as it is; its own
`codex/rails-8-1-3` branch is 188 commits behind develop and conflicts with it, so the default-branch SHA got a
minimal port instead: the 31 keyword-argument `enum` calls in 23 model files rewritten to `enum :name, {…}` (removed in
8.0); [`resource :app, only: [:index]`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/config/routes.rb#L715)
→ `only: []` (8.1 raises on `:index` for a singular resource; same routes); `sprockets-rails` added to the Gemfile
(Rails 8 no longer depends on it); [`rails-i18n ~> 7.0`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/Gemfile#L89)
→ `~> 8.0`; [administrate-field-belongs_to_search 0.10.0](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/Gemfile#L99),
the latest release, vendored with its `rails < 8.0` and `administrate < 1.0` caps lifted. `bundle lock
--conservative --update rails administrate administrate-field-belongs_to_search rails-i18n` then moved administrate
to 1.0.0, acts-as-taggable-on 13.0.0, audited 5.8.0, devise-two-factor 6.4.1, devise_token_auth 1.3.0 and tidewave
0.9.1. Conservative bumps on both: ruby-vips 2.1.4 → 2.3.0 (8.1's Active Storage refuses older ruby-vips),
groupdate 6.2.1 → 6.8.0 (6.2.1 fails 33 report specs on 8.1), redis-client 0.26.4 → 0.30.1 (SU4: main's
`RedisCacheStore`, built in [rack_attack.rb](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/config/initializers/rack_attack.rb#L19),
needs ≥ 0.28.0 at boot) and rspec-rails 7.0.1 → `570b2b0a79` (L1: every mailer spec file fails to load with
`FrozenError` on main, as in Forem). The two locks then differ only in the Rails gems and what main itself requires
(globalid 1.4.0, herb, marcel 2.1.0, psych, ractor-dispatch, stringio).

**Main checkout only:** [`gem 'active_record_query_trace'`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/Gemfile#L258)
→ `require: false` (c). Its [`CustomLogSubscriber < ActiveRecord::LogSubscriber`](https://github.com/brunofacca/active-record-query-trace/blob/5c6736460471421533d6156bcdf71d938a45ac9a/lib/active_record_query_trace.rb#L80)
calls [`attach_to :active_record`](https://github.com/brunofacca/active-record-query-trace/blob/5c6736460471421533d6156bcdf71d938a45ac9a/lib/active_record_query_trace.rb#L101)
(1.9, the latest release; unchanged on its default branch), and the `:nodoc:` `ActiveRecord::LogSubscriber` is now an
`EventReporter::LogSubscriber` without `attach_to` (308594b580, part of #55900 like R2-3), so boot fails with
`NoMethodError`. The gem's own failing test for this (its #72) was closed. Chatwoot enables it only in development,
so the shim hides no test.

Results: 8-1 63 F (50 in `super_admin` specs on administrate 1.0, plus `contact_inbox_builder`, Slack uploads'
open-redirect check, confirmation mailer: upgrade fallout that main shares). Main 211 F, 148 of them not on 8-1, in
19 files. Those files again: main 148 F, 8-1 3 F and 3 F (the 3 confirmation mailer ones, which fail on all runs).
The 3 `working_hour_spec` failures passed on main's rerun (time-of-day dependent), so 145 main-only failures are
stable; all are classified below, and CW1 is the only (a).

**CW1 (a): `where("", values)` puts `(())` in the query.** Chatwoot's
[`FilterService#query_builder`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L189)
calls `where(@query_string, @filter_values)`, and `@query_string`
[starts as `''`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L20);
with no filters, `PG::SyntaxError` (4 failures in `conversations/filter_service_spec`). 8-1 drops the empty condition;
on main `build_where_clause` [wraps it in parentheses](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/relation/query_methods.rb#L1995)
before the fallback that leaves it unchanged. Bisected to 8c4ed25f0a (#58427, kamipo), the SU2 commit; this is a
side effect of moving `where`'s dispatch into `bound_sql_literal_for`, not the deliberate `find_by_sql` change, and the
fallback's parentheses are otherwise only doubled (`((a = 1))`, harmless). Not in S1–SU5, R2-x, E1–E4 or AR-1–AR-4
(AR-4 changes `where!`'s signature, not this branch); no issue or PR found. Repro:
[empty_where.rb](../../bench/upstream/app_suites/empty_where.rb). Fix: use an empty condition as it is
(`if rest.empty? || opts.empty?`), which is what 8-1's `sanitize_sql` returned for it with any values; one test in
`where_test.rb` (empty, named and positional values) that fails on main with a syntax error. Relation, finder,
sanitize, relations and base tests 1508 runs green on SQLite, RuboCop clean; with the fix in the main tree, Chatwoot's
`filter_service_spec` passes 52/52.
[patch](../../bench/upstream/app_suites/cw1-where-empty-condition-binds.patch),
[body](../../bench/upstream/app_suites/cw1-body.md). Branch `thomasklemm/where-empty-condition-binds` @ `4520f97971`
on main `7a78da5a55` (the freshly fetched main). No review round yet.

**CW2 (d), restore candidate: the private `Resolver#_find_all` is gone.** 9987431315 (#58279, "Resolve the single
best template without sorting the whole set") inlined it; 8-1's [`find_all` called it](https://github.com/rails/rails/blob/6e091242176c322edc5a8907583c01b08b8a60bc/actionview/lib/action_view/template/resolver.rb#L61).
Chatwoot's [`EmailTemplates::DbResolverService#find_all`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/email_templates/db_resolver_service.rb#L28)
(a pattern from panoramic) calls `_find_all(name, prefix, partial, details, key, locals)`, so every mailer that
renders through it raises `NoMethodError`: 121 failures (an app-side shim defining `_find_all` in that class, used for
one rerun only, removes all of them). The commit says custom resolvers that override `find_all` keep working; those
that override `_find_all` itself no longer have it called at all, by reading the code (not run):
[godmin 2.3.0](https://github.com/varvet/godmin/blob/b270f3736dde6022b71544c1692cafea42d4b35f/lib/godmin/resolver.rb#L22)
and [rbexy 2.0.0.rc7](https://github.com/patbenatar/rbexy/blob/681bc8813f9e8258b8c8ed4056030d0516d5d4ad/lib/rbexy/rails/component_template_resolver.rb#L13)
(both `FileSystemResolver` subclasses), plus unreleased view_component-cache_digest and torque-admin; code search shows
about 245 hits for `_find_all(name, prefix, partial`, mostly Chatwoot and old Redmine forks. Unreleased and private.
A restore of the base `Resolver#_find_all` hook, with `find_all` going through it, would be small and fix
Chatwoot's pattern; honoring overrides in `FileSystemResolver` subclasses would mean routing `find` through them too,
which is not small. Not built: the coordinator decides whether this meets the restore rule.

**CW3 (b): `precision: nil` datetime columns cast to microseconds in memory** (as in Mastodon): 2 failures, the widget
and public `update_last_seen` specs expect `UpdateMessageStatusJob.perform_later` with a nanosecond `Time` on
`contact_last_seen_at`.

**CW4 (b): integration `get …, params:, as: :json` sends the params in the query string.** 3c99a378ad (#57140,
CHANGELOG) removed the `X-Http-Method-Override` POST, so `companies_controller_spec`'s `page: 1` comes back as `"1"`
(2 failures). The CHANGELOG says "`params:` retains existing behavior: GET → query string", which isn't what 8.1 did
for GET with `as: :json`.

**CW5 (b?), record only: saving re-derives a polymorphic type from the associated record.** Factories build
`Inbox` with a `channel` and then `channel_type: 'Channel::FacebookPage'`; 8-1 saves that type, main saves the
channel's class. Bisected to 4af9822fae ("Write association keys through routes", #59120, the R2-1 commit); repro:
[poly_type.rb](../../bench/upstream/app_suites/poly_type.rb). 8-1 stored a type that disagrees with the saved record,
so main's result is consistent and the test relied on the mismatch: 2 failures
(`contact_inbox_with_contact_builder_spec`, `billing_helper_spec`). No CHANGELOG entry.

**SU5 (c): activerecord-import 2.1.0 calls the removed `validation_context=`**: 14 failures in the data import
job and Intercom importer specs.

**Deprecations that only main emits** (warnings in the main run): 1817 `` `verify_authenticity_token` is deprecated
… use `skip_forgery_protection` `` (as in Redmine and Forem); 16 `config.active_record.raise_on_assign_to_attr_readonly`
is deprecated; 8 `Passing a Redis or ConnectionPool instance via the :redis configuration to
ActiveSupport::Cache::RedisCacheStore is deprecated`, from rack_attack.rb above. Both trees print Devise 4.9.4's route
mapper warnings and `ActiveSupport::Configurable is deprecated`.

## Private Rails app with Inertia Rails

The private app from [the anonymized M0 study](../m0/private-inertia-app.md): authenticated Inertia (React) pages,
dashboards, background jobs, PostgreSQL. No application source, names or test counts are recorded here, per that
study's privacy rules; the app was not changed upstream (no commits, branches or PRs). Ruby 4.0.9 on both trees,
its locked inertia-rails 3.23.0, PostgreSQL 18.6, the app's own `rails test` with 8 workers and a fixed seed.
Rails 8-1-stable `6e09124217` and main `7a78da5a55`, both as `path:` gems.

**Bundles.** The two locks differ only in Rails and what main itself requires (herb, marcel 2.1, psych,
ractor-dispatch, stringio), plus one gem whose latest release caps marcel below 2; it was moved to its unreleased
upstream fix commit in both trees. The app's test env prints deprecations to stderr (not raising), so main-only ones
were read from the logs. Environment fixes identical on both trees: the `zip` CLI installed, and
`max_locks_per_transaction = 256` on the test cluster (PI2; with the default 64, one of two main runs failed most
tests with `out of shared memory`; the 8-1 runs never did).

**Results.** 8-1 twice: every test passes. Main twice: the same failures both times, all in one area of the app and all
from PI1. With a one-line app-side shim for PI1 (main checkout only), main passes every test, with the same assertion
count as 8-1.

**PI1 (c), covered by our open #59574: `Arel::Table.new(name)` with a positional name.** The app calls `Arel::Table.new` with a
positional name and gets `ArgumentError (given 1, expected 0)` (b1650993b0, #57829; see
[arel-table-positional](arel-table-positional.md)). With #59574's branch in the main tree and no app shim, the failing
files pass, and each call prints the new deprecation. Nothing new to build.

**PI2 (a), lead, not built: `disable_referential_integrity` on PostgreSQL 18.4+ holds about 16 times as many locks.**
7051ca8a45 (#57378, CHANGELOG) toggles every foreign key with `ALTER TABLE … ALTER CONSTRAINT … NOT ENFORCED` and back,
in one transaction. Each toggle locks the table, the referenced table, their indexes and the constraint until commit;
8-1 used `DISABLE TRIGGER ALL`. `truncate_tables` (at each parallel worker's start) and `insert_fixtures_set` both go
through it, and fixture loading keeps the locks until its transaction commits. PostgreSQL's shared lock table holds
about `max_locks_per_transaction` × connections (64 × about 100 by default), so parallel test workers that load
fixtures at the same time can run out: `PG::OutOfMemory: out of shared memory`. In the app suite this hit one of the
two main runs and neither 8-1 run. Repro without app code:
[fk_locks.rb](../../bench/upstream/app_suites/fk_locks.rb), default PostgreSQL 18.6 settings, 151 tables with 300
foreign keys: one call holds 161 locks on 8-1 and 2,558 on main. 24 processes resetting their databases at once, each
holding the locks for half a second as a fixture load would: 8-1 24/24 ok twice; main 10 and 13 of 24 fail with
`out of shared memory`. With 8 or 16 processes the repro passes on main most of the time, so how often a suite hits
it depends on the database size and on whatever else holds locks at that moment. The CHANGELOG entry doesn't mention
locks. No issue or PR found. A fix isn't small: the toggle is the point of the change (it needs table ownership
instead of superuser), and the locks are what `ALTER CONSTRAINT` takes. Options for the coordinator: an upgrade-guide
or CHANGELOG note (raise `max_locks_per_transaction` for parallel tests), or asking upstream whether `truncate_tables`
needs the toggle at all, since PostgreSQL truncates all tables in one statement. App-side workaround: raise
`max_locks_per_transaction`.

**PI3 (a, performance), built: `Object#try` allocates an empty keyword Hash per call.** 2709a9f16d (kamipo, "Remove
`ruby2_keywords` usage", no CHANGELOG) turned `try(*args, &block)` with `ruby2_keywords` into
`try(*args, **kwargs, &block)`; a named keyword splat builds a Hash on every call. Found by allocation sites per
request: inertia-rails 3.23.0's prop resolver calls
[`prop.try(:rescue?)`](https://github.com/inertiajs/inertia-rails/blob/3ffd1f4c4f66cef89c481423af1fc25beb859de6/lib/inertia_rails/props_resolver.rb#L120),
[`prop.try(:deferred?)`](https://github.com/inertiajs/inertia-rails/blob/3ffd1f4c4f66cef89c481423af1fc25beb859de6/lib/inertia_rails/props_resolver.rb#L279)
(shortened) and [`prop.try(:once?)`](https://github.com/inertiajs/inertia-rails/blob/3ffd1f4c4f66cef89c481423af1fc25beb859de6/lib/inertia_rails/props_resolver.rb#L285)
per prop (v3.23.0), so its allocations rise by about 200 objects
per page on main. Repro: [try_kwargs.rb](../../bench/upstream/app_suites/try_kwargs.rb) (8-1 1 object per
`try(:name)`, main 2, fix 1; with keywords 3 on all three). Fix: an anonymous `**`, which Ruby 3.4+ doesn't allocate
for without keywords (3.3 measured unchanged); the block form is chosen again when there are no positional
arguments, as in 8-1, so `try(key: 1) { }` (`TypeError` on 8-1 and main) now runs the block. Test in `try_test.rb`
(guarded `RUBY_VERSION >= "3.4"`, as other Active Support tests are) fails on main with 2; `try_test.rb` passes on 4.0.9
and 3.3.13; Active Support `core_ext` tests identical to main (only missing-`builder` LoadErrors in this bundle);
RuboCop clean. Per call: 2 → 1 objects, Callgrind 3,362 → 2,835 instructions in the interpreter and 2,293 → 1,897 with
YJIT (A/A identical). ZJIT micro on Ruby master not run (no master build on this orb).
[patch](../../bench/upstream/app_suites/pi3-try-without-kwargs-hash.patch),
[body](../../bench/upstream/app_suites/pi3-body.md). Branch `thomasklemm/try-without-kwargs-hash` @ `1e3539559d`
on main `7a78da5a55`. No review round yet.

**inertia-rails 3.23.0 on main:** nothing breaks and it emits no deprecation; its only main-specific effect is PI3.

**Deprecations that only main emits** (all from app code): `exec_insert`/`exec_update` (deprecated, to be removed in
9.0), `ActionController::InvalidAuthenticityToken` (renamed to `InvalidCrossOriginRequest`), and
`ActiveRecord::SchemaDumper.ignore_tables` (use `config.active_record.schema_ignored_tables`).

**Impact on four requests:** [private-inertia-app-82](../m0/private-inertia-app-82.md).
