# Rails readiness: bdb3d960121e7eb73a61c04099d1eef3c821e397 against 6e091242176c322edc5a8907583c01b08b8a60bc

Base `6e09124217` (8.1.4.1), candidate `bdb3d96012` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-05T17:41:41Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| redmine (shims: 1) | `d9f5f18b65dc7f27509a8eb5ea18fe4a8dab0335` (`d9f5f18b65`) | 6117 / 0F, 6117 / 0F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| redmine-shimmed (shims: 2) | `d9f5f18b65dc7f27509a8eb5ea18fe4a8dab0335` (`d9f5f18b65`) | 6117 / 0F, 6117 / 0F | 6117 / 4F, 6117 / 4F | 4 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| lobsters (shims: 1) | `6f6e48f652ff10b8efb84c4882108f07a238340b` (`6f6e48f652`) | 936 / 0F, 936 / 1F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| lobsters-rspec-rails-main (bumps: rspec-rails https://github.com/rspec/rspec-rails 9fb6f4f0a3; shims: 1) | `6f6e48f652ff10b8efb84c4882108f07a238340b` (`6f6e48f652`) | 936 / 0F, 936 / 1F | 936 / 0F, 936 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| solidus-core (shims: 1) | `ed00fc881c88d62af152e550b68e859715cf9bf3` (`ed00fc881c`) | 4487 / 0F, 4487 / 0F | 4487 / 0F, 4487 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| solidus-api (shims: 1) | `ed00fc881c88d62af152e550b68e859715cf9bf3` (`ed00fc881c`) | 684 / 0F, 684 / 0F | 684 / 1F, 684 / 1F | 1 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| writebook (Rails 3a4961048a → bdb3d96012; ruby 3.4.12; bumps: globalid 1.4.0) | `d57c62bc19edac3930d3860a2584757f1d45d07c` (`d57c62bc19`) | 313 / 2F, 313 / 2F | 313 / 2F, 313 / 2F | 2 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| writebook-system (Rails 3a4961048a → bdb3d96012; ruby 3.4.12; bumps: globalid 1.4.0) | `d57c62bc19edac3930d3860a2584757f1d45d07c` (`d57c62bc19`) | 3 / 0F, 3 / 0F | 3 / 0F, 3 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| mastodon (bumps: rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 1) | `da4edd9b8003f54a5815165b5c8193604fbe679d` (`da4edd9b80`) | 8010 / 0F, 8010 / 0F | 8010 / 2435F, 8010 / 2435F | 2435 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mastodon-prs (Rails 6e09124217 → cc1ff7b867 (bdb3d96012 + #59574, #59627, #59630, #59642, #59644, #59629, #59628, #59621, #59617, #59611, #59609, #59569, #59565, #59564, #59557); bumps: rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 2) | `da4edd9b8003f54a5815165b5c8193604fbe679d` (`da4edd9b80`) | 8010 / 0F, 8010 / 0F | 8010 / 34F, 8010 / 34F | 34 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| forem (ruby 3.3.13; bumps: amazing_print 3.0.0, bullet 8.3.0, carrierwave 3.1.4, rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 3) | `310cb3f37b0a9eb351828218d7bbd5d8c15840f1` (`310cb3f37b`) | 16487 / 5F, 16487 / 6F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.0.4 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| forem-shimmed (ruby 3.3.13; bumps: amazing_print 3.0.0, bullet 8.3.0, carrierwave 3.1.4, rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 4) | `310cb3f37b0a9eb351828218d7bbd5d8c15840f1` (`310cb3f37b`) | 16487 / 5F, 16487 / 6F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.0.4 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| forem-f1-schema (ruby 3.3.13; bumps: amazing_print 3.0.0, bullet 8.3.0, carrierwave 3.1.4, rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 5) | `310cb3f37b0a9eb351828218d7bbd5d8c15840f1` (`310cb3f37b`) | 16487 / 5F, 16487 / 6F | 16487 / 1694F, 16487 / 1631F | 1574 confirmed, 1 signature-changed, 10 order-dependent, 156 one-seed, 5 base-failing | herb: - -> 0.11.1, marcel: 1.0.4 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| chatwoot (ruby 3.4.4; bumps: rails-i18n ~> 8.0, sprockets-rails >= 0, administrate-field-belongs_to_search vendor-gems/administrate-field-belongs_to_search-0.10.0, ruby-vips 2.3.0, groupdate 6.8.0, redis-client 0.30.1, rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 2) | `17b246068c1e141ba0dc8488ca7f4c83f466e8ce` (`17b246068c`) | 7682 / 67F, 7682 / 64F | did not load, did not load | 1 suite-did-not-load | globalid: 1.2.1 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| chatwoot-shimmed (ruby 3.4.4; bumps: rails-i18n ~> 8.0, sprockets-rails >= 0, administrate-field-belongs_to_search vendor-gems/administrate-field-belongs_to_search-0.10.0, ruby-vips 2.3.0, groupdate 6.8.0, redis-client 0.30.1, rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 3) | `17b246068c1e141ba0dc8488ca7f4c83f466e8ce` (`17b246068c`) | 7682 / 67F, 7682 / 64F | 7682 / 284F, 7682 / 264F | 200 confirmed, 3 signature-changed, 10 order-dependent, 7 one-seed, 65 base-failing | globalid: 1.2.1 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| chatwoot-prs (Rails 6e09124217 → cc1ff7b867 (bdb3d96012 + #59574, #59627, #59630, #59642, #59644, #59629, #59628, #59621, #59617, #59611, #59609, #59569, #59565, #59564, #59557); ruby 3.4.4; bumps: rails-i18n ~> 8.0, sprockets-rails >= 0, administrate-field-belongs_to_search vendor-gems/administrate-field-belongs_to_search-0.10.0, ruby-vips 2.3.0, groupdate 6.8.0, redis-client 0.30.1, rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79; shims: 3) | `17b246068c1e141ba0dc8488ca7f4c83f466e8ce` (`17b246068c`) | 7682 / 67F, 7682 / 64F | 7682 / 104F, 7682 / 84F | 20 confirmed, 10 order-dependent, 7 one-seed, 68 base-failing | globalid: 1.2.1 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| discourse (shims: 1) | `f2eb5d605b577bb62715c5df54ef390f133a9e81` (`f2eb5d605b`) | 35822 / 28F, 35822 / 33F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| discourse-shimmed (shims: 2) | `f2eb5d605b577bb62715c5df54ef390f133a9e81` (`f2eb5d605b`) | 35822 / 28F, 35822 / 33F | 35822 / 158F, 35822 / 158F | 130 confirmed, 28 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| discourse-prs (Rails 6e09124217 → cc1ff7b867 (bdb3d96012 + #59574, #59627, #59630, #59642, #59644, #59629, #59628, #59621, #59617, #59611, #59609, #59569, #59565, #59564, #59557); shims: 2) | `f2eb5d605b577bb62715c5df54ef390f133a9e81` (`f2eb5d605b`) | 35822 / 28F, 35822 / 33F | 35822 / 59F, 35822 / 58F | 30 confirmed, 1 order-dependent, 28 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| spree-core (shims: 1) | `0eb13214ed61c48c0cebdb356e0235c0b40e61d7` (`0eb13214ed`) | 11236 / 0F, 11236 / 1F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| spree-core-prs (Rails 6e09124217 → cc1ff7b867 (bdb3d96012 + #59574, #59627, #59630, #59642, #59644, #59629, #59628, #59621, #59617, #59611, #59609, #59569, #59565, #59564, #59557); shims: 1) | `0eb13214ed61c48c0cebdb356e0235c0b40e61d7` (`0eb13214ed`) | 11236 / 0F, 11236 / 1F | 11236 / 49F, 11236 / 49F | 49 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| spree-api (shims: 1) | `0eb13214ed61c48c0cebdb356e0235c0b40e61d7` (`0eb13214ed`) | 6320 / 0F, 6320 / 0F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| spree-api-prs (Rails 6e09124217 → cc1ff7b867 (bdb3d96012 + #59574, #59627, #59630, #59642, #59644, #59629, #59628, #59621, #59617, #59611, #59609, #59569, #59565, #59564, #59557); shims: 1) | `0eb13214ed61c48c0cebdb356e0235c0b40e61d7` (`0eb13214ed`) | 6320 / 0F, 6320 / 0F | 6320 / 4F, 6320 / 4F | 4 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| sure (ruby 3.4.9; bumps: lookbook 2.3.15) | `529d7de76f07ba0557e8a442dd7c53cdd401169a` (`529d7de76f`) | 14661 / 0F, 14661 / 0F | 14661 / 487F, 14661 / 487F | 487 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 5 times per tree), `one-seed` too but past the suite's cap on alone reruns; `base-failing` fails on base too; `signature-changed` fails on both with different errors. Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.

## New (0)

None: every candidate flag matches a known finding.

## Known (5181)

| Finding | Status | Classes | Count | Suites | Record |
| --- | --- | --- | --- | --- | --- |
| R1 | open-pr | 2195 confirmed | 2195 | mastodon | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SU3 | record-only | 3 confirmed | 3 | sure | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| FO-rest | record-only | 14 confirmed | 14 | forem-f1-schema | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SU2 | record-only | 455 confirmed | 455 | sure | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| CW1 | open-pr | 4 confirmed | 4 | chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| FO-deprecations | record-only | 1435 confirmed, 1 signature-changed | 1436 | forem-f1-schema | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| CW6 | open-pr | 54 confirmed | 54 | chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS-arel | open-pr | 101 confirmed | 101 | discourse-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| FO1 | gem-side | 72 confirmed, 10 order-dependent, 156 one-seed | 238 | forem-f1-schema | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| M-prefixes | gem-side | 10 confirmed | 10 | discourse-prs, discourse-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SP1 | prepared | 50 confirmed | 50 | spree-core-prs, spree-api-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SU4 | gem-side | 2 confirmed | 2 | sure | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| S1 | prepared | 3 confirmed, 1 suite-did-not-load | 4 | redmine-shimmed, discourse-prs, discourse-shimmed, redmine | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SU5 | gem-side | 55 confirmed | 55 | sure, chatwoot-prs, chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| M1 | record-only | 225 confirmed | 225 | mastodon | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| FO3 | gem-side | 53 confirmed | 53 | forem-f1-schema | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS3 | record-only | 12 confirmed | 12 | discourse-prs, discourse-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| CW2 | open-pr | 122 confirmed, 3 signature-changed | 125 | chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| S2 | prepared | 25 confirmed | 25 | mastodon, mastodon-prs, redmine-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS-precision | record-only | 20 confirmed | 20 | discourse-shimmed, discourse-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS-errors-inspect | record-only | 6 confirmed | 6 | discourse-prs, discourse-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| noise-discourse-smtp | noise | 1 confirmed | 1 | discourse-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| M-precision | record-only | 6 confirmed | 6 | mastodon, mastodon-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| M-enum | record-only | 2 confirmed | 2 | mastodon, mastodon-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| CW3 | record-only | 4 confirmed | 4 | chatwoot-prs, chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SP3 | gem-side | 2 confirmed | 2 | spree-api-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| M-vary | record-only | 19 confirmed | 19 | mastodon-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SP2 | record-only | 1 confirmed | 1 | spree-api-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS-vary | record-only | 6 confirmed | 6 | discourse-prs, discourse-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| CW4 | record-only | 4 confirmed | 4 | chatwoot-prs, chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| CW5 | record-only | 4 confirmed | 4 | chatwoot-prs, chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS4 | record-only | 2 confirmed | 2 | discourse-prs, discourse-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| SO1 | record-only | 1 confirmed | 1 | solidus-api | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| FO-boot | record-only | 1 suite-did-not-load | 1 | forem | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| DS1 | gem-side | 1 suite-did-not-load | 1 | discourse | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| L1 | gem-side | 1 suite-did-not-load | 1 | lobsters | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| AR-2 | open-pr | 2 suite-did-not-load | 2 | spree-api, spree-core | [api-regressions.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/api-regressions.md) |
| CW-boot | gem-side | 1 suite-did-not-load | 1 | chatwoot | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| F1 | open-pr | 1 suite-did-not-load | 1 | forem-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| noise-chatwoot-order | noise | 20 order-dependent, 14 one-seed | 34 | chatwoot-prs, chatwoot-shimmed | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| noise-discourse-order | noise | 1 order-dependent | 1 | discourse-prs | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |

## Fails on base too (197)

| Signature | Count | Suites | Match |
| --- | --- | --- | --- |
| `ActionController::Redirecting::OpenRedirectError: Unsafe redirect to "http://0.0.0.0:3000/integrations/slack/contact.png", pass allow_other_host: true to redirect anyway.` | 4 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `ActionController::Redirecting::OpenRedirectError: Unsafe redirect to "http://0.0.0.0:3000/integrations/slack/user.png", pass allow_other_host: true to redirect anyway.` | 4 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `ActiveRecord::RecordInvalid: Validation failed: Domain has already been taken` | 1 | lobsters-rspec-rails-main | known:noise-lobsters-submit-story |
| `ChunkyPNG::SignatureMismatch: PNG signature not found, found nil instead of "\x89PNG\r\n\x1A\n"!` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: /home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby --disable-gems -e Process.wait(Process.spawn('/bin/true'))` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: /home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby -e STDOUT.write('x' * 2048)` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: magick --version` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: magick /tmp/X -auto-orient -background white -interlace none -flatten -debug all /tmp/X` | 10 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: magick jpeg:/tmp/X -auto-orient -background white -interlace none -flatten -debug all -quality 40 jpg:/tmp/X` | 4 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: magick png:/tmp/X -auto-orient -background white -interlace none -flatten -debug all -quality 1 jpg:/tmp/X` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Discourse::Utils::CommandError: magick public/uploads/default/test_2/original/1X/f5c5ad82569d6751a7438eda2ea6e224366b5dd7.jpeg /tmp/X` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Errno::ECONNRESET: Connection reset by peer` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `Errno::ENOENT: No such file or directory @ rb_sysopen - /tmp/X` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `JSON::NestingError: nesting of 100 is too deep` | 1 | forem-f1-schema | known:noise-forem-both-trees |
| `JSON::ParserError: unexpected token at 'Puma starting in cluster mode...` | 2 | forem-f1-schema | known:noise-forem-both-trees |
| `Minitest::Assertion: Expected: "VipsForeignLoadHeifFile"` | 2 | writebook | known:WB-vips |
| `Mocha::ExpectationError: unexpected invocation: Discourse.warn("Failed to render topic OG image", topic_id: 937, error: "nice -n 10 magick -background none -size 1200xX MSVG:/tmp/X -depth 8 -define pn` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `NoMethodError: undefined method '[]' for nil` | 14 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `NoMethodError: undefined method 'text' for nil` | 4 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `NoMethodError: undefined method 'width' for nil` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `NoMethodError: undefined method 'uid' for nil` | 1 | forem-f1-schema | known:noise-forem-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: #<ActiveSupport::BroadcastLogger:0xX @broadcasts=[#<ActiveSupport::Logger:0xX @level=0, @progname=nil, @default_formatter=#<Logger::Formatter:0xX @datetime` | 1 | forem-f1-schema | known:noise-forem-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: Expected 200 status code, but got 422` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/x... \n \n </table>\n </td>\n </tr>\n </table>` | 2 | chatwoot-prs | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:122:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:135:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:168:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:258:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:270:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:294:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:333:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:338:in &#39;block (4 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ntroller_spec.rb:349:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ontroller_spec.rb:41:in &#39;block (4 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ontroller_spec.rb:48:in &#39;block (4 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ontroller_spec.rb:82:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n <meta charset=\"utf-8\" />\n <meta name=\"viewport\"...ontroller_spec.rb:96:in &#39;block (3 levels` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected #<Mail::Body:0xX @boundary=nil, @preamble=nil, @epilogue=nil, @charset="US-ASCII", @pa... </td>\n </tr>\n </table>\n </body>\n</html>\n", @ascii_o` | 1 | chatwoot-prs | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected #<Upload id: 146, user_id: 2166, original_filename: "wrong_upload.png", filesize: 2297, width: 244, h...ion_status: 1, security_last_changed_at: n` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected ActionController::ParameterMissing with "param is missing or the value is empty: contact email", got #<ActionController::ParameterMissing: param i` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected ActionController::ParameterMissing with "param is missing or the value is empty: contact phone number", got #<ActionController::ParameterMissing: ` | 8 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected Discourse::Utils::CommandError with message matching /output exceeded 1024 bytes/, got #<Discourse::Utils::CommandError:"/home/user/.local/share/m` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected Errno::EACCES but nothing was raised` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected 'nil.present?' to be truthy, got false` | 12 | chatwoot-prs, chatwoot-shimmed, discourse-prs, discourse-shimmed | known:noise-chatwoot-both-trees, known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected the response to have a success status code (2xx) but it was 422` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected the response to have a success status code (2xx) but it was 500` | 34 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected the response to have status code :ok (200) but it was :internal_server_error (500)` | 4 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected the response to have status code :unprocessable_entity (422) but it was :internal_server_error (500)` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: "/tmp/X"` | 4 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected: "FFFFFF"` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected: "invite_team"` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: "paulene@ortiz.test"` | 1 | chatwoot-prs | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: "twyla@cassin.example"` | 1 | chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: "updated-again@example.com"` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<Encoding:UTF-8> ""` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: 1` | 2 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected: 2` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: < nil` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: true` | 6 | discourse-prs, discourse-shimmed | known:noise-discourse-env |
| `RSpec::Expectations::ExpectationNotMetError: expected: {"min_version" => {"android" => nil, "ios" => nil}}` | 2 | chatwoot-prs, chatwoot-shimmed | known:noise-chatwoot-both-trees |
