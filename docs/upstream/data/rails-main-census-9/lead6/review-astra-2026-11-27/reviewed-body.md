# Look up indexes inline in LazyIndexedAttributeSet#[] and #keys

Since #59141, `LazyIndexedAttributeSet#[]` and `#keys` find each attribute through `index_for_name` and `lookup`, which are two method calls per attribute. Saving a record runs both for every attribute: dirty tracking calls `#keys` three times, and `#[]` once for each attribute it checks. So `update!` of one column costs more the wider the table is. This change inlines the two lookups in both methods, as `#fetch_value_at` already inlines `lookup`. The inlined code reads the same instance variables at the same points, so the results don't change.

Callgrind instructions per call, Ruby 4.0, no JIT, objects per call unchanged:

| | main | this change |
|---|---:|---:|
| `update!` of one column, 30 columns | 1,456,136 | 1,395,418 |
| load a record, then `changed?`, 30 columns | 712,038 | 681,893 |
| `serializable_hash`, 30 columns | 191,400 | 178,771 |

At 102 columns `update!` runs 7.8% fewer instructions. With YJIT, `update!` and load then `changed?` at 30 columns run about 2% fewer.
