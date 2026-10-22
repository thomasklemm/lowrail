# Bet Y: non-creating guards

## Prospective protocol (2026-10-22)

Start from main and compare the external Fizzy DirectSite overlay at
[`936cc46`](https://github.com/thomasklemm/lowrail/commit/936cc462ffa2586a45458f6efa69d9717f965fe8)
with the same overlay using the existing native `exact_class?` primitive.
Do not remove method-body, visibility, schema, reflection, scope, connection
or mid-request checks. An existing singleton class, even an empty one, refuses
the new path. No app source/configuration edits or production admission.

Inventory and screen the unchanged main blog form/token/collection units too.
The necessary private implicit calls stay live: public sends and captured
helper bodies are not equivalent to Rails dispatch. Do not replay bet K's
rejected combined form/constant candidate as a new result.

Use Ruby 4.0.7 / Rails 8.1.4. Build official Ruby with
`--enable-yjit=stats --disable-install-doc` for diagnostic counters; use stock
`mise exec ruby@4.0.7 --` for allocations and interpreter checks. Pin
`BUNDLER_VERSION=4.0.20` before Bundler, and assert actual JIT state after
boot in every worker. Certificates match each actual Ruby build/mode.
Two-seed exact status/body/all-header comparisons and positive fast-path
hits with zero fallbacks precede measurement. Keep strict query shadows in
untimed coverage only. Use 2,000 warm requests and 500 stats requests, matching
K; retain every worker and all premeasurement failures.

**Screen gate:** singleton-send fallbacks must fall clearly from F's old-on
value to the same fixture's off value or below (historical target about
243/request). No allocation or interpreter-Ir regression. Report side exits,
all invalidation reasons, code GC, new compilation and window ratio-in-YJIT
separately; fallbacks are not exits. New compilation means diagnostic stats,
not a JIT-flat price. No ZJIT execution/speed claim from YJIT counters.

Only if exactness, counters and interpreter non-regression pass, run **one**
Fizzy `/buckets` real-Puma cohort using the existing `script/rps` harness at
`b1e239f` and the `44a33c4` / `544ad8d` protocol: 4 workers × 1 thread,
concurrency 16, 5 s warmup / 20 s load, 20 rotated off-A/on/off-B rounds.
Require A/A RPS's 95% interval to contain zero; treatment's RPS lower 95%
bound must exceed the A/A upper bound. All coverage workers must prove JIT
active, hits > 0 and fallback 0 before load. Run A/A admission first, retain
all rounds, no retries/exclusions. Record p50/p90/p99, allocations, GC and
worker state; no uniformly-faster claim when tails regress. Never push main.

## Guard inventory

