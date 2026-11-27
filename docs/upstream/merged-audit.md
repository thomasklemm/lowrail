# Audit of merged upstream PRs (2026-11-03)

Thomas asked whether anything we got merged upstream is incorrect. This is a skeptical re-review of every
PR by thomasklemm merged since 2026-10-15: 34 in rails/rails (#59235 to #59576, all merged by amatsuda) and
7 in ruby/ruby (#19484, #19485, #19538, #19554, #19586, #19619, #19660). The list came from
`gh pr list --author thomasklemm --state merged` and was rechecked at 23:18 UTC.

**Result: no regression in stock Rails or Ruby behavior.** Nothing needs a fix PR, and no fix branch was
prepared. Seven Rails PRs change behavior that only code calling or overriding Rails internals (or
introspecting methods) can see. Each is reproduced below and recorded as a lead. The ruby/ruby PRs are clean.

## Method

* **Signals.** Comments, reviews and cross-references after each merge, reverts, follow-up commits on main
  touching the same files, and CI on main after the merges.
* **Re-review.** Every merged diff was read for mutation of shared or caller-owned objects, frozen defaults,
  order, duplicates, nil/empty edges, subclasses and overrides, thread safety and Ruby-version branches.
  Rails differences were run on the merge commit and its first parent with Ruby 4.0.9 (each commit's
  framework `lib/` first on the load path, Rails' own bundle; sqlite3 in memory and PostgreSQL 15). ruby/ruby
  was run on master 26d140fce5 in the interpreter, with `--yjit --yjit-call-threshold=1`, and with
  `--zjit` at call thresholds 1 and 2 with and without inlining.
* **Second opinions.** Three independent review subagents covered the same PRs (Active Record relation PRs,
  the other Rails PRs, and the JIT PRs) without seeing my conclusions. Their findings are merged in here
  after I checked them.
* For ruby/ruby#19484 only the production code was reviewed. Its macOS test failure belongs to
  [another thread](https://ampcode.com/threads/T-01a19d14-4f82-70ee-a23a-924089ab2b46).

## Signals

* No reverts of our PRs. The one revert in this window, f9d8dc9f1c, is of amatsuda's own `index_with`
  change; rails#59555 later restored the 8.1 behavior it was about.
* No reviews, review comments or issue comments after merge on any of the 41 PRs. The only exchange near a
  merge is fatkodima on [rails#59236](https://github.com/rails/rails/pull/59236#issuecomment-6316399624) asking whether
  such micro-optimizations are worth it, and amatsuda's answer. That was about value, not correctness.
* Cross-references point only to our own open follow-ups (rails#59557, ruby#19661/#19663), czj's fork PRs
  and Shopify/ruby issues that are consistent with the merged change. Shopify/ruby#939 was closed as fixed
  by ruby#19586.
* **Follow-up commits by Ryuta Kamizono** on the relation code:
  * 693d4e5922 "Skip merging a relation's values into themselves" touches the line #59556 added. Running
    `relation.unscope(:order, :where).order(:id).where(title: "a")` followed by `merge!(relation)` loses
    WHERE and ORDER BY on both `e2e002be27^1` and `e2e002be27`. The bug predates #59556, and #59556 did not
    widen it.
  * bb359be47a "Fix `merge` dropping `RECURSIVE`" fixes a bug that already existed at `ab5a78a7c2^1`.
  * 401f146f41 only removes an allocation.
* **CI on main.** Buildkite `rails` failed at the #59535 merge (c0cacea4cd), in
  `EagerAssociationTest#test_preload_has_many_through_with_source_type_ignores_other_types_in_loaded_through_records`,
  an ordering assertion without ORDER BY that Yasuo Honda fixed as flaky in 0fb680a063. Other failed main
  builds in the window (MemCacheStore, Ractor query cache, railties timeouts) don't touch our files.
  On ruby/ruby master, YJIT macOS failed twice on an `IO::TimeoutError` test; ZJIT workflows were green.

## Leads: behavior differences only internals or introspection can see

Before is `<merge>^1`, after is `<merge>`. The lines in question are unchanged on origin/main (d795dac950),
so each difference still applies there.

### rails#59538: relation loads pass a shared frozen `binds` Array when `prepared_statements: false`

`exec_main_query` now passes `FROZEN_EMPTY_ARRAY` to `_query_by_sql`. With prepared statements on,
`to_sql_and_binds` replaces it with the compiled binds. With them off, it hands the given array on to the
`QueryIntent` and the `sql.active_record` payload.

```ruby
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", prepared_statements: false)
ActiveRecord::Base.connection.create_table(:posts) { |t| t.string :title }
class Post < ActiveRecord::Base; end
Post.create!(title: "a")
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  next unless payload[:name] == "Post Load"
  payload[:binds] << :marker rescue puts "#{$!.class}: #{$!.message}"
  puts "frozen? #{payload[:binds].frozen?}"
end
Post.where(title: "a").to_a
```

Before: `frozen? false`. After: `FrozenError: can't modify frozen Array: []` then `frozen? true`. PostgreSQL
gives the same result. Only relation loads are affected; `find`, `find_by`, `count`, `pluck`, `exists?` and
`find_by_sql` still pass fresh arrays.

Why it is a lead and not a regression: Rails only reads binds. A GitHub code search found no
`payload[:binds] <<`, `.concat`, `.map!`, `.clear` or `.delete`. The sqlserver, oracle-enhanced, cockroachdb,
trilogy and postgis adapters don't mutate the binds they receive. The one sqlserver `binds <<` builds its own
local Array. If a report turns up, the fix is to pass `[]` in `exec_main_query` again, or have
`to_sql_and_binds` return its own empty Array on the unprepared branch.

### rails#59536: `collect_warnings` returns a shared frozen Array when there are no warnings

A `collect_warnings` override that appends to `super`'s result now raises on every query without warnings:

```ruby
ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Module.new do
  def collect_warnings(result) = super.push(ActiveRecord::SQLWarning.new("audit", "0", "warn"))
end)
```

Before, the override's warning was reported; after, the query fails with `FrozenError: can't modify frozen
Array: []`. This also applies on PostgreSQL without notices and on MySQL with `warning_count == 0`.
`collect_warnings` is private and Rails only iterates the result. None of the five adapters above overrides it.

### rails#59562: a Subscriber subclass that already uses the name `event_method_names` at class level

The PR adds a class-level reader and a class instance variable `@event_method_names` on every Subscriber
class. A subclass with its own `def self.event_method_names` now gets
`TypeError: no implicit conversion of String into Integer` on every event. A subclass that sets
`@event_method_names = [...]` gets `NoMethodError: undefined method 'merge' for an instance of Array` from
`attach_to`. Both handled events before the merge. The PR's tests cover an instance method with that
name, not a class method. No gem in the Rails bundle uses the name. Otherwise dispatch can't differ: the
cached name always equals `name[0, name.index(".")]`.

### rails#59560: `HashLookupTypeMap#fetch` overrides no longer run for PostgreSQL result columns

A module prepended to `HashLookupTypeMap` that wraps `fetch` saw 4 calls for a two-column `select_all`
before the merge and 2 after, because result columns now go through `fetch_result_type`. The cast types
are identical, and schema columns still call `fetch`. The class is `:nodoc:`. A PostgreSQL-derived adapter
whose type map isn't a `HashLookupTypeMap` would get `NoMethodError`. I found none: code search turns up
only copies of Rails and Katello's `get_oid_type` patch, which still works because `register_type` also
clears the new key cache.

### rails#59537: callers of the private `TagBuilder#tag_string`

`tag_string(name, content, options)` became `tag_string(name, options, content = nil)`. Code that adds
its own `TagBuilder` element calling `tag_string(:i, content, options)` now raises
`NoMethodError: undefined method 'each_pair' for an instance of String`. Before the merge it rendered
`<i class="fa">star</i>`. Code search found no external caller or override.

### rails#59571: parameterless lambda scopes have arity 0 instead of -1

`Post.method(:approved)` with `scope :approved, -> { ... }` changes from
`[-1, [[:rest, :args], [:keyrest, :kwargs]]]` to `[0, []]`. The ArgumentError for `Post.approved(1)` has
the same message, but its first frame is now `named.rb` instead of the app's scope line. Ransack's
`chain_scope` branches on `arity < 1` and `arity == 1` (read from its current source), so it behaves the
same for -1 and 0.

### rails#59316 and rails#59535: contrived or text-only

* #59316's host fast path checks `instance_of?(String)`. A plain String with a `match` override added by
  `extend` passes that check, so the override is skipped: `https://www.example.com:8443/x` before,
  `http://alias.example.com/x` after. About 240 host and protocol cases (encodings, frozen, IP, user/port,
  subdomain/domain) matched.
* #59535: the error for `fetch` without arguments now reads `expected 1..2` instead of `expected 1+`, and
  `HashWithIndifferentAccess#fetch` reports `[[:req, :key], [:opt, :default]]` as its parameters.

### Not caused by our PRs

* `index_with` on an Array subclass that overrides `each` ignores the override on main, both before and
  after rails#59555. `Tens[1, 2].index_with { _1 }` returns `{10 => 10, 20 => 20}` on 8-1-stable and
  `{1 => 1, 2 => 2}` on main. 2b88dc1995 (Sep 4, unreleased) introduced it. #59555 kept `Array#to_h` for
  Arrays, and its message's claim that `to_h` is the same as `each` there is false for such subclasses.
  This is an unreleased difference from 8.1. It is rare: Ruby's own `Array#map` also ignores an
  overridden `each`.
* #59555 itself changes `Hash#index_with` and `Struct#index_with` from what main had between Sep 4 and
  Nov 3, back to the released 8.1 results. That restores the old behavior rather than regressing it.

## Clean

Each line gives the reason the PR was trusted: a matching before/after run, or a proof from the code.

| PR | Why it's clean |
| --- | --- |
| rails#59576 | `WhereClause#ast` gave identical output for 16 predicate shapes (`""`, `Arel.sql("")`, nil, false, mixed) |
| rails#59568 | `attribute_types` is a local inside one branch only |
| rails#59556 | values are only read; bang methods replace the receiver's arrays; self-merge and CollectionProxy outputs were identical (see Kamizono's follow-up above) |
| rails#59554 | same keys, same order, `public_send(name!, *value)` with names built at load |
| rails#59553 | the only caller does `default_extensions \| reflection.extensions` |
| rails#59552 | `scopes` returns a fresh Array; join, preload and eager_load SQL was identical |
| rails#59551 | `extending!` already returns early for no modules and no block |
| rails#59544 | 14 value shapes gave identical `where`/`where.not` SQL; the caller's Array was untouched |
| rails#59543 | `except`/`slice` return new Hashes; CollectionProxy delegates `except`/`only` to its scope |
| rails#59541 | a 12×12 merge matrix plus `rewhere`/`unscope(where:)` gave byte-identical SQL |
| rails#59539 | `chain` is an Array; `drop(i)` equals `[i..]` |
| rails#59534 | a `*rest` Array is always fresh: splat, `send`, `public_send`, `Method#call`, `...`/`*` forwarding, `super` and prepends, on 4.0.9 interpreter/YJIT and master interpreter/YJIT/ZJIT |
| rails#59533 | `Array#-` with a small right side calls `elem.eql?("")`, as the new loop does |
| rails#59270 | `public_send` dispatches the same for a Symbol and a String |
| rails#59563 | both forms iterate through `each`; plain, HWIA, ruby2_keywords and subclass outputs matched |
| rails#59561 | identical key String; subclass, `dup`'d module and cross-thread values matched |
| rails#59558, #59278 | `PG::Result#ftype`/`fields` are pure; `select_all` types and values matched, including an enum loaded on demand |
| rails#59555 | restores 8.1 behavior (see above) |
| rails#59542 | the empty intents Array is no longer swapped; nothing else holds it |
| rails#59329 | `rindex` uses the same predicate as `drop_while`; the keys are only used with `include?`; about 50 route cases matched |
| rails#59274 | `uniq` always returns a new Array |
| rails#59252 | same key order; Array, Set and Enumerator `lookup_ancestors` gave the same messages |
| rails#59244 | `Symbol#name == to_s`, and Symbol can't be subclassed |
| rails#59236 | equivalent for a Hash (since rewritten by 84048ad477) |
| rails#59235 | `groups_for` returns a Hash; the same groups are built in the same order |
| ruby#19660 | `def Hash.new`, `define_singleton_method`, prepend, `undef`/`remove_method`, subclasses and re-aliasing agree across interpreter/YJIT/ZJIT; a false "redefined" flag could only disable the optimization; byroot's 43a4bc5f6f is a cleanup |
| ruby#19554, #19619 | add only a `return None` fallback plus a counter |
| ruby#19538 | `exit_state` is the original send's snapshot, kept live by the operand visitor and used only before side effects; about 1,250 stack overflow exits per shape (block args, splats, rest, keywords, `super`) all printed `ok` |
| ruby#19485 | touches only `IncrCounter` instructions, which have no outputs and are emitted only with stats |
| ruby#19586 | the VM resolves aliases from the lookup entry too; re-alias, override, remove, prepend, visibility changes and `GC.compact` all matched the interpreter |
| ruby#19484 (production code) | matches the VM's lazy block parameter; Symbol, Method, nil, Proc subclass and `to_proc` objects after specialization, plus `GC.stress` with compaction, all matched |

One older ZJIT gap turned up that none of these PRs introduced: `clear_method_cache_by_id_in_class` only
invalidates `METHOD_ENTRY_CACHED` entries when a class has subclasses, and ZJIT's `track_cme_assumption`
doesn't set that flag. No failing script was found. It belongs in the
[ZJIT lead queue](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03) as unmeasured.

## 2026-11-27: what landed against our last reviewed heads

Rafael França amended L3 ([rails#60020](https://github.com/rails/rails/pull/60020)) before merging it, and Thomas
suspected he reworked others. This section compares, for every merged PR of ours, the code that landed with our last
reviewed head: the head of the latest approving pass in the queue item (the item's `head` where no pass approved).
What landed is the merge commit's second parent, or the squashed or rebased commits, plus later commits on the default
branch that rewrite lines we added. Covered: 91 rails/rails PRs merged since 2026-10-21, 17 ruby/ruby PRs and 31 gem
PRs (ransack, blind_index, caxlsx, connection_pool, cuprite, ferrum, graphql-ruby, hashie, inertia-rails, prism,
rails_vite, rqrcode_core, rubocop-rails, ruby/bigdecimal, ruby/date, ruby-bench, sqlite3-ruby). Roundhouse and the
pre-2026 PRs are out of scope.

**Result: four of our Rails PRs were amended by Rafael before merging (L3, AM4, MB1, K6), and none of the amendments
introduces a bug.** Each is exact for every caller its contract covers. AM4 is the only change of design: Rafael moved
the enqueued-email assertions into Active Job, which narrows where they are available on purpose and is documented.
The three performance amendments keep the measured saving (objects unchanged, instructions between −0.9% and +0.3% on the
interpreter, YJIT and ZJIT). No fix PR is needed, so no queue item was built. Five more Rails PRs were only rebased by
Rafael at merge time; one of them (#59611) lost a hunk that main already had. In the gems, skryukov refactored
inertia-rails#435 (exact) and rewrote #436 with fixes of his own, ankane landed blind_index#62's code without its
tests, and flavorjones added an allocation test and a CHANGELOG entry to sqlite3-ruby#758. Every queue item in state
`merged` now records the PR head that landed as `merged_head`.

### Method

* **Who changed what.** For each PR, GitHub's GraphQL timeline lists force-pushes and commits with their actor and
  committer; every push or commit not by Thomas was compared with what was there before it. rails/rails merges all
  are merge commits whose second parent is the final PR head (only #59316 was squashed, identically), so the PR head
  is what landed.
* **Comparison.** Only changed lines count: `git diff -U0` of our head against its own base versus the merged head
  against its own base, by file ([pdiff.sh](../../bench/upstream/merged-audit-2026-11-27/scripts/pdiff.sh); the outputs are
  in [interdiffs](../../bench/upstream/merged-audit-2026-11-27/interdiffs)). A rebase that only moves hunks shows
  as identical.
* **Follow-ups on main.** `git blame` at rails/rails main 2e299253f9 counted, per file, the lines each PR added that
  still carry its commits; every file with fewer was traced with `git log -S`.
* **Each amendment** was judged like a review on the merged code: exactness for the contract's callers, a
  differential probe where behaviour could differ, the affected Rails suites, and `script/upstream-bench` (Ruby
  4.0.10 interpreter and YJIT, master f3e180b5eb ZJIT; objects and Callgrind instructions, A/A in every cell) of the
  reviewed head cherry-picked onto the merge's first parent against the merge.

### Amended before merging

| PR | Item | What Rafael changed | Verdict |
| --- | --- | --- | --- |
| [#60020](https://github.com/rails/rails/pull/60020) | L3 | `return hash unless snapshot` before the loop replaces `snapshot&.[](…)` inside it (force-pushed 17:13 and 17:15 UTC, merged 17:21) | Exact, saving kept |
| [#60013](https://github.com/rails/rails/pull/60013) | AM4 | Replaced our `rescue LoadError` and `defined?(ActiveJob)` with a new `action_mailer_test_helper` load hook; the enqueued-email assertions move to `ActiveJob::ActionMailerTestHelper`, which the Active Job railtie prepends; CHANGELOG, guides and a railties test | Exact for apps with the Active Job railtie; deliberate, documented narrowing elsewhere |
| [#59810](https://github.com/rails/rails/pull/59810) | MB1 | The early-return condition became two private predicates, `other_contributes_nothing?` and `where_and_having_clauses_empty?`, each with a one-line comment saying why | Exact, saving kept |
| [#59804](https://github.com/rails/rails/pull/59804) | K6 | `id = sanitize_to_id(name) unless options.key?("id")` moved out of the Hash literal into a local | Exact, saving kept |

**L3.** After `materialize`, `@attributes` is nil only for a set that holds no attribute, where both versions return
an empty Hash; `index_for_name` is a Hash lookup, so skipping it calls nothing a caller could see. The 2,309-line
[probe.rb](../../bench/upstream/l3/probe.rb) output is byte-identical between the reviewed head and the merge, and a
new [empty-set probe](../../bench/upstream/merged-audit-2026-11-27/l3_empty_probe.rb) gives the same Hashes for
attribute-less models, new and loaded records and partial selects
([outputs](../../bench/upstream/merged-audit-2026-11-27/L3-probe)). Reviewed against merged, objects are equal (2 per
`attributes_for_database` call). The merge is slightly cheaper on the interpreter, −0.3% to −0.9% instructions
(A/A 0.09–0.23%), since no `&.` runs per column; YJIT −0.5% to +0.1% and ZJIT −0.3% to +0.1%, each inside or within
0.2 points of its A/A ([4.0.10](../../bench/upstream/merged-audit-2026-11-27/L3-reviewed-vs-merged-4.0.10),
[ZJIT](../../bench/upstream/merged-audit-2026-11-27/L3-reviewed-vs-merged-master-zjit)). Active Model's suite on
main: 1,277 runs, 0 failures.

**AM4.** A [probe](../../bench/upstream/merged-audit-2026-11-27/am4/probe.rb) in five setups on the merge's parent,
our reviewed head and the merge ([results](../../bench/upstream/merged-audit-2026-11-27/am4/probe-results.txt)):

* An app with the Active Job railtie (also when `action_mailer/test_helper` loads before the app initializes): the
  same eight helpers on `ActionMailer::TestCase` and `ActionDispatch::IntegrationTest`, `capture_emails` delivers a
  `deliver_later` mail, `assert_enqueued_emails` passes. Identical in all three trees.
* An app that requires `action_mailer/railtie` without `active_job/railtie`, and plain `require "action_mailer"`
  (with or without `require "active_job"`): parent and reviewed head have the enqueued-email helpers (Active Job is
  in the bundle), the merge has only `assert_emails` and `capture_emails`, and `capture_emails { deliver_later }`
  returns no mail instead of one. That is Rafael's design: the CHANGELOG tells non-Rails users to prepend
  `ActiveJob::ActionMailerTestHelper` themselves, and UG82M's upgrade note already tells such apps to require the
  Active Job railtie. Both failure modes are loud (`NoMethodError`, or an `assert_emails` count of 0), not silent.

Action Mailer's suite (291 runs, which load the helper through the explicit prepend) and railties'
`integration_test_case_test.rb` (6 runs, including Rafael's and our app tests) pass on main 2e299253f9. No test
covers the explicit prepend outside the abstract test setup; one isn't needed for a documented opt-in. AM4 is a fix,
with no measured saving to keep.

**MB1.** The predicates evaluate the same expressions in the same order, and the comments say what the commit
message said. Objects are equal (27 for `post.comments.where(approved: true)`, 10 for a `where.merge(order)` that
has values to merge); instructions +0.3% and +0.2% on the interpreter, two private calls per merge, the A/A 0.04%
and 0.13%; YJIT within noise; ZJIT −0.1% ([4.0.10](../../bench/upstream/merged-audit-2026-11-27/MB1-reviewed-vs-merged-4.0.10),
[ZJIT](../../bench/upstream/merged-audit-2026-11-27/MB1-reviewed-vs-merged-master-zjit)). MB1's 5–6 objects per
association scope stay saved. Active Record's SQLite suite on main: 10,485 runs, 0 failures, 4 errors, all from the
missing `sqlite3` command-line tool in the orb (structure dump and load).

**K6.** `sanitize_to_id(name)` still runs only without an `"id"` option and before anything else touches user
objects; `name` is only read in the literal. Objects equal (7, 6 and 97 for `text_field_tag`, with `id:`, and
`button_to` with 5 params); instructions within ±0.2% in all three modes
([4.0.10](../../bench/upstream/merged-audit-2026-11-27/K6-reviewed-vs-merged-4.0.10),
[ZJIT](../../bench/upstream/merged-audit-2026-11-27/K6-reviewed-vs-merged-master-zjit)). `form_tag_helper_test.rb`,
`tag_helper_test.rb` and `url_helper_test.rb` pass on main (160, 110 and 49 runs).

### Rebased by the maintainer, no change of content

* rails/rails [#59851](https://github.com/rails/rails/pull/59851) (A1), [#59668](https://github.com/rails/rails/pull/59668)
  (E2b), [#59617](https://github.com/rails/rails/pull/59617) and [#59986](https://github.com/rails/rails/pull/59986)
  (UG82M): Rafael rebased each onto main within minutes of merging; the changed lines are identical. In UG82M
  the upgrade-guide section now sits after the Rack::Sendfile and Rack::ContentLength notes instead of after the
  missing-controller note.
* [#59611](https://github.com/rails/rails/pull/59611) (R1, no queue item): the rebase dropped our
  `s.add_dependency "prism"` from `actionview.gemspec` (and its `Gemfile.lock` line), because Shu Masuda's
  f36806f678 (2026-11-22) had added `prism "~> 1.0"` there. Railties' unversioned dependency landed as ours. The
  title still names Action View; nothing to fix.
* ruby/ruby: every squash or rebase merge matches the PR head line for line. Alan Wu's commits on #19484 and
  #19485 were merges of master. Two of ours on rubocop-rails (#1670, koic squashed our two commits into one) and
  caxlsx#550 (kiskoza rebased onto a RuboCop fix) are identical too.

### Amended earlier, already recorded

* [#59634](https://github.com/rails/rails/pull/59634) (AR-4): kamipo's c8490688d7 (2026-11-05) made `where!` and
  `having!` wrappers around new `_where!` and `_having!`; its effect on Mobility and active_record-acts_as is in
  the [ledger](contributions.md).
* [ruby#19660](https://github.com/ruby/ruby/pull/19660): byroot's force-push (2026-11-03) maps any singleton class to
  its attached object before the class checks instead of returning `HASH_REDEFINED_OP_FLAG` for Hash's alone. Only
  methods in the redefinition table are affected, and the only singleton entry is `Hash.new`, so the flags are the
  same; the 2026-11-03 audit above ran the merged form.

### Later commits on main that rewrite our lines

* [#59642](https://github.com/rails/rails/pull/59642) (CW1) caused a regression that someone else fixed:
  `Post.where(Arel.sql("id = ?"), 1)` raised `PreparedStatementInvalid` because CW1 passed the `Arel::Nodes::SqlLiteral`
  itself to `bound_sql_literal_for`, and `SqlLiteral#count` (from `Arel::Expressions`) builds a COUNT node instead
  of counting `?`. Andrew K. Fader's [#59829](https://github.com/rails/rails/pull/59829) (518784d2e3, 2026-11-16)
  converts it with `to_s` and adds the test. Census 10 recorded the line change but not that it fixed our
  regression.
* Rafael's f5e35938a2 (today, after amatsuda's [#59369](https://github.com/rails/rails/pull/59369) makes
  `Symbol#to_s` return the interned frozen String on every supported Ruby) replaced `Symbol === k ? k.name : k.to_s`
  with `k.to_s` across Rails, one line of it from our [#59244](https://github.com/rails/rails/pull/59244). Exact, and
  the Symbol keys still allocate nothing because `to_s` is now an alias of `name`.
* Older and already known: byroot's revert of #59584 and simplification of #59640; 84048ad477 rewriting #59236;
  kamipo's 693d4e5922 after #59556; Lawrence Lin's ef429f4bcc and Aaron Patterson's attribute-set work replacing
  the lines of #59568 and #59634; byroot's doc fix in #59555's comment.

### Gems

* **ankane/blind_index#62** (BI1): ankane's ac61e54cf4 kept our code change verbatim, kept the `# memoize for
  performance` comment we had removed, dropped both of our tests and their table, and added an Active Record 8.2 CI
  gemfile instead. The ledger called the commit "our change verbatim"; it is verbatim for the code only.
* **inertiajs/inertia-rails#435** (INR435): skryukov extracted `sensitive_pair?`, shared by query and fragment
  redaction, wrote `pair.sub(/=.*/m) { "=#{ENCODED_REDACTED}" }` for `"#{key}=#{ENCODED_REDACTED}"`, shortened the
  guide text and added `(@thomasklemm)` to the CHANGELOG line. A pair only counts as sensitive when it has an `=`,
  so both forms give the same String; exact.
* **inertiajs/inertia-rails#436** (INR436): after our last push (e666cde2da) skryukov added eleven commits that
  rework prop resolution (dotted keys merged lazily, `only`/`except` applied inside closures, a `DottedKeys` class,
  a plain-value fast path) with CHANGELOG entries in his name. That is his code, reviewed in his repo; we did not
  re-review it.
* **sparklemotion/sqlite3-ruby#758**: flavorjones added a test that `Statement#step` allocates nothing once a statement
  is done, merged main in and wrote the CHANGELOG entry. **skryukov/rails_vite#57**: skryukov added the CHANGELOG
  entry. **rubycdp/cuprite#360**: route merged main in. Everything else (bigdecimal, date, sqlite3-ruby#773,
  ransack, hashie, rqrcode_core, ruby-bench, prism, connection_pool, ferrum, graphql-ruby, inertia-rails #437,
  #441, #442, #444) landed as our head.

### Landed after changes of our own past the last approving pass

Not maintainer edits, but the rule asks for them: A1, K1 and PR59574 differ from their last approving head only by
our rebases onto a newer main; ZNE1 renamed two tests after the last approve; E2's last head carries code and body approvals
by thermos-sol and Astra with readiness verdicts left at `changes` by Thomas's decision (its note). AR-4, CW1, SU1,
PR59617, TN2, ZWB1 and the inertia items have no pass recorded as `approve`; their landed code is our last push.

### What the edits teach (candidate guidance)

1. **Guard once, before the loop** (L3): a nil that makes the whole result empty gets an early return, not `&.` on
   every iteration.
2. **Name a compound guard and say why in one line** (MB1): Rafael split `values.empty? && !other.null_relation? &&
   … where … having …` into two private predicates, each with the reason a reader would otherwise delete the
   condition. That reason lived only in our commit message. Our comment rule already allows exactly this; we
   under-applied it. The two calls cost 0.2–0.3% on the interpreter and nothing under a JIT, so Rails takes a named
   predicate over an inline condition.
3. **No conditional modifier inside a literal or an argument list** (K6): compute the value into a local first. Add to
   the shape checklist next to "no reassignment inside a conditional modifier".
4. **Decouple frameworks with load hooks, and put the integration in the framework that depends** (AM4): instead of
   `rescue LoadError` and `defined?(ActiveJob)` in Action Mailer, Action Mailer runs an on-load hook and Active Job's
   railtie adds its helpers. Rafael also documented the hook in the configuring guide, the behaviour in the testing
   guide and the opt-in in the CHANGELOG, and added a railties app test. For Rails changes across framework
   boundaries, propose the hook shape first.
5. **Expect Rafael to rebase CHANGELOG and guide conflicts himself at merge time** (A1, E2b, #59617, UG82M, #59611):
   five of his merges on 2026-11-26 rebased first. A CHANGELOG-only conflict alone doesn't need our push; a dependency
   or code conflict still does, since his resolution can drop a hunk (#59611).
6. **Check String subclasses that Rails passes around** (CW1): `Arel::Nodes::SqlLiteral` is a String whose `count`
   builds SQL. Add it to exactness checklist item 2 as a standing case for Active Record changes.
7. **Write `to_s` for Symbols in Rails** (#59369): Active Support now aliases `Symbol#to_s` to `name` on Rubies before
   4.1, and Rafael removed the `Symbol === k ? k.name : k.to_s` pattern. Don't add it again.
8. **Gems follow their maintainer's taste, not our test rule**: flavorjones added an allocation test to #758 (our
   rule forbids them only upstream in Rails), ankane drops tests he doesn't want and adds a CI gemfile, skryukov and
   flavorjones expect a CHANGELOG entry with credit. Read a gem's recent merges for these before opening.
