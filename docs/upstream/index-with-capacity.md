# `Enumerable#index_with` with `Hash.new(capacity:)`

**Result: one variant beats `to_h` on Ruby 4.1 without changing Ruby 4.0.** On Ruby 4.1, `Array#index_with` fills a
hash built with `Hash.new(capacity: size)`, or `{}` when the array has two elements or fewer. It is the same embedded hash
`Array#to_h` makes, without a pair Array per element. Ruby 4.0 and older keep `to_h` unchanged. It is one commit on
[`thomasklemm/index-with-capacity`](https://github.com/thomasklemm/rails/tree/thomasklemm/index-with-capacity),
[`c1da731`](https://github.com/thomasklemm/rails/commit/c1da73121f543f16c1ac61ddf65b431731b86061), based on canonical
main [`5810776eec`](https://github.com/rails/rails/commit/5810776eec). No PR is open.

| | main (`to_h`) | candidate on 4.1 |
| --- | --- | --- |
| Objects per call, n elements | n + 1 | 1 (interpreter); 1 for n ≤ 2, else 3 (YJIT, see [JIT gap](#leads-for-rubyruby-not-rails-prs)) |
| Result hash | embedded up to 8 entries | identical memsize at every size measured (0–50) |
| `index_with` spills (heap harness: railsbench / shipit / lobsters) | 0 / 0 / 0 | 0 / 0 / 0 (#59108's loop: 2003 / 163 / 212) |
| Heap harness objects, one iteration (interpreter) | | −11,993 / −60,651 / −5,408 |
| Census-4 apps, pair Arrays removed per workload sum | | 74–1,334 in all 9 apps that run on 4.1 |
| Wall time | | tie within A/A on lobsters and shipit, 4.1 and 4.0, interpreter and YJIT |

Allocation counts and heap bytes are not speed claims; the wall-time section is the only timing.

## History

* **2b88dc1995** (byroot, 2026-09-04, "Instantiate record with IndexedRows when joining") switched `index_with` from a
  `{}` + `each` loop to `to_h { |elem| [elem, value] }`.
* **#59108** (amatsuda, merged 2026-10-15) went back to `{}` + `each`, to drop the pair Array per element.
* **#59203** (amatsuda, merged 2026-10-20) reverted #59108 after byroot's review. Since ruby/ruby#18345, `{}` on Ruby
  4.1 has room for two entries, so the loop spills to a malloc'd table at the third insert, while `Array#to_h` presizes
  and stays embedded up to 8. byroot's heap harness counted `index_with` spills of 2003 / 163 / 212 on railsbench /
  shipit / lobsters with the loop and 0 after the revert; wall time was a tie. `Hash.new(capacity: 6)` did not help
  then (256 B, same as the spill), and byroot warned that parsing `capacity:` is expensive for small sizes.
* **ruby/ruby#19537** (byroot, merged 2026-10-29, [`7142a3d`](https://github.com/ruby/ruby/commit/7142a3debbda9c35bef9921fc59a27225969b979))
  gives `Hash` its own `new`, so `capacity:` is applied before the slot is allocated, and adds a `Hash` branch to the
  interpreter's `opt_new` that reads `capacity:` without a kwargs hash. byroot on #59203: "so we could consider
  `Hash.new(capacity:)` again".

## Pins and method

* **Ruby 4.0.7** (mise) and **Ruby 4.1.0dev master [`b51db981f6`](https://github.com/ruby/ruby/commit/b51db981f6)**
  (built 2026-11-02 with `--enable-yjit`; `git log` contains `7142a3d Optimize Hash.new(capacity:)`). Interpreter and
  `--yjit` on both. No ZJIT measurements.
* **Rails:** canonical main [`5810776eec`](https://github.com/rails/rails/commit/5810776eec) (fresh fetch, after
  #59544) for the commit, the AS suite and ruby-bench. The census-4 apps bundle
  [`b5be03636e`](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953); `enumerable.rb`,
  `indexed_row.rb`, `serialization.rb` and `attribute_set.rb` are identical between the two commits.
* **Variants** (full `enumerable.rb` copies in `.lowrail/private/index-with-capacity/variants/`, swapped into the
  bundled Rails, then restored):
  * `main`: `to_h { |elem| [elem, value] }`.
  * `each`: #59108, `{}` + `each`, for every enumerable.
  * `capa`: `Array#index_with` with `Hash.new(capacity: size)` + `each`, on every Ruby.
  * `gate`: `capa`, defined only when `RUBY_VERSION >= "4.1"`.
  * `gate2` (the candidate): `gate`, with `{}` instead of `Hash.new(capacity:)` for two elements or fewer.
* **Per call:** [`bench/upstream/index_with_micro.rb`](../../bench/upstream/index_with_micro.rb), Array (and Set)
  of frozen Strings, block and default forms, GC disabled, 20,000 calls.
* **Heap harness:** byroot's [heap-report harness](https://github.com/ruby/ruby-bench/compare/main...byroot:ruby-bench:heap-harness)
  (`byroot/ruby-bench` `bf1afb2`), run on ruby-bench's railsbench, shipit and lobsters with Rails pointed at the main
  worktree. One prewarm iteration, then one iteration with GC disabled and `ObjectSpace.dump_all`. A thin wrapper
  (`harness-iw`, in the orb checkout) keeps byroot's report and adds totals plus every object allocated in
  `core_ext/enumerable.rb`. Spills are counted as byroot does: hashes of at most 8 entries with malloc'd memory.
* **Census-4 apps:** [`bench/upstream/index_with_heap.rb`](../../bench/upstream/index_with_heap.rb) runs census 4's
  boot and workloads ([rails-main-census-4.md](rails-main-census-4.md)) and adds slot bytes, malloc bytes, Hash
  spills and `enumerable.rb` allocations per workload;
  [`index_with_heap_compare.rb`](../../bench/upstream/index_with_heap_compare.rb) sums the deltas per app.
* **Wall time:** ruby-bench's default harness on lobsters and shipit, 10 warmup and 20 timed iterations per process,
  variants interleaved in rotated order per round (4.1: `main-A`, `gate`, `gate2`, `main-B`, 5 rounds; 4.0: `main-A`,
  `gate`, `main-B`, 3 rounds), every other service stopped.
* Raw receipts are in `.lowrail/private/index-with-capacity/` (micro tables, heap summaries, app JSON, size histogram,
  variants, wall-time logs).

### Bench-local compatibility changes (same for every variant)

Rails main (8.2 defaults) does not run the three ruby-bench apps unchanged. Every variant got the same changes:

* All three apps add `gem "prism"`: Ruby master no longer ships prism as a default gem, and Action View requires it.
* **lobsters:** `forgery_protection_verification_strategy = :header_or_legacy_token`. The 8.2 default
  (`:header_only`) drops the form token that the route generator logs in with.
* **lobsters, shipit:** `erb_implementation = :erubi`. Herb, the 8.2 default, rejects `users/tree.html.erb` and
  shipit-engine's `stacks/index.html.erb`.
* **shipit:** shipit-engine 0.45.0 is vendored with one change. `ReviewStack` reopens `model_name`, which Rails main
  now freezes, so it overrides `self.model_name` on a dup instead.
* **Census-4 apps on 4.1:** a `Gemfile.r41` copy without the `ruby` line, plus `prism`. Writebook needs
  redcarpet 3.6.1, because 3.6.0 doesn't compile on Ruby master. The census copy of lobsters is skipped on 4.1:
  commonmarker 2.6.3 (rb-sys) and stackprof don't build on Ruby master. ruby-bench's lobsters covers it there.
  Redis and memcached run as services.

## Per call

Array, block form (the default form is identical). Objects and slot bytes per call, then the memsize of the
result. Spilled means a hash of at most 8 entries with a malloc'd table; above 8 every variant uses a malloc'd
table.

| n | Ruby | mode | main `to_h` | #59108 `{}` + each | `Hash.new(capacity:)` | gate2 (4.1: `{}` for ≤ 2) |
|---:|---|---|---|---|---|---|
| 0 | 4.0.7 | interpreter | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B (unchanged) |
| 0 | 4.0.7 | YJIT | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B (unchanged) |
| 0 | 4.1.0dev | interpreter | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B |
| 0 | 4.1.0dev | YJIT | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B | 3 obj, 192 B → 64 B | 1 obj, 64 B → 64 B |
| 1 | 4.0.7 | interpreter | 2 obj, 200 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 256 B **spilled** | 2 obj, 200 B → 160 B (unchanged) |
| 1 | 4.0.7 | YJIT | 2 obj, 200 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 256 B **spilled** | 2 obj, 200 B → 160 B (unchanged) |
| 1 | 4.1.0dev | interpreter | 2 obj, 104 B → 64 B | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B |
| 1 | 4.1.0dev | YJIT | 2 obj, 104 B → 64 B | 1 obj, 64 B → 64 B | 3 obj, 192 B → 64 B | 1 obj, 64 B → 64 B |
| 2 | 4.0.7 | interpreter | 3 obj, 240 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 256 B **spilled** | 3 obj, 240 B → 160 B (unchanged) |
| 2 | 4.0.7 | YJIT | 3 obj, 240 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 256 B **spilled** | 3 obj, 240 B → 160 B (unchanged) |
| 2 | 4.1.0dev | interpreter | 3 obj, 144 B → 64 B | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B | 1 obj, 64 B → 64 B |
| 2 | 4.1.0dev | YJIT | 3 obj, 144 B → 64 B | 1 obj, 64 B → 64 B | 3 obj, 192 B → 64 B | 1 obj, 64 B → 64 B |
| 3 | 4.0.7 | interpreter | 4 obj, 280 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 256 B **spilled** | 4 obj, 280 B → 160 B (unchanged) |
| 3 | 4.0.7 | YJIT | 4 obj, 280 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 256 B **spilled** | 4 obj, 280 B → 160 B (unchanged) |
| 3 | 4.1.0dev | interpreter | 4 obj, 200 B → 80 B | 1 obj, 64 B → 160 B **spilled** | 1 obj, 80 B → 80 B | 1 obj, 80 B → 80 B |
| 3 | 4.1.0dev | YJIT | 4 obj, 200 B → 80 B | 1 obj, 64 B → 160 B **spilled** | 3 obj, 208 B → 80 B | 3 obj, 208 B → 80 B |
| 6 | 4.0.7 | interpreter | 7 obj, 400 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 352 B **spilled** | 7 obj, 400 B → 160 B (unchanged) |
| 6 | 4.0.7 | YJIT | 7 obj, 400 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 352 B **spilled** | 7 obj, 400 B → 160 B (unchanged) |
| 6 | 4.1.0dev | interpreter | 7 obj, 368 B → 128 B | 1 obj, 64 B → 256 B **spilled** | 1 obj, 128 B → 128 B | 1 obj, 128 B → 128 B |
| 6 | 4.1.0dev | YJIT | 7 obj, 368 B → 128 B | 1 obj, 64 B → 256 B **spilled** | 3 obj, 256 B → 128 B | 3 obj, 256 B → 128 B |
| 8 | 4.0.7 | interpreter | 9 obj, 480 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 544 B **spilled** | 9 obj, 480 B → 160 B (unchanged) |
| 8 | 4.0.7 | YJIT | 9 obj, 480 B → 160 B | 1 obj, 160 B → 160 B | 1 obj, 160 B → 544 B **spilled** | 9 obj, 480 B → 160 B (unchanged) |
| 8 | 4.1.0dev | interpreter | 9 obj, 480 B → 160 B | 1 obj, 64 B → 256 B **spilled** | 1 obj, 160 B → 160 B | 1 obj, 160 B → 160 B |
| 8 | 4.1.0dev | YJIT | 9 obj, 480 B → 160 B | 1 obj, 64 B → 256 B **spilled** | 3 obj, 288 B → 160 B | 3 obj, 288 B → 160 B |
| 12 | 4.0.7 | interpreter | 13 obj, 560 B → 464 B | 1 obj, 160 B → 544 B | 1 obj, 160 B → 544 B | 13 obj, 560 B → 464 B (unchanged) |
| 12 | 4.0.7 | YJIT | 13 obj, 560 B → 464 B | 1 obj, 160 B → 544 B | 1 obj, 160 B → 544 B | 13 obj, 560 B → 464 B (unchanged) |
| 12 | 4.1.0dev | interpreter | 13 obj, 544 B → 448 B | 1 obj, 64 B → 448 B | 1 obj, 64 B → 448 B | 1 obj, 64 B → 448 B |
| 12 | 4.1.0dev | YJIT | 13 obj, 544 B → 448 B | 1 obj, 64 B → 448 B | 3 obj, 192 B → 448 B | 3 obj, 192 B → 448 B |
| 50 | 4.0.7 | interpreter | 51 obj, 2080 B → 1744 B | 1 obj, 160 B → 1824 B | 1 obj, 160 B → 1824 B | 51 obj, 2080 B → 1744 B (unchanged) |
| 50 | 4.0.7 | YJIT | 51 obj, 2080 B → 1744 B | 1 obj, 160 B → 1824 B | 1 obj, 160 B → 1824 B | 51 obj, 2080 B → 1744 B (unchanged) |
| 50 | 4.1.0dev | interpreter | 51 obj, 2064 B → 1728 B | 1 obj, 64 B → 1728 B | 1 obj, 64 B → 1728 B | 1 obj, 64 B → 1728 B |
| 50 | 4.1.0dev | YJIT | 51 obj, 2064 B → 1728 B | 1 obj, 64 B → 1728 B | 3 obj, 192 B → 1728 B | 3 obj, 192 B → 1728 B |

* On **4.1 interpreter**, `Hash.new(capacity: n)` is exact: one object, and the same embedded memsize as `to_h`
  at every size (64 B up to 2, 80 at 3, 128 at 6, 160 at 8).
* On **4.1 YJIT**, `Hash.new(capacity:)` allocates two extra transient Hashes. Neither YJIT nor ZJIT implements
  #19537's `opt_new` branch. That makes it worse than `to_h` for 0–1 elements (3 objects vs 1–2) and even at 2.
  `gate2` avoids that with `{}`, which holds two entries embedded on 4.1. From 3 elements up, `gate2` costs 3 objects
  against `to_h`'s n + 1. Bytes are within 8 B at n = 3 (208 vs 200) and lower from n = 4.
* On **4.0.7**, `Hash.new(capacity: n)` spills for every 1 ≤ n ≤ 8 (256–544 B against 160 B embedded), so the
  capacity path must not run there. The #59108 loop is exact on 4.0 (1 object, 160 B embedded up to 8).
* Set receivers on 4.1 spill even on main (`Enumerable#to_h` does not presize): 3 elements give 160 B with a malloc'd
  table, against 80 B embedded with `Hash.new(capacity:)`. The candidate does not change Sets (see
  [Rejected](#rejected-variants)).

### How often ordinary requests call it

`index_with` sizes on the census-4 workloads, one pass per workload (from `.lowrail/private/index-with-capacity/sizes.jsonl`):

| app | Array calls (+ other receivers) | 0–2 elements | 3–8 | > 8 | main callers |
| --- | ---: | ---: | ---: | ---: | --- |
| blog | 23 | 10 | 13 | 0 | `IndexedRow` (20), `attributes_with_values` (3) |
| campfire | 122 (+3) | 25 | 67 | 30 | `IndexedRow` (77), `AttributeSet#to_hash` (34), `attributes_with_values` (11) |
| writebook | 150 | 25 | 104 | 21 | `IndexedRow` (138), `attributes_with_values` (11) |
| fizzy | 301 (+5) | 108 | 142 | 51 | `IndexedRow` (233), `attributes_with_values` (35), `Key` (16), `insert_all` (12) |
| codetriage | 17 | 2 | 2 | 13 | `IndexedRow` (15) |
| pingcrm | 37 | 7 | 13 | 17 | `IndexedRow` (24), `serializable_hash` (12) |
| redprints-cfp | 20 | 4 | 7 | 9 | `IndexedRow` (19) |
| react-starter-kit | 30 | 9 | 21 | 0 | `IndexedRow` (18), `serializable_hash` (11) |
| lobsters | 130 | 51 | 16 | 63 | `IndexedRow` (118), `insert_all` (8) |

Every query result builds an `IndexedRow` column index with `index_with`. Every `as_json`/`render json:` record goes
through `serializable_hash`, and every save goes through `attributes_with_values`. Census 4 ranked the site second by
breadth: 9 of 9 apps and 93 % of workloads.

## Heap harness (byroot's)

One iteration with GC disabled, whole heap. The `index_with` columns count only objects allocated in
`core_ext/enumerable.rb` at the `index_with` lines. Under YJIT, the ≤ 8 embedded column for `gate`/`gate2` includes
the two transient Hashes per `Hash.new(capacity:)` call.

| app | Ruby | mode | variant | objects | heap B | malloc B | all ≤8 spills | index_with pair Arrays | index_with ≤8 embedded | index_with ≤8 spilled | index_with >8 | index_with hash bytes |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| lobsters | 40 | interp | main-A | 995843 | 73544200 | 167536981 | 3238 | 8629 | 234 | 0 | 752 | 681152 |
| lobsters | 40 | interp | main-B | 995853 | 73556520 | 167532315 | 3238 | 8629 | 234 | 0 | 752 | 681152 |
| lobsters | 40 | interp | gate | 995841 | 73544440 | 167533119 | 3238 | 8629 | 234 | 0 | 752 | 681152 |
| lobsters | 40 | interp | capa | 987159 | 73201520 | 167579231 | 3450 | 0 | 22 | 212 | 752 | 778480 |
| lobsters | 40 | interp | each | 987148 | 73227600 | 167529799 | 3238 | 0 | 234 | 0 | 752 | 741152 |
| lobsters | 40 | yjit | main-A | 998141 | 73524080 | 167681400 | 3238 | 8629 | 234 | 0 | 752 | 681152 |
| lobsters | 40 | yjit | main-B | 998059 | 73449400 | 167668724 | 3238 | 8629 | 234 | 0 | 752 | 681152 |
| lobsters | 40 | yjit | gate | 998051 | 73498400 | 167661335 | 3238 | 8629 | 234 | 0 | 752 | 681152 |
| lobsters | 40 | yjit | capa | 989528 | 73242120 | 167722185 | 3450 | 0 | 22 | 212 | 752 | 778320 |
| lobsters | 40 | yjit | each | 989476 | 73156640 | 167701255 | 3238 | 0 | 234 | 0 | 752 | 740992 |
| lobsters | 41 | interp | main-A | 968132 | 60078608 | 164333612 | 8261 | 8629 | 234 | 0 | 752 | 661728 |
| lobsters | 41 | interp | main-B | 968167 | 60093072 | 164328026 | 8271 | 8629 | 234 | 0 | 752 | 661728 |
| lobsters | 41 | interp | gate | 959551 | 59731592 | 164341416 | 8261 | 0 | 234 | 0 | 752 | 661728 |
| lobsters | 41 | interp | gate2 | 962724 | 60025528 | 130793047 | 8360 | 0 | 234 | 0 | 752 | 661728 |
| lobsters | 41 | interp | each | 960393 | 59816432 | 164359975 | 8483 | 0 | 22 | 212 | 752 | 683808 |
| lobsters | 41 | yjit | main-A | 973512 | 60433200 | 164351136 | 8360 | 8629 | 234 | 0 | 752 | 661728 |
| lobsters | 41 | yjit | main-B | 973540 | 60454224 | 164353645 | 8360 | 8629 | 234 | 0 | 752 | 661728 |
| lobsters | 41 | yjit | gate | 966125 | 60164272 | 164250328 | 8360 | 0 | 1300 | 0 | 752 | 729952 |
| lobsters | 41 | yjit | gate2 | 965958 | 60110584 | 164374948 | 8360 | 0 | 1256 | 0 | 752 | 727136 |
| lobsters | 41 | yjit | each | 964585 | 60048544 | 164407629 | 8572 | 0 | 22 | 212 | 752 | 683808 |
| railsbench | 40 | interp | main-A | 1244679 | 91213240 | 140842901 | 6345 | 12000 | 2003 | 0 | 2 | 321856 |
| railsbench | 40 | interp | main-B | 1244678 | 91216800 | 140841343 | 6345 | 12000 | 2003 | 0 | 2 | 321856 |
| railsbench | 40 | interp | gate | 1244675 | 91203960 | 140837362 | 6345 | 12000 | 2003 | 0 | 2 | 321856 |
| railsbench | 40 | interp | capa | 1232680 | 90718680 | 141239395 | 8348 | 0 | 0 | 2003 | 2 | 706336 |
| railsbench | 40 | interp | each | 1232669 | 90719840 | 140849747 | 6345 | 0 | 2003 | 0 | 2 | 322016 |
| railsbench | 40 | yjit | main-A | 1249409 | 91394720 | 140881013 | 6345 | 12000 | 2003 | 0 | 2 | 321856 |
| railsbench | 40 | yjit | main-B | 1249409 | 91398080 | 140882180 | 6345 | 12000 | 2003 | 0 | 2 | 321856 |
| railsbench | 40 | yjit | gate | 1249410 | 91393400 | 140882787 | 6345 | 12000 | 2003 | 0 | 2 | 321856 |
| railsbench | 40 | yjit | capa | 1237416 | 90915080 | 141269326 | 8348 | 0 | 0 | 2003 | 2 | 706416 |
| railsbench | 40 | yjit | each | 1237405 | 90919960 | 140884628 | 6345 | 0 | 2003 | 0 | 2 | 321936 |
| railsbench | 41 | interp | main-A | 1220882 | 74419024 | 137091563 | 19318 | 12000 | 2003 | 0 | 2 | 257648 |
| railsbench | 41 | interp | main-B | 1220878 | 74420232 | 137092711 | 19318 | 12000 | 2003 | 0 | 2 | 257648 |
| railsbench | 41 | interp | gate | 1208897 | 73921936 | 137085721 | 19318 | 0 | 2003 | 0 | 2 | 257648 |
| railsbench | 41 | interp | gate2 | 1208889 | 73917880 | 137084440 | 19318 | 0 | 2003 | 0 | 2 | 257648 |
| railsbench | 41 | interp | each | 1208877 | 73782744 | 137475894 | 21321 | 0 | 0 | 2003 | 2 | 513920 |
| railsbench | 41 | yjit | main-A | 1225659 | 74601192 | 137113249 | 19318 | 12000 | 2003 | 0 | 2 | 257648 |
| railsbench | 41 | yjit | main-B | 1225318 | 74580312 | 137129625 | 19318 | 12000 | 2003 | 0 | 2 | 257648 |
| railsbench | 41 | yjit | gate | 1217394 | 74336456 | 137131130 | 19318 | 0 | 6003 | 0 | 2 | 513648 |
| railsbench | 41 | yjit | gate2 | 1217590 | 74380480 | 137127088 | 19318 | 0 | 6003 | 0 | 2 | 513648 |
| railsbench | 41 | yjit | each | 1213389 | 73984032 | 137497969 | 21321 | 0 | 0 | 2003 | 2 | 513920 |
| shipit | 40 | interp | main-A | 1383924 | 97655400 | 150744511 | 6327 | 60493 | 163 | 0 | 3859 | 2878992 |
| shipit | 40 | interp | main-B | 1383938 | 97645480 | 150744045 | 6327 | 60493 | 163 | 0 | 3859 | 2878992 |
| shipit | 40 | interp | gate | 1383902 | 97673720 | 150744151 | 6327 | 60493 | 163 | 0 | 3859 | 2878992 |
| shipit | 40 | interp | capa | 1323485 | 95543880 | 150799980 | 6490 | 0 | 0 | 163 | 3859 | 3239872 |
| shipit | 40 | interp | each | 1323433 | 95539040 | 150711953 | 6327 | 0 | 163 | 0 | 3859 | 3148288 |
| shipit | 40 | yjit | main-A | 1397206 | 98179400 | 150780281 | 6327 | 60493 | 163 | 0 | 3859 | 2878992 |
| shipit | 40 | yjit | main-B | 1397243 | 98199240 | 150778455 | 6327 | 60493 | 163 | 0 | 3859 | 2878992 |
| shipit | 40 | yjit | gate | 1397276 | 98194240 | 150778712 | 6327 | 60493 | 163 | 0 | 3859 | 2878992 |
| shipit | 40 | yjit | capa | 1336793 | 96081440 | 150837880 | 6490 | 0 | 0 | 163 | 3859 | 3239872 |
| shipit | 40 | yjit | each | 1336724 | 96065880 | 150732017 | 6327 | 0 | 163 | 0 | 3859 | 3148528 |
| shipit | 41 | interp | main-A | 1346002 | 78747576 | 149250301 | 11635 | 60493 | 163 | 0 | 3859 | 2817104 |
| shipit | 41 | interp | main-B | 1345920 | 78746088 | 149236892 | 11635 | 60493 | 163 | 0 | 3859 | 2817104 |
| shipit | 41 | interp | gate | 1285660 | 76342640 | 149253643 | 11635 | 0 | 163 | 0 | 3859 | 2817104 |
| shipit | 41 | interp | gate2 | 1285351 | 76346952 | 149247325 | 11635 | 0 | 163 | 0 | 3859 | 2817104 |
| shipit | 41 | interp | each | 1285606 | 76310120 | 149239338 | 11798 | 0 | 0 | 163 | 3859 | 2793600 |
| shipit | 41 | yjit | main-A | 1359131 | 79281360 | 149270274 | 11635 | 60493 | 163 | 0 | 3859 | 2817104 |
| shipit | 41 | yjit | main-B | 1359122 | 79278912 | 149269926 | 11635 | 60493 | 163 | 0 | 3859 | 2817104 |
| shipit | 41 | yjit | gate | 1306077 | 77343864 | 149275686 | 11635 | 0 | 7581 | 0 | 3859 | 3291856 |
| shipit | 41 | yjit | gate2 | 1306063 | 77335176 | 149274012 | 11635 | 0 | 7581 | 0 | 3859 | 3291856 |
| shipit | 41 | yjit | each | 1298571 | 76843640 | 149262425 | 11798 | 0 | 0 | 163 | 3859 | 2793600 |

* **Spills:** `index_with` spills stay at 0 on all three apps with `gate`/`gate2`, as with `to_h`. The #59108 loop
  reproduces byroot's 2003 / 163 / 212 on 4.1 exactly, and the ungated `capa` gives the same numbers on 4.0.
* **4.1 interpreter, gate2 against main-A:** railsbench −11,993 objects and −0.50 MB heap; shipit −60,651 objects and
  −2.40 MB; lobsters −5,408 objects and −0.05 MB, and −33 MB malloc in that one run.
  gate2's lobsters run differs from gate's outside `index_with`: all ≤ 8 spills are 8,360 against 8,261, and malloc is −33 MB. `index_with`'s own allocations are identical (0 Arrays, 234 embedded, 661,728 B). Treat that lobsters total as single-run noise; gate's −8,581 objects is the cleaner figure for the same code in the interpreter.
* **4.1 YJIT, gate2:** railsbench −8,069 objects / −0.22 MB, shipit −53,068 / −1.95 MB, lobsters −7,554 / −0.32 MB.
* **A/A** (main-B − main-A): at most 341 objects and 75 kB heap on any app, Ruby and mode.
* **4.0:** `gate` matches main within A/A, since the method isn't defined there.

## Census-4 apps

Sums over each app's workloads (requests, jobs, mailers), per operation. **objects** and **slot B** are GC-enabled
medians, **malloc B** comes from the GC-disabled window, and **≤8 spills** counts every Hash in the window. The last
three columns count `core_ext/enumerable.rb` allocations, which include `index_by` as well. "hit" is the number of
workloads that reach `index_with`.

### Ruby 4.1.0dev

**gate2 - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | -150.7 | -10653.2 | -49595.5 | -0.5 | 76.0→2.0 | 24.5→24.0 | 0→0 |
| blog | yjit | 10 | 9 | +84.9 | +3003.2 | -58578.7 | -1.1 | 76.4→2.0 | 24.9→50.0 | 0→0 |
| campfire | interpreter | 9 | 9 | -207.7 | -8297.6 | -13974.5 | +0.0 | 223.0→14.0 | 89.0→89.0 | 34.0→34.0 |
| campfire | yjit | 9 | 9 | -154.0 | -4860.0 | -10361.5 | +0.0 | 223.0→14.0 | 89.0→143.0 | 34.0→34.0 |
| codetriage | interpreter | 7 | 7 | -291.6 | -10520.8 | -10613.5 | +0.0 | 300.0→7.0 | 17.0→17.0 | 0→0 |
| codetriage | yjit | 7 | 7 | -272.2 | -14242.8 | -17628.2 | +0.0 | 300.0→7.0 | 17.0→47.0 | 0→0 |
| fizzy | interpreter | 14 | 14 | -1413.0 | -57957.6 | -72552.6 | +0.4 | 1425.1→94.2 | 306.0→306.0 | 13.0→13.0 |
| fizzy | yjit | 14 | 14 | -983.2 | -30861.2 | -48431.4 | +0.4 | 1417.0→86.1 | 306.0→658.0 | 13.0→13.0 |
| fizzy-mysql | interpreter | 14 | 14 | -1336.3 | -53503.2 | -93108.6 | -1.2 | 1428.1→94.0 | 251.0→251.0 | 13.0→13.0 |
| fizzy-mysql | yjit | 14 | 14 | -996.1 | -31571.6 | -68898.5 | -1.2 | 1420.1→86.0 | 251.0→593.0 | 13.0→13.0 |
| pingcrm | interpreter | 8 | 8 | -323.8 | -32544.8 | -21139.1 | +0.0 | 302.0→13.0 | 37.0→37.0 | 6.0→6.0 |
| pingcrm | yjit | 8 | 8 | -193.2 | +13314.8 | -10291.1 | +0.0 | 302.0→13.0 | 37.0→97.0 | 6.0→6.0 |
| react-starter-kit | interpreter | 8 | 7 | -134.9 | -3469.2 | -8542.5 | +0.0 | 139.0→1.0 | 30.0→30.0 | 0→0 |
| react-starter-kit | yjit | 8 | 7 | -83.0 | +4079.6 | -5680.4 | +0.0 | 139.0→1.0 | 30.0→72.0 | 0→0 |
| redprints-cfp | interpreter | 8 | 7 | -177.6 | -10188.4 | -10404.4 | +0.0 | 173.0→0 | 20.0→20.0 | 0→0 |
| redprints-cfp | yjit | 8 | 7 | -133.4 | -2163.6 | -9514.6 | +0.0 | 173.0→0 | 20.0→52.0 | 0→0 |
| writebook | interpreter | 8 | 8 | -547.1 | -21452.4 | -35366.0 | +0.0 | 574.0→26.0 | 101.0→101.0 | 0→0 |
| writebook | yjit | 8 | 8 | -407.6 | -16247.2 | -26322.2 | +0.0 | 574.0→26.0 | 101.0→249.0 | 0→0 |

**main-B - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | -148.4 | -9137.6 | -46017.9 | -0.5 | 76.0→74.0 | 24.5→24.0 | 0→0 |
| blog | yjit | 10 | 9 | -0.3 | -365.6 | -56710.3 | -1.1 | 76.4→74.0 | 24.9→24.0 | 0→0 |
| campfire | interpreter | 9 | 9 | -0.0 | -0.0 | -1411.5 | +0.0 | 223.0→223.0 | 89.0→89.0 | 34.0→34.0 |
| campfire | yjit | 9 | 9 | -0.2 | -16.0 | +406.5 | +0.0 | 223.0→223.0 | 89.0→89.0 | 34.0→34.0 |
| codetriage | interpreter | 7 | 7 | -4.5 | -101.6 | +4407.5 | +0.0 | 300.0→300.0 | 17.0→17.0 | 0→0 |
| codetriage | yjit | 7 | 7 | +0.1 | +444.8 | -2016.6 | +0.0 | 300.0→300.0 | 17.0→17.0 | 0→0 |
| fizzy | interpreter | 14 | 14 | +1.1 | +34.4 | -10501.6 | -0.4 | 1425.1→1425.0 | 306.0→306.0 | 13.0→13.0 |
| fizzy | yjit | 14 | 14 | -84.5 | -4782.0 | -5157.5 | +0.0 | 1417.0→1417.0 | 306.0→306.0 | 13.0→13.0 |
| fizzy-mysql | interpreter | 14 | 14 | -65.2 | -3758.0 | +13051.8 | +1.2 | 1428.1→1428.2 | 251.0→251.0 | 13.0→13.0 |
| fizzy-mysql | yjit | 14 | 14 | +130.1 | +6299.2 | +186.3 | -1.2 | 1420.1→1420.0 | 251.0→251.0 | 13.0→13.0 |
| pingcrm | interpreter | 8 | 8 | -24.5 | -11244.0 | -1716.9 | +0.0 | 302.0→302.0 | 37.0→37.0 | 6.0→6.0 |
| pingcrm | yjit | 8 | 8 | +2.8 | -153.6 | +962.1 | +0.0 | 302.0→302.0 | 37.0→37.0 | 6.0→6.0 |
| react-starter-kit | interpreter | 8 | 7 | +3.0 | +2120.4 | +877.1 | +0.0 | 139.0→139.0 | 30.0→30.0 | 0→0 |
| react-starter-kit | yjit | 8 | 7 | +9.6 | +5068.0 | +294.9 | +0.0 | 139.0→139.0 | 30.0→30.0 | 0→0 |
| redprints-cfp | interpreter | 8 | 7 | -4.4 | -3202.4 | -309.8 | +0.0 | 173.0→173.0 | 20.0→20.0 | 0→0 |
| redprints-cfp | yjit | 8 | 7 | +1.0 | +565.2 | +1084.0 | +0.0 | 173.0→173.0 | 20.0→20.0 | 0→0 |
| writebook | interpreter | 8 | 8 | +1.2 | +655.2 | -423.9 | +0.0 | 574.0→574.0 | 101.0→101.0 | 0→0 |
| writebook | yjit | 8 | 8 | -9.2 | -3941.6 | -2126.1 | +0.0 | 574.0→574.0 | 101.0→101.0 | 0→0 |

**gate - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | -20.5 | +2792.8 | -9248.2 | +0.0 | 76.0→2.0 | 24.5→24.5 | 0→0 |
| blog | yjit | 10 | 9 | +84.1 | +6827.6 | +11867.9 | -0.3 | 76.4→2.0 | 24.9→72.4 | 0→0 |
| campfire | interpreter | 9 | 9 | -203.7 | -8018.8 | +30588.3 | +0.0 | 223.0→14.0 | 89.0→89.0 | 34.0→34.0 |
| campfire | yjit | 9 | 9 | -104.7 | -1690.4 | -5994.3 | +0.0 | 223.0→14.0 | 89.0→193.0 | 34.0→34.0 |
| codetriage | interpreter | 7 | 7 | -285.2 | -6967.2 | -13190.7 | +0.0 | 300.0→7.0 | 17.0→17.0 | 0→0 |
| codetriage | yjit | 7 | 7 | -266.5 | -13271.6 | -15874.2 | +0.0 | 300.0→7.0 | 17.0→51.0 | 0→0 |
| fizzy | interpreter | 14 | 14 | -1330.6 | -53233.6 | -97943.7 | -0.4 | 1425.1→94.0 | 306.0→306.0 | 13.0→13.0 |
| fizzy | yjit | 14 | 14 | -841.9 | -21462.8 | -54075.4 | +0.0 | 1417.0→86.0 | 306.0→874.0 | 13.0→13.0 |
| fizzy-mysql | interpreter | 14 | 14 | -1403.4 | -57267.6 | -74497.7 | +1.2 | 1428.1→94.2 | 251.0→251.0 | 13.0→13.0 |
| fizzy-mysql | yjit | 14 | 14 | -811.2 | -20387.2 | -41414.7 | +1.2 | 1420.1→86.2 | 251.0→709.0 | 13.0→13.0 |
| pingcrm | interpreter | 8 | 8 | -280.5 | -3143.2 | -18662.5 | +0.0 | 302.0→13.0 | 37.0→37.0 | 6.0→6.0 |
| pingcrm | yjit | 8 | 8 | -175.1 | +12523.2 | -9218.9 | +0.0 | 302.0→13.0 | 37.0→111.0 | 6.0→6.0 |
| react-starter-kit | interpreter | 8 | 7 | -135.9 | -3862.4 | -8533.1 | +0.0 | 139.0→1.0 | 30.0→30.0 | 0→0 |
| react-starter-kit | yjit | 8 | 7 | -77.6 | -1464.4 | -4305.8 | +0.0 | 139.0→1.0 | 30.0→90.0 | 0→0 |
| redprints-cfp | interpreter | 8 | 7 | -174.8 | -8754.8 | -10547.8 | +0.0 | 173.0→0 | 20.0→20.0 | 0→0 |
| redprints-cfp | yjit | 8 | 7 | -127.2 | -1611.2 | -6897.2 | +0.0 | 173.0→0 | 20.0→60.0 | 0→0 |
| writebook | interpreter | 8 | 8 | -534.0 | -14787.2 | -35573.7 | +0.0 | 574.0→26.0 | 101.0→101.0 | 0→0 |
| writebook | yjit | 8 | 8 | -353.4 | -11049.6 | -24842.8 | +0.0 | 574.0→26.0 | 101.0→299.0 | 0→0 |

**each - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | -156.5 | -9808.4 | +177.5 | +14.0 | 76.0→2.0 | 24.5→24.8 | 0→13.5 |
| blog | yjit | 10 | 9 | -76.0 | -6384.4 | -19437.0 | +13.7 | 76.4→2.0 | 24.9→25.0 | 0→13.4 |
| campfire | interpreter | 9 | 9 | -207.1 | -9967.2 | -10869.6 | +20.0 | 223.0→14.0 | 89.0→89.0 | 34.0→54.0 |
| campfire | yjit | 9 | 9 | -209.8 | -10095.6 | -10947.5 | +20.0 | 223.0→14.0 | 89.0→89.0 | 34.0→54.0 |
| codetriage | interpreter | 7 | 7 | -289.4 | -9000.0 | -8933.5 | +2.0 | 300.0→7.0 | 17.0→17.0 | 0→2.0 |
| codetriage | yjit | 7 | 7 | -299.0 | -15751.6 | -18488.7 | +2.0 | 300.0→7.0 | 17.0→17.0 | 0→2.0 |
| fizzy | interpreter | 14 | 14 | -1352.9 | -63925.6 | -75212.4 | +132.6 | 1425.1→77.0 | 306.0→306.0 | 13.0→141.0 |
| fizzy | yjit | 14 | 14 | -1189.1 | -54508.8 | -34714.4 | +134.0 | 1417.0→69.2 | 306.0→306.0 | 13.0→141.0 |
| fizzy-mysql | interpreter | 14 | 14 | -1417.8 | -66557.6 | -53415.5 | +119.2 | 1428.1→77.2 | 251.0→251.0 | 13.0→131.0 |
| fizzy-mysql | yjit | 14 | 14 | -1356.0 | -63252.4 | -68904.1 | +116.8 | 1420.1→69.0 | 251.0→251.0 | 13.0→131.0 |
| pingcrm | interpreter | 8 | 8 | -284.4 | -9326.4 | -18858.8 | +7.0 | 302.0→13.0 | 37.0→37.0 | 6.0→13.0 |
| pingcrm | yjit | 8 | 8 | -260.1 | +2061.2 | -15541.7 | +7.0 | 302.0→13.0 | 37.0→37.0 | 6.0→13.0 |
| react-starter-kit | interpreter | 8 | 7 | -135.5 | -5754.8 | -4003.7 | +21.0 | 139.0→1.0 | 30.0→30.0 | 0→21.0 |
| react-starter-kit | yjit | 8 | 7 | -123.3 | +474.0 | -3757.1 | +21.0 | 139.0→1.0 | 30.0→30.0 | 0→21.0 |
| redprints-cfp | interpreter | 8 | 7 | -177.4 | -10972.0 | -10308.6 | +7.0 | 173.0→0 | 20.0→20.0 | 0→7.0 |
| redprints-cfp | yjit | 8 | 7 | -163.7 | -2283.6 | -10108.6 | +7.0 | 173.0→0 | 20.0→20.0 | 0→7.0 |
| writebook | interpreter | 8 | 8 | -537.2 | -20868.8 | -24450.7 | +56.0 | 574.0→26.0 | 101.0→101.0 | 0→56.0 |
| writebook | yjit | 8 | 8 | -549.2 | -26450.4 | -26463.6 | +56.0 | 574.0→26.0 | 101.0→101.0 | 0→56.0 |

### Ruby 4.0.7

**main-B - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | +6.4 | +1786.0 | -707.2 | +0.0 | 74.0→74.0 | 24.0→24.0 | 0→0 |
| blog | yjit | 10 | 9 | +22.9 | -3028.0 | -105639.2 | +0.0 | 76.4→76.4 | 24.6→24.9 | 0→0 |
| campfire | interpreter | 9 | 9 | -0.8 | -46.0 | +2341.9 | +0.0 | 223.0→223.0 | 89.0→89.0 | 0→0 |
| campfire | yjit | 9 | 9 | -1.2 | -62.0 | +376.2 | +0.0 | 223.0→223.0 | 89.0→89.0 | 0→0 |
| codetriage | interpreter | 7 | 7 | -6.2 | -1340.0 | -4199.5 | +0.0 | 300.0→300.0 | 17.0→17.0 | 0→0 |
| codetriage | yjit | 7 | 7 | +5.7 | +2240.0 | -5910.4 | +0.0 | 300.0→300.0 | 17.0→17.0 | 0→0 |
| fizzy | interpreter | 14 | 14 | -75.0 | -4768.0 | +199.3 | +0.0 | 1425.0→1425.0 | 306.0→306.0 | 2.0→2.0 |
| fizzy | yjit | 14 | 14 | +149.2 | -3008.0 | +18032.0 | +0.0 | 1417.0→1417.0 | 306.0→306.0 | 2.0→2.0 |
| fizzy-mysql | interpreter | 14 | 14 | -2.1 | -112.0 | +3840.6 | +1.0 | 1428.0→1428.1 | 251.0→251.0 | 2.0→2.0 |
| fizzy-mysql | yjit | 14 | 14 | +123.3 | +8168.0 | +3026.0 | +0.0 | 1420.0→1420.0 | 251.0→251.0 | 2.0→2.0 |
| lobsters | interpreter | 11 | 10 | +12.6 | -968.0 | +1851.4 | +0.0 | 1630.0→1630.0 | 127.5→127.5 | 0→0 |
| lobsters | yjit | 11 | 10 | +3.6 | -6106.0 | -58.8 | +0.0 | 1626.0→1626.0 | 127.5→127.5 | 0→0 |
| pingcrm | interpreter | 8 | 8 | +1.4 | +2498.0 | -1665.2 | +0.0 | 302.0→302.0 | 37.0→37.0 | 0→0 |
| pingcrm | yjit | 8 | 8 | +44.6 | +17386.0 | +3049.8 | +0.0 | 302.0→302.0 | 37.0→37.0 | 0→0 |
| react-starter-kit | interpreter | 8 | 7 | +0.7 | +12.0 | -242.7 | +0.0 | 139.0→139.0 | 30.0→30.0 | 0→0 |
| react-starter-kit | yjit | 8 | 7 | -8.0 | -3012.0 | -1321.9 | +0.0 | 139.0→139.0 | 30.0→30.0 | 0→0 |
| redprints-cfp | interpreter | 8 | 7 | -8.2 | -6064.0 | -675.6 | +0.0 | 173.0→173.0 | 20.0→20.0 | 0→0 |
| redprints-cfp | yjit | 8 | 7 | +2.4 | -646.0 | +834.8 | +0.0 | 173.0→173.0 | 20.0→20.0 | 0→0 |
| writebook | interpreter | 8 | 8 | -5.3 | -3200.0 | -947.8 | +0.0 | 574.0→574.0 | 101.0→101.0 | 0→0 |
| writebook | yjit | 8 | 8 | +1.7 | +1364.0 | -2628.4 | +0.0 | 574.0→574.0 | 101.0→101.0 | 0→0 |

**each - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | -175.8 | -9948.0 | +39003.4 | +0.0 | 74.0→2.0 | 24.0→24.5 | 0→0 |
| blog | yjit | 10 | 9 | -172.2 | -14024.0 | -162357.0 | +0.0 | 76.4→2.0 | 24.6→24.0 | 0→0 |
| campfire | interpreter | 9 | 9 | -210.2 | -7880.0 | -9537.8 | +0.0 | 223.0→14.0 | 89.0→89.0 | 0→0 |
| campfire | yjit | 9 | 9 | -209.1 | -7818.0 | -13236.6 | +0.0 | 223.0→14.0 | 89.0→89.0 | 0→0 |
| codetriage | interpreter | 7 | 7 | -299.6 | -15664.0 | -21129.1 | +0.0 | 300.0→7.0 | 17.0→17.0 | 0→0 |
| codetriage | yjit | 7 | 7 | -296.3 | -9664.0 | -20748.9 | +0.0 | 300.0→7.0 | 17.0→17.0 | 0→0 |
| fizzy | interpreter | 14 | 14 | -1345.4 | -49728.0 | -86687.5 | +0.0 | 1425.0→77.0 | 306.0→306.0 | 2.0→2.0 |
| fizzy | yjit | 14 | 14 | -1351.5 | -49690.0 | -74987.1 | +0.2 | 1417.0→69.1 | 306.0→306.0 | 2.0→2.0 |
| fizzy-mysql | interpreter | 14 | 14 | -1346.3 | -49364.0 | -76330.2 | +1.0 | 1428.0→77.1 | 251.0→251.0 | 2.0→2.0 |
| fizzy-mysql | yjit | 14 | 14 | -1300.1 | -46498.0 | -88045.6 | +0.0 | 1420.0→69.0 | 251.0→251.0 | 2.0→2.0 |
| lobsters | interpreter | 11 | 10 | -1588.4 | -57592.0 | -102045.8 | +0.0 | 1630.0→34.0 | 127.5→127.5 | 0→0 |
| lobsters | yjit | 11 | 10 | -1599.6 | -64104.0 | -100167.4 | +0.0 | 1626.0→30.0 | 127.5→127.5 | 0→0 |
| pingcrm | interpreter | 8 | 8 | -252.2 | +4994.0 | -18535.6 | +0.0 | 302.0→13.0 | 37.0→37.0 | 0→0 |
| pingcrm | yjit | 8 | 8 | -284.7 | -7894.0 | -17933.1 | +0.0 | 302.0→13.0 | 37.0→37.0 | 0→0 |
| react-starter-kit | interpreter | 8 | 7 | -126.2 | +492.0 | -10400.3 | +0.0 | 139.0→1.0 | 30.0→30.0 | 0→0 |
| react-starter-kit | yjit | 8 | 7 | -134.1 | -2954.0 | -9406.4 | +0.0 | 139.0→1.0 | 30.0→30.0 | 0→0 |
| redprints-cfp | interpreter | 8 | 7 | -186.2 | -14442.0 | -11122.5 | +0.0 | 173.0→0 | 20.0→20.0 | 0→0 |
| redprints-cfp | yjit | 8 | 7 | -166.7 | -2034.0 | -11803.2 | +0.0 | 173.0→0 | 20.0→20.0 | 0→0 |
| writebook | interpreter | 8 | 8 | -552.9 | -23364.0 | -35237.6 | +0.0 | 574.0→26.0 | 101.0→101.0 | 0→0 |
| writebook | yjit | 8 | 8 | -547.0 | -20170.0 | -35005.9 | +0.0 | 574.0→26.0 | 101.0→101.0 | 0→0 |

**capa - main-A** (per op, summed over workloads)
| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | interpreter | 10 | 9 | -244.9 | -15080.0 | +114710.9 | +16.3 | 74.0→2.0 | 24.0→25.6 | 0→16.3 |
| blog | yjit | 10 | 9 | -61.1 | -2416.0 | -71965.9 | +15.9 | 76.4→2.0 | 24.6→25.5 | 0→15.9 |
| campfire | interpreter | 9 | 9 | -210.2 | -7880.0 | -8326.1 | +27.0 | 223.0→14.0 | 89.0→89.0 | 0→27.0 |
| campfire | yjit | 9 | 9 | -210.0 | -7840.0 | -8582.2 | +27.0 | 223.0→14.0 | 89.0→89.0 | 0→27.0 |
| codetriage | interpreter | 7 | 7 | -293.8 | -15326.0 | -19655.9 | +4.0 | 300.0→7.0 | 17.0→17.0 | 0→4.0 |
| codetriage | yjit | 7 | 7 | -287.0 | -7078.0 | -18633.2 | +4.0 | 300.0→7.0 | 17.0→17.0 | 0→4.0 |
| fizzy | interpreter | 14 | 14 | -1412.1 | -54630.0 | -23237.9 | +187.4 | 1425.0→94.2 | 306.0→306.0 | 2.0→173.0 |
| fizzy | yjit | 14 | 14 | -1410.3 | -54538.0 | -27218.6 | +187.4 | 1417.0→86.2 | 306.0→306.0 | 2.0→173.0 |
| fizzy-mysql | interpreter | 14 | 14 | -680.2 | +2362.0 | -51238.6 | +180.6 | 1428.0→94.0 | 251.0→251.0 | 2.0→166.0 |
| fizzy-mysql | yjit | 14 | 14 | -1277.5 | -47328.0 | -25563.0 | +182.0 | 1420.0→86.2 | 251.0→251.0 | 2.0→166.0 |
| lobsters | interpreter | 11 | 10 | -1579.8 | -58996.0 | -87497.2 | +22.5 | 1630.0→34.0 | 127.5→127.5 | 0→22.5 |
| lobsters | yjit | 11 | 10 | -1598.9 | -64668.0 | -96095.4 | +22.5 | 1626.0→30.0 | 127.5→127.5 | 0→22.5 |
| pingcrm | interpreter | 8 | 8 | -283.9 | -4790.0 | -17037.3 | +20.0 | 302.0→13.0 | 37.0→37.0 | 0→20.0 |
| pingcrm | yjit | 8 | 8 | -291.0 | -11826.0 | -15844.8 | +20.0 | 302.0→13.0 | 37.0→37.0 | 0→20.0 |
| react-starter-kit | interpreter | 8 | 7 | -136.7 | -5072.0 | -5005.8 | +27.0 | 139.0→1.0 | 30.0→30.0 | 0→27.0 |
| react-starter-kit | yjit | 8 | 7 | -146.5 | -10672.0 | -4632.3 | +27.0 | 139.0→1.0 | 30.0→30.0 | 0→27.0 |
| redprints-cfp | interpreter | 8 | 7 | -175.0 | -7606.0 | -9896.0 | +8.0 | 173.0→0 | 20.0→20.0 | 0→8.0 |
| redprints-cfp | yjit | 8 | 7 | -172.6 | -4852.0 | -8330.6 | +8.0 | 173.0→0 | 20.0→20.0 | 0→8.0 |
| writebook | interpreter | 8 | 8 | -554.9 | -24612.0 | -17342.4 | +65.0 | 574.0→26.0 | 101.0→101.0 | 0→65.0 |
| writebook | yjit | 8 | 8 | -534.4 | -11806.0 | -21059.4 | +65.0 | 574.0→26.0 | 101.0→101.0 | 0→65.0 |

* The census apps confirm that `gate2` removes **all** `index_with` pair Arrays on every app (blog 76 → 2 …
  fizzy 1,425 → 94; the remainder is `pluck`/`excluding` in the same file) without new spills. Interpreter object
  deltas sit well outside A/A on 8 of 9 apps. Blog's main-A interpreter run is an outlier: main-B and gate2 are both
  about −150 against it.
* YJIT keeps a smaller net saving, because of the two transient Hashes per call with more than 2 elements. The
  saving is still beyond A/A on 8 of 9 apps; blog is +85, inside its noise. Slot bytes are mixed under YJIT
  (pingcrm +13 kB, react-starter-kit +4 kB), comparable to the YJIT A/A spread (pingcrm +17 kB on 4.0).
* On 4.0 the #59108 loop (`each`) saves about as much as `capa` with no spills. The ungated `capa` spills 4–187 small
  hashes per app sum, which is why the candidate keeps `to_h` on 4.0.

## Wall time

Each row: median per-process time (median of 20 timed iterations) over rounds, and the variant over the mean of the same round's main-A and main-B. On 4.0.7 the candidate is not defined, so `gate` there is a second A/A.

| app | Ruby | mode | rounds | main-A ms | main-B ms | variant | variant ms | variant / main (median, range) | A/A main-B / main-A (median, range) |
|---|---|---|---:|---:|---:|---|---:|---|---|
| lobsters | 4.0.7 | interpreter | 3 | 1280.0 | 1340.0 | gate | 1283.0 | +0.5% (-5.2% … +1.2%) | +2.2% (-0.5% … +10.9%) |
| lobsters | 4.0.7 | YJIT | 3 | 732.0 | 741.0 | gate | 758.5 | -1.1% (-1.2% … +6.6%) | +1.2% (-0.5% … +6.0%) |
| lobsters | 4.1.0dev | interpreter | 5 | 1205.0 | 1210.0 | gate | 1215.5 | +1.7% (-1.0% … +1.9%) | -0.5% (-5.7% … +3.4%) |
| lobsters | 4.1.0dev | interpreter | 5 | 1205.0 | 1210.0 | gate2 | 1195.5 | +1.1% (-4.7% … +1.6%) | -0.5% (-5.7% … +3.4%) |
| lobsters | 4.1.0dev | YJIT | 5 | 706.5 | 708.5 | gate | 703.5 | +0.6% (-2.6% … +2.2%) | +0.9% (-3.2% … +1.6%) |
| lobsters | 4.1.0dev | YJIT | 5 | 706.5 | 708.5 | gate2 | 685.0 | -3.5% (-4.4% … -0.5%) | +0.9% (-3.2% … +1.6%) |
| shipit | 4.0.7 | interpreter | 3 | 2237.5 | 2282.0 | gate | 2327.0 | +3.0% (+2.6% … +3.8%) | +2.0% (-7.9% … +6.6%) |
| shipit | 4.0.7 | YJIT | 3 | 1121.5 | 1096.5 | gate | 1137.5 | +2.3% (-1.0% … +4.1%) | -0.5% (-4.1% … +0.4%) |
| shipit | 4.1.0dev | interpreter | 5 | 2305.5 | 2285.0 | gate | 2281.5 | +0.8% (-5.7% … +4.1%) | -0.9% (-3.6% … +1.8%) |
| shipit | 4.1.0dev | interpreter | 5 | 2305.5 | 2285.0 | gate2 | 2278.0 | -1.0% (-2.7% … +8.8%) | -0.9% (-3.6% … +1.8%) |
| shipit | 4.1.0dev | YJIT | 5 | 1026.5 | 1017.5 | gate | 998.5 | -2.3% (-7.6% … +6.5%) | -0.8% (-4.0% … +0.1%) |
| shipit | 4.1.0dev | YJIT | 5 | 1026.5 | 1017.5 | gate2 | 998.5 | -0.6% (-4.1% … +7.5%) | -0.8% (-4.0% … +0.1%) |

Every variant/main ratio sits inside the spread of its A/A control or the 4.0 second A/A (up to +3.0 % median, +10.9 % per round). This is a tie, as with #59203. Allocation and heap counts above are not timing claims.

## The candidate

```ruby
class Array # :nodoc:
  if RUBY_VERSION >= "4.1"
    # Same as Enumerable#index_with, without a pair array per element. An empty
    # hash has room for two entries; for more, Hash.new(capacity:) sizes the
    # hash before allocating it (ruby/ruby#19537), so it is embedded for up to
    # 8 entries, as Array#to_h would make it.
    def index_with(default = (no_default = true))
      if block_given?
        result = size > 2 ? Hash.new(capacity: size) : {}
        each { |elem| result[elem] = yield(elem) }
        result
      elsif no_default
        to_enum(:index_with) { size }
      else
        result = size > 2 ? Hash.new(capacity: size) : {}
        each { |elem| result[elem] = default }
        result
      end
    end
  end
end
```

### Why it is exact, and its boundaries

* **Same result:** a plain `Hash` with no default or default proc. Insertion order is the array order; a duplicate key
  keeps its first position and its last value, as `to_h` does. The default form stores the same object, not a copy.
  The enumerator form returns an Enumerator sized by the array. The block runs once per element, in order. `break`
  and exceptions leave `index_with` as before.
* **Same memory on 4.1:** identical result memsize to `Array#to_h` at 0, 1, 2, 3, 6, 8, 9, 12 and 50 elements.
  The capacity is computed once, from `size` at the start. An array mutated inside the block still gets every key,
  as with `to_h` (both iterate by index); only the capacity reflects the old size.
* **Only arrays on 4.1:** every other receiver goes through `Enumerable#index_with`, unchanged (`to_h`). That is
  deliberate. A generic `respond_to?(:size)` path would call `Relation#size`, which can run a `COUNT` query, and
  `Enumerator#size`, which can be nil or computed lazily. Hash receivers are a separate question: main
  regressed them, which is fixed on its own branch (see [Other findings](#other-findings)).
* **Boundary: Array subclasses that override `each`.** Main's `to_h` is `Array#to_h`, which walks the array in C and
  ignores an overridden `each`; the candidate calls `each`. That is what Rails 8.1 and #59108 did. No Rails class
  does this, but a subclass whose `each` yields something other than its elements would now index those.
* **Boundary: Ruby 4.1.0dev builds between ruby/ruby#18345 and #19537** take the capacity path without #19537's
  presizing, so they spill as #59108 did. Released 4.1 will include #19537.
* **Ruby 3.3:** `Hash.new(capacity:)` does not exist before 3.4. The gate is `>= "4.1"`, so 3.3.5 never reaches it.

### Tests and suites

* New `test_index_with_array` in `activesupport/test/core_ext/enumerable_test.rb`. It checks 12 elements with the
  block and default forms against expectations built with `zip`, that the result has no default, the empty array,
  that the default object is shared, duplicate keys (order and last value), and the enumerator's size and `each`.
* On 4.1, it fails each of six wrong implementations: a positional `Hash.new(size)`, keeping the first value,
  `reverse_each` in either form, an unsized enumerator, and `default.dup`. It passes on unchanged main, so it
  pins current behavior rather than the implementation.
* **ActiveSupport suite, `RAILS_STRICT_WARNINGS=1`:** Ruby 4.0.7, 6869 runs, 29,892 assertions, 0 failures, 0 errors,
  60 skips. Ruby 4.1.0dev, 6869 runs, 0 failures and 1 error:
  `NotificationSubscriptionTest#test_record_and_set_subscriptions_when_using_a_regexp`, a
  `Ractor::Error: can not copy ActiveSupport::Notifications::Fanout::Registry` that occurs the same way on
  unchanged main under Ruby master (not related to this change). RuboCop: no offenses.

### PR description draft (not published)

> **Build `Array#index_with` without pair arrays on Ruby 4.1**
>
> ### Motivation / Background
>
> `index_with` runs on almost every request. Every query result builds `IndexedRow`'s column index with it, every
> `as_json`/`render json:` record goes through `serializable_hash`, and every save goes through
> `attributes_with_values`. It builds its hash with `to_h { [elem, value] }`, so it allocates one two-element pair
> array per element, which `to_h` immediately takes apart.
>
> #59108 replaced that with `{}` and an `each` loop. #59203 reverted it because, since ruby/ruby#18345, an empty hash on
> Ruby 4.1 only has room for two entries: the loop moved its table to the C heap at the third insert, while
> `Array#to_h` presizes and stays embedded up to eight. ruby/ruby#19537 now applies `Hash.new(capacity:)` before the
> hash is allocated, so on 4.1 it produces the same embedded hash as `Array#to_h`.
>
> ### Detail
>
> On Ruby 4.1, `Array#index_with` fills `Hash.new(capacity: size)`, or `{}` for two elements or fewer since that already
> fits them. Ruby 4.0 and older keep `to_h`, because there `Hash.new(capacity:)` spills even small hashes. Other
> enumerables keep `Enumerable#index_with`. The result is the same hash, with the same order, duplicate-key handling,
> default object and sized enumerator. Its memsize is identical to `to_h`'s at every size from 0 to 50.
>
> ### Additional information
>
> Per call on Ruby 4.1.0dev (7142a3d): n + 1 objects become 1 in the interpreter. Under YJIT it is 3 for more than two
> elements, because YJIT and ZJIT don't yet take #19537's `opt_new` fast path. Those two extra objects go away with the
> pending YJIT/ZJIT `Hash.new(capacity:)` work.
>
> byroot's heap-report harness, one iteration, Rails main against this change:
>
> | | railsbench | shipit | lobsters |
> | --- | ---: | ---: | ---: |
> | `index_with` spills, main / this / #59108 | 0 / 0 / 2003 | 0 / 0 / 163 | 0 / 0 / 212 |
> | objects, 4.1 interpreter | −11,993 | −60,651 | −5,408 |
> | objects, 4.1 YJIT | −8,069 | −53,068 | −7,554 |
> | Ruby 4.0.7 | unchanged | unchanged | unchanged |
>
> Wall time (ruby-bench, interleaved with an A/A control, 3–5 rounds): a tie within noise on lobsters and shipit, on
> 4.1 and 4.0, interpreter and YJIT. Across nine census apps on 4.1 it removes every `index_with` pair array without
> adding spills.
>
> ### Checklist
>
> * [x] This Pull Request is related to one change. Unrelated changes should be opened in separate PRs.
> * [x] Commit message has a detailed description of what changed and why.
> * [x] Tests are added or updated if you fix a bug or add a feature.
> * [ ] CHANGELOG files are updated for the changed libraries if there is a behavior change or additional feature.

## Rejected variants

| Variant | Why |
| --- | --- |
| `each`: #59108's `{}` + `each` for every enumerable | Reverted upstream for 4.1 spills, reproduced here: 2003 / 163 / 212 spills, and 13–141 per census app. On 4.0 it is the best variant (0 spills, all pair Arrays gone), but reviving it there would mean a second Ruby-version path for the same method. Recorded as a possible follow-up, not in this change. |
| `capa`: `Hash.new(capacity:)` on every Ruby | Spills every 1–8 element hash on 4.0.7 (256–544 B against 160 B), and 2003 / 163 / 212 in the heap harness. |
| `gate`: `capa` on 4.1 only | Exact in the interpreter, but under YJIT 0–2 element calls cost 3 objects instead of 1–3. That covers 12–43 % of Array calls in the census apps. `gate2` is identical above 2 elements and better below. |
| Generic `respond_to?(:size)` fast path (the task's option a, for Array/Set/Hash) | Would call `Relation#size` (a `COUNT` query on an unloaded relation) and `Enumerator#size`, and would tie Hash receivers to whichever semantics main has (see the `Hash#index_with` regression below). |
| Sets on the fast path | Would help Sets on 4.1, which spill even on main because `Enumerable#to_h` does not presize. Rails's own callers pass Arrays; the Set gap is a Ruby lead (below). |
| A per-call YJIT check | `RubyVM::YJIT.enabled?` can change at runtime, and a JIT branch in Active Support is the wrong layer. The JIT gap belongs in ruby/ruby. |

## Leads for ruby/ruby (not Rails PRs)

* **YJIT/ZJIT: `opt_new` has no `Hash` `capacity:` branch.** Interpreted, `Hash.new(capacity: n)` allocates 1 object
  after #19537. Under `--yjit` or `--zjit` it allocates 3: the result plus two transient Hashes, at any n. The
  YJIT and ZJIT parts of #19537 only regenerated bindings. **Already in progress:** U1's `yjit-hash-new` and
  `zjit-hash-new` branches on thomasklemm/ruby, stacked on ruby/ruby#19660 and the Hash-subclass fix. Once they land,
  the candidate costs 1 object under YJIT too, and its `> 2` split stays harmless.
* **`Enumerable#to_h` does not presize from `size`.** `Set#index_with` (and any `Enumerable#to_h` with a block on a
  sized collection) spills at 3 entries on 4.1: 160 B against 80 B presized.
* **`Enumerable#index_by`** (`{}` + `each`, Rails) spills on 4.1 the same way #59108 did: 8 / 2 spills on lobsters /
  shipit (enumerable.rb:60). A Rails follow-up could presize it the same way. It is not part of this change, which is
  limited to `index_with`.

## Other findings

* **`Hash#index_with` regression on main, fixed on its own branch.** [`2b88dc1995`](https://github.com/rails/rails/commit/2b88dc19959ca7d929f0e8325b7946acc484c3f7)
  (byroot, 2026-09-04, "Instantiate record with IndexedRows when joining", part of #58663, a performance PR) switched
  `Enumerable#index_with` to `to_h { |elem| ... }`. Its message and PR say nothing about non-Array receivers, and no
  issue or PR covers them, so the change looks unintended.
  * `Hash#to_h` yields `(key, value)` as two arguments, so a hash now indexes its keys, and a two-parameter block gets
    `nil` as the value: `{a: 1}.index_with { |k, v| "#{k}#{v}" }` gives `{a: "a"}` on main and
    `{[:a, 1] => "a1"}` on 8.1. HashWithIndifferentAccess is affected the same way.
  * `Struct#to_h` yields members, so a struct indexes `:x, :y` instead of its values.
  * Every Rails caller passes an Array, so Rails itself is unaffected.
  * The fix is [`thomasklemm/hash-index-with-pairs`](https://github.com/thomasklemm/rails/tree/thomasklemm/hash-index-with-pairs),
    [`6235de2`](https://github.com/thomasklemm/rails/commit/6235de2236077aafd67d4991cab172715054ebd0), on canonical main
    `5810776eec`. `Enumerable#index_with` goes back to 8.1's `each` loop, and a new `Array#index_with` keeps `to_h`,
    so arrays stay byte-identical to main and keep #59203's no-spill result. For Sets and other enumerables the
    loop is no worse than `Enumerable#to_h`, which does not presize either and adds the pair Arrays (Set, 3 elements,
    4.1: 1 object against 5, same 160 B spilled table).
  * The regression test covers the block with one and with two parameters, the default form, HashWithIndifferentAccess,
    and Struct (`each`), with `each_pair` as the contrast. It fails on main and passes on the branch.
  * AS suite with `RAILS_STRICT_WARNINGS=1`: 4.0.7 6869 runs, 0 failures, 0 errors; 4.1.0dev only the same
    pre-existing Ractor error. RuboCop is clean.
  * **Overlap:** both this branch and `index-with-capacity` add `Array#index_with` to the same spot in
    `enumerable.rb`. Whichever lands second needs a small rebase: the capacity branch's gated method then replaces the
    `to_h` body on Ruby 4.1.
* **Rails main on Ruby master:** the AS Ractor error above, Herb rejecting templates in two ruby-bench apps, and
  shipit-engine reopening the now-frozen `model_name` are all independent of `index_with`.
