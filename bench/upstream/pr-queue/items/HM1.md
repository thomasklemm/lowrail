---
id: HM1
repo: hashie/hashie
fork: thomasklemm/hashie
kind: perf
area: Mash#respond_to_missing?, method_suffix, log_collision?
reviewer: dblock
branch: thomasklemm/respond-to-missing-allocations
head: "5a63e912442b8c2713fc09f9e52e3d6aba6d01f8"
base: master
built_on: "37454e149e"
depends_on: []
stacked_on:
alternative_of:
impact: "Writing a new symbol key to a Mash allocates 2 objects fewer (the respond_to_missing? argument array and the Symbol#to_s copy), and the collision check no longer builds a name-and-suffix pair: Mash.new of a 24-key API response with one nested object and an array of two goes from 101 to 21 objects on Ruby 4.0.9, -3.2% instructions (interpreter, A/A 0.00%), -11.4% (YJIT, A/A 0.05%, JIT-flat) and +20.3% benchmark-ips (YJIT, best of 3, A/A 3.80%). On CodeTriage's suite (hashie 5.1.0, same three-line change) the two lines go from 21.78 objects per request each to 0, and whole requests from 5,987 to 5,944 objects (-0.7%), with identical test outcomes."
evidence: [bench/upstream/oss_profile_sweep_1/body/HM1, bench/upstream/oss_profile_sweep_1/hm1, bench/upstream/oss_profile_sweep_1/hm1_diff.rb]
rank:
risky: false
state: built
pr:
note: "2026-11-26: built on master 37454e149e (6.0.1 dev); fork branch pushed, nothing posted upstream, no PR. Found by script/profile-hotlines (docs/upstream/profile-hotlines-2026-11-25.md, #3 method_suffix and #5 log_collision?, in 5 of 12 apps; Huginn 22% of jobs, Forem 95%, CodeTriage 100% of requests). Ownership, open and closed: no PR or issue names method_suffix, log_collision? or method_name_and_suffix as a cost; no open PR touches lib/hashie/mash.rb (open PRs: none; open issues #450, #229 unrelated). Closest prior work, all merged: #613 (sampokuokkanen, Symbol#name in convert_key, 2026-10), #615 (dblock/Copilot, 'remaining allocation improvements identified by profiling after #613': Hashie::Array construction, Symbol#name in IndifferentAccess and KeepOriginalKeys; does not touch respond_to_missing? or the suffix helpers), #614 (Mash#dup), #411 (2017, the respond_to? collision check that this path runs on every write, fixing issue #410's logging regression), #639 (the _-prefixed helper rename). Last release v6.0.0 2026-11-11 (dblock); last commits 2026-11-23. No Lowrail queue or ledger item for hashie. Suite (RUBYOPT=--disable-error_highlight CI=true bundle exec rake spec) on Ruby 3.0.7, 3.1.7, 3.2.11, 3.3.14, 3.4.13, 4.0.9: master and branch 0 failures each, branch +1 example (the new spec); JRuby not run (no JRuby in the orb; the spec is MRI-only like its neighbours). rubocop 153 files no offenses. The new spec fails on master (expected 0, got 200) and passes on the branch. Differential hm1_diff.rb (Mash, StrictKeyAccess, PermissiveRespondTo, KeepOriginalKeys, SymbolizeKeys, DefineAccessors, subclasses overriding respond_to_missing? with *args or (name, priv), disable_warnings; 9,140 rows over String, Symbol, suffixed, unicode and non-String keys; respond_to?, respond_to_missing?, writes with the warning log, dynamic calls): master A/A identical; master vs branch identical on Ruby 4.0.9 and 3.0.7 except direct respond_to_missing? calls with 1 argument (master ArgumentError, branch false) or 3 (master true, branch ArgumentError), which Ruby never makes; the new arity matches Clash, Rash and MethodAccess (hm1/diff-ruby-*.txt). Body numbers: script/upstream-bench body/HM1 on 5a63e91 (base twice, interp A/A 0.00%, YJIT A/A 0.05% JIT-flat in 6 windows, ips A/A 3.80% JIT-flat in 9 windows; per round the branch beat both base runs: +13.3%, +21.9%, +26.7%, lowest branch 44.1k above highest base 40.1k). CodeTriage d1868f8634 (script/corpus, Ruby 4.0.7, SEED=1234): lowrail-profile 0.1.0.rc1 built from Lowrail 106ebd27 (sha256 c4a3a7c3), hashie 5.1.0 as a path gem with only mash.rb changed (hm1/hashie-5.1.0-head.diff; the 5.1.0 code has the same three lines); 222 runs, 0 failures in plain, base, aa and head, outcomes identical in base/aa/head (plain lacks one line only because a git clone message splits it); compare exit 0, 0 regressions, 15 improvements (13 actions -39 to -47 objects, both lines 21.78 to 0). Huginn and Forem not rerun: no checkouts in this orb. CHANGELOG: not in the commit, because on master any entry under Unreleased fails spec/release_preparation_spec.rb:23 and :47 (checked with a dummy entry on master: 3 examples, 2 failures); CONTRIBUTING wants the entry with the PR number, so it goes in once the PR exists, and the PR has to say that spec breaks. Awaiting thermos-sol."
ownership: {date: 2026-11-26, checked: ["open PRs naming respond_to_missing?, _method_suffix, _log_collision? that change lib/hashie/mash.rb"], hits: []}
passes: []
---

