---
id: ATF1
repo: rails/rails
kind: fix
area: "Action Text: Content rendering, bulk attachable lookup"
reviewer: "flavorjones (#58173)"
branch: thomasklemm/action-text-attachment-from-node-fallback
head: "b3a7a6bb19f8f8d20c38248c1d77dca98956761e"
base: main
built_on: "088fc0cf61"
introduced_by: 58173
depends_on: []
stacked_on:
alternative_of:
impact: "Since #58173 (merged 2026-11-25, unreleased) Content#attachment_for_node passes Attachment.from_node an attachable it already resolved (Attachable.from_node, never nil) for every node, while AttachmentGallery passes only the bulk-located record. ActionText::Attachment.from_node(node, attachable = nil) is public (not :nodoc:) and overriding it is how Campfire (basecamp/once-campfire, about 8 forks in code search) turns OpenGraph embed nodes into its own attachable and accepts @mentions with expired SGIDs; on main its override no longer applies: 6 of 19 ContentFiltersTest tests fail (9 failures in the profiled two-run suite), bisected first-parent to 818edfd76a. Fix restores 634 runs, 0 failures. Plain Rails renders the same either way, so no speed or behaviour change for apps without an override. One line plus one test."
evidence: [bench/upstream/rails_main_hotlines/atf1]
rank: 5
risky: false
state: in-review
note: "2026-11-27 (Rails 8.2 pre-beta round): found in Campfire's suite on main 088fc0cf61 (its own pin e3d5c569d2 passes); bisect.log in evidence. Classification: an unreleased behaviour change to a public extension point, and Rails' own two call sites disagree (gallery already passes only the located record), so the fix is in Rails rather than a compatibility shim; reviewers asked to judge that. Actiontext suite: 385 runs, one error (JavascriptPackageTest needs yarn, environment). Test fails without the fix. Only #58173 cross-reference is lylo/pagecord#1491 (adopting it). No open PR or issue names attachment_for_node, attachables_by_sgid or #58173."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #58173","open PRs naming attachment_for_node that change actiontext/lib/action_text/content.rb"], hits: []}
passes: []
---

# Let Attachment.from_node pick attachables the bulk lookup didn't locate

Since #58173, `ActionText::Content` resolves every attachment's attachable itself before calling `ActionText::Attachment.from_node`, falling back to `Attachable.from_node` for nodes the bulk lookup didn't find. So `Attachment.from_node` never receives a `nil` attachable any more, and an application that overrides it to supply its own attachables stops applying. Campfire [does this](https://github.com/basecamp/once-campfire/blob/945c22f141795e910e2822d386a94c5686bf7bdc/lib/rails_ext/action_text_attachables.rb#L5) for OpenGraph embeds and for mentions with expired SGIDs, and its tests for unfurled links fail on main.

This passes only the record the bulk lookup located, as `AttachmentGallery` already does, and leaves the fallback to `Attachment.from_node` as before #58173. Rendering without an override is unchanged, and attachables are still located in one query per model.
