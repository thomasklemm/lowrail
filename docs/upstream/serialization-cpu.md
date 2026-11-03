# JSON serialization CPU time (bet S1)

Where `as_json`, `serializable_hash`, `to_json`, `render json:`, jbuilder and the json gem spend time in real apps,
and whether exact Rails or json gem changes make them measurably cheaper. Method as in
[activerecord-cpu](activerecord-cpu.md): stackprof for the ranking, Callgrind instruction counts with an A/A
control as the evidence, census allocations for side effects, **no wall-time claim**. Rails main
[`b084108cf3`](https://github.com/rails/rails/commit/b084108cf37bacb47c269684a7576f7ac2296983), Ruby 4.0.7,
json 3.1.0 (micro), interpreter and YJIT.

**Result.** On the JSON endpoints of eleven census apps, the serialization layer itself is small: escape, the json
gem's generator, Active Support's encoder and `as_json`, Active Model's `serializable_hash`, `index_with` and
Time/BigDecimal encoding together take about 1.5% of samples (mean, interpreter). Most of a JSON request is
the queries and attribute reads that serializers trigger, plus the serializer gems (active_model_serializers,
jbuilder, alba, inertia_rails). Within the serialization subtree, the largest Rails-owned frame is the escape pass
behind `to_json`, about 4% of it. One exact candidate came out of it:

| # | Branch | Commit | What | Per call, interpreter / YJIT | ruby-bench | Census (56 workloads) |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | [`thomasklemm/json-escape-without-regexp`](https://github.com/thomasklemm/rails/tree/thomasklemm/json-escape-without-regexp) | [`e13f3f6d6d`](https://github.com/thomasklemm/rails/commit/e13f3f6d6d4b6c81db663c7c903e6b779e1a8824) | Before Ruby 4.1, escape JSON by searching for each character with `include?` instead of one `gsub!` over a Regexp union | plain text −2.7% to −6.6% / −4.2% to −8.9%; text with `<>&` −9% to −14% / −10% to −17% | within A/A, except railsbench YJIT −0.36% (A/A −0.10%) | 30 / 34 workloads −1 or more (A/A 16 / 11), median −1.0 / −1.5 |

Not opened. Escaping is a critical change under [DECISIONS](../DECISIONS.md#extra-adversarial-astra-round-for-critical-changes-2026-11-03),
so it needs Sol and the adversarial Astra round before it can enter the queue. Draft in the short form at the end.

## Where the time goes

### Census apps' JSON workloads

Each census app's `:json` workloads ([census_prof.rb](../../bench/upstream/serialization_cpu/census_prof.rb), the
A1 harness filtered to JSON): 50 warmups per workload, then round-robin 40 times (400 for the four apps with few
samples) under stackprof in wall mode at 200 µs with raw stacks. Apps: Blog, Campfire, Fizzy, Redprints CFP
(SQLite); CodeTriage, PingCRM, Lobsters (SQLite), Mastodon, Discourse, Lago, Chatwoot (PostgreSQL 15). The census
copies of Lobsters, Mastodon, Discourse, Lago and Chatwoot were set up for this bet in `.corpus/census-s-*` with
`script/census setup` on the same Rails commit (Discourse needed pgvector 0.8.1 and Lago `postgresql-15-partman`,
as in census 6). Self charges C functions to the nearest Ruby frame, except the generator, `gsub!`/`tr!`,
`Time#xmlschema` and `BigDecimal#to_s`, which keep their own ([rank.rb](../../bench/upstream/serialization_cpu/rank.rb)).

Self time by area, % of all samples of the JSON requests, mean over the eleven apps (per-app columns in
[rank-census-interpreter.tsv](data/serialization-cpu/rank-census-interpreter.tsv) and
[rank-census-yjit.tsv](data/serialization-cpu/rank-census-yjit.tsv)):

| Area | Interpreter | YJIT | Range (interpreter) |
| --- | ---: | ---: | --- |
| Active Record (queries, associations, other) | 37.3 | 29.9 | 22–51 |
| attribute reads (attribute sets, casting, readers) | 6.3 | 5.3 | 2.8–10.9 |
| database driver | 6.2 | 9.6 | 0.7–11.8 |
| active_model_serializers (Mastodon, Discourse) | 1.7 | 1.8 | 5.3, 13.4 |
| inertia_rails (PingCRM, Redprints) | 0.8 | 0.7 | 3.5, 5.0 |
| jbuilder (Blog, Campfire, Chatwoot, Fizzy, PingCRM) | 0.6 | 0.5 | 0.5–2.0 |
| **JSON escape (`gsub!`)** | **0.4** | **0.6** | 0.0–0.8 (YJIT up to 1.2) |
| `index_with` (`serializable_hash`) | 0.4 | 0.5 | 0.2–0.9 |
| json gem generator (C) | 0.3 | 0.4 | 0.0–0.7 |
| Time/Date/BigDecimal `as_json` | 0.2 | 0.2 | 0.0–0.6 |
| Active Support encoder (`encode`, Coder proc) | 0.1 | 0.1 | 0.0–0.3 |
| Active Model `serializable_hash`/`as_json` | 0.1 | 0.1 | 0.0–0.5 |
| Active Support `Hash#as_json`/`Array#as_json` | 0.0 | 0.0 | 0.0–0.2 |

Inclusive, the renderer (`render json:`) is on 36% of samples and `to_json`/`ActiveSupport::JSON.encode` on 15%
(Lobsters 31%, Mastodon 64%, Lago 32%, Redprints 20%); jbuilder 20%, inertia_rails 15%. Restricted to samples
under a serialization root (`as_json`, `to_json`, `serializable_hash`, JSON generate, serializer gems;
[within tables](data/serialization-cpu/rank-census-within-interpreter.tsv)), Active Record still leads at 38%
(lazy loading from inside serializers), attribute reads 8.6%, then escape 3.9%, the Active Support encoder 3.7%,
the generator 3.0% (YJIT: generator 5.2%, escape 3.8%). These means include CodeTriage, whose single JSON
workload has only a handful of samples inside a serialization root.

### Micro set

[micro.rb](../../bench/upstream/serialization_cpu/micro.rb): 20 posts (11 columns: strings, text, boolean,
integer, decimal, a datetime, timestamps), 3 comments each, `load_defaults 8.1` settings unless `LEGACY=1`
(the framework defaults: `escape_json_responses` and `escape_js_separators_in_json` on). `PLAIN=1` uses text
without `<>&`. Cases: `record.as_json` with and without `only`/`include`, `serializable_hash`, `relation.as_json`,
`to_json`, `render json:` (one record, 20 records) through `ActionController::API`, and a jbuilder index with a
partial and with an inline block. Self time of three of them
([rank-micro.tsv](data/serialization-cpu/rank-micro.tsv)):

| Frame (self) | `as_json(include:)` | jbuilder index | `render json:` 20 |
| --- | ---: | ---: | ---: |
| `LazyAttributeSet#keys` (open #58002) | 14.3 | 0.0 | 11.3 |
| `Hash#as_json` | 12.1 | 0.0 | 9.9 |
| `Array#index_with` | 8.1 | 0.0 | 7.7 |
| `String#gsub!` (escape) | 0.0 | 15.3 | 0.0 (8.1 defaults: no escape) |
| `read_attribute_for_serialization` (`send` with a String) | 5.3 | 0.0 | 5.4 |
| `Time#xmlschema` + `TimeWithZone#as_json` | 5.1 | 1.8 | 4.1 |
| json gem `State#generate` | 0.0 | 2.7 | 3.8 |
| jbuilder `_set_value`, `Blank#==`, `_extract_method_values` | – | 11.5 | – |

Instructions per call (interpreter, 100 calls after warmup, GC off; A/A within 0.13% on every case except the inline jbuilder template, −0.47%):
`as_json` 117,845; `as_json(only:)` 74,039; `as_json(include: :comments)` 315,825; `to_json` 226,281;
20 records `as_json` 2.30 M, `to_json` 4.07 M; `render json:` 20 records 2.85 M; jbuilder 5.14 M.
`time.as_json` is 5,627, of which `Time#xmlschema` is 1,494.

**Opened as [rails/rails#59584](https://github.com/rails/rails/pull/59584) (2026-11-03, head `8f77e334e9`): the minimal variant.** After fatkodima's objection to #59577 and the readability
gate in [DECISIONS](../DECISIONS.md#readability-gate-l0l3), S1 goes out as the coder-only variant:
[`thomasklemm/json-escape-coder-only`](https://github.com/thomasklemm/rails/tree/thomasklemm/json-escape-coder-only)
at [`8f77e334e9`](https://github.com/thomasklemm/rails/commit/8f77e334e98b15350521cdf8872d5699dc08c54b), one commit
on `b084108cf3`. Only `JSONGemCoderEncoder#escape!` changes (two frozen Hash constants, two `each_key` loops with
plain `include?`/`gsub!`, settings read after `force_encoding` and before any replacement, as on main), with no code comment and no bound-method constants. Its String
comes straight from `JSON::Coder#dump`, so no custom `stringify` can reach it, and every finding of review rounds 2
to 6, including the pre-4.0 Ractor IsolationError, came through that hook; `JSONGemEncoder` keeps main's code. All
eleven census apps lock json 2.20 to 3.1, so all use the coder encoder. Checks: Active Support with
`RAILS_STRICT_WARNINGS=1` 5,482 runs, 0 failures (Redis store tests excluded, no Redis gem in this bundle);
RuboCop clean; `escape_fuzz.rb` 0 of 16,000 and `escape_fuzz_custom.rb` 0 of 80,001 differ from main; encoding
from a non-main Ractor works. Ruby 4.1 (master `9aa0898240`) takes the `tr!` branch and never calls this method,
so no ZJIT number applies. Readability **L1**: the per-character loop is slightly unusual next to a single
`gsub!`, but clear at once, and the gain is outside the A/A per call and on railsbench under YJIT.

ruby-bench on the minimal variant (Callgrind, one measured iteration after warmup, A/A = `b084108cf3` in a
second worktree): interpreter railsbench −0.037% (A/A +0.014%), lobsters +0.046% (−0.000%), shipit +0.039%
(+0.004%); YJIT railsbench **−0.764%** (A/A +0.038%) and, rerun, **−0.282%** (A/A −0.078%), lobsters +0.021%
(−0.023%), shipit −0.040% (+0.019%). The PR body is at the end.

Review (2026-11-03): Sol approved `f3a074279b` on both rubrics. Astra found the settings read before
`force_encoding`, which changed error precedence for a frozen String and the order against a fiber switching
settings; fixed in `8f77e334e9` (same order as main; Active Support 5,482 runs, 0 failures; `escape_fuzz.rb` 0 of
16,000 differ). A prepended `String#gsub!` seeing two String-pattern calls instead of one Regexp call is accepted.

## Candidate

### S1: escape JSON by searching for each character instead of a Regexp

Before Ruby 4.1 (no `String#tr!` with a Hash, [#58746](https://github.com/rails/rails/pull/58746)), both encoders
escape with

```ruby
json.force_encoding(::Encoding::BINARY)
json.gsub!(FULL_ESCAPE_REGEX, ESCAPED_CHARS) # or HTML_ENTITIES_REGEX / JS_SEPARATORS_REGEX
json.force_encoding(::Encoding::UTF_8)
```

The Regexp union runs Onigmo over the whole document even when nothing needs escaping, and `gsub!` sets the
match data. S1 keeps the binary String and the five replacements and calls
`json.gsub!(char, chars) if json.include?(char)` for each character, with a String pattern
(`rb_memsearch`, no Regexp) and the same Hash as the replacement. It does so only when the encoder's output is a
plain String (`instance_of?(String)`); subclasses keep the single `gsub!` over the Regexp union. Both settings are
read before anything is replaced, as on main. The `tr!` branch for Ruby 4.1 is unchanged.

**Exactness.** The five characters' replacements contain none of the five, so replacing them one after another
gives the same bytes as one pass. The search runs on the binary String as before, so invalid UTF-8 from a
`JSON::Fragment` still passes through untouched. A fuzz over 16,000 encodings (random strings of
`< > & U+2028 U+2029 é \ "` plus invalid bytes as fragments, all four combinations of the two settings, with
and without the `escape_html_entities:` option) gives identical bytes and encodings on main and S1, including
6,916 outputs with invalid encoding ([escape_fuzz.rb](../../bench/upstream/serialization_cpu/escape_fuzz.rb)).
The new test `test_escape_options_apply_independently` pins the combination no existing test covered (HTML
escaping off, separators on, repeated characters); a mutant that skips separators when the option is passed fails
it, and it passes on main.

**Review round (2026-11-03).** Sol approved `72d0a204cc` on both rubrics. The adversarial Astra round (101,760
cases on Ruby 4.0.7) found three differences, all fixed in `60d70808d9`:

1. P2: a custom `JSONGemEncoder` whose `stringify` returns a String subclass with `include?` returning false left
   all five characters literal (main escapes them); an `include?` that raises was a new exception path.
2. P3: a custom encoder returning `super.html_safe` got `html_safe? == true`, because the skipped `gsub!` no longer
   marked the SafeBuffer unsafe (main: false).
3. P3: `escape_js_separators_in_json` was read after the HTML substitution, so a change mid-encode (fiber plus
   TracePoint) could leave U+2028 literal; main reads both settings first.

The fix takes the per-character path only for a plain String and keeps main's single `gsub!` otherwise (1, 2), and
reads both settings before any substitution (3). Two new tests, `test_escape_string_subclass_from_custom_encoder`
and `test_escape_marks_safe_buffer_from_custom_encoder_unsafe`, fail on `72d0a204cc` and pass on main and on the
fix. The fuzz was extended with the default encoder, `JSONGemEncoder` and custom encoders returning a String
subclass or a SafeBuffer, comparing bytes, encoding, class and `html_safe?`
([escape_fuzz_custom.rb](../../bench/upstream/serialization_cpu/escape_fuzz_custom.rb)): main vs the fix
0 of 16,001 differ; main vs `72d0a204cc` 3,758 differ. Its trace of setting reads before the first
`include?`/`gsub!` shows both settings on main and on the fix, only the HTML setting on `72d0a204cc`. The guard
costs 0.1 to 0.3 points per call; the numbers below are the fix's.

**Review round 3 (2026-11-03).** Sol and Astra (176k probes on Ruby 4.0.7) found one remaining difference in
`60d70808d9`: `instance_of?(String)` is also true for a plain String with singleton methods, so a custom encoder
returning `super.tap { |s| def s.include?(*) = false }` left all five characters literal (P2). Fixed in
[`f883f67d87`](https://github.com/thomasklemm/rails/commit/f883f67d87d44a85591a77f2063748008c85d2e8) with option
(a): the guard is `String#to_s` called through a bound core method (it returns the receiver only for an instance of
String itself), and the search and replacement call `String#include?` and `String#gsub!` through bound core
methods, so no method defined on the String itself is consulted. Subclasses keep main's single dispatched `gsub!`.
Variants measured and rejected: `Kernel#instance_of?` via `bind_call` (+2 objects per call); also routing a
singleton `gsub!` override to main's path by checking `method(:gsub!).owner` (V2, +3 objects per call, `to_json`
+1.1% vs main); a `String#count` prefilter (V3) and a `Regexp#match?` prefilter (V5), both of which give back the
plain-text saving. The one remaining difference from main is a singleton `gsub!` override on a plain String: main
calls it, the fix does not. That difference can only escape more, never less: a no-op `gsub!` override makes main
emit `<>&` and U+2028/9 literally (4,499 of 6,000 cases), while the fix's output equals `JSONGemEncoder`'s in
6,000 of 6,000 ([escape_noop_gsub.rb](../../bench/upstream/serialization_cpu/escape_noop_gsub.rb)). A pass-through override matches main exactly. New test
`test_escape_string_with_singleton_methods_from_custom_encoder` fails on `60d70808d9` and passes on main and the fix.
Fuzz ([escape_fuzz_custom.rb](../../bench/upstream/serialization_cpu/escape_fuzz_custom.rb), extended with
singleton `include?`, `include?` that raises, `instance_of?`, `to_s`/`equal?`/`class`, `equal?` plus `include?`,
a SafeBuffer lying about `to_s`/`equal?`/`instance_of?`, a subclass doing the same, and pass-through and no-op
`gsub!`): main vs the fix differs in 3,248 of 52,001 cases, all in the no-op `gsub!` encoder; main vs `60d70808d9`
differs in 10,472 (singleton `include?`, raising `include?`, lying SafeBuffer, `equal?` plus `include?`). Allocations
per call unchanged from `60d70808d9` (25 / 481 / 527 for `to_json` / 20 posts / jbuilder, main 26 / 482 / 528).
Active Support with `RAILS_STRICT_WARNINGS=1`: 5,488 runs, 0 failures; RuboCop clean. The bound calls cost about
1.5 points on a single small record (`post.to_json` plain −1.1% interpreter, −2.6% YJIT, against −2.5% / −4.3% for
`60d70808d9`); the multi-record and jbuilder cases are within 0.7 points of `60d70808d9`. All runs in
[instructions.txt](data/serialization-cpu/instructions.txt).

**Review round 4 (2026-11-03).** Sol and Astra found one remaining issue in `f883f67d87`: the guard
`STRING_TO_S.bind_call(json).equal?(json)` dispatched `equal?`, so a singleton `equal?` that raises made head raise
where main returns, even with both settings off (a new exception path; it could not skip escaping). Fixed in
[`4e73141327`](https://github.com/thomasklemm/rails/commit/4e73141327d9c6a5a68af085659f6256a9f9bc52): the identity
check is `BasicObject#equal?` through a bound core method too, so the escape path dispatches no method on a plain
String. Allocations unchanged (25 / 481 / 527). The singleton-methods test gained a raising-`equal?` encoder, which
fails on `f883f67d87` (`RuntimeError: equal? called`) and passes on main and the fix. Fuzz with a
`singleton_equal_raises` encoder: main vs the fix differs in 3,245 of 56,001 cases, all in the no-op `gsub!` encoder
(accepted in round 3); main vs `f883f67d87` also differs in all 4,000 `singleton_equal_raises` cases. Active
Support with `RAILS_STRICT_WARNINGS=1`: 5,488 runs, 0 failures; RuboCop clean. The bound `equal?` costs about 0.5
points on a single small record (plain `post.to_json` −0.5% interpreter, −1.6% YJIT); the other cases are within
0.3 points of `f883f67d87`. All runs in [instructions.txt](data/serialization-cpu/instructions.txt).

**Review round 5 (2026-11-03).** Sol (correctness) and Astra found two cases with one cause: the fast path assumed
the dispatched `json.force_encoding(::Encoding::BINARY)` had made the String binary. With a singleton
`force_encoding` that returns `self`, invalid UTF-8 made main's Regexp `gsub!` raise `ArgumentError` while head
returned invalid JSON; on a frozen String, main's `gsub!` raised `FrozenError` while head returned the String. Fixed
in [`7f88aeab6d`](https://github.com/thomasklemm/rails/commit/7f88aeab6ddca2eb3c930fb2a5a088931a918317): the fast
path also requires `String#+@` (bound) to return the receiver, which is true only for an unfrozen String, and the
encoding read through a bound `String#encoding` to be `Encoding::BINARY`; anything else takes main's `gsub!`. A bound
`Kernel#frozen?` was measured and rejected: `bind_call` on a Kernel method allocates 2 objects per call. Fully bound
`EQUAL.bind_call(::Encoding::BINARY, …)` cost 0.4 points more than `::Encoding::BINARY.equal?(…)`, so the latter is
used; it dispatches on the frozen, shareable `Encoding::BINARY` (a singleton method on it raises `FrozenError`).
New test `test_escape_string_that_force_encoding_does_not_convert_from_custom_encoder` (both repros) fails on
`4e73141327` and passes on main and the fix. Fuzz encoders added: no-op `force_encoding`, the same frozen, a binary
frozen String lying about `frozen?`, and a chilled literal; main vs the fix differs in 3,217 of 72,001 cases, all in
the accepted no-op `gsub!` encoder (main vs `4e73141327`: 6,083, including 2,866 in the three `force_encoding`
encoders). A chilled String warns identically on main and the fix. Allocations unchanged (25 / 481 / 527). Active
Support with `RAILS_STRICT_WARNINGS=1`: 5,490 runs, 0 failures; RuboCop clean. Cost against `4e73141327`: about
0.9 points on a single small record (plain `post.to_json` +0.5% interpreter, −1.0% YJIT vs main), nothing on
`posts.to_json` (−4.5% / −5.3%).

**Audit of the remaining dispatched calls on the String** (`escape!` and `escape_binary!`, both encoders):

* `json.force_encoding(::Encoding::BINARY)` before escaping: the same call, arguments and position as main. Whatever
  it does, head now checks the result with bound core methods and otherwise takes main's path.
* `json.force_encoding(::Encoding::UTF_8)` after escaping: identical to main, and its return value is `escape!`'s in
  both.
* `json.gsub!(regexp, ESCAPED_CHARS)` on the fallback path: identical to main.
* Fast path: `to_s`, `+@`, `encoding`, `include?`, `gsub!` and `equal?` are all bound core calls; nothing is
  dispatched on the String.
* `::Encoding::BINARY.equal?` dispatches on the Encoding, not the String; only a global redefinition of
  `BasicObject#equal?` (or `Encoding#equal?`) could change it, which Ruby documents should not be done.
* Ruby 4.1's `tr!` path is unchanged from main.

**Review round 6 (2026-11-03).** Sol approved `7f88aeab6d` on both rubrics; the `::Encoding::BINARY.equal?` dispatch
is accepted. Astra found a non-String proxy: a custom encoder returning `SimpleDelegator.new(super)` gets escaped
output on main through the dispatched `gsub!`, while head raised `TypeError: bind argument must be an instance of
String`. Fixed in [`e13f3f6d6d`](https://github.com/thomasklemm/rails/commit/e13f3f6d6d4b6c81db663c7c903e6b779e1a8824):
`::String === json` (a C kind-of check, nothing dispatched on `json`) comes first, and anything else takes main's path.
New test `test_escape_proxy_from_custom_encoder` (SimpleDelegator and a BasicObject proxy with `method_missing`) fails
on `7f88aeab6d` with that TypeError and passes on main and the fix. Fuzz with both proxies: main vs the fix differs in
3,297 of 80,001 cases, all in the accepted no-op `gsub!` encoder; main vs `7f88aeab6d` also differs in all 8,000
proxy cases. Allocations unchanged (25 / 481 / 527). Active Support with `RAILS_STRICT_WARNINGS=1`: 5,492 runs,
0 failures; RuboCop clean. Cost of the check: within noise (`posts.to_json` −4.5% interpreter, −5.8% YJIT vs main;
`7f88aeab6d` −4.5% / −5.2%).

**Ruby master × ZJIT.** Not applicable: on Ruby master
[`9aa0898240`](https://github.com/ruby/ruby/commit/9aa0898240) (`4.1.0dev +ZJIT`) `TR_ESCAPE_SUPPORTED` is true,
both encoders escape with `tr!`, and `escape_binary!` is called 0 times
([escape_path_check.rb](../../bench/upstream/serialization_cpu/escape_path_check.rb)); on 4.0.7 it is called once per
encode. The change runs only on Ruby ≤ 4.0.

**Checks.** All Active Support test files except the Redis cache store (the `redis` gem is outside the bundle
groups installed here) with `RAILS_STRICT_WARNINGS=1`: 5,486 runs, 0 failures; RuboCop clean. The census was not
rerun for the fix: the default encoders return plain Strings, which take the same path as in `72d0a204cc`.

**Per call** (instructions, `irmicro.rb`, base / A/A / S1 `72d0a204cc`; the fix `60d70808d9` is within 0.3 points of these, all runs in [instructions.txt](data/serialization-cpu/instructions.txt)):

| Case | Interpreter | YJIT |
| --- | --- | --- |
| `post.to_json`, plain text | 136,918 / −0.05% / **−2.96%** | 112,821 / +0.14% / **−4.06%** |
| 20 posts `to_json`, plain | 2,576,624 / +0.03% / **−4.67%** | 2,208,631 / −0.04% / **−5.64%** |
| jbuilder index, plain | 3,651,928 / −0.00% / **−3.17%** | 1,885,558 / +0.50% / **−6.84%** |
| `render json:` 20 posts, plain, pre-8.1 defaults | 3,205,249 / +0.02% / **−6.01%** | 2,633,503 / −0.06% / **−7.30%** |
| 20 posts `to_json`, plain, pre-8.1 defaults | 2,782,684 / −0.04% / **−6.82%** | 2,412,512 / −0.13% / **−8.16%** |
| 20 posts `to_json`, text with `<b>` and `&` | 4,072,830 / +0.00% / **−14.13%** | 3,714,800 / +0.07% / **−15.79%** |
| jbuilder index, text with `<b>` and `&` | 5,145,100 / −0.03% / **−11.13%** | 3,382,135 / −0.06% / **−17.25%** |
| `render json:` 20 posts, 8.1 defaults (no escape; control) | 2,849,732 / −0.13% / −0.04% | 2,278,254 / −0.19% / −0.15% |
| `post.as_json` (no encoding; control) | 117,820 / +0.08% / +0.01% | – |

All runs: [instructions.txt](data/serialization-cpu/instructions.txt). The escape pass in isolation
([escape_variants.rb](../../bench/upstream/serialization_cpu/escape_variants.rb), CPU time, 4 KB document): plain
text 6.2 → 0.47 µs for HTML entities and 6.6 → 3.6 µs with the separators as well (the multibyte search is
the remaining cost); text with `<>&` 172 → 105 µs; a 20-byte document 0.42 → 0.35 µs.

**ruby-bench** (Callgrind, one measured iteration after warmup, A/A = same tree twice):

| | railsbench | lobsters | shipit |
| --- | ---: | ---: | ---: |
| interpreter, S1 (A/A) | −0.054% (+0.025%) | +0.032% (+0.011%) | +0.044% (−0.047%) |
| YJIT, S1 (A/A) | **−0.364%** (−0.096%) | +0.080% (+0.139%) | +0.081% (−0.055%) |

Only railsbench under YJIT moves beyond its A/A, in a single run per variant; the others encode too little JSON
in their measured loops to show it. The census and the micros carry the evidence.

**Census** (allocations, `script/census run --label s-base --aa` / `--label s-s1` on Blog, Campfire, Fizzy,
PingCRM, Redprints CFP, CodeTriage): interpreter / YJIT 30 / 34 of 56 workloads moved −1 object or more (A/A
16 / 11), median −1.0 / −1.5, no SQL changes. HTML pages move too (`to_json` in views and Inertia props); Fizzy's
board −53 and cards −37 objects.

**Where it applies.** Every `to_json`, `ActiveSupport::JSON.encode` and jbuilder template, and `render json:` in
apps before `load_defaults 8.1`, on Ruby 3.3 to 4.0. Ruby 4.1 uses `tr!` and makes it moot there. Measured share of
JSON requests: escape is 0.4% (interpreter) and 0.6% (YJIT) of samples on average, up to 1.2% (Discourse YJIT),
and S1 removes most of it on plain text.

## Overlap checked

* **rails/rails, open:** #58002 (`LazyAttributeSet#keys` without materializing; the largest serialization frame in
  the micros) measured on the same micro, ported by hand because main moved the class into `attribute_set.rb`:
  `as_json` −2.62%, `as_json(include:)` −3.12%, 20 records `as_json` −2.41%, `render json:` −1.86%
  (interpreter instructions). Not duplicated. #59557 (ours, `Array#index_with` on Ruby 4.1) and #59141
  (attributes in an Array) also touch the attribute half. Nothing open touches `json/encoding.rb`,
  `core_ext/object/json.rb` or `serialization.rb` for speed (searched `as_json`, `to_json`, `serializable_hash`,
  `JSON encod`, `jbuilder`, `render json`, `xmlschema`, `TimeWithZone`).
* **rails/rails, merged:** #58746 (`tr!` on Ruby 4.1; byroot's review lifted the version check to load time),
  #58751 (faster `TimeWithZone#xmlschema`), 943a31c500 (separators no longer escaped under `load_defaults 8.1`).
* **ruby/json:** open #1114 (RFC 9839 validation) and #848 only. byroot's recent work is correctness and RFC 8785
  (#1091, #1105, #1107, #1110–#1113, #1115); the generator already has SIMD string scanning and `script_safe`.
  Nothing on HTML-entity escaping; issue search for `escape_html`, `u003c` and `script_safe rails` finds only the
  closed #667.

## Rejected and leads

* **`Hash#as_json` via `transform_values`** when every key is a String: `Hash#as_json` is 10–12% self in the
  micros, and the guarded variant is 2,138 → 1,791 ns on a 12-key native Hash and 4,154 → 3,940 ns on a record's
  hash (CPU time). Rejected: not exact. `transform_values` keeps String-subclass keys that `k.to_s` converts, and
  copies `compare_by_identity`, which `result = {}` does not. The cheap guard (`keys.all?(String)`) allocates; an
  allocation-free one is slower than the current code (3,006 ns).
* **`read_attribute_for_serialization` with Symbols** (`send` with a String is 123 ns against 80 ns): rejected,
  since the names arrive from `attribute_names` as Strings, and converting each to a Symbol is the same lookup `send` already does.
* **`TimeWithZone#as_json`** (5,627 instructions per call, `Time#xmlschema` 1,494 of it): the rest is two module
  attribute reads, the memoized `utc?`/`utc` and `force_encoding`; nothing exact left after #58751.
* **Ruby 4.1's `tr!` path:** #58746 notes `tr!` builds a table per call and is slower than the Regexp below 128
  bytes; S1's per-character search may beat `tr!` too. Unmeasured here (no Ruby 4.1 build in this orb). Lead.
* **jbuilder** (rails/jbuilder, outside this bet's Rails/json scope): `_blank?` is `BLANK == value`, which calls
  `Blank#==` (`super || Blank === other`) twice per attribute (2.6% self of the jbuilder micro, 11.5% for
  jbuilder's own frames); `Blank === value` would be the same test. Lead.
* **json gem HTML escaping:** a generator option that escapes `<>&` (as `script_safe` does `/` and the separators)
  would remove Rails' second pass entirely (15% of the jbuilder micro). A feature, not a small exact change; would
  need byroot's interest first. Lead.

## Method

* **Trees.** `rails-wt/sbase` at `b084108cf3`, `rails-wt/s1` (S1), `rails-wt/s58002` (#58002 ported). Micro
  bundles via [gen_gemfile.rb](../../bench/upstream/serialization_cpu/gen_gemfile.rb) (`rails` by path, sqlite3,
  jbuilder 2.15.1, json 3.1.0, stackprof), A/A as a second identical Gemfile.
* **Profiles.** stackprof 0.2.28, wall mode at 200 µs, raw; census runs via
  [census_prof_run.rb](../../bench/upstream/serialization_cpu/census_prof_run.rb) with `script/census`'s
  environment; ranking by [rank.rb](../../bench/upstream/serialization_cpu/rank.rb) (`--within` restricts to
  serialization roots).
* **Instruction counts.** Valgrind 3.19 Callgrind, `--toggle-collect=rb_ary_cycle` around the measured loop
  ([irmicro.rb](../../bench/upstream/serialization_cpu/irmicro.rb); YJIT with `--smc-check=all` and 600 warmups);
  ruby-bench via `bench/upstream/arcpu/irab.rb`.
* **Census.** `script/census run --out census-out/serial`, labels `s-base`, `s-base2` (A/A) and `s-s1`; compare
  with `script/census compare --base s-base --aa s-base2 s-s1`.

## Draft

### S1: Escape JSON by searching for each character instead of a Regexp

Before Ruby 4.1, `ActiveSupport::JSON.encode` escapes `<`, `>`, `&`, U+2028 and U+2029 with one `gsub!` over a
Regexp union, which runs the regexp engine over the whole document even when nothing needs escaping. This searches
for each character with `include?` and replaces only the ones that occur, still on the binary String, so the
output is unchanged, including invalid UTF-8 from `JSON::Fragment`. It calls the core String methods directly, so
singleton methods on the generated String can't skip escaping, and String subclasses, such as a SafeBuffer from a
custom encoder, keep the single `gsub!`. Ruby 4.1 keeps using `tr!`.

Instructions per call (Callgrind, Ruby 4.0.7, 20 records of 11 columns):

| | interpreter | YJIT |
| --- | ---: | ---: |
| `posts.to_json` | −4.5% | −5.3% |
| jbuilder index | −3.0% | −6.2% |
| `render json: posts` (before `load_defaults 8.1`) | −5.8% | −7.4% |
| `posts.to_json`, text with `<b>` and `&` | −13.5% | −15.1% |

This path runs for every `to_json` and jbuilder template, and for `render json:` before 8.1 defaults; on six apps,
30 of 56 workloads allocate at least one object fewer (16 in an A/A run). A single small record is within about ±1%
(+0.5% interpreter, −1.0% YJIT).

## PR body (minimal variant)

**Escape JSON from JSON::Coder by searching for each character**

Before Ruby 4.1, `JSONGemCoderEncoder`, the default encoder with json 2.15.2 or later, escapes `<`, `>`, `&`, U+2028 and U+2029 with one `gsub!` over a Regexp union, which runs the regexp engine over the whole document even when nothing needs escaping. Its String comes straight from `JSON::Coder#dump`, so this searches it for each character with `include?` and replaces only the ones that occur. The replacements contain none of the five characters, and the search still runs on the binary String, so the output is the same, including invalid UTF-8 from `JSON::Fragment`; both settings are read before anything is replaced. `JSONGemEncoder` (older json, custom encoders) keeps the single `gsub!`, and Ruby 4.1 keeps using `tr!`.

| Per call, Ruby 4.0.7, 20 records of 11 columns | Interpreter | YJIT |
| --- | ---: | ---: |
| `posts.to_json` | 2,576k → 2,459k instructions (−4.5%), 359 → 342 µs | 2,223k → 2,088k (−6.1%), 291 → 280 µs |
| jbuilder index | 3,651k → 3,547k (−2.9%), 799 → 813 µs | 1,862k → 1,749k (−6.1%), 382 → 361 µs |
| `render json: posts` before `load_defaults 8.1` | 3,204k → 3,012k (−6.0%), 583 → 558 µs | 2,633k → 2,449k (−7.0%), 398 → 361 µs |
| `posts.to_json`, text with `<b>` and `&` | 4,073k → 3,500k (−14.1%), 524 → 446 µs | 3,703k → 3,132k (−15.4%), 464 → 379 µs |

Instructions are Callgrind's with GC off (A/A within 0.2%, `render json:` under YJIT 1.8%); µs are medians of 8 interleaved rounds and as noisy as wall time on a shared machine (A/A up to 5%), so the instructions carry the comparison. A single small record gains too (−2.8% / −4.4% instructions). Plain documents allocate one object fewer; a document with `<`, `>` and `&` allocates 7 more. On ruby-bench, railsbench under YJIT runs 0.28% and 0.76% fewer instructions in two runs (A/A −0.08% and +0.04%); lobsters, shipit and the interpreter are within noise. I found the site by profiling the JSON endpoints of eleven open-source apps, where escaping was 0.4% (interpreter) to 0.6% (YJIT) of samples: https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/serialization-cpu.md (benchmark: https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/serialization_cpu/micro.rb).