# Write new Mash keys without allocating in respond_to_missing?

Every write to a `Mash` checks whether the key collides with a built-in method, through `respond_to?`. For a key that isn't set yet, that goes through `respond_to_missing?`, which collected its arguments into an array and took the key's suffix from `Symbol#to_s`, a new String each time. The collision check then built a name and suffix pair, although it only needs the suffix.

This reads the suffix from `Symbol#name`, as `convert_key` does since #613, takes `include_private` directly as `Clash`, `Rash` and `MethodAccess` already do, and has the collision check ask only for the suffix. A new symbol key is now written without allocating.

```ruby
require "benchmark/ips"
require "hashie"
require "json"

Hashie.logger = Logger.new(nil)
payload = JSON.parse(File.read("repo.json")) # a GitHub repository response: 24 keys, an owner object, two licenses

Benchmark.ips { |x| x.report("Mash.new(api_response)") { Hashie::Mash.new(payload) } }
```

Ruby 4.0.9 with YJIT, best of three runs:

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(api_response)` | 39.3k i/s | 47.3k i/s | +20.3% |

Building that Mash allocates 101 objects on master and 21 on the branch.

## For Thomas

The fix in one sentence: every Mash write asks `respond_to?` whether the key shadows a method, and for a new key that question allocated an argument array and a copy of the key's name; now it allocates neither.

The one visible difference: calling `respond_to_missing?` directly with one or three arguments. Master accepts any count after the name (`*args`), so one argument raised ArgumentError only because `super` then got too few, and three returned true for a known key. The branch has Ruby's own signature `(name, include_private = false)`, the one Clash, Rash and MethodAccess use. Ruby always passes two. The alternative that keeps `*args` saves the String but not the Array (1 object per new key instead of 2).

Before opening: the CHANGELOG entry goes in with the PR number (`* [#NNN](https://github.com/hashie/hashie/pull/NNN): Write new Mash keys without allocating in respond_to_missing? - [@thomasklemm](https://github.com/thomasklemm).` under Changed), and `thomasklemm` into `.spellcheck.txt`. On master that entry makes `spec/release_preparation_spec.rb` fail (two examples), since the spec copies the real CHANGELOG and expects only placeholders; no contributor PR has added an entry since the release automation landed, so this is the first one to hit it. The PR body should say so in a sentence, or dblock fixes the spec first.

The body's script reads a `repo.json` file; the measured payload is in `bench/upstream/oss_profile_sweep_1/hm1_body.rb`. The ips numbers have ±5-10% per report, but the branch was ahead of both base runs in every round.
