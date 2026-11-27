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
state: built
note: "2026-11-27 (Rails 8.2 name-collision sweep, names82/README.md): found by diffing method lists of 8.1.4.1 and main 088fc0cf61 on Ruby 4.0.10 (both trees booted; the two methods moved private->public on the model singleton). Repro model_collisions.rb, the callers' own files at their SHAs in timestamp_callers.rb (8.1.4.1 works, main NoMethodError for all three), differential ts_probe.rb: 20 cases (private, protected, concern class_methods, abstract parent, STI, extend, singleton prepend, alias_attribute, touch, insert_all, reset_column_information, public call/respond_to?/send/private_methods) identical on 8.1.4.1 and the branch; main differs only for non-public overrides and the public-call/visibility rows. New test fails on main with the NoMethodError and passes on head; AR SQLite suite on head 10460 runs, 0 F, 5 E, all 5 environment errors (no pg gem, no sqlite3 CLI) that error the same on base. RuboCop clean. Searched rails/rails issues/PRs for both method names: nothing since 2019. No CHANGELOG: the regression is unreleased. Compatibility freeze until the 8.2 beta (DECISIONS) applies; opening needs the coordinator's decision."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #58735","open PRs naming resolve_model_hooks, timestamp_attributes_for_create, timestamp_attributes_for_update that change activerecord/lib/active_record/model_schema/schema_context/mapped_table.rb, activerecord/lib/active_record/timestamp.rb"], hits: []}
passes: []
---

# Keep `timestamp_attributes_for_create` and `_for_update` private

#58735 made `timestamp_attributes_for_create` and `timestamp_attributes_for_update` public so the mapped table can [call them](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/model_schema/schema_context/mapped_table.rb#L60-L61) when the schema loads. Models that add or replace timestamp columns override them as private class methods, as Rails defined them through 8.1, and on main such a model raises `NoMethodError: private method 'timestamp_attributes_for_create' called` on its first create or update.

This makes both methods private again and calls them with `send` from the mapped table, so public and private overrides both work as in 8.1.

Affected, for example, [trefle-api (master)](https://github.com/treflehq/trefle-api/blob/2f93e59c903b6c66563a6203703dd17d49e75ef1/app/models/application_record.rb#L7) on its `ApplicationRecord`, and [publish-teacher-training (main)](https://github.com/DFE-Digital/publish-teacher-training/blob/6bf930764bd454d8a97087ac58655308ef862195/app/models/concerns/changed_at.rb#L14), whose `ChangedAt` concern its `Course` and `Provider` models include.
