# R7: refilling the Rails queue from census 7's narrower tiers

Bet R7 (2026-11-03). Census 7 found no exact candidate left among the lines that reach 7 or more apps. This round
looks for exact candidates in its 3–6-app and 2-app tiers, and in the Rails lines that matter in only one big app
(Discourse, Mastodon, Chatwoot, Sure). Candidates were first ranked by objects per workload × apps. A second pass
(2026-11-03, after the evidence rule in DECISIONS, 54643c2) adds CPU per call: Callgrind Ir and interleaved wall
time, each against an A/A. See [CPU per call](#cpu-per-call) and the [ranking by value](#ranking-by-value).

**Result.** Five candidates were built. Each is one commit on the thomasklemm/rails fork, on rails/rails main
[`1597d576bd`](https://github.com/rails/rails/commit/1597d576bd222de7bf55bf7a12bffd87138f2a13) (R7-5 on
[`d47dc59e65`](https://github.com/rails/rails/commit/d47dc59e65)), and has a test that fails without it. None is
opened. R7-4 is out of the queue (Sure only). R7-5 replaces it and is marked "don't open".

| # | Branch @ SHA | Pattern | Per call (4.0.7 interp) | Census: workloads / apps moved at the site (A/A: 0) |
| --- | --- | --- | ---: | --- |
| R7-1 | [`thomasklemm/tag-values-without-copies`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-values-without-copies) [`d18c315d20`](https://github.com/thomasklemm/rails/commit/d18c315d201ed47c902cd754f07dab43fe2bca6a) | every `class_names`/`token_list`, every `class:`/`aria:` Array or Hash attribute | −1 to −2 | 18 / 4 (blog, fizzy, lobsters, sure); median −39.5, Sure up to −679 |
| R7-2 | [`thomasklemm/hash-as-json-symbol-names`](https://github.com/thomasklemm/rails/tree/thomasklemm/hash-as-json-symbol-names) [`a97a37b603`](https://github.com/thomasklemm/rails/commit/a97a37b60337524fce22b68ac689e7db1bb1e09b) | every direct `as_json`, and every encode with options (`to_json(except:)`), of a Hash with Symbol keys; not a plain `render json:` | −1 per Symbol key | 8 / 5 (discourse, fizzy, loomio, mastodon, sure); median −47.5 |
| R7-3 | [`thomasklemm/through-stale-state-without-array`](https://github.com/thomasklemm/rails/tree/thomasklemm/through-stale-state-without-array) [`8b4b8457f1`](https://github.com/thomasklemm/rails/commit/8b4b8457f122f3882e57ba91eae574d40fb89ac0) | every read of a loaded `has_one`/`has_many :through` a `belongs_to` | −2 | 16 / 5 (casa, discourse, docuseal, lago, redprints-cfp); median −12 per workload |
| R7-4 (dropped) | [`thomasklemm/currency-format-frozen-defaults`](https://github.com/thomasklemm/rails/tree/thomasklemm/currency-format-frozen-defaults) [`10b375c5e3`](https://github.com/thomasklemm/rails/commit/10b375c5e3) | every `number_to_currency` | −2 | 9 / 1 (sure); median −88, up to −384 |
| R7-5 | [`thomasklemm/sanitized-value-in-place`](https://github.com/thomasklemm/rails/tree/thomasklemm/sanitized-value-in-place) [`1a791fc876`](https://github.com/thomasklemm/rails/commit/1a791fc876bfb614b7f2e8210f192511b4c76c2b) | every `radio_button`/`check_box` id from a value (`sanitized_value`) | −2 | not run; census 7 puts the line in 5 apps at 4.6 objects/op |

The first pass recommended R7-1, R7-2, R7-3, R7-4. The value ranking below replaces it: R7-3, then R7-2 (Ruby 4.0
only, Thomas decides), then R7-1. R7-5 is "don't open".

## Opening pass (2026-11-03): neither R7-2 nor R7-1 opens

Thomas cleared R7-2 to open, on the premise that it is a no-op on Ruby master, and R7-1 subject to the L0–L3 gate.
Both branches rebase cleanly onto rails/rails main
[`1105756f42`](https://github.com/rails/rails/commit/1105756f42) (R7-2 → `0f375b5bed`, R7-1 → `1d25fe3689`, local
only; the fork keeps `a97a37b603` and `d18c315d20`). No open PR or main commit since `1597d576bd` touches
`core_ext/object/json.rb` or `tag_helper.rb`, and 10 of our 20 rails/rails slots are in use.

**R7-2 is blocked: it is a regression on Ruby 4.1, not a no-op.** On master, objects don't change (5/8/10 → 1/5/5 on
4.0.9; 1/5/5 on master before and after). Instructions do change. Master's `Symbol#to_s` already costs what
`Symbol#name` costs, so the added `Symbol === k` is pure overhead there. The Rails micro
([`ir_run_409.sh`](../../bench/upstream/r7/open/ir_run_409.sh), [`ir_run_i41.sh`](../../bench/upstream/r7/open/ir_run_i41.sh),
`cpu_r7.rb` as above; i49/y49 = 4.0.9 interpreter/YJIT, i41/z41 = master `9aa0898240` interpreter/ZJIT):

| Operation | Mode | main Ir | A/A | candidate Ir | Δ | Δ % |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `{ 4 Symbol keys }.as_json` | i49 | 11,203 | +0.12% | 9,423 | −1,779 | −15.88% |
| | y49 | 8,775 | +0.01% | 6,067 | −2,708 | −30.86% |
| | i41 | 9,715 | −0.02% | 10,927 | +1,212 | **+12.48%** |
| | z41 | 7,433 | −0.07% | 7,673 | +240 | **+3.23%** |
| `to_json(except: :created_at)` | i49 | 24,638 | +0.05% | 23,244 | −1,394 | −5.66% |
| | y49 | 18,577 | −0.02% | 16,534 | −2,043 | −11.00% |
| | i41 | 24,939 | +0.07% | 25,979 | +1,040 | **+4.17%** |
| | z41 | 19,085 | +0.42% | 19,263 | +177 | +0.93% |
| `ActiveSupport::JSON.encode(hash)` | i49 / y49 / i41 / z41 | 8,728 / 6,535 / 9,582 / 7,726 | ≤ 1.11% | 8,728 / 6,535 / 9,634 / 7,728 | 0 / 0 / +52 / +2 | 0 / 0 / +0.54 / +0.03 |

The explanation, from standalone loops ([`key_variants.rb`](../../bench/upstream/r7/open/key_variants.rb),
[`key_calls.rb`](../../bench/upstream/r7/open/key_calls.rb), Ir per call over a bare `k` reference): one `Symbol === k`
costs about 264 Ir in both interpreters. `k.to_s` costs 435 on 4.0.9 against 170 for `k.name`, plus the allocation
and the fstring lookup in `Hash#[]=`. On master `to_s` and `name` cost the same (141). The other exact spellings
don't help the interpreter: in the as_json-shaped loop on master, `Symbol ===` is +14.8%, `is_a?(Symbol)` +15.4% and
`case k when Symbol` +15.5% against plain `to_s`. Only `is_a?` is flat under ZJIT (0.0% against +3.2%). A
Ruby-version branch would avoid the cost and is L3. Ruby 4.1.0 ships in December 2026, when the routine cell moves to
4.1 ([measurement-matrix](measurement-matrix.md)), so the change would trade a 4.0 gain for a permanent 4.1
interpreter loss. Per DECISIONS (a ZJIT loss blocks until explained), R7-2 doesn't open. It goes back to Thomas
with this explanation.

ruby-bench doesn't reach it: per request, railsbench and shipit make 0 `Hash#as_json` calls, and lobsters 0.44 with
no Symbol keys ([`lowrail_asjson.rb`](../../bench/upstream/r7/open/lowrail_asjson.rb)). Suites on 4.0.9
(`RAILS_STRICT_WARNINGS=1`, `SEED=41231`): Active Support 6,894 runs, 0 failures, 0 errors (`PARALLEL_WORKERS=1`,
memcached as an orb service); Action Pack 4,472 runs, 0 failures; Active Record `test:sqlite3` 10,270 runs, 0
failures, 4 errors, all four `SqliteStructureDump/LoadTest` failing because this orb has no `sqlite3` CLI. RuboCop
is clean.

**R7-1 is L2 and has no measurable app or ruby-bench effect, so it doesn't open.** Gate rating: two new module
helpers (`append_tag_value`, `append_tag_values`) replace one recursive method, and one of them needs a comment
explaining why nested Arrays are still splatted. That is L2 ("a new helper"), close to L3. L2 needs an effect
measurable in an app or on ruby-bench. ruby-bench: `build_tag_values` runs 0 times per request in railsbench and
lobsters, and 1.32 times in shipit ([`lowrail_tagcount.rb`](../../bench/upstream/r7/open/lowrail_tagcount.rb)).
At about 105 ns per call (`tag.div(class: [..])`, 4.0.7 interpreter) that is about 140 ns of a 17 ms shipit request
(1,992 ms per 114-request iteration), about 0.001%. In apps the largest site is Sure's account pages (679 fewer
objects, so a few hundred calls), still a small fraction of a percent of a page whose A/A moves by up to ±7%, so app pages
can't price it. The branch stays on the fork; nothing was rerun on 4.0.9.

## Pins and method

* **Rails:** canonical `rails/rails` main `1597d576bd` (merge of our #59576), fetched 2026-11-03 14:20 UTC. The
  copies were set up at `231bc7ed65` (`script/census setup`), and every label ran with `--rails` at `1597d576bd` or at
  a candidate on it.
* **Ruby 4.0.7**, interpreter and `--yjit`, for the census and the suites. **Ruby master `9aa0898240`** (4.1.0dev,
  `--enable-zjit`, the F1/F2 pin), interpreter and `--zjit`, for the micro and the differential harnesses. Master
  breaks no candidate's setup.
* **Corpus:** census 7's configurations without `fizzy-mysql`, because this orb has no MySQL server. That leaves 22
  configurations, 20 apps and 237 workloads. Pins: blog `real-blog-r4`, campfire `af4dd9f`, writebook `7478e2c`, fizzy
  `77eada1`, codetriage `d1868f8`, pingcrm `22464f8`, redprints-cfp `6080fc2`, react-starter-kit `f808193`, lobsters
  `366e211`, docuseal `6c416dd`, mastodon `5ccbf0e`, lago `b0007bf`, discourse `0f524718`, loomio `407d4a8`, sure
  `8d0d84d`, casa `b584d2e`, chatwoot `ae66c97`, flow `6a8b5fd`, hackatime `74deec4`, thinkroom `f7865d0`.
  mastodon-nops and lago-nops run on the same copies.
* **Runs:** `run --label r7 --aa --modes interp,yjit --jobs 6` (labels `r7` and `r72`), then one label per candidate
  (`tagvalues`, `asjson`, `stale`, `currency`). Each candidate is compared with `r72`, and `r7` is the A/A.
* **Census measure.** A candidate removes one line's allocations, so the census delta is read at that line's file.
  For each workload, [`sitedelta.py`](../../bench/upstream/r7/sitedelta.py) sums the objects per operation that the
  traced window attributes to the file, and it reports the traced total and the GC-window median beside it. The A/A
  moves none of the four files in any workload, except `core_ext/object/json.rb` in 3 Thinkroom interpreter
  workloads. Over all 237 workloads the totals fall by 0.04–0.14%, which is inside the A/A on that measure (−0.17% /
  −0.06%). No corpus-wide percentage is claimed.
* **Micro:** [`micro_r7.rb`](../../bench/upstream/r7/micro_r7.rb), `GC.stat(:total_allocated_objects)` over 2,000
  warm calls, main twice (A/A) and each candidate, on 4.0.7 interpreter/YJIT and master interpreter/ZJIT.
* **Exactness:** one differential harness per candidate ([`diff_c1.rb`–`diff_c4.rb`](../../bench/upstream/r7)). Each
  prints results, call logs and errors on main and on the candidate, under all four Ruby/mode pairs. All four
  harnesses print identical output on main and the candidate in every pair.
* **Sources mined:** census 7's `rank-c72-interpreter.tsv` (the 3–6-app and 2-app tiers by mean objects per
  operation, and the one-app lines of the four big apps), re-ranked on `r7` (same order). Open PRs: all 1,241 open
  rails/rails PRs and their files (GraphQL, 2026-11-03 14:30 UTC). Every PR that touches a candidate's file was read
  and checked with `git merge-tree` against the candidate.
* **Suites** (Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`): Active Support with `PARALLEL_WORKERS=1` and
  memcached, because with two workers `MemCacheStoreTest` and `BacktraceCleanerCleanLocationsTest` fail on
  unchanged main too. Action Pack, Action View and Active Record (`test:sqlite3`) ran with two workers. With
  `PARALLEL_WORKERS=1`, Action Pack reports 282 "missing assertions" errors on main and on R7-1 alike (4,754 runs).
* **Setup notes (this orb):** pgvector 0.8.1 built from source, `postgresql-15-partman`, `libidn11-dev`, `liblept5`,
  and `trust` in `pg_hba.conf` for local TCP. Docuseal's pdfium is the bblanchon `chromium/8125` build with SONAME
  `libpdfium_real.so`, behind a 9-symbol stub `libpdfium.so`, as in census 7.

## Per call

Objects per call, main / A/A / candidate:

| Case | 4.0.7 interpreter | 4.0.7 YJIT | master 9aa0898240 interpreter | master ZJIT |
| --- | ---: | ---: | ---: | ---: |
| R7-1 `class_names("btn", active: true)` | 13 / 13 / 12 | 13 / 13 / 12 | 12 / 12 / 11 | 12 / 12 / 11 |
| R7-1 `class_names(nested Array)` | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 |
| R7-1 `tag.div(class: ["btn", "btn-primary"])` | 11 / 11 / 9 | 11 / 11 / 9 | 11 / 11 / 9 | 11 / 11 / 9 |
| R7-1 `tag.div(class: { active: true })` | 11 / 11 / 10 | 11 / 11 / 10 | 10 / 10 / 9 | 10 / 10 / 9 |
| R7-1 `tag.div(aria: { describedby: [..] })` | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 |
| R7-2 `{4 Symbol keys}.as_json` | 5 / 5 / 1 | 5 / 5 / 1 | 1 / 1 / 1 | 1 / 1 / 1 |
| R7-2 `{4 Symbol keys}.as_json(except: :created_at)` | 8 / 8 / 5 | 8 / 8 / 5 | 5 / 5 / 5 | 5 / 5 / 5 |
| R7-2 `{ post: {4 keys} }.as_json({})` | 10 / 10 / 5 | 10 / 10 / 5 | 5 / 5 / 5 | 5 / 5 / 5 |
| R7-3 `comment.post_author` (loaded, through `belongs_to`) | 3 / 3 / 1 | 3 / 3 / 1 | 3 / 3 / 1 | 3 / 3 / 1 |
| R7-4 `number_to_currency(1234.5)` | 53 / 53 / 51 | 53 / 53 / 51 | 53 / 53 / 51 | 53 / 53 / 51 |
| R7-4 `number_to_currency(-5, unit: "€")` | 58 / 58 / 56 | 58 / 58 / 56 | 58 / 58 / 56 | 58 / 58 / 56 |
| R7-5 `sanitized_value("In progress")` | 7 / 7 / 5 | 7 / 7 / 5 | 7 / 7 / 5 | 7 / 7 / 5 |
| R7-5 `radio_button(:post, :status, "In progress")` | 29 / 29 / 27 | 30 / 30 / 28 | 29 / 29 / 27 | 30 / 30 / 28 |

Master returns a frozen String from `Symbol#to_s` (Feature #22137). `Hash#[]=` then stores it without a copy, so
R7-2 changes nothing there; the saving is on Ruby ≤ 4.0. No candidate loses under ZJIT.

## CPU per call

DECISIONS (54643c2) requires CPU per call next to objects. Each case below is one whole operation, so the
change in percent is the candidate's share of that operation.

**Method.** [`cpu_r7.rb`](../../bench/upstream/r7/cpu_r7.rb) warms each case with 3,000 calls, runs `GC.start`,
then disables GC. For Ir, the N calls run inside `Array#cycle`, and Callgrind (Valgrind 3.19.0,
`--collect-atstart=no --toggle-collect=rb_ary_cycle`, plus `--smc-check=all` under a JIT) counts only that
window. Ir per call is (Ir at N = 5,000 − Ir at N = 0) / 5,000. Main, its A/A twin (the same checkout, measured
again) and the candidate run under 4.0.7 interpreter (i40), 4.0.7 `--yjit` (y40) and master `9aa0898240` `--zjit`
(z41). R7-2 has no z41 row: it is a no-op on master. Wall time ([`ns_run.sh`](../../bench/upstream/r7/ns_run.sh))
interleaves main, A/A and candidate for 7 rounds, one process per measurement, 20,000 calls each, with the order
reversed every other round. It reports the median ns per call. Ir is the primary measure; wall time on this shared
orb moves by up to ±3.5% between A/A runs.

**Ir per call** (Δ against main; A/A is the twin against main):

| Candidate | Operation | Mode | main Ir | A/A | candidate Ir | Δ | Δ % |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| R7-1 | `tag.div(class: ["btn", "btn-primary"])` | i40 | 37,060 | +0.26% | 35,480 | −1,629 | −4.39% |
| | | y40 | 21,087 | +0.05% | 20,231 | −861 | −4.08% |
| | | z41 | 19,690 | −0.28% | 18,722 | −940 | −4.78% |
| R7-1 | `tag.div(aria: { describedby: [..] })` | i40 | 47,124 | +0.06% | 45,536 | −1,603 | −3.40% |
| | | y40 | 26,172 | +0.03% | 25,309 | −867 | −3.31% |
| | | z41 | 25,069 | −0.04% | 24,157 | −908 | −3.62% |
| R7-1 | `class_names("btn", active: true)` | i40 | 25,156 | −0.26% | 24,704 | −419 | −1.67% |
| | | y40 | 16,378 | −0.03% | 16,070 | −305 | −1.86% |
| | | z41 | 15,646 | −0.01% | 15,591 | −54 | −0.34% |
| R7-2 | `{ 4 Symbol keys }.as_json` | i40 | 11,202 | +0.18% | 9,437 | −1,774 | −15.83% |
| | | y40 | 8,834 | +0.27% | 6,122 | −2,724 | −30.80% |
| R7-2 | `{ 4 Symbol keys }.to_json(except: :created_at)` | i40 | 24,790 | +0.01% | 23,492 | −1,300 | −5.24% |
| | | y40 | 18,726 | +0.08% | 16,717 | −2,017 | −10.77% |
| R7-2 | `ActiveSupport::JSON.encode(hash)` (what `render json:` does) | i40 | 8,739 | 0.00% | 8,739 | 0 | 0.00% |
| | | y40 | 6,589 | 0.00% | 6,591 | +2 | +0.03% |
| R7-3 | loaded `comment.post_author` (through `belongs_to`) | i40 | 15,448 | 0.00% | 12,123 | −3,325 | −21.52% |
| | | y40 | 8,257 | +0.02% | 5,003 | −3,254 | −39.41% |
| | | z41 | 7,874 | −0.03% | 4,537 | −3,336 | −42.38% |
| R7-5 | `radio_button(:post, :status, "In progress")` | i40 | 116,189 | −0.07% | 116,112 | −38 | −0.03% |
| | | y40 | 70,265 | −0.21% | 68,990 | −1,199 | −1.71% |
| | | z41 | 69,384 | +0.10% | 69,041 | −376 | −0.54% |

**Wall time per call** (median of 7 interleaved rounds; 6 where one measurement printed nothing):

| Candidate | Operation | Mode | main ns | A/A % | candidate ns | Δ % |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| R7-1 | `tag.div(class: [..])` | i40 / y40 / z41 | 3,620 / 2,044 / 1,893 | −1.95 / +0.91 / −2.39 | 3,515 / 1,942 / 1,770 | −2.90 / −4.99 / −6.50 |
| R7-1 | `tag.div(aria: { describedby: [..] })` | i40 / y40 / z41 | 4,813 / 2,586 / 2,444 | +0.49 / +1.63 / −3.46 | 4,698 / 2,529 / 2,328 | −2.39 / −2.19 / −4.74 |
| R7-1 | `class_names("btn", active: true)` | i40 / y40 / z41 | 2,288 / 1,647 / 1,515 | +1.49 / −1.51 / −0.36 | 2,230 / 1,586 / 1,492 | −2.54 / −3.71 / −1.49 |
| R7-2 | `{ 4 Symbol keys }.as_json` | i40 / y40 | 948 / 739 | −1.92 / +2.06 | 720 / 491 | −24.06 / −33.53 |
| R7-2 | `to_json(except: :created_at)` | i40 / y40 | 2,531 / 2,000 | +2.04 / +1.29 | 2,369 / 1,800 | −6.40 / −10.01 |
| R7-3 | loaded `comment.post_author` | i40 / y40 / z41 | 1,547 / 687 / 661 | −0.59 / −0.68 / −1.10 | 1,179 / 394 / 363 | −23.80 / −42.63 / −45.06 |
| R7-5 | `radio_button(..)` | i40 / y40 / z41 | 13,645 / 7,448 / 7,507 | +0.63 / +1.00 / −3.51 | 13,788 / 7,116 / 7,171 | +1.05 / −4.46 / −4.48 |

Wall time agrees with Ir in direction for R7-1 to R7-3. For R7-5 it is within the A/A in the interpreter and under
ZJIT. R7-1's wall-time gains are 1–2× its A/A spread, so they rest on the Ir numbers.

**Lib diff and complexity.**

| Candidate | Lib diff | Adds complexity? |
| --- | --- | --- |
| R7-1 | +29 / −15 (`tag_helper.rb`) | Yes. Two new module methods replace `flatten`/`compact` chains. |
| R7-2 | +4 / −2 (`core_ext/object/json.rb`) | No. One ternary in the existing loop. |
| R7-3 | +11 / −3 (`through_association.rb`) | Yes, a little. One branch for single-column keys; composite keys keep the old line. |
| R7-4 | +2 / −2 | No. Dropped from the queue (one app). |
| R7-5 | +8 / −1 (`tags/base.rb`) | Yes. A new branch and an `instance_of?(String)` guard that keeps the old chain for other values. |

## Ranking by value

| Rank | Candidate | Ir gain beyond the A/A? | Verdict |
| --- | --- | --- | --- |
| 1 | R7-3 | Yes: −21% (i40), −39% (y40), −42% (z41) of a loaded through read, A/A ≤ 0.03% | Open first. Largest share of its operation, small diff. |
| 2 | R7-2 | Yes on 4.0.7: −16%/−31% of a direct `as_json`, −5%/−11% of `to_json(except:)`; 0 for a plain `render json:` | No-op on Ruby master (`Symbol#to_s` is frozen there). Smallest diff. Thomas decides whether a 4.0-only gain is worth opening. |
| 3 | R7-1 | Yes for `tag.div` with an Array/Hash attribute: −3.3% to −4.8% in all three modes, A/A ≤ 0.28%. `class_names` −1.7%/−1.9%, but only −0.34% under ZJIT | Openable, but the diff adds two methods for a few percent of a tag render. The draft must say so plainly. |
| — | R7-5 | No in the interpreter (−0.03% against an A/A of −0.07%); −1.7% (y40), −0.5% (z41) | **Don't open.** The interpreter gain is within the A/A, the change adds a branch, and it has a boundary (below). |
| — | R7-4 | — | Out of the queue (Sure only). The branch stays pushed. |

## R7-1: collect nested tag values without intermediate Arrays

`build_tag_values(*args)` takes its arguments as a rest Array. It also concatenated a fresh Array for each nested
Array (`tag_values.concat build_tag_values(*tag_value)`). `token_list` and the `class`/`aria` attribute paths called it
and then read the result once. The candidate appends every value to one Array through
`TagHelper.append_tag_value`. Nested Arrays are still splatted, so their elements are read from a copy, in the
same order. `build_tag_values` keeps its signature and result.

**Exactness checklist.**
1–2: Singleton `each`/`to_a` on an Array argument, an Array subclass with its own `each`/`to_a`/`map`/`size`, and
a Hash subclass with its own `each`/`each_pair` give identical results and call logs. The splat reads an Array the
same way in both versions.
3: Objects with `to_ary`/`to_a` as values: neither version calls them.
4: Every `present?` and `to_s` call on user values happens in the same order. The candidate adds no call and skips
none.
5: `to_s` results are appended as before.
6: An element whose `to_s` appends to its containing Array is read from the splat's copy in both versions.
7: Frozen Arrays and Hashes give the same output, and an exception raised from `present?` or `to_s` keeps its class
and message.
8: `append_tag_value` is a module method of `TagHelper`, not a new private view method, so no helper name is
added to views.
**Boundary:** an app that overrides the private (nodoc) `build_tag_values` in a view no longer changes what
`token_list` and the `class` attribute collect. This is an override of a nodoc private method, which DECISIONS
accepts.

**Test:** `test_token_list_and_class_attribute_collect_nested_values_into_one_array`. A nested Array must cost only
the one copy its splat makes. On main it costs one more than that, and the test fails.
**Suites:** AV 2,914 runs, AP 4,472, AR 10,266, AS 6,887, each with 0 failures and 0 errors. RuboCop is clean.
**Overlap:** no open PR changes `build_tag_values`. #57999 (attribute strings) and #59499 merge cleanly. #47163,
#47159, #56596, #45236, #49377 and #51646 already conflict with main.

> **Collect nested tag values without intermediate Arrays**
>
> Every `class_names`/`token_list` call, and every `class:` or `aria:` attribute given an Array or a Hash, runs
> `build_tag_values`. It collects the values into one Array and builds another Array for each nested Array, then
> concatenates them. The caller reads the result once.
>
> This appends every value to a single Array instead. Nested Arrays are still splatted, as before, so the same
> values are read in the same order, with the same `present?` and `to_s` calls, and a value that mutates its
> Array while it is read sees the same copy. `build_tag_values` is unchanged for other callers.
>
> | Per call (objects) | Before | After |
> | --- | ---: | ---: |
> | `class_names("btn", active: true)` | 13 | 12 |
> | `tag.div(class: ["btn", "btn-primary"])` | 11 | 9 |
> | `tag.div(aria: { describedby: [...] })` | 14 | 12 |
>
> Across 20 open-source apps on Rails main, the pages that build class lists allocate fewer objects: up to 679
> fewer per request on Sure's account pages, and about 110 fewer on Lobsters' story lists. Ruby master with ZJIT
> saves the same objects. In instructions, one `tag.div(class: [..])` render takes 4.4% (interpreter) and 4.1% (YJIT)
> fewer on Ruby 4.0.7, and 4.8% under ZJIT on master; `class_names("btn", active: true)` 1.7% / 1.9% / 0.3%
> (Callgrind, A/A within 0.3%). The change adds two small private methods.
>
> One boundary: a view that overrides the private `build_tag_values` no longer affects `token_list` and the class
> attribute.

## R7-2: use `Symbol#name` for `Hash#as_json` keys

`Hash#as_json` stringified every key with `k.to_s`. On Ruby ≤ 4.0, `Symbol#to_s` returns a new String, and
`Hash#[]=` then stores an interned frozen copy of it. That copy is the String that `Symbol#name` already returns.
The candidate uses `Symbol === k ? k.name : k.to_s`.

**Exactness checklist.**
1: Symbols cannot have singleton methods. A refinement of `Symbol#to_s` is lexical and cannot reach `json.rb`.
2: There are no Symbol subclasses. String subclass keys and their own `to_s` still take `to_s`, and the harness
logs the call.
3–4: For Symbol keys the candidate skips `Symbol#to_s`. Only a global redefinition of `Symbol#to_s` sees the
difference, which DECISIONS accepts as core redefinition. Other keys (Integer, nil, Float, Array, custom objects)
take `to_s` as before.
5–6: Values are converted as before. A value whose `as_json` mutates the source Hash behaves the same.
7: The result keys are equal and identical (`equal?`), frozen, and have the same encoding, for ASCII, non-ASCII,
dynamic and spaced Symbols. This holds for frozen, `compare_by_identity` and subclass sources, with `only:`,
`except:` and frozen options.
8: Nothing new is loaded.
On Ruby master the change is a no-op, as shown above.

**Test:** `test_hash_as_json_does_not_copy_symbol_keys`. Symbol keys must cost the same as String keys, with and
without options, and the key must be `:name.name`. On main the test fails (4 against 1).
**Suites:** AS 6,889 runs, AP 4,472, AV 2,913, AR 10,266, each with 0 failures. RuboCop is clean.
**Correction (second pass).** The first draft said "every `render json:`". A TracePoint in a real controller
shows that `render json:` of a Hash calls `ActiveSupport::JSON.encode(hash, {})`, which takes the
options-free encoder and never calls `Hash#as_json` (0 calls, Ir unchanged). The pattern is direct `as_json` and
encodes with options. The census deltas were measured and stand.
**Overlap:** no open PR touches `core_ext/object/json.rb`. The serialization dive's rejected `transform_values`
variant is a different change; this one keeps `result = {}` and the loop.

> **Use `Symbol#name` for `Hash#as_json` keys**
>
> Every `as_json` of a Hash with Symbol keys, and every encode with options such as `to_json(except:)`,
> stringifies each key with `to_s`. A plain `render json:` does not reach this code. On Ruby 4.0 and
> earlier this creates a String that `Hash#[]=` then replaces with its interned frozen copy. That copy is the
> String `Symbol#name` returns.
>
> This uses `Symbol#name` for Symbol keys. The resulting Hash has the same keys, and they are the same objects as
> before: frozen, interned, and in the same encoding. Strings, String subclasses, Integers, `nil` and other keys
> still go through `to_s`, so a key object's own `to_s` is called as before. Values, `only:`/`except:` and the
> options passed to each value are unchanged.
>
> | Per call (objects, Ruby 4.0) | Before | After |
> | --- | ---: | ---: |
> | `{ id:, name:, email:, created_at: }.as_json` | 5 | 1 |
> | `{ post: { 4 keys } }.as_json({})` | 10 | 5 |
>
> On Ruby 4.0.7 this is 16% (interpreter) and 31% (YJIT) fewer instructions for the `as_json` above, and 5% / 11%
> for `to_json(except:)` (Callgrind, A/A within 0.3%). On Ruby 4.1, `Symbol#to_s` already returns a frozen String,
> so nothing changes there. Across 20 open-source apps
> on Rails main, 8 workloads in 5 apps allocate fewer objects, for example 381 fewer on Sure's dashboard and 79
> fewer in a Mastodon `DistributionWorker` job. Only a global redefinition of `Symbol#to_s` would notice the
> change.

## R7-3: read the through foreign key without wrapping it in an Array

`ThroughAssociation#stale_state` runs on every read of a loaded `has_one`/`has_many :through` association whose
through reflection is a `belongs_to`. It computed
`Array(through_reflection.foreign_key).filter_map { |c| owner.read_attr(c) }.presence`: one Array for the key and
one for the values. `foreign_key` is a frozen String for a single column (`Key::Single`) and an Array for a
composite key. For a String, the candidate reads the one column and returns `[value] if value`. Composite keys keep
the old expression.

**Exactness checklist.**
1–3: The key is the reflection's own frozen String, not a user object, so `Array()` made no conversion calls on it.
4: `read_attr` is called once with the same name. The candidate skips `Array()`, `filter_map` and `presence`, all
core or Active Support methods on Arrays that Rails built itself. Only a global redefinition would see the
difference.
5–6: The value is wrapped as `filter_map` would wrap it, and `nil` and `false` give `nil` as `presence` did.
7: The result is a new unfrozen Array, as before.
8: Nothing new is loaded.
The harness covers loaded, changed, nil, `false`, `true` and String-assigned keys, new and found records, a Symbol
`foreign_key:` option and a composite key (with a partial `nil`). It logs `read_attr` through a prepended module, and
both versions give the same states, staleness, targets and call logs.

**Test:** `test_has_one_through_belongs_to_stale_state_wraps_only_the_foreign_key_value`. The state is the value
wrapped in an Array, `nil` when the key is `nil`, and it costs one allocation. On main it costs 3 and the test
fails.
**Suites:** AR 10,267 runs, AS 6,887, AP 4,472, AV 2,913, each with 0 failures. RuboCop is clean.
**Overlap:** #57055 (inverse before attribute assignment) changes `association.rb` around `stale_state` and already
conflicts with main. #52060 conflicts with main. #55039, #55041, #58065 and #58877 merge cleanly.

> **Read the through foreign key without wrapping it in an Array**
>
> Every read of a loaded `has_one :through` or `has_many :through` a `belongs_to` checks `stale_state`, the owner's
> foreign key values. For a single-column key this wraps the column name in an Array, maps it into another Array,
> and calls `presence`.
>
> For a single column this now reads the value and wraps only the value. Composite keys keep the existing code. The
> state is the same, `nil` when the key is `nil` or `false`, and `read_attr` is called once as before, so a
> prepended `read_attr` and attribute aliases see the same calls. Whether a changed foreign key reloads the target
> is unchanged.
>
> | Per call (objects) | Before | After |
> | --- | ---: | ---: |
> | `comment.post_author` (loaded, through `belongs_to :post`) | 3 | 1 |
>
> Across 20 open-source apps on Rails main, 16 workloads in 5 apps allocate fewer objects. Discourse's topic lists
> allocate about 250 fewer per request, and CASA's case contacts page about 240 fewer. The read itself takes 21%
> (interpreter) and 39% (YJIT) fewer instructions on Ruby 4.0.7, and 42% under ZJIT on Ruby master (Callgrind, A/A
> within 0.03%).

## R7-4: pass the frozen empty format to I18n in `number_to_currency`

**Dropped from the queue (2026-11-03).** It reaches one census app (Sure). The branch stays pushed; nothing below
was rerun.

`NumberToCurrencyConverter#options` calls `i18n_format_options`, which passed a new `{}` as the `default:` of each
of its two `I18n.translate` calls. The first result is copied with `dup`, and the second is only read by `merge!`.
Since 2ecce1b3b9, `NumberConverter#options` makes the same two lookups with the frozen `EMPTY_FORMAT` default. The
candidate passes `EMPTY_FORMAT` here too.

**Exactness checklist.**
1–3: The default is Rails' own Hash, not a user object.
4: The same `translate` calls happen with an equal default. The only difference is that the default is frozen.
5: A missing translation returns the default itself. The first result is copied with `dup` as before, so
`i18n[:negative_format] ||=` writes to a fresh Hash. The second result is only read.
6: Translations are only read.
7: A backend that mutated the `default:` Hash it was given would now raise `FrozenError`. Main already passes the
same frozen object in `NumberConverter#options`, so such a backend breaks every number helper on main already.
8: Nothing new is loaded.
The harness converts 8 numbers (Integer, negative, Float, invalid String, `nil`, negative BigDecimal, rounding to
zero, Infinity) under 9 option sets (full locale, format-only, `nil` negative format, base-only, a String
`number.format` that raises, explicit `format:`, unknown locale, `negative_format:`). It runs them on the Simple
backend, a recording subclass and a Fallbacks backend: 216 identical lines.

**Test:** `test_number_to_currency_reads_missing_formats_without_a_default_per_call` stubs `I18n.translate` and
checks that every format lookup gets the same frozen empty default. On main there are 5 distinct defaults over two
calls, and the test fails.
**Suites:** AS 6,888 runs, AP 4,472, AV 2,913, AR 10,266, each with 0 failures. RuboCop is clean.
**Overlap:** #59149 (eager-built format keys) and #47874 (`trim_empty_fractional`) do not touch
`i18n_format_options`.

> **Pass the frozen empty format to I18n in `number_to_currency`**
>
> Every `number_to_currency` call, from the view helper or from Active Support, looks up `number.format` and `number.currency.format` with a new empty Hash as the
> default. The first result is copied and the second is only read, and `NumberConverter#options` already passes its
> frozen `EMPTY_FORMAT` for the same lookups.
>
> This passes `EMPTY_FORMAT` here as well. Translations, defaults and the order of lookups are unchanged. A missing
> translation still returns an empty Hash: the first one is copied before `negative_format` is filled in, and the
> second is only merged from, so nothing writes to the frozen default. Locale formats, a format-only locale, an
> explicit `format:` and the Fallbacks backend give the same output.
>
> | Per call (objects) | Before | After |
> | --- | ---: | ---: |
> | `number_to_currency(1234.5)` | 53 | 51 |
> | `number_to_currency(-5, unit: "€")` | 58 | 56 |
>
> Of 20 open-source apps on Rails main, Sure formats currency on the measured pages. Its 9 affected workloads
> allocate fewer objects, up to 384 fewer per request on the dashboard. Ruby master with ZJIT saves the same objects.

## R7-5: edit the `sanitized_value` copy in place (don't open)

`Tags::Base#sanitized_value` builds the id of every `radio_button` and `check_box` that has a value (and the
`collection_*` items) with `value.to_s.gsub(/[\s.]/, "_").gsub(/[^-[[:word:]]]/, "").downcase`. The second `gsub`
and `downcase` each return a new String, although only the first `gsub`'s result, which Rails just made, is
edited. The candidate keeps `value = value.to_s`, keeps the old chain for any value whose `to_s` is not a plain
String (`instance_of?(String)` false), and for a plain String runs `gsub`, then `gsub!` and `downcase!` on that
result.

```ruby
value = value.to_s
return value.gsub(/[\s.]/, "_").gsub(/[^-[[:word:]]]/, "").downcase unless value.instance_of?(String)

# String#gsub returns a new String, so the other steps can edit it in place.
sanitized = value.gsub(/[\s.]/, "_")
sanitized.gsub!(/[^-[[:word:]]]/, "")
sanitized.downcase!
sanitized
```

**Exactness checklist** ([`diff_c5.rb`](../../bench/upstream/r7/diff_c5.rb), all four Ruby/mode pairs).
1: `to_s` is called once, as before. The caller's value and the String `to_s` returns are never edited: frozen
Strings, a `to_s` that returns a retained (shared) String, and Symbol, `nil`, Integer and Float values give the
same id and leave their source unchanged.
2: String subclasses (from `to_s` or as the value) fail `instance_of?(String)` and take the old chain, so their own
`gsub`/`downcase` run as before and the result has their class.
3–4: For a plain String the candidate calls `gsub!` and `downcase!` where main called `gsub` and `downcase`. Only a
global redefinition of those core methods sees the difference, **with one exception**: a plain String whose
singleton `gsub` returns a String someone else keeps. Main would copy it twice; the candidate edits it in place, so
the other holder's String changes. The harness case "to_s singleton gsub (boundary)" shows the difference, and so does the later helper case "to_s
plain retained", which reads that same kept String after the candidate edited it (2 of 33 lines differ, in all four
Ruby/mode pairs; the other 31 are identical). This is
outside the accepted list in DECISIONS (singleton methods on a plain String are user code, not core redefinition).
5–6: `gsub!` returns `nil` when nothing matches, and `downcase!` too; the candidate ignores both return values and
returns `sanitized`, so "all-removed", empty and already-lowercase values match main.
7: The result is a new unfrozen String with the same encoding: Unicode, binary, and invalid bytes (which raise
the same `ArgumentError` from the same step) match main.
8: Nothing new is loaded.

**Test:** `test_radio_button_id_from_value_edits_only_its_own_copy` checks the id, that the caller's String is
unchanged, a frozen value, and that `sanitized_value` allocates fewer objects than the old chain on the same value.
On main the allocation assertion fails (7 against 6).
**Suites** (Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`): AV 2,914 runs, AP 4,472, AR 10,266 (`test:sqlite3`),
AS 6,892 (serial, memcached), each with 0 failures and 0 errors. RuboCop is clean. The test also passes on master `9aa0898240` with
`--zjit`.
**Census:** not run for this candidate; census 7 puts `tags/base.rb:129` in 5 apps at 4.6 objects per operation.
**Verdict: don't open.** In the interpreter, Ir per `radio_button` moves by −0.03% against an A/A of −0.07%. Under
YJIT it is −1.7%, under ZJIT −0.5%. The change adds a branch and a guard, and the singleton-`gsub` boundary is a real
difference. The branch is pushed for the record.

## Ranking and dispositions

Re-ranked on `r7`. Tiers follow census 7; within a tier, lines are ordered by mean objects per operation. "Not
examined" means only the line was read.

**3–6 apps**

| Site (rank) | Apps | Objects/op | Disposition |
| --- | ---: | ---: | --- |
| AS `notifications/fanout.rb:213` (1125) | 5 | 13.1 | Listener call per timed event. Not examined further. |
| AV `tag_helper.rb:1868/1877/1813/1814` (1371–1403) | 3–4 | 1.3–10.8 | **R7-1** (1868, 1877; 1814's rest Array). 1813 (`tokens`) and 1824 (the joined result) are required. |
| AS `big_decimal/conversions.rb:9` (1126) | 5 | 8.4 | `to_s("F")` result. Required. |
| AS `number_converter.rb:218`, `number_to_rounded_converter.rb:36`, `number_to_delimited_converter.rb:16` | 3 | 6.9–8.1 | The BigDecimal and the formatted Strings. Required. |
| AR `arel/visitors/to_sql.rb:837/838/839`, `bound_sql_literal.rb:20` | 6 | 1.2–6.3 | SQL fragments of bound literals. Required. |
| AS `html_safe_translation.rb:26`, AV `translation_helper.rb:104` | 6 | 5.7–6.1 | One keyword Hash per hop (i18n dive). Required. |
| AV `template/renderable.rb:21`, `rendering_helper.rb:152/153` | 3–4 | 2.5–5.8 | `render_in(locals:)` keywords, the Renderable, the payload. Required. |
| AV `asset_url_helper.rb:235/236` | 3 | 2.9–5.7 | `options.merge(protocol: :request)`: the copy keeps the caller's options intact. Required. |
| AM `indexed_row.rb:105/114` | 5 | 1.7–5.7 | `Remapper` for joins. Rewritten by open #59141 (tenderlove). Excluded. |
| AR `transaction.rb:677` | 6 | 5.1 | Re-raised exception. Required. |
| AV `tags/base.rb:129` `sanitized_value` | 5 | 4.6 | **R7-5**, don't open: −2 objects, but no Ir gain in the interpreter beyond the A/A, and a singleton-`gsub` boundary. |
| AS `redis_cache_store.rb:330` | 5 | 4.5 | `**options` forwarding. Required by the keyword API. |
| AS `inflector/methods.rb:87/89` `camelize` | 4–5 | 1.9–4.3 | Rejected in census 3 (literal inflection plans). |
| AR `query_methods.rb:2211` | 5 | 3.9 | `arel.project(*columns)` with ignored columns: the projections. Required; rest Array is a VM lead (census 7). |
| AS `core_ext/object/json.rb:194` | 5 | 4.0 | **R7-2.** |
| AR `associations/through_association.rb:86` | 5 | 3.9 | **R7-3.** |
| AP `route_set.rb:783` | 5 | 3.5 | `direct` URL helpers with `only_path`: `"/" + url.partition(re).last`. **Lead:** an index-and-slice saves the Array and two Strings; not built. |
| AS `cache.rb:118/1032/1047` | 5–6 | 1.1–3.2 | Expanded and namespaced cache keys. Required. |
| AR `postgresql/oid/array.rb:30`, AM `type/binary.rb:35` | 3–4 | 2.8 | Decoded values. Required. |
| others in the tier below 2.5 objects/op | | | Not examined. |

**2 apps**

| Site | Apps | Objects/op | Disposition |
| --- | --- | ---: | --- |
| AV `tag_helper.rb:1819` | fizzy, sure | 110.3 | The tokens `split` yields. Required output of `class_names`. |
| AV/AS/AR `structured_event_subscriber.rb`, AS `event_reporter.rb:525` | codetriage, fizzy | 1.3–5.5 | Debug-mode structured events, which these apps enable. Required while enabled. |
| AS `json/encoding.rb:315`, `fanout.rb:292`, AV `base.rb:358`, AP `route_set.rb:370/371` | 2 each | 1.3–4.3 | Not examined. |

**One app (Discourse, Mastodon, Chatwoot, Sure)**

| Site | App | Objects/op | Disposition |
| --- | --- | ---: | --- |
| AS `number_converter.rb:191/194` (`i18n_format_options`) | sure | 7.2, 4.8 | **R7-4.** |
| AS `number_to_currency_converter.rb:26` `gsub` chain | sure | 16.4 | The formatted result Strings. Required. |
| AS `number_converter.rb:185` (`default_format_options` dup) | sure | 2.4 | The Hash the options are merged into. Required. |
| AV `text_helper.rb:570` `split_paragraphs` | mastodon | 4.6 | `simple_format`'s paragraphs. Required. |
| AS `deprecation/reporting.rb:23` | chatwoot | 2.9 | Backtrace for a deprecation the app triggers. App-side. |
| AS `output_safety.rb:165`, AR `aggregations.rb:23` | mastodon | 2.3, 1.4 | Not examined. |
| AR `store.rb:334` | chatwoot | 1.0 | The indifferent store Hash. Required. |

**SQL control.** Each label changes the SQL digest of 2–5 of 474 workload runs. The changed runs are Discourse's
`GET topic.json` (it also changes in the A/A), Mastodon's `GET profile` and timelines (a different label and mode
each time), and Thinkroom's `POST comment`, which writes data. None of these is a workload that a candidate moved.
They are database drift, as in census 7.

## Limits

* The census measures allocation counts only. Each configuration and mode ran in one process, and results are
  judged against the A/A. CPU per call is measured on single operations (above), not across the census.
* `fizzy-mysql` did not run (no MySQL server in this orb), so MySQL is not covered in this round.
* Suites ran locally only (Ruby 4.0.7; Active Record on SQLite). No hosted CI ran on the fork branches.
* The exactness checklist items were checked with the harnesses named above (`diff_c1.rb`–`diff_c5.rb`). None of
  the candidates has had a Sol or Astra review yet.
* Receipts: [data/rails-r7-queue/receipts.tar.gz](data/rails-r7-queue/receipts.tar.gz) holds both rankings on `r7`,
  label metadata, the `compare` output, per-candidate site deltas with their A/A, the micro, every harness output
  and the suite summaries. The second pass adds [cpu-receipts.tar.gz](data/rails-r7-queue/cpu-receipts.tar.gz):
every Callgrind output, `ns.tsv`, both tables, the R7-5 harness outputs and suite logs. Scripts:
[bench/upstream/r7](../../bench/upstream/r7).
