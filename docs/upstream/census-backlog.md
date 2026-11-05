# Census backlog: unworked Rails and ecosystem leads (2026-11-04)

Every lead in the census rounds that is still unworked:
[census 3](rails-main-census-3.md)–[8](rails-main-census-8.md), the [framework census](rails-framework-census.md),
[R6](rails-r6-leads.md), [R7](rails-r7-queue.md), [F1](frontier-census-f1.md), the
[Action View](actionview-cpu.md), [Active Record](activerecord-cpu.md), [Action Pack](actionpack-cpu.md) and
[serialization](serialization-cpu.md) deep dives, the [PostgreSQL census](pg-census.md), the
[merged audit](merged-audit.md), [schema context](schema-context.md), and the Held and Investigated sections of the
[ledger](contributions.md). "Unworked" means not merged, not open (ours or someone else's), not rejected for a
recorded reason, and not being built by a running orb. Area owners on 2026-11-04: C9 Active Model
`resolve_attribute_name` and Journey `UriEncoder`, C10 Action View tag options, C11 Active Record (with Arel), C12
Action Pack, C13 Active Support.

Upstream state was checked on rails/rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed)
(the site is still on main unless noted) and against open rails/rails PRs on 2026-11-04. ZJIT and YJIT leads are
in [zjit-iseq-leads](zjit-iseq-leads.md) and [yjit-leads](yjit-leads.md) and are not repeated here.

