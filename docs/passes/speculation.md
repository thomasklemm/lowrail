# Guard cost, unsafe ceilings and exact speculation

Rails 8.1 is primary; Campfire's Rails 8.2 alpha is supplementary. Experiments
use Ruby 4.0.7. Unsafe measurements are not support claims or permission to
deploy an unchecked specialization. Exact semantics or refusal remains the
contract; passing a finite suite does not close an invalidation hole.

## Monomorphic receiver slot

The receiver cache already validates method facts lazily after invalidation.
The historical approximately 663 Ir/check is cached dispatch, **not** walking
all facts on every call. `K[id]` adds a monomorphic receiver-class slot before
the existing polymorphic `V[id]` hash:

```ruby
self.class.equal?(::Lowrail::K[id]) || ::Lowrail.ok?(id, self.class)
```

`ok?` publishes only successful validations. Every existing method invalidation
withdraws K together with V. Installation initializes slots through the largest
unit ID, including gaps, to a private frozen non-class sentinel. An overridden
`self.class` returning nil therefore cannot match an unchecked slot. Statistics
mode withdraws all slots, including on late activation, and never publishes a
class: every counted call still goes through the existing counting path.
The regression also covers a different validated class returned by `self.class`,
invalidation, fallback, restoration and late statistics.

This is a dispatch optimization with **the same known invalidation limitations
as V**, not a claim that today's hooks cover arbitrary Ruby mutation.

### Integration gates

Before/after `lowrail verify`, all opt-ins, fixed suite seed 41231, serial test
workers and full SQL tracing: per-test outcomes and both complete per-unit maps
are identical on all five apps. Each verify also compares its on/off SQL trace.

| App | Outcomes | Hits | Fallbacks |
|---|---:|---:|---:|
| real-blog-r4 | 21 | 99 | 0 |
| PingCRM | 26 | 451 | 0 |
| React Starter Kit | 36 | 149 | 0 |
| Redprints CFP | 50 | 288 | 0 |
| Campfire (supplementary) | 634 | 10,918 | 3,496 |

Rails 8.1.4 L3, archived/current runtime: Active Record **9,240 outcomes**
(9,238 identities, including parameterized multiplicities), Action View
**2,747 + 242 + 173**. All outcomes and per-unit hit/fallback maps match.
AR completes 68,857 hits / 11,616 fallbacks; AV/AR integration completes 118
hits. The other two AV groups have zero installed-pass hits, not coverage of
a source route/view lowering. Gem tests: 91 tests / 1,557 assertions, no
failures/errors, six optional skips. Rust: 31 unit and three integration tests.

`lowrail bench real-blog-r4 --pass default --path /articles`, six independent
fixed-heap interpreter rounds, 50 warmups, N=0/50 total and GC-excluded windows,
unchanged app and production default builds:

| Runtime | Default total Ir/request | Versus no setup, % [95% CI] | A/A |
|---|---:|---:|---|
| Before K | 8,586,225 | −5.880 [−5.903, −5.825] | pass |
| K | 8,574,492 | −6.011 [−6.033, −5.967] | **reject** |

K's total off/off CI is **[+0.002, +0.064]%**, GC-excluded
**[+0.003, +0.053]%**: neither includes zero. Both heap controls pass. The
roughly 0.13 percentage-point difference is descriptive only; **no accepted
request improvement or native YJIT speed claim** follows. No retry or widened
tolerance was used. Both coverage probes complete ten routes/request.
Private raw evidence: `/tmp/speculation-k-blog-{before,after}`,
`.lowrail/speculation-{before,after}` and `.lowrail/k-rails-{before,after}`.

The unsafe ceiling, break attribution, micro-cost breakdown and residual
invalidation work are separate experiments, not part of the K change.

## Decision and remaining work

**Current-runtime holes remain open; exact residual checks are planned for
entry-level guards.** K preserves the existing cache's validity boundary; it
does not close those holes. Neither an `invokesuper` bytecode filter nor the
RubyVM constant-cache counter is a sound replacement for the missing checks.

The independently measured K-plus-residual example costs **4,470 Ir/check**
in the interpreter. Once against a 9 M-Ir request that is about **0.05%**;
repeating it at every lowered expression is unattractive. This prices four
small synthetic facts, **not** an arbitrary endpoint's entire assumption set.
An entry-level design must also handle mutation *during* a request: an entry
snapshot alone cannot protect a later use after a callback mutates a fact.
It needs a proven mutation-free region, effective revocation/deoptimization,
or a residual check at the use. Exact semantics or refuse still applies.

