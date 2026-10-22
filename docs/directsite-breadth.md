# Bet F2: stop DirectSite breadth at the screen

**No new supported shape, runtime change, or speed claim.** The bounded
EventSummary specimen fails exact-response admission and saves only about
30 objects on the card-show request. Discard the specimen; retain the
diagnostic census and [machine-readable evidence](directsite-breadth.json).
This does not reverse Y's separate `/buckets` result or integration path.

Base: [Y's shared production/test connection rebind](https://github.com/thomasklemm/lowrail/commit/2363958b4b8d12696852bce3667b7b7f904eaeb1).
Screen harness: [screen-platform](https://github.com/thomasklemm/lowrail/commit/94f3f321c8c73a3814f3828bb299f26ba31e2ab0),
used in a detached worktree, not merged here. Ruby 4.0.7, Rails 8.1.4,
Bundler 4.0.20. Y's branch and runtime files are unchanged.

## Why zero hits is not an admission census

`ARRequestSites.install` is an external, handwritten experiment, not a
general call-site compiler. For Fizzy it installs just the pinned
`buckets/_bucket.html.erb` expression. The users, workflows, filtered,
notifications and card-show GETs do not execute that expression. Their zero
hits primarily mean **no installed program**, not that the same query was
rejected by a guard. Campfire already has its separate room probe/page
program; message pagination, sidebar and search are not installed sites.
There is no Writebook or CASA installer arm.

The remaining shapes below are potential new programs, not safe cases to
admit by relaxing existing checks. Keep native non-creating record-holder
checks, effective methods/visibility, schema/reflections/scopes, SQLite
prepared/config equality and the shared PID/connection/visitor rebind.

There is a separate **guard-closure prerequisite**, not just a breadth
problem. [Y's follow-up](https://ampcode.com/threads/T-01a16381-6622-777e-b606-383a6516fa3e)
at [baseline d3d3548](https://github.com/thomasklemm/lowrail/commit/d3d3548fd5dfa3d711c588f433c4dab64a5abb2c)
replaced transitive `ActiveRecord::Relation#_exec_scope` in memory, calling
the original then adding `where(id: -404)`. On natural `GET /buckets`,
off-A/off-B responses and ordered SQL matched; on changed both while still
claiming two DirectSite hits and zero fallbacks (shadows off, YJIT active).
F's handwritten inventory omits that dependency. This is Y's independently
reported counterexample, not an F2 rerun. Future widening also requires
**compiler-derived transitive guard closure**; adding just this one method
to the manual list would not establish a complete purity/evaluation-order
certificate. The historical bucket price is not production exactness proof.

## Construction census, ranked where measured

`bench/experiments/directsite_breadth_census.rb` observes naturally executed
calls: 20 warm GETs per route, then one diagnostic GET, without YJIT.
It counts outermost selected AR builder/named-scope/association-reader
calls, subtracts its observer allocations, and records result types and
SQL events inside each span. These are **inclusive diagnostic pools, not
removable objects or achieved savings**. Rows with SQL include real rows,
callbacks and/or preloads; they must not be priced as construction.
Disjoint constructor spans at one site may be added; routes and overlapping
terminal totals may not. The export retains every row and ordered SQL.

Run the census with existing seeds from `fizzy_link_fixture.rb` or
`campfire_scenario.rb prepare`, always into a new private output:

```sh
BUNDLE_GEMFILE="$PWD/.corpus/fizzy/Gemfile" BUNDLER_VERSION=4.0.20 \
  mise exec ruby@4.0.7 -- ruby -rbundler/setup \
  bench/experiments/directsite_breadth_census.rb \
  "$PWD/.corpus/fizzy" "$PRIVATE/fizzy-seed" fizzy "$PRIVATE/new-census.json"
# Campfire: substitute its app/Gemfile, seed and the workload name campfire.
```

| Rank | New shape and route | Observed construction objects/request | Boundary that prevents simple reuse |
|---|---|---:|---|
| 1 | Fizzy filtered: `Filter::Resources#buckets`, hash/array `where` | 2,349 in 31 `where` calls, no SQL inside | `creator.buckets.where(id: super.ids)` combines two HABTM/authorization paths and live ID arrays. Preserve their reads, joins, loaded state and empty-list behavior; not a fixed owner foreign-key substitution. |
| 2 | Fizzy card show: `EventSummary#main_summary`, scoped association + `non_boosts` | 1,113 = scope 612 + named scope 174 + reader 171 + Arel 156 | Six evaluations; cached association scope on repeated use. This is the bounded specimen screened below, not a 1,113-object saving. |
| 3 | Fizzy card show: `Event::Particulars#assignees`, hash/array `where` | 608 in four calls, no SQL inside | Live particulars IDs and account users; parameter cardinality/type and association/authorization continuation are not certified by the bucket site. |
| 4 | Fizzy users: `Current.account.users.active` + load Arel | 279 = scope 109 + active 115 + reader 13 + Arel 42 | Account association, active scope and ordinary load continuation; avatar attachment readers allocate another 642 **including three SQL loads**, not removable construction. |
| 5 | Campfire sidebar: through-association query Arel | 268 in one `build_arel` span | Membership/room through joins, live room exclusions and limit; preserve loaded memberships and the normal preloader. Other constructor spans remain separate in the export. |
| 6 | Campfire search: `reachable_messages.search(query).last(100)` constructors | 264 = through scope 211 + search 40 + reader 11 + limit 2 | Live FTS argument/joins, reachability and last/reverse ordering. Arel and row-loading spans are separate. |
| 7 | Fizzy notifications: read/unread ordered pagination | 245 across controller constructors | Different exists/count/load consumers, live page/offset and polymorphic resources. `order`/`limit` alone are already expressible; the complete use-site continuation is missing. |
| 8 | Fizzy workflows: two bare collection-reader paths | 210 = two scope pools of 95 + two readers of 10 | Plain CollectionProxy target/loaded state and strict loading differ from scoped AssociationRelation loads; finite counterexample below. |

The rank orders the displayed pure-construction pools, not whole-route
savings. For Campfire, the room `last_page` span is 4,069 objects with ten
SQL events (and an existing site); `page_before` is 1,608 with three SQL
events. Neither is a construction budget. Pagination must retain the live
anchor lookup/created_at comparison, last-40/reversal and creator preload.
An isolated `find_by` terminal is not instrumented by this builder census;
no generic `find_by` budget or support is claimed. Dynamic arguments,
hash predicates, includes/preload and order/limit are not categorically
impossible: each requires its own complete exact call-site program.

**Unranked, unknown rather than zero:** unchanged Writebook production boot
fails `ActiveRecord::Base.sqlite3_production_warning=` on Rails 8.1.4.
Its book-show source has `leaves.active.with_leafables.positioned`, where
`with_leafables` is polymorphic `includes(:leafable)`; book lookup also
retains access policy. No production allocation or own-suite claim is made.
CASA was source-inspected only: its configured PostgreSQL adapter is outside
Site's exact SQLite/prepared gate. Case index combines policy scope,
assigned-volunteer/court-date preloads, optional filters and stable ordering;
case show uses a different continuation. No dynamic CASA budget or suite
claim is made. Neither app was patched to force admission. Lobsters was not
used.

## One bounded specimen, one failed screen

The discarded external specimen replaced only `EventSummary#main_summary`
with the existing Site for `events.chronologically.non_boosts`, preserving
the summarizer and original fallback. It added source/effective-original
checks and a `WhereChain#not` method/visibility fact; it did not weaken Site
or add ordinary singleton classes or a test-only rebind. This was an
experimental splice, **not a complete production certificate**.

The screen used one fixed 3-round off-A/on/off-B schedule, 50 warm and 50
sample requests per timed worker, plus three untimed coverage workers:

| Gate | Observation | Verdict |
|---|---|---|
| Two-seed literal status/body/all-header equality | Status 200 agrees; body and header hashes differ even off-A/off-B at both seeds in every round. Entropy controls report pass. | **Rejected**, no normalization or retry. Cause of the off/off differences is unresolved. |
| Ordered SQL | Each coverage arm has 560 SQL events/10 requests; strict per-hit SQL/bind shadows pass. Whole-stream digests differ, including off/off; seeded companion digests differ too. | **Not certified**; equal counts are insufficient. |
| Allocations, median [min, max] | off-A 18,133 [18,122, 18,156]; off-B 18,134 [18,122, 18,154]; on 18,103 [18,091, 18,128] | About 30 objects/request, −0.168% arm-mean diagnostic; no admitted win. |
| Coverage | On: 30 hits, 30 strict shadows, 30 fallbacks in ten requests | Fails zero-fallback requirement. |
| Wall median | +2.268% on/off; A/A maximum absolute round spread 8.822% | No clear wall win; not an RPS price or JIT-flat result. |

Untimed follow-up probes run ten requests with shadows separately **off and
on**. Both yield 30 hits/30 fallbacks. All 30 fallbacks in each probe have
an unloaded association with nonnil cached scope; removing only that scope
cache temporarily makes eligibility pass, then immediately restoring it
preserves the original fallback. This diagnoses the refusal, **not permission
to discard the guard** or reuse that altered state as a treatment.

Bare-reader counterexample, on unchanged fixture data: Workflow stages
return the same three IDs, but stock `owner.stages.to_a` marks the association
loaded while direct Site rows do not. For a strict-loading owner the stock
reader raises `ActiveRecord::StrictLoadingViolationError`; the attempted
direct reuse returns rows. Refuse that reuse. This is not a demonstrated
defect in Y's differently scoped bucket chain.

## App-owned suite diagnostic and stop

Fizzy's full `bin/rails test --seed 731` ran through `lowrail verify` with
the external specimen and Y's shared Site/rebind, actual YJIT in both arms:
**124 identical identities/outcomes, 117 pass and seven identical baseline
`Current#reset_all` errors, 458 assertions and 5,324 identical ordered SQL
events**. This is equivalence, not an all-green suite. External on receipts
have 19 new hits/19 shadows/16 fallbacks, including four hits in
`EventSummaryTest#test_body`; Y's bucket also has one hit/shadow/connection
bind. Public CLI unit counters remain zero: this is not public delivery.

Before the suite, the specimen's unused production-eager-path Zeitwerk
callback was corrected for its two callback arguments. Native screen and
suite source hashes are therefore distinct and both retained in the export;
the suite is not certification of the exact screened fingerprint. The
specimen and temporary diagnostic scripts are discarded after export.

**Stop F2 here.** No interpreter Callgrind or `script/rps` cohort was run:
there is no exact, zero-fallback new-route candidate to price. No retry,
exclusion, app source/config patch, guard relaxation, main push, upstream
activity or support/default change. Further breadth would need a separately
scoped exact continuation design, not another favorable benchmark rerun.
