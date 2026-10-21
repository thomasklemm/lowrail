# An opt-in Lowrail subset — Bet E (2026-10-21)

**Exploration, not a third production tier.** The diagnostic is implemented;
the whole-action compiler is not. No production guards, default passes,
app implementation, or admission rules change. Apps that do not invoke the
diagnostic or explicitly load the experiment are unaffected.

## Answer: adoption is not certified by a source census

The seven requested apps boot on Ruby **4.0.7 / Rails 8.1.4**. Doctor inventories
**856 actions: 0 certified, 65 with no detected structural blocker, 16 small
rewrite candidates, 586 large candidates, and 189 refused**. This is not
"81 actions can safely opt in": the no-mutation contract and complete
transitive effects/type certificates are missing for all 856.

[Machine-readable census](lowrail-subset.json) contains every action, findings,
rewrite size, rule-specific suggested rewrite, pending certificates, app/source
pins, environments and unknown benefit. Counts overlap across rules; rewrite
size is a conservative source-shape label, not an estimate in engineering days.

| App | Actions | Certified | No blocker detected | Small | Large | Refused | Diagnostic environment |
|---|---:|---:|---:|---:|---:|---:|---|
| Generated blog | 9 | 0 | 0 | 0 | 9 | 0 | development |
| Campfire r81 | 117 | 0 | 0 | 0 | 84 | 33 | development |
| Fizzy | 187 | 0 | 0 | 0 | 77 | 110 | test |
| CASA | 266 | 0 | 0 | 0 | 239 | 27 | test |
| Writebook | 72 | 0 | 0 | 0 | 59 | 13 | test |
| CodeTriage | 42 | 0 | 0 | 0 | 40 | 2 | test |
| Lobsters | 163 | 0 | 65 | 16 | 78 | 4 | production |
| **Total** | **856** | **0** | **65** | **16** | **586** | **189** | |

### Rules ranked by distinct actions blocked

| Rule | Actions | Meaning |
|---|---:|---|
| SUB003 | 747 | Proc/around callback shape unsupported by the proposed whole-action compiler |
| SUB004 | 222 | A reached HTML ERB template lacks a strict-locals declaration |
| SUB008 | 189 | Action source cannot be closed/resolved by this prototype |
| SUB006 | 130 | Computed/options/collection/cache render boundary |
| SUB005 | 65 | Reached helper/template writes view instance variables |
| SUB007 | 7 | Dynamic/raw AR query structure |
| SUB002 | 2 | Computed dispatch/eval/metaprogramming |
| SUB001 | 1 | Detected mutable-code/config operation inside reached source |

SUB003 is a **compiler support gap**, often inherited Rails machinery, not a
recommendation to remove security callbacks. Boot callback membership is
conservative across the controller, not evaluated path by path. Consequently
747 is not 747 profitable rewrites. This ranking selected the action-specific
callback-selection experiment below before investing in view composition.

## The proposed contract and what it would buy

Roundhouse's model, described in [PLAN](PLAN.md), replaces Rails within a
supported subset. Lowrail's unchanged-app model retains Rails and refuses
unproved sites; entry-only checks cannot cover mid-request mutation. This
experiment asks whether an explicit, stronger app contract can close that
boundary. It does **not** quietly reinterpret the existing guarded/sealed tiers.

Each rule has a source/boot check and a missing proof obligation. Clean source
is necessary, never sufficient. A deployment would have to opt in explicitly,
pin Ruby/Rails/gems/schema/config, exercise its own suite and route scenarios,
and reject uncertified transitive boundaries. No such admission path ships here.

