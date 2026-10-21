# Generated-method census: park an enum pass

2026-10-21. **Research only. No pass, runtime/default/quarantine change,
support claim, request timing cohort or Callgrind.** Ruby 4.0.7 throughout.
The five required apps use Rails 8.1.4. The additional corpus pins retain
their actual Rails versions, rather than silently changing dependencies.
Boots retain app JIT policy (blog, CASA and Writebook enable YJIT); both
request workers are explicitly interpreter-only. The JSON records each mode.

**Recommendation: park, not go.** Replacing the generated enum predicate
itself is a better Lowrail boundary than rewriting callers, but these
requests do not justify its exactness/delivery cost. There are **59 app
predicates across 18 enum declarations in five of nine apps**, with no
observed enum overrides. Only three predicates execute in the requested
workload: **39 calls over Fizzy's 18 GETs; zero in blog**. Enum bang methods
and enum-generated scopes have **zero calls** in both workloads.

## 1. Static description sites, then real boot

The [census script](../bench/experiments/bmethod_census.rb) parses app/lib/config
Ruby with Prism, then separately observes a real boot/eager load with Lowrail
off. `define_method`/`define_singleton_method` returns retain the original
UnboundMethod, creation location and later definitions. The live heap sweep
also finds pre-observer bmethods/aliases. `ISeq.to_a[9] == :block` distinguishes
block-backed methods from ordinary defs, not just a suggestive source line.
Eval-compiled ordinary defs are matched against the **entire captured method
ISeq**, so delegates/association helpers are not mislabeled bmethods.

For every recorded entry the [JSON appendix](bmethod-census.json) contains
holder, generated/current body shape, source location, parameters, arity,
visibility, ancestry and effective overrides in named module/class consumers,
including prepends and gem consumers. Anonymous owner IDs are **local to one
boot**, not stable constant names. Enum rows associate the anonymous owner
with its actual model's `_enum_methods_module`; scopes belong to the model's
singleton class. This is a diagnostic eager-load census, **not** a proposal
to force loads during Lowrail activation.

| App / boot environment | Rails | App enums | Predicates | Bangs | Positive + negative scopes | All bmethod entries | Observed eval-generated plain defs |
|---|---|---:|---:|---:|---:|---:|---:|
| Blog / production | 8.1.4 | 0 | 0 | 0 | 0 | 4,535 | 5,949 |
| Fizzy / production | 8.1.4 | 2 | 5 | 5 | 6 | 5,588 | 6,809 |
| CASA / production, external boot fixture | 8.1.4 | 4 | 14 | 14 | 28 | 8,345 | 9,351 |
| Writebook / test | 8.1.4 | 5 | 15 | 15 | 30 | 4,745 | 6,529 |
| CodeTriage / test | 8.1.4 | 0 | 0 | 0 | 0 | 5,569 | 12,050 |
| Campfire / test | **8.2.0.alpha** | 3 | 10 | 10 | 20 | 4,192 | 5,823 |
| PingCRM / test | 8.1.4 | 0 | 0 | 0 | 0 | 4,648 | 6,575 |
| Redprints CFP / test | **8.1.3** | 4 | 15 | 15 | 30 | 7,181 | 8,422 |
| React Starter Kit / test | 8.1.4 | 0 | 0 | 0 | 0 | 4,557 | 5,869 |

App enum totals exclude `ActionMailbox::InboundEmail`, whose five predicates,
five bangs and ten scopes occur in seven boots. All observed enum predicates
and bangs are **public, zero parameters, arity 0**; scopes are public with
`*args` (Ruby keyword forwarding may appear as `**`), arity −1. Engine scopes
are not app enum opportunities. Within the five required 8.1.4 apps there are
**11 app enums, 34 predicates, 34 bangs and 64 scopes**. None of these numbers
is an eligibility or speed claim.

Descriptions matter: Fizzy's `User.role` uses string values and `scopes: false`,
so its two predicates do **not** imply four role scopes. `Bubble.status` has
three string values. CASA has a custom `court_report_` prefix, mixed integer
and string enums, and integer values **1/2/3** for court-order implementation.
Writebook has `*_theme?` suffixes and both integer/string mappings. The JSON
retains every declaration and actual expanded name; no ordinal is guessed.

