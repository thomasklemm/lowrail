---
id: OP1
repo: rails/rails
kind: fix
area: Action Dispatch parameter parsers
reviewer: "byroot (merged #57952)"
branch: thomasklemm/parameter-parsers-register-in-place
head: "d1e2cdbcc2fe0a8e664eb57a7fee937e04c5a23f"
merged_head: "d1e2cdbcc2fe0a8e664eb57a7fee937e04c5a23f"
base: main
built_on: "8e097e9d81f65fe8701c77352f5758be4f75f957"
depends_on: []
stacked_on:
alternative_of:
impact: "graphiti, graphiti-rails, jsonapi-rails and scimitar (OpenProject) boot on main again instead of raising FrozenError; fixes unreleased #57952"
rank: 3
risky: true
state: merged
pr: 59661
note: "2026-11-18 (adopted): thermos-sol (add18408) and Astra (a5070630) both approve d1e2cdbcc2; lease-pushed onto thomasklemm/parameter-parsers-register-in-place over 49b835ba58 and PATCHed the body. The old head would have added a second action_dispatch.ractorize initializer on main. 2026-11-18 (-lean2, after Astra changes on 58c3765e8a): thomasklemm/parameter-parsers-register-in-place-lean2 d1e2cdbcc2 on main 8e097e9d81, one commit, author date 2026-11-05T12:05:18Z, no trailers; the PR branch still holds 49b835ba58 and nothing was posted. Fixes the duplicate action_dispatch.ractorize initializer (one line in main's hook) and Astra's three points: the writer freezes a replacement of frozen parsers (`@parameter_parsers.frozen? ? parsers.freeze : parsers`), so a later before_ractorize hook can't put a mutable table back; the hook freezes inside ActiveSupport.on_load(:action_dispatch_request), as Active Record's does, so Request is not loaded by ractorize!; the body names the one lost freeze, direct includers of Http::Parameters (Request subclasses freeze on assignment as on main). Finding: any route loads Request (RouteSet#request_class), so production apps with a route, or with Action Mailbox or Active Storage routes, load it at boot; only a route-less app sees point 2. lib +7/-2 against main. Two railties tests, both fail on 58c3765e8a and each on its own mutant. Action Pack 4,526 runs 0 F/E/S; ractors_test (RACK=head) 23 runs 0 F/E; RuboCop 4 files clean. Needs claude-code and Astra on d1e2cdbcc2. 2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-rails-ruby.md): on current main (046cca206b renamed main's hook to action_dispatch.ractorize) the head adds a second initializer with that name. Candidate thomasklemm/parameter-parsers-register-in-place-lean 58c3765e8a on main 8e097e9d81: the flag, the ObjectSpace walk and &.freeze are gone; DEFAULT_PARSERS.dup on include, an unfrozen writer, and one freeze line in main's existing hook (Rails parses only with ActionDispatch::Request.parameter_parsers); lib +3/-2. Action Pack 4,526 runs 0 F/E; railties ractors_test (RACK=head) 21 runs 0 F/E; RuboCop 4 files clean; no-dup and writer-freeze mutants fail. Needs claude-code and Astra (risky) on the new head; its body is under For Thomas. opened as draft 2026-11-05; earlier heads c5df553fa3, 860a2c7220, 6331f39542; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: test list (in the diff); Ractor shareability note; evidence in docs/upstream/app-suites.md#openproject"
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
  - reviewer: thermos-sol
    orb: T-01a1ee60-a4df-75cc-9428-abffe636e31c
    head: "58c3765e8a424c69236f755b5abfced112715ab2"
    date: 2026-11-18
    verdict: approve
    open: >-
      Both Thermos rubrics applied personally, no delegated reviewers. Reviewed
      the lean candidate and its For Thomas body, not the live head's old body.
      One freeze is added inside main's existing action_dispatch.ractorize
      initializer; no second initializer, flag or ObjectSpace walk remains.
      params_parsers reads Request.parameter_parsers, not other includers;
      post-ractorize assignment and other-includer differences are disclosed.
      The writer's surviving respond_to?(:symbol) handles documented MIME-type
      keys; the existing RUBY_VERSION/RACK test condition requires the Ractor
      APIs under test. No added code/test comments. Opened the linked gem callers;
      in-place registration is real. Ruby 4.0.9: webservice_test.rb 9 runs/22
      assertions and RACK=head application/ractors_test.rb 21/71, all pass.
      The two new webservice cases error with FrozenError on base and pass on
      lean. Raw cat-file: one commit on 8e097e9d81, Thomas author/committer,
      original author date 1793880318 +0000, no trailers. The message correctly
      drops the old post-ractorize-freezing promise. Separate Astra risk slot
      remains required; this pass does not fill it.
  - {reviewer: astra, head: "d1e2cdbcc2", orb: T-01a1ee7c-6230-7048-ae2d-0791548851ec, date: 2026-11-18, verdict: approve, open: "No remaining must-fixes found. Prior reproducers pass; engine/app/on_load registration order and production lazy/eager boot with/without routes checked. Request subclasses retain Ractor reads; direct/concern/singleton-class includers lose them as disclosed, unless explicitly frozen. Candidate body and commit message accurate within that scope. Identity/original date/no-trailers verified. Ractors 23 tests/78 assertions and webservice 9/22, no F/E/S. Details under For Thomas."}
  - {reviewer: thermos-sol, head: "d1e2cdbcc2", orb: T-01a1ee7c-596a-74f9-a54d-b5dc4bad316a, date: 2026-11-18, verdict: approve, open: "No must-fixes. Both rubrics reviewed directly without delegation. Action Pack 4526 runs/21684 assertions; RACK=head ractors_test 23/78; RuboCop 4 files clean. Both new Ractor tests fail on 58c3765e8a, and each fails on its own mutant. Keep the frozen-table guard, nested load hook and route-less regression/comment. Main/old-head differentials, every commit/body sentence and identity verified; direct-includer boundary is disclosed. Details under For Thomas."}
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

