# R7: refilling the Rails queue from census 7's narrower tiers

Bet R7 (2026-11-03). Census 7 found no exact candidate left among the lines that reach 7 or more apps. This round
looks for exact candidates in its 3–6-app and 2-app tiers, and in the Rails lines that matter in only one big app
(Discourse, Mastodon, Chatwoot, Sure). Candidates are ranked by objects per workload × apps. The numbers are
allocation counts only; no timing is claimed.

**Result.** Four candidates. Each is one commit on the thomasklemm/rails fork, on current rails/rails main
[`1597d576bd`](https://github.com/rails/rails/commit/1597d576bd222de7bf55bf7a12bffd87138f2a13), and has a test
that fails without it. None is opened.

| # | Branch @ SHA | Pattern | Per call (4.0.7 interp) | Census: workloads / apps moved at the site (A/A: 0) |
| --- | --- | --- | ---: | --- |
| R7-1 | [`thomasklemm/tag-values-without-copies`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-values-without-copies) [`d18c315d20`](https://github.com/thomasklemm/rails/commit/d18c315d201ed47c902cd754f07dab43fe2bca6a) | every `class_names`/`token_list`, every `class:`/`aria:` Array or Hash attribute | −1 to −2 | 18 / 4 (blog, fizzy, lobsters, sure); median −39.5, Sure up to −679 |
| R7-2 | [`thomasklemm/hash-as-json-symbol-names`](https://github.com/thomasklemm/rails/tree/thomasklemm/hash-as-json-symbol-names) [`a97a37b603`](https://github.com/thomasklemm/rails/commit/a97a37b60337524fce22b68ac689e7db1bb1e09b) | every `as_json`/`render json:` of a Hash with Symbol keys | −1 per Symbol key | 8 / 5 (discourse, fizzy, loomio, mastodon, sure); median −47.5 |
| R7-3 | [`thomasklemm/through-stale-state-without-array`](https://github.com/thomasklemm/rails/tree/thomasklemm/through-stale-state-without-array) [`8b4b8457f1`](https://github.com/thomasklemm/rails/commit/8b4b8457f122f3882e57ba91eae574d40fb89ac0) | every read of a loaded `has_one`/`has_many :through` a `belongs_to` | −2 | 16 / 5 (casa, discourse, docuseal, lago, redprints-cfp); median −12 per workload |
| R7-4 | [`thomasklemm/currency-format-frozen-defaults`](https://github.com/thomasklemm/rails/tree/thomasklemm/currency-format-frozen-defaults) [`10b375c5e3`](https://github.com/thomasklemm/rails/commit/10b375c5e3) | every `number_to_currency` | −2 | 9 / 1 (sure); median −88, up to −384 |

Recommended order to open: R7-1, R7-2, R7-3, R7-4. R7-4 reaches only one census app (Sure), which ranks it last,
although `number_to_currency` is an ordinary helper.

## Pins and method

* **Rails:** canonical `rails/rails` main `1597d576bd` (merge of our #59576), fetched 2026-11-03 14:20 UTC. The
  copies were set up at `231bc7ed65` (`script/census setup`), and every label ran with `--rails` at `1597d576bd` or at
  a candidate on it.
* **Ruby 4.0.7**, interpreter and `--yjit`, for the census and the suites. **Ruby master `9aa0898240`** (4.1.0dev,
  `--enable-zjit`, the F1/F2 pin), interpreter and `--zjit`, for the micro and the differential harnesses. Master
  breaks no candidate's setup.
* **Corpus:** census 7's configurations without `fizzy-mysql`, because this orb has no MySQL server. That leaves 22
  configurations, 20 apps and 237 workloads. Pins: blog `real-blog-r4`, campfire `af4dd9f`, writebook `7478e2c`, fizzy
  `77eada1`, codetriage `d1868f8`, pingcrm `22464f8`, redprints-cfp `6080fc2`, react-starter-kit `f808193`, lobsters
  `366e211`, docuseal `6c416dd`, mastodon `5ccbf0e`, lago `b0007bf`, discourse `0f524718`, loomio `407d4a8`, sure
  `8d0d84d`, casa `b584d2e`, chatwoot `ae66c97`, flow `6a8b5fd`, hackatime `74deec4`, thinkroom `f7865d0`.
  mastodon-nops and lago-nops run on the same copies.
* **Runs:** `run --label r7 --aa --modes interp,yjit --jobs 6` (labels `r7` and `r72`), then one label per candidate
  (`tagvalues`, `asjson`, `stale`, `currency`). Each candidate is compared with `r72`, and `r7` is the A/A.
* **Census measure.** A candidate removes one line's allocations, so the census delta is read at that line's file.
  For each workload, [`sitedelta.py`](../../bench/upstream/r7/sitedelta.py) sums the objects per operation that the
  traced window attributes to the file, and it reports the traced total and the GC-window median beside it. The A/A
  moves none of the four files in any workload, except `core_ext/object/json.rb` in 3 Thinkroom interpreter
  workloads. Over all 237 workloads the totals fall by 0.04–0.14%, which is inside the A/A on that measure (−0.17% /
  −0.06%). No corpus-wide percentage is claimed.
* **Micro:** [`micro_r7.rb`](../../bench/upstream/r7/micro_r7.rb), `GC.stat(:total_allocated_objects)` over 2,000
  warm calls, main twice (A/A) and each candidate, on 4.0.7 interpreter/YJIT and master interpreter/ZJIT.
* **Exactness:** one differential harness per candidate ([`diff_c1.rb`–`diff_c4.rb`](../../bench/upstream/r7)). Each
  prints results, call logs and errors on main and on the candidate, under all four Ruby/mode pairs. All four
  harnesses print identical output on main and the candidate in every pair.
* **Sources mined:** census 7's `rank-c72-interpreter.tsv` (the 3–6-app and 2-app tiers by mean objects per
  operation, and the one-app lines of the four big apps), re-ranked on `r7` (same order). Open PRs: all 1,241 open
  rails/rails PRs and their files (GraphQL, 2026-11-03 14:30 UTC). Every PR that touches a candidate's file was read
  and checked with `git merge-tree` against the candidate.
* **Suites** (Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`): Active Support with `PARALLEL_WORKERS=1` and
  memcached, because with two workers `MemCacheStoreTest` and `BacktraceCleanerCleanLocationsTest` fail on
  unchanged main too. Action Pack, Action View and Active Record (`test:sqlite3`) ran with two workers. With
  `PARALLEL_WORKERS=1`, Action Pack reports 282 "missing assertions" errors on main and on R7-1 alike (4,754 runs).
* **Setup notes (this orb):** pgvector 0.8.1 built from source, `postgresql-15-partman`, `libidn11-dev`, `liblept5`,
  and `trust` in `pg_hba.conf` for local TCP. Docuseal's pdfium is the bblanchon `chromium/8125` build with SONAME
  `libpdfium_real.so`, behind a 9-symbol stub `libpdfium.so`, as in census 7.

## Per call

Objects per call, main / A/A / candidate:

| Case | 4.0.7 interpreter | 4.0.7 YJIT | master 9aa0898240 interpreter | master ZJIT |
| --- | ---: | ---: | ---: | ---: |
| R7-1 `class_names("btn", active: true)` | 13 / 13 / 12 | 13 / 13 / 12 | 12 / 12 / 11 | 12 / 12 / 11 |
| R7-1 `class_names(nested Array)` | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 |
| R7-1 `tag.div(class: ["btn", "btn-primary"])` | 11 / 11 / 9 | 11 / 11 / 9 | 11 / 11 / 9 | 11 / 11 / 9 |
| R7-1 `tag.div(class: { active: true })` | 11 / 11 / 10 | 11 / 11 / 10 | 10 / 10 / 9 | 10 / 10 / 9 |
| R7-1 `tag.div(aria: { describedby: [..] })` | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 | 14 / 14 / 12 |
| R7-2 `{4 Symbol keys}.as_json` | 5 / 5 / 1 | 5 / 5 / 1 | 1 / 1 / 1 | 1 / 1 / 1 |
| R7-2 `{4 Symbol keys}.as_json(except: :created_at)` | 8 / 8 / 5 | 8 / 8 / 5 | 5 / 5 / 5 | 5 / 5 / 5 |
| R7-2 `{ post: {4 keys} }.as_json({})` (`render json:`) | 10 / 10 / 5 | 10 / 10 / 5 | 5 / 5 / 5 | 5 / 5 / 5 |
| R7-3 `comment.post_author` (loaded, through `belongs_to`) | 3 / 3 / 1 | 3 / 3 / 1 | 3 / 3 / 1 | 3 / 3 / 1 |
| R7-4 `number_to_currency(1234.5)` | 53 / 53 / 51 | 53 / 53 / 51 | 53 / 53 / 51 | 53 / 53 / 51 |
| R7-4 `number_to_currency(-5, unit: "€")` | 58 / 58 / 56 | 58 / 58 / 56 | 58 / 58 / 56 | 58 / 58 / 56 |

Master returns a frozen String from `Symbol#to_s` (Feature #22137). `Hash#[]=` then stores it without a copy, so
R7-2 changes nothing there; the saving is on Ruby ≤ 4.0. No candidate loses under ZJIT.

## R7-1: collect nested tag values without intermediate Arrays

`build_tag_values(*args)` takes its arguments as a rest Array. It also concatenated a fresh Array for each nested
Array (`tag_values.concat build_tag_values(*tag_value)`). `token_list` and the `class`/`aria` attribute paths called it
and then read the result once. The candidate appends every value to one Array through
`TagHelper.append_tag_value`. Nested Arrays are still splatted, so their elements are read from a copy, in the
same order. `build_tag_values` keeps its signature and result.

**Exactness checklist.**
1–2: Singleton `each`/`to_a` on an Array argument, an Array subclass with its own `each`/`to_a`/`map`/`size`, and
a Hash subclass with its own `each`/`each_pair` give identical results and call logs. The splat reads an Array the
same way in both versions.
3: Objects with `to_ary`/`to_a` as values: neither version calls them.
4: Every `present?` and `to_s` call on user values happens in the same order. The candidate adds no call and skips
none.
5: `to_s` results are appended as before.
6: An element whose `to_s` appends to its containing Array is read from the splat's copy in both versions.
7: Frozen Arrays and Hashes give the same output, and an exception raised from `present?` or `to_s` keeps its class
and message.
8: `append_tag_value` is a module method of `TagHelper`, not a new private view method, so no helper name is
added to views.
**Boundary:** an app that overrides the private (nodoc) `build_tag_values` in a view no longer changes what
`token_list` and the `class` attribute collect. This is an override of a nodoc private method, which DECISIONS
accepts.

**Test:** `test_token_list_and_class_attribute_collect_nested_values_into_one_array`. A nested Array must cost only
the one copy its splat makes. On main it costs one more than that, and the test fails.
**Suites:** AV 2,914 runs, AP 4,472, AR 10,266, AS 6,887, each with 0 failures and 0 errors. RuboCop is clean.
**Overlap:** no open PR changes `build_tag_values`. #57999 (attribute strings) and #59499 merge cleanly. #47163,
#47159, #56596, #45236, #49377 and #51646 already conflict with main.

> **Collect nested tag values without intermediate Arrays**
>
> Every `class_names`/`token_list` call, and every `class:` or `aria:` attribute given an Array or a Hash, runs
> `build_tag_values`. It collects the values into one Array and builds another Array for each nested Array, then
> concatenates them. The caller reads the result once.
>
> This appends every value to a single Array instead. Nested Arrays are still splatted, as before, so the same
> values are read in the same order, with the same `present?` and `to_s` calls, and a value that mutates its
> Array while it is read sees the same copy. `build_tag_values` is unchanged for other callers.
>
> | Per call (objects) | Before | After |
> | --- | ---: | ---: |
> | `class_names("btn", active: true)` | 13 | 12 |
> | `tag.div(class: ["btn", "btn-primary"])` | 11 | 9 |
> | `tag.div(aria: { describedby: [...] })` | 14 | 12 |
>
> Across 20 open-source apps on Rails main, the pages that build class lists allocate fewer objects: up to 679
> fewer per request on Sure's account pages, and about 110 fewer on Lobsters' story lists. Ruby master with ZJIT
> saves the same objects.
>
> One boundary: a view that overrides the private `build_tag_values` no longer affects `token_list` and the class
> attribute.

## R7-2: use `Symbol#name` for `Hash#as_json` keys

`Hash#as_json` stringified every key with `k.to_s`. On Ruby ≤ 4.0, `Symbol#to_s` returns a new String, and
`Hash#[]=` then stores an interned frozen copy of it. That copy is the String that `Symbol#name` already returns.
The candidate uses `Symbol === k ? k.name : k.to_s`.

**Exactness checklist.**
1: Symbols cannot have singleton methods. A refinement of `Symbol#to_s` is lexical and cannot reach `json.rb`.
2: There are no Symbol subclasses. String subclass keys and their own `to_s` still take `to_s`, and the harness
logs the call.
3–4: For Symbol keys the candidate skips `Symbol#to_s`. Only a global redefinition of `Symbol#to_s` sees the
difference, which DECISIONS accepts as core redefinition. Other keys (Integer, nil, Float, Array, custom objects)
take `to_s` as before.
5–6: Values are converted as before. A value whose `as_json` mutates the source Hash behaves the same.
7: The result keys are equal and identical (`equal?`), frozen, and have the same encoding, for ASCII, non-ASCII,
dynamic and spaced Symbols. This holds for frozen, `compare_by_identity` and subclass sources, with `only:`,
`except:` and frozen options.
8: Nothing new is loaded.
On Ruby master the change is a no-op, as shown above.

**Test:** `test_hash_as_json_does_not_copy_symbol_keys`. Symbol keys must cost the same as String keys, with and
without options, and the key must be `:name.name`. On main the test fails (4 against 1).
**Suites:** AS 6,889 runs, AP 4,472, AV 2,913, AR 10,266, each with 0 failures. RuboCop is clean.
**Overlap:** no open PR touches `core_ext/object/json.rb`. The serialization dive's rejected `transform_values`
variant is a different change; this one keeps `result = {}` and the loop.

> **Use `Symbol#name` for `Hash#as_json` keys**
>
> Every `render json:` and `as_json` of a Hash with Symbol keys stringifies each key with `to_s`. On Ruby 4.0 and
> earlier this creates a String that `Hash#[]=` then replaces with its interned frozen copy. That copy is the
> String `Symbol#name` returns.
>
> This uses `Symbol#name` for Symbol keys. The resulting Hash has the same keys, and they are the same objects as
> before: frozen, interned, and in the same encoding. Strings, String subclasses, Integers, `nil` and other keys
> still go through `to_s`, so a key object's own `to_s` is called as before. Values, `only:`/`except:` and the
> options passed to each value are unchanged.
>
> | Per call (objects, Ruby 4.0) | Before | After |
> | --- | ---: | ---: |
> | `{ id:, name:, email:, created_at: }.as_json` | 5 | 1 |
> | `{ post: { 4 keys } }.as_json({})` | 10 | 5 |
>
> On Ruby 4.1, `Symbol#to_s` already returns a frozen String, so nothing changes there. Across 20 open-source apps
> on Rails main, 8 workloads in 5 apps allocate fewer objects, for example 381 fewer on Sure's dashboard and 79
> fewer in a Mastodon `DistributionWorker` job. Only a global redefinition of `Symbol#to_s` would notice the
> change.

## R7-3: read the through foreign key without wrapping it in an Array

`ThroughAssociation#stale_state` runs on every read of a loaded `has_one`/`has_many :through` association whose
through reflection is a `belongs_to`. It computed
`Array(through_reflection.foreign_key).filter_map { |c| owner.read_attr(c) }.presence`: one Array for the key and
one for the values. `foreign_key` is a frozen String for a single column (`Key::Single`) and an Array for a
composite key. For a String, the candidate reads the one column and returns `[value] if value`. Composite keys keep
the old expression.

**Exactness checklist.**
1–3: The key is the reflection's own frozen String, not a user object, so `Array()` made no conversion calls on it.
4: `read_attr` is called once with the same name. The candidate skips `Array()`, `filter_map` and `presence`, all
core or Active Support methods on Arrays that Rails built itself. Only a global redefinition would see the
difference.
5–6: The value is wrapped as `filter_map` would wrap it, and `nil` and `false` give `nil` as `presence` did.
7: The result is a new unfrozen Array, as before.
8: Nothing new is loaded.
The harness covers loaded, changed, nil, `false`, `true` and String-assigned keys, new and found records, a Symbol
`foreign_key:` option and a composite key (with a partial `nil`). It logs `read_attr` through a prepended module, and
both versions give the same states, staleness, targets and call logs.

**Test:** `test_has_one_through_belongs_to_stale_state_wraps_only_the_foreign_key_value`. The state is the value
wrapped in an Array, `nil` when the key is `nil`, and it costs one allocation. On main it costs 3 and the test
fails.
**Suites:** AR 10,267 runs, AS 6,887, AP 4,472, AV 2,913, each with 0 failures. RuboCop is clean.
**Overlap:** #57055 (inverse before attribute assignment) changes `association.rb` around `stale_state` and already
conflicts with main. #52060 conflicts with main. #55039, #55041, #58065 and #58877 merge cleanly.

> **Read the through foreign key without wrapping it in an Array**
>
> Every read of a loaded `has_one :through` or `has_many :through` a `belongs_to` checks `stale_state`, the owner's
> foreign key values. For a single-column key this wraps the column name in an Array, maps it into another Array,
> and calls `presence`.
>
> For a single column this now reads the value and wraps only the value. Composite keys keep the existing code. The
> state is the same, `nil` when the key is `nil` or `false`, and `read_attr` is called once as before, so a
> prepended `read_attr` and attribute aliases see the same calls. Whether a changed foreign key reloads the target
> is unchanged.
>
> | Per call (objects) | Before | After |
> | --- | ---: | ---: |
> | `comment.post_author` (loaded, through `belongs_to :post`) | 3 | 1 |
>
> Across 20 open-source apps on Rails main, 16 workloads in 5 apps allocate fewer objects. Discourse's topic lists
> allocate about 250 fewer per request, and CASA's case contacts page about 240 fewer. Ruby master with ZJIT saves
> the same objects.

## R7-4: pass the frozen empty format to I18n in `number_to_currency`

`NumberToCurrencyConverter#options` calls `i18n_format_options`, which passed a new `{}` as the `default:` of each
of its two `I18n.translate` calls. The first result is copied with `dup`, and the second is only read by `merge!`.
Since 2ecce1b3b9, `NumberConverter#options` makes the same two lookups with the frozen `EMPTY_FORMAT` default. The
candidate passes `EMPTY_FORMAT` here too.

**Exactness checklist.**
1–3: The default is Rails' own Hash, not a user object.
4: The same `translate` calls happen with an equal default. The only difference is that the default is frozen.
5: A missing translation returns the default itself. The first result is copied with `dup` as before, so
`i18n[:negative_format] ||=` writes to a fresh Hash. The second result is only read.
6: Translations are only read.
7: A backend that mutated the `default:` Hash it was given would now raise `FrozenError`. Main already passes the
same frozen object in `NumberConverter#options`, so such a backend breaks every number helper on main already.
8: Nothing new is loaded.
The harness converts 8 numbers (Integer, negative, Float, invalid String, `nil`, negative BigDecimal, rounding to
zero, Infinity) under 9 option sets (full locale, format-only, `nil` negative format, base-only, a String
`number.format` that raises, explicit `format:`, unknown locale, `negative_format:`). It runs them on the Simple
backend, a recording subclass and a Fallbacks backend: 216 identical lines.

**Test:** `test_number_to_currency_reads_missing_formats_without_a_default_per_call` stubs `I18n.translate` and
checks that every format lookup gets the same frozen empty default. On main there are 5 distinct defaults over two
calls, and the test fails.
**Suites:** AS 6,888 runs, AP 4,472, AV 2,913, AR 10,266, each with 0 failures. RuboCop is clean.
**Overlap:** #59149 (eager-built format keys) and #47874 (`trim_empty_fractional`) do not touch
`i18n_format_options`.

> **Pass the frozen empty format to I18n in `number_to_currency`**
>
> Every `number_to_currency` call, from the view helper or from Active Support, looks up `number.format` and `number.currency.format` with a new empty Hash as the
> default. The first result is copied and the second is only read, and `NumberConverter#options` already passes its
> frozen `EMPTY_FORMAT` for the same lookups.
>
> This passes `EMPTY_FORMAT` here as well. Translations, defaults and the order of lookups are unchanged. A missing
> translation still returns an empty Hash: the first one is copied before `negative_format` is filled in, and the
> second is only merged from, so nothing writes to the frozen default. Locale formats, a format-only locale, an
> explicit `format:` and the Fallbacks backend give the same output.
>
> | Per call (objects) | Before | After |
> | --- | ---: | ---: |
> | `number_to_currency(1234.5)` | 53 | 51 |
> | `number_to_currency(-5, unit: "€")` | 58 | 56 |
>
> Of 20 open-source apps on Rails main, Sure formats currency on the measured pages. Its 9 affected workloads
> allocate fewer objects, up to 384 fewer per request on the dashboard. Ruby master with ZJIT saves the same objects.

## Ranking and dispositions

Re-ranked on `r7`. Tiers follow census 7; within a tier, lines are ordered by mean objects per operation. "Not
examined" means only the line was read.

**3–6 apps**

| Site (rank) | Apps | Objects/op | Disposition |
| --- | ---: | ---: | --- |
| AS `notifications/fanout.rb:213` (1125) | 5 | 13.1 | Listener call per timed event. Not examined further. |
| AV `tag_helper.rb:1868/1877/1813/1814` (1371–1403) | 3–4 | 1.3–10.8 | **R7-1** (1868, 1877; 1814's rest Array). 1813 (`tokens`) and 1824 (the joined result) are required. |
| AS `big_decimal/conversions.rb:9` (1126) | 5 | 8.4 | `to_s("F")` result. Required. |
| AS `number_converter.rb:218`, `number_to_rounded_converter.rb:36`, `number_to_delimited_converter.rb:16` | 3 | 6.9–8.1 | The BigDecimal and the formatted Strings. Required. |
| AR `arel/visitors/to_sql.rb:837/838/839`, `bound_sql_literal.rb:20` | 6 | 1.2–6.3 | SQL fragments of bound literals. Required. |
| AS `html_safe_translation.rb:26`, AV `translation_helper.rb:104` | 6 | 5.7–6.1 | One keyword Hash per hop (i18n dive). Required. |
| AV `template/renderable.rb:21`, `rendering_helper.rb:152/153` | 3–4 | 2.5–5.8 | `render_in(locals:)` keywords, the Renderable, the payload. Required. |
| AV `asset_url_helper.rb:235/236` | 3 | 2.9–5.7 | `options.merge(protocol: :request)`: the copy keeps the caller's options intact. Required. |
| AM `indexed_row.rb:105/114` | 5 | 1.7–5.7 | `Remapper` for joins. Rewritten by open #59141 (tenderlove). Excluded. |
| AR `transaction.rb:677` | 6 | 5.1 | Re-raised exception. Required. |
| AV `tags/base.rb:129` `sanitized_value` | 5 | 4.6 | **Next lead.** `gsub` → `gsub` → `downcase` makes two intermediate Strings; the second `gsub!` and `downcase!` would operate on the first result, which Rails owns. Expected −2 per radio/checkbox value. Not built (limit of 4). |
| AS `redis_cache_store.rb:330` | 5 | 4.5 | `**options` forwarding. Required by the keyword API. |
| AS `inflector/methods.rb:87/89` `camelize` | 4–5 | 1.9–4.3 | Rejected in census 3 (literal inflection plans). |
| AR `query_methods.rb:2211` | 5 | 3.9 | `arel.project(*columns)` with ignored columns: the projections. Required; rest Array is a VM lead (census 7). |
| AS `core_ext/object/json.rb:194` | 5 | 4.0 | **R7-2.** |
| AR `associations/through_association.rb:86` | 5 | 3.9 | **R7-3.** |
| AP `route_set.rb:783` | 5 | 3.5 | `direct` URL helpers with `only_path`: `"/" + url.partition(re).last`. **Lead:** an index-and-slice saves the Array and two Strings; not built. |
| AS `cache.rb:118/1032/1047` | 5–6 | 1.1–3.2 | Expanded and namespaced cache keys. Required. |
| AR `postgresql/oid/array.rb:30`, AM `type/binary.rb:35` | 3–4 | 2.8 | Decoded values. Required. |
| others in the tier below 2.5 objects/op | | | Not examined. |

**2 apps**

| Site | Apps | Objects/op | Disposition |
| --- | --- | ---: | --- |
| AV `tag_helper.rb:1819` | fizzy, sure | 110.3 | The tokens `split` yields. Required output of `class_names`. |
| AV/AS/AR `structured_event_subscriber.rb`, AS `event_reporter.rb:525` | codetriage, fizzy | 1.3–5.5 | Debug-mode structured events, which these apps enable. Required while enabled. |
| AS `json/encoding.rb:315`, `fanout.rb:292`, AV `base.rb:358`, AP `route_set.rb:370/371` | 2 each | 1.3–4.3 | Not examined. |

**One app (Discourse, Mastodon, Chatwoot, Sure)**

| Site | App | Objects/op | Disposition |
| --- | --- | ---: | --- |
| AS `number_converter.rb:191/194` (`i18n_format_options`) | sure | 7.2, 4.8 | **R7-4.** |
| AS `number_to_currency_converter.rb:26` `gsub` chain | sure | 16.4 | The formatted result Strings. Required. |
| AS `number_converter.rb:185` (`default_format_options` dup) | sure | 2.4 | The Hash the options are merged into. Required. |
| AV `text_helper.rb:570` `split_paragraphs` | mastodon | 4.6 | `simple_format`'s paragraphs. Required. |
| AS `deprecation/reporting.rb:23` | chatwoot | 2.9 | Backtrace for a deprecation the app triggers. App-side. |
| AS `output_safety.rb:165`, AR `aggregations.rb:23` | mastodon | 2.3, 1.4 | Not examined. |
| AR `store.rb:334` | chatwoot | 1.0 | The indifferent store Hash. Required. |

**SQL control.** Each label changes the SQL digest of 2–5 of 474 workload runs. The changed runs are Discourse's
`GET topic.json` (it also changes in the A/A), Mastodon's `GET profile` and timelines (a different label and mode
each time), and Thinkroom's `POST comment`, which writes data. None of these is a workload that a candidate moved.
They are database drift, as in census 7.

## Limits

* Allocation counts only. Each configuration and mode ran in one process, and results are judged against the A/A.
* `fizzy-mysql` did not run (no MySQL server in this orb), so MySQL is not covered in this round.
* Suites ran locally only (Ruby 4.0.7; Active Record on SQLite). No hosted CI ran on the fork branches.
* The exactness checklist items were checked with the harnesses named above. None of the candidates has had a
  Sol or Astra review yet.
* Receipts: [data/rails-r7-queue/receipts.tar.gz](data/rails-r7-queue/receipts.tar.gz) holds both rankings on `r7`,
  label metadata, the `compare` output, per-candidate site deltas with their A/A, the micro, every harness output
  and the suite summaries. Scripts: [bench/upstream/r7](../../bench/upstream/r7).
