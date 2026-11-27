# Decision register

The rules in force, each stated once, with the date or owner that decides it. Numbers live in the linked docs. The
incidents behind the rules, superseded wording and one-off exceptions are in [decisions-archive.md](decisions-archive.md);
its last section holds this file as it stood before the 2026-11-27 condensation, verbatim, with every rule dropped then
and why. The paused runtime-lowering prototype's decisions are in [decisions-prototype.md](decisions-prototype.md).

## What needs Thomas

These hold above everything below.

* **Two approvals replace Thomas's** (Thomas, 2026-11-27): the coordinator decides as it would recommend, and posts
  comments and replies, opens PRs and pushes to open PRs itself, on our PRs and others', once `thermos-sol` and Astra
  both approved the exact text or head. Thomas gets the overview afterwards. The etiquette below still decides whether
  a comment belongs at all (no pings, no burndown data); the three bullets below apply where those two reviews are
  missing. Releases and publishing lowrail-profile still need Thomas.
* **No comments on other people's PRs or issues** (measurements, reviews, suggestions, thanks) **unless Thomas approved
  that specific comment** ([details](#no-comments-on-others-prs-without-thomass-approval-thomas-2026-11-04)). Orbs
  draft at most and ask the coordinator, who asks Thomas.
* **Upstream posts need Thomas** (2026-11-18, 2026-11-25): posting, opening and pushing to open PRs need his approval
  unless he has approved that action. Standing approvals are stated where they apply: answers that were asked for,
  focused reviewed replies on ruby/ruby, drafts in repos with room, CHANGELOG-only rebases. rails/rails opening:
  [Submission queue](#submission-queue-2026-11-03).
* **Thomas sees before posting:** replies that push back on a maintainer or answer "is this worth it" (drafted and
  checked once for facts and tone), and reply drafts to a maintainer's review comments (2026-11-18).
* **New issues** need his OK. **ruby/ruby PRs** open only for items he names, after he can retell the change.
* **Only Thomas marks a draft ready**; neither the coordinator nor W1 runs `script/pr-queue ready`.
* **Ask him** for destructive or irreversible actions, releases, visibility changes and reversing his decisions.

## Lowrail reoriented toward upstream fixes and advisory types (2026-11-02)

**Lowrail is a discovery tool.** It measures real open-source Rails apps on Rails main, finds avoidable work, and
upstreams small, exact fixes where the work lives: Rails, Ruby/ZJIT, gems. Finding ZJIT leads in those apps is a goal
of its own. Why: the runtime lowering failed the YJIT gate
([Bet S](decisions-prototype.md#bet-s-runtime-lowering-parked-2026-10-23)), Feature #22459 was declined, and the
measurements found fixes maintainers accepted ([ledger](upstream/contributions.md)). Advisory types/MCP are parked
([types-usefulness](types-usefulness.md)). Stopped: new interpreter-Ir pricing, sealed-tier breadth, guarded endpoints,
Rails 8.2 sealed re-certification, further promotion of #22459.

**The Rust core and the lowering runtime are paused** (Thomas, 2026-11-27): `src/` and the lowering parts of `gem/`
stay in the tree unchanged, not deleted and not promoted ([PLAN.md](PLAN.md)). lowrail-profile is developed.

**Prefer broad, idiomatic patterns** that every app runs (`where`, SELECT compilation, `tag.*`, params/enum `fetch`,
block forwarding) over single-app hotspots. App numbers are breadth evidence, not the headline.

## Performance across the stack, compatibility as inventory (Thomas, 2026-11-05 night)

* **Performance across the whole stack** (Ruby runtime and GC, C extensions and drivers, Rack and Puma, Rails, gems).
  YJIT is the production reference; interpreter numbers alone don't carry a claim.
* **No new compatibility PRs for Rails main** (Rails or gems) until the Rails 8.2 beta, since the internal design can
  still change; findings go into an inventory with callers and proposed fixes. Exceptions: WAL150 (Thomas, 2026-11-26), TSP1 (Thomas, 2026-11-27).
* **Only PRs with large relevance open:** the effect reaches many apps or a widely used gem, or a whole request, test
  run or ruby-bench benchmark moves measurably. Small per-call wins in niche gems or rare paths, and fixes for niche gems, are
  recorded as `held` items ("parked idea") and not opened later as they are. Every item states its reach in `impact` before review.
* **Rails, central gems and Ruby; no ecosystem fixing** (2026-11-06): no fixes in individual apps or niche gems for
  Rails-main breakage (recorded in [contributions](upstream/contributions.md)). Upstream work goes where it reaches
  every Rails app: Rails, central gems (Rack, drivers, Puma and the like), Ruby, ruby-bench.
* **No upstream reports or fixes for projects with restrictive AI policies** (2026-11-06), e.g. Mastodon; they stay
  measurement corpus.
* **Current versions only** (2026-11-06): no PR for a break that only shows with an old, long-superseded dependency
  version, even inside a declared range.

## Bets

Priorities (Thomas, 2026-11-03): Rails and ZJIT first, then gems. Parked: types/MCP, YJIT, ruby/uri, the Campfire
lead. Each bet's doc is the source of truth for its state.

* **Three big bets in parallel** (Thomas, 2026-11-25): ZJIT gaps on real apps beyond k0kubun's zjit-headline2,
  unreleased Rails 8.2 regressions (rails-main-census-11), and lowrail-profile for any Rails app. The coordinator runs
  and reviews them.
* **Next** (Thomas, 2026-11-25 evening): (a) lowrail-profile on 5–8 unfamiliar open-source apps, costly gem lines
  turned into upstream fixes; (b) correctness before Ruby 4.1: weekly differential of the census app suites on Ruby
  master (interpreter, YJIT, ZJIT) and on zjit-headline2, minimized and bisected; (c) a list of our open rails/rails
  PRs that could close or be bundled, for Thomas; (d) tooling: ownership check before opening, raw-data retention
  before archiving a thread, a trailer-refusing pre-push hook in fork checkouts. ZJIT performance asks pause:
  zjit-headline2 is ahead of YJIT on every measured app.
* **lowrail-profile 0.1** (Thomas, 2026-11-25, all six recommendations of [profile-release-plan](profile-release-plan.md)):
  its own gemspec in `gem/` without lowering code, for rubygems.org; floor Ruby 3.3 and Rails 7.2 if M2 holds,
  otherwise 4.0 and 8.1; `--record` and `--workloads` experimental (writes behind `--allow-writes`); a dated ledger
  snapshot bundled; proof on Campfire, Lobsters, CodeTriage and a floor-version app. M1–M5 run. **No release, not even
  rc1,** before an intensive field test on all census apps (or a set Thomas agrees to); the release (M6) needs Thomas.
* **lowrail-profile 0.1 has no gate** (coordinator, delegated, 2026-11-25): `compare` exits 0 whatever it lists, 2 on
  invalid evidence or multi-process captures, because unchanged heads were flagged too often
  ([profile-gate-design](profile-gate-design.md)). A gate with a noise model from several base captures may come in 0.2.

| Bet | Goal | Doc |
| --- | --- | --- |
| Z10 | per-ISEQ ZJIT stats on the apps | [zjit-iseq-leads](upstream/zjit-iseq-leads.md) |
| F1, F2 | frontier census (20 apps, Rails main × master); our merged Rails PRs under ZJIT | [measurement-matrix](upstream/measurement-matrix.md) |
| C8 | census 8 (CPU, allocations) on 4.0.9 and pinned master | [census](upstream/census.md) |
| Z5–Z8, Z12 | objtostring, compile speed, cfunc paths, stats correctness, warmup | [zjit-shortlist](upstream/zjit-shortlist.md) |
| V1, A1, S1 | Action View, Active Record, JSON serialization CPU | [actionview](upstream/actionview-cpu.md) · [activerecord](upstream/activerecord-cpu.md) · [serialization](upstream/serialization-cpu.md) |
| G1, I18N | gem census, i18n, gem request census | [gem-census](upstream/gem-census.md) · [i18n](upstream/i18n-performance.md) · [requests](upstream/gem-request-census.md) · [round 2](upstream/gem-request-census-2.md) |
| R6 | relation delegators `...`, `default_scope` owner checks | [rails-r6-leads](upstream/rails-r6-leads.md) |
| E2 | the 13 census configurations that fail on Ruby master install, via gem fixes | [gems-on-master](upstream/gems-on-master.md) |
| P-TEST, P-DRV | per-test framework overhead; database driver result path (planned) | |
| FLK1 | rails/rails CI flakiness: exact fixes in one PR, one commit per cause | [rails-ci-flakiness](upstream/rails-ci-flakiness.md) |
| done | Z2/Z11, Z13, Z1-2, P-MAP, QB1, DEF8, VM1 | [differential](upstream/zjit-app-differential.md) · [gap](upstream/zjit-yjit-gap.md) · [gap 2](upstream/zjit-gap-census-2.md) · [p-map](upstream/p-map.md) · [query-building](upstream/query-building.md) · [defaults](upstream/rails8-defaults.md) · [vm-share](upstream/vm-share.md) |

## Working mode

* **Decide, then document** (Thomas, 2026-11-03): within these rules, take the recommendation you think is right and
  record it here with its reason instead of asking. What needs Thomas is at the top.
* **Orb reports are claims.** Check a decision-bearing fact before relaying it.
* **Judge today's situation on its merits** (Thomas, 2026-11-27): old maintainer decisions and issues are context,
  not authority. Where a current case would be better served by a different choice, propose it; argue upstream
  from current behaviour and evidence rather than from years-old threads.
* **Child orbs don't notify Thomas** (2026-11-04): they report only to the coordinating thread with
  send_thread_message, never notify_user, and are snoozed indefinitely. The coordinator relays.
* **No fixed orb limit** (Thomas, 2026-11-27; replaces "at most 8 working orbs", 2026-11-03): run as many orbs as
  the work needs in parallel, size each by `amp orb system-metrics` of similar tasks, and archive finished ones.
* **No upstream references in Lowrail commit messages:** `owner/repo#N` or an issue or PR URL leaves a permanent entry
  on that upstream thread. Name upstream work in plain words or by queue item ID; numbers and links go in the docs.
  `script/commit` and `script/hooks/pre-push` refuse them (2026-11-15).
* **Commit identity.** Author and committer Thomas Klemm `<github@tklemm.eu>`, no Amp or co-author trailer (a plain
  `git commit` in Amp adds Amp-Thread-ID). Use `script/commit -F msgfile` in Lowrail and upstream checkouts; it
  verifies the result. `script/hooks/pre-push` (installed by `.agents/setup`) refuses trailers in Lowrail; the ones
  already on main stay. Run `script/install-fork-hooks DIR` on every fork clone before its first push (2026-11-25), and
  check `git log --format='%(trailers:only)' base..HEAD` is empty before every fork or upstream push (2026-11-05).
  Rewrites drop the signature: sync with `script/git-signed pull --rebase origin main`; `script/pr-queue rebase`
  signs itself. Upstream: one commit per fix on a freshly fetched base.

### Orbs only, not Thomas's Mac (Thomas, 2026-11-17)

All work runs in orbs; the Mac runner is not used. arm64-only checks are skipped unless Thomas offers the Mac for one
specific run.

### Orb time (Thomas, 2026-11-04)

Orbs bill per running minute by size; a paused orb costs nothing.

* **a1.medium minimum (the project default), a1.large is fine.** Pass `orb_size` on every create_thread: a1.medium for
  watchers, coordination, reviews, ledger and docs work and light suites; a1.large for Ruby builds, framework, app and
  gem suites, differential harnesses and benchmarks. Larger only for a short, focused burst (a full Rails matrix, a
  parallel bisect): say why in the prompt and archive the thread when done.
* **One central watcher** (W1) checks every open upstream PR every 30 minutes and reports what matters; workers keep
  no PR watch schedules.
* **Let orbs pause:** no sleep loops or long polling; stop services when done; batch messages, since each wakes the
  receiver for at least 5 minutes. **Archive finished orbs**; records live in this repo. Check
  `amp orb system-metrics <thread>` before sizing a similar task.

## Upstream etiquette

* **Comment only when the thread needs it:** to answer a question asked there, to report a bug or verified fix that
  bears on it, or with a change it waits for. Benchmarks of others' PRs, related breadth, overlap with our PRs and
  claims on issues stay in our docs; our PR is the claim. Never ask anyone to merge, rerun or review faster.
* **No data comments on others' burndown issues** (Thomas, 2026-11-25), e.g. nothing on Shopify/ruby#1030.
* **No pings** on open PRs and issues anywhere (Thomas, 2026-11-17). Close only at a maintainer's request or when
  superseded.
* **Collaborative, not credit-seeking** (2026-11-03): don't point out overlap, ask who lands what, or offer to close
  ours for theirs. If someone else's PR covers ours, close ours with one neutral line.
* **Well-reviewed PRs over issue discussions** (2026-11-03): no issues or issue discussions on things Thomas doesn't
  understand well or where we have little to add; an issue needs a verified bug or a question we can answer. Past
  mistakes stay as they are.
* **Thank for something concrete, never as filler** (2026-11-16): one plain sentence when someone did something for
  the PR; no reflexive "Thanks!" after a reply that only reports what we did. **No standalone thank-you after a plain
  merge** (2026-11-05) unless worth a notification (real review time, several rounds, their own work); otherwise a 👍
  on their comment or review if they left one, else nothing.
* **No "I" or "we" where the sentence works without** (2026-11-16); where a person is needed, "I".
* **Closing comments:** thank where earned, accept the point, one neutral fact for the record, don't belittle our
  result, don't reopen the decision.
* **Search before building:** open, closed and Dependabot PRs, issues, earlier maintainer decisions, and recent
  maintainer commits and PRs on the same functions.
* **ZJIT ideas are free to take** (k0kubun, Shopify/ruby#1100) unless the idea's issue has an assignee, an open PR
  exists, or a tracker table's assignee column names someone.
* **Rails doesn't take JIT workarounds** (skipkayhil, 2026-11-15): a Rails change whose win comes mainly from how a
  JIT compiles a construct goes to the JIT; Rails perf PRs need a win in the interpreter or in allocations on their
  own. Such a pattern becomes a ZJIT PR on ruby/ruby citing the closed Rails PR and the maintainer's comment; it
  builds on an existing branch with its commits and authorship kept and credits them in the body. No comment on the Rails PR.
* **YJIT is in maintenance mode** (XrXr, k0kubun): JIT performance and allocation-parity work targets ZJIT; YJIT gets
  correctness fixes only; YJIT findings go to [yjit-leads](upstream/yjit-leads.md), not built. Our open YJIT PRs stay
  open and maintained.

### No comments on others' PRs without Thomas's approval (Thomas, 2026-11-04)

We don't comment on other people's PRs or issues unless Thomas explicitly approved that specific comment. Their PR
description is theirs; what we measure about their work stays in our records. Orbs draft at most and ask the
coordinator, who asks Thomas. Replies on our own PRs and issues are unaffected.

Approved comments open with "Heads-up in case it's useful:", state the effect in one sentence, give the minimal repro,
name an existing fix or PR if there is one, and stop: no thanks, no judgement, no proposals or numbers nobody asked for.

**Exception: answers that were asked for** (2026-11-05). When someone asks us for an answer, a re-test or a data
point, post it promptly without asking Thomas, if it is properly reviewed and measured and helps. Everything
unsolicited still needs his approval.

### Nothing internal upstream (Thomas, 2026-11-14)

Upstream posts contain only what helps people there decide. Lowrail matters stay here: our held or unopened branches
as comparisons, queue, slots and caps, review passes and reviewer names, internal IDs (census and round numbers too),
orbs and process. Numbers describe the upstream code, with setup in neutral words ("35 Rails workloads"). Check every
column, row, link and sentence: would the reader miss it? If not, drop it. Bodies don't mention or link Lowrail.

## Pull requests

* **Thomas can explain it first** (2026-11-03): before a ruby/ruby PR or any issue opens, Thomas can say in two or
  three sentences of his own what is wrong, what changes and why it is safe; he gets a short explanation with a
  minimal example. The agentic work comes after that. Open PRs and issues he can't stand behind close with one
  neutral line.
* **One concern per PR**; a ruby/ruby PR touches the VM, YJIT or ZJIT, never two (tekknolagi).
* **Cross-link interlocking changes in the body**, one sentence with owner/repo, updated as the other side moves, never
  as a comment. Every cross-repo reference carries owner/repo; link branches instead of naming them.
* **ZJIT evidence in the tools' own format** (k0kubun, 2026-11-04): raw `run_benchmarks.rb` output and a stats diff in
  diff format without in-noise diffs, not percentage tables.
* **Restore and compatibility PRs name their callers** (2026-11-04) with line permalinks.
* **Cite only relevant, current projects, most important first** (Thomas, 2026-11-27). Every gem, app or repo a
  PR, issue or comment names is checked first: stars, downloads (rubygems.org) and the last push or release. Drop
  archived, abandoned or niche projects, and gem versions a current release has superseded; permalinks follow
  [Line permalinks for callers](#line-permalinks-for-callers-thomas-2026-11-04). Order the remaining ones by reach,
  the most used first, and name a few strong ones rather than a long list.
* **Maintainers can edit our branches** (2026-11-06): "Allow edits by maintainers" on (`script/pr-queue open` sets
  it); our forks hold no Actions secrets.
* **Few, clean commits; the reasoning goes in their messages** (2026-11-06).
* **Do less work, don't inline helpers** (Thomas, 2026-11-27, after rails#60016): no performance PR that only
  inlines small helper methods at their call sites to save method calls; that moves logic into the wrong layer and
  makes the code worse for a gain JITs mostly remove. Doing it in one place makes no sense, and doing it everywhere
  is worse: method-call overhead is the JIT compilers' job, so such a finding goes to ZJIT. Rails PRs reduce the
  work itself (fewer walks, fewer allocations), judged on ZJIT first, then YJIT, not only on interpreter
  instruction counts.
* **Tests check behaviour, never implementation** (2026-11-06): no allocation, instruction or call counts or other
  internal-state asserts in upstream suites. Perf is shown by a benchmark beside the suite, numbers in the body or a
  linked record, the why in the commit message. Add a test only where a plausible regression would break behaviour.
* **Unreleased upstream evidence** may be cited when the body says it is unreleased.

### Playbook from the PR retrospective (2026-11-04)

Evidence per rule: [pr-retrospective](upstream/pr-retrospective.md).

* **Thomas owns the ruby/ruby review conversation:** no LLM attribution, only work he can explain in every detail. He
  answers reviews or approves every answer; since 2026-11-04 the coordinator may post focused, reviewed replies and
  body updates on ruby/ruby and tells him afterwards, each with an explanation he can retell.
* **Ask on the tracker before ZJIT design changes** (profiling, speculation, invalidation, recompile policy, new
  per-ISEQ state, new HIR instructions, or more than about 150 lines): a Shopify/ruby issue with one concrete ask and
  the data first, the PR once the team says go.
* **Gems:** check maintainer activity and the repo's idioms before building.
* **Pace on ruby/ruby** (once new PRs are allowed): at most 2 new a week, the next only after a maintainer responded
  to the previous; one PR per finding.
* **ZJIT perf PRs need a run_benchmarks.rb effect outside A/A** unless the team asked or it removes a permanent exit.
  Report `zjit_alloc_bytes` for new per-ISEQ or per-profile state.
* **Evidence:** one base / A/A / head comparison, only stats that move, under about 120 words of prose. **Show the
  mechanism** (HIR or the changed path) on the real call shape and the smallest common input.
* **No follow-ups to a fix a maintainer called narrow, nothing in code a maintainer is reworking.**
* **Answer review with the change or one named blocker**, not a menu.
* **Tests test one thing**, plus asserts on the invariants the change relies on.
* **Rails:** small, obvious, numbers from real apps; drop or simplify L2 candidates and any needing more than two
  exactness rounds.

### PR descriptions (Thomas, 2026-11-03 to 11-05)

A maintainer gets the point in seconds without our notes; if it reads like a report, it is too long.

* **Shape:** the title says what changes; two or three short paragraphs, usually 50–120 words: (1) what breaks or is
  wasted, where and why, with one concrete example; (2) what the change does and why it is safe for released versions
  and existing callers, plus the one boundary a reviewer would ask about only if users can hit it; (3) for
  compatibility and restore PRs only, who is affected, with line permalinks.
* **Numbers:** a perf PR gets one small before/after table whose heading says what was measured; instructions are
  never called time; A/A, methodology, ruby-bench placement and other Rubies stay in the record; a correctness PR has
  no numbers. Cells stay short; explanations go in the prose (2026-11-15).
* **Leave out:** run and suite counts, commands, SHAs and pins, Rubies or databases tried, review history, rejected
  variants, differential sizes, private or `:nodoc:` override boundaries, "this is not a speed claim". Answer such
  questions in a reply.
* **Language:** full sentences, plain words; no internal labels, arrows, shorthand, stacked qualifiers, headings,
  checklists or bold.
* **Fixed parts:** a stacked PR starts "Stacked on #N, which should merge first; only the last commit (`sha`) is new
  here." No footer and no Lowrail link (2026-11-15); link the record in a reply if asked. How we found it is one
  clause ("While profiling a few Rails apps, …"). Redmine tickets are links ([Bug #N](https://bugs.ruby-lang.org/issues/N),
  2026-11-16). No AI disclaimer unless it matters. Cite an earlier PR of ours by reference and what it tried, not
  "My #N" (2026-11-15).
* **Review:** Sol checks every sentence against the record and reads it as an outsider. Fix by cutting. A body that
  needs more than about 150 words to be honest means the change should be split or simplified.
* **Examples:** ankane/blind_index#62, activerecord-hackery/ransack#1795 and rails/rails #59661–#59677 as of 11-05.

### No unnecessary code comments in upstream PRs (Thomas, 2026-11-10)

Superfluous comments read as AI slop (byroot on #59555). For every upstream PR, tests and benchmark files included:

* **A comment stays only when a reader would otherwise undo or misread the code**, and only where that file's
  maintainer would keep one (2026-11-18): one short line, why not what, in the file's style, keeping the surrounding
  comment density.
* **No comments that** restate the code, narrate the change, mention the PR, benchmark or measurement, or explain what
  was removed; cost, internals and equivalence go in the commit message, body or record.
* **No comment above a public or documented method** unless meant as API docs; internal helpers get `# :nodoc:` on the
  `def` line, unless the enclosing class or module already is `:nodoc:`.
* A reviewer's "comment so nobody deletes this" doesn't override this: prefer a behaviour test; for a perf-only line
  the commit message carries the reason.
* **Every review pass checks every added comment line**; a superfluous one is `changes`, not a nit. Check before a
  queued branch opens.

### Line permalinks for callers (Thomas, 2026-11-04)

Every caller cited in a body, issue or ledger record links to the exact line at a **commit SHA**, never `blob/main`.
For a gem, the commit behind its **latest released version's** tag, version named in the link text (no tag: the
release's "Bump to x.y.z" commit or its rubygems.org source); for an app without releases, the default branch's current SHA,
branch named. Also check a gem's default branch: if it already fixed the call, say "fixed on main, unreleased". Quote the line exactly (or mark
it shortened), and before posting fetch each file at that SHA and confirm the line.

## When Rails restores a private API, and other open calls (decided 2026-11-04 at Thomas's request)

* **No deprecation shims for internal API** (matthewd, 2026-11-06; this wins over the restore rule, Thomas,
  2026-11-25): private or `:nodoc:` breakage is fixed in the gem or app that relies on it; Rails gets a fix only when
  Rails itself is wrong.
* **Restores:** public API removed without deprecation is restored, deprecated if the new name is better. Private API
  only when (1) the removal is unreleased, (2) several real callers break (released gems or apps, with permalinks), or
  one large one breaks silently or wrongly, and (3) the restore is small and keeps the change's purpose. The PR says
  the API is private and names the callers. Otherwise record-only, or a fix in the gem or app when small and its
  maintainers are active.
* **rspec-rails release:** no issue for now; ask once a Rails 8.2 beta is out.

## Submission queue (2026-11-03)

Every candidate gets one file in [bench/upstream/pr-queue/items](../bench/upstream/pr-queue/items) once its branch and
body exist ([format](../bench/upstream/pr-queue/README.md)): title, body exactly as posted, impact, rank by effect and breadth, and every
pass with the head it reviewed. It opens when its repo has room, strongest first, through `script/pr-queue open`,
which refuses unless the gates pass on the current head. A candidate made moot upstream becomes `superseded` or
`closed` with a note.

* **Ownership check** (2026-11-25): items record `introduced_by` and `tracker` where they exist and run
  `script/ownership ID`; `open` refuses without a check from the last 3 days.
* **rails/rails: at most 15 open, drafts included; opens ready** (Thomas, 2026-11-27; rafaelfranca turned on draft
  counting and asked not to open PRs that aren't ready, since drafts notify him). A Rails PR opens only when every
  pass approves the exact head and there is room under 15, ready for review (`script/pr-queue open ID`, no
  `--draft`). The waiting line stays in the queue, never as GitHub drafts. Keep each PR small. Open PRs fixing older,
  released bugs aren't closed to free a slot (2026-11-25).
* **Other repositories open as drafts, and only Thomas marks them ready** (2026-11-05 night). Agents may open reviewed
  items as drafts where the repo has room, every pass on the exact head.
* **ruby/ruby: none open unless Thomas names the item** (2026-11-04): we have to get better at ruby/ruby PRs first.
  A named item opens once built and reviewed, after "Thomas can explain it first". Named and unopened: ZJIT lead 3
  (ZL3; 2026-11-14). Earlier exceptions are in the archive. Other recorded slots (GC pool-budget fix, Z13's top lead,
  Shopify/ruby#1064, #1065, #1091, #1058) don't open. At most 10 of ours open, all kinds counted. Open ones stay unless
  there is a reason to close one and report an issue instead, proposed to Thomas. Not covered: ruby/ruby-bench, and a
  fix for our own test that turns others' CI red (2026-11-04).
* **Gems: at most 2 of our PRs without a maintainer response per repository** (2026-11-04); **ruby/ruby-bench** is
  exempt (2026-11-05).
* **Stacked PRs open right away** (2026-11-05) with the stacked sentence; #N's body links back. Once #N merges, rebase
  the stacked PR to its own change. (GitHub's native stacking needs both branches in the base repo.)
* **Keep open PRs mergeable:** resolve conflicts promptly, keep CI green where the failure is ours (show unrelated
  failures fail on base when asked). No force-push without a conflict, a requested change or a failure of ours. When
  only CHANGELOG files conflict, the coordinator may run `script/pr-queue rebase ID --push` unasked (Thomas, 2026-11-18).
* **Guards in the target repository's idiom** (Thomas, 2026-11-18): a guard protects the documented contract and real
  callers, as that file's maintainer would write it; a guard stays only for a real caller, a documented case, or a
  correctness or safety property, never for "exactly like before for any object". An accepted difference outside the
  contract gets one sentence in the body; a review lists each surviving guard and its reason
  ([sweep](upstream/guard-simplification-2026-11-18.md)).

## Evidence and measurement

* **Ruby pin 4.0.10** (Thomas, 2026-11-27; 4.0.9 from 2026-11-03) for census and Rails PR evidence. New
  measurements start on 4.0.10 with their own A/A; comparisons already running finish on 4.0.9. Never compare
  across pins; every A/A and main-versus-branch pair runs on one pin. Open bodies with 4.0.7 numbers stay; they name their Ruby.
* **4.1 is measured on pinned Ruby master, SHA recorded**, not previews: boot, interpreter, YJIT and ZJIT allocations
  with A/A on the ZJIT pass's build; the routine cell moves to 4.1 when 4.1.0 ships
  ([measurement-matrix](upstream/measurement-matrix.md)).
* **Every census adds a ZJIT stats pass on master** with `--zjit-exec-mem-size=512 --zjit-mem-size=1024`;
  `compile_error_out_of_memory` must be 0 in every run before a counter is reported.
* **Every new ZJIT lead is written down** (2026-11-03) in the [lead queue](upstream/zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03),
  wherever found: fallback reason or exit, repro or app and site, counts per op and on ruby-bench where known, free or
  taken; unmeasured ones marked so. Nothing is posted for it. A lead goes upstream as a PR once built. Only correctness
  bugs (crash, wrong result, interpreter/JIT divergence) become issues, with a minimal repro, even when we also fix
  them; performance leads never.
* **Raw data is committed or archived before a worker reports done** (2026-11-25), with its paths in the item's
  `evidence:`; `script/pr-queue status` flags a reviewed or later item whose body has numbers and no such path.
* **Where claims come from:** Callgrind instruction counts with fixed heap and A/A are primary ([bench.md](bench.md));
  body numbers come from `script/upstream-bench` ([body-numbers](upstream/body-numbers.md)). App pages find sites but
  can't price them (A/A up to ±7%). ZJIT speed claims come from ruby-bench with A/A.
* **Every candidate also reports its micro on master × ZJIT** (Rails, Ruby and gems; pinned build, `--wall` with
  A/A), or says its path doesn't run on 4.1 (Thomas, 2026-11-27: ZJIT is tested and weighed wherever it can be;
  census rounds, field tests and reviews include a ZJIT pass too). In the record; in the body as one sentence when
  the ZJIT result adds something, such as a win that holds or differs under ZJIT. A ZJIT or YJIT wall-time loss blocks it only when `script/upstream-bench --wall` (≥ 30 rounds) claims
  it: an A/A interval containing 0 and a change interval excluding 0. A loss inside that cohort's intervals is noise, not
  an unexplained cost; a claimed loss blocks until explained or accepted (2026-11-27, wall_noise study). Rails changes made only for ZJIT need a
  win of their own on the pin.

### Benchmark tables in the project's own format (Thomas, 2026-11-14)

Bodies lead with the project's own benchmark and tool. ruby/ruby: a `benchmark/*.yml` (existing or new and small)
through `make benchmark ITEM=… COMPARE_RUBY=… OPTS="--repeat-count 10"`, with both version lines and
benchmark-driver's table, and the older release in one sentence when it shows a regression closing. Rails and gems: a
short benchmark-ips (or benchmark-driver) script with its before/after output. One pinned core, best of N; the record
keeps raw output and an A/A. Callgrind finds and attributes; in a body it is one supporting line or a small table only
when it shows what wall time can't (objects, a JIT-only path). Wall time is measured on orbs.

### Realistic sizes upstream (Thomas, 2026-11-14)

Bodies and comments cite only sizes an app plausibly has: a few to about 20 params, tens to about 100 columns,
ordinary values. The size sweep stays in the record; the body may say in one clause that larger inputs were checked,
with no unrealistic row or number.

### Learnings from byroot's follow-ups (2026-11-10)

From the revert of #59584 and the simplification of #59640 (story in the archive):

* **Size sweep** for work proportional to input length (scans, escaping, parsing, encoding, copying): small, typical,
  and one input past the last-level cache (≥ 1 MB), each with the match absent, early and late. The worst row is
  reported, and a change adding passes over the input shows the large row; in the body only within realistic sizes.
* **Lifetime and reach in `impact`:** does the path still run on Ruby master and Rails main? If not, open only with a
  large measured win on current releases.
* **Every perf review prompt asks for the input that makes the change slowest**, and to measure it.
* **Before patching a failing piece, ask whether it can go**; when we keep the conservative fix, name the smaller
  option in the body.

## Review gates

### The coordinator picks the reviewers (Thomas, 2026-11-18 and 2026-11-27)

The coordinator picks the reviewers, models and instructions that fit each head best (a full pass, a short confirm
after a small fix, an adversarial brief, a second or third reviewer, a thermos waiver for e.g. a mostly generated app)
and starts them without asking; the item's note says which and why. What matters is the end result. What needs Thomas
upstream is unchanged.

### Required passes

Every upstream PR, issue or comment draft gets as many rounds as it needs on its **current head**. Each confirmed
finding is fixed and re-reviewed; a round ends with a pass without must-fix; a head change means another pass. Items
enter the queue at `built`; an item is `reviewed` only when the floor below approves its current `head`, and
`script/pr-queue open` and `ready` refuse otherwise. The fixed floor, in every repository:

* **A detailed pass: thermos-sol by default** (Thomas, 2026-11-18, confirmed 2026-11-27): `thermos` in its own GPT-6.1
  Sol thread (`openai/gpt-6.1-sol`, effort `xhigh`), correctness/security and maintainability in parallel, plus body,
  comments and commit message sentence by sentence and the exactness probe. Recorded as `thermos-sol`. It fills the
  thermos slot that diffs over 200 changed lines (or several files, or a new mechanism) need. `thermos-opus`,
  `thermos-fable` and recorded `claude-code` passes also count as the detailed pass.
* **Astra on the exact head shortly before opening, for every item** (`openai/gpt-6-astra`; Thomas, 2026-11-27).
  On a **critical** change it runs adversarially after the detailed pass approves: try to break identical behaviour
  with inputs, overrides, prepends, threads, reloading and error paths, run them, report only demonstrated
  differences. Critical: escaping or other security boundaries, connection or transaction handling, record loading and
  typecasting, caching or memoization, thread or fiber state, VM/JIT code. Items are marked `risky` for correctness
  changes on hot paths, Ractor/thread or frozen-object semantics, anything a maintainer pushed back on before, and
  critical changes; how Astra is briefed on other risky items is the coordinator's choice.
  Every Astra brief includes the relevance and currency check of every project the body, issue or comment cites
  ([Pull requests](#pull-requests), "Cite only relevant, current projects"): stars, downloads, last push or release,
  and the order by reach.

Beyond the floor:

* **Anthropic models where OpenAI's checks stop a review:** crash and memory-safety fixes get `thermos-opus`; reviews
  of our own safety guards (`guard_review: true`) run as `thermos-opus` or `thermos-fable`, framed as checking each fix
  against the original repro, with plain reports and repro detail kept in the reviewing thread; there a
  `thermos-opus` or `thermos-fable` pass from another orb than the detailed pass fills the Astra slot (2026-11-25).
* **Replies to a maintainer's review comments:** an intensive `thermos-opus` next to `thermos-sol` on the same head;
  Thomas sees the drafts first (2026-11-18).
* **Opus and Fable are regular reviewers** (Thomas, 2026-11-27; three Claude accounts): use them intensively for
  second opinions, claims-heavy bodies, measurements, exactness and hard design questions. Recorded as `opus` or
  `fable` with the orb's thread ID in `orb`; they add to the floor and don't replace the Astra pass.
* **Active Record adapter or schema changes run `script/min-versions` before review** (2026-11-25): their tests on the oldest supported SQLite (and a middle
  one), PostgreSQL, MySQL and Ruby, base versus head ([usage](upstream/ar-adapter-suite.md#oldest-supported-versions-2026-11-25)).

Models (Thomas, 2026-11-17 to 11-25): Sol is GPT-6.1 Sol, not 6.2, always `xhigh`; Astra is GPT-6 Astra. Build and
review threads run as plain Opus 5.5 (`anthropic/claude-opus-5-5`), not Claude Code external agents (same model on the
linked subscription), at `high` for reviews, exactness work and hard builds, `medium` for record updates, reruns and
small follow-ups. Fable is `anthropic/claude-fable-5-2`.

### Exactness checklist

Every orb runs this against its candidate with a differential harness before review and reports which items it checked:

1. Singleton methods on arguments and intermediate results, private ones too, `extend`, prepended modules,
   `method_missing`/`respond_to_missing?`; `instance_of?` doesn't exclude them.
2. Subclasses of Hash, Array and String with their own `to_a`, `each`, `map`, `merge`, `[]=`, `include?`, `gsub!`.
3. Implicit conversions (`to_ary`, `to_a`, `to_s`, `to_hash`), public and private, with call counts.
4. Every call the change adds on a user-supplied object (even `equal?`, `force_encoding`) and every call base made that
   it skips (e.g. a `gsub!` that raises on a frozen String).
5. Results from user code are copied as base did, never adopted as an accumulator.
6. Mutation during conversion or iteration (live Hash vs snapshot), and fibers suspended there.
7. Frozen receivers, arguments and results; exception class and message.
8. Load order and standalone `require`; configuration read before vs after the work, as in base.

Accepted without a fix, except for escaping or SQL safety: global redefinition of core methods, overrides of private
(nodoc) methods, internal Arrays reached through ObjectSpace.

### Claims are checked, behaviour changes are probed (Thomas, 2026-11-14)

* **Every factual claim in a body or comment is backed by a command the reviewer ran or a link it opened**, recorded
  in the pass. An unchecked claim is cut, not softened.
* **A pass on a behaviour change includes a differential probe of old against new** across input types, subclasses and
  duck-typed objects included, and checks the documented return contract (`<=>` returns -1, 0, 1 or nil).

### Readability gate (L0–L3)

Thomas, 2026-11-03; part of the detailed review's maintainability rubric. L0: no harder to read; opens if exact and
measurable. L1: slightly unusual but clear at once; needs a per-call CPU gain outside the A/A. L2: noticeably more
complex (new helper, lazy arrays, copied internals); needs an effect measurable in an app or on ruby-bench. L3: a
duplicated method, a Ruby-version branch, index loops, or code needing comments; don't open. ruby/ruby also needs a
measurable ruby-bench effect or a correctness repro.

* **Describe it out loud first** (2026-11-04): before review the author writes the changed code as plain sentences, one
  per line or branch. If one is awkward, needs "except" or "unless also", or names a variable twice, refactor and
  measure again; a readable form keeping most of the gain wins. The description goes in the review record and,
  shortened, in the body.
* **Cold read:** a reviewer new to the change says in one sentence what each branch does and why each condition is
  there; if that takes two tries, rewrite before opening.
* **Shape checklist:** each case its own branch, no reassignment inside a conditional modifier, no ternary beyond one
  short line, a one-line why on sentinel or identity checks, no new name used once, the diff reads like its
  surroundings.
* **Numbers as a signal:** record `flog` and RuboCop `Metrics/*` per touched method before and after; a rise needs a
  sentence in the review. They never replace the cold read.

### Correctness fixes: readable first (2026-11-04)

No code golf: as readable and idiomatic as a maintainer would write it. Measure only to rule out a clear slowdown on a
common path, never to choose between correct shapes; no numbers in the body. The L0–L3 performance bars don't apply;
the cold read and shape checklist do. Correctness findings along the way get their own PRs.
* **A fix that also closes a performance regression shows it with numbers** (Thomas, 2026-11-27, BT1): the body says
  clearly that it is faster again, in the project's own format when a clean A/A allows it, otherwise one Callgrind line
  with its A/A; the older release in one sentence. Wall-time numbers only with their full spread and A/A.
