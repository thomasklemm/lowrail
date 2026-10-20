# Pass `route/path` — named-route `*_path` helpers

Code: `src/lower/route.rs` (pass), `gem/lib/lowrail/routes.rb` (runtime),
`gem/lib/lowrail/oracle_routes.rb` (build-time oracle side), route facts in
`gem/lib/lowrail/guard.rb`. Runs on compiled ERB (after `view/link_to`, so
route calls inside its fast path are lowered too) and on every `*.rb` under
`app/` except `app/assets` and `app/javascript`.

## What Rails does (Action Pack 8.1.4 and 8.2 alpha)

`name_path(*args)` is a `define_method` in the route set's anonymous
`path_helpers_module`. It pops a trailing `Hash` / `ActionController::Parameters`
as options and calls the route's `UrlHelper`. Routes without requirements
and without a glob get an `OptimizedUrlHelper`, whose fast branch runs when
`args.size == required_parts.size`, there are no options, and
`t.send(:optimize_routes_generation?)` (no `default_url_options` on the
route set or the caller):

```text
options = t.url_options.merge(route.defaults)
params  = {part_i => args[i].to_param}          # nil or "" → UrlGenerationError
path    = route.format(params)                  # Journey: static text + escape_segment(value);
                                                #   optional groups like (.:format) dropped
path   << "/" if options[:trailing_slash]
script  = options.delete(:script_name) || t._routes.relative_url_root || ""
script  = options[:original_script_name] + script if present
result  = script.to_s.chomp("/") << path        # Http::URL.path_for, + params/anchor keys
```

Everything else (`super`) goes through `RouteSet#url_for` with recall,
`path_params` and Journey's generator. In a request, a controller's
`url_options` is a fresh frozen hash with host, port, protocol, `_recall`
and `script_name` (`""` unless mounted), or `original_script_name` for
engines. 8.1.4 escapes a `:controller` segment with `escape_path`; 8.2 uses
`escape_segment` for all segments (the probes catch the difference).
Production frees the route AST after boot (`Route#glob?` raises there), so
globs are read from the path spec.

## What is specialized

Shape: receiverless call, no block, only positional arguments (no hash
literal, keywords, splats), exactly one per required part, inside an
instance method (any `def` without receiver in a Ruby file; always in a
template), arguments on one line. The pass emits, on the call's first line:

```ruby
((::Lowrail.ok?(U, self.class)) ? (__lr0a0 = ARG; (!(::Hash === __lr0a0 || ::ActionController::Parameters === __lr0a0) &&
  optimize_routes_generation? && (__lr0s = ::Lowrail::Routes.prefix(url_options, self)) &&
  ::String === (__lr0p0 = __lr0a0.to_param) && !__lr0p0.empty?) ? (__lr0s << "/articles/" << ::Lowrail::Routes.seg(__lr0p0) << "/edit") : edit_article_path(__lr0a0)) : (edit_article_path(article)))
```

(one line in the output). Arguments are evaluated once, in order. Rails' own
conditions stay calls, so `default_url_options`, mounted script names and
`to_param` overrides behave as before; `Routes.prefix` returns nil (helper
called) for `trailing_slash`, `original_script_name`, `params`, `anchor`,
non-`Hash` or defaulting option hashes. `Routes.seg` returns an ASCII value
with no character Journey would escape as is, else calls
`Journey::Router::Utils.escape_segment`. Templates add
`defined?(name) == "method"` for argument-less calls, since a local passed to
`render` may shadow the helper.

Facts per unit: each helper as `@self#name_path` with the route
(`name`, path spec, required parts, `defaults.inspect`), checked per class of
`self` (owner must be `Rails.application.routes.named_routes.path_helpers_module`,
route unchanged, no requirements, no glob), plus the Rails methods whose
behavior is inlined (`OptimizedUrlHelper#call/optimized_helper/parameterize_args/optimize_routes_generation?`,
`Journey::Route#format/required_parts`, `Journey::Format#evaluate`,
`RouteSet#find_script_name/relative_url_root`, `Http::URL.path_for`,
`Router::Utils.escape_segment`, `UriEncoder#escape_segment/escape`).
Redrawing routes redefines the helpers, which resets the units.

## How it is proven at build time

