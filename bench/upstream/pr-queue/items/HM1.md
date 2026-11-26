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
passes:
  - {reviewer: thermos-sol, head: "5a63e912442b8c2713fc09f9e52e3d6aba6d01f8", date: 2026-11-26, orb: T-01a21529-0776-7291-92a5-ebc2bd66d658, verdict: changes, open: "R1 remove the allocation spec; R2 add the changelog before opening and isolate the release fixture; R3 inline the measured benchmark payload; R4 label interpreter allocations; R5 correct the native-hook arity explanation"}
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

### Thermos-sol review — 2026-11-26

**Verdict: changes.** Reviewed Hashie `37454e149e4e7b88ae87cd1878f95519553fd33a` → `5a63e912442b8c2713fc09f9e52e3d6aba6d01f8`, including its commit message, and this item's metadata, note, proposed upstream body and For Thomas text as recorded at Lowrail `edf4b982`. The original text above is deliberately unchanged so the findings have an exact target; this report supersedes its “Awaiting thermos-sol” status. Both Thermos rubrics were applied by the same reviewer in this thread, as requested, without subagents or other threads; this is not a claim of two independent reviewers. Line references below use those reviewed revisions.

#### Open findings and exact fixes

**R1 — P2, remove the implementation-count spec.** Hashie `spec/hashie/mash_spec.rb:849–859` asserts `GC.stat(:total_allocated_objects) == 0`, not a user-visible result. It matches nearby upstream allocation tests and correctly fails on base (200 instead of 0), but Lowrail's explicit upstream-test rule in DECISIONS forbids adding allocation-count assertions. The added `# warm up` comment is also redundant with the code. Smallest fix: delete that entire new `it 'are written as new keys without allocating' ... end` block, leaving the existing symbol-key behavior spec unchanged. Keep the allocation evidence in the benchmark, not another helper or a replacement implementation-count assertion. No library restructure is needed.

**R2 — P2, do not defer the required changelog or plan to open with a known-red suite.** Item `note` at line 21 and For Thomas line 57 misread CONTRIBUTING: “Update Changelog” precedes “Make a Pull Request”; “Update CHANGELOG Again” adds the PR number afterwards. Add this exact unnumbered entry under Hashie's `CHANGELOG.md:17` (`### Changed`), keeping its placeholder, and add `thomasklemm` to `.spellcheck.txt`:

```markdown
* Write new Mash keys without allocating in respond_to_missing? - [@thomasklemm](https://github.com/thomasklemm).
```

The underlying release-spec coupling is real, but the claimed failure count is not correct for this entry: under Changed it causes **3 examples, 1 failure**, only the placeholder-only example at `spec/release_preparation_spec.rb:47`. The publishing example at line 23 passes. Other entry categories can additionally invalidate its category expectations; “any entry fails both” is false. A tested, small prerequisite fix is to insert these four lines in `spec/release_preparation_spec.rb:18`, immediately after `project.copy_files(...)` and before `project.configure_workflow(...)`, so each release test starts from its own placeholder-only Unreleased fixture rather than the pending contribution entries:

```ruby
path = File.join(project.checkout, 'CHANGELOG.md')
changelog = File.read(path)
pending = described_class::CATEGORIES.map { |name| "### #{name}\n\n* Your contribution here.\n\n" }.join
project.write('CHANGELOG.md', changelog.sub(/^### Added\n.*?(?=^## \[6\.0\.0\])/m, pending))
```

This retains the existing release history and all placeholders. With the new Changed entry present, this fixture fix gives **3 examples, 0 failures** and its file passes RuboCop. It was tested only in a disposable base worktree, not added to the fork. Fix this prerequisite before opening (or wait for an upstream fix); no unsolicited upstream report is authorized. Replace the note's CHANGELOG clause and the For Thomas changelog paragraph with: “Before opening, add the unnumbered CHANGELOG entry under Changed and `thomasklemm` to `.spellcheck.txt`, and isolate the release spec's Unreleased fixture. The entry currently fails only the placeholder-only example. Add the PR number after opening.” The eventual body should not announce a known failure that can instead be fixed before submission.

**R3 — P2, make the posted benchmark reproducible.** Item body line 38 reads an absent `repo.json`; the For Thomas explanation and Lowrail-only payload are stripped before posting. A maintainer cannot reproduce this workload from the body. Its two-license payload is a hand-built repository-shaped fixture, not a supplied real GitHub response. Smallest exact fix: replace that line, including its comment, with the following literal payload from the measured `hm1_body.rb` (only `PAYLOAD` renamed to `payload`):

