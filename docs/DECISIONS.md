# Decision register

What we pursue, what is parked, and what is rejected, with the evidence that
decided it. Update this when a pass changes state. Numbers live in the linked
docs; this page only records the decision and why.

## Ancestry-changing delivery refuses whole artifacts (2026-10-22)

The all-sealed cold failure is a runtime defect, not witness noise. On the
retained blog, `Template#compiled_source` changes owner from
`ActionView::Template` to `Lowrail::Templates::CompiledSource`, and Preloader's
`#call` changes owner to `Lowrail::PreloadPlans::Hook`. The corresponding
module case-membership checks change false → true, and ancestry/loaded
features differ. `instance_of?` remains true in both arms; the two sampled
inherited-constant probes remain false. That does not prove arbitrary
constant lookup equivalent, nor excuse the demonstrated observations.

Refuse **the complete artifact** at manifest admission when any unit is
`active_record/preload_plans` or `sealed/link_to`, or its template table is
nonempty. This precedes Guard/Loader/pass installation and source delivery,
including mixed artifacts and selection of only a safe unit. Dropping an
unsafe unit alone could leave its lowered files/templates executable. Keep
the full witness unchanged; explicit `LOWRAIL=0` remains an original-only
control. Symmetric sealed observers are still present in both arms, not
on-only delivery. Build-time inventory/oracle code is retained, but its
presence in a manifest is not production support.

Verification-only discovery also refuses link through its existing
`verification_literal_table_observer_unavailable` ledger path, without
running that builder or emitting its files. An existing test checks the
explicit refused outcome/reason and exact remaining unit inventory. This
preserves passive AR/token/collection coverage rather than shipping a mixed
artifact that must refuse wholesale. All original 193 gem test identities
and their workloads/assertions remain, with unsafe activation assertions
changed to explicit refusal; none are deleted or newly skipped.

The isolated **form/token/collection** artifact still passes the same full
cold witness at both seeds, extended to every already-loaded named
Action*/Active*/Rails/Rack/Zeitwerk holder: **1,843 before / 1,857 after
requests**, equal in off-A/off-B/on. Neither forbidden prepend occurs in
any captured chain; loaded-holder census and loaded-feature order match.
Both 192-pair controls retain hits **104/398/87** (collection's 62 explained
fallbacks), native 50 requests retain **50/200/50** hits, zero fallbacks,
and epoch deopt **1/4/1**. Its emitted bodies and admission are unchanged;
the accepted **−15.02% interpreter Ir** price remains representative, with
no allocation screen or reprice needed. Mixed all-sealed responses are exact
at both seeds but **unexercised**, with zero hits, not recovered optimization
coverage. Raw off/off entropy remains rejected, not normalized.

## Token allocation fix and one new-rule blog cohort: preregistered (2026-10-21)

The token-only +32 objects/request is traced to per-hit view-context constant
caches and Kernel-owned `IVAR.bind_call` method entries, not warm admission
witnesses. A live-prefix/normal-suffix split and one literal view ivar read
remove about 32 objects/request, leaving token-only allocation-neutral,
not a win. Remaining guard reads stay exact; no native API/admission/default
or quarantine change. Strict production regressions **2/201** pass; independent
Thermos reviews approve. [Allocation trace and limits](passes/token-allocation.md).

**Before counting:** the owner authorizes exactly one new blog interpreter
cohort in slot 1 on the published fixed source, isolated form/token/collection
artifact, under a new A/A decision rule. Both total and no-GC A/A nominal
95% intervals must lie **wholly within ±0.1%**; containing zero is **not**
required. The prior no-GC interval **[+0.009283,+0.062511]%** is noise far below
the effect being priced: the old rule rejected precision rather than material
bias. This is a prospective rule, **not a re-score**: the `62f8a6b` cohort
stays rejected under its original rule and is never pooled with the new one.

All other historical-method gates stay fixed: six rounds / seed 41231,
18 serial workers / jobs=1, N0/N50, warmup50, floors
`[1000000,250000,100000,20000,10000]`, identical pinned brk512 tool and worker,
actual interpreter/no JIT, exact pages/heap ranges/brk, fresh pre/post cold
seeds 0/1, both 192-pair controls, native coverage and epoch deopt. Retain all
rounds and accept or reject the whole cohort; **no retry or exclusions**.
Only this driver's summary policy changes, not other shared-harness gates.
YJIT seam work stays paused; no README/results edit by this worker.

## Blog new-rule interpreter re-price: ACCEPTED (2026-10-21)

The one prospective cohort on clean detached `b059fc9` completes: **−15.022961%
total Ir [−15.051352,−14.996655]**, no-GC **−15.021453%
[−15.044109,−14.967704]**. Both A/A intervals are wholly within the
preregistered ±0.1%: total **[−0.068389,+0.004169]%**, no-GC
**[−0.077337,+0.033586]%**. All other gates pass: heap/exact pages/brk,
actual interpreter, fresh pre/post cold seeds, 192+192 observable pairs,
native/deopt. Independently reconciled 72 dumps/self-cost sums, 36 subtractions,
18 source certificates and 681 pins. Exactly six rounds / 18 serial workers;
no measurement retry/exclusions. Launcher refusals before counter work and
after completion are retained; service stopped and slot 1 released.

This replaces the defective-source headline **only for this three-unit blog
endpoint/fixture**. The old `62f8a6b` rejection is not rescored; `553e7aa` stays
historical/defective-source only. Token-only is allocation-neutral, not a win;
do not attribute the entire cross-source difference to it. No latency/YJIT,
whole-app, test-tier or default promotion claim. README/results remain with
the docs owner. [Protocol and complete accepted export](passes/production-aa01-reprice.md).

## Production sealed helper dispatch safety (2026-10-21)

Production token admission did not refuse an existing view `send` override
or a private live generator. Stock Rails calls those helpers implicitly;
the specialization used `view.send` and a public generator call. Reproduced
before a fix: wrong CSRF name with generation/conversion/send counts 1/0/1
versus stock 1/1/0, and a private generator raising `NoMethodError` instead
of generating once. Both were admitted, not post-seal mutations.

Use a captured, independently stock-certified `BasicObject#instance_exec`
to run actual implicit calls on the actual view. It bypasses view-defined
`send`, `__send__`, `public_send`, `method` and `instance_exec`, while retaining
private/protected and `method_missing` dispatch, stock `defined?` semantics,
live ordering and saved-value continuation. Apply the same mechanism to the
form's builder/buffer/URL/token boundaries. Keep the named route's original
explicit `public_send` with a newly constructed String name and its live app
override effects; polymorphic routing does not call that helper implicitly.
Collection's existing implicit renderer calls need no change. A separate
follow-up fixes `Sealed.link?`'s private `tag_builder` call with the same
primitive and certificate fact; its pre-boot hostile-view regression fails
on unchanged main. Test admission
remains a separate, unpublished review and will consume this one primitive.

