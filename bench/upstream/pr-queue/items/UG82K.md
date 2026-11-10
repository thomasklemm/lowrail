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
impact: "apps with queue_adapter = :sidekiq on Sidekiq 7.3.x or 8.0.0-8.0.2, including the 7.3.3+ the 8.1 deprecation recommends, fail to boot or load ActiveJob::Base on main"
rank: 12
risky: false
state: built
note: "split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from 28e73a9396 unchanged (patch-id equal). Strength check passed (docs/upstream/app-suites.md, UG82 split): (a) on main 224f5b1563 a minimal app with queue_adapter = :sidekiq fails with Sidekiq 7.3.2-7.3.10 and 8.0.0-8.0.2 and boots with 8.0.3 and 8.1.7, all boot on 8-1-stable; (b) 8.1's deprecation says to upgrade to 7.3.3 or later. Open point for review: the require sentence is stricter than needed (an initializer require works on main from Sidekiq 8.0.5; only 8.0.3-8.0.4 need application.rb), and require: false with no require already fails on 8.1. Waits for a free slot after UG82H and UG82P."
passes: []
---

# Note in the upgrade guide that Sidekiq 8.0.3 or later is required

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. Sidekiq 8.0.3 or later is needed (#56518): older releases, including the 7.3.3+ that the 8.1 deprecation recommends, can fail to load Sidekiq's adapter, which sidekiq/sidekiq#6669 fixed in 8.0.3. Sidekiq must also be required before initialization, including when its Gemfile entry uses `require: false`.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c7893f5d5b509a2514303c84459f74bb0499d6fc/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
