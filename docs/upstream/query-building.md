# QB1: how much of query building repeats, and what could be cached

Bet QB1, 2026-11-14. P-MAP ([p-map](p-map.md)) found that Active Record query building is 10.9% of real request time
on average across five apps, with no method above 0.42%. This bet asks how much of that work is repeated identically
on every request and could be cached: which queries go through `ActiveRecord::StatementCache` and which are built
from Relation → Arel → visitor → SQL each time, which stages the uncached path spends its time in, and which
caches Rails has tried. Same setup as P-MAP: Rails main
[50c54eed06](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b), Ruby 4.0.9 with YJIT,
production mode, the five census apps (Blog, Campfire, Fizzy, Lobsters, Mastodon) with P-MAP's 48 workloads, plus
CE2's 13 heavier pages ([`bench/upstream/ce2/`](../../bench/upstream/ce2/README.md)): index pages of 50 and 100
records, JSON at 100, forms and a save.

**Result.** 97% of query-building time goes to queries built from scratch each time; the statement cache serves
13–46% of reads but costs only 0.3% of a request. Almost all of the uncached work repeats: 95–100% of uncached reads
have the same SQL shape on the next identical request, and 81–100% of the shapes appear on more than one page. Only
the bind values change. But no single cache would capture it. The time is spread evenly over relation copying and
merging (2.8% of server time), association scopes (2.8%), `build_arel` (2.5%), the visitor (1.2%) and plumbing
(1.2%). No entry point (`where`, `find_by`, `exists?`, `count`, an association reader, a preload) costs more than 0.5%
of a request on average. Rails has never cached a chained relation; tenderlove's 2014 plan to do so was never built.

Two exact levers exist, both in association scopes:

* **The association reader builds its scope and throws it away when the statement cache serves the read**: up to
  2.0% of a request (Fizzy 3.7%, Mastodon 3.0%). This is open upstream as
  [rails/rails#59212](https://github.com/rails/rails/pull/59212) (bruno-costanzo, with matthewd's
  `global_current_scope` guard). Not ours, not rebuilt.
