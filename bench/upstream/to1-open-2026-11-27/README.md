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

## Timing on head 18fd3c4a07 (2026-11-27, a1.xxlarge)

Base Rails main `2e299253f9`, head `18fd3c4a07`. Ruby 4.0.10 (mise) for the interpreter and YJIT; Ruby master
`0d399335b7` (`--enable-zjit --enable-yjit optflags=-O3`, `zjit_gap_bet/setup.sh ruby`) for ZJIT.

### Per call (`script/upstream-bench`, script [`to1_body.rb`](to1_body.rb))

[`body/TO1`](body/TO1): objects and Callgrind interp/YJIT plus `--ips 3` (YJIT), all on 4.0.10.
[`body/TO1-wall-yjit`](body/TO1-wall-yjit) and [`body/TO1-wall-zjit`](body/TO1-wall-zjit): `--modes "" --wall 30`.
Raw output in each `raw.tar.gz`. Every JIT window was flat (6 Callgrind windows, 9 ips reports, 90 wall processes per
case). Callgrind A/A in brackets; wall cells are change [95%] with the A/A [95%] below.

| | Objects interp | Objects YJIT | Ir interp | Ir YJIT | ips YJIT (A/A) | Wall YJIT 4.0.10 | Wall ZJIT master |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| `text_field_tag` | 7 → 6 | 7 → 6 | −0.7% (0.07%) | −1.7% (0.41%) | +6.2% (2.5%) | −2.5% [−3.3, −2.0]; A/A +0.4% [−0.7, +1.0] | −2.4% [−2.7, −2.1]; A/A +0.2% [−0.4, +0.5] |
| `hidden_field_tag` | 9 → 8 | 9 → 8 | −0.6% (0.05%) | −1.1% (0.14%) | +2.5% (0.4%) | −2.2% [−2.6, −1.5]; A/A +0.3% [−0.3, +0.8] | −0.6% [−1.7, −0.2]; A/A +0.0% [−0.3, +0.5] |
| `submit_tag` | 13 → 12 | 13 → 12 | −0.6% (0.04%) | −1.8% (0.09%) | +4.8% (0.3%) | −2.2% [−2.7, −1.6]; A/A +0.4% [−0.2, +1.1] | −1.5% [−2.1, −1.1]; A/A −0.2% [−1.0, +0.4] |
| `tag.input` | 4 → 3 | 4 → 3 | −1.5% (0.06%) | −4.1% (0.44%) | +5.7% (0.1%) | −5.7% [−6.3, −4.8]; A/A +0.2% [−0.2, +1.1] | −4.1% [−4.3, −3.5]; A/A −0.2% [−1.1, +0.6] |
| `image_tag` | 8 → 7 | 8 → 7 | −0.7% (0.01%) | −1.4% (0.60%) | +2.6% (1.8%) | −1.5% [−2.0, −0.7]; A/A +0.5% [−0.4, +1.0] | −2.1% [−2.8, −1.6]; A/A −0.1% [−1.1, +0.6] |
| `f.text_field` | 17 → 16 | 18 → 17 | **+0.6%** (0.03%) | within noise (−0.5%, A/A 0.69%) | **−1.5%** (0.2%) | −0.2% [−1.0, +0.7], no claim; A/A +0.3% [−0.5, +0.9] | +0.4% [−0.4, +0.9], no claim; A/A +0.5% [−0.2, +0.9] |
| `f.check_box` | 20 → 18 | 22 → 20 | −0.6% (0.12%) | −1.1% (0.01%) | +1.9% (1.7%) | −1.7% [−2.2, −0.6]; A/A +0.0% [−0.9, +1.0] | −1.5% [−1.9, −0.8]; A/A −0.0% [−0.8, +0.5] |

`f.text_field` saves its object but costs 640 interpreter instructions more per call (+0.6%, 20× its A/A), and
benchmark-ips under YJIT has it −1.5% slower (A/A 0.2%); both wall cohorts put it inside noise. Not explained here.
`image_tag` and `f.check_box` ips gains are about their A/A; the wall cohorts are the time numbers to use.

### Page level (`script/census`, corpus `censusto1`)

Apps set up with `script/census setup --corpus censusto1 --rails rails/rails@2e299253f942… --ruby 4.0.10
--ruby-overlays fixtures/corpus/frontier-master`; CASA set up without trouble (PostgreSQL 17 local), so no pingcrm.
Head as `--rails thomasklemm/rails@18fd3c4a07`; dependencies outside Rails matched the base lock in every run.

