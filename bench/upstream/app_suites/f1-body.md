### Load unknown PostgreSQL types in lookup_cast_type

Since #57013 the PostgreSQL adapter loads type OIDs on demand, but [`lookup_cast_type`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/connection_adapters/postgresql/quoting.rb#L190) looks up the OID without loading it. When their OIDs are absent from the type map, these lookups return `ActiveModel::Type::Value`, as happens for extension types and their arrays. Adding an array column of such a type with a default now raises, which also stops a schema from loading:

```ruby
add_column :ltrees, :paths, :ltree, array: true, default: ["1.2"]
# => TypeError: can't quote Array
```

It works on 8.1. Forem's `db/schema.rb` has such a column, [`t.ltree "target_geolocations", default: [], array: true`](https://github.com/forem/forem/blob/5f0276dce15e3859f7bf4d39c5460efbdc398288/db/schema.rb#L727) (main), so `db:schema:load` stops at `display_ads`. `citext[]` and `hstore[]` fail the same way.

This loads the OID first when the type map doesn't have it, as [`get_oid_type`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L1045) already does. The new test adds an `ltree` array column with a default and checks the model's default; it fails on main with the `TypeError`. With this change, Forem's schema loads all 135 tables.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
