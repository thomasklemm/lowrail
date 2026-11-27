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
