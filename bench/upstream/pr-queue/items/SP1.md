---
id: SP1
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide"
reviewer: "Edouard-chin (author of #58483), gmcgibbon (merged it)"
branch: thomasklemm/upgrade-guide-frozen-default-url-options
head: "4fe014a8a7"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "upgrade-guide note that default_url_options is a frozen {} unless configured (Spree's mailers, about 1,080 code-search hits)"
rank: 10
risky: false
state: in-review
pr:
note: "waits for #58483's author (heads-up posted 2026-11-05); conflicts textually with UG82, rebase once UG82 moves"
passes:
  - {reviewer: skeptic, head: unrecorded, date: 2026-11-05, verdict: nits, open: "two should-fixes and three nits, all but one nit applied"}
  - {reviewer: opus, orb: T-01a1e18f-86a8-75c0-91a2-90cc92fb40c7, head: "4fe014a8a7", date: 2026-11-15, verdict: changes, open: "Guide text approved; the current body (bb6a5c4b) still needs changes. On rails/rails main 78039119db (merges cleanly; url_for.rb still {}.freeze, 8-1-stable {}), Ruby 4.0.9: unconfigured, ActionMailer::Base, ActionController::Base, a class including routes.url_helpers and an integration session all have a frozen {} and []= raises FrozenError can't modify frozen Hash: {}; with config.action_mailer.default_url_options set the mailer Hash is not frozen and []= works; assigning a new Hash and overriding default_url_options in a mailer both work (url renders); routes.default_url_options []= works. No CHANGELOG on main mentions it. rubocop + rubocop-md and mdl clean. Fixed by bb6a5c4b: footer gone; the rspec-rails link at 222fb5518a (v8.0.4's commit) returns 200 and L19 is the in-place default_url_options[:host] ||=, which 8.0.5 still has and 8.1.0 (2026-11-06, Changelog: rspec/rspec-rails#2907) replaces, so 'rspec-rails 8.0 ... (fixed in 8.1.0)' holds; the how-found clause matches docs/upstream/app-suites.md (Spree suite, SP1). Must-fix: (1) cut 'Docs only; each example was run on main.' (Leave out: process; the diff shows it is docs); (2) Line permalinks: Spree and rails_admin are gems, so link the latest release and name its version, not main commits: Spree v6.0.4 (f03d041483, same lines 65 and 182 as b16f63338b), rails_admin v4.0.0.beta2 (0c6b8e9d70, same L47) or v3.3.1 (L44). Nit: the item note's conflict with UG82 is gone (clean merge now); it conflicts with UG82S instead."}
---

# Note in the upgrade guide that default_url_options is frozen unless configured

#58483 froze the `default_url_options` Hash that controllers, mailers and every other class including the URL helpers start with. Neither the CHANGELOG nor the upgrade guide mentions it. Running Spree's test suite on Rails main, I found that code that sets a host in place now raises when the application hasn't configured the options:

```ruby
ActionMailer::Base.default_url_options[:host] = "shop.example.com"
# 8.1:  sets the host
# main: FrozenError: can't modify frozen Hash: {}
```

Callers that fail on Rails main:

* Spree's [`BaseMailer#ensure_default_action_mailer_url_host`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/mailers/spree/base_mailer.rb#L182), which [`mail` calls](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/mailers/spree/base_mailer.rb#L65) for every email of a store with a storefront URL;
* rails_admin's [`spec_helper.rb`](https://github.com/railsadminteam/rails_admin/blob/2dfd05f15f983792c6b981c67a2d53e6b9419b85/spec/spec_helper.rb#L47), when the suite loads;
* rspec-rails 8.0's [feature example group](https://github.com/rspec/rspec-rails/blob/222fb5518a7c9c1b9a0a06d950c2dfa2d3fa69e9/lib/rspec/rails/example/feature_example_group.rb#L19) (fixed in 8.1.0).

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" with the three replacements (configure the options, assign a new Hash, override the method) and notes that `routes.default_url_options` is unaffected. Docs only; each example was run on main.
