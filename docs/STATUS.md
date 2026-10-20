# Status

Living summary of what works, what was learned, and what is next. Details
live in the linked docs; numbers come from executed runs, dated.

## Works (2026-10-20)

Ruby 3.4+ (gemspec), developed on 4.0.7. real-blog on Ruby 3.4.11 builds the
same 11 units and verifies 21/21 identical with 114 hits.

- **Boot facts** (`lowrail facts APP`): modules, methods with owner,
  source location, visibility and ISeq kind, models, controllers, routes and
  compiled template code. Prism classifies origins: real-blog has 13 source
  `def`s against 362 gem-generated methods on app classes.
- **Build-time oracle** (`gem/exe/lowrail-oracle`): a booted view context
  that evaluates helpers with marker strings; probes with special characters
  prove how each marker is escaped. Passes reuse Rails' own rules instead of
  re-implementing them.
- **View pass `link_to`** (`src/lower/view.rs`): per call site
  `((guard && type checks) ? inline : original)`, on the original line, with
  the original call verbatim as fallback.
- **Route pass `route/path`** (`src/lower/route.rs`,
  [docs/passes/route-helpers.md](passes/route-helpers.md)): named-route
  `*_path` calls in templates and in Ruby files under `app/` (the first
  Ruby-file pass, served through `load_iseq`); probes run the emitted code
  next to the real helper. Guards on `@self` facts are checked per class of
  `self` (`Lowrail.ok?`). Dynamic engine script completion stays in Rails;
  `_url` host normalization is memoized only on the request, keyed by its
  scalar inputs (including in-place string/encoding changes). `url_options`
  and application overrides remain live. `article_url` construction is
  3.71 → 2.21 µs, 25 → 9 allocations (YJIT; see pass notes).
  Block-backed `direct`/`resolve` helpers remain refused with block locations
  and operations: corpus blocks read current state, transform arguments or
  dispatch dynamically; a runtime probe rejects dropping their state/query.
- **Active Record preload plans** ([design and measurements](passes/preload-plans.md)):
  guarded gem-level trees, scopes and loader groups computed once; fresh
  Rails Association loaders per call, no cached rows. Schema/reflection/scope
  changes and unsupported shapes retain the original Rails path. Already-loaded
  micro path −22.1% time/−29.3% allocations, but presentation +19.3% and
  response-cache-disabled room +10.2%: not a general application-speed win,
  so it is opt-in (`lowrail build --preload-plans`) until it no longer
  slows real requests.
- **Runtime gem**: `load_iseq` / ISeq eval seams (composes with Bootsnap and
  require-hooks/Freezolite in every installation order), per-file compiler
  contracts captured from the booted app, unchanged-source/original-ISeq
  fingerprints, and original-only Bootsnap caches ([survey and tests](loaders.md));
  template seam (lowered handler code while the source digest matches),
  guards that reset on every definition path and revalidate lazily
  (including stubs on single objects), per-view-class checks, env check,
  stats, Minitest outcome reporter across forked workers and RSpec per-example
  outcomes via RUBYOPT (explicit `verify APP -- bundle exec rspec ...`). Setup
  loads no default gems, so apps pinning `json` still boot.
- **`lowrail verify [--bisect]`**: suite with `LOWRAIL=0` and `1`, per-test
  outcomes and fast-path hits. `--bisect` reruns with unit subsets
  (`LOWRAIL_UNITS`) and writes `.lowrail/denylist.json`, which `build`
  honors. Checked with a fault injected into one real-blog unit: found in 4
  reruns, the rebuild skips that template.
- **Build surface** (PLAN 9.4): `lowrail facts` materializes lazy
  surface before dumping (production eager load, attribute methods,
  relation delegation, lazy routes, view context classes, every template
  compiled), captures every eval'd script (`TracePoint(:script_compiled)`,
  `.lowrail/generated/`) and links methods to the exact generated `def`
  (`--show Mod#meth`). `lowrail observe APP` records a test run
  (definitions after boot, scripts, sampled argument/return classes) into
  `.lowrail/observed.json` and diffs it against the facts.
