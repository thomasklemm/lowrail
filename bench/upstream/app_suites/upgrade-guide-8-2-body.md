### Add four notes to the Rails 8.2 upgrade guide

This adds four sections to "Upgrading from Rails 8.1 to Rails 8.2". Each covers a change on main that breaks existing apps and that the guide doesn't mention yet. They are separate commits, so each can be taken on its own:

* **`link_to`, `button_to` and `current_page?` moved to `NavigationHelper`** ([`07f4b45`](https://github.com/rails/rails/commit/07f4b45e294e016675ec500a800f359cde839aa4), #55410): classes that include `UrlHelper` or `FormHelper` without it lose them, as in Redmine, Mastodon, Decidim and Gumroad.
* **`Rack::Sendfile` is omitted when `x_sendfile_header` is unset** ([`b37aeee`](https://github.com/rails/rails/commit/b37aeee32f29b879f7bc6e1d91fda7e5f845160b), #56915): when it is unset, `insert_before Rack::Sendfile` raises on boot, as in Redmine.
* **Loading fixtures on PostgreSQL 18.4+ acquires more locks** ([`7051ca8`](https://github.com/rails/rails/commit/7051ca8a45e4757fbf05431e0dae1077e3c418b4), #57378): parallel test workers loading fixtures into databases with a few hundred foreign keys can fail with `out of shared memory`.
* **Upgrade Sidekiq to 8.0.3 or later** ([`10c24f2`](https://github.com/rails/rails/commit/10c24f2481c55a8f215f7a0dcfa4126a702f5b82), #56518): older releases, including the 7.3.3+ that the 8.1 deprecation recommends, can fail to load Sidekiq's adapter; [`b065bfb`](https://github.com/sidekiq/sidekiq/commit/b065bfb4873a95d84b815f574f0daf6b8742e39c) (sidekiq/sidekiq#6669) fixed it in 8.0.3.

These notes come from comparing applications on main and 8-1-stable, with focused reproductions. Docs only.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c7893f5d5b509a2514303c84459f74bb0499d6fc/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
