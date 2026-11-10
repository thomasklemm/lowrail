---
id: UG82H
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, Herb"
reviewer: "marcoroth (Herb), #58721"
branch: thomasklemm/upgrade-guide-herb-tag-branches
head: "e2bd1d953fb51d6a0b570553738d1f2b0ba63c40"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
impact: "templates that open an element in one branch or loop iteration and close it in another no longer compile through Herb (lobsters, Discourse, Redmine); the guide doesn't say so"
rank: 6
risky: false
state: built
note: "2026-11-10: Claude Code pass amended the error block to the one-line summary that SyntaxErrorInTemplate and herb:check show; head 3be82b17cb -> e2bd1d953f (force-with-lease). Earlier: split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from 3428a0ee53 with its context resolved by hand (same added lines, inserted after the Herb section, before the :controller/:action section). Planned to open as a draft first, with UG82P, after a Claude Code pass."
passes:
  - {reviewer: claude-code, head: "e2bd1d953fb51d6a0b570553738d1f2b0ba63c40", date: 2026-11-10, verdict: approve, open: "Changes found on 3be82b17cb, fixed in this head by the reviewer; approve on this head. Snippet, loop-iteration failure and recursive-partial fix verified on main 224f5b1563 with herb 0.11.0 (Erubi renders all). One fix, applied: the quoted two ✘ lines are Herb::Engine::ParseError#detailed_message, which only prints for an uncaught cause; SyntaxErrorInTemplate, test output, the error page, logs and herb:check all show the one-line summary, so the block now quotes that (\"caused by:\"). Amended to e2bd1d953f, force-with-lease on 3be82b17cb, mdl clean, no trailers. Body and links (lobsters, Discourse, Redmine) accurate."}
---

# Note in the upgrade guide that HTML elements must close in the branch that opens them

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. With Herb (#58721), tags pair within each branch of Ruby control flow, so a template that opens an element in one branch or loop iteration and closes it in another no longer compiles, even when the HTML it renders is balanced. Affected on main are [lobsters' user tree](https://github.com/lobsters/lobsters/blob/36f631c083baf1aa1bf0cf7ed22a8e9fe277c41c/app/views/users/tree.html.erb#L22-L38), [Discourse's topic page](https://github.com/discourse/discourse/blob/b2d1791995a03498e183d2929452b762af99b305/app/views/topics/show.html.erb#L64-L67) and [Redmine's bulk edit form](https://github.com/redmine/redmine/blob/4dba4a79238191d617c4809b25e3818f966f5406/app/views/issues/bulk_edit.html.erb#L202-L204).

---

<sub>Found by running Rails apps on Rails main with the 8.2 defaults ([record](https://github.com/thomasklemm/lowrail/blob/c01dbe6f2a2b061f241d47cdab39733e75a20311/docs/upstream/herb-tags-across-branches.md), part of my research project Lowrail).</sub>
