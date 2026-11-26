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

## Post-field-test review: thermos-fable (2026-11-25)

Scope: the lowrail-profile changes in `687f168b..1618fc38` (`8e36ae06`, `a4bc8d5a`, `dbe31072`, `9683fcf4`,
`90ef44e3`, `9736c860`, `abf515d3`, `1618fc38`). One reviewer applied both Thermos rubrics, without delegation and
independently of thermos-opus's pass above, which was read only after this audit. Main has since moved to
`5cdc5669` (the report streams its runs); that commit is not reviewed here.
**Verdict: changes requested; do not publish this gem. Seven must-fixes, all small.** T2, T7's path table and run
deletion, the compare refusal and the report-only compare do what they say. T1, T4 and T8 each fail on a layout or
command an unfamiliar app is likely to have. Receipts, scripts and the verified fixes:
[2026-11-25-review-fable](../../bench/upstream/profile_release/2026-11-25-review-fable/README.md).

### What ran

* **Gem.** `gem build lowrail-profile.gemspec` in `gem/` at `1618fc38`: sha256
  `e5b8991d963ebd1bf5e4c984c236c821becea0bb9a62506f088bc5cc6b4ca4b5`, as stated, 14 files. The README's install
  line, run as written, builds the same archive and installs it.
* **Profile suites** as `ci.yml` runs them: Ruby 4.0.7 / Rails 8.1.4, 35 runs, 1,128 assertions; Ruby 3.3.14 /
  Rails 7.2.4, 35 runs, 1,068 assertions; 0 failures and 0 skips on both (rspec-core installed).
* **Every new test fails with its commit reverted.** For each commit, its tests ran against its parent's `lib`,
  `exe`, `ext` and README, on both pairs:

  | Commit | Tests | At the commit | On the parent's code |
  | --- | --- | --- | --- |
  | `8e36ae06` T1 | path gems and an engine root | pass | fails |
  | `a4bc8d5a` T2 | the *no runs* message | pass | fails |
  | `dbe31072` T4 | processes the suite starts | pass | fails |
  | `9683fcf4` CI fix | the same test (`-W0`, each suite ran) | pass | fails |
  | `90ef44e3` T7 | runs deleted unless kept; `--out` ownership | pass | both fail |
  | `9736c860` T8 | `--timeout` | pass | fails |
  | `abf515d3` | compare refuses parallel workers | pass | fails |
  | `1618fc38` | six compare and CI-step tests | pass | 5 fail, 1 errors |

* **Apps**, each with the built gem installed and `bundle exec lowrail-profile`: a fresh `rails new` app on Ruby
  4.0.7 / Rails 8.1.4.1 (Minitest, a scaffold, a job, a mailer); an RSpec app on Ruby 3.3.14 / Rails 7.2.4
  (rspec-rails, and rswag-specs as Dawarich has) whose `after(:suite)` starts rspec and rake again; and a copy of
  the fresh app with path gems inside and outside the root, through a symlink, a `git:` gem and the bundle in
  `vendor/bundle`.

### Must-fix

Each fix below is in [smallest-fixes.patch](../../bench/upstream/profile_release/2026-11-25-review-fable/smallest-fixes.patch)
(27 added lines, 12 removed). With it applied the reproductions below pass, and the patch also applies to main at
`5cdc5669`. On `1618fc38` plus the patch the profile suites pass on both pairs (35 runs, 0 failures, 0 skips). It
is a reviewer's patch, not a commit: none of it is in `gem/`, and it adds no tests.

1. **P1, T4 (`dbe31072`): the RSpec trigger fires in processes that are not running RSpec.** `leave_env` runs at
   `before_configuration` when `RSpec::Core::Runner` is *loaded*. A gem that requires `rspec/core` when the app boots
   is enough: with rswag-specs in the bundle, `bin/rails runner` already has the constant. Reproduced on the RSpec
   app, three ways:
   * `lowrail-profile -- bundle exec rake spec` counts nothing and exits 1 on a passing suite (*no runs with
     requests*, with the hint about controller specs). The rake parent drops the profiler before the suite starts.
     The exe before `dbe31072` counted 2 requests and exited 0, so this is a regression.
   * A Minitest file in that app ran with seeds 30185 and 32404 in its two runs while `capture.json` records seed
     1234: the seed is dropped before Minitest reads it, and compare's seed check then certifies a seed that was
     never used.
   * `--workloads` there writes no `measured.json` (the runner reads `ENV["LOWRAIL_PROFILE"]` after boot), so
     compare refuses the capture (exit 2). By the same reading `--allow-writes` is dropped too; that was not run.

   Smallest fix, one line: leave only when the app boots inside RSpec's runner,
   `caller_locations.any? { _1.path.to_s.end_with?("/rspec/core/runner.rb") }`. Then `rake spec` counts 2 requests,
   the Minitest file runs with 1234 twice and the workloads capture compares with exit 0. Test: the existing
   child-environment fixture with `require "rspec/core"` in `config/application.rb` and a Minitest suite.