```ruby
payload = JSON.parse(<<~JSON)
  {"id": 1296269, "node_id": "MDEwOlJlcG9zaXRvcnkxMjk2MjY5", "name": "Hello-World", "full_name": "octocat/Hello-World",
   "private": false, "description": "This your first repo!", "fork": false, "url": "https://api.github.com/repos/octocat/Hello-World",
   "homepage": "https://github.com", "language": null, "forks_count": 9, "stargazers_count": 80, "watchers_count": 80,
   "default_branch": "master", "open_issues_count": 0, "is_template": false, "topics": ["octocat", "api"],
   "has_issues": true, "has_wiki": true, "archived": false, "disabled": false, "pushed_at": "2011-01-26T19:06:43Z",
   "owner": {"login": "octocat", "id": 1, "avatar_url": "https://github.com/images/error/octocat_happy.gif",
             "gravatar_id": "", "type": "User", "site_admin": false, "url": "https://api.github.com/users/octocat",
             "html_url": "https://github.com/octocat"},
   "licenses": [{"key": "mit", "name": "MIT License", "spdx_id": "MIT", "node_id": "MDc6TGljZW5zZTEz"},
                {"key": "apache-2.0", "name": "Apache License 2.0", "spdx_id": "Apache-2.0", "node_id": "MDc6TGljZW5zZTI="}]}
JSON
```

Do not silently substitute a smaller fixture and retain these numbers. The prose stays short; the benchmark needs its actual input.

**R4 — P2, name the allocation mode.** Item body line 49 immediately follows a YJIT-only result, but 101 → 21 are the interpreter counts. The raw YJIT counts are 104.963 → 24.963, rounded 105 → 25. Replace the sentence with: “Without YJIT, building that Mash allocates 101 objects on master and 21 on the branch.” In `impact`, likewise replace “101 to 21 objects on Ruby 4.0.9,” with “101 to 21 objects on Ruby 4.0.9 without YJIT,”. Both interpreter and YJIT object-worker replays confirmed the respective rounded values and the 80-object saving; this is a mode-label correction, not a disputed benefit.

**R5 — P3, correct the callback explanation.** For Thomas line 55 calls `(name, include_private = false)` “Ruby's own signature”. Native `Object#respond_to_missing?` requires exactly two arguments (`parameters == [[:req], [:req]]` on Ruby 4.0.9), which is why the old missing-key one-argument call raises in `super`. Also, old one-argument calls for stored keys or recognized suffixes already return true. Replace the first five sentences of that paragraph, through “Ruby always passes two.”, with: “The observable argument-count differences are direct calls to `respond_to_missing?`: missing unsuffixed keys called with one argument now return false rather than raising; direct calls with more than two arguments now raise. Stored keys and recognized suffixes already returned true with one argument. The branch uses the conventional Ruby-defined hook signature `(name, include_private = false)`, matching Clash, Rash and MethodAccess; Ruby's `respond_to?` passes two arguments. Native `Object#respond_to_missing?` itself requires exactly two.” Keep its final sentence about the one-object `*args` alternative. This is a factual record correction, not a request to restore the splat.

#### Correctness, compatibility and maintainability conclusions

The three implementation-line changes are acceptable for Ruby's callback protocol. `respond_to?` and `method` use two arguments, the optional `include_private` value reaches implicit `super`, and both subclass forwarding shapes (`super` with `*args` and `super(name, priv)`) preserve normal results. The one-/three-argument differences are real but outside the two-argument callback protocol; no inspected Hashie caller or dependent relies on them. This is not a claim that no application anywhere calls the exposed method directly. Do not claim literal all-arity equivalence or native-signature identity.

`Symbol#name` does produce a frozen whole name, but `_method_suffix` never returns that whole name: it returns nil or `name[-1]`. On both Ruby 3.0.7 and 4.0.9 the latter is a fresh **mutable String**, with the same value as before, including Unicode prefixes; `end_with?` does not mutate it. Public hook results remain booleans, and the separate `convert_key` hook already used `Symbol#name` before this change. String, frozen String, String-subclass and duck-typed suffix inputs preserve results in the probes. Normal writes pass a Symbol to `_log_collision?`, so dropping the unused name-and-suffix pair preserves warnings and avoids an unnecessary full-name operation. Private-helper overrides and global core-method redefinitions are outside the accepted compatibility boundary; no new defensive wrapper is warranted.

Read Hashie's `lib`/spec callback callers, StrictKeyAccess, PermissiveRespondTo and MethodAccess, and inspected current OmniAuth (`beebfc6b34aad6c74d452148f5eb62e93af06c5b`), omniauth-github (`f27bb4e018150d87e9444ad13955acfc9e76f4d7`) and Grape (`b8fad3963958e5a2fb6bb1462309edf36f250a1e`) source for direct hook/helper use: none found in their library code. OmniAuth's `KeyStore < Hashie::Mash` disables collision warnings and adds no callback override; the real `AuthHash`/`InfoHash` conversion, dynamic predicates, name fallback and validity probe agree on base/head. These are source inspection and targeted execution, not full dependent-suite runs.

