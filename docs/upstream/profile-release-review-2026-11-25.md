# lowrail-profile 0.1.0.rc1: M5 Thermos review (2026-11-25)

**Verdict: changes requested; do not publish this candidate.** Packaging, the support-floor suite proof and
the counter checks passed, but the new write guard is bypassable, the older-Rails route fallback can enable a
lossy replay, and the newly documented exit-status guarantee is false. Fix those, correct the evidence claims
and strengthen the action-floor tests before a confirm review.

Both Thermos rubrics were applied by one reviewer, without delegation or additional threads: correctness and
security, then maintainability. This is a review record, not an implementation of the fixes or release approval.

## Scope and attribution

Reviewed only the profiler changes in `2c845e81..fd36835b` (`ad9d5269`, `fd36835b`) and
`ab657532..24a6d0b1` (`24a6d0b1`), on main at `24a6d0b138d3d316221a46eec7d6f9e4ba9e2f74`.
Intervening work was not treated as part of this candidate. The release plan, the 2026-11-25 decision,
AGENTS invariants, shipped README and report header were checked against the implementation and
[M4 receipts](../../bench/upstream/profile_release/2026-11-25/README.md).

Findings 1 and 2 concern new code. Finding 3 concerns a new public guarantee about pre-existing CLI behavior;
it is not attributed as a newly introduced execution regression. Finding 5 is a release-gate coverage gap, not
a defect in the current compare arithmetic. No upstream comments or releases were posted.

## Must-fixes and their smallest fixes

### 1. P1: validate the request actually sent, not the DSL verb

At `gem/lib/lowrail/profile_workloads.rb:42–57`, `get` is permitted without `--allow-writes`, but its `env:`
options can replace the wire method in `Workloads::MockClient`. A valid workload declaration:

```ruby
get "/probe", env: { "REQUEST_METHOD" => "POST" }
```

reached a POST-only controller action and wrote a marker **60 times without `--allow-writes`**, exiting 0.
This was reproduced from the installed gem on Ruby 3.3.14 / Rails 7.2.4 and Ruby 4.0.7 / Rails 8.1.4:
10 warmups plus 20 measured requests in each of two runs. Controls: an explicit `post` was refused with zero
writes; a normal JSON GET made zero writes. This is a transport option bypass, not arbitrary Ruby executed
by the workload file, and contradicts the advertised GET-only boundary.

**Smallest fix:** certify the normalized request's final method and method-control options before sending it;
reject overrides that make a permitted declaration a non-GET. Keep refusal of setup and explicit writes before
any request. Keep this profiler policy out of the census's intentionally writable behavior. Add a public CLI
regression test with GET and POST routes to the same path, checking zero POST effects without the flag and
the intended POST behavior with it.

### 2. P2: ambiguous route recovery must refuse on Rails before 8.1

`gem/lib/lowrail/profile.rb:219–226` takes the first route matching a pattern, controller and action. Those
fields do not identify a route when constraints/defaults differ. Reproduced on Rails 7.2 with:

```ruby
get "/probe(/:id)", to: "boundary#index", as: :first_probe,
  defaults: { id: "sentinel" }, constraints: { id: /sentinel/ }
get "/probe(/:id)", to: "boundary#index", as: :second_probe
```

The request `/probe/7` actually matches the second route. The fallback selects the first and emits an enabled
`get first_probe_path`, which generates `/probe` and loses `7`. The first route's default also hides the lost
optional parameter from `shape_of`'s lossy check. Rails 8.1's actual matched-route object selects the second
route and correctly comments the request out as lossy.

**Smallest fix:** use this fallback only when the candidate is unambiguous; otherwise omit the shape or keep
it disabled with a reason. Do not re-recognize routes by executing constraints, and do not load constants to
guess which route matched. Test overlapping routes with different defaults/constraints, not just resources.
An experimental label does not make an enabled, incorrectly reconstructed request exact.

### 3. P2: implement the newly promised child exit-status passthrough

`gem/README-profile.md:169` and release-plan guarantee 5 promise passthrough. At
`gem/exe/lowrail-profile:217–218`, a failed child only produces a warning; the wrapper then exits 0 when report
generation succeeds. A real request followed by `exit 7` gave `capture.json` exit statuses `[7,7]`, but the
installed CLI exited **0 on both support pairs**. Report-construction failure also unconditionally exits 1
at lines 187–191 instead of preserving a failed child's status.