**Boot boundaries.** Writebook production still fails with
`NoMethodError: sqlite3_production_warning=` at production.rb:66. Its test
inventory is not a repaired production boot. CASA uses the already documented
[external dummy-credentials/schema-only fixture](helper-discovery.md#casa-a-named-disposable-production-boot-fixture),
with a fresh private local PostgreSQL DB. No real credential is needed or
published. Other test boots use their unchanged config and isolated DBs where
needed. No suite or production compatibility is inferred from boot success.

Pins are from `script/corpus` / [compat](compat.md), recorded in full in JSON.
Blog is the retained **86ebd4a8 source fixture**, not a newly renamed Rails
application: source archive SHA256
`56d74970a6531ff667e62a8a32c396c8cddb6e78991f5b2a7825c1dfcd7a180c`.
The reachability DB has three articles and comment multiplicities **2/1/0**,
inserted without callbacks, with empty queue/cache/cable schemas. Article text
is a literal census fixture, not a byte-equivalence comparison to another run.

### Beyond enums: what the boot-generated population contains

The totals above are **entries, not independent templates or hot sites**.
For example, most boots include 2,730 pre-observer Bundler current-Ruby
bmethod entries/aliases (Redprints 2,337; Starter 2,460). Their size must not
inflate a Rails opportunity.
The appendix distinguishes observed creation, live pre-observer snapshots,
later redefinition and eval-generated plain defs. Static `store`, `delegate`,
associations, attributes and related descriptions are also retained in full.

| Family / fixed description | Actual holder and call shape | Override / exactness observation |
|---|---|---|
| Enum | Anonymous `ActiveRecord::Enum::EnumMethods` instance included in the model; predicate/bang `()`; singleton scopes `(*args)` | No observed app/gem override for the 59 app predicates or bangs, or 114 scopes. This does not cover unexecuted future mutations or per-object singleton overrides. |
| `store_accessor` and `store ... accessors:` | Anonymous `_store_accessors_module`; readers/dirty helpers `()`, writer `(value)`, public | Fizzy has **80 store-generated entries**: 56 from its seven described keys plus 24 framework entries. `Filter#assignment_status`, `#indexed_by`, `#terms` **override** the generated readers and call `super`; these are refusals under the proposed no-overrides rule, not direct-dispatch candidates. |
| Inheritable `class_attribute` | Singleton classes, private `__class_attr_*` getter `()` and setter `(new_value)`; closure-backed | Fizzy has **1,505** such bmethod entries. Values are live captured cells: the setter can mutate the getter's cell **without changing the getter body**. Body/ancestry checks alone do not license folding a value. |
| Named scopes | Model singleton class `(*args)`; public bmethod | Scope execution, current scoping, extensions and keyword/block forwarding remain live. A fixed name is not a fixed query or pure function. |
| Route/helper generation | Anonymous route helper/proxy modules, plus generated view classes; many public `(*args)` methods and zero-arg `_routes` closures | Fizzy has **315** route-set bmethod entries. Helpers retain request/default-url-options/route-set dependencies. Do not confuse bmethods with the already ordinary-def helpers emitted by Rails' code generators. |
| Delegates, associations, callback runners, tag helpers; gem DSLs | Plain eval-generated `def`s as well as bmethods; exact per-entry args/visibility in JSON | E.g. Rails `delegate`, association accessors and tag helpers already have ordinary method ISeqs. Devise, Draper, Avo, Forwardable/DelegateClass and other loaded generators are inventoried, not automatically eligible. ObjectSpace population includes tooling/bundle infrastructure, especially in test boots. |

The recorder checks **effective lookup in consumers**, not only whether the
owner still contains its method. Same-holder redefinitions are retained too.
For anonymous consumers with no semantic constant identity, and pre-observer
replacements, the report cannot prove historical provenance. It is a census
of observable generation/live methods, not a completeness theorem about every
method ever temporarily created, C-defined method, or lazily unloaded class.

## 2. Untimed request reachability

Only after the static/boot census, a **scratch** worker counted `TracePoint
:call` events whose actual method ISeq was block-backed. It counted method
entries, not nested `:b_call` iterations, and only the request's own thread.
Rack body enumeration/close is included. No timing or allocation reading was
mixed into the observer. The scratch source is preserved **as evidence text**
in JSON, not installed in the gem. No test runtime is loaded by HTTP workers.

Blog uses production `GET /articles` and `GET /articles/1`, each cold, warm,
warm-repeat: **6/6 HTTP 200**. Fizzy reuses
[`fizzy_link_fixture.rb`](../bench/experiments/fizzy_link_fixture.rb) and the
exact six-route vector/natural CSRF+password login from
[`fizzy_link_http.rb`](../bench/experiments/fizzy_link_http.rb): **18/18 GETs
HTTP 200**. Login GET 200 / POST 302 are recorded separately and excluded.
`SKIP_TELEMETRY=1`; stock production caches remain enabled across the vector.
No fake Current, injected signed cookie, app patch or cache-clearing policy.

| Bmethod family, ranked by Fizzy call count | Fizzy: 18 GETs | Blog: 6 GETs |
|---|---:|---:|
| `class_attribute` | **24,246** | **1,099** |
| Route-set methods | **1,233** | **297** |
| Store accessors | **235** | 0 |
| All named scopes (**not enum scopes**) | **172** | 0 |
| OpenSSL digest constructors | 112 | 30 |
| Action View base helpers | 83 | 17 |
| Enum predicates | **39** | **0** |
| Turbo frame helpers | 36 | 12 |
| Other bmethods | 22 | 32 |
| **Total** | **26,178** | **1,487** |

The highest individual Fizzy methods are AR's private
`__class_attr_default_connection_handler` **1,786**, `default_role` **1,594**,
`default_shard` **1,559**, `default_scopes` **1,243**, `logger` **1,212** and
`attribute_aliases` **1,122**; `_routes` follows at **912**. Blog's leading
individual method is `_routes`, **204**, ahead of view `__class_attr_logger`,
**126**. The JSON ranks **every observed identity** and retains every
per-request count, not just the aggregate.

| Fizzy route | Total bmethods, cold / warm / repeat | Enum predicates | Store readers |
|---|---|---|---|
| `/buckets` | 2,444 / 1,131 / 1,131 | 4 / 4 / 4 | 12 / 12 / 12 |
| Filtered `/bubbles` (literal full query in JSON) | 4,133 / 2,295 / 2,295 | 3 / 0 / 0 | 66 / 60 / 60 |
| `/account/users` | 411 / 396 / 396 | 0 / 0 / 0 | 0 / 0 / 0 |
| `/workflows` | 297 / 254 / 254 | 0 / 0 / 0 | 0 / 0 / 0 |
| `/notifications` | 1,773 / 248 / 248 | 0 / 0 / 0 | 1 / 0 / 0 |
| Bucket/bubble show | 3,784 / 2,344 / 2,344 | 8 / 8 / 8 | 4 / 4 / 4 |

The 39 enum calls are `Bubble#drafted?` **23**, `#creating?` **9** and
`#published?` **7**. No `User#member?`/`#system?`, enum bang or enum-generated
positive/negative scope executes. Among the 235 store calls, **222** are
the generated super bodies beneath the three overridden `Filter` readers:
`indexed_by` **101**, `assignment_status` **62**, `terms` **59**. Only **13**
are the unoverridden Event readers (`assignee_ids` 12, `comment_id` 1).
Counting a super body does **not** make the effective receiver unoverridden.

Cold totals are 12,842 Fizzy / 699 blog; warm and repeat totals are each
6,668 Fizzy / 394 blog. This finite traced vector is not a traffic-frequency
model, an uninstrumented execution-order certificate, or active Lowrail hits.

## 3. Exact replacement sketch and micro, not a price

If revived, start with **enum predicates only**, one ordinary `def` installed
in the **existing actual generated owner**, not a new prepend or caller
rewrite. This covers views and explicit receivers as well as bare calls.

- At natural boot/load completion, certify the Rails generator/source and
  bundle, actual owner identity, model/ancestor chain, exact generated body,
  parameters and public visibility; record prefix/suffix/aliases and actual
  typed captured values, not enum order. Refuse any app/gem/prepend/subclass
  override of the affected method; per-object singleton overrides also need
  a proved boundary. A lockfile plus app-source search is not that proof.
- Preserve live `status_for_database`, type conversion, record state and
  `==`; do not turn the predicate into raw attribute or integer-storage
  access. For string enums the captured RHS is an object, not merely equal
  bytes: substituting a fresh literal can change behavior with a custom
  equality implementation. Captured name/RHS provenance and escape/mutation
  boundaries must be certified or refused.
- Removing `public_send` also removes its overridable dispatch and **public
  visibility check**. A bare `status_for_database` accepts a private method,
  whereas the original raises. Certify actual dispatch/body/visibility,
  relevant primitives and equality semantics at the point of use, including
  changes caused by code the residual calls. Entry guards and suppressible
  Ruby mutation hooks alone are insufficient. If the proof needs a guard
  more expensive than this tiny predicate, keep the original.
- In the sealed tier, retain originals through boot, observe already loaded
  holders and use the existing no-mutation contract/invalidation boundaries.
  Refuse escaped Method/UnboundMethod/closure or unsupported tracing,
  refinement, Ractor or mutation observability rather than spoof reflection.
  A verification-only test certificate must be built/admitted in that **same
  test environment**, not repurpose a production certificate or treat suite
  parity as a general immutability proof. Need nonzero per-unit hits and
  identical per-test outcomes through `lowrail verify` before support.
- Emit a separate small **method ISeq** for Ruby 4.1/ZJIT, without block
  closure/dynamic-send/splat wrappers. Existing `JitShapes` already warns
  about these shapes and a preview 30-word inlining threshold. This census
  ran Ruby **4.0.7**, not ZJIT: a plain def is a candidate shape, **not** a
  promise of 4.1 inlining or speed. Bangs and scopes need separate semantic
  residuals (callbacks, exceptions, transactions/scoping), not this predicate.

### Bounded wall-clock micro

One process per interpreter/YJIT mode, 100,000 warmup calls per case, five
rotated samples × 2,000,000 iterations, separate monomorphic loops. Medians
include loop overhead. The live reader is a trivial `@status` getter; **not
Active Record**. Exact micro bodies and all samples are in script/JSON.

| Shape | Interpreter ns/iteration | YJIT ns/iteration |
|---|---:|---:|
| Rails-shaped bmethod: interpolated `public_send(:"#{name}_for_database") == value` | **223.62** | **180.79** |
| Bmethod: direct reader `status_for_database == 1` | 50.97 | 27.81 |
| Plain def: direct reader `status_for_database == 1` | **46.10** | **27.31** |
| Plain def: fixed-name `public_send(:status_for_database) == 1` | 88.58 | 70.82 |

The combined rewrite is 4.85× / 6.62× faster **in this micro**. But deleting
only block backing changes 50.97→46.10 ns / 27.81→27.31 ns here: dynamic-name
construction/public dispatch, not an arbitrary `define_method`, accounts for
most of the difference. No guards, fallback, installation, real AR type
reader, fixed-heap/A/A or JIT-flat admission was priced. **Do not multiply
these ns by call counts to claim a request saving.** No measured cohort was
run or repeated until green.

### Source locations and backtraces today: not a universal invariant

Lowrail **does not universally preserve original source_location or full
backtraces**. The original plan's source-splice description is narrower than
all current delivery paths:

| Delivery path | What current code does |
|---|---|
| Source-file lowering | `Compilation.lowered` replays compiler, original display/absolute path, start line and options. Same-line splices preserve the original method location and fallback-body lines. `Compiler` documents `<compiled>` vs `<main>` at the top level; added specialized work can have new frames/line events. This is not identical tracing/ISeq metadata. |
| Sealed template splices | Keep the template identifier and reject newlines in replacements; existing dispatch/constructor metadata tests compare off/on. A form block's original source_location is a certificate input, not a universal wrapper-location guarantee. |
| AR instantiate runtime install | `ar_instantiate.rb:47` calls `class_eval(source, "lowrail:ar_instantiate:Model", 1)`. The new `_load_from_sql` starts at **synthetic line 2**. Even its `super` fallback adds a Lowrail frame. |
| Preload / Inertia config / form / endpoint variants | Runtime-defined/prepended methods expose Lowrail Ruby locations or synthetic `lowrail:endpoint` ISeqs, not the original Rails/gem method location. The original method remains below them where applicable. |

Executed evidence: the real `Compilation.lowered` recipe plus same-line
splice reports `/tmp/bmethod-source.rb:2` and the same fallback exception
frame at line **3**, before/after. Evaluating the **actual AR-generated
source** with the installer's filename/start-line arguments reports
`lowrail:ar_instantiate:LocationProbe:2` instead of the inherited original
`/tmp/bmethod-original.rb:57`; fallback frames include both original line
**57** and synthetic line **9**. This is a generated-body probe, not an AR
admission/support claim. `CompilerTest#test_compile_matches_compile_file`
also passes **1 test / 18 assertions**. Source and output are retained in JSON.

An additional fresh-process probe uses **Fizzy's actual `Bubble#drafted?`**
and a deliberately raising reader. Installing a plain def in the same owner
with the original file/line keeps **both source_locations at enum.rb:307**.
But the original backtrace has `Kernel#public_send` and
`block in define_enum_methods` at line 307; the plain def has `drafted?` at
307 and no public_send frame. The diagnostic mutation is process-local, not
an eligible specialization or app patch. Thus original source_location
**and identical complete backtraces/line events** are not automatically
attainable by a filename/line argument. If full frame identity is required,
that is an unresolved refusal boundary, not something Lowrail already
guarantees. No delivered behavior was changed by this investigation.

## Ranked decision

1. **PARK enum predicate replacement.** Cleanest small domain; 59 app bodies
   inventoried, 34 in the five required 8.1.4 apps, but only **39/18** Fizzy
   calls and **0/6** blog calls. Reconsider with an enum-heavy real workload
   and an exact low-cost certificate/location policy, not by widening defaults.
2. **PARK class-attribute / route generator research separately.** Much more
   reach (**24,246/1,233** Fizzy calls; **1,099/297** blog), but captured mutable
   cells and live routing are not constant-foldable descriptions. Prefer
   framework plain-def generation investigation to a blanket Lowrail rewrite;
   this micro provides no meaningful class-attribute price.
3. **NO-GO for a store-accessor pass on these requests.** **222/235** Fizzy
   calls violate the no-overrides boundary; only **13** remain. Keep conversion,
   accessor selection and dirty tracking live; no replacement of custom readers.
4. **NO-GO for enum bang/scope work from this evidence.** Zero executions in
   either workload, with substantially more semantics than the predicate.

## Reproduction and appendix format

Use the corpus pins/overlays in `script/corpus` and `docs/compat.md`; do not
change foreign implementation code. Prepare the retained blog, isolated
schema-only DBs, the CASA external boot fixture and Fizzy fixture as described
above. From an app's directory, with its frozen bundle and environment:

```sh
mise exec ruby@4.0.7 -- ruby /path/to/lowrail/bench/experiments/bmethod_census.rb \
  static "$PWD" /private/raw/APP-static.json
LOWRAIL=0 RAILS_ENV=test mise exec ruby@4.0.7 -- bundle exec ruby \
  /path/to/lowrail/bench/experiments/bmethod_census.rb boot "$PWD" /private/raw/APP-test.json
# Production cases use their matching environment; CASA passes the existing
# casa_production_boot.rb as the optional boot-fixture path, against a NEW DB.
# The request worker's exact scratch source is JSON.request_harness_source.
mise exec ruby@4.0.7 -- ruby --disable-yjit bench/experiments/bmethod_census.rb micro /private/raw/micro-interpreter.json
mise exec ruby@4.0.7 -- ruby --yjit bench/experiments/bmethod_census.rb micro /private/raw/micro-yjit.json
mise exec ruby@4.0.7 -- ruby bench/experiments/bmethod_appendix.rb \
  /private/raw docs/bmethod-census.json "$RECORDED_LOWRAIL_REVISION"
```

The appendix is dictionary-packed rather than repeating hundreds of MB of
ancestries/paths. `apps[app].method_ids` indexes `methods`; column names are
in `method_columns`, `shape_columns`, `override_columns`. Holder/name/owner/
receiver/label/eval-digest and ancestry members index `strings`; shapes,
parameters, locations and ancestries index their named tables. **Index 0 is
valid; null means absent.** `source_location` paths are literal display data,
not normalized load-control permissions. Every request retains status, phase,
full route and counted identities. No cookies, generated secrets or real app
data are published. Invalid setup/observer attempts are named, not counted.

Validation losslessly decoded **117,217 method memberships across nine apps**
back to the raw reports, including source/argument/visibility/ancestry,
same-holder replacement flags and every consumer override. All static parses
succeeded. Both recorder controls detect private arguments/prepend overrides
and eval-generated plain defs; syntax checks and the 18-assertion compiler
check pass. The appendix's recorded Lowrail revision is
[`87356dd`](https://github.com/thomasklemm/lowrail/commit/87356dd9b4f2aefb5c65ed69b85cf20a57c6bc95).
Publication rebased through
[`553e7aa`](https://github.com/thomasklemm/lowrail/commit/553e7aa): the inspected
AR install, compiler replay and JIT-shape behavior are unchanged; later test
invocation/Prism parser changes do not relabel these historical observations.
Scratch instrumentation and owned services are removed/stopped after capture.