After the shared bench seam was released, guarded versus branch-elided blog
requests pass the controls: **0.081% default / 0.194% all-opt-in** interpreter
instructions are removed. Guard dispatch is not a large remaining opportunity
on this measured K runtime. These are unsafe ablations, not native YJIT speed
claims or exactness certification. See the request and single-pass results
below; runtime structural guards remain, so this is not the ceiling for
removing every runtime check. Campfire cached/uncached request ceilings remain
unmeasured: its test corpus was prepared, but production authentication/assets
were not, and the Rails 8.2 alpha was explicitly secondary to Rails 8.1.

## Measurement-only unsafe mode

`LOWRAIL_SPECULATE=unguarded` loads `bench/speculation.rb` from the source
checkout through `lowrail/setup`. It is deliberately outside the packaged gem,
requires an actual procfs ancestor running `lowrail bench`, `lowrail verify`
or this checkout's `script/rails-suite`, and prints
`UNSAFE UNGUARDED MEASUREMENT: BOOT FACTS ARE NOT CHECKED. NEVER DEPLOY.`
An ordinary process and production verification both exit 1 with a refusal;
the only production-environment exception is an actual benchmark ancestor,
because request benchmarks boot a production app. A missing experiment file
also refuses. This is an accident-prevention boundary, not a security sandbox.
`LOWRAIL=0` clears both unsafe ENV variables before loading the experiment;
the off-side smoke check confirms no `Lowrail::Speculation` module is loaded.

The experiment bypasses eligible units' method-fact validation and the
instantiate entry's AR epoch. Data-dependent STI, argument/relationship shape,
scope and stream-byte checks remain; L2's deliberately impossible delivery
probes remain false. Digest memo's first-call binding initialization is not
skipped. `LOWRAIL_SPECULATE_KEEP=ar_epoch` restores only the existing
instantiate epoch for attribution. There is still Ruby dispatch/cache-branch
overhead: **this mode is not a measured zero-overhead guard ceiling**.

`lowrail bench --speculate unguarded` now adds only an unsafe comparison layer;
guarded/original/off workers explicitly clear both unsafe ENV variables.
Ordinary strict preflight and activation/JIT probes remain mandatory, as do
the unsafe layer's own probes, heap matching, A/A and end-of-run fingerprints.
A disposable build recompiles generated source with fact guards elided while
preserving live input predicates, literals, UTF-8 positions and source lines.
Its manifest carries an incompatible `[LOWRAIL UNSAFE] ` Ruby-description
marker: the ordinary loader declines it; only the ancestry-checked experiment
accepts it. No unsafe build is a support claim.

All units must be selected. A named pass over a mixed build is refused:
eliding its siblings' disabled guards changes fallback dispatch, confounding
the ablation. Build each isolated pass separately instead. Native timing and
stacked/reference-build combinations are refused by this measurement mode.

A census of the four Rails-8.1 app ledgers found **zero additional existing-pass
sites refused solely because a true boot fact might change later**. Existing
passes already install mutable facts behind their guards. Remaining refusals
are structural, unmodeled or presently ineligible (template context, scope/query
certificates, options/argument shape, etc.). This is not a claim that a new,
broader lowerer could find no additional sites. No false-at-boot fact was
reclassified as eligible.

## Guard-tax request ceilings

Ruby 4.0.7, interpreter, six independent fixed-heap rounds, 50 warmups and
N=0/50 windows, seed 41231. Positive is guarded minus unsafe work. Both total
and GC-excluded instruction controls must accept; a failed control is retained,
not retried to get green. All unit/route counts come from separate Stats-on
probes, never the measured windows. This is request-level guard removal on
the pinned K runtime **before** the pending residual-closure changes, not a
prediction of a later, more exact guard's cost.

The combined selection is the nine-pass set `all-opt-in,-endpoint`; the
subsequent `endpoint/action` prototype is deliberately excluded. Runtime
dispatch, data-dependent predicates and runtime structural checks remain.
Consequently the all-opt-in result is the ceiling for **this fact/epoch
ablation**, not a full zero-overhead runtime-pass ceiling. No extra sites are
added by this mode; the existing-pass census above found zero eligible sites
refused solely because true boot facts could later change.

### Blog index, Rails 8.1.4

`GET:/articles`; each row is its own build, not a mask over a mixed build.
Total Ir/request and 95% CI, rounded to whole instructions:

| Build | Guarded − unsafe Ir/request [95% CI] | % of guarded [95% CI] | Coverage / request | Controls |
|---|---:|---:|---|---|
| default | 6,931 [2,974, 8,531] | 0.081 [0.035, 0.099] | 10 completed routes | accept |
| all-opt-in, excluding endpoint | 16,923 [11,049, 18,147] | 0.194 [0.127, 0.208] | 10 completed routes | accept |
| route/path only | −121 [−5,414, 5,744] | −0.001 [−0.060, 0.063] | 4 completed routes | accept; unresolved from zero |
| view/link_to only | 4,407 [390, 7,472] | 0.051 [0.005, 0.086] | 10 helper hits, no route units | accept |
| active_record/instantiate only | 12,973 [10,904, 14,338] | 0.142 [0.119, 0.156] | 6 instantiate hits | accept |
| active_record/preload_plans only | 5,096 [2,499, 8,972] | 0.055 [0.027, 0.097] | 1 hit / 1 fallback | accept |

