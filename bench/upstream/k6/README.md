# K6: `button_to` params with `tag`, after rails/rails#50312

Census 9's lead 2, params half ([census 9](../../../docs/upstream/rails-main-census-9.md#button_to-since-50312)),
built and measured 2026-11-14 in [thread T-01a1da35](https://ampcode.com/threads/T-01a1da35-7853-752b-a1f6-83e465cd9102).
Queue item: [K6](../pr-queue/items/K6.md). Branch `thomasklemm/button-to-params-tag` on thomasklemm/rails, head
`aba0855fcf`, built on rails/rails main `50c54eed06`. Ruby 4.0.9. K5 (calling `form_tag_with_body` directly) is not
part of it: it bypasses the public `form_tag`.

## The change

```diff
         if params
           to_form_params(params).each do |param|
-            inner_tags.safe_concat hidden_field_tag(param[:name], param[:value], id: nil)
+            input_options = { type: "hidden", name: param[:name], value: param[:value] }
+            input_options[:autocomplete] = "off" unless ActionView::Base.remove_hidden_field_autocomplete
+            inner_tags.safe_concat tag(:input, input_options)
           end
         end
```

plus one test, `test_button_to_with_params_omits_autocomplete_when_remove_hidden_field_autocomplete_is_true`
(+12/−1 in `navigation_helper.rb` and `navigation_helper_test.rb`). The lines are #50312's own `token_tag` and
`method_tag` shape (`options = { type: "hidden", name:, value: }`, the same `autocomplete` line, `tag(:input,
options)`), and 8-1-stable's and the pre-#50312 `button_to`'s, which wrote `options = …` (reassigning the method's
`options` argument inside the block) and `tag(:input, **options)`. K6 names the Hash `input_options` and passes it
without a splat, as `token_tag` does, which also saves the copy the splat makes: one object per param. Census 9's K6
diff used `**input_options` and was checked on the same 5,760 inputs.

Out loud: for each param, build a hidden input's attributes from its name and value; add `autocomplete="off"` unless
the app turned that off; render it with `tag`.

## Why the output is the same

Main's path is `hidden_field_tag(name, value, id: nil)`: `{ id: nil }.merge(type: :hidden)`, then `autocomplete:
"off"` unless `remove_hidden_field_autocomplete` (the key is never already set), then `text_field_tag`, which builds
`{ "type" => "text", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)`
and calls `tag :input`. The Hash `tag_options` sees is `type: :hidden, name:, id: nil, value:, autocomplete: "off"`,
in that order. `tag_options` renders keys by `to_s`/`name`, skips `nil` values (so `id` disappears), renders the
Symbol `:hidden` and the String `"hidden"` the same way, and none of these keys is in `TAG_TYPES`. K6 hands it
`type: "hidden", name:, value:, autocomplete: "off"`. Names from `to_form_params` are always `namespace.to_s`;
`sanitize_to_id`'s result is overwritten by `id: nil`, so its only effect on main is the work.

The one observable difference: main calls the public `hidden_field_tag` and `text_field_tag` for each param, so an
app that overrides them saw `button_to`'s params pass through them from #50312 (merged 2026-11-07, unreleased) until
now. 8.1 and the pre-#50312 `button_to` never called them; K6 restores that. `form_tag` and `tag` overrides still see
every call, as on main.

## Equivalence

[results/equivalence.txt](results/equivalence.txt) (output hashes and the full diff):

* Census 9's [`button_to_diff.rb`](../census9/button_to_diff.rb), 5,760 inputs: main and K6 byte-identical, including
  `html_safe?` (names, URLs, methods in any case, flat and nested params, Arrays, HTML characters, `form`/`form_class`,
  `remote`, `authenticity_token`, blocks, `data`/`disabled`, both `button_to_generates_button_tag` settings,
  `remove_hidden_field_autocomplete` on and off, forgery protection on and off).
* [`widen.rb`](widen.rb), 1,544 inputs where K6 alone differs from census 9's K7 (K6 keeps `form_tag`, its `capture`
  and the per-param attribute Hash): Symbol, Integer, Float, `nil`, `true`/`false`, Array and Hash keys; keys that
  need escaping (`"`, `'`, `<`, `&`, `&amp;`, `]`, `[`, `[]`, whitespace, tab and newline, Unicode, binary and
  invalid UTF-8, 300 characters); html_safe keys and values; a String subclass with its own `to_s`; objects with
  their own `to_s` or `to_param` (returning `nil`, `false`, an Array, a Hash, a SafeBuffer, a Symbol, an Integer);
  `nil`, `false`, `true`, `""`, Symbol, Integer, Float, BigDecimal, Date and Time values; empty and nested Arrays and
  Hashes; HashWithIndifferentAccess, permitted and unpermitted `ActionController::Parameters`, a Hash subclass,
  non-Hash params; raising `to_param` and `to_s`; every combination with both `button_to_generates_button_tag` and
  `remove_hidden_field_autocomplete` settings and forgery protection on and off; params mixed with every button and
  form option, string-keyed `"params"`, a frozen options Hash, `false` and Hash URLs, a block button; calls inside
  `capture`, inside a `content_tag` block, without an output buffer and from a compiled ERB template; and view
  subclasses that prepend `form_tag`, `tag`, `hidden_field_tag`, `text_field_tag` and `sanitize_to_id`. Each line
  records the result's class, `html_safe?`, encoding and `frozen?`, or the exception class and message (97 inputs
  raise, the same on both). Main and K6 differ in exactly the `hidden_field_tag` and `text_field_tag` override cases
  above; main against `main2` (a second checkout) is identical.
