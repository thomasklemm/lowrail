# Rails-main CPU census 8: self instructions per workload

Census 8 ranks Rails source lines and methods by the **instructions they execute themselves** per workload,
instead of by allocated objects. Fewer objects do not always mean less CPU, and a Rails maintainer asked whether
allocation-only changes are worth it (fatkodima on [rails/rails#59577](https://github.com/rails/rails/pull/59577)).
The corpus is census 7's: 23 configurations, 20 apps, 251 workloads, on canonical Rails main, Ruby 4.0.9,
interpreter and YJIT, with an A/A pair. Objects stay as a second column, from an allocation census on the same pin.
Ruby master `9aa0898240` (the 4.1 pin) gets boot, list and interpreter/YJIT/ZJIT allocations with an A/A.

**Result.** Ranked by instructions, Rails main's hot code is mostly code that allocates nothing: **22 of the CPU top
30 lines allocate no objects**, and only 5 are in census 7's allocation top 30. The top CPU line is
`Inflector#apply_inflections` (15 apps, 1.21% of all interpreted instructions; allocation rank 93), then
`index_with` (covered by our open #59557), the generated Relation readers, `_load_from_sql`, attribute-set lines
(open #59141) and `IsolatedExecutionState.[]`. Most of the uncovered top tier is required work (SQL text, visitor
dispatch, driver values) or blocked by the review gates. One exact candidate came out of it:

| # | Branch | Per call, main → candidate (interp / YJIT / ZJIT) | Readability |
| --- | --- | --- | --- |
| C8-1 | [`thomasklemm/uri-regexp-anchor`](https://github.com/thomasklemm/rails/tree/thomasklemm/uri-regexp-anchor) [`84b0a308dc`](https://github.com/thomasklemm/rails/commit/84b0a308dc4c6ef9b75436d49cd54a67fad13169) | `asset_path("application.css")` 34,688 → 31,053 / 26,024 → 22,421 / 24,668 → 20,715 Ir | L0 |

In the census, C8-1 cuts its line's instructions by 35–47% in each of 8 apps; whole requests move by less than
the A/A (about 0.1% of an app's CPU). A second candidate, C8-2 (a constant instead of `WhereClause.empty` in the
generated readers), was faster interpreted but slower under YJIT and ZJIT, and was dropped.

Interpreter and YJIT on Ruby 4.0.9; ZJIT micros on master `9aa0898240`. Instruction counts only (Callgrind); no
timing is claimed. Ruby master ran boot, list and allocations with an A/A on 21 of 23 configurations
([below](#ruby-master-9aa0898240)).

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`1105756f42`](https://github.com/rails/rails/commit/1105756f426ee42834af5c87b4549ef709d631e5) (merge of #59580),
  checked with `gh api repos/rails/rails/commits/main` on 2026-11-03.
* **Ruby 4.0.9** (`ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]`), interpreter and `--yjit`.
  Census 8 started on 4.0.7 and moved to 4.0.9
  ([decision](../DECISIONS.md#ruby-pin-409-41-measured-on-pinned-master-2026-11-03)); the 4.0.7 allocation labels
  `c8`/`c82` stay as receipts and are not compared with anything here. **Ruby master**
  [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb)
  (`ruby 4.1.0dev (2026-11-03T12:42:36Z HEAD 9aa0898240) +PRISM`, RubyGems 4.1.0.beta3), built with YJIT and ZJIT.
* **Corpus:** census 7's overlays and setup (`script/census setup --rails 1105756f42…`, pin branch
  `thomasklemm/ruby-409-pin`, merged); production; disposable orb services (Redis, memcached, MySQL 8.4 on 3307,
  PostgreSQL 15 with pgvector and pg_partman).
* **Instruction counts:** [`script/cpu-census`](../../script/cpu-census) runs every app under Callgrind 3.19.0 with
  a sampling request ([cpu-valgrind.patch](../../bench/upstream/census8/cpu-valgrind.patch), from
  `bench/experiments/hotspots-valgrind.patch` with a settable interval). Each workload: census 7's boot and
  workload, 200 warmup operations, then one measured window of 10 operations. The window reports the **exact**
  client instructions of the measuring thread (Callgrind's count, not an estimate) and Ruby stacks sampled every
  4,096–12,288 instructions (uniform, seed 41231) by [`cpu_sampler.c`](../../bench/upstream/census8/cpu_sampler.c):
  `rb_profile_frames` with the line of every frame, as StackProf does. A sample's instructions go to its nearest
  Ruby frame and that frame's line, so C functions (Hash, String, regexp, the PG driver) are charged to the Ruby
  line that called them ("native" share below). The sampler's own instructions and the GC marking of its frames
  are excluded from the count.
* **GC** is reported apart: samples taken inside GC are counted separately (`gc_ir_per_op`) and charged to no
  line. A `GC.start` runs right before each measured window, so few collections fall inside it: GC samples are
  0.45% of interpreted and 0.90% of YJIT window instructions (most of it Sure's pages), and 7 interpreted
  workloads ran a GC in the window.
  The ranking therefore shows mutator work only; what fewer allocations save in GC is not in these numbers.
* **YJIT JIT-flat gate** ([bench.md](../bench.md)): under YJIT, after the 200 warmup operations the harness warms in
  windows of 10 operations, each after a `GC.start` and through the measured window's own block (not sampled),
  until three windows in a row compile nothing (at most 50). The measured window is checked too, and a workload
  whose window compiled anything is left out of the YJIT ranking.
* **Ranking** ([`cpu_rank.rb`](../../bench/upstream/census8/cpu_rank.rb)): a line (or method, by self instructions)
  *reaches* a workload at ≥ 5,000 instructions per operation. Breadth first: tiers by apps reached, ≥ 7 first;
  within a tier by mean instructions per operation over all ranked workloads. "% Ir" is the line's share of all
  instructions of all ranked workloads. Objects per operation come from the 4.0.9 allocation label `a4092`.
* **A/A:** labels `cpu409` (base) and `cpu4092` (A/A twin), same copies, run one after the other.

### What the YJIT gate taught

The first YJIT pass gated on two flat windows run outside the sampler, and 106 of 214 measured windows still
compiled (median 25 blocks, up to 1,063). Two diagnostic runs (`CENSUS_CPU_DIAG=1`, Blog and PingCRM) separated
the suspects: an extra unsampled window right before the measured one compiled nothing while the measured window
did, and the same held with that window sampled, so the sampling signals alone do not cause it. With
`--yjit-log`, the blocks compiled in the measured window are mostly the first blocks of methods (`index: 0`), as
when a method reaches YJIT's call threshold: cancancan's `does_not_support_subquery_strategy?` and
`accessible_by`, Rails' `QueryIntent#run_query!`, `build_select`, `Result#column_types`. Why they cross it in the
measured window and not in the unsampled or sampled window just before it is not established. The gate now needs
three flat windows in a row (`CENSUS_CPU_FLAT`), each after a `GC.start` and through the measured window's own
block, and workloads that still compile are excluded rather than rerun.

### A/A

`cpu409` against its twin `cpu4092`, per workload, relative change in exact instructions per operation:

| Mode | Workloads | Median | \|Δ\| p90 | ≤ −1% | ≥ +1% |
| --- | ---: | ---: | ---: | ---: | ---: |
| Interpreter | 242 | −0.02% | 0.60% | 12 | 6 |
| YJIT (JIT-flat in both) | 75 | +0.02% | 0.48% | 0 | 2 |

22 of 23 configurations: Sure's twin was not run (each Sure label takes about an hour under Callgrind; it was
stopped to free the copy for the master set). Sampler quality over all 251 + 251 windows: 0 empty, 0 truncated, 0
dropped stacks; the signal arrives at most 1,631 Ir late (mean 16); the handler's own instructions are excluded.

**Allocation A/A on 4.0.9** (`script/census`, labels `a409`/`a4092`, all 23 configurations, 251 workloads; the
objects column): median **+0.0 / +0.0** objects per workload (interpreter / YJIT); moved ≤ −1: 57 / 66, ≥ +1:
61 / 45; SQL changed on 3 / 1 workloads. Census 7's on 4.0.7 was 59 / 43 and 54 / 62.

### Runs that were redone

* The first interpreter pass dropped up to 44% of Sure's samples and 12–14% on Fizzy's and Loomio's largest pages
  (the stack table was full). The sampler now keeps stacks as a prefix tree (shared prefixes stored once) and those
  runs were repeated; superseded files are kept apart, not mixed in. Runs that dropped nothing kept their files; the
  two sampler builds record the same samples, and each run's `meta.json` names its build.
* Sure then hit Valgrind's `VG_N_SEGMENTS` limit (30,000 mappings). `cpu-valgrind.patch` raises it to 120,000;
  Sure (both modes) and the Campfire YJIT rerun (Valgrind crashed translating YJIT code once) used that build. The
  limit changes no instruction count.
* Chatwoot's 201st message within a minute is refused (`Validation failed: Too many messages`); 200 warmup operations
  cross it, so `cpu-census` raises `CONVERSATION_MESSAGE_PER_MINUTE_LIMIT` for Chatwoot. Census 7's allocation runs
  stay under it.

## Ranking

Top of the interpreter ranking on `cpu409`, all 23 configurations, 20 apps, 251 workloads; every line shown is in
the ≥ 7-apps tier. "Native" is the share of the line's instructions spent in C functions it called. Objects per
operation are the same line in the 4.0.9 allocation label `a4092`.

| Rank | Site | Apps | Ir/op | % Ir | Native | Obj/op | Disposition |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | AS `inflector/methods.rb:437` `apply_inflections` | 15 | 725,357 | 1.21 | 82% | 11.8 | Not built (see below). |
| 2 | AS `enumerable.rb:317` `index_with` | 20 | 519,289 | 0.87 | 58% | 369.5 | Our open #59557 (Ruby 4.1). |
| 3 | AR `query_methods.rb:193` generated `*_value(s)`/`*_clause` readers | 20 | 501,767 | 0.84 | 38% | 0 | C8-2 tried and rejected (YJIT/ZJIT slower). |
| 4 | AR `querying.rb:99` `column_types.reject` | 20 | 369,420 | 0.62 | 70% | 9.5 | Required (census 7); line in open #59141. |
| 5, 10, 14, 21, 22 | AM `attribute_set.rb:225/92/249/226/258` | 19–20 | 140–324k | 0.23–0.54 | 0–97% | 0–51 | Open #59141 (tenderlove), #58380. |
| 6, 16 | AM `indexed_row.rb:172/174` | 19 | 160–284k | 0.27–0.47 | 0–30% | 0 | Open #59141. |
| 7, 36 | AS `isolated_execution_state.rb:32/33` `[]` | 20 | 275,197 | 0.46 | 14% | 0 | Not built: call overhead, not work. |
| 8 | AS `erb/util.rb:160` `xml_name_escape` | 19 | 261,185 | 0.44 | 86% | 0 | Rejected in Bet V1. |
| 9, 41 | AR `result.rb:121/119` `column_types` Hash | 20 | 256,506 | 0.43 | 0–97% | 0 | Per result; open #59141 changes the file. |
| 11 | Arel `plain_string.rb:15` `@str <<` | 20 | 219,220 | 0.37 | 0% | 0 | SQL text. Required. |
| 12 | AV `buffers.rb:47` `OutputBuffer#<<` | 16 | 219,190 | 0.37 | 0% | 0 | Our open #59570. |
| 13 | AR `postgresql/database_statements.rb:256` | 12 | 209,168 | 0.35 | 94% | 187.8 | Result values (driver). Required. |
| 15 | AS `erb/util.rb:16` `html_escape` | 18 | 177,423 | 0.30 | 53% | 2.7 | Escaping (critical). Required. |
| 17 | Arel `table.rb:91` `Table#[]` | 20 | 152,500 | 0.25 | 53% | 114.1 | Attribute nodes. Required. |
| 18, 26 | Arel `visitor.rb:37/35` dispatch | 20 | 135–152k | 0.23–0.25 | 0% | 0 | Required. |
| 19 | AR `predicate_builder.rb:251` `handler_for` | 20 | 144,431 | 0.24 | 49% | 0 | Not built (see below). |
| 20, 29 | AR `merger.rb:65/64` | 20 | 131–141k | 0.22–0.24 | 0–96% | 0 | Open #56205 on the lines. |
| 23 | AS `ordered_options.rb:108` `InheritableOptions#initialize` | 20 | 136,961 | 0.23 | 38% | 0 | Per-instance config copies; #59105 (merged) took the reads. Not built. |
| **24** | AV `asset_url_helper.rb:194` `URI_REGEXP.match?` | 17 | 136,003 | 0.23 | 98% | 0 | **C8-1.** |
| 25, 44 | AR `query_cache.rb:90/98` | 20 | 108–136k | 0.18–0.23 | 70–98% | 0 | Cache key lookup. Required. |
| 27 | AS `weak_key_map.rb:39` | 20 | 133,735 | 0.22 | 77% | 0 | Required (one lookup). |
| 28 | AR `hash_lookup_type_map.rb:67` | 12 | 133,383 | 0.22 | 52% | 0 | PG type map lookups; #59560 merged. Required. |
| 30 | AS `output_safety.rb:245` `html_safe` | 19 | 126,407 | 0.21 | 77% | 107.4 | SafeBuffers. Required. |
| 32 | AR `where_clause.rb:8` `empty?` delegation | 20 | 123,691 | 0.21 | 12% | 0 | Open #46805 (delegations). |
| 33 | AR `delegation.rb:140` | 20 | 116,867 | 0.20 | 60% | 66.6 | Relations. Required. |
| 35 | AS `class_attribute.rb:12` | 20 | 112,611 | 0.19 | 0% | 0 | Class-attribute readers. Required. |
| 37, 40 | AV `tag_helper.rb:1551/1540` | 17–18 | 110–112k | 0.18–0.19 | 5–14% | 0–26 | Open #57999 (attribute strings). |
| 42 | AR `query_attribute.rb:61` `#hash` | 19 | 108,686 | 0.18 | 0% | 0 | Open #59518. |
| 43 | Arel `collectors/composite.rb:21` | 18 | 108,389 | 0.18 | 0% | 0 | Measured: reading ivars instead of the private readers saves 151 Ir/call interpreted, 3 under YJIT. Below the L1 bar. |

By method (self instructions) the top adds `TagHelper::TagBuilder#tag_options` (`tag_helper.rb:1630`) and
`#content_tag_string` (`:1543`), both covered by open #57999, and `ActiveRecord::Result#column_types`.

**YJIT.** 117 of 251 YJIT workloads were JIT-flat and are ranked (20 apps). The top is the same set in a different
order: `index_with` (19 apps, 1.42%), `apply_inflections` (13, 1.35%), `_load_from_sql` (0.88%),
`LazyAttributeSet#keys` (0.86%), the generated readers (0.77%), `column_types` (0.66%), PG result values (0.50%),
`Arel::Table#[]` (0.45%), `xml_name_escape` (0.44%); `asset_path`'s regexp is rank 13 (12 apps, 0.36%). YJIT shrinks
Ruby-level dispatch and leaves C-heavy lines (regexps, Hash, the driver) at their cost, so those rise.

Full rankings (line and method, both modes) are in the receipts.

## CPU against census 7's allocation ranking

[`c7_compare.rb`](../../bench/upstream/census8/c7_compare.rb) puts census 8's interpreter line ranking next to
census 7's allocation ranking (`rank-c72-interpreter.tsv`, Ruby 4.0.7, Rails `b084108cf3`; pins differ, so ranks
are compared, not counts).

* **5 of the CPU top 30 are in the allocation top 30**: `index_with` (CPU 2, allocations 1), PostgreSQL result
  values (13 / 2), `Arel::Table#[]` (17 / 3), `html_safe` (30 / 4), `LazyAttributeSet#keys` (5 / 15).
* **22 of the CPU top 30 allocate nothing** (0 objects per operation): the generated relation readers, `IsolatedExecutionState.[]`,
  `Result#column_types`, Arel's SQL string and visitor dispatch, `IndexedRow#fetch`, `OutputBuffer#<<`,
  `xml_name_escape`, the asset URI regexp, `handler_for`, the merger. No allocation census could find them.
* The CPU top line, `apply_inflections`, is rank 93 by allocations (11.8 objects per operation): its cost is 33
  case-insensitive `sub!` attempts per word, not objects.
* In the other direction, census 7's allocation leaders are cheap in instructions: `where_clause.rb:32` (alloc 5) is
  CPU 87 (0.11%), `attribute.rb:10` (7) is CPU 188, `notifications/fanout.rb:379` (19) is CPU 2,199, and
  `relation.rb:80`, `:101` and `query_methods.rb:1989` reach no workload at the 5,000 Ir threshold.

So objects and instructions rank mostly different code. An allocation win buys GC time (not in these numbers) and
some mutator work; a CPU candidate should come from this ranking and prove itself per call.

## C8-1: anchor `URI_REGEXP` once

Branch [`thomasklemm/uri-regexp-anchor`](https://github.com/thomasklemm/rails/tree/thomasklemm/uri-regexp-anchor)
[`84b0a308dc`](https://github.com/thomasklemm/rails/commit/84b0a308dc4c6ef9b75436d49cd54a67fad13169), one commit on
the pin. **Readability L0.**

`asset_path` (and through it `image_tag`, `stylesheet_link_tag`, `javascript_include_tag`, `asset_url`) returns a
source untouched when it is already a URI. The check is `URI_REGEXP.match?(source)`, a case-insensitive pattern
with the `^` anchor inside each of its three alternatives. For the common relative source the match fails, and
the failing match is the line's cost: `asset_url_helper.rb:194` is rank 24 of the CPU ranking (17 apps,
136,003 Ir/op interpreted, 98% of it in C, i.e. the regexp engine) and rank 13 under YJIT (0.36%). It allocates nothing, so no
allocation census could see it.

```diff
-      URI_REGEXP = %r{^[-a-z]+://|^(?:cid|data):|^//}i
+      URI_REGEXP = %r{^(?:[-a-z]+://|(?:cid|data):|//)}i
```

**Why it is exact.** `^A|^B|^C` and `^(?:A|B|C)` denote the same language, and alternation order is unchanged, so
the leftmost match and its end are the same. The `i` option applies to both alike. Checked exhaustively: every
string of length ≤ 6 over `a Z - : / \n c i d D t x . ␠` (8,108,731 strings, with newlines so the multiline `^` is
exercised) gives the same `match?` and the same match offsets. The constant stays a frozen Regexp literal with the
same options. Its `source` and `inspect` change, which only code printing the pattern could observe.

**Exactness checklist** (DECISIONS): 1–6 do not apply (no call on a user-supplied object is added or skipped;
`match?` coerces with `to_str` exactly as before, the receiver is the constant); 7: frozen Regexp, same
exceptions (a non-String raises the same `TypeError` from `match?`); 8: load order unchanged. The three callers
(`asset_path`, `compute_asset_host`, Action Text's `RemoteImage.remote_url?`) only use `match?`.

**Per call** ([micro.rb](../../bench/upstream/census8/micro.rb), [ir.sh](../../bench/upstream/census8/ir.sh),
Callgrind Ir per call over 3,000 calls inside `Array#cycle`, GC off; base twice for the A/A; interpreter and YJIT
on 4.0.9, ZJIT on master 9aa0898240):

| Call | Mode | main | A/A | C8-1 | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `asset_path("application.css")` | interp | 34,688 | 34,688 | **31,053** | −10.5% |
| | YJIT | 26,024 | 25,993 | **22,421** | −13.8% |
| | ZJIT | 24,668 | 24,671 | **20,715** | −16.0% |
| `asset_path("controllers/hello_controller", type: :javascript)` | interp | 43,587 | 43,587 | **38,730** | −11.1% |
| | YJIT | 34,775 | 34,827 | **29,832** | −14.2% |
| | ZJIT | 30,983 | 30,982 | **25,667** | −17.2% |
| `stylesheet_link_tag("application")` | interp | 88,599 | 88,652 | **85,379** | −3.6% |
| | YJIT | 56,662 | 56,748 | **53,397** | −5.8% |
| | ZJIT | 53,909 | 53,607 | **50,149** | −7.0% |
| `asset_path("https://cdn.example.com/x.js")` | interp | 3,526 | 3,526 | 3,526 | 0 |
| | YJIT | 2,431 | 2,422 | 2,435 | within A/A |
| | ZJIT | 2,624 | 2,772 | 2,643 | within A/A |

The regexp alone (`match?` on 4.0.9, interpreter): 9,580 → 5,943 Ir for `"application.css"`, 44,966 → 25,239 for a
111-character path. Both forms still scale with the length of the source.

**Alternatives measured and not taken.** A prefilter, `return source if %r{:|//}.match?(source) &&
URI_REGEXP.match?(source)`, saves more on relative sources (34,714 → 26,415 interp, 26,230 → 17,714 YJIT), and so
does `(source.include?(":") || source.include?("//")) && …` (26,594 / 17,842). Both make every absolute URL pay
for two scans (+903 / +717 Ir for the prefilter regexp, +513 / +374 for `include?`), and both add a line that needs
explaining (L1). The anchor change makes no input slower.

**Census** (label `c81`, `--rails thomasklemm/rails@84b0a308dc`, interpreter, 8 apps, 78 workloads, against
`cpu4092` with `cpu409` as the A/A). The line's own instructions per operation, base / A/A / C8-1:

| App | `asset_url_helper.rb:194` Ir/op | Change |
| --- | ---: | ---: |
| Lobsters | 364,723 / 369,135 / **217,157** | −40% |
| Fizzy | 151,645 / 155,629 / **93,843** | −38% |
| Writebook | 133,288 / 128,677 / **78,274** | −41% |
| CodeTriage | 36,848 / 37,666 / **20,706** | −44% |
| PingCRM | 37,865 / 37,662 / **23,231** | −39% |
| Campfire | 24,232 / 23,868 / **12,754** | −47% |
| Hackatime | 23,508 / 22,756 / **15,357** | −35% |
| Blog | 6,711 / 7,038 / **3,765** | −44% |

Whole workloads move by less than the A/A: median −0.08% (A/A −0.02%, |d| p90 0.56% against 0.60%). The line is
0.23% of all interpreted instructions, so a 40% cut is about 0.1% of an app's CPU, below what a single run resolves.
That is the honest size of C8-1: exact, free, and small per request.

**Suites** (`RAILS_STRICT_WARNINGS=1`, `SEED=41231`, Ruby 4.0.9): Action View `rake test` 3,341 runs, 7,625
assertions, 0 failures, 0 errors, 0 skips on main and on C8-1, same two warnings from capybara 3.40.0 on both.
Action Text 373 runs, 631 assertions, 0 failures, and on both the one error `JavascriptPackageTest` (needs
`yarn`, absent in the orb).

**Prior work.** `URI_REGEXP` was made case-insensitive in
[rails/rails#10969](https://github.com/rails/rails/pull/10969) (merged 2013); no PR, open or closed, changes its
shape or the speed of the check (`gh search prs` for `URI_REGEXP`, `asset_path regexp`, `asset_url_helper regexp`,
`asset_path performance/faster/allocations`). Open PRs touching the file do not touch the line: #56053 (escaping;
shows the line as context), #51646, #58935. No dependency on a Ruby or ZJIT change.

**Primary review:** not run yet (DECISIONS: Thermos with GPT-6.1 Sol before the queue; this thread cannot start
one).

### PR draft (short form, not published)

**Anchor `URI_REGEXP` once instead of per alternative**

> `asset_path` checks every source against `URI_REGEXP` to leave URLs alone. For the usual relative source the
> check fails, and the case-insensitive pattern with `^` in each alternative is the most expensive line of
> `asset_path`. Factoring the anchor out matches the same strings at the same positions and runs fewer
> instructions:
>
> | Per call (Callgrind Ir) | Before | After |
> | --- | ---: | ---: |
> | `asset_path("application.css")`, interpreter | 34,688 | 31,053 |
> | same, YJIT | 26,024 | 22,421 |
> | `stylesheet_link_tag("application")`, YJIT | 56,662 | 53,397 |
>
> Absolute URLs cost the same as before. In a CPU census of 20 open-source apps on Rails main, 17 apps reach this
> line, and its instructions drop by 35–47% per request in each app measured; it allocates nothing. It is about
> 0.1% of a request, so this is a small, free cleanup rather than a visible speedup.

## Not built

* **`apply_inflections` (rank 1).** `pluralize`/`singularize` at request time, called by apps and gems
  (cancancan's `accessible_by`, Lobsters' views), not by Rails' own hot paths. `"comment".pluralize` is 97,087 Ir
  interpreted and 56,359 under ZJIT, because every word is tried against up to 33 rules with `sub!` in order. The exact
  options are a result cache (memoization keyed by locale and word, invalidated when inflections change: critical by
  DECISIONS, L2) or one combined regexp (rejected upstream in #35459, closed stale; order and capture semantics make
  it L3). Prior work: #6864 (closed), #14247, #3536, #29097; open #46918 and #58752 touch other Inflector methods. Left
  for Thomas to decide.
* **`IsolatedExecutionState.[]` (ranks 6, 32).** 1,713 Ir per call interpreted against 837 for an empty lambda;
  `Thread.current.active_support_execution_state` alone is 1,288. PingCRM makes ~121 calls per operation through
  `current_shard`/`current_role`/`connected_to_stack`. The method is already minimal; the cost is the call chain.
  Callers could cache, but that is thread/fiber state (critical, L2). Not built.
* **C8-2, generated `where_clause`/`having_clause` readers (rank 3).** `@values.fetch(:where,
  Relation::WhereClause.empty)` calls `.empty` on every read. With the constant `Relation::WhereClause::EMPTY` as the
  default: `where_clause` 1,631 → 1,436 Ir interpreted (A/A 1,631), but **YJIT 1,293 → 1,414** (A/A 1,282) and
  **ZJIT 1,505 → 1,564** (A/A 1,507); `having_clause` the same direction (YJIT +45). A JIT loss blocks it (DECISIONS);
  rejected, not pushed. `FromClause::EMPTY` is a private constant, so `from_clause` was left alone anyway.
* **`handler_for` (rank 17).** `@handlers.detect { |klass, _| klass === object }.last` scans the handler list per
  predicate value. A per-class cache would change behavior for handlers registered later and for `===` overrides;
  L2. No open or closed PR found.
* **`Arel::Collectors::Composite#<<` (ranks 36, 43).** Measured above; under YJIT the private readers are already
  inlined. Not built.
* **Required:** SQL text, visitor dispatch, PG result values, attribute nodes, the query-cache key, `column_types`
  per result, as in census 7.

## Ruby master 9aa0898240

Ruby master [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb) is the
4.1 pin ([decision](../DECISIONS.md#ruby-pin-409-41-measured-on-pinned-master-2026-11-03); 4.1.0-preview1 was
dropped). It was built here with `--enable-yjit --enable-zjit` into `~/c8/ruby-master`. Master labels are never
compared with 4.0.9 labels.

**Boot and list, first pass (census 8's own overlays).** `script/census setup` on the census copies, with the
master variant lock `Gemfile.census-1105756f426e-ruby-9aa0898240`: 10 of 23 configurations installed and passed
`list` (Blog, Campfire, Fizzy, Fizzy-MySQL, CodeTriage, PingCRM, RedPrints CFP, React Starter Kit, CASA,
Hackatime; 100 workloads). The other 13 failed in `bundle install`:

| Configuration | Exact failure on master |
| --- | --- |
| Writebook | redcarpet 3.6.0 does not compile: `Data_Get_Struct` was removed |
| Lobsters | commonmarker 2.6.3 (rb-sys: incomplete `struct rb_matchext_struct`); stackprof 0.2.27 does not compile |
| Docuseal | numo-narray-alt 0.10.3 does not compile |
| Mastodon, Mastodon-nops, Loomio | cbor does not compile (`Data_Get_Struct`) |
| Sure | cbor (`Data_Get_Struct`); skylight and stackprof do not compile |
| Flow | cbor (`Data_Get_Struct`); temporalio has no build for 4.1 |
| Lago, Lago-nops | lago-expression requires Ruby `~> 4.0.2`; cbor (`Data_Get_Struct`) |
| Discourse | google-protobuf 4.36.2: "is not valid for all platforms" |
| Chatwoot | byebug 11.1.3, stackprof 0.2.25 and unf_ext do not compile |
| Thinkroom | Bundler 4.0.20 crashes: `Gem::YAMLSerializer.load("---\n")` returns nil on RubyGems 4.1.0.beta3 |

These are ledger entries, not worked around in app code. Bet E2 resolved 11 of them with dependency-only master
overlays ([gems-on-master](gems-on-master.md), `script/census setup --ruby-overlays fixtures/corpus/frontier-master`);
Chatwoot and Flow stay blocked there. (C8's "msgpack" note for Lago was cbor's msgpack-derived type names; E2
found msgpack builds.)

**Allocation A/A, first pass** (`amst` / `amst2`, 10 configurations, 100 workloads, interpreter / YJIT / ZJIT):
median **+0.0 / +0.0 / +0.0** objects per workload; moved ≤ −1: 23 / 21 / 19, moved ≥ +1: 19 / 23 / 33; SQL changed
on 0 / 0 / 0 workloads.

**Boot and list, second pass (E2's master overlays).** With `fixtures/corpus/frontier-master` (merged from bet E2)
all 11 configurations E2 fixed install and pass `list` on master here too: Writebook, Lobsters and Thinkroom set up
fresh in corpus `censusm8`; Docuseal, Mastodon, Mastodon-nops, Lago, Lago-nops, Discourse, Loomio and Sure on their
census copies, whose server databases a second corpus cannot share (the overlay applied to the copy, the master
variant lock rebuilt from it, `list`, then the copy's own Gemfile and lock restored; the 4.0.9 variant is a separate
file). 127 workloads (Discourse's `perform Jobs::UpdateGravatar` is gone after the first `list`, as E2 recorded).
**21 of 23 configurations boot on master; Chatwoot and Flow stay blocked** (commonmarker 0.x, temporalio).

**Allocation A/A, second pass** (`amsx` / `amsx2`, the 11 configurations, 127 workloads, interpreter / YJIT / ZJIT;
not mixed into `amst`): median **+0.0 / +0.0 / +0.0**; moved ≤ −1: 19 / 19 / 21, moved ≥ +1: 25 / 20 / 24; SQL changed
on 2 / 4 / 2 workloads.

**ZJIT leads from the master pass.** Four new entries, C–F, are in the queue on Lowrail branch
[`thomasklemm/zjit-lead-rest-splat`](https://github.com/thomasklemm/lowrail/tree/thomasklemm/zjit-lead-rest-splat)
(`docs/upstream/zjit-iseq-leads.md`); all are free, unmeasured in Ir, and nothing was posted.

* **C, a rest parameter copies a caller-built splat Array.** `URI.for(*split(uri), self)` at uri 1.1.2's
  `rfc3986_parser.rb:135` allocates one Array more per call under ZJIT than under YJIT and the interpreter: in `amst`
  46 of 100 workloads in 9 apps (Campfire +179 to +182 objects per operation), in `amsx` 7 more apps. It is
  [Shopify/ruby#1095](https://github.com/Shopify/ruby/issues/1095) (ours; no assignee, no PR).
* **D and E, YJIT allocates an Array less than both the interpreter and ZJIT**, in both A/A runs: Action View's
  generated `_layout` (`layouts.rb:384`; interpreter / YJIT / ZJIT, summed over workloads: Blog 37 / 34 / 37, Fizzy
  51 / 46 / 51) and Active Storage's `nil.try` blocks (`attached/model.rb:189` and `:291`; Fizzy 4 / 0 / 2 and
  3 / 0.7 / 3). A standalone `nil.try(:upload)` allocates 1 / 0 / 0, so ZJIT handles the plain call; the app-only
  difference is not explained.
* **F, unconfirmed:** under ZJIT only, Discourse's JSON workloads run one `Time.parse` per request (`time.rb:390`: 44
  Strings, 10 MatchData, 2 Hashes per operation), possibly a data or timing effect.

Not leads: inertia_rails `props_resolver.rb` (the per-line sums differ by one workload's data, and a per-call micro
of `Object#try` allocates 2.0 objects in all three modes), Loomio's growing `POST comment` result (data
accumulates between modes), and the `<internal:array>` lines, where YJIT and ZJIT allocate alike.

## Limits

* Instruction counts, not time. Callgrind counts the measuring thread's client instructions exactly; the per-line
  split is sampled (median 41,805 samples per workload window interpreted, minimum 291), so lines below a few
  thousand Ir/op are noisy. Cache misses, branch mispredictions and memory bandwidth are not modelled.
* GC is outside the ranked numbers (a `GC.start` precedes every window), so allocation-heavy lines are
  under-weighted relative to production.
* Under YJIT only JIT-flat windows are ranked: 117 of 251. The YJIT ranking therefore leans to read workloads.
* Each app runs all its workloads in one process with 200 warmup operations per workload; there is no fresh
  process per workload.
* `query_methods.rb:193` and other `class_eval`ed lines aggregate every method generated there; `--by method`
  splits them.
* Local suites only (Ruby 4.0.9); no hosted CI on the fork branch. C8-1 has not had its primary review.
* Receipts: [data/rails-main-census-8/receipts.tar.gz](data/rails-main-census-8/receipts.tar.gz): both CPU rankings
  (line and method, interpreter and YJIT), label metadata, the CPU and allocation A/As (4.0.9 and master), the
  census 7 comparison, the open-PR map, the C8-1 and C8-2 Ir matrices, and the suite summaries. The 4.0.7 labels
  `c8`/`c82` and the superseded CPU runs (old YJIT gate, the sampler's dropped-sample runs) stay in the orb's private
  output, not in the receipts.
