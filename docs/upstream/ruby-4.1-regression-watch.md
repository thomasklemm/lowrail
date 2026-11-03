# Ruby 4.1 regression watch: census 4 apps on Ruby 4.0.7 and master

The census 4 workloads (nine Rails apps, 97 request, job and mailer workloads, same Rails main commit) ran on Ruby
4.0.7 and on a fresh build of ruby/ruby master, interpreter and YJIT on both, ZJIT on master. The aim was to catch
4.1 regressions that hurt Rails apps before 4.1 ships, the way `{}` spilling at the third insert after ruby/ruby#18345
was only noticed weeks later through Rails #59108 and its revert #59203.

**Three confirmed regressions, all bisected; two have a fix on a branch.** Overall master allocates
fewer objects and far fewer bytes than 4.0.7 and runs fewer instructions; the regressions hide inside that improvement.

| # | Finding | Modes | Reach | Bisected to | Existing report | Fix |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | `m(a: v, **h)` and zsuper with keywords allocate a second Hash | interp, YJIT, ZJIT | 94 of 97 workloads, all nine apps; median +9, mean +40 Hashes/op, max +394 objects/op | [`f01bf185f6`](https://github.com/ruby/ruby/commit/f01bf185f67ab13e626a270a510b0b37a59c6a0c) (ruby/ruby#18344) | none found | [`thomasklemm/kwsplat-fit-merge`](https://github.com/thomasklemm/ruby/tree/thomasklemm/kwsplat-fit-merge) @ [`e5e20a5207`](https://github.com/thomasklemm/ruby/commit/e5e20a52076396271de600e735d95716bfd2c086) |
| 2 | Sparse large-slot heaps force `nofree` major GCs | interp, YJIT | 74–76 of 97 workloads run more GCs; majors +142% (interp) and +159% (YJIT), all GCs +39% and GC time +12% under YJIT | [`16da5f23c2`](https://github.com/ruby/ruby/commit/16da5f23c29b6b6e2c464a2f2e3c41e1aba99e1e) (ruby/ruby#16632) | none found; open ruby/ruby#17251 touches the same decision and does not fix it | [`thomasklemm/gc-pool-budget`](https://github.com/thomasklemm/ruby/tree/thomasklemm/gc-pool-budget) @ [`4b02fa55cb`](https://github.com/thomasklemm/ruby/commit/4b02fa55cbdd548d2aed0b28d8c17f2e112722e5) on master `9b30fd207f`, candidate (first version `a06b86d852`) |
| 3 | No 320 B slot: objects needing 257–320 B (31–38 ivars) take 512 B, +60% | all | `ActiveRecord::ConnectionAdapters::QueryIntent` (31 ivars on a find) on every query: +1,753 B per workload | [`c9b7088364`](https://github.com/ruby/ruby/commit/c9b70883640e59bdd1f2f6a538957119cb558fac) (ruby/ruby#16282, deliberate size table) | none found; gap not discussed in the PR | lead, no fix (GC design) |
| 4 | ZJIT: `f(*a, x)` into a rest parameter allocates one more Array than the interpreter | ZJIT only | `URI.parse` per request: Campfire +123 to +184 objects/op, Writebook up to +71 | predates ruby/ruby#18267; not a 4.0.7 → 4.1 regression | none found | lead, no fix |

No PR, Redmine issue or comment was opened.

## Pins and method

* **Ruby:** 4.0.7 (`229531a6cf`, mise) and master
  [`b51db981f6`](https://github.com/ruby/ruby/commit/b51db981f642115e0d77f4a926c7f0209f4871ab)
  (2026-11-02, `ruby 4.1.0dev (2026-11-02T20:50:33Z HEAD b51db981f6) +PRISM [x86_64-linux]`), configured
  `--enable-yjit --enable-zjit --disable-install-doc`, GCC 12.2.0, rustc 1.99.1. It is 593 commits past
  4.1.0-preview1. For instruction counts, 4.0.7 was also built here from `v4.0.7` with the same compiler and
  `--enable-yjit --disable-install-doc` (`4.0.7-local`).
* **Rails:** canonical main [`b5be03636e`](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953),
  the census 4 pin, so Rails is constant and only Ruby changes.
* **Apps and data:** the census 4 apps, pins, seeds, fixtures and workloads unchanged
  ([census 4](rails-main-census-4.md#apps)): Blog, Campfire, Writebook, Fizzy (SQLite and MySQL 8.4.10), CodeTriage
  and PingCRM (PostgreSQL 15), Redprints CFP, React starter kit, Lobsters. 97 workloads per mode.
* **One bundle for both Rubies.** Each app copy has a single lockfile that both Rubies install, so gem versions are
  identical between the columns (see [Overlays](#overlays-gems-that-do-not-build-on-master)).
* **Harness:** [`rails_main_census_4.rb`](../../bench/upstream/rails_main_census_4.rb), extended with a `zjit` mode,
  GC counters per window, traced bytes per site (`ObjectSpace.memsize_of`, slot plus out-of-slot storage), an optional
  long GC window (`CENSUS_GC_OPS`, with `CENSUS_GC_MAJOR_BY` also recording each major's `major_by` and the heap that
  forced it) and an optional Callgrind window (`CENSUS_CALLGRIND_EXT`, the existing
  [`bench/callgrind.c`](../../bench/callgrind.c)). Warmup, windows and tracing are as in census 4. Comparison:
  [`ruby_41_watch_compare.rb`](../../bench/upstream/ruby_41_watch_compare.rb) (workloads and sites, gem paths
  normalized across the 4.0.0 / 4.1.0+6 ABI directories),
  [`ruby_41_watch_callgrind.rb`](../../bench/upstream/ruby_41_watch_callgrind.rb),
  [`ruby_41_watch_gc.rb`](../../bench/upstream/ruby_41_watch_gc.rb). Run scripts, overlays and repros:
  [fixtures/corpus/ruby-41-watch](../../fixtures/corpus/ruby-41-watch).
* **A/A:** two full independent runs per Ruby and mode (`r407a/b`, `rmasa/b`). Median objects per workload are
  identical between A and B in every mode on both Rubies (A/A median delta +0.0, +0.00%). A workload or site counts
  as moved only when its delta exceeds twice the larger of the two A/A spreads and at least 2 objects (1 KiB for
  bytes).
* `script/census` (Lowrail main 65b110d) arrived after these copies were prepared and smoke-tested on both Rubies, so
  this run stays on the census 4 harness; `script/census` needed no fixes from this work.

## Results per app

Median change per workload, master − 4.0.7, averaged over the A/A pairs. Objects are GC-enabled objects per
operation; bytes are traced bytes per operation.

| App | Workloads | Objects, interp | Objects %, interp | Bytes %, interp | Objects, YJIT | Objects %, YJIT | Bytes %, YJIT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Blog | 10 | −7.5 | −0.82% | −16.7% | −15.8 | −0.86% | −16.7% |
| Campfire | 9 | −40.0 | −0.72% | −13.6% | −40.0 | −0.72% | −13.5% |
| CodeTriage (PG) | 7 | −40.3 | −1.24% | −16.6% | −45.9 | −1.57% | −17.2% |
| Fizzy (SQLite) | 14 | −10.0 | −0.21% | −13.8% | −13.0 | −0.21% | −14.0% |
| Fizzy (MySQL) | 14 | **+26.0** | **+0.19%** | −15.3% | **+21.6** | **+0.15%** | −15.6% |
| Lobsters | 11 | −216.6 | −2.59% | −15.7% | −218.8 | −2.59% | −15.5% |
| PingCRM (PG) | 8 | −26.4 | −0.87% | −17.5% | −28.8 | −0.99% | −17.8% |
| Redprints | 8 | −35.1 | −1.62% | −15.1% | −35.5 | −1.66% | −15.3% |
| React starter kit | 8 | −26.9 | −1.21% | −13.5% | −27.4 | −1.23% | −14.2% |
| Writebook | 8 | −82.1 | −1.65% | −13.7% | −80.4 | −1.65% | −13.9% |
| **All 97** | 97 | **−31.1** | **−0.99%** | **−15.2%** | **−33.9** | **−1.13%** | **−15.3%** |
| A/A (both Rubies) | 97 | +0.0 | +0.00% | +0.0% | +0.0 | +0.00% | +0.0% |

Workloads moved beyond A/A: interpreter 11 more / 78 fewer objects, YJIT 9 / 81. The 11 that allocate more are
all Fizzy pages and jobs whose extra keyword-splat Hashes (finding 1) outweigh the savings. ZJIT on master against
4.0.7 YJIT: median −41.0 objects (−1.36%), −15.3% bytes; against master YJIT: median −8.0 objects, bytes +0.2%,
with Campfire +123 to +184 per workload from finding 4.

**Instructions.** Callgrind on the interpreter, one 10-operation window per workload after warmup, A/A pair per Ruby
([`ruby_41_watch_callgrind.rb`](../../bench/upstream/ruby_41_watch_callgrind.rb); `no_gc` subtracts the operations'
GC). mise's 4.0.7 is a prebuilt binary from another toolchain (GCC 10.2.1), and that alone moves counts by 1.5%, so
4.0.7 was rebuilt here with master's GCC 12.2.0 and configure flags (`cg407la/b`):

| Comparison | Median | Geomean | A/A median | Slower / faster beyond A/A |
| --- | ---: | ---: | ---: | ---: |
| 4.0.7 (same compiler) → master, no GC | **−0.68%** | −0.79% | 0.14% | 5 / 34 |
| 4.0.7 (same compiler) → master, with GC | −0.63% | −0.83% | 0.15% | 4 / 32 |
| 4.0.7 mise binary → master, no GC | +1.07% | +0.80% | 0.14% | 49 / 10 |
| 4.0.7 mise binary → 4.0.7 built here | +1.53% | +1.61% | 0.16% | 78 / 0 |

Master runs fewer interpreter instructions than 4.0.7. The apparent +1% against the mise binary is the compiler, not
Ruby. The largest same-compiler increases are about +1.3% (Fizzy and Fizzy MySQL `NotifyRecipientsJob`, CodeTriage
home, the React starter kit's invalid profile PATCH), within the range this window resolves, so none is a finding.

**GC.** One 1,000-operation GC-enabled window per workload, run alone, two runs per Ruby (`gc407a/b`,
`gcmasa/b`), summed over the 97 workloads ([`ruby_41_watch_gc.rb`](../../bench/upstream/ruby_41_watch_gc.rb)):

| Per 1k ops, all workloads | 4.0.7 A / B | master A / B | Change |
| --- | ---: | ---: | ---: |
| Major GCs, interp | 41 / 36 | 93 / 93 | **+142%** |
| Major GCs, YJIT | 37 / 39 | 95 / 102 | **+159%** |
| All GCs, interp | 1,065 / 771 | 1,086 / 1,096 | +19% (A/A noisy) |
| All GCs, YJIT | 802 / 809 | 1,129 / 1,117 | **+39%** |
| GC time, YJIT | 34.4 / 34.6 s | 37.9 / 39.3 s | +12% (wall clock) |
| GC time, interp | 34.7 / 33.2 s | 34.5 / 33.9 s | +1% |

Master runs more collections in both runs than 4.0.7 in either on 74 (interp) and 76 (YJIT) of 97 workloads, fewer
on 3. That is finding 2.

## 1. Keyword splat after dynamic keywords allocates a second Hash

```ruby
def m(**kw) = kw
v = 2
h = {}
m(a: v, **h)   # 4.0.7: 1 Hash. master: 2 Hashes (interpreter, YJIT, ZJIT)
m(a: 1, **h)   # 1 Hash on both: a static value compiles differently
class P; def d(e, url_safe: false) = e; end
class C < P; def d(e, url_safe: true) = super; end
C.new.d(1)     # 4.0.7: 1 Hash. master: 2
```

[`repro/kwsplat.rb`](../../fixtures/corpus/ruby-41-watch/repro/kwsplat.rb) prints objects per call;
[`repro/kwsplat_min.rb`](../../fixtures/corpus/ruby-41-watch/repro/kwsplat_min.rb) exits non-zero on the regression
and drove the bisect.

**Where Rails apps hit it.** Lines whose Hash count exactly doubled, summed over all 97 workloads (interpreter):

| Objects/op, all workloads | Site | Shape |
| ---: | --- | --- |
| 1,053 | AS `event_reporter.rb:525` `debug` | `notify(name, payload, caller_depth: caller_depth + 1, filter_payload:, **kwargs)` |
| 1,007 | AS `structured_event_subscriber.rb:93` `emit_debug_event` | `event_reporter.debug(name, payload, caller_depth: caller_depth + 1, filter_payload: false, **kwargs)` |
| 844 | importmap-rails `importmap_tags_helper.rb:44` | `tag.link rel: "modulepreload", href: path, nonce:, **options` |
| 266 | Fizzy `application_helper.rb:10` `icon_tag` | `tag.span class: …, "aria-hidden": true, **options` |
| 234 | AR `singular_association.rb:52` | zsuper with keywords |
| 124 | AS `structured_event_subscriber.rb:86` | `emit_event(…, **kwargs)` |
| 106 | AS `message_verifier.rb:337` `decode` | `def decode(encoded, url_safe: @url_safe) … super` (zsuper) |
| 58, 52, 52, 43 | AP `url_for.rb:37`, AR `timestamp.rb:129`, AS `number_converter.rb:202/206`, AR `query_cache.rb:274` | `**options` after keywords |

94 of 97 workloads, in all nine apps, allocate extra Hashes from this; median 9, mean 43.7 per operation (about
0.7% of all objects), Fizzy's board page 394. Every Rails structured event that goes through `emit_debug_event`,
every `tag.*` call that forwards `**options` after literal options, and every zsuper from a method with keyword
parameters pays one more Hash.

**Bisect.** `git bisect run` over master `d375bcc965`..`b51db981f6` (7,176 commits, miniruby, interpreter) with
`kwsplat_min.rb`: first bad commit
[`f01bf185f6`](https://github.com/ruby/ruby/commit/f01bf185f67ab13e626a270a510b0b37a59c6a0c) "Refactor
core_hash_merge_ptr and core_hash_merge_kw" (byroot, ruby/ruby#18344, merged 2026-08-15).

**Cause.** #18344 split the VM's hash merges into copying (`core#hash_merge_kwd`, `core#hash_merge_ptr`) and in-place
(`…_bang_…`) variants, so that a literal hash can start from a hidden constant hash and be allocated right-sized
once. The prism compiler tracks `owned_hash` to pick the in-place variant, but never sets it after a dynamic first
chunk compiled with `newhash`, so `newhash 1; …; core#hash_merge_kwd` copies the hash it just built. The prism
zsuper path still emits the copying `core#hash_merge_ptr` on its own `newhash`/`dup` (`compile.c` was switched to the
bang variant there; `prism_compile.c` was not), and the single-keyword-splat paths in both compilers copy their own
`newhash 0`. In 4.0.7 these merges were all in place.

**Fix.** [`e5e20a5207`](https://github.com/thomasklemm/ruby/commit/e5e20a52076396271de600e735d95716bfd2c086) on
[`thomasklemm/kwsplat-fit-merge`](https://github.com/thomasklemm/ruby/tree/thomasklemm/kwsplat-fit-merge) (one commit
on master `b51db981f6`, Thomas Klemm as author and committer, no trailers; 7 files, +39 −9):

* `vm.c`, `hash.c`, `defs/id.def`: a new `core#hash_merge_fit_kwd` for a hash the compiler just built with
  `newhash`. It merges the splat in place when the result fits the hash's embedded table, and otherwise copies into a
  right-sized hash exactly as `core#hash_merge_kwd` does. It never converts to an st_table: `newhash N` is sized for
  N entries in 4.1's variable slots, and an in-place merge that overflows is about 50% slower per call than the copy
  (`m(a:, b:, c:, **{k: 1})` 204 → 304 ns), the same trade-off that got #59108 reverted.
* `prism_compile.c`: use it after a `newhash` first chunk and for the single keyword splat; zsuper without a keyword
  rest builds its keywords with `newhash` directly instead of `newhash 0` plus a copying merge. `compile.c`: the same
  for its single keyword splat (its other paths already merge in place on master).
* `test/ruby/test_allocation.rb`: `keyword_splat(a: nill, **empty_hash)` and the keyword-and-keyword-splat variant
  expect one Hash (8 assertions fail on unpatched master, pass with the fix), and `keyword_splat(a: 2, b: nill,
  **hash1, c: nill)` expects one Hash, which master already does and the first fix attempt broke (below).

Objects per call ([`repro/kwsplat_shapes.rb`](../../fixtures/corpus/ruby-41-watch/repro/kwsplat_shapes.rb); the same
counts under the interpreter, YJIT and ZJIT; `--parser=parse.y` is unchanged from master):

| Call | 4.0.7 | master | fix |
| --- | ---: | ---: | ---: |
| `m(a: v, **{})`, `m(a: v, **{k: 1})` | 1 | 2 | **1** |
| `m(raise: v, **{}, default: d)`, `m(a: v, **{}, **{})`, `{a: v, **{}, b: d}` | 1 | 2 | **1** |
| zsuper with keywords | 1 | 2 | **1** |
| `m(count: 1, raise: v, **h, default: d)` (static first pair) | 1 | 1 | 1 |
| `m(a: v, b: v, c: v, **{k: 1})`, `m(a: v, **h7)` (result does not fit: copy) | 1 | 2 | 2 |
| zsuper from a method with `**kw` | 2 | 3 | 3 |

The fix is never above master and returns the fitting cases to 4.0.7's count. It leaves the overflow case:
4.0.7's `newhash` always had room for 8 pairs (160 B), while 4.1 sizes it exactly, so a splat that adds entries
beyond the embedded table has to copy. Closing that would mean sizing the first hash for the splat before
allocating it, with a core merge that takes the pairs and the splat together, in both compilers. That is a design
change for the maintainers, not a small exact patch. In the census it is rare (below). zsuper with a keyword rest keeps
master's `dup` plus copy, because a method can reassign its `**kw` local before `super`.

Timing ([`repro/kwsplat_time.rb`](../../fixtures/corpus/ruby-41-watch/repro/kwsplat_time.rb), interpreter, pinned
core, median of 5 × 2M calls, two alternating rounds, beside the GC census, so treat ±5% as noise):

| Call | master | fix |
| --- | ---: | ---: |
| `m(a:, b:, c:, **{})` | 159–162 ns | **116–117 ns** |
| `m(a: v, **{k: 1})` | 171–175 ns | **126–128 ns** |
| zsuper with keywords | 159–161 ns | **121–129 ns** |
| `m(a:, b:, c:, **{k: 1})` (copy) | 202–203 ns | 202–206 ns |
| `m(a: v, **{k1..k3})` (copy) | 241–244 ns | 243–245 ns |
| `m(a: v, **h7)` (copy) | 336–354 ns | 341–344 ns |

The caller's `**h` is never mutated (checked in the repros).

**First attempt, superseded.**
[`e313932657`](https://github.com/thomasklemm/ruby/commit/e313932657038f27762b932b3b607b785783e2c1) on
`thomasklemm/kwsplat-owned-newhash` marked `newhash` results as owned and put the overflow guard into the shared
in-place merges. The census of that build caught a new regression: the guard also copied hashes that master's own
in-place paths merge into (a `hash_merge_ptr` copy sized exactly, then `**h`, then another pair), so
`I18n.translate(key, count: 1, raise: v, **options, default: defaults)` (ActiveModel `translation.rb:85`) went from 1
Hash to 2–3, +26 Hashes/op on Blog's invalid-article page. The current fix confines fit-or-copy to the fresh
`newhash` that the new core method receives. The old branch is left as is; use `kwsplat-fit-merge`.

**Census of the fix** (`rfita/b` against `rmasa/b`, same harness and app copies,
[receipts](data/ruby-41-watch/receipts.tar.gz)):

| Mode | Objects/workload, median | Workloads with fewer / more objects (beyond A/A) |
| --- | ---: | ---: |
| Interpreter | −9.1 | 65 / 0 |
| YJIT | −7.6 | 65 / 0 |
| ZJIT (one run) | −8.5 | 75 / 0 |

Hashes per operation summed over all 97 workloads (interpreter): 4.0.7 78,103, master 81,992, fix **77,840**. The
median workload is back at 4.0.7's Hash count (master +9). The structured-event, importmap, `icon_tag`, zsuper and
`url_for` sites all return to one Hash per call. Two overflow sites stay doubled: `number_converter.rb:202` (+52
Hashes summed) and `timestamp.rb:129` (+16.5). Instruction counts are unchanged. The first fix build (`cgfixa/b`) was
at median −0.01% (A/A 0.13%, no workload beyond A/A). The current one (`cgfita`, a single run) was at +0.12%, with
Lobsters' home, active and story pages about +1.1%. Rerun back to back with master on a separate Lobsters copy
(`cglobm1`/`cglobf1`), those pages are +0.07%, +0.09% and +0.01%, and every Lobsters workload is within ±0.4%.
Master itself had moved +1.0% on home since its morning run: Lobsters renders relative times.

**Checks on the fix build:** `make btest` (2,141 tests, PASS) and `make test-all` for `test_keyword`, `test_call`,
`test_hash`, `test_super`, `test_allocation`, `test_syntax`, `test_compile_prism`, `test_iseq`, `test_method`,
`test_proc`: 1,311 tests, 0 failures, 0 errors, 8 skips. Fork CI for `e5e20a5207` and `a06b86d852` was still queued when this was
written. On the first attempt (`e313932657`) every job that ran passed except SHSTK `make check`, which fails the same
four `JSONGeneratorTest#test_rfc8785_*` tests on upstream master `b51db981f6` itself.

**Before a PR:** #18344's bot comment says `prism_compile.c` is maintained in ruby/prism, so the prism half may need to
go there (and the `compile.c`/`hash.c`/`vm.c` half to ruby/ruby), or to byroot as a follow-up to his own change. The
maintainers' own benchmark (ruby-bench) was not run.

## 2. Sparse large-slot heaps force `nofree` major GCs

Every major GC on master in the census windows is `major_by: :nofree` (CENSUS_GC_MAJOR_BY pass, interpreter: Lobsters
16, React starter kit 14, Redprints 11, Writebook 9, Campfire 8 …). The few majors on 4.0.7 are `oldmalloc`.
`GC.stat_heap(:force_major_gc_count)` names the heaps. In Lobsters' home page, the 768 B heap (2 pages, 69 live
slots) forced 19 majors and the 640 B heap (9 pages) 6, out of 21. The big, busy heaps forced none. The same probe on
4.0.7 (same copy) ran 0 majors on that page, and no heap forced one on any Lobsters workload; its 6 majors were all
`oldmalloc`.

[`repro/bigslot.rb`](../../fixtures/corpus/ruby-41-watch/repro/bigslot.rb) keeps a 300k-object working set and
allocates garbage plus one 70-element Array (640 B slot on both Rubies) per iteration that lives through a few minor
GCs. Over 40,000 iterations (`RING=200 BIG=70 N=40000`), two runs each:

| Build | `nofree` majors | 640 B heap pages at end |
| --- | ---: | ---: |
| 4.0.7 | 2, 2 | 9, 9 |
| master `b51db981f6` | 26, 29 | 6, 8 |
| master + open ruby/ruby#17251 (rebased) | 18, 25 | 5, 6 |
| master + fix | 3, 3 | 29, 29 |

Under YJIT (one run each): 4.0.7 2, master 35, master + fix 3.

**Bisect.** `git bisect run` over `d375bcc965`..`b51db981f6` (miniruby, exit 0 at ≤ 8 majors, 1 at ≥ 15, skip
between) found [`16da5f23c2`](https://github.com/ruby/ruby/commit/16da5f23c29b6b6e2c464a2f2e3c41e1aba99e1e) "Revert
\"Double sweep byte budget to preserve heap 1 behavior\"", the last of three commits rebase-merged from
[ruby/ruby#16632](https://github.com/ruby/ruby/pull/16632) "Convert incremental sweep budget from slots to bytes"
(Matt Valentine-House, 2026-04-01/02). The PR's first commit (`3938195740`) turned both lazy-sweep budgets
from fixed slot counts (2,048 swept, 1,024 pooled per step) into byte budgets divided by the slot size; `7ddcaa4076`
doubled them and was still good; `16da5f23c2` undid the doubling.

**Cause.** Variants of the two budgets on master, same repro, two ring sizes:

| `sweep_budget` / `pool_budget` per step | `nofree` majors (ring 200, 300) |
| --- | ---: |
| bytes / bytes (master) | 29, 10 |
| 2 × bytes / 2 × bytes (`7ddcaa4076`) | 4, 4 |
| 2,048 slots / 1,024 slots (4.0.7) | 3, 5 |
| bytes / **1,024 slots** | **3, 5** |
| 2,048 slots / bytes | 21, 10 |

The pool budget alone decides it. Each sweep step hands its first pages to the heap's pool (`heap_add_poolpage`) until
`pool_budget` slots are pooled, then the rest to the free list. At 40 × 1,024 B ÷ slot size, the 640 B heap's pool
budget is 64 slots and the 768 B heap's 53, less than one page (102 and 85 slots). So the sparse heaps pool a single
page per step. The `nofree` request itself comes from `gc_sweep_finish_heap`: the heap swept fewer than
`min_free_slots`, and more than `RVALUE_OLD_AGE` minors have passed since the last major. How one pooled page leads
there was not traced further; the measured fact is that pooling at least two pages (the doubled budget) or 1,024 slots
removes the extra majors. The PR's
premise ("larger slot pools are less heavily used, so a fixed slot count over-services them") holds for the sweep
budget, which the table shows is harmless here. Applied to the pool it starves exactly the heaps that 4.1's twelve
size classes made sparse.

**Fix.** [`a06b86d852`](https://github.com/thomasklemm/ruby/commit/a06b86d8521df07b8a3327a6cc63b8b512e2f170) on `thomasklemm/gc-pool-budget-slots` (one commit on master `b51db981f6`, Thomas Klemm as author and
committer, no trailers; `gc/default/default.c`, +4 −3): restore the slot-count pool budget
(`GC_INCREMENTAL_SWEEP_POOL_SLOT_COUNT 1024`) and keep #16632's byte sweep budget.

**Census of the fix** (`gcpoola/b`, same GC windows, run alone; sums over the 97 workloads per 1k ops):

| | 4.0.7 A / B | master A / B | master + fix A / B |
| --- | ---: | ---: | ---: |
| Major GCs, interp | 41 / 36 | 93 / 93 | **18 / 17** |
| Major GCs, YJIT | 37 / 39 | 95 / 102 | **10 / 17** |
| Minor GCs, interp | 1,024 / 735 | 993 / 1,003 | 1,181 / 1,160 |
| Minor GCs, YJIT | 765 / 770 | 1,034 / 1,015 | 1,163 / 1,154 |
| GC time, interp | 34.7 / 33.2 s | 34.5 / 33.9 s | **28.3 / 27.8 s** |
| GC time, YJIT | 34.4 / 34.6 s | 37.9 / 39.3 s | **29.6 / 28.4 s** |
| RSS growth per window, YJIT | −602 / −649 MB | +12 / +8 MB | +249 / +240 MB |

Against master the fix lowers majors on 30–31 workloads and raises them on at most 1, and GC time falls 18%
(interp) and 25% (YJIT), below 4.0.7. It trades memory: RSS grows about 2.3 MB more per workload over a 1,000-op
window than on master in both modes (summed: interp −114 / −97 MB → +109 / +123 MB, YJIT +12 / +8 → +249 / +240 MB),
because fewer majors run. That is about 1% of a Rails process and is the trade-off the maintainers would have to
weigh with their RSS benchmarks. Minor GCs stay 15–50% above 4.0.7 with or without the fix; with the fix their cost is
below 4.0.7's, so they were not bisected (see Limits).

**Checks on the fix build:** `make btest` (2,141 tests, PASS) and `make test-all` for `test_gc`, `test_gc_compact`,
`test_objectspace`, `objspace`, `test_weakmap`, `test_hash`, `test_array`, `test_string`: 1,537 tests, 0 failures.

**Sweep steps with the fix (2026-11-03, master `9b30fd207f`).** The fix was held back because a deterministic loop
model predicted much larger lazy-sweep steps: pooled pages do not count toward a step's sweep budget, so a step in a
large-slot heap keeps sweeping until it has pooled 1,024 slots. I measured the steps directly with a build of
`b51db981f6` instrumented to time every `gc_sweep_step` and every sweep continuation triggered by allocation
([`gcstep/gcstep.patch`](../../fixtures/corpus/ruby-41-watch/gcstep/gcstep.patch), not for upstream; the pool
budget is chosen at run time by `RUBY_GC_POOL_MODE`, so both variants run the same binary). Census windows as above
(1,000 requests per workload, 97 workloads in ten apps), master's byte pool budget against the fix:

| | Interpreter, master | Interpreter, fix | YJIT, master | YJIT, fix |
| --- | ---: | ---: | ---: | ---: |
| Major GCs | 86 | 13 | 98 | 26 |
| GC time (`GC.stat(:time)`) | 32.4 s | 27.6 s | 34.5 s | 26.6 s |
| RSS growth per workload window | −2.1 MB | +1.2 MB | +0.6 MB | +2.3 MB |
| Sweep pause per allocation, p99 / max | 2.17 / 23.1 ms | 2.25 / 24.6 ms | 1.97 / 22.9 ms | 2.21 / 23.8 ms |
| One step in a heap of 512 B+ slots, p99 / max | 0.72 / 2.3 ms | 0.85 / 2.0 ms | 0.66 / 2.1 ms | 1.01 / 2.2 ms |
| Pages in that step, p99 / max | 126 / 283 | 169 / 272 | 119 / 271 | 114 / 276 |

A second round on seven of the apps repeats it (majors interpreter 54 → 13, YJIT 60 → 14; GC time −18% and −22%;
pause p99 2.38 → 2.39 ms and 2.40 → 2.31 ms). The worst single app for step length is fizzy on MySQL: one step in the
large-slot heaps went from 0.3 to 1.6–1.8 ms at p99, with its maximum unchanged at about 2 ms. The allocation pause
users see is the sweep continuation; its p99 rises 4% (interpreter) and 12% (YJIT) and its maximum stays about the
same (23 → 25 ms and 23 → 24 ms). The 6–9× of the loop model did not show up in these apps.

Middle grounds, same run (interpreter / YJIT majors, eight and seven apps that all variants completed): pool twice
the byte budget 56 / 56, at least two pages 42 / 31, 1,024 slots capped at eight pages 11 / 12, against 70 / 67 on
master and 7 / 14 with the fix. The cap did not shorten steps consistently (pause p99 2.23 vs 2.10 ms interpreter, 2.29 vs
2.48 ms YJIT; one large-slot step at p99 0.85 vs 0.85 ms and 0.88 vs 0.74 ms), and the doubled byte budget, which fixes the repro (4 majors), leaves most of the Rails majors. So
the fix stays the plain 1,024-slot pool.

ruby-bench (`73918b2`, 15 warm-up and 40 measured iterations, each variant run alone, one run each), master against
the fix:

| Benchmark, mode | Major GCs | GC time | Peak RSS | Sweep pause p99 / max |
| --- | ---: | ---: | ---: | ---: |
| railsbench, interpreter | 0 → 0 | 3.25 → 2.99 s | 105 → 107 MB | 1.62 → 1.82 / 2.4 → 5.7 ms |
| lobsters, interpreter | 0 → 0 | 1.34 → 1.35 s | 288 → 269 MB | 0.87 → 1.00 / 1.3 → 1.3 ms |
| shipit, interpreter | 25 → 6 | 3.48 → 2.77 s | 146 → 158 MB | 0.65 → 0.85 / 1.2 → 1.9 ms |
| railsbench, YJIT | 1 → 0 | 3.01 → 2.98 s | 132 → 131 MB | 2.41 → 2.11 / 3.8 → 3.2 ms |
| lobsters, YJIT | 0 → 0 | 1.38 → 1.28 s | 338 → 305 MB | 0.91 → 1.10 / 1.3 → 1.5 ms |
| shipit, YJIT | 27 → 5 | 4.11 → 2.83 s | 193 → 210 MB | 0.66 → 0.85 / 1.1 → 1.8 ms |

Railsbench and lobsters run at most one major GC on either build, so the fix changes little there; shipit has the
regression and loses most of its majors for 12–17 MB more peak RSS. Sweep pauses grow by at most 0.3 ms at p99. The
single 5.7 ms railsbench maximum is one pause and did not recur under YJIT.

Method notes: the five variants first ran in parallel per app; apps that write shared state (Writebook, React starter
kit, fizzy on MySQL under YJIT, ruby-bench lobsters' file cache) broke each other, so those were rerun one variant at a
time against a freshly loaded database. A sqlite3 gem finalizer deadlock at process exit was killed after the JSON was
written. Scripts: [`gcstep/`](../../fixtures/corpus/ruby-41-watch/gcstep/).

**Rebased fix.** [`thomasklemm/gc-pool-budget`](https://github.com/thomasklemm/ruby/tree/thomasklemm/gc-pool-budget)
@ [`4b02fa55cb`](https://github.com/thomasklemm/ruby/commit/4b02fa55cbdd548d2aed0b28d8c17f2e112722e5), one commit on
master `9b30fd207f` (2026-11-03); `gc-pool-budget-slots` stays as the record of the first version. On `9b30fd207f`
the repro still runs 27–28 `nofree` majors (three runs) against 2 on 4.0.7, and 3 with the fix, whose 640 B heap
ends at 24–29 pages. `test_gc`, `test_gc_compact` and `objspace` pass (206 tests, 0 failures, the same 10 skips as
master), and `make btest` passes 2,141 tests. Candidate only: no ruby/ruby PRs open for now (DECISIONS, 2026-11-03).

**Explanation for Thomas.** When Ruby sweeps lazily, each small sweep step puts some freed pages aside in a reserve
(the pool) instead of handing them straight to allocation. Ruby 4.0 reserved 1,024 objects' worth per step in every
heap; master reserves a fixed number of bytes, which in the heaps for big objects (640 and 768 bytes each, for example
an Array of about 70 elements) is less than one page. Those heaps then stay at 5–6 pages, and when big objects survive
a few GCs and then die, the GC finds too little free room there and runs a full major GC instead of growing the heap:
27 times in the 40,000-iteration script, 2 times on 4.0.7. The fix puts back 4.0's 1,024-slot reserve and keeps
master's byte-based sweep budget, so the reserve returns to a value 4.0 shipped with; the GC tests and btest pass. The
cost is a bigger heap (a few MB per Rails process) and sweep steps in the big-object heaps that are somewhat longer at
the 99th percentile, while the longest pauses stay the same.

**Draft ruby/ruby body (not opened).**

> On master, heaps with large slots (640 and 768 bytes) run many more full major GCs than on Ruby 4.0. I traced it to ruby/ruby#16632, which made both lazy-sweep budgets a number of bytes divided by the slot size. For the pool that each sweep step sets aside, this means 64 slots for 640-byte slots and 53 for 768-byte slots, less than one page. These heaps then stay small, sweeping finds too few free slots in them, and the GC runs a major GC with reason `nofree` instead of growing them. The script below keeps 70-element arrays (640-byte slots) alive across a few minor GCs. In 40,000 iterations it runs 2 major GCs on Ruby 4.0.7 and 27 to 28 on master.
>
> This PR keeps the byte budget for sweeping and pools 1,024 slots per step in every heap, as Ruby 4.0 did. The script then runs 3 major GCs.
>
> I measured it in ten open-source Rails apps on Rails main, over 97 workloads of 1,000 requests each, master against this branch. Major GCs went from 86 to 13 with the interpreter and from 98 to 26 with YJIT. Total GC time fell 15% and 23%. In ruby-bench, shipit went from 25 to 6 major GCs (interpreter) and 27 to 5 (YJIT), with 20% and 31% less GC time. Railsbench and lobsters run at most one major GC on either build and barely change.
>
> There are two costs. Memory: the 640-byte heap in the script ends with 24 to 29 pages instead of 5 or 6. The apps' resident memory grew 1.7 to 3.3 MB more per workload, and shipit's peak RSS rose 12 to 17 MB. Sweep steps: a single step in a large-slot heap takes longer, 19% (interpreter) and 53% (YJIT) at the 99th percentile, and up to 0.3 → 1.7 ms in one app. The sweep pause an allocation sees grew 4% and 12% at the 99th percentile, and the longest pause stayed at 23 to 25 ms. In ruby-bench that pause grew by at most 0.3 ms at the 99th percentile.
>
> ruby/ruby#17251 also changes when these heaps force a major GC. Rebased onto master, it reduces the majors in the script but does not remove them.
>
> <details><summary>Script</summary>
>
> ```ruby
> # RING=200 BIG=70 N=40000 ruby bigslot.rb
> keep = Array.new(300_000) { |i| i.even? ? "k#{i}" : [i] }
> big = Integer(ENV.fetch("BIG", "90"))
> ring = Array.new(Integer(ENV.fetch("RING", "300"))); pos = 0
> iter = -> { 2000.times { |i| "s#{i}"; [i, i] }; ring[pos] = Array.new(big, 0); pos = (pos + 1) % ring.size }
> 2000.times { iter.() }; GC.start
> heap_of = -> { GC.stat_heap.values.find { |h| h[:slot_size] >= big * 8 + 16 } }
> m0 = GC.stat(:major_gc_count)
> by = Hash.new(0)
> Integer(ENV.fetch("N", "20000")).times do
>   m = GC.stat(:major_gc_count)
>   iter.()
>   by[GC.latest_gc_info(:major_by)] += 1 if GC.stat(:major_gc_count) != m
> end
> heap = heap_of.()
> puts format("%s: %d major %p; %d B heap: %d pages", RUBY_VERSION, GC.stat(:major_gc_count) - m0, by,
>   heap[:slot_size], heap[:heap_eden_pages])
> ```
>
> </details>

## 3. No 320 B slot: objects of 257–320 B now take 512 B

```ruby
eval "class C34; def initialize; #{(0...34).map { "@i#{_1} = #{_1}" }.join("; ")}; end; end"
C34.new   # 34 ivars, 288 B needed. 4.0.7: 320 B slot. master: 512 B slot
```

[`repro/slot34.rb`](../../fixtures/corpus/ruby-41-watch/repro/slot34.rb) exits 1 when the object lands above
320 B; [`repro/slot_gaps.rb`](../../fixtures/corpus/ruby-41-watch/repro/slot_gaps.rb) prints the size per ivar count:

| Ivars | 3 | 5 | 10 | 14 | 18 | 22–30 | **31–38** | 39–50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4.0.7 | 40 | 80 | 160 | 160 | 160 | 320 | **320** | 640 |
| master | 40 | 64 | 96 | 128 | 160 | 256 | **512** | 512 |

Master's heaps are 32, 40, 64, 80, 96, 128, 160, 256, 512, 640, 768, 1024 B (`gc/default/default.c`
`EACH_POOL_SLOT_SIZE`); 4.0.7's were 40, 80, 160, 320, 640. Everything else gets the same slot or a smaller one, but
an object needing 257–320 B (31–38 ivars, or an embedded Array of 31–38 elements) grows 60%; 39–62 ivars shrink from 640 to 512 B.

**Where Rails apps hit it.** `ActiveRecord::ConnectionAdapters::QueryIntent` has 37 ivar names in
`query_intent.rb`, and a Fizzy `Card.find` sets 31 of them, so every query pays. Warmed up, one find allocates one
QueryIntent of 320 B on 4.0.7 and 512 B on master ([`repro/query_intent.rb`](../../fixtures/corpus/ruby-41-watch/repro/query_intent.rb),
`rails runner` in the Fizzy copy). It is the largest real byte growth in the census: the
`abstract/database_statements` site grows +1,753 B per workload on average (2,922 → 4,675 B, +60%), with an
unchanged object count. Wider models mostly gain: a Fizzy `Card` (24 ivars) goes from 320 to 256 B.

**Bisect.** `git bisect run` with `slot34.rb` over `d375bcc965`..`b51db981f6` (miniruby): first bad commit
[`c9b7088364`](https://github.com/ruby/ruby/commit/c9b70883640e59bdd1f2f6a538957119cb558fac) "Introduce power-of-two
size pools" (Matt Valentine-House, [ruby/ruby#16282](https://github.com/ruby/ruby/pull/16282), in 4.1.0-preview1). The PR picks the
sizes on purpose ("mostly powers of two with a few intermediate sizes to fill gaps where Ruby objects tend to
cluster") and reports lower RSS. Neither the PR nor its review discusses the 256 → 512 gap.

**No fix prepared.** A 320 or 384 B heap is a GC design change: one more heap, a new reciprocal-table entry, more
per-heap growth thresholds, and an RSS trade-off that needs the maintainers' benchmarks. It is not small or exact.
Recorded as a lead for #16282's authors, with QueryIntent as the Rails case. Rails could avoid it on its own side by
keeping QueryIntent at 30 ivars or fewer (256 B), for example by moving rarely set fields into a lazily built object.

## 4. ZJIT: caller splat into a rest parameter allocates one more Array

```ruby
module U; def self.for(scheme, *arguments, default: nil) = scheme; end
def split(s) = [s, 1, 2]
def parse(s) = U.for(*split(s), self)   # URI::RFC3986_Parser#parse
# objects per call: interpreter 3, YJIT 3, ZJIT 4 (master); U.for(*split(s)) is 3 everywhere
```

[`repro/splat_tail.rb`](../../fixtures/corpus/ruby-41-watch/repro/splat_tail.rb). The interpreter reuses the
mutable `splatarray true` + `pushtoarray` Array as the callee's rest Array (`ARGS_SPLAT_MUT`); ZJIT builds a fresh
one. In the census this is uri's `rfc3986_parser.rb:135` under ZJIT, one Array per `URI.parse`: Campfire +123 to +184
objects per workload, Writebook's books page +71 (against master YJIT). The `caller_splat_optimized` counter fires on this call.
It is **not** a 4.0.7 → 4.1 regression: miniruby `--zjit` builds at ruby/ruby#18267's merge
(`11d6a46a42`, "Specialize caller splats with monomorphic lengths") and at its parent (`1d3b0594d4`) both allocate 4,
and 4.0.7's ZJIT was experimental and not built here. Recorded as a ZJIT lead for the next JIT pass; no report or fix.

## Improvements on 4.1

* **Bytes:** −15% traced bytes per workload in every app and mode (A/A exact). The new allocator has twelve slot
  sizes from 32 B instead of five from 40 B (`GC.stat_heap`): an empty Object is 32 B (was 40), a one-pair Hash
  64 B (was 160), a 100-byte String 128 B (was 160).
* **`Symbol#to_s` returns a frozen String** ([Feature #22137](https://bugs.ruby-lang.org/issues/22137)), 1 → 0
  objects. Most of Lobsters' −217 objects/op (i18n `fallbacks.rb:60` `locale.to_s != fallback.to_s` alone is −260
  on its story page) and broad Rails savings: `attribute_registration.rb:125` `name.to_s`, `navigation_helper.rb`,
  `request_forgery_protection.rb:909`. Mutating the result now raises `FrozenError` (4.0.7 only warns under
  `-W:deprecated`); no census workload did.
* **`lib/time.rb`:** `Time.iso8601` 16 → 4 objects; `Time.httpdate` unchanged at 17.
* **Pathname:** `Pathname#join` 34 → 28 objects.
* **Interpreter instructions:** −0.68% median per workload against 4.0.7 built with the same compiler (34 workloads
  faster, 5 slower beyond A/A; see [Results](#results-per-app)).

## Rejected, with reasons

* **Line moves and attribution shifts** dominate raw site diffs: `time.rb:387 → 390`, `<internal:marshal>:34 → 35`,
  `<internal:pathname_builtin>`, `net/http.rb:1682 → 1708`, YJIT's `<internal:array>:246 → 245`, and
  ConditionVariables now attributed to `<internal:thread_sync>` instead of `monitor.rb`. Matching counts on both
  sides, not regressions.
* **`Marshal.load(Time)` +1** in a first micro probe: a traced load allocates the same 5–6 Strings, Time and
  `Time::tm` on both; the extra object came from the probe.
* **Gem binaries capped at `< 4.1.dev`** (ffi, herb, nokogiri, sqlite3, pg, commonmarker) and three source builds
  (below): gem packaging, not Ruby regressions.
* **Hash-sizing spills (#18345 class) elsewhere:** apart from QueryIntent (finding 3), no site shows byte growth
  without a matching object change beyond A/A; the other large byte increases are kwsplat lines and attribution
  shifts.
* **+1.07% interpreter instructions** against mise's 4.0.7: a toolchain difference (prebuilt with GCC 10.2.1). With
  the same compiler master is −0.68%.
* **Struct with 3 members 40 → 64 B** (`Filters::Environment` in callbacks too): deliberate, stated in
  [`40f105bd55`](https://github.com/ruby/ruby/commit/40f105bd55) "Change RStruct to match SHAPE_ID_LAYOUT_EXTENDED".
* **Regexp `memsize_of` 522 → 994 B:** accounting. RSS per retained Regexp grows 690 → 731 B
  ([`repro/regexp_rss.rb`](../../fixtures/corpus/ruby-41-watch/repro/regexp_rss.rb)).
* **A standalone mixed-heap GC loop** (not kept): `nofree` majors on both Rubies depending on
  run length, so it was dropped for `bigslot.rb`, whose counts repeat.
* **Fork CI on the fix branches:** the SHSTK `make check` job fails four `JSONGeneratorTest#test_rfc8785_*` tests that
  fail the same way on upstream master `b51db981f6`.

## Overlays: gems that do not build on master

Dependency-only, recorded per app in [fixtures/corpus/ruby-41-watch](../../fixtures/corpus/ruby-41-watch) as patches
on top of the census 4 overlays. Both Rubies use the resulting lockfile.

* **Source platform** (`force_ruby_platform: true`) for gems whose `x86_64-linux` binaries require `< 4.1.dev`:
  ffi 1.17.4 (1.17.2 in Campfire), herb 0.11.1, nokogiri 1.19.4, sqlite3 2.9.5/2.9.6/2.10.1, pg 1.6.3/1.7.0,
  commonmarker. Adds mini_portile2 2.8.9.
* **Lobsters:** commonmarker 2.6.3 → 2.10.1 (2.6.3's rb-sys 0.9.124 fails on master: `struct rb_matchext_struct` is no
  longer in the public headers); stackprof 0.2.27 → 0.2.28 (0.2.27's extconf requires
  `rb_postponed_job_register_one`, removed with the old postponed-job API, Feature #21768).
* **Writebook:** redcarpet 3.6.0 → 3.6.1 (3.6.0 uses `Data_Get_Struct`, removed with untyped data objects, Feature
  #21768; 3.6.1 uses TypedData).
* `ruby file: ".ruby-version"` is commented out in CodeTriage, Fizzy, Lobsters and Writebook so one bundle serves both
  Rubies. Master installs Bundler 4.0.20 to match the lockfiles (its default is 4.1.0.beta3).

## Limits

* Allocation, instruction and GC counts only; no request latency or throughput is claimed. The kwsplat timings are
  microbenchmarks.
* Minor GCs run 15–50% more often on master than on 4.0.7, with or without the pool fix (master releases fewer heap pages
  per window: −7.7k against −16k summed). With the fix their total cost is below 4.0.7's, so this was
  not bisected.
* Local tests for the fixes are `make btest` and the listed `test-all` files. The full `make check` runs on fork CI,
  which was still queued for the current fix commits.
  No ruby-bench run.
* Runs on the same app copies were serialized, because workload setup deletes census rows. A first Callgrind label and
  a first GC-window pass overlapped other runs, so they were discarded and rerun alone. One 25-second Blog Callgrind
  probe overlapped master run B's Blog workloads; their deltas are within the usual per-workload A/A range. Builds,
  microbenchmarks and test runs did run beside the census. That affects only wall-clock numbers (the timing tables and
  GC milliseconds), not object, GC or instruction counts.
* Some pages render relative times (Lobsters' `how_long_ago`), so their instruction counts drift through the day
  (Lobsters home +1.0% between master runs hours apart). The 4.0.7 rebuild (`cg407la/b`) ran about two hours after
  master's pair, so on such pages drift inflates 4.0.7 and overstates master's advantage. Without Lobsters the median
  is −0.61% over 86 workloads (−0.68% with it). The kwsplat fix's
  Lobsters numbers were rerun side by side.
* The fix census for the pool budget (`gcpoola/b`) shared the orb with a Callgrind A/B and the fix's own tests for
  part of run A, which touches only GC milliseconds (wall clock), not counts.
* mise's 4.0.7 is a precompiled binary (GCC 10.2.1, Red Hat). For instruction counts, 4.0.7 was rebuilt here with the
  same GCC 12.2.0 and configure flags as master; allocation and GC counts do not depend on the compiler.
* Redmine's API and pages returned HTTP 403 from the orb; existing reports were searched through GitHub (ruby/ruby,
  ruby/prism PRs and issues) and web search.
* Receipts: [data/ruby-41-watch/receipts.tar.gz](data/ruby-41-watch/receipts.tar.gz) holds every compare output and
  each run's JSON trimmed to the top 50 sites per workload (no sites for GC and Callgrind runs). Full receipts stay under
  `.lowrail/private/ruby-41-watch/`.
