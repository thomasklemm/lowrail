# Inertia prop tuple iteration (`inertia/props`)

Opt-in only. The allocation survey's conditional `props` micro is not a
certificate: this pass pays for actual receiver checks. No prop values,
metadata, controller data or resolved results are cached across calls.

```sh
lowrail build APP --passes default,+props
# Full name: default,+inertia/props. Never included by default.
```

## Certificate and delivery

The single runtime builder audits inertia_rails **3.21.2, 3.22.0 and 3.23.0**
by full `props_resolver.rb` SHA-256, the private method's owner, name and
source position, and native `Hash#each` / `Enumerable#each_with_object` facts.
Unknown gems, changed source, resolver/iteration overrides and denylisted
targets refuse. Missing Inertia records `gem_absent`, including blog and
Campfire. Stable ledger reasons are `gem_absent`, `gem_version`,
`source_changed`, `resolver_override`, `iteration_override`, `denylisted`.

The builder emits the gem source through the existing runtime-source/ISeq
seam. It changes only `deep_transform_props`' iterator:

```ruby
# Original, preserved as fallback:
props.each_with_object({}) do |(key, prop), transformed_props|
  # original prop body
end

# Certified arm:
transformed_props = {}
props.each do |key, prop|
  # same prop body, in the SAME lexical class/module scope
end
transformed_props
```

The name, signature and private visibility stay unchanged. The original body
and fallback line numbers remain in place; the specialized arm is on the
definition line. There is no prepend wrapper capturing an old resolver, no
replacement metadata/serializer implementation and no `each_pair` assumption.
Two-argument native Hash iteration avoids the otherwise hidden tuple Arrays.
Source/loader/compiler mismatches retain the original ISeq. The runtime
activates only after initialization with matching gem/builder/runtime sources.

## Mutation boundary: no entry permission survives application code

Each traversal independently checks an ordinary Hash's **actual** effective
`each_with_object` and `each` bodies and public visibility, through bound core
reflection methods. This residual is unconditional even with a warm shared
guard; suppressed mutation hooks, singleton overrides and visibility changes
cannot reuse a stale iterator authorization. Hash subclasses fall back.

Once the native iterator starts, its body remains active just as the original
`each_with_object`'s `each` does. Everything inside the loop remains normal live
Ruby dispatch: key/path conversion, serializer detection and serialization,
shape/partial checks, recorder callbacks, scroll intent, metadata, keep/rescue
predicates, both lazy evaluations, recursive Hash/Array traversal, result
insertion, `as_json` and error reporting. A mutation does not restart the
iteration or replay any of these effects. A later recursive traversal takes
its own fresh receiver/body/visibility check. Changes to other helpers or
constants are observed by the unchanged Ruby body, not an inlined boot copy.

Permanent tests in `gem/test/inertia_props_test.rb` inject a suppressed-hook
mutation of a later nested Hash's iterator after entry, across all three
supported gem versions. Original-source discovery enumerates each exercised
body callsite, testing its first and last occurrence rather than just one
occurrence per method name. This includes both sides of lazy unwrapping,
post-evaluation serialization/scroll intent and the rescue continuation.
They compare public `resolve` results, metadata and ordered effect/recorder logs
against original execution, require a visible marker on a subsequent traversal
and once-only lazy/serializer evaluation, and cover changed `each`, private iteration,
Hash subclasses, partial/except/once/deferred/dotted props and fresh results.
Stale/malformed certificates and non-main Ractors use the original body;
the latter declines before reading any unshareable guard or Stats state.
The regression matrix is not a claim to support TracePoint/ISeq introspection
as an optimization-invariant API; it uses tracing only to inject mutations.

## Gates and request measurement

Final-source gates:

- `cd gem && mise exec -- rake test`: **100 runs / 4,170 assertions**, zero
  failures/errors, seven skips. The props tests run all three supported gems,
  including the previously failing malformed-certificate and Ractor cases.
