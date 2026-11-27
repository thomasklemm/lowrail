# L6 thermos-sol short confirm, 2026-11-27

Verdict: **approve** for the assembled body and record at Lowrail commit [cbbdb9f1](https://github.com/thomasklemm/lowrail/commit/cbbdb9f1ef22bf66d096af10af556e2ed91a2594), on unchanged Rails head [8b1c6428ea056b3c5983372d85b85615ae3d3f45](https://github.com/thomasklemm/rails/commit/8b1c6428ea056b3c5983372d85b85615ae3d3f45). No remaining must-fix and no new optional finding.

This is a short confirmation of the earlier detailed Thermos pass, not a new pair of independent reviews. The original L1 code approval, executed exactness probe and measured worst-case controls remain applicable. No code, queue item or record was edited by this reviewer. No new benchmark measurement or full suite run was needed for these text-only changes.

## All requested corrections are confirmed

* The Callgrind heading no longer asserts allocation parity. The record uses the exact qualified objects sentence; impact excludes an allocation count for `update!` because the controls differ.
* The body leads with the requested 30-column native benchmark, before the supporting Callgrind table. Its Ruby code is identical to the previously executed `native_benchmark.rb` except for removing the magic comment. The extracted code has no comment lines and passes `ruby -c`.
* The before and after output lines match `body-rerun/raw/ips-r2-base.log` and `ips-r1-candidate.log` exactly, apart from their labels and leading indentation. They are the best rounds of their respective streams. The pinned Ruby version line matches those logs. All nine retained native measurement windows are JIT-flat. The body does not turn the overlapping timings into a prose speed-up claim.
* Every Callgrind table cell and the final instruction-only prose remain unchanged from the detailed pass. Rerunning the archived-total audit again gives `ALL_ARCHIVED_TOTALS_MATCH`.
* The record and impact now qualify ZJIT as ungated: the measurements neither establish a gain nor rule out a regression. The unsupported separate counter claims and “No ZJIT loss” assurance are gone.
* Astra's call-count sentence is scoped to the measured update. The unchanged title, helper-count framing and commit motivation remain accepted optional choices, not blockers.

The internal +3.7% native aggregate uses the mean of the two best control streams, 50,385.5 i/s (50,195 and 50,576), against 52,253 i/s. It is not the ratio of the two raw output lines shown in the body. `checks.txt` records this distinction; the body makes no percentage timing claim.

The prose was reread sentence by sentence as an upstream description: no internal process text or Lowrail link, no conflation of instructions with time, no new project/caller citation to vet, and no unnecessary code comment. Omitting the optional rewrites does not block approval.

The live fork branch still resolves to the exact reviewed head and live Rails main still resolves to base `088fc0cf61e4ba0c7987decafacc69adb3e22eec` (`remote-refs.txt`). There is consequently no new code or upstream overlap to re-review. This approval does not substitute for Astra's confirm or the queue's opening checks.

## Retained inputs and checks

`item-reviewed.md` is the complete item at the requested Lowrail commit; `record-reviewed.md` is its refreshed L6 section. `benchmark.rb` is extracted verbatim from the body's Ruby fence. `verify.rb` compares the assembled text against the original review evidence and the raw native logs. `body-data-audit.txt` retains the repeated independent arithmetic audit of all four original body-run archives.

Executed from the Lowrail repository root:

```sh
e=docs/upstream/data/rails-main-census-9/lead6/review-thermos-sol-2026-11-27
mise exec ruby@4.0.9 -- ruby "$e/confirm/verify.rb"
mise exec ruby@4.0.9 -- ruby -c "$e/confirm/benchmark.rb"
mise exec ruby@4.0.9 -- ruby "$e/audit_body_data.rb"
```

Decisive output: `ASSEMBLED_BODY_CONFIRM_CHECKS_PASS`, `Syntax OK`, and `ALL_ARCHIVED_TOTALS_MATCH`. These are checks against retained runs, not new 4.0.9 performance measurements after the pin change.
