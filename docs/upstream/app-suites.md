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
| Solidus `ed00fc8` | core and api rspec, SQLite | see below | see below | |

## Findings

**S1 (b): `Rack::Sendfile` only added when `x_sendfile_header` is configured.** b37aeee32f (#56915, CHANGELOG
entry). Redmine's `config.middleware.insert_before Rack::Sendfile, Rack::ContentLength` raises `No such middleware to
insert before: Rack::Sendfile` on boot. Redmine's `test_download_should_set_sendfile_header` stubs
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
`ActionView::Helpers::UrlHelper` loses `link_to`. Redmine's `Redmine::Hook::ViewListener` does, so 3
`Redmine::Hook::ManagerTest` tests fail with `undefined method 'link_to'`, and so does every plugin hook that builds
links. GitHub code search shows about 2.6k hits for `include ActionView::Helpers::UrlHelper`. Swapping the include
works on main ([check](../../bench/upstream/app_suites/navhelper.rb)), but `NavigationHelper` doesn't exist on 8-1.
No compat code; docs-only note:
[patch](../../bench/upstream/app_suites/s2-upgrade-guide-navigation-helper.patch),
[body](../../bench/upstream/app_suites/s2-body.md). Branch `thomasklemm/upgrade-guide-navigation-helper` @
`fcf2a1957a` on main `8b06b0eb98`; S1 and S2 merge with each other and with main `fa03095c6f` cleanly.

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

## Not run yet

Mastodon, Forem/Chatwoot, Maybe, once-campfire: see later sections.
