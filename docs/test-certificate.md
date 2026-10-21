# Verification-only test certificate: isolated review slice

2026-10-21. **Local review implementation, not production admission or main
integration approval.** The requested 20-unit own-suite coverage is not complete:
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
their known all-sealed Template/Preloader failures remain failures. This branch
must be reconciled with the sealed owner's separately owned registry/setup/
stats/form-admission boundary before any integration.

## Executed own-suite matrix

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
`config.eager_load = config.rake_eager_load` (false). Directly requiring the
environment with CI=1 gives true, but is not the unchanged own-suite command.
Nothing forces it true here. True eager-load execution remains uncovered.

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
unsupported pass families are explicit build-ledger refusals. No claim follows
for those missing units or for production execution.

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
- Affected gem tests: 48 runs, 760 assertions, zero failures/errors, five named
  prerequisite skips (canonical corpus form fixture; require-hooks/freezolite
  loader integrations). Those integrations are not claimed as covered; actual
  blog Bootsnap cold/warm runs above completed. No Callgrind or measurements.

Run the public fork, liveness, policy and sticky mutation regressions with
`ruby -Igem/lib:gem/test gem/test/test_certificate_test.rb`. They generate a
disposable Rails/Bootsnap/SQLite fixture, not a private app or existing artifact.

Reproduce with `cargo build --locked`, then
`script/blog-test-certificate APP NEW_RESULTS_DIR CHROME_BINARY` under Ruby
4.0.7. It uses an external orb Chromium wrapper for no-sandbox/dev-shm flags;
the app's system-test driver and test sources remain unchanged. The runner
refuses an existing result directory and fails on missing/empty outcomes,
nonzero suite exits, any exact outcome difference, or an on arm with zero hits.

**Review decision still needed:** the two-unit evidence is useful but does not
close the link/form/20-unit contract gap. Do not merge or publish this tier as
full sealed own-suite coverage. Sealed-owner admission review and the shared
file boundary precede any main integration. The production token/collection
boundary is now published in
[ae025b0](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb),
but was not imported into this isolated branch. After admission-owner approval,
rebase onto current origin/main and rerun the complete matrix on that rebased
head before any main integration. True eager loading and parallel workers
remain uncovered.
