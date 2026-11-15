---
id: OP1
repo: rails/rails
kind: fix
area: Action Dispatch parameter parsers
reviewer: "byroot (merged #57952)"
branch: thomasklemm/parameter-parsers-register-in-place
head: "49b835ba58"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "graphiti, graphiti-rails, jsonapi-rails and scimitar (OpenProject) boot on main again instead of raising FrozenError; fixes unreleased #57952"
rank: 3
risky: true
state: ready
pr: 59661
note: "opened as draft 2026-11-05; earlier heads c5df553fa3, 860a2c7220, 6331f39542; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: test list (in the diff); Ractor shareability note; evidence in docs/upstream/app-suites.md#openproject"
passes:
  - {reviewer: sol, head: unrecorded, date: 2026-11-05, verdict: changes, open: "two rounds, applied"}
  - {reviewer: astra, head: "c5df553fa3", date: 2026-11-05, verdict: changes, open: "frozen? check, applied"}
  - {reviewer: skeptic, head: "860a2c7220", date: 2026-11-05, verdict: nits, open: "no blocker, applied"}
  - {reviewer: astra, head: "860a2c7220", date: 2026-11-05, verdict: changes, open: "round 2: non-Request includers, applied"}
  - {reviewer: astra, head: "6331f39542", date: 2026-11-05, verdict: nits, open: "round 3: approve; one test/body nit applied in 49b835ba58"}
  - {reviewer: sol, head: "49b835ba58", date: 2026-11-05, verdict: approve, open: production code unchanged since Astra round 3}
  - {reviewer: astra, head: "49b835ba58", date: 2026-11-05, verdict: nits, open: "module/singleton-class includer fixtures, a lazy-load assertion, ancestors filter hardening, after replacing a manually frozen table; not applied"}
  - {reviewer: skeptic, head: "49b835ba58", date: 2026-11-05, verdict: nits, open: "optional: before_ractorize hook walks ObjectSpace (others use .descendants); flag name parameter_parsers_frozen; one garbled body sentence; railties ractors_test not run (needs RACK=head)"}
  - {reviewer: claude-code, head: "49b835ba58", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: nits, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Clause backed by app-suites.md OP1. Nit applied: 'code that registers a parser' -> 'registering a parser'."}
---

# Allow registering parameter parsers in place during boot

Since #57952, the default parameter parsers are [the frozen `DEFAULT_PARSERS` constant](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L31), and [assigned parsers are frozen too](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L45). Running OpenProject's test suite on Rails main, I found that registering a parser in place now raises `FrozenError` while the app boots:

```ruby
ActionDispatch::Request.parameter_parsers[:jsonapi] = ->(raw) { JSON.parse(raw) }
# 8.1: registered; main: FrozenError: can't modify frozen Hash
```

Released gems do this from their railtie or engine: [graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb#L84), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb#L75), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/75314ad9742e8fe4746e1c8418779d2aacf7d9b8/lib/jsonapi/rails/railtie.rb#L43) and [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb#L14), which OpenProject uses, so apps using them don't boot on main.

This restores in-place registration, keeping parsers mutable until `ractorize!`, which then freezes them on every class that includes `ActionDispatch::Http::Parameters`. Parsers assigned or included after that are frozen as before, and `DEFAULT_PARSERS` itself stays frozen. Reading them from another Ractor still requires every parser value to be shareable.
