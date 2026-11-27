Draft issue for sferik/duel-ruby (not posted; Thomas approves the final text). The issue body is between the two
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

Calibration on GitHub's hosted runners, using [fork pull requests](https://github.com/thomasklemm/hashie/pulls?q=is%3Apr+%5Bcalibration%5D) with comment-only changes to `lib/`, gave:

| Setup | Runs failed | Unsettled benchmark results |
|---|---|---|
| 13 benchmarks, default limit and workers | 0 of 25 | 79 of 325 |
| 27 benchmarks, one at a time, 12 or 24 workers, CPU limit 1.02 | 6 of 10 | 46 of 270 |
| 27 benchmarks, one at a time, 24 workers, CPU limit 1.05 | 0 of 20 | 6 of 540 |

Some comment-only comparisons showed 3–7% timing differences, including differences that survived fresh-process confirmations. The cause wasn't isolated. The 1.05 setup still caught both planted regressions in every run, but trades sensitivity to small slowdowns for fewer false alarms.

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
