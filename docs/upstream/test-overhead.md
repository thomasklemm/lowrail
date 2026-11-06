# P-TEST: the cost outside a Rails test body

2026-11-05–06. Ruby 4.0.9, revision `3e93b23afcec3433f6aecc34b5d832799d754238`.

## Scope and decision

Four real app setups: Campfire and Redmine (Minitest/SQLite), Lobsters
(RSpec/SQLite, four configured databases), and Mastodon (RSpec/PostgreSQL 15
and Redis). These are **warm, small model-test samples**, not an estimate of
the mix of tests in every suite. Application-wide hooks remain enabled; an
empty test measures those hooks too, not just Rails itself.

One candidate, [PT1](../../bench/upstream/pr-queue/items/PT1.md), avoids unused
surviving-pool scans in transactional fixtures. It reaches Minitest and
rspec-rails examples using `ActiveRecord::TestFixtures`. It is **held as a
parked idea**, not an urgent Rails submission. Its small interpreter/YJIT
empty-test wins do not establish a whole-suite benefit: all three full-suite
arms failed the same checkpoint test, and same-base instruction drift was
7.50%. The original lazy-bookkeeping version failed independent order probes
and was withdrawn. The corrected fork branch is retained. No upstream PR,
issue or comment was created.

## Inputs and reuse

Rails main is `1e235cee11b0a7aecb189d8837534807626287aa`; 8-1-stable is
`6e091242176c322edc5a8907583c01b08b8a60bc` (8.1.4.1). PT1 is
`31058914ccf2e4f7b36c3d3d815f9f756b628819`, based on that main, on fork branch
`thomasklemm/skip-unused-fixture-pool-scan`. Its production change was first
committed in `43b20e75ca98e2f776eee19e5fef8cad9cdc0e65`; the follow-up fixes
only the regression test's handler-override restoration. The production
file's SHA-256 is `adb53f4cf5ad0e3b6ea95a477563ac7a8f9e811e717efc1f72a1d79ca0628f1f`.

