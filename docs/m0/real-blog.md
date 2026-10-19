# M0 — real-blog, where the time goes

Ruby 4.0.7 +YJIT, Rails 8.1.4, production env, SQLite, in-process Rack
(`bench/requests.rb`), 4 s per route after 200 warm-up requests, one orb core.
Profile: stackprof wall mode, 100 µs interval, `bench/profile_summary.rb`
(C functions charged to their Ruby caller).

| Route | req/s | µs/req | allocs/req |
|---|---:|---:|---:|
| GET /articles | 554 | 1805 | 2379 |
| GET /articles/1 | 527 | 1898 | 2254 |
| GET /articles/1/edit | 621 | 1609 | 1717 |
| GET /articles/new | 834 | 1199 | 1595 |
| GET /articles.json | 913 | 1095 | 1299 |
| GET /articles/1.json | 1964 | 509 | 643 |

Self time by area (all four HTML routes): actionview 19.9 %, activesupport
18.3 %, actionpack 13.0 %, activerecord 9.5 %, stdlib (OpenSSL, pathname,
monitor) ~11 %, rack 6.1 %, GC sweeping 5.3 %, i18n ~4 %. **App Ruby code is
≈0 % self**; the app is only present as compiled ERB templates.

Inclusive time of notable frames:

| Frame | total |
|---|---:|
| `ActionView::Template#render` (all templates) | 57.9 % |
| `ActionView::Renderer#render_partial` | 35.6 % |
| `FormHelper#form_with` | 20.6 % |
| `RequestForgeryProtection#form_authenticity_token` (HMAC per form) | 9.4 % |
| `TagBuilder#tag_options` | 5.8 % |
| `ActiveSupport::Notifications.instrument` wrappers | 72 % (wrapping; self small) |

HTML show (1898 µs) vs JSON show (509 µs): about **1.4 ms of 1.9 ms is view
rendering**, i.e. helpers, partial lookup and HTML building inside Rails.

## Conclusions

1. **Speed is in framework code, not app code.** Lowering only `app/**/*.rb`
   would change nothing measurable here. The `load_iseq` seam must cover gems,
   and the planner must target framework methods specialized for this app.
2. **Templates need their own seam.** ActionView compiles ERB with
   `module_eval`, so `load_iseq` never sees it. Lowrail needs a second
   delivery point at template compilation (`ActionView::Template#compile!`),
   where a lowered compiled source replaces Rails' one, guarded the same way.
3. **The biggest lever is view lowering**, which is also where Roundhouse is
   strongest (`src/lower/view_to_library/`, `form_builder.rs`,
   `tag_builder.rs`): `form_with`, `link_to`, `tag.*`, `dom_id`, partial
   resolution, with constant HTML precomputed at build time under boot facts
   (helper owners, form builder class, config such as
   `form_with_generates_ids`). The correctness check is byte-identical
   responses with Lowrail on and off, in addition to identical tests.
4. Per-request fixed costs (middleware, encrypted cookie session, CSRF HMAC
   per form) are a second tier; some are cacheable per request, not per
   build, and need care around security semantics.

Caveat: real-blog is a scaffold. Campfire and ARGOS (Inertia: JSON props, no
server-side ERB for pages) will shift the balance toward controllers,
serialization and Active Record; M0 is repeated there before choosing M4's
order.

## Helper micro-benchmarks (same setup, view context of a booted controller)

| Call | µs |
|---|---:|
| `link_to "Show", article, class: …` | 6.56 |
| same HTML built inline (escape + `article_path`) | 2.61 |
| `article_path(article)` | 2.04 |
| `polymorphic_path(article)` | 3.32 |
| `dom_id(article)` / inline `"article_#{id}"` | 0.72 / 0.14 |
| `pluralize(3, "comment")` (I18n + inflector) | 6.36 |
| `truncate(body, length: 100)` | 1.11 |
| `button_to "Destroy", article, method: :delete, …` | 27.71 |
| `form_authenticity_token(form_options: …)` (per-form HMAC) | 11.84 |
| `article.comments.size` (COUNT query) | 26.30 |

Per article in the index partial, helpers cost ≈ 60 µs, of which roughly
half is specializable (route helpers, `link_to`/`tag` building, `dom_id`,
`pluralize` under a locale/inflection fact). The CSRF HMAC must stay per
request, and the COUNT query is a data-access question (preload / counter
cache), not a lowering one.

**Estimate:** helper and route-helper specialization alone gives on the
order of 10–25 % on real-blog's HTML routes, not multiples. Larger gains
need specializing the per-request framework path itself (middleware chain,
instrumentation, callbacks, session/cookie handling), which is where the
boot facts matter most. Both are measured, not assumed, as passes land.
