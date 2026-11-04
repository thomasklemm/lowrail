# Rails 8.2 differential: 8-1-stable vs main on generated inputs (2026-11-04)

Rails main ships as 8.2 soon. This round runs the same generated inputs through 8-1-stable and main and diffs every
output and exception, to find behaviour changes nobody meant to make before they reach users.

**Result.** About 450,000 cases per side; 26 functions differ. Every difference traces to a commit. Two are
accidents and get a fix each (F1, F2; local Rails branches, patches below, not opened). The rest are intended: most
are in a CHANGELOG, and six are undocumented but harmless (encodings, frozen strings, a valid `WHERE (1=0)` instead
of invalid SQL, error messages). I don't think any of them needs a CHANGELOG note.

## Pins and method

* **Rails:** 8-1-stable `6e09124217` (v8.1.4.1) and main `6c23cb8f2a` (2026-11-04), fixes on main `8b06b0eb98`.
  Merge base `8ae3d84277`.
* **Ruby:** 4.0.9. Both lockfiles aligned on the gems that could change outputs (rack 3.2.8, uri 1.1.2, nokogiri
  1.19.7, concurrent-ruby 1.3.8, sqlite3 2.10.2; i18n, tzinfo, json, rails-html-sanitizer, erubi already equal).
* **Harness:** [fixtures/corpus/rails-82-diff/harness.rb](../../fixtures/corpus/rails-82-diff/harness.rb). Inputs
  are generated with core Ruby only, from seed `20261104` with N = 2000, before Rails loads, so both sides get
  identical inputs. Each case prints its result or exception class and message; Strings carry encoding and
  frozenness, SafeBuffers their `html_safe?`. Surfaces:
  * inflections and String extensions (43 functions over about 2,100 words);
  * number helpers (Active Support and Action View, 40 option sets), phone numbers;
  * Duration building, arithmetic and ISO 8601 parsing; TimeWithZone formatting, `change`, `advance`, edges,
    comparisons and parsing in 10 zones (DST gaps and overlaps, Lord Howe, Chatham, Apia); `distance_of_time_in_words`;
  * `to_query`/`to_param` on nested Hashes and Arrays, with a Rack round trip;
  * JSON encoding (escaping on and off, time precision, non-standard time format) and decoding;
  * ERB escaping, SafeBuffer operations, the text and sanitize helpers, the tag builder, `content_tag`, `tag`,
    `class_names`/`token_list`, form tags;
  * `url_for`, named helpers and recognition on a route set with nested resources, constraints, globs, optional
    scopes and a redirect;
  * Active Record SQL for 2,000 chains of `where`/`not`/`or`/`order`/`joins`/`includes`/`group`/`in_order_of`/
    tuples, plus Arel predicates, sanitizing and quoting.
* **Comparison:** `cmp.rb` and `split.rb` group differences by function; `bisect/run.sh` runs one check file per
  `git bisect run` against main's bundle with the bisected worktree's `lib` directories.
* **Extra probe:** [url_helpers_positional.rb](../../fixtures/corpus/rails-82-diff/url_helpers_positional.rb),
  4,580 positional URL helper calls with `default_url_options[:host]` set, which the main harness doesn't cover.

## Differences

