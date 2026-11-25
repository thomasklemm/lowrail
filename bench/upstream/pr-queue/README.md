# Upstream PR queue

One file per prepared PR in `items/<ID>.md`: the metadata, the title and the body exactly as it will be posted.
`script/pr-queue` reads them, checks the gates and opens, readies and syncs PRs. Rules:
[DECISIONS](../../../docs/DECISIONS.md#submission-queue-2026-11-03).

```
script/pr-queue status          every item by state and rank: fork head, passes on it, diff size, mergeability, base drift, next step
script/pr-queue next            the highest-ranked reviewed item whose repo has room
script/pr-queue open ID --draft opens it (rails/rails only as draft), records pr and state
script/pr-queue ready ID        marks a draft ready for review; rails/rails: at most 15 non-draft
script/pr-queue sync            pulls draft/ready/merged/closed from GitHub
script/pr-queue rebase ID       rebuilds a branch whose only conflicts are CHANGELOG files on the current base
script/pr-queue rebase ID --push  ... and force-pushes it with a lease on the old head, updating head, built_on, note
```

Commit the item files after `open`, `ready`, `sync` and `rebase --push`, with `script/commit`. `status` keeps a blobless clone of each upstream repo under
`.lowrail/pr-queue/` (fetched every run) to compare the fork branch with `head` and run `git merge-tree` against
the current base. MERGE is `clean`, `CHANGELOG-only` (only CHANGELOG files conflict) or `CONFLICT`; `(gh)` marks
GitHub's view when the fork branch couldn't be fetched. BASE-MOVED counts the base commits since `built_on` (or the
merge base) that touch the PR's files, listed below the table: an early warning that upstream moved under it.
An item whose state disagrees with our open PRs on GitHub (a draft or ready item that merged, closed or changed
draft state; a merged or closed one that is open) shows `sync: …` in NEXT and under "Out of date with GitHub or
the ledger", as does a merged item missing from the Merged section of
[contributions.md](../../../docs/upstream/contributions.md), which is kept by hand. Run `sync` and add the ledger
entry; `status` itself writes nothing.

## Ownership check

`script/ownership ID` lists who else may already own the item's problem: open PRs that cross-reference its
`introduced_by` PR (or name its commit), open PRs that name a method the item's branch changes and change the same
file (the def or body of a Ruby `def` or Rust `fn` in non-test files; without a branch, the methods `introduced_by`
changes), and each `tracker` issue or PR with the open PRs and issues that reference it. It
writes the date, what it checked and the hits into the item's `ownership:` line. Read the hits before opening.
`open` refuses, and `status` shows, a reviewed item whose ownership check is missing or older than 3 days.

## Rebasing a CHANGELOG-only conflict

`script/pr-queue rebase ID` does what was done by hand for PR59574 and INR436/437/442 on 2026-11-17. It refuses
unless the fork branch is at `head` and `git merge-tree` against the current base conflicts only in CHANGELOG
files. In the bare cache with a temporary index (no checkout touched), it replays each commit of the branch onto
the base: the commit's diff outside CHANGELOG files applied unchanged, and the entry it added to a CHANGELOG put on
top of the base's file, under the same heading it was under (`## [Unreleased]`) or at the top (Rails). The message
stays byte for byte, the author and author date stay, Thomas commits, nothing adds a trailer. It refuses when a
code diff doesn't apply, the branch has a merge, or a CHANGELOG change isn't one entry inserted on top; rebase
those by hand.

It leaves the result at `refs/rebase/ID` in `.lowrail/pr-queue/<repo>.git`, prints the range-diff against the old
head and these checks per commit: code diff identical (added and removed lines), same CHANGELOG entry and nothing
removed, message byte-identical, author and author date kept, committer Thomas, no trailers. It pushes only with
`--push`, and never when a check fails. Pushing an open PR still needs Thomas's OK
([DECISIONS](../../../docs/DECISIONS.md#working-mode)), so run it without `--push` first, show him the range-diff,
and run the repo's tests on `refs/rebase/ID` if the base moved code the PR touches (BASE-MOVED). `--push` rebuilds
(same trees, a new committer date), force-pushes with `--force-with-lease` on the old head, prepends a dated
entry to `note` and sets `head` and `built_on`; the new head has no passes yet.

## Commits without trailers

`script/commit -F MSGFILE` (or `-m MESSAGE`, `--amend` to replace HEAD and keep its author date) commits the staged
index as Thomas Klemm for author and committer through `/usr/bin/git commit-tree`, so Amp adds no Amp-Thread-ID
trailer. It works in Lowrail and in upstream checkouts (run it from there), and checks the new commit before HEAD
moves: author and committer, the message byte for byte, empty `%(trailers:only)`, and in Lowrail no `owner/repo#N`
or issue or PR URL in the message.

`script/install-fork-hooks DIR` copies `script/hooks/fork-pre-push` into an upstream checkout as its pre-push hook
(it refuses to replace another hook). The hook checks each pushed commit that no remote-tracking ref or the pushed-to
branch already has: no `Amp-Thread-ID:` or Amp `Co-authored-by:` trailer, author and committer Thomas Klemm
`<github@tklemm.eu>`. Other contributors' commits that are already upstream pass.

## Body numbers

Every number in a body (objects, Callgrind instructions, benchmark-ips) comes from one
[`script/upstream-bench`](../../../script/upstream-bench) run of the item's base against its head, committed under
`bench/upstream/<topic>/body/<ID>/` next to its benchmark script; `impact` and the body cite that directory. It
measures base twice in every cell and prints "within noise" for a change inside that A/A, which the body then
doesn't claim. A YJIT or ZJIT cell also records compile and invalidation counters around every measured window
and says "not JIT-flat, no claim" when any moved, so a body claims JIT rows only from runs that have the gate.
Usage, method and limits: [body-numbers](../../../docs/upstream/body-numbers.md). Examples:
`form_helper_stack/body/fb1` and `body/am1`. A reviewer checks a body number by rerunning the run's `commands.sh`,
or the whole run into a new directory.

`evidence:` lists the repo paths that hold the raw data (stats, dumps, captures, run directories) the body's
numbers come from. `status` reports a problem for an item in state reviewed, draft, ready, merged or closed whose body
has measured numbers (a unit such as objects, Ir, ns or i/s, a percentage, a factor like 1.3x, or a count with
thousands separators) and no `evidence:` path that exists, and for every listed path that doesn't exist.

## Item file

```markdown
---
id: DC1                       # = file name
repo: rails/rails
fork: thomasklemm/rails       # optional, default thomasklemm/<repo name>
kind: fix                     # fix | perf | docs | restore
area: Action View, form helpers
reviewer: seanpdoyle          # likely reviewer: usually the author of the change it fixes or touches
branch: thomasklemm/form-tag-helper-token-tag
head: "ab0a99e41a"            # the commit the passes reviewed; quoted, 7–40 hex digits
base: main                    # the branch the PR targets
built_on: "bdb3d96012"        # upstream commit it was built and tested on
introduced_by: 58211          # optional: the upstream PR number or quoted commit SHA that introduced the problem
tracker: [Shopify/ruby#1014]  # optional: upstream issues or PRs that track the problem (owner/repo#N)
ownership: {date: 2026-11-25, checked: [...], hits: [...]}  # written by script/ownership
depends_on: []                # IDs that must be merged first
stacked_on:                   # ID of our PR this one is stacked on (that one must be opened)
alternative_of:               # ID this competes with; only one of them opens
impact: one line, the effect a maintainer cares about
evidence: [bench/upstream/form_helper_stack/body/fb1]  # repo paths with the raw data behind the body's numbers
rank: 2                       # 1 opens first
risky: false                  # true: Astra is required (DECISIONS, review rounds)
guard_review: true            # optional: reviews our own safety guards; thermos-opus/-fable stand in for Sol and Astra
state: draft
pr: 59667
note:                         # one line: why it is held, superseded, ...
passes:                       # oldest first
  - {reviewer: skeptic, head: "ab0a99e41a", date: 2026-11-05, verdict: approve, open: wording nit applied}
---

# Keep token_tag and method_tag where FormTagHelper can reach them

The body, verbatim, as it is posted.

## For Thomas

Optional, last: what Thomas needs to retell the change. Everything from this heading on is not posted.
```

`reviewer` in a pass: `claude-code` (the separate final review orb), `skeptic` (the orb's skeptical reviewer
subagent, kept as a record), `sol`, `astra`, `thermos`, `thermos-sol`, `thermos-opus` and `thermos-fable` (a
thermos review on that model, which is also the detailed review), and for now `opus` and `fable`, which stand in for Sol or
Astra when their `orb` (the orb's thread ID) differs from the claude-code pass's `orb` on that head and from the other
stand-in's ([DECISIONS](../../../docs/DECISIONS.md#opus-and-fable-stand-in-for-sol-and-astra-thomas-2026-11-14-temporary-pending-thomas)).
On an item with `guard_review: true`, `thermos-opus` and `thermos-fable` stand in the same way, since Sol's and
Astra's cyber-safety checks stop reviews of our own safety guards
([DECISIONS](../../../docs/DECISIONS.md#working-mode), "Reviews of our own safety guards go to Anthropic models").
`verdict`:
`approve`, `nits` (no must-fix, optional points listed in `open`) or `changes` (must-fix). Every pass checks each
added code comment, tests and benchmarks included, against [DECISIONS](../../../docs/DECISIONS.md#no-unnecessary-code-comments-in-upstream-prs-thomas-2026-11-10);
a superfluous comment means `changes`. Every factual claim in the body or a comment is backed by a command the
reviewer ran or a link it opened, and a pass on a behaviour change includes a differential probe of old against new
across input types (subclasses and duck-typed objects too) and checks the documented return contract
([DECISIONS](../../../docs/DECISIONS.md#claims-are-checked-behaviour-changes-are-probed-thomas-2026-11-14)). Record a pass on the
head it reviewed. When a fix changes the branch, update `head` to the new commit; the old passes stay in the list
and stop counting. A body-only change keeps the head, so it needs no new code pass, but its text was reviewed by
whichever pass is listed.

A thermos pass can be waived on one head: `waived: [{reviewer: thermos, head: "…", by: coordinator, reason: …}]`.
It counts like an approving pass on that head only; claude-code, Sol and Astra can't be waived.

Items that are already open and ready may have no body.

Migrated passes whose head the old ledger didn't record have `head: unrecorded`; they never count.

## States

```
built -> in-review -> reviewed -> draft -> ready -> merged
                                                  -> closed
any state -> held | superseded
```

* **built:** branch pushed, body drafted, no pass yet on this head.
* **in-review:** passes are being run on this head.
* **reviewed:** every required pass approves on the current `head` (latest pass per reviewer counts), no
  must-fix. Required: one detailed claude-code pass always ([DECISIONS 2026-11-17](../../../docs/DECISIONS.md#one-detailed-review-instead-of-two-thomas-2026-11-17)), Astra (or a stand-in) when `risky`, thermos when the diff against the base has
  more than 200 changed lines. `open` refuses otherwise.
* **draft**, **ready**, **merged**, **closed:** the PR's state on GitHub; `sync` keeps them current.
* **held:** not to open now; `note` says why and what unblocks it. **superseded:** replaced by another item or PR.

The author moves an item to in-review and reviewed by editing `state`; `status` flags an item whose state
claims more than its passes show, and an item whose fork branch moved off `head`.
