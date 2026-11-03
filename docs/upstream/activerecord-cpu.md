# Active Record CPU time per query (bet A1)

Allocation censuses ([5](rails-main-census-5.md), [PG](pg-census.md)) left little on the query path to remove. This
bet profiles CPU self time instead: where Active Record, Active Model and Arel spend time per query in real apps, and
whether exact Rails changes make it measurably faster.

**Result.** Self time is flat: no Active Record, Active Model or Arel frame takes more than about 1% of samples on
average across ruby-bench and six census apps. The cost is in many small per-query steps. Two clusters had a clear,
exact cause that no open PR covers, and each became a candidate. Both are one-commit branches on canonical main
[`e64b660612`](https://github.com/rails/rails/commit/e64b660612fa582a4a89a91bc002269b29426e76) and pass the
Active Record SQLite and PostgreSQL suites with `RAILS_STRICT_WARNINGS=1`, plus RuboCop.

| # | Branch | Commit | What | ruby-bench instructions, interpreter (railsbench / shipit / lobsters) | YJIT | Allocations (census, 56 workloads) |
| --- | --- | --- | --- | ---: | ---: | --- |
| C3 | [`thomasklemm/load-from-sql-attribute-types-once`](https://github.com/thomasklemm/rails/tree/thomasklemm/load-from-sql-attribute-types-once) | [`2fd04c4ade`](https://github.com/thomasklemm/rails/commit/2fd04c4ade032a97018e5ad489e2b4f6ff8cf800) | `_load_from_sql` reads `attribute_types` once instead of once per column type key | **−1.04% / −4.12% / −1.03%** | −0.68% / **−5.29%** / −0.60% | unchanged (as expected) |
| C2 | [`thomasklemm/association-scope-lazy-alias-tracker`](https://github.com/thomasklemm/rails/tree/thomasklemm/association-scope-lazy-alias-tracker) | [`fcfadc0ee8`](https://github.com/thomasklemm/rails/commit/fcfadc0ee84f1b53534a6407e10cf966d00c0d0d) | association scopes build the `AliasTracker` only for through chains | −0.09% / **−2.64%** / −0.28% (with open #59212: −0.01% / −0.78% / +0.07%) | +0.08% / **−1.82%** / −0.13% (with #59212, shipit: −1.09%) | 36 / 42 workloads −1 or more (A/A 16 / 14), median −2.0 / −3.3 |

Instruction counts are Callgrind's, one measured iteration after warmup with GC off in the window (see
[Method](#method)); A/A (same tree twice) is −0.002% / +0.021% / −0.151% in the interpreter and +0.056% / +0.043% / −0.045% under YJIT; C2 and C3 together are −0.93% / −6.75% / −1.08% (interpreter), additive. Interpreter / YJIT for the census columns.
Wall time on ruby-bench in this orb could not resolve effects of this size (A/A spread up to 4%; see
[Wall time](#wall-time)), so instruction counts are the primary evidence here and wall time is reported as a check.

Neither candidate has been opened as a PR. Drafts in the [DECISIONS](../DECISIONS.md) short form are at the end.

## Where the time goes

### ruby-bench (railsbench, lobsters, shipit)

stackprof 0.2.28 in wall mode at 200 µs with raw stacks, after warmup (interpreter 3 iterations then 10 profiled;
YJIT 15 then 20). The apps are single-threaded and CPU-bound on in-process SQLite, so wall samples are CPU samples;
stackprof's CPU timer fires at only 250 Hz in this orb (gVisor), against the requested 5 kHz in wall mode.
"Self" charges C functions (Hash#fetch, Array#hash …) to the Ruby frame that called them; GC samples are separate.

| Profile | Samples | AR/AM/Arel on stack | AR/AM/Arel self | GC |
| --- | ---: | ---: | ---: | ---: |
| railsbench interpreter / YJIT | 170,872 / 147,079 | 69.5% / 63.4% | 18.1% / 13.7% | 5.2% / 9.7% |
| lobsters interpreter / YJIT | 99,913 / 116,244 | 90.9% / 89.5% | 41.8% / 33.7% | 2.2% / 4.1% |
| shipit interpreter / YJIT | 197,571 / 203,224 | 94.4% / 89.4% | 66.0% / 53.0% | 3.8% / 8.7% |

Self time by area (% of all samples, mean of the six profiles; full table in
[rank-rubybench.tsv](data/activerecord-cpu/rank-rubybench.tsv)):

| Area | Mean self | Range |
| --- | ---: | --- |
| attribute set, type casting (LazyAttributeSet, IndexedRow, `cast_value`) | 6.4% | 3.7–8.5 |
| connection, query cache, instrumentation | 6.1% | 3.5–10.3 |
| associations, reflections | 5.0% | 0.0–10.9 |
| result, instantiation (`Result`, `_load_from_sql`, model schema) | 4.7% | 1.9–8.6 |
| query methods, `build_arel` | 2.9% | 0.0–5.8 |
| Arel (AST and `to_sql` visitor) | 2.3% | 0.0–4.2 |
| where clause, `Merger`, spawn | 2.2% | 0.4–5.0 |
| relation core, delegation | 2.1% | 0.0–3.8 |
| adapter execute (Ruby side) | 1.9% | 1.5–2.5 |
| scoping, default scope | 1.5% | 0.6–2.4 |
| predicate builder | 0.9% | 0.0–1.8 |
| statement cache | 0.2% | 0.0–0.3 |

Top frames by self time (mean %, interpreter and YJIT profiles of the three apps):

| Frame | Mean | Max | Note |
| --- | ---: | ---: | --- |
| `QueryCache::Store#compute_if_absent` | 1.01 | 2.07 | hashes `[sql, binds]` twice per lookup; with `QueryAttribute#hash` 0.30, `Attribute#hash` 0.26, `Type::Value#hash` 0.24 ≈ 1.8% |
| `Result#column_types` | 0.90 | 2.16 | builds a Hash of every column by name and by index, per result |
| `LazyAttributeSet#fetch_value!` | 0.78 | 1.02 | #59141 / #58002 territory |
| `Querying#_load_from_sql` | 0.77 | 1.64 | mostly the `reject` over `column_types` → **C3** |
| `SQLite3::DatabaseStatements#perform_query` | 0.60 | 0.68 | |
| `IndexedRow::Mutable#fetch` | 0.44 | 0.64 | |
| `Relation::Merger#merge` | 0.40 | 1.12 | |
| `Delegation::ClassMethods#create` | 0.38 | 0.89 | |
| `ConnectionHandling#connection_specification_name` | 0.33 | 0.73 | superclass walk per pool lookup |
| `Scoping::Default::ClassMethods#has_default_scope?` | 0.32 | 0.55 | `method(:default_scope).owner` per `find` |
| `Arel::Visitors::Visitor#visit` | 0.31 | 0.61 | the `send` itself (bet J1) |
| `ModelSchema#schema_context` + `schema_loaded?` + `attribute_types` | 0.79 | 2.14 | mostly called from the `reject` in `_load_from_sql` → **C3** |

Inclusive time of subsystems ([inclusive-rubybench.tsv](data/activerecord-cpu/inclusive-rubybench.tsv)): the
association scope build (`Association#scope`, `AssociationScope`) is 3.1% / 2.6% of lobsters and 19.7% / 15.8% of
shipit; resolving the model's pool (`ConnectionHandling#connection_pool`) 1.0–3.2% outside railsbench, a third of
it from `Relation#alias_tracker` and from `adapter_class` in `preprocess_order_args`; per-query connection checkout
and checkin 1.0–4.8%; `to_sql_and_binds` 2.4–3.8%; the predicate builder 2.6–4.6%.

### Census apps, SQLite and PostgreSQL

Blog, Campfire, Fizzy and Redprints CFP (SQLite), PingCRM and CodeTriage (PostgreSQL 15), set up with
`script/census setup` on the same Rails commit and run through census 4's workloads
([census_prof.rb](../../bench/upstream/arcpu/census_prof.rb)): 50 warmups per workload, then all workloads
round-robin 40 times with the profiler paused during side-effect resets. PostgreSQL samples include waiting on the
server (charged to `perform_query`).

The picture is the same, flatter still: the largest Active Record frame other than the adapters' `perform_query`
is `compute_if_absent` at 0.43%; association and reflection self time 4.7%, attribute sets 4.6%, connection and
query cache 4.2%, result and instantiation 3.0% (means over twelve profiles,
[rank-census.tsv](data/activerecord-cpu/rank-census.tsv)). The association scope build is 2.1–11.3% inclusive
(Fizzy 10.5% / 11.3%) and pool resolution 0.3–2.0% ([inclusive-census.tsv](data/activerecord-cpu/inclusive-census.tsv)).
`Result#column_types` is smaller here (0.14–0.35% inclusive) than on shipit, whose tables are wider.

## Candidates

### C3: read `attribute_types` once when loading records

`_load_from_sql` removes the result's column types that the model already has:

```ruby
column_types = column_types.reject { |k, _| attribute_types.key?(k) }
```

`Result#column_types` holds each column twice (by name and by index), so the block calls `attribute_types` 2N times
per result. Until #58437 / #58578 (July–August 2026, Shopify's schema context and Ractor work) `attribute_types` was
`@attribute_types ||= …`; it now goes through `schema_context`, `schema_loaded?`, the schema's `attributes` and
`types` on every call. On SQLite and PostgreSQL every result carries column types (MySQL's don't), so every
instantiating query pays it. The change reads `attribute_types` once; the rejected Hash is identical.

Per call (12-column model, SQLite in memory, Ruby 4.0.7; [micro.rb](../../bench/upstream/arcpu/micro.rb)), instructions
(Callgrind, GC off) and time (interleaved processes, median):

| Per call | Interpreter, instructions | YJIT, instructions |
| --- | ---: | ---: |
| `Post.find(1)` | 442,379 → 413,373 (−6.6%) | 221,754 → 213,301 (−3.8%) |
| `Post.where(author_id: 1).limit(5).to_a` | 746,713 → 717,897 (−3.9%) | 360,174 → 351,231 (−2.5%) |
| `_load_from_sql`, 1 row | 142,722 → 113,503 (−20.5%) | 83,835 → 75,485 (−10.0%) |
| `_load_from_sql`, 10 rows | 311,067 → 281,215 (−9.6%) | |

MICRO_C3_TIME

ruby-bench instructions per iteration (interpreter): railsbench 5.1168 → 5.0634 G (−1.04%), shipit 6.1304 → 5.8778 G
(−4.12%), lobsters 4.1731 → 4.1301 G (−1.03%); A/A −0.002% / +0.021% / −0.151%. YJIT: railsbench 2.8055 → 2.7864 G (−0.68%), shipit 3.2078 → 3.0381 G (−5.29%), lobsters 2.8890 → 2.8716 G (−0.60%); A/A +0.056% / +0.043% / −0.045%. Census
allocations unchanged (11 / 15 workloads moved ≤ −1 against the A/A's 16 / 14), SQL changes within the A/A's set.

**Overlap.** Open #59141 (tenderlove, attributes stored in an Array) deletes this block: types move into its
`RowLayout`. Measured the same way it saves 2.85% / 9.16% on railsbench / shipit, so C3 is roughly half of #59141's
shipit gain as a one-line change, and becomes moot if #59141 merges. A variant that also skips the index keys
(`c3b`: iterate `result_set.columns`) saves more per call (one-row load −32% vs −23% in time) but changes the
contents of the additional-types Hash and overlaps #59141 further; not pursued. On ruby-bench `c3b` is −1.27% / −5.19% / −1.24% (interpreter) against C3's −1.04% / −4.12% / −1.03%.

### C2: build the association alias tracker only for through chains

`AssociationScope#scope` passes `scope.alias_tracker` to `get_chain`. `Relation#alias_tracker` resolves the model's
connection pool (`connection_handler`, `connection_specification_name`, `current_role`, `current_shard`) and calls
`pool.with_connection`, which checks a connection out and back in when none is leased (the normal case since Rails
7.2), to read `table_alias_length`. `get_chain` uses the tracker only for the reflections after the first, so for a
direct association it is never used. `get_chain` now takes the relation and builds the tracker when it reaches the
second reflection, with the same arguments. A direct association no longer touches the connection while building its
scope; the query that follows still does.

Per call (same micro; each `fresh_*` case instantiates a new `Post` first):

| Per call | Interpreter, instructions | YJIT, instructions | Interpreter, with #59212 |
| --- | ---: | ---: | ---: |
| `post.author` | 692,045 → 646,861 (−6.5%) | 297,595 → 281,710 (−5.3%) | 454,362 → 454,319 (0.0%) |
| `post.comments.to_a` | 873,313 → 828,050 (−5.2%) | 359,451 → 343,017 (−4.6%) | 630,811 → 633,161 (+0.4%) |
| `post.comments.where(body: "c").to_a` | 1,049,464 → 1,004,384 (−4.3%) | 429,728 → 417,466 (−2.9%) | 1,050,056 → 1,003,365 (−4.4%) |
| `association(:comments).scope`, rebuilt | 241,736 → 196,720 (−18.6%) | | 242,237 → 196,798 (−18.6%) |

MICRO_C2_TIME

ruby-bench instructions (interpreter): railsbench −0.09%, shipit −2.64%, lobsters −0.28% (A/A as above). Census
allocations: −2 objects per direct association scope (the tracker and its Hash); 36 / 42 of 56 workloads moved
≤ −1 against the A/A's 16 / 14, median −2.0 / −3.3; Fizzy 13 / 12 of 14 workloads, median −18 / −13.

**Overlap.** Open #59212 (bruno-costanzo) stops statement-cached association readers from building the scope at all,
so on top of it C2 only applies where a scope is still built: association relations (`post.comments.where(…)`,
`order`, `exists?`), `CollectionProxy#scope`, through associations' targets. Measured on top of #59212 (interpreter): shipit
−0.78%, railsbench −0.01%, lobsters +0.07% (within lobsters' A/A), and shipit −1.09% under YJIT; per call `post.comments.where(…).to_a` −4.4% and
`association(:comments).scope` −18.6% are unchanged by #59212. The two touch different files and are independent.

## Overlaps measured, not duplicated

Same instruction-count method, each PR merged onto the same main (interpreter):

| PR | Author | What | railsbench | shipit | lobsters |
| --- | --- | --- | ---: | ---: | ---: |
| #59212 | bruno-costanzo | skip building the association scope when the reader uses the statement cache | +0.01% | −10.16% | −0.74% |
| #59141 | tenderlove | Active Record attributes in an Array | −2.85% | −9.16% | does not boot¹ |
| #59413 | czj | look up the raw-SQL matcher in `order` only when needed | +0.03% | −0.90% | −0.24% |
| #59518 | sampokuokkanen | memoize `QueryAttribute#hash` (query cache key) | −0.16% | −0.36% | −0.28% |

¹ With #59141 (head `6df1ebd`) lobsters fails at boot: `User has no attribute 'prefers_color_scheme' to define a reader for` (`ArgumentError` from `define_method_attribute`), raised when activerecord-typedstore 1.6.0 calls `define_attribute_method` for a typed-store key that is not a column. Recorded here only; nothing was posted.

#59413 is exactly the `preprocess_order_args` lead found here (eager `model.adapter_class` per `order`, 0.77% of
shipit under YJIT) and #59518 with merged #59505 is the query-cache-key lead; both were found by their authors first.

## Rejected and not pursued

| Lead | Cost found | Why not |
| --- | --- | --- |
| Query cache key hashing (`compute_if_absent` → `Array#hash` → `QueryAttribute#hash`, `Attribute#hash`, `Type::Value#hash`; `Hash#delete` + reinsertion for LRU order) | ≈1.8% mean self; shipit YJIT 2.45% under `Hash#delete` plus 0.94% `Array#hash` | Another author's line of work: #59505 (merged 2026-11-01) and open #59518. What remains after them (statement-cache binds are plain `Attribute`s, and the SQL String is hashed twice per lookup) would need a key object with a memoized hash; left to that author. |
| `preprocess_order_args` evaluates `model.adapter_class.column_name_with_order_matcher` for Symbol/Arel arguments | 0.77% shipit YJIT, 0.31% lobsters | Open #59413 does exactly this (measured above). |
| `has_default_scope?`: `method(:default_scope).owner` allocates a Method per `find`/`find_by` (via `scope_attributes?`), per association proxy and per `all` | 0.61% railsbench YJIT, 0.50% shipit YJIT inclusive | Deliberate: #59234 (kamipo, merged 2026-10-21) made it the single spelling to fix private `default_scope` overrides, and it was faster than the `respond_to?` it replaced. Ruby has no allocation-free way to ask for a resolved method's owner; caching it needs method-added hooks on the class and extended modules, which is not an exact change. |
| Connection checkout and checkin per query (`with_connection` without a lease) | shipit interpreter 2.6% checkout + 2.8% release | Design of non-sticky leases (#51192); the cost is the pool's monitors. No small exact change. |
| Resolving the model's pool per query (`connection_handler`, `current_role`, `current_shard`, `connection_specification_name`) | 1.0–3.2% inclusive outside railsbench | Each part follows live state (role/shard stacks, per-class names, Ractor handlers). Only avoidable callers were addressed (C2; #59413). |
| Arel `Visitor#visit` dispatch | 0.31% self | Dispatch is already cached per class; what remains is the `send`, which is bet J1 (ZJIT). |
| `Result#column_types`, `indexed_rows`/`column_indexes`, `LazyAttributeSet` | 0.9%, 0.4%, 0.8% self | #59141 and #58002 rework these; C3 is measured against #59141. |
| SQLite `stmt.types.map { type_map.lookup(t) }` per query | part of 0.6% `perform_query` self | Caching the mapped types per prepared statement is not exact: SQLite re-prepares a statement after a schema change and its declared types can change. |
| `schema_context` checks `@schema_context&.schema_loaded?` inline instead of calling `schema_loaded?` (every `attribute_types`, `type_for_attribute`, `attributes_builder`) | alone: `Post.find(1)` −1.2%, one-row load −4.0% in instructions | On top of C3: 0.0% / −0.1% / −0.2% per call (`find`, `where…to_a`, `has_many` load). Below the bar once C3 removes the per-key calls. |
| `Delegation::ClassMethods#create`, `Relation#initialize`/`initialize_copy` | 0.38%, 0.18%, 0.16% self | Argument forwarding and object setup; nothing exact to remove. |
| `ActiveRecord::StructuredEventSubscriber#sql` | 0.7% in Fizzy and CodeTriage only | Runs only when an event reporter subscriber exists in debug mode; app configuration. |

## Wall time

WALL_SECTION

## Method

* **Pins.** Rails main [`e64b660612`](https://github.com/rails/rails/commit/e64b660612fa582a4a89a91bc002269b29426e76)
  (merge of #59552, fetched 2026-11-03); Ruby 4.0.7 (mise), interpreter and `--yjit`; ruby-bench at byroot's
  heap-harness `bf1afb2` with the [index-with-capacity](index-with-capacity.md) setup
  ([bench/upstream/index_with_ruby_bench](../../bench/upstream/index_with_ruby_bench)): Rails main needs `prism`,
  erubi and `:header_or_legacy_token` there, and a vendored shipit-engine 0.45.0. Census apps on the same commit via
  `script/census setup`. PostgreSQL 15.19, Redis and memcached as orb services.
* **Profiles.** [`harness-arprof`](../../bench/upstream/arcpu/ruby-bench/harness-arprof/harness.rb) (warmup, then
  stackprof wall mode, 200 µs, raw), [`census_prof.rb`](../../bench/upstream/arcpu/census_prof.rb) for census
  workloads; [`rank.rb`](../../bench/upstream/arcpu/rank.rb) (self/inclusive by frame and area),
  [`callers.rb`](../../bench/upstream/arcpu/callers.rb), [`incl.rb`](../../bench/upstream/arcpu/incl.rb).
* **Instruction counts.** Lowrail's pinned Valgrind 3.19.0 with the 512 MiB brk reservation
  (`script/bench-valgrind`), Callgrind with `--collect-atstart=no --toggle-collect=rb_ary_cycle`:
  [`harness-ir`](../../bench/upstream/arcpu/ruby-bench/harness-ir/harness.rb) warms up (interpreter 1 iteration,
  YJIT 10), then runs one iteration inside `[nil].cycle(1) { … }` with GC disabled, so only that iteration's
  mutator instructions are collected. [`irab.rb`](../../bench/upstream/arcpu/irab.rb) gives each variant its own
  Gemfile copy pointing at its Rails worktree; YJIT runs add `--smc-check=all`. No brk warning in any log. The A/A
  pair is the same tree measured twice; lobsters' A/A (−0.15%) is larger than the others' because the app is not
  fully deterministic. Per-call counts: [`irmicro.rb`](../../bench/upstream/arcpu/irmicro.rb) on
  [`micro.rb`](../../bench/upstream/arcpu/micro.rb) cases (connection released, as in a request).
* **Wall time.** [`rbab.rb`](../../bench/upstream/arcpu/rbab.rb): variants interleaved, order rotated per round, one
  process per run, the Rails path swapped through a symlink so every variant loads from the same path;
  [`harness-cpu`](../../bench/upstream/arcpu/ruby-bench/harness-cpu/harness.rb) also records process CPU time.
* **Allocations.** `script/census run` A/A pair (`base`, `base2`) and one label per candidate on the six apps,
  interpreter and YJIT, `compare --base base2 --aa base`.
* **Suites.** Each branch: `rake test:sqlite3` and `rake test:postgresql` in `activerecord` with
  `RAILS_STRICT_WARNINGS=1` (SQLite 10,247 runs, PostgreSQL 11,166 runs, 0 failures and 0 errors; the four SQLite
  structure-dump tests that need the `sqlite3` CLI were rerun after installing it and pass), base PostgreSQL run
  identical; RuboCop on the changed files.
* **Overlap check.** `gh search prs` on rails/rails for each lead (query cache, `column_types`, `_load_from_sql`,
  `alias_tracker`, `AssociationScope`, `disallow_raw_sql`, `adapter_class`, `has_default_scope`), and the diffs of
  open #59141, #58002 and #59212.

## Drafts

Short form from [DECISIONS](../DECISIONS.md): two paragraphs, one per-call table, one sentence of breadth.
Not opened; each needs its Thermos review (Codex, GPT-6.1 Sol) first.

### C3: Read attribute_types once when loading records

> `_load_from_sql` drops the result's column types that the model already has with
> `column_types.reject { |k, _| attribute_types.key?(k) }`. `Result#column_types` holds every column twice, by name
> and by index, so the block calls `attribute_types` twice per column, and since #58437 that call goes through
> `schema_context`, `schema_loaded?` and the schema's attributes instead of reading an ivar. Every query that
> instantiates records on SQLite or PostgreSQL pays it.
>
> This reads `attribute_types` once before `reject`. The resulting Hash is the same, since nothing in the block can
> change the model's attribute types.
>
> | Per call, 12-column model | Before | After |
> | --- | ---: | ---: |
> | `Post.find(1)`, interpreter / YJIT | 442k / 222k instructions | 413k / 213k (−6.6% / −3.8%) |
> | `Post.where(...).limit(5).to_a` | 747k / 360k | 718k / 351k (−3.9% / −2.5%) |
> | instantiating one row | 143k / 84k | 114k / 75k (−20% / −10%) |
>
> On ruby-bench this is 1.0% / 4.1% / 1.0% fewer instructions per iteration on railsbench / shipit / lobsters in the
> interpreter (0.7% / 5.3% / 0.6% with YJIT; A/A under 0.16%).

### C2: Build the association alias tracker only for through chains

> `AssociationScope#scope` builds an `AliasTracker` for every association scope. `Relation#alias_tracker` looks up
> the model's connection pool and checks a connection out and back in to read `table_alias_length`, but `get_chain`
> only uses the tracker for the reflections after the first, so for a direct `belongs_to` or `has_many` it's thrown
> away. This runs for every association reader that builds its scope and every association relation
> (`post.comments.where(...)`).
>
> `get_chain` now takes the relation and builds the tracker when it reaches the second reflection, with the same
> arguments as before. A direct association no longer touches the connection while building its scope; the query
> that runs it still does. It's independent of #59212: association relations still build the scope there.
>
> | Per call, interpreter / YJIT | Before | After |
> | --- | ---: | ---: |
> | `post.author` | 692k / 298k instructions | 647k / 282k (−6.5% / −5.3%) |
> | `post.comments.to_a` | 873k / 359k | 828k / 343k (−5.2% / −4.6%) |
> | `post.comments.where(body: "c").to_a` | 1,049k / 430k | 1,004k / 417k (−4.3% / −2.9%) |
>
> On ruby-bench shipit runs 2.6% fewer instructions per iteration (1.8% with YJIT; 0.8% / 1.1% on top of #59212), and 36 to
> 42 of 56 workloads in six apps allocate 2 fewer objects per association scope.

