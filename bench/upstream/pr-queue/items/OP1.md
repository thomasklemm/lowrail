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
note: "2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-rails-ruby.md): on current main (046cca206b renamed main's hook to action_dispatch.ractorize) the head adds a second initializer with that name. Candidate thomasklemm/parameter-parsers-register-in-place-lean 58c3765e8a on main 8e097e9d81: the flag, the ObjectSpace walk and &.freeze are gone; DEFAULT_PARSERS.dup on include, an unfrozen writer, and one freeze line in main's existing hook (Rails parses only with ActionDispatch::Request.parameter_parsers); lib +3/-2. Action Pack 4,526 runs 0 F/E; railties ractors_test (RACK=head) 21 runs 0 F/E; RuboCop 4 files clean; no-dup and writer-freeze mutants fail. Needs claude-code and Astra (risky) on the new head; its body is under For Thomas. opened as draft 2026-11-05; earlier heads c5df553fa3, 860a2c7220, 6331f39542; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: test list (in the diff); Ractor shareability note; evidence in docs/upstream/app-suites.md#openproject"
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
  - {reviewer: astra, head: "58c3765e8a", orb: T-01a1ee60-ae6e-70c0-8121-529b8f4e7a5a, date: 2026-11-18, verdict: changes, open: "Reproduced unfrozen replacement from a later before_ractorize callback, breaking non-main-Ractor parser reads before ractorize! even returns; preserve writer freezing once ractorization starts. The direct Request reference also triggers its on_load hook early with eager_load=false; preserve lazy loading. Qualify the body's no-request-is-parsed-with-other-tables claim and disclose the lost Ractor reads. Identity/date/no-trailers verified. Details under For Thomas."}
---

# Allow registering parameter parsers in place during boot

Since #57952, the default parameter parsers are [the frozen `DEFAULT_PARSERS` constant](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L31), and [assigned parsers are frozen too](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L45). Running OpenProject's test suite on Rails main, I found that registering a parser in place now raises `FrozenError` while the app boots:

```ruby
ActionDispatch::Request.parameter_parsers[:jsonapi] = ->(raw) { JSON.parse(raw) }
# 8.1: registered; main: FrozenError: can't modify frozen Hash
```

