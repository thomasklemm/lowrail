# Sealed new-comment form scaffold

**Current runtime: passive-v1 natural admission; not yet priced.** The first
natural certified form is wholly original. Its completed render supplies the
read-only witness; only a later entry may specialize. Old effectful
certificates still refuse. The guarded default, quarantine, and per-hit form
input/epoch/actual-holder checks are unchanged. The accepted measurements
below remain pinned historical prices, **not prices of this admission path**.
See the [review gates and coverage](../sealed-verification.md#passive-form-v1-review-gates).

## Passive form v1

Build time retains the synthetic stock audit, and separately records the
compiled original form block, pure class-attribute readers, literal translation
and polymorphic caches, source digests and native method/binary identity.
Runtime does not repeat the audit. It reads only app-populated state after a
successful natural form render: the controller's cached view class, generated
model/schema caches, already-initialized I18n state, route/config tables and
the original block's ISeq. The audited stock `_routes` getter reads an ivar or
its captured RouteSet; it does not construct one. Missing or changed facts
refuse; they never authorize require/autoload, compilation, SQL, view/model
construction, hook replay or weaker actual-holder introspection.

`Lowrail::Native.exact_class?(object, expected)` is mandatory. There is no
objspace fallback. The whole loaded native binary and C method metadata are
certified. Different Ruby/native/source/JIT builds need a fresh certificate.
Generated template method labels alone are process-local; the block signature
replaces only that label, retaining instructions, operands, locals, catches,
line events and source paths. This is not arbitrary compiled-body normalization.

The observer is installed via the existing natural Action View load boundary
with explicit `LOWRAIL_SEALED=1`, **including LOWRAIL=0**. Both arms load the
same seam files and inherit the same `FormScaffold::Variant`; off never
configures admission or enables its fast path. Default/guarded setup is not
changed. The cold witness records bound method owner, instance-method source,
full inherited ancestry and seam loaded features, not just direct ancestors.

Admission has **one witness attempt per process**, guarded by `Mutex#try_lock`.
Concurrent entries choose original before publication; `@active` is published
last, only after every check and the seal-epoch check. A failed attempt is
terminal; another setup refuses rather than resetting the budget. Pending
noncertified forms do not run the witness. Runtime state exposes attempts and
the successful one-time wall duration; that diagnostic cost is not per-hit
pricing. Explain/doctor/MCP read recorded pending/refused reasons without
executing a witness. Terminal messages include the exhausted attempt budget.

The eight-thread witness holds admission while seven other first renders
finish: all eight remain original, with zero prepublication hits; the ninth
gets one hit. Both 192-pair controls (ordinary and header-writing subscriber)
retain byte-identical responses, every header, SQL, events and assigns, with
**104 hits and zero form fallbacks each**: the historical 105th hit is now the
original admission render. The blog C cold show remains zero, then a natural
repeat gets one. These are bounded behavioral checks, not a whole-app support
claim. Known all-sealed Template/Preloader ancestry differences remain red;
the isolated form artifact selects neither seam. No filter flattening is
included. Token/collection micros below remain measurement specimens, not
silently added production stages or additive request savings.

## Separate collection, token and filter prices (2026-10-21)

Three **separate finite interpreter micro cohorts** ran sequentially on
[`2c6899c`](https://github.com/thomasklemm/lowrail/commit/2c6899cd444583c96006430da03cb32776e23bb7),
after fresh disposable production/interpreter builds and native admission.
These are **not whole-request numbers and are not additive**, either with
one another or with the historical form price. Each candidate includes its
own eligibility checks and live residue. Standalone checks/residue arms are
diagnostic, not an arithmetic decomposition of the candidate.

| Isolated real operation | Saved total Ir, paired median [95% CI] | Paired candidate Δ% [95% CI] | Decision |
|---|---:|---:|---|
| One stock two-comment collection invocation | 200,979.80 [200,498.47, 201,333.63] | −9.88386 [−9.90693, −9.87628] | Accepted isolated collection-fusion price |
| Four live token tags from one show request | 89,927.06 [89,170.80, 90,472.40] | −11.12246 [−11.21563, −11.00622] | Accepted isolated token price |
| One real controller filter chain | 4,124.64 [−2,807.96, +6,516.19] | −0.046934 [−0.074127, +0.031951] | Controls accepted; **no resolved saving, stop at price** |

GC-excluded saved Ir are respectively **200,884.46**
[200,569.19, 201,311.37], **89,807.18** [89,689.44, 90,048.67],
and **3,296.42** [−1,380.45, +7,359.27]. Filter's interval spans zero in
both modes. Its flattened-chain specimen remains evidence only: it is
excluded from passive-form implementation and every production plan.

Ruby 4.0.7 / Rails 8.1.4; six whole randomized rounds, seed 41231,
N=0/200 subtraction for collection/token and N=0/50 for filter, at most
**three** simultaneous Callgrind workers.
Collection/token each use 30 workers and 120 GC-free windows; filter uses
18 workers and 72 GC-free windows. All unchanged total/no-GC A/A, five-heap,
brk-preflight and actual-interpreter gates pass. No retry, extra cohort,
selected-arm salvage, YJIT measurement or gate change occurred. The A/A
total intervals are [−0.053963, +0.024373]%,
[−0.027465, +0.050796]% and [−0.048705, +0.057596]% respectively.

Before counters, each specimen passed both **192-pair** observable controls
(ordinary and header-writing render subscriber), with 105/285/108 active
hits respectively and no fallbacks. Fifty native requests recorded
50/200/50 active hits and zero fallbacks; separate negative controls retained
the original behavior for epoch/input/chain changes. Fresh association SQL,
records, live CSRF masking, halting/around/security bodies, and fresh request
objects stay live in their respective specimens.

Common runtime SHA is
`36cb0a49b31ce2b30ba6213d29ae18048f0de81b4083667230987be8a0ae4d8b`;
harness SHA is
`b45c39d6b772e5acf604ca9a6b8bd4385a8d76c8f48d373aa36437243997f5aa`.
Fresh artifact manifest SHAs (not production activation claims):

- Collection: `9cee23cfa8f0d390393112a9d048402d0df84853ce04c498be80fd016c3c2423`.
- Token: `829a2a84c291a30ac7c9520e14bb5ddaa22db31ad0aa74ae75c18ffbe9991523`.
- Filter: `01e4aa76b2ef8030a5fcd17e80874650e0d6d54897571349677ed5af94326bf5`.

The [numeric export](sealed-micros.json) includes exact source/tool/fixture/
artifact/runtime/harness pins, paired intervals, rounds, window endpoints,
heap capacities and controls. Raw app responses, tokens and logs remain
private. Run the corresponding `bench/experiments/sealed_collection.rb`,
`sealed_tokens.rb` or `sealed_filters.rb` against a new disposable app/output,
with `RAILS_ENV=production LOWRAIL=0 BENCH_JIT=0 BENCH_ROUNDS=6
BENCH_SEED=41231 BENCH_JOBS=3` and the pinned Valgrind on PATH/CPATH.
These measurement-only specimens are not production installers.

Old effectful form certificates remain refused. The next priced target,
**only after passive-admission review gates are reported and a new allocation**, is
one whole-request interpreter show cohort with form, token and collection
active together. Only that run can establish their actual combined price;
neither a sum nor an inferred request percentage is credited here.

## Historical form prices

**Latest accepted interpreter request saving: −14.457% [−14.474, −14.410].**
The new budget-plus-request run uses **8.750826 → 7.485376 M Ir/request**,
with **`measurement_complete:true`** and no unmodeled units. The earlier
−14.405% request result remains unchanged, not rescored.
This remains a `sealed_only` pilot: **no default change or promotion**, and no
accepted YJIT non-regression cohort. See both pinned interpreter results below.

Before implementation, the complete checked measurement specimen saved
**1,282,228 Ir/form** [1,280,077, 1,284,287], **−79.712%** of the original
form's work, and **392 objects/form**. One invocation on blog show implied a
conditional **about 14.7%** request budget against the separately measured
8.744 M interpreter baseline. That micro remains a separate source-pinned
experiment, not an additive stacking claim, native throughput or promotion.

The owner selected this slice after the [link pilot](sealed-links.md) stayed
in the stacking backlog. It is the largest stage in the earlier
[behavior-matched renderer](sealed-renderer.md): about 1.296 M Ir between
`restored` and `form`. This new price isolates the real form, without replacing
the surrounding renderer, filters, collection or hidden-token implementation.

## What was priced

The [measurement-only specimen](../../bench/experiments/sealed_form.rb)
captures the actual compiled `articles/show.html.erb:42` block in a real
request. Its original arm replays **that ERB block**, including Rails'
capture/output-buffer ownership, through stock `form_with`; it does not use
a cheaper handwritten baseline. All four operation arms construct a fresh
`Comment.new`. No constructor, record, HTML, query result or token is cached.

| Arm, one form including `Comment.new` | Total Ir | GC-excluded Ir | Objects |
|---|---:|---:|---:|
| Original A | 1,608,577 | 1,608,495 | 470 |
| Original B | 1,608,828 | 1,608,453 | 470 |
| Eligibility checks + construction | 61,641 | 61,643 | 12 |
| Live residue + construction | 305,930 | 305,958 | 74 |
| Complete checked candidate | **326,348** | **326,341** | **78** |

Every arm includes the constructor; **standalone arm medians are not
additive**. Candidate minus original is paired by whole round, not a
subtraction of displayed medians. No-GC paired saving is **1,282,098 Ir**
[1,280,039, 1,284,504]. Nominal intervals resample six whole rounds, seed
41231; they are coarse and do not prove production traffic performance.

The predicate conservatively charges a main-Ractor/epoch check per hit,
actual view/Article/Comment holders, English locale, persisted parent,
unpersisted blank child with no errors, and the stock tag-builder holder and
its view context. `ObjectSpace.internal_class_of` does not create an
eigenclass and refuses existing singleton overrides. No effective-method or
visibility lookup, global TracePoint or constructor-provenance wrapper runs.

Remaining work stays live and in order: `Comment.new`, the parent route
helper, the second `url_for` after field construction, action escaping, real
`token_tag`/per-form CSRF masking, mutable `PRE_CONTENT_STRINGS` reads, and
fresh safe output. Symbol `:label` and String `"textarea"` keys are distinct;
an asymmetric table probe checks that distinction. Unknown input refuses
before replacement work and calls the original with the already-created
model/block, without reconstructing the model or replaying conversion.

## Exactness and eligibility boundary

The model is the freshly constructed blank Comment at this literal source
site, **not any object whose current getters happen to return nil**. A
production generator must first certify stock construction, pure accessors
and conversions, nil schema defaults, no initialization callbacks, the exact
ERB block and locals/compiler context, FormBuilder/tag helpers, URL helpers,
I18n translations/inflections/backend, config and primitive dependencies.
The micro checks empty initialization callbacks/defaults but is **not** that
inventory or a generic certificate. Source fingerprints pin the tested
fixture; one successful request does not prove purity.

Non-English locales, nonblank/defaulted/error/persisted children, custom
builders, preexisting singleton holders and unmodeled callbacks must remain
original. Runtime config, I18n backend/table and certified method mutations
are excluded only by the explicit [sealed contract](../sealed.md), not by
these value checks. A production variant must not be admitted merely because
this experiment's helper predicate accepts a model.

The existing isolated comparator passes **192 literal pairs**, then another
**192** with a render subscriber that writes a response header: status, body,
**all** headers, ordered SQL/binds/cache flags, controller/render events,
assigns, AR state, transaction and query-cache state. Each on run completes
105 form replacements; the untouched index and refusals remain Rails. The
four fixture families include escaping/Unicode, missing records and empty
comments, with existing/absent sessions and six request shapes.

Native untimed probes also check nonblank input, validation errors, persisted
models, singleton model overrides, a foreign builder context, another locale,
epoch deopt and mutable tag-table entries. Only these replay probes normalize
the independently masked token values; they decode and validate the real
per-form token for the emitted action and POST/PATCH method. The isolated
request checker compares raw bytes without token normalization. Correctness
freezes clocks/entropy symmetrically; **measurements use real entropy**.

## Pinned cohort and controls

Measured revision:
[`642f0b3`](https://github.com/thomasklemm/lowrail/commit/642f0b334c976d06d3a11ea3065bf179fc813a7a).
Ruby 4.0.7 / Rails 8.1.4; six randomized rounds, N=0/200 subtraction,
30 fresh workers, at most four concurrent. Five fixed heap floors are
1,000,000/250,000/100,000/20,000/10,000. All **120 windows are GC-free**.
No completed cohort/control was retried or salvaged.

- Total A/A **[−0.02688, +0.05606]%**, no-GC A/A
  **[−0.02960, +0.05802]%**: both contain zero and pass ±0.5% tolerance.
- All five actual heap-capacity checks and actual interpreter checks pass.
- Pinned Valgrind 3.19.0, 512 MiB reservation; Rails-boot allocation preflight
  passes, no overflow warnings. Tool SHA:
  `5edddeee9ee49e9d4ff2188c7d01ea03e389a5acf091af4c465d04e52fda9588`.
- Fixture lock SHA:
  `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
- [Numeric export](sealed-form.json) retains exact experiment/fixture hashes,
  framework fingerprints, paired estimates, all rounds, window instruction,
  allocation/GC endpoints, heap capacities, controls and correctness digests.
  Raw responses, cookies and logs remain private.

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SEALED_RENDERER_STAGE=form_site \
  mise exec -- ruby bench/experiments/blog_endpoint_check.rb \
    .corpus/real-blog-r4 /tmp/NEW-form-check render_subscriber
# Omit render_subscriber for the ordinary 192-pair comparison.
ulimit -d unlimited
PATH=/tmp/PINNED-VALGRIND/bin:$PATH CPATH=/tmp/PINNED-VALGRIND/include \
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 BENCH_JOBS=4 BENCH_JIT=0 \
  mise exec -- ruby bench/experiments/sealed_form.rb \
    .corpus/real-blog-r4 /tmp/NEW-form-price
```

The guarded tier and seven-pass quarantine remain unchanged. YJIT was held
at micro publication; its later finite request follow-up is rejected below.
The finite **real-artifact** interpreter show cohort below supplies the request result;
the earlier micro alone did not pre-authorize a speed claim.

## Production generator and variant

`sealed/form_scaffold` is a separate `form_with` method variant, selected only
by `build --sealed --env production` and production `LOWRAIL_SEALED=1`.
The original ERB and original Rails helper remain intact. No inline template
if/else, loader change, guard bypass or default-tier opt-in is introduced.

The first generator domain is intentionally narrow: Ruby 4.0.7, Rails 8.1.4,
the eagerly loaded blog classes, and the exact literal blank-comment block
with no locals. Boot inventory certifies effective folded methods and their
public dispatch, independently pinned gem sources, generated accessors and
delegation bodies, schema defaults/types and initialization callbacks,
English literal translations, form configuration, polymorphic naming/cache,
and the ERB handler/compiler context. Activation repeats the inventory,
source and generated-code checks. Unknown input is a ledger refusal with a
remedy, not permission to learn a customized body as stock. Lazy apps and
Ruby 4.1 remain original for this pilot; this is not a generic form compiler.

The application namespace is a build fact, not the literal
`RealBlogR4::Application`: `script/corpus` invokes `rails new` with the chosen
destination, whose basename determines the module, and copies can retain
their original name. The inventory records the actual application class and
rechecks it at activation, alongside the unchanged closed stock/model/config
inventory and app-source pins. The public regression also builds a renamed
application, requires a live form hit without fallback, then still refuses
its custom builder. This corrects a false refusal; it does not broaden the
certified form, model, helper or locale semantics.

The variant keeps the measured live residue and per-hit checks, including
the model constructor in the unchanged ERB, URL generation, real CSRF
masking, mutable pre-content-table reads and fresh safe output. Foreign
holders/builders/buffers, non-English requests, nonblank/error/persisted
children and epoch deopt call `super` with the already evaluated model and
block. There is no cached record, token, generated HTML or query result.
The production no-mutation promise remains essential: this is not a new
Ruby mutation-enforcement mechanism.

The permanent public CLI regression builds an isolated copy of the actual
blog fixture, compares **192+192** raw observable pairs (ordinary and
header-writing render subscriber), and requires form hits with zero form
fallbacks. A separate replay through the public helper checks value-based
fallbacks, asymmetric mutable table keys, output safety/encoding and real
per-form tokens against their emitted action/method. A custom builder that
adds output is refused at build time, and retains that output with Lowrail
off and on. Run with:

```sh
mise exec -- cargo build
mise exec -- ruby -Igem/lib -Igem/test gem/test/form_scaffold_test.rb
```

The regression skips explicitly when the optional blog corpus or Ruby 4.0.7
is absent; that skip is not form coverage. It creates the production schema
and Articles 1/2/3 with three Comments inside its disposable app copy, rather
than depending on the orb's corpus production database. Missing production
data still correctly refuses real build inventory; eligibility is unchanged.
Production request pricing must use the exact published revision and a
freshly pinned artifact.

## Accepted real-artifact interpreter request cohort

Measured published head:
[`f39bcd7`](https://github.com/thomasklemm/lowrail/commit/f39bcd71a8e8ac77b8be0d4fc3e945c932870cb6),
with the implementation from
[`6cfc6e3`](https://github.com/thomasklemm/lowrail/commit/6cfc6e3e8e8e155d731229e69cdbb56aa7a5007a).
The artifact SHA is
`1ba58a84c38bf295d0c4f74b5832ebb451a29e7386d8d148668c5cedec02a83f`.
The existing build denylist excludes `sealed/link_to`; only form unit 18 is
enabled. Other runtime units stay disabled, with **no delivered files or
templates**. This is form-only against unchanged Rails, not a stacked gain.

Ruby 4.0.7 / Rails 8.1.4; `/articles/1` with two comments; one finite cohort,
six fresh randomized rounds, N=0/50 subtraction, seed 41231, at most four
workers, and the same five fixed heaps and pinned 512-MiB Valgrind tool as
the micro. **No retries, extra cohorts or clean-arm salvage.** All 144 windows
are GC-free; heap matching and actual interpreter-mode gates pass. This is
not a production GC schedule or native-throughput claim.

| Arm | Total Ir/request | Paired Δ% vs off-A [95% CI] | Native `vm_trace` self Ir/request |
|---|---:|---:|---:|
| Off A | 8,747,393.93 | reference | 0 |
| Off B | 8,745,130.10 | −0.027 [−0.053, +0.052] | 0 |
| Missing artifact | 8,747,583.14 | +0.018 [−0.012, +0.044] | 0 |
| Empty artifact | 8,744,793.49 | −0.019 [−0.057, +0.004] | 0 |
| Disabled units | 8,746,355.86 | −0.003 [−0.031, +0.029] | 0 |
| Form enabled | **7,486,000.93** | **−14.405 [−14.451, −14.374]** | **0** |

No-GC delta is **−14.401% [−14.451, −14.370]**. Both independent A/A
controls pass: total [−0.053, +0.052]%, no-GC [−0.037, +0.032]% contain
zero and are inside ±0.5%. Objects/request are **2,244.37 → 1,864.24**;
these whole-request medians are not the older micro's allocation count.
The exact-artifact native/public probe records **one form hit/request,
zero form fallbacks**. The public regression passes 192+192 byte/header/SQL/
event/assign/state pairs, live token/fallback replay and custom-builder
refusal. Full implementation-head gem: 142 tests / 4,999 assertions, six
skips, no failures/errors; Cargo 35+1+3. Five-app default outcomes and
own-thread SQL remain identical (blog 21, Campfire 634 with two skips,
PingCRM 26, Redprints 50+12 browser, Starter 36). Other-thread SQL differences
in Campfire/PingCRM remain advisory. Zero default units/hits are not optimized
coverage, and this orb does not claim Ruby 4.1 coverage.

The in-mode tracing check sums **native `vm_trace` function self Ir**, not
its callees, across all native source locations using `callgrind_annotate
--auto=no --inclusive=no --show=Ir --threshold=100`. N=50 minus N=0 divided
by 50 is **exactly zero in every arm and round, in both modes**: 72 deltas
from the cohort's own windows. The same extractor reproduces the historical
positive control **283,074 Ir/request** (14,153,799 − 99, divided by 50).
No tracing tax is subtracted to manufacture this saving.

The separate untimed YJIT diagnostic on the interpreter-certified artifact
has zero lifetime/delta `exit_trace_leave`, but **zero form hits** because
boot inventory differs in JIT mode; the variant is never installed. That is
not fast-path evidence or a statement about interpreter windows. After the
published mode-admission boundary, a fresh `build --jit yjit` artifact on
[`827f935`](https://github.com/thomasklemm/lowrail/commit/827f93530ec33573265bc4c4f1bd83fd384d7b64)
passes an untimed 50-request check: **50 hits, zero fallbacks, zero lifetime/
delta trace exits**. At that publication no YJIT instruction cohort had
started; the later finite warmup-v2 result below is rejected.

The [numeric export](sealed-form-request.json) retains artifact, fixture,
runtime/harness/source pins, per-round values, all controls and window/heap/GC
endpoints, native probes and per-arm trace-self annotations. Raw responses,
cookies and logs stay private. The historical `measurement_complete` flag
remains **false**: at the measured revision, single-pass Callgrind had no exact
runtime-form operation capture/per-hit budget adapter. The report must not relabel the
older handwritten micro or divide this request saving by its hit count to
invent one. **The request saving is accepted; the pass remains sealed-only,
with no default change or promotion.**

## Per-hit adapter follow-up (not a new measurement)

The shared operation worker now captures this certified site's actual ERB
block, view and request context without tracing, removes its capture method,
then replays the **installed production variant and its real `super_method`**.
Every arm constructs a fresh Comment/model array. Both pay `Method#call`;
the variant includes its full predicate. Untimed replay validates live CSRF
tokens independently and compares normalized bytes, safety and encoding
against both the original and the captured request result.

The public regression passes **1 test / 30 assertions**, including the
192+192 observable pairs, constructor/value refusals and native operation
capture. The adapter observes exactly **one invocation and completed hit per
iteration and per request**, not inferred from the request saving. The
matching-mode YJIT artifact also passes that untimed adapter check. Shared
single-pass budget/report arithmetic passes alongside the existing stacked
controls; `--pass sealed/form_scaffold --measure-budgets` can now generate and
compare a genuine instruction budget without editing an artifact to remove
unselected AR units or importing a different-metric micro.

At adapter publication no new operation or request instruction windows had
run. The old numeric export remains unchanged and incomplete. Only a new,
accepted, source-pinned budget plus request run with all existing controls
can produce a new report with `measurement_complete:true`.

## Finite YJIT follow-up: rejected, no retry

One form-only show cohort ran after the separate warmup-v2 A/A validation,
on exact head
[`ab8e4df`](https://github.com/thomasklemm/lowrail/commit/ab8e4dfced319e95527ba480bea845ff330d33bb).
Its unchanged artifact was built on
[`827f935`](https://github.com/thomasklemm/lowrail/commit/827f93530ec33573265bc4c4f1bd83fd384d7b64)
with `--sealed --env production --jit yjit`, manifest SHA
`2bd964cf1d666756287822a9f351d7007bf428d54b9f71ab143b8cd1756b3096`.
The denylist excludes links; only form unit 18 is enabled, with no delivered
files/templates. The pinned app actually declares `RealBlogR4::Application`;
the later app-name fix is not part of this cohort.

Ruby 4.0.7 / Rails 8.1.4, six randomized rounds, N=0/50, seed 41231, at most
four workers, fixed heaps and the same pinned Valgrind tool. Warmup uses
`quiet-2000-v2`; measured workers do **not** use `--yjit-stats`. A repeated
untimed native check on that exact head/artifact records **50 hits/50
requests, zero fallbacks, zero lifetime/delta `exit_trace_leave`, and zero
enabled TracePoints**. Coverage separately records one form hit/request.

The cohort is **rejected**, including all arms and both modes:

- Four of 144 windows compiled additional YJIT blocks:
  `0-disabled` no-GC N=50 **+50**, `2-missing` no-GC N=50 **+8**,
  `5-default` no-GC N=0 **+7**, `5-missing` total N=50 **+14**.
- `3-off_a` and `4-off_a` hit the **20,000-request warmup ceiling**, without
  the required quiet interval.
- Actual heap capacities mismatch: pool 0 **1,000,445–1,002,093** slots and
  pool 2 **100,148–100,570**, beyond the existing one-page tolerance.
- A/A and idle-boundary controls pass; all 144 windows are GC-free. Those
  passes cannot override the failed JIT and heap gates.

Raw total Ir/request is **5,416,639.41 → 4,661,292.39**,
**−13.938% [−14.020, −13.875]**. No-GC is
**−13.925% [−14.067, −13.888]**. These numbers are **diagnostic only**, not an
accepted YJIT saving or non-regression claim. No retry, extra cohort,
selected-arm salvage or promotion occurred. Native `vm_trace` function self
Ir/request is exactly **0 in every arm/round and both modes** (72 deltas),
from this YJIT cohort's own N=50 minus N=0 dumps, not the interpreter windows.

The [numeric export](sealed-form-yjit-v2.json) retains the full result,
source/build/runtime/harness pins, original samples, every rejection and
per-arm trace-self annotations. Runtime and harness file hashes were checked
against the pinned Git revision. Raw files and the byte-identical artifact
archive stay private for the separately owned warmup diagnosis. The
historical accepted interpreter result is unchanged; `sealed_only` status,
the guarded default tier and quarantine are unchanged. There is still **no
accepted YJIT non-regression cohort and no promotion**.

## New interpreter budget-plus-request run: accepted and complete

One new finite run used exact published build/measurement head
[`c51b20e`](https://github.com/thomasklemm/lowrail/commit/c51b20eea4431dbf32e56c9b3693a74934c1e89f),
`build --sealed --env production --jit interpreter`, and manifest SHA
`df827fe2e92cede4dff9eb8dcefe05a54ab1bc673dd2f85e6832ac22ad527482`.
Only form unit 18 is enabled; links are denylisted, and there are no delivered
files/templates. Artifact source pins and every runtime/harness fingerprint
are in the [new numeric export](sealed-form-request-budget.json), checked
against that exact Git head. This is not a rescore of `f39bcd7`, whose
historical `measurement_complete:false` export is unchanged.

Ruby 4.0.7 / Rails 8.1.4, `/articles/1`, seed 41231, real entropy: six
operation rounds at N=0/200, then six request rounds at N=0/50, at most four
workers. Both phases pass total/no-GC A/A, all five fixed-heap and actual
interpreter gates. All **72 operation and 144 request windows are GC-free**.
No retry, extra cohort or selected-arm salvage occurred. The exact-artifact
untimed native check recorded **50 requests, 50 hits, zero fallbacks, no
activation refusal and zero enabled TracePoints** before measurement.

| Request arm | Total Ir/request | Paired Δ% vs off-A [95% CI] | Native `vm_trace` self Ir/request |
|---|---:|---:|---:|
| Off A | 8,750,826.47 | reference | 0 |
| Off B | 8,747,404.35 | −0.021 [−0.046, +0.012] | 0 |
| Missing artifact | 8,745,177.60 | −0.053 [−0.087, −0.011] | 0 |
| Empty artifact | 8,750,084.65 | −0.009 [−0.044, +0.062] | 0 |
| Disabled units | 8,746,562.61 | −0.048 [−0.071, +0.005] | 0 |
| Form enabled | **7,485,376.17** | **−14.457 [−14.474, −14.410]** | **0** |

No-GC request saving is **−14.421% [−14.461, −14.412]**;
objects/request are **2,244.54 → 1,864.25**. The native `vm_trace` **function
self** extractor yields exactly zero in all 72 request deltas and all 36
operation deltas, including every arm, round and total/no-GC mode. These are
this interpreter run's own windows, not the separate YJIT diagnostic.

The operation adapter replays the real captured site against the installed
variant and its original `super_method`. Constructor, full per-hit checks,
fresh output, live URLs and real CSRF masking remain inside the price:

| Operation arm | Total Ir/form | Objects/form |
|---|---:|---:|
| Original A | 1,613,770.12 | 471 |
| Original B | 1,613,404.61 | 471 |
| Installed variant, including predicate | 342,480.05 | 85 |

Independently counted completed hits are **one per iteration and request**.
The guard-included paired budget is **1,271,062.10 Ir/hit**
[1,269,801.76, 1,272,502.72]. The paired request saving is
**1,265,147.20 Ir/request** [1,260,354.23, 1,266,696.28]; measured minus
predicted is **−5,914.90** [−11,648.99, −3,407.26]. This residual includes
setup/context work, not just interaction. Paired medians are not obtained by
subtracting the displayed arm medians. No unmodeled hit or fallback units
remain, so the new result has **`measurement_complete:true`** for total Ir.
No-GC budget remains unmodeled separately, as the export reports.

The run is an **accepted interpreter instruction saving**, not native
throughput or a production GC schedule. **Sealed-only, default/quarantine
unchanged; no promotion and no accepted YJIT non-regression cohort.** All
workers were released immediately after the run.

## Retained certification cache: untimed follow-up only

The active production pass currently retains **42 compiled source-inventory
files**. `FormScaffoldInventory.check` and `.template` need them during
activation; `FormScaffold.valid?` and `.render` do not read that cache. It
must not be discarded between inventory and template certification.

After the new cohort, a separate native **interpreter** process warmed 50
successful requests, then manually cleared only `@compiled` after activation
and forced full GCs. ISeq wrappers decreased **1,448 → 412**, and pool-0 live
slots **229,325 → 227,056** (the diagnostic itself retains its snapshot).
The next **50 requests still had 50 hits and zero fallbacks**; forcing the
epoch nonzero then produced an original-path fallback. Requests did not
repopulate the cache. The export retains the exact diagnostic source/result.

This supports releasing the boot-only cache after complete certification
without weakening per-hit checks. It does **not** establish that the cache
explains the entire separately reported ~9k extra pool-0 objects under YJIT.
At diagnostic publication no production cleanup had been implemented. No
accepted or rejected cohort was repriced.

### Post-measurement production release

The owner subsequently selected the safe release. Successful activation now
drops `@compiled` **after** source, inventory and template certification,
holder/epoch setup and variant installation have all completed. The source
compiler then stays closed for that process: later inventory/template/fact
requests refuse instead of recompiling lazily. A later public `setup` keeps
serving the original form and reports **"source inventory released; restart
to recertify"**. No per-hit check, `valid?` or `render` body changed.

The public build regression observes weak references to the real source
roots at the final template-certification boundary, then requires all of
them to be collectible after activation. It fails before this change with
"certification roots retained". On the changed runtime, the next **50 real
requests produce 50 hits and zero fallbacks**, a forced epoch change falls
back, and a later public setup also falls back with the release diagnostic.
The existing **192+192** raw observable comparisons, live-token replay,
renamed-app certification and custom-builder refusal remain in that test.

This is a **post-measurement memory-lifetime change**, not a repricing or
new speed claim. Both accepted interpreter exports and the rejected YJIT
export retain their original artifacts, numbers and fingerprints. The
remaining YJIT object-gap/v3 diagnosis is separate. No additional instruction
cohort ran for this cleanup; sealed-only status and no promotion remain.