2. **P2, T4 (`dbe31072`): Bundler's saved environment still holds the seed and the profiler** (also thermos-opus 3).
   `Bundler::ORIGINAL_ENV` is taken before `leave_env`, so a child started under `Bundler.with_unbundled_env` or
   `with_original_env` gets `SEED=1234`, `SPEC_OPTS=--seed 1234` and `LOWRAIL_PROFILE*` back; with a caller
   `SEED=99` it gets 1234. On the RSpec app a nested `bundle exec rspec` started that way printed *Randomized with
   seed 1234* and rewrote its tracked file in another order: the Dawarich defect, and guarantee 1 is false for
   it. Started with a plain `system` it ran in its defined order and the tree stayed clean. When lowrail-profile is
   not itself under `bundle exec`, such a child also loads the profiler. Smallest fix: make the same edits to
   `Bundler::ORIGINAL_ENV` when it is loaded, and to the `BUNDLER_ORIG_RUBYOPT`/`RUBYLIB` copies. With it the
   child's environment is the plain run's in both forms and the tree is unchanged.
3. **P2, T8 (`9736c860`): a hung worker survives `--timeout`** (also thermos-opus 1). `KILL` is sent only when the
   command's own process is still alive 10 s after `TERM`. On the fresh app with two parallel workers and a test
   whose worker does not exit on `TERM`, lowrail-profile exited 124 after 20.7 s and left `Rails test worker 0`
   running under PID 1. A hung worker is the Fizzy case the flag exists for. Smallest fix: wait up to 10 s for the
   *group* to end, then `KILL` it. With it the same run exits 124 after 30.8 s with nothing left, and a worker that
   does exit on `TERM` still ends the run in 20.8 s. The test needs a grandchild that ignores `TERM` under a parent
   that does not.
4. **P2, T1 (`8e36ae06`): path gems inside the root under `gems/` or `vendor/gems/` appear nowhere** (GitLab's
   layout). The counter does not treat such a file as an app line, but the report classifies anything under the
   root as `app` before it looks at the path gems. So the line is in no ranked row, under no app line, and not in
   *Not attributed* either: on the T1 app 17.2 objects per request are missing, and the header's "1.4% not
   attributed" leaves them out. Smallest fix: `classify` treats a path under the root as the app's only when the
   counter would (no `gems/` segment), and otherwise goes on to the path gems. With it both gems rank as
   `GEM/<name>/…` with `articles_controller.rb:7` as their caller, and that app line's warm objects go from 24.0 to
   63.7 per request, which is the sum of what it calls.
5. **P2, T7 (`90ef44e3`): the run deletion globs `--out`.** This is thermos-opus's finding 2, confirmed here: after
   `--keep-runs --out tmp/g/keep`, a capture with `--out 'tmp/g/{keep,x}'` deleted `keep/run1` and `keep/run2` and
   kept its own. This pass had tried only `[x]`, where the report fails before anything is deleted, as it did
   before the range. Fix as given there (`Dir.children`); it is not in the patch.
6. **P3, README (`1618fc38`): the CI job stops on a failing suite** (also thermos-opus 4). Run step by step under
   `bash -e`, the job succeeds for an unchanged head (0 regressions), for a planted one (3 listed) and with two
   workers (the refusal and *compare exited 2* in the summary). With a failing test on head it fails at *Profile
   head*, and Compare and the upload never run, so "a failing suite makes compare exit 2, which the summary shows"
   is not what the job does. Smallest fix: say that the job fails at its profile step, or add `if: always()` to
   the last two steps.
7. **P2, receipts: the Hackatime and Writebook captures are not in the repository.** The t3 README says the
   field-test threads commit them under `oss_profile_sweep_1/`; main has OSM's there and no others. The numbers the
   no-gate decision rests on (12.5%, 4.4%, plant found in half) match the committed `options-hackatime-serial.txt`,
   but the README's ranges (`Admin::AdminUsersController#index` 14,700–14,730 or 14,785–14,817; the plant's +40–60
   on about 7,900) cannot be checked or replayed. Smallest fix: commit each capture's `report.json.gz` as OSM's
   are, or correct that sentence and drop the ranges.

### Should-fix

* **A symlinked path gem is not classified.** Ruby names a required file by its real path, and the `G` row has the
  path Bundler was given. The report says so correctly (it is the *Not attributed* share). One line in the patch:
  write the real path.
* **`docs/profile.md` still shows the gate's CI job** (thermos-opus 5 ranks it a must-fix). Its YAML has no
  `PARALLEL_WORKERS: 1`, so on a parallel suite it exits 2. Replace it with the README's job or a link.
