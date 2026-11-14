# Rails-main census 9: what costs more on main than on 8-1-stable, and what moved since census 8

Census 9 compares Rails main [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b)
(2026-11-14) with 8-1-stable [`71e963ed1b`](https://github.com/rails/rails/commit/71e963ed1b0c8e5d1ff6e9124236cf7c4d4a24b9)
and with census 8's pin [`1105756f42`](https://github.com/rails/rails/commit/1105756f426ee42834af5c87b4549ef709d631e5)
on Ruby 4.0.9, ahead of the 8.2 beta. It ranks by self Callgrind instructions first and allocations second. The
focus is tenderlove's [#59141](https://github.com/rails/rails/pull/59141) (attributes in an indexed row, merged
2026-11-11), plus a root cause for `button_to` after seanpdoyle's [#50312](https://github.com/rails/rails/pull/50312)
(merged 2026-11-07).

**Result.** Main is faster than 8.1 in 70 of 71 workloads: the median is −6.5% of interpreted instructions and −601
objects per workload. The one slower workload is codetriage's debug-logged job (+4.0%), which is already known and
deliberate. #59141 makes loading, generated readers, `#attributes`, `new` and `becomes` much cheaper. Every path
that still goes **by name**, or that rebuilds a Hash from the row, got slower. None of that is released. The largest
of these are:

* `update!` on wide tables: +71% vs 8.1 at 300 columns. Most of it is `LazyIndexedAttributeSet#keys` (K1, being
  built in another orb).
* `attributes_for_database` ×2.2 and `attributes_before_type_cast` ×5. These are what Marshal and MessagePack
  record caching use; `Marshal.dump` of a record is +33–36% vs 8.1.
* By-name reads and writes: `read_attribute`/`self[]` +16%, `id`/`_read_attribute` +40% vs before #59141,
  `write_attribute` and writers +33–37%.

`button_to` is +24–35% with no params and +42–45% with params since #50312. The params half has an exact fix (K6/K7)
that recovers 28–31% and returns large param sets to their pre-#50312 cost.

Nothing was opened or posted upstream. Every number is interpreter Ir per call under census 8's patched Callgrind,
with a fixed heap and an A/A pair. YJIT numbers appear only where every measured window compiled nothing.

## Ranked leads

Reach is measured in the CPU census (8 apps, 71 workloads, interpreter). Net "% all" is the lead's summed
self-instruction change over all workloads, as a share of all 8.1 instructions. The A/A is main against its own
twin (`main2`, or `c9m2` in the census).

