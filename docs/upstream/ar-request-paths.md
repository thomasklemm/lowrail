# Active Record request paths: a candidate round (2026-11-04)

A round for small, exact rails/rails candidates on Active Record request paths: record instantiation,
attribute reads and writes, query building and Arel, associations and their cache, preloading, the
`find`/`find_by` statement cache, transactions and callbacks. Sources: the census 8 CPU rankings
([rails-main-census-8](rails-main-census-8.md), interpreter and YJIT, line and method, 20 apps, 251 workloads),
census 7's allocation ranking, [activerecord-cpu](activerecord-cpu.md), [frontier-census-f1](frontier-census-f1.md),
[rails-common-paths](rails-common-paths.md) and [merged-audit](merged-audit.md). Out of scope by agreement:
ActiveModel `resolve_attribute_name` (orb C9) and Action View (orb C10).

**Result.** One candidate, AR-1, queued (not opened). Two smaller ones were built, measured and dropped; the
hotter Active Record lines in census 8 are all taken by open or merged PRs (table below).

| # | Rails branch @ SHA (local, not pushed) | Change | Per call |
| --- | --- | --- | --- |
| AR-1 | `thomasklemm/sqlite3-result-type-map-once` @ `3fa76e25b4` | SQLite3 `perform_query` calls `type_map` once per result instead of once per column | 0 objects; `find` −1.6% to −2.5% instructions in all four modes |

