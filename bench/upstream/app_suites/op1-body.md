### Allow registering parameter parsers in place during boot

Since #57952, the default parameter parsers are [the frozen `DEFAULT_PARSERS` constant](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L31), and [assigned parsers are frozen too](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L45). Code that registers a parser in place now raises `FrozenError` while the app boots:

```ruby
ActionDispatch::Request.parameter_parsers[:jsonapi] = ->(raw) { JSON.parse(raw) }
# 8.1: registered; main: FrozenError: can't modify frozen Hash
```

Released gems do this from their railtie or engine: [graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb#L84), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb#L75), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/75314ad9742e8fe4746e1c8418779d2aacf7d9b8/lib/jsonapi/rails/railtie.rb#L43) and [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb#L14), which OpenProject uses, so apps using them don't boot on main.

The parsers now stay mutable while the app boots, and a `before_ractorize` hook freezes them, as #57952 did on assignment. The default is a copy of `DEFAULT_PARSERS` so it can be extended; parsers are still only frozen, so a parser read from another Ractor must be shareable, as before. One test registers a parser in place and posts to it; another reads a parser registered in an initializer from a Ractor after `ractorize!`.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
