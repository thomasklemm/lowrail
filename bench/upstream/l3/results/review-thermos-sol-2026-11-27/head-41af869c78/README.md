# L3 thermos-sol review of 41af869c78

Verdict: **changes**. The earlier correctness defect is repaired. One maintainability gate remains: the two overrides duplicate the complete snapshot-and-transform protocol. No further supported-input correctness or security defect was demonstrated.

Reviewed head: `41af869c787a33db4cb46149746cf3cabeb896f7`, sole parent `088fc0cf61e4ba0c7987decafacc69adb3e22eec`. Lowrail started on main `652f5a402c216ee6a1772b0e5a5ccae4d3922c0f`. The full title/body reviewed is preserved in `item-snapshot.md`; the upstream diff is `reviewed.diff`. Neither the Rails branch nor the queue item was edited. No upstream post was made.

## Changes: keep the snapshot protocol in one place

`activemodel/lib/active_model/attribute_set.rb:376–400` repeats materialization, the Attribute-reference snapshot, ordered traversal, missing-slot filtering and Hash construction, with only the final accessor changing. DECISIONS' readability gate explicitly assigns a duplicated method L3 and says not to open it. This is also a concrete maintenance risk: the two previous repairs independently added the snapshot to one accessor before the other. Each method is individually clear; the blocker is keeping that protocol synchronized, not obscure syntax or a runtime failure at this head.

Replace the two new overrides with exactly:

```ruby
    #: () -> Hash[String, untyped]
    def values_before_type_cast
      attributes_to_hash { |attribute| attribute.value_before_type_cast }
    end

    #: () -> Hash[String, untyped]
    def values_for_database
      attributes_to_hash { |attribute| attribute.value_for_database }
    end
```

Add this helper under the existing `private` section, before `materialize`:

```ruby
      #: () { (ActiveModel::Attribute) -> untyped } -> Hash[String, untyped]
      def attributes_to_hash
        materialize
        snapshot = @attributes&.dup
        hash = {}
        indexes.each_key do |name|
          if attribute = snapshot&.[](index_for_name(name))
            hash[name] = yield(attribute)
          end
        end
        hash
      end
```

Keep both tests. This is a proposed replacement, not an upstream edit or approval of a new head. Historical measurements and the earlier choice of two plain methods in the record were considered; they explain the choice but do not record an exception to the current duplicated-method gate.

Validation-only `shared_transform.rb` exercises exactly this executable replacement. Its 718-line extension is identical to main on SQLite and PostgreSQL; the callable-default repro and both regression tests pass, and both methods still allocate 2 objects per warmed call. A three-round, same-pin YJIT observation at 30 columns retains most of the gain: main/head/helper/main2 best i/s are 34,843/39,564/39,178/33,828 for Marshal and 91,129/144,700/139,901/90,035 for the database Hash. Helper versus main is +12.44%/+53.52%, with main2 −2.91%/−1.20%. These short, noisy, ungated timing observations are not new body numbers; they do not show a material helper penalty. Raw: `helper-ips.log`, `helper-ips.json`, `helper-ips-best.txt`, `extended-helper-*`, `regressions-helper.txt`, `body-claims-helper.txt`.

## Optional point: simplify the first two sentences of paragraph two

The phrase “builds both Hashes … after building them” makes an outsider resolve whether “them” means the Hashes or the Attributes. Replace only the first two sentences of the second paragraph with:

> Both methods now materialize the attributes as before, then build each Hash from a snapshot in index order. The snapshot preserves the result if a serializer or callable default assigns another attribute.

Keep the existing final sentence about reading directly from the row and ciphertext. This is optional wording, not a correctness finding.

## Independent reviews and synthesis

Two read-only Task reviewers ran in parallel in this thread, loading `thermo-nuclear-review` and `thermo-nuclear-code-quality-review` independently. No other threads were created. Correctness/security returned approve, with no finding. Maintainability returned changes for duplicated methods and for describing a rejected row-reading variant, plus a non-blocking commit-wording suggestion. The primary reviewer independently ran the checks below and synthesized the reports.

The duplicated-protocol finding is retained for the explicit gate and the demonstrated history of divergent snapshot handling. The proposed removal of the row-reading explanation is **not** retained: DECISIONS' more specific “Learnings from byroot's follow-ups” rule asks for the smaller alternative in the body when retaining the conservative fix. The ciphertext claim was rerun, including the row-reading control. Keeping that sentence also explains why the existing `to_hash` path is not reused. The commit's final paragraph is accurate as written; its optional rewording is not necessary. The only optional point carried forward is the ambiguous body sentence above.

## Correctness, exactness and test evidence

All new runtime checks use Ruby 4.0.10 revision `a704b7cd95`, following the updated pin. The retained body measurements use Ruby 4.0.9, and no comparison crosses those pins.

