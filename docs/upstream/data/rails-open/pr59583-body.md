Every read of a loaded `has_one :through` or `has_many :through` a `belongs_to` checks `stale_state`, the owner's foreign key values. For a single-column key it wraps the column name in an Array, maps it into another Array and calls `presence`.

For a plain String key this now reads the column and wraps only the value. Composite keys and String subclasses keep the existing code. The state is the same, `nil` when the key is `nil` or `false`, and `read_attr` is called once as before, so whether a changed foreign key reloads the target is unchanged.

| Per call, loaded `comment.post_author` | Objects | Ir interpreter | Ir YJIT | Ir ZJIT |
| --- | ---: | ---: | ---: | ---: |
| main | 3 | 15,447 | 8,283 | 7,879 |
| this PR | 1 | 12,076 (−22%) | 4,983 (−40%) | 4,571 (−42%) |
| main, A/A rerun | 3 | +0.20% | +0.02% | +0.03% |

Ir is Callgrind instructions per call (5,000 calls minus 0, GC disabled) on Ruby 4.0.7 and, for ZJIT, Ruby master 9aa0898240: [script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/r7/cpu_r7.rb). I found the site in an allocation census of 20 open-source apps on Rails main, made with Lowrail, my research project ([census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-r7-queue.md)). 16 workloads in 5 apps allocate fewer objects, for example about 250 fewer per Discourse topic list request.
