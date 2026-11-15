---
id: MB1
repo: rails/rails
kind: perf
area: Active Record, relation merging
reviewer: kamipo
branch: thomasklemm/merge-blank-relation
head: "5dd4ff1529b9f8f754e8988603d3794f8541af46"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "every association scope merges a blank scope_for_association relation (half of all merges, 8-26 per request); skipping it saves 5-6 objects each; benchmark-ips +19-21% on building post.comments.where(...) in interpreter, YJIT and ZJIT (A/A <= 2%); Callgrind -0.4% to -1.8% Ir per request on association-heavy pages of Fizzy, Lobsters and Campfire (A/A <= 0.11%), unchanged on preload-only pages"
rank: 26
risky: false
state: built
pr:
note: "QB1 (docs/upstream/query-building.md#mb1-skip-merging-a-relation-without-values). Differential probe: 288 merge/merge! cases identical except merge! of a blank relation into a loaded/arel-built receiver with a where clause no longer raises UnmodifiableRelation. AR suites on the head: sqlite3 10,375 runs 0 F (4 E = no sqlite3 CLI, pass once installed), postgresql 11,298 runs 0 F 0 E. Mastodon Callgrind cohort rejected (A/A +26%)"
passes: []
---

# Skip merging a relation without values

`Association#target_scope` merges `klass.scope_for_association` into every association scope it builds: every
`has_many` chain (`post.comments.where(...)`, `.exists?`, `.count`), every association reader, and once per
model in a through chain. For a model without a default scope that relation is
blank. Merging it changes nothing, but the `Merger` still goes through every value and merges the where and having
clauses, which allocates 5 to 6 objects each time. In real apps that is about half of the merges in a request.

This returns early when the other relation has no values. A relation can be null without values
(`Post.none.only(:order)`), so a null relation still goes through the merge and makes the receiver null.

```ruby
require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "rails", github: "rails/rails", branch: "main"
  gem "sqlite3"
  gem "benchmark-ips"
end

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :posts
  create_table :comments do |t|
    t.references :post
    t.boolean :approved, default: true
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

post = Post.create!
3.times { post.comments.create! }

Benchmark.ips do |x|
  x.report("post.comments.where(approved: true)") { post.comments.where(approved: true) }
  x.report("post.comments.where(approved: true).to_a") { post.comments.where(approved: true).to_a }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before: post.comments.where(approved: true)        123.331k (± 4.0%) i/s    (8.11 μs/i) -    620.823k in   5.033791s
after:  post.comments.where(approved: true)        149.671k (± 3.1%) i/s    (6.68 μs/i) -    748.573k in   5.001472s

before: post.comments.where(approved: true).to_a    22.133k (± 5.4%) i/s   (45.18 μs/i) -    112.863k in   5.099307s
after:  post.comments.where(approved: true).to_a    23.808k (± 4.0%) i/s   (42.00 μs/i) -    120.411k in   5.057535s
```

Building the chain allocates 32 objects before and 27 after. Without YJIT it is 19 percent faster, and on Ruby
master with ZJIT 21 percent.

In full requests of three open-source apps (a card page in Fizzy, a story page in Lobsters, posting a message in
Campfire), it is 65 to 194 fewer objects and 0.9 to 1.8 percent fewer instructions. List pages that preload their
associations don't change.
