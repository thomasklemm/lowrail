# Why hashie's Perf Comment workflow posted nothing on HM5's PR (2026-11-28)

michaelherold merged hashie/hashie#662 (HM5) on 2026-11-28 at 13:12 UTC and asked there why no Duel comment appeared
next to Danger's ([comment](https://github.com/hashie/hashie/pull/662#issuecomment-7239768173)). This is the cause as
the runs show it, and the reply drafted for review.

**Posted 2026-11-28 15:19 UTC:** [reply draft 2](#reply-draft-2-exact-text-replaces-the-draft-above), unchanged, as
[issuecomment-7241379662](https://github.com/hashie/hashie/pull/662#issuecomment-7241379662), after Astra and thermos-sol
both approved that exact text (their sections below). The posted body was read back and matches the draft. No fix PR
is open or built; the reply offers one if the maintainers want comments on passing runs.

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

## Reply draft 2 (exact text; replaces the draft above)

Adopted on 2026-11-28 from Astra's replacement, word for word: it names the earlier-comment condition, owns that the
default was left in place, pins the docs link to the release commit and offers the change instead of describing it.
The first draft above stays as the reviewers quoted it. Everything between the rules is the comment.

---

Duel stayed quiet because both jobs passed and there was no earlier Duel comment. I left [Duel 0.3.1's default](https://github.com/sferik/duel-ruby/blob/3c0c99d95dc2d5620f59e4bb298179422086adf7/docs/configuration.md#choose-when-to-comment-on-a-pull-request), `:failures`, in place in #659: it comments on failures or comparison errors, and on later status changes after a comment. The [Perf Comment run](https://github.com/hashie/hashie/actions/runs/46143085591) fetched both reports and logged `duel comment: no comment`; #661 stayed quiet for the same reason. The results are in the Duel jobs' logs of the [Perf run](https://github.com/hashie/hashie/actions/runs/46142873379).

If you'd prefer reports on passing PR runs too, I can send a PR setting `c.comment = :results`; the YJIT and ZJIT reports would appear together in one comment.

---

## thermos-sol: approve on the reply draft

Reviewed independently on 2026-11-28 in thread `T-01a222b5-484d-77b5-a1ec-49033b95f099`. **Approve Reply draft 2
unchanged**, as present in Lowrail `5de87e38502eef4339c51ab8d667778b95c98d6a`. No wording changes or remaining
findings on that text. This is a text-and-evidence review using the thermos correctness rubric for claims, not a
code-change review. No delegation, upstream post, workflow dispatch, fork change or upstream push was made.

### Exact text approved

> Duel stayed quiet because both jobs passed and there was no earlier Duel comment. I left [Duel 0.3.1's default](https://github.com/sferik/duel-ruby/blob/3c0c99d95dc2d5620f59e4bb298179422086adf7/docs/configuration.md#choose-when-to-comment-on-a-pull-request), `:failures`, in place in #659: it comments on failures or comparison errors, and on later status changes after a comment. The [Perf Comment run](https://github.com/hashie/hashie/actions/runs/46143085591) fetched both reports and logged `duel comment: no comment`; #661 stayed quiet for the same reason. The results are in the Duel jobs' logs of the [Perf run](https://github.com/hashie/hashie/actions/runs/46142873379).
>
> If you'd prefer reports on passing PR runs too, I can send a PR setting `c.comment = :results`; the YJIT and ZJIT reports would appear together in one comment.

The two paragraphs, joined by one blank line and with no trailing newline, have SHA-256
`afbc9d09034d171cae7e458e377db4eabc78254917b4653c34a21e09fded876b`. This approval applies to those exact words
and links, not the superseded first draft or my earlier uncommitted alternative. The draft and Astra's record above
are unchanged.

### Independent primary-source findings

* **Cause, not a workflow failure:** Perf 46142873379 ran the two Duel jobs successfully. Both artifacts contain
  `pr=662`, `comment=change`, `status=passed`. Perf Comment 46143085591 downloaded both and printed
  `duel comment: no comment (the last comment says passed already)`. The gem prints that line even with no
  earlier comment; it does not establish an earlier passing comment. Paginated REST and GraphQL responses,
  including minimized comments, contain Danger's comment and the maintainer's question, but no Duel comment.
* **Default and our choice:** hashie master was `f608fb16a98df6c99471e22b32e5a28bec4d7001`. Its `.duel.rb`
  is identical to the file at the measured PR head and does not set `c.comment`. The actual #659 file patch
  introduced it that way. Loading this configuration with the released Duel 0.3.1 gem yields `:failures`.
  No motive for that choice is claimed. The caller workflows pin the reusable workflows at
  `3c0c99d95dc2d5620f59e4bb298179422086adf7`; its comment workflow installs exactly Duel 0.3.1.
* **Not only regressions; not unsettled results:** the actual `CLI.comment` returns `post` for `failed` and
  `error` under `:failures`, and `change` for `passed` and `nothing_to_compare`. `Comment#comment` also posts
  when a previous Duel comment has a different status. The actual YJIT report has one unsettled timing but an
  overall passed status; the ZJIT report has none. An unsettled timing alone does not trigger a comment.
  Comparison errors are distinct from benign nothing-to-compare runs.
* **Not a fork-PR lookup failure:** the run API's `pull_requests` arrays are empty, but Duel does not use them.
  The reusable Perf workflow writes the original `github.event.pull_request.number` into `comment.env`.
  The comment command reads `pr=662` and verifies the current PR head against `--head` before checking prior
  comments. It could not reach the observed log line if the number were unresolved or the head mismatched.
* **Not a missing report:** the log says `Found 2 artifact(s)` and `Total of 2 artifact(s) downloaded`.
  Independently downloaded artifacts 15262822161 and 15262741434 contain both expected files. Both pairs match
  the committed copies byte for byte. The same comparison succeeded for every report of the other three runs.
* **Danger finds the PR differently, but both found it:** Danger v0.3.0 reads `report.pr_number`, lists open PRs
  by source owner/branch and verifies the head, repositories and base. Duel reads its report's number and
  verifies the head. Neither relies on `workflow_run.pull_requests[0]`. Danger defaults `comment-empty` to
  true; its "No issues found" comment is therefore consistent with a quiet first passing Duel run. The actual
  Danger Comment run 46142911941 used that workflow at `645e89bcc7be89ee7e8362166110b05cbced8e59` and
  `COMMENT_EMPTY: true`. The difference in discovery did not cause this silence.
* **#660:** no Duel comment in REST or GraphQL. Its two Perf Comment runs, 46058882024 and 46071028106,
  downloaded two reports each from 46058787439 and 46070968046. Every report says `pr=660`, `comment=change`,
  `status=neutral` and "nothing to compare": the watched files were unchanged. The PR changed the workflow,
  vocabulary, changelog and contribution docs, not the code/configuration/benchmarks Duel watches. Both logs end
  `duel comment: no comment (the last comment says neutral already)`. Without an earlier Duel comment,
  suppression is expected.
* **#661:** no Duel comment in REST or GraphQL. Its original workflow ran only YJIT, not the later two-job
  matrix. Perf 46064801194 has one successful job and one report saying `pr=661`, `comment=change`,
  `status=passed`. Perf Comment 46065084741 downloaded it and printed the same passed-status suppression line.
  Thus draft 2's "stayed quiet for the same reason" is accurate without implying two reports on #661.

All four Perf Comment runs were fetched independently with `gh api`. The live run list contained exactly those
four runs. All seven artifacts' `comment.env` and `duel.md` files matched the already committed evidence.

### Sentence and link checks on draft 2

1. **Opening cause:** both successful jobs, both passed report statuses, no prior Duel comment and the actual
   command's control flow establish it. It answers the question in the first sentence without a blanket claim
   that passing runs can never comment.
2. **Default left in #659 and its behavior:** checked the merged configuration patch, current/PR-head config,
   pinned reusable workflows, gem source and docs. "Later status changes after a comment" allows repeated
   transitions and distinguishes comment history from run history. "Comparison errors" avoids confusing an
   error with the benign nothing-to-compare case.
3. **Both reports fetched, quoted log text, #661:** complete step logs and the downloaded artifacts establish
   these. `duel comment: no comment` is an exact prefix of the real log line, not a claim to quote the full line.
   #661 shares the cause, not the report count.
4. **Where results can be read:** opened the linked Perf page, fetched its job metadata and downloaded the
   logs. The Compare steps in jobs 140972490241 and 140972490523 contain individual benchmark results and final
   verdicts. The two `duel.md` artifacts also contain them. I make no claim about the rendered summary or
   signed-out access to the logs; neither is promised by this text.
5. **Offer and one combined comment:** ran the released gem's actual policy and comment code. Under `:results`,
   `passed`, `failed` and `error` give `post`, while `nothing_to_compare` gives `change`. With the two actual
   passing reports and those policy outputs, `Comment#run` makes one captured post containing both `## yjit`
   and `## zjit`, including the unsettled row. It also posts one combined comment after an earlier passed
   comment. The workflow downloads all named reports into one directory and calls `duel comment` once. This
   establishes the offered behavior without claiming a live write or a new Actions run was tested.

Opened all three exact URLs in draft 2: the full-SHA docs URL, Perf Comment 46143085591 and Perf 46142873379.
Both run pages identify the expected successful workflow. Fetched the pinned docs page's HTML as well: it has
`id="user-content-choose-when-to-comment-on-a-pull-request"` and
`href="#choose-when-to-comment-on-a-pull-request"`, so the anchor is valid. The v0.3.1 annotated tag resolves
to the full commit in the link; its config, CLI, comment source and configuration docs match the gem's files.
Every sentence and link was checked against commands I ran or pages I opened, not Astra's conclusions.

### Reader's verdict and first-draft notes

Draft 2 is short and plain, answers first, has no filler, pings or internal details, and owns leaving the default
in #659. The last sentence is a fair conditional offer, not pressure to change the policy. It should say neither
more nor less for this question. I would not change a word.

On the superseded draft I had wording nits about making our choice explicit and the ambiguous "#661 was the same"
after a reference to two jobs. Its "every run" promise was also broader than the actual workflow, which permits
manual Perf runs but only comments on non-cancelled PR runs, and still checks the current PR head. Draft 2 resolves
these points; none is carried forward as a finding. The earlier uncommitted review was saved locally before
pulling the replacement and was not applied over the other reviewer's additions.

The repositories named by the reply are the actual incident's project and tool, not incidental reach examples.
Live GitHub metadata shows both unarchived and recently pushed; RubyGems reports Duel 0.3.1 as current. Their
stars/downloads were checked too, but do not belong in the reply or affect whether the relevant docs are cited.

### What I ran

* Read `AGENTS.md` and `docs/DECISIONS.md`, especially What needs Thomas, Upstream etiquette, Nothing internal
  upstream, PR descriptions and Claims are checked, behaviour changes are probed. Loaded the correctness review
  skill without delegating. Inspected status, remotes, HEAD and shallow state; this checkout is not shallow.
* `gh api repos/hashie/hashie/actions/runs/ID` for 46143085591, 46142873379, 46058882024, 46065084741,
  46071028106, 46058787439, 46064801194 and 46070968046; the `/jobs?per_page=100` endpoints for the first
  two and 46064801194. Fetched `perf-comment.yml/runs?per_page=100` and `danger-comment.yml/runs?per_page=20`.
* `gh api repos/hashie/hashie/actions/runs/ID/logs`, then `unzip -q`, for all four Perf Comment runs,
  Perf 46142873379 and Danger Comment 46142911941. Read and searched the complete step logs.
* `gh api repos/hashie/hashie/actions/runs/ID/artifacts` for all four source Perf runs, then
  `/actions/artifacts/ID/zip` for all seven artifacts; `unzip -q`, `cat`, `head` and `diff -u` against
  each committed report's `comment.env` and `duel.md`.
* `gh api repos/hashie/hashie/commits/master`; contents APIs for `.duel.rb`, Perf, Perf Comment,
  Danger Comment and CONTRIBUTING on master, `.duel.rb` at #662's exact head and Perf at #661's exact head;
  decoded `.content` with `base64 -d`. Read the two reusable Duel workflows at full `3c0c99d` SHA.
* `gh api repos/hashie/hashie/pulls/N`, paginated `/issues/N/comments?per_page=100` for 659–662,
  `/pulls/659/files?per_page=100` and `/pulls/660/files?per_page=100`. Also queried 660–662 using
  `gh api graphql` for author, body, minimized state and `hasNextPage` (false for all). Refetched #661/#662
  comments while checking draft 2. Read the maintainer's exact question through those API results.
* Contents APIs at the full Duel release SHA for `lib/duel/{config,cli,comment}.rb`, `docs/configuration.md`
  and `duel.gemspec`; v0.3.1 ref and annotated-tag endpoints. `diff -u` against the gem's extracted files.
* Danger's v0.3.0 recursive tree and reusable comment workflow through `gh api`, then the workflow at the
  actual run's resolved SHA; `diff -u` confirmed identical content. Read the source and actual step log.
* `read_web_page` opened both Actions URLs, the original tag docs URL and draft 2's exact full-SHA docs URL.
  `curl --fail --silent --show-error --location` fetched both docs HTML pages; `rg` checked their anchor.
* `curl --fail --silent --show-error --location https://rubygems.org/downloads/duel-0.3.1.gem`, `sha256sum`,
  `tar xf` and `tar xzf`. Gem SHA-256 is
  `6a5363b2ce2dd6c2eaaff99740c5b88ef14cb6dadec06ac71a8dd98563e53355`, matching the Perf logs' lockfile checksum.
* `gh api repos/hashie/hashie` and `gh api repos/sferik/duel-ruby` for archive state, stars and last push;
  RubyGems `/api/v1/gems/{duel,hashie}.json` through `curl` for current versions, release dates and downloads.
* `/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby -v` and
  `/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby -I .amp/in/orb-backup/no-comment-sol/source/gem/lib .amp/in/orb-backup/no-comment-sol/probe/policy.rb`.
  It loads the downloaded gem's unmodified Config, CLI and Comment code and hashie's exact configuration,
  asserts all 16 mode/status results, then runs the real comment decision and report formatting on downloaded
  reports. Only transport reads and posts are replaced by offline responses and in-memory capture. Script SHA-256:
  `85f6193f0aae4ee95352a8dbd2b767b5199a66deeddb706965f00b05e603f75a`.
  Decisive output:

  ```text
  Hashie's unmodified .duel.rb: :failures
  results: passed=post, failed=post, nothing_to_compare=change, error=post
  failures: passed=change, failed=post, nothing_to_compare=change, error=post
  662 actual reports, no earlier Duel comment: posts=0; duel comment: no comment (the last comment says passed already)
  662 actual reports, earlier failed: posts=1; duel comment: commented on pull request 662
  662 actual reports, earlier passed: posts=0; duel comment: no comment (the last comment says passed already)
  662 with :results, no earlier Duel comment: posts=1; duel comment: commented on pull request 662
  662 with :results, earlier passed: posts=1; duel comment: commented on pull request 662
  660 actual neutral reports, no earlier Duel comment: posts=0; duel comment: no comment (the last comment says neutral already)
  660 neutral reports, earlier passed: posts=1; duel comment: commented on pull request 660
  661 actual passing report, no earlier Duel comment: posts=0; duel comment: no comment (the last comment says passed already)
  PASS: policy matrix and offline real-report paths; no network or upstream writes
  ```

Fetched primary sources, logs, artifact archives, probe and full output remain in
`.amp/in/orb-backup/no-comment-sol/`. The decisive output is retained above; the underlying upstream reports and
logs were already committed. No new performance measurement or timing claim was made.
