# Performance round on Rails main (2026-11-05)

This round looked for rails/rails performance PRs where main still costs more than 8-1-stable
[`6e09124217`](https://github.com/rails/rails/commit/6e091242176c322edc5a8907583c01b08b8a60bc). Three follow-up
topics were added during the round: QueryIntent's slot size on Ruby master, a search for #18345-class hash spills,
and the cost of the Rails 8.1.1 → 8.1.4.1 bump in ruby-bench. The candidates are built, reviewed and measured, but
not opened: the rails/rails queue is full, so they go into the [PR queue](../../bench/upstream/pr-queue/items)
behind the correctness PRs already waiting there.

**Result: three candidates, A–C.** One more was built and rejected (D), and the other starting points are recorded
below with their numbers.

| rank | candidate | branch @ commit | effect | readability | review |
| ---: | --- | --- | --- | --- | --- |
| A | QueryIntent keeps its background session and mutex in one `AsyncState` | [`thomasklemm/query-intent-async-state`](https://github.com/thomasklemm/rails/tree/thomasklemm/query-intent-async-state) [`5e26a026f1`](https://github.com/thomasklemm/rails/commit/5e26a026f1180469fca5172c7382da7d02602277) on main `1e235cee11` | Ruby master: every intent goes from a 512-byte to a 256-byte slot, −256 B per query; objects unchanged | L1 | skeptic: approve; Sol and Astra pending on this head |
| B (not opened) | `tag_options` skips the second blank check when the name is the key | [`thomasklemm/tag-options-blank-once`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-options-blank-once) `ddd44b197e` (rebase of `2dc1231b26`) | the shortcut saves −2.0% per String-key tag call but is not exact; the exact form is main's code | – | closed: [below](#refresh-on-main-1e235cee11-2026-11-05-evening) |
| C | `EventReporter::LogSubscriber#emit`/`#consumes?` read the logger once | [`thomasklemm/log-subscriber-logger-once`](https://github.com/thomasklemm/rails/tree/thomasklemm/log-subscriber-logger-once) [`defa5dc860`](https://github.com/thomasklemm/rails/commit/defa5dc8602281d03db9d65770e9f749fd1931e5) on main `1e235cee11` | `consumes?` −17.3%, `emitting?` −13.1% per call (app-free case) | L0 | skeptic: approve; Sol pending on this head |
| D (rejected) | `connection_handler` checks for the main Ractor first | not pushed; [patch](../../bench/upstream/perf_round/patches/rejected/connection-handler-main-ractor.patch) | −188 Ir per call (−6%), ≈0.055% of shipit | – | don't ship: breaks the `sqlite3_ractor` test hook |

Queue items (metadata, passes and the body as posted): [PM1](../../bench/upstream/pr-queue/items/PM1.md),
[PM2](../../bench/upstream/pr-queue/items/PM2.md), [PM3](../../bench/upstream/pr-queue/items/PM3.md). Patches are in
[`bench/upstream/perf_round/patches`](../../bench/upstream/perf_round/patches). Queue ranks: A 11, C 13; B is closed
(not exact, and the exact form saves nothing), so there is no 8-1-stable backport either.

## Pins and method

* **Rails main** [`bdb3d96012`](https://github.com/rails/rails/commit/bdb3d960121e7eb73a61c04099d1eef3c821e397)
  (2026-11-05 10:34 +0100; still main at the last fetch). Profiling started on `61f15cb68f`, three small merges
  earlier. Each branch is one commit on `bdb3d96012`. A second worktree of the same commit (`m2`) is the A/A.
  8-1-stable is `6e09124217`; the Rails 8.1 tags are `v8.1.1` and `v8.1.4.1`.
* **Ruby 4.0.9** (the pin) and **Ruby master
  [`a041273a4c`](https://github.com/ruby/ruby/commit/a041273a4c9606e6c7aaaefa36ad9d7b2d5a1e72)** (4.1.0dev,
  2026-11-05) as the second column.
* **ruby-bench** railsbench, lobsters, shipit and erubi-rails, with one Gemfile per Rails tree
  ([`mkvariant.sh`](../../bench/upstream/perf_round/mkvariant.sh),
  [`mkvariant-master.sh`](../../bench/upstream/perf_round/mkvariant-master.sh)); lobsters and shipit set
  `erb_implementation = :erubi` (and lobsters the legacy CSRF token strategy) on 8.2, as in census 4.
* **Instructions per iteration**: `ruby_bench_ir.rb` with cachegrind, interpreter, fixed heap
  (`RUBY_GC_HEAP_0..4_INIT_SLOTS` from [bench.md](../bench.md)), a 1-iteration and a 4-iteration run per variant,
  window = (4 − 1) / 3 ([`run-ir.sh`](../../bench/upstream/perf_round/run-ir.sh)). **Method-level attribution**:
  sampled Callgrind windows ([`cg.sh`](../../bench/upstream/perf_round/cg.sh)) diffed with
  [`cg_diff.rb`](../../bench/upstream/rails_82_impact/cg_diff.rb), with a second process of the base tree as A/A.
  **Per call**: [`irm.sh`](../../bench/upstream/perf_round/irm.sh) /
  [`irm.rb`](../../bench/upstream/perf_round/irm.rb), Callgrind toggled on the timed loop, 2,000 calls, GC disabled,
  [case files](../../bench/upstream/perf_round/cases). **Memory**: heap slot bytes and objects per iteration from
  `GC.stat_heap` ([`by.sh`](../../bench/upstream/perf_round/by.sh),
  [`harness-bytes.rb`](../../bench/upstream/perf_round/harness-bytes.rb)), 10 iterations after 3 warmups, fixed heap.
  **Call counts**: [`cc.sh`](../../bench/upstream/perf_round/cc.sh) (TracePoint, one iteration).
* **A/A at the whole-benchmark level is wide.** On 4.0.9 railsbench main against main moved by up to 0.15%, and
  lobsters had single runs at +1.2% and +1.8% (an extra GC in the window); on master railsbench moved by 0.86%. B
  and C save about 0.16–0.18% of a railsbench iteration, below that spread, so their effect is claimed from the
  method-level windows and per-call counts, where the A/A is 1–5% of the effect. A's effect is memory, where the A/A
  is under 0.005%.
* YJIT was not measured; no YJIT claims are made.
* **Reviews**: one skeptical reviewer subagent per candidate, rerun after each rewrite. The Sol review was not
  available (`/tmp/sol` is absent in this orb). Readability gate per [DECISIONS](../DECISIONS.md#readability-gate-l0l3):
  description out loud, cold read by the reviewer, flog and RuboCop `Metrics/*` before and after, and Rails' own
  RuboCop config (clean on all three).
* **Overlap**: `gh search prs --repo rails/rails --author thomasklemm --state open` (15 open; none touch these
  files) and searches for others' PRs on each file. `git merge-tree` of each branch against the heads of #59499,
  #56596, #47163, #57089, #58801, #59530, #58957, #59500, #59628, #59569, #59564 and #59557 finds no conflict that
  main doesn't already have with those PRs.

## A. QueryIntent: background state in one object

**What it changes.** `QueryIntent#initialize` preset `@session = nil` and `@mutex = NullLock`
([L102–L103](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/query_intent.rb#L102-L103)),
which only an intent scheduled by `async_schedule!` uses. They move into `AsyncState = Struct.new(:session, :mutex)`
(comment: "Allocated only when scheduling an asynchronous query."), which `async_schedule!` creates; `initialize`
presets `@async = nil`. `@lock_wait` and `@event_buffer` stay plain preset ivars with their readers. The unused
`session` reader and `session=` writer (`:nodoc:`, added in 9051bc4332, unreleased) go away; that is the one API
difference.

**Instance variables per query shape** at the end of the query ([`qi_count.rb`](../../bench/upstream/perf_round/qi_count.rb),
Ruby master): on main `find`, `find_by`, `where.to_a`, `first`, `count`, `pluck`, `update_all`, `delete`,
`exec_query`, `select_all`, the three queries of a `transaction` and `load_async` all end with 31 (512 B), `execute`
with 30 (512 B); `initialize` sets 30. A plain Fizzy `Card.find` sets 31 (census 4). With A: 30 and 29, all 256 B,
`load_async` included (`AsyncState` adds one ivar and two are gone). A 256-byte slot holds up to 30 on master, so there is
no headroom left: the next eagerly set ivar brings back 512 B.

**Shapes** (measured on the lock_wait-in-struct version; the final one has one more ivar in the shared prefix). All intents share one 28-ivar prefix in the same order, then `@cast_result` or `@affected_rows`: three
layouts in load_async_test, asynchronous_queries_test, query_intent_test, log_subscriber_test and
ractor_connection_handling_test, no `-W:performance` shape warnings, nothing too complex. Main has the same three.

**Why not the first version.** v1 ([`e22f13be8b`](https://github.com/thomasklemm/rails/commit/e22f13be8b042ec80eb3218e3d030b583dfd9b62),
only dropping the four presets) gave foreground intents 27 ivars, but the reviewer showed that CRuby sizes new objects
by the class's highest ivar count so far. One `load_async` intent reached 31, and from then on every intent was 512
bytes again. Measured on master ([`qi_async.rb`](../../bench/upstream/perf_round/qi_async.rb)), memsize of a fresh
intent and bytes per `Post.find`:

| tree | before any async query | after one `load_async` |
| --- | --- | --- |
| main | 512 B; 4,088 B/find | 512 B; 4,104 B/find |
| v1 (drop presets) | 256 B; 3,832 B/find | **512 B** (async intents had 31 ivars) |
| A, lock wait in the struct (`9fabafcf8b`) | 256 B; 3,832 B/find | 256 B; 3,848 B/find (async intents 29) |
| A, final (`8e7de36dbc`) | 256 B; 3,832 B/find | 256 B; 3,848 B/find (async intents 30) |

On 4.0.9 every tree stays at 320 B; objects per find are the same in every tree (61.0 on master, 60.0 on 4.0.9). A
second rewrite kept `@event_buffer` out of the struct so that `ensure_result` and `execute_or_skip` are unchanged
apart from `@async` (`ensure_result` flog 27.2 in that version → 20.9, the same as main).

**Memory, ruby-bench per iteration, Ruby master**: heap slot bytes allocated (Σ slot size × objects allocated, from
`GC.stat_heap`), 3 warmups and 10 iterations, fixed heap; allocated bytes, not RSS. A/A within 0.005%; final tree:

| | main | main (A/A) | A | Δ |
| --- | ---: | ---: | ---: | ---: |
| railsbench slot bytes | 59,087,612 | 59,087,625 | 58,575,608 | −512,004 (−0.87%) |
| shipit slot bytes | 52,044,134 | 52,042,557 | 51,542,168 | −501,966 (−0.96%) |
| lobsters slot bytes | 33,485,554 | 33,484,234 | 33,214,610 | −270,944 (−0.81%) |
| objects (all three) | 946,167 / 870,310 / 528,848 | ±0.02% | 946,167 / 870,316 / 528,640 | approximately unchanged (lobsters −0.04%; each scheduled async intent allocates one struct) |

railsbench creates 2,000 intents per iteration, so −512,000 B is exactly 256 B each. On Ruby 4.0.9 slot bytes are
unchanged (railsbench 74,812,892 in both trees).

**Instructions.** `QueryIntent.new` 5,955 → 5,579 Ir per call on 4.0.9 (A/A 0); per query `find` 297,022 → 296,822,
`where.to_a` 434,577 → 434,295, `update_all` 414,835 → 414,516 (all within ±0.1%, A/A up to 0.04%). Whole-benchmark
windows: [below](#instructions-per-iteration-final-trees).

**Tests.** Active Record sqlite3 suite with `RAILS_STRICT_WARNINGS`: 10,289 runs, 0 failures, 0 errors, 52 skips;
`rake test_sqlite3_ractor`: 9,554 runs, 0 failures. No test added: the change is a refactor and a slot-size assertion
would be brittle across Rubies.

**Readability (L1).** Out loud: "An intent keeps its background session and mutex in one AsyncState, created when it
is scheduled. Without one it is a foreground intent: not pending, not canceled." (Metrics below are from the
lock-wait-in-struct version; the final one assigns `@lock_wait` as main does.)
Cold read by the reviewer: clear. Metrics, main → A: `initialize` flog 30.7 → 28.7, ABC 30.56 → 28.6; `execute_or_skip`
25.5 → 29.1, ABC 18.49 → 21 (two `@async.` reads); `pending?` 2.4 → 3.6; `canceled?` 2.6 → 4.0; `ensure_result`
unchanged. The rise in `execute_or_skip` is the `@async.session`/`@async.mutex` reads, the cost
of grouping the fields. Rails' RuboCop flagged `@async&.session.active?` (Lint/SafeNavigationChain); it is now
`@async && @async.session.active?`, like `canceled?`.

**Review.** First pass: ship with changes (v1's memory claim fails after one async query; stale comment; inaccurate
ivar counts in the message). Second pass on the `AsyncState` version: ship. Sol (gpt-6.1-sol, on patch and body):
request changes, [below](#sol-review-of-pm1pm3-2026-11-05). Third pass on the final version: ship (no path to 31 ivars;
`dup` shares the struct as main shared `@session` and `@mutex`, and nothing writes to it after creation).

**Overlap.** matthewd's draft #57089 (PostgreSQL pipelining) adds QueryIntent state; it conflicts with main in
several files already, and A adds no new conflict. #58801 touches `write_query?` only.

## B. `tag_options`: one blank check per attribute name

**What it changes.** Since the security fix 99a3247ebc (GHSA-68p9-83h6-5wpj, flavorjones; backported as 9190210606
in 8.1.4.1), `TagBuilder#tag_options` checks `key.blank?` and then `name.blank?` on the converted name
([L1548–L1551](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/tag_helper.rb#L1548-L1551)).
For a plain String key `to_s` returns the key itself, so `String#blank?` ran twice on the same object. Final version
(after Sol's review; the earlier shapes are below):

```ruby
next if key.blank?

if Symbol === key
  name = key.name
  next if name.blank?
else
  name = key.to_s
  # When to_s returns the key itself, its blank? was just checked.
  next if !name.equal?(key) && name.blank?
end
```

Nested `data`/`aria` keys keep both checks.

**Exactness of the final version.** Main's calls happen in main's order; the only call skipped is `name.blank?`
where `name` is the very object whose `blank?` just returned false. It differs from main only if `blank?` is impure
(answers differently for the same object; a String key now gets one `blank?` call fewer) or `equal?` is overridden,
which Ruby's docs forbid; the commit message says so. `tg_eq.rb` (432 lines) and Sol's repros render the same as
main. **The analysis below is of the previous version (`02f567ab81`).** Symbols: `Symbol#blank?` is `empty?`, and an empty Symbol's name is `""`. Plain Strings still go
through `to_s`, so a singleton or `extend`ed `to_s` is checked as converted. Every other key, String subclasses and
SafeBuffer included, gets both checks in the old order. [`tg_eq.rb`](../../bench/upstream/perf_round/tg_eq.rb) renders
48 kinds of keys × 9 values (Symbols, Strings with whitespace, `"\t\n"`, NBSP, binary `"\xff"`, UTF-16LE; SafeBuffer;
String subclasses overriding `to_s` or `blank?`; frozen Strings with singleton `to_s`/`blank?`; `nil`, `false`, `true`,
Integer, Array, Hash; objects with custom `blank?`/`to_s`) and matches main in all 432 lines, including the same
`Encoding::CompatibilityError` for the binary key. One difference remains by construction: a plain String key that
has *both* a singleton `blank?` returning true *and* a singleton `to_s` returning something non-blank was skipped on
main and is now emitted, with its escaped, non-blank name. The reviewer judged this not a security issue; it needs a
frozen String with two singleton methods as a Hash key.

**Two rejected shapes.** The first version (`case key when String then key`) took a String subclass as its own name,
so a subclass that is blank only once converted produced `<img ="…" />`, the markup the GHSA fixed; the second
(`elsif key.instance_of?(String) then name = key`) did the same for a plain String with a singleton `to_s`. Both were
found by the reviewer. Sol then showed the third shape (`02f567ab81`) still wasn't exact: it skipped `key.blank?` for
plain Strings and Symbols, so a frozen `" "` with a singleton `to_s` returning `"title"` rendered `title="hello"`
(main: `<img />`), a nonblank String with a singleton `blank?` returning true was emitted, a blank String whose `to_s`
raises now raised, and an overridden `Symbol#blank?` was ignored. All reproduced. The tests now cover these too (`test_tag_with_whitespace_string_attribute_name_is_skipped`,
`test_tag_with_string_attribute_name_that_converts_to_blank_is_skipped`), pass on main and fail on the second version.
The singleton case has to use a frozen String: a Hash copies an unfrozen String key and drops its singleton methods.

**Numbers.** Per call, Ruby 4.0.9 interpreter, railsbench app ([`cases/tg.rb`](../../bench/upstream/perf_round/cases/tg.rb)):

| | main | main (A/A) | final B | previous B (`02f567ab81`) |
| --- | ---: | ---: | ---: | ---: |
| `tag.a("x", href:, class:, data: { id: })` | 57,596 | 57,556 | 57,484 (−0.2%) | 56,671 (−1.5%) |
| `content_tag(:a, "x", "href" =>, "class" =>, "data" => { "id" => })` | 59,411 | 59,393 | 58,104 (−2.2%) | 58,354 (−1.7%) |
| `link_to("x", "/posts", class: "c")` | 42,422 | 42,082 | 41,413 (−2.4%; A/A 0.8%) | 41,549 |

Ruby master a041273a4c, final B: Symbol keys 54,651 → 54,483 (−0.3%, A/A 0.12%), String keys 57,039 → 55,924
(−2.0%, A/A 0.14%). The Symbol-key gain is gone (it came from skipping `key.blank?`); String keys keep theirs, and
`link_to` stringifies its html options, so its keys are Strings. Objects are unchanged. Per railsbench iteration
(9,057 `tag_options` calls; sampled window, A/A from a second main process), final B: `tag_options` inclusive −6.4M Ir
(A/A 0.38M), of which `String#blank?` self −8.7M (A/A 0.41M; the inclusive total is smaller because of sampling
noise across the window).

**Backport.** 8-1-stable has the same code (9190210606), and its `String#blank?` has no ASCII fast path, so the double
check costs more there: in railsbench, 8.1.1 → 8.1.4.1 added +51.8M Ir in `String#blank?` and +18.4M in
`tag_options` self per iteration. Worth proposing for 8-1-stable once it lands on main.

**Tests.** Action View suite on the final version: 2,957 + 251 + 177 runs, 0 failures; `tag_helper_test.rb` 110 runs,
285 assertions, which pass on main and fail on `02f567ab81`.

**Readability (L1).** Out loud: "Skip a blank key. Take a Symbol's name and skip it if blank. Otherwise convert the
key, and check the result unless it is the key itself, which was just checked." The identity check has its one-line
comment. The two lines become eight, with the name check written twice. Rails' RuboCop: clean.

**Review.** Three passes on earlier shapes: don't ship (String subclasses bypass the converted check), ship with
changes (singleton `to_s` on a plain String bypasses it), ship. Sol: request changes (the third shape still skipped
main's calls). Fourth pass on the final version: ship, disclose the purity assumption (done in the commit message).

**Overlap.** #59499 (popover), #56596 (boolean attribute values) and #47163 (`tag.attributes`) touch tag_helper.rb
elsewhere; no new conflicts. Our earlier
[actionview-tag-symbol-keys](actionview-tag-symbol-keys-pr.md) work changed the nested key conversion, not this
check.

## C. EventReporter::LogSubscriber: read the logger once

**What it changes.** `emit` and `consumes?`
([L56–L88](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activesupport/lib/active_support/event_reporter/log_subscriber.rb#L56-L88))
read `logger` for the nil check and again in `log_level_satisfied?`; each read goes `self.class.logger` →
`@logger || default_logger` → e.g. `ActionController::Base.logger`. They now read it once and pass it:
`log_level_satisfied?(logger, event_method)`. The class and `consumes?` are new on main (aebcb61520, 81d95a3f74);
none of the seven framework subclasses overrides these methods, and `log_level_satisfied?` is private and unreleased.

**Exactness.** Identical when `logger` returns the same object on both reads; otherwise the level check now uses the
logger from the nil check (disclosed in the body). The reviewer measured the only
difference: a logger that turns nil between the two reads used to raise `NoMethodError` (rescued and reported by the
event reporter), and now uses the logger already checked.

**Numbers.** Per call, railsbench app:

| | 4.0.9 main | 4.0.9 C | master main | master C |
| --- | ---: | ---: | ---: | ---: |
| `LogSubscriber#consumes?` | 13,789 | 11,621 (−15.7%) | 14,290 | 12,013 (−15.9%) |
| `EventReporter#emitting?` | 27,813 | 25,640 (−7.8%) | 29,259 | 26,946 (−7.9%) |

A/A within 0.03% (4.0.9) and 0.15% (master). Per railsbench iteration (4,000 `emitting?` calls): `consumes?` −8.5M Ir
(A/A 0.39M), `emitting?` −8.3M (A/A 0.29M). shipit and lobsters make 316 and 228 `consumes?` calls per iteration, so
their totals don't move.

**Tests.** activesupport event_reporter, event_reporter/log_subscriber and log_subscriber tests; the log subscriber
tests of Action Pack, Action View, Active Record, Active Job and Action Mailer: all green (reviewer reran them). No
test added (refactor).

**Readability (L0).** Out loud: "Read the logger; without one, do nothing; otherwise check the level on that logger."
`logger = self.logger` is a common Rails idiom. Metrics: `emit` flog 7.5 → 7.8, `consumes?` 5.1 → 5.2,
`log_level_satisfied?` 6.5 → 5.2.

**Review.** Ship. Notes: add numbers (they are in the body), mention the nil-race difference (in this doc).

**Lead, not built.** `emitting?` allocates `{ name: name }` per call for subscriber filter procs
([event_reporter.rb:385](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activesupport/lib/active_support/event_reporter.rb#L385));
it is the filter's argument, so it can't be shared without changing what filters receive.

**Overlap.** linyiru's #58957 calls `emitting?` from structured event subscribers; it doesn't touch this file and
gets cheaper with C.

## Sol review of PM1–PM3 (2026-11-05)

Sol (codex gpt-6.1-sol, read-only, on the patches and bodies) reviewed the queued heads `9fabafcf8b`, `02f567ab81` and
`cec8010a8b`. Each finding was checked against the code; repros: [`sol_pm1.rb`](../../bench/upstream/perf_round/sol_pm1.rb),
[`sol_pm2.rb`](../../bench/upstream/perf_round/sol_pm2.rb).

| # | finding | verdict | action |
| --- | --- | --- | --- |
| PM1-1 | `lock_wait` in the struct changes `dup` and `freeze`: after `dup`, `execute_or_wait` on the copy sets the original to 0.0 (main: stays 17); on a frozen intent it returns 0.0 instead of raising `FrozenError` | **confirmed** on master and 4.0.9 | `@lock_wait` stays a plain ivar; `AsyncState = Struct.new(:session, :mutex)`. 30 ivars still fit 256 B (measured); slot bytes unchanged within 0.002% |
| PM1-2 | removing `session`/`session=` is an API difference | confirmed (`:nodoc:`, unreleased) | the body says so |
| PM1-3 | objects not exactly unchanged; method for slot bytes | confirmed (lobsters −0.04%, one struct per scheduled intent) | "approximately unchanged", method described |
| PM1-4 | shorter struct comment, permalinks | applied | |
| PM2-1 | a frozen `" "` with singleton `to_s` → `"title"` renders `title="hello"`; singleton `blank?` → true is emitted; a blank key whose `to_s` raises now raises; tests don't cover blank → nonblank or raw `blank?` | **confirmed**, plus an overridden `Symbol#blank?` (ignored by `02f567ab81`) | rewritten to Sol's suggested exact form (main's order, skip only when `to_s` returned the key); two tests added |
| PM2-2 | `instance_of?` call main never makes; Symbol `blank?` dropped | confirmed for `02f567ab81` | gone in the final form |
| PM2-3 | body: "identical" claim, SHA links, the 9.3M sentence | applied | body states what the comparison showed; −6.4M `tag_options` inclusive replaces the `String#blank?` attribution |
| PM2 result | measure what is left | String keys −2.2% (4.0.9) / −2.0% (master); Symbol keys −0.2% / −0.3%, within noise | kept in the queue on the String-key gain and railsbench's −6.4M per iteration |
| PM3-1 | disclose that the level check uses the logger from the nil check | confirmed (a `logger` override returning different loggers) | in the body |
| PM3-2 | private helper arity changed; qualify the compatibility claim | confirmed | "the framework's subscribers … don't call the private helper" |
| PM3-3 | (27,813 − 25,640) × 4,000 = 8.69M, not 8.3M | confirmed (8.69M from per-call numbers, 8.3M from the sampled window) | the body attributes 8.3M to the sampled window, A/A 0.29M |
| PM3-4 | full-SHA links; "customize logger selection through `default_logger`" | applied | |

Rejected: none. A third skeptical-reviewer pass on the final PM1 and PM2 said ship for both.

## Refresh on main 1e235cee11 (2026-11-05, evening)

Rails main moved to [`1e235cee11`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa)
(inflector `match?`, `Array#index_with` docs; no overlap). All three branches rebased cleanly, and the numbers were
taken again on it, with Lowrail [`a06703e89d`](https://github.com/thomasklemm/lowrail/commit/a06703e89dd41af36cf7a923103be3e7ec7be9a5):
[`percall.sh`](../../bench/upstream/perf_round/percall.sh) (Callgrind on the timed loop only, 2,000 calls after
2,000 warmups, GC disabled, fixed heap, pinned Valgrind from `script/bench-valgrind`, inclusive Ir per call, 3
repetitions per tree, a second main checkout as A/A) with the app-free cases
[`tg_none.rb`](../../bench/upstream/perf_round/cases/tg_none.rb), [`er_none.rb`](../../bench/upstream/perf_round/cases/er_none.rb)
and [`qi.rb`](../../bench/upstream/perf_round/cases/qi.rb); slot bytes per query from
[`qi_bytes.rb`](../../bench/upstream/perf_round/qi_bytes.rb). Ruby 4.0.9, and Ruby master
[`2a3b7678ff`](https://github.com/ruby/ruby/commit/2a3b7678ff31dbe70f2131314aa34879559367db) for slot sizes.

* **PM1**, head `5e26a026f1`. Ruby master, bytes per query: `find` 4,088 → 3,832, `where.to_a` 5,592 → 5,336,
  `update_all` 5,120 → 4,864, `insert` 5,776 → 5,520, `exec_query` 2,176 → 1,920; A/A identical; objects unchanged.
  After a `load_async`, fresh and async intents stay at 256 B (main 512). Ruby 4.0.9: unchanged (320 B slot).
  `Post.find` Ir per call 316,608 / 316,759 / 316,580 (main), 316,581 / 316,786 (A/A), 316,412 / 316,384 (PM1): no
  CPU claim. Tests: AR sqlite3 suite with `RAILS_STRICT_WARNINGS`, 10,289 runs, 0 failures, 5 errors from the orb
  (no `sqlite3` CLI, no `pg`). Skeptic: nits (an internal corner — an async intent whose foreground fallback hits a
  bind `RangeError` and is read via `affected_rows` — reaches 31 ivars, main 32, so "29 or 30" became "one fewer at
  every point"; calling the private `execute_or_wait` with `send` on a foreground intent raises, unreachable). The
  ruby-bench slot-byte table above is from `bdb3d96012` and was not rerun; the body now uses the per-query table.
  `risky: true` (concurrency), so Astra as well as Sol. Skeptic on `5e26a026f1`: approve (link nit applied).
* **PM2: closed, not opened.** Main calls `key.blank?`, `key.to_s` and `name.blank?`, and a frozen String key keeps
  singleton overrides of each. [`pm2_exact.rb`](../../bench/upstream/perf_round/pm2_exact.rb) renders `<img />` on
  main and `<img ="x" />` on the branch for a `blank?` that answers false then true (also with `to_s` returning
  self, and for a converted blank String whose `equal?` always returns true). Skipping any of the three calls is
  observable, and reordering them is too, so the exact form is main's code. What the shortcut saved: `content_tag`
  with String keys 58,550 → 57,406 Ir per call (−2.0%, mean of 3; A/A 0.02%), `tag.a` with Symbol keys 56,728 →
  56,654 (noise). Reopen only if Rails decides `blank?` on attribute keys may be assumed pure.
* **PM3**, head `defa5dc860`. `ActionController::LogSubscriber#consumes?` 12,805 → 10,591 (−17.3%),
  `EventReporter#emitting?` 16,878 → 14,662 (−13.1%); main runs agree within 19 Ir (0.12%). The app-free case uses an
  info-level `ActiveSupport::Logger`, so the absolute numbers are lower than the railsbench-app ones above. Tests
  added for both methods with a `logger` that returns different loggers on successive calls (info then error, error
  then info, info then nil, nil then info), asserting one lookup and the predicate or dispatch result; the first three
  fail on main, nil-first documents the same behaviour. "On every request" is now "twice per action" (Action
  Controller's structured event subscriber, L10 and L30). activesupport suite without the Redis/memcache stores: 5,154
  runs, 0 failures (the two backtrace-cleaner failures come from loading all files through `-e` and pass on their
  own on both trees); Action Pack, Action View, Active Record, Active Job and Action Mailer log subscriber tests
  green. Skeptic: nits (add the info-then-nil case, list both commands), applied; approve on `defa5dc860` (the new
  cases raise `NoMethodError` on main).
* **Readability.** PM1 L1 (unchanged code; comment now "Background-only state, kept apart so that every intent stays
  small."). PM3 L0, no comments added. RuboCop clean on both.

## D (rejected). `connection_handler` asks `Ractors.main?` first

`ActiveRecord::Base.connection_handler` calls `ractor_connection_handler`, which returns nil on the main Ractor
(9e8fe3955b), before falling back to `default_connection_handler`. Checking `ActiveSupport::Ractors.main?` in
`connection_handler` first is exact in production code: 3,133 → 2,945 Ir per call (−6%, A/A 0) on 4.0.9; 17,492
calls per shipit iteration, ≈3.3M Ir or 0.055%. **Rejected:** the `sqlite3_ractor` test configuration prepends
`ARTest::RactorProxy`, which overrides `ractor_connection_handler` to force the proxy on the main Ractor. With D that
hook is never called, so the whole proxy run silently tests the plain handler
(`transaction_instrumentation_test.rb`: 4 failures in its `ractor_proxy?` branches; 0 with main's `core.rb`). Making
it work needs the hook moved to `connection_handler`, a three-file change for 0.055%. The `Ractor.current`/main
checks are deliberate Ractor support; this was the cheapest form found.

## Starting points that are not candidates

| starting point | main vs 8.1 | finding |
| --- | --- | --- |
| Schema context, Ractor-local lookups (#58437, #58578, #58767) | shipit: `WeakKeyMap#fetch_or_store` +58M, `schema_context`/`schema_loaded?` +37M per iteration | **overlap**: matthewd's #59530 rewrites SchemaContext and its slow path; recorded, not built |
| Connection-pool lease, used pools, handler (#59071, #59018, #58306) | shipit `used_pools!`/`UsedPoolSet` +25M; `with_connection` 26,755 → 30,258 Ir per call; `connection_handler` 2,297 → 3,133 | `LeaseRegistry#lease` inlining was rejected earlier (−0.13%, within 2× A/A). `connection_handler` is D (rejected). `used_pools!` is per-execution-context state (24,151 calls per shipit iteration from `checkout` and `query_cache`); no cheaper exact form found that keeps the deliberate isolation |
| Execution-state lookups | shipit `IsolatedExecutionState.[]` 92.2M → 107.5M self (+15M), from the extra `used_pools!` calls | same as above: the calls are the deliberate cost; `[]` itself is unchanged from 8.1 |
| CSRF Vary path (#59375) | railsbench +21.9M | **overlap**: czj's #59500 ("Only vary on Sec-Fetch-Site for requests that check it") |
| Query-intent logging (635454d310, 5c5683125a, 1277a8f09c) | +15,484 objects in the impact run | the query-intent architecture (matthewd); `start_intent_log`'s payload is a 10-key literal Hash (sized at creation); #57089 reworks this area; nothing small and exact found |
| #59237 `has_default_scope?` | +8,987 objects | kamipo's correctness fix asks `method(:default_scope).owner`; the cheaper forms were found inexact in R6 lead 2, and #59212 touches the association scope; recorded |
| #55410 `convert_options_to_data_attributes` | +8,052 objects in the impact run | **not a cost**: the method moved from `url_helper.rb` to `navigation_helper.rb` with an identical body |
| `IndexedRow`, `Result#column_indexes` | – | excluded by the coordinator (V2's candidate; byroot's `to_h` choice; tenderlove's #59141) |
| `Notifications.notifier`, `_routes` through `helper_module._routes` | 10,539 and 21,287 `notifier` calls per shipit/railsbench iteration (3.96M self on shipit) | small leads behind `Ractors.main?`, not measured further |

## Search for #18345-class hash spills and wide objects (Ruby master)

Since ruby/ruby#18345, `{}` holds two entries and moves its table to the C heap at the third insert. A ruby-bench
harness ([`harness-hashscan.rb`](../../bench/upstream/perf_round/harness-hashscan.rb),
[`hs_report.rb`](../../bench/upstream/perf_round/hs_report.rb)) records, on Ruby master, every Rails-allocated Hash
whose memsize shows a spilled table, per allocation site, and every object with more than 30 ivars, for railsbench,
shipit, lobsters and erubi-rails. Each top site was blamed on main and checked against the census 4 Rails pin
[`b5be03636e`](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953):

| site | spills per iteration (bench) | keys | since b5be03636e? |
| --- | --- | --- | --- |
| `querying.rb:99` `column_types.reject` | 2,000 rb / 3,568 shipit | 6–24 | no (71e45582b7) |
| `result.rb:118` `types = {}` | 2,000 rb / 3,568 shipit | 12–48 | no (f37a6dd218); a `Hash.new(capacity:)` lead, held while #59557 is open |
| `database_statements.rb:832` intent log payload | 2,000 rb / 1,970 shipit / 1,030 lobsters | 10 | no (5c5683125a); a literal, sized at creation |
| `instrumentation.rb:60` `raw_payload = {` | 2,000 rb | 14 | no, literal |
| `response.rb:199` `Headers.new` | 2,000 rb | 8–11 | no |
| `enumerable.rb:317` `Array#index_with` via `to_h` | 3,627 shipit / 373 lobsters | 7–24 | **yes** (6235de2236, ours); `to_h` sizes the Hash, so it spills only above 8 keys; #59557's topic, not touched |
| `route_set.rb:953/230/350` `merge` of url options | 1,408 shipit / 748 lobsters / 434 lobsters | 4–11 | no |
| `associations.rb:85` `@association_cache ||= {}` | 835 of 3,423 shipit | ≥3 | no (d432679e04); a lead |
| `cache.rb:1089`, `partial_renderer.rb:311` instrument payloads | 249 / 103 shipit, 366 lobsters | 4–7 | no, literals |
| `hash/keys.rb:32` `symbolize_keys` | 431 lobsters | 8 | no, `transform_keys` |
| `renderer.rb:133/154` (`default_env.merge(@env)`) | 10,000 erubi-rails each | 4 / 9 | no |
| `join_dependency.rb:17` `each_with_object({})` | 94 shipit | 8–24 | no (fe1f4b2ad5); a lead |

The `+` lines of `git diff -U0 b5be03636e bdb3d96012` with incremental hash building (`= {}`, `each_with_object({})`,
`[]=`, `merge!`) are all cold or unchanged in incrementality: `exception_wrapper.rb` `built_methods = {}` (error pages),
Active Job `serialize_hash` (our b05ca528f6, `each_with_object` → `each`, same inserts), `Hash#extract!` (our
1bc5b64704, same), `Enumerable#index_with` (6235de2236; `Array#index_with` keeps `to_h`), Active Storage
`create_many` (attachment changes), and `cookies.rb` `{ value: value }` (one key). **No new #18345-class incremental
site on a hot path**, so no candidate. **Wide objects**: QueryIntent (31 ivars, 2,000 per railsbench iteration) is the
only Rails object above 30 ivars in all four benchmarks; A takes it to 29.

## Rails 8.1.1 → 8.1.4.1 in ruby-bench, attributed

ruby/ruby-bench#567 (our bump) runs 0.8–1.5% more interpreter instructions per iteration
([ruby-bench-improvements, round 2](ruby-bench-improvements.md#1-rails-8141)). Here both Rails tags run with the same
lockfile otherwise (rails-html-sanitizer 1.7.2, loofah 2.25.3, nokogiri 1.19.7 in both), so the whole difference is
Rails. Sampled Callgrind windows, Ruby 4.0.9, two 8.1.1 processes as A/A:

* **railsbench: +110.6M Ir per iteration (+1.52%, A/A 0.035M)**, the same as the lockfile bump.
  * **+62.7M `tag_options` inclusive** (`String#blank?` +51.8M, `tag_options` self +18.4M): GHSA-68p9-83h6-5wpj,
    9190210606 (flavorjones), the converted-name check. **Deliberate security fix**; its double check on String keys is
    what B removes on main. 8-1-stable's `String#blank?` has no ASCII fast path (main got one later), which is why it
    costs more there.
  * **≈+27M Vary**: `_set_vary_header` +16.2M inclusive, `vary_headers` +3.7M, `Rack::Headers#[]=` +11.0M. GHSA-r9jg-fmfx-2gv6,
    7a955ca367 (Jeremy Daer), varying rendered responses on negotiation headers. **Deliberate security fix**; on main
    as e38dd281d3, next to the CSRF Vary path that #59500 addresses.
  * **≈+5M cookies and session**: `CookieJar#initialize`/`build`/`[]=` and `commit_session` (+1.5–2M each):
    2d9f502df9 (`cookies_same_site_protection` for every session store) and 849a6c30ea (no upgraded cookies on
    skipped sessions). Deliberate.
  * The rest is below 1M per method.
* **shipit: +68.1M (+1.14%, A/A 12.7M).** Mostly Active Record bug fixes: `read_attribute_for_serialization` +10.9M
  (#56705 turned `alias :read_attribute_for_serialization :send` into a method, for the docs and a one-argument
  contract; with Ruby master warning about `alias` falling back to `Object`, 2ed2c88f77, an alias isn't the way back —
  **deliberate**); `BelongsToAssociation#foreign_key` +7.8M and the new `foreign_key_values`/
  `association_primary_key_values`/`owner_foreign_key_matches_record?` (+16M together; #56664 and #57784, inverse
  matching for composite keys — **bug fixes**); `only_columns` +5.1M (#57364 added `model.only_columns.any?` to
  `build_select` — **bug fix**; a lead: the class-chain walk could be cheaper, not measured further); `String#blank?`
  +7.1M and `tag_options` +4.9M (as in railsbench); `Merger#merge_multi_values` −9.6M.
* **On main:** the tag-name check, the Vary change and the cookie changes are all on main (99a3247ebc, e38dd281d3,
  7723e49717, 1640b94e4c); the Active Record fixes are on main in reworked form (association routes). The impact report's
  +0.85% on railsbench for 8-1-stable against the merge base `8ae3d84277` is the same set.
* **Accidental cost with a small exact fix:** only the double blank check, which is B (targets main; backport-worthy).

## Instructions per iteration, final trees

Cachegrind, interpreter, fixed heap, window = (4 − 1 iterations) / 3, change against main (q7 on 4.0.9, q71 on
master; [`irtable.rb`](../../bench/upstream/perf_round/irtable.rb)):

| bench | Ruby | main Ir/iter | A/A (m2) | A | B |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | 4.0.9 | 5.2282e+09 | -0.040% | -0.067% | -0.233% |
| railsbench | master | 5.3597e+09 | +0.317% | +0.143% | +1.134% |
| shipit | 4.0.9 | 5.9345e+09 | -0.091% | +0.013% | +0.006% |
| shipit | master | 6.0887e+09 | +0.089% | +1.030% | -0.023% |
| lobsters | 4.0.9 | 4.2511e+09 | -1.508% | -1.021% | -0.951% |
| lobsters | master | 4.2014e+09 | -0.440% | -0.361% | -0.685% |
| erubi-rails | 4.0.9 | 6.4159e+09 | -0.303% | -0.242% | -0.163% |
| erubi-rails | master | 6.3525e+09 | +0.497% | +2.128% | +1.429% |

**None of these windows supports a claim.** main against main (A/A) moves by up to 1.5% (lobsters, 4.0.9) and 0.5%
(erubi-rails, master), and the cells above it don't agree with the per-call and memory numbers (B saves
instructions per call on master, yet shows +1.1% on railsbench). The cause is GC timing: counting GCs over the same
3 iterations on master ([`harness-gccount.rb`](../../bench/upstream/perf_round/harness-gccount.rb)) gives shipit
7 minor / 2 major (main), 9 / 2 (main A/A), 9 / 3 (A), 8 / 3 (B); railsbench 12 / 3, 9 / 3, 11 / 3, 12 / 3. One
extra major GC in A's shipit window is its +1.0% (seen in both the v1 and the final run). A saves 256 B per
intent and allocates the same objects, so a moved GC trigger is expected; it is not a per-query cost. The candidates'
claims therefore rest on the per-call counts, the sampled method windows and the slot bytes above.

## Receipts

Scripts and cases are in [`bench/upstream/perf_round`](../../bench/upstream/perf_round). Raw Callgrind, cachegrind,
byte and hash-scan outputs stay under `.lowrail/private/perf` (not committed).
