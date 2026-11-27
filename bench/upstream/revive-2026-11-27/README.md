# Reviving TO1, FH2, LBL1 and SP1 (2026-11-27)

These four held rails/rails items were rebuilt on Rails main `088fc0cf61` (2026-11-27), each as one commit by Thomas with
no trailers. They had been held because K6 hadn't merged yet (TO1), because rails/rails had stopped merging per-call
wins (FH2, LBL1), and because the four upgrade-guide PRs had no decision yet (SP1). All of those reasons cleared on
2026-11-26. Ruby 4.0.9, plus Ruby master `f3e180b5eb` for ZJIT.

| Item | Fork branch | Head | Outcome |
| --- | --- | --- | --- |
| TO1 | `thomasklemm/tag-attributes-own-string` | `7f1f0dce45` | held: ZJIT `f.text_field` +0.64% unexplained, and no form-level effect |
| FH2 | `thomasklemm/form-builder-tag-copies` | `7401f9dac7` | parked: Astra broke V and TR; the exact remainder (PH + SV) is within noise |
| LBL1 | `thomasklemm/label-translation-key-once` | `4c64fb7898` | held for Thomas: Astra found Chain, Proc and Cache rendering boundaries |
| SP1 | `thomasklemm/upgrade-guide-frozen-default-url-options` | `d41b93d147` | the 2026-11-17 claude-code must-fixes applied; approved |

## Ownership and drift

`script/ownership` (2026-11-27) found nothing for FH2, LBL1 or SP1. For TO1 it listed open PRs that touch
tag_helper.rb. The only one about allocations is rails/rails#57999 (ikraamg, changes requested in July). It removes
the per-attribute strings in `tag_option`, which main has since replaced with `append_tag_option`, so the two don't
overlap. Since `4500a94c34`, main has changed `tags/base.rb` (FB1, #59824) and `tag()` (K6, #59804, which adds
`.freeze`). FH2 and LBL1 cherry-pick onto main cleanly. Main has nothing new on `default_url_options`: `url_for.rb` is
unchanged, and neither a CHANGELOG nor the guide mentions the freeze.

## Equivalence (Ruby 4.0.9, main against each head, A/A main against main2)

* `sweep_fuzz.rb`, 86,726 lines: main2, TO1 and FH2 match main byte for byte. LBL1 differs in 330 cases, all of them a
  method name with invalid UTF-8 in a label or placeholder. Main raised `EncodingError` when it built the repeated
  default Symbol; LBL1 doesn't build that Symbol, so I18n raises `ArgumentError: invalid byte sequence` instead. Both
  raise. `results/lbl1_fuzz_diff.txt`.
* `sweep_boundaries.rb`, TO1: an override of `TagBuilder#tag_options` (`:nodoc:`) no longer sees `tag()` or void
  elements; the output is unchanged. `results/to1_boundaries_diff.txt`.
* `fh2_probe.rb`, 32,272 lines, object addresses normalized: only the 45 Translator boundary lines recorded in
  2026-11-17 (Symbol, `to_s` object, nil and Integer object names; the name is no longer a copy, so it can be frozen).
  The AMT arity lines are gone with AMT. `fh2_review_probe.rb`, 202,330 lines: the TR, SV and V String-subclass
  boundaries recorded by the claude-code pass, with no AMT lines. `fh2_amt_override.rb` renders on FH2 as it does on main.
* `lbl1_probe.rb`: the Simple backend shows the same 48 Proc-returning-nil lines as `lbl1_probe_diff.txt` and Fallbacks
  is identical. Lookups drop from 417,750 to 404,282 (Fallbacks 819,466 to 792,814), the same counts as in 2026-11-17.
* SP1: `sp1_probe.rb` on main, results in `bench/upstream/sp1/probe-main-088fc0cf61-configure{0,1}.txt`.

## Tests

Action View `rake test` (template, Action Pack and Active Record integration) passes on main, on each head, and on
FH2 + LBL1 + TO1 merged: 2,982 + 252 + 177 runs, 0 failures (`results/actionview_tests.txt`). RuboCop reports no
offenses on the changed files. `git merge-tree` is clean for each pair of TO1, FH2 and LBL1.

## Objects per call

`results/objects.txt` (interpreter and YJIT) has the same setup as the bodies. TO1: `text_field_tag` 9 → 8,
`hidden_field_tag` 11 → 10, `submit_tag` 14 → 13, `tag.input` 6 → 5, `f.text_field` 17 → 16, `f.check_box` 20 → 18.
FH2: `text_field` 17 → 15, `text_area` 18 → 16, `radio_button` 21 → 19, `select` 33 → 33, `label` 90 → 86.
LBL1: `label` 90 → 75. main2 matches main.

## Instructions per call (Callgrind)

`revive_ir.sh` and `revive_ir.rb` (interpreter) and `revive_jit.sh` and `revive_jit.rb` (YJIT, ZJIT) use the same
setup as `fh2_ir.rb`: GC off, each scenario in its own `Array#cycle` Callgrind part, minus a `cycle(0)` part. Trees run
interleaved: main, TO1, FH2, LBL1, main2, main. A/A is the spread of the three main runs, and a change counts only
outside it. Untouched paths move by up to about 0.3% (interpreter) and 0.5% (JIT) between trees.