**Smallest fix:** choose a deterministic failed child status, preserve it through report generation and return
it from the wrapper. Preserve signal failure too rather than treating its nil `exitstatus` as success. Test
the public CLI with a request and `exit 7`, plus a failing report path. Compare already rejects the failed
capture with exit 2; that does not satisfy the wrapper's independent passthrough promise.

### 4. P2: narrow the outcome/load-order and failure guarantees to the receipts

README guarantee 4 says per-test outcomes **and load order** were identical plain, listed-but-off and profiled
on all four apps and macOS. The receipts support a qualified statement:

* Most load-order controls use `off-env` (`bundle exec env COMMAND`), not direct `bundle exec COMMAND`.
  They exclude Lowrail, Bundler and RubyGems; CodeTriage additionally excludes 27 yard files. First-run
  differences are documented. Those exceptions cannot disappear from the public guarantee.
* CodeTriage prints observable per-test outcomes for 217 of 222 tests, not all 222. Suite-level success is
  established for the rest, but individual equivalence is not.
* The macOS Campfire artifact establishes suite/per-test outcomes and extension use, not loaded-feature order.
* Guarantee 6 says a counter that fails to build warns and leaves the app running. The install paragraph and
  implementation correctly say compilation failure aborts the profiler before launching the app. Build failure
  and a runtime load/hook no-op are different contracts.

**Smallest fix:** qualify guarantee 4 with the actual baseline, normalization and coverage, and remove macOS
load-order equivalence. Separate build refusal from runtime warning/no-op in guarantee 6. In the plan and
proof method, replace the non-working root command `gem build gem/lowrail-profile.gemspec` with a build from
`gem/` (`gem build lowrail-profile.gemspec`); the gemspec's relative file list is conventional and need not change.
Also update the plan's stale schema-1 wording to match the report's `meta.format == 2` contract.

### 5. P2 release-gate gap: test the independent action-floor terms

The current formula correctly uses the maximum of twice the measured noise, 0.1% of the larger action count
and 20 times `--min`, with a strictly-greater-than regression boundary. However, a scratch mutation setting
both `ACTION_SHARE` and `ACTION_MIN` to zero still passes **the entire profiler suite: 25 tests, 290 assertions**.
This plausible implementation would turn unchanged low-noise actions into false CI failures, defeating the
reason for the published action floor.

**Smallest fix:** extend public compare tests with flat captures where each term independently dominates:
base 1,000, head 1,019 versus 1,021 for the 20-object floor; base 100,000, head 100,099 versus 100,101 for the
0.1% floor. Include exact equality, a non-default `--min`, and a head-spread-dominant case. Assert CLI status
and the reported threshold independently of the implementation. Keep the existing invalid-evidence tests.
No algorithm rewrite is called for by this finding.

## What passed, and the limits of the evidence

### The archive contains exactly the profiler

Built from `gem/` using `mise exec -- ruby -S gem build lowrail-profile.gemspec --output PATH`, then inspected
`data.tar.gz` inside the archive and installed with `gem install --local` into isolated Ruby 3.3 and 4.0 homes.
The archive contains exactly 14 files:

* `lib/lowrail/{profile,profile_report,profile_compare,profile_workloads,profile_version,workloads,load_hooks,loaded_constant}.rb`
* `exe/lowrail-profile`, `ext/lowrail_profile/{extconf.rb,lowrail_profile.c}`
* `data/contributions-index.json`, `README-profile.md`, `LICENSE`

No lowering runtime, setup hook, compiler passes or Rust executable ships. No install-time extension or gem
dependency is declared. The ledger is dated `2026-11-25T12:35:41Z`, with 89 allocation-work entries
(61 merged, 28 open). The reviewed archive's SHA-256 is
`df543df744cc56ade168778c66e847266ebfad40903f377f3673729e800eba58`.
It differs from the M4 archive because the M4 documentation commit subsequently changed the packaged README.

The package test's spec/relative-require checks and installation-without-checkout checks passed. Listing the
gemspec loads no Lowrail feature. Profile proof and boundary reproductions used the installed `.gem`'s Ruby
files and C source, with no checkout `RUBYLIB` or pre-existing counter cache.

### The built gem completed a fresh support-floor proof

Generated a fresh Blog with `LOWRAIL_CORPUS_RUBY=3.3.14 LOWRAIL_RAILS=7.2.4 script/corpus real-blog NAME`.
Applied the already disclosed `params.expect` to `require/permit` prerequisite before the plain run; without it
the generated app fails without Lowrail too. Added only the profiler gem to its separate Gemfile.

