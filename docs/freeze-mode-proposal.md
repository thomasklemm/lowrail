# Bet D: method-only seal (exploration, WIP)

2026-10-21. Coordinator review draft, **not a default, runtime API, or support
claim**. No change to `lowrail/setup`, existing guards, sealed admission or
quarantined passes. The owner has authorized native YJIT direction-finding;
no Callgrind cohort is run here.

## Proposed contract

The application chooses a readiness barrier after production initialization,
eager loading, and explicitly declared natural request/job warmup. Before
traffic and background writers resume, Lowrail validates each unit's source,
method bodies, visibility, ancestors, native/JIT identity and lexical scope.
Missing facts refuse the unit without running application getters or code.

After the barrier the application promises no changes to the method tables,
visibility or ancestry on which admitted units depend. This includes gem
patches, stubs, reloads, saved reflective mutators, singleton overrides and
mutations initiated by helper arguments or callbacks. **Class-instance-variable
memos are legal.** This is not a promise to freeze whole Class objects. Mutable
configuration, constants, receivers, refinements and data graphs require
separate certificates or live checks; a method-only seal cannot certify them.

A detected violation permanently clears the process authorization flag,
before warning or invoking application mutation callbacks. Subsequent entries
use original dispatch, not a retry of an already partially executed operation.
An active specialization must recheck the flag after every live boundary
before a later skipped call. If that continuation cannot be made exact, it
must not be admitted. Logging is unconditional and identifies operation,
holder and source location. Never silently rearm the process.

Hard freeze failures cannot be undone. If an irreversible freeze was applied,
do not pretend deoptimization repairs the original path: fail worker readiness
or terminate the failed request and restart with the contract disabled.

## Three mechanisms, intentionally separate

1. **Whole-holder freeze**, existing `FreezeAudit`: complete ordinary/singleton
   ancestor closure is strong method enforcement, but forbids legal class-ivar
   writes too. Known `query_constraints_list ||= nil` and
   `connection_class ||= false` writes cannot be warmed away. Not the proposed
   method-only production contract.
2. **Selective module freeze**: freeze only currently stateless helper
   modules/eigenclasses (in these boots **TagHelper only**, not UrlHelper).
   Leave classes and mutable ancestors alone.
   A useful narrow compatibility probe, **not complete dispatch certification**.
   Inherited/core/receiver facts remain uncovered; no pass may infer otherwise.
3. **Method-only tripwire**, `bench/experiments/method_seal.rb`: a stock Ruby
   TracePoint observes mutation APIs and VM mutation callbacks, clears one flag
   and warns. No Module API is wrapped, preserving argument-less `private`.
   Aliased callbacks use `callee_id`; undefined callbacks require observing
   the NoMethodError raised *after* Ruby has installed the new method.

The tripwire is experimental observation, **not an enforcement certificate**.
It sees overridden callbacks even without `super`, saved Ruby mutators,
visibility and ancestry APIs, and tested undefined callbacks. Extensions that
mutate without Ruby events remain outside coverage. Refined lookup is not
ordinary method-table identity. Missing methods and no-op mutation APIs can
conservatively withdraw authorization. The first violation ends observation;
reports are first-break witnesses, not exhaustive lists of subsequent writes.
There is no claim of race-safe multi-Ractor publication or arbitrary in-flight
deoptimization. No production guard may be removed based on this alone.

## Rejected observer cost; singleton-seal improvement