**Objects per request** ([`page/objects.sh`](page/objects.sh), `run --aa --only`, `page/objects-raw.tar.gz`,
[`objects-table.txt`](page/objects-table.txt)): median GC-enabled objects per request, main / main again → TO1.

| page | mode | main (A/A) | TO1 | Δ per request |
| --- | --- | ---: | ---: | ---: |
| blog `GET article` | interp 4.0.10 | 1,941.6 / 1,940.8 | 1,920.1 | −21.1 (−1.1%) |
| | YJIT 4.0.10 | 1,947.8 / 1,950.8 | 1,927.6 | −21.8 (−1.1%) |
| | ZJIT master | 1,922.6 / 1,924.6 | 1,899.0 | −24.5 (−1.3%) |
| writebook `GET books` | interp 4.0.10 | 4,355.1 / 4,354.5 | 4,286.1 | −68.7 (−1.6%) |
| | YJIT 4.0.10 | 4,369.1 / 4,369.2 | 4,300.9 | −68.2 (−1.6%) |
| | ZJIT master | 4,363.8 / 4,365.9 | 4,294.2 | −70.7 (−1.6%) |
| casa `GET casa case edit` | interp 4.0.10 | 22,566.2 / 22,565.7 | 22,512.8 | −53.2 (−0.2%) |
| | YJIT 4.0.10 | 22,779.4 / 22,781.5 | 22,726.7 | −53.8 (−0.2%) |
| | ZJIT master | 22,382.1 / 22,386.1 | 22,333.2 | −50.9 (−0.2%) |

**Wall time per request** ([`page/wall_lane.sh`](page/wall_lane.sh), [`page/wall_table.rb`](page/wall_table.rb),
`page/wall-raw.tar.gz`, [`wall-table.md`](page/wall-table.md)): census-3's method. 30 rounds per page and mode, a
round being three fresh `script/census run --wall --only PAGE` processes (main a, TO1 h, main b) in the six orders in
turn, one lane per page and mode, each pinned to its own physical core. GC on, `RUBY_GC_HEAP_INIT_BYTES=32 MiB`;
windows of 25 (blog), 15 (writebook) or 3 (casa) requests, 80/80/150 warm windows, 20 timed. Per process the mean of
its JIT-flat timed windows; change = TO1 / mean(main a, b), A/A = a / b, geometric means with 95% bootstrap intervals
over rounds. Counts only with an A/A interval containing 0 and a change interval excluding 0.

| page | mode | main ms | TO1 ms | change [95%] | A/A [95%] | flat windows main, TO1 | verdict |
| --- | --- | ---: | ---: | --- | --- | --- | --- |
| blog `GET article` | YJIT 4.0.10 | 1.753 | 1.746 | −0.4% [−1.8, +0.9] | −1.2% [−3.6, +0.7] | 1200/1200, 600/600 | inside noise |
| | ZJIT master | 1.850 | 1.857 | +0.4% [−1.1, +1.8] | +1.2% [+0.2, +2.3] | 1200/1200, 600/600 | A/A excludes 0, no claim |
| writebook `GET books` | YJIT 4.0.10 | 4.073 | 3.976 | −2.4% [−4.3, −0.4] | −2.6% [−5.7, +0.1] | 1125/1200, 568/600 | passes the rule, but see below |
| | ZJIT master | 3.533 | 3.525 | −0.2% [−1.2, +0.7] | −0.4% [−1.7, +0.6] | 1180/1200, 593/600 | inside noise |
| casa `GET casa case edit` | YJIT 4.0.10 | – | – | – | – | – | not run: never JIT-flat |
| | ZJIT master | 33.746 | 33.893 | +0.4% [−1.5, +2.2] | +0.2% [−1.9, +2.3] | 1154/1200, 576/600 | inside noise |

* Writebook under YJIT technically passes (A/A upper bound +0.1%, change upper bound −0.4%), but the A/A point
  (−2.6%) is as large as the change (−2.4%) and the object saving is 1.6% of the request at an 18.6% GC share. Treat
  it as noise, not a page-level win.