**Result.** 20 performance leads remain. Most are in areas other orbs own, so they are listed for those orbs. The
most valuable unworked item outside those areas is a correctness finding: Rails main dropped three
`ActionView::Template` handler methods, which breaks maildown's Markdown handler (CodeTriage's mails). It is
built as **TH-1** (below) and opened as [rails/rails#59606](https://github.com/rails/rails/pull/59606). No second performance lead outside
the owned areas clears the bar (see [Why only one candidate](#why-only-one-candidate)).

## Refresh on main 1e235cee11 (2026-11-05 night)

The ranking and dispositions below this section describe the original 2026-11-04 check, not the current queue.
Rechecked all 20 performance leads against rails/rails main
[`1e235cee11b0a7aecb189d8837534807626287aa`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa)
and open and closed PRs on 2026-11-05. Two small variants were built independently on that main, not on another
open PR. **Only CB2 survived exact-head skeptical review.** CB1 is rejected, not awaiting a waiver. Nothing opens
in this task: CB2 needs the coordinator's Sol pass and queue release. Its workload CPU effect is tiny or
within A/A; it does not claim an app speedup. The result is one viable candidate, not two padded with a known
behavior change or a previously rejected design. This keeps the lesson from fatkodima on
[rails/rails#59577](https://github.com/rails/rails/pull/59577): CPU evidence and a small, readable change, not
extra helpers or cached state to improve allocation counts. The open-PR check paginated all 1,282 open PRs,
including other authors' work; name searches also included closed PRs.

| Original rank | Current disposition and reason |
| ---: | --- |
| 1 | Already in open [rails/rails#59564](https://github.com/rails/rails/pull/59564), head `2fb737482fa9d03e3bbb35586edda131b42e6bdf`: the body and branch include `immediate_future_classes` and `target_classes`. Do not build a duplicate follow-up. |
| 2 | Retain rejection: [request-path study](as-request-paths.md) already rejected caching the unsilenced list. `silenced?` is live subscriber behavior, and an extra cache is L2. Open #58957 concerns structured events, not permission to cache the list. |
| 3 | Retain rejection: `super` is the deliberate extension point added by #46573, not gratuitous dispatch. A direct `ERB::Escape` call reverses that design. |
| 4 | Fixed: [rails/rails#59618](https://github.com/rails/rails/pull/59618), merged as `088a9ad445105e705e972e899b85463b96d11109`, appends the default star without a rest Array. |
| 5 | Retain rejection: `Arel.sql` is public and accepts positional and named binds. The private `where!`/`having!` signature precedent does not transfer. |
| 6 | Park: after merged #59294 the `update(*other_hashes)` rest remains. Avoiding it cheaply needs either a signature/forwarding contract change or special-case dispatch; not a small obvious change with CPU evidence. |
| 7 | Retain [common-paths rejection](rails-common-paths.md#rejected-and-not-built): removing inheritable config copies changes when the mutable inherited config is read. A design question, not a local allocation fix. Census 8's 0.23% is **self** instructions, not inclusive cost of its callers. |
| 8 | Park: `tr!` is the Ruby 4.1 path, so it cannot produce a Ruby 4.0.9 candidate. The earlier ≤4.0 JSON work is now merged; no follow-up to its rejected multi-scan variants. |
| 9 | Retain rejection: `URL.path_for` receives public, potentially retained/frozen buffers; ownership transfer is not established. |
| 10 | Retain hold: a JSON generator option is a feature requiring ruby/json maintainer interest, not a Rails patch. |
| 11 | Retain rejection: changing delegation through `scoping` affects overridable calls, block forwarding and VM behavior. The exact lambda-only part already merged in #59571. |
| 12 | **New exactness rejection:** `.values` is a snapshot. Replacing either remaining call with `.values_for_merge` changes public `structurally_compatible?` / `empty_scope?` results if a value's `==` mutates the other relation. Reproducer and outputs below; no candidate. |
| 13 | **CB2**, [queue item](../../bench/upstream/pr-queue/items/CB2.md): avoid collecting empty around-callback arguments; six changed code/doc lines, one less Array per symbol callback. No overlapping optimization found; open #58749 changes callback ordering, #58582 duplicate removal, not this dispatch tuple. The earlier request-path rejection concerns the required `Environment`/thunk, not the rest assignment here. |
| 14 | **CB1 rejected**, [held record](../../bench/upstream/pr-queue/items/CB1.md): `NilClass#try`/`try!` with `(...)` skips direct keyword-splat conversion. `nil.try(:upload, **unpermitted_params)` raises on main but returns nil on the candidate. Open #58646 and merged #55278 concern different behavior and do not authorize this change. |
| 15 | Retain rejection: global column-alias caches are a Ractor/ownership design change. |
| 16 | Fixed: [rails/rails#59608](https://github.com/rails/rails/pull/59608), merged as `98f3793369779f3027a08c73615f08f24f4cd931`. |
| 17 | Retain rejection: changing the PostgreSQL prepared-statement key/pool is a cache redesign, not a String removal. |
| 18 | Retain the actionpack study's inactivity hold; not a Rails-main code change or a reason to send another unanswered gem PR. |
| 19 | Retain [R7 dispositions](rails-r7-queue.md#ranking-and-dispositions): required copies and narrow sites do not justify another complex allocation-only patch. |
| 20 | Drop for this round: roughly two Action Text `reverse_merge` calls per operation, no independent CPU evidence. The lookup-context copy is required. |

### Measurements, including the rejected CB1 variant

Ruby 4.0.9 revision `3e93b23afcec3433f6aecc34b5d832799d754238`; Rails base and independent A/A worktree both
`1e235cee11b0a7aecb189d8837534807626287aa`. Medians of three per-tree runs with the existing PM1/PM3
[`percall.sh`](../../bench/upstream/perf_round/percall.sh), GC disabled, identical fixed heap. Ir is **inclusive**
method/workload instructions plus equal loop overhead, not the self-instruction ranking of census 8. Fractions
of an object are the loop's three objects divided by the call count; the table rounds that common overhead away.

| Case | Main Ir | A/A Ir | Candidate Ir | Objects, main → candidate | Interpretation |
| --- | ---: | ---: | ---: | ---: | --- |
| CB1 `nil.try(:upload)` | 1,398.7 | 1,398.7 | 956.5 | 1 → 0 | −31.6%; interpreter only |
| CB1 positional + keyword arguments + block | 2,011.3 | 2,014.3 | 1,030.5 | 2 → 0 | −48.8%; A/A ≤0.15% |
| CB1 SQLite Active Storage dirty update | 923,112.0 | 923,619.1 | 923,207.2 | 194 → 193 | No workload CPU claim; A/A ≤0.09% |
| CB2 symbol around callback | 14,399.8 | 14,398.4 | 14,233.3 | 7 → 6 | −1.16%; A/A ≤0.024% |
| CB2 two-argument block | 15,370.9 | 15,374.5 | 15,348.0 | 8 → 8 | −0.15%, close to max A/A 0.13%; not a headline |
| CB2 object around callback | 14,671.5 | 14,669.9 | 14,686.3 | 7 → 7 | **+0.10%** retained; moving the argument Array into the Ruby tuple is not free |
| CB2 SQLite model save | 216,695.0 | 216,637.5 | 216,517.4 | 56 → 55 | −0.082%; A/A ≤0.027%, tiny synthetic workload effect |
| CB2 controller action | 547,189.1 | 546,820.4 | 546,897.4 | 133 → 132 | Within A/A ≤0.114%; no request CPU claim |

The callback-free control is unchanged (about 3,260 Ir, zero objects); `nil.try` is unchanged on the callbacks
branch. An initial object-callback cohort had a failed base setup during dependency installation; the **whole
cohort is rejected**, not treated as zero instructions or pooled with the valid replacement cohort. Raw values,
rejected data, test tails, JIT windows and rejected native timing samples are in
[`data/census-backlog-refresh/`](data/census-backlog-refresh/).

Supplemental Callgrind: Ruby 4.0.9 YJIT and master ZJIT
[`ec4f61e68936cf3544e9507acdfdcf0501f90116`](https://github.com/ruby/ruby/commit/ec4f61e68936cf3544e9507acdfdcf0501f90116).
All 54 measured windows are JIT-flat (compiled ISEQ/block or side-exit counters unchanged; ZJIT OOM counter zero).
`nil.try` already allocates zero objects and has no measurable instruction gain on either JIT. Symbol callback
median Ir: YJIT 12,446.6 → 11,838.9 (−4.9%, max paired A/A 0.115%); ZJIT 11,985.5 → 11,884.6 (−0.84%, A/A 0.137%).
Two-argument block: YJIT 13,315.7 → 12,816.4 (−3.75%, A/A 0.130%); ZJIT 13,057.8 → 12,808.7 (−1.91%, A/A 0.278%).
The remaining changed object-callback form was then measured separately with the same protocol: all 18 windows
flat, objects unchanged at seven. YJIT 12,602.5 → 12,176.1 Ir (−3.38%, A/A ≤0.119%); ZJIT
12,178.9 → 12,047.6 (−1.08%, A/A ≤0.044%). Its +0.10% interpreter loss is not a JIT loss.
These are microbenchmarks, not app timings. Native master CPU timings have noisy A/A (nil +29%, symbol −17% by
medians); **that timing cohort is rejected, not rerun until green**. Its apparent block slowdown is not used as a
speed claim in either direction; the separately specified fixed-heap Ir cohort above reduces block instructions.

### Exactness, tests and reproduction

Before review, CB1's intended change read: accept the same arguments and block; discard them without collecting
them; return nil. Review disproved the first sentence for direct keyword conversion (below). CB2: read the
argument list from the fourth tuple entry; splat it at the existing
`send` in the caller. Templates with arguments put their list in that entry; templates without arguments leave
it absent. No new branches, cached state, callback wrappers or user-code frames.

CB1 head `22a3d41d8db5ba1aad8b86de5229336148080bca`; CB2 head `ced306c8a8b827f538b4b6f0fbeefc1264e94f8f`.
CB2 preserves public dispatch and return values. Its nodoc call-template tuple changes, so an override of that
internal representation must follow it. CB1's `Method#parameters` change (forwarding keyword rest, arity still
−1) is disclosed but **not** its blocker: skipping `to_hash` side effects, exceptions and invalid return-type
checks is observable public behavior. A leading optional parameter restores coercion but still allocates the
rest Array on Ruby 4.0.9, so it is not a cheap rescue. The held item cannot be opened.

[`refresh_exact.rb`](../../bench/upstream/census_backlog/refresh_exact.rb) gives 83 byte-identical callback
outcomes on Ruby 4.0.9 interpreter/YJIT and master ZJIT. Callback cases include subclass `send`/`instance_exec`,
`method_missing`, symbols, callable objects, all block arities, conditions, aborts, exceptions, frozen receivers
and fiber suspension. CB1 initially matched 95 cases passing actual Hashes through `public_send`; that missed
direct non-Hash keyword splats. The revised harness adds successful, raising, invalid and missing `to_hash`,
plus real `ActionController::Parameters`: **all ten new outcomes differ** on interpreter and YJIT. Both outputs
are retained in the raw data. Existing Active Support full suite, **on main and both exact heads**:
`PARALLEL_WORKERS=1 bundle exec rake test` from `activesupport`, **6,901 runs, 29,966 assertions, 0 failures,
0 errors, 60 skips** each. The changed files pass Rails RuboCop. No permanent behavior test is added for the
representation-only refactor; existing callback and try public-API tests pass unchanged.
Action Pack on main and CB2 also passes `PARALLEL_WORKERS=1 bundle exec bin/test
test/controller/filters_test.rb test/abstract/callbacks_test.rb`: **78 runs, 161 assertions, no failures, errors
or skips** on each tree.

Complexity is unchanged: Flog `run_callbacks` 82.6; methods-only (`flog -a -m`) total of both files 657.3 on all trees.
RuboCop metrics for `run_callbacks`: ABC 45.09, cyclomatic 14, perceived 17 before/after. Each touched `expand`
retains its previous metrics and branch count; both nil methods have no branches.

Independent skeptical passes are recorded on the exact heads in the queue metadata: CB1 **changes required**
(coercion blocker verified independently); CB2 **approve with nits**, no correctness blockers, including an
additional 201 differential cases. Its wording nits were applied. Under Thomas's later "Bodies for humans,
short" rule, both item bodies now contain two paragraphs and one table; methodology, pins, controls, test
totals and the nodoc override boundary stay in the item notes and this record, not in the prospective PR body.
CB2 still needs coordinator Sol; no Sol or Astra was run here.

Use `main`, `main-aa`, `nil-try`, `callbacks` for independent worktrees at the exact heads above. Ruby 4.0.9
and the patched Valgrind from `script/bench-valgrind` are required. The heap is fixed by `percall.sh` to size-pool
initial slots `1000000/250000/100000/20000/10000`; all four trees use the same Gemfile.lock (SHA-256
`98694d889aa7c4d367faed3d3034dfb17aec063a126aac9545b3c1dc69c26154`).
Benchmark source is pinned at Lowrail
[`5b9c878577970eaeb02b69d614b7e4a6bd7eea87`](https://github.com/thomasklemm/lowrail/tree/5b9c878577970eaeb02b69d614b7e4a6bd7eea87/bench/upstream/census_backlog),
using [`percall.sh`](https://github.com/thomasklemm/lowrail/blob/5b9c878577970eaeb02b69d614b7e4a6bd7eea87/bench/upstream/perf_round/percall.sh).

```sh
RUBY=path/to/ruby-4.0.9/bin/ruby WARMUP=2000 OUT=/tmp/cb2 \
  bash bench/upstream/perf_round/percall.sh bench/upstream/census_backlog/refresh_cases.rb symbol 3000 3 path/to/main path/to/main-aa path/to/callbacks
WORKLOADS=1 RUBY=path/to/ruby-4.0.9/bin/ruby WARMUP=500 OUT=/tmp/cb2-workload \
  bash bench/upstream/perf_round/percall.sh bench/upstream/census_backlog/refresh_cases.rb action 1000 3 path/to/main path/to/main-aa path/to/callbacks
RUBY=path/to/ruby-4.0.9/bin/ruby WARMUP=2000 OUT=/tmp/cb1 \
  bash bench/upstream/perf_round/percall.sh bench/upstream/census_backlog/refresh_cases.rb nil_try 3000 3 path/to/main path/to/main-aa path/to/nil-try
# Likewise nil_kwargs, symbol/block/object/plain with the appropriate candidate tree.
WORKLOADS=1 RUBY=path/to/ruby-4.0.9/bin/ruby WARMUP=500 OUT=/tmp/cb1-workload \
  bash bench/upstream/perf_round/percall.sh bench/upstream/census_backlog/refresh_cases.rb attachment_update 1000 3 path/to/main path/to/main-aa path/to/nil-try
# Likewise save/action on the callbacks tree.
RAILS_PATH=path/to/main BUNDLE_GEMFILE=path/to/main/Gemfile path/to/ruby-4.0.9/bin/ruby -rbundler/setup bench/upstream/census_backlog/refresh_exact.rb nil
# Run the same on the candidate and compare; use callbacks instead of nil for CB2.
```

Supplemental JIT windows use [`refresh_window.rb`](../../bench/upstream/census_backlog/refresh_window.rb),
with `bench/callgrind.c` built as `lowrail_callgrind.so` against each Ruby's headers. Set `CG_EXT` to that extension,
use the same heap variables above, and run Valgrind with `--tool=callgrind --instr-atstart=no`; the extension
starts and stops counting around the measured window only. Arguments are the case name and `3000`. Flags were
`--yjit --yjit-stats=quiet --yjit-call-threshold=1` on 4.0.9 and
`--zjit --zjit-stats=quiet --zjit-call-threshold=1` on master. Warmup requires three consecutive flat windows
before measurement, and the recorded measured counters must also remain flat; no non-flat sample is discarded.

The Relation rejection is executable through public APIs in
[`refresh_values_repro.rb`](../../bench/upstream/census_backlog/refresh_values_repro.rb). A `readonly` value's
`==` changes the other relation's `offset!`; the main snapshot yields `compatible: true` and `empty scope: true`.
Replacing each `.values` call with `.values_for_merge` yields false for both, despite the same final offset.
That snapshot cannot be removed just because the Hash is not explicitly mutated by the comparing method.

## Ranked performance leads

Score = effect × breadth ÷ review risk. Effect is on a 1–5 scale: 5 means ≥ 0.5% of an operation's instructions or
≥ 20 objects per operation, 4 means 0.2–0.5% or 10–20 objects, 3 means 0.05–0.2% or 5–10, 2 means 0.01–0.05% or
2–5, and 1 is less. Breadth is census apps reached, out of 20. Risk is 1 (L0/L1, exact, reviewed), 2 (a boundary
to argue, or not yet tried) or 3 (L2, a design question, or a VM-side fix). Effects are the source docs' numbers.

| # | Lead | Area (owner) | Source | Effect | Breadth | Risk | Score | Upstream since |
| ---: | --- | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | C6-2: the preloader branch builds its class lists in place (`immediate_future_classes`, `target_classes`) | Active Record (C11) | [census 6](rails-main-census-6.md#c6-2-build-the-preloader-branchs-class-lists-in-place) | on top of #59564: preloading median −11 / −14 objects, Sure −200 / −193 (3) | 17 apps, 131 of 251 workloads | 1 | 51 | Unchanged. Sol approved both rubrics; waits for our open #59564, which it was never folded into |
| 2 | Census 5 R10/R20/R21: `fanout.rb:286/290` builds the active-subscription list for unsilenced silenceable subscribers on every instrument | Active Support (C13) | [census 5](rails-main-census-5.md) | 13–29 objects per op (4) | 9 of 9 apps, 97–98% of workloads | 2 | 38 | Unchanged since 1d2c6fed48; #58957 (open) skips structured events only. Not attempted |
| 3 | V1-C2: `ERB::Util.html_escape`/`unwrapped_html_escape` call `ERB::Escape.html_escape` instead of `super` | Active Support (C13) | [actionview-cpu](actionview-cpu.md) | erubi-rails −5.2% / −4.8% Ir (interpreter / YJIT), railsbench −0.8% interpreted; per call 78 → 71 ns, 55 → 43 ns (5) | every escape, 20 apps | 3 | 33 | Unchanged (`super(s)` at util.rb:16). Held because it removes the `super` #46573 added on purpose |
| 4 | `SelectManager#project(*projections)` gets a one-element rest Array from every `arel.project(table[Arel.star])` | Arel (C11) | [census 7](rails-main-census-7.md) rank 121 | 9.5 objects per op (3) | 20 apps, 82% | 2 | 30 | Unchanged. kamipo fixed the same shape Rails-side for `where!`/`having!` in 401f146f41 (#59579), so a Rails-side fix now has a precedent |
| 5 | `Arel.sql(sql, *positional_binds, **named_binds)` allocates an empty rest and kwrest per call | Arel (C11) | [census 6](rails-main-census-6.md) rank 100 | 11.7 objects per op (4) | 15 apps, 72% | 2 | 30 | Unchanged; same 401f146f41 precedent, but `Arel.sql` is public, so the signature can't take the `where!` form |
| 6 | HWIA `merge(...)` → `update(*other_hashes)` rest Array | Active Support (C13) | [census 7](rails-main-census-7.md) rank 104 | 10.7 objects per op (4) | 20 apps, 81% | 3 | 27 | #59294 (merged 2026-10-31) forwards `merge`'s arguments; the rest Array remains |
| 7 | `InheritableOptions#initialize`: per-request config copies built when views read `config` | Active Support (C13) | [census 8](rails-main-census-8.md) rank 23 | 0.23% of interpreted Ir (4) | 20 apps | 3 | 27 | #59105 took the reads; the copies are P1-1's design question ([common paths](rails-common-paths.md#rejected-and-not-built)) |
| 8 | S-tr: on Ruby 4.1 the JSON escape uses `tr!`; compare with a per-character search there | Active Support (C13) | [serialization-cpu](serialization-cpu.md) | unmeasured; the 4.0 version (#59584) is −4.5% / −6.1% on `posts.to_json` (3) | 30 of 34 JSON workloads, ~15 apps | 2 | 22 | Unchanged (`TR_ESCAPE_SUPPORTED`). #59584's own path is ≤ 4.0 only |
| 9 | Path helpers: `URL.path_for` copies the route buffer (`url.rb:169` `chomp`) after `Journey::Format` builds it (`visitors.rb:38`) | Action Pack (C12) | [census 6](rails-main-census-6.md) ranks 44/45 | 21.3 objects per op each (5) | 15 apps, 59% | 3 | 25 | Unchanged; needs `path_for` (public) to own the buffer: a maintainer question |
| 10 | S-jsonopt: a ruby/json generator option to escape `<>&`, so Rails drops its second pass | json gem | [serialization-cpu](serialization-cpu.md) | the second pass is ~15% of the jbuilder micro (4) | every `to_json`/`render json:`, ~15 apps | 3 | 20 | ruby/json #763 ("Escape HTML entities") closed; open PRs unrelated. A feature: needs byroot's interest before a PR |
| 11 | Generated relation delegators forward `...` through a `scoping { }` block (`delegation.rb:81`) | Active Record (C11) | [census 6](rails-main-census-6.md) rank 58, [R6](rails-r6-leads.md) remainder | 18.8 objects per op before #59571; 304 per op left at the line in R6 (4) | 14 apps, 66% | 3 | 19 | #59571 (merged) removed the parameterless-lambda part; the rest is "not exact as is; also a VM question" |
| 12 | Census 5 R23 residue: `empty_scope?` and `structurally_incompatible_values_for` still copy `values` | Active Record (C11) | [census 5](rails-main-census-5.md) | part of 17.9 objects per op (2) | ~16 apps | 2 | 16 | #59556 (ours, merged) fixed the Merger copy; these two callers are unchanged |
| 13 | Around callbacks splat the call template (`callbacks.rb:131`) | Active Support (C13) | [census 5](rails-main-census-5.md) | 2.8 objects per op (2) | ~15 apps | 2 | 15 | Unchanged; not attempted |
| 14 | `Tryable#try(*args, **kwargs, &block)` allocates 2 objects per call (Active Storage's `nil.try`, census 8 ZJIT leads D/E) | Active Support (C13) | [common paths 2](rails-common-paths-2.md#rejected-and-not-built) | 2 objects per call; Fizzy 3–4 per op (2) | ~5 apps | 1 | 10 | Unchanged; not measured on apps |
| 15 | Eager-load column aliases `"t#{i}_r#{j}"` rebuilt per query (`join_dependency.rb:188`) | Active Record (C11) | [census 6](rails-main-census-6.md#addendum-l6s-four-apps) | 17.7 objects per op (26.9 YJIT) (4) | 7 apps, 9% | 3 | 9 | Unchanged; needs a global table of frozen names (not Ractor-friendly) |
| 16 | `prepend_formats`: skip re-deriving lookup formats when the template's format already leads | Action View renderer (free) | [actionview-cpu](actionview-cpu.md#rejected-and-leads) | 6.0 / 5.4 µs per template render on the renderer path; 2–3% of erubi-rails (4) | renderer-based renders only, 2 of 7 profiles (~6 apps) | 3 | 8 | Unchanged. "Not exact cheaply": format validation and the JS→HTML fallback are most of the cost |
| 17 | PG `sql_key` builds `"#{schema_search_path}-#{sql}"` per query | Active Record (C11) | [pg-census](pg-census.md) | 9.6 objects per op (3) | 8 of 9 PG apps | 3 | 8 | Unchanged; a path-keyed pool changes the statement cache |
| 18 | `useragent`: `UserAgent.parse` per `allow_browser` check | useragent gem | [actionpack-cpu](actionpack-cpu.md) | 16–20 µs per check, 1.4% of the Blog profile (5) | apps with `allow_browser` (~4) | 3 | 7 | Gem last pushed 2024-12-04, 23 open issues, eight unanswered PRs since August: maintainer inactive (DECISIONS: check activity first) |
| 19 | R7 tier not examined: `json/encoding.rb:315`, `fanout.rb:292`, Action View `base.rb:358`, `route_set.rb:370/371`, `output_safety.rb:165` | AS / AV / AP | [R7](rails-r7-queue.md#ranking-and-dispositions) | 1.3–4.3 objects per op (2) | 2–5 apps | 2 | 4 | Unchanged |
| 20 | Hash#merge probe sites: Action Text `content.rb:40` `reverse_merge` | Action Text (free) | [framework census](rails-framework-census.md) | ~2 calls per op (1) | few | 2 | 1 | Not checked further; `lookup_context.rb:213` is the required copy |

Parked behind someone else's open PR (not ours to build): AT-builder (hoist `attributes_builder` per row, 10 rows
−5.7%) and the `_load_from_sql` column-iteration variant behind #59141; schema-context's cheaper `schema_context`,
faster slow path and the ZJIT branch split behind matthewd's #59530; `references_eager_loaded_tables?` behind #59377;
`preprocess_order_args`' eager matcher behind #59413; the query-cache key behind #59518; `LazyAttributeSet#keys`
behind #58002; jbuilder `_blank?` behind rails/jbuilder#622; http_accept_language's per-request singleton behind
iain/http_accept_language#80.

## Correctness findings

Ranked by user impact. None has a rails/rails issue from us; issues need Thomas's OK (DECISIONS).

| # | Finding | Area | Source | State on main 2026-11-04 |
| ---: | --- | --- | --- | --- |
| 1 | `find_by_sql`/`count_by_sql` with array binds on PostgreSQL prepared statements: since #58427 (`8c4ed25f0a`) typed literals (`DATE :d`, `TIMESTAMP ?`, `INTERVAL`, `JSONB`), `DATE '…' + :n` and `(:x IS NULL)` fail with a syntax or type error that 8.1.4 doesn't raise; Sure's transfer matcher breaks. Not in the CHANGELOG. | Active Record (C11) | [find-by-sql-typed-literal-binds](find-by-sql-typed-literal-binds.md), [pg-census](pg-census.md) | Present (`bound_sql_literal_for`). Our open #59565 only adds a cast hint to the error |
| 2 | **Built as TH-1.** #57874 (`cd416503e8`, unreleased) dropped `ActionView::Template.registered_template_handler`, `template_handler_extensions` and `register_default_template_handler`. maildown 3.3.1 calls `registered_template_handler(:erb)` from its handler, so on main a `.md` template raises `NoMethodError` inside `ActionView::Template::Error` the first time it compiles; census 4 saw CodeTriage's Markdown mails fail this way. SimpleCov added a `respond_to?` workaround; view_component fixed its copy (ViewComponent#2662). (Loomio's initializer also calls it, but its handler takes one argument, which 8.1 already rejects, and Loomio has no `.md` views, so it is not evidence.) | Action View (free) | [census 4](rails-main-census-4.md) | Present; open as #59606, see [TH-1](#th-1-restore-the-template-handler-lookup-methods) |
| 3 | `Array#index_with` ignores an overridden `each` on an Array subclass since 2b88dc1995 (unreleased): `Tens[1, 2].index_with { _1 }` is `{10=>10, 20=>20}` on 8.1 and `{1=>1, 2=>2}` on main. | Active Support (C13) | [merged-audit](merged-audit.md) | Present (`enumerable.rb:315` uses `to_h`). Our open #59557 touches the same method on 4.1 |
| 4 | **Built as TC-1.** `Time#change` on a `Time` with a zone object raises `TZInfo::AmbiguousTime` in the hour repeated when clocks are set back (every TZInfo zone; `ActiveSupport::TimeZone` when both occurrences share a DST flag, e.g. Moscow 2014), including Active Model's precision cast (`change(nsec:)`); where the AS zone's DST occurrence is the later one (Dublin, Casablanca) it moves the time by an hour. Present on 8-1-stable and main; no rails/rails issue (closed #44226 is a different TZInfo symptom). | Active Support `Time#change` (free: a bug, not a C13 speedup) | [common paths 2](rails-common-paths-2.md#rejected-and-not-built) | Present; fixed on branch, see [TC-1](#tc-1-keep-the-utc-offset-in-timechange-for-times-with-a-zone-object) |
| 5 | Our merged PRs' internal-only differences: #59538 frozen `payload[:binds]` with `prepared_statements: false` (a subscriber that mutates it gets `FrozenError`), #59536 `collect_warnings` overrides that `super.push`, #59562 subclasses defining `event_method_names`, #59560 non-`HashLookupTypeMap` PG type maps, #59537 external `tag_string(name, content, options)` callers, #59571 scope arity −1 → 0, #59316 `extend`-added `match`, #59535 `fetch` arity message. | AR / AS / AV / AP | [merged-audit](merged-audit.md#leads-behavior-differences-only-internals-or-introspection-can-see) | All present; nobody has reported one. Fix recipes are in the audit (e.g. #59538: pass `[]` again in `exec_main_query`) |
| 6 | `render formats: [:html, :bogus]` raises only on the renderer path (`prepend_formats` validates, the controller path doesn't). | Action View (free) | [actionview-cpu](actionview-cpu.md#rejected-and-leads) | Present; inconsistency, not reported |
| 7 | rails/rails#59141 (tenderlove, open) broke Lobsters boot through activerecord-typedstore 1.6.0 (`store … accessors:` plus `define_attribute_method`) at `6df1ebd`. | Active Record (open PR) | [activerecord-cpu](activerecord-cpu.md) | Not on main; not rechecked at the PR's head `e5dc0b4338` |
| 8 | Main breaks a JSON escape edge only a singleton no-op `gsub!` reaches (`<>&` and U+2028/9 left literal). | Active Support | [serialization-cpu](serialization-cpu.md) | Present; contrived, accepted |
| 9 | Rails' own suites: Active Record assertion totals vary between runs with a fixed seed (36,542–36,591, per-test counts identical); `MemCacheStoreTest` and `BacktraceCleanerCleanLocationsTest` fail with two workers sharing services; Action Pack reports 282 "missing assertions" with `PARALLEL_WORKERS=1`; four SQLite rake tests need the `sqlite3` CLI. | test infrastructure | [census 3](rails-main-census-3.md), [R7](rails-r7-queue.md#pins-and-method) | Not rechecked |
| 10 | Deliberate main changes that needed app edits: `Key::Mapping` rejects Discourse chat's composite foreign key, Rails' Sidekiq adapter removed (Lago), frozen `VALID_UNSCOPING_VALUES` (clickhouse-activerecord), `RemoteIp#filter_proxies` (Mastodon), `detach_from` on log subscribers. | various | [pg-census](pg-census.md) | Deliberate; no action |
| 11 | Ecosystem: CASA can't resolve on main (caxlsx 4.5.0 pins `marcel ~> 1.0`, Active Storage needs `~> 2.0`; fixed on caxlsx master, unreleased); RubyGems 4.1.0.beta3 loads `"---\n"` as nil and crashes Bundler 4.0.2x (ruby/rubygems#10017, open); a ZJIT segfault in CASA (`vm_lookup_cc` from `tag_options`, 1 of 15 processes, not reproduced). | gems / Ruby | [census 4](rails-main-census-4.md), [F1](frontier-census-f1.md), [pg-census](pg-census.md) | Open upstream or unreproduced |

The census 5 note that `capture_helper.rb:59` `yield(*, **)` allocates an Array per `capture` in the interpreter
does not reproduce standalone on 4.0.9 or master (0 extra objects interpreted; YJIT allocates the empty rest, the
closed ruby/ruby#19655 case), so it is not listed.

## Leads whose disposition changed upstream

* R2-4 rechecked 2026-11-04 ([`r24_capture_rest.rb`](../../bench/upstream/census_backlog/r24_capture_rest.rb)): `def b(*) = yield(*)` allocates 0 objects per call interpreted on 4.0.9 and master, but 0.97 with YJIT and ZJIT, while `(*args)` allocates 1 everywhere. With ruby/ruby#19655 closed, the change would save the Array only in the interpreter, permanently; the [common paths](rails-common-paths.md#rejected-and-not-built) rejection stands and nothing was built.
* R2-4 (`OutputBuffer#capture(*)`) was held until ruby/ruby#19655; #19655 was closed unmerged on 2026-11-04, so
  YJIT and ZJIT keep allocating the empty rest and the interpreter-only gain is permanent. The common-paths
  rejection stands.
* The `where!(opts, *rest)` VM lead (census 6 ranks 55/62, census 7 ranks 37/51, census 5 rank 96) was fixed
  Rails-side by kamipo in 401f146f41 (#59579).
* C7-1 (our closed #59577) is covered by kamipo's #59590 (63cf73e451, 2c8de94e54).
* `Time#change` Rationals: czj's 08ccbcbfbf (#59323) covers `usec == 0`; the non-zero path keeps the framework
  census's rejection (1 of 15 objects).
* Stale text in source docs, corrected on 2026-11-04 with dated status lines: R6-1 (merged as #59571), R7-3 (merged as
  #59583), schema-context (merged as #59585), census 3's C3 and census 5's C15 holds (merged as #59536 and #59554),
  and the framework census's once-campfire#374 (open, not merged).

## Why only one candidate

Outside C9–C13 the remaining leads are: `prepend_formats` (L2, about 6 apps, most of the cost is required
validation), the json-gem option (a feature that needs the maintainer's interest first), `useragent` (inactive
maintainer), Action Text's `reverse_merge` (about 2 calls per op), and R2-4 and the other Action View sites, which
keep their recorded rejections. None passes effect × breadth ÷ risk against the bar for a Rails slot, so this round
builds only TH-1. The highest-scoring leads for the area owners are C6-2 (C11, ready once #59564 merges), the
fanout subscription list (C13, unattempted) and V1-C2 (C13, a design question for maintainers).

## TH-1: restore the template handler lookup methods

Opened as [rails/rails#59606](https://github.com/rails/rails/pull/59606) on 2026-11-04 from
[`thomasklemm/template-handler-readers`](https://github.com/thomasklemm/rails/tree/thomasklemm/template-handler-readers)
@ `5b24d5490e` on rails/rails main `9b116f1fed`, one commit authored and committed by Thomas Klemm; the commit is in
[`patches/th1-template-handler-readers.patch`](../../bench/upstream/census_backlog/patches/th1-template-handler-readers.patch)
(`git am` onto `9b116f1fed`). Lib +12, test +19.

**What broke.** #57874 moved the registry into frozen module instance variables on `ActionView::Template::Handlers`
and kept `register_template_handler`, `unregister_template_handler` and `handler_for_extension` on
`ActionView::Template` as delegators. Three methods that 8.1 has were dropped without a deprecation or CHANGELOG
entry, and nothing in the PR discussion mentions removing them. The removal is unreleased.

**Change.** The three methods come back as delegations to the registry, like the methods #57874 kept:

```ruby
def template_handler_extensions
  Handlers.extensions.map(&:to_s).sort
end

def registered_template_handler(extension)
  extension && Handlers.template_handlers[extension.to_sym]
end

def register_default_template_handler(extension, handler)
  Handlers.register_default(extension, handler)
end
```

`handler_for_extension` and every render path are unchanged. Two differences from 8.1 remain, both from #57874's
rewrite and both left as they are: `handler_for_extension` no longer calls `registered_template_handler` (an
override of the latter no longer changes template lookup; calling it would add a method call to every lookup),
and `register_default_template_handler` no longer goes through `register_template_handler` (the built-in handlers
already skip it since #57874).

**Evidence.**

* Repro ([`th_repro.rb`](../../bench/upstream/census_backlog/th_repro.rb), a `.md` template whose two-argument
  handler gets the ERB handler with `registered_template_handler(:erb)`, as maildown's does): 8-1-stable renders `"HELLO 2"`; main raises
  `ActionView::Template::Error: undefined method 'registered_template_handler' for class ActionView::Template`;
  the branch renders `"HELLO 2"` on 4.0.9 and on master with ZJIT.
* maildown 3.3.1's real handler ([`th_maildown.rb`](../../bench/upstream/census_backlog/th_maildown.rb)): main fails
  at the lookup; 8-1-stable and the branch both get past it and stop at the same later point (maildown's
  `valid_encoding?` call on an `OutputBuffer` in this bare-view harness, which is not a Rails change).
* Differential against 8-1-stable ([`th_diff.rb`](../../bench/upstream/census_backlog/th_diff.rb)): Symbol, String,
  `nil`, `false`, unknown, empty, an object with a public `to_sym`, one with a private `to_sym`, a String subclass
  with its own `to_sym`, Integer and plain Object extensions; extension lists after register and unregister, fresh
  unfrozen Arrays; default handler after `register_default_template_handler` with a Symbol and a String, `nil`
  extension, unregistering the default; argument errors and arities. Output identical to 8-1-stable under the
  4.0.9 interpreter, 4.0.9 YJIT, the master interpreter and master ZJIT (threshold 1). The readers also work
  from a non-main Ractor on 4.0.9.
* Tests: the four new tests fail on main with `NoMethodError` and pass on the branch; Action View `rake test`
  2,948 + 251 + 177 runs, 0 failures (Ruby 4.0.9); RuboCop clean.

Instructions per call, Callgrind as in [common paths 2](rails-common-paths-2.md#pins-and-method) (3,000 calls
after 3,000 warmup, GC disabled, medians of three runs; [`micro_th.rb`](../../bench/upstream/census_backlog/micro_th.rb),
[raw table](data/census-backlog/th1-callgrind.txt)). Ruby 4.0.9 for interpreter and YJIT, master `9aa0898240` for
interpreter and ZJIT. Objects per render unchanged (47). Everything is within the A/A, as expected for a change that
only adds methods:

| Case | Mode | main | A/A | TH-1 |
| --- | --- | ---: | ---: | ---: |
| `view.render(template:)`, a two-tag ERB template | interpreter 4.0.9 | 163,921 | +0.10% | +0.15% |
| | YJIT 4.0.9 | 92,446 | +0.14% | −0.01% |
| | interpreter master | 167,248 | +0.07% | −0.12% |
| | ZJIT master | 96,639 | −0.07% | −0.00% |
| `Template.handler_for_extension(:erb)` | interpreter 4.0.9 | 1,511 | −0.13% | +0.00% |
| | YJIT 4.0.9 | 1,313 | −0.13% | −0.09% |
| | interpreter master | 1,605 | +0.00% | +0.00% |
| | ZJIT master | 1,441 | +0.26% | +0.14% |

### Exactness checklist (TH-1)

1. Singleton methods and `method_missing` on the extension: the only call made on it is `to_sym`, as in 8.1;
   public, private (raises `NoMethodError` in both) and String-subclass cases are in the differential.
2. Subclasses of Hash/Array/String: the registry is Rails' own frozen Hash; String-subclass extensions covered.
3. Implicit conversions: none added; `to_sym` explicit, same call count as 8.1 (one).
4. Calls added on user objects: none beyond 8.1's `to_sym`; handlers are returned, never called.
5. Results copied as before: `template_handler_extensions` returns a new Array of new Strings per call, as 8.1.
6. Mutation during iteration: the registry is copy-on-write and frozen; nothing iterates user data.
7. Frozen values and exceptions: same exception classes for wrong arity, missing `to_sym`, `nil` default
   extension; results not frozen, as 8.1.
8. Load order: the methods live where `register_template_handler` does and need no new constant; standalone
   `require "action_view"` works (the repro scripts load it that way).

Interpreter, YJIT and ZJIT outputs of the differential are identical to each other and to 8-1-stable.

### Review

Readability L0: three one-line delegations, written like the methods #57874 kept.

Primary review on both rubrics by a separate subagent (codex is not available in this orb, as in the common-paths
rounds): correctness **approve**, maintainability **approve-with-nits**, L0. It reran the differential, added
cases ([`th_diff2.rb`](../../bench/upstream/census_backlog/th_diff2.rb): `register_default_template_handler`
returns and stores the passed handler, returned Strings and Arrays are not shared, capturing lambdas, Handlers
subclasses) and a clean-process Ractor check ([`th_ractor.rb`](../../bench/upstream/census_backlog/th_ractor.rb):
8-1-stable raises in a non-main Ractor because of its class variables, the branch reads; registering from a Ractor
fails on both), and confirmed each new test fails without the change. It found the two #57874 differences above
and recommended leaving them, and a plain restore over a deprecation (the removal was never released, the commit
message of #57874 doesn't mention it, and `handler_for_extension` isn't a replacement because it falls back to the
default handler). A third subagent read the PR body against this page as an outsider: it found that Loomio's
handler takes one argument (8.1 already raises `ArgumentError` for it) and that Loomio has no `.md` views, so Loomio
was dropped as evidence; that "same bodies as 8.1" was wrong for two of the methods; that the body named only one
of the two differences; and that it led with history. The body was rewritten from its suggestion. Nits applied: the parameter is named `handler` like `Handlers.register_default`'s, the nil test
is its own test, and the commit title names the class. Not a critical change in the DECISIONS sense (no escaping,
connections, records, caching, thread state or VM code), so no adversarial round.

### Second review and fix (2026-11-04)

Sol, in the coordinating thread, approved the restoration with one exactness fix: `register_default_template_handler`
passed the extension to `Handlers.register_default`, which converts it with `to_sym` twice (once to register, once
to fetch the default), while 8.1 converted it once. The earlier checklist claim of one call was wrong for this method.
It now passes `extension.to_sym`, and a test with a stateful `to_sym` fails without the fix. The tests also cover
`nil`/`false` lookups, a fresh mutable Array of Strings from `template_handler_extensions`, and default registration
with `unshareable_proc_action: :raise` (registry and default shareable, the method returns the stored default). The
differential gained the stateful converter (one `to_sym` call for both methods) and is still identical to
8-1-stable in all four modes; Action View `rake test` 2,950 + 251 + 177 runs, 0 failures. A separate subagent
re-reviewed the diff and body: code approve, body approve-with-nits (name which methods take an extension, state the
`unshareable_proc_action` copy, give the reason the two differences stay), all applied.

### PR body (as opened)

Title: **Restore three ActionView::Template handler methods removed in #57874**

> On main, a template handler that calls `ActionView::Template.registered_template_handler(:erb)` raises `ActionView::Template::Error` (undefined method `registered_template_handler`) the first time a template using it is compiled; 8.1 renders the same template. maildown 3.3.1's Markdown handler does this. #57874 moved the template handler registry onto `ActionView::Template::Handlers` and kept `register_template_handler`, `unregister_template_handler` and `handler_for_extension` on `ActionView::Template`, but dropped `registered_template_handler`, `template_handler_extensions` and `register_default_template_handler`.
>
> This restores the three methods as delegations to `Handlers`. For the extension values 8.1 accepted, they return the same results as 8.1, and `registered_template_handler` and `register_default_template_handler` call `to_sym` on the extension once, as 8.1 did. The one change: when `unshareable_proc_action` is set, a Proc passed to `register_default_template_handler` is stored as its shareable copy, as `register_template_handler` already does, and the method returns that stored handler. Two differences introduced by #57874 are left alone, since they only matter to code that overrides one of these methods: `handler_for_extension` no longer calls `registered_template_handler`, and `register_default_template_handler` no longer calls `register_template_handler`. The removal hasn't been released, so there is no CHANGELOG entry.
>
> I found this while running open-source Rails apps against Rails main for my research project, [Lowrail](https://github.com/thomasklemm/lowrail).

## TC-1: keep the UTC offset in `Time#change` for times with a zone object

Branch [`thomasklemm/time-change-zone-offset`](https://github.com/thomasklemm/rails/tree/thomasklemm/time-change-zone-offset)
@ `553f9267ee` on rails/rails main `aa236fc09b`, opened as [#59617](https://github.com/rails/rails/pull/59617)
on 2026-11-04 14:01 UTC by the coordinator (GitHub had refused PR creation for the account that afternoon);
patch in [`patches/tc1-time-change-zone-offset.patch`](../../bench/upstream/census_backlog/patches/tc1-time-change-zone-offset.patch).
Lib +8/−15 in `Time#change`, five Active Support tests and one Active Model test, a CHANGELOG entry.

**Is it a real bug?** Yes, on 8-1-stable and main alike ([`tz_change.rb`](../../bench/upstream/census_backlog/tz_change.rb)):
a `Time` from `getlocal(TZInfo::Timezone.get("Europe/Berlin"))` at 02:30 on 2026-10-25 raises `TZInfo::AmbiguousTime`
for `change(nsec:)`, `change(hour: 2)` and `ActiveModel::Type::DateTime.new(precision: 6).cast`. Ruby's
`Time.new(..., zone)` calls `zone.local_to_utc`, which TZInfo raises for an ambiguous local time; b191a65850 (#46251)
only handled zones that resolve the hour. `ActiveSupport::TimeZone` raises too when both occurrences share a DST flag
(Moscow 2014-10-26), and picks the wrong occurrence where its DST period is the later one (Europe/Dublin every year,
Casablanca, Windhoek, 1940s transitions). Active Record's time-zone-aware attributes convert with `in_time_zone`
first, so default models probably don't reach it (read from code, not run). Search: no open or closed rails/rails
issue or PR on `AmbiguousTime` with `change`; #44226 (closed, stale) is a different TZInfo symptom.

**Described in plain sentences (one per line of the branch):**

* Build the requested local fields at this time's UTC offset and convert that instant into the zone.
* If the zone gives that instant the same offset, return it: it has the requested fields, and in a repeated hour it
  is the occurrence matching this time.
* Otherwise let the zone pick the offset for the requested fields, as before.

`Time.utc(fields) - utc_offset` is used instead of `Time.new(fields, utc_offset)` because the latter has Ruby's
day-overflow bug (`Time.new(2026, 4, 31, 20, 0, 0, -14400)` is 2026-03-30; related to Bug #21301).

**Exactness.** Differential [`tz_diff.rb`](../../bench/upstream/census_backlog/tz_diff.rb) with
[`tz_compare.py`](../../bench/upstream/census_backlog/tz_compare.py): 246,924 cases (nine zones as TZInfo and
`ActiveSupport::TimeZone`, a minimal protocol zone, 18 option sets, instants around each 2026 transition plus 1890
and 2011 Apia): differences only where main raised `AmbiguousTime` (614) or picked the other Dublin occurrence (36);
identical across 4.0.9 interpreter and YJIT and master interpreter and ZJIT. Primary reviewer's
[`edge.rb`](../../bench/upstream/census_backlog/tc1_reviews/edge.rb) (LMT offsets, Apia/Kiritimati date-line skips,
spring gaps, 48 option sets incl. overflow, huge and negative years, `:offset`, callers `beginning_of_*`, `advance`,
the Active Model cast, subclass and frozen receivers, singleton overrides, protocol-only zones), identical under four
system `TZ` values; exception classes and messages unchanged ([`errs.rb`](../../bench/upstream/census_backlog/tc1_reviews/errs.rb)).
Adversarial round ([`all_transitions.rb`](../../bench/upstream/census_backlog/tc1_reviews/all_transitions.rb),
465,528 cases per tree over every tzdata transition up to 2037; [`gap.rb`](../../bench/upstream/census_backlog/tc1_reviews/gap.rb)
630,080 spring-gap cases identical; [`ar.rb`](../../bench/upstream/census_backlog/tc1_reviews/ar.rb) SQLite precision
0/3/6/nil with time-zone-aware attributes on and off): every difference is main raising or main returning the other
occurrence. Sol found that a custom zone whose `utc_to_local` raises for instants before 2026 makes the branch raise
where main returns (the probe at the original offset lands on 2025-12-31); accepted without a rescue, so the claim is
limited to zones whose `utc_to_local` covers the instants near the requested one (TZInfo and `ActiveSupport::TimeZone`
do). Non-canonical fields normalise differently: `change(sec: 60)` shows 14:01:00 where main shows its cached
14:00:60, with the same `to_r`. Accepted: a zone object whose `utc_to_local` and
`local_to_utc` contradict each other can give a different (no more wrong) answer
([`odd.rb`](../../bench/upstream/census_backlog/tc1_reviews/odd.rb)); the branch now calls `zone.utc_to_local` where
main called `local_to_utc` ([`calls.rb`](../../bench/upstream/census_backlog/tc1_reviews/calls.rb)); a numeric
argument with a side-effecting `to_int` can be converted twice on the fallback. Checklist items 1–8 covered by
these runs (overrides on the receiver, subclasses, conversions, calls on user zones, frozen receivers, exceptions;
no new constants or requires). Tests: both new tests fail on main (one `AmbiguousTime` error, one wrong offset);
`time_ext_test.rb` 178 runs, Active Support suite without cache stores identical to main (4,739 vs 4,737 runs; the
same two `BacktraceCleanerCleanLocationsTest` failures on both), Active Model type tests and Active Record time,
timestamp and attribute-method tests on SQLite pass.

**Cost** (Callgrind, [raw](data/census-backlog/tc1-callgrind.txt), [`micro_tz.rb`](../../bench/upstream/census_backlog/micro_tz.rb)):

| Case | interp 4.0.9 | YJIT 4.0.9 | interp master | ZJIT master |
| --- | ---: | ---: | ---: | ---: |
| `change(nsec:)`, `ActiveSupport::TimeZone` zone | +11.6% | +22.3% | +8.1% | +7.7% |
| `change(nsec:)`, TZInfo zone | +6.2% | +16.1% | +2.4% | +2.7% |
| `change(month: 1)` from July (offset changes) | +104% | +118% | +101% | +98% |
| TimeWithZone precision cast | −0.01% | −0.01% | +0.01% | −0.19% |
| local Time `change(hour: 0)` | +0.04% | +0.08% | +0.18% | −0.46% |

A/A ≤ 0.29%. Objects per `change` 25 → 28–29 on zone-object Times. The primary reviewer found no equally exact
cheaper form (`Time.new` with an Integer offset has the overflow bug; `localtime` saves 0.4%). Correctness over
speed: the slow path is a `Time` with a zone object, not what Rails hands out (`TimeWithZone`).

**Readability.** L1. Cold read (adversarial reviewer, before the message): each branch stated in one sentence; the
candidate line took a second read, so the comment now says why equal offsets mean the fields are right. Shape: one
branch per case, no reassignment in a condition (the old `(new_time_2 = ...)` is gone), no ternary, no single-use
name. flog `Time#change` 79.1 → 78.2; RuboCop ABC 54.43 → 53.98, cyclomatic 17 → 16, perceived 20 → 19, method
length 32 → 31.

**Reviews.** Primary (subagent): correctness approve, maintainability approve-with-nits (comment said "DST ended",
now "clocks were set back"; CHANGELOG added; commit message states the remaining TZInfo raise). Adversarial
(subagent, critical because it is typecasting): approve, no regression demonstrated. Outsider read of the body:
rewrite; done (Moscow and Casablanca added, Active Model wording narrowed, the doubled cost on the fallback stated).
Sol round (coordinator): open after fixes. Added the `ActiveSupport::TimeZone` Moscow 2014 test (21:30 and 22:30 UTC,
the two 01:30 occurrences), a `change(nsec:)` test with a fraction that checks fraction and instant, and an Active
Model precision-3 cast test that truncates; all three fail on main. Wording: "TZInfo's default ambiguity settings",
"when precision truncation is needed", the remaining `AmbiguousTime` and `PeriodNotFound` limits in CHANGELOG and
body, the differential claim limited to what was tested. Rebased onto `9cf3693a0a` (contains `1ca7528bac`);
`git merge-tree` clean; `time_ext_test.rb` 180 runs, 0 failures; Active Support suite unchanged against main.
Overlap search: no open PR on `AmbiguousTime` or `core_ext/time/calculations`; #59420 and #59475 touch only
`TimeWithZone`, #45902 (2022) only validates option keys.

### Tests for both clock changes (2026-11-04, head `553f9267ee`)

Thomas asked for tests covering both clock directions. New method `test_change_uses_the_zones_offset_around_start_of_dst_for_times_with_a_zone_object`, run for a `TZInfo::Timezone` and an `ActiveSupport::TimeZone` (Europe/Berlin, 2026-03-29): `change(hour: 2, min: 30)` into the skipped hour raises `TZInfo::PeriodNotFound` for both (measured on main, [`spring.rb`](../../bench/upstream/census_backlog/tc1_reviews/spring.rb): a `Time` with an `ActiveSupport::TimeZone` raises, unlike `TimeWithZone`, which shifts forward); `change(min: 0)` at 01:30 +0100 and 03:30 +0200 keeps the offset; `change(month: 7)` from January and `change(month: 1)` from July take the zone's new offset. Passes on main and the branch (guards for the fallback). Two wrong implementations fail it: keeping the probe without the offset check (also caught by three existing tests) and a fallback at the probe's offset instead of the zone (`Time.new(..., new_time.utc_offset)`; caught by nothing else in the file). Dropped as already covered or not able to catch a plausible mistake: fall-back from the second occurrence (US/Eastern, Berlin TZInfo, Dublin and Moscow tests), `change(hour:)` into and out of the repeated hour (US/Eastern test), Lord_Howe's 30-minute change (existing fractional-hour test), southern hemisphere (Lord_Howe; the logic has no hemisphere-specific step), `change(day:)` across a transition (same fallback as `month:`), the Active Model cast (already in the PR, precision 3 truncates). Rebased onto `aa236fc09b`; `time_ext_test.rb` 181 runs, `time_with_zone_test.rb`, `date_time_ext_test.rb`, `date_ext_test.rb`, `time_zone_test.rb`, `duration_test.rb`, compatibility and Active Model `date_time_test.rb` pass; RuboCop clean. Code unchanged, so no new Sol round.

### PR body (as posted)

Rewritten by the coordinator for Thomas after opening (no cost numbers, per DECISIONS "Correctness PRs carry no performance numbers"; the `utc_to_local` scope clause is kept for a maintainer question); last clause added with the test change. 193 words.

Title: **Keep the UTC offset in Time#change for times with a zone object**

> On a `Time` whose zone is an object (`TZInfo::Timezone` or `ActiveSupport::TimeZone`), `change` couldn't stay in the hour that repeats when clocks go back. TZInfo zones raised `TZInfo::AmbiguousTime`, also from Active Model's datetime cast when it truncates precision. `ActiveSupport::TimeZone` could jump to the other occurrence of that hour.
>
> `change` now tries the time's own UTC offset first and keeps it when the zone agrees. Otherwise the zone decides, as before.
>
> At 00:30 UTC on 2026-10-25, both zones are in the first of two identical local hours:
>
> | Zone | Start | `change(sec: 1)` on main | With this PR |
> | --- | --- | --- | --- |
> | Berlin, `TZInfo::Timezone` | 02:30:00 +0200 | raises `AmbiguousTime` | 02:30:01 +0200 |
> | Dublin, `ActiveSupport::TimeZone` | 01:30:00 +0100 | 01:30:01 +0000, an hour later | 01:30:01 +0100 |
>
> Still unchanged: an ambiguous time raises when neither occurrence has the original offset, and a time in the skipped spring hour raises `PeriodNotFound`.
>
> Compared with main for every TZInfo and `ActiveSupport::TimeZone` zone around each transition up to 2037, results differ only where main raised or picked the other occurrence, and the tests cover both clock changes.
