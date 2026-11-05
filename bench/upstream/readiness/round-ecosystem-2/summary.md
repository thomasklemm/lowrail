# Rails readiness: 7a78da5a5576d7ab7549b10fb13156788478ba35 against 6e09124217

Base `6e09124217` (8.1.4.1), candidate `7a78da5a55` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-05T00:10:50Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| acts_as_list-sqlite | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_list-postgresql | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_list-mysql | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-sqlite3 (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 0F, 133 / 0F | 133 / 31F, 133 / 31F | 31 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-pg (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 0F, 133 / 0F | 133 / 32F, 133 / 32F | 32 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-mysql2 (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 0F, 133 / 0F | 133 / 31F, 133 / 31F | 31 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| closure_tree | `v9.8.0` (`ca04a8a703`) | 369 / 0F, 369 / 0F | 369 / 0F, 369 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| counter_culture-sqlite3 (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| counter_culture-postgresql (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| counter_culture-mysql2 (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| paranoia (shims: 1) | `a950fe4981` (`a950fe4981`) | 101 / 0F, 101 / 0F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_tenant (bumps: appraisal false) | `v2.2.2` (`659804fee7`) | 186 / 0F, 186 / 0F | 186 / 0F, 186 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-sqlite3 (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 263 / 0F, 263 / 0F | 263 / 0F, 263 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-postgresql (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 376 / 0F, 376 / 0F | 376 / 0F, 376 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-mysql2 (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 318 / 0F, 318 / 0F | 318 / 0F, 318 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-trilogy (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 318 / 0F, 318 / 0F | 318 / 0F, 318 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| pg_search (shims: 1) | `v2.4.0` (`e767fe3276`) | 278 / 0F, 278 / 0F | 278 / 0F, 278 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| scenic | `v1.9.0` (`bef5f4959b`) | 114 / 2F, 114 / 2F | 114 / 21F, 114 / 21F | 19 confirmed, 2 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| strong_migrations-postgresql | `v2.8.0` (`a0d89633e2`) | 233 / 1F, 233 / 1F | 233 / 3F, 233 / 3F | 2 confirmed, 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| strong_migrations-mysql2 | `v2.8.0` (`a0d89633e2`) | 233 / 3F, 233 / 3F | 233 / 13F, 233 / 13F | 9 confirmed, 2 order-dependent, 3 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| strong_migrations-trilogy | `v2.8.0` (`a0d89633e2`) | 233 / 3F, 233 / 3F | 233 / 13F, 233 / 13F | 9 confirmed, 2 order-dependent, 3 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| groupdate | `v6.8.0` (`6255e75000`) | 1252 / 0F, 1252 / 0F | 1252 / 0F, 1252 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-sqlite3 | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-postgresql | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-mysql2 | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-trilogy | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| audited (shims: 1) | `v5.8.0` (`f935285c27`) | 221 / 1F, 221 / 1F | 221 / 1F, 221 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mobility-sqlite3 (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 748 / 1F, 748 / 1F | 748 / 1F, 748 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mobility-postgres (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 1277 / 2F, 1277 / 2F | 1277 / 2F, 1277 / 2F | 2 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mobility-mysql (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 748 / 1F, 748 / 1F | 748 / 1F, 748 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| store_model | `v4.6.1` (`8ed9813cf9`) | 504 / 0F, 504 / 0F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| store_model-test-env | `v4.6.1` (`8ed9813cf9`) | 504 / 0F, 504 / 0F | 504 / 11F, 504 / 11F | 11 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| money-rails | `v3.0.0` (`f5e2af7298`) | 268 / 1F, 268 / 0F | 268 / 1F, 268 / 0F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| will_paginate-sqlite3 (shims: 1) | `v4.0.1` (`50017c3eb0`) | 144 / 0F, 144 / 0F | 144 / 2F, 144 / 2F | 2 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| will_paginate-postgres (shims: 1) | `v4.0.1` (`50017c3eb0`) | 144 / 0F, 144 / 0F | 144 / 2F, 144 / 3F | 2 confirmed, 1 flaky-candidate | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| will_paginate-mysql (shims: 1) | `v4.0.1` (`50017c3eb0`) | 144 / 0F, 144 / 0F | 144 / 2F, 144 / 3F | 2 confirmed, 1 flaky-candidate | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| bullet | `8.3.1` (`c4786510ab`) | 286 / 0F, 286 / 0F | 286 / 0F, 286 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| carrierwave | `v3.1.4` (`453c665ef1`) | 1788 / 1F, 1788 / 1F | 1788 / 1F, 1788 / 1F | 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| carrierwave-cucumber | `v3.1.4` (`453c665ef1`) | 42 / 0F, 42 / 0F | 42 / 0F, 42 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| shrine | `v3.10.2` (`fa2e4c28c7`) | 1537 / 0F, 1537 / 0F | 1537 / 2F, 1537 / 2F | 2 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0 |
| lograge | `v0.15.1` (`106e8333d6`) | 134 / 3F, 134 / 32F | 134 / 7F, 134 / 34F | 2 confirmed, 2 signature-changed, 30 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| factory_bot_rails (bumps: aruba < 3; shims: 1) | `v6.5.1` (`dfdef4c70a`) | 12 / 0F, 12 / 0F | 12 / 0F, 12 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| factory_bot_rails-minitest (bumps: aruba < 3; shims: 1) | `v6.5.1` (`dfdef4c70a`) | 2 / 0F, 2 / 0F | 2 / 0F, 2 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| factory_bot_rails-cucumber (bumps: aruba < 3; shims: 1) | `v6.5.1` (`dfdef4c70a`) | 26 / 0F, 26 / 0F | 26 / 0F, 26 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| shoulda-matchers-sqlite3 (bumps: appraisal false, bundler >= 2.0; shims: 2) | `v8.0.1` (`cf3b3685f2`) | 3097 / 0F, 3097 / 0F | 3097 / 2F, 3097 / 2F | 2 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| shoulda-matchers-postgresql (bumps: appraisal false, bundler >= 2.0; shims: 2) | `v8.0.1` (`cf3b3685f2`) | 3159 / 0F, 3159 / 0F | 3159 / 2F, 3159 / 2F | 2 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| shoulda-matchers-acceptance (bumps: appraisal false, bundler >= 2.0; shims: 2) | `v8.0.1` (`cf3b3685f2`) | 10 / 0F, 10 / 0F | 10 / 1F, 10 / 1F | 1 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| solid_cache (bumps: appraisal false, minitest-mock >= 0; shims: 1) | `v1.0.10` (`004e1011d4`) | 3096 / 0F, 3096 / 0F | 3096 / 3F, 3096 / 3F | 3 confirmed | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| solid_cable (shims: 1) | `v4.1.0` (`1e4217e51d`) | 39 / 0F, 39 / 0F | 39 / 0F, 39 / 0F | – | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 5 times per tree); `base-failing` fails on base too; `signature-changed` fails on both with different errors. Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.

## New (0)

None: every candidate flag matches a known finding.

## Known (172)

| Finding | Status | Classes | Count | Suites | Record |
| --- | --- | --- | --- | --- | --- |
| R2-7 | gem-side | 19 confirmed, 4 order-dependent | 23 | strong_migrations-mysql2, strong_migrations-trilogy, strong_migrations-postgresql | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-2 | gem-side | 19 confirmed | 19 | scenic | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-15 | record-only | 4 confirmed | 4 | shoulda-matchers-postgresql, shoulda-matchers-sqlite3 | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-13 | record-only | 6 confirmed | 6 | will_paginate-mysql, will_paginate-postgres, will_paginate-sqlite3 | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-17 | gem-side | 1 confirmed | 1 | solid_cache | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-14 | record-only | 2 confirmed | 2 | shrine | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-5 | gem-side | 94 confirmed | 94 | ancestry-mysql2, ancestry-pg, ancestry-sqlite3 | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-3 | gem-side | 2 confirmed | 2 | lograge | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-16 | gem-side | 2 confirmed | 2 | solid_cache | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-10 | record-only | 5 confirmed | 5 | store_model-test-env | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-1 | record-only | 1 confirmed | 1 | shoulda-matchers-acceptance | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-11 | record-only | 6 confirmed | 6 | store_model-test-env | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-8 | gem-side | 1 confirmed | 1 | strong_migrations-postgresql | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-6 | gem-side | 1 suite-did-not-load | 1 | paranoia | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-9 | record-only | 1 suite-did-not-load | 1 | store_model | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-4 | record-only | 2 signature-changed | 2 | lograge | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-18 | gem-side | 2 flaky-candidate | 2 | will_paginate-mysql, will_paginate-postgres | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |

## Fails on base too (49)

| Signature | Count | Suites | Match |
| --- | --- | --- | --- |
| `ActiveRecord::StatementInvalid: PG::DuplicateTable: ERROR: relation "search in a haystack" already exists` | 1 | scenic | known:noise-scenic-schema-dumper |
| `Minitest::Assertion: Expected /\ \ \ \ t\.string\ "name"\n\ \ \ \ t\.bigint\ "order_id"\n/ to match "# This file is auto-generated from the current state of the database. Instead\n# of editing this fi` | 3 | strong_migrations-mysql2, strong_migrations-postgresql, strong_migrations-trilogy | known:noise-r2-both-trees |
| `Minitest::Assertion: StrongMigrations::UnsafeMigration expected but nothing was raised.` | 2 | strong_migrations-mysql2, strong_migrations-trilogy | known:noise-r2-both-trees |
| `NoMethodError: undefined method '[]' for nil` | 1 | carrierwave | known:noise-r2-both-trees |
| `RSpec::Core::MultipleExceptionError: expected 'Lograge.notification_listeners_for('process_action.action_controller')' to have changed to [], but did not change` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Core::MultipleExceptionError: expected collection contained: [#<ActiveSupport::Notifications::Fanout::Subscribers::Timed:0xX @pattern="process_acti...>:0xX @events=[]>, @silenceable=false, @can` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "action=pong"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "controller=ActionCableChannel action=pong"` | 5 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /duration=[.0-9]{2,4}/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /status=200 /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "My test: {\"method\":\"GET\",\"status\":200}" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "method=GET status=200" to match / data=value/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "/home"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "controller=HomeController action=index"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "unpermitted_params=[\"florb\", \"blarf\"]"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match / data=value/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /^method=GET /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /allocations=231/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /db=0.02/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /duration=[.0-9]{4,4} /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /location=http:\/\/www.example.com/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /view=0.01 /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=pong" to match / data=value/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected '"".present?' to be truthy, got false` | 3 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected {"en" => "{foo: :bar}"} to match hash {en: "{:foo=>:bar}"}` | 1 | mobility-postgres | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected {en: "{foo: :bar}"} to match hash {en: "{:foo=>:bar}"}` | 3 | mobility-mysql, mobility-postgres, mobility-sqlite3 | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected: "money-rails/helpers/action_view_extension"` | 1 | money-rails | known:noise-r2-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<Encoding:UTF-8> "{:foo=>\"bar\"}"` | 1 | audited | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected: 1` | 3 | counter_culture-mysql2, counter_culture-postgresql, counter_culture-sqlite3 | known:noise-r2-counter_culture-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["scenic.bananas", "scenic.apples"]` | 1 | scenic | known:noise-scenic-schema-dumper |
| `StrongMigrations::UnsafeMigration:` | 2 | strong_migrations-mysql2, strong_migrations-trilogy | known:noise-r2-both-trees |
