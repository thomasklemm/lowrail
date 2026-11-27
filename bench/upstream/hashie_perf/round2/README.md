# hashie, round 2: what else can be made better (2026-11-27)

A deeper look after dblock's four leads ([round 1](../README.md)): which hashie classes the popular dependents use,
where a realistic API workload spends objects and time, and which exact changes follow. Three candidates were built
(HM3, HM4, HM5); the rest are held with their numbers.

Setup: hashie master `9e313f3`. Rubies 4.0.10 `a704b7cd95` and master `0d399335b7`, both built with YJIT and ZJIT;
suites also on 3.0.7 and 3.4.7. Duel ran on fork PRs (thomasklemm/hashie #27–#29, #32) against `perf-base-zjit`
(master plus the ZJIT job), on GitHub's runners with Ruby 4.0.10; run IDs in `duel/runs.tsv`, summaries in
`duel/*.summary.txt`, full logs in `duel/logs.tar.gz`. Local runs used this orb (8 CPUs, not a1.xxlarge), so local
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
| 1 | HM4: skip the conflict check when a subclass disabled warnings | omniauth, elasticsearch-model, zendesk_api now; restforce and chef-zero once they allow hashie 6 | quiet `Mash.new` CPU 0.43 (YJIT) and 0.64 (ZJIT) in Duel; `[]=`, `dup`, `merge` alike | see [HM4](#hm4-skip-the-conflict-check-when-warnings-are-disabled) |
| 2 | HM3: `method_missing` without the arguments Array | every Mash, Ruby ≥ 4.0 | 1 object per method-style read; reads CPU 0.91–0.95 in Duel; setters 1.01–1.02 | built, in review |
| 3 | HM5: `to_hash` reads each value once | every `to_hash` and `to_json` | CPU 0.86 (YJIT) and 0.69 (ZJIT) in Duel | built, queued behind the first two |
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

Queued, not opened: at most two new hashie PRs at a time.
