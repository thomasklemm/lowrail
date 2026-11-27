# L3 thermos-sol review, 2026-11-27

Verdict: **changes**. The exact head changes the Hash returned by `attributes_before_type_cast` when a callable default assigns a later attribute. Do not open this head.

Reviewed base `088fc0cf61e4ba0c7987decafacc69adb3e22eec` and head `f70d3e091759d3f7acf5f5b46ba40537c7b6c6f5` on `thomasklemm/rails`, branch `thomasklemm/attrs-for-database-row-2`. Both remote refs were checked directly. Lowrail input was `d0ce579b50943542880b6d33865b5a18995f0406`; `item-snapshot.md` preserves the reviewed title and entire item. Neither the Rails branch nor the item was changed.

## Must-fix: snapshot the before-type-cast attributes too

At `activemodel/lib/active_model/attribute_set.rb:377–386`, the new method calls `lookup` on the live attribute Array while traversing it. Main first snapshots the Attribute references into an independent IndexedRow, then traverses that snapshot. `Attribute::UserProvidedDefault#value_before_type_cast` executes a Proc, so this is not necessarily a passive reader.

`callable_default_repro.rb` uses only public Active Record APIs: a new record has `author_name: "David"`, and its earlier `title` attribute has a callable default that assigns `author_name = "Mary"` and returns `"title"`.

| Observable result | Main | Head | Head with proposed snapshot |
| --- | --- | --- | --- |
| Returned Hash's `author_name` | David | Mary | David |
| Record's `author_name` afterwards | Mary | Mary | Mary |

The raw outputs are `default-main.txt`, `default-head.txt`, and `default-proposed.txt`. I independently reproduced the correctness reviewer's finding on the exact base and head. It does not rely on overriding a Rails private method, changing a core method, or reaching an internal Array.

Smallest repair: immediately after `materialize`, take `attrs = @attributes&.dup`, and replace `lookup(index_for_name(name))` with `attrs&.[](index_for_name(name))`. This is the same snapshot policy the patch already uses for `values_for_database`. `proposed_snapshot.rb` is a validation-only overlay, not a change to the reviewed Rails tree. With it, the repro and the 718-line SQLite extended probe match main. Add a public-behavior regression test for the callable-default case, asserting both the old value in the Hash and the changed value on the record afterwards.

The repair changes the allocation claim. `body-claims-main.txt`, `body-claims-head.txt`, and `body-claims-proposed.txt` independently measure warm calls: main allocates 4/4 objects for database/before-type-cast; this head 2/1; the proposed repair 2/2. Replace the body's allocation sentence exactly with:

> On a record whose attributes are built, each method now allocates two objects per call instead of four.

Remeasure the repaired head, including the before-type-cast row, and rerun the required exact-head reviews. The unchanged equivalence claim is not true at the reviewed head; it becomes supportable only after the behavior is repaired.

## Optional points

1. Strengthen the added serialization test at `activerecord/test/cases/attribute_methods_test.rb:391–398`: append `assert_equal "Mary", topic.author_name` after the existing assertion. That confirms the competing assignment actually happened without asserting implementation details. The existing test passes on both main and head (`serialization-test-*.txt`), and the selected AR tests pass.
2. Shorten the body's second paragraph. The current body has 166 prose words excluding fenced blocks; “after building them as before” and “as the row was” make an outsider reconstruct the references. After both snapshot repairs, an optional replacement is:

   > Both methods now materialize the attributes and build the Hash from a snapshot, in index order. A snapshot is still needed because serialization or a callable default can assign another attribute. Reading the raw row instead would skip materialization but lose cached ciphertext for encrypted attributes.

   The commit's “They now read the attributes materialize built” can similarly become “The two methods now materialize the attributes, then read them directly in index order.” These are wording improvements, not separate blockers.
