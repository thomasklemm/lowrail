# Open Rails perf PRs: CPU per call and readability (2026-11-03)

Evidence pass on four open rails/rails PRs under the evidence rule (DECISIONS 54643c2) and the L0–L3 readability
gate ("Learnings from 2026-11-03"). Rails main [`1105756f42`](https://github.com/rails/rails/commit/1105756f42),
each PR cherry-picked onto it. Plus the R7-3 PR opened today, [rails/rails#59583](https://github.com/rails/rails/pull/59583).

**Method.** [`cpu_open.rb`](../../bench/upstream/rails-open/cpu_open.rb) warms each case with 3,000 calls, runs
`GC.start` and disables GC. Ir per call is Callgrind's count for 5,000 calls minus 0 calls inside `Array#cycle`
(`--toggle-collect=rb_ary_cycle`, `--smc-check=all` under a JIT), divided by 5,000
([`ir_run.sh`](../../bench/upstream/rails-open/ir_run.sh)). Main, an A/A rerun of main and each variant. Modes:
i40 Ruby 4.0.7 interpreter, y40 4.0.7 `--yjit`, i41 master `9aa0898240` interpreter, z41 the same master `--zjit`.
Objects: `GC.stat(:total_allocated_objects)` over 2,000 calls. Wall time: 5 interleaved rounds, one process per
measurement, order reversed each round ([`ns_run.sh`](../../bench/upstream/rails-open/ns_run.sh)); a cross-check only,
its A/A moves by up to ±6% on this orb. Full tables: [Ir](data/rails-open/ir-table.md),
[ns](data/rails-open/ns-table.md), [objects](data/rails-open/obj.tsv).

## rails/rails#59557 `Array#index_with` with `Hash.new(capacity:)` — L3, kept open (Thomas)

Lib diff +33/−7: a duplicated method behind a `RUBY_VERSION` branch with a five-line comment.

| Per call | Objects main → PR (i41 / z41) | Ir i41 | Ir z41 | A/A |
| --- | --- | ---: | ---: | ---: |
| 3 Strings, block | 4 → 1 / 3 | +16.0% | +45.8% | ≤ 0.07% |
| 8 Strings, block | 9 → 1 / 3 | −1.8% | +16.1% | ≤ 0.03% |
| 50 Strings, block | 51 → 1 / 3 | −12.9% | −1.6% | ≤ 0.08% |
| 6 Strings, default | 7 → 1 / 3 | +2.0% | +30.0% | ≤ 0.04% |
| `post.serializable_hash` (4 attributes) | 10 → 6 / 8 | +2.6% | +11.3% | ≤ 0.16% |

On 4.0.7 the PR is unchanged (Ir within ±0.5%). Wall time agrees (i41 n=3 +11%, z41 +64%; n=50 −18%/−12%).

**Simple variant** (one method, no version branch, no comment, +5/−10): `Hash.new(capacity: size)` and `each` on
every Ruby. Rejected: +21% Ir at n=3 on 4.0.7, +18% on the master interpreter, +43% under ZJIT; it only wins under
4.0.7 YJIT (−9% to −34%). It also fails the PR's Array-subclass tests (an overridden `each`/`size` is used).

**Outcome:** Thomas kept the PR open because ZJIT's part comes with ruby/ruby#19662. The body now says that, with
the master numbers above, and the YJIT row now cites ruby/ruby#19663 (it cited #19662). Before/after:
[before](data/rails-open/pr59557-before.md), [after](data/rails-open/pr59557-after.md).

## rails/rails#59570 `OutputBuffer#<<` without the super dispatch — L2

Lib diff +4/−1, copies `ERB::Util.unwrapped_html_escape`'s two steps and needs its comment.

| Per call | Objects | Ir i40 | Ir y40 | Ir z41 | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| `buffer << "Tom & Jerry <b>"` | 1 → 1 | −16.2% | −16.0% | −0.9% | ≤ 0.06% |
| `buffer << "Tom and Jerry"` | 0 → 0 | −19.9% | −21.7% | −1.5% | ≤ 0.06% |
| `buffer << html_safe` | 0 → 0 | −0.7% | −0.9% | +1.1% | ≤ 0.06% |
| render a 2-local partial | 33 → 33 | −0.95% | −1.94% | −0.19% | +0.09 / −0.81 / +0.24% |

Wall time agrees for unsafe appends (−19% / −13% / −1.5%); the partial render is within its A/A. Simplest variant
(`ERB::Escape.html_escape(value)` directly, +1/−1) is not exact: it fails the PR's tests for a `to_s` that returns a
String subclass (3 failures). The L2 bar (an app or ruby-bench effect) rests on the existing erubi-rails result
(−5.8% / −5–6% instructions, [contributions](contributions.md)). ZJIT gains almost nothing.

## rails/rails#59564 preloader Arrays in place — L1

Lib diff +14/−10 (`map!`, `delete_if`, `concat`, six `.tap(&:uniq!)`).

| Per call | Objects i40 (PR / simple) | Ir i40 | Ir y40 | Ir z41 | A/A |
| --- | --- | ---: | ---: | ---: | ---: |
| `Post.preload(:comments).to_a` (3 posts) | 384 → 374 / 375 | −0.06% / −0.14% | −0.19% / −0.34% | −0.19% / −0.24% | −0.06 / +0.04 / 0.00% |
| `Post.preload(:commenters).to_a` (through) | 757 → 727 / 730 | −0.15% / −0.20% | −0.33% / −0.52% | −0.41% / −0.49% | +0.02 / −0.04 / +0.18% |

**Simple variant** (+10/−6): the PR without the six `.tap(&:uniq!)` (plain `.uniq`). It reads better and saves as
much or more Ir (one object fewer saved). Wall time is noise here (A/A up to ±6%).

## rails/rails#59569 alias tracker only for through chains — L1

Lib diff +5/−3: a lazy `tracker ||= scope.alias_tracker` and `get_chain` takes the scope.

| Per call | Objects | Ir i40 | Ir y40 | Ir z41 | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| `post.association(:comments).scope` (reset first) | 36 → 34 | −8.3% | −6.1% | +0.1% | +0.04 / +0.08 / +1.31% |
| `post.association(:commenters).scope` (through) | 85 → 85 | +0.03% | −0.15% | −0.32% | +0.01 / +0.05 / −0.52% |

Wall time: direct scope −13% / −7% / −10%; through within the A/A. Under ZJIT the Ir gain is within its (noisy) A/A.

## rails/rails#59583 through `stale_state` (opened today) — L1

Lib diff +10/−3, no comment; `instance_of?(String)` keeps String subclasses on the `Array()` path (Astra).
Loaded `comment.post_author`: objects 3 → 1; Ir i40 15,447 → 12,076 (−22%, A/A +0.20%), y40 8,283 → 4,983 (−40%,
+0.02%), z41 7,879 → 4,571 (−42%, +0.03%) ([`ir73.sh`](../../bench/upstream/rails-open/ir73.sh)). AR `test:sqlite3`
10,271 runs, 0 failures; RuboCop clean. Body: [pr59583-body.md](data/rails-open/pr59583-body.md).

## Recommendations

| PR | L | Recommendation |
| --- | --- | --- |
| #59583 | L1 | Open (done). |
| #59569 | L1 | Keep. −6% to −8% of a direct association scope build in interpreter and YJIT; nothing under ZJIT. |
| #59570 | L2 | Keep; the per-append gain is well outside the A/A and the ruby-bench effect exists. ZJIT gains ~1%. |
| #59564 | L1 | Close, or replace with the simple variant. Its gain is at most 0.5% of a preload, within the A/A in the interpreter for a has_many. |
| #59557 | L3 | Kept open by decision; body states the master costs and the ruby/ruby#19662 dependency. No simple variant keeps the gain. |