* **A child started while `test_helper.rb` loads is profiled and seeded** (Minitest reads `SEED` later); one started
  from `rails_helper.rb` is not. The README's "once Minitest or RSpec has read its options" covers it; name
  `test_helper.rb` there.
* **`--timeout` and a terminal.** In its own process group the command cannot read the terminal: under a pty,
  `--timeout 5 -- ruby -e 'p STDIN.gets'` took 15 s and needed `KILL`. Say that a debugger does not work with it.
* `DECISIONS` gives "1.7% with three base captures": that is the CI job with three base captures; one compare is
  3.3% (`options-hackatime-serial.txt`).
* `docs/profile.md` says paths were four fifths of Sure's TSVs; the 81% was measured on Campfire. On the T1 app
  the path table makes the TSVs 4.1–4.2 times smaller.
* `profile_test.rb` grew from 802 to 990 lines. The tests these fixes need belong in a new file, which `ci.yml`
  must then list.

### What passed

* **T1.** A path gem outside the root ranks as `GEM/outer/…` with its app caller. One under `engines/` is keyed
  `APP/engines/inner/…` and shown as the app's own line, as the counter attributes it. A `git:` gem ranks under its
  repository directory's name, as before the range. With the bundle in `vendor/bundle` the result is the same, and
  the profiler, itself a path gem there, stays unranked. A file in no gem is *Not attributed* with the right
  number: 20.46 objects per request, 38 per call in 7 of 13 requests.
* **T2.** Controller specs alone: exit 1 with the new message. A request spec with or without them: 1 request.
* **T4, plain children.** Fresh app: 18 tests with identical outcomes plain and profiled, in both runs, without a
  seed, with `SEED=99 SPEC_OPTS=--no-color`, and with two workers. RSpec app: 36 examples, identical. The tree
  changes only by `--out`, apart from must-fix 2. Children started from a test, from `Minitest.after_run`, from
  `after(:suite)`, from a worker's setup, a nested `bin/rails test`, `bin/rails runner`, rspec and rake see the
  plain run's environment. A non-Ruby child sees `RUBYLIB` unset where a plain run has it empty.
* **T7.** `--out` holds 1.95 MB with `--keep-runs` and 0.95 MB without. `report` from kept runs writes the same
  bytes; without runs it exits 1 and says why. The tree is unchanged.
* **T8, where `TERM` works.** Serial and with two workers, a test that hangs: exit 124 after 21 s for
  `--timeout 20`, `timed_out: [1]`, no second run, nothing left running. A serial hang that ignores `TERM` is
  killed after 30.5 s. compare refuses the capture (exit 2).
* **The README's numbers.** Every rate in *Why there is no gate* and *What it can find* matches `options-*.txt`.
  From OSM's committed captures the built gem gives 0 of 24 unchanged heads, the plant in 12 of 12 (+168.5 against
  26.6 of 26,402) and exit 2 for the 8-worker captures (8,063 and 26,106). Its logs give 81 s plain and 554–588 s
  per serial capture.

### Maintainability

No file crossed 1,000 lines and no rewrite is called for. Two places hold the same fact twice, and each produced a
finding. What an app line is lives in the counter (the root, less `gems/`, `test/` and `spec/`) and again in
`classify` (anything under a root): must-fix 4. What the command's environment is lives in the exe's hash and in
`ENV_KEYS` plus the two `RUBYOPT`/`RUBYLIB` edits in `profile.rb`; let the exe name what it set. "The suite has
read its options" is inferred from a loaded constant (must-fix 1); the stack check is still an inference, and
RSpec offers no hook that is cheaper. The run loop's two ways to start the command should become one function
that returns the status, so the 124 and 128-plus-signal rules exist once.

## Confirm of the review fixes: thermos-opus (2026-11-25)

