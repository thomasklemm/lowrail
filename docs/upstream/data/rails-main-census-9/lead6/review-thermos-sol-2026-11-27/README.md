# L6 thermos-sol review, 2026-11-27

Verdict: **changes**, confined to the proposed description and its evidence conclusions. The exact Rails code is approved at readability **L1**; no correctness or security defect was demonstrated.

Reviewed head: `8b1c6428ea056b3c5983372d85b85615ae3d3f45`.
Base: `088fc0cf61e4ba0c7987decafacc69adb3e22eec`.
Reviewer thread: https://ampcode.com/threads/T-01a21cfb-ed5d-720b-a976-c77d8b4f1a11.

This is the detailed Thermos pass, not the separate required Astra approval. Two independent, read-only subagents loaded the correctness/security and maintainability rubrics in parallel; this reviewer inspected the diff, resolved their findings, ran the probes and measurements, and synthesized the verdict. No other threads were created. Neither the queue item nor the Rails branch was edited.

The final signed sync brought in the coordinator's call-count wording fix and the independent Astra record. That original finding is resolved below; the three remaining must-fixes still apply. The simultaneous Ruby-pin update explicitly permits comparisons already running on 4.0.9 to finish on that pin, as these did.

## Must-fix findings

### 1. Remove the uncertified blanket allocation assertion

`bench/upstream/pr-queue/items/L6.md:31` says “objects per call unchanged.” The current run's interpreter `update!` allocations are base 207.987, candidate 207.987, second base 207.999. Its generated table withholds that allocation row. YJIT and the 102-column update controls differ too. This is not an allocation regression, but the supplied run does not certify the blanket claim under `docs/upstream/body-numbers.md`.

Replace the body heading exactly with:

> Callgrind instructions per call, Ruby 4.0, no JIT:

In `docs/upstream/rails-main-census-9.md`, replace the refreshed section's sentence “Objects are unchanged (208 / 90 / 32 at 30 columns).” with:

> Objects per call are unchanged for find then `changed?` and `serializable_hash` (90 and 32). The two base allocation runs differ for `update!`, so no allocation count is claimed for that row.

The item's impact summary repeats the same blanket claim and should be narrowed when the builder records the pass.

### 2. Lead with a runnable native benchmark and actual output

The proposed body has only a Callgrind table. DECISIONS' “Benchmark tables in the project's own format” requires a short benchmark-ips/benchmark-driver script and its before/after output for Rails. The older-head record's noisy wall-time results explain not claiming a speedup, but are not a recorded waiver of the current presentation requirement.

Add the runnable script in `native_benchmark.rb` and the actual benchmark-ips output retained by `body-rerun/`, without promoting a noisy result to a speed claim. Suggested introductory text:

> A benchmark of serializing a record from a 30-column table:

Callgrind can remain supporting instruction evidence; it must not be described as elapsed time. The builder must review the final assembled body after adding the native output. Do not invent a speedup if the A/A does not resolve it.

### 3. Do not turn ungated ZJIT observations into “No ZJIT loss”

`docs/upstream/rails-main-census-9.md:258–266` ends with “No ZJIT loss.” Both retained master/ZJIT runs have `claim: false`, `jit.flat: false`, and “not JIT-flat, no claim,” because that Ruby build lacks `invalidation_count`. The longer-warmup negative delta is still ungated. This does not demonstrate a regression; it prevents certifying its absence from these runs.

Replace “No ZJIT loss.” exactly with:

> These are ungated observations; without an invalidation counter, the runs do not establish a ZJIT gain or rule out a regression.

Keep the percentages diagnostic and explicitly ungated in the internal record and item impact. Do not count them as a passing JIT-flat result. The available compilation counters being flat does not replace the missing invalidation counter. Any policy decision accepting this limitation before opening belongs to the coordinator; this pass does not waive the evidence rule.

The same paragraph also cites a separate `--zjit-stats` run with 600,000 fewer sends and 12% fewer `zjit_insn_count`. Neither that raw counter run nor its A/A/OOM control was found in the item's listed evidence directories (`rg` for the counter names and values found no output). Commit and identify that evidence before retaining those claims, or replace the text from “it is −1.0%” through the paragraph's end exactly with:

> it reads −1.0% (A/A 0.07%). These are ungated observations; without an invalidation counter, the runs do not establish a ZJIT gain or rule out a regression.

## Call-count finding resolved during sync

The originally reviewed `L6.md:29` presented three `#keys` calls as a general saving invariant. The measured default update does call it three times, but setting `Post.partial_updates = false` reduces it to one on both base and head. `call_count_variants.rb` and `call-counts-{base,head}.txt` retain this counterexample. The coordinator independently applied Astra's narrower sentence before this review's final push:

> In the measured `update!` of one column, dirty tracking calls `#keys` three times and `#[]` once for each attribute it checks.

