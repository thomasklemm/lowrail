# TO1 unheld: rebase, shape, reach, exactness (2026-11-27)

Thomas unheld TO1 (relevance). This record covers the rebase, the simplified shape, the helpers it reaches, the
exactness work and the page-level measurement.

## Rebase and shape

Rebased onto rails/rails main `2e299253f9`: head `be8139e150` on `thomasklemm/tag-attributes-own-string`, one commit,
Thomas as author and committer, no trailers, lease-pushed over `7f1f0dce45`.

The old head had the same four lines (`+"<#{name}"`, append, suffix, `freeze.html_safe`) twice: once in
`self_closing_tag_string` and once in `tag()`. DECISIONS' "Fix the shared helper" rules out that copy. The new head
makes `self_closing_tag_string` a `:nodoc:` public method next to `content_tag_string`, and `tag()` calls it the way
`content_tag` calls `content_tag_string`. Two pieces remain: `append_tag_options` (the loop that used to be the body of
`tag_options`), which `tag_options` now wraps, and the one helper that writes void tags. Diff: +13/−6, one file.

Plain sentences: `tag_options` makes an empty String, appends the attributes, and returns it unless it stayed empty.
`append_tag_options` appends each attribute to the String it is given. `self_closing_tag_string` starts the tag's
String with `<name`, appends the attributes unless there are none, appends the suffix and returns it frozen as a
SafeBuffer. `tag()` calls `self_closing_tag_string` with `>` or ` />`.

## Conflicts with open PRs on tag_helper.rb

`git merge-tree` of each open PR against main and against the head gives the same conflicted files and the same
number of conflict hunks in tag_helper.rb. TO1 adds no conflict that main doesn't already have:

| PR | conflicted files vs main = vs head | tag_helper.rb hunks main / head |
| --- | --- | --- |
| #59499 popover | CHANGELOG only | 0 / 0 |
| #56596 non-boolean boolean attributes | tag_helper.rb, its test | 1 / 1, identical hunk text |
| #47163 token-list aware attributes | 5 files | 2 / 2, identical hunk text |
| #51646 void trailing slash | 21 files | 7 / 7 |
| #57999 intermediate strings | tag_helper.rb | 6 / 6 |
| #54042, #49377, #47159, #45236 | already conflicting | 2/2, 1/1, 1/1, 6/6 |

## Reach: which helpers take the changed path

Every `tag(name, options)` call and every void `tag.*` element with attributes (`tag.input`, `tag.img`, `tag.br`,
`tag.meta`, `tag.link`, `tag.source` …) saves one String. In Action View (main `2e299253f9`):

* form tag helpers: `text_field_tag` and everything built on it (`hidden_field_tag`, `password_field_tag`,
  `email_field_tag`, `search_field_tag`, `number_field_tag`, date and time fields, `file_field_tag` …),
  `check_box_tag`, `radio_button_tag`, `submit_tag`, `image_submit_tag`, and `form_tag` without a block (the
  opening `<form>`);
* the hidden inputs every form and `button_to` adds (`token_tag`, `method_tag`, `utf8_enforcer_tag`), and the
  `button_to` input;
* form builder fields: `f.text_field` and the other input fields (`Tags::TextField`: password, hidden, email,
  number, date …), `f.check_box` (box and hidden input), `f.radio_button`, `f.file_field`, the hidden input of
  `f.select` with `multiple` or `include_hidden`, and the hidden fields of `date_select`/`time_select`;
* asset helpers: `image_tag`, `stylesheet_link_tag`, `favicon_link_tag`, `auto_discovery_link_tag`,
  `preload_link_tag` (`tag.link`), `picture_tag` and video/audio `<source>` tags;
* `csrf_meta_tags` (two `<meta>`), `csp_meta_tag`.

Not reached: `content_tag`, `tag.div` and other elements with content, `label`, `text_area`, `select`/`option`,
`javascript_include_tag`, `link_to`, `form_with` with a block (its `<form>` is a `content_tag`).

