# L3 Astra confirmation of the shared helper

**Verdict: approve. Must-fixes: none. Exact replacement text: none. Optional points: none.**

Reviewed `319e55a661702e756a5140aeec2300aa55efa0f4`, one commit on
`088fc0cf61e4ba0c7987decafacc69adb3e22eec`, and the assembled title/body at Lowrail `2d748812`
(saved in `body-reviewed.md`). This was a direct review in thread
`T-01a21daf-ee03-7066-a89d-c542a69e8449`, with no delegation. No queue item or Rails checkout was
edited, and no Rails push or PR action was taken.

## Refactor review

The diff from the previous head changes only `attribute_set.rb`; both tests are unchanged. The
public methods pass their respective Attribute operation to one private `attributes_to_hash` helper.
The helper materializes, takes the same shallow snapshot, visits the same names in index order,
skips the same nil slots and returns a fresh Hash. The yielded operation still runs on the captured
Attribute object, not on a replacement a callback may have written into the live set. It preserves
the state and memoization boundaries verified in the prior pass while removing the duplicated loop.

The helper is actually private (`environment.txt`), and no existing Active Model/Active Record method
has the same name. The only new comment is its RBS signature in the surrounding style. The two public
signatures were already present in the previous head; no explanatory prose comments were added.
The reviewed commit message accurately describes the shared helper and snapshot. The upstream diff
passes `git diff --check`.

## Fresh executed comparisons

Same Ruby 4.0.9 (`3e93b23afc`), SQLite 2.10.2 and dependency bundle as the prior pass. Every base output
below was regenerated; none is merely copied from the earlier approval. `run-probes.sh` retains the
commands and `probe-source-sha256.txt` identifies the unchanged harnesses.

| Check | Base versus exact head |
| --- | --- |
| `defaults_and_caches.rb`, interpreter | 1,540 cases identical |
| Same probe, YJIT | 1,540 cases identical, also identical to interpreter |
| Extended probe | 718 lines identical |
| Earlier adversary | 165 cases identical |
| Cross-payload probe, fresh Marshal/MessagePack payloads from both trees | 5,799 lines identical |
| Legacy Marshal fixtures | 9 cases identical |
| Callable-default repro | Both return David and leave the record at Mary |
| Ciphertext probe | Stable repeated Hash/ciphertext object and Marshal bytes; nil column accessed |
| Five targeted Active Record test files | Base 272 runs / 1,360 assertions; head 274 / 1,364; no failures, errors or skips |

The cache probe covers ordered results, raw Attribute memoization and `@casted_values`, accessed fields,
dirty tracking, errors, and exact unencrypted Marshal/MessagePack bytes. It exercises assignments,
reads, mutation, exceptions, freezing, `becomes`, clearing dirty state, reentrancy and controlled
fiber/thread suspension from callable defaults and custom casts/deserializers/serializers. It includes
new, loaded, assigned, partially selected, warmed, frozen, readonly and Marshal-loaded records, plus
nil/false/String/Array/Hash default results. Of 1,520 callback-matrix cases, 770 reach their callback
during the first operation: 200 defaults, 180 casts, 150 deserializations, 210 serializations and 30
`changed_in_place?` calls. Twenty other cases exercise default return values. Unreached hooks are
controls, not counted as side effects.

The unchanged extended and adversarial probes retain the prior pass's singleton/private-method,
prepend/extend, conversion, subclass, frozen-input/result, coder, returned-object identity, encrypted
record and partial/duplicate-select coverage. See the previous head's README for the full checklist.

`no_snapshot.rb` removes only the helper's snapshot, in memory. That changes **340** new-probe cases
and makes both regression tests fail with expected David, actual Mary. Complete mutant outputs and
changed-case names are retained. The original tests pass on the unmodified head. This confirms that
the new helper still protects both paths, rather than making an unchanged test accidentally irrelevant.

## Assembled body and raw data

`audit.py` checks the saved body against `results/rebuild3-2026-11-27/body-ips.txt` and
`body/L3c-2026-11-27`; full results are in `audit.txt`.

* All four body output lines match in every numeric field, unit and uncertainty. Main's chosen Marshal
  row is round 5 and its database row round 6; head's rows are rounds 3 and 5. All are the respective
  best rows, and the file contains six complete rounds of each side, including the A/A.