Plain, listed-but-off and all six runs of three installed-gem invocations each produced **21 tests,
46 assertions, zero failures/errors/skips**, with identical per-test outcomes. Every run counted 12 requests
and zero drops. File hashes outside `.git`, `tmp`, `log` and `storage` were unchanged. Independent
`compare BASE HEAD --aa BASE2 --json` exited 0. This fresh proof checks outcomes and source-tree preservation,
not a new independent loaded-feature-order comparison.

Separately, the installed CLI consumed the committed Blog receipts: unchanged head exited 0; planted head
exited 1 with just `output_safety.rb:228`, +1.6667 objects/request against a 1-object floor. A mismatched seed
and failed-child reports independently exited 2. This planted comparison reused M4's reports; it was not a
new planted capture. Compare's no-A/A mode is diagnostic and deliberately exits 0, as documented.

### Both local profiler test runs passed

From `gem/`, using Ruby 4.0.7 / Rails 8.1.4, then `mise exec ruby@3.3.14 --` for Ruby 3.3.14 / Rails 7.2.4:

```sh
ruby -Ilib -Itest -e 'ARGV.select { _1.end_with?(".rb") }.each { require File.expand_path("test/#{_1}") }; ARGV.reject! { _1.end_with?(".rb") }' -- profile_test.rb profile_package_test.rb workloads_test.rb load_hooks_test.rb --verbose --seed=1729
```

Results: **25 runs / 290 assertions** on 4.0 and **25 / 287** on 3.3, both zero failures/errors/skips.
The Ractor fallback returned main=true and other-Ractor open=false on both versions. Literal rendering,
filtering, nested parameters and injection regression cases passed on both. No literal-rendering regression
was established. The safe loaded-constant lookup and Active Support on-load integration preserve the intended
lazy-loading boundary; the ambiguous route lookup is the exactness exception above.

### C and portability checks found no new memory defect

Inspected allocation/reallocation bounds, packed counters, VALUE marking, window reuse, reset, thread/fiber
ownership and main-Ractor gating. Built the installed source with clang 19 and UndefinedBehaviorSanitizer on
Linux. With default threads and again with `RUBY_MN_THREADS=1`, stress completed 1,000 request windows and
1,000 separate fiber-job windows, nested windows, GC compaction and 10,000 expected String allocations at
the tested site, with zero drops and no sanitizer diagnostics. Abandoning 1,100 windows retained 1,024 and
reported 76 drops. The `_GNU_SOURCE` redefinition warning was harmless. This is not an ASan run or proof of
memory safety for all inputs.