## Exactness

* `to1_probe.rb` (new): 13,487 cases over `tag()` (names, nil/false/""/Array/String options, open, escape),
  `tag.input/br/img/path`, `tag.attributes`, `content_tag`, every `*_tag` form helper, `image_tag`, the asset and
  CSRF/CSP helpers, `form_tag`, `button_to`, `select_hour`; options cover attribute order (Symbol and String keys
  mixed and duplicated), escaping of keys and values, data/aria Hashes (nested, nil, blank keys, Arrays, BigDecimal,
  to_json duck), booleans and `hidden: "until-found"`, nil values, Regexp, Set, String subclasses with own `to_s`,
  Hash subclasses with own `each_pair`, HWIA, frozen Hashes, compare_by_identity, mixed and invalid encodings
  (binary, UTF-16LE, invalid UTF-8), a `to_s` that raises before and after other attributes, and long values. Each
  line prints the result's class, frozen?, html_safe?, encoding and content, or the exception, plus every `to_s`,
  `to_json` and `each_pair` call on user objects in order. Main and head: byte-identical
  (`results/equivalence_sha256.txt`, head output `results/probe_head.txt.gz`). Results are fresh unfrozen
  SafeBuffers in both.
* `form_helper_stack/sweep_fuzz.rb`: 86,726 lines, byte-identical.
* `form_helper_stack/sweep_boundaries.rb` (`results/boundaries_diff.txt`): the one known boundary, an override of
  `TagBuilder#tag_options` (`:nodoc:`) no longer sees `tag()` and void elements; output unchanged. DECISIONS
  accepts overrides of nodoc methods.
* Checklist: (1) singleton/prepend on user values: values go through the same `append_tag_option` as before, same
  call order (probe logs); (2) Hash/String subclasses: probed; (3) implicit conversions: `to_s`/`to_json` counts
  identical; (4) calls added on user objects: none (`options.blank?` was already called by `tag_options`); skipped:
  none; (5) no user result adopted as accumulator: the accumulator is the literal `+"<#{name}"`; (6) mutation during
  iteration: same `each_pair` loop; (7) frozen options and frozen result: probed, result frozen buffer shared as
  before; exception classes and messages identical; (8) load order: same file, no new require.
* Action View `rake test` on Ruby 4.0.10: main and head both 2,984 + 252 + 177 runs, 0 failures
  (`results/av_main.txt`, `results/av_head.txt`).

## Astra: not exact (2026-11-27), stopped

Astra (`openai/gpt-6-astra`, thread T-01a21f0d-5484-77aa-89c4-29131c0e3f58) on `be8139e150`: changes / not exact.
Evidence bundle: `astra/review-evidence.tar.gz`. Its four public-API repros, rerun here on main, the old head
`7f1f0dce45` and `be8139e150` (`astra_check.rb`, `results/astra_check.txt`):

| Repro | main | old head | new head | Cause |
| --- | --- | --- | --- | --- |
| 1 `tag(:br)` on a frozen view, nil options | `<br />` | `<br />` | FrozenError (memoizes `@tag_builder`) | the simplification |
| 2 an attribute's `to_s` mutates the tag name String | `<br id="value" />` | `<input …>` | `<input …>` | the approach: the name is copied before the attributes run |
| 3 invalid-encoding attribute before one whose `to_s` raises | RuntimeError from the later `to_s` | Encoding::CompatibilityError | same | the approach: encodings meet the name during the loop |
| 4a `tag.self_closing_tag_string(...)` custom element | custom element | custom element | `<text id="a" />` | the simplification (method made public) |
| 4b `tag.append_tag_options(...)` custom element | custom element | ArgumentError | ArgumentError | the approach (public helper on TagBuilder) |

