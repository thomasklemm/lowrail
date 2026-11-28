# Why hashie's Perf Comment workflow posted nothing on HM5's PR (2026-11-28)

michaelherold merged hashie/hashie#662 (HM5) on 2026-11-28 at 13:12 UTC and asked there why no Duel comment appeared
next to Danger's ([comment](https://github.com/hashie/hashie/pull/662#issuecomment-7239768173)). This is the cause as
the runs show it, and the reply drafted for review. Nothing is posted yet.

## Cause

Duel comments on a pull request only when its `.duel.rb` setting `c.comment` says to. hashie's `.duel.rb` (master
`f608fb1`) does not set it, so Duel 0.3.1's default `:failures` applies: a comment when a benchmark failed or Duel
could not compare, and, once it has commented, again when the status changes. Both Duel jobs of the PR's Perf run
passed, so each report said `comment=change`, there was no earlier Duel comment whose status could differ, and
`duel comment` posted nothing. The workflows from the Duel guard PR and the ZJIT job PR worked as written; the
default was left in place and neither PR body nor CONTRIBUTING.md says a passing run stays silent.

## Evidence

**The run on HM5's PR.** Perf run 46142873379 (`pull_request`, head `6b6f67b39c`), jobs `Duel (yjit)` and
`Duel (zjit)`, both success. Its two artifacts ([reports/perf-run-46142873379](reports/perf-run-46142873379)):

| report | `comment.env` | first line of `duel.md` |
| --- | --- | --- |
| duel-report-yjit | `pr=662`, `comment=change`, `status=passed` | 🟢 Duel: 100% of benchmarks passed (27 benchmarks, 1 unsettled) |
| duel-report-zjit | `pr=662`, `comment=change`, `status=passed` | 🟢 Duel: 100% of benchmarks passed (27 benchmarks) |

Perf Comment run 46143085591 (`workflow_run`, 12:07:17 UTC, success;
[log](perf-comment-logs/run-46143085591.log)): "Get the report" found and downloaded both artifacts of run
46142873379; "Comment on the pull request" ran `duel comment --report … --head 6b6f67b39c… --marker duel` and printed

```
duel comment: no comment (the last comment says passed already)
```

**Every Perf Comment run on hashie so far** (`gh api repos/hashie/hashie/actions/workflows/perf-comment.yml/runs`;
logs in [perf-comment-logs](perf-comment-logs), reports in [reports](reports)):

| Perf Comment run | Perf run | PR head | reports say | `duel comment` printed |
| --- | --- | --- | --- | --- |
| 46058882024 | 46058787439 | ZJIT job PR, `f6545d1dd3` | `comment=change`, `status=neutral` (nothing to compare) ×2 | no comment (the last comment says neutral already) |
| 46065084741 | 46064801194 | HM2's PR, `1af7ad9a20` | `comment=change`, `status=passed` | no comment (the last comment says passed already) |
| 46071028106 | 46070968046 | ZJIT job PR, `62f869ab29` | `comment=change`, `status=neutral` ×2 | no comment (the last comment says neutral already) |
| 46143085591 | 46142873379 | HM5's PR, `6b6f67b39c` | `comment=change`, `status=passed` ×2 | no comment (the last comment says passed already) |

No hashie PR has a Duel comment: the issue comments of the HM1, Duel guard, ZJIT job, HM2 and HM5 PRs hold Danger's
report from `github-actions[bot]` and people's comments, nothing else.

**Duel 0.3.1's source** (the gem from rubygems.org, sha256 `6a5363b2…e53355`, the version `duel-comment.yml` at
`3c0c99d` installs):

* `lib/duel/config.rb`: `@comment = :failures` is the default; the doc comment and `docs/configuration.md`
  ("Choose when to comment on a pull request") list `:always`, `:results` ("When the run passed or failed, but not
  when there was nothing to compare"), `:failures` ("When a benchmark failed, or Duel couldn't compare. This is the
  default.") and `:never`, and say that once the workflow has commented it comments again when the status differs
  from its last comment's.
* `lib/duel/cli.rb`: `CLI.comment(mode, status)` returns `post` or `change`. Called here for every mode and status:
  `:failures` gives `change` for `passed` and `nothing_to_compare` and `post` for `failed` and `error`; `:results`
  gives `post` for `passed`, `failed` and `error` and `change` for `nothing_to_compare`; `:always` gives `post` for
  all four.
* `lib/duel/comment.rb`, `Comment#comment`: it posts only if the merged mode is `post` or the last Duel comment's
  marker differs from this run's status; with no earlier Duel comment it prints "no comment (the last comment says
  STATUS already)".

**Ruled out by the same log:** a missing report (two artifacts were downloaded); an unresolved PR number (both reports
carry `pr=662`, and `duel comment` got past its check that the PR's head is still the run's head, which it makes
before it looks at earlier comments); a difference in how Danger Comment and Perf Comment find the PR (Perf Comment
found it).

**Where the results are without a comment:** the Duel jobs' logs print every benchmark's ratio
(job 140972490241 for YJIT, 140972490523 for ZJIT). Whether the run's summary page shows the report was not verified:
it does not render for a signed-out reader.

## The fix, if the maintainers want a comment on passing runs

One line in `.duel.rb`: `c.comment = :results`. Not built and not run on the fork; it would be a new queue item, and
it opens only if a maintainer asks for it.

## Reply draft (exact text, for thermos-sol and Astra)

To be posted on the PR as a reply to michaelherold. Everything between the rules is the comment.

---

Duel doesn't comment on a passing run by default. `.duel.rb` doesn't set [`c.comment`](https://github.com/sferik/duel-ruby/blob/v0.3.1/docs/configuration.md#choose-when-to-comment-on-a-pull-request), so the default, `:failures`, applies: it comments when a benchmark fails or Duel can't compare, and after such a comment once more when the result changes. Both Duel jobs passed here, so the [Perf Comment run](https://github.com/hashie/hashie/actions/runs/46143085591) fetched both reports and logged `duel comment: no comment`; #661 was the same. The results are in the Duel jobs' logs of the [Perf run](https://github.com/hashie/hashie/actions/runs/46142873379).

`c.comment = :results` in `.duel.rb` would post the report on every run that compares benchmarks; a PR for that can follow if that's preferred.

---
