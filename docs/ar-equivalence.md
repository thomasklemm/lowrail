# Active Record equivalence evidence

Executed 2026-10-20, Ruby 4.0.7, Rails 8.1.4, sqlite3 gem 2.10.1 and local
PostgreSQL 15. These are bounded differential checks, **not a proof of all
Active Record programs**. No new general relation-chain specialization is
claimed: most of this API deliberately stays on Rails.

## 1. Planning shadow

`LOWRAIL_SHADOW=strict` checks every actual AR specialization; `1` records
and warns but continues. Unset/`0` does not run an oracle. `lowrail verify`
sets strict in both child modes, as do the gem tests. There is no change to
the base runtime, loader, general guard, stats or templates modules.

The shared implementation is `gem/lib/lowrail/ar_shadow.rb`:

- **SQL readers:** compile the live final relation through Rails' Arel and
  adapter, and compare it with the cached statement immediately before its
  execution. Both use Rails' `_query_by_sql` query-name selection.
- **Preloads:** build Rails' real Branch tree, compute each live Batch
  frontier and its LoaderRecords keys, and compare the ordered statement
  groups with Lowrail's frontier. Advance the oracle using only rows fetched
  by the real loaders. It does not run a second query or instantiate a
  second set of records/callbacks.
- **Instantiation:** this pass skips no SQL planning. Compare its cached
  attributes builder's types/defaults with Rails' live recipe for each
  fast-path row, without recasting values or constructing another record.

Statements compare exact SQL, query name and ordered binds: attribute name,
type class, logical type, limit/precision/scale, before-cast value/class and
database value/class. Adapter `to_sql_and_binds` is called through a
planning-only connection; it never reaches `select_all`, the query cache or
`sql.active_record` instrumentation on the real connection. Guarded scope
inputs are still subject to the existing purity certificate. This is not a
safe way to execute arbitrary application scope lambdas a second time.

`Lowrail::ARShadow.counts` gives checks per pass;
`Lowrail::ARShadow.mismatches` retains the last 100 details. Every mismatch
is warned; strict also raises `Lowrail::ARShadow::Mismatch`. Diagnostics
contain SQL/bind values: use only where those values may be logged. Canary
mode is diagnostic, not an automatic repair/fallback mechanism.

The composition regression runs Rails-only, all passes with shadow off, and
all passes with strict shadow. Exact SQL events, query-cache hits, returned
records and callback counts agree, with real hits in all three passes.
Fault controls independently perturb SQL, a bind value, a bind type/limit
and the query name; all five are caught without emitting a SQL event.

### Cost (not an application speed claim)

`mise exec -- ruby bench/ar_shadow_cost.rb` uses five fresh YJIT processes,
alternating paired off/strict order, 200 warmups and 1,000 iterations, with
stats enabled in both. Same enabled passes and SQLite fixture in both modes:

| Operation | Shadow off µs median (range) | Strict µs median (range) | Objects off → strict |
| --- | --- | --- | --- |
| Scoped reader | 67.84 (62.92–71.47) | 96.30 (91.61–101.14) | 234 → 300 |
| Nested preload | 252.82 (243.28–261.87) | 447.14 (435.96–471.50) | 735 → 1,366 |
| Instantiate seven rows | 6.08 (5.89–6.44) | 7.98 (7.77–8.82) | 54 → 68 |

This is deliberately expensive test/canary instrumentation, not the default.

## 2. Seeded relation differential

`bench/ar_equivalence.rb` builds real runtime units against its loaded
models, installs the normal guards and activates all three passes. It does
not pretend to compile arbitrary relation chains. Rails and Lowrail run in
separate fresh processes against identical fixtures. Comparison includes
ordered SQL/name/bind values and types/cache flags, record classes and
attributes, loaded association contents, scalar terminators, and full
exception class/message (only object addresses are normalized).

