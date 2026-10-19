# Status

Living summary of what works, what was learned, and what is next. Details
live in the linked docs; numbers come from executed runs, dated.

## Works (2026-10-20)

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
- **Runtime gem**: `load_iseq` seam (composes with Bootsnap in either order),
  template seam (lowered handler code while the source digest matches),
  guards that reset on every definition path and revalidate lazily
  (including stubs on single objects), per-view-class checks, env check,
  stats, Minitest outcome reporter across forked workers. Setup loads no
  default gems, so apps pinning `json` still boot.
- **`lowrail verify`**: suite with `LOWRAIL=0` and `1`, per-test outcomes and
  fast-path hits.
- **Types and MCP** (first iteration, other thread): boot-first types with
  provenance, RBS generation, stdio MCP server. See `docs/types.md`.

## Evidence

| App | Lowered | verify | Other |
|---|---|---|---|
| real-blog (Rails 8.1.4) | 9/9 `link_to` sites, 5 templates | 21/21 identical, 58 fast-path hits | 4 HTML routes byte-identical on/off (CSRF masked); speed change within noise (allocs −3 % on index) |
| Campfire (Rails 8.2 alpha) | 0/4 `link_to` sites (shapes refused, see ledger) | 634/634 identical (2 skips both ways), hooks installed, 0 units | M0 in `docs/m0/campfire.md` |
| ARGOS (private, Rails 8.1.4) | not built yet | — | M0 aggregates in `docs/m0/argos.md` |

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

## Next

- Route-helper specialization in templates and Ruby files (first Ruby-file
  pass through `load_iseq`).
- Benchmark harness with interleaved on/off runs and confidence intervals.
- Guarded memo for per-request work on boot-fixed inputs (ARGOS: Inertia
  asset-version digest 12.8 % self per request).
- Active Record attribute/reflection dispatch (ARGOS, Campfire uncached).
- Bisection of verify differences to a unit, and a per-app denylist.
