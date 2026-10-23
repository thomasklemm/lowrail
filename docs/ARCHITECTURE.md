# Architecture: the pass contract

Status: pass contract, 2026-10-20. Section 2 records the pre-migration wiring;
section 3 is the contract; section 5 tracks its implementation.
PLAN.md stays the "why"; this file is the "how a pass plugs in".

## 1. Pipeline

```
 boot facts ─┐   (lowrail facts: eager load + materialize + script_compiled,
 Prism      ─┼─▶  Prism over app/, observe: definitions/types from a test run)
 observed   ─┘
        │
        ▼
   passes ── each: eligible sites → units (+ guard facts) and ledger entries
        │
        ▼
   .lowrail/manifest.json  (units, files, templates, fingerprints)
   .lowrail/ledger.json    (one entry per site: lowered or refused + reason)
        │
        ▼
 delivery at runtime (gem/lib/lowrail.rb setup)
   source units  → lowered ISeqs via translate / cache output / eval; template seam
   runtime units → method variants installed after Rails initializes
        │
        ▼
 guards: method facts (Guard), route facts, AR epochs, per-call state checks
        │
        ▼
 verify (outcomes + SQL traces, bisect) and bench (layered, A/A controlled)
```

## 2. Before migration: two pass kinds, wired by hand

Steps 1–3 now use `src/passes.rs`, `exe/lowrail-runtime-build` and the shared
ledger schema documented in FORMATS.md.
The four old per-pass build executables below were internal drivers; no
benchmark calls them. They have been removed and the pass notes updated.
The table and pain points record the pre-migration design.

| Pass | Kind | Built by | Guard style | Default | Result so far |
|---|---|---|---|---|---|
| `route/path` (+ `_url`) | source | Rust `src/lower/route.rs` + Ruby oracle | per call site, `Lowrail.ok?` + route facts | on | ~2× per call, request effect in noise |
| `view/link_to` | source | Rust `src/lower/view.rs` | per call site | on | byte-identical HTML, request effect in noise |
| `memo/sha256`, `memo/uri_join` | source | Rust `src/lower/memo.rs` + certificate | per call site + bounded cache | opt-in | no net win |
| `digest/file_memo` | runtime | `exe/lowrail-digest-build` | method variant, byte compare | opt-in | historical −14% on one page, [Private Rails app with Inertia Rails](m0/private-inertia-app.md); not current admission |
| `active_record/preload_plans` | runtime | `exe/lowrail-preload-build` | method variant + structural plan | opt-in | slower uncached |
| `active_record/instantiate` | runtime | `exe/lowrail-ar-instantiate-build` | per-model variant + AR epoch | opt-in | −38 % load-only on a Rails alpha already fixed upstream |
| `active_record/ar_plans` | runtime | `exe/lowrail-ar-build` | final-relation plan + AR epoch | opt-in | <0.2 % expected |

What hurts iteration speed:

1. **Each pass is wired in five places**: a `build` flag, a branch in
   `src/build/mod.rs`, a hard-coded name in `summary`, an `if` in
   `Lowrail.setup`, and its own install/activation code (four copies of
   "on_load(:after_initialize) or a TracePoint until Rails exists").
2. **Runtime passes post-process the manifest in sequence.** Every
   `lowrail-*-build` boots the app again (besides the facts dump and the
   oracle, once per runtime pass) and rewrites `manifest.json`/`ledger.json` in place. The order
   of those rewrites is implicit.
3. **No shared unit/ledger schema.** Ledger keys differ (`file`/`template`/
   `method`), outcomes are free text, so refusals cannot be aggregated across
   passes or apps.
4. **Each pass thread rebuilt its own measurement**: micro, expected-effect
   budget, request pairs. Results were often not comparable.
5. **Base cost is unknown.** With Lowrail on, request medians were higher on
   all five apps even where passes had few hits (being measured in
   `docs/bench.md`).

## 3. The contract

A pass is one named unit of specialization, `area/name`. It declares:

| Field | Meaning |
|---|---|
| `name` | `route/path`, `active_record/instantiate`, … (stable; appears in units, ledger, denylist, stats) |
| `kind` | `source` (rewrites app source; built in Rust over Prism) or `runtime` (specializes a framework or gem method; built in Ruby inside one booted app) |
| `default` | `on` or `opt-in`; see section 4 for promotion |
| `needs` | fact sources it reads: `facts`, `oracle`, `observed`, `booted_app` |
| `build` | sites → `{units, ledger}`; never writes files itself |
| `guard` | one of: `call_site` (`Lowrail.ok?`/`G[id]` around an expression), `method_variant` (a normal def per variant, installed while facts hold), `epoch` (plan stored with `Lowrail::AR.epoch`) and any per-call state checks |
| `runtime` | `Lowrail::Passes::<Name>.install(units)` plus an `activate` hook; source passes have none beyond delivery |
| `bench` | how to measure one hit in isolation (saved µs, allocations, guard included) |