* Controls, so the probes can fail: always adding `autocomplete` changes 288 lines of the census grid and 694 of
  `widen.rb`; rendering without escaping changes 288 and 172; `value.to_s` (which would print `value=""` for `nil`)
  changes none of the census grid and 130 lines of `widen.rb`. Pointing the census grid at the pre-#50312 tree
  differs from main at once.

## Tests

On the head: Action View `rake test` (template 2,968 runs, Action Pack integration 251, Active Record integration
177), 0 failures, 0 errors, no warnings from Rails files. RuboCop 1.90.0 (Rails' config): no offenses on both files.

Do the existing tests pin the output? `test_button_to_with_params`, `_with_permitted_strong_params`,
`_with_nested_hash_params` and `_with_nested_array_params` use `assert_dom_equal`, which pins each input's `type`,
`name`, `value` and `autocomplete="off"` and the absence of an `id` (each mutation fails 4 tests: drop
`autocomplete`, add an `id`, `type="text"`). Nothing pinned `remove_hidden_field_autocomplete: true` for `button_to`
params, neither on main nor before #50312: always adding `autocomplete` passed every Action View test. That setting
is now read in `button_to` itself, so the new test covers it. It passes on main and on K6 and fails with that
mutation. `nil`/`false` values (the `value.to_s` mutation) are not pinned either; that mistake is less plausible, so
no test was added for it.

RuboCop `Metrics/*` with the default config, for `button_to`: ABC 47.47 → 50.38, cyclomatic 20 → 21, perceived
21 → 22, lines 39 → 41. The extra branch is the `remove_hidden_field_autocomplete` check `hidden_field_tag` made
before, now in the same shape as `token_tag` and `method_tag`.

## Size sweep

[`k6_micro.rb`](k6_micro.rb) and [`sweep.sh`](sweep.sh): Ir per `button_to` call under census 8's patched Callgrind
(`IrCount`, `--instr-atstart=no`), fixed heap (`RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000`),
GC off in the window, 100 calls after 100 warmup calls (5 after 5 for the 2,000-param, 5,000-param and MB cases).
Trees: main `50c54eed06` and its twin `main2` (the A/A), K6 (lib identical to the head), and #50312's first parent
`9ba8b1edee` ("before #50312"). Each tree runs in its own process. Params are `"k1" => "v1"`…; `nested_20x10` is 20
Hashes of 10, `arrays_20x10` 20 Arrays of 10; the MB rows put one large name or value in `params:`, with `<` (which
escaping replaces) absent, first, last or every fourth byte. Raw: [results](results/); table: [`table.rb`](table.rb).

### Interpreter

| Case | before #50312 | main | K6 | K6 vs main | K6 vs before #50312 | A/A | objects before / main / K6 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `no_params` | 94,172 | 137,420 | 137,551 | +0.1% | +46.1% | 0.00% | 13 / 23 / 23 |
| `params1` | 160,278 | 230,504 | 203,592 | −11.7% | +27.0% | 0.03% | 30 / 45 / 39 |
| `params2` | 220,032 | 317,175 | 262,900 | −17.1% | +19.5% | 0.04% | 42 / 62 / 50 |
| `params5` | 398,189 | 575,911 | 439,483 | −23.7% | +10.4% | 0.06% | 78 / 113 / 83 |
| `params20` | 1,293,099 | 1,873,523 | 1,326,369 | −29.2% | +2.6% | 0.07% | 258 / 368 / 248 |
| `params200` | 12,067,484 | 17,498,299 | 12,011,451 | −31.4% | −0.5% | 0.08% | 2,418 / 3,428 / 2,228 |
| `params2000` | 120,078,078 | 174,274,877 | 119,388,370 | −31.5% | −0.6% | 0.08% | 24,018 / 34,028 / 22,028 |
| `params5000` | 300,835,471 | 435,909,156 | 298,998,799 | −31.4% | −0.6% | 0.08% | 60,018 / 85,028 / 55,028 |
| `nested_20x10` | 12,671,109 | 18,137,379 | 12,619,727 | −30.4% | −0.4% | 0.07% | 2,718 / 3,728 / 2,528 |
| `arrays_20x10` | 12,377,520 | 17,839,966 | 12,334,489 | −30.9% | −0.3% | 0.09% | 2,538 / 3,548 / 2,348 |
| `csrf_delete_params20` | 1,397,271 | 1,983,653 | 1,437,129 | −27.6% | +2.9% | 0.06% | 269 / 381 / 261 |
| `params2000_1kb` | 149,008,281 | 204,478,517 | 149,483,885 | −26.9% | +0.3% | 0.06% | 28,018 / 38,028 / 26,028 |
| `value_1mb_absent` | 9,834,953 | 10,846,738 | 10,849,004 | +0.0% | +10.3% | 0.00% | 30 / 45 / 39 |
| `value_1mb_early` | 11,768,747 | 12,794,528 | 12,761,972 | −0.3% | +8.4% | 0.04% | 32 / 47 / 41 |
| `value_1mb_late` | 11,768,759 | 12,794,578 | 12,762,027 | −0.3% | +8.4% | 0.04% | 32 / 47 / 41 |
| `value_1mb_all` | 24,915,742 | 26,648,828 | 26,629,630 | −0.1% | +6.9% | 0.00% | 32 / 47 / 41 |
| `value_4mb_late` | 42,791,611 | 46,640,952 | 46,652,892 | +0.0% | +9.0% | 0.04% | 32 / 47 / 41 |
| `name_1mb_absent` | 9,835,123 | 38,312,730 | 10,834,234 | −71.7% | +10.2% | 0.04% | 30 / 46 / 39 |
| `name_1mb_late` | 11,763,656 | 40,241,423 | 12,767,224 | −68.3% | +8.5% | 0.01% | 32 / 48 / 41 |
| `name_1mb_nested` | 10,719,774 | 39,188,702 | 11,708,816 | −70.1% | +9.2% | 0.00% | 36 / 53 / 45 |
| `csrf_form_tag` | 193,484 | 193,512 | 193,424 | −0.0% | −0.0% | 0.03% | 29 / 29 / 29 |
| `hidden_field_tag` | 79,500 | 79,498 | 79,507 | +0.0% | +0.0% | 0.07% | 11 / 11 / 11 |
| `link_to` | 41,355 | 41,359 | 41,414 | +0.1% | +0.1% | 0.05% | 5 / 5 / 5 |

`no_params`, `csrf_form_tag`, `hidden_field_tag` and `link_to` run code K6 does not change; they move by at most
0.13% between trees (A/A ≤ 0.09%). The MB-value rows move by −0.3% to +0.03% against main (−32.6k to +11.9k Ir): a
param's fixed saving (27k Ir) is under 0.3% at that size, and those rows scatter around it by about ±30k Ir, which is
not attributed.

* **Params:** from the 200- and 2,000-param rows, each param costs 87.1k Ir and 17 objects on main, 59.7k and 11 on
  K6, and 60.0k and 12 before #50312, so K6 saves 27.4k Ir and 6 objects per param: −12% with one param, −29% with
  20, −31% from 200 to 5,000. With 20 params `button_to` is back within 3% of before #50312, and with 200 or more
  small params 0.3–0.6% below it: a field is 0.3k Ir cheaper than before #50312 (no splat copy), which outweighs the
  fixed 43k Ir #50312 added to every call (`no_params`).
* **Large values:** 1 MB and 4 MB values cost the same on main and K6 within 0.3% (escaping the value dominates; both
  escape it once in `tag_options`). **Worst row:** `value_4mb_late`, +0.03% (+11,940 Ir).
* **Large names:** main's `sanitize_to_id` copies the name twice (`delete("]")`, then `tr`) only for `id: nil` to drop
  the result; K6 skips it: −68% to −72% for a 1 MB name.
* Not K6: with one large param, main and K6 both cost about 1 Ir per byte more than before #50312 (+1.0M at 1 MB,
  +3.9M at 4 MB), so #50312 added a pass over the form's body somewhere outside the params loop. Not attributed;
  the `form_tag` body path (`capture`, `safe_join`, `content_tag`) is the first suspect, which is K5's territory.

