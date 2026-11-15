---
id: MB1
repo: rails/rails
kind: perf
area: Active Record, relation merging
reviewer: kamipo
branch: thomasklemm/merge-blank-relation
head: "ee000f16715dd3b701b403a34f163c0979895bb5"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "every association scope merges a blank scope_for_association relation into a relation without conditions (39-48% of all merges, 7-25 per request in Fizzy, Lobsters, Mastodon, Campfire); skipping it saves 5-6 objects each; benchmark-ips on building post.comments.where(...): interp +21.5% (A/A -0.7%), YJIT +14.9% (-2.1%), ZJIT +18.9% (-2.0%), reviewers +13-18%; Callgrind interp -0.81% to -1.40% Ir per request on Fizzy card, Lobsters story, Campfire message, -0.39% on Fizzy card list (A/A <= 0.11%), unchanged on preload-only pages"
rank: 26
risky: false
state: in-review
pr:
note: "QB1 (docs/upstream/query-building.md#mb1-skip-merging-a-blank-relation-into-a-relation-without-conditions). First head 5dd4ff1529 skipped every merge without values and kept duplicate where/having predicates (both reviews: changes). Final guard also requires a receiver without where/having conditions; differential probes identical to main (ours 352 cases, claude-code 1,477, opus 1,728). Test covers all three guards. AR suites on 0008bb1b1b (merger.rb as head): sqlite3 10,376 runs 0 F 0 E, postgresql 11,299 runs 0 F 0 E; merging_test on head 45 runs 0 F. Mastodon Callgrind rejected twice for path changes; direct count 10,379 -> 10,359 objects per request"
passes:
  - {reviewer: claude-code, head: "5dd4ff1529b9f8f754e8988603d3794f8541af46", orb: T-01a1dc8b-c8a7-72af-bc88-95d050defaed, date: 2026-11-15, verdict: changes, open: "Code fine, exactness claim wrong. Must-fix: (1) public merge not exact: WhereClause#merge (predicates | other.predicates) drops the receiver's duplicate predicates even for an empty other; the early return keeps them (Post.where(title: 'a').where(title: 'a').merge(Post.all), RANDOM() condition twice now runs twice; also merge(blank/unscoped/Comment.all/{}) and having); records identical in every deterministic case, association chains identical; body/commit/record must stop saying 'changes nothing'/'identical in every case'. (2) null-relation guard untested: rake test:sqlite3 passes with it removed; add none.only(:order)/none.except(:where) tests. UnmodifiableRelation change for merge! into loaded/.arel receiver with where (24 cases) acceptable (:nodoc:, main already inconsistent). Probe 1,477 cases (23 receivers x 32 args x merge/merge! + 5), 135 differ: 88+1 dedup, 24 UnmodifiableRelation, 22 private values_for_merge override. sqlite3 10,375 runs 0 F (5 E: sqlite3 CLI, pg gem). Allocations 5/6 per blank merge, chain 33 -> 28 confirmed. ips core 1: interp +20%, YJIT best 159.3k -> 191.7k (+20%); .to_a noise. Body: STI wording, 0.85 to 1.8 percent, mention Fizzy card list, drop or cite 'about half of the merges'. Worth the line (shape of #59572)."}
  - {reviewer: opus, head: "5dd4ff1529b9f8f754e8988603d3794f8541af46", orb: T-01a1dc8b-d1ad-770d-ae97-fb4487370a47, date: 2026-11-15, verdict: changes, open: "Code line fine. Must-fix: (1) blank merge was not a no-op: Array#| in WhereClause#merge deduplicated the receiver's repeated where/having predicates (bind, SQL string, having; merge and merge!); now they stay; rows same, SQL/binds differ; association paths unaffected; body/record wording wrong. (2) no test covers !other.null_relation?: rake test:sqlite3 10,375 runs green without it while Post.all.merge(Post.none.only(:order)) returns every row. (3) YJIT .to_a +7.6% does not reproduce (13,765 -> 13,686, -0.6%, A/A -1.7%); drop. Probe 1,728 cases (27 receivers x 32 args x merge/merge!), 112 differ: 84 dedup, 28 UnmodifiableRelation for merge! into loaded/.arel receiver with where (acceptable, :nodoc:). Tests: sqlite3 10,375 0 F (4 E sqlite3 CLI), merging 44/0/0, relation 59/0/0, hmt 185/0/0; one order-dependent failure reproduces on main (SEED=48538). Allocations 32 -> 27 and 5-6 per merge confirmed. ips core 1 best of 3: interp chain 29,270 -> 34,295 (+17.2%, A/A +0.5%), YJIT 88,766 -> 103,840 (+17.0%, A/A +4.0%), interp .to_a +0.4%. 'About half of merges' unverified. Nits: STI subclasses not blank; mention Fizzy card list -0.44%; mention #59212 overlap. Value: maintainer likely to take it."}
  - {reviewer: claude-code, head: "0008bb1b1bcb2d88f010dc20dfd46d57e4fdba66", orb: T-01a1dc8b-c8a7-72af-bc88-95d050defaed, date: 2026-11-15, verdict: nits, open: "Exactness holds: first-pass probe (1,477 cases) on main and 0008bb differs only in 12 lines from a contrived subclass overriding :nodoc: values_for_merge to {} with a where clause; the 88 dedup, HashMerger and 24 UnmodifiableRelation differences are gone; code reading agrees. Allocations chain 33 -> 28, post.comments.scope 18 -> 13, blank merge into blank receiver 5 -> 0, into receiver with where still 6. ips core 1: interp best +18% (A/A 3.5%), YJIT best +13%, means +16% (A/A 5.9%). sqlite3 10,376 runs 0 F (1 E: pg gem); merging_test 45/0/0; mutants: no null guard fails line 21, no conditions guard fails line 19. Commit accurate, no trailers, Thomas author/committer, no code comment. Nits: (1) line 20 assert_predicate Post.where(id: 1).merge(Post.none.only(:order)) never reaches the early return; use Post.all as receiver (applied in ef6f3ff44b, test-only, merger.rb identical). (2) two-line guard fine, no helper. Body on main 3dcad12 still old: title, 'changes nothing', both conditions, STI wording, cite 'about half', queue note; to check against cells once on main."}
  - {reviewer: opus, head: "ef6f3ff44ba372e6491dab286aba4a8de1a4dbd6", orb: T-01a1dc8b-d1ad-770d-ae97-fb4487370a47, date: 2026-11-15, verdict: nits, open: "One commit on 50c54eed06, merger.rb identical to 0008bb1. Probe 1,728 cases: 0 differ from main (dedup and UnmodifiableRelation differences gone). Chain 27.03 vs 32 objects; blank merge into fresh relation 1 object, into where relation 7 as main; hmt with duplicated default scope same SQL. Guard mutants: no null guard fails line 20, no where guard fails line 19, no having guard still passes (28 probe diffs: repeated HAVING kept). merging_test 45/0/0 on ef6f3ff4; rake test:sqlite3 10,376 0 F 0 E on 0008bb1; rubocop clean. ips core 1 best of 2 on 0008bb1: interp chain 28,185 -> 32,883 (+16.7%, A/A -0.8%), YJIT 83,036 -> 96,159 (+15.8%, A/A +2.0%); .to_a -1.7%/-1.0% noise; suggest 'about 16 to 21 percent' or remeasured numbers. Commit accurate, no trailers, Thomas, no comments. Nits: (1) add a having assertion so the third guard is tested (applied in ee000f1671: no having guard now fails line 21); (2) body on main 3dcad12 still describes 5dd4ff: new head/title, both conditions, .to_a within noise, Callgrind on new head, #59212 overlap. Value: maintainer likely to take it."}
