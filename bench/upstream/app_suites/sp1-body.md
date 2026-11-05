### Note in the upgrade guide that default_url_options is frozen unless configured

#58483 froze the `default_url_options` Hash that controllers, mailers and every other class including the URL helpers start with. Neither the CHANGELOG nor the upgrade guide mentions it, and code that sets a host in place now raises when the application hasn't configured the options:

```ruby
ActionMailer::Base.default_url_options[:host] = "shop.example.com"
# 8.1:  sets the host
# main: FrozenError: can't modify frozen Hash: {}
```

Callers that fail on Rails main:

* Spree's [`BaseMailer#ensure_default_action_mailer_url_host`](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/mailers/spree/base_mailer.rb#L182), which [`mail` calls](https://github.com/spree/spree/blob/b16f63338bf0229794afeaa19db84cd7579972a0/spree/core/app/mailers/spree/base_mailer.rb#L65) for every email of a store with a storefront URL;
* rails_admin's [`spec_helper.rb`](https://github.com/railsadminteam/rails_admin/blob/2dfd05f15f983792c6b981c67a2d53e6b9419b85/spec/spec_helper.rb#L47), when the suite loads;
* rspec-rails 8.0.4's [feature example group](https://github.com/rspec/rspec-rails/blob/47ab2ca91ace1aa8beaad91e59cde5fae46ed3b8/lib/rspec/rails/example/feature_example_group.rb#L19) (fixed on its main branch, unreleased).

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" with the three replacements (configure the options, assign a new Hash, override the method) and notes that `routes.default_url_options` is unaffected. Docs only; each example was run on main.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