Scope: `1618fc38..60387485` in `gem/`, docs/profile.md, the README, DECISIONS and the receipts: `5cdc5669`
(streaming report, reviewed in full), `9b31044c` (the fixes for both reviews' must-fixes and should-fixes, T9/T10),
`7a5ee0b6` (receipts) and `60387485` (the counter built outside the app's bundle; a symlinked path gem in the test).
Both Thermos rubrics, each earlier finding checked by reproduction against the built gem and by a mutant against its
test. Receipts: [2026-11-25-confirm-opus-2](../../bench/upstream/profile_release/2026-11-25-confirm-opus-2/README.md).
**Verdict: no must-fix. All five of my must-fixes are fixed, as verified by reproduction. Two of them lack a
regression test, so "each fix has a test that fails without it" does not hold; add the two tests below before 0.1
ships. The gem with sha256 `c4a3a7c3d7a7806e5a310fc23e2c006975ed4f20160508ab43caeda1d729df68` (60387485) is
otherwise ready.**

**What ran.**

* Gems: 7a5ee0b6 `6a807858…94470` and 60387485 `c4a3a7c3…29df68`, both as stated. The archive holds the 14
  profiler files, with no Lowrail runtime file.
* Profile suites at 7a5ee0b6, as `ci.yml` lists them: Ruby 4.0.7 / Rails 8.1.4, 38 runs, 1,166 assertions, 0
  failures, 0 skips; Ruby 3.3.14 / Rails 7.2.4, 38 runs, 1,107 assertions, 0 failures, 0 skips. At 60387485 the
  changed and neighbouring tests (`ProfileEnvTest`, `ProfileReportTest`, the path-gem and package tests) passed on
  both: 6 runs, 63 and 61 assertions.
* Floor Blog (Ruby 3.3.14 / Rails 7.2.4) from the 7a5ee0b6 gem: the earlier repros below, and the streaming report.

**Earlier findings, reproduced against the gem.**

| Finding | Reproduction at 7a5ee0b6 | Mutant against its test |
| --- | --- | --- |
| 1. `--timeout` skipped KILL when the leader exited on TERM | A leader that exits on TERM with a grandchild that ignores it: exit 124, the grandchild is gone | KILL only while the leader lives: killed |
| Exit 124 after an earlier failed run | Run 1 exits 1, run 2 hangs: exit 124, `exit [1,124]`, `timed_out [2]`, notice at the top of report.md and on the terminal, `meta.timed_out` in report.json | first failure wins: killed; no notice: killed |
| 2. run*/ deletion globbed `--out` | Blog: a `--keep-runs` capture in `/tmp/g/keep`, then `--out '/tmp/g/{keep,x}'`: `keep/run1` and `run2` stay, the literal directory's runs are deleted | glob back in the delete: **survived**; glob back in `ProfileReport`: **survived** |
| 3. Bundler's saved environment | Blog, an integration test starting a child plainly, under `with_original_env` and `with_unbundled_env`: identical to the unprofiled run (`SEED=7`, no profiler), the suite at seed 1234, both for `bundle exec lowrail-profile -- bin/rails test` and for `lowrail-profile -- bundle exec bin/rails test` | `ORIGINAL_ENV` not edited: killed; `BUNDLER_ORIG_` not edited: **survived**, though on the Blog in the second form it leaves `BUNDLER_ORIG_RUBYOPT=-I…/lib -rlowrail/profile` in the child |
| 4. README CI job | `if: always()` on Compare and the upload; the prose says the job fails on a failing suite and the summary still shows compare's exit 2 | checked by `test_documented_ci_compare_step_reports_and_never_fails` |
| 5. docs/profile.md gate | The section states 0.1 has no gate, links the README's *Compare*, keeps the release-candidate numbers under their own heading; no gate YAML is left | – |
| RSpec runner predicate | `caller_locations` includes `rspec/core/runner.rb` | back to `loaded_constant`: killed; never: killed |
| Report format 3 required by compare | A format 2 base exits 2 with "format 2, this lowrail-profile reads 3" | any format accepted: killed; `FORMAT = 2`: killed |
| `LOWRAIL_PROFILE_KEYS` | The exe lists its own keys, so the list cannot drift | keys not removed: killed |
| HUP and QUIT forwarded, traps before spawn | HUP is checked by the test | HUP dropped: killed; QUIT dropped: **survived**; pending signals dropped: **survived** |
| Path gem inside the app root, symlinked path gem | – | `gems/` as app: killed; no realpath: survived at 7a5ee0b6, killed at 60387485 |

**Streaming report (5cdc5669).** It reads each TSV line by line and keeps attributed rows as flat integer arrays,
keyed by interned window names and (path, line) ids, in first-seen order. The old code merged the same raw keys in
the same order, and the one `Array#sum` (unattributed) still sums an array, so every float sum and tie is unchanged.
The ids pack into `loc << 31 | caller` and `path << 32 | line`, which is safe below 2³¹ locations and 2³² lines.
Checked:

* On a kept floor-Blog capture, report.md and report.json from 1618fc38 and 5cdc5669 are byte-identical. At
  7a5ee0b6 report.md is identical, and report.json differs only by `meta.format`, `timed_out` and `timeout`.
  0.64 s and 39 MB before, 0.47 s and 28 MB after.
* A 471 MB set generated from that capture with the receipts' `gen.rb blog big 16 40` gives the same result:
  65.7 s and 1.70 GB before, 51.4 s and 235 MB after.
* `test_report_keeps_no_object_per_attributed_row`: the report holds 8,365 objects for 80,000 rows (bound 20,000).
  1618fc38's report holds 646,127 and fails the test. Making the attribution key `loc` alone also fails it.
* I did not rerun the builder's fresh-app, Campfire and Sure-sized captures; their sha256 are in
  `2026-11-25-stream/README.md`.

**The counter built outside the bundle (60387485).** `Bundler.with_unbundled_env` runs extconf.rb and make in
Bundler's saved original environment, without the bundle's additions. Built on the Blog under `bundle exec`
with a probe in the caller's RUBYOPT:

* extconf.rb still sees `CC`, `CFLAGS`, the caller's own RUBYOPT entry, an arbitrary variable and the original
  `PATH`.
* What is gone is only what the bundle added: `-rbundler/setup`, `BUNDLE_*`, `GEM_HOME` as `bundle exec` set it,
  and the bundle's bin directory.
* The Ruby is the absolute `RbConfig.ruby`, and the compiler and flags come from `RbConfig::CONFIG` or the
  caller's environment, so the bundle can choose neither, and nothing the build needs is lost.
* Without Bundler, or with a Bundler older than `with_unbundled_env`, it builds as before.
* Mutant: building inside the bundle again fails `test_the_counter_builds_under_an_apps_bundle`.

**Should-fix (tests only, before 0.1 ships).**

1. **A regression test for the glob deletion.** It destroyed another capture's data, and both glob mutants pass
   every test. Smallest test: a capture with `--keep-runs` in `dir/keep`, then one with `--out "dir/{keep,x}"`.
   Assert that `keep/run1` and `keep/run2` remain, and that the literal directory's report is its own (for example
   its `capture.json` argv).
2. **A test for the `BUNDLER_ORIG_` edit.** Run the child-environment test's command under `bundle exec` once (a
   Gemfile with no gems is enough), or set `BUNDLER_ORIG_RUBYOPT` to the profiler's RUBYOPT in its caller
   environment, and include `BUNDLER_ORIG_RUBYOPT` in what `child.rb` prints.

