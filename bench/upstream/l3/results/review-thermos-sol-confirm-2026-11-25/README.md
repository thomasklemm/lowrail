# L3 Thermos-sol confirmation, 2026-11-25

**Verdict: approve. No remaining must-fix or new nit.** The amended head restores the pre-serialization snapshot, the public-behavior regression test earns its place, both component suites pass, and the independently rerun performance gain survives. The body's absolute i/s differ from this cohort; replacement output and the deliberately least-beneficial measurements are retained below.

Both Thermos rubrics were loaded and applied by this reviewer in this thread, as requested. No delegation, Rails edits or pushes, PR actions, or queue-item edits. This is fresh execution on the amended commit, not certification carried forward from another head.

## Pins

* Rails head: `cf1607c76d4974df18bfb06315f695d1bac2c0ad`, branch `thomasklemm/attrs-for-database-row-2` in `thomasklemm/rails`.
* Canonical main, the head's sole parent, and both control worktrees: `f785381cca8621772cba659ff93f825eb7f99942`.
* Negative control: old head `768ad013702517396f96f9f69ff9b9d2791c85eb`. Files named `extended-head*` refer to this old head; `confirm` always means the amended head.
* Lowrail item/body/guidance: `c613275a` on main. The body script is byte-identical to `bench/upstream/l3/l3_ips.rb` (`body-script-check.txt`).
* Ruby 4.0.9, revision `3e93b23afc`, benchmark-ips 2.15.1, SQLite gem 2.10.2. Exact bundle, environment, identities and remote pins are retained in `Gemfile.lock`, `environment.txt`, and `pins.txt.gz`.

`head.diff.gz` is the complete Rails change. Relative to the old head, the production change is the Array snapshot after materialization and its use instead of live lookup. The only other code change is one nine-line regression test. There are still just two added RBS return signatures and **zero added prose comments**, including in the test.

The dependency audit found no differing application-gem versions. The amended checkout's newly resolved local lock causes Bundler to activate Ruby's standard-library `etc` 1.4.6 while computing its installation parallelism during setup; main's existing lock does not. `dependency-diff.txt` and `dependency-activation.txt` retain this distinction and its require stack. It happens before loading Active Record or entering the warmed benchmark, not in the timed operation; this is not a claim of identical boot-loaded features.

## Snapshot semantics and the regression test

The copy preserves the Attribute references captured before application casting/serialization runs. It must be shallow: in-place changes to a captured Attribute or its value continue to be visible as on main. The nil guard retains the empty-set behavior. `values_before_type_cast` needs no such copy: the ordinary built Attribute's reader calls no application conversion or serializer.

The new test uses `Topic.new`, the public writer, an ordinary object's public `to_s`, and `attributes_for_database`. It asserts the returned value, not allocation counts, call order, internal arrays, helpers, or mock interactions. Keeping this test is worthwhile: omitting the copy is a plausible future optimization, and the old production implementation really fails this assertion. The existing broad suites had missed it.

The **actual new upstream test file**, loaded against each checkout's libraries and test helper, produces:

| Tree | Decisive output |
|---|---|
| main | `1 runs, 1 assertions, 0 failures, 0 errors, 0 skips` |
| old head | `Expected: "David"; Actual: "Mary"`; one failure |
| amended head | `1 runs, 1 assertions, 0 failures, 0 errors, 0 skips` |

See `regression-*.txt`. The first direct invocations omitted `ARCONN`, unlike the Rake task, and failed before running tests; those logs are explicitly named `*-missing-arconn.txt`. Reading `test/support/connection.rb` established the missing configuration, and the corrected commands set `ARCONN=sqlite3`. Those setup errors are not regression-test failures.

The extended probe has **718 byte-identical lines** on main, main2 and the amended head, under both the interpreter and YJIT. The negative control still differs in the five expected result lines: custom serialization, the suspended fiber, Marshal, MessagePack, and built-in string casting that replace a later attribute. Fresh main/amended-head Marshal and MessagePack payloads through `probe.rb` give **5,799 identical lines** on all three checkouts. No process-local snapshot override was loaded for either comparison.

### Exactness checklist

