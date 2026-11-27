# L3 adversarial Astra review of the repaired head

**Verdict: approve. Must-fixes: none. Exact replacement text: none. Optional points: none.**

Reviewed `41af869c787a33db4cb46149746cf3cabeb896f7`, one commit on
`088fc0cf61e4ba0c7987decafacc69adb3e22eec`. The title and complete body reviewed are saved in
`body-reviewed.md`; the commit and patch are in `reviewed-commit.txt`. This pass ran directly in
thread `T-01a21daf-ee03-7066-a89d-c542a69e8449`, without delegating. No Rails fork, queue item,
PR or comment was changed.

## The earlier approval missed executable user defaults

The parent directory's approval of `f70d3e0917` was wrong: `UserProvidedDefault#value_before_type_cast`
can execute a Proc. That fact is explicit in this pass's probes, rather than inferred from the ordinary
Attribute reader. The supplied callable-default repro now returns `author_name: "David"` and leaves the
record at `"Mary"`, on both base and this head (`default-repro-*.txt`).

Both replacement methods materialize first, duplicate the Attribute-reference Array, then dispatch on
those captured objects in index-key order. Main performs the same capture into an unset row and dispatches
through `IndexedRow#transform_values`. The nil check excludes the slots main leaves unset. Neither method
changes the materialization, cast cache, value memoization or result ownership. The two nullable accesses
also handle a set with no backing Attribute Array. The only added comments are two RBS signatures in the
file's existing style; there are no prose comments to remove. The two public-behavior tests are useful:
each fails when its snapshot is removed, not merely when implementation details change.

## Executed checks

Ruby 4.0.9 (`3e93b23afc`), SQLite gem 2.10.2. This reproduces the supplied 4.0.9 comparison with its own A/A;
it supplies no replacement upstream performance numbers. Dependencies are retained in `Gemfile.lock`.

| Probe | Result on base versus exact head |
| --- | --- |
| New `defaults_and_caches.rb`, interpreter and YJIT | 1,540 cases identical in each mode; also identical across modes |
| Existing `exactness_extension.rb` | 718 output lines identical |
| Existing `adversary.rb` | 165 cases identical |
| Existing `probe.rb`, loading payloads dumped by both exact trees | 5,799 lines identical |
| Historical Rails 6.1 fixtures, both Hashes or generated reader first | 9 cases identical |
| Ciphertext probe | Repeated database Hash and Marshal bytes stable; same ciphertext object; nil column accessed |
| Five targeted Active Record test files | Base: 272 runs / 1,360 assertions; head: 274 / 1,364; no failures/errors/skips |

The new probe records ordered Hash entries, exact unencrypted Marshal/MessagePack bytes, errors, callback
traces, accessed fields, dirty tracking, frozen/readonly state, and the actual Attribute memoization and
`@casted_values` contents immediately after the operation and after generated reads. It does not call
Attribute readers to inspect caches. It exercises new/loaded/assigned/partially selected/warmed/frozen/
readonly/`becomes`/Marshal-loaded records. Callback effects include assignment to two later columns,
in-place mutation, reads, exceptions, freezing, shared writes through `becomes`, clearing dirty state,
reentrant dumping, and controlled fiber/thread suspension. Nil, false, String, Array and Hash default
results are repeated to cover default memoization's falsey boundary.

Of the 1,520 callback-matrix cases, 770 actually reach the callback during the first operation: 200 callable
defaults, 180 casts, 150 deserializations, 210 serializations and 30 `changed_in_place?` calls. The other
cases are controls where that hook is not reached (for example a warm cache or raw-value operation).
Another 20 cases cover different callable-default return values. The report does not count an armed but
unreached callback as a tested side effect.

The inherited probes cover singleton/private methods, prepend/extend, implicit conversion, Array/Hash/
String subclasses, frozen inputs/results, second-call object identity, mutation of returned Hashes,
serialization coders, encrypted records, duplicate/extra selected columns, save/clone/dup, and plain
Active Model objects. Cross-process encryption comparisons normalize random ciphertext to plaintext;
within-record stability is checked before normalization. The legacy fixture check is compatibility
evidence, not a new support claim for that format.

### Negative controls

`no_snapshot.rb` removes only the requested snapshot in memory, without changing a checkout. Removing
the before-type-cast snapshot changes 25 new-probe cases; removing the database snapshot changes 315.
Changed case names and complete outputs are retained. With both removed, the two new Rails tests fail
with expected `"David"`, actual `"Mary"` (`tests-no-snapshots.txt`). Their normal run passes.

The pre-existing row-read alternative changes repeated encrypted Hashes and Marshal bytes from stable
to unstable, loses ciphertext identity, and omits the nil column from accessed fields
(`ciphertext-row-read.jsonl`). That directly checks the body's reason for keeping materialization.

### Limits and exactness checklist

Checked argument/type dispatch and subclasses; implicit conversions; calls to user objects; copied versus
adopted results; mutation and suspension; frozen objects and exceptions; normal standalone Rails loading.
No production/private API override is needed by the ordinary probes. Deliberate method replacement is
confined to the negative controls. No exhaustive scheduler search, arbitrary autoload-order test, new
PostgreSQL/MySQL run, full component suite, or Ruby-master/ZJIT rerun was performed. The builder's broader
runs are not represented as independently executed here.

## Body and measurement audit

`python3 audit.py` checks the saved title/body against the kept evidence. All four IPS output lines match
`results/rebuild2-2026-11-27/body-ips.txt` in every numeric field, unit and uncertainty. The file really
contains six complete main/head/main2 rounds. Main's best rows are round 3; the head's best Marshal row
is round 1 and its best database row is round 6. The Ruby version line matches. The example is byte-identical
to `l3_ips.rb`, and nine triples plus id and timestamps make 30 columns.