That resolves the universal-count finding without changing the head. The initial snapshot is retained in `item-reviewed.md`; this review did not edit the item. The incoming Astra record is separate evidence and is not counted as one of this review's parallel legs.

## Optional points

* The title is accurate but narrower than the change. Optional replacement: “Inline lookups in LazyIndexedAttributeSet#[] and #keys”.
* The first paragraph can avoid an incomplete dispatch-count framing: `#[]` also bypasses `attribute_at`, and `index_for_name` calls the `indexes` reader. A shorter replacement that names preserved paths instead of asserting broad equivalence is:

> `LazyIndexedAttributeSet#[]` and `#keys` look up attribute indexes and cached attributes through small helper methods added in #59141. Dirty tracking calls them while saving a record, so their overhead grows with the number of columns even when only one changes.
>
> This change reads the indexes and cached attributes directly in those two methods. The default-attribute and unknown-name paths stay the same, and `#fetch_value_at` already reads the cache directly.

* If the commit is amended for another reason, its motivation can avoid the same universal-save framing. Optional replacement commit body:

```text
Dirty tracking visits attributes by name through #[] and #keys when
saving a record. Inline their index and attribute-cache lookups so
these visits do not need the helper calls for each column.
```

None of these optional wording changes is needed to establish code correctness. Amending changes the head and invalidates exact-head code approvals.

## Code and exactness

The only diff is four expressions replaced in `activemodel/lib/active_model/attribute_set.rb`. In `#[]`, a known name returns the cached Attribute or the existing default; an unknown name still returns `Attribute.null(name)`. Slot zero stays truthy. In `#keys`, a cached Attribute's `initialized?` determines membership; otherwise the existing row-presence short circuit and default path remain. The cache is read inside each iteration, not hoisted across a callback that could create it.

No new guard, state, helper, loop, conversion, allocation site, comment, test, dependency, or load-time action was added. The surviving guards preserve known versus unknown names, lazy absence of the cache, cache hits versus defaults, and initialized versus missing attributes. `default_attribute` and all its stores, typecasting, duplication and freeze behavior are unchanged.

The `indexes`, `index_for_name`, `attribute_at` and `lookup` dispatches skipped by the inlining can distinguish overrides of these internal methods. That is DECISIONS' explicitly accepted private/`:nodoc:` boundary. Neither reviewer found a Rails subclass, prepend or consumer requiring those dispatches. Arbitrary third-party monkey patches are not certified.

`differential_probe.rb` includes the existing K1 harness, then adds 20 record states × 13 names, repeated reads, five duck-name cases, reentrant mutation during `hash`, a fiber suspended there, a Hash-subclass index table, and a frozen cache. The two outputs are byte-identical: **19,256 lines**, with `INCONSISTENT: []` and `EXTENDED_PROBE_COMPLETE`. Frozen error addresses alone are normalized. The underlying K1 harness's two attempts to *write* the obsolete 6.1 marshalling format raise the same `ArgumentError` on both trees; this is not a successful legacy-format load test.

Names include known and unknown Strings, Symbols, nil, Integer, frozen Strings and String subclasses whose public/private conversions raise. States include partial selects, extra aliases, new and assigned records, frozen records, dup/clone, becomes/STI, save, Marshal and YAML. Outputs compare Attribute class/name/initialization/user-origin, values and missing-value errors, ordered keys, dirty state and attributes.

Exactness checklist coverage:

1. Inspected removed internal dispatch and downstream callers; probed overridden argument methods and reentrancy. Internal helper overrides remain the accepted exclusion.
2. Probed Hash and String subclasses. Array access stays the same `[]` send on the same internal array; no iteration/conversion/accumulator protocol was changed.
3. No conversion was added or removed; conversion traps and duck `hash`/`eql?` counts match.
4. No user-object call is added or skipped; only the named internal helper/reader dispatches disappear.
5. `row_keys` still supplies the same fresh keys array and `keep_if` still filters it; no user result is newly adopted.
6. Reentrant mutation and a suspended fiber at name hashing produce the same results, including changes to the attribute cache.
7. Frozen records, names and cache arrays match, including exception class and message after address normalization.
8. Requires and configuration reads are unchanged; the probes independently boot each tree. No new standalone-require contract is asserted.

The attribute-set suite passes on each tree: **44 runs, 103 assertions, 0 failures/errors/skips**. Attributes, attribute-dirty, dirty and serialization contract files also pass on each tree: **82 runs, 216 assertions, 0 failures/errors/skips**. This review did not rerun the full SQLite/PostgreSQL suites; the builder's suite summary remains separately attributable evidence.

## Readability and metrics

Classification: **L1**, slightly lower-level but immediately readable. It is not L2/L3: there is no copied whole method, new mechanism, index loop or version branch. Inlining only `index_for_name` would leave much of the targeted dispatch and is not materially clearer; removing helpers everywhere would broaden the diff unnecessarily.