The default body jointly lowers a `link_to` and its route; isolated source
builds therefore have different route coverage. Dividing the isolated helper
ablation by ten gives **441 [39, 747] Ir/helper invocation**. The path-only
estimate is **−30 [−1,354, 1,436] Ir/completed route**, unresolved from zero;
do not replace it with a positive micro estimate. Other runtime and memo
passes absent from this request have no attributed per-hit saving. Single-pass
rows are not additive: they change the installed set, generated body and heap
work. The combined build is the directly measured combined ceiling.

GC-excluded savings, in the same row order, are 6,110 / 17,667 / −1,527 /
3,285 / 11,884 / 7,245 Ir/request; full intervals, per-round slopes and
provenance are retained in `speculation-ceilings.json`. Interpreter work is
not convertible to native YJIT microseconds or a theoretical throughput gain.

Initial path/link masks over a mixed build produced negative estimates;
those are **invalid attribution**, not guard-tax results. They are retained
as such, and the published CLI now rejects that selection. Earlier attempts
without `SECRET_KEY_BASE_DUMMY=1` failed before benchmarking and provide no
semantic or performance evidence.

### Other corpus requests

| App / Rails / GET route | Build | Guarded − unsafe Ir/request [95% CI] | % of guarded [95% CI] | Controls |
|---|---|---:|---:|---|
| PingCRM / 8.1.4 / `/organizations` | default | 1,416 [−6,980, 6,731] | 0.012 [−0.058, 0.056] | **reject**, GC-excluded A/A |
| PingCRM / 8.1.4 / `/organizations` | all-opt-in, excluding endpoint | 22,398 [18,634, 33,301] | 0.189 [0.158, 0.281] | accept |
| React Starter Kit / 8.1.4 / `/dashboard` | default | 779 [−2,446, 4,731] | 0.009 [−0.029, 0.055] | accept; unresolved from zero |
| React Starter Kit / 8.1.4 / `/dashboard` | all-opt-in, excluding endpoint | 3,009 [−284, 6,625] | 0.036 [−0.003, 0.079] | accept; unresolved from zero |
| Redprints CFP / 8.1.3 / `/proposals` | default | 2,840 [149, 7,428] | 0.019 [0.001, 0.050] | **reject**, total A/A |
| Redprints CFP / 8.1.3 / `/proposals` | all-opt-in, excluding endpoint | 41,164 [33,398, 45,245] | 0.278 [0.225, 0.305] | accept |

All three routes complete **zero source units** in these builds, so the
default rows provide no per-hit source-guard tax. Rejected rows are retained,
not credited as wins. All-opt-in counted hits are instantiate **12 / 2 / 21**
and Inertia bind **5 / 5 / 4**, respectively; digest/preload/AR-reader units
have zero hits. Those combined request deltas are not assigned to a particular
runtime pass without a separate ablation. The Inertia shape/constant checks
and other structural runtime checks still run. The all-opt-in GC-excluded
savings are **20,837 / −361 / 42,517 Ir/request**; Starter's intervals include
zero for both metrics. Redprints remains secondary pinned-8.1.3 evidence,
not a claimed 8.1.4 measurement. No failed A/A row was rerun.

Initial all-opt-in probes on PingCRM, Starter and Redprints correctly refuse
an interpreter/JIT build mismatch: production boot enables YJIT, recording
`Array#each` at `<internal:array>:219`, while interpreter workers observe a
C method with nil source location. The mismatching Inertia fact makes
`Guard.validate` false before measuring. Corrected builds use the already
published `LOWRAIL_BUILD_JIT=0` hook; no activation check is weakened.
All three corrected cohorts pass both A/A metrics and heap matching. They
are new, changed-build experiments, not retries of the failed default controls.

## Unsafe break list

All-opt-in `lowrail verify`, fixed seed 41231, serial workers:

| App / pinned Rails | Outcomes | Own-thread SQL | Result |
|---|---:|---:|---|
| real-blog-r4 / 8.1.4 | 21 | 125 | identical |
| PingCRM / 8.1.4 | 26 | 809 | identical; **9 other-thread SQL differences**, advisory |
| React Starter Kit / 8.1.4 | 36 | 264 | identical |
| Redprints CFP / 8.1.3 | 50 | 692 | identical |
| Redprints system tests / 8.1.3 | 12 | 260 | identical |
| Campfire / 8.2.0.alpha, supplementary | 634 (2 skips) | 15,108 | identical |