1 and 4a could be undone by going back to the old shape. 2 and 3 can't without giving up the change: the tag's own
String has to start with the name before the attributes are evaluated. Both need contrived inputs (aliasing the name
from an attribute's `to_s`, a failing mixed-encoding tag), but they fall under exactness checklist items 6 and 7, and
the brief said to stop on a "not exact" verdict. Astra also judged the change worth pursuing in principle and
corrected the reach list: `select`'s hidden input needs `multiple` and `include_hidden`, `button_to`'s submit input
depends on configuration, and `form_with`'s hidden inputs gain while its `<form>` doesn't.

The a1.xxlarge timing run (T-01a21f0c-fbe0-77e6-9af2-3a4d79a2adde) was stopped before any per-call or page result,
so there are no page-level numbers. The fork branch stays at `be8139e150`, and nothing was posted.

thermos-sol (`openai/gpt-6.1-sol` xhigh, thread T-01a21f0d-28ca-7638-ad49-8af4c8d3f393) on the same head: not exact,
hold. Its own 6,256-case probe reproduced repros 2 and 3 (also with a Fiber suspended in the name-mutating `to_s`),
the frozen-view FrozenError and both custom-element collisions. The maintainability side approved the shape (L1, no
duplicated serialization or one-tag fast path) and would make `append_tag_options` private. That fixes 4b but not 2
or 3. Its objects check matched ours: one object fewer per tag with attributes, a cold `tag(:br)` on a fresh helper
instance 3 → 4 (the memoized builder), warm `tag(:br)` unchanged. It also says the commit sentence "The returned
buffer is unchanged" is too broad. Its correctness subreviewer was blocked by the provider, and it finished that
rubric itself in the thread.

Outcome: held. Both reviewers judged the reach big enough for a PR if the change were exact. An exact form would have
to evaluate every attribute before the tag's String exists, which is what main already does, so there is no exact
variant left with the saving. Opening it as is needs Thomas to accept repros 2 and 3 as outside the contract.

## Thomas accepts 1 and 2; head 18fd3c4a07 (2026-11-27)

Thomas (2026-11-27) accepts differences 2 and 3 of the Astra table above (an attribute's `to_s` that mutates the
tag-name String; the earlier `Encoding::CompatibilityError` when the name and a value have incompatible encodings) as
outside the contract. They stay out of the PR body and are recorded only here and in the item.

The new head `18fd3c4a07` (lease-pushed over `be8139e150`) removes the frozen-view and custom-element differences by
adding no public method to TagBuilder: `tag_options` takes an optional third argument, the String to append to, and
`tag()` keeps main's `if options` guard. `self_closing_tag_string` stays private and writes into its own String the
same way. Diff +11/−4.

* `astra_check.rb` (`results/head-18fd3c4a07/astra.txt`): frozen `tag(:br)` renders `<br />`, and both custom elements
  render as on main. Only the two accepted differences remain.
* `to1_probe.rb` and `sweep_fuzz.rb` byte-identical to main (`equivalence_sha256.txt`); Action View 2,984 + 252 + 177
  runs, 0 failures on Ruby 4.0.10.
* Overrides: `tag_options` prepends that forward with `...` or `*` now see `tag()` and void elements again, with the
  same output as main. That matters for turbo_boost-commands 0.3.2 (40k downloads), whose TagBuilder patch is
  `tag_options(options, ...)`: under the earlier heads its attributes vanished from `tag()`, `tag.input`,
  `text_field_tag` and `image_tag` (`turbo_boost_prepend.rb`, `results/head-18fd3c4a07/turbo_boost_prepend.txt`).
  A prepend with exactly `(options, escape = true)` now raises ArgumentError on `tag()` and void tags
  (`boundaries_diff.txt`). The only such override in a GitHub code search for `def tag_options` is green_monkey
  (last push 2017, an `alias_method` on the Rails 3 API). Overrides of `:nodoc:` methods are an accepted boundary.
* Objects per call (Ruby 4.0.10, interpreter): text_field_tag 8 → 7, submit_tag 14 → 13, tag.input 6 → 5,
  image_tag 9 → 8, f.text_field 17 → 16, f.check_box 20 → 18; `tag(:br)` and `content_tag` unchanged.