- `mise exec -- cargo test`: **34 unit + three integration tests** pass.
- Benchmark seam contracts: `bench/request_pairs_test.rb` **10 / 70** and
  `bench/pass_test.rb` **16 / 157**, zero failures/errors/skips.
- Builder refusal probes return no units/files for missing resolver methods,
  missing/private `Hash#each`, denylisting and unknown gem versions.

Final-source five-app verification uses `default,+props`, seed **41231**,
full SQL traces and serial workers. All **779 outcomes** and own-thread
ordered SQL digests/counts are identical, with zero unstable SQL exclusions.

| App / gem | Outcomes | Queries | Props hits / fallbacks |
|---|---:|---:|---:|
| Real Blog / no Inertia | 21 | 125 | 0 / 0 (`gem_absent`) |
| Campfire / no Inertia | 634 (2 matching skips) | 15,108 | 0 / 0 (`gem_absent`) |
| PingCRM / 3.23.0 | 26 | 812 | 271 / 0 |
| Redprints / 3.21.2 | 50 + 12 system | 692 + 260 | 14 + 54 / 0 |
| Starter / 3.22.0 | 36 | 264 | 30 / 0 |

PingCRM retains nine other-thread SQL differences, advisory because thread
interleaving is not ordered by this gate. None was suppressed. Campfire's
separate browser suite was not included; its 634-test suite refused this
pass rather than claiming props coverage. Redprints' system gate ran in the
installed Chrome. The numeric export retains per-test outcomes, own-thread
digests and advisory maps, not just totals.

### One finite request cohort per mode; no replacements

Ruby **4.0.7**, Rails **8.1.4**, inertia_rails **3.22.0**, Starter production
`GET /dashboard` as an authenticated Inertia JSON request. The reference is
no Lowrail setup; `default` here means only the explicitly selected props
pass, **not default promotion**. Exactly six randomized rounds per mode,
50-request windows with N=0 subtraction, jobs=4, fixed heap floors
**1,000,000 / 250,000 / 100,000 / 20,000 / 10,000**, seed 41231. The shared
[c9d2397 protocol](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0)
and its request/heap/JIT worker files were unchanged. Controls include off-A,
off-B, selected, disabled, empty and missing builds, warmed heap observers,
post-GC settling, actual JIT state, three flat warmup windows and no
compilation/invalidation inside measured windows.

**Both cohorts are rejected as certification of the published runtime.**
Their numerical A/A, heap and JIT gates passed, but they preceded two safety
fixes: malformed activation certificates must decline instead of raising,
and non-main Ractors must decline before reading main-Ractor state. The
builder also now refuses missing/private iterator methods before reflection.
These failures were reproduced, fixed and covered by the final correctness
gates. The runtime/builder fingerprints changed after measurement. The
original machine verdicts remain `accepted` inside the export, with an outer
`rejected / final_runtime_fingerprint_changed` disposition; neither cohort is
silently relabeled as a measurement of the final code. **No retry or
replacement cohort was run.** The published runtime has no accepted request
performance result and no speed claim.

The retained **pre-fix diagnostics** are losses, not gains. Values are arm
medians; percentage deltas and signed savings are paired estimates, not
subtractions of displayed medians.

| Mode | Off Ir/request | Props Ir/request | Paired increase, 95% CI | Objects off → props |
|---|---:|---:|---:|---:|
| Interpreter | 5,117,652.93 | 5,162,500.57 | +0.873% [+0.788, +0.956] | 1,236.89 → 1,254.49 |
| YJIT | 3,263,251.03 | 3,294,592.10 | +0.976% [+0.845, +1.068] | 1,241.05 → 1,258.19 |

Signed total savings/request were **−44,692.51 Ir [−48,929.90, −40,360.20]**
interpreter and **−31,851.75 [−34,818.72, −27,598.26]** YJIT. GC-excluded
increases were +0.922% [+0.776, +0.983] and +1.091% [+0.970, +1.171]. Total
A/A was +0.023% [−0.137, +0.069] interpreter and −0.029% [−0.168, +0.018]
YJIT; both GC-excluded controls also contain zero within ±0.5%. Heap page
capacities matched and all actual-JIT/warmup/window checks passed. Each mode
recorded **4 props hits/request, zero fallbacks**. These are Callgrind
instruction counts, not native throughput measurements or a per-hit budget.

