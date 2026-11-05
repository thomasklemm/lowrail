# Rails readiness: 7a78da5a5576d7ab7549b10fb13156788478ba35 against 6e09124217

Base `6e09124217` (8.1.4.1), candidate `7a78da5a55` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-05T00:00:41Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| kaminari | `v1.3.2` (`adb89b8f26`) | 555 / 0F, 555 / 0F | 555 / 0F, 555 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| devise | `05811fb8366edd08874111d0f6fb44543e1c91ef` (`05811fb836`) | 878 / 0F, 878 / 0F | 878 / 0F, 878 / 0F | – | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.1.0 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| rspec-rails | `5072befe5d1b01348a14fa02b6e5a8448874fb53` (`5072befe5d`) | 993 / 50F, 993 / 50F | 993 / 41F, 993 / 41F | 41 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| pundit | `ea9e31a2d7993f038ee52b94ccc9c7411637ba89` (`ea9e31a2d7`) | 184 / 0F, 184 / 0F | 184 / 0F, 184 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| cancancan-sqlite (bumps: ostruct >= 0; shims: 1) | `4362b39b04e6840c8edbd2cb4de16b2d77b19c3c` (`4362b39b04`) | 712 / 0F, 712 / 0F | 712 / 0F, 712 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| cancancan-postgres (bumps: ostruct >= 0; shims: 1) | `4362b39b04e6840c8edbd2cb4de16b2d77b19c3c` (`4362b39b04`) | 712 / 0F, 712 / 0F | 712 / 0F, 712 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| friendly_id-sqlite | `4699c9791db955dfa9929af0f38a4059af550026` (`4699c9791d`) | 530 / 0F, 530 / 0F | 530 / 1F, 530 / 1F | 1 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| friendly_id-postgresql | `4699c9791db955dfa9929af0f38a4059af550026` (`4699c9791d`) | 530 / 0F, 530 / 0F | 530 / 1F, 530 / 1F | 1 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| view_component (shims: 1) | `b1fd129eaeedf4a33986c4ed342f041c2d4a5b0a` (`b1fd129eae`) | 892 / 0F, 892 / 0F | 892 / 14F, 892 / 14F | 14 confirmed | marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| simple_form | `18f38aad0bdeca2ba1815043b94d96fdbbe6a325` (`18f38aad0b`) | 806 / 3F, 806 / 3F | 806 / 3F, 806 / 3F | 3 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| ransack-sqlite (shims: 1) | `fbc3baf164da2a80435d5678a77924c66472f694` (`fbc3baf164`) | 1145 / 22F, 1145 / 15F | 1145 / 24F, 1145 / 17F | 2 confirmed, 33 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ransack-postgresql (shims: 1) | `fbc3baf164da2a80435d5678a77924c66472f694` (`fbc3baf164`) | 1146 / 23F, 1146 / 15F | 1146 / 24F, 1146 / 16F | 1 confirmed, 34 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| administrate (bumps: appraisal false, awesome_print false; shims: 1) | `6cb9cbbbc8032b5802ade02169881e61caf08193` (`6cb9cbbbc8`) | 642 / 0F, 642 / 0F | did not load, did not load | 1 suite-did-not-load | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.0.4 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| jbuilder | `f141f5ede81bf534d62c6ba228975d5ccb90b63d` (`f141f5ede8`) | 138 / 0F, 138 / 0F | 138 / 0F, 138 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| good_job | `e15ee79627` (`e15ee79627`) | 1265 / 2F, 1265 / 2F | 1265 / 2F, 1265 / 2F | 2 base-failing | marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| solid_queue-sqlite (shims: 1) | `b9c646a848` (`b9c646a848`) | 402 / 0F, 402 / 0F | 402 / 0F, 402 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| solid_queue-postgres (shims: 1) | `b9c646a848` (`b9c646a848`) | 402 / 0F, 402 / 0F | 402 / 0F, 402 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| sidekiq-rails | `75982898ff` (`75982898ff`) | 177 / 0F, 177 / 0F | 177 / 0F, 177 / 0F | – | marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| paper_trail-sqlite (shims: 1) | `86ce1b8307` (`86ce1b8307`) | 444 / 0F, 444 / 0F | 444 / 0F, 444 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| paper_trail-postgres (shims: 1) | `86ce1b8307` (`86ce1b8307`) | 510 / 0F, 510 / 0F | 510 / 0F, 510 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| active_model_serializers | `6934c8bd31` (`6934c8bd31`) | 576 / 0F, 576 / 0F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| pagy | `b48c906e31847cc2564b1e8da2995e2b1b8e3e9a` (`b48c906e31`) | 1205 / 0F, 1205 / 0F | 1205 / 0F, 1205 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| turbo-rails | `37530c08780fa6f6dbb56a633de4b81169bdd174` (`37530c0878`) | 247 / 0F, 247 / 0F | 247 / 0F, 247 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| importmap-rails | `f255e55482d9173d8f64db3bfa4317b64445eeb4` (`f255e55482`) | 104 / 0F, 104 / 0F | 104 / 0F, 104 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| propshaft | `e7530a0490c8e1cd4e15dfa9a98717167fa6dccf` (`e7530a0490`) | 170 / 0F, 170 / 0F | 170 / 0F, 170 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| responders | `eb9b9baac1f8e2d44265e20120bdec45c0890a28` (`eb9b9baac1`) | 116 / 0F, 116 / 0F | 116 / 0F, 116 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| rails-controller-testing | `c203673f8011a7cdc2a8edf995ae6b3eec3417ca` (`c203673f80`) | 46 / 4F, 46 / 4F | 46 / 37F, 46 / 37F | 33 confirmed, 2 signature-changed, 2 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| draper | `7fc015f80ccb1f0aa7b8ffaa7a50db76d0cc946c` (`7fc015f80c`) | 425 / 2F, 425 / 2F | 322 / 1F, 322 / 1F | 1 confirmed, 1 test-count-mismatch | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts-as-taggable-on | `719734149d4f4295f497dc9a02884b08051325a3` (`719734149d`) | 312 / 3F, 312 / 0F | 312 / 3F, 312 / 0F | 3 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 5 times per tree); `base-failing` fails on base too; `signature-changed` fails on both with different errors. Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.

