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
every mode (`probes/mm_probe.rb`). `...` or a fixed `value = nil` avoids it, but extra arguments, which the current
signature ignores, would raise ArgumentError, and subclasses call `super` with the arguments. Not exact; not built.

## Ownership

No open hashie PRs except our HD2 (#660). Open issues #450 and #229 are unrelated. Searches for
`method_name_and_suffix`, suffix allocations, deep_merge or dup performance, Mash#dig and Mash.new found only closed
2015–2019 issues about other behaviour.

## Reply draft to dblock (issuecomment-7226612359)

For both reviewers' approval of the exact text; `#661` is HM2's number if nothing opens before it.

```text
Thanks for digging these up. I measured each one on master with Duel (YJIT and ZJIT) and locally:

1. #661 reads suffixed names from `Symbol#name`, one String fewer per call: "read keys with suffixes" goes from 16 to 13 objects, CPU time the same.
2. Copying already converted values in `dup` makes `deep_merge` about three times faster (31 to 13 objects), but it skips the subclass's `initialize`, which `MethodAccessWithOverride`'s `dup` specs need, and stops re-logging key conflict warnings. Keeping both means keeping the per-key conflict check, which is where the time goes, so I left it.
3. `Mash.new` allocates about 25 objects for the fixture here, not 56. Eight of them are Strings for the conflict warning on the two licenses' `key` fields, built even though the benchmarks' logger discards it.
4. `dig` with `map!` saves two objects but Duel found it 12% slower under YJIT, and removing `*args` from `method_missing` would make extra arguments raise, so neither changed.
```
