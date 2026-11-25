# L3 Thermos review, 2026-11-25

**Verdict: changes (must-fix).** `values_for_database` no longer snapshots the Attribute references before running user code. A public string conversion or custom serializer that writes a later column changes the returned Hash and the Marshal/MessagePack payload relative to main. Preserve the snapshot, then update the body and commit's exactness claim. The performance opportunity remains real and is not overlapped by the two Bruno changes.

This is a fresh review of the new head. Both Thermos rubrics were loaded and applied by the reviewer in this thread, as requested; no subagents or other threads performed independent passes. Earlier heads' passes were not used as verification. No Rails branch or queue item was edited, and no PR was opened or commented on.

## Pins

* Lowrail guidance and item: `b6019d18eb8fe48ee7d95fc7f58198f8924cba23`.
* Fork branch: `thomasklemm/rails`, `thomasklemm/attrs-for-database-row-2`.
* Reviewed head: `768ad013702517396f96f9f69ff9b9d2791c85eb`.
* Reviewed rails/rails main, also the head's parent and both A/A worktrees: `f785381cca8621772cba659ff93f825eb7f99942`. A final `git ls-remote` still returned that main SHA.
* Old head `52587b6f5dde95937fbec43a76a25d161214b764` and new head have stable patch-id `1828f1bcb04cd736255722842fb3440a884d6cf3`.
* Ruby: `ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]`. Bundler 4.0.20, benchmark-ips 2.15.1, sqlite3 gem 2.10.2; complete dependencies in `Gemfile.lock` and `environment.txt`.

Raw source, history, commit identity and patch-id commands are recorded in `pins-and-diff.txt.gz`, `introducing-history.txt.gz` and `bruno-merges.txt`. All Rails worktrees remained clean.

## P2 must-fix: keep the pre-serialization snapshot

Location: `activemodel/lib/active_model/attribute_set.rb:390-399`, especially lines 394-395.

Main first materializes the set and copies the Attribute references into a separate row. It then serializes those references. The head instead looks up each reference in the live set immediately before serializing it. Both casting and serialization can execute application code; replacing a later attribute during that code must not replace the reference this call was going to serialize.

`snapshot_repro.rb` uses only a normal Active Record model, a built-in string attribute, an ordinary assignment and the assigned object's public singleton `to_s`. There is no private-method override, core monkey-patch, ObjectSpace access or internal-array mutation:

```ruby
record = Example.new(a: "trigger", b: "old")
input = Object.new
input.define_singleton_method(:to_s) { record.b = "changed"; "converted" }
record.a = input
puts "dumped=#{record.attributes_for_database.fetch("b").inspect} current=#{record.b.inspect}"
```

`ruby -rbundler/setup "$OUT/snapshot_repro.rb"`, separately against each tree, prints (`snapshot-repro.txt`):

```text
main:     dumped="old" current="changed"
main2:    dumped="old" current="changed"
head:     dumped="changed" current="changed"
snapshot: dumped="old" current="changed"
```

The extension to the existing review probe independently demonstrates the same difference through a custom type's public `serialize`, a fiber suspended inside it, `Marshal.load(Marshal.dump(record))`, and MessagePack dump/load. A mutation of an earlier column and mutation followed by an exception are controls and remain identical. Interpreter and YJIT produce the same per-tree outputs. See `exactness_extension.rb`, `exactness.diff.gz` and `review-probe-*.txt.gz`.

**Smallest fix:** after `materialize`, take `attributes = @attributes&.dup` in `values_for_database` and read each reference from that Array instead of calling live `lookup`. Keep the `nil` guard for empty sets. `snapshot_variant.rb` tests exactly that change as a process-local replacement, without changing the checkout. It makes the complete 718-line extended probe byte-identical to main and main2. `values_before_type_cast` can keep its present loop: the built Attribute's reader does not invoke a type conversion or serializer; overrides of that nodoc Attribute method are outside the stated checklist boundary.

Add one public-behavior regression assertion for the example above in the existing Active Record attribute-method tests when implementing the fix. Existing suites and the old probes do not catch it. Update the body and commit's “same attributes / unchanged Hashes” claim only after the fix. The proposed snapshot changes the warm database-Hash allocation count from 1 to 2, so its allocation sentence must change too.

The experimental snapshot was also benchmarked with the **unchanged body script**, `--yjit`, core 1, three rotating/interleaved rounds against main and main2. Best rounds (`snapshot-ips.log`, `snapshot-ips-best.txt`):

| i/s | main | snapshot | main2 A/A |
|---|---:|---:|---:|
| Marshal.dump | 36,028 | 43,020 (+19.41%) | 36,068 (+0.11%) |
| attributes_for_database | 90,244 | 153,819 (+70.45%) | 90,773 (+0.59%) |

