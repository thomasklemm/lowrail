# Action View rendering candidates and the SafeBuffer.new lead (C10, 2026-11-04)

A round for small, exact rails/rails candidates on the Action View rendering path (templates, partials,
collections, `tag`/`content_tag`/`tag_options`, `link_to`, form helpers, `t`, output buffer and SafeBuffer
handling), picked from the census data by CPU and allocations, plus a measured record of the String-subclass
`new` cost behind every `html_safe`. ActiveModel `resolve_attribute_name`, Journey `UriEncoder#escape` (C9) and
Active Record (C11) were left alone. Nothing was opened or posted.

**Result.** Two candidates, both in `TagBuilder#append_tag_option`, the method behind every attribute of
`tag.*`, `content_tag`, `tag()`, `link_to` and the form helpers. T1 is the stronger one.

| # | Branch @ SHA | Change | Per call |
| --- | --- | --- | --- |
| T1 | [`thomasklemm/tag-option-string-first`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-option-string-first) @ [`f02e21ddbb`](https://github.com/thomasklemm/rails/commit/f02e21ddbb65fed60b829da8fbdfda843d41d303) | a String attribute value takes its own `when String` branch first instead of passing four class checks before `else` | −5% to −6.6% instructions interpreted, −1.5% to −2.3% YJIT, −1.6% to −2.2% ZJIT for tags with String attributes; +1% for a Symbol or Integer value |
| T2 | [`thomasklemm/tag-option-array-join`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-option-array-join) @ [`6181372aa1`](https://github.com/thomasklemm/rails/commit/6181372aa16d4a36b85a63eb4c90cad6286f435c) | an Array attribute value is escaped and joined directly instead of through `safe_join`, whose SafeBuffer was only appended to a plain String | 13 → 11 objects, −10% to −11% instructions in every mode |

Both are one commit on rails/rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed7b9e3557979704a0a7aaa825200317),
authored and committed by Thomas Klemm. The SafeBuffer.new numbers are a lead only ([below](#lead-safebuffernew-misses-the-opt_new-fast-path)).

## Pins and method

* Rails main `9b116f1fed` (merge of #59405, 2026-11-04). Worktrees: `rails` (base), `rails-aa` (the same commit
  again, for the A/A), `rails-t1`, `rails-t2`. Bundles in `~/w/avb/VARIANT` load each worktree's actionview,
  actionpack, activesupport and activemodel.
* Ruby 4.0.9 (interpreter and `--yjit`); Ruby master
  [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb) built with
  `--enable-yjit --enable-zjit` (interpreter and `--zjit`), the census-8 4.1 pin.
* **Census apps:** `script/census setup --corpus censusc10 --rails rails/rails@9b116f1fed` for Blog, Campfire,
  Fizzy, Writebook and Lobsters (52 workloads); Redis as an orb service. Scripts run inside the copies through
  [`run_in_copy.rb`](../../bench/upstream/actionview_c10/run_in_copy.rb) with census's environment.
* **CPU ranking:** census 8's receipts (`rank-cpu409-*-line.tsv`, Rails `1105756f42`, 20 apps, 251 workloads).
  `append_tag_option`'s lines there are the same code as on `9b116f1fed` (only `tag_options`' blank-name check,
  99a3247ebc, moved lines).
* **Instructions per call:** Callgrind, `--collect-atstart=no --toggle-collect=rb_ary_cycle`, N = 3,000 calls inside
  `[0].cycle(1)` after 3,000 warmup calls, GC disabled; Ir per call = (Ir(N) − Ir(0)) / N
  ([`ir_variants.sh`](../../bench/upstream/actionview_c10/ir_variants.sh),
  [`tag_micro.rb`](../../bench/upstream/actionview_c10/tag_micro.rb)). JIT runs add `--smc-check=all`.
* **Wall time per call:** [`ns_variants.rb`](../../bench/upstream/actionview_c10/ns_variants.rb): one process per
  run pinned to one CPU, 20,000 warmup calls, 100,000 timed calls, GC on, 15 rounds with the variant order
  rotated, median.
* **Calls per request:** TracePoint counts after warmup
  ([`tag_value_count.rb`](../../bench/upstream/actionview_c10/tag_value_count.rb),
  [`safebuffer_count.rb`](../../bench/upstream/actionview_c10/safebuffer_count.rb)); wall time per operation is
  measured before the TracePoint is enabled.
* **ruby-bench:** ruby/ruby-bench `73918b2`, railsbench (Rails 8.1.1, whose `tag_option` has the same `case`).
  The harness [`lowrail_tagir.rb`](../../bench/upstream/actionview_c10/lowrail_tagir.rb) redefines `tag_option`
  in every variant (base, T1, T2), so all sides run the same redefined method; one iteration under Callgrind after
  warmup (interpreter 1, YJIT 10), GC disabled; base twice for the A/A ([`rb_ir.sh`](../../bench/upstream/actionview_c10/rb_ir.sh)).
* **Suites:** Action View `rake test` with `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, Ruby 4.0.9; RuboCop on the
  changed files.
* **Reviews:** codex is not installed in this orb, so each candidate got separate subagent reviews: a primary
  review on both rubrics, then an adversarial round that ran code to break identical behavior (both changes touch
  escaping, a critical area by DECISIONS). A further subagent read both PR bodies against this page.

## Where Action View's time goes now

Census 8's interpreted ranking for the rendering path, after the merged and open work (#59570 `OutputBuffer#<<`,
#59598 `URI_REGEXP`, #57999 attribute strings, V1's rejects): `xml_name_escape` (rank 8, rejected in V1),
`OutputBuffer#<<` (open #59570), `html_escape` (required), `asset_path` (merged #59598), `String#html_safe`
(rank 30) and `SafeBuffer#initialize` (rank 51) (the SafeBuffer lead below), then `tag_options` and
`append_tag_option`. The uncovered part of `append_tag_option` is its `case`:

| Census 8 line (pin `1105756f42`) | Code | Apps | Ir/op | % of all interpreted Ir |
| --- | --- | ---: | ---: | ---: |
| `tag_helper.rb:1635` | `when Array, Hash` | 18 | 91,971 | 0.154 |
| `tag_helper.rb:1638` | `when Regexp` | 17 | 44,784 | 0.075 |
| `tag_helper.rb:1640` | `when Symbol` | 18 | 44,296 | 0.074 |
| `tag_helper.rb:1643` | `else` body (`unwrapped_html_escape`) | 19 | 64,982 | 0.109 |

The three `when` lines are 0.30% of all interpreted instructions in the census and allocate nothing. Under YJIT
they are not in the ranking (the class checks compile to cheap guards); only the escape line is.

What attribute values are, per operation, in the five apps (`tag_value_count.rb`, 30 warmup operations, 5 counted):

| App | Workloads | Attribute values per op | Strings | Symbol | Array/Hash | Other |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Blog | 10 | 32.9 | 96.0% | 0.6 | 0.4 | 0.3 Integer |
| Campfire | 9 | 28.1 | 90.1% | 2.7 | 0 | 0.1 true |
| Fizzy | 14 | 300.4 | 94.9% | 4.0 | 0.2 | 10.4 true, 0.6 Integer |
| Lobsters | 11 | 330.4 | 94.7% | 0.6 | 10.4 | 6.6 Integer |
| Writebook | 8 | 124.2 | 98.5% | 1.9 | 0 | |

The most per page: Fizzy `GET board` 1,377 String values, Lobsters `GET active` 1,352.

## T1: check for String attribute values first

```diff
             case value
+            when String
+              value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s
             when Array, Hash
```

**Why it is exact.** The new branch's body is the `else` body. A String can't be an instance of Array, Hash,
Regexp or Symbol (four classes, no common subclass), so every String already reached `else`; only the number of
`Module#===` checks on the way changes (4 → 1 for Strings, +1 for everything else). `Module#===` calls nothing on
the value. A TracePoint diff of every `:call`/`:c_call` over 1,550 probes found no other difference.

**Search.** No rails/rails PR or issue changes this `case` (`gh search prs`: `append_tag_option`, `tag_options`,
`tag_option performance`, `content_tag performance`, `tag helper allocations`; open #57999 restructures the
appends but not the `case`; open #59499 and #56596 touch boolean attributes). History of the method: #26254
(2016, `gsub` with a String), 9276ea89d2 (2018), #59117 (append without a string per attribute), be594680cd
(Symbol branch, 2026-10-25), 99a3247ebc (blank names).

**Exactness checklist** (differential harness [`diff_tag.rb`](../../bench/upstream/actionview_c10/diff_tag.rb):
1,407 probes, 42 value kinds × 7 keys × escape on/off through `tag.div`, `tag.input`, `content_tag`, `tag()`,
`data:`, `aria:`, `tag.attributes`, `hidden:`, `link_to`, `text_field_tag`; interpreter and YJIT on 4.0.9,
interpreter and ZJIT on master, and YJIT/ZJIT at call threshold 1 with five repeats; identical on all):
1 singleton `to_s`/`html_safe?`, `extend`, prepended singleton modules, a `BasicObject` with `method_missing`:
same calls. 2 String subclasses overriding `to_s`, `to_str`, `html_safe?`, `include?`, `gsub`; SafeBuffers, unsafe
SafeBuffers, Array/Hash subclasses: same calls in the same order. 3 `to_ary`, `to_a`, `to_hash`, `to_str`-only
objects, private `to_s`: same counts. 4 no call added or skipped on a user object (TracePoint). 5 the String
branch runs the same expression, so copies are made as before. 6 a `to_s` that mutates itself or the options
Hash: identical. 7 frozen values, binary, Shift_JIS, UTF-16 and invalid UTF-8 values, raising `to_s`: same
results and exceptions. 8 no new constant or require.

**Accepted differences** (adversarial round; none without a global redefinition or a constant planted in Rails'
own namespace): redefining `String.===`, `Array.===`, `Hash.===` or `Regexp.===` changes which branch values take
(on base a String could be sent to the Array branch and raise; on T1 an Array subclass with an html_safe `to_s`
could be emitted raw if `String.===` is made to match it); a constant named `String` defined inside
`ActionView::Helpers` (or `TagHelper`, `TagBuilder`) is now consulted for every attribute, as it already is in
`tag_options`' `hidden:` check and 21 other places in the helpers. Refinements, threads with `GC.compact`,
redefinitions after JIT compilation, `ERB::Util` prepends before and after Active Support loads, and a non-main
Ractor calling `tag_options` directly were identical.

**Per call** (Ir; A/A is the same commit measured again):

| Call | Mode | main | A/A | T1 | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `tag.div("x", class: "card", id: "card_1")` | interpreter 4.0.9 | 34,329 | −0.27% | 32,550 | −5.2% |
| | YJIT 4.0.9 | 17,618 | −0.44% | 17,214 | −2.3% |
| | interpreter master | 32,997 | −0.30% | 31,298 | −5.1% |
| | ZJIT master | 18,977 | +0.22% | 18,682 | −1.6% |
| `content_tag(:a, "Post", href: "/posts/1", class: "btn btn-primary")` | interpreter 4.0.9 | 35,500 | −0.30% | 33,739 | −5.0% |
| | YJIT 4.0.9 | 20,267 | +0.15% | 19,957 | −1.5% |
| | interpreter master | 34,175 | +0.02% | 32,573 | −4.7% |
| | ZJIT master | 20,473 | −0.60% | 20,032 | −2.2% |
| `tag.input(type: "text", name: "q", value: "rails")` | interpreter 4.0.9 | 40,251 | +0.07% | 37,744 | −6.2% |
| | YJIT 4.0.9 | 21,405 | +0.07% | 20,929 | −2.2% |
| | interpreter master | 38,539 | −0.28% | 36,003 | −6.6% |
| | ZJIT master | 19,247 | +0.24% | 18,864 | −2.0% |
| `tag.div("x", dir: :ltr)` (Symbol, pays one more check) | interpreter 4.0.9 | 23,135 | 0.00% | 23,419 | +1.2% |
| | YJIT 4.0.9 | 11,836 | −0.11% | 11,898 | +0.5% |
| | interpreter master | 22,210 | −0.19% | 22,423 | +1.0% |
| | ZJIT master | 11,213 | −0.29% | 11,247 | +0.3% |
| `tag.div("x", tabindex: 0)` (Integer) | interpreter 4.0.9 | 24,153 | 0.00% | 24,445 | +1.2% |
| | interpreter master | 23,261 | −0.13% | 23,518 | +1.1% |
| | ZJIT master (two runs) | 12,123 / 12,069 | −0.45% / −0.22% | 12,048 / 12,049 | within A/A |

About 870 fewer instructions per String attribute interpreted, about 200 under YJIT and 150–200 under ZJIT;
about 290 more per Symbol or Integer attribute interpreted, 60 under YJIT. Objects per call are unchanged (4).

**Wall time per call** (pinned, 15 rotated rounds, medians):

| Call | Mode | main | A/A | T1 |
| --- | --- | ---: | ---: | ---: |
| `tag.div` with two String attributes | interpreter | 3,950 ns | +0.6% | 3,856 ns (−2.4%) |
| | YJIT | 2,224 ns | +1.1% | 2,190 ns (−1.5%) |
| `content_tag(:a, …)` | interpreter | 4,184 ns | +1.2% | 4,052 ns (−3.2%) |
| | YJIT | 2,637 ns | −1.2% | 2,619 ns (−0.7%) |
| `tag.input` with three String attributes | interpreter | 4,619 ns | −0.5% | 4,400 ns (−4.7%) |
| | YJIT | 2,740 ns | −0.3% | 2,673 ns (−2.4%) |
| `tag.div(dir: :ltr)` | interpreter | 2,636 ns | +0.6% | 2,675 ns (+1.5%) |
| | YJIT | 1,558 ns | +2.3% | 1,585 ns (+1.7%) |

Interpreted, the gain clears the A/A (about 45 ns per String attribute); under YJIT it is about the size of the
A/A except for `tag.input`.

**In the apps.** With ~95% of values Strings, the per-page saving interpreted is about 45 ns × String values:
Fizzy `GET board` 1,377 × 45 ns ≈ 62 µs of 63 ms (0.1%), Lobsters `GET active` 1,352 × 45 ns ≈ 61 µs of 44 ms
(0.14%). Census 8 puts the three `when` lines at 0.30% of all interpreted instructions; T1 removes about 95% of
those checks.

**ruby-bench:** railsbench interpreted −0.067% against an A/A of +0.013%, not resolved ([below](#ruby-bench)).

**Suites:** Action View `rake test` 2,945 + 251 + 177 runs, 0 failures, 0 errors, 0 skips on main and T1.
Removing the escape from the new branch fails 2 tests in `tag_helper_test.rb`, so the branch is covered.
RuboCop clean. **Readability:** L1 (a `when` that repeats the `else` line; the reason is in the commit message).

**Reviews.** Primary: correctness approve, maintainability approve (L1); no test needed, existing String
escaping tests cover the branch; optional nit: a short comment so a cleanup does not merge the branches again
(not taken: DECISIONS asks for no comments unless the code would be misread). Adversarial: approve, differences
as listed above.

## T2: join Array attribute values without a SafeBuffer

```diff
             when Array, Hash
               value = TagHelper.build_tag_values(value) if key == "class"
-              value = escape ? @view_context.safe_join(value, " ") : value.join(" ")
+              value = escape ? value.flatten.map! { |v| ERB::Util.unwrapped_html_escape(v) }.join(" ") : value.join(" ")
```

`safe_join(array, " ")` escapes the separator, flattens, escapes each element, joins and marks the result
html_safe. The result is then appended to `output`, which is always a plain `+""` (`tag_options`, `tag_option`,
`prefix_tag_option`), so the SafeBuffer is never needed. `token_list` in the same file already inlines
`safe_join` this way ("Inlined safe_join: the tokens are already a flat array"). A new test pins a nested Array
on a non-`class` attribute (the existing nested-Array tests only cover `class`, which flattens earlier in
`build_tag_values`); it fails if `flatten` is dropped.

**Search.** As T1, plus `safe_join` (#59114 `token_list`, merged; no PR changes the attribute join).

**Exactness checklist** (`diff_tag.rb`, the primary review's 217 + Hash probes, the adversarial round's
override set; all modes as T1): 1–3 Array/Hash subclasses overriding `flatten`, `map!`, `join`, `each`, `to_a`,
`to_ary`, a `flatten` that returns a non-Array, `method_missing`/private `to_ary`, `to_ary` returning nil or a
non-Array: same calls and errors. 4 skipped: the separator's escape (no user code; `CGI.escapeHTML(" ")` returns
the same frozen `" "`) and `.html_safe`, plus `SafeBuffer#include?`/`#gsub` instead of the String ones (the
SafeBuffer versions delegate to `to_str`). 5 `flatten` copies and `join` builds a new String, as before. 6 an
element whose `to_s` mutates the Array: identical (`flatten` copied first). 7 frozen and nested frozen Arrays,
recursive Arrays (`ArgumentError: tried to flatten recursive array`), mixed encodings, raising `to_s`: same class
and message. 8 `ERB::Util` is already required by the file.

**Accepted differences** (in the commit message): a view that overrides `safe_join` no longer sees Array
attribute values (the aria token path still calls it); an override of `ERB::Util.unwrapped_html_escape` no longer
sees the `" "` separator, so one that escapes spaces now leaves the separators as spaces (elements are still
escaped by it; spaces are safe inside a quoted attribute); prepends on `SafeBuffer#initialize`, `#include?`,
`#gsub` or `String#html_safe` no longer run for the joined value; a `TagBuilder` built on a context without
`safe_join` (nodoc constructor) now works instead of raising `NoMethodError`. No input or override made T2 emit
fewer escapes than base.

**Per call** (`tag.div("x", class: ["card", "card--active"])`; a String-only tag as the control):

| Mode | Objects main → T2 | Ir main | A/A | Ir T2 | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| interpreter 4.0.9 | 13 → 11 | 41,179 | −0.03% | 36,989 | −10.2% |
| YJIT 4.0.9 | | 22,257 | −0.13% | 19,778 | −11.1% |
| interpreter master | | 40,129 | −0.15% | 35,842 | −10.7% |
| ZJIT master | | 21,178 | −0.13% | 19,153 | −9.6% |
| control `tag.div("x", class: "card", id: "card_1")`, interpreter 4.0.9 | 4 → 4 | 34,344 | −0.13% | 34,346 | 0.0% |

Wall time: interpreter 5,300 → 4,750 ns (−10.4%, A/A −0.3%), YJIT 3,177 → 2,748 ns (−13.5%, A/A +1.1%).

**In the apps** it is narrow: Array or Hash values are 10.4 per operation on average in Lobsters and at most 0.4 in
the other four apps. Lobsters' home page joins about 50 through `safe_join` from `append_tag_option`, so about
50 × 550 ns ≈ 27 µs of a 44 ms page interpreted (0.06%).

**Suites:** Action View 2,946 + 251 + 177 runs, 0 failures, 0 errors (one test more than main). RuboCop clean.
**Readability:** L1 (`safe_join`'s body inlined in one line, as in `token_list`).

**Reviews.** Primary: correctness approve, maintainability approve-with-nits (L1); nit applied: the test now uses
an html_safe element with markup (`"<c>".html_safe`) so pass-through is pinned. Adversarial: approve; it added the
separator boundary above, which went into the commit message.

## ruby-bench

railsbench, interpreter, Ruby 4.0.9, instructions per iteration (Callgrind, one iteration after one warmup
iteration, GC disabled; `tag_option` redefined in every variant):

| Variant | Ir per iteration | Δ vs mean of base |
| --- | ---: | ---: |
| base, run 1 | 6,968.18 M | |
| base, run 2 | 6,969.07 M | A/A +0.013% |
| T1 | 6,963.98 M | −0.067% |
| T2 | 6,963.90 M | −0.068% |

Not resolved. A TracePoint count ([`lowrail_tagcount.rb`](../../bench/upstream/actionview_c10/lowrail_tagcount.rb))
shows railsbench's iteration renders 18,418 String and 3,687 Symbol attribute values and no Array or Hash value
(0 `safe_join` calls), so T2 cannot change its path; T2's −0.068% is run-to-run variation (railsbench reseeds its
database at start), which makes T1's −0.067% unresolved too. The expected T1 effect from the per-call numbers is
about 18,418 × 580 − 3,687 × 290 ≈ 9.6 M instructions (0.14%; on Rails 8.1 a String passes three checks, not
four). The YJIT runs were stopped after the base run (4,389.5 M per iteration): an effect that the interpreter
runs cannot resolve is smaller still under YJIT. erubi-rails renders no tag helpers, so T1 and T2 do not reach it.

## PR bodies (reviewed drafts)

A separate reviewer recomputed every number against this page and the diffs and read both bodies as an outsider
(verdict: ready after edits). Its edits are applied: boolean attributes excluded from "every attribute", every
non-String value named as paying the extra check, the other two T1 calls and the Symbol row's A/A stated, the
census pin described, the railsbench patching named, the app-level estimate added; for T2 the unsourced A/A object
count removed, the `token_list` comparison corrected (it still ends in `html_safe`), Hash values named, and the
Lobsters size fixed above. The links resolve once this page is on Lowrail main.

### T1: Check for String tag attribute values first

> Every attribute that `tag.*`, `content_tag`, `link_to` and the form helpers render, except boolean ones like `disabled`, goes through `TagBuilder#append_tag_option`. Its `case` tests each value against `Array`, `Hash`, `Regexp` and `Symbol` before reaching `else`, but 90–98% of the values are Strings in five open-source apps I measured. In a profile of 20 open-source apps on a recent Rails main, the three `when` lines were 0.3% of all instructions with the interpreter.
>
> This adds a `when String` branch first, with the same body as `else`. A String can't match any of the other classes, so every String took `else` before and is escaped the same way now; only the number of class checks changes. Every value that is not a String (a Symbol, Integer, `true`, Array, Hash or Regexp) pays one more check.
>
> | Per call | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT | Time, interpreter | Time, YJIT |
> | --- | ---: | ---: | ---: | ---: | ---: |
> | `tag.input(type: "text", name: "q", value: "rails")`, main | 40,251 | 21,405 | 19,247 | 4,619 ns | 2,740 ns |
> | this PR (change vs main) | 37,744 (−6.2%) | 20,929 (−2.2%) | 18,864 (−2.0%) | 4,400 ns (−4.7%) | 2,673 ns (−2.4%) |
> | main again (change vs first main run) | +0.07% | +0.07% | +0.24% | −0.5% | −0.3% |
> | `tag.div("x", dir: :ltr)`, a Symbol (change vs main) | +1.2% | +0.5% | +0.3% | +1.5% | +1.7% |
>
> (Ruby 4.0.9; ZJIT on Ruby master 9aa0898240; Callgrind instructions per call with GC off; times are medians of 15 pinned runs; [scripts](https://github.com/thomasklemm/lowrail/tree/main/bench/upstream/actionview_c10).) `tag.div` and `content_tag` with String attributes gain 5.0–5.2% interpreted and 1.5–2.3% under YJIT in instructions; their YJIT time is within the repeat-run difference, as is the Symbol call's except for interpreted instructions. In Fizzy and Lobsters, whose pages render about 1,350 String attributes, that is an estimated 60 µs of a 44–63 ms page interpreted (0.1%). On ruby-bench's railsbench (Rails 8.1.1 with this `case` patched in, interpreter, instructions per iteration) it is within noise. I found this in a CPU census of open-source Rails apps with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/actionview-render-c10.md)).

### T2: Join Array tag attribute values without a SafeBuffer

> When an attribute value is an Array or Hash (`class: ["btn", "btn-primary"]`, `rel: [...]`), `TagBuilder#append_tag_option` joins it with `safe_join`, which wraps the joined String in a new `ActiveSupport::SafeBuffer`. The attributes are built in a plain String, so that SafeBuffer is appended once and discarded.
>
> This escapes and joins the values directly, inlining `safe_join` the way `token_list` in the same file does, but without marking the result html_safe. Each value is escaped as before and html_safe values stay unescaped. Two things no longer happen for Array and Hash values: a view that overrides `safe_join` doesn't see them, and the `" "` separator, which escapes to itself, is no longer passed through `ERB::Util.unwrapped_html_escape`. The new test covers a nested Array on an attribute other than `class` (existing tests only cover `class`).
>
> | `tag.div("x", class: ["card", "card--active"])`, per call | Objects | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT | Time, interpreter | Time, YJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 13 | 41,179 | 22,257 | 21,178 | 5,300 ns | 3,177 ns |
> | this PR (change vs main) | 11 | 36,989 (−10.2%) | 19,778 (−11.1%) | 19,153 (−9.6%) | 4,750 ns (−10.4%) | 2,748 ns (−13.5%) |
> | main again (change vs first main run) | | −0.03% | −0.13% | −0.13% | −0.3% | +1.1% |
>
> (Ruby 4.0.9; ZJIT on Ruby master 9aa0898240; Callgrind instructions per call with GC off; times are medians of 15 pinned runs; [scripts](https://github.com/thomasklemm/lowrail/tree/main/bench/upstream/actionview_c10).) A tag with only String attributes is unchanged. ruby-bench's railsbench renders no Array attribute values, so it can't show this; of five open-source apps, Lobsters joins about 50 on its home page and the others under 1 per request, so the saving is tens of µs per page at most. I found this while counting where Action View creates SafeBuffers in those apps with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/actionview-render-c10.md)).

## Lead: SafeBuffer.new misses the opt_new fast path

`String` defines its own singleton `new` (`rb_str_s_new`), so `new` on any String subclass resolves to it instead
of `Class#new`, and `opt_new`'s fast path (allocate and call `#initialize` from the caller) doesn't apply in the
interpreter, YJIT or ZJIT. For a subclass, `rb_str_s_new` just calls `rb_class_new_instance_pass_kw`, so the cost
is the slow path plus an extra frame. `ActiveSupport::SafeBuffer` is a String subclass without its own `new`, and
every `String#html_safe` is `ActiveSupport::SafeBuffer.new(self)`. This is the case of our closed ruby/ruby#19667
(jhawthorn: not worth more complexity in `vm_exec_core`); byroot's merged ruby/ruby#19703 fixed only Hash
subclasses. Recorded as a lead; no ruby/ruby PR or issue (no new ruby/ruby PRs, DECISIONS).

**Per call** ([`safebuffer_new_micro.rb`](../../bench/upstream/actionview_c10/safebuffer_new_micro.rb): best of 7
× 1,000,000 calls, pinned; Callgrind Ir per call over 20,000 calls, two identical runs each). "Fast path" is a
SafeBuffer subclass whose singleton `new` is `Class#new`, the cost `new` would have with `opt_new`:

| Mode | `"x".html_safe` | `SafeBuffer.new("x")` | fast path | extra per call |
| --- | ---: | ---: | ---: | ---: |
| interpreter 4.0.9 | 242 ns / 2,487 Ir | 226 ns / 2,334 Ir | 150 ns / 1,570 Ir | 77 ns / 764 Ir |
| YJIT 4.0.9 | 170 ns / 1,718 Ir | 167 ns / 1,683 Ir | 95 ns / 938 Ir | 73 ns / 745 Ir |
| interpreter master | 231 ns / 2,508 Ir | 212 ns / 2,342 Ir | 126 ns / 1,567 Ir | 86 ns / 775 Ir |
| ZJIT master | 152 ns / 1,760 Ir | 147 ns / 1,736 Ir | 78 ns / 944 Ir | 69 ns / 792 Ir |

(The coordinator's earlier figures, 220 vs 134 ns interpreted and 146 vs 69 ns under YJIT, were on master
`aa26cc7114` with Active Support 8.1.4.1; same picture.)

**How often per request** (`safebuffer_count.rb`: TracePoint on `SafeBuffer#initialize`, 200 warmup operations,
10 counted; wall time per operation before the TracePoint, median of 5 windows of 20; interpreter and YJIT on
4.0.9). Share = SafeBuffers × the extra cost above (77 ns interpreted, 73 ns YJIT) / wall time per operation:

| App | Workloads (with any) | SafeBuffer.new per op, mean (max) | share interp / YJIT, mean (max) |
| --- | ---: | ---: | ---: |
| Blog | 10 (6) | 22.1 (56) | 0.05% / 0.10% (0.13% / 0.23%) |
| Campfire | 9 (3) | 13.3 (57) | 0.01% / 0.01% (0.02% / 0.04%) |
| Fizzy | 14 (8) | 151.0 (698) | 0.04% / 0.07% (0.18% / 0.34%) |
| Lobsters | 11 (7) | 160.6 (660) | 0.03% / 0.06% (0.11% / 0.20%) |
| Writebook | 8 (8) | 72.5 (166) | 0.06% / 0.11% (0.12% / 0.19%) |

On HTML pages: Blog 43–56 per page (0.11–0.13% interpreted, 0.21–0.23% YJIT), Fizzy 325–698 (0.08–0.18% /
0.15–0.34%), Lobsters 104–660 (0.05–0.11% / 0.09–0.20%), Writebook 101–166 (0.07–0.12% / 0.15–0.19%); Campfire's
three pages make none (their HTML comes from fragment caches). JSON, job and redirect workloads make almost none.
So the String-subclass `new` costs about 0.1–0.3% of an HTML page with YJIT, and a fix would save that.

**Who makes them** (mean per operation over the 52 workloads): `content_tag_string` 28.3, `tag()` 17.4,
`self_closing_tag_string` 12.4, `OutputBuffer#capture` 8.3, `safe_join` 5.7, `stylesheet_link_tag` 5.5,
`OutputBuffer#to_s` 4.0, `token_list` 3.7; all others below 1.2. 97% come from `String#html_safe`; the direct
`SafeBuffer.new` calls are `OutputFlow`'s (1.3 per op).

**Avoidable SafeBuffers in Rails** (the Rails-candidate half of the question):

* Already-safe arguments are rare: 0.8–4.0 per operation (of 13–161). They are `ActionView::Context#_layout_for`
  (`view_flow.get(name).html_safe` on a SafeBuffer, 1.15 per op) and `OutputFlow#set` re-wrapping a SafeBuffer
  (0.35). Returning `self` from `SafeBuffer#html_safe` was rejected in #17250 (2014: `html_safe` is expected to
  return a new object). Not built: about 100 ns per page.
* SafeBuffers built only to be joined or appended: `append_tag_option`'s `safe_join` (T2); `stylesheet_link_tag`
  makes one per `<link>` and then joins them (Fizzy 65 per page via propshaft's `:app`, about 15 µs of 63 ms;
  avoiding it needs a private path around `tag`, L2); `form_tag_with_body` wraps `safe_join([extra_tags, content])`
  only to pass it to `content_tag` (one per form, Lobsters 50 per page). Not built: below 0.03% of a page each.
* A Rails-side workaround (`SafeBuffer.singleton_class` binding `Class#new`) would recover the 70–85 ns everywhere
  but needs a comment to be understood (L3), changes refinement and visibility behavior the way #19667 described,
  and is the JIT's/VM's job by tenderlove's rule on Feature #22459. Not built.

## Rejected and not built

| Site | Numbers | Why not |
| --- | --- | --- |
| `ControllerHelper#respond_to?`: frozen Set for `CONTROLLER_DELEGATES.include?` (census 8 method rank 80, 0.14% interpreted / 0.15% YJIT) | `view.respond_to?(:config)` 224 → 180 ns interpreted, 131 → 100 ns YJIT; 2–110 calls per op (`:config`, `:request`, `:response`) | ≤ 5 µs of a 20 ms page (≤ 0.02%); a second constant (L1) and `Set#include?` compares by `hash`/`eql?` where `Array#include?` uses `==`, which a `to_sym` returning a non-Symbol could tell apart. |
| `_layout_for`/`OutputFlow#set` re-wrapping SafeBuffers, `stylesheet_link_tag`, `form_tag_with_body` | above | Below 0.03% of a page each, or L2. |
| `xml_name_escape`, `ensure_valid_html5_tag_name`, `prepend_formats`, `_all_renderers`, `safe_concat`, `view_assigns` | [actionview-cpu](actionview-cpu.md) | V1's dispositions unchanged. |
| `OutputBuffer#<<` escape path, `URI_REGEXP`, tag attribute strings, `capture(*)` | | Open #59570, merged #59598, open #57999, rejected R2-4 ([common paths](rails-common-paths.md)). |
| Collection and partial rendering, `t`, `link_to`/`url_for` | census 8 ranks ≥ 500 for `render_partial_template`, `optimize_routes_generation?`; route generation reworked by #59470/#59479 | Nothing exact above the bar on these lines. |

## Limits

* Five SQLite/Redis census apps for the per-request counts, not all 20; the CPU ranking is census 8's 20 apps on
  Rails `1105756f42`.
* Instruction and wall-time numbers are per call; page shares are estimates from per-call costs × counts.
* Reviews were subagents, not the Sol/Astra Thermos reviews DECISIONS names (codex is not installed here).
* Raw outputs (differential runs, counts, Callgrind logs) are in the orb's `.lowrail/private/c10` and `/tmp/c10`,
  not checked in.
