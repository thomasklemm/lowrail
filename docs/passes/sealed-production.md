# Passive production token and collection units

**Current-source three-unit price: [−15.022961% interpreter Ir](production-aa01-reprice.md).**
`sealed/token_tag` and `sealed/collection_render` have public
build/runtime certificates. The measured production form/token/collection
units are separate from the rejected [combined pricing specimen](sealed-combined.md).
That specimen stays rejected and is not measured again. This is not a Rails
throughput/latency claim or a whole-app result. No default-tier, quarantine or
guarded-pass behavior changes. The later token-continuation safety fix changes
the runtime source; the historical −15.49% remains scoped to `ae025b0`.
The separately authorized [corrected-source re-price](production-interpreter-reprice.md)
at `553e7aa` is **−15.23% total interpreter Ir [−15.25, −15.21]**, with both
A/A controls and pre/post correctness gates passing, but is defective-source
only. The [dispatch-corrected attempt](production-dispatch-reprice.md) is
**rejected no-GC A/A**, not a replacement price. The later prospective
`b059fc9` cohort is accepted under its separately preregistered rule; the
earlier rejection is unchanged. No YJIT price is claimed.

## Helper dispatch safety

**The −15.225536% measured source `553e7aa` had this defect. That number is
not a price for the dispatch fix.** A public production artifact admitted
both a private effective-view generator and an existing view `send` override.
Stock implicit calls generated/converted once; the former fast path raised
`NoMethodError`, or emitted the wrong CSRF name with generation/conversion/send
counts **1/0/1 instead of 1/1/0**. Installation was during `after_initialize`,
before `initialized?` and before the first witness, not post-seal mutation.

The shared `Sealed::VIEW_CONTEXT` captures core
`BasicObject.instance_method(:instance_exec)`. `UnboundMethod#bind_call(view)`
runs Ruby blocks with the actual view as `self`; helpers that Rails calls
implicitly remain actual implicit calls, not reflective/public substitutes.
The named route is different: stock polymorphic routing uses explicit
`recipient.public_send(method_string, article)`. Keep that explicit call and
its live override effects, String argument and public visibility restriction.
The other helper calls preserve private/protected visibility,
`method_missing`'s private-call flag, `respond_to_missing?`/`defined?` behavior,
live ordering, and the saved-value tag continuation. Capturing the core method
also bypasses a view's own `instance_exec` override. Unit/epoch/holder/table
state is retained in local variables, not read from the view after switching
`self`. No view/request/block is retained by admission. Build independently
requires native owner `BasicObject`, original name `instance_exec`, no Ruby
source location and no ISeq; form, render and link certificates pin its
signature, and runtime admission checks the same captured method. A changed capture
with a present certificate key refuses as `view context dispatch changed;
rebuild`. Older certificates missing that key fail closed through the existing
`KeyError` refusal boundary instead.

### Reviewed token/form/collection call list

| Former operation | Verdict |
|---|---|
| Token `view.send(:protect_against_forgery?)` | Real implicit call, with Rails' original `defined?` prefix restored |
| Token `view.form_authenticity_token(...)` | Real implicit call; private/protected and missing-method generation allowed |
| Token `view.send(:request_forgery_protection_token).to_s` | Real implicit helper call, then live conversion exactly once |
| Token continuation `view.send(:tag, :input, **attributes)` | Real implicit call with saved values; never regenerate/reconvert |
| Form validity `view.send(:tag_builder)` | Real implicit call through the same captured context |
| Form validity `view.output_buffer` | Real implicit call through the same captured context |
| Form rendering `view.article_comments_path(article)` | Preserve stock routing's explicit `view.public_send(+"article_comments_path", article)`, not an fcall; private routes remain private and live `public_send` effects remain observable |
| Form rendering `view.url_for(path)` | Real implicit call, like stock `html_options_for_form` |
| Form rendering `view.send(:token_tag, ...)` | Real implicit call; composes with token observer/fallback |
| Collection renderer | No reflective view dispatch; existing implicit `build_rendered_template` already runs on the actual renderer. Stock explicit `current.render(view, ...)` remains explicit |
| Admission `view_class.instance_method(:_routes).bind_call(view)` | Retain: read-only stock-getter witness, body independently certified before the call; it is not a live-helper substitution |
| `view.method`, `view.__send__` | None in these production runtime/admission paths; the route's original `public_send` is deliberately retained |
| Separate `Sealed.link?`: `view.send(:tag_builder)` | Same implicit-call fix in a separate follow-up commit, using `VIEW_CONTEXT`; link build/admission pin the same shared fact |