| Area / rule | Concrete subset | Check / proposed removal |
|---|---|---|
| All / SUB001 | Code, callback membership, routes, subscribers, helper/config tables fixed after readiness; restart to change them. No late framework monkeypatches or hidden/native writes. | Reuse SEAL001/004/005/008/009 hints and boot inventory; an exercised seal-check plus complete mutation boundary is still required. Could replace repeated body/epoch/config revalidation, **not** guards on live values. |
| Controllers/helpers / SUB002 | Hot-path dispatch targets finite literals; no computed `send`, `eval`, dynamic method generation or `method_missing` dispatch. | Prism checks calls; suggests explicit branches/literal dispatch tables. Removes SEAL006/unresolved-target boundaries only after actual receiver/type facts close. |
| Controllers / SUB003 | Finite, ordered per-action callback plan with known conditions and halting/around/error semantics. Initial whole-action subset excludes unsupported Proc/around shapes. | Booted Facts callback census. Keep security bodies; extract named operations only when equivalent, or retain stock callbacks until the compiler supports them. Potentially removes chain interpretation, never authorization, CSRF, live predicates or callback bodies. |
| Views / SUB004 | Explicit inputs at every template/partial boundary, including `locals: ()`; controller assigns are explicit read-only inputs to rendering. | ERB strict-locals marker and literal partial traversal. Would remove SEAL007/locals-shape and repeated lookup certification. Actual strict-locals binding/type checks remain future compiler work. |
| Views/helpers / SUB005 | Helpers return values; no helper/template mutation of view instance variables. Compute assigns before rendering. Keep explicit `content_for`/capture effects live and modeled. | Scan reached helper/template writes, not every unused helper in the app. Addresses the assign-effect hole in handwritten endpoint ceilings. Does not certify mutable objects merely because their ivar is not reassigned. |
| Views / SUB006 | Finite synchronous named render graph with explicit handlers/layout/locals; unsupported caching, streaming, components and computed renders stay on Rails. | Follow literal partial names; flag options/collection/dynamic/cache operations. Removes resolver/handler/collection dispatch only when equivalent emission is available. **Never disable caching to gain eligibility.** |
| Models/AR / SUB007 | Fixed query/table/association shape, runtime values bound normally; real AR casts, defaults, scopes, queries, authorization and callbacks remain. | Flag raw/dynamic SQL and dynamic model-name operations. Could remove query-shape/reflection rediscovery, not AR semantics or result fetching. No direct-ivar, query-result-cache or general typed-AR claim. |
| All / SUB008 | Every compiled effect/dispatch/type boundary has source and a transitive certificate; otherwise leave that call live or refuse the region. | Resolve action/helper source and retain unknowns. Observed types/census hotness are evidence, not proof of purity. This prototype lacks the complete gem/framework effect graph and therefore never certifies an action. |

The relevant existing boundaries are documented in
[suppressed hooks](passes/suppressed-hooks.md),
[endpoint quarantine and assign effects](passes/endpoint.md),
[callback ceilings](passes/layer-ceiling.md), and
[template/lookup certification](passes/erb.md).
The JSON rule catalog carries the corresponding SEAL IDs and rewrite advice.

## Doctor: implemented CLI and read-only MCP

```sh
mise exec ruby@4.0.7 -- cargo build --locked
RAILS_ENV=test mise exec ruby@4.0.7 -- target/debug/lowrail doctor APP --subset
mise exec ruby@4.0.7 -- target/debug/lowrail doctor APP --subset --static --out /tmp/subset.json
```

The existing `lowrail doctor APP` behavior remains unchanged. `--subset` runs
an explicit diagnostic eager boot with `LOWRAIL=0`, collecting existing
`Lowrail::Facts` controller/callback/routes data. This command is **not** runtime
activation and does not claim to preserve lazy-load order during its inventory.
Normal Lowrail setup never requires the scanner or the experiment.
Exit zero means the diagnostic completed, not that any action is compliant.

Boot and source parsing run in separate processes. In particular, Campfire's
unchanged bundle pins Prism 1.4; the external scanner uses Lowrail's current
Prism grammar adapter, without upgrading the app bundle. The source scanner
reuses seal hints, generates Ruby with Rails' real Erubi handler (without
executing it), and follows named app methods/helpers/literal partials. Existing
`observed.json` types/sample counts and lowering ledger entries are attached
when available. **Estimated speedup stays null** without an action-scoped
completed-operation budget; blocker counts are not converted into percentages.

MCP exposes `subset_doctor`, returning the last `.lowrail/subset.json` with
`available:false` when absent. Like the existing doctor tool it is read-only;
it does not secretly boot apps or run their suites from an MCP query.
Malformed JSON is an error, not stale successful evidence.