- `run-probes.sh`: `review_probe.rb` is 676 lines and the 2026-11-25 `exactness_extension.rb` is 718 lines. Main and exact head are byte-identical on SQLite 2.10.2 and PostgreSQL 17, interpreter and YJIT. `probe-comparison.txt` records successful comparisons. The original callable-default repro returns David in the Hash and leaves Mary on the record on main and head, interpreter and YJIT. That repro explicitly uses SQLite even when the surrounding ADAPTER environment says PostgreSQL; the PostgreSQL evidence is from the two adapter-aware differential probes.
- `regressions-main.txt` and `regressions-head.txt`: both added tests, 2 runs and 4 assertions, zero failures/errors. Run the exact head's test file against each framework tree. `regressions-old-db.txt`: on `768ad01370`, both tests fail David versus Mary. `regressions-old-btc.txt`: on `f70d3e0917`, only the callable-default test fails David versus Mary. These are actual historical trees, not assertions against fabricated expectations.
- `run-tests.sh`: two relevant Active Model test files, 60 runs/140 assertions on each tree, zero failures/errors. Six focused Active Record files (attribute methods, Marshal, MessagePack, dirty, serialized attributes, encryptable record): main 389 runs/1,596 assertions and head 391/1,600, zero failures/errors, the same one skip. Full framework suites and additional adapters were not rerun in this pass.
- `body-claims-main.txt`, `body-claims-head.txt`, `body-claims-main2.txt`: warmed allocations 4/2/4 for **each** public Hash method. Main and head keep ciphertext, Marshal output and returned ciphertext-object identity stable; accessed fields include the nil-valued column. `body-claims-row-read.txt` confirms that bypassing materialization makes ciphertext/Marshal output unstable and omits that nil column from accessed fields.
- `concurrency-main.txt` and `concurrency-head.txt`: 200 records × 8 threads, zero mismatches/errors. Frozen clean/dirty records match. Prepared shareable sets return both Hashes in a Ractor; cold sets raise FrozenError on both. Error object addresses differ, as expected.
- `requires-main.txt` and `requires-head.txt`: bare standalone `require "active_model/attribute_set"` fails identically because `delegate` was not loaded. The probes' supported `require "active_record"` succeeds on both. No load-order regression was introduced; the existing bare-require problem was not changed.

The exactness checklist covers singleton/private type methods, extension/prepend, missing-method dispatch, String/Array/Hash subclasses, public/private conversion, callback order and counts, returned value identity, fresh result Hashes, mutation during serialization, fiber suspension, frozen receivers/values, and exception class/message. Global core redefinitions, overrides of nodoc/protected storage internals, and ObjectSpace access to internal Arrays are excluded by DECISIONS, not represented as public guarantees.

After materialization and `@attributes.dup`, application code runs only when accessing an Attribute's value. Both methods now select each later Attribute from the copied Array, not the live Array. `indexes.each_key` and `index_for_name` are still live reads, but the lazy set assigns its indexes only at initialization; model index maps and extensions are immutable, and schema reset rebuilds a model context rather than mutating an existing set's map. Reload replaces the record's attribute set, not the set on this call's stack. The old IndexedRow also retained the same index-map object. Reentrancy and mutation inside retained value objects remain shallow-reference-snapshot behavior on both sides.

The guards are limited to two representation facts: an empty set may have no attributes Array, and an absent slot contains no Attribute. They do not filter legitimate nil/false values. No new compatibility guard is introduced.

## Title, body, comments and commit audit

`pins-and-history.txt` verifies exactly one commit on the requested parent, Thomas Klemm <github@tklemm.eu> as author and committer, no trailers and clean `git diff --check`.

- Title: accurately distinguishes removing the IndexedRow copy from the retained shallow Array snapshot.
- Body sentence 1: the introducing merge `1f32b09101` already contains the protected row-building copy and generic transform methods (`introduced-copy.txt`, `introducing-pr.json`). The same copy remains in current main.
- Body sentence 2: `Marshalling::Methods#_marshal_dump_7_1` builds its record payload with one `attributes_for_database` call; MessagePack's `build_entry` does likewise for each unique encoded record. Source paths and commands are in `commands.txt`.
- Body paragraph 2: materialization and index-key ordering are unchanged; snapshot mutation and ciphertext claims pass the checks above. The proposed wording clarification is optional. The smaller row-reading alternative belongs here under the specific conservative-fix rule.
- Body benchmark: the Ruby source equals `l3_ips.rb`; its schema is 1 id + 27 fields + 2 timestamps = 30 columns. It creates, reloads and then repeatedly dumps/exports one record. No synthetic shortcuts or hidden application dependencies were added.
- Body output: `audit_body.py` matches all four entire quoted output lines, including dispersion, per-iteration time, sample totals and elapsed time, to their retained raw samples. The before lines are round 3; after Marshal is round 1; after database Hash is round 6. All three trees have six complete rounds. Best throughput is +20.82%/+75.15%, main2 −0.41%/−0.60%; every head sample exceeds every control sample. The quoted Ruby description also matches. No time claim is inferred from Callgrind.
- Final allocation sentence: raw `script/upstream-bench` object logs, both modes, say 4/2/4 for each method; the independent current-pin check agrees. The built-attributes qualifier is necessary and retained.
- Final width sentence: the exact-head sweep at 6 and 100 columns preserves the gain; the older 6/102 rows are not silently attributed to this head. Larger widths and large-value boundaries stay in the record.
- Added comments: exactly two `#:` type signatures, matching the file's existing convention. No narrative code, test or benchmark comments were added.
- Commit subject and first paragraph correctly name the allocation owner and the public callers. The second paragraph correctly describes materialize, ordered Attribute dispatch and the retained shallow snapshot. The final paragraph explains the rejected raw-row alternative and its ciphertext/accessed-fields differences, both rerun. No internal process or review details leak upstream.