JIT gate: each scenario warms up in rounds of N calls (N = 500, GC off) until three rounds in a row compile nothing.
A first `cycle(0)` pass compiles the measuring loop itself, and the script skips its parts. Each scenario prints what
it compiled during its own window, and `nf` marks a scenario that compiled in any tree; nf cells don't count. Under
Callgrind, `hidden_field_tag` always compiles in its window (5 YJIT blocks, 12 ZJIT units), as do some `form_with` and
ZJIT `f.label` windows. They are recorded and not rerun. An earlier harness, with its warm-up shorter than the window,
compiled 11–34 blocks per window. Its runs were discarded before the harness was fixed.

Tables: `results/{interp,yjit,zjit}_table.txt`; raw output: `results/{interp,yjit,zjit}.txt`.

| Per call, change against main | interp | YJIT | ZJIT (master) |
| --- | ---: | ---: | ---: |
| TO1 `tag.input` | −2.21% | −3.80% | −1.98% |
| TO1 `text_field_tag` | −1.10% | −1.56% | −0.89% |
| TO1 `submit_tag` | −0.92% | −1.84% | −0.62% (A/A 0.39%) |
| TO1 `f.check_box` | −0.86% | −1.73% | −0.68% |
| TO1 `f.text_field` | −0.02% | −0.61% | **+0.64%** (A/A 0.12%) |
| TO1 5-field `form_with` | −0.12% / −0.04% | −0.35% nf / −0.18% nf | +0.05% / −0.18% nf |
| FH2 `f.text_field` | −1.44% | −0.92% | −0.92% |
| FH2 `f.text_area` | −1.97% | −0.30% | −1.08% |
| FH2 `f.radio_button` | +0.04% | −0.86% (A/A 0.66%) | −0.55% |
| FH2 `f.label` | −0.49% | −1.09% | −0.70% nf |
| FH2 5-field `form_with` (label text) | −0.38% | −0.38% nf | −0.06% |
| LBL1 `f.label` | −16.36% | −16.73% | −18.32% nf |
| LBL1 5-field `form_with` with `f.label` | −8.81% | −9.43% nf | −9.78% nf |

Under ZJIT, TO1 runs `f.text_field` 0.64% slower, outside both the A/A and the cross-tree noise, while
`text_field_tag`, which takes the same `tag()` path, is 0.89% faster. Nothing explains that yet, and DECISIONS blocks a
ZJIT loss until it is explained. TO1 also moves no form outside noise, so it stays held.
FH2's five-field form uses 0.38% fewer interpreter instructions; its YJIT cell is not JIT-flat and doesn't count, and its ZJIT difference is within A/A. No whole-request effect was measured. No change loses under ZJIT.

## SP1 body and the citation rule (DECISIONS 2026-11-27)

Checked 2026-11-27. Spree: 15.9k stars, about 3.0M downloads, pushed today. rails_admin: 8.0k stars, about 13.6M
downloads, pushed 2026-11-26. rspec-rails 8.0.5 is superseded by 8.1.0, which has the fix, so its bullet is dropped.
The rule's permalinks follow Line permalinks for callers (DECISIONS 6252c567), so the links stay on the latest releases, named in the text: Spree 6.0.6 `314dcb7784` (L65 and L182) and rails_admin 3.3.1 `ab5ae55428` (L44). A first draft that pinned default-branch commits was corrected after Astra's confirm pass. Spree stays first although rails_admin has more downloads, because its line runs in every Spree store's
mailer, while rails_admin's runs only in rails_admin's own suite.

## FH2 after Astra (2026-11-27)

Astra's pass on `7401f9dac7` (archive `astra-fh2/`) found two exactness breaks with public callbacks and mutable Strings.
`value_before_type_cast` builds its method name after `value_came_from_user?` has run, and `Translator` keeps the
caller's unfrozen object name instead of a copy. Both hunks have to go. What is left, PH (`(...)`) and SV
(`sanitized_value` in place), is in a local tree, measured once interleaved with main and main2
(`results/fh2_reduced_interp.txt`, N = 500, interpreter): `f.text_field` −0.54%, `f.text_area` −0.53%,
`f.radio_button` −0.31%, `f.label` −0.14%, 5-field `form_with` −0.09% / −0.16%, with main/main2 A/A ≤ 0.07%. Objects:
text_field 17 → 16, text_area 18 → 17, radio_button 21 → 19, label 90 → 88. That is within cross-tree noise at the form
level and below the bar, so FH2 is parked and not opened.

## LBL1 after Astra (2026-11-27)

Astra's pass on `4c64fb7898` (archives and `adversarial.rb` in `astra-lbl1/`; reproduced here, `adversarial_diff.txt`)
found differences beyond the disclosed ones:

* a Hash translation in an earlier `Chain` backend: main renders the Hash, the head renders "Title";
* a translation Proc that reads `default:` renders other text, and under `Cache` two builders' entries coincide;
* a BasicObject `i18n_key` duck raises `NoMethodError` (`Symbol === key` fixes this one).

Astra's fresh Callgrind run (i18n 1.15.2) confirms the effect: `f.label` −16.9% in the interpreter and with YJIT, and a
five-label form −9.3% / −9.6%. LBL1 is held until Thomas decides whether these boundaries are acceptable.
