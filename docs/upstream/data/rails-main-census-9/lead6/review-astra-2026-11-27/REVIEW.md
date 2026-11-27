# L6 independent Astra review, 2026-11-27

Verdict: **changes (body only)**. No demonstrated in-contract code regression.

Reviewed head: `8b1c6428ea056b3c5983372d85b85615ae3d3f45`.
Base: `088fc0cf61e4ba0c7987decafacc69adb3e22eec`, including K1.
The fetched Rails main was still that base. Exactly one commit, four lines replaced in one file;
no new comments, guards, tests, or other upstream files. `reviewed.diff` and `reviewed-body.md`
preserve what was reviewed. The queue item was not edited.

## Must-fix: scope the call-count claim to the measured update

The body says:

> Saving a record runs both for every attribute: dirty tracking calls `#keys` three times, and `#[]` once for each attribute it checks.

This is too broad. `probe.rb`, on both base and head, records three `#keys` calls for an update
of a loaded record, but only one for `update!` on a new record (which inserts it). The original
30-column caller probe confirms the measured update has three `#keys` calls and 38
`attribute_changed?` calls to `#[]`, plus three other `#[]` calls. Those are not counts for
every save.

Replace that sentence exactly with:

> In the measured `update!` of one column, dirty tracking calls `#keys` three times and `#[]` once for each attribute it checks.

No head change is needed. This replacement has been checked against `callers-base.txt` and
`callers-head.txt`; it does not claim a fixed count for arbitrary callbacks or new records.

## Optional point: refresh the wall-time evidence before choosing the presentation

The decision to retain the instruction table rather than lead with benchmark-ips is explicitly
recorded in the item and census record, so this is not reopened as a must-fix. However, its
justification uses the November 17 comparison, before K1 merged. Three new interleaved
base/head/base rounds on the current pair are retained here. For `update!`, their best rounded
rates are 5,569 / 5,910 / 5,621 i/s: an encouraging signal, unlike the old inconclusive result.
The other two cases do not convincingly separate from the control spread and individual-run
noise. These exploratory runs **do not record JIT-flat windows**, so none is a publishable
speed claim. If a benchmark-ips lead is wanted under DECISIONS, run the current pair through
`script/upstream-bench --ips` and its gate; do not copy these rates into the body.

## Exactness evidence

Ruby 4.0.9, revision `3e93b23afc`, same dependency versions on both trees.

* `bench/upstream/k1/keys_probe.rb`: **6,959 lines identical**, empty `keys.diff`. This exercises
  ordinary, partial and extra-column records, custom types, defaults, dirty state, serialization,
  STI, `becomes`, frozen records, duplication and the 6.1/7.1 record Marshal formats.
* Independent `probe.rb`: 90 observations per side. Fresh, read, written, frozen, duplicated,
  cloned, directly marshaled, materialized and subclassed sets; missing, Symbol, nil, Integer,
  false and String-subclass keys; callback-bearing Hash/Array subclasses; mutation during
  index lookup, including a suspended Fiber and a coordinated writer Thread; `becomes` with
  an extra attribute and shared writes, Marshal and freeze; new and loaded saves.
  All differences are the deliberately overridden nodoc helper calls described below.
  Object addresses in the direct-set Marshal output are normalized, not compared across
  processes. Directly marshaling the private set exposes the same sentinel-object behavior on
  both sides; that is not evidence of a regression. Public record Marshal checks match.
* **Excluded differences reproduced, not concealed:** on a materialized set, overriding
  `indexes`, `index_for_name`, `lookup` or `attribute_at` to raise changes `#[]` from raising to
  returning the attribute. Overrides of `index_for_name` and `lookup` also change `#keys`.
  `probe.diff` contains them. The class is `:nodoc:` and DECISIONS explicitly accepts these
  override differences. No Rails subclass of `LazyIndexedAttributeSet` was found.
  `ReindexedAttributeSet` is an independent delegating class, not its subclass; legacy
  `LazyAttributeSet` also is not its subclass. Their distinct lookup implementations are
  not bypassed by this patch.
