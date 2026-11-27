# L3 independent Astra review, 2026-11-27

**Verdict: approve. Must-fixes: none. Optional points: none.**

Reviewed `f70d3e091759d3f7acf5f5b46ba40537c7b6c6f5`, one commit on
`088fc0cf61e4ba0c7987decafacc69adb3e22eec`, and the exact title/body saved in
`body-reviewed.md`. The fork branch and current Rails main still matched these SHAs at the final API check.
This pass ran independently in thread `T-01a21cfe-3bc3-730f-8be8-b10faebf5c84`, without another agent or thread.
No Rails checkout, queue item, PR, or upstream comment was changed.

## Executed differential checks

All runs used Ruby 4.0.9, revision `3e93b23afc`, with the sqlite3 gem 2.10.2; the dependency resolution is in
`Gemfile.lock`. The extended, cross-payload, adversary and size probes assert their Rails source path.
`sha256.txt` records the uncompressed output hashes.

| Probe | Main versus reviewed head |
| --- | --- |
| Existing `exactness_extension.rb`, including `review_probe.rb` | 718 lines identical |
| Existing `probe.rb`, loading both trees' saved Marshal and MessagePack payloads | 5,799 lines identical |
| Independent `adversary.rb` | 165 cases identical, including ordered Hash entries, type-call traces, resulting state and errors |
| `legacy.rb`, historical Rails 6.1 fixtures, both Hash methods or a generated reader first | 9 cases identical |
| `ciphertext.rb` | Both Hash and Marshal payload stable; nil field included in accessed fields on both |
| `key_probe.rb` | Same String-subclass keys and values; Ruby's string-key hashing did not invoke the proposed callback |

The independent probe triggers assignment, in-place mutation, freezing, readonly, `becomes`, schema-cache reset,
exceptions and reentrant serialization from custom `cast`, `deserialize`, `serialize`, and `changed_in_place?`.
It also exercises a JSON coder that writes a later column, controlled suspension in a fiber or a thread while
another execution context writes that column, non-deterministic encryption on new/loaded/frozen/readonly/partial/
`becomes` records, and exact non-encrypted Marshal/MessagePack payload bytes. Random ciphertext is normalized to
plaintext for cross-process comparisons; within-record stability is compared before normalization.

The inherited extension covers singleton and private type methods, `extend`, prepend, `method_missing`, private and
public `to_s`, Array/Hash/String subclasses, frozen inputs and serializer results, second-call value identity,
mutation of the returned Hash, partial and duplicate selects, defaults, ignored columns, dirty tracking, save,
clone/dup and Active Model-only models. It checks the exceptions as well as successful values. No production
method is overridden in the ordinary probes. The separate controls below deliberately replace methods.

Rails' five targeted SQLite test files (`attribute_methods`, `marshal_serialization`, `message_pack`, `dirty`,
`encryption/encryptable_record`) passed: main 272 runs / 1,360 assertions, head 273 / 1,361, no failures, errors or
skips. `suite-main.txt` and `suite-head.txt` retain the full output. These include the retained Rails 7.1 Marshal
fixtures. The 6.1 fixtures were separately extracted from `fffc82f3697^`; their removal from the supported test suite
does not make their unchanged results a new support claim.

### Negative controls

`mutant.rb` removes only the array snapshot in the reviewed database method, without editing a checkout. This
changes 57 of the 165 independent cases (`mutant-summary.txt`, `mutant.diff.gz`). The added Rails test fails with
expected `"David"`, actual `"Mary"` (`snapshot-test-mutant.txt`), so it guards a real public behavior.

`row_read.rb` evaluates the previously recorded `results/variant-row-read.diff` methods. `ciphertext-row-read.jsonl`
shows both repeated database Hashes and Marshal bytes becoming unstable, and `accessed_fields` losing the nil
`empty` column. Main and head return stable data and include that column. This directly checks the body's and
commit message's reason for retaining materialization.

## Why the implementation preserves these contracts

