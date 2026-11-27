---
id: UG82D
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, Active Record default_order"
reviewer: "rafaelfranca (#39525)"
branch: thomasklemm/upgrade-guide-default-order-scope
head: "747652dc50"
base: main
built_on: "088fc0cf61"
introduced_by: 39525
depends_on: []
stacked_on:
alternative_of:
impact: "Since #39525 (merged 2026-05-28, unreleased) Active Record has a public default_order query method delegated from every model (Querying), so `scope :default_order` raises ArgumentError at class load (dangerous_class_method?), and a model's own `def self.default_order` still works on the model but a relation answers with the query method, which raises without arguments. Neither the CHANGELOG entry nor the upgrade guide says so. GitHub code search: about 333 `scope :default_order` hits and 143 `def self.default_order` (2026-11-27), e.g. otwarchive, fat_free_crm 0.28.0, fjordllc/bootcamp; Flow's suite errors in 409 of 452 tests on main from it. Docs only; a deliberate feature, not a Rails bug."
evidence: [bench/upstream/rails_main_hotlines/ug82d]
rank: 4
risky: false
state: in-review
note: "2026-11-27 (Rails 8.2 pre-beta round): found by the heavy-app slice in Flow's controller tests (company_membership.rb:34), repro in bench/upstream/rails_main_hotlines/ug82d (results.txt: 8.1.4.1 works, main raises for the scope and for the class method on a relation). No issue or PR names the collision (searched 'default_order scope', the error text, 'default_order conflict'; #39525's cross-references are follow-up fixes #59496, #59497, #59523, #57630, open #37807, #45864). Guide section placed after the enum negative-scopes section. Commit message names no PR number (fork push would reference it)."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #39525"], hits: ["references #39525: rails/rails#37807 (PR, open, GermanDZ): Fix first and last when records are not loaded in a sorted relationship","references #39525: rails/rails#45864 (PR, open, simi): Add Relation#select_append method to append to default selection."]}
passes: []
---

# Note in the upgrade guide that models can't define a `default_order` scope

Active Record's new `default_order` query method is available on every model, so a model that defines a scope with that name now raises `ArgumentError` when it loads. The name is common in applications, for example [otwarchive](https://github.com/otwcode/otwarchive/blob/452391b648f2fb06b55c36133812449747634504/app/models/language.rb#L12), [fat_free_crm 0.28.0](https://github.com/fatfreecrm/fat_free_crm/blob/1f3dd674f30b1fb3979301985ed77ddfdccb5148/app/models/polymorphic/version.rb#L18) and [bootcamp](https://github.com/fjordllc/bootcamp/blob/9f3e2a4c83216a4922f37e53088853009aab095d/app/models/report.rb#L48). A `default_order` class method still runs on the model, but on a relation the query method runs instead and raises without arguments.

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" that shows the error and says to rename the scope or class method.
