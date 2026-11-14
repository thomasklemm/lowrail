# VB1: block literals instead of Symbol blocks in `LazyIndexedAttributeSet`

Lead 7c of [ZJIT leads 3 and 7](../../../docs/upstream/zjit-leads.md#rails-side-option-a-block-literal-in-fetch_value_at),
built 2026-11-14 in [thread T-01a1db12](https://ampcode.com/threads/T-01a1db12-4922-7731-840b-735d41b72d93). Queue
item: [VB1](../pr-queue/items/VB1.md). Branch `thomasklemm/indexed-set-value-block` on thomasklemm/rails, head
`59db98e25c`, built on rails/rails main `50c54eed06` (still main on 2026-11-14 18:00 UTC). Nothing opened or posted.

## The change

```diff
@@ def fetch_value_at!(index)
-        cast_value(@ctx.name_at(index), index, &:value!)
+        cast_value(@ctx.name_at(index), index) { |attribute| attribute.value! }
@@ def deep_dup
-      map(&:deep_dup)
+      map { |attribute| attribute.deep_dup }
@@ def value_at!(index, name)
-          cast_value(name, index, &:value!)
+          cast_value(name, index) { |attribute| attribute.value! }
```

+3/−3 in `activemodel/lib/active_model/attribute_set.rb`, one commit, no comments, no test.

**Why.** YJIT (`exit_if_unsupported_block_arg_type`) and ZJIT (`type_specialize`, `BlockHandler::BlockArg`)
specialize a block argument only when it is nil, a block param proxy (YJIT) or a Proc. A Symbol makes the send
generic: `send_iseq_block_arg_type` in YJIT, `send_fallback_send_block_arg_not_nil` in ZJIT. `fetch_value_at!` (the
generated slot readers) and `value_at!` (`fetch_value!`: `id`, `read_attr`, `_read_attribute`) reach `cast_value`
on every first read of an attribute, so each first read is one generic call, although `cast_value` only yields when
the row has no value. `deep_dup`, which `Core#init_attributes` runs on every record `dup`, is one generic call with the
Symbol, and under ZJIT each of `transform_attributes!`'s yields to the Symbol's proc is a further generic call
(`send_fallback_invokeblock_not_specialized`).

**Scope.** The user asked for every Symbol-to-proc on this hot path in `attribute_set.rb` where it measurably helps.
`LazyIndexedAttributeSet` has three: the two `&:value!` and `map(&:deep_dup)`. All three are taken; `deep_dup` was
measured separately (tree `fixb` against `fixv`, below) and helps in all three modes. The other Symbol blocks in the
file are in `ReadOnlyAttributeSet` and the base `AttributeSet` (`cast_types` at schema load, `values_before_type_cast`
and `values_for_database` for Marshal, `read_only`, `deep_dup` of plain sets), none on the read path of a loaded
record; L3 replaces the two Marshal ones on `LazyIndexedAttributeSet`. Not measured, not changed.

## Exactness

* `&:value!` / `&:deep_dup` call the public method on the yielded attribute, with Symbol#to_proc's lambda arity (one
  argument). The block literals do the same: `cast_value` yields exactly one Attribute
  (`default_attribute(name, index, false, nil)`), `transform_attributes!` yields one. `value!` and `deep_dup` are
  public on every Attribute class (`Attribute#value!`, `Uninitialized#value!` raising the frozen
  `UNINITIALIZED_ERROR`; `Object#deep_dup`). No `using` in the file, so refinements play no part. `block_given?` is
  true in both.
* Laziness: the blocks run at the same moment as before (only when `cast_value` reaches the default path, and only
  in `map` after `materialize`), so what is cast, when, and how often is unchanged.
* [probe.rb](probe.rb) on main, main2 and the branch: 620 probe lines on several record states (three loaded
  records, three partial selects, `SELECT … AS`, new, blank new, STI, `becomes`, frozen, dup, written,
  ActiveModel::Attributes) over the reader paths (generated reader, `read_attribute`, `[]`, `_read_attribute`,
  `read_attr`, `_read_attribute!`) and 13 attributes (columns, defaults,
  a lazy proc default, virtual with and without defaults, a type that raises on cast/deserialize, a traced type
  that logs every cast and deserialize), then dirty tracking, save and reload, and `dup` with a value whose `dup`
  raises. Each line has the value or the exception class and message, the Rails frames of its backtrace, and the
  type's cast log. main and main2 are byte-identical; the branch differs only by the added block frame
  (`attribute_set.rb:412 block in fetch_value_at!`, `:534 block in value_at!`, `:444 block in deep_dup`) in
  backtraces raised inside the blocks: [probe_diff.sh](probe_diff.sh) prints nothing for SQLite or PostgreSQL 17
  (962 lines each; 26 raw hunks, all of them backtraces). `MissingAttributeError` for uninitialized attributes is
  raised by `missing_attribute(…, caller_locations)` in `_read_attribute_at!`/`_read_attribute!`, so its backtrace
  is the caller's and identical on both trees. Raw: [results/probe](results/probe).
* With K1 (`thomasklemm/lazy-indexed-keys`) and L3 (`thomasklemm/attrs-for-database-row`): `git merge-tree` of VB1
  with each, and of K1+L3 with VB1, is clean. On the K1+L3+VB1 tree: Active Model 1,269 runs 0 failures, and the
  probe equals the branch's apart from line numbers.
* Open PRs touching `attribute_set.rb` (`gh pr list --limit 1000`): #59800 (K1), kamipo's #58380 and tenderlove's
  draft #53344. VB1 adds no conflict: #58380 conflicts with main and VB1 only in `activerecord/CHANGELOG.md`, #53344
  in the same six files with both. GitHub search finds no open PR on `value!`/`cast_value`, the Symbol block or
  `LazyIndexedAttributeSet` other than K1.

## Tests

On `59db98e25c`, Ruby 4.0.9: Active Model 1,269 runs, 0 failures, 0 errors (also with `-w`, no warning from
`attribute_set.rb`); Active Record SQLite 10,375 runs, 0 failures, 0 errors, 52 skips; Active Record PostgreSQL 17
11,298 runs, 0 failures, 0 errors, 31 skips; RuboCop 1.90.0 with Rails' config: no offenses. Fork CI
(Devcontainer smoke test, rails-new-docker) green. No new test: the change has no behaviour of its own to pin, and
DECISIONS rules out counting generic calls in the suite.

## Measurement

[attr_bench.rb](attr_bench.rb) (micro) and [req_bench.rb](req_bench.rb) (request mix) under [run.sh](run.sh), all
cells by [matrix.sh](matrix.sh) or one-off `RUN=` loops: one process per tree, width and mode; the pinned Valgrind
3.19.0 with the 512 MiB brk reservation built by `script/bench-valgrind` ([valgrind.json](results/valgrind.json); no
`brk segment overflow` in any run); stock Callgrind client requests ([irwin.c](irwin.c)) zeroing and dumping around
each window of N = 200 calls, `GC.start` then `GC.disable` around it (0 GCs in every window), census fixed heap
(`RUBY_GC_HEAP_*_INIT_SLOTS`), the `_empty` window subtracted. Under a JIT the warmup repeats windows until three in a
row change no JIT counter, and a cell counts only if the measured window changed none either (gate): YJIT compiled
ISEQs, blocks and `invalidation_count`; ZJIT compiled ISEQs, side exits and `invalidation_time_ns` (master has no
invalidation count). Trees: `main` and `main2` (A/A, both `50c54eed06`), `fixv` (only the two `&:value!` lines,
`5e14c3a4f8`, the first build of the branch) and `fixb` (`fixv` plus `deep_dup`; its `attribute_set.rb` is
byte-identical to the head `59db98e25c`). Rubies: 4.0.9 (interpreter, YJIT) and master
[`674c477295`](https://github.com/ruby/ruby/commit/674c477295) (ZJIT; the lead's pin), GCC 14.2.0, rustc 1.100.0.

Cases: `rows10_read_all` instantiates 10 records from a cached result and calls every reader once (`id` through
`fetch_value!`/`value_at!`, the 31 others through the generated slot readers, so every read is a first read);
`load1_read_all` the same for `find(1)`; `dup_warm` dups a loaded record; `load1_dup`, `load1`,
`load1_attributes`, `load1_serializable_hash`, `rows10` (no reads), `new` and the warm readers are controls. Table of
`id`, `type` and width−2 string/integer columns. The request mix copies ruby-bench's railsbench: production mode,
its `posts` schema with 100 rows, the routes `/posts`, `/posts.json`, `/posts/1`…`/posts/100` sampled with its seed,
scaffold-like ERB views and layout; the window is the first 200 requests of its 2,000 (3 index pages, 197 show
pages). Its layout leaves out railsbench's `csrf_meta_tags` (random token).

**Run c is the result.** Runs a and b had the connection pool's reaper thread running, which wakes on a timer and
whose work lands inside some windows: the same 200-request window repeated three times in one process gave 210.9M,
208.2M and 210.9M Ir with the reaper on and 207.4M, 208.18M and 208.19M with `reaping_frequency: 0` (two processes
agree within 0.08%, [noise](results/noise)); it also compiled code inside YJIT request windows. Run c reran every cell
with the reaper off. Run b is kept ([tables-b](results/tables-b.md)), its request cells superseded and not used. Run
a is not kept: its matrix service had `Restart=always`, a stop issued from the wrong directory did nothing, and it
reran twice beside runs b and c, rewriting run a's files with a different tree under the name `fix`. Run c is unaffected (its own
files; one Ruby thread, so its instruction counts don't depend on CPU sharing), and the split by line below is run e,
measured afterwards on an idle orb.

Branch (`fixb`) against main, Ir per call, run c ([tables-c](results/tables-c.md), raw
[results/raw](results/raw)); A/A is main2 against main:

| 30 columns, run c | interp main | A/A | branch | YJIT main | A/A | branch | ZJIT main | A/A | branch |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 records, every attribute read once | 1,701,233 | −0.01% | **−2.51%** | 748,608 | −0.01% | **−7.53%** | 561,399 | −0.01% | **−20.61%** |
| `find` and every attribute read once | 550,002 | +0.00% | −0.79% | 274,973 | −2.77% | −4.90% | 250,425 | −0.34% | −4.94% |
| `dup` of a loaded record | 438,599 | −0.09% | **−1.93%** | 226,521 | −0.06% | **−5.72%** | 211,777 | −0.05% | **−12.32%** |
| `find` then `dup` | 1,115,688 | −0.07% | −0.78% | 598,930 | −1.30% | −3.28% | 524,075 | −0.04% | −5.02% |
| `find` then `serializable_hash` | 787,214 | −0.17% | −0.62% | 516,279 | −1.41% | −3.11% | 427,254 | −0.14% | −3.01% |
| `find` then `#attributes` | 621,706 | −0.07% | −0.05% | 314,254 | −2.48% | −2.39% | 285,164 | +0.05% | −0.10% |
| `find` | 401,715 | +0.00% | −0.02% | 208,447 | −3.68% | −3.71% | 202,903 | +0.03% | +0.05% |
| 10 records, no reads | 215,518 | −0.09% | −0.04% | 80,935 | −0.08% | −0.00% | 83,899 | −0.04% | −0.10% |
| request mix, per request | 1,039,548 | −0.16% | −0.04% | rejected | | | 1,074,341 | −0.08% | **−0.58%** |

Every JIT window in run c passes the gate except main's YJIT request window (5 blocks compiled), so the YJIT request
cell is rejected, recorded and not rerun. In the YJIT `find`, `#attributes`, `find`+`dup` and `serializable_hash`
rows main itself sits in a slower compiled state (A/A −1.3% to −3.7%; main2 and the branch agree), so for those
rows the branch against main2 is the fair reading (`find` −0.03%, `#attributes` +0.09%, `find`+`dup` −2.01%,
`serializable_hash` −1.72%, `find`+reads −2.19%).

Widths ([tables-c](results/tables-c.md)): 10 records read once, interpreter −1.81% / −2.51% / −2.69% at 6 / 30 / 100
columns, YJIT −11.87% / −7.53% / −16.92%, ZJIT −15.38% / −20.61% / −21.81%; `dup` of a loaded record interpreter
−1.67% / −1.93% / −1.96%, YJIT −5.98% / −5.72% / −5.61%, ZJIT −10.59% / −12.32% / −12.44%. The controls, which
don't run the changed lines (load without reads, `id` after `find`, `#attributes`, warm reads, `new`), move by at
most 0.10% in the interpreter at every width. Under ZJIT they move by at most 0.17%, except `new` at 6 columns
(+0.63%, A/A +0.12%). Three repeats of that cell (run g) give medians of 18,507 / 18,555 / 18,534 Ir for main, main2
and the branch (+0.15%, A/A +0.26%), and `#attributes` +0.08% (A/A +0.08%). Under YJIT they move with the
compiled-state flips described below. Objects per call are identical on both trees in every cell.

Split by line (run e, 30 columns, main, `fixv` and `fixb` in one cohort, every JIT window gated): the `&:value!`
lines carry all of the read gain (10 records read once: `fixv` −2.49% / −7.52% / −20.42% interpreter / YJIT / ZJIT,
`fixb` against `fixv` −0.01% / −0.01% / +0.02%) and leave `dup` unchanged (`fixv` +0.04% / +0.08% / +0.12%);
`deep_dup` carries all of the `dup` gain (`fixb` against `fixv` −1.86% / −5.06% / −11.35% for `dup` of a loaded
record, −0.81% / −0.76% / −4.84% for `find` then `dup`).

Request mix: 12 fewer generic calls per request in both JITs ([stats](results/stats), `STATS=1` with
`--yjit-stats=quiet` / `--zjit-stats-quiet`, no Valgrind; in those files `fix` is `fixv` for the 30-column runs and the
head for the request runs, `zjit-dup_warm-all-send-counters-*` lists every send counter of one `dup` window): YJIT `send_iseq_block_arg_type` 16.92 → 4.99, ZJIT
`send_fallback_send_block_arg_not_nil` 55.86 → 43.94 (the rest are other sites, lead 7a/7b). At ~145 Ir per first
read in the interpreter that is ~0.17% of a request, inside the interpreter A/A, so the interpreter request cell
shows nothing either way.

Counters at 30 columns, per call: 10 records read once, YJIT `send_iseq_block_arg_type` 300 → 0 and ZJIT
`send_fallback_send_block_arg_not_nil` 300 → 0 (ZJIT dynamic sends 322 → 22); `dup`, ZJIT
`send_fallback_send_block_arg_not_nil` 1 → 0 and `send_fallback_invokeblock_not_specialized` 30 → 0 (dynamic sends
63 → 32), YJIT `send_iseq_block_arg_type` 1 → 0 and one side exit fewer.

**JIT state variance (not caused by the change).** Some gated cells land in one of two compiled states, depending
on the process and on the cases run before them. YJIT `read_all_warm` (every reader on a warm record, which the
change doesn't execute) at 30 columns read +1.59% on the branch in run c (A/A +0.02%). Rerun with fewer cases: run d
([tables-d](results/tables-d.md)) +0.05% (A/A +0.03%; per reader `id` +0.54% against an A/A of +0.36%, 3 Ir, the slot
readers ±0), and run f, three processes per tree with only `read_all_warm` and `find`: 8,661–8,665 Ir on main, main2
and the branch alike, `find` 200,898–201,320. YJIT `find` flips both ways: main sat 3.7% above main2 and the branch
in run c, the branch 3.8% above main and `fixv` in run e. ZJIT 10 records read once: main read 656,403 in run b
against 561,399 in run c and 564,968 in run e, the branch 445,668–445,711; the table uses the cheaper main state.

## Rerun

```
Rails worktrees under ~/vb1 (main, main2, fix, fixb at the commits above), bundles ~/vb1/suite-TREE (4.0.9) and
~/vb1/suiteM-TREE (master; activesupport..railties, sqlite3), BUNDLE_PATH ~/vb1/gems409 and ~/vb1/gemsM, irwin.so
built from irwin.c into ~/vb1/ext409 and ~/vb1/extM (CPATH with the pinned Valgrind's include), the pinned Valgrind
in ~/vb1/vg (script/bench-valgrind ~/vb1/vg), Ruby master 674c477295 in ~/w/ruby-master.
RUN=c bench/upstream/vb1/run.sh OUT TREE 6|30|100|req interp|yjit|zjit [CASE...]
ruby bench/upstream/vb1/table.rb OUT c
bench/upstream/vb1/stats.sh OUT TREE 30|req yjit|zjit [CASE...]
RAILS=~/vb1/TREE BUNDLE_GEMFILE=~/vb1/suite-TREE/Gemfile ruby bench/upstream/vb1/probe.rb sqlite|postgresql > TREE.txt
bench/upstream/vb1/probe_diff.sh main.txt fix.txt
```