These are a separate cohort, not a controlled direct comparison between head and snapshot. Only the extended probe and benchmark were run on the experimental replacement; it is not a newly reviewed Rails head or a full-suite certification of the proposed fix.

## Body audit and replacement output

The Ruby script under the item's heading is byte-identical to `bench/upstream/l3/l3_ips.rb`. Its version line reproduces exactly. Every prose sentence was checked:

| Body claim | Own check and conclusion |
|---|---|
| Title: build the Hashes without copying the lazy row | True of this head's diff. The suggested fix still avoids the IndexedRow container but retains an Array snapshot. |
| Since #59141, both calls copy attributes into an IndexedRow::Mutable before making a Hash | Verified against introducing merge `1f32b09101783c398c6276856b7471c14dc66555`, current protected `attributes`, and inherited `values_*`; `introducing-history.txt.gz`. |
| Marshal and the MessagePack coder call attributes_for_database once per record | Verified in current `activerecord/lib/active_record/marshalling.rb:23` and `message_pack.rb:89`, and exercised by `probe.rb`. MessagePack's encoder deduplicates record references before building an entry. |
| Build the Hashes from the set's attributes after building them, in index order | Verified in the diff and ordered probe outputs. |
| “The same method runs on the same attributes, so the Hashes and the record afterwards are unchanged.” | **False for public conversion/serialization that replaces a later attribute; must-fix above.** Calling the same accessor name does not guarantee it receives the same Attribute reference. |
| Reading raw row values instead, like to_hash, would skip building attributes and produce fresh encrypted ciphertext | Verified by `row_read_variant.rb` and `body_claims.rb`: main/head/snapshot have `ciphertext_stable=true`, `Marshal_stable=true`, identical cached ciphertext objects; row-read has all three `false`. |
| Both Hash methods allocate one object rather than four per call | Reproduced **after materialization**: 4 → 1 for both. Cold 30-column calls instead allocate 47 → 44 (database) and 36 → 33 (before-type-cast). Small wording fix: scope the sentence to a materialized record. With the proposed snapshot it becomes 4 → 2 for database and 4 → 1 for before-type-cast. |
| The script has 30 columns and the gain holds from 6 to 100 | Schema introspection prints 30. The size sweep at exactly 6 and 100 columns reproduces the gains, well outside its A/A (below). Scope “the gain” to the scalar-value script; expensive serialization can dominate. |

**Number refresh (nit, not evidence that the old run was fabricated):** none of the four displayed throughput rows is the best output of this rerun. The old body has 37.427k → 45.888k and 92.856k → 165.488k. Their implied +22.6% / +78.2% become **+24.70% / +83.88%** here. The effect reproduces; machine/process noise and dependency versions mean the absolute numbers are not exact reproductions. This is the replacement output for the **reviewed head**, copied from its six-round cohort:

```text
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before:            Marshal.dump     35.899k (± 4.3%) i/s   (27.86 μs/i) -    179.550k in   5.001502s
before: attributes_for_database     90.461k (± 3.1%) i/s   (11.05 μs/i) -    458.847k in   5.072310s
after:             Marshal.dump     44.765k (± 4.6%) i/s   (22.34 μs/i) -    224.586k in   5.016969s
after:  attributes_for_database    166.341k (± 4.9%) i/s    (6.01 μs/i) -    842.280k in   5.063567s
```

Main2 bests are 36,663 and 90,003 i/s: A/A +2.13% and −0.51%. Every head round beats every main and main2 round for both operations. Do not attach this head's numbers to a future fixed head; rerun or clearly use that head's own results. An optional one-word usability fix is to tell the reader to run the script with `--yjit`; the version line already makes the measured mode clear.

## Every commit-message sentence was checked

The title is the same as the body and accurately describes the reviewed diff. Author and committer are Thomas Klemm <github@tklemm.eu>; there are no trailers.

| Commit sentence | Conclusion |
|---|---|
| LazyIndexedAttributeSet#attributes copies into a new IndexedRow::Mutable on every call | Verified in current source and the introducing history. |
| AttributeSet#values_* back the named public APIs and only transform the row into a Hash | Verified in `attribute_set.rb:115-121`, `active_record/attribute_methods/before_type_cast.rb`, and both dump callers. |
| They now read what materialize built, by name in index order, as transform_values does | Verified in the diff and `indexed_row.rb:186-196`. |
| “They build the same attributes and call the same method on each, so the Hashes and the record's state afterwards are unchanged.” | **Not true for the demonstrated callback/fiber cases.** Same must-fix as the body, not a separate code defect. |
| Row-reading would skip materialize, lose ciphertext memoization, and omit nil reads from accessed_fields | Verified by the process-local row-read variant: after `record.attributes`, main/head/snapshot report `["id", "secret", "nil_column"]`; row-read reports `["id", "secret"]`, and the ciphertext/Marshal stability checks turn false. |

