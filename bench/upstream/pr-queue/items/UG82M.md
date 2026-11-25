---
id: UG82M
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, Action Mailer and Active Job"
reviewer: "byroot (#59820)"
branch: thomasklemm/upgrade-guide-mailer-active-job-railtie
head: "de4d27b257337464438695d3d6600af13bdf0482"
base: main
built_on: "cf0325a832"
depends_on: []
stacked_on:
alternative_of:
impact: "Since #59820 (merged 2026-11-16) require 'action_mailer/railtie' no longer loads active_job/railtie: apps with an explicit railtie list that omits Active Job raise NoMethodError on config.active_job at boot, and deliver_later enqueues to the default Async adapter instead of the configured one (8.1: configured TestAdapter). turbo-rails then skips Turbo::Broadcastable::TestHelper (view_component's sandbox no longer loads). CHANGELOG covers only standalone use; the upgrade guide says nothing. Census 11 (docs/upstream/rails-main-census-11.md)."
rank: 12
risky: false
state: built
pr:
note: "2026-11-25 (census 11): built on main cf0325a832, guide-only (16 lines, before the 6.1 marshalling section). Ownership: no rails/rails issue or PR; #59820 has no cross-references and no review comments; none of the 66 open PRs created since 11-16 touches action_mailer/railtie or the guide section; not in our queue. Repro .amp/in/orb-backup/c11/repro/am2_mailer_without_job_railtie.rb (run through each tree's bundle): 8.1 config.active_job ok, deliver_later TestAdapter 1 enqueued; main NoMethodError, ActiveJob undefined after boot, deliver_later Async. Reach looks narrow: 9 of 10 sampled config/application.rb with the mailer railtie also require active_job/railtie (GSA/i14y comments it out but has no mailer railtie). Alternative to a guide note: restore the require in the railtie (byroot made it deliberately). Needs: claude-code pass, likely-reviewer check, Thomas's OK; waits for a slot like the other UG82 notes."
passes:
  - {reviewer: thermos-sol, head: "de4d27b257337464438695d3d6600af13bdf0482", orb: "T-01a212b7-add7-770d-90b0-f74112d7d64c", date: 2026-11-25, verdict: changes, open: "Both Thermos rubrics applied directly, no delegation. Guide change is small, correctly placed and useful for the narrow implicit-railtie case; the removal in the introducing PR was deliberate. No source-code or structural defect found. Must fix body/impact accuracy: config.active_job.queue_adapter raises at boot when the railtie is absent; it is not an existing configured adapter silently ignored. The unconfigured test default changes TestAdapter to AsyncAdapter; direct job adapter configuration still works, and production defaults are Async on both trees. Delete the body's configured-adapter clause and its final outside-Rails-only CHANGELOG claim (the entry generally announces decoupling, but omits railtie-list instructions); cut the meta opening and name config.active_job.queue_adapter. Eighteen stable/head fresh-process scenarios pass, reproducing config boot failure, Test-to-Async fallback, Turbo helper omission and explicit-require/rails-all controls; two production controls agree. Action Mailer 88/275, Railties frameworks 28/52, configuration adapter cases 7/14, Guides 18/39/2 skips, all 0 failures/errors; Rails-configured mdl passes. Released Turbo 2.0.23 and ViewComponent 4.25.0 line permalinks checked, but no full ViewComponent sandbox run or new app-prevalence sample. Thomas author/committer, no trailers. Sentence audit, evidence, commands and smallest fixes: docs/upstream/rails-main-census-11.md#ug82m."}
---

# Note in the upgrade guide that Action Mailer no longer loads Active Job

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that the guide doesn't mention yet. Since #59820, `require "action_mailer/railtie"` no longer loads the Active Job railtie. An app that lists its frameworks and requires the Action Mailer railtie without Active Job's then raises `NoMethodError` when it sets `config.active_job`, and `deliver_later` no longer uses its configured queue adapter. The CHANGELOG entry covers Action Mailer used outside Rails only.
