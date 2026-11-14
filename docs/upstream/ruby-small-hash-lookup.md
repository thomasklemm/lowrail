# F1: small-Hash lookups on Ruby master, the fix (2026-11-14)

A lookup in a small Hash (`h[:b]` on three Symbol keys) runs 333 instructions on master against 287 on 4.0.9,
bisected to ruby/ruby#18222 (byroot, SWAR `ar_find_entry_hint`) and ruby/ruby#18476 (Peter Zhu, AR-table identity
hashes).

**Short answer.** One function split in `hash.c` recovers almost all of it and keeps both PRs' gains: `h[:b]` 333 →
294 instructions (4.0.9: 287), 1.31–1.33× the lookups per second on #18222's own benchmark at every hit position (1.29× for `h[:b]`), Symbol
literals of 1–8 pairs 4–9% fewer instructions, railsbench −0.39% and lobsters −0.22% instructions per iteration
(interpreter). Tables of 9 keys and more are unchanged. Slower: every lookup whose first hint match holds a
different object, +11 to +21 instructions, e.g. an equal String built at runtime +13 (+2.4%); worst in percent is a
miss behind a hint collision, +3.4% to +4.6% depending on the loop (see "Where it loses"). Wall time on those is within noise.

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
`ObjectSpace.dump` shows a 64-byte slot on both. Identity lookups get cheaper with the branch: Symbol keys 308 → 277
(−10%), an `Object.new` key in a 2-key identity Hash 298 → 268 (top-level loop as in `repro_ir.sh`). One review
measured an identity Hash with heap-object keys as unchanged (322 → 322): it filled 3 keys by `[]=`, which makes an
st_table on master (round 2's finding 3), as does the "ident obj n=3" case in `ir-interp.txt` (298 / 298).

**Under YJIT and ZJIT** the same micros (same script, `--yjit` / `--zjit`, every case warmed before any window, JIT-flat
gate between the empty and the measured window: passed in all 74 cases on all four runs;
[`results/ir-yjit.txt`](../../bench/upstream/f1/results/ir-yjit.txt),
[`results/ir-zjit.txt`](../../bench/upstream/f1/results/ir-zjit.txt)). Both JITs call the same `rb_hash_aref` and
`rb_hash_bulk_insert`, so the saving is the same in absolute terms and larger in percent:

| case | master YJIT | branch YJIT | master ZJIT | branch ZJIT |
| --- | ---: | ---: | ---: | ---: |
| loop alone | 28 | 28 | 24 | 24 |
| `h[:b]`, 3 keys | 188 | 149 (−20.7%) | 185 | 146 (−21.1%) |
| `hash_ar_aref` any hit / miss | 187 / 180 | 148 / 167 | 185 / 178 | 146 / 165 |
| String key, equal but another object | 404 | 417 (+3.2%) | 401 | 414 (+3.2%) |
| identity Hash, hit | 163 | 132 | 169 | 138 |
| literal, 1 / 3 / 8 pairs | 481 / 979 / 2,234 | 453 / 895 / 2,011 | 414 / 901 / 2,156 | 386 / 817 / 1,933 |

Every st_table row (9 to 1,000 keys, lookups, literals, `[]=`) is identical under YJIT; under ZJIT all are identical
except the 9-pair literal (2,718 → 2,654, −2.3%), which takes the unchanged st_table path; not investigated.

## Where it loses

Every lookup whose first hint match holds a different object runs `ar_equal` as before, after the inline check,
and pays +11 to +21 instructions (master → branch, Ir per iteration, measured in the two reviews, consistent with
the String rows above). First review, top-level loop: a Symbol miss behind a hint collision 385 → 398 (+3.4%, the worst in
that review), the same Symbol behind a colliding slot 376 → 387 (+2.9%), an equal String 536 → 549 (+2.4%; a chilled
`h["b"]` literal 928 → 942), a String collision miss 565 → 578, an equal Bignum 1,034 → 1,047, an equal Float
862 → 875, a user-defined `eql?` 3,816 → 3,833 (+0.4%), `key?`/`fetch` with an equal String +3/+8.
Second review, its own loop: a miss whose hint matches one other key 372 → 389 (+17, +4.6%, the worst), a hit on
the second key sharing a hint +11 (Symbol 384 → 395, String 523 → 534), a miss past 3 colliding keys +11, `aset`
with an equal String +13, a Struct key with a user `eql?` +21 (+0.5%). Hint collisions between two keys happen about
once in 255 pairs (1–3% of misses at 3–8 keys); Symbols and same-object keys, the common case, take the fast path.

## Top-level loops

The first body (opened as ruby/ruby#19899) showed a 3-line loop and this table, run at top level as written: whole process under Callgrind, (Ir at
N = 2,000,000 − Ir at N = 0) / N, fixed salt, fixed heap ([`repro_ir.sh`](../../bench/upstream/f1/repro_ir.sh)),
seeds 1 and 2 identical ([`results/repro-ir/`](../../bench/upstream/f1/results/repro-ir/)). They come out 13 below
the `x = expr`-in-a-method form above; the differences are the same. The 8-key rows use `:k1`…`:k8`: with
`hash_ar_aref.yml`'s `:a`…`:h`, `:g` and `:h` share a hint in the installed 4.0.9 process, so its last-key lookup
calls `ar_equal` twice and measures 352 instead of the linear scan's 322 (found in review). Master and the branch
give the same numbers with either key set under seed 1; under seed 2, `:a`…`:h` collide on master as well
(last key 411).

| loop | 4.0.9 | master | branch |
| --- | ---: | ---: | ---: |
| `h = {a: 1, b: 2, c: 3}`, `h[:b]` | 274 | 320 | 281 |
| 8 Symbol keys, hit at the first / last key | 266 / 322 | 320 / 320 | 281 / 281 |
| 8 Symbol keys, miss | 333 | 313 | 300 |
| 3 String keys, `h[k]` with `k = +"b"` | 502 | 539 | 552 |
| loop alone | 126 | 128 | 128 |

## The PR body's benchmark

The body now shows #18222's own `benchmark/hash_ar_aref.yml`, as its body did. `make benchmark ITEM=hash_ar_aref
COMPARE_RUBY=~/w/inst/base/bin/ruby OPTS="--repeat-count 10"` in the branch build directory, `taskset -c 2`, without
the fixed-seed shim, benchmark-driver v0.16.3 from `make update-benchmark-driver`
([`results/bd-make-benchmark.md`](../../bench/upstream/f1/results/bd-make-benchmark.md)):

| case | master | branch | branch / master |
| --- | ---: | ---: | ---: |
| miss_empty | 14.856M | 14.833M | 1.00 |
| hit_first | 8.108M | 10.657M | 1.31 |
| hit_third | 7.930M | 10.648M | 1.34 |
| hit_fourth | 7.942M | 10.695M | 1.35 |
| hit_last | 8.028M | 10.733M | 1.34 |
| miss | 9.338M | 9.952M | 1.07 |

The 4.0.9 numbers in the body come from a separate three-way benchmark-driver 0.17 run of the same file on the same
core, best of 10, no shim ([`results/bd-3way.md`](../../bench/upstream/f1/results/bd-3way.md)): 4.0.9 / master /
branch hit_first 10.300M / 7.924M / 10.896M, hit_third 9.441M / 7.992M / 11.066M, hit_fourth 7.951M / 8.097M /
10.894M, hit_last 7.601M / 8.152M / 10.692M, miss 6.819M / 9.081M / 9.977M, miss_empty 14.338M / 14.847M / 14.804M.
Master and branch agree with the `make benchmark` run within 4%; 4.0.9's hit_third moves between runs (8.1M with the
shim, 9.4M without), as its linear scan depends on which keys share a hint in that process.

Before these runs the branch was reinstalled from its build directory: the installed `ruby` predated the final
`hash.c` timestamp and still printed the base revision. Its `ar_find_entry_hint`, `ar_find_entry_hint_slow`,
`rb_hash_aref` and `ar_equal` disassemble identically to the reinstalled binary, so the earlier measurements stand;
the reinstalled one prints `696e3f5f0c`. The "+13 instructions (+2.4%)" for an equal String is the in-method
(552 → 565) and top-level (539 → 552) Callgrind rows above; its wall time (46.5M vs 46.1M i/s) is in the
benchmark-driver table below.

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



## ruby-bench railsbench and lobsters

Callgrind, M Ir per iteration (3 measured iterations, GC included, about one minor GC per window in every run), the
Hash functions' self Ir alongside ([`cg_report.rb`](../../bench/upstream/f1/cg_report.rb); same regex for both
builds). Runs a and b are two runs of the same build (A/A).

| benchmark, mode | master a / b | branch a / b | branch − master | Hash functions master → branch | JIT-flat gate |
| --- | ---: | ---: | ---: | ---: | --- |
| railsbench, interpreter | 7,404.5 / 7,402.8 | 7,376.6 / 7,373.2 | **−28.8 (−0.39%)**, A/A ≤ 0.05% | 686.6 → 658.9 | n/a |
| railsbench, YJIT | 4,742.6 / 4,735.7 | 4,716.2 / 4,705.4 | **−28.3 (−0.60%)**, A/A ≤ 0.23% | 680.5 → 651.6 | pass (all four) |
| railsbench, ZJIT | 4,902.9 / 4,902.2 | 4,877.3 / 4,874.7 | **−26.6 (−0.54%)**, A/A ≤ 0.05% | 679.1 → 650.2 | pass (all four) |
| lobsters, interpreter | 3,619.0 / 3,619.0 | 3,611.1 / 3,610.9 | **−8.0 (−0.22%)**, A/A ≤ 0.004% | 235.8 → 225.8 | n/a |
| lobsters, ZJIT | 2,496.7 | 2,488.3 | −8.4 (−0.34%), single runs | 232.8 → 223.2 | pass |
| lobsters, YJIT | 2,334.0 | 2,325.5 | rejected | | **fail** (both) |

The lobsters YJIT pair failed the gate (YJIT compiled blocks in the measured window, as in round 2) and is rejected,
not rerun; its numbers are diagnostic only. Per-run numbers:
[`results/ruby-bench-callgrind.json`](../../bench/upstream/f1/results/ruby-bench-callgrind.json), the
[`cg_report.rb` output](../../bench/upstream/f1/results/ruby-bench-cg-report.txt) and each run's ruby-bench metadata
([`results/ruby-bench-runs/`](../../bench/upstream/f1/results/ruby-bench-runs/)); the Callgrind dumps (200 MB) are
not committed. The branch takes back about 28 M of round 2's +50.5 M Ir per railsbench
iteration in Hash functions; the rest is in literal building and allocation (above), which this change does not
target.

## Tests and warnings

* `make check` on the branch: btest 2,148/2,148 pass; test-spec 33,747 examples, 0 failures, 2 errors; test-all
  38,997 tests, 1 failure, 2 errors; test-tool 1 failure. All four are environmental and fail identically on
  unpatched master in this orb: the two spec errors are `CLOCK_REALTIME_ALARM` / `CLOCK_BOOTTIME_ALARM` (EINVAL in
  the sandbox), the two test-all errors are `TestIO#test_seek*` (tmpfile vanished under the parallel runner; both
  fail on master alone too), `TestThread#test_handle_interrupt_masks_sigint` failed once under `-j2` load and passes
  5/5 alone on both builds, and `TestCommitEmail#test_sendmail_encoding` fails because the orb sets `GIT_AUTHOR_*`.