* **Every association scope merges a blank relation** (`klass.scope_for_association` for a model without a default
  scope). That merge does nothing and costs 5–6 objects. It is half of all merges in a request (8–26 per request).
  **MB1** skips it with one line; it is built as
  [`thomasklemm/merge-blank-relation`](https://github.com/thomasklemm/rails/tree/thomasklemm/merge-blank-relation):
  building `post.comments.where(approved: true)` is 19–21% faster in the interpreter, YJIT and ZJIT (A/A ≤ 2%), and
  whole association-heavy requests run 0.4–1.8% fewer instructions (A/A ≤ 0.11%).

Everything else that looks cacheable is either not exact (constant-looking scopes, compiled SQL for identical
shapes) or not small (a bound relation template per association).

## Method

* **Query census.** [`bench/upstream/qb/queries.rb`](../../bench/upstream/qb/queries.rb) runs each workload in-process
  (Rack::Test, as the census): 5 requests as warmup to fill the statement caches, then 10 measured ones. Every
  `sql.active_record` event (schema and transaction statements excluded) is classified by the path that produced
  it:
  * **statement cache**: `StatementCache#execute`, either the `find`/`find_by` fast path or the association reader
    cache.
  * **built per query**: an Arel AST compiled by `to_sql_and_binds` for this query.
  * **string**: SQL handed over as a string.
  
  It is also classified by origin: association reader (and why it skipped the cache), preloader, `find`/`find_by`
  (and why they fell back), calculations, relation loads, named scopes and writes. Each query's shape is its SQL
  with literals, binds and `IN` lists folded. Counters record relation copies, merges, `where` calls, scope bodies,
  `build_arel` and compiles per request. The census copies are P-MAP's: Blog, Fizzy and Lobsters in CE2's copies
  (`censusce2`, which add only CE2's data and `?per_page=`), Campfire and Mastodon in fresh copies with P-MAP's seeds.
* **Time.** P-MAP's profiler unchanged ([`p_map/profile.rb`](../../bench/upstream/p_map/profile.rb): Puma in
  process, Vernier wall mode at 500 µs, YJIT, 60 warmup and 200 measured requests per workload).
  [`qb/stages.rb`](../../bench/upstream/qb/stages.rb) takes the samples P-MAP charges to "AR: query building" and
  splits them by path, by stage, by origin and by entry point. The path is "statement cache" when
  `StatementCache#execute` is on the stack. The stage is the first match on the stack, in this order: visitor,
  binds, `build_arel`, association scope, `where` predicates, relation spawn/merge, other. The entry point is the
  outermost Active Record frame below the app's code.
  [`qb/mechanisms.rb`](../../bench/upstream/qb/mechanisms.rb) gives inclusive shares of mechanisms across all
  layers. Shares are of server time, as in P-MAP. As a check against P-MAP's independent run, query building comes
  out at 3.2 / 8.4 / 15.3 / 16.3 / 11.7% (Blog, Campfire, Fizzy, Lobsters, Mastodon), against P-MAP's 2.8 / 7.9 /
  16.0 / 16.5 / 11.5%. The difference is within P-MAP's A/A of 0.7 pp.
* **Prototype.** Callgrind instructions and objects per whole request through the census harness
  ([`p_map/request_ir.sh`](../../bench/upstream/p_map/request_ir.sh)): GC is off after `GC.start` (a fixed heap),
  base twice as A/A, interpreter and YJIT. A YJIT cell counts only when its window compiled no block. Also a
  benchmark-ips script in the format of a Rails PR body (one pinned core, best of 5, with A/A), and the Active
  Record suites.

Data: [`data/query-building/`](data/query-building/). It holds the query census (`queries.md`), the most frequent
uncached shapes per app (`shapes.txt`), the stage, origin and entry tables (`stages-census.md`, `stages-ce2.md`,
`stages.json`), the inclusive mechanisms (`mechanisms.md`) and the Callgrind cells (`callgrind.txt`).

## Cached and uncached queries

Queries per request, mean over each app's workloads.

| | Blog | Campfire | Fizzy | Lobsters | Mastodon | Blog CE2 | Fizzy CE2 | Lobsters CE2 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| statement cache | 0.8 | 1.3 | 6.8 | 3.1 | 12.4 | 0.3 | 4.7 | 1.8 |
| built per query | 1.0 | 5.1 | 32.5 | 16.7 | 14.6 | 1.8 | 53.3 | 9.8 |
| SQL string | 0.0 | 0.4 | 1.2 | 1.2 | 0.1 | 0.0 | 0.0 | 0.0 |
| **all** | 1.8 | 6.9 | 40.5 | 20.9 | 27.1 | 2.2 | 58.0 | 11.5 |

The built reads, by origin:

| Reads built per query | Blog | Campfire | Fizzy | Lobsters | Mastodon | Fizzy CE2 | Lobsters CE2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| count, `exists?`, `pluck`, `sum` | 0.2 | 0.6 | 5.4 | 6.4 | 1.8 | 7.3 | 1.5 |
| preload (`includes`, `preload`) | 0.2 | 0.0 | 5.0 | 4.1 | 6.5 | 6.0 | 4.5 |
| relation loads (`where` chains) | 0.2 | 0.0 | 0.0 | 1.8 | 2.4 | 0.0 | 2.2 |
| named scope loads | 0.0 | 0.4 | 1.8 | 1.1 | 0.4 | 3.0 | 0.8 |
| scoped `find_by`/`first`/`find` on a relation | 0.0 | 1.3 | 2.7 | 1.0 | 1.0 | 1.0 | 0.0 |
| association reader that skips the cache | 0.0 | 1.0 | 1.4 | 0.2 | 1.7 | 0.0 | 0.0 |
| `find`/`find_by` that fall back | 0.0 | 0.0 | 2.0 | 0.4 | 0.3 | 2.0 | 0.0 |
| Solid Cache entry reads | 0.0 | 0.0 | 11.5 | 0.1 | 0.0 | 34.0 | 0.0 |

* **The statement cache covers what it was built for.** `Model.find(id)` and `find_by(column: value)` hit it nearly
  always. Fallbacks are at most two per request: Fizzy's `Session.find_by(id:)` gets an Array value and its
  `Filter.find_by` runs inside a current scope; Mastodon's `Status` has a `default_scope`; Lobsters passes `nil`.
  Plain association readers hit it too (Fizzy 5.8 per request, Mastodon 2.3).
* **Association readers skip it for a reason.** Campfire's and most of Fizzy's skips are the reflection scopes of
  Active Storage (`has_one_attached`, `-> { where(name:) }`) and Action Text (`has_rich_text`). The others are app
  scopes: Fizzy's `Comment#reactions`, Lobsters' `Story#tags`, Mastodon's `Status#active_mentions`. Most of
  Mastodon's skips (1.4 per request) come from `Status`'s `default_scope`. A reflection scope is a lambda that Rails
  can't prove constant, so these stay uncached.
* **Most uncached reads aren't one-hop lookups at all.** They are counts and `exists?` on association proxies
  (`card.comments.any?`), scoped finders (`Current.account.users.find_by(identity:)`), named scopes and `where`
  chains, and preloads. The statement cache has no key for these.
* Fizzy reads Solid Cache entries (`SolidCache::Entry.read_multi`) 11 to 34 times per request. These are built
  through Arel like any query; that is Solid Cache's to change, not Rails'.
* Lobsters runs with prepared statements off (query log tags), which doesn't change which path builds a query, only
  that SQLite compiles every statement (P-MAP).

### Do the uncached reads repeat?

Reads built per query, over each workload's last two measured requests:

| | built reads per request | same shape on the next request | shape repeats within the request | binds differ within the request | shape also on another page | query cache hit |
|---|---:|---:|---:|---:|---:|---:|
| Blog | 0.7 | 100% | 0% | 0% | 67% | 0% |
| Campfire | 3.3 | 100% | 9% | 0% | 78% | 4% |
| Fizzy | 29.9 | 100% | 51% | 47% | 88% | 2% |
| Lobsters | 15.2 | 100% | 35% | 28% | 86% | 9% |
| Mastodon | 14.2 | 95% | 12% | 11% | 81% | 1% |
| Blog CE2 | 1.7 | 100% | 0% | 0% | 100% | 0% |
| Fizzy CE2 | 53.3 | 100% | 68% | 64% | 89% | 1% |
| Lobsters CE2 | 9.0 | 100% | 0% | 0% | 100% | 0% |

Every uncached query repeats with only bind values changing: the same request builds the same shapes, most shapes
appear on several pages (the session, the current user, the account, permission checks), and in Fizzy half the
shapes repeat within one request with other binds (per-card counts and `exists?`). In principle all of this could
come from a cache of compiled SQL. In practice the key is the problem (below).

## Where the time goes

Query building as P-MAP charges it (self time), split by path and stage, percent of server time (census workloads).
The stage is the first match on the stack, so a `where` inside an association scope counts as association scope.

| Stage | Blog | Campfire | Fizzy | Lobsters | Mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| relation spawn/merge (`spawn`, `initialize_copy`, `Merger`, `WhereClause`, scoping) | 0.95 | 1.80 | 2.87 | 5.23 | 3.25 | 2.82 |
| association scope (`AssociationScope`, `target_scope`, preloader scope) | 0.46 | 2.62 | 5.11 | 2.64 | 3.23 | 2.81 |
| `build_arel` | 0.32 | 1.90 | 3.68 | 3.93 | 2.76 | 2.52 |
| Arel visitor (`to_sql_and_binds`, `compile`) | 0.58 | 0.82 | 1.81 | 2.03 | 0.96 | 1.24 |
| other (load, finders, calculations, query cache, logs) | 0.47 | 0.83 | 1.13 | 1.61 | 0.89 | 0.99 |
| bind handling and type casting | 0.04 | 0.26 | 0.33 | 0.11 | 0.17 | 0.18 |
| `where` hash → predicates (outside association scopes) | 0.03 | 0.10 | 0.05 | 0.33 | 0.04 | 0.11 |
| *statement cache path (all stages)* | 0.33 | 0.10 | 0.34 | 0.46 | 0.40 | 0.32 |
| **query building** | 3.18 | 8.43 | 15.32 | 16.34 | 11.70 | 10.99 |

On CE2's heavier pages query building is smaller (Blog 2.8%, Fizzy 9.1%, Lobsters 6.6%; rendering 50–100 rows
dominates), with the same order of stages ([`stages-ce2.md`](data/query-building/stages-ce2.md)).