The conditional micro's 74 → 61 objects and 5,894 YJIT Ir/call saving exclude
this full receiver certificate. The guarded draft instead allocates more at
request level; no tuple-pool ceiling is credited as a net saving. The pass
remains opt-in for experimentation and is recorded in the
[Stacking backlog](../DECISIONS.md#stacking-backlog), with no promotion or
assumed additive benefit. Any later guard-cost change requires new exactness
gates and a newly declared finite measurement, not selection from these rounds.

[props-results.json](props-results.json) preserves both cohorts' arm/window
counts, heap capacities, JIT histories, harness/runtime/lock/manifest hashes,
signed estimates, rejection reasons, final source hashes and final verify
reports. Private raw evidence is under `/tmp/lowrail-props-{interpreter,yjit}`
and `/tmp/lowrail-props-gates`; no headers, cookies or response bodies are
published.

### Reproduction

Prepare pinned corpus dependencies/production assets, PostgreSQL and Starter
SSR using [bench.md](../bench.md). Keep authenticated headers private, as
generated by `bench/inertia_setup.rb`. These commands declare **new** cohorts
of the checked-out code, not replacements for or reproductions of the rejected
draft's fingerprints:

```sh
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 LOWRAIL_BUILD_JIT=0 mise exec -- \
  target/debug/lowrail build .corpus/react-starter-kit --env production --passes default,+props
BENCH_JIT=0 BENCH_JOBS=4 BENCH_HEADERS="$(cat .corpus/react-starter-kit/tmp/m0/headers-json.json)" \
  mise exec -- target/debug/lowrail bench .corpus/react-starter-kit --pass props \
  --path /dashboard --out /tmp/NEW-props-interpreter
# Rebuild with LOWRAIL_BUILD_JIT=1, then use BENCH_JIT=1 and a NEW output dir.

RAILS_ENV=test LOWRAIL_BUILD_JIT=0 mise exec -- target/debug/lowrail \
  build .corpus/react-starter-kit --env test --passes default,+props
RAILS_ENV=test SEED=41231 SPEC_OPTS='--seed 41231' LOWRAIL_SQL_TRACE=full \
  mise exec -- target/debug/lowrail verify .corpus/react-starter-kit -- \
  bundle exec rspec --seed 41231
```

## Ordinary-def follow-up: stopped at price (2026-10-21)

The separate exact-guard ordinary-def specimen is **stopped at price**, not
implemented as a pass. One valid corrected-code interpreter micro on
[fb07512](https://github.com/thomasklemm/lowrail/commit/fb07512d06ca217ec1fdb1e49e0cd24ab4fa8345)
loses **+22.594% total Ir [22.496, 22.731]** and **+22.614% GC-excluded
[22.469, 22.739]** versus original. Its unchanged exact checks cost
**6.857× [6.758, 6.912]** the available unchecked iteration saving. The inline
guarded control loses +22.558% total [22.447, 22.659]; method separation does
not fix the deficit. All micro controls and pre-window positive liveness
pass, with no fallback pricing. These fresh-input micros are not re-scores
of the earlier request results.

The first format-1 micro remains **invalid fallback/incomplete-check pricing**;
it is not promoted to valid evidence by the corrected cohort. The props YJIT
micro is **cancelled before starting**, not merely held. No retry, promotion,
weaker guard or production reflection/delivery certification follows. The
existing opt-in pass is unchanged. A cheaper VM-owned dispatch certificate
is a backlog question only, without implementation or pricing.
[Full pins, both metric intervals, liveness, controls and numeric export](yjit-regression.md#corrected-interpreter-pricing-stop-at-price).
