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
introduced_by: 56915
impact: "apps that insert middleware relative to Rack::Sendfile without x_sendfile_header raise on boot (Redmine)"
rank: 4
risky: false
state: merged
pr: 59985
note: "2026-11-25 (Thomas OK, cap raised to 25; no earlier or closed PR on the topic found): opened as draft rails/rails#59985. 2026-11-25 (recheck on main f785381cca): still breaks; insert_before Rack::Sendfile without x_sendfile_header raises No such middleware to insert before: Rack::Sendfile, 8.1.4.1 boots (bench/upstream/ug82-recheck-2026-11-25/results.txt). Open rails/rails#44556 (2022, SValkanov) would remove Sendfile from the stack another way and is stale; no open PR adds a guide note, and the guide has none. Head merges cleanly; passes stay valid. Recommended for the draft slot after UG82K (rank 12 -> 4); still conflicts textually with SP1. Earlier: split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from c90a929275 unchanged (patch-id equal). Waits for a free rails/rails slot after UG82H and UG82P."
ownership: {date: 2026-11-25, checked: ["open PRs cross-referencing #56915"], hits: ["references #56915: basecamp/once-campfire#359 (PR, open, namespaceMarcello): Have Thruster send whole files from disk again","references #56915: rails/rails#59675 (PR, open, thomasklemm): Note in the upgrade guide that link_to and button_to moved to NavigationHelper"]}
passes:
  - {reviewer: claude-code, head: "2422669c945eef9679da2c9e1bb33266700e24e9", date: 2026-11-10, verdict: approve, open: "On main 224f5b1563: without x_sendfile_header the stack has no Rack::Sendfile and insert_before Rack::Sendfile raises exactly the quoted RuntimeError; with the header it boots; Executor is unconditional and follows Static, and insert_before Executor boots. Redmine config/application.rb L79 checked. No changes."}
  - {reviewer: opus, orb: T-01a1e18f-86a8-75c0-91a2-90cc92fb40c7, head: "2422669c945eef9679da2c9e1bb33266700e24e9", date: 2026-11-15, verdict: approve, open: "Guide text and the current body (bb6a5c4b: footer cut, how-found clause added) approved. On rails/rails main 78039119db (merges cleanly; default_middleware_stack.rb unchanged since 224f5b1563), Ruby 4.0.9, minimal app: without x_sendfile_header, insert_before Rack::Sendfile raises RuntimeError 'No such middleware to insert before: Rack::Sendfile', as quoted; with X-Sendfile it boots with Sendfile before Static; insert_before ActionDispatch::Executor boots and lands after ActionDispatch::Static (Static 1, ContentLength 2, Executor 3), so the 'no longer wraps static file responses' sentence holds; Executor is added unconditionally in build_stack. #56915 is afd103d69a (2026-03-02), not in 8-1-stable. Redmine config/application.rb L79 at 41cd39c24a is the quoted insert_before and is unchanged on master 7872c0d026; its production.rb only has the header commented out. The how-found clause matches docs/upstream/app-suites.md S1 (b), Redmine's suite. rubocop + rubocop-md and mdl clean. Queue note, not the body: UG82S and SP1 insert at the same spot after the missing-controllers section and conflict textually; whichever merges second rebases."}
  - {reviewer: claude-code, head: "2422669c945eef9679da2c9e1bb33266700e24e9", orb: T-01a1e18b-510a-735a-84ec-88579c5aa137, date: 2026-11-16, verdict: approve, open: "On main 78039119db (merges cleanly), Ruby 4.0.9, minimal app with load_defaults 8.1 and the public file server on: without x_sendfile_header the stack has no Rack::Sendfile and insert_before Rack::Sendfile, Rack::ContentLength raises RuntimeError No such middleware to insert before: Rack::Sendfile; with x_sendfile_header = X-Sendfile it boots with ContentLength before Sendfile; insert_before ActionDispatch::Executor boots and lands after ActionDispatch::Static (default_middleware_stack.rb adds Executor unconditionally after Static), as the guide says. Change is b37aeee32f (merge afd103d69a, #56915); 8-1-stable adds Sendfile unconditionally. Redmine config/application.rb L79 at 41cd39c24a is the insert_before (200). Body (bb6a5c4b) accurate, how-found clause matches app-suites S1. rubocop and git diff --check clean; author/committer Thomas, no trailers. Conflicts textually only with SP1. No changes."}
---

# Note in the upgrade guide that Rack::Sendfile is omitted when x_sendfile_header is unset

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. `Rack::Sendfile` is omitted when `x_sendfile_header` is unset (#56915), so `insert_before Rack::Sendfile` then raises on boot, as I found running Redmine's test suite on main ([its `config/application.rb`](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/config/application.rb#L79)).
