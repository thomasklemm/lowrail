# Decision register

What we pursue, what is parked and what is rejected, with the reason. Numbers live in the linked docs; this page
records the rule and why. Rules are grouped by topic, with a date or owner only where it decides something. The
parked runtime-lowering prototype's decisions are in [decisions-prototype.md](decisions-prototype.md). Earlier
wording of these rules is in git history (before 2026-11-03 19:00 UTC).

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
  reviews) comes after that, not instead of it. New ZJIT PRs pause until the open ones are reviewed with him; open
  PRs and issues he can't stand behind are closed with one neutral line.
* **One concern per PR.** A ruby/ruby PR touches the VM, YJIT or ZJIT, never two of them (tekknolagi on
  [ruby#19661](https://github.com/ruby/ruby/pull/19661#issuecomment-6607345199)). Dependent changes go into one PR
  as separate commits; open a follow-up only after its base has merged. Never stack on an open PR.
* **Cross-link interlocking changes in the body** (Thomas): one sentence with owner/repo (e.g. rails/rails#59557 ↔
  ruby/ruby#19662), updated when the other side moves, never as an extra comment. Every cross-repo reference
  carries owner/repo; link branches instead of naming them.
* **rails/rails body,** about 150 words, no headings, no template checklist. Paragraph 1: what is wasted and where
  it runs. Paragraph 2: what changes and the one boundary a reviewer would ask about. Then one per-call
  before/after table: objects, and CPU in ns and Ir for interpreter and YJIT on the Ruby pin, with its A/A. One
  sentence of ruby-bench placement ("within noise" is fine) and app breadth; one sentence on how the site was
  found, linking the census doc in the public Lowrail repo (Lowrail named as my research project; Roundhouse not
  mentioned). No per-app tables, review history or receipts.
* **ruby/ruby body:** about 100 words plus one micro table, with the ruby-bench headline effect or the
  correctness repro.
* **No code comments** unless the code would be misread without them; why a change is equivalent goes in the body.

## Submission queue (2026-11-03)

Every finished candidate (review gates passed, body drafted) goes into the **Queue** section of
[upstream/contributions.md](upstream/contributions.md), ranked by effect and breadth, and opens only when its repo
has room. Open the strongest first. A candidate made moot upstream leaves the queue with a note.

* **rails/rails:** at most 20 of our PRs open (Thomas). Keep each PR small.
* **ruby/ruby:** at most 20 of our PRs open, counting all of them (VM, ZJIT, YJIT, backports) (Thomas; 15 earlier on
  2026-11-03, back to 20 the same evening). At 20 or more, open nothing new until merges or closes bring the count
  below 20, and let the maintainers merge. New PRs
  are VM or ZJIT, at most one new PR per day. Slots above the cap are decided by the agent (Thomas, 2026-11-03), recorded here. Current ones: the 4.1 GC
  pool-budget regression fix (Thomas approved); Shopify/ruby#1100's fix (ruby/ruby#19682), which k0kubun
  cleared on that issue; the top free lead from Z13's ranking (this slot was lead 7's, which turned out to be taken), and lead 3, class-level methods on
  many model classes (Shopify/ruby#1099 item 2), from the
  [lead queue](upstream/zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03). The green-lit Shopify/ruby#1064,
  #1065 and #1091 open as room appears under the cap; `Kernel#dup` (#1058) after them.
* **gems:** no per-gem limit (Thomas); open whatever is good.
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
| G1, I18N | gem census; i18n deep dive; gem request census | [gem-census](upstream/gem-census.md) · [i18n-performance](upstream/i18n-performance.md) · [gem-request-census](upstream/gem-request-census.md) |
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