Flog 4.10.0 and RuboCop 1.93.0, identical standalone metric configuration with thresholds zero to expose values:

| Method | Flog | ABC | Cyclomatic | Perceived | Length |
| --- | --- | --- | --- | --- | --- |
| `#[]` | 3.8 → 5.5 | 3.74 → 5.74 | 2 → 4 | 3 → 5 | 5 → 5 |
| `#keys` | 12.0 → 12.0 | 9.43 → 9.90 | 4 → 5 | 5 → 6 | 8 → 8 |

The increases expose nil/cache/fallback decisions previously hidden in callees, rather than adding runtime decisions. `metrics.yml`, the JSON and Flog output retain the calculations. This is not a Rails-configured RuboCop pass: the first attempt lacked Rails' RuboCop plugins, and the standalone metric run deliberately does not replace Rails' pinned style check.

## Claims, history and submission bar

Title: accurate. Historical attribution: the fetched merge of #59141 contains these helper paths (`introduction.txt`, `introduced-attribute-set.txt`). The default caller trace supports the measured update's three `#keys` calls and 38 `attribute_changed?` calls, not a universal count. The inlining and `#fetch_value_at` statements match the inspected source; the safer paragraph above avoids internal-override and counting distractions.

`audit_body_data.rb` recomputes **every instruction cell** of the four current body runs from the archived dumps' trailing `totals:` lines, subtracting N=0 and dividing by N. All match the JSON exactly (`ALL_ARCHIVED_TOTALS_MATCH`). The three table rows and 102-column/YJIT sentences are numerically supported; the YJIT update and find/changed rows have flat recorded windows. YJIT serialization is too close to its A/A to promote and is not claimed in the body. The allocation and ZJIT qualifications above are necessary despite the matching instruction arithmetic.

The exact head has one parent, the requested base; author and committer are **Thomas Klemm <github@tklemm.eu>**, with no trailers. The full patch/message is `head.patch`; `git diff --check` passes. No added comments need removal.

The fetched current upstream main and live remote main both equal the requested base. The merged-PR query since 2026-11-25 returned 71 results, including stable-branch backports; all titles were read. First-parent path history shows K1 is the only merged change in that interval to the relevant attribute-set/read paths. Its diff removes the redundant keys union and context type-key machinery, not these lookups. The older related #59833 and #59963 merged on November 18 and 24 respectively; neither covers the inlining. Current main still has the original helper calls. `recent-main.txt`, `recent-attributes-first-parent.patch`, `merged-prs.json`, remote refs and related-PR metadata retain this check. The head merges cleanly with the fetched main (`merge-tree.txt`).

The relevance/currency rule finds no third-party gem/app citation to prune or reorder in the proposed body. Its only linked project is the target Rails repository via #59141: active, not archived, 59,174 stars and last push 2026-11-27T11:44:38Z at the check (`cited-projects.json`). Ruby 4.0 identifies the measured runtime, not an external caller or project endorsement.

The change still targets a broad path on current Rails main, and the retained interpreter and YJIT instruction deltas give L1 a per-call CPU effect outside A/A. It is not a JIT-only workaround. Nevertheless, **the present description/evidence package does not clear the opening bar** until the findings above are resolved, the assembled body is checked, and Astra approves the exact final head. This pass does not open, post, push to the Rails fork, or waive a queue cap or ownership gate.

## Reproduction and retained evidence

All runs use Ruby 4.0.9, revision `3e93b23afc`, except the builder's separately identified master/ZJIT data. Scratch Rails worktrees live under `.amp/in/orb-backup/l6-review/{base,head}`. The pinned Valgrind was built with `bash script/bench-valgrind .amp/in/orb-backup/l6-review/valgrind`; its build log and each run's manifest are kept.

`base.Gemfile`/`head.Gemfile` and their locks retain the probe/test tooling. For either SIDE, set `BUNDLE_GEMFILE` to that file and run `mise exec ruby@4.0.9 -- ruby differential_probe.rb` or `call_count_variants.rb` from the repository root. The scripts resolve their shared fixtures relative to their evidence directory. For focused tests, add the corresponding `activemodel/lib`, `activemodel/test`, and `railties/lib` directories to Ruby's load path.

Each `script/upstream-bench` output directory keeps its generated commands, script, Gemfiles/locks, manifests, process logs, raw dumps and results. The fresh measurement conclusions follow.

## Fresh body-row measurement

`body-rerun/` reruns the 30-column `serializable_hash` case through `script/upstream-bench`, with interpreter and YJIT modes, warmup 300, N=200, and three benchmark-ips rounds pinned to core 1. Both trees are clean and at the exact requested pins. The independently built patched Valgrind 3.19.0 and the same third-party resolution are recorded in the run.