`body-audit.txt` also reconstructs every L3b instruction row independently from archived raw Callgrind totals, subtracting the N=0 total from the N=500 total and dividing by 500, and checks every YJIT counter pair in all 24 windows. All eight rows and their A/A spreads match the record. The interpreter Marshal allocation bases differ, so no interpreter Marshal allocation claim is made.

Current projects were checked live: Rails 59,180 stars, Active Record 875,153,352 total downloads, current release 8.1.4.1; msgpack 788 stars, 548,521,708 downloads, release 1.8.7; sqlite3 848 stars, 203,687,545 downloads, release 2.10.2; benchmark-ips 1,776 stars, 91,529,625 downloads, release 2.15.1. All repositories are unarchived. Last pushes/releases and exact responses are retained in `*-project.json` and `*-rubygems.json`. Rails is the subject and MessagePack is a Rails cache coder, not a list of claimed downstream callers; benchmark-ips and SQLite are the current measurement tools. No abandoned, niche or superseded gem-version citation needs cutting, and no multi-project caller list needs reordering. Ruby's repository currency is recorded too.

## Worst input and upstream overlap

`run-benchmarks.sh` retains three full interleaved main/head/main2 rounds on core 1 with the fixed heap. The size sweep covers 6, 100, 300 and 1,500 columns, cold wide records, 1 MiB Marshal payloads and serializers scanning 1 MiB every call. Head improves both ordinary-width cases; the two 1 MiB cases are inside their A/A variation. These are ungated timing observations, not replacements for body measurements.

The slowest measured input is the custom type reversing a **128 MiB** string on every database serialization. Best rates main/head/main2 are 6.087/5.919/5.621 i/s: head −2.76% against an A/A −7.66%. This does not establish a slowdown; the work in application serialization overwhelms the removed row copy. Raw samples have substantial dispersion, so a small loss cannot be excluded. No reruns were selected to manufacture a green result. See `worst-ips.log`, `worst-ips.json` and `worst-ips-best.txt`.

Fetched Rails main is `dbbfb84cec40d64ef7cf8fdc21e89b98dbdd1a46` at the recorded check time. GitHub returned 72 merged main-targeting PRs since 2026-11-25 (76 across branches); titles and relevant source history were inspected. None covers this work. The only post-2026-11-25 change to the hash-building storage file is the already-in-base keys/materialize change from #59800 (`upstream-keys.diff`), not these methods or the row copy. There is no diff from the requested base to fetched current main in the attribute-set, indexed-row, Marshal or MessagePack files. Method-name search returns no covering merged or open PR; the existing PostgreSQL MessagePack/bytea work concerns types, not this temporary-row construction. Raw: `merged-main-prs.json`, `merged-prs.json`, `method-pr-search.json`, `recent-attribute-commits.txt`, `pins-and-history.txt`, `upstream-since-base.diff`.

Ruby master × ZJIT was not rerun at this head; the record explicitly labels its existing run as `f70d3e0917`, with missing invalidation counters and no certified JIT-flat claim. The proposed helper still needs a real branch head and re-review, including refreshed evidence, before opening.

## Readability and metrics

Cold read: materialize the set; copy its Attribute references; visit each indexed name; include a value only if its snapshotted slot contains an Attribute. Both branches are individually L1 and need no explanatory comment. Overall the duplicated protocol hits the explicit L3 gate. The storage-specific work belongs in this subclass beside `to_hash`; neither the generic AttributeSet nor IndexedRow should gain this special case.

Flog rises from the inherited generic 3.7 for each method to 10.0 for each override. RuboCop ABC rises from 2.24 to 10.25 and cyclomatic/perceived complexity from 2 to 5. This is the cost of locally owning snapshot/iteration/presence handling instead of delegating through the temporary row; the duplicated ownership is the reason to consolidate it. The base class methods themselves remain unchanged. Metrics thresholds were deliberately zero to expose values; their nonzero exit is diagnostic, not a project lint failure. Project RuboCop reports two files inspected, no offenses. Raw: `flog-*`, `metrics-*`, `metrics.yml`, `rubocop.log`.

Both new tests assert observable Hash content and the record's mutation, not internal classes or call counts. Their distinct application callbacks justify keeping both. No additional test or code comment is requested.

## Evidence packaging

`SHA256SUMS` covers the other 97 files. The retained raw probe output and patch context contain trailing spaces, so a whitespace check of the entire evidence commit reports those original bytes; they were not normalized. The Markdown and executable source files pass the whitespace check, shell scripts pass `bash -n`, and `audit_body.py` compiles. The signed pull/rebase preserved concurrent changes, including the new Astra record and main-combination note in L3's metadata; its title and body are unchanged from the reviewed snapshot. This pass did not edit the item.
