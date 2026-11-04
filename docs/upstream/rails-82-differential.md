# Rails 8.2 differential: 8-1-stable vs main on generated inputs (2026-11-04)

Rails main ships as 8.2 soon. This round runs the same generated inputs through 8-1-stable and main and diffs every
output and exception, to find behaviour changes nobody meant to make before they reach users.

**Result.** About 450,000 cases per side; 26 functions differ. Every difference traces to a commit. Two are
accidents and get a fix each (F1, F2; fork branches, patches below, not opened). The rest are intended: most
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
  string is `""` (+4/−2), plus two tests. Fork branch
  [`thomasklemm/to-query-skip-empty-nested`](https://github.com/thomasklemm/rails/tree/thomasklemm/to-query-skip-empty-nested)
  @ `2750d65efd` on main `8b06b0eb98`
  ([patch](../../fixtures/corpus/rails-82-diff/patches/f1-to-query-skip-empty-nested.patch)).
* **Type check kept** (Sol: not redundant). An empty Array as a whole still serializes to the bare key:
  `[].to_query("a")` is `"a%5B%5D"` on 8.1 and with the fix. (Sol's note expected `"a%5B%5D="`; the source has
  `nil.to_query(prefix)`, which adds no `=`.) `{ a: [] }.to_query` stays `""`.
* **Tests:** `test_nested_values_with_an_empty_query_are_skipped` fails without the change. The second,
  `test_nil_false_and_blank_values_in_arrays_are_kept`, asserts the exact string for
  `{ a: [nil, false, "", [[]]], b: 1 }` (`"a%5B%5D&a%5B%5D=false&a%5B%5D=&b=1"`), so a fix that drops every blank
  value fails it (that variant returns `"b=1"`). Hash values `nil`/`false`/`""` were already covered by
  `test_nested_empty_hash`. 18 runs pass; the Object, Hash and Array core-extension tests and the URL/routing/request
  tests in Action Pack pass. Harness rerun: 0 outputs with a stray `&`, against 34 on main and 205 on 8.1.
* **Upstream search:** no open PR or issue on `to_query` or empty nested values; #57500 and #57677 are merged.

> **Skip nested values that serialize to an empty query in to_query**
>
> #57677 changed `Array#to_query` to skip empty Hash and Array elements by their type, instead of skipping any element whose query string is empty, as #57500 did. An element that is not empty itself but only holds empty collections still serializes to an empty string, so it adds an empty pair again, and `Hash#to_query` keeps such values too. `{ q: [[]], page: 2 }.to_query` returns `"&page=2"`, and since `url_for` passes extra options through it, such a parameter produces `/search?&page=2`.
>
> This keeps the type check and also skips a value whose query string is empty, in both methods. Dropping such fragments prevents stray separators and keeps every non-empty parameter. One test covers an Array and a Hash that hold only empty collections, and another checks that `nil`, `false` and empty strings inside an Array are still kept.

## F2: URL helpers keep generating empty arguments with default URL options

* **Change:** in the optimized helper's `call`, fall back to the general path when `optimized_helper` returns `nil`
  and default URL options apply (`|| default_url_options?(t)`, +3/−3 with the comment), plus a boundary test and
  two calls in the existing comparison test. Fork branch
  [`thomasklemm/optimized-url-helpers-blank-arguments`](https://github.com/thomasklemm/rails/tree/thomasklemm/optimized-url-helpers-blank-arguments)
  @ `2b4a97089a` on main `8b06b0eb98`
  ([patch](../../fixtures/corpus/rails-82-diff/patches/f2-url-helpers-blank-arguments.patch)).
* **What `default_url_options?(t)` is** (added by #59479, `route_set.rb:312`): true when the route set's
  `default_url_options` or the receiver's `default_url_options` is non-empty, which is "default URL options apply".
  Two `empty?` checks and a `respond_to?`; the same call already guards the optimized path for routes whose options
  aren't optimizable. The new use sits inside `if path.nil?`, after `optimized_helper` gave up and only before the
  error is raised, so every URL the optimized helper builds is unchanged; only the error path differs.
* **Tests:** the comparison test ("default URL options that do not shape the path generate the same URL as the
  general path") gets `article_path("")` and `article_url(record)` with an empty `to_param`, and fails without the
  change. New boundary test: without default URL options, `product_path("")` still raises with the "missing
  required keys" message. A wrong fix that always returns `super` when the path is `nil` fails it, and fails the
  existing `product_path(nil)` message test. routing_test 359 runs pass; with the other URL and routing files,
  783 runs.
* **Upstream search:** no open PR or issue; #59479 is merged (by amatsuda, 2026-10-31).

> **Generate URLs for empty arguments with default URL options as before**
>
> Since #59479, the optimized URL helpers also run when the default URL options only set reserved options such as `:host`. For an empty-string argument or a record whose `to_param` is empty, the optimized helper raises `UrlGenerationError`, while the general path, which these helpers used before, generates the URL. So with `default_url_options[:host]` set, as in a mailer, `post_url(post)` for a post whose `to_param` is `""` now raises instead of returning `http://example.com/posts/`.
>
> This falls back to the general path when the optimized helper can't build the path and default URL options apply, as it already does when options are passed. The fallback runs only after the optimized helper gave up, so every URL it builds stays the same, and `true`, `false` and `nil` arguments behave as they do without default URL options. A new test checks that without default URL options an empty argument still raises.

## Review status

Both fixes follow "Correctness fixes: readable first": one condition or one line each, in the shape of the
surrounding code, no measurements. Sol (from the patches and this doc): both "open with nits"; the nits are applied above. F2 opened as
[rails/rails#59625](https://github.com/rails/rails/pull/59625) on 2026-11-04 (head `2b4a97089a`). F1 opened as a draft,
[rails/rails#59626](https://github.com/rails/rails/pull/59626) (head `2750d65efd`), to be marked ready when a slot frees up:
GitHub caps users without write access at 15 open PRs per repository, which is why the creates returned 404.

## Round 2: view helpers, type casting, SQL on three visitors, recognition (2026-11-04)

**Result.** About 1,020,000 cases per side, same pins and lockfiles as round 1. No new accidents. Every difference
traces to a commit that is either in a CHANGELOG or a deliberate, harmless fix; nothing here needs a fix or a
CHANGELOG note.

### Method

* **Harness:** [harness2.rb](../../fixtures/corpus/rails-82-diff/harness2.rb), on top of round 1's generators (same
  seed, then the same random stream continues), still generated before Rails loads. Classifiers:
  `formclass.rb` (which options explain a form difference) and `sqlclass.rb` (which relation ops explain a SQL
  difference).
* **View (177,000 cases):**
  * the form builder on an Active Model object with generated values: text, number, hidden, password, email,
    date, datetime-local and time fields, text area, check box, radio button, label, select, multiple select,
    `collection_select`, `grouped_collection_select`, `collection_check_boxes`, `collection_radio_buttons`,
    `options_for_select`, `grouped_options_for_select`, `select_tag`, `fields`, the date/time selects,
    `time_zone_select`, submit and button. Generated attribute hashes and select options (`include_blank`,
    `prompt`, `selected`, `disabled`, `multiple`, `include_hidden`) and choice shapes;
  * the text helpers (`pluralize`, `truncate`, `simple_format`, `highlight`, `excerpt`, `word_wrap`), sanitizing
    (`sanitize` with tag and attribute lists, `strip_tags`, `strip_links`, `sanitize_css`), number helpers,
    `distance_of_time_in_words` and `time_tag` in four zones, and tag/link/mail/phone helpers, over generated HTML
    with scripts, event handlers, `javascript:` and `data:` URLs.
  * Every HTML result is compared exactly and after normalisation (parsed with Nokogiri's HTML5 parser,
    attributes sorted), so attribute-order changes are reported separately.
* **Types (765,000 cases):** 36 types (all built-in Active Model types, limit/precision/scale variants, JSON,
  `DecimalWithoutScale`, `UnsignedInteger`, and 15 PostgreSQL OID types) × 2,000 generated input pairs (blank and
  boolean-like strings, integer boundaries, floats with NaN/Infinity, BigDecimals, date and time strings across DST
  edges, Dates, TimeWithZones in 10 zones, JSON, PG literals, ranges, binary): `cast`, `serialize`, `deserialize`,
  `serializable?`, `changed?` and `changed_in_place?`, under four `Time.zone` values, plus dirty tracking on an
  Active Model object with one attribute of each type. Targeted extras: Decimal with 9 precision/scale pairs,
  BigInteger/Integer(limit: 8)/Float on numeric strings, 2,018 UUID spellings, Serialized with String and
  ImmutableString subtypes, and a SQLite Active Record model (new, assign, save, reload, changes, dup, clone,
  `serializable_hash`, `where`) with time-zone-aware attributes.
* **SQL (2,000 relation chains):** round 1's ops plus `merge`, `or`/`and` with another relation, `from` a subquery,
  `matches`, endless ranges, subquery `IN`, optimizer hints, `reverse_order`, `lock` and `with`. Each chain rendered
  by SQLite, by an unconnected PostgreSQL adapter and by an unconnected Mysql2 adapter (string quoting stubbed with
  the same pure function on both sides, server versions fixed), and its rows read from a seeded SQLite database.
* **Recognition (59,000 cases):** a route set with concerns, shallow nesting, namespaces, a `module:`/`path:` scope,
  constraints, an optional segment, a glob, an optional locale scope, a singular resource, `path_names` and a
  redirect. 8,000 paths (round 1's random ones plus paths built from the route patterns with random, partly
  percent-encoded segments and format suffixes) × five verbs: `recognize_path`, then `path_for`, `url_for` and
  the route's named helper with the recognized params. 4,812 paths are recognized.

### Differences

| Surface | Difference (8.1 → main) | Commit | Class | Action |
| --- | --- | --- | --- | --- |
| Form builder, tag options | Same attribute changes as round 1 (nested Hash attributes dasherized, `hidden` values, `open`, blank names); 13,700 of 13,869 form differences. No attribute-order-only difference anywhere. | round 1 rows | Intended, in CHANGELOG | None |
| `time_zone_select` | New zones in the list: `Pacific Time (Canada)`, `Alberta`, `Northwest Territories`, `Manitoba` | `38c63e2013` and the Manitoba/NWT commits | Intended, in CHANGELOG | None |
| Multiple `select` with `form:` | The hidden companion field carries the same `form` attribute (`<input name="person[role][]" type="hidden" value="" form="f">`), so clearing every option is submitted when the select lives outside its form | `7fae0020ff` | Intended fix, undocumented | None |
| PG integer arrays, `serialize` | The returned `Data` carries a typed element encoder; encoded text identical for every input tried | `ce948ef38f` | Intended, in CHANGELOG | None |
| PG integer arrays, `deserialize` | An empty element (`"{1,}"`, `"{ }"`, `"{\"\"}"`) decodes to `0` instead of `nil`; `cast` unchanged | `ce948ef38f` (C decoder) | Intended; edge undocumented | None: PostgreSQL never returns empty elements for an integer array, so only hand-written literals passed to `deserialize` see it |
| PG interval, `serialize`; dirty tracking | `"PT0.0000001S"` instead of `"PT1.0e-07S"`; an interval attribute assigned such a value no longer looks changed on reassignment | `58b8fb7050` | Intended, in CHANGELOG | None |
| `Serialized` with an ImmutableString subtype | Mutating the deserialized String in place is now detected by `changed_in_place?` | `8e9b18a24f` | Intended fix, undocumented | None |
| Active Record `attributes` after assigning and saving | Schema order instead of assignment order | `61480bf2d1` (main's lazy attribute set) | Intended | None |
| `dup` of a new record | `dup.attributes == record.attributes` is false when a value is a BigDecimal `NaN`: the duplicate gets its own copy, and `NaN` never equals another `NaN`; every other value compares equal | lazy attribute set commits | Intended, harmless | None |
| Enum, invalid value | The `ArgumentError` lists the valid values | `fcf4393f04` | Intended, in CHANGELOG | None |
| SQL (all three visitors) and SQLite rows | Only round 1's two causes: `WHERE (1=0)` for an empty tuple `where` (8.1 sent invalid SQL) and the join order/aliases of `includes` with joins | `cf9c0879ca`, `48f3e61a41`, `b0ded066af` | Intended | None |

No difference in the text, sanitizing, number, time and tag helpers; in any other type's cast, serialize,
deserialize or change detection; in UUID handling (despite the new fast path); in decimal scale rounding (despite
two changes there); in any PostgreSQL- or MySQL-only SQL; or in recognition and generation.

**Pre-existing, the same on 8.1 and main (not 8.2 regressions, recorded only):** `changed?` raises `ArgumentError:
comparison of Rational with BigDecimal failed` on the types that pass values through unchanged (binary, PG range,
money, hstore and others) when the old value is a Time or Date and the new one a BigDecimal (74 cases), because
`Time#==` compares through `<=>`; casting an integer array element `"x"` gives `0` while serializing it gives
`NULL`.