### YJIT

| Case | before #50312 | main | K6 | K6 vs main | K6 vs before #50312 | A/A | objects before / main / K6 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `no_params` | | not flat | not flat | | | | |
| `params1` | 89,011 | 129,227 | 110,562 | −14.4% | +24.2% | 0.22% | 30 / 46 / 40 |
| `params2` | 124,432 | 183,091 | 146,014 | −20.3% | +17.3% | 0.10% | 42 / 63 / 51 |
| `params5` | 232,200 | 343,014 | 250,762 | −26.9% | +8.0% | 0.08% | 78 / 114 / 84 |
| `params20` | 758,281 | 1,132,415 | 763,868 | −32.5% | +0.7% | 0.07% | 258 / 369 / 249 |
| `params200` | 7,138,497 | 10,707,841 | 7,015,372 | −34.5% | −1.7% | 0.06% | 2,418 / 3,429 / 2,229 |
| `params2000` | 71,473,499 | 106,997,905 | 70,080,670 | −34.5% | −1.9% | 0.08% | 24,018 / 34,029 / 22,029 |
| `params5000` | 179,101,211 | 267,979,410 | 175,575,050 | −34.5% | −2.0% | 0.05% | 60,018 / 85,029 / 55,029 |
| `nested_20x10` | 7,651,662 | 11,247,463 | 7,524,593 | −33.1% | −1.7% | 0.06% | 2,718 / 3,729 / 2,529 |
| `arrays_20x10` | 7,393,080 | 10,982,387 | 7,267,598 | −33.8% | −1.7% | 0.06% | 2,538 / 3,549 / 2,349 |
| `csrf_delete_params20` | 815,284 | 1,193,654 | 826,818 | −30.7% | +1.4% | 0.08% | 269 / 382 / 262 |
| `params2000_1kb` | 100,294,503 | 137,512,359 | 100,466,957 | −26.9% | +0.2% | 0.05% | 28,018 / 38,029 / 26,029 |
| `value_1mb_absent` | 10,560,692 | 11,521,414 | 11,497,941 | −0.2% | +8.9% | 0.00% | 30 / 46 / 40 |
| `value_1mb_early` | 11,687,999 | 12,663,188 | 12,650,171 | −0.1% | +8.2% | 0.00% | 32 / 48 / 42 |
| `value_1mb_late` | | not flat | not flat | | | | |
| `value_1mb_all` | 24,839,802 | 26,524,557 | 26,497,561 | −0.1% | +6.7% | 0.00% | 32 / 48 / 42 |
| `value_4mb_late` | 42,735,867 | 46,534,028 | 46,515,230 | −0.0% | +8.8% | 0.04% | 32 / 48 / 42 |
| `name_1mb_absent` | 10,540,894 | 38,992,279 | 11,502,631 | −70.5% | +9.1% | 0.03% | 30 / 47 / 40 |
| `name_1mb_late` | 11,688,165 | 40,139,576 | 12,645,118 | −68.5% | +8.2% | 0.01% | 32 / 49 / 42 |
| `name_1mb_nested` | 10,637,792 | 39,066,060 | 11,599,697 | −70.3% | +9.0% | 0.01% | 36 / 54 / 46 |
| `csrf_form_tag` | 102,762 | 102,874 | 102,551 | −0.3% | −0.2% | 0.19% | 30 / 30 / 30 |
| `hidden_field_tag` | 46,046 | 45,806 | 45,968 | +0.4% | −0.2% | 0.07% | 11 / 11 / 11 |
| `link_to` | 21,873 | 21,533 | 21,517 | −0.1% | −1.6% | 1.35% | 5 / 5 / 5 |

A cell counts only when main, `main2` and K6 compiled nothing in the measured window (and before #50312 too, for its
column). `no_params` compiled 3 blocks in every tree's window and `value_1mb_late` 1, so they are "not flat" and not
claimed. A/A ≤ 0.22% on every params row. The controls K6 does not change move by up to 0.4% between trees
(`hidden_field_tag` +0.4% against an A/A of 0.07%; `link_to`'s own A/A is 1.35%), so YJIT differences below about
0.5% are not claimed.

The interpreter's picture holds: −14% with one param, −32.5% with 20, −34.5% from 200 to 5,000, back within 1% of
before #50312 at 20 params and 1.7–2.0% below it from 200 on; 1 MB and 4 MB values within 0.2%; 1 MB names −68.5% to
−70.5%.

## Not done

* Ruby master × ZJIT (DECISIONS asks for it before a Rails candidate opens).
* Reviews: no claude-code or Sol/stand-in pass yet.
