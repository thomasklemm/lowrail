### Transaction-level try locks are not held on Rails main

Heads-up in case it's useful: on Rails main (8.2.0.alpha), when it is the first statement in the transaction, a `transaction: true` try lock (exclusive or shared, any `timeout_seconds`) is released as soon as it is taken, so a second caller gets it too. Session locks and `blocking: true` are unaffected.

```ruby
held, release = Queue.new, Queue.new
first = Thread.new do
  Tag.transaction { Tag.with_advisory_lock("demo", transaction: true) { held << true; release.pop } }
end
held.pop
p Thread.new { Tag.transaction { Tag.with_advisory_lock("demo", transaction: true, timeout_seconds: 0) { :got_it } } }.value
# Rails 8.1: false; Rails main: :got_it
release << true; first.join
```

[rails/rails@01e33f8](https://github.com/rails/rails/commit/01e33f82f829b12273eb66e9fff80bbb36daf12b) made the internal `query_*` methods default to `materialize_transactions: false` (on PostgreSQL, [`query_rows`](https://github.com/rails/rails/blob/3ba9e53d7e7e85a11b3b88ed68b7d9293c0d2169/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb#L15), which `query_value` uses). So the [try-lock `query_value(sql)`](https://github.com/ClosureTree/with_advisory_lock/blob/58718b42d78cb2a0d5460da261986687d5a852f8/lib/with_advisory_lock/postgresql_advisory.rb#L165) runs before the lazy `BEGIN`, and `pg_try_advisory_xact_lock` ends with that statement. Rails' own `pg_try_advisory_lock` call passes `materialize_transactions: true` since that commit.

Passing it on the try path, with the same `internal_exec_query` check as the [blocking path](https://github.com/ClosureTree/with_advisory_lock/blob/58718b42d78cb2a0d5460da261986687d5a852f8/lib/with_advisory_lock/postgresql_advisory.rb#L155-L161), fixes it (7.6.0 on Rails main):

```ruby
result = if respond_to?(:internal_exec_query, true)
           query_value(sql) # Rails < 8.2
         else
           query_value(sql, 'AdvisoryLock', materialize_transactions: true)
         end
```

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/0513a9bacf1e309720dbf7b9ca01150e88ddbd52/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