---

# Skip merging a blank relation into a relation without conditions

`Association#target_scope` merges `klass.scope_for_association` into every association scope it builds: every
`has_many` chain (`post.comments.where(...)`, `.exists?`, `.count`), every association reader, and once per
model in a through chain. For a model without a default scope that isn't an STI subclass, that relation is blank,
and the association relation it is merged into has no conditions yet. Merging it adds nothing, but the `Merger`
still goes through every value and merges the where and having clauses, which allocates 5 to 6 objects each time.
In Fizzy, Lobsters, Mastodon and Campfire, that is 39 to 48 percent of the merges in a request.

This returns early when the other relation has no values and the receiver has no where or having conditions. A
relation can be null without values (`Post.none.only(:order)`), so a null relation still goes through the merge
and makes the receiver null. A receiver with conditions also still goes through it, because `WhereClause#merge`
drops duplicate predicates: `Post.where(id: 1).where(id: 1).merge(Post.all)` keeps one condition.

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
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before: post.comments.where(approved: true)    123.359k (± 1.8%) i/s    (8.11 μs/i) -    620.776k in   5.032258s
after:  post.comments.where(approved: true)    141.771k (± 3.4%) i/s    (7.05 μs/i) -    710.696k in   5.012994s
```

Building the chain allocates 32 objects before and 27 after, and without YJIT it is 17 to 21 percent faster. With `.to_a`
the SQLite query dominates and the difference is within noise.

In full requests of three open-source apps (a card page in Fizzy, a story page in Lobsters, posting a message in
Campfire), it is 56 to 170 fewer objects and 0.8 to 1.4 percent fewer instructions. Fizzy's card list runs 0.4 percent fewer
instructions; the Blog and Lobsters list pages, which preload their associations, don't change. With
[#59212](https://github.com/rails/rails/pull/59212), an association reader served by the statement cache would no
longer build its scope; this still covers collection chains, counts and readers that skip the cache.
