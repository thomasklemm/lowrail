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