The three `view.send` calls in `FormScaffoldInventory.check` (builder default,
UTF-8 policy, content-exfiltration policy), and compiler/template reflection
in `FormScaffoldBuild`/inventory, remain **build-only** synthetic probes. They
do not authorize reflective dispatch during requests. Type/Module `.method`
reads in admission check certificate bodies, never invoke a helper on a view.
The sealed link follow-up is separate from the token/form/collection fix.
Default/quarantine and guarded passes are unchanged by either fix.

The kept production regression uses four fresh boot modes: private, protected,
ordinary public (`reflective`), and missing-method generator, each with the hostile reflective
overrides installed before the first witness. It compares literal and
non-String saved-value continuations with the saved stock method, including
once-only generation/conversion and missing-method private-call flags. The
hostile view overrides `send`, `__send__`, `public_send`, `method` and
`instance_exec`; none may intercept an implicit helper. Whole warmed requests additionally
exercise the form/collection path under those conditions. Rails' original
`_run` public template dispatch and polymorphic public route dispatch are
retained, not trapped as implicit helper calls.
Private/protected modes also restrict the effective `output_buffer` getter;
the stock-private `tag_builder` remains private in every mode.
An override of `__send__` alone was not the old defect; including it prevents
the tempting but incorrect fix of replacing `send` with `__send__`.

Source changes: `sealed.rb` (shared core capture), `render_units.rb` (live
token dispatch and captured-method check), `render_units_build.rb` (capture
certificate), `form_scaffold.rb` (form dispatch), `form_scaffold_build.rb`
(capture certificate), `form_scaffold_admission.rb` (capture check). These six
source pins change. The artifact still delivers **zero files and zero template
ISeqs**: three passive unit certificates change, not app/template source bytes.
No new price, YJIT run, Callgrind slot or test-tier integration follows.

### Dispatch-fix validation

