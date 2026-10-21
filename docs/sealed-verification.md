# Verifying sealed production behavior — proposal

2026-10-21. **Design only; no runner, admission change or new gate implemented.**
No measured cohorts. Recommendation: run suite-derived behavioral scenarios
through an **external driver against cold, real production off/on processes**.
Use captured replay where it is faithful, adapters where the suite depends
on process-local test machinery, and an explicit uncovered ledger everywhere
else. Do not admit a production artifact into `RAILS_ENV=test` to get hits.

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
The copied-blog form probe also shows that preloading Minitest/reporters can
change the inventory and correctly prevent activation ([follow-up](types.md#explain-a-build-not-an-inferred-promise)).

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

Suggested first implementation scope, **not authorization here**: the blog's
entire mapped controller/request behavior (create/invalid create/show/edit/
update/invalid update/destroy, comments, redirects, validation errors and
form/security round trips), plus its queued broadcast jobs. Carry every
original test ID into the mapping and list model-only assertions not reached
by those scenarios. Prove the harness detects an altered response, changed bind
value, lost/duplicated job/effect, real load reorder and zero-hit activation
refusal. Only then expand to Wikino/RubyToolbox and framework-specific queues.
Do not start performance measurements as part of this correctness work.
