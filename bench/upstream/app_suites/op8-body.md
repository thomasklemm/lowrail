### Keep models with mutable defaults off the frozen defaults

#59083 [freezes a model's default attributes](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/model_schema/schema_context.rb#L119-L121) when [every one is freezable](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activemodel/lib/active_model/attribute.rb#L42-L44); new records dup the cast value. Two mutable defaults break:

* A serialized default the coder doesn't round-trip reads as changed and is saved. OpenProject's [`HealthReport`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/models/health_report.rb#L33) loads its [`jsonb DEFAULT '{}' NOT NULL`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/structure.sql#L3050) as `[]`, so `HealthReport.new(subject: storage).save!` raises `PG::NotNullViolation` (8.1: only after a read).
* A nested default (`'{"theme":{"mode":"light"}}'` with a JSON coder) is shared between new records.

Now a mutable type (JSON, PostgreSQL arrays, hstore, points) freezes only a NULL default and `serialize` none (its coder loads even NULL); `normalizes` and `encrypts` defer to the wrapped type. Affected models keep 8.1's uncast writable defaults: 51 of OpenProject's 305 frozen models, 6 of Mastodon's 117; ruby-bench: 9 of shipit's 26, 1 of lobsters' 24, none in activerecord or railsbench. They pay +18–22% again; other models, NULL json included, stay within 0.25% (Callgrind).

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/cb32d8e9ab8940671cf707304bbfea0a4258e4b4/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
