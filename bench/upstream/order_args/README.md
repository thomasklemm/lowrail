# Order argument micro-benchmark (rails/rails#59577)

`bench.rb` measures the per-call cost of Active Record `order` on an in-memory
SQLite database, against any Rails checkout given in `RAILS`. Cases:

| case | code |
|---|---|
| `order_id` | `Post.order(:id).to_a` |
| `order_hash` | `Post.order(created_at: :desc).to_a` |
| `assoc_order` | `author.posts.order(:id).to_a` |
| `pre_id` | `preprocess_order_args([:id])` |
| `pre_hash` | `preprocess_order_args([{ created_at: :desc }])` |

Objects and wall time (best of 7, after 500 warm-up calls):

```sh
cd ~/rails && RAILS=$PWD bundle exec ruby [--yjit|--zjit] path/to/bench.rb stats pre_id
```

Instructions per call under Callgrind, with GC disabled during the measured
calls (N calls minus 0 calls, divided by N):

```sh
path/to/ir.sh ~/rails pre_id            # interpreter
path/to/ir.sh ~/rails pre_id --yjit
BUNDLE= path/to/ir.sh ~/rails pre_id --zjit   # Ruby with the gems installed, no bundle exec
```

Run the base checkout twice as an A/A pair and compare the change against
both. Wall time of whole queries varies by several percent between A/A runs;
Ir and object counts are stable.
