# Sealed onboarding census — five apps

Ruby 4.0.7, seed 41231; `script/corpus` pins, no app source overlays.
All five apps boot and their baseline and observed suites pass: **779 test
outcomes**, including Redprints' separately selected 12 browser examples.
Campfire retains two skips. This is an onboarding census, **not sealed
fast-path certification**. All observed tests run unoptimized.

The sanitized [ledger](sealed-corpus.json) retains pin/lock provenance,
commands, grouped observation locations/targets, app versus gem name/version,
static hints, source-coverage comparison and checkpoint timing. The complete
per-process evidence, candidate stacks and individual tests remain in each
app's `.lowrail/{seal,seal-static,doctor}.json`, available through MCP. No
configuration values, SQL, cookies or database contents are exported.

## Classify before counting

A callback alone does not prove mutation. The structural census compares the
certified **destination** at test boundaries: own UnboundMethod identities and
visibility, ancestors, singleton holders, constants and autoload bindings.
For example, `Other.include(CertifiedModule)` does not change CertifiedModule.
That source-side callback remains a hint, not a proven SEAL001 violation.
One shared ancestor change can affect thousands of inventoried holders; these
are **holder/checkpoint observations, not distinct mutation operations**.

| App | Tests | API/callback hints | Confirmed holder deltas | Test-only deltas | Lazy-loading deltas | App-source deltas needing production-path review | Mixed/unresolved deltas |
|---|---:|---:|---:|---:|---:|---:|---:|
| Blog | 21 | 252 | 45 | 35 | 4 | 0 | 6 |
| Campfire | 634 | 4,423 | 3,359 | 3,084 | 9 | 1 | 265 |
| PingCRM | 26 | 255 | 17 | 3 | 6 | 0 | 8 |
| Redprints | 50 | 719 | 44 | 25 | 6 | 0 | 13 |
| Starter | 36 | 413 | 61 | 45 | 9 | 0 | 7 |
| Redprints system, separate | 12 | 445 | 52 | 27 | 6 | 0 | 19 |

**This does not establish that every app violates the production contract.**
Nor does zero in the app-source column certify a compatible app. The remaining
mixed/unresolved deltas have not been classified as genuine production-path
mutations. No production-violation headline is inferred from them. Classification
is advisory, never authorization to activate a sealed unit.

The one Campfire app-source delta is a redefinition of
`RoomMessagesCountDatabaseTasks#{load_schema,migrate,repair_room_messages_count}`
from `lib/tasks/room_messages_count.rake:5/9/14`. The test suite explicitly
loads tasks in `test/models/room/messages_count_tasks_test.rb:5`; that is not
evidence of a request-time production redefinition. Exclude this task-only
target from an endpoint certificate, or complete task loading before sealing
a process which actually runs tasks. Do not demand an app rewrite solely
because a test loads its task definitions.

### Patterns and remedies

* **Test-only (b):** transactional fixture Notifications subscribe/unsubscribe
  gives Blog **84**, Campfire **2,492**, PingCRM **104**, Redprints **236** and
  Starter **144** API hints. They are not 84–2,492 proved production subscription
  changes: the present watcher sees the API, not successful fanout-state deltas.
  Rails test helpers, Minitest/Mocha, RSpec, Capybara and WebMock also change
  method/ancestor state. Campfire's 3,084 automatically justified test-only
  holder deltas are dominated by Mocha modules propagating through the broad
  Object/Class ancestry. Keep these fixtures and doubles; exclude their effect
  from production-contract counts **only in test**, and keep those processes
  unoptimized. Never classify an app mutation as test-only merely because
  Minitest appears further up its call stack.
* **Lazy materialization (a):** `UserAgent`, ActiveSupport multibyte helpers,
  Rails generators/schema metadata and ActionText support constants load after
  the current materialization point. Finish the needed factory/load step before
  sealing, or narrow the target inventory. These are seal-point/inventory
  problems, not evidence that Ruby apps inherently cannot be sealed. Mixed
  intervals can contain both test-helper constants and legitimate lazy loading;
  the ledger preserves their components instead of guessing one disposition.
* **Config hints:** the main suites each observe one initial config-container
  write through Rails' lazy `env_config` construction. Redprints system observes
  49 config hints, including test configuration machinery. Prewarming the Rails
  request environment before sealing is an easy candidate, but these API hints
  are not state-comparison proof of a production configuration violation.
