# Build attribute Hashes without copying the lazy row

Since #59141, `attributes_for_database` and `attributes_before_type_cast` on a record copy all of its attributes into a new `IndexedRow::Mutable` on every call, only to turn that row into a Hash. `Marshal.dump` of a record and the MessagePack cache coder call `attributes_for_database` once per record.

This builds both Hashes straight from the set's attributes, in the order of its indexes, after building them as before, so the Hashes and the record afterwards are unchanged. Both still read from a copy of the attributes, since serializing a value or evaluating a callable default can assign another attribute. Reading the values from the row instead, as `#to_hash` does, would skip building the attributes, but an encrypted attribute would then dump a new ciphertext on every call.

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

before:            Marshal.dump     36.872k (± 3.8%) i/s   (27.12 μs/i) -    187.150k in   5.075668s
before: attributes_for_database     91.454k (± 4.0%) i/s   (10.93 μs/i) -    458.738k in   5.016068s
after:             Marshal.dump     44.549k (± 5.0%) i/s   (22.45 μs/i) -    224.700k in   5.043857s
after:  attributes_for_database    160.185k (± 7.4%) i/s    (6.24 μs/i) -    812.702k in   5.073511s
```

On a record whose attributes are built, each method now allocates two objects per call instead of four. The script's table has 30 columns; the gain holds from 6 to 100.
