# Decision register

What we pursue, what is parked and what is rejected, with the reason. Numbers live in the linked docs; this page
records the rule and why. Rules are grouped by topic, with a date or owner only where it decides something. The
parked runtime-lowering prototype's decisions are in [decisions-prototype.md](decisions-prototype.md). Earlier
wording of these rules is in git history (before 2026-11-03 19:00 UTC).

## Bet: what our merged Rails PRs add up to (2026-11-04)

Main against main with 39 of our merged perf PRs reverted (five conflict and stay in both trees), Ruby 4.0.9, fixed
heap ([merged-sum](upstream/merged-sum.md)): census allocations −3.8% per workload in five apps (A/A ≤ 0.04%, 52/52
workloads move), ruby-bench −1.2% to −9.7% objects per iteration, and −2.0% to −7.0% instructions on erubi-rails,
railsbench and shipit (A/A ≤ 0.54%). Lobsters' ruby-bench instructions and every app-level YJIT row fail their A/A
and are not claimed. Ten PR groups carry 85% of the allocations; the WhereClause and database-statement groups lead.
For our own picture; nothing posted.

## Lowrail reoriented toward upstream fixes and advisory types (2026-11-02)

Lowrail's boot facts, allocation censuses and JIT fallback counts found work maintainers accepted (seven Rails
PRs, sqlite3-ruby#758, Prism#4298, three Campfire PRs and five ruby/ruby JIT fixes by 2026-11-02;
[ledger](upstream/contributions.md)). Its own runtime lowering failed the YJIT gate
([Bet S](decisions-prototype.md#bet-s-runtime-lowering-parked-2026-10-23)). Feature #22459 was declined
(tenderlovemaking: it is the JIT's job, fix the framework code; alanwu: no reason to ship the primitive), and
ruby/ruby#19488 was closed for too little gain (≈0.07% of railsbench sends).

**Decision.** Lowrail is a discovery tool. It measures real open-source Rails apps on Rails main, finds avoidable
work, and upstreams small, exact fixes where the work lives: Rails, Ruby/ZJIT, gems. Finding ZJIT leads in those
apps is a goal of its own. Advisory types/MCP are parked ([types-usefulness](types-usefulness.md)). The runtime
gem, guards and sealed tier stay in the tree as research, unchanged and not promoted. Stopped: new interpreter-Ir
pricing, sealed-tier breadth, guarded endpoints, Rails 8.2 sealed re-certification, further promotion of #22459.

**Prefer broad, idiomatic patterns** that every app runs (`where`, SELECT compilation, `tag.*`, params/enum
`fetch`, block forwarding) over single-app hotspots. App numbers are breadth evidence, not the headline.

## Working mode

* **Decide, then document** (Thomas, 2026-11-03). Within these rules, go with the recommendation you think is
  right and record it here with its reason, instead of asking. Ask Thomas only for destructive or irreversible
  actions, releases, visibility changes, reversing a decision he made, and before posting a reply that pushes back
  on a maintainer or answers an "is this worth it" challenge.
* **Orb reports are claims.** Check a decision-bearing fact before relaying it.
* **Always thank maintainers and reviewers** (Thomas, 2026-11-04) in every reply and closing comment, in one plain
  sentence.
* **Child orbs don't notify Thomas** (Thomas, 2026-11-04). They report only to the coordinating thread with
  send_thread_message, never with notify_user, and their threads are snoozed indefinitely. The coordinator relays.
* **At most 8 working orbs at once** (Thomas, 2026-11-03). A larger orb (`a1.xxlarge`) is fine for long parallel
  runs such as Ruby builds or a census; it doesn't reduce wall-time noise, and Callgrind stays primary.
* **No upstream references in Lowrail commit messages.** A commit message containing `owner/repo#N` or an issue or
  PR URL puts a public "added a commit that references this issue" entry on that upstream thread, and a force-push
  does not remove it. Name upstream work in plain words in commit messages ("Ledger: the Kernel#dup reply"); links
  belong in the docs, where they create no entry.
* **Commit identity.** Commits are authored and committed by Thomas Klemm `<github@tklemm.eu>` via `/usr/bin/git`,
  with no Amp or co-author trailer (`/opt/git` adds one). Upstream: one commit per fix on a freshly fetched base.

## Upstream etiquette

* **Comment only when the thread needs it:** to answer a question asked there, to report a bug or a verified fix
  that bears on it, or with a change the thread is waiting for. Benchmarks of others' PRs, related breadth (e.g.
  Rails data on k0kubun's lobsters burndown Shopify/ruby#1039), overlap with our PRs and comments that claim an
  issue stay in our docs; our PR is the claim. Never ask anyone to merge, rerun or review faster.
* **Collaborative, not credit-seeking** (Thomas, 2026-11-03). Upstream work is shared. Don't point out overlap
  with our PRs, ask who lands what, or offer to close ours in favor of theirs. If someone else's PR covers ours,
  close ours with one neutral line.
* **Well-reviewed PRs over issue discussions** (Thomas, 2026-11-03). We put our effort into small, well-reviewed
  pull requests. We don't open issues or join issue discussions on things Thomas does not understand well himself,
  or where we have little to add at that moment; an issue needs a verified bug or a question we can answer
  ourselves. New issues need Thomas's OK. Past mistakes stay as they are (no GitHub Support requests to erase
  them); the rules above prevent repeats.
* **Write "I", not "we".** One account is one person.
* **Closing comments:** thank, accept the point, leave one neutral fact for the record; don't belittle our result.
* **Search before building:** open, closed and Dependabot PRs, issues, and earlier maintainer decisions in the
  target repo (missed on 2026-11-03: cbor-ruby#31, tiktoken_ruby#130, ruby/ruby#16909).
* **ZJIT ideas are free to take** (k0kubun on
  [Shopify/ruby#1100](https://github.com/Shopify/ruby/issues/1100#issuecomment-6611201953): "It's free to take.
  Unless there's a particular issue … that has an assignee or an active PR, feel free to work on any of the
  ideas."). An idea is taken only if its own issue has an assignee or an open PR exists (e.g. ruby/ruby#18326 for
  sendforward). A name in the assignee column of a tracker table (e.g. Shopify/ruby#1039's rows) also counts as taken:
  check it before building. Lead 7 was built and then found to be row 7, assigned to k0kubun, so it stays unopened.
* **YJIT is in maintenance mode** (XrXr on
  [ruby#19664](https://github.com/ruby/ruby/pull/19664#pullrequestreview-5752852916); k0kubun on
  [ruby#19671](https://github.com/ruby/ruby/pull/19671#issuecomment-6596469897)). JIT performance and
  allocation-parity work targets ZJIT; YJIT gets correctness fixes only; YJIT findings go to
  [yjit-leads](upstream/yjit-leads.md) and are not built. Our open YJIT PRs stay open and maintained (Thomas);
  the maintainers decide on them.

## Pull requests

* **Plain language upstream** (Thomas, 2026-11-03, after tekknolagi on
  [Shopify/ruby#1058](https://github.com/Shopify/ruby/issues/1058#issuecomment-6613994853): "This LLM shorthand
  output may be readable to you … but it is not for us … Please don't make meat proxies out of us both."). Every
  comment, PR body and issue is written for a maintainer who has not seen our notes:
  * full sentences, no shorthand, arrows, internal labels (B, R, P, C1, "patch points¹") or undefined terms;
  * every number says what was measured, on what, with what, and against which baseline (for example "27% more
    Callgrind instructions per call for a three-entry Hash, JITs off"), and instructions are never called time;
  * lead with the answer to the question asked; prefer three short paragraphs to a dense table with footnotes;
  * before posting, a separate Sol pass checks the facts against our doc and reads it as an outsider would. A text
    that fails is rewritten, not trimmed.
    Rewrites of already posted bodies that add no new claims may use any separate reviewer (2026-11-03: no codex
    in the rewrite orb); edit a body only when the old one is hard to read.
  We don't add an AI disclaimer to every PR; where it matters (as on #1058) we say so plainly.
* **Thomas can explain it first** (Thomas, 2026-11-03). Before a ruby/ruby PR or any issue opens, Thomas can say
  in two or three sentences of his own what is wrong, what changes and why that is safe. I give him a short
  explanation with a minimal example; the PR opens only when he can retell it. The agentic work (builds, numbers,
  reviews) comes after that, not instead of it. Until Thomas lifts it, no new ruby/ruby PRs open at all
  (2026-11-03): finished candidates are recorded in the queue, not opened (ruby/ruby-bench is not covered; a fix for our own test that turns others' CI red is an approved exception,
  2026-11-04); new rails/rails PRs are prepared through the full review path and held
  until Thomas has read them, then opened ready for review (rails/rails asks for no draft PRs, since drafts notify
  every watcher); open
  PRs and issues he can't stand behind are closed with one neutral line.
* **One concern per PR.** A ruby/ruby PR touches the VM, YJIT or ZJIT, never two of them (tekknolagi on
  [ruby#19661](https://github.com/ruby/ruby/pull/19661#issuecomment-6607345199)). Dependent changes go into one PR
  as separate commits; open a follow-up only after its base has merged. Never stack on an open PR.
* **Cross-link interlocking changes in the body** (Thomas): one sentence with owner/repo (e.g. rails/rails#59557 ↔
  ruby/ruby#19662), updated when the other side moves, never as an extra comment. Every cross-repo reference
  carries owner/repo; link branches instead of naming them.
* **rails/rails body,** about 180 words, no headings, no template checklist. Paragraph 1: what is wasted and where
  it runs. Paragraph 2: what changes and the one boundary a reviewer would ask about. Then one per-call
  before/after table: objects, and CPU in ns and Ir for interpreter and YJIT on the Ruby pin, with its A/A. One
  sentence of ruby-bench placement ("within noise" is fine) and app breadth; one sentence on how the site was
  found, linking the census doc in the public Lowrail repo (Lowrail named as my research project; Roundhouse not
  mentioned). No per-app tables, review history or receipts.
* **ZJIT evidence in the tools' own format** (k0kubun on ruby/ruby#19680, 2026-11-04): raw `run_benchmarks.rb`
  output and a ZJIT stats diff in diff format, leaving out diffs within noise; not tables of percentages.
* **ruby/ruby body:** about 100 words plus one micro table, with the ruby-bench headline effect or the
  correctness repro.
* **Restore and compatibility PRs name their callers** (Thomas, 2026-11-04): when a PR brings back or bridges
  something main removed, the body says in a sentence or a short list who uses it (gem or app, file, the call), so
  the PR doesn't stand alone. Every bug, regression and compatibility PR ends with a one-line `<sub>` footer after
  `---` saying how it was found, linking the matching record in the public Lowrail repo (ecosystem-tests,
  app-suites, api-regressions, rails-82-differential).
* **No code comments** unless the code would be misread without them; why a change is equivalent goes in the body.

## Playbook from the PR retrospective (2026-11-04)

Adopted from [pr-retrospective](upstream/pr-retrospective.md), which has the PR evidence for each rule. The first
three change earlier decisions and were approved by Thomas on 2026-11-04.

* **Thomas owns the ruby/ruby review conversation** (Thomas). No LLM attribution, and only work he can explain in
  every detail, as the ZJIT team asks ("stand behind your contribution as if unaided"). He answers reviews himself
  or approves every answer before it is posted. This is the precondition for lifting the ruby/ruby stop.
  Update (Thomas, 2026-11-04): the coordinator may post focused, reviewed replies and body updates on ruby/ruby
  himself and tells Thomas afterwards, each with a short explanation Thomas can retell.
* **Ask on the tracker before ZJIT design changes** (Thomas). Profiling, speculation, invalidation, recompile
  policy, new per-ISEQ state, new HIR instructions, or more than about 150 lines: first a Shopify/ruby issue with
  one concrete ask and the data, then a PR once the team says go. This narrows "well-reviewed PRs over issue
  discussions" for ZJIT design.
* **Gems: at most 2 unanswered PRs per repository** (Thomas). Check maintainer activity and the repo's idioms
  before building.

* **Pace on ruby/ruby** (once new PRs are allowed again): at most 2 new PRs a week, the next only after a maintainer
  has responded to the previous one, one PR per finding.
* **A ZJIT performance PR needs a run_benchmarks.rb effect outside A/A**, unless the team asked for the change or it
  removes a permanent exit.
* **Evidence is one base / A/A / head comparison**, only the stats that move, with under about 120 words of prose.
* **Show the mechanism** (HIR or the changed path) on the real call shape and on the smallest common input, not
  only on the input that benefits most.
* **No follow-ups to a fix a maintainer called narrow, and nothing in code a maintainer is reworking.** The search
  before building includes recent maintainer commits and PRs on the same functions.
* **Answer review with the change or one named blocker**, not a menu of options.
* **Closing comments don't reopen decisions**: thanks, the reason, nothing more.
* **Tests test one thing**, plus asserts on the invariants the change relies on.
* **Report zjit_alloc_bytes** for any new per-ISEQ or per-profile state.
* **Rails:** keep the pattern (small, obvious, numbers from real apps). Drop or simplify L2 candidates and any that
  need more than two exactness rounds.

* **Standing OK for the 2026-11-04 Rails round** (Thomas, 2026-11-04). The candidates and bug fixes from the census
  backlog, C9 (CP-3, CP-5), C11, C13 and C15 may open on rails/rails without another read by Thomas, once they have
  passed the full review path plus a Sol review run by the coordinator. Opening a PR on top of one of our open PRs
  (stacking) stays out: such a candidate opens only if it applies to main on its own, otherwise after the first merges.
  No per-orb limit and no spacing on rails/rails (Thomas): a finished, reviewed candidate opens right away.

## Submission queue (2026-11-03)

Every finished candidate (review gates passed, body drafted) goes into the **Queue** section of
[upstream/contributions.md](upstream/contributions.md), ranked by effect and breadth, and opens only when its repo
has room. Open the strongest first. A candidate made moot upstream leaves the queue with a note.

* **rails/rails:** at most 20 of our PRs open (Thomas). Keep each PR small.
* **ruby/ruby:** at most 10 of our PRs open, counting all of them (VM, ZJIT, YJIT, backports) (Thomas, 2026-11-04;
  20 before). We have to get better at ruby/ruby PRs first, so none open for now, not even under the cap. The ones
  already open stay open unless there is a reason to close one and report it as an issue instead; such a close is
  proposed to Thomas with the reason. The previously recorded slots (GC pool-budget fix, lead 3, Z13's top lead,
  Shopify/ruby#1064, #1065, #1091, #1058) stay in the queue and do not open.
* **gems:** at most 2 of our PRs without a maintainer response per repository (Thomas, 2026-11-04; no limit before).
* **Keep open PRs mergeable** (Thomas): resolve conflicts promptly and keep CI green where the failure is ours
  (show unrelated failures fail on base when asked). Don't force-push without a conflict, a requested change or a
  failure of ours, because each push notifies reviewers and reruns CI.
* **Approved and unmerged after 14 days:** one short, neutral note on a weekday (Thomas), never asking anyone to
  merge. Once per PR.

## Evidence and measurement

* **Ruby pin 4.0.9** (Thomas, 2026-11-03) for the census and Rails PR evidence; 4.0.8 and 4.0.9 are bugfix and CVE
  releases. Never compare across pins; every A/A and every main-versus-branch pair runs on one pin. Open PR bodies
  with 4.0.7 numbers stay; they name their Ruby.
* **4.1 is measured on pinned Ruby master, SHA recorded** (2026-11-03): boot, interpreter, YJIT and ZJIT
  allocations with A/A, on the same build as the ZJIT pass. 4.1.0-preview1 was dropped: it predates our merged
  Ruby PRs, its regressions may already be fixed on master, and fixes land against master. When 4.1.0 ships the
  routine cell moves to 4.1. Cells and cadence: [measurement-matrix](upstream/measurement-matrix.md).
* **Every census adds a ZJIT stats pass on master.** ZJIT stats on apps need `--zjit-exec-mem-size=512
  --zjit-mem-size=1024`, and `compile_error_out_of_memory` must be 0 in every run before a counter is reported.
* **Every new ZJIT lead is written down** (Thomas, 2026-11-03), wherever it turns up: a census, a review, a PR
  build, a side exit seen in passing. Add it to the
  [lead queue](upstream/zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03) with the fallback reason or exit,
  a repro or the app and site, counts per op and on ruby-bench where known, and whether it is free or taken. An
  unmeasured lead goes in too, marked unmeasured. Nothing is posted upstream for it. A lead goes upstream as a PR
  when we can build it. An issue is opened only for a correctness bug (crash, wrong result, interpreter/JIT
  divergence) with a minimal repro, which we file even if we also fix it (like Shopify/ruby#1101). Performance
  leads never become issues on their own.
* **Where claims come from.** Callgrind instruction counts with fixed heap and A/A are primary
  ([bench.md](bench.md)). App pages find sites but can't price them (A/A up to ±7%). ZJIT speed claims come from
  ruby-bench with A/A.
* **Every Rails candidate also reports its micro on master × ZJIT** (pinned build, A/A), or says its path doesn't
  run on 4.1. A ZJIT loss blocks it until explained; #59557's `index_with` lost under ZJIT although it only
  changed allocation. Rails changes made only for ZJIT need a win of their own on the Ruby pin.

## Review gates

### Readability gate (L0–L3)

Thomas, 2026-11-03; rated as part of the primary review's maintainability rubric. L0: no harder to read; opens if
exact and measurable. L1: slightly unusual but clear at once; needs a per-call CPU gain outside the A/A. L2:
noticeably more complex (a new helper, lazy arrays, copied internals); needs an effect measurable in an app or on
ruby-bench. L3: a duplicated method, a Ruby-version branch, index loops, or code that needs comments; don't open.
ruby/ruby additionally needs a measurable ruby-bench effect or a correctness repro (#19488 and #19625 were closed
for lacking one).

Readability checks added 2026-11-04 (Thomas: "always watch for readable code"), after #59608's first shape
reassigned a variable inside an `unless`:

* **Describe it out loud first** (Thomas). Before any review, the author writes the changed code as plain sentences,
  one per line or branch, as if reading it to a colleague ("take the current formats; if the template's single
  format already leads them, keep the list as it is, otherwise put it in front"). If a sentence comes out awkward,
  needs "except" or "unless also", or can't be said without naming a variable twice, refactor the code until the
  description is simple, then measure again. The fastest form isn't required: a readable form that keeps most of the
  gain wins. The final description goes into the review record and, shortened, into the PR body.
* **Cold read.** A reviewer who hasn't seen the change states in one sentence what each branch does and why each
  condition is there. If that takes a second try, rewrite before opening.
* **Shape checklist.** Each case gets its own branch, with no reassignment inside a conditional modifier and no
  ternary longer than one short line. Sentinel or identity checks (`equal?`, placeholder values) get a one-line
  comment saying why. No new name used only once. The diff reads like the surrounding code.
* **Numbers as a signal, not a gate.** Record the change in `flog` score and RuboCop `Metrics/*` (ABC size,
  cyclomatic and perceived complexity) for each touched method, before and after. A rise needs a sentence of
  justification in the review. These numbers miss shape problems, so they never replace the cold read.

### Short PR bodies (2026-11-04)

Thomas, after reading all of today's Rails PRs: "Beschreibungen könnten etwas kürzer sein, weniger Wall of Text".
A human reviewer has to get the essence in a few seconds.

* **Shape:** the first sentence says what changes, the second why it is safe or what it fixes. Then one small
  table or a single line of numbers. Aim for about 180 words in total, table and code names included (Thomas, on #59617); well above that needs a reason.
* **Scope caveats** take one clause each, not a paragraph. Methodology, A/A values, rejected variants and
  differential sizes stay in the Lowrail doc, or go in a `<details>` block at the end if a reviewer will want them.
* Sol's and the outsider's wording fixes are made by shortening the text, not by adding to it.
* **Correctness PRs carry no performance numbers** (Thomas, on #59617). The body says what was broken, what now
  happens and what was tested. Cost measurements stay in the Lowrail doc and come up only if a maintainer asks,
  unless the fix measurably slows a common path.

### Correctness fixes: readable first (2026-11-04)

Thomas: for bug and correctness fixes, no code golf. The fix is written as readable and idiomatic as possible,
in the shape a maintainer would write it. Performance is a side note: measure only to rule out a clear slowdown on
a common path, never to choose between two correct shapes, and keep the numbers out of the body (see above). The
L0–L3 performance bars don't apply; the cold read and the shape checklist do. Correctness findings that come up
along the way get their own PRs.

### Primary review

Before the queue, every candidate passes an independent Thermos review on both rubrics (correctness,
maintainability): GPT-6.1 Sol for Rails and gems, GPT-6 Astra (`gpt-6-astra`) for ruby/ruby.

### Exactness checklist

Every orb runs this list against its candidate with a differential harness before review, and its report says
which items it checked:

1. Singleton methods on arguments and intermediate results, including private ones, `extend`, prepended modules
   and `method_missing`/`respond_to_missing?`; `instance_of?` does not exclude them.
2. Subclasses of Hash, Array and String with their own `to_a`, `each`, `map`, `merge`, `[]=`, `include?`, `gsub!`.
3. Implicit conversions (`to_ary`, `to_a`, `to_s`, `to_hash`), public and private, with call counts.
4. Every call the change adds on a user-supplied object (even `equal?`, `force_encoding`) and every call base made
   that the change skips (e.g. a `gsub!` that raises on a frozen String).
5. Results returned by user code are copied as base did, never adopted as an accumulator.
6. Mutation during conversion or iteration (live Hash vs snapshot), and fibers suspended there.
7. Frozen receivers, arguments and results; exception class and message.
8. Load order and standalone `require`; configuration read before vs after the work, as in base.

Accepted without a fix, unless the change is escaping or SQL safety: global redefinition of core methods,
overrides of private (nodoc) methods, reaching internal Arrays through ObjectSpace.

### Extra adversarial Astra round for critical changes (2026-11-03)

Critical changes get a second round after the primary approves: Astra for Rails and gems, Sol for ruby/ruby, with
an adversarial brief. It tries to break identical behavior with inputs, overrides, prepends, threads, reloading and
error paths, runs them where it can, and reports only demonstrated differences. **Critical:** escaping or other
security boundaries, connection or transaction handling, record loading and typecasting, caching or memoization,
thread or fiber state, VM/JIT code. A critical candidate is ready only after both rounds.

### Replies to value challenges

A reply to "is this worth it" or any other pushback is drafted, checked once for facts and tone, and shown to
Thomas before posting.

## Bets

Priorities (Thomas, 2026-11-03): Rails and ZJIT first, then gems. Parked: types/MCP, YJIT, ruby/uri, the Campfire
lead. States change often; each bet's doc is the source of truth.

| Bet | Goal | Doc |
| --- | --- | --- |
| Z10 | per-ISEQ ZJIT stats on the apps; leads 7 and 3 are being built | [zjit-iseq-leads](upstream/zjit-iseq-leads.md) |
| F1 | frontier census: 20 apps on Rails main × master, ZJIT fallbacks and exits | [measurement-matrix](upstream/measurement-matrix.md) |
| F2 | our merged Rails PRs under ZJIT | [measurement-matrix](upstream/measurement-matrix.md) |
| C8 | census 8 (CPU and allocations) on 4.0.9 and pinned master | [census](upstream/census.md) |
| Z5–Z8, Z12 | objtostring, compile speed, cfunc paths, stats correctness, warmup | [zjit-shortlist](upstream/zjit-shortlist.md) |
| Z2, Z11 | ZJIT differential on Rails and app suites: done, no divergence | [zjit-app-differential](upstream/zjit-app-differential.md) |
| V1, A1, S1 | Action View, Active Record and JSON serialization CPU | [actionview-cpu](upstream/actionview-cpu.md) · [activerecord-cpu](upstream/activerecord-cpu.md) · [serialization-cpu](upstream/serialization-cpu.md) |
| G1, I18N | gem census; i18n deep dive; gem request census and round 2 (rack K1 #2550, nokogiri N1 #3759 open; i18n, tzinfo, importmap-rails, mail left alone) | [gem-census](upstream/gem-census.md) · [i18n-performance](upstream/i18n-performance.md) · [gem-request-census](upstream/gem-request-census.md) · [round 2](upstream/gem-request-census-2.md) |
| R6 | relation delegators `...`, `default_scope` owner checks | [rails-r6-leads](upstream/rails-r6-leads.md) |
| E2 | make the 13 census configurations that fail on Ruby master install, via gem fixes upstream; doubles the corpus every ZJIT pass sees. 11 of 13 install; Chatwoot and Flow are blocked | [gems-on-master](upstream/gems-on-master.md) |
| Z13 | where ZJIT spends more Ir than YJIT on railsbench, lobsters and shipit, classified into buckets that become leads | zjit-yjit-gap (planned) |

Chosen 2026-11-03 for reach. E2 unblocks ZJIT measurement on Mastodon, Discourse, Chatwoot, Lobsters and Loomio, and
the gem fixes are needed for 4.1 anyway. Z13 measures the gap to YJIT directly instead of inferring it from fallback
counts. One orb slot stays reserved for Rails candidates from C8's CPU census; the Rails queue is otherwise empty.

## Learnings from 2026-11-03

The incidents behind the rules above, kept so the rules keep their reasons:

* Two Shopify/ruby#1039 comments and one ruby/ruby#18960 comment were deleted as unsolicited data → comment rules.
* A draft offering to close ours if a maintainer would rather land the rows himself read as credit-seeking (not
  posted) → collaborative, not credit-seeking.
* fatkodima on [rails#59577](https://github.com/rails/rails/pull/59577#issuecomment-6606427493) asked for
  provenance and impact and called the code more complex for questionable benefit; #59577 and #59557 went too far
  → CPU and provenance in the body, readability gate.
* cbor-ruby#43 duplicated nobu's open #31; tiktoken_ruby#130 and ruby/ruby#16909 were missed → search before
  building.
* tekknolagi called our dense #1058 reply unreadable LLM shorthand and asked not to be made a proxy for it; Thomas
  edits that reply himself → plain language upstream, with an outsider-readability pass.
* A bare `#19583` in Shopify/ruby linked the wrong repo twice → owner/repo on every reference.
* The 64 MiB ZJIT default filled in most app passes → memory flags and the zero-OOM check.
* #19665 was relayed as a correctness fix and is not; Discourse and Mastodon were named as old-Bundler examples and
  lock 4.0.23 → orb reports are claims.
* S1, C7-1, I2 and C1 each needed three to five review rounds for the same classes of difference → exactness
  checklist.
* Several limits were set and changed within one day → one cap per repo, named exceptions, recorded here.

## Orb time (Thomas, 2026-11-04)

Amp orbs are billed per minute while running, by size (a1.tiny 1 CPU/2 GB $0.08/h, small 2/4 $0.17, medium 4/8
$0.33, large 8/16 $0.66, xxlarge 16/32 $1.32). A paused orb costs nothing; an orb pauses 5 minutes after its agent
finishes (20 after a human interaction), and immediately when the thread is archived. Orb Saver Mode is on, so
opening a thread doesn't wake it.

* **a1.medium minimum, a1.large is fine.** The project default is **a1.medium** (was a1.large); smaller orbs are
  too small (Thomas, 2026-11-04). Pass `orb_size` on every create_thread: **a1.medium** for watchers, coordination,
  reviews, ledger and docs work and light suites; **a1.large** for Ruby builds, Rails framework suites, app and gem
  suites, differential harnesses and benchmarks. **Above a1.large** (xxlarge, 3xlarge) only for a short, focused
  burst that needs it, such as a full Rails matrix or a parallel bisect; say why in the prompt and archive the
  thread as soon as that step is done.
* **One central watcher** (W1) watches every open upstream PR every 30 minutes and reports only what
  matters; worker orbs keep no PR watch schedules.
* **Let orbs pause:** no sleep loops or long polling, finish a step and stop; stop long-running services when done;
  batch messages to other threads, since every message wakes the receiving orb for at least 5 minutes.
* **Archive finished orbs** instead of leaving them open; their records live in this repo.
* Check usage with `amp orb system-metrics <thread>` (cores, memory, CPU over time) before choosing a size for a
  similar task. Measured on 2026-11-04: all 17 active orbs were a1.large; the coordinator, the watcher, C15 and G2
  averaged 3–10 % CPU, and the busiest workers 50–65 %.

## Line permalinks for callers (Thomas, 2026-11-04)

Every caller we cite in a PR body, issue or ledger record links to the exact line, so a reader can check the claim in
one click.

* Use a **commit-SHA permalink** (`blob/<sha>/path#L42`), never `blob/main`; a branch link drifts as soon as the file
  changes. For a gem, take the commit behind the tag of its **latest released version** and name that version in the
  link text; if the gem has no tag, use the release's "Bump to x.y.z" commit or the gem's source on rubygems.org.
  For an app without releases, use the default branch's current SHA and name the branch.
* Also check the gem's default branch: if the call is already fixed there, say "fixed on main, unreleased" instead of
  calling it a break.
* Quote the line exactly as it appears at that SHA, or mark the quote as shortened.
* Before posting, fetch each file at the linked SHA and confirm that the linked line contains the quoted call.

## When Rails restores a private API, and other open calls (decided 2026-11-04 at Thomas's request)

* **Restores.** Public API removed without a deprecation: restore it, deprecated if the new name is better. Private
  or `:nodoc:` API: restore it only when all three hold, otherwise fix it in the gem or app that uses it:
  1. the removal is **unreleased**, so a restore costs maintainers no new compatibility promise,
  2. **several real callers** (released gems or apps, cited with permalinks) break, or one large one breaks
     silently or wrongly, and
  3. the restore is **small** and keeps the change's purpose: a deprecated shim, an alias, a signature, not a
     revert of the feature.
  The PR says openly that the API is private and names the callers. #59629 (`find_template`), #59630
  (`filter_proxies`) and AR-4 (`where!`/`having!` binds) meet all three and stay open or queued. Private
  breakage that fails any of them (build_bind_attribute, `_prefixes`, Vary changes) is record-only, or goes to the
  gem or app when the fix there is small and the maintainers are active.
* **Open gem PRs** (inertia-rails, i18n, rubocop-performance, others): no pings. One short, friendly ping only after
  four weeks without any maintainer reaction; closing only at a maintainer's request or when superseded.
* **rspec-rails release:** no issue for now. Ask once a Rails 8.2 beta is out, because then its unreleased Rails-main
  fixes block real users.
* **Unreleased upstream evidence** (for example ransack's main-branch spec) may be cited when the body says it is
  unreleased.

## No comments on others' PRs without Thomas's approval (Thomas, 2026-11-04)

We don't comment on other people's PRs or issues (measurements, reviews, suggestions, thanks) unless Thomas has
explicitly approved that specific comment. Their PR description is theirs; what we measure about their work stays in
our records. Orbs draft at most, and ask the coordinator, who asks Thomas. A benchmark comment on rails/rails#59141
was deleted for this reason. Replies on our own PRs and issues are unaffected.

Approved comments follow the style Thomas liked on rails/rails#57013 (2026-11-04): open with "Heads-up in case
it's useful:", state the effect in one sentence, give the minimal repro, name an existing fix or PR if there is
one, and stop. No thanks, no judgement of the work, no proposals beyond what was asked, no numbers that weren't
asked for.

**Exception: answers that were asked for** (Thomas, 2026-11-05). When someone asks us for an answer, a re-test or a
data point, post it directly and promptly, without asking Thomas first, as long as it is reviewed and measured
properly and helps constructively. Example: eightbitraptor's re-test request on ruby/ruby#17251. Everything
unsolicited still needs Thomas's approval.
