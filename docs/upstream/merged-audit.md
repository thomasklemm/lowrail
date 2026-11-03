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