* The Ruby version line matches. The example is byte-identical to `l3_ips.rb`: nine column triples,
  id and timestamps give 30 columns.
* Both Hash methods have exact 4/4/2 allocations in the base/base2/head raw object logs, under both
  interpreter and YJIT. The body correctly says two instead of four on materialized records.
* All eight instruction rows were independently recomputed from the N=500 and N=0 Valgrind totals,
  including both base runs. The YJIT counters in every corresponding log are unchanged. These are
  instruction counts, not timings. Callgrind itself was not rerun in this confirmation.

The shortened prose still states the public entry points, why the temporary row is wasted, the
snapshot boundary and why reading from the underlying row would change encrypted dumps. It neither
hides the snapshot nor overstates an app-wide gain. The prior pass directly ran the row-read negative
control; this pass reran the actual ciphertext path and both snapshot regressions. No text replacement
is needed.

The exact body script and the existing 6/30/100-column and 128 MiB serializer probes were rerun with fresh
base/head/base2 controls (`body-ips.txt`, `sizes.txt`, `large.txt`, `performance-summary.jsonl`). They are
short corroboration runs, not replacements for the supplied upstream numbers or a new wall-time claim.
In particular they are not the 30-round interval-gated `--wall` cohort now required by DECISIONS to
classify a timing loss. Raw observations are retained without suppressing noisy rows.

At 6, 30 and 100 columns, all head timing rows exceed both base rows, and both Hash methods reproduce
4/4/2 objects per call. The body's unchanged script gives 36,126 / 39,861 / 36,279 i/s for Marshal and
90,535 / 130,432 / 86,993 for the database Hash (base/head/base2). The worst-input run's best of three
is 6.652 / 6.557 / 6.980 i/s: head -1.43%, A/A +4.93%. That short run does not establish a regression
or a tight bound on one; the serializer dominates. All individual rounds are retained in the summary.

## Current upstream and scope

Fork head still matched the requested SHA. Rails main was
`259e41a8af4c9c8a9252629f6031457fc7d82c30`. The additional commits since the previous pass's
`dbbfb84cec` are saved in `new-main-commits.txt`; none changes the AttributeSet, Attribute, user-default,
IndexedRow, Marshal or Active Record MessagePack files checked (`new-main-paths.diff` is empty).
No new covering change was found. `merge-tree.txt` records a clean merge with current main, not a
test of that merged tree.

Project relevance was refreshed through GitHub and RubyGems metadata (`repo-*.json`, `gem-*.json`):
Rails, msgpack-ruby, sqlite3-ruby and benchmark-ips remain unarchived, with current releases
8.1.4.1, 1.8.7, 2.10.2 and 2.15.1 respectively. Their stars, downloads and release/push dates are kept.
The body has no third-party application reach citations or superseded dependency-version claim;
Rails precedes its MessagePack coder, and the benchmark requires are executable setup.

No new PostgreSQL/MySQL, full-component, master/ZJIT or exhaustive-scheduler test was run here.
The review applies to the exact supplied head and base. It does not adopt the builder's broader runs
as independently rerun evidence.

## Reproduce

Use the same two worktree locations and environment as the previous pass, with the head worktree at
`319e55a661`. `run-probes.sh` and `run-performance.sh` are the executed scripts; adapt their environment
paths for another orb. The shared probe remains at `../head-41af869c78/defaults_and_caches.rb`.
`payload-inputs.tar.gz` preserves this run's fresh payloads and the historical fixtures. For the control:

```sh
ruby -r"$OUT/no_snapshot.rb" "$OLD/head-41af869c78/defaults_and_caches.rb"
RUBYOPT="-r$OUT/no_snapshot.rb" bundle exec rake -C "$RAILS/activerecord" test:sqlite3 \
  TEST=test/cases/attribute_methods_test.rb \
  TESTOPTS='--name=/attributes_.*the_record_had_when_it_was_called/'
python3 "$OUT/audit.py"
python3 "$OUT/performance_summary.py"
```

`sha256.txt` records uncompressed differential-output hashes. Compressed files retain the full raw output.
