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

## Ownership-safe rework (2026-11-08) — close recommended

Revisited [the preloader PR](https://github.com/rails/rails/pull/59564) after
[tenderlove's inline review](https://github.com/rails/rails/pull/59564#discussion_r4507386824).
GitHub dates the COMMENTED review to **2026-11-08 18:58:37 UTC**, not November 7.
The objection is valid: the published code adopts `immediate_future_classes` as an accumulator and mutates
`likely_reflections` results. A callee's present implementation does not establish ownership in its caller.

**Outcome: recommend closing, not updating.** The ownership-safe rewrite passes the focused behavior checks,
but both interpreter instruction changes are smaller than A/A movement. The YJIT measurements compile during
the counted windows, so they cannot establish a qualifying win. No Rails force-push, body edit, reply or closure
was performed; the PR remains at
[`2fb737482f`](https://github.com/thomasklemm/rails/commit/2fb737482fa9d03e3bbb35586edda131b42e6bdf).
The [queue item](../../bench/upstream/pr-queue/items/PR59564.md) preserves the live body, not a proposed replacement.

### Rework considered

The PR was rebased locally onto Rails main
[`bc0ce44b23`](https://github.com/rails/rails/commit/bc0ce44b239b5a45e8add556f92bbc210abb3597).
The measured rewrite is uncommitted and unpublished. Its complete `git diff upstream/main --binary` SHA-256 is
`42eefa14216571a1f81d6055c7270d845612c6c10adf0892b7e36f3613283fb8` (+8/−5 across the two preloader files).

Cold read, one responsibility per line:

* Concatenate immediate and child classes into a new Array, deduplicate it in place, and return the Array.
* Keep `likely_reflections.reject` in both callers; map target classes in the fresh rejected Array.
* Flatten runnable loaders, then delete already-run loaders from that fresh Array.
* Collect future classes for the batch, then map and deduplicate the collected Array in place.
* Partition branches, then append finished branches' children to the newly built in-progress group.

In particular, `future_classes` becomes:

```ruby
def future_classes
  classes = immediate_future_classes + children.flat_map(&:future_classes)
  classes.uniq!
  classes
end
```

The final return is necessary because `uniq!` returns nil when nothing is removed. Neither helper results nor
loader/child Arrays are adopted as mutation receivers. No new upstream test was added for allocations or other
implementation details.

### Measurement

Ruby **4.0.9**, revision `3e93b23afc`, interpreter and `--yjit`, on the same build and dependencies in both trees.
The unchanged [`cpu_open.rb`](../../bench/upstream/rails-open/cpu_open.rb) creates three authors, three posts and
two comments per post; each workload warms for 3,000 calls. Objects are `GC.stat(:total_allocated_objects)` over
2,000 calls. Instructions are Callgrind's **5,000-call count minus its 0-call count, divided by 5,000**, with
`--collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file=/dev/null`, plus `--smc-check=all` for YJIT.
This is a fresh comparison, not a comparison with the historical Ruby 4.0.7 table above. No ZJIT remeasurement
was needed after the update criterion failed.

Initial-slot settings alone did not retain a fixed heap: the first direct interpreter main window
grew eden pages from `459/72/177/10/7` to `695/473/947/272/7`. That preliminary attempt was **rejected**, not pooled.
For one replacement finite cohort, an Array#cycle wrapper calls the existing `HeapWindows.prepare_heap` before
entering the measured C method, keeps its anchors alive, disables GC again, and snapshots pools/GC/JIT before and
after `super`. Preparation and snapshot work are outside the collected region. The workload and its warmup are
unchanged. Heap floors, identical in all arms, are `3000000/1000000/1000000/300000/20000` slots for pools 0–4;
every window starts with `1833/1223/2451/1478/199` eden pages. Data limit is unlimited.

All **24 replacement windows** have zero measured GC-count change, unchanged per-pool eden/total-allocated-page
counters, and no brk overflow. Main, one repeat of main, and the rewrite each run once at N=0 and N=5,000 for both
workloads and both modes. Worker concurrency was raised from two to four within this finite batch after checking
memory; no workers were retried or selected. No wall-time result is claimed.

Valgrind was built with `script/bench-valgrind`: 3.19.0, the pinned 512 MiB brk patch, source SHA-256
`dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02`, patch SHA-256
`ab95c4a3c2ffae1db00116ff550b19f1f30f3ae3333349779c221d1fb55f84d1`, Callgrind binary SHA-256
`58fff2840b00bc424c88114678fedc1651507aa4543c12c81b989394c5d92c04`, GCC 14.2.0, glibc 2.41.

| Workload | Mode | Main instructions/call | Rework instructions/call | Rework Δ | Repeat main Δ | Objects main → rework |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `Post.preload(:comments).to_a` | Interpreter | 1,627,780.9132 | 1,627,578.9042 | −0.012410% | +0.013097% | 362 → 356 |
| `Post.preload(:commenters).to_a` | Interpreter | 3,137,222.5054 | 3,136,720.6056 | −0.015998% | +0.028607% | 724 → 706 |
| `Post.preload(:comments).to_a` | YJIT, **not flat** | 713,569.8462 | 712,659.3510 | −0.127597% | −0.106408% | 368 → 362 |
| `Post.preload(:commenters).to_a` | YJIT, **not flat** | 1,467,964.9248 | 1,464,542.7420 | −0.233124% | +0.104645% | 741 → 723 |

The interpreter savings are **202.0090** and **501.8998** instructions/call, against A/A movements of **213.1884**
and **897.4592**. Object savings are real, but do not establish the CPU gain required to pursue the update.
The YJIT rows are raw observations, **not admissible speed evidence**: all six 5,000-call windows compile blocks.
The through YJIT delta is larger than its A/A, but its compilation differs materially between arms (79/103/10 new
blocks for main/repeat/rework), so it does not rescue the result. No warmup adjustment or rerun was made to seek a
passing JIT gate.

<details><summary>Raw Callgrind counts and JIT compilation</summary>

Every interpreter N=0 count is 2,302; every YJIT N=0 count is 2,677. All N=0 JIT compilation deltas are zero.
Objects on the A/A arm equal main in every row.

| Workload | Mode | Arm | N=5,000 count | New compiled blocks in counted window |
| --- | --- | --- | ---: | ---: |
| Direct | Interpreter | Main | 8,138,906,868 | — |
| Direct | Interpreter | Repeat main | 8,139,972,810 | — |
| Direct | Interpreter | Rework | 8,137,896,823 | — |
| Through | Interpreter | Main | 15,686,114,829 | — |
| Through | Interpreter | Repeat main | 15,690,602,125 | — |
| Through | Interpreter | Rework | 15,683,605,330 | — |
| Direct | YJIT | Main | 3,567,851,908 | 21 |
| Direct | YJIT | Repeat main | 3,564,055,414 | 9 |
| Direct | YJIT | Rework | 3,563,299,432 | 32 |
| Through | YJIT | Main | 7,339,827,301 | 79 |
| Through | YJIT | Repeat main | 7,347,508,044 | 103 |
| Through | YJIT | Rework | 7,322,716,387 | 10 |

</details>

### Behavior and review

Commands run from the rewritten tree's `activerecord` directory with an external component-only bundle and
SQLite in-memory (same dependency versions and Ruby for the main control):

* `bundle exec ruby -w -Itest bin/test test/cases/associations_test.rb --seed 1729`:
  **141 tests, 557 assertions, 0 failures/errors/skips**.
* `bundle exec ruby -w -Itest bin/test test/cases/associations/eager_test.rb test/cases/associations/nested_through_associations_test.rb test/cases/associations/cascaded_eager_loading_test.rb --seed 1729`:
  **304 tests, 1,147 assertions, 0 failures/errors/skips**.
* `bundle exec ruby -w -Itest bin/test test/cases/associations_test.rb test/cases/associations --seed 1729`:
  **1,822 tests, 6,407 assertions, 1 failure, 0 errors/skips**, identically on main and rework. The sole failure is
  `HasManyThroughAssociationsTest#test_create_new_owner_with_counter_cache_and_partial_inserts_disabled`, line 97:
  expected counter cache 1, actual 2. This is not a green whole-associations result; the failure is unchanged on base.
* RuboCop 1.90.0 on `branch.rb` and `batch.rb`: **2 files inspected, no offenses**.
* A temporary public preload probe with frozen `immediate_future_classes` and `likely_reflections` results checks
  direct, through and nested record contents/order. Main and the rewrite pass; the old PR raises `FrozenError`
  from `future_classes`'s `uniq!`. No allocation-count assertion was added to the upstream suite.

Readability is L1 at most. Flog / RuboCop ABC / cyclomatic / perceived complexity, main → rework:

| Method | Flog | ABC | Cyclomatic | Perceived |
| --- | ---: | ---: | ---: | ---: |
| `Branch#future_classes` | 8.2 → 7.3 | 5.1 → 5.2 | 2 → 2 | 2 → 2 |
| `Branch#target_classes` | 24.1 → 24.1 | 14.76 → 14.76 | 7 → 7 | 8 → 8 |
| `Branch#runnable_loaders` | 6.2 → 6.2 | 3.61 → 3.61 | 3 → 3 | 3 → 3 |
| `Batch#call` | 51.1 → 48.7 | 30.25 → 30.25 | 14 → 14 | 14 → 14 |

The 0.1 ABC increase is the local assignment needed to return the Array rather than `uniq!`'s nullable result.
A skeptical Medium subagent reviewed the exact uncommitted diff, current PR body, behavior logs and complete
interpreter results: **no must-fix code finding; recommend closure**. It independently recalculated both
interpreter effects and rejected the available YJIT baseline for compilation. The remaining raw YJIT rows were
then checked by the author; they fail the same gate. The current body describes the old implementation and its
old Ruby 4.0.7 evidence, and its ownership claim would need replacing if the PR were pursued. No Sol, Astra or
Claude Code approval is claimed for a new upstream head; no new upstream head or text was published.
