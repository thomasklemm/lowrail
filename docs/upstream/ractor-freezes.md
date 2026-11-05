# F1: objects Rails main froze for Ractors, and who mutates them

2026-11-05. Inventory only. Thomas, the same day: no new Rails or gem compatibility PRs until the Rails 8.2 beta,
because the Rails-internal design can still change; we decide then what is fixed in Rails and what outside. So no
Rails branch or queue item was built for this round. Already existing and left as they are: OP1
([rails/rails#59661](https://github.com/rails/rails/pull/59661), draft, branch
[`thomasklemm/parameter-parsers-register-in-place`](https://github.com/thomasklemm/rails/tree/thomasklemm/parameter-parsers-register-in-place)
at `49b835ba58a49e91268c8296fa2d351dd8e36efe`), and the gem drafts
[ankane/blind_index#62](https://github.com/ankane/blind_index/pull/62) (BI1) and
[pond/scimitar#172](https://github.com/pond/scimitar/pull/172) (SC1).

Rails main `1e235cee11b0a7aecb189d8837534807626287aa`, 8-1-stable `6e091242176c322edc5a8907583c01b08b8a60bc`, Ruby
4.0.9.

## Summary

| Frozen object | Commit (PR) | Mutating callers found | Proposed source fix |
| --- | --- | --- | --- |
| `ActionDispatch::Request.parameter_parsers` | ac98c112f4 (#57952), defaults f2be45aaa8 (#57859) | 58 hits in 57 repos; 11 released gems | OP1: mutable until `ractorize!` (#59661, draft) |
| `Model.predicate_builder` and its `TableMetadata` | 3ba8970f4a (#58399) | 3 gems call `register_handler`; blind_index memoizes on `TableMetadata` | freeze in `before_ractorize`, `try_make_shareable` at construction |
| `ActiveRecord.query_transformers` | efd6072d58 (#57852) | 5 hits; iron_trail fails to boot even without Ractors | `try_make_shareable`, or move to `before_ractorize` |
| `ExceptionWrapper.rescue_responses` / `rescue_templates` | 2a28075803 (#57483), cc70d62782 (#57852) | 29 hits in 28 repos; 9 gems | mutable until `ractorize!` (OP1 pattern) |
| `ActionDispatch::Response.default_headers` | 56d19e536b (#58517), 41712078eb (#58656) | 5 hits, 2 real in-place writes | upgrade-guide note; the config path still works |
| `ActionView::Template::Handlers::ERB.escape_ignore_list` | d0743addea (#58359) | 1 hit (`on_load(:action_view)`) | upgrade-guide note |
| `ActiveRecord::Base.time_zone_aware_types` | 0de1bf6ed3 (#58642) | 0 in-place writes after boot | nothing |
| `Model.model_name` (`ActiveModel::Name`) | c4dcf552cf (#58298) | 28 hits in 18 repos, private ivars | upgrade-guide note |
| every `ActiveSupport::TimeZone` | 26e78a20db (#58067) | 206 files stub `Time.zone` (DC4) | already recorded in [app-suites](app-suites.md) DC4 |

The strongest source fixes, for when building resumes: OP1 (already a draft), then the predicate builder, then
`query_transformers` (a plain Ruby 4.0 app with iron_trail can't boot on main, Ractors or not), then
`rescue_responses`.

Already recorded elsewhere and not repeated: frozen `default_url_options` (baa1ca5f2f, #58483), `ViewPaths#_prefixes`
(fd5ffed45b, #58509), `Relation::VALUE_METHODS` (c10c3c5bf4, #57366), the dependency-tracker registry (73bdeced4f,
#57948), copy-on-write reflections (a791f84224, #58668) and `Transactions::ACTIONS` (5700c17cb7, #57323), in
[ecosystem-tests](ecosystem-tests.md) and [ecosystem-round-2](ecosystem-round-2.md).

## When each freeze bites

[`phases.rb`](../../bench/upstream/ractor_freezes/phases.rb) boots a minimal app and tries each mutation in four boot
phases: at require time, in a railtie initializer (also where `config/initializers` run), in an `after_initialize`
block registered at require time or inside an initializer, and after boot. Output:
[phases.json](data/ractor-freezes/phases.json). On 8-1-stable every cell is `ok`; on main:

| Mutation | require | initializer | after_initialize (registered at require) | after_initialize (registered in initializer) | after boot |
| --- | --- | --- | --- | --- | --- |
| `Request.parameter_parsers[k] =` | FrozenError | FrozenError | FrozenError | FrozenError | FrozenError |
| `predicate_builder.register_handler` | FrozenError | FrozenError | FrozenError | FrozenError | FrozenError |
| ivar on `TableMetadata` | FrozenError | FrozenError | FrozenError | FrozenError | FrozenError |
| `model_name.instance_variable_set` | FrozenError | FrozenError | FrozenError | FrozenError | FrozenError |
| `ExceptionWrapper.rescue_responses[k] =`, `merge!` | FrozenError | ok | ok | FrozenError | FrozenError |
| `Response.default_headers[k] =` | (not loaded) | FrozenError | FrozenError | FrozenError | FrozenError |
| `query_transformers <<` (shareable lambda) | ok | ok | ok | FrozenError | FrozenError |
| `time_zone_aware_types <<` | ok | ok | ok | FrozenError | FrozenError |
| `ERB.escape_ignore_list <<` | ok | ok | FrozenError | FrozenError | FrozenError |

The first four freeze when the object is made, so no boot phase works. The rest freeze in `after_initialize`, so
registering during boot still works and only late or per-request writes fail.

## Per object

### `ActionDispatch::Request.parameter_parsers`

[ac98c112f4](https://github.com/rails/rails/commit/ac98c112f4f4088d20420d9cd2634120eab69c0e)
("Freeze parameter parsers hash when it is assigned", Andrew Novoselac, #57952, merged by byroot 2026-07-01) freezes
every value passed to `parameter_parsers=`; the defaults became the frozen `DEFAULT_PARSERS` in
[f2be45aaa8](https://github.com/rails/rails/commit/f2be45aaa8447b0d6efbcb7b42e5c6dbeb6b30b6) (#57859). The PR has no
review comments and doesn't mention in-place registration. Registering in place was never documented (the writer's
doc shows `merge` and assign), but it is the common shape.

Callers: [58 hits in 57 repositories](data/ractor-freezes/parameter_parsers.tsv) writing `parameter_parsers[k] =`,
`||=`, `merge!` or `delete`. Released gems (RubyGems downloads):
[graphiti 2.2.3](https://github.com/graphiti-api/graphiti/blob/1b11959b323cce2d9d8185a9f6c18164c9763eb1/lib/graphiti/rails/railtie.rb)
(1.9M), [graphiti-rails 0.4.2](https://github.com/graphiti-api/graphiti-rails/blob/f8031d1f9659825d7a41f73a4650c616085c187c/lib/graphiti/rails/railtie.rb)
(1.6M), [jsonapi-rails 0.4.1](https://github.com/jsonapi-rb/jsonapi-rails/blob/2e1b5b1413225f72d270512a436519791ff2399f/lib/jsonapi/rails/railtie.rb)
(4.2M), [jsonapi.rb 2.1.1](https://github.com/stas/jsonapi.rb/blob/b5c6b601ea354b45c290bc689ad3da66151c2165/lib/jsonapi/rails.rb)
(4.3M), [scimitar 2.15.0](https://github.com/pond/scimitar/blob/a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d/lib/scimitar/engine.rb)
(2.9M), msgpack_rails 0.4.3 (0.9M), [scim_engine 2.1.3](https://github.com/Cisco-AMP/scim_engine/blob/2bf971c0dbba4efa3b75ba7ea63262b66597fea4/lib/scim_engine/engine.rb),
[two_percent 1.3.1](https://github.com/powerhome/power-tools/blob/bf56f7118af3eb13ba8e4eed23ec8c95a50756f0/packages/two_percent/lib/two_percent/engine.rb),
[infinum_json_api_setup 0.1.1](https://github.com/infinum/infinum-json-api-setup/blob/4098b9d9b221878b1cf454418cb7bd7fb919c0e0/lib/infinum_json_api_setup/rails.rb),
[toon-parser 0.1.0](https://github.com/afshmini/toon-parser/blob/7efc48875a239f64e1a21f7fa36ed5bb4135b12a/lib/toon-parser/railtie.rb)
and kit-api. Apps: Canvas LMS registers `:lineitem` and `:score` in `config/initializers/mime_types.rb` (instructure
`1c9f0bb801`, lines 51–52, plus six forks), keygen-api, Manyfold, Manifold, lumendatabase and trln-ingest (`delete`),
and about 20 copies of the `json_param_key_transform.rb` camelCase initializer (`parameter_parsers[:json] = …`).
jsonapi-resources already uses `merge` and assign.

Source fix: OP1, built and opened as draft #59661 before this round; it keeps the parsers mutable during boot and
freezes them of every includer in a `before_ractorize` hook. Unchanged here.

### `Model.predicate_builder` and `TableMetadata`

[3ba8970f4a](https://github.com/rails/rails/commit/3ba8970f4a0b2f8ab1590d818b1b850be656bfd0) ("Make
ActiveRecord::PredicateBuilder ractor safe", Gannon McGibbon, in #58399 "Active Record ivar ractor safety",
self-merged 2026-08-07) ends `PredicateBuilder#initialize` with `ActiveSupport::Ractors.make_shareable(self)`. On Ruby
4.0 that deep-freezes the handler list and the `TableMetadata`. The PR body says the builder ivars "needed" freezing;
review discussed only memoization in `Persistence`, nothing about `register_handler`, which keeps its in-source
docs example of registering on a builder. The commit changed Rails' own test from registering on
`Topic.predicate_builder` to a subclass that overrides `register_handlers`.

Callers ([register_handler.tsv](data/ractor-freezes/register_handler.tsv)):
* [katalyst-tables 3.14.0](https://github.com/katalyst/tables/blob/dd4c6f6b1779cd0b2fdedbd1e1d9d17d4c922ac4/lib/katalyst/tables/collection/type/string.rb#L46)
  (57k downloads, released 2026-09-30; used by katalyst/koi, content, navigation) registers a `Match` handler on every
  non-exact string filter, at query time.
* [pg_tags_on 1.0.1](https://github.com/cata-m/pg_tags_on/blob/72f6c291a46f8aa38c28a963a3bf90848b3aaf77/lib/pg_tags_on/active_record/base.rb#L24)
  (14k) registers once per model.
* [activerecord-hash_options 0.1.0](https://github.com/kbrock/activerecord-hash_options/blob/194dab605e00647ce65c0a36bee254ec842039a7/lib/active_record/hash_options.rb#L19)
  (3k) registers ten handlers per model.
* blind_index 2.8.1 (5.9M downloads) memoizes `@has_blind_indexes` on `TableMetadata` in
  [`extensions.rb`](https://github.com/ankane/blind_index/blob/master/lib/blind_index/extensions.rb#L5-L9), so every query
  of a model raises (BI1).

Other `TableMetadata` users found (cancancan, torque-postgresql, union_of, activerecord-filter, motor-admin,
graphql-filters) only construct new ones, which stay mutable until the builder wraps them; not affected.

[pb.rb](../../bench/upstream/ractor_freezes/pb.rb) on main: builder and table frozen, `register_handler` and the memo
raise `FrozenError`. Source fix, tried locally and not pushed: `try_make_shareable(self)` in `initialize` (a no-op
unless `unshareable_proc_action` is set, as for callbacks and reflections) plus
`ActiveSupport::Ractors.try_make_shareable(model.predicate_builder)` next to `make_reflections_shareable!` in Active
Record's `before_ractorize` hook. With it, pb.rb registers the handler (`count` returns 1) and the memo works;
[pb_ractor.rb](../../bench/upstream/ractor_freezes/pb_ractor.rb) shows a builder made under `:raise` is shareable at
once, an earlier one becomes shareable when the hook runs, and a Ractor reads the builder. Open point for a real
patch: a model defined after `ractorize!` in an app that leaves `unshareable_proc_action` unset would get a mutable
builder; OP1 solved the same case with a flag the hook sets. katalyst-tables' per-query `register_handler` grows the
shared handler list on every filter and isn't thread-safe either; that is a gem issue, not a reason to keep the
freeze.

### `ActiveRecord.query_transformers`

[efd6072d58](https://github.com/rails/rails/commit/efd6072d5856b6415fb6e87f67dca1bb81744c16) ("Make Active Record
configs ractor shareable", #57852, Gannon McGibbon, self-merged 2026-08-15) calls `make_shareable` on the array in
`after_initialize`. That freezes the array and tries to make each transformer shareable, without the `try_` variant
gmcgibbon himself proposed in the PR thread ("Configuration values can be anything the user wants, so we need to
introduce a try_make_shareable helper"); Edouard Chin answered that string configs need no `try_`, and the patch was
narrowed.

Callers ([query_transformers.tsv](data/ractor-freezes/query_transformers.tsv)):
[iron_trail 0.3.1](https://github.com/trusted/iron_trail/blob/cfbb85d86db4815eb32d55c3b0b244b892229dae/lib/iron_trail/query_transformer.rb#L14)
(62k downloads) pushes a `proc` built in an instance method from `on_load(:active_record)`;
[bemi-rails 0.4.0](https://github.com/pgstack-io/bemi-rails/blob/7c116bc71e39ee2ebf47d30ac9dc6cdf44c67f83/lib/bemi/context.rb#L49)
pushes a `Proc.new` built in a module method at require time. [qt_boot.rb](../../bench/upstream/ractor_freezes/qt_boot.rb)
with both shapes: bemi's proc has the module as `self` and boots on main. iron_trail's shape raises
`Ractor::IsolationError: Proc's self is not shareable` at boot when Active Record loads during boot, and `FrozenError`
when it loads after; 8-1-stable boots both. This breaks apps that never use Ractors, on plain Ruby 4.0. Also: the
graphql-ruby spec and a Spanner example push `QueryLogs` (fine, a module). Source fix: `try_make_shareable`, or freeze
in `before_ractorize`; either keeps 8.1 behavior for apps that don't ractorize.

### `ExceptionWrapper.rescue_responses` and `rescue_templates`

[2a28075803](https://github.com/rails/rails/commit/2a2807580305a55f3aafbe4ccc5aa3fada3af348) (Andrew Novoselac, #57483,
merged by rafaelfranca 2026-05-28) freezes the defaults and has the railtie assign a merged copy;
[cc70d62782](https://github.com/rails/rails/commit/cc70d62782526a3134d6c2a682fc6b935bbb7d7c) (#57852) makes them
shareable in `after_initialize`. In review rafaelfranca asked for a config for `wrapper_exceptions` because "it is
here not for application, but for rails plugins to configure", and gmcgibbon later wrote on
[#58359](https://github.com/rails/rails/pull/58359#issuecomment-5187537357): "I don't think #57483 was the right
choice". The supported path is `config.action_dispatch.rescue_responses`, which Forem, Discourse and Canvas use.

Callers: [29 hits in 28 repositories](data/ractor-freezes/rescue_responses.tsv). Gems, by when they write:
* require time, raise on main: [restful_error 1.0.7](https://github.com/kuboon/restful_error/blob/ea630794e45efe5a98a702e8f1e3a5ee0205e472/lib/restful_error.rb#L65-L67)
  (also in an `inherited` hook), [params_schema](https://github.com/to-omer/params_schema/blob/4ebd3ba410023342ddfc5f6813033a2c23b10c88/lib/params_schema.rb);
* per request, raises: [grape-middleware-lograge 1.2.3](https://github.com/tchak/grape-middleware-lograge/blob/3daaa11d71140a41f044d6a5cea58454239faded/lib/grape/middleware/lograge.rb)
  (34k);
* during boot, still work: [shipit-engine](https://github.com/Shopify/shipit-engine/blob/2f629b62e8bd2d86006f45865f1c6bccaf67176a/lib/shipit/engine.rb)
  (engine `after_initialize`), [dynamic_image 3.4.0](https://github.com/elektronaut/dynamic_image/blob/df01885a44137b38f942c9fd3b93ce2ab6e61996/lib/dynamic_image/engine.rb#L38),
  [md_record](https://github.com/bhserna/md_record/blob/4954f0d668bbc09e4046dbe5510d1329609959ae/lib/md_record/railtie.rb),
  act_as_fire_record_beta, rambulance 3.3.0 (2.0M, from its generated initializer), rexception, halitosis (through the
  config);
* specs: lograge, sentry-rails, gaffe, steroids.

Apps: three trade-tariff apps and npq-registration in `config/initializers` (work), scholarsphere in the
`ApplicationController` body (works when eager loaded, raises when the controller loads after boot in development),
cerberus in `to_prepare` (raises on the first reload), almanac at class definition. Source fix: the OP1 pattern, a
mutable copy until `before_ractorize`, keeping the frozen defaults. A weaker option is an upgrade-guide line pointing
to the config.

### `ActionDispatch::Response.default_headers`

[56d19e536b](https://github.com/rails/rails/commit/56d19e536b409b17d8f89545ff5281c4e1c3eaf6) (Edouard Chin, #58517,
merged by gmcgibbon), with [41712078eb](https://github.com/rails/rails/commit/41712078eb9e44a387e9b31ec4cabc7b90e906ac)
(#58656) copying instead of freezing the config itself after a gem broke. The PR says it also wants to stop runtime
mutation. [dh_boot.rb](../../bench/upstream/ractor_freezes/dh_boot.rb): secure_headers 7.3.0's shape (delete from
`config.action_dispatch.default_headers` in `on_load(:action_controller)`) and a config initializer delete both still
take effect on main. Direct writes ([5 hits](data/ractor-freezes/response_default_headers.tsv)): two app initializers
(CineRoom `[]=`, NimbusLauncher `merge!`) and two old shopify_app copies with `response.default_headers.delete` in a
controller (current shopify_app uses `response.headers.except!`). Upgrade-guide note only.

### `ERB.escape_ignore_list`, `time_zone_aware_types`, `model_name`

* `escape_ignore_list`: [d0743addea](https://github.com/rails/rails/commit/d0743addea8d13187ae5f043c1d2fa1d879508f3)
  (#58359) makes it shareable in `after_initialize` and adds `ActionView::Base.escape_ignore_list=`. hmcguire-shopify
  asked in review for deprecations of the old accessors; the answer was that nothing is deprecated, only nodoc'd. One
  writer found: chatwootnext appends in `on_load(:action_view)`, which raises when Action View loads after boot; raif
  writes in an initializer (works). Upgrade-guide note.
* `time_zone_aware_types` and `skip_time_zone_conversion_for_attributes`:
  [0de1bf6ed3](https://github.com/rails/rails/commit/0de1bf6ed327f3ea3e8290cfb25a4c7be026b82f) (#58642) freezes them
  after initialize. Every writer found sets them in `config/application.rb` or uses `+=`; none mutates after boot.
  Nothing to do.
* `model_name`: [c4dcf552cf](https://github.com/rails/rails/commit/c4dcf552cfc15268a1b448ec6c2f2a2f89d8be52) (#58298)
  makes the memoized `ActiveModel::Name` shareable. [28 hits in 18 repos](data/ractor-freezes/model_name_ivars.tsv)
  set private ivars on it, mostly `@route_key` for singular resources (the old rails/rails#1769 workaround), all small
  apps; they raise at class load. Those that build their own `ActiveModel::Name.new` inside an overridden
  `model_name` keep working, since a new Name isn't frozen (checked): active_type 2.8.0 (4.5M downloads),
  chouette-core, boston-cas. Never supported; upgrade-guide note at most.

## Census apps

Searching the 14 apps of [app-suites](app-suites.md) for all of these names: only OpenProject reaches a frozen object,
through scimitar (OP1). Forem, Discourse and Canvas set `rescue_responses` and OpenProject and Discourse
`default_headers` through the config, which still works.

## The two gem drafts

* **scimitar#172** registers through `parameter_parsers=` when the hash is frozen, which is the documented writer and
  correct with or without OP1. If OP1 merges, scimitar needs nothing and #172 becomes optional. Recommendation: leave
  it a draft, don't mark it ready before the 8.2 beta; close it with one neutral line if OP1 lands.
* **blind_index#62** skips the memo only when the metadata is frozen. With the predicate-builder fix the metadata
  stays mutable unless the app ractorizes, and #62 is still right for ractorized apps. Recommendation: leave it a
  draft until the beta; if Rails keeps freezing at construction, #62 is needed; if it moves the freeze to
  `before_ractorize`, #62 is a small robustness change ankane may or may not want.

## Method and limits

`gh search code` (legacy API: default branches, forks included, at most 100 results per query), 2026-11-05, filtered
for writing calls and with vendored gems, Rails copies and code corpora removed. Counts are lower bounds; "released"
means the line is in the gem's `lib/` of the version on RubyGems. Hits per object are in
[data/ractor-freezes](data/ractor-freezes). The probes are in
[bench/upstream/ractor_freezes](../../bench/upstream/ractor_freezes); run each with `bundle exec ruby` from a Rails
checkout. No branch was pushed and nothing was posted upstream in this round.