Ruby 4.0.7, Rails 8.1.4, strict gates and the retained production fixture:
app source `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`,
lock `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.

- `ruby -Igem/lib -Igem/test gem/test/form_scaffold_test.rb`:
  **2 tests / 201 assertions, zero failures/errors/skips**. This executes
  the public artifact build, both seeded cold off/off/on sequences, both
  **192-pair** status/body/all-header/SQL/event/assign controls and native/deopt
  checks, plus the dispatch and existing continuation regressions.
- `ruby -Igem/lib -Igem/test gem/test/test_certificate_test.rb --seed 19811`:
  **7 / 118, zero failures/errors/skips** on the source-frozen final fix.
- `cargo test --locked`: **39 + 2 + 8 passed**, none failed or ignored.
- A native-capture diagnostic accepts stock `instance_exec` and refuses both
  a captured native `__send__` and a Ruby replacement. No app code executes
  through those rejected captures.

The regression failed first on unchanged main. Earlier whole-request probe
mistakes (the layout adds a fifth CSRF generation/conversion, and its bare
missing-method vcall raises `NameError`, not `NoMethodError`) are retained in
the local validation log, not changes to the production contract. One
certificate run had two hit-count failures while runtime edits overlapped.
Its exact refusal was not captured, so source drift is not asserted as proven
cause. Clean main at the same seed passes **7 / 118**; both the diagnostic
source-frozen run and the final uninstrumented run pass **7 / 118**. Final
runtime/test hashes are checked unchanged across the production/certificate
run. No failed result is suppressed or used as price evidence.

### Separate sealed-link dispatch fix

The link sibling was not unreachable debt: its existing cold production
fixture admits a link unit. Adding a view `send` override before boot, which
raises only for `:tag_builder`, makes that fixture fail on unchanged main
(`6a8e5c9`): the sealed request returns **500**, not the stock **200**. The
override is not a post-seal mutation. The follow-up runs this private helper
as an actual fcall via the same `VIEW_CONTEXT`, with the same shared native
fact pinned in the link certificate and checked at admission.

The regression compares off, unopted-in and sealed response bodies, status,
conversion counts, render events/assigns and method metadata. It requires a
link hit, not silent refusal, for a view with hostile `send`, `__send__`,
`public_send`, `method` and `instance_exec` overrides. The latter four prevent
replacing the fcall with another reflective substitute. Foreign view and
builder holders must still fall back. This follow-up changes only
`sealed.rb` and `sealed_build.rb` source pins and adds the `view_context`
certificate key. It does not edit link template/factory/entry lowering or
claim a new price. The full existing link suite includes its native YJIT
trace smoke check; that is not the paused seam experiment or a priced cohort.

`ruby -Igem/lib -Igem/test gem/test/sealed_link_test.rb` passes **2 / 162,
zero failures/errors/skips** with the five-override regression. Independent
Thermos correctness and maintainability reviews, including follow-ups on the
regression and refusal wording, report no remaining material finding.

## What is certified

Both units use a first **natural original operation** as their witness. The
observation seams are installed identically in explicit sealed off/on arms;
only an admitted on arm takes the fast path. Admission has one try-lock
attempt, checks actual native holders, stock method/body/visibility and source
fingerprints, and rechecks the seal epoch before publishing. Failure is
terminal with a reason in stats/explain. There is no runtime objspace,
materialization, view construction, template lookup, compilation, schema
probing or on-only prepend. Build-only inventory remains build-only.

- **Token:** retain live protection policy, token generation/masking, name
  conversion and autocomplete policy. Literal tag output requires plain
  String name/value, the exact cached view/tag-builder context and the known
  action/method options. Recheck the actual builder holder/context after the
  live generation/conversion/config reads: entry-time checks do not cover a
  generator replacing `@tag_builder`. Unknown inputs, a replacement outside
  the certified holder/context, or epoch changes continue at stock `tag` with
  the already generated/converted values; they do not replay generation or
  conversion. A foreign builder causes local fallback, not terminal retirement;
  a later stock builder can hit again. SafeBuffer, Array, Regexp and nil values
  are original tag continuations, not forced into a String shortcut.
- **Collection:** specialize only stock `collection_with_template` with a
  nonnil template and no layout. Keep live collection derivation/loading,
  lookup, iterator/preloading, local-name/cache-key effects, `Template#render`,
  events and rendered-result objects. This removes fewer branches than the
  old pricing adapter: **there is no cached-template lookup shortcut** and
  no transfer of its isolated or request prices.
- **Form composition:** unwrap only the exact source/body-certified symmetric
  token observer when checking the original helper beneath it. Arbitrary
  helper overrides still refuse. Existing form admission is otherwise intact.

The first production domain deliberately inherits the existing narrow
Ruby 4.0.7 / Rails 8.1.4 stock-blog build inventory. This is not a general
token/collection support claim, a lazy-app certificate, or a test-environment
certificate. The known broader all-sealed Template/Preloader ancestry failure
is not repaired or normalized by these units.

## Explicit fixture boundary

[`BlogShowGetOnly`](../../fixtures/corpus/blog_show_get_only.rb) is a separately
named, tracked fixture, **not a hidden BlogProduction variant**. It creates
fresh schemas and inserts three literal articles and three comments, with
comment counts 2/1/0 and a fixed timestamp, without callbacks/jobs. Preparation
refuses existing SQLite storage. Parent-only read-only validation checks all
rows and absence of queued jobs before cold workers start. The fixture digest
is a required pin in the [numeric gate export](sealed-production-results.json).

The old `db/seeds.rb` snapshot is retained as the named failure
**`historical_seed_six_unfinished_turbo_jobs`**. Both entropy companions reject
`rejected_async_completion` in all three restored arms: six ready
`Turbo::Streams::ActionBroadcastJob` jobs, no supervisor, no completed snapshot.
Its cold equality does not waive async completion. Raw capture digests and
the actual refusal records are retained in the export; the dedicated terminal
completion regression continues to exercise pending work and a held Cable
writer. No jobs were deleted from that seed to make it pass.

Any future price uses **only the new fixture** for all candidate/control arms.
It must not be compared with −17.86%, older form prices or any older cohort.

## Executed gates

The public CLI regression builds an isolated artifact containing exactly
form/token/collection, with no delivered files/templates. The reusable
[`sealed_production_check.rb`](../../bench/experiments/sealed_production_check.rb)
then runs restored production workers, not a pricing installer:

1. Raw off/off/on remains `rejected_off_control` for real entropy/clock fields.
   Both declared entropy seeds pass exact off/off/on comparisons of full cold
   ancestry, feature/load order, hooks, ordered SQL, events, response and
   parent-read exit effects, including the async completion boundary. No
   `Templates::CompiledSource` or `PreloadPlans::Hook` occurs in any arm; no
   census field is dropped.
2. **192 ordinary + 192 header-writing render-subscriber pairs** have identical
   status/body/all headers, SQL, events and assigns. Each on arm records
   **form104/token398/collection87** hits and **62 collection fallbacks**.
   The latter remain visible; the nonnil-template/no-layout domain does not
   cover all negative/alternate rendering cases. Off hit counters are zero.
3. After natural admission, **50 native show requests** give
   **form50/token200/collection50**, zero fallbacks/refusals. Epoch deopt gives
   original-path fallback counts **1/4/1**, with no further hits.
4. Public regression additionally compares literal and unsupported live token
   values against the stock continuation, including output class/encoding and
   once-only generation/name conversion. Tampered observer certificates leave
   three successful original requests, zero token/collection hits and explicit
   terminal refusals. No wrong-answer special cases are added.

The token-continuation safety-fix rerun passed **2 tests / 123 assertions,
zero failures/errors/skips**, including all the production gates above with
the same hit/fallback counts. Its new boot-installed-generator regression
first failed against the old runtime: stock returned
`<input data-probe="late-builder" />`, but specialization emitted the literal
hidden input. With the fix both return the stock output, generating once per
arm; the foreign-builder call records zero hits/one fallback. Restoring the
stock builder records one hit/zero fallbacks without reauthorization. No
dependency or seal epoch is reset. The historical numeric exports remain
unchanged; this is correctness evidence for changed source, not a new price.

Reproduce the self-contained build/fixture/gate regression under the repository
Ruby with an available `real-blog-r4` corpus:

```sh
LOWRAIL_TEST_CORPUS_ROOT=/absolute/corpus/root \
  ruby -Igem/test gem/test/form_scaffold_test.rb --name /passive_production/
# For an already prepared, isolated app and the unchanged fixture snapshot:
ruby bench/experiments/sealed_production_check.rb APP SEED_STORAGE NEW_OUTPUT
```

The scheduling/counter prerequisite is separate: the actual Callgrind
`gc_exclusion` regression executes the native counter, rather than only its
stub, outside slots/cohorts. Affinity/CPU/overlap observations remain symmetric
and outside window endpoints; unavailable migration counters remain null.

### Broader validation and a caught integration regression

The first full primary suite recorded **173 tests / 5,918 assertions, three
failures, zero errors, two named Rails-checkout/bundle skips**. One failure is
the unchanged all-sealed cold-ancestry gate. The others were not dismissed:
the old-artifact test's explicit matrix grows from 27 to 33 cases for the two
new sealed pass IDs, and the new observer had allocated an extra initialization
TracePoint that correctly retired memo's tracing-sensitive fast path.

Clean main passes the same production-activation regression (1/91); the draft
fails it, and the corrected observer plus manifest matrix pass **8/178**. The
observer now uses Rails' existing `after_initialize` load hook directly: it
needs completed Zeitwerk aliasing, not a new initialized-app TracePoint.
Memo's conservative trace policy and all guarded passes are unchanged. The
dedicated Rails report rerun passes **3/17**, zero skips. The final affected
suite and published source/artifact pins are recorded in the numeric export;
the original failed run remains reported, not relabeled green.

The corrected strict run records **170 tests / 3,552 assertions, one failure,
zero errors/skips**: only the retained all-sealed cold-ancestry failure above.
It includes every gem test file except the unchanged `inertia_props_test.rb`
(its three tests passed in the initial full run). Cargo passes **39 + 1 + 8**.
Actual counter/placement regressions pass **3/155**; the separately pinned
512-MiB-brk counter regression passes **1/13**, with zero skips. These are
untimed prerequisites, not an app cohort or a speed result.

## Accepted finite interpreter cohort

**Historical at ae025b0; superseded for the corrected source by the
[accepted re-price](production-interpreter-reprice.md).**

