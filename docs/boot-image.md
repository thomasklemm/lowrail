# Bet H: boot image and worker memory

**2026-10-21 verdict: kill this Ruby-level whole-boot ISeq replay. Keep
prefork `Process.warmup` as a separate memory candidate, not a Lowrail win.**
Warm Bootsnap already removes much of the observed startup cost. The image
with path caching and consumed-blob release is still 8–13% slower on the
four successful full-page screens and retains more RSS. It also bypasses a
foreign loader in a concrete counterexample. Nothing here changes the runtime
delivery, app code/config, default passes, or production admission. The later
branch-only opt-in Puma helper is separate from replay; see the bounded
follow-up below.

Work stays on `thomasklemm/boot-image`. Initial probe:
[`ff15690`](https://github.com/thomasklemm/lowrail/commit/ff15690);
replay/guards:
[`c06ab16`](https://github.com/thomasklemm/lowrail/commit/c06ab16);
retained census/Puma diagnostic:
[`cedbc65`](https://github.com/thomasklemm/lowrail/commit/cedbc65).
[Sanitized records and every observed census difference](boot-image-results.json)
include rejected requests/cohorts, not just these medians.

## Scope and measurement

Ruby **4.0.7**, Rails **8.1.4**, Linux orb, YJIT enabled at process startup
in every final arm. Three fresh-process samples per timing arm, rotating
order after a separate capture and Bootsnap priming boot. Capture/prime are
retained but excluded from medians. OS file caches are warm; these are not
cold-disk, throughput, JIT-flat or accepted request-benchmark claims.
Some setup/discovery ran concurrently: this is a directional native screen,
not a precision comparison of close arms. No Callgrind was used.

Time starts before spawning Ruby and includes Bundler, production eager
initialization and the first completed Rack response/body. It excludes
database preparation, asset builds, network listening and TLS. RSS is read
from `smaps_rollup` after ten additional requests and full GC, before census.
Boot-only times, individual samples, PSS and dirty pages are in the export.

| App and source pin | Route / fixture |
|---|---|
| Blog, [Roundhouse bb90df2](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9) `fixtures/real-blog` | `/articles`; generated through `script/corpus`, three articles/comments |
| Campfire r81, [02023b0](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa) | `/session/new`; production SQLite fixture |
| Fizzy, [6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9) | `/session/new`; disposable production SQLite databases |
| Lobsters, [ruby-bench 351a39b](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716) | `/`; requested bet-C pin, upstream shipped DB restored into SQLite `:memory:` |
| CASA, [b584d2e](https://github.com/rubyforgood/casa/commit/b584d2e6e6ebffe382f34c2ec202d20384d035ca) | `/users/sign_in` fails; separate `/health` succeeds. External throwaway credentials and schema-only local PostgreSQL |

Campfire, Lobsters and CASA do not ship Bootsnap in these bundles. Their
Bootsnap comparison uses an external dependency-only Gemfile adding Bootsnap
1.26.0/msgpack without changing other pins. Blog has 1.26.0; Fizzy retains
1.18.4. These are not an artificial common Bootsnap-version comparison.
No application source or configuration file was patched.

“Lowrail now” means current **default**, with the same warm Bootsnap and
startup JIT mode. All five manifests have **zero units**: do not credit
differences from Bootsnap to lowering. Blog/Campfire/Fizzy/Lobsters used CLI
default builds. CASA's second build subprocess could not use the external
credential fixture; its empty default control manifest was instead written
through the public compiler. That is not a successful CASA CLI build claim.

## Production startup and warm RSS

Cells: **seconds to first completed response / RSS MiB**, median of three.
Prototype here means `image_paths_release`: image replay plus Bootsnap
path/YAML/JSON caches (its ISeq cache off), deleting each consumed binary
blob. All four routes below return HTTP 200 in every arm.

| App | Plain | Bootsnap | Lowrail now | Prototype |
|---|---:|---:|---:|---:|
| Blog | 3.025 / 159.5 | 2.085 / 163.1 | 2.033 / 163.3 | 2.261 / 171.0 |
| Campfire r81 | 3.556 / 172.8 | 2.302 / 171.6 | 2.285 / 170.7 | 2.501 / 181.7 |
| Fizzy | 3.517 / 164.3 | 2.372 / 162.7 | 2.413 / 160.4 | 2.590 / 168.7 |
| Lobsters | 3.660 / 203.2 | 2.455 / 197.5 | 2.577 / 202.4 | 2.768 / 205.0 |

CASA's sign-in is **HTTP 500 in all arms**:
`Sprockets::Rails::Helper::AssetNotFound`, missing `apple-icon-57x57.png`.
It boots, but these are **not successful first-request results**. They remain
visible rather than repairing app assets/config to get green:

| CASA cohort | Plain | Bootsnap | Lowrail now | Prototype |
|---|---:|---:|---:|---:|
| Rejected sign-in, n=3 | 6.216 / 236.3 | 3.921 / 230.3 | 3.433 / 231.8 | 3.834 / 239.7 |
| Separate `/health`, HTTP 200, n=1 | 6.366 / 236.8 | 3.574 / 231.3 | 3.627 / 231.7 | 4.403 / 254.0 |

The single health screen is narrower, not a replacement success for sign-in
or a precision estimate. Its health check creates its normal singleton row
once; cross-arm DB-state equivalence has not been certified.

### Image ablations

Same units and three-sample cohorts as above; CASA entries still denote
failed sign-in. These retain the losing variants rather than selecting only
the best RSS result. All images are trusted local Marshal outputs.

| App | Pure image | Image + path caches, blobs retained | Image + paths, consumed blobs released | Captured files / image MiB |
|---|---:|---:|---:|---:|
| Blog | 2.719 / 178.7 | 2.257 / 179.2 | 2.261 / 171.0 | 2,072 / 12.7 |
| Campfire | 3.091 / 189.1 | 2.566 / 191.6 | 2.501 / 181.7 | 2,427 / 14.5 |
| Fizzy | 3.162 / 180.5 | 2.722 / 182.8 | 2.590 / 168.7 | 2,607 / 16.2 |
| Lobsters | 3.172 / 219.8 | 2.823 / 223.5 | 2.768 / 205.0 | 2,806 / 17.0 |
| CASA (500) | 5.586 / 270.2 | 4.342 / 272.0 | 3.834 / 239.7 | 4,354 / 22.3 |

Pure-image hits per boot/warmup are 2,072 / 2,427 / 2,627 / 2,806 / 4,360
in app order. More hits than captured files in Fizzy/CASA include repeated
loads. Release mode gets 2,013 / 2,390 / 2,548 / 2,758 / 4,317 hits.
This really exercised bytecode delivery, rather than timing a no-op image.

The image stores native top-level ISeqs observed during a real eager boot
and warmup, Ruby identity, entry gem versions/paths, load path, source hashes
and compiler options. Entry validation hashes every file; use-time validation
hashes each served file again. It retains MRI's require/path machinery.
It **does not** serialize a live heap, dynamic `eval` methods or a relocatable
image: absolute paths remain required. Existing Lowrail relocation delivery
in [loaders.md](loaders.md#deploy-paths) is not replaced or weakened.

One separate blog `strace -c -e trace=%file` probe counts **201,265 plain /
74,630 Bootsnap / 74,663 image+paths+release** file syscalls. `stat` alone is
2,843 / 3,171 / 5,242. This prototype has neither zero per-file stat nor zero
path search; no such implementation or performance is claimed.

## Prefork memory: the surviving candidate

Actual preloaded Puma, two workers, one request thread each. The master first
boots and warms the app; all arms perform full GC before fork. Treatments are
ordinary fork, additional `GC.compact`, or `GC.compact` + `Process.warmup`.
Each worker serves at least ten requests and performs GC at its tenth.
Read `/proc` for master and both live workers. These are **one process tree
per treatment**, not replicated/control-qualified memory wins.

Cells: **mean worker RSS / total master+two-workers PSS, MiB**. PSS apportions
shared pages; summing worker RSS would double-count shared memory. Raw private
and shared dirty-page counts and unequal worker request counts are exported.

| App | Ordinary fork | + `GC.compact` | + compact + `Process.warmup` | Total PSS change, warmup vs ordinary |
|---|---:|---:|---:|---:|
| Blog | 138.5 / 236.8 | 139.3 / 238.8 | 131.8 / 226.9 | −4.2% |
| Campfire r81 | 151.1 / 276.9 | 155.6 / 268.4 | 145.1 / 249.5 | −9.9% |
| Fizzy | 161.4 / 259.6 | 160.1 / 260.6 | 150.6 / 246.7 | −5.0% |
| Lobsters | 253.5 / 443.4 | 251.0 / 419.0 | 240.6 / 392.8 | −11.4% |
| CASA `/health` | 232.1 / 379.1 | 232.9 / 370.6 | 210.2 / 338.5 | −10.7% |

Every request in this table is HTTP 200. No ISeq replay/lowering is active:
this is Ruby's existing warmup facility, not a Lowrail implementation. Compact
alone does not consistently help. We have not separated warmup's component
effects, measured post-fork JIT growth under sustained load, or demonstrated
that this belongs in a separate product rather than server configuration.

Puma pins: blog/CASA 8.0.2, Campfire 6.6.1, Fizzy 6.5.0; Lobsters' external
dependency wrapper adds 8.0.2. Lobsters initially had two harness startup
failures (Puma require order, missing default PID directory), then HTTP 500
`no such table: keystores`: ActiveRecord's post-fork/thread connection
replacement loses the upstream in-memory DB. The final memory-only wrapper
restores the same shipped DB at the first worker request, not app config.
Its per-worker DB copy is included in RSS/PSS and explains why this differs
from single-process startup memory. The failed cohort remains in the export.
CASA's initial wrong-route HTTP 404 memory cohort is likewise rejected, not
pooled with its separate successful `/health` cohort.

## Exactness: finite agreements, real failures

Separate census workers observe named modules **after warmup**, without
resolving autoloads. Two stock, two pure-image, two image+paths+release runs
per app. No post-hoc response normalization or excluded header is used.

| App | Stock loaded features, ordered | Stock non-autoload constants | Named app method holders | Pure-image snapshot | Paths+release additions: features / constants |
|---|---:|---:|---:|---|---:|
| Blog | 2,262 | 8,549 | 19 | All three match stock, both runs | +4 / +14 |
| Campfire | 2,610 | 10,041 | 211 | All three match stock, both runs | +28 / +82 |
| Fizzy | 2,517 | 10,028 | 256 | All three match stock, both runs | +5 / +14 |
| Lobsters | 2,989 | 10,724 | 194 | All three match stock, both runs | +16 / +53 |
| CASA (500 route) | 4,454 | 15,016 | 576 | All three match stock, both runs | +30 then +29 / +82 |

Stock/stock also agrees for these snapshots. Method rows include own names,
visibility, source locations, parameters and arity, including named generated
attribute/association modules. They are **not** an exhaustive method-body,
anonymous-module, callback/event or intermediate-boot equivalence check.
Paths+release app method metadata agrees, but its loaded-feature order and
constant set do not: Bootsnap instrumentation adds modules and loads files
earlier. Every sequence edit and added/removed constant is exported, including
CASA's one-file difference between repeats.

**All image runs change the compiler method chain**, adding
`BootImage::Delivery#load_iseq`. A direct public-hook counterexample proves
why snapshot agreement is insufficient: stock's existing `load_iseq` loader
transforms a file to return `"hooked"`; image replay instead returns `"ab"`
with one hit and never delegates to that loader. This is an exactness failure,
not a tolerable boot optimization. The diagnostic is explicitly marked
rejected and must not be used as an application preload.

The finite fallback probes do retain stock behavior for changed Ruby/gems/
load path, changed source at entry **and after entry**, missing/corrupt image,
corrupt binary, and changed compiler defaults after entry. Normal probe:
one hit. Those refusal cases: zero hits. None certifies opaque loader policy,
translators, warnings, trace observers or future mutation of load-path policy.

Raw first-response comparisons are **not exact**, including stock/stock:
blog/Campfire/Fizzy/Lobsters body digests differ, as do `etag`, `set-cookie`,
`x-request-id`, `x-runtime` (Lobsters uses capitalized header names). CASA's
error-page body agrees, but request ID/runtime differ. The export lists all
observed differing header names and hashes the original header values so
cookies are not published. Entropy was not controlled in this cheap screen;
these differences are neither blamed on the image nor waived as correctness.

Blog's own suite was separately executed off/image: **21 tests, 54 assertions
each, zero failures/errors/skips**, identical per-test results and identical
SQL identity/multiplicity map (**125 queries**); image records **1,730 hits**.
This is finite suite evidence, not full production request equivalence.
Other own suites, DB-state snapshots, lazy-load/reload behavior and Thermos
review were not completed. **No main/runtime promotion is proposed**, so a
losing, non-exact experiment is not sent through those promotion gates.

## Component decisions

| Piece | Screen / exactness result | Verdict |
|---|---|---|
| Whole-boot compiled app/gem/Rails image | Thousands of actual hits; slower/larger than warm Bootsnap; foreign loader bypass | **Kill this Ruby-level replay design.** Not a proof that a VM-supported image is impossible |
| Release consumed bytecode blobs | Reduces retained RSS versus holding the image; still larger than Bootsnap | Retain as diagnostic ablation, not a standalone win |
| Recorded require graph / zero-stat lookup | Feature order recorded; no executable graph or zero-stat resolver built. Current syscall probe does not improve on Bootsnap | **Defer**, no performance/exactness claim after image stop rule |
| Pre-resolved Zeitwerk map | Not implemented; no certified way here to suppress filesystem work while preserving lazy loading and callbacks | **Defer**, not declared impossible |
| Pre-generated attribute methods | Explicit Article/Comment generation changes observed own method rows **108→375 (+267)**. Blanket all-model generation additionally fails on missing `action_text_rich_texts` although stock boots | **Kill unconditional early generation**; it changes observable method availability and schema access timing |
| Association method replay | Named generated methods observed, but no closure/method-body replay implemented | **Defer**; no independent win or exactness claim |
| Arbitrary frozen literals | Compiling `"a" << "b"` yields `"ab"` normally, **FrozenError** with freezing | **Kill blanket app freezing**. Existing generated code already uses scoped frozen-literal policy; no additional saving measured |
| Fewer duplicated method bodies / smaller ISeqs | Packing ISeqs does not deduplicate installed methods or dynamic eval bodies; not implemented | **Defer**, no claimed byte/RSS reduction |
| Prefork compact + warmup | Successful-page trees show 4.2–11.4% lower total PSS; n=1 each; compact alone inconsistent | **Keep candidate**, independently validate DB/output/own suites and realistic worker lifetime before proposing server integration |

## Bounded follow-up: explicit Puma warmup

Owner-approved follow-up, still **branch only**. The gem now offers an
independent opt-in helper; normal `lowrail/setup` never loads or calls it:

```ruby
require "lowrail/puma"
preload_app!
before_fork { Lowrail::Puma.warmup }
```

`warmup` attempts `GC.compact` + `Process.warmup` once per process. It returns
true on completion, false for a repeat, missing API or rescued StandardError;
a partial failure is not retried by another hook in that process. It neither
loads Rails/Puma nor changes the GC on require. This explicit API is independent
of lowering and `LOWRAIL`; the caller must opt in. Two public-interface tests
pass (six assertions), exercising real compaction/idempotence and failure/
unavailable-API behavior. Helper commit:
[`4cb1c8b`](https://github.com/thomasklemm/lowrail/commit/4cb1c8b).

### Repeated process trees

One fixed cohort: three rounds/app, each with **off-A / warmup / off-B** in
rotated order, **36 fresh process trees** total. Two Puma workers × one thread;
six off trees and three warmup trees per app. Same fixture routes and upstream
dependency pins as the original memory screen. Both arms require the helper;
only the warmup arm invokes it, through the real Puma `before_fork`. All 12
warmup invocations report completion. No replay, lowering, app/config-file
patch, added GC disabling or retry-to-green.

PSS/worker RSS below are medians across trees. Paired PSS percentages compare
each warmup tree with the mean of its two off controls; ranges retain every
round, including uneven worker request distributions and the large blog A/A
outlier. Warmup is lower than **both** controls in every round for all four
apps. This passes the requested repeatability screen, not a precision memory
or server-capacity claim. [All 36 records](prefork-warmup-results.json).

| App | Total PSS off → warmup, MiB | Mean worker RSS off → warmup, MiB | Paired PSS change, three-round range | First Puma response off → warmup, s | 5xx / responses |
|---|---:|---:|---:|---:|---:|
| Blog | 250.5 → 240.3 | 138.6 → 131.4 | −9.2% … −1.5% | 3.604 → 3.796 | 0 / 274 |
| Campfire | 288.7 → 267.2 | 151.2 → 147.2 | −8.8% … −2.6% | 4.121 → 4.477 | 0 / 300 |
| Fizzy | 260.6 → 245.0 | 160.1 → 148.3 | −6.5% … −4.9% | 4.082 → 4.267 | 0 / 213 |
| Lobsters | 440.0 → 395.8 | 251.7 → 241.3 | −12.1% … −7.7% | 4.498 → 4.643 | 0 / 248 |

Startup is measured from just before exec of the app Ruby process through
the first completed **Puma** response, including the master's original eleven
Rack warmup requests, server startup, readiness detection and sampling-client
startup. It is not the initial table's first Rack response. Hook medians alone
are **210 / 240 / 274 / 283 ms**, in app order. Worker GC still runs at request
ten and routing can send more requests to one worker; all actual counts remain
in the export. Blog's off/off PSS spread reaches 9.24%; it is not discarded.
No steady-state worker lifetime or additional workers-per-box is inferred.

### Real-server RPS and exact-output gate

One cohort per supported app uses published `script/rps`
[`96b447f`](https://github.com/thomasklemm/lowrail/commit/96b447f730fcba7e698ad76ae55c740de2fca82f)
in an isolated detached worktree, not a merge of bet-A changes. The external
[Puma adapter](../bench/experiments/prefork_puma.rb) enables preloading and the
same observer in every arm, calling the helper only for `on`. It records each
actual master hook's completion/time outside app state. No app Puma/config.ru
file is edited. Public compiler-created empty YJIT artifacts (zero files/units)
prevent another Lowrail pass from confounding the treatment.

Protocol fixed before load: **ten rotated off-A/on/off-B rounds**, four
workers × one thread, concurrency 16, 5-second warmup and 20-second timed
windows, server CPUs 0–3/client 4–7, pinned oha 1.14.0. Retained blog fixture
and fresh GET-only seed for `/articles/1`; canonical Campfire dependency-only
overlay and fresh authenticated room fixture for `/rooms/486777696`.
Cold/warm exact samples use bet A's two-seed validator with all Rack headers;
timed HTTP uses natural entropy. A regression beyond the cohort's A/A band
kills the candidate; a failed exact gate is never a throughput win.

**Blog complete:** A/A −0.10% [−4.32%, +4.94%], noise floor **4.94%**.
On/off +6.09% [+3.00%, +9.05%] is **not a resolved speed win** because its
whole interval does not clear that floor. No detected RPS regression.
Median off-A / on / off-B is **1550.8 / 1654.0 / 1553.3 RPS**. Cold samples
from all 33 servers and warm samples from all 30 timed servers pass both seeds'
exact status/body/all Rack-header checks. All eleven on-arm master hooks completed;
controls never invoke warmup. **951,540 timed + 193,418 warmup HTTP200**,
zero load/transport errors. [Sanitized windows and paired summary](prefork-rps-results.json).

**Status:** Campfire RPS cohort running. Published bet A currently has **no
Fizzy/Lobsters HTTP validation adapters**; their requested RPS checks are
blocked pending those adapters, not substituted with login/empty pages or the
in-process Rack screen. No four-app promotion can follow the current results.

## Reproduction and retained boundaries

The exploration-only driver is [boot_image.rb](../bench/experiments/boot_image.rb).
Use `script/corpus` with the pins above, dependency-only external wrappers
where noted, prepared disposable DBs/assets, and external CASA credentials.
Do not repair app code/config. Configuration is private because it includes
credential/environment inputs. Its public shape is:

```json
{
  "app": "/absolute/corpus/app",
  "path": "/articles",
  "env": {"BUNDLE_GEMFILE": "/absolute/external/Gemfile", "RUBY_YJIT_ENABLE": "1"},
  "samples": 3,
  "census": false,
  "modes": ["capture", "plain", "bootsnap", "lowrail", "image", "image_paths", "image_paths_release"]
}
```

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/boot_image.rb run PRIVATE_CONFIG NEW_PRIVATE_DIR
# Separate census: census=true; samples=2; capture/plain/image/image_paths_release.
# Memory: add treatment=none|compact|warmup to a private config.
amp orb service start boot-puma --command 'mise exec ruby@4.0.7 -- ruby /absolute/lowrail/bench/experiments/boot_image.rb puma-start /absolute/PRIVATE_CONFIG /absolute/NEW_PRIVATE_DIR'
mise exec ruby@4.0.7 -- ruby bench/experiments/boot_image.rb puma-sample /absolute/NEW_PRIVATE_DIR /articles
amp orb service stop boot-puma
```

Optional `before_boot` loads the external CASA fixture; `lobsters_database`
names ruby-bench's shipped SQLite fixture. Keep raw responses, credentials,
cache binaries and DB files private. The checked-in JSON contains timing/
memory samples, body/header-value digests, complete **observed** census
differences, fallbacks and failed cohorts. It is evidence for the stop/keep
decisions, not a manifest of supported whole-app images.
