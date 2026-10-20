# Decision register

What we pursue, what is parked, and what is rejected, with the evidence that
decided it. Update this when a pass changes state. Numbers live in the linked
docs; this page only records the decision and why.

Working assumption: many small exact passes (each < 2 %) should **stack**.
`lowrail bench --passes SET --default-build DIR` (8db84d8) measures a pass set as one layer against no-setup and a separate default
reference, and report the stacked effect next to the sum of individual
expected effects, with uncertainty. Real per-hit instruction budgets are
still missing for most passes (`measurement_complete: false`); adapters are
the current bench work. Promotion to
default still follows [ARCHITECTURE.md §4](ARCHITECTURE.md), applied to the
stacked set as well as to single passes.

## Architecture

| Item | State | Why / evidence |
|---|---|---|
| Pass registry, single runtime-build boot, shared ledger (migration 1–3) | done | Behavior-equivalent; [build-pass-equivalence.json](build-pass-equivalence.json) |
| Runtime `Lowrail::Passes` registry (migration 4) | done (491ea27) | 811 outcomes, ordered SQL, per-unit maps and Rails L3 identical; request −0.02 % (noise); cold require+setup +0.76 % once per boot (registry parsing, not eager loading). Seed-dependent real-blog link_to fallback explained: lazy route-helper materialization during a Turbo model broadcast before the first request; guard correctly conservative, identical on old and new runtime (a161a8e) |
| `lowrail bench APP --pass/--passes` (migration 5) | done (6f9e27a, 8db84d8) | One shared method: fixed-heap Callgrind, A/A, actual JIT state, stale-build rejection ([bench.md](bench.md)) |
| SQL-trace differential in verify | done | Fixed seed, symmetric repeat controls |
| Rails 8.1.4 framework suites as gate | done | [rails-suite.md](rails-suite.md); zero reproducible differences |
| Ship `passes.rb` as precompiled ISeq | parked | Would remove most of the cold registry cost; only after migration 4 lands |

## Passes

| Pass | State | Why / evidence |
|---|---|---|
| Route lowerings | opt-in | Method wins (`article_url` 4.0 → 2.25 µs); no request claim yet |
| Memo, digest memo | opt-in | Exact; digest memo helped one private app page; stacking candidate |
| `active_record/instantiate` | parked | −38 % load-only on the Rails alpha; upstream fixed the builder (rails/rails@f126797d45), gain disappears on current main. Keep for the guard machinery, not for the win. First stacked measurement (blog `/articles`, fixed-heap): default+instantiate is **+0.59 % [+0.53, +0.60] instructions vs default**, i.e. a net cost on Rails 8.1. Parked: never part of a default set on 8.1; the builder should refuse where the per-row guard exceeds the saving |
| AR plans, preload plans | opt-in | Expected effect < 0.2 %; zero Rails-suite reader/preload hits, being investigated (round 2) |
| `inertia/config_bind` | opt-in | 5 → 3 objects/bind, expected 0.5–2.8 % on JSON routes; native A/A controls failed. Upstream PR inertiajs/inertia-rails#437 may make it obsolete; keep for older versions only |
| Whole compiled ERB specialization | surveyed; no pass | I18n epoch not closed; Campfire URLs have 7 valid guards but 0 completed lowerings/request. No credited saving; [profile and refusals](passes/erb.md) |
| Literal-run ERB | rejected | 2 sites across five apps; two append calls saved per rendered layout do not justify a pass/guard ([survey](passes/erb.md)) |
| Route pass with host/protocol `default_url_options` | parked | Widening the optimized predicate is not exact (`to_param` ordering counterexample); scalar-only args cover 1/4 Campfire path calls, base-AR `to_param` certification would cover 4/4, but the ceiling is ~0.3 % of an uncached room request (19 calls × ~2 µs). Revisit as a stacking item once per-hit route budgets exist ([route-helpers.md](passes/route-helpers.md)) |
| Template lookup | parked | At most 0.42% before complete guards; `clear_cache` and `DetailsKey.clear` change Templates while path/details identities stay unchanged. Needs a filesystem-resolver epoch ([survey](passes/template-lookup.md)) |
| `run_callbacks` specialization | survey | 22.5 % inclusive in Rails-suite profiles; build only if ≥ 2 % expected on a corpus route |
| Literal tag attributes | survey | Candidate #4 owns tag-options/form-builder attribute work (4.46 % blog / 2.90 % Campfire cost shares, not savings); establish per-site removable work before implementation ([boundaries](passes/erb.md)) |
| Fixed-shape serialization | parked | 0–0.18 %; Alba key-plan prototype **rejected** (regressed Redprints, +20 objects) |
| Empty callbacks (standalone) | rejected | < 0.006 %; superseded by the `run_callbacks` survey |
| Campfire CSP/importmap reuse | rejected as a pass | A cache changes `Regexp.timeout` semantics; fixed in the app instead (upstream PR) |
| Freezolite in Lowrail | rejected | App decision; documented under complementary optimizations |
| Escaping AR app-chain plans | parked | Zero credited until exact full-chain eligibility is shown |

## Later

- Revisit Roundhouse for typed-IR ideas once the stacked-pass measurements
  exist, to compare what per-site lowering actually buys.
- Spinel target: out of scope for now.

## Stacking backlog

Small exact savings (each < 2 %) that are worth revisiting once the large
items are done, because they may add up. Shares are removable estimates or
upper bounds per route, not measured request wins. Re-measure with
`lowrail bench --passes SET` before building.

| Item | Est. removable share | Certification needed | State |
|---|---|---|---|
| Route lowering under host/protocol `default_url_options` | ~0.3 % Campfire room (19 calls × ~2 µs) | base-AR `to_param`, attribute/type facts; generic script order | parked ([route-helpers.md](passes/route-helpers.md)) |
| Template lookup | ≤ 0.42 % blog edit, ≤ 0.24 % Campfire, ≤ 0.23 % Redprints, ≤ 0.08 % PingCRM | filesystem-resolver epoch on `clear_cache`/`DetailsKey.clear`, live details/locals | parked ([erb.md](passes/erb.md)) |
| Callback machinery (no-around chains) | 0.14–0.98 % across 11 routes | chain identity + set/skip/reset_callbacks epoch | parked; Rails main PR 59094 removes part upstream |
| `inertia/config_bind` | 0.5–2.8 % on JSON routes (expected) | implemented, opt-in | opt-in; may become obsolete with inertiajs/inertia-rails#437 |
| Fixed-shape serialization | 0–0.18 % PingCRM | exact key plan without extra allocations | parked (Alba key-plan prototype rejected) |
| Literal tag attributes | 0–0.21 % blog, 0–0.08 % Campfire | folded into the tag/form component pass | in progress as part of candidate 4 |
| Precompiled `passes.rb` | cold boot only (~0.37–0.40 M instructions once) | none | follow-up |
