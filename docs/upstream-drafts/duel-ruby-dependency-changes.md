Draft issue for sferik/duel-ruby. **Not posted** (Thomas, 2026-11-27: kept as our own notes, no issue). The issue body is between the two
horizontal rules; the review after it is internal. Checked against Duel 0.3.1 and main a09111e on 2026-11-27.

Title: Document how to compare dependency changes

---

Could the docs show dependency-change setup in one example: watch `Gemfile` and `Gemfile.lock`, then prepare each version's bundle? In Duel 0.3.1 and current main, changes to only those files are skipped by default. Adding a file to `c.watch` makes Duel run, but under `bundle exec` both versions still load the runner's bundle unless configured otherwise. The [per-version preparation example](https://github.com/sferik/duel-ruby/blob/a09111ec63dc2c7faa083fd8472239b3f13eefff/docs/configuration.md#prepare-each-version) already supplies the bundle part.

This came up adding Duel in hashie/hashie#659. Before adding the watch entry, at [this revision](https://github.com/thomasklemm/hashie/tree/be311bbf4b0571d71481579f5c4e7aa27e704a01):

```sh
echo '# a dependency change' >> Gemfile && git commit -qam 'Change only the Gemfile'
BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec duel --base HEAD~1
# duel: lib, ext, benchmarks, .duel.rb unchanged since the baseline, so there's nothing to compare (--force to anyway)
```

Calibration on GitHub's hosted runners used Ruby 4.0 with YJIT and `c.warm = 2`. [Fork pull requests](https://github.com/thomasklemm/hashie/pulls?q=is%3Apr+%5Bcalibration%5D) with comment-only changes to `lib/` gave:

| Setup | Runs failed | Unsettled benchmark results |
|---|---|---|
| 13 benchmarks, two at a time, 12 workers per version, CPU limit 1.02 | 0 of 25 | 79 of 325 |
| 27 benchmarks, one at a time, 12 or 24 workers per version, CPU limit 1.02 | 6 of 10 | 46 of 270 |
| 27 benchmarks, one at a time, 24 workers per version, CPU limit 1.05 | 0 of 20 | 6 of 540 |

Some comment-only comparisons showed 3–7% timing differences, including differences that survived fresh-process confirmations. The cause wasn't isolated. The 1.05 setup caught both planted regressions in two runs of each plant, but trades sensitivity to small slowdowns for fewer false alarms.

Hardware instruction counters were unavailable on the sampled Azure AMD runners even after relaxing perf permissions. AWS Xeon probes could open the counter but hit the read failure addressed by #9. A Callgrind fork had fewer unsettled results but no extra catches in the planted regressions, at higher job times. It ran without YJIT while the CPU-time job used YJIT; small CPU slowdowns weren't planted.

---

## Review — 2026-11-27

Verdict: changes; the replacement above is approved by this review, not approved for posting. Reviewed directly,
without delegates. Nothing posted upstream.

* Ruby 4.0.9 probes passed on installed Duel 0.3.1 and main `a09111ec`: Gemfile-only and lockfile-only changes skip;
  watching Gemfile loads dependency 2.0 twice; per-version preparation loads 1.0/2.0. Source and docs agree; shared
  bundles are already documented. Harness and logs: `.amp/in/orb-backup/duel-review/`.
* Reproduced Hashie's skip at `be311bbf4b`. Without `BUNDLE_GEMFILE`, the command fails: Duel isn't in the root
  bundle. Watch was added in `0c58ef4`, already present at `ef3b274`.
* Ran `tally.py` for `calibration`, `-3`, `-4`, `-7`, `-7p12`, `-8`; retained counts agree. Cut "not run" (round 7
  caught five CPU-plant regressions) and "Passing job" (included failures). The two-at-once 1/20 is real, but
  neither contention nor comment placement nor added scenarios was isolated as a cause.
* Callgrind tally/probes confirm the outcome, not the general default recommendation. README counts are stale:
  26 counter summaries (20 AMD, four Intel, two unknown), 20 A/A runs. One CPU-plant pair took 915/184 = 4.97×,
  outside 2.5–4×. Cut counts/ratios; disclose differing JIT modes and no small-slowdown plant.
* GitHub API confirms public link targets, open counter-read fix #9, and run 46026321908's zero unsettled (cut as
  redundant). HTML fetches failed in this environment. Hashie: active, 3,035 stars, ~507 million downloads, 6.0.0
  released November 11. Duel: active, 21 stars, 8,688 downloads, 0.3.1 released November 22. Body has no internal
  names, headings, bold or pings; 309 words, down from 395.

## Thermos follow-up — 2026-11-27

Verdict: changes to Astra's replacement at `3c1a25e3`; title approved. Applied both rubrics personally, without delegates. The body above includes the two clarifications below and goes back to Astra before Thomas; nothing was posted upstream.

* Disclose `c.warm = 2`, common to the table's cohorts, and name the first row's two concurrent benchmarks, CPU limit and workers per version. "Default limit and workers" was literally true, but omitted the nondefault warm-up. The logs and Hashie configuration establish the explicit settings.
* Replace "every run" with its observed denominator: two runs per plant, with 13 allocation and four CPU regressions each time (`calibration-8`). This does not establish sensitivity to smaller slowdowns.
* Rechecked every other sentence against source and archived runs. Reran both tally scripts; the retained table cells match, as do the 3–7% observations, counter failures, tighter Callgrind intervals, differing JIT modes and absence of small-slowdown plants. All 108 summaries in the six requested CPU cohorts match their archived raw final reports.
* Both Duel pins reproduced the Gemfile-only skip at Hashie `be311bbf4b`; a live worker probe confirmed separate library trees with the inherited Gemfile, then per-version Gemfiles through preparation. Code/docs support the combined-example request, not an unsupported-feature claim.
* Unauthenticated API reads verified all link targets: the exact `a09111ec` docs file contains `Prepare each version`; the Hashie tree pin exists; fork PRs contain the controls/plants; the Hashie PR adds Duel; the open read-fix PR is #9. Direct HTML requests timed out, but the public API content was accessible. No additional body changes were needed.

## Confirmation — 2026-11-27

Verdict: approve the exact title and body from `0e1d2b11`, unchanged. Reviewed directly, without delegates;
Thomas still approves posting. Checked all 55 archived A/A logs behind the table: round 1's 25 runs explicitly
say two benchmarks at a time and 12 workers per version; rounds 7/7p12/8 say one at a time and 24/12/24 workers.
All report Ruby 4.0.10 with YJIT. GitHub API reads of `.duel.rb` at the four cohorts' recorded aa-1 heads confirm
`c.warm = 2`, with CPU limit 1.05 in round 8. Reran the four cohort tallies; table totals agree. The four raw
round-8 plant logs confirm two runs per plant: 13 allocation regressions in each allocation run and four CPU
regressions in each CPU run, all with zero errors. Both clarifications are accurate; no replacement needed.