1. Public/private singleton type methods, extended/prepended types, missing-method dispatch, and the public mutating singleton `to_s`: same results, logs and errors.
2. String/Array/Hash subclass values with overridden conversions and iteration: same results, identities and logs. No new iteration of user values is introduced.
3. Public/private string conversion, JSON/YAML, enum, date, decimal, binary and encrypted values: same conversion/error behavior. No `to_ary`, `to_a` or `to_hash` call is added or removed by these methods.
4. Traced type calls retain order/count. The Array copy restores the observable aspect of the removed row construction, without calling user code itself.
5. Both methods return new plain Hashes and keep the same cached value objects. Mutating a returned Hash does not become a mutation of the source; frozen serializer results and fresh-object serializers agree.
6. Earlier/later attribute replacement, replacement followed by exception, a suspended fiber and both serialization formats now agree, including the record's subsequent changes.
7. Frozen records, values and returned objects, missing attributes, raising serializers and repeated calls after errors agree.
8. Standalone `require "active_model"` and `require "active_record"` pass separately on main and the amended head (`standalone.txt`). The diff adds no loading or configuration access; model declarations/defaults/partial loads are exercised by the probes.

Core global monkey-patches, overrides of private/nodoc methods and reaching internal arrays through ObjectSpace remain the checklist's accepted exclusions. No such technique is used by the regression test or the failing negative controls.

## Suites and lint

| Command on the amended checkout | Decisive output |
|---|---|
| `bundle exec rake test` from `activemodel` | **1,275 runs, 5,710 assertions, 0 failures, 0 errors, 0 skips** |
| `bundle exec rake test:sqlite3` from `activerecord` | **10,444 runs, 37,316 assertions, 0 failures, 0 errors, 52 skips** |
| `bundle exec rubocop --parallel --format simple activemodel/lib/active_model/attribute_set.rb activerecord/test/cases/attribute_methods_test.rb` | **2 files inspected, no offenses detected** |
| `git diff --check HEAD^ HEAD` | no output |

Raw suite and lint output is in `active-model.txt`, `active-record-sqlite.txt`, and `rubocop.txt`. The skips are reported, not counted as passes. Both full suites ran without JIT and finished before benchmarking began.

## Body and commit-message audit

Each prose sentence under the item's heading and each commit-message sentence was checked against current source and the runs here. The commit contains no benchmark numbers or trailers. Its author and committer are Thomas Klemm <github@tklemm.eu>.

| Claim in the body and/or commit | Check |
|---|---|
| Build Hashes without copying the lazy row | The diff removes the IndexedRow container copy from these two methods; the database method intentionally retains an Array snapshot. |
| Since the IndexedRow change, both calls copy the attributes to an IndexedRow::Mutable then transform it into a Hash | Current inherited `AttributeSet#values_*`, protected `LazyIndexedAttributeSet#attributes`, and `IndexedRow#transform_values`; introducing history was also examined in the initial review and is unchanged at this main. |
| Marshal and MessagePack call attributes_for_database once per record | Read `marshalling.rb:23` and `message_pack.rb:89`; the latter's `encode_record` deduplicates references. Fresh payload probes exercise both. |
| Build the attributes as before and read by name in index order | Both new methods keep `materialize`; both traverse the same indexes as the former transform. Probe key order, values and state match. |
| Same methods/attributes, same Hashes and subsequent record state | The new snapshot makes this true for the previously failing public cases as well as ordinary/frozen/partial cases. The returned container remains a new Hash. |
| Database values still come from a copy because serialization can assign another attribute | Actual upstream regression test is red on the old head and green on main and this head; callback/fiber/Marshal/MessagePack probes also match. |
| Reading row values as to_hash does skips building but regenerates encrypted ciphertext | `claims-main.txt` and `claims-confirm.txt` have ciphertext and Marshal stability true and preserve the same cached object. `claims-row-read-control.txt`, a process-local replacement of these methods on this head, has all three false. |
| Commit also says row-reading loses nil reads from accessed_fields | The normal trees give `["id", "secret", "nil_column"]`; row-read control gives `["id", "secret"]`. |
| On built attributes, database values allocate 2 objects instead of 4, before-type-cast 1 | Warmed five-sample minima reproduce **4 → 2** and **4 → 1** exactly (`claims-*.txt`). Cold calls are deliberately not claimed: this harness measures 47 → 45 and 36 → 33. |
| The script's table has 30 columns | Runtime `Post.column_names.length` is 30. |
| The gain holds from 6 to 100 columns | Checked by the new 6/100-column sweep, with 300 and 1,500 as stress controls; full output below. |

