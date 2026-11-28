# hashie, round 2: what else can be made better (2026-11-27)

A deeper look after dblock's four leads ([round 1](../README.md)): which hashie classes the popular dependents use,
where a realistic API workload spends objects and time, and which exact changes follow. Three candidates were built:
All three are held after review, each not exact in a case its own differential never recorded (HM5 waits for
Thomas's decision); the rest are held with their numbers. **No hashie PR was opened in this round.**
`candidates.bundle` holds the three final heads and HM4's two earlier forms (`git fetch candidates.bundle
'refs/heads/held/*:refs/heads/held/*'` in a hashie clone).

Setup: hashie master `9e313f3`. Rubies 4.0.10 `a704b7cd95` and master `0d399335b7`, both built with YJIT and ZJIT;
suites also on 3.0.7 and 3.4.7. Duel ran on fork PRs (thomasklemm/hashie #27–#29, #32) against `perf-base-zjit`
(master plus the ZJIT job), on GitHub's runners with Ruby 4.0.10; run IDs in `duel/runs.tsv`, summaries in
`duel/*.summary.txt`, full logs in `duel/logs.tar.gz`. After the ZJIT job and the suffix change merged upstream
(master `277e88e`), HM5 and HM4 were rebuilt on it and Duel ran again on fork PRs #33–#36 against `perf-base` =
`277e88e`; the local HM4 cohorts named `10a9303` and `body/HM4` use that base too. Fork measurement PRs are closed
and their branches deleted once recorded ([fork-cleanup](../../hashie_duel/fork-cleanup/README.md)). Local runs used this orb (8 CPUs, not a1.xxlarge), so local
wall time supports the record only; **bodies cite Duel**. Local wall time is `script/upstream-bench --wall` (fresh
base / candidate / base processes per round, one pinned core, A/A in every cohort); `probes/quick.rb` is a
screening loop without A/A and decides nothing.

Workload: `fixtures/github-org-repos.json` (30 repositories of the rails organization from GitHub's API, 83 keys
each with nested owner, license and permissions) and `fixtures/github-issues.json` (30 issues), fetched 2026-11-27.

## Reach: Mash, and mostly subclasses that disable warnings

`out/rubygems-runtime-revdeps.json` (`.amp`-side script, rubygems.org API, 2026-11-27): 1,681 gems depend on hashie
at runtime, with 912M downloads in total; the 12 largest hold 83% of those downloads. What the largest ones use
(sources read at their default branches, permalinks for the cited ones in the queue items):

| Gem | Downloads | Latest | Uses |
|---|---:|---|---|
| omniauth | 235M | 2.4.2 (2026-11-18) | `KeyStore < Hashie::Mash` with `disable_warnings`; `AuthHash`, `InfoHash` (own `to_hash`, zero arity) |
| snaky_hash (oauth2) | 140M | 2.0.9 (2026-10-25) | `StringKeyed < Hashie::Mash`, own `convert_key` and `convert_value`; warnings not disabled; 2.0.9 requires hashie < 6, its main branch < 7 |
| slack-ruby-client | 96M | 3.4.0 (2026-11-24) | `Slack::Messages::Message < Hashie::Mash`, overrides the private `log_built_in_message` |
| elasticsearch-model | 78M | 8.0.1 (2025-09-01) | `HashWrapper < Hashie::Mash` with `disable_warnings` |
| restforce | 60M | 8.0.1 (2025-12-29) | `Restforce::Mash` with `disable_warnings`, own `initialize`, `dup`, `convert_value`; hashie < 6 |
| zendesk_api | 47M | 3.1.2 (2026-07-23) | `SilentMash < Hashie::Mash` with `disable_warnings` |
| faraday-mashify | 27M | 1.0.3 (2026-08-23) | plain `Hashie::Mash.new(body)` per response |
| chef-zero | 23M | 15.1.11 (2026-05-28) | `Mash < Hashie::Mash` with `disable_warnings`; hashie < 6 |
| inspec-core | 10M | 7.3.4 (2026-10-13) | plain `Hashie::Mash.new`, `DeepFind` on one Hash; hashie < 6 |

Grape's `HashieMash` params builder is plain `Hashie::Mash.new(params)` (optional dependency). None of these
reaches Dash, Trash, Clash or Rash from library code; middleman's `EnhancedHash` has its IndifferentAccess includes
commented out. So the priority is Mash: construction, method reads, `to_hash`, and the subclasses that disable
warnings (omniauth, elasticsearch-model, restforce, zendesk_api, chef-zero: 443M downloads).

Side finding: slack-ruby-client's override is dead on hashie 6, which renamed the helper to
`_log_built_in_message` (hashie/hashie#639, v6.0.0). On slack-ruby-client `0f1757e` with hashie master,
`Slack::Messages::Message.new('size' => 1, 'key' => 'x')` logs 2 warnings. No issue or PR there names it. Not
built: it is a fix in another repository; lead for the coordinator.

## Where the workload spends objects and samples

`probes/profile.rb` (30 repositories per call), Ruby 4.0.10: `out/profile-alloc-4.0.10-interp.txt`,
`out/profile-stackprof-4.0.10-{interp,yjit}.txt`; ZJIT stats on master in `out/zjit-stats-master-quiet_body-*.txt`.

* **`Mash.new` ×30: 774 objects.** 131 splat Arrays from `initialize` calling `deep_update(*other_hashes)`; 101
  `Hash#dup` in `convert_value` before `self.class.new(val)`; 101 Mashes; 30 `Hashie::Array`; and 205 objects (41 ×
  4 Strings and a Method) for conflict warnings: every repository has the key `size`, labels have `default`,
  licenses have `key`. The warning is the other thread's (round 1, last section).
* **Samples:** `Kernel#respond_to?` holds 43% of `Mash.new` inclusive (interpreter) and 49% under YJIT: the
  per-key conflict check, as round 1 found for `dup`. `convert_key` 16% inclusive, `convert_value` 26–60%.
* **Method reads ×210: 210 objects, all of them `method_missing`'s `*args` Array.** → HM3.
* **`to_hash` ×30: 292 objects** and `Hashie::Hash#to_hash` reads every value twice through `self[k]`. → HM5.
  101 of the objects are Method objects from `object.method(:to_hash).arity` (held, below).
* **ZJIT on master** (`quiet_body.rb`, 36,000 calls per case): 13.5M `rb_vm_splat_array` calls and 13.7M
  `one_or_more_complex_arg_pass` send fallbacks, one per key written: `end_with?(*ALLOWED_SUFFIXES)` in
  `_method_suffix`. 4.28M side exits, nearly all `exit_recompile`. `convert_key` runs 2.3 times per key written.
* Dash, Trash and Coercion (`probes/profile_others.rb`, hashie's own benchmark shapes): `Dash.new` 4 objects, reads
  and writes 0, `Trash.new` 4, coerced 7, nested coercion 16. Nothing to take. `IndifferentAccess.new` of the nested
  fixture: 252 objects, of which 63 Strings and 6 Classes come from `inject!` including the module into each nested
  hash's singleton class, which runs `included` (and its `alias_method "regular_#{m}"` loop) once per nested hash
  (held, below).

## Ranking by reach × gain

| # | Idea | Reach | Gain | State |
|---|---|---|---|---|
| 1 | HM4: skip the conflict check when a subclass disabled warnings | omniauth, elasticsearch-model, zendesk_api now; restforce and chef-zero once they allow hashie 6 | quiet `Mash.new` CPU 0.46 (YJIT) and 0.66 (ZJIT) in Duel; `[]=`, `dup`, `merge` alike locally; plain Mash 1.01 | **held after review**: a quiet subclass built in a non-main Ractor raises, and an overridden `disabled_warnings` reader is ignored; no measured form is exact ([below](#hm4-skip-the-conflict-check-when-warnings-are-disabled)) |
| 2 | HM3: `method_missing` without the arguments Array | every Mash, Ruby ≥ 4.0 | 1 object per method-style read; reads CPU 0.91–0.95 in Duel; setters 1.01–1.02 | **held after review**: a forwarded keyword Hash is stored with its keyword flag ([below](#hm3-method_missing-without-the-arguments-array)) |
| 3 | HM5: `to_hash` reads each value once | every `to_hash` and `to_json` | CPU 0.84 (YJIT) and 0.69 (ZJIT) in Duel | unheld 2026-11-28: Thomas accepts the callback case as outside the contract; in review again on `6b6f67b` ([below](#hm5-to_hash-reads-each-value-once)) |
| 4 | `Hash#dup` before `self.class.new(val)` in `convert_value` | every nested hash in `Mash.new` | 101 of 774 objects; time not measured | held: a subclass `initialize` would receive the caller's Hash instead of a copy |
| 5 | Literal suffixes instead of `end_with?(*ALLOWED_SUFFIXES)` | every key written, every suffixed call | helper alone 113 → 61 ns under YJIT, 134 → 121 ns interpreted (`out/suffix-micro.txt`) | held: the win is how JITs compile a splat call, and it duplicates the constant; ZJIT lead |
| 6 | `initialize` → `deep_update`'s splat Array | every Mash | 131 of 774 objects | held: `deep_update` is public and subclasses call or override it; no exact form found |
| 7 | Method object per nested value in `_flexibly_convert_to_hash` | every nested `to_hash` | 101 of 292 objects | held: the arity check is what makes OmniAuth's zero-arity `InfoHash#to_hash` work, and a per-class cache would miss singleton methods |
| 8 | `convert_key`: return a String key before `respond_to?(:to_sym)` | every String key | interpreter about −4 to −6% on `Mash.new` (screening); YJIT and ZJIT inside the screening spread | held: no JIT gain, and a String subclass with its own `to_s` would no longer be converted |
| 9 | `Mash#fetch(key, ...)` instead of `*args` | `fetch` calls | 1 object per call without a default, interpreter only; YJIT 0.11 → 0.15 µs slower (screening) | held: slower under YJIT |
| 10 | IndifferentAccess: one singleton class per nested hash | IndifferentAccess users; none among the largest dependents | 69 of 252 objects on the fixture | held: low reach, and the per-hash include is the documented `inject!` behaviour |
| 11 | Dash, Trash, Coercion, Clash, Rash | not used by the largest dependents | 0–16 objects per call already | nothing found |

`out/held-quick.txt` holds the screening runs for 8 and 9; `probes/held-*.patch` the prototypes.

## HM3: `method_missing` without the arguments Array

**Held, not exact (2026-11-27).** Astra and thermos-sol both returned "changes" on `282ebcb` (their sections below):
an optional parameter receives a keyword-flagged Hash as it is, where the rest Array received an unflagged copy. A
value set through `SimpleDelegator` (Ruby 3.3 and later), or through a subclass whose `ruby2_keywords`
`method_missing` calls `super` (3.2 and later), is then splatted as keywords by a later `receive(*[value])`. The
differential below never looked at that flag. `probes/mm_anonymous_rest.rb` (`out/mm-anonymous-rest.txt`) repeats
their repro on 4.0.10 and master: master `[[{a: 13}], {}]`, HM3 `[[], {a: 13}]`. The same probe shows the form that
would be exact: keep an anonymous rest and read `[*].first` in the setter (the repro matches master; 5 reads allocate
2 objects instead of 7; 5 setters allocate 5 more, 44 against 39). But `[*]` is Ruby 3.2 syntax and hashie supports
3.0 (`ruby -c` on 3.0.7 fails), so it is not built and not reviewed. Reopen when hashie requires Ruby 3.2. Both
reviewers also found the impact too broad (snaky_hash 2.0.9 and restforce 8.0.1 exclude hashie 6; DefineAccessors
reads don't reach `method_missing`) and the body silent on the ZJIT-on-master losses recorded below. Nothing was
opened or posted. The record below is as it stood before review.

Branch `thomasklemm/method-missing-rest`, head `282ebcb` on `9e313f3`:
`def method_missing(method_name, value = nil, *, &blk)`, and the setter passes `value`. Since Ruby 4.0
(`43683e1e9d`, "Avoid allocation for anonymous positional splat with no arguments", in `v4.0.0`) an anonymous rest
parameter allocates nothing when the call passes no arguments. Round 1 left `*args` because `...` cannot name the
setter's argument and a fixed arity rejects extra arguments; an optional argument followed by an anonymous rest
keeps both, which round 1's probes did not cover. The body says so, since it supersedes point 4 of the reply on
hashie/hashie#659.

| | interp 4.0.10 | YJIT 4.0.10 | ZJIT 4.0 (Duel) | ZJIT master |
|---|---|---|---|---|
| Objects, 5 reads as methods | 5 → 0 | 5 → 0 | 5 → 0 | 5 → 0 |
| Duel CPU, read keys as methods | | 0.953 [0.949, 0.956] same | 0.937 [0.925, 0.946] faster | |
| Duel CPU, Symbol-given keys | | 0.914 [0.912, 0.917] faster | 0.912 [0.908, 0.921] faster | |
| Duel CPU, KeepOriginalKeys Symbol / String | | 0.949 / 0.949 same | 0.937 faster / 0.970 same | |
| Duel CPU, suffixed reads (16 → 12 objects) | | 0.983 same | 0.990 same | |
| Duel CPU, write new keys / overwrite | | 1.018 / 1.012 same | 1.022 / 1.008 same | |
| Callgrind, 5 reads (`body/HM3`) | −1.3% (A/A 0.17%) | −2.6% (A/A 0.09%) | | |
| Wall, 5 reads | | −3.5% [−4.2, −3.2], A/A −0.2% | | −3.9% [−4.4, −3.5], A/A −0.1% |
| Wall, `auth.info.email, auth.uid` | | −4.1% [−4.8, −2.3] | | −5.5% [−6.0, −4.4] |
| Wall, `mash.description = value` | | (with `private?`: −0.5% [−0.9, −0.2]) | | **+2.5% [+2.2, +2.7]**, A/A −0.4% [−0.8, +1.0] |
| Wall, `mash.name(1)` | | | | **+6.7% [+6.5, +6.9]**, A/A +0.2% |

Duel (fork #27, run 46067769275): 27 benchmarks, 0 regressed, 0 unsettled, under YJIT and ZJIT.

**Setters and reads with an argument are slower under ZJIT on master** (`wall/HM3-setter-master-zjit`, 30 rounds,
claimed). A call that passes an argument allocates the same one Array as before (`probes/mm_signatures.rb`,
`out/mm-signatures.txt`: 1 object with either signature) and now also fills the optional parameter. Duel on 4.0 has the two
setter benchmarks 1–2% above master under both JITs, inside its limit. Accepted for review on these grounds: method
reads far outnumber method-style writes on a response object, and `mash.name(1)` has no caller we know of. The
body states the setter cost. On Ruby 3.4.7 objects are unchanged and screening times stay inside the two base
runs' spread (`out/HM3-ruby-3.4.7-quick.txt`, no A/A).

Exactness: `probes/mm_diff.rb`: 19 Mash flavours (extensions, `super` in four spellings, `ruby2_keywords`, a
prepended module, a singleton method, a default proc, a subclass recording `assign_property`'s argument) × 3 seeds ×
frozen and unfrozen × 18 names × 19 argument shapes (none, nil, false, several, Arrays, Hashes, keywords, `**`,
empty and non-empty splats, blocks, a Mash) × 4 ways to call (`public_send`, `method_missing` directly, `method(n).call`,
a String name). Each row records the result with class and frozenness, the whole mash, which stored values are the
caller's own objects, what `assign_property` received, and the warning log. **155,953 rows identical** between master
and the branch on 4.0.10 (interpreter and YJIT) and on master with ZJIT (`mm/differential.tar.gz`, checksums next
to it). The probe is sensitive: a variant without the anonymous rest differs in 33,760 rows. Checklist: (1)
singleton, prepend and `method_missing` overrides probed; (2) Mash, Array and Hash arguments pass through by
identity; (3) splats and keyword hashes arrive as before, no conversion is added; (4) no call on a user object is
added, `args.first` on our own Array goes; (5) nothing is copied or adopted; (6) no iteration; (7) frozen mashes
give identical errors; (8) no load-order effect. Accepted: `method(:method_missing).parameters` names differ
(`arity` stays −2). Suite: 4.0.10 `rake spec` 1,077/0 (two added expectations for extra arguments), rubocop 156
files clean, `docs:examples` 359/0; 3.0.7 1,073/0; 3.4.7 1,077/0.

Out loud: `method_missing` takes the method name, an optional value and any further arguments, which it ignores;
a stored key is read, a setter assigns the value, and the other suffixes act as before. RuboCop metrics for
`method_missing` (limits set to 0 to print them): ABC 12.25 → 11.36, cyclomatic 6 → 6, perceived 4 → 4. L0.

## HM5: `to_hash` reads each value once

**Unheld (2026-11-28).** Thomas accepts as outside the contract that a value changed by a callback during `to_hash`
is converted as it was read; the case stays out of the PR body. Head `6b6f67b` and the body are unchanged and went
back to both reviewers with that case pre-accepted.

**Held after review, needs Thomas (2026-11-27).** Astra and thermos-sol both returned "changes" on `6b6f67b` (their
sections at the end). Between master's two reads of a value, user code can run: the value's `is_a?`, and, for an
Array, the output key's `hash`. If that code replaces or deletes the entry, master converts what the second read
finds and the branch converts what it read. `probes/to_hash_reentrant.rb` (`out/to-hash-reentrant.txt`) repeats two
of their repros on 4.0.10 and master: a value whose `is_a?` replaces its entry gives `{x: 29}` on master and
`{x: {old: 13}}` on the branch; a key whose `hash` clears the receiver raises NoMethodError on master and returns
`[[13]]` on the branch. A fiber or thread that replaces the entry while `to_hash` is suspended shows the same. No
`[]` override is needed, so the body's one stated difference doesn't cover it, and the differential below never
changed the receiver during the conversion. No dependent was found doing this; ordinary inputs agree in the
reviewers' 33,000 and 35,280 independent rows per side. The only exact fix restores the two reads, and with them the
cost. It is checklist item 6 (mutation during conversion), so it opens only if Thomas accepts reading each value
once as outside the contract, and then the body says that a value changed by a callback during `to_hash` is
converted as it was read. Both also asked to narrow the reach: IndifferentAccess, Dash and Trash have their own
`to_hash` and don't gain (the item's impact now says so). Nothing was opened or posted.

thermos-sol's slowest input, one key holding a `Hashie::Array` of 131,072 Integers (+1.25% [+0.80, +1.70] under ZJIT
on master on its 2-CPU orb), repeated here on the 8-CPU orb, 30 rounds each (`to_hash_array_body.rb`,
`wall/HM5-array-*`): ZJIT on master −0.1% [−0.5, +0.3], no claim; YJIT 4.0.10 **+0.6% [+0.4, +0.9]**, A/A +0.1%
[−0.3, +0.3]. So the loss is not confirmed under ZJIT and is 0.6% under YJIT for one huge Array; the cause is not
traced. A Mash with 100 scalar keys is −17.1% [−17.6, −16.7] and −18.3% [−18.5, −17.6]. Neither orb is a1.xxlarge.

Branch `thomasklemm/to-hash-read-once`, head `e10dce0` on `9e313f3`: `value = self[k]` once in
`Hashie::Hash#to_hash` instead of `self[k]` in the `is_a?(Array)` test and again for the conversion. In a Mash
every `self[k]` is `custom_reader`: a default-proc check, `convert_key` and the read.

| | interp 4.0.10 | YJIT 4.0.10 | ZJIT 4.0 (Duel) | ZJIT master |
|---|---|---|---|---|
| Duel CPU, `Mash#to_hash: a nested Mash` | | 0.862 [0.858, 0.866] faster | 0.687 [0.682, 0.694] faster | |
| Callgrind, `Mash#to_hash` of a repository | −27.8% (A/A 0.02%) | −19.0% (A/A 0.28%) | | |
| Callgrind, `to_json` | −26.2% | −15.7% | | |
| Wall, `to_hash` | | −18.5% [−19.0, −18.1] | | −13.6% [−14.4, −12.9] |
| Wall, `to_json` | | −15.0% [−15.4, −14.8] | | −11.3% [−11.7, −11.0] |
| Wall, an auth info hash with its own `to_hash` | | −7.2% [−7.6, −6.7] | | −3.6% [−6.7, −1.9] |

Objects are unchanged (10 in Duel). Duel (fork #29, run 46068675920): 0 regressed under both JITs; YJIT has one
unsettled benchmark that the change doesn't touch (KeepOriginalKeys Symbol reads 1.056 [1.039, 1.065], the
benchmark with the thinnest A/A margin in the calibration). The Duel run measured `39db98d`; `e10dce0` has the same
tree and a corrected commit message.

Exactness: `probes/to_hash_diff.rb`: 13 classes (Hashie::Hash, Mash, a subclass and five extensions, an InfoHash-like subclass
with a zero-arity `to_hash`, IndifferentAccess, a `[]` that copies, Clash, Rash) × 6 value sets (scalars, nested,
objects with `to_hash` of arity 0 and 1 and through `method_missing`, Mash/Dash/Hash values, frozen and subclassed
Arrays, conflicting keys) × 5 option sets × frozen × default / default proc; each row records the result, whether it
is the receiver, the receiver afterwards and `to_json`. **2,340 rows identical** on 4.0.10 and on master with ZJIT
(`to_hash/differential-e10dce0.tar.gz`). The two expected differences are printed by the probe: a subclass's `[]`
is called once per key instead of twice, and a `[]` whose result alternates between calls no longer has its first
result tested and its second converted. A stored key never reaches a default proc (0 calls in both). Suite: 4.0.10
1,076/0, rubocop clean, `docs:examples` 359/0; 3.0.7 1,072/0; 3.4.7 1,076/0.

Out loud: for each key, pick the output key, read the value once, and convert it, element by element when it is an
Array. `to_hash` metrics: ABC 20.15 → 18.84, cyclomatic 8 → 8, perceived 10 → 10. L0.

Rebuilt on master `277e88e` as `6b6f67b` (2026-11-27): the CHANGELOG line conflicted with the two entries merged
since; the code diff and the message are unchanged, the CHANGELOG line is now #662. Duel judged the exact head (fork
#33, run 46077588957): `Mash#to_hash` 0.838 [0.833, 0.842] under YJIT and 0.688 [0.680, 0.694] under ZJIT, 27
benchmarks, 0 regressed, 0 unsettled under both. Rerun on `6b6f67b`: 4.0.10 `rake spec` 1,076/0, rubocop clean,
`docs:examples` 359/0; 3.0.7 1,072/0; 3.4.7 1,076/0; the differential against `277e88e` on 4.0.10, 4.0.10 with YJIT
and master with ZJIT has the same 2,340 identical rows and the same two expected differences
(`to_hash/differential-6b6f67b.tar.gz`). The Callgrind and wall cells above are from `e10dce0` on `9e313f3`; the
`to_hash` code is the same on both bases.

## HM4: skip the conflict check when warnings are disabled

**Held, not exact (2026-11-27).** Astra returned "changes" on `10a9303` (its section at the end);
`probes/quiet_ractor_and_reader.rb` (`out/quiet-ractor-and-reader.txt`) repeats its two blocking repros on 4.0.10 and
master.

1. **Ractor.** `class Quiet < Hashie::Mash; disable_warnings; end; Ractor.new { Quiet.new(fresh: 3).to_hash }` returns
   the Hash on master and raises Ractor::IsolationError on the branch. Asking the class for every key reads
   `@disabled_warnings`, an unshareable Array, from a non-main Ractor; master reads it only for a key that conflicts
   with a method. The module form, the reorder and flag first raise the same way, so **no form measured here is
   exact**, and none can be while the per-key path reads that Array.
2. **Overridden reader.** `def self.disabled_warnings; [:size]; end` on a subclass: master's `disable_warnings?(:size)`
   is true and nothing is logged; the branch's guard reads the instance variables, answers false and logs the
   warning. Removing the guard fixes this and brings back the reorder's 3–5% on every plain Mash.

Astra also showed that the calls listed as accepted below are not only counts: a `respond_to?` or
`respond_to_missing?` with side effects, or a raising `disable_warnings?`, changes what is stored or raised; a frozen
class goes from FrozenError to a stored key; and merely reading `Mash.disabled_warnings` once creates
`@disabled_warnings` and defeats the fast return (plain `Mash.new` up to +12.7% under YJIT in its diagnostic sweep
on a 2-CPU orb). An exact form would have to keep class state out of the per-key path or store it shareable, which
is a design change to `KeyConflictWarning`, not a small performance change. Nothing was opened or posted. The
record below is as it stood before review; its exactness section missed Ractors and reader overrides.

thermos-sol returned "changes" on the same head with the same two blockers, found independently (its section at the
end), and measured the inspected-list state: `Mash.new('ready?' => true)` in a mixed process +10.7% under ZJIT on
master (2-CPU orb, diagnostic). Both reviewers put the next upstream number at 662, not the 663 in the CHANGELOG
line. The fork branches of HM3 and HM4 are deleted; their heads are in `candidates.bundle`.

Branch `thomasklemm/skip-disabled-conflict-check`, head `10a9303` on `277e88e`, two added lines and one removed:
`Mash#_log_collision?` asks `self.class.disable_warnings?(method_key)` before `respond_to?` instead of after it, and
`KeyConflictWarning#disable_warnings?` starts with `return false unless @disable_warnings || @disabled_warnings`, so
that a class that configured nothing answers from two instance variable reads. The commit also adds the Duel
benchmark "disable_warnings: Mash.new from a nested JSON response". This is the shared check, so `Mash.new`, `[]=`,
`merge`, `dup`, `update` and `replace` gain alike, in every subclass that disabled warnings.

| | interp 4.0.10 | YJIT 4.0.10 | ZJIT 4.0 (Duel) | ZJIT master |
|---|---|---|---|---|
| Duel CPU, `disable_warnings`: Mash.new nested | | 0.458 [0.456, 0.460] faster | 0.655 [0.650, 0.662] faster | |
| Duel CPU, Mash.new: a nested JSON response | | 1.007 [1.003, 1.009] same | 1.006 [1.000, 1.012] same | |
| Duel CPU, Mash.new: a flat Hash | | 1.008 [1.006, 1.011] same | 1.005 [0.998, 1.011] same | |
| Duel CPU, Mash: write new keys as methods | | 1.013 [1.010, 1.016] same | 1.013 [1.009, 1.017] same | |
| Duel CPU, Mash: overwrite a key as a method | | 0.981 [0.977, 0.984] same | 0.952 [0.949, 0.955] same | |
| Duel CPU, Mash#deep_merge: a nested update | | 1.000 [0.997, 1.003] same | 0.998 [0.992, 1.003] same | |
| Callgrind, quiet.new(repository) (`body/HM4`) | −32.6% (A/A 0.04%) | −48.1% (A/A 0.23%) | | |
| Callgrind, quiet merge / quiet `[]=` | −32.3% / −42.7% | −47.8% / −53.3% | | |
| Callgrind, plain Mash.new(repository), quiet subclass ran first | **+3.1%** (A/A 0.04%) | +1.1% (A/A 0.09%) | | |
| Wall, quiet.new(repository) / auth hash | | −51.7% [−51.8, −50.6] / −47.0% [−47.6, −46.7] | | −55.6% [−55.8, −54.7] / −49.0% [−49.2, −48.6] |
| Wall, quiet merge / quiet `[]=` | | −51.0% [−51.4, −50.4] / −66.2% [−66.3, −65.9] | | −54.5% [−55.2, −53.2] / −66.1% [−66.4, −65.9] |
| Wall, plain Mash.new(repository), quiet subclass ran first | | +2.3% [+1.9, +4.3], A/A +0.4% [−0.1, +0.7] | | **+9.1% [+7.4, +9.8]**, A/A +0.2% [−1.2, +2.6] |
| Wall, plain Mash.new(repository), plain only | | +1.5% [+0.9, +1.8], A/A −0.3% [−1.3, +0.4] | | +2.5% [+0.2, +3.4], A/A −0.1% [−1.1, +1.2] |
| Wall, plain Mash#merge / `mash['description'] =`, plain only | | +1.0% [+0.2, +1.5] / −3.6% [−4.1, −2.7] | | −0.2% (no claim, A/A excludes 0) / −4.7% [−4.9, −4.3] |

Duel (fork #36, run 46079366956, the exact head): 28 benchmarks, 0 regressed under both JITs. Under YJIT one
benchmark is unsettled, "KeepOriginalKeys: read Symbol keys as methods" 1.038 [1.017, 1.055]; it writes no key, and
it was unsettled the same way in a run that only changed `to_hash` (46068675920, 1.056 [1.039, 1.065]). Objects are
unchanged (11 for the quiet subclass, 25 for plain Mash). Local wall cohorts are `wall/HM4-10a9303-*` and
`body/HM4`.

**Cost: a Mash that disables nothing asks its class once per key written.** On master it asked only for a key that
conflicts with a method. Duel has plain `Mash.new` at 1.005–1.008 and new keys written as methods at 1.013, each
"same". Locally, a process that builds only plain Mashes has `Mash.new(repository)` at +1.5% [+0.9, +1.8] under
YJIT 4.0.10 and +2.5% [+0.2, +3.4] under ZJIT on master, `Mash#merge` at +1.0% under YJIT, and overwriting an existing
key 3.6% and 4.7% faster (not traced; master's `disable_warnings?` read the list and assigned `@disable_warnings`
on every call, which the early return skips). Interpreted, plain
`Mash.new(repository)` runs 3.1% more instructions (Callgrind, A/A 0.04%): the extra class-method call per key.

**Under ZJIT on master the cost is larger when one process builds both kinds of Mash.** `wall/HM4-10a9303-master-zjit` (30 rounds): plain `Mash.new(repository)` +9.1% [+7.4, +9.8] in a process where the
quiet subclass ran the same methods first, against +2.5% alone. ZJIT on 4.0.10 in the same mixed process (`wall/HM4-10a9303-4.0.10-zjit`, 20 rounds): −2.6% [−3.7, +0.1],
no claim (the interval includes 0, and 4.0.10's ZJIT has no side-exit counter for the JIT-flat gate); its quiet
cases are −49 to −69%. So the mixed-process cost shows on master's ZJIT only.
`probes/zjit_mixed.rb` (`out/zjit-mixed-order.txt`, measured on the module form and the flag-first form): after a
quiet subclass ran first, `send_polymorphic_fallback` per plain `Mash.new` goes from 20 to 114. The call
`self.class.disable_warnings?` in the shared method then has two receiver classes, `Hashie::Mash` and the subclass,
and ZJIT sends dynamically although both resolve to the same method. Every form measured pays this (below); the
body says so in one sentence without a number, because the number is local.

### Three other forms, measured and refused

| Form | Quiet `Mash.new` in Duel (YJIT / ZJIT) | Plain `Mash.new` nested in Duel | Plain, local | Why not |
|---|---|---|---|---|
| Module included by `disable_warnings` without keys, overriding `_log_collision?` (`f41c3b2`, `probes/held-conflict-check-module.patch`; run 46071221821) | 0.433 / 0.639 | 0.996 / 0.996 | YJIT 4.0.10, quiet subclass ran first: **+19.0% [+18.2, +19.6]** wall, +20.4% instructions (`body/HM4-module-f41c3b2`); plain only +0.1% (no claim); ZJIT master mixed +8.4% [+7.3, +9.2], plain first +5.8% [+4.6, +7.1] | plain Mash pays 19% under YJIT once a quiet subclass was built first, which Duel's one-benchmark processes don't show; and it is a one-caller fast path beside the shared check |
| Reorder only: ask the class before `respond_to?`, `disable_warnings?` unchanged apart from `\|\|` (`probes/held-conflict-check-reorder.patch`; run 46077591328) | 0.417 / 0.645 | 1.027 [1.020, 1.033] / 1.046 [1.042, 1.051] unsettled; flat Hash 1.043 unsettled / 1.033; new keys 1.035 / 1.028 | YJIT mixed +4.8% [+4.2, +5.7]; ZJIT master mixed +11.1% [+10.1, +11.9], plain only +6.3% [+4.5, +7.6] | 3–5% on every plain Mash, 3 unsettled benchmarks in Duel |
| Flag first: `return false unless @disable_warnings`, then the list, else `true` (`0ded81e`, `probes/alt-flag-first-reorder.patch`; run 46077594232) | 0.450 / 0.638 | 1.010 / 1.013 | YJIT mixed +1.4% [+1.1, +1.7], plain only +2.0% [+1.7, +2.3]; ZJIT master mixed +9.7% [+8.8, +10.2], plain only +3.5% without a claim (measured as a patch on `9e313f3`) | not exact: a class that fills the Array `disabled_warnings` returns without calling `disable_warnings` warned again (1,146 of 66,994 differential rows, `quiet/flag-first-0ded81e-diffs.tar.gz`) |

The head keeps the flag-first cost and stays exact for that class: calling `disabled_warnings` sets
`@disabled_warnings`, so such a class takes the old path.

**YJIT lead, also on unmodified master.** `probes/yjit_first.rb` (`out/yjit-first.txt`, screening without A/A): when
a Mash class with its own `_log_collision?` builds a Mash before the first plain Mash is built, plain `Mash.new`
of the fixture takes 81 µs instead of 68 µs under YJIT 4.0.10, and 85–91 µs instead of 71 µs under YJIT on master.
`PermissiveRespondTo`, which ships such an override, does it on master `9e313f3` and on the final head (85 µs
against 69 µs). An override that only calls `super`, an overridden `custom_writer`, an empty subclass and a plain
quiet subclass don't. It does not happen when plain Mash is compiled first, in the interpreter, or under ZJIT.
In the slow process Callgrind has `respond_to?` reached from the interpreter loop (`vm_call_cfunc_with_frame_`,
`vm_exec_core`) where the fast process stays in JIT code (`body/HM4-module-f41c3b2`, raw.tar.gz); the cause in YJIT
is not found. Not ours to fix in hashie; lead for the coordinator.

### Exactness

`probes/quiet_diff.rb`: 31 classes (Mash, subclasses that disable all, some or no warnings, by Symbol and String,
children that inherit or narrow, a class that disables twice in either order, a class with its own
`disable_warnings?`, a class that fills `disabled_warnings` directly, a class disabled after instances exist, quiet
classes with each Mash extension, with their own methods, and Restforce- and OmniAuth-like classes) × 3 seeds × 30
keys (Strings, Symbols, suffixed names, numbers, nil, an Array, objects with `to_sym`, names of Mash's own private
methods) × 12 operations (`[]=`, a setter, `update`, `merge` with and without a block, `dup`, `replace`,
`assign_property`, `new`, `shallow_update`, `reverse_merge`, a bang reader) × frozen and unfrozen. Each row records
the result and its class, the mash afterwards, and the warnings logged during construction and during the
operation. **66,994 rows; 66,976 identical** against `277e88e` on 4.0.10, 4.0.10 with YJIT and master with ZJIT
(`quiet/differential-10a9303.tar.gz`). The 18 that differ are one case: the key `"respond_to?"` on a quiet subclass
with `MethodAccessWithOverride`. There the stored key shadows `respond_to?` with a reader that takes no argument;
master then raises ArgumentError from the conflict check on the next write, and the branch, which no longer calls
`respond_to?` for that class, stores the key. Not in the body: it is a failure that goes away for one key name.

Accepted, printed by the probe as `accepted` lines: (1) for a key whose warning is disabled, `respond_to?` and with
it `respond_to_missing?` are no longer called by a write (a subclass counting them sees fewer calls); (2) a class
that disabled nothing has `disable_warnings?` called once more per key, 5 instead of 4 for three keys; (3) the query
no longer assigns `@disable_warnings` or creates `@disabled_warnings` on a class that configured nothing, so
`instance_variables` stays empty and a frozen class answers false where master raised FrozenError. Checklist: (1)
overrides of `disable_warnings?`, `_log_collision?` (PermissiveRespondTo) and `respond_to_missing?` probed; (2)
nothing is stored or returned differently; (3) no conversion added, `method_key` reaches the class as before; (4)
the calls on user objects that go are (1) above, none is added; (5) nothing copied; (6) no iteration; (7) frozen
mashes give identical errors; (8) a class disabled after its instances exist behaves as on master ("late").

Suite on `10a9303`: 4.0.10 `rake spec` 1,076/0, rubocop 156 files clean, `docs:examples` 359/0; 3.0.7 1,072/0; 3.4.7
1,076/0. No spec added: the existing ones cover every warning case, and the new benchmark guards the cost.

Out loud: a key can only collide if it is a String or Symbol; if the class disabled its warning there is nothing to
log; otherwise look for a method of that name as before. A class that never disabled anything says so at once.
RuboCop metrics: `_log_collision?` ABC 14.46 → 13.64, cyclomatic 8 → 8, perceived 8 → 8; `disable_warnings?` ABC 5.1
→ 6.48, cyclomatic 4 → 6, perceived 4 → 6. L0.

Risky (`risky: true`): the conflict check runs on every Mash write, and the change touches what every plain Mash
pays.

## Astra: changes on 282ebcbb8248ae3ef379bc7254ad69fd0422d7b4

2026-11-27, [review thread](https://ampcode.com/threads/T-01a21f08-d80b-7106-a4dc-d66f07191d10).
Reviewed here without delegation. Verified the remote branch, clean checkout, exact parent
`9e313f308f3270995c2c978e92f0f216b861861b` and one-commit range. The reviewed item text and complete commit diff,
scripts, raw outputs, build logs, source/API responses and reproduction instructions are in
[astra-HM3-282ebcb.tar.gz](astra-HM3-282ebcb.tar.gz). No fork push or upstream post was made.

### Must fix: forwarded keyword hashes change meaning

On Ruby 3.2.10, 3.3.10, 3.4.7, 4.0.10 (interpreter and YJIT), and Ruby master
`0d399335b733776187e43a783e5f950c18ad881c` with ZJIT, a `ruby2_keywords` forwarding subclass exposes this difference:

```ruby
require 'hashie'
class ForwardingMash < Hashie::Mash
  ruby2_keywords def method_missing(*args, &block)
    super
  end
end
def consume(*args, **kwargs)
  [args, kwargs]
end
value = ForwardingMash.new.public_send(:payload=, a: 1)
p consume(*[value])
```

Base: `[[{a: 1}], {}]`. Head: `[[], {a: 1}]`. Ruby 3.0.7 and 3.1.7 give the same result on both
trees (the keyword form), so this is not a claim of breakage on those versions. `forwarding_repro.rb` and its
per-version outputs retain the exact runs. This is observable public return behavior, not just reflection or
an override of a private helper. A caller forwarding the returned value to a method that distinguishes positional
arguments from keywords can hit it; no specific dependent in the reach table is claimed to do so.

There is also a plain-Mash version on 3.3.10 onward, including master/ZJIT (`keyword_repro.rb`):

```ruby
require 'hashie'
require 'delegate'
class Payload < Hash; end
def consume(*args, **kwargs)
  [args, kwargs]
end
mash = Hashie::Mash.new
SimpleDelegator.new(mash).public_send(:payload=, **Payload[a: 1])
p consume(*[mash.payload])
```

It produces the same base/head difference, without overriding Mash. Hashie explicitly preserves custom Hash
subclasses. The archive also demonstrates the flag reaching the public `assign_property` override through
`SimpleDelegator` with an ordinary Hash; forwarding that value changes positional/keyword dispatch too.
This is a real supported delegation/subclass boundary, though the exact call shape is uncommon.

The cause is visible in Ruby master's `vm_args.c`, lines 924–947: optional parameters are filled before the rest
parameter, and the `ruby2_keywords` marker is cleared only on the rest Array's last Hash. Moving the first value
out of that Array bypasses that clearing. The previous probe formats hashes as key/value pairs and does not
observe the marker, so its identical output does not establish equivalence here.

The smallest certainly safe correction is restoring `*args` and `args.first`; that loses this optimization.
An optimization-preserving alternative needs a new exactness pass that preserves keyword declassification,
identity and extra-argument behavior on all supported Rubies. Do not add an unconditional Hash copy or a
keyword parameter as an untested fix: positional hashes and forwarded keyword hashes are not interchangeable.
The candidate itself was not edited.

### Text findings and claim audit

* **Must fix the omission of the master/ZJIT tradeoff.** The body accurately attributes its final sentence to Duel,
  but mentions only the 4.0 setter result. The note says the local losses are stated in the body; they are not.
  The retained `wall/HM3-setter-master-zjit/results.json` and table report setter +2.456% [2.156%, 2.687%] and
  argument-bearing read +6.7% [6.5%, 6.9%], with passing A/A intervals containing zero, 30 rounds and flat JIT
  counters. These are different from a result inside noise. Add a short qualitative sentence about slower setters
  and argument-bearing reads on Ruby master/ZJIT; do not turn the old 8-CPU measurements into newly approved
  publication-quality numbers. The bounded setter tradeoff could be accepted for a read-oriented optimization
  after disclosure; it is not an automatic rejection of the idea. The keyword behavior difference independently
  blocks this exact head. No evidence here establishes the frequency of reads versus writes in all consumers.
* **Must qualify `impact`.** Released snaky_hash 2.0.9 (and therefore current oauth2) and restforce 8.0.1 exclude
  Hashie 6, so they are not current eligible beneficiaries of a new Hashie-6 change. snaky_hash's default branch
  permits `< 7`, unreleased; restforce's still says `< 6.0`. Also, “every method-style read on every Mash” is false:
  warmed DefineAccessors readers allocate zero on both trees and bypass this method. Say “reads dispatched through
  `Mash#method_missing`,” and separate eligible consumers from those waiting for dependency updates.
* **Optional wording correction for the earlier reply.** Opened
  [the actual comment](https://github.com/hashie/hashie/pull/659#issuecomment-7227673119) through the GitHub API.
  It says “I left `method_missing`'s `*args` too: the setter needs the argument, and a fixed arity would reject the
  extra arguments it accepts today.” It does not say every alternative must retain `*args`. The body addresses
  the right earlier decision, but “revisits the `*args` left unchanged in #659” is more exact and less defensive
  than “replaces what I wrote … had to stay.”

Sentence-by-sentence checks of the title, body, commit message and CHANGELOG:

| Claim | Command/source checked and conclusion |
| --- | --- |
| Title and CHANGELOG: no arguments Array on method reads, Ruby 4.0 in the CHANGELOG | Exact diff and base/head/base `allocations.rb` runs support the saving on 4.0.10 and master. The body supplies the title's version boundary. The anticipated CHANGELOG link 662 returned 404; it is a reservation, not an existing PR, and must match the actual number before opening. |
| Old `*args` allocates, only the setter consumes an argument | Read the complete method at base and head, and ran `allocations.rb`. No other branch reads `args`. A chained `owner.login` performs two missing-method calls, not one; “each dispatch” would avoid implying one Array for that whole expression. |
| The new optional-value/anonymous-rest signature; older Rubies still allocate | `git show` and executions on 3.0.7, 3.1.7, 3.2.10, 3.3.10, 3.4.7, 4.0.10 and master. Read Ruby commit `43683e1e9d` via its API and the actual `v4.0.0/vm_args.c`, which contains the anonymous-empty-rest optimization. |
| Setter takes the first value; extras accepted and ignored | Both existing and new differential probes, including multiple values, nil, false, keyword hashes, splats, blocks and frozen receivers. Ordinary values agree; this does not excuse the keyword-marker regression above. |
| Four Duel allocation rows, 5 → 0 three times and 16 → 12 | Extracted and read both raw logs from run 46067769275, not just summaries. Repeated those four fixture shapes in `duel_objects.rb`, base/head/base, 4.0.10 interpreter/YJIT and master/ZJIT: deltas are exactly −5, −5, −5, −4 objects. The first raw slope has a shared −0.001 startup residual, documented in the archive. |
| Duel Symbol-given reads “faster”, CPU 0.91 in both JITs | Raw logs report 0.914 [0.912, 0.917] YJIT and 0.912 [0.908, 0.921] ZJIT, both `faster`. Checked the wrapper commits: candidate 522b899 and base f6545d1 have byte-identical `lib`, `spec` and `benchmarks` trees to this head/base respectively. This verifies a report of Duel's result, not a newly measured speed claim. |
| Setters keep the Array; Duel 1–2% slower within its limit | Allocation probes confirm the Array remains for calls with an argument. Raw Duel rows are 1.018/1.012 YJIT and 1.022/1.008 ZJIT, all `same`. Read `.duel.rb` and Duel 0.3.1's `Stats.decide`: the CPU-specific limit is 1.05; the log header's generic 1.02 is not that override. `same` means under the threshold, not equal speed. |
| Commit message: reads and `?`, `!`, `_` stop allocating that arguments Array; older Rubies unchanged | Tested every shape in `allocations.rb` with repeated-base controls. One object saved per dispatch on 4.0/master, none on 3.0–3.4. Other suffix work still allocates, and missing-method dispatch with explicit arguments retains its rest Array. Also ran the supplied `mm_signatures.rb` across all release pins and master/ZJIT; direct calls can be optimized differently from missing-method dispatch. No added code-comment line needs removal. |

No factual sentence in those four text surfaces was left unchecked. The missing tradeoff, overbroad impact and
inexact earlier-reply paraphrase are recorded rather than silently corrected.

### Reach and currency, checked on 2026-11-27

Live RubyGems metadata and GitHub repository responses are in `sources/`; `reach.sh` reproduces the requests.
Downloaded and inspected each latest released gem's actual Mash consumer. `current-sources.sh` also resolves the
default branch to a full SHA and reads its gemspec. All repositories below are unarchived. Direct dependents are
listed by total gem downloads, not stars; downloads are not unique installations or proof of this call frequency.

| Project | Stars | Gem downloads | Latest release/date | Last push | Current eligibility |
| --- | ---: | ---: | --- | --- | --- |
| omniauth | 8,102 | 235,361,860 | 2.4.2 / 2026-11-18 | 2026-11-27 | KeyStore/AuthHash derive from Mash; allows Hashie 6 |
| snaky_hash | 19 | 140,364,316 | 2.0.9 / 2026-10-25 | 2026-11-27 | StringKeyed/SymbolKeyed derive from Mash; release excludes 6, default-branch relaxation unreleased |
| slack-ruby-client | 1,259 | 96,263,564 | 3.4.0 / 2026-11-24 | 2026-11-24 | Messages::Message derives from Mash; allows 6 |
| elasticsearch-model (elasticsearch-rails repo) | 3,079 | 78,459,520 | 8.0.1 / 2025-09-01 | 2025-10-08 | HashWrapper derives from Mash; allows 6; older activity, not shown to be abandoned |
| restforce | 822 | 60,005,180 | 8.0.1 / 2025-12-29 | 2026-07-27 | Mash subclass, but release and default branch exclude 6 |
| zendesk_api | 410 | 47,179,059 | 3.1.2 / 2026-07-23 | 2026-11-17 | SilentMash derives from Mash; allows 6 |
| faraday-mashify | 4 | 26,806,907 | 1.0.3 / 2026-08-23 | 2026-11-07 | Default response wrapper is Mash; allows 6; downloads support relevance despite few stars |

Also checked every contextual project: oauth2 has 2,179 stars, 288,611,398 downloads, release 2.1.0 on 2026-10-25,
last push 2026-11-27; it depends on snaky_hash, so its reach is indirect and not added to that gem's counts.
Hashie has 3,035 stars and 507,055,651 downloads, release 6.0.0 on 2026-11-11, last push 2026-11-27.
Duel has 21 stars and 8,745 downloads, release 0.3.1 on 2026-11-22, last push 2026-11-25; it remains relevant as
Hashie's adopted benchmark tool, not as evidence of ecosystem reach. Ruby has 23,868 stars, last push
2026-11-27; gem download counts do not apply to the language runtime. Of currently eligible direct consumers,
the order is omniauth, slack-ruby-client, elasticsearch-model, zendesk_api, faraday-mashify. Prefer a few of these
to an unqualified long list; none of their older gem versions was substituted for the latest release.

### Executed coverage and limits

* Reran `probes/mm_diff.rb` unchanged on all six release Rubies above, on 4.0.10/YJIT and master/ZJIT: every
  base/head output pair is byte-identical. Older versions have different multiline error formatting; they were
  compared only within the same pin. This successful control is retained alongside the failing new probe.
* `adversarial.rb` runs 30,576 cases plus one reflection row per cell. It covers all seven requested extensions,
  implicit and explicit `super`, `...`, `ruby2_keywords`, prepends, SimpleDelegator, Forwardable, dynamic Method
  and Proc calls, UnboundMethod binding/bind_call, super_method, custom Hash/Array/String values, public/private
  duck conversions and blocks, frozen receivers, and ordinary/empty/flagged/mixed keyword and positional inputs.
  The existing probe adds singleton methods, default procs, warning capture and identity observations. Only the
  demonstrated keyword-marker changes and the already-accepted `parameters` reflection change survived;
  `arity` remains −2. Changed behavior rows: 0 on 3.0/3.1, 360 on 3.2, 525 on 3.3, 465 on 3.4, and 400 in each
  4.0/master cell. Raw rows, not just normalized comparisons, are kept.
* Exactness checklist: exercised 1–3 (overrides/subclasses/conversions), 4–5 (argument behavior, with the flag
  regression explicitly blocking), 7 (frozen errors) and 8 (fresh processes plus standalone `require 'hashie/mash'`).
  No iteration, cache, loading hook or new user callback is added, so checklist 6 introduces no new traversal or
  suspension point; no concurrency or reloading stress test is claimed.
* Ruby 4.0.10 official commands: `bundle exec rake spec` gives base 1,076/0 and head 1,077/0;
  `bundle exec rake rubocop` inspects 156 files without offenses; `bundle exec rake docs:examples` gives 359/0.
  Initial incomplete-bundle failures were reproduced on base and repaired by installing the full bundle, not
  by changing tests. Other Ruby versions ran the differential probes, not the full suite. Release Ruby ZJIT was
  not built; its Duel logs were inspected, while our ZJIT execution used the pinned master build.
* Cold read: read an existing key, otherwise dispatch its suffix, and pass the first value only to assignment.
  L0 structurally. Measured Flog 17.7 → 16.6, ABC 12.25 → 11.36, cyclomatic 6 → 6, perceived 4 → 4,
  method length 14 → 14. The smaller metrics do not establish argument-binding equivalence.
* Worst-input search: `worst.rb` includes zero/one/two/keyword/direct reads, a setter, and prepared splats of
  0, 1, 2, 20, 1,000 and 131,072 arguments (1 MiB backing array). The largest relative slowdown in the five-round
  screening was the ordinary existing-key read with one ignored argument, `mash.name(1)`, not the huge splat.
  Screening alone claims nothing. A separate 30-round base/head/base confirmation, with 30 GC-off windows per
  process, one pinned core and JIT-flat checks, is kept as `worst-confirm/` in the archive. This is a bounded
  input search, not a universal worst-case proof. This orb has 8 CPUs, not the required a1.xxlarge, so none of
  its new diagnostic timings is approved for a body or promoted to a publication-quality timing claim.
  The confirmation passes A/A and all 90 processes' JIT-flat checks: the one-argument reader's change interval
  excludes zero on the slower side, the zero-argument reader's on the faster side. The simple two-key fixture's
  setter interval contains zero; this does not negate the older, different fixture's setter regression. Exact
  diagnostic estimates, intervals, windows and commands remain in `worst-confirm/results.json` and `table.md`.

## thermos-sol: changes on 282ebcbb8248ae3ef379bc7254ad69fd0422d7b4

2026-11-27, orb `T-01a21f08-d041-7016-b829-aa1e0ed68eaf`. Reviewed the single commit against
`9e313f308f3270995c2c978e92f0f216b861861b`, including the exact HM3 title/body, commit message and CHANGELOG.
Applied both Thermos correctness/security and maintainability rubrics directly in this thread, without delegating,
as requested. **Changes required:** a demonstrated keyword-forwarding regression, overbroad allocation claims,
and omitted master/ZJIT losses. No upstream writes or fork pushes.

Scripts, raw outputs, source/API evidence and the validated rollback patch:
[`thermos-sol-HM3-282ebcb.tar.gz`](thermos-sol-HM3-282ebcb.tar.gz). Paths below are inside that archive;
`RUNS.md` gives commands and limitations. The reviewed branch still resolved to the full head above.

### R1 — P2: the optional value lets a keyword-marked Hash escape as keywords

`lib/hashie/mash.rb:500,506`: moving the first argument out of the named rest changes Ruby's handling of
`ruby2_keywords` forwarding. This affects public dispatch and return values, not only reflection or a private hook.
Minimal repro, run separately with `ruby -I BASE/lib repro.rb` and `ruby -I HEAD/lib repro.rb`:

```ruby
require 'hashie'
require 'delegate'
def receive(*positional, **keywords); [positional, keywords]; end
value = SimpleDelegator.new(Hashie::Mash.new).public_send(:item=, a: 13)
p receive(*[value])
```

Base: `[[{a: 13}], {}]`. Head: `[[], {a: 13}]`. The returned Hash has become keyword arguments when splatted.
This introduced difference reproduces on Ruby 3.3.10, 3.4.7, 4.0.10, and pinned master, with every tested JIT mode.
A public `assign_property(name, value)` override calling `receive(*[value])` sees the same difference before storing.
No override is needed for the return-value repro above.

A subclass with an ordinary legacy forwarding override also reproduces, starting on Ruby 3.2.10:

```ruby
class LegacyKeywordMash < Hashie::Mash
  ruby2_keywords def method_missing(name, *args, &block)
    super
  end
end
value = LegacyKeywordMash.new.public_send(:item=, a: 13)
p receive(*[value])
```

The same base/head outputs differ on 3.2.10–4.0.10 and master. On 3.0.7/3.1.7 the legacy example already returns
keywords on base too, so that is not an introduced regression there. The SimpleDelegator example is unchanged
through 3.2.10. Complete three-case/version/JIT outputs: `evidence/keyword-repro-all.txt`.

Mechanism checked in master `0d399335b733776187e43a783e5f950c18ad881c`, `vm_args.c`: optional arguments are
assigned before rest-argument cleanup; the latter removes `RHASH_PASS_AS_KEYWORDS` only from a final Hash still
in the rest. The new optional slot has already consumed it (`evidence/ruby-vm-argument-path.txt`).

**Smallest validated correction:** restore `(method_name, *args, &blk)` and `args.first`. The two-line
`restore-named-rest.patch` is in the archive. It gives exactly base's entire `lib` tree, fixes the focused repro on
3.2/3.3/4.0/master, and passes 1,077 specs and RuboCop (156 files) on 4.0.10. It sacrifices this optimization.
No guard, keyword-copy workaround or alternative optimized signature is claimed safe. Do not apply only a
keyword-flag test to Hashie: fixing Ruby's argument handling is a separate possible investigation, not a validated fix.

### R2 — P2: narrow the allocation promise to the call shapes measured

The title, commit subject/body and CHANGELOG suggest method reads generally lose the Array; HM3's impact explicitly
says "Every method-style read on every Mash". `allocations.rb`, run base/head/base on each Ruby/JIT configuration,
demonstrates these boundaries on 4.0.10 and master:

| Public call shape | Base objects/call | Head objects/call |
| --- | ---: | ---: |
| ordinary `mash.name` | 1 | 0 |
| `mash.name(*EMPTY)` with a frozen empty Array | 1 | 1 |
| a subclass's `def method_missing(name, *args, &block); super; end`, then `mash.name` | 2 | 2 |
| a subclass's `def method_missing(...); super; end`, then `mash.name` | 1 | 0 |
| `mash.name(13)` | 1 | 1 |

These are allocation counts, not timings. Direct-read output has an equal 0.0001/call instrumentation cost on both
sides; the displayed integers remove that equal overhead. Base/head/base controls agree. Ruby 3.0–3.4 show no
allocation change. `evidence/allocations-all.txt` retains every raw count. An empty argument list is not sufficient
to promise no allocation when the call arrives as a splat. Narrow the prose to ordinary unsplatted reads and do not
promise all subclass forwarding shapes. `mash.owner.login` also contains two affected reads, not one call.

### R3 — P2: the body does not disclose the known larger master/ZJIT losses

The last body sentence accurately describes Duel's 4.0.10 setter medians, but it is not a fair account of the known
costs across pins. HM3's note says the local losses are "stated in the body"; they are not. Checked the existing
`wall/HM3-setter-master-zjit/results.json` against all 90 archived process logs, including every case's windows,
A/A and flat-JIT flags (`evidence/historical-wall-audit.txt`: 360 case/process arrays match):

| Existing master/ZJIT cohort, 30 rounds | Change, 95% interval | A/A, 95% interval |
| --- | --- | --- |
| setter | +2.456% [+2.156, +2.687] | −0.441% [−0.832, +1.001] |
| `mash.name(1)` | +6.724% [+6.462, +6.932] | +0.160% [−0.198, +0.382] |

They meet the statistical claimed-loss gate, not the "noise" exception. The VM now fills an optional argument while
these shapes retain their Array; that is a checked path difference, not an isolated attribution of all the CPU cost.
An allocation win for plain reads can justify that tradeoff, but there is no measured application read/write or
forwarding mix here proving a net time win. Require a concise disclosure and an explained/accepted tradeoff before
approval, rather than clearing it with Duel's different pin or 5% limit. These losses do not alone prove that the
optimization must be abandoned; R1 independently blocks the exact head. Cut the body rather than lengthening its
roughly 200 words beyond the PR-description guidance.

**Independent worst-input measurement:** `perf_body.rb`, `script/upstream-bench --wall 30 --wall-mode zjit
--wall-windows 5 --wall-ms 10 --warmup 10000 --core 4 --modes ''`, same base/head, pinned master
`0d399335b733776187e43a783e5f950c18ad881c`; 90 fresh processes, GC off, every measured window JIT-flat.
Among the 14 tested call shapes the largest median relative loss is an **empty-splat read**, not a setter:

| New diagnostic cohort | Change, 95% interval | A/A, 95% interval |
| --- | --- | --- |
| `mash.name(*empty)` | +5.9% [+5.6, +6.2] | +0.1% [−0.5, +0.5] |
| `mash.name(1)` | +5.8% [+5.5, +6.2] | +0.1% [−0.2, +0.7] |
| named-rest subclass, no-argument read | +2.7% [+2.3, +3.0] | +0.3% [−0.4, +1.2] |
| setter, one value | +1.7% [+1.1, +2.0] | −0.0% [−0.3, +0.5] |
| ordinary unsplatted read | −7.3% [−7.8, −7.1] | +0.0% [−0.4, +0.4] |

The slowest absolute case was the two-argument setter (`public_send(:name=, 'Grace', 29)`), about 0.62 µs/call,
versus 0.61 µs base; its relative loss is +2.0% [+1.5, +2.2], A/A +0.4% [−0.2, +2.0]. All 14 rows, individual
windows, flags, generated commands and results are under `evidence/worst-master-zjit`. This is a measured sweep,
not a universal worst-case bound. The preliminary screen is kept and not used for claims.

**Host limitation:** this orb has 8 CPUs, not the mandated a1.xxlarge publication host. The existing local timing
record also declares 8 CPUs. These are diagnostic/statistically resolving cohorts, not publication-approved timing
numbers; do not move the new percentages into an upstream body. No timing was delegated to another orb because
this review was expressly confined to this thread. Allocation and correctness conclusions do not depend on timing.

### Independent exactness and validation coverage

`public_diff.rb` is a new probe, not a rerun of `probes/mm_diff.rb`: 197,602 observable rows per side per configuration,
19 classes including Mash, bare/explicit/keyword/legacy/`...`/optional `super`, prepends, assignment/read observers,
nine Mash extensions and BlockAccess. It covers absent/present/exact-suffix keys, frozen receivers, default procs,
nil/false/scalars, Hash/Array/String subclasses, public/private conversions, marked/mixed/empty keywords, splats,
blocks, public dispatch/direct calls/Method objects/String names/SimpleDelegator; it records results, errors,
mutation, identity and hook events. Two fiber cases suspend at lookup, mutate the receiver and optionally freeze it.

Ran 3.0.7 interpreter; 3.1.7, 3.2.10, 3.3.10, 3.4.7 and 4.0.10 interpreter/YJIT; master interpreter/YJIT/ZJIT.
Normalized only checkout paths and object addresses. No differences through 3.2 in the broad probe; 80 rows per
configuration from 3.3 onward expose R1 through the assignment observer. The focused public return-value repro adds
the 3.2 legacy-super boundary the broad snapshots missed. `edge_diff.rb` adds 54 cases per release and master/ZJIT
for singleton methods, per-object prepends/extend, frozen conversion results, method-name conversion mutation/errors,
and missing required arguments; no additional semantic differences. Fresh-process load-order checks agree.

Checklist: (1) singleton/private/extend/prepend/dispatch checked; (2) container subclasses and overridden conversion/
iteration hooks checked; (3) implicit conversions and hook counts checked; (4) no added call on a supplied value,
`args.first` on the VM-created Array goes, but VM keyword processing changes (R1); (5) no new accumulator/adoption;
(6) mutation and fiber boundary checked, no iteration changed; (7) frozen receivers/values and error class/message
checked; (8) load order checked. Reflection changes as expected: arity stays −2, parameters change from required name,
rest `args`, block `blk` to required name, optional `value`, anonymous rest, block `blk`. Accepted metadata difference,
not a second correctness finding. No new shared state, configuration, dependencies or security boundary.

On 4.0.10, independently ran base specs **1,076/0**, head specs **1,077/0**, head documentation examples **359/0**,
and project RuboCop **156 files clean**. The two changed examples pass individually and both fail with a deliberately
wrong fixed-arity control. The broader fixed-arity control has 41,568 differing rows among 197,600 completed rows,
then raises at the first unrescued fiber: that negative-control run is not reported as a completed full probe.
No claim of full gem-suite execution on every Ruby/JIT; compatibility conclusions are scoped to the probes run.

### Maintainability, added comments and specifications

Cold read of both versions: an exact key wins even when its spelling ends in a suffix, so it forwards the block to
`[]`; otherwise split the suffix, assign the first value (nil if absent) for `=`, booleanize the read for `?`, create
and store a nested Mash only when absent for `!`, return a temporary nested Mash when absent for `_`, and otherwise
perform an ordinary read. Every dispatch branch is unchanged; the correctness difference is at argument binding.

**L0 structurally:** one signature and one expression change, no helper, branch, wrapper or duplication. `mash.rb`
stays 654 lines; no file crosses 1,000 lines because of this change. No unrelated restructuring would improve these
two lines. Per-method measurements, flog 4.10.0 and RuboCop 1.91.0 with metric limits set to zero:

| `method_missing` metric | Base | Head |
| --- | ---: | ---: |
| flog | 17.7 | 16.6 |
| ABC | 12.25 | 11.36 |
| cyclomatic | 6 | 6 |
| perceived | 4 | 4 |
| method length | 14 | 14 |
| parameter count | 2 | 3 |

The parameter metric rises because the optional value is now named; the control flow does not grow. Lower scores
do not excuse R1. There are **zero added comment lines**, including specs; pre-existing comments shown in diff
context are not additions. Both added expectations check public behavior with asymmetric values: extra arguments
do not change an existing-key read, and a multi-argument setter uses 123 rather than 456. They fail the plausible
mistake of removing the rest altogether; keep them. They do not cover keyword forwarding, so add a public R1
regression test if an optimized replacement is attempted. No superfluous comments or implementation-only tests found.

### Sentence-by-sentence claim audit

| Posted text | Check performed and result |
| --- | --- |
| Title: "Read Mash keys as methods without allocating an arguments Array" | Diff and independent base/head/base allocation probe confirm ordinary unsplatted reads on 4.0+, not every call shape; R2. Title also omits the Ruby boundary present in the CHANGELOG. |
| Body 1: `*args` collects an Array on every call; only the setter reads an argument | Opened both `method_missing` bodies, the callers/extensions and allocation outputs. True for the method's normal calls; there is no other `args` use. This does not mean its argument-array allocation is the only allocation of a setter or suffix call. |
| Body 2: `mash.name`, `mash.owner.login`, `mash.private?` allocate an empty Array | Source and ordinary-read allocation probe plus Duel's read/suffix cases support an Array per dispatched read on base. The chained example contains two reads; simplify the sentence rather than imply one total Array for the chain. |
| Body 3: names the setter value and leaves the rest anonymous, with the printed signature | Exact `git diff` confirms both changed lines. |
| Body 4: since Ruby 4.0 anonymous rest allocates nothing for a no-argument call; older Rubies allocate as before | Opened Ruby optimization commit `43683e1e9d8f7f6ed3fb4a48598190a0993f8f66`, verified it is an ancestor of v4.0.0 (`553f1675f3a9cece340b90f374a4245dccac2272`), and ran allocation controls on all pins. True for ordinary calls, false for empty-splat/named-rest-super generalization; R2. |
| Body 5: replaces the earlier reply on 659; optional plus anonymous rest still accepts setter and extra arguments | Fetched `issuecomment-7227673119`: point 4 did retain `*args` over fixed-arity rejection. Ran extra-argument public probes and both added specs. Acceptance is true, but preserved keyword behavior is not; R1. |
| Body allocation-table introduction and all four rows | Opened the exact Duel benchmark source and extracted run 46067769275 logs: method reads 5→0, Symbol method reads 5→0, KeepOriginalKeys Symbol reads 5→0, suffixes 16→12 under both JITs. Raw Ruby description is 4.0.10, so "Ruby 4.0" is accurate. |
| Body: Duel calls Symbol reads faster under both JITs, CPU 0.91 of master | Raw medians 0.914 [0.912, 0.917] YJIT and 0.912 [0.908, 0.921] ZJIT; both labeled faster. 0.91 is honest rounding. Allocation counts are not being mislabeled time. |
| Body: setters retain the Array, Duel 1–2% slower, within limit | VM/signature allocation probe and raw two-setter medians: 1.018/1.012 YJIT, 1.022/1.008 ZJIT, all "same". Opened exact workflow/config and Duel limit implementation: actual CPU limit 1.05, despite the output's generic 1.02 header. Literally supported, but omits the different master losses; R3. |
| Commit subject: "Stop allocating an arguments Array in Mash#method_missing" | Same boundary issue as title, and setters still allocate; scope it to ordinary reads on Ruby 4.0+ (R2). |
| Commit sentence 1: named rest allocates on every call and only setter reads an argument | Source and base allocation probe support it, with the same scope as body 1. |
| Commit sentence 2: optional value plus anonymous rest; since 4.0 empty rest avoids allocation, including `?`, `!`, `_` | Signature, Ruby source/ancestry, ordinary-read controls and actual Duel suffix benchmark support the ordinary calls; not splatted/forwarded calls (R2). |
| Commit sentence 3: extra arguments remain accepted/ignored and older Rubies allocate as before | Public shape matrix and old-version allocation controls support argument acceptance and allocation. Ignoring extras does not establish keyword equivalence; R1. |
| CHANGELOG: Ruby 4.0 method reads avoid an arguments Array, attribution and link 662 | Code/allocation audit gives the R2 boundary. Commit author and committer are Thomas Klemm, no trailers. GET of upstream PR 662 returned 404: it is a prospective number, not a verified reference. Recheck/replace on opening; do not treat it as an existing PR. |

**Duel provenance:** run API and raw checkout logs identify workflow-carrying head
`522b8997366f6b1304f38e6cb008bf945b9a17fd`, test merge `4b48c95270f0e242a21283e062fb2254c4b00ff5`,
and base `f6545d1dd34c3905fb4c8fa25764f209cb65274f`. Compared `lib`, `spec`, `benchmarks`, `.duel.rb` tree/blob
hashes, not just a branch name: head/merge match reviewed head for all four; workflow base matches reviewed master.
The extra branch changes are workflow, spelling, CHANGELOG and CONTRIBUTING, not runtime/spec/benchmark changes.
All 27 benchmarks report 0 regressed, 0 errors, 0 unsettled under each JIT. Opened calibration-8's kept A/A and
planted-regression logs/config too; do not confuse its controls or the other candidates' logs with this run.

After the independent audit, read fork PR 27's conversation, inline comments and reviews (empty), and searched for
an upstream PR for this candidate (none found). No external reviewer finding was imported. No public claim remains
silently unchecked: unsupported scope is R2, missing material context is R3, and the unassigned CHANGELOG number
is an explicit pre-opening check. This pass does not authorize opening or bless a replacement head.

## Astra HM5: changes on 6b6f67b39c4f839154209f4d94ceadb416f82ddb

2026-11-27, [review thread](https://ampcode.com/threads/T-01a21f3c-2ef1-726e-be84-05ebf5389576). Reviewed here without delegation. Verified the fork branch's full head, its sole parent `277e88e6ccc317497e6c20fb8b9e35abebc0fe19`, the complete diff, commit message, and exact HM5 title/body. No upstream write or fork push. Scripts, raw outputs, API responses and reproduction commands are in [`astra-HM5-6b6f67b.tar.gz`](astra-HM5-6b6f67b.tar.gz); paths below refer to that archive.

### R1: read-once changes results beyond the disclosed subclass read count

**Changes required under the requested identical-results contract.** A value's public `is_a?` can replace or delete its entry between base's two reads. Head converts the earlier object instead. This does not require overriding `[]`, changing a private Hashie hook, or globally redefining a core method. Minimal reproduction (`minimal.rb`, run separately with each checkout's `-I lib`):

```ruby
require 'hashie'
h = Hashie::Hash.new
v = Object.new
v.define_singleton_method(:is_a?) { |type| h[:x] = 29; super(type) }
v.define_singleton_method(:to_hash) { { old: 13 } }
h[:x] = v
p h.to_hash
```

Base returns `{x: 29}`; head returns `{x: {old: 13}}`. The receiver ends with `x: 29` on both. `edges.rb` also demonstrates this on plain Mash, with String keys, and through `to_json`. An Array-valued variant replaces the entry with an Integer: base raises `NoMethodError` on `each`, whereas head succeeds with the old Array's contents. These are observable results and exceptions, not merely different callback counts.

`repros.rb` contains two other minimized forms of the same boundary:

* A value's `is_a?(Hashie::Array)` deletes its entry from a Hashie::Hash whose default proc returns 29. Base returns `{x: 29}`; head returns `{x: {old: 13}}`. Thus the previous probe's “stored keys never reach the default proc” observation applies only while the key remains stored.
* A copying reader, `def [](key); super.dup; end`, returns a value whose `is_a?(Hashie::Array)` sets `@tested = true` and whose `to_hash` returns `{tested: !!@tested}`. Base converts a second, untouched copy and returns `false`; head converts the tested copy and returns `true`. The original probe's copying-reader case uses values that cannot expose this state/identity difference.

The mutation boundary is not confined to `is_a?`. In the Array branch, writing the output key can run its public `hash` before base's second input read. `key-callback.rb` uses a stable hash value and no reader or value override:

```ruby
require 'hashie'
h = Hashie::Hash.new
key = Object.new
calls = 0
key.define_singleton_method(:hash) do
  calls += 1
  h.clear if calls == 3
  7
end
h[key] = Hashie::Array[13]
p h.to_hash.values
```

Base raises `NoMethodError` for `nil.each`; head returns `[[13]]`. The script catches the exception only to print it. This key's hash value remains stable; the behavioral difference is its mutation of the input hash during output insertion.

**Caller relevance:** these are supported public Ruby extension points and real mutable receivers, not a demonstrated bug in OmniAuth. A lazy/proxy value or stateful key can execute such callbacks; no current named dependent was found doing this. A shared Hashie::Hash or Mash can also be replaced while conversion is suspended: `edges.rb` deterministically pauses a value's type test with a Fiber, and separately with two Queues and a Thread, replaces the entry, then resumes. Base returns the replacement and head the earlier object. Those tests establish the changed interleaving, not a guarantee of atomic serialization on either version. Frozen-receiver mutation errors and freezing without replacement agree.

**Smallest certainly exact correction:** restore the original two `self[k]` reads and remove `value`; the tested parent supplies that behavior. It sacrifices this optimization. Preserving the optimization instead requires accepting and describing a broader read-once/snapshot behavior change, including callbacks and concurrent replacement, not only a subclass's read count. The body accurately describes reading once but does not document these extra result/exception differences. No speculative guard or upstream correction was applied.

### Independent probes, ordinary callers and maintainability

Ran Ruby 3.0.7, 3.1.7, 3.2.10, 3.3.10, 3.4.7 and 4.0.10 interpreters, 4.0.10/YJIT, and built Ruby master `0d399335b733776187e43a783e5f950c18ad881c` with ZJIT. R1 reproduces across all eight cells; comparisons are always within one Ruby pin.

* Reran the existing `to_hash_diff.rb`: its 2,340 matrix rows agree on every completed cell, with only its two already-declared alternating-reader/read-count differences. The default-proc control remains zero. It does not exercise the public callback mutation boundary above, record the first-read object's state, or observe container keyword flags, identity relationships and frozenness comprehensively.
* New `adversarial.rb`: **33,000 rows per side per cell, zero differences**. It covers 22 receiver classes, including Hashie::Hash, Mash, subclasses, public/private/prepended readers, six Mash extensions and MethodAccessWithOverride, Dash, Trash, populated Clash/Rash, IndifferentAccess, and the actual released OmniAuth AuthHash/InfoHash. Values include plain/Hashie/subclassed/frozen Arrays, nested Hash/Mash/Dash/Trash, Strings with subclass/encoding metadata, marked keyword Hashes, and `to_hash` of arity zero, one, optional, two, keyword-only, private and method-missing forms. Five option sets include both key-conversion flags together; frozen/unfrozen, default-proc and identity-hash modes exercise both `to_hash` and `to_json`.
* Snapshots record result/source/receiver graph identity, container frozenness, Hash keyword flags, identity-comparison mode and user-conversion events. The broad probe has 7,810 matching error rows and 25,190 successful rows per cell; it is not merely a rejection test. A deliberately wrong control that drops key-conversion options changes **4,392 rows** on 4.0.10. Raw rows are retained, not just hashes of them.
* `edges.rb`: **128 rows per side**, 24 result/exception differences, all on Hashie::Hash/Mash and all explained by R1. It includes singleton and prepended public type tests, private-method errors, replacement/deletion, Array values, freezing, fibers, threads and JSON. Dash/Trash and IndifferentAccess override `to_hash`; direct conversions do not traverse the changed method. Clash/Rash are also controls rather than evidence of affected reach. Four fresh-process require orders agree.
* Exactness checklist: (1–3) singleton/private/prepend hooks, subclassed containers and arity-sensitive conversions exercised; (4) the skipped second read is R1, and no new call is added to a supplied value; (5) new local retention exposes first-versus-second-copy state, as demonstrated; (6) mutation, fibers and threads differ as above; (7) frozen/error cases exercised; (8) fresh require-order checks agree. No unrelated keyword-flag regression was found.
* Independently ran Ruby 4.0.10 `bundle exec rake spec` on both trees: **1,076 examples, zero failures each**. Head `rake rubocop`: **156 files, no offenses**; head `rake docs:examples`: **359 examples, zero failures**. This is not a claim that the complete suite ran on every Ruby.
* **L0:** for each input key, choose its output spelling, read once, then convert the value or each Hashie::Array element. No new helper, guard, configuration, dependency or comment. The unqualified `Array` inside this method resolves to `Hashie::Array` under normal `require 'hashie'`; a plain Array is not automatically walked here. `flog` 24.4 → 21.5; ABC 20.15 → 18.84; cyclomatic 8 → 8; perceived 10 → 10; method length 20 → 21. The added local explains the extra line; lower complexity does not establish temporal equivalence.

### Every upstream sentence checked

| Text surface and claim | Executed check and conclusion |
| --- | --- |
| Title: read each value once in Hashie::Hash#to_hash | Read the exact diff; existing read-count probe reports two → one per stored key. Correct for this traversal. |
| Body sentence 1: two `self[k]` reads, type test then conversion | Read both full method bodies and ran the counted-reader probe. Correct; the type constant normally resolves to Hashie::Array. |
| Body sentence 2: Mash reads convert keys/check default proc; to_json calls to_hash | Read `Mash#custom_reader`, its `[]` alias, `convert_key`, and `Hashie::Hash#to_json`; exercised actual Mash/OmniAuth and JSON in both probes. Correct for the inherited path. |
| Body sentences 3–4: read once/convert that value; subclass sees one read instead of two | Exact diff and counted/copying-reader executions confirm this. The literal statements are true, but they do not make the extra result differences in R1 acceptable under the requested contract. |
| Duel introduction and CPU table: nested Mash, Ruby 4.0, relative to master, YJIT 0.84/ZJIT 0.69 | Opened run 46077588957 and closed fork PR 33 via `gh api`; extracted/read the original two logs. Both say Ruby 4.0.10. Rows are 0.838 [0.833, 0.842] and 0.688 [0.680, 0.694], both `faster`, so rounding is correct. Checkout merge `a52a15e2b6dddaeae2626e561cb82ed8893a9898` has the reviewed head and parent, and its entire tree equals the reviewed head's tree. |
| Body last sentence: allocations unchanged | Both raw Duel rows say 10. Independently reran its actual JSON fixture through the allocation worker, base/head/base on 4.0.10 and master/ZJIT: 10/10/10. This is true for the named benchmark; arbitrary allocating `[]` overrides can save objects, as the copying-reader control shows. |
| Commit subject and every sentence | `git show --format=fuller` plus the same source/read-count checks: the message repeats the mechanism above, without a time or universal-equivalence claim. No unchecked sentence remains. |
| CHANGELOG: read once, Thomas attribution, link 662 | Diff/read-count checks support the description; actual author and committer are Thomas Klemm. Upstream's latest visible issue/PR is 661, and GET of 662 returns 404, so **662 is still the next visible number**, not an existing or reserved PR. Recheck at opening. |

Both Duel logs also confirm the impact metadata's 27 benchmarks, zero regressed, zero errors and zero unsettled. The older local Callgrind/wall records use `e10dce0` against `9e313f3`, as the HM5 section says; their method blobs were inspected, but their historical timing numbers were not rerun or promoted as new exact-head evidence. No new upstream PR for this candidate was found.

### Relevance and currency, checked live on 2026-11-27

| Project | Stars | RubyGems downloads | Latest release | Last push | Relevance |
| --- | ---: | ---: | --- | --- | --- |
| OmniAuth | 8,102 | 235,361,860 | 2.4.2, 2026-11-18 | 2026-11-27 | The only named downstream consumer; released requirement `hashie >= 3.5.2` permits 6. AuthHash/InfoHash inherit Mash, and InfoHash's zero-arity `to_hash` calls `super`. |
| Hashie | 3,035 | 507,055,651 | 6.0.0, 2026-11-11 | 2026-11-27 | Target library; requires Ruby >= 3.0. |
| Duel | 21 | 8,764 | 0.3.1, 2026-11-22 | 2026-11-25 | The target's adopted benchmark tool, not a downstream reach claim. |
| Ruby | 23,868 | N/A | Not a gem | 2026-11-27 | Runtime named in the benchmark attribution, not a downstream reach claim. |

All four repositories are unarchived. Downloaded OmniAuth's latest released gem, resolved its annotated tag to `2045f32693592360488c833b1505658dceddcd03`, and compared the actual released [InfoHash#to_hash lines](https://github.com/omniauth/omniauth/blob/2045f32693592360488c833b1505658dceddcd03/lib/omniauth/auth_hash.rb#L64-L68) byte-for-byte with the gem. Also fetched the current default-branch gemspec: it still permits Hashie 6. “235M” is supported rounding, not unique installations or proof of serialization frequency. With only one named downstream, reach ordering is already correct. “Every Mash serialized again” describes users of this inherited traversal, not subclasses replacing `to_hash` entirely.

### Worst-input measurement and limits

`worst.rb`/`screen.sh` ran a bounded 31-case sweep, five base/head/base rounds each on 4.0.10 interpreter/YJIT and pinned master/ZJIT, with GC-off CPU-time windows on core 1. The largest relative candidate costs among affected methods were the **empty copying-reader subclass** in interpreter/YJIT and **`Hashie::Hash[x: 13].to_hash`** on master/ZJIT. The slowest absolute case was the **100-key Mash** in every mode; its candidate/base ratios were below one. Unchanged Dash and IndifferentAccess conversions were controls, not credited as gains or regressions. Complete samples, A/A ratios and rankings are in `outputs/screen-*` and `outputs/analysis.txt`; the screening has no JIT-flat/significance claim.

`confirm.sh` then measured those two input shapes with distinct call sites and a scalar Mash control using `script/upstream-bench --wall 30 --wall-windows 5 --wall-ms 10 --warmup 10000`, again pinned to core 1, separately on 4.0.10/YJIT and master/ZJIT. Each cohort has 90 fresh processes, a repeated-base control, passing A/A intervals, and unchanged JIT counters in every measured window. **Neither selected slowdown reproduced in the isolated confirmation.** The single-scalar Hash and Mash were faster in both; the empty subclass was within noise on master/ZJIT and had a very small faster-side interval on YJIT. This does not prove that every mixed-profile workload is free of a regression: the broad screen shares call sites, while confirmation isolates the selected shapes. Exact estimates, confidence intervals and all commands are retained in `confirm-yjit/` and `confirm-zjit/`.

**Host limitation:** this orb has two CPUs, not the required a1.xxlarge timing host. These new measurements are diagnostic only, not publication-approved timing evidence; no new percentage from them belongs in the upstream body. No separate measurement thread was created. The audit of the body's reported Duel ratios stands on its retained exact-head logs; the changes verdict stands on demonstrated result/exception differences, not on a speculative slowdown.

## thermos-sol HM5: changes on 6b6f67b39c4f839154209f4d94ceadb416f82ddb

2026-11-27, orb `T-01a21f3c-226a-77d4-8978-cd852e1e46ae`. Loaded Thermos and both correctness/security and maintainability rubrics and applied them here, without other threads or subagents, as requested. Verified the fork branch and its one-commit parent `277e88e6ccc317497e6c20fb8b9e35abebc0fe19`; reviewed the entire diff, HM5 title/body/impact, commit message and CHANGELOG entry. No Hashie source edit, fork push or upstream post was made.

**Verdict: changes under the requested strict equivalence contract.** Ordinary stored values agree in the new differential. Reentrant public callbacks can nevertheless change results without overriding `[]`; accepting only a subclass's reduced read count is not a complete compatibility boundary. This is not a demonstrated failure in OmniAuth or an identified security vulnerability. The coordinator can instead explicitly accept and disclose the broader boundary. The implementation itself is L0 and structurally sound.

Scripts, raw outputs and source/API evidence are in [`thermos-sol-HM5-6b6f67b.tar.gz`](thermos-sol-HM5-6b6f67b.tar.gz). Paths below refer to that archive; `RUNS.md` gives reproduction commands and toolchain/measurement limitations. The candidate was not silently corrected.

### R1 — P2: reentrant callbacks change the returned value, not just a subclass's read count

At `lib/hashie/hash.rb:41–49`, base looks up the value again after its first result's public `is_a?` callback. Head retains the first result. Minimal repro, run with `ruby -I BASE/lib repro.rb` and `ruby -I HEAD/lib repro.rb`:

```ruby
require 'hashie'
h = Hashie::Hash.new
v = Object.new
v.define_singleton_method(:is_a?) do |type|
  h[:item] = :replacement if type == Hashie::Array
  super(type)
end
h[:item] = v
p h.to_hash[:item].equal?(v)
```

Base prints `false` (the output value is `:replacement`); head prints `true` (the original object). Neither the hash nor its class overrides `[]`. A `Hashie::Array` value replacing itself with `[29]` during the same type check serializes `[29]` on base and its original `[17]` on head, including through `to_json`. Deleting itself instead changes base's `NoMethodError` into a successful conversion on head. Frozen mutation failures agree. A fiber suspended at the type check and resumed after deleting or replacing the entry shows the same distinction. `repros.rb`, `edge_diff.rb` and their per-version outputs retain these runs.

There is also a core Hash-key callback version, without any value-method override:

```ruby
require 'hashie'
h = Hashie::Hash.new(:fallback)
n = 0
k = Object.new
k.define_singleton_method(:hash) { h.clear if (n += 1) == 3; 13 }
h[k] = :stored
p h.to_hash.values
```

Base: `[:fallback]`; head: `[:stored]`. The key returns a stable integer hash; its callback deletes the receiver during lookup/output insertion. `repros.rb` uses an explicitly armed counter to keep setup separate. These are reachable public custom-value/key boundaries, not global core redefinitions or private-helper overrides. They require deliberately reentrant callbacks; no named released consumer was found to use them. Ordinary callbacks that do not replace/delete the current entry did not expose an additional result difference.

`more_edges.rb` also demonstrates the same lookup-count consequence when a custom public `each_key` yields an absent key with a stateful default proc: Hashie::Hash returns 2 on base and 1 on head; Mash returns 4 and 2 because each missing-key read invokes its proc through two paths. A copying reader returns its second fresh object on base and its first on head. The latter is the already acknowledged custom-reader boundary, made observable by identity rather than printed contents; it is not a separate defect.

**Smallest strict correction:** restore the original two `self[k]` expressions in the conversion branches and remove `value = self[k]`, i.e. revert the runtime hunk. That loses this optimization and gives exactly the already-tested base implementation. No speculative type/owner guard is proposed. If read-once snapshot semantics are acceptable instead, explicitly accept that callbacks or mutation between the old lookups can change results even without a `[]` override, and describe that boundary rather than asserting universal equivalence. That is a contract decision, not a proven optimization-preserving fix.

### R2 — P3: qualify the reach, not the valid OmniAuth example

`impact` says “every Mash that is serialized again”. A supported mixin can bypass this helper entirely:

```ruby
klass = Class.new(Hashie::Mash) { include Hashie::Extensions::IndifferentAccess }
h = klass.new(item: 17)
p h.method(:to_hash).owner # Hashie::Extensions::IndifferentAccess
```

Counting `[]` across `h.to_hash` and `h.to_json` gives zero on both trees (`evidence/indifferent-mash-reach.txt`); that module exports with `each_pair`. Dash/Trash use their own `to_hash` alias, Clash inherits core Hash conversion, and Rash delegates to its backing hash. They are compatibility controls, not additional beneficiaries. Say “serializations through Hashie::Hash#to_hash, including Mash and OmniAuth's subclasses” instead of promising every Mash/API response. No project needs to be removed from the concrete reach example.

Live GitHub/RubyGems checks on 2026-11-27 (`sources/omniauth-*.json`) found OmniAuth unarchived, **8,102 stars**, **235,361,860 total gem downloads**, latest **2.4.2**, released **2026-11-18**, last repository push **2026-11-27**. Its released dependency is `hashie >= 3.5.2`, so Hashie 6 is allowed; the current default-branch gemspec agrees. The 235M rounded figure is supported, not a unique-installation or serialization-frequency estimate. OmniAuth is the only consumer project named in HM5's impact.

Downloaded the actual 2.4.2 gem and compared `auth_hash.rb` byte-for-byte with its release commit `2045f32693592360488c833b1505658dceddcd03`: [KeyStore derives from Mash](https://github.com/omniauth/omniauth/blob/2045f32693592360488c833b1505658dceddcd03/lib/omniauth/key_store.rb#L5), [AuthHash derives from KeyStore](https://github.com/omniauth/omniauth/blob/2045f32693592360488c833b1505658dceddcd03/lib/omniauth/auth_hash.rb#L8), and [InfoHash#to_hash calls super](https://github.com/omniauth/omniauth/blob/2045f32693592360488c833b1505658dceddcd03/lib/omniauth/auth_hash.rb#L64-L68). Executed released AuthHash/InfoHash conversion and JSON examples against both Hashie trees; values and calculated names match (`evidence/omniauth-2.4.2.txt`). Its continued eligibility and real call path are verified, not just its dependency declaration.

### Sentence-by-sentence upstream text audit

| Text | Executed check and conclusion |
| --- | --- |
| Title and CHANGELOG: read each value once in Hashie::Hash#to_hash | Exact diff, method owners, original counted-read probe and new identity probe support one lookup instead of two on this helper's normal per-key path. No added code-comment line exists. |
| Body sentence 1 and commit sentence 1: two `self[k]` reads, type test then conversion | Read both complete method bodies and ran the supplied differential. Lexically `Array` here is `Hashie::Array` after `require 'hashie'`; behavior for core Arrays is unchanged. This does not mean all Ruby Arrays are traversed by that branch. |
| Body sentence 2 and commit sentence 2: Mash converts the key and looks for a default proc on each read; to_json calls to_hash | Read `Mash#custom_reader`, `convert_key`, `alias [] custom_reader`, and Hashie::Hash#to_json. Executed both serialization paths, defaults, direct method owners and fresh-process require variants. Supported on this helper's path; R2 qualifies overriding serializers. |
| Body sentence 3 and commit final sentence: read once and convert what was read | Exact runtime diff and independent outputs support this. It is the first lookup's value, including across reentrant mutation; R1 is the resulting strict-contract limitation. |
| Body sentence 4: an overriding subclass's `[]` sees one read per key rather than two | Supplied counting probe and `more_edges.rb` confirm it. Correct, but not an exhaustive list of affected public callbacks; R1. |
| Duel introduction and YJIT 0.84 / ZJIT 0.69 table | Opened run 46077588957's API record and both kept raw logs, not only summaries. Exact head is `6b6f67b`, base `277e88e`, actual Ruby 4.0.10; CPU ratios are 0.838 [0.833, 0.842] and 0.688 [0.680, 0.694], both `faster`. Rounding is correct. Duel 0.3.1's clock implementation measures CPU time, not instructions or allocations. |
| Body: allocations are unchanged | Both Duel logs give 10 for the nested-Mash case. Independent base/head/base allocation measurements on 4.0.10/YJIT give the same 100,001 objects per 10,000 calls, including one shared instrumentation object; JSON likewise agrees at 13 objects/call. This is the measured fixture, not a promise for allocating custom readers. |
| Commit subject and complete message | Same source/read-path checks as the title and first three body rows; no additional factual claim or trailer. Author/committer are Thomas Klemm. No new comment, helper, test or dependency is hidden in the diff. |
| CHANGELOG attribution and prospective 662 link | Checked commit attribution and fetched upstream's current latest issues/PRs: latest visible number 661, no open upstream PR, GET pull/662 is 404, including the final repeat. **662 still appears to be next**, not an existing link or a reservation. These reads cannot rule out deleted numbers or reserve GitHub's counter; recheck/replace on opening. |

No factual sentence in those four upstream text surfaces was left silently unchecked. The body does not assert a universal speedup. Its numeric table reports the demonstrated Duel fixture, not the older Callgrind/wall cohorts. Those older cohorts used `e10dce0` on `9e313f3`; they were inspected as context, not relabeled exact-head runs.

**Duel provenance:** closed fork PR 33 names exactly this head and parent. The checkout log identifies test merge `a52a15e2b6dddaeae2626e561cb82ed8893a9898`. Fetched that object and compared the `lib`, `spec`, `benchmarks` trees and `.duel.rb` blob: test merge matches the reviewed head, unchanged benchmark/spec/config trees match base. Both logs report 27 benchmarks, zero regressed/errors/unsettled. The per-CPU limit is 1.05 in `.duel.rb`, not the generic header's 1.02. After the independent audit, fetched PR 33's conversation, inline comments and reviews (all empty) and current upstream open PRs (none); no external reviewer finding was imported.

### Correctness coverage and probe sensitivity

`public_diff.rb` is an independent **35,280-row** probe per side/configuration: 21 receiver flavors, 28 value shapes, five options, frozen/unfrozen, ordinary/default/default-proc, and `to_hash`/`to_json`. It covers Hashie::Hash, Mash, a named subclass, InfoHash-style override, all nine Mash extensions, Dash, Trash, Clash, Rash, IndifferentAccess, singleton/extended/prepended readers; Hash/Array/String subclasses, Hashie::Array, private/singleton/arity-0/1/optional/rest/two-required/keyword/`method_missing` conversions and frozen conversion results. It records return/error, input after conversion, source identity, classes, frozen state, string bytes/encoding, default/default-proc presence, identity-hash mode and the Ruby keyword flag. Only object addresses and checkout prefixes in diagnostics are normalized; arbitrary Hash metadata is not reduced to printed pairs.

Executed release cells: 3.0.7 interpreter; 3.1.7, 3.2.10, 3.3.10, 3.4.7 interpreter/YJIT; 4.0.10 interpreter/YJIT/ZJIT, plus 4.0.7 interpreter. Built Ruby master `0d399335b733776187e43a783e5f950c18ad881c` and ran interpreter/YJIT/ZJIT too: **all 16 configurations have 35,280 ordinary-input snapshots per side and zero differences.** The two minimal R1 repros also differ on every release pin and master. `edge_diff.rb` adds 49 callback/mutation/fiber/key-collision cases, and `more_edges.rb` adds 30 conversion/metadata/default/identity cases. Their differences are R1 and its acknowledged read-count consequences, not an undiscovered keyword-flag change. The supplied `to_hash_diff.rb` gives its original 2,340 identical matrix rows and the same two expected differing footer rows; its stored-key default-proc footer agrees.

**Negative control for the earlier blind spot:** `flag_control.rb` deliberately marks returned Hashes with Ruby's keyword flag, without editing the candidate. The supplied probe's entire output stays identical to head; the new probe changes **11,700 rows**. Thus the old probe really is blind to that property, while the new one observes it. The candidate itself does not introduce that flag change. This is probe validation, not a candidate finding.

Exactness checklist: (1) singleton/private/extend/prepend/missing-method hooks exercised; (2) container subclasses, Array iteration overrides and colliding output keys exercised; (3) public/private and arity-sensitive conversions, plus their events, exercised; (4) no new user call, but skipped lookups skip public callbacks and change mutation ordering (R1); (5) ordinary source/result identity and conversion-result metadata agree, with first-versus-second fresh lookup identity explicitly recorded; (6) live deletion/replacement and fiber suspension exercised; (7) frozen receivers, containers and results plus error class/message exercised; (8) fresh-process standalone `hashie/hash`, `hashie/mash` and `hashie` loads agree. The no-JSON-require error was also seen on both trees before rerunning the OmniAuth example with `require 'json'`; it is not an introduced bug.

Independently on **Ruby 4.0.10**, `bundle exec rake spec`: base **1,076/0**, head **1,076/0**; `bundle exec rake rubocop`: **156 files, no offenses**; `bundle exec rake docs:examples`: **359/0**. Same head results also passed on 4.0.7. An initial attempt to reuse another Ruby installation's native gems failed dependency loading on base and head; installing the proper 4.0.10 bundle resolved it, without changing source/tests. Other release Rubies ran the differential probes, not their whole suites.

### Maintainability rubric

Cold read: compute the requested output key; obtain one value; iterate a Hashie::Array's elements through the existing conversion helper, otherwise convert the value through that helper; return the new ordinary Hash. The key conditions implement the existing option precedence, and the Array branch preserves the existing element-wise conversion rule. The change belongs in the canonical shared helper, not a Mash-only fast path. No extra wrapper, type/owner guard, branch, duplication, sequential orchestration, mutable shared state, feature gate or new dependency. No coherent simplification would improve these few lines by adding another abstraction. **L0, maintainability approve.**

Measured separately with flog 4.10.0 and RuboCop 1.91.0 (`evidence/flog-{base,head}.txt`, `metrics-*.json`): flog **24.4 → 21.5**, ABC **20.15 → 18.84**, cyclomatic **8 → 8**, perceived **10 → 10**, method length **20 → 21**, parameter count **1 → 1**. The extra line is the named local; branching and indirection do not grow. `hash.rb` is **78 → 79 lines**, so no 1,000-line threshold is crossed. There are zero added comment lines and no added implementation-count test to reject. Lower metrics do not establish semantic equivalence across R1's reentrant boundary.

### Slowest measured input and timing limitation

**Diagnostic only, not approved upstream timing:** this review's orb has two vCPUs, not DECISIONS' required a1.xxlarge. The request prohibited other threads. All new raw samples, including failed gates and preliminary cohorts, are retained; they are not promoted into the body or used as a policy-compliant performance blocker.

The initial twelve-case Ruby 4.0.10/ZJIT screen used five base/head/base rounds; its missing `compiled_side_exit_count` made every timing unclaimable. On master `0d399335b733776187e43a783e5f950c18ad881c`/ZJIT, ran the same twelve cases through `script/upstream-bench --wall 30 --wall-windows 5 --wall-ms 10 --warmup 10000 --core 1`: empty Hashie/Mash, scalar Symbol/String keys, core/Hashie Arrays, 20-key Hashie/Mash, stringify/symbolize and JSON. All measured windows were JIT-flat. No ordinary-case cell claimed a loss; the worst relative point estimate there was empty Mash, −0.05% [−1.13%, +0.95%], A/A −0.18% [−2.14%, +1.57%]. These intervals do not show a slowdown.

Extended the Hashie::Array sweep to 0, 1, 20 and **131,072 elements** (1 MiB of raw references), first three rounds and then a complete **30-round** confirmation, five GC-off windows/process, CPU 1, all six base/head/base2 orders. Used the unchanged harness's wall worker with bounded call counts, and its actual `wall_cell`/bootstrap estimator for analysis (`run-large.sh`, `large_body.rb`, `large_summary.rb`). Every cell remained JIT-flat in 90 processes. The slowest absolute **and** worst relative input in this bounded sweep was:

```ruby
h = Hashie::Hash[item: Hashie::Array.new(131_072, 17)]
h.to_hash
```

Head: **3.621 ms/call**; paired change **+1.25% [ +0.80%, +1.70% ]**; A/A **−0.26% [−0.63%, +0.58%]**. This local cohort does pass the statistical and JIT gates for a small loss; unlike its preliminary three-round result it must not be dismissed as merely inside its confidence interval. **Repeat this row on a1.xxlarge before clearing the performance follow-up.** The orb size prevents treating it as DECISIONS' blocking-loss measurement. No cause or optimization-preserving correction is established, and no speculative large-Array branch is recommended. This is not a universal worst-case proof over arbitrary Ruby callbacks. The candidate's body reports only its nested-Mash fixture, whose Duel claim was verified separately.

## Astra HM4: changes on 10a93033975136664d7b7231986663e9c7689d91

**Changes; do not open this head.** Reviewed independently in `T-01a21f5c-5af9-70ac-9fd0-44b340063d1e`, 2026-11-27. Verified the fork branch's full head, its parent `277e88e6ccc317497e6c20fb8b9e35abebc0fe19`, and its one-commit range. No candidate code was changed or pushed, and nothing was posted upstream. Scripts, raw outputs, public API responses, exact diff and an expanded sentence-by-sentence review are in [astra-HM4-10a9303.tar.gz](astra-HM4-10a9303.tar.gz). The original differential stdout is losslessly nested as `quiet-outputs.tar.xz` to keep this archive below 10 MB.

### R1: ordinary quiet subclasses lose working Ractor writes

```ruby
require 'hashie'
class Quiet < Hashie::Mash
  disable_warnings
end
r = Ractor.new { Quiet.new(fresh: 3).to_hash }
p(r.respond_to?(:value) ? r.value : r.take)
```

Base returns `{"fresh"=>3}`. Head raises `Ractor::IsolationError` accessing the unshareable `@disabled_warnings` class ivar. Catching the exception around `m[:fresh] = 3` confirms that head leaves `{}` while base stores the value. A subclass with `disable_warnings(:size)` also fails for the nonconflicting key `fresh`. Plain `Hashie::Mash` fails after the main Ractor calls its semipublic `disabled_warnings` reader. On Ruby 3.0.7 the regression is broader: **even plain, unconfigured Mash fails**, because that Ruby prohibits these class-ivar reads altogether. Its minimal repro, after preloading, is:

```ruby
require 'hashie/mash'
p Ractor.new { Hashie::Mash.new(fresh: 3).to_hash }.take
```

This is reachable without overrides by applications constructing response objects in worker Ractors. It is not a claim that every Hashie operation was previously Ractor-safe. `ractors.rb` records exceptions and partial state across the Ruby matrix; `minimal-*-ractor-plain-preloaded-3.0.txt` records the plain-Mash repro. The earlier non-preloaded attempt failed on both trees during RubyGems autoload and is retained, not counted as this finding. Untouched plain classes are the passing control on Ruby 3.1 and later.

### R2: the guard ignores an overridden semipublic exclusions reader

```ruby
require 'hashie'
class Selective < Hashie::Mash
  def self.disabled_warnings
    [:size]
  end
end
p Selective.disable_warnings?(:size)
Selective.new(size: 7)
```

Base returns `true` and logs nothing; head returns `false` and logs a conflict warning. Both store 7. This override does not initialize the particular ivars that the new guard reads. Both methods are documented `@api semipublic`, not private/nodoc helpers. A computed/shared configuration provider can hit this; none of the five cited released gems currently uses this override, so this is an extension-contract finding, not a claim about those gems. A singleton-class prepend reproduces it too (`extended.rb`). Removing the new early-return line fixes R2 alone, but leaves R1 and the reorder-only performance cost.

### Accepted differences are not limited to call counts

`adversarial.rb` demonstrates and retains minimal executable cases for each boundary:

* A quiet class's public `respond_to?` override calls `self.class.disable_warnings(:other) if key == :size` before `super`. Base warns on `size` and leaves its warning enabled; head skips that hook, does not warn and leaves it disabled. Observable configuration and warnings differ.
* A quiet `respond_to_missing?` override mutates `payload[:observed] = true if key == :fresh` before `super`; `m[:fresh] = m.payload` stores the extra field on base only. Moving that mutation to a class `disable_warnings?` override instead stores it on head only. A predicate override raising for `:fresh` lets base store 7 but makes head raise and leave `{}`. These are synthetic effectful hooks, not discovered production callers; they disprove the claimed equivalence beyond counts. A Queue-barrier version confirms the added callback can also admit a second thread's mutation before the write. An ordinary eight-thread/independent-Mash control is identical.
* `Class.new(Hashie::Mash).freeze.new`, followed by writing `:size`, raises `FrozenError` and stores nothing on base; head logs and stores 7. Avoiding an unnecessary class mutation is reasonable, but the public exception/storage change needs explicit acceptance, not a claim that frozen behavior is identical.
* On a quiet class with `MethodAccessWithOverride`, `m.public_send(:'respond_to?=', 7)` raises `ArgumentError` before storing on base; head stores the key and permits the next ordinary write. This confirms the known 18 rows and their previously unrecorded partial state. It is an improvement for a shipped extension and a user-controlled key, not just internal accounting; disclose it if retaining the change.

The no-ivar-assignment difference alone is acceptable. Skipped/added effectful hooks cannot be accepted as merely count differences while promising identical warnings/state for every caller. The private `_log_collision?` override control matched; the shipped `PermissiveRespondTo` override remains a separate, unchanged path. The existing probe drops stored state on exceptions and does not record identities/keyword flags; its hook tests count calls only. Additional identity/frozen/keyword-flag controls for ordinary values and Hash/Array/String subclasses matched, while the new callbacks above expose changes it did not record.

### Performance: raw numbers reconcile, but the plain-path cost needs a broader repeat

`audit.py` recomputed paired medians and A/A from **80 archived wall cells**, and all base/A/A/head Callgrind totals for `body/HM4` and `body/HM4-module-f41c3b2`; they match `results.json`. Confidence intervals were checked as recorded, not independently regenerated. Raw Duel logs and the live run API confirm run 46079366956, the exact head, Ruby 4.0.10, 28 benchmarks and zero classified regressions; the YJIT read-only KeepOriginalKeys case is unsettled. CPU rows 0.458/0.655, 1.007/1.006 and 1.013/1.013 round correctly in the body. “Same” is Duel's threshold classification, not proof of zero cost. The retained mixed-master wall cohort recomputes +9.108%, A/A +0.209%, consistent with its recorded intervals [+7.408%, +9.836%] and [−1.192%, +2.606%]. The refused-form numbers reconcile too.

This review orb has **2 vCPUs and 3,931 MiB RAM**, not a1.xxlarge; its tier name was not exposed by the inspected CLI/environment. New timings are diagnostic only. The sweep covered one scalar key, 20 fresh keys, 20 suffixed keys, the nested fixture, clear-and-insert and overwrite, each plain-only/quiet-first and before/after calling **`Hashie::Mash.disabled_warnings`**. That reader initializes an empty Array without disabling any warning, defeating the head's new fast return. All 48 cells used five randomized base/A/A/head rounds, nine GC-off CPU-time windows/process, core 0. No JIT-flat gate was claimed; some review checks overlapped, and the observed ranges are noisy.

The worst median in this finite sweep was the nested fixture **after quiet-class warmup and inspection of the plain exclusions list**:

| Diagnostic only | Paired change | A/A | Observed change range | Observed A/A range |
|---|---:|---:|---:|---:|
| Ruby 4.0.10/YJIT | +12.68% | +0.25% | −0.75% to +14.42% | −2.20% to +15.28% |
| Master 0d399335b7/ZJIT | +8.53% | +0.69% | +3.10% to +14.64% | −5.00% to +4.85% |

These are not confidence intervals or established speed-loss claims. A less noisy YJIT control, 20 fresh keys after only inspecting the list, was +8.85% (A/A −0.29%; change range +6.86% to +11.40%, A/A −2.16% to +1.22%). No warning was disabled on the measured plain Mash. Repeat this state-dependent cost on a1.xxlarge before treating approximately 1% as representative.

The exact-head `zjit_mixed.rb` rerun confirms polymorphic-send fallbacks per plain construction rise **20/20/114 for base/A/A/head** after quiet warmup; the plain-only control is 40 on both trees. The checked runs explicitly have `compile_error_out_of_memory=0` with `--zjit-exec-mem-size=512 --zjit-mem-size=1024`. This verifies the dispatch observation on this head, rather than borrowing it solely from older variants.

**None of the refused forms is a replacement:** all three were applied in separate scratch worktrees and all three fail the quiet-class Ractor repro. The module form also adds a second collision path, reorder-only pays the larger ordinary-path cost, and flag-first ignores direct mutation of the exclusions Array. The smallest safe rollback is to restore the original ordering and remove the new ivar guard; it loses the proposed quiet speedup. No optimization-preserving fix is established. Do not add exception rescues, method-owner guards or copied collision logic merely to keep the win. Correctness already blocks this head; performance approval should separately wait for an a1.xxlarge repeat of these ordinary/mixed-state shapes and acceptance of the tradeoff. The small-orb runs alone are not a formal new loss gate.

### Upstream text, relevance and currency

Every title/body/commit-message/CHANGELOG sentence was checked against the exact diff, executed tracing/probes, retained raw evidence or fetched source/API responses; the full sentence table is `review.md` in the archive. Required text corrections:

* “Every Mash write” is false for Integer keys. An unset key matching an existing built-in (`size`) does not call `respond_to_missing?`. Prefer new, nonconflicting String/Symbol keys through the default helper. The “once for every key” cost sentence also needs that qualification: a fresh collision calls the class twice, including the logger check, before and after.
* Cut the universal “most expensive step” assertion. In the retained YJIT issues profile, `convert_value` is 62.6% inclusive versus `respond_to_missing?` 20.0%; the repository profile's 49.0% is `Kernel#respond_to?`, not that missing-method hook alone.
* “Ruby 4.0 doesn't show this” overstates a local 4.0.10/20-round cohort that fails its JIT-flat gate. Say it was not observed in that cohort. The master warning and table are fair descriptions of their specific runs, not release-wide guarantees. Discarding a boolean is not evidence that discarded callbacks have no effects.
* The new benchmark does build the quiet subclass from the nested JSON fixture. No added comment needs removal; the two-line source change is L0 syntactically but its guard bypasses a semipublic contract.
* Both caller permalinks match the latest released gem bytes and release-tag SHAs; KeyStore line 8 disables warnings, AuthHash line 8 inherits it, and HashWrapper lines 28–29 inherit Mash and disable warnings. Their current default branches retain those calls. Commit attribution matches Thomas. The highest live issue/PR number is **661**, so the next expected number is **662**, not the CHANGELOG's assumed 663; recheck at opening.

Live GitHub/rubygems metadata and released/default-branch sources are retained in `reach/`. All are unarchived; downloads are cumulative, not active hashie-6 installs:

| Project | Stars | Downloads | Latest release/date | Last push | Released hashie range |
|---|---:|---:|---|---|---|
| omniauth | 8,102 | 235,368,604 | 2.4.2 / 2026-11-18 | 2026-11-27 | >= 3.5.2; allows 6 |
| elasticsearch-model | 3,079 | 78,460,281 | 8.0.1 / 2025-09-01 | 2025-10-08 | >= 0; allows 6 |
| restforce | 822 | 60,006,023 | 8.0.1 / 2025-12-29 | 2026-07-27 | >= 1.2.0, < 6.0 |
| zendesk_api | 410 | 47,179,798 | 3.1.2 / 2026-07-23 | 2026-11-17 | >= 3.5.2; allows 6 |
| chef-zero | 530 | 22,642,721 | 15.1.11 / 2026-05-28 | 2026-11-16 | >= 2.0, < 6.0 |

The body's two callers are ordered by reach. Elasticsearch has over a year without a push/release, but 8.0.1 remains latest and abandonment is not demonstrated; keep it secondary, not as evidence of recent maintenance. The impact reasonably separates compatible users from restforce/chef-zero, whose releases cannot use hashie 6. A combined reach ranking puts restforce ahead of zendesk_api. Every listed release has the stated quiet subclass. Duel (the project's chosen tool, not an impact caller): 21 stars, 8,764 downloads, 0.3.1 released 2026-11-22, pushed 2026-11-25. Hashie: 3,035 stars, 507,065,900 downloads, 6.0.0 released 2026-11-11, pushed 2026-11-27. Neither is archived.

### Executed checks and limitations

* Both trees ran the unchanged differential and new adversarial/Ractor probes on **3.0.7, 3.1.7, 3.2.9, 3.3.10, 3.4.7, 4.0.10, 4.0.10/YJIT and master/ZJIT**, built at `0d399335b733776187e43a783e5f950c18ad881c`. Both blockers reproduce throughout; R1 is broader on 3.0.7. A prebuilt 4.0.10 without ZJIT emitted a warning when attempted with `--zjit`; its interpreter outputs are retained but excluded from ZJIT coverage.
* `bundle exec rake spec` on 4.0.10: **1,076 examples, 0 failures on each tree**. Head `bundle exec rake rubocop`: **156 files, no offenses** (also the 124-file subtask); `bundle exec rake docs:examples`: **359 examples, 0 failures**. Earlier unbundled release-preparation failures were resolved by installing the complete bundle; their logs remain. No full suite on every Ruby or integration-app matrix is claimed.
* The original probe covers every requested extension, `Mash.quiet`, none/some/all/String exclusions, repeated calls, inheritance/narrowing, late configuration, arbitrary keys/conversions, anonymous classes and frozen receivers. The additional probes cover the missed readers/prepends, effectful hooks, partial state after exceptions, direct ivars, mutable returned configuration, frozen-class writes, threads and Ractors.
* Original-probe behavior differences remain 18 MethodAccessWithOverride rows and three accepted output lines. Ruby 3.1 additionally changes 72 source/caret lines in 36 NoMethodError highlights because the expression moved; those are not new semantic failures. Raw stdout has 66,999 lines normally (66,994 excluding five `accepted` lines), 67,107 on 3.1. All raw outputs and hashes are retained without filtering. This review establishes counterexamples, not equivalence for all remaining Ruby programs.

## thermos-sol HM4: changes on 10a93033975136664d7b7231986663e9c7689d91

2026-11-27, GPT-6.1 Sol, xhigh, thread `T-01a21f5c-5173-76cc-aa9a-676d6e5f0c2d`. Applied both Thermos
rubrics directly in this thread, without delegation, as requested. Exact base
`277e88e6ccc317497e6c20fb8b9e35abebc0fe19`, one candidate commit. Neither hashie checkout was changed; no fork push,
upstream PR or upstream comment. The reviewed queue text is preserved in the evidence as `sources/HM4-reviewed.md`
(SHA-256 `5cedeb6a5d6333475eb3dd74ccf9d025f94357d65b33ca8f99c0ddbcdc915ddb`).

**Changes, not an exact optimization.** Two ordinary supported cases regress: Ractors cannot build configured
subclasses that worked before, and a semipublic warning-list override is ignored. The cost is disclosed substantially
fairly and is not the reason for this verdict. The existing differential's accepted call-count changes also have
observable consequences beyond counts. The following are executed differences, not hypothetical ones.

Evidence: [`thermos-sol-HM4-10a9303.tar.gz`](thermos-sol-HM4-10a9303.tar.gz), scripts and source/API snapshots at its
top level, all raw outputs in the nested `raw-evidence.tar.xz`. Nested compression retains preliminary/noisy runs as
well as final runs without exceeding 10 MB. `RUNS.md` gives commands, pins and the interpretation of each cohort.

### R1 — P2: querying warning configuration on noncolliding keys breaks Ractors

`lib/hashie/mash.rb:645` newly calls the class predicate even when `respond_to?` would return false. Both the new
predicate and the old predicate then consult the mutable, unshareable class warning-list Array. Previously this
class state was never touched for an ordinary new key. No override, private access or concurrent mutation is needed:

```ruby
require 'hashie'
class QuietWorkerMash < Hashie::Mash
  disable_warnings
end
QuietWorkerMash.new(name: 0)
worker = Ractor.new { QuietWorkerMash.new(name: 7).to_h }
worker.respond_to?(:value) ? worker.value : worker.take
```

Base: `{"name"=>7}`. Head: `Ractor::RemoteError` wrapping `Ractor::IsolationError` (the harness rescues inside the
worker and records the underlying error). Demonstrated on Ruby **3.0.7, 3.1.7, 3.2.10, 3.3.10, 3.4.7, 4.0.10 and
master**, including available YJIT/ZJIT modes. Master is `0d399335b733776187e43a783e5f950c18ad881c`.

`edges.rb` also reproduces this with `disable_warnings(:size)` and a new `:name` key, and with an otherwise plain
subclass whose public `disabled_warnings` was merely inspected before starting the Ractor. Unconfigured plain and
unconfigured frozen classes are controls that still work. A real caller can prepare a warning-disabled response
class in the main Ractor and build responses in workers. This is a write failing, not merely a query's different
instance-variable side effect. The existing `quiet_diff.rb` never starts a Ractor.

Smallest unquestionably exact remedy: restore the old predicate-call position. Removing only the new ivar guard
does **not** solve this, because the old predicate also reads the Array. Do not freeze a public mutable list,
rescue isolation errors into a different warning policy, or cache configuration that can still change. No such fix
was applied in this review.

### R2 — P2: the ivar shortcut bypasses the semipublic warning-list method

`lib/hashie/extensions/key_conflict_warning.rb:57` infers an empty policy from the absence of two implementation
ivars instead of asking `disabled_warnings`. That method is explicitly `@api semipublic`, not private/nodoc:

```ruby
require 'hashie'
class ListPolicy < Hashie::Mash
  def self.disabled_warnings
    [:size]
  end
end
p ListPolicy.disable_warnings?(:size)
ListPolicy.new(size: 7)
```

Base: `true`, no collision warning. Head: `false`, one collision warning. Both store `{"size"=>7}`. The reproduction
captures the logger and counts the actual warning, not calls to a private helper. This also reproduces on every
Ruby above. Lazy policy storage in a differently named ivar, a `Thread.current`-backed list, singleton-class
`prepend`, `extend` and inherited list methods reproduce the query change (`repros.rb`, `edges.rb`). A real policy
provider or subclass can implement this method without using Hashie's ivar names. Directly filling the default
`disabled_warnings` Array still works; that is a different case and does not validate overrides.

Smallest fix for R2 alone: delete the added early return and remeasure. That is effectively the refused reorder-only
form, which still has R1 and its measured plain-Mash cost. A method-owner check, extra cache or another one-caller
module is not a smaller or demonstrated-exact solution. Taken together, R1/R2 favor holding this candidate rather
than adding a stack of compatibility branches to save this check.

### Judging the accepted differences, including what the probe did not record

* **Skipped `respond_to?` / `respond_to_missing?`: intentional mechanism, but not just a count.** With warnings
  disabled, either public hook can materialize state. A minimal override is
  `def respond_to?(key, *rest); regular_writer('checked', true) if key == :name; super; end`.
  `new(name: 7).to_h` is `{"checked"=>true,"name"=>7}` on base and `{"name"=>7}` on head. The equivalent
  `respond_to_missing?` override does the same (`dynamic_policy.rb`). This is a real metaprogramming/lazy-property
  caller shape, though not demonstrated in the named consumer gems. Skipping such hooks is inherent to the requested
  optimization, so not an independent surprise blocker; accept it only as an explicit hook-contract change, not
  evidence that stored state is identical for every caller. If pursued, the body should say that disabled keys no
  longer invoke these hooks. Private `_log_collision?` override differences are within DECISIONS' accepted boundary.
* **Extra `disable_warnings?` calls: disclosed cost, not unconditionally benign behavior.** `repros.rb`'s public
  `FilterPolicy` returns `super` for nil/`:size` and raises `KeyError` for any other key. `new(name: 7)` stores the
  value on base and now raises. A Boolean-returning policy also suffices: increment `@queries` and return
  `(@queries % 3).zero?`; `new(name: 0, size: 7)` logs once on base and zero times on head, with identical stored
  values (`dynamic_policy.rb`, master interpreter/ZJIT). A stateful warning budget or policy lookup can hit this.
  These demonstrate the expanded invocation contract, not another failure of a pure predicate. The body already
  says it asks earlier, but must not imply arbitrary custom policies keep the same warnings or errors.
* **No query ivar assignment: accept the reduced mutation, but its consequence reaches writes.** For
  `class F < Hashie::Mash; end; F.freeze`, `F.new(size: 7)` raises `FrozenError` on base; head stores the key and logs
  once. `F.disable_warnings?` raises on base and answers false on head. A frozen unconfigured subclass is plausible;
  this is a beneficial behavior change, not a correctness blocker, but the record's assertion that nothing is
  returned/stored differently is too broad. Do not add an ivar detail to the body; disclose improved frozen-class
  behavior if claiming comprehensive compatibility.
* **The 18 `MethodAccessWithOverride` rows: accept the removed failure.** For a quiet subclass including that
  extension, `new('respond_to?' => 1, 'name' => 2).to_h` raises `ArgumentError` on base and returns both keys on head.
  This is a real response-key collision, not merely a count. An upstream body need not enumerate this one repaired
  error path, but cannot claim all errors and stored state are unchanged. The current body does not make that claim
  explicitly; the internal checklist does.

These boundaries do not excuse R1 or R2: R1 uses only built-in configuration and ordinary keys; R2 uses an existing
semipublic policy API, with no side effects needed.

### Executed exactness, tests and limitations

Ran `run-matrix.sh` across the seven Ruby pins above, interpreter everywhere, YJIT where available (3.1 onward),
and ZJIT on 4.0.10/master. `repros.rb` records warnings, returned/stored state and underlying exceptions; `edges.rb`
adds Ractors, configuration during key conversion, direct flag/list states and policy mixins. Four worker threads
with configuration established before use agree on ordinary stored results. This is not a race-freedom proof for
arbitrary simultaneous policy mutation, and none is claimed.

The independent `public_diff.rb` has **12,242 rows per runtime**: no/all/some warnings, String settings, repeated
calls, narrowing/widening/inheritance, direct ivars/list mutation, late configuration, anonymous/frozen classes,
`Mash.quiet`, all seven requested extensions, public and private overrides, eight write/construction operations,
String/Symbol/suffixed/numeric/nil/duck keys, defaults/default procs, frozen receivers, and Hash/Array/String
subclasses. It records partial receiver state after exceptions, nested classes/frozen flags, String encodings and
`Hash.ruby2_keywords_hash?`, rather than just a JSON representation of values. Corrected normalized runs are
`public-final-*` and the master `public_diff-master-*`; earlier `public_diff-*`/`public-4.0.9-*` files retain
address-normalization noise and are not evidence of further bugs. Ordinary pure-policy cases otherwise agree;
the meaningful categories are the demonstrated policy, frozen-class and MethodAccessWithOverride differences,
plus earlier failures from the deliberately private class predicate (accepted private boundary).
Ruby 3.1 also records eight changed `error_highlight` source excerpts pointing to the moved query; exception type,
underlying message, warning output and partial state are unchanged in those eight rows, not another semantic bug.

Reran the original `quiet_diff.rb` on 4.0.10 and master, each in interpreter/YJIT/ZJIT. Each emits **66,999 lines**;
21 differ, consisting of the 18 known MethodAccessWithOverride cases and three accepted-summary lines. This
confirms why that differential missed R1/R2 and hook-induced state changes: it lacks the first two caller shapes
and only counts the hooks in separate accepted summaries. It also does not preserve keyword flags in its value
serialization. No keyword-flag regression was observed for HM4 in the independent harness.

Ruby 4.0.10: targeted Mash/extension specs **254 examples, 0 failures on both base and head**; head executable
documentation **359/0**. Full head suite **1,076 examples, 3 failures**, all release-preparation subprocess Bundler
dependency resolution (missing `guard`); rerunning that spec on base reproduces all three. RuboCop inspects 156
files and reports the **same two existing `RSpec/EmptyLineAfterSharedInclusion` offenses** on base/head with the
installed 1.93.0/plugin versions. Thus this review does not reproduce the record's all-green full suite/lint in its
own environment, and does not attribute those environmental/baseline failures to HM4. Raw logs are retained.
No app integration suite, arm64 or alternate Ruby implementation was run.

### Performance evidence and worst-input search

`audit_raw.rb` recomputes all HM4 wall medians/bootstrap intervals/A/A and JIT-flat decisions from retained round
arrays. `audit_files.py` cross-checks **every wall sample** against its archived worker log, Callgrind deltas against
raw totals, and the exact-head Duel CPU summary rows against `duel/logs.tar.gz`. These checks pass. GitHub run
46079366956's API and logs identify the exact head/base; fork PR 36 is closed. Its 28 benchmarks/zero regressed and
the one YJIT unsettled read-only benchmark match the record; “same” is Duel's classification, not proof of zero cost.

The body's rounded quiet CPU ratios **0.46/0.66**, plain nested **1.01/1.01**, and new-method writes **1.01/1.01**
are supported by the unrounded intervals in the table above. The archived local master/ZJIT mixed-process loss
recomputes to **+9.108% [+7.408, +9.836]**, A/A **+0.209% [−1.192, +2.606]**, all windows JIT-flat. It is honestly
mentioned without promoting the local percentage into the body. The 4.0.10 ZJIT interval includes zero and lacks a
side-exit counter, so it cannot establish the categorical sentence “Ruby 4.0 doesn't show this.” Say instead that
the effect was not detected in the tested 4.0.10 mixed-process run. The dynamic-send explanation is supported by
`probes/zjit_mixed.rb`/`out/zjit-mixed-order.txt` on earlier forms (20 versus 114 polymorphic fallbacks); those
statistics are not a new exact-head causal experiment.

**This review's orb is two vCPUs/3,931 MiB, not a1.xxlarge. All new timings are diagnostic only.** `perf.rb`/`perf.py`
sweep 13 plain-Mash shapes, plain-only and quiet-first mixed processes: empty and integer-key controls, absent
String/Symbol keys, `?`/`!`/`_`/`=` suffixes, overwrites, flat 20-key and 20-question-key Hashes and the repository
fixture. Six randomized base/head/base2 rounds, pinned core, seven GC-off thread-CPU windows per process; all
samples retained. This is a bounded adversarial input search, not a universal maximum over user callbacks.
The initial 4.0.10/YJIT sweep overlapped Ruby builds and has a large unaffected-empty control change; it is retained
but rejected as performance evidence, not rerun until green. The separate master/ZJIT sweep has its worst changed
mixed-process point estimate at **20 question-suffixed keys, +2.67%, A/A −0.46%**; the empty control is noisy
(+2.22%, A/A +5.80%). It does not reproduce the older master's +9.1% result on this later pin, and cannot refute it.
The separate 4.0.10 interpreter sweep's largest loss is **overwriting an existing question-suffixed key in a mixed
process, +4.29%, A/A +0.19%**: after warming the quiet subclass, `m = Hashie::Mash.new('ready?' => true)`, repeatedly
`m['ready?'] = true`. For a plain-only process, new `{'ready?' => true}` is the largest point estimate, **+3.70%,
A/A +0.16%**. These are diagnostic point estimates without a bootstrap/JIT-flat claim, not a basis for a new body
number. The repository fixture is the slowest absolute operation in this bounded sweep; the cheap suffixed-key
operations expose the extra-query cost without requiring an unusually large response.

After this independent audit, fetched the concurrent Astra record and tested its additional caller state:
**merely inspect `Hashie::Mash.disabled_warnings` before using plain Mash**, leaving the Array empty. This defeats
the shortcut without disabling a warning. A separate six-round master/ZJIT sweep (`PRIME_LIST=1`, no outputs
overwritten) has the largest changed mixed-process point estimate of this review: **`Mash.new('ready?' => true)`,
+10.70%, A/A +0.36%**. Plain-only, flat20 is +7.26%, A/A −0.69%; the repository fixture is +6.10%, A/A −0.22%.
These remain diagnostic, not a statistical or policy-compliant blocking-loss claim. They independently confirm
that “a class that never disabled a warning” does not necessarily use the fast return. The body's cost table is
fair for its measured state, not a bound on all ordinary plain-Mash states. **Repeat the inspected-list and mixed
cases on a1.xxlarge before clearing the general performance claim.** No larger loss over arbitrary mutable policy
lists is claimed without running it.

The refused forms do not supply a demonstrated better candidate: reorder-only preserves method-based list policies
but still queries them for noncollisions and costs 3–5% in Duel; flag-first loses direct list configuration; the
module form duplicates the shared check and has the archived **+19.039% [+18.239, +19.639] YJIT mixed-process loss**.
Its early policy lookup has the same Ractor-sensitive dependency. Their local wall comparisons were recomputed
and Duel CPU rows checked against raw logs, not silently substituted for exact-head runs. Do not revive one merely
to get a nicer isolated Duel table. There is no measured, exact better form established here. Performance alone would not block the well-used
quiet-class win given the fairly stated cost; correctness does. A replacement needs exactness first and mixed-class
timing on a1.xxlarge before approval.

### Sentence-by-sentence upstream text audit

The archive preserves the exact title/body, `git show --format=fuller` with the commit message and CHANGELOG, live
API metadata, released sources and linked-file snapshots. Every factual sentence was checked; findings are cuts
or qualifications below, not unverified assertions passed through.

| Text | Command/source checked | Judgment |
| --- | --- | --- |
| Title: skip the check in warning-disabled subclasses | Exact diff, quiet-class differential, Duel benchmark/logs | Accurate mechanism for the normal subclass; not a universal equivalence promise. |
| Body/commit: “Every Mash write asks respond_to?” | `edges.rb` counts on `:size`, `:unseen`, `7`, nil; `custom_writer`/`_log_collision?` source | Overbroad: numeric/nil writes do not call the receiver hook. Qualify to checked String/Symbol keys; extension overrides can bypass this path too. |
| Body/commit: an unset key runs respond_to_missing? | Same probe: absent built-in `:size` calls `respond_to?`, not `respond_to_missing?`; absent `:unseen` calls both | False without “when it is not already a method.” Cut the generalization. |
| Body: “the most expensive step of building a Mash” | Read `out/profile-stackprof-4.0.10-yjit.txt`: `respond_to?` 49.0% inclusive, `respond_to_missing?` 30.9%; interpreter file and fixture | Profiling supports a hot path in this fixture, not a universal superlative. Cut “the most expensive step” or scope it to the profile. |
| Body/commit: disabled subclasses do that work then discard it | Base `_log_collision?` and quiet-hook repros | True for those checked keys; keep only after the preceding qualification. |
| OmniAuth KeyStore/AuthHash parentage, 2.4.2; elasticsearch-model HashWrapper, 8.0.1 | Fetched exact linked blobs, latest gem tarballs, release/tag and default-branch APIs | Both permalinks still contain the disabling call at the named line, match released code, and describe current released callers. Reach below. |
| Body/commit: class query before respond_to?; fast false for unconfigured class | Exact diff, direct-ivar/query probes, primed-list sweep | Only falsy flag and list ivars take the shortcut; merely inspecting an empty list defeats it despite never disabling a warning. R2 also invalidates inferring policy from ivars for an override. |
| Body/commit: new benchmark builds quiet subclass from nested fixture | Benchmark diff, repository fixture, Duel logs | Verified; no new comment or implementation-count test. |
| “Duel on Ruby 4.0, CPU time relative to master” and all six cells | Run API, raw logs, `audit_files.py`, `runs.tsv`/summaries | Verified, 4.0.10, exact head versus exact base; table rounds correctly. |
| Cost: one extra class query for every key | Hook-count probes and diff | Correct direction, overbroad domain: String/Symbol conflict-check path, not integers/nil or bypassing extensions. Also affects custom-policy behavior as demonstrated above. |
| Master/ZJIT mixed-process slowdown and two receiver classes | Recomputed archived +9.108% cohort, earlier-form ZJIT stats | Cost disclosure is fair. Do not present earlier-form attribution as an exact-head experiment. |
| “Ruby 4.0 doesn't show this” | 4.0.10 mixed raw cohort, missing JIT-flat counter; exact Duel CPU rows | Too categorical; qualify to the tested run and its lack of detected effect. |
| CHANGELOG describes skipped conflict checks and credits Thomas | Exact diff, author/committer metadata | Mechanism/credit supported; no added explanatory code comments to reject. |
| CHANGELOG assumes pull/663 | Latest issue API is 661; issue endpoints 662 and 663 return 404; upstream open-PR API empty | **Next number is 662 at this check, not 663.** HM5 opening first is an unfulfilled assumption. Recheck and fix before posting; no PR number can be reserved by this text. |

The commit message repeats the first two overgeneralizations and “every key” scope; fix those in the commit as well
as the body. The body need not become a catalogue of private overrides or repaired error cases. R1/R2 are blockers,
not limitations to bury in additional prose. Keep the corrected body short rather than growing it to justify them.

### Reach and currency checked against current releases

Used GitHub repository APIs (stars, archived state, current branches), RubyGems gem APIs (latest version, release
date, lifetime downloads and runtime requirement), downloaded latest `.gem` sources, and release-tag/linked-blob
comparisons. Full responses and source files are archived. All five projects are non-archived; their latest released
sources retain the disabling calls. Downloads are lifetime gem downloads, **not** counts of users running hashie 6.

| Project/gem | Stars | Downloads | Latest release | Released hashie requirement | Reach supported now |
| --- | ---: | ---: | --- | --- | --- |
| omniauth | 8,102 | 235,368,604 | 2.4.2, 2026-11-18 | `>= 3.5.2` | Allows 6; KeyStore line 8 disables warnings, AuthHash inherits it. |
| elasticsearch-rails / elasticsearch-model | 3,079 | 78,460,281 | 8.0.1, 2025-09-01 | `>= 0` | Allows 6; HashWrapper line 29 disables warnings. |
| zendesk_api_client_rb / zendesk_api | 410 | 47,179,798 | 3.1.2, 2026-07-23 | `>= 3.5.2` | Allows 6; SilentMash disables warnings. |
| restforce | 822 | 60,006,023 | 8.0.1, 2025-12-29 | `>= 1.2.0, < 6.0` | Same pattern, but not reachable through its released dependency constraint today. |
| chef-zero | 530 | 22,642,721 | 15.1.11, 2026-05-28 | `>= 2.0, < 6.0` | Same pattern, likewise excluded today. |

Hashie itself: 6.0.0 released 2026-11-11, 3,035 stars, 507,065,900 lifetime downloads. The impact's ordering of the
three eligible consumers and its explicit `< 6` exclusion for the other two are supported; the body names the two
strongest eligible examples. Do not add the excluded consumers' downloads to current affected reach. The impact's
“every key written” wording needs the same domain qualification as the body.

### Maintainability rubric

Cold read: reject non-String/Symbol keys; ask whether the class disabled this warning; otherwise test whether the
receiver responds; accept only a nonsuffixed/setter conflict that is not already a stored key. The query returns
false for absent internal flags/list, otherwise uses the existing policy. This is short and in the canonical shared
helper, with no new wrapper, public name, dependency, mode or duplicated check on the exact head. No convincing
structural extraction or new policy layer would simplify it. **L0 structurally; no independent maintainability
blocker.** The implicit ivar-to-policy equivalence is the concrete boundary error R2, not a reason for cosmetic
refactoring. No security, feature-gate or devex regression was demonstrated beyond the runtime behavior above.

RuboCop 1.93.0 metrics: `_log_collision?` ABC **14.46 → 13.64**, cyclomatic/perceived **8 → 8**;
`disable_warnings?` ABC **5.10 → 6.48**, cyclomatic/perceived **4 → 6**. Flog 4.10.0: **19.9 → 17.5** and
**5.6 → 6.6** respectively. The predicate grows because the shortcut adds a compound branch; that small increase
is readable but buys the incorrect abstraction assumption above. Head files are 654, 91 and 112 lines respectively
for Mash, KeyConflictWarning and the extension benchmarks; no 1,000-line threshold crossing. No added code comments
or tests to trim. The new benchmark measures a useful public operation, but is not a regression test for R1/R2.

## Astra HM5, second pass: approve on 6b6f67b39c4f839154209f4d94ceadb416f82ddb

2026-11-28, thread `T-01a21f3c-2ef1-726e-be84-05ebf5389576`, reviewed here without delegation.
**No open finding.** Thomas's accepted boundary covers R1, including first-copy state, value/key callbacks and
fiber/thread replacement or deletion; its omission from the body is explicitly accepted, not a finding.
`git ls-remote` confirms the exact fork head; `git show` confirms its sole parent, complete diff, commit message
and CHANGELOG. Compared the title/body byte-for-byte with the first-pass Lowrail commit: unchanged. The earlier
sentence audit and eight-cell differential evidence therefore still apply; no new full matrix or timing run is
claimed. Re-read the conversion and reader bodies and executed `instance_method(:to_hash).owner`: Hash/Mash use
Hashie::Hash, Dash/Trash use Dash, and IndifferentAccess uses its own module. The narrowed impact is accurate.

Recomputed both huge-Array cohorts from all 90 raw process logs each using `script/upstream-bench`'s `wall_cell`
and bootstrap estimator; every estimate/interval matches `results.json`, and all recorded JIT deltas are zero.
For `Hashie::Hash[item: Hashie::Array.new(131_072, 17)].to_hash`, master/ZJIT is −0.1% [−0.5, +0.3], while
4.0.10/YJIT is +0.6% [+0.4, +0.9], A/A +0.1% [−0.3, +0.3]. **The YJIT loss is detected in that cohort, not
inside its noise interval. It may remain in the record, without a body sentence.** The body claims only the
named nested-Mash Duel fixture, not a universal speedup; the size sweep belongs here. Under the current timing
rule, effects below 3% still require a1.xxlarge, so this eight-CPU result is diagnostic rather than a qualified
blocking-loss claim. No cause or absence of a worst-case slowdown is asserted. A stronger sub-percent claim
would require the specified host; this is not an additional opening condition for this narrowly worded body.

Live `gh api` checks still show latest visible issue/PR **661**, and GET 662 returns **404**: 662 remains the next
visible number, not reserved. Recheck at opening. Refreshed reach: OmniAuth 2.4.2, 235,407,426 downloads, 8,102
stars, released 2026-11-18, pushed 2026-11-27, released requirement `hashie >= 3.5.2`; the only named downstream
still permits Hashie 6 and needs no reach reordering. Hashie remains unarchived with 3,035 stars, pushed
2026-11-27. Duel remains unarchived with 21 stars, 8,797 downloads, version 0.3.1 released 2026-11-22 and pushed
2026-11-25. Existing raw evidence stays in `astra-HM5-6b6f67b.tar.gz`, `duel/` and `wall/HM5-array-*`.
No candidate edit, fork push or upstream post.