3. Restore the complete six-round benchmark log, or correct the internal record's round count. `results/rebuild-2026-11-27/body-ips.txt` has three completed main/L3/main2 rounds and only main's part of round 4, not six completed rounds. All four body output lines and A/A samples are present, so this does not invalidate the quoted output; I did not verify the claimed six-round maximum. `body-audit.txt` records the exact retained rounds. No item edit was made.

## Thermos synthesis and maintainability

Two independent, read-only Task reviewers ran concurrently in this thread using `thermo-nuclear-review` and `thermo-nuclear-code-quality-review`. Neither created a thread, edited files, published, pushed, or spawned another reviewer. The correctness review returned **changes** for the callable-default counterexample. The maintainability review returned **nits**, with no design must-fix, and the first two optional points above.

The maintainability review treated before-type-cast as an ordinary accessor when justifying the asymmetric snapshot policies. Direct inspection of `attribute/user_provided_default.rb:17–23` and the public repro disprove that premise; the verified correctness finding takes precedence. Its readability assessment otherwise stands: the two short overrides follow the existing storage class's `to_hash` and IndexedRow traversal idiom. The narrow guards handle empty sets and absent slots; no generic transformation helper or numeric index loop is needed for this repair.

Readability is L1 rather than the gate's L3 duplicated-method case: these specialize two existing conversions to their storage owner, not two interchangeable implementations or a parallel mechanism. Main's inherited methods each have flog 3.7, ABC 2.24, cyclomatic/perceived complexity 2/2; the new before-type-cast method has flog 8.5, ABC 8.31, 3/3; database has flog 10.0, ABC 10.25, 5/5. The increase buys explicit storage traversal instead of allocation of an intermediate row. Metrics are recorded with zero thresholds to report all methods, not as a failing project lint gate. Rails' actual configuration reports `2 files inspected, no offenses detected` (`rubocop.log`).

Every added comment line was checked. Only two RBS-inline `#: () -> Hash[String, untyped]` signatures were added, in the surrounding style; no prose code comments. The enclosing class is already `:nodoc:`. The new test asserts public Hash behavior and belongs beside the existing attribute-Hash tests.

## Exactness, tests, and the keys/materialize change

`run-probes.sh` reran both requested probes on both exact revisions with Ruby 4.0.9, SQLite and PostgreSQL 17, interpreter and YJIT. All eight main/head comparisons are byte-identical: 676 lines for `review_probe.rb` and 718 for `exactness_extension.rb` in each adapter/mode. This is limited coverage, not proof of exactness: neither probe includes a callable default that mutates another attribute. The new repro is the counterexample they miss.

The original and extended probes cover type singleton/private methods, extension/prepend, missing-method dispatch, String/Array/Hash subclasses, public/private conversions, type callback order, fresh/raising serializers, encrypted attributes, mutations and fiber suspension during serialization, result ownership, frozen inputs/results/records, empty/partial layouts, selected extras and duplicate columns, late attributes, `becomes`, reload, dirty/save behavior, Marshal and MessagePack. No new user-value dispatch is introduced beyond the existing Attribute accessor calls. `values_before_type_cast` running callable defaults is the newly exposed omission in the earlier coverage.

Standalone require order was compared in separate processes. Direct `require "active_model/attribute_set"` without the framework boot raises the same pre-existing `NoMethodError` on both revisions; `require "active_model"` and `require "active_record"` work. The probes use the normal framework boot and configuration on both revisions.

The only `attribute_set.rb` change between the previous base and current main is the merged keys/materialize optimization: remove `row_keys | @ctx.type_keys` in `keys`, and remove the second `@ctx.type_keys` walk in `materialize`. `row_keys` already returns `indexes.keys`; Builder constructs indexes containing all model attribute names and typed extras. The new overrides still call the same `materialize`, then visit the same index order and skip the same absent slots as main's copied row. The partial/default/extra-column cases remain identical in the requested probes. The callable-default bug is introduced by L3's live lookup, not by that upstream change. See `pins-and-overlap.txt.gz` and `keys-pr-diff.json`.

Executed selected suites on the head:

- Active Model attribute set and attributes: 60 runs, 140 assertions, 0 failures/errors/skips (`am-tests.log`).
- Active Record attribute methods, Marshal, MessagePack, dirty, serialized attributes and encryption: 390 runs, 1,597 assertions, 0 failures/errors, 1 skip (`ar-tests.log`).
- The added serialization test, loaded from head and run against each framework revision: 1 run, 1 assertion, 0 failures/errors on each (`serialization-test-main.txt`, `serialization-test-head.txt`).
- Concurrency probe on each revision: 200 records × 8 threads, 0 mismatches/errors; frozen clean/dirty results agree; prepared Ractor yields 22/22 keys, cold Ractor raises FrozenError on both. Object addresses differ in the raw error text as expected (`concurrency-*.txt`).

The full component suites and the Ruby-master build were not rerun here; this pass ran the focused suites and reviewed the builder's kept current-head results. No adapter/schema implementation changes are proposed, so the adapter minimum-version matrix is not applicable.

## Measurements and the least favorable input

`run-benchmarks.sh` reuses the kept sweep and worst-input harnesses from the earlier review, under Ruby 4.0.9 +YJIT, core 1, fixed heap floors, three interleaved main/head/main2 rounds. Main2 is a fresh process at the same base tree, the A/A control. These short benchmark-ips observations have no measured JIT-flat counters and are not replacement body claims.

The least favorable input is a six-column record with a custom type that reverses a 128 MiB string on every serialization (`changed_in_place?` returns true). Its payload exceeds this orb's 54 MiB last-level cache; callback work overwhelms the removed row-copy work. Best samples are main 7.270 i/s, head 7.320 i/s, main2 6.962 i/s: head +0.69%, A/A −4.24%, sample dispersion about 14%. There is no distinguishable gain or loss; a small slowdown cannot be excluded. At 1 MiB every-call serialization the observed head difference is −1.55%, A/A −1.24%, dispersion 4–6%; that is likewise not evidence of a slowdown. Raw samples are all kept, not rerun until green (`worst-ips.log`, `worst-ips.json`, `sweep-ips.log`, `sweep-ips.json`).

The sweep includes 6, 100, 300 and 1,500 columns, 1 MiB string payloads and cold records. At realistic endpoints the database-Hash observations are +109.30% at 6 columns (A/A +0.59%) and +101.32% at 100 (A/A +2.59%); Marshal is +22.65% (A/A +6.03%) and +32.70% (A/A +6.93%). Those are shape observations, not updated 30-column body numbers. The wide and large-payload cases stay in this record.

The builder's kept `body/L3-2026-11-27` run has interpreter CPU and allocation reductions as well as gated YJIT reductions, so this is not a JIT-only workaround. The master-ZJIT run is explicitly uncertified because `invalidation_count` is missing; the kept available compilation counters are flat and there is no observed loss. No new ZJIT speed claim is made here.

## Title, body, and commit message audit

`audit_body.py` compares the body's Ruby script with `l3_ips.rb` and finds them identical. Each quoted before/after output line matches a retained raw sample in `rebuild-2026-11-27/body-ips.txt`, including the Ruby version, dispersion, elapsed time and iteration count. The figures are not invented, but the six-round description in the internal record is not supported by the retained partial log.

Sentence-by-sentence body audit:

1. “Since #59141 …” — current base still routes the two public methods through `AttributeSet#values_*`, `LazyIndexedAttributeSet#attributes` and `IndexedRow#transform_values`. The introducing PR's metadata/body and current source were read (`introducing-pr.json`, `reviewed.diff.gz`).
2. Marshal and MessagePack call once per record — checked `active_record/marshalling.rb:23` and `active_record/message_pack.rb:89`. Built-in Marshal is not an external project citation.
3. Direct construction after materialization, index order — matches the new methods.
4. Same attributes and unchanged Hash/state — **false on the exact head**, demonstrated above. Repair the implementation, not the equivalence requirement.
5. Database snapshot because serialization can assign — true; verified by the requested extended probe and the new upstream test.
6. Raw-row alternative loses cached encrypted ciphertext — verified by rerunning the earlier validation-only row-read variant: repeated ciphertext and Marshal output are unstable there, stable on main/head; nil-column access tracking also differs (`body-claims-row-read.txt`).
7. Warm allocations 4→2 / 4→1 — reproduced exactly at this head. Must become 4→2 / 4→2 after the repair, with the exact sentence above.
8. Thirty columns and gains from 6 to 100 — the script creates 27 data columns plus id/timestamps, and the current-head sweep checks both realistic endpoints. No whole-app speedup is claimed.

