# UG82D validation by execution (2026-11-27)

Every claim in the guide section and the PR body was run on Ruby 4.0.9 with SQLite in memory. The runs used
Active Record 8.1.4.1 as the control, rails/rails main `088fc0cf61` (still main at this check) and the new head
`ba46acbfd7`. Script: [validate.rb](validate.rb). Exact outputs: [validate-results.txt](validate-results.txt), with the
head's output identical to main's. Earlier repros: [results.txt](results.txt).

Commands: `AR_VERSION=8.1.4.1 ruby validate.rb`, `RAILS_PATH=<checkout> ruby validate.rb`.

| Claim | 8.1.4.1 | main 088fc0cf61 |
| --- | --- | --- |
| 1. `scope :default_order` | defines | `ArgumentError: You tried to define a scope named "default_order" on the model "Post", but Active Record already defined a class method with the same name.` (verbatim as in the guide) |
| 2. `def self.default_order` on the model | `["a","b","c"]`, `ORDER BY position ASC` | same |
| 3. `Post.where(published: true).default_order`, `Post.all.default_order` | `["a","b"]`, `["a","b","c"]` | `ArgumentError: The method .default_order() must contain arguments.` |
| 4. `def self.default_order(column) = order(column => :desc)`, `ArgPost.where(published: true).default_order(:position)` | `["b","a"]`, `ORDER BY position DESC` | `["a","b"]`, `ORDER BY position ASC`, no error (silent reorder) |
| 4. with `.order(:title)` after it | `["b","a"]` (class method's DESC plus title) | `["a","b"]` (default order replaced by the explicit order) |
| 4. qpixel `License.enabled.default_order(category, user_default)` shape | sorted list | `ActiveRecord::UnknownAttributeReference: Dangerous query method ...` (args are not order args) |
| 4. qpixel `License.enabled.default_order` (no args) | sorted list | `ArgumentError: ... must contain arguments.` |
| 5. `class << self; def default_order` | works on model and relation | model works; relation raises as in 3 |
| 5. danbooru shape: `extend Searchable` on an abstract ApplicationRecord, `Pool` `extend SearchMethods` | `Pool.search(order: "post_count")`: `ORDER BY size desc, updated_at DESC` | model call works; `q.order(...).default_order` raises as in 3 |
| 5. danbooru `apply_default_order(params)` on a relation (Searchable calls `default_order` inside the class method) | `ORDER BY updated_at DESC` | same: runs in the model's scope, `self` is the class, so unaffected |
| 5. attribute or column named `default_order` | works | works |
| 5. `belongs_to`/`has_many :default_order` | works | works |
| 5. `Post.where(nil).unscope(:default_order)` | `ArgumentError: invalid unscoping argument` (not supported then) | `SELECT "posts".* FROM "posts"`, no interaction with the class method |
| 5. `has_many :comments, default_order: :position` on a model with `def self.default_order` | `Unknown key: :default_order` (option is new) | `ORDER BY comments.position ASC`, no interaction |

Mechanism (asked by Thomas), run with the same script:

| Probe | 8.1.4.1 | main |
| --- | --- | --- |
| `ActiveRecord::Base.respond_to?(:default_order)` | false | true |
| `Object.respond_to?(:default_order, true)` | false | false |
| `ActiveRecord::Base.method(:default_order).owner` | NameError | `ActiveRecord::Querying` |
| `QUERYING_METHODS.include?(:default_order)` | false | true |
| `Comment.send(:dangerous_class_method?, :default_order)` (plain model) | false | true |
| `Relation.instance_method(:default_order).owner` | NameError | `ActiveRecord::QueryMethods` |
| `Post.method(:default_order).owner` (with `def self.default_order`) | `#<Class:Post>` | `#<Class:Post>` |
| `Post.where(nil).method(:default_order).owner` | `Post::ActiveRecord_Relation` (generated delegator) | `ActiveRecord::QueryMethods` |

Source lines at main `088fc0cf61` (checked with `git show`): querying.rb L15 (`:default_order` in `QUERYING_METHODS`,
delegated to `all` at L24); scoping/named.rb L202-206 (`dangerous_class_method?` raise); attribute_methods.rb L273-285;
relation/delegation.rb L124-137 (`method_missing` forwards only for methods the relation lacks); query_methods.rb
L946-951 (`default_order(*args)`) and L2631-2633 (`check_if_method_has_arguments!`).

## Guide text decision

The relation-case error is now quoted, like the scope error. "With arguments, it can silently change the ordering" is
accurate for order-like arguments (claim 4). It is reworded as "uses them as the relation's default order, which can
silently change the ordering", since the arguments become a default order that any explicit `order` replaces. The
qpixel shape raises a different error instead, which "can" covers, so the guide doesn't list it.

## Citations (checked 2026-11-27)

| Project | Stars | Last push / release | Line | Decision |
| --- | --- | --- | --- | --- |
| fatfreecrm/fat_free_crm | 3632 | push 2026-11-19; gem 0.28.0 2026-04-19, 140,802 downloads | v0.28.0 `1f3dd674f3` L18 `scope :default_order,  -> { order('created_at DESC') }`; same line on master `dcd1bef280` | Released gem: link the v0.28.0 tag commit with the version in the link text (line permalink rule) instead of master |
| danbooru/danbooru | 2946 | push 2026-11-27 | master `03652f924f` (current) L83 `q = q.order(Arel.sql("cardinality(post_ids) desc")).default_order` | App without releases: current default-branch SHA. Only cited relation-case caller, call shape reproduced above |
| otwcode/otwarchive | 2459 | push 2026-11-21 | master `452391b648` (current) L12 `scope :default_order, -> { order(:sortable_name) }` | App, current SHA |
| codidact/qpixel | 444 | push 2026-11-23 | develop `dd2c62a513` license.rb | Not cited: niche, and its with-arguments call raises rather than reordering |
| fjordllc/bootcamp | | | | Dropped from the body earlier; the three above suffice |

Order in the body is by reach within each case: fat_free_crm then otwarchive for the scope, danbooru for the relation.

## Lint

`mdl --style ./.mdlrc.rb guides/source/upgrading_ruby_on_rails.md` (mdl 0.12.0, Rails' Gemfile.lock version) exits 0
on the old and new head. `git diff --check` is clean.