### Astra adversarial review of d1e2cdbcc2 (2026-11-18)

**Verdict: approve; no remaining must-fixes found.** Reviewed directly, without
delegation, in orb `T-01a1ee7c-6230-7048-ae2d-0791548851ec`. Exact fork head
`d1e2cdbcc2fe0a8e664eb57a7fee937e04c5a23f` is one commit on
`8e097e9d81f65fe8701c77352f5758be4f75f957`; the remote -lean2 branch still
pointed there when checked. This approval covers the narrower scope stated in
the proposed -lean2 body below, not the old body's promise to freeze every
includer.

* **The previous writer and lazy-loading failures are fixed.** Replayed
  `op1_probe.rb` modes `normal`, `late_hook`, `after_writer`, `includer` (a
  Request subclass), and `lazy` against the candidate and parent/old-head
  two-file controls. All parser reads returned `{"a" => 1}`; the isolated
  lazy probe left the Request autoload intact. Replayed the actual production
  app with `eager_load` both false and true, with and without a later
  `before_ractorize` replacement: the table was frozen and Ractor-readable
  after every `ractorize!`. The lazy normal case did not run Request hooks
  until the probe explicitly referenced Request after ractorization.
* **Registration order did not expose another early freeze.** A real engine
  initializer ordered after `action_dispatch.ractorize`, a later application
  initializer, `after_initialize`, and post-boot registration all worked.
  Separate probes registered Request load callbacks before the initializers,
  in the engine/application initializers, in `after_initialize`, and after
  boot. All callbacks completed their in-place registrations and the engine's
  writer-then-in-place registration before freezing. Tested all four
  combinations of production eager loading on/off and an empty/nonempty route
  set. Route-less lazy boot stayed lazy through `ractorize!`; the other three
  loaded Request during boot. A late Request load callback using the writer
  after ractorization also preserved freezing and returned the expected custom
  parser result from another Ractor (`"xY9"` became `"9Yx"`).
