# Guard ceiling: the guards matter only where the ceiling does

2026-10-21. **Deliberately unsafe exploration, not a runtime option, support
claim or speed claim.** Ruby 4.0.7, Rails 8.1.4, startup YJIT, CPU 2.
The [sanitized allocation/equality appendix](guard-ceiling.json) retains all
80 workers from five screens, including the rejected broad Fizzy diagnostic.
Private configurations, login inputs, entropy values, response bodies and
literal headers are not exported.

## Result

Objects per request, except Fizzy's **sum of six route medians**, not a
measured median of vector totals. Off is off-A; off-B is its independent
control. Ceiling = off-A − unguarded; guard cost = guarded − unguarded.

| Specimen | Off-A | Guarded | Unguarded | Off-B | Ceiling | Guard cost | Ceiling consumed | Exactness |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Blog `/articles/1`, sealed form/token/collection + AR | 2,387 | 2,044 | 1,971 | 2,387 | 416 (17.43%) | 73 | 17.55% | PASS |
| Fizzy six GETs, suffix-only guard elision | 209,379.5 | 210,540 | 209,320 | 209,370 | 59.5 (0.0284%) | 1,220 | 2,050.42% | FAIL, including A/A |
| Campfire room, 19 instantiation units after ARShadow fix | 15,523 | 15,523 | 15,525 | 15,524 | −2 | −2 | N/A: no positive ceiling | FAIL, including A/A |
| Lobsters `/newest`, guarded URL program | 14,307 | 239,235 | 14,233 | 14,306 | 74 (0.517%) | 225,002 | 304,056.76% | PASS |
| Lobsters `/hottest`, guarded URL program | 14,739 | 187,347 | 14,239 | 14,739 | 500 (3.392%) | 173,108 | 34,621.60% | PASS |

The requested signed expression
\((\mathrm{unguarded}-\mathrm{guarded})/(\mathrm{off}-\mathrm{unguarded})\)
is the **negative** of the positive consumed share above: −17.55%,
−2,050.42%, −304,056.76%, −34,621.60%, respectively for the positive-ceiling
rows. Campfire's algebraic value is −100%, but dividing two unresolved
negative two-object differences has no useful economic interpretation.

**Recommendation:** keep block-link and Campfire instantiation killed as
performance bets. Free guards do not create a material allocation win there.
Blog already retains 343 of its 416-object ceiling; guards are not its main
limitation. Lobsters demonstrates a genuinely prohibitive guard cost, but
even free certificates leave only 0.52% / 3.39% allocation ceilings for this
version of the program. Cheap correct guards (public UnboundMethod equality
or a method token, with visibility/state/mid-request checks still accounted
for) are worthwhile only on units with a material gross ceiling. This study
does not establish a runtime-speed ceiling from object counts.

## Fixed method and unsafe boundary

- Three fresh-process rounds in order **off-A, guarded, unguarded, off-B**;
  four separate statistics-enabled coverage workers precede timing. Blog
  uses 200 warmups and 300 samples/worker; the others use 20/30. No discarded
  workers, normalization, outlier removal or retry-to-green.
- Exact integer `GC.stat(:total_allocated_objects)` deltas surround complete
  requests, including body consumption. GC stays enabled. These are actual
  counts, not allocation sampling, but background/cache activity causes the
  observed min/max ranges below; do not call every request deterministic.
- Same prepared DB copies, production boot, dependency lock, artifact and
  fixture controls in all arms. No application source/configuration edits.
  Timed entropy remains native. Two separate untimed validation requests per
  route use the existing source-pinned seed-0/seed-1 companions. Actual
  status, body SHA256 and sorted all-header SHA256 must match within every
  round. No header stripping, body rewriting or response normalization.
- `explore_unguarded: true` is accepted only by the screen with the exact
  [`guard_ceiling.rb`](../bench/experiments/guard_ceiling.rb) hook. Only its
  unsafe worker receives `LOWRAIL_EXPLORE_UNGUARDED=1`. The hook rejects an
  ordinary preload and an arm/flag mismatch. No file under `gem/` reads this
  flag, and this branch changes no runtime or compiler source.
- Ordinary installation, observation, warmup and natural admission happen
  first. Blog then bypasses form/collection/token predicates, the token's
  post-live validity/fallback branch, and AR entry validity/current checks.
  Campfire bypasses only AR entry validity/current checks; its original STI
  fallback remains. Live token generation, escaping, callbacks and output
  construction remain live. Thus this is the measured bypassed-check ceiling,
  not a claim that every setup or argument-shape branch was removed.
- Fizzy's causal arm bypasses only `BlockLinkSpecimen.predicate`, leaving
  common compiler/template/ISeq/witness/buffer observers identical in all
  arms. Lobsters installs the **same published guarded program** in both
  selected arms, then overrides only `Certificate.valid?` after warmup.
  It retains live `url_options`, `_routes`, strategy execution and shape
  fallback branches. Matching coverage proves no different fallback mix on
  these requests. This is not a mutation/adversarial correctness certificate.

