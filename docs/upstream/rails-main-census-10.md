# Rails-main census 10: main against 8-1-stable and census 9, after kamipo's association fixes

Census 10 compares Rails main [`4500a94c34`](https://github.com/rails/rails/commit/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff)
(2026-11-17) with 8-1-stable [`aab611acd8`](https://github.com/rails/rails/commit/aab611acd84b4754e2403a9ab005532ccb0ed374)
and with census 9's main [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b)
(2026-11-14), on Ruby 4.0.9, census 9's 8 apps and its method. Nothing was built or posted: rails/rails is at
our 15 open-PR cap. Ranking follows tonight's PR retrospective: unreleased regressions against 8.1 first, then
changes that move a whole request on their own.

**Result.** Main is still faster than 8.1 in 67 of 70 workloads (median −5.95% of interpreted instructions, A/A median
0.12%; census 9 had −6.48%), and allocates a median 553 fewer objects per request. But **main is now slower than
census 9's main**: median +0.42%, 12 workloads slower beyond 1% (casa +1.14% median, up to +1.91%; writebook
+0.82%), against −1.78% for census 9 over census 8. Of main's +0.53% of all instructions, 0.26 points are lead A1 and
0.09 points lead C, both merged by kamipo on 2026-11-16 and 11-17.

Since census 9, main merged 22 first-parent commits ([list](data/rails-main-census-10/main-since-c9.txt)), nine of
them kamipo's Active Record merges of 2026-11-16 and 11-17. Two of them make every association load and every
association join more expensive, one adds to every through load and one to every `where` key: an association reader now builds five `WhereClause` differences and one Array to
check that its own scope did not remove the owner conditions, and a through association builds a second
`AliasTracker`. **That is new main regression against 8.1** in the interpreter: `author.posts` +3.6%, `has_one`
+5.3%, a polymorphic `as:` has_many +5.0%, `joins(:posts)` +5.6%, `joins` through +7.8% (A/A ≤ 0.1%). Under YJIT
main stays faster than 8.1, but these paths are +2.9% to +5.4% against census 9 in the JIT-flat cells. `WhereClause#-` is now the
largest allocation that main adds over 8.1: 56 of 70 workloads in all 8 apps, a median 0.56% of a request's objects
and up to 2.76% (casa's case edit page, +661 objects). An exact fast path for associations without a scope
recovers 70% of the instructions and 10 of the 11 objects (lead A1). 8-1-stable moved by two backports that change no
library code.

Every number is Callgrind instructions (Ir) per call or per request with census 8's patched Valgrind, a fixed heap
and an A/A twin. YJIT numbers count only where every measured window compiled nothing.

## Ranked leads

"8.1" is 8-1-stable `aab611acd8`, "c9" census 9's main `50c54eed06`. Shares are of all interpreted instructions or
objects per request in the workloads named. A/A is main against a second checkout of itself.

| # | Lead | Main file:line | Reach | Magnitude (A/A) | Against 8.1 | Existing PR / owner | Exact? | Next step |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **A1: owner-condition bookkeeping on every association scope** (#59825, #59836): five `WhereClause#-` and an Array per load, also on every `joins(:assoc)` | AR `association_scope.rb:62/68/131/162`, `reflection.rb:236–256` | 8/8 apps, 56 of 70 workloads; `WhereClause#-`, `#empty?` and `keep_owner_conditions` +0.258% of all Ir vs c9 (max +0.87% per request); objects median 0.56%, max 2.76% (casa case edit, +661) | `author.posts` +2.7%, has_one +3.4%, `as:` +3.9%, `joins` +3.4% / +4.7%, +11 objects each vs c9 (A/A ≤ 0.1%); ceiling recovers 70% of the instructions and 10 of 11 objects | **Regression:** has_many +3.6%, has_one +5.3%, `as:` +5.0%, `joins` +5.6%, `joins` through +7.8% (interp); YJIT still below 8.1 | kamipo, merged 2026-11-17, no reviews; none open on these files | Yes for associations without a scope item (the common case); probed: SQL, records, warnings, no user `==`/`hash` calls | **Build first** when a slot frees: skip the differences unless a scope item was merged. Or hand kamipo the repro |
| 2 | **A2: a second `AliasTracker` per through load** (#59823) | AR `through_association.rb:39–51` | 5/8 apps, 19 workloads (`AliasTracker.create` +4.2 objects); +0.017% of all Ir | `author.comments` +3.6%, +6 objects at #59823 | No (main still −10.6% vs 8.1) | Our open #59569 removes the same tracker cost elsewhere | Probably (unaliased chain: `aliased_table_for` returns `arel_table`); not proved | After A1; or fold into #59569's follow-up |
| 3 | **C: block forwarding in `type_caster`/`type_for_attribute`** (#59816) | AR `arel/attributes/attribute.rb:12`, `arel/table.rb:112`, `type_caster/map.rb:15` | Every `where` key (2–3 calls); +0.094% of all Ir vs c9 (max +0.28%) | `where(title:)` +1.1%, three keys +1.8%, `group.count` +0.8% and +5 objects (interp); YJIT flat except `group_count` | Not alone (where still −0.8% to −7.9% vs 8.1) | kamipo, merged 2026-11-16; our #59607 removed a block here before | Yes | Low; mention with A1 |
| 4 | **Lead 8 (census 9): `table_name_qualified_unscope_values` per merge** (#59709) | AR `query_methods.rb:1066` | 8/8 apps, 56 workloads, +13.4 objects | Small | Yes, small | None | Yes (early return) | Fold into A1 |

Not leads, or already taken:

* **`pluck` +5.8% against 8.1** (400k → 424k Ir, 99 → 83 objects; YJIT −6.7%). The growth is about 150 more calls
  per `pluck`, all of them `QueryIntent`, the schema-context chain and the Ractor-safe class attributes
  ([calls, 8.1](data/rails-main-census-10/pluck-calls-s81.txt), [c9](data/rails-main-census-10/pluck-calls-c9.txt)),
  which [rails-82-impact](rails-82-impact.md) and [main-regressions](main-regressions.md) judged deliberate. #59816
  adds +4.6k on top (lead C).
* Census 9's leads that are queued, open or parked: K1 (#59800, open), K6 (#59804, open), L3 (reviewed), L6 (built,
  waits for K1), lead 4 (by-name access after #59141, tenderlove plans index-based generated methods), lead 5
  (partial-select reads), lead 7 (closed). `attribute_set.rb` and `indexed_row.rb` are unchanged since census 9, so
  their numbers stand.
* `bound_sql_literal_for(opts.to_s, rest)` (#59829) replaces one line of our CW1 (#59642); `String#to_s` returns the
  receiver, so it adds one call and no object.

## Lead A1: owner-condition bookkeeping on every association scope

**Site.** #59825 (`f620da3544`, kamipo, merged 2026-11-17 01:07 UTC) and #59836 (`ebf746c795`, kamipo, merged
2026-11-17 12:38 UTC). Every association scope build on main now does this ([main
`association_scope.rb:62/68/131/162`](https://github.com/rails/rails/blob/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff/activerecord/lib/active_record/associations/association_scope.rb#L62),
[`reflection.rb:236–256`](https://github.com/rails/rails/blob/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff/activerecord/lib/active_record/reflection.rb#L236-L256)):

* `last_chain_scope` computes `key_clause = scope.where_clause - where_clause` and returns `[scope, key_clause]`;
* `add_constraints` computes `fixed_clause = scope.where_clause - where_clause - key_clause` before it merges the
  association's own scope, then calls `keep_owner_conditions(scope, key_clause, fixed_clause)`;
* `keep_owner_conditions` computes `key_clause - scope.where_clause` and `type_clause - scope.where_clause` and
  returns when both are empty;
* `join_scope` (every `joins(:assoc)`, `eager_load`, `where.associated`) computes `fixed_clause` and calls
  `keep_owner_conditions` with an empty key clause.

`WhereClause#-` is `WhereClause.new(predicates - other.predicates)`, two objects each. An association reader
therefore allocates 11 more objects than on census 9: five differences and the pair. The check exists for
association scopes that `unscope` or `rewhere` the owner key. When the reflection chain has no scope at all, nothing
can remove a condition, and every difference is empty by construction.

**Share per request.** 56 of 70 workloads, all 8 apps. `keep_owner_conditions` and `WhereClause#-` self are 0.137%
of all interpreted instructions, median 0.114% per workload, up to 0.484% (casa `GET casa case edit`), 0.345%
(writebook `GET leaf.md`), 0.330% (casa `GET supervisors`), 0.310% (casa `PATCH casa case`) and 0.300% (hackatime
`GET statusbar today`) ([per workload](data/rails-main-census-10/share-A1.tsv)). Objects: `WhereClause#-` is the
largest allocation main adds over 8.1 and over census 9 (+51.8 objects in the 56 workloads where it grew;
[8.1](data/rails-main-census-10/alloc-method-81-main.txt), [c9](data/rails-main-census-10/alloc-method-c9-main.txt)),
median 0.56% of a request's objects, up to 2.76% (casa case edit +661, casa `GET supervisors` +192, casa
`GET casa case` +275; [per workload](data/rails-main-census-10/reach-A1.txt)). Against census 9, A1's methods (`WhereClause#-`, `#empty?`, `#initialize`, `QueryMethods#where_clause`,
`keep_owner_conditions`, `add_constraints`, `last_chain_scope`) grew by +0.258% of all instructions, median +0.21%
per workload, up to +0.87% (casa case edit; [per workload](data/rails-main-census-10/attrib-c9-main.tsv),
[script](../../bench/upstream/census10/attrib.rb); the same split on main's A/A is ±0.002%). In casa that is a third
to a half of each slower page's growth (case edit +1.54% total, +0.87% A1; `PATCH casa case.json` +1.91%, +0.58%);
self instructions only, so the callees' share (`Array#-`, `Struct#==`) comes on top.

**Repro** ([`assoc_micro.rb`](../../bench/upstream/census10/assoc_micro.rb); `author.posts.reset; author.posts.to_a`
with three rows and no association scope), Ir / objects per call, interpreter:

| Case | 8.1 | c9 | main (A/A) | main vs 8.1 | main vs c9 | ceiling | ceiling vs c9 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `author.posts` | 644,108 / 148 | 649,466 / 96 | 667,130 / 107 (667,036) | **+3.6%** | +2.7% | 654,774 / 97 | +0.8% |
| `author.profile` (has_one) | 507,939 / 120 | 517,086 / 75 | 534,667 / 86 (534,569) | **+5.3%** | +3.4% | 522,286 / 76 | +1.0% |
| `comment.post` (belongs_to) | 523,779 / 121 | 494,836 / 75 | 512,684 / 86 (512,596) | −2.1% | +3.6% | 500,337 / 76 | +1.1% |
| `author.pictures` (`as:`) | 674,724 / 160 | 681,686 / 102 | 708,302 / 113 (707,658) | **+5.0%** | +3.9% | 689,218 / 103 | +1.1% |
| `author.comments` (through) | 920,052 / 217 | 776,229 / 141 | 822,711 / 158 (822,622) | −10.6% | +6.0% | 810,295 / 148 | +4.4% (lead A2) |
| `Author.joins(:posts).to_sql` | 340,709 / 127 | 347,937 / 101 | 359,753 / 107 (359,790) | **+5.6%** | +3.4% | 349,003 / 99 | +0.3% |
| `Author.joins(:comments).to_sql` | 530,195 / 182 | 545,914 / 139 | 571,605 / 151 (571,678) | **+7.8%** | +4.7% | 548,540 / 135 | +0.5% |
| `author.published_posts` (scoped) | 863,393 / 223 | 830,987 / 143 | 851,275 / 154 (851,026) | −1.4% | +2.4% | 851,764 / 154 | +2.5% (keeps the check) |
| `preload(:posts)`, `posts.count`, `posts.where(...)` | | | | −1.7% / +1.0% / −5.2% | ±0.1% | | unchanged |

YJIT, flat cells only ([raw](data/rails-main-census-10/raw/assoc/)): main is still faster than 8.1 everywhere, but
against census 9 `has_one` +2.9%, `as:` +4.0%, through +5.4%, `joins` +3.1% and +4.0%; the ceiling is within +0.7%
of census 9 on each. `association_scope_keeps_owner_conditions = true` (the 8.2 default for new apps) costs the same
as `false` (±0.1%, `main-keep` in the raw files): the work is the check, not the re-add.

Bisect over the first-parent merges ([req micro](data/rails-main-census-10/raw/req/)): `author.posts` 650,710 →
652,868 at #59816 (lead C), → 662,697 / +5 objects at #59825, → 668,702 / +6 objects at #59836; through
additionally 773,749 → 801,251 / +6 objects at #59823 (lead A2). Nothing else between census 9 and main moves these
cases.

**Exact change?** Yes, for the case that matters. The ceiling ([diff](data/rails-main-census-10/A1-ceiling.diff),
local only) keeps the where-clause snapshots (no allocation) and computes the differences only when
`add_constraints` merged at least one scope item; `keep_owner_conditions` returns at once when both clauses are
empty; `join_scope` skips it when there are no scope items. Against the checklist:

* Output: SQL and records identical for direct, scoped, `as:`, through, composite-key, `disable_joins` and join
  cases on main and the ceiling ([probe](../../bench/upstream/census10/a1_cpk_probe.rb),
  [main](data/rails-main-census-10/a1-cpk-probe-main.txt), [ceiling](data/rails-main-census-10/a1-cpk-probe-proto.txt)).
  The deprecation warning cannot fire without a scope item, so it fires in the same cases.
* Calls into user code (item 4): the skipped `Array#-` compares predicates either with themselves (`rb_eql`'s
  identity check) or with predicates on another column, where `Struct#==` stops at the attribute name before the
  bind value. A custom key type that counts `==`, `eql?` and `hash` sees no call on census 9, main or the ceiling in
  any case ([probe](../../bench/upstream/census10/a1_calls_probe.rb), [main](data/rails-main-census-10/a1-calls-probe-main.txt));
  the positive control (subtracting two independently built `where(author_id: 1)`) records one.
* Order: with a scope item the differences now run after the scope lambdas instead of between them; they compare
  Rails' own Arel nodes and record nothing, so the order is not observable. A reviewer may prefer keeping the
  `key_clause` line where it is and only skipping the rest; that costs one difference (2 objects) per load.
* **Built (2026-11-18)** as [A1](../../bench/upstream/a1/README.md) on main `e30c36266b`: the preloader and
  `disable_joins` already compute their differences only when needed; the full differential probe (preload, eager
  load, joins, STI, `as:`, scoped through, `unscope`/`rewhere`, both settings) and the association and relation tests
  on SQLite and PostgreSQL pass. Ruby master × ZJIT is still missing.

**Prior work.** None on the cost. #59825 and #59836 have no reviews or comments on performance (kamipo merged both
himself); #59836's description says the check exists for the `unscope(where: :user_id)` pattern. Our open #59569
(build the alias tracker only for through chains) touches `association_scope.rb` in `get_chain` and still merges
cleanly with main. **Collision risk is high:** kamipo made six commits to associations, reflection and
relations on 2026-11-16 and 11-17. None of his eight open PRs touches `association_scope.rb` or `reflection.rb`
(#58814 touches `alias_tracker.rb`, #58815 the preloader, #39863 `predicate_builder.rb`); wtn's #59826 touches the
through preloader.

## Lead A2: a second `AliasTracker` per through-association load

**Site.** #59823 (`5828589f4f`, kamipo, merged 2026-11-16): `ThroughAssociation#target_scope`
([main `through_association.rb:39–51`](https://github.com/rails/rails/blob/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff/activerecord/lib/active_record/associations/through_association.rb#L39-L51))
now calls `scope.alias_tracker` and, per through link, `aliased_table_for` and `klass_join_scope(table)` instead of
`klass.scope_for_association`. `Relation#alias_tracker` checks a connection out of the pool to read
`table_alias_length`, the cost our #59569 removes from direct associations.

**Share.** `AliasTracker.create` grew in 19 workloads of 5 apps (+4.2 objects, [c9](data/rails-main-census-10/alloc-method-c9-main.txt)).
In the CPU census `AliasTracker.create`, `aliased_table_for`, `klass_join_scope` and `target_scope` grew by +0.017%
of all instructions against census 9; the census apps load few through associations.

**Repro.** `author.comments` (has_many through posts): 773,749 → 801,251 Ir (+3.6%), 141 → 147 objects at #59823;
+100 Ruby and C calls per load, including the pool lease (`with_connection`, `LeaseRegistry#lease`) and the alias
counting. Main is still 10.6% below 8.1 here, so this is a regression against census 9 only.

**Exact change?** Probably, not designed yet. Only aliased chains need a tracker; when no table repeats in the chain,
`aliased_table_for` returns the model's own `arel_table`, and `klass_join_scope(arel_table)` builds the same scope
as `scope_for_association`. Proving that equivalence (STI type condition, default scopes, predicate builder) is the
work. **Prior work:** our #59569 (same tracker cost, other call site); kamipo's #59823 thread has no comments.

## Lead C: `type_for_attribute` forwards a block on every predicate

**Site.** #59816 (`c84a19e192`, kamipo, merged 2026-11-16): `Arel::Attributes::Attribute#type_caster(&block)`,
`Arel::Table#type_for_attribute(name, &block)`, `TableAlias#type_for_attribute` and
`TypeCaster::Map#type_for_attribute(name, &block)` now take and pass a block, so a calculation can fall back to the
result's column type. `PredicateBuilder` calls `type_caster` two or three times per `where` key, with no block.

**Repro** ([`rel_micro.rb`](../../bench/upstream/census10/rel_micro.rb)), interpreter, #59816's parent → merge:
`Post.where(title:).to_sql` 195,296 → 197,392 (+1.1%), three keys 348,811 → 355,129 (+1.8%), `pluck` 418,646 →
423,224, `group(:author_id).count` 488,419 → 492,467 and 135 → 140 objects (the `proc` per group column); calls
and objects otherwise identical. A pure-Ruby probe on 4.0.9 puts a nil `&block` hop at about 360 Ir more than a
plain call. **YJIT: no cost** (`where_hash3` +0.1%, flat), except `group_count` +4.4k Ir and +5 objects.

**Share.** +0.094% of all instructions against census 9, median +0.07% per workload, up to +0.28% (casa case edit,
supervisors; writebook's `Turbo::Streams::BroadcastJob` +0.27%). Since YJIT is the production reference and the interpreted cost is about 0.3–0.5 µs per `where`
key, this ranks low.

**Exact change?** Yes: forward the block only when one is given (`block ? relation.type_for_attribute(name, &block) :
relation.type_for_attribute(name)` still has a block parameter; `yield`/`block_given?` keeps the method simple), or
let the two calculation call sites pass the fallback themselves. **Prior work:** our #59607 (merged 2026-11-04)
replaced a block in this chain with a `fetch` default; kamipo's #59816 has no comments.

## Carried over from census 9

* **Lead 8, `table_name_qualified_unscope_values` on every merge** (#59709): still +13.4 objects per workload in 56
  of 70 workloads against 8.1. `AssociationScope#add_constraints` calls it per scope item and `Merger#merge` per
  merge. An early return for empty `unscope_values` is exact. Not queued; below the bar alone, natural to fold into
  A1 if kamipo takes that.
* **Hot sites on main** ([rank](data/rails-main-census-10/rank-c10m-method.txt)): `TagBuilder#append_tag_option`
  0.92%, `String#blank?` 0.74%, `IsolatedExecutionState.[]` 0.73%, `TagBuilder#tag_options` 0.69%,
  `Merger#merge` 0.55% of all interpreted instructions: all ranked and judged in censuses 8 and 9, none new.


## Main against 8-1-stable and census 9 in the census

**CPU against 8.1** (`c10s` against `c10m`/`c10m2`, interpreter, 70 workloads, all JIT-flat;
[cells](data/rails-main-census-10/cpu-81-main-cells.txt), [methods](data/rails-main-census-10/cpu-81-main-method.txt),
[net by method](data/rails-main-census-10/cpu-net-81-main-method.txt)):

| App | Workloads | Median main vs 8.1 | Range | A/A median \|Δ\| |
| --- | ---: | ---: | --- | ---: |
| blog | 10 | -12.01% | -24.86% … -5.30% | 0.07% |
| casa | 10 | -7.76% | -24.44% … -0.12% | 0.10% |
| codetriage | 7 | -3.20% | -12.73% … +5.04% | 0.12% |
| hackatime | 11 | -5.40% | -9.42% … -2.23% | 0.07% |
| pingcrm | 8 | -5.48% | -6.49% … -1.77% | 0.11% |
| react-starter-kit | 8 | -5.92% | -8.40% … -4.75% | 0.21% |
| redprints-cfp | 8 | -5.99% | -9.46% … -1.64% | 0.57% |
| writebook | 8 | -6.50% | -9.22% … -2.71% | 0.05% |

All 70 workloads: median -5.95%; 67 faster and 2 slower beyond 1%; A/A median |Δ| 0.12%

The two slower workloads are codetriage `perform SendSingleTriageEmailJob` (+5.04%, the debug-logged event reporter,
judged deliberate in [main-regressions](main-regressions.md); +4.03% in census 9) and codetriage `PATCH repo
subscription` (+1.09%, A/A 0.00%). The methods that grew against 8.1 are census 9's list (#59141's attribute set,
`append_tag_option`, `QueryIntent`, `WeakKeyMap`, `association_route`, schema context) plus two new rows from lead
A1: `WhereClause#empty?` +0.111% and `WhereClause#-` +0.107% of all 8.1 instructions, 8 apps each. `PG::Connection#get_result`
(+0.585%, 3 apps) is work that moved out of `perform_query` (−0.48% in the same apps), not new cost.

**CPU against census 9** (`c10c9`; [cells](data/rails-main-census-10/cpu-c9-main-cells.txt),
[net by method](data/rails-main-census-10/cpu-net-c9-main-method.txt), [by file](data/rails-main-census-10/cpu-net-c9-main-file.txt)):

| App | Workloads | Median main vs c9 | Range | A/A median \|Δ\| |
| --- | ---: | ---: | --- | ---: |
| blog | 10 | -0.04% | -0.41% … +0.76% | 0.07% |
| casa | 10 | +1.14% | +0.01% … +1.91% | 0.10% |
| codetriage | 7 | +0.58% | -0.03% … +0.99% | 0.12% |
| hackatime | 11 | +0.28% | -1.22% … +0.65% | 0.07% |
| pingcrm | 8 | +0.21% | -0.46% … +0.53% | 0.11% |
| react-starter-kit | 8 | +0.34% | +0.04% … +2.71% | 0.21% |
| redprints-cfp | 8 | +0.74% | -0.25% … +1.73% | 0.57% |
| writebook | 8 | +0.82% | +0.64% … +1.37% | 0.05% |

All 70 workloads: median +0.42%; 1 faster and 12 slower beyond 1%; A/A median |Δ| 0.12%

The two outliers in react-starter-kit and redprints-cfp `GET home` (+2.71%, +1.73%) carry the same size of A/A
(−2.74%, −1.22%) and are noise. Every other slower workload loads associations; the net method list is led by
`WhereClause#-` (+0.116%), `QueryMethods#where_clause` (+0.050%), `Attribute#type_caster` (+0.041%) and
`Table#type_for_attribute` (+0.039%).

**Allocations** (`script/census`, [8.1](data/rails-main-census-10/alloc-81-main.txt),
[c9](data/rails-main-census-10/alloc-c9-main.txt)): A/A median −0.1 / −0.1 objects (interpreter / YJIT). Main
against 8.1: median −553 / −583 objects, all 70 workloads lower, 11 SQL digests changed (12 in census 9). Main
against census 9: median −17.7 / −19.2 objects, 59 lower and 5 higher. The growth is lead A1: `WhereClause#-` and
`last_chain_scope` are the only methods that grew in more than 5 apps; what shrank was not attributed ([methods](data/rails-main-census-10/alloc-method-c9-main.txt)).

### Our merged changes

[`ours_survive.rb`](../../bench/upstream/census9/ours_survive.rb) against main ([output](data/rails-main-census-10/ours-survive.txt)):
#59809 (merged 2026-11-15, "query"/"queries" in the request log line) keeps its line. #59642 (CW1) keeps 1 of 2
lines: #59829 changed `bound_sql_literal_for(opts, rest)` to `opts.to_s` (no cost). #59634 keeps 23 of 26 lines
after kamipo's and Hartley McGuire's edits. Everything census 9 listed as kept still is.

## Method and pins

* **Rails:** main [`4500a94c34`](https://github.com/rails/rails/commit/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff)
  (merge of #59845, fetched 2026-11-17 22:30 UTC). 8-1-stable [`aab611acd8`](https://github.com/rails/rails/commit/aab611acd84b4754e2403a9ab005532ccb0ed374)
  (#59839; census 9's `71e963ed1b` plus two backports with no `lib/` change). Census 9's main
  [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b). First-parent points
  for the attribution: `e9c26763e2`, `78039119db`, `d0eec80537`, `23cac06228` (#59816), `ed17c90871`, `667831f578`
  (#59821), `3d4914e1b2`, `a5203b3d4d` (#59823), `a58ae65dd0` (#59825), `04988cc35d`, `4f00fbc946`, `f0c9373b05`,
  `ff53633d52` (#59836).
* **Ruby** 4.0.9 (`3e93b23afc`), interpreter and `--yjit`. ZJIT was not run (nothing was built).
* **Corpus:** census 9's 8 apps (blog, writebook, codetriage, pingcrm, redprints-cfp, react-starter-kit, casa,
  hackatime) with census 7's overlays ([`setup.sh`](data/rails-main-census-10/setup.sh)). 70 workloads: hackatime's
  `perform DashboardRollupRefreshJob` listed at setup but recorded no measurement in any label, so every comparison
  leaves it out (census 9 had 71).
* **Census runs** ([`run_census.sh`](data/rails-main-census-10/run_census.sh), [`heap.sh`](data/rails-main-census-10/heap.sh)):
  allocations `a10m`/`a10m2`, `a10s`/`a10s2`, `a10c9` (interpreter and YJIT, `--jobs 2`); CPU `c10m`/`c10m2`, `c10s`,
  `c10c9` (interpreter, `--jobs 2`). As in census 9, the CPU comparison uses main's A/A for both sides of every cell.
  On this orb (2 cores, 4 GB) the allocation labels took 25 minutes and each CPU label about 40.
* **Comparison:** `script/census compare`, `bench/upstream/main_regressions/method_diff.rb alloc`, census 9's
  [`cpu_regress.rb`](../../bench/upstream/census9/cpu_regress.rb) and [`cpu_net.rb`](../../bench/upstream/census9/cpu_net.rb),
  and [`site_reach.rb`](../../bench/upstream/census10/site_reach.rb) for the objects at given lines.
* **Micros:** [`assoc_micro.rb`](../../bench/upstream/census10/assoc_micro.rb), [`rel_micro.rb`](../../bench/upstream/census10/rel_micro.rb)
  and census 9's [`req_micro.rb`](../../bench/upstream/census9/req_micro.rb), run by
  [`sweep.sh`](../../bench/upstream/census10/sweep.sh) and tabulated by [`table.rb`](../../bench/upstream/census10/table.rb).
  100 calls after 100 warmup calls; `IrCount` reads the exact Ir under census 8's patched Callgrind
  (`--instr-atstart=no`); objects from `GC.stat` with GC off in the window; under YJIT, warmup until three windows in a
  row compile nothing (at most 30), and a cell whose measured window compiled anything is "not flat" and not used.
  Each tree runs in its own process; main and `main2` are the A/A. `KEEP=1` sets
  `association_scope_keeps_owner_conditions = true`, the 8.2 default for new apps.
* **Fixed heap:** `RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000` for every run.
* **Ceiling prototype** for lead A1: a local patch on main ([diff](data/rails-main-census-10/A1-ceiling.diff)), not
  a branch; it measures what an exact fast path could recover, nothing more.
* **Receipts:** [data/rails-main-census-10](data/rails-main-census-10/) (micro raw output in `raw/`). Orb scripts
  and notes in `.amp/in/orb-backup/`.

## Limits

* No ZJIT and no YJIT CPU census; YJIT claims come from the micros.
* The 8 apps include no MySQL app and none on `load_defaults "8.2"`, so the census runs
  `association_scope_keeps_owner_conditions = false`; the micro shows `true` costs the same.
* Lead A1's exactness is argued and probed for direct, polymorphic and through associations with and without a
  scope; composite keys and `disable_joins` are not probed yet.