**Notes.**

* QUIT forwarding and the pending-signal replay have no test (both mutants survive). Both are small and correct by
  reading.
* The grace loop waits while `kill(0, -pid)` succeeds. A group holding only a zombie whose parent outlives the
  leader would wait the full 10 s before KILL (hypothesis; it only delays).
* An app file under a `gems/` directory (`app/models/gems/…`) is no longer an app line. The counter already skips
  such frames, so the two agree.
* `2026-11-25-stream/README.md` names `profile_test.rb` for the bound test, which 9b31044c moved to
  `profile_report_test.rb`.
* Maintainability: the exe's run loop now holds the grace loop as well, and several new comments are longer than
  one line of why. Neither blocks the release.

## Delta confirm 60387485..53a071fd: thermos-opus (2026-11-25)

Scope: `776ef498` (tests only: the `--out` glob, `BUNDLER_ORIG_RUBYOPT`, the ruby-head Gemfile, the stream README
path) and `53a071fd` (`--timeout` no longer waits for zombies in the stopped group). Receipts:
[2026-11-25-confirm-opus-2](../../bench/upstream/profile_release/2026-11-25-confirm-opus-2/README.md)
(`mutants-53a071fd.txt`, `ps-probes.txt`). **Verdict: no must-fix. The gem with sha256
`d1e80952de34d52850ff5b953111444525a61ef97da628b10ff094077d4ef3f5` (53a071fd, reproduced) is ready. One
should-fix in the `ps` fallback, below.**

* **The tests now catch their mutants.** At 53a071fd these mutants are killed:
  * the glob back in the exe's delete, and the glob back in `ProfileReport`
    (`test_runs_are_deleted_after_the_report_unless_kept`);
  * `leave_env` skipping `BUNDLER_ORIG_` (`test_processes_the_suite_starts_run_as_without_the_profiler`);
  * the build inside the bundle, with the ruby-head Gemfile that no longer pins a version
    (`test_the_counter_builds_under_an_apps_bundle`);
  * waiting with `kill 0` again, and counting zombies (`test_timeout_does_not_wait_for_a_zombie`);
  * a `ps` filter that never sees the group (`test_timeout_stops_a_hung_run_and_its_processes`).
* **The changed tests pass** (the env tests, timeout, run deletion, child environment): Ruby 4.0.7 / Rails 8.1.4,
  6 runs, 753 assertions; Ruby 3.3.14 / Rails 7.2.4, 6 runs, 698 assertions; 0 failures, 0 skips.
* **The zombie case reproduced.** Under a python3 subreaper that never reaps, a `--timeout 1` run took 11.1 s at
  60387485 and 1.1 s at 53a071fd.
* **`ps` parsing.**
  * `-o pgid= -o stat=` prints no header. The pgid is right-aligned, which `split` and `to_i` handle, and
    `to_i == pid` matches because the command leads its own group.
  * A zombie's state starts with `Z` (`Z`, `Z+`, `Zs`) in procps on Linux and in BSD ps on macOS, which both
    accept `-A` and `-o pgid,stat`; I did not run it on macOS. BusyBox 1.36.1's ps gives the same fields.
  * `ps` itself runs in lowrail-profile's group, not the command's.
  * Measured with a grandchild that cleans up for 3 s on TERM (`ps-probes.txt`): procps, BusyBox and a PATH
    without `ps` (the `kill 0` fallback) all wait for the cleanup and exit 124 in about 4.1 s.