Title and commit subject are identical, short and descriptive. The commit's first paragraph correctly locates the per-call row copy and its callers. Its next paragraph correctly describes the intended index traversal, but “same attributes … Hashes … unchanged” fails on the callable-default case. Its database-snapshot explanation is correct and the raw-row rejection is demonstrated. After repair, explain that evaluating a default can run application code too. `commit-check.txt` verifies one parent equal to the requested base, Thomas Klemm <github@tklemm.eu> as both author and committer, no trailers, and a clean diff check.

## Relevant, current project citations

Checked live GitHub and RubyGems APIs, with raw JSON kept here. The prose names only Rails' own Marshal/MessagePack paths, not a list of apps or niche external users. Rails comes before MessagePack; no reach-order correction is needed. SQLite and benchmark-ips occur as measurement tools in the script, not as affected-app citations. They were checked too:

| Project | Stars | Total gem downloads | Latest gem release / last push |
| --- | ---: | ---: | --- |
| rails/rails / activerecord | 59,174 | 875,070,966 | 8.1.4.1, 2026-11-04 / 2026-11-27 |
| msgpack/msgpack-ruby | 788 | 548,455,103 | 1.8.7, 2026-10-30 / 2026-11-19 |
| sparklemotion/sqlite3-ruby | 848 | 203,666,215 | 2.10.2, 2026-10-26 / 2026-11-25 |
| evanphx/benchmark-ips | 1,776 | 91,523,752 | 2.15.1, 2026-05-21 / 2026-06-18 |

None is archived; no superseded dependency version is named as an affected caller. This does not turn the benchmark into whole-app relevance evidence.

## Overlap and opening bar

A fresh fetch still has Rails main at the requested base. The merged-PR search since 2026-11-25 returns 71 entries, including stable-branch backports; the method-name search and full relevant-file history were also inspected. No merged PR removes this row copy or implements these overrides. The merged keys optimization is complementary. The recent MessagePack class-loading and record-dup dirty-tracker changes are different concerns. `merged-prs.json`, `method-pr-search.json`, `pins-and-overlap.txt.gz` and `overlap-summary.txt` preserve the checks.

This head does **not** clear DECISIONS' opening bar: exactness fails. The mechanical optimization is small and idiomatic, with interpreter/allocation evidence beyond A/A and ordinary-size benefits, but its reach remains per dumped/cached record; there is no demonstrated whole-request gain. The builder's relayed item-specific approval to open is recorded, not an independently verified general relevance waiver. A low open-PR count alone does not remove the relevance requirement.

After repair, the builder must refresh the numbers/body and obtain both current-head passes. This touches typecasting/cached values and needs the required **adversarial Astra pass**, regardless of the item's current `risky: false` metadata; record the critical classification accordingly. This review does not approve an opening, modify the queue, or perform any upstream action.

## Reproduction and delivery

`Gemfile`/`Gemfile.lock`, `environment.txt`, the two runner scripts, raw output and SHA256 manifest are retained in this directory. Probe output and raw diffs are gzip-archived byte for byte, including their original whitespace. Worktrees and installed gems are scratch under `.amp/in/orb-backup/l3-review/`. Paths in the scripts are local to this orb. The requested original probe sources and previous benchmark harnesses remain in their existing committed locations; no source was changed by this pass.

The report and raw evidence are committed to Lowrail only. The builder owns recording the pass and making any candidate or item changes.