## New (0)

None: every candidate flag matches a known finding.

## Known (58)

| Finding | Status | Classes | Count | Suites | Record |
| --- | --- | --- | --- | --- | --- |
| E2 | prepared | 1 confirmed | 1 | ransack-sqlite | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| I1 | issue | 2 confirmed | 2 | friendly_id-postgresql, friendly_id-sqlite | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-draper | record-only | 1 confirmed, 1 test-count-mismatch | 2 | draper | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-dynamic-controller-routes | record-only | 33 confirmed, 2 signature-changed | 35 | rails-controller-testing | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-view_component-dependency-tracker | record-only | 8 confirmed | 8 | view_component | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-view_component-request-url | gem-side | 3 confirmed | 3 | view_component | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-view_component-allocations | gem-side | 2 confirmed | 2 | view_component | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-view_component-locale | gem-side | 1 confirmed | 1 | view_component | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| eco1-ransack-select-manager | gem-side | 2 confirmed | 2 | ransack-postgresql, ransack-sqlite | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| L1 | gem-side | 1 suite-did-not-load | 1 | administrate | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| E4 | prepared | 1 suite-did-not-load | 1 | active_model_serializers | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |

## Fails on base too (118)

| Signature | Count | Suites | Match |
| --- | --- | --- | --- |
| `Minitest::Assertion: Expected [] to include "README.rdoc".` | 2 | rails-controller-testing | known:noise-eco1-both-trees |
| `Minitest::Assertion: Expected at least 1 element matching "input:match('pattern', /\\\\d+/)", found 0.` | 2 | simple_form | known:noise-eco1-both-trees |
| `Nokogiri::XML::XPath::SyntaxError: ERROR: Char out of XML range: .//*[nokogiri:match(.,'class','(?-mix:^(?!.*¼hosen .*¼hosen ).*¼hosen .*$)')] \| self::*[nokogiri:match(.,'class','(?-mix:^(?!.*¼hosen .` | 1 | simple_form | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<a controller=\"people\" class=\"sort_link \" href=\"/people?q%5Bs%5D=id+asc\">id&nbsp;defaultarrow</a>" to match /id<\/a>/` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<a controller=\"people\" class=\"sort_link \" href=\"/people?q%5Bs%5D=name+asc\">Full Name&nbsp;defaultarrow</a>" to match /Full Name<\/a>/` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "SELECT \"issue_343_people\".* FROM \"issue_343_people\" ORDER BY \"issue_343_people\".\"id\" DESC" to include "\"issue_343_people\".\"name\" = "` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "bundler: failed to load command: tmp/fail_sanity_check (tmpRUBYLIB/bundler/source/git/git_proxy.rb:461:in 'Bundler::Source::Git::GitProxy#allowed` | 1 | rspec-rails | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected RuntimeError with message matching /Ransack needs Article associations explicitly allowlisted/ but nothing was raised` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected RuntimeError with message matching /Ransack needs Article attributes explicitly allowlisted/ but nothing was raised` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected ["=> Booting Puma\n", "=> Rails RAILS_VERSION application starting in development \n", "=> Run 'bin/rails server --help' for more startup options\` | 1 | good_job | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected ["=> Booting Puma\n", "=> Rails RAILS_VERSION application starting in production \n", "=> Run 'bin/rails server --help' for more startup options\n` | 1 | good_job | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected '"bundler: failed to load command: tmp/pass_sanity_check (tmpRUBYLIB/bundler/source/git/git_proxy.rb:461:in 'Bundler::Source::Git::GitProxy#allowe` | 1 | rspec-rails | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected no Exception, got #<Ransack::InvalidSearchError: Invalid combinator unknown> with backtrace:` | 4 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected no Exception, got #<Ransack::InvalidSearchError: Invalid search term unknown_attr_eq> with backtrace:` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<ActsAsTaggableOn::Tag id: 1, name: "awesome", taggings_count: 0, type: nil>` | 1 | acts-as-taggable-on | known:noise-eco1-taggable-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: 1` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["c", "b", "a"]` | 1 | acts-as-taggable-on | known:noise-eco1-taggable-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["call-50%off"]` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["tag2", "tag1"]` | 1 | acts-as-taggable-on | known:noise-eco1-taggable-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: [#<Person id: 30, parent_id: nil, name: "a_c", email: nil, only_search: nil, only_sort: nil, only_adm...eated_at: "2026-11-04 21:47:37.398570000 ` | 1 | ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: [#<Person id: 30, parent_id: nil, name: "a_c", email: nil, only_search: nil, only_sort: nil, only_adm...eated_at: "2026-11-04 22:13:15.592262000 ` | 1 | ransack-postgresql | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: [#<Person id: 56, parent_id: nil, name: "name_with_underscore", email: nil, only_search: nil, only_so...eated_at: "2026-11-04 22:13:15.732703000 ` | 1 | ransack-postgresql | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: []` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid combinator 1` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid combinator nand` | 4 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term context` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term name_eq` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term nick_eq` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term notable_name_cont` | 4 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term notable_of_Person_type` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term only_admin_eq` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term quick_cont` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid search term restricted` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid sort term` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid sort term only_admin` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid sort term only_search` | 4 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Invalid sort term persons_salarydesc` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: No valid predicate for full_name` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Predicate eq takes a single value, 2 given for array_where_people_ids` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `Ransack::InvalidSearchError: Predicate eq takes a single value, 2 given for name` | 4 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RuntimeError: Warnings were generated: RAILS/railties/lib/rails/generators/model_helpers.rb: warning: literal string will be frozen in the future (run with --debug-frozen-string-literal for more infor` | 39 | rspec-rails | known:noise-eco1-both-trees |
