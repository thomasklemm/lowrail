---
id: MB1
repo: rails/rails
kind: perf
area: Active Record, relation merging
reviewer: kamipo
branch: thomasklemm/merge-blank-relation
head: "ee000f16715dd3b701b403a34f163c0979895bb5"
merged_head: "60147d2f28487ea77549aa7c6cb36fc25c1236c4"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
evidence: [docs/upstream/data/query-building/mb1-ips.txt, docs/upstream/data/query-building/callgrind.txt]
impact: "every association scope merges a blank scope_for_association relation into a relation without conditions (39-48% of all merges, 7-25 per request in Fizzy, Lobsters, Mastodon, Campfire); skipping it saves 5-6 objects each; benchmark-ips on building post.comments.where(...): interp +21.5% (A/A -0.7%), YJIT +14.9% (-2.1%), ZJIT +18.9% (-2.0%), reviewers +13-18%; Callgrind interp, same-round base and A/A: -1.39% Fizzy card, -0.78% Campfire message, -0.61% Lobsters story (A/A <= 0.06%), -0.39% Fizzy card list (first-round base), unchanged on preload-only pages; YJIT Callgrind Fizzy card -1.10% rejected (18 blocks compiled in the branch window)"
rank: 26
risky: false
state: merged
pr: 59810
note: "2026-11-27 (merged audit, docs/upstream/merged-audit.md): Rafael split the early-return condition into two private predicates with why-comments; exact; objects equal, interp +0.2-0.3% instructions, YJIT and ZJIT within noise (bench/upstream/merged-audit-2026-11-27/MB1-*). 2026-11-18 (rules review adopted after thermos-sol confirm, Lowrail 9f494264): shortened body (nits only); body PATCHed. 2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-rails-ruby.md): body corrected in this item only, not PATCHed (live body unchanged): 386 -> 317 words; the boundary paragraph shortened, the unclear '17 to 22 percent faster without YJIT', the .to_a noise line and the per-page list cut. QB1 (docs/upstream/query-building.md#mb1-skip-merging-a-blank-relation-into-a-relation-without-conditions). First head 5dd4ff1529 skipped every merge without values and kept duplicate where/having predicates (both reviews: changes). Final guard also requires a receiver without where/having conditions; differential probes identical to main (ours 352 cases, claude-code 1,477, opus 1,728). Test covers all three guards (null-relation nit applied in ef6f3ff44b, having nit in ee000f1671, test-only). AR suites on 0008bb1b1b (merger.rb identical to the head): sqlite3 10,376 runs 0 F 0 E, postgresql 11,299 runs 0 F 0 E; merging_test on head 45 runs 0 F. Mastodon Callgrind rejected twice for path changes; direct count 10,379 -> 10,359 objects per request"
passes:
  - {reviewer: claude-code, head: "5dd4ff1529b9f8f754e8988603d3794f8541af46", orb: T-01a1dc8b-c8a7-72af-bc88-95d050defaed, date: 2026-11-15, verdict: changes, open: "Code fine, exactness claim wrong. Must-fix: (1) public merge not exact: WhereClause#merge (predicates | other.predicates) drops the receiver's duplicate predicates even for an empty other; the early return keeps them (Post.where(title: 'a').where(title: 'a').merge(Post.all), RANDOM() condition twice now runs twice; also merge(blank/unscoped/Comment.all/{}) and having); records identical in every deterministic case, association chains identical; body/commit/record must stop saying 'changes nothing'/'identical in every case'. (2) null-relation guard untested: rake test:sqlite3 passes with it removed; add none.only(:order)/none.except(:where) tests. UnmodifiableRelation change for merge! into loaded/.arel receiver with where (24 cases) acceptable (:nodoc:, main already inconsistent). Probe 1,477 cases (23 receivers x 32 args x merge/merge! + 5), 135 differ: 88+1 dedup, 24 UnmodifiableRelation, 22 private values_for_merge override. sqlite3 10,375 runs 0 F (5 E: sqlite3 CLI, pg gem). Allocations 5/6 per blank merge, chain 33 -> 28 confirmed. ips core 1: interp +20%, YJIT best 159.3k -> 191.7k (+20%); .to_a noise. Body: STI wording, 0.85 to 1.8 percent, mention Fizzy card list, drop or cite 'about half of the merges'. Worth the line (shape of #59572)."}
  - {reviewer: opus, head: "5dd4ff1529b9f8f754e8988603d3794f8541af46", orb: T-01a1dc8b-d1ad-770d-ae97-fb4487370a47, date: 2026-11-15, verdict: changes, open: "Code line fine. Must-fix: (1) blank merge was not a no-op: Array#| in WhereClause#merge deduplicated the receiver's repeated where/having predicates (bind, SQL string, having; merge and merge!); now they stay; rows same, SQL/binds differ; association paths unaffected; body/record wording wrong. (2) no test covers !other.null_relation?: rake test:sqlite3 10,375 runs green without it while Post.all.merge(Post.none.only(:order)) returns every row. (3) YJIT .to_a +7.6% does not reproduce (13,765 -> 13,686, -0.6%, A/A -1.7%); drop. Probe 1,728 cases (27 receivers x 32 args x merge/merge!), 112 differ: 84 dedup, 28 UnmodifiableRelation for merge! into loaded/.arel receiver with where (acceptable, :nodoc:). Tests: sqlite3 10,375 0 F (4 E sqlite3 CLI), merging 44/0/0, relation 59/0/0, hmt 185/0/0; one order-dependent failure reproduces on main (SEED=48538). Allocations 32 -> 27 and 5-6 per merge confirmed. ips core 1 best of 3: interp chain 29,270 -> 34,295 (+17.2%, A/A +0.5%), YJIT 88,766 -> 103,840 (+17.0%, A/A +4.0%), interp .to_a +0.4%. 'About half of merges' unverified. Nits: STI subclasses not blank; mention Fizzy card list -0.44%; mention #59212 overlap. Value: maintainer likely to take it."}
  - {reviewer: claude-code, head: "0008bb1b1bcb2d88f010dc20dfd46d57e4fdba66", orb: T-01a1dc8b-c8a7-72af-bc88-95d050defaed, date: 2026-11-15, verdict: nits, open: "Exactness holds: first-pass probe (1,477 cases) on main and 0008bb differs only in 12 lines from a contrived subclass overriding :nodoc: values_for_merge to {} with a where clause; the 88 dedup, HashMerger and 24 UnmodifiableRelation differences are gone; code reading agrees. Allocations chain 33 -> 28, post.comments.scope 18 -> 13, blank merge into blank receiver 5 -> 0, into receiver with where still 6. ips core 1: interp best +18% (A/A 3.5%), YJIT best +13%, means +16% (A/A 5.9%). sqlite3 10,376 runs 0 F (1 E: pg gem); merging_test 45/0/0; mutants: no null guard fails line 21, no conditions guard fails line 19. Commit accurate, no trailers, Thomas author/committer, no code comment. Nits: (1) line 20 assert_predicate Post.where(id: 1).merge(Post.none.only(:order)) never reaches the early return; use Post.all as receiver. (2) two-line guard fine, no helper. Body on main 3dcad12 still old: title, 'changes nothing', both conditions, STI wording, cite 'about half', queue note; to check against cells once on main."}
  - {reviewer: opus, head: "ef6f3ff44ba372e6491dab286aba4a8de1a4dbd6", orb: T-01a1dc8b-d1ad-770d-ae97-fb4487370a47, date: 2026-11-15, verdict: nits, open: "One commit on 50c54eed06, merger.rb identical to 0008bb1. Probe 1,728 cases: 0 differ from main (dedup and UnmodifiableRelation differences gone). Chain 27.03 vs 32 objects; blank merge into fresh relation 1 object, into where relation 7 as main; hmt with duplicated default scope same SQL. Guard mutants: no null guard fails line 20, no where guard fails line 19, no having guard still passes (28 probe diffs: repeated HAVING kept). merging_test 45/0/0 on ef6f3ff4; rake test:sqlite3 10,376 0 F 0 E on 0008bb1; rubocop clean. ips core 1 best of 2 on 0008bb1: interp chain 28,185 -> 32,883 (+16.7%, A/A -0.8%), YJIT 83,036 -> 96,159 (+15.8%, A/A +2.0%); .to_a -1.7%/-1.0% noise; suggest 'about 16 to 21 percent' or remeasured numbers. Commit accurate, no trailers, Thomas, no comments. Nits: (1) add a having assertion so the third guard is tested ; (2) body on main 3dcad12 still describes 5dd4ff: new head/title, both conditions, .to_a within noise, Callgrind on new head, #59212 overlap. Value: maintainer likely to take it."}
  - {reviewer: opus, head: "ee000f16715dd3b701b403a34f163c0979895bb5", orb: T-01a1dc8b-d1ad-770d-ae97-fb4487370a47, date: 2026-11-15, verdict: approve, open: "Confirm pass on ee000f1671 with body and record at Lowrail 78ea3ab. One commit on 50c54eed06, Thomas author/committer, no trailers, no comments; merger.rb identical to 0008bb1; test diff from ef6f3ff only the repeated having assertion. Probe 1,728 cases: 0 differ from main. merging_test 45 runs 168 assertions 0 F; each guard removal fails it; main's merger.rb passes it; rubocop clean. Body claims checked: STI wording; one condition kept for duplicate where; 39-48% (campfire 38.7, fizzy 46.8, lobsters 48.3, mastodon 44.0) and 7-25 per request from merges.txt; 27.03 objects per chain; 5 objects saved per skipped merge; YJIT 123.359k -> 141.771k matches mb1-ips.txt (+14.9%, A/A -2.1%); 17 to 21 percent without YJIT (own +16.7%/+17.2%); .to_a within noise fair; 56-170 objects and 0.8-1.4% Ir match second-round cells; Fizzy card list -0.39%; #59212 overlap described correctly. Ready to open as far as this review goes."}
  - {reviewer: claude-code, head: "ee000f16715dd3b701b403a34f163c0979895bb5", orb: T-01a1dc8b-c8a7-72af-bc88-95d050defaed, date: 2026-11-15, verdict: nits, open: "Confirm pass with body at 78ea3ab; postable as is. One commit on 50c54eed06, no trailers, Thomas; diff from 0008bb test-only (activerecord/lib empty). Probe 1,477 cases byte-identical to 0008bb, 0 lines differ from main apart from the private values_for_merge override. merging_test 45 runs 0 F; each guard covered (null line 23, where line 18, having line 21). rake test:sqlite3 on ee000f1 10,376 runs 0 F (1 E pg gem). Body numbers all match cells: 39-48% from merges.txt, ips block verbatim (mb1-ips.txt 283/287, +14.9%, A/A -2.1%), interp +21.5%, ZJIT +18.9%, 32 -> 27 (own 33 -> 28), Callgrind second round -1.40/-0.81/-0.88% and 56-170 objects, card list -0.39%, dedup sentence, #59212 open. Optional nits: (1) '17 to 21 percent' -> '17 to 22 percent' or 'about 20 percent'; (2) second-round branch cells compared with first-round base/A/A; Lobsters 0008bb 20,884 objects vs 5dd4ff 20,901 shows drift, so the 0.4-point gap explanation is unverified; rerun base and A/A in the same round; (3) record: test sentence should name the having guard; reviewers' probes also found the UnmodifiableRelation change and the private override; say suites ran on 0008bb; move 'applied in ef6f3ff44b' out of my 0008bb open field."}
  - {reviewer: claude-code, head: "ee000f16715dd3b701b403a34f163c0979895bb5", orb: T-01a1dc8b-c8a7-72af-bc88-95d050defaed, date: 2026-11-15, verdict: nits, open: "Final confirm with body and record at 4ec311b; postable as is. All three earlier nits applied as described. Numbers recomputed from callgrind.txt: Fizzy card -1.385% (A/A +0.047%, -177 objects), Campfire -0.784% (-0.009%, -50), Lobsters -0.614% (-0.059%, -85); '50 to 177' and '0.6 to 1.4 percent' hold; card list -0.39% on first-round base fine (Fizzy base drift -0.02%); Lobsters drift -0.265%; 'overstated by up to 0.27 points' and '15-17 more objects' check; YJIT -1.099% (A/A +0.043%) correctly rejected (18 blocks). Optional nit: 'same round' is unclear when callgrind.txt files base/A/A under a separate third round; say rounds two and three ran in one session, or rerun the branch cells next to them."}
  - {reviewer: fable, head: "ee000f16715dd3b701b403a34f163c0979895bb5", orb: T-01a1dcf3-f208-7655-bf11-7773fa4733e4, date: 2026-11-15, verdict: approve, open: "Focused exactness pass with body at 874c106: no difference from main found, nothing open. Code reading: with empty values, a non-null other and a receiver without where/having, main's merge calls no setter (each merge_* step is guarded by the other relation's values, and a where/having clause is only assigned when the merged clause is non-empty), so no state change, no assert_modifiable!, no @arel reset; CollectionProxy delegates all 18 readers Merger calls on other to its scope, like values_for_merge; no Relation subclass overrides them; every merge! caller goes through Merger (target_scope, through chain, association_scope, join_scope, preloader, Model.all under another model's scope, all_queries_scope). Audit on main under the sqlite3 suite (10,375 runs, 0 F, 4 E sqlite3 CLI): of 18,140 merges the guard condition holds in 7,787 (42.9%: 5,708 target_scope, 2,036 through chain, 28 preloader, 9 join_scope, 6 in tests; 2,024 with another model, 91 into a receiver with other values), and in each one main's full merge raised nothing, called no setter and left every instance variable of the receiver, the other relation and a proxy's scope unchanged; as a control, the first head's guard reports the duplicate predicates, the null relation and UnmodifiableRelation. Probe 44,382 cases (78 receivers x 71 arguments x merge/merge! x 4 contexts: plain, Post.where.scoping, Post.unscoped block, Comment.none.scoping; plus 78 chains through spawn): STI, default scopes with where/extending/none/all, scopes returning all or nil, through and disable_joins scopes, proxies (new owner, extension block, unscope), blank AssociationRelation, aliased table, receivers loaded or after arel/to_sql/exists?/count/load_async, repeated select/joins/includes/preload/order/group/annotate/references, create_with, readonly/strict_loading true and false, hashes, procs, nil, a class; it compares result, receiver and other (values, null, extensions, scope_for_create, where_values_hash, SQL, ids, same object, modifiable before and after). Byte-identical on main and head (digest 15ba479b1a575e6d); guard mutants differ: first head 4,861 lines, no null guard 2,003, no where guard 1,045, no having guard 257. Body correctness sentences true on both trees: scope_for_association has no values for a plain model, [:where] for an STI subclass and a default scope; one blank merge into a receiver without conditions per scope build for has_many where/exists?/count and belongs_to/has_one readers (statement-cache path too), two for a two-model through chain, none for an STI subclass, a default-scoped target or preload; main's blank merge allocates 6 objects, the head 1 (5 saved); chain 32 -> 27; Post.none.only(:order) has values {} and null_relation? true and makes Post.all null; the repeated where keeps one condition. No code comment added. Scripts: this orb, .amp/in/orb-backup/mb1-fable/ (probe.rb, mutant.rb, guard_audit.rb, suite_audit.sh, audit_control.rb, body_check.rb, proxy_check.rb)."}
  - reviewer: thermos-sol
    orb: T-01a1ee60-a4df-75cc-9428-abffe636e31c
    head: "ee000f16715dd3b701b403a34f163c0979895bb5"
    date: 2026-11-18
    verdict: nits
    open: >-
      Both Thermos rubrics applied personally; body-only confirm. All four
      guards earn their place: values.empty? selects the no-work case,
      !other.null_relation? preserves none.only(:order), and empty receiver
      where/having clauses preserve predicate deduplication on both paths.
      No added comments or extra abstraction. Association target_scope and
      scope_for_association support the body; query-building.md and its recorded
      results back the object, reach and whole-request figures. The #59212
      boundary is relevant, not private-override trivia. Ruby 4.0.9 merging_test
      passes 45 runs/168 assertions. Raw cat-file: one commit on 50c54eed06,
      Thomas author/committer, author date 1794703470 +0000, no trailers.
      No must-fix. Optional: shorten the first paragraph further; the prose is
      still roughly 196 words before the reproducible script and tool output.
---

# Skip merging a blank relation into a relation without conditions

`Association#target_scope` merges `klass.scope_for_association` into every association scope it builds: every
`has_many` chain (`post.comments.where(...)`, `.exists?`, `.count`), every association reader, and once per
model in a through chain. For a model without a default scope that isn't an STI subclass, that relation is blank,
and the association relation it is merged into has no conditions yet. Merging it adds nothing, but the `Merger`
still goes through every value and merges the where and having clauses, which allocates 5 to 6 objects each time.
In Fizzy, Lobsters, Mastodon and Campfire, that is 39 to 48 percent of the merges in a request.

This returns early when the other relation has no values and the receiver has no where or having conditions. A null
relation still goes through the merge, since it can be null without values (`Post.none.only(:order)`), and so
does a receiver with conditions, because the merge drops duplicate predicates.

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

Building the chain allocates 32 objects before and 27 after. In full requests of Fizzy, Lobsters and Campfire,
it is 50 to 177 fewer objects and 0.6 to 1.4 percent fewer instructions. With
[#59212](https://github.com/rails/rails/pull/59212), an association reader served by the statement cache would no
longer build its scope; this still covers collection chains, counts and readers that skip the cache.
