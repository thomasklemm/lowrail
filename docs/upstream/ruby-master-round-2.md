# Ruby master round 2: regressions against 4.0.9 and the ZJIT/YJIT gap (2026-11-14)

Round 2 of the [Ruby 4.1 regression watch](ruby-4.1-regression-watch.md) (round 1: 2026-11-05) and a refresh of the
[ZJIT/YJIT gap](zjit-yjit-gap.md) (bet Z13, 2026-11-03), both on one ruby/ruby master build,
[`b7e8fad022`](https://github.com/ruby/ruby/commit/b7e8fad022) (2026-11-14), with Rails main
[`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b). Ruby 4.1 ships on
2026-12-25. Nothing was opened, posted or filed upstream; Thomas decides per finding. The only push outside Lowrail
is the rebased GC branch on Thomas's fork ([GC re-verification](#5-gc-pool-budget-re-verified-pr-queue-item-gc)).

**Short answer.** Master still allocates fewer objects (−2.2% median) and far fewer bytes (−14%) than 4.0.9 in every
census workload, with no allocation regression. The regressions are in instructions: **small-Hash operations cost
more**. A symbol lookup in a three-key Hash (`opts[:key]`) runs +46 instructions and about twice the wall time.
Each pair inserted into a small Hash costs about +55 instructions. Copying a 3–8-key Hash that was grown by insertion
costs +32% to +113%. On railsbench the Hash functions run +7.5% (about +50 M instructions per iteration, interpreter and YJIT alike), but other master gains offset that, and a whole iteration without GC is within ±0.4% of 4.0.9. Round 1's kwsplat Hash regression is fixed. Its `nofree` major GCs and the 320 B slot
gap are not, though the open draft ruby/ruby#17251 now removes the majors as well as our held fix does. ZJIT still runs 3.4% more instructions than YJIT on railsbench, the same as on 11-03 once GC is excluded. rails/rails#59141 adds a new ZJIT fallback bucket
in the shared attribute readers, which is small and outweighed by what #59141 saves (railsbench −1.1% ZJIT, −1.5% YJIT).

## Findings, ranked

Ranked by reach × magnitude. "A/A" is the spread between two identical runs of the same build. Ir is Callgrind
instructions with the pinned Valgrind ([method](#method-and-pins)).

| # | Finding | Modes | Reach | Magnitude (controls) | Bisected to | Existing report | Proposed next step |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Small-Hash lookups and inserts cost more** (`h[:k]` on ≤ 8 keys, literals, `[]=`) | interp, YJIT, ZJIT (same C functions) | every app and request; railsbench Hash functions **+50.5 M Ir per iteration (interp), +48.9 M (YJIT), +7.5%**, about +0.7% of an iteration | `h[:b]` 288 → 334 Ir (+16%), wall time 2.9 → 6.4 ns; 3-pair literal 1,084 → 1,232 Ir (+14%); 12-key lookup unchanged (control); whole iteration without GC +0.35% interp, −0.16% YJIT (offset by other gains) | [`7da70f1773`](https://github.com/ruby/ruby/commit/7da70f1773) (ruby/ruby#18222, byroot, SWAR `ar_find_entry_hint`) +23 Ir and [`0b2edb5b9a`](https://github.com/ruby/ruby/commit/0b2edb5b9a) (ruby/ruby#18476, Peter Zhu, AR identity hashes) +14 Ir | none found | Show both authors the x86-64 count and the 3-line repro; try keeping the identity check and the SWAR search off the plain lookup path, then measure on railsbench. Highest reach of anything here. **Built 2026-11-14:** [ruby-small-hash-lookup](ruby-small-hash-lookup.md), queue item F1 |
| 2 | **`nofree` major GCs in sparse large-slot heaps** (round 1 #2) | interp, YJIT | 35 census workloads; shipit | YJIT census: majors **−82.5%**, GC time **−27.4%** with the fix (two A/A rounds); shipit YJIT 24–26 → 5–9 majors, −29% GC time; bigslot 1–2 / 24–31 / 3 (4.0.9 / master / fix). Cost: +1.2–1.8 MB RSS per workload, large-slot sweep step p99 ≈ 3× | [`16da5f23c2`](https://github.com/ruby/ruby/commit/16da5f23c2) (ruby/ruby#16632), round 1 | ruby/ruby#17251 (eightbitraptor, open draft): **its current head `41c689571a` fixes it too**. Census majors −95%, shipit 4–5 majors, bigslot 1–4 at 4–5 pages; app RSS cost the same as ours, large-slot sweep step p99 unchanged from master (0.62–0.63 ms). Numbers for master and #17251 [added to our 11-05 comment on #17251](https://github.com/ruby/ruby/pull/17251#issuecomment-6652543942) 2026-11-14 | **Decided (Thomas, 2026-11-14):** our fix is not opened; [item GC](../../bench/upstream/pr-queue/items/GC.md) (`7bc813e025`) stays held as the fallback, reopened only if #17251 stalls or is closed |
| 3 | **Copying a 3–8-key Hash grown by insertion** (`h.dup`, `m(**h)`) | interp, YJIT, ZJIT | apps that `dup` or splat small option Hashes built with `[]=` | `m(**h)` +47 / +75 / +113% at 3 / 5 / 8 keys, `h.dup` +32 / +51 / +82%; A/A ≤ 0.2% below 8 keys, ≤ 1.9% above; very large inputs: `h.dup` of 100k +14%, `m(**h, a: v)` +6.5% | ruby/ruby#18345 (byroot, deliberate: insertion-grown Hashes become st_tables at the 3rd key) | byroot's #18345 notes the st_table churn; KW2 (ours, parked) covers the merge side | Low priority: ask byroot whether `rb_hash_dup` of a ≤ 8-entry st_table should make an AR table |
| 4 | **rails/rails#59141 shared readers pass `&:value!` generically** (Rails, not Ruby; corrected in [zjit-leads](zjit-leads.md#correction-railsrails59141s-site-is-value-not-block)) | ZJIT, YJIT | every AR attribute read on Rails main; largest on Lobsters | ZJIT: +208 `send_block_arg_not_nil` and +51 `send_polymorphic_fallback` per Lobsters request; railsbench +22.5k per iteration; YJIT dynamic sends +5.4% (railsbench), +4.1% (Lobsters). Price on railsbench: **ZJIT −1.1%, YJIT −1.5%, a net win** (all gates pass) | `1f32b09101` (merge of #59141) against its parent `c48c154e3f` | none | Section 6 |
| 5 | **No 320 B slot** (round 1 #3) | all | every query: `QueryIntent` (31 ivars) 320 → 512 B | census `database_statements` site +2,444 B per workload | [`c9b7088364`](https://github.com/ruby/ruby/commit/c9b7088364) (ruby/ruby#16282, deliberate) | none | Unchanged: no Ruby fix proposed; Rails could keep `QueryIntent` ≤ 30 ivars |
| 6 | **ZJIT copies a caller-built splat into a rest parameter** (round 1 #4) | ZJIT | `URI.parse`; top ZJIT-only allocation site in the census | +1 Array per call | predates #18267 (not a 4.0 → 4.1 regression) | Shopify/ruby#1095 (ours, open, unassigned) | Unchanged |
| — | Round 1 #1, kwsplat second Hash | — | — | **fixed**: 4.0.9's counts in every shape | — | — | Drop `thomasklemm/kwsplat-fit-merge` |
| — | ZJIT − YJIT gap | ZJIT | ruby-bench | railsbench +3.39% (A/A 0.06%), unchanged since 11-03 without GC | — | see [buckets](#zjit--yjit-buckets) | Free buckets: leads 3, 7, megamorphic growth, 4 |

No allocation regression: no census workload allocates more objects on master beyond the A/A spread, and 30
(interpreter) and 33 (YJIT) of 35 allocate fewer (section 4).

## 1. Small-Hash lookups and inserts cost more

```ruby
h = {a: 1, b: 2, c: 3}
h[:b]                  # 4.0.9 288 Ir, master 334 Ir per loop iteration (+46); wall time per lookup 2.9 → 6.4 ns
x = {a: v, b: v, c: v} # 4.0.9 1,084 Ir, master 1,232 Ir with GC (+148, +14%); wall time 58.7 → 67.0 ns
x = {a: v}             # 704 → 741 Ir with GC (+37, +5%)
```

Whole-process Callgrind with the pinned tool, (Ir at 1M or 200k iterations − Ir at 0) / iterations, so the loop
itself is included and identical on both sides ([`hashlit.sh`](../../fixtures/corpus/ruby-master-round-2/hashlit.sh)). Wall time: interpreter, one pinned core, median of 7 interleaved
runs minus an empty loop, three alternating process pairs; 4.0.9 2.6 / 3.3 / 2.9 ns, master 6.5 / 6.2 / 6.5 ns per
lookup. A 12-key Hash (st_table) lookup is unchanged (379 → 375 Ir), and `{}` is cheaper with GC (476 → 439).

**Where the instructions go** (function self Ir per `h[:b]`, 4.0.9 → master): 4.0.9 inlines the whole AR-table search
into `rb_hash_aref` (87). On master `rb_hash_aref` (41) calls an out-of-line `ar_find_entry_hint` (51), an
out-of-line `any_hash` (26), and `ar_equal` (4 → 13), which now takes the Hash and checks `RHASH_IDENTHASH_P` before
calling `rb_any_cmp`. Inserting literal pairs goes the same way: `rb_hash_bulk_insert` → `ar_insert_direct` with
`ar_find_entry_hint` and `any_hash` per pair (+57 Ir per pair).

**Bisect** (miniruby, pinned Valgrind, Ir per `h[:b]` iteration; endpoints and the candidates, not a full bisect run):

| commit | Ir |
| --- | ---: |
| `d375bcc965` (4.0 branch point) | 280 |
| `74299e5a87`, parent of the next | 291 |
| [`7da70f1773`](https://github.com/ruby/ruby/commit/7da70f1773) "hash.c: speedup ar_find_entry_hint with SWAR" (byroot, ruby/ruby#18222, 2026-08-06) | **314** (+23) |
| `68abb349e5`, parent of the next | 315 |
| [`0b2edb5b9a`](https://github.com/ruby/ruby/commit/0b2edb5b9a) "Implement support for AR table backed identity hashes" (Peter Zhu, ruby/ruby#18476, 2026-08-24) | **329** (+14) |
| master `b7e8fad022` | 329 |

For inserts, an earlier `git bisect run` on the per-pair cost ((3 pairs − 1 pair) / 2) found the same two commits:
`7da70f1773` 354 → 418 and `0b2edb5b9a` +52 (stock Valgrind; those runs kept no logs, so only the located commits
count, not their exact numbers). The single-pair literal bisected to the bump-pointer allocator `4f259bc25d` only with
`GC.disable`, where heap growth dominates; with GC on, a one-pair literal is only +37 Ir, so that bisect is not used.

**Reach.** Every mode: YJIT and ZJIT call the same `rb_hash_aref` / `rb_hash_bulk_insert` for Hash `[]` and literals.
Every app: Rails reads and builds options, `params`, attribute and keyword Hashes of up to 8 keys on every request.
Measured on ruby-bench railsbench (interpreter, Callgrind, same fixed-heap window as the gap runs), the Hash
functions (`rb_hash_*`, `ar_*`, `st_*`, `any_hash`, …) run **+50.5 M Ir per iteration on master (673.9 → 724.4 M,
+7.5%)**, about +0.7% of the iteration without GC. The biggest moves are the now out-of-line `any_hash` (+74.8) and
`ar_find_entry_hint` (+45.8) against the inlined `ar_update`/`tbl_update`/`rb_any_hash` (−118), and `rb_hash_aset`
+46.2. Other master changes offset it: the whole iteration without GC and page zeroing is +24.8 M (+0.35%).

**Existing report.** None found: no ruby/ruby issue or PR mentions an x86 cost of #18222 or #18476 (searched
`ar_find_entry_hint`, identity hash, hash lookup slower); bugs.ruby-lang.org returns 403 from the orb, and a web
search found only byroot's posts. #18222 was measured on arm64 (`ar-hit-1` 13.2 → 14.0 M i/s). Related merged work:
ruby/ruby#19809 (jhawthorn, clamp the AR bound) does not change the count.

**Fix built (2026-11-14):** [ruby-small-hash-lookup](ruby-small-hash-lookup.md): a same-object fast path in `ar_find_entry_hint`
keeps SWAR and the identity flag and takes `h[:b]` from 333 to 294 Ir.

**Can the broken piece go?** Partly. The identity-hash check (`RHASH_IDENTHASH_P` in `ar_equal` / `ar_do_hash`) is
per call; an identity Hash could take its own lookup function so the common path keeps 4.0's inlined search. Whether
the SWAR search should stay out of line on x86 is byroot's call; his PR notes the happy path was tuned until
`hit_first` was "on par" on arm64, and the counts here say it is not on x86-64 at index 1.

## 2. Copying a 3–8-key Hash grown by insertion costs +32% to +113%

Since ruby/ruby#18345 (byroot, deliberate), a Hash starts in the smallest slot that fits, so `h = {}; h[:a] = …`
becomes an st_table at the third key (on 4.0.9 it stayed an AR table up to eight). Operations that copy such a
Hash pay for the st_table: `h.dup` and `m(**h)` copied an 8-key AR table with one `memcpy` on 4.0.9.

Keyword-splat sweep ([`kw_sweep.rb`](../../fixtures/corpus/ruby-master-round-2/kw_sweep.rb) under Callgrind, GC excluded, interpreter,
two runs per Ruby; Ir per call, A/A within 0.2% below size 8 and 1.9% above):

| call shape | size 0–1 | 2 | 3 | 5 | 8 | 9 | 16 | 64 | 1,000 | 100,000 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| control: loop + lambda | +4.4% | +4.4% | +4.4% | +4.4% | +4.4% | +4.4% | +4.4% | +4.4% | +4.4% | +4.4% |
| control: `{a: v}` | +15% | +15% | +15% | +15% | +15% | +15% | +15% | +15% | +11% | +6% |
| `h.dup` | +5–6% | +6% | **+32%** | **+51%** | **+82%** | +5% | +5% | −10% | +12% | +14% |
| `m(**h)` | +10–11% | +11% | **+47%** | **+75%** | **+113%** | +9% | +9% | −13% | +12% | +10% |
| `{**h}` | +12–14% | +12% | **+33%** | **+49%** | +29% | +21% | +13% | +4% | +3% | +2% |
| `m(a: v, **h)` | +13% | **+36%** | **+32%** | **+41%** | +16% | +20% | +11% | +3% | +3% | +2% |
| `m(**h, a: v)` | +13–15% | **+31%** | **+30%** | **+45%** | +17% | +20% | +11% | +5% | +7% | +7% |
| `m(a: v, b: v, c: v, **h)` | +15–46% | **+66%** | **+55%** | **+41%** | +18% | +21% | +13% | +5% | +3% | +2% |
| zsuper with keywords | +5% | | | | | | | | | |

`h` is built by insertion (`(0...size).to_h`). The bold cells are the st_table conversions; the merge rows are
[KW2](contributions.md) (parked 2026-11-10, a design question for Kevin Newton). **New in round 2** are the copy
rows: `h.dup` and `m(**h)` of a 3–8-key insertion-grown Hash. Very large Hashes copy +10–14% slower too (`h.dup` of
100k entries; a whole-process probe puts it at +6.5%, mostly more bytes through `memcpy`), but Rails rarely copies
Hashes that large.

**Reach.** Every mode and app that copies small option or attribute Hashes built by `[]=`, e.g. `options.dup` then
`options[:k] = v` (byroot's own example in #18345), or `m(**opts)` with a built-up `opts`. Allocation counts do not
show it: the census objects and bytes go down.

**Existing report.** byroot's #18345 notes "more malloc/free churn and more work during sweeping" from the extra
st_tables; KW2 asks Kevin about the merge side. Nothing on the copy side.

**Can the broken piece go?** A copy knows its final size, so `rb_hash_dup` of a ≤ 8-entry st_table could produce a
right-sized AR table instead of copying the st_table. That is an idea, not a measured patch.

## 3. Round 1's findings on master

| round 1 # | finding | status on `b7e8fad022` |
| ---: | --- | --- |
| 1 | `m(a: v, **h)` and zsuper allocate a second Hash | **Fixed.** `kwsplat_shapes.rb` gives 4.0.9's counts in every shape. Kevin Newton's hash-splat compilation changes (`deaea318b1`, `4a3a75e616`, 2026-11-09) landed in that code; the fixing commit was not bisected. Our `thomasklemm/kwsplat-fit-merge` is obsolete. |
| 2 | Sparse large-slot heaps force `nofree` major GCs | **Still there.** See [GC re-verification](#5-gc-pool-budget-re-verified-pr-queue-item-gc). |
| 3 | No 320 B slot (31–38 ivars take 512 B) | **Still there.** `QueryIntent` (31 ivars set on a find) is 320 B on 4.0.9 and 512 B on master; the census `abstract/database_statements` site is +2,444 B per workload (4,074 → 6,518 B). Fizzy `Card` shrinks 320 → 256 B. |
| 4 | ZJIT `f(*a, x)` into a rest parameter allocates one more Array | **Still there.** uri `rfc3986_parser.rb:135` is the top ZJIT-only allocation site in the census (+0.6 objects per workload on average against master YJIT). |

## 4. Allocation census: no regression

Blog, Fizzy and Lobsters (`script/census --corpus census5`, 35 workloads), Rails main `50c54eed06`, Ruby 4.0.9
(mise) against master, two full runs per Ruby and mode
([`ruby_41_watch_compare.rb`](../../bench/upstream/ruby_41_watch_compare.rb); A/A median +0.0):

| | objects, median per workload | workloads more / fewer beyond A/A | traced bytes, mean |
| --- | ---: | ---: | ---: |
| interpreter, master − 4.0.9 | −149 (−2.24%) | 0 / 30 | −14.2% |
| YJIT, master − 4.0.9 | −121 (−2.09%) | 0 / 33 | −14.0% |
| ZJIT − YJIT on master | −26 (−0.63%) | 0 / 25 | −0.4% |

The one byte increase is Fizzy's `MagicLinkMailer` (+3.6%): mail's ISEQ and Regexp `memsize_of` accounting, not more
objects. The largest moved lines are renames (`<internal:string>:92` replaces `output_safety.rb`'s SafeBuffer line,
`time.rb:387` → `:390`, `timev` and `marshal` line moves), each matched by an equal decrease.

## 5. GC pool budget, re-verified (pr-queue item GC)

[Item GC](../../bench/upstream/pr-queue/items/GC.md) restores the slot-count pool budget for incremental sweeping that
ruby/ruby#16632 changed (round 1 finding 2).

**Master still has the problem.** Nothing that touches the pool budget has landed since round 1. The GC commits
between the two masters are the page-pool bookkeeping (`33b6c8872a`, `a8ad8b9a60`, `a5ea2cd00f`, Luke Gruber),
mimalloc (`a04c1e136f`), wbcheck and MMTk. ruby/ruby#17251 ("Trigger nofree majors on a per-heap basis",
eightbitraptor) is still an open draft; it was force-pushed on 2026-11-13 (head `41c689571a`), and our 2026-11-05
comment has no reply. ruby/ruby#19170 (return empty pages to the OS on majors, same author) is an open draft too.

**Rebase.** `4b02fa55cb` cherry-picks onto `b7e8fad022` without conflicts. The rebased commit, with the commit
message's numbers refreshed to this round, is [`7bc813e025`](https://github.com/thomasklemm/ruby/commit/7bc813e0255deae62a0bc71e9c59790b705ab413),
pushed to `thomasklemm/gc-pool-budget` on the fork with a lease on `4b02fa55cb`. No PR.

**bigslot.rb** (`RING=200 BIG=70 N=40000`, the script in GC.md; `nofree` majors and 640 B heap pages at the end):

| build | majors | pages |
| --- | --- | --- |
| 4.0.9 (local build) | 2, 1, 2 (earlier today 2, 1, 1) | 9, 99, 9 |
| master `b7e8fad022` | 31, 24, 31 (earlier today 26, 26, 28) | 4, 7, 4 |
| master + fix | 3, 3, 3 (earlier today 3, 3, 3) | 32, 30, 30 |
| master + ruby/ruby#17251 at `41c689571a` | 1, 4, 1, 4, 1 | 5, 4, 5, 4, 5 |

For the #17251 comment, the three builds ran three more times in alternation (majors): master 28, 28, 28; #17251 1, 1, 1;
fix 3, 3, 3 ([`bigslot-comment.log`](data/ruby-master-round-2/receipts.tar.gz)).

Variants, one run each (majors / pages): ring 300: master 10 / 9, fix 5 / 41, #17251 6 / 7. 90-element Arrays (768 B
heap): master 41 / 5, fix 5 / 7, #17251 3 / 4. YJIT, ring 200: master 27 / 6, fix 3 / 35, #17251 1 / 5. **The
current #17251 head removes the extra majors as well as our fix does, without the extra pages.** On 11-05 (round 1,
an older head rebased) it only reduced them (18, 25 majors).

**ruby-bench shipit** (`HARNESS=gcstep`, 15 warmup and 40 measured iterations, one build with the measurement-only
[`gcstep.patch`](../../fixtures/corpus/ruby-41-watch/gcstep) where `RUBY_GC_POOL_MODE=bytes` is master and `slots` is
the fix; sums over the 40 iterations):

| mode | build | round | majors | minors | GC ms | peak RSS MB | sweep pause p99 / max ms | large-slot step p99 / max ms |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| interp | master | a / b / c / d / e | 25 / 24 / **7** / 22 / 23 | 82 / 87 / 207 / 90 / 89 | 3,605 / 3,537 / 2,932 / 3,716 / 3,671 | 146–148 | 0.65–0.77 – 6.2 | 0.03–0.05 – 0.1 |
| interp | fix | a / b / c / d / e | 5 / 5 / **14** / 5 / 5 | 183 / 171 / 135 / 183 / 177 | 2,731 / 2,844 / 3,120 / 2,884 / 2,800 | 156–162 | 0.77–0.96 – 2.8 | 0.06–0.09 – 0.1 |
| YJIT | master | a / b / c | 24 / 25 / 26 | 84 / 91 / 90 | 3,972 / 4,325 / 4,413 | 195 / 195 / 195 | 0.65 / 0.69 / 0.71 – 1.7 | 0.04–0.05 – 0.1 |
| YJIT | fix | a / b / c | 5 / 9 / 5 | 193 / 165 / 174 | 2,948 / 3,121 / 2,830 | 206 / 209 / 210 | 0.77 / 0.77 / 0.79 – 1.5 | 0.06–0.07 – 0.1 |
| interp | #17251 | a / b | 4 / 4 | 134 / 124 | 2,492 / 2,365 | 166 / 167 | – | – |
| YJIT | #17251 | a / b | 4 / 5 | 126 / 133 | 2,727 / 2,738 | 212 / 211 | – | – |

The #17251 rows are its own build (`~/w/r17251`, no gcstep patch, so no step times), run after the others with the orb otherwise idle. Rounds a and b ran while other work was on the orb, so their GC ms are less clean than round c's; the counts are
unaffected. Under YJIT the fix is consistent: majors 24–26 → 5–9, GC time −29% (4,237 → 2,966 ms mean), peak RSS
+11 to +15 MB. Under the interpreter, round c inverted (master 7 majors, fix 14), so two more rounds ran: d and e agree with a and b
(22, 23 → 5, 5). Over all five, the median is 23 → 5 majors and 3,605 → 2,844 ms GC time (−21%), peak RSS +10 to +14
MB. Round d's master cell overlapped a few bigslot runs, which can move its GC ms but not its counts.

**Census apps** (Blog, Fizzy, Lobsters on Rails main, YJIT, 35 workloads, one 500-operation GC window each with
`CENSUS_GC_MAJOR_BY`; same gcstep build; two rounds, master and fix alternating per app;
[`gc_census_report.rb`](../../fixtures/corpus/ruby-master-round-2/gc_census_report.rb), sums over the 35 windows):

| build | round | majors | minors | GC ms | RSS growth MB | sweep pause p99 / max ms | large-slot step p99 / max ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| master | a / b | 25 / 15 | 193 / 195 | 7,703 / 6,572 | +23.5 / +5.6 | 3.06 / 2.20 – 19.8 | 0.58 / 0.59 – 1.9 |
| fix | a / b | 3 / 4 | 202 / 202 | 5,157 / 5,203 | +66.8 / +68.9 | 2.15 / 2.34 – 19.9 | 1.67 / 1.74 – 1.8 |

[`ruby_41_watch_gc.rb`](../../bench/upstream/ruby_41_watch_gc.rb) per 1,000 operations: majors −82.5%, all GCs −4.0%,
GC time **−27.4%**; Lobsters' home page is the one workload whose collections move beyond both A/A spreads (−18 per
1k ops). Master's own A/A spread is wide (25 vs 15 majors, 23.5 vs 5.6 MB), the fix's is narrow, and the effect is
far beyond both.

**Do the body's claims still hold?** Mostly yes; GC.md's body now carries these numbers, except the last claim:

* *Majors on the script, 4.0 vs master vs fix* (2 / 27–28 / 3): **holds** (1–2 / 24–31 / 3 on 4.0.9 and
  `b7e8fad022`).
* *Heap cost in the script* (24–29 pages instead of 5–6): **holds in direction**, now 30–32 pages instead of 4–7.
* *97 workloads, majors 86 → 13 (interp) and 98 → 26 (YJIT), GC time −15% / −23%*: **not re-measured at that
  scale.** The three-app YJIT census gives majors −82.5% and GC time −27.4%, consistent with it.
* *RSS +1.7 to +3.3 MB per workload*: **holds roughly**, +1.2 to +1.8 MB per workload here.
* *shipit 25 → 6 (interp) and 27 → 5 (YJIT), −20% / −31% GC time, peak RSS +12–17 MB*: **holds for YJIT** (24–26 →
  5–9, −29%, +11–15 MB). **Interpreter is mixed**: two rounds hold (25, 24 → 5, 5, about −21% GC time) and one
  inverted (7 → 14); rounds d and e hold again (22, 23 → 5, 5).
* *Large-slot sweep step p99 +19% (interp) / +53% (YJIT), up to 0.3 → 1.7 ms in one app*: **the cost is larger
  now**: about 3× at p99 in the census (0.58 → 1.7 ms) and +40–80% on shipit. The sweep pause an allocation waits
  for did not grow in the census (p99 3.06 / 2.20 → 2.15 / 2.34 ms, max about 19–20 ms in both).
* *ruby/ruby#17251 reduces the majors but does not remove them*: **no longer holds.** The current head
  (`41c689571a`, force-pushed 2026-11-13) removes them: bigslot 1–4 majors (master 24–31, fix 3); shipit 4 / 4
  (interp) and 4 / 5 (YJIT) majors; census 1 / 1 majors over 35 workloads (master 25 / 15, fix 3 / 4).
  It pays about the same memory as our fix in the apps (census RSS growth +68.4 / +69.1 MB against the fix's
  +66.8 / +68.9; shipit peak RSS 166–167 MB interp and 211–212 MB YJIT, against the fix's 156–162 and 206–210).
  Only in the bigslot script does it keep the 640 B heap small (4–5 pages, fix 30–32).

**#17251 against our fix** (same census cells). `#17251` is `b7e8fad022` + `41c689571a` cherry-picked, without the
gcstep patch; `#17251 + gcstep` is the same build with [`gcstep.patch`](../../fixtures/corpus/ruby-41-watch/gcstep)
at its default pool mode, so #17251's own budget, run like master and fix ([`gc_17251_steps.sh`](../../fixtures/corpus/ruby-master-round-2/gc_17251_steps.sh)):

| build | round | majors | minors | GC ms | RSS growth MB | sweep pause p99 / max ms | large-slot step p99 / max ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| master | a / b | 25 / 15 | 193 / 195 | 7,703 / 6,572 | +23.5 / +5.6 | 3.06 / 2.20 – 19.8 | 0.58 / 0.59 – 1.9 |
| fix | a / b | 3 / 4 | 202 / 202 | 5,157 / 5,203 | +66.8 / +68.9 | 2.15 / 2.34 – 19.9 | 1.67 / 1.74 – 1.8 |
| #17251 | a / b | 1 / 1 | 218 / 217 | 4,921 / 4,962 | +68.4 / +69.1 | – | – |
| #17251 + gcstep | a / b | 1 / 1 | 216 / 205 | 5,085 / 5,046 | +71.9 / +72.7 | 1.98 / 3.53 – 22.1 | 0.63 / 0.62 – 2.0 |

Per 1,000 operations against master: majors −95.0%, all GCs +2.1%, GC time −30.8% (`#17251`), −95.0%, −1.2%,
−29.0% (`#17251 + gcstep`); the fix: −82.5%, −4.0%, −27.4%. **#17251 does not lengthen large-slot sweep steps**
(p99 0.62–0.63 ms, master 0.58–0.59, fix 1.67–1.74). On shipit with gcstep, #17251 runs 4 / 4 majors (interp, GC
2,891 / 2,539 ms) and 4 / 4 (YJIT, 2,707 / 2,730 ms), with large-slot step p99 0.02–0.05 ms like master's.
**Can the broken piece go?** Our fix and #17251 fix the same majors at the same memory cost in the apps, and #17251
also fixes the bigslot shape without extra pages and is written by the GC's maintainer. If #17251 lands before 4.1,
item GC can go. If it stalls as a draft, item GC is the smaller, already-measured fallback; keep it held.
**Decision (Thomas, 2026-11-14):** our fix is not opened; #17251 is the route. Item GC is held as a fallback, reopened
only if #17251 stalls or is closed. The master and #17251 columns of the table above, with fresh bigslot runs, were [added to our 11-05 comment on #17251](https://github.com/ruby/ruby/pull/17251#issuecomment-6652543942); a separate comment that also showed our branch was deleted the same day (Thomas).

## 6. rails/rails#59141: shared attribute readers under YJIT and ZJIT

[rails/rails#59141](https://github.com/rails/rails/pull/59141) (tenderlove, merged 2026-11-11 as `1f32b09101`) makes
every model share one reader ISEQ per attribute slot: `_read_attribute_N` → `_read_attribute_at!(N)` →
`@attributes.fetch_value_at!(N)`. Compared here: Rails main `50c54eed06` against #59141's parent `c48c154e3f`, same
Ruby master.

**Counters on the census apps** (per operation, mean over the app's workloads; ZJIT `--zjit-stats-iseq` on master +
`1c64fd8d6a`, YJIT `--yjit-stats=quiet`; `CENSUS_WARMUP=200`, 0 out-of-memory):

| ISEQ (ZJIT) | counter | Lobsters parent → main | Fizzy parent → main |
| --- | --- | ---: | ---: |
| `_read_attribute_at!` (the `@attributes` read) | `getivar_fallback_no_side_exits` | 0 → **395** | 0 → 8.6 |
| `_read_attribute!` | `getivar_fallback_no_side_exits` | 488 → 117 | 40.7 → 28.8 |
| `fetch_value_at!` | `send_fallback_send_block_arg_not_nil` | 0 → **208** | 0 → 5.2 |
| `_read_attribute_N` | `send_fallback_send_polymorphic_fallback` | 0 → **51** | 0 → 2.6 |
| `_read_attribute_N` | `exit_guard_type_failure` | 0 → 15 | 0 → 0.1 |
| whole app | dynamic sends | 15,162 → 15,346 (+1.2%) | 17,681 → 17,430 (−1.4%) |
| whole app | `getivar_fallback_no_side_exits` | 3,398 → 3,702 (+9%) | 2,970 → 2,622 (−12%) |
| whole app | `send_block_arg_not_nil` | 470 → 771 (+64%) | 740 → 778 (+5%) |
| YJIT, whole app | `num_send_dynamic` | 6,373 → 6,633 (+4.1%) | 9,885 → 9,851 (−0.3%) |
| YJIT, whole app | `num_getivar_megamorphic` | 2,045 → 2,063 (+0.9%) | 1,545 → 1,610 (+4.2%) |

**What this means.** The shared readers are not a new kind of polymorphism: before #59141 every model already read
`@attributes` in the shared `_read_attribute!`. ZJIT compiles `_read_attribute_at!` to a final version and then reads
`@attributes` with `rb_ivar_get` (`no_side_exits`, lead 15) because it sees one shape per model class; on Lobsters
the 395 new fallbacks replace 371 in `_read_attribute!`, net +24. What is new is that each first read now passes a Symbol block argument
(`cast_value(…, &:value!)` in `fetch_value_at!` → `send_block_arg_not_nil`, +208 per Lobsters request; generic in YJIT too,
see [zjit-leads](zjit-leads.md#correction-railsrails59141s-site-is-value-not-block)) and that the slot ISEQ's
call to `_read_attribute_at!` is class-polymorphic (`send_polymorphic_fallback`, lead 3: +51). Fizzy (148 model
files, 70 tables) barely moves and improves overall. YJIT sees a few more megamorphic ivar reads and, on Lobsters,
+4% dynamic sends.

**Price on railsbench** (ruby-bench copies `~/w/rb-main` and `~/w/rb-parent`, same fixed heap and gate as the gap
runs; one Callgrind run per mode and side, all four passing the gate):

| | parent `c48c154e3f` | main `50c54eed06` | main − parent | of which generic dispatch |
| --- | ---: | ---: | ---: | ---: |
| ZJIT, M Ir per iteration | 2,925.4 | 2,893.2 | **−32.1 (−1.1%)** | +3.7 |
| YJIT | 2,807.8 | 2,765.6 | **−42.2 (−1.5%)** | −0.8 (`rb_vm_send` +1.8) |

Counters on railsbench (stats runs, same copies): ZJIT `send_block_arg_not_nil` 92.6k → 115.1k per iteration, all of
it `fetch_value_at!`; YJIT `num_send_dynamic` 358k → 377k (+5.4%). **#59141 is a net win in both JITs**: the
name-keyed Hash lookups it removes (`ar_find_entry_hint`, `rb_hash_aref`, `rb_str_hash`, `any_hash` together −15 M)
outweigh the generic block-forwarding sends it adds. The ruby-bench railsbench app has one model; Lobsters (more
models, where the counters move most) could not be priced because ruby-bench lobsters does not run on Rails main
(below). The first YJIT pair failed the gate on a harness artifact (two `GC.stat` blocks compiled by the harness's
own read after the window; the gate now reads its counters right next to the window) and was rerun once with the
corrected bracketing; the rejected pair is kept.

**Can the broken piece go?** Corrected 2026-11-14 ([zjit-leads](zjit-leads.md#rails-side-option-a-block-literal-in-fetch_value_at)):
the fallback is `cast_value(@ctx.name_at(index), index, &:value!)`, a Symbol block argument that YJIT does not
specialize either. A block literal there removes it in both JITs and is cheaper in all three modes (Active Record
micro: −1.5% interpreter, −9.9% YJIT, −12.8% ZJIT), so the Rails change is the better fix.

**Candidate bucket.** It is a small sub-bucket of existing leads, not a bucket of its own: its cost sits in leads 7 (block
argument), 3 (class-polymorphic send) and 15 (ivar read in a final version), whose owners are listed in the
[bucket table](#zjit--yjit-buckets). A ZJIT fix for lead 7 covers most of it.

**Rails main breaks two corpus apps (not Ruby).** Fizzy's `uuid_primary_keys.rb` recurses on Rails main, and
activerecord-typedstore 1.6.0 raises "has no attribute … to define a reader for" (`read.rb:20`) in Lobsters, after
#59141. The census copies carry local workarounds (Fizzy patch; a Lobsters initializer that is a no-op before #59141).
ruby-bench lobsters on Rails main fails with `RouteGenerator#auth_token` returning nil, so only railsbench was priced.
None of these was reported.

## ZJIT − YJIT buckets

Same harness, scripts and pins as [zjit-yjit-gap](zjit-yjit-gap.md) (ruby-bench `73918b2`, Callgrind run a with
perf maps), plus the JIT-flat gate, the fixed heap and the pinned Valgrind ([method](#method-and-pins)).

**Only railsbench passes the gate in both modes.** ZJIT passed on all three benchmarks; YJIT failed on lobsters and
shipit. On both, YJIT kept compiling blocks through all 8 warm windows (lobsters 86,946 → 87,298, shipit 76,797 →
77,203) and in the measured window (+2 and +24). Lobsters writes votes and comments each iteration, so later iterations take
new paths; on shipit the late blocks were not traced. Per
[bench.md](../bench.md) those two cohorts are **rejected**, not rerun; their totals below are diagnostic only.
Railsbench is the priced number.

| | railsbench | lobsters (diagnostic) | shipit (diagnostic) |
| --- | ---: | ---: | ---: |
| ZJIT, M Ir per iteration | 4,833.6 (A/A run c 4,830.5, −0.06%) | 3,267.1 | 3,738.7 |
| YJIT | 4,675.2 | 3,075.4 (gate failed) | 3,229.7 (gate failed) |
| **ZJIT − YJIT** | **+158.4 (+3.39%)** | +191.8 (+6.2%) | +509.1 (+15.8%) |
| 11-03, GC excluded | +156.9 (+3.40%) | +170.3 (+5.58%) | +542.1 (+17.2%) |
| GCs in the window (ZJIT / YJIT) | 1 / 1 | 0.7 / 0.7 | 0.7 / 0.7 |

With the fixed heap, the measured windows run about one minor GC and no major, so these totals compare with 11-03's
GC-excluded column. **The railsbench gap has not moved in eleven days** (+156.9 → +158.4 M); the lobsters and shipit
diagnostics point the same way. What moved inside it: generic ivar reads fell (+16.3 → +7.9 M on railsbench, after
tekknolagi's ruby/ruby#19443), and JIT code grew (+87.0 → +101.0 M, entry trampoline included).

**Buckets**, ZJIT − YJIT self Ir, M per iteration (run a; [`zjit_yjit_gap_buckets.rb`](../../bench/upstream/zjit_yjit_gap_buckets.rb)):

| bucket | railsbench | lobsters (diag.) | shipit (diag.) | 11-03 railsbench |
| --- | ---: | ---: | ---: | ---: |
| method dispatch (generic send path) | +93.6 (59%) | +99.3 (52%) | +329.3 (65%) | +87.4 |
| JIT code (incl. entry trampoline 29.5 M on railsbench) | +101.0 (64%) | +70.3 (37%) | +139.8 (27%) | +87.0 |
| block and proc invocation (generic) | +47.1 (30%) | +19.0 (10%) | +38.7 (8%) | +46.4 |
| side exits and frame materialization | +13.6 (9%) | +4.5 (2%) | +10.6 (2%) | +14.7 |
| ivar and attr access (generic) | +7.9 (5%) | +21.3 (11%) | +60.3 (12%) | +16.3 |
| GC | −0.2 | +9.5 | +1.5 | +27.0 (not comparable: 10.7 GCs per window then) |
| other runtime | −11.9 | +5.6 | −18.4 | −7.8 |
| write barriers | −13.0 | −3.5 | −3.8 | −13.0 |
| interpreter | −30.9 | −22.2 | −11.7 | −29.8 |
| allocation | −48.6 | −12.3 | −36.5 | −42.2 |
| **total** | **+158.4** | +191.8 | +509.1 | +183.9 |

**Leads by owner.** Extra generic operations per iteration that ZJIT makes and YJIT does not make at the same ISEQ
([`zjit_yjit_gap_sites.rb`](../../bench/upstream/zjit_yjit_gap_sites.rb) with per-ISEQ counters from the stats-iseq
build), with the estimated M Ir (extra × price per extra call: 278 / 285 / 338 Ir per send or yield, 41 / 78 / 101 Ir
per ivar read). Owners checked on 2026-11-14 against open ruby/ruby ZJIT PRs and Shopify/ruby issues:

| bucket (lead) | railsbench | lobsters | shipit | owner |
| --- | ---: | ---: | ---: | --- |
| class-polymorphic sends, `send_polymorphic_fallback` (3) | 30k (8.5) | 171k (48.8) | 574k (193.8) | **free.** Shopify/ruby#776 open, unassigned (tekknolagi on 11-06: "might be handled now?"; the counts say no, +10–15% since 11-03). Repro and issue draft: [zjit-leads](zjit-leads.md#lead-3-classes-missing-from-a-polymorphic-sends-profile). Top sites: `block in _load_from_sql` (`attribute_types` on the model class), `Type::Value#hash`, `association`, `Core.current_shard`/`current_role` |
| yields in `Array#each`/`#map`, `invokeblock_not_specialized` + `polymorphic_miss` (1) | 265k (73.6) | 95k (27.1) | 187k (63.1) | taken: k0kubun, Shopify/ruby#1093 (open). The mix shifted from `polymorphic_miss` to `not_specialized`, probably through `7041d9e65e` ("End blockparamproxy and block profiling experiments"); not bisected |
| `&block` forwarding, `send_block_arg_not_nil` (7) | 108k (30.0) | 88k (25.1) | 196k (66.1) | **taken** (corrected 2026-11-14): Shopify/ruby#1014 open, unassigned, but Shopify/ruby#1039 row 7 is assigned to k0kubun ([zjit-leads](zjit-leads.md#lead-7-block-arguments-other-than-nil-or-a-proc)); ruby/ruby#18180 (dak2, merged 09-23) covered Proc block args only. Top sites `_read_attribute(name, &block)`, `mon_synchronize`. #59141 adds `cast_value(…, &:value!)` here, which YJIT also leaves generic (section 6) |
| shape-polymorphic ivar reads without a profile, `no_profile_missing_ic` (11) | 195k (7.9) | 193k (15.1) | 478k (48.5) | taken: tekknolagi. ruby/ruby#19443 merged 11-06 (−11% / −35% / −29% fallbacks since 11-03); #18616 open draft for the rest |
| megamorphic sends, `send_megamorphic` (new) | 2k (0.6) | 43k (12.2) | 96k (32.5) | **free, new.** Up +89% on shipit since 11-03 at sites that had none then (`BasicObject#!=` 30k, `stale_state`, `where_clause=`, `Logger#level`); YJIT is megamorphic at some of them too. Cause not traced |
| `&block` to a C method and other `complex_arg_pass` (14) | 72k (19.9) | 21k (6.1) | 38k (12.8) | in part free (`**rest` callees, Shopify/ruby#1039 rows 36/43 unassigned) |
| protected calls, `need_permission` (4) | 55k (15.3) | 16k (4.4) | 30k (10.3) | **free again.** Our ruby/ruby#19483 was closed 11-04; tekknolagi filed Shopify/ruby#1109 (open, unassigned) |
| `Kernel#send`, `method_type_optimized` (5) | 42k (11.6) | 20k (5.7) | 41k (13.8) | taken: tekknolagi, ruby/ruby#19583 (open draft) |
| ivar read in a final version, `no_side_exits` (15) | 0 | 75k (5.9) | 95k (9.6) | 15a free (our candidate build, not opened); 15c taken (k0kubun, ruby/ruby#19617 open). Railsbench went from 74k to 0 |
| side exits and frame materialization (17) | 13.6 M | 4.5 M | 10.6 M | taken (Shopify/ruby#1093, ruby/ruby#18759, #18244, all open) |
| JIT code: cfunc calls with a frame (12), PatchPoint padding (16) | in JIT code | | | 12 taken (k0kubun, Shopify/ruby#1030); 16 free, low priority |
| `rb_zjit_root_mark` per JITFrame (13) | not visible with a fixed heap | | | free; our ruby/ruby#19685 closed 11-04 (no wall-time effect) |
| rails/rails#59141 shared readers (candidate) | — | +208 `block_arg_not_nil`, +51 `polymorphic_fallback`, +24 net `no_side_exits` per request (census) | — | **no bucket of its own**; inside leads 7, 3 and 15 (section 6) |

**Unowned, largest first:** lead 3 (class-polymorphic sends; the largest on lobsters and shipit), lead 7 (`&block`
forwarding; taken after all, see [zjit-leads](zjit-leads.md)), the new megamorphic-send growth, protected
calls (lead 4, free since our PR closed), and the `**rest` part of lead 14.

## Method and pins

* **Ruby master** [`b7e8fad022`](https://github.com/ruby/ruby/commit/b7e8fad022) (2026-11-14 10:43 UTC,
  `ruby 4.1.0dev (2026-11-14T10:43:38Z HEAD b7e8fad022) +PRISM [x86_64-linux]`), `--enable-yjit --enable-zjit
  --disable-install-doc`, GCC 14.2.0, rustc 1.100.0. It is the only master build; the variants below are incremental
  builds of it that change one thing and share its gems.
  * master + `1c64fd8d6a` (`--zjit-stats-iseq`, thomasklemm/ruby `thomasklemm/zjit-stats-iseq`; one `hir.rs` conflict
    resolved to master) for per-ISEQ ZJIT counters only, never timed;
  * master + the GC fix (`7bc813e025`) for bigslot, and master + ruby/ruby#17251 (`41c689571a` cherry-picked) for
    bigslot and its shipit and census GC cells;
  * master + [`gcstep.patch`](../../fixtures/corpus/ruby-41-watch/gcstep/gcstep.patch) (`RUBY_GC_POOL_MODE`,
    sweep-step log) for the shipit and census GC cells.
* **Ruby 4.0.9:** mise's binary (GCC 10.2.1) for the allocation census, and a local build of `v4.0.9` with master's
  compiler and flags (`--enable-yjit`) for every instruction count, because the compiler alone moves counts by 1.5%
  (round 1).
* **Rails:** main [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b)
  (2026-11-13) in the census; #59141 is `1f32b09101`, its parent `c48c154e3f`.
* **Apps:** `script/census --corpus census5`, Blog, Fizzy (SQLite) and Lobsters, set up on Rails main with the
  master overlays (`fixtures/corpus/frontier-master`). Three of round 1's nine apps: they cover a small app, the app
  with the most models, and the app ruby-bench also has. Two local workarounds for Rails main (#59141 section).
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2fc1a84702fea63e06f64d179751d69df4)
  (the gap page's pin): railsbench and lobsters on Rails 8.1.1, shipit on 8.1.2. Copies with Rails main and with
  #59141's parent for railsbench.
* **Valgrind:** the pinned 3.19.0 with the 512 MiB brk reservation (`script/bench-valgrind`, tool SHA-256
  `7749537b…0eb294` on this orb, patch `ab95c4a3…`). Every Callgrind log was checked for `brk segment overflow`; none
  had one. **Rejected:** every Callgrind run before 13:00 used the orb's stock Valgrind 3.24, which logged the
  overflow in each Rails run. That cohort (the first gap runs and the first keyword sweep) was discarded, not
  rescored, and rerun with the pinned tool. The three miniruby bisects of that period keep only the commits they
  located; their numbers were remeasured with the pinned tool (section 1).
* **Fixed heap.** Master: `RUBY_GC_HEAP_INIT_BYTES=33554432`. On master this is a per-heap floor applied lazily
  (`heap_prepare` force-allocates pages without GC until each heap holds 32 MiB / slot size slots); it does not
  pre-allocate at boot. 4.0.9: `RUBY_GC_HEAP_{0..4}_INIT_SLOTS` = 32 MiB per pool (838,860 … 52,428). Each window
  records `heap_before` (pages per heap); ZJIT and YJIT had one GC per railsbench window on master. The GC bucket is
  therefore smaller than on 11-03 (10.7 GCs per window then) and is not compared across the two pages.
* **JIT-flat gate.** [`zjit_yjit_gap_harness.rb`](../../bench/upstream/zjit_yjit_gap_harness.rb) now runs warm
  windows of 3 iterations until the compile and invalidation counters are unchanged over 2 consecutive windows
  (`FLAT_WINDOWS`, up to 8), then measures, and records `jit_flat.gate`: pass only if the measured window also leaves
  them unchanged (YJIT: compiled ISEQs, blocks, invalidations; ZJIT: compiled ISEQs, side exits and
  `invalidation_time_ns`, since ZJIT counts no invalidations). Warmup is 40 iterations, not 15. Two time-based
  sources failed it and are disabled in the ruby-bench copy: the connection-pool reaper (60 s timer; ZJIT compiled
  ISEQs at iterations 29, 48, 65) and ActiveRecord's `verify_timeout` of 2 s (YJIT compiled two blocks of `block in
  with_raw_connection` in the window, after the window's three `GC.start` took longer than 2 s under Valgrind). The
  copy sets `reaping_frequency: 0` and `verify_timeout: 1000000`; this changes no request work. Both rejected cohorts
  are kept (`cg-rejected/`), and neither number is used. The census Callgrind window records the same counters
  (`jit_flat` per window in [`rails_main_census_4.rb`](../../bench/upstream/rails_main_census_4.rb)).
* **A/A.** Allocation census: two full runs per Ruby and mode, a workload moves only beyond twice the larger A/A
  spread. Keyword sweep: two runs per Ruby (identical to 0.2% below size 8). Gap: ZJIT railsbench run c (no perf map) against run a, 4,830.5 vs 4,833.6 M Ir (−0.06%); no YJIT A/A this round to save orb time (11-03's was 0.19%). GC cells: rounds a, b, c
  (shipit) and a, b (census), alternating master and fix.
* **Scripts** in [fixtures/corpus/ruby-master-round-2](../../fixtures/corpus/ruby-master-round-2): `cg_queue.sh` (gap Callgrind queue), `stats_queue.sh`,
  `kw_sweep.rb`/`.sh`/`_report.rb`, `hashlit.sh`, `lookup_time.rb`, `bisect_hash{lit,pair,lookup}.sh`,
  `gc_shipit.sh`, `gc_census.sh`, `gc_report.rb`, `r59141_stats.sh`/`_cg.sh`/`_report.rb`, `zstats_diff.rb`. The
  in-repo harness changes are the JIT-flat gate above. Receipts: [`data/ruby-master-round-2/receipts.tar.gz`](data/ruby-master-round-2/receipts.tar.gz) (gap and #59141 per-function JSONs and reports, JIT stats, keyword sweep, Hash bisect, bigslot, GC and census reports; Callgrind dumps not kept).
