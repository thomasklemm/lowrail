# Inertia configuration binding — opt-in

Measured 2026-10-20, Ruby **4.0.7 +YJIT**, unchanged `script/corpus` pins.
This implements [candidate 1](../candidates.md#1-inertiaconfig_bind), not a
memoized configuration. **Request-time improvement is unproven.** The native
A/A controls failed on all three apps; a positive method micro is not a
promotion gate.

## Contract and delivery

`inertia/config_bind` is a registry runtime pass, opt-in, alias
`inertia_config`. `Lowrail::InertiaConfigBuild.build(denied:)` boots under
the shared runtime-build driver and returns `{units, ledger}` without writing
files. It emits one `kind: method` unit for
`InertiaRails::Configuration#bind_controller`. Compiler delivery retains
method units even though they have no lowered source file.

The normal `def bind_controller(controller)` variant allocates a fresh exact
Configuration, attaches this controller and shallow-copies **current** option
values into a fresh mutable Hash. No values, controllers or proc results are
cached. Values keep their identities, including mutable Strings and lambdas.
Readers and their callable evaluation stay entirely in Inertia. This is why
the [memo pass refused the method](memo.md#public-inertia-analogue-and-argos):
caching its return would share mutable request-bound state.

Build certificates pin the gem configuration file (audited **3.21.2, 3.22.0,
3.23.0**), Active Support extraction source, pass implementation and builder.
Shared method facts cover construction, allocation, initialization, extraction
and the core methods these operations use. The original binder is retained
below the variant and checked by method identity. Native aliases must also
retain their original names. The per-call guard requires exact Configuration
and Hash classes, the same frozen schema constant, ordinary Hash
default/default-proc/identity policy and the **exact ordered keys**.
Compare from the trusted Symbol schema, with Symbol equality guarded: a
caller's asymmetric key `==` must not make an unknown key look canonical.
Unsupported inputs call `super`, preserving extraction, errors and subclasses.
Private/protected binders are refused both at build and before installation,
so prepending the public variant cannot expose a private original method.
Build and activation also require a frozen, exact Array of Symbols with no
singleton methods; the reserved constructor keyword `controller` cannot be
an option. A schema object with its own permissive equality is not trusted.

Public setters, `merge!` and `with_defaults` invalidate the shared guard state;
the next bind revalidates and copies the new live values. Direct options-Hash
changes are checked on every call; in-place value mutation is naturally live.
No application object is frozen to manufacture eligibility. Installation seeds
Guard's weak override tracker for preexisting singleton `class` stubs on
Configurations/Hashes; later definitions use the existing shared hooks. This
is a one-time boot heap walk, not a per-request scan. Foreign-ractor calls
retain the original method.

Ledger codes: `canonical_schema` (lowered), `gem_absent`,
`unsupported_gem_version`, `constructor_override`, `schema_changed`,
`denylisted` (refused). Runtime shape/class, Hash-policy, schema and method
declines count as fallbacks, not disk writes. They are deliberately exercised
by the gem regression; none occurred in the supported corpus requests/tests.
As with the existing Guard, hook-bypassing definition/visibility changes,
native replacement, refinements and ISeq/tracing inspection remain boundaries.
Concurrent mutation between guard and return is not transactional.

**Activation registration pending:** the base-cost report lifted the runtime
freeze while this experiment was finishing. Runtime migration step 4 owns
registration and the shared after-initialize helper. The published
`install(units)` only selects its unit; that helper must call `activate`.
There is no pass-private on-load/TracePoint wrapper in the published pass.
The local measurements used the temporary setup hook on local
`exp/inertia-config`; the final corpus gates use an explicit after-initialize
test shim after removing the private activation wrapper. Neither hook nor
shim nor changes to the five formerly frozen runtime files are published
here. The measured bind/guard bodies are unchanged. Until step 4 registers
it, main builds this unit but does not activate it. Integrated shared-helper
verification belongs to that pending registration, not the evidence below.

## Correctness gates

Build test configurations with
`target/debug/lowrail build .corpus/APP --passes default,+inertia/config_bind`.
Use `PARALLEL_WORKERS=1 LOWRAIL_SQL_TRACE=full SEED=41231`, with PostgreSQL,
SSR and browser setup from [the Inertia M0](../m0/inertia.md).

| App / suite | Identical outcomes | Identical ordered same-thread SQL | Binding hits | All-pass fallbacks |
|---|---:|---:|---:|---:|
| PingCRM, models + browser | 26 pass | 812 | 222 | 0 |
| Redprints, default RSpec | 50 pass | 692 | 36 | 0 |
| Redprints, explicit system RSpec | 12 pass | 260 | 216 | 0 |
| Starter, RSpec including system | 36 pass | 264 | 44 | 0 |
| real-blog, default tests | 21 pass | 125 | 0: gem absent | 0 |
| real-blog, browser | 2 pass | 55 | 0: gem absent | 0 |
| Campfire, default tests | 634: 632 pass + 2 existing libvips skips | 15,108 | 0: gem absent | 0 |
| Campfire, browser | 30 pass | 7,621 | 0: gem absent | 0 |

That is **811 identical outcomes / 24,937 SQL events / 518 binding hits**.
Other-thread SQL differences remain advisory: nine PingCRM browser tests and
one Campfire default test plus 14 Campfire browser tests; their ordered
own-thread traces match. The earlier hook-based run had 24,968 matched SQL
events (Campfire 15,109 + 7,651) and 12 Campfire browser advisories; these are
separate runs, not a SQL difference within either off/on pair. Commands are
PingCRM `bin/rails test test/models test/system --seed 41231`, Redprints
`bundle exec rspec --seed 41231` and `bundle exec rspec spec/system --seed
41231`, Starter `bundle exec rspec --seed 41231`; negative controls use
`bin/rails test --seed 41231` and explicit
`bin/rails test test/system --seed 41231` for browsers.

The subprocess gem regression runs all three supported Inertia versions and
plain/stale-build controls. It checks independent mutable return storage,
live identity/in-place changes, no eager lambda evaluation and distinct
controller contexts, the actual inherited `inertia_config` DSL, per-test
change/restore, Hash policies/order/subclasses/unknown-option errors,
configuration subclasses, constructor/binder redefinitions, schema changes
and preexisting/late reflection overrides. Frozen sources still produce
mutable results. Asymmetric-key and private-binding regressions were observed
failing before their fixes, as was an overridden schema equality; the final
targeted suite is 3 runs, 38 assertions, zero failures/errors/skips.
After pulling current main, the full gem suite is **90 runs,
1,501 assertions, zero failures/errors, six optional skips** (including the
two added Rails-checkout-dependent gates); Rust has
**30 unit + 3 integration** passes.

Production `bench/inertia_config.rb check` checks **all 12** cases: two routes
per app, each as HTML and Inertia JSON. It freezes time and records/replays
SecureRandom/OpenSSL entropy, checks entropy consumption and compares raw body
bytes without masking. All headers except measured `x-runtime` also match.
Authentication remains real; Starter HTML has live SSR. A separate 20-request
live census per case has zero fallbacks. This is pass-off original body versus
pass-on in the same initialized application, isolating the configuration
variant rather than conflating independent session entropy with its output.

## Guard-inclusive micro and expected effect

`bench/inertia_config.rb micro`: production app booted without Lowrail, normal
method dispatch on both arms, five alternating-order rounds of 50,000 binds,
2,000 warmups per arm. GC stays enabled; stats/profilers are off. The guarded
arm includes the complete installed cached method-fact and per-call shape
guard, not the earlier candidate's modeled `G[0]` check. Medians, not confidence
intervals:

| App | Original → guarded µs/bind | Objects/bind | JSON / HTML hits/request | Expected JSON / HTML saving | Objects saved JSON / HTML |
|---|---:|---:|---:|---:|---:|
| PingCRM | 5.606 → 2.261 | 5 → 3 | 5 / 5 | 0.50% / 0.46% | 10 / 10 |
| Redprints | 4.500 → 2.098 | 5 → 3 | 9 / 4 | 1.10% / 0.40% | 18 / 8 |
| Starter | 5.111 → 2.176 | 5 → 3 | 11 / 5 | 2.83% / 0.29% | 22 / 10 |

Expected effects use `(original_us - guarded_us) × hits / baseline_wall_us`,
with the **candidate survey's** JSON denominators 3361.16 / 1962.99 / 1140.35
µs and corresponding HTML denominators, not newly observed speedups. These
are below the preliminary 0.65% / 1.49% / 3.93% estimates because the real guard
costs more; the original method's timings also vary between runs. Initial
reflective Kernel dispatch allocated 11 objects/bind and was rejected; guarded
normal dispatch restores the intended two-object saving.

From a prepared corpus app, production/YJIT, `LOWRAIL=0`:

```sh
bundle exec ruby --yjit ../../bench/inertia_config.rb micro
```

The standard-setup byte-check command below requires the pending shared
activation registration; the local checks above supplied an after-initialize
test shim instead. The micro activates the pass explicitly and works now.
For byte checks, first build production with
`--passes default,-view/link_to,-route/path,+inertia/config_bind` (only the
binding pass), then run from the app with `LOWRAIL=1 LOWRAIL_STATS=/tmp/bind-stats` and
`RUBYOPT="-I/absolute/lowrail/gem/lib -rlowrail/setup"`:

```sh
bundle exec ruby --yjit ../../bench/inertia_config.rb check
```

The native [request-pairs harness](../bench.md) uses those same one-unit
production builds, independent off/off workers, all six standard runtime
layers, five fresh-process cohorts × eight alternating rounds, 0.5 seconds
per CPU-calibrated block, 400 warmups, GC enabled, stats/profilers off. JSON
routes: `/organizations`, `/proposals`, `/dashboard`. Keep all failed cohorts;
do not retry or widen the ±2% A/A gate. Nominal 95% bootstrap intervals below
use independent process cohorts, not requests. Negative deltas mean faster.

| JSON app | A/A CPU difference CI (%) | A/A wall difference CI (%) | Enabled wall delta % [CI] | Objects/request off → on |
|---|---:|---:|---:|---:|
| PingCRM | [−4.592, 2.265] | [−5.004, 3.013] | −0.421 [−4.981, 2.529] | 2522.52 → 2512.48 |
| Redprints | [−8.715, 7.533] | [−8.703, 7.543] | −0.850 [−4.807, 4.897] | 2892.48 → 2874.48 |
| Starter | [−4.984, 9.284] | [−5.015, 9.282] | −4.856 [−11.621, 0.405] | 1246.70 → 1224.59 |

All three controls fail for both CPU and wall time. These enabled deltas are
observations, **not accepted request effects**. Earlier pre-hardening cohorts
also failed their A/A controls; they are retained separately, not pooled into
these final results or retried to obtain green controls. No pass-specific
Callgrind instruction result is claimed. Micro allocation savings and live
hit counts do not establish a net request-time improvement. **Keep opt-in.**

## Upstream alternative

The [unsubmitted upstream draft](../upstream-drafts/inertia_rails.md) proposes
accepting the constructor's already-owned canonical keyword-rest Hash rather
than re-extracting it. Keeping `.new`/`initialize` dispatch makes that smaller
than a guarded allocate shortcut and could remove this cost for all users.
The draft's constructor probe is not an upstream performance result.

A separate upstream PR now covers the same cost:
[inertiajs/inertia-rails#437](https://github.com/inertiajs/inertia-rails/pull/437)
(cheaper configuration binding plus plain-data scans; open, not merged,
upstream CI not yet run). Its own synthetic production/YJIT pairs (no DB, 10
interleaved pairs, 10/10 faster each) save 38.6–143.3 µs/request CPU; that is
the PR's measurement, not a Lowrail result. If it merges, this pass's gain
disappears on the new version and the pass should refuse it as a stale fact.