* CASA under YJIT 4.0.10 invalidates about one block per request forever: a probe with 500 warm windows
  (`page/wall/casa-yjit-counters-probe.json.gz`, inside the archive) shows `compiled_iseq_count` settled at 4,540 by
  window ~100 while `invalidation_count` and `compiled_block_count` rise by 3 every 3-request window to the end. No
  window passes the gate, so the cohort was stopped after its first round and is not reported.
* Three Writebook processes (yjit r01-a and r27-h, zjit r23-a) crashed at workload setup
  (`census_4_workloads.rb:107`, a leaf without its leafable left by a concurrent process) and were rerun alone; their
  logs are kept as `*.crashed.log`.
* Under the size of these pages the saving (21–71 objects per request, ≤ 1.6%) is below what the wall cohort resolves
  (about ±1–2% here). No page shows a time change.

Harness fix (separate commit): `wall()` ignored `CENSUS_ONLY`, so `--wall --only` timed every workload, and it called
`RubyVM::ZJIT.enabled?`, which raises on 4.0.10; both fixed before these runs.

## The f.text_field instructions (2026-11-27)

Unparked by the coordinator: per-call wall time under both JITs counts as measurable. Before review, the
`f.text_field` +0.6% interpreter instructions (body/TO1, title "Hello") and ips −1.5% were checked
(`ftf/`, Ruby 4.0.10, interpreter, Callgrind, N = 2,000 or 1,000, GC off, raw in `ftf/raw.tar.gz`).

* Same helper, other inputs (`ftf_ir.rb`, `ir_cases.tsv`, main / head / main again): `f.text_field` with title
  "Hello world" 94,793 / 94,192 / 94,564 (−0.5%); with class, placeholder and autocomplete 137,055 / 136,182 /
  137,074 (−0.6%); with a data Hash 170,746 / 170,272 / 170,719 (−0.3%); a 200-character value 91,063 / 90,541 /
  91,116 (−0.6%). `text_field_tag` −0.7%, `tag.input` with 5 attributes −1.0%.
* Title length sweep 1 to 39 (`ftf_sweep.rb`, `sweep_table.tsv`, one run per tree): lengths 1–7 cost +0.08% to
  +0.16% (about 100 instructions); every length from 9 up saves 0.2% to 1.0%. Main's own run-to-run spread here is
  about 0.2%.

So the cost is not on the path but on the output length: the tag's String grows from `"<input"` in Ruby's capacity
steps, and for some short totals it needs one more `realloc` than main's separate attribute String did (the lead
sweep's function diff, `lead-sweep-2026-11-27/results/to1_zjit_fn_diff.txt`, puts it in malloc/realloc). The worst
case seen is the body's +640 instructions (about 0.1 µs); the wall cohorts on the same input are −0.2% [−1.0, +0.7]
under YJIT and +0.4% [−0.4, +0.9] under ZJIT, so no time loss is claimed in either mode. Not a regression on the
form builder path. The body leaves `f.text_field` out.

## Astra on 18fd3c4a07: a new difference, stopped (2026-11-27)

Astra (thread T-01a21f5c-aafb-73e1-9bee-b1c0c78193f7; evidence `astra/review-evidence-18fd3c4a07.tar.gz`): not exact.
One new difference without any override, reproduced here (`astra2_check.rb`, `results/head-18fd3c4a07/astra2_check.txt`):
an attribute value that is invalid US-ASCII (`"é".dup.force_encoding("US-ASCII")`) gives `tag(:input, id: value)` and
`tag.input(id: value)` a valid UTF-8 result on main and an invalid US-ASCII result on the head, which raises
`Encoding::InvalidByteSequenceError` when transcoded. The bytes are the same. Main interpolates into a UTF-8 literal;
the head appends to `"<input"`, which is 7-bit, so the String takes the appended value's encoding. This is neither of
Thomas's two accepted cases, and the coordinator's brief says to stop on any other difference.

Also from that pass (`:nodoc:` override boundaries): a `tag_options` prepend whose return value replaces the
attributes, or one that freezes it, no longer works for `tag()` and void elements (the head discards or appends to
it). Gone on this head: the frozen-view error and both custom elements.

Body findings, for a later attempt: say "time per call" (the cohort measures thread CPU time with GC off), the
article page is 1,941 to 1,920, and "returns a new String as before" also has to allow for nil. All ten timing
percentages and the page objects recompute from the raw data. thermos-sol was stopped before its verdict.