Redprints is evidence for its pinned 8.1.3 build, not a substituted 8.1.4 run.
Other-thread SQL is not ordered/gating evidence; the nine PingCRM differences
are retained, not attributed to a guard without a reproducer. No guard/fact is
established as their cause. The same nine names recur in the final 26-outcome /
809-query PingCRM smoke run:

```text
ContactsTest#test_can_add_contact
ContactsTest#test_cannot_view_deleted_contacts_by_default,_but_allows_to_change_filter
ContactsTest#test_list_all_contacts_and_allows_to_paginate_and_search
LoginTest#test_Redirect_to_login_for_Inertia_requests,_too
OrganizationsTest#test_can_add_organization
OrganizationsTest#test_cannot_view_deleted_organizations_by_default,_but_allows_to_change_filter
OrganizationsTest#test_list_all_organizations_and_allows_to_paginate_and_search
UsersTest#test_Owner_can_add_user
UsersTest#test_cannot_view_deleted_users_by_default,_but_allows_to_change_filter
```

The initial Redprints system attempt used a wrong Chrome setup and is not
passing evidence; the corrected browser run is the row above. A final
unsafe-loader smoke rerun again completed blog's 21 outcomes / 125 queries;
fallback counts may change with lazy first-call initialization and are not
completed-hit budgets.

**Literal response-byte differential remains pending.** Test assertions and SQL
traces are not a replacement for it. Private raw logs are
`/tmp/speculation-{blog,ping,starter,redprints}-verify.log`,
`/tmp/speculation-redprints-system-v2.log` and
`/tmp/speculation-campfire-unsafe.log`. Never publish fixture headers/cookies.

Rails **8.1.4**, source `c3466ea00d7121798e3aa3144ffdf7174b81d8cb`, full component
bundle, L1/L2/L3, SQLite AR adapter:

| Suite | Outcomes per layer | Reproducible unsafe differences |
|---|---:|---|
| Active Support | 5,815 | 0; 5,814 stable identities + 1 anonymous-class identity |
| Active Model | 1,100 | 0 |
| Active Record | 9,240 | **34 L3 errors**, 0 L1/L2 differences |
| Action Pack | 4,095 | 0 |
| Action View | 2,747 + 242 + 173 | 0 |
| Active Job | 212 | 0; 209 stable identities + 3 timestamped Range identities |
| Action Mailer | 268 | 0 |

The unstable/transient identities are recorded in the evidence JSON; their
observations pass, but they cannot establish exact identity equality. L2 has
17 expected probe fallbacks per component, not accelerated-path coverage.
Only AR and AV/AR exercise genuine L3 runtime units; zero hits elsewhere are
not evidence for hypothetical lowerings. Rails SQL tracing was disabled by
the suite runner: this is an outcome/shadow gate, **not a Rails SQL gate**.

Every one of the 34 differences is off=`pass`, on=`error`, with
`Lowrail::ARShadow::Mismatch: active_record/instantiate: Rails planning differs`.
**All 34 are caught by the existing `Lowrail::AR.epoch`**: keeping only that
epoch while still bypassing method facts restores **9,240 identical outcomes**,
zero shadow mismatches, and the complete guarded hit/fallback maps
(68,857 / 11,616). Without it, the stale cached attributes builder produces
75,433 hits / 10,208 fallbacks. No new hook was needed to explain these breaks.

The complete differing identities (each has the same attribution above):