### Unit schema (manifest)

```json
{"id": 17, "pass": "route/path", "kind": "file|template|method|model",
 "target": "app/models/article.rb | ActiveRecord::Base._load_from_sql | Message",
 "sites": 3, "facts": [ ... method/route facts ... ], "data": { ...pass-specific... }}
```

`facts` are checked by `Lowrail::Guard` (shared). Pass-specific payload lives
only under `data`.

### Ledger schema

```json
{"pass": "route/path", "target": "app/views/articles/index.html.erb", "line": 12,
 "site": "article_path", "outcome": "lowered | refused", "reason": "options_hash",
 "detail": "free text", "copies": 2}
```

`reason` is a short code from the pass's documented list, so `lowrail build`
can print a refusal table across passes and apps, and the corpus ledger can be
compared run to run.

### Build orchestration

```
lowrail build APP [--env E] [--passes default,+props,+endpoint]
  1. facts (one boot, cached)
  2. source passes in Rust, in declared order (link_to before route/path)
  3. one Ruby process: boot the app once, run every selected runtime pass's
     builder, return their units/ledger as JSON on stdout
  4. merge, assign unit ids, write manifest + ledger once, compile ISeqs
```

### Runtime

`Lowrail.setup` loads the manifest, installs `Guard` and `Loader`, then hands
it to `Lowrail::Passes`. The registry lazily requires each runtime present
and calls `Lowrail::Passes::<Name>.install(units)` with only that runtime's
units, preserving the original installation order. The two `memo/*` passes
share one installer. Existing file paths and `Lowrail::<Name>` constants stay
available, so generated Ruby and source-fact owners do not change.

The sealed-only `inertia/config_bind` pass uses `Passes::InertiaConfig` directly.
Its builder-only publication preceded this registry; activation is now wired
through the same helper, with separate integration gates in addition to the
existing-pass before/after equivalence proof.

The [suppressed-hook audit](passes/suppressed-hooks.md) also makes both memo
passes, file-digest memo and all three AR passes sealed-only. Their cached
facts/epochs do not certify suppressed dependency changes. Only props and
endpoint remain in guarded `all-opt-in`; defaults remain empty. The generic
registry drives the separate production sealed tier; old/mixed artifacts
refuse whole, and test processes remain original-only.

The opt-in `inertia/props` builder returns a gem-source rewrite through the
existing runtime `files` protocol, not a replacement resolver subsystem.
`Passes::InertiaProps` authorizes only native ordinary-Hash iteration at each
traversal entry, including recursion after app code; the prop body and original
fallback remain in their original lexical scope. See [its mutation contract
and measured request cost](passes/props.md).

One `Passes.after_initialize` helper schedules every runtime's `activate`
through Active Support's `:after_initialize` hook, which also runs immediately
after an already-completed initialization. Before Rails exists, one temporary
TracePoint hands the queued runtimes to that hook in installation order.
Installers contain no private Rails-activation callbacks.

Source delivery remains eager: `Routes` supplies generated-code helpers and
`Templates` attaches at Action View's compilation seam, before initializers
can compile a template. `Passes` owns this wiring too; delivery is not delayed
until Rails initializes. Memo tracing guards also install immediately. AR
epoch hooks still attach to `:active_record`, independently of pass activation.
Stats, hits and fallbacks retain `Lowrail.check`/`ok?` or `Stats.count(id, ok)`.
Absent/incompatible/empty builds and empty selections return before loading
the registry or installing delivery, invalidation or activation hooks.

## 4. A pass's lifecycle

1. **Survey**: the builder runs in report-only mode over the corpus; the
   ledger shows eligible sites and refusals by reason.
2. **Price before building** (added 2026-10-20). Measure the complete exact
   check cost per hit, including every post-entry boundary, against the
   whole original work it replaces, with one finite micro cohort. If the
   checks alone cost more than the saving, stop at design. Pricing stopped
   both guarded endpoint designs before implementation (caller-side sections:
   93,649 Ir of checks vs 90,042 Ir for two links; body-installed: 94,466 vs
   89,729). `inertia/props` was built first and lost (micro −5,894 Ir/call,
   request +0.87 % with per-iteration checks).
3. **Implement** behind `opt-in`, with tests that fail on a plausible wrong
   implementation (asymmetric inputs, a fact changed after boot).
4. **Gate**: `lowrail verify` on all corpus apps: identical outcomes and SQL
   traces, hits where they genuinely occur, every fallback explained.
5. **Measure** with `lowrail bench`: saved µs or instructions per completed hit
   (guard included) × hits per request = expected effect; then the measured
   request effect against an A/A control. Keep metrics/JIT state comparable;
   guard success alone is not necessarily a completed specialization. Partial
   budgets and rejected controls are recorded, not promoted.
