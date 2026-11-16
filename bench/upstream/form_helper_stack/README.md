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