```text
BasicsTest#test_typecasting_aliases
BasicsTest#test_select_symbol
AttributeMethodsTest#test_write_attribute_does_not_raise_when_the_attribute_isn't_selected
DirtyTest#test_save_should_not_save_serialized_attribute_with_partial_writes_if_not_present
CalculationsTest#test_pluck_with_type_cast_does_not_corrupt_the_query_cache
UniquenessValidationTest#test_validate_case_insensitive_uniqueness
StoreTest#test_accessing_attributes_not_exposed_by_accessors_encoded_with_JSON
StoreTest#test_convert_store_attributes_from_Hash_to_HashWithIndifferentAccess_saving_the_data_and_access_attributes_indifferently
StoreTest#test_store_takes_precedence_when_updating_store_and_accessor
StoreTest#test_serialize_stored_nested_attributes
StoreTest#test_accessing_attributes_not_exposed_by_accessors
HasManyAssociationsTestPrimaryKeys#test_has_many_assignment_with_custom_primary_key
HasManyAssociationsTestPrimaryKeys#test_ids_on_unloaded_association_with_custom_primary_key
HasManyAssociationsTestPrimaryKeys#test_ids_on_loaded_association_with_custom_primary_key
HasManyAssociationsTest#test_calling_first_nth_or_last_on_existing_record_with_build_should_load_association
OptimisticLockingWithSchemaChangeTest#test_increment_counter_updates_lock_version
OptimisticLockingWithSchemaChangeTest#test_decrement_counter_updates_custom_lock_version
OptimisticLockingWithSchemaChangeTest#test_decrement_counter_updates_lock_version
OptimisticLockingWithSchemaChangeTest#test_destroy_dependents
OptimisticLockingWithSchemaChangeTest#test_update_counters_updates_custom_lock_version
OptimisticLockingWithSchemaChangeTest#test_update_counters_updates_lock_version
OptimisticLockingWithSchemaChangeTest#test_increment_counter_updates_custom_lock_version
SerializedAttributeTestWithYamlSafeLoad#test_serialize_attribute_via_select_method_when_time_zone_available
LeftOuterJoinAssociationTest#test_construct_finder_sql_does_not_table_name_collide_on_duplicate_associations
FilterAttributesTest#test_filter_attributes_on_pretty_print
FilterAttributesTest#test_filter_attributes_affects_attribute_for_inspect
FilterAttributesTest#test_filter_attributes
FilterAttributesTest#test_filter_attributes_could_be_overwritten_by_models
CascadedEagerLoadingTest#test_eager_association_loading_grafts_stashed_associations_to_correct_parent
ActiveRecord::CustomPropertiesTest#test_attributes_not_backed_by_database_columns_are_always_initialized
ActiveRecord::CustomPropertiesTest#test_overloaded_properties_save
CounterCacheTest#test_reset_the_right_counter_if_two_have_the_same_foreign_key
CounterCacheTest#test_removing_association_updates_counter
YamlSerializationTest#test_new_records_remain_new_after_round_trip
```

The list is checked against all 34 keys in the machine-readable
`unsafe_rails.activerecord.L3.differences`; the evidence retains both outcomes
for each identity, not just a difference total.

## Fixed-heap guard micro costs

`bench/guard_breakdown.rb` uses the shared counter extension and estimator:
six fresh processes per case, randomized case order, N=0/100,000, total and
GC-excluded windows, 100,000-call warmup, fixed five-pool heap floors,
independent loop/loop A/A, actual YJIT-state recording. Subtract the *paired*
empty-loop slope, not a guessed number of Ruby bytecodes. All cohorts below
pass heap and A/A controls; the latter's CI is [0, 0]%. Ir means executed
native instructions. YJIT Ir is not interpreter Ir and neither is nanoseconds.

| Check, Stats off | Interpreter net Ir | YJIT net Ir |
|---|---:|---:|
| Previous cached `Lowrail.ok?` dispatch | 822 | 371 |
| K + `equal?` | 425 | 140 |
| K with an additional truthy check | not measured | 230 |
| Class method identity, `klass.instance_method(:foo) == saved` | 1,138 | not isolated |
| Actual receiver method identity, `object.method(:foo).unbind == saved` | 1,796 | 1,286 |
| Own visibility, `klass.public_method_defined?(:foo)` | 369 | not isolated |
| One constant identity, `Target.equal?(saved)` | 311 | not isolated |
| Equality against independent two-key flat config snapshot | 2,081 | not isolated |
| K + class identity + visibility + constant identity + snapshot | **4,470 [4,468, 4,472]** | **3,019 [3,015, 3,019]** |

Combined costs are measured independently, not a sum of separately compiled
micros. The class-identity combined example does **not** additionally price an
actual receiver's hidden singleton override. Snapshot copying happens outside
the check; nested mutable values need independent deep snapshots or refusal.
Core reflection/equality operations also need certification or captured-core
bindings in a real residual guard. These are candidate costs, **not a shipped
complete exactness proof**.

The old approximately 663 Ir number and the owner's exploratory 803/340 Ir
micro use different loop/body shapes. Under this fixed-heap method old cached
dispatch is 822/371 and K is 425/140 (interpreter/YJIT). Do not subtract numbers
across those harnesses or call the entire old path per-fact validation.

### Callgrind attribution

The old cached interpreter path's **822 Ir** has the following disjoint self
costs, from the same fixed-heap cached/loop N=0/100,000 dumps. Each dump's
self-cost sum is checked against its full Callgrind total before subtraction;
inclusive call edges are not counted again. Round zero gives 822.005 Ir,
consistent with the six-round estimate above.