Maintainability: the change keeps behavior in its canonical helpers, removes an unused pair instead of adding a layer, adds no configuration, and introduces no structural or file-size regression. The Symbol guard follows `convert_key` and retains the non-Symbol conversion path. There is no justification for extracting a generic key adapter or restructuring Mash for this three-line change. The new allocation-count spec is the maintainability/policy issue (R1); existing behavior tests already cover new symbol-key access. No introduced security issue was found.

#### Executed checks and evidence audit

* On Ruby 4.0.9, `CI=true RUBYOPT=--disable-error_highlight bundle exec rake spec` on the exact base and head: **1,075 / 1,076 examples, 0 failures**. `bundle exec rake rubocop` on head: **both scans (124 and 153 files), no offenses**.
* On Ruby 3.0.7 installed with mise, `CI=true RUBYOPT=--disable-error_highlight ruby -Ilib -Ispec -S rspec spec/hashie/mash_spec.rb`: **171 / 172 examples, 0 failures** on base/head. This oldest-Ruby run used directly installed RSpec 3.13.2, pending_for 0.1.29, SimpleCov 0.22.0 and ActiveSupport 5.2.8.1, not the full development bundle. It is not a rerun of the six-Ruby full-suite matrix claimed in the original note.
* `bundle exec ruby -I../hashie-base/lib -Ispec -S rspec spec/hashie/mash_spec.rb:849` from the head checkout: the new example fails on base with **expected 0, got 200**. Verified the loaded callback's `source_location` is the base checkout; head's full suite and Ruby 3.0 Mash suite include the passing example.
* Ran `ruby -I CHECKOUT/lib bench/upstream/oss_profile_sweep_1/hm1_diff.rb` on base/head with **both 3.0.7 and 4.0.9**, compared using `hm1/fields.rb`: **9,140 rows per side**, only the recorded argument-count differences (784 one-argument and 7,190 three-argument row differences). Extra scratch probes cover mutable suffix return values, frozen/String-subclass/duck inputs, a private method, superclass `include_private` forwarding, real OmniAuth auth hashes and 1 MiB suffixed symbols. Normal results agree. The older note's plain-suite clone-message explanation cannot be independently reconstructed from its truncated tail files.
* Replayed `script/upstream-bench --worker objects .../hm1_body.rb` on both exact checkouts with Ruby 4.0.9, interpreter and YJIT, base/head/base; also checked fixed-heap interpreter workers. Rounded counts agree: **101 / 21 / 101** without YJIT, **105 / 25 / 105** with YJIT. These direct `-I` worker runs differ from the recorded minimal Bundler harness by 0.002 objects per call, not by an object or by the saving.
* Independently recomputed Callgrind results from every committed trailing `totals:` line minus its N=0 control, divided by 2,000: interpreter base 576,411.731 / 576,411.778 and head 557,984.424 (**−3.1969%**, A/A rounds to **0.00%**); YJIT base 278,110.4115 / 277,968.89 and head 246,360.284 (**−11.3938%**, A/A **0.0509%**). No fresh Callgrind measurement was claimed.
* Reparsed the nine committed benchmark-ips logs: baseline bests 38,558 / 40,050, mean **39,304 i/s**; branch best **47,266 i/s**, **+20.2575%**, A/A **3.7961%**. Per-round improvements against the mean of that round's two bases are **13.3%, 21.9%, 26.7%**. Rechecked all **15** recorded YJIT windows (six Callgrind, nine ips): all **45** compile/block/invalidation counter pairs unchanged. Thus the body table's **39.3k / 47.3k / +20.3%** is supported by the raw record. These are audited prior timing results, not freshly rerun wall-time numbers.
* Decompressed all three CodeTriage profile captures and reran `ruby gem/exe/lowrail-profile compare BASE.json HEAD.json --aa AA.json`: **exit 0**, byte-identical output to committed `compare.txt`, **0 reported regressions / 15 improvements**. Capture metadata records both subrun exits zero. Base/aa/head outcome files are byte-identical (217 parsed lines each); plain has 216. Raw whole-request means are base **5,986.91 / 5,988.59**, aa **5,986.98 / 5,988.88**, head **5,943.97 / 5,944.63**; the reported **21.78 → 0** line deltas and rounded **−0.7%** whole-request effect agree. This is a reanalysis of the recorded CodeTriage run, not a fresh app run: CodeTriage, Huginn and Forem checkouts are absent here.
* Read CONTRIBUTING, release specs, workflow matrix, changelog and relevant prior commits/PRs; GitHub reads confirmed the exact fork head and upstream master, no open PRs, the two listed open issues, and no PR attached to this head. Nothing was posted, pushed or changed on either Hashie remote. Ruby 3.1–3.4 and JRuby were not rerun by this reviewer.

The three implementation lines can remain unchanged. R1/R2 require a new fork head and a confirming review before approval; R3/R4/R5 are item/body corrections. This review records findings only and does not apply those upstream or proposed-body fixes.
