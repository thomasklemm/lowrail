# Form helper stack below `hidden_field_tag` (2026-11-16)

Follow-up to K6 #59804, where the reviewer asked whether `text_field_tag` could skip `sanitize_to_id` for an
explicit `id: nil`. This looks one level deeper: which helpers under `*_field_tag` and the form builder allocate
objects that an exact rewrite could avoid, and which other callers would gain.

Rails main `4617bd9`, Ruby 4.0.7 interpreter, objects per call counted with `ObjectSpace` allocation tracing after
three warm calls (`form_stack_trace.rb`). Active Record model on SQLite in memory, no validation errors.
Candidates are prototypes in `form_stack_patches.rb`, switched on by letter with `PATCH=`.

| Candidate | What it skips |
| --- | --- |
| A | `Errors#where` returns `[]` when there are no errors, no type and the attribute is a Symbol or a plain String (`error_wrapping` asks this for every builder field) |
| B | `field_id` skips `gsub` and `delete_suffix` when the object name has nothing to replace (`_` counts as nothing: `gsub` maps it to itself) |
| C | `field_name` skips `map!.join` when there are no extra names |
| D | `Tags::Base#sanitized_method_name` skips `delete_suffix` unless the name ends in `?` |
| E | `text_field_tag` builds its attribute Hash in one pass instead of `{...}.update(options.stringify_keys)`; `hidden_field_tag` uses `dup` and `[]=` instead of `merge` |
| S | with E, also skips `sanitize_to_id` when `id` is given (the reviewer's suggestion) |

| Objects per call | main | A–E | 
| --- | ---: | ---: |
| `text_field_tag` | 9 | 8 |
| `hidden_field_tag` | 11 | 9 |
| `email_field_tag` with `class:` | 11 | 10 |
| `label_tag` | 7 | 6 |
| `check_box_tag` | 11 | 10 |
| `f.text_field` | 27 | 20 |
| `f.hidden_field` | 24 | 19 |
| `f.check_box` | 31 | 24 |
| `f.select` | 40 | 33 |
| `f.label` | 77 | 70 |
| `f.submit` | 60 | 60 |

Per candidate on `f.text_field`: A −2, B −3, C −1, D −1, E 0. E only reaches the `*_tag` helpers; the builder
goes through `Tags::TextField#render` and `tag` directly.

`f.label` and `f.submit` are dominated by I18n lookups (`I18n::MissingTranslation` objects, `humanize`, interpolation),
not by Action View. Not investigated.

## Equivalence

* `form_stack_fuzz.rb`: 12,528 outputs of `field_id`, `field_name`, `text_field_tag`, `hidden_field_tag`,
  `email_field_tag`, `check_box_tag`, `label_tag` and `sanitize_to_id` over 216 names (random mixes of brackets,
  `_`, `?`, `.`, `:`, non-ASCII, quotes, Symbols, nil, Integer, invalid UTF-8, UTF-16) and 11 option shapes.
  A–E: byte-identical to main, including the 116 raising inputs.
* With S: identical except for invalid UTF-8 names, where main raises `ArgumentError` from `sanitize_to_id` and S
  renders the field.
* `errors_check.rb`: `Errors#[]`, `where`, `messages_for`, `include?` with and without errors, Symbol, String,
  String subclass, Integer, nil, Object and a type proc: identical with A apart from object addresses.
* The builder scenarios render byte-identical HTML with A–E.

Open boundaries, not checked: an app or gem that overrides `Hash#stringify_keys` or passes a non-Hash options object
(E), a String object name with a singleton `gsub` (B), a String subclass attribute to `Errors#where` (A takes the
old path for it).

## Time

benchmark-ips, two rounds, wall time in this orb, +2% to +9% i/s for A–E. Noise is of the same size (`f.hidden_field`
main 46.6k/48.9k, A–E 54.6k/43.4k). No speed claim; that needs `lowrail bench`.

## Earlier dispositions

C12 (actionview-render-c12.md) and rails-common-paths.md rejected B, C and the `Errors#[]` early return one by one
as under the share bar (`field_id` 0.022% of instructions in 7 apps) or as inexact (an unguarded `@errors.empty?`
skipped `normalize_arguments`; A guards on the attribute's class). Together they remove 7 of 27 objects per
builder field, but form pages remain a small share of request time.

## `f.label` and `f.submit`

`i18n_probe.rb` logs every backend lookup and `I18n::MissingTranslation` for one call, with no app translations:

```
f.label  (Post, :title)
  helpers.label.post.title            miss
  helpers.label.post.title            miss   (the same key again, as the default) -> MissingTranslation
  activerecord.attributes.post.title  miss
  attributes.title                    miss   -> MissingTranslation, then "title".humanize
f.submit (persisted Post)
  activerecord.models.post            miss   (model_name.human)
  helpers.submit.post.update          miss
  helpers.submit.update               hit    "Update %{model}"
```

**Candidate L (label), Action View only.** `Tags::Translator#i18n_default` adds
`:"#{model.model_name.i18n_key}.#{method}"` as the first default. It is there for forms whose object name differs from
the model (`as: :article`, nested attributes), but when the object name is the model's `i18n_key`, the usual case, it
is the key just looked up, so it is looked up twice and its miss builds a `MissingTranslation`. L drops that default
when `key.name == object_name`:

* `f.label` 77 → 68 objects, 4 → 3 lookups, one `MissingTranslation` fewer; benchmark-ips (wall time, orb, three
  rounds) 14.2k → 16.3k i/s. No speed claim without `lowrail bench`.
* `label_equiv.rb`: 720 lines (3,600 `f.label` calls) over 8 translation setups (none, hit, empty string, Proc, Symbol
  link, `activerecord.attributes`, nested and namespaced `helpers.label` keys, `value:` keys), both settings of
  `raise_on_missing_translations`, and 9 builders (Symbol and String object names, `as:`, nested attributes,
  namespaced model with `admin_user` and `admin/user`, Active Model, a non-model object, nil). Byte-identical with
  and without L, with `Backend::Simple` and with `Backend::Fallbacks` (`de` → `en`). Lookups per case drop only where
  the object name is the `i18n_key`.
* Observable only to code that watches lookups, such as a backend or `lookup` override that logs or counts them: it
  sees the duplicate lookup disappear.

**Rest of `f.label`:** the `human_attribute_name` miss (`lookup_ancestors` walks `ancestors` per call, one
`MissingTranslation`, `humanize`). The i18n side is i18n-performance.md's C2/C3 and the `MissingTranslation` lead
(not exact). Not new.

**`f.submit`** runs once per form, not per field. Its 60 objects are mostly i18n plumbing and interpolation, two
`humanize` calls (model name, then "Update Post" for the last default, built even though Action View's own locale
file has `helpers.submit.update`), and `set_default_disable_with`'s `fetch("data", {})` plus `deep_merge!` (3 Hashes).
Building the last default lazily needs a Proc default, which custom backends see; not exact. Not built.

## `hidden_field_tag` itself (alternative to K6's change in `button_to`)

K6 rebuilds the hidden field inside `button_to`. Instead, `button_to` can keep main's
`hidden_field_tag(name, value, id: nil)` and the shared helpers get cheaper, for every caller:

| | Change | Exact? |
| --- | --- | --- |
| T | `tag`: `.freeze.html_safe`, as `content_tag_string` and `self_closing_tag_string` in the same file already do, so the SafeBuffer shares the string instead of Ruby allocating a hidden one | yes |
| Z | `sanitize_to_id`: `tr!` on the `delete` result instead of a second copy | yes |
| I | `text_field_tag`: compute `sanitize_to_id(name)` only when the options have no `id` (the reviewer's suggestion on #59804) | invalid UTF-8 names with an explicit `id` render instead of raising `ArgumentError`; the error came from computing an id that is then dropped |
| K | `hidden_field_tag`: `{ **options, type: :hidden }` instead of `merge` | **no**: with a HashWithIndifferentAccess, a String `"autocomplete"` key is no longer seen by `key?(:autocomplete)` (214 of 15,984 fuzz lines differ). Rejected |

`form_stack_fuzz.rb` (15,984 outputs, now with HashWithIndifferentAccess and String-keyed options): T and Z
identical; I and T+Z+I differ only in the 15 invalid-UTF-8 lines. Builder scenarios byte-identical with T+Z+I.

| Objects per call (`hft_count.rb`) | main | T+Z+I | K6 (estimate) |
| --- | ---: | ---: | ---: |
| `hidden_field_tag(name, value, id: nil)` | 11 | 8 | 5 in `button_to` |
| `hidden_field_tag(name, value)` | 11 | 9 | – |
| `text_field_tag` | 9 | 7 | – |
| `tag(:input, …)` | 5 | 4 | – |
| `button_to` with 20 params | 452 | 391 | about 332 (−6 per param) |
| `f.text_field` / `f.check_box` (T only reaches them) | 27 / 31 | 26 / 29 | – |

benchmark-ips (wall time, orb, two rounds; not a speed claim): `hidden_field_tag(id: nil)` +20%, `button_to` with
20 params +13%, `tag(:input)` +6%, `text_field_tag` +1%.

## Sweep of the tag and form helpers (2026-11-16, Rails main `a5203b3d4d`)

Every allocation site under `tag`, `content_tag`, `tag.*`, the `*_tag` helpers, the form builder's fields, and the
Active Model and Active Support code they call per field, checked for an exact rewrite at the lowest level its callers
share. Objects per call on Ruby 4.0.9 (interpreter), from `GC.stat(:total_allocated_objects)` over 100 calls after
3 warm-up calls (`sweep_count.rb`). Inputs are realistic: names like `post[title]`, no options or one key, `button_to`
with no `params:` or one param, an Active Record `Post` without validation errors, and the defaults of a new app
(`form_with_generates_ids`, `remove_hidden_field_autocomplete`, `button_to_generates_button_tag`, no UTF-8 enforcer).
So the counts differ slightly from the 4617bd9 table above (`f.text_field` 28 there was 27). Candidates are prototypes in
`sweep_patches.rb`, switched on by name with `PATCH=`. `sweep_table.sh` prints the tables. Functional work only:
no speed claims, no Callgrind.

Left out because they are handled elsewhere: #59804 (`text_field_tag` computing the id only when none is given,
`sanitize_to_id` with `tr!`, `tag` freezing before `html_safe`; it appears below only as the reference column T) and
queue item LBL1 (`f.label`'s duplicate translation lookup).

### Candidates

Saved objects per call. A blank cell in the per-field column means the candidate touches no builder field. "Per field"
counts `f.text_field`, `f.text_area`, `f.hidden_field`, `f.check_box`, `f.radio_button`, `f.select` and `f.label`.

| | Site | Change | Saved per helper call | Saved per builder field | Exact? | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| B | `FormTagHelper#field_id` | skip `gsub` and `delete_suffix` when the object name has nothing to replace and the method name doesn't end in `?` | – | 4 on every field | yes; a caller's String with a singleton `gsub`/`delete_suffix` no longer sees those calls | **PR 1** |
| C | `FormTagHelper#field_name` | skip `map!.join` when there are no extra names | – | 1 on every field | yes | **PR 1** |
| D | `Tags::Base#sanitized_method_name` | copy only when the name ends in `?` | – | 1 on every field | yes | **PR 1** |
| PH | `Tags::Placeholderable#initialize` | `(...)` instead of `(*)` | – | 1 (text-like fields, text area) | yes; `parameters` reports `[[:rest, :*], [:keyrest, :**], [:block, :&]]` | **PR 2** |
| AMT | `ActiveModelInstanceTag#content_tag` | name `content_tag`'s parameters instead of `(type, options, *)` | – | 1 (text area, select, label) | yes for every valid call; a wrong-arity call on this internal module says "expected 2..4" instead of "expected 2+" / "1..4" | **PR 2** |
| V | `Tags::Base#value_before_type_cast` | build `"<name>_before_type_cast"` only when the value came from the user | – | 1 (text-like fields, persisted or untouched record) | yes, same calls in the same order | **PR 2** |
| SV | `Tags::Base#sanitized_value` | `gsub!`/`downcase!` on the first copy | – | 2 (label, radio button, `multiple` check box) | yes, the first `gsub` always returns a new plain String | **PR 2** |
| CB | `Tags::CheckBox#hidden_field_for_checkbox` | `[]=` on the slice instead of `merge!` of a literal Hash | – | 1 (check box) | yes | **PR 2** |
| OS | `options_for_select` | `map!` on the `[selected, disabled]` pair, which `extract_selected_and_disabled` always builds new | – | 1 (select) | yes | **PR 2** |
| TR | `Tags::Translator#initialize` | `gsub` only when the object name contains `_attributes][` | – | 2 (`f.label` without text, `placeholder: true`) | yes; the name is the caller's String instead of a copy, never mutated | **PR 2** (or with LBL1, same class) |
| HFT | `hidden_field_tag` | `dup` and `[]=` instead of `merge` | 1 | – | yes; a Hash subclass that overrides `merge` sees `dup` instead | **PR 3** |
| LT | `label_tag` | `options ? options.stringify_keys : {}` | 1 (without options) | – | yes | **PR 3** |
| CBT | `check_box_tag` | `args` instead of `[*args, false]` | 1 | – | yes, `checked` is `nil` instead of `false` when not given, used only in `if checked` | **PR 3** |
| O | `tag`, `TagBuilder#self_closing_tag_string` | write the attributes into the tag's own String through a new `append_tag_options`, which `tag_options` now wraps | 1 on every `tag()` with options and void `tag.*` (`*_field_tag`, `submit_tag`, `button_to`, CSRF and `_method` inputs) | 1 (input fields), 2 (check box) | yes; an override of `TagBuilder#tag_options` (`:nodoc:`) no longer sees `tag()` and void elements | **PR 4**, after #59804 (same line; with its T it is −2 per `tag()`) |
| DA | `TagBuilder#append_prefix_tag_option` | `dasherize` only names that contain `_` | 1 per `data-`/`aria-` key without `_` (`controller`, `action`, `id`, `label`) | – | yes; a `String#dasherize` override is called only for names with `_` | **PR 5** |
| AM | `ActiveModel::Errors#messages_for` (what `errors[]` and `error_wrapping` call) | return `[]` when there are no errors, no type, and the attribute is a Symbol or a plain String | – | 4 on every field except hidden ones | output yes; two boundaries, below | **PR 6** (Active Model) |
| A | `Errors#where` | the same guard one level down | – | 2 | as AM | superseded by AM |
| TB | `Tags::Base#tag_builder` | use the template's `TagBuilder` (`@template_object.tag`) | – | 1 on every field | output yes; a view's own `safe_join` and `tag` overrides start being called by builder fields | hold, Thomas decides |
| T2 | `append_tag_option` (parked lead, contributions.md) | join Array values without `safe_join`'s SafeBuffer | 1 per `class: [..]` attribute (12 → 11) | – | output yes; a view's `safe_join` override no longer sees Array attribute values | still parked |
| LB | `Tags::Label#render` | build the `LabelBuilder` only when the block or translation needs it | – | 1 (`f.label :x, "Text"`) | yes | reject: writes the constructor call twice for one object |
| ST | `set_default_disable_with` | `fetch("data") { {} }` | 0 | – | yes | reject: without `data` both forms build the Hash |

AM's boundaries: an attribute name that is invalid UTF-8 raised `EncodingError` from `to_sym` on a model without
errors and now returns `[]` (the raise came from work whose result was discarded). And a plain String attribute with a
stateful singleton `to_sym` is called less often. Unlike the C12 version (an unguarded `@errors.empty?`), the guard
skips only attributes whose `to_sym` can't run app code. Hidden fields don't wrap errors, so they gain nothing.

Not found or not exact: `content_tag_string` and `tag.div` can't take O's change without giving up interpolation's
`to_s` semantics for `content` and `name` (stateful `to_s`, Integer content). `stringify_keys` in each field's
`render` copies `@options`, which `objectify_options` has just copied, but the copy is what keeps the caller's Hash
unchanged. The `tag_options` blank checks (PM2) allocate nothing and stay closed. `f.submit` and the rest of `f.label`
are I18n (see above and LBL1).

### Proposed PRs

| PR | Candidates | Files | `f.text_field` | `f.check_box` | `f.select` | `f.label` | 5-field `form_with` | Other callers |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 Field ids and names for plain names | B, C, D | form_tag_helper.rb, tags/base.rb | −6 | −6 | −6 | −6 | −30 | `field_id`/`field_name` in views |
| 2 Fewer copies in the builder's tags | PH, AMT, V, SV, CB, OS, TR | tags/*.rb, active_model_helper.rb, form_options_helper.rb | −2 | −1 | −2 | −5 | −11 | `options_for_select` −1 |
| 3 Fewer copies in `*_tag` helpers | HFT, LT, CBT | form_tag_helper.rb | – | – | – | – | – | `hidden_field_tag`, `label_tag`, `check_box_tag` −1 each |
| 4 Attributes into the tag's own String | O | tag_helper.rb | −1 | −2 | – | – | −5 | every `tag()` with options: `*_field_tag`, `submit_tag`, `button_to`, `f.submit` −1 |
| 5 `data-`/`aria-` names without `_` | DA | tag_helper.rb | – | – | – | – | – | −1 per such key on any tag |
| 6 `Errors#messages_for` without errors | AM | activemodel errors.rb | −4 | −4 | −4 | −4 | −20 | every `errors[:attr]` on a valid model |
| all six | | | 28 → 15 | 32 → 19 | 41 → 29 | 100 → 85 | 279 → 213 | `hidden_field_tag` 11 → 9, `button_to` with one param 47 → 45 |

The combined diff on `a5203b3d4d` is `sweep_recommended.patch` (9 files, +45 −25). Counted on that checkout, it
gives the same numbers as the prototypes.

### Equivalence

* `sweep_fuzz.rb`: 86,726 outputs (or exception class and message) of `field_id`, `field_name`, `tag` (open,
  unescaped, `nil`/`false`/`""`/Array options), `tag.*`, `tag.attributes`, `content_tag`, `text_field_tag`,
  `hidden_field_tag`, `label_tag` (with block), `check_box_tag` (1–4 arguments), `submit_tag`, `button_to`, and
  `f.text_field`, `text_area`, `hidden_field`, `check_box`, `radio_button`, `select`, `label` (plain, text, block,
  `value:`), `submit`, and `form_with`, plus `Errors#[]`, `where`, `messages_for`, `include?` and `added?`. Names include
  Symbols, `nil`, Integers, Floats, objects with a custom and with a counting `to_s`, html_safe Strings, brackets,
  `_attributes][`, non-ASCII, invalid UTF-8, UTF-16 and 40 random mixes. Options include Symbol and String keys,
  HashWithIndifferentAccess, a Hash subclass, frozen Hashes, nested `data`/`aria` Hashes, `class` Arrays with Hashes,
  `nil`/blank keys, `placeholder`, `index`, `namespace`, `multiple` and `include_hidden`. Builders cover Active Record
  (persisted, new from user input, invalid with errors), Active Model, nil, a namespaced subclass, and the object names
  `:post`, `"post"`, `post[comments_attributes][0]`, `admin/post`, `post[]`, `""` and `a b.c`.
  Every candidate except A and AM: byte-identical to main, run by run. A and AM: 1,053 and 1,047 lines differ, all of
  them the two AM boundaries above. The real diff (`sweep_recommended.patch`) differs from main in exactly AM's lines.
* `sweep_boundaries.rb`: overrides of `safe_join`, `tag`, `TagBuilder#tag_options`, `String#dasherize`, a Hash subclass's
  `merge`, wrong-arity `content_tag` calls and `Placeholderable#initialize`'s parameters. Output is identical
  everywhere. Which hooks get called changes as the table says (O, PH, AMT, HFT, DA, T2, TB).
* Rails test suites on the combined diff: Action View 2,967 + 251 + 177 runs, Active Model 1,269 runs, 0 failures
  (Action View on main: the same counts). A slip in the first application, where `String#sub` read `\1` in TR's
  replacement as a backreference, failed 5 Action View tests and changed 99 fuzz lines. Both checks catch that
  class of mistake. RuboCop: no offenses on the 9 files.

### Earlier rejections, reconsidered

* C12 and rails-common-paths.md rejected `field_id` (B) and `field_name` (C) as under the share bar, and as in-place
  editing with a singleton-`gsub` boundary. B doesn't edit in place: it skips the call, also for names with `_`
  (`line_item`), and saves 4 objects per field, not 2 (`gsub` without a match allocates 2). C still adds a branch for
  1 object per field. It is in PR 1 because it sits next to B and every builder field pays it.
* C12's `Errors#[]` early return was inexact because it skipped `normalize_arguments` for every attribute. AM guards on
  the attribute's class, which leaves only the invalid-UTF-8 raise and stateful singleton `to_sym`.
* PM2 (blank checks in `tag_options`): no allocation involved and no exact form. Not reopened.
* T2: exact output, 1 object per Array `class:`. The open question is the same as before: moving the `safe_join`
  override boundary.

### For Thomas

1. AM changes Active Model: a model without errors returns `[]` for an invalid-UTF-8 String attribute instead of
   raising `EncodingError`, and a String with a stateful singleton `to_sym` sees fewer calls. Fine as a bug fix?
2. C (field_name) and D (sanitized_method_name) each add a ternary for 1 object per field. Keep them in PR 1, or ship B
   alone (−4)?
3. O adds a `:nodoc:` method, `TagBuilder#append_tag_options`, and `tag()` stops calling `tag_options`. It goes after
   #59804, which edits the same line.
4. TB and T2 move a helper-override boundary (`safe_join`, `tag`) for 1 object each. Build them, or keep them parked?

## FB1 (#59824) wall time, 2026-11-17

`fb1_ips.rb` (the first body's benchmark-ips script) under YJIT, Ruby 4.0.7, pinned to one core, six rounds of main,
branch, main again: raw output in `fb1_ips_aa.txt`. Best of six, branch against main: `text_field` +7.7%, `checkbox`
+14.1%; main against main: +1.5% and +10.9%. Medians: +19.5% / +1.5% against an A/A of +9.5% / −0.1%. The orb's
wall time doesn't resolve this change, so the body shows objects per call (`fb1_alloc.rb`: 28 → 22, 32 → 26) and the
Callgrind instruction counts instead.

## Decisions, 2026-11-17 (Thomas)

* AM: built and opened as draft rails/rails#59832 (queue item AM1). The invalid-UTF-8 raise from discarded work is a
  bug, not a contract, so the body doesn't mention it. `am1_ips.rb`, `am1_objs.rb`, raw rounds with an A/A in
  `am1_ips_aa.txt`.
* O: kept for later as queue item TO1 (held), after #59804 merges.
* TB and T2: parked; they are the weakest candidates (1 object each for a moved override boundary).