* **The custom-table tradeoff is real, but disclosed.** Request subclasses
  assigned their own tables before and after the hook remained frozen and
  Ractor-readable, including subsequent replacements: the initial absent ivar
  is nil, whose `frozen?` is true. Direct includers before/after the hook,
  inclusion through another concern, and a singleton-class includer instead
  retained mutable tables and raised `Ractor::IsolationError` even reading the
  shareable default JSON parser. Parent main and the old ObjectSpace-based
  implementation allowed all those reads. Explicitly freezing a direct
  includer's table restored its reads and the candidate writer retained that
  freeze. This is not equivalent coverage to the old walk; retaining this
  reduction is the stated scope choice, not evidence such tables are unused.
* **Wording and identity checked.** The proposed -lean2 body no longer claims
  custom tables are never used and states their lost Ractor readability.
  `params_parsers` in stock Rails does use Request's table; custom overrides
  remain possible. The commit's freeze/replacement/copy statements match the
  implementation. The old body above still describes the live old PR head and
  must not be reused for -lean2. Raw headers name Thomas Klemm
  `<github@tklemm.eu>` as author and committer, preserve author timestamp
  `1793880318 +0000` (`2026-11-05T12:05:18Z`, independently matched against the
  live PR commit), and have no trailers.

Verification: Ruby 4.0.9, Rack `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`.
`RACK=head bundle exec ruby -Itest test/application/ractors_test.rb` in railties:
**23 runs, 78 assertions, 0 failures/errors/skips**. Action Pack
`webservice_test.rb`: **9 runs, 22 assertions, 0 failures/errors/skips**. Did not
rerun the full Action Pack or OpenProject suites. The prior orb was archived,
so `download_thread_file` refused the requested transfer; recovered both
original reproducers from its transcript instead. Those and new
`op1_order_probe.rb`, `op1_tables_probe.rb`, route fixtures, and the suite's
`OP1.Gemfile`/lock are retained in this orb's `.amp/in/orb-backup/`. Only this
Lowrail review record is changed; no fork/PR write or public comment.

### Body for the -lean2 head d1e2cdbcc2 (2026-11-18, not posted)

Since #57952, the default parameter parsers are [the frozen `DEFAULT_PARSERS` constant](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L31), and [assigned parsers are frozen too](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionpack/lib/action_dispatch/http/parameters.rb#L45). Running OpenProject's test suite on Rails main, I found that registering a parser in place now raises `FrozenError` while the app boots:

```ruby
ActionDispatch::Request.parameter_parsers[:jsonapi] = ->(raw) { JSON.parse(raw) }
# 8.1: registered; main: FrozenError: can't modify frozen Hash
```