The measured Lowrail base is
[`7d9866ea2355e0e0c7f69199bd2883c3620b3f94`](https://github.com/thomasklemm/lowrail/commit/7d9866ea2355e0e0c7f69199bd2883c3620b3f94).
The export fingerprints the measured helpers, client extension, Ruby binary
and lockfiles; publication's rebase is not another measurement.

The [app-suite manifest](../../bench/upstream/readiness/round-app-suites.yml),
`Readiness::Round`, `Suite#prepare`, the ecosystem Gemfile wrapper, existing
PostgreSQL/Redis services, and the existing PM1/PM3/CB2
[`percall.sh`](../../bench/upstream/perf_round/percall.sh) are reused. There is
no replacement suite runner. The only new micro workload is
[`cases.rb`](../../bench/upstream/test_overhead/cases.rb).

| App | App commit | Available Rails | Selected existing test |
| --- | --- | --- | --- |
| Campfire | `a05ee908977d8ec97bfce0503c8e689334804d08` | main | `RoomTest#test_type` |
| Redmine | `d9f5f18b65dc7f27509a8eb5ea18fe4a8dab0335` | stable | `EnumerationTest#test_default` |
| Lobsters | `6f6e48f652ff10b8efb84c4882108f07a238340b` | both | `Tag validations allows a valid tag to be created` |
| Mastodon | `da4edd9b8003f54a5815165b5c8193604fbe679d` | both | `Tag HASHTAG_RE does not match URLs with anchors with non-hashtag characters` |

All use Minitest 6.0.6 where loaded. RSpec core is 3.13.5 in Lobsters and
3.13.6 in Mastodon. The existing readiness bumps pin rspec-rails to
`9fb6f4f0a3` and `570b2b0a79`, respectively. Those rspec-rails inputs are held
identical across the two Rails arms; this is not released versus main
rspec-rails. Rails main's required dependency updates remain in the bundles:
marcel 1.2.1 → 2.1.0, added Herb/ractor-dispatch, and added psych/stringio
entries except in Lobsters. The main-versus-stable comparisons therefore
price the Rails dependency set, not a causal isolation of Rails code alone.
The same-base A/A and PT1 arms have identical dependencies.
Campfire/Redmine use sqlite3 2.10.2, Lobsters 2.9.6; Mastodon uses
pg 1.7.0. Mastodon's assets are not compiled: this sample boots its model-test
environment and loads its schema, not its browser suite.

### Unavailable cells, not compatibility projects

* Campfire on 8-1-stable: its `load_defaults 8.2` is rejected.
* Redmine on main: the known insertion before absent `Rack::Sendfile` stops
  boot. The existing app-side compatibility workaround was **not** applied.
* Writebook was attempted as a fifth suite. Stable rejects its `analysis=`
  configuration; on Ruby 4.0.9/main, mini_magick cannot require `benchmark`
  from the bundle. Neither was repaired for this round.

## Measurement contract

The selected class, example name, app helpers, fixtures, callbacks, mocks and
per-example transaction integration are unchanged. A fresh instance is run
each iteration. The empty arm replaces only that test's body. For Minitest
it sets the assertion counter to one without executing an assertion, avoiding
the otherwise artificial missing-assertion warning; `PTEST_EMPTY=literal`
is available as a genuinely empty/warning diagnostic. This is not a claim
that zero-assertion reporting is free. The body arm runs the original test.

Minitest includes `Test#run`, result creation and the Rails per-test reporter.
RSpec includes `Example#run`, the normal per-example hook chain, result
notifications and a fresh example-group instance. Suite/context hooks run
once outside the window, with the context instance variables copied as the
normal group runner does. RSpec's previously run example result is reset
between repetitions. Boot, class discovery, formatter initialization,
suite summaries and worker fork/startup are excluded. Neither this method
nor a subtraction between arms prices parallel process startup.

The finite micro cohort is three independent process repetitions per tree,
200 tests per window; A and independent A/A use the **same Rails commit and
bundle**, alternated within each repetition. The interpreter warms 200
tests. YJIT first warms 2,000, then must show ten consecutive quiet batches
of 200 and unchanged compilation/block/invalidation counters across every
measured window. Rejected cells are retained, not retried for a green gate.

`script/bench-valgrind` builds the existing larger-brk Valgrind. The existing
`bench/callgrind.c` client extension starts instrumentation after boot and
warmup; `rb_ary_cycle` bounds instruction collection. GC is disabled in the
micro windows. The same fixed heap floors in all apps/arms are
1,000,000 / 250,000 / 250,000 / 50,000 / 25,000 slots. Existing
`HeapWindows.prepare_heap` anchors the page targets. Pages and capacities
must not change within a window. A/A below means the largest paired
instruction deviation, as in PM1/PM3/CB2, not a native-time confidence
interval. There is **no wall-time claim**.

### Measurement failures retained

* Bundler's lock-selected version initially used `Kernel.exec`, escaping the
  profiled process. Allocation markers without non-zero Callgrind counts
  were invalid. All accepted runs pin `BUNDLER_VERSION=4.0.20`.
* A client-request dump cannot use `/dev/null`: Callgrind tries to open
  `/dev/null.1`. `percall.sh` now retains actual profiles, checks process
  success, non-zero instructions and an allocation marker, and fails closed.
* The old micro heap's 100,000 slots in pool 2 were below the live Redmine,
  Lobsters and Mastodon boot heap. These are preparation failures, not noisy
  samples. The larger, identical heap above was frozen before cohort 1.
* Simultaneous independent processes against Campfire's same SQLite file
  produced busy errors during an initial whole-suite probe. The correctness
  comparison instead uses an isolated, identical `DATABASE_URL` and serial
  before/after runs. No application test or transaction was changed.
* I added the driver's brk refusal while some shells were already executing
  its previously read loop. Finished worker cohorts then hit a shell
  parse error reading the changed tail: corrected-head YJIT original body
  and dedicated Mastodon, isolated Lobsters and N=10 Lobsters YJIT body
  cohorts. The first two have 9/12 passing worker windows respectively,
  with successful worker exits printed inside the loop, but their
  orchestration did not finish cleanly. They remain diagnostics, not
  promoted cohorts. The already-running cohort-1 matrix was declared before
  these errors; its later Mastodon cells are not retries of the dedicated
  cohort. The current script passes `bash -n` and the positive/refusal probes.
  No workload source was changed for this.

## Results

Completed interpreter empty controls, instructions and objects per test.
Each row is the median of three independent A processes; the independent
A/A is reported separately, not pooled into that median.

| App / Rails | Empty test instructions | Objects | Original body instructions | Status |
| --- | ---: | ---: | ---: | --- |
| Campfire / main | 1,279,813 | 339 | 1,503,402 | Six windows per arm pass heap/mode checks |
| Redmine / 8-1-stable | 1,918,466 | 684 | 2,807,484 | Six windows per arm pass heap/mode checks |
| Lobsters / 8-1-stable | 1,571,326 | 437 | 13,685,805 | Original-body row uses complete isolated cohort |
| Lobsters / main | 1,530,465 | 380 | 15,213,132 | Original-body row uses complete isolated cohort |
| Mastodon / 8-1-stable | 4,420,010 | 1,708 | 4,494,205 | Cohort 1, all twelve windows per arm pass |
| Mastodon / main | 4,448,945 | 1,677 | 4,521,333 | Cohort 1, all twelve windows per arm pass |

| Interpreter control | Largest paired A/A, empty | Largest paired A/A, original body |
| --- | ---: | ---: |
| Campfire / main | 0.191% | 0.103% |
| Redmine / stable | 0.028% | 0.016% |
| Lobsters / both | 0.228% | 0.061% |
| Mastodon / both | 0.042% | 0.047% |

These A/A values describe the observed micro noise; they do not borrow the
request protocol's ±0.1% certification or establish whole-suite variability.

For Lobsters' empty control, main is 2.60% below stable, with fewer objects;
its original Tag-creation example is **11.16% higher** on main. The latter
uses an isolated SQLite database set, with all twelve windows passing and
max paired A/A 0.061%. The earlier shared-database body cohort remains
rejected, not pooled in. This difference is absent from the empty control;
it is not attributed to a cause or proposed as another fix here.

Mastodon's cohort-1 empty control is 0.655% higher on main despite 31 fewer
objects, with max paired A/A 0.042%. Its separately declared dedicated
interpreter controls corroborate the direction: 4,421,332 → 4,445,563 empty
instructions (+0.548%, max paired A/A 0.065%), and 4,489,355 → 4,516,920
with the original body (max paired A/A 0.029%). These cohorts are not pooled.
These are small-example comparisons, not suite effects. Original-body and
empty-control ratios are not a complete additive breakdown: body activity
can change teardown work, and suite startup is excluded. PostgreSQL/Redis
server CPU and external child tools are not counted by the Ruby-process
Callgrind window; SQLite's in-process engine is counted.
Absolute instruction totals across the two adapters are not like-for-like.

The completed Campfire YJIT reference gives 677,652–678,939 instructions per
empty test and 760,416–764,033 with the original body. **Both finite cohorts
are rejected for a production claim:** one of six windows in each cohort
compiled during measurement. The other windows are not a replacement cohort.
The numbers are diagnostic ranges over all six collected windows, including
the rejected one, not accepted speed estimates.

The four-app YJIT matrix is complete, including its rejected cells:

| App / reference cohort | Empty control | Original body | Decision |
| --- | --- | --- | --- |
| Campfire/main | 5/6 windows pass | 5/6 pass | Both cells rejected for compilation; ranges above |
| Redmine/stable | 0/6 pass | 0/6 pass | Heap preparation fails after warmup; no instruction price |
| Lobsters/stable + main | 7/12 pass | 5/12 pass | Entire cells rejected; compilation and original shared-database failures retained |
| Mastodon/stable + main | 12/12 pass | 12/12 pass | Every window flat/fixed; no failed window replaced |

Mastodon YJIT medians, stable → main: **3,511,389 → 3,458,565** empty-test
instructions (−1.50%, 1,709 → 1,678 objects), and
**3,569,365 → 3,518,192** with the original body (−1.43%,
1,716 → 1,685 objects). Max paired A/A is 0.0795% empty and 0.0452% body.
The small main/stable direction differs from the interpreter's; this still
prices the dependency sets, not Rails code alone. PT1's separate,
corrected-source YJIT comparison below is not a replacement for the rejected
Campfire reference cell. No accepted full-suite YJIT price is claimed.

## Component attribution

The phase diagnostic wraps one existing no-argument lifecycle method at a
time with the same Callgrind client requests, after 200 ordinary warm tests.
Thirty dumps per method are summed and the empty-method seam subtracted.
Phases are inclusive; parent-minus-child differences separate transaction
pin/unpin work from the fixture cache and replica-pool scans. They are
attribution, not a separate accepted performance cohort or additive CPU
times. Allocation counts are from the unwrapped total-test windows.

Campfire/main, inclusive instructions per empty test, seam subtracted:

| Component | Instructions | Approximate empty-test share |
| --- | ---: | ---: |
| Transaction setup/teardown, excluding shared-pool helpers | 715,004 | 56% |
| Shared-pool setup and teardown | 45,561 | 4% |
| Other fixture setup/teardown | 65,333 | 5% |
| Other ActiveSupport/app before/after hooks | 347,010 | 27% |
| Remaining Minitest/result/reporter work, by subtraction | 106,905 | 8% |

The last row is a residual, not a separately wrapped assertion/reporting
measurement. The transaction row includes pin/unpin, begin/rollback,
notification and connection cleanup work; it is not all SQL execution. The
empty control prices the same app hooks as the original body, including
WebMock/Mocha, ActionCable cleanup and the app's WebPush pool reset. Removing
those hooks or the transactions would change the test contract.

The same decomposition in all four apps (interpreter instructions per empty
test, rounded; RSpec hook rows exclude the outer ActiveSupport fixture
wrapper). Each column partitions its total; the phases are diagnostic,
not another A/A cohort.

| Component | Campfire/main | Redmine/stable | Lobsters/main | Mastodon/main |
| --- | ---: | ---: | ---: | ---: |
| Transactions excluding shared-pool helpers | 715,004 | 472,090 | 710,223 | 870,706 |
| Shared-pool helpers | 45,561 | 28,264 | 48,038 | 49,149 |
| Other fixture work | 65,333 | 120,185 | 57,855 | 83,534 |
| Other ActiveSupport/app hooks | 347,010 | 1,274,683 | 76,013 | 60,274 |
| RSpec before/after-example hooks and mocks | — | — | 376,381 | 3,080,521 |
| Framework/result/reporter residual | 106,905 | 23,244 | 261,955 | 304,761 |

Fixtures account for about 65% of Campfire's empty test, 32% of Redmine's,
53% of Lobsters', and 23% of Mastodon's. Redmine's other ActiveSupport/app
hooks account for 66%; Mastodon's RSpec hooks/mocks account for 69%. RSpec's
mock setup/verify/teardown are already included in the RSpec row (about
13,709 instructions in Lobsters and 104,621 in Mastodon), not additive.
These are hook boundaries, not proof that upstream RSpec owns all that cost:
configured app hooks and DatabaseCleaner run there too. No hook was removed.

## Candidate: skip the unused surviving-pool scan (PT1)

Plain reading of the changed code:

1. Set up, save and restore pools in exactly main's existing order.
2. Clear the saved state, as before.
3. If no saved role/shard mapping disappeared, there is nothing to disconnect;
   return without collecting all surviving pool configs.
4. Otherwise run main's existing orphan-disconnection code unchanged.

This does not remove begin/rollback, pin/unpin, fixture-cache validation,
notifications, sharding or replica restoration. The production change adds
one guard and a blank line, with no ordering state, helper, comment or cache.
The common path still allocates the saved-map entries main needs to remember
shard order; only the final unused scan and its arrays disappear.

Corrected production diff, Campfire empty model test, interpreter medians:
**1,279,555 → 1,263,806 instructions (−1.23%), 339 → 325 objects**. All nine
windows pass fixed-heap/mode checks; max paired A/A is 0.113%, versus the
1.23% effect. With the original body, 1,504,097 → 1,488,501 instructions and
369 → 355 objects. The separate corrected-head YJIT empty cohort is complete:
678,537 → 665,612 instructions (−1.90%), about 340 → 326 objects, all nine
windows flat/fixed, max paired A/A 0.117%. The original-body YJIT workers
also finish flat/fixed (761,448 → 748,847 instructions), but their driver-tail
error above prevents promoting that cell. These per-test figures are not
whole-suite figures and do not clear the impact gate.

### Withdrawn variant and ordering regression

The earlier head `75ff72edf42381d97398281399c0878c5e8cb08a` saved a shard only
when replacing a reader. That changed restoration and orphan-disconnection
order: visit writing shards `a,b`, initially with reader `b`; add reader `a`
mid-test and repeat setup. Main restores/disconnects `a,b`, the lazy variant
`b,a`. Coordinator-run Sol and Astra independently reproduced this over two
cycles. The first skeptical pass missed it by normalizing saved-map order.
Its approval is withdrawn, not silently carried to the corrected head.

That variant measured 1,279,206 → 1,255,322 interpreter instructions and
339 → 322 objects. Those are **defective-source diagnostics**, not evidence
for the current item. The correction deliberately gives up that extra saving
rather than adding a second mechanism to preserve insertion order.

### Exactness checks

The standard Campfire runner, seed 4242, `PARALLEL_WORKERS=1`, on main and
the candidate both produce **649 tests, 3,921 assertions, zero failures,
zero errors, two skips**. An independent observer records each test identity
in execution order, assertion count, failure class/message and transaction
SQL (`BEGIN`, `ROLLBACK`, savepoints, commit/release). The two 649-row streams
are byte-identical, including 3,058 transaction SQL entries. An independent
deliberate assertion failure after a fixture update, followed by a clean
test, preserves the failure message, reporter output (`F.`) and rollback
isolation.

Rails' SQLite tests pass on the corrected branch: fixture infrastructure
11 tests/26 assertions, fixture behavior 142/1,067, multiple databases
21/77; together, **174 tests/1,170 assertions, no failures/errors/skips**. Existing
cases cover replica aliases, non-default shards, restored roles, removed
roles and disconnecting orphaned pools. Fixture infrastructure also passes
with `ARCONN=sqlite3_ractor`: 11 tests/26 assertions. The new regression test
records real handler/manager/configuration restoration and disconnection,
calls the actual operations, and asserts both late-reader orders. It passes
main and the corrected head and fails the lazy variant on both outcomes.
It restores the original isolated-execution-state handler override, including
the unset case, rather than leaving an explicit default override installed.

### Full-suite cohort finished, rejected; PT1 parked

One serial main/A/A/candidate cohort ran the normal Campfire non-system CI
target, `bin/rails test --seed 4242`, with `PARALLEL_WORKERS=1`, GC enabled
and an isolated SQLite database. All five pools stayed fixed in every arm;
starting capacities match within the existing one-page gate. The frozen
floors were 4,000,000 / 1,500,000 / 750,000 / 150,000 / 75,000, with
`RUBY_GC_HEAP_GROWTH_FACTOR=1.01`. These oversized experimental heaps are not
a production tuning recommendation.

**All three processes exited 1:** 649 tests, 3,921 assertions, one failure,
zero errors and two skips each. The failure is identical on unmodified main,
its independent A/A and PT1:
`SqliteWalCheckpointTest#test_a_contender_thread_takes_over_checkpointing_after_the_lock_holder_stops`
expects `:busy`, receives `:checkpointed`. Its native child holds a file lock
for 250 ms; the parent starts a contender thread before making that assertion.
The unchanged native suite passes, as do the earlier smaller-heap Callgrind
runs. No timeout, test body or test selection was changed to obtain green.

The following are **rejected-cohort diagnostics, not a passing-suite price**.
Instructions use the client dump's trailing `totals:`, excluding the small
finish fringe in the process-exit counter. Per-test means include both skips.

| Arm | Whole-window instructions | Instructions/test | Objects in window | GC segments |
| --- | ---: | ---: | ---: | ---: |
| Main A | 81,742,872,394 | 125,952,038 | 17,808,466 | 3,529 |
| Same-base A/A | 75,616,137,686 | 116,511,768 | 16,173,417 | 3,349 |
| PT1 | 71,059,463,088 | 109,490,698 | 14,920,982 | 3,220 |

Raw A/A changes by **−7.495%**; PT1 is **−13.070% versus A**, but only
**−6.026% versus the second baseline**. The same-base allocation drift alone
is 1,635,049 objects. The cause of that drift was not isolated. A numerical
reduction against A is not an accepted whole-suite effect: the test gate
fails in every arm, and there is no stable whole-run reference. In particular,
**this is not a 13% suite speedup**. No window is removed, rescored or retried.
PT1 stays `held`, with “parked idea” in the note, and its branch is kept.
Sol/Astra on this head are not requested on the strength of these counts.

The bracket is Minitest's `run_all_suites`. It covers all tests but excludes
app boot, discovery, executor startup/shutdown and the final summary; it is
not the entire CI process or the separate browser/system job. There is no
whole-suite YJIT or wall-time speed claim.

Earlier failures remain separate: the first GC-enabled window grew pools
0–2 (58,780,896,545 client-dump instructions), and a native larger-heap probe
still grew pool 1 by four pages. The next native preflight held all five
pools at the final floors above. Its first Callgrind attempt was aborted
before a dump: the kernel's 00:04:58 UTC memory-cgroup OOM record names PID
69066. The finished cohort followed the required app-control matrix rather
than overlapping those profilers. None of the rejected attempts supplies a
replacement accepted arm.

### Readability and remaining review gates

Flog 4.9.4: setup 30.5 unchanged, teardown 27.1 → 28.5. RuboCop 1.92.2,
default metrics: setup ABC 21.31 unchanged; teardown ABC 22.29 → 23.43,
cyclomatic 8 → 9, perceived 9 → 10. The rise is the single explicit early exit;
it cuts an unused scan without introducing state.
These are metric observations, not a clean-lint claim.

The narrowed production head's skeptical review found no demonstrated
blocker: ten explicit ordered scenarios, 500 ordered mutation traces, live
SQLite replica/shard/thread and handler self-proxy probes, and pinning
failures. The new late-reader regression passed 100/100 times on main and
the narrowed head, and failed 100/100 on the withdrawn head. The review's
test-isolation nit was fixed separately; the exact final head passed the
focused recheck with unset/nil/direct/Ractor overrides, injected assertion
and setup failures, and repeated cycles.
The private early-path return intentionally changes from `[]` to `nil`;
no inspected Rails/rspec-rails caller consumes it. No actual-worker-Ractor,
PostgreSQL/MySQL candidate certification is implied.
Sol/Astra on the corrected head and Ruby master/ZJIT remain coordinator
gates if the idea is revisited with sufficient impact; they were not run for
this parked idea. This thread does not infer passes from the old head or
from 4.0.9/YJIT.
Both reported fork smoke checks passed on the final head: `rails-new-docker`
and `Devcontainer smoke test`. This is not a hosted full Rails test matrix.

## Other leads: one line each

* `fixtures :all`: globbing/accessor generation is class-load work, not per
  warm test; don't multiply it by the number of tests.
* Fixture set lookup: array/hash copies defend mutable class configuration;
  no cache-key shortcut without an invalidation proof.
* Minitest setup/teardown dispatch: current main still dispatches the hook
  lists dynamically; unrolling would alter mutable hook-list/dispatch
  behavior for a small share of the app sample, so not built.
* Minitest assertions/reporters: the real passing assertion body and the
  empty control differ, but no demonstrated large exact upstream change.
* rspec-rails fixture opt-out is already the subject of
  [2869](https://github.com/rspec/rspec-rails/pull/2869); discovery globbing is
  already covered by [2914](https://github.com/rspec/rspec-rails/pull/2914).
* Lobsters enables both Rails transactional fixtures and DatabaseCleaner;
  removing either changes configured isolation, and deletion/truncation
  metadata must still work. This is not an exact generic upstream shortcut.
* DatabaseCleaner's empty `connection.transaction {}` has a connection-setup
  contract across supported Rails versions; removing it was not certified.
* Mastodon's global DNS/Paperclip mocks, Redis/cache cleanup and route hook
  belong to app-wide hooks too; they are not all Rails fixture overhead.
* Rails parallel teardown correctness is already covered by
  [59459](https://github.com/rails/rails/pull/59459); no compatibility work here.
* PostgreSQL cancellation/pool cleanup already has
  [47499](https://github.com/rails/rails/pull/47499); no duplicate lead.
* Integration sessions and system-browser helpers were read but not priced
  by these model-test samples; no claim that either is negligible.

Searches checked current Rails main, minitest main
`4f8b722a08ce19df32c56930cc27eaf12f0c23e3`, rspec-rails main
`542ed318328bde7d4d76d26c3de327a4595ff430`, open and closed PRs, the
[contributions ledger](contributions.md) and [census backlog](census-backlog.md).
No overlapping unused-replica-cleanup optimization was found. The original
orphan-cleanup change, `dd6f1c2245b9b617448d632c678b47ecb3fcf51f`, is preserved.

## Reproduction and retained evidence

The [machine-readable evidence export](../../bench/upstream/test_overhead/evidence.json)
retains **475 windows across 52 cohorts**, instructions, objects, heap/JIT
observations, log hashes and rejected cohorts, plus twelve distinct lockfile
contents and the deduplicated exact 649-row outcome/transaction stream.
A valid window is not an accepted cohort: any failed window rejects its
whole finite cell. Diagnostic/preflight cohorts are not pooled into the
specified app controls or the corrected-head candidate cohort.

Preparation reuses `Readiness::Round` and `Suite#prepare` with the app/ref
table above. Set the candidate Rails pin to the recorded main, remove
`share_base` for independent trees, and use Ruby 4.0.9. Add Campfire's pinned
entry with `bin/rails db:prepare`; Mastodon's model sample uses schema load
instead of assets/browser setup. Only the existing database configuration
and Ruby-version setup are used, not the compatibility-shim variants.
Independent A/A wrappers use the same lock file and app symlink; only their
Rails path differs for the stable/main or main/candidate comparison.

After preparing those wrappers, the measured Campfire interpreter command is:

```sh
source /tmp/ptest/env.sh campfire
export BUNDLER_VERSION=4.0.20 PERFCALL_STATE=1 PERFCALL_CLIENT=1
export BENCH_CALLGRIND_EXTENSION=/tmp/ptest/lowrail_callgrind.so
export VALGRIND=/tmp/ptest/vg-client
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000
export RUBY_GC_HEAP_2_INIT_SLOTS=250000 RUBY_GC_HEAP_3_INIT_SLOTS=50000 RUBY_GC_HEAP_4_INIT_SLOTS=25000
export WARMUP=200 PTEST_YJIT=0 BENCH_JIT=0 RUBYOPT=--disable-yjit PTEST_EMPTY=1
OUT=/tmp/ptest/results/new-interpreter-empty bash bench/upstream/perf_round/percall.sh \
  bench/upstream/test_overhead/cases.rb test 200 3 \
  /tmp/ptest/measure/campfire-cand-a /tmp/ptest/measure/campfire-cand-b /tmp/ptest/measure/campfire-scan-a
```

The Valgrind wrapper adds `--instr-atstart=no --smc-check=all-non-file` to the
pinned 512-MiB-brk tool. The extension is built from `bench/callgrind.c` with
Ruby 4.0.9 headers and `Init_lowrail_callgrind`. For YJIT, change the warmup
to 2,000 and set `PTEST_YJIT=1 BENCH_JIT=1 RUBYOPT=--yjit`; use a new output
directory and keep the ten-quiet-batch gate. `PTEST_EMPTY=0` keeps the original
body. Other app selections are the table's class/file/full example name.

For the isolated Lobsters body control, point all four named database URLs
at a disposable database set, prepare it with the existing app setup, and
use that same set across serial arms. The validated URL mapping is
`PRIMARY_DATABASE_URL=sqlite3:/tmp/ptest/lobsters2-primary.sqlite3`,
`CACHE_DATABASE_URL=sqlite3:/tmp/ptest/lobsters2-cache.sqlite3`,
`QUEUE_DATABASE_URL=sqlite3:/tmp/ptest/lobsters2-queue.sqlite3`, and
`RACK_ATTACK_DATABASE_URL=sqlite3:/tmp/ptest/lobsters2-rack-attack.sqlite3`.
Do not share these files with a second driver.

For phase attribution, set `PTEST_PHASE` to the method name (prefix
`example.` for RSpec's example hooks), `PTEST_PHASE_WARMUP=200 WARMUP=0`, and
run `irm.rb` with N=30 under `--instr-atstart=no`, **without** the cycle
collection toggle or `PERFCALL_CLIENT`. Each wrapped method dumps one region;
sum all 30, subtract the matching `ptest_seam`, and do not price these as
accepted performance windows.

The full-suite command uses `suite_window.rb` with the same larger heap in
all three serial arms, `DATABASE_URL` pointing at an isolated prepared
SQLite database, and `bin/rails test --seed 4242`. No micro warmup or disabled
GC is applied to that standard suite. Keep `PARALLEL_WORKERS=1` explicit.
Never run the suite alongside other profilers in this 8-GiB orb.

Validation of the driver rejects zero instruction counts, a missing object
marker, failed processes and brk overflow; a positive fake output succeeds.
The default runner and its opt-in interpreter instrumentation both perform
exactly 13 calls for eight warmup plus five measured iterations. That scratch
probe was deleted. Ruby syntax checks and `bash -n` pass. The ordinary
per-call defaults remain unchanged; heap floors and client/state checks are
opt-in for this workload.