The runners are based on the approved native-bench tooling at
[`bfc682b`](https://github.com/thomasklemm/lowrail/commit/bfc682b), with the
explicit fourth arm and post-warmup callback added on this branch. Full
private result/protocol/log hashes and source/runtime/artifact pins are in
the appendix. Recorded Git revisions for early screens precede final
commits/rebase; **captured file hashes**, not HEAD alone, identify executed
code. The complete private file indexes are covered by result hashes; the
export also records normalized-path index hashes and runtime-source hashes.

Native wall A/A maximum round spreads were 10.73% blog, 4.37–15.51% Fizzy,
7.54% Campfire and 7.04% / 3.78% Lobsters. Wall time is diagnostic only;
no YJIT-flat, interpreter-Ir or published speed gate is claimed. **Zero
Callgrind cohorts were launched.** Slot 2 remains unused: the allocation
question is answered without an instruction-price cohort; no speed claim
is promoted from an exactness-rejected or tiny-ceiling specimen.

## Per-specimen evidence

### Blog

Post-sealed-dispatch-fix runtime
[`cd82a5d`](https://github.com/thomasklemm/lowrail/commit/cd82a5df8aaa45c4a5b26fea3a63df39ae316650),
before the later ARShadow disabled-predicate fix. This is the coordinator's
accepted 73/416 result, not silently remeasured against a different base.
The 20-unit artifact contains 17 AR units plus sealed form/token/collection;
no delivered-file lowering. Both selected coverage arms have Article ×1,
Comment ×2, form ×1, token ×4 and collection ×1 per request, zero fallbacks.
Every status/body/header comparison and companion control passes.

| Arm | Median objects [min, max] |
|---|---:|
| Off-A | 2,387 [2,380, 2,400] |
| Guarded | 2,044 [2,036, 2,058] |
| Unguarded | 1,971 [1,964, 1,981] |
| Off-B | 2,387 [2,379, 2,398] |

Retained archive SHA256
`b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`;
source pin `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`;
lock `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
Fresh `BlogShowGetOnly` production data and normal assets precompile; public
artifact rebuilt with `--sealed --jit yjit`. A fixed disposable fixture
secret is supplied before boot, not patched into application configuration.

### Fizzy: only the suffix comparison prices its scan

Same six-template block-link delivery as the
[existing interpreter study](block-link-specimen.md), rebuilt/discovered in
YJIT mode. Both selected arms have **24 suffix hits over 19 sites per vector**;
four cache-elided sites stay at zero. No extra fast paths are invented.

| GET (fixture IDs abbreviated) | Off-A | Guarded | Unguarded | Off-B | Exact |
|---|---:|---:|---:|---:|---|
| `/buckets` | 46,272 | 46,744 | 46,240 | 46,272 | PASS |
| filtered `/bubbles` | 77,938.5 | 78,341 | 77,927.5 | 77,931 | FAIL |
| `/account/users` | 12,524 | 12,618 | 12,518 | 12,522 | PASS |
| `/workflows` | 16,767 | 16,862 | 16,763 | 16,767 | PASS |
| `/notifications` | 10,756 | 10,804 | 10,752 | 10,756 | FAIL |
| bubble detail | 45,122 | 45,171 | 45,119.5 | 45,122 | FAIL |

The failing routes differ in body **and** headers, including off/off;
status is always 200 and companion controls pass. This is a full-vector
red gate, not proven specialization divergence and not proven harmless
entropy. The remaining cause is unestablished. Actual digests/checks/ranges
are retained; no mismatch was normalized or rerun away.

An earlier **broad observer-elision diagnostic** produced summed medians
209,381.5 / 210,526 / 63,509 / 209,380. It removed work that the ordinary
**off arm also pays**: compiler/ISeq/source observations and common
invocation witnesses. It is retained as `fizzy` in the appendix, explicitly
rejected as a causal scan/token-savings estimate, with the same full-vector
red exactness gate. The primary `fizzy-suffix` screen changes only the
on-only post-capture predicate. Its 59.5-object ceiling cannot rescue the
already-killed block-link bet, regardless of that predicate's cost.

### Campfire

Rebuilt on
[`acc130d`](https://github.com/thomasklemm/lowrail/commit/acc130d903ffd867e64908c9dda237098973de00),
so the disabled ARShadow predicate no longer allocates an Array per hit.
Artifact: 19 public instantiation units, no delivered-file lowering.
Both selected coverage arms complete 52 instantiations/request and retain
two original Room STI fallbacks. The earlier +52-object shadow tax is not
being mislabelled as guard cost.

| Arm | Median objects [min, max] |
|---|---:|
| Off-A | 15,523 [15,513, 15,569] |
| Guarded | 15,523 [15,513, 15,577] |
| Unguarded | 15,525 [15,510, 15,575] |
| Off-B | 15,524 [15,511, 15,576] |

Existing `CampfireRoomCompanion`/policy, session-RNG companion before natural
login, and the existing login entropy context are shared across arms.
These cold controls do **not** establish warm equality: every round/seed
body/header comparison fails, including A/A; all statuses are 200 and
control evidence passes. Neither a guard saving nor exactness is claimed.
The dedicated disposable Redis is local to this orb, with no persistence.

### Lobsters

Exact guarded source and external dependency wrapper/lock from
[`919931e`](https://github.com/thomasklemm/lowrail/commit/919931e0f02b338aadc6045e0290a7b70bb59a3e).
The unsafe arm uses that **same** guarded continuation, not the older
[`db5a7a8`](https://github.com/thomasklemm/lowrail/commit/db5a7a8)
program with its different root-URL boundary behavior. Therefore
the older −165/−800 figures are not pooled with the −74/−500 measured here.
Separate coverage workers match at 91 hits/newest request and 50 hits/hottest
request, zero fallbacks. All three rounds and both seeds pass exact
status/body/all-header checks in **all four** arms.

| Route | Off-A [min, max] | Guarded [min, max] | Unguarded [min, max] | Off-B [min, max] |
|---|---:|---:|---:|---:|
| `/newest` | 14,307 [14,297, 14,316] | 239,235 [239,229, 239,243] | 14,233 [14,225, 14,245] | 14,306 [14,299, 14,316] |
| `/hottest` | 14,739 [14,739, 14,747] | 187,347 [187,347, 187,347] | 14,239 [14,239, 14,247] | 14,739 [14,739, 14,747] |

Source: ruby/ruby-bench
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
`benchmarks/lobsters`; download the shipped `db/production.sqlite3` from
there, SHA256 `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
Do not load its historical SQLite-incompatible schema. Boot-prepared private
seed SHA256 `b90816703504429b1926c97c50a960ce9a29235b7543f3159fbc441ed1e9406b`.
Use tracked `fixtures/corpus/lobsters.Gemfile{,.lock}`, a rebuilt zero-unit
YJIT artifact, production `DATABASE_URL=sqlite3:<copied primary>`, and fixed
ordinary `HTTP_X_REQUEST_ID=lowrail-url-screen`. The source-pinned
`LobstersNativeValidation` companion is active only for untimed exactness.
The standalone programs are exploration setup, not units admitted by a
public Lowrail pass or a new `lowrail verify` support claim.

## Reproduction and validation

Follow [native-bench preparation](native-bench.md), with absolute private
seed/artifact/config paths. Build artifacts with the **executing Ruby and
JIT mode**; old copied artifacts are not transferable certificates. Add:

```json
{
  "explore_unguarded": true,
  "exploration_setup": "/absolute/repo/bench/experiments/guard_ceiling.rb"
}
```

For Fizzy also set `"guard_scope": "suffix"`, its frozen contexts, and the
existing block-link entropy policy. For Campfire acknowledge only a
dedicated disposable Redis via `CAMPFIRE_DISPOSABLE_REDIS=1`. List validation
policy files in `exploration_sources`; the native harness hashes runtime,
bench, artifact and setup inputs and checks them after every worker.

```sh
mise exec ruby@4.0.7 -- script/screen APP ROUTE... \
  --config PRIVATE_CONFIG.json --output NEW_PRIVATE_DIRECTORY \
  --warmup 20 --samples 30 --cpu 2
mise exec ruby@4.0.7 -- ruby bench/native_bench_test.rb
```

Blog uses `--warmup 200 --samples 300`. Full ranges, individual integer
allocation samples, exact digests/checks, coverage deltas, runtime/JIT pins,
private result/log hashes and diagnostic wall summaries are in the appendix.
Tests: 3 runs, 41 assertions, zero failures/errors/skips. A standalone hook
preload and non-screen unsafe invocation are refused. No app own-suite,
mutation or DB-state certification is implied by these request screens.

## DECISIONS (five lines)

1. Keep unsafe elision confined to the explicit exploration hook; never merge it into the default runtime.
2. Blog loses 73/416 objects (17.55%) to these guards; guard cost is secondary to its existing ceiling.
3. Keep Fizzy block-link killed: free suffix guards leave only 59.5/209,379.5 objects and full-vector exactness is red.
4. Campfire has no positive ceiling; Lobsters needs dramatically cheaper correct checks before reconsideration, with only 0.52%/3.39% gross allocation ceilings.
5. Retain all rejected measurements, normalize nothing, launch zero Callgrind cohorts and make no speed claim.
