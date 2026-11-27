# hashie: dblock's four performance leads after #659 (2026-11-27)

dblock merged the Duel guards (HD1) and listed four candidates that Claude found on hashie master
(hashie/hashie#659, issuecomment-7226612359). Each was checked on master `9e313f3` before building anything.

Setup: Duel on fork PRs (thomasklemm/hashie) against `perf-base` (= `9e313f3`, YJIT job only, #20–#22) and
`perf-base-zjit` (= HD2's head `f6545d1`, a YJIT and a ZJIT job, #23–#25), GitHub's runners, Ruby 4.0.10. Raw logs
are in `duel/logs.tar.gz`, summaries in `duel/*.summary.txt`, and run IDs in `duel/runs.tsv`. The PRs were closed after
the data was collected. Local work ran in this orb (8 CPUs, not a1.xxlarge). Rubies: 4.0.10 `a704b7cd95` and master
`0d399335b7`, both built with YJIT and ZJIT. The allocation probes and prototypes are in `probes/`, and their output in
`allocations/`. Local wall time comes from `script/upstream-bench --wall 30` (A/A in every cohort, one pinned core
each, three cohorts in parallel on separate cores). It supports the record; the body cites only Duel's allocation
counts and the YJIT result.

## 1. Suffixed method names: holds, HM2

`_method_name_and_suffix` started from `Symbol#to_s`, which allocates one String per call. The leads said 3 Strings:
it is 3 per call, and one of the 3 can go. The other two are the sliced name and suffix, which callers use as keys.
The branch `thomasklemm/suffix-name` (`d1f403e`) reads `Symbol#name`, the same change as `_method_suffix`.

| | interp | YJIT 4.0.10 | ZJIT 4.0.10 | ZJIT master |
|---|---|---|---|---|
| Objects, 3 suffixed reads (body/HM2) | 16 → 13 | 16 → 13 | 16 → 13 | not measured |
| Objects, new key as a method | 6 → 5 | 6 → 5 | 6 → 5 | not measured |
| Callgrind, suffixed reads | within A/A | −4.1% (A/A 0.18%) | not JIT-flat, no claim | |
| Callgrind, new key | +0.2% (A/A 0.01%) | −2.3% (A/A 0.02%) | not JIT-flat, no claim | |
| Wall, suffixed reads | −0.3% [−0.7, +0.5], no claim | −4.0% [−4.2, −3.6], A/A −0.3% | (−1.0%, not JIT-flat) | −0.3% [−0.5, +0.3], no claim |
| Wall, new key | −1.9% [−2.6, −0.8], A/A +0.5% | −3.3% [−4.0, −2.7], A/A +0.3% | (−0.7%, not JIT-flat) | −1.1% [−1.2, −0.9], A/A −0.1% |

ZJIT 4.0.10's stats lack `compiled_side_exit_count`, so `script/upstream-bench`'s JIT-flat gate refuses every ZJIT
4.0.10 cell; the numbers in brackets are recorded, not claimed. Duel (fork #20, #23): 0 regressed under YJIT and ZJIT.
Allocations: suffixes 16 → 13, write new keys 5 → 4, overwrite 6 → 5. Every CPU verdict was "same": YJIT medians for these three
benchmarks 1.000–1.016, ZJIT 0.975, 0.990 and 0.990, against Duel's 1.05 limit.

Exactness: `probes/c1_diff.rb` covers Mash, a subclass, `quiet`, DefineAccessors, StrictKeyAccess, KeepOriginalKeys,
SymbolizeKeys, PermissiveRespondTo, SafeAssignment, TransformKeys, UnderscoreKeys, MethodAccessWithOverride, a subclass
overriding `method_missing` with `super`, and a singleton method. Inputs: 3 seeds (String keys, Symbol keys, nested,
unicode, `a?` stored keys), frozen and unfrozen mashes, and 58 names as Symbols and as Strings sent to
`method_missing`. Each row records the result and its frozenness, `respond_to?` public/private, the whole mash with key
classes and key frozenness, the warning log, and a second call (for accessors DefineAccessors defined). Result: 8,528
rows identical between base and branch on 4.0.9 and on master with ZJIT (`c1/differential.tar.gz`). Checklist: (1)
singleton and `method_missing` overrides were probed; (2) no Symbol subclasses; (3) non-Symbols still go through
`to_s`, and a global `Symbol#to_s` redefinition is accepted; (4) the only added call is `is_a?(Symbol)` on the
method name; (5) a name without a suffix is now Symbol#name's frozen String, and callers only read it (StrictKeyAccess's
message, DefineAccessors' closures through `convert_key`); stored key frozenness is unchanged in the probe; (6) no
iteration; (7) frozen mashes give identical FrozenErrors; (8) no load-order effect. Suite: Ruby 4.0.9 `rake spec`
1,076/0, rubocop 124 + 156 files clean.

### Head eae505a after Astra's must-fix

Astra found that `d1f403e` returned Symbol#name's frozen String for a name without a suffix. DefineAccessors then hands that
String to a public default proc, so `m.default_proc = proc { |h, key| h[key.upcase!] = 7 }; m.missing` raised
FrozenError where master returned 7 (reproduced, `probes/astra_repro.rb`). `eae505a` finds the suffix in
`Symbol#name` and returns `method_name.to_s` for an unsuffixed name, as master did. `c1_diff.rb` now also sets
mutating default procs on Mash, DefineAccessors and StrictKeyAccess. Its 10,400 rows are identical to master on 4.0.9
and master+ZJIT, and the same probe finds 16 differing rows on `d1f403e` (`c1/differential-eae505a.tar.gz`). The
benchmarked paths are all suffixed, so their allocations are unchanged (13, 5, 5). The body's Callgrind and YJIT wall
runs were repeated on `eae505a` (`body/HM2-eae505a`, `c1/wall-4.0.10-yjit-eae505a`).

### Head 1af7ad9 after thermos-sol's must-fix

On `eae505a`, a non-Symbol name without a suffix went through `to_s` twice, which a String with its own `to_s` can
observe. thermos-sol's repro is a StrictKeyAccess KeyError message: master names the second result, `eae505a` the third
(`probes/sol_repro.rb`). `1af7ad9` returns `name` for non-Symbols and `Symbol#to_s` for Symbols, using thermos-sol's
validated one-line fix. Both repros now match master. `c1_diff.rb` gives 10,400 identical rows on 4.0.9 and
master+ZJIT, `rake spec` passes 1,076/0, rubocop is clean, and suffixed allocations are 13, 5, 5. Duel on the final
head: fork PR #26 (`duel/`).

## 2. `deep_merge` copies the whole tree: a real win, not exact, not opened

Confirmed: `dup` is `self.class.new(self, ...)`, so every key goes through `custom_writer` again, including the
key-conflict check (`respond_to?` → `respond_to_missing?`). On the fixture: dup 20 objects (interp) or 24 (JIT),
deep_merge 26 or 30. In Duel, deep_merge allocates 31.3 and Mash.new 25.3. The leads' 61 vs 56 matches neither,
probably older numbers.

Prototype (`probes/c2-dup-copy.patch`): `regular_dup.clear`, then `copy.regular_writer(copy.convert_key(k),
copy.convert_value(v, true))` per pair. Duel: deep_merge cpu **0.346 (YJIT), 0.316 (YJIT) and 0.359 (ZJIT)**,
allocations 31.2 → 13, and nothing regressed (fork #22, #25). Locally (`allocations/candidate-2-dup.txt`), dup takes
65 → 19 µs (interp), 28 → 9 µs (YJIT) and 60 → 17 µs (ZJIT 4.0.10), with objects 20/24 → 6.

Not exact: 4 specs fail (`method_access_spec.rb:226, 283, 292, 302`). MethodAccessWithOverride redefines conflicting
methods per instance in its `initialize`, and a copy that skips `self.class.new` doesn't get them. RequiredKeys'
initialize check and any user subclass `initialize` would be skipped the same way. The copy also no longer re-logs
key-conflict warnings, a difference outside the specs. `regular_dup.clear` plus `custom_writer` (variant B) is exact for
the writer path, but CPU time is unchanged (YJIT 28.0 vs 27.3 µs), because the time is in the per-key collision check
itself. Every exact form keeps that check, and every form that skips it changes subclass `initialize` and logging.
Recorded, not opened; told dblock in the reply.

## 3. `Mash.new` allocates 53 Strings of 56 objects: does not hold

Mash.new of the fixture, objects from hashie's lib (`allocations/candidates-3-4.txt`): **20.2 (interp), 24.2 (YJIT,
ZJIT 4.0.10), 18.2 (ZJIT master)**, with Strings 8.1, 12.1 and 6.1. Duel reports 25.3. Per call: 4 `deep_update`
splat Arrays, 3 Mashes, 2 Hashie::Arrays, 1 dup of the nested plain Hash. **8 Strings and 2 Method objects come from
building the key-conflict warning for the two licenses' `"key"` field** (`Hash#key`), although the benchmark's
logger is `Logger.new(nil)`. `Hashie.logger.warn { ... }` would skip building it for a nil or quieter logger, but it
changes what a duck-typed logger without block support receives. That matters only for payloads with conflicting keys,
so it was not built. StackProf (`probes/prof.rb`, interp): `_log_collision?` holds 38% of Mash.new samples
(`respond_to?` 34%), `convert_value` 48% inclusive, and `convert_key` 12% self. No exact reduction beyond helper
inlining, which DECISIONS rules out.

## 4. `dig` and `method_missing`'s `*args`: do not hold

`dig`: `keys.map` is one Array per level, and Hash#dig re-enters Mash#dig for nested Mashes, so `dig(:owner, :login)`
is 4 objects (8 in the standalone probe on another fixture). `map!` reuses the splat Array: 4 → 2 objects, exact for
callers since the splat is always a fresh Array. Duel (fork #21, #24) under YJIT: `Mash: read keys with [] and dig` cpu
**1.113–1.126 slower, regressed** in all 4 measurements on both runs (Duel's profile names `Hash#dig` and `Mash#dig`).
Under ZJIT: 0.984, same. Not opened. Converting only the first key per level is not exact: a nested plain Hash or custom
Hash would get Symbol keys where it got Strings.

`method_missing(method_name, *args, &blk)`: an empty `*args` allocates 1 Array per call on 4.0.9, 4.0.10 and master in
every mode (`probes/mm_probe.rb`). `...` avoids it and still accepts extra arguments (mm_probe C), but the `=` branch needs the first argument, which
`...` cannot name. A fixed `value = nil` names it, but would make the extra arguments that the current signature ignores
raise ArgumentError. Not exact; not built.

## Ownership

No open hashie PRs except our HD2 (#660). Open issues #450 and #229 are unrelated. Searches for
`method_name_and_suffix`, suffix allocations, deep_merge or dup performance, Mash#dig and Mash.new found only closed
2015–2019 issues about other behaviour.

## Reply draft to dblock (issuecomment-7226612359)

For both reviewers' approval of the exact text; `#661` is HM2's number if nothing opens before it.

```text
Thanks for digging these up. I measured each one on master with Duel (YJIT and ZJIT) and locally:

1. #661 finds the suffix in `Symbol#name`, one String fewer per split: "read keys with suffixes" goes from 16 to 13 objects, CPU time the same.
2. Copying already converted values in `dup` makes `deep_merge` about three times faster (31 to 13 objects), but it skips the subclass's `initialize`, which `MethodAccessWithOverride`'s `dup` specs need, and stops re-logging key conflict warnings. This prototype breaks existing behavior, so I left it.
3. `Mash.new` allocates about 25 objects for the fixture in Duel, not 56. The two licenses' `key` fields cause warning Strings to be built even though the benchmark logger discards the warnings.
4. `dig` with `map!` saves two objects, but Duel found the `[]` and `dig` benchmark 12% slower under YJIT. I left `method_missing`'s `*args` too: the setter needs the argument, and a fixed arity would reject the extra arguments it accepts today.
```

## Astra: changes on d1f403e; code and body approved on eae505a (2026-11-27)

Reviewer: `astra`, thread `T-01a21ea6-c103-7055-b928-054d2f8d8df1`. Reviewed exact heads `d1f403e0774a7ad509ae06477407dbc2836491fd` and, after the coordinator's repair, `eae505a846f162e743b65261a7cda01d32e84f85`, each against `9e313f308f3270995c2c978e92f0f216b861861b`. No subagents, new threads, upstream posts or fork pushes. Evidence and runnable probes: [astra-eae505a.tar.gz](astra-eae505a.tar.gz). The archive includes both patches, the reviewed text, raw outputs, commands, tool manifest and the rejected system-Valgrind attempt.

### Demonstrated regression and repair

The original head changes public behavior, not just a private helper's return value:

```ruby
klass = Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::DefineAccessors }
mash = klass.new
mash.default_proc = proc { |hash, key| hash[key.upcase!] = 7 }
mash.missing
```

Master returns `7` and stores `{"MISSING" => 7}`; d1f403e raises `FrozenError: can't modify frozen String: "missing"`. The generated unsuffixed reader passes the helper's name to `custom_reader`, which passes it to the public default proc. The coordinator's eae505a returns `method_name.to_s` in the unsuffixed branch; the same repro again returns `7` with the same stored hash. The archive's `default-proc-*.txt` also records the second instance after the generated accessor already exists. Both revisions keep mutable slices for suffixed Symbol names.

Own runs on Ruby 4.0.10 `a704b7cd95`: the extended `c1_diff.rb` has **10,400 identical lines** between master and eae505a. The original probe also matched d1f403e on 8,528 lines on Ruby 4.0.9, explaining why it missed this callback. Log timestamps/PIDs were normalized, not messages or values. A separate **4,480-case** probe covered all nine Mash extension modules, MethodAccessWithOverride, three DefineAccessors combinations, subclass and prepended `method_missing` forwarding, extra positional/keyword arguments and blocks, repeated generated accessors, frozen receivers and keys, String subclasses, frozen Strings, Symbols, nil, integers, a duck-typed name, empty names, NUL, binary bytes and Unicode. Ordinary outcomes match on eae505a. Targeted Mash/extension specs: master, d1f403e and eae505a each **301 examples, 0 failures** (`ruby -Ilib -S rspec spec/hashie/mash_spec.rb spec/hashie/extensions/mash spec/hashie/extensions/method_access_spec.rb --format progress`). This reviewer did not rerun the full suite or Ruby master; the retained earlier master+ZJIT differential files were also compared successfully.

Two deliberately nonstandard direct-call differences remain, recorded rather than hidden:

* A String with a singleton `is_a?` that raises, passed directly to KeepOriginalKeys' `method_missing`, returns `7` on master but raises on both candidate heads. Ordinary Ruby method dispatch supplies a Symbol, and no documented caller requiring this overridden introspection was found.
* A String subclass whose `to_s` raises on its second call, sent directly to KeepOriginalKeys' `method_missing` without a suffix, returns nil on master and d1f403e but raises on eae505a. Its new unsuffixed branch calls `to_s` twice. Ordinary Strings remain identical. This is the explicitly acknowledged direct non-Symbol boundary, not a claim of equivalence for arbitrary conversion hooks. No new guard is requested without a documented caller, per DECISIONS' guard rule.

Checklist: singleton/prepend/subclass and conversion boundaries tested; frozen receivers, keys, results and error classes/messages compared; name mutation tested through the public default proc; no changed iteration, configuration access, loading or shared mutable cache. The replacement String is not exposed for suffixes. No new code comments. Cold read: borrow the Symbol's frozen name to find and slice a suffix; otherwise return its mutable `to_s` as before. Flog for the touched method is 4.9 → 8.6; RuboCop Metrics ABC 4.58 → 7.68, cyclomatic 2 → 3, perceived 3 → 4, length 6 → 6. The rise is the Symbol branch and preserved unsuffixed conversion, not new layering; readability remains L0. Metrics were measured with zero thresholds to expose the scores, not claimed as lint failures.

### Slowest measured input and allocation controls

The adverse shape is an unsuffixed name: the new type check and name lookup cannot save the final mutable String. A direct String name is worse because it saves no conversion and now repeats `to_s`. Ran `script/upstream-bench` workers with pinned Valgrind 3.19.0/512-MiB brk, Ruby 4.0.10, fixed heap settings, interpreter, N=100 minus N=0, and master twice. No time was measured on this 8-CPU orb. The system-Valgrind attempt hit brk overflow and is rejected; its outputs remain in the archive.

| Input to `method_missing` | Master instructions/call | eae505a | Change | A/A |
| --- | ---: | ---: | ---: | ---: |
| `:"?"` | 8,999.48 | 9,037.96 | +0.43% | 0% |
| `"?"` | 8,804.35 | 9,093.06 | +3.28% | 0% |
| Unsuffixed 16-byte Symbol | 6,882.20 | 7,249.62 | +5.34% | 0% |
| Unsuffixed 16-byte String | 7,460.93 | 7,947.48 | **+6.52%** | 0% |
| 1-MiB ASCII Symbol, final `?` | 1,057,898.73 | 1,057,861.62 | −0.004% | 0% |
| 1-MiB ASCII String, final `?` | 1,057,807.68 | 1,058,098.72 | +0.028% | −0.00074% |

The Symbol unsuffixed row is also a normal missing-method call shape; the overhead is not confined to artificial String dispatch. These are interpreter instructions, **not demonstrated wall-time regressions**. This limited sweep is not a universal worst-case bound. Allocation workers also covered 1-, 16- and 1,048,576-byte names with no suffix, an early `?` that is not a suffix, and a final `?`, as both Symbols and Strings. Symbol suffix splits save one object; String inputs do not. Separate base/head/base controls show a stored exact suffixed key stays at about 1 object/call, an ordinary missing suffix falls 5 → 4, and StrictKeyAccess falls 10 → 8 because it splits twice. Thus the body's corrected "Splitting a suffixed name" is right; "every suffixed call saves one" is not.

### Body and reply claims checked

* Read the exact diff, gemspec (Ruby ≥3.0), all helper callers, the benchmark fixture and benchmark definitions, merged #656's body and metadata, and dblock's original comment through GitHub's API. `_method_suffix` already uses `Symbol#name`; the basic mechanism, examples and CHANGELOG placement are correct. Only #660 was open at the check; **#661 must still be verified when opening**.
* Inspected the six raw Duel logs in `duel/logs.tar.gz`, not just summaries. Suffix allocation rows are 16 → 13, 5 → 4 and 6 → 5. All relevant CPU classifications are `same`; this is Duel's configured 1.05 threshold, not proof of equal time. Those Duel runs used the original suffix prototype, not eae505a. Own allocation probes confirm the same suffix savings; these are the same suffix-path operations in eae505a. The body table is acceptable with that provenance retained here.
* The old local YJIT wall record really reports −4.0209% with A/A −0.3411% and an interval containing zero for A/A. It was run on an 8-CPU orb, contrary to the current a1.xxlarge timing rule, and on the earlier head. **Approve the corrected body without that timing sentence**, not its restoration based on these old runs. The title and the body's remaining sentences are approved on eae505a.
* The dup prototype's Duel CPU ratios are 0.346 and 0.316 (YJIT), 0.359 (ZJIT), with about 31 → 13 objects. "About three times faster" accurately summarizes those tool reports. One YJIT run also has one unsettled unrelated row; "zero regressions" must not be expanded into "all rows settled". Applied the kept prototype patch to master and reproduced exactly the four MethodAccessWithOverride failures at 226, 283, 292 and 302; the targeted suite is 301 examples/4 failures. The same fixture logs two warnings when master duplicates it and zero with the prototype. The local dup timings in `candidate-2-dup.txt` match the record, but lack their own retained A/A and are not approved for a new independent timing claim. No kept variant-B timing output substantiates 28.0 versus 27.3 µs; neither that comparison nor one failed prototype proves that every exact implementation must retain all existing work.
* Duel's `Mash.new` count is about 25, not 56. The allocation-site record's 20.19 interpreter objects are **objects attributed to Hashie's library**, not the total. Own base/head/base probe gives approximately 20.93 total/7.98 Strings in the interpreter and 24.93/11.98 under YJIT; the repeated base matches. Renaming the two `key` fields removes about ten interpreter objects, including eight Strings, and fourteen YJIT objects, including twelve Strings. Hence neither "eight of the 25" nor an unqualified total of "20" is approved. The logging mechanism is verified in `_log_built_in_message`, `Utils.method_information`, the fixture and the logger configuration.
* Dig's raw YJIT reruns range from 1.113 to 1.126 and all report regression for **the combined bracket-read/dig benchmark**. ZJIT is 0.984, classified same. Allocation rows are 4 → 2. The standalone `dig_probe.rb` adds another wrapper `dig` using `super`, so its 8-object result is not merely the effect of a different fixture. The original claim that `...` rejects extra arguments is false: the kept `mm_probe.rb` variant C and my `Forwarder#method_missing(name, ...)` run both accept them. The revised explanation about the setter needing a named argument and fixed arity rejecting extras is accurate; it does not prove all other signatures impossible.

### Project relevance and currency, checked 2026-11-27

GitHub repository APIs and RubyGems APIs were fetched live and retained. `hashie/hashie`: 3,035 stars, not archived, last push 2026-11-27, current master still `9e313f3`; Hashie 6.0.0 released 2026-11-11, 507,033,809 total downloads and 222,845 downloads for 6.0.0. `sferik/duel-ruby`: 21 stars, not archived, last push 2026-11-25; gem `duel` 0.3.1 released 2026-11-22, 8,695 total downloads and 631 for 0.3.1. This is niche, but it is the actual benchmark tool adopted by the target project, not an ecosystem-reach example; its citation is necessary methodology. `ruby/ruby`: 23,868 stars, not archived, last push 2026-11-27; latest release v4.0.10 published 2026-11-18; RubyGems downloads are not applicable to the interpreter. YJIT and ZJIT are part of that project. No downstream app is cited. The prose leads with the target Hashie and mentions tools only for evidence, so there is no misleading downstream reach ordering or superseded dependency version.

### Exact replacement reply approved by Astra

At this review's initial snapshot the draft still overgeneralized the dup prototype and labeled library-attributed allocations as a total. The coordinator has since applied the two replacements below. **This exact text is approved.** Posting still needs thermos-sol's approval of the same words and the actual #661 number. Code/body approval does not waive that separate text gate.

```text
Thanks for digging these up. I measured each one on master with Duel (YJIT and ZJIT) and locally:

1. #661 finds the suffix in `Symbol#name`, one String fewer per split: "read keys with suffixes" goes from 16 to 13 objects, CPU time the same.
2. Copying already converted values in `dup` makes `deep_merge` about three times faster (31 to 13 objects), but it skips the subclass's `initialize`, which `MethodAccessWithOverride`'s `dup` specs need, and stops re-logging key conflict warnings. This prototype breaks existing behavior, so I left it.
3. `Mash.new` allocates about 25 objects for the fixture in Duel, not 56. The two licenses' `key` fields cause warning Strings to be built even though the benchmark logger discards the warnings.
4. `dig` with `map!` saves two objects, but Duel found the `[]` and `dig` benchmark 12% slower under YJIT. I left `method_missing`'s `*args` too: the setter needs the argument, and a fixed arity would reject the extra arguments it accepts today.
```

## Astra: approve 1af7ad9a203fef81be51abb46869eabf6db5d34e (2026-11-27)

Final pass by `T-01a21ea6-c103-7055-b928-054d2f8d8df1`: **approve the code, title, current body and exact reply draft introduced by Lowrail b7ea02a8; no must-fix remains.** This supersedes the eae505a approval above, which was too permissive about the demonstrated extra `to_s` call. Thermos-sol's StrictKeyAccess example shows why preserving it matters: master raises `KeyError` naming `name2` after two conversions, eae505a names `name3` after three, and 1af7ad9 again names `name2` after two. My KeepOriginalKeys name that raises on its second conversion also matches master again, as does the mutating DefineAccessors default proc. The final branch converts a Symbol back to a mutable String when unsuffixed and reuses the already converted non-Symbol String. No new helper or shared state is involved; L0.

Independently reran the 10,400-row differential on Ruby 4.0.10: byte-identical to master after the same Logger prefix normalization. The separate 4,480-case extension/subclass/frozen/name probe also matches, except for the already recorded direct String with an overridden `is_a?` that raises. That artificial introspection boundary remains accepted, not claimed identical. Targeted Mash and extension specs pass **301 examples, 0 failures**. Full `rake spec` could not load the missing `guard` dependency here; a direct full RSpec attempt likewise stopped before examples for missing `yard` and `ruby-gem-release`. These failed attempts are retained; this pass does not claim to have independently rerun the coordinator's 1,076-example full suite.

Reran the six Callgrind cases on the exact final head with the same Ruby, pinned Valgrind, worker, fixed heap and retained two-master controls. Unsuffixed 16-byte Symbol is now the worst observed relative increase: **6,882.20 → 7,527.33 interpreter instructions/call (+9.37%, A/A 0%)**; the String case is **7,460.93 → 8,035.35 (+7.70%, A/A 0%)**. The four suffixed cases have exactly the eae505a counts tabulated above. The extra unsuffixed type check costs instructions even though it repairs conversion behavior; this is not a wall-time claim or a universal bound. The final allocation probe still gives stored suffix 0.999, ordinary missing suffix 4.0 and StrictKeyAccess missing suffix 8.0 objects/call. Final method metrics versus master: Flog 4.9 → 10.1, ABC 4.58 → 9, cyclomatic 2 → 4, perceived 3 → 5, length 6 → 6. The second short conditional preserves conversion count without adding layering; the higher scores are acknowledged, not treated as unchanged complexity.

Read the completed Duel run **46063675164** for fork PR 26. It runs the benchmark wrapper head `0e7794cfd9a9be82f5f2ad3f3bd1ae13b04e6f6c`, not the literal reviewed commit; fetched `lib/hashie/mash.rb` and verified it byte-identical to 1af7ad9. Both YJIT and ZJIT finish with 27 benchmarks, **0 regressed, 0 errors, 0 unsettled**. Both confirm 16 → 13, 5 → 4 and 6 → 5 allocations; suffix-read CPU ratios are 1.006 (YJIT) and 0.979 (ZJIT), both `same`. The new nested-fixture counts are 25.35 and 25.64 respectively, consistent with the reply's approximate 25. The earlier dup/dig evidence and project currency checks above remain the basis for the other claims.

**Exact text approval:** the four-point reply under “Reply draft to dblock” is identical to the approved block above and to b7ea02a8. SHA-256 of its contents, including the trailing newline: `42d0e6df51851d656b8691903b4440ed06d2e0a863207da61b26b29607c193c1`. Keep `#661` as requested; it must identify the actual opened HM2 PR before this reply is posted. No replacement wording is requested. Posting still requires thermos-sol's approval of these exact words. This review posted nothing upstream.

Final-head raw evidence and probes: [astra-1af7ad9.tar.gz](astra-1af7ad9.tar.gz), supplementing [astra-eae505a.tar.gz](astra-eae505a.tar.gz). Includes final differential outputs, conversion repros, specs (successful targeted and blocked full attempts), instructions, allocation counts, metrics, reviewed patch and reply, and the complete final Duel log plus wrapper comparison.

## thermos-sol: approve — head 1af7ad9a203fef81be51abb46869eabf6db5d34e

2026-11-27, orb `T-01a21ea6-b891-70c0-8cd5-39e892fefbd1`. Both Thermos rubrics were applied personally in this
thread, without subagents or new threads, as requested. Base: `9e313f308f3270995c2c978e92f0f216b861861b`.
The final head is one commit on that base. Correctness/security, maintainability, the queue title/body, upstream
commit message, CHANGELOG line and the exact reply above are approved. No open must-fix. This pass does not approve
the original `d1f403e` or intermediate `eae505a` heads.

### Demonstrated findings and their fixes

* On `d1f403e`, an unsuffixed Symbol name became frozen. Besides Astra's public default-proc repro, a mutating
  TransformKeys callback composed with StrictKeyAccess or DefineAccessors raised FrozenError instead of the base's
  KeyError or nil. The independent probe found 64 differing rows. Returning a fresh `Symbol#to_s` String in that
  branch fixes it. The initial checklist's claim that callers only read the unsuffixed name was wrong and is
  superseded by this finding and the final-head checks below.
* On `eae505a`, that fix called a non-Symbol name's `to_s` twice. A String with its own conversion made a public
  StrictKeyAccess error name `changed` instead of `expected`, with three conversions instead of two. The independent
  probe found 672 differing rows. The exact fix is the final else expression:
  `[method_name.is_a?(Symbol) ? method_name.to_s : name, nil]`. It copies Symbols as base did and reuses the one
  conversion of other names. Final default-proc, transformer and String-conversion repros all match base.

### Executed checks and retained evidence

Review scripts, outputs, dependency lock, final patch, raw Duel rerun log and metric reports are kept in
[`thermos-sol-1af7ad9.tar.gz`](thermos-sol-1af7ad9.tar.gz); `commands.txt` inside gives the commands and normalization.
Ruby used here: 4.0.9, revision `3e93b23afc`, x86_64 Linux.

| Check on the final head | Result |
| --- | --- |
| `mise exec ruby@4.0.9 -- bundle exec rake spec` | 1,076 examples, 0 failures |
| `mise exec ruby@4.0.9 -- bundle exec rake rubocop` | 124 + 156 files, no offenses |
| Independent `exactness.rb`, base versus final | 5,040 rows identical, including a fresh run with `HM2_FIX` unset |
| Kept extended `probes/c1_diff.rb`, rerun here | 10,400 rows identical after Logger timestamp/PID normalization only |
| `regressions.rb` and `size-boundary.rb` | All repros match; 27 size-boundary rows identical |
| Standalone `require 'hashie'` and `require 'hashie/mash'` | Base and final load and behave identically |
| `git diff --check HEAD^ HEAD` | Clean |

Exactness checklist:

1. Probed singleton conversions, private conversions, `extend` with DefineAccessors, prepended dispatch/response
   hooks, a singleton private method, and overridden `method_missing` with `super`; inspected all helper callers.
2. Probed Mash subclasses, String subclasses and frozen String subclasses, nested Hash/Array subclasses, and the
   Mash extensions including DefineAccessors, StrictKeyAccess, KeepOriginalKeys and SymbolizeKeys. No iteration or
   subclass conversion algorithm is changed.
3. Compared public/private `to_s` behavior and conversion traces/counts, String/Symbol names, duck-typed names and
   frozen conversion results. Nested subclass conversion hooks were present in the independent probe.
4. The Symbol guard follows neighboring `_method_suffix`; Symbol names use `name` for suffix detection, then `to_s`
   only for an unsuffixed result. Non-Symbols retain one `to_s`. Global redefinitions of core Symbol methods and
   private helper overrides remain the checklist's accepted boundaries, not a claim of arbitrary monkeypatch parity.
5. Suffixed slices remain new Strings. Unsuffixed Symbol results remain fresh mutable Strings, including when passed
   to public default procs or transformers; other conversions retain their original result rather than being copied
   or evaluated again. Compared result/key frozenness and the resulting Mash state.
6. Probed mutating key transformers in both extension include orders, a fiber suspended in the callback, repeated
   calls and block side effects. No new shared state, iteration, cached value or synchronization is introduced.
7. Probed frozen/unfrozen Mashes, frozen keys, frozen names and frozen nested values; compared results, errors/messages,
   warnings and post-call state. The size sweep used empty, 16-byte and 1,048,576-byte stems with no/early/late suffix.
8. Both standalone requires passed on base and final; no dependency, eager load or configuration read was added.

No security, feature-gate, dependency or developer-workflow regression was found in the scoped change. No upstream
test or code comment was added, so there are no implementation assertions or superfluous added comments to remove.

### Maintainability and cold read

L0: get a Symbol's shared name (or convert another name once); if suffixed, return the two slices; otherwise return
the mutable Symbol copy or the already-converted non-Symbol name. The first guard avoids changing String inputs;
the second preserves the public callback behavior demonstrated above. Both stay in the existing owning helper.
Using `name.dup` unconditionally would copy non-Symbol results that base did not copy; always calling `to_s` again
would reintroduce the demonstrated conversion regression. A wrapper, memoized type flag, version branch or helper
inlining would add concepts without simplifying these two contracts. `mash.rb` stays 654 lines, the helper 6.

| `_method_name_and_suffix` | base | final |
| --- | ---: | ---: |
| Flog 4.10.0 | 4.9 | 10.1 |
| RuboCop 1.91.0 ABC | 4.58 | 9 |
| Cyclomatic / perceived complexity | 2 / 3 | 4 / 5 |
| Method length | 6 | 6 |

The metric rise is the two short Symbol guards needed to preserve String input handling and mutable unsuffixed
results, not scattered feature logic. The metrics-only config sets limits to zero to expose the values; its reports
are not lint failures. The normal project RuboCop run is clean.

### Body, commit and reply claim audit

The title describes the scoped change. The body's first paragraph and each code example match the dispatch path;
the second explains the interned frozen name, the existing `_method_suffix` precedent and the necessary mutable
unsuffixed return. The three allocation rows match Duel, not the differently shaped local new-key fixture. The CPU
sentence reports Duel's classification, not literal equal timings or a speed claim. The upstream commit's title and
each explanatory sentence match that same source and callback repro. It has Thomas as author and committer, no
trailers, no internal identifiers and no benchmark claim beyond one avoided allocation. The CHANGELOG line matches
the change; the coordinator must ensure `#661` is the actual PR number before opening/posting.

I inspected `body/HM2` raw A/A logs, c1 wall JSON/tables, the Duel raw logs, allocation attribution and the kept
master/ZJIT differential archive. The archive's 10,400 base/head rows match after timestamp/PID normalization. No
Ruby master/ZJIT build or local wall benchmark was run in this review orb. Historical `d1f403e`/`eae505a` wall and
Callgrind numbers are not approved as measurements of the final head, and the non-xxlarge local timing is not a body
headline. The final body claims only Duel allocations and its CPU verdict.

Final-code Duel was independently checked by fetching run `46063675164`'s raw log: YJIT and ZJIT each report
27 benchmarks, 0 regressed, 0 errors, 0 unsettled. The three body rows are 16 → 13, 5 → 4 and 6 → 5 objects, all CPU
verdicts `same`. This run is on fork PR 26's workflow-carrying head `0e7794cfd9a9be82f5f2ad3f3bd1ae13b04e6f6c`,
not the literal HM2 commit: its base is HD2's `f6545d1dd34c3905fb4c8fa25764f209cb65274f`. Its diff is only the same
helper change and CHANGELOG entry; the entire `mash.rb` blob equals HM2's `1d46a64fc8551afe7394aab7f1eb2b14c8b8b230`.
All PR 26 checks were successful when read. These are inspected hosted results, not locally executed JIT runs.

During sync I also checked Astra's final-head Callgrind archives directly: subtracting N=0 from N=100 and dividing
by 100 gives unsuffixed 16-byte Symbol 6,882.20 → 7,527.33 instructions/call (+9.37%) and String
7,460.93 → 8,035.35 (+7.70%); the two base controls match. This is a real instruction cost of preserving the
unsuffixed contract, accepted alongside the suffixed allocation reduction, not a demonstrated wall-time loss.
Those are inspected retained runs, not my own measurement, and no claim that every call is faster is approved.

Reply audit, sentence by sentence:

* Opening: dblock asked for these four leads; a concrete thanks and the stated Duel/local setup answer that request.
* Point 1: source, the repeated raw allocation rows and Duel's YJIT/ZJIT `same` verdict support every claim.
* Point 2: kept Duel ratios 0.346/0.316/0.359 support "about three times faster", with 31.2 → 13 objects. I applied
  the kept prototype separately: 47 method-access specs ran, the four cited dup specs failed; initialization and
  warning counts each changed from 1 to 0, and a conflicting reader lost its stored value. The last sentence rejects
  this prototype, without claiming that no exact optimization could ever exist.
* Point 3: raw Duel reports about 25 objects. The fixture has two licenses with `key` fields; the source and kept
  allocation attribution place the warning String work there despite `Logger.new(nil)`. The approved wording avoids
  combining exact String totals from unlike runs or repeating the lead's unsupported 53/56 figure.
* Point 4: `map!`'s raw allocation row is 4 → 2; the kept YJIT CPU ratios 1.113–1.126 support the rounded 12% loss
  for the combined benchmark. The setter reads the first splat argument; a fixed-arity repro rejects extras that
  current readers/setters accept. Anonymous rest still accepts extras, so the reply correctly does not claim that
  every alternative signature is impossible.

The reply has no ping, unsolicited burndown data, internal queue/process detail, request for attention or credit
claim. Candidates 2–4 remain recorded and unopened. The exact current fenced text above is approved unchanged:
987 bytes including its final newline, SHA256 `42d0e6df51851d656b8691903b4440ed06d2e0a863207da61b26b29607c193c1`.
Astra's final-head approval landed during sync and names that identical reply hash; both text approvals are now
recorded. The coordinator still must verify the actual PR number before posting. This thread pushed no Hashie
branch, opened no PR and posted nothing upstream.
