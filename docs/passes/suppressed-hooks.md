# Suppressed-hook audit: cached facts are not a method epoch

2026-10-20. This follows the `view/link_to` / `route/path` quarantine, not a
new speed experiment. **Defaults stay unchanged.** Seven audited passes need
the sealed contract; `endpoint/action` survives the named probe. No source
certificate, digest-byte comparison or AR epoch is credited with protection
it did not demonstrate.

## Before quarantine

Each disposable process boots Rails 8.1.4 on Ruby 4.0.7, constructs eligible
units, warms the fast path, suppresses the relevant owner's `method_added`
or `singleton_method_added`, replaces the dependency, and repeats the same
operation. A separate off process makes the same mutation. These are actual
dependency replacements, not file edits after compilation. All seven failures
leave the cached guard **true**, add hits and report **zero fallbacks**.

| Pass | Suppressed owner / replacement | Off after mutation / stale fast result | Hits before → after |
|---|---|---|---:|
| `inertia/config_bind` | `Hash.method_added`; `extract!` sets a changed version | changed version / old version | 3 → 4 |
| `memo/sha256` | `Digest::SHA256.singleton_method_added`; `base64digest` | changed digest / cached digest | 2 → 3 |
| `memo/uri_join` | `URI.singleton_method_added`; `join` changes host/path | changed URI / cached URI | 2 → 3 |
| `digest/file_memo` | `Digest::MD5.singleton_method_added`; `file` | changed digest / cached digest of unchanged bytes | 2 → 3 |
| `active_record/instantiate` | model singleton callback; `instantiate_instance_of` | changed row titles / old titles | 12 → 16 |
| `active_record/preload_plans` | model singleton callback; `scope_for_association` adds a filter | filtered rows / unfiltered rows | 3 → 4 |
| `active_record/ar_plans` | Arel visitor owner's callback; `visit_Arel_Nodes_SelectStatement` adds a comment | changed SQL / old SQL, same rows | 6 → 8 |

The AR cases keep both model epochs **52/55** before and after. The scoped
reader also keeps the same visitor object. Those facts cannot detect a
suppressed method hook on a dependency. File memo's full-byte comparison
certifies file content, not what an overridden `Digest::MD5.file` means.

`endpoint/action` passes: after two index/show warm pairs, suppressing
`UrlHelper.method_added` and replacing `link_to` changes every index link in
both off and on responses. Its actual helper/body checks take the original
continuation; the action/filter effects are still once-only. The permanent
fixture also compares complete responses with statistics disabled, rather
than relying on guard counters as proof. Existing post-entry subscriber,
singleton-helper, template, filter and constant mutation controls remain.
This is evidence for this slice/probe, not a general proof about endpoints.

## Publication boundary and regression contract

