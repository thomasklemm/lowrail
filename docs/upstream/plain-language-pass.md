# Plain-language pass over open PR descriptions

Every open PR description by thomasklemm in ruby/ruby, rails/rails and the gem repos, rewritten under the
"Plain language upstream" rule in [DECISIONS](../DECISIONS.md) after tekknolagi's reply on
[Shopify/ruby#1058](https://github.com/Shopify/ruby/issues/1058#issuecomment-6613994853). Each draft kept every fact,
number and caveat, was checked by a separate reviewer against the old body, the diff and our record, and was
approved per PR before the body was replaced through the REST API. No comments were posted, no code changed.
ruby/ruby#19483, #19558, #19680 and #19681 are rewritten by the thread that is remeasuring them.

| Date | PR | What changed |
| --- | --- | --- |
| 2026-11-03 | [ruby/ruby#19655](https://github.com/ruby/ruby/pull/19655) | Answer first; the allocation table became one sentence with its baseline. |
| 2026-11-03 | [ruby/ruby#19659](https://github.com/ruby/ruby/pull/19659) | Bullets became sentences; six geomeans without a stated direction replaced by "within the differences between two identical builds". |
| 2026-11-03 | [ruby/ruby#19662](https://github.com/ruby/ruby/pull/19662) | Problem/Fix labels dropped; a second, conflicting baseline (27.5 → 81.7 ns) replaced by "about three times slower"; per-call numbers in one table; notes that #19660 is merged. |
| 2026-11-03 | [ruby/ruby#19678](https://github.com/ruby/ruby/pull/19678) | Split into what is wasted and what changes; table rows say master → this PR. |
| 2026-11-03 | [ruby/ruby#19682](https://github.com/ruby/ruby/pull/19682) | Table became three sentences with baselines; Ir spelled out as Callgrind instructions; unrecorded "20,000 calls" dropped. |
| 2026-11-03 | [ruby/ruby#19487](https://github.com/ruby/ruby/pull/19487) | Plainer guard wording; the stats table became one sentence. |
| 2026-11-03 | [ruby/ruby#19492](https://github.com/ruby/ruby/pull/19492) | Answer first; ratio directions stated; the stats table became one sentence. |
| 2026-11-03 | [ruby/ruby#19648](https://github.com/ruby/ruby/pull/19648) | Answer first; corrected the new function's name to `rb_yjit_class_attached_object()`. |
| 2026-11-03 | [ruby/ruby#19661](https://github.com/ruby/ruby/pull/19661) | Labels and tables became sentences; names #19663 and #19662 as the JIT follow-ups. |

Left unchanged: [ruby/ruby#19620](https://github.com/ruby/ruby/pull/19620), already plain.