- **Types and MCP** (first iteration, other thread): boot-first types with
  provenance, RBS generation, stdio MCP server. See `docs/types.md`.

## Evidence

| App | Lowered | verify | Other |
|---|---|---|---|
| real-blog (Rails 8.1.4) | 9/9 `link_to` sites, 10/10 route sites (1 in a controller), 12 units including preload plans | 21/21 identical, 116 fast-path hits across all 12 units (2 preload hits) | 4 HTML routes byte-identical on/off (CSRF masked); request time within noise, allocs −1 to −6 %; `edit_article_path` 2.7 → 1.4 µs |
| Campfire (Rails 8.2 alpha) | 1/4 `link_to`, 108/162 route sites (51 `_url`) | 634/634 identical (2 skips both ways), 13238 hits across 52 units, 0 fallbacks; with `--preload-plans` 786 preload hits | M0 in `docs/m0/campfire.md`; preload results in [pass notes](passes/preload-plans.md) |
| ARGOS (private, Rails 8.1.4) | 235/280 route sites, 61 units; `link_to` 0/0 | 10,816 unit/request + 552 system outcomes identical; 794/226 guard hits, zero guard fallbacks; three units unexercised | [Iteration and aggregate measurements](m0/argos.md): page/boot timing within noise; 14,734 type signatures, 3,053 non-untyped returns; digest 15.8% self remains a candidate |
| PingCRM (Rails 8.1.4, Ruby 4.0.7) | 30/30 route sites, 4 route units + preload | 26/26 identical, 11 route + 7 preload hits | [Public Inertia M0](m0/inertia.md); seed 41231, browser suite included |
| Redprints CFP (Rails 8.1.3, Ruby 4.0.7) | 25/27 route sites, 14 route units; 9 Ruby files compiled | 50/50 non-system + 12/12 browser outcomes identical; 25 + 19 fast-path hits, **zero fallbacks** in both runs | Freezolite delivery and dynamic mounted-engine script completion fixed ([loader survey](loaders.md)) |
| React Starter Kit (Rails 8.1.4, Ruby 4.0.7) | 23/26 route sites, 8 route units + preload | 36/36 identical, 25 route hits across 7 units; no preload hits | [M0](m0/inertia.md) includes healthy SSR HTML and authenticated JSON |

Public Inertia builds and `observe` completed on all three. Lowrail-off
production/YJIT baselines and StackProf area shares are in [the M0](m0/inertia.md),
not speedup claims. All three version digests are eager boot Strings: **zero
digest calls across 400 traced requests/app**, unlike ARGOS's version proc.
Configuration binding and serializer/prop descriptors are measured candidates;
dynamic users, props, SQL and SSR output must remain per request.

### Per-file loader policy (2026-10-20)

Build captures the app's real compiler calls, including Freezolite's temporary
defaults and Bootsnap's selected per-file options. Runtime requires the same
recipe, original ISeq and source bytes before substituting lowered code;
Bootsnap caches only originals. Installation-order and ecosystem details are
in [loader composition](loaders.md). This is delivery/correctness work, not a
speed claim.

Executed on Ruby 4.0.7, using the `script/corpus` pins and seed 41231:

- real-blog: build 11 units, verify 21/21 identical, 56 hits across all
  11 units, 1 view fallback.
- Campfire: verify 634/634 identical (2 skips both ways), 6913 hits across
  52 units, zero fallbacks.
