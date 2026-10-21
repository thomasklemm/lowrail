# Active-freeze contract spike

2026-10-21, Ruby **4.0.7**, Rails **8.1.4**. Research, not a new tier or a
pass promotion. No Callgrind, timing windows, measurement cohorts or guard
changes. The sealed tier and seal-check retain their existing semantics.
App evidence uses study base
[`e32040d`](https://github.com/thomasklemm/lowrail/commit/e32040da3682ca79ee60aa658da16370ef1746a3);
it does not describe later sealed/form admission changes.

## Blog production: zero violations in the sampled paths

**Zero observed FrozenErrors** on the blog's two production request paths,
with lowering off **and** on, for all three candidate sets. This supports
continuing with a **selective, explicitly accepted production contract**,
not freezing every Rails process by default.

| Frozen set | C verification requests, off / on | Native bench requests, off / on | FrozenError raise events |
|---|---:|---:|---:|
| (a) Link/form certificate holders and complete ancestor chains | 2 / 2 | 4 / 4 | **0** |
| (b) Loaded app/framework/bundle holders and their chains | 2 / 2 | 4 / 4 | **0** |
| (c) (b), additionally Hash/Array/String/Enumerable | 2 / 2 | 4 / 4 | **0** |

That is **36 post-freeze requests**, excluding warmup, in 18 fresh processes.
The native driver is the original `bench/requests.rb` with
`BENCH_COUNT_REQUESTS=2 BENCH_WARMUP=2 BENCH_JIT=1`, separately for
`GET:/articles` and `GET:/articles/1`. No Callgrind extension is loaded; this
branch counts requests and exits before the timed benchmark. A separate
diagnostic return observer freezes after the existing warmup loop returns.
These traced processes cannot be reused for clean-VM pricing.

The C workers use `BlogProduction.worker`, its real production application,
SQL/event/load observers, two GET scenarios, four SQLite databases and
state restoration. Freeze occurs after boot/eager load and two warmup GETs
per scenario, before its scenario loop. This is explicitly **warm** evidence,
not a cold-load equivalence experiment. Each on worker retains seven link
hits (5 index, 2 show); form remains **0 hits**, with its existing passive
activation refusal. No form support claim follows from freezing.

The ordinary, unmodified cold C off/off/on control remains
**`rejected_off_control`** because of natural response entropy. No fields
were normalized or removed. Matching freeze violations and successful
requests are **not** a new differential-equivalence or speed result.

### Inventories and symmetry

Set (a) comes from the published artifact's link primitive holders and all
form inventory method holders, including the cached view class, template
compiler and constructor holders. It is not just Article/Comment. There are
**275 form method facts**; freezing them does not make the currently refused
form activatable. Both ordinary and singleton ancestor chains are closed,
including **Class, Module, Object, Kernel and BasicObject** where reached.

Set (b) is deliberately conservative: loaded modules with a constant or own
method source under the app or a loaded bundle gem, including anonymous
holders with method provenance. It includes third-party gems, not merely
Rails. It does not load autoloads to discover candidates; an anonymous,
source-less C holder cannot be attributed this way. The explicit certificate
holders in (a) are always included. Core holders can already enter (b)
through subclasses or mixins; (c) adds only what is still missing.

The enforcement switch is independent of `LOWRAIL`. The symmetry follow-up
also loads the seven relevant Lowrail adapter **definitions** in both arms
and explicitly includes them in the frozen set; it does not install adapters
in the off arm. This avoids a named runtime module being mutable only off.
Lowering-created anonymous implementation holders have no counterpart off.
The regression checks equal frozen flags, errors, values and audit reports
off/on for the same candidate objects. Neither arm is an unfrozen control.

The [sanitized census](freeze-contract.json) records the exact observations,
lock/source pins, inventories' sizes, named-holder symmetry and exclusion
lists. Complete private per-process reports retain **every** FrozenError
raise event with its full backtrace, including rescued/re-raised errors.
Counts are raise events, not unique mutation operations or failing tests.

## Fizzy production/jobs follow-up: warmup cannot remove recurring writes

The follow-up uses Lowrail
[`83bf0ba`](https://github.com/thomasklemm/lowrail/commit/83bf0baa9c21d86955e31f626bbc466b60c41f9d),
the same pinned Fizzy revision and Rails/Ruby versions, a disposable production
copy, precompiled assets and four SQLite databases. `SKIP_TELEMETRY=1` avoids
external Sentry delivery. Neither app nor framework source is patched.
The ordinary default build has **zero units** (existing quarantine/refusals):
both `LOWRAIL=0` and `1` exercise original Rails under the same explicit freeze,
not a new fast-path/support claim. The selected set is a **scenario-holder
probe**, not a claimed certificate: Bubble/User/Bucket/Event/Notification,
ApplicationController/ApplicationJob, the three app jobs and the seven
symmetric runtime definitions. Full ordinary/singleton ancestry is frozen.

Each process attempts seven real GETs: health, login, authenticated buckets,
bubbles, bubble detail, notifications and events. Authentication uses a real
Session and signed cookie, not an app authentication bypass. A testing request
helper only constructs the cookie; no test framework or exclusions are used.
The three actual jobs run via `perform_now`, with the production Solid Queue
adapter still configured: `AutoPopAllDueJob`, `RemoveAbandonedCreationsJob`,
`GenerateNotificationsJob`. Positive controls verify a due bubble is popped,
an abandoned creation is deleted and a reader receives a notification.
Enqueue callbacks write to the disposable Solid Queue database, but no worker
is started: queue claiming, GlobalID deserialization, scheduled polling and
downstream Turbo broadcast execution remain **uncovered**.

FrozenError **raise events per process**, off / on:

| Cumulative warm recipe | Selected holders | App/framework/bundle | Plus core |
|---|---:|---:|---:|
| Fixtures and seven request warm steps, one GET each | 22 / 22 | 22 / 22 | 22 / 22 |
| Additionally three job warm steps, one `perform_now` each | 19 / 19 | 19 / 19 | 19 / 19 |
| Additionally seven populated-request steps, one GET each | **9 / 9** | **11 / 11** | **11 / 11** |

The second recipe creates fresh job inputs after warming jobs. The final
recipe also renders pages with the resulting event/message data before the
freeze; empty-page warming had not exercised those paths. Each warm step and
its count is retained. This is a finite three-recipe census, not a retry until
green. There are **126 post-freeze request attempts and 54 real job attempts**
across 18 processes. Both raw request-only and final populated unfrozen
controls complete all ten scenarios successfully in both Lowrail arms.
Every frozen process reaches all ten attempts but exits nonzero.

Final selected-holder failures are the bubbles page and the auto-pop/delete
jobs: **nine** raises in `query_constraints_list`, `persistence.rb:224`.
The broad/core sets additionally hit **two** raises in
`SolidCache::Entry.connection_class`, `core.rb:230`, on bubble detail.
Off/on named inventories match exactly: 351 / 9,702 / 9,703 named holders.
Full ancestor closure is reported complete; no holder was silently excluded.

These two remaining patterns **cannot be fixed just by warming**:

```ruby
@query_constraints_list ||= if base_class? || primary_key != base_class.primary_key
  primary_key if primary_key.is_a?(Array)
else
  base_class.query_constraints_list
end

@connection_class ||= false
```

For the observed scalar-key models the first expression keeps assigning nil;
the second keeps assigning false. Both write again after successful prior
calls, and frozen classes reject the write. The final populated run witnesses
that failure, not just a source-level hypothesis. Do not set a fake truthy
memo or invent query constraints to get green. Freezing these model holders
needs a reviewed app/framework change that preserves memo semantics, or
refusal of that holder-dependent contract. Static doctor can flag falsey
`||=` class memos and known scalar-key model facts; the live path supplies
the evidence. Earlier lazy attributes/builders/relation delegates are warmable
for this finite slice, but removing their first failure only exposes the next.

[`fizzy_freeze.rb`](../bench/experiments/fizzy_freeze.rb) is the reproducible
worker (requires an explicit disposable-app marker). Its `FREEZE_WARM_JOBS`
levels are 0/1/2; restore the four empty prepared databases between processes.
The [sanitized event census](freeze-fizzy-production.json) preserves each event
and its full backtrace by hash reference, outcomes, warm steps and source pins.
Private logs retain response/SQL diagnostics; they are not published.
The [reviewed integration proposal](freeze-integration.md) keeps preflight
refusal distinct from irreversible freeze failure. Fizzy narrows the earlier
blog feasibility result: a complete ancestor closure alone does not make
freezing arbitrary Rails model holders production-compatible.

## Suites: onboarding evidence, not the production decision

Blog baseline: **21 tests / 54 assertions, green**. Fizzy baseline:
**124 tests / 458 assertions, seven existing `Current#reset_all` errors**.
Neither app source is patched. Fizzy is the coordinator-approved additional
app for the initial census; Wikino/CRM are not tested. The production/job
follow-up above is separate from these initial test-suite observations.

The raw initial targeted freeze, after loading the suites and generating
attributes/schema/model names, records **21 blog / 124 Fizzy** timestamp
memo errors. The raw broad/core runs record **two events each**: Minitest's
seed assignment and Selenium FileReaper's exit memo. Those early broad runs
froze test infrastructure and are retained as **invalid onboarding policy**,
not presented as production violations.

The corrected policy loads test frameworks and Turbo's test helper before
freezing, and explicitly excludes test classes/modules and their singleton
holders. The report publishes the actual list, not merely a filter name:
Minitest, ActiveSupport::TestCase, its test-only mixins and concrete app test
classes, Rails test fixtures, Capybara/Selenium, Mail::TestMailer and the test
adapters are outside the frozen set. Provenance-based selections are review
inputs, never production admission rules. Shared Ruby core holders are not
silently excluded. If an excluded holder was needed by the requested closure,
`ancestor_closure_complete` is false and `excluded_required_holders` lists it.
No such run certifies those excluded facts.

### Named warm steps, cumulative and counted

Each process records step names, targets and call counts. The initial schema
step covers **2 blog / 32 Fizzy** concrete model objects (including generated
HABTM models with repeated names). Subsequent model warm steps
call each eligible model exactly once; the JSON retains the actual list.

| Additional step | Call count | Blog targeted events after step | Fizzy targeted events after step |
|---|---:|---:|---:|
| Test framework/helpers + attributes/schema/model names | per loaded test file; per model | 21 timestamp memos | 124 timestamp memos |
| `timestamp_metadata`: `all_timestamp_attributes_in_model` | once/model | 21, now routes/arel/STI | 126, now routes/arel/association constants |
| `arel_table` | once/model | 21, arel errors become predicate-builder errors | 126, same substitution |
| `association_constants`: `Associations::Association` | 1 | 21 | 126, now CollectionAssociation/SingularAssociation |
| `test_order_default` and `lazy_routes` | 1 each, separately recorded | 21 predicate-builder/STI memos | 549, including repeated useragent load errors |

Unchanged totals do **not** mean a warm step did nothing. The exception
identities change: warming `arel_table` removes that error and exposes
`predicate_builder`; loading `Association` exposes further lazy constants.
There is no “retry until green” interpretation. The finite sequence stops
with unresolved paths; none of the suite results is a passing seal gate.

After the final declared test-helper/adapter exclusions and warm steps, the
targeted suite counts are **21 blog / 549 Fizzy** raise events. Blog's 21
tests all error in predicate-builder/STI memos; Fizzy reaches 124 tests with
120 errors and eight assertions, with predicate-builder, association and
repeated useragent-load errors. The final broad/core runs have **21 / 124**
events respectively, all first loading `ActiveSupport::Multibyte::Chars`.
These are lower bounds on remaining lazy work, not distinct app mutations.

The final explicit exclusion lists contain **756 blog / 844 Fizzy holders**,
counting singleton holders separately. All targeted excluded-required lists
are empty; broad/core explicitly report the removed test holders as holes in
their requested inventories. No Minitest/TestCase/fixture/test-adapter holder
is silently frozen to obtain these final results. The extra adapter warm
step has two require targets and is recorded separately in every final run.

### Classification and what doctor can know

| Observed pattern / source | Disposition | Static doctor potential |
|---|---|---|
| AR timestamp `@... ||=`, `timestamp.rb:65–77` | Warm the metadata getters; demonstrated removal, not an app rewrite. | Class-method ivar memo assignment is a source hint; reachability and sufficiency need the audit. |
| AR `arel_table` / `predicate_builder`, `core.rb:393/397`; STI `finder_needs_type_condition?`, `inheritance.rb:94` | Ordinary class memos. Warm each actual getter; predicate/STI remain unresolved in the bounded run. A nil/false memo or an invalidated cache cannot be fixed by one warm call in general. | Same syntactic hint; do not infer successful warming from `||=` alone. |
| Lazy route helper `define_method`, `route_set.rb:334` | `reload_routes_unless_loaded` before freeze removes this failure. | Literal generator/load sites can be flagged, but runtime route finalization is the witness. |
| AR Association / CollectionAssociation / SingularAssociation constants | Finite lazy loading; load only the needed hierarchy before freeze or refuse the affected contract. One constant was insufficient. | Autoload/require sites are hints, not proof of the complete future load set. |
| Turbo::Broadcastable::TestHelper definition | Load test helpers before the test seal. Not a request-time production monkeypatch finding. | Test source provenance is visible; do not classify every stack containing Minitest as test-only. |
| Minitest seed, ActiveSupport test-order default, Mail::TestMailer and fixture-class memos | Exclude test-only holders; warm the shared test-order default. No production app change demanded. | Recognizable test entrypoints/assignments; exclusions must remain explicit. |
| Fizzy's useragent lazy top-level constants, `user_agent/comparable.rb:1` | Frozen Object prevents first load. A declared first-request/useragent warmup is a candidate, **not demonstrated in this Fizzy run**. | Literal require/constant sites can be flagged; no static completeness claim. |

No production class-attribute setter, post-boot gem monkeypatch or lazy
attribute-method violation is observed in the two blog scenarios. That is
**not** a zero count for all app behavior. A genuinely live `class_attribute`
setter/redefinition, schema reload, feature-driven class memo reset or gem
patch after the seal needs an app/deployment change, an unfrozen contract or
unit refusal; repeatedly warming it is not a repair.

## Recommended contract and residual checks

1. **Choose units, then close the dependency set.** Freeze only selected
   certificate holders plus *all* their ordinary/singleton ancestors. Verify
   boot facts once before freezing. No omitted mutable ancestor, including
   Kernel/Object, may be called “covered”. No automatic pass activation.
2. **The app owns the seal point.** Boot, eager load, declared natural request
   warmup and job warmup precede it, identically with lowering off/on. Run
   production scenario audits before deployment; full job-worker lifecycle
   coverage remains an explicit gap here. A violation raises; it is not
   rescued into a fictitious safe continuation. Freezing is irreversible for
   that process.
3. **Retain actual receiver selection at each live boundary.** The published
   `Lowrail::Native.exact_class?(object, expected)` rejects singleton methods,
   singleton prepends/extend, even an empty eigenclass, and later subclasses.
   Use exact class-object identity for class receivers. A preceding check is
   not reusable after app callbacks/helper arguments may change a receiver.
4. **Certify lexical refinement state or refuse.** Refining a frozen class
   succeeds, and native actual-class identity does not detect refined lookup.
   New refinements do not retroactively change an already compiled lexical
   scope; source/ISeq/delivery certification must cover the actual lowered
   callsites. A Ruby mutation hook or `frozen?` cannot replace that certificate.
5. **Freeze data separately, selectively.** Class freezing blocks replacing a
   constant or assigning a class ivar/cvar, not `CONFIG[:nested] << value` or
   mutating an array stored in a class memo. `Ractor.make_shareable` blocks the
   tested nested plain-data write; it is not a blanket Rails-config solution
   (Procs, mutable caches and external state need separate treatment). Validate
   and deep-freeze only the certified literal graph. Keep request/config
   values live or guarded otherwise.

The Ruby probe demonstrates refinements returning 11 instead of 7, a new
subclass returning 13, an instance singleton returning 17, and a successful
nested constant write. Native rejects the subclass/singleton/extended Hash;
it does not reject refinement lookup. Class-variable writes, both direct and
through a method, raise. Nested class memo arrays remain mutable.

**Important blast radius:** a complete selected-unit chain already freezes
Object/Kernel. An unrelated gem's later top-level constant or include can
therefore fail even on an original, unlowered path. Refusing that unit does
not unfreeze Object or repair the request. If an app cannot accept that
shared-root contract, do not enforce this set in its production process;
keep its ordinary guarded/original behavior. “Unsupported units stay
original” is necessary, but not a global compatibility proof after freezing.

## Conditional payoff: operations, not a price

[`freeze_guard_census.rb`](../bench/experiments/freeze_guard_census.rb) runs
the real positive warmed guards ten times, with no pass rewritten. It then
counts the native predicate separately after a freeze. Endpoint receivers
are a positive method-fact fixture, not endpoint certification.

| Boundary | Existing primitive operations per hit | Conditional residual for frozen/certified dispatch |
|---|---|---|
| Props recursive guard | class 1, singleton_class 1, visibility 2, instance_method 2: **6 bound reflective calls**, plus two UnboundMethod comparisons | **1 native actual-class pointer comparison** |
| Endpoint `helper_current?` | singleton_class 1, instance_method 1, visibility 1: **3 bound calls**, plus method comparison | 1 native receiver check |
| Endpoint cached `template_current?` | singleton_class 1, instance_method 2, visibility 1: **4 bound calls**, plus run/template method comparisons | 1 native receiver check; path/locals/template selection still live |

The observed ten-call counts are 60/30/40 `UnboundMethod#bind_call` invocations
respectively, versus ten native `exact_class?` calls in the residual specimen.
The native primitive itself is a C `CLASS_OF` pointer comparison; it does not
construct an eigenclass. Keep main-Ractor, active-unit/contract authorization,
input shape/value/config and other non-method checks. Recheck receiver shape
at recursive entries and after live app code. This is an operation-budget
estimate, **not** a nanosecond/instruction/request saving.

The **275 form facts** and link's **6 view + 4 builder + 19 primitive + 2
delivery checks** are build/admission facts, not hundreds of present per-hit
operations. The current sealed link already relies on a production promise;
freeze would enforce its method part, not eliminate a new repeated census.
The form remains inactive at this source version. Do not claim removing
per-hit form checks that are not executing. The earlier props 6.857× price
remains unchanged; this spike does not re-price it or promote a pass.

### Prepared props companion: unpriced; counting selection is separate work

[`props_freeze.rb`](../bench/experiments/props_freeze.rb) pins and reuses the
published `83bf0ba` `PropsVariant.source` and `YjitRegression.setup` factory.
It evaluates only the pinned definitions prefix of the latter CLI, never its
driver/worker entrypoint. All eight arms use the same fresh nested input per
resolve and freeze Hash/Enumerable plus complete ordinary/singleton ancestry
at the same post-setup point, without a TracePoint. No measured entrypoint is
provided. `frozen_split` and `frozen_checks_original` replace only the method
census with **one `Native.exact_class?` per recursive entry**. Main-Ractor,
active-unit, mutable Guard state/validation and Stats behavior remain intact.

```sh
LOWRAIL_FREEZE=1 BENCH_JIT=0 mise exec -- ruby bench/experiments/props_freeze.rb --liveness frozen_split
LOWRAIL_FREEZE=1 BENCH_JIT=0 mise exec -- ruby bench/experiments/props_freeze.rb --check /private/NEW-proof
mise exec -- ruby bench/experiments/props_freeze_test.rb --seed=1729
```

The primary interpreter lifetime gate passes **478 comparisons** across the
same three Inertia versions and two frozen shapes. Checked arms must produce
exactly **20 authorizations / ten resolves**, no fallbacks; original/each
controls produce zero counts. Forced-false receiver authorization fails the
liveness gate. Separate off/on contract witnesses preserve callback order,
once-only evaluation and legal late per-instance mutation, while global Hash
mutation raises identically. They do not pretend forbidden mutations are
ordinary native-only lifetime cases.

One declared warm prerequisite was discovered: **first Ractor startup** tries
to prepend Kernel and fails after the full chain is frozen. That failed run
is retained. The Ractor case now performs one bootstrap Ractor before freezing
in **both** arms, then checks non-main fallback normally. This is not permission
to create Ractors cold after freezing or to omit Kernel from the closure.

The native study's accepted interpreter result still loses about 1.38%.
Its retained-window accounting attributes **1,132 Ir/resolve** to the two
native predicates: 454 BASIC lookup + 602 visibility lookup + 76 scaffolding;
**4,717.248 Ir** remains outside them. Predicate removal alone cannot close
the paired 1,427.777-Ir gap. Disabled Stats also accounts for 630 Ir inside
four `vm_defined` calls, plus VM opcodes. These are the native study's numbers,
not a price for this freeze specimen; see [props-native](passes/props-native.md).

The coordinator approved preparing **one combined** freeze/receiver/late-counter
specimen. The native study owns counting/non-counting selection, late Stats
activation witnesses and integration; it received these exact freeze-only
sources, dedicated witnesses and full source-pinned lifetime proof. That work
is not duplicated here. No cohort or slot request is made by this spike, and
there is no demonstrated combined win or production guard change.

## Tooling and boundaries

`gem/lib/lowrail/freeze_audit.rb` is a standalone doctor **companion**, not a
new `lowrail doctor`/`seal-check` flag. The CLI runs inside a disposable app
bundle, boots it, eager loads, executes an explicit warmup, freezes, then
loads a Ruby workload. It records rescued errors too and exits nonzero for
violations even if the workload rescued them. It keeps its observer through
test-framework `at_exit` workloads. Missing startup/workload success cannot
produce a passing report. Reports contain paths/holder labels/backtraces,
not config values, SQL, response cookies or arbitrary object inspection.

```sh
# Run from APP, using absolute paths; WARMUP and WORKLOAD are app-owned Ruby
# files. WARMUP must preload test support if WORKLOAD runs the suite.
LOWRAIL=0 ruby /path/to/lowrail/script/freeze-audit holders /private/off.json \
  --holder Article --holder Comment --warmup /path/to/warmup.rb -- /path/to/requests.rb
LOWRAIL=1 ruby /path/to/lowrail/script/freeze-audit holders /private/on.json \
  --holder Article --holder Comment --warmup /path/to/warmup.rb -- /path/to/requests.rb
```

Supply the existing symmetric `RUBYOPT=-I.../gem/lib -rlowrail/setup` when
actually comparing an installed artifact; merely setting `LOWRAIL=1` does
not create a build. Profiles `app` and `core` select broader inventories.
Named test exclusions use repeated `--exclude-holder`; the Ruby API also
accepts anonymous module identities in `exclusions:`. There is deliberately
no silent, default test-framework exemption in the production enforcer.

For an app-controlled post-warmup enforcement point, require the standalone
file in **both** arms and set `LOWRAIL_FREEZE=1` independently of `LOWRAIL`:

```ruby
session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: certified_holders)
session.start!(audit: false) # no TracePoint; mutations still raise
```

Without the explicit switch, `start!` is a no-op. Without the observer the
report says `enforced_without_observer`, never “clean audit”. The normal
runtime/setup does not require this file, infer holders, force warmup, freeze
anything or enable a pass. A production-grade admission certificate and
doctor static-rule integration remain future coordinator decisions.

Coordination: the sealed owner confirmed the separate boundary. No changes
to setup.rb, sealed.rb, seal.rb, form files, seal-check's SEAL001–009 ledger,
its epoch, or its test-double/unoptimized semantics are made here.
