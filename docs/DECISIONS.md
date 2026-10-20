# Decision register

What we pursue, what is parked, and what is rejected, with the evidence that
decided it. Update this when a pass changes state. Numbers live in the linked
docs; this page only records the decision and why.

Working assumption: many small exact passes (each < 2 %) should **stack**.
A planned `lowrail bench --passes SET` (immediate follow-up to migration 5)
will measure a pass set as one layer against no-setup and a separate default
reference, and report the stacked effect next to the sum of individual
expected effects, with uncertainty. Promotion to
default still follows [ARCHITECTURE.md §4](ARCHITECTURE.md), applied to the
stacked set as well as to single passes.

## Architecture

| Item | State | Why / evidence |
|---|---|---|
| Pass registry, single runtime-build boot, shared ledger (migration 1–3) | done | Behavior-equivalent; [build-pass-equivalence.json](build-pass-equivalence.json) |
| Runtime `Lowrail::Passes` registry (migration 4) | in progress | Non-browser gates identical, request cost −0.02 % (noise). Cold require+setup +0.76 % once per boot from parsing the shared registry, not eager pass loading. Gated on browser counter attribution |
| `lowrail bench APP --pass/--passes` (migration 5) | in progress | One shared method: fixed-heap Callgrind, A/A, actual JIT state, stale-build rejection ([bench.md](bench.md)) |
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
| Whole compiled ERB specialization | in progress | Candidate #2, up to ~2.8 % on blog edit |
| Template lookup | next | Overlaps Rails-suite hot methods (`LookupContext#find`, `PathSet#find`) |
| `run_callbacks` specialization | survey | 22.5 % inclusive in Rails-suite profiles; build only if ≥ 2 % expected on a corpus route |
| Literal tag attributes | parked | 0–0.2 %; revisit as a stacking item after ERB |
| Fixed-shape serialization | parked | 0–0.18 %; Alba key-plan prototype **rejected** (regressed Redprints, +20 objects) |
| Empty callbacks (standalone) | rejected | < 0.006 %; superseded by the `run_callbacks` survey |
| Campfire CSP/importmap reuse | rejected as a pass | A cache changes `Regexp.timeout` semantics; fixed in the app instead (upstream PR) |
| Freezolite in Lowrail | rejected | App decision; documented under complementary optimizations |
| Escaping AR app-chain plans | parked | Zero credited until exact full-chain eligibility is shown |

## Later

- Revisit Roundhouse for typed-IR ideas once the stacked-pass measurements
  exist, to compare what per-site lowering actually buys.
- Spinel target: out of scope for now.