**The accepted −15.225536% was measured at
[`553e7aa`](https://github.com/thomasklemm/lowrail/commit/553e7aafa88754fd32359e5e11ba0cc5bfcd6f65),
which had this dispatch defect. It remains a price for that exact source and
specimen only, not the fixed runtime.** The separately authorized replacement
cohort at `62f8a6b` is rejected below. The later prospective `b059fc9` cohort
above is the accepted replacement, not a reclassification of that rejection.
Default/quarantine/guarded passes are unchanged;
YJIT seam work stays paused and `835cf16` parked.
[Dispatch sweep and correctness gates](passes/sealed-production.md#helper-dispatch-safety).

## Dispatch-corrected interpreter re-price: REJECTED A/A (2026-10-21)

The prerequisite screen passes exact status/body/all-header checks and the
fixed allocation rule: off-A/off-B/on **2412/2412/2069** objects/request,
343 saved (14.220564%); S's earlier on median was 2019, 50 lower. Same active
Article/Comment/form/token/collection counts **1/2/1/4/1**, no fallbacks.
The twenty-unit full-stack screen is not the three-unit interpreter specimen
or a paired causal attribution of those 50 objects. Native wall is not priced.

Exactly one historical-method cohort at clean detached `62f8a6b`, six rounds,
18 serial workers, slot 1: total A/A passes **[−0.008722,+0.064901]%**, but
GC-excluded A/A **[+0.009283,+0.062511]% excludes zero**. **Reject the whole
cohort; no replacement price, retry, exclusions or relaxed rule.** Diagnostic
only: total **−14.536782% [−14.552516,−14.507619]**, no-GC **−14.537277%**.
Heaps/exact pages/brk/mode pass; 72 dumps/self-cost sums, 36 subtractions,
18 certificates and 681 source pins independently reconcile. Pre/post cold,
192+192 observable pairs and native/deopt gates pass; raw entropy still rejects.
Slot 1 is released. No YJIT or default/quarantine change. The old −15.225536%
stays defective-source only. [Method, rejection and complete export](passes/production-dispatch-reprice.md).

Working assumption: many small exact passes (each < 2 %) should **stack**.
`lowrail bench --passes SET --default-build DIR` (8db84d8) measures a pass set as one layer against no-setup and a separate default
reference, and report the stacked effect next to the sum of individual
expected effects, with uncertainty. Real per-hit instruction budgets are
still missing for most passes (`measurement_complete: false`); adapters are
the current bench work. Promotion to
default still follows [ARCHITECTURE.md §4](ARCHITECTURE.md), applied to the
stacked set as well as to single passes.

## Campfire r81 room instantiation: KILLED after screen + one variant (2026-10-21)

Original room screen: allocations 15526 → 15578.5/request; wall −0.741%, A/A floor 5.571%; no win.
Each of 52 hits allocates an Array in disabled `ARShadow.enabled?` (`%w[1 strict]`); 10000 calls allocate 10002 objects versus two with an allocation-free predicate.
One branch-only variant removes that overhead, not the underlying tie: allocations 15525.5/15525/15524.5 (off-A/off-B/on); wall −4.168% [−6.107, −1.864] fails 3× the 4.293% A/A floor.
Both screens reject exact body/all-header identity even off/off; the warm validation boundary is unclassified, not normalized or dismissed as cold entropy.
Kill the Ir cohort; slot 2 released, no runtime promotion. Keep browser/CSRF/cookie/ETag/runtime/session-clock/Redis-expiry rejections, blog feature exemption and ten cached-bind gaps named. [Both screens, allocation proof and independent five-route result](campfire-bench.md#13-screen-one-allocation-only-variant-then-kill).

## Campfire r81 instantiation: companions accepted, screen before price (2026-10-21)

The single authorized companion rerun exits 0 for both seeds, off/off/on:
HTTP bytes, SQLite, loads/non-Lowrail feature order, events and completed/exit
state agree under the declared controls. **Named items stay next to this result:**
browser other-thread nondeterminism; raw CSRF/cookie/ETag/runtime/session-clock
rejections; Redis `rate-limit:sessions` expiry accepted off/off rejection;
the blog's path/hash-pinned Lowrail feature exemption; ten cached lazy-Proc
binds/worker unavailable, never evaluated. All 42 Redis key names/values and
41 other expiries remain exact. Cold login+room has 103 hits, outside warm work.

The warm target remains 52 hits (Account5/User5/Message40/Boost1/Session1) plus
two Room STI fallbacks, **only campfire-r81 02023b0, not the Oct-8 fixture**.
Both phase orders retain the frozen pages in 16 exact-worker tool=none windows.
Slot 2 was assigned; its launcher fails before any counted Callgrind worker or
window. Its initial log was overwritten; the cause remains unconfirmed.
The new **screen first, price rarely** policy arrives before Ir measurement:
no cohort retry or price. The subsequently published shared screen and one
variant kill the bet (above). No runtime/default/quarantine or app patch reaches main.
[Evidence, exclusions and private-receipt hashes](campfire-bench.md#12-one-authorized-companion-rerun-accepted-with-named-items).

## Prism 2 adoption and target grammar (2026-10-21)

Adopt Ruby Prism 2.0.0 for development (app bundles may retain 1.9), and Rust
`ruby-prism`/sys 2.0.0 with exact Rubydex
`c69a742c9097a2a5c13f97726abda55b0507121b`. Its `^2.0.0-rc.2` already accepts
stable, so upstream #1078 is not a prerequisite. The old Rubydex pin's native
`links=prism` conflict and 36 mechanical API errors are recorded, not bypassed.
No Rubydex API integration or witness/type-recovery adoption follows.

Exactness requires explicit grammar: Ruby `version: "current"`; one shared
Rust parser uses captured boot/build runtime, 4.0 → `CRuby3_5`, 4.1 →
`CRuby4_1`. Missing/unknown targets refuse; standalone `parse` requires
`--ruby-version`. Both old Rust 1.9 and 2.0 plain `parse()` selected latest;
that pre-existing boundary is now closed. The 4.1-only `&nil` regression
fails on plain parse. Thermos correctness/security and maintainability
follow-ups found no blocker. A naming-only consistency hint, not a behavior
bug, is [ruby/prism#4297](https://github.com/ruby/prism/issues/4297).

Nine-app census payload, delivered blog ISeq/source bytes and paired Rust
facts/types/MCP/build trees match. Ruby manifests change only the two edited
build-source pins; a later independently published render-unit fix is named
separately. Wall/RSS samples are untimed-cohort diagnostics, no speed claim.
Both Ruby 4.0.7 and pinned 4.1 preview gates run, retaining explicit 4.0-only
fixture skips. The regenerated supplied blog fails the production source pin
on baseline too; the owner-retained fixture passes strict form gates. No pin
relaxation. `Prism.find` has 17 source-backed agreements but generated ERB
and isolated Proc probes return nil: no witness adoption. Full inventory,
limitations and machine evidence: [prism-2.md](prism-2.md).

## Fizzy block links: N=50 INVALID; N=10 scoped warm bench price (2026-10-21)

**Rule before numbers:** any pin/mode/brk/exact-page/mix violation invalidates
the whole cohort; both total/no-GC A/A 95% intervals must contain zero wholly
within ±0.5%. No exclusions or retry-to-green. The completed N=0/50 cohort
is **INVALID**: heap pages grow in both off and on. **Diagnostic numbers
only, never a price or direction claim:** total Δ +0.415777%
[+0.364704, +0.733074], no-GC Δ +0.413692% [+0.364724, +0.448149].
Both A/A controls pass, as do pins/mode/brk and the exact 1200-hit mix;
the heap failure still invalidates everything. All 18 workers, 72 dumps and
36 N0 subtractions independently reconcile. No retry/exclusions. The old
service/slot is released. [Complete INVALID export](fizzy-link-ir-invalid.json).

**N=0/10 accepted as a scoped warm bench price, not a win:** total interpreter
Ir **+0.403071% [+0.386235, +0.429585]**, no-GC **+0.402000%
[+0.380081, +0.421142]** for these six Fizzy GETs at the stated floors only.
Cold off/off/on remains **RED**. Accepted named off/off rejections: nine
SolidCache `created_at` values and historical estimation-SQL interleaving.
**Uncovered:** payload/assigns, lazy cached-bind values, SolidCache completion.
No production admission, cold-start or whole-app claim.

Init slots are floors, not caps. Untimed off-only whole-window allocation
budgeting with N=0/10 yields fixed init slots
`3350000,300000,460000,30000,20000` (254 MB of slots). Fresh off/on workers in
both phase orders retain exact pages and add none inside all 16 windows;
full on windows have exactly 240 hits/19 identities with four explicit zeros.
The one authorized replacement completes six rounds / seed 41231 /
off_a/off_b/on / jobs=1 after the old slot release. Both A/A 95% intervals
contain zero within ±0.5%: total [−0.046920, +0.026381], no-GC
[−0.042940, +0.026493]. All 18 workers retain exact pages, zero page additions
and the exact 240-hit/19-identity mix with four zeros; 72 dumps and 36
subtractions independently reconcile. Same detached harness/brk512 tool;
no app/config/GC-policy change, higher-segment tool, retry, exclusions, YJIT
or pooling with invalid N=50 data. Slot released. The untimed report retains
its original request-only proposal as historical evidence.
[Complete scoped N=10 export](fizzy-link-ir-n10.json).
[Protocol, failures and reproduction](block-link-specimen.md#untimed-heap-preconditioning-prefer-n10-on-the-existing-tool),
[all untimed window evidence](fizzy-link-heap.json).

**One improvement KILLED before screening:** branch-only request-cached dependency scan backed by existing Guard resets.
Ruby 4.0.7 / Rails 8.1.4 control: one scan; after `private :content_tag_string`, cached eligibility stays true while the full post-block scan is false.
Stock saved-builder dispatch enters `method_missing` and raises `ArgumentError`; cached eligibility would bypass that live error.
Visibility changes fire no Guard hook; bet D also leaves saved-ancestry, suppressed-callback and refinement holes open. No authoritative epoch.
Correctness prerequisite failed: no HTTP/allocation/YJIT screen or new cohort. Keep the stock fallback; production widening is PARKED and block-link work stops.

## First accepted whole-request price (2026-10-21)

**Historical at ae025b0; the corrected-source re-price below supersedes it.**

**Interpreter Ir on one blog endpoint and fixture**, not a Rails-wide speed
claim: production form/token/collection, **BlogShowGetOnly GET /articles/1**,
Ruby 4.0.7 / Rails 8.1.4, measured at
[`ae025b0`](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb).
One authorized six-round, seed41231, N=0/50 cohort: **−15.49% total Ir
[−15.51, −15.46]**, **−15.51% GC-excluded Ir**; both A/A controls contain
zero within ±0.5%. All heap/exact-page, brk512 and interpreter-mode gates pass.
Every worker records the clean detached harness revision and source pins.
Migration counts remain unavailable; allocation change is diagnostic only.

The JIT-specific idle companion is not applicable to interpreter and was not
run. An initial `RAILS_ENV=nil` command refused before any counter worker;
only the explicit production environment was corrected. Slots 1+2 are released;
no retry/exclusions, no old-fixture comparison and **no YJIT cohort**. The
historical pricing specimen below stays rejected. Test-certificate AR review
comes next, then design-only token/collection test admission; neither follows
from this price. [Exact scope, gates and numeric export](passes/sealed-production.md).

## Token continuation safety after the measured revision (2026-10-21)

Live token generation can replace the actual view's `@tag_builder` without
changing any method, constant or boot config. The entry holder check therefore
does not authorize literal tag assembly after generation. Recheck the actual
builder holder/context after generation, name conversion and autocomplete
policy, then use stock `tag` with the saved values when it no longer matches.
Never replay token generation or conversion. A foreign builder is a local
input fallback, not a sticky dependency retirement; restoring the stock
builder permits another hit.

The production regression installs its generator and replacement builder
class before boot/admission. Stock output is
`<input data-probe="late-builder" />`; the old specialization incorrectly
emits a literal hidden input. The regression checks output equality, one
generation per arm, the fallback and subsequent stock-builder hit.

**This safety fix changes the measured source.** The accepted −15.49% price
above remains scoped to `ae025b0`, interpreter Ir on one blog endpoint and
fixture. It is not a price for the corrected runtime. No new cohort, cost or
speed claim is made. Production equivalence gates are correctness evidence,
not a remeasurement. Token/collection test admission remains separate; the
blog test configuration disables forgery protection, so empty-token hits
cannot cover protected-token assembly. Form remains refused in that tier.

## Historical pre-dispatch-fix interpreter re-price (2026-10-21)

The separately authorized **one** interpreter cohort at published `553e7aa`
includes the token continuation fix: production form/token/collection on
**BlogShowGetOnly GET /articles/1**, Ruby 4.0.7 / Rails 8.1.4, **−15.23% total
Ir [−15.25, −15.21]**, **−15.25% GC-excluded Ir**. This replaces the earlier
price for the corrected specimen; −15.49% remains historical at `ae025b0`.
It is not a native-latency, YJIT, test-tier or whole-app claim.
The later dispatch defect means it is not a price for today's runtime;
the [dispatch-corrected replacement attempt](passes/production-dispatch-reprice.md)
is rejected, not another accepted result.

Six rounds, seed 41231, 18 sequential workers, identical accepted N0/50,
fixed-heap/exact-page/brk512 method. Both A/A controls contain zero within
±0.5%; all gates pass. All 72 dumps and 36 subtractions independently reconcile,
every worker pins the clean detached SHA before/after, and pre/post cold,
192+192, native/deopt controls pass. No retry/exclusions; slot 1 is released.
No production/default/quarantine change. The YJIT candidate remains rejected;
the separately authorized scratch native caller diagnostic is not a price
or a v2 execution. [Protocol and complete export](passes/production-interpreter-reprice.md).

## Current production YJIT method: native candidate rejected (2026-10-21)

Untimed only, at pinned `f34a35c`: mode-certified production form/token/collection
on BlogShowGetOnly show passes seeded cold off/off/on, both 192-pair controls,
and native/deopt. Warm per-request hits are 1/4/1 with zero fallbacks. All six
native dry processes exit 0 and all 24 actual windows have flat compilation,
entry, invalidation, code-GC, compiler-time and full-log observations.
Nevertheless the registered fixed 10,000+2,000 candidate **rejects**:
production/order0 has only **8/10** quiet certification intervals. At the
request-400 sample (requests 201–400), `ConnectionPool#discarded?` adds one
entry/two blocks and **408 log bytes**. No extension, retry, exclusions,
Callgrind/timing cohort or new price. Flat windows do not rescue warmup.

Retained logs show the same extra entry in every off/on worker, but earlier
in off; production phase timing is asymmetric. The subsequently authorized
scratch-only native diagnostic establishes the **on** mechanism: actual
20-second `AR Pool Reaper`, ten normal-path calls per tick, count 91→101→111;
third tick's `keep_alive → sequential_maintenance → discarded?` crosses
119→120 and installs the normal entry while the request count stays fixed
at 12,050. One off/one on process only; the off recorder missed its startup
stop and was not rerun. Off caller provenance is unavailable, not inferred.

V2 now requires K=10 quiet intervals **inside each Valgrind worker**, plus an
80-second quiet minimum for these frequencies, under preregistered request/time
caps; native calibration is not a certificate. Actual windows must be flat.
The zero-overlap proposal is superseded by **request-thread-primary Ir** with
all-thread background reporting. Existing native N50 envelopes are 0.076–0.098 s;
the hypothetical 50× projection is already 3.8–4.9 s, not 190–245 s. Actual
Valgrind duration/ticks must be recorded. Raw background share is capped at
**0.5% per worker/mode**; pooled completed-reaper-tick Ir rates must agree across
off-A/off-B/on within **1% per mode**, with no partial ticks or unknown mappings.
The tolerance formula was preregistered before synthetic validation; three
equal-background/different-request controls each gave **300,150 Ir/tick**,
0% spread and the fixed minimum 1%. Sparse/zero-denominator data rejects.

The standalone bench-only all-thread adapter passes its one authorized
two-pthread process (**13 windows, 25 files**), interpreter-only API smoke
(two files) and native refusal. Known asymmetric instruction costs, all-thread
reset/rebaselining, request-only exclusion and negative current-thread-only
controls all reconcile; no background work is lost. This is mechanical evidence,
not Rails/YJIT thread mapping or a cohort. The source-pinned reaper overlay seam
remains a **proposal, not installed**: native marks after the real sleep and
after original maintenance, identical in all arms, no app method callback.
The API's C-entry cost is **108 Ir/tick**, excluding Ruby/JIT dispatch,
registration and topology effects; all observer costs must stay charged.
Owner review of that seam, lifetime mapping and the final v2 rule is still
required; **no Rails/YJIT app worker or cohort ran**. Quiet is not compiler
closure or guaranteed A/A. `835cf16` stays parked; no YJIT stage 2. The accepted
interpreter re-price does not rescue the rejected candidate.
[Method, exact-SHA export, causal limits and design-only v2](passes/production-yjit-method.md).

## Combined specimen must pass its own cold gate (2026-10-21)

Form+token+collection is a single whole-request interpreter experiment, not
the arithmetic sum of isolated prices. The combined cold gate now checks all
Lowrail loaded features **in actual order**, as well as complete ancestry,
owners/source locations, SQL streams and post-exit effects. It exposed on-only
`compilation.rb`, `loader.rb` and `routes.rb`; explicit sealed setup now defines
those helpers symmetrically, without installing their hooks in the off arm.
No guarded/default path or invalidation guard changes.

Both declared seeded off/off/on comparisons pass; raw entropy remains a
rejected off control. The artifact has one form unit and zero files/templates,
with neither known asymmetric Template/Preloader chain. Both 192-pair controls
record form104/token281/collection104, and 50 warm requests record 50/200/50,
all with zero fallbacks. This admits **pricing only**, not production token or
collection support. The published, pinned six-round interpreter cohort is now
**REJECTED**: total A/A is +0.025019% [+0.006339%, +0.051123%], excluding zero.
Combined −17.862649% total / −17.863529% GC-excluded Ir is **descriptive only**,
not a speed claim. GC-excluded A/A, all five heaps and all 18 interpreter-mode
checks pass but cannot salvage a failed total control. No rerun, filter stage,
additive claim or promotion. Untimed diagnosis of all 48 off-worker profiles
establishes **no concrete fixable harness cause**: no in-window GC, matching
outside-window collection counts, negligible A/B subtraction seams, but live
object/allocation and native lookup/allocator differences. Queue order does not
explain the signs; actual CPU placement was not recorded. No replacement
cohort is proposed. Another would require a pinned harness fix and separate
approval, not a hypothesis or a candidate change.
[Protocol, pins and retained failures](passes/sealed-combined.md).

## Passive form admission, not runtime recertification (2026-10-21)

Use the first **natural, wholly original** certified form render as a read-only
admission witness. Build-time synthetic auditing remains separate. Require the
published native `exact_class?` and exact binary/method/source/block/cache facts;
never replace missing facts with runtime loading, SQL, compilation, view
construction, I18n lookup or replayed hooks. Old certificates stay refused.
Install the same observation seam with explicit sealed opt-in in both arms,
including LOWRAIL=0. One try-lock-protected witness attempt/process, active
publication last; concurrent entries run original, failure is terminal and
visible in explain/doctor/MCP, another setup does not reset the budget.

The isolated form/link/default full-chain cold witnesses have no ancestry or
other recorded off/off/on differences. Form has zero source/template delivery,
so neither older all-sealed seam is selected. Blog C's first show remains
original (0 hits); the natural repeat gets 1. Both 192-pair controls retain
all recorded outputs/events/assigns with **104 hits/0 fallbacks**, not the
historical 105: one render pays admission. Eight concurrent first renders
remain original and exact, ninth hits once. PingCRM's lazy-build refusal stays
visible; Wikino absent. The all-sealed Template/Preloader failures remain real
and red, scoped to a separate follow-up after the combined cohort.

This is **not a new speed claim or production promotion**. Report the review
gates before the next allocation; only one whole-request interpreter show
cohort with form+token+collection together can price their combined effect.
No flattened-filter stage, additive micro arithmetic, or new YJIT cohort.
[Admission, evidence and limits](sealed-verification.md#passive-form-v1-review-gates),
[certificate and historical prices](passes/sealed-form.md).

## Full ancestry is observable (2026-10-21)

Do not normalize Lowrail modules out of `Object.ancestors`, view ancestry or
any certified holder. The passive-form cold witness exposed an older on-only
`Guard::ObjectHooks` inherited through BasicObject. Facts-free form/link units
do not depend on it. Select invalidation hooks from the selected units' actual
method facts, not from the tier name; retain both hooks for every factful unit.
File delivery separately needs `ModuleHooks` for late Bootsnap rehook. Necessary
hooks must be installed identically with explicit `LOWRAIL=0`, without enabling
guards, source delivery or pass activation in that arm. Explain/doctor/MCP
describe both dependencies; `LOWRAIL_UNITS=""` still installs neither.

The expanded cold census compares complete Object/Kernel/BasicObject and
certificate-named holder chains before and after natural requests, including
the naturally cached view. **All-sealed currently fails exactness:**
`Templates::CompiledSource` is prepended to `ActionView::Template` on-only,
and `PreloadPlans::Hook` to `ActiveRecord::Associations::Preloader` on-only.
These are open correctness failures of those seams, not entropy or harmless
instrumentation, and historical narrower cold comparisons do not cover them.
Keep the mismatches and the rejected all-sealed evidence. Fix those passes
separately; do not weaken the full-chain gate or credit their hits as exact
coverage. [Census scope and limitations](sealed-verification.md#full-ancestry-census).

## Sealed admission must not materialize the app (2026-10-21)

The blog cold witness establishes an app-observable correctness violation:
runtime Materialize repeats hooks, autoloads API, requires objspace and probes
four databases. Remove it from runtime link admission. Check only already-loaded
dependencies/cached view class; the app may supply them naturally before a
later request, otherwise refuse. Do not prepare the off arm to hide the change.

**The accepted interpreter form saving (−14.457%, earlier −14.405%) remains
measured, unchanged and not rescored; that runtime was NOT ACTIVATABLE IN
PRODUCTION after the readiness correction.** Its old form certificate needs
controller/view/I18n/ERB effects to recertify and still refuses conservatively.
Only the separately versioned passive certificate above can now admit naturally.
Build-time certification and its tests remain; no guard weakening or effectful
recertification. The historical table/cohorts below describe their pinned
runtimes, not current activation. The sealed owner's YJIT cohort remains
separate on its pinned 88506d9 artifact; this fix uses no measurement slots.

Refusals are explicit in activation diagnostics, unit stats/outcomes and the
shared explain/doctor/MCP surface. Cold blog form show hits fall **1 → 0**;
link index/show hits fall **5/2 → 0/0**. Record that as coverage rejection,
not a support claim. Raw entropy still rejects off/off; the two declared
companions now agree exactly for their two GETs, with no cold SQL/load
exclusions. [Evidence, coverage losses and regressions](sealed-verification.md#current-runtime-passive-admission-or-explicit-refusal).

The bounded follow-up recovers **link index/show 5/2 hits, zero fallbacks**
with the optional Lowrail-owned public-C-API `exact_class?` primitive, loaded
symmetrically at gem require even off. No Ruby reflection/heap-walk substitute,
objspace fallback, runtime compile or readiness warming. Missing native build
still refuses visibly. Both-Ruby oracle/passivity witnesses and cold blog
companions retain all guards and exact SQL/hooks/loads; raw entropy stays red.
This does **not** recover form activation or change its measured result, add
measurements, or certify the unported suite scenarios
([prototype and scope](sealed-verification.md#optional-native-holder-prototype-link-coverage-recovered)).

## Collection/token isolated prices; filter stops (2026-10-21)

Three separate finite interpreter cohorts on
[`2c6899c`](https://github.com/thomasklemm/lowrail/commit/2c6899cd444583c96006430da03cb32776e23bb7)
pass the unchanged A/A/heap/brk/JIT-state controls. Collection fusion saves
**200,979.80 Ir [200,498.47, 201,333.63] per two-comment invocation**,
**−9.88386% [−9.90693, −9.87628]**. Token saves
**89,927.06 Ir [89,170.80, 90,472.40] per four-token operation**,
**−11.12246% [−11.21563, −11.00622]**. Accept those isolated prices only.

Filter saves **4,124.64 Ir [−2,807.96, +6,516.19]**,
**−0.046934% [−0.074127, +0.031951]**: no resolved saving. Stop it at price;
keep the flattened-filter specimen only as evidence, not in passive form or
any production plan. Six rounds each, no retry; all 312 windows GC-free.

**These are not additive and are not whole-request percentages.** No
production promotion follows; passive form still needs its approved
symmetry/concurrency/bounded-admission/cold/exactness gates. After review and
a new measurement allocation, price form + token + collection together in
one whole-request interpreter show cohort. Do not infer a sum. The
[method, admission, pins and intervals](passes/sealed-form.md#separate-collection-token-and-filter-prices-2026-10-21)
and [numeric export](passes/sealed-micros.json) retain all three results.

## RBS exports preserve slot evidence, not signature certification (2026-10-21)

Reuse the existing TypeModel and renderer for `types --rbs APP`, legacy split
files and read-only MCP `export_rbs`. Each return/argument slot is `proven`
(explicitly body-local), advisory `static`, sample-derived `observed` with
counts, or `unknown`/untyped. Preserve original sources and contradictions;
never call schema storage nullability or finite observations a runtime type
certificate. There is no whole-signature status. Unsupported receiver names
remain diagnostics rather than invented RBS constants. Blog and Wikino parse
and validate with RBS; this is tooling, not lowering support or speed evidence.
[Contract and bounded checks](types.md#rbs-output).

### Seed real Rails APIs, not replacement-runtime types (2026-10-21)

Reuse Roundhouse's bottom-up schema/API/caller design, but not its runtime RBS.
The bounded Rails 8.0/8.1 catalog checks boot owner and gem source, retains
`rails_api` provenance, and never produces proof. Unsaved column readers,
including IDs, are nullable; constructors, block-free finder unions, relation
chains and boot-generated enum predicates feed advisory inference. Preserve
untyped casting inputs and unsupported framework results. Export booted
inheritance and empty helpers so known APIs can actually be used by Steep.

Same-snapshot unknown slots: blog **176 → 158**, Wikino **3,707 → 3,545**;
most of the net reduction is correcting delegation parameter shape, not
recovering argument value types. Blog Steep **51 → 6**, still failing and
non-gating. Full RBS-collection import remains a follow-up. Runtime/lowering and measurement work are
untouched. [Classification, exact slot counts and limitations](types.md#rails-api-follow-up--2026-10-21).

### Recover declarations through Sorbet, never certify them (2026-10-21)

Use Prism to associate adjacent sig/def pairs with booted Sorbet wrappers,
retaining lexical type aliases, actual parameters and inherited method lookup.
Every recovered type is advisory `static`, source `sorbet sig`, regardless of
runtime checking. Unsupported expressions stay untyped, and `void` says nothing
about the returned Ruby value. The optional registry reader only inspects
already-built raw entries of the pinned 0.5.12435 layout; it never invokes
pending sigs, lazy type initialization or app code. No new proof or lowering.

Of Wikino's original 2,772 wrapped unknown slots, 517 returns become static;
2,079 forwarding placeholders are replaced by 136 typed real arguments, not
counted as recovered values. All recovered declarations contribute 1,208
static slots. Wikino coverage is now **0/1,715/1/1,129**, blog
**2/99/7/188** (proven/static/observed/unknown). Blog's unknown increase is
30 newly exported URL-helper arguments, not lost types. Booted routes and
source/versioned Turbo/Importmap support reduce blog Steep **6 → 2**. Correct
RBS callback self exposes two real nullable `article` calls; keep those visible.
[Inputs, denominator accounting and checks](types.md#sorbet-and-framework-signatures-follow-up--2026-10-21).

## Sealed verification: external production scenarios, first slice rejected (2026-10-21)

The two-example production probes are not whole-suite active coverage. Compare
suite-derived production replay, a separately certified production/test seam
and an external scenario driver. Recommend the driver with isolated state,
real request/job workers, original behavioral assertions, exact effects,
strict loads and per-unit hit/refusal accounting. A replay cannot prove all
inputs or close mid-request certification gaps. Keep production admission,
Bundlebun refusal and existing verify gates unchanged. **Option C accepted**;
the first two-GET blog Rack-boundary runner restores four databases and runs
sequential production/YJIT off/off/on workers, outside the test runtime.
Its raw off/off comparison rejects natural response entropy; no exclusions
or support claim. Retain the cold 14-off/3-on SQL and extra load-hook findings,
and the original unattributed form-inventory refusal. A fresh exact-334f49a
recheck has form19 show 1/0, index 0/0 and every refusal null; record that
before/after evidence without claiming an isolated cause. Explicit, pinned
two-seed entropy companions now retain the raw rejection while comparing
literal responses, SQL/binds, effects, captured events and loads. Their off/off
controls agree, but both off/on gates still reject cold SQL/load differences;
no exemption or support claim. Wider request/job replay and explaining those
cold findings remain follow-ups, not implemented admission gates.
[Trade-offs, results, hits/refusals and explicit uncovered IDs](sealed-verification.md).

The next blog-only C extension ports all **19 remaining ordinary IDs**, plus
server-only workflows for both system IDs and two bad-CSRF controls. Fresh
restored production workers retain every response/redirect/cookie/flash,
SQL/bind/event and four-DB/storage effect, including parent-read persisted
effects after worker exit. All **225 scenario oracle results** pass, but raw
and both seeded off/off/on groups remain **`rejected_off_control`**. Declared
workflow-thread clocks/UUID streams do not control Cable's separate writer:
real timestamps and asynchronous SQL/effect interleavings remain visible.
Do not disable broadcasts, exclude rows/SQL, widen clocks silently or infer
equivalence from passing assertions. Two system IDs remain explicitly partial
and uncovered (browser/Turbo/dialogs); jobs, asynchronous completion and real
HTTP remain gaps. The expanded cold ancestry census also retains the on-only
Template/Preloader seams as independent correctness failures, not entropy.
Fresh rebuilding after passive form admission preserves these rejections:
form coverage changes **0/0 → 12/1 hits/fallbacks**, link stays **104/4**
(legacy index/show **5/2 hits**). Keep the pending and input-refusal reasons.
Defer the real-app slice until these failures and the asynchronous boundary
have explicit solutions; no support/promotion or measurement claim
([bounded result](sealed-verification.md#blog-write-and-model-scenarios)).

The next C follow-up introduces a symmetric, **terminal two-second completion
boundary**, not output normalization. At workflow end, join the existing Solid
Cable writer and accepted trim tasks through its real shutdown, including
in-flight batches; never use a queue-empty sleep or the dropping server-restart
path. Keep every raw provisional/exit capture. A separate completed effect
snapshot is allowed only on success. Deadline, reported async errors,
unsupported listeners/adapters or unfinished Solid Queue jobs visibly refuse;
even identical refusals cannot pass. There is no queue supervisor in this
Rack slice, so enqueued Turbo jobs stay unfinished, not artificially executed
or discarded. The frozen 216-worker run joins all 63 started Cable writers;
162 snapshots complete and match worker-exit state, while 54 refuse unfinished
jobs. All 225 scenario assertions pass, but raw and both seeds still reject
off/off: real writer timestamps and SQL interleavings remain compared, with
three trim DELETEs retained. No silently broadened entropy control. The single
full-article form fallback is the **correct refusal** of
`articles/_form.html.erb:1`, single Article, `{class: "contents"}`, nil
scope/url/format on `GET /articles/3/edit`; the comment-form certificate does
not cover it. Keep runtime/inventory guards and the red gate unchanged
([boundary and witness](sealed-verification.md#terminal-asynchronous-completion-boundary)).

The deferred real-app GET slice stops at **build eligibility**, as scoped:
fresh frozen production/YJIT link/form-only inventories on Starter,
CodeTriage and PingCRM return zero units for the closed blog controller/model
domain; Redprints (Rails 8.1.3) and Wikino (8.0.5.1) return zero at the 8.1.4
version gate. Writebook fails production boot on its removed
`sqlite3_production_warning=` API, and CASA requires an unsupplied master key;
their inventories are not reached. Passive admission did not generalize
build-time certification. **Zero GET workers, no measured runtime hit/fallback
or on-only-difference result**, not an empty equivalence pass. Preserve each
row and stop rather than adding app/config shims, upgrading pins, borrowing
another pass's hits or widening inventory. Real-app C coverage remains a
product gap, with no support expansion or measurements
([per-app evidence](sealed-verification.md#real-app-get-eligibility-after-passive-form-activation)).

## One read-only explanation surface (2026-10-21)

`lowrail explain`, MCP `explain_unit`/`explain_site` and doctor's build section
share one typed report over the existing ledger/manifest and `facts::load`.
Show actual certificates, guard/contract descriptions, reason codes and
recorded counters; do not boot Ruby or evaluate guards to manufacture an
answer. Eligibility is not activation, advisory dump mode is not certification
mode, and an unrecorded site is not a refusal. New builds retain exact pass
selection; older selections remain unknown. Stale/unbound stats stay visible
without being attributed to current unit IDs. Compiler-dropped units stay
original despite eligible ledger rows. This is tooling, not a promotion,
weakened refusal or support/speed claim. [API and checks](types.md#explain-a-build-not-an-inferred-promise).

## Sticky tracing fixed; config promotion still blocked (2026-10-21)

Production activation/delivery no longer enables global return tracing
([published boundary](https://github.com/thomasklemm/lowrail/commit/ed7cbbe8f8ab6e9b7be24775ac76a94cebecd95e)).
Target only `initialize!`; observe lazy readiness without tracing; record
delivery in Loader itself. Native post-boot Starter counters show **zero
`exit_trace_leave`**. Global-return versus targeted-only micros isolate the
tax on both interpreter and YJIT; no pass body or certificate was weakened.

One finite post-fix config-only Starter JSON cohort per mode, no retries:
**interpreter −10.156% Ir [−10.219, −10.084], accepted**; YJIT **rejected**
both A/A controls and measured-window JIT flatness (10/24 workers). Its raw
−0.153% is diagnostic only. Untimed YJIT attribution finds **0 hits / 9,911
fallbacks**: a JIT-disabled build certified C `Array#each`, whereas `--yjit`
uses `<internal:array>:219`. Correct refusal of that fact is not a reason to
relax it. The native zero-trace proof covers activation/fallback, not a
verified fast path. Interpreter coverage separately has 11 hits / 0 fallbacks
per request. Keep **sealed-only, no promotion**: no accepted post-fix YJIT
cohort demonstrates non-regression. Old accepted/rejected results remain
separate. [Diagnosis, proposal and all evidence](passes/yjit-regression.md).

**Operational closure, not promotion:** `build --jit MODE` records the actual
certification mode across builders/compiler. Setup refuses unknown/mismatched
modes before installers; initialize! completion reports later drift rather
than forcing the app or uninstalling. Doctor, stats, verify and bench expose
the distinction. Deploy YJIT at startup (`RUBY_YJIT_ENABLE=1` or `--yjit`) and
rebuild `--jit yjit`. Both early mismatch directions and real Rails late
enablement have regression coverage; no new measured cohort was started.

## Guarded props ordinary-def: stop at price (2026-10-21)

**Stop this exact-guard shape; no promotion. Cancel its YJIT micro, not merely
hold it.** One corrected-code interpreter cohort on clean
[fb07512](https://github.com/thomasklemm/lowrail/commit/fb07512d06ca217ec1fdb1e49e0cd24ab4fa8345)
passes both A/A, five heaps, brk, mode and pre-window liveness gates. Ruby
4.0.7, Inertia 3.22.0, pinned Valgrind 3.19/brk512; six rounds, seed 41231,
N=1,000, at most four workers, no retry. Split ordinary-def versus original
loses **+22.594% total Ir [22.496, 22.731]** and **+22.614% GC-excluded
[22.469, 22.739]**; inline guarded loses +22.558% total [22.447, 22.659].
Complete checks cost 30,482.987 Ir/resolve against 4,445.573 available unchecked
iteration saving: **6.857× [6.758, 6.912]**. Moving the fallback to another
method does not close the guard deficit. This is a micro price, not a new
request result or production reflection/delivery certificate.

The earlier format-1 cohort remains **invalid fallback/incomplete-check
pricing**, not a second accepted fast-path loss and not rescored. No guard is
weakened and the existing opt-in pass is unchanged. At this decision a VM-owned
non-callback dispatch certificate was a backlog question only; the separately
requested native preparation below does not revise this price. Config-bind
YJIT stays on hold until its measurement
method is accepted. [Pins, paired estimates, controls and backlog boundary](passes/yjit-regression.md#corrected-interpreter-pricing-stop-at-price).

## Props native dispatch: stop at price too (2026-10-21)

Add `Lowrail::Native.plain_hash_iteration?` beside the optional actual-class
primitive, **without production props integration**. It checks the actual
ordinary Hash class, both iterator BASIC definitions and public visibility
on every call, without Ruby callbacks or eigenclass materialization. Keep
the outer main-Ractor, source/unit/fact admission and every recursive-entry
check in the pricing specimen. The extension remains Ractor-unsafe, loads
in both arms, and needs fresh native binaries/artifacts after this addition.

Both Ruby targets witness overrides, visibility, suppressed hooks, aliases,
undef, refinements and mid-traversal mutation; extra conservative refusals
are documented. The untimed whole-resolver census replaces twelve reflective
bind_call entries, four method comparisons and two class comparisons with
two native predicate calls; outer admission remains. This is **not** a
measured fraction of the old 30,483 Ir check cost. The undocumented MRI
visibility API is feature-detected and version-witnessed, not a generic VM
portability claim.

One finite interpreter cohort on
[83bf0ba](https://github.com/thomasklemm/lowrail/commit/83bf0baa9c21d86955e31f626bbc466b60c41f9d)
passes both A/A, all five heaps, brk, mode, source and positive liveness gates
(20 authorizations/zero fallbacks in each checked arm). Ruby 4.0.7/Inertia
3.22.0/pinned Valgrind 3.19 brk512; six rounds, seed 41231, N=1,000, at most
two workers, no retries. Native split **still loses +1.383906% total Ir
[1.360285, 1.409477]**, **+1.383817% GC-excluded [1.360197, 1.409653]**,
despite 55→46 objects/resolve. Same-cohort checks fall from 30,982.589 to
5,849.248 Ir [5,821.248, 5,897.248], **81.188% removed [80.810, 81.296]**,
but available iteration saving is only 4,445.369 [4,393.471, 4,471.573]:
**1.321176× [1.301877, 1.336813]** remaining check/saving ratio.

**Stop the native shape at price as well. No retry, YJIT run, production
integration or promotion.** Both worker slots are released. The old
ordinary-def stop and invalid fallback cohort remain unchanged; no cross-
cohort rescore or request saving. Attribute the remaining checks from the
retained dumps/untimed census before proposing another candidate or asking
for slots. [Boundary, both CIs, pins and sanitized export](passes/props-native.md).

The untimed retained-dump attribution finds **1,132 Ir/resolve in the native
predicate itself** (454 BASIC, 602 visibility, 76 scaffolding), identically
across 24 positive windows, not approximately 50 Ir. Another **630 Ir** is
inside disabled-Stats constant checks, before their interpreter opcodes.
The warm path performs no full unit validation, only two activation and
cached-state reads. Do not hoist mutable admission across callbacks.
Freezing alone cannot close the paired 1,428-Ir gap, even with a free
predicate. The next **unpriced** candidate combines the separately witnessed
frozen-holder contract with counting/non-counting guard definitions selected
at installation and late Stats activation. Keep Ractor/admission and actual
receiver checks at every recursive entry; prove late counts and frozen
lifetime behavior before requesting a cohort. No runtime integration or
speed claim follows from the 1,686-Ir combined target budget.
[Machine-function accounting, census and candidate](passes/props-native.md#untimed-attribution-of-the-remaining-checks).

Before pricing, the **combined specimen was prepared**: frozen holders plus
ordinary counting/non-counting definitions selected on installation/late
Stats enable, retaining every recursive-entry Ractor/admission/receiver
check. Both Rubies pass 478 lifetime comparisons in each counting mode
(**1,912 total**), plus exact late/in-flight counters and positive 20/0
liveness. Alias-only selection loses an in-flight authorization; the
specimen preserves pending decisions with a targeted retired-ISeq observer
only after Stats activation, and charges its completion marker to any future
price. Disabled workers have no observer or Stats query. No Callgrind slots,
YJIT run or production edits; request two slots for one finite interpreter
cohort only after publication. [Contract, witnesses and pins](passes/props-native.md#combined-frozen-holder-and-selected-counting-specimen).

The first authorized combined-price **launch was invalid and produced zero
measured windows**, not a props price. The private launcher expected
`--worker`, while `RequestPairs` passed its route argument `unused`. A worker
re-entered the controller and launched two nested children: three concurrent
Callgrind processes transiently exceeded the two-process cap. All four dumps
contain `totals: 0`; no round completed. Admission/preflight passed, but that
does not repair dispatch or cap failure. Preserve the launcher, four dumps,
logs and nested outputs; no retry, salvage or break-even claim follows.

The owner separately authorizes **one first measurement**, conditional on a
published tracked launcher, exact-route native E2E check and hard process
guards. Worker roles must be explicit and cannot invoke the controller or
create children; supervision refuses a third launch **before** spawning it.
Keep the fc40772 specimen equivalent and every pricing gate unchanged.
If paired savings do not cover the 1,428-Ir gap and all marker/replacement
costs with uncertainty accounted for, props stops permanently at that price.
[Dispatch correction, native check and reproduction](passes/props-native.md#tracked-pricing-launcher-and-zero-window-invalid-attempt).

### Frozen props: accepted micro, integration deferred

The one separately authorized finite interpreter cohort on
[d97df0a](https://github.com/thomasklemm/lowrail/commit/d97df0ab7fcc840c98de2885ce23e54ab5a5952b)
passes all unchanged A/A, five-pool heap, brk, mode, source and positive
liveness gates. Ruby 4.0.7 `229531a6cf`, Inertia 3.22.0, pinned Valgrind 3.19
brk512; six rounds, seed 41231, N=1,000, **42 boots / 168 windows**.
The hard cap held: **peak 2, final active 0, refused 0**, all direct children,
no nesting; both slots released. The earlier zero-window launch stays invalid.

`frozen_split` saves **−0.460571% total Ir [−0.508479, −0.408556]** and
**−0.460571% GC-excluded [−0.508479, −0.408556]**, **55 → 46 objects/resolve**.
Actual paired net saving is **478.145 Ir [424.145, 528.145]**, including
marker/replacement costs: the conditional permanent-stop rule clears.
Within these new paired rounds, native checks cost **6,589.766 Ir**, combined
checks **3,959.224 Ir**, and unchecked iteration saves **4,445.369 Ir**;
checks removed are **2,630.542 Ir [2,628.542, 2,656.542]**.
All full contrasts and both CIs are retained, not reconstructed from
differences of medians. The reference setup preloads Stats and freezes every
arm; **no cross-cohort rescoring** of the old 1,428-Ir gap or native price.

**`native_split` is rejected and dropped**, losing **+2.098314% total Ir
[2.070323, 2.123393]**, **+2.098331% GC-excluded [2.070323, 2.123376]**.
The accepted cohort does not make every arm a win.

**Status: accepted micro, integration deferred until the sealed freeze tier
is implemented.** Frozen holders require the opt-in freeze contract, which
is still only an [accepted design](freeze-integration.md); Fizzy still has
recurring falsy-memo writes. The saving is real but small. Test-certificate
and passive token/collection correctness take priority. **No integration,
pass promotion, YJIT or whole-request cohort.** If the tier is built later,
a new workstream picks up props on top of it.
[Full contrasts and pins](passes/props-native.md#accepted-combined-interpreter-micro-integration-deferred),
[sanitized export](passes/props-frozen-interpreter.json).

## Relocatable delivery (2026-10-20)

Use typed app-root-relative metadata and explicit AOT `build --target-root`
for file ISeqs. Do not transparently recompile lowered source at boot: public
compiler hooks can add effects and change the result on both supported VMs.
Original/lowered source digests, binary digest and live-loader recipe/ISeq
checks remain mandatory. Path-bound or old artifacts refuse with a recorded
reason rather than silently delivering zero hits. Preserve the independent
sealed-tier admission and quarantine. [Loader contract](loaders.md#deploy-paths),
[reported costs and copied-app checks](ruby-4.1.md#relocation-follow-up).

Same-root native delivery checks the observed binary without normalization.
Target-root delivery uses a separate portable certificate, derived only after
the complete source replay matches the observed ISeq with its native root
label and entry line restored. Only known root labels normalize; entry line 0,
nested frames, operands and strings remain exact. Existing translators decline
native, cache and eval substitution rather than assuming that their unchanged
original proves how they would treat newly introduced instructions.

## 512 MiB decision recheck (2026-10-20)

The authorized finite remeasurement on the pinned brk512 tool is in
[bench.md](bench.md#decision-critical-512-mib-remeasurement-2026-10-20), with
old/new CIs, every control and the numeric export. **No optimization decision
flips; nothing is reopened or promoted.** Historical rejections stay rejected.
These findings cover the measured snapshot, not the subsequent runtime work
integrated by the publication rebase; see the explicit provenance boundary.

1. **Caller-side sections: stop holds.** The optimistic combined checks still
   exceed the whole two-link budget by +3,607 Ir. No runtime pilot or widening.
2. **Body-installed endpoint: stop holds.** Internal checks alone still lose
   +4,419 Ir after subtracting unchanged-delivery overhead. A sealed contract
   or VM epoch remains necessary, not a sufficient complete certificate.
3. **Inertia props: opt-in/no promotion holds.** The final runtime regresses
   interpreter Ir by +4.364% with accepted controls. Its one YJIT cohort is
   rejected for non-flat measured windows in 5/36 workers; diagnostic +31.043%
   is not an accepted regression magnitude. Both modes count 4 hits/request,
   zero fallbacks. No rerun or clean-arm salvage.
4. **Quarantine holds; one observation changes.** Current default remains
   near off in magnitude: show −0.004% is unresolved, but index −0.062%
   [−0.084, −0.052] is a small **resolved** saving, not literally “within noise.”
   The fresh default has zero units; this is not restored source-pass credit.
   The unsafe former-default saving was not remeasured. Keep quarantine and
   the sealed-first decision; any sealed benefit still needs its own gate.
5. **L2_events stays an upper bound.** Show −37.297% reproduces the large
   interpreter ceiling with accepted controls. Unchanged assigns/observer/
   mutation omissions still prevent semantic certification or promotion.
6. **Shipped K holds.** The original runtime snapshots reproduce net
   822.005 → 425.004 interpreter Ir/check and 371 → 140 YJIT. Both modes'
   arm cohorts pass every control. Still no accepted request/native speed win.

## Finite sealed-renderer experiment (2026-10-20)

**2× target missed; no third mini-runtime/bridge tier is promoted.** Five
cumulative specimens each pass 192 isolated body/all-header/ordered-SQL/
event/assign/state pairs, including empty comments. The final stage also
passes a side-effecting render subscriber. Pinned-tool interpreter controls
pass: Rails **8.744456 → 6.120350 M Ir** (−30.016%, about 1.43×),
**2244.30 → 1465.73 objects/request**. Historical 5.473809 M L2_events remains
non-equivalent; the conservative restoration is not a minimal observer tax.

Form expansion saves 1.296 M, then filters/token-tag/collection composition
save 0.045/0.081/0.217 M. AR/security/fanout boundary diagnostics price
1.286/1.120/0.270 M, but overlap and perturb work +3.37%: no additive or
irreducible-floor claim. Remaining Rails integration/live helpers on top of
real AR/security block this specimen, not event fanout alone. Another roughly
**1.75 M Ir** is needed to halve Rails' work. This finite result is not a
proof that every more aggressive sealed renderer must fail. Keep real
AR/security/events, existing tiers, default and quarantine unchanged; no
runtime implementation follows. The single YJIT cohort is rejected: 5/48
workers compile in measured windows and GC-excluded A/A misses zero; no
retry or clean-arm salvage. [Experiment, ablations and controls](passes/sealed-renderer.md).

## Architecture

| Item | State | Why / evidence |
|---|---|---|
| Pass registry, single runtime-build boot, shared ledger (migration 1–3) | done | Behavior-equivalent; [build-pass-equivalence.json](build-pass-equivalence.json) |
| Runtime `Lowrail::Passes` registry (migration 4) | done (491ea27) | 811 outcomes, ordered SQL, per-unit maps and Rails L3 identical; request −0.02 % (noise); cold require+setup +0.76 % once per boot (registry parsing, not eager loading). Seed-dependent real-blog link_to fallback explained: lazy route-helper materialization during a Turbo model broadcast before the first request; guard correctly conservative, identical on old and new runtime (a161a8e) |
| `lowrail bench APP --pass/--passes` (migration 5) | done (6f9e27a, 8db84d8) | One shared method: fixed-heap Callgrind, A/A, actual JIT state, stale-build rejection ([bench.md](bench.md)) |
| Ruby 3.4 | dropped, owner decision 2026-10-20 | Targets are Ruby 4.0 (primary 4.0.7) and 4.1. Gemspec minimum is 4.0. Ruby 3.4.5's full gem matrix is not green (Digest certification, Ractor test API, AR query-hook identity and ISeq delivery); historical targeted 3.4 results are not a support claim. Keep the independent preload compiler fix. Corpus candidates must first pass a plain-Ruby-4.0.7 boot/suite; dependency-only Ruby overlays are allowed, app/gem code workarounds are not. |
| Ruby 4.1 / ZJIT measurement column | 4.1 is a correctness target; 4.0.7 stays measurement primary | Preview pinned to Ruby `2d08b5f` builds both JITs. Full gem/Cargo suites green on both targets; ISeq provenance and Ractor tracing retain exact refusals. Disposable source-dependency overlays: blog 21, Campfire 634 (2 skips), PingCRM 26, Redprints 50 + 12, Starter 36 identical outcomes and own-thread SQL; blog YJIT also 21 identical. Redprints additionally needs authorized per-gem FFI/SQLite source selection and Bundler 4.0.20. Original pins unchanged; no unchanged-bundle claim. Finite same-VM cohorts finished: guard 1,760→375 interpreter / 1,045→66 YJIT Ir accepted; ZJIT 1,026→56 diagnostic. Props −3.358/−11.141/−2.185% all rejected (A/A / heap / missing invalidation proof). Entire blog comparison rejected: copied historical artifact activates zero units; L2 observations are only unchanged handwritten ceilings. No pass promotion, retry or priority change. Singleton rewrite canceled with the guarded endpoint slice; guide only. Explicit mise-per-run and test-corpus-root axes preserve defaults. No public broad mutation epoch found; Box remains experimental, not a guard replacement ([matrix, hits and exact failures](ruby-4.1.md)) |
| YJIT + ZJIT emitted shapes | warning-only audit and opt-in diagnostics | Preserve guards/fallbacks and all existing gates. Emitted file/endpoint ISeq warnings go to the ledger; runtime/template inspection gaps are explicit. Verify retains process snapshots, bench collects them only in untimed coverage; unavailable per-ISeq counters remain null. Pass rule: no interpreter regression + guard-included YJIT micro gain; ZJIT later, whole-request JIT diagnostic while flat rejects. Endpoint instance singleton-class creation is a concrete cost, not permission to weaken its certificate ([guide and alternatives](jit-shapes.md)) |
| ZJIT instruction seam | diagnostic only; fail closed on preview | `BENCH_JIT=zjit` attests actual YJIT/ZJIT states and retains compile/exit-stub/invalidation-time observations. No public invalidation count means strict flat gate rejects, never substitutes time for a generation. Separate five-available-counter partial gate passes all 114 ZJIT workers in this study; it proves neither no invalidations nor executed exits/ratio/per-ISeq stability. YJIT's three counters and all A/A/heap/brk controls unchanged. Fixed heaps cover all 12 preview pools; 4.0's five defaults unchanged. Exact endpoint-loop prewarm closes observer self-compilation ([protocol](bench.md), [preview study](ruby-4.1.md)) |
| YJIT instruction measurement | gate shipped; endpoint ceiling still unproven | Three flat compiled-ISeq/block/invalidation warm windows plus unchanged counters in every measured window; exact GC-observer warmup and request-only post-GC settling, unchanged A/A/heap gates. Both corrected blog comparisons reject residual block compilation (4/36 index, 5/36 show workers; show also fails excluded A/A). Matched interpreter comparisons pass. Diagnostic eventful −23/−35% is not a confirmed YJIT ceiling shrink; no retry-to-green, clean-arm salvage or priority change. Accepted guard micro: 371 → 140 YJIT Ir/check (−62.26%, versus −48.30% interpreter). Keep allocations + gated leaf-operation Ir; PMU cycles unavailable. No native speed or quarantined-source support claim ([method and results](bench.md#quiescent-yjit-instruction-mode)) |
| YJIT request warmup v2 | **one finite off/off show validation accepted**, no pass promotion | Prepared heap/observers, idle beyond unchanged timeout, aged-branch exercise, ≥2,000 quiet requests plus zero-work endpoints, cap 20,000. Pinned `2b57bc8`: 12 workers / 48 windows flat, A/A total +0.0147% [−0.1192,+0.0717], excluded +0.0460% [−0.1064,+0.1082]; heap/brk and all pre-window timing gates pass. 24 long windows use supplementary separate zero/symmetric companion counts, **not exact measured counts**. All existing gates unchanged; old rejected cohorts remain rejected. Native AR lazy-target attribution proves one mechanism, not every historical site. Future pass cohorts still need their own gates; no app/YJIT policy or default change ([protocol/result](bench.md#v2-declaration-prepared-heap-idle-boundary-2000-quiet-requests), [export](bench-yjit-v2.json)) |
| YJIT request warmup v3 | **one finite six-arm validation rejected; cause open** | Pinned `86672e5` / YJIT artifact `b68764be…`: all 36 workers certify in 2,000–16,000 requests, no caps; exact 611/306/246/99/100 pages and unchanged one-page gate pass. A/A total +0.064310% [−0.050859,+0.205778], excluded −0.044404% [−0.123620,+0.146327]; brk and all native idle/symmetry controls pass. Three of 144 windows compile blocks: round 0 disabled total/N50 +15, round 1 off-B total/N50 +9, round 3 empty total/N50 +45; zero new ISeqs/invalidations/GC segments. All no_gc and N0 windows flat, off-A/missing/default completely flat; total-only is an observation, not attribution. Native, padded-native and Nulgrind diagnostics do not identify those sites. Reaper compilation is observed elsewhere, not proved for these windows; switches are not tick counts under Valgrind. No retry, re-scoring, accepted YJIT pass price or v4 cure ([result/protocol](bench.md#v3-result-one-finite-six-arm-cohort-rejected), [full export](bench-yjit-v3.json)) |
| YJIT v3 + compile log | **declared diagnostic addition; existing gates retained** | `BENCH_YJIT_LOG=1` retains full per-worker `--yjit-log=FILE` streams and hashes, outside-region realtime envelopes and byte offsets, without rotation or 1,024-entry ring truncation. Because failed attempts can log without installing blocks, byte growth/missing byte counters additionally reject logged windows. Native log-off/on both certify at 2,000 with identical prepared pages; small pre-fill allocation differences retained, not subtracted. No app/JIT-policy/default change or separate validation cohort. Next authorized measurement is the sealed owner's form-only show with a fresh `--sealed --env production --jit yjit` artifact built on its exact published measurement head, including every existing in-cohort A/A/heap/brk/JIT/idle gate; passing counts, failure keeps named sites. The earlier `411eb71` artifact is stale after the link fix changes its `sealed.rb` source pin: no stale-gate bypass or historical runtime override. Fresh native admission and preflight are required. Driver explicitly refuses parent `RAILS_ENV` mismatch before activation/setup, with no silent default ([head-agnostic flags and limitations](bench.md#v3--compile-log-diagnostic-addition-not-a-cure)) |
| Campfire hotspot sampler | **unsupported signal/Fiber-switch tool boundary; original cohorts still rejected** | One exact-sampler and one qualified stock Callgrind 3.19.0 untimed Fiber control both assert at `threads.c:247` after rt_sigreturn at `fiber_setcontext`; not patch-specific, no brk-only bench implication. Native/tool=none censuses put synthetic empty captures on child ECs, but do not identify the 12 historical JSON empties. Real native JSON/room/sidebar requests execute `ActiveRecord::Key::Single` Enumerable zip / Enumerator next via association scope construction; room also uses foreign-association assignment during Action Text body construction. No Puma/ActionCable/timer cause assigned, no dropped samples, no speculative fix or new cohort. Upstream draft retained locally only ([evidence/boundary](passes/hotspots.md#campfire-sampler-boundary-untimed-diagnosis)) |
| SQL-trace differential in verify | done | Fixed seed, symmetric repeat controls |
| Declared RNG companion verification | explicit pinned two-seed policy, owner decision 2026-10-21 | `verify --companion-seeds 0,1 --load-controls FILE` leaves the ordinary unseeded gate/raw differences intact and adds two whole-suite off/on pairs. The control file declares Kernel plus the app RNGs with evidence and exact revision/effective-lock pins; reporters seed before each example and attest all test ids. Every companion outcome and own-thread SQL digest/count must agree, without SQL noise/list/multi-worker exemptions; any difference fails. Only complete success plus identical unseeded outcomes permits visibly classifying unseeded SQL as RNG-dependent, companion-verified. Loads are not covered. No implicit seeding or endless per-test list growth. [Contract](FORMATS.md#declared-rng-companions), [breadth results](compat.md#gem-breadth-round-2--2026-10-21). |
| Anonymous census constant identity | narrow observer correction | Elide only address tokens inside inspect-style module names, preserving constant suffixes and every literal load/hook/event position. RubyToolbox's 368 pair / 736 four-run constant identities were process addresses, not load changes; the fixed-seed rerun did not remove them. The regression fails with the previous observer; real A/B event reordering still rejects. Its separate 18 DatabaseCleaner truncation-order SQL identities have closed pinned variants, each observed twice off-only; no SQL normalization. [Contract](FORMATS.md#inspect-style-constant-names), [evidence](../fixtures/corpus/rubytoolbox-sql-evidence.json). |
| Rare app SQL branches | pinned closed variants, owner decision 2026-10-21 | Extends explicit `--load-controls` beyond the original load-only policy: exact test + explanatory SQL identity + closed full ordered own-thread SHA256/count variants, each proved in a Lowrail-off arm with mechanism/evidence. Both arms must match; an unknown digest/count or added query still fails even if ordinary repeat controls classify that example noisy. Effective Bundler lock SHA256, app HEAD and clean tracked source checked before/after. All entries/variants/raw traces remain visible; no global normalization/repeat relaxation or test RNG hook. CRM's unseeded Kernel `Array#sample` selects the observer's won/revenue-update branch. Diagnostic-only identical RNG seeds remove all three original differences in two off/two on full subsets; other rejected identities remain rejected. [Evidence](compat.md#fat-free-crm-pinned-sql-randomness--2026-10-21), [format](FORMATS.md#pinned-load-controls). |
| Load behavior is part of exactness | invariant 7, owner decision 2026-10-20 | Activation must not trigger app/framework autoloads or run Active Support hooks early. CASA locale formatting and Fizzy's Active Storage callback exposed real bugs; shared initialization/loaded-constant gates and lazy model/epoch installation fix them, with regressions. `LOWRAIL_VERIFY_LOADS=1` compares constants, Zeitwerk paths and executed load hooks/order at first test/after suite, with off/off and on/on controls and pass/setup isolation. Enabled for the corpus; measured blog median overhead +0.12 s (+6.6%), so opt-in. |
| Rare app load races | pinned off/off controls, owner decision 2026-10-21 | `verify --load-controls FILE` accepts only exact indexed load-event identities, each with local evidence and observed thread/stack origin, pinned to the app's source revision and Gemfile.lock SHA256. Changed pins or tracked app source make entries inert; no wildcard, path/event normalization, SQL/constant exemption or global repeat relaxation. All raw events and controls remain in JSON; a separate known-app-nondeterminism text section reports differing/observed/pinned counts and evidence. Fizzy's 18 event-349 identities recur in one of 20 sequential verifier-off runs (A 1/10, B 0/10); plain traces without any Lowrail files confirm Turbo's ScheduledTask worker racing main-thread Event notification enqueue. This corrects the earlier selection/head attribution, not runtime behavior or baseline app errors. [Evidence and reproduction](compat.md#fizzy-pinned-app-load-nondeterminism--2026-10-21), [format](FORMATS.md#pinned-load-controls). |
| require-hooks/Bootsnap adapter selection under Lowrail | resolved by hook-free delivery | Neither build capture nor runtime defines `load_iseq`. Native MRI `translate` (top-level files only), Bootsnap post-serialization `storage_to_output`, and existing ISeq eval delivery preserve owners/source locations/method chains and adapter choice. Native delivery checks the actual binary observed at build, with no runtime recompile, extra compiler callbacks, warning re-emission or fingerprint normalization. Existing translators/custom warning callbacks retain native compilation; unobserved inner compiler wrappers cannot inherit outer defaults. Original-only caches and complete source/recipe/binary guards remain. Both Ruby 4.0.7 and 4.1-preview pass the 19-order presence/absence/state/census matrix and the Freezolite matrix, with delivery hits. Late installation alone cannot certify future detectors; no registry upstream change, mode forcing or introspection spoof. [Details](loaders.md#resolved-require-hooks-adapter-selection). |
| Bundlebun integration enumeration | targeted delivery/activation refusal; eligible 14-props-hit gate still unmet | The historical 277-hit/seven-unit target is obsolete after the sealed-only quarantine. Current eligible ceiling: 14 `inertia/props` hits. Bundlebun 0.5.0 installs no ISeq hook: its synchronous unsorted constant/autoload walk depends on identifier allocation. A compile-only symbol control causes **8 actual stable load differences**, independently confirmed in `$LOADED_FEATURES` and four processes without Lowrail/census/TracePoint. An early-delivery census cohort passes with 14 hits but direct controls change order: **non-certifying**. Waiting for natural integration completion misses the already loaded props file and yields zero hits. Keep the early `bundlebun_load_order` refusal in setup/manifest/ledger/stats; no identifier padding, forced autoloads or upstream monkeypatch. Strict refusal still gives 50 identical outcomes / 692 queries / 0 stable differences / **0 hits**, not active support. This bounded failure of the present seam is not a universal impossibility proof; alternate/dynamic dependencies are not generally certified. [Boundary and controls](loaders.md#bounded-follow-up-delivery-timing-cannot-certify-this-bundle), [local-only upstream draft](upstream/bundlebun-integration-order.md), [corpus results](compat.md). |
| Rails 8.1.4 framework suites as gate | done | [rails-suite.md](rails-suite.md); zero reproducible differences |
| Replacement-layer ceiling, Rails 8.1.4 blog index/show | layer D chosen; old ceiling is an upper bound | Eventful −26/−37% handwritten specimen omitted observable controller assigns and mid-request helper mutation; accepted A/A was not semantic certification. Keep Rack envelope and the real event/state pipeline. Conservative generated slice proceeds separately, no default promotion; [ceiling correction](passes/layer-ceiling.md), [pilot boundary](passes/endpoint.md) |
| Roundhouse Ruby replacement calibration | measurement only; no third-tier promotion | Same generated Rails 8.1.4 blog/data, pinned-tool interpreter work is 5.887×/6.188× lower on index/show, but literal HTML, SQL/events and session confidentiality differ. Both YJIT cohorts reject A/A, heap and JIT-flat gates; inclusive profiles are perturbed, not additive removal budgets. Rendering/composition is the largest plausible transferable band. A real-object sealed renderer is a 2× research hypothesis, not a measured bridge; 3× is unproven. Keep real AR/security/events and the two-tier design; [audit, subsystem matrix and bridge budget](passes/roundhouse-calibration.md) |
| Monomorphic receiver guard slot K | shipped dispatch optimization (690f64d) | Same invalidation boundary as V, sentinel slots and Stats withdrawal. Five-app outcomes/full unit maps and Rails L3 identical. Fixed-heap net check cost 822 → 425 Ir interpreter, 371 → 140 YJIT; blog request A/A rejected, so no accepted request win ([measurements](passes/speculation.md)) |
| Unsafe fact bypass | measurement only; strict bench seam published | Rails 8.1.4 L3 has 34 instantiate planning errors; **all 34 caught by the existing AR epoch**. Five-app outcomes and own-thread SQL agree; 9 PingCRM other-thread SQL differences remain advisory, byte differential pending. Guard elision on the pre-residual K runtime removes 0.081% default / 0.194% all-opt-in blog instructions, 0.189% all-opt-in PingCRM, 0.036% Starter (CI crosses zero), 0.278% pinned-8.1.3 Redprints. Runtime structural checks remain; not a full unchecked-runtime ceiling or native speed/support claim. Failed A/A/probes retained ([request ceilings](passes/speculation.md#guard-tax-request-ceilings), [break list](passes/speculation.md#unsafe-break-list)) |
| Exact residual guards | planned at entry level; current-runtime holes remain open | Suppressed callbacks, own visibility, constant replacement/removal and direct config mutation are not closed by today's cache. K + four small residuals costs 4,470 interpreter Ir (~0.05% of 9 M Ir once, not per site); entry snapshots must also cover mid-request mutation. An ISeq containing `invokesuper` is not proof that the callback invokes it ([counterexamples](passes/speculation.md#invalidation-coverage-and-minimal-counterexamples)) |
| RubyVM constant-cache stat as mutation epoch | rejected | Ruby 4.0.7 replacement/removal and Zeitwerk reload can leave it unchanged. Read costs 7,081 interpreter / 6,970 YJIT Ir, versus 311 interpreter Ir for one constant identity check. Keep identity/presence checks or refuse ([matrix and costs](passes/speculation.md#constant-cache-counter-measured-and-rejected)) |
| VM-owned structural mutation epoch | local experiment only; not a complete section certificate | No supported broad API found in pinned 4.1-preview1/master. Patched 4.0.7 read costs 195 interpreter / 36 YJIT Ir; compare+branch 267 / 52, accepted fixed-heap cohorts. Detects tested suppressed hooks, own visibility, uncached constant/autoload/Zeitwerk mutations and all ten endpoint method facts; warning reentry required an extra pre-callback bump. Receiver replacement, mutable table contents/defaults (including PRE_CONTENT_STRINGS), config/input state and post-call continuations remain; the ordinary getter is overridable. Two checkpoints estimate 534 interpreter Ir versus 94,466 historical guard Ir, **not** a net endpoint saving or sufficient checkpoint count. Keep sealed/default/quarantine decisions unchanged; no runtime integration or upstream post ([patch, matrix and costs](passes/vm-epoch.md)) |
| Upstream VM-epoch proposal (ruby-core / JIT team) | held until the sealed pilot measures a request result | 534 Ir for two checkpoints vs 94,466 Ir of guards is an estimate, not an endpoint saving, and the epoch leaves holder/value/config/table gaps. A proposal needs a measured request win that the epoch would make safe without the sealed contract. Local draft only; no external post |
| First sealed slice: reactivate the quarantined `view/link_to` and `route/path` arms under the contract | decided, before the show endpoint pilot | They delivered −5.995 % index / −0.987 % show Ir and lost them only to post-seal mutations (suppressed-hook redefinition, singleton `route.format` via `to_param`), which the contract forbids (SEAL001) and seal-check detects. Smallest end-to-end proof of the tier: existing generator, known numbers, known counterexamples as negative fixtures. Remaining non-epoch facts (builder receiver, config, mutable tables) stay checked or refused. Guarded-tier quarantine unchanged |
| Two tiers: guarded (default) and sealed (opt-in) | decided; sealed tier in design | Caller-side certification costs more than it saves (0fbb909), and entry checks cannot cover mid-request mutation (45fd07a). The sealed tier trades an explicit app contract (no code/subscriber/config/route mutation after boot, among others) for ahead-of-time endpoints without per-call checks. Ruby cannot fully enforce the contract (suppressed hooks, captured `bind_call`), so `lowrail seal-check` verifies it with the app's own suite and reports `file:line` and a fix. Test stubs deopt the process and are not counted as failures. Guarded tier unchanged |
| Body-installed endpoint specialization | stopped; sealed contract / VM epoch needed | Delivering the body's own ISeq removes the outer dispatch certificate, not the nested facts. Internal-method checks alone exceed the entire two-link budget: historical +4,720 Ir, pinned-brk512 recheck +4,419 [+4,337, +4,633]. Stop holds; no runtime implementation ([recheck](bench.md#decision-critical-512-mib-remeasurement-2026-10-20)) |
| Ship `passes.rb` as precompiled ISeq | parked | Would remove most of the cold registry cost; only after migration 4 lands |

## Passes

| Pass | State | Why / evidence |
|---|---|---|
| Source `view/link_to` and `route/path` | quarantined, including opt-in and old artifacts | Warmed suppressed hooks render stale helpers; name evaluation can change the actual tag builder, and `to_param` can change the actual route formatter after entry authorization. A class/visibility check at entry cannot repair this. Old mixed artifacts refuse as a whole, with a recorded boot reason. Rewrite actual receiver/body certificates and once-only local continuations before measuring/reactivating ([repros and boundary](passes/endpoint.md#source-arm-quarantine)) |
| `endpoint/action` | conservative slice opt-in; widening held | Warm → suppressed `UrlHelper.method_added` → replace `link_to` passes off/on response comparison, including statistics-off controls: actual helper/body checks catch it. No new quarantine. Generated compiled-template/collection-partial bodies, controller process seam and live Rails events/state/AR remain. Historical index +18.565% versus the former default, rejected composition/named-helper residual and widening hold remain ([audit](passes/suppressed-hooks.md), [contract](passes/endpoint.md)) |
| `memo/sha256` | **sealed-only**, guarded/opt-in refused | Suppress `Digest::SHA256.singleton_method_added` after two warm hits, replace `base64digest`: original changes, cached value stays stale, third hit and no fallback. Source hashes and cached method facts do not detect this. SEAL001 required; old/mixed artifacts refuse whole ([audit](passes/suppressed-hooks.md)) |
| `memo/uri_join` | **sealed-only**, guarded/opt-in refused | Suppress `URI.singleton_method_added` after two warm hits, replace `join`: original changes host/path, fast value stays stale, third hit and no fallback. SEAL001 required, not an exact guarded memo; old/mixed artifacts refuse whole ([audit](passes/suppressed-hooks.md)) |
| `digest/file_memo` | **sealed-only**, guarded/opt-in refused | Suppress `Digest::MD5.singleton_method_added` and replace `file`: bytes checks still pass but cannot certify the skipped digest method; third hit is stale. SEAL001 required. Private-page benefit is historical, not guarded safety evidence; old/mixed artifacts refuse whole ([audit](passes/suppressed-hooks.md)) |
| `active_record/instantiate` | **sealed-only**; performance still parked | Suppressed model singleton hook plus replaced `instantiate_instance_of` changes original row titles but not fast rows. AR epochs remain 52/55; cached guard remains true. SEAL001 required. Historical −38% alpha load-only gain disappeared upstream, blog stacked +0.59% remains a loss ([audit](passes/suppressed-hooks.md)) |
| `active_record/preload_plans` | **sealed-only**, guarded/opt-in refused | Suppressed model singleton hook plus replaced `scope_for_association` filters original rows but not fast rows. AR epochs remain 52/55, so the epoch is not complete coverage of suppressed dependency mutation. SEAL001 required; old/mixed artifacts refuse whole ([audit](passes/suppressed-hooks.md)) |
| `active_record/ar_plans` | **sealed-only**, guarded/opt-in refused | Suppress the visitor owner's `method_added`, replace `visit_Arel_Nodes_SelectStatement` with an SQL-comment-producing body: original SQL changes, cached plan SQL does not. Same visitor identity and unchanged AR epochs 52/55 do not rescue the certificate. SEAL001 required; old/mixed artifacts refuse whole ([audit](passes/suppressed-hooks.md)) |
| `inertia/config_bind` | **sealed-only**, promotion blocked | Warmed suppressed `Hash.method_added` defeats the guarded certificate. Pre-fix JSON interpreter −6.947%, HTML −0.275%; accepted YJIT **+16.339% / +16.459%** included sticky global tracing. Post-fix JSON interpreter **−10.156% accepted**; YJIT rejected A/A/flatness and a separate untimed probe has zero hits (JIT-mode fact mismatch). No accepted post-fix YJIT non-regression proof, no promotion. #437 open/unmerged; 3.23.0 lacks it; future fixed bodies refuse ([diagnosis](passes/yjit-regression.md), [old prices](passes/next-levers.md), [audit](passes/suppressed-hooks.md)) |
| `inertia/props` | opt-in experiment; exact-guard ordinary-def alternative **stopped at price**; no promotion | Ordinary-Hash tuple iteration only; original prop body/lexical scope and fallback retained, actual iterator/visibility checked at every traversal after app code. Five-app 779 outcomes and own-thread SQL identical, nonzero hits in all three Inertia apps. Historical draft +0.873% interpreter / +0.976% YJIT cohorts stay rejected after safety fixes changed fingerprints ([retained evidence](passes/props.md)). Final-runtime brk512 request recheck: interpreter +4.364% [+4.292, +4.462] accepted; YJIT diagnostic +31.043% rejected (5/36 non-flat workers; [recheck](bench.md#decision-critical-512-mib-remeasurement-2026-10-20)). Separate corrected ordinary-def micro: +22.594% interpreter [22.496, 22.731], complete checks cost 6.857× the iteration saving; YJIT micro **cancelled**, invalid earlier fallback price retained ([stop and pins](passes/yjit-regression.md#corrected-interpreter-pricing-stop-at-price)). No credited gain or retry. |
| `sealed/token_tag` / `sealed/collection_render` | passive production units; **no accepted dispatch-corrected price**, sealed-only | Natural first-original witnesses, exact native/source/stock-body certificates and identical off/on seams; no runtime objspace/materialization/lookup or on-only prepend. Live token generation/name conversion and stock continuation for unknown values; collection retains live lookup, iterator/preload, locals/cache-key effects, Template rendering/events. On **BlogShowGetOnly GET /articles/1**, the [62f8a6b re-price](passes/production-dispatch-reprice.md) is **rejected no-GC A/A**; diagnostic total −14.536782% is not a price. Historical [553e7aa −15.225536%](passes/production-interpreter-reprice.md) is defective-source only, and ae025b0 −15.49% is not current either. Pre/post cold and 192+192 gates pass; native hits 50/200/50, zero fallbacks, epoch deopt 1/4/1. Old six-pending-Turbo-job seed remains a named async refusal; old pricing specimen stays rejected. No cross-fixture, native-latency, YJIT or test-tier claim ([boundary and gates](passes/sealed-production.md)). |
| Whole compiled ERB specialization | surveyed; no pass | I18n epoch not closed; Campfire URLs have 7 valid guards but 0 completed lowerings/request. No credited saving; [profile and refusals](passes/erb.md) |
| Literal-run ERB | rejected | 2 sites across five apps; two append calls saved per rendered layout do not justify a pass/guard ([survey](passes/erb.md)) |
| Route pass with host/protocol `default_url_options` | parked | Widening the optimized predicate is not exact (`to_param` ordering counterexample); scalar-only args cover 1/4 Campfire path calls, base-AR `to_param` certification would cover 4/4, but the ceiling is ~0.3 % of an uncached room request (19 calls × ~2 µs). Revisit as a stacking item once per-hit route budgets exist ([route-helpers.md](passes/route-helpers.md)) |
| Template lookup | parked | At most 0.42% before complete guards; `clear_cache` and `DetailsKey.clear` change Templates while path/details identities stay unchanged. Needs a filesystem-resolver epoch ([survey](passes/template-lookup.md)) |
| `run_callbacks` specialization | parked; stacking only | Census: 4–7 calls/request, no nonempty symbol-only chains. Eligible no-around machinery is 0.141–0.975 % of eleven corpus routes, even before guards; action bodies are not removable. Rails already caches chains, and upstream [PR59094](https://github.com/rails/rails/pull/59094) removes known-terminator thunks. No runtime pass; [survey and measured boundaries](rails-suite.md#round-2-callbacks-are-parked-not-a-225-app-opportunity) |
| Tag/form attribute component | parked; measured instruction loss before checks | Rails main [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b), absent in 8.1.4, saves 150/139 objects per actual blog show/index-shaped bundle but **adds 41,521/34,495 interpreter Ir**, 23,098/18,793 YJIT Ir. Both finite corrected micro cohorts pass; invalid lost-frozen-source/bind_call attempt retained, not salvaged. Generic nested-Hash semantics also differ from 8.1.4. No component/backport: exact sealed/guarded certificates and installed L4 helper gates still needed; cheap upstream test scaffold is not a positive net price ([prices and boundary](passes/next-levers.md), [earlier survey](passes/tag-options.md)) |
| Upstream `String#blank?` / sealed backport | **candidate #3 parked; timeout semantics block 5/5 core apps** | Show micro −118,626 interpreter / −155,248 YJIT Ir, zero objects, ≈1.4% conditional budget (<2%, not a request win). Both 4.0.7/4.1 reproduce global and per-Regexp timeout exceptions skipped by main; all five production boots use global 1.0 s, so nil-policy refusal admits 0/5. No pass or cohort. If revived: original throughout boot, seal-time native/subclass/singleton/constant/policy checks and escaped Method/UnboundMethod refusal, then normal def with original owner/name/path/parameters, no prepend/hot guard. Cold load_iseq changes uncertified pre-seal behavior. Upstream Rails remains the path ([evidence and policy table](passes/string-blank.md), [delivery boundary](passes/next-levers.md#sealed-candidate-3-not-a-guardless-backport)) |
| Seal-check global Regexp timeout policy | **SEAL005 detector gap fixed independently** | Original public probe: epoch 0 → 0, empty ledger on both Rubies. Native-getter comparison at setter return now proves actual changes with before/after values; saved setter and restoration before checkpoint are covered, unchanged/rejected setters stay clean. Test observer only, no guarded/sealed production wrapper or default change ([regression](../gem/test/seal_test.rb), [evidence](passes/string-blank.md#timeout-policy-refuse-including-in-sealed-mode)) |
| Campfire fragment caches | stay | Uncached all-pass renders cost roughly 1.8–9.6× warm hits in the measured room/sidebar fixtures; even the layer study's 33–41% endpoint-lowering ceilings would not close the gap. No observed c < a; native A/A fails, so no precise pass gain claimed ([measurements](passes/campfire-fragments.md)) |
| Fixed-shape serialization | parked | 0–0.18 %; Alba key-plan prototype **rejected** (regressed Redprints, +20 objects) |
| Empty callbacks (standalone) | rejected | < 0.006 %; superseded by the `run_callbacks` survey |
| Campfire CSP/importmap reuse | rejected as a pass | A cache changes `Regexp.timeout` semantics; fixed in the app instead (upstream PR) |
| Freezolite in Lowrail | rejected | App decision; documented under complementary optimizations |
| Escaping AR app-chain plans | parked | Zero credited until exact full-chain eligibility is shown |

## Later

- Revisit Roundhouse for typed-IR ideas once the stacked-pass measurements
  exist, to compare what per-site lowering actually buys.
- Spinel target: out of scope for now.

## Stacking backlog

Small exact savings (each < 2 %) that are worth revisiting once the large
items are done, because they may add up. Shares are removable estimates or
upper bounds per route, not measured request wins. Re-measure with
`lowrail bench --passes SET` before building.

| Item | Est. removable share | Certification needed | State |
|---|---|---|---|
| Route lowering under host/protocol `default_url_options` | ~0.3 % Campfire room (19 calls × ~2 µs) | base-AR `to_param`, attribute/type facts; generic script order | parked ([route-helpers.md](passes/route-helpers.md)) |
| View-scoped route-refusal cache | no current runtime purpose: quarantine removes every route source arm | reconsider only after an exact receiver/body and post-conversion continuation rewrite | parked WIP (patch + local stash), not shipped; no reactivation or further measurements |
| Template lookup | ≤ 0.42 % blog edit, ≤ 0.24 % Campfire, ≤ 0.23 % Redprints, ≤ 0.08 % PingCRM | filesystem-resolver epoch on `clear_cache`/`DetailsKey.clear`, live details/locals | parked ([erb.md](passes/erb.md)) |
| Callback machinery (no-around chains) | 0.14–0.98 % across 11 routes | chain identity + set/skip/reset_callbacks epoch | parked; Rails main PR 59094 removes part upstream |
| `inertia/config_bind` | measured Starter JSON −6.947% interpreter, **+16.339% YJIT** vs off; not a default gain | SEAL001 contract required; current version/body allowlist must refuse an upstream-fixed version | sealed-only; #437 still open/unreleased, guarded/opt-in and old artifacts refused ([prices](passes/next-levers.md), [audit](passes/suppressed-hooks.md)) |
| Fixed-shape serialization | 0–0.18 % PingCRM | exact key plan without extra allocations | parked (Alba key-plan prototype rejected) |
| Tag/form attribute component (includes literal attributes) | **loss before guards**: show/index +41,521/+34,495 interpreter Ir; −150/−139 objects/request-shaped bundle | 8.1.4-compatible nested-Hash semantics, actual receiver/body/primitive/table certificates after live conversions; sealed contract or guarded continuations; installed L4 tag/form helper tests | parked; upstream main fusion loses Ir in both modes, no Lowrail implementation or allocation-to-speed inference ([finite prices](passes/next-levers.md)) |
| `String#blank?` | show −118,626 interpreter / −155,248 YJIT Ir before sealed delivery costs; zero objects, ≈1.4% conditional interpreter budget, **no eligible request credit** | SEAL001/005/008/009; native/subclass/singleton/constant checks, nil global and per-Regexp policies, live encoding cache; original through boot, seal-time escaped-handle refusal then normal def, no prepend/hot guard | **candidate #3 parked**, not implemented: timeout semantics exclude 5/5 core production apps (global 1.0 s); <2% micro only. Setter detection fixed separately, not an eligibility waiver. No policy change or request cohort; prefer upstream Rails ([design](passes/string-blank.md)) |
| Receiver dispatch K / amortized residual guards | K micro: −397 interpreter / −231 YJIT Ir per cached check; unsafe guard-elision ceiling: 0.081% default / 0.194% all-opt-in blog, 0.189% PingCRM, 0.036% Starter (noise), 0.278% pinned-8.1.3 Redprints | retain K/V invalidation and Stats behavior; effective method/visibility/constant/config residuals and mid-region safety; runtime structural checks remain in the ablation | K shipped, its before/after request A/A rejected. Separate unsafe ceilings measured, not native wins or promotions; exact residuals planned at entry level. Four-app existing-pass census adds 0 sites solely by ignoring future mutability ([study](passes/speculation.md)) |
| Precompiled `passes.rb` | cold boot only (~0.37–0.40 M instructions once) | none | follow-up |
| Endpoint-scoped compiled-body / no-block `link_to` slice | **loss: +18.565% [+18.534, +18.646] Ir/request on index versus the former default** | source/compiled-method/locals identity, effective helper and visibility at use, live event/render/AR pipeline, isolated byte/header/SQL/event pairs | no widening: four SHA computations, repeated dispatch/residuals and 549,861 Ir of lost source splices explain the regression. Unpublished +5.56% composition and named-helper-only residual are rejected/diagnostic, not credited savings. Unsafe source arms quarantined first ([endpoint](passes/endpoint.md#exact-slice-measurement-and-rejected-composition)) |
| Quarantined source-helper savings | **lost**, not credited: former default −5.995% [−6.012, −5.966] index / −0.987% [−1.040, −0.977] show Ir vs off; quarantined default is within noise of off | suppressed `method_added` on a warmed live helper; name evaluation changing `tag_builder.content_tag_string`; `to_param` changing singleton `route.format`; require actual receiver/body certificates and local continuations at every evaluation boundary | both passes wholly disabled, including opt-in/old mixed artifacts. Quarantine costs +6.367% [+6.333, +6.386] index / +0.998% [+0.960, +1.086] show versus former unsafe default, fixed-heap interpreter with passing A/A/heaps. Five-app hits/fallback maps `{}`; no executable route completion arms. Separate opt-in rewrite only, no native speed claim ([cost and gates](passes/endpoint.md#quarantine-cost-and-gates)) |
| Show-first caller-side section certificates | **no credited request saving**: optimistic combined-lookup checks cost 93,649 Ir for two links versus 90,042 for their entire original work; deficit +3,607 [+3,441, +3,688]. Thin-body expansion also loses +8,905 [+8,780, +9,006] Ir/two links. Initial separate-lookup deficit was +22,401, retained in the evidence | effective receiver/body/visibility after every argument or live-call boundary; once-only callee continuations; full mutation matrix before request comparison | stopped at design/cost gate, no runtime pilot or index widening. Both six-round c9d2397-protocol interpreter cohorts pass total/no-GC A/A, heap and JIT-state controls. Combined public-instance lookup removes avoidable reflection work but still loses. Checks omit remaining primitive/remote facts, entry/delivery and continuation costs; not a complete certificate or request benchmark. Follow-up body-installed pricing also stops below ([design and evidence](passes/endpoint.md#show-section-cost-gate-stop-before-runtime-implementation)) |
| Guarded endpoint body-installed alternative | **no saving**: internal-method checks alone cost 94,466 [94,430, 94,530] Ir versus 89,729 [89,700, 89,768] for the entire two original show links; deficit +4,720 [+4,695, +4,814]. Off / unchanged-ISeq / guard-cost-plus-original arms cost 89,729 / 92,279 / 186,757 Ir. The +2,537 unchanged-delivery increment is retained, unattributed and subtracted before guard pricing | VM dispatch removes the outer body identity check, not the nested calls' facts. Ten method facts still omit actual holder acquisition, primitives, mutable tables and repeated post-call checks. `<compiled>` top-level frame, trace events, edited ISeq identity and reload-handle inequality are refusal reasons; ordinary method metadata/exception frames and active-frame/saved-handle behavior match in finite probes | **guarded endpoint: stopped; requires a sealed contract or a VM epoch**. Ruby-level fact-guard endpoint work ends here. One six-round c9d2397 interpreter cohort passes total/no-GC A/A, five heaps and JIT-state controls; not native speed or a request benchmark. No accelerated runtime/generator, quarantine/default unchanged ([contract and costs](passes/endpoint.md#body-delivery-contract-and-finite-cost-result)) |
| Blog controller filter interpretation (including around chains) | ~0.54 pp index (diagnostic; rejected A/A), ~0.60 pp show of L0, ordered hand-ablation | exact ordered chain/conditions/method/Proc identities and callback mutation generation; retain CSRF/around bodies, once-only queries and halting/error behavior | measured ceiling only; generator held ([layer study](passes/layer-ceiling.md)) |
| Remaining controller/params/response interpretation | ~1.55 pp index (diagnostic), ~0.74 pp show, after rendering/event removals; not additive with a separate pass budget | original action/render/response hooks and live request format/params facts; preserve execution context, instance state, flash/session and observer behavior | ordered ceiling, not a supported pass ([layer study](passes/layer-ceiling.md)) |
| Blank Comment model for the show form | ~0.49 pp show (~8 objects); absent on index | stock `new`/initialize/schema/defaults, empty initialization callbacks, no observable form-model hooks | prefer retaining the construction to avoid a separate certificate; measured, no pass ([layer study](passes/layer-ceiling.md)) |
| Sealed new-comment form scaffold | **latest accepted interpreter show request −14.457% [−14.474, −14.410]**, 8.750826 → 7.485376 M Ir; new counted budget 1,271,062.10 Ir/hit, one completion/request, **measurement_complete:true**. All request/operation controls pass, native `vm_trace` self zero in every arm. Earlier −14.405% request and ~14.7% micro remain separate and unchanged | literal ERB/site/locals, stock construction/defaults/pure conversions, FormBuilder/helpers/config/I18n boot inventory; live constructor, URL calls, CSRF masking, tag-table reads, fresh output and per-hit unknown-holder/value checks | **sealed_only, no default change or promotion**; first accepted sealed request lever above 2%. Public CLI regression covers 192+192 observable pairs, renamed-app certification and custom-builder refusal. Historical completeness stays false; only the new budget/request run is complete. Matching-mode YJIT native hits/zero trace exits pass, but its one warmup-v2 cohort is **rejected** for JIT-window/warmup and heap failures; raw −13.938% is diagnostic only, no retry or accepted YJIT non-regression. Post-measurement cleanup releases the 42-file source cache only after complete activation, then refuses recertification rather than compiling lazily; weak-root lifetime, 50-hit and epoch/later-setup fallback regressions pass. No repricing; remaining YJIT object-gap diagnosis separate ([pinned request/export and generator](passes/sealed-form.md)) |
| AttributeSet reads/casting | ≤2.02% inclusive blog index discovery bound, **not removable credit** | exact attribute/default/missing/cached-nil/type/dirty-tracking contracts and method/type mutation facts; Rails L4 tests | direct-ivar prototype combined with Journey/Fanout regressed show +0.128%; index control rejected. No saving credited; individual components unpriced ([layer study](passes/layer-ceiling.md)) |
| Journey Format structure | ≤0.50% inclusive blog index discovery bound, **not removable credit** | route reload generation, exact format/escaper structure and parameter-before-child evaluation/missing-key behavior | combined prototype does not win; per-component cost still unpriced ([layer study](passes/layer-ceiling.md)) |
| SafeBuffer/OutputBuffer interpretation | ≤1.51% inclusive blog index discovery bound, **not removable credit** | exact safety/mutation/encoding/capture/streaming/handler contracts; source/method/resolver generations and L4 tests | survey only; no component implemented or saving credited ([layer study](passes/layer-ceiling.md)) |
| Empty-list Notifications Fanout fast path | unpriced individually; no credited request saving | retain live subscriptions/silence or complete notifier/subscription/log-level/silence epochs; framework tests | combined prototype does not win. Preserve endpoint events; old eventful −37.29% show is an upper bound missing observable assigns, not supported equivalence. Boot-time subscriber absence is insufficient ([layer study](passes/layer-ceiling.md)) |

### Allocation census follow-ups (Rails 8.1.4)

Objects/request below are **conditional discovery-pool ceilings**, not achieved
savings or a traffic mix. They start at zero until eligibility/certification is
closed; overlapping pools must not be added. Source line/class rankings, exact
off/default totals, retained/garbage, micros and upstream commits are in
[allocations.md](passes/allocations.md). Category-a data/IO/client/opaque rows
are deliberately not pass candidates. Rows group category-b callsites into
coherent mechanisms; category-c rows retain their upstream-solved disposition.

| Item | Estimated objects/request | Certification needed | State |
|---|---|---|---|
| Compiled form/literal-tag intermediates | Blog edit 0–44 in three named option/name pools; more buffer pools unpriced; simple-fragment micro saves 26/call, **0 real-form request credit** | Source/compiler/resolver/locals, effective helpers/TagBuilder, I18n generation, live form/errors/config/value safety/encoding, fresh output and order | interpreter micro accepted, final YJIT heap rejected; whole fragment/component, not arbitrary freezing; overlaps existing ERB/tag/endpoint work |
| Inertia prop tuple iteration (`inertia/props`) | **No credited request saving.** Draft Starter JSON increases Ir +0.873% interpreter / +0.976% YJIT and objects 1,236.89→1,254.49 / 1,241.05→1,258.19; original conditional pool ceilings remain Starter 0–11 / Redprints 0–11/13 / Ping 0–22 Arrays | Implemented source/owner certificate and unconditional actual ordinary-Hash iterator/body/visibility checks at each recursive entry; live lazy/partial/once/deferred/rescue/serializer/recorder operations, fresh output and permanent post-entry mutation regressions | opt-in only; one finite c9d2397 cohort per mode, no retries. Both controls pass but final fingerprints changed for malformed-certificate/Ractor safety fixes, so both cohorts are rejected as final-runtime certification, retained as diagnostics. Five-app 779 outcomes/own-thread SQL identical. No promotion, no assumed additive benefit; future guard-cost work needs new certification and a declared finite study ([results](passes/props.md)) |
| CurrentAttributes default tuple iteration | Starter 0–10 Arrays; Redprints 0–6; Ping 0–4 | Exact defaults/reset/Hash methods; retain per-request Proc execution and value `dup` | source/runtime variant candidate; separate certificate from props |
| FrozenRecord CFP scalar-ID lookup | Redprints list 0–300, show 0–15 (20/1 independently counted calls × 15 objects/call) | Class/source/methods/comparison, current unscoped Scope and empty criteria/order/index state, live load/reload/max-scan policy; identical result identity/errors | conditional micro only; interpreter and YJIT instruction A/A rejected; no result cache |
| StoreModel scalar-read forwarding | Redprints list/show 0–203/19 Arrays at generated-reader source line 273 | Exact generated getter and StoreModel/AR ancestor methods, scalar schema/type/enum facts, missing/default/cached-nil and parent-assignment behavior | source-callsite/endpoint candidate; **not** generic Rails reader overhead or boot-time code generation |
| Notification template-root prefix | Blog 0–5 Strings, not all 10 line-61 Strings | Root/template/source/method facts; preserve live observers and fresh final path/payload per event | runtime variant/component candidate, never event elision |
| Importmap preload iteration | Blog 0–8 Arrays at helper line 42 | Helper/compiler/importmap/order/safety/buffer facts; resolver/nonce/URL/regexp-timeout behavior remains live | source/component candidate; no URL memo; overlaps layout lowering |
| Route fresh-buffer residue | Blog 0–7.33 Strings, equal-route mean | Fresh owned path buffer, route/mount/script/default/escaper/to_param facts, output identity and evaluation order | source-plan candidate; overlaps existing route/Journey rows |
| Net::HTTP SSR setter discovery | Starter HTML 0–34 Strings, JSON 0 | Exact setter set/order and Net::HTTP methods; live proxy/TLS/env/options/IO/error/resource behavior | runtime variant candidate; not removal of SSR/network |
| Net::HTTP header capitalization | Starter HTML 0–26 intermediate Strings, JSON 0 | Exact methods/input encoding/case/order; fresh final headers and live values | component candidate; separate from setter discovery |
| Inertia prop path scaffolding | Starter 0–11 Strings; Redprints list/show 0–11/13; Ping 0–22 | Exact keys/methods/metadata configuration; prove nonescape, preserve fresh metadata paths and all live values/errors | source-plan candidate; tuple micro does not price this |
| Inertia metadata `try` dispatch | Starter 0–28 Arrays; Redprints list/show 0–28/34; Ping 0–40 in three named pools | Exact receiver/helper/metadata methods and visibility, live partial/once/deferred/rescue behavior | source/component candidate; not counted as tuple savings |
| Inertia config extraction Hashes | Starter 0–8 at `hash/slice.rb:25` | Existing config-bind source/schema/controller certificate; live options/Proc/mutation/override/fresh storage | **subset** of existing opt-in config-bind row, not additive |
| AttributeSet key unions | Starter 0–8 Arrays (returned Array must remain) | Schema/type/default/missing/extra-attribute membership, exact methods/mutation and ordering | component candidate; no bypass of casts/defaults |
| Literal inflection plans | Starter 0–16 Strings equal-route mean; profile 32 both formats, dashboard 0 | Literal caller/input, inflection/locale rules generation, exact methods/encoding/fresh observable output | source candidate; no global dynamic-string cache |
| PostgreSQL type-map tuple dispatch | Ping 0–38.5 Arrays equal-route mean | Connection/shard/schema/OID/type-registry generations, adapter methods/extensions/custom types/errors | adapter component candidate; real rows/casts retained |
| Fixed query-shape allocation plans | Ping 0–62.5 objects equal-route mean in four named handler/options/placeholder/sanitization pools | Schema/adapter/scope/handler/method facts; live binds, quote/SQL/evaluation order and authorization/notification hooks | component/endpoint candidate, not a query/result cache; overlaps authorization |
| CanCan finite rule-shape wrappers | Ping 0–14 Arrays equal-route mean | Exact DSL/rule/order/alias/condition generation and endpoint eligibility; current user/permissions/SQL remain live | high-burden endpoint candidate, not permission-result memoization |
| Scalar Article DOM ID (extra micro) | 0 request credit; 3 interpreter / 2 YJIT objects/certified eligible call | Exact Article/naming/to_model/to_key/id/schema/visibility/singleton mutations, integer shape, fresh String | conditional source micro; YJIT cohorts rejected (A/A, then heap); eligible request frequency unmeasured |
| Upstream attribute appends (c/tag) | Blog observed mean 79.67 intermediate Strings; removal uncredited | Exact version/helper methods and unchanged escaping/output semantics | already solved on Rails main [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b); overlaps parked tag component |
| Upstream callback thunk (c/callback) | App mean observed Proc pools: blog 10.67, Starter 14.5, Redprints 15.5, Ping 15 | Exact chain/terminator methods; retain callback bodies/control flow/mutation | already solved on main [7a2033c9](https://github.com/rails/rails/commit/7a2033c9b88b4eb4ff5c50fcc2bf68b5d50c70e4); overlaps callback row |
| Upstream static miss candidates (c/static) | Observed 45 Strings/Arrays/request; not all necessarily removable | Exact middleware/file-server/source and live path/file/encoding/error behavior | upstream main [bac124be](https://github.com/rails/rails/commit/bac124beceb2d899340647718f1eef68a9c9cbec), [ef95eda7](https://github.com/rails/rails/commit/ef95eda7b74a7888432ea36bff7e0bf9a7fa8d4e); no local backport |
| Upstream scalar `to_param` (c/param) | Blog observed mean 14 Strings + 7 Arrays; fresh final String retained | Exact AR key/to_param/schema/method facts and once-only access; composite fallback | upstream main [a3319707](https://github.com/rails/rails/commit/a331970705be25cc338854490fbd05144c810555); overlaps routes |
| Upstream Journey construction (c/route) | Blog observed mean 14.67 Arrays + 7.33 Strings; final paths remain | Exact formats/routes/escaper/method generations, missing/optional/evaluation-order semantics | upstream main [938d6069](https://github.com/rails/rails/commit/938d6069a8c1ad03fe7baa6d86572b8e2e3852a5); overlaps Journey/routes |
| Upstream controller URL-options (c/url-options) | Blog observed mean 7.33 Hashes, removal uncredited | Exact controller/request/script-name/recycle contract and live engine dispatch | upstream main [042e0851](https://github.com/rails/rails/commit/042e0851acbb17b375f23af58214139fdef637d8); no blind memoization |
| Upstream scalar association keys (c/keys) | Redprints observed mean 32 line-373 Arrays; some key/results still needed | Exact reflection/key shape/schema/method facts and composite fallback | upstream main [fafab17b](https://github.com/rails/rails/commit/fafab17bfc40812a794c2492845deb519ab1f387); overlaps AR plans |