The audit independently recomputes all eight `L3b-2026-11-27` instruction rows from the retained Valgrind
N=500 and N=0 totals (not just the summary table), including both base runs. Each YJIT log's three counters
is unchanged. Raw object logs give 4/4/2 for each Hash method in interpreter and YJIT modes. Thus the body's
two-objects-instead-of-four sentence matches the exact-head data. The snapshot-fix README section's
instruction numbers also agree with those logs. Callgrind itself was not rerun in this pass.

The unchanged body script was rerun under YJIT on CPU 1, base/head/base2:

| i/s | Base | Head | Base2 | Head versus base | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| Marshal.dump | 34,443 | 37,050 | 33,544 | +7.57% | -2.61% |
| attributes_for_database | 82,316 | 143,272 | 71,647 | +74.05% | -12.96% |

The short 6/30/100-column sweep also has each head row above both base rows for Marshal and both Hashes,
and reproduces exactly 4/4/2 objects for both Hashes at all three widths (`sizes.txt`). Timing dispersion is
large, reaching 34.73% A/A in that sweep; these are corroborating observations, not new precise speed
claims. Review timing runs did not collect JIT-flat counters. The supplied exact-head benchmark retains
its own controls. The benchmark example's timestamp-bearing record differs from the size probe's schema,
so their absolute Marshal allocation counts are not interchangeable.

Worst input measured: a serializer reversing a 128 MiB string on every call. Best of three interleaved
rounds: base 7.278, head 7.355, base2 7.413 i/s; head +1.06%, A/A +1.85% (`large.txt`). The optimization's
effect disappears into serializer work and noise; no regression is demonstrated, but this is not a tight
bound on a small one. `performance-summary.jsonl` retains every run, not just the best values.

Read the exact-tree Marshal and MessagePack encoders: each calls `attributes_for_database` once per
encoded record. Read the Attribute implementation, user-default implementation, IndexedRow, builder and
lazy set to check the remaining mechanism claims. No wording replacement is needed.

## Upstream overlap and project relevance

Live GitHub search returned 76 PRs merged since 2026-11-25, including stable-branch backports
(`merged-prs.json.gz`). Fetched complete Rails history and inspected the changes in the affected path.
Current main was `dbbfb84cec40d64ef7cf8fdc21e89b98dbdd1a46`; fork head still matched the requested head.
No merged PR covers L3. The keys/materialize change in #59800 is already in the supplied base and leaves
the row copy intact (`merged-keys.diff`). Since that base, #59662 changes default freezability, not either
Hash-building path (`overlap.txt`). The new core-extension requires, SQLite floor and other merges do not
remove this work. The MessagePack missing-class change is in its decoder, not the per-record encoder.
`merge-tree.txt` records a clean merge with current main; that merged tree was not tested here.

The body has no third-party application reach citations. Rails is the affected project; MessagePack,
SQLite and benchmark-ips are its coder or executable benchmark dependencies. Current GitHub and RubyGems
metadata was fetched for each (`repo-*.json`, `gem-*.json`):

| Project/gem | Stars | Gem downloads | Latest release / last repository push |
| --- | ---: | ---: | --- |
| Rails / Active Record | 59,180 | 875,153,352 | 8.1.4.1, 2026-11-04 / 2026-11-27 |
| msgpack-ruby | 788 | 548,521,708 | 1.8.7, 2026-10-30 / 2026-11-19 |
| sqlite3-ruby | 848 | 203,687,545 | 2.10.2, 2026-10-26 / 2026-11-25 |
| benchmark-ips | 1,776 | 91,529,625 | 2.15.1, 2026-05-21 / 2026-06-18 |

None is archived. There is no abandoned project or superseded dependency-release claim to cut, nor an app
list to reorder. The body leads with Rails, then its cache coder. The linked introduction was checked
through #59141's merged record and the current source (`introduced-by.json`).

## Reproduction

Create clean Rails worktrees at the base/head SHAs above, resolve this directory's Gemfile with `RAILS`
set separately for each tree, and use Ruby 4.0.9. `environment.sh`, `run-inherited.sh` and
`run-performance.sh` preserve the exact paths and commands used here; adapt paths for another orb.
Set TMPDIR under `.amp/in/orb-backup/`. `payload-inputs.tar.gz` retains both trees' actual payload inputs
and the three historical SQLite fixtures. The latter came from the parent review's retained archive.

Additional commands, with OUT pointing here and each tree's bundle selected:

```sh
ruby "$OUT/defaults_and_caches.rb"
ruby --yjit "$OUT/defaults_and_caches.rb"
ruby -r"$OUT/no_snapshot.rb" "$OUT/defaults_and_caches.rb"
MUTANT=values_for_database ruby -r"$OUT/no_snapshot.rb" "$OUT/defaults_and_caches.rb"
MUTANT=values_before_type_cast,values_for_database RUBYOPT="-r$OUT/no_snapshot.rb" \
  bundle exec rake -C "$RAILS/activerecord" test:sqlite3 TEST=test/cases/attribute_methods_test.rb \
  TESTOPTS='--name=/attributes_.*the_record_had_when_it_was_called/'
python3 "$OUT/audit.py"
python3 "$OUT/performance_summary.py"
```

The negative controls initially stopped on a probe source-length assertion (12 instead of 11 lines);
the corrected probe was rerun, and only the completed controls are retained. This was a harness error,
not a Rails failure. `sha256.txt` records the uncompressed differential-output hashes.
