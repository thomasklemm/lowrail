### Keep a new record's copy of a frozen default attribute unread

Since #59083 a model's default attributes are [frozen at schema load](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/model_schema/schema_context.rb#L119-L121), and [freezing an attribute casts its value](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activemodel/lib/active_model/attribute.rb#L46-L47). A new record's copy of a mutable default inherits that cast value, so dirty tracking treats it as read and compares it with the raw default.

When a serialized column's coder does not round-trip the column default, a brand-new record now reports a change it never made and saves it. OpenProject's [`HealthReport`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/models/health_report.rb#L33) has a [`jsonb DEFAULT '{}' NOT NULL`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/structure.sql#L3050) column whose coder loads `{}` as `[]`:

```ruby
report = HealthReport.new(subject: storage)
report.changed # 8.1: ["subject_type", "subject_id"]; main: also "results"
report.save!   # 8.1: saved; main: PG::NotNullViolation, results is NULL
```

The value is NULL because [serialized types write the coder's empty value as NULL](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/type/serialized.rb#L79-L85). On 8.1 that happens only after the app reads the attribute.

The copy of a frozen attribute now starts unread, as defaults did before #59083, and is cast again on first read. This also stops new records from sharing the nested objects of a serialized default, which the shallow `dup` of the cast value does on main. The test fails on main.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