Measured commit:
[`ae025b0`](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb),
Ruby **4.0.7**, Rails **8.1.4**, actual **interpreter**, production
`GET /articles/1` on **BlogShowGetOnly** only. The three-unit manifest is
`5271a66ff71c44f4276363adef136f65cadc2e1b7729ef6f2e953dd0d212d7e6`;
the fixture is
`21a0de39f113d57e9303967b801c7b34d86aca7bcfcbe8c3d94013914cf5c970`.
Full runtime, harness, app, lock, native and tool pins are in the
[numeric export](sealed-production-results.json), alongside all six round
rows, complete summaries and all 18 worker records / 72 windows.

One separately authorized cohort used slots 1+2, six randomized rounds,
seed **41231**, off-A/off-B/production, **N=0/50** subtraction, real entropy,
the unchanged five heap floors and the pinned **512-MiB-brk** tool. Maximum
observed worker-process envelope concurrency is **two**. Both slots were
released after all 18 workers finished. No retry, excluded round, rescore,
older-price comparison or additional cohort. **No YJIT cohort**; that method
is parked and interpreter Ir remains primary.

The harness ran from a **clean detached worktree at the measured commit**.
Each worker recorded its actual revision, clean state, harness aggregate,
Ruby description and private metadata-wrapper SHA before and after execution.
The original source-path runtime worktree was also clean at that commit; its
bytes and the artifact were not rebuilt or relocated. The wrapper only checks
pins outside the unchanged shared worker's windows; it installs no pricing
adapter. Its executed source and the driver's source are retained in the export.
Source, framework, native, tool and artifact hashes match before and after.

The first command **refused `RAILS_ENV=nil`** at parent manifest preflight,
before creating a cohort directory or any counter worker. Only the explicit
production command environment was corrected. This was not a counter retry.

### Result and gates

**Accepted by the shared harness: total AND GC-excluded A/A pass.** Values
below are per-request medians and nominal 95% bootstrap intervals over the six
independent round pairs, not independent samples for each request.

| Metric | Off-A / request | Production / request | Production Δ% [95% interval] | Off-B/A Δ% [95% interval] |
|---|---:|---:|---:|---:|
| Total Ir | 8,803,370.57 | 7,440,039.03 | **−15.492980 [−15.511296, −15.461565]** | −0.029975 [−0.047392, +0.028585] |
| GC-excluded Ir | 8,804,989.22 | 7,439,041.47 | **−15.509265 [−15.527966, −15.471767]** | −0.037196 [−0.055493, +0.015382] |
| Allocated objects (diagnostic only) | 2,281.14 | 1,870.60 | −17.994038 [−18.012700, −17.977800] | +0.003945 [−0.010521, +0.015785] |

- Both instruction A/A intervals contain zero and stay within **±0.5%**.
  All five slot-range/exact-page heap gates, brk preflight/worker checks and
  actual-interpreter/JIT-state checks pass. All 72 counter dumps independently
  reconcile with exported totals and all 36 N=0 subtractions reconcile.
- Every window has **zero minor/major collections**. Total and GC-excluded
  windows are separate executions, not one trace with GC removed. Their
  difference is not GC savings. The allocation figure is diagnostic only.
- The **JIT-specific idle companion is not applicable to interpreter** and
  was not run (`idle_boundary` is absent); it is not relabeled an executed
  pass. The normal request-settle seam ran in every worker.
- All 72 windows retain symmetric thread CPU/affinity and overlap endpoints:
  affinity `0-7`, 32 windows overlap a peer counter envelope and 48 overlap
  a peer worker-process envelope. These are conservative envelopes, not a
  census of unrelated host load. **Migration counts remain null/unavailable**;
  equal endpoint CPUs do not establish zero migrations.
- All six on workers finish with all three production admissions active and
  no refusal. Post-cohort untimed cold and **192+192** controls pass again,
  with paired hits **104/398/87**, 62 collection fallbacks retained, and
  native 50-show hits **50/200/50**, zero fallbacks/refusals. Witness work is
  outside warm windows, not a controlled cold-latency estimate.

This establishes reduced **interpreter instruction work for this one endpoint
and fixture** with these production units. It does not establish native
latency, YJIT performance, arbitrary subscribers/apps, test-tier admission or
the broader all-sealed ancestry gate. No comparison with another fixture or
the rejected pricing specimen follows.