| # | Lead | Main file:line | Reach | Magnitude (A/A) | Released? | Existing PR / issue | Proposed next step |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | **K1** `LazyIndexedAttributeSet#keys` builds `row_keys \| type_keys \| cached_names`, which always equals `row_keys` | AM `attribute_set.rb:343` | 8/8 apps, 25 workloads grew; +0.134% net; CPU rank 55 (0.145%) | Built: `update!` −18% / −29% / −36% at 30/100/300 cols; `serializable_hash` −30%; `changed?` −17%; YJIT `update!` −29% (A/A ≤ 0.34%) | No (#59141) | ikraamg's #58002 targets the old `keys` (stale); kamipo's #58380 doesn't touch it | **Built and reviewed by the K1 orb** ([proof](../../bench/upstream/k1/README.md)); Thomas decides on opening |
| 2 | **`button_to` params via `hidden_field_tag`** (K6), and `form_tag { }` with a block (K5) | AV `navigation_helper.rb:459`, `:462` | 4/8 apps call `button_to` (43 call sites, 3 with `params:`); `button_to` ≈ 85k Ir inclusive per op | Params: +42–45% since #50312; **K7 −28% to −31%**, back to pre-#50312. No params: +24–35% since #50312, K7 −2.7% to −4.8% (A/A ≤ 0.1%). YJIT (flat): params K7 −30% to −33%, no params −1.7% to −3.5% | No (#50312, 2026-11-07) | None; #50312's discussion has no performance comments | **K6 built** ([record](../../bench/upstream/k6/README.md), queue item [K6](../../bench/upstream/pr-queue/items/K6.md)); K5 is optional. Thomas decides on opening |
| 3 | **`attributes_for_database` / `attributes_before_type_cast` rebuild an `IndexedRow::Mutable` per call** (`materialize`, then a Hash via `transform_values`) | AR `before_type_cast.rb:108/113` → AM `attribute_set.rb:115/119` → `:457` | Marshal (`marshalling.rb:23`) and MessagePack (`message_pack.rb:89`) record caching; 0 of the 71 census workloads | `attributes_for_database` ×2.2 at 6–300 cols (1 → 4 objects); `before_type_cast` ×5–6; `Marshal.dump` +33% / +34% / +36% / +36% vs 8.1 at 6/30/100/300 cols (A/A ≤ 0.04%) | No (#59141) | None (#59249 and #59684 touch other parts of Marshal and MessagePack) | **L3 built** ([record](../../bench/upstream/l3/README.md), queue item [L3](../../bench/upstream/pr-queue/items/L3.md)): drops the per-call row copy, keeps `materialize` (a row read is not exact). `Marshal.dump` −15%, MessagePack −25% to −28%, `attributes_for_database` −33% to −42%, `before_type_cast` −43% to −53% at 6–300 cols (A/A ≤ 0.26%) |
| 4 | **By-name access after #59141**: `index_for_name` → `indexes` → `lookup`, a second `index_for_name` in `write`, eager cast in `write_from_user` | AM `attribute_set.rb:495`, `:374/382`, `:422`; AR `read.rb:40/56`, `write.rb:32/52`, `primary_key.rb:19` | 8/8 apps: `index_for_name` +0.298% net (59 workloads), `value_at!` +0.272%, `fetch_value!` +0.102% | vs before #59141: `read_attribute`/`self[]` +16%, `id`/`_read_attribute` +39–41%, `write_attribute` +37%, writer +33%, `changed?` +32%, `dup` +22% (YJIT read +2%, write +43%) (A/A ≤ 0.95%) | No (#59141) | None. tenderlove plans index-based generated writers and the like | Reads by name (`id`, `_read_attribute`): regression from #59141. Writers and dirty: not yet converted. Give tenderlove the numbers before the beta |
| 5 | **Partial-select reads** go through `ExtendedIndexes`/`Remapper` | AM `indexed_row.rb:206/267` | 2/8 apps in the census (`Remapper#initialize` +0.041%) | `partial_load1_read` +14–15% vs before #59141 and +17% vs 8.1 at every width; YJIT +26–31% | No (#59141) | None | Measure `select(:id, :name)` loads with 1–10,000 rows; low priority |
| 6 | **`update!` grows with width before #59141** | Before #59141: `LazyAttributeSet#keys`'s union, which a19ef01cb3 (#59083) keeps on saved records. On K1: by-name helpers in AM `attribute_set.rb:320` (`#[]`), `:346–347` (`#keys`), `:469` (`transform_attributes!`) | Every app that saves wide records | 8.1 → before #59141: +12% / +20% / +32% / +39% at 6/30/100/300 cols; K1 +10% at 300 cols; K1 + L6 −1.8% at 300 cols | No (#59083, #59141) | None | **Attributed** ([below](#lead-6-update-and-table-width)). K1 removes #59083's part; L6 (`641c84c43a`, +4/−4) is built. Thomas decides |
| 7 | **Per-row load on large results** | AR `querying.rb:93`, `result.rb:263`, `model_schema.rb:227/235` | Any query that loads thousands of rows; the census's small pages are faster | 10,000 rows, Ir per row vs 8.1: +13% / +14% / +22% at 6/30/300 cols. Census 8 was +32% / +33% / +41%; #59141 recovered 12% (A/A ≤ 0.04%) ([below](#per-row-load)) | No (before census 8) | None. AT-1 (reuse the builder per row) rejected: it skips the overridable `instantiate_instance_of` | Attribute the census 8 per-row growth (`loaded_mapped_table` ×2, `schema_attributes`, the strict-loading class attributes) |
| 8 | **`table_name_qualified_unscope_values` on every merge** | AR `query_methods.rb:1066` via `merger.rb:66`, `association_scope.rb:147` | 8/8 apps, 57 workloads: +13 objects; +0.025% Ir | Small; `merge` itself is −36% vs census 8 | No (#59709, 2026-11-10, fixes #48227) | None | Return early when `unscope_values` is empty; not built, below the bar alone |

Not leads (released, or deliberate and already judged):

* The `_set_vary_header` growth (e38dd281d3, GHSA-r9jg-fmfx-2gv6) and the `tag_options` blank checks (99a3247ebc,
  GHSA-68p9-83h6-5wpj) are security fixes released in 8.1.4.1.
* `QueryIntent`, `WeakKeyMap` leases, `association_route`, `EventReporter` and the schema context are judged in
  [rails-82-impact](rails-82-impact.md) and [main-regressions](main-regressions.md).
* Records Marshal-dumped by 8.1 in the 6.1 format fail on main. This is intended and documented: the 8.2 upgrade guide
  requires switching to 7.1 and flushing caches first, and #59249 removes 6.1 loading
  ([below](#records-in-the-61-marshal-format-from-81-not-a-lead)).

## K1: `LazyIndexedAttributeSet#keys`

Recorded here only. Another orb proved and built it: [bench/upstream/k1](../../bench/upstream/k1/README.md), queue item
[K1](../../bench/upstream/pr-queue/items/K1.md), branch `thomasklemm/lazy-indexed-keys` at `bbdd9945d3`. `keys` unions `row_keys`, `@ctx.type_keys` and
`cached_names`, then filters each name through `index_for_name`. For a set built by `build_from_row`, every type
key and cached name is already a row key, so the union is `row_keys`. Commit `5e34cc61f8` ([patch](data/rails-main-census-9/K1.patch),
+1/−9) lists the keys from the indexes alone and drops the second `type_keys` pass in `materialize`.

Evidence:

* Equality: 67 attribute sets checked, including store attributes on #58380's head.
* Tests: Active Model 1,269 runs and focused Active Record 1,867 runs, 0 failures.
* Interpreted gains: `update!` −18% / −29% / −36% at 30/100/300 columns, `serializable_hash` −30%, `changed?` −17%
  to −18%, `as_json` −14%.
* YJIT at 30 columns: `changed?` −24%, `update!` −29%.

With K1, `update!` at 300 columns is 5.09M Ir against 8.1's 4.63M; it is 7.91M on main.

## Lead 6: `update!` and table width

**Result.** Before #59141, the width-dependent growth comes from one commit, a19ef01cb3 "fix `deep_dup` and `map`
return type". It is tenderlove's, and it went in with #59083 (merged 2026-10-15 as `da27ee26de`). K1 already removes
it. What K1 leaves is #59141's by-name helpers, which a save calls once per column in three loops. L6 inlines the
helpers in two of those loops. It is built on the fork as `thomasklemm/indexed-set-inline-lookups` at
[`641c84c43a`](https://github.com/thomasklemm/rails/commit/641c84c43a558947c3cf54ce11a910edb183b992), +4/−4, and
queued as [L6](../../bench/upstream/pr-queue/items/L6.md). With K1 and L6 together, `update!` costs less than on
8.1 at 300 columns. A part that does not depend on width remains and is not attributed here: +4.6% at 30 columns
and +8.2% at 6.

`update!` of one column (`update1` in [`attr_micro.rb`](../../bench/upstream/census9/attr_micro.rb)), Ir per call,
interpreter, measured in this orb:

| Columns | 8.1 (A/A) | before #59141 | main | K1 | K1 + L6 (A/A) | K1 + L6 vs 8.1 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 6 | 876,439 / 876,423 | 977,857 (+11.6%) | 1,027,368 (+17.2%) | 969,145 (+10.6%) | 948,073 / 948,052 | +8.2% |
| 30 | 1,189,479 / 1,188,245 | 1,425,842 (+19.9%) | 1,595,210 (+34.1%) | 1,308,854 (+10.0%) | 1,244,175 / 1,245,085 | +4.6% |
| 100 | 2,064,800 / 2,064,214 | 2,719,412 (+31.7%) | 3,223,183 (+56.1%) | 2,278,478 (+10.3%) | 2,090,222 / 2,090,118 | +1.2% |
| 300 | 4,613,118 / 4,616,166 | 6,432,392 (+39.4%) | 7,899,487 (+71.2%) | 5,082,557 (+10.2%) | 4,532,201 / 4,532,610 | **−1.8%** |
| Ir per column | 12,680 | 18,543 | 23,349 | 13,977 | 12,178 | |

### Bisect

Every 8-1-stable commit since the merge base `8ae3d84277` is a backport, and the merge base costs the same as 8.1
(12,689 Ir per column against 12,680). So the bisect runs over the 2,411 first-parent commits from `8ae3d84277` to
`c48c154e3f`. It measures Ir per column, (Ir at 300 − Ir at 30) / 270, and samples every 300th commit before trisecting
([`bisect.rb`](../../bench/upstream/census9/lead6/bisect.rb), [all points](data/rails-main-census-9/lead6/bisect.txt)):

| First-parent commit | Ir at 30 | Ir at 300 | Ir per column |
| --- | ---: | ---: | ---: |
| `8ae3d84277` (merge base) | 1,182,597 | 4,608,361 | 12,688 |
| `ffe977efbc` (#59111, parent of #59083's merge) | 1,257,349 | 4,643,144 | 12,540 |
| ↳ #59083 `33e6064ac9` "remove `send`" | 1,255,327 | 4,641,065 | 12,540 |
| ↳ #59083 **`a19ef01cb3`** "fix `deep_dup` and `map` return type" | 1,496,340 | 6,733,752 | **19,398** |
| `da27ee26de` (#59083's merge) | 1,464,350 | 6,443,596 | 18,442 |
| `c48c154e3f` (before #59141) | 1,425,842 | 6,432,392 | 18,543 |

#59083 was rebased onto `ffe977efbc`, so its own commits measure on the same base. Two smaller moves are not
chased: +68k Ir at 30 columns that builds up before `ffe977efbc` without changing the per-column cost, and +650 Ir
per column that appears between the 900th and the 1,200th commit and is gone by the 1,800th.

**Mechanism.** Until a19ef01cb3, `LazyAttributeSet#map` was `AttributeSet#map` and returned a plain, Hash-backed
`AttributeSet`. So after the first save (`changes_applied` → `forget_attribute_assignments` →
`@attributes.map(&:forgetting_assignment)`), a record's `keys` was `attributes.each_key.select { ... }`, as on 8.1.
a19ef01cb3 makes `map` and `deep_dup` return a `LazyAttributeSet`. A saved record therefore keeps the lazy set, whose
`keys` builds `values.keys | types.keys | @attributes.keys` and then filters it. `AttributeMutationTracker#attr_names`
calls `keys` three times per `update!`, and each call hashes every column name into the two temporary Hashes that
the two `Array#|` build.

The Callgrind self Ir per column ([`fn_slope.rb`](../../bench/upstream/census9/lead6/fn_slope.rb),
[table](data/rails-main-census-9/lead6/callgrind-functions-per-column.txt)) shows that most of the growth is
hashing. The `callgrind_annotate` dumps cover only the measured window
([`cg_window.rb`](../../bench/upstream/census9/lead6/cg_window.rb)). The instance-variable shape lookups also grew,
but they are gone again before #59141.

| C function, Ir per column | 8.1 | a19ef01cb3's parent | a19ef01cb3 | before #59141 | K1 | K1 + L6 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| total | 12,679 | 12,529 | 19,372 | 18,519 | 13,967 | 12,155 |
| `ruby_sip_hash13` | 450 | 450 | 1,708 | 2,068 | 450 | 450 |
| `rb_st_update` | 94 | 94 | 1,116 | 1,555 | 94 | 94 |
| `find_table_bin_ind` | 45 | 45 | 601 | 844 | 45 | 46 |
| `rb_str_hash`, `rb_any_hash` (2), `ar_force_convert_table`, `rb_hash_add_new_element`, `rb_hash_stlike_update`, `rb_st_keys` | 254 | 253 | 1,339 | 1,677 | 288 | 287 |
| `rb_shape_get_iv_index_with_hint` (shape.c, shape.h) | 66 | 66 | 912 | 0 | 0 | 0 |
| `vm_exec_core` (vm.inc, insns.def, vm_insnhelper.c) | 3,661 | 3,661 | 4,243 | 3,397 | 5,023 | 3,922 |

At the Ruby level, a19ef01cb3 adds only 2 calls and 4 lines per column: 21 → 23 Ruby calls, 29 → 33 lines
([`lines.rb`](../../bench/upstream/census9/lead6/lines.rb),
[per column](data/rails-main-census-9/lead6/ruby-lines-per-column.txt)). The cost is in the C work of the unions.

**Deliberate?** The type change is deliberate. It comes from tenderlove's 2024 refactoring
[#53344](https://github.com/rails/rails/pull/53344) (still open), rebased into #59083, "Add read-only attributes and
use it instead of building a cache". #59083's next commit, dfe995aacb "Ensure `@attributes` is always a
LazyAttributeSet", relies on it, and #59141's indexed set needs it. #59083 has no review comments. Its description
says "I'm not thrilled with some of the code in here, but I like the performance gain". Nobody discussed the cost of
the union in `keys`. That union is the piece that can go: #59141 carried it into `LazyIndexedAttributeSet#keys` as
`row_keys | @ctx.type_keys | cached_names`, which always equals `row_keys`. **K1 is its exact fix.** On K1, every
hashing function above is back at 8.1's count per column.

### What K1 leaves, and L6

K1 costs 13,967 Ir per column against 8.1's 12,679 (+1,288, about +10%). None of it is hashing: the whole difference
is in the VM, from 26 Ruby calls and 25 C calls per column against 8.1's 21 and 15. The calls come from three loops,
all from #59141 ([call sites](data/rails-main-census-9/lead6/ruby-call-sites-per-column.txt),
[`sites.rb`](../../bench/upstream/census9/lead6/sites.rb)):

1. **`LazyIndexedAttributeSet#keys`** (AM `attribute_set.rb:346–347` on main): each name costs `index_for_name`
   (→ `indexes` → `Hash#[]`) and `lookup` (→ `Array#[]`), two Ruby calls where 8.1 makes one (`self[name]`).
   `keys` runs three times per `update!`.
2. **`AttributeMutationTracker#attribute_changed?`** (`attribute_mutation_tracker.rb:79`), once per column, calls
   `LazyIndexedAttributeSet#[]` (`attribute_set.rb:320`) → `index_for_name` and `attribute_at` → `lookup`. That is
   four Ruby calls where 8.1 makes two.
3. **`transform_attributes!`** (`attribute_set.rb:469–480`), from `forget_attribute_assignments`: an
   `each_with_index` block with two Array stores per slot, where 8.1 runs `Hash#transform_values`.

**Deliberate?** The helpers are deliberate structure ("Methods that take a name look its index up once and work by
index from there"). The same file already inlines them where it is hot: `fetch_value_at` is "Same as #value_at,
inlined since generated readers call this", `value_at` "check[s] the caches directly", and `type_for` reads
`@indexes`. tenderlove [plans](https://github.com/rails/rails/pull/59141#issuecomment-6546441624) to give "the
same 'index based' treatment to the other methods we generate". That would rework loop 2's callers, but not
`#keys` or `#[]` themselves.

**L6** (+4/−4, [patch](data/rails-main-census-9/lead6/L6.patch)) inlines `index_for_name`, `lookup` and
`attribute_at` in `#[]` and in `#keys`' loop. It is exact: `index_for_name` is `indexes[name]`; `indexes` is the
`attr_reader` of `@indexes`, which only `initialize` assigns; `lookup` is `@attributes&.[](index)`; and
`attribute_at` is `lookup(index) || default_attribute(name, index)`. The inlined code reads the same instance
variables at the same points, including after a `default_attribute` in the loop creates `@attributes`. Nothing in
Rails subclasses `LazyIndexedAttributeSet`.

Evidence:

* K1's [`keys_probe.rb`](../../bench/upstream/k1/keys_probe.rb) prints identical output for main and L6 (54 cases,
  6,897 lines) and for K1 and K1 + L6 (6,959 lines).
* Active Model passes on L6 (1,269 runs, 0 failures). Active Record SQLite has 10,375 runs, 0 failures and 5
  errors, all from this orb's environment: four from the missing `sqlite3` CLI and one from `pg` outside the bundle.
  Once both are installed, those two files pass (`sqlite_rake_test` 15/15, `connection_handlers_multi_db_test`
  21/21).
* K1 + L6 passes Active Model (1,269 runs, 0 failures) and 26 focused Active Record files (dirty, attributes,
  persistence, serialization, STI, store, Marshal, timestamps, locking, enum, dup/clone, autosave, transactions;
  2,173 runs, 0 failures).
* RuboCop: no offenses.

Loop 3 is not built. `@attributes.map! { |attr| attr && yield(attr) }` with `@casted_values.fill(UNCAST)` saves 3.8%
at 300 columns on K1. But it is exact only if every slot with a cast value also has a built attribute after
`materialize`, which needs its own proof.

L6 is based on main `50c54eed06`, as asked. Its `#keys` hunk changes the two lines after K1's, so the two branches
conflict textually. The resolution keeps K1's `row_keys.keep_if` with L6's two lines
([K1 + L6 diff](data/rails-main-census-9/lead6/L6-on-K1.diff)); every K1 + L6 number here uses it. Either branch
can rebase onto the other, or K1 can take L6's two `#keys` lines.

L6 per call, interpreter, against its base. A/A is L6 against a second checkout of itself, and objects per call
are unchanged in every case ([all 40 cases](data/rails-main-census-9/lead6/l6-interp.md)):

| Case | L6 vs main, 30 cols | 300 cols | K1 + L6 vs K1, 30 cols | 300 cols | largest A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| `update!` of one column | −3.8% | −7.0% | −4.8% | −10.9% | 0.09% |
| load, then `update!` | −4.9% | −8.3% | −5.0% | −9.2% | 0.07% |
| load, then `changed?` | −6.3% | −6.8% | −7.8% | −8.4% | 0.15% |
| load, assign, then `changes` | −5.9% | −6.6% | −7.1% | −8.0% | 0.15% |
| `serializable_hash` | −4.4% | −4.7% | −6.6% | −6.8% | 0.25% |
| load, then `as_json` | −2.1% | −2.3% | −2.6% | −2.7% | 0.14% |
| load, then `dup` | −4.0% | −4.5% | −2.3% | −2.4% | 0.05% |
| load, then `Marshal.dump` | −4.1% | −4.4% | −2.2% | −2.4% | 0.05% |

On main, `update!` drops by 1.8% / 3.8% / 5.8% / 7.0% at 6/30/100/300 columns. Some by-name cases of a few thousand
Ir (`read_attribute`, `_read_attribute`, `write_attribute`, the writer, `new`, the warm reader) move by +0.2% to
+1.0% on either base (9 to 142 Ir). No move is more than 0.1 points above that case's A/A. Readers, loads,
`#attributes`, `marshal_dump` of a warm record and `attributes_for_database` are unchanged.

YJIT, load then `changed?`: L6 against main is −3.3% / −3.2% at 30/300 columns (A/A 0.73% / 0.04%), and K1 + L6
against K1 is −4.4% / −4.3% (A/A 0.06% / 0.01%). `update!`, assignment then `changes`, and `serializable_hash`
compiled blocks in some measured windows ([raw](data/rails-main-census-9/lead6/l6-yjit.txt)), so they are not
claimed.
Ruby master × ZJIT was not measured. [DECISIONS](../DECISIONS.md#evidence-and-measurement) requires it before L6
opens.

## `button_to` since #50312

| Case (interpreter, Ir per call) | 8.1 | before #50312 | #50312 | main | K5 | K6 | **K7** | K8 (attribution) | K7 vs main | Objects before #50312 / main / K7 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `button_to(..., method: :delete)` | 190,430 | 178,382 | 227,182 | 226,472 | 218,627 | 226,480 | 218,426 | 208,904 | −3.6% | 24 / 36 / 33 |
| CSRF on, POST | 182,553 | 172,647 | 215,369 | 215,464 | 207,620 | 215,436 | 207,484 | 195,568 | −3.7% | 24 / 34 / 31 |
| CSRF, `method: :get` | 128,479 | 122,261 | 165,425 | 165,408 | 157,512 | 165,398 | 157,488 | 145,572 | −4.8% | 19 / 29 / 26 |
| CSRF, `method: :delete` | 244,348 | 228,073 | 276,887 | 277,004 | 269,180 | 276,956 | 268,936 | 257,020 | −2.9% | 30 / 42 / 39 |
| CSRF, block, `method: :patch` | 248,467 | 233,032 | 281,593 | 281,731 | 274,247 | 281,645 | 274,015 | 262,104 | −2.7% | 33 / 46 / 42 |
| CSRF, `form:` options and `form_class` | 212,154 | 200,732 | 251,080 | 251,190 | 243,279 | 251,183 | 243,237 | 231,485 | −3.2% | 24 / 34 / 31 |
| CSRF, `remote: true` | 197,570 | 187,900 | 233,215 | 233,304 | 225,474 | 233,270 | 225,322 | 213,901 | −3.4% | 24 / 34 / 31 |
| 20 params | 1,424,130 | 1,315,344 | 1,896,191 | 1,895,179 | 1,888,897 | 1,360,406 | **1,351,315** | 1,339,518 | **−28.7%** | 263 / 373 / 270 |
| 200 params | 13,120,438 | 12,069,631 | 17,512,917 | 17,506,297 | 17,515,820 | 12,146,990 | **12,122,540** | 12,110,863 | **−30.8%** | 2,424 / 3,434 / 2,431 |
| CSRF, 2,000 params | 130,539,662 | 120,220,534 | 174,341,778 | 174,230,148 | 174,384,354 | 120,589,872 | **120,455,983** | 120,457,138 | **−30.9%** | 24,029 / 34,045 / 24,036 |
| 1 MB label | 28,113,133 | 26,523,035 | 25,298,740 | 25,298,546 | 25,290,482 | 25,298,545 | 25,290,671 | 25,278,273 | −0.0% | 26 / 38 / 35 |
| `form_tag(...) { }` (control) | 236,119 | 223,754 | 222,215 | 223,668 | 222,255 | 223,694 | 223,230 | 211,812 | −0.2% | 34 / 34 / 34 |
| `link_to` (control) | 76,812 | 72,311 | 72,317 | 72,235 | 72,250 | 72,286 | 72,238 | 72,252 | +0.0% | 11 / 11 / 11 |

**A/A:** 8.1 against its twin is ≤ 0.4% (`form_tag` control) and ≤ 0.08% elsewhere; main against `main2` is ≤ 0.05%.
**YJIT:** [below](#button_to-under-yjit).

**Root cause.** #50312 implements `button_to` on top of `form_tag`. Two parts cost the time.

1. **Params (+42–45%).** Each param now goes through `hidden_field_tag(name, value, id: nil)`, which calls
   `text_field_tag`, `sanitize_to_id` (on a nil id), and `merge`/`update`/`stringify_keys` per field. Before #50312,
   and in #50312's own `method_tag` and `token_tag`, a hidden field is
   `tag(:input, type: "hidden", name:, value:, autocomplete:)`. K6 emits params that way again. From the 20- and
   200-param cases, each param costs about 87k Ir and 17 objects on main, against 60k and 12 before #50312 and on K6.
2. **No params (+24–35%, about 43k Ir).** The parts, measured one at a time on main
   ([`bt_steps.rb`](../../bench/upstream/census9/bt_steps.rb), [output](data/rails-main-census-9/raw/bt_steps-main.txt)):
   * the `capture` of the `form_tag` block: 7.2k Ir, 3 objects. K5 calls `form_tag_with_body` directly.
   * the `accept-charset` attribute: 11.9k Ir (K8 against K7). This is #50312's stated, deliberate output change.
   * `html_options_for_form`'s `stringify_keys` and second `url_for` (11.9k), the `safe_join` in
     `form_tag_with_body` (12.3k), and `extra_tags_for_form`'s downcase and `case` instead of a direct
     `method_tag`/`token_tag`.

   These are shared `form_tag` code that 8.1 already ships for every `form_tag`, so making them cheaper is a
   `form_tag` change, not a `button_to` one.

**Deliberate?** The refactor is deliberate: "Implement `button_to` in terms of `form_tag`" (87f14c57fd), approved by
skipkayhil. Its stated output changes are the field order, `accept-charset`, and a case-insensitive `method:`.
Nothing in the PR or its review discusses performance, and the per-param `hidden_field_tag` is incidental: the same
PR adds `method_tag`/`token_tag` with `tag(:input, …)`.

**K6/K7 are exact.** [`button_to_diff.rb`](../../bench/upstream/census9/button_to_diff.rb) prints `button_to`'s
output for 5,760 inputs: names, URLs (String, Hash, `false`), methods in any case, flat and nested params, Arrays,
HTML characters, `form`/`form_class`, `remote`, `authenticity_token`, blocks, `data`/`disabled`, both
`button_to_generates_button_tag` settings, `remove_hidden_field_autocomplete`, and forgery protection on and off,
including `html_safe?`. Main, K5, K6 and K7 print identical output. The Action View template tests pass on K7:
2,967 runs, 0 failures (rerun after renaming K6's local variable to `input_options` so it no longer shadows the
`options` argument).

K6 is L0: three lines that mirror `token_tag`. K5 is L1: it bypasses the public `form_tag`, so an app that
overrides `form_tag` would no longer see `button_to` calls. That is a contract question, and the reason to offer K6
alone. Diffs: [K5](data/rails-main-census-9/k5-button_to.diff), [K6](data/rails-main-census-9/k6-button_to.diff),
[K7](data/rails-main-census-9/k7-button_to.diff), [K8](data/rails-main-census-9/k8-button_to.diff).

**Lifetime and reach.** The change was merged 2026-11-07, is unreleased, and would ship in the 8.2 beta.
`button_to` has 43 call sites in 4 of the 8 apps (blog 3, writebook 14, codetriage 1, casa 25); 3 pass `params:`
(writebook 2, casa 1). In the CPU census, `button_to` runs about 85k Ir per operation in 4 apps, about 0.03% of a
request. The lead is worth a follow-up because it is unreleased and exact, not because of its share.

### `button_to` under YJIT

Ir per call with `--yjit`. A cell counts only when main, `main2` and K7 all compiled nothing in their measured
windows. The before/after-#50312 column counts only when both of those trees were flat too; otherwise it says
"not flat".

| Case | before #50312 | main | K7 | #50312 effect | K7 vs main | A/A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| CSRF on, POST | 91,691 | 112,934 | 109,915 | +23.3% | −2.7% | 0.08% |
| CSRF, `method: :get` | 59,718 | 82,278 | 79,413 | +38.0% | −3.5% | 0.01% |
| CSRF, `method: :delete` | 119,853 | 145,180 | 141,470 | +21.0% | −2.6% | 0.03% |
| CSRF, block, `method: :patch` | 123,013 | 146,792 | 144,342 | +19.5% | −1.7% | 0.12% |
| `method: :patch` with options | 111,128 | 137,224 | 134,483 | +23.6% | −2.0% | 0.06% |
| 20 params | 773,067 | 1,146,180 | **790,149** | +48.3% | **−31.1%** | 0.03% |
| CSRF, 20 params | 809,771 | 1,175,794 | **823,883** | +45.2% | **−29.9%** | 0.08% |
| 200 params | not flat | 10,732,451 | **7,192,203** | not flat | **−33.0%** | 0.04% |
| 1 MB label | 26,434,625 | 25,184,893 | 25,182,308 | −4.6% | −0.0% | 0.00% |
| `form_tag(...) { }` (control) | 112,938 | 111,717 | 112,731 | −1.0% | +0.9% | 0.12% |

`button_to(..., method: :delete)` without CSRF and `link_to` compiled in every tree's window, and CSRF with 2,000
params compiled in main's, so they are not claimed. The interpreter's picture holds under YJIT: K6's params change
recovers 30–33%, back to within 2% of before #50312. K5's `form_tag` bypass recovers 2–3.5%. The `form_tag` control
moves +0.9% with K7, against an A/A of 0.12%; K7 does not change `form_tag`, so that is the limit of this YJIT
control, and it is why the no-params gain is not claimed as more than about 2–3%.

## #59141: attributes in an indexed row

Per call, interpreter. The trees are 8.1 (`s81`, A/A `s81b`), main before #59141 (`pre141` = `c48c154e3f`),
#59141's merge (`m141` = `1f32b09101`) and main (A/A `main2`). The table has an `id`, a `type` column, timestamps,
and data columns cycling string, integer, boolean, datetime, float and text. Every width is in
[attr-interp.md](data/rails-main-census-9/attr-interp.md) and [attr-yjit.md](data/rails-main-census-9/attr-yjit.md).
The model `ApiItem` declares one virtual and one type-overriding `attribute`; a partial select reads 3 columns.

| Case | 30 cols: #59141 effect | 30 cols: main vs 8.1 | 300 cols: #59141 effect | 300 cols: main vs 8.1 | YJIT 30 cols: #59141 | Class |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `find` | −13.2% | −30.7% | −21.4% | −49.1% | −19.4% | faster |
| load 20 rows (`_load_from_sql`) | −10.3% | +0.8% | −2.2% | −28.9% | −16.8% | faster |
| warm reader | −16.5% | −20.7% | −16.3% | −20.7% | −15.1% | faster |
| all readers, warm | −18.7% | −24.8% | −20.0% | −26.0% | −24.2% | faster |
| `#attributes`, warm (czj's `to_hash` landed in #59141 as 19022a4aa4) | −23.5% | −31.6% | −23.1% | −31.0% | −56.2% | faster |
| `new(2 attrs)` | ~ | −51.2% | +2.3% | −92.3% | −5.6% | faster |
| `becomes` | −72.1% | −37.5% | −81.2% | −50.8% | not flat | faster |
| partial select, `#attributes` | −18.6% | −16.6% | −22.5% | −19.1% | −27.6% | faster |
| `read_attribute` / `self[]` | +15.7% / +15.0% | +17.1% / +16.2% | +15.6% / +14.9% | +17.2% / +16.4% | +2.2% / +2.6% | **regression** (by name) |
| `id` / `_read_attribute` | +41.2% / +39.3% (300 cols) | −9.5% / −9.2% | +41.2% / +39.3% | −9.5% / −9.2% | +20.5% / +16.6% (100 cols) | **regression** vs before #59141, still below 8.1 |
| partial select, read | +14.0% | +16.6% | +14.8% | +16.6% | +31.3% | **regression** |
| `attributes_before_type_cast` | +471% | +468% | +477% | +477% | +337% | **regression** (rebuilds the row) |
| `attributes_for_database` | +149% (30 cols, Marshal run) | +122% | +143% | +118% | — | **regression** (rebuilds the row) |
| `Marshal.dump` (7.1 format; before #59141 → main) | +38% | +34% | +40% | +36% | — | **regression** |
| `write_attribute` / writer | +37.4% / +33.1% | +23.6% / +25.0% | +37.2% / +31.6% | +23.8% / +23.1% | +43.5% / +26.7% | not yet converted |
| assign, then `changes` | +16.3% | +9.2% | +16.8% | +8.4% | +8.8% | not yet converted, plus K1 |
| `changed?` | +31.5% | +8.7% | +33.3% | +8.0% | +32.4% | K1 + by name |
| `dup` | +22.2% | +26.2% | +23.7% | +26.7% | +15.9% | by name |
| `serializable_hash` / `as_json` | +31.1% / +13.3% | +10.9% / −11.6% | +30.9% / +13.8% | +10.7% / −13.0% | not flat / +11.8% | K1 (−30%) + by-name reads |
| `slice` / `values_at` | +2.4% / +5.5% | −8.5% / −15.6% | +2.7% / +6.1% | −8.3% / −15.2% | −1.8% / −3.5% | by name, small |
| `update!` (1 column, SQL) | +11.7% | +32.7% | +22.8% | +70.9% | not flat | K1 + by name; half predates #59141 (lead 6) |
| STI load | +10.3% | −27.5% | +8.0% | −45.1% | +17.2% | by name (`type`) |

**A/A:** ≤ 0.4% interpreted in all cells but `sti_load1` at 6 columns (0.66%) and `writer` (up to 0.95%), where
the change is 30–40%. YJIT cells marked "not flat" compiled in a measured window and do not count.

**Regression, or not yet converted.** tenderlove [wrote on #59141](https://github.com/rails/rails/pull/59141#issuecomment-6546441624)
that the PR "only tackles the reader methods" and that he expects "to give the same 'index based' treatment to the
other methods we generate". These are **not yet converted**: generated writers, `write_attribute`, and the
dirty-tracking paths that write. They are slower because the name lookup grew a layer
(`write_from_user` → `index_for_name` → `write` → `index_for_name` again → `attribute_at` → `store`), and because
`write_from_user` now casts eagerly. The comment there makes the eager cast deliberate: it keeps the first read on
the fast path.

These are **regressions from #59141** that conversion of the generated methods would not fix:

* Reads that Rails and apps make by name, not through a generated method: `id`, `_read_attribute`,
  `read_attribute`, `self[]`, partial-select reads, `read_attribute_for_serialization`. Each now pays
  `index_for_name` → `indexes` → `value_at!` with the `UNCAST` check, where before #59141 it paid one `Hash#[]` on
  the attribute set. In the CPU census, `index_for_name` alone is +0.298% of all instructions in all 8 apps, and the
  15th-largest method by self instructions on main.
* Whole-record Hashes that still materialize: `values_before_type_cast` and `values_for_database` (lead 3), and
  `keys` (K1).

**Net in the apps.** Counting the attribute stack (`attribute_set.rb` +1.43%, `indexed_row.rb` +0.24% against
`attribute_set/builder.rb` −1.22%, `_load_from_sql` −0.46%, `result.rb` −0.74%, `attribute.rb` −0.26%, `read.rb`
−0.24% of all 8.1 instructions), main spends less than 8.1 on attributes. The by-name and Hash-rebuilding paths
above are what is left to recover.

### Marshal and MessagePack (lead 3)

`Marshal.dump(record)` in the 7.1 format, which main always uses, Ir per call. 8.1's default is the 6.1 format, so
the micro sets 7.1 on 8.1 too. On 8.1 with the 6.1 format the dump costs 227,630 / 423,965 / 880,622 at 6/30/100
columns, so apps still on the 6.1 format get faster on main.

| Columns | 8.1 (7.1 format, A/A) | before #59141 | main (A/A) | main vs 8.1 | `attributes_for_database` 8.1 → main | objects |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 6 | 72,645 / 72,658 | 74,101 | 95,770 / 95,803 | +31.8% | 15,824 → 35,937 (×2.27) | 1 → 4 |
| 30 | 264,290 / 264,618 | 255,839 | 353,078 / 352,882 | +33.6% | 73,357 → 162,985 (×2.22) | 1 → 4 |
| 100 | 804,236 / 804,489 | 777,368 | 1,092,026 / 1,092,038 | +35.8% | 237,388 → 527,095 (×2.22) | 1 → 4 |
| 300 | 2,364,096 | 2,284,076 | 3,204,606 / 3,205,270 | +35.6% | 718,348 → 1,562,600 (×2.18) | 1 → 4 |

The cost is in `LazyIndexedAttributeSet#attributes` (`attribute_set.rb:457`). It calls `materialize`, which builds
an `Attribute` for every row key and type key, then copies them into a new `IndexedRow::Mutable` on every call, and
`AttributeSet#values_for_database` (`:119`) then runs `transform_values` over that. `to_hash` had the same shape
until czj's row-reading `to_hash` went into #59141. The same treatment for `values_for_database` and
`values_before_type_cast` was the proposed next step. One question it needed answered: whether a value cast from the
row and never written serializes to the same database value as the row's raw value (it must, for Marshal round
trips).

**Built as L3, without the row read** ([record](../../bench/upstream/l3/README.md)). The question's answer is no:
`Attribute#value_for_database` keeps what it returns, so main dumps the same ciphertext for a non-deterministically
encrypted attribute on every call, and serializing the row's value again re-encrypts it each time. Skipping
`materialize` also changes `accessed_fields`. So L3 keeps `materialize` and drops only the row copy: the copy alone is
32,820 Ir and 3 objects per call at 30 columns (794 on 8.1). The branch `thomasklemm/attrs-for-database-row`
(`52587b6f5d`, +24) prints byte-identical probe output to main on SQLite and PostgreSQL, including Marshal and
MessagePack payloads dumped by 8.1 and by main. Fix against main, interpreter, 6/30/100/300 columns: `Marshal.dump`
−15.9% / −15.4% / −15.2% / −15.3%, MessagePack dump −25.1% / −27.1% / −27.7% / −28.1%, 3 fewer objects (A/A ≤
0.26%). That recovers 60–70% of the dump regression against 8.1; the rest is the Ruby walk over the indexes that
replaced 8.1's C `Hash#transform_values`. YJIT: in the record.

Found along the way, not part of L3: records Marshal-dumped by 8.1.4.1 in the 6.1 format fail on main. This is
intended and documented, so it was not built; see [below](#records-in-the-61-marshal-format-from-81-not-a-lead).

Reach: `Rails.cache` entries holding records (Marshal), the MessagePack cache coder, and anything that calls
`attributes_before_type_cast`. None of the 71 census workloads dump a record, so the census cannot rank it. The
loss is per cached record.

### Records in the 6.1 Marshal format from 8.1 (not a lead)

The L3 orb reported that records Marshal-dumped by 8.1.4.1 in the 6.1 format fail on main. The 6.1 format is
8.1's default for apps without `load_defaults "7.1"`. Since a cache (`Rails.cache`, Solid Cache, sessions) outlives a
deploy, upgrading such an app could break on load. **The failure is real, but it is intended and documented, so
nothing was built (no M61).**

**Repro** ([marshal_compat.rb](../../bench/upstream/census9/marshal_compat.rb), output
[marshal-compat.txt](data/rails-main-census-9/marshal-compat.txt)). Twelve records are dumped on one tree and loaded
on the other. Each loaded copy is compared with the original, then saved and reloaded. The cases are: new, new STI,
new with a built `has_many`, created, loaded, loaded after reads, loaded and dirty, loaded STI, `includes` (plain
and STI), a parent with `includes(:posts)`, and a partial `select`. The models have a JSON-serialized column, a
non-deterministic encrypted attribute and a deterministic one. SQLite, Ruby 4.0.9.

| Dumped on → loaded on | Loaded records (8) | New and created records (4) |
| --- | --- | --- |
| 8.1, 6.1 format → 8.1 | all load, save and match | all load, save and match |
| **8.1, 6.1 format → main** | **all raise `ArgumentError: undefined class/module ActiveRecord::Result::IndexedRow` on `Marshal.load`** | **all load and read correctly; `save` raises `NoMethodError: undefined method 'transform_row' for an instance of Hash`** |
| 8.1, 7.1 format → main | same as 8.1 → 8.1 | same as 8.1 → 8.1 |
| main, 7.1 format → 8.1 (rolling deploy) | same as 8.1 → 8.1 | same as 8.1 → 8.1 |

Main can't dump the 6.1 format at all (`format_version = 6.1` raises `ArgumentError`), so the only reverse direction
is 7.1. The 7.1 format drops the dirty state of new and dirty records and loads the unselected columns of a partial
`select` as `nil`. It does that the same way on 8.1 and main, so it is not a cross-version difference.

**Cause.** In the 6.1 format, Ruby dumps a record's instance variables as they are, so the payload names 8.1's
private classes and their instance variables. Main changes those classes, so these payloads have broken one way after
another since August. The two failures the L3 orb saw come from two PRs (checked on each PR's parent and merge;
trees in the output file):

* byroot's [#58663](https://github.com/rails/rails/pull/58663) (`1fbedade58` "Extract IndexedRow into ActiveModel",
  merged 2026-09-15) breaks **loaded** records. It moved `ActiveRecord::Result::IndexedRow` to
  `ActiveModel::IndexedRow` and renamed its `@column_indexes` to `@indexes`. All eight loaded records in the matrix
  hold one, so all eight fail to load. On its parent `3fcedd35b7` all eight load, and six save. The two with
  `includes` already failed on `save` (`NoMethodError: undefined method 'map' for nil`).
* tenderlove's [#59141](https://github.com/rails/rails/pull/59141) (merged 2026-11-11) breaks **new** records. They
  load as an `AttributeSet` holding a Hash. `b33a68e1de` (in #59141) makes them lay themselves out only when a
  generated reader reads by slot. A `save` before that reaches `AttributeSet#map`, which calls
  `transform_row` on the Hash. The INSERT first fails on `ActiveModel::Attribute::FromUser` values, then the rollback
  raises the `NoMethodError`. Its parent `c48c154e3f` saves new, new STI and created records. Main's own Rails 6.1
  fixture `rails_6_1_new_topic.dump` behaves the same way
  ([marshal_fixture_new.rb](../../bench/upstream/census9/marshal_fixture_new.rb)). It saves only when
  `define_attribute_methods` ran before the load and a reader runs before the save. Main's test does both. 8.1
  saves it either way.
* Earlier breaks, found while bisecting: a new record with a built `has_many` child fails on `save` from kamipo's
  [#58354](https://github.com/rails/rails/pull/58354) (merged 2026-08-03; first-parent bisect, first bad
  `f5ae04bef6`). #58354 caches `@foreign_key` in `BelongsToAssociation#initialize`, and the child's marshaled
  association has no such variable. The error is `MissingAttributeError: can't write unknown attribute ''`, and a
  `NoMethodError` on later commits. On the same August commits, the `includes` records already raised
  `ArgumentError: wrong number of arguments` when read. That was not bisected.

So the L3 note "very likely #59141" is half right: #59141 breaks new records, and #58663 broke loaded records two
months earlier. This is the outcome #57382 predicted: 6.1 loading breaks whenever the private classes change.

**Status of the format on main.**

* byroot's [#57382](https://github.com/rails/rails/pull/57382) "Remove support for Rails 6.1 Active Record Marshal
  format" was merged 2026-05-18. It removed 6.1 dumping and the `load_defaults "7.1"` line, made 7.1 the only
  format, and added to the 8.2 upgrade guide: "you MUST opt-in to the newer `7.1` marshal format before upgrading,
  and ensure all caches were either flushed or upgraded." The PR says: "For now loading 6.1 record will still work
  ... but we might break it at any point when evolving the various `Attribute` / `AttributeSet` private APIs." It
  also says no realistic deprecation warning was possible. It has no CHANGELOG or 8.2 release-notes entry, only the
  upgrade-guide section.
* tenderlove's [#59249](https://github.com/rails/rails/pull/59249) "Remove marshal loading support for Rails 6.1"
  is **open, not draft**, and byroot approved it on 2026-10-22. It deletes the 6.1 fixtures and tests and the
  `Builder`/`Association` `marshal_dump` compat. It adds a CHANGELOG entry and a guide paragraph: records with cached
  associations raise `TypeError`, others "can break at any time", and caches must be flushed before upgrading.
* In #59141, tenderlove restored 6.1 loading (`6cba4864a5`) only "to get this landed" because "we have some tests
  that care about Marshal". byroot answered "I honestly didn't mind it being removed :)", and earlier suggested
  splitting 6.1 support out.
* The 8.1 upgrade guide doesn't mention the Marshal format. Its configuring guide still says old-format messages "can
  still be read", which holds on 8.1.

**Precedent.** The 7.1 format came with a `load_defaults "7.1"` switch, and from 7.1 on Rails read both formats, so
an app switched after its upgrade without a flush. Only Rails < 7.1 can't read 7.1 dumps. The Active Support
cache's 6.1 format went through a deprecation in 7.1 before its removal in 7.2 (7.2 release notes: "Remove deprecated
support for `config.active_support.cache_format_version = 6.1`"). The Active Record 6.1 format gets no
deprecation, by #57382's choice. No guide promises that 6.1-format dumps of Active Record objects survive an upgrade.
The private classes they name are `:nodoc:`, and the 8.2 upgrade guide explicitly requires a flush.

**Existing reports.** GitHub search of rails/rails issues and PRs for `IndexedRow marshal`, `marshal 6.1`,
`marshalling_format_version`, `transform_row` and the error message finds nothing about this. The only matches are
closed issues #49827, #49871, #50219 and #53667 (2023–2024) and the merged doc PR #49876, none about 8.2. #59141's
thread mentions Marshal only for restoring and removing 6.1 support and for whether `UNSET` leaks into dumps.

**Why no fix.** Making 8.1's 6.1 payloads load on main would mean a `ActiveRecord::Result::IndexedRow` constant with
`marshal_load` for the old instance variables, a laid-out path for Hash-backed sets in `map` and the save path, and
fallbacks for the association internals. That is compat code the maintainers have said they don't want, while
#59249, which deletes the rest of it, is open and approved. The documented upgrade path works, as the table shows:
switch to 7.1 on 8.1 (8.1 reads both formats), let the 6.1 entries expire or flush them, then deploy 8.2. Mixed
8.1/main fleets on 7.1 read each other's dumps.

Optional for Thomas, nothing posted. #59249's CHANGELOG says records other than those with cached associations "may
still load". For payloads written by 8.1, the only ones a real upgrade meets, none work on main today: loaded ones
fail on load and new ones fail on save. A one-line comment on #59249 with this table would sharpen its wording.
Separately, 8.1.x could warn once at boot when `marshalling_format_version` is still 6.1. That fires for every
such app, cached records or not, which is presumably why #57382 rejected it.

### Per-row load

`_load_from_sql` on a cached result, Ir per row (objects per row), interpreter. Single-row and 20-row loads are faster
on main than on 8.1 at every width; the cost per row of a large result is not.

| Rows × columns | 8.1 | census 8 | before #59141 | #59141 | main (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 × 30 | 100,536 (10) | — | — | — | 68,625 / 68,512 (7) |
| 20 × 300 | 53,148 (5.25) | 51,259 (5.15) | 38,737 | 37,871 | 37,888 / 37,887 (3.2) |
| 10,000 × 6 | 13,088 (5) | 17,326 (5) | 17,001 | 14,831 | 14,831 / 14,831 (3) |
| 10,000 × 30 | 13,112 (5) | 17,400 (5) | 17,067 | 15,001 | 14,903 / 14,898 (3) |
| 10,000 × 300 | 13,164 (5) | 18,621 (5.01) | 18,266 | 16,103 | 16,109 / 16,103 (3) |

The per-row growth predates census 8. #59141 removed two objects per row and about 2,200 Ir. What is left is call
overhead per record: `loaded_mapped_table` twice, `schema_attributes`, the builder, `_primary_key`, the
strict-loading class attributes, `RowLayout#build`, and the `Array.new` for cast values. AT-1 hoisted the builder
out of the loop (−9% at 20 rows). It is not exact, because it skips the overridable private `instantiate_instance_of`
(`RelationTest#test_relation_with_private_kernel_method` fails). [AT-1 patch](data/rails-main-census-9/AT1-rejected.patch).
Under YJIT, main's 1,000- and 10,000-row windows compile 1 block each, so no YJIT per-row claim is made.

## Main vs 8-1-stable in the census

**CPU** (`script/cpu-census`, labels `c9s` and `c9m`/`c9m2`, interpreter, 71 workloads, all JIT-flat):

| App | Workloads | Median main vs 8.1 | Range | A/A median \|Δ\| |
| --- | ---: | ---: | --- | ---: |
| blog | 10 | −12.20% | −25.00% … −5.39% | 0.09% |
| casa | 10 | −8.95% | −24.49% … −0.14% | 0.03% |
| codetriage | 7 | −4.01% | −12.65% … +4.03% | 0.07% |
| hackatime | 12 | −5.69% | −19.10% … −2.02% | 0.10% |
| pingcrm | 8 | −5.59% | −6.35% … −4.80% | 0.10% |
| react-starter-kit | 8 | −7.06% | −8.63% … −4.96% | 0.07% |
| redprints-cfp | 8 | −6.67% | −9.06% … −2.36% | 0.47% |
| writebook | 8 | −6.90% | −9.80% … −3.24% | 0.05% |

All 71 workloads: median −6.48%; 68 faster and 1 slower beyond 1%. The slower one is codetriage
`perform SendSingleTriageEmailJob` (+4.03%), the `log_level = :debug` event-reporter case that
[main-regressions](main-regressions.md) already judged deliberate. The 8.1 twin (`c9s2`) was stopped after 3 apps to
save orb time, so `cpu_regress.rb` uses main's A/A for both sides of every cell.

Methods that grew in every app ([full list](data/rails-main-census-9/cpu-81-main-method.txt),
[lines](data/rails-main-census-9/cpu-81-main-line.txt)). New code is mostly #59141's attribute set, then features
already judged deliberate:

| Method (8 apps each) | Net % of all 8.1 Ir | Disposition |
| --- | ---: | --- |
| `TagBuilder#append_tag_option` (new, 49580d1d04) | +0.634% | Extracted from `tag_options`; `tag_helper.rb` as a whole is −0.192% |
| `LazyIndexedAttributeSet#index_for_name` | +0.298% | **Lead 4** |
| `Result::RowLayout#initialize` | +0.296% | #59141's row layout; `result.rb` as a whole is −0.735% |
| `LazyIndexedAttributeSet#value_at!`, `fetch_value_at!`, `initialize`, `cast_value`, `IndexedRow.key_at?` | +0.135% to +0.272% each | #59141's new readers; replace `LazyAttributeSet#fetch_value` (−0.794%) |
| `OptimizedUrlHelper#call` | +0.257% | `route_set.rb` as a whole is −0.761% |
| `WeakKeyMap#fetch_or_store`, `association_route`, `current_default_association_route?` | +0.145% to +0.245% | Deliberate ([rails-82-impact](rails-82-impact.md)) |
| `LazyIndexedAttributeSet#keys` | +0.134% | **K1** |
| `QueryIntent`, `start_intent_log`, `execute_intent` | +0.055% to +0.124% | Deliberate (new feature) |
| `csrf_token_hmac` | +0.152% | Keyed HMAC reuse: native digest work is now charged to this frame; deliberate |
| `schema_context`, `current_schema_context`, `schema_attributes`, `loaded_mapped_table` | +0.067% to +0.084% each | Deliberate (#58437, #59530); part of lead 7's per-row cost |
| `table_name_qualified_unscope_values` | +0.025% | **Lead 8** |

By file, net: `attribute_set.rb` +1.434% and `query_intent.rb` +0.369% grew most. `attribute_set/builder.rb`
−1.216%, `journey/formatter.rb` −0.917% and `route_set.rb` −0.761% shrank most
([by file](data/rails-main-census-9/cpu-net-81-main-file.txt)).

**Allocations** (`script/census`, labels `a9s`/`a9s2` and `a9m`/`a9m2`): A/A median 0.0 / 0.0 objects per workload
(interpreter / YJIT). Main against 8.1 is a median of **−601 / −633 objects**, with all 71 workloads lower and 12
SQL digests changed ([compare](data/rails-main-census-9/alloc-compare-81-main.txt)). The broad allocation growth is
#59141's attribute-set classes, `table_name_qualified_unscope_values` (+13 objects, 57 workloads), and the retry
budget, intent log and default scope. All of it is outweighed by what went away.

## Changes since census 8

### Census

**CPU** (`c9c8` against `c9m`/`c9m2`, interpreter, 71 workloads; [by file](data/rails-main-census-9/cpu-net-c8-main-file.txt),
[by method](data/rails-main-census-9/cpu-net-c8-main-method.txt), [per cell](data/rails-main-census-9/cpu-c8-main-method.txt)):
main is a median **−1.78%** faster than census 8's pin, with 49 workloads faster and 1 slower beyond 1%. By app the
median runs from −0.17% (redprints-cfp) to −4.51% (pingcrm). The one slower workload is redprints-cfp `GET home`
(+1.19%, against an A/A median of 0.47% for that app). It is the static-file probe and the `tag_options` checks below.

| Since census 8, net % of all census 8 Ir | Grew | Shrank | Cause |
| --- | ---: | ---: | --- |
| #59141's attribute set (`attribute_set.rb`, `indexed_row.rb`, `builder.rb`, `result.rb`, `querying.rb`) | +0.626% | −1.493% | Net **−0.87%**; the growth is leads 1, 3, 4 and 5 |
| `index_with` (our merged #59557) | | −0.392% | Ours |
| `String#blank?` and `tag_options` (99a3247ebc, GHSA-68p9-83h6-5wpj) | +0.166% / +0.150% | `append_tag_option` −0.160% | Security fix, released in 8.1.4.1; not a lead |
| `_set_vary_header` (e38dd281d3, GHSA-r9jg-fmfx-2gv6) | +0.049% | | Security fix, released in 8.1.4.1; not a lead |
| `static.rb` precompressed probes (#59725) | +0.023% (6 apps) | | Deliberate, still cheaper than 8.1 |
| `form_tag_helper.rb`, `capture_helper.rb`, `output_safety_helper.rb` (#50312) | +0.029% (4–7 apps) | | Lead 2 |
| `model_schema.rb`, `schema_context.rb` | | −0.212% | #59530 (matthewd) |

So the biggest new hot spot since census 8 is the by-name and rebuild cost inside #59141's attribute set, which
#59141's gains outweigh in every app.

**Allocations** (`a9c8` against `a9m`, [compare](data/rails-main-census-9/alloc-compare-c8-main.txt)): median
**−76 / −75 objects** per workload, 68 lower and 3 higher, 2 SQL digests changed. The three higher (interpreter)
are redprints-cfp `GET home` +16.7, blog `POST comment (redirect)` +15.7 and blog `GET article` +2.1. New since
census 8:

* `ActionDispatch::FileHandler` probes precompressed copies for top-level misses: +12 objects per request in 6
  apps (b63dddb7e3, #59725). It is deliberate, and still fewer probes than 8.1 (6 against 9 for `/posts`).
* `button_to` (lead 2).
* `table_name_qualified_unscope_values` (lead 8).

### Commits merged since 2026-11-04 that matter here

108 first-parent commits ([list](data/rails-main-census-9/main-since-c8.txt)). In order of effect:

* **#59141** (tenderlove, 2026-11-11): this document's focus. Net faster in every app, with the regressions above.
* **#50312** (seanpdoyle, 2026-11-07): `button_to` on `form_tag`, lead 2.
* **#59709** (b2a1d01a4d, 2026-11-10), qualify unscope values when merging (fixes #48227): lead 8. #59780 (kehra,
  2026-11-14) fixes its Array case, and #59767 (kamipo) deprecates unqualified unscope of other tables.
* **#59725** (b63dddb7e3): static precompressed probes, above.
* **#59727** (salasebas), `JoinDependency` key aliases, and #59739 (ilianah), JSON schema cache allocations: both
  are allocation reductions. They were not attributed per workload.
* **#59530** (matthewd), schema context primary keys: part of `schema_*` above.

### Our merged changes

* **CW1, [#59642](https://github.com/rails/rails/pull/59642)** (merged 2026-11-12, `0e655babbc`):
  `where("x = ?", v).to_sql` −1.6% interpreted and −6.8% YJIT, 52 → 44 objects; `where_named_to_sql` −6.3% YJIT,
  71 → 62 objects (A/A ≤ 0.1%, [raw](data/rails-main-census-9/raw/cw1-yjit.txt)). Both lib lines survive on main.
* **AR-1, [#59629](https://github.com/rails/rails/pull/59629)** (merged 2026-11-09, `e39506b600`): restores
  `find_template` as a compatibility alias (`lookup_context.rb:161`). It is a correctness fix with no hot-path
  effect, and survives.
* **Reverted or rewritten upstream** ([`ours_survive.rb`](../../bench/upstream/census9/ours_survive.rb) against main,
  [output](data/rails-main-census-9/ours-survive.txt)):
  * #59584 (JSON::Coder escape skip) was **reverted** by byroot in #59713 (`ebfaed3969`).
  * #59640 (`local_cache_key`): byroot rewrote the line in #59714 (`15110dfcbb`, "Further simplify").
  * #59568 (attribute-set lookups) was **superseded** by #59141.
  * #59634, #59576 and #59533 (`WhereClause`/`where!`): lines rewritten by our own later merges and kamipo's
    `eabb5b9553`.
  * #59556 (Merger dup) was replaced by an early return; kamipo's later merges changed the file.
  * #59236 and #59235 were changed before census 8 (84048ad477, e3dd00a4bb).

  The other merged PRs keep every lib line.

## Method and pins

* **Rails:** main [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b)
  (merge of #59780, fetched 2026-11-14). 8-1-stable [`71e963ed1b`](https://github.com/rails/rails/commit/71e963ed1b0c8e5d1ff6e9124236cf7c4d4a24b9)
  (#59781). Census 8 [`1105756f42`](https://github.com/rails/rails/commit/1105756f426ee42834af5c87b4549ef709d631e5).
  #59141: parent `c48c154e3f`, merge `1f32b09101`. #50312: parent `9ba8b1edee`, merge `22898dbd82`. CW1 `0e655babbc`,
  AR-1 `e39506b600`.
* **Ruby** 4.0.9 (`3e93b23afc`), interpreter and `--yjit`. ZJIT was not run.
* **Corpus:** the 8 census apps that run on 8.1 and need no MySQL: blog, writebook, codetriage, pingcrm,
  redprints-cfp, react-starter-kit, casa and hackatime (71 workloads), with census 7's overlays (`script/census
  setup`). This answers "8.1 against main" at the same reach as [main-regressions](main-regressions.md), at a third
  of census 8's 251 workloads.
* **Census runs:**
  * [`run_census.sh`](data/rails-main-census-9/run_census.sh) (with [`heap.sh`](data/rails-main-census-9/heap.sh)): allocations `a9m`/`a9m2`, `a9s`/`a9s2`, `a9c8`; CPU
    `c9m`/`c9m2`, `c9s`, `c9c8`, interpreter, `--jobs 3`.
  * Comparison: [`cpu_regress.rb`](../../bench/upstream/census9/cpu_regress.rb), per cell, and
    [`cpu_net.rb`](../../bench/upstream/census9/cpu_net.rb), the net per key.
  * The YJIT CPU census was not run; YJIT claims come from the micros and their per-window gate.
* **Micros:** [`attr_micro.rb`](../../bench/upstream/census9/attr_micro.rb),
  [`req_micro.rb`](../../bench/upstream/census9/req_micro.rb) and
  [`rows_micro.rb`](../../bench/upstream/census9/rows_micro.rb), with sweep scripts next to them.
  * Each case: N calls (100–200) after a 100–300-call warmup.
  * `IrCount` ([`ir_count.c`](../../bench/upstream/census9/ir_count.c)) reads the thread's exact Ir under census
    8's patched Callgrind (`--instr-atstart=no`). Objects come from `GC.stat`, with GC disabled in the window.
  * Under YJIT, warmup runs until three windows in a row compile nothing (at most 30), and the measured window's
    block count is printed. Any nonzero count makes the cell "not flat", and it does not count.
  * Each tree runs in its own process; one tree under two names is the A/A.
* **Fixed heap:** `RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000`, the same for every run.
* **Sweeps, including very large inputs:**
  * table width 6/30/100/300 columns;
  * rows per load 1/20/1,000/10,000;
  * `button_to` with 0/20/200/2,000 params and a 1 MB label;
  * `Marshal.dump` at 6/30/100/300 columns.
* **Exactness:** `button_to_diff.rb` (5,760 inputs) and `keys_equiv.rb` (K1).
* **Repeats:** the per-row sweep for census 8, before #59141 and #59141 ran up to four times, because its orb service
  restarted on exit. All runs are in `raw/rows.txt` and agree within 0.6%; the table uses the first.
* **Receipts:** [data/rails-main-census-9](data/rails-main-census-9/). Restore notes and orb scripts are in
  `.amp/in/orb-backup/` (NOTES.md).

## Limits

* YJIT numbers come from micros only. Per-row loads on main compile 1 block per window at 1,000 and 10,000 rows,
  so no YJIT row result is claimed.
* Lead 3 has no census reach because no workload caches records. Its size is per cached record.
* Lead 6: the part of `update!`'s growth that does not depend on width (+4.6% at 30 and +8.2% at 6 columns with
  K1 + L6) is not attributed. L6 has no Ruby master × ZJIT numbers yet.
* The 8 apps include no MySQL app, and no app on `load_defaults "8.2"`.
