# F1: small-Hash lookups on Ruby master, the fix (2026-11-14)

Finding 1 of [Ruby master round 2](ruby-master-round-2.md#1-small-hash-lookups-and-inserts-cost-more): a lookup in a
small Hash (`h[:b]` on three Symbol keys) runs 333 instructions on master against 287 on 4.0.9, bisected to
ruby/ruby#18222 (byroot, SWAR `ar_find_entry_hint`) and ruby/ruby#18476 (Peter Zhu, AR-table identity hashes).
Thomas allowed this one as a ruby/ruby PR (DECISIONS, exception of 2026-11-14), after the "Thomas can explain it
first" step. **Nothing is opened.** Queue item [F1](../../bench/upstream/pr-queue/items/F1.md).

**Short answer.** One function split in `hash.c` recovers almost all of it and keeps both PRs' gains: `h[:b]` 333 →
294 instructions (4.0.9: 287), 1.29× the lookups per second on #18222's own benchmark at every hit position, Symbol
literals of 1–8 pairs 4–9% fewer instructions, railsbench −0.39% and lobsters −0.22% instructions per iteration
(interpreter). Tables of 9 keys and more are unchanged. The one slower case is a hint match on a different but
equal key (a String built at runtime): +13 instructions (+2.4%).

## Für Thomas (zum Nacherzählen)

Ein kleiner Hash (bis 8 Schlüssel) findet einen Schlüssel über ein Hinweis-Byte und prüft dann, ob der Schlüssel an
dieser Stelle wirklich gleich ist. Auf master macht diese Prüfung seit #18222 und #18476 drei Funktionsaufrufe, obwohl
bei Symbolen dort fast immer genau dasselbe Objekt liegt; deshalb kostet `h[:b]` 333 statt 287 Instruktionen. Die
Änderung schaut zuerst nur, ob an der gefundenen Stelle exakt dasselbe Objekt liegt, und gibt die Stelle dann sofort
zurück, sonst läuft der bisherige Code. Das ist sicher, weil ein Objekt immer gleich sich selbst ist (normale Hashes
prüfen `a == b` als Erstes, `compare_by_identity` prüft nur das) und dabei kein Ruby-Code läuft, der den Hash ändern
könnte.

```ruby
h = {a: 1, b: 2, c: 3}
h[:b]                 # :b ist dasselbe Objekt wie der gespeicherte Schlüssel: neuer kurzer Weg, 333 → 294
s = {"b" => 1}
s[+"b"]               # gleicher Inhalt, anderes Objekt: alter Weg wie bisher (+13 Instruktionen)
```

## What is wrong

`rb_hash_aref` on an AR table computes the key's hash, then `ar_find_entry_hint` finds the slot. Per `h[:b]`
(self instructions, function by function, Callgrind):

| | 4.0.9 | master `88ea6fd282` | this branch |
| --- | ---: | ---: | ---: |
| `rb_hash_aref` | 87 (search inlined) | 41 | 41 |
| `any_hash` | inlined | 26 | 26 |
| `ar_find_entry_hint` | inlined | 51 | 29 |
| `ar_equal` | 4 (with `rb_any_cmp` inlined) | 13 | — |
| `rb_any_cmp` | — | 4 | — |
| `rb_hash_start` | 3 | 3 | 3 |
| **total in Hash code** | **94** | **138** | **99** |

Since #18222 GCC compiles `ar_find_entry_hint` as its own function, and because of its slow-path loop it saves five
callee-saved registers on every call, hit or miss. Since #18476 `ar_equal` takes the Hash and checks the identity
flag first, and GCC no longer inlines `rb_any_cmp` into it. A hit on a Symbol key therefore makes three calls
(`ar_find_entry_hint` → `ar_equal` → `rb_any_cmp`) just to learn that the key is the very object stored in the
slot, which is always the case for Symbols.

## The change

Branch [`thomasklemm/ar-small-lookup`](https://github.com/thomasklemm/ruby/tree/thomasklemm/ar-small-lookup),
one commit on ruby/ruby master `88ea6fd282`. `ar_find_entry_hint` becomes an inline function that runs the SWAR
search and returns the first matching slot when it holds the same object as the key; anything else continues in
`ar_find_entry_hint_slow`, which is the previous body from the first `ar_equal` call on, marked `NOINLINE` like
`ar_equal`.

**Exact.** A key that is the same object as the stored key is equal under both comparisons an AR table uses:
`rb_any_cmp` returns 0 for `a == b` before anything else, and an identity hash compares `x == y`. No Ruby code runs
on that path, so the table cannot be converted or changed under the lookup, and the `RHASH_AR_TABLE_P` check that
follows `ar_equal` is not needed there. A differential probe (self-unequal `eql?`, NaN, counting `eql?`, an `eql?`
that converts the table to an st_table, String keys frozen and not, identity hashes, deleted and reinserted
entries, a Hash subclass, default procs, duplicate literal keys, sizes 1–10, 100 random mixed-key tables) prints the
same on master and the branch with the system seed and with three fixed seeds. `#eql?` calls are the same: master
never called `eql?` for an identical key either.

**Can the broken piece go?** The pieces that cost are not the SWAR search or the identity flag but the call
structure around them on the hit path. Both stay: SWAR still wins on x86-64 where #18222 said it would (late hits
and misses, below), and identity hashes still need the flag check on the slow path. What goes is the out-of-line
call with its register saves and the `ar_equal`/`rb_any_cmp` calls for a key that is the stored object.

**Variants measured** (same seed, interpreter, Ir per op; base / variant):

| variant | `h[:b]` | miss | equal String, not identical | 3-pair literal |
| --- | ---: | ---: | ---: | ---: |
| this branch (inline fast path + out-of-line rest) | 333 → 294 | 326 → 313 | 552 → 565 | 1,152 → 1,068 |
| same-object check inside the existing out-of-line function | 333 → 309 | 326 → 326 | 552 → 554 | unchanged |
| the rest as one plain loop from the first match | 333 → 310 | 326 → 327 | 552 → 563 | 1,152 → 1,068 |
| this branch, `ar_equal` without `NOINLINE` | 333 → 294 | 326 → 313 | 552 → 558 | 1,152 → 1,068 |

The first is the branch. Dropping `NOINLINE` from `ar_equal` halves the cost of the equal-String case but is a
second, unrelated change; it can be offered if a reviewer asks about that row.

## Instructions per operation (interpreter)

Callgrind, Ir per loop iteration including the loop (`empty` is the loop alone), seed 1; seed 2 gives the same
numbers except where a hint collision moves (n = 64 miss, n = 1000 miss, n = 16 literal). A/A: 0 in all 74 cases.
Full table with both seeds: [`results/ir-interp.txt`](../../bench/upstream/f1/results/ir-interp.txt).

| case | 4.0.9 | master | branch | branch vs master |
| --- | ---: | ---: | ---: | ---: |
| loop alone | 157 | 159 | 159 | 0 |
| `h[:b]`, 3 keys (the finding) | 287 | 333 | **294** | −11.7% |
| hit at the first key, 1–8 keys | 268 | 330 | 291 | −11.8% |
| hit at the last key, 2 / 4 / 8 keys | 276 / 292 / 324 | 330 | 291 | −11.8% |
| miss, 1 / 4 / 8 keys | 290 / 314 / 346 | 326 | 313 | −4.0% |
| miss, empty Hash | 247 | 240 | 240 | 0 |
| `h.fetch(:b)` / `h.key?(:b)`, 3 keys | 473 / 404 | 524 / 454 | 475 / 401 | −9.4% / −11.7% |
| Integer key, 3 keys | 288 | 333 | 294 | −11.7% |
| String key, same object | 313 | 359 | 320 | −10.9% |
| **String key, equal but another object** | 515 | 552 | **565** | **+2.4%** |
| String key, miss | 436 | 452 | 439 | −2.9% |
| identity Hash, Symbol hit, 1–8 keys | 295–337 | 308 | 277 | −10.1% |
| identity Hash, miss, 1–8 keys | 311–353 | 309 | 296 | −4.2% |
| 9 / 16 / 64 / 1,000 keys (st_table), hit | 329 / 338 / 341 / 354 | 324 / 339 / 341 / 345 | same | 0 |
| 9 / 16 / 64 / 1,000 keys (st_table), miss | 372 / 369 / 401 / 375 | 367 / 355 / 355 / 466 | same | 0 |
| literal, 1 / 3 / 8 Symbol pairs | 499 / 917 / 2,102 | 644 / 1,168 / 2,513 | 616 / 1,084 / 2,289 | −4.3% / −7.2% / −8.9% |
| literal, 9 / 16 pairs (st_table) | 3,122 / 4,575 | 2,954 / 4,283 | same | 0 |
| literal, 3 String pairs | 1,002 | 1,361 | 1,277 | −6.2% |
| `h[:b] = v`, existing key, 3 / 1,000 keys | 521 / 545 | 482 / 466 | 443 / 466 | −8.1% / 0 |
| `g = {}; g[:a] = v; g[:b] = v; g[:c] = v` | 1,338 | 2,159 | 2,133 | −1.2% |
| `h.merge(o)`, 3 + 1 keys | 1,299 | 1,696 | 1,570 | −7.4% |
| `h.dup`, 3 keys / `kw(a:, b:, c:)` | 1,444 / 646 | 1,564 / 664 | same | 0 |

The literals recover 28 instructions per pair (one SWAR miss each without the out-of-line call) but stay 9–24% above
4.0.9 (1 to 8 pairs). The rest of the gap is outside the hint search; in the per-function profile of the 3-pair
literal it is `rb_hash_bulk_insert` itself (103 → 148), an out-of-line `any_hash` (26 per pair),
`rb_gc_writebarrier` calls (21 per pair, none on 4.0.9) and allocation. Inserting into an empty Hash by `[]=`
is round 2's finding 3 (st_table from the third key, ruby/ruby#18345) and moves only 1%.

**#18222's own benchmark** (`benchmark/hash_ar_aref.yml`, eight keys, one lookup per iteration here): master runs
333 instructions at every hit position, the branch 294; 4.0.9 279 / 295 / 303 / 335 for the first, third, fourth and
last key. Misses: 4.0.9 346, master 326, branch 313. So the branch is below 4.0.9 from the third key on and on every
miss, the constant-time behaviour #18222 introduced, and 15 instructions above 4.0.9 for the first key (4.0.9 had
the whole search inlined into `rb_hash_aref`, including the hash function).