Released gems do this from their railtie or engine: [graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb#L84), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb#L75), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/75314ad9742e8fe4746e1c8418779d2aacf7d9b8/lib/jsonapi/rails/railtie.rb#L43) and [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb#L14), which OpenProject uses, so apps using them don't boot on main.

This restores in-place registration, keeping parsers mutable until `ractorize!`, which then freezes them on every class that includes `ActionDispatch::Http::Parameters`. Parsers assigned or included after that are frozen as before, and `DEFAULT_PARSERS` itself stays frozen. Reading them from another Ractor still requires every parser value to be shareable.

## For Thomas

### Body for the -lean head (2026-11-18, not posted)

Since #57952, the default parameter parsers are [the frozen `DEFAULT_PARSERS` constant](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L31), and [assigned parsers are frozen too](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L45). Running OpenProject's test suite on Rails main, I found that registering a parser in place now raises `FrozenError` while the app boots:

```ruby
ActionDispatch::Request.parameter_parsers[:jsonapi] = ->(raw) { JSON.parse(raw) }
# 8.1: registered; main: FrozenError: can't modify frozen Hash
```

Released gems do this from their railtie or engine: [graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb#L84), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb#L75), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/75314ad9742e8fe4746e1c8418779d2aacf7d9b8/lib/jsonapi/rails/railtie.rb#L43) and [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb#L14), which OpenProject uses, so apps using them don't boot on main.

This keeps the parsers mutable while the app boots, and the existing `before_ractorize` hook freezes `ActionDispatch::Request.parameter_parsers`, the ones requests are parsed with. `DEFAULT_PARSERS` itself stays frozen, and reading the parsers from another Ractor still requires every parser value to be shareable. Parsers assigned after `ractorize!` and those of other classes that include `ActionDispatch::Http::Parameters`, which no request is parsed with, are no longer frozen.

### Astra adversarial review of 58c3765e8a (2026-11-18)

**Verdict: changes.** Reviewed directly, without delegation. Candidate is
`58c3765e8a424c69236f755b5abfced112715ab2`, parent `8e097e9d81`.

1. **Must fix: replacement during ractorization loses shareability.**
   `actionpack/lib/action_dispatch/http/parameters.rb:44-45` always produces a
   mutable hash. An application or engine callback registered after Action
   Dispatch's `before_ractorize` callback can replace the just-frozen table:

   ```ruby
   ActiveSupport.on_load(:before_ractorize) do
     ActionDispatch::Request.parameter_parsers = ActionDispatch::Request.parameter_parsers
   end
   Rails.application.ractorize!
   ```

   In a booted production application, `ractorize!` returns successfully, but
   `parameter_parsers.frozen?` is false and a non-main Ractor reading even the
   unchanged default JSON parser raises `Ractor::IsolationError` for
   `@parameter_parsers from ActionDispatch::Request`. Parent main and the old
   head's parameter/railtie implementation return `{"a" => 1}` for the same
   parser call. The candidate's no-replacement control also succeeds. This is
   **during** `ractorize!`, not just the post-ractorization difference accepted
   in the proposed body. Retain a ractorization-state check in the writer, or
   an equivalent guarantee that replacements remain frozen, and add a later-hook
   regression test. Merely freezing the setter's input does not help:
   `transform_keys` creates a mutable replacement.

2. **Must fix: the freeze now forces a lazy Request load.**
   `actionpack/lib/action_dispatch/railtie.rb:112` references `Request` directly.
   In a production application with `eager_load=false`, Request remains an
   autoload through `after_initialize`. On parent main and the old implementation,
   it remains lazy through `ractorize!`; on the candidate, its
   `:action_dispatch_request` hooks run inside Action Dispatch's ractorization
   callback. The initializer itself does not force loading, and eager-loaded
   production does not expose this difference. Use the existing Request load
   hook to defer the freeze when Request is absent, keeping the late-load case
   and hook ordering covered by a test.

3. **Body correction and explicit scope decision.** The live body correctly
   describes old head `49b835ba58`, not this candidate; do not reuse it unchanged.
   The proposed body discloses two lost freezes, but “which no request is parsed
   with” is too absolute: Rails' stock `params_parsers` uses Request's table;
   custom request subclasses can override that method and consume their own
   table. Direct public parser reads on such classes also worked from a Ractor
   before and now fail even with shareable values. The ObjectSpace walk really
   did cover those reads. Dropping that coverage is a scope choice, not proof
   those tables are unused. Qualify the claim to the stock Rails request path
   and state the Ractor consequence if the narrower coverage is retained.

Checks: Ruby 4.0.9, Rack main `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`.
The controls used the parent's or old head's two changed production files over
the same candidate checkout, so unrelated framework differences were held fixed.
Executed default parser reads, later-hook replacement, post-hook replacement,
custom-class reads, and lazy-load probes; also booted production apps and called
the real `ractorize!`. A late engine initializer, `after_initialize`, and
registration after boot without ractorization all succeeded on the candidate
(`[:json, :xml, :csv, :html]`). `webservice_test.rb`: **9 runs, 22 assertions,
0 failures/errors/skips**. Did not rerun the builder's full Action Pack or
railties suites. Scratch reproducers are retained in this review orb under
`.amp/in/orb-backup/op1_probe.rb` and `op1_app_probe.rb`.

Identity: raw commit headers have Thomas Klemm `<github@tklemm.eu>` as both
author and committer; author date `2026-11-05T12:05:18Z` matches `49b835ba58`
and the live PR commit; `%(trailers:only)` is empty. One existing
`action_dispatch.ractorize` initializer remains, rather than a duplicate.
