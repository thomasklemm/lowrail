# Build attribute Hashes without copying the lazy row

Since #59141, `attributes_for_database` and `attributes_before_type_cast` on a record copy all of its attributes into a new `IndexedRow::Mutable` on every call, only to turn that row into a Hash. `Marshal.dump` of a record and the MessagePack cache coder call `attributes_for_database` once per record.

This builds both Hashes straight from the set's attributes, after building them as before, in the order of its indexes. The same method runs on the same attributes, so the Hashes and the record afterwards are unchanged. `attributes_for_database` still reads them from a copy, as the row was, since serializing a value can run code that assigns another attribute. Reading the values from the row instead, as `#to_hash` does, would skip building the attributes but would not be the same: an encrypted attribute would dump a new ciphertext on every call.

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

before:            Marshal.dump     37.337k (± 4.3%) i/s   (26.78 μs/i) -    188.500k in   5.048642s
before: attributes_for_database     93.220k (± 2.0%) i/s   (10.73 μs/i) -    467.064k in   5.010354s
after:             Marshal.dump     42.863k (± 7.7%) i/s   (23.33 μs/i) -    216.976k in   5.062101s
after:  attributes_for_database    153.856k (±11.0%) i/s    (6.50 μs/i) -    772.850k in   5.023190s
```

On a record whose attributes are built, `attributes_for_database` now allocates two objects per call instead of four, and `attributes_before_type_cast` one. The script's table has 30 columns; the gain holds from 6 to 100.