| Surface | Difference (8.1 → main) | Commit | Class | Action |
| --- | --- | --- | --- | --- |
| `Hash#to_query`, `Array#to_query`, `url_for` extras | Empty nested collections no longer add `a[][]`; but a value that holds only empty collections now adds an empty pair: `{ q: [[]], page: 2 }.to_query` is `"&page=2"`, `url_for(…, q: [[]])` gives `"/search?&page=2"`, `{ a: [1, [[]], 2] }` gives `&&` | #57500 (`68160c4417`) skipped elements with an empty query; #57677 (`208fa7c015`) replaced that with a type check, which brought the empty pairs back for nested values | Intended (both no CHANGELOG); **the `&`/`&&` is an accident** | **F1** below |
| Positional URL helpers with `default_url_options` (host etc.) | `post_url(post)` with a blank `to_param` (`""`, `[]`) returned `"http://…/posts/"`; now raises `UrlGenerationError`. Hits mailers and serializers that set a host. | #59479 (`8e36346c17`) keeps the optimized helpers with such defaults; their blank-argument check raises where the general path generated the URL | **Accident** | **F2** below |
| Tag helpers | Nested Hash options render as dasherized attributes (`hx: { post: … }` → `hx-post`, value JSON-encoded and escaped); `hidden: "until-found"` renders as is; more boolean attributes (`open`, `shadowroot*`); blank-after-`to_s` attribute names skipped | `b3dcad2f50`, `242f0c8248`, `a4de7e6fc7`, `99a3247ebc` | Intended, in Action View CHANGELOG | None. Escaping checked by hand with quotes, `<`, `&` in keys and values. |
| `String#mb_chars` | Removed | `76f770fd05` | Intended, in CHANGELOG (deprecated in 8.1) | None |
| Number helpers, `Float::INFINITY` | `number_to_delimited` → `"Infinity"` instead of `"In,fin,ity"`; `significant: true` returns `"Inf"` instead of raising `FloatDomainError` | `150e4c0443`, `a9a6bc9505` | Intended, in CHANGELOG | None |
| Number helpers, encoding | Results are UTF-8, were US-ASCII | `2ecce1b3b9` | Intended (refactor), undocumented | None: ASCII-only either way, compares and concatenates the same |
| `TimeWithZone#to_s` | Result is US-ASCII, was UTF-8 | `f91c1e35ee` | Intended (refactor), undocumented | None, same reason |
| `TimeZone#name`, route verbs | Frozen Strings | `26e78a20db` (TimeZone shareable for Ractors), Journey verb matchers (`e04d378447`, likely; not bisected) | Intended, undocumented | None; only code that mutates a zone name or verb in place would notice |
| `Symbol#to_param` | Returns the frozen `Symbol#name` | `ed3f4eafe6` | Intended, in CHANGELOG | None |
| `where([:a, :b] => [])` | `WHERE (1=0)` instead of `WHERE ()` (invalid SQL on 8.1) | `cf9c0879ca` | Intended fix, undocumented | None; 8.1 raised at query time |
| `includes` + `left_joins` of the same associations | Join order and aliases change (`authors` instead of `authors_posts`) | `48f3e61a41` (#54181), `b0ded066af` (#44922) | Intended, in CHANGELOG | None |
| `UrlGenerationError` messages | "missing required keys" instead of "possible unmatched constraints"; the `[:controller]` hint is gone | optimized URL helper PRs #59350, #59474 and the dynamic-segment removal | Intended, message only | None |
| `get ":controller(/:action(/:id))"` | Raises `ArgumentError` | `92d809905b` | Intended, in CHANGELOG | Harness route removed |

No difference in inflections, Duration, TimeWithZone arithmetic, DST handling, parsing, JSON, ERB escaping,
SafeBuffer, the text helpers, Arel predicates, sanitizing or quoting.

**Left as is:** with default URL options, `post_path(true)` and `post_path(false)` raise `NoMethodError` on main
(8.1: `"/posts/true"`, `UrlGenerationError`). That is what both versions already do without default URL options;
F2 doesn't change it.

## F1: to_query skips nested values that serialize to an empty query

* **Change:** in `Array#to_query` and `Hash#to_query`, keep the type check and also drop an element whose query
  string is `""` (+4/−2), plus one test with both shapes. Branch `thomasklemm/to-query-skip-empty-nested` @
  `fbd3fb7b3f` on main `8b06b0eb98`, local
  ([patch](../../fixtures/corpus/rails-82-diff/patches/f1-to-query-skip-empty-nested.patch)).
* **Checks:** the new test fails without the change (`["a%5B%5D=1", "", "", "a%5B%5D=2"]`). The Object, Hash and
  Array core-extension tests (332) and the URL/routing/request tests in Action Pack (756) pass. Rerun of the query
  and routes harness with the fix: 0 outputs with a stray `&`, against 34 on main and 205 on 8.1.
* **Upstream search:** no open PR or issue on `to_query` or empty nested values; #57500 and #57677 are merged.

> **Skip nested values that serialize to an empty query in to_query**
>
> #57677 changed `Array#to_query` to skip empty Hash and Array elements by their type, instead of skipping any element whose query string is empty, as #57500 did. An element that is not empty itself but only holds empty collections still serializes to an empty string, so it adds an empty pair again, and `Hash#to_query` keeps such values too: `{ q: [[]], page: 2 }.to_query` returns `"&page=2"`, and `url_for` passes extra options through it, so such a parameter produces `/search?&page=2`.
>
> This keeps the type check and also skips a value whose query string is empty, in both methods. A value that serializes to an empty string adds nothing to the query, so dropping it only removes the stray `&`. The test covers an Array and a Hash holding only empty collections.

## F2: URL helpers keep generating blank arguments with default URL options

* **Change:** in the optimized helper's `call`, fall back to the general path when the arguments don't produce a
  path and default URL options apply (`|| default_url_options?(t)`, +3/−3 with the comment), plus two calls in the
  existing "same URL as the general path" test. Branch `thomasklemm/optimized-url-helpers-blank-arguments` @
  `0bb04b6d7d` on main `8b06b0eb98`, local
  ([patch](../../fixtures/corpus/rails-82-diff/patches/f2-url-helpers-blank-arguments.patch)).
* **Checks:** the extended test fails without the change (`article_path("", {}) with routes.default_url_options
  {host: "example.org"}`). `routing_test`, `url_for_test`, `controller/routing_test`, `route_set_test`,
  `integration_test`, `url_generation_test` and `journey/router_test` pass (782 runs). The positional probe: 556
  differences from 8.1 before, 16 after, all of them `true`/`false`/`nil` arguments as described above.
* **Upstream search:** no open PR or issue; #59479 is merged (by amatsuda, 2026-10-31), not reopened.

> **Generate URLs for blank arguments with default URL options as before**
>
> Since #59479, the optimized URL helpers also run when the default URL options only set reserved options such as `:host`. When an argument is blank, the optimized helper raises `UrlGenerationError`, while the general path, which these helpers used before, generates the URL. So with `default_url_options[:host]` set, as in a mailer, `post_url(post)` for a post whose `to_param` is `""` now raises instead of returning `http://example.com/posts/`.
>
> This falls back to the general path for such arguments when default URL options apply, as the helper already does when options are passed or when a route has requirements. Without default URL options nothing changes, since the optimized helper already raised there before #59479. The existing test that compares both paths under each set of default URL options now includes a blank argument and a record with a blank `to_param`.

## Review status

Both fixes follow "Correctness fixes: readable first": one condition or one line each, in the shape of the
surrounding code, no measurements. Not yet reviewed by Sol; patches sent to the coordinating thread. Not opened.