* Targeted: `test_hash`, `test_optimization`, `test_keyword`, `test_set`, `test_object`, `test_object_id`,
  `test_literal`, `test_marshal`: 1,055 tests, 0 failures; mspec `core/hash core/set`: 738 examples, 0 failures.
* Warnings: with Ruby's own flags (`-Wall -Wextra` and the rest of configure's list), GCC 14.2 and Clang 19.1 build
  `hash.c` without a warning on master and on the branch. With extra `-Wall -Wextra` on Clang, both give the same one
  warning (`-Wtautological-pointer-compare`, `if (RHASH_AR_TABLE(hash) != NULL)`, unchanged code) and none in the
  changed code. GCC and Clang both keep `ar_find_entry_hint_slow` out of line. GCC 14 inlines
  `ar_find_entry_hint` into `ar_lookup`, `rb_hash_has_key`, `rb_hash_slice`, `rb_hash_stlike_delete`,
  `rb_hash_except`, `env_except` and `ar_insert_direct`, and keeps it out of line for `rb_hash_aref`, `rb_hash_aset`,
  `rb_hash_fetch`, `rb_hash_dig`, `rb_hash_lookup`/`lookup2`, `hash_foreach_call` and others, now as a leaf without
  register saves that tail-jumps to `_slow`; hash.o text grows 79,994 → 80,226 bytes here (a review build measured
  +632). The `inline` keyword matters for the inlined callers: without it `h[:b]` is the same, but in review
  `fetch` cost +10, `key?` +14 and the 3- / 8-pair literals +44 / +120. `NOINLINE` on `_slow` changes nothing with GCC 14 `-O3` (hash.o byte-identical without it, per review);
  it keeps other compilers from inlining the loop, and its register saves, back into the hit path, as on `ar_equal`.
* Differential probe ([`diff_probe.rb`](../../bench/upstream/f1/diff_probe.rb), 127 lines of results: self-unequal
  `eql?`, NaN, `eql?` call counts, an `eql?` that converts the table to an st_table mid-lookup, String keys,
  identity hashes, delete/reinsert, a Hash subclass, default procs, duplicate literal keys, sizes 1–10, 100 random
  mixed tables): identical output on master and the branch with the system seed and with fixed seeds 1, 2, 3.

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

## Internal

Finding 1 of [Ruby master round 2](ruby-master-round-2.md#1-small-hash-lookups-and-inserts-cost-more). Thomas
allowed this one as a ruby/ruby PR (DECISIONS, exception of 2026-11-14), after the "Thomas can explain it first"
step. **Nothing is opened.** Queue item [F1](../../bench/upstream/pr-queue/items/F1.md). A review noticed, outside
this change and not investigated: a heap Float key (`h[1e300*1]`, 2 keys) costs 376 Ir on 4.0.9, 820 on master and
833 on the branch.

### Für Thomas (zum Nacherzählen)

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
s[+"b"]               # gleicher Inhalt, anderes Objekt: alter Weg wie bisher (+13 Instruktionen, +2,4 %)
```