By origin, the built queries' time is: relations and named scopes 3.3%, association collection chains
(`card.comments.where`, `.exists?`, `.count`) 2.9%, association readers 1.7%, preloads 1.3%, calculations 1.0%,
`find`/`find_by` fallbacks 0.4%. By entry point it is flatter still: the largest are `Relation#each` (0.49%),
`QueryMethods#where` (0.44%) and `Relation#to_ary` (0.40%); `find_by` on a relation, `order`, `blank?`, `any?`,
`count`, `exists?` and the preloader are 0.2–0.3% each.

Bind type casting is 0.85% of a request inclusive, across all layers (Fizzy 2.2%, almost all in the app's own
`ActiveRecord::Type::Uuid#serialize`). The same app type makes Fizzy's Arel compile look large (3.8% inclusive): it
is the app's base36-to-hex conversion of every `IN` value, not the visitor.

Inclusive shares of the mechanisms behind the candidate caches (a sample counts for every mechanism on its stack, so
rows overlap):

| Mechanism | Blog | Campfire | Fizzy | Lobsters | Mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| association reader: scope built, then the statement cache used | 0.27 | 1.71 | 3.67 | 1.40 | 3.03 | 2.01 |
| `Association#scope`, every caller | 0.66 | 4.02 | 8.45 | 3.40 | 5.15 | 4.34 |
| `AssociationScope.scope` (once per owner record) | 0.29 | 2.48 | 4.31 | 1.76 | 2.71 | 2.31 |
| `CollectionProxy#scope` (chains, counts, `exists?` on has_many) | 0.02 | 1.96 | 4.29 | 1.32 | 0.56 | 1.63 |
| `Relation::Merger#merge` | 0.13 | 0.86 | 2.10 | 0.90 | 1.20 | 1.04 |
| named scope bodies (`_exec_scope`) | 0.00 | 1.50 | 0.89 | 1.00 | 1.42 | 0.96 |
| relation copies (`spawn`, `initialize_copy`) | 0.57 | 0.72 | 1.02 | 1.39 | 0.82 | 0.91 |
| preloader scope building | 0.17 | 0.61 | 0.75 | 0.93 | 0.49 | 0.59 |
| `default_scope` evaluation | 0.11 | 0.24 | 0.49 | 0.51 | 1.23 | 0.52 |
| `StatementCache#execute`, including the database | 4.23 | 1.12 | 5.78 | 4.46 | 5.83 | 4.28 |