| Piece | Net Ir | Share | Function / largest source rows |
|---|---:|---:|---|
| VM opcode dispatch, array access and Ruby branch machinery | 482 | 58.6% | `vm_exec_core'2`; `insns.def:82` (23), `vm.inc:4681` (15), `vm_insnhelper.c:6123,6122` (14/12) |
| Constant-path/cache and lexical-environment lookup | 131 | 15.9% | `rb_vm_opt_getconstant_path` 84 (`vm_insnhelper.c:6637,6618`: 24/20), `vm_env_cref` 47 (`:845,839,867`: 8/8/7) |
| Receiver-cache hash lookup | 107 | 13.0% | `rb_hash_aref` 34, `rb_st_lookup` 56, `rb_ident_hash` 14, `rb_hash_start` 3; same principal source rows as the YJIT table |
| Ruby method-frame setup and argument copy | 51 | 6.2% | `vm_call_iseq_setup_normal_0start_2params_4locals` 41, `__memcpy_avx_unaligned_erms` 10 |
| Receiver class lookup and its builtin-call adapter | 33 | 4.0% | `builtin_inline_class_20` 24 (`kernel.rbinc:17,13`: 8/6), `vm_call_single_noarg_leaf_builtin` 9 |
| VM interrupt checks | 18 | 2.2% | `rb_vm_check_ints`, chiefly `vm_core.h:2232,2269,2272` and `atomic.h:991` |
| Epoch compare | **0** | 0% | no epoch compare on the cached method-fact path |

Less than 0.006 Ir/check remains in amortized call-cache lookup/write-barrier
costs. The 51-Ir method-entry share is not the entire cost of calling `ok?`:
its Ruby instructions execute in the 482-Ir VM bucket too. The VM profile
cannot split those into Ruby-level line costs without another overlapping
isolation experiment. Unit array lookup is in that VM bucket, not an
additional C-function share. Full interpreter function/line costs are in
`speculation-ceilings.json`.

The old cached YJIT path's net **371 Ir** decomposes into disjoint self costs:

| Piece | Net Ir | Share | Function / largest source rows |
|---|---:|---:|---|
| Generated native Ruby body, branches and call machinery, minus empty loop | 145 | 39.1% | unnamed JIT bodies +164 and −19; no Ruby line map |
| Constant inline-cache tests | 79 | 21.3% | `rb_vm_ic_hit_p`, `vm_insnhelper.c:6573,845` (8 each), `:867` (7), remaining rows in JSON |
| Receiver-cache hash lookup | 107 | 28.8% | `rb_hash_aref` 34 (`hash.c:2092,2101`: 12/11), `rb_st_lookup` 56 (`st.c:854,1065,1088`: 11/10/9), identity hash 14, hash start 3 |
| Receiver class lookup | 24 | 6.5% | `builtin_inline_class_20`, `kernel.rbinc:17,13` (8/6), remaining inlined rows in JSON |
| Unit array lookup | 16 | 4.3% | `rb_yarv_ary_entry_internal`, `array.h`, `jit.c` |
| Epoch compare | **0** | 0% | method facts are lazily revalidated after hooks; this cached path has no epoch compare |

The trivial Ruby dispatch micro costs 110 net YJIT Ir (314 interpreter), but
that is an overlapping isolation experiment, **not** another additive share
on top of the 145 generated-body remainder. Adding `object.class` changes JIT
code layout: its isolated delta is not a reliable class-lookup attribution.
The explicit class/epoch local-ivar prototype is likewise not more exact than
the hooks. K's 140 YJIT Ir is the measured minimal integrated dispatch here,
not an exact guard for facts whose hooks are incomplete.

## Invalidation coverage and minimal counterexamples

Run `mise exec -- ruby bench/speculation_holes.rb`. Each method/constant case
first validates the original fact, mutates it, then demonstrates a stale true
cached guard and a false candidate residual. These are **pre-existing runtime
holes**, not introduced by K or discovered only in a hypothetical new pass.

1. **Suppressed method callback.** After validation of `C#foo = 7`:

   ```ruby
   C.define_singleton_method(:method_added) { |_| }
   C.define_method(:foo) { 19 }
   # cached guard remains true; C.instance_method(:foo) != saved
   ```

   A saved method-definition identity rejects this (1,138 Ir for the class
   lookup above). Ancestor redefinitions need the effective lookup, not just
   an own-method table. Refusing custom callbacks at boot is conservative, but
   a later callback definition also needs a non-suppressible observer.

2. **An ISeq containing `invokesuper` is insufficient.** This hook contains
   `invokesuper` but deliberately skips it for the method that matters:

   ```ruby
   def C.method_added(name)
     return if name == :foo
     super
   end
   C.define_method(:foo) { 19 }
   ```

   Do not ship the proposed bytecode filter as a closure. Presence of an
   instruction says nothing about whether every path reaches it.

3. **Suppressed singleton callback, including its own definition.**

   ```ruby
   object.define_singleton_method(:singleton_method_added) { |_| }
   object.define_singleton_method(:foo) { 29 }
   # object.class is unchanged; the weak override tracker did not observe foo
   ```

   The new hook can consume its *own* notification. Checking only
   `object.class.instance_method` misses this. Effective receiver method
   identity, `object.method(:foo).unbind == saved`, rejects it; see costs above.

