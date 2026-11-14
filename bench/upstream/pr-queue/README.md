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
```

Commit the item files after `open`, `ready` and `sync`. `status` keeps a blobless clone of each upstream repo under
`.lowrail/pr-queue/` (fetched every run) to compare the fork branch with `head` and run `git merge-tree` against
the current base. MERGE is `clean`, `CHANGELOG-only` (only CHANGELOG files conflict) or `CONFLICT`; `(gh)` marks
GitHub's view when the fork branch couldn't be fetched. BASE-MOVED counts the base commits since `built_on` (or the
merge base) that touch the PR's files, listed below the table: an early warning that upstream moved under it.

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
depends_on: []                # IDs that must be merged first
stacked_on:                   # ID of our PR this one is stacked on (that one must be opened)
alternative_of:               # ID this competes with; only one of them opens
impact: one line, the effect a maintainer cares about
rank: 2                       # 1 opens first
risky: false                  # true: Astra is required (DECISIONS, review rounds)
state: draft
pr: 59667
note:                         # one line: why it is held, superseded, ...
passes:                       # oldest first
  - {reviewer: skeptic, head: "ab0a99e41a", date: 2026-11-05, verdict: approve, open: wording nit applied}
---

# Keep token_tag and method_tag where FormTagHelper can reach them

The body, verbatim, as it is posted.
```

`reviewer` in a pass: `claude-code` (the separate final review orb), `skeptic` (the orb's skeptical reviewer
subagent, kept as a record), `sol`, `astra`, `thermos`, and for now `opus` and `fable`, which stand in for Sol or
Astra when their `orb` (the orb's thread ID) differs from the claude-code pass's `orb` on that head and from the other
stand-in's ([DECISIONS](../../../docs/DECISIONS.md#opus-and-fable-stand-in-for-sol-and-astra-thomas-2026-11-14-temporary-pending-thomas)).
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
  must-fix. Required: claude-code and Sol (or a stand-in) always, Astra (or a stand-in) when `risky`, thermos when the diff against the base has
  more than 200 changed lines. `open` refuses otherwise.
* **draft**, **ready**, **merged**, **closed:** the PR's state on GitHub; `sync` keeps them current.
* **held:** not to open now; `note` says why and what unblocks it. **superseded:** replaced by another item or PR.

The author moves an item to in-review and reviewed by editing `state`; `status` flags an item whose state
claims more than its passes show, and an item whose fork branch moved off `head`.
