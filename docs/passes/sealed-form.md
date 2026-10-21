# Sealed new-comment form scaffold

**Accepted interpreter request saving: −14.405% [−14.451, −14.374].**
The real-artifact blog-show cohort uses **8.747394 → 7.486001 M Ir/request**.
This remains a `sealed_only` pilot: **no default change or promotion**, and no
accepted YJIT non-regression cohort. See the pinned request result below.

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

The guarded tier and seven-pass quarantine remain unchanged. **YJIT is
held**, not rejected or credited: warmup-method work is separate. The finite
**real-artifact** interpreter show cohort below supplies the request result;
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
is absent; that skip is not form coverage. Fresh orbs also need the disposable
blog production SQLite fixture populated with Articles 1/2/3 and 2/1/0
Comments, not just a test/development schema. A missing production database
correctly refuses inventory; do not relax eligibility to make the test pass.
The test copies that fixture before changing anything. Production request
pricing must use the exact published revision and a freshly pinned artifact.

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