* **No hang.** Every path ends at the 10 s deadline, then KILL. Only a `ps` that never returns could stretch it
  (hypothesis, not seen).

**Should-fix: a `ps` that runs but fails kills too early.** A `ps` that exits non-zero with no output (a
restricted `/proc`, a `ps` without `-A` or `-o`) makes `running` false at once. KILL then goes out right after
TERM, without the 10 s grace: the probe's cleanup was cut off at 1.1 s. That only cuts the TERM handling of a
run that already timed out, and never hangs. Smallest fix: fall back to `kill 0` when ps fails, for example
`out = \`ps -A -o pgid= -o stat=\`; next(Process.kill(0, -pid) rescue false) unless $?.success?` before parsing.

## Confirm of the review fixes: thermos-fable (2026-11-25)

Scope: `1618fc38..0ee4aed2` in `gem/`, docs/profile.md, the README, DECISIONS and the receipts: `5cdc5669`
(streaming report, reviewed in full), `9b31044c` (the fixes for both reviews, T9/T10), `7a5ee0b6` (receipts),
`60387485` (counter built outside the app's bundle; symlinked path gem in the test), `776ef498` (tests for the
`--out` glob and `BUNDLER_ORIG_RUBYOPT`), `53a071fd` (`--timeout` does not wait for a zombie), `c19ab7bb` (the
zombie test on Linux only) and `0ee4aed2` (the grace holds when `ps` fails). One reviewer applied both Thermos
rubrics, without delegation and independently of thermos-opus's confirms above; its first was read only after my
audit of `1618fc38..60387485`. The head moved three times during the pass, so each result names the gem it ran
with. Receipts: [2026-11-25-confirm-fable](../../bench/upstream/profile_release/2026-11-25-confirm-fable/README.md).
**Verdict: not yet; two must-fixes, one line and one sentence. All seven must-fixes of my first pass are fixed, as
reproduced on the apps below.** Both change the gem's bytes (`gem/lib`, the README), so the gem `57eb11b3…518d`
(0ee4aed2) is not the one to publish. Neither breaks an app or a capture: one misfiles an app's own lines in the
report, the other understates a limit in the README.

### What ran

* **Gems.** Built in `gem/` at `7a5ee0b6`, `60387485`, `53a071fd` and `0ee4aed2`: sha256 `6a807858…94470`,
  `c4a3a7c3…29df68`, `d1e80952…f3f5` and `57eb11b39028eb34fd9d86ebdd9dfc12f18edeab8d9beb5a886e40abc4ef518d`, each
  as stated, 14 files.
* **Profile suites** as `ci.yml` lists them, 0 failures, 0 errors and 0 skips in each:

  | Head | Ruby 4.0.7 / Rails 8.1.4 | Ruby 3.3.14 / Rails 7.2.4 |
  | --- | --- | --- |
  | `7a5ee0b6` | 38 runs, 1,168 assertions | 38 runs, 1,107 assertions |
  | `60387485` | 39 runs, 1,175 assertions | 39 runs, 1,114 assertions |
  | `53a071fd` | 40 runs, 1,181 assertions | 40 runs, 1,119 assertions |
  | `0ee4aed2` | 41 runs, 1,184 assertions | 41 runs, 1,122 assertions |

* **Apps** of the first pass, with each built gem installed and `bundle exec lowrail-profile`: the fresh Rails
  8.1 app, the RSpec app on Rails 7.2 with rswag-specs, the path-gem app (also with `vendor/bundle`), plus a copy
  of the fresh app with a `GemsController` and one of the RSpec app with Minitest 5.23.1.
* `gem/lib`, `gem/ext` and the README are the same from `9b31044c` to `0ee4aed2`. `gem/exe` changed three times
  after `7a5ee0b6` (the counter's build, and twice `--timeout`'s wait for the stopped group), and the `--timeout`
  runs were repeated at `53a071fd` and `0ee4aed2`.

### The first pass's must-fixes, reproduced again

