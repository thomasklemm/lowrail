---
id: UG82K
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, Active Job"
reviewer: "guilleiguaran (merged #56518)"
branch: thomasklemm/upgrade-guide-sidekiq-8-0-3
head: "f526d29c5025178a57b10a2270492949406259d4"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
introduced_by: 56518
impact: "apps with queue_adapter = :sidekiq on Sidekiq 7.3.x or 8.0.0-8.0.2, including the 7.3.3+ the 8.1 deprecation recommends, fail to boot or load ActiveJob::Base on main"
rank: 12
risky: false
state: reviewed
pr:
note: "split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from 28e73a9396 unchanged (patch-id equal). Strength check passed (docs/upstream/app-suites.md, UG82 split): (a) on main 224f5b1563 a minimal app with queue_adapter = :sidekiq fails with Sidekiq 7.3.2-7.3.10 and 8.0.0-8.0.2 and boots with 8.0.3 and 8.1.7, all boot on 8-1-stable; (b) 8.1's deprecation says to upgrade to 7.3.3 or later. Open point for review: the require sentence is stricter than needed (an initializer require works on main from Sidekiq 8.0.5; only 8.0.3-8.0.4 need application.rb), and require: false with no require already fails on 8.1. Waits for a free slot after UG82H and UG82P."
ownership: {date: 2026-11-25, checked: ["open PRs cross-referencing #56518"], hits: ["references #56518: rails/rails#59675 (PR, open, thomasklemm): Note in the upgrade guide that link_to and button_to moved to NavigationHelper"]}
passes:
  - {reviewer: claude-code, head: "f526d29c5025178a57b10a2270492949406259d4", date: 2026-11-10, verdict: approve, open: "Reran on main 224f5b1563, Ruby 4.0.9, load_defaults 8.1: required before the app class, 7.3.10 and 8.0.2 raise NameError for SidekiqAdapter, 7.3.3 raises it at require even with :async, 8.0.3/8.0.4/8.0.5 boot; require: false without a require fails on all; initializer require works only from 8.0.5, application.rb from 8.0.3, so the require advice is stricter than needed for 8.0.5+ but correct, keep it. #6669 is in Sidekiq 8.0.3 Changes.md. No changes."}
  - {reviewer: opus, orb: T-01a1e18f-86a8-75c0-91a2-90cc92fb40c7, head: "f526d29c5025178a57b10a2270492949406259d4", date: 2026-11-15, verdict: nits, open: "Guide text and the current body (bb6a5c4b: footer cut, how-found clause added) approved with a nit. Reran on rails/rails main 78039119db (merges cleanly, guide and activejob unchanged since 224f5b1563), Ruby 4.0.9, load_defaults 8.1, minimal app with queue_adapter = :sidekiq: Sidekiq 7.3.2, 7.3.10 and 8.0.2 raise NameError uninitialized constant ActiveJob::QueueAdapters::SidekiqAdapter whether required before the app class, from an early initializer, or not at all; 7.3.3 raises NameError from remove_const in sidekiq/rails.rb at require, also with queue_adapter = :async; 8.0.3, 8.0.4, 8.0.5 and 8.1.0 boot when required before the app class; require: false with no require fails on all; an initializer require works only from 8.0.5. 8-1-stable's deprecation says 7.3.3 or later; main's activejob CHANGELOG has the removal (#56518, merge 63d2a1c928); Sidekiq Changes.md lists #6669 under 8.0.3 and sidekiq/sidekiq#6669 is merged. The how-found clause matches docs/upstream/app-suites.md GR7 (found booting Gumroad on Sidekiq 7.3). rubocop (Rails' 1.90.0 + rubocop-md 3.0.0) and mdl clean on the guide. Nits: 'the 7.3.3+' -> 'Sidekiq 7.3.3 or later' (no shorthand); the require advice is stricter than needed from 8.0.5 but correct for the 8.0.3 minimum, keep it."}
  - {reviewer: claude-code, head: "f526d29c5025178a57b10a2270492949406259d4", orb: T-01a1e18b-510a-735a-84ec-88579c5aa137, date: 2026-11-16, verdict: approve, open: "Confirm on the body after bb6a5c4b and the opus nit (no shorthand: 'including the Sidekiq 7.3.3 or later that the 8.1 deprecation recommends'); head unchanged, merges cleanly with main 78039119db, author/committer Thomas, no trailers, rubocop (1.90.0 + rubocop-md) and git diff --check clean. Reran on main 78039119db, Ruby 4.0.9, load_defaults 8.1, queue_adapter = :sidekiq: required before the app class 7.3.10 and 8.0.2 raise NameError uninitialized constant ActiveJob::QueueAdapters::SidekiqAdapter when ActiveJob::Base loads (with :async/:test they boot); 7.3.3 raises NameError from remove_const at require, whatever the adapter; 8.0.3/8.0.4/8.0.5 boot; no require fails on all; an initializer require fails on 8.0.3/8.0.4 at initialize! and works on 8.0.5, so the guide's require advice is stricter than needed only from 8.0.5 (keep). Removal is 10c24f2481 (merge 63d2a1c928, #56518); 8-1-stable's deprecation says 7.3.3 or later; Sidekiq Changes.md lists 'Rework Rails integration [#6669]' under 8.0.3. How-found clause matches app-suites GR7. No changes."}
---

# Note in the upgrade guide that Sidekiq 8.0.3 or later is required

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. Booting an app that uses Sidekiq 7 on main, I found that Sidekiq 8.0.3 or later is needed (#56518): older releases, including the Sidekiq 7.3.3 or later that the 8.1 deprecation recommends, can fail to load Sidekiq's adapter, which sidekiq/sidekiq#6669 fixed in 8.0.3. Sidekiq must also be required before initialization, including when its Gemfile entry uses `require: false`.