After the unchanged materialization, the old method copies Attribute references into an unset row and transforms
that row in index-key order. The new database method copies those same references into an Array and walks the same
index keys. Its nil check excludes the slots the old row leaves unset. The two methods dispatch the same operation
on the same Attribute objects; neither adopts a user value as the result Hash. The snapshot is needed because type
conversion and serialization can replace a later Attribute. The before-type-cast method reads Attribute's raw-value
reader without invoking type conversion. Empty sets still work with no backing Array.

The two loops have different snapshot requirements, so they are not interchangeable duplicated implementations.
Both fit the surrounding `to_hash` method. The only added comment lines are the two existing-style RBS signatures;
there is no explanatory prose comment to remove. The commit message matches the executed callback and ciphertext
controls. The branch has exactly one commit and `git diff --check` is clean.

Exactness checklist: argument/type dispatch and subclasses, implicit conversions, added/skipped user calls,
returned-object identity and copying, mutation/suspension, frozen behavior, and normal standalone `require
"active_record"` were checked as above. No exhaustive arbitrary scheduler interleavings, alternate autoload orders,
PostgreSQL/MySQL suite, full component suite or new Ruby-master/ZJIT run was performed in this pass. The record's
broader suite and ZJIT results are not represented here as independently rerun evidence.

## Performance and body claims

The body's Ruby script is byte-identical to `l3_ips.rb` (`body-script-check.txt`). It was rerun unchanged under YJIT
on CPU 1, three interleaved rounds of main/head/main2, with main2 a fresh process on the same base checkout.
Best results (`body-ips.txt`, `performance-summary.jsonl`):

| i/s | Main | Head | Main2 | Head versus main | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| Marshal.dump | 35,984 | 43,188 | 36,404 | +20.02% | +1.17% |
| attributes_for_database | 87,250 | 148,431 | 91,190 | +70.12% | +4.52% |

All head rounds beat every base round. These observations corroborate the existing body's output, not replace it
with this orb's absolute rates. The body's retained 37.337k/42.863k and 93.220k/153.856k output is in
`results/rebuild-2026-11-27/body-ips.txt`; its 30 columns are nine triples plus id and timestamps.
The review timing runs did not collect JIT-flat counters; they are observations, not replacement upstream numbers.
The original `body/L3-2026-11-27` record retains the gated comparison.

`performance.rb` separately tested 6, 30 and 100 columns with one main/head/main2 triplet in each of interpreter and
YJIT modes (`sizes.txt`). All three operations improved beyond their paired A/A variation. Warm allocations for the
two Hash methods were exactly 4/4 on both base processes and 2/1 on head at every width and mode. These inputs have
no timestamp columns, so their absolute Marshal object counts are not the body's timestamp-bearing record counts.
The short size runs corroborate the range, not a precise percentage claim.

Worst input tested: a type that reverses a 128 MiB string on every serialization and always reports an in-place
change. Three interleaved YJIT rounds gave 6.938 / 6.789 / 6.780 i/s best main/head/main2: head -2.15%, A/A -2.28%,
with individual-run dispersion around 14–15% (`large.txt`). The gain disappears when user serialization dominates;
these data do not demonstrate a regression or establish a tight upper bound on a small one. No app-wide timing
gain is claimed. A per-record improvement in the built-in Marshal and MessagePack cache paths is still useful.

Read `active_record/marshalling.rb` and `message_pack.rb` on the exact trees: the 7.1 dump and MessagePack encoder
each call `attributes_for_database` once per record. Read `attribute_set.rb`, `indexed_row.rb`, `attribute.rb` and
the builder to check the copy, ordering, memoization and sparse-slot claims. The title/body and commit are approved
without wording replacements.

## Upstream overlap and current-project check

Fetched full Rails history and current main. `recent-main.txt` lists commits since 2026-11-25;
`merged-prs.json.gz` retains the 71 merged PR search results (including stable-branch backports).
The only change in the four core files during that interval is #59800 (`overlap.txt`, `recent-relevant.diff.gz`),
which removes redundant type-key work from `keys` and `materialize`, not the row copy. #59911 changes missing-class
handling in Active Support's MessagePack decoder (`messagepack-recent.json`), not this encoder path. Current main
is the supplied base; the redundant copy remains there. No merged PR since that date supersedes L3.