The oracle (booted app) reports the route behind each helper and calls it
with marker arguments (`LRHP0Q`) to get the template; the pass refuses unless
each marker appears once and the static text is ASCII. It then evaluates the
exact inner expression it will emit next to the real helper call, for ~37
argument values per position (special characters, `/`, `%`, non-ASCII,
binary and broken UTF-8, UTF-16, `""`, `nil`, Integer, bignum, Float,
Symbol, Array, `{}`, options hash, `ActionController::Parameters`,
SafeBuffer, `BasicObject`, records with and without id), in five contexts
(the oracle's view; views and controllers of requests routed through the
app's route set with `SCRIPT_NAME` `""` and `"/sub/"`), comparing class,
bytes, encoding, frozen, html_safe, or exception class and message. Any
difference refuses the helper. In a `class` body (not a module) the oracle
also checks the helper resolves to the route set's method in that class.

## `*_url` helpers

Same shape as `*_path`, starting from `Lowrail::Routes.url_prefix(url_options,
self)` instead of `prefix`. Rails ends `OptimizedUrlHelper#call` in
`Http::URL.url_for(options)`: `path_for` with `:only_path`, else
`build_host_url(host, port, protocol, options, path_for(options))`.
`url_prefix` calls Rails' own private `build_host_url` with the script name
as the path, so host/port/protocol normalization, `subdomain`/`domain`/
`tld_length` and `user`/`password` are Rails' code, not a copy; the route
path is appended afterwards. A missing or non-String host and an invalid
protocol return nil, so the real helper raises after `to_param`, as Rails
does. Route defaults with host-part keys are refused. Facts add
`Http::URL.url_for/full_url_for/build_host_url/normalize_*` and require the
helper to be the route set's URL helper module method. Probes add an
`https://user.example.co.uk:8443` request context.

Per call (real-blog, controller with an HTTPS request, YJIT, 3 runs):
`article_url(article)` 4.6–5.1 → 2.6–3.0 µs, 24 → 16 allocations. Most of
what remains is the controller's `url_options` hash, which Rails builds on
every call.

## Refused (ledger reasons)

Direct /
resolve helpers (`CustomUrlHelper`, e.g. `rails_blob_path`), explicit
receiver (`main_app.x_path`, `url_helpers.x_path`), options hash, arity ≠
required parts (Rails recalls missing parts from the request), not in an
instance method, a nested route call (the inner one is lowered), multi-line
arguments, requirements or glob, route defaults that set url options,
helper overridden in that class, probe mismatch.

## Results (2026-10-20, Ruby 4.0.7)

| App | Route sites lowered | Units | `lowrail verify` |
|---|---|---|---|
| real-blog (8.1.4) | 10/10 (9 template, 1 controller) | 6 | 21/21 identical; 110 hits across all 11 units (link_to + route) |
| Campfire (8.2 alpha) | 108/162 with `_url` (51 of them `_url`; 27 Ruby files, 32 templates) | 59 | 634/634 identical (2 skips both ways); 52 units hit, 13238 hits, 0 fallbacks |

Before `_url` (57/162): 33 units, 12140 hits. Campfire refusals now:
18 direct helpers (`fresh_*`, `rails_blob_path`),
17 arity, 11 options hash, 4 explicit receiver, 2 model methods named like
route helpers (`Webhook#message_path`), 1 class-body call.

real-blog HTML (production build, `bench/requests.rb` `BENCH_DUMP`, CSRF
tokens masked): `/articles`, `/articles/1`, `/articles/1/edit`,
`/articles/new` byte-identical with `LOWRAIL=0` and `1`.

Micro (production, YJIT, view of a routed request, median of 5×300k):

| Call | Rails | lowered |
|---|---:|---:|
| `edit_article_path(article)` | 2701 ns | 1389 ns |
| `articles_path` | 1444 ns | 614 ns |

What remains is what Rails semantics require per call: `url_options`
265 ns (a dup per call in controllers), `optimize_routes_generation?`
121 ns, `article.to_param` 473 ns, the guard 82 ns.

Requests (real-blog, production, YJIT, 6 interleaved rounds of off /
link_to units only (`LOWRAIL_UNITS`) / link_to + route, 3 s per route after
200 warm-up requests):

| Route | off µs (min–max) | link_to only | + route | allocs off → + route |
|---|---|---|---|---:|
| GET /articles | 2056 (1948–2452) | 2084 | 1972 (−4.1 %) | 2378 → 2226 |
| GET /articles/1 | 2184 (1822–2561) | 1992 | 1998 (−8.5 %) | 2253 → 2227 |
| GET /articles/1/edit | 1464 (1324–1549) | 1437 | 1452 (−0.8 %) | 1716 → 1686 |
| GET /articles/new | 1319 (1098–1464) | 1256 | 1274 (−3.4 %) | 1594 → 1582 |

The spread inside one configuration (10–25 %) is larger than every
difference, so the request-time change is **within noise**. Allocations
are stable and drop by 1–6 %. Expected gain: real-blog renders few route
calls per request (~1.3 µs saved each), well under 1 % of a 1.3–2 ms
request.

## Open risks

- On the slow branch after a runtime condition fails, `url_options`,
  `optimize_routes_generation?` and `to_param` run again inside the helper
  (Rails itself calls `to_param` twice before raising). Pure in Rails; an
  app override with side effects would see an extra call.
- The guard calls `self.class`; an object overriding `class` would be
  checked against that answer.
- Fact names `call`, `format`, `evaluate`, `escape` are common: defining
  any method with those names resets the route units (re-validated on the
  next call per class). Harmless at boot, a cost if code defines such
  methods per request.
- Route facts compare spec, parts and defaults; requirements and globs are
  checked as absent. Engines' own helper modules and `main_app` calls are
  refused, not specialized.
- Ruby-file call sites without arguments rely on Prism's view of local
  variables; locals created by `eval`/`binding.local_variable_set` are not
  seen.
- `direct`/`resolve` helpers (18 in Campfire) and arity mismatches
  (Rails recalls parts from the request, 17) are now the largest refused
  groups.