* The custom index's `[]` callback still runs before the attribute-array read. Mutating the
  array reference there, including through the Fiber/Thread, gives the same result and call
  events. No new snapshot, cache, conversion, load, configuration read, or user callback is
  introduced. Existing callback sites in the helper bodies remain; nodoc helper dispatch is
  what disappears. This is not a general concurrency proof for unsynchronized model writes.
* `attribute_set_test.rb`: **44 runs, 103 assertions, zero failures/errors/skips on each tree**.
  Logs retained. The full Active Model and Active Record suites were not rerun in this pass.

## Claims and value

`audit_numbers.py` independently reads the archived Callgrind `totals:` lines, subtracts N=0,
divides by N, averages the two base runs, and compares every result to `results.json` in all
four November 27 run directories. It also reads the object logs, checks for brk overflow, and
compares recorded JIT counters. `numbers.txt` retains the output.

The body's six integer cells reproduce after rounding: 1,456,136 / 1,395,418;
712,038 / 681,893; 191,400 / 178,771. The 102-column update reduction is 7.8%; the
30-column YJIT update and load/dirty-check reductions are 2.2% and 2.4%. All six
windows in each claimed YJIT row have unchanged, present counters. Object differences
on the update path are within the base/base spread; the other object counts are equal.
The benchmark really has 30 columns (id + 27 + timestamps), or 102 (id + 99 + timestamps).

These are **recalculations from kept raw runs**, not new Callgrind executions in this orb.
The new benchmark-ips runs are exploratory, with a base/base control, and not JIT-gated.
The ZJIT archives reproduce too, but their missing `invalidation_count` still prevents a
JIT-flat claim. The body makes no ZJIT claim. This pass does not certify the record's broad
“No ZJIT loss” wording as a guarantee about other warmup/compilation states.

The instruction reduction is not just a JIT compiler preference: interpreter reductions
of about 4–8% occur on complete common update/dirty-check operations, with small A/A spread,
and the claimed YJIT instruction reductions are independently gated. The diff is readable
local inlining (L1), with no new mechanism. A maintainer may still reject micro-optimizations,
but there is no demonstrated basis to reject this as a niche path or a JIT workaround.
No time or allocation improvement should be inferred from the instruction table.

`#fetch_value_at` already accesses `@attributes` directly. The introduced PR and current
source support the history and mechanism statements. The new-record call-count exception
above is the one body claim that needs narrowing.

## Currency, relevance and overlap

The body cites only Rails and its introducing PR, not outside apps or gems. Live GitHub and
RubyGems responses are retained: Rails was unarchived, 59,174 stars, pushed November 27;
the rails gem had 823,128,659 downloads and latest version 8.1.4.1 released November 4.
There is no multi-project ordering or stale caller-version citation to fix. The change is
explicitly on Rails main, not a patch to that stable release.

`recent-merged.json` contains the live search for merged Rails PRs since November 25.
The fetched current main equals the reviewed base; the only change to this file in that
interval is the K1 merge. Its retained helper calls are exactly the lines replaced here.
The merge-tree check is clean. No subsequent merged change already covers L6.

## Reproduction and delivery scope

`commands.sh` records the executed test/measurement forms. Detached worktrees live under
`.amp/in/orb-backup/l6-review/{base,head}` at the SHAs above. Retained Gemfiles and lockfiles
use those trees; base/head differ only in the local framework paths. Install their gems with
Ruby 4.0.9 before rerunning. The first custom probe draft needed its Builder constructor and
ExtendedIndexes setup corrected; the retained probe and outputs are the completed runs.
Initial suite setup lacked the Rails Minitest plugin path; the retained passing commands
include `railties/lib` and the required test gems.

Only this evidence directory is committed. No fork push, PR opening, upstream comment,
queue-item edit, delegation, or other thread creation was performed.
