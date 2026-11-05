### Keep models with mutable defaults off the frozen defaults

#59083 [freezes a model's default attributes](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/model_schema/schema_context.rb#L119-L121) when [every one is freezable](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activemodel/lib/active_model/attribute.rb#L42-L44). Each new record dups the value cast when freezing. Two mutable defaults break:

* A serialized default the coder doesn't round-trip reads as changed in a new record and is saved. OpenProject's [`HealthReport`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/models/health_report.rb#L33) loads its [`jsonb DEFAULT '{}' NOT NULL`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/structure.sql#L3050) as `[]`, and `HealthReport.new(subject: storage).save!` raises `PG::NotNullViolation`. 8.1 saved it only after the attribute was read.
* A nested default (`'{"theme":{"mode":"light"}}'` with a JSON coder) is shared: a change via one new record shows in the next.

An attribute whose type, or the type `normalizes` wraps, is `Type::Helpers::Mutable` (serialized, JSON, PostgreSQL arrays and hstore, points, encrypted) is no longer freezable. Its model keeps 8.1's writable defaults and per-record casts; nothing is cast at schema load. Other models keep the frozen defaults, within A/A (Callgrind, Ruby 4.0 and master); affected ones pay +18–22% again.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/cb32d8e9ab8940671cf707304bbfea0a4258e4b4/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
