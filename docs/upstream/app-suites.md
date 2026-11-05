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
| Mastodon `ca2f092` | rspec (flatware, 8 workers), 8002 examples, PostgreSQL 17 + Redis | 0 F, 0 F | 2427 F ×2; with 2 app shims 34 F ×2, all main-only | R1 (d, our #59630), M1 (d, record only), `Vary` (b, open #59500), S2 and 3 more (b), L1 |
| Sure `e658686` | `rails test`, 14313 runs, PostgreSQL 18.6 + Redis | 0 F, 0 F | 13 F, 472 E | SU1 (a), SU2 (b, record only), SU3–SU5 (b/c) |
| Writebook `d57c62b` | `rails test`, 313 runs, plus 3 system tests; SQLite | its lock (main `3a49610`): 4 F ×2 (libvips, environment) | same 4 F ×2; system clean | no main-only failure; WB1 (c, deprecation) |
| Forem `5f0276d` | rspec, 16542 examples, PostgreSQL 15 + Redis | 5 F, 5 F (1 flake each) | boot needs 4 bumps and 3 app shims; then 1690 main-only F | F1 (a), FO1–FO3 (c/d), deprecations (b) |
| Chatwoot `a8364f9` (CE) | rspec, 7632 examples, PostgreSQL 16 + pgvector, Redis | 63 F (port fallout, also on main); failing files twice more: same | 1 gem shim (boot); 148 main-only F, 145 stable | CW1 (a), CW2 (d, restored), CW3–CW5 (b), SU4, SU5, L1 |
| Discourse `f81fcb4` | core rspec without system specs, 35771 examples, PostgreSQL 15 + pgvector, Redis | 53 F (environment); failing files twice more: 52 F, 51 F | seeding fails (DS1), so every example fails; with 2 app shims 191 F, 140 main-only and stable | DS1 (a, fix built, PR blocked on CLA), DS2 (a, open #59595), DS3 (b+d), DS4 (d), #59574's Arel case, AR-4, S1, (b)/(c) |
| Private Rails app with Inertia Rails (anonymized) | `rails test`, PostgreSQL 18.6, 8 workers | clean, clean | all main-only failures from one call (PI1); otherwise clean | PI1 (c, our #59574), PI2 (a, docs note queued), PI3 (a, perf, built) |
| Spree `b16f633` | rspec: core 11236, api 6320, emails, dashboard, mcp, opentelemetry and 4 providers 1030 examples; PostgreSQL 16 | clean ×2 (every suite) | 2 boot shims (our #59627, #59574); then 53 F ×2, all main-only (core 49, api 4) | SP1 (b, docs note built), SP2 (b), SP3 (c, mobility#692) |
| Decidim `80149bb` | rspec without system specs: core 5141, admin 997, api 73, participatory_processes 942, proposals 1897, meetings 1739 examples; PostgreSQL 15 | 3 F ×2 (Faker data, also on main); failing files a third time: same | 1 boot shim (our #59574); then 262 F (run 2; run 1 +21 from a port clash), same a third time, 259 main-only | DC1 (a, fix built, queued first), DC2 (b+c, cells-rails, silent), DC3 (c, rspec-rails 8.0.4), DC4–DC6 (b), CW3, CW5 |
| Zammad `64e70ff` | rspec without system specs, 20323 examples, PostgreSQL 18.6, Redis, memcached (no Elasticsearch) | 7 F, 10 F (environment, also on main); failing files twice more: 7 F, 8 F | no shim needed; 2520 F, 2524 F; 2498 from one call (ZM1), 15 main-only otherwise | ZM1 (d, restore built, queued), ZM2 (c, rspec-rails), ZM3 (d), ZM4 (b), ZM5 (d), CW4 (b) |

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

mastodon/mastodon `ca2f092` (default branch `main`,
[`ca2f092f4f`](https://github.com/mastodon/mastodon/tree/ca2f092f4f580b1993bae3ac4f4742b748f18ad1), 2026-11-04),
Ruby 4.0.9 (its `.ruby-version`), PostgreSQL 17.11, Redis 7.0.15. Rails main `bdb3d96012` (2026-11-05) for every run,
bisect and check; 8-1-stable `6e09124217` (v8.1.4.1). The suite as its CI test job runs it: `bin/flatware rspec`
with 8 workers, one database each (`bin/flatware fan bin/rails db:test:prepare`), all of `spec/` except the `js`,
`search` and `streaming` tags that `rails_helper.rb` excludes; 8002 examples, 2 pending. Seeds 4242 and 1717 on both
trees, about 90 seconds wall per run. CI's OIDC, SAML and CAS settings are on; the `pam_authentication` group isn't
bundled (`ALLOW_NOPAM=true`), the same on both trees. Assets were built once with `bin/rails assets:precompile` on the
8-1 tree and copied to the main tree. Mastodon's test env prints deprecations to stderr, so main-only ones are read
from the logs.

**Lockfiles.** Mastodon locks Rails 8.1.4.1, so the 8-1 lock differs from Mastodon's own only in the `path:` Rails
and the rspec-rails bump below. The main lock was resolved from the 8-1 lock (`bundle lock --conservative --update`
over the Rails gems) and differs only in the Rails gems and what main itself requires: herb 0.11.1, marcel
1.2.1 → 2.1.0, psych 5.5.0, ractor-dispatch 0.3.0, stringio 3.2.0 (globalid is already 1.4.0). One bump, on both
trees: rspec-rails 8.0.4 → `570b2b0a79` (git), because on main with 8.0.4 `user_mailer_spec.rb` fails to load with
`FrozenError: can't modify frozen Hash: {}` (L1) and all 9 view specs fail with `FrozenError` on `_prefixes` (both
fixed in that ref; 8.0.4 is still the latest release). 8-1 passes with either.

Results: 8-1 0 F and 0 F. Main 2427 F and 2427 F, the same examples both times, in 416 files; those 416 files again
on 8-1 (3268 examples): 0 F. Main with two app-side shims (main checkout only: define `filter_proxies` in
Mastodon's extension with 8-1's body, and pass `attr` to `build_bind_attribute`;
[patch](../../bench/upstream/readiness/round-app-suites/mastodon-main-shims.patch)): 34 F and 34 F, the same examples, in 9
files; those files a third time: the same 34. No flaky failure on either tree, so every main failure is main-only.
All of it is classified below, and none of it is a new (a).

| Group | Failures | Class | Commit | Status |
|---|---|---|---|---|
| R1 `GetIp#filter_proxies` removed | 2187 | (d), restore | 752cc3915d (#56805) | our open #59630 |
| M1 `build_bind_attribute` takes an Arel attribute | 225 | (d) | 4f1ff11da3 (#58479) | record only; restore built as ZM1 |
| `Vary: Sec-Fetch-Site` on GET responses | 19 (behind R1) | (b) | f5a1915f1d (#56350) | open #59500 |
| S2 `link_to` moved to `NavigationHelper` | 11 | (b) | 07f4b45e29 (#55410) | our S2 note, queued |
| `precision: nil` timestamps as microseconds | 3 | (b) | c162370c8f (#57845) | CHANGELOG |
| enum `ArgumentError` lists the valid values | 1 | (b) | fcf4393f04 (#57446) | CHANGELOG |

Each commit was bisected over 8ae3d84277 (the 8-1-stable branch point) to main with one spec file per group, then
checked against its parent: the parent has no failure of the group, the commit has the group's failures. Harness
notes for the bisects: Mastodon's
[`check_ip(client_ips, forwarded_ips) if @check_ip`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/lib/action_dispatch/remote_ip_extensions.rb#L38)
(since its 8.1.4.1 update,
[599d816f6e](https://github.com/mastodon/mastodon/commit/599d816f6e4dd444766155cbce05ffea8568d2f8)) calls the private
`GetIp#check_ip` that 8.1.4.1's security fix added (475118e113 on main, 2026-11-03), so older main commits fail every
request spec; the bisect copies call it only when it exists. The bisect copies' M1 shim picks the argument by the
method's parameter name, so it works on both sides of 4f1ff11da3.

**R1 (d), restore, our open [#59630](https://github.com/rails/rails/pull/59630).** Mastodon's
[`filter_proxies([remote_addr] + ips).first || ips.last || remote_addr`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/lib/action_dispatch/remote_ip_extensions.rb#L57)
calls the `:doc:` private method that 752cc3915d (#56805, fatkodima, perf) replaced with `first_non_proxy`, so every
request raises `NoMethodError`: 2187 failures, which also hide the 19 `Vary` failures. With #59630's head
`54e07d2dba` cherry-picked onto main `bdb3d96012` (applies cleanly) and no `filter_proxies` shim, two full runs give
the same 34 failures as the shimmed runs, none of them from `filter_proxies`, and 2877 warnings that point to
`first_non_proxy`. First found in the earlier round below; nothing new to build.

**M1 (d), record only: `PredicateBuilder#build_bind_attribute` takes an Arel attribute.** 4f1ff11da3 (#58479,
matthewd, "Query predicate expressions for Active Record types, take 2"; CHANGELOG "Add query predicate expressions
for Active Record types") changed it from `(column_name, value)` to
[`(attribute, value)`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/relation/predicate_builder.rb#L128-L131).
Mastodon's [`Status::SafeReblogInsert`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/concerns/status/safe_reblog_insert.rb#L64)
calls `predicate_builder.build_bind_attribute(attr.name, attribute.value)` in its override of `_insert_record`, so
every reblog insert raises `NoMethodError: undefined method 'name' for an instance of String` (225 failures, 28 of
them in `feed_manager_spec`).
Repro: [bind_attribute_name.rb](../../bench/upstream/app_suites/bind_attribute_name.rb): on 8-1 the column name
works (and an Arel attribute gives a bind named by the struct); on main the column name raises. `PredicateBuilder` is
`:nodoc:` and this is one app, so under the restore rule it stays a Mastodon-side fix (pass the attribute on 8.2),
not reported. *Update (2026-11-05):* Zammad, authlogic 6.6.1 and DocuSeal call it with a column name too, so
it is now a restore under that rule, built as [ZM1](#zammad).

**`Vary: Sec-Fetch-Site` (b), covered by open [#59500](https://github.com/rails/rails/pull/59500).** f5a1915f1d
(#56350, "Use a modern approach for cross-site request forgery protection") adds
[`append_after_action :append_sec_fetch_site_to_vary_header`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_controller/metal/request_forgery_protection.rb#L310)
to every protected action; the CHANGELOG entry doesn't mention `Vary`. `statuses_spec` (12, which expects
[`vary_by`'s `Accept, Accept-Language, Cookie`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/controllers/statuses_controller.rb#L9)),
`webfinger_spec` (5, `"Sec-Fetch-Site, Origin"` instead of `"Origin"`), `outboxes_spec` and `embed_spec` (1 each)
fail, all on GET requests. The bisect lands on 4f2ee07b8e (#56369), because between the two commits main had no
`verify_authenticity_token` callback and Mastodon's
[`skip_before_action :verify_authenticity_token, only: :raise_not_found`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/controllers/application_controller.rb#L34)
raised at class load; with that line changed to `skip_forgery_protection`, f5a1915f1d's parent passes and
f5a1915f1d fails the same 17 webfinger and statuses examples. #59500 (czj, head `d255d0649e`, last updated
2026-11-01) stops adding the header for GET, HEAD and QUERY requests, which pass verification on their method alone;
cherry-picked onto main, the four files pass 66/66. Nothing of ours. Heads-up with this data posted on #59500 with Thomas's OK (2026-11-05, [comment](https://github.com/rails/rails/pull/59500#issuecomment-6656106193)).

**The rest (b), all with CHANGELOG entries:** 11 S2 failures,
[`REST::NotificationSerializer`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/serializers/rest/notification_serializer.rb#L5) and
[`REST::NotificationGroupSerializer`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/serializers/rest/notification_group_serializer.rb#L5)
include only `UrlHelper` and call
[`link_to`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/serializers/concerns/notification_fallback_concern.rb#L82)
(our upgrade-guide note S2 is in the queue); 3 `precision: nil` failures, `user_spec` (2) and
`post_status_service_spec` (1) compare against a nanosecond `Time`; 1 in `notification_policy_spec`, which matches
the whole enum error message. The webfinger, outboxes and embed `Vary` failures that the earlier round saw on both trees
pass on 8-1 now.

**Deprecations that only main emits** (warnings in the shimmed main run; the 8-1 runs print none):
* 332: `` Passing `pk` as a positional argument to `insert` is deprecated `` (6669725a14, #58297, CHANGELOG), from
  [`connection.insert(im, "#{self} Create", primary_key || false, primary_key_value, returning: returning)`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/concerns/status/safe_reblog_insert.rb#L39)
  (shortened), in the same reblog override, which is kept close to Active Record's own
  `_insert_record`. Main still turns `pk` into `returning:`, so behavior is unchanged.
* 33 (c): `Mime::EXTENSION_LOOKUP is deprecated`, from Devise 5.0.4's
  [`Mime::EXTENSION_LOOKUP[format.to_s]`](https://github.com/heartcombo/devise/blob/9ea459de9aec5f1217ad738c58e0d23fb9f5beaa/app/controllers/devise_controller.rb#L99)
  through the sessions and confirmations controllers' `super`; fixed on Devise main in
  [6200069398](https://github.com/heartcombo/devise/commit/6200069398ff3c88a56fbaa8fa2fdec1ae53a20b), unreleased
  (5.0.4 is the latest release).
* 27: `` `verify_authenticity_token` is deprecated … use `skip_forgery_protection` `` (4f2ee07b8e, #56369), from
  [application_controller.rb#L34](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/controllers/application_controller.rb#L34)
  and [omniauth_callbacks_controller.rb#L5](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/controllers/auth/omniauth_callbacks_controller.rb#L5).
* 24 `exec_update is deprecated`, from [ranked_trend.rb#L18](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/concerns/ranked_trend.rb#L18);
  5 `exec_insert is deprecated`, from [account_summary.rb#L40](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/account_summary.rb#L40)
  and [cli/statuses.rb#L55](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/lib/mastodon/cli/statuses.rb#L55) and
  [#L140](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/lib/mastodon/cli/statuses.rb#L140).
* 12 `ActionController::InvalidAuthenticityToken has been deprecated`, from
  [error_responses.rb#L7](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/controllers/concerns/error_responses.rb#L7)
  and [api/web/base_controller.rb#L6](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/controllers/api/web/base_controller.rb#L6).
* 8 (one per process) `` `ActiveRecord::SchemaDumper.ignore_tables=` is deprecated ``, from
  [config/environment.rb#L9](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/config/environment.rb#L9).

Not seen: S1, SU1–SU5, R2-x, E1–E4, AR-1–AR-4, CW1, CW2, L2. No branch, patch or queue entry from this round.

### Earlier round (2026-11-04)

`a255155`, PostgreSQL 17 and Redis, flatware, rspec-rails pinned to 9fb6f4f0a3 (it also fixes `MailerExampleGroup`
for L1), Rails main `8b06b0eb98`. First main run: 2462 failures in 7984 examples. It found R1 and M1 and the same
(b) groups.

**R1 fix.** Restore `filter_proxies` as a deprecated private `:doc:` method with 8-1's body (all non-proxy IPs, in
order), warning through `ActionDispatch.deprecator`, to be removed in Rails 9.0, pointing to `first_non_proxy`
(Thomas's decision). The fast path is untouched. Test: IPv4, IPv6, a Regexp proxy and an all-proxy list against
8-1's results, plus `assert_deprecated`; it fails on main with `NoMethodError`. A differential script gives identical
output on 8-1-stable and on the branch, including an identical `IPAddr::InvalidAddressError` for a non-IP entry.
`request_test.rb` 200 runs green; RuboCop clean.
[patch](../../bench/upstream/app_suites/r1-remote-ip-filter-proxies-deprecation.patch),
[body](../../bench/upstream/app_suites/r1-body.md). Branch `thomasklemm/remote-ip-filter-proxies-deprecation` @
`54e07d2dba` on main `d09361d7cf` (Sol: open with nits, applied: concrete migration in the message,
`assert_deprecated(/filter_proxies/, …)`, neutral CHANGELOG, body wording); opened as #59630.

That round's 8-1 controls ran one after another on the default Redis (an earlier 8-1 run with `REDIS_URL` set had 63
environment failures, from redis_configuration_spec and feed specs), and its 9 view-spec `FrozenError`s came from the
older rspec-rails pin (fd5ffed45b freezes `ViewPaths._prefixes`; fixed in rspec-rails 570b2b0a79, #2915).

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
`where_test.rb` (empty, named and positional values, as arguments and in the array form) that fails on main with a
syntax error. `opts.empty?` rather than `blank?`: a whitespace-only condition gave invalid SQL on 8-1 too. Repro runs
each relation (8-1 and the fix: rows; main: syntax error). Relation, finder,
sanitize, relations and base tests 1508 runs green on SQLite, RuboCop clean; with the fix in the main tree, Chatwoot's
`filter_service_spec` passes 52/52.
[patch](../../bench/upstream/app_suites/cw1-where-empty-condition-binds.patch),
[body](../../bench/upstream/app_suites/cw1-body.md). Branch `thomasklemm/where-empty-condition-binds` @ `58a6ff8355`
on main `7a78da5a55`. Sol: open with nits; applied (array form in the test, "values" not binds, "on Rails main" in
the body, the repro executes the query); amended and force-pushed with lease from `4520f97971`.

**CW2 (d), restored: the private `Resolver#_find_all` hook is gone.** 9987431315 (#58279, "Resolve the single
best template without sorting the whole set") made [`Resolver#find_all`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/actionview/lib/action_view/template/resolver.rb#L68-L70)
call `find_templates` directly; 8-1's [`find_all` called `_find_all`](https://github.com/rails/rails/blob/6e091242176c322edc5a8907583c01b08b8a60bc/actionview/lib/action_view/template/resolver.rb#L61).
Chatwoot's [`EmailTemplates::DbResolverService`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/email_templates/db_resolver_service.rb#L28)
(a `Resolver` subclass, a pattern from panoramic) overrides `find_all` and calls `_find_all(name, prefix, partial,
details, key, locals)`, so every mailer that renders through it raises `NoMethodError`: 121 failures. Other callers:
[view_component-cache_digest](https://github.com/tildeio/view_component-cache_digest/blob/82da53b3b092a256841858ed6a482ae0bd80b385/lib/view_component/cache_digest/resolver.rb#L10)
(a `Resolver` subclass overriding `_find_all`, unreleased); [godmin 2.3.0](https://github.com/varvet/godmin/blob/b270f3736dde6022b71544c1692cafea42d4b35f/lib/godmin/resolver.rb#L22)
and [rbexy 2.0.0.rc7](https://github.com/patbenatar/rbexy/blob/681bc8813f9e8258b8c8ed4056030d0516d5d4ad/lib/rbexy/rails/component_template_resolver.rb#L13)
override it in `FileSystemResolver` subclasses; code search shows about 245 hits for `_find_all(name, prefix, partial`.
Repro: [resolver_find_all_hook.rb](../../bench/upstream/app_suites/resolver_find_all_hook.rb). On 8-1 both
overrides are used through `find` and `find_all`. On main the `Resolver` subclass raises `NotImplementedError` from
`find_templates`, and the `FileSystemResolver` subclass (the godmin/rbexy shape) silently finds nothing. Restore
(decided 2026-11-04 under the restore rule: unreleased, several callers, small): `Resolver#find_all` calls
`_find_all` again, its private default calls `find_templates`, and `Resolver#find` still goes through `find_all`, so
an override of either is honored. `FileSystemResolver` is unchanged: its own optimized `find`/`find_all` never reach
`_find_all`, so godmin's and rbexy's overrides stay uncovered; honoring them there would need a check on every
`find`, which would undo #58279's fast path, and the body says so. Tests in `view_paths_test.rb`: a subclass
overriding `_find_all` (fails on main with `NotImplementedError`), Chatwoot's shape (public `find_all` calling the
inherited `_find_all`, with `find_templates`; fails on main with `NoMethodError`) and one implementing only
`find_templates`, each rendering through a controller (`PathSet#find`) and `PathSet#find_all`; plus a resolver-level
check that `find` and `find_all` pass all six arguments to `_find_all` unchanged (`details`, `key` and `locals` by
identity; fails on main). Action View suite 3372 runs green, RuboCop clean. With the restore in the main tree and without the app shim, Chatwoot's 9
affected spec files run 132 examples with 3 failures, the confirmation mailer ones that fail on 8-1 too.
[patch](../../bench/upstream/app_suites/cw2-resolver-find-all-hook.patch),
[body](../../bench/upstream/app_suites/cw2-body.md). Branch `thomasklemm/resolver-find-all-hook` @ `0d3ef774bd` on
main `7a78da5a55`. Sol: open with nits; applied (Chatwoot-shape and argument tests, body wording: bypassed overrides
vs. Chatwoot's missing inherited method, methods named, the fast-path reason); amended and force-pushed with lease
from `e910df6df3`.

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

## Discourse

discourse/discourse `f81fcb4` (default branch `main`,
[`f81fcb4b44`](https://github.com/discourse/discourse/tree/f81fcb4b4425f4c3b8c94248771e8289daf6c376)), Ruby 4.0.9 on
both trees (Discourse asks for `~> 4.0.0`), PostgreSQL 15.19 with pgvector 0.8.1, Redis 7, libvips 8.18.7 (built
from source; Discourse's vips worker refuses older), jemalloc. Rails main `7a78da5a55` for every run and bisect
(still the head of the freshly fetched main); 8-1-stable `6e09124217`. Discourse's own core backend suite as its CI
runs it: `bin/turbo_rspec` without arguments (every `spec/**/*_spec.rb` except `spec/system`; plugin and theme specs
are separate CI jobs and not run), 1712 files and 35771 examples, 8 workers with their own database and Redis,
`--seed 4242`, 12–15 minutes wall per full run on 8 cores. Discourse's test env prints deprecations to stderr
(`config.active_support.deprecation = :stderr`), so it doesn't raise on them; main-only ones are read from the logs.

**Lockfiles.** Discourse names the seven Rails component gems at `~> 8.1.0` (8.1.4); both checkouts point them at a
`path:` Rails. The only other change, on both trees: 8-1-stable's actionview needs `rails-html-sanitizer >= 1.7.2`,
so Bundler moved rails-html-sanitizer 1.7.1 → 1.7.2, loofah 2.25.2 → 2.25.3 and nokogiri 1.19.4 → 1.19.7. The main
lock was resolved from the 8-1 lock and differs only in the Rails gems and what main itself requires (herb 0.11.1,
psych 5.5.0, ractor-dispatch 0.3.0, stringio 3.2.0). No main-only bump. rspec-rails stays at its locked 8.0.4.

**Main checkout only, app side:**
* [`foreign_key: %i[chatable_id chatable_type],`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/plugins/chat/lib/chat/category_extension.rb#L17)
  → `as: :chatable,` (DS1). Without it `db:migrate` (which loads the bundled plugins) can't seed the Uncategorized
  category; the unshimmed main run printed 35771 `F` before it was stopped, and a single file fails every example with
  `'allow uncategorized topics' cannot be enabled because the "Uncategorized" category no longer exists`.
* [`Arel::Table.new(table_name)`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/json_api_kit/adapters/active_record/pagination/numbered_rows.rb#L43)
  → `Arel::Table.new(name: table_name)`, applied after the full run, for the classification rerun only: 101 of the
  140 main-only failures (all of `json_api_kit`). This is the positional table name of
  [arel-table-positional](arel-table-positional.md), which already lists Discourse; covered by our open #59574.

Results: 8-1 53 F (`qunit_cli`, image tools, `safe_exec`, SMTP and other environment failures, all also on main).
Main 191 F. The 60 files with any failure, again (2240 examples): main 192 F (the extra one is `smtp_spec.rb:31`,
flaky on 8-1 too), 8-1 52 F and 51 F (`smtp_spec.rb:31` and `api/site_spec.rb:29` flaky). 140 failures are on both
main runs and on none of the three 8-1 runs; all are classified below.

**DS1 (a), held: a two-column `foreign_key` against a one-column primary key now raises on every use.** The bundled
chat plugin declares `has_many :category_channels` with
[`foreign_key: %i[chatable_id chatable_type]`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/plugins/chat/lib/chat/category_extension.rb#L17) where
`as: :chatable` was meant. On main any read of the association raises `ArgumentError: Key mappings must have the
same number of columns` ([key.rb#L397](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/key.rb#L397)), so with chat enabled every
`Category` save fails in
[`object.category_channels.exists?`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/plugins/chat/plugin.rb#L423), the serializer that `publish_category` runs,
and `db:migrate` can't seed. Bisected to 7249a66350 ("Resolve association reads through routes", #59120, the R2-1
and CW5 PR; its parent 7374e8551f passes). Repro: [fk_arity.rb](../../bench/upstream/app_suites/fk_arity.rb). On 8-1
the same declaration silently queries `chatable_id IS NULL AND chatable_type IS NULL` (so `has_chat_channels` is
always false and `dependent: :destroy` deletes nothing), `joins` builds `"categories".""`, and only `build` works.
Not in S1–SU5, R2-x, E1–E4 or AR-1–AR-4 (the PG census hit it as a setup note); no issue or PR found. Not built: 8-1's
behavior is wrong, so restoring it isn't a fix; the fix is Discourse's `as: :chatable`. At most Rails could name the
association in the error (`CompositePrimaryKeyMismatchError` is checked only for composite primary keys); the
coordinator decides whether that is worth a PR.

*DS1 outcome (2026-11-05): fix built for Discourse, PR not opened because it needs Thomas's CLA.* Still on
discourse/discourse main [`de34d8ac4f`](https://github.com/discourse/discourse/blob/de34d8ac4f9d31eea2d4c3e2de397f60e239ee88/plugins/chat/lib/chat/category_extension.rb#L14-L18);
no open PR (the repository has issues disabled; bug reports go to meta, code to PRs). The only caller is the category
serializer's `has_chat_channels` ([plugin.rb#L419–L423](https://github.com/discourse/discourse/blob/de34d8ac4f9d31eea2d4c3e2de397f60e239ee88/plugins/chat/plugin.rb#L419-L423)),
added with the association in e768f0c3cd ("Chat channel list in category UI"); nothing in the frontend reads it any
more (the chat tab's condition is `chat_enabled && category.id`), and other `category_channels` hits in the repo are
unrelated names. A category can have several channels (unique by name), so the fix is `as: :chatable`, matching
`has_one :category_channel`. Real results change nothing for callers on 8.1 except the value: the same two
`chat_channels` queries per serialized category, now `chatable_id = ? AND chatable_type = 'Category'` (indexed).
`dependent: :destroy` is dropped from the `has_many`: destroying a category with two channels, one with a message,
leaves one channel before and after the fix, but none if it were kept, so keeping it would newly hard-delete
channels with messages. (Pre-existing, not in this fix: `deletable_for_chat?` checks only the `has_one`'s channel, and
the other channels stay orphaned after a category delete.) Spec: `category_serializer#has_chat_channels` in
`plugins/chat/spec/plugin_spec.rb`, true for a category with a channel, false when only another category has one;
it fails without the fix on 8.1 (`expected true, got false`) and on main (`Key mappings …`). Results, chat plugin
specs without system specs (227 files, 3,220 examples, `--seed 4242`, LOAD_PLUGINS=1): fix 0 F on Rails 8.1.4.1 and
on main `bdb3d96012`; without the fix 1 F on 8.1 (the new spec) and 2,718 F on main. Core `*categor*_spec.rb` (48
files, 759 examples) with LOAD_PLUGINS=1: the same 25 failures with and without the fix on both Rails versions (they
fail only because plugins are loaded into core specs); main without the fix 696 F. With the fix, `db:migrate` on main
seeds a fresh database. stree and RuboCop clean. Skeptical reviewer: open with nits (applied: context name, who sees
the change, what the delete keeps); Sol not available on this orb. Commit
`e7ee7a18fb` on branch `thomasklemm/category-channels-association` (local only, not pushed; no fork created) on
main `de34d8ac4f`: [patch](../../bench/upstream/app_suites/ds1-category-channels-association.patch),
[body](../../bench/upstream/app_suites/ds1-body.md). Discourse's CONTRIBUTING requires the Discourse CLA
(cla-assistant checks every PR); thomasklemm has no earlier Discourse PR, so it is almost certainly unsigned. Next
step: Thomas signs at discourse.org/cla, then the branch is pushed to a fork and the PR opened with the body as is.

**DS2 (a): an attribute named `method` breaks every association read on its record.** `UserSecondFactor` has a
[`method` column](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/app/models/user_second_factor.rb#L56), and main's
[`sc.execute(owner.method(:read_attr), c, async: async)`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/associations/association.rb#L286)
calls the attribute reader instead of `Object#method` (`wrong number of arguments (given 1, expected 0)`): 8
failures in `second_factor_manager_spec`. Same commit, 7249a66350 (#59120). Already covered by open
[#59595](https://github.com/rails/rails/pull/59595) (anthonyfranco, `8f966cd64d`, a lambda instead of `method`);
with it applied to the main tree, `second_factor_manager_spec` passes 61/61. No branch of ours, no comment.

**DS3 (b)+(d): Active Record's PostgreSQL adapter no longer calls `exec`/`async_exec`/`exec_params`.** 53701519a1
("Preserve typed PG exceptions for server-initiated disconnects", #57057, matthewd; no CHANGELOG entry) switched to
`send_query`/`send_query_params`/`send_query_prepared` plus `get_result`. Discourse wraps the old methods:
[`Migration::SafeMigrate`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/migration/safe_migrate.rb#L97) (`alias_method :exec_migrator_unpatched, :exec`
and `:async_exec`), which blocks column drops and renames in migrations, now sees no SQL (5 failures in
`safe_migrate_spec`), and [`MethodProfiler`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/method_profiler.rb#L153)
(`%i[exec async_exec exec_prepared send_query_prepared query exec_params]`) records no SQL time (1 in
`request_tracker_spec`). Both stop working silently in production too. Repro:
[pg_send_query.rb](../../bench/upstream/app_suites/pg_send_query.rb): 8-1 `{async_exec: 1, exec_params: 1}`, main
`{send_query: 1, send_query_params: 1}` (main calls them at [database_statements.rb#L189–L213](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb#L189-L213)).
A deliberate change, but a CHANGELOG or upgrade-guide note would be the S1-style follow-up; not built.

*APM gems, checked at runtime* with [apm_pg_spans.rb](../../bench/upstream/app_suites/apm_pg_spans.rb) on both trees
(PostgreSQL 15, `prepared_statements: true`, warmed up, then four queries: `where` without binds, `create!`, a
prepared `find`, and `where` with binds inside `unprepared_statement`; 6 SQL statements in all, `create!` being
BEGIN, INSERT, COMMIT). Each gem at its latest release:

| Gem, integration | 8-1-stable | main |
|---|---|---|
| opentelemetry-instrumentation-pg 0.37.1 (sdk 1.13.1, in-memory exporter) | 6 SQL spans with `db.statement` | **0** |
| opentelemetry-instrumentation-active_record 0.13.0 | 5 model spans (`ApmPost query`, `ApmPost.create!`, `ApmPost#save!`), no attributes | the same 5, still no SQL |
| datadog 2.48.0, `pg` (`pg.exec.params`, `pg.async.exec`, `pg.exec.prepared`; test mode, traces dropped in `before_flush`) | 6 | **0** |
| datadog 2.48.0, `active_record` (`postgres.query`, from `sql.active_record`) | 6 | 6 |
| rack-mini-profiler 5.0.0, pg patch (`should_measure?` forced, `record_sql` counted) | 6, with SQL | **1**, the prepared `find`, recorded as the statement name `a1` instead of its SQL |

So OpenTelemetry users lose every SQL span on 8.2: the pg integration sees nothing and the Active Record integration
never had the SQL. Datadog users keep SQL spans if the `active_record` integration is on (it is under
`instrument :rails`), and lose only the pg-level spans (`pg.*`, with their own peer and timing tags).
rack-mini-profiler in a Rails app loses all of its SQL timings: when it patches pg it [turns its `sql.active_record`
subscription off](https://github.com/MiniProfiler/rack-mini-profiler/blob/d95511f0b5fe0ae6d326c6ce7071157d829b9447/lib/patches/sql_patches.rb#L34-L41). None of the three raises or warns.

Patched methods at the release tags: OpenTelemetry
[`EXEC_ISH_METHODS`](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/7f5283c99271aa4b9acd625b39429ba5d90ee285/instrumentation/pg/lib/opentelemetry/instrumentation/pg/constants.rb#L70-L78) (`exec`, `query`, `sync_exec`, `async_exec`, `exec_params`,
`async_exec_params`, `sync_exec_params`), [`PREPARE_ISH_METHODS`](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/7f5283c99271aa4b9acd625b39429ba5d90ee285/instrumentation/pg/lib/opentelemetry/instrumentation/pg/constants.rb#L83-L87) and
[`EXEC_PREPARED_ISH_METHODS`](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/7f5283c99271aa4b9acd625b39429ba5d90ee285/instrumentation/pg/lib/opentelemetry/instrumentation/pg/constants.rb#L92-L96), wrapped in [patches/connection.rb](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/7f5283c99271aa4b9acd625b39429ba5d90ee285/instrumentation/pg/lib/opentelemetry/instrumentation/pg/patches/connection.rb#L81-L82);
Datadog [`exec` … `sync_exec_prepared`](https://github.com/DataDog/dd-trace-rb/blob/f7009ebf10051fd6d0a034adf98050288f5517e6/lib/datadog/tracing/contrib/pg/instrumentation.rb#L23-L90) (the `exec`, `async_exec` and
`sync_exec` families with `_params` and `_prepared`); rack-mini-profiler
[`exec`, `async_exec`, `exec_prepared`, `send_query_prepared`, `prepare`, `exec_params`](https://github.com/MiniProfiler/rack-mini-profiler/blob/d95511f0b5fe0ae6d326c6ce7071157d829b9447/lib/patches/db/pg/alias_method.rb#L31-L39).
None wraps `send_query` or `send_query_params`, and only rack-mini-profiler wraps `send_query_prepared`. **Heads-up posted on #57057 with Thomas's approval on 2026-11-04** ([comment](https://github.com/rails/rails/pull/57057#issuecomment-6642150088)); issues for the gems wait for matthewd's answer.

**DS4 (d): `CSRFTokenVerifier` includes `RequestForgeryProtection` outside a controller.**
[`include ActionController::RequestForgeryProtection`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/csrf_token_verifier.rb#L9) then
[`verified_request?`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/csrf_token_verifier.rb#L22) (OmniAuth's request phase). Main's Sec-Fetch-Site check
(f5a1915f1d) instruments the token fallback, and `instrument_csrf_event` (daa6fae399, #56355) calls `action_name`,
which the plain class lacks: `NameError`, a 500 for a POST to `/auth/*` without `Sec-Fetch-Site` (1 failure in
`omniauth_callbacks_controller_spec`). Browsers send the header, so this is mostly non-browser clients.

**Known findings:**
* AR-4: [`permalinks.where!("url ILIKE :url OR external_url ILIKE :url", url: …)`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/app/models/permalink.rb#L92)
  leaves `:url` in the SQL, `PG::SyntaxError` at `:`: 3 failures in `admin/permalinks_controller_spec`
  (filter by URL).
* S1: test and development set [`x_sendfile_header = nil`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/config/environments/test.rb#L94), so main drops
  `Rack::Sendfile` there and [`middleware_order_spec`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/spec/integrity/middleware_order_spec.rb#L14) fails (1).
  Production sets `X-Accel-Redirect`, so the middleware stays, and
  [`request.env["sendfile.type"] = ""`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/app/controllers/static_controller.rb#L353) still disables it per request,
  as S1 says. Nothing in Discourse inserts relative to `Rack::Sendfile`.
* 5 (c): view specs fail with `FrozenError` on `["", "action_view/test_case/test"]` (`topics/show`, `list/list`):
  rspec-rails 8.0.4 and `_prefixes`, as in Mastodon (fixed in rspec-rails 570b2b0a79, unreleased).
* 10 (b): `precision: nil` timestamps cast to microseconds in memory (c162370c8f, #57845; as in Mastodon): the four
  `basic_reviewable_*_serializer_spec`s, `pending_post_serializer_spec` (2), `invite_spec` (2), `user_spec` (1),
  and `post_spec`'s "resets the topic's bumped_at", where `reset_bumped_at` runs on a stale `Topic`: on 8-1 the
  nanosecond `created_at` differs from the stored microseconds, so the save happens; on main the values are equal
  and nothing is saved.
* 2 (b): `Vary: Sec-Fetch-Site` on stylesheet and theme JavaScript responses that expect no `Vary` (as in Mastodon).
* 3 (b): `ActiveModel::Errors#inspect` now prints `#<ActiveModel::Errors:0x… @errors=[]>` (4c0776608a, #56865,
  `instance_variables_to_inspect`); `steps_inspector_spec` matches 8.1's `#<ActiveModel::Errors []>`.
* Not seen: S2, SU1–SU5, R2-x, E1–E4, AR-1–AR-3, L1, L2.

**Deprecations that only main emits** (warnings, counted in the full main run):
* 1246: `` `verify_authenticity_token` is deprecated … use `skip_forgery_protection` ``, from
  [`skip_before_action :verify_authenticity_token`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/app/controllers/users/omniauth_callbacks_controller.rb#L13)
  in 8 files (4f2ee07b8e, #56369).
* 18: `` Calling `protect_from_forgery` without specifying a strategy is deprecated ``, from
  [application_controller.rb#L23](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/app/controllers/application_controller.rb#L23) and
  [uploads_controller.rb#L16](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/app/controllers/uploads_controller.rb#L16).
* 10: `` `config.active_record.schema_cache_ignored_tables` is deprecated `` (use `schema_ignored_tables`), from
  [`ActiveRecord.schema_cache_ignored_tables.push(`](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/config/initializers/000-active_record.rb#L11).
* 10: `require_dependency is deprecated`, from Discourse's
  [compatibility wrapper](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/require_dependency_backward_compatibility.rb#L18).
* Both trees: 5 `` `distinct` is not supported by `update_all` `` from
  [uploads.rake#L623](https://github.com/discourse/discourse/blob/f81fcb4b4425f4c3b8c94248771e8289daf6c376/lib/tasks/uploads.rake#L623).

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

**PI2 (a), docs note queued: `disable_referential_integrity` on PostgreSQL 18.4+ holds about 16 times as many locks.**
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

*PI2 outcome (2026-11-05): an upgrade-guide note, queued first in the rails/rails queue as a correctness item.*
Code fixes considered first, in order, on main `bdb3d96012`, PostgreSQL 18.6, 151 tables, 300 foreign keys:
1. `truncate_tables` doesn't need the toggle on 18.4+: PostgreSQL's TRUNCATE checks foreign keys from `pg_constraint`
   without looking at enforcement (`heap_truncate_find_FKs`, REL_18_STABLE), and truncating only the referenced table
   raises the same `cannot truncate a table referenced in a foreign key constraint` with and without the toggle. It
   would cut `truncate_tables` from 3,760 locks to 1,356 (8-1: 1,514). But it doesn't fix PI2: one
   `insert_fixtures_set` for every table holds 3,310 locks on main (8-1: 927), and in
   [fk_fixture_locks.rb](../../bench/upstream/app_suites/fk_fixture_locks.rb) (8 processes, each empties its own
   database and loads five rows per table, 3 rounds) main fails 20, 23 and 24 of 24 times, 8-1 never, and main with
   the truncate change still 20 of 24 (the reviewer, removing truncation entirely: 13 of 24). Not built; recorded as
   a possible small exact cleanup.
2. Toggling only the constraints of the fixture tables: they must include every foreign key that references a table
   the fixtures delete from, which with the default `fixtures :all` is nearly all of them; no gain for the common
   case, more code. Not built.
3. Built: a section in "Upgrading from Rails 8.1 to Rails 8.2" (lock use, the error and HINT, raise
   `max_locks_per_transaction`, restart). With `max_locks_per_transaction` 128, 256 or 512, the repro passes 24/24
   and 48/48 with 8 and 16 workers. Where the locks come from, per `pg_locks`: 1,200 trigger-object locks (drop and
   recreate), 300 constraint locks, 3 per table and 1 per index. Side note: `check_all_foreign_keys_valid!` after
   fixture loading toggles every foreign key again in its own transaction (2,571 locks), which doesn't raise the
   peak. Also stale but not touched: the testing guide's TIP that only superusers can disable triggers.
No open rails/rails PR touches this code except #56764 (the < 18.4 trigger path; no overlap); #57378 has no review
discussion; the toggle's reasons are no superuser and revalidation on restore (#57377). Skeptical reviewer: open with
nits (applied: lock-table wording, "in a typical schema", intermittent, body leads with the change, links the
repro, says why no code change); Sol not available on this orb (/tmp/sol missing). Readability: docs only, mdl
clean; described out loud as "on 18.4+ fixture loading switches every foreign key off and on, which holds many
locks; parallel workers can run out; raise the setting". Branch
[`thomasklemm/upgrade-guide-postgresql-fk-locks`](https://github.com/thomasklemm/rails/tree/thomasklemm/upgrade-guide-postgresql-fk-locks)
@ `7e1817e6f2` on main `bdb3d96012`, merges cleanly with S1 and S2:
[patch](../../bench/upstream/app_suites/pi2-upgrade-guide-postgresql-fk-locks.patch),
[body](../../bench/upstream/app_suites/pi2-body.md).

**PI3 (a, performance), built: `Object#try` allocates an empty keyword Hash per call.** 2709a9f16d (kamipo, "Remove
`ruby2_keywords` usage", no CHANGELOG) turned `try(*args, &block)` with `ruby2_keywords` into
`try(*args, **kwargs, &block)`; a named keyword splat builds a Hash on every call. Found by allocation sites per
request: inertia-rails 3.23.0's prop resolver calls
[`prop.try(:rescue?)`](https://github.com/inertiajs/inertia-rails/blob/3ffd1f4c4f66cef89c481423af1fc25beb859de6/lib/inertia_rails/props_resolver.rb#L120),
[`prop.try(:deferred?)`](https://github.com/inertiajs/inertia-rails/blob/3ffd1f4c4f66cef89c481423af1fc25beb859de6/lib/inertia_rails/props_resolver.rb#L279)
(shortened) and [`prop.try(:once?)`](https://github.com/inertiajs/inertia-rails/blob/3ffd1f4c4f66cef89c481423af1fc25beb859de6/lib/inertia_rails/props_resolver.rb#L285)
per prop (v3.23.0), so its allocations rise by about 200 objects
per page on main. Repro: [try_kwargs.rb](../../bench/upstream/app_suites/try_kwargs.rb) (8-1 1 object per
`try(:name)`, main 2, fix 1; with keywords 3 on all three). Fix: an anonymous `**`, which avoids materializing the keyword Hash on Ruby 3.4+ when no keywords are passed (no
allocation improvement on 3.3); only the block form checks for keywords, through a private
`try_keywords_empty?(**)`, so behaviour is unchanged (`try(key: 1) { }` still raises `TypeError` on `try` and
`try!`), and the block-only form `try { }` keeps main's count. First version (`1e3539559d`) dropped that check and ran
the block; Sol asked for identical behaviour. Tests: behaviour, not allocation counts (Sol: brittle across VMs and
JITs): `try`/`try!` with `**{}`, a positional Hash, keywords, keywords with a block, and keywords alone with a block
(raises). They pass on 8-1, main and the fix on Ruby 4.0.9 and 3.3.13, and fail on the first version. Edge-case
differential (`try`/`try!` with no name, keywords only, blocks, Hash receivers): identical to main. Active Support
`core_ext` tests identical to main (only missing-`builder` LoadErrors in this bundle); RuboCop clean. Callgrind
instruction counts per `try(:deferred?)` call, not page speedups ([try_micro.rb](../../bench/upstream/app_suites/try_micro.rb):
200,000 warm-up calls, then (Ir at 200,000 − Ir at 0) / 200,000, Ruby 4.0.9, `--disable-yjit` and
`--yjit --yjit-call-threshold=1`, two runs each, identical): 3,362 → 2,835 interpreter, 2,293 → 1,894 YJIT; 2 → 1
objects. ZJIT micro on Ruby master not run (no master build on this orb).
[patch](../../bench/upstream/app_suites/pi3-try-without-kwargs-hash.patch),
[body](../../bench/upstream/app_suites/pi3-body.md). Branch `thomasklemm/try-without-kwargs-hash` @ `fb8a273532`
on main `7a78da5a55`. Sol: changes requested, applied.

**inertia-rails 3.23.0 on main:** nothing breaks and it emits no deprecation; its only main-specific effect is PI3.

**Deprecations that only main emits** (all from app code): `exec_insert`/`exec_update` (deprecated, to be removed in
9.0), `ActionController::InvalidAuthenticityToken` (renamed to `InvalidCrossOriginRequest`), and
`ActiveRecord::SchemaDumper.ignore_tables` (use `config.active_record.schema_ignored_tables`).

**Impact on four requests:** [private-inertia-app-82](../m0/private-inertia-app-82.md).

## Spree

spree/spree `b16f633` (default branch `main`,
[`b16f63338b`](https://github.com/spree/spree/tree/b16f63338bf0229794afeaa19db84cd7579972a0)), Ruby 4.0.9 on both
trees (Spree's CI uses `4.0`), PostgreSQL 16.15 (its CI uses `postgres:16`), libvips 8.14. Rails main `bdb3d96012`
(2026-11-05) for every run and bisect; 8-1-stable `6e09124217`. Spree main has no Ruby `admin` or `storefront` engine
any more (both are TypeScript packages under `packages/`), so the suites are the ones its backend CI runs: core (712
files), api (553), emails, dashboard, mcp, opentelemetry and the four providers (easypost, meilisearch, paypal,
stripe). None of them drives a browser. Each runs as in CI (`rake test_app`, then `parallel_rspec --group-by
filesize`), core and api with 4 processes per tree, the others with one, `--seed 4242`, both trees at the same time
against their own PostgreSQL cluster (core about 7 minutes wall, api about 3.5). No Meilisearch server ran, so
spree_meilisearch's integration spec skips itself, as in Spree's MySQL job. The dummy app comes from each tree's own
`rails new`, so main's calls `load_defaults 8.2`. Spree's test env raises only on Spree's own deprecations and prints
the rest to stderr, so main-only Rails deprecations are read from the logs.

**Bundles.** Spree commits no lockfile. Each of its 11 Gemfiles was resolved for 8-1 with
[`gem 'rails'`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/common_spree_dependencies.rb#L7)
pointed at a `path:` checkout; the main locks came from the 8-1 locks with `bundle lock --conservative --update` over
the Rails gems and differ only in Rails and what main itself requires (herb 0.11.1, marcel 1.2.1 → 2.1.0,
ractor-dispatch 0.3.0). [`spree_core.gemspec`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/spree_core.gemspec#L33)
caps `rails` at `< 8.2`; both checkouts have `< 8.3`. No gem bump in either tree. rspec-rails stays at 8.0.4: L1 doesn't
apply, since there are no feature specs and the mailer example group copies nothing when no
`config.action_mailer.default_url_options` is set.

**Main checkout only, app side** (each one otherwise stops boot or `db:migrate`, so every example):
* [`default: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/lib/spree/core/configuration.rb#L187)
  (shortened) → `72`. a18d246600 (#56041) moved the constant into `BCryptPassword`; covered by our open #59627, whose
  body already cites this line.
* 15 calls such as [`Arel::Table.new(:spree_policies)`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/db/migrate/20250902143122_fix_policies_store_association.rb#L5)
  and [`Arel::Table.new(translatable_class::Translation.table_name)`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/models/concerns/spree/translatable_resource_scopes.rb#L20)
  in 7 files (migrations, the translation scopes, the preferences JSON conversion) → `name:`. b1650993b0 (#57829);
  covered by our open #59574.

Both PRs together cover Spree: with #59574 (`79b81aa0bf`) and #59627 (`08be5191db`) cherry-picked onto main
`bdb3d96012` (both apply cleanly) and no Spree shim, the test app migrates all 210 tables and core gives the same 49
failures as main (all SP1), with 69 positional-name deprecation warnings.

Results (examples; failures in run 1 / run 2):

| Suite | Examples | 8-1-stable | main |
|---|---|---|---|
| core | 11236 | 0 / 0 | 49 / 49 |
| api | 6320 | 0 / 0 | 4 / 4 |
| emails, dashboard, mcp, opentelemetry | 202, 16, 62, 26 | 0 / 0 | 0 / 0 |
| easypost, meilisearch, paypal, stripe | 93, 100, 216, 315 | 0 / 0 | 0 / 0 |

The 13 files with a failure, again: 8-1 0 F, main the same 53 F, so nothing is flaky. With the SP1 shim below (main
checkout only) those files give 0 F in core and 3 F in api (SP2, SP3), so the freeze hides nothing else. Every
main-only failure is classified below; none is (a).

**SP1 (b), docs note built: `default_url_options` is a frozen `{}` unless configured.** Spree's
[`ActionMailer::Base.default_url_options[:host] = host_url`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/mailers/spree/base_mailer.rb#L182),
which [`mail` calls](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/mailers/spree/base_mailer.rb#L65)
for every email of a store with a storefront URL, raises `FrozenError: can't modify frozen Hash: {}`: 47 core mailer
failures, 2 subscriber specs (where the `FrozenError` inside `perform_enqueued_jobs` surfaces as a `NameError` for
`tagged_logger`, which RSpec example groups lack; that code is the same on 8-1) and 1 api test-email request.
Bisected to baa1ca5f2f (#58483, "Freeze the Controller `default_url_options`", no CHANGELOG entry; its parent
ef8d9606d9 passes), the L1 commit. The freeze sits in `ActionDispatch::Routing::UrlFor`'s `included` hook, so it covers
mailers, integration sessions and every class that includes the URL helpers, not only controllers. It hits only
the unconfigured default: options set through `config.action_mailer.default_url_options` or
`config.action_controller.default_url_options` stay mutable, and `routes.default_url_options` is untouched. The PR
says "it's possible but unlikely that applications where doing that in the wild"; its deprecating predecessor #58481
was closed as opened in the wrong repository, not rejected. Code search finds about 1,080 hits for
`ActionMailer::Base.default_url_options[:host] =`, among them
[rails_admin's spec_helper](https://github.com/railsadminteam/rails_admin/blob/2dfd05f15f983792c6b981c67a2d53e6b9419b85/spec/spec_helper.rb#L47)
(its dummy app sets no options), and rspec-rails 8.0.4 is L1. Repro:
[mailer_url_options.rb](../../bench/upstream/app_suites/mailer_url_options.rb) (8-1: the mail has the host; main:
`FrozenError`; assigning a new Hash works on both). Deliberate and merged by gmcgibbon, so no revert or deprecation
shim (the proxy in #58481 would be L2); the upgrade guide gets a note like S1 and S2. Heads-up with these numbers posted on #58483 with Thomas's OK (2026-11-05, [comment](https://github.com/rails/rails/pull/58483#issuecomment-6656481078)), so its author can choose a deprecation over the note; SP1 stays last in the queue until he answers.
[patch](../../bench/upstream/app_suites/sp1-upgrade-guide-frozen-default-url-options.patch),
[body](../../bench/upstream/app_suites/sp1-body.md). Branch `thomasklemm/upgrade-guide-frozen-default-url-options` @
`4fe014a8a7` on main `bdb3d96012`, docs only; each example in it was run on main. Separate reviewer: two should-fixes
(the scope is every URL-helper includer, not just controllers and mailers; show `config.action_controller` too) and
three nits (file labels, heading wording; the literal-Hash override was kept to match the controller guide), all but
the last applied. No Sol pass: `/tmp/sol` isn't available on this orb. Queued last, after S2 (docs, not correctness).
App-side fix: reassign (`default_url_options = default_url_options.merge(host: host_url)`), which is the main
checkout's classification shim.

**SP2 (b): new Canadian time zones.** [`Spree::Api::EnumTypes`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/api/lib/spree/api/enum_types.rb#L15)
compares the committed `enums.generated.ts` with a fresh render, which on main also lists `America/Edmonton` and
`America/Inuvik` (1 failure). 38c63e2013 (`Pacific Time (Canada)`, `Alberta`), 05bfe6e33c (`Manitoba`) and 4755ce99ea
(#59221, `Northwest Territories`) add `TimeZone::MAPPING` entries, each with a CHANGELOG entry.

**SP3 (c), known: mobility 1.3.2's `where!` override no longer sees `where`.** Spree's store API looks up translated
slugs with [`scope.i18n.find_by!(permalink: id)`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/api/app/controllers/spree/api/v3/store/categories_controller.rb#L31)
(and `slug` for products). On main the query reads `"spree_categories"."permalink"` instead of joining
`spree_category_translations` for the locale, so a French slug gives a 404 with no error (2 failures). Bisected to
c8490688d7 (kamipo's commit in #59634, AR-4: `where` now calls `_where!`); its parent e4852e04bb still joins. This is
the case already reported as [shioyama/mobility#692](https://github.com/shioyama/mobility/issues/692) (open, no reply);
kamipo called overriding private APIs "at the gem's own risk". Spree adds a large caller where it is silently wrong
rather than an error. With a `_where!` hook in mobility's `QueryExtension`
([mobility_where_shim.rb](../../bench/upstream/app_suites/mobility_where_shim.rb), the fix shape from #692), Spree's
two controller specs pass 85/85 on main. Record only.

**Deprecations that only main emits** (warnings, all suites, run 1):
* 192: `` The :preprocessed option is deprecated … Use the :process option `` (3d105fc346, #51951, "Active Storage
  immediate variants"), from `Spree::Media`'s
  [`preprocessed: true`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/models/spree/media.rb#L129) variants (and
  [#L151](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/models/spree/media.rb#L151)).
* 56: `exec_insert`/`exec_update`/`exec_delete is deprecated`, from Spree's
  [`connection.exec_insert(`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/db/migrate/20260809120001_consolidate_metadata_columns.rb#L24)
  migration, [`consolidate_metadata.rake`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/lib/tasks/consolidate_metadata.rake#L59)
  and two task specs.
* 32: `` :active_job was loaded before application initialization `` and the same for `:action_mailer`, the new load
  hook guard (e7b0236064, #56201; logged by default, `config.action_on_early_load_hook = :log`, no CHANGELOG entry).
  It comes from Spree's dummy-app template,
  [`ActionMailer::Base.default from: "spree@example.com"`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/lib/generators/spree/dummy/templates/rails/test.rb#L39)
  in `config/environments/test.rb`, so every Spree extension's test app logs it on each boot. Not on 8-1.
* With #59574: 69 positional `Arel::Table.new` warnings (above).

**Not pursued:**
* Spree pins [`json < 3`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/common_spree_dependencies.rb#L13)
  because "Active Support 8.1 still passes them positionally"; 8-1-stable and main both call `::JSON.parse(json,
  **options)` in `ActiveSupport::JSON.decode`, so this isn't main-only and wasn't chased.
* Main's "Missing host to link to!" error still says "set default_url_options[:host]"
  ([url.rb#L162](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/url.rb#L162)),
  which now reads as advice to do what SP1 makes raise. A possible one-line follow-up; not built (one concern per PR,
  and it is wording, not breakage).
* The Meilisearch integration spec (needs a server; Spree's MySQL job skips it too).

## Decidim

decidim/decidim `80149bb` (default branch `develop`,
[`80149bbba8`](https://github.com/decidim/decidim/tree/80149bbba83a3c477172d113d21e22115c901e54), 2026-11-05), Ruby 4.0.9
on both trees (Decidim's CI uses 3.4.7), PostgreSQL 15.19 with `ltree` and `pg_trgm` (its CI uses `postgres:14`), one
cluster per tree (the dummy apps of both trees use the same database names), libvips 8.14, Node 26.12.1 (CI 24.18.0).
Rails main `bdb3d96012` (2026-11-05, still the head of main at the end of the round) for every run and bisect;
8-1-stable `6e09124217` (v8.1.4.1). Decidim is a monorepo of engines; its CI generates one dummy app
(`bundle exec rake test_app`, a `rails new` through Decidim's generator, so main's calls `load_defaults 8.2`) and runs
each module's specs from the module directory. This round ran the non-system jobs of six modules as CI does
(`bundle exec parallel_test --type rspec --pattern spec/ --exclude-pattern spec/system`, core also without
`spec/tasks/decidim_tasks_shakapacker_spec.rb`, which CI runs alone because it rebuilds the packs), 4 processes per tree,
CI's environment (`CI=true`, the Bullet settings, `DECIDIM_BULLET_UNUSED_EAGER=true` for api), both trees at the same
time, seeds 4242 and 1717. Decidim's spec helper retries a failing example up to three times (rspec-retry), as in CI, so
an `F` failed three times. No other service: the HTML validator in CI serves only system specs. Decidim's test env prints
deprecations to stderr.

**Bundles.** Decidim locks Rails 8.1.4. Both checkouts point `rails` at a `path:` gem, and both need the same changes:
* every gemspec's [`required_ruby_version = "~> 3.4.0"`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/decidim-core.gemspec#L22) → `">= 3.4"` (28 gemspecs), and
  [`add_dependency "rails", "~> 8.1.0"`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/decidim-core.gemspec#L76) → `">= 8.1.0", "< 8.3"`;
* google-protobuf 4.33.5 → 4.36.2 (sass-embedded's dependency; 4.33.5 has no x86_64-linux build for Ruby 4.0, so
  Bundler finds no installable version);
* `gem "readline"` in the Gemfile's development/test group: readline is a bundled gem on Ruby 4.0, and without it
  [`require "readline"`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/spec/tasks/upgrade/decidim_tasks_sidekiq_spec.rb#L4)
  fails to load, which aborts that file's whole parallel group (a quarter of core on both trees; the first attempt
  was stopped and rerun with the gem).

The main lock was resolved from the 8-1 lock with `bundle lock --conservative --update` over the Rails gems and
differs only in Rails and what main itself requires (herb 0.11.1, marcel 1.2.1 → 2.1.0, psych 5.5.0,
ractor-dispatch 0.3.0, stringio 3.2.0). rspec-rails stays at its locked 8.0.4 for the runs (see DC3).

**Main checkout only, app side:** three positional `Arel::Table.new` calls → `name:`
([migration](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/db/migrate/20250416130426_rename_doorkeeper_scopes.rb#L15),
[attachment presenter](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/presenters/decidim/component_attachment_collection_presenter.rb#L65),
[`ForceAuthentication`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/controllers/concerns/decidim/force_authentication.rb#L44);
[patch](../../bench/upstream/readiness/round-app-suites/decidim-main-arel-shim.patch)). Without the first,
`db:migrate` stops in `RenameDoorkeeperScopes` and the test app can't be generated. b1650993b0 (#57829), covered by
our open #59574, as in Spree. Recipe for the readiness runner:
[round-app-suites-decidim.yml](../../bench/upstream/readiness/round-app-suites-decidim.yml).

Results (examples; failures in run 1 / run 2; core includes one passing scratch example of mine):

| Module | Examples | 8-1-stable | main |
|---|---|---|---|
| core | 5141 | 0 / 0 | 38 / 34 |
| admin | 997 | 0 / 0 | 11 / 11 |
| api | 73 | 0 / 0 | 0 / 0 |
| participatory_processes | 942 | 1 / 1 | 34 / 34 |
| proposals | 1897 | 2 / 2 | 122 / 105 |
| meetings | 1739 | 0 / 0 | 78 / 78 |

Every file with a failure, a third time, one process per tree and one tree at a time: 8-1 the same 3 failures, main
the same 262 as run 2. Run 1's 21 extra main failures (`global_engines_spec`, proposals' `component_spec`) are
`Address already in use` for Capybara's server on port 5100, which both trees' processes used at the same time, so
they are environment. The 3 failures on both trees are the searchable-resource specs of processes and proposals, whose
Faker text has an apostrophe that is stored as `&#39;`. That leaves 259 main-only failures, all classified below.
Two classification reruns of the failing files (main tree, run 1's file list): with rspec-rails main
`5072befe5d` (DC3) 196 still fail; with that, the `NavigationHelper` shim below and the DC1 fix, 29 do (26 main-only).

| Group | Failures (run 2) | Class | Commit | Status |
|---|---|---|---|---|
| DC2 `link_to` gone from cells and presenters (S2) | 167 | (b) + (c) cells-rails | 07f4b45e29 (#55410) | record; our S2 note queued |
| DC3 rspec-rails 8.0.4: controller specs render real templates; view specs' frozen `_prefixes` | 66 | (c) | 9987431315 (#58279) and the known `_prefixes` freeze | fixed on rspec-rails main, unreleased |
| DC4 `ActiveSupport::TimeZone` frozen, `allow(Time.zone).to receive(:now)` raises | 15 | (b) | 26e78a20db (#58067) | record |
| CW5 polymorphic type re-derived on save (factory) | 4 | (b?) | 4af9822fae (#59120) | known |
| CW3 `precision: nil` timestamps as microseconds | 4 | (b) | c162370c8f (#57845) | known |
| DC6 `message_serializer = :json` under `load_defaults 8.2` | 2 | (b) | bbb427c241 | record |
| DC5 `pluck` on a new owner's association reads the target | 1 | (b) | cdbac993d5 (#58372) | record |
| DC1 `FormTagHelper` can't reach `token_tag`/`method_tag` | 2 (inside DC3's 66) | **(a)** | 07f4b45e29 (#55410) | fix built, queued first |

**DC1 (a), fix built: `FormTagHelper` calls `token_tag` and `method_tag`, which 07f4b45e29 moved into
`NavigationHelper`.** [`extra_tags_for_form`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/form_tag_helper.rb#L1129-L1145)
renders the hidden `_method` and authenticity-token inputs with them, and `FormTagHelper`
[includes `UrlHelper`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/form_tag_helper.rb#L21)
but not `NavigationHelper`. Views include everything, but a class that includes only `FormTagHelper` or `FormHelper`
raises `NoMethodError` for every form that isn't a GET. cells-rails 0.1.6's `Cell::ViewModel`
[includes `FormHelper`](https://github.com/trailblazer/cells-rails/blob/77ff22ae8f94472cf477672ca2f0c86757d627d8/lib/cell/railtie.rb#L49),
so Decidim's report-user modal, [`decidim_form_for … method: :post`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/cells/decidim/report_user_button/flag_modal.erb#L2)
in a cell, raises `undefined method 'token_tag'`, so a visitor opening a user's profile page gets an error. In the runs it shows in
2 controller specs (`profiles_controller_spec`, `user_activities_controller_spec`) only because DC3 renders their
templates; scratch specs ([request](../../bench/upstream/app_suites/decidim_profile_request_spec.rb),
[cell](../../bench/upstream/app_suites/decidim_report_user_button_cell_spec.rb)) pass on 8-1 and fail on main. Bisected
with the Decidim spec and with [form_tag_token.rb](../../bench/upstream/app_suites/form_tag_token.rb): 07f4b45e29
fails, its parent passes. No issue or PR covers it; seanpdoyle's open #50312 ("Implement `button_to` in terms of
`form_tag`", last updated 2026-07-15) would move both methods into `FormTagHelper` as part of a larger change. Fix:
move the two private methods, unchanged, back into `UrlHelper`, which both helpers include and where they lived on
8.1. Described out loud: "`token_tag` and `method_tag` live in `UrlHelper`, which both `FormTagHelper` and
`NavigationHelper` include." Readability: L0 (a move, no method body changes, so flog and RuboCop metrics are
unchanged). Test: a class that includes only `FormTagHelper` renders a PATCH form with both hidden inputs; it fails on
main with `undefined method 'method_tag'`. Action View suite green (2956 + 251 + 177 runs), RuboCop clean. With the fix
both Decidim scratch specs pass on main. Skeptical reviewer (subagent): ship; it checked method resolution in
`ActionView::Base` and in standalone includers of each of the four helpers, `button_to` from `NavigationHelper` alone,
that the moved bodies are main's, not 8.1's, and that no other private method moved by 07f4b45e29 is called from
outside `NavigationHelper`; one wording nit in the commit message, applied. No Sol pass on this orb.
[patch](../../bench/upstream/app_suites/dc1-form-tag-helper-token-tag.patch), [body](../../bench/upstream/app_suites/dc1-body.md).
Branch [`thomasklemm/form-tag-helper-token-tag`](https://github.com/thomasklemm/rails/tree/thomasklemm/form-tag-helper-token-tag)
@ `ab0a99e41a` on main `bdb3d96012`, pushed to the fork, not opened; first in `bench/upstream/pr-queue`.

**DC2 (b)+(c): cells lose `link_to`, and Decidim's fallback escapes the cell's HTML instead of raising.** S2 again
(07f4b45e29 moved `link_to`, `button_to` and `current_page?` into `NavigationHelper`, no deprecation), but with a
silent failure. cells-rails includes `FormHelper` into every cell (above), which brought `link_to` on 8.1 and doesn't on
main ([form_helper_link_to.rb](../../bench/upstream/app_suites/form_helper_link_to.rb)). Decidim's `ViewModel` has
[`delegate_missing_to :view_context`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/lib/decidim/view_model.rb#L21),
so a cell's `link_to … do` block such as [`card_g/show.erb`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/cells/decidim/card_g/show.erb#L1)
now runs the controller's `link_to`, whose `capture` escapes the plain String that cells-erb's `capture` returns: every
card renders its whole inner HTML as text (`&lt;div class="card__grid-img"&gt;…`), with no error. Twelve presenters,
events and renderers include only `UrlHelper` and raise `undefined method 'link_to'`, for example
[`UserPresenter`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/presenters/decidim/user_presenter.rb#L8)
(every mention) and [`PublishProposalEvent`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-proposals/app/events/decidim/proposals/publish_proposal_event.rb#L18).
With `include ActionView::Helpers::NavigationHelper` next to those twelve includes and in `Cell::ViewModel` (main
checkout only, [patch](../../bench/upstream/readiness/round-app-suites/decidim-main-navigation-helper-shim.patch),
[initializer](../../bench/upstream/readiness/round-app-suites/decidim-cells-navigation-helper-initializer.rb)) all 167
pass. The fix belongs in cells-rails (include `NavigationHelper` where it is defined; last release 0.1.6, 2024-11-13)
and in Decidim's includes; recorded, not reported. For the coordinator: S2 was decided as a docs-only note when its
callers raised `NoMethodError`; with cells-rails the same move silently changes rendered HTML, which may be worth
reconsidering under the restore rule (`link_to` in `UrlHelper` was public API). A shim inside Rails can't simply make
`UrlHelper` include `NavigationHelper`, because `NavigationHelper` includes `UrlHelper` (a cyclic include).

**DC3 (c): rspec-rails 8.0.4 no longer blanks templates in controller specs.** 9987431315 (#58279, the CW2 commit)
makes [`PathSet#find`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/path_set.rb#L43-L46)
ask each resolver for one template with `find`. rspec-rails 8.0.4's `ResolverDecorator`
[forwards every call](https://github.com/rspec/rspec-rails/blob/222fb5518a7c9c1b9a0a06d950c2dfa2d3fa69e9/lib/rspec/rails/view_rendering.rb#L87)
and blanks only Arrays of templates, so the single template comes back unblanked and controller specs without
`render_views` render the real views. 56 controller-spec failures follow (missing route helpers, `nil` versions, view-only
settings; bisected with `errors_controller_spec` and `amendments_controller_spec`: 9987431315 fails, its parent 91e626db50
passes). rspec-rails fixed it on main in 2d5985ea6e ("Handle templates returned directly by resolvers", 2026-10-16),
unreleased; Mastodon's pinned ref `570b2b0a79` predates it. The other 10 are admin view specs with
`FrozenError` on `["", "action_view/test_case/test"]` (the known `_prefixes` case from Mastodon and Discourse). All 66
pass with rspec-rails main `5072befe5d`; that also hides DC1's two examples, so the plain runs keep 8.0.4. The case is
new to this record but is rspec-rails' release gap again (L1); nothing to report.

**DC4 (b): every `ActiveSupport::TimeZone` is frozen at creation.** 26e78a20db ("Make AS::TimeZone shareable",
#58067, merged by gmcgibbon on 2026-07-29; no CHANGELOG entry) calls `ActiveSupport::Ractors.make_shareable(self)` in
`TimeZone#initialize` unconditionally, not through the `try_make_shareable` variant that the Ractor option gates.
rspec-mocks can't stub a frozen object, so
[`allow(Time.zone).to receive(:now)`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-participatory_processes/spec/jobs/decidim/participatory_processes/change_active_step_job_spec.rb#L29)
raises `ArgumentError: Cannot proxy frozen objects` (15 failures in `change_active_step_job_spec`; 26e78a20db fails,
its parent passes). GitHub code search counts 206 files with `"allow(Time.zone).to receive"` (GitLab among them) and 32
with `expect(…)`. Rails' own test needed a `.dup` in the same commit. Repro:
[time_zone_frozen.rb](../../bench/upstream/app_suites/time_zone_frozen.rb). Deliberate; a CHANGELOG or upgrade-guide line
("stub `Time.now` or use `travel_to`") would be the S1-style follow-up; not built.

**DC5 (b): `pluck` on a new owner's association reads the built records.** cdbac993d5 (#58372, CHANGELOG "Fix `pluck`
ignoring records assigned to a new record's association"; its message says "we have swapped one breaking change for
another"). Decidim's [`Coauthorable#authors`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/lib/decidim/coauthorable.rb#L72)
plucks the coauthorships, and [`add_coauthor`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/lib/decidim/coauthorable.rb#L155)
on an unsaved record builds a coauthorship and then appends the author to `authors`. On 8.1 the pluck saw nothing,
so the author was listed once; on main it is listed twice (`proposal_creator_spec`, 1 failure; the commit fails, its
parent passes). Repro: [pluck_new_owner.rb](../../bench/upstream/app_suites/pluck_new_owner.rb) (8-1 `[]`, main
`["built"]`). The Decidim side would stop appending when the pluck already sees the author; recorded.

**DC6 (b): `load_defaults 8.2` sets `active_support.message_serializer = :json`.** bbb427c241. Decidim's
`AttributeEncryptor` spec decrypts a [fixed value](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/spec/lib/attribute_encryptor_spec.rb#L74)
that was encrypted with Marshal, and main's dummy app rejects it with `Unsupported serialization format` (2 failures;
bbb427c241 fails, its parent passes). Apps that move to 8.2 defaults with Marshal-encrypted data hit the same; the new
framework defaults cover it.

**Known findings:** CW5 (factory `searchable_resource` assigns [`resource`, then `resource_type`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/lib/decidim/core/test/factories.rb#L926-L928);
main saves the base class `Decidim::UserBaseEntity` for a user, so `search_spec` finds no users; 4 failures; 4af9822fae
fails, its parent passes; Decidim's own indexing writes `resource_type` without assigning the record, so production
is unaffected). CW3 (proposals' `answered_at` is `precision: nil` in 8-1's schema dump and reported as precision 6 on
main, so `update!(answered_at: Time.current)` keeps microseconds; the two serializer specs, 4 failures). #59574's
positional `Arel::Table.new` (above). Not seen: S1, SP1, L1, L2, R1, M1, DS1–DS4, AR-4, CW1, CW2, SU1–SU5, E1–E4.

**Deprecations that only main emits** (warnings, all six modules, run 1):
* 144: `require_dependency is deprecated` (57a5577169), from Decidim's engines loading mailer previews
  ([core engine.rb#L718](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/lib/decidim/core/engine.rb#L718),
  [initiatives engine.rb#L181](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-initiatives/lib/decidim/initiatives/engine.rb#L181)) on every boot.
* 48: `ActionController::InvalidAuthenticityToken has been deprecated … Use ActionController::InvalidCrossOriginRequest`
  (46eecbfd1a), from `rescue_from ActionController::InvalidAuthenticityToken` in the
  [Devise sessions controller](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/controllers/decidim/devise/sessions_controller.rb#L12)
  and its [system twin](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-system/app/controllers/decidim/system/devise/sessions_controller.rb#L13).
* 43: `` `verify_authenticity_token` is deprecated … use `skip_forgery_protection` `` (4f2ee07b8e, as in Redmine,
  Forem and Discourse), from `skip_before_action :verify_authenticity_token` in four controllers, such as
  [`ErrorsController`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/controllers/decidim/errors_controller.rb#L5).
* 3: `Mime::EXTENSION_LOOKUP is deprecated` (f6c709e747), from devise 5.0.4's
  [`navigational_formats`](https://github.com/heartcombo/devise/blob/9ea459de9aec5f1217ad738c58e0d23fb9f5beaa/app/controllers/devise_controller.rb#L99);
  fixed on devise main (heartcombo/devise#5856), unreleased.

**Not pursued:**
* A cells-rails or Decidim PR for DC2, a Decidim change for DC5, an rspec-rails release request for DC3: findings
  in gems and apps are recorded, not reported.
* An upgrade-guide note for DC4 and the rspec-mocks pattern: deliberate, test-only, not built (one concern per PR).
* System specs (they need Chrome and the validator service) and the other 19 modules.

## Zammad

zammad/zammad `64e70ff` (default branch `develop`,
[`64e70ff159`](https://github.com/zammad/zammad/tree/64e70ff1590358310c463637018497413cc4aabf), 2026-11-05), Ruby 4.0.9
on both trees (Zammad pins 3.4.12; the Gemfile's `ruby` line is changed in both), PostgreSQL 18.6 (its GitHub CI uses
`postgres:18`), Redis 7.0.15, memcached 1.6.18, jemalloc. Rails main `bdb3d96012` (2026-11-05, still the head of main
at the end of the round) for every run, bisect and the fix; 8-1-stable `6e09124217` (v8.1.4.1). Zammad's backend CI
job as it runs it: `bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb" -t ~searchindex -t ~integration`,
plus `-t ~required_envs` as in its GitHub CI (live services), 20,323 examples in 1,641 files, `CI_SKIP_ASSETS_PRECOMPILE`
and `CI_SKIP_DB_RESET` as in CI, `REDIS_URL` and `MEMCACHE_SERVERS` set (CI picks each at random). There is no
minitest suite left (`test/` only holds data). **Elasticsearch skipped:** the 45 `searchindex` files are excluded by
CI's own rspec job too and run in separate Elasticsearch jobs. Seeds 4242 and 1717.

**Runs.** Zammad's CI slicing (`--require ./spec/rspec_extensions.rb` with `CI_NODE_TOTAL=5`, `CI_NODE_INDEX`), 5
processes per tree, each with its own copy of the seeded test database, Redis database and memcached, one tree at a
time: about 13 minutes wall per run on 8 cores. Each rspec process grows to 2–3 GB (with glibc malloc past 3 GB in 800
examples), so the first attempt, 12 processes at once, hit the orb's 16 GB limit; jemalloc and 5 slices fixed that.
Running both trees at the same time also breaks `user_agent_spec` (22 failures, Puma on fixed ports 3010/3011), so the
recorded runs don't. Zammad's test env prints deprecations, and
[`deprecation_toolkit.rb`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/spec/support/deprecation_toolkit.rb#L11-L16)
fails an example on any deprecation whose first stack frame isn't under `/ruby/` or `/gems/`; with Rails checked out
at `/home/user/w/rails-main` that made 213 main examples fail on `verify_authenticity_token`'s deprecation, so both
Rails trees live under `/home/user/w/gems/` (the first main run was discarded and rerun).

**Bundles.** Zammad names `gem 'rails', '~> 8.1.0'` (8.1.4.1); both checkouts point it at a `path:` Rails, and both
add `gem 'readline'` (0.0.4): Ruby 4.0 no longer ships readline, and pry-remote requires it at boot. Otherwise the 8-1
lock has Zammad's locked versions. The main lock was resolved from the 8-1 lock with `bundle lock --conservative
--update` over the Rails gems and differs only in Rails and what main itself requires (herb 0.11.1, marcel 1.2.1 →
2.1.0, psych 5.5.0, ractor-dispatch 0.3.0). rspec-rails stays at its locked 8.0.4. No app shim: main boots, migrates
and seeds as it is. Setup per tree: `bundle exec rake zammad:db:init`, then one `createdb -T` copy per slice. Recipe for
the readiness runner (unchecked, one process): [round-zammad.yml](../../bench/upstream/readiness/round-zammad.yml).

Results: 8-1 7 F (seed 4242) and 10 F (1717); main 2,520 F and 2,524 F (2,518 the same), in 219 files. Those files
twice more, 3 processes per tree: 8-1 7 F and 8 F; main with ZM1's fix branch and its deprecation allowed in Zammad
([patch](../../bench/upstream/app_suites/zm1-zammad-allow-deprecation.patch)) 22 F and 43 F, of which 22 are the port
clash above (that rerun ran both trees at once). The failures on both trees are environment or order: three knowledge
base sort specs (the cluster's C collation), `user_agent_spec`'s pinned-IP check (`TCPSocket.open` with
`open_timeout:`), `twilio_spec` (`Twilio` not loaded), `migration_helper_spec`, `collection_update_job_spec`, a
knowledge base notification example and `store/provider/file_spec`, each on some 8-1 run. 2,498 failures in 202 files
are ZM1 on both main runs; the 15 left are main-only on both seeds and classified below. Without the fix, Zammad's own
one-line shim ([patch](../../bench/upstream/app_suites/zm1-zammad-shim.patch), `table[:login]`) gives the same 15 plus
the environment ones (20 in 216 files).

| Group | Failures | Class | Commit | Status |
|---|---|---|---|---|
| ZM1 `build_bind_attribute` rejects a column name | 2,498 | (d), restore | 4f1ff11da3 (#58479) | fix built, queued |
| ZM2 rspec-rails 8.0.4 channel specs: no connection class | 4 | (c) | Action Cable server adapterization (#50979) | fixed on rspec-rails main, unreleased |
| ZM3 `allow_request_origin?` moved to the server | 4 | (d) | 1f73f78b3a (#50979) | record only |
| CW4 GET `as: :json` sends params in the query string | 4 | (b) | 3c99a378ad (#57140) | CHANGELOG |
| ZM4 retries no longer mutate the deserialized job data | 1 | (b) | f5097cf946 (#58975) | CHANGELOG |
| ZM5 Active Job log subscriber hooks renamed | 1 | (d) | dbc3a5d6d5 (#55900) | record only |
| `exec_update` deprecated, raised by Zammad's toolkit | 1 | (b) | 3fc2ca0725 (#55897) | CHANGELOG |

**ZM1 (d), restore built: `PredicateBuilder#build_bind_attribute` no longer takes a column name.** 4f1ff11da3
(#58479, matthewd, the M1 commit) changed it from `(column_name, value)` to
[`(attribute, value)`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/relation/predicate_builder.rb#L128-L131).
Zammad's [`User.by_login_case_sensitive`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/app/models/user.rb#L88)
(added on 2026-10-21 in f0d1ecd36, "Lookups of users by login scan the users table instead of using its index") passes
`:login` and wraps the bind in `LOWER()`. It is reached by `User.identify`, so every authenticated request, email
import and login lookup raises `NoMethodError: undefined method 'type_caster' for an instance of Symbol`, and Zammad's
error handler turns them into 500s: 2,498 failures. M1 was record-only because Mastodon was the one caller found;
there are more now: [authlogic 6.6.1's `FindWithCase#sensitive_comparison`](https://github.com/binarylogic/authlogic/blob/9b8cfe8b14b9cc172d45c570f2823298b0bdf0ed/lib/authlogic/acts_as_authentic/queries/find_with_case.rb#L54)
(a released gem; the case-sensitive login lookup), Mastodon's
[`Status::SafeReblogInsert`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/concerns/status/safe_reblog_insert.rb#L64)
and DocuSeal's [`Api::SubmittersController`](https://github.com/docusealco/docuseal/blob/6c416dd76e10a44a6440a77d144819199687a06b/app/controllers/api/submitters_controller.rb#L195)
(master). Under the restore rule (unreleased, several real callers, small) this is now a restore, decided here: accept a
String or Symbol again, warn through `ActiveRecord.deprecator` (to be removed in 9.0, pointing at
`arel_table[:name]`), and build the bind from `table.arel_table[name]`. Said out loud: "if the caller passed a column
name, warn and build the bind from the table's Arel attribute for that column; otherwise build it from the attribute as
main does." The bind is a plain `QueryAttribute` even for a type with query predicate expressions, because these
callers build the left-hand side themselves; a `ComparisonValue` would give asymmetric SQL such as `email = LOWER(?)`.
The only difference from 8-1 is the bind's name: the resolved column name as a String (also for an `alias_attribute`),
which is what `where` gives. No issue or PR found (`build_bind_attribute` in rails/rails PRs and issues, authlogic
issues). Repro: [bind_attribute_column_name.rb](../../bench/upstream/app_suites/bind_attribute_column_name.rb), the
three call shapes: 8-1 finds the row with each, main raises `NoMethodError` in each, the fix finds the row with each
and warns 3 times. Test in `predicate_builder_test.rb`: a Symbol and a String give a typed bind that finds the row and
warn; a `LowerString` column still gets a plain bind. It fails on main with the `NoMethodError`. Predicate builder
tests 61 runs green; Active Record on SQLite 10,290 runs, 0 failures, 4 errors (`SqliteStructureDumpTest` and
`SqliteStructureLoadTest` need the `sqlite3` CLI, which the orb lacks); RuboCop clean. Cost on the common path,
Callgrind instructions per `PredicateBuilder#build` call with an Arel attribute (100,000 warm calls, Ruby 4.0.9):
interpreter 25,426 → 26,008 (A/A under 10 Ir); YJIT 12,917–14,060 (three base runs) → 14,301–14,901, within twice the
base spread. A guard clause into a private helper wasn't cheaper (YJIT 15,182) and `unless is_a?(Arel::Attributes::Attribute)`
saved about 300 interpreter Ir but would treat any other duck-typed attribute as a column name, so the exact
String/Symbol check stays. flog for the method 5.7 → 18.0, ABC 5.2 → 14.4, cyclomatic 2 → 4: the deprecation branch.
Skeptical reviewer (subagent): open with nits; applied (CHANGELOG says "Deprecate passing a column name" instead of
"again", the message example is valid Ruby for any name, the plain-bind assertion). Sol not available on this orb.
With the fix in the main tree and no Zammad shim, Zammad's 219 failing files fail only on the 15 below, once the new
warning is allowed (otherwise Zammad's deprecation toolkit fails 448 examples on it, which is the intended signal).
[patch](../../bench/upstream/app_suites/zm1-bind-attribute-column-name.patch),
[body](../../bench/upstream/app_suites/zm1-body.md). Branch
[`thomasklemm/bind-attribute-column-name`](https://github.com/thomasklemm/rails/tree/thomasklemm/bind-attribute-column-name)
@ `72d0b21869` on main `bdb3d96012` (first version `a2a89ee17b`, before the review nits). App-side fix for Zammad:
pass `table[:login]`.

**ZM2 (c): rspec-rails 8.0.4's channel example group can't find the connection class.** `graphql_channel_spec`'s
`stub_connection` raises `Described class is not a connection class` (4): rspec-rails 8.0.4 reads
`_connection_class || described_class`, and since the Action Cable server adapterization (#50979, merged in ad9c346c99)
the default comes through `connection_class`. Fixed on rspec-rails main in
[29cad6c9f5](https://github.com/rspec/rspec-rails/commit/29cad6c9f508affc84ef70a464bb425e84922e37) ("Handle
connection_class changes in Rails 8.2", 2026-08-19, unreleased); with rspec-rails `570b2b0a79` (the L1 ref, which has
it) the spec passes. Another reason rspec-rails needs a release before 8.2 (L1, DC3).

**ZM3 (d), record only: `connection_origin_configuration_spec` calls the connection's private
`allow_request_origin?`.** [`connection.send(:allow_request_origin?)`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/spec/channels/application_cable/connection_origin_configuration_spec.rb#L6)
(4); 1f73f78b3a ("Move #allow_request_origin? to Server::Base", #50979) moved it to `ActionCable::Server::Base`. The
spec tests Zammad's allowed-origins initializer through a private method; whether the origins still apply in a real
WebSocket handshake on main was not checked.

**CW4 (b), as in Chatwoot: `get …, params: { data: {} }, as: :json` sends the params in the query string.**
`long_polling_spec` (4): the empty `data` Hash disappears from the query string, so
[`params['data'].permit!`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/app/controllers/long_polling_controller.rb#L18)
raises on nil. 8-1's integration session sent such a GET as a JSON POST with `X-Http-Method-Override`.

**ZM4 (b): retries no longer change the job data a job was deserialized from.** f5097cf946 (#58975, CHANGELOG)
dups `exception_executions` in `deserialize`.
[`trigger_ai_agent_job_spec`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/spec/jobs/trigger_ai_agent_job_spec.rb#L92-L103)
passes the same `job.serialize` Hash to `ActiveJob::Base.execute` five times and expects the fifth to give up; it relied
on the retries counting up in that shared Hash. With the `.dup` reverted in the main tree the spec passes (1). The
spec's assumption, not Zammad's retry handling, is what changed: real retries go through a fresh serialization.

**ZM5 (d), record only: Zammad's `ActiveJob::LogSubscriber` override no longer runs.** Zammad
[prepends `enqueue`/`enqueue_at`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/config/initializers/active_job_log_subscriber.rb#L26-L32)
to the `:nodoc:` subscriber to log "Won't enqueue …" when its `HasActiveJobLock` drops a job. dbc3a5d6d5 ("Convert log
subscriber in Active Job to consume structured events", #55900, like 308594b580 in Chatwoot's record) renamed the
handlers to `enqueued`/`enqueued_at` and passes a payload without the job object, so the override is silently
skipped and the line is gone (1, `application_job_spec`). Its `info` → `debug` override still works (the info-level
specs pass). A Zammad-side change; the job's lock key isn't in the new payload.

**`exec_update` (b):** [`connection.exec_update(`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/db/migrate/20260206133553_issue5254_user_organization_uniqueness.rb#L38)
in a migration (3fc2ca0725, deprecated for 9.0); Zammad's deprecation toolkit fails its spec (1).

**Deprecations that only main emits** (warnings, main run 1; 8-1 prints none):
* 752: `` `verify_authenticity_token` is deprecated … use `skip_forgery_protection` `` (4f2ee07b8e), from
  [`skip_before_action :verify_authenticity_token, raise: false`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/app/controllers/application_controller/prevents_csrf.rb#L11).
* 70 (c): `auto_populated? is deprecated … (use auto_populated_on_insert? instead)` (de7b8c8eed), from
  activerecord-import 3.0.1's
  [`column.respond_to?(:auto_populated?) ? column.auto_populated? : column.default_function`](https://github.com/zdennis/activerecord-import/blob/ed0cdadf80c84d73314a4788cc4db3bd14e27127/lib/activerecord-import/import.rb#L1173);
  unchanged on its default branch.
* 55: `require_dependency is deprecated`, from 10 rake files such as
  [max_connections.rake#L3](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/lib/tasks/zammad/db/max_connections.rake#L3),
  once per boot.
* 9 (c): `The built-in delayed_job adapter is deprecated … upgrade delayed_job gem to version 4.2.0` (8f8964c1e2):
  Zammad locks its fork [zammad-deps/delayed_job](https://github.com/zammad-deps/delayed_job/tree/0f1644ccc6911f7fc0950aec6a63440b333a5074)
  at 4.1.13 (branch `threadsafe`).
* 2: `exec_update` (above).

**Not pursued:**
* Elasticsearch specs (45 files) and `integration`/`required_envs` specs (live services), as CI's main rspec job.
* An rspec-rails release request for ZM2: the DECISIONS rule waits for a Rails 8.2 beta.
* Reporting ZM3, ZM5, the `require_dependency` and `verify_authenticity_token` calls or the `exec_update` migration
  to Zammad, or the `auto_populated?` call to activerecord-import: findings are recorded, not reported.
* A narrower ZM1 restore (Symbol only, or only in `QueryPredicates`-free tables): every caller found passes a String or
  a Symbol, and the type lookup is the same either way.