On rails/rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed) (2026-11-04, after #59590 and
#59596–#59598), one commit, authored and committed by Thomas Klemm. The branch is not on the fork yet; the commit is in
[`ar-1-sqlite3-result-type-map-once.patch`](../../bench/upstream/ar_request_paths/ar-1-sqlite3-result-type-map-once.patch)
(`git am` on `9b116f1fed`); push it to the fork when the PR is opened.

## Pins and method

* Rails main `9b116f1fed`. Worktrees `main` and `aa` (the same commit twice, for the A/A) and one per candidate.
* Ruby 4.0.9 (mise), interpreter and `--yjit`; Ruby master
  [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb) built with
  `--enable-zjit --enable-yjit` for the interpreter and ZJIT columns.
* Micro cases: [`ar.rb`](../../bench/upstream/ar_request_paths/ar.rb) `CASE N MODE`, SQLite in memory (or
  PostgreSQL 15 with `DB=pg`), prepared statements on, GC disabled, event reporter debug mode off. `find` is
  `Post.find(id)` on a 9-column table; `where_to_a` loads 5 records; `load20` loads 20. `TZCFG=utc` adds
  `default_timezone: "utc"` to the database config.
* **Objects per call:** `GC.stat(:total_allocated_objects)` over warmed calls (`ar.rb CASE N obj`).
* **Instructions per call:** Callgrind, `--collect-atstart=no --toggle-collect=rb_ary_cycle`, (Ir(1,000) − Ir(0)) /
  1,000, median of three runs per variant and mode (two for `TZCFG=utc`); YJIT and ZJIT add `--smc-check=all`
  ([`ir.sh`](../../bench/upstream/ar_request_paths/ir.sh), [`ir_table.py`](../../bench/upstream/ar_request_paths/ir_table.py)).
* **ruby-bench:** ruby/ruby-bench `73918b2` with its own lockfiles (Rails 8.1.1/8.1.2, whose SQLite3
  `perform_query` matches main apart from the `intent` argument). The harness
  [`lowrail_ir.rb`](../../bench/upstream/ar_request_paths/lowrail_ir.rb) redefines `perform_query` from the
  installed gem's source in every variant, with the change applied only in the candidate, so both sides run a
  redefined method; one iteration under Callgrind after warmup (interpreter 1, YJIT 10), GC disabled; `main1` and
  `main2` are the A/A ([`rb_ir.sh`](../../bench/upstream/ar_request_paths/rb_ir.sh)).
* **Differential:** [`diff_sqlite.rb`](../../bench/upstream/ar_request_paths/diff_sqlite.rb) prints results,
  column types, loaded records, DML results, statement pool sizes, results after adding and removing a column, and
  the error class of a bad query, with prepared statements on and off, `default_timezone` `"local"` and `"utc"`, and
  `statement_limit: 2`; run on main and the candidate under the interpreter, YJIT and ZJIT (call threshold 1).
* **Suite:** Active Record `test:sqlite3` on Ruby 4.0.9 (the `sqlite3` CLI installed for the structure dump/load
  tests); RuboCop on the changed file.
* **Reviews:** codex is not available in this orb, so a separate subagent did the primary review on both rubrics
  (correctness, maintainability with the L0–L3 rating) and an adversarial round that ran code against overrides,
  eviction, fork, threads, error paths and timezones (record loading is critical in DECISIONS).

## AR-1: look up the SQLite3 type map once per result

`SQLite3::DatabaseStatements#perform_query` builds every SELECT result with

```ruby
ActiveRecord::Result.new(stmt.columns, rows, stmt.types.map { |t| type_map.lookup(t) }, affected_rows: affected_rows)
```

`type_map` is a method on the abstract adapter, not a reader: it calls `extended_type_map_key` (which checks
`@default_timezone`) and then reads `self.class::TYPE_MAP`, or, when `default_timezone` is set in the database
config, builds a `{ default_timezone: ... }` Hash and looks it up in `EXTENDED_TYPE_MAPS`, a `Concurrent::Map`.
It ran once per column of every result. The change reads it once:

```ruby
type_map = type_map()
ActiveRecord::Result.new(stmt.columns, rows, stmt.types.map { |t| type_map.lookup(t) }, affected_rows: affected_rows)
```

The spelling has precedent in the same layer: `collector = collector()` in `abstract/database_statements.rb`
(kamipo, 2020; Hartley McGuire, 2025). PostgreSQL's `type_map` is an `attr_reader`, and mysql2/trilogy build
results without column types, so SQLite is the only adapter where this costs anything.

**Census.** Census 8 (interpreter, 4.0.9) has these lines in all 8 SQLite apps (each `type_map` line in 7 of them) (blog, campfire, fizzy,
lobsters, react-starter-kit, redprints-cfp, thinkroom, writebook): `database_statements.rb:149` (the
`Result.new` line, rank 368, 18,230 Ir/op), `type_map.rb:15`/`:19` (`lookup`/`fetch`), `abstract_adapter.rb:1336`,
`:1342`, `:1347` (`extended_type_map_key`, `type_map`). About 0.03% of all instructions for the line itself: the
work is per column, and request time is spread thin. ruby-bench per iteration: railsbench 2,000 results with 12,000
columns, lobsters 1,030 with 10,126, shipit 1,970 with 30,512 (counted with a prepended `Result#initialize`).

**Not taken upstream.** `gh search prs`/`issues` on rails/rails for "type_map sqlite3", "sqlite3 type map result",
"stmt.types", "extended_type_map_key", "sqlite3 perform_query", "sqlite3 database_statements": no PR or issue
touches this. The file's history since June 2026 is QueryIntent, Ractor, retry and Markdown work; no open PR
changes `perform_query`.

**Exactness** (checklist items checked):

* `type_map` takes no arguments and reads only `@default_timezone`, which is set from the config once at
  `initialize`; changing `ActiveRecord.default_timezone` at runtime doesn't change the key. So the one call returns
  the map every per-column call returned (item 8).
* The call only runs in the branch with at least one column, so it never adds a call (item 4).
* Overrides and prepends of `type_map` or `extended_type_map_key` (item 1): `type_map` gets no column, so an
  override can only differ per column by counting its own calls. The reviewer prepended a counting `type_map` with
  `default_timezone: "local"` on a 5-column select: 5 calls on main, 1 on the candidate, identical `column_types`.
  This is the only visible difference, and it is the change.
* Threads and Ractors: `perform_query` runs under the adapter lock; the Ractor proxy adapter has its own `type_map`
  and `perform_query` and never reaches this code.
* `type_map` now runs before `stmt.columns`; `stmt.columns` has no side effects.
* Differential: identical output on main and the candidate under the interpreter, YJIT and ZJIT in every config
  above, with timestamps fixed. The one differing line is the counted `type_map` calls for a 3-column result: 4 on
  main, 2 on the candidate.
* Objects per call unchanged: `find` 51, `where_to_a` 132, `load20` 291 (with `TZCFG=utc`, `find` 60 → 52: the
  per-column key Hash is gone).
* Suite: `test:sqlite3` 10,281 runs, 0 failures, 0 errors after installing the `sqlite3` CLI (the 4 structure
  dump/load tests that errored without it pass on main and the candidate). RuboCop: no offenses.

**Review.** Primary: ship as is, L0–L1, no correctness findings; asked for numbers with and without
`default_timezone` in the config, both below. Adversarial: no demonstrated difference besides the call count above.

### Instructions per call (Callgrind)

Median of three runs per variant and mode (`load20` under ZJIT and every `TZCFG=utc` cell: two). "A/A" is the
`aa` worktree (the same commit as main) against main.

| Case | Mode | main | A/A | AR-1 | Change |
| --- | --- | ---: | ---: | ---: | ---: |
| `find` | interpreter 4.0.9 | 285,315 | −0.06% | 279,005 | **−2.21%** |
| `find` | YJIT 4.0.9 | 139,477 | +0.37% | 136,912 | **−1.84%** |
| `find` | interpreter master | 290,345 | +0.02% | 283,107 | **−2.49%** |
| `find` | ZJIT master | 142,740 | −0.02% | 140,449 | **−1.60%** |
| `where_to_a` | interpreter 4.0.9 | 588,944 | −0.09% | 582,517 | −1.09% |
| `where_to_a` | YJIT 4.0.9 | 268,824 | +0.19% | 266,379 | −0.91% |
| `where_to_a` | interpreter master | 606,701 | +0.02% | 597,805 | −1.47% |
| `where_to_a` | ZJIT master | 275,739 | +0.02% | 272,969 | −1.00% |
| `load20` | interpreter 4.0.9 | 856,776 | −0.05% | 850,280 | −0.76% |
| `load20` | YJIT 4.0.9 | 417,257 | +0.01% | 415,085 | −0.52% |
| `load20` | interpreter master | 895,508 | +0.01% | 889,285 | −0.69% |
| `load20` | ZJIT master | 412,617 | +0.00% | 410,269 | −0.57% |
| `find`, `TZCFG=utc` | interpreter 4.0.9 | 335,274 | +0.02% | 284,558 | **−15.13%** |
| `find`, `TZCFG=utc` | YJIT 4.0.9 | 186,974 | +0.28% | 142,887 | **−23.58%** |
| `find`, `TZCFG=utc` | interpreter master | 343,036 | −0.09% | 289,673 | **−15.56%** |
| `find`, `TZCFG=utc` | ZJIT master | 188,758 | −0.05% | 145,588 | **−22.87%** |
| `where_to_a`, `TZCFG=utc` | interpreter 4.0.9 | 638,782 | +0.03% | 588,559 | −7.86% |
| `where_to_a`, `TZCFG=utc` | YJIT 4.0.9 | 315,809 | −0.04% | 272,339 | −13.76% |
| `where_to_a`, `TZCFG=utc` | interpreter master | 658,887 | +0.05% | 603,876 | −8.35% |
| `where_to_a`, `TZCFG=utc` | ZJIT master | 321,852 | −0.07% | 278,101 | −13.59% |

Per column of `find`, AR-1 saves about 700 instructions (interpreter) in the default config and about 5,600 with
`default_timezone` in the database config, where main builds the key Hash and looks it up in the
`Concurrent::Map` for every column. That setting is per database in `database.yml`, not
`config.active_record.default_timezone`; none of the three ruby-bench apps sets it, and in census 8 only the default
branch shows up (`abstract_adapter.rb:1347`, the `else` that reads `TYPE_MAP`, in 7 apps; lines 1338 and 1344, the
key Hash and `compute_if_absent`, in none). No loss in any mode.

### ruby-bench (instructions per iteration)

One iteration under Callgrind after warmup, GC disabled; "main" is the mean of two main runs, "A/A" the second main
run against the first. The YJIT runs of the dropped statement-pool variants were stopped; main2 for YJIT ran after
them, in the same orb.

| App | Mode | main | A/A | AR-1 | Change |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | interpreter | 6,962,229,552 | +0.03% | 6,952,414,628 | −0.14% |
| railsbench | YJIT | 4,380,803,369 | +0.08% | 4,382,780,638 | +0.05% (inside A/A) |
| lobsters | interpreter | 4,266,309,164 | +0.01% | 4,260,302,858 | −0.14% |
| lobsters | YJIT | 3,033,650,774 | −0.02% | 3,027,920,196 | −0.19% |
| shipit | interpreter | 5,851,209,594 | +0.08% | 5,825,261,028 | **−0.44%** |
| shipit | YJIT | 3,158,304,663 | −0.08% | 3,150,338,863 | −0.25% |

Shipit has the most result columns per iteration (30,512, against 12,000 for railsbench and 10,126 for lobsters),
and the largest change.

## PR body (draft, reviewed)

Title: **Look up the SQLite3 type map once per result**

> When the SQLite3 adapter builds a result, it calls `type_map.lookup` once per column. `type_map` isn't a plain reader: it calls `extended_type_map_key` and reads `self.class::TYPE_MAP`, and if the database config sets `default_timezone` it also builds a `{ default_timezone: }` Hash and looks it up in a `Concurrent::Map`. Every call returns the same map.
>
> This calls `type_map` once per result, like `collector = collector()` in `to_sql_and_binds`. `type_map` takes no arguments and depends only on config read when the connection was created, so every column gets the same type as before. The one visible change: a subclass that overrides `type_map` is now called once per result instead of once per column.
>
> | `Post.find(id)` on a 9-column table, instructions per call | Interpreter | YJIT | ZJIT |
> | --- | ---: | ---: | ---: |
> | main | 285,315 | 139,477 | 142,740 |
> | this PR | 279,005 (−2.2%) | 136,912 (−1.8%) | 140,449 (−1.6%) |
> | Noise check: main run twice | −0.06% | +0.37% | −0.02% |
> | Separate setup, `default_timezone: "utc"` in the database config: main → this PR | 335,274 → 284,558 (−15%) | 186,974 → 142,887 (−24%) | 188,758 → 145,588 (−23%) |
>
> SQLite in memory, GC disabled. Each number is Callgrind instructions for 1,000 calls minus a 0-call run, divided by 1,000; median of three runs (two for the `default_timezone` row). Ruby 4.0.9; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/ar_request_paths/ar.rb)). On ruby-bench, instructions per iteration drop 0.44% (interpreter) and 0.25% (YJIT) on shipit, and 0.14% and 0.19% on lobsters, against noise of 0.08% or less; railsbench under YJIT is within noise. I found this while profiling 20 Rails apps on Rails main for Lowrail, a research project of mine; these lines show up in all 8 of the apps that use SQLite ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-request-paths.md)).