The asymmetric schema has STI, polymorphic and through associations, enum,
JSON serialization, a custom string type, default/named scopes, scoped
collection and singular readers, projections and empty/zero-limit readers.
The grammar includes hash/array/range/exclusive-range/nil predicates,
`where.not`, `or`, `merge`, joins/left joins, includes/preload/eager_load,
order/reorder, limit/offset, select/distinct/group/having/unscope/none and
all requested terminators: `to_a`, `first`, `last`, `take`, `find_by`,
`exists?`, `count`, `pluck`, `ids`. Some generated combinations are invalid;
matching exceptions count separately, not as successful query coverage.

Each phase has 487 directed cases plus seeded random compositions. Four
fresh phases: boot; add a default scope after warming plans; change a column
type/reset schema after warming; and execute inside an `all_queries` scoping
block. Unsupported shapes and invalidated plans must remain on Rails.

### Executed coverage, seed 41231

| Adapter/mode | Chains | Observed SQL events (off, equal on) | Chains with SQL-plan hit¹ | Chains with instantiation hit | Matching exceptions |
| --- | ---: | ---: | ---: | ---: | ---: |
| SQLite, prepared | 9,948 | 13,345 | 180 | 5,818 | 3,453 |
| PostgreSQL, prepared | 9,948 | 13,183 | 168 | 5,760 | 3,786 |
| SQLite, unprepared | 3,948 | 5,261 | 90 | 2,055 | 897 |
| **Total** | **23,844** | **31,789** | **438** | **13,633** | **8,136** |

**Zero differential or shadow mismatches.** 30 chains hit SQL readers;
411 hit preload plans (three overlap). There are 23,406 chains without a
SQL-plan hit: not all are guard refusals—many use unspecialized terminators
or unsupported shapes. The report keeps the per-association build ledger,
separating eligible readers/edges from refusals and runtime hit coverage.
The fixture builds six eligible scoped readers and seven eligible preload
edges. This narrow eligible surface is the honest limit of today's passes.

¹ Union of reader and preload hits, not checks or query count. Shadow counts
also include the explicit pre-mutation warmups. SQL-reader hits occur only
in boot: added scope, changed schema and current scoping correctly stop
their warmed fast paths. The column mutation also disables preload plans.

Run from the Lowrail checkout:

```sh
CHAINS=2000 SEED=41231 mise exec -- ruby bench/ar_equivalence.rb > /tmp/sqlite.json
AR_EQ_PREPARED=0 CHAINS=500 mise exec -- ruby bench/ar_equivalence.rb > /tmp/unprepared.json
# This command drops/recreates eq_* tables: use ONLY a disposable database.
AR_EQ_DATABASE_URL=postgresql:///lowrail_equivalence CHAINS=2000 \
  mise exec -- ruby bench/ar_equivalence.rb > /tmp/postgres.json
```

`AR_EQ_RAILS` selects another installed Rails version; it does not bypass
audited-source/implementation guards. Reports are JSON and exit nonzero on
bugs. A failing isolated chain is deletion-minimized to a 1-minimal operation
list, retaining its base, terminator, cache choice, seed and mutation phase.
Use the reported JSON in a fresh worker, once with each LOWRAIL value:

```sh
LOWRAIL=1 LOWRAIL_SHADOW=strict mise exec -- ruby -Igem/lib \
  bench/ar_equivalence.rb --worker boot 41231 0 \
  '{"base":"EqWriter.find(1).preferred_posts","ops":[],"end":"to_a"}'
```

If isolation loses the failure, the report marks `requires_prefix: true`
and keeps the original index/case; rerun that seeded phase. It does not
falsely claim a minimal standalone repro of process-history-dependent bugs.
The minimizer deletes operations; it is not a global/schema/value shrinker.

## 3. Rails' own suite

