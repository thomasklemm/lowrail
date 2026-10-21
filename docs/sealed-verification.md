# Verifying sealed production behavior

2026-10-21. **Option C accepted; bounded blog slice implemented below.**
The wider request/job design remains a proposal, not a new admission gate.
No measured cohorts. Run suite-derived behavioral scenarios
through an **external driver against cold, real production off/on processes**.
Use captured replay where it is faithful, adapters where the suite depends
on process-local test machinery, and an explicit uncovered ledger everywhere
else. Do not admit a production artifact into `RAILS_ENV=test` to get hits.

## Full ancestry census

The cold observer now records **complete inherited ancestry**, without
filtering Lowrail modules, for Object, Kernel, BasicObject, the named holders
in every certificate/fact, ActionView::Template when templates are delivered,
and the controller's already-cached view class. It reads names and caches;
it never constructs a view, resolves an autoload or scans the heap. Missing
holders stay null. The before/after-request stages are compared between arms,
not equated to one another: natural rendering may populate a previously
missing view/tag class. Anonymous ancestors retain their positions as null;
this is a named-chain census, not a cross-process object-identity proof.

The earlier narrower API/objspace/hook witness missed an on-only inherited
`Lowrail::Guard::ObjectHooks`. Form/link units have no method-fact dependency
on that hook. Hook admission now depends on selected facts; file delivery has
an independent ModuleHooks/Bootsnap dependency. Required hooks are symmetric
with explicit LOWRAIL=0, while that arm still delivers and activates nothing.
Missing, incompatible, quarantined and empty builds remain no-ops.

**Open exactness failures, not normalized:** the all-sealed artifact still
adds `Lowrail::Templates::CompiledSource` to `ActionView::Template` and
`Lowrail::PreloadPlans::Hook` to `ActiveRecord::Associations::Preloader` on
only. The expanded cold test is intentionally red for this artifact. Existing
scalar-event/body/SQL equality and old narrow cold passes cannot override that
failure. The follow-up must select these seams only where needed and make
needed seams symmetric without activating optimization in the off arm.
Historical measured runtimes/results are retained, not rescored.

