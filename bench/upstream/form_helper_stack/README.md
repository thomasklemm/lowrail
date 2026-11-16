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
