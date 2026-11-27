---
id: TSP1
repo: rails/rails
kind: fix
area: "Active Record, timestamps"
reviewer: "skipkayhil (#58735)"
branch: thomasklemm/private-timestamp-attributes
head: "25d4cf4f23601fa91284feaa216fb2ecd3978122"
base: main
built_on: "088fc0cf61"
introduced_by: 58735
depends_on: []
stacked_on:
alternative_of:
impact: "Since #58735 (merged 2026-09-11, unreleased) timestamp_attributes_for_create/_for_update are public and the mapped table calls them with an explicit receiver, so a model or concern that overrides them as private class methods (Rails' own visibility through 8.1) raises NoMethodError on its first create or update. GitHub code search: about 590 `def timestamp_attributes_for_create` and 592 `_for_update` hits, mostly vendored Rails copies; verified current callers trefle-api (590 stars, Rails 8.1.4, private override on ApplicationRecord, so every model) and DFE-Digital/publish-teacher-training (Rails 8.1.4.1, ChangedAt concern in Course and Provider). Public overrides (e.g. AixleHQ/flow) are unaffected. A correctness fix of an unreleased regression; no numbers."
evidence: [bench/upstream/rails_main_hotlines/names82]
rank: 3
risky: false
state: reviewed
note: "2026-11-27 (reviews): astra approve and thermos-sol nits on 25d4cf4f23 with the af1686dd body; not opened: the compatibility freeze until the 8.2 beta has no standing exception for it, so the coordinator decides. 2026-11-27 (Rails 8.2 name-collision sweep, names82/README.md): found by diffing method lists of 8.1.4.1 and main 088fc0cf61 on Ruby 4.0.10 (both trees booted; the two methods moved private->public on the model singleton). Repro model_collisions.rb, the callers' own files at their SHAs in timestamp_callers.rb (8.1.4.1 works, main NoMethodError for all three), differential ts_probe.rb: 20 cases (private, protected, concern class_methods, abstract parent, STI, extend, singleton prepend, alias_attribute, touch, insert_all, reset_column_information, public call/respond_to?/send/private_methods) identical on 8.1.4.1 and the branch; main differs only for non-public overrides and the public-call/visibility rows. New test fails on main with the NoMethodError and passes on head; AR SQLite suite on head 10460 runs, 0 F, 5 E, all 5 environment errors (no pg gem, no sqlite3 CLI) that error the same on base. RuboCop clean. Searched rails/rails issues/PRs for both method names: nothing since 2019. No CHANGELOG: the regression is unreleased. Compatibility freeze until the 8.2 beta (DECISIONS) applies; opening needs the coordinator's decision."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #58735","open PRs naming resolve_model_hooks, timestamp_attributes_for_create, timestamp_attributes_for_update that change activerecord/lib/active_record/model_schema/schema_context/mapped_table.rb, activerecord/lib/active_record/timestamp.rb"], hits: []}
passes:
  - {reviewer: thermos-sol, head: "25d4cf4f23601fa91284feaa216fb2ecd3978122", orb: T-01a21d3c-d0a4-748b-8840-4b47467cab32, date: 2026-11-27, verdict: nits, open: "Correctness/security and maintainability approve. ts_probe 20 cases plus 8 more byte-identical 8.1.4.1 vs head; three caller files refetched at pinned SHAs, fail on main, pass on head; timestamp suite head 48/105/0/0, base with head test 48/104/0/1 (the new test), sqlite3_ractor 47/104/0/0; diff --check clean. Nits: (1) body quoted the create-hook error though DFE hits the update hook, same as Astra's, already fixed in af1686dd; (2) commit message says the mapped table's call made them public, while SchemaContext did (7fb3234736) and MappedTable took the calls over later (b5200ac8f2); not applied, to keep the reviewed head. Report: artifact 2a5621a2-b69c-4178-ba38-23bd25f612b0 in the reviewing thread."}
  - {reviewer: astra, head: "25d4cf4f23601fa91284feaa216fb2ecd3978122", orb: T-01a21d3c-d867-704d-8e7d-750267525349, date: 2026-11-27, verdict: approve, open: "Confirm with the body at Lowrail af1686dd: both text fixes present and correct. Accepts plain send: schema reload through a subclass, enum definition and HABTM join-table resolution succeed with public send and fail with private send on 8.1.4.1, parent and head (tsp1_send_contract.rb in the reviewing orb), so a private send is outside the contract. No findings or nits."}
  - {reviewer: astra, head: "25d4cf4f23601fa91284feaa216fb2ecd3978122", orb: T-01a21d3c-d867-704d-8e7d-750267525349, date: 2026-11-27, verdict: changes, open: "63-case adversarial harness (visibilities x singleton/concern/abstract/STI/extend/prepend, refinements, schema reset, fibers, threads, cross-Ractor reads) matches 8.1.4.1 except a model with private_class_method :send (proposed __send__; declined: AR already calls private model hooks with send, e.g. model_schema.rb descendant.send(:reload_schema_from_cache), so such a model breaks on 8.1 too and a __send__ guard covers no contract case). Body: NoMethodError named the create hook though DFE hits the update hook; trefle-api has release v2.3.0, cite it. Both body fixes applied; head unchanged."}
---

# Keep `timestamp_attributes_for_create` and `_for_update` private

#58735 made `timestamp_attributes_for_create` and `timestamp_attributes_for_update` public so the mapped table can [call them](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/model_schema/schema_context/mapped_table.rb#L60-L61) when the schema loads. Models that add or replace timestamp columns override them as private class methods, as Rails defined them through 8.1, and on main such a model raises `NoMethodError` on its first create or update.

This makes both methods private again and calls them with `send` from the mapped table, so public and private overrides both work as in 8.1.

Affected, for example, [trefle-api 2.3.0](https://github.com/treflehq/trefle-api/blob/2d1fc52c60af4c32f697ae238ac516778d535cab/app/models/application_record.rb#L7) on its `ApplicationRecord`, and [publish-teacher-training (main)](https://github.com/DFE-Digital/publish-teacher-training/blob/6bf930764bd454d8a97087ac58655308ef862195/app/models/concerns/changed_at.rb#L14), whose `ChangedAt` concern its `Course` and `Provider` models include.