## Exactness checklist

1. **Singleton methods, private methods, extend, prepend, method_missing:** public and private singleton type `serialize`, extended and prepended types, a type dispatching serialize through method_missing/respond_to_missing?, and the mutating singleton input to_s. Dispatch/logs/errors agree except the demonstrated live-reference defect.
2. **Hash/Array/String subclasses:** values with custom to_hash/each/[]=, to_a/each/map, and to_s/to_str; stable results, identities and logs. These are values, not hand-constructed internal layouts. The diff adds no new conversion of them.
3. **Conversions:** public/private to_s, existing serialized JSON/YAML/enum/encrypted/date/binary inputs, call logs. Both trees raise the same private-method errors. No to_ary, to_a or to_hash conversion is introduced or removed by the changed methods.
4. **Added/skipped calls:** traced serialize/deserialize/changed_in_place? calls retain their order on ordinary inputs; the skipped row copy also skipped its snapshot semantics, which is the must-fix.
5. **User-returned objects / accumulators:** fresh-serializer objects, returned-Hash mutation, shared value identity, and frozen Hash results; both create a fresh plain Hash and preserve the same cached value objects.
6. **Mutation and fibers:** **fails** for a later-column replacement during casting or serialization, including a suspension and external mutation. Earlier-column replacement and exception controls agree. The snapshot replacement restores all extended comparisons.
7. **Frozen/errors:** loaded and new frozen records, frozen scalar/Array/Hash inputs and serializer results, serializers that raise, private methods, repeated calls after errors. Main/head match for these controls.
8. **Load order / standalone require / configuration:** `active_model` and `active_record` load independently on both trees. Direct `active_model/attribute_set` without its prerequisites raises the same pre-existing delegate NoMethodError on both. The change adds no requires or configuration reads. Existing probes also exercise model attributes declared after load.

The original `review_probe.rb` prefix is 676 byte-identical lines on main, main2 and head. The 22 added cases make 718 lines; main = main2 = snapshot, while head differs in five demonstrated result lines. `probe.rb` with fresh Marshal and MessagePack payloads from both main and head prints 5,799 byte-identical lines on all three checkouts. `probe-sha256.txt` contains hashes of the decompressed outputs.

## Tests and commands

All commands used Ruby 4.0.9. The isolated bundle includes the sqlite3 CLI, pg gem and argon2; the former five environment errors therefore do not recur. These were the component tasks on the exact head, not a selection of test files:

```text
# cwd: $SCRATCH/head/activemodel
bundle exec rake test
1275 runs, 5710 assertions, 0 failures, 0 errors, 0 skips

# cwd: $SCRATCH/head/activerecord
bundle exec rake test:sqlite3
10443 runs, 37312 assertions, 0 failures, 0 errors, 52 skips

bundle exec rubocop --parallel --format simple --config "$SCRATCH/head/.rubocop.yml" \
  "$SCRATCH/head/activemodel/lib/active_model/attribute_set.rb"
1 file inspected, no offenses detected
```

`SCRATCH=/home/user/workspace/repo/.amp/in/orb-backup/l3-review` and `OUT=$PWD/bench/upstream/l3/results/review-thermos-sol-2026-11-25` from the Lowrail root. For each tree `T=main|main2|head`, the environment was:

```sh
export PATH=/home/user/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
export RAILS=$SCRATCH/$T BUNDLE_GEMFILE=$SCRATCH/Gemfile.$T BUNDLE_PATH=$SCRATCH/gems
ruby "$OUT/exactness_extension.rb"
ruby bench/upstream/l3/probe.rb dump "$SCRATCH/payload-$T" # main and head
ruby bench/upstream/l3/probe.rb probe "$SCRATCH/payload-main" "$SCRATCH/payload-head"
ruby -rbundler/setup "$OUT/body_claims.rb"
ruby -rbundler/setup "$OUT/snapshot_repro.rb"
taskset -c 1 ruby --yjit -rbundler/setup bench/upstream/l3/l3_ips.rb
taskset -c 1 ruby --yjit -rbundler/setup "$OUT/sweep_ips.rb"
taskset -c 1 ruby --yjit -rbundler/setup "$OUT/worst_ips.rb"
```

The stock script ran in six rounds, rotating `main/head/main2`, `head/main2/main`, `main2/main/head` twice. Each result is the largest i/s over the predeclared rounds for that operation, not a selected whole-process run. Full unfiltered outputs are retained, including all slower rounds. The sweep and worst case each used three rounds in the same rotation and 0.5 s warmup / 1.5 s measurement per case. No low-throughput cohort was thrown away or repeated to obtain a win.

