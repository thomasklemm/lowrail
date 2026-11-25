# Rails readiness: cf0325a832a1594f01d866da1e4ad23d962d886b against 1afb398af94c3f76567d427a279637dbfaac8b3f

Base `1afb398af9` (8.1.4.1), candidate `cf0325a832` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-25T14:44:10Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| kaminari | `v1.3.2` (`adb89b8f26`) | 555 / 0F, 555 / 0F | 555 / 0F, 555 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| devise | `05811fb8366edd08874111d0f6fb44543e1c91ef` (`05811fb836`) | 878 / 0F, 878 / 0F | 878 / 0F, 878 / 0F | – | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.2, marcel: 1.1.0 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| rspec-rails | `5072befe5d1b01348a14fa02b6e5a8448874fb53` (`5072befe5d`) | 993 / 51F, 993 / 51F | 993 / 42F, 993 / 42F | 42 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| pundit | `ea9e31a2d7993f038ee52b94ccc9c7411637ba89` (`ea9e31a2d7`) | 184 / 0F, 184 / 0F | 184 / 0F, 184 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| cancancan-sqlite (bumps: ostruct >= 0; shims: 1) | `4362b39b04e6840c8edbd2cb4de16b2d77b19c3c` (`4362b39b04`) | 712 / 0F, 712 / 0F | 712 / 0F, 712 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| cancancan-postgres (bumps: ostruct >= 0; shims: 1) | `4362b39b04e6840c8edbd2cb4de16b2d77b19c3c` (`4362b39b04`) | 712 / 0F, 712 / 0F | 712 / 0F, 712 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| friendly_id-sqlite | `4699c9791db955dfa9929af0f38a4059af550026` (`4699c9791d`) | 530 / 0F, 530 / 0F | 530 / 0F, 530 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| friendly_id-postgresql | `4699c9791db955dfa9929af0f38a4059af550026` (`4699c9791d`) | 530 / 0F, 530 / 0F | 530 / 0F, 530 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| view_component (shims: 1) | `b1fd129eaeedf4a33986c4ed342f041c2d4a5b0a` (`b1fd129eae`) | 892 / 0F, 892 / 0F | did not load, did not load | 1 suite-did-not-load | marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| simple_form | `18f38aad0bdeca2ba1815043b94d96fdbbe6a325` (`18f38aad0b`) | 806 / 3F, 806 / 3F | 806 / 3F, 806 / 3F | 3 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| ransack-sqlite (shims: 1) | `fbc3baf164da2a80435d5678a77924c66472f694` (`fbc3baf164`) | 1145 / 22F, 1145 / 15F | 1145 / 24F, 1145 / 17F | 2 confirmed, 33 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ransack-postgresql (shims: 1) | `fbc3baf164da2a80435d5678a77924c66472f694` (`fbc3baf164`) | 1146 / 23F, 1146 / 15F | 1146 / 24F, 1146 / 16F | 1 confirmed, 34 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| administrate (bumps: appraisal false, awesome_print false; shims: 1) | `6cb9cbbbc8032b5802ade02169881e61caf08193` (`6cb9cbbbc8`) | 642 / 142F, 642 / 142F | did not load, did not load | 1 suite-did-not-load | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.2, marcel: 1.0.4 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| jbuilder | `f141f5ede81bf534d62c6ba228975d5ccb90b63d` (`f141f5ede8`) | 138 / 0F, 138 / 0F | 138 / 0F, 138 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| good_job | `e15ee79627` (`e15ee79627`) | 1265 / 2F, 1265 / 2F | 1265 / 2F, 1265 / 2F | 2 base-failing | marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| solid_queue-sqlite (shims: 1) | `b9c646a848` (`b9c646a848`) | 402 / 0F, 402 / 0F | 402 / 0F, 402 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| solid_queue-postgres (shims: 1) | `b9c646a848` (`b9c646a848`) | 402 / 0F, 402 / 0F | 402 / 0F, 402 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| sidekiq-rails | `75982898ff` (`75982898ff`) | 177 / 0F, 177 / 0F | 177 / 0F, 177 / 0F | – | marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| paper_trail-sqlite (shims: 1) | `86ce1b8307` (`86ce1b8307`) | 444 / 0F, 444 / 0F | 444 / 0F, 444 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| paper_trail-postgres (shims: 1) | `86ce1b8307` (`86ce1b8307`) | 510 / 0F, 510 / 0F | 510 / 0F, 510 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| active_model_serializers | `6934c8bd31` (`6934c8bd31`) | 576 / 0F, 576 / 0F | 0 / 0F, 0 / 0F | 1 test-count-mismatch | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| pagy | `b48c906e31847cc2564b1e8da2995e2b1b8e3e9a` (`b48c906e31`) | 1205 / 0F, 1205 / 0F | 1205 / 0F, 1205 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| turbo-rails | `37530c08780fa6f6dbb56a633de4b81169bdd174` (`37530c0878`) | 247 / 0F, 247 / 0F | 247 / 0F, 247 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| importmap-rails | `f255e55482d9173d8f64db3bfa4317b64445eeb4` (`f255e55482`) | 104 / 0F, 104 / 0F | 104 / 0F, 104 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| propshaft | `e7530a0490c8e1cd4e15dfa9a98717167fa6dccf` (`e7530a0490`) | 170 / 0F, 170 / 0F | 170 / 0F, 170 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| responders | `eb9b9baac1f8e2d44265e20120bdec45c0890a28` (`eb9b9baac1`) | 116 / 0F, 116 / 0F | 116 / 0F, 116 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| rails-controller-testing | `c203673f8011a7cdc2a8edf995ae6b3eec3417ca` (`c203673f80`) | 46 / 4F, 46 / 4F | 46 / 37F, 46 / 37F | 33 confirmed, 2 signature-changed, 2 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| draper | `7fc015f80ccb1f0aa7b8ffaa7a50db76d0cc946c` (`7fc015f80c`) | 425 / 2F, 425 / 2F | 322 / 1F, 322 / 1F | 1 confirmed, 1 test-count-mismatch | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts-as-taggable-on | `719734149d4f4295f497dc9a02884b08051325a3` (`719734149d`) | 312 / 3F, 312 / 0F | 312 / 3F, 312 / 0F | 3 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_list-sqlite | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_list-postgresql | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_list-mysql | `v1.2.6` (`4b527e673f`) | 231 / 0F, 231 / 0F | 231 / 0F, 231 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-sqlite3 (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 0F, 133 / 0F | 133 / 31F, 133 / 31F | 31 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-pg (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 0F, 133 / 0F | 133 / 32F, 133 / 32F | 32 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-mysql2 (shims: 1) | `v5.1.0` (`c03bc1a9b0`) | 133 / 0F, 133 / 0F | 133 / 31F, 133 / 31F | 31 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| closure_tree | `v9.8.0` (`ca04a8a703`) | 369 / 0F, 369 / 0F | 369 / 0F, 369 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| counter_culture-sqlite3 (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| counter_culture-postgresql (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| counter_culture-mysql2 (shims: 2) | `v3.14.0` (`d4417ef01b`) | 219 / 0F, 219 / 1F | 219 / 0F, 219 / 1F | 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| paranoia (shims: 2) | `a950fe4981` (`a950fe4981`) | 101 / 0F, 101 / 0F | 101 / 0F, 101 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| acts_as_tenant (bumps: appraisal false) | `v2.2.2` (`659804fee7`) | 186 / 0F, 186 / 0F | 186 / 0F, 186 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-sqlite3 (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 263 / 0F, 263 / 0F | 263 / 0F, 263 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-postgresql (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 376 / 0F, 376 / 0F | 376 / 0F, 376 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-mysql2 (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 318 / 0F, 318 / 0F | 318 / 0F, 318 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-import-trilogy (bumps: ostruct >= 0) | `v3.0.1` (`ed0cdadf80`) | 318 / 0F, 318 / 0F | 318 / 0F, 318 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| pg_search (shims: 1) | `v2.4.0` (`e767fe3276`) | 278 / 0F, 278 / 0F | 278 / 0F, 278 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| scenic | `v1.9.0` (`bef5f4959b`) | 114 / 2F, 114 / 2F | 114 / 21F, 114 / 21F | 19 confirmed, 2 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| strong_migrations-postgresql | `v2.8.0` (`a0d89633e2`) | 233 / 1F, 233 / 1F | 233 / 3F, 233 / 3F | 2 confirmed, 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| strong_migrations-mysql2 | `v2.8.0` (`a0d89633e2`) | 233 / 1F, 233 / 1F | 233 / 11F, 233 / 11F | 9 confirmed, 2 order-dependent, 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| strong_migrations-trilogy | `v2.8.0` (`a0d89633e2`) | 233 / 1F, 233 / 1F | 233 / 11F, 233 / 11F | 9 confirmed, 2 order-dependent, 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| groupdate | `v6.8.0` (`6255e75000`) | 1252 / 0F, 1252 / 0F | 1252 / 0F, 1252 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-sqlite3 | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-postgresql | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-mysql2 | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| delayed_job_active_record-trilogy | `v4.1.11` (`e5b4fbf8c6`) | 103 / 0F, 103 / 0F | 103 / 0F, 103 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| audited (shims: 1) | `v5.8.0` (`f935285c27`) | 221 / 1F, 221 / 1F | 221 / 1F, 221 / 1F | 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mobility-sqlite3 (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 748 / 1F, 748 / 1F | 748 / 91F, 748 / 91F | 90 confirmed, 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mobility-postgres (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 1277 / 2F, 1277 / 2F | 1277 / 190F, 1277 / 190F | 188 confirmed, 2 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| mobility-mysql (bumps: ostruct >= 0) | `v1.3.2` (`a776667737`) | 748 / 1F, 748 / 1F | 748 / 91F, 748 / 91F | 90 confirmed, 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| store_model | `v4.6.2` (`8ecbaa229e`) | 549 / 0F, 549 / 0F | 549 / 11F, 549 / 11F | 11 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| store_model-test-env | `v4.6.1` (`8ed9813cf9`) | 504 / 0F, 504 / 0F | 504 / 11F, 504 / 11F | 11 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| money-rails | `v3.0.0` (`f5e2af7298`) | 268 / 1F, 268 / 0F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| will_paginate-sqlite3 (shims: 1) | `v4.0.1` (`50017c3eb0`) | 144 / 0F, 144 / 0F | 144 / 2F, 144 / 2F | 2 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| will_paginate-postgres (shims: 1) | `v4.0.1` (`50017c3eb0`) | 144 / 0F, 144 / 0F | 144 / 2F, 144 / 3F | 2 confirmed, 1 flaky-candidate | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| will_paginate-mysql (shims: 1) | `v4.0.1` (`50017c3eb0`) | 144 / 0F, 144 / 0F | 144 / 2F, 144 / 3F | 2 confirmed, 1 flaky-candidate | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| bullet | `8.3.1` (`c4786510ab`) | 286 / 0F, 286 / 0F | 286 / 0F, 286 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| carrierwave | `v3.1.4` (`453c665ef1`) | 1788 / 1F, 1788 / 1F | 1788 / 1F, 1788 / 1F | 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| carrierwave-cucumber | `v3.1.4` (`453c665ef1`) | 42 / 0F, 42 / 0F | 42 / 0F, 42 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| shrine | `v3.10.2` (`fa2e4c28c7`) | 1537 / 0F, 1537 / 0F | 1537 / 2F, 1537 / 2F | 2 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0 |
| lograge | `v0.15.1` (`106e8333d6`) | 134 / 3F, 134 / 32F | 134 / 7F, 134 / 34F | 2 confirmed, 2 signature-changed, 30 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| factory_bot_rails (bumps: aruba < 3; shims: 1) | `v6.5.1` (`dfdef4c70a`) | 12 / 0F, 12 / 0F | 12 / 0F, 12 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| factory_bot_rails-minitest (bumps: aruba < 3; shims: 1) | `v6.5.1` (`dfdef4c70a`) | 2 / 0F, 2 / 0F | 2 / 0F, 2 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| factory_bot_rails-cucumber (bumps: aruba < 3; shims: 1) | `v6.5.1` (`dfdef4c70a`) | 26 / 0F, 26 / 0F | 26 / 0F, 26 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| shoulda-matchers-sqlite3 (bumps: appraisal false, bundler >= 2.0; shims: 2) | `v8.0.1` (`cf3b3685f2`) | 3097 / 0F, 3097 / 0F | 3097 / 2F, 3097 / 2F | 2 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| shoulda-matchers-postgresql (bumps: appraisal false, bundler >= 2.0; shims: 2) | `v8.0.1` (`cf3b3685f2`) | 3159 / 0F, 3159 / 0F | 3159 / 2F, 3159 / 2F | 2 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| shoulda-matchers-acceptance (bumps: appraisal false, bundler >= 2.0; shims: 2) | `v8.0.1` (`cf3b3685f2`) | 10 / 0F, 10 / 0F | 10 / 1F, 10 / 1F | 1 confirmed | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| solid_cache (bumps: appraisal false, minitest-mock >= 0; shims: 1) | `v1.0.10` (`004e1011d4`) | 3096 / 0F, 3096 / 0F | 3096 / 3F, 3096 / 3F | 3 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| solid_cable (shims: 1) | `v4.1.0` (`1e4217e51d`) | 39 / 0F, 39 / 0F | 39 / 0F, 39 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| attr_json (bumps: rspec-rails https://github.com/rspec/rspec-rails 570b2b0a79) | `v2.6.0` (`bec4645742`) | 281 / 8F, 281 / 8F | 281 / 8F, 281 / 8F | 2 signature-changed, 6 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| globalize-sqlite3 (shims: 1) | `v7.1.3` (`38e5fe5aeb`) | 304 / 0F, 304 / 0F | 304 / 0F, 304 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| globalize-postgresql (shims: 1) | `v7.1.3` (`38e5fe5aeb`) | 305 / 0F, 305 / 0F | 305 / 0F, 305 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| enumerize-sqlite3 (shims: 1) | `v3.0.0` (`8688372f15`) | 274 / 0F, 274 / 0F | 274 / 0F, 274 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| enumerize-postgresql (shims: 1) | `v3.0.0` (`8688372f15`) | 274 / 0F, 274 / 0F | 274 / 0F, 274 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| typedstore (shims: 1) | `v1.6.0` (`2f3fb98e65`) | 581 / 4F, 581 / 4F | 581 / 454F, 581 / 454F | 450 confirmed, 4 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| typedstore-main (shims: 1) | `263050a196` (`263050a196`) | 581 / 0F, 581 / 0F | 581 / 0F, 581 / 2F | 2 order-dependent | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ar_lazy_preload | `v2.1.3` (`678e82ae52`) | 134 / 0F, 134 / 0F | 134 / 0F, 134 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| active_record_query_trace | `v1.9` (`5c67364604`) | 75 / 8F, 75 / 8F | did not load, did not load | 1 suite-did-not-load | globalid: 1.3.0 -> 1.4.0, herb: - -> 0.11.2, marcel: 1.1.0 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| annotaterb | `v4.26.0` (`4c95876ecb`) | 900 / 0F, 900 / 0F | 900 / 0F, 900 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| ancestry-pr770 (shims: 1) | `68789a1903` (`68789a1903`) | 259 / 0F, 259 / 0F | 259 / 7F, 259 / 7F | 7 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| discard | `v2.0.0` (`cdeb3d40d8`) | 92 / 0F, 92 / 0F | 92 / 0F, 92 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| activerecord-session_store | `v2.3.0` (`74011f1318`) | 62 / 0F, 62 / 0F | 62 / 0F, 62 / 0F | – | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| attr_encrypted (shims: 1) | `v4.2.0` (`c2aa160c23`) | 151 / 1F, 151 / 1F | 151 / 1F, 151 / 1F | 1 base-failing | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| active_record_doctor-postgresql | `v2.1.0` (`62882337c8`) | 261 / 0F, 261 / 0F | 261 / 12F, 261 / 12F | 12 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| active_record_doctor-sqlite3 | `v2.1.0` (`62882337c8`) | 261 / 0F, 261 / 0F | 261 / 5F, 261 / 5F | 5 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| online_migrations (shims: 1) | `v0.37.0` (`82e264fd46`) | 545 / 0F, 545 / 0F | 545 / 17F, 545 / 17F | 17 confirmed | herb: - -> 0.11.2, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 3 times per tree), `one-seed` too but past the suite's cap on alone reruns; `base-failing` fails on base too; `signature-changed` fails on both with different errors. Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.

## New (0)

None: every candidate flag matches a known finding.

## Known (1089)

| Finding | Status | Classes | Count | Suites | Record |
| --- | --- | --- | --- | --- | --- |
| E2 | prepared | 1 confirmed | 1 | ransack-sqlite | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| R2-7 | gem-side | 19 confirmed, 4 order-dependent | 23 | strong_migrations-mysql2, strong_migrations-trilogy, strong_migrations-postgresql | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| SP3 | gem-side | 368 confirmed | 368 | mobility-mysql, mobility-postgres, mobility-sqlite3 | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| eco1-draper | record-only | 1 confirmed, 1 test-count-mismatch | 2 | draper | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| A59-1 | gem-side | 450 confirmed | 450 | typedstore | [ar-gems-after-59141.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-gems-after-59141.md) |
| eco1-dynamic-controller-routes | record-only | 33 confirmed, 2 signature-changed, 1 test-count-mismatch | 36 | rails-controller-testing, active_model_serializers | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| PR59574 | open-pr | 7 confirmed | 7 | ancestry-pr770 | [rails-main-census-11.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-main-census-11.md) |
| R2-2 | gem-side | 19 confirmed | 19 | scenic | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-15 | record-only | 4 confirmed | 4 | shoulda-matchers-postgresql, shoulda-matchers-sqlite3 | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-13 | record-only | 6 confirmed | 6 | will_paginate-mysql, will_paginate-postgres, will_paginate-sqlite3 | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-17 | gem-side | 1 confirmed | 1 | solid_cache | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| IX1 | open-pr | 34 confirmed | 34 | online_migrations, active_record_doctor-sqlite3, active_record_doctor-postgresql | [rails-main-census-11.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-main-census-11.md) |
| R2-14 | record-only | 2 confirmed | 2 | shrine | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-5 | gem-side | 94 confirmed | 94 | ancestry-mysql2, ancestry-pg, ancestry-sqlite3 | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-3 | gem-side | 2 confirmed | 2 | lograge | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-16 | gem-side | 2 confirmed | 2 | solid_cache | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| eco1-ransack-select-manager | gem-side | 2 confirmed | 2 | ransack-postgresql, ransack-sqlite | [ecosystem-tests.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md) |
| R2-10 | record-only | 10 confirmed | 10 | store_model, store_model-test-env | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-1 | record-only | 1 confirmed | 1 | shoulda-matchers-acceptance | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-11 | record-only | 12 confirmed | 12 | store_model, store_model-test-env | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-8 | gem-side | 1 confirmed | 1 | strong_migrations-postgresql | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| L1 | gem-side | 1 suite-did-not-load | 1 | administrate | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| AM2 | prepared | 2 suite-did-not-load | 2 | money-rails, view_component | [rails-main-census-11.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-main-census-11.md) |
| A59-qt | gem-side | 1 suite-did-not-load | 1 | active_record_query_trace | [ar-gems-after-59141.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-gems-after-59141.md) |
| R2-4 | record-only | 2 signature-changed | 2 | lograge | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| noise-c11-attr_json-browser | noise | 2 signature-changed | 2 | attr_json | [rails-main-census-11.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-main-census-11.md) |
| R2-18 | gem-side | 2 flaky-candidate | 2 | will_paginate-mysql, will_paginate-postgres | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| noise-c11-typedstore-order | noise | 2 order-dependent | 2 | typedstore-main | [rails-main-census-11.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-main-census-11.md) |

## Fails on base too (174)

| Signature | Count | Suites | Match |
| --- | --- | --- | --- |
| `ArgumentError: Invalid Timezone: US/Pacific` | 6 | attr_json | new |
| `NoMethodError: undefined method 'stub' for an instance of User` | 1 | attr_encrypted | new |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ActiveRecord::ActiveRecordError: cannot update a new record> with backtrace:` | 1 | typedstore | new |
| `ActiveRecord::StatementInvalid: PG::DuplicateTable: ERROR: relation "search in a haystack" already exists` | 1 | scenic | known:noise-scenic-schema-dumper |
| `Minitest::Assertion: Expected /\ \ \ \ t\.string\ "name"\n\ \ \ \ t\.bigint\ "order_id"\n/ to match "# This file is auto-generated from the current state of the database. Instead\n# of editing this fi` | 3 | strong_migrations-mysql2, strong_migrations-postgresql, strong_migrations-trilogy | known:noise-r2-both-trees |
| `Minitest::Assertion: Expected [] to include "README.rdoc".` | 2 | rails-controller-testing | known:noise-eco1-both-trees |
| `Minitest::Assertion: Expected at least 1 element matching "input:match('pattern', /\\\\d+/)", found 0.` | 2 | simple_form | known:noise-eco1-both-trees |
| `NoMethodError: undefined method '[]' for nil` | 1 | carrierwave | known:noise-r2-both-trees |
| `Nokogiri::XML::XPath::SyntaxError: ERROR: Char out of XML range: .//*[nokogiri:match(.,'class','(?-mix:^(?!.*¼hosen .*¼hosen ).*¼hosen .*$)')] \| self::*[nokogiri:match(.,'class','(?-mix:^(?!.*¼hosen .` | 1 | simple_form | known:noise-eco1-both-trees |
| `RSpec::Core::MultipleExceptionError: expected 'Lograge.notification_listeners_for('process_action.action_controller')' to have changed to [], but did not change` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Core::MultipleExceptionError: expected collection contained: [#<ActiveSupport::Notifications::Fanout::Subscribers::Timed:0xX @pattern="process_acti...>:0xX @events=[]>, @silenceable=false, @can` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "action=pong"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "controller=ActionCableChannel action=pong"` | 5 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /duration=[.0-9]{2,4}/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /status=200 /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "<a controller=\"people\" class=\"sort_link \" href=\"/people?q%5Bs%5D=id+asc\">id&nbsp;defaultarrow</a>" to match /id<\/a>/` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "<a controller=\"people\" class=\"sort_link \" href=\"/people?q%5Bs%5D=name+asc\">Full Name&nbsp;defaultarrow</a>" to match /Full Name<\/a>/` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "My test: {\"method\":\"GET\",\"status\":200}" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "SELECT \"issue_343_people\".* FROM \"issue_343_people\" ORDER BY \"issue_343_people\".\"id\" DESC" to include "\"issue_343_people\".\"name\" = "` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected "bundler: failed to load command: tmp/fail_sanity_check (tmpRUBYLIB/bundler/source/git/git_proxy.rb:461:in 'Bundler::Source::Git::GitProxy#allowed` | 1 | rspec-rails | known:noise-eco1-both-trees |
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
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ArgumentError: JsonTypedStoreModel has no attribute 'no_default' to define a reader for> with backtrace:` | 1 | typedstore | known:A59-1 |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ArgumentError: MarshalTypedStoreModel has no attribute 'no_default' to define a reader for> with backtra` | 1 | typedstore | known:A59-1 |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveModel::MissingAttributeError, got #<ArgumentError: YamlTypedStoreModel has no attribute 'no_default' to define a reader for> with backtrace:` | 1 | typedstore | known:A59-1 |
| `RSpec::Expectations::ExpectationNotMetError: expected RuntimeError with message matching /Ransack needs Article associations explicitly allowlisted/ but nothing was raised` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected RuntimeError with message matching /Ransack needs Article attributes explicitly allowlisted/ but nothing was raised` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected ["=> Booting Puma\n", "=> Rails RAILS_VERSION application starting in development \n", "=> Run 'bin/rails server --help' for more startup options\` | 1 | good_job | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected ["=> Booting Puma\n", "=> Rails RAILS_VERSION application starting in production \n", "=> Run 'bin/rails server --help' for more startup options\n` | 1 | good_job | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected '"".present?' to be truthy, got false` | 3 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected '"bundler: failed to load command: tmp/pass_sanity_check (tmpRUBYLIB/bundler/source/git/git_proxy.rb:461:in 'Bundler::Source::Git::GitProxy#allowe` | 1 | rspec-rails | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected no Exception, got #<Ransack::InvalidSearchError: Invalid combinator unknown> with backtrace:` | 4 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected no Exception, got #<Ransack::InvalidSearchError: Invalid search term unknown_attr_eq> with backtrace:` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected {"en" => "{foo: :bar}"} to match hash {en: "{:foo=>:bar}"}` | 1 | mobility-postgres | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected {en: "{foo: :bar}"} to match hash {en: "{:foo=>:bar}"}` | 3 | mobility-mysql, mobility-postgres, mobility-sqlite3 | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected: "no implicit conversion of Hash into String"` | 1 | rspec-rails | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<ActsAsTaggableOn::Tag id: 1, name: "awesome", taggings_count: 0, type: nil>` | 1 | acts-as-taggable-on | known:noise-eco1-taggable-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: #<Encoding:UTF-8> "{:foo=>\"bar\"}"` | 1 | audited | known:noise-r2-ruby34-inspect |
| `RSpec::Expectations::ExpectationNotMetError: expected: 1` | 5 | counter_culture-mysql2, counter_culture-postgresql, counter_culture-sqlite3, ransack-postgresql, ransack-sqlite | known:noise-r2-counter_culture-order, known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["c", "b", "a"]` | 1 | acts-as-taggable-on | known:noise-eco1-taggable-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["call-50%off"]` | 2 | ransack-postgresql, ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["scenic.bananas", "scenic.apples"]` | 1 | scenic | known:noise-scenic-schema-dumper |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["tag2", "tag1"]` | 1 | acts-as-taggable-on | known:noise-eco1-taggable-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: [#<Person id: 30, parent_id: nil, name: "a_c", email: nil, only_search: nil, only_sort: nil, only_adm...eated_at: "2026-11-25 12:32:04.414269000 ` | 1 | ransack-sqlite | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: [#<Person id: 30, parent_id: nil, name: "a_c", email: nil, only_search: nil, only_sort: nil, only_adm...eated_at: "2026-11-25 12:38:36.951518000 ` | 1 | ransack-postgresql | known:noise-eco1-both-trees |
| `RSpec::Expectations::ExpectationNotMetError: expected: [#<Person id: 56, parent_id: nil, name: "name_with_underscore", email: nil, only_search: nil, only_so...eated_at: "2026-11-25 12:38:37.192255000 ` | 1 | ransack-postgresql | known:noise-eco1-both-trees |
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