**Feasible, with partial pass coverage.** Tested the Rails 8.1.4 source tag,
commit [c3466ea](https://github.com/rails/rails/commit/c3466ea00d7121798e3aa3144ffdf7174b81d8cb),
the 8.1 corpus version. The corpus also has an 8.2-alpha target; it was not
tested here. `bench/ar_rails_suite.rb` loads repository component sources
and gemspecs, loads test models, then builds/activates Lowrail's runtime
units against those models without a fake Rails application or weaker guards.

**Historical harness caveat (corrected by the standing
[Rails-suite gate](rails-suite.md)):** this experiment built plans inside
both test processes, including `LOWRAIL=0`. The numbers below describe those
schema-materialized processes, not an untouched Rails baseline.

With SQLite (`ARCONN=sqlite3_mem`), seed 41231, the old off and on both reported:

**9,240 runs, 31,031 assertions, one identical failure, zero errors, 44 skips.**

The failure is
`ViewWithPrimaryKeyTest#test_does_not_assume_id_column_as_primary_key`
(`Expected "id" to be nil`). It also occurred with lowering disabled because
the builder still ran there. It was **a harness side effect, not an existing
Rails failure**: the new no-build off process passes all 9,240 tests (44
skips), and separate-process construction preserves all 17 focused view-test
outcomes with genuine instantiation hits. The historical comparison was
**not a green Rails suite**. It compared all per-test results/failures including
multiplicities: 9,238 distinct printed identities, two duplicated Arel
identities, 9,240 identical observations. Subprocess reports remain separate.

- 620 instantiation units built; **68,862 row hits/checks**, 11,612 fallbacks,
  zero shadow mismatches in the full on run.
- SQL readers: no unit in the full suite. Broad Arel method inventory finds
  the suite's Minitest::Spec implementation and correctly refuses a custom
  planning implementation. A focused relation-file probe builds 32 eligible
  readers, but did not exercise a reader fast path.
- Preload: 771 eligible edges, **zero hits** in the full run. The shared
  unit has 546 unresolvable model facts from 42 generated HABTM class names
  (`HABTM_Articles`, etc.); their reported names are not root constants.
  This disables the entire unit safely. More full-suite planning coverage
  needs reachable model identity/constant handling and finer-grained units,
  plus a narrower certification of actual Arel planning dependencies—not
  disabling guards or ignoring failed facts.
- Repeated off controls identify 9,103 stable same-thread SQL digests; after
  the STI fix below all agree with on. The remaining 133 common identities
  have unstable off traces (including randomized data/thread activity).
  They are not SQL-equivalence evidence. Two other identities lack a trace
  in at least one control. Unlike the synthetic differential, these trace
  digests intentionally mask values/timestamps; use shadow for exact binds.

Use the corrected runner from the Lowrail checkout (SQLite CLI and native
gem build prerequisites required). It builds in a separate process and loads
the resulting manifest through the actual `RUBYOPT` setup path:

```sh
mise exec -- script/rails-suite --prepare
mise exec -- script/rails-suite --suites activerecord
```

The default glob includes general AR cases and SQLite adapter cases, not
other adapters or encryption performance benchmarks. Optional filename
arguments after `--` restrict the case files. `.build.json` records
units/refusals, and `.shadow.json` records checks/mismatches and duplicate-safe
outcome observations. The new gate disables SQL tracing; the masked SQL
numbers above are historical evidence, not fresh independent-process SQL
coverage. Compare observations, not only totals or the subprocess exit code.

## Defects exposed and repaired

1. **Real SQL mismatch: retained removed STI classes.** The epoch identity
   hash held model classes strongly, unlike Rails' weak descendant tracker.
   A removed temporary subclass remained in later `type IN (...)` queries.
   Minimal regression fails before the fix; weak identity keys allow GC.
   This accounts for all 130 reproducible cross-mode digest differences in
   the 9,103 stable Rails controls. No stable traced-SQL difference remains
   there, and no exact query/bind mismatch remains in the synthetic corpus.
2. **Pass composition disabled preload hits.** Preload facts/source
   certification rejected Lowrail's own relation wrappers when SQL readers
   were enabled. Validate and pin Rails' original definitions under only
   the exact known wrapper, while preserving wrapper invalidation facts.
   The regression requires genuine hits from all three passes and fails
   before this fix with zero preload hits.
3. **Epoch hook recursion after method stubs.** Alias-based restoration of
   an inherited hook made `super` enter another copy of itself. Skip copied
   wrappers by their owning ancestor chain. Repeated restoration regression
   fails before the fix; no application method call or invalidation is lost.
4. **Unsupported inventory could abort the build.** Unavailable table
   metadata and an abstract AssociationReflection now produce ledger
   refusals without losing other model units. Regression uses both cases.
5. **Tracing broke valid SQLite byte SQL.** A diagnostic regexp rejected
   invalid UTF-8 accepted by SQLite. Encode those SQL bytes losslessly for
   tracing; an executed-query regression retains distinct byte signatures.

Targeted AR/trace tests: **14 tests, 284 assertions, zero failures/skips**.
Rust: **30 unit + three integration tests pass**. Full gem suite:
84 tests, 872 assertions, three failures and 14 skips; the three URI memo
source-certification failures reproduce on unchanged HEAD with this orb's
installed URI gem. Optional corpus/gem dependencies explain the skips. They
are not suppressed or counted as passing.

## Limits

Scope lambdas and custom types can execute arbitrary Ruby; finite examples
cannot prove purity, concurrency behavior or equivalence. Existing
certification/guards, refusal ledgers and app-specific `lowrail verify`
remain required. Adapters, server settings, collation, prepared statements,
async execution, replicas/shards and Rails versions differ. PostgreSQL is
covered here by the synthetic grammar; the newer [standing Rails-suite
gate](rails-suite.md) also runs its general and PostgreSQL adapter cases.
No Rails 8.2-alpha, application corpus or system-test run is claimed here.
This provides more independent opportunities to falsify equivalence, not a
universal support or speed claim.

## Connection-identity audit (2026-10-20, Round 2)

The opt-in SQL reader had a correctness bug: after warming a scoped reader,
replacing the connection's visitor with a custom subclass could reuse SQL
compiled by the old visitor. Method definitions on the original visitor class
still matched. Strict shadow mode exposed the different SQL; without shadow
the stale SQL could execute. This is separate from the runtime-registry refactor.

Build now records the target's visitor class and certifies the actual visitor
hierarchy, including classes outside `Arel::`. Runtime requires that exact
class without singleton overrides and pins each cached statement to its visitor
object. A changed visitor falls back; it is not recertified lazily. Prepared
statement changes still rebuild their own cache entry. Older builds lacking the
visitor fact decline silently and need rebuilding. Tests compare exact query
events/rows for live method patches, custom visitor swaps, replacement nodes
and rebuilt custom planners; the visitor-swap regression fails before the fix.

An additional differential validation warmed each pass independently, then
changed one input in a fresh process. Seven changes × three passes = **21
off/on comparisons**: visitor subclass swap, visitor singleton patch, adapter
subclass/new pool, same-adapter/new pool, reading role, another shard, and the
public `unprepared_statement` window followed by restoration. The second
SQLite database contains deliberately different `OTHER-<id>` titles. Compare
exact rows, loaded associations, ordered SQL/binds and restoration, not just
exception-free completion. Before: 20 identical, reader visitor-swap differs
with two strict shadow mismatches. After: **21 identical, zero mismatches**.

| Cached pass | Visitor / prepared statements | Pool / adapter / role / shard | Result |
|---|---|---|---|
| SQL reader | Exact visitor class/object; prepared flag remains a cache key | Connection-identity cache, adapter check, global connection epochs, per-call role/shard checks | Swapped visitors now fall back; other cases already identical |
| Preload | Caches structural scopes/groups, not compiled SQL; fresh `where(...).load` goes through the live visitor/connection | Fresh Rails loaders use the current connection context; schema/reflection/type identities rechecked | Not affected in these seven cases; two warm and two subsequent completed preloads |
| Instantiate | Consumes an already-executed `ActiveRecord::Result`; caches attributes, not SQL | Establish/remove/connects-to epochs invalidate; role/shard keeps Rails' live schema/builder behavior | Not affected; 40 warm hits, then 40 more, or 10 call-level fallbacks after pool/adapter replacement |

This is a bounded identity audit, not a claim about arbitrary private-state
mutation, every adapter, or concurrent connection replacement during a query.
