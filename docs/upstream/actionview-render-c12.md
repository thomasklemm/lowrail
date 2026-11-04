# Action View rendering pipeline beyond tag helpers (C12, 2026-11-04)

A round for small, exact rails/rails candidates in the rest of the rendering pipeline: template and partial
lookup (resolver, `PathSet`, details keys, the template cache), collection and `render partial:` rendering,
compiled-method dispatch, `OutputBuffer`/SafeBuffer appends outside open #59570, form builders and
`fields_for`, `t`, and the Active Model validations and serialization that views trigger. Tag options (C10) were
left alone. Nothing was built, opened or posted.

**Result: no candidate.** Every site in scope either costs less than 0.03% of the census's interpreted
instructions, was reworked on main in the last two months, or was already ruled out. The best exact rewrites
found would save about 0.01–0.015% of instructions. That is well below the gain ruby/ruby#19488 was closed for
(about 0.07%) and below what made CP-1/CP-2 easy to accept (3.5 µs on every request).

## Pins and method

* Rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed7b9e3557979704a0a7aaa825200317)
  (unchanged since C10). Ruby 4.0.9, interpreter and YJIT.
* CPU ranking: census 8 (20 apps, Rails `1105756f42`), `rank-cpu409-{interpreter,yjit}-{line,method}.tsv`.
  "Objects/op" is objects allocated on the line per app operation (request or job), not per call.
* History: `git log` on each file in scope since 2026-09. Overlap: the 13 open rails/rails PRs on these files
  (2026-11-04: #59608, #59606, #59602, #59570, #59498, #59482, #59433, #59148, #59127, #58902, #58742, #58431,
  #58271). None touches the two leads below; #58271 has the same idea as the merged 9d1131bf79.
* Per-call numbers: [`leads_micro.rb`](../../bench/upstream/actionview_c12/leads_micro.rb), best of 5 × 1,000,000
  calls, pinned to one CPU, `Encoding.default_internal = UTF-8`. Wall time only; no Callgrind round was run,
  because no lead got past the share check.

## Where the rest of the pipeline stands

Census 8 lines in scope, highest first (excluding `tag_helper.rb`, `asset_*` and `OutputBuffer#<<`):

| Site | Apps | % of all Ir, interp / YJIT | Disposition |
| --- | ---: | ---: | --- |
| `OutputSafetyHelper#safe_join` (output_safety_helper.rb:41) | 14 | 0.082 / 0.111 | Below. No exact rewrite: escape, flatten, join and `html_safe` are all needed. Its main caller is `append_tag_option` (T2, parked). |
| `ControllerHelper#respond_to?` (:40–41) | 17 | 0.131 / 0.139 | Rejected in C10. |
| `Base#assign` (base.rb:317) | 18 | 0.067 / 0.098 | Rejected in V1 (`view_assigns` String keys are public API). |
| `Serialization#read_attribute_for_serialization` | 7 | 0.029 / 0.060 | Rejected ([serialization-cpu](serialization-cpu.md)). |
| `OutputBuffer#initialize` (buffers.rb:25) | 16 | 0.027 / 0.029 | Lead below; under the bar. |
| `AbstractRenderer#extract_details` (:165–166) | 11 | 0.042 / 0.019 | Already a minimal loop with a `NO_DETAILS` fast path. |
| `PartialRenderer#render_partial_template` | 11 | 0.022 / 0.026 | C10: nothing exact above the bar. |
| `FormTagHelper#field_id` (form_tag_helper.rb:113) | 7 | 0.022 / — | Lead below; under the bar. |
| `Validations#context_for_validation` | 12 | 0.020 / 0.008 | One `ValidationContext` per validated record; it is state, not waste. |
| `Template#render` (:338), `#strict_locals!` (:423) | 13 / 10 | 0.020 + 0.018 / 0.005 + 0.006 | `strict_locals?` runs twice per render, about 30 ns. Too small. |
| `Base#_run` (base.rb:368) | 15 | 0.017 / 0.033 | `public_send` is deliberate (b439b78705, amatsuda 2020: template methods are public). |
| `TemplatePath.virtual` (:22–24) | 17 | 0.023 / 0.028 | The cache key. Avoiding it needs a nested cache (L2+). Called once per lookup, not twice. |
| `PathSet#search_combinations`, `LookupContext#detail_args_for` | 18 / 15 | 0.057 + 0.008 / 0.035 + 0.009 (method) | Reworked on main: 3518f09daf, 142cc318c1, fb78f4f60d / #58899 (merged 2026-10-24), cee8bba523. |
| `Hash#as_json` (core_ext/object/json.rb:175) | 12 | 0.075 / 0.197 (method) | `Symbol#name` keys rejected (R7-2: loses on Ruby master). Capacity preallocation needs a Ruby ≥ 3.4 gate (L2), like #59557. |
| `Errors#[]` via `ActiveModelInstanceTag#error_wrapping` | 4–5 | ≤ 0.003 | Only form pages. An `@errors.empty?` early return skips `normalize_arguments` (which can raise), so it is not exact. |
| `translate` | 3 | — / 0.013 | Three apps. |
| `Template#compile!`, `instrument_render_template`, collection rendering into one buffer | | ≤ 0.009 | Reworked on main (9d1131bf79, b035657a99, e23bcfd2c3). |

## Leads measured and not built

| Lead | Per call, main → candidate (interp / YJIT) | Why not |
| --- | --- | --- |
| `OutputBuffer#initialize`: `+""` instead of `String.new("")` when no buffer is given | 292 → 202 ns / 207 → 121 ns; objects unchanged (2) | About 0.015% of instructions. An exact form needs a sentinel default and an identity check (`NOBUF.equal?(buffer)`), which needs a comment (L2). A `nil` default would stop `OutputBuffer.new(nil)` from raising `TypeError`, so it is not exact. `String.new(str)` costs about 100 ns more than `+""` because of its keyword parsing; that is Ruby's to fix. |
| `field_id`: skip `gsub`/`delete_suffix` when the object name has no character to replace | sanitizing `"post"`: 520 → 316 ns / 504 → 272 ns, 2 → 0 objects | Only form pages (7 apps, 0.022% for the line), so about 0.01% overall. Every name with `_` (`line_item`) still takes the slow path, and the regexp would be needed twice (a new constant). |

## Limits

* Wall time only, from a micro on one CPU; no Callgrind or ruby-bench, because no lead passed the share check.
* Census shares are from census 8 on Rails `1105756f42`; files changed since then (above) were read on `9b116f1fed`.
* No reviewer round: nothing was built.
