# Decisions archive

<!--
Moved out of DECISIONS.md on 2026-11-25 (cleanup agreed by Thomas on 2026-11-25). Each quoted block is verbatim from
docs/DECISIONS.md at d72d947c (only the leading "> " is added); the line above it says why it moved and what
replaced it. Nothing here is in force unless DECISIONS.md says so. Where every paragraph of the old file went, line
by line: bench/upstream/decisions-cleanup/mapping.md. Three #self-links inside quotes (to #review-gates,
#pr-descriptions-… and #code-comments-in-upstream-patches-…) pointed into the old DECISIONS.md and do not resolve here.
-->

Superseded wording, status notes about single items, one-off exceptions for items already opened, merged or closed,
and history, moved out of [DECISIONS.md](DECISIONS.md) on 2026-11-25. The rules in force are there; nothing here is
in force. Each quote is verbatim; the line above it says why it moved and what replaced it. Three #self-links inside quotes
point to the old file and do not resolve. The paragraph-by-paragraph
mapping is in [decisions-cleanup/mapping.md](../bench/upstream/decisions-cleanup/mapping.md).

## Superseded rules

### Register intro

Replaced by the new intro, which points to this archive for earlier wording instead of git history.

> # Decision register
>
> What we pursue, what is parked and what is rejected, with the reason. Numbers live in the linked docs; this page
> records the rule and why. Rules are grouped by topic, with a date or owner only where it decides something. The
> parked runtime-lowering prototype's decisions are in [decisions-prototype.md](decisions-prototype.md). Earlier
> wording of these rules is in git history (before 2026-11-03 19:00 UTC).

### Larger orbs for long parallel runs (2026-11-03)

Replaced by [Orb time](DECISIONS.md#orb-time-thomas-2026-11-04) (2026-11-04): a1.large for builds, suites and
benchmarks, above a1.large only for a short, focused burst. The cap of 8 orbs stays.

> * **At most 8 working orbs at once** (Thomas, 2026-11-03). A larger orb (`a1.xxlarge`) is fine for long parallel
>   runs such as Ruby builds or a census; it doesn't reduce wall-time noise, and Callgrind stays primary.

### Rails PRs held until Thomas has read them, opened ready for review (2026-11-03)

Replaced by "rails/rails opens as draft" (2026-11-05) and "Every upstream PR opens as a draft, and only Thomas marks
it ready" (2026-11-05 night) under [Submission queue](DECISIONS.md#submission-queue-2026-11-03). The ruby/ruby stop
and the closing rule in the same sentence stay in DECISIONS.

>   reviews) comes after that, not instead of it. Until Thomas lifts it, no new ruby/ruby PRs open at all
>   (2026-11-03): finished candidates are recorded in the queue, not opened (ruby/ruby-bench is not covered; a fix for our own test that turns others' CI red is an approved exception,
>   2026-11-04); new rails/rails PRs are prepared through the full review path and held
>   until Thomas has read them, then opened ready for review (rails/rails asks for no draft PRs, since drafts notify
>   every watcher); open
>   PRs and issues he can't stand behind are closed with one neutral line.

### Dependent changes in one PR, never stacked (2026-11-03)

Replaced by "Stacked PRs open right away" (Thomas, 2026-11-05) under Submission queue. "One concern per PR" stays.

