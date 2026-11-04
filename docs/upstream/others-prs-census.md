# Others' open Active Record PRs on the census

Our CPU and allocation rounds kept finding that the largest remaining Active Record costs were already being
reworked by other people's open PRs. This page measures three of them against their own bases, on the census
apps and on ruby-bench, and checks with a differential whether query results change. The numbers stay here.
Under DECISIONS (no unsolicited comments on others' PRs), measurements and behaviour notes stay in this record.

| PR | Author | What it changes | Base | Head |
| --- | --- | --- | --- | --- |
| [#59141](https://github.com/rails/rails/pull/59141) | tenderlove | Row-indexed attribute sets (`IndexedRow`), slot-numbered readers | `1105756f42` (merge base with main) | `e5dc0b4338` |
| [#58002](https://github.com/rails/rails/pull/58002) | ikraamg | `LazyAttributeSet#keys` without materializing every `Attribute` | `f78fe4227d` (2256 commits behind main) | `ca75837c16` |
| [#59530](https://github.com/rails/rails/pull/59530) | matthewd | `SchemaContext` split into a per-class context and a `MappedTable` | `e77813d4e8` | `ec8f6a92f9` |

#59612 (kamipo, `Merger#merge`) was merged before this round and is out of scope. All heads were re-read on
2026-11-04 and are unchanged.

**#58002 is measured as a port.** Its own base can't boot blog, campfire or fizzy, so its one commit is ported to
#59141's base `1105756f42` as `050a948988` (local only, Ikraam Ghoor as author). On main, `LazyAttributeSet#keys` is
the same three lines the PR replaces, so the port is the PR's diff with the file moved. The PR's per-call numbers
are given on both trees.

## Method

* Ruby 4.0.9 (`3e93b23afc`), interpreter and YJIT.
* **Per call:** Callgrind instruction counts over 200 calls with GC off, after warmup, using
  [`schema_context/irmicro.rb`](../../bench/upstream/schema_context/irmicro.rb) and
  [`micro.rb`](../../bench/upstream/schema_context/micro.rb) (SQLite, `time_zone_aware_attributes` on). Each run
  has an A/A worktree on the base commit. This round adds three cases to `micro.rb`: `attribute_names` on a
  record instantiated from a Hash, `find(1).attributes` and `find(1).as_json`.
* **ruby-bench:** railsbench, lobsters and shipit under Callgrind with a fixed heap
  (`RUBY_GC_HEAP_{0..4}_INIT_SLOTS`), base, A/A and head (`arcpu/irab.rb`, one iteration). The numbers are
  instructions for the whole run. There is no wall-time claim.
* **Census allocations:** `script/census run`, interpreter and YJIT, with an A/A on the base. There are two lanes:
  `census` (blog, campfire, fizzy, pingcrm, redprints-cfp and codetriage on SQLite; 56 workloads per mode) and
  `census-s` (chatwoot, discourse, lago, lobsters and mastodon on PG; 63 workloads). The tables give the
  per-workload median of allocated objects, how many workloads moved (≤ −1 or ≥ +1 object), and how many
  workloads' SQL changed. The A/A row is the noise floor.
* **Differential:** [`others_prs/probe.rb`](../../bench/upstream/others_prs/probe.rb) runs every census workload
  in the app with the variant bundle. It records a digest of each response body, with tokens, nonces and UUIDs
  masked. It also records every record loaded through `_load_from_sql`, as its class and its ordered
  attributes. Two base runs give the A/A, so a workload that varies between them is "unstable" and not compared.
  [`others_prs/controls.rb`](../../bench/upstream/others_prs/controls.rb) adds 112 targeted cases on SQLite and
  PG: partial selects, aliases, `find_by_sql` extras, unknown keys, defaults, STI, enums, serialized and
  time-zone-aware columns, Marshal, dup/becomes, stale schema and reordered columns.

## Summary

| PR | Per call, interpreter / YJIT (A/A ≤ 0.3% unless noted) | ruby-bench, interpreter (A/A) | ruby-bench, YJIT (A/A) | Census allocations | Behaviour |
| --- | --- | --- | --- | --- | --- |
| #59141 | `find` −15.7% / −24.2%; 10 rows −32.8% / −51.4%; `where.to_a` −10.7% / −16.7%; `find(1).attributes` −22.0% / −36.5%; but `instantiate(hash)` +128.7% / +317.2% | railsbench −1.827% (+0.047%); shipit −5.198% (−0.034%); **lobsters fails** | railsbench −2.866% (−0.101%); shipit −8.222% (−0.051%); **lobsters fails** | SQLite: median −37 / −35 objects, 52/56 and 51/56 moved down. PG (without lobsters): median −390 / −387, 49/52 and 50/52 | **Key order** of `attributes`/`as_json` for partial selects; **`define_attribute_method` for a non-attribute raises**, which breaks activerecord-typedstore 1.6.0 (Lobsters); stale-column edge |
| #58002 | `attribute_names` −59.0% / −69.9%; `find(1).as_json` −5.2% / −9.4%; `find(1).attributes` −1.5% / −5.8%; queries ±0.2% | railsbench +0.054% (+0.049%); shipit −0.006% (+0.005%); lobsters +0.015% (+0.158%): within A/A | shipit −0.171% (−0.003%); lobsters −0.136% (+0.006%); railsbench +0.054% (+0.100%), within A/A | SQLite: median −1.1 / −0.3, 29/56 and 23/56 down (A/A 10 and 15). PG: median −3.3 / −1.3, 39/63 and 33/63 down (A/A 13 and 20) | none found |
| #59530 | `attribute_types` +50.9% / +17.7%; `find` +9.3% / +5.9%; 10 rows +19.1% / +8.6%; `Post.new` +17.5% / +10.4% | railsbench +1.229% (+0.016%); shipit +3.314% (−0.683%); lobsters +0.889% (+0.121%) | railsbench +0.447% (+0.010%); shipit +2.272% (+0.089%); lobsters −0.073% (−0.384%) | within A/A in both lanes, no SQL changes | **Fizzy no longer boots** (`stack level too deep`) |

## #59141: row-indexed attributes

**Per call** (Ir per call, 200 calls):

| Case | Interpreter base → head | YJIT base → head |
| --- | --- | --- |
| `Post.find(1)` | 415,345 → 349,999 (−15.7%) | 213,874 → 162,042 (−24.2%) |
| `Post.find_by(title:)` | 429,453 → 363,849 (−15.3%) | 226,457 → 174,005 (−23.2%) |
| `where(...).limit(5).to_a` | 723,666 → 646,130 (−10.7%) | 354,380 → 295,135 (−16.7%) |
| `_load_from_sql`, 1 row | 116,493 → 51,118 (−56.1%) | 76,942 → 24,734 (−67.9%) |
| `_load_from_sql`, 10 rows | 293,395 → 197,181 (−32.8%) | 130,837 → 63,566 (−51.4%) |
| `Post.new` | 25,951 → 23,768 (−8.4%) | 8,931 → 8,451 (−5.4%) |
| `find(1).attributes` | 603,658 → 470,966 (−22.0%) | 335,037 → 212,670 (−36.5%) |
| `find(1).as_json` | 659,360 → 619,059 (−6.1%) | 390,627 → 342,968 (−12.2%) |
| `Post.instantiate(hash)` | 18,168 → 41,556 (+128.7%) | 4,888 → 20,393 (+317.2%) |
| `instantiate(hash).attribute_names` | 109,035 → 166,841 (+53.0%) | 70,710 → 101,405 (+43.4%) |

The A/A is within 0.4% on every row. `instantiate` from a Hash is the one per-call loss. On the base it wraps the
Hash lazily; on the head it copies every value into an `IndexedRow` first
([`trace_59141_instantiate.rb`](../../bench/upstream/others_prs/trace_59141_instantiate.rb) shows five extra
`IndexedRow::Mutable#[]=` calls and two `Array.new`). Rows loaded from the database don't take that path. Gems
that build records from cached attribute hashes do. `find(1).attributes` gets faster in this micro, unlike the
`#attributes` regression czj reported on the PR, because the micro includes loading the row.

**ruby-bench.** Interpreter: railsbench −1.827% (A/A +0.047%), shipit −5.198% (A/A −0.034%). YJIT: railsbench −2.866% (A/A −0.101%), shipit −8.222% (A/A −0.051%). The head variants were rerun on their own after lobsters aborted the first run; that run's railsbench head agreed within 0.06% (−2.807%).
**lobsters fails** on the head in both modes, with the same error as the census (see below).

**Census allocations.**

| Lane | Mode | A/A median (moved down / up) | Head median (moved down / up) | SQL changed, A/A → head |
| --- | --- | --- | --- | --- |
| SQLite (56) | interpreter | 0.0 (10 / 10) | −37.3 (52 / 4) | 0 → 0 |
| SQLite (56) | YJIT | 0.0 (15 / 10) | −35.2 (51 / 4) | 0 → 0 |
| PG (63; head 52, without lobsters) | interpreter | 0.0 (13 / 14) | −390.2 (49 / 1) | 2 → 2 |
| PG (63; head 52) | YJIT | 0.0 (20 / 9) | −386.5 (50 / 0) | 2 → 1 |

Fizzy −154 and pingcrm −75 per request lead the SQLite lane. On PG, chatwoot's conversation list drops 7,717
objects and mastodon's timelines drop up to 10,453.

**Behaviour.** The differential compared 44 response bodies and 50 record sets on SQLite, and 32 bodies and 20
record sets on PG. No response body changed. Four record sets changed, all in the same way:

1. **Attribute order follows the table, not the SELECT list.** Codetriage's `Repo.select(:id, :issues_count,
   :language, :full_name, :name, :description)` (TopicsController), discourse's `User` selects on `/latest` and
   the category pages, and lago's `Event` select now list attributes in column order. The values are the same.
   [`repro_59141_select_order.rb`](../../bench/upstream/others_prs/repro_59141_select_order.rb):
   `Post.select(:score, :title).first.attributes.keys` is `["score", "title", "id"]` on the base and
   `["id", "title", "score"]` on the head, and `to_json` reorders its keys the same way. An alias that isn't a
   column (`select("title AS name, id")`) moves after the columns: `["name", "id"]` becomes `["id", "name"]`.
   Controls show the same for `find_by_sql` extras, unknown keys passed to `instantiate`, and the attribute
   order in Marshal output. None of the census pages render this order, but an API that renders a partial
   select with `as_json` changes its key order.
2. **`define_attribute_method` for a name that isn't an attribute now raises** at the first load:
   `ArgumentError: Post has no attribute 'nickname' to define a reader for`. On the base it defined a reader
   ([`repro_59141_define_attribute_method.rb`](../../bench/upstream/others_prs/repro_59141_define_attribute_method.rb)).
   activerecord-typedstore 1.6.0, the latest release (2024-02-28), does this for every store accessor. So
   Lobsters fails its first `User` load in the census, in the differential and in ruby-bench's `lobsters`
   benchmark. The gem fix tenderlove mentioned on the PR,
   [byroot/activerecord-typedstore#114](https://github.com/byroot/activerecord-typedstore/pull/114), was merged on
   2026-10-27 but is not released. The raise is deliberate
   (`define_method_attribute` in `attribute_methods/read.rb`).
3. **Stale schema (edge case).** A column dropped without `reset_column_information` can leave SQLite's cached
   statement reporting the old column with shorter rows. The base then gives `"gone" => nil` and
   `has_attribute?(:gone)` true. The head drops the key, and reading it raises `MissingAttributeError`
   ([`repro_59141_stale_column.rb`](../../bench/upstream/others_prs/repro_59141_stale_column.rb); deterministic on
   SQLite, 3/3 runs each). This needs an inconsistent result from the adapter, so it is recorded, not raised.

On PG, a table whose columns were reordered behind a stale schema cache maps values by name correctly on the head.
Only the key order differs, as in point 1.

## #58002: `LazyAttributeSet#keys`

**Per call.** The PR touches only `keys`, so the cases that call it move and the read and query paths don't:

| Case | Own base `f78fe42` → head, interpreter / YJIT | Ported to `1105756`, interpreter / YJIT |
| --- | --- | --- |
| `instantiate(hash).attribute_names` | 133,217 → 66,671 (−50.0%) / 92,784 → 43,872 (−52.7%) | 109,281 → 44,832 (−59.0%) / 70,773 → 21,304 (−69.9%) |
| `find(1).as_json` | 724,551 → 687,561 (−5.1%) / 430,244 → 405,989 (−5.6%) | 658,852 → 624,516 (−5.2%) / 389,951 → 353,318 (−9.4%) |
| `find(1).attributes` | 663,657 → 652,038 (−1.8%) / 378,330 → 364,831 (−3.6%) | 604,019 → 594,665 (−1.5%) / 339,874 → 320,276 (−5.8%) |
| `find`, `find_by`, `where.to_a`, 1 and 10 rows, `instantiate`, `new` | within ±0.4% (A/A up to −4.0% on YJIT 10 rows) | `find` +0.0% / +0.2%; 10 rows −0.0% / −0.1% |

**ruby-bench (port).** Interpreter: railsbench +0.054% (A/A +0.049%), shipit −0.006% (A/A +0.005%), lobsters +0.015% (A/A +0.158%), all within A/A. YJIT: shipit −0.171% (A/A −0.003%), lobsters −0.136% (A/A +0.006%), railsbench +0.054% (A/A +0.100%). Shipit and lobsters gain slightly, beyond their A/A.

**Census allocations (port, against the #59141 base runs).**

| Lane | Mode | A/A median (moved down / up) | Port median (moved down / up) | SQL changed, A/A → port |
| --- | --- | --- | --- | --- |
| SQLite (56) | interpreter | 0.0 (10 / 10) | −1.1 (29 / 7) | 0 → 0 |
| SQLite (56) | YJIT | 0.0 (15 / 10) | −0.3 (23 / 7) | 0 → 0 |
| PG (63) | interpreter | 0.0 (13 / 14) | −3.3 (39 / 9) | 2 → 3 |
| PG (63) | YJIT | 0.0 (20 / 9) | −1.3 (33 / 9) | 2 → 1 |

Pingcrm (Inertia props through `as_json`) drops 17 objects on every workload, and mastodon drops 24 on 12 of 14.

**Behaviour.** No differences. The 112 controls are identical on SQLite and PG, for both the PR's own trees and
the port. The differential compared 44 response bodies and 50 record sets on SQLite, and 41 bodies and 21 record
sets on PG. One discourse record set (`GET category (crawler)`) differed, but a third base run differs from the
first in the same way. With that run as the A/A, the port matches. The PR's own tests pass on the port, except
for five new tests that build an `AttributeSet::Builder` with the old two-argument signature.

## #59530: SchemaContext / MappedTable split

**Fizzy no longer boots** on the head: `SystemStackError: stack level too deep` while loading the first model.
Fizzy's [`config/initializers/uuid_primary_keys.rb`](https://github.com/basecamp/fizzy/blob/main/config/initializers/uuid_primary_keys.rb)
prepends `build_schema_context` on `ActiveRecord::Base`. It calls `primary_key` there to register a UUID
default before `load_schema!`, as its comment explains. On the head, `primary_key` →
`configured_primary_key_definition` → `schema_context` builds the context again, which calls the prepended
`build_schema_context` again.
[`repro_59530_build_schema_context.rb`](../../bench/upstream/others_prs/repro_59530_build_schema_context.rb) prints
`1` on the base and raises `SystemStackError` on the head. `build_schema_context` is `:nodoc:`, so this may count
as an internal API, but a released app depends on it.

**Per call** (interpreter, `time_zone_aware_attributes` on; YJIT in the summary table): `attribute_types` +50.9%,
`has_attribute?` +29%, `Post.new` +17.5%, `instantiate` +16.8%, 10 rows +19.1%, `find` +9.3%, `find_by` +8.7%,
`where.to_a` +6.6%, A/A ≤ 0.1%. With `time_zone_aware_attributes` off (the base on its fast path):
`attribute_types` +36%, `Post.new` +12.2%, 10 rows +11.8%, `find` +5%. A TracePoint shows where the cost comes
from. On the head, `SchemaContext#attributes` goes through `mapped_table` → `model_class` → `mapped_table_for`
(`Array#[]`, `equal?`) → `MappedTable#attributes` → `attributes_cache` → `Ractors.store_if_absent` →
`Ractor.store_if_absent` → `WeakKeyMap#[]` on every read. The base reads `@attributes`, or does one
`Ractors[]` on the slow path. The base `e77813d4e8` predates #59585, so its time-zone-aware models are still on the
slow path. On current main they would be on the fast path, so the gap would be the time-zone-aware-off one.

**Census allocations** (Fizzy excluded on the head): SQLite median +0.1 interpreter and +0.3 YJIT against an A/A
median of 0, with 15/42 workloads up in both modes (A/A: 15/56 interpreter, 8/56 YJIT) and no SQL changes. PG:
median 0 in both modes, 22/63 up in the interpreter against 6 in the A/A, and SQL changes 1, the same as the A/A.

**Behaviour, other than Fizzy:** 0 of 38 response bodies and 0 of 36 record sets differ on SQLite, and the 112
controls are identical on SQLite and PG.

## Behaviour notes (record only)

DECISIONS: no unsolicited comments on others' PRs. These notes are written in comment form for the record only; they are not to be posted.

**#59530 (Fizzy boot):**

> Thanks for untangling this, @matthewd! I tried the branch on a few open-source apps, and one of them, Fizzy,
> no longer boots: `stack level too deep`. Its `config/initializers/uuid_primary_keys.rb` prepends
> `build_schema_context` on `ActiveRecord::Base` and calls `primary_key` inside it, to register a UUID default
> before `load_schema!`. Here, `primary_key` goes through `schema_context` and calls `build_schema_context` again.
> Minimal repro (prints 1 on e77813d, raises `SystemStackError` on ec8f6a9):
>
> ```ruby
> ActiveRecord::Base.singleton_class.prepend(Module.new do
>   def build_schema_context
>     primary_key
>     super
>   end
> end)
> Post.create!(title: "a")
> ```
>
> I know `build_schema_context` is :nodoc:, so this may be fine, but Fizzy would need another hook.

**#59141:** the key order and typedstore findings above, for the record. The typedstore break is already known
on the PR (tenderlove's gem fix, unreleased).

**#58002:** no behaviour change.