| First pass | At the new head |
| --- | --- |
| 1. RSpec trigger wherever `RSpec::Core::Runner` is loaded | rswag-specs app: `rake spec` exits 0 and counts 2 requests; the Minitest file runs with seed 1234 in both runs; `--workloads` records `measured` [20, 20] and compare exits 0 |
| 2. `Bundler::ORIGINAL_ENV` kept the seed and the profiler | Children under `with_original_env` and `with_unbundled_env` are identical to the plain run's in both apps (no profiler, the caller's `SEED=99` or none); the RSpec app's tree is clean (`swagger/order_unbundled.txt` no longer changes) |
| 3. A TERM-ignoring parallel worker survived `--timeout` | Two workers, one ignoring TERM: exit 124 after 30.8 s, nothing left running, report with the *Incomplete* notice, `meta.timed_out` [1]; again at `53a071fd` and `0ee4aed2` |
| 4. Path gems under `gems/` and `vendor/gems/` appeared nowhere | Both are `GEM/…` rows with the controller line as caller; *Not attributed* is down to the loose file outside the root (20.46 objects per request, 0.6%). But see must-fix 1 |
| 5. Run deletion globbed `--out` | `--out 'tmp/g/{keep,x}'` leaves `tmp/g/keep/run1` and `run2` and deletes its own runs; `--out 'tmp/g/[x]'` now reports |
| 6. README CI job stopped on a failing suite | Run step by step, honouring `if: always()`: unchanged head 0 regressions, planted head 3, both green; a failing head or base fails the job, and Compare still writes *head's command exited [1,1]* and *compare exited 2*; two workers are refused |
| 7. Hackatime and Writebook captures not committed | In `2026-11-25-t3/census/`. Seven option sets replayed with main's `gem/lib` (Hackatime and Writebook serial and parallel, Writebook w4, Campfire serial, OSM serial): every `options-*.txt` byte for byte |
| Symlinked path gem (should-fix) | `GEM/linked/…` for both files; the test now has such a gem |

Per-test outcomes are identical plain and profiled in both apps (19 tests with and without a seed and with two
workers; 36 examples, 14 pending), and the tree is unchanged after every profile.

### Must-fix

Both fixes are in
[smallest-fixes.patch](../../bench/upstream/profile_release/2026-11-25-confirm-fable/smallest-fixes.patch)
(13 added lines, 10 removed, one test row included). It is a reviewer's patch against `0ee4aed2`, not applied to
`gem/`. With it the profile suites pass on both pairs (41 runs, 0 failures, 0 skips; 1,184 and 1,122 assertions).

1. **P2, regression from the fix for my must-fix 4 (`9b31044c`): an app file under a directory named `gems` is
   reported as outside the app.** `classify` now refuses the app root for every path with a `gems/` segment, not
   only for path gems. On a copy of the fresh app with a `GemsController`, `app/views/gems/index.html.erb` and
   `app/models/gems/ruby.rb` leave the app group: the report says *Not attributed: 114.33 objects per request
   (2.1% of all) are on lines outside the app, Rails, Ruby and the bundle's gems* and names both files by their
   absolute paths. At `1618fc38` they were `APP/…` lines. The regex is the one my first pass proposed, so the gap
   is mine. Smallest fix, one line: refuse the app root only when a path gem's `G` row covers the path
   (`&& path_gems.any? { |_, d| path.start_with?(d) }`). With it both layouts are right, and
   `test_a_path_gem_inside_the_app_root_is_a_gem`, given one such view, fails on `0ee4aed2`'s lib and passes with
   the fix. The counter still skips these frames as callers (the C rule since `8e36ae06`), as it did at `1618fc38`.
2. **P3, README: the difference between captures is understated against its own example.** *Captures taken at
   different times can drift by about 0.2% per action (Forem: `ResponseTemplatesController#update` 15,028 →
   15,155)*: that example is +126.1, or +0.84%, and reads 15,154.4. Of the five actions compare listed on Forem's
   unchanged head, four moved 0.10% to 0.24% and this one 0.84%; over all 656 actions with a warm value the largest
   difference is 1.85%. A reader who trusts 0.2% takes a listed +0.8% for real, which is what the sentence is there
   to prevent. Smallest fix: *up to about 1% … (compare listed five actions, four by 0.1% to 0.25% and … 15,028 →
   15,154, +0.8%)*. docs/profile-0.2-design.md also says this is not drift (17 of 82 actions move in time order).

Two more were found during the pass and are fixed at `0ee4aed2`:

* **CI was red on macOS at `53a071fd`**: the zombie test skipped there and *Profile tests* requires `0 skips`
  (both jobs: *40 runs, … 0 failures, 0 errors, 1 skips*). `c19ab7bb` defines the test on Linux only. CI on `0ee4aed2`
  is green in all 14 jobs, both macOS jobs included.
* **A `ps` that fails ended `--timeout`'s 10 s at once (`53a071fd`)**: with a `ps` that exits 1 and prints
  nothing, a command that needs 3 s after `TERM` was killed at once, so a stopped suite would write no counts.
  `0ee4aed2` falls back to `kill 0` when `ps` exits non-zero: the same command now finishes its handler (4.1 s),
  and without the fallback the new test fails.

### Should-fix

