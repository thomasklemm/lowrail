### Allow registering parameter parsers in place during boot

Since #57952, the default parameter parsers are [the frozen `DEFAULT_PARSERS` constant](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L31), and [assigned parsers are frozen too](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L45). Code that registers a parser in place now raises `FrozenError` while the app boots:

```ruby
ActionDispatch::Request.parameter_parsers[:jsonapi] = ->(raw) { JSON.parse(raw) }
# 8.1: registered; main: FrozenError: can't modify frozen Hash
```

Released gems do this from their railtie or engine: [graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb#L84), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb#L75), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/75314ad9742e8fe4746e1c8418779d2aacf7d9b8/lib/jsonapi/rails/railtie.rb#L43) and [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb#L14), which OpenProject uses, so apps using them don't boot on main.

This restores in-place registration: the parsers stay mutable during boot, and in apps that never call `ractorize!` (`DEFAULT_PARSERS` stays frozen). A `before_ractorize` hook freezes the parsers of every class that includes `ActionDispatch::Http::Parameters` and records that it did, so parsers assigned or included after `ractorize!` are frozen as before. To read them from another Ractor, every parser value must be shareable, as with #57952. Tests cover registering in place on the defaults, after a manual freeze and on a `Request` subclass; freezing other includers and grandchildren; and calling registered, reassigned and later-included parsers from a Ractor.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/cb32d8e9ab8940671cf707304bbfea0a4258e4b4/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
