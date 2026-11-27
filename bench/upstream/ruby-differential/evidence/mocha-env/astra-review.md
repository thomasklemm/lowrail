# MO1 Astra review, 2026-11-27

Verdict: **changes** on `3d3f63b4c136e807c6f532f97fc90794080ba364`. No demonstrated regression in the supported behavior exercised. The remaining blockers are the commit trailer, body and queue metadata, not a demonstrated supported-call failure.

Reviewer: `astra`, thread `T-01a21cf3-0e32-7607-8de3-82fe7c0058b5`. Reviewed directly, without other agents or threads. Nothing sent upstream.

## Must fix before opening

1. **Remove the Amp trailer from the candidate commit and regenerate its patch.** The exact reviewed commit contains `Amp-Thread-ID: https://ampcode.com/threads/T-01a21ca4-eb07-7134-a138-0909fab59394`. This violates both the no-trailers and nothing-internal-upstream rules. `citations/source.txt` retains `git show --format=fuller --stat HEAD`. Removing it changes the head, so update the item and confirm the new head.
2. **Correct the caller citations.** The Capistrano link is to current `master` (`b54b02fa0e`), not the commit of its latest release, **3.20.1** (`f40817b449c113a4fce039a318b92e63e1d10c85`). The same calls are at [3.20.1 lines 275–276](https://github.com/capistrano/capistrano/blob/f40817b449c113a4fce039a318b92e63e1d10c85/spec/lib/capistrano/configuration/servers_spec.rb#L275-L276). Name the version and put this widely used released gem before Sure. Label Sure's existing link `Sure main`, or use its latest release [v0.7.6-hotfix.2 lines 359–360](https://github.com/we-promise/sure/blob/c241a66da7634118b485a9ee561f7c94bbe4efc3/test/models/provider/jev_test.rb#L359-L360), which also contains these calls.
3. **Cut “Stubbing behaves the same as before on every Ruby.”** There is a demonstrated exception: an object with its own `mocha_shareable?` now runs that method during an unrelated stub. The singleton, private and prepended variants returned `42` on base and raised the deliberately supplied `RuntimeError` on the candidate on both pins. The checklist explicitly accepts overrides of private/nodoc methods, so these are **not implementation must-fixes**; the unqualified body promise is still false. The supported lifecycle behavior actually checked is stated below.
4. **Set `risky: true`.** The item currently says false despite introducing Ractor/shareable-object memoization semantics, an explicit risky category in DECISIONS. This review was already adversarial; no extra review was skipped here because of that field.

## Evidence executed

Raw logs, commands, probe sources, dependency locks and citation responses are in `astra-review.tar.gz`. No performance or allocation claim is made.

Built with `script/ruby-differential build`, using Ruby from mise as baseruby:

* `--commit v4.0.9 --name ruby409`: Ruby 4.0.9, revision `3e93b23afcec3433f6aecc34b5d832799d754238`.
* `--commit f3e180b5ebc835f87c2ff7ccb8474a1bf18b0115 --name master`: Ruby 4.1.0dev, that exact revision.
* Both configure with `--enable-zjit --enable-yjit`. Full suites and differential probes ran in interpreter mode. The standalone ENV repro also ran with `--yjit` and `--zjit` on both trees and pins.

Applied the supplied patch to `99da677165a5ef21cc5ad21da733e82fc6aa2636`. Restoring its original committer timestamp (the author timestamp) reproduced the requested commit hash exactly; the reviewed checkout was detached at `3d3f63b4c136e807c6f532f97fc90794080ba364`, tree `b415c4733d630d458bf9be4ccfe889851ff63ac1`.

| Check | Base, both pins | Candidate, both pins |
| --- | --- | --- |
| `bundle exec rake test` | 457 unit + 445 acceptance; no failures/errors | 457 unit + 448 acceptance; no failures/errors |
| `bundle exec rake test:isolated` | All 127 files pass | All 128 files pass |
| Minitest integration Gemfile, `MOCHA_RUN_INTEGRATION_TESTS=minitest bundle exec rake test` | 12 runs; no failures/errors | 12 runs; no failures/errors |
| Test::Unit integration Gemfile, `MOCHA_RUN_INTEGRATION_TESTS=test-unit bundle exec rake test` | 13 tests; no failures/errors | 13 tests; no failures/errors |
| RuboCop Gemfile, `bundle exec rake lint` | 234 files, no offenses | 235 files, no offenses |

Copied only the candidate's acceptance test onto base, then reran `rake test`: all pass on 4.0.9; on master all 457 units pass and exactly the three new acceptance cases fail. Removed the copied test afterwards. The standalone ENV repro passes on base 4.0.9 and fails with `Ractor::IsolationError` on base master; candidate passes on both, in interpreter, YJIT and ZJIT modes. Warnings remain in the raw logs; no claim that the suites are warning-free.

The 37 differential scenarios compare outputs, exception classes/messages and visible state, not simply process exit (probes deliberately catch exceptions). `results/comparisons.json` preserves every difference. Normalization removes only the experimental-Ractor warning and replaces the Ruby installation path with `PIN`.

* On 4.0.9, the only differences are the three excluded `mocha_shareable?` overrides above.
* Base 4.0.9 versus candidate master additionally differs in Ruby's wording of a pre-existing non-main-Ractor isolation error. Base and candidate give the same error on master. This is not a candidate regression.
* Ordinary ENV stubs and expects, unmet expectations, chained returns (including false/nil), explicit unstub, multiple methods, nested tests, errors in a test body, cleanup order and the next test all retain the expected 4.0.9 behavior on master.
* A saved full mock used in the next test still raises `Mocha::StubbingError`. A saved ENV stub method sees the fresh next-test expectation in both trees. A failed ENV expectation is followed by a clean next test.
* Thread-created and thread-called stubs and a suspended/resumed fiber agree. This does not establish thread safety: Mocha's README explicitly disclaims it. Calls through a stub from another Ractor still reject an unshareable Proc; setting up Mocha inside another Ractor still hits its existing unshareable constant.
* `ENV.singleton_class.any_instance`, stubbing the singleton class itself, class/module receivers, normal `extend`/prepend methods, `method_missing`/`respond_to_missing?`, Hash/Array/String subclasses with hostile conversion methods, and receivers with raising `hash`/`==`/`eql?` agree. Identity lookup also bypasses those overrides on ENV.
* `Ractor.current` is another tested shareable, unfrozen receiver: base works on 4.0.9 and fails on master; candidate works on both. `Ractor::Port.new` and `Ractor.shareable_proc` are frozen on these pins and continue to be rejected. Frozen ordinary receivers retain their exception; freezing an ordinary receiver after stubbing retains its successful invocation followed by the same teardown `FrozenError`.

## Body and comment audit

Every factual sentence was checked against the commands in the archive or the opened [Bug #22291](https://bugs.ruby-lang.org/issues/22291):

* The opening failure and exact error: the supplied standalone repro on base master.
* The Ruby restriction and ENV's status: direct `instance_variable_set` probes on ENV, Object, Class, Module and Ractor on both pins (`ivar-facts.log`), Ruby master's `variable.c`, and Bug #22291. Classes/modules still accept ivars.
* Mocha's `@mocha` storage: base source, latest released `v3.1.0` source and the reproduced failures from `stubs` and `expects`.
* Both named callers: fetched both linked files at their exact SHAs and the latest-release alternatives above. Calls still exist on their current default branches.
* Identity Hash and reset placement: exact diff plus the identity and lifecycle probes. Ordinary objects, classes and modules retain the previous path. Frozen shareable objects are rejected by the public API before cache storage.
* The final universal-equivalence sentence: contradicted by the three executed private-helper collision cases; remove it rather than describing private overrides upstream.

Citation currency was checked with GitHub and RubyGems APIs on 2026-11-27: Capistrano 13,011 stars, 91,641,504 downloads, release 3.20.1 on 2026-05-16, last push 2026-11-02; Sure 18,160 stars, latest release v0.7.6-hotfix.2 on 2026-11-21, last push 2026-11-27; Mocha 1,280 stars, 101,626,702 downloads, release 3.1.0 on 2026-03-14, last push 2026-09-22; Ruby 23,870 stars, last push 2026-11-27. None is archived. Sure is an app, not a RubyGems dependency. The current body orders Sure before the substantially distributed released gem; reverse that order.

Added comment lines were checked: the frozen-string directive and `@private` tags follow the repository style; the rationale explains why ENV needs external storage and why classes/modules are excluded. No independent correctness claim is hidden in those comments. The commit's claim about ivars is verified; its claim about lifetime is supported for the exercised lifecycle, not a proof about every private call.

Exactness checklist: singleton/private/prepended behavior, subclasses/conversions, added dispatch, frozen objects, standalone API loading and lifecycle ordering were exercised. No caller-produced collection is adopted or iterated by the change; those copying/live-iteration checks are inapplicable. Fiber suspension and resumed lookup were checked. The only new user-dispatch difference found is the excluded helper override. No existing public contract was relaxed to obtain passing results.

No Sure or Capistrano full application suite, older Ruby release, stress/concurrency-safety proof, or performance benchmark was run in this review. The claims above are limited to the exact two Ruby pins and scenarios retained here.
