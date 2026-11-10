---
id: UG82H
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, Herb"
reviewer: "marcoroth (Herb), #58721"
branch: thomasklemm/upgrade-guide-herb-tag-branches
head: "3be82b17cb2b2928a20ab91e4bb3c99877706ecb"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
impact: "templates that open an element in one branch or loop iteration and close it in another no longer compile through Herb (lobsters, Discourse, Redmine); the guide doesn't say so"
rank: 6
risky: false
state: built
note: "split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from 3428a0ee53 with its context resolved by hand (same added lines, inserted after the Herb section, before the :controller/:action section). Planned to open as a draft first, with UG82P, after a Claude Code pass."
passes: []
---

# Note in the upgrade guide that HTML elements must close in the branch that opens them

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. With Herb (#58721), tags pair within each branch of Ruby control flow, so a template that opens an element in one branch or loop iteration and closes it in another no longer compiles, even when the HTML it renders is balanced. Affected on main are [lobsters' user tree](https://github.com/lobsters/lobsters/blob/36f631c083baf1aa1bf0cf7ed22a8e9fe277c41c/app/views/users/tree.html.erb#L22-L38), [Discourse's topic page](https://github.com/discourse/discourse/blob/b2d1791995a03498e183d2929452b762af99b305/app/views/topics/show.html.erb#L64-L67) and [Redmine's bulk edit form](https://github.com/redmine/redmine/blob/4dba4a79238191d617c4809b25e3818f966f5406/app/views/issues/bulk_edit.html.erb#L202-L204).

---

<sub>Found by running Rails apps on Rails main with the 8.2 defaults ([record](https://github.com/thomasklemm/lowrail/blob/c01dbe6f2a2b061f241d47cdab39733e75a20311/docs/upstream/herb-tags-across-branches.md), part of my research project Lowrail).</sub>
