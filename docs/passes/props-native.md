# Props native dispatch predicate: untimed preparation

2026-10-21. **Pricing only; no production props integration, promotion or
speed claim.** The ordinary-def Ruby-reflection shape still stops at its
[accepted interpreter loss](yjit-regression.md#corrected-interpreter-pricing-stop-at-price):
30,482.987 Ir of checks versus 4,445.573 Ir of unchecked iteration saving,
6.857×. Its YJIT micro remains cancelled. This is a separately requested
native alternative, not a rescore or retry of either historical cohort.

## Primitive and boundary

`Lowrail::Native.plain_hash_iteration?(object)` checks, on every invocation:

1. `CLASS_OF(object) == rb_cHash`: actual VM class, not `object.class`,
   `instance_of?`, `respond_to?`, or a materialized singleton class.
2. Both effective `Hash#each` and inherited `Enumerable#each_with_object`
   retain MRI's basic-definition flag.
3. Both effective methods are public. Basic-definition flags alone miss
   `Hash.send(:private, :each)` and protected methods. The additional
   `rb_method_boundp(rb_cHash, id, 3) == 1` checks exclude both.

There is no Ruby callback, receiver eigenclass creation, method-hook trust,
dispatch cache owned by Lowrail, or private VM-struct copy. `extconf.rb`
detects both C APIs; absent APIs make the predicate return false. The flag
argument is an **undocumented, deprecated MRI API**, not a portability
promise. The public visibility behavior is inspected in the pinned MRI
`vm_method.c` and witnessed on Ruby 4.0.7 revision `229531a6cf` and 4.1 preview
revision `2d08b5f42f`. New VMs need the same witnesses before support claims.

This certifies only the **audited unrefined iterator sites**, not an
arbitrary caller's lexical refinements. A caller-only `Hash#each` refinement
changes that caller's send, but neither the separately defined original
resolver nor the existing unrefined receiver guard. Tests preserve that
distinction rather than treating a refined top-level reflection as the
production guard. Registering an `each_with_object` refinement can clear the
basic flag and cause a conservative refusal even for an unrefined site.

The extension stays Ractor-unsafe: direct non-main calls raise
`Ractor::UnsafeError`. The pricing adapter retains the existing main-Ractor
check **before** consulting unit state or the primitive. It also retains
source activation, full unit/fact validation, statistics and a check at
**every** recursive traversal entry. Existing iterations are not restarted
after a callback mutates a later receiver. Production `inertia_props.rb`,
its builder and its emitted guard are unchanged.

The extension still loads symmetrically with Lowrail on/off, never compiles
at runtime, and uses the owner's per-Ruby/revision/platform output path.
Adding this function changes the whole binary and C-source certificate:
**recompile and rebuild artifacts; never reuse the previous native witness.**

## Witnesses and additional refusals

On both Rubies, `NativePropsTest` covers plain/frozen hashes, non-hashes,
subclasses, singleton/private singleton overrides, extend/prepend, both
private/protected methods, undef, method_missing/respond_to_missing?,
suppressed method_added, same-behavior Ruby redefinition, native aliases,
visibility mutation/restoration between traversals, refinements, and the
non-main-Ractor boundary. A warm identical-callsite N=0/N=1,000 allocation
control reports **0 / 0 allocations**, with the receiver still plain after
the calls. This is a hot-call observation, not a cold VM-metadata allocation
guarantee.

The interpreter lifetime fixture additionally passes **478 comparisons per
Ruby**, across Inertia 3.21.2/3.22.0/3.23.0: every discovered post-entry body
call boundary, suppressed receiver mutations, lazy callback mutation,
private iteration, subclasses, stale/malformed facts and a non-main Ractor.
Both native shapes preserve the original values, ordered effects and
once-only evaluation. Direct native witnesses pass **4 tests / 157 assertions**
per Ruby; existing native passivity/load tests pass **2 / 25**, and pricing
admission/refusal regressions **6 / 163** per Ruby. These are untimed checks.

Compared with the existing complete receiver reflection, the predicate also
refuses these otherwise accepted cases:

- An already materialized empty eigenclass, an unrelated singleton method,
  or an empty extension module. This deliberately avoids eigenclass lookup.
- Restoring `each` through a saved alias after redefinition, or reinstalling
  a captured native UnboundMethod via `define_method`: method equality may
  recover, while the BASIC flag does not. Direct `alias_method :each,
  :each_pair` remains accepted and is witnessed independently.
- The inherited-iterator refinement registration described above.

These are conservative refusals, not evidence of changed original behavior.
The unrefined differential receiver check must run **after** the native
decision: running it first creates the very eigenclass the candidate avoids.

## Exact operation census, not an Ir attribution

Both Rubies execute the same fresh-input whole resolver operation with
`guard_valid=true` and **two authorized entries per resolve**. Ten-operation
liveness companions give **20 authorizations / 0 fallbacks** in every checked
arm and zero counts in original/unchecked controls. The
[numeric export](props-native.json) retains both censuses, all arm liveness,
Ruby revisions and this orb's C-source/build/binary hashes.

| Receiver work per resolve | Existing complete Ruby check | Native predicate |
|---|---:|---:|
| `UnboundMethod#bind_call` dispatches | 12 | 0 |
| Of those: class / singleton_class / visibility / method lookup | 2 / 2 / 4 / 4 | 0 / 0 / 0 / 0 |
| UnboundMethod comparisons | 4 | 0 |
| Receiver class equality calls | 2 | 0 |
| Native predicate entries | 0 | 2 |
| Inside the two positive C entries | — | 2 class-pointer reads, 4 BASIC and 4 public-entry lookups |

The forwarded native calls are **inside** the twelve bind_call dispatches,
not twelve more independent operations. The two main-Ractor equalities,
active-unit hash lookups, Guard state access and cached fact checks remain.
No body/visibility requirement or recursive entry is elided.

The 30,482.987 Ir figure includes all checks and reflection side effects;
an operation census cannot determine its removable Ir fraction. In
particular the new C predicate still pays native method lookup, and all
outer checks remain. **How much of the 6.857× deficit closes is unpriced.**

## Reproduce without a measured window

```sh
# Build separately under each Ruby, from gem/.
mise exec -- rake compile
mise exec ruby@4.1.0-preview1 -- rake compile

# From the repository root; repeat with the preview Ruby for its witnesses.
LOWRAIL_STRICT_GATES=1 mise exec -- ruby -Igem/lib gem/test/native_props_test.rb --seed=1729
mise exec -- ruby bench/experiments/yjit_regression_test.rb --seed=1729
BENCH_JIT=0 mise exec -- ruby bench/experiments/yjit_regression.rb --census props_native checks_original
BENCH_JIT=0 mise exec -- ruby bench/experiments/yjit_regression.rb --census props_native native_checks_original
BENCH_JIT=0 mise exec -- ruby bench/experiments/yjit_regression.rb --liveness props_native native_split
BENCH_JIT=0 mise exec -- ruby bench/experiments/props_variant.rb --check-native /tmp/NEW-native-props-lifetime
```

The census is a disposable untimed process: its return observer targets only
the guard ISeq, and its global C-call observer only records calls while that
guard executes. Neither observer runs in a measured worker. Lifetime/pricing
source proofs now include the native C/build recipe and compiled binaries.
The harness regression forces the native predicate false and requires the
liveness gate to refuse, preserving fallback-priced-cohort protection.

The prepared `props_native` group has original paired A/A controls,
Ruby-reflection `split` and `checks_original`, native `native_split` and
`native_checks_original`, plus unchecked `each`. All build fresh nested
inputs identically. The coordinator has authorized one finite interpreter
cohort with **at most two workers**, after the untimed gates. It must price
`native_checks_original − original`, compare it against `original − each`,
and require the complete `native_split` candidate itself to win under
unchanged gates. No Callgrind window has run for this shape; no YJIT cohort
or production integration is authorized by this preparation.

## Strict-gate provenance

Both complete strict suites pass with the native candidate over
[9e61c52](https://github.com/thomasklemm/lowrail/commit/9e61c52): Ruby 4.0.7
**162 tests / 6,123 assertions**, one optional Rails profiling-bundle skip;
Ruby 4.1 preview **162 / 5,155**, that same skip plus the three explicitly
Ruby-4.0-only cold-blog, sealed-link and sealed-form fixtures. After pulling
the audit/evidence additions through
[315d56f](https://github.com/thomasklemm/lowrail/commit/315d56f), Cargo passes
again and both Rubies pass the combined native/new freeze-audit gates
**11 / 205**, plus harness **6 / 163**. The native source/binary fingerprints
and both 478-case lifetime proofs remain identical. The full-suite counts
above do not silently include the five subsequently added freeze-audit tests.

The primary cold-blog gate uses the native owner's canonical source export
(archive SHA-256 `ad1ccb8cc926b06e0a20643cc8975cf37fd20c5d74839195bc5c6e7c819dc761`),
with source pin `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`
and lock pin `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
Extract into a new corpus directory, install with the frozen lock, and use a
disposable `LOWRAIL_TEST_CORPUS_ROOT`; do not overwrite existing sources or
change shared entropy pins. Its `real-blog-r4` must be a **physical copy**:
the observed-run recorder filters expanded root paths while Rails reports
real source paths, so a symlink overlay yields no controller samples. That
fixture mistake was reproduced and corrected; no recorder/runtime code was
changed, and the corrected gate passes **1 / 11** before the full rerun.
