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

## Results

Not measured at preregistration.