Released gems do this from their railtie or engine: [graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb#L84), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb#L75), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/75314ad9742e8fe4746e1c8418779d2aacf7d9b8/lib/jsonapi/rails/railtie.rb#L43) and [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb#L14), which OpenProject uses, so apps using them don't boot on main.

This keeps the parsers mutable while the app boots. The existing `before_ractorize` hook freezes `ActionDispatch::Request.parameter_parsers`, which Rails parses requests with, once the class is loaded, and parsers assigned after that stay frozen. `DEFAULT_PARSERS` itself stays frozen, and reading the parsers from another Ractor still requires every parser value to be shareable. Classes that include `ActionDispatch::Http::Parameters` directly now keep mutable parsers, which another Ractor can't read.

### Guards and comments on -lean2 (2026-11-18)

Each surviving guard and comment, with the reproducer that keeps it. Reproducers are in this orb's
`.amp/in/orb-backup/` (Astra's `op1_probe.rb` and `op1_app_probe.rb`, plus `op1_writer_probe.rb` and `op1_mutants.sh`).

* `@parameter_parsers.frozen? ? parsers.freeze : parsers` in the writer: Astra's later-hook replacement. On
  58c3765e8a, `op1_probe.rb late_hook` and the production app with a later `before_ractorize` hook end with a mutable
  table and `Ractor::IsolationError` reading the JSON parser; with the guard both are frozen and return
  `{"a" => 1}`. The no-guard mutant fails the later-hook test. It is Rails' own idiom for carrying frozenness over
  (`enum.rb`, `time_zone_conversion.rb`). A Request subclass has no table of its own (`nil.frozen?` is true), so its
  assignments freeze as on main; only direct includers of `Http::Parameters` stay mutable (`op1_writer_probe.rb`:
  main freezes every assignment; 58c3765e8a freezes none after the hook; -lean2 freezes Request after the hook and
  subclasses always).
* `ActiveSupport.on_load(:action_dispatch_request) { parameter_parsers.freeze }` inside the `before_ractorize` hook,
  instead of naming `ActionDispatch::Request`: Astra's lazy-load probe (`op1_probe.rb lazy`: 58c3765e8a runs the
  request hooks inside ractorization, -lean2 leaves `ActionDispatch.autoload?(:Request)` set) and a route-less
  production app with `eager_load = false`. This railtie already reaches Request only through that hook, and
  Active Record's ractorize hook nests `on_load(:active_record)` the same way. The direct-reference mutant fails the
  lazy test; a mutant that registers the freeze at boot instead raises `FrozenError` in two tests. Scope: any route
  loads Request (`RouteSet#request_class` from `Mapping#conditions`), so a production app with a route of its own,
  or the Action Mailbox or Active Storage routes, has it loaded at boot. Only a production app without routes sees
  the difference; local environments draw their lazy routes on demand and were not probed further.
* Test comment `# Drawing any route loads ActionDispatch::Request.` above `use_frameworks` without Action Mailbox,
  `draw_routes = false` and an empty route set: without it a reader would drop that setup as noise, and the test
  would then fail on `ActionDispatch.autoload?(:Request)` rather than test the lazy path. No lib comments.
* Dropped as before (rules review): the flag, the `ObjectSpace` walk and `&.freeze`. The walk's coverage for direct
  includers is the one difference the body states.

Tests, both through `Rails.application.ractorize!` in `railties/test/application/ractors_test.rb`:
"keeps the parameter parsers frozen when a later before_ractorize hook assigns them" (fails on 58c3765e8a: not
frozen) and "freezes the parameter parsers once ActionDispatch::Request is loaded" (fails on 58c3765e8a:
`ActionDispatch.autoload?(:Request)` is nil). Ruby 4.0.9, Rack main via `RACK=head`.

### Thermos-sol confirmation of d1e2cdbcc2 (2026-11-18)

**Verdict: approve; no must-fixes.** Both correctness/security and maintainability rubrics reviewed here directly,
without other reviewers or threads. Exact head `d1e2cdbcc2fe0a8e664eb57a7fee937e04c5a23f` is one commit whose sole
parent is main `8e097e9d81f65fe8701c77352f5758be4f75f957`. The fork's `-lean2` ref matches. Raw commit headers name
Thomas Klemm `<github@tklemm.eu>` as author and committer, author timestamp `1793880318` is
`2026-11-05T12:05:18Z`, and `git interpret-trailers --parse` returns nothing. No Rails sources, fork refs or PR
metadata were changed.

**Correctness and surviving guards.** Read the main, old-head `49b835ba58`, previous lean and candidate production
files, the Request consumer, load-hook implementation, ractorize! caller, and the corresponding Rails idioms.
The candidate has exactly one `action_dispatch.ractorize` initializer in both source and the initializer registry.
A three-way merge of main's railtie, the old head's parent and the old head is clean but has two such initializers.

* Keep `@parameter_parsers.frozen? ? parsers.freeze : parsers`: freeze replacements of a frozen table, otherwise
  leave them mutable. Removing this guard fails the later-hook test, while the lazy-load test still passes.
  Request subclasses and grandchildren start without their own table; their assignments freeze as on main
  (`nil.frozen?` is true), and their JSON parser reads succeed from another Ractor both before and after the hook.
  A manual freeze is also sticky, as on main, unlike the old PR head. No separate nil or subclass guard is needed.
* Keep `on_load(:action_dispatch_request)` nested inside `on_load(:before_ractorize)`: only freeze the Request table
  once both boundaries have happened, without loading Request early. Replacing it with a direct Request reference
  fails only the lazy-load test. This is the existing Active Record ractorization idiom, not another state flag.
* Keep the inherited `key.respond_to?(:symbol)` normalization guard: real `Mime::Type` keys are the documented
  setter example and the webservice regression input. A symbol-bearing duck key is converted once; symbols and
  strings keep their existing treatment. Frozen input hashes are copied, not adopted, and failed assignment leaves
  the previous table intact. Unshareable parser values still produce `Ractor::IsolationError`, as on main.
* Direct class and module includers, including a class included after the hook, retain mutable tables and cannot
  read them from another Ractor, unlike main and the old PR. The proposed body explicitly discloses this scope
  choice. Stock `params_parsers` still reads Request's table; subclass tables are not claimed to be unused.

**Comments and test shape.** The only added code comment is `# Drawing any route loads ActionDispatch::Request.`
Keep it: it explains why the unusual framework/route setup is necessary, rather than narrating the assertion.
Fresh-process probes leave Request lazy after `routes.draw { }`, but load it for a controller route, a Rack endpoint
or a redirect. Traced through `Mapping#conditions` to `RouteSet#request_class`. The route-less test is worth keeping:
it catches the demonstrated lazy-load regression in a route-less production/worker app with `eager_load=false`;
an ordinary routed app would miss it. No extra production comment, flag, ObjectSpace walk or helper is justified.
Cold read: copy the defaults for boot-time edits; preserve the table's frozen state on replacement; freeze Request's
table when ractorization and class loading meet. The setter's small complexity increase buys that real invariant:
flog 5.6 → 6.5; ABC 4.90 → 6.56; cyclomatic/perceived 3 → 4. No file approaches 1,000 lines.

**Commit message and proposed body, sentence by sentence.** The title and cause sentence match the main registration
failure. Opened both frozen-parser permalinks and every gem caller permalink; checked the version sources/tags and
their current-branch callers. The graphiti-rails tag is v0.4.2 despite its stale internal VERSION string. The
OpenProject discovery sentence agrees with the app-suite record and its pinned Gemfile.lock's scimitar 2.15.0.
The boot-mutation sentence is exercised by webservice tests and the real request repro, which also succeeds on
the retained Rails 8.1 checkout. The existing-hook/late-class sentence is exercised by the real application tests;
the frozen-replacement sentence by later-hook and post-hook replacement probes. The default-copy sentence is
exercised by the untouched-default regression. The body correctly keeps DEFAULT_PARSERS frozen, requires shareable
parser values without promising to convert them, and states the direct-includer consequence. No false claim or
required wording change remains; the live body's broader every-includer promise must not be reused for this head.

**Executed checks.** Ruby 4.0.9 (`3e93b23afc`), `RACK=head` at
`da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`, same dependency lock and checkout for all differential controls:

* In `actionpack`: `bundle exec rake test` — **4,526 runs, 21,684 assertions, 0 failures/errors/skips**.
  The harness also reports its service-dependent MemCacheStoreTest group unavailable (no memcached); it is not
  counted as a run or a skip in that summary.
* In `railties`: `bundle exec ruby -Itest test/application/ractors_test.rb` — **23 runs, 78 assertions,
  0 failures/errors/skips**.
* `bundle exec rubocop` on the four changed files — **4 files inspected, no offenses**.
* The two new Ractor tests with the previous lean production files — **2 runs, 2 failures** (mutable replacement;
  Request autoload lost). The no-guard and direct-reference mutants each fail only their respective test.
* Candidate `webservice_test.rb` with main production files — **9 runs, 2 FrozenErrors**, both new registrations;
  with old-head production files — **9 runs, 22 assertions, 0 failures/errors/skips**. No-dup produces two errors;
  unconditional writer-freeze produces one, so both boot-mutation changes are covered.
* Separate main/old/lean/head probes checked subclass/grandchild, class/module includer and late-includer reads,
  default/copy identity, key conversion, invalid input, manual freeze, registration and replacement. Production
  file overlays, probes, lock and raw output are retained under this thread's `.amp/in/orb-backup/op1-*` paths.

Read-only GitHub check: the live PR remains open at `49b835ba58`, with no reviews/comments, but currently reports
`isDraft=false` (not draft). No upstream action was taken; this pass applies only to the requested candidate and
proposed body, not that live head/body. The parallel Astra confirmation is a separate gate.

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
