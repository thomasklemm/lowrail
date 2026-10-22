# Framework contracts and observed arguments across six Rails apps

2026-10-22. Advisory types/MCP only. Same six frozen facts and unchanged app
sources as [types-breadth](types-breadth.md), based on
[`93dd986`](https://github.com/thomasklemm/lowrail/commit/93dd986af457ac39e2ab83015d80add48e6817b6).
No runtime/lowering, app patch, upstream contribution or performance claim.

**442 unknown slots become static; 843 unknown argument slots gain observed
types (8.75% of 9,637).** The latter is sampled caller evidence, never static
or proven. Fizzy's suite is not green; its samples are explicitly partial.
Lobsters remains an unchanged workload with all Lowrail outputs external.

## Fixed-denominator ledger

Order is **proven / static / observed / unknown**. There are 24,184 effective
return/parameter slots throughout; no parameters are removed to improve the
score. Ivars and support declarations are excluded. These are effective
receiver slots, including inherited copies, not independent method bodies.

| App | Before (no observations) | Framework contracts | Contracts + observed arguments | Arguments recovered |
|---|---|---|---|---:|
| Blog | 2/99/0/195 | 2/99/0/195 | **2/99/0/195** | 0 / 97 |
| Fizzy | 14/953/0/1,660 | 14/953/0/1,660 | **14/953/86/1,574** | 86 / 947 |
| Campfire | 30/752/0/5,941 | 30/1,181/0/5,512 | **30/1,181/144/5,368** | 144 / 3,791 |
| CASA | 40/2,548/0/7,286 | 40/2,561/0/7,273 | **40/2,561/517/6,756** | 517 / 3,223 |
| Writebook | 19/499/0/1,025 | 19/499/0/1,025 | **19/499/96/929** | 96 / 529 |
| Lobsters workload | 34/881/0/2,206 | 34/881/0/2,206 | **34/881/0/2,206** | unavailable / 1,050 |
| **Total** | **139/5,732/0/18,313** | **139/6,174/0/17,871** | **139/6,174/843/17,028** | **843 / 9,637** |

The historical blog 2/99/7/188 contains seven sampled **returns**. This
argument-only comparison starts without those observations; it does not lose
seven static facts. No proven/static names are changed by observation merging.
Of the 843 recovered arguments, **110 retain unknown generic members**, such
as `Array[untyped]`; a class sample cannot establish element types.

The default observer requires a targetable Ruby ISeq and an app-source path;
gem implementations are not sampled unless explicitly selected. Rest,
keyword-rest and block parameters remain untyped. This measures the existing
observer's recovery, not the ceiling of a wider sampler or caller analysis.

[Machine ledger](types-contracts-coverage.json): every recovered slot, ordinal
and name, type, sample histogram, provenance, cap, facts/output hashes, suite
exit status, and counts of runtime methods outside the fixed universe.

## Generic contracts, not app-specific guesses

The bounded catalog now describes ActionView's TagHelper, CaptureHelper and
OutputSafetyHelper. It matches effective boot owner, gem source path, and
Rails 8.0/8.1 version family, retaining that source/version in every slot.
Known overridden `tag_builder` / `safe_join` return boundaries refuse the
dependent contract. Inputs keep their booted shape and remain `untyped`.
Existing modeled effective receivers now receive the catalog return as well
as its parameter shape; an actual app body still wins over the catalog.

| Contract family | Campfire | CASA | Total recovered |
|---|---:|---:|---:|
| TagHelper | 198 | 6 | 204 |
| CaptureHelper | 132 | 4 | 136 |
| OutputSafetyHelper | 99 | 3 | 102 |
| **Total** | **429** | **13** | **442** |

`tag()` and `tag(nil)` return TagBuilder, not a string; a whole-method
signature includes TagBuilder and SafeBuffer. Existing modeled calls propagate
that conservative whole-method union, rather than selecting an overload.
`capture` and `content_for`
include nil. `provide` returns nil even when it appends content. `content_for?`
is boolean. Safe-output helpers return SafeBuffer on normal completion.
These are **advisory normal-return framework contracts**, not proofs about
arbitrary mutated buffers, custom conversion methods or block execution.
Bodies containing unsupported blocks still refuse inference. RBS declares
SafeBuffer as a String subtype and supplies the external TagBuilder name.

The installed Rails 8.1.4 source and executed boundary probe were checked,
including nil/object capture, empty/nonempty content, empty/one-element
sentences, and invalid names (`tag(false)` raises TypeError here).
The source reference is [Rails ActionView helpers](https://github.com/rails/rails/tree/v8.1.4/actionview/lib/action_view/helpers).
Turbo's large broadcast bucket is deliberately **not** assigned a fixed
publisher/job return: real channel, instrumentation and enqueue paths vary.
No replacement-runtime signature has been treated as a real-Rails contract.

## Own-suite observation, without app patches

Existing `lowrail observe`, Ruby 4.0.7, seed **1379**, cap **16** per method
per process, `LOWRAIL_OBSERVE_TYPES_ONLY=1`. Rails apps use their default
`bin/rails test` scope, not a separately invoked system-test suite. CASA uses
default RSpec scope (`exclude ci_only` is the app's own configuration).

| App | Retained own-suite result | Argument-conflicting slots |
|---|---|---:|
| Blog | 21 tests / 54 assertions, green | 0 |
| Fizzy | 124 / 458, 0 failures, **7 errors** | 0 |
| Campfire | 234 / 671, green | 0 |
| CASA | 3,761 examples, 0 failures, **21 pending** | 0 |
| Writebook | 119 / 381, green | 0 |
| Lobsters | no shipped `test` or `spec` tree; **unavailable**, not a passed zero-yield suite | unavailable |

Fizzy's seven full error identities match the recorder-off control: each
raises `Current#reset_all` from `test/test_helpers/session_test_helper.rb:22`.
The 86 arguments are useful samples from a failing suite, not support proof.
No retries-to-green or app edits were made. CASA needed the existing Node 24
asset build and a disposable local PostgreSQL database. Preparation failures
and the initial blog invocation failure are retained, not erased.

All facts, raw observations, aliases, RBS and derived JSON live outside the
workload trees under the external analysis root. The unchanged Lobsters
workload is ruby-bench `351a39b` plus Lowrail's already-committed overlays.
Nothing is authored, committed, published or offered to Lobsters.

### All 13 flagged return slots investigated; none merged here

The raw merger reports **Campfire 1 + CASA 12 distinct return conflicts**;
these must not be presented as 13 argument conflicts or silently discarded.
[Full classifications and evidence](types-contracts-conflicts.json):

- **Four compatible Rails relations:** `CasaOrg#casa_admins`, `#supervisors`,
  `#volunteers` have STI elements below User; `Volunteer#case_assignments_with_cases`
  returns an AssociationRelation of CaseAssignment. Actual relation identity
  and `klass <= expected_class` were checked. The compatibility checker does
  not understand these model-specific subtype/association-relation cases.
- **Nine exception-unwind artifacts, not normal-return contradictions:**
  Campfire `Opengraph::Fetch#resolve_redirect` (RestrictedHTTP::Violation);
  CASA `ContactTypeGroupsController#new`, `ContactTypesController#new`,
  `CustomOrgLinksController#new`, `HearingTypesController#new`,
  `JudgesController#new`, `OtherDutiesController#new`, `NotesController#edit`
  (Pundit::NotAuthorizedError), and `VolunteersController#send_sms_to`
  (NoMethodError). A diagnostic trace of unchanged own tests observed each
  nil `:return` during exception unwinding. Normal-return samples agree with
  the static names where exercised; this is not a proof of all executions.

Ruby emits `TracePoint(:return)` with nil on exception unwind; the existing
recorder does **not** distinguish that from a normal nil return. This remains
a recorded limitation, not an inferred nullable contract. No recorder or
compatibility-checker semantics are changed in this bet.

The published comparison therefore uses an explicit **argument-only
derivative**, preserving raw observations but excluding **all** return/ivar
samples and 52 method records outside the original modeled universe. Its
returns are asserted to be identical static fact objects. It does not
publish the raw merged output as corrected RBS. Generic observations of Range
and NoMethodError keep their unknown type parameters; standalone support also
declares DateTime, so these real CASA arguments validate without guessed types.

## Reproduction and checks

Prepare external aliases with copied facts whose absolute `app_root` names
the unchanged workload. Run from Lowrail, with a command that changes only
the subprocess's working directory, for example:

```sh
LOWRAIL_OBSERVE_TYPES_ONLY=1 lowrail observe /tmp/types/fizzy --samples 16 -- \
  bash -c 'cd /absolute/fizzy && export LOWRAIL_OBSERVE_ROOT="$PWD" && exec bundle exec bin/rails test --seed 1379'
lowrail types /tmp/types/fizzy/static > /tmp/types/fizzy/contracts-static.json
script/types-observed-arguments /tmp/types blog fizzy campfire casa writebook lobsters
```

`static/.lowrail/facts.json` contains the same facts but no observations;
`static.json` is the no-observation baseline from 93dd986. The reducer rejects
changed slot universes, changed returns or argument conflicts; it never boots
an app or rewrites the raw recorder file. All generated files stay external.

The rebased code candidate
[`f507a89`](https://github.com/thomasklemm/lowrail/commit/f507a89263d6b53815ff1decb7e7b9eba1051003),
based on main's screen-platform commit 14d8cf0, passed:

- `cargo test --locked`: **42 + 2 + 8**, zero failures; real-blog corpus
  integrations executed with the prepared external corpus root.
- Full strict Ruby 4.0.7 gem suite, seed 1729: **193 / 6,932**, zero
  failures/errors, the same three named optional skips detailed below.
- All **seven** current bench suites: **44 / 736**, zero failures/errors/skips,
  Minitest 6.0.6 with explicit `MT_CPU=16`; this includes `request_pairs`
  **17 / 352** and the new screen suite **5 / 95**, with Valgrind installed.
- **Six static + five argument-only RBS validates**, RBS 4.2.0, all exit 0.
- Both source-checked Fizzy MCP sessions. The existing session covers
  type-at-position, method signature, definition and dynamic-receiver refusal.
  The frozen per-slot ledger is identical after rebase.

The 6292640 follow-up changed only this documentation, not checked gate inputs.
No new Steep, runtime-support or performance claim.

### Thermos corrections

The initial independent reviews identified an anonymous-helper lookup gap and
a relative facts-path bug in the measurement reducer. Named dependency
overrides already refused, but an anonymous ancestor could be skipped to a
stock view method. The view catalog now refuses that incomplete lookup for
both the outer method and its dependencies; the general body resolver is
unchanged. A regression fails on the original candidate, and checks both
named and anonymous shadowing without replacing the defining Rails module.

The reducer now resolves format-2 `app_root` relative to the facts file, just
like the CLI, refuses in-app output before writing, and pins the resolved root
when copying facts into an external argument alias. Its integration control
checks refusal, a successful external alias, and unchanged input facts.
All retained workload outputs remain external, including Lobsters.

View contracts now share the existing catalog signature builder, and required
external RBS names, generics and superclasses share one declaration table.
The nullable `capture` contract was not changed: `SafeBuffer?` already includes
the nil values observed for nil/object block results. The frozen six-app
static facts and argument ledger are unchanged by these corrections.

A second Fizzy MCP session against the argument-only alias reports
`AccessesHelper#access_menu_tag` as
`(Bucket) ?{ (*untyped) -> untyped } -> untyped`, with `Bucket: 1` and
`evidence: observed` for `bucket`. Its definition matches line 2 of
`app/helpers/accesses_helper.rb`; its return stays unknown. The same session
checks the static `Comment.new` call at comments_controller.rb:31:15.

### Published breadth baseline verification

The prepared strict Ruby 4.0.7 rerun for the published 93dd986 inputs finished
with **193 tests / 6,932 assertions, zero failures/errors, three named optional
skips**: the absent `campfire` specimen (the separate `campfire-r81` observation
above is not that specimen), and the two Rails-suite checkout/bundle gates.
Cargo was **41 + 2 + 8**, six static RBS directories validated, and the six
original bench suites were **39 / 601**, zero failures/errors/skips.

The other orb's 641 bench assertions differ only in `request_pairs`: its
worker-overlap test makes **five counted assertions** per available OS thread
on Minitest 6.0.6 (`assert_operator` and `assert_match` each count two), plus
eight fixed assertions. Local controlled censuses with `MT_CPU=8` and `16`
saw 10 and 18 threads and 58 and 98 assertions, respectively; the latter full
suite reproduced **17 / 352**
instead of **17 / 312**. Both Valgrind checks ran. The original other-orb
historical thread census was not retained; that historical attribution is a
reconstruction, while the local mechanism and difference were reproduced.

The initial full strict run (**193 / 3,854, ten failures, one error, three
skips**) is retained: missing rails_vite/Inertia prerequisites and an existing
noncanonical `real-blog-r4` specimen. Dependencies were installed and a fresh
pinned specimen prepared without relaxing source pins or modifying app code.
Their versions and installation commands were already documented in
[testing prerequisites](development/testing.md). Ruby preview was not installed
and is not claimed as verified.