The generic eligibility mechanism is the sealed owner's published
[`ca814ae`](https://github.com/thomasklemm/lowrail/commit/ca814ae9168946d90e9895e9feb4d85ed68c4c2b).
This follow-up sets six more registry `sealed_only` flags, in Rust and Ruby;
config binding was already flagged. It does not create another sealed path.

- Guarded explicit selection refuses these passes, including aliases/groups.
  `all-opt-in` now selects only `inertia/props` and `endpoint/action`; default
  still selects no units.
- Old guarded artifacts, unknown tiers and mixed artifacts containing any
  sealed-only pass refuse **the entire manifest before Guard/Loader/pass
  installers**, recording a reason. The runtime regression covers 24 cases
  across all eight sealed registry pass names, including `sealed/link_to`.
- Accepted sealed artifacts require `tier: "sealed-v1"`, build/runtime
  production environment and explicit `LOWRAIL_SEALED=1`. Test mode never
  accepts them. There is no test certificate override and no fake JSON seal.
- `suppressed_hooks_test.rb` uses real production Rails, public compilation
  and `Lowrail.setup`, not direct pass installation. For each bad pass it
  checks off versus refused-old-artifact mutation results and **nonzero warm
  hits in a separate accepted, unmutated sealed process**. Post-seal mutation
  is SEAL001, not a promised supported sealed behavior.
- Existing isolated runtime unit fixtures explicitly accept the production
  contract. Their extra surviving guards are defense in depth, not evidence
  that suppressed hooks became safe. Historical AR composition/L3 fixtures
  now assert original-only refusal, not accelerated/shadow coverage.

Selecting all sealed candidates exposed two build planners assuming every
Rails app loads Active Record. Instantiate and scoped-plan builders now record
`framework_absent` rather than failing a controller-only app or forcing AR to
load. The public digest-fixture build exercises this boundary. Its standalone
production test writes real manifest bytes and requires hits before mutation
checks; a missing file returning `no-manifest` is not coverage.

## Verification

No new request or micro benchmark cohort is part of this quarantine.

After integrating the published relocatable-format boundary,
`cargo test --all-targets`: **35 unit + 1 corpus/MCP + 3 verifier tests pass**,
with the physical corpus root explicitly supplied so the optional case runs.
Ruby 4.0.7: **129 tests, 4,916 assertions, zero failures/errors, 6 skips**
(four legacy `.corpus/real-blog` fixture-path checks and two prepared-framework
fixture checks; real-blog-r4 and framework suites run separately below).
The production digest fixture's additional source-isolation check passes
**1 test / 34 assertions**, including original behavior and zero hits with
all units disabled while the delivered source's runtime entry stays loaded.
Ruby 4.1.0-preview1: **129 tests, 4,011 assertions, zero failures/errors,
9 skips**. The skips are missing RSpec, Vite, Freezolite/require-hooks and
the two prepared-framework fixtures, plus the existing Ruby-4.0.7-only cold-link
fixture; they are not accelerated coverage. The seven new public production
probes separately pass **1 test / 91 assertions** on both Ruby targets.
The file-memo probe pins its certified Digest 3.2.1; this is not certification
of Ruby 4.1's default Digest 3.3.0.

Rails 8.1.4 L3 (seed 41231): AP **4,095**, AV **2,747**, AV-with-AP **242**,
AV-with-AR **173**, AR **9,240** outcomes identical; zero shadow mismatches.
All quarantined AR units have **0 hits / 0 fallbacks** because their old
unmarked artifacts refuse whole. This is original-only compatibility, not a
retained AR acceleration/shadow claim. The first AR off/off runs lacked the
sqlite3 CLI (1 failure, 2 errors); discard that environment cohort. Installing
sqlite3 and rerunning AR off/off/L3 with the identical prepared lockfile makes
all three processes exit zero and all 9,240 identities agree. No test or
diagnostic suppression was added.

Five-app `lowrail verify`, Ruby 4.0.7, seed 41231, one Minitest worker,
`LOWRAIL_VERIFY_LOADS=1`, rebuilt default and all-opt-in artifacts:

| App / suite | Outcomes / own-thread SQL, both selections | Default hits/fallbacks | All-opt-in per-unit hits/fallbacks | Strict load gate |
|---|---|---|---|---|
| Blog | 21 / 125 queries identical | `{}` / `{}` | endpoint units 0/1: **0/0 each** | pass, no differences |
| Campfire | 632 pass + 2 libvips skips / 15,108 queries identical | `{}` / `{}` | no units | pass, no differences |
| PingCRM ordinary | 1 / 4 queries identical | `{}` / `{}` | props unit 0: **0/0** | pass |
| PingCRM browser | 25 / 809 default, 812 opt-in queries; each off/on comparison identical | `{}` / `{}` | props unit 0: **271/0** | pass; other-thread SQL remains advisory |
| Redprints ordinary | 50 / 692 queries identical | `{}` / `{}` | props unit 0: **14/0** | **refused**, 16 stable load differences, 32 unstable entries |
| Redprints browser | 12 / 260 queries identical | `{}` / `{}` | props unit 0: **54/0** | **refused**, known setup/source delivery boundary |
| Starter | 36 / 264 queries identical | `{}` / `{}` | props unit 0: **30/0** | pass; 8 unstable load entries advisory |

In particular, do not report Blog's two eligible endpoint units as covered by
its ordinary suite: neither hits there. The dedicated response-level endpoint
fixture supplies actual positive/mutation coverage. Redprints remains a red
strict compatibility result even with **zero selected units**; its adapter /
Bundlebun load-order boundary is not fixed by these flags. Outcomes-only
agreement is not full support. All seven newly sealed-only passes disappear
from guarded app maps intentionally, rather than becoming unexplained
fallbacks. Their positive public production coverage is the separate fixture.

### Compatibility controls still in progress at quarantine publication

The framework and application comparisons above use the quarantine runtime
frozen before format-2 integration; both full gem suites and Cargo then test
the integrated publication tree. No claim about the unpublished TracePoint
fix or a newly priced sealed runtime follows from these gates.

At publication the frozen app driver was still completing default and
all-opt-in controls for CASA, Writebook, Fizzy and CodeTriage. CASA default ordinary **2,992** and
browser **769** outcomes pass; own-thread SQL agrees after symmetric controls
(47/5 unstable-query identities and 8 unstable load entries remain advisory).
CASA all-opt-in ordinary also passes. All CASA manifests/maps are empty.
Remaining browser/compat results were **pending**, not passed or silently skipped;
their completion is recorded below. This early publication released
the six registry flags for dependent sealed/activation work, not a promotion.

### Final compatibility controls (2026-10-21)

That same sequential driver has now finished, without changing its frozen
runtime, selections, seed or fixtures. Every default/all-opt-in manifest has
**zero units**, and every hit/fallback map is `{}`. These are original-only
setup/delivery controls, not accelerated support or pricing. SQL agreement
below is per test after the verifier's symmetric same-mode controls, not an
inference from equal totals. Raw query counts are retained where they differ.

| App / suite | Off/on outcomes, both selections | Own-thread SQL default / all-opt-in | Strict load gate default / all-opt-in | Remaining advisories |
|---|---|---|---|---|
| CASA ordinary | 2,971 pass + 21 pending, identical | 126,101 off / 126,103 on; 126,103 each opt-in; controlled identities agree | pass / pass, 0 stable differences | 47 / 90 unstable SQL identities; 8 unstable load entries each |
| CASA browser | 769 pass, identical | 62,268 each, both selections | pass / pass, 0 stable differences | 5 unstable SQL identities, 8 unstable loads each |
| Writebook ordinary | 119 pass, identical | 8,028 each, both selections | pass / pass, 0 stable differences | 0 unstable SQL identities, 8 unstable loads each |
| Writebook browser | 2 pass, identical | 217 each, both selections | pass / pass, 0 stable differences | 0 unstable SQL identities, 8 unstable loads each |
| Fizzy ordinary | **117 pass + 7 errors**, identical | 5,322 each, both selections | pass / **refused, 18 stable differences** | 0 unstable SQL identities, 8 unstable loads each; baseline remains red |
| CodeTriage ordinary | 222 pass, identical | 2,871 each, both selections | pass / pass, 0 stable differences | 2 / 3 unstable SQL identities; 24 unstable loads each |

Fizzy's seven errors are `Current.reset_all` on an instance, originating at
`test/test_helpers/session_test_helper.rb:22`, in both off/on and their
same-mode controls. Default verify exits zero because the error identities
agree; that is **not a green app baseline**. All-opt-in additionally exits
one on its strict load gate: 18 surviving differences reorder load events
349–357 (including `active_job_arguments`, `QrCodeLink`, `ApplicationJob` and
`Turbo::Streams::BroadcastStreamJob`). Its per-test outcomes and own-thread
SQL still agree, and no pass is selected. The verifier labels this a
setup/source-delivery or combined-pass boundary; no individual culprit is
proved. The archived manifest embedded in that report is **format 1, files
`{}`, units `[]`, passes `{}`**: this is already post-quarantine, but before
format-2 and the later tracing/loader changes. Do not relabel it as an active
AR/config-pass experiment or attribute it to a single later change. Do not
suppress the load differences, retry until green or claim Fizzy support.
Redprints' earlier strict-load refusal also remains red.

No compatibility result is pending now. These historical controls do not
validate the later production TracePoint changes or any sealed acceleration.

### Fizzy on the published hook-free-loader head

One new correctness comparison **per selection**, not a retry of the frozen
controls above, ran on
[`b091cb7`](https://github.com/thomasklemm/lowrail/commit/b091cb7206a0bc877a9eef9a0201ec95f85c7a2a)
(loader boundary `2d1ad72`, doctor and test-only timeout observer). Ruby 4.0.7,
seed 41231, `RAILS_ENV=test`, `PARALLEL_WORKERS=1`,
`LOWRAIL_VERIFY_LOADS=1`; release binary rebuilt before both artifacts.

| Selection | Outcomes / own-thread SQL | Stable load differences | Unstable load entries | Verify |
|---|---|---:|---:|---|
| Default | 124 identical: 117 pass + the same 7 baseline errors; 5,322 identical queries | **18** | 8 | **refused**, exit 1 |
| All-opt-in | same outcomes and queries | **0** | **26**, including the 18 reordered-event identities | exit 0, advisory instability remains |

Both format-2 artifacts have files `{}`, units `[]`, passes `{}` and empty
hit/fallback maps. There is **no accelerated coverage**. The first default
mismatch is `after_suite/load_events/349`: off records the
`active_job_arguments` hook (`activejob-8.1.4/lib/active_job/railtie.rb:23`),
on records `QrCodeLink`. Events 349–357 contain the same nine hook/load
identities in different order; no loaded-set or outcome/SQL difference is
claimed. In the all-opt-in same-mode controls those event positions vary,
so the verifier removes their identities symmetrically as unstable. Its zero
stable count is **not proof that the cause was fixed**.

No pass is selected, and `Lowrail.setup` returns for an empty manifest before
Guard, Loader or Passes installation. The setup/manifest-versus-inherent-order
cause is not isolated; the exact commands, manifests and reports were handed
to the loader owner. No loader changes, extra Fizzy comparisons, baseline
error fixes or gate suppression were made here. The older 18 remain a
post-quarantine/pre-format-2/pre-loader result, not retrospectively attributed
to one later change.