Fresh isolated production/YJIT artifacts on base
[`315d56f`](https://github.com/thomasklemm/lowrail/commit/315d56f7dd8982c3eb974536c252b4aeb3709a81)
plus the hook fix, each with its own off/off/on seed-0 companion:

| Artifact | Files / templates | Full named-chain differences, cold / after GETs | Coverage |
|---|---:|---:|---|
| Form only | 0 / 0 | **0 / 0** | Still explicitly refused by this prerequisite runtime; zero hits, unexercised |
| Link only | 2 / 0 | **0 / 0** | Index/show **5/2 hits**, no fallbacks; recorded fields exactly equal |
| Default | 0 / 0 | **0 / 0** | Empty quarantined default, zero hits; unexercised, not support coverage |

The form/default comparisons have zero off/off and off/on differences and
zero capture errors, but are not renamed to coverage passes. Neither requires
ObjectHooks; only link's file delivery requires ModuleHooks, identical in both
arms. The all-sealed raw result remains `rejected_off_control`; its seed-0 and
seed-1 companions both reject **only `cold_witness`** after the expanded
census. The corresponding real cold test remains red, not normalized or
marked skipped. Targeted guard/loader/admission checks pass on 4.0.7
(43 tests / 1,319 assertions, no skips), guard/manifest checks on 4.1-preview1
(12 / 121, no skips), and `cargo test --locked` passes. This is an untimed
prerequisite study, not a pricing run or passive-form admission result.

Manifest SHA-256, form/link/default respectively:
`24210f4b799f203ad6bb9667546d640dac7b4501035ac4d8f971180d44e05a62`,
`cff8c2f6b3fd2be6af3d46f36485e7983b778c89bce0008a2cc432dade78c9f1`,
`8d8609c1e5b4fe31429a82f295a63c4bb1ae2cca91ca89ff3328103dec2d8fd6`.
Private retained workers/artifacts: `.lowrail/private/hook-census-1/`;
`isolated-summary.json` records both ancestry stages and the exact verdicts.

## Current runtime: passive admission or explicit refusal

The cold findings below exposed a correctness bug, not a fair-comparison
artifact. Runtime `Sealed.activate` used `Materialize.run`: on performed **81
boot SQL reads** (primary 15, cache 6, queue 54, cable 6), repeated eager-load
hooks, forced `ActionController::API`, and required objspace. The separate form
audit also generated attributes, constructed a controller/view, looked up I18n
translations and compiled ERB. None of that belongs in runtime admission.
Build-time materialization and the stock form audit remain unchanged.

Runtime link admission now only reads already-loaded dependencies and the
controller's cached view class. It never requires objspace, invokes eager-load
hooks or constructs that cache. The existing request entry can retry after
the **app itself** supplies prerequisites; all source/body/visibility/delivery/
literal-state guards still apply. A missing prerequisite is a visible refusal.

The current form certificate has no passive equivalent for its synthetic
probes. It is therefore **not activatable in production**, even after a
natural form render. `FormScaffold.activate` and runtime inventory checks
refuse with: **"form certification requires runtime controller/view/I18n/ERB
effects; passive activation unavailable; keep original"**. No helper variant
is installed. A form's intentional 0 hits / 0 fallbacks is a **coverage
rejection**, not an activation or support claim. Build eligibility and its
renamed-app/custom-builder tests remain intact; this is not a weakened audit.

`LOWRAIL_DEBUG=1` shows activation refusals in the diagnostic log. Stats and
Minitest/RSpec outcome reports also retain `unit_refusals`, including a refused
installer that never put a counting guard into the app. `lowrail explain`,
doctor and both MCP explain tools show the form's current `activation_refusal`
even without stats. Historical build decisions/counters stay historical.

### Bounded readiness recheck

Fresh production/YJIT build on base
[`88506d9`](https://github.com/thomasklemm/lowrail/commit/88506d9b10a5177fee768b64fa6f02440e7f0d47)
plus this fix; private evidence `.lowrail/private/blog-production-readiness/`.
Run the same raw off/off/on sequence and both declared entropy companions
(seeds 0 and 1), sequentially restoring the same four databases. No measurements,
exclusions, prepared-Materialize companion or new support/certification claim.

| Observation | Before | After, off1 / off2 / on |
|---|---|---|
| Boot SQL, primary/cache/queue/cable | off 0; on 15/6/54/6 | **0/0/0/0 in every worker** |
| Cold index / show SQL | index 14/14/3; show 2/2/2 | **index 14/14/14; show 2/2/2**, primary only; exact text/binds/order |
| Hooks / features | 12 extra cold hooks, API and objspace on only | **identical hook execution sequence**; API absent and objspace unloaded before/after both GETs |
| Early and post-boot app-style callbacks | before_eager_load repeated; controller Base + API on | each registration executes **once**, controller Base only, including late registrations |
| Raw unpinned gate | rejected_off_control | **rejected_off_control**, unchanged: both response comparisons contain natural entropy |
| Declared seed 0 and 1 comparisons | rejected cold SQL/loads | **exact agreement for these two GETs** in responses/all headers, SQL/binds, effects, captured events, entropy trace, loads/features and cold witness; no capture errors |

All 18 scenario assertions pass, but this is **not sealed form/link coverage**:

| Unit | Before index hits/fallbacks; show hits/fallbacks | After |
|---|---|---|
| 18 sealed/link_to | 5/0; 2/0 | **0/0; 0/0**, objspace not already loaded |
| 19 sealed/form_scaffold | 0/0; 1/0 | **0/0; 0/0**, explicit effectful-certificate refusal |
| 0 preload plan | 1/1; 0/0 | unchanged |
| 1 Article instantiate | 2/0; 1/0 | unchanged |
| 2 Comment instantiate | 2/0; 1/0 | unchanged |

The comparator still rejects altered bodies/headers, SQL/binds/order, effects,
events and loads; it now additionally compares boot SQL by database and the
cold hook/feature witness. The minimum off/off control is retained. The same
19 ordinary and two system test IDs listed below remain uncovered.

### Coverage rejection, including the larger controls

The interpreter form checker still compares all **192 pairs** for both `none`
and `render_subscriber`. Both remain exactly equal in their recorded response,
SQL, event, assignment and model-state fields, but the unchanged coverage gate
now exits 1: **`production form coverage missing`**. Historical form hits were
**105 per control → 0**, with zero form fallbacks. Link is also 0/0 because
objspace was not app-loaded; a historical aggregate link count for these
controls was not retained, so no before-count is inferred. Other current
hits are preload 45, Article 261, Comment 171; preload falls back 47 times.
Private evidence: `.lowrail/private/blog-form-readiness/`. These are coverage
rejections, not successful sealed-form verification.

The public link regression retains **1 hit / 0 fallbacks** in both its
original and renamed application when the app explicitly loads objspace and
its cached view class exists. Removing that cache gives an explicit refusal,
does not recreate it or load features; after the app naturally creates it,
request-entry admission succeeds. Foreign view/builder overrides still take
the original path. This is not a substitute for the blog C coverage lost above.

The four required real-blog gem gates (three facts checks and the 21-test
empty-artifact off/on suite) remain green. They never exercised form/link,
so their form/link hit counts stay **0 → 0**. A separate YJIT-matched verify
using the production C artifact in test mode also gives **21/21 outcomes and
125 queries identical**, zero hits/fallbacks, with the existing explicit
production-only artifact refusal. No test-env admission was added.

### Correctness checks for this fix

On base `88506d9` plus this change, with no test exclusions:

- `cargo build --locked && cargo test --locked`: **37 unit + 1 types/MCP +
  8 verify integration tests pass**.
- From `gem/`, `LOWRAIL_STRICT_GATES=1 mise exec -- rake test
  TESTOPTS='--verbose --seed=1729'`: Ruby **4.0.7, 156 tests / 6,775 assertions,
  zero failures/errors/skips**. The final additional form log/CLI assertions
  also pass separately: **1 test / 63 assertions**.
- The same full strict command with `mise exec ruby@4.1.0-preview1` and
  `LOWRAIL_TEST_CORPUS_ROOT` pointing to disposable prepared corpus copies:
  **156 tests / 5,885 assertions, zero failures/errors, three named skips**:
  `BlogProductionTest#test_cold_sealed_admission_does_not_prepare_the_app`,
  `SealedLinkTest#test_cold_opt_in_delivery_preserves_response_effects_and_refuses_foreign_receivers`,
  and `FormScaffoldTest#test_public_sealed_build_preserves_forms_observers_and_refuses_custom_builder`.
  Each explicitly requires Ruby 4.0.7; no preview sealed-activation claim.
- The first preview attempt recorded three failures: missing RSpec matchers
  (two reporter tests), and missing native dependencies in the Rails profiling
  bundle. After installing those prerequisites, targeted checks and the entire
  strict suite above pass. Native Nokogiri/SQLite/FFI source variants were
  prepared only in disposable corpus copies, preserving gem versions and the
  original corpus locks; the private Rails fixture bundle was prepared likewise.

### Optional native holder prototype: link coverage recovered

The follow-up on `fb07512` replaces link's objspace dependency with
`Lowrail::Native.exact_class?(object, expected)`. Its complete operation is
`CLASS_OF(object) == expected`, using Ruby's public C API. Returning a boolean
avoids exposing internal Class/ICLASS objects (which objspace sometimes wraps).
No singleton-class flag branch is needed: an eigenclass pointer cannot equal
the certified ordinary view/Hash/Regexp class. This is **not** `object.class`,
`instance_of?`, method enumeration, heap walking or eigenclass construction.
There is no Ruby dispatch, allocation or GC operation in the primitive.

This is an explicitly built, optional prototype: run **`rake compile` from
`gem/` under each chosen Ruby**. It needs the Ruby headers and a C compiler.
Engine/version/revision/platform-specific directories keep the two builds
separate. The gem ships the source and Rake task, not a mandatory installation
extension: no compiler is needed to install/require the Ruby gem. It never
compiles during application boot. A failed rebuild removes the prior output;
an absent or unloadable binary leaves link visibly refused with **"Lowrail
native actual-holder primitive unavailable; run rake compile; keep original"**.
There is **no objspace fallback**, including when the app loads objspace itself.

Requiring Lowrail attempts the native require unconditionally, including
`LOWRAIL=0`; the off/on loaded features match in the public regression. The
extension defines only `Lowrail::Native.exact_class?`. The link certificate
pins the actual native binary's SHA256 and the method's metadata, as well as
every existing source/body/visibility/delivery/literal-state guard. The shared
literal-table audit accepts a predicate so the separate form build-time
objspace audit remains unchanged. No form file or runtime form policy changed.
Admission still only reads the cached view class: the missing-cache regression
refuses without creating it or loading features, then admits at request entry
after the app supplies it naturally.

On **both Ruby 4.0.7 and 4.1-preview1**, the native admission decision matches
`ObjectSpace.internal_class_of(object).equal?(expected)` for stock instances,
private singleton overrides, singleton prepends, undef, `respond_to_missing?`,
empty eigenclasses, subclasses, Hash/Regexp and immediate values. App reflection
overrides are not invoked. In separate diagnostic processes, 10,000 warmed
calls allocate **0 objects**, keep pending GC **marking → marking** with the
collection count unchanged, and leave eigenclass counts **76 → 76** (4.0.7) /
**71 → 71** (preview). Heap walking is isolated from the GC-state experiment;
objspace is loaded only for diagnostic oracle/counting processes, not admission.
Disassembly of both compiled predicates contains no calls; the C operation
only reads the dispatch class and compares pointers.

Fresh blog production/YJIT artifact, same two GETs, restored four-DB snapshot
and minimum raw/seed-0/seed-1 off/off/on sequences:

| Observation | Before native primitive | After |
|---|---|---|
| Link 18 index / show hits, fallbacks | 0/0, 0/0 | **5/0, 2/0** in raw and both companions; no link refusal |
| Form 19 index / show hits, fallbacks | 0/0, 0/0 | **unchanged 0/0, 0/0**, explicit passive-activation refusal |
| Boot SQL, primary/cache/queue/cable | 0/0/0/0 | **0/0/0/0 in all nine workers** |
| Request SQL | index 14; show 2 | **index 14/14/14; show 2/2/2**, primary only; exact text/binds/order |
| Hooks / app features | passive witness | **146 identical cold hook executions**; early/late callbacks once each; API absent, objspace unloaded before/after requests |
| Declared entropy companions | exact for two GETs, link unexercised | **both exact for two GETs**, now with link hits; no exclusions |
| Raw gate | rejected_off_control | **rejected_off_control retained**, not normalized or reclassified |

Private evidence: `.lowrail/private/blog-native-holder-final/` and
`.lowrail/private/native-holder-{gc,eigen}-r{4,41}.json`. These are correctness
diagnostics, **not measurements**, whole-app support or new certification.
The same 19 ordinary and two system test IDs remain uncovered. Preview tests
the primitive, not unsupported preview sealed admission. Form's historical
measured result and coverage rejection remain unchanged.

Final strict full suites (`LOWRAIL_STRICT_GATES=1 rake test`, seed 1729):
Ruby 4.0.7 **158 tests / 6,831 assertions, zero failures/errors/skips**;
4.1-preview1 **158 / 5,910, zero failures/errors**, with three named
4.0.7-only skips (BlogProduction, SealedLink and FormScaffold). The first
preview attempt failed a missing Herb native dependency; installing the
same-version source dependency in the disposable corpus bundle fixed setup,
and the complete strict rerun above passed. No production guard was changed
to make preview admission pass. Cargo's **37 unit + 1 types/MCP + 8 verify**
tests pass. A locally packaged/installed gem requires without a native build,
then its shipped source compiles and loads without objspace. Private full
logs are `native-full-r4-final.log`, `native-full-r41.log`, the retained
`native-full-r41-missing-herb.log` and `native-package.log` under
`.lowrail/private/`.

## The evidence gap and the claim we can actually make

[`Manifest`](../gem/lib/lowrail/manifest.rb) admits sealed-v1 only with the
production environment, explicit acceptance and registered sealed-only units.
[`Sealed.activate`](../gem/lib/lowrail/sealed.rb) and
[`FormScaffold.activate`](../gem/lib/lowrail/form_scaffold.rb) have additional
production/source/inventory predicates. These are independent gates; matching
the manifest alone does not prove activation. Keep every refusal.

The [breadth probe](../fixtures/corpus/breadth_production_spec.rb) has two
examples/app. Wikino and RubyToolbox hit specific sealed paths; CRM does not.
The [reported results](compat.md#sealed-production-probes-bounded-non-vacuous-coverage)
are smoke/contract evidence, not whole-suite active coverage. Default/opt-in
zero-hit suites test noninterference and refusal, not sealed semantics.
The historical copied-blog form probe's reporter/inventory refusal and the
later tracing recheck remain recorded below. Neither supersedes the current
explicit passive-activation refusal ([explain](types.md#explain-a-build-not-an-inferred-promise)).

No finite suite proves an app's **whole behavior on all inputs**. The attainable
claim is equivalence over the suite's mapped production scenarios, with an
explicit denominator: original test IDs, converted/scenario IDs, assertions,
request/job paths, exercised units, hit/fallback counts and uncovered reasons.
One successful request must not stand in for every example or input shape.
Keep the existing app-suite outcome result alongside this new evidence.

## Options

| Approach | What it proves when successful | What it cannot prove / main risks | Cost |
|---|---|---|---|
| **A. Capture test traffic, replay requests/jobs into production off/on** | Production differential equivalence for the recorded inputs, initial state and observed effects, with the real artifact. No test runtime inside production workers. | Raw test cookies/CSRF, host policy, adapter state, open fixture transactions and stubbed services are not portable. Direct model/helper calls and assertions outside HTTP/jobs are absent. A recorded response is not a business oracle; both arms can be equally wrong. Blindly enqueueing every captured child job executes effects twice. | Moderate runner work; app-specific snapshot, session and queue adapters. At least cold off/off/on runs plus state restores and capture. Database/service snapshots may dominate. |
| **B. Entire suite inside production with a separately certified test seam** | Executes original assertions and direct calls; can cover helpers/models missed by HTTP, but only for a newly certified harness-plus-production configuration. | Tests load support modules, change subscriptions, stub methods, use fixture transactions and swap job adapters after boot. Production may reject the suite or inventory before any useful test. Certifying a test seam is not certifying ordinary deployment; checkpoint restoration misses in-flight mutations. | Superficially cheap to launch; high and open-ended audit cost across each suite/gem/version. Requires a new explicit contract/admission design and adversarial regressions. |
| **C. External suite-derived scenario driver (recommended)** | Retains production behavior, the real artifact and applicable suite assertions. Follows each arm's real login/redirect/session/job flow rather than replaying captured test internals. Provides a coverage map and can include separate directly invoked root-job scenarios. | Needs adapters/translation; unit-only methods, stubs and transaction-local state do not magically transfer. Still finite evidence; concurrent schedules and unsampled inputs remain gaps. | Moderate/high initial harness and app-adapter cost; bounded thereafter by scenarios plus cold/state controls. More work than two-example probes, less unbounded certification than B. |
| **D. Test-env artifact / test-adapted sealed build** | May help debug a compiler transformation in that distinct environment. | Does not exercise the production artifact, inventory, eager loading, caches, middleware or JIT certificate. Removing an environment predicate or forging `Rails.env` is not a certified seam. | Cheap experiment, wrong evidence for this task; do not substitute it for a production gate. |

A is an input source for C, not a claim of complete conversion. Reuse original
test assertions in the external driver when they describe production behavior;
keep explicitly test-environment-only assertions in the unchanged suite.
Disagreements between **test-off** and **production-off** are portability
findings, not Lowrail bugs or automatic reasons to weaken production checks.

## Recommended design

```diagram
             ┌──────────────────────────────┐
             │ Suite scenarios + state seed │
             └─────┬────────────────┬───────┘
                   │                │
                   ▼                ▼
            ┌──────────────┐ ┌──────────────┐
            │ Off: real    │ │ On: same     │
            │ production   │ │ + artifact   │
            └──────┬───────┘ └──────┬───────┘
                   │                │
                   ▼                ▼
             ┌────────────────────────────┐
             │ Assertions + exact effects │
             │ + hits + uncovered ledger  │
             └────────────────────────────┘
```

The two arms are logically paired but **run sequentially by default**, never
against a shared live database or fixed Capybara port at the same time.
The minimal cold comparison costs three scenario executions (off/off/on)
with three state restores; capture controls, repeated off/off stability
checks and warm sequences are additional. Fresh process startup per isolated
scenario is intentionally more expensive than running the suite once.

### 1. Bind the scenario corpus to its evidence

Pin source revision, lock hash, Ruby/Rails, JIT at build/startup/after initialize,
artifact/manifest/certificate digests, loader order/cache policy, scenario
adapter version and input/snapshot digests. Produce the sealed artifact from
the actual production boot, at the same deploy root or through the existing
explicit relocation certificate. Do not rebuild between comparison arms or
silently load a test certificate. Mismatched modes are **mode mismatch**, not
behavioral coverage. Record artifacts with no units separately.

Capture external boundary inputs during an ordinary lowering-off suite and
map each test to ordered root requests, root jobs, assertions and setup.
The capture itself needs a recording-off/recording-on control; it may affect
loading, randomness or timing. Do not assume capture is observationally free.
Direct object calls, callbacks triggered only inside a rolled-back transaction,
stubbed inputs, unsupported WebSockets/streaming, missing services and unowned
child processes are explicit uncovered entries, never successful replays.

### 2. Recreate real state, not test transactions

For each independent scenario, restore the same committed DB contents,
sequences, schema and relevant queue/cache/storage/service state before each
arm. Test fixture transactions are not visible to a production connection:
export their logical seed through an audited adapter and validate its digest,
or mark that scenario unavailable. Copying the physical DB while a test holds
uncommitted fixtures is not a solution. Preserve multi-request session state
within a scenario and commit/after_commit effects; reset between scenarios.

Use only disposable databases/services with egress denied or replayed. Capture
mail, files/blobs, cache/Redis writes, enqueue/dequeue/retry state, webhooks,
notifications and external requests in separate per-arm sinks. The sink adapter
and its behavior are declared, symmetric inputs, not evidence about the real
external service. No live production DB or outbound delivery. Keep raw secrets
and snapshots private. Sequential runs can reuse the same logical DB name,
deployment path and port after an explicit stop/reset, avoiding accidental
SQL/config differences from arm-specific infrastructure names.

### 3. Keep test frameworks outside the production workers

Run assertions in the driver; production workers load their real application
entrypoint and production queue adapters, not Minitest/RSpec doubles,
transaction helpers or time-travel helpers. A scenario performs login in each
arm and uses that arm's cookies/CSRF/redirect values as protocol inputs. It
must not send test-encrypted cookies to production or copy an on-arm response
into the off arm. Check those flows themselves, not just the eventual page.

Requests enqueue their own children normally; drain those children **once**
through the real adapter/worker chain. A separately tested root job is injected
only when no preceding scenario request already schedules it. Preserve payloads,
queue, retries, callbacks, transaction/after_commit boundaries and errors. An
inline/test adapter is a different workload, not a production worker proof.
Use explicit completion barriers for background work and bounded timeouts;
unfinished work is inconclusive/failing evidence, not a zero-effect result.

First establish cold off/off controls with exactly the production harness
and a predeclared capped repeat count, not retries until green. Then run
off/on with a restored seed, and a warm/multi-request scenario that
preserves caches and sessions within each arm. Bound attempts in advance and
retain rejected controls. Separate normal deployment (no instrumentation)
smokes from instrumented comparisons: the latter may only claim behavior in
the declared observed configuration until observer transparency is checked.

### 4. Compare more than today's verifier digest

* **Outcomes/oracles:** original scenario assertions, exceptions and completion
  status must agree off/on. Preserve status, body bytes, encoding and **all**
  headers/cookies; include streaming chunks and their order when supported.
  A matching digest of a wrong error page is not a pass.
* **SQL:** preserve order, SQL, bind **values**, cache flags, row counts and
  transaction boundaries per request and per job. The existing
  [`SqlTrace`](../gem/lib/lowrail/sql_trace.rb) deliberately masks timestamps/
  long numbers and records bind classes rather than values; its digest alone
  cannot establish exact production query equality. Background work must be
  attributed to a causal request/job and checked on its own worker thread;
  today's other-thread multiset advisory is not job equivalence evidence.
* **Effects:** compare committed DB/sequence state and captured effect logs,
  including order/multiplicity, rollback, missing effects and duplicate effects.
  Job execution that returns equal HTTP but loses an enqueue is a failure.
* **Events/contexts:** retain the existing response/SQL/event/assign checks
  where the pass promises them, including errors, nested render/capture and
  subscriber payloads. Do not infer instrumentation equivalence from HTML.
* **Coverage:** require delivery/activation evidence and non-zero per-unit
  fast-path hits for every claimed unit; show fallback and refusal reasons
  per scenario. A green all-fallback run is noninterference only. Aggregate
  hits cannot certify an unexercised form or a refused job process.

Time, secure randomness, signed/encrypted sessions and concurrent schedules
make literal byte comparison difficult even off/off. Declare and audit any
input controls; use them identically in separate companion scenarios, retaining
the uncontrolled result. A seeded companion is not proof of all production
random paths. Do not globally stub SecureRandom/time or strip tokens, headers,
timestamps and SQL binds until green. A protocol field that is intentionally
opaque needs an explicit reviewed relationship/security assertion and a
separately labeled weaker claim; it is not literal byte equality. Unresolved
off/off variation leaves that claim inconclusive. Existing pinned controls
remain exact, revision/lock-bound and visible; SQL controls do not excuse load
differences. Do not grant a blanket replay exemption for nondeterminism.

### 5. Invariants 6 and 7 remain admission requirements

**Invariant 6 — exact mid-request:** end-to-end equality is regression evidence,
not certification that every later helper, `to_param`, callback or foreign
receiver is safe. Keep source/receiver/value certificates and original
evaluation order; use asymmetric errors, coercions, nested calls, per-instance
overrides and post-entry mutation scenarios. For any contract-violating path,
demonstrate refusal before effects or an explicitly supported safe continuation;
an epoch bump after an unchecked expansion is not protection. Suppressed or
restored-between-checkpoint mutation and native changes remain detector gaps.
If certification cannot cover a boundary, retain original code or refuse;
neither a clean replay nor a test-only exclusion authorizes that expansion.

**Invariant 7 — preserve loading:** compare off/on cold boot and scenario-stage
load censuses, actual require order and on_load order in every request/job
process; keep the loader's owner/source_location/chain and adapter selection.
Observers must not constantize an autoload or preload targets merely to count
hits. Apply the existing exact load gate, not response-based inference, and
retain a true no-Lowrail baseline to expose effects shared by the two
instrumented arms. An observer-induced change requires fixing the observer
or reporting unavailable evidence, never ignoring the inventory mismatch.
The Bundlebun refusal and unknown delivery recipes remain unchanged. A suite
replay must not turn its eager loading into a new application boot policy.

For B, both invariants would require certifying every test helper's live
effect on expanded targets, in addition to the production contract. Merely
preloading all test support and pinning a different inventory does not prove
purity, no in-flight mutation or the deployed load order. This is why B is not
the first implementation recommendation, even though its assertion coverage
is attractive. A future seam would be explicit, versioned and separately
certified, never an env-var bypass for a normal production artifact.

## Relationship to existing gates and a bounded first step

Keep unchanged: gem/Cargo regressions, ordinary default/all-opt-in suite
verification (outcomes, own-thread SQL and strict loads), exact pinned app
controls/RNG companion policy, seal-check's advisory mutation ledger, current
production smoke probes and per-pass equivalence checks. None becomes a
production seal certificate; none is replaced by a replay success.

Add C as a **separate production behavioral report** only after its design is
accepted. Reuse facts/manifest readers, reason codes, load identities and
hit/fallback reporting, but add the missing scenario, causal-job and exact
effects data rather than relabeling the current `verify` report. Invalid state
restore, failed capture controls, missing worker reports or an empty scenario
set must not yield a passing sealed-coverage headline. Coverage is always
unit-and-scenario-specific, not “all gems supported.”

Suggested wider implementation scope, **not implemented by the two-GET slice**: the blog's
entire mapped controller/request behavior (create/invalid create/show/edit/
update/invalid update/destroy, comments, redirects, validation errors and
form/security round trips), plus its queued broadcast jobs. Carry every
original test ID into the mapping and list model-only assertions not reached
by those scenarios. Prove the harness detects an altered response, changed bind
value, lost/duplicated job/effect, real load reorder and zero-hit activation
refusal. Only then expand to Wikino/RubyToolbox and framework-specific queues.
Do not start performance measurements as part of this correctness work.

## First blog slice: raw comparison rejected (2026-10-21)

Run from the Lowrail checkout, with Ruby 4.0.7 and a release CLI:

```sh
mise exec -- ruby script/blog-production-verify run \
  .corpus/real-blog-r4 .lowrail/private/blog-production-NEW
```

The output directory must not exist. The runner copies the app, **not its
databases**, into a private disposable directory. It prepares all four stock
SQLite schemas and two articles/comments from the suite's YAML fixtures,
with explicit IDs and committed fixture timestamps (not a clock stub).
It builds one sealed artifact with `--env production --jit yjit`, then restores
the same closed primary/cache/queue/cable database snapshot before each of
three **sequential cold workers: off1, off2, on**. Bootsnap tmp caches are
removed before each worker. Each worker starts with `--yjit`, real production
initialization/middleware and the normal production adapters. No Minitest,
RSpec, outcome reporter, time/random stub or foreign-repository edit is used.

This is a **Rack boundary**, not a Puma/HTTP transport test: the external
driver runs the assertions after each worker has executed the two GETs using
`Rack::MockRequest`. Index is cold; show follows it in the same process.
No writes, background job drain, browser/JS, streaming or external-service
claim. SQL from other threads during requests is labeled, not silently merged
into own-thread SQL; background work outside those windows is uncovered.

The report preserves status, all headers, body bytes/encoding, ordered actual
SQL and already-cast bind **values**, cache/row counts and request/other-thread
origin. It does not recast binds or invoke a lazy cached-bind Proc; unavailable
capture is a rejection. Logical snapshots include all four database schemas,
table rows, sequences and non-DB storage-file hashes. Cold/scenario load
censuses reuse `VerifyLoads`; actual `$LOADED_FEATURES` order is also compared,
excluding only Lowrail's own runtime files. The shared setup/observers are
declared: a true no-gem observer-transparency control remains missing.

`report.json` lists source/lock/artifact/snapshot hashes, original test IDs,
oracles, every unit's per-scenario hits/fallbacks, runtime refusals, JIT modes,
uncovered IDs and limitations; `explain.log` comes from the existing CLI reader,
not another facts/manifest parser. Missing scenarios, capture failures,
off/off variation, any actual difference or zero total hits cannot produce
a passing sealed-coverage status. Only a successful finite scenario comparison
could be reported as such; it would still not certify SEAL001–009 or all inputs.

### Recorded result and unresolved findings

One sequence at [the published pre-run head](https://github.com/thomasklemm/lowrail/commit/5ff3be61c20bb0612816ca9cfbf094eef8a5f4a2),
private evidence `.lowrail/private/blog-production-c1/{off1,off2,on,prepare,report}.json`
and build/explain/worker logs. Lock SHA256
`570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`;
controller-test source SHA256
`36c63346d820223f9d03450a19132de27c058e9181bea0d0c5e9cedc2b1abaa2`.
The generated app has no separate Git revision; the report hashes its source
files instead of attributing the containing Lowrail repository's revision to it.

* **Exit 1, `rejected_off_control`; no support/certification claim.** Both
  original scenario assertions pass in all three workers (six executions).
* Raw unpinned off/off responses differ: CSRF meta/form tokens, signed Turbo
  stream names, cookies, ETag and `x-runtime`. `SECRET_KEY_BASE_DUMMY=1` also
  generates independent worker secrets; it is **not** a fixed deployment-secret
  control. Fresh sessions and real clocks/randomness are intentional in this
  retained raw run. Caller-supplied request IDs are the scenario IDs.
  No response field is stripped or normalized. Future declared, pinned entropy
  companions must remain visibly separate and retain this raw rejection.
* Off/off SQL, loads and effects agree. Each arm's initial logical state equals
  the prepared snapshot, and both GETs leave it unchanged, including queue,
  cache, cable and storage. There are no SQL/value capture errors.
* Off/on cold index SQL is **14 versus 3**, including the omitted SQLite
  version/schema queries; show is **2 versus 2** with identical SQL/binds.
  Cold on-only loads include `ActionController::API`, `objspace` and **12 extra
  hook events**, including `before_eager_load` and `action_controller_api`.
  These are findings to explain, **not exclusions**, and one on run is not a
  repeated stable/unstable classification. Sealed activation calls Materialize;
  neither that observation nor passing responses waives invariant 7.
* Build facts retain six missing-table skips for uninstalled ActionMailbox,
  ActionText and ActiveStorage schema; no coverage claim for those models.

| Unit | Pass / target | Index hits / fallbacks | Show hits / fallbacks |
|---|---|---:|---:|
| 0 | active_record/preload_plans | 1 / 1 | 0 / 0 |
| 1 | active_record/instantiate — Article | 2 / 0 | 1 / 0 |
| 2 | active_record/instantiate — Comment | 2 / 0 | 1 / 0 |
| 18 | sealed/link_to — ArticlesController | 5 / 0 | 2 / 0 |
| 19 | sealed/form_scaffold | 0 / 0 | 0 / 0 |
| 3–17 | SolidCable/Cache/Queue instantiate variants | 0 / 0 each | 0 / 0 each |

Form unit 19 reports `boot inventory changed; rebuild` under this observer;
a separate, no-observer diagnostic boot activates the same artifact. **Cause
unattributed at that head**; the subsequent exact-head recheck is below.
Link and artifact admission report no refusal.
Recorded hits are exercised-path evidence, **not** an accepted equivalence gate.

### Tracing-fix recheck on 334f49a

Pulled [334f49a](https://github.com/thomasklemm/lowrail/commit/334f49a7630ea4556659f4cc8ecffbcb4630941e),
rebuilt the release CLI and a fresh production/YJIT blog artifact on that exact
head, then ran the **unchanged raw runner with the observer**, once off/off/on.
Evidence: `.lowrail/private/blog-production-334f49a/`, including
`{prepare,off1,off2,on,report}.json`, build/explain logs and `lowrail-head.txt`.

Form unit **19 has index 0 hits / 0 fallbacks, show 1 hit / 0 fallbacks**.
Every reported refusal is null: artifact, sealed, form and form input. The
earlier inventory refusal is absent in this recheck. This records before/after
evidence, not an independently isolated causal attribution. All six scenario
assertions pass; effects remain unchanged; build/startup/after-initialize modes
are YJIT and there are no capture errors. The raw gate still exits 1 with
`rejected_off_control`. Cold index SQL remains **14/14/3** (off1/off2/on),
show **2/2/2**, with **12 extra cold on-arm hook events**. Neither finding
is excluded or explained away by the disappearance of the refusal.

### Declared blog entropy companions

Explicit opt-in, always **in addition to**, never instead of, the raw gate:

```sh
mise exec -- ruby script/blog-production-verify run \
  .corpus/real-blog-r4 .lowrail/private/blog-production-entropy-NEW \
  --entropy-companions
```

The [control declaration](../fixtures/corpus/blog-entropy-controls.json) is
included verbatim in each companion report. It pins the generated app's source
(SHA256 of the sorted relative-path/content-digest map for `.rb`, `.erb`,
`.jbuilder`, `.yml` under app/config/db/test), its exact lock hash, Ruby 4.0.7,
and the framework/stdlib source files at the controlled call sites. There is
no invented app Git revision. A changed/missing pin makes companions visibly
`inactive_pin_mismatch`; it does not grant an exemption or change the raw run.
The two seeds are **0 and 1**, each with its own sequential cold off/off/on
sequence and state restores. All nine scenario workers use the same artifact.

Every controlled input is visible:

| Input | Companion control; raw gate remains unpinned |
|---|---|
| Secret | `SECRET_KEY_BASE_DUMMY` unset; `SECRET_KEY_BASE` is the public, disposable string `lowrail-disposable-blog-companion-only-` repeated four times. **Never use this secret or these IVs in a deployment.** |
| Session ID | Only `ActionDispatch::Session::Compatibility#generate_sid`'s `SecureRandom.hex(16)` byte source is seeded. |
| CSRF | Only `generate_csrf_token` and `mask_token`'s 32-byte SecureRandom calls in the pinned Rails forgery-protection source are seeded. |
| Cookie encryption IV | Only `OpenSSL::Cipher#random_iv`'s 12-byte `OpenSSL::Random.random_bytes` call in the pinned stdlib source is seeded. No OpenSSL RNG reseeding. |
| Seed scope | A fresh `Random` per seed/scenario ID/declared site, seeded with SHA256 of those inputs; the ordered requested lengths/output digests are compared too. Only the current request thread is controlled. Unknown intercepted call sites delegate normally and **reject** with a visible capture error. |
| Runtime header | Only Rack::Runtime's two `Rack::Utils.clock_time` reads return 1000.000 and 1000.001. The real reads are retained separately as `clock_observations`; the literal `x-runtime: 0.001000` header is still compared. Extra/missing reads reject. This is a declared artificial input, **not a timing measurement**. No Time/Process clock override. |
| Request/session lifecycle | Original test ID supplied as request ID; fresh session per GET. No cookie reuse, CSRF submission/security or session round-trip claim. |
| State | Same four closed SQLite files and fixture timestamp/IDs; clear tmp before every worker. No live worker during restore. |

There is **no response rewriting, header deletion, SQL exclusion, load
exemption or event-order normalization**. Status, every header/cookie, body
bytes/encoding, SQL/bind values and effects use the same exact comparator in
raw and companion runs. It now also compares ordered start/finish names for
action_controller/action_view notifications and the explicitly listed scalar
payload fields (controller/action/method/path/format/status/identifier/layout/
count/cache_hits). Arbitrary object payloads, durations and allocation counts
are **not captured**, so this is not full subscriber-payload equivalence.
An actual body, bind, event/order, load or effect difference still rejects.
`raw_status` is always retained; a companion failure cannot turn a raw success
into a passing overall run either. This does not weaken ordinary `verify`.

**Bounded result:** base 334f49a plus this harness change, fresh build;
private evidence `.lowrail/private/blog-production-entropy-final/`.
The raw off/off responses still differ; exit 1, `rejected_off_control`, retained.
For **both** seeds, off/off agrees exactly in every compared field, with no
capture errors. Off/on responses (including encrypted cookies, CSRF tokens,
signed stream names, ETag and runtime header), captured events/entropy traces
and effects agree exactly. Both companions nevertheless report **`rejected`**:
cold SQL **14/14/3**, plus actual load-census/feature-order differences including
the **12 extra cold hook events**, remain findings for the next follow-up.
No exclusions and no accepted equivalence/support/certification claim.

All **18** original scenario assertions pass across the nine workers; every
runtime refusal is null. Form19 remains **index 0/0, show 1/0** in each on arm;
other unit counts match the table above (units 3–17 remain unexercised).
This is only the same two GETs; the uncovered denominator below is unchanged.
The controls do not establish security, all random paths, concurrent schedules,
observer transparency, arbitrary event payloads or whole-app behavior. The
first development attempt refused a missing activated default-gem pin; the
next retained undeclared Rails-session/stdlib-IV call-site errors. Their
rejections are preserved in private `blog-production-entropy-v1`/`v2` evidence;
the corrected declared sites, not output normalization, enabled the comparison.

### Explicit uncovered denominator

Mapped IDs: `ArticlesControllerTest#test_should_get_index` and
`ArticlesControllerTest#test_should_show_article`. Of 21 ordinary suite IDs,
19 are **not ported**, plus both active system tests below. These are not
passes inferred from HTTP status or zero hits:

```text
ArticlesControllerTest#test_should_get_new
ArticlesControllerTest#test_should_create_article
ArticlesControllerTest#test_should_not_create_article_with_invalid_params
ArticlesControllerTest#test_should_get_edit
ArticlesControllerTest#test_should_update_article
ArticlesControllerTest#test_should_not_update_article_with_invalid_params
ArticlesControllerTest#test_should_destroy_article
CommentsControllerTest#test_should_create_comment
CommentsControllerTest#test_should_not_create_comment_with_invalid_params
CommentsControllerTest#test_should_destroy_comment
ArticleTest#test_creates_an_article_with_valid_attributes
ArticleTest#test_validates_title_presence
ArticleTest#test_validates_body_minimum_length
ArticleTest#test_destroys_comments_when_article_is_destroyed
CommentTest#test_creates_a_comment_on_an_article
CommentTest#test_belongs_to_article_association
CommentTest#test_requires_commenter
CommentTest#test_requires_body
CommentTest#test_requires_valid_article
ArticlesSystemTest#test_full_article_lifecycle
ArticlesSystemTest#test_article_with_comments
```

The inventory reads this fixture's source-declared Rails `test` blocks; it does
not claim dynamic test discovery. Comparator regressions reject an altered
body/header, changed bind value, reordered SQL/load events, duplicated effect,
missing scenario, failed capture and zero-hit run, and distinguish off/off
rejection from a Lowrail-attributed difference. No measured cohorts were run.
