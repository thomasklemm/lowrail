---
id: CELLS75
repo: trailblazer/cells-rails
kind: fix
area: Rails 8.2 helpers
reviewer:
branch: thomasklemm/navigation-helper
head: "6ba587cce668bb823022cd1416ee9a9c48152e68"
base: master
built_on: "77ff22ae8f94472cf477672ca2f0c86757d627d8"
depends_on: []
stacked_on:
alternative_of:
impact:
rank:
risky: false
state: ready
pr: 75
note: "2026-11-15 (red-PR sweep): red from dependency drift on master, not ours (our line is a no-op before Rails 8.2): 4 Rails 6.0 jobs uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger; 4 Rails 7.1/7.2 jobs on Ruby 3.2/3.3 railties line_filtering ArgumentError with minitest 6.0.6; 5 jobs SimpleFormTest expects aria-required, which simple_form 5.4.1 no longer emits; 3 ruby-head jobs cannot load ostruct (master with gemfiles/8.0 on Ruby 4.0.7 fails the same way locally). master 77ff22a has not moved and has no CI since 2024; no push, a rerun would fail the same. Needs a maintainer fix to the matrix or gemfiles. Opened before the queue tracked it; item added 2026-11-14 so status watches it. built_on is the merge base GitHub reports for head. Passes and record: docs/upstream/contributions.md."
passes:
  - {reviewer: claude-code, head: "6ba587cce668bb823022cd1416ee9a9c48152e68", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: nits, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Clause backed by app-suites.md DC2. Nit applied: 'as Decidim's cells do' -> 'as its cells do'."}
---

# Include NavigationHelper in cells on Rails 8.2
