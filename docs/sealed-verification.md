# Verifying sealed production behavior

2026-10-21. **Option C accepted; bounded blog slice implemented below.**
The wider request/job design remains a proposal, not a new admission gate.
No measured cohorts. Run suite-derived behavioral scenarios
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
unattributed**: await the independently owned tracing fix on origin/main, then
rerun before attributing it. Link and artifact admission report no refusal.
Recorded hits are exercised-path evidence, **not** an accepted equivalence gate.

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