The two old wording concerns are resolved. The copy's purpose belongs in the commit/body and is now there; adding a prose code comment would duplicate both the explanation and the regression test.

## Measurements

`benchmark_rounds.sh` runs the unchanged body script for six rotating rounds of main/confirm/main2 on core 1 with `--yjit`, then three rounds each of the size sweep and deliberately expensive serialization case. All output is retained, including slower rounds. Best i/s is chosen independently per operation over the declared number of rounds, never by rerunning a disappointing cohort.

| Body benchmark, best of six, i/s | main | amended head | main2 A/A |
|---|---:|---:|---:|
| Marshal.dump | 36,698 | 42,788 (+16.59%) | 36,560 (−0.38%) |
| attributes_for_database | 89,596 | 148,501 (+65.75%) | 91,693 (+2.34%) |

**Absolute numbers not reproduced exactly:** the body's 37.565k → 44.518k and 92.033k → 154.469k are higher than this independent cohort. Their +18.5% / +67.8% gains become +16.59% / +65.75% here, with sample dispersion around 4–6% in the selected main/head rows. The numerical difference is not a new code or wording defect: the body quotes a retained six-round run on this exact head, and the independent gain remains far outside its A/A. If refreshing the body to this review's run, use this **replacement output**, copied verbatim from `body-ips.txt` (best rows selected in `body-best.txt`):

```text
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before:            Marshal.dump     36.698k (± 4.7%) i/s   (27.25 μs/i) -    183.810k in   5.008660s
before: attributes_for_database     89.596k (± 6.3%) i/s   (11.16 μs/i) -    455.500k in   5.083930s
after:             Marshal.dump     42.788k (± 4.0%) i/s   (23.37 μs/i) -    216.810k in   5.067064s
after:  attributes_for_database    148.501k (± 3.9%) i/s    (6.73 μs/i) -    757.785k in   5.102881s
```

The three-round scalar size sweep confirms the body's range claim. For 6 columns, Marshal/database-Hash throughput improve **15.77% / 101.51%**, versus A/A **+0.68% / −2.35%**; for 100 columns, **31.97% / 107.68%**, versus **−0.14% / −0.35%**. The 300/1,500-column controls also improve, and the 1,500-column cold call is +19.82% versus A/A +5.69%. Full rows are in `sweep-best.txt`, all rounds in `sweep-ips.txt`.

To make the change least helpful, the type in `worst_ips.rb` reverses **128 MiB** on every serialization and says its value changed in place, preventing memoization. This is larger than the orb's reported 54 MiB LLC. The best main/head/main2 are **7.270 / 6.994 / 7.067 i/s**: head **−3.80%**, control **−2.79%**, with about **±14%** sample dispersion. The first two rounds actually have head slightly faster than main; the best-of-three comparison is not evidence of a consistent regression. There is no resolvable gain on this deliberately artificial bound, and these noisy short windows cannot exclude a small loss.

The same shape at **1 MiB** already erases the gain: **1,720 / 1,676 / 1,656 i/s**, head **−2.56%**, A/A **−3.72%**. The 1 MiB ordinary String Marshal case is +5.36% versus A/A +2.17%, with high dispersion. The body does not claim every serializer or large payload gets the scalar benchmark's gain. No absolute slowest input exists when user serialization can do arbitrary work; these are measured least-beneficial constructions, not a universal bound or a whole-app claim.

`sample-counts.txt` validates two operations × three trees × six rounds for the body, eleven × three × three for the sweep, and one × three × three for the 128 MiB case. No cohorts were discarded or rerun.

## Maintainability and overlap

Cold read: build the Attributes, snapshot their references only for database serialization, then put each present Attribute's requested representation into a fresh Hash in index order. The condition skips genuinely absent slots. The new optional snapshot mirrors the existing nil-safe storage invariant, rather than inventing a fallback.

