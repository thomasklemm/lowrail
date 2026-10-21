# Verification-only test certificate: AR-only own-suite coverage

2026-10-21. The reviewed AR-only tier was published in
[985297a](https://github.com/thomasklemm/lowrail/commit/985297a4d50bab735f0c1c59fbfed4d0a96738f1).
**This is not production admission.** The requested 20-unit own-suite coverage is not complete:
two AR units execute; link/form and the remaining production units are gaps.
No app source, production artifact, seal epoch, pricing adapter or benchmark
cohort was changed. Fizzy's documented pinned red-but-identical baseline stays
unchanged in [own-suite-results.json](own-suite-results.json).

## Build and authorization

```sh
PARALLEL_WORKERS=1 lowrail build APP --sealed --verify-test --env test --jit interpreter
```

This writes `.lowrail/verification-test/`, never the production manifest or
materialized `facts.json`. Fresh discovery runs the original `bin/rails test`
and observes its final naturally available holders/caches. It does not call
`Facts.collect`, `Materialize.run`, Lowrail eager loading, or effectful
`Seal.install/activate`. Missing holders/schema caches are not warmed. Existing
synthetic form inventory remains disposable **build-only** work, after the
natural certificate was captured; it is never an activation witness.

Compilation captures the original app's compiler calls in another unchanged
own-suite process, using a disposable cold Bootsnap directory. Native/source,
compiler recipe, JIT and quarantine checks remain in place. This is expensive
verification plumbing, not a speed optimization or a production certificate.

The separate manifest tier is `sealed-test-v1`; `verification_test` contains
version, mode `verification-only`, observed policy and source-set fingerprints.
Runtime requires `LOWRAIL_SEALED=1 LOWRAIL_VERIFY_TEST=1 RAILS_ENV=test`, explicit
`PARALLEL_WORKERS=1`, and `LOWRAIL_DIR` pointing at that directory. Ordinary
production admission keeps its existing branch/checks. Both cross-environment
refusals have regressions: production artifacts under test, and test
certificates under production.

Authority starts **pending**, including delivered source during initializers.
The Minitest reporter's first `prerecord`, after unchanged helper loading and
executor startup, must observe Rails' actual executor: size 1, process policy,
and `@parallelized == false`. Environment variables alone do not authorize it.
Unknown, absent or parallel policy refuses. Lazy model activation uses the
existing natural-load hook, never a forced constant resolution.

Each AR unit stays pending until a successful return from the source-pinned
Rails `define_attribute_methods` is observed for its canonical, already-loaded
model, with both raw schema/generated flags true. Lowrail does not call the
generator. Completion releases a never-authorized decision once; it cannot
revive a retired unit. That first natural load stays original. Later schema,
builder or assumed-method mutation still retires the unit permanently.

The source set compares membership **and** digests, including app/config/lib/
test/db Ruby, Rake, ERB, YAML and SQL inputs; Gemfile/lock; root Rakefile;
bin/rails; config/boot.rb; test_helper and system base. Runtime and Bootsnap
Ruby sources are fingerprinted too. Policy reads allowlisted raw ivars, not
app getters or secret-bearing config serialization. Unsupported cache-store
or Bootsnap compiler/config policy refuses. Cache directory contents are not
authority; the gate exercises real enabled cold/warm Bootsnap caches.

## Assumption → invalidation map and limits

| Assumption | Dependent units | Invalidation / boundary |
|---|---|---|
| Environment, actual worker/config/JIT/compiler policy, source membership/digests | All verification units | Pending until exact match; mismatch/drift/unknown refuses; observed config/Bootsnap writes retire authority. Restoration does not reauthorize. |
| Effective `attributes_builder`, `instantiate_instance_of`, `_load_from_sql` bodies/visibility and lookup ancestry | That model's AR unit, including inherited/super holders | Passive destination-state observation plus bound-core named-method/ancestor snapshots before use. Unrelated lazy method generation is live, not a folded assumption. Sticky per-unit deopt; no global Seal ledger or epoch reset. This does not repair or exempt existing seal-check inherited-undef/opaque-holder gaps. |
| Hoisted stock 8.1 attributes builder | That AR unit | Existing AR epoch plus raw cached-builder identity before each use; replacement retires the plan, including a direct ivar write bypassing Rails' reset hooks. |
| Schema/default/table changes | AR recipe vs other consumers | AR retains live type conversion/initialization and validates its builder/epoch. **No complete folded form-schema/default/table observer is claimed.** Form refuses. |
| Nested literal tables/config/I18n/naming/routes | Link/form | Observer coverage is incomplete. Explicit terminal unit refusals; never an assumption that test mode makes these immutable. |
| Subscribers/notifier | No folded AR dependency | Acquisition, instrumentation and payloads remain live, including fixture subscribe/unsubscribe. A subscriber that changes a method/builder/schema assumption still retires that dependent unit before its next unsafe use. |
| Fixture rows, Current values, mail deliveries, request cache entries | Live data | Not automatically global boot mutations. Original Rails callbacks, transactions and resets still run. Mutating a watched method/config/schema assumption retires the dependent unit. |
| PID | All verification authority | Unexpected child clears G/K/V/Stats STATE, link ACTIVE/BUILDERS/request token, form witness/admission and model cached plans. Counters start at zero, child refuses permanently, and prior watched units record deopt. No parallel support. |

Refusal reasons include `verification_parallel_policy_unknown`,
`verification_test_initialization_pending`, `verification_config_or_source_set_mismatch`,
`verification_policy_or_source_drift`, `verification_attributes_builder_replaced`,
and `verification_unexpected_pid_original_only`. Unimplemented folded domains
use `verification_literal_table_observer_unavailable` and
`verification_form_config_schema_translation_observer_unavailable`.

### Link audit: not a table-only certificate

The literal link specialization folds **no Rails config or I18n value**.
Argument evaluation, option conversion, URL/default-url options, routing and
`to_param` remain live. `PRE_CONTENT_STRINGS["a"]` also remains a live lookup.
For the accepted literal name/single literal class sites it does assume:

- The `TAG_TYPES` binding is an exact frozen Hash, with nil default/default
  proc and nil `"class"`/`"href"` entries; those keys must remain ordinary
  attributes. The frozen blank/XML-name regexp bindings and stock escaping,
  primitive and constructor bodies must retain the semantics checked by
  `Sealed.literal_state?` and the source/body signatures.
- The effective view helper, TagBuilder and primitive method bodies,
  visibility and ancestry match the build certificate; the real native
  actual-holder predicate and delivered factory/dispatch bodies match too.
- The actual view/builder provenance stays certified, including **after**
  live conversion/URL/app code, not just at request entry.

A passive table observer alone cannot cover that method/constant/provenance
closure or all mid-call mutation. This slice does not expand admission: link
stays explicitly refused. Form stays refused too. The explicit pass allowlist
also rejects production token/collection and preload units; new registry
entries must never enter this tier through `Selection::sealed` implicitly.

The passive TracePoint, boot-policy capture and natural form seam are installed
in both explicit off/on arms. Fast-path installers are on-only. Complete
production cold-ancestry gates are **not** replaced by outcome equality here;
their known all-sealed Template/Preloader failures remain failures. Reconciliation
retains the published registry/setup/stats wiring and exact form token-observer
certificate/source pins. `form_scaffold_admission.rb`, `render_units.rb` and
`render_units_build.rb` are byte-identical to the upstream base. Production
token/collection installers do not enter the verification-only allowlist.

## Executed own-suite matrix

Reconciled onto upstream
[0dcd595](https://github.com/thomasklemm/lowrail/commit/0dcd59563b7d52a614bb86ba5e4e79aea65e93a3),
including the production passive admission, encoding fix and published pricing
documentation. The matrix was rerun after the final rebase. The local code head
was `3b1ebe2e70603cfb152bd9cd0098c046ba2e36ac`; the subsequent review-record commit
changes only these docs/results. The affected gem checks ran on the identical
runtime/test/runner bytes before the final docs-only upstream rebase; an exact
non-docs tree comparison confirmed no source changed.

Ruby 4.0.7, Rails 8.1.4, original public generated blog, seed 41231,
`PARALLEL_WORKERS=1`. Each row runs off, on-cold and on-warm, comparing exact
identity → outcome records, with no normalization. All 12 exits are zero.
Full records and **every artifact unit**, including zero hits/refusals, are in
[test-certificate-results.json](test-certificate-results.json).

| CI | Suite | Off / on-cold / on-warm | On-only differences | AR hits per on arm |
|---|---|---|---:|---:|
| unset | `bin/rails test` | 21 pass / 21 pass / 21 pass | 0 | Article 30, Comment 9 |
| unset | `bin/rails test:system` | 2 pass / 2 pass / 2 pass | 0 | Article 18, Comment 8 |
| 1 | `bin/rails test` | 21 pass / 21 pass / 21 pass | 0 | Article 30, Comment 9 |
| 1 | `bin/rails test:system` | 2 pass / 2 pass / 2 pass | 0 | Article 18, Comment 8 |

Actual `eager_load` is **false in both CI modes**: the original test command's
Rake preparation installs Rails' before-initialize override
`config.eager_load = config.rake_eager_load` (false). These historical default
invocations did not cover true eager loading. The explicit-path invocation
below closes that execution gap without editing the app's configuration.

Per on arm (cold/warm and both CI modes agree):

| Unit | Test hits / fallbacks / deopts | System hits / fallbacks / deopts | Reason / status |
|---|---:|---:|---|
| 0: Article instantiate | 30 / 1 / 0 | 18 / 1 / 0 | First natural generation original; subsequent loads optimized |
| 1: Comment instantiate | 9 / 1 / 0 | 8 / 1 / 0 | Same pending → natural completion boundary |
| 2: link | 0 / 23 / 0 | 0 / 43 / 0 | Literal-table observer unavailable; refused, not coverage |
| 3: form | 0 / 1 / 0 | 0 / 6 / 0 | Config/schema/translation observer unavailable; refused, not coverage |

Off counters are all zero. Discovery produces four candidates, not the prior
20-unit production artifact: the other 15 production AR holders/caches were not
naturally discovered, and preload has no passive test certificate. Other
unsupported pass families are explicit build-ledger refusals. In particular,
`PreloadBuild`, `TokenTagBuild` and `CollectionRenderBuild` each record
`verification-only passive certificate not implemented for this pass`; they
produce no artifact unit or H/F/D coverage. No claim follows for those missing
units or for production execution.

## Documented explicit-path invocation: actual eager loading

Rails 8.1.4's `TestCommand#perform` calls `test:prepare` when the CLI has no
explicit test path/name. In this generated blog, tailwindcss-rails 4.6.0
enhances that task: **`test:prepare → tailwindcss:build → environment`**.
Rails' `environment` task registers a `before_initialize` hook that assigns
`config.eager_load = config.rake_eager_load`. It runs after `test.rb` selected
`ENV["CI"].present?`, replacing true with the default false. This is the
[documented Rake eager-loading policy](https://guides.rubyonrails.org/v8.1/autoloading_and_reloading_constants.html#eager-loading),
not a Lowrail setting. Changing `rake_eager_load` would require changing app
configuration; this task does not do that.

Rails also [documents explicit file/directory arguments](https://guides.rubyonrails.org/v8.1/command_line.html#running-tests).
`CI=1 PARALLEL_WORKERS=1 bin/rails test test/ --seed 41231` skips that Rake
preparation in the suite process, preserving the app's own `eager_load=true`.
An original off probe ran all 23 tests / 68 assertions successfully; their
identities are exactly the union of the 21 ordinary and two system identities.
An explicit `test/` includes system tests, unlike the no-path default.

Set `LOWRAIL_VERIFY_TEST_DIRECT=1` when building the verification artifact to
use this invocation for both passive discovery and original compiler capture.
The mode is opt-in and is bound into the certificate policy alongside the
**observed** eager flag, executor and Bootsnap policy; the flag itself is not
an eager-loading witness. The default invocation is unchanged. A mode change
after authorization retires authority stickily, including after restoration.

Reproduce the direct matrix with:

```sh
script/blog-test-certificate APP NEW_RESULTS_DIR CHROME_BINARY --direct
```

The runner first executes the public `db:test:prepare test:prepare` tasks
**off, in a separate process**, so database and Tailwind preparation are not
lost but their Rake boot cannot alter the suite process. Discovery/compiler
capture use `test/`; the matrix supplies the ordinary files explicitly and
`test/system/` separately. App config, tests and system driver are unchanged.
Every suite process has the same passive state observer off/on. It reads raw
policy and enumerates already-existing named AR subclasses after the suite;
it never loads a holder or generates schema/attribute methods.

The direct 12 arms and a fresh default-mode 12-arm control retain exact
identity/outcome, every-unit H/F/D/refusal and natural-holder inventories in
[test-certificate-eager-results.json](test-certificate-eager-results.json).
Both modes use off / on-cold / on-warm, seed 41231 and explicit worker 1.
All 24 exits are zero and all identities/outcomes match, after reconciliation
with upstream's production token continuation fix and documentation. The
reconciled base and exact changed-source digests are in the result record.
The direct true-eager arms still authorize **only Article and Comment**:

| Invocation / CI | Actual eager flag | Ordinary / system identities | On Article H/F/D (ordinary; system) | On Comment H/F/D (ordinary; system) |
|---|---|---|---|---|
| Default / unset or 1 | false | 21 / 2 | 30/1/0; 18/1/0 | 9/1/0; 8/1/0 |
| Explicit paths / unset | false | 21 / 2 | 30/1/0; 18/1/0 | 9/1/0; 8/1/0 |
| Explicit paths / 1 | true | 21 / 2 | 30/1/0; 18/1/0 | 9/1/0; 8/1/0 |

All off counters are zero. Link remains 0/23/0 ordinary and 0/43/0 system;
form remains 0/1/0 and 0/6/0, with the same explicit observer refusals. Token,
collection and preload remain pass-level refusals with no artifact units.
There is no production or speed claim and no parallel-worker coverage.

True eager loading changes the available holders, **not schema readiness**:
the named AR subclass inventory grows from 3 to 31 (including framework/gem
models). Only Article/Comment have naturally generated attributes and loaded
schema. The true-eager build ledger records 23 concrete AR candidates: two
lowered, 21 refused for `schema/attribute methods not naturally available`.
The other eager-loaded classes do not become eligible merely by existing.

A negative control keeps `LOWRAIL_VERIFY_TEST_DIRECT=1` but runs a true-eager
artifact through the no-path Rake-backed command. The actual false eager
policy refuses with `verification_config_or_source_set_mismatch` for every
unit: 21 original passing identities, zero hits. A mode mutation/restoration
also has a public sticky-retirement regression. Reconciled checks:
`cargo test --locked` passes 39 + 1 + 8; the affected gem run passes 50 tests /
775 assertions, with the same six named prerequisite skips listed below.

An earlier prepared direct attempt had **one on-only system-test timeout** in
the final CI=1 warm arm, while affected gem checks ran concurrently. Capybara
could not find `My First Article`; the captured page subsequently contains
that link, and the index response took 2.092 seconds. A navigation/wait race
is a hypothesis, not an established cause. The failed attempt's exact
outcomes/counters remain in the results JSON. After reconciliation, the full
matrices above ran sequentially after gem checks, without changing app code,
test code, driver configuration or timeouts; no failure was normalized away.

The coordinator then prescribed a **fixed six-run diagnosis**, not retries to
green: three alternating off/on pairs of exactly that CI=1 system command,
seed 41231, retained prepared app and original off/on Bootsnap directories,
serially with no concurrent gem checks. All six exit zero with both exact
identities passing and actual eager loading true. Each on arm has Article
18/1/0, Comment 8/1/0, link 0/43/0 and form 0/6/0 with unchanged refusals;
all off counters are zero. The earlier timeout remains **unestablished under
concurrent load**, not disproved or assigned a proven cause.

The same historical artifact was used, not a rebuilt artifact that could
silently refuse. Its only runtime-pin difference was the later production
token continuation fix. A private mount namespace exposed the artifact's exact
historical `render_units.rb` read-only at its original path; every runtime/app
source pin matched before the six runs. The working checkout retained the
published production fix throughout. No app/test/timeout or cache-directory
edit was made. All six records and the exact artifact digest are retained in
the results JSON's `bounded_timeout_diagnosis` section.

The previous review slice had one hit then one sticky deopt per AR unit,
from natural attribute generation. Delaying authorization alone preserved
parity but exposed further overly broad retirements: `append_features` on
Callbacks while including it into unrelated CurrentAttributes, fixture
`Notifications.unsubscribe`, `DescendantsTracker.reject!(classes)` (which
mutates its argument), and a MessagePack lazy hook's `Base.class_eval`.
The observer now checks the **destination's assumed facts**, not just these
method names/source receivers. No deopt counter or Seal epoch was cleared to
obtain the improved liveness above.

## Additional probes and validation

- Public Rails/Bootsnap regression: pending → natural generation → repeated
  real AR hits with no deopt across Current reset, subscribe/unsubscribe and
  unrelated method definition. Asymmetric rows/statuses are preserved.
- Public parent-active → fork-child-original regression: child has zero
  inherited or new hits, two original-path query fallbacks, one watched-unit
  deopt, and explicit PID refusal. Seeded G/K/V/STATE, link builder witness/
  ACTIVE/request token and form authority are cleared before child use;
  repeating initialization cannot reauthorize. Parent remains optimized.
- Actual config mutation followed by restoration: original-only, sticky refusal.
- Direct cached-builder replacement bypassing Rails reset hooks: same selected
  rows, prior hits then original query fallbacks and one deopt,
  `verification_attributes_builder_replaced`;
  restoring the builder does not reauthorize.
- Bootsnap compiler setter, even assigning the same compiler: conservative
  whole-tier retirement, same rows, prior hits then original query fallbacks
  and one deopt.
- Named-method replacement/restoration and a real schema reset also retire
  stickily. These config/builder/Bootsnap/method/schema cases are public
  regressions in `gem/test/test_certificate_test.rb`, not deleted scratch
  probes. No application source or production runtime path is changed.
- Missing initialization/pending authority, missing/parallel workers, source
  additions/removals and cross-environment refusal regressions pass. An actual
  two-worker Rails policy refuses even with `PARALLEL_WORKERS=1`; restoring the
  single-worker executor does not reauthorize (no workers are spawned).
- The new liveness regression run unchanged against the previous review code
  fails: expected 8 hits, actual 6. The original 12-arm one-hit/deopt baseline
  and intermediate conservative retirements did not demonstrate sustained
  optimized execution; the current nonzero-hit, zero-deopt matrix above does.
- `cargo test --locked`: 39 unit + 1 types MCP + 8 verify pass.
- Affected gem tests: 50 runs, 765 assertions, zero failures/errors, six named
  prerequisite skips. The five earlier integration gaps remain; the new
  production token/collection corpus test also skips for the same missing
  canonical fixture. Those integrations are not claimed as covered; actual
  blog Bootsnap cold/warm runs above completed. No Callgrind or measurements.

The named prerequisite gaps are:

| Test | Missing prerequisite |
|---|---|
| `FormScaffoldTest#test_public_sealed_build_preserves_forms_observers_and_refuses_custom_builder` | `.corpus/real-blog-r4` |
| `LoaderTest#test_cached_hijacks_do_not_inherit_bootsnap_compiler_options` | require-hooks/Bootsnap integration gems |
| `LoaderTest#test_freezolite_and_bootsnap_in_every_order_with_cold_and_warm_caches` | freezolite/require-hooks integration gems |
| `LoaderTest#test_load_iseq_state_matches_off_during_build_and_cold_and_warm_delivery` | require-hooks/Bootsnap integration gems |
| `LoaderTest#test_source_transforms_are_not_bypassed` | freezolite/require-hooks integration gems |
| `FormScaffoldTest#test_passive_production_token_and_collection_public_artifact` (new upstream test) | Same `.corpus/real-blog-r4` fixture |

Run the public fork, liveness, policy and sticky mutation regressions with
`ruby -Igem/lib:gem/test gem/test/test_certificate_test.rb`. They generate a
disposable Rails/Bootsnap/SQLite fixture, not a private app or existing artifact.

Reproduce with `cargo build --locked`, then
`script/blog-test-certificate APP NEW_RESULTS_DIR CHROME_BINARY` under Ruby
4.0.7. It uses an external orb Chromium wrapper for no-sandbox/dev-shm flags;
the app's system-test driver and test sources remain unchanged. The runner
refuses an existing result directory and fails on missing/empty outcomes,
nonzero suite exits, any exact outcome difference, or an on arm with zero hits.

The approved AR-only publication and actual eager-loading evidence do not close
the link/form/20-unit contract gap. Do not describe this tier as full sealed
own-suite coverage. Token/collection test admission remains a separate design,
implementation and review; production witnesses do not certify test state.
Parallel workers remain uncovered.
