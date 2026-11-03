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
| 2026-11-03 | [ruby/ruby#19663](https://github.com/ruby/ruby/pull/19663) | Problem/Fix labels became sentences; the ns table says which run is which. |
| 2026-11-03 | [ruby/ruby#19664](https://github.com/ruby/ruby/pull/19664) | Allocation numbers became one sentence with master as the baseline. |
| 2026-11-03 | [ruby/ruby#19665](https://github.com/ruby/ruby/pull/19665) | Corrected "both tests fail on master": only the allocation test does; baseline named. |
| 2026-11-03 | [ruby/ruby#19666](https://github.com/ruby/ruby/pull/19666) | Corrected the ruby2_keywords case (methods marked with it, not flagged hashes); dropped the stale "2 together with #19655". |
| 2026-11-03 | [ruby/ruby#19670](https://github.com/ruby/ruby/pull/19670) | Answer first; the three-number table became one sentence; "embedded table" is now "AR table". |
| 2026-11-03 | [rails/rails#59557](https://github.com/rails/rails/pull/59557) | Tables became sentences with baselines; corrected the repeat-run noise (0.16%, not 0.1%), the unmeasured YJIT count with ruby/ruby#19663, and the spill claim (small Hashes only). |
| 2026-11-03 | [rails/rails#59564](https://github.com/rails/rails/pull/59564) | Table became sentences; the A/A pairs are explained as one repeat run per case; "every includes that preloads". |
| 2026-11-03 | [rails/rails#59565](https://github.com/rails/rails/pull/59565) | Corrected the `IS`/`IS NOT DISTINCT FROM` pairing and which change made `where` send binds. |
| 2026-11-03 | [rails/rails#59569](https://github.com/rails/rails/pull/59569) | Corrected the workload counts (36 interpreter, 42 YJIT; 2 objects per direct scope); Ruby 4.0.7 named. |
| 2026-11-03 | [rails/rails#59570](https://github.com/rails/rails/pull/59570) | The boundary became its own paragraph; the append count covers every `<%= %>`; Ruby 4.0.7 named. |
| 2026-11-03 | [rails/rails#59574](https://github.com/rails/rails/pull/59574) | Answer first; the three-row table became two sentences. |
| 2026-11-03 | [rails/rails#59577](https://github.com/rails/rails/pull/59577) | Corrected when the result is allocated and when the frozen empty Array is returned (Hash arguments); the interpreter's −0.6% marked as noise; the application sentence now matches the posted reply. |
| 2026-11-03 | [rails/rails#59583](https://github.com/rails/rails/pull/59583) | "Ir" and "A/A" spelled out; "workloads" named as requests, jobs or mailers. |
| 2026-11-03 | [rails/rails#59584](https://github.com/rails/rails/pull/59584) | Dense first paragraph split; the escape share is an average, not a range; A/A spelled out. |
| 2026-11-03 | [rails/rails#59585](https://github.com/rails/rails/pull/59585) | A 4.6% instruction increase is no longer called slower; the ZJIT 7–10% range names its two cases; A/A spelled out. |
| 2026-11-03 | [ruby-i18n/i18n#764](https://github.com/ruby-i18n/i18n/pull/764) | One dense sentence split into four. |
| 2026-11-03 | [ruby-i18n/i18n#765](https://github.com/ruby-i18n/i18n/pull/765) | Hard wraps removed; the instruction count names the JIT and baseline; "every app that translates" became "all ten". |
| 2026-11-03 | [ruby-i18n/i18n#766](https://github.com/ruby-i18n/i18n/pull/766) | Corrected where the check is cached (a private constant read by three methods) and what the 3% is (the saving). |
| 2026-11-03 | [rails/propshaft#289](https://github.com/rails/propshaft/pull/289) | A sentence says what the table measures; "M" and "k" spelled out. |
| 2026-11-03 | [ruby/bigdecimal#562](https://github.com/ruby/bigdecimal/pull/562) | Cut from about 450 words of prose to about 185: problem and fix, the allocation table, the instruction saving, no speed claim, one validation line. Constructor details, CPU controls and the earlier-variants note dropped; reproduction script kept. |
| 2026-11-03 | [rails/importmap-rails#336](https://github.com/rails/importmap-rails/pull/336) | Answer first; confidence intervals and controls spelled out; tests shortened to one line; AI note and the ZJIT invalidation remark dropped. |
| 2026-11-03 | [tzinfo/tzinfo#171](https://github.com/tzinfo/tzinfo/pull/171) | Answer first; "oldest CI engine lines" became "then the oldest Rubies in CI"; the undefined "independent results" dropped. |
| 2026-11-03 | [inertiajs/inertia-rails#437](https://github.com/inertiajs/inertia-rails/pull/437) | Measurement setup in full sentences; A/A and percentile labels spelled out; arrows removed. |
| 2026-11-03 | [inertiajs/inertia-rails#441](https://github.com/inertiajs/inertia-rails/pull/441) | The one-row table became two sentences with the baseline. |
| 2026-11-03 | [inertiajs/inertia-rails#442](https://github.com/inertiajs/inertia-rails/pull/442) | The table became one sentence; the 1.8% median is scoped to all 55 requests. |
| 2026-11-03 | [rubocop/rubocop-performance#550](https://github.com/rubocop/rubocop-performance/pull/550) | Arrows and "stock / branch" columns spelled out; "witnesses" and "AST" replaced. |
| 2026-11-03 | [rubocop/rubocop-rails#1670](https://github.com/rubocop/rubocop-rails/pull/1670) | The A/A allocation sentence names its two runs and the baseline of the 26.4%. |
| 2026-11-03 | [skryukov/rails_vite#57](https://github.com/skryukov/rails_vite/pull/57) | "Closes #56" dropped (#56 closed as a duplicate); first sentence plain; ends with a link to #56 for motivation. |

Left unchanged: [ruby/ruby#19620](https://github.com/ruby/ruby/pull/19620), already plain. The ruby/ruby part stopped after these, because the open ruby/ruby PRs are being reviewed with Thomas. Also unchanged as already plain: ruby-i18n/i18n#763, MiniProfiler/rack-mini-profiler#670, getlago/lago-expression#91, inertiajs/inertia-rails#435 and #436, rubocop/rubocop-performance#551 and #552, and Shopify/tapioca#2748.
