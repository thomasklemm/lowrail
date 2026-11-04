# Private Rails app with Inertia Rails: Rails main against 8-1-stable (2026-11-04)

What Rails main (the coming 8.2) changes for the private app of [the M0 study](private-inertia-app.md), per request.
Same privacy rules: no application source, names, dependency lists or test counts. Correctness on the same pins is
in [app-suites](../upstream/app-suites.md#private-rails-app-with-inertia-rails). Nothing here is posted upstream.

**Result.** Main executes 0.5–2.6% fewer interpreter instructions and allocates 8–18% fewer objects per request than
8-1-stable on all four workloads; every row passes its A/A. Active Record carries most of the saving; Active Support
and inertia-rails allocate more (the `try` regression PI3, and `Array#index_with`'s pair Arrays).

## Pins and method

* Rails 8-1-stable `6e09124217` and main `7a78da5a55` as `path:` gems, the same two bundles as the suite runs
  (they differ only in Rails and what main requires). Ruby 4.0.9, interpreter (`--disable-yjit`,
  `config.yjit = false`), test environment with eager loading, fixtures loaded into a template database and a fresh
  copy per worker, time frozen, one signed session cookie per worker.
* Workloads, all authenticated and checked for status 200 and identical response bytes on both trees: **A** an Inertia
  HTML page (full first load), **B** the same page's Inertia JSON partial reload of its deferred props, **C** a JSON
  dashboard (Inertia request), **D** a background job run with `perform_now`.
* [bench.md](../bench.md)'s fixed-heap Callgrind method with its `callgrind.c` client requests and `heap_windows.rb`:
  Valgrind 3.19 with the 512 MiB brk build (no overflow in any worker), 30 warmups, then N=0 and N=50 windows in
  alternating order, each after three full GCs; instructions per request = (Ir₅₀ − Ir₀) / 50. The heap floors are
  larger than bench.md's defaults because this app's heap after boot exceeds them: `RUBY_GC_HEAP_0..4_INIT_SLOTS`
  3,000,000 / 1,000,000 / 400,000 / 100,000 / 40,000, identical for every worker. No GC ran in any measured window,
  so total and GC-excluded counts coincide; only total mode was run.
* Six rounds × four layers (8-1 A and B, main A and B), each a fresh process, at most four at a time, seeded
  random order. A/A: the median of the B layer against the A layer, with a 5,000-resample bootstrap over rounds;
  the gate is a 95% interval inside ±0.5%. Main against 8-1 uses all twelve processes per tree.
* Allocations per request from `GC.stat` in the same windows. Allocation sites by Rails file:line from a separate
  native run per tree (`ObjectSpace.trace_object_allocations`, 10 requests after warmup, GC disabled), as in
  [merged-sum](../upstream/merged-sum.md).

## Per request, main against 8-1-stable (interpreter)

| Workload | Instructions 8-1 → main | Δ | A/A 8-1, main (95%) | Objects 8-1 → main | Δ |
| --- | ---: | ---: | --- | ---: | ---: |
| A Inertia HTML | 58.84M → 57.30M | **−2.62%** | −0.00% [−0.03, +0.05], −0.01% [−0.05, +0.03] | 12,932 → 10,667 | **−17.5%** |
| B Inertia partial reload | 39.96M → 39.42M | **−1.36%** | −0.00% [−0.02, +0.01], +0.01% [−0.01, +0.04] | 5,999 → 4,943 | **−17.6%** |
| C JSON dashboard | 58.40M → 57.96M | **−0.76%** | −0.01% [−0.04, +0.04], −0.00% [−0.04, +0.03] | 12,113 → 11,117 | **−8.2%** |
| D background job | 15.56M → 15.49M | **−0.45%** | +0.03% [−0.01, +0.05], −0.00% [−0.03, +0.01] | 3,941 → 3,386 | **−14.1%** |

Allocation A/A is 0.00% on every row (−0.01% for C on main). These are instruction and allocation counts, not
timings.

**YJIT: not measured.** bench.md's JIT-flat gate rehearses 200 cycles and then needs 2,000 quiet requests, each cycle
with three full GCs at the fixed heap. Natively, an 8-1 worker for B went quiescent after 2,000 requests with flat
counters across both measured windows, but took about four minutes; under Callgrind that is hours per worker, so no
YJIT cohort was run (orb-time rule). No YJIT row is claimed.

## Biggest movers

Allocation sites per request, net per Rails file (so moved lines cancel), main minus 8-1:

| File | A | B | C | D | Attribution |
| --- | ---: | ---: | ---: | ---: | --- |
| activerecord `connection_adapters/postgresql_adapter.rb` | −353 | −192 | −277 | −166 | `get_oid_type` no longer builds a type-map cache key per result column: our merged 408e6a3e29 ("Reuse type map cache keys for PostgreSQL result columns") |
| activerecord `relation/where_clause.rb`, `query_methods.rb`, `predicate_builder.rb`, `relation.rb` | −758 | −314 | −424 | −160 | the WhereClause and merger work of the 8.2 cycle, including our merged PRs ([merged-sum](../upstream/merged-sum.md)) |
| activerecord `associations/association.rb`, `association_scope.rb` | −340 | −71 | −50 | −50 | association scope building; not attributed |
| activerecord `postgresql/database_statements.rb` | −93 | −45 | −72 | −24 | not attributed |
| actionview `helpers/tag_helper.rb` | −92 | | | | not attributed |
| activesupport `core_ext/enumerable.rb` | **+605** | **+267** | **+469** | **+112** | `Array#index_with` builds a pair Array per element since 2b88dc1995 (byroot), kept on purpose after #59108/#59203 for embedded hashes up to eight entries; our open #59557 targets it on Ruby 4.1. Known, not new |
| inertia-rails `props_resolver.rb` | **+207** | +33 | **+235** | | `Object#try` allocates an empty keyword Hash per call since 2709a9f16d (kamipo): **PI3**, fix built |

Instructions by C function (interpreter Callgrind attributes to the VM, not to Ruby lines), per request on A:
fewer object allocations (`rb_wb_protected_newobj_of` −163k), complex argument setup (`setup_parameters_complex`
−254k, `vm_callee_setup_arg` −110k), regex matching (`match_at` −356k) and `vm_call0` calls (−185k); more bytecode in
`vm_exec_core` (+1.26M) and more instance-variable shape lookups (`rb_shape_get_iv_index_with_hint` +302k,
`vm_call_ivar` +148k). The other workloads move the same functions in the same directions.

PI3's fix removes about 200 objects per request on A and C, about a tenth of the gross increase above; its per-call
saving is in [the PI3 record](../upstream/app-suites.md#private-rails-app-with-inertia-rails).
