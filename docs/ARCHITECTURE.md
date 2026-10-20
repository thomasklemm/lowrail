# Architecture: the pass contract

Status: target design, 2026-10-20. Sections 1 and 2 describe the code as it is;
section 3 is the contract every pass will follow; section 5 is the migration.
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
   source units  → lowered ISeqs via load_iseq / template seam
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
| `digest/file_memo` | runtime | `exe/lowrail-digest-build` | method variant, byte compare | opt-in | −14 % on one ARGOS page |
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
lowrail build APP [--env E] [--passes default,+ar_instantiate,-view/link_to]
  1. facts (one boot, cached)
  2. source passes in Rust, in declared order (link_to before route/path)
  3. one Ruby process: boot the app once, run every selected runtime pass's
     builder, return their units/ledger as JSON on stdout
  4. merge, assign unit ids, write manifest + ledger once, compile ISeqs
```

### Runtime

`Lowrail.setup` loads the manifest, installs `Guard` and `Loader`, then for
each pass present in the manifest requires `lowrail/passes/<name>` and calls
`install(units)`. One shared helper runs `activate` after Rails initializes
(or immediately if it already has). Stats, hits and fallbacks go through
`Lowrail.check`/`ok?` or `Stats.count(id, ok)` for every pass.

## 4. A pass's lifecycle

1. **Survey**: the builder runs in report-only mode over the corpus; the
   ledger shows eligible sites and refusals by reason.
2. **Implement** behind `opt-in`, with tests that fail on a plausible wrong
   implementation (asymmetric inputs, a fact changed after boot).
3. **Gate**: `lowrail verify` on all corpus apps: identical outcomes and SQL
   traces, hits where they genuinely occur, every fallback explained.
4. **Measure** with `lowrail bench`: saved µs per hit × hits per request =
   expected effect; then the measured request effect against an A/A control.
5. **Promote** to `default: on` only if the expected effect is ≥ 2 % on some
   corpus route, the measurement agrees, and nothing gets slower beyond
   noise. Otherwise it stays opt-in with its numbers in `docs/passes/`.

Rules that apply to every pass: exact semantics or refuse; no data cached
across requests; refusal reasons are recorded, never silent.

## 5. Migration

Steps 1–3 are implemented without changing runtime delivery or installation.
Step 4 must wait for the base-cost work (`docs/bench.md`) in `lowrail.rb`
and `guard.rb` to land.

1. Pass registry in Rust (`src/passes.rs`: name, kind, default, builder) and
   `--passes`; keep the old flags as aliases for one release.
2. One Ruby runtime-build entry point (`exe/lowrail-runtime-build`) that boots
   once and runs the selected builders; the existing `*_build.rb` files become
   builder functions returning `{units, ledger}`.
3. Shared ledger schema with reason codes; `build` prints one refusal table.
4. `Lowrail::Passes` registry and one activation helper in the gem; move the
   seven passes behind it without changing their behavior (verify gates
   before/after must match, including hits per unit).
5. `lowrail bench APP --pass NAME` wrapping `docs/bench.md`'s method.