Checked by a separate reviewer against the receipts (every number recomputed) and for an outsider's reading; its
corrections are applied (the census count was 7 of 8 in the draft; the line at `database_statements.rb:149` is in
all 8 SQLite apps, and each `type_map` line in 7, together covering all 8).

## Dropped

| Candidate | Numbers | Why not |
| --- | --- | --- |
| SQLite3 statement pool read once: `(@statements[sql] \|\|= prepare(sql)).reset!` instead of `\|\|=` then a second `@statements[sql].reset!` (each `StatementPool#[]` calls `Process.pid`) | `find` −0.46% / −0.94% (interpreter / YJIT, YJIT A/A −0.48%), `where_to_a` −0.25% / −0.29%; ruby-bench interpreter shipit −0.18%, railsbench −0.07%, lobsters +0.01% | Exact (eviction happens before insert, so main's second lookup always returns the stored statement), but the reviewer rated the one-liner L2 for a gain about the size of the YJIT A/A. The double lookup is incidental (d4f8806344 wrapped the old `stmt = ... ; stmt.reset!` in an `if` in 2025); restoring that shape would be L0 but saves only one Hash lookup and a `Process.pid` per query. Not opened. |
| PostgreSQL `prepare_statement` reads `@statements[sql_key]` once | `find` −0.49% interpreter, −0.09% YJIT (A/A +0.15%); `where_to_a` −0.29% / −0.21% | Inside or near the A/A under YJIT. |

## Hot Active Record lines already taken

Census 8 method rank (interpreter) for every Active Record or Active Model method in ≥ 6 apps above 0.15% of
instructions, and why this round left it alone:

| Rank | Method | % Ir | Disposition |
| ---: | --- | ---: | --- |
| 3 | PG `cast_result` | 1.03 | Ours, merged (#59558, #59560). PG's `type_map` is a reader, so AR-1 has no PG analogue. |
| 4, 5, 8, 21, 22, 37, 60 | `IndexedRow`, `LazyAttributeSet#fetch_value!`/`keys`/`default_attribute`, `AttributeSet#[]` | 0.17–1.01 | Open #59141 (tenderlove); #58380. |
| 9, 10 | `Result#column_types`, `_load_from_sql` | 0.72–0.75 | Open #59141. |
| 12 | `Relation::Merger#merge` | 0.60 | Open #56205. |
| 13, 20, 23 | Arel `Visitor#visit`, collectors `<<` | 0.36–0.56 | Not examined in depth: visitor dispatch and String appends, no repeated work found on a read. |
| 17 | `QueryCache::Store#compute_if_absent` | 0.45 | Lock plus Hash; nothing to elide exactly. |
| 19 | `Arel::Table#[]` | 0.42 | Builds the `Attribute` nodes the query needs. |
| 25 | `connection_specification_name` | 0.30 | A loop would bypass overrides on superclasses (rejected in rails-common-paths). |
| 26, 35 | `build_where_clause`, `expand_from_hash` | 0.23–0.30 | Not examined in depth this round; kamipo and others are active in `query_methods.rb`. |
| 28, 52, 61 | `association`, `association_instance_get`, `Association#target` | 0.17–0.26 | Cache reads; no repeated work. |
| 34 | `PredicateBuilder#handler_for` | 0.24 | A cache would be L2 (census 8). |
| 43, 51, 57 | `Attribute#hash`, `Type::Value#hash`, `QueryAttribute#hash` | 0.18–0.21 | Open #59518. |
| 49 | `ScopeRegistry#value_for` | 0.20 | `IsolatedExecutionState` reads; call overhead. |
| 53 | `resolve_attribute_name` | 0.19 | Orb C9. |
| 63 | Preloader `Branch#preloaders_for_reflection` | 0.17 | Our open #59564. |
| — | `has_default_scope?` `method().owner` | — | Deliberate (#59234). |
| — | `AliasTracker` | — | Our open #59569. |
| — | `preprocess_order_args`/`column_references` | — | kamipo's merged #59590. |

Not built, as leads: `current_time_from_proper_timezone` checks out a connection on every save;
`AttributeMutationTracker#any_changes?` calls `LazyAttributeSet#keys` (an Array union of three key lists) two or
three times per save (touches the attribute set #59141 changes). `StructuredEventSubscriber#sql` cost shows up only
with the event reporter in debug mode, not in production.

## Limits

* Instruction counts on SQLite in memory and micro cases, not request time. ruby-bench runs Rails 8.1 with the
  change patched in by the harness, not Rails main.
* PostgreSQL and MySQL are untouched by AR-1. MySQL wasn't run.
* Reviews were subagents, not the Sol/Astra Thermos reviews DECISIONS names, because codex is not installed here.