**#18476's own claim** (an identity Hash as an AR table instead of an st_table): `ObjectSpace.memsize_of({}.compare_by_identity)`
is 256 on 4.0.9 and 64 on master and on the branch (the 160 in #18476's description predates later right-sizing);
`ObjectSpace.dump` shows a 64-byte slot on both. Identity lookups get 10% cheaper with the branch.

## Wall time

**The 3-line repro** (`while i < 20_000_000; h[:b]; i += 1; end`), hyperfine, 15 runs after 3 warmups, one pinned
core, no JIT; per lookup = (median − median of the same loop without `h[:b]`) / 20 M
([`results/hyperfine-repro.json`](../../bench/upstream/f1/results/hyperfine-repro.json)):

| | 4.0.9 | master | master A/A | branch |
| --- | ---: | ---: | ---: | ---: |
| whole run, median ms | 375.6 | 452.0 | 451.0 | 398.5 |
| empty loop, median ms | 165.3 | 190.8 | | 191.3 |
| **per lookup** | **10.5 ns** | **13.1 ns** | 13.0 ns | **10.4 ns** |

Round 2 measured 2.9 → 6.4 ns per lookup with a different loop and subtraction; the direction is the same, the
master/4.0.9 ratio here is 1.25×, not 2.2×.

**#18222's benchmark and the size sweep**, benchmark-driver, best of 10 runs per executable, one pinned core, no
JIT, M i/s ([`results/bd-interp-1.log`](../../bench/upstream/f1/results/bd-interp-1.log); `hash_ar_aref` cases do
10 lookups per iteration):

| case | 4.0.9 | master | branch | branch / master |
| --- | ---: | ---: | ---: | ---: |
| `hash_ar_aref` miss_empty | 14.41 | 15.57 | 15.14 | 0.97 |
| `hash_ar_aref` hit_first | 10.31 | 8.00 | 10.58 | **1.32** |
| `hash_ar_aref` hit_third | 8.13 | 8.01 | 10.48 | **1.31** |
| `hash_ar_aref` hit_fourth | 7.87 | 7.93 | 10.47 | **1.32** |
| `hash_ar_aref` hit_last | 7.58 | 7.94 | 10.59 | **1.33** |
| `hash_ar_aref` miss | 6.82 | 8.66 | 8.96 | 1.04 |
| `h3[:b]` | 101.2 | 79.6 | 102.4 | **1.29** |
| `h3.fetch(:b)` | 54.4 | 48.5 | 53.8 | 1.11 |
| `s3[+"b"]` (equal String, other object) | 46.0 | 46.5 | 46.1 | 0.99 |
| `ident[:c]` (identity Hash, 3 keys) | 101.0 | 107.6 | 135.5 | **1.26** |
| `big[:k500]` (1,000 keys) | 86.9 | 74.9 | 76.6 | 1.02 |

So #18222's claim holds on x86-64 for late hits and misses (master over 4.0.9: hit_last 1.05×, miss 1.27×), its
hit_first is 0.78× of 4.0.9 on master, and the branch is faster than both at every position. The equal-String case
that costs +13 instructions is within noise in wall time. The 1,000-key row (st_table, not touched) shows how far
single cells move between executables here.



## Method and pins

* Ruby master [`88ea6fd282`](https://github.com/ruby/ruby/commit/88ea6fd282) (2026-11-14 18:00 UTC) and the branch
  built on it, both `--enable-yjit --enable-zjit`; Ruby 4.0.9 built from `v4.0.9` with `--enable-yjit`; GCC 14.2.0
  `-O3`, rustc 1.100.0. Variants are build-directory binaries of the branch tree with `hash.c` changed.
* Valgrind: the pinned 3.19.0 with the 512 MiB brk reservation (`script/bench-valgrind`, Callgrind tool SHA-256
  `1c77713c…ff6b3` on this orb). No log had a `brk segment overflow`.
* Micro instruction counts ([`hash_ir.rb`](../../bench/upstream/f1/hash_ir.rb)): each case in its own Callgrind
  window, (window of N = 200,000 iterations − window of 0) / N, loop included; fixed heap
  (`RUBY_GC_HEAP_INIT_BYTES=33554432` on master, the five per-pool slot floors on 4.0.9); no ASLR; the hash salt
  fixed per run by an `LD_PRELOAD` shim ([`fixseed.c`](../../bench/upstream/f1/fixseed.c)), because which keys share
  a hint byte depends on the per-process salt and moves single cases by up to 70 instructions between runs.
  A/A (same build, same seed, same script): identical in all 74 cases. Two seeds; every case without a hint
  collision agrees between seeds.
* ruby-bench [`0e67be0`](https://github.com/ruby/ruby-bench/commit/0e67be0) (main), railsbench and lobsters, copy with
  `reaping_frequency: 0` and `verify_timeout: 1000000` as in round 2, harness `harness/gap.rb`
  ([`zjit_yjit_gap_harness.rb`](../../bench/upstream/zjit_yjit_gap_harness.rb), JIT-flat gate) via
  [`cg_queue.sh`](../../bench/upstream/f1/cg_queue.sh); fixed heap 32 MiB per heap; 5 warmup iterations without JIT,
  40 with; 3 measured iterations; GC included. Each run pinned to one core.
* Wall time: benchmark-driver 0.17 on one pinned core, best of 10 per executable, with the fixed-seed shim;
  hyperfine 1.19.0.