4. **Own visibility changes have no callback.**

   ```ruby
   C.send(:private, :foo)
   # saved method identity still matches; object.public_send(:foo) now raises
   ```

   Check the assumed visibility of the effective method (369 Ir for the
   public class case), or refuse. A Ruby wrapper around argument-less
   `Module#private` changes its lexical semantics and is not a fix.

5. **Constant replacement/removal.** Construct the replacement *before*
   validation so its method definitions do not incidentally reset the guard:

   ```ruby
   replacement = Replacement # already has a different .foo
   # validate Original's Target.foo here
   Host.send(:remove_const, :Target)
   Host.const_set(:Target, replacement)
   ```

   Constant identity (311 Ir for the simple measured lookup) rejects the new
   target; absence must also fall back rather than raise from the guard.
   `const_added` fires on definition **and replacement**, but **not removal**
   on Ruby 4.0.7. App callbacks can suppress it too. It is not a complete epoch.

6. **Direct configuration mutation bypasses setters.**

   ```ruby
   config = { limit: 7 }
   snapshot = config.dup.freeze
   config[:limit] = 31 # same object, no setter/epoch bump
   config == snapshot # false
   ```

   Compare an independently captured value snapshot (2,081 Ir for the measured
   two-key flat hash), or refuse. An identity check or a shallow snapshot with
   shared nested values is insufficient. Config setter hooks alone do not close
   this; I18n backend trees and resolver clearing retain their refusals in
   [ERB](erb.md) and [template lookup](template-lookup.md).
   This synthetic setter-epoch example is not a claim that `inertia/config_bind`
   caches option values: that pass copies live values and retains its existing
   per-call shape/constant checks. Do not remove those checks speculatively.

| Fact class | Existing mechanism | Complete for arbitrary changes? | Required remaining boundary |
|---|---|---|---|
| Method resolution / include / prepend / extend / remove / undef | ModuleHooks/ObjectHooks reset G/V/K | **No**; callbacks may be suppressed; module-descendant/refinement/C boundaries remain | effective method identity or conservative refusal; do not infer super reachability from ISeq presence |
| Own visibility | boot validation only | **No** | live visibility or refusal |
| Named constant target | boot `const_get`; possible `const_added` hook | **No** | identity/presence check or refusal |
| AR cached attributes builder | existing `Lowrail::AR.epoch` | catches **all 34 observed suite breaks**, not proof of all imaginable direct mutation | keep it; do not fold it away |
| Config values | setters / pass-specific live predicates | **No**, direct mutation bypasses setters | independent snapshot equality, existing live predicate, or refusal |
| I18n / template resolver state | no complete epoch established | **No** | continue refusal; do not credit theoretical lowering savings |

## Constant-cache counter: measured and rejected

`mise exec -- ruby bench/experiments/constant_epoch.rb` tests all
`RubyVM.stat` keys on Ruby 4.0.7, with Zeitwerk 2.8.3. It distinguishes a
constant read only through `const_get` from a warmed literal-path ISeq.

| Mutation | Δ `constant_cache_invalidations` |
|---|---:|
| `const_get`-only replacement / removal | **0 / 0** (every stat counter unchanged) |
| Warmed literal-path replacement / removal | 1 / 1 |
| Uncached autoload registration / materialization / removal | 0 / 0 / 0 |
| Cached autoload registration / materialization / removal | 0 / 0 / 1 |
| Removal of unmaterialized autoload | 0 |
| Zeitwerk reload / rematerialization, uncached name | **0 / 0** |
| Zeitwerk reload / rematerialization, warmed literal path | 2 / 1 |

The source explains the counterexamples: Ruby 4.0.7's
[`rb_clear_constant_cache_for_id`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/vm_method.c)
increments by the number of registered inline-cache entries for the name,
**not once per mutation**. It also counts already-invalid entries. No registered
entry means no increment, even though the constant changes. `const_get` alone
does not register a literal-path inline cache. `constant_cache_misses` counts
executed lookup misses, not mutations; neither it nor the cvar/shape counters
catches the zero-delta replacement/removal cases. `global_constant_state` was
removed in Ruby 3.2. No complete mutation epoch is exposed by these stat keys.

| Operation, net Ir over loop [95% CI] | Interpreter | YJIT |
|---|---:|---:|
| `RubyVM.stat(:constant_cache_invalidations)` | **7,081 [7,033, 7,161]** | **6,970 [6,906, 7,114]** |
| Read plus equality with saved epoch | **7,280 [7,152, 7,440]** | **7,027 [6,963, 7,203]** |
| Single constant identity check, for comparison | 311 | not isolated |

