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
2. **Selective module freeze**: freeze only currently stateless UrlHelper and
   TagHelper modules/eigenclasses. Leave classes and mutable ancestors alone.
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
