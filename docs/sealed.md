# Sealed: an opt-in production contract

The guarded default tier is unchanged: any app, exact or refuse, original
body as fallback. The source-arm quarantine remains in force. **Sealed is a
different, explicit promise by an application's operator**, not a claim that
Ruby became statically immutable. Passing `seal-check` is evidence about the
tests exercised, not acceptance of that promise and not a support/speed claim.

The [production behavioral verification proposal](sealed-verification.md)
compares suite-derived replay, a certified test seam and an external scenario
driver. It recommends the external driver; no new runner or admission change
is implemented. Current two-example breadth probes remain smoke evidence.

## Contract and the work it can remove

Certification is a closed inventory of classes, singleton classes, ancestor
modules, constants, method bodies, templates, routes and configuration used
by a generated unit. It includes framework dependencies, not just app classes.
Uncertified paths stay original Rails. New/unknown inputs refuse before any
side effect; fallback never replays a partially executed action or helper.

| Promise, in production after the seal | What it unlocks; measured reason for it | Still live / not implied |
|---|---|---|
| Seal only after `after_initialize`, eager loading and lazy schema/attribute/route/view/template generation. Restart to change the certified inventory. | Build facts can select bodies ahead of time. Boot alone missed 1,438 blog / 4,446 Campfire methods seen by tests before materialization ([build surface](STATUS.md#build-surface-2026-10-20)). | Initializers and legitimate framework generation must finish, not be silently forbidden. Different locals sets may still generate methods. |
| No method definition/replacement/removal/undef/alias, visibility, constant/autoload or ancestor mutation on a certified target, including singleton methods on its instances. This includes `def`, `define_method`, `include`/`prepend`/`extend`, eval/class_eval and indirect/native equivalents. No new refinement altering a certified call. | Remove per-call effective identity/visibility checks. The optimistic two-link certificate alone costs **93,649 Ir**, versus **90,042 Ir** for the entire original links ([endpoint cost gate](passes/endpoint.md#show-section-cost-gate-stop-before-runtime-implementation)). | Existing app code still executes once in original order. A contract about class methods must also cover hidden singleton receivers, captured route objects and the compilation container. |
| Subscriber set and notifier fixed at seal: no subscribe, unsubscribe, temporary `subscribed`, replacement or in-place alteration. | A fixed instrumentation plan can specialize fanout, not assume that logging is off. Rails 8.1.4 has live render subscribers even at WARN; debug mode is fiber-local ([layer study](passes/layer-ceiling.md)). | **All existing subscribers still receive all events**, payloads, nesting and live assigns. Subscriber behavior, logger level, debug/silence state are not constants unless separately certified. The −26%/−37% eventful specimen is an upper bound missing assigns, not a target or equivalence proof. |
| No route/config/schema/type/reflection/callback/template/resolver/I18n/inflection mutation for facts actually certified, including direct edits to nested Hash/Array/String values and cache clears. | Fold boot config branches and static route/lookup structure. A flat two-key residual snapshot already costs **2,081 Ir**; resolver clears change template objects under unchanged identities, with at most **0.42%** lookup opportunity ([speculation](passes/speculation.md), [lookup](passes/template-lookup.md)). | Runtime data, sessions, CSRF, request headers, SQL, current model values and feature flags explicitly supplied as inputs are not boot config. Do not freeze arbitrary Rails caches/data or optimize mutable flags as constants. |
| Models in expanded URL helpers use stock or separately certified **pure** `to_param`: deterministic in its explicit current values, no mutation, callbacks, IO or hidden request state. | Can specialize route formatting without a certificate after conversion. Quarantine's `to_param` probe changes the actual captured route's singleton `format` and defeats entry-only checks ([endpoint quarantine](passes/endpoint.md#source-arm-quarantine)). | Preserve conversion exactly once, order, errors, escaping, missing keys and fresh output. `to_param` absence does not mean skip the inherited conversion. Purity is not established by absence of observed effects. |
| Any folded `default_url_options` is request-independent and side-effect-free. Move `Current`-dependent pieces into explicit helper arguments, or keep that helper live. | Campfire's live defaults permit only **1/4** scalar path calls, or **4/4** with an AR certificate; the whole room opportunity is only about **0.3%** ([routes](passes/route-helpers.md)). | Do not cache Campfire's `Current` across requests, user/tenant/host changes or mounted engines. A valid boot value is not a request-invariance proof. |
| Strict locals for certified templates where feasible; explicit finite locals shapes otherwise. | Gives one stable compilation signature; old endpoint slice refused strict/unknown locals and compiled-container-sensitive bodies ([endpoint](passes/endpoint.md)). | A recommendation, not a ban on every non-strict template. Preserve original CREF (`Comment` in blog show), output-buffer/capture ownership and errors. Strict locals by itself saves no measured request instructions. |
| No unresolved `method_missing`/dynamic send at an **expanded dispatch**. A finite proven target set is allowed; otherwise retain that call live. | Removes unknown dispatch without inventing a certificate. The existing-pass census found **zero** extra sites refused solely for future mutability; remaining refusals are structural/unmodeled ([speculation](passes/speculation.md)). | Not a ban on Rails' internal dynamic behavior. Sealing alone does not create a lowerer, prove receiver types or authorize bypassing app hooks. |

An app may adapt its code to this contract, or narrow its certified set. It
need not adopt sealed mode to use Lowrail. A known violation refuses the
sealed artifact/region and runs original code, with a ledger explanation.

### Rule IDs and additional boundaries

The single rule catalog is [`SealRules::RULES`](../gem/lib/lowrail/seal_rules.rb):
SEAL001 structural mutation, SEAL002 URL-default dependence, SEAL003 conversion
purity review, SEAL004 subscribers, SEAL005 runtime config/routes/resolvers,
SEAL006 unresolved dispatch, SEAL007 locals, SEAL008 framework tables and
SEAL009 delivery introspection. Static and dynamic results use these IDs;
SEAL002/003/006/007/009 are review hints, not dynamically proved purity or
reachability assertions. A callback/API is a **hint**, not proof that its
receiver changed. A **proven** row requires a changed certified destination
snapshot. Counts are checkpoint observations, not unique mutations.

The structural snapshot records own public/protected/private methods (including
UnboundMethod identity, owner, source and visibility), ancestors, singleton
holders and own constant/autoload bindings. It compares before/after each test
and at exit. It does not call autoloads. Suppressed callbacks and direct `def`
or constant assignment are caught **if the changed state survives to a
checkpoint on an inventoried holder**; restored-between-checkpoint edits,
inherited `undef` tombstones and unknown instance singleton holders remain
gaps. For include/extend, a source-module callback without a destination delta
is only a hint, even if the source module was certified. Snapshot rows retain
candidate file:line separately from the checkpoint. With no candidate, the
mutation source is explicitly unknown, not attributed to the checkpoint code.

* **SEAL008, framework heap tables:** no in-place changes to contents,
  defaults/default Procs or nested values of tables consumed by an expansion.
  Stock 8.1.4 `TAG_TYPES` is frozen, so a boot proof need not copy its contents;
  rebinding and `Hash#[]` overrides still require SEAL001. Mutable
  `PRE_CONTENT_STRINGS` has a default Proc. The detector explicitly watches
  writes and snapshots both tables at seal, per-test boundaries and process
  exit, including String bytes/encoding and default/default-Proc identity.
  A snapshot difference proves changed state but cannot recover the original
  mutation file/line: its row labels the checkpoint location honestly. Changes
  undone between checkpoints, arbitrary nested opaque objects and other tables
  remain gaps. Leave the consumer live or refuse until explicitly inventoried.
* **Receiver replacement is not structural mutation.** A different
  `@tag_builder`/view/controller/route object can have unchanged class tables.
  No rule currently proves object provenance or blocks ivar replacement. The
  pilot must keep actual receiver acquisition/dispatch live; an expansion
  needs a separate provenance proof or live shape predicate, not SEAL001 alone.
* **Primitive inputs are not sealed heap values.** Keep live argument values,
  Hash defaults, String encodings/safety, per-instance overrides and arbitrary
  coercions. No global “pure Ruby primitive” certificate is implied. Unknown
  values stay in the original call, evaluated once. No generated shortcut may
  move an application conversion, add an extra one, or reuse its authorization
  after another live call.
* **SEAL009, observational equivalence:** the production contract accepts
  edited ISeqs and changed line/C-call trace streams, and excludes observation
  of those internals and top-level frame labels in certified paths. Actual
  delivery probes saw `<compiled>` instead of `<top (required)>`; call-stack,
  TracePoint, ISeq/AST-sensitive apps therefore **refuse sealed delivery** unless
  they explicitly accept this exclusion. It is not normalized away by verify.
  Late installation after a method handle escaped is refused separately:
  even an unchanged-source reload changes UnboundMethod equality. Cold delivery
  before exposure is required. Ordinary application exceptions/events/assigns
  are not excluded by this introspection clause.

These distinctions follow the endpoint's [final fact table](passes/endpoint.md#final-fact-classification-sealed-contract-vm-epoch-residuals).
Its accepted body-installed guard micro prices **94,466 Ir** of optimistic
internal checks versus **89,729 Ir** for the entire original two links; it
does not prove a sealed expansion or close the receiver/value gaps. The
[accepted VM experiment](passes/vm-epoch.md) costs **195/249/267 interpreter
Ir**, or **36/49/52 YJIT Ir**, for read/compare/compare+branch, with zero
allocations. Two interpreter checkpoints estimate 534 Ir, not a net saving
or proof that two suffice. Only patched Ruby provides this structural epoch;
4.1-preview1/master have no supported equivalent. A trusted/intrinsic read
**and comparison** are required, not an overridable Ruby getter. Warning
reentry required a pre-callback bump; post-call continuations and the heap /
receiver / input gaps above remain. No universal refinement/Box/Ractor or
complete VM-reentry certificate is implied. A later trusted authorization
provider may replace test certification without regenerating specialized
bodies; the pilot must not depend on this experimental VM patch.

## Detection is a test tool, not enforcement

```sh
lowrail seal-check APP -- bin/rails test --seed 41231
lowrail seal-check APP -- bundle exec rspec --seed 41231
# Narrow a diagnostic census to a declared target inventory:
lowrail seal-check APP --targets ArticlesController,Article,Comment -- bin/rails test
# Prism-only precheck, no app boot and no tests:
lowrail seal-check APP --static
# Ordered onboarding: boot, baseline suite, hints, optional dynamic census,
# existing guarded refusals grouped by reason. JSON: .lowrail/doctor.json.
lowrail doctor APP --seal-check -- bin/rails test --seed 41231
# Separate opt-in return-tracing check, with no tracing installed by doctor:
RUBYOPT="--yjit --yjit-stats=quiet" lowrail doctor APP --trace-check --path /up -- bin/rails test
```

Doctor's `--trace-check` samples an unrelated warmed, JIT-compiled leaf and,
with `--path`, ten warmup GETs plus one GET in its independent boot process.
Use a safe endpoint in a disposable diagnostic run, never a timed benchmark.
It neither enables YJIT/stats itself nor installs a TracePoint. Disabled
global tracing can leave executable VM instrumentation behind even with
zero live observers; request-only targeted tracing is reported separately.
Missing counters or disabled YJIT mean `unavailable`, not a clean result.
The advisory `return_tracing` JSON neither promotes a pass nor fails the
baseline. [Mechanism, scope and regression](passes/yjit-regression.md#doctor-detect-sticky-tracing-from-any-gem).

The command runs the app's own suite with lowering off, materializes the
boot surface after `initialize!` has returned (all `after_initialize` hooks
have run), then traces method/constant/ancestor/visibility operations,
Notifications subscription operations, routes and reachable config containers.
It does not wrap lexical `private` or `class_eval`, freeze app objects, reject
stubs or turn violations into failed assertions. The default census covers
boot-loaded app and Rails modules plus their ancestors and core dependencies;
it is intentionally broader than a future endpoint certificate. A class
reopening with no mutation is not itself a violation.

Every observation carries file, line, target, operation, current test (when
known), and remedy. API calls and their callbacks can both be observed:
**counts are observations, not deduplicated mutations**. `observed_at` keeps
the framework call location as well as the app test responsible. Rows do not
include method arguments, SQL, cookie values or configuration values.
`.lowrail/seal.json` retains command, suite exit, materialization errors,
target inventory, per-process ledgers and per-test optimization status. The
read-only MCP tool **`seal_ledger`** serves it without needing a facts build.
MCP **`doctor`** serves the onboarding report including static hints, source
app/gem attribution (gem name/version), dynamic evidence and disagreements.
Gem findings suggest an upstream issue or excluding the target, never an app
rewrite to patch a dependency. Relevance is a separate field: `test_only`
(justified only in `RAILS_ENV=test`), `lazy_materialization` (move loading or
generation before the seal), `production_relevant`, or unresolved/mixed.
Each changed-state component retains its source. A test runner further up
the stack never excuses an app method change. Headline contract counts include
only proven production-relevant changes; unresolved provenance is reported
separately, never counted as a compatible app. Lazy/test exclusions do not
authorize an affected sealed fast path in that test process. Static scope is
app/config/lib plus exact gem files named by a previous dynamic census, not
a whole-dependency proof.
The comparison reports unique rule/source-file pairs matched/unobserved and
dynamic-only, plus their unmatched rate. This is **coverage disagreement**;
an unexecuted hint is not refuted. Semantic disagreement rate is unavailable
without independent evidence, not fabricated as 0%.
The five-app census has 91–97% unmatched source pairs. Static results therefore
remain a pure onboarding hint list with **no certification gate weight**; no
static-precision tuning is required for the blog pilot. Destination comparisons
cost 136–175 ms/test in the shared orb (two comparisons/test plus boundaries),
excluding tracing/materialization/serialization. This is acceptable CI-tool
overhead, not a production request check or an isolated performance result.
Incomplete boot/materialization or no recorded tests is not a clean result.

On any observed violation a process-global monotonic epoch changes. Test
doubles (Minitest stub, mocha and RSpec mocks) receive the same treatment:
**“this test runs unoptimized”**, not a red test. Restoration does not restore
authorization; later tests in that process stay deoptimized. A sealed request
entry must read this epoch once before entering any generated code; no sealed
delivery is installed by this tooling step. No successful
test is thereby credited with fast-path coverage. Do not reuse a request's
permission across an observed in-flight mutation: the detector is diagnostic,
and that request is not certified even if it began before deoptimization.

Ruby cannot enforce the contract completely. `method_added` can be suppressed;
captured `UnboundMethod#bind_call` can bypass wrappers; plain `def` without a
class keyword and direct constant assignment need not have a detectable class
reopening. TracePoint sees many ordinary callback cases, not every native or
suppressed path. Surviving destination changes additionally have snapshot
coverage, not complete mutation detection. Notifications/config/route APIs
currently remain hints without a state comparison; they deopt conservatively
but do not establish that a subscription or write succeeded. Config
setters/opaque objects, aliased mutation APIs,
non-exercised branches, native writes and child processes without the observer
can escape it. Purity, request independence and the absence of dynamic dispatch
need source/certificate review in addition to execution. An undetected
production breach cannot be promised automatic safe fallback. Operators must
honor the contract; **do not deploy an unchecked artifact on an arbitrary app**.

## Pilot order and gates

The first delivered pilot is the separate `sealed/link_to` pass, **after
pricing its residual checks**. The guarded `view/link_to` and `route/path`
passes and old artifacts remain quarantined; routes stay live. A sealed
artifact must refuse without explicit sealed acceptance. The historical
−5.995% index / −0.987% show numbers price
unsafe pre-quarantine code, not the new tier. Effective receiver selection,
mutable tables, configuration and primitive inputs still need live predicates
or refusal. The three quarantine repros must appear in the detector ledger;
in-flight deoptimization cannot replay name expressions or `to_param`. A
diagnostic observation alone is not a safe continuation.

Gates are five-app verify, AP/AV L3, isolated response/SQL/event/assign pairs,
and one finite c9d2397 interpreter cohort on index/show against off. A price
failure stops implementation; missing certificates refuse rather than waive
the gate. The [finite operation prices](passes/sealed-links.md) now include
fresh-builder provenance with real original-body ISeq delivery, weak-map
registration/lookup and GC cleanup: 95,638 → 52,762 interpreter Ir for two
literal-name links, 17 → 9 objects. This clears that measured builder-cost
hurdle, not the complete deployment certificate or request gates. Route's
initial incomplete −4,687-Ir price does not authorize its activation. The
[post-TracePoint-fix request series](passes/sealed-links.md#post-fix-four-finite-cohorts-one-small-accepted-result)
accepts only interpreter show, **−0.185% [−0.221, −0.159]**; interpreter index
and both YJIT cohorts reject their controls. Links are on the stacking backlog,
not promoted. Next is interpreter-first form-scaffold pricing on show; new
YJIT cohorts wait for the separately owned warmup-method investigation.

### Artifact acceptance and the first delivered slice

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 LOWRAIL_BUILD_JIT=0 \
  lowrail build APP --env production --sealed
# At production boot, before Rails or certified method handles escape:
RAILS_ENV=production LOWRAIL_SEALED=1 LOWRAIL=1 \
  RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails server
```

`--sealed` selects registry entries with `sealed_only`, not every guarded
opt-in pass and not a spelling prefix. It cannot combine with `--passes`.
The manifest carries `tier: "sealed-v1"` and `rails_env: "production"`.
Runtime acceptance additionally requires `LOWRAIL_SEALED=1`, production and
only registered sealed-only units. A missing/unknown tier, missing opt-in,
test environment or mixed old artifact refuses **the entire artifact before
installing its Guard/Loader/pass state**. There is no test certificate bypass
or hand-authored “clean” JSON flag. `seal-check` supplies diagnostic evidence;
the production opt-in accepts all SEAL001–009 promises, including the SEAL009
introspection exclusion. It is not a runtime enforcement mechanism.

The first link slice is intentionally restricted to the production Ruby
4.0.7 / Rails 8.1.4 blog. It accepts literal names and one literal `class`
option only (8/9 source sites); route/URL conversion stays original and live.
Unknown shapes, custom helpers and edited/stale sources refuse. Independent
Rails-source pins and effective body/visibility signatures reject boot-time
Ruby helper/primitive overrides; this is not a universal certificate for
arbitrary native extensions or Ruby implementations. Cold factory and request
entry bodies must actually deliver through the existing ISeq seam. An app
whose certified bodies already escaped, or whose cold delivery cannot be
witnessed, remains unoptimized rather than reinstalling handles.

`TagHelper#tag_builder` registers only the result of its own stock constructor
in a WeakKeyMap, inside its original body ISeq. `TagBuilder.new` and
`#initialize` are not wrapped, aliased or replaced. Foreign builders (including
reinitialized objects) refuse. Actual view-holder inspection uses the native
ObjectSpace read rather than creating a singleton class on the receiver.
Main-Ractor checks precede registry access; no universal Rails/Ractor support
is claimed. Threads retain separate request authorization, restored in ensure
by the original `Metal#dispatch` body ISeq. That runtime authorization seam
can later use a trusted VM provider without regenerating template bodies.

The render residue still consumes `PRE_CONTENT_STRINGS["a"]` and its default
Proc live, and escapes live URLs with their original safety/encoding behavior.
Frozen stock `TAG_TYPES` and literal-escaping dependencies are boot facts;
mutable/custom type tables refuse. Configuration and model conversions are
not folded. Residual URL/input and actual receiver checks remain: sealing does
not authorize expanding an arbitrary object. A local fallback after URL
conversion calls `content_tag` with the converted values, never `link_to` again.

The separate guarded-pass audit reproduced `inertia/config_bind` with a
suppressed `Hash.method_added` hook and changed `Hash#extract!`: warmed facts
stay true and the shortcut misses the replacement. That pass is registered
sealed-only too; old unmarked/mixed artifacts refuse, and its guarded selection
records the SEAL001 reason. This is eligibility, not a new performance claim
or a broadening of the blog link certificate. Its accepted request prices are
mode-specific (−6.947% interpreter, **+16.339% YJIT**), so it is not promoted.

### Subsequent show endpoint: compiler phases

After partial evaluation over certified facts, perform ordered, attributed
phases, never a generic dead-method shaker (unused methods execute no request
instructions):

1. Remove constant fact guards, coalesce remaining admissibility guards into
   one request-entry decision. Keep live input predicates and refuse before
   effects. Never reactivate the quarantined source passes.
2. Fold dead branches on sealed env/config/feature flags. Mutable explicit
   inputs remain live. Record no eligible branch as zero, not a survey saving.
3. Inline proven no-op callback/middleware layers, preserving around/ensure,
   halting and error behavior. Middleware that is identity on only the observed
   GET is not identity for every accepted input.
4. Deforest non-escaping Hash/Array/tag-buffer intermediates. Preserve fresh
   returned storage, safety/encoding, conversion order and once-only effects.
   Allocation survey pools are discovery bounds, not credited savings.

The subsequent blog-show pilot keeps real controller/view assigns,
instrumentation, query objects, Rack/session/security behavior and compilation
scope. Gate on off/sealed literal body/status/**all headers**, ordered SQL,
events and assigns using the existing **144-pair** checker; five-app default
verify unchanged; then **one finite c9d2397-protocol interpreter cohort** with
ordered phase ablations (Ir and objects/request), independent A/A, identical
heap floors and actual interpreter state. Retain rejected controls; no retry
to green and no native YJIT speed claim. An unsuccessful pilot remains a
documented refusal/negative result, not a reason to weaken those gates.
