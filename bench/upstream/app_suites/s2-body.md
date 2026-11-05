### Note in the upgrade guide that link_to and button_to moved to NavigationHelper

#55410 moved `link_to`, `button_to`, `current_page?` and the `link_to_if` family from `ActionView::Helpers::UrlHelper` into the new `ActionView::Helpers::NavigationHelper`. Views are unaffected, because `ActionView::Helpers` includes both. A class that includes only `UrlHelper` to build links outside a view, such as a presenter or a hook object, loses these methods:

```ruby
class LinkPresenter
  include ActionView::Helpers::UrlHelper
end
LinkPresenter.new.link_to("Issues", "/issues")
# => NoMethodError: undefined method 'link_to'
```

Redmine's [`Redmine::Hook::ViewListener`](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/lib/redmine/hook/view_listener.rb#L32) (master) hits this, and so do Mastodon's [`REST::NotificationSerializer`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/serializers/rest/notification_serializer.rb#L5) and [`REST::NotificationGroupSerializer`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/serializers/rest/notification_group_serializer.rb#L5) (main), which call [`link_to`](https://github.com/mastodon/mastodon/blob/599d816f6e4dd444766155cbce05ffea8568d2f8/app/serializers/concerns/notification_fallback_concern.rb#L82) through `NotificationFallbackConcern`.

Includers of `FormHelper` lose them too, and a class that also forwards missing methods to a view doesn't raise: `link_to` then runs in the view, without the class's own `capture`. Cells from cells-rails 0.1.6 [include `FormHelper`](https://github.com/trailblazer/cells-rails/blob/77ff22ae8f94472cf477672ca2f0c86757d627d8/lib/cell/railtie.rb#L49) and Decidim's cells [delegate to the view context](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/lib/decidim/view_model.rb#L21) (develop), so on main [Decidim's cards](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/cells/decidim/card_g/show.erb#L1) render their markup as escaped text.

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" that covers both cases. The fix is `include ActionView::Helpers::NavigationHelper`, which includes `UrlHelper`. The section also shows a form for code that supports earlier versions.

Docs only.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c96c47539d8b49f7455fe03f66a498aa123d6e30/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