* **Unresolved:** anonymous ancestor additions, repeated framework-task method
  definitions, logger/formatter instance extensions, Channel test/factory
  extensions and generated class attributes remain separately reviewable.
  App versus gem source and gem versions are retained. A certified endpoint
  should exclude unrelated logger/channel/task targets, not freeze all of Rails.
  A production-relevant mutation on an actually expanded target still refuses.
* **Actionable static review:** Campfire's
  `SetCurrentRequest#default_url_options` (`app/controllers/concerns/set_current_request.rb:10`)
  reads Current's host/port/protocol: SEAL002 is real source dependence, not a
  dynamically proved request-invariance violation. Pass these values explicitly
  or leave URL-default evaluation live. Redprints' `Proposal#to_param = external_id`
  is a SEAL003 purity-review hint, not proof of impurity; do not rewrite a pure
  accessor unnecessarily. Its delivery `public_send` calls can use an audited
  finite status table or remain live. SEAL007 strict-locals recommendations are
  usually easy to apply, but not having strict locals is not itself a violation.

The broad inventory and unresolved provenance are deliberately retained. A
fully classified genuine-production-only violation count is **not yet
available**; reporting raw observations as that count would be false.

## Blog follow-up: seal-clean (dynamic, test-observed)

The table above is the initial five-app census, retained rather than silently
reclassified. For the blog pilot, all six mixed and four lazy holder rows were
traced to their causes. **Zero observed production-relevant violations remain.**
This is finite test evidence, not enforcement or proof of unexecuted paths.
Campfire's 265 unresolved holder rows are deferred, not treated as clean.

| Initial holder row | Cause, exact source evidence and disposition |
|---|---|
| `Object` (mixed) | Test-class definitions in `test/{controllers,models}`; DRb 2.2.3 constants loaded by `active_support/testing/parallelization.rb:3` through `drb.rb`/`drb/drb.rb:52,1991–1993`. Test harness loading, not production request mutation. |
| `Rails` (mixed) | `rails/test_help.rb:10` requires `rails/generators/test_case.rb:3`, which requires `rails/generators.rb:3,14`; `Rails::Dom` is rails-dom-testing 2.3.0. Test support only. |
| `ActiveRecord` (mixed) | Fixture/TestDatabases/Assertions constants are test helpers. `InternalMetadata` and `SchemaMigration` are lazy database metadata classes; now explicitly resolved before the seal. The residual row is entirely test-only. |
| `ActionController` (mixed) | `test_case.rb` requires `metal/testing.rb` and `template_assertions.rb:6` before defining TestCase/TestRequest/TestSession/LiveTestResponse. Both previously “lazy” components are test-only support. |
| `ActionController::Live` (mixed) | `test_case.rb:25,34` aliases the original thread methods, then replaces them at lines 28/37 to disable controller threads in tests. Alias source locations still point at `metal/live.rb:408,417`; that is not production provenance of the alias operation. Test-only. |
| anonymous ActiveJob ancestor (mixed) | `active_job/test_helper.rb:19,37–38` includes TestQueueAdapter and creates `_test_adapter` plus the private `__class_attr__test_adapter*` methods generated by `active_support/class_attribute.rb:15,17`. The anonymous holder can be labeled with a different descendant between boots; the changed ancestor and generated fields identify its cause. Test-only. |
| `Thor::Group` (lazy) | Same `rails/test_help.rb:10` → `rails/generators/test_case.rb:3` chain. Also resolved before inventory when Thor is loaded, so this row no longer occurs. |
| `Object::UserAgent` (lazy) | AllowBrowser's first request loads useragent 0.16.11 (`action_controller/metal/allow_browser.rb:64`). Require its normal entry point before the seal. |
| `ActiveSupport::Multibyte::Chars` (lazy) | First SQLite fixture quote loads `multibyte/chars.rb:47` through `active_record/connection_adapters/abstract/quoting.rb:74`. Resolve the constant before the seal. |
| `ActionDispatch::Routing::RoutesProxy` (lazy) | `button_to` in `comments/_comment.html.erb:4` enters polymorphic routing (`polymorphic_routes.rb:223`), loading `routes_proxy.rb:9`. Resolve the constant before the seal. |

