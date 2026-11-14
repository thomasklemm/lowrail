# Rails readiness: 50c54eed065b8bfb1b0bbb5fa770c859baa98f9b against c48c154e3f5285cb2fe4cf03b2e3a62cfd34ffc8

Base `c48c154e3f` (8.2.0.alpha), candidate `50c54eed06` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-14T12:13:04Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| activerecord-import-sqlite3 (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 263 / 0F, 263 / 0F | 263 / 0F, 263 / 0F | – | same |
| activerecord-import-postgresql (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 376 / 0F, 376 / 0F | 376 / 0F, 376 / 0F | – | same |
| paper_trail-sqlite (shims: 1) | `86ce1b8307` (`86ce1b8307`) | 444 / 0F, 444 / 0F | 444 / 0F, 444 / 0F | – | same |
| paper_trail-postgres (shims: 1) | `86ce1b8307` (`86ce1b8307`) | 510 / 0F, 510 / 0F | 510 / 0F, 510 / 0F | – | same |
| audited (shims: 1) | `v5.8.0` (`f935285c27`) | 221 / 1F, 221 / 1F | 221 / 1F, 221 / 1F | 1 base-failing | same |
| store_model | `v4.6.2` (`8ecbaa229e`) | 549 / 11F, 549 / 11F | 549 / 11F, 549 / 11F | 11 base-failing | same |
| attr_json (bumps: rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79) | `v2.6.0` (`bec4645742`) | 281 / 8F, 281 / 8F | 281 / 8F, 281 / 8F | 8 base-failing | same |
| mobility-sqlite3 (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 748 / 91F, 748 / 91F | 748 / 91F, 748 / 91F | 91 base-failing | same |
| mobility-postgres (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 1277 / 190F, 1277 / 190F | 1277 / 190F, 1277 / 190F | 190 base-failing | same |
| globalize-sqlite3 (shims: 1) | `v7.1.3` (`38e5fe5aeb`) | 304 / 0F, 304 / 0F | 304 / 0F, 304 / 0F | – | same |
| globalize-postgresql (shims: 1) | `v7.1.3` (`38e5fe5aeb`) | 305 / 0F, 305 / 0F | 305 / 0F, 305 / 0F | – | same |
| enumerize-sqlite3 (shims: 1) | `v3.0.0` (`8688372f15`) | 274 / 0F, 274 / 0F | 274 / 0F, 274 / 0F | – | same |
| enumerize-postgresql (shims: 1) | `v3.0.0` (`8688372f15`) | 274 / 0F, 274 / 0F | 274 / 0F, 274 / 0F | – | same |
| typedstore (shims: 1) | `v1.6.0` (`2f3fb98e65`) | 581 / 4F, 581 / 6F | 581 / 454F, 581 / 454F | 448 confirmed, 2 signature-changed, 4 base-failing | same |
| typedstore-main (shims: 1) | `263050a196` (`263050a196`) | 581 / 0F, 581 / 2F | 581 / 0F, 581 / 2F | 2 base-failing | same |
| ar_lazy_preload | `v2.1.3` (`678e82ae52`) | 134 / 0F, 134 / 0F | 134 / 0F, 134 / 0F | – | same |
| active_record_query_trace | `v1.9` (`5c67364604`) | did not load, did not load | did not load, did not load | 2 suite-did-not-load | same |
| annotaterb | `v4.26.0` (`4c95876ecb`) | 900 / 0F, 900 / 0F | 900 / 0F, 900 / 0F | – | same |
| ancestry-sqlite3 (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 31F, 133 / 31F | 133 / 31F, 133 / 31F | 31 base-failing | same |
| ancestry-pr770 (shims: 1) | `68789a1903` (`68789a1903`) | 259 / 7F, 259 / 7F | 259 / 7F, 259 / 7F | 7 base-failing | same |
| ancestry-pg (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 32F, 133 / 32F | 133 / 32F, 133 / 32F | 32 base-failing | same |
| acts_as_list-sqlite | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | same |
| acts_as_list-postgresql | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | same |
| discard | `v2.0.0` (`cdeb3d40d8`) | 92 / 0F, 92 / 0F | 92 / 0F, 92 / 0F | – | same |
| paranoia (shims: 2) | `a950fe4981` (`a950fe4981`) | 101 / 0F, 101 / 0F | 101 / 0F, 101 / 0F | – | same |
| money-rails | `v3.0.0` (`f5e2af7298`) | 268 / 1F, 268 / 0F | 268 / 1F, 268 / 0F | 1 base-failing | same |
| friendly_id-sqlite | `4699c9791db955dfa9929af0f38a4059af550026` (`4699c9791d`) | 530 / 0F, 530 / 0F | 530 / 0F, 530 / 0F | – | same |
| friendly_id-postgresql | `4699c9791db955dfa9929af0f38a4059af550026` (`4699c9791d`) | 530 / 0F, 530 / 0F | 530 / 0F, 530 / 0F | – | same |
| counter_culture-sqlite3 (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | same |
| counter_culture-postgresql (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | same |
| activerecord-session_store | `v2.3.0` (`74011f1318`) | 62 / 0F, 62 / 0F | 62 / 0F, 62 / 0F | – | same |
| attr_encrypted (shims: 1) | `v4.2.0` (`c2aa160c23`) | 151 / 1F, 151 / 1F | 151 / 1F, 151 / 1F | 1 base-failing | same |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 5 times per tree), `one-seed` too but past the suite's cap on alone reruns; `base-failing` fails on base too; `signature-changed` fails on both with different errors. Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.

## New (0)

None: every candidate flag matches a known finding.

## Known (452)

| Finding | Status | Classes | Count | Suites | Record |
| --- | --- | --- | --- | --- | --- |
| A59-1 | gem-side | 448 confirmed, 2 signature-changed | 450 | typedstore | [ar-gems-after-59141.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-gems-after-59141.md) |
| A59-qt | gem-side | 2 suite-did-not-load | 2 | active_record_query_trace | [ar-gems-after-59141.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-gems-after-59141.md) |

## Fails on base too (381)

| Signature | Count | Suites | Match |
| --- | --- | --- | --- |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column articles.locale does not exist` | 3 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column articles.title does not exist` | 64 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column comments.content does not exist` | 20 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column container_posts.title does not exist` | 21 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column hstore_posts.title does not exist` | 18 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column json_container_posts.title does not exist` | 18 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column json_posts.title does not exist` | 18 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column jsonb_posts.title does not exist` | 21 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column serialized_posts.subtitle does not exist` | 1 | mobility-postgres | new |
| `ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column: articles.locale:` | 3 | mobility-sqlite3 | new |
| `ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column: articles.title:` | 64 | mobility-sqlite3 | new |
| `ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column: comments.content:` | 20 | mobility-sqlite3 | new |
| `ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column: serialized_posts.subtitle:` | 1 | mobility-sqlite3 | new |
| `ArgumentError: Invalid Timezone: US/Pacific` | 6 | attr_json | new |
| `ArgumentError: wrong number of arguments (given 1, expected 0)` | 7 | ancestry-pr770 | new |
| `Capybara::ElementNotFound: Unable to find field "Title" that is not disabled` | 1 | attr_json | new |
| `Capybara::ElementNotFound: Unable to find link or button "add Person role"` | 1 | attr_json | new |
| `NoMethodError: undefined method 'stub' for an instance of User` | 1 | attr_encrypted | new |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ActiveRecord::ActiveRecordError: cannot update a new record> with backtrace:` | 1 | typedstore | new |
| `RSpec::Expectations::ExpectationNotMetError: expected ArgumentError with "You cannot query on mobility attributes translated with the Serialized backend (content).", got #<ArgumentError: Attribute is ` | 2 | mobility-postgres, mobility-sqlite3 | new |
| `RSpec::Expectations::ExpectationNotMetError: expected ArgumentError with "You cannot query on mobility attributes translated with the Serialized backend (title)." but nothing was raised` | 2 | mobility-postgres, mobility-sqlite3 | new |
| `RSpec::Expectations::ExpectationNotMetError: expected: {"apps" => [123]}` | 2 | typedstore-main | new |
| `RSpec::Expectations::MultipleExpectationsNotMetError: Got 2 failures from failure aggregation block:` | 2 | mobility-postgres | new |
| `Minitest::Assertion: [ActiveRecord::RecordInvalid] exception expected, not` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'query' for an instance of ActiveRecord::ConnectionAdapters::SQLite3Adapter` | 5 | store_model | known:R2-10 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestAncestryColumnValidationFailsTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestAncestryColumnValidationStringKeyFailsTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestAncestryColumnValidationStringKeyTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestAncestryColumnValidationTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestAncestryColumnValuesTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestBuildAncestryFromOtherIdsTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestBuildAncestryFromParentIdsTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestCounterCacheWhenUpdatingParentAndCurrentIsNilTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestCounterCacheWhenUpdatingParentAndPreviousIsNilTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestCounterCacheWhenUpdatingParentTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestDepthCachingAfterSubtreeMovementTestNode` | 3 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestDescendantsMoveWithNodeTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestHasAncestryDetectsChangesInAfterSaveTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestHasAncestryDetectsChangesInBeforeSaveTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestIntegrityCheckingTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestIntegrityRestorationTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestModifiedParentsSetAncestryProperlyTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestNodeBeforeLastSaveTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestNodeExcludedByDefaultScopeShouldStillMoveWithParentTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestNodeInDatabaseChildrenTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestNodeInDbFirstNodeTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestParentNotFoundTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestRootNotFoundTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestSetParentIdTestNode` | 4 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestSetParentTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestTouchOptionEnabledPropagatesWithModificationTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestTouchPropogatesMultipleLevelsTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestUpdateDescendantsWithChangedParentValueTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `NoMethodError: undefined method 'validation_context=' for an instance of AncestryTestDatabase::TestValidateDescendantsDepthTestNode` | 2 | ancestry-pg, ancestry-sqlite3 | known:R2-5 |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ArgumentError: JsonTypedStoreModel has no attribute 'no_default' to define a reader for> with backtrace:` | 1 | typedstore | known:A59-1 |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ArgumentError: MarshalTypedStoreModel has no attribute 'no_default' to define a reader for> with backtra` | 1 | typedstore | known:A59-1 |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ArgumentError: YamlTypedStoreModel has no attribute 'no_default' to define a reader for> with backtrace:` | 1 | typedstore | known:A59-1 |
| `RSpec::Expectations::ExpectationNotMetError: expected {"en" => "{foo: :bar}"} to match hash {en: "{:foo=>:bar}"}` | 1 | mobility-postgres | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected {en: "{foo: :bar}"} to match hash {en: "{:foo=>:bar}"}` | 2 | mobility-postgres, mobility-sqlite3 | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected: "money-rails/helpers/action_view_extension"` | 1 | money-rails | known:noise-r2-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<#<Class:0xX> id: nil, name: nil, store_id: nil, configuration: #<Configuration color...liers: nil>, union_test: nil, validation_hooks_configura` | 2 | store_model | known:R2-11 |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<#<Class:0xX> id: nil, name: nil, store_id: nil, configuration: [#<Configuration colo...liers: nil>, union_test: nil, validation_hooks_configura` | 2 | store_model | known:R2-11 |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<#<Class:0xX> id: nil, name: nil, store_id: nil, configuration: {"foo" => #<Configura...liers: nil>, union_test: nil, validation_hooks_configura` | 1 | store_model | known:R2-11 |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<#<Class:0xX> id: nil, name: nil, store_id: nil, configuration: {foo: #<Configuration...liers: nil>, union_test: nil, validation_hooks_configura` | 1 | store_model | known:R2-11 |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<Encoding:UTF-8> "{:foo=>\"bar\"}"` | 1 | audited | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected: 1` | 2 | counter_culture-postgresql, counter_culture-sqlite3 | known:noise-r2-counter_culture-order |
