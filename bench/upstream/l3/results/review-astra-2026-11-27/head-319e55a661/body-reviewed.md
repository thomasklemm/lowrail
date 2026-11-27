# Build attribute Hashes without copying the lazy row

Since #59141, `attributes_for_database` and `attributes_before_type_cast` on a record copy all of its attributes into a new `IndexedRow::Mutable` on every call, only to turn that row into a Hash. `Marshal.dump` of a record and the MessagePack cache coder call `attributes_for_database` once per record.

Both methods now materialize the attributes as before, then build each Hash from a snapshot in index order. The snapshot preserves the result if a serializer or callable default assigns another attribute. Reading the values from the row instead, as `#to_hash` does, would skip building the attributes, but an encrypted attribute would then dump a new ciphertext on every call.

```ruby
require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    9.times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

values = {}
9.times { |i| values.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
post = Post.find(Post.create!(values).id)

Benchmark.ips do |x|
  x.report("Marshal.dump") { Marshal.dump(post) }
  x.report("attributes_for_database") { post.attributes_for_database }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before:            Marshal.dump     36.143k (± 6.7%) i/s   (27.67 μs/i) -    183.918k in   5.088614s
before: attributes_for_database     92.570k (± 4.5%) i/s   (10.80 μs/i) -    466.760k in   5.042253s
after:             Marshal.dump     43.776k (± 4.6%) i/s   (22.84 μs/i) -    220.904k in   5.046205s
after:  attributes_for_database    150.662k (± 9.0%) i/s    (6.64 μs/i) -    754.572k in   5.008384s
```

On a record whose attributes are built, each method now allocates two objects per call instead of four. The script's table has 30 columns; the gain holds from 6 to 100.
