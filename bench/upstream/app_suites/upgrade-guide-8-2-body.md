### Add four notes to the Rails 8.2 upgrade guide

This adds four sections to "Upgrading from Rails 8.1 to Rails 8.2". Each covers a change on main that breaks existing apps and that the guide doesn't mention yet:

* **`link_to`, `button_to` and `current_page?` moved to `NavigationHelper`** ([`07f4b45`](https://github.com/rails/rails/commit/07f4b45e294e016675ec500a800f359cde839aa4), #55410): classes that include `UrlHelper` or `FormHelper` without it lose them, as in Redmine, Mastodon, Decidim and Gumroad.
* **`Rack::Sendfile` requires `x_sendfile_header`** ([`b37aeee`](https://github.com/rails/rails/commit/b37aeee32f29b879f7bc6e1d91fda7e5f845160b), #56915): `insert_before Rack::Sendfile` raises on boot, as in Redmine.
* **Loading fixtures on PostgreSQL 18.4+ acquires more locks** ([`7051ca8`](https://github.com/rails/rails/commit/7051ca8a45e4757fbf05431e0dae1077e3c418b4), #57378): parallel test workers can fail with `out of shared memory`.
* **Sidekiq 8.0.3 or later is required to use its Active Job adapter** ([`10c24f2`](https://github.com/rails/rails/commit/10c24f2481c55a8f215f7a0dcfa4126a702f5b82), #56518): with earlier versions, including the 7.3.3+ that the 8.1 deprecation asks for, `config.active_job.queue_adapter = :sidekiq` raises `NameError` when `ActiveJob::Base` loads (sidekiq/sidekiq#6669 fixed it in 8.0.3).

Each was found in an app on main and doesn't occur on 8-1-stable. Docs only.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/55198aba6f265745f8ee4b3b3d261630a38ff2ee/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