The supplied [CI run](https://github.com/thomasklemm/lowrail/actions/runs/45619157548) succeeded at exact head
`fd36835bf2f4bdf03f131da7fe29a644b0f83842`: nine Linux Ruby/Rails pairs, two macOS pairs and Ruby head each
ran all 25 profiler tests without skips; both full-gem jobs also succeeded. The separate
[macOS Campfire run](https://github.com/thomasklemm/lowrail-profile-ci-proof/actions/runs/45622936395) succeeded;
its downloaded artifact records `lowrail_profile.bundle`, identical 634-test outcomes with one skip and no
failures, five processes per run, 666 request / 16 job / 19 Cable windows and zero drops. The workflow/platform
uses Apple clang; the receipt does not retain the compiler command. No macOS machine was run in this review.

## README and header claim audit

All prose and table claims were checked; this groups neighboring sentences by their shared evidence.

| Claim group | Result |
| --- | --- |
| Opening: counts by request/job/mail/Cable, source line, app caller and ledger; not CPU/time/retained memory/SQL | Supported by implementation, suite tests and receipt reports. Main-Ractor-only and dropped/unfinished-window limits remain material; README discloses the former and compare rejects the latter. No claim of exclusivity over other profilers was found. |
| Install, support versions, first-run build cache, no lowering, off means off | Package and local support endpoints passed; matrix supplies the intervening pairs/macOS. `require: false` and lazy lookup are tested. Compilation refusal is described accurately here, unlike guarantee 6. |
| Commands, options, output-directory ownership, seed, two runs | Implementation agrees; existing output-owned run/report files can be replaced. Profiler output, explicit recording and the external counter cache are intentional writes, not application source edits. Child status is recorded, but not passed through (finding 3). |
| Reading tables: warm/all, nearest app caller, own, reach, dev/test classification, embedded jobs/mail, line prefixes | Implementation and recorded reports agree. Dev/test labels are heuristics, not a claim that all remaining work happens in production. |
| Ledger match and status labels | Bundled dated scope is explicit. M4 records 52 scripted live-diff matches, not manual review of five per app; that deviation from the plan is disclosed and does not establish broader coverage. No network fetch is needed by the installed profiler. |
| Compare validity, floors, exit 0/1/2, diagnostic mode and CI shell/pipefail | Current implementation agrees; installed-gem comparisons and invalid controls passed. Action-floor regression sensitivity is inadequate (finding 5). One A/A pair is correctly described as a sample, not a bound. |
| CI recipe and suite-run cost | Six suite runs for default base/base2/head. M4's linked positive and planted jobs used the unpacked built gem in a separate proof repository. That repository's unrelated generated-app CI failed, as disclosed; it is not silently counted as green. |
| Experimental record/workloads, filtering, real side effects and disposable services | Experimental labels and secret-filter warning are present. No application source rewrite is performed. GET-only safety and exact older-Rails recording do not hold in the reproduced cases (findings 1 and 2). The Ruby workload file is trusted application code, not a sandbox. |
| Guarantees 1–6 | Package/off/source preservation supported within named output/cache exclusions; guarantee 4 overstates normalized/partial evidence, 5 is false, and 6 conflates build refusal and runtime no-op (findings 3 and 4). |
| Troubleshooting and overhead | Receipt summary has counting overhead 4–9% and stack-walk overhead 31–87% of suite time across four apps. Those are not wall-clock costs: a complete two-run capture is 2.6–3.6× plain wall time. Full raw timing logs were discarded, so this review can cross-check the committed rounded summaries and method, not recompute precise percentages. |
| Report header, `profile_report.rb:447–462` | Correctly says objects, not time/retained memory or milliseconds. Command, first Ruby, observed Rails/environment, first-run kind counts/processes, number of runs, dated/off ledger and profiler version agree with generated reports. Table exposes dropped samples; unfinished-window warning and compare refusal prevent treating incomplete captures as valid evidence. |

## Maintainability verdict

Changes requested at the policy boundary in finding 1. A declaration-only guard duplicates the transport's
concept of a request and can drift from it; certify the final transport specification instead of accumulating
separate exceptions for each spelling of a write. Finding 2 similarly needs an explicit ambiguity refusal,
not another heuristic for route identity. Those are small boundary corrections, not reasons to rewrite the
shared workload system.

The explicit package allowlist and extracted `loaded_constant` source of truth are direct and cohesive.
The Ractor and literal compatibility changes remain local. No changed file crossed 1,000 lines (counter 650,
report 600, profiler 376, profiler tests 824); no additional structural blocker, wrapper layer or speculative
decomposition is justified. Fix and test the five items above, then confirm the exact rebuilt candidate.

## Confirm review: thermos-opus (2026-11-25)

**Verdict: nits; the five findings above are fixed.** This pass checked thermos-sol's list against the fix range
`c2e5c393..14579fb4`, only the profile commits (`b60a29e2`, `c65370c9`, `7e67b661`, `20049618`, `7b45ced2`, with
`e3a53f20`, `85c4fedc`, `b6276362` and `14579fb4` alongside). Main was at `b6109a84`, whose `gem/` is identical to
`14579fb4`. One reviewer applied both rubrics, without delegation. A parallel thermos-fable confirm covers the other list.
CI at `14579fb4` succeeded on all 14 check runs. Receipts:
[2026-11-25-confirm-opus](../../bench/upstream/profile_release/2026-11-25-confirm-opus/README.md).

**Gem.** Built from `gem/` at head: sha256 `324affa6…36f2d`, byte-identical to the builder's, 14 files. Installed with
`gem install --local` into fresh `script/corpus real-blog` copies on Ruby 3.3.14 / Rails 7.2.4 (the floor Blog, with
its `params.expect` patch) and on Ruby 4.0.7 / Rails 8.1.4. Each copy ran the builder's `rerun.sh` unchanged, and the
8.1 copy also ran the full floor proof. Results: 21 tests identical in all 12 setups on each Blog, trees unchanged,
every capture process equal to `off-env`. A/A exits 0, the plant exits 1 with only the planted lines, and `--seed 99`
exits 2. The local profiler suites passed with nothing skipped: 29 runs / 372 assertions on 4.0 and 29 / 369 on 3.3.

**Reverting each fix fails its new test** (on both Rubies unless noted):

| Finding | Repro from the review, installed gem | Mutation → the new test |
| --- | --- | --- |
| 3. Exit status | A failing suite exits 1 (runs `1 1`) and a `KILL`-ed one exits 137 (runs `137 137`), plain and profiled, on both Blogs. | Final `exit 0`; no-report `exit 1`; a signal as `exitstatus.to_i` → all fail. |
| 1. Write guard | Without the flag, `env: { "REQUEST_METHOD" => "POST" }` is refused before any request (3 → 3 articles). With `--allow-writes` it is sent as a POST (`#create` 20 windows/run, answered 422), and a `post` writes 3 → 63. | Guard line removed; `overridden` forced false; forced true → all fail. |
| 2. Routes before 8.1 | The review's overlapping routes: `/probe/7` is not recorded, and the unambiguous route is. Only the route table's pattern and defaults are read; no constraint runs and nothing is autoloaded. | `candidates&.first` → fails on 7.2. It passes on 8.1, as expected, because 8.1 uses its matched route; the CI matrix runs 7.2 and 8.0. |
| 5. Compare floors | — | `ACTION_MIN = 0`; `ACTION_SHARE = 0`; both; no head spread; `1 ×` noise → all fail. |

**Docs (finding 4).** Every changed README and plan sentence agrees with the receipts and code: the qualified
guarantee 4 (`off-env` baseline, exclusions, 217 of 222, macOS outcomes only), guarantee 6's split between build and
runtime, the exit-status paragraph, the new refusals, *Not compared*, the build from `gem/` and `meta.format` 2.
The fixes receipts' tables match this rerun, apart from database counts and seed-independent load-order detail.
The Spring sentence was not reproduced here.

**Nits, none blocking:**

* `test_a_failed_command_fails_the_profile`'s `first` case cannot tell the first failing run from the last, because
  only run 1 fails: `statuses.reverse.find` passes it. Smallest fix: run 2 exits 4, and expect 3.
* The `--record` failure path (`exit(failed || 1)` after a report) has no test.
* The guard certifies each declaration. Block and `alternate:` turns change only path and params. A `_method` smuggled
  through a form-typed JSON GET body or an alternate's params did not reach another action, because Active Support
  escapes `&` in JSON. That is a hypothesis about other encoders, not a reproduced bypass.

**A/A recommendation.** On the 3.3 / 7.2 Blog, across 12 unchanged captures and every assignment of base, A/A and
head, the default (one A/A pair, 6 suite runs) fails an unchanged head 4.5% of the time. The cause is
`uri/common.rb:394` (14.25–21.75) and once `set.rb:512`. Two A/A pairs (8 runs, always) reach only 1.4%.
Re-capturing head **only when compare exits 1**, and failing only if that second comparison also exits 1, reaches
0.4%. It costs nothing on a green run, and every plant was still caught (132 of 132 assignments with the default,
264 of 264 with the confirm). On 4.0 / 8.1 no strategy flagged an unchanged head. Recommendation for 0.1: keep one
A/A pair as the default, and make the README's CI job a confirm step instead. On exit 1, profile head once more
into `head2` and fail only if `compare base head2 --aa base2` also exits 1. Say in the README that a single
unconfirmed failure is a place to look. That is a docs-only change and needs no new option; a pooled `--head2`
can follow later.

## Last fix round confirm: thermos-opus (2026-11-25)

Scope: the profile changes in `c7d3d4a2..c6250062` (`a28c9f0f`, `dcce21eb`, `61e2057c`, `1530feeb`, `ae445174`,
`758c1d26`, `737b2df3`, `c6250062`), checked against the nits of the two confirms above and in
[profile-release-astra-review-2026-11-25.md](profile-release-astra-review-2026-11-25.md). CI on `c6250062`: 14 of 14
checks green. **Verdict: no must-fix. The 0.1.0.rc1 gem with sha256
`f569d5f5ebbf20902d4cdc84dc7fc5e7b895efd2b90988cd6e16898de0a86d31` is the one to publish.**

**Each fix, and its revert.** The profile suites, run as CI runs them on Ruby 4.0.7 / Rails 8.1.4, gave 30 runs, 388
assertions, 0 failures and 0 skips. Every revert or mutation below fails its test:

| Item | Change | Revert or mutation → result |
| --- | --- | --- |
| 1. `-I#{lib}` in RUBYOPT | Added beside RUBYLIB when lib has no whitespace | Drop it → `test_a_child_with_its_own_rubylib_loads_the_profiler` fails (`LoadError`, child exits 9) |
| 2. Counter sources | `Dir.children`; package test home `space [home] {x}*` | Back to `Dir["#{source}/*"]` → package test fails (counter build fails) |
| 3. Exit status | Run 2 exits 4, expected 3 | `statuses.reverse.find` → fails (expected 3, actual 4) |
| 3. `--record` failure | Passing command → 1, failed → its status | `exit 1` → fails (7 expected); `exit(failed \|\| 0)` → fails (1 expected) |
| 3. Lost action row | One of two rows removed → exit 2 | Refuse only an empty list → fails ("one action row lost", 0) |
| 3. Compare file | Tests moved to `profile_compare_test.rb` | `ci.yml`'s profile job lists it |
| 4. Line floor | `[2 * noise, min].max` | Back to `[noise, min].max` → floor-terms and A/A tests fail |
| 4. CI confirm step | Head profiled again on exit 1 | Drop the `status = 1` guard, the `\|\| status=$?` or the second compare → the documented-step test fails each time. `docs/profile.md` has the same YAML. |
| 5. Write guard sentence | Requests checked as declared | Matches `Workloads::Request#copy`: an override sets only `path:` and `params:`, and `perform` sends the declared verb and headers |

**False alarms, replayed** with the retained `scripts/gate.rb` and the gem's `lib` at `c6250062`:

* Blog (the 12 unchanged and 3 planted floor-Blog captures of the M4, fixes and confirm-opus receipts): byte-identical
  to `gate-blog-floor.txt`. One compare is 22 of 1,320 (1.67%), the combined gate 4 of 11,880 (0.03%), the plant 396 of
  396 and 792 of 792. rc1 reproduces 60 and 48.
* Fresh app (24 captures): 100 of 12,144 (0.82%) and 400 of 255,024 (0.16%). All failures are
  `journey/path/pattern.rb:77`. The per-capture warm values match the README's two groups of five, so 5 × 4 × 5 = 100.
* Campfire, CodeTriage and Lobsters: identical to their `gate-*.txt`. Plants are caught 12 of 12 in both modes, and
  there are no unchanged-head failures.
* `gate.rb`'s `Gate` subclass only skips the file reading in `ProfileCompare#initialize`. The real
  `lowrail-profile compare` CLI on the first 199 Blog assignments exits 1 three times, consistent with 1.67%.

The README's numbers (1.7% → 0.03%, 4 of 11,880; 0.8% and 0.16% from one line; every plant caught in both profiles of
head on four apps) and `docs/profile.md`'s Blog sentence agree with these numbers.

**The gem.** `c6250062` changes only `bench/`. `gem build lowrail-profile.gemspec` at `737b2df3` and at `c6250062`
gives byte-identical archives, sha256 `f569d5f5…a86d31`, as the receipt states. No rebuild or floor-Blog rerun was
needed.

**Nits, none blocking:**

* `gate-fresh-81.txt` prints one decimal (`0.8%`, `0.2%`), and the committed `gate.rb` prints two (`0.82%`, `0.16%`). The
  file came from an earlier revision of the script. The counts are the same.
* `blog-floor/` does not record which gem file was installed (`installed-from.txt` is a path). Only the receipt
  README ties it to `737b2df3`. That is harmless here, because both builds are identical.
* `docs/profile.md` quotes only the Blog's rates. The README also gives the fresh app's 0.16%.

## Post-field-test review: thermos-opus (2026-11-25)

Scope: the lowrail-profile changes in `687f168b..1618fc38` (`8e36ae06`, `a4bc8d5a`, `dbe31072`, `9683fcf4`,
`90ef44e3`, `9736c860`, `abf515d3`, `1618fc38`), both Thermos rubrics, run independently of thermos-fable's pass.
**Verdict: not ready to publish. Five must-fixes, each small. Nothing in the range changes a profiled app's
per-test outcomes or load order on the floor Blog, and TSV format 3 is written and read consistently.**

**What ran.**

* Gem: `gem build lowrail-profile.gemspec` from `gem/` at `1618fc38`, sha256
  `e5b8991d963ebd1bf5e4c984c236c821becea0bb9a62506f088bc5cc6b4ca4b5`, as stated.
* Profile suites as `ci.yml` runs them: Ruby 4.0.7 / Rails 8.1.4, 35 runs, 1,128 assertions, 0 failures, 0 skips;
  Ruby 3.3.14 / Rails 7.2.4, 35 runs, 1,068 assertions, 0 failures, 0 skips (rspec-core installed, so the rspec half
  of the child-environment test ran).
* Floor Blog (`LOWRAIL_CORPUS_RUBY=3.3.14 LOWRAIL_RAILS=7.2.4 script/corpus real-blog`, the three `params.expect`
  rewrites, installed from the gem above) through `2026-11-25/scripts/proof.sh` and `controls.sh`: plain, off,
  off-env, profiled, base2, head, planted, seed99 all exit 0 with 21 identical outcomes (21 runs, 46 assertions, 0
  failures); the tree is unchanged by every capture; `run1/` and `run2/` are gone after each capture. compare
  `--json`: head exit 0 (`aa: true`, nothing listed), planted exit 0 listing only `output_safety.rb:228`, seed99
  exit 2 (seed differs). Load order: every suite process of every capture is identical to the `bundle exec env`
  control, seed99's are the same set in another order. Raw scratch under `.amp/in/orb-backup/opus-review/` (not
  committed).
