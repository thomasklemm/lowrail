Draft issue for sferik/duel-ruby (not posted; Thomas approves the final text). Checked against Duel 0.3.1 and main
a09111e on 2026-11-27: the default watch list is still `lib` and `ext`, workers load the runner's bundle unless
`c.prepare(:version)` sets `BUNDLE_GEMFILE`, and the repro output below is from hashie at be311bb.

Title: A change to only Gemfile or Gemfile.lock is skipped as "nothing to compare"

---

A pull request that changes only `Gemfile` or `Gemfile.lock`, such as a Dependabot bump, passes with "nothing to compare", because Duel watches `lib` and `ext` by default. Adding `c.watch += ['Gemfile']` makes it run, but both versions then load the runner's bundle, so it compares the same code with the same gems. Should a lockfile change be compared with each version on its own bundle, as the `c.prepare(:version)` example does, or should the docs say that dependency changes aren't compared?

```
echo '# a dependency change' >> Gemfile && git commit -qam 'Change only the Gemfile'
bundle exec duel --base HEAD~1
# duel: lib, ext, benchmarks, .duel.rb unchanged since the baseline, so there's nothing to compare (--force to anyway)
```

We added Duel to Hashie in hashie/hashie#659 and calibrated it on GitHub's hosted runners with pull requests in [a fork](https://github.com/thomasklemm/hashie/pulls?q=is%3Apr+%5Bcalibration%5D): comment-only changes to `lib/` as controls, and two planted regressions.

| Setup | Identical code failed | Unsettled | Planted regressions | Passing job |
|---|---|---|---|---|
| 13 benchmarks, default limit and workers | 0 of 25 runs | 79 of 325 | allocation: all 8 benchmarks it reaches; CPU (about 1.5×): caught | 47–84 s |
| 27 benchmarks, one at a time, 12 or 24 workers, CPU limit 1.02 | 6 of 10 runs | 46 of 270 | not run | 109–201 s |
| 27 benchmarks, one at a time, 24 workers, CPU limit 1.05 | 0 of 20 runs | 6 of 540 | allocation: 13 benchmarks, CPU: 4, both in every run | 124–137 s |

With more benchmarks, a comment in `lib/` moved some method-call timings by 3–7% for a whole run, fresh processes included, which a 1.02 limit fails. We don't know why. Two benchmarks at a time also failed identical code once in 20 runs. A [current run](https://github.com/hashie/hashie/actions/runs/46026321908) on the pull request had 0 unsettled.

Instruction counts weren't available. Of 23 jobs, 20 ran on Azure AMD EPYC runners, where `perf_event_open` fails with EACCES at the default `perf_event_paranoid` and ENOENT at 2 or below, and 3 on AWS Xeon runners, where it works after `sudo sysctl kernel.perf_event_paranoid=2` and the read then needs #9. Counting instructions under Callgrind instead, on a fork, was quieter but caught nothing CPU time missed and made jobs 2.5–4× as long, so CPU time looks like the right default on these runners.
