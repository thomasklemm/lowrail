# Rails 8.2 name collisions (2026-11-27)

Method lists of Rails 8.1.4.1 (`3f290b759c`) and main (`088fc0cf61`), both booted as a minimal Rails app
(`dump.rb` → `methods-*.json.gz`, load_defaults 8.1, `rails/all`, eager load, `pp` and `rake` loaded in both) on Ruby 4.0.10, diffed by
surface and visibility (`diff.rb` → `diff.txt`, `names.rb` → `names.txt`): model instance and singleton, relation,
association proxy, Active Model, controller (Base, API), view, job, mailer, 36 core classes, and the reserved sets
(`dangerous_attribute_methods`, `dangerous_class_method?`, `method_defined_within?(…, Relation)`, `QUERYING_METHODS`).

**99 distinct non-underscore names are new to at least one surface** (plus 65–100 `_`/`__class_attr_*` internals per
surface, and 64 model-singleton names that moved private → public). Reserved sets: +11 dangerous attribute
names (`read_attr`, `resolve_alias`, `association_cache`, `serialization_key`, …), +103 dangerous class names
(e.g. `default_order`, `has_json`, `schema_context`, `mapped_table`, `schema_attributes`, `all_queries_scope`,
`abstract_ancestors`, `primary_key_definition`), +1 querying method (`default_order`). Public removals include
`ActiveRecord::Base.get_primary_key`, `String#mb_chars`, 23 view-instance config readers (`field_error_proc`,
`default_formats`, …; the class-level accessors stay) and the mailer instance `delivery_job` readers.

Collision search: GitHub code search (`queries.txt`, `queries-2.txt` → `search-*.jsonl`), repos ranked by stars and
last push (`rank.rb` → `ranked-*.txt`, `repos.json`), every exact `def NAME` fetched and classified (`verify.rb` →
`verified-1.txt`), and 68 corpus repos (census apps, the three apps T-01a21d12 boots, large Rails apps, widely used
gems; `corpus.txt`, `corpus_grep.sh` → `corpus-hits.txt` with each repo's SHA).

## Confirmed collisions

| Name | Mechanism (repro) | Callers by reach | Decision |
| --- | --- | --- | --- |
| `timestamp_attributes_for_create` / `_for_update` | #58735 made them public and the mapped table calls them with a receiver; a private override raises `NoMethodError` on the first create/update (`model_collisions.rb`, callers' own files in `timestamp_callers.rb`, 20-case differential `ts_probe.rb` → `ts_probe-results.txt`) | trefle-api (590★, Rails 8.1.4, `ApplicationRecord`), DFE-Digital/publish-teacher-training (8.1.4.1, `Course`, `Provider`), postfix_admin 0.8.0 (26k downloads, niche); public overrides (AixleHQ/flow, decko) unaffected | Rails fix **TSP1** |
| `default_order` | known (UG82D, #60005) | otwarchive, fat_free_crm, danbooru, flow (corpus-hits.txt) | done |
| route name `inbound_emails` | #59950 prepends the unnamed conductor `POST inbound_emails` in dev/test, taking an app's `resources :inbound_emails` name there (`inbound_emails_route.rb`) | none found: current hits are namespaced (collectif-objets `api/v1`, rails_com `panel`) | fix built, **CIR1 held** |
| `type_for_column(connection, column)` private override | signature and visibility changed (`model_collisions.rb`) | none: canvas-lms's is on its own `Bookmarker`, rest are vendored copies | drop |
| private `controller_scope`, `controller_action_scope` (controllers), `scope_prefix`, `distance_translation` (helpers), `origin_trusted?` | an app's private method of the same name replaces Rails' new private one: relative `t(".x")` lookups and CSRF trusted-origin checks change (`controller_view_collisions.rb`) | only abandoned or 0–33★ repos (EOL deprecated_eol 2019, line-count test app 2022, shiplix 2018) | drop (niche; private API) |
| `serialization_key` instance method | model's own method replaces the new private Active Model one; `as_json(only:)` raises | thadeu/voodu-webui (0★) | drop |
| scopes / class methods named `schema_context`, `mapped_table`, `schema_attributes`, `abstract_ancestors`, `primary_key_definition`, `has_json`, … | scope raises at load; a `def self.NAME` breaks schema loading (`model_collisions.rb`) | none in models (search 0 for scopes and `def self.`; `has_json` hits are Campfire using the feature) | drop |
| `get_primary_key`, `String#mb_chars` | removed (`removed_probe.rb`) | Mastodon migration helpers (restrictive AI policy, no upstream); `mb_chars` deprecated in 8.1 | drop (`:nodoc:` / deprecated) |

Other new names (`Date#this_week?` etc., `datalist_tag`, `read_attr`, `resolve_alias`, `association_cache`) had
hits only on unrelated classes (not models, controllers or view helpers), Rails copies, or gems defining their own.