| Cell | Base (mean of controls) | Head | Change | A/A |
| --- | ---: | ---: | ---: | ---: |
| Interpreter instructions/call | 191,241 | 178,894 | −6.46% | 0.18% |
| YJIT instructions/call | 194,977 | 192,662 | −1.19% | 0.58% |
| YJIT benchmark-ips, best of 3 | 50.4k i/s | 52.3k i/s | +3.7% | 0.76% |

The interpreter result reproduces the body's approximately 6.6% saving. The fresh YJIT instruction result is only about twice its A/A and is not promoted to a separate claim. All six YJIT Callgrind windows and all nine benchmark-ips windows are JIT-flat. The tool's native table is now available to satisfy the presentation requirement; this one run is not a whole-request speed claim.

`native_benchmark.rb` was also executed directly on base, head and base again, on core 2 with the fixed heap and Ruby 4.0.9/YJIT: `native-{base,candidate,base2}.txt`. This validates the proposed standalone reproduction script. Those direct runs lack the tool's JIT-window certification and are not used as new performance claims; the body output should come from `body-rerun/`.

## Size and least-benefit controls

`keys_size_sweep.rb`, through `script/upstream-bench`, measures 0, 1, 30, 102 and 32,768 names with all raw-row slots present and with the row absent. Every case has A/A controls, warmup 1 and N=5. The first absent-row warmup materializes missing Attributes; measured calls then exercise their cached `initialized? == false` branch. The present-row cases leave the attribute cache lazy. There is no early-match exit in this filter, so full and absent membership are its two uniform branch extremes.

The large case's 32,768 frozen names are 39 bytes each, or 1,277,952 name bytes, beyond the checklist's 1 MB floor. This deliberately unrealistic case stays in the record, never the proposed body.

| Case | Base instructions/call | Head | Change | A/A |
| --- | ---: | ---: | ---: | ---: |
| Empty layout, full or absent row | 2,224.4 | 2,224.4 | 0% | 0% |
| One name, full row | 4,708.4 | 4,190.2 | −11.01% | 0.04% |
| 30 names, full row | 69,555.2 | 57,317.0 | −17.59% | 0.14% |
| 102 names, full row | 230,377.4 | 188,500.2 | −18.18% | 0.02% |
| 32,768 names, full row | 73,433,413.7 | 60,026,619.2 | −18.26% | 0.005% |
| 32,768 names, absent row | 55,819,301.2 | 42,421,638.6 | −24.00% | 0.006% |

An empty layout is the constructed least-benefit input: the changed block never runs, so it cannot remove any helper work. Its measured instruction count is identical. No size-sweep case regresses. All cases, including the omitted intermediate absent rows, and all raw controls are in `size-sweep/`.

`worst_inputs.rb`, through `script/upstream-bench`, separately measures the least-benefit branches with warmup 3,000 and N=1,000 in interpreter and YJIT modes. Unknown and nil names take the unchanged `Attribute.null` fallback; an initialized cached slot and a cached missing partial-select slot exercise the two cached Attribute states. Empty `#keys` never enters the changed block.

| Case | Interpreter base → head, instructions/call | Change | YJIT base → head, instructions/call | Change |
| --- | ---: | ---: | ---: | ---: |
| Unknown String name | 3,484 → 3,242 | −7.0% | 1,725 → 1,671 | −3.1% |
| Nil name | 3,425 → 3,183 | −7.1% | 1,673 → 1,620 | −3.1% |
| Cached String name | 1,990 → 1,401 | −29.6% | 1,270 → 1,119 | −11.9% |
| Partial select, missing slot | 1,990 → 1,401 | −29.6% | 1,269 → 1,121 | −11.7% |
| Empty keys | 2,005 → 2,005 | 0% | 1,412 → 1,412 | 0% |

All five cells have A/A controls; the largest spread is 0.06% in the interpreter and 0.16% under YJIT. Every YJIT cell is flat in all six measured windows. Objects match on both base runs and head in every cell. Empty keys is again the worst relative result, with identical counts; no measured edge case regresses. The absolute slowest measured input is the deliberately large full-row size-sweep case above, which still removes 18.26% of instructions. These are instruction results, not elapsed-time guarantees. Full precision and all controls are in `worst-rerun/results.json`.

All three fresh runs keep the original dumps in `raw/callgrind.tar.gz`, with per-dump SHA-256 checksums in `raw/callgrind.sha256`. Extract that archive in its `raw/` directory before rerunning commands that expect individual dump paths.

Archive verification independently checked all 132 fresh dump hashes, their 22 instruction cells and exact clean source pins (`archive-verification.txt`). Review scripts, configuration and this report pass the scoped whitespace check. The unscoped staged-diff check flags whitespace in retained Valgrind/build logs and fetched Git text/patches; those raw outputs are deliberately not reformatted.