* **A test for restoring the traps.** Without `traps.each { trap(…) }` after a `--timeout` run, `INT`, `TERM` and
  `HUP` during the report are swallowed (Sure's report takes over two minutes); with it each ends
  lowrail-profile. No test covers it, and the mutant survives. It can be timed: let the command leave a FIFO as
  `runN/1.tsv`, so the report blocks on it, then signal (`scripts/trap-restore.rb`).
* **`profile_test.rb` went from 990 to 1,055 lines in this range**, and `--timeout` is now tested in two files.
  Move `test_timeout_stops_a_hung_run_and_its_processes` to the three `--timeout` tests in `profile_env_test.rb`,
  or all four into a file of their own.
* **Receipts.** OSM's serial captures are committed (`oss_profile_sweep_1/osm/s1`–`s5`), but `run_options.sh`
  reads them from the orb backup and the t3 README calls them not committed. `census/README.md` still names
  `$O/census/SET` and says the replay needs `3c878c94`'s lib.
* **Notes on `0ee4aed2`.** A failing `ps` prints its error on every poll: 31 lines on lowrail-profile's stderr for
  a 3 s wait (send its stderr to `File::NULL`). The new test gives the grandchild 2 s to boot and set its trap; on a
  slow runner it
  would fail on *the grandchild started*, not pass wrongly. QUIT forwarding and the traps set before the spawn have
  no test (both mutants survive); both are correct by reading.

### The three choices the builder left

* **`@aa_given` stays: right.** An `--aa` file that holds `null` parses to nil, and compare must refuse that pair,
  not fall back to comparing without one. The flag and `@aa` are not duplicates.
* **No test for restoring the traps: acceptable for 0.1, but a test is possible** (above). The line works, as run
  with and without it.
* **No test for the Minitest < 5.24 prepend: acceptable.** CI installs Minitest 5.27.0, and 5.23 does not install
  on Ruby 4.0. Run by hand on Ruby 3.3.14 / Rails 7.2.4 with Minitest 5.23.1 (`register_plugin` absent): seed 1234
  in both runs, 7 requests counted, and a child, also under `with_unbundled_env`, sees what the plain run's sees.

### What passed

* **Streaming report (`5cdc5669`).** On the path-gem app's kept runs, report.json and report.md from `1618fc38`
  and `5cdc5669` are identical; on the fresh app with two workers, `1618fc38` and `60387485` differ only in
  `meta.format` and `meta.timed_out`. Peak RSS 42 → 33 MB and 54 → 42 MB. The old report fails the bound test
  with 646,123 objects held (bound 20,000; the new one holds 8,363). `loc << 31 | caller` and `path << 32 | line`
  are distinct below 2³¹ locations and 2³² lines, and no line is negative: the counter counts a line at or below
  0 as line 0 and takes no caller frame there (`lowrail_profile.c`).
* **Counter built outside the bundle (`60387485`).** On an app whose Gemfile reads `.ruby-version` relative to
  the cwd, `1618fc38` exits 1 with Bundler's *No such file* in the build log; the new gem builds and counts 6
  requests. It also builds under the RSpec app's bundle on Ruby 3.3.14.
* **`--timeout`.** All four cases (one or two workers; the hanging test exits on `TERM` or ignores it) exit 124
  with nothing left running at `7a5ee0b6`, `53a071fd` and `0ee4aed2`; a timed-out capture is refused by compare
  (exit 2).
* **Mutants**, one fix undone at a time, each run against the test said to cover it. At `53a071fd` 21 of 24 are
  killed, the streaming report, the RSpec trigger, `ORIGINAL_ENV`, `BUNDLER_ORIG_*`, `LOWRAIL_PROFILE_KEYS`, both
  path-gem rules, the counter's build, five of `--timeout`, both globs (survivors at `60387485`), format 3, the
  2-process boundary and both `if: always()` among them. At `0ee4aed2` the 15 that touch the exe or the tests
  `776ef498` added: 12 killed, the failing-`ps` fallback included. The same three survive at both heads: `QUIT` not
  passed on, the traps not restored, the traps set after the spawn.
* **README and DECISIONS numbers.** Hackatime's 12.5% (15 of 120) and 4.4% (16 of 360), and with three base
  captures 3.3% (2 of 60) and 1.7% (2 of 120), are the replayed `options-hackatime-serial.txt`. The `--timeout`
  row, the note on processes started while `test_helper.rb` loads and the CI job's prose match what ran.

### Maintainability

`profile_report.rb`'s streaming loader is denser than what it replaced, but the ids stay inside `load_run`,
`each_attribution` and two one-line helpers, and the tables read as before. The exe's run loop now carries the
traps, the pending signals, the grace wait and `ps` inline, 36 lines of one branch: a `run_with_timeout`
that returns the status and whether it timed out or was interrupted would give the loop back its shape. The two
spawn paths differ on purpose (a process group changes what the terminal sends), so I would not unify them.
Neither blocks 0.1; the 1,000-line test file is the one rubric flag (should-fix above).
