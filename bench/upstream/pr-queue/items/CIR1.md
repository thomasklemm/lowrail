---
id: CIR1
repo: rails/rails
kind: fix
area: "Action Mailbox, conductor routes"
reviewer: "mattyr (#59950)"
branch: thomasklemm/conductor-create-route-name
head: "d09a3fffa50d9edde388e726e3daf422e2cf4656"
base: main
built_on: "088fc0cf61"
introduced_by: 59950
depends_on: []
stacked_on:
alternative_of:
impact: "Since #59950 (merged 2026-11-26, unreleased) the conductor routes are prepended in development and test, and the unnamed `post \"inbound_emails\"` takes the path-derived name inbound_emails, so an app's top-level `resources :inbound_emails` loses its name there: inbound_emails_path points at the conductor in development/test and at the app in production. No affected caller found: GitHub code search finds 9 non-copy `resources :inbound_emails` in config/, and the current ones (betagouv/collectif-objets, one-work/rails_com) are namespaced (api_v1_, panel_), so they don't collide. One-token fix (`as: nil`)."
evidence: [bench/upstream/rails_main_hotlines/names82]
rank: 20
risky: false
state: held
note: "2026-11-27 (Rails 8.2 name-collision sweep): held as a parked idea, correctness fix with no caller of reach found (DECISIONS: only PRs with large relevance open; compatibility freeze until the 8.2 beta). Repro inbound_emails_route.rb: 8.1.4.1 all envs and main production give GET /inbound_emails -> inbound_emails#index; main development/test give POST /rails/conductor/action_mailbox/inbound_emails; branch matches 8.1.4.1 in all three. New railties routing test fails on main and passes on head; routing_test 40 runs, routes_test 8, actionmailbox 125, all green; RuboCop clean. Not reviewed: open it only if a real app is found or a maintainer touches these routes again, after thermos-sol and Astra on the head."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #59950"], hits: []}
passes: []
---

# Don't name the conductor's inbound email create route

Since #59950 the Action Mailbox conductor routes are prepended in development and test. The create route has no `as:`, so it takes the name derived from its path, `inbound_emails`, and an app's own `resources :inbound_emails` loses that name there: `inbound_emails_path` returns `/rails/conductor/action_mailbox/inbound_emails` in development and test, and `/inbound_emails` in production.

This passes `as: nil`, so the create route has no name, as when it came from the conductor's `resources :inbound_emails, as: :rails_conductor_inbound_emails`.