Both overrides belong in LazyIndexedAttributeSet next to to_hash. They do not require a helper, a callback mode or changes to the base class/callers. A shared block traversal would add indirection to two short loops and obscure the intentional snapshot difference. Reading the raw row would be shorter but is observably wrong, as the ciphertext/accessed-fields controls demonstrate.

The production file grows **891 → 916 lines**, below 1,000. The existing test file grows **1,808 → 1,817**; it was already over the threshold and the one behavior test belongs with the adjacent public-API tests, not in a new file. Zero prose comments were added.

Measured method metrics (`flog-confirm.txt.gz`, `metrics-confirm.json.gz`, and their fresh main controls): inherited methods are Flog 3.7, ABC 2.24, cyclomatic/perceived 2. The new before-type-cast override is 8.5 / 8.31 / 3; database values is 10.0 / 10.25 / 5. The explicit loop explains the increase over the inherited transform, and the extra nil-safe copy/read explains the increase over the old head. These small straight-line traversals are understandable without another abstraction. Metrics thresholds were intentionally zero to print scores, not Rails' lint thresholds; actual Rails lint passed.

Bruno's keys change (`af6081aeeb03c1ba2b2ddccf886e9b706f196c87`, merged in 59833) and to_hash/keys change (`d120f34811a23fa30530f2a889f4d34e15a26b79`, merged in 59963) are ancestors of main/head (`pins.txt.gz`, `maintainability.txt`). Current source shows neither removed these methods' row copy. The one-pass each_pair API still needs the copied IndexedRow here, while the raw-row to_hash path cannot preserve serialization memoization. L3 remains complementary, not redundant; all measurements include both landed changes.

## Reproduction commands

From the Lowrail root, with detached Rails trees under `S` and the recorded bundle installed:

```sh
export PATH=/home/user/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
S=$PWD/.amp/in/orb-backup/l3-review
E=$PWD/bench/upstream/l3/results/review-thermos-sol-confirm-2026-11-25
P=$PWD/bench/upstream/l3/results/review-thermos-sol-2026-11-25
export RAILS=$S/confirm BUNDLE_GEMFILE=$S/Gemfile.confirm BUNDLE_PATH=$S/gems

ruby "$P/exactness_extension.rb"
ruby --yjit "$P/exactness_extension.rb"
ruby bench/upstream/l3/probe.rb dump "$S/payload-confirm-confirm"
ruby bench/upstream/l3/probe.rb probe "$S/payload-confirm-main" "$S/payload-confirm-confirm"
ruby -rbundler/setup "$P/body_claims.rb"
ruby -r"$P/row_read_variant.rb" -rbundler/setup "$P/body_claims.rb"
bash "$E/benchmark_rounds.sh"
```

The probes/claims were also run with `T=main|main2|head`, changing `RAILS=$S/$T` and `BUNDLE_GEMFILE=$S/Gemfile.$T`. Fresh payloads were dumped on main and confirm only. In each tree's `activerecord` directory the exact regression command was:

```sh
ARCONN=sqlite3 bundle exec ruby -Itest \
  "$S/confirm/activerecord/test/cases/attribute_methods_test.rb" \
  -n /test_attributes_for_database_serializes_the_attributes_the_record_had_when_it_was_called/
```

The amended-head isolated run used the preferred `-i` alias instead of `-n`; both select the same single test. The full-suite/lint commands above used the amended checkout and its bundle. Flog used `bundle exec flog -m -a activemodel/lib/active_model/attribute_set.rb`; metrics used RuboCop with the initial review's `metrics.yml` and JSON format. SHA256SUMS inventories the delivered files; probe hashes refer to decompressed bytes.

Scope: current SQLite, the two requested suites, interpreter/YJIT differential probes, and YJIT wall-time microbenchmarks. PostgreSQL, Ruby master/ZJIT, instruction counting and JIT-flat counters were not rerun; no result for them or whole-app speed is claimed. Earlier-head benchmark results are not used as current numbers. This branch has no PR; no PR discussion or feedback was published.
