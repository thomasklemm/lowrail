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
| Replacement-layer ceiling, Rails 8.1.4 blog index/show | owner decision pending; measurement only | Envelope saves ~2.3–2.6% Ir; hand-lowered endpoint ~33.4–40.9%. Keeping controller/render events retains ~78%/91% of that saving (index ablation A/A rejected, show accepted). Most removable work is rendering/helper interpretation, not AR queries. Concrete L3 attribute/Journey/Fanout trio does not win. No generator, L4 pilot or default change; [measurements, entry facts and per-test shapes](passes/layer-ceiling.md) |
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
| `run_callbacks` specialization | parked; stacking only | Census: 4–7 calls/request, no nonempty symbol-only chains. Eligible no-around machinery is 0.141–0.975 % of eleven corpus routes, even before guards; action bodies are not removable. Rails already caches chains, and upstream [PR59094](https://github.com/rails/rails/pull/59094) removes known-terminator thunks. No runtime pass; [survey and measured boundaries](rails-suite.md#round-2-callbacks-are-parked-not-a-225-app-opportunity) |
| Tag/form attribute component | parked, upstream-solved | Rails main [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b) already fuses attribute appends; absent from `8-1-stable` and every stable 8.1 release through 8.1.4 when checked. Estimated ~0.3–0.45 % blog edit / ~0.2–0.3 % Campfire room before guards. Census: 12/94/2/0/0 direct sites, all refused as `upstream_solved`; [per-site options/refusals and controls](passes/tag-options.md). No backport now. Cheapest later component pilot: upstream code and tag-helper tests make the L4 scaffold almost free |
| Campfire fragment caches | stay | Uncached all-pass renders cost roughly 1.8–9.6× warm hits in the measured room/sidebar fixtures; even the layer study's 33–41% endpoint-lowering ceilings would not close the gap. No observed c < a; native A/A fails, so no precise pass gain claimed ([measurements](passes/campfire-fragments.md)) |
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
| Tag/form attribute component (includes literal attributes) | ~0.3–0.45 % blog edit, ~0.2–0.3 % Campfire room before guards; other routes unpriced | per-version source/method facts, no TagBuilder overrides, fact-change fallback, live escaping/config/form state; L4 helper tests and corpus/HTML gates | parked, upstream-solved by [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b); not in `8-1-stable` or stable 8.1.0–8.1.4. Cheapest later component pilot; no Lowrail implementation ([survey](passes/tag-options.md)) |
| Precompiled `passes.rb` | cold boot only (~0.37–0.40 M instructions once) | none | follow-up |
| Blog controller filter interpretation (including around chains) | ~0.54 pp index (diagnostic; rejected A/A), ~0.60 pp show of L0, ordered hand-ablation | exact ordered chain/conditions/method/Proc identities and callback mutation generation; retain CSRF/around bodies, once-only queries and halting/error behavior | measured ceiling only; generator held ([layer study](passes/layer-ceiling.md)) |
| Remaining controller/params/response interpretation | ~1.55 pp index (diagnostic), ~0.74 pp show, after rendering/event removals; not additive with a separate pass budget | original action/render/response hooks and live request format/params facts; preserve execution context, instance state, flash/session and observer behavior | ordered ceiling, not a supported pass ([layer study](passes/layer-ceiling.md)) |
| Blank Comment model for the show form | ~0.49 pp show (~8 objects); absent on index | stock `new`/initialize/schema/defaults, empty initialization callbacks, no observable form-model hooks | prefer retaining the construction to avoid a separate certificate; measured, no pass ([layer study](passes/layer-ceiling.md)) |
| AttributeSet reads/casting | ≤2.02% inclusive blog index discovery bound, **not removable credit** | exact attribute/default/missing/cached-nil/type/dirty-tracking contracts and method/type mutation facts; Rails L4 tests | direct-ivar prototype combined with Journey/Fanout regressed show +0.128%; index control rejected. No saving credited; individual components unpriced ([layer study](passes/layer-ceiling.md)) |
| Journey Format structure | ≤0.50% inclusive blog index discovery bound, **not removable credit** | route reload generation, exact format/escaper structure and parameter-before-child evaluation/missing-key behavior | combined prototype does not win; per-component cost still unpriced ([layer study](passes/layer-ceiling.md)) |
| SafeBuffer/OutputBuffer interpretation | ≤1.51% inclusive blog index discovery bound, **not removable credit** | exact safety/mutation/encoding/capture/streaming/handler contracts; source/method/resolver generations and L4 tests | survey only; no component implemented or saving credited ([layer study](passes/layer-ceiling.md)) |
| Empty-list Notifications Fanout fast path | unpriced individually; no credited request saving | retain live subscriptions/silence or complete notifier/subscription/log-level/silence epochs; framework tests | combined prototype does not win. Prefer preserving endpoint events: accepted show still −37.29% Ir; boot-time subscriber absence is insufficient ([layer study](passes/layer-ceiling.md)) |
