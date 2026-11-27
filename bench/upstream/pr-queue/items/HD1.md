---
id: HD1
repo: hashie/hashie
fork: thomasklemm/hashie
kind: feature
area: CI, Duel performance regression guards (.duel.rb, benchmarks/, perf.yml, perf-comment.yml, gemfiles/duel.gemfile, Gemfile)
reviewer: dblock
branch: thomasklemm/duel
head: "bcf21e76c40d212ac66b9a168cd611d84d191a8f"
base: master
built_on: "812c48ca7b"
tracker: [hashie/hashie#658]
depends_on: []
stacked_on:
alternative_of:
impact: "Every hashie PR that touches lib/ gets a Duel check (Ruby 4.0, YJIT, one benchmark at a time) of 21 scenarios in benchmarks/ on Mash, Dash, Trash and extension hot paths, replacing the four benchmark-ips scripts, as dblock asked in #658 and on #659. Calibrated on the fork at jobs=1: 0 false alarms in 35 runs on identical code, both planted regressions failed (13 and 4-5 benchmarks), #656 0/4 slower; a passing run takes about 90 s."
evidence: [bench/upstream/hashie_duel]
rank:
risky: false
state: draft
pr: 659
note: "2026-11-27 reply to dblock posted by Thomas's approval (issuecomment-7216282843, short SHA bcf21e7). Thomas then approved a second commit on #659 instead of a stacked PR: candidate a00b9abb3d on fork branch thomasklemm/duel-coverage (one commit on bcf21e7) adds 6 scenarios (IndifferentAccess new/read/write, DeepFind+DeepFetch, Dash IndifferentAccess from String keys, nested Dash coercion; 27 total) and sets c.measure('cpu', limit: 1.05) and c.processes = 24. Round 7 showed that more processes at limit 1.02 fail identical code (3/5 at 24, 3/5 at 12 with the new scenarios): comment-only trees shift method-dispatch timings 3-7% for a whole run. Round 8 (calibration-8): A/A 0/20, none re-measured, 6/540 unsettled, job 124-137 s; CPU plant 4 regressed x2; allocation plant 13 (432 s); #656 candidate (fork PR #9) 0/3 slower, faster on 5-6. Ruby 4.0.9 rake 1,076/0, Ruby 3.0.7 spec 1,072/0, rubocop clean. Thermos-sol delta review requested; push and body update wait for its approve. 2026-11-27 Thomas approved the push: master still 812c48c, so no rebase; force-pushed bcf21e7 to thomasklemm/duel with lease on c4303d5; PR body PATCHed to the combined layout (21 scenarios, jobs=1 calibration) and read back identical; reply to dblock drafted, not posted (Thomas reviews it first). Upstream checks on bcf21e7 ran without approval (Thomas is no longer first-time after #656) and all 15 passed; Perf run 45983825333: 21 benchmarks in 69s, 0 regressed, 4 unsettled, job 105 s. 2026-11-26 thermos-sol delta (T-01a21832) changes on 87a9f22: R1 CONTRIBUTING wording and R2 README cause paragraph applied with the reviewer's exact text; #656 merged as 812c48c, so the layout is rebased as bcf21e76c4 on thomasklemm/duel-benchmarks (one commit on 812c48c) and also deletes benchmarks/mash_new_keys.rb. Ruby 4.0.9 rake spec 1,076/0, Ruby 3.0.7 1,072/0, rubocop clean. Round 6 on bcf21e7: A/A 0/15, none re-measured, plants 13/5. Confirm pass requested. 2026-11-26 dblock asked to combine duel/ and benchmarks/ (issuecomment-7192448526). Candidate 87a9f2254e on fork branch thomasklemm/duel-benchmarks (one commit on e1adebc; PR branch untouched at c4303d5): duel/ -> benchmarks/, three benchmark-ips scripts replaced by 8 extension/plain scenarios (21 total), benchmark-ips/benchmark-memory out of the Gemfile, CONTRIBUTING one kind, CHANGELOG [#659], c.jobs = 1 after two false failures at 2 at a time (rounds 3-4); round 5: A/A 0/20, candidate 0/4 slower, plants 13/4 (bench/upstream/hashie_duel/README.md). Ruby 4.0.9 rake spec 1,075/0, Ruby 3.0.7 1,071/0, rubocop clean. Push and reply wait for Thomas; thermos-sol delta review requested. 2026-11-26 thermos-sol changes on 9c30091 applied as c4303d5 (same parent e1adebc): R1 Trash with: -> transform_with: (topics now \"octocat, api\"); R2 narrative comments deleted at the given ranges, null-logger why-line kept; R3 the reviewer's short body plus one calibration paragraph and the approval note, which Thomas's brief requires in the body (approval verified: our #656 runs upstream are action_required); commit message JSON sentence corrected. CHANGELOG nit declined: hashie's CHANGELOG and release spec CATEGORIES have no Miscellaneous section, so Added stays. Ruby 4.0.9 rake spec 1,075/0, rubocop clean. Recalibration on c4303d5 (calibration-2): A/A 0/10 failed (one Dash.new required remeasure, cleared, the same benchmark as cohort 1's only remeasure), allocation plant 8 regressed, CPU plant 2, candidate faster on 5 and slower on none; body now says 35 A/A runs (25 + 10, same lib/). 2026-11-26 built: one commit 9c30091 on master e1adebc (fork master fast-forwarded to e1adebc), Thomas Klemm author and committer, no trailers, fork pre-push hook installed. Requested by dblock in #658 (he wrote it for us on #656; Thomas agreed publicly there). Calibration on fork PRs #1-#8 against duel-calibration (= 9c30091), see bench/upstream/hashie_duel/README.md. Local: Ruby 4.0.9 rake spec 1,075 examples 0 failures, rake rubocop clean, duel --force A/A 0 regressed. Benchmarks chosen from profile-hotlines (Mash in Huginn 6.2% of job objects, Forem 0.9%), HM1 and dblock's benchmarks/mash_new_keys.rb; fixture is the octocat repository payload of HM1's body. README badge: Duel's own static badge (README.md 'Without the job, use Duel's own badge'), which needs no duel/badge branch or push job, as in Grape. Kind feature added to script/pr-queue KINDS for this item. Manual ownership check 2026-11-26, open and closed: no hashie PR or issue names Duel, a perf workflow or regression benchmarks except #658; #658 has no assignee or comments, labels chore and 'you can help!', only cross-reference #656 (ours); latest 15 PRs are dblock release tooling (#643-#657), dependabot and #656."
ownership: {date: 2026-11-26, checked: ["open PRs naming repository_attributes that change .duel.rb, .github/workflows/perf-comment.yml, .github/workflows/perf.yml, .gitignore, .rubocop.yml, .spellcheck.txt, CHANGELOG.md, CONTRIBUTING.md, README.md, duel/dash_duel.rb, duel/duel_helper.rb, duel/fixtures/repository.json, duel/mash_duel.rb, gemfiles/duel.gemfile","hashie/hashie#658 and what references it"], hits: ["tracker: hashie/hashie#658 (open): Add Duel performance regression guards","references hashie/hashie#658: hashie/hashie#656 (PR, open, thomasklemm): Write new Mash keys without allocating in respond_to_missing?"]}
passes:
  - {reviewer: thermos-sol, head: "9c3009161ec0e259e7863d9b3b92864da5589bd0", date: 2026-11-26, orb: T-01a217c1-624d-774b-b3ad-3946a5260e8a, verdict: changes, open: "R1 use transform_with for the Trash benchmark; R2 delete narrative code comments; R3 shorten the PR body and correct the input and calibration wording"}
  - {reviewer: thermos-sol, head: "c4303d510262c31290fe11dd845d38bc9bc999bd", date: 2026-11-26, orb: T-01a217c1-624d-774b-b3ad-3946a5260e8a, verdict: approve, open: none}
  - {reviewer: thermos-sol, head: "87a9f2254eb5492408d327003f46dcd2c0f90f51", date: 2026-11-26, orb: T-01a21832-7ce1-758b-b1c2-ae5c2576a644, verdict: changes, open: "R1 correct CONTRIBUTING's cross-scenario comparison claim and acknowledge lost reports; R2 qualify the combined-layout README's contention explanation as a hypothesis"}
  - {reviewer: thermos-sol, head: "bcf21e76c40d212ac66b9a168cd611d84d191a8f", date: 2026-11-26, orb: T-01a21832-7ce1-758b-b1c2-ae5c2576a644, verdict: approve, open: none}
---

# Add Duel performance regression guards

Closes #658.

This ports ruby-grape/grape#3077 to Hashie. For changes to `lib/`, Duel compares pull requests with their target branch on Ruby 4.0 with YJIT and checks for CPU and allocation regressions.

The benchmarks live in `benchmarks/` and replace the four benchmark-ips scripts there, so `benchmark-ips` and `benchmark-memory` leave the Gemfile. The 21 scenarios cover Mash construction, key access, writes, `respond_to?`, `deep_merge` and `to_hash`; Dash and Trash construction, property access and coercion; and the KeepOriginalKeys and PermissiveRespondTo cases the old scripts compared by hand. Duel compares refs, so the old within-run comparison tables and byte counts are gone.

Duel has its own bundle in `gemfiles/duel.gemfile`, so Hashie's Ruby 3.0+ support is unchanged. Perf runs pull-request code with read-only permissions; a separate workflow posts reports without running that code. A maintainer can apply `duel: accept` for an intentional slowdown.

On [pull requests in my fork](https://github.com/thomasklemm/hashie/pulls?q=is%3Apr+%5Bcalibration%5D), 35 runs on comment-only changes to `lib/` all passed with one benchmark at a time (two at once failed identical code once in 20 runs), and two planted regressions failed 13 and 4–5 benchmarks. A passing run takes about 90 seconds.

## For Thomas

What it is: a CI job that, for each PR, benchmarks hashie's master against the PR in parallel worker processes and fails when the PR is slower or allocates more, plus a job that comments the result. dblock asked for exactly this in #658 as a copy of what sferik did for Grape.

Calibration in one sentence: on GitHub runners, 25 runs of identical code never failed, both deliberate regressions failed, and #656 shows as faster, so the gate keeps Duel's defaults (limit 1.02, YJIT). The one caveat is the thin margin: identical code shows medians up to about 1.03 on some runners for a few benchmarks, although only one run required remeasurement (four unsettled repeats), and 79 of 325 final benchmark timings were unsettled; `c.measure("cpu", limit: 1.03)` in `.duel.rb` is the one-line fallback if dblock ever sees a false alarm.

Not in the port: Grape's Rakefile task for Duel (not asked for in #658), and the badge job (the static badge needs none).

### Thermos-sol review — 2026-11-26

**Verdict: changes.** Reviewed the single Hashie commit `e1adebc3de7f48c7aa3f1f9f73c97676102f34a3` → `9c3009161ec0e259e7863d9b3b92864da5589bd0`, its message, every sentence of the proposed body, the internal notes and metadata, and the calibration evidence. Both Thermos rubrics were applied here by the same reviewer, without subagents or other threads; this is not two independent reviews. Read Hashie's AGENTS.md and CONTRIBUTING.md, Grape's merged #3077 and discussion, and Duel's README plus docs/ci.md, docs/configuration.md, docs/benchmarks.md and docs/how-it-works.md at `3c0c99d95dc2d5620f59e4bb298179422086adf7` (verified v0.3.1). References to Hashie lines below mean the reviewed head. The proposed body and item state above are deliberately unchanged.

#### Must-fixes and smallest fixes

**R1 — P2, the Trash benchmark does not transform anything.** At `duel/dash_duel.rb:23`, `with:` is only used when `from:` is present (`lib/hashie/extensions/dash/property_translation.rb:122–135`). Here `RepositoryTrash.transforms` is `{}`, and running the actual benchmark returns `topics == ["octocat", "api"]`, not the advertised joined string. Consequently it cannot guard transformation regressions. Change exactly one keyword:

```diff
-  property :topics, with: ->(topics) { topics.join(', ') }
+  property :topics, transform_with: ->(topics) { topics.join(', ') }
```

An in-memory replay of that substitution returns `title == "octocat/Hello-World"`, `stars == 80`, and `topics == "octocat, api"`. Do not change Hashie's implementation or add another benchmark/helper to compensate. Recheck this corrected benchmark's output and A/A before carrying the review forward to a new head; the existing calibration measured the non-transforming version.

**R2 — delete the narrative code comments.** Lowrail DECISIONS makes unnecessary comments a review blocker, including benchmark files; copying them from Grape does not waive it. The added executable/configuration files contain 58 full-line comments among 236 added lines, mostly narration of adjacent code. Exact deletion ranges: `.duel.rb:3–8,10–12`; `duel/dash_duel.rb:5–7`; `duel/mash_duel.rb:5–6`; `duel/duel_helper.rb:6–8`; `.github/workflows/perf.yml:3–8,20–21,30,32,37,39,41–43`; `.github/workflows/perf-comment.yml:3–13,25`; `gemfiles/duel.gemfile:3–7,11–12`. Keep frozen-string directives, the inline version annotations and concise permission reasons. Replace `duel/duel_helper.rb:11–12` with the one useful why-line `# Keep collision checks without timing log output.` No new abstraction or replacement documentation is needed: CONTRIBUTING already gives the local commands, and the code names the inputs and workflows.

**R3 — cut the report-like proposed body and correct the input/calibration wording.** The body is 423 words, substantially beyond DECISIONS' 50–120-word normal shape and approximately 150-word ceiling. It includes test-run history, pins, fork calibration, a link to our trial PRs and speculative run-approval instructions. These belong here, not in the posted body. Its universal client/fixture claims and `to_hash` “of the result” are also inaccurate. Replace the body, not the title, with these three short paragraphs:

```markdown
Closes #658.

This ports ruby-grape/grape#3077 to Hashie. For changes to `lib/`, Duel compares pull requests with their target branch on Ruby 4.0 with YJIT and checks for CPU and allocation regressions. The 13 benchmarks cover Mash construction, key access, writes, `deep_merge` and `to_hash`, plus Dash defaults, property access and coercion, and Trash renaming and transformation.

The benchmark bundle is separate, so Hashie's Ruby 3.0+ support and main dependencies are unchanged. Perf runs pull-request code with read-only permissions; a separate workflow posts reports without running that code. A maintainer can apply `duel: accept` for an intentional slowdown.
```

That wording assumes R1 is fixed. In the commit message, replace `Their input is a fixture parsed with Ruby's JSON, so both versions get the same Hash.` with `The API response fixture is parsed with Ruby's JSON.` Not every case uses the fixture: coercion deliberately starts with string/symbol values and new-key writes start with empty Mashes. In the internal calibration paragraph, replace `although only one run required remeasurement (four unsettled repeats), and 79 of 325 final benchmark timings were unsettled` with `although only one run required remeasurement (four unsettled repeats), and 79 of 325 final benchmark timings were unsettled`. This preserves the successful calibration without implying that all near-limit timings were remeasured or cleared.

#### Correctness, security and maintainability

* **Mash's nine cases:** construction includes the conversion being measured; three ordinary method reads, the three suffix readers, and bracket/dig readers exercise distinct dispatch paths. New-key writes use Duel's batched `n` interface and `untimed` to construct a fresh Mash for each measured write, rather than becoming overwrites after the first iteration. Overwrite, `respond_to?`, non-mutating nested `deep_merge`, and `to_hash` use `once` for input construction. The merge and conversion cases are independent; conversion is not performed on the merge result. Repeating the actual definitions did not alter the shared JSON fixture. No randomness, clock/network input or accumulating keys was found. The null logger removes output I/O, not the collision-check path. Fixed batching/loop overhead is the same for each version.
* **Dash/Trash's four cases:** required/default construction, combined reads/writes, renaming, and coercion are direct, different public operations. Fixture slicing, key conversion and coercion input construction happen in `once`; the constructor's own work remains measured. Defaults, renames and asymmetric coercion outputs are correct. Transformation is the single misleading case, R1. A semantic probe through Duel's actual harness checked all 13 definitions: 12 met their named output contract, the Trash case failed exactly as described, and the 24-key shared fixture remained unchanged after repeated calls. No other materially redundant case or obvious missing hot path from the requested Mash/Dash/Trash scope warrants expanding this port.
* **Execution permissions:** `Perf` is `pull_request`/`workflow_dispatch`, not privileged `pull_request_target`; top-level permissions are empty and its job receives only contents/PR read. No inherited secrets are passed. The pinned reusable workflow checks out with `persist-credentials: false` and full history. The comment workflow receives write permissions separately. Its `workflow_run` path downloads reports and installs exact Duel 0.3.1 without checking out or executing PR code; its `pull_request_target` path only reacts to the accept-label change and reruns the matching Perf run. The called jobs narrow actions access to read for commenting and write for rerunning. Report parsing allowlists fields and checks the PR head against the run SHA; artifact text is not executed as shell. No demonstrated fork/token escalation or untrusted-checkout issue was found. The fork did not exercise the comment workflow because it is not on its default branch; this part is a source audit, not an end-to-end approval/comment test.
* **Pinning and filters:** both reusable workflow pins resolve to Duel v0.3.1; its nested actions are SHA-pinned and the separate bundle pins `duel` to 0.3.1. Filters include library, benchmarks, configuration, gemspec, Duel Gemfile and Perf workflow changes, matching the Grape port's approach. Duel's own watch rules can still skip gemspec/Gemfile-only changes. No docs-only check or per-PR badge-push job is promised. The README badge is intentionally Duel's static badge, documented for use without a badge job; its image is not a live passing-status claim.
* **Compatibility and boundaries:** `Gemfile`, `hashie.gemspec`, `Rakefile`, `lib/` and existing test workflow are byte-for-byte unchanged. The gemspec still permits Ruby 3.0+, and the main bundle has neither Duel nor StackProf. The 3.4+ requirement applies only to the optional Duel bundle. The spellcheck additions are intentional terms; RuboCop's multiple-class exclusion is confined to `duel/` and no existing baseline is expanded. CHANGELOG retains the placeholder and author credit. Nit: CONTRIBUTING categorizes test-harness/CI work as Miscellaneous, so move the new line from Added to Miscellaneous, above that section's placeholder.
* **Structure:** the correct simplification is to keep the existing arrangement and delete narration, not introduce a wrapper or orchestration layer. Small benchmark files, one shared fixture/helper, one isolated bundle and two calls to canonical reusable workflows are cohesive. No new spaghetti branch in production code, oversized-file threshold crossing, duplicated workflow implementation or unjustified public abstraction was found. The helper is reused and removes actual repeated input selection.

#### Raw calibration reconciliation and threshold decision

Read all `calibration/*.summary.txt` and run JSON, reran `python3 -I bench/upstream/hashie_duel/tally.py`, and independently reconciled all 30 extracted job logs against their run metadata/timestamps and summaries. Fork PRs #1–#8 target `duel-calibration`, whose head is the reviewed port. Inspected their actual commits: A/A changes only comments; the allocation and CPU plants match the descriptions; the candidate's `lib/hashie/mash.rb` blob `a80d6bf9bb289009259c9ccb98d81ad1fdfbed6e` matches the referenced #656 head. No workflows were rerun during this review.

| Cohort | Raw result | Runtime |
|---|---|---|
| Identical code, five PRs × five attempts | 25/25 passed, zero regression/error conclusions; 79/325 final timings unsettled. Only aa-2 attempt 2 remeasured. | Job 47–84 s, median 58 s; Duel 33–64 s. |
| Allocation plant | Eight Mash benchmarks regressed; Mash.new 105.7 → 143.7 objects, method reads 5 → 15. Four Dash/Trash cases unaffected. | Duel 215 s; job 248 s. |
| CPU plant | Method reads 1.465–1.519× in all four measurements; allocations stayed at 5. | Duel 52 s; job 93 s. |
| #656 candidate, three attempts | Zero classified regressions; faster on 6, 3, 5 cases, with 5, 2, 4 unsettled timings respectively. The same five allocation reductions appear each time. | Jobs 94, 53, 54 s; Duel 40, 36, 37 s. |

The five candidate allocation reductions are Mash.new about 105.4–105.7 → 25.37–25.67; deep_merge 120.4–120.6 → 31.42–31.65; `respond_to?` 6 → 1; overwrite 9 → 6; new-key write 7 → 5. The body rounds one representative run correctly. Normal CI was green on A/A/candidate branches; the allocation plant failed allocation specs on supported Rubies and the CPU plant failed lint, as expected. No hidden failed Duel run or missing measurement was found in this cohort.

**Keep the default CPU limit of 1.02.** A median above 1.02 is not itself the failure criterion: the initial 99% interval must exceed the limit, and a slowdown must survive fresh-process confirmation. aa-2 attempt 2 initially reported Dash construction at 1.031 [1.021, 1.041]; four repeats were 1.019, 1.023, 1.025 and 1.022, all unsettled, not demonstrated equal. Other medians near 1.03 often never triggered remeasurement because their intervals overlapped the boundary. The data justify trying the shipped rule, not raising the limit merely to exceed the largest observed median. The across-the-board CPU threshold is separately 1.005. Widening the per-case limit to 1.03 would also change that threshold; it is not a no-cost noise switch. Zero failures in 25 trials does not prove a negligible false-alarm rate: even independent trials would give a one-sided 95% upper bound of about 11.3%. Neither more reruns until green nor preemptive threshold tuning is justified by these observations.

CPU and allocation metrics, but no instruction metric, appear in these logs. That establishes what this cohort measured; absence alone does not establish that every GitHub runner lacks hardware counters. The README's `perf_event_open`/orb-platform explanation is not independently established by the archived output. Use cohort-qualified wording if it is retained, rather than treating the host-capability diagnosis as measured fact. No instruction-count or general application-speed conclusion is drawn here.

#### Sentence-by-sentence body and commit audit

| Proposed body claim, in order | Finding |
|---|---|
| `Closes #658.` | Correct issue, opened by dblock specifically asking for the Grape port. |
| `This ports ruby-grape/grape#3077 to Hashie.` | Correct provenance; merged Grape diff uses the same architecture. |
| `On each pull request ... side by side ... Ruby 4.0 with YJIT ... fails if ... slower or allocates more.` | Implemented for matched paths, subject to Duel's limits, confirmation and accept label; not a guarantee that any positive noise fails. |
| `The Perf comment workflow ... runs none of the pull request's code ... duel: accept ...` | Source-verified, with the default-branch limitation stated above. |
| `Both call ... pinned to ... v0.3.1 commit.` | Exact pin verified; cut the version/pin narration from the body. |
| `Duel needs Ruby 3.4 ... own bundle ... out of the main one.` | Correct; main bundle/support unchanged. |
| `The 13 benchmarks are the paths API clients run on every response, built from one fixture ...` | Thirteen definitions, but the universal client claim is unjustified. Coercion and fresh-key writes do not take their inputs from the JSON. The fixture matches #656's hand-built repository-shaped payload, not evidence of an actual captured API response. |
| `Mash.new ... deep_merge ... to_hash of the result: the conversion every client pays for.` | The operations exist, but `to_hash` receives the original Mash, not the merged result; not every client performs these operations. Cut those claims. |
| `Reading keys ... writing ... respond_to? ...` | Accurate enumeration of the nine Mash cases. |
| `These go through ... collision check on every write, where #410 and #656 were.` | Writers do check collisions; readers are separate paths. #410 is an accessor regression report and #656 changes new-key/respond_to_missing? handling. The compressed historical attribution is less clear than the actual code; cut it rather than expand it. |
| `Dash.new ... Trash.new with renamed and transformed ... coercion.` | Defaults/access/coercion are exercised; transformation is false until R1. |
| `Before opening, I ran ... fork ... branch that has this commit.` | Correct branch topology, but unnecessary process narration upstream. |
| `Five ... only a comment ... five times ... 25 ... none failed.` | Exact match to the branches and 25 run records. Cut from posted body. |
| `In one run Duel measured one Dash benchmark again before passing it.` | Correct, with four unsettled repeats, not four clean equivalence results. |
| `convert_key ... Symbol#to_s ... 8 ... 106 to 144 objects ... key? three times ... 1.5x.` | Both plants and rounded numbers match code/raw logs. |
| `#656 ... faster on 3 to 6 ... three runs ... slower on none.` | Correct as classified verdicts; some timings were unsettled. |
| `A run with nothing slower takes about a minute ... regression ... two to four ... measures again.` | Ordinary-run description matches 47–84 s. Regression jobs were specifically 93 and 248 s, so use those if retaining numbers; they do not establish a general 2–4-minute range. |
| `GitHub's runners don't expose instruction counts, so CPU time and allocation counts decide.` | Second clause verified for these logs; universal platform diagnosis is not established by the raw record. Cut the sentence from the body. |
| `Runs on the fork` link | Correctly targets our calibration PRs, but the process/evidence link belongs here rather than in the short upstream body. |
| `Perf ... needs a maintainer to approve this pull request's runs ...` | Whether approval is needed depends on Hashie's repository policy/contributor approval state, which was not verified. Do not promise a universal approval prerequisite. |
| `... compares the code with itself ... only duel/ and configuration change.` | The library is identical, so the comparison is A/A; the commit also changes docs, badge and CHANGELOG. Cut the imprecise rationale. |
| `Perf comment runs once it is on master.` | Correct GitHub trigger/default-branch requirement. |

The commit subject accurately describes the change. Its first paragraph's five claims (matched PR comparisons; fail on regression; separate safe commenting; accept label; target branch) are supported with the same threshold qualifiers. Its second paragraph lists real cases but incorrectly universalizes the JSON input; R3 supplies the exact sentence correction. Its last paragraph correctly separates Duel's Ruby requirement and bundle from Hashie's Ruby 3.0 support. The actual author and committer are both Thomas Klemm `<github@tklemm.eu>`, there are no trailers, and there is exactly one commit on the stated master. No internal queue IDs, Lowrail references or review names appear in the upstream commit/message.

For Thomas: “for each PR” should be read as path-filtered PRs and `master` as the target branch, not hard-coded master. The request/provenance, omitted Rake task and static-badge explanation are correct. R3 corrects the remeasurement wording; YJIT is an explicit workflow choice, not Duel's default (`jit` defaults to `none`). The hypothetical 1.03 fallback is not validated calibration or a recommendation to tune now. Item `head`, `built_on`, branch, repo/fork, evidence directory and `kind: feature` agree with the actual refs/files and queue parser. `reviewer: dblock` denotes the maintainer, not a review already performed. The metadata's “never slower” means no classified regression, not that all timings settled. Its historical local counts are supported; the ownership statement is a dated search, not a reservation. No state, impact, body or other metadata was changed by this review apart from appending this pass.

#### Executed verification and limitations

All commands used an isolated checkout of the exact reviewed Hashie head, not an installed gem. Ruby 3.0 used a separate worktree and bundle to avoid sharing Ruby 4's lockfile.

* Ruby 4.0.9: `CI=true bundle exec rake spec` — **1,075 examples, 0 failures**, 100% line coverage.
* Ruby 4.0.9: `bundle exec rake rubocop` — **124 files then 157 files, no offenses detected**.
* Ruby 3.0.7, Bundler 2.5.23: `CI=true bundle _2.5.23_ exec rake spec` — **1,071 examples, 0 failures**, 100% line coverage. The four-example difference is three existing release-preparation examples gated to Ruby >=3.3 and one Mash `dup` allocation example gated to MRI >=3.2. RuboCop was run on Ruby 4, as AGENTS requires Ruby >=3.2 for linting.
* Ruby 4.0.9 + YJIT: `BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec duel --force --base HEAD --json ../review-aa.json` — exit 0, **13 benchmarks in 34 s, 0 regressed, 0 errors, 7 unsettled**; across-the-board CPU 1.004 [0.999, 1.010], unsettled. Base and candidate commits in JSON both equal the reviewed head, uncommitted changes false. This is a single review A/A, not another calibration cohort, and was not rerun until green.
* Actual-definition semantic probe — the one reproducible Trash failure above, 12 other expected outputs, fixture unchanged; the one-keyword in-memory fix passes rename and transform expectations. Hashie working trees remain unmodified.

No Hashie branch was pushed, no PR was opened, no fork workflow was rerun, and nothing was posted upstream. This review does not certify the unexercised privileged comment/label workflow end to end or approve a later changed head.

### Thermos-sol confirm pass — 2026-11-26

**Verdict: approve; no open must-fixes.** Confirmed Hashie `c4303d510262c31290fe11dd845d38bc9bc999bd`, still one commit on `e1adebc3de7f48c7aa3f1f9f73c97676102f34a3`, against the previous reviewed head `9c3009161ec0e259e7863d9b3b92864da5589bd0` and this item at Lowrail `aa984944`. Applied both Thermos rubrics myself again without delegation. This confirm pass supersedes the original R1–R3 findings for the new head, not the historical evidence or limitations. The proposed body and state remain unchanged.

#### Fix confirmation and paragraph wording

* **R1 closed:** `RepositoryTrash` now uses `transform_with:`. Replayed all 13 actual Duel definitions: all expected outputs pass, including renamed title/stars and `topics == "octocat, api"`; repeated execution leaves the fixture unchanged. Both archived new-cohort runs and the local new-head A/A report Trash at 4 allocations instead of the old non-transforming case's 3.
* **R2 closed:** the exact diff removes the requested narrative comments. The only executable change is the transformer keyword; the other insertion is the short null-logger reason. Remaining directives, inline pins and permission comments are appropriate. No workflow semantics, production code, dependency isolation or other benchmark behavior changed.
* **R3 closed:** the commit uses the corrected JSON-fixture sentence, and the internal first-cohort sentence distinguishes remeasurement from unsettled timings. The public body drops the universal client/fixture claims and incorrect merge-result description. Its first three paragraphs retain the reviewed replacement. The added calibration paragraph is required by Thomas's updated brief; its presence is not a finding. At 159 words overall, the body remains concise given the specifically requested calibration and approval details.
* **Calibration sentence:** 35 comment-only A/A runs all passed across the two cohorts (25 old, 10 new); both kinds of planted regression failed. Eight allocation regressions are reproduced on the new head. The quoted method-read 1.5× is the first cohort's rounded 1.465–1.519×, not the new cohort's 1.404–1.445×; the paragraph aggregates the cohorts and does not claim all 35 runs used the corrected Trash definition. The new CPU plant also catches suffix reads. No wording change is required to make the aggregate historical claim true.
* **Candidate/runtime sentences:** #656 has classified faster results and no classified regression in either cohort; its new run has five faster cases and zero unsettled timings. “About a minute” matches the old 47–84 s and new 48–77 s passing job ranges. The body no longer claims a general regression runtime range or universal unavailability of instruction counters.
* **Approval/default-branch sentence:** independently read #656's current-head upstream Actions records. Both CI (`45810442812`) and Danger (`45810443805`) at `d874851d79db3a35b4cde8d2d6c567833ebb73f7` are `action_required`. This supports the explicit maintainer-approval note for this contributor's fork PRs here; it is not an assertion that every contributor always needs approval. Perf comment still requires its workflow on the default branch. The rest of the body and commit claims remain supported by the unchanged code and pinned reusable workflows.
* **CHANGELOG nit withdrawn:** CONTRIBUTING mentions Miscellaneous, but the actual CHANGELOG and `HashieReleasePreparation::CATEGORIES` support only Added/Changed/Deprecated/Removed/Fixed/Security, with earlier CI/tooling entries under Added. My earlier suggestion did not account for that executable category contract. Keep Added; do not add a category or expand this port.

#### Recalibration checked against raw evidence

Reran `python3 -I bench/upstream/hashie_duel/tally.py bench/upstream/hashie_duel/calibration-2` and independently checked all 13 archived logs against their summaries, JSON conclusions/job timestamps, current fork branch SHAs and parent commits. Each raw run contains all 13 initial benchmark cases. The five A/A heads have only their stated comment change; both plants have the intended library delta; the candidate Mash blob is still `a80d6bf9bb289009259c9ccb98d81ad1fdfbed6e`. All eight branch parents and the PR target now equal `c4303d5`. The logs run Ruby 4.0.10 + YJIT, distinct from local Ruby 4.0.9.

| New-head cohort | Confirmed result | Job / Duel duration |
|---|---|---|
| A/A, five branches × two attempts | 10 successes, zero regressions/errors; 26/130 reported final timings unsettled. | 48–77 s, median 54.5 s (55 s rounded) / 34–63 s. |
| Allocation plant | Eight regressed, zero errors; Mash.new 105.7 → 143.7 objects, method reads 5 → 15. | 238 s / 220 s. |
| CPU plant | Two regressed: method reads 1.404–1.445×, suffix reads 1.030–1.134× over their measurements; allocations unchanged. | 86 s / 69 s. |
| #656 candidate | Five faster, zero regressed/errors/unsettled; the same five allocation-reduction paths. | 50 s / 37 s. |

Only aa-3 attempt 2 remeasured: Dash required/default construction initially 1.026 [1.020, 1.033], then 1.021, 1.022, 1.028 and 1.025, all unsettled. It passed without demonstrating equality. Together with cohort 1 this is two remeasured runs, both on the same benchmark, and 0/35 failed runs. The note's word “cleared” means the check passed, not that the repeats established equivalent performance. Keep the default 1.02 CPU limit and the previous uncertainty caveat: this is useful additional calibration, not proof of a negligible false-positive rate or a reason to rerun/tune until green.

#### Fresh local checks and recordkeeping

* `CI=true bundle exec rake spec rubocop`, Ruby 4.0.9 — **1,075 examples, 0 failures; 124 then 157 files inspected, no offenses**.
* `BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec duel --force --base HEAD --json ../confirm-aa.json`, Ruby 4.0.9 + YJIT — **13 benchmarks in 30 s, 0 regressed, 0 errors, 2 unsettled**, exit 0. JSON confirms both commits are `c4303d5` and uncommitted changes are false; across CPU 1.000 [0.995, 1.006], unsettled. One local run only, with no rerun for a preferred result.
* All-definition semantic probe — **13/13 expected outputs**, transformed Trash topics, shared fixture unchanged. `Gemfile`, gemspec, `Rakefile`, library and existing test workflow are unchanged from the same parent. Ruby 3.0 was tested in the previous review, not rerun for this comment/benchmark-only follow-up.

The earlier frontmatter pass was retargeted to `c4303d5` in `aa984944`, although the earlier report explicitly reviewed `9c30091`; its R3 quote was also replaced inside the historical report. Those pre-existing edits are preserved here rather than silently rewriting someone else's changes. This appended approve entry is the actual first confirm coverage of `c4303d5`. For accurate historical pass attribution, the earlier entry's head should be `9c3009161ec0e259e7863d9b3b92864da5589bd0`; this does not affect the latest-pass gate or this approval.

No Hashie pushes, workflow reruns, PRs or upstream comments were performed. Workflow security conclusions carry forward because only their comments changed; privileged comment/label handling remains source-reviewed rather than exercised end to end.

### Thermos-sol delta review — 2026-11-26 (combined layout)

**Verdict: changes, two text-only must-fixes.** Reviewed Hashie candidate `87a9f2254eb5492408d327003f46dcd2c0f90f51` against the approved `c4303d510262c31290fe11dd845d38bc9bc999bd`, and checked the candidate's complete diff against its sole parent `e1adebc3de7f48c7aa3f1f9f73c97676102f34a3`. Both Thermos rubrics were applied by this reviewer personally, without subagents or other threads; this is not two independent reviews. Read Hashie's guidance, the earlier review, and Duel's source and benchmark/configuration/JSON/how-it-works documentation at v0.3.1 (`3c0c99d95dc2d5620f59e4bb298179422086adf7`). Read the PR discussion after the independent audit: dblock's combine request is the only comment, with no submitted or inline reviews. The item state, head, public body and existing reports are deliberately unchanged.

#### Must-fixes and exact smallest fixes

**R1 — P2, distinguish branch guards from the removed within-ref comparisons.** Hashie `CONTRIBUTING.md:53` says JSON also compares scenarios with each other. Duel's `JSONReport#timed` exports per-iteration medians, but every computed ratio, interval and verdict compares one named scenario between baseline and candidate. It produces no extension-versus-plain comparison table or interval. Dividing suitable medians by hand is possible, but is not the old `compare!` result, and the setter scenarios here are not matched: the plain overwrite uses a 24-key nested Mash and `description`, while the permissive overwrite uses one key `a`; fresh writes use different names/values. The replacement must not imply that their ratios reproduce the old extension overhead measurement. Replace exactly that final paragraph with:

```markdown
`duel --base v6.0.0` compares the working tree with another ref, `--filter PermissiveRespondTo` selects scenarios, and `--json PATH` exports per-iteration results. Duel computes ratios between refs for the same scenario, not between extension and plain `Mash` scenarios; the old within-ref comparison tables and byte-memory report are not preserved.
```

No extra framework, adapter, comparator or matched benchmark expansion is required for this port. If retaining the old within-ref extension-cost measurements is a maintainer requirement, that is an additional requirement, not something the current JSON switch supplies.

**R2 — P2, the README does not currently mark its cause as a hypothesis.** Lowrail `bench/upstream/hashie_duel/README.md:88–92` says everything else was flat and concludes that risk grew with the number of short scenarios. Round 3's candidate actually has substantial faster paths, and different cohorts do not isolate scenario count or contention as the cause of the false classifications. Replace exactly that closing paragraph with:

```markdown
Both false failures occurred with two benchmarks at a time. Cross-benchmark CPU contention is a hypothesis, not a demonstrated cause. With one at a time, round 5 had no A/A remeasurement and a median job time of 84 s versus round 4's 76 s. The earlier 13-scenario cohorts had 0/35 failures at two at a time; these different cohorts do not isolate the cause or establish a negligible false-alarm rate. Raw: `calibration-3`, `-4`, `-5`; `round.sh` reruns and collects them.
```

This is a wording fix, not a request to change thresholds, remove `c.jobs = 1`, or rerun until green. Neither fix was applied during this review.

#### What became of each deleted script

| Deleted master script | Replacement coverage | What is not preserved |
|---|---|---|
| `mash_method_access.rb` | Ordinary method dispatch is guarded by `Mash: read keys as methods`; the new flat five-key plain case also exercises simple method reads. Duel replaces the manual `hold!` before/after workflow with a ref comparison. | Its single `test` reader, IPS presentation and persisted `tmp/mash_benchmark.json` workflow are not reproduced literally. Reads are now multi-operation scenarios, so time is per scenario, not per individual read. |
| `keep_original_mash_keys.rb` | New plain, KeepOriginalKeys Symbol, and KeepOriginalKeys String cases each read the same five values. Symbol keys are retained only in the Symbol extension case; ordinary Mash normalizes both input forms to the same String-keyed state, so a second plain String-input case would duplicate its measured work. | The two automatic within-ref `compare!` tables and their single-key workload disappear. Setup is not measured in either the old reader blocks or the new ones. |
| `permissive_respond_to.rb` | Fresh-class inclusion is measured with `Class.new` outside timing; flat `new(a: 1)`, fresh-key setter and existing-key setter each have permissive guards beside plain Mash coverage. The new-key batch really writes to a fresh object every time, rather than turning into overwrites. | The empty memory-control row, byte totals/retained-memory report and automatic within-ref ratios disappear. The old new-key block included empty construction; the new setter excludes it with `untimed`. Plain overwrite and permissive overwrite do not use equivalent fixtures. |

On this CRuby workflow Duel counts allocated objects, not allocated or retained bytes: `Metrics::Allocations` reads `GC.stat(:total_allocated_objects)`, while `Metrics::AllocatedBytes` is JRuby-only. No `judge: :peak_memory` was added, and peak RSS would not reproduce benchmark-memory's allocation/retention breakdown anyway. A larger allocation with the same object count is therefore not covered by a byte guard. These are deliberate simplifications worth stating, not grounds to preserve two parallel benchmark frameworks. The commit message accurately describes the replacement operations and dependency removal, but should be read with these narrower measurement boundaries, not as a claim of identical reports.

#### Correctness, security, structure and comments

* **Discovery and version isolation:** the new glob discovers exactly 21 definitions. Duel loads the candidate's config and benchmark files for both versions, with each version's own `lib` first; master does not need to contain the new filenames. The helper move is coherent: `repository_attributes` is now genuinely shared by Dash and extensions, not a new wrapper layer. The JSON fixture is byte-identical to the approved one.
* **Actual operations:** replayed all 21 real definitions through `Duel::Harness`, with explicit discovery/name checks, failure-raising output assertions, and batches of 1, 17 and 1 after the trial. All pass; Symbol/String key storage, permissive subclass inclusion/behavior, fresh objects, overwritten values, Dash defaults and all six read/write operations, coercion, Trash renaming/transformation and non-mutating deep merge were checked. The 24-key shared fixture is unchanged. Hashie suite and Duel completion alone would not establish these semantic properties.
* **Scope and permissions:** production code, gemspec, Rakefile and existing test workflow are unchanged from the approved head. The only executable workflow delta is `duel/**` to `benchmarks/**`; reusable pins, unprivileged measurement and separate privileged report handling remain unchanged. The old source-review security conclusions carry forward; privileged commenting/accept-label handling was not exercised end to end here. No new security defect was found.
* **Dependencies and compatibility:** deleting the two development gems leaves no remaining consumer in this exact candidate. Omniauth's integration benchmark has its own `benchmark-ips` dependency. The ordinary bundle contains neither benchmark gem, Duel nor StackProf. Ruby 3.0 library support is unchanged, while running these benchmarks now requires the documented Ruby 3.4+ optional bundle. The removed baseline entry belongs to the deleted empty block; it is not a new suppression. The class-per-file exclusion follows the small benchmark files rather than broadening to production code.
* **Maintainability:** one DSL, a reused fixture/helper and three short scenario files are a real simplification over maintaining two frameworks. No oversized file, spaghetti branch, unnecessary adapter or useful further decomposition was found. The five-key widening and six-operation Dash case change workload granularity but remain bounded, direct public operations. `[#659]` matches CONTRIBUTING's numbered-CHANGELOG convention and preserves the placeholder; keep Added, as already established by the release-category contract.
* **Every remaining added comment checked:** frozen-string directives and the generated baseline count are appropriate; existing version annotations, permission reasons and the null-logger why-line still earn their place. `.duel.rb:5` is a short reason not to undo a non-default concurrency choice, rather than a narration of `jobs = 1`; it accurately records a failure observed at two-at-a-time and need not be deleted. It does not claim that core contention was proven. No new superfluous comment is a must-fix.

#### Calibration reconciliation and the jobs decision

Ran `tally.py` for all three new rounds and independently reconciled **all 65 archived raw logs** with their summaries, job metadata/conclusions/times and exact source commits. Each has 21 initial scenarios, the stated Ruby 4.0.10 + YJIT and the stated concurrency. All A/A branches add only one comment, each parent matches its round's port, and every candidate's Mash blob is `a80d6bf9bb289009259c9ccb98d81ad1fdfbed6e`. Round 4 to round 5 changes only `c.jobs = 1` and its comment; it does not move a threshold or change a workload. The raw extension lines are absent from the summaries' Mash/Dash/Trash filter, but present in every full log; the tally's final totals match the full logs.

| Cohort | A/A failures / remeasured runs / unsettled timings | Candidate failed runs | Plants regressed (allocation / CPU) | Median A/A job |
|---|---|---|---|---|
| Round 3, two at a time | 0/10 / 3 / 56 of 210 | 1/2 | 13 / 5 | 80 s |
| Round 4, two at a time | 1/20 / 4 / 84 of 420 | 0/3 | 13 / 5 | 76 s |
| Round 5, one at a time | 0/20 / 0 / 51 of 420 | 0/4 | 13 / 4 | 84 s |

The false-alarm record is honest in the table and archives: round 3's Dash read/write failure on the candidate survives four measurements at 1.031–1.035 despite an unchanged Dash implementation; round 4's true A/A failure survives four plain Symbol-key measurements at 1.052–1.071 with across CPU 1.001. Neither is erased by the later green cohort. `round.sh` uses target attempt counts, not stop-on-success, and the archived attempts include the failures. The older 0/35 and latest 0/20 must remain separate cohorts, not become a claim that all attempted runs passed.

**Keep `c.jobs = 1`: a justified conservative tune, not evidence of a solved noise model.** It removes cross-benchmark concurrency, leaves twelve workers per version and every confidence/CPU/allocation threshold unchanged, and both plants still fail. Round 5's four CPU regressions are the plain five-key reader, both KeepOriginalKeys readers and the existing nested method reader; suffix reads no longer confirm, so do not claim unchanged sensitivity for every marginal path. The eight-second median runtime cost is modest. Selection after false failures and twenty subsequent A/A runs on the same runner class do not prove general reliability, negligible false positives or causation; even an independent 0/20 cohort would have a one-sided 95% upper failure-rate bound of about 14%. R2 removes precisely that overclaim, without demanding more calibration or looser limits.

#### Upstream integration and fresh local verification

**The #656 condition has already happened.** Read the current upstream PR and fetched canonical Hashie master: #656 merged at `2026-11-26T12:47:44Z` as `812c48ca7b330abea6a69b92a747c49a95f9cdc0`. That master contains `benchmarks/mash_new_keys.rb`, which requires both removed benchmark gems and does not match `*_benchmark.rb`. This is absent from the exact reviewed parent, not a defect silently present at `87a9f22`; it is a mandatory integration step before publishing the rebased layout. Smallest fix on that rebase: delete `benchmarks/mash_new_keys.rb` too, retaining the merged library change. Its nested-construction/fresh-write operations have Duel coverage, subject to the timing/bytes differences above. Do not broaden the glob or reintroduce the old dependencies just to leave an ignored broken script. Recheck and review the rebased head; this pass does not certify it.

Fresh commands ran in a clean isolated checkout of the exact candidate, using `mise exec ruby@4.0.9 --`:

* `CI=true bundle exec rake spec rubocop` — **1,075 examples, 0 failures**, 100% line coverage; **124 then 155 files inspected, no offenses**. Exit 0.
* `RUBY_YJIT_ENABLE=1 BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec duel --force --base HEAD --json ../delta-aa.json` — **21 benchmarks in 92 s, 0 regressed, 0 errors, 11 unsettled**, exit 0. JSON pins both versions to `87a9f2254eb5492408d327003f46dcd2c0f90f51`, with uncommitted changes false, jobs 1, twelve workers per version, warm-up 2 s, confidence 0.99 and limit 1.02. Across CPU 0.995 [0.985, 1.006] is unsettled, not demonstrated equal. One run only, with no rerun for a preferred result.
* `BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec ruby -Ilib ../probe.rb` — **21/21 actual definitions pass**, repeated batches and unchanged shared input. Probe and JSON remain under `.amp/in/orb-backup/hd1-delta/`; calibration raw data remains in the already tracked evidence directories. Ruby 3.0 was not rerun for this delta review.

No Hashie checkout was edited, no Hashie branch was pushed, no fork workflow was rerun, no PR was opened and nothing was commented upstream. Only this review section and its exact-head pass entry are added to HD1. The old body still describes the live 13-scenario PR head; it is not a proposed description of the unposted 21-scenario candidate.

### Thermos-sol confirm pass — 2026-11-26 (rebased combined layout)

**Verdict: approve; no open must-fixes.** Confirmed Hashie `bcf21e76c40d212ac66b9a168cd611d84d191a8f`, exactly one commit on `812c48ca7b330abea6a69b92a747c49a95f9cdc0`, against the previous reviewed candidate `87a9f2254eb5492408d327003f46dcd2c0f90f51` and the Lowrail evidence at `60ee8412`. Applied both Thermos rubrics personally again, without delegation; this is one reviewer's confirm pass, not two independent reviews. This approval supersedes the preceding candidate's R1/R2 findings for this exact head, not the historical results or measurement limitations. The item state, live head, public body and previous reports remain unchanged.

#### Fix and rebase confirmation

* **R1 closed:** `CONTRIBUTING.md:53` matches the requested replacement paragraph exactly. It distinguishes raw per-iteration JSON from Duel's between-ref ratios and explicitly says the old within-ref tables and byte-memory report are not preserved. It no longer presents unmatched setter scenarios as equivalent extension-overhead comparisons.
* **R2 closed:** the combined-layout README's cause paragraph matches the requested text exactly. It calls cross-benchmark CPU contention a hypothesis, distinguishes the two concurrency cohorts, and makes no negligible-false-alarm or scenario-count causation claim. The earlier failed classifications remain visible in the table and archives; round 6 does not erase them.
* **Rebase correct:** the candidate introduces no changes to `lib/`, `spec/`, gemspec or Rakefile against its new master parent. The merged #656 Mash blob and specs are retained unchanged. `benchmarks/mash_new_keys.rb` is deleted against that parent, so no ignored script remains requiring the removed benchmark gems. All other benchmark definitions, fixture, helper, configuration and workflows are byte-identical to the previous candidate. Range-diff shows only the requested CONTRIBUTING change, the newly applicable deletion, the message update and the redundant spellcheck addition disappearing because master already contains it.
* **Commit wording accepted:** the added sentence correctly names `mash_new_keys.rb`'s construction and new-key-write operations as covered. It does not restore or promise the removed bytes report or identical workload: the deleted script used a smaller nested payload and included empty construction in its setter block, whereas Duel's setter excludes construction. Those boundaries are now explicit in CONTRIBUTING and in the preceding review. No additional code change, wrapper or benchmark framework is needed.
* **Structure, security and comments:** no new executable/configuration behavior or code comments were added relative to the reviewed layout. The earlier maintainability, permission-boundary and necessary-why-comment conclusions carry forward. The optional Ruby 3.4+ bundle remains isolated. Privileged report/label handling remains source-reviewed, not newly exercised end to end.

#### Round 6 reconciled against raw records

Ran `python3 -I bench/upstream/hashie_duel/tally.py bench/upstream/hashie_duel/calibration-6` and independently reconciled all **17 full job logs** with their metadata/conclusions/timestamps, summaries and exact source commits. Each run has all 21 initial scenarios, one benchmark at a time, twelve workers per version, Ruby 4.0.10 + YJIT and the unchanged 1.02 limit. All seven calibration heads have `bcf21e76c40d212ac66b9a168cd611d84d191a8f` as their direct parent. All five A/A diffs contain only their one comment. The rebuilt allocation plant changes only `Symbol#name` to `Symbol#to_s`; the CPU plant changes only the stored-key test in `method_missing` from one to three `key?` calls. Neither recipe undoes or duplicates #656's merged changes.

| New-baseline cohort | Confirmed result | Job / Duel time |
|---|---|---|
| A/A, five branches × three attempts | 0/15 failed, no remeasurement, 45/315 final timings unsettled | 81–91 s, median 86 s / 66–73 s |
| Allocation plant | 13 benchmarks regressed, zero errors | 365 s / 344 s |
| CPU plant | Five benchmarks regressed: plain five-key reader, both KeepOriginalKeys readers, nested method reader and suffix reader; zero errors | 160 s / 136 s |

The README's new row agrees with the raw evidence. Fork PR #8 is closed, not merged, as reported; #656's library change is now the baseline rather than a candidate to count again. Keep `c.jobs = 1` and the existing thresholds. This is additional calibration on the actual rebased head, not proof of a zero future false-positive rate, equality of unsettled timings, or the proposed contention mechanism.

#### Fresh local checks

All checks loaded the exact clean candidate checkout through `mise exec ruby@4.0.9 --`:

* `CI=true bundle exec rake spec rubocop` — **1,076 examples, 0 failures**, 100% line coverage; **124 then 155 files inspected, no offenses**, exit 0.
* `BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec ruby -Ilib ../probe.rb` — **21/21 actual definitions pass** with the previous failure-raising assertions, repeated batches of 1, 17 and 1, and unchanged shared fixture. No probe expectations were changed to accommodate the rebase.
* `RUBY_YJIT_ENABLE=1 BUNDLE_GEMFILE=gemfiles/duel.gemfile bundle exec duel --force --base HEAD --json ../confirm-rebased-aa.json` — **21 benchmarks in 88 s, 0 regressed, 0 errors, 12 unsettled**, exit 0. Both JSON commits are `bcf21e76c40d212ac66b9a168cd611d84d191a8f`, uncommitted changes false, jobs 1, twelve workers per version, warm-up 2 s, confidence 0.99 and CPU limit 1.02. Across CPU 0.997 [0.989, 1.006] is unsettled. One run only, not rerun until green.

Ruby 3.0's 1,072/0 is the builder's reported check, not a fresh reviewer execution. Fresh logs and JSON are retained under `.amp/in/orb-backup/hd1-delta/confirm-rebased-*`; the round-6 raw logs remain in the tracked evidence archive. No tracked Hashie file was edited, no Hashie branch was pushed, no workflow was rerun and nothing was posted upstream. This pass approves only the named candidate; the still-live 13-scenario PR body/head are deliberately untouched.
