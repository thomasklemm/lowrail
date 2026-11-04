# Active Support on the request path (2026-11-04)

A round on Active Support code that runs on every request: Notifications, Callbacks, CurrentAttributes and
IsolatedExecutionState, the cache stores' read path, the loggers, HashWithIndifferentAccess, the core extensions,
TimeWithZone and Duration, ErrorReporter and the Executor. Candidates come from the CPU ranking of
[census 8](rails-main-census-8.md) (`rank-cpu409-{interpreter,yjit}-{line,method}.tsv`; 20 apps, 251 workloads,
Rails main `1105756f42`, Ruby 4.0.9) and the [census backlog](census-backlog.md), skipping every site an open PR,
a merged PR or an earlier round already covers.

**Result.** Two candidates, opened on 2026-11-04 after the full review path and the coordinator's Sol round: N1 as
[rails/rails#59613](https://github.com/rails/rails/pull/59613), H1 as [rails/rails#59614](https://github.com/rails/rails/pull/59614).

| # | Branch @ SHA | Change | Per call |
| --- | --- | --- | --- |
| N1 | [`thomasklemm/fanout-handle-groups-each`](https://github.com/thomasklemm/rails/tree/thomasklemm/fanout-handle-groups-each) @ `d6b71f057d` | `Fanout#build_handle` fills its group Array with `each` instead of `Hash#map` (Enumerable) | `instrument` with one subscriber: 4 → 3 objects; −5.1% / −10.8% / −11.3% instructions (interpreter / YJIT / ZJIT) |
| H1 | [`thomasklemm/hash-extract-each`](https://github.com/thomasklemm/rails/tree/thomasklemm/hash-extract-each) @ `441ee1f921` | `Hash#extract!` iterates its keys with `each` instead of `each_with_object` | `extract!` with the asset helpers' keys: 4 → 3 objects; −18.8% / −43.8% / −23.7%; `stylesheet_link_tag` −1.6% / −5.1% / −3.5% |

Both were measured on rails/rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed) and opened as one commit each on
`9cf3693a0a` (no commits on either file in between), authored and committed by Thomas Klemm; the patches are in [`patches/`](../../bench/upstream/as_request_paths/patches/).

## Why these two

Census 8 ranks lines by the instructions they execute themselves. Within Active Support, below the sites that are
covered or decided (`apply_inflections`, `index_with`, `IsolatedExecutionState.[]`, `xml_name_escape`,
`html_escape`, `InheritableOptions#initialize`, `String#blank?`, `html_safe`), the next request-path lines with an
exact, small change are:

| Site | Interpreter: apps, % of Ir, native | YJIT: apps, % of Ir | Objects per op |
| --- | --- | --- | ---: |
| `notifications/fanout.rb:377` `groups.map` in `build_handle` | 20, 0.116%, 92% | 18, 0.167% (rank 49) | 32.0 |
| `core_ext/hash/slice.rb:29` `Hash#extract!` | 17, 0.135%, 57% | 11, 0.179% (rank 47) | 6.2 |

In both, most of the line's cost is the Enumerable layer, not the work: `Hash` has no `map` of its own and
`Array` has no `each_with_object`, so both calls go through Enumerable's C implementation, which allocates an
internal block (IFUNC) on every call and calls the Ruby block from C through it. Replacing them with `each` and a
local accumulator removes that object and that layer. czj's merged
[rails/rails#59450](https://github.com/rails/rails/pull/59450) and our merged #59236 and #59563 made the same change
elsewhere for the pair Array `each_with_object` yields to destructuring blocks.

## Pins and method

Scripts in [`bench/upstream/as_request_paths/`](../../bench/upstream/as_request_paths/):

* Worktrees `main` and `aa` (Rails main `9b116f1fed` twice, for the A/A), `n1` and `h1`. Ruby 4.0.9 interpreter and
  `--yjit`; Ruby master [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb)
  interpreter and `--zjit`.
* **Instructions per call:** [`ir.sh`](../../bench/upstream/as_request_paths/ir.sh) and
  [`ir_table.rb`](../../bench/upstream/as_request_paths/ir_table.rb): Callgrind, `--toggle-collect=rb_ary_cycle`,
  3,000 calls inside `[0].cycle(1)` after 3,000 warmup calls, GC off, (Ir(3,000) − Ir(0)) / 3,000; two runs per
  variant and mode (the table shows the upper of the two). Cases in [`micro.rb`](../../bench/upstream/as_request_paths/micro.rb).
  The notifier cases use a fresh `Fanout` with one monotonic callable (as `ActiveRecord::RuntimeRegistry`
  subscribes to `sql.active_record`) or that plus one event-object block.
* **Wall time:** [`ns_pinned.sh`](../../bench/upstream/as_request_paths/ns_pinned.sh) /
  [`ns_table.rb`](../../bench/upstream/as_request_paths/ns_table.rb): one CPU, 15 rounds in rotating order,
  30,000 calls after 5,000 warmup calls, GC off, medians. Callgrind runs used the other CPUs at the same time.
* **ruby-bench:** ruby/ruby-bench `73918b2` (Rails 8.1.1/8.1.2, whose `build_handle` and `extract!` bodies match
  main's except that 8.1's `Handle.new` also takes the notifier).
  [`lowrail_as.rb`](../../bench/upstream/as_request_paths/lowrail_as.rb) (copied into `ruby-bench/harness/`)
  redefines the method in every variant, main's body or the candidate's; one iteration under Callgrind after
  warmup (interpreter 1, YJIT 10), `main1`/`main2` the A/A ([`rb_as.sh`](../../bench/upstream/as_request_paths/rb_as.sh)).
  Calls per iteration with a TracePoint (`COUNT=1`).
* **Valgrind:** stock 3.19.0, which prints `brk segment overflow` in every run here, as it did in the
  [round 2](rails-common-paths-2.md) receipts ([bench.md](../bench.md#valgrind-brk-reservation-correction-2026-10-20)).
  The counts carry the same allocator-layout caveat as CP-3 and CP-5.
* **Suites** (Ruby 4.0.9, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, `PARALLEL_WORKERS=1`, Redis and memcached as orb
  services): Active Support 6,895 runs, 0 failures, 0 errors, 60 skips on both branches. N1: Active Record
  `test:sqlite3` 10,281 runs, 0 failures, 4 errors (the structure dump/load tests need the `sqlite3` CLI, absent in
  the orb, as in round 2). H1: Action View 0 failures, 0 errors; Action Pack 4,800 runs, 0 failures, 282 errors, the
  same 282 `MetalIntegrationTest` "Test is missing assertions" errors as main with the same seed (route helpers
  named `test_*` leak in; the file alone passes on both). RuboCop clean on both files.

## N1: build the handle's groups with `each`

```diff
         if groups.empty?
           NullHandle
         else
-          instances = groups.map do |group_klass, grouped_listeners|
-            group_klass.new(grouped_listeners, name, id, payload)
+          instances = []
+          groups.each do |group_klass, grouped_listeners|
+            instances << group_klass.new(grouped_listeners, name, id, payload)
           end
           Handle.new(name, id, instances, payload)
         end
```

**Said in sentences.** If no group is listening, return the null handle. Otherwise start an empty list, add one new
group object per group class and its listeners, and build the handle from that list.

`build_handle` runs for every `instrument`, `start`/`finish` pair and `build_handle` call on the default notifier:
SQL queries (Active Record's runtime registry is always subscribed), renders, cache operations, controller actions.
Our merged #59235 returns `NullHandle` before the `map` when no group is active; that case is unchanged. In ruby-bench,
railsbench builds 5,987 non-empty handles per iteration, shipit 4,339 and lobsters 1,271.

**Exactness.** `groups` is what `groups_for` returns: the frozen Hash cached per event name (`group_by` →
`transform_values` → `freeze`) or a `dup` of it. Its keys are the four internal `*Group` classes and its values
frozen Arrays of subscribers, so no user code runs in the iteration except through overrides of the `:nodoc:`
`groups_for`. Order (Hash insertion order), the arguments to each `group_klass.new`, and what `Handle` receives (a
fresh, unfrozen Array) are unchanged; an exception from a group's `new` propagates the same way and drops the
partial Array in both. Differential ([`diff_fanout.rb`](../../bench/upstream/as_request_paths/diff_fanout.rb),
277 probes: no subscriber, every subscriber kind and pairs of kinds, silenced and unsilenced silenceable subscribers,
regexp and catch-all patterns, payload mutation, subscribers raising in `start`, `finish` or the block, nested
events, unsubscribing between `start` and `finish`, threads, fibers) on 4.0.9 interpreter, YJIT and YJIT at threshold 1, and
master interpreter, ZJIT, ZJIT at threshold 1 and YJIT: identical except one probe, a `Fanout` subclass whose
`groups_for` returns a Hash subclass with its own `map` (the accepted override class). Checklist: 1–8 checked; 2 and 4
differ only through that override.

**Reviews.** Primary (separate subagent, both rubrics): approve / approve with notes, **L1** ("`each` that pushes
into an empty Array is a common idiom and clear at once, but less natural than `map`"); same pattern as
`(active_subscriptions ||= []) << s` in `groups_for` a few lines above. Its note: RuboCop's `Style/MapIntoArray` would flag the
shape, but Rails' config has `DisabledByDefault: true` and does not enable it, so the body says why it isn't `map`.
Adversarial round (same subagent, its own probes on all five Ruby/JIT modes): no difference outside the accepted
class; the `Enumerable#map` frame disappears from `caller_locations` inside a prepended `BaseGroup#initialize`.
Cold read (a third subagent): "slightly harder" than `map`, no shape-list violation. Metrics: flog 7.1 → 8.5, ABC
7.07 → 7.81, 9 → 10 lines, cyclomatic 3 → 3, perceived 4 → 4.

**Instructions per call** (Callgrind; 4.0.9 and master, two runs each):

| Case | Mode | main | A/A | N1 | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `instrument` with one monotonic subscriber | interpreter 4.0.9 | 16,136 | +0.00% | 15,309 | −5.13% |
| | YJIT 4.0.9 | 7,992 | +0.07% | 7,128 | −10.81% |
| | interpreter master | 16,511 | +0.00% | 15,612 | −5.44% |
| | ZJIT master | 8,881 | +0.91% | 7,874 | −11.34% |
| `instrument` with two groups (monotonic + event object), one run | interpreter 4.0.9 | 32,507 | +0.01% | 31,536 | −2.99% |
| | YJIT 4.0.9 | 12,874 | −0.24% | 11,802 | −8.33% |
| | ZJIT master | 16,000 | +0.00% | 14,812 | −7.42% |
| `build_handle` alone, one group | interpreter 4.0.9 | 6,317 | −0.00% | 5,489 | −13.11% |
| | YJIT 4.0.9 | 4,474 | −1.67% | 3,530 | −21.09% |
| | ZJIT master | 4,105 | −0.27% | 3,097 | −24.56% |
| `Post.find(1)` (SQLite in memory, default subscribers) | interpreter 4.0.9 | 286,758 | +0.01% | 285,960 | −0.28% |
| | YJIT 4.0.9 | 140,379 | −0.08% | 139,564 | −0.58% |
| | ZJIT master | 128,331 | +0.14% | 127,460 | −0.68% |

Objects per call: `instrument` with one group 4 → 3, two groups 6 → 5, `Post.find` 57 → 56 (all modes).

**Wall time per call** (4.0.9, medians of 15 pinned rounds): `instrument` with one subscriber 1,930 → 1,726 ns
interpreted (−10.6%, A/A −0.9%), 1,027 → 797 ns with YJIT (−22.4%, A/A +2.4%).

**ruby-bench** (instructions per iteration):

| App | Handles | Mode | main1 | main2 (A/A) | N1 | Δ |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| railsbench | 5,987 | interpreter | 6,953,540,098 | +0.009% | 6,948,127,176 | −0.078% |
| shipit | 4,339 | interpreter | 5,839,882,773 | −0.004% | 5,836,500,006 | −0.058% |
| lobsters | 1,271 | interpreter | 4,263,617,377 | +0.013% | 4,263,025,315 | −0.014% |

railsbench's −5.4M and shipit's −3.4M fit about 830 instructions per handle; both are about the size of the
±0.07% noise between differing builds measured in round 2, so the body calls ruby-bench within noise. YJIT, main1
and candidate only (the A/A runs were stopped to free the CPUs for the quiet timing rerun, so these rows are not
resolved): railsbench 4,375,412,322 → 4,374,185,998 (−0.03%), shipit 3,140,923,834 → 3,139,335,411 (−0.05%),
lobsters 3,029,900,810 → 3,020,546,301 (−0.31%, more than 1,271 handles can explain; lobsters' YJIT A/A was
−0.11% in round 2). H1's YJIT rows were stopped before the candidate run.

## H1: iterate `Hash#extract!` keys with `each`

```diff
   def extract!(*keys)
-    keys.each_with_object(self.class.new) { |key, result| result[key] = delete(key) if has_key?(key) }
+    result = self.class.new
+    keys.each do |key|
+      result[key] = delete(key) if has_key?(key)
+    end
+    result
   end
```

**Said in sentences.** Start an empty Hash of the receiver's class. For each requested key the receiver has, move
its value into the result. Return the result.

`stylesheet_link_tag` and `javascript_include_tag` call `options.extract!("protocol", "extname", "host",
"skip_pipeline")` once per call (`asset_tag_helper.rb:126` and `:220`); usually none of those keys is given.
`ActionController::Parameters#extract!` delegates to it, and so do the Redis cache store's option setup and
`create_table`. In ruby-bench, lobsters makes 206 calls per iteration and shipit 64; railsbench none.

**Exactness.** `*keys` is always a fresh plain Array, so the iteration runs no user code; `each_with_object` called
`Array#each` itself, so both versions call it once. The calls on the receiver are the same in the same order
(`class`, `new`, then `has_key?`, `delete`, `[]=` per key), the accumulator is the `self.class.new` result in both,
and an exception partway leaves the receiver and the lost key in the same state. Differential
([`diff_extract.rb`](../../bench/upstream/as_request_paths/diff_extract.rb), 178 probes: Hash, defaults and default
procs, `compare_by_identity`, HashWithIndifferentAccess, OrderedOptions, InheritableOptions, Parameters, Hash
subclasses logging or overriding `has_key?`/`delete`/`[]=`/`initialize`, a subclass whose `initialize` needs an
argument, `delete` raising or rewriting the receiver, frozen receivers, singleton and extended methods; keys empty,
duplicate, missing, nil, Arrays, String/Symbol pairs) on the same seven Ruby/JIT modes: 0 differences. Checklist: 1–8
checked.

**Reviews.** Primary (separate subagent): approve / approve with notes, **L1** ("the familiar local accumulator +
`each` + return pattern; slightly longer, can't be misread"). Its note: the commit message said "every stylesheet
and javascript tag"; fixed to "once per call". Adversarial round (28 probes of its own plus the harness, four modes,
including fibers suspended in `has_key?`, a thread killed there, `throw`, an Array subclass splatted as keys, a
`self.new` returning a non-empty, frozen or nil Hash): identical except backtraces and `caller_locations`, which
lose the `Enumerable#each_with_object` frame, and TracePoint `:c_call`, which no longer reports it. Cold read: "about
the same, slightly more explicit"; it called the `result[key] = … if has_key?(key)` modifier borderline for the
shape list (an element write, not a reassignment, unchanged from main). Metrics: flog 6.4 → 6.3, ABC 7 → 7, 1 → 3
lines, cyclomatic 3 → 3, perceived 3 → 3.

**Instructions per call** (Callgrind; two runs each):

| Case | Mode | main | A/A | H1 | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `{"media" => "all"}.extract!("protocol", "extname", "host", "skip_pipeline")` (no key present) | interpreter 4.0.9 | 7,694 | +0.05% | 6,250 | −18.77% |
| | YJIT 4.0.9 | 6,404 | +0.30% | 3,600 | −43.78% |
| | interpreter master | 7,979 | −0.05% | 6,495 | −18.60% |
| | ZJIT master | 6,866 | −0.04% | 5,240 | −23.68% |
| same with `"host"` present | interpreter 4.0.9 | 8,461 | +0.00% | 7,080 | −16.33% |
| | YJIT 4.0.9 | 7,049 | −1.02% | 4,244 | −39.80% |
| | ZJIT master | 7,534 | −0.05% | 5,896 | −21.73% |
| `stylesheet_link_tag("application")` | interpreter 4.0.9 | 89,076 | −0.02% | 87,669 | −1.58% |
| | YJIT 4.0.9 | 54,003 | +0.03% | 51,246 | −5.10% |
| | interpreter master | 84,460 | −0.18% | 82,636 | −2.16% |
| | ZJIT master | 50,724 | −0.04% | 48,925 | −3.55% |
| `javascript_include_tag("application")` | interpreter 4.0.9 | 79,317 | −0.22% | 77,828 | −1.88% |
| | YJIT 4.0.9 | 49,734 | −0.41% | 48,350 | −2.78% |
| | ZJIT master | 46,073 | +0.13% | 44,355 | −3.73% |

Objects per call: `extract!` 4 → 3, `stylesheet_link_tag` 24 → 23 (4.0.9; 23 → 22 on master),
`javascript_include_tag` 23 → 22.

**Wall time per call** (4.0.9, medians of 15 pinned rounds): `extract!` with `"host"` present 1,048 → 808 ns
interpreted (−22.8%, A/A +1.0%), 897 → 550 ns with YJIT (−38.7%, A/A +3.4%); `stylesheet_link_tag` 12,639 →
12,443 ns interpreted (−1.5%, A/A −1.1%: not resolved), 8,049 → 7,502 ns with YJIT (−6.8%, A/A −2.4%). No key
present: 931 → 705 ns interpreted (−24.3%, A/A −0.7%), 773 → 461 ns with YJIT (−40.3%, A/A −0.4%).

**ruby-bench** (instructions per iteration, interpreter): lobsters 4,266,033,777 / A/A +0.010% / H1 −0.008%; shipit
5,844,250,241 / A/A −0.034% / H1 −0.012%. Within noise, as 206 and 64 calls at about 1,400 instructions each predict.

## Sol round and opening (2026-11-04)

The coordinator ran Sol on both: open after body fixes, keep the code. Applied:

* The bodies no longer claim exactness absolutely. Sol showed that overrides of `Array#each`/`Hash#each` (a `yield`
  returning a different value, a two-argument `yield`) and `caller_locations`/TracePoint tell the versions apart;
  the bodies say behavior is preserved with the standard `Hash`/`Array`/`Enumerable` implementations and that
  diagnostic frames change.
* Each body carries a standalone before/after script (objects and ns per call) and links the micro at an immutable
  commit URL; the exact Ruby builds are named; no projection to 3.3/3.4.
* Modest pitch: one internal callback object fewer per call, helper-level numbers, ruby-bench within noise, no
  request speedup claimed. Wall times were rerun with nothing else running in the orb (15 pinned rounds, GC off):
  `instrument` 1,907 → 1,711 ns interpreted (−10.3%, A/A −1.4%), 1,076 → 802 ns YJIT (−25.5%, A/A +2.0%);
  `extract!` 916 → 696 ns (−24.0%, A/A −0.6%), 774 → 464 ns (−40.1%, A/A −0.0%); `stylesheet_link_tag` −2.2% / −4.5%
  (A/A −0.1% / −0.4%).
* N1 is scoped to the default `Fanout` notifier. H1's call list is exact (receiver `class`, `has_key?`, `delete`;
  its class `new`; the result `[]=`), the unmeasured "costs more than the lookups" and "as usual" are gone, and the
  object count is stated for an existing Hash (3 → 2; the micro's 4 → 3 included building the input Hash).
* H1 takes Sol's `do … end` form (Thomas). Its bytecode is identical to the reviewed braces form (`disasm` differs only in
  column padding), so the measurements stand; `diff_extract.rb` gave 0 differences again on the final head.
* A second outsider read of the rewritten bodies: H1's input Hash has one entry, not two (fixed), and wording.
* Preflight: main refreshed to `9cf3693a0a`, no commits on either file since `9b116f1fed`, `git merge-tree` clean,
  overlap search repeated (nothing new; #58366 touches `groups_for`, not `build_handle`). Targeted suites on the
  final heads (notifications 97 runs, Hash/HWIA 202, asset tag helpers 126; 0 failures), RuboCop clean.
* Opened ready for review as [#59613](https://github.com/rails/rails/pull/59613) (`d6b71f057d`) and
  [#59614](https://github.com/rails/rails/pull/59614) (`441ee1f921`), with the bodies as posted below. A
  report-only watch checks both every 2 hours and messages the coordinator only when something is new.

## PR bodies (drafts, superseded by the bodies as opened)

Checked by a separate reader against this page and for an outsider's reading; its corrections are applied
(H1's `[]=` goes to the new Hash, not the receiver; ZJIT `stylesheet_link_tag` −3.5%; the noise wording; trims).

### N1: Build notification handle groups with each instead of Hash#map

> Every `ActiveSupport::Notifications.instrument` call with an active subscriber goes through `Fanout#build_handle`, which turns the subscriber groups into group objects with `groups.map`. That includes every SQL query, since Active Record's runtime registry is always subscribed. `Hash` has no `map` of its own, so this is `Enumerable#map`, which allocates an internal block on every call and calls the Ruby block from C through it.
>
> This fills the Array with `each` and `<<`, as `groups_for` does earlier in this file. It still returns `NullHandle` when no group is listening, and otherwise builds the same group objects in the same order. Only an override of the internal `groups_for` returning a Hash subclass with its own `map`, or a backtrace from inside a group's `initialize`, would show a difference.
>
> | `instrument` with one monotonic subscriber, per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 4 | 1,930 ns | 1,027 ns | 16,136 | 7,992 | 8,881 |
> | this PR | 3 | 1,726 ns (−10.6%) | 797 ns (−22.4%) | 15,309 (−5.1%) | 7,128 (−10.8%) | 7,874 (−11.3%) |
> | main, run again (change from the first run) | | −0.9% | +2.4% | +0.00% | +0.07% | +0.91% |
>
> One subscriber is the smallest case this changes. `Post.find(1)` on in-memory SQLite runs 0.3% fewer instructions interpreted, 0.6% with YJIT and 0.7% with ZJIT; ruby-bench's railsbench (Rails 8.1 with the method patched in) moves by 0.08%, within the noise between builds. Ruby 4.0.9, GC disabled, ZJIT on Ruby master 9aa0898240; times are medians of 15 pinned runs, instructions are Callgrind counts per call ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/as_request_paths/micro.rb)). In an instruction profile of 20 open-source Rails apps on Rails main, this line ran in all 20 and took 0.12% of everything the interpreter executed; I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/as-request-paths.md)).

### H1: Iterate Hash#extract! keys with each instead of each_with_object

> `stylesheet_link_tag` and `javascript_include_tag` take their path options out with `options.extract!("protocol", "extname", "host", "skip_pipeline")` on every call, and `ActionController::Parameters#extract!` goes through the same method. `Hash#extract!` iterates the keys with `each_with_object`, which comes from `Enumerable`: it allocates an internal block on every call and calls the Ruby block from C through it.
>
> This starts an empty Hash of the receiver's class, moves each requested key the receiver has into it with `each`, and returns it, as `deep_transform_keys` does since #59450. The receiver sees the same `has_key?` and `delete` calls, and the new Hash the same `[]=` calls, in the same order; only backtraces and traces from inside those calls lose the `each_with_object` frame.
>
> | `{"media" => "all"}.extract!("protocol", "extname", "host", "skip_pipeline")`, per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 4 | 931 ns | 773 ns | 7,694 | 6,404 | 6,866 |
> | this PR | 3 | 705 ns (−24.3%) | 461 ns (−40.3%) | 6,250 (−18.8%) | 3,600 (−43.8%) | 5,240 (−23.7%) |
> | main, run again (change from the first run) | | −0.7% | −0.4% | +0.05% | +0.30% | −0.04% |
>
> No key present is the usual case; with one present it saves 16.3%, 39.8% and 21.7% of instructions. `stylesheet_link_tag("application")` runs 1.6% fewer instructions interpreted, 5.1% with YJIT and 3.5% with ZJIT, and takes 6.8% less time with YJIT (A/A −2.4%); ruby-bench moves within noise. Ruby 4.0.9, GC disabled, ZJIT on Ruby master 9aa0898240; times are medians of 15 pinned runs, instructions are Callgrind counts per call ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/as_request_paths/micro.rb)). In an instruction profile of 20 open-source Rails apps on Rails main, this line ran in 17 and took 0.14% of everything the interpreter executed; I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/as-request-paths.md)).

## PR bodies as opened

### N1 (#59613): Build notification handle groups with each instead of Hash#map

> With the default `Fanout` notifier, every instrumented event that has an active subscriber goes through `Fanout#build_handle`, which maps the group Hash from `groups_for` to group objects. That includes every SQL query, since Active Record's runtime registry is always subscribed. `Hash` has no `map` of its own, so this is `Enumerable#map`, which creates an internal callback object on every call to forward each entry to the block.
>
> This accumulates the group objects with `each` and `<<` instead, as `groups_for` does earlier in the file. For the Hash `groups_for` produces, the groups are built in the same order with the same constructor arguments, and `NullHandle` is still returned when nothing is listening. With the standard `Hash`, `Array` and `Enumerable` implementations this preserves behavior; frames seen through `caller_locations` or TracePoint inside a group's constructor change.
>
> | `instrument` with one monotonic subscriber and a reused payload, per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 4 | 1,907 ns | 1,076 ns | 16,136 | 7,992 | 8,881 |
> | this PR | 3 | 1,711 ns (−10.3%) | 802 ns (−25.5%) | 15,309 (−5.1%) | 7,128 (−10.8%) | 7,874 (−11.3%) |
> | main, run again (change from the first run) | | −1.4% | +2.0% | +0.00% | +0.07% | +0.91% |
>
> One subscriber is the smallest case this changes. `Post.find(1)` on in-memory SQLite runs 0.3% fewer instructions interpreted, 0.6% with YJIT and 0.7% with ZJIT. On ruby-bench (Rails 8.1 with this method patched in), railsbench, shipit and lobsters stay within noise, so I don't claim a request-level speedup.
>
> Interpreter and YJIT: `ruby 4.0.9 (2026-10-23 revision 3e93b23afc)`; ZJIT: Ruby master `9aa0898240`; not measured on 3.3 or 3.4. Times are medians of 15 runs pinned to one otherwise idle CPU with GC disabled; instructions are Callgrind counts per call ([micro](https://github.com/thomasklemm/lowrail/blob/860e9f4/bench/upstream/as_request_paths/micro.rb)). A standalone check, run with `ruby -I activesupport/lib`:
>
> ```ruby
> # frozen_string_literal: true
>
> require "active_support"
> require "active_support/notifications"
> require "benchmark"
>
> fanout = ActiveSupport::Notifications::Fanout.new
> module Runtime
>   def self.call(name, start, finish, id, payload) = nil
> end
> fanout.subscribe("event", Runtime, monotonic: true)
> instrumenter = ActiveSupport::Notifications::Instrumenter.new(fanout)
> payload = {}
> run = proc { instrumenter.instrument("event", payload) { } }
>
> 10_000.times(&run)
> before = GC.stat(:total_allocated_objects)
> 100_000.times(&run)
> puts "objects per call: #{(GC.stat(:total_allocated_objects) - before) / 100_000.0}"
> puts "ns per call: #{(Benchmark.realtime { 1_000_000.times(&run) } * 1000).round}"
> ```
>
> In an instruction profile of 20 open-source Rails apps on Rails main, the `groups.map` line in `build_handle` ran in all 20 and took 0.12% of everything the interpreter executed; I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/860e9f4/docs/upstream/as-request-paths.md)).

### H1 (#59614): Iterate Hash#extract! keys with each instead of each_with_object

> `Hash#extract!` iterates its keys with `each_with_object`, which comes from `Enumerable` and creates an internal callback object on every call to forward each key to the block. `stylesheet_link_tag` and `javascript_include_tag` call it on every call to take out their path options, and `ActionController::Parameters#extract!` delegates to it.
>
> This builds the result in a local Hash with `each`, as `deep_transform_keys` does since #59450. That removes one internal allocation and the Enumerable callback layer, including when none of the keys is present. With the standard `Hash`, `Array` and `Enumerable` implementations the same calls are made in the same order as before. The receiver gets `class`, `has_key?` and `delete`, its class gets `new`, and the result gets `[]=`. Frames seen through backtraces, `caller_locations` or TracePoint inside those calls change.
>
> | `extract!("protocol", "extname", "host", "skip_pipeline")` on `{"media" => "all"}`, per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: | ---: |
> | main | 3 | 916 ns | 774 ns | 7,694 | 6,404 | 6,866 |
> | this PR | 2 | 696 ns (−24.0%) | 464 ns (−40.1%) | 6,250 (−18.8%) | 3,600 (−43.8%) | 5,240 (−23.7%) |
> | main, run again (change from the first run) | | −0.6% | −0.0% | +0.05% | +0.30% | −0.04% |
>
> Objects are counted on an existing Hash; the table's times and instructions include building the one-entry input Hash on each call, and the script below reuses it. With one of the keys present it saves 16.3% (interpreter), 39.8% (YJIT) and 21.7% (ZJIT) of instructions, and `stylesheet_link_tag("application")` runs 1.6% fewer instructions interpreted, 5.1% with YJIT and 3.5% with ZJIT. On ruby-bench (Rails 8.1 with this method patched in), shipit and lobsters stay within noise, so I don't claim a request-level speedup.
>
> Interpreter and YJIT: `ruby 4.0.9 (2026-10-23 revision 3e93b23afc)`; ZJIT: Ruby master `9aa0898240`; not measured on 3.3 or 3.4. Times are medians of 15 runs pinned to one otherwise idle CPU with GC disabled; instructions are Callgrind counts per call ([micro](https://github.com/thomasklemm/lowrail/blob/860e9f4/bench/upstream/as_request_paths/micro.rb)). A standalone check, run with `ruby -I activesupport/lib`:
>
> ```ruby
> # frozen_string_literal: true
>
> require "active_support"
> require "active_support/core_ext/hash/slice"
> require "benchmark"
>
> options = { "media" => "all" }
> run = proc { options.extract!("protocol", "extname", "host", "skip_pipeline") }
>
> 10_000.times(&run)
> before = GC.stat(:total_allocated_objects)
> 100_000.times(&run)
> puts "objects per call: #{(GC.stat(:total_allocated_objects) - before) / 100_000.0}"
> puts "ns per call: #{(Benchmark.realtime { 1_000_000.times(&run) } * 1000).round}"
> ```
>
> In an instruction profile of 20 open-source Rails apps on Rails main, the `extract!` line ran in 17 and took 0.14% of everything the interpreter executed; I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/860e9f4/docs/upstream/as-request-paths.md)).

## Not built, and why

| Site | Numbers | Why not |
| --- | --- | --- |
| Census backlog 2: `groups_for` builds `active_subscriptions` and `dup`s the groups for every event with an unsilenced silenceable subscriber (`fanout.rb:284–291`) | 13–29 objects per op in census 5; lines 284–291 about 0.08% of interpreted Ir in census 8 | `silenced?` is live (log level, debug mode) and must stay a call per subscriber; skipping the Array and `dup` exactly means caching the merged groups for the "all active" state next to the existing cache, new cached state (L2, caching is critical). Not built. |
| V1-C2: `html_escape` calling `ERB::Escape.html_escape` instead of `super` | erubi-rails −5.2% / −4.8% Ir, railsbench −0.8% | Design question: #46573 added the `super` on purpose. Not opened (coordinator's instruction); note sent. |
| HWIA `merge(...)` → `update(*other_hashes)` rest Array | 10.7 objects per op, 20 apps (census 7) | Removing the rest Array needs a second single-argument path or signature (L2); #59294 was merged "just because the code is nicer", and `...` already costs a YJIT fallback. Not built. |
| `InheritableOptions#initialize` per-request config copies | 0.23% of interpreted Ir, 20 apps | Design question after #59105 (P1-1). Not built. |
| `Array#deep_dup` as `map { _1.deep_dup }` instead of `map(&:deep_dup)` | 4-element Array 452 → 225 ns YJIT, 858 → 762 ns interpreted (one session, unpinned) | 11 apps, 0.07% interpreted; it trades the Rails `&:sym` idiom for a JIT effect in `Symbol#to_proc`. Lead only. |
| `Tryable#try`, `String#blank?`, `IsolatedExecutionState.[]` | census 8 unchanged | Earlier dispositions; the data did not change. |
| Cache store read path (`Store#instrument`, `normalize_key`, `merged_options`) | `cache.rb:1093` 9 apps, 0.02% | Below the other sites; `normalize_options` copies only when options are passed. |
| Callbacks (`run_callbacks`, `CallTemplate`) | `callbacks.rb:105` 0.03%, `:399` 0.04% | The `Environment` per run is required; #59105-era work (7a2033c9b8) took the thunk. Nothing exact left on the lines. |
| Logger/BroadcastLogger/TaggedLogging, ErrorReporter, Executor | ≤ 0.02% each | Not in the ranking's upper tiers; open #59521, #58897, #58775 touch TaggedLogging/BroadcastLogger for correctness. |
| `Time#change`, TimeWithZone | `calculations.rb:173` 0.10% | czj's 08ccbcbfbf took the Rationals for zero usec; CP-4 (`apply_seconds_precision`) rejected as not exact in round 2. |
| `Hash#stringify_keys`, `String#squish!`, `Hash#as_json` | 0.13% / 0.11% / 0.07% | Already minimal (`transform_keys` with `Symbol#name`, one regexp `gsub!`); R7-2 rejected for `as_json`. |

## Upstream search

`gh search prs --repo rails/rails` (open and closed) for `build_handle`, `fanout map`, `Fanout groups`,
`notifications handle allocation`, `notifications fanout performance`, `instances groups.map`, `extract!`,
`Hash#extract!`, `Hash extract`, `extract! each_with_object`, `each_with_object pair`, `slice.rb extract`; issues
for `extract!` and `build_handle`. Related only: #59235 (ours, merged, the `groups.empty?` check above the line),
#59095 and #59238 (merged, other parts of the fanout), #44469 (2022, the fanout rewrite), #5287 and #7007 (2012,
`extract!`'s current shape), #40292 (docs). Open PRs on the files: #58366 (`groups_for` locking, not
`build_handle`); none on `slice.rb`. Recent history: `fanout.rb` last changed in 58030897e4 (docs) and e3dd00a4bb;
`slice.rb` only in doc commits. Nothing on either line.

## Limits

* Per-call instruction counts on micro cases and a SQLite `find`, not request time; ruby-bench runs Rails 8.1 with
  the method patched in by the harness.
* Wall time is from one orb with Callgrind on the other CPUs; it supports per-call claims only.
* Reviews were subagents (primary + adversarial, cold read); the Sol review runs in the coordinating thread.
* MySQL, Trilogy and PostgreSQL suites were not run (no servers here); neither change is adapter-specific.
