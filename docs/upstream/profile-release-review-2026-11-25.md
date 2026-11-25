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
