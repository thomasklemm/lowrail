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

## Astra: changes on the reply draft

Reviewed independently on 2026-11-28 in thread `T-01a222b5-550c-7735-9974-600d25c90350`. No delegation,
upstream posts, workflow runs or changes to hashie or its fork. The verdict applies to this exact original text:

> Duel doesn't comment on a passing run by default. `.duel.rb` doesn't set [`c.comment`](https://github.com/sferik/duel-ruby/blob/v0.3.1/docs/configuration.md#choose-when-to-comment-on-a-pull-request), so the default, `:failures`, applies: it comments when a benchmark fails or Duel can't compare, and after such a comment once more when the result changes. Both Duel jobs passed here, so the [Perf Comment run](https://github.com/hashie/hashie/actions/runs/46143085591) fetched both reports and logged `duel comment: no comment`; #661 was the same. The results are in the Duel jobs' logs of the [Perf run](https://github.com/hashie/hashie/actions/runs/46142873379).
>
> `c.comment = :results` in `.duel.rb` would post the report on every run that compares benchmarks; a PR for that can follow if that's preferred.

### Findings and rival explanations

* **The cause is the comment policy.** I fetched the live logs of jobs 140973134632 (Perf Comment), 140972490241
  (YJIT) and 140972490523 (ZJIT), and downloaded the two artifacts from Perf run 46142873379. Both reports have
  `pr=662`, `comment=change`, `status=passed`. Both downloaded reports match the committed copies byte for byte.
  Loading hashie's current `.duel.rb` into the released gem leaves `Duel.config.comment == :failures`.
* **Not an unsettled-result trigger.** The YJIT job explicitly reports one unsettled timing, zero regressions and
  zero errors; its overall status is still passed. The ZJIT job passed too. Duel 0.3.1's actual `CLI.comment`
  returns `change` for passed and nothing-to-compare runs under `:failures`, and `post` for failed and error runs.
  An unsettled individual timing is not by itself a reason to comment in this run.
* **Not failure to resolve a fork PR.** The Perf run API's `pull_requests` array is empty, but that is not where
  Duel gets the number. `duel.yml` writes `github.event.pull_request.number` into `comment.env` during Perf;
  `duel comment` reads it and checks the current PR head against the source run's head. The observed log message
  occurs only after this check and the earlier-comments API call succeeded.
* **Not a missing artifact.** The comment job found and downloaded both named reports, then installed Duel 0.3.1
  and ran the comment command. Its full final line is
  `duel comment: no comment (the last comment says passed already)`. The draft quotes an exact prefix, not a
  different message. This line does not prove there was an earlier Duel comment: the gem produces it with no
  earlier comment too, which the offline probe reproduced using the real downloaded reports.
* **Not an observed token failure.** The job's effective token permissions include `PullRequests: write`;
  both workflow layers grant it. The run succeeded and reached policy suppression, before any POST. This
  establishes the cause without claiming to have tested a live comment write with that token; I did not.
* **Danger finds the destination differently, but both found it.** I read hashie's caller and
  `danger/danger-pr-comment`'s reusable workflow at v0.3.0. Danger reads `report.pr_number`, lists matching open
  PRs by source branch/repository/head, and verifies the report's number; Duel reads `comment.env` and verifies
  its PR's head. Neither needs `workflow_run.pull_requests[0]`. Danger defaults `comment-empty` to true;
  its posted report says “No issues found.” Different silence policies explain the contrast, not PR discovery.
* **Neither #660 nor #661 has a Duel comment in the paginated issue-comment responses.** I independently fetched
  all four Perf Comment jobs' logs and their source artifacts. For #661, run 46065084741 downloaded one report
  from 46064801194: `pr=661`, `comment=change`, `status=passed`, no earlier Duel comment, the same suppression.
  “#661 was the same” is true of the cause, not the report count. For #660, runs 46058882024 and 46071028106
  downloaded two reports each, from 46058787439 and 46070968046 respectively: `pr=660`, `comment=change`,
  `status=neutral`. All say “nothing to compare”: the watched files were unchanged. These were not measured
  passing comparisons. All downloaded artifacts match the copies above.

### Sentence, link and behavior checks

* The opening answers the question, but “doesn't comment on a passing run” is too absolute in isolation: a
  passing run after a failed or neutral comment does post under the default. Say why this passing run was quiet.
* “Can't compare” means a comparison error, not “nothing to compare,” which stays quiet without history.
  “Once more” can also suggest only one later update. The real code posts at subsequent status transitions:
  failed → passed → neutral → passed can each produce a comment. The approved text uses “comparison errors”
  and “later status changes.”
* **“Every run that compares benchmarks” is too broad for hashie.** Its Perf workflow also allows
  `workflow_dispatch`; the pinned comment workflow only handles non-cancelled source `pull_request` runs, and
  its command skips a stale PR head. With `:results`, the two passing reports produce one new comment containing
  `## yjit` and `## zjit`, including on a later passing run. This is not two comments or an edit to one old
  comment. The offer should concern passing PR runs, without promising delivery for every run.
* All three URLs in the original resolve: I fetched both Actions pages and their API metadata, and the docs
  HTML. The anchor `choose-when-to-comment-on-a-pull-request` exists. The Perf logs really contain the benchmark
  results. I make no claim about a rendered Actions summary or signed-out access to the logs themselves.
* Hashie's current master is `f608fb16a98df6c99471e22b32e5a28bec4d7001`. Its Duel Gemfile pins 0.3.1; its two
  reusable workflows pin `3c0c99d95dc2d5620f59e4bb298179422086adf7`, and the comment workflow installs exactly
  0.3.1. The v0.3.1 tag currently resolves to that SHA. The original tag URL is version-specific, but a tag can
  move; the approved text uses the full SHA as required by the permalink rule. I fetched that URL and verified
  the same anchor and documentation contents. Current duel-ruby main retains the same `COMMENTED` policy.
* The original is plain and contains no internal material. Its final offer is optional, not a push to change
  policy, but it omits our choice in #659. That PR added `.duel.rb` without a comment override, as its actual
  file patch confirms. The approved text owns that choice and offers a small change only if preferred.

### Relevance and currency

Checked live GitHub repository metadata and RubyGems metadata on 2026-11-28:

| Project | Stars | Gem downloads | Last push / latest gem release |
| --- | ---: | ---: | --- |
| hashie/hashie | 3,035 | 507,141,361 | push 2026-11-28; hashie 6.0.0 released 2026-11-11 |
| sferik/duel-ruby | 21 | 8,813 | push 2026-11-25; duel 0.3.1 released 2026-11-22 |
| danger/danger-pr-comment | 0 | not a gem | push 2026-11-18 |

None is archived. Hashie is the repository being answered; Duel is the exact installed tool whose behavior
the maintainer asked about, not a popularity example. Its small reach is not a reason to omit the relevant
primary documentation. No newer Duel gem release supersedes the cited version. Danger was checked because
the question contrasts its comment, but the approved reply need not name its repository. There is no list
of ecosystem examples to reorder by reach. These are registry metadata counts, not performance measurements.

### What I ran

* Read `AGENTS.md` and `docs/DECISIONS.md`; fetched origin/main and verified it contains `ba1b9347`.
* `gh api repos/hashie/hashie/actions/runs/{RUN}/jobs`, then
  `gh api --allow-escape-sequences repos/hashie/hashie/actions/jobs/{JOB}/logs` for the two Perf jobs and all
  four Perf Comment runs listed above; `gh api repos/hashie/hashie/actions/workflows/perf-comment.yml/runs`
  confirms those are the four runs currently returned.
* `gh api repos/hashie/hashie/actions/runs/{RUN}/artifacts`, then the `/actions/artifacts/{ID}/zip` endpoints
  for all four source runs; `unzip` and `diff -ru` against each committed reports directory: no differences.
* Paginated `gh api repos/hashie/hashie/issues/{659,660,661,662}/comments`, each PR endpoint, the specific
  maintainer comment endpoint, and `/pulls/659/files`; read the original question and the configuration patch.
* GitHub contents APIs for hashie's `.duel.rb`, `gemfiles/duel.gemfile` and Perf, Perf Comment and Danger Comment
  workflows on master; Duel's `duel.yml` and `duel-comment.yml` at `3c0c99d`, docs at v0.3.1 and the full SHA,
  CLI on current main, and Danger's reusable workflow at v0.3.0. Fetched the tag's commit and repository metadata.
* `curl -fsSL` for the two Actions page URLs, both tag and full-SHA docs HTML, RubyGems metadata for hashie and
  duel, and `https://rubygems.org/downloads/duel-0.3.1.gem`; `gem unpack` using local Ruby 4.0.9. Gem SHA-256:
  `6a5363b2ce2dd6c2eaaff99740c5b88ef14cb6dadec06ac71a8dd98563e53355`.
* Ran `/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby .amp/in/orb-backup/astra-duel/probe.rb`.
  It loads the gem's actual Config, CLI and Comment code, loads hashie's configuration, asserts all 16
  mode/status results, and calls `Comment#run` on downloaded reports and controlled copies. Only the GitHub
  transport is replaced with offline responses/captured writes; no network writes occur. It checks no-history,
  failed/passed/neutral history, repeated passing results, a stale head, and two-report combinations.
  Decisive output: `original two passing reports, no Duel history: 0 posts`;
  `results, two passing reports: 1 posts`; `results, passing again: 1 posts`;
  `results, obsolete PR head: 0 posts`; final
  `PASS: policy, history, current-head guard and combined-report checks; no network calls`.
  Script SHA-256: `48e3beb382cfa7af68c56d1758f72333b8fe632a81bed161aab4db8c64beae03`.
  Fetched sources, logs, artifact archives, script and full output remain in this thread's
  `.amp/in/orb-backup/astra-duel/`. Existing committed logs/reports retain the upstream evidence.

### Exact replacement approved by Astra

The original draft above remains unchanged. I approve this replacement, including the pinned documentation link:

> Duel stayed quiet because both jobs passed and there was no earlier Duel comment. I left [Duel 0.3.1's default](https://github.com/sferik/duel-ruby/blob/3c0c99d95dc2d5620f59e4bb298179422086adf7/docs/configuration.md#choose-when-to-comment-on-a-pull-request), `:failures`, in place in #659: it comments on failures or comparison errors, and on later status changes after a comment. The [Perf Comment run](https://github.com/hashie/hashie/actions/runs/46143085591) fetched both reports and logged `duel comment: no comment`; #661 stayed quiet for the same reason. The results are in the Duel jobs' logs of the [Perf run](https://github.com/hashie/hashie/actions/runs/46142873379).
>
> If you'd prefer reports on passing PR runs too, I can send a PR setting `c.comment = :results`; the YJIT and ZJIT reports would appear together in one comment.