Snapshot experiments use `ruby -r"$OUT/snapshot_variant.rb" ...` on the unchanged head; row-read evidence uses `-r"$OUT/row_read_variant.rb"`. Extended probes were also run with `--yjit`; their bytes agree with their interpreter counterpart on each tree. The full tests ran without JIT. `summarize_ips.rb` extracts the displayed bests; sample counts were checked (six per tree/operation for the body, three for the other cohorts).

## Size sweep and deliberately least-beneficial input

The size sweep builds exactly 6, 100, 300 and 1,500 columns with the script's string/integer/boolean cycle and timestamps. Best of three, head versus main, with each row's same-operation main2 A/A:

| Case | head i/s change | main2 A/A |
|---|---:|---:|
| 6 columns Marshal.dump | +22.32% | +4.52% |
| 6 columns attributes_for_database | +164.22% | +5.42% |
| 100 columns Marshal.dump | +36.63% | +2.88% |
| 100 columns attributes_for_database | +107.64% | +3.49% |
| 300 columns Marshal.dump | +31.78% | −0.73% |
| 300 columns attributes_for_database | +95.35% | +1.01% |
| 1,500 columns Marshal.dump | +26.46% | +0.77% |
| 1,500 columns attributes_for_database | +89.13% | +1.47% |
| 1,500 columns instantiate then first attributes_for_database | +25.25% | +2.83% |
| 6 columns Marshal.dump with a 1 MiB String | +20.79% | +9.82% |
| 6 columns serialize a 1 MiB String afresh each call | +0.06% | −2.16% |

To make the removed bookkeeping least important, `worst_ips.rb` uses a type that reverses a **128 MiB** value on every serialization and reports changed_in_place? true, so memoization cannot hide the work. This exceeds the orb's reported 54 MiB L3 cache. Best main/head/main2 are **6.865 / 6.910 / 6.953 i/s**: head +0.66%, A/A +1.28%, with about ±14.5% dispersion. There is no resolvable speed gain in that input. This is a deliberately artificial bound, not an app-speed claim; the result does not exclude smaller regressions hidden by noise. The 1 MiB counterpart already erases the gain. Inputs cannot produce an absolute maximum runtime when user serialization can do arbitrary work.

## Maintainability, comments and overlap

The cold read is straightforward: build the Attributes as before, then for each name that has one, put that Attribute's requested representation into a new Hash. The conditional skips an unbuilt slot rather than inventing a nil value. That describes both loops; it does **not** justify replacing a captured reference with a live one.

The specialization belongs next to LazyIndexedAttributeSet#to_hash, not in unrelated callers or the base class. A shared block helper would merely move these short loops behind another call; no new helper is needed for the snapshot fix. The two representation-specific traversals repeat shape, but introduce no new mode, public API, policy or scattered special cases. Their missing snapshot is the structural issue that matters here. The file grows 891 → 915 lines and does not cross 1,000.

Metrics were measured, not treated as tests: inherited methods have Flog 3.7, ABC 2.24, cyclomatic/perceived 2; each new override has Flog 8.5, ABC 8.31, cyclomatic/perceived 3. File Flog total is 625.3 → 642.4. The increase is the explicit traversal replacing inherited container copying and is small/readable; it is not a reason to add another abstraction. `metrics.yml` sets thresholds to zero only to expose scores; those deliberate metric offenses are not a failed Rails lint run. Rails' actual lint is clean.

Every added upstream comment line was checked: **two existing-style `#:` return signatures and zero prose comments**. No unnecessary comment or public implementation documentation was added.

Bruno's keys change is `af6081aeeb03c1ba2b2ddccf886e9b706f196c87`, merged in #59833 (`9a64d012d2`); his base AttributeSet#to_hash/#keys change is `d120f34811a23fa30530f2a889f4d34e15a26b79`, merged in #59963 (`e49b3461cd`). Both are ancestors of the reviewed main and head. Neither changes values_for_database, values_before_type_cast, or LazyIndexedAttributeSet#attributes. The new each_pair API still requires the copied IndexedRow; substituting it here would retain the waste. L3 is therefore not redundant, and its measured benefit already includes both merged changes.

`gh pr list --repo rails/rails --head thomasklemm:thomasklemm/attrs-for-database-row-2 --state all --json number,state,title,url` returned `[]`; there is no PR discussion for this head to reconcile. No public review action was taken.

## Scope and retained evidence

The review covers current SQLite behavior, both requested suites, wall-time YJIT benchmarks and the exactness extensions above. PostgreSQL, Ruby-master/ZJIT, instruction counting and JIT-flat counters were not rerun in this pass; no earlier-head result is presented as current verification. A passing suite does not cancel the reproduced public-API divergence.

Raw output is retained, with repetitive probes and history compressed losslessly using `gzip -n`. `probe-sha256.txt` refers to their original decompressed bytes; `SHA256SUMS` inventories the delivered evidence. The item file is unchanged. Only this evidence directory is included in the Lowrail commit.
