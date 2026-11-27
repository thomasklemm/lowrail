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
