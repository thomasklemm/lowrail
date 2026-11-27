# Should Rails warn when a model class method is shadowed on relations? (2026-11-27)

Follow-up to UG82D (rails/rails#60005). Question from Thomas: should Rails fix the `default_order` collision rather
than only document it? Answer: **open nothing**; #60005 stays the fix. Evidence below, all run on Ruby 4.0.9 against
rails/rails main `088fc0cf61` (8.1.4.1 as control where noted).

## A. Precedent: earlier query methods with common names

| Method | PR | First release | Collision reports found |
| --- | --- | --- | --- |
| `extract_associated` | #35784 | 6.0 | none |
| `annotate` | #35617 | 6.0 | none |
| `invert_where` | #40249 | 7.0 | none |
| `excluding` / `without` | #41439, #41465 | 7.0 | two comments on #34250 (`scope :excluding` on 6.0.0.rc2, `scope :without` in 2020; both Enumerable names via Active Support) |
| `in_order_of` | #42061 | 7.0 | none |
| `with` (CTE) | #37944 | 7.1 | Rails' own: `Base.with` vs Active Support's `Object#with`; fixed by #57693 (2026-06, `Base.with` with a block calls `Object#with`) |
| `regroup` | #47010 | 7.1 | none |

No rename, revert or upgrade-guide note for any of them (`rg` over `guides/source/upgrading_ruby_on_rails.md` for these
names: no hits). Searches: `"<name>" conflict`, `"You tried to define a scope named"`, `"must contain arguments"` in
rails/rails issues and PRs. Outside rails/rails, the scope-raise messages show up mostly from gems that generate scopes
(boolean_timestamps#7 `loaded`, china_regions#10 `filter`, act_as_time_as_boolean#6 `reject`, kaminari#551 `page`
in 4.1, ransack#369 `search` in 4.1, mailboxer#340 `deleted`), each fixed by renaming or an opt-out in the gem.

## B. Earlier proposals and maintainer positions

* Scope and enum name conflicts raise since 4.1: chancancode in #13389 and #13450 (2013-12): "These scopes with
  'reserved' names has always been problematic and a cause for many subtle bugs, so we decided to fail loudly"
  (#15032). He left out dynamic methods on purpose. rafaelfranca on #14655 (4.1 `scope :public`): intended; "it is in
  the CHANGELOG". #31179 (5.2, merged by rafaelfranca) added the raise for scopes named like a Relation instance method.
* Relation methods taking precedence over model class methods is expected behaviour: sgrif on #26949 (2016,
  Enumerable methods over scopes, "This is the expected behavior."), matthewd on #34250 (2018, `scope :reverse`,
  "This is the expected behaviour.").
* jhawthorn, 1b773bca5c (2020-05, "Avoid confliting Kernel-named scopes on Relation"): the existing
  `singleton_method_added` hook in scoping/named.rb deliberately does not generate a relation delegator when Relation
  already defines the name, with test fixtures `Reply.load(data:)` and `Reply.select(data:)` for exactly this case.
* A warning when a scope overwrites an existing class method existed twice and was removed twice: removed in 2012
  (Jon Leighton, f6db31ec16, "Users should run with -w if they want to be warned about redefined methods"), restored
  by amatsuda in #23331 (2016), removed again in #43204 (2021) after rafaelfranca on #43163: "if we see `scope` just
  as a glorified way to do `def self.some_scope_name` it is better to not warn."
* No issue or PR proposes a warning for a class method shadowed by a Relation method (searched "class method
  shadowed relation", "class method relation delegation conflict", "dangerous_class_method", "method_defined_within"
  and the related threads' cross-references). Not an explicit rejection, but every adjacent decision points the same way.

## C. Prototype and false positives

[prototype.rb](prototype.rb) prepends `singleton_method_added` and `extend` on `ActiveRecord::Base` and records a hit
when a public Relation method (not from Object/Kernel/Active Support, and not one Relation forwards to the model, such
as `name` or `table_name`) has the name of the new class method. [harness.rb](harness.rb): fires for `def self.`,
`class << self`, `define_singleton_method`, `extend Module` on an abstract class (danbooru's shape) and concern
`class_methods`; silent for forwarded names, scopes, ordinary class methods and STI subclasses; 0 hits from Active
Record itself at load ([results.txt](results.txt)).

**Rails' own test models** ([rails_models.rb](rails_models.rb), 221 of 237 files loaded): 4 hits, all deliberate
fixtures: `Bulb.new`, `Parrot.delete_all`, `Reply.load(data:)`, `Reply.select(data:)`.

**23 apps** (20 census apps plus fat_free_crm, otwarchive and danbooru from the boot check, default-branch HEADs in
[apps.txt](apps.txt)), static Prism scan [scan.rb](scan.rb) of `app/`, `lib/`, `plugins/` and engines, raw output
[hits.json](hits.json): 50 raw hits, 25 of them scanner false matches (plain Ruby classes under `app/models`, a
`Data.define` block, a dynamic class); one missed definition (danbooru `BackgroundJob` via `concerning`) added by hand.
That leaves 26 model class methods shadowed on relations, in 6 apps:

| App | Shadowed class methods | On main |
| --- | --- | --- |
| danbooru | `default_order` ×10 (Searchable on ApplicationRecord, 5 `SearchMethods`, 3 `def self.`, BackgroundJob), `update!`, `sample` | 1 call breaks: `pool.rb:83` (`q.order(...).default_order`); the other `default_order` calls go through `apply_default_order` in the model's scope and work |
| discourse | `Post.reverse_order`, `OptimizedImage.lock`, `Poll.preload!`, `DataExplorer::Query.find`, `Calendar::Event.update`, `Group.[]`, `ProblemCheckTracker.[]` | unchanged; `Post.reverse_order` also exists on relations (`topic_view.rb` calls it there and gets Relation's) |
| mastodon | `AccountSummary.readonly?`, `FollowRecommendation.readonly?`, `Setting.cache_key`, `Setting.[]` | unchanged |
| otwarchive | `Question.reorder(positions)` | unchanged |
| fat_free_crm | `Setting.[]` | unchanged |
| lago-api | `Analytics::Base.cache_version` | unchanged |

A definition-time warning would fire on 26 definitions in 6 of 23 apps plus 4 in Rails' own tests. One call site is a
real bug, and it already raises on main. Restricting the names to QueryMethods and SpawnMethods leaves 14 definitions
(danbooru's 10 `default_order`, `reorder`, `reverse_order`, `lock`, `preload!`) for the same single bug. The other 16
were already shadowed on 8.1 and work because the apps call them only on the class.

The with-arguments case (silent reorder) has no real caller: none of the 23 apps, and GitHub code search for
`"def self.default_order("` (23 results) finds qpixel (its arguments raise `UnknownAttributeReference`, not a
reorder), quintel/etengine (a config getter called on the class, 33 stars) and archived or old repos.

**Cost** ([cost.rb](cost.rb)): the check runs only when a class method is defined or a module extended (206 calls for
201 definitions), 0 calls and the same 182,854 allocations over 1,000 query iterations with and without it.

## D. Recommendation, per case

* **`scope :default_order` raises at load:** leave it. It is the 4.1 guard working as designed (chancancode,
  rafaelfranca), loud at boot (Flow's suite errored in 409 of 452 tests from its `scope :default_order`); #60005
  documents it.
* **Class method, called on a relation without arguments:** leave it. It raises `ArgumentError` on the first call,
  so a test that reaches the call finds it (danbooru's pool search). #60005 documents it.
* **Class method called with arguments on a relation:** the only silent case, but no real caller was found, and a
  warning could not tell it apart from 16 working, deliberate overrides in the same 23 apps and 4 Rails fixtures.
  Relation precedence is tested and was called expected behaviour by three maintainers, and the closest earlier
  warning was removed in 2021 because it fired on legitimate overrides. A PR would most likely be closed. Open nothing.

The prototype is not built as a branch.

Run: `mise exec ruby@4.0.9 -- bundle exec ruby harness.rb` (the Gemfile points at a rails/rails checkout at `088fc0cf61`;
`AR_VERSION=8.1.4.1` uses the release); `ruby scan.rb names-main.txt new-names.txt APP_DIR...` for the scan.