* `features_cmp.rb` alone reported nothing here (`base off-env: 1 processes` and no capture rows): `dump_features.rb`
  names its file from `ENV["LOWRAIL_PROFILE"]` at exit, which `leave_env` now deletes, so the `run*-PID` filter
  matches no file. The comparison above was redone over every file. Receipt scripts that rely on it now pass
  vacuously; capture the variable at load in `dump_features.rb`.

### Must-fix

1. **`--timeout` skips KILL when the leader exits on TERM** (`9736c860`, `exe/lowrail-profile` `waiter.join(10) ||
   (stop.("KILL"); …)`). A grandchild that ignores TERM survives: leader `spawn(ruby -e 'trap("TERM"){}; sleep
   300')` under `--timeout 1` exits 124 after 3 s and the grandchild keeps running (re-parented to 1, still in the
   group). It can also write a TSV into `run1/` while the report is built or the directory deleted. Smallest fix:
   `stop.("TERM"); waiter.join(10); stop.("KILL"); waiter.join` (ESRCH already rescued). The test only covers a
   leader that ignores TERM; make its grandchild ignore TERM too, and bound the CLI call with a deadline: with
   `pgroup: false` or without KILL the test hangs instead of failing (both mutants hung).
2. **run*/ deletion globs `--out`** (`90ef44e3`, `Dir[File.join(out, "run*")]`; also `report`'s
   `Dir["#{dir}/run*/"]` and the older `ProfileReport#initialize`). Verified on the Blog: after a `--keep-runs`
   capture in `/tmp/g/keep`, a capture with `--out '/tmp/g/{keep,x}'` deleted `keep/run1` and `keep/run2` and left
   its own `run1/` `run2/`; its report was built from `keep`'s runs. `out` is `File.expand_path`ed, so a `[`, `{` or
   `*` anywhere in the checkout path is enough. Smallest fix: `Dir.children(out).grep(/\Arun\d+\z/)` (joined to
   `out`) in all three places, as the counter sources already do.
