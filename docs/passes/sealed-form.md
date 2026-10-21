# Sealed new-comment form scaffold

**Positive interpreter price; sealed-only pilot, request result pending.**
The complete checked measurement specimen saves
**1,282,228 Ir/form** [1,280,077, 1,284,287], **−79.712%** of the original
form's work, and **392 objects/form**. One invocation on blog show implies a
conditional **about 14.7%** request budget against the separately measured
8.744 M interpreter baseline. It is not an achieved request saving, an
additive stacking claim, native throughput or promotion.

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
held**, not rejected or credited: warmup-method work is separate. An untimed
hit check and one finite **real-artifact** interpreter show cohort, after
worker release, decide the request result. This micro does not pre-authorize
a speed claim.

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
is absent; that skip is not form coverage. Production request pricing still
must use the exact published revision and a freshly source-pinned artifact.
