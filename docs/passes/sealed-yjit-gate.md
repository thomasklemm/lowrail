# Bet S: finite sealed/YJIT go/no-go

## Preregistration — 2026-10-23, before measurement

Source baseline: current `origin/main`,
[`a233fff`](https://github.com/thomasklemm/lowrail/commit/a233fff63ab61baf9b5205ca403d5f23cfa1dfe9).
No runtime/pass/default/quarantine changes. Fresh plain public
`build --sealed --env production --jit yjit`; do not prune units, add a
denylist, or reuse a historical artifact. The historical three-unit
interpreter price is not this fresh build's price.

**Decision: GO only if the YJIT wall-time block-delta t95 interval is wholly
negative, instructions do not regress, and the correctness/coverage gates
pass. NO-GO otherwise, including unresolved results or failed gates.**
Report each app separately; the two-app bet is GO only if both pass.
No extra cohort, retry, outlier removal, stopped-round salvage, or pooling
with historical measurements. A failed gate is not a measured loss.

- One native cohort per app: four blocks, alternating **off/on/off** and
  **on/off/on**. Every position is a fresh Ruby 4.0.7 process with startup
  YJIT, ten warmup requests and ten measured requests. Serial execution,
  one fixed allowed CPU, ordinary heap and GC, no profiler/statistics in
  timing. Real entropy; compilation and collections during requests count.
- Time the full Rack request including response consumption and status
  validation with `CLOCK_MONOTONIC`. For each block divide the mean on
  process cost by the mean off process cost, subtract one, multiply by 100.
  The estimate is the mean of **four block deltas**, and exploratory t95
  is mean ± 3.182446305 × sample SD / √4 (three degrees of freedom).
  Requests are not independent statistical replicates. Retain flanking
  same-arm differences as drift diagnostics, not a fitted correction.
- Instructions: one serial six-round off-A/off-B/on fixed-heap Callgrind
  cohort, using the existing `script/screen` N0/N50 worker, matching fresh
  **interpreter** artifact. This is the repository's primary instruction
  metric, not YJIT machine instructions or latency. Both total/no-GC A/A
  intervals must be wholly within ±0.1%; all existing heap/brk/background
  and response gates remain. Non-regression requires the total-Ir on/off
  interval's upper endpoint ≤ 0. Do not infer YJIT-flat instructions from
  a ten-warmup native run, or weaken the existing YJIT-flat price gate.
- Existing raw-response and two-seed cold off/off/on companions, ordered
  SQL, state/load/ancestry/completion checks, and both 192-pair blog controls
  remain hard gates. Keep the raw-entropy refusal visible; only the existing
  explicitly pinned companion policy can certify its declared slice.
  Do not normalize tokens, drop headers, recast lazy binds, or waive cold
  differences. Require actual admitted units and nonzero fast-path hits.
- Blog: retained `BlogShowGetOnly`, `GET /articles/1`, two comments. The
  public cold checker also accepts the current plain build's AR instantiate
  units, while preserving all observable comparisons and render-unit hit/
  epoch-deopt requirements; every unit's counters remain recorded.
- Second app: census current pinned, non-blog corpus apps; choose the
  successfully built production/YJIT app with the greatest unit count,
  then check runtime admission/hits. Record build/boot refusals separately,
  never call them zero admitted units. Use one representative GET already
  present in the repository's fixture drivers. No new pass or app patch.
  Selection and counts will be recorded before timing. If none admits a
  unit, stop the second-app arm rather than invent a benchmark.
- Real-Puma throughput is conditional on a positive native block result
  and passing correctness gates, never a rescue for a negative/unresolved
  block result. One finite cohort only. Any NO-GO gets a short diagnosis,
  not repeated warmups or a replacement cohort.

Time box: one working session, at most 90 minutes of setup/selection and
measurement. Infrastructure failures and unfinished arms are recorded as
unresolved NO-GO, not zero effect or evidence of no eligible corpus app.

## Frozen selection — before native or instruction timing

**Fizzy, GET /buckets**, is the second app: 47 units in its fresh plain
production/YJIT build (45 AR instantiate, token, collection). Both render
units admit and have nonzero hits in the untimed cold companion. Blog has
20 units (17 AR instantiate, form, token, collection).

The successful primary-track pinned production builds admit: Fizzy 47,
Campfire 21, CodeTriage 13, Redprints 12, PingCRM 11, Starter 6,
RubyToolbox 3, Fat Free CRM 1. CASA refuses a missing production master key;
Writebook refuses the removed `sqlite3_production_warning=` API; Wikino
requires production domain/AWS settings and PostgreSQL 18 schema support
(the orb has PostgreSQL 15). These are unresolved builds, not zero units.
The maximum is among successfully prepared primary-track builds; duplicate
Rails 8.2-alpha fixture tracks were not surveyed. No app source was patched.

YJIT manifest SHA-256, frozen before timing:

- Blog: `171d9fcaa83510ab517132cae4cdd33131ec05f1ae39531d619181280ad6c5a7`.
- Fizzy: `5032a2802ff6a1332ba31b0654f571c2c99be93a57139ab577cc6a76be5a8bdc`.

Untimed correctness already rejects both current plain artifacts: on-only
AR runtime feature loads differ from off; Fizzy also has off/off terminal
effects differences and unavailable lazy SQL binds. No gates are waived.
The single planned performance cohorts are retained as diagnostic evidence,
not accepted speed claims, regardless of their sign.

## Owner stopping decision — supersedes interpreter work

**runtime lowering parked: interpreter-only gains do not count, YJIT is the reference**.
This decision arrived after both single YJIT cohorts finished, while the
blog interpreter counter was running. Stop that counter (three full rounds
retained, fourth incomplete); prevent the queued Fizzy interpreter cohort
from starting. No interpreter result is completed, priced or used to argue
for continuation. No additional native/per-component performance cohort.
This replaces the original Ir continuation, not its preregistered history.

## Results

**NO-GO on both apps and the two-app bet.** Neither native interval resolves
a gain. The correctness failures independently prevent acceptance. Numbers
below are diagnostic, not accepted production speed/support claims; the
historical accepted three-unit interpreter price is unchanged.

### Native YJIT wall signal

Ruby 4.0.7, Rails 8.1.4 in both apps, startup YJIT, CPU 2, ordinary heap/GC.
Every block completed all three fresh processes and every process completed
10 warmups plus 10 timed full Rack requests. Statistics/coverage were enabled
only for ten additional requests **after** timing. Pins are unchanged in
both cohorts; no counted request, process, block or outlier is excluded.

| App / route | Four block on/off deltas (%) | Mean (%) | Exploratory t95 (%) | Decision |
|---|---|---:|---|---|
| Blog `/articles/1` | +12.408834, +10.010510, +12.608678, +7.866773 | **+10.723699** | **[+7.158094, +14.289304]** | resolved slowdown in this protocol |
| Fizzy `/buckets` | +11.410825, +6.911158, −5.512694, +16.019755 | **+7.207261** | **[−7.526668, +21.941189]** | unresolved, not a gain |

The mean flanking same-arm drifts are −1.428541% (blog) and −2.228427%
(Fizzy), with t95 [−6.607145,+3.750062]% and [−27.047416,+22.590562]%.
Fizzy's third off flank falls 23.16%; retain the block, do not trim it.
All requests, JIT/GC endpoint counters and block arithmetic are retained in
the numeric export. Twelve process means per app are not twelve independent
on/off effects; the inference has four block replicates, three degrees of
freedom.

Coverage after timing: every blog on worker installs all 17 AR units and
records Article/Comment/form/token/collection hits **10/20/10/40/10**. Every
Fizzy on worker installs 38 of the 45 AR units, activates token/collection,
and hits eight distinct units (IDs 7/8/12/24/39/41/45/46); the other emitted
units are not claimed as exercised. No runtime refusal. Build-unit census,
installed-unit census and exercised-unit census are distinct.

One launcher failure is retained: invoking the driver by a relative path
made its child look for the driver inside the app. It failed before app boot
or any request. The absolute entry-point invocation corrected that launch;
there was exactly one **measured** native cohort per app, no measured retry
to rescue a result. This is a disclosed departure from the preregistration's
blanket refusal to continue after infrastructure failure, not discarded data.

### Correctness controls

- **Blog:** both seeded off/off companions are exact. On matches full
  response bytes/headers, ordered SQL, effects, events, app/framework load
  census, terminal completion and framework ancestry (1,843/1,857 holders),
  but fails the complete cold feature comparison: on alone loads
  `ar_shadow.rb`, `ar_instantiate.rb`, `ar_guard.rb`. Both **192-pair**
  controls (ordinary and render subscriber) are equal with nonzero render
  hits and the original intentional 62 collection fallbacks. Raw entropy
  still rejects; it is not normalized away.
- **Fizzy:** both seeded full natural-login/three-GET response sequences
  match byte-for-byte including headers. All 128 captured ordered SQL events
  match, but **12 lazy cached-bind payloads per worker are unavailable**;
  the Proc is not called or recast, so this is incomplete SQL evidence, not
  a passing SQL certificate. Complete cold features differ by the same
  on-only AR files. Terminal `solid_cache_entries` state differs even
  off/off. Completion itself reports completed, and declared entropy errors
  are empty; neither excuses the unequal state. Raw entropy rejects.

No Lowrail-feature filtering, lazy-bind exemption or terminal-effect waiver
was introduced. The old isolated artifact's passing cold gates cannot be
borrowed by the current 20/47-unit plain builds.

### Diagnosis and stopping decision

The requested ten-warmup protocol is **not steady-state YJIT**. During each
ten-request blog window, off compiles about 3,664 blocks and on 4,211.
Mean recorded compiler time is **97.00 ms off versus 114.20 ms on** per
ten requests, while full wall time is **136.02 versus 149.72 ms**. The extra
17.20 ms of compilation is large enough in magnitude to cover the 13.70 ms
wall increase. Compilation is deliberately charged, not subtracted to
manufacture a favorable result. Both arms have only one minor collection
across six windows; measured allocations remain lower on (about 1,903
versus 2,279/request). Thus the interpreter/allocation saving does not
translate into a gain in the requested short YJIT windows.

What YJIT already removes versus what Lowrail adds must not be conflated:

| Lowered work / hot path | Source-level saving and retained/additional work |
|---|---|
| Form (one/show) | Avoids ordinary FormBuilder/tag assembly for the certified blank form. Adds Ractor/epoch/site/options/actual-holder checks, reflective ivar reads and captured `instance_exec` dispatch. URL generation, CSRF generation and escaping remain live. |
| Token (four/show) | Replaces hidden-input attribute/tag assembly, not CSRF cryptography. Adds pre/post-live-code holder/epoch checks, three reflective ivar reads and one captured view context per token; prior allocation diagnosis found these largely cancel its object saving. |
| Collection (one/show) | Removes only nonnil-template/no-layout branches. Iterator/preloading, local writes, template dispatch, notifications and output objects remain; adds Ractor/epoch/renderer-holder checks. This is a small branch specialization, not compiled whole-view rendering. |
| AR (three loaded records/show) | Retains real AR objects, attribute construction, casting/callback/instrumentation behavior. Adds a per-model method, plan validity/schema epoch checks, and per-row current-plan checks; caches the attributes builder. |

Source audit: [form](../../gem/lib/lowrail/form_scaffold.rb),
[token/collection](../../gem/lib/lowrail/render_units.rb),
[AR](../../gem/lib/lowrail/ar_instantiate.rb), and the existing
[reflective/context allocation diagnosis](token-allocation.md).
YJIT compiles Ruby helper/control-flow paths instead of paying interpreter
bytecode dispatch, so interpreter Ir saved is not evidence of the same
native saving. **These observations do not identify which semantic branches
YJIT folds away.** No per-method machine-code capture or controlled component
ablation was taken, so attributing the whole loss to "YJIT already removed
the form work" or assigning a measured nanosecond guard/delivery cost would
be invented. The surviving allocation reduction specifically contradicts
the claim that YJIT removes all of that work.

Measured added compilation is 17.20 ms/ten blog requests; separate steady
guard, native-boundary and delivery overheads are **unpriced**, not zero.
All three render observer seams are installed in off too, so their shared
prepend/dispatch cost cannot be assigned wholly to on. AR method delivery
and its runtime files are on-only. One-time passive admissions occur during
warmup, not in the measured windows; do not add their witness seconds to
the timed slowdown. No new ablation is started after the parking decision.

Fizzy's work removed is tiny in this route: about 8,998 objects/request on
versus 9,001 off. Compiler time averages 85.89 versus 83.92 ms per ten
requests; five of six on windows have a minor collection, versus none off.
Large process/flank variation and this different GC mix leave its wall
effect unresolved. These are observations, not a causal attribution to
any one guard, delivery hook or YJIT optimization. No ablation isolates those
costs, and no saturated-YJIT gain/loss is established by these cohorts.

**Stop this bet.** No longer-warmup rescue, second cohort, new pass, default
or quarantine change. Real-Puma throughput is not run: neither block result
is positive, and correctness gates also fail. This does not contradict the
separate older-source/older-protocol Puma result.

## Evidence and reproduction

[Sanitized numeric export](sealed-yjit-gate-results.json): all 240 timed
request samples (120/app), 24 workers' JIT/GC endpoints, block estimates,
coverage, cold comparisons, manifest/lock/entropy pins and raw-record hashes.
Private raw records retain literal response/cookie/SQL/database data; they
are not published. No configs or generated fixture secrets are exported.
Native measurement harness revision:
[`b41384c`](https://github.com/thomasklemm/lowrail/commit/b41384c107de4caae63dedd1ac9bc0659ece7cd7).
Automatic commit trailers were removed before publication, preserving each
tree/date and the preregistration sequence; the export maps the original
recorded revision to this identical-tree published commit.
Final harness-only cleanup fixes relative-path child invocation and scopes
the sealed-epoch deopt assertion to render units (AR has its own schema/
method epochs). All units' counters remain recorded; cold/SQL/response
comparators are unchanged. Neither edit remeasures or rescores these results.

Successful native commands, with private JSON fixture configuration (app,
artifact, CPU 2, route, environment and seed directories):

```sh
mise exec -- ruby /home/user/workspace/repo/bench/experiments/sealed_yjit_gate.rb \
  /tmp/sealed-yjit-blog-config.json /tmp/sealed-yjit-blog-native-measured
mise exec -- ruby /home/user/workspace/repo/bench/experiments/sealed_yjit_gate.rb \
  /tmp/sealed-yjit-fizzy-config.json /tmp/sealed-yjit-fizzy-native
```

Both return `coverage:true, source_unchanged:true, native_positive:false`.
Independent Python recomputation from the 24 workers exactly reconciles
both means and t95 intervals. Existing harness checks:
`mise exec -- ruby bench/screen_test.rb` — 5 runs/95 assertions;
`mise exec -- ruby bench/request_pairs_test.rb` — 17 runs/312 assertions;
zero failures/errors/skips. These are harness checks, not passing app
correctness gates or a speed claim.