3. **`leave_env` does not reach Bundler's saved environment** (`dbe31072`). `Bundler::ORIGINAL_ENV` is taken when
   Bundler loads, before `leave_env`. After `leave_env`, a plain `system` child sees no profiler, but children under
   `Bundler.with_original_env` or `with_unbundled_env` (the usual way an `after(:suite)` or an engine starts another
   bundle) get `LOWRAIL_PROFILE*`, `SEED`, `SPEC_OPTS`, `RUBYOPT` back and load the profiler (`profiler="constant"`).
   Guarantee 1 as written does not hold for them. Smallest fix: run the same edits on `Bundler::ORIGINAL_ENV` when
   defined (a plain unfrozen Hash on Ruby 4.0.7's Bundler), and on `ENV["BUNDLER_ORIG_RUBYOPT"]`/`["BUNDLER_ORIG_RUBYLIB"]`;
   extend the child-environment test with a `Bundler.with_original_env` child.
4. **The README CI job stops on a failing suite** (`1618fc38`, README *Compare*). lowrail-profile exits with the
   suite's status, so under GitHub's `bash -e` the Profile step fails and Compare and the artifact upload are
   skipped. "A failing suite makes compare exit 2, which the summary shows" is false as written. The Compare line
   itself is right (exit 2 reaches the summary and the step exits 0, checked under `bash -e`). Smallest fix: add
   `if: always()` to Compare and upload-artifact (the job then fails red on the suite, which is a real error, and the
   summary still shows compare's exit 2), and say so; or drop the sentence.
5. **`docs/profile.md` still publishes the gate** (`1618fc38` added only a banner). Its CI YAML runs `[ "$status" = 1
   ] || exit "$status"`, which can no longer be reached, so the second head profile never runs; the prose says
   "compare exits 1 when anything grew", "a first exit 1 profiles head once more", and "ordinary command captures
   may have any number of processes", which `abf515d3` refuses. Smallest fix: replace the section's exit-1 prose and
   YAML with the README's *Compare* section (or a link to it) and keep the release-candidate numbers under a history
   heading.

### Should-fix

* **`ENV_KEYS` can drift from the exe's env hash.** Dropping `LOWRAIL_PROFILE_RECORD` or `_ALLOW_WRITES` from it
  passes every test. Let the exe pass its key list (one `LOWRAIL_PROFILE_KEYS` variable) and delete that list.
* **`HUP`/`QUIT` are not forwarded under `--timeout`**: with its own process group the command no longer gets the
  terminal's hangup, and a TTY read (`binding.irb`) stops it with SIGTTIN. Add `HUP` and `QUIT`; document that
  interactive debugging does not work with `--timeout`. The traps are also installed after `spawn` (small window),
  and not restoring them passes every test.
* **Exit 124 is not guaranteed**: with run statuses `[1, 124]` lowrail-profile exits 1 (first failure). Say "the
  first failing run's status, 124 for the run that timed out". `timed_out` is in capture.json but not report.json
  or report.md.
* **compare does not refuse a report of another version** (README claims it): `meta["format"]` is still 2, while
  `8e36ae06` changed app and path-gem keys, so base and head from different lowrail-profile revisions list key
  changes as regressions. Bump the report format or require equal `Lowrail::Profile::VERSION`.
* **The receipts' parallel cohorts no longer replay**: `gate.rb` and `options.rb` call `valid?`, which now refuses
  `fresh-81` (2 processes) and t3's parallel sets, against `1618fc38`'s "still reproduce their numbers". Skip only
  the process-count problem in those scripts, or note the gem they need.
* `test_compare_refuses_captures_of_parallel_workers` uses 8 processes; `> 1` mutated to `> 2` survives. Use 2.
* Gate leftovers in `profile_compare.rb`: the action floor's rationale (parallel workers) no longer applies to
  one-process captures, `@aa_given` duplicates `!@aa.nil?`, and the `processes == 1` check for workloads is now dead.
* Maintainability: the run loop has two inline spawn paths (`system` and spawn/detach/trap/deadline) and
  `interrupted` is set in only one; one `run(env, command, timeout:)` would hold the 124/128+signal mapping once.
  The TSV header literal `# lowrail-profile 3` and the run-directory pattern are written in several files.
  Several new comments run past one line of why.

### Notes

* The RSpec trigger checks that `RSpec::Core::Runner` is loaded, not that it has read `SPEC_OPTS`. rspec-rails and
  `rspec/core/rake_task` do not load it (checked); a rake parent that requires `rspec/core` before booting the app
  would leave the env early (hypothesis). `leave_env` never runs for Spring, plain `Minitest::Test` suites without
  `ActiveSupport::TestCase`, or processes started before `Minitest.run`; those keep the pre-range behaviour.
* The profiled main process and its forked workers keep profiling after `leave_env`: the output directory, app
  root and flags are captured at load. `profile_workloads.rb` reads `ENV["LOWRAIL_PROFILE"]` at the end; no
  trigger found, but a constant would remove the risk.
* Deletion never precedes data the report lacks: a failed report, a failed `--record` and a non-zero workloads run
  exit first; a timed-out or interrupted capture deletes only after the partial report.
* TSV format 3: `P` rows precede first use, including inside `@` rows; ids are per file. Format 2 runs are refused
  ("older lowrail-profile"). No other reader of the TSVs or of report.json's old `gate` key exists in `bench/`,
  `script/` or `fixtures/`.

### Mutants

21 of 27 killed. Killed: `leave_env` keeping `-rlowrail/profile` or lib, running before the seed is read, not
restoring `SEED`, dropping the RSpec guard; `--keep-runs` ignored, deleting before `--record`, the `report`
message; P ids off by one, P written per use, reader ignoring P; 124 → 143, INT not forwarded, no break after a
timeout; compare accepting several processes, exiting 1 on regressions, `aa?` always true. Hung, not failed:
`pgroup: false`, no KILL. Survived: KILL to the pid only, traps not restored, `ENV_KEYS` without `RECORD` or
`ALLOW_WRITES`, the Minitest < 5.24 prepend made a no-op (not reachable on the installed Minitest), `> 2` processes.