Seal-only preparation now also evaluates Rails' lazy `env_config`. It does
not change the shared guarded materializer or load arbitrary app test helpers.
The same original seed-41231 suite rerun passes **21/54 assertions**, with
**271 observations: 230 API hints and 41 confirmed holder deltas**. All four
lazy-only rows and the metadata/config mutations disappear. Thirty-six deltas
are automatically test-only; five residual mixed rows are the documented
test-harness cases above. Reviewed classification: **41 test-only, zero lazy,
zero unresolved, zero production-relevant**. The raw automated classifications
are preserved beside this manual disposition in the JSON; no heuristic is
broadened to excuse every mutation with a test caller. Eighty-four subscriber
API hints are still hints, not proven subscriber-state violations. All 21 tests
remain unoptimized; seal-clean is not a fast-path coverage claim.

## Static versus dynamic evidence

Prism scans app/config/lib and exact gem files named by dynamic evidence. Each
SEAL001–009 rule has positive/negative fixtures. Dynamic API callbacks are
excluded from the proof set. Comparison uses unique rule/changed-source-file
pairs; an ancestor-only proof with no known mutation source is counted as such,
not attributed to the test runner's checkpoint line.

| App | Static hints | Hint source pairs | Proven source pairs | Matched pairs | Coverage unmatched |
|---|---:|---:|---:|---:|---:|
| Blog | 97 | 44 | 39 | 3 | 96.25% |
| Campfire | 271 | 149 | 130 | 8 | 97.05% |
| PingCRM | 64 | 27 | 31 | 3 | 94.55% |
| Redprints | 152 | 65 | 42 | 6 | 94.06% |
| Starter | 122 | 53 | 46 | 8 | 91.21% |
| Redprints system | 160 | 69 | 60 | 6 | 95.12% |

This high **coverage mismatch is not a semantic disagreement or false-positive
rate**: boot definitions, unexecuted branches, template recommendations and
test-only behavior have different scopes. No hint was independently refuted;
the semantic disagreement rate is **unknown**, not 0%. Static scanning does not
claim that a custom to_param is impure or that an unexecuted send is reachable.
It remains a pure hint list in doctor, with **no gate weight** for the pilot.

## Detector cost, not request cost

These are observed wall times with corpus/gem validation sharing the orb, not
isolated benchmark estimates. The detector makes two full comparisons per test
plus process boundaries; it never installs this comparison in production.
TracePoint, materialization, serialization and baseline-suite costs are excluded.

| App | Comparisons | Total comparison seconds | Median ms/check | Comparison ms/test |
|---|---:|---:|---:|---:|
| Blog | 43 | 3.671 | 70.75 | 174.82 |
| Campfire | 1,270 | 110.169 | 76.08 | 173.77 |
| PingCRM | 53 | 4.040 | 69.93 | 155.38 |
| Redprints | 101 | 6.822 | 58.05 | 136.44 |
| Starter | 73 | 5.631 | 75.18 | 156.42 |
| Redprints system | 25 | 2.152 | 79.85 | 179.36 |

## Gates and next boundary

The three quarantine reproductions now require **confirmed** SEAL001 state
differences plus candidate file:line evidence, retaining original output and
once-only name/to_param evaluation. The suite keeps a negative source-module
inclusion case and suppressed-hook/visibility case. This does not establish
an in-flight optimized continuation: seal-check deliberately runs with
lowering off; a violation observed after request entry cannot retroactively
make that request safe. Test stubs conservatively revoke the entire process.

Tooling validation after upstream rebase: gem suite **118 runs / 4,284
assertions**, zero failures or errors, seven optional skips; seal-preparation
follow-up **15/52**, request repros **3/42**, Rust **34 unit + 3 integration**
pass. The blog rerun above validates the later seal on the real app.

Guarded default verification previously passes the same five apps and own-thread
SQL with empty hit/fallback maps; it is quarantine compatibility, not sealed
coverage. New sealed-only route/link artifacts, residual check pricing, AP/AV L3
and the finite interpreter request cohort remain **pending**. Neither the
historical −5.995%/−0.987% unsafe source results nor the patched VM's 534-Ir
two-checkpoint estimate is a sealed request saving. Receiver selection,
config/table/input facts and observational exclusions still need their own
check or refusal before activating the pilot.
