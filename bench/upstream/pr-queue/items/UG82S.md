---
id: UG82S
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, middleware"
reviewer: "byroot (#56915)"
branch: thomasklemm/upgrade-guide-sendfile-unset
head: "2422669c945eef9679da2c9e1bb33266700e24e9"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
impact: "apps that insert middleware relative to Rack::Sendfile without x_sendfile_header raise on boot (Redmine)"
rank: 12
risky: false
state: built
note: "split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from c90a929275 unchanged (patch-id equal). Waits for a free rails/rails slot after UG82H and UG82P."
passes:
  - {reviewer: claude-code, head: "2422669c945eef9679da2c9e1bb33266700e24e9", date: 2026-11-10, verdict: approve, open: "On main 224f5b1563: without x_sendfile_header the stack has no Rack::Sendfile and insert_before Rack::Sendfile raises exactly the quoted RuntimeError; with the header it boots; Executor is unconditional and follows Static, and insert_before Executor boots. Redmine config/application.rb L79 checked. No changes."}
---

# Note in the upgrade guide that Rack::Sendfile is omitted when x_sendfile_header is unset

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. `Rack::Sendfile` is omitted when `x_sendfile_header` is unset (#56915), so `insert_before Rack::Sendfile` then raises on boot, as in [Redmine](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/config/application.rb#L79).

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c7893f5d5b509a2514303c84459f74bb0499d6fc/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