There are no third-party app/caller reach citations in the body. Rails and its MessagePack coder are the affected
project and path; SQLite and benchmark-ips are benchmark dependencies. The current-project rule was checked even
for those dependencies through GitHub repository metadata and RubyGems API metadata (`repo-*.json`, `gem-*.json`):

| Project/gem | Stars | Total gem downloads | Latest release / last repository push |
| --- | ---: | ---: | --- |
| Rails / Active Record | 59,174 | 875,070,966 for activerecord | 8.1.4.1 on 2026-11-04 / 2026-11-27 |
| msgpack-ruby | 788 | 548,455,103 | 1.8.7 on 2026-10-30 / 2026-11-19 |
| sqlite3-ruby | 848 | 203,666,215 | 2.10.2 on 2026-10-26 / 2026-11-25 |
| benchmark-ips | 1,776 | 91,523,752 | 2.15.1 on 2026-05-21 / 2026-06-18 |

None is archived or an abandoned/niche reach citation. No superseded gem release is named in the body. Rails is
discussed first, then its MessagePack path; the benchmark's requires are executable setup, not a ranked app list.
Ruby is the mandated 4.0.9 measurement pin, not a dependency-compatibility claim; its repo is active and unarchived
(`repo-ruby.json`). The #59141 origin was checked through its merged PR record (`introduced-by.json`) and the
current implementation.

## Reproduction

Use two clean Rails trees at the SHAs above, this directory's Gemfile, Ruby 4.0.9, and set `RAILS` to the absolute
tree path before each process. `bundle install` resolves the path gems for that tree. Set `TMPDIR` to a disposable
directory under `.amp/in/orb-backup/`; `payload-inputs.tar.gz` contains the exact cross-payload inputs and extracted
historical fixtures. Commands were run from the Lowrail root, with `OUT` pointing to this directory:

```sh
ruby bench/upstream/l3/results/review-thermos-sol-2026-11-25/exactness_extension.rb
ruby bench/upstream/l3/probe.rb dump "$TMPDIR/payload-$TREE"
ruby bench/upstream/l3/probe.rb probe "$TMPDIR/payload-main" "$TMPDIR/payload-head"
ruby "$OUT/adversary.rb"
ruby -r"$OUT/mutant.rb" "$OUT/adversary.rb"
ruby "$OUT/ciphertext.rb"
ruby -r"$OUT/row_read.rb" "$OUT/ciphertext.rb"
ARCONN=sqlite3 RUBYLIB="$RAILS/railties/lib:$RAILS/activerecord/test" ruby "$OUT/legacy.rb"
RUBYLIB="$RAILS/railties/lib" bundle exec rake -C "$RAILS/activerecord" test:sqlite3 \
  TEST='test/cases/attribute_methods_test.rb,test/cases/marshal_serialization_test.rb,test/cases/message_pack_test.rb,test/cases/dirty_test.rb,test/cases/encryption/encryptable_record_test.rb'
taskset -c 1 ruby --yjit -rbundler/setup bench/upstream/l3/l3_ips.rb
WIDTH=100 taskset -c 1 ruby --yjit "$OUT/performance.rb"
LARGE=1 taskset -c 1 ruby --yjit "$OUT/performance.rb"
ruby "$OUT/summarize.rb"
```

The focused negative-control Rails test used the same rake task with `RUBYOPT=-r$OUT/mutant.rb`,
`TEST=test/cases/attribute_methods_test.rb` and
`TESTOPTS=--name=test_attributes_for_database_serializes_the_attributes_the_record_had_when_it_was_called`.
Initial test-runner setup attempts required comma-separated TEST paths and `railties/lib` in RUBYLIB; the retained
suite outputs are the successful runs, not those setup errors. The fixture probe also required `ARCONN=sqlite3`.
