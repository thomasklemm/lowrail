# Rails candidates on common request paths (2026-11-03/04)

An overnight round for up to three new rails/rails candidates: small, exact (identical behavior), on paths most
requests run, with an allocation or instruction saving beyond the A/A. Quality over count; zero was an acceptable
result. Sources: the census and CPU docs ([census 3–7](rails-main-census-7.md), [census 8](rails-main-census-8.md),
[activerecord-cpu](activerecord-cpu.md), [actionview-cpu](actionview-cpu.md), [serialization-cpu](serialization-cpu.md),
[actionpack-cpu](actionpack-cpu.md), [rails-open-evidence](rails-open-evidence.md),
[gem-request-census](gem-request-census.md), [R7](rails-r7-queue.md)), plus an allocation trace of about 40 common
operations (helpers, form fields, finders, association reads, collection rendering) on Rails main.

**Result.** Two candidates, opened on 2026-11-04 after Thomas approved them: CP-1 as
[rails/rails#59596](https://github.com/rails/rails/pull/59596), CP-2 as
[rails/rails#59597](https://github.com/rails/rails/pull/59597); the rest were
rejected or already covered (below).

| # | Branch @ SHA | Change | Per call |
| --- | --- | --- | --- |
| CP-1 | [`thomasklemm/statement-cache-frozen-sql`](https://github.com/thomasklemm/rails/tree/thomasklemm/statement-cache-frozen-sql) @ `aabbcd09e9` | freeze a cached statement's SQL once, so `to_sql_and_binds` stops copying it on every cached `find`, `find_by` and association read | −2 objects; −0.2% to −0.6% instructions |
| CP-2 | [`thomasklemm/allow-browser-named-sets-once`](https://github.com/thomasklemm/rails/tree/thomasklemm/allow-browser-named-sets-once) @ `e78c7e93d3` | convert `allow_browser`'s named version sets (`:modern`) to HWIA once at load, not on every checked request | −1 object; −3.5% to −6.9% instructions per check |

Both are on rails/rails main [`d795dac950`](https://github.com/rails/rails/commit/d795dac950fe6eeeb7a2a439d9ca66eb8cbc067e),
one commit each, authored and committed by Thomas Klemm.

## Pins and method

* Rails main `d795dac950` (fetched 2026-11-03; unchanged at 23:00 UTC). Worktrees `main` and `aa` (the same
  commit twice, for the A/A) and one per candidate.
* Ruby 4.0.9 (mise), interpreter and `--yjit`; Ruby master
  [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb) built with
  `--enable-zjit --enable-yjit` for the interpreter and ZJIT columns.
* **Objects per call:** `GC.stat(:total_allocated_objects)` over 2,000 warmed calls, GC disabled
  ([`micro.rb`](../../bench/upstream/common_paths/micro.rb) `CASE N obj`).
* **Instructions per call:** Callgrind, `--collect-atstart=no --toggle-collect=rb_ary_cycle`, the N calls inside
  `[0].cycle(1)`, GC disabled after 3,000 warmup calls; Ir per call = (Ir(3,000) − Ir(0)) / 3,000
  ([`ir_rep.sh`](../../bench/upstream/common_paths/ir_rep.sh), [`ir_rep_table.py`](../../bench/upstream/common_paths/ir_rep_table.py)).
  CP-1: three runs per variant and mode, medians shown (the per-run spread of these Active Record calls is a few
  hundred Ir); CP-2: one run per variant. YJIT and ZJIT runs add `--smc-check=all`.
* **Wall time per call:** [`ns_run_pinned.sh`](../../bench/upstream/common_paths/ns_run_pinned.sh), pinned to one
  CPU with `taskset`, 15 rounds, variant order rotated each round, one process per run, 30,000 calls after 5,000
  warmup calls, GC disabled; medians. A first unpinned pass (`ns_run.sh`, seven rounds, 20,000 calls) had A/As up to
  ±7% and is only in the receipts.
* **ruby-bench (CP-1):** ruby/ruby-bench main as of 2026-11-03 with its own lockfiles (Rails 8.1.1/8.1.2, whose
  `cacheable_query` and `to_sql_and_binds` match main). The harness
  [`lowrail_scir.rb`](../../bench/upstream/common_paths/lowrail_scir.rb) redefines `cacheable_query` in every
  variant, with `.freeze` only in the candidate, so both sides run the same redefined method; one iteration under
  Callgrind after warmup (interpreter 1, YJIT 10), GC disabled; `main1`/`main2` are the A/A
  ([`rb_ir.sh`](../../bench/upstream/common_paths/rb_ir.sh)). Calls per request:
  [`lowrail_sc.rb`](../../bench/upstream/common_paths/lowrail_sc.rb) (TracePoint).
* **Suites:** `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, Ruby 4.0.9; Active Record `test:sqlite3` and
  `test:postgresql` (PostgreSQL 15 as an orb service), Action Pack `rake test`. RuboCop on every changed file.
* **Reviews:** codex is not available in this orb, so each candidate got two independent subagent reviews: a
  primary review on both rubrics (correctness, maintainability with the L0–L3 rating), then an adversarial round
  that tried to break identical behavior by running code. A third subagent read each PR body against this page
  for facts and for an outsider's readability.

## CP-1: freeze a cached statement's SQL once

`StatementCache` (behind `Model.find`, `find_by` and the association readers that use the statement cache) keeps
the SQL String its Arel collector built, `StatementCache::Query#@sql`, and hands it to `find_by_sql` on every
execution. `to_sql_and_binds` copies any String SQL that isn't frozen (`arel_or_sql.dup.freeze unless
arel_or_sql.frozen?`, the guard against a caller's String changing later). With prepared statements the cached
SQL was never frozen, so every cached query copied the same SQL: two objects per execution, both allocated on that
line (allocation tracing on `Post.find`). The change freezes it in `cacheable_query`, next to the `sql.freeze` the Arel
branch of `to_sql_and_binds` already does:

```diff
-          query = klass.query(sql, retryable: collector.retryable)
+          query = klass.query(sql.freeze, retryable: collector.retryable)
```

**Search.** No rails/rails PR, issue or maintainer decision covers it (searched "statement cache", "StatementCache",
"cacheable_query", "to_sql_and_binds", "freeze cached query", "dup.freeze sql"; the dup dates from `e220fda3e5`,
"dup if arel is not our string", and `08604eeaa4`, "No need to dup && freeze an already frozen sql string"). Open
PRs touching the two files: #57694 (an `Arel.array_bind` rewrite of `PartialQuery`, stale) and old transaction
PRs, none on these lines. A `to_sql_and_binds` probe over 23 common Active Record operations
([`dupfind.rb`](../../bench/upstream/common_paths/dupfind.rb)) found the statement cache to be the only Rails path
that hands it an unfrozen String Rails owns; the other was a user's own `find_by_sql` String, where the copy is
needed.

**The unprepared half was dropped.** The first version also froze `PartialQuery#sql_for`'s joined String
(`prepared_statements: false`, the MySQL default). The adversarial review showed that an app overriding
`find_by_sql` or `select_all` and editing the String in place works on main there (a fresh String per execution)
and would raise `FrozenError`, so that half is gone; the unprepared path is unchanged and keeps its copy.

**Boundaries (in the PR body).** With prepared statements:

1. `payload[:sql]` of `sql.active_record` is the same frozen String on every execution of a cached statement
   instead of an equal frozen copy. It was frozen before too, so only `equal?`/`object_id` can tell.
2. An override of `find_by_sql` or `select_all` that edits the SQL String in place now raises `FrozenError` for
   cached queries. On main it edited the cached statement itself, so the edit repeated on each later execution
   (an appended comment grew by one copy per query,
   [`override_find_by_sql.rb`](../../bench/upstream/common_paths/override_find_by_sql.rb)); such an override also
   already raises on main for any caller passing a frozen literal.

**Exactness checklist** ([`diff_sc.rb`](../../bench/upstream/common_paths/diff_sc.rb), SQLite, prepared and unprepared,
interpreter and YJIT, plus both reviews on SQLite and PostgreSQL 15): 1–3 the SQL is the collector's own buffer
(`+""` in `Arel::Collectors::PlainString`), never a user object; Arel SQL literals are appended into it and are not
frozen by this. 4 no call on a user object is added or skipped. 5 not applicable. 6 threads (8 × 50 cached finds on
PostgreSQL), fibers and `load_async` with the global thread pool behaved identically. 7 every String downstream of
`to_sql_and_binds` was already frozen; the results, SQL text, encoding (including non-ASCII and binary values in
default scopes), binds, `cached` flag, `RecordNotFound` messages, query cache keys, QueryLogs/annotate output,
`explain`, schema reloads, `table_name=` changes, reconnects and `PreparedStatementCacheExpired` matched. 8 nothing
new is loaded. Differences: the two boundaries above.

**Per call** (SQLite in memory, prepared statements; Ir medians of three runs, A/A = the same commit measured again):

| Operation | Mode | Objects main → PR | Ir main | A/A | Ir PR | Δ |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `Post.find(id)` | interpreter 4.0.9 | 61 → 59 | 310,237 | +0.01% | 308,998 | −0.40% |
| | YJIT 4.0.9 | 61 → 59 | 158,859 | +0.20% | 158,016 | −0.53% |
| | interpreter master | 61 → 59 | 307,254 | +0.04% | 305,820 | −0.47% |
| | ZJIT master | 61 → 59 | 144,951 | −0.08% | 144,103 | −0.59% |
| `post.author` (reset, then read) | interpreter 4.0.9 | 96 → 94 | 560,411 | +0.02% | 558,862 | −0.28% |
| | YJIT 4.0.9 | 98 → 96 | 258,388 | −0.06% | 256,764 | −0.63% |
| | interpreter master | | 569,261 | +0.02% | 567,684 | −0.28% |
| | ZJIT master | | 261,054 | −1.70% | 254,754 | −2.41% (A/A too wide) |
| `author.posts.to_a` (reset, then load) | interpreter 4.0.9 | 91 → 89 | 544,648 | +0.05% | 543,562 | −0.20% |
| | YJIT 4.0.9 | 92 → 90 | 236,517 | +0.04% | 235,041 | −0.62% |
| | interpreter master | | 571,979 | +0.00% | 570,473 | −0.26% |
| | ZJIT master | | 242,641 | +1.44% | 244,824 | +0.90% (A/A too wide) |

About 1,200–1,600 fewer instructions per cached query in every mode. The ZJIT association cells are bimodal
between runs (A/A ±1.4–1.7%), so they show no loss but resolve no gain; `find` under ZJIT is −0.59% against an A/A
of −0.08%.

**Wall time per call** (pinned to one CPU, 15 rotated rounds, 30,000 calls each, medians; A/A as above):

| Operation | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `Post.find(id)` | interpreter 4.0.9 | 70.9 µs | +0.4% | 69.2 µs | −2.3% |
| | YJIT 4.0.9 | 20.9 µs | +2.0% | 20.7 µs | −0.9% |
| `post.author` | interpreter 4.0.9 | 128.5 µs | −1.3% | 126.3 µs | −1.7% |
| | YJIT 4.0.9 | 35.0 µs | +1.5% | 35.4 µs | +1.0% |

Wall time does not resolve a change of this size (the instruction counts say 0.3–0.6%); the interpreter `find`
cell is larger than the instruction change and is not claimed. An unpinned first pass (seven rounds) had A/A up to
±7% and is in the receipts.

**ruby-bench** (instructions per iteration, Callgrind, Ruby 4.0.9; cached queries per request from the TracePoint
count: railsbench 0.99, lobsters 2.17, shipit 21.5):

| App | Mode | main, run 1 | main, run 2 | A/A | candidate | Δ vs mean of main |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| railsbench | interpreter | 6.9586 G | 6.9599 G | +0.019% | 6.9532 G | −0.087% |
| railsbench | YJIT | 4.3793 G | 4.3842 G | +0.111% | 4.3812 G | −0.013% |
| shipit | interpreter | 5.8433 G | 5.8461 G | +0.049% | 5.8421 G | −0.044% |
| shipit | YJIT | 3.1403 G | 3.1439 G | +0.116% | 3.1432 G | +0.035% |
| lobsters | interpreter | 4.2653 G | 4.2664 G | +0.025% | 4.2667 G | +0.020% |
| lobsters | YJIT | 3.0192 G | 3.0299 G | +0.357% | 3.0297 G | +0.171% |

Within noise. The expected effect is about 1,200 instructions × 21.5 queries × 114 requests ≈ 3 M per shipit
iteration (0.05%), the size of its A/A; railsbench's −0.09% is larger than its 0.99 cached queries per request
explain (about 0.03%), so it is noise as well (railsbench reseeds its database at start).

**Suites:** Active Record `test:sqlite3` 10,274 runs, 0 failures, 0 errors, 52 skips (the four structure-dump tests
need the `sqlite3` CLI, installed for this run); `test:postgresql` 11,195 runs, 0 failures, 0 errors, 31 skips (main:
11,194 runs, the same result). New test `test_cached_prepared_queries_return_frozen_sql` (defined only when the
connection uses prepared statements, like `finder_test.rb`'s prepared-statement tests): fails on main on SQLite and
PostgreSQL. RuboCop clean. **Readability:** L0.

**Reviews.** Primary: correctness approve, maintainability approve-with-nits (L0; nit: add a test that pins the
frozen SQL, done; keep the freeze in `cacheable_query`, not `Query#initialize`, and don't use `-sql`, which would
intern large SQL in the fstring table). Adversarial: one demonstrated difference beyond the payload identity, the
in-place edit by a `find_by_sql`/`select_all` override; fixed for the unprepared path by dropping that half, and
disclosed for the prepared path, where main already corrupted its own cached SQL in that case.

## CP-2: build `allow_browser`'s named version sets once

`rails new` (with importmap) generates `allow_browser versions: :modern` in `ApplicationController`, so every
request with a user agent runs `BrowserBlocker#blocked?`, which converted the frozen constant
`SETS[:modern]` to a `HashWithIndifferentAccess` to look up the browser's minimum version. The candidate builds
`EXPANDED_SETS` once at load (each set converted and frozen) and looks named sets up there; a Hash passed by the
app is still converted on each check, so later changes to it are seen. The file now requires
`active_support/core_ext/hash/indifferent_access`, because the conversion moved to load time; through
`require "action_controller"` the loaded features and their order are unchanged (both reviews compared
`$LOADED_FEATURES`). A test asserts the new constant is Ractor-shareable.

**Search.** #59472 (linyiru, merged 2026-10-31) read the user agent's version and browser once in the same class;
#58629 made the callback shareable; #53131 made `BrowserBlocker` private. No PR or decision on the set
conversion. This is P1-2 from [actionpack-cpu](actionpack-cpu.md#p1-2-allow_browsers-named-sets-built-once), held
then against a 0.1%-of-request bar; it is rebuilt on current main (the old branch kept a code comment) and judged
by the L1 rule (a per-call gain beyond the A/A). Two public apps read `BrowserBlocker::SETS[:modern]` directly
(found by the primary review), which is why `SETS` keeps its Symbol-keyed Hash instead of becoming the HWIA.

**Exactness checklist** ([`diff_ab.rb`](../../bench/upstream/common_paths/diff_ab.rb) and both reviews: up to 31
user agents × 15 `versions` values, interpreter and YJIT): 1–2 Hash subclasses, singleton `hash`/`eql?`/
`with_indifferent_access` and an object `eql?` to `:modern` made the same calls (`hash` 3 times on both). 3 no
conversions added. 4 `with_indifferent_access` is no longer called for named sets; for app hashes it is called as
before. 5–6 an app Hash mutated between requests is seen on the next request on both. 7 errors for `"modern"`,
`nil`, unknown Symbols and Integers keep their class and message; invalid-byte user agents raise the same
`ArgumentError`. 8 see the require above; no `on_load` hook runs earlier; Zeitwerk reloads of a controller switching
between `:modern` and hashes matched. Ractors: `Ractor.shareable?(EXPANDED_SETS)` is true; a full `blocked?` in a
non-main Ractor fails the same way on both because of the useragent gem's own constants. Differences: the private
`expanded_versions` returns one shared frozen HWIA for named sets, and `SETS` redefined after load is not seen
(both nodoc internals, accepted).

**Per call** (`BrowserBlocker.new(request, versions:).blocked?` on a fresh request; Callgrind one run per variant):

| Check | Mode | Objects main → PR | Ir main | A/A | Ir PR | Δ |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `:modern`, Firefox 132 | interpreter 4.0.9 | 190 → 189 | 312,242 | +0.03% | 294,313 | −5.74% |
| | YJIT 4.0.9 | 190 → 189 | 224,199 | +0.09% | 216,408 | −3.47% |
| | interpreter master | | 312,243 | −0.04% | 290,724 | −6.89% |
| | ZJIT master | | 225,413 | +0.00% | 215,280 | −4.50% |
| `:modern`, Safari 18 | interpreter 4.0.9 | | 392,776 | −0.01% | 374,554 | −4.64% |
| | YJIT 4.0.9 | | 297,617 | −0.09% | 289,659 | −2.67% |
| custom `{ firefox: 100, chrome: 100 }` (control) | interpreter 4.0.9 | 190 → 190 | 306,076 | +0.01% | 306,076 | −0.00% |
| | YJIT 4.0.9 | | 223,069 | −0.01% | 223,024 | −0.02% |
| | interpreter master | | 303,887 | −0.07% | 303,647 | −0.08% |
| | ZJIT master | | 222,100 | −0.01% | 222,166 | +0.03% |

**Wall time per check** (pinned to one CPU, 15 rotated rounds, 30,000 checks each, medians):

| Check | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `:modern`, Firefox 132 | interpreter 4.0.9 | 43.9 µs | +1.4% | 40.4 µs | −8.0% |
| | YJIT 4.0.9 | 23.5 µs | +1.7% | 22.5 µs | −4.4% |
| custom Hash (control) | interpreter 4.0.9 | 41.6 µs | +1.5% | 41.4 µs | −0.4% |
| | YJIT 4.0.9 | 24.0 µs | +1.6% | 24.5 µs | +1.9% |

So about 3.5 µs interpreted and 1 µs under YJIT per checked request, beyond the A/A, and nothing for custom hashes.

**ruby-bench** can't show it: shipit, the only one of the three with `allow_browser`, makes 0.28 checks per request
and sends no user agent, so the check returns before the lookup. In the census, Blog, Fizzy and Writebook use
`:modern` (P1-2's census: −1 object on their checked requests).

**Suites:** Action Pack `rake test` 4,463 runs, 0 failures, 0 errors (before the Ractor test was added);
`allow_browser_test.rb` 11 runs, 0 failures, with `-w`. RuboCop clean. **Readability:** L1 (a second constant built
from the first).

**Reviews.** Primary: correctness approve, maintainability approve-with-nits (L1). Findings: state the gain as
"1 object and a few µs per check" in the body (done); keep two constants rather than turning `SETS` into HWIAs
(kept, because apps read `SETS[:modern]`); add the Ractor-shareability test (done). Adversarial: nothing beyond the
accepted nodoc boundaries.

## PR bodies (as opened)

Both bodies were checked by a separate reviewer (verdict: ready after small edits) against the receipts (every number recomputed) and for an
outsider's reading; its corrections are applied. The links resolve once this page is on Lowrail main.

### CP-1: Freeze a cached statement's SQL once instead of copying it per execution

> Every `find`, `find_by` and association read that goes through the statement cache passes the cached SQL String to `find_by_sql`. With prepared statements (the default on SQLite and PostgreSQL) that String isn't frozen, so `to_sql_and_binds` copies and freezes it on every execution: two objects per query.
>
> This freezes the SQL once, when the statement is cached, as `to_sql_and_binds` already does for SQL it compiles from Arel. Without prepared statements nothing changes. With them, `payload[:sql]` is now the same frozen String on each execution instead of an equal frozen copy, and an override of `find_by_sql` or `select_all` that edits the SQL String in place now raises `FrozenError` for cached queries. On main such an edit changed the cached statement itself, so the appended text grew by one copy per query, and the override already raised for callers passing a frozen String.
>
> | `Post.find(id)`, per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 61 | 70.9 µs | 20.9 µs | 310,237 | 158,859 | 144,951 |
> | this PR | 59 | 69.2 µs (−2.3%) | 20.7 µs (−0.9%) | 308,998 (−0.40%) | 158,016 (−0.53%) | 144,103 (−0.59%) |
> | main, run again (change from the first run) | 61 | +0.4% | +2.0% | +0.01% | +0.20% | −0.08% |
>
> SQLite in memory, GC disabled, Ruby 4.0.9; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/common_paths/micro.rb)). Times are medians of 15 runs in rotating order on one CPU; instructions are Callgrind's count for 3,000 calls minus its count for none, divided by 3,000, median of three runs. Wall time doesn't resolve a change this size: the interpreter's −2.3% is larger than the instruction change, and YJIT's is inside its A/A. ruby-bench is within noise: shipit runs about 21.5 cached queries per request, and its instructions per iteration moved by less than 0.05% in both modes, inside A/As of 0.05% (interpreter) and 0.12% (YJIT). I found this while tracing allocations in common Active Record calls on Rails main with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-common-paths.md)).

### CP-2: Build allow_browser's named version sets once

> The generated `ApplicationController` calls `allow_browser versions: :modern` (in every app except `--api` ones), so every request with a user agent checks the browser. Each check converted the frozen `:modern` set to a `HashWithIndifferentAccess` to look up the browser's minimum version, with the same result every time.
>
> This converts the named sets once, when the class loads, into a frozen, Ractor-shareable `EXPANDED_SETS`. A version Hash passed by the app is still converted on each check, so later changes to it are seen as before, and `SETS` keeps its Symbol-keyed Hashes for code that reads it. Because the conversion now runs at load time, the file requires `active_support/core_ext/hash/indifferent_access` itself; after `require "action_controller"` the same files load in the same order.
>
> | `:modern`, Firefox 132, per check | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 190 | 43.9 µs | 23.5 µs | 312,242 | 224,199 | 225,413 |
> | this PR | 189 | 40.4 µs (−8.0%) | 22.5 µs (−4.4%) | 294,313 (−5.7%) | 216,408 (−3.5%) | 215,280 (−4.5%) |
> | main, run again (change from the first run) | 190 | +1.4% | +1.7% | +0.03% | +0.09% | +0.00% |
>
> A check here is `BrowserBlocker#blocked?` on a freshly built mock request, with GC disabled, on Ruby 4.0.9; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/common_paths/micro.rb)). Times are medians of 15 runs in rotating order on one CPU; instructions are Callgrind's count for 3,000 checks minus its count for none, divided by 3,000. With a custom version Hash, objects, time and instructions are unchanged within the A/A. ruby-bench can't show this: shipit, the only one of its three Rails apps with `allow_browser`, sends no user agent, so the check returns before the lookup. I found this while measuring the request path of newly generated apps with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-common-paths.md)).

