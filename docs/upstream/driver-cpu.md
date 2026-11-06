# Database driver CPU: where the rows cost work

Bet P-DRV, 2026-11-05–06. Ruby **4.0.9**, interpreter and YJIT. This is a
client-side query study, not database-server latency or a request benchmark.

Two SQLite changes survive the first screen: avoid transcoding text which is
already UTF-8, and fill multi-column row Arrays at their known size. Neither
changes Rails. PostgreSQL's tempting length-before-NULL shortcut loses badly
on NULL and empty fields and is rejected. Trilogy and mysql2 already have the
obvious encoding/name caches. The coordinator opened DRV1 as draft
[#769](https://github.com/sparklemotion/sqlite3-ruby/pull/769); this measurement
thread has taken no upstream action.

**Checkpoint:** candidate interpreter/YJIT cohorts and the complete interpreter
census are published below. The broad YJIT baseline census is still running;
large fully cast model warmups take several minutes per fresh process under
Valgrind. No incomplete baseline is described as accepted. The two candidate
YJIT prices come from separate completed, controlled cohorts.

**Review follow-up:** DRV1's test-only head has exact-head skeptic, Sol and
Astra passes. DRV2's original resize head grows native buffers on Ruby 3.2/3.3
and is superseded. The corrected head matches main's row memory on Ruby
3.2/3.3/3.4 and passes the revised whole-model-load gate: **−2.6910% YJIT Ir**
for 1,000 seven-column records through normal `to_a`. The skeptic confirmed
its final measurements and body; coordinator Sol/Astra confirmations remain.
The original `select_all` result alone was not sufficient.

## Sources and overlap checked first

All drivers were built from the maintainers' current default branch, not a
released binary gem. The default heads and open PR lists were checked again
before preparing the handoff.

| Source | Measured commit |
|---|---|
| Ruby 4.0.9 | `3e93b23afcec3433f6aecc34b5d832799d754238`, x86_64-linux, Prism |
| Rails main | `1e235cee11b0a7aecb189d8837534807626287aa` |
| [sqlite3-ruby main](https://github.com/sparklemotion/sqlite3-ruby) | `48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0` |
| [pg master](https://github.com/ged/ruby-pg) | `9754680861354eaa5799878d3e4f2cacb892a3e4` |
| [trilogy main](https://github.com/trilogy-libraries/trilogy) | `518b2d51d5b4dd7571e3bd95fb7322fb7653f283` |
| [mysql2 master](https://github.com/brianmario/mysql2) | `42e6eeb1c1b5aa1cc5e7396977c5c576b40ccc91` |

SQLite uses system SQLite 3.40.1, threadsafe build. PostgreSQL is 15; the two
MySQL clients use the same local MariaDB 10.11 server. PostgreSQL and MariaDB
run outside the measured Ruby process; SQLite's engine runs inside it. The
driver totals therefore **are not a ranking of database engines**.

Existing work excludes several attractive-looking leads:

* SQLite [#768](https://github.com/sparklemotion/sqlite3-ruby/pull/768) owns
  moving `Statement#to_a` to C; [#528](https://github.com/sparklemotion/sqlite3-ruby/pull/528)
  owns releasing the GVL in `step`. Neither was duplicated. Our merged
  [#758](https://github.com/sparklemotion/sqlite3-ruby/pull/758) is already in
  the baseline. Flavorjones and tenderlove are the intended reviewers of the
  two independent candidates below.
* pg already interns field-name Strings and converts the built-in numeric and
  timestamp types in C. `TypeMapByOid` already fits a column map above ten
  rows, avoiding an OID lookup for every cell. Open
  [#768](https://github.com/ged/ruby-pg/pull/768),
  [#766](https://github.com/ged/ruby-pg/pull/766) and
  [#763](https://github.com/ged/ruby-pg/pull/763) cover numeric caching and
  timestamp work; those belong to larskanis's existing review queue.
* Trilogy caches charset-to-Ruby encodings and interns result names when
  requested. Rails enables that mode. Its current open PRs include Ractor and
  connection work, not another missing per-cell encoding cache. Rails' Trilogy
  adapter refuses prepared statements: there is no prepared Trilogy cell.
* mysql2 already caches charset encodings, materializes metadata once, and has
  string-only conversion loops. Open
  [#1605](https://github.com/brianmario/mysql2/pull/1605) owns local DATETIME
  conversion; result lifetime and statement safety also have active PRs.

## What each boundary measures

The same 1,000-row fixture has asymmetric IDs/names, negative integers,
microsecond timestamps, text of several hundred bytes, alternating NULL/empty
values and binary `00 ff` payloads. Narrow rows select ID/name; wide rows select
all seven columns. Shapes are ID lookup, 20 and 1,000 narrow/wide rows, and a
1,000-value integer `pluck`. The UTF-8 candidate adds a 20-name `IN` lookup.
Queries and schemas are warmed; Rails' query cache is disabled.

Three operations share each fixture and query:

1. **Driver API:** execute/reset, bind, materialize the rows and names/types,
   release the result. A prepared driver statement is reused; an unprepared
   one is prepared and closed per operation where the API requires it.
2. **Adapter:** `select_all(arel).rows`, including SQL/bind preparation,
   instrumentation, result wrapping and `cast_result`.
3. **Active Record:** finder or relation load, followed by every record's
   `attributes` to force lazy casts; `pluck` uses the real public method.

These are observable API boundaries, not three additive stack frames.
Adapter-minus-driver includes adapter-owned work that the raw call omits;
model-minus-adapter includes relation/finder work as well as instantiation and
casting. A finder also uses Rails' own LIMIT/statement-cache path rather than
the prebuilt raw Arel. Do not subtract that row to claim an exact finder tax.
Rails' mysql2 prepared setting does not imply every adapter query uses the
same native statement path as a direct prepared driver call.
The pg raw endpoint uses `exec_prepared`/`exec_params`; Rails uses its own
`send_query*`/`get_result` orchestration and may use the simple protocol for an
unprepared, bind-free query. Those protocol/waiting differences are not a pure
`ActiveRecord::Result` allocation tax.

Most importantly, **the raw connection is not always pure C**. Rails installs
Ruby decoder callbacks in pg. In the unprepared wide 1,000-row interpreter
profile, `PG::Result#values` is 76.36% of raw-query instructions; the Ruby
decoder bridge is 23.71%, including 19.20% below `rb_funcallv` for Rails'
`ByteaMarker`. That belongs to adapter policy even though the driver invokes
it. It was not relabeled as native-driver conversion or built into a Rails PR.

For comparison, SQLite's native `step` accounts for 86.76% of its wide-row raw
profile, including 20.69% in the SQLite engine's `sqlite3_step`. Trilogy's C
query entry accounts for 99.59%, with 58.95% in value conversion. These are
inclusive call-tree samples, not additive percentages or cross-driver speed
claims. The SQLite sample uses the original 30-operation diagnostic cohort;
the other two use five operations. Allocation/heap admission is separate.

## Measurement and controls

The worker extends the existing
[`refresh_window.rb`](../../bench/upstream/census_backlog/refresh_window.rb),
not a replacement benchmark framework. The existing
[`percall.sh`](../../bench/upstream/perf_round/percall.sh) used for PM1/PM3/CB2
also independently measures the UTF-8 bind query. Sources, entry points and
commands are in [`driver_cpu/README.md`](../../bench/upstream/driver_cpu/README.md).

* Each cohort has three fresh **base / same-base A/A / candidate** processes,
  or three base/A/A pairs for the baseline census. No baseline is borrowed
  across Ruby pins or driver variants.
* Interpreter windows warm 50 operations at a time. YJIT windows warm 667 at a
  time; three consecutive compilation-flat windows are required, with at most
  50 attempts. Every measured window records compiled ISeqs, blocks and
  invalidations before/after. A compilation during measurement rejects it.
* Five operations per counted window, GC disabled only inside that window.
  `HeapWindows.prepare_heap` prepares all five size pools with slot floors
  1,000,000 / 250,000 / 100,000 / 20,000 / 10,000. Before/after capacities and
  cross-arm matching must stay within one page per pool.
  Allocation figures count Ruby objects, not every native allocator call in
  SQLite/libpq/the MySQL clients; retained row-buffer memory is checked
  separately in the supported-Ruby correction below.
* Callgrind uses start/stop client requests and a 512-MB-brk build of Valgrind.
  Instructions come from each dump's **`totals:`**, not its incremental
  `summary:` header. Counts include Ruby allocation/conversion runtime work
  reached by the measured operation; they exclude boot and external servers.
  The same counter/JIT-observer framing is included in every window, not
  subtracted as an estimated overhead.
  That framing is mode-dependent and proportionally larger for tiny queries;
  absolute cross-mode totals are not a standalone YJIT speed comparison.
* The three paired process ratios have a deterministic paired bootstrap
  interval. The prospective micro A/A rule is zero containment and the whole
  interval inside ±0.5%. Three processes provide a coarse control, not a
  high-precision confidence claim. Rejected cohorts stay in the export.
* Native YJIT uses the same worker without the Callgrind extension for the
  UTF-8 query's allocation check. No wall-time improvement is claimed.

All **63 accepted selected-candidate YJIT window profiles** were also inspected for
actual compiler-entry/code-generation work: none contains it. Rejected
wide20/`pluck` profiles do contain `gen_single_block` and compiler-entry work,
which confirms the negative control; a tiny `yjit_compile` threshold check or
the generated-code runtime `is_proc` helper is not compilation.

The first SQLite prepared census used 30 operations and grew heaps in some
large model loads. It is diagnostic only. Five operations are the recorded
protocol revision, not pooled with it. PostgreSQL's wide model still grows
pool 4 from about 10,182 to 13,436 slots and is rejected. Some other cells fail
A/A or JIT-flatness; their raw counts remain observations, not accepted prices.
Two completed early command wrappers exited on a trailing shell typo *after*
writing all samples; their data completeness is checked independently, and
those shell commands are not described as successful runs.

Receipts: [summary and raw-data index](data/driver-cpu/README.md),
[per-process summary](data/driver-cpu/summary.json),
[source/binary provenance](data/driver-cpu/provenance.json),
[raw receipts](data/driver-cpu/receipts.tar.gz) and
[expanded exactness observations](data/driver-cpu/sqlite-exact.json.gz).

## Baseline: query cost and row cost

The complete interpreter census has **126 cells, 78 accepted**. The table
keeps rejected cells visible. A cell marked **†** is a diagnostic observation
only: at least one of A/A, heap or completeness gates failed. The numerical
export retains the individual process counts and reasons. Prepared `1` means
the connection's prepared setting is enabled, with the API caveats above.

<details>
<summary>All interpreter shapes: instructions / objects per query</summary>

| Driver / prepared | Shape | Driver Ir / objects | Adapter Ir / objects | AR Ir / objects |
|---|---|---:|---:|---:|
| sqlite3 / 1 | find | 27,867 / 12† | 255,774 / 41† | 434,374 / 86† |
| sqlite3 / 1 | narrow 20 | 92,399 / 47 | 334,662 / 77† | 2,210,984 / 546† |
| sqlite3 / 1 | narrow 1,000 | 3,620,154 / 2,007† | 3,864,636 / 2,037 | 90,352,965 / 24,066 |
| sqlite3 / 1 | wide 20 | 185,267 / 117 | 428,963 / 147† | 2,792,947 / 767 |
| sqlite3 / 1 | wide 1,000 | 8,144,390 / 5,507 | 8,398,478 / 5,537 | 118,763,135 / 35,067 |
| sqlite3 / 1 | pluck 1,000 | 2,735,852 / 1,007† | 2,965,627 / 1,037 | 4,257,127 / 1,068 |
| sqlite3 / 0 | find | 125,525 / 18 | 320,678 / 37 | 518,264 / 88 |
| sqlite3 / 0 | narrow 20 | 153,793 / 53 | 353,190 / 73 | 2,229,173 / 542† |
| sqlite3 / 0 | narrow 1,000 | 3,679,592 / 2,013 | 3,879,049 / 2,033 | 90,368,923 / 24,062† |
| sqlite3 / 0 | wide 20 | 294,584 / 123 | 498,357 / 143 | 2,862,488 / 763† |
| sqlite3 / 0 | wide 1,000 | 8,250,876 / 5,513† | 8,451,625 / 5,533 | 118,828,652 / 35,063† |
| sqlite3 / 0 | pluck 1,000 | 2,783,226 / 1,013† | 2,971,543 / 1,033† | 4,263,661 / 1,064 |
| pg / 1 | find | 27,049 / 8† | 309,238 / 38 | 490,041 / 85 |
| pg / 1 | narrow 20 | 45,882 / 44 | 313,044 / 75 | 2,189,657 / 544 |
| pg / 1 | narrow 1,000 | 1,466,644 / 2,004 | 1,733,644 / 2,035 | 88,226,515 / 24,064 |
| pg / 1 | wide 20 | 133,982 / 114† | 432,361 / 145 | 2,819,446 / 805 |
| pg / 1 | wide 1,000 | 5,656,414 / 5,504 | 5,952,075 / 5,535 | 117,413,391 / 37,065† |
| pg / 1 | pluck 1,000 | 928,507 / 1,004 | 1,175,290 / 1,035 | 2,467,669 / 1,066 |
| pg / 0 | find | 27,155 / 8 | 274,004 / 31 | 472,595 / 84 |
| pg / 0 | narrow 20 | 45,552 / 44 | 270,956 / 68 | 2,148,054 / 537† |
| pg / 0 | narrow 1,000 | 1,465,440 / 2,004† | 1,690,850 / 2,028† | 88,197,760 / 24,057 |
| pg / 0 | wide 20 | 133,705 / 114† | 391,487 / 138 | 2,778,925 / 798 |
| pg / 0 | wide 1,000 | 5,656,329 / 5,504 | 5,910,880 / 5,528† | 117,393,022 / 37,058† |
| pg / 0 | pluck 1,000 | 928,110 / 1,004 | 1,135,654 / 1,028 | 2,428,184 / 1,059 |
| trilogy / 0 | find | 26,977 / 11† | 221,493 / 39† | 379,030 / 87† |
| trilogy / 0 | narrow 20 | 39,329 / 46† | 252,727 / 75 | 2,100,003 / 541† |
| trilogy / 0 | narrow 1,000 | 1,054,265 / 2,006 | 1,274,844 / 2,035† | 86,890,785 / 24,061† |
| trilogy / 0 | wide 20 | 81,110 / 116† | 282,885 / 145† | 2,535,089 / 762† |
| trilogy / 0 | wide 1,000 | 2,871,872 / 5,506 | 3,074,485 / 5,535† | 109,381,151 / 35,062† |
| trilogy / 0 | pluck 1,000 | 790,709 / 1,006 | 1,003,038 / 1,035 | 2,295,265 / 1,066 |
| mysql2 / 1 | find | 45,610 / 23 | 258,955 / 52 | 402,507 / 95 |
| mysql2 / 1 | narrow 20 | 70,111 / 53 | 312,427 / 83 | 2,161,400 / 550 |
| mysql2 / 1 | narrow 1,000 | 1,973,329 / 2,013† | 2,216,962 / 2,043 | 87,823,058 / 24,070 |
| mysql2 / 1 | wide 20 | 166,968 / 128 | 396,661 / 158 | 2,649,316 / 776† |
| mysql2 / 1 | wide 1,000 | 6,314,190 / 5,518 | 6,540,603 / 5,548 | 112,834,410 / 35,076† |
| mysql2 / 1 | pluck 1,000 | 1,399,137 / 1,012 | 1,629,736 / 1,042 | 2,921,495 / 1,073† |
| mysql2 / 0 | find | 60,768 / 22 | 246,907 / 45† | 405,216 / 94 |
| mysql2 / 0 | narrow 20 | 75,249 / 52† | 279,885 / 76 | 2,129,243 / 543 |
| mysql2 / 0 | narrow 1,000 | 1,853,454 / 2,012 | 2,058,166 / 2,036 | 87,675,036 / 24,063 |
| mysql2 / 0 | wide 20 | 141,514 / 127† | 335,638 / 151† | 2,588,868 / 769† |
| mysql2 / 0 | wide 1,000 | 4,304,859 / 5,517† | 4,496,847 / 5,541 | 110,804,522 / 35,069† |
| mysql2 / 0 | pluck 1,000 | 1,467,875 / 1,011 | 1,663,245 / 1,035 | 2,955,726 / 1,066† |

</details>

The per-row increment is the 1,000-row minus 20-row query cost, divided by
980. Only pairs with both instruction controls accepted are priced below;
this is a two-shape slope, not a universal linear model for every query.

| Interpreter path | Extra Ir / row | Extra objects / row |
|---|---:|---:|
| pg prepared, narrow driver | 1,449.8 | 2 |
| pg prepared, narrow adapter | 1,449.6 | 2 |
| pg prepared, narrow fully cast model | 87,792.7 | 24 |
| pg prepared, wide adapter | 5,632.4 | 5.5 |
| SQLite prepared, wide driver | 8,121.6 | 5.5 |
| SQLite prepared, wide fully cast model | 118,336.9 | 35 |
| mysql2 prepared, narrow adapter | 1,943.4 | 2 |
| mysql2 prepared, narrow fully cast model | 87,409.9 | 24 |
| mysql2 unprepared, narrow adapter | 1,814.6 | 2 |
| mysql2 unprepared, narrow fully cast model | 87,291.6 | 24 |

**The driver is the first cost, not always the dominant one.** In the accepted
prepared pg 1,000-row narrow load, the raw boundary is 1.66% of the forced-model
instruction total, additional adapter work 0.30%, and remaining relation/model
work 98.04%. For SQLite's accepted wide 1,000-row load those shares are 6.86%,
0.21% and 92.93%. Allocation growth similarly goes from about 2 to 24 objects
per narrow row, or 5.5 to 35 per SQLite wide row. This deliberately forces all
selected attributes; applications that leave casts lazy do less work.

`pluck` changes the balance: pg's accepted prepared query has 928,507 raw,
1,175,290 adapter and 2,467,669 total instructions, with 1,004 / 1,035 / 1,066
objects. The client row loop is then 37.63% of query instructions and the
dominant allocation source. That is why a driver change can move a complete
`select_all` or `pluck` while becoming small in a fully cast model load.

The narrow raw-driver allocation counts fit two objects per returned row
(Array and name String), plus 7 per query for prepared SQLite, 13 for
unprepared SQLite, 4 for pg, 6 for Trilogy, and 13/12 for prepared/unprepared
mysql2. These are this warmed fixture's observed totals, including wrappers
and metadata, not a promise for arbitrary types or result modes. pg's
one-row result uses a different type-map path. Adapter materialization adds
roughly 20–31 objects per query, rather than another object for every cell.

## DRV1: bind UTF-8 text without making a Ruby copy

`!UTF8_P(value) || !USASCII_P(value)` is always true. Passing UTF-8 text through
`rb_str_encode` therefore makes an unnecessary Ruby String before SQLite takes
its own `SQLITE_TRANSIENT` copy. Test only `!UTF8_P(value)`. US-ASCII still
transcodes, including its existing invalid-byte error; BLOB and UTF-16 branches
are untouched. The input remains unmodified and SQLite still owns its copy.

Reach: every UTF-8 SQLite text parameter, in direct-driver applications and
ordinary Rails queries. A 20-name lookup is a query-level example, not a
measured frequency or a claim about an entire request.

| Accepted operation | Before Ir | After Ir | Paired change | Objects before / after |
|---|---:|---:|---:|---:|
| Interpreter raw driver | 265,436 | 256,393 | −3.4060% | 47 / 27 |
| Interpreter `select_all` | 951,398 | 942,396 | −0.9463% | 129 / 109 |
| Interpreter `pluck` | 1,092,175 | 1,083,184 | −0.8232% | 162 / 142 |
| YJIT raw driver | 262,171 | 253,176 | −3.4309% | 47 / 27 |
| YJIT `select_all` | 683,135 | 674,319 | −1.2681% | 130 / 110 |

The YJIT `pluck` Callgrind cohort **rejects** for compilation and A/A; its
apparent instruction delta is not a speed result. Native YJIT, three fresh
base/A/A/head groups with unchanged heaps and flat JIT counters, independently
confirms **163 → 143 objects** for that complete `pluck`, and **93 → 92** for a
single-name finder. The one-name instruction cohort establishes no gain.
The original `percall.sh` batch-20 check reports 162.03 → 142.03 objects and
approximately 1,081,088 → 1,071,816 Ir per query; it is a separate, corroborating
protocol, not pooled with the fixed-heap worker.

Branch: [`thomasklemm/skip-utf8-bind-transcode`](https://github.com/thomasklemm/sqlite3-ruby/tree/thomasklemm/skip-utf8-bind-transcode),
head [`c55ce350e32f4cf05ff7f7680120d011e84eba59`](https://github.com/thomasklemm/sqlite3-ruby/commit/c55ce350e32f4cf05ff7f7680120d011e84eba59).
Queue body: [DRV1](../../bench/upstream/pr-queue/items/DRV1.md).
The measurements used predecessor `b2735e1a77`; the follow-up changes only
tests, with identical C source and native binary. Its engine-independent tests
cover malformed UTF-8 (`ff`, truncated `e2 82`), frozen inputs, TEXT type and
exact returned bytes, plus mutation after binding. The skeptic independently
ran both new tests on base/head with literal freezing both enabled and
disabled (2 runs / 13 assertions in each). No alternate Ruby engine was run.

## DRV2: fill a multi-column row at its final length

The tables below price the **original resize head**, not the replacement.
That head is held after Astra's supported-Ruby finding. No new-head speed
claim or opening decision is derived from these tables.

`Statement#step` already allocates capacity for the known column count, but
`rb_ary_store` updates the row length for each value. Resize a multi-column row
once and use `RARRAY_ASET`, retaining its write barriers. Single-column rows
keep `rb_ary_store`: unconditional resizing regresses `pluck`.

Reach: every SQLite result row with two or more columns, including default
Rails model loads. The selected change has no allocation saving. A large raw
driver percentage does not imply the same percentage after model casting.

| Accepted interpreter operation | Before Ir | After Ir | Paired change | Objects |
|---|---:|---:|---:|---:|
| 1,000 narrow rows, raw driver | 3,620,138 | 3,580,135 | −1.1050% | 2,007 |
| 20 wide rows, `select_all` | 428,852 | 421,570 | −1.7245% | 147 |
| ID finder, attributes forced | 434,613 | 433,701 | −0.2097% | 86 |
| 1,000-value `pluck` | 4,255,400 | 4,256,264 | +0.0179% | 1,068 |

The 1,000-wide-row adapter instruction cohort rejects because its A/A interval
does not contain zero; its apparent −4.19% is **not** an accepted gain. The
full wide model load does not establish an instruction improvement either
(candidate interval crosses zero). Keep the small single-column overhead
visible rather than describing this as a uniform improvement.

| Accepted YJIT operation | Before Ir | After Ir | Paired change | Objects |
|---|---:|---:|---:|---:|
| 1,000 narrow rows, raw driver | 2,938,552 | 2,898,393 | −1.3657% | 2,007 |
| 1,000 wide rows, `select_all` | 7,549,104 | 7,195,944 | **−4.6782%** | 5,538 |

The accepted wide-query A/A interval is [−0.01984%, +0.12874%]; the candidate
interval is [−4.84470%, −4.65312%]. The small wide-query YJIT window recompiles;
finder and `pluck` YJIT cohorts reject A/A. Those observations are retained,
not repeated until green. There is no full-model YJIT gain claim.

Branch: [`thomasklemm/fill-multicolumn-rows`](https://github.com/thomasklemm/sqlite3-ruby/tree/thomasklemm/fill-multicolumn-rows),
head [`36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b`](https://github.com/thomasklemm/sqlite3-ruby/commit/36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b).
Queue body: [DRV2](../../bench/upstream/pr-queue/items/DRV2.md). The initial
skeptic approved, but Astra's later finding supersedes that opening decision.

### Supported-Ruby correction and relevance gate

On Ruby 3.2.9 and 3.3.10, `rb_ary_resize` grows storage when the requested
length equals capacity. This affects exactly-full embedded Arrays as well as
heap-backed rows. Ruby 3.4.8 avoids that growth. Initialize the last slot with
`rb_ary_store(list, length - 1, Qnil)` instead, inside the existing `length > 1`
guard, then retain write-barrier-aware `RARRAY_ASET` for the actual values.

Replacement head:
[`10b25aa99e9c1778a6bfc35f661d5ab6f28ec42e`](https://github.com/thomasklemm/sqlite3-ruby/commit/10b25aa99e9c1778a6bfc35f661d5ab6f28ec42e).
The [native-memory export](data/driver-cpu/native-memory.json) retains all
widths, runtime/archive hashes and binary hashes; its probe is in the receipts.

Independent builds of main, the original resize head and the replacement
were run on each Ruby. Eighteen widths from 1 through 2,000 cover embedded and
heap boundaries; values, frozen state and results retained through compaction
are checked. All **54 main/replacement width pairs** have identical retained
row memory and embedding. Example total Array/native-buffer bytes:

| Ruby | Width | Main | Resize head | Replacement |
|---|---:|---:|---:|---:|
| 3.2.9 / 3.3.10 | 3 | 40 | 192 | 40 |
| 3.2.9 / 3.3.10 | 8 | 80 | 272 | 80 |
| 3.2.9 / 3.3.10 | 80 | 680 | 1,000 | 680 |
| 3.2.9 / 3.3.10 | 2,000 | 16,040 | 24,040 | 16,040 |
| 3.4.8 | 80 | 680 | 680 | 680 |
| 3.4.8 | 2,000 | 16,040 | 16,040 | 16,040 |

`GC.stat(:malloc_increase_bytes)` is retained as a diagnostic, not an exact
allocation-count oracle: allocator rounding differs even at the same retained
size. The first probe draft repeatedly doubled the heap at every width and
exhausted memory on **main** before producing observations. The corrected
probe uses ordinary compaction; no driver or benchmark gate was changed.
The running benchmark processes were checked and remained alive.

The replacement's Ruby 4.0.9 interpreter/YJIT suites each pass **428/873**, and
both compaction differentials match all **651** baseline observations. A fresh
finite cohort measures normal `relation.spawn.to_a` model loads at 20/1,000
narrow/wide rows, without the census's forced `attributes` casts, plus adapter
and single-column controls. It is an explicit new workload and changed-head
measurement, not another attempt to turn an unchanged rejected cell green.

The revised **whole-model-load gate passes** in both interpreter and YJIT:

| Accepted replacement operation | Before Ir | After Ir | Paired change | Objects |
|---|---:|---:|---:|---:|
| Interpreter, 20 narrow models | 837,498 | 836,678 | −0.1313% | 226 |
| Interpreter, 20 wide models | 944,157 | 936,797 | −0.7800% | 297 |
| Interpreter, 1,000 wide models | 27,190,830 | 26,834,750 | **−1.2725%** | 11,567 |
| Interpreter, 1,000-wide `select_all` | 8,398,761 | 8,042,188 | −4.1251% | 5,537 |
| YJIT, 20 narrow models | 354,987 | 354,331 | −0.1974% | 227 |
| YJIT, 1,000 wide models | 13,019,464 | 12,667,677 | **−2.6910%** | 11,568 |
| YJIT, single-column `pluck` | 2,456,847 | 2,457,645 | **+0.0367%** | 1,069 |

For 1,000 wide models, interpreter A/A is [−0.01002%, +0.03900%], candidate
[−1.31825%, −1.27163%]; YJIT A/A is [−0.06497%, +0.01142%], candidate
[−2.72425%, −2.62638%]. All heaps match and measured windows are JIT-flat;
accepted YJIT call graphs contain no compiler-entry/code-generation work.
These are complete default lazy-attribute model loads, **not** the larger
fully cast loads in the census and not whole-request or elapsed-time savings.

Keep the small `pluck` overhead visible. Narrow 1,000-model loads reject A/A
in both modes (and compile under YJIT). YJIT 20-wide model loads reject A/A,
JIT-flatness and heap matching; YJIT wide `select_all` rejects A/A/JIT-flatness.
Interpreter `pluck` rejects A/A. Those cells stay rejected, not remeasured.

## Exactness and own suites

The driver changes are built independently against the same SQLite main, not
stacked. The loaded native feature and binary hashes were checked: Ruby 4.0
can prefer `lib/sqlite3/4.0/sqlite3_native.so`, so rebuilding only the unversioned
file would silently test the wrong extension.

The independent base/head probe compares values, classes, bytes, encodings,
validity, frozenness, input mutation, retained bindings, row/field identity and
exceptions. It covers NULL, empty/invalid UTF-8 and US-ASCII, UTF-16 database
encodings, default internal encodings, BLOBs, embedded NUL, integer limits and
huge integers, frozen/subclassed Strings, 1–2,000 columns, GC stress,
compaction and four threads with separate connections.

* Base, UTF-8 head and row-fill head produce **651 identical observations** in
  interpreter and YJIT with compaction, SHA256
  `d1364a39f8c0c696125cfbcdda2aa5f5034f91167d0415d3b79bb2ad22252ec6`.
  The original probe's thread block captured an outer database local and only
  selected one column. The reviewer found that weakness; it was corrected to
  use a connection local to each thread, three columns and asymmetric thread
  values, then all six base/head/mode probes were rerun. The prior probe's
  digest, independently reproduced by both reviewers, was
  `72f4ee77c3d664cbf38bd88bee1730c79453f15bee240fccc8b837cf180c75c9`.
* A separate end-to-end Active Record differential retains results through
  compaction, re-executes all **24 API operations**, and compares typed values,
  encodings and frozen state across both candidate heads, both prepared
  settings and interpreter/YJIT. All twelve runs match digest
  `9ce1cf7b352385279140760a13ceb182de253fb0e8946e854e016a32a2e65f08`.
* DRV1's skeptical reviewer independently reran the original observations under
  YJIT/compaction and added **225** adversarial observations, digest
  `0fdc35fe9ca985947a31cdd0288195679e35b65c17a42295a2d2a080fb1c97b2`.
  Hostile String overrides are not invoked; mutating inputs after binding
  still leaves SQLite's copy intact. No difference was found.
* DRV2's skeptical reviewer added **238** independent observations under both
  interpreter and YJIT, digest
  `725f0aa8265d6910a2b5a4ea791e138dc9b1f88a0824ae67f78329d5297f0dc4`.
  Those include 28 widths, float bit patterns and limits, callback/error
  boundaries, internal-encoding mutation, retained rows during GC stress and
  compaction, plus multi-column threads with separate and shared connections.
* DRV1 follow-up own suites, interpreter and YJIT with compaction verification:
  **432 runs, 891 assertions, zero failures/errors, 12 skips** in each mode.
  Its allocation regression fails against base (one temporary object) and
  passes against head (none). The measured predecessor passed 430/878.
* DRV2 own suite, compaction verification: **428 runs, 873 assertions, zero
  failures/errors, 12 skips**. Existing result tests plus the independent
  differential cover the row-fill refactor; no incidental private-helper test
  was added.

DRV1's new-head skeptic approves the code and short body; the footer resolves
publicly. Sol confirmed with no fixes and Astra approved the exact follow-up
head; the coordinator opened draft #769. DRV1 is L0.
DRV2's initial L1 approval is superseded by Astra's supported-Ruby finding;
the corrected head's skeptic independently reproduced the memory fix and
matched **152 adversarial observations** across Ruby 3.2/3.3/3.4/4.0.9, digest
`289e058d7dcbbd5977b485bf400f43576f6641801e88fca40a3ec307068a5dea`.
It checked 110 widths, retained rows before/after compaction and GC stress
during cell creation, with no correctness/native-memory blocker, L1. It then
independently recomputed the final model-load results from JSONL/Callgrind
totals, checked all 108 measurement windows and 27 accepted YJIT call graphs,
and approved the relevance gate and public body on the corrected head.
The requested supporting exports are included; coordinator Sol/Astra
confirmations remain. Ruby Flog/RuboCop metrics do not apply to these C changes.
The pushed fork heads report **no CI checks**, not green CI. These Linux runs
do not certify every SQLite/Ruby/platform combination or include sanitizers. As in DECISIONS'
exactness boundary, reaching unfinished internal Arrays through ObjectSpace
is not a supported observer.

## Rejected or already-owned leads

| Lead | Decision |
|---|---|
| pg: test field length before NULL | Reject: populated-field `pluck` −1.052%, but NULL-heavy raw driver **+16.574%**, NULL `pluck` **+2.091%**, empty-field raw **+5.207%**, empty `pluck` **+0.896%**; no PR item. |
| SQLite: replace `rb_ary_store` with push | Reject: narrow driver **+0.386%**; updating length through push is not a free append. |
| SQLite: resize every row, including one column | Reject: wide raw driver −4.473%, but single-column `pluck` **+0.241%**; DRV2 retains the existing one-column path. |
| SQLite: share/freeze more column-name Strings | Not built: names are per statement, not per row; sharing mutable names changes observable identity/frozenness. |
| pg: cache every per-cell type-map lookup | Already done: results above ten rows use a fitted column map; custom maps/callbacks must keep their semantics. |
| Trilogy/mysql2: repeated encoding lookup | Already cached on current main; removing default-internal checks would change mid-query conversion behavior. |
| Result-wrapper pooling | Not built: retained results, mutation, explicit clear/free and concurrent queries make identity/lifetime observable; no exact large win demonstrated. |
| SQLite: unprotected VALUE stores or remove mutex/GVL work | Not built: write barriers and synchronization are correctness requirements, not dispensable overhead. |
| pg: numeric/timestamp conversion | Existing open PRs; do not duplicate. |
| Rails pg ByteaMarker / Rails main compatibility | Inventory only; no Rails adapter changes or compatibility fixes this round. |

The rejected pg variant nevertheless matches **94** differential observations,
digest `f79a49868b7accd833d1760d3c53082c6cedfa7015cac40f4eb8f5fb80284b62`.
Its own suite is not claimed green: three `:arch64` examples request multi-GB
objects and exhaust this orb on both arms. Serial base/head runs excluding
that tag have 1,122/1,123 examples, the same eight local service/conninfo
failures and four pending. Earlier parallel test servers conflicted on ports;
only the corrected serial comparison informs this inventory. No service or
Rails compatibility workaround was made into a candidate.
