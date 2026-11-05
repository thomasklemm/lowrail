### Include NavigationHelper in cells on Rails 8.2

Rails main (8.2.0.alpha) moved `link_to`, `button_to`, `current_page?` and the `link_to_if` family from `UrlHelper` into a new `ActionView::Helpers::NavigationHelper` ([rails/rails#55410](https://github.com/rails/rails/pull/55410)). The [`FormHelper` include](https://github.com/trailblazer/cells-rails/blob/77ff22ae8f94472cf477672ca2f0c86757d627d8/lib/cell/railtie.rb#L49) brought them into every cell, but `FormHelper` doesn't include the new module, so on Rails main a cell's `link_to` raises `NoMethodError`. If the cell forwards missing methods to the view, as Decidim's cells do, it renders the view's `link_to` instead, and the block's markup comes out escaped.

This includes `NavigationHelper` next to `FormHelper` when it is defined, so Rails 8.1 and earlier are unchanged. It also brings back the private `token_tag` and `method_tag` that `form_tag` and `form_for` need on Rails main today. The new test renders `link_to` from a cell. On Rails main without this change, it and the form tests raise; with it, the suite gives the same result as on Rails 8.1 (Ruby 4.0).

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c96c47539d8b49f7455fe03f66a498aa123d6e30/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