Association scopes are the one concentrated part: 4.3% of a request is spent inside `Association#scope`, building
the same `WHERE fk = ?` relation once per owner record.

## What Rails does and has tried

* **StatementCache (2013, AdequateRecord 2014).** Noemj added the class in
  [#10152](https://github.com/rails/rails/pull/10152); tenderlove's AdequateRecord work cached `find`, `find_by` and
  association readers ([77b18d7ef4](https://github.com/rails/rails/commit/77b18d7ef4),
  [bd3b28f7f1](https://github.com/rails/rails/commit/bd3b28f7f1), merged without a PR in
  [ccdeb43d2e](https://github.com/rails/rails/commit/ccdeb43d2e)). His
  [post](http://tenderlovemaking.com/2014/02/19/adequaterecord-pro-like-activerecord.html) said the chained `where`
  form "can't benefit" yet and ended with the plan to "explore how we can integrate this cache to the 'chained
  where' form". That was never built.
* **Today's gates at 50c54eed06.** `find` falls back for several ids, a block, no primary key,
  `scope_attributes?` (a current scope or a default scope) and values that are `nil`, Array, Range, Hash, Relation
  or a record ([core.rb#L298-L309](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activerecord/lib/active_record/core.rb#L298-L309)).
  `find_by` falls back on the same scopes and values, on `composed_of` keys, on keys that aren't columns and on
  associations other than a non-polymorphic `belongs_to`
  ([core.rb#L311-L365](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activerecord/lib/active_record/core.rb#L311-L365)).
  The association reader skips the cache for a reflection scope anywhere in the chain, an eager-loading scope,
  `klass.scope_attributes?` and a default scope on the through model
  ([association.rb#L403-L408](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activerecord/lib/active_record/associations/association.rb#L403-L408)).
* **Each limit has a correctness reason.** Every narrowing since 2014 followed a wrong result:
  * the 2014 eager-loading skip ([#16788](https://github.com/rails/rails/pull/16788), references in a default scope
    ignored);
  * no cached `find` from a scope (`fb160f6e7d`, the parent id was baked in);
  * the through model's `default_scope` ([dc3230b156](https://github.com/rails/rails/commit/dc3230b156),
    [#20745](https://github.com/rails/rails/issues/20745), acts_as_tenant);
  * STI subclasses ([d333d85254](https://github.com/rails/rails/commit/d333d85254), re-enabled with invalidation in
    [#39588](https://github.com/rails/rails/pull/39588));
  * a private or dynamic `default_scope` method "baking the first evaluation of the default scope into the prepared
    statement" ([#59234](https://github.com/rails/rails/pull/59234), [#59237](https://github.com/rails/rails/pull/59237));
  * `ignored_columns` changes ([#59530](https://github.com/rails/rails/pull/59530)).
  
  The widenings came with invalidation or a proof: STI again with a descendants check (#39588), aliased attributes
  and `find_by(post: post)` (kamipo), and `default_order:` baked into the cached SQL
  ([#57632](https://github.com/rails/rails/pull/57632), "that should keep using the cache", rafaelfranca).
* **No cache across relations.** `Relation#arel` and `to_sql` are memoized per instance (`@arel ||=`), and `spawn`
  resets them, so every chain builds again. No PR or issue found proposes a cache of compiled relations, Arel or SQL
  by shape. The related attempts were rejected or stalled:
  * [#19349](https://github.com/rails/rails/pull/19349): proxies cached with `current_scope`.
  * [#29814](https://github.com/rails/rails/pull/29814): the `scope_for_create` cache was removed.
  * [#42643](https://github.com/rails/rails/pull/42643): reset of the memoized `@association_scope`, stale.
  * [#56635](https://github.com/rails/rails/pull/56635): byroot, "the gain isn't measurable, and the code noticeably
    harder, so I wouldn't merge".
* **Speedups instead of caches.** kamipo's and byroot's work made each stage cheaper instead of skipping it:
  * The predicate builder about 2× ([a1d236e931](https://github.com/rails/rails/commit/a1d236e931)).
  * `find_by(post: post)` cached ([dbda5febe4](https://github.com/rails/rails/commit/dbda5febe4)).
  * Allocation-free `ToSql#visit` ([#36483](https://github.com/rails/rails/pull/36483)).
  * The shared Arel dispatch cache ([#36645](https://github.com/rails/rails/pull/36645)).
  * `BoundSqlLiteral` ([#51139](https://github.com/rails/rails/pull/51139)) and n-ary `Or`
    ([#51492](https://github.com/rails/rails/pull/51492)).
  * In 2026: the merge and `WhereClause` trims, ours among them ([#59541](https://github.com/rails/rails/pull/59541),
    [#59556](https://github.com/rails/rails/pull/59556), kamipo's [#59572](https://github.com/rails/rails/pull/59572),
    [#59590](https://github.com/rails/rails/pull/59590), [#59612](https://github.com/rails/rails/pull/59612)), and
    `ToSql` 23% faster under YJIT ([#59404](https://github.com/rails/rails/pull/59404)).
* **Open now:**
  * [#59212](https://github.com/rails/rails/pull/59212): don't build the reader's scope when the cache serves it.
  * [#59569](https://github.com/rails/rails/pull/59569) (ours): `AliasTracker` only for through chains.
  * Issue [#54943](https://github.com/rails/rails/issues/54943), "Slow query generation".

## Ranking

By share × reach × exactness. "Share" is the mechanism's inclusive cost on the census workloads. "Would bring" is
what an exact change could remove, as a share of a request.

| # | Opportunity | Share (mean; range) | Exact? | Verdict | Would bring |
|---|---|---|---|---|---|
| 1 | Association reader: don't build the scope when the statement cache serves the read | 2.0%; 0.3–3.7% | yes, with a `global_current_scope` guard (matthewd's nested-through case) | **covered**: [rails/rails#59212](https://github.com/rails/rails/pull/59212), open since 2026-10-20, our census comment on it | up to 2.0% (upper bound: also counts scope building on the skip path); Fizzy 3.7%, Mastodon 3.0% |
| 2 | Skip merging a blank relation (`scope_for_association` of a model without a default scope, half of all merges) | 0.2–0.5% (8–26 merges × 5–6 objects per request) | yes: an empty values Hash merges nothing; a null relation keeps going through the merge | **built: MB1** | 0.4–1.8% of instructions on association-heavy pages (Fizzy card, Campfire message, Lobsters story); nothing on list pages that preload; overlaps #59212 on the cached reader path |
| 3 | A bound relation template per association (build `WHERE fk = ?` once per reflection, bind each owner) | `AssociationScope.scope` 2.3%, `CollectionProxy#scope` 1.6%; after #1 and #2 about 1–1.5% | not as a small change: a Relation is mutable, carries extensions and current scopes, and every proxy method would need the bound copy | structural; a design for a maintainer discussion, not a PR | 1–1.5% |
| 4 | Statement cache for `exists?`/`count`/`size` on a bare association | count and `exists?` origins 1.0%, proxy predicates (`any?`, `many?`, `include?`) 0.2–0.3% each | partly: the same gates as the reader plus `distinct`, `group`, counter caches and loaded targets | possible follow-up after #59212; most calls come with extra conditions | ≤0.5% |
| 5 | Cache constant scopes (`scope :published, -> { where(published: true) }`) and default scopes | `_exec_scope` 0.96%, `default_scope` 0.52% | no: a lambda can read the time, `Current`, its arguments or the owner, and Rails can't tell. The last two default-scope fixes (#59234, #59237) were exactly that bug | rejected; an opt-in API would be a feature, and the merge into the caller's relation remains | — |
| 6 | Avoid repeated visitor work for identical shapes (SQL by AST shape) | Rails' share of compile about 1% (Fizzy's 3.8% is its own UUID type) | the key needs a walk of the AST as costly as compiling it | rejected; the visitor was already made cheaper (#36483, #45934, #59404) | — |
| 7 | Cheaper `where` hash → predicate building | 0.11% outside association scopes | — | nothing left; the predicate builder was already halved | — |
| 8 | `find`/`find_by` fallbacks | 0.4% | they fall back on Array values, `current_scope` and default scopes by design | inherent | — |
| 9 | Preloader scope building | 0.59% | one scope per preloaded association per request; `IN` lists vary | inherent | — |

Outside Rails: Fizzy's `ActiveRecord::Type::Uuid` (base36 to hex for every bind) costs Fizzy 2.2% of a request, and
Solid Cache builds its entry read through Arel 11–34 times per request in Fizzy. Both are app or gem leads, not
pursued.

## MB1: skip merging a relation without values

Branch [`thomasklemm/merge-blank-relation`](https://github.com/thomasklemm/rails/tree/thomasklemm/merge-blank-relation),
head [`5dd4ff1529`](https://github.com/thomasklemm/rails/commit/5dd4ff1529b9f8f754e8988603d3794f8541af46), one
commit on rails/rails main 50c54eed06. Queue item [MB1](../../bench/upstream/pr-queue/items/MB1.md), `built`.

```{ .diff file="activerecord/lib/active_record/relation/merger.rb" }
       def merge
+        return relation if values.empty? && !other.null_relation?
+
         # Merging a relation's values into themselves is a no-op, and `unscope!`
         # would delete them while they are read.
         return relation if values.equal?(relation.values_for_merge)
```

**Why it is there.** `Association#target_scope` is
`AssociationRelation.create(klass, self).merge!(klass.scope_for_association)`. For a model without a default scope,
`scope_for_association` returns a fresh `relation` with no values. A merge with no values runs every `NORMAL_VALUES`
check, `merge_*` for selects, preloads, joins and clauses, and builds a new `WhereClause` (and having clause) from
two empty ones. Counted on the census workloads, `Merger#merge` runs 15–53 times per request, and half of the calls
come from `target_scope` (and `ThroughAssociation#target_scope`, once per model in the chain) with an empty values
Hash.

**Exactness.** Every `merge_*` step reads only the other relation's values (`values_for_merge`, which a
`CollectionProxy` delegates to its scope, so a proxy's values are never empty) and `null_relation?`. With empty
values each step does nothing, except `none!`. A null relation can have empty values (`Post.none.only(:order)`,
because `spawn` copies `@none`), so it keeps going through the merge. A differential probe
([`qb/merge_probe.rb`](../../bench/upstream/qb/merge_probe.rb), Lobsters' models) covered 288 cases:
`merge` and `merge!` with 9 receivers (plain, with where, `none`, a collection proxy, a proxy chain, an association,
after `.arel`, loaded) and 16 arguments (blank relations of the same and another model, `unscoped`, `all`, `none`,
`none.only(:order)`, `none.except(:where)`, `except(:where)` leftovers, `extending`, `where({})`, `unscope`,
`strict_loading(false)`, `readonly(false)`, a proxy, another model's where). It compared SQL, `null_relation?`,
value keys, extension methods, loaded records and the receiver. All cases are identical except one kind: `merge!` (internal, `:nodoc:`) of a blank relation
into a loaded or Arel-built receiver that has a where clause raised `UnmodifiableRelation` and now returns the
receiver unchanged. It raised only because the merge rewrote the where clause with the same predicates; the public
`merge` spawns first and is identical in every case.

**Tests.** Active Record on the head: `rake test:sqlite3` 10,375 runs, 0 failures (4 errors were the orb's missing
`sqlite3` CLI in `sqlite_rake_test.rb`, which passes once installed), `rake test:postgresql` (PostgreSQL 17)
11,298 runs, 0 failures, 0 errors.

**benchmark-ips** ([`qb/mb1_ips.rb`](../../bench/upstream/qb/mb1_ips.rb), [`mb1_ips.sh`](../../bench/upstream/qb/mb1_ips.sh)):
a `has_many` chain on SQLite in memory, one pinned core, best of 5 per tree, trees in a rotating palindromic order,
main run twice as A/A. Raw: [`data/query-building/mb1-ips.txt`](data/query-building/mb1-ips.txt).

| Ruby | `post.comments.where(approved: true)` main | A/A | MB1 | change |
|---|---:|---:|---:|---:|
| 4.0.9 interpreter | 34,425 i/s | −1.3% | 41,031 i/s | +19.2% |
| 4.0.9 YJIT | 123,331 i/s | −2.0% | 149,671 i/s | +21.4% |
| master 88ea6fd282 ZJIT | 116,928 i/s | +0.2% | 140,967 i/s | +20.6% |

Objects per chain: 32 → 27. With `.to_a` (the query and three records) the change is within its A/A in the
interpreter (+0.9%, A/A −1.8%) and ZJIT (−0.2%, A/A −0.2%), and +7.6% under YJIT (A/A −1.4%); the SQLite query
dominates there. No ZJIT loss.

**Whole requests, Callgrind** ([`data/query-building/callgrind.txt`](data/query-building/callgrind.txt)), interpreter,
fixed heap, instructions and objects per request:

| Workload | base | A/A | MB1 | change | objects |
|---|---:|---:|---:|---:|---:|
| Fizzy GET card | 78,483,514 | +0.11% | 77,081,828 | −1.79% | 13,098 → 12,904 |
| Campfire POST message (turbo_stream) | 44,504,393 | +0.01% | 43,977,273 | −1.18% | 10,948 → 10,883 |
| Lobsters GET story | 105,787,363 | +0.10% | 104,887,501 | −0.85% | 20,995 → 20,901 |
| Fizzy GET cards (100), CE2 | 209,725,160 | +0.01% | 208,795,267 | −0.44% | 23,779 → 23,650 |
| Lobsters GET newest (100), CE2 | 504,713,905 | −0.01% | 504,505,161 | −0.04% | 88,277 → 88,259 |
| Blog GET articles (100), CE2 | 136,469,614 | −0.02% | 136,493,803 | +0.02% | 18,386 → 18,390 |

Mastodon's `GET status context` is rejected, not rerun: its base and A/A differ by 26% (9,075 against 10,382
objects; the base request took another path). The list pages that preload their associations (Blog's and
Lobsters' index pages) build few association scopes, so they don't move.

The YJIT Callgrind cells (Fizzy GET card, Lobsters GET story, pinned Valgrind 3.19.0 with the 512 MiB brk
reservation, since stock Valgrind overflows the brk segment under YJIT) are being run; this section is updated with
them.

**Whole requests, benchmark-ips under YJIT** ([`qb/page_ips.sh`](../../bench/upstream/qb/page_ips.sh)): one census
request in process, 400 warmup requests, then benchmark-ips for 5 s, one pinned core, best of 5 per tree, base twice
as A/A. Raw: [`data/query-building/page-ips.txt`](data/query-building/page-ips.txt).

Being run; this section is updated with the results.

**Value.** Small and exact: one line, 5–6 objects per association scope, about a fifth of building a `has_many`
chain, up to 1.8% of the instructions of an association-heavy page. The open question for a maintainer is the one
byroot raised on #56635 (\"minor reductions in allocation no longer make a noticeable difference\"); here the gain
shows in wall time on the chain itself, which is why the body leads with it.

## What it means

* The repeated work is real but not cacheable as a unit. Every uncached query repeats with only binds changing,
  but it gets there through a chain of steps (scope bodies, merges, association scopes, `build_arel`, compile) that
  each look at mutable state. A cache key would have to cover the same state. That is why tenderlove's 2014 plan
  stopped at one-hop lookups, and why every later limit on the statement cache followed a wrong result.
* What is exactly redundant is in association scopes: building a scope that is thrown away (#59212) and merging a
  blank relation (MB1). They overlap on the association reader's cached path, where #59212 skips the whole scope;
  MB1 also covers collection chains, counts, `exists?` and readers that skip the cache. Together they remove 1–4%
  of an association-heavy request (Fizzy, Campfire, Mastodon) and nothing on list pages that preload.
* The remaining structural lever is an association scope built once per reflection and bound per owner (#3). It is
  worth a design discussion with a maintainer before any code.