- Redprints: build 14 units and compile all 9 Ruby files with its own
  Freezolite policy. Non-system RSpec is 50/50 identical, 25 hits across
  9 units; browser RSpec is 12/12 identical, 19 hits across 8 units. Both
  report zero fallbacks. These runs include the separate
  [mounted-engine completion fix](https://github.com/thomasklemm/lowrail/commit/9fa9bd13313ad0314f606d37e221b66616751b8f):
  `find_script_name` remains dynamic instead of using a class-wide guard
  that engine singleton overrides could invalidate.

The full gem suite passes: 58 runs, 1583 assertions, 3 skips. Ruby 3.4.11
targeted compiler/loader/end-to-end tests pass: 20 runs, 483 assertions,
1 skip. Rust tests pass (22 unit + 2 integration). The two loader-policy
regressions fail on pre-fix main and pass with the fix. A further cached-hijack
regression fails without the follow-up recipe guard and passes with it;
tests cover actual frozen-literal behavior and lowered-file delivery, not
just process success.

### Build surface (2026-10-20)

Materialize, as added modules / methods / generated scripts per step after
`config/environment` (real-blog 5210 / 36752 / 1155 at boot, Campfire 6840
/ 49628 / 1602):

| step | real-blog | Campfire |
|---|---|---|
| `eager_load!` | +1520 / +9114 / +693 | +791 / +2765 / +464 |
| production eager load (Zeitwerk all, namespaces) | +726 / +4203 / +144 | +955 / +5895 / +174 |
| models (schema, attribute methods) | +41 / +524 / +48 | +26 / +4110 / +266 |
| relation delegation (speculative) | 0 | +0 / +6 / +6 |
| lazy routes | +0 / +68 / 0 | +88 / +704 / +22 |
| controllers (`view_context_class`) | +7 / +145 / +32 | +7 / +145 / +31 |
| templates compiled | +1 / +30 / +28 | +2 / +154 / +104 |

Generated scripts: real-blog 2096 (0.75 MB), Campfire 2664 (1.2 MB); methods
compiled from one: 5657 / 8960; app-relevant methods with a linked
generated `def`: 299 / 2840. Capture costs ~15–25 ms of hook time
(boot +0.05 s on real-blog, within noise on Campfire's 2 s).

Observed test run against the materialized facts: real-blog defines 9942
methods after boot, Campfire 19524; all but 1438 / 4446 are in the facts
(by name, generated `def` text, or template). The rest is test-only code
(Minitest/Rails testing, fixtures, mocha, webmock, rexml, DRb), no app
method; the only templates are Campfire's 8 exception-page templates,
recompiled per rendered exception (80 methods). Suite overhead: definitions
only +0.4 s real-blog (fixed cost), +3–4 % Campfire; with type sampling (16
per method, 586 methods hooked) +3–6 %; uncapped sampling up to +9 %.

## Learned

1. **Speed is in framework code** (M0: real-blog app self time ≈0 %,
   Campfire 1.5–4.9 %), so lowering targets Rails and gem code as used by the
   app, not just `app/**/*.rb`.
2. **Two delivery seams**: `load_iseq` for Ruby files, the handler call in
   `ActionView::Template#compiled_source` for templates.
3. **Per-call-site guards beat per-method guards** for a first pass: they
   keep line numbers, never evaluate arguments twice, and need no change to
   method tables.
4. **Partial evaluation through the booted app** (the oracle) is the robust
   way to "derive from the booted Rails app": constants come from Rails
   itself, and probes turn escaping assumptions into checked facts.
5. **Single helpers are small wins** (`link_to` 6.6 → 2.6 µs); measurable
   gains need many sites per request or framework paths per request
   (Campfire: CSP/importmap URL work 34.8 % inclusive on cached pages,
   Active Record dispatch and fragment keys when uncached).

6. **Boot is not the whole app, but materialize nearly is.** In test env
   `eager_load!` sees a quarter of what production eager load plus lazy
   generation build (Campfire: 2765 of 13779 added methods). After
   materialize, a full test run adds no app method; what it adds is test
   machinery. Generated code is only meaningful per `def`: Active Support's
   CodeGenerator shares method caches across models and batches them in
   run-dependent order, so script digests differ while `def` texts match.

## Next

- `direct`/`resolve` helpers and missing route arguments; host normalization
  is request-local now, but Rails' `url_options` assembly remains per call.
- Broader benchmark coverage and confidence intervals (preload runs now interleave on/off).
- Guarded memo for per-request work on boot-fixed inputs (ARGOS: Inertia
  asset-version digest 12.8 % self per request).
- Active Record attribute/reflection dispatch (ARGOS, Campfire uncached).