> * **One concern per PR.** A ruby/ruby PR touches the VM, YJIT or ZJIT, never two of them (tekknolagi on
>   [ruby#19661](https://github.com/ruby/ruby/pull/19661#issuecomment-6607345199)). Dependent changes go into one PR
>   as separate commits; open a follow-up only after its base has merged. Never stack on an open PR.

### Standing OK for the 2026-11-04 Rails round

One-off for C9 (CP-3, CP-5), C11, C13 and C15, all handled. Its "no per-orb limit and no spacing on rails/rails" was
replaced by "rails/rails: only the most urgent findings open" (2026-11-05 night) and the draft rules.

> * **Standing OK for the 2026-11-04 Rails round** (Thomas, 2026-11-04). The candidates and bug fixes from the census
>   backlog, C9 (CP-3, CP-5), C11, C13 and C15 may open on rails/rails without another read by Thomas, once they have
>   passed the full review path plus a Sol review run by the coordinator. Opening a PR on top of one of our open PRs
>   (stacking) stays out: such a candidate opens only if it applies to main on its own, otherwise after the first merges.
>   No per-orb limit and no spacing on rails/rails (Thomas): a finished, reviewed candidate opens right away.

### Rails drafts only when Thomas asks (2026-11-05)

Replaced by "Every upstream PR opens as a draft, and only Thomas marks it ready" (2026-11-05 night): agents may open
reviewed items as drafts in any repo with room. "Only Thomas marks drafts ready" is stated once there. The draft
rule and the 15-PR note stay.

>   Only Thomas marks drafts ready. Keep each PR small.
> * **rails/rails opens as draft** (Thomas, 2026-11-05): we open Rails PRs as drafts in small batches when Thomas asks,
>   preferably grouped by theme and likely reviewer. The queue no longer opens Rails PRs on its own. Drafts don't count toward GitHub's limit of 15 non-draft PRs.

### Ping after 14 days approved and unmerged

Archived because "Open PRs and issues anywhere: no pings" (Thomas, 2026-11-17) covers it: a note on an approved, unmerged PR is a ping.

> * **Approved and unmerged after 14 days:** one short, neutral note on a weekday (Thomas), never asking anyone to
>   merge. Once per PR.

### Claude Code orbs and a final Claude Code review (Thomas, 2026-11-06)

Replaced by "One detailed review instead of two" (2026-11-17) and "Thermos on Sol is the default review; Opus 5.5
instead of Claude Code" (2026-11-18). "Commits are few and clean" stays under Pull requests.

> ### Claude Code orbs and a final Claude Code review (Thomas, 2026-11-06)
>
> New work orbs run as Claude Code (`external-agent:claude-code`). Orbs that are already running may finish, but before anything goes upstream (PR, push to an open PR, body edit or reply), a separate Claude Code orb does a thorough final review. That review covers the exact head, the commit messages and the text. Its pass is recorded as `reviewer: claude-code`. Sol/Astra stay as additional gates. Commits are few and clean, and the reasoning goes in their messages.

### Sol 6.2 allowed (2026-11-17)

Replaced by "Sol reviews stay on GPT-6.1 Sol" (2026-11-25). The RUBY19659 first-use note is status.

> Models (Thomas, 2026-11-17): Astra means GPT-6 Astra (`openai/gpt-6-astra`). Sol stays GPT-6.1 Sol; Thomas allowed
> trying Sol 6.2, but it isn't offered yet.
> Sol reviews stay on GPT-6.1 Sol (Thomas, 2026-11-25): GPT-6.2 Sol's safety check stopped a JIT review as possible
> security work. Fable (`anthropic/claude-fable-5-2`) may be used wherever it helps (Thomas, 2026-11-25), such as hard
> design rounds or an extra review of a large change. A thermos review on Fable is recorded as
> `reviewer: thermos-fable` and counts where a `thermos-opus` pass does (first use: RUBY19659, 2026-11-25).

### Review rounds: skeptic, Sol via codex, Astra, thermos (Thomas, 2026-11-05)

The required passes were replaced in turn by claude-code (2026-11-06), one detailed review (2026-11-17) and
thermos-sol as the default (2026-11-18). The rest of the section stays in DECISIONS, reworded to the passes now in
force.

> ### Review rounds before anything opens (Thomas, 2026-11-05)
>
> Every upstream PR, issue or comment draft goes through as many review rounds as it needs, on its **current head**:
>
> 1. The orb's own skeptical reviewer subagent, rerun after every rewrite (most orbs have no Codex CLI).
> 2. Sol (`codex exec -m gpt-6.1-sol`, read-only), run by the coordinator on the patch and body.
> 3. Astra (`codex exec -m gpt-6-astra`) in addition for correctness changes on hot paths, Ractor/thread or
>    frozen-object semantics, and anything a maintainer has pushed back on before.
> 4. `thermos` for larger diffs (several files or a new mechanism).
>
> Every confirmed finding is fixed and the changed part reviewed again; the round ends when a pass has no must-fix.
> A head change after the last pass means another pass. An item is `reviewed` only when skeptic and Sol, Astra when
> `risky`, and thermos when the diff has more than 200 changed lines each approve (no must-fix) on its current `head`;
> `script/pr-queue open` and `ready` check this and refuse otherwise.
> Superseded 2026-11-06: claude-code replaces skeptic as a required pass (see [Claude Code orbs and a final Claude Code
> review](#claude-code-orbs-and-a-final-claude-code-review-thomas-2026-11-06)).

### Record footer in PR bodies (2026-11-14)

History of the "No footer" rule, which stays.

>   new here." Interlocking changes get one cross-link sentence with owner/repo. **No footer** (Thomas, 2026-11-15:
>   cleaner without; replaces the `<sub>` record footer of 2026-11-14, removed from every open PR the same day). How

### New orbs in the Medium agent mode (2026-11-05 night)

Already marked superseded (2026-11-06, Claude Code orbs; since 2026-11-18 Opus 5.5 threads).

> * **New orbs run in the Medium agent mode** (GPT, plenty of tokens); orb size as the task needs. Superseded
>   2026-11-06: Claude Code orbs, see [Review gates](#review-gates).

## Merged duplicates

Stated once in DECISIONS now; the wording here was folded into the section named.

"PR descriptions: see below": a pointer to the section in the same chapter.

> * **PR descriptions:** see [PR descriptions](#pr-descriptions-thomas-2026-11-03-to-11-05) below.

Gems cap: the cap of 2 unanswered PRs per repository is under Submission queue; the playbook keeps "check maintainer
activity and the repo's idioms".

> * **Gems: at most 2 unanswered PRs per repository** (Thomas). Check maintainer activity and the repo's idioms
>   before building.

Code comments: merged into [No unnecessary code comments in upstream PRs](DECISIONS.md#no-unnecessary-code-comments-in-upstream-prs-thomas-2026-11-10),
together with the 2026-11-18 maintainer rule and the byroot quote.

> * **No code comments** unless the code would be misread without them; why a change is equivalent goes in the body.

>   The same goes for code comments (Thomas, 2026-11-18): a comment stays only where that file's maintainer would keep
>   one, because a reader would otherwise undo or misread the line; one line, why not what, in the file's own style.

> ### Code comments in upstream patches (byroot on #59555, 2026-11-05)
>
> byroot, on the comment above our `Array#index_with`: "This isn't something that should be surfaced in Rails docs.
> it's an implementation detail. If anything that specialized version could be `:nodoc:`. I don't mind AI PRs, but
> please read them and curb their tendency to spew tons of comments." Fixed in #59659 by deleting the comment.
> (`class Array` is already `# :nodoc:` in that file, so the comment never reached the API docs. The volume was the
> real problem.)

> * **Comments are the exception.** Add one only when a reader would otherwise undo the code. Then it is one line,
>   and it says why, not what. Explanations of cost, Ruby internals or the regression belong in the PR body or the
>   Lowrail record.

> ## No unnecessary code comments in upstream PRs (Thomas, 2026-11-10)
>
> Superfluous comments read as AI slop (byroot on #59555, see [Code comments in upstream
> patches](#code-comments-in-upstream-patches-byroot-on-59555-2026-11-05)). A standing rule for every upstream PR:
>
> * **A code comment stays only when a reader would otherwise undo or misread the code.** Then it is one short line
>   that says why, not what, and the diff keeps the comment density of the surrounding upstream code.
> * **No comments that** restate the code, narrate the change, mention the PR, the benchmark or the measurement, or
>   explain what was removed. Those belong in the commit message, the PR body or the Lowrail record.

## Status notes and one-off exceptions

### Census 11 regressions (2026-11-25)

IX1 opened as a draft (rails/rails#59976); TA1 is superseded by rails#59858. The cap of 22 stays under Submission queue.

> * **Census 11 regressions** (coordinator, delegated by Thomas, 2026-11-25): IX1 (IndexDefinition readers removed by rails#59850; GitLab, Mastodon, online_migrations, active_record_doctor) opens as a rails/rails draft in the last free slot (22) once thermos-sol approves the exact head. TA1 (token-auth scheme argument) does not open: thermos-sol found it duplicates the open rails#59858 (czj, 2026-11-18), which also handles an optional third parameter that TA1 gets wrong; superseded, cap back to 22.

### Lead 7

>   check it before building. Lead 7 was built and then found to be row 7, assigned to k0kubun, so it stays unopened.

### Ready order given to Thomas (2026-11-05 night)

>   pass on the exact head; neither the coordinator nor W1 runs `script/pr-queue ready`. Ready order he was given:
>   #59662 OP8, #59663 ZM1, #59661 OP1, #59667 DC1, #59668 E2b.

### ruby/ruby cap and exceptions, as of 2026-11-25

"20 before" is history. F1 (ruby/ruby#19899) and BX1 (#19919) are closed, ZNE1 (#19909) merged, ZS1 (#19912) and
ZSV1 (#20169, draft) opened; BX1's lift of the two-a-week pace went with it. The lead 3 exception (held as ZL3) and the
moratorium stay in DECISIONS.

> * **ruby/ruby:** at most 10 of our PRs open, counting all of them (VM, ZJIT, YJIT, backports) (Thomas, 2026-11-04;
>   20 before). We have to get better at ruby/ruby PRs first, so none open for now, not even under the cap. The ones
>   already open stay open unless there is a reason to close one and report it as an issue instead; such a close is
>   proposed to Thomas with the reason. The previously recorded slots (GC pool-budget fix, lead 3, Z13's top lead,
>   Shopify/ruby#1064, #1065, #1091, #1058) stay in the queue and do not open.
>   Exception (Thomas, 2026-11-14): the small-Hash regression on master (F1, round 2) and ZJIT lead 3 (receiver classes
>   missing from a polymorphic send's profile) go upstream as PRs once built and reviewed, after the "Thomas can explain
>   it first" step. Exception (Thomas, 2026-11-15): ZS1, ZJIT specialization of Symbol block arguments (`&:sym`,
>   Shopify/ruby#1014's open "later step" after ruby/ruby#18180), because apps and gems use it everywhere; built with
>   Fable 5.2, same "Thomas can explain it first" step before opening. Closed the same day without a PR: the reachable ceiling is 0.04–0.38% of an
>   iteration on Rails main, and the send side is on Rafael França's unmerged Shopify branch, the yield side on k0kubun's
>   (docs/upstream/zjit-symbol-block.md).
>   Exception (Thomas, 2026-11-15): ZNE1, ZJIT handling of `!=` whose `!=` is `BasicObject#!=`, after skipkayhil closed
>   rails/rails#59811 with "Let's fix this in the JITs?"; a PR instead of a comment there, built with Fable 5.2. Exception (Thomas, 2026-11-16): BX1, the Ruby 4.1 regression where `bundle exec ruby -rGEM` loads the newest installed GEM instead of the locked one (round 3), goes upstream as a PR with the repro in its body instead of a Redmine issue ("easier for the maintainers"), once built and reviewed; this also lifts the two-a-week pace for it. Exception (Thomas, 2026-11-25): ZSV1, ZJIT profiling of the real class for `setinstancevariable` (Shopify/ruby#1122), opens as a draft once rebased onto current master and approved by thermos-sol and Astra on the exact head. The script's ruby/ruby cap is the 10 above; the moratorium holds for every other item.

### Compatibility PRs already open (2026-11-05 night)

>   inventory with callers and proposed fixes. The ones already open stay (blind_index#62 and scimitar#172 say they wait
>   for the beta).

### Held ideas closed on 11-05

>   Such ideas stay with us as `held` queue items ("parked idea" in the note) and are not opened later as they are;
>   #59673 PM1, #59674 PM3 and #59677 CB2 were closed on 11-05 for this reason.

### Old pins: rails/rails#59676

>   current releases of Rails, Ruby and gems. rails/rails#59676 (minitest 5.1–5.17, found via
>   active_model_serializers' old dev pin) stays open, but no more of this kind.

### Private-API restores that met the bar (2026-11-04)

The three conditions and the private-breakage rule stay in DECISIONS; the item states are status.

>   The PR says openly that the API is private and names the callers. #59629 (`find_template`), #59630
>   (`filter_proxies`) and AR-4 (`where!`/`having!` binds) meet all three and stay open or queued. Private
>   breakage that fails any of them (build_bind_attribute, `_prefixes`, Vary changes) is record-only, or goes to the
>   gem or app when the fix there is small and the maintainers are active.

### Orb CPU measured on 2026-11-04

> * Check usage with `amp orb system-metrics <thread>` (cores, memory, CPU over time) before choosing a size for a
>   similar task. Measured on 2026-11-04: all 17 active orbs were a1.large; the coordinator, the watcher, C15 and G2
>   averaged 3–10 % CPU, and the busiest workers 50–65 %.

### Bets table as of 2026-11-25

DECISIONS keeps each bet's goal and doc; progress and results live in those docs. The closing paragraph moved
because its reasons are history: E2 and Z13 were chosen on 2026-11-03 and Z13 is done. The C8 slot has no dated
replacement: C8 is done, C8-1 is built and unopened, and since 2026-11-25 the bets set the orb allocation.

> | Bet | Goal | Doc |
> | --- | --- | --- |
> | Z10 | per-ISEQ ZJIT stats on the apps; leads 7 and 3 are being built | [zjit-iseq-leads](upstream/zjit-iseq-leads.md) |
> | F1 | frontier census: 20 apps on Rails main × master, ZJIT fallbacks and exits | [measurement-matrix](upstream/measurement-matrix.md) |
> | F2 | our merged Rails PRs under ZJIT | [measurement-matrix](upstream/measurement-matrix.md) |
> | C8 | census 8 (CPU and allocations) on 4.0.9 and pinned master | [census](upstream/census.md) |
> | Z5–Z8, Z12 | objtostring, compile speed, cfunc paths, stats correctness, warmup | [zjit-shortlist](upstream/zjit-shortlist.md) |
> | Z2, Z11 | ZJIT differential on Rails and app suites: done, no divergence | [zjit-app-differential](upstream/zjit-app-differential.md) |
> | V1, A1, S1 | Action View, Active Record and JSON serialization CPU | [actionview-cpu](upstream/actionview-cpu.md) · [activerecord-cpu](upstream/activerecord-cpu.md) · [serialization-cpu](upstream/serialization-cpu.md) |
> | G1, I18N | gem census; i18n deep dive; gem request census and round 2 (rack K1 #2550, nokogiri N1 #3759 open; i18n, tzinfo, importmap-rails, mail left alone) | [gem-census](upstream/gem-census.md) · [i18n-performance](upstream/i18n-performance.md) · [gem-request-census](upstream/gem-request-census.md) · [round 2](upstream/gem-request-census-2.md) |
> | R6 | relation delegators `...`, `default_scope` owner checks | [rails-r6-leads](upstream/rails-r6-leads.md) |
> | E2 | make the 13 census configurations that fail on Ruby master install, via gem fixes upstream; doubles the corpus every ZJIT pass sees. 11 of 13 install; Chatwoot and Flow are blocked | [gems-on-master](upstream/gems-on-master.md) |
> | Z13 | where ZJIT spends more Ir than YJIT on railsbench, lobsters and shipit, classified into buckets that become leads (2026-11-15). Done 11-15 on master `3be2b028a7`, JIT-flat and fixed heap: ZJIT +3.4% / +6.4% / +16.3%; polymorphic fallbacks 41%, codegen 33%, blocks 25%, ivars 9%, protected and `send` 9% of the gap, almost all known and owned upstream. New: OO1 (`OrderedOptions#_get` public, held: wins per call on 4.0.9, whole requests don't move), data for Shopify/ruby#1109 (draft, not posted); `&:sym` block args are about 1% of the gap and with ZS1 | [zjit-yjit-gap](upstream/zjit-yjit-gap.md) |
> | Z1-2 | ZJIT vs YJIT on real apps on master and on k0kubun's `zjit-headline2` (Shopify/ruby#1030), which gaps are unowned, then the Z11 differential on headline2 before it lands (2026-11-25). Done 11-25: headline2 `f2c3f457ff` runs 5.9–10.6% fewer instructions than YJIT on railsbench, lobsters, shipit, Campfire, Writebook and Blog, master 3.3–14.3% more; every remaining ZJIT-only cost is owned (k0kubun's later branches, #19949, #19617, our #19982), so no issue drafts; no divergence in three app suites, btest, test-all and the yield and ZS1 probes | [zjit-gap-census-2](upstream/zjit-gap-census-2.md) |
> | P-MAP | full-request stack map under YJIT by layer (Puma/Rack to drivers, GC, YJIT), leads outside Rails (2026-11-05). Done 11-14: flat below the layers; allow_browser (AB1) built, MK1 held below noise | [p-map](upstream/p-map.md) |
> | QB1 | how much of AR query building repeats per request and could be cached (2026-11-14). Done 11-14: 97% of it is built per query and repeats with only binds changing, but it is flat over stages and entry points; the exact levers are in association scopes: #59212 (open, not ours, up to 2.0%) and MB1 (blank merge into a relation without conditions, 0.4–1.4% of association-heavy pages; reviewed: opus approves, claude-code nits, after one round of changes) | [query-building](upstream/query-building.md) |
> | P-TEST | per-test framework overhead in real Rails test suites: fixtures, transactions, setup, reporters (2026-11-05) | test-overhead (planned) |
> | P-DRV | database driver result path: sqlite3, pg, trilogy, per row and per query (2026-11-05) | driver-cpu (planned) |
> | DEF8 | what every new app pays per request: each default piece of `rails new` from main switched off in turn and priced (default, `--api`, Tailwind; 20-field scaffold), ranked by cost × reach (2026-11-14). Done 11-14: importmap tags 18%, allow_browser 13% (AB1), info logging 10%, `:app` stylesheet 9% of a bare page under YJIT; IM1 (importmap-rails) and QL1 (Rails) built | [rails8-defaults](upstream/rails8-defaults.md) |
> | VM1 | what P-MAP's VM share (18–32%) and allocation/GC share (17–23%) under YJIT are made of on real request paths, mapped to Rails lines and ranked by share × reach (2026-11-15). Done 11-15: interpretation is 0.2–0.6% of instructions; the bucket is C calling back into Ruby, generic sends and call helpers, from mechanisms inherent to Rails' design or parked YJIT limits; allocation has no lever beyond the censuses. Built: TE2 (`tag_options` `!=` → `==`); TE1 (tag escapes without `super`) held, since it drops real prepends of `unwrapped_html_escape` (angular_xss, Discourse) | [vm-share](upstream/vm-share.md) |
> | FLK1 | make rails/rails CI less flaky: rank intermittent failures on main and unrelated PR jobs over Sep 17–Nov 15 (2,430 builds), find causes, fix the exact ones in one bundled PR, one commit per cause (2026-11-15). Top causes by volume are outside Rails (Buildkite agent interruptions; a Ruby Ractor `require` bug, mitigated on main). Built: Server-Timing sleep tolerances, Ractor proxy pin leak; the server restart test stays open (cause on CI not established) | [rails-ci-flakiness](upstream/rails-ci-flakiness.md) |
>
> Chosen 2026-11-03 for reach. E2 unblocks ZJIT measurement on Mastodon, Discourse, Chatwoot, Lobsters and Loomio, and
> the gem fixes are needed for 4.1 anyway. Z13 measures the gap to YJIT directly instead of inferring it from fallback
> counts. One orb slot stays reserved for Rails candidates from C8's CPU census; the Rails queue is otherwise empty.

## History

> ## Bet: what our merged Rails PRs add up to (2026-11-04)
>
> Main against main with 39 of our merged perf PRs reverted (five conflict and stay in both trees), Ruby 4.0.9, fixed
> heap ([merged-sum](upstream/merged-sum.md)): census allocations −3.8% per workload in five apps (A/A ≤ 0.04%, 52/52
> workloads move), ruby-bench −1.2% to −9.7% objects per iteration, and −2.0% to −7.0% instructions on erubi-rails,
> railsbench and shipit (A/A ≤ 0.54%). Lobsters' ruby-bench instructions and every app-level YJIT row fail their A/A
> and are not claimed. Ten PR groups carry 85% of the allocations; the WhereClause and database-statement groups lead.
> For our own picture; nothing posted.

> ## Learnings from 2026-11-03
>
> The incidents behind the rules above, kept so the rules keep their reasons:
>
> * Two Shopify/ruby#1039 comments and one ruby/ruby#18960 comment were deleted as unsolicited data → comment rules.
> * A draft offering to close ours if a maintainer would rather land the rows himself read as credit-seeking (not
>   posted) → collaborative, not credit-seeking.
> * fatkodima on [rails#59577](https://github.com/rails/rails/pull/59577#issuecomment-6606427493) asked for
>   provenance and impact and called the code more complex for questionable benefit; #59577 and #59557 went too far
>   → CPU and provenance in the body, readability gate.
> * cbor-ruby#43 duplicated nobu's open #31; tiktoken_ruby#130 and ruby/ruby#16909 were missed → search before
>   building.
> * tekknolagi called our dense #1058 reply unreadable LLM shorthand and asked not to be made a proxy for it; Thomas
>   edits that reply himself → plain language upstream, with an outsider-readability pass.
> * A bare `#19583` in Shopify/ruby linked the wrong repo twice → owner/repo on every reference.
> * The 64 MiB ZJIT default filled in most app passes → memory flags and the zero-OOM check.
> * #19665 was relayed as a correctness fix and is not; Discourse and Mastodon were named as old-Bundler examples and
>   lock 4.0.23 → orb reports are claims.
> * S1, C7-1, I2 and C1 each needed three to five review rounds for the same classes of difference → exactness
>   checklist.
> * Several limits were set and changed within one day → one cap per repo, named exceptions, recorded here.
