# Active-freeze contract spike

2026-10-21, Ruby **4.0.7**, Rails **8.1.4**. Research, not a new tier or a
pass promotion. No Callgrind, timing windows, measurement cohorts or guard
changes. The sealed tier and seal-check retain their existing semantics.
App evidence uses study base
[`e32040d`](https://github.com/thomasklemm/lowrail/commit/e32040da3682ca79ee60aa658da16370ef1746a3);
it does not describe later sealed/form admission changes.

## Primary result: the production paths tolerate freezing, within this slice

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

## Suites: onboarding evidence, not the production decision

Blog baseline: **21 tests / 54 assertions, green**. Fizzy baseline:
**124 tests / 458 assertions, seven existing `Current#reset_all` errors**.
Neither app source is patched. Fizzy is the coordinator-approved additional
app for this first census; Wikino/CRM and production Fizzy/jobs are not tested.

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
   production scenario audits before deployment, with jobs still an explicit
   gap here. A violation raises; it is not rescued into a fictitious safe
   continuation. Freezing is irreversible for that process.
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