## Rejected and not built

| Site | Numbers | Why not |
| --- | --- | --- |
| `OutputBuffer#capture(*args)` → `capture(*)` (census R2-4; every block `tag.*`, `content_for`, form builder) | `tag.div { }` 9 → 8 objects and −0.46% Ir interpreted; YJIT 9 → 9 (+0.05%); ZJIT on master 9 → 9 | Only the interpreter gains: YJIT on 4.0.9 and ZJIT on master allocate the empty rest Array themselves (until ruby/ruby#19655), and YJIT is on by default since Rails 7.2. Same file as our open #59570. |
| `cached_find_by([primary_key], [id])` and `values.flatten` (every `find`) | 1–2 Arrays per `find` | `[primary_key]` is the statement-cache key; `flatten` is needed for composite keys, so skipping it needs a branch (L1) for about 0.1% of a `find`. |
| `CustomUrlHelper#call` with `only_path` (`"/" + url.partition(re).last`, `direct`/`resolve` helpers; R7 lead) | 3 objects of a full URL generation | Few apps use `direct`/`resolve` path helpers; a slice changes the result's encoding when the URL is US-ASCII. |
| `field_name` with no extra names (`method_names.map!.join`, every form field) | 1 String per field | Needs a branch (L1) for 1 of about 28 objects per field. |
| `field_id`'s `gsub(...).delete_suffix` (every form field) | 1 String | In-place editing of the `gsub` result, the R7-5 pattern: no interpreter gain there, and a singleton-`gsub` boundary. |
| `connection_specification_name` (census 8 method rank 25, 0.30% of instructions) | recursion through `superclass` | A loop would bypass overrides on superclasses. |
| `notifications/fanout.rb:213` (R7 lead) | 13 objects per op | The objects are allocated by the subscribers' own blocks (app and gem code). |
| `aggregations.rb` `@aggregation_cache = {}` | 1 Hash per record | Only models with `composed_of` (#33221 already made it per model); Mastodon only. |
| `InheritableOptions#initialize` (census 8 rank 23) | 0.23% | The per-request config copies are built when views read `config` (asset helpers); avoiding them is P1-1's design question. |
| P1-1 (CSRF settings without the config copy), R2-3 (URL defaults merge), R7-1, R7-2, R7-5 | see their docs | Unchanged dispositions. |
| `apply_inflections`, `IsolatedExecutionState.[]`, `handler_for`, `Composite#<<`, `where`/`having` defaults, `URI_REGEXP` | census 8 | Skipped: census 8 built or rejected them (C8-1 is its own queue entry). |
| Collection rendering, `link_to`, `tag.*`, `content_tag`, `l`, `t`, `number_with_delimiter`, `simple_format` | | The remaining Rails-side objects are output, or the time is in i18n, nokogiri or loofah. |

## Limits

* Allocation and instruction counts per call on SQLite in memory and on micro cases, not request time. ruby-bench
  runs Rails 8.1 with the change patched in by the harness, not Rails main.
* MySQL and Trilogy were not run (no server in this orb); CP-1 no longer changes their default unprepared path.
* Wall-time medians come from one orb; they support per-call claims only.
* Reviews were subagents, not the Sol/Astra Thermos reviews DECISIONS names, because codex is not installed here.
* Receipts: [data/rails-common-paths/receipts.tar.gz](data/rails-common-paths/receipts.tar.gz) (every Callgrind log,
  `ns.tsv`, ruby-bench logs, differential outputs, suite summaries).
