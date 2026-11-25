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
impact: "Since #59820 (merged 2026-11-16, deliberate decoupling) require 'action_mailer/railtie' no longer loads active_job/railtie. An app that requires the mailer railtie without the Job railtie and sets config.active_job.queue_adapter (or any setting under config.active_job) raises NoMethodError at boot. Without such a setting it boots, and in tests deliver_later falls back from TestAdapter to AsyncAdapter. turbo-rails then omits Turbo::Broadcastable::TestHelper (if defined?(ActiveJob) at test-case load). The CHANGELOG announces the decoupling but its migration note covers standalone Action Mailer only, not explicit railtie lists; the upgrade guide has no note. Census 11 (docs/upstream/rails-main-census-11.md#ug82m)."
rank: 12
risky: false
state: built
pr:
note: "2026-11-25: body and impact corrected per the thermos-sol changes pass on de4d27b257 (text only, head unchanged): configured-adapter clause and CHANGELOG sentence removed, config.active_job.queue_adapter named, meta opening cut; boot failure and the unconfigured test default kept apart. Guide unchanged (optional wording left). Earlier: 2026-11-25 (census 11): built on main cf0325a832, guide-only (16 lines, before the 6.1 marshalling section). Ownership: no rails/rails issue or PR; #59820 has no cross-references and no review comments; none of the 66 open PRs created since 11-16 touches action_mailer/railtie or the guide section; not in our queue. Repro .amp/in/orb-backup/c11/repro/am2_mailer_without_job_railtie.rb (run through each tree's bundle): 8.1 config.active_job ok, deliver_later TestAdapter 1 enqueued; main NoMethodError, ActiveJob undefined after boot, deliver_later Async. Reach looks narrow: 9 of 10 sampled config/application.rb with the mailer railtie also require active_job/railtie (GSA/i14y comments it out but has no mailer railtie). Alternative to a guide note: restore the require in the railtie (byroot made it deliberately). Needs: claude-code pass, likely-reviewer check, Thomas's OK; waits for a slot like the other UG82 notes."
passes:
  - {reviewer: thermos-sol, head: "de4d27b257337464438695d3d6600af13bdf0482", orb: "T-01a212b7-add7-770d-90b0-f74112d7d64c", date: 2026-11-25, verdict: changes, open: "Both Thermos rubrics applied directly, no delegation. Guide change is small, correctly placed and useful for the narrow implicit-railtie case; the removal in the introducing PR was deliberate. No source-code or structural defect found. Must fix body/impact accuracy: config.active_job.queue_adapter raises at boot when the railtie is absent; it is not an existing configured adapter silently ignored. The unconfigured test default changes TestAdapter to AsyncAdapter; direct job adapter configuration still works, and production defaults are Async on both trees. Delete the body's configured-adapter clause and its final outside-Rails-only CHANGELOG claim (the entry generally announces decoupling, but omits railtie-list instructions); cut the meta opening and name config.active_job.queue_adapter. Eighteen stable/head fresh-process scenarios pass, reproducing config boot failure, Test-to-Async fallback, Turbo helper omission and explicit-require/rails-all controls; two production controls agree. Action Mailer 88/275, Railties frameworks 28/52, configuration adapter cases 7/14, Guides 18/39/2 skips, all 0 failures/errors; Rails-configured mdl passes. Released Turbo 2.0.23 and ViewComponent 4.25.0 line permalinks checked, but no full ViewComponent sandbox run or new app-prevalence sample. Thomas author/committer, no trailers. Sentence audit, evidence, commands and smallest fixes: docs/upstream/rails-main-census-11.md#ug82m."}
---

# Note in the upgrade guide that Action Mailer no longer loads Active Job

An app that lists its frameworks in `config/application.rb` and requires `action_mailer/railtie` without `active_job/railtie` got the Active Job railtie through Action Mailer's until #59820. On main it doesn't, so setting `config.active_job.queue_adapter` raises `NoMethodError` on boot. This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" that says to require the Active Job railtie explicitly.