At exploration source [2c420ad](https://github.com/thomasklemm/lowrail/commit/2c420ad05ea1c6d5619ba1ccf6d2ec1b8f7dca6c),
six finite alternating rounds, 500 warmup/300 timed requests/arm, CPU 2,
Ruby 4.0.7 / Rails 8.1.4 / native YJIT with stats enabled identically:

| Blog GET /articles/1 | off-A | off-B | Lowrail on | on + TracePoint |
|---|---:|---:|---:|---:|
| Mean of round request medians, ms | 2.961157 | 2.976779 | 2.446227 | 13.560401 |
| Objects/request | — | — | 1878.029 | 1949.354 |

A/A +0.598% [-2.803, +4.284]; tripwire/on **+454.306%**
[+429.296, +478.032], about **5.54×**. **NO-GO** as a production detector.
The existing sealed artifact's on/off difference is not new freeze-tier
performance credit. This experiment does not elide any existing unit guard.
YJIT remains enabled; activation invalidation delta is zero in every blog
worker. We have not established a deoptimization mechanism from that counter.
Raw compiled/side-exit/trace-leave counters are retained privately; missing
`ratio_in_yjit` is not interpreted as zero. Campfire finite comparison pending.

`singleton_seal.rb` is the one cheaper improvement: after callback-owner
preflight, freeze holder/ancestor eigenclasses and hook carriers. Class-ivar
writes remain legal; existing ModuleHooks/ObjectHooks clear a flag. This is
**a deliberately incomplete research detector, not an admission authority**.
It refuses the whole set before freezing if any effective mutation callback
has an unexpected owner. It cannot turn an open hole into a safe fallback.

Finite fresh-process probes (`singleton_seal_probe.rb`, Ruby 4.0.7):

| Mutation | Outcome |
|---|---|
| nil/false class-ivar memo writes | legal; flag stays enabled |
| ordinary def, remove_method, undef_method, saved pre-hook define_method | detected; flag withdrawn and warning emitted |
| custom holder method_added present at barrier | refused before freeze |
| install custom holder method_added after freeze | FrozenError, loud irreversible compatibility failure, not safe fallback |
| private/public/protected on existing method | **open hole**; mutation succeeds, flag remains enabled |
| module_function on existing method | FrozenError on eigenclass copy; visibility may already have changed; not safe fallback |
| normal include/prepend | detected before ancestry change |
| normal extend on holder | detected, then FrozenError |
| incoming prepend_features calls saved pre-hook primitive | **open hole**, ancestry changes with flag enabled |
| ordinary instance singleton override | detected |
| pre-existing suppressing instance singleton callback | **open hole** |
| new subclass suppresses singleton_method_added and method_added | **open hole** |
| new refinement method definition | detected conservatively by matching name |
| activate pre-existing refinement via using | **open hole**; lexical scopes require separate admission |
| C rb_attr via Fiddle with GVL | detected; does not prove arbitrary native VM internals covered |

Do not use Guard resets as an authoritative epoch after arbitrary live block
execution. Request-entry scans alone also miss mutations inside a block before
later skipped calls. Retain exact post-boundary dependency scans or refuse.
Freezing every live instance/eigenclass is not an acceptable substitute.

## Reproduction / work in progress

`method_seal_suite.rb` loads an app's own tests before the seal; production
readiness is **not** inferred from a test-environment run. Its five policies
are baseline, complete freeze, declared getter warmup + complete freeze,
selective helper freeze, and method tripwire. `method_seal_corpus.rb` launches
these in separate processes and retains private reports/outcomes/SQL/logs.
No app implementation/config is patched. Dependency overlays remain owned
by `script/corpus` and [compat.md](compat.md).

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/method_seal_test.rb
mise exec ruby@4.0.7 -- ruby bench/experiments/method_seal_corpus.rb \
  .corpus NEW_PRIVATE_OUTPUT blog-d campfire-r81 fizzy writebook casa codetriage
```

The native driver has six randomized rounds, independent off-A/off-B workers,
fixed warmup, allocations, wall/CPU timing and JIT counters. It never loads a
counter extension. The real Inertia resolver specimen elides repeated method
facts but retains a process flag/main-Ractor/actual-receiver check at recursive
entries. Request mode is explicitly an **admission-cost ablation**, not a new
optimized endpoint: all arms call the real Rails helper body through the same
wrapper. Neither can establish a supported production speedup.

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/method_seal_native.rb \
  micro "$PWD" NEW_PRIVATE_OUTPUT
mise exec ruby@4.0.7 -- ruby bench/experiments/method_seal_native.rb \
  requests .corpus/blog-d NEW_PRIVATE_OUTPUT /articles/1
```

**WIP limitations:** initial CASA harness runs loaded zero examples and are
invalid, not green. Initial CodeTriage runs have a local PostgreSQL connection
failure, not a contract finding. Both need corrected harness/setup runs.
An initial blog tripwire incorrectly classified unrelated test-class mutation
through Class; target matching is corrected, with a fresh run still required.
Initial smoke timings are not cohorts or prices. Full numeric results follow.