| Unit / boundary | Exact facts and emitted shape | Decision |
|---|---|---|
| F `bucket_rows`, user | Actual User holder; live `persisted?`/integer ID; two effective public reader bodies. Old `singleton_methods.empty?` followed by captured `singleton_class.bind_call` and Module lookup | Replace creating lookup with native exact holder **after** live reads, then captured ordinary-class public/body checks. Keep ordinary ID/association sends visible. |
| F `Site#eligible?`, owner | Owner class, live persisted/integer ID, association/ID/persisted reader bodies and public visibility | Native exact holder before and after live reads; ordinary-class lookup only after that proof. Existing eigenclasses conservatively fall back. |
| F model and relation methods | Captured Module lookup and public visibility on model singleton class (class setup, not a record's eigenclass), model-specific relation delegates and WhereChain | Retain. No guard-created ordinary singleton class; hook-only or JIT-only invalidation cannot certify erased calls. |
| F schema/scope/reflection | Defaults, types/columns/table identity, current/global scope, role/shard, reflection identity/options/scope/keys, no query transformers | Retain live comparisons. JIT CME invalidation does not watch mutable data contents. |
| F association/connection | Actual association not loaded, no cached scope/public singleton overrides; connection/visitor identity and prepared mode; PID/database-config-qualified child rebind | Retain; singleton enumeration does not materialize an eigenclass. Fork rebinding is still bench-only. |
| Sealed admission, all three units | One natural original witness; source/binary/ISeq/visibility/holder/config/translation/route/template facts, mutex, one attempt, epoch before publication | Cold, not a per-request guard. No runtime autoload/materialization or new guard hooks. |
| Form hot entry | Main Ractor/epoch; exact Array/Proc/view/Article/Comment holders, options/block source, builder/buffer holder/context, locale and blank/unpersisted child | Existing native holder primitive creates no eigenclass. Captured ivar and block-source `bind_call` avoid app reflection overrides. Keep checks. |
| Form live helper boundary | Captured stock `BasicObject#instance_exec` invokes private `tag_builder`, `output_buffer`, `url_for`, `token_tag`; named route retains original public_send/new String | Retain. A public send changes private/method_missing semantics; a captured method body bypasses legitimate overrides. No new method/ancestry shim. |
| Token hot entry/continuation | Main Ractor/epoch, nil token, exact options/view/builder and view-context link; after generation/conversion recheck epoch and String/builder holders | Retain non-creating native checks and saved-value stock continuation. Never regenerate a token or reconvert its name. |
| Token live helper boundary | Captured instance_exec for defined?/private protection, generator/name calls, live autocomplete getter and fallback tag | Retain implicit dispatch. K's five constant-cache exits are known, but its combined capture/split candidate failed its screen; not claimed fixed here. |
| Collection hot entry/body | Main Ractor/epoch, exact renderer/view, nonnil template/no layout; lexical PartialIteration-shadow refusal at witness | Already ordinary method, constant and live iterator/Template sends. Preserve preload/locals/cache-key/render/event effects; no singleton/instance_exec rewrite needed. |

Runtime counters are window-wide, not per-guard attribution. Public Ruby APIs
cannot assign every side exit, invalidation or ratio to an individual guard.
The old/new F pair isolates its two holder-guard changes; unit ablations on
blog can locate aggregate costs but do not make counters additive.

## Completed admission screens

Two-seed literal status/body/all-header digests match across all arms on both
apps. Every coverage worker asserts actual YJIT; Fizzy old/new each complete
20 hits and 20 strict SQL/bind shadows in ten requests, zero fallback. Blog
form/token/collection/stack hit deltas are 10/40/10/(10+40+10), zero fallback.
Stats workers use the independently built `--enable-yjit=stats` Ruby 4.0.7;
stock workers use mise Ruby 4.0.7. Both use Bundler 4.0.20 before app boot.

| Fizzy, per request | off-A | old F | new guard | off-B |
|---|---:|---:|---:|---:|
| Stock objects | 9084.796 | 8507.846 | **8417.880** | 9085.070 |
| Singleton-send fallbacks | 243 | 469 | **243** | 243 |
| Side exits | 42 | 38 | 38 | 42 |
| Window ratio-in-YJIT, % | 99.763683 | 99.801331 | 99.795969 | 99.763683 |

All four stats windows have zero invalidations/code GC and two newly compiled
ISeqs. This is a clear singleton-send counter improvement, **not** a JIT-flat
price or an across-the-board improvement: ratio-in-YJIT is slightly lower
than old F. Stock objects fall by about 90 versus F and 667 versus off.

| Blog, per request | off-A | form | token | collection | stack | off-B |
|---|---:|---:|---:|---:|---:|---:|
| Stock objects | 2286.326 | 1908.106 | 2286.272 | 2286.104 | 1908.438 | 2286.610 |
| Singleton-send fallbacks | 106 | 106 | 106 | 106 | 106 | 106 |
| Side exits | 11 | 12 | 15 | 11 | 16 | 11 |
| Constant-cache exits | 0 | 1 | 4 | 0 | 5 | 0 |
| Window ratio-in-YJIT, % | 99.742789 | 99.689520 | 99.727858 | 99.752880 | 99.658967 | 99.742789 |

Every blog stats window also has zero invalidations/code GC and two new
ISeqs. No blog runtime rewrite: the necessary implicit/private-dispatch
blocks remain, with K's five CREF-sensitive constant-cache exits explicitly
retained rather than rebranding K's rejected combined candidate.

### Incremental interpreter gate: pass, one attempt

Measured clean
[`c968daa`](https://github.com/thomasklemm/lowrail/commit/c968daa6db34ee6b35362bef272862d963137011),
old-on A / new-on / old-on B. These are **not new-versus-off prices** and must
not be added to F's earlier, pre-worker-binding-fix price.

| Metric | Old A / request | New / request | New/old paired change [95%], % | A/A [95%], % |
|---|---:|---:|---:|---:|
| Total Ir | 37,956,069.80 | 37,722,639.65 | **−0.621986 [−0.657997, −0.609650]** | [−0.017925, +0.034873] |
| No-GC Ir | 37,957,220.95 | 37,725,681.45 | **−0.610000 [−0.654673, −0.582798]** | [−0.036947, +0.042471] |

All 18 serial workers / 72 windows pass interpreter mode, source/tool/pin,
exact-page and zero-new-page gates. Targets 2047/367/1128/148/199 pages;
each full window completes 20 hits, zero fallback, shadows off. Four
tool=none preflight workers / 16 windows pass too. Both A/A intervals lie
wholly within the preregistered ±0.1%; both treatment upper bounds are ≤ 0.
No measurement retry/exclusion. All automatic GC counts in these small
fixed-heap windows are zero; the no-GC measurement is still separately kept.

### Mutation/fork coverage and its limits

Native primitive regression: `ruby -Igem/lib gem/test/native_test.rb` passes
2 tests / 25 assertions / no skips. Three production/YJIT fork workers run
19 controls × two seeds, preserving identical response status/body/headers.
Baseline/restored controls hit; empty User/Bucket eigenclasses, singleton ID,
private singleton/ordinary association readers and undefined readers refuse
with positive fallback and no hit. Expected private/undefined reader errors
remain HTTP 500 rather than silently using the cached query.

The broader checker **exits 2**: SQL/whole-DB equality fails even off/off.
Read-only SQLite comparison identifies session `created_at`/`updated_at` and
SolidCache `created_at`/`value` differences in the completed databases; queue
and cable match. No SQL or whole-DB certificate is credited or normalized.
Premeasurement checker setup failures (optional ZJIT constant absent; an
inherited-visibility mutation incompletely restored) are retained privately
alongside the corrected controls. The initial native-test command lacked
`-Igem/lib`; its load error is retained, not counted as a passing test.

## Puma cohort admission

The screens above admit exactly the one preregistered cohort. The unchanged
shared scripts/runtime come from
[`6510cd2`](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8),
including the `b1e239f` RPS harness and `544ad8d` native-GC/passive-wire
observers. Supply the existing native holder binary to that runtime. Use an
unchanged disposable Fizzy copy under that harness's `.corpus/`, the same
seed and entropy policy, and a relocated zero-unit artifact. No app source,
Puma config or dependency changes beyond the committed corpus recipe.

`jit_guards_rps.rb` adds only untimed admission: an external Puma setup hook
asserts actual YJIT in each post-fork worker and writes PID-qualified mode
receipts. Both seed workflows plus additional coverage GETs must reach all
four workers with hits > 0 and fallback 0. Cold/warm checks also reconcile
every running worker's mode receipt in all native servers. Public hit/shadow
counters remain off during timed load. Native GC tags and tcpdump
4.99.3/libpcap 1.10.3 are present identically from the first timed window;
recorder CPU 7 shares the client set, never the server set.

As in `44a33c4`, “A/A first” means adjudicate/report its band first within
the rotated cohort, not run an extra timing cohort. The decision rule above
is unchanged. A failed preflight or cohort is retained without a retry.

## Single Puma cohort: accepted scoped throughput result

Measured
[`796fa58`](https://github.com/thomasklemm/lowrail/commit/796fa5893b4e117168340c229908f89b86fdaf41):
Ruby 4.0.7, Rails 8.1.4, **Puma 6.5.0**, startup YJIT, four workers × one
thread, c16, 20 rotated rounds, 5 s warmup / 20 s load. All 60 timed windows
are retained, including the negative treatment round. No retry/exclusion.

**A/A first:** paired mean −0.440081%, 95% [−1.632208%, +0.800804%]; maximum
absolute single-round A/A spread 6.447765%. It contains zero. Treatment
RPS is **+7.827430% [+6.130743%, +9.838538%]**: its lower bound exceeds the
A/A upper bound, so the preregistered rule passes. This is new F versus
Lowrail off, **not a head-to-head native price for the guard change** versus
old F, and not a comparison obtained by subtracting two historical cohorts.

| Median of window values | off-A | on | off-B |
|---|---:|---:|---:|
| RPS | 511.233 | 546.242 | 503.224 |
| p50, ms | 7.687 | 7.194 | 7.763 |
| p90, ms | 124.517 | 110.797 | 119.969 |
| p99, ms | 265.474 | 246.536 | 268.017 |
| Post-load sum of worker RSS, KiB | 916,908 | 905,118 | 904,300 |
| Sum of worker GC-time deltas, ms | 3,554 | 3,636.5 | 3,590.5 |
| Sum of worker collection deltas | 323 | 338.5 | 331.5 |
| Process allocation deltas / completion | 9,066.219 | 8,398.372 | 9,066.256 |
| Recorder CPU, s | 0.475 | 0.500 | 0.475 |
| Native observer CPU, ms | 51.782 | 53.091 | 50.791 |

Percent changes use the mean of paired-round ratios, not ratios of these
medians. Latency values are medians of window percentiles, not a pooled
histogram or proof of uniformly faster tails. Process deltas include the
untimed metrics calls/background work; more completions occur in on windows.
GC collections/time increase in absolute terms. These are not a fixed-heap
memory/GC price or evidence that GC caused any tail. Observer CPU excludes
Ruby wrapper overhead and kernel capture cost; no observer-off overhead
ablation is claimed.

Both seeds' natural login/GET cold and post-warmup status/body/all-Rack-header
digests match across every arm/window. All 252 workers in the 63 fresh
servers assert actual YJIT after fork; timed counters are off. Before the
first load, all four on coverage workers have positive hits and strict
shadows, zero fallback. Pre/post metrics show no worker replacement. All
3,161 pinned inputs still match. There are **zero HTTP/transport errors**.

The offline receipt audit independently reconciles every oha receipt hash,
count/RPS/latency, schedule, paired bootstrap, worker mode and stable PID set.
**623,992 / 623,992** timed completions join one-to-one with both native
records and passive wire requests in all 60 windows. No join problems,
sequence gaps/retransmissions, kernel/native drops or open GC intervals.
Every one of the 72 interpreter dump totals separately equals its parsed
native self-cost sum and its worker receipt. Raw captures and environment
files stay private because they may contain disposable session credentials.

The [durable machine-readable export](jit-guards.json) contains actual source
and binary/input pins, all census counters (including pre-window totals),
two-seed digests, every Ir window/dump hash, the rejected full-DB controls,
all 60 RPS windows, all 252 worker-mode receipts, process metrics and the
complete numeric GC/wire audit. `$REPO` and `$SCRATCH` are relocatable root
labels, not a portable app/bundle. No credentials or raw cookie/packet data
are exported. `window_ratio_in_yjit` is computed from instruction deltas;
the arithmetic delta of a cumulative ratio is not that window ratio.

## Reproduction and next admission boundary

Reuse `script/corpus fizzy` and `script/corpus real-blog-r4`; prepare the
committed `FizzyLinkFixture` and `BlogShowGetOnly` snapshots. Match artifacts
to each actual stock/stats Ruby description, select the three blog units
after resolving manifest paths, renumber IDs and regenerate relative-path
metadata. Keep the existing entropy provider/site rules and update only
source/lock pins for a freshly generated fixture. The export records every
actual input hash. The stats Ruby recipe is:

```sh
./configure --prefix="$SCRATCH/ruby-stats" --enable-yjit=stats --disable-install-doc
make -j4 && make install
```

Official 4.0.7 tar.xz SHA256:
`47ef59413f7a4587ba6a6b78b14036eb5e36eec2ec0b90964801e88d56a3d375`.
The executed stats binary SHA256 is in the export. Pin Bundler 4.0.20 and
use the stock Ruby gem paths for the stats interpreter. Run each census in
a fresh output directory, then the finite interpreter preflight/cohort:

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/jit_guards.rb run CONFIG NEW_OUTPUT
PATH="$VALGRIND/bin:$PATH" CPATH="$VALGRIND/include" \
  mise exec ruby@4.0.7 -- ruby bench/experiments/jit_guards_ir.rb none CONFIG NEW_OUTPUT
PATH="$VALGRIND/bin:$PATH" CPATH="$VALGRIND/include" \
  mise exec ruby@4.0.7 -- ruby bench/experiments/jit_guards_ir.rb cohort CONFIG NEW_OUTPUT
```

The Puma config additionally selects only `/buckets`, supplies pinned oha,
the compiled shared `bench/rps_gc_tags.c`, `packet_capture_cpu: "7"`, and
sets `puma_setup` to this branch's `jit_guards_rps.rb`. Keep all settings and
the decision rule above; this completed attempt does **not** authorize a
retry. Its entry point and offline parser are:

```sh
BUNDLER_VERSION=4.0.20 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/jit_guards_rps.rb "$HARNESS/script/rps" CONFIG NEW_OUTPUT
python3 "$HARNESS/bench/rps_attribution.py" OUTPUT > PRIVATE_ATTRIBUTION.json
```

This result changes neither default delivery nor production admission.
The coordinator has authorized taking F toward an **opt-in** tier here,
in order: active DirectSite own-suite equivalence; declared and proved
off/off DB-noise exclusions; purity/lifecycle/fork/concurrency certificates;
a bounded transport-error review; full gates and Thermos. Those are new
prerequisites, **not already satisfied by this throughput result**. Main
integration belongs to the coordinator; README work follows integration.
No ZJIT execution or speed claim is made.
