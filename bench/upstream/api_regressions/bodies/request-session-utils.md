Title: **Deprecate ActionDispatch::Request::Session and Request::Utils**

`ActionDispatch::Request::Session` and `ActionDispatch::Request::Utils` now resolve to `ActionDispatch::Http::Session` and `ActionDispatch::Http::Utils`, and each lookup prints a deprecation warning. #57856 moved both classes to make them load at boot, but it did not keep the old names, and that change has not been released yet.

Gems and applications still use the old names, so on main they raise `NameError`:

- json_tagged_logger calls `ActionDispatch::Request::Session.create(store, request, options)` for every request it tags.
- Application specs stub or check `ActionDispatch::Request::Session`. GitHub code search finds it in about 150 `spec/` files, and also in ManageIQ's session extension.

The deprecated names return the same classes, so calls such as `create`, `find`, `Options`, `is_a?`, `ENV_SESSION_KEY` and `perform_deep_munge=` behave as on 8-1-stable, apart from the warning. This is the same pattern main already uses for `Cookies::HTTP_HEADER` and `InvalidAuthenticityToken`. As with those constants, `defined?(ActionDispatch::Request::Session)` now returns `nil`. The gems I found that guard with `defined?` (zhong, rspec_power) then skip their patch, so they don't break.

The new test fails without the deprecations.
