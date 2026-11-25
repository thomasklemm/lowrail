# Rails-main boot check 2026-11-25

Rails main [`f785381cca`](https://github.com/rails/rails/commit/f785381cca8621772cba659ff93f825eb7f99942) against v8.1.4.1 [`3f290b759c`](https://github.com/rails/rails/commit/3f290b759c8e2ffe7c257951b1255740751355e4), ruby 4.0.9, 20 census apps, 3 minutes. Previous run: none. Made by `script/rails-main-boot` ([how it works](rails-main-boot.md)); raw data in [`bench/upstream/rails-main-boot/2026-11-25/`](../../bench/upstream/rails-main-boot/2026-11-25/).

## New breaks

| # | Check | Error | Apps | First app frame | Range | Introduced by | Ownership (search hits) |
|---:|---|---|---|---|---|---|---|
| 1 | eager_load | `LoadError \| cannot load such file -- active_job` | discourse | `app/mailers/admin_confirmation_mailer.rb:3:in '<main>'` | [`8ae3d84277`](https://github.com/rails/rails/commit/8ae3d84277889ec1c718844550e3aa09ce42a58c)…[`f785381cca`](https://github.com/rails/rails/commit/f785381cca8621772cba659ff93f825eb7f99942) | [#59820](https://github.com/rails/rails/pull/59820) [`ed17c90871`](https://github.com/rails/rails/commit/ed17c90871d2c65acc201c082c1f6f924d6d55f9) (found) | upgrade guide on main mentions active_job; references #59820: rails/rails#59986 (PR, open, thomasklemm): Note in the upgrade guide that Action Mailer no longer loads Active Job; queue item UG82M (introduced_by 59820); rails/rails#59986 (PR, open, thomasklemm): Note in the upgrade guide that Action Mailer no longer loads Active Job [active_job]; rails/rails#58957 (PR, open, linyiru): Skip structured event handlers whose event nobody consumes [active_job]; rails/rails#46797 (issue, open, georgeclaghorn): Active Job async adapter may use connections without a lease [active_job] |

Breaks already in the previous run: none.
Fixed since the previous run: none.

## Per app

| App | bundle | boot | eager_load | runner | Notes |
|---|---|---|---|---|---|
| blog | ok | ok | ok | ok |  |
| campfire | ok | fails on 8.1 only | not reached on 8.1, main ok | not reached on 8.1, main ok | 8.1 boot: `RuntimeError: Unknown version "8.2"` |
| casa | ok | ok | ok | ok |  |
| chatwoot | ok | ok | ok | ok |  |
| codetriage | ok | ok | ok | ok |  |
| discourse | ok | ok | break | not reached on main | main eager_load: `LoadError: cannot load such file -- active_job` |
| docuseal | ok | ok | fails on both | skipped | 8.1 eager_load: `RuntimeError: Could not load libpdfium library. Make sure it's installed and in your library path. Error: Could not open library 'libpdfium.so': libpdfium.so: c`; main eager_load: `RuntimeError: Could not load libpdfium library. Make sure it's installed and in your library path. Error: Could not open library 'libpdfium.so': libpdfium.so: c` |
| fizzy | ok | fails on 8.1 only | not reached on 8.1, main ok | not reached on 8.1, main ok | 8.1 boot: `NameError: undefined method 'call' for class 'Hash'` |
| flow | fails on 8.1 only | not reached on 8.1, main ok | not reached on 8.1, main ok | not reached on 8.1, main ok | 8.1 bundle: `Bundler: Could not find compatible versions \| Because every version of rails depends on activestorage = 8.1.4.1 \|   and every version of activestorage depends` |
| hackatime | ok | ok | ok | ok |  |
| lago | ok | ok | ok | ok |  |
| lobsters | ok | ok | ok | ok |  |
| loomio | ok | ok | ok | ok |  |
| mastodon | ok | ok | ok | ok |  |
| pingcrm | ok | ok | ok | ok |  |
| react-starter-kit | ok | ok | ok | ok |  |
| redprints-cfp | ok | ok | ok | ok |  |
| sure | ok | ok | ok | ok |  |
| thinkroom | ok | ok | ok | ok |  |
| writebook | ok | ok | ok | ok |  |

## Ranking and ownership (checked by hand)

One new break, and it is the first run, so every break counts as new.

**1. AM3: Action Mailer cannot load without the `activejob` gem.** Severity: the app does not start in production
(eager load), and without eager loading the first mailer class load raises. #59820 (byroot, merged 2026-11-16,
first bad merge [`ed17c90871`](https://github.com/rails/rails/commit/ed17c90871d2c65acc201c082c1f6f924d6d55f9),
found in 13 bisect steps over 2,517 first-parent commits) dropped `activejob` from `actionmailer.gemspec`. But
`load_defaults "6.0"` and later still set `config.action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"`, the
mailer railtie constantizes it in `on_load(:action_mailer)`, and `action_mailer/mail_delivery_job.rb` starts with
`require "active_job"`. An app whose Gemfile lists Rails components with `actionmailer` and without `activejob` (or
`rails`) therefore raises `LoadError: cannot load such file -- active_job` when `ActionMailer::Base` loads, even if
it never calls `deliver_later`. This contradicts the CHANGELOG entry ("no longer have a hard dependency on Active Job").
Minimal repro [`2026-11-25/am3/`](../../bench/upstream/rails-main-boot/2026-11-25/am3/) (railties, actionpack,
actionmailer only): 8.1.4.1 boots with and without `load_defaults`. Main with `load_defaults 8.1` raises at boot;
without `load_defaults` it boots, and only `delivery_job` raises, which is the intended behavior.

* Reach: Discourse (census copy, first app frame `app/mailers/admin_confirmation_mailer.rb:3`). Its current main
  Gemfile lists the same seven components, `~> 8.1.0`, without `activejob`, so it breaks on its 8.2 upgrade. GitHub
  code search: 391 Gemfiles contain `gem "actionmailer"`, 64 of them also `gem "activejob"` (indicative, not
  verified per file).
* Ownership: nobody else has it. No rails/rails issue or PR names `MailDeliveryJob` together with a missing Active
  Job, and #59820 has no comments or reviews. Its only cross-reference is our UG82M draft (#59986), which covers a
  different case: a railtie list without `active_job/railtie`. UG82M's fix (require the Active Job railtie) itself
  raises `LoadError` when the gem is not bundled. No Discourse issue or PR. Main has not changed Action Mailer
  since `f785381cca`.
* Assessment: Rails itself is wrong here (its default configuration makes the removed dependency hard again), and
  the regression is unreleased and breaks a widely used app. So it meets the rails/rails bar for urgent findings. A
  small fix would make the railtie's `delivery_job` default lazy or conditional on Active Job, keeping #59820's
  purpose. Otherwise, UG82M's note could also say to add `activejob` to the Gemfile. **Record only**: nothing has
  been built or posted. If it is built, it gets a queue item `AM3` with `introduced_by: 59820` and a
  `script/ownership` check.

Not breaks:

* **campfire, fizzy** set `load_defaults 8.2`, so they cannot boot on 8.1 (`Unknown version "8.2"`, and
  `Hash#call` missing). They boot, eager-load and run on main. **flow**'s lock needs marcel 2 (Active Storage on main),
  so it cannot bundle with 8.1. It bundles, boots, eager-loads and runs on main. From the next run on, these three are compared with this run's main.
* **docuseal** boots on both trees. Its eager load needs Docuseal's own pdfium fork, which is released for musl only,
  so it fails on both trees on glibc (environment).
* The other 15 apps (blog, casa, chatwoot, codetriage, hackatime, lago, lobsters, loomio, mastodon, pingcrm,
  react-starter-kit, redprints-cfp, sure, thinkroom, writebook) pass bundle, boot, eager load and `rails runner` on
  both trees. UG82K, UG82S and UG82M do not show here because no census app uses Sidekiq 7, inserts middleware
  relative to `Rack::Sendfile`, or lists the mailer railtie without the Job railtie.

## Run notes

* Ruby 4.0.9, 2 vCPU, 3 GB. A cold orb took about 35 minutes: a 33-minute run
  ([summary](../../bench/upstream/rails-main-boot/2026-11-25/cold-run-summary.txt)) plus copies of four apps from an
  interrupted first attempt. Nearly all of it was bundling, including Chatwoot's grpc and Lago's Rust extension.
  This record is from a warm rerun (copies and bundles cached): 192 seconds with the bisect.
* The interrupted first attempt ran bundle installs while another app booted. A reinstall of `stackprof` then made
  fizzy's main boot fail. Installs now run one after another before the parallel boots.
* Apps' test suites were not run (`--tests` is optional). It was validated on blog: 21 per-test outcomes per tree,
  identical.
