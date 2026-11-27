# Look up indexes inline in LazyIndexedAttributeSet#[] and #keys

Since #59141, `LazyIndexedAttributeSet#[]` and `#keys` find each attribute through `index_for_name` and `lookup`, which are two method calls per attribute. In the measured `update!` of one column, dirty tracking calls `#keys` three times and `#[]` once for each attribute it checks. So `update!` of one column costs more the wider the table is. This change inlines the two lookups in both methods, as `#fetch_value_at` already inlines `lookup`. The inlined code reads the same instance variables at the same points, so the results don't change.

A benchmark of serializing a record from a 30-column table:

```ruby
require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
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
Benchmark.ips { |x| x.report("serializable_hash") { post.serializable_hash } }
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before:   serializable_hash     50.195k (± 7.9%) i/s   (19.92 μs/i) -    250.992k in   5.000357s
after:    serializable_hash     52.253k (± 7.5%) i/s   (19.14 μs/i) -    261.406k in   5.002670s
```

Callgrind instructions per call, Ruby 4.0, no JIT:

| | main | this change |
|---|---:|---:|
| `update!` of one column, 30 columns | 1,456,136 | 1,395,418 |
| load a record, then `changed?`, 30 columns | 712,038 | 681,893 |
| `serializable_hash`, 30 columns | 191,400 | 178,771 |

At 102 columns `update!` runs 7.8% fewer instructions. With YJIT, `update!` and load then `changed?` at 30 columns run about 2% fewer.
