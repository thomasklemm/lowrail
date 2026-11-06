# Database driver CPU: where the rows cost work

Bet P-DRV, 2026-11-05–06. Ruby **4.0.9**, interpreter and YJIT. This is a
client-side query study, not database-server latency or a request benchmark.

Two SQLite changes survive the controls and relevance gates: avoid transcoding
text which is already UTF-8, and fill multi-column row Arrays at their known
size. Neither changes Rails. PostgreSQL's tempting length-before-NULL shortcut loses badly
on NULL and empty fields and is rejected. Trilogy and mysql2 already have the
obvious encoding/name caches. The coordinator opened drafts
[#769](https://github.com/sparklemotion/sqlite3-ruby/pull/769) and
[#770](https://github.com/sparklemotion/sqlite3-ruby/pull/770); this measurement
thread has taken no upstream action. No further candidate cleared the
whole-workload gate.

**Complete census:** all four drivers, seven supported prepared/unprepared
settings and six shapes at three API boundaries: **126 cells per mode**.
Interpreter admits **78**; YJIT admits **63**. Every rejection is retained,
not rerun until green. The candidate prices come from separate completed,
controlled cohorts; the census is not a cross-engine or latency ranking.

**Review follow-up:** DRV1's test-only head has exact-head skeptic, Sol and
Astra passes. DRV2's original resize head grows native buffers on Ruby 3.2/3.3
and is superseded. The corrected head matches main's row memory on Ruby
3.2/3.3/3.4 and passes the revised whole-model-load gate: **−2.6910% YJIT Ir**
for 1,000 seven-column records through normal `to_a`. The skeptic confirmed
its final measurements, body and TruffleRuby guard; the coordinator reports
Sol and Astra approval on the exact guarded head, now draft #770.
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

The boundary matters even more in the accepted **YJIT** SQLite windows.
For 1,000 seven-column rows, native `Statement#step` is over half the ordinary
lazy-attribute model load, but only about a tenth after forcing all casts:

| Query boundary | Ir / query, one window | Native `step` share | Contained SQLite engine `sqlite3_step` share |
|---|---:|---:|---:|
| `select_all` | 7,547,562 | 93.57% | 22.23% |
| Ordinary `relation.spawn.to_a` | 13,020,521 | 54.33% | 12.97% |
| Load plus every record's `attributes` | 65,932,863 | 10.73% | 2.56% |

These are inclusive shares inside individual accepted query profiles, not
component-level A/A prices or additive percentages. `step` includes its Ruby
allocation runtime and the contained SQLite engine work; the engine column
is a subset, not an extra cost. The ordinary-load profile is from the
corrected-head cohort's **base**, not from a rejected raw-driver cell. The
[attribution export](data/driver-cpu/profile-attribution.json) identifies the
three profiles and exact counters. This is why a fully cast census alone
understates the driver opportunity in normal lazy model loading.

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

The completed broad YJIT census adds **756 window profiles**. All **378**
profiles belonging to accepted query controls contain no compiler-entry or
code-generation work; **50** rejected profiles contain it. The
[profile audit](data/driver-cpu/jit-profile-audit.json) records every window,
its query-control verdict and matching compiler symbols. This supplements,
not replaces, the measured-counter and heap gates.

The first SQLite prepared census used 30 operations and grew heaps in some
large model loads. It is diagnostic only. Five operations are the recorded
protocol revision, not pooled with it. PostgreSQL's wide model still grows
pool 4 from about 10,182 to 13,436 slots and is rejected. Some other cells fail
A/A or JIT-flatness; their raw counts remain observations, not accepted prices.
Two completed early command wrappers exited on a trailing shell typo *after*
writing all samples; their data completeness is checked independently, and
those shell commands are not described as successful runs.
The SQLite YJIT wrapper later stopped at an already-owned PostgreSQL output
directory after finishing its two SQLite cohorts; the separate PostgreSQL
worker completed those cohorts. All seven YJIT census settings have complete
base/A/A receipts with three repetitions, not inferred success from wrappers.

Receipts: [summary and raw-data index](data/driver-cpu/README.md),
[per-process summary](data/driver-cpu/summary.json),
[source/binary provenance](data/driver-cpu/provenance.json),
[candidate/raw receipts](data/driver-cpu/receipts.tar.gz),
[YJIT census receipts](data/driver-cpu/yjit-receipts.tar.gz) and
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

### Complete YJIT census

The same six shapes and three API boundaries yield **63 accepted cells out
of 126**. As above, the AR column forces every record's `attributes`; it is
not the ordinary lazy-attribute `to_a` workload used for DRV2's relevance gate.
Each prepared setting has its own base/A/A control. These are endpoint
prices, not a separately paired prepared-versus-unprepared speed claim.

| Driver / prepared | Accepted / measured cells |
|---|---:|
| SQLite / 1 | 8 / 18 |
| SQLite / 0 | 12 / 18 |
| pg / 1 | 10 / 18 |
| pg / 0 | 11 / 18 |
| mysql2 / 1 | 9 / 18 |
| mysql2 / 0 | 7 / 18 |
| Trilogy / 0 | 6 / 18 |

All 63 rejected cells fail A/A: **44** fail A/A alone, **14** fail A/A plus
JIT-flatness only, **4** fail A/A plus heap matching only, and **1** fails all three.
No cell is incomplete. A **†** still means diagnostic only, including its
allocation observation; it is not an accepted instruction price.

<details>
<summary>All YJIT shapes: instructions / objects per query</summary>

| Driver / prepared | Shape | Driver Ir / objects | Adapter Ir / objects | AR Ir / objects |
|---|---|---:|---:|---:|
| sqlite3 / 1 | find | 55,683 / 12 | 192,248 / 42 | 962,630 / 86† |
| sqlite3 / 1 | narrow 20 | 121,493 / 47† | 238,650 / 78† | 1,103,146 / 547† |
| sqlite3 / 1 | narrow 1,000 | 2,939,945 / 2,007 | 3,034,251 / 2,038 | 46,220,324 / 24,067† |
| sqlite3 / 1 | wide 20 | 200,310 / 117 | 297,081 / 148 | 1,513,201 / 768† |
| sqlite3 / 1 | wide 1,000 | 7,468,740 / 5,507† | 7,548,149 / 5,538 | 65,878,031 / 35,068 |
| sqlite3 / 1 | pluck 1,000 | 2,063,878 / 1,007† | 2,168,145 / 1,038† | 2,487,383 / 1,069† |
| sqlite3 / 0 | find | 146,624 / 18 | 270,648 / 38 | 1,068,357 / 88† |
| sqlite3 / 0 | narrow 20 | 196,681 / 53† | 292,003 / 74 | 1,144,307 / 543 |
| sqlite3 / 0 | narrow 1,000 | 2,997,072 / 2,013 | 3,077,378 / 2,034 | 46,239,110 / 24,063 |
| sqlite3 / 0 | wide 20 | 308,781 / 123 | 387,484 / 144† | 1,604,783 / 764 |
| sqlite3 / 0 | wide 1,000 | 7,576,141 / 5,513† | 7,641,240 / 5,534† | 65,970,683 / 35,064 |
| sqlite3 / 0 | pluck 1,000 | 2,109,684 / 1,013 | 2,188,507 / 1,034† | 2,514,275 / 1,065 |
| pg / 1 | find | 57,128 / 8 | 220,849 / 39 | 984,120 / 85† |
| pg / 1 | narrow 20 | 103,308 / 44 | 239,627 / 76 | 1,021,623 / 545† |
| pg / 1 | narrow 1,000 | 1,496,606 / 2,004 | 1,609,364 / 2,036† | 41,603,896 / 24,065† |
| pg / 1 | wide 20 | 160,730 / 114 | 287,630 / 146 | 1,505,917 / 806† |
| pg / 1 | wide 1,000 | 5,275,352 / 5,504 | 5,395,586 / 5,536 | 62,015,590 / 37,066† |
| pg / 1 | pluck 1,000 | 964,228 / 1,004† | 1,078,964 / 1,036† | 1,414,277 / 1,067 |
| pg / 0 | find | 57,132 / 8† | 209,244 / 32 | 981,866 / 84† |
| pg / 0 | narrow 20 | 103,535 / 44 | 226,274 / 69 | 1,007,532 / 538 |
| pg / 0 | narrow 1,000 | 1,496,410 / 2,004 | 1,594,902 / 2,029 | 41,592,620 / 24,058† |
| pg / 0 | wide 20 | 159,828 / 114† | 273,894 / 139† | 1,492,907 / 799 |
| pg / 0 | wide 1,000 | 5,275,389 / 5,504 | 5,381,123 / 5,529 | 62,012,248 / 37,059† |
| pg / 0 | pluck 1,000 | 963,797 / 1,004 | 1,065,196 / 1,029 | 1,399,862 / 1,060† |
| mysql2 / 1 | find | 73,874 / 23 | 229,898 / 53† | 973,855 / 95† |
| mysql2 / 1 | narrow 20 | 146,149 / 53 | 263,190 / 84† | 1,075,560 / 551† |
| mysql2 / 1 | narrow 1,000 | 2,011,032 / 2,013 | 2,117,120 / 2,044 | 44,413,182 / 24,071† |
| mysql2 / 1 | wide 20 | 202,852 / 128 | 293,790 / 159 | 1,434,954 / 777† |
| mysql2 / 1 | wide 1,000 | 6,341,820 / 5,518 | 6,428,915 / 5,549† | 60,451,058 / 35,077† |
| mysql2 / 1 | pluck 1,000 | 1,456,627 / 1,012† | 1,553,917 / 1,043 | 1,882,175 / 1,074 |
| mysql2 / 0 | find | 86,467 / 22† | 218,449 / 46† | 1,003,202 / 94† |
| mysql2 / 0 | narrow 20 | 154,799 / 52† | 262,834 / 77 | 1,065,166 / 544† |
| mysql2 / 0 | narrow 1,000 | 1,892,210 / 2,012 | 1,977,113 / 2,037 | 44,228,486 / 24,064† |
| mysql2 / 0 | wide 20 | 176,063 / 127 | 256,282 / 152† | 1,396,559 / 770† |
| mysql2 / 0 | wide 1,000 | 4,334,719 / 5,517 | 4,410,648 / 5,542† | 58,381,201 / 35,070† |
| mysql2 / 0 | pluck 1,000 | 1,522,112 / 1,011† | 1,605,357 / 1,036 | 1,925,817 / 1,067 |
| trilogy / 0 | find | 57,104 / 11 | 286,143 / 40† | 1,045,527 / 87† |
| trilogy / 0 | narrow 20 | 107,197 / 46† | 307,116 / 76 | 1,039,986 / 542 |
| trilogy / 0 | narrow 1,000 | 1,090,119 / 2,006† | 1,215,697 / 2,036 | 43,431,416 / 24,062† |
| trilogy / 0 | wide 20 | 116,908 / 116 | 230,061 / 146† | 1,351,539 / 763† |
| trilogy / 0 | wide 1,000 | 2,899,544 / 5,506 | 3,002,632 / 5,545.6† | 56,925,389 / 35,063† |
| trilogy / 0 | pluck 1,000 | 844,374 / 1,006† | 999,240 / 1,036† | 1,353,544 / 1,067† |

</details>

Only slopes with both 20-row and 1,000-row controls accepted are priced:

| Accepted YJIT path | Extra Ir / row | Extra objects / row |
|---|---:|---:|
| sqlite3 prepared, wide adapter | 7,399.0 | 5.5 |
| sqlite3 unprepared, narrow adapter | 2,842.2 | 2 |
| sqlite3 unprepared, narrow fully cast model | 46,015.1 | 24 |
| sqlite3 unprepared, wide fully cast model | 65,679.5 | 35 |
| pg prepared, narrow driver | 1,421.7 | 2 |
| pg prepared, wide driver | 5,219.0 | 5.5 |
| pg prepared, wide adapter | 5,212.2 | 5.5 |
| pg unprepared, narrow driver | 1,421.3 | 2 |
| pg unprepared, narrow adapter | 1,396.6 | 2 |
| mysql2 prepared, narrow driver | 1,902.9 | 2 |
| mysql2 prepared, wide driver | 6,264.3 | 5.5 |
| mysql2 unprepared, narrow adapter | 1,749.3 | 2 |
| mysql2 unprepared, wide driver | 4,243.5 | 5.5 |
| trilogy unprepared, narrow adapter | 927.1 | 2 |
| trilogy unprepared, wide driver | 2,839.4 | 5.5 |

Only one YJIT 1,000-row census shape has all three boundary controls accepted:
SQLite unprepared, narrow rows. It records **2,997,072 / 3,077,378 /
46,239,110 Ir** for driver / adapter / fully cast model: approximately
**6.48%** raw boundary, **0.17%** additional adapter work and **93.34%**
remaining relation/model work. Other triples cannot be decomposed from
rejected endpoint prices. The within-profile attribution above explains why
normal lazy model loads expose much more driver work than this forced-cast
boundary does.

The census adds no new exact whole-workload winner. Repeated encoding/name
work is already cached in pg/Trilogy/mysql2 or has observable semantics;
the measured pg alternative remains rejected on NULL/empty workloads.
DRV1 and DRV2 stay the only built candidates handed to the coordinator.

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

### TruffleRuby initializer guard

Current fork head:
[`61fd4988d615a292e566caa3f042d0f263802dfe`](https://github.com/thomasklemm/sqlite3-ruby/commit/61fd4988d615a292e566caa3f042d0f263802dfe).
Astra found that TruffleRuby ignores requested Array capacity and implements
`RARRAY_ASET` through `rb_ary_store`. Its preliminary length store would add
one storage operation per row without removing any. Guard only that
initializer with `#ifndef TRUFFLERUBY`; both fill branches remain intact.

The macro is reliable, not an extconf heuristic: TruffleRuby revision
[`979bbdfbcc8894133b3452197bc8e2e188ad6360`](https://github.com/truffleruby/truffleruby/commit/979bbdfbcc8894133b3452197bc8e2e188ad6360)
[defines it unconditionally in public headers](https://github.com/truffleruby/truffleruby/blob/979bbdfbcc8894133b3452197bc8e2e188ad6360/lib/cext/include/ruby/internal/config.h#L159-L161),
which `<ruby.h>` includes, and
[documents it for C extensions](https://github.com/truffleruby/truffleruby/blob/979bbdfbcc8894133b3452197bc8e2e188ad6360/doc/user/compatibility.md#L28).
pg already uses `defined(TRUFFLERUBY)` in `ext/gvl_wrappers.h`.
TruffleRuby's [capacity implementation](https://github.com/truffleruby/truffleruby/blob/979bbdfbcc8894133b3452197bc8e2e188ad6360/lib/truffle/truffle/cext.rb#L1173-L1178)
and [cell-store implementation](https://github.com/truffleruby/truffleruby/blob/979bbdfbcc8894133b3452197bc8e2e188ad6360/lib/cext/include/ruby/internal/core/rarray.h#L403-L412)
confirm the original storage operations are retained there.

CRuby 4.0.9 preprocessed source is byte-identical before/after the two-line
guard (SHA256 `6b6a2bd3f29b7caf2636bdcb9f062506db1a619ccf7b5ccefd0e0a9b9b963cd3`),
independently reproduced by the skeptic. The accepted CRuby measurements
therefore carry forward without a new cohort, as requested by the coordinator.
Both rebuilt own suites again pass **428/873**, zero failures/errors, 12 skips.
The skeptic approves the exact new head and body, L1. No TruffleRuby runtime
was executed; its storage equivalence is source-derived, not a measured
TruffleRuby speed or compatibility claim. The coordinator reports Sol and
Astra approval on this exact head and opened draft #770; no further driver
code or queue-item change is part of the completed census.

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
Sol confirmed that head with a wording nit; Astra requested the TruffleRuby
guard above. The new-head skeptic, Sol and Astra passes are complete, and
the coordinator opened draft #770. Supporting exports include both follow-ups.
Ruby Flog/RuboCop metrics do not apply to these C changes.
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