Per action the report distinguishes:

* `structural_candidate`: no syntactic blocker detected; certificates pending.
* `small_rewrite_candidate`: currently only explicit-locals changes detected.
* `large_rewrite_candidate`: dispatch/callback/effect/render/query reshaping.
* `refused`: unresolved source boundary; rewrite/adoption effort unknown.

Every row has `compliant:false`, rule findings and specific suggested rewrites
(inline in the full report, via the shared rule catalog in the compact census).

### Reproducing the census

Prepare pins with `script/corpus` and the dependency-only overlays documented
in [compat](compat.md) and [Campfire](campfire-bench.md). Blog uses Roundhouse's
generator at [bb90df2](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9).
Lobsters uses ruby-bench at
[351a39b](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
the Bet C wrapper/lockfile, and a disposable production SQLite fixture.
CodeTriage uses its existing CI database configuration with a disposable
schema-only PostgreSQL database; no production database is contacted.

Run doctor in the environment shown above with the app's ordinary boot inputs
and wrapper Gemfile where required. Aggregate reports, without rebooting apps:

```sh
mise exec ruby@4.0.7 -- ruby script/subset-census docs/lowrail-subset.json \
  blog=.corpus/real-blog/.lowrail/subset.json \
  campfire-r81=.corpus/campfire-r81/.lowrail/subset.json \
  fizzy=.corpus/fizzy/.lowrail/subset.json casa=.corpus/casa/.lowrail/subset.json \
  writebook=.corpus/writebook/.lowrail/subset.json \
  codetriage=.corpus/codetriage/.lowrail/subset.json \
  lobsters=.corpus/ruby-bench/benchmarks/lobsters/.lowrail/subset.json
```

Inventory includes explicit route-default actions and directly declared public
`action_methods` on source-backed app controllers. It excludes inherited public
Turbo/tag helper methods unless routed, does not expand dynamic `:action`
routes, and does not enumerate engine/gem controllers without app source.
HTML ERB only: JSON/Turbo Stream/other formats and alternate custom layouts are
not comprehensively assessed. Helper resolution is conservative by name, not a
Ruby include/prepend/type proof. Source closure, non-ERB templates, metaprogrammed
visibility/actions, dynamic routes and omitted formats are coverage limits,
not evidence that those actions would comply. Zero parse errors and seven
successful boots do not mean seven passing app suites or production inventories.

## Experiment: per-action callback selection, not whole-action AOT

After the ranking, E and G agreed a boundary: E owns action-specific
membership/selection; G owns generic ActiveSupport callback execution.
G had no reusable emitter. This experiment therefore **copies selected chains
and uses unchanged Rails `run_callbacks`**, including live Proc/around callbacks.

[`subset_callbacks.rb`](../bench/experiments/subset_callbacks.rb) builds the
`index`/`show` plans before requests and compiles each selected Rails chain.
It folds only stock `ActionFilter` `only`/`except` membership whose missing-action
behavior is known. Earlier live `if`/`unless` predicates are retained even if a
later `except` is known false: erasing their effects would change the app.
It retains the real controller pipeline, action, assigns, rendering, response,
AR and all remaining conditions. A single active flag controls admission;
the public callback-chain setter withdraws it with a loud warning and later
entries use the original chain. Direct callback/condition/hash/native mutation
is **not covered**, and stable `action_name` is an experimental assumption.
No default or sealed runtime registers this specimen.

The generated blog has six filters. For `index`, one filter is removed; for
`show`, six remain and one action-name condition is removed. The contract test
covers asymmetric index/show behavior, preceding predicate effects, Proc/around
execution, halting and a later callback mutation/fallback.

### Why not fuse the action and view now?

Bet B's tested compiler at
[080c2bb](https://github.com/thomasklemm/lowrail/commit/080c2bb) retains the real
controller pipeline and specializes `TemplateRenderer#render_template` after
assigns. Its final
[5c57f8b](https://github.com/thomasklemm/lowrail/commit/5c57f8bb830717f707ff134b876f6e6c43e470ab)
reports show/index **+24.53%/+18.94% wall and +113/+136 objects**; it was killed.
Its cached-collection/render-options refusal excludes Campfire `rooms#show`,
and strict locals remain unsupported by that compiler. The proposed strict
subset rule is therefore not an admission check for B's current compiler.
E does not copy that renderer, disable Campfire caching, or call the composition
whole-action AOT. D's MethodSeal active flag at
[867337f](https://github.com/thomasklemm/lowrail/commit/867337f) is observational,
not a safe no-mutation certificate. Its hooks do not justify dropping any
production guards; E's incomplete setter tripwire is equally experimental.

The independent callback screen is recorded separately below. No whole-action
compiler, typed model compiler, Campfire acceleration, general certificate or
unchanged-app support claim is delivered by this exploration.

## Native screen: KILL, no speed direction established

Used Bet A's **unchanged** `script/screen` from
[ff46f99](https://github.com/thomasklemm/lowrail/commit/ff46f99517f6a1fcb9dfc3ab3e132616be100457)
through `NativeBench::Exploration.install`, not a forked timing loop.
Three alternating `off_a/on/off_b` rounds, **200 warmups and 300 measured
requests per route per worker**, CPU 2, native YJIT, GC enabled, separate
10-request coverage workers. The default zero-unit YJIT artifact is independently
built; no sealed form/token/collection stack or B/D implementation is loaded.
The app is an unchanged generated-blog copy dedicated to these sequential
workers; the same pristine four-database snapshot is restored before each.

[Screen JSON](lowrail-subset-screen.json) retains **both** runs, raw worker
wall/allocation samples, exact checks, two entropy seeds, DB checks, RSS/GC,
source/lock/artifact/harness pins and setup costs. Native hardware instructions
are unavailable in this orb (`perf_event_open`: ENOENT, paranoid 2). No
Callgrind cohort was requested or run, and these are not README price claims.

| Corrected run | Show | Index |
|---|---:|---:|
| Off-A / off-B / on wall medians, µs¹ | 2,083.71 / 2,113.45 / 2,127.12 | 2,132.70 / 2,282.90 / 2,186.14 |
| Paired on/off delta | +2.271% | +2.796% |
| A/A max absolute round spread | 4.085% | 12.874% |
| Allocations/request median, all three arms | **2,387 / 2,387 / 2,387** | **2,488 / 2,488 / 2,488** |
| RSS KiB, off-A / off-B / on¹ | 180,181 / 181,589 / 181,128 | 180,748 / 181,849 / 181,476 |
| GC ms/request, off-A / off-B / on¹ | 0.2576 / 0.3273 / 0.2748 | 0.3263 / 0.1877 / 0.1851 |
| Status/body/all headers, both seeds, every paired round | pass | pass |
| Validation DB snapshot unchanged | pass | pass |
| Separate on coverage | 10 selections / 10 requests | 10 selections / 10 requests |
| Off coverage | 0 selections | 0 selections |

¹ Means across worker medians/RSS/GC rates, as emitted by the shared harness.
No claim of an RSS reduction; raw startup/layout variation is retained.

**Decision: KILL this direction**, not a proved regression. Identical integer
allocation medians show no allocation gain; wall effects are inside A/A, so
they establish neither a slowdown nor a win. The coordinator explicitly ended
this prototype after the screen. No further subset variants or larger cohorts.
The reusable output is the doctor/corpus census, not an accelerated action.

### Retained first failure and controlled inputs

The first run failed exact body/header checks **between off-A and off-B too**.
Its apparent wall deltas −4.345%/+3.386% were already inside A/A
11.075%/19.757%; allocations were also 2,387/2,488. It is rejected, not pooled
with the corrected run or erased.

The differing bytes were Turbo `signed-stream-name` and the resulting ETag.
With `tmp` retained the two off workers matched; clearing `tmp` as the harness
does reproduced the mismatch. Turbo derives its signing key during boot from
the harness's independently generated dummy secret, before the exploration
hook. The correction supplies the same **disposable** Rails secret/key-generator
and Turbo signing-key input in every arm, before a verifier has been used;
if the verifier was already initialized, setup refuses. The two relevant Turbo
source files are pinned along with all exploration dependencies. No app code,
event, header, signature or digest is removed/normalized.

Untimed validation uses the existing blog entropy control's unchanged runtime
and random-site allowlists with explicitly fresh generated-app/lockfile pins,
seeds 0 and 1, and a caller-supplied request ID. Real timed requests retain
their normal RNG/clock reads; validation controls do not run in the timed
window. The symmetric setup overhead is recorded separately from boot.
These predictable inputs are only for the disposable fixture, never a deployed
security recipe. DB validation is the existing blog effects snapshot, not a
proof of arbitrary external IO. Broader events/assigns/transitive-effect
equivalence is not certified by these two GETs.

The native adapter is
[`subset_callbacks_native.rb`](../bench/experiments/subset_callbacks_native.rb).
Supply the ordinary native-bench config (`workload: blog`, dedicated `app`,
pristine `seed`, matching-mode empty `artifact`) plus `exploration_setup`,
`subset_entropy_policy`, and `exploration_sources` covering the specimen,
entropy policy/helper dependencies and Turbo engine/verifier source files.
The export retains the executed config and exact policy/source hashes.

```sh
mise exec ruby@4.0.7 -- script/screen APP /articles/1 /articles \
  --config PRIVATE_CONFIG.json --output NEW_PRIVATE_DIR --warmup 200 --samples 300
```

## Verification and stopping point

* `mise exec ruby@4.0.7 -- cargo test --locked`: **39 unit + 2 integration +
  8 verify tests passed**, no ignored tests. MCP discovery/report refresh and
  corrupt-report behavior are included.
* `ruby gem/test/subset_test.rb` on 4.0.7: **1 test / 12 assertions**, no
  failures/errors/skips. Reached-helper effects, an unused neighboring helper,
  asymmetric action blockers, strict locals, cached renders, layout `yield`,
  unknown benefit and boot callback evidence are checked through the report.
* `ruby bench/experiments/subset_callbacks_test.rb`: **1 / 8**, no failures,
  errors or skips; real Rails callback behavior and loud mutation fallback.
* Final CLI boot recheck on unchanged Campfire/Prism 1.4: **117 actions**,
  **84 large / 33 refused**, boot successful, same census as before.
* Generated blog own suite through `lowrail verify`: **21 tests / 54
  assertions off and on**, identical per-test outcomes and own-thread SQL
  (**125 queries**). Prototype active on, **2 selected entries**, zero off.
* Blog's real headless Chrome suite, separately through `lowrail verify`:
  **2 tests / 14 assertions off and on**, identical per-test outcomes and
  reported own-thread SQL (**55 queries**); **10 selected entries** on, zero
  off. Browser server-thread SQL remains advisory, not a stronger SQL gate.

The two own-suite runs use the experiment installed after `test_helper` loads,
before Rails' test runner. The ordinary manifest has zero units and reports a
YJIT-build/interpreter-test mode refusal; **public-unit hits are zero, as
expected**. Independent specimen counts above and in the exported suite evidence
show this was not a no-op callback comparison. These are correctness runs, not
wall-time results. Other corpus app suites were **not rerun** for this specimen;
the census's seven boots are not substituted for those suites.

The temporary suite runner used the following setup, with Lowrail's ordinary
verify recorder providing per-test/SQL comparisons and an after-run specimen
counter snapshot. It changed no app/test implementation:

```ruby
$LOAD_PATH.unshift(File.expand_path("test", Dir.pwd))
require File.expand_path("test/test_helper", Dir.pwd)
require "/absolute/lowrail/bench/experiments/subset_callbacks"
SubsetCallbacks.counting = true
SubsetCallbacks.install(ArticlesController, actions: %w[index show], enabled: ENV["LOWRAIL"] == "1")
require "rails/test_unit/runner"
Rails::TestUnit::Runner.run(ARGV)
```

Stop here: retain the rules, doctor, per-action census and negative specimen.
No callback-selection promotion, larger benchmark, further subset variant,
whole-action performance/support claim, app rewrite demonstration, main push,
or production certificate follows from these results.