These two six-round cohorts also pass the same fixed-heap and A/A controls.
This API is not one cheap integer read: Ruby 4.0.7's
[`vm_stat`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/vm.c)
unconditionally interns **five** key names before returning the requested
counter. `rb_intern_const` performs symbol-table lookup rather than caching the
ID; no Hash is allocated for a symbol argument, and later shape-stat branches
are not executed after the first key matches. Symbol-table layout contributes
to the between-process spread. The read is over 22× the measured simple
identity check and is still incomplete.

**Decision:** keep constant-identity checks (or refuse); do not replace them
with `RubyVM.stat` reads.

## Reproduction and retained evidence

[speculation-evidence.json](speculation-evidence.json) retains all 34 differing
identities with outcomes, per-layer counts and unstable/transient identity
lists, the AR-epoch attribution control, per-round micro slopes, paired CIs,
heap/A/A gates, full function/line attribution, refusal census and the constant
matrix. It contains no app headers, SQL bodies or authentication fixtures.
[speculation-ceilings.json](speculation-ceilings.json) adds sanitized request
results, per-round instruction slopes, rejected/invalid attempts, manifest,
runtime and harness fingerprints, completed-unit counts and the interpreter
function/line attribution. Private raw response/heap/profiler dumps are not
published as if they were sanitized reports.

```sh
mise exec -- ruby bench/speculation_holes.rb
mise exec -- ruby bench/experiments/constant_epoch.rb
GUARD_JIT=0 GUARD_CASES=loop,inline,method_identity,visibility,constant_identity,snapshot,exact_residuals \
  mise exec -- ruby bench/guard_breakdown.rb /tmp/NEW-guard-residuals
GUARD_JIT=1 GUARD_CASES=loop,constant_counter,constant_epoch \
  mise exec -- ruby bench/guard_breakdown.rb /tmp/NEW-constant-cost-yjit
# Use a NEW suite output directory; prepare the pinned Rails 8.1.4 bundle first.
LOWRAIL_SPECULATE=unguarded mise exec -- script/rails-suite --out .lowrail/NEW-unsafe
LOWRAIL_SPECULATE=unguarded LOWRAIL_SPECULATE_KEEP=ar_epoch \
  mise exec -- script/rails-suite --out .lowrail/NEW-epoch-only --suites activerecord
# Interpreter runtime facts must be captured in interpreter mode too.
LOWRAIL_BUILD_JIT=0 SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=error mise exec -- \
  target/debug/lowrail build .corpus/real-blog-r4 --env production --passes all-opt-in,-endpoint
mise exec -- target/debug/lowrail bench .corpus/real-blog-r4 --pass default \
  --path /articles --speculate unguarded --out /tmp/NEW-blog-guard-tax
```

For the old-cache micro, use the archived pre-K runtime through
`GUARD_LOWRAIL_LIB`; a fresh checkout with K is not the same implementation.
Corpus verify uses each app's documented test command and prepared disposable
databases/assets/SSR, fixed seed 41231 and serial workers. Missing PostgreSQL
connection ENV in one final PingCRM smoke attempt caused no outcomes; that
attempt is not included as a passing gate or as an unsafe semantic break.

At the initial study publication, from `gem/`, `mise exec -- ruby -S rake test`
completed **91 tests / 1,564 assertions, zero failures/errors, six optional
skips**. The focused guard regression was **5 tests / 34 assertions**.
Counterexamples and the constant matrix reproduce exactly against retained
JSON; the documented 34 identities are checked against the outcome map.
Ordinary-process, production-verify and missing-experiment activation all
refuse; explicit off controls clear unsafe ENV and do not load the experiment.

At the unsafe-seam publication, the integration suite is **94 tests / 1,677
assertions, one known failure, zero errors, six optional skips**. The sole
failure is the intentionally red
`ViewTest#test_default_link_to_observes_a_suppressed_redefinition_after_warmup`
introduced in [the separate correctness regression](https://github.com/thomasklemm/lowrail/commit/5a15175).
It reproduces a normal guarded-mode byte error: a real request subscriber
suppresses `method_added` and redefines `link_to` after warmup; the stale
lowered body omits all ten live-helper comments. Effective helper identity
at use would catch it. It is a concrete instance of the pre-existing callback
hole, **not one of the 34 unsafe AR errors**. Its separately owned fix is in
progress; the final fresh gem run reproduces exactly that one failure, with
all other tests passing. After integrating the shared YJIT stability gate,
PassBench **15/139**, RequestPairs **10/68**, and Rust **33 unit plus three
integration tests** pass. The interpreter measurement reports retain their
original runtime/harness fingerprints; this integration does not relabel old
measurements as newly executed cohorts.