6. **Promote** to `default: on` only if the expected effect, individually or
   as a measured pass set, is ≥ 2 % on some corpus route, the measurement
   agrees, and nothing gets slower beyond noise. That includes YJIT:
   whenever a YJIT request cohort for the route passes its gates, the pass
   must not regress there either. An interpreter win alone does not
   promote (2026-10-20: `inertia/config_bind` −6.9 % interpreter but
   +16.3 % under YJIT on Starter JSON, accepted cohort). Otherwise it stays opt-in
   with its numbers in `docs/passes/`. Smaller passes may stack; do not demand
   that each independently cross the threshold.

Rules that apply to every pass: exact semantics or refuse; no data cached
across requests; refusal reasons are recorded, never silent.

### Proposed: component passes (not yet implemented)

Per-site surveys keep ending below 0.5 % per route (template lookup, routes,
callbacks; see [DECISIONS.md](DECISIONS.md)) because each site needs its own
certificate. A `component` pass instead replaces one framework subsystem
(e.g. `TagBuilder`/`FormBuilder`, Journey formatting, AR attribute storage)
with a faster implementation of the same observable behavior, keeping the
original installed as the fallback. In addition to the rules above:

1. **Applicability at boot**: facts prove the app only uses extension points
   the replacement covers (no custom resolver, no overridden `tag_options`,
   …); otherwise refuse with a reason.
2. **Rails' own tests as gate (L4)**: the component's framework test files
   from `script/rails-suite` run with the replacement installed and must be
   identical to off, in addition to the corpus verify and byte-identical
   output gates.
3. **Pinned per Rails minor version**; unknown versions refuse. Fact changes
   after boot fall back to the original for the affected receiver.

## 5. Migration

Steps 1–5 are implemented. Step 4 follows the base-cost work in
`docs/bench.md`; guard, loader and statistics hot paths remain unchanged.

1. Pass registry in Rust (`src/passes.rs`: name, kind, default, builder) and
   `--passes`; the transitional per-pass build flags are now removed.
2. One Ruby runtime-build entry point (`exe/lowrail-runtime-build`) that boots
   once and runs the selected builders; the existing `*_build.rb` files become
   builder functions returning `{units, ledger}`.
3. Shared ledger schema with reason codes; `build` prints one refusal table.
4. `Lowrail::Passes` registry and one activation helper in the gem; preserve
   runtime installation, source delivery, guards and per-unit counters.
   Before/after evidence is recorded in
   [runtime-pass-equivalence.json](runtime-pass-equivalence.json).
5. **Implemented:** `lowrail bench APP --pass NAME [--path /path]` wraps
   `request_pairs.rb`, `callgrind.c` and optional `gc_requests.rb`, with
   separate strict build/activation/JIT/coverage probes. Versioned JSON and a
   short Markdown table carry controls, request effects and optional guarded
   per-hit budgets. Existing AR/preload method micros share fresh-process
   A/A orchestration; remaining operation adapters are listed in
   [bench.md](bench.md#remaining-per-pass-adapters). Stacked `--passes` mode
   uses a separate saved default build, the same no-setup/A/A/heap gates,
   and multi-unit/model `--budgets` input. It reports measured saving beside
   the summed individual expectations and a covariance-aware residual CI;
   missing budgets remain unmodeled. `--measure-budgets` captures real guarded
   source operations and Inertia controller bindings, using shared fixed-heap
   off/off/on windows and per-operation A/A controls. Guarded fallback attempts
   are priced explicitly per invocation, never disguised as completed hits.
   See [stacked pass sets](bench.md#stacked-pass-sets).

### Post-migration cleanup

Build selection uses only `--passes`; short names such as `+memo` and
`+ar_instantiate` remain registry aliases, not separate CLI flags. Source
delivery and runtime method bodies are unchanged by the cleanup.

Application activation has one owner, `Passes.after_initialize`. Direct
`activate` calls remain only where needed by isolated pass tests, method
diagnostics and Rails **component** suites, which have no initialized Rails
application to fire that hook. `AR.install`'s `:active_record` hook remains
dependency invalidation, not an alternative per-pass activation path.

The shared benchmark replaces the cached-reader, preload and memo request
runners and the instantiate request/micro branches. Operation workers stay;
instantiate's internal-cost/StackProf breakdown and `ar_plans_runs.rb`'s
Lowrail-off implementation comparison are not covered by `lowrail bench`.
See [the remaining diagnostics](bench.md#remaining-per-pass-adapters).

The cleanup's [before/after corpus evidence](cleanup-equivalence.json) retains
entire-manifest and ledger equality, ordered own-thread SQL and full per-unit
maps, including the Campfire browser A/A variation rather than hiding it.
