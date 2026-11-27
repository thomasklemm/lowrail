# OP8: answer to rafaelfranca's inline question (2026-11-26), drafts for Thomas

Question on `activemodel/lib/active_model/attribute.rb:43`: "This is strange. Isn't better to override `freezable?`
in the types that matter?"

Replacement head: [`424441d986`](https://github.com/thomasklemm/rails/commit/424441d98683697154e5a3b85de8fc86fefec508)
on `thomasklemm/serialized-defaults-not-freezable`, one commit on main `9e82904f18`. Force-pushed to the PR branch
with a lease on `71c77e3a01` on 2026-11-27 after Thomas approved; title and body PATCHed as below. The reply was
posted with Thomas's added trade-off sentences: https://github.com/rails/rails/pull/59662#discussion_r4718321474

## Reply (first draft; Thomas edited the posted comment to end with the code-search result instead, see OP8.md)

> Agreed, that reads better. Since #59972 a new record gets a `deep_dup` of a frozen default, so JSON, array and
> hstore defaults are no longer shared and can stay frozen. Only serialized types still need to opt out, because a
> coder can load the default, even NULL, as something that reads as changed. `Attribute#freezable?` now asks the
> type: `Type::Value#freezable?` is true, `Type::Serialized` returns false, and encrypted types ask the type they
> encrypt.

## Title

Don't freeze serialized column defaults

## Body

#59083 [freezes a model's default attributes](https://github.com/rails/rails/blob/9e82904f18daceb77761a5705dde0c529026cea2/activerecord/lib/active_record/model_schema/schema_context.rb#L137-L139) when [every one is freezable](https://github.com/rails/rails/blob/9e82904f18daceb77761a5705dde0c529026cea2/activemodel/lib/active_model/attribute.rb#L42-L44), and new records copy the cast value. For a serialized attribute the coder decides that value, and it may not round-trip the column default. OpenProject's [`HealthReport`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/models/health_report.rb#L33) loads its [`t.jsonb :results, null: false, default: {}`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/migrate/20260428133700_create_health_reports.rb#L34) as `[]`, so in its test suite on Rails main, `HealthReport.new(subject: storage).save!` raises `PG::NotNullViolation` (8.1: only after a read).

Now serialized types don't let their defaults be frozen, and encrypted types ask the type they encrypt. Models with a serialized attribute keep 8.1's writable defaults; other models, including those with JSON, array and hstore defaults, stay frozen.
