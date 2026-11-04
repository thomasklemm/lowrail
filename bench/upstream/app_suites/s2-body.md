### Note in the upgrade guide that link_to and button_to moved to NavigationHelper

#55410 moved `link_to`, `button_to`, `current_page?` and the `link_to_if` family from `ActionView::Helpers::UrlHelper` into the new `ActionView::Helpers::NavigationHelper`. Views are unaffected, because `ActionView::Helpers` includes both. A class that includes only `UrlHelper` to build links outside a view, such as a presenter or a hook object, loses these methods:

```ruby
class LinkPresenter
  include ActionView::Helpers::UrlHelper
end
LinkPresenter.new.link_to("Issues", "/issues")
# => NoMethodError: undefined method 'link_to'
```

Redmine's view hook listeners hit this. Its plugins build links that way through `Redmine::Hook::ViewListener`.

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2". Because `NavigationHelper` includes `UrlHelper`, including `NavigationHelper` instead is all an app needs. The section also notes that code supporting earlier Rails versions should keep `UrlHelper` there, since `NavigationHelper` doesn't exist before 8.2.

Docs only.
