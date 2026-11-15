Queries per request by path

| | blog | campfire | fizzy | lobsters | mastodon | blog (CE2) | fizzy (CE2) | lobsters (CE2) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| compiled | 1.0 | 5.1 | 32.5 | 16.7 | 14.6 | 1.8 | 53.3 | 9.8 |
| statement_cache | 0.8 | 1.3 | 6.8 | 3.1 | 12.4 | 0.3 | 4.7 | 1.8 |
| string | 0.0 | 0.4 | 1.2 | 1.2 | 0.1 | 0.0 | 0.0 | 0.0 |
| **total** | 1.8 | 6.9 | 40.5 | 20.9 | 27.1 | 2.2 | 58.0 | 11.5 |

Queries per request by origin (reads)

| | blog | campfire | fizzy | lobsters | mastodon | blog (CE2) | fizzy (CE2) | lobsters (CE2) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| cache store (Solid Cache) | 0.0 | 0.0 | 11.5 | 0.1 | 0.0 | 0.0 | 34.0 | 0.0 |
| preload | 0.2 | 0.0 | 5.0 | 4.1 | 6.5 | 0.7 | 6.0 | 4.5 |
| count/exists?/pluck | 0.2 | 0.6 | 5.4 | 6.4 | 1.8 | 0.3 | 7.3 | 1.5 |
| association reader, cached | 0.1 | 1.0 | 5.8 | 1.7 | 2.3 | 0.0 | 3.7 | 0.8 |
| find | 0.7 | 0.0 | 0.0 | 0.1 | 9.3 | 0.3 | 0.0 | 0.0 |
| relation load (named scope) | 0.0 | 0.4 | 1.8 | 1.1 | 0.4 | 0.0 | 3.0 | 0.8 |
| relation load | 0.2 | 0.0 | 0.0 | 1.8 | 2.4 | 0.7 | 0.0 | 2.2 |
| relation finder (scoped find/find_by/first) | 0.0 | 1.3 | 2.7 | 1.0 | 1.0 | 0.0 | 1.0 | 0.0 |
| find_by | 0.0 | 0.3 | 1.0 | 1.2 | 0.8 | 0.0 | 1.0 | 1.0 |
| association reader, skips cache | 0.0 | 1.0 | 1.4 | 0.2 | 1.7 | 0.0 | 0.0 | 0.0 |
| find_by fallback (value is a Array) | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 0.0 |
| find_by fallback (current_scope) | 0.0 | 0.0 | 0.6 | 0.0 | 0.0 | 0.0 | 1.0 | 0.0 |
| collection cache_key | 0.0 | 0.0 | 0.5 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| find_by fallback (unknown) | 0.0 | 0.0 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 0.0 |
| find_by fallback (value is nil) | 0.0 | 0.0 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 0.0 |
| find fallback (default_scope) | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 |
| find_by fallback (default_scope) | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 |
| other | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 |
| **total** | 1.4 | 4.6 | 36.7 | 18.3 | 26.5 | 2.0 | 58.0 | 10.8 |

Association readers that skip the statement cache, by reason

| | blog | campfire | fizzy | lobsters | mastodon | blog (CE2) | fizzy (CE2) | lobsters (CE2) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| reflection scope | 0.0 | 1.0 | 1.4 | 0.2 | 0.2 | 0.0 | 0.0 | 0.0 |
| owner default_scope | 0.0 | 0.0 | 0.0 | 0.0 | 1.4 | 0.0 | 0.0 | 0.0 |
| target default_scope | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| **total** | 0.0 | 1.0 | 1.4 | 0.2 | 1.7 | 0.0 | 0.0 | 0.0 |

Writes per request by path

| | blog | campfire | fizzy | lobsters | mastodon | blog (CE2) | fizzy (CE2) | lobsters (CE2) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| compiled | 0.3 | 1.9 | 2.5 | 1.4 | 0.5 | 0.2 | 0.0 | 0.8 |
| string | 0.0 | 0.4 | 1.2 | 1.2 | 0.1 | 0.0 | 0.0 | 0.0 |
| **total** | 0.3 | 2.3 | 3.7 | 2.7 | 0.6 | 0.2 | 0.0 | 0.8 |

Repetition of reads built per query (share of those queries)

| | built reads/request | shape repeats on the next request | shape repeats within the request | binds differ within the request | shape also on another page | query cache hit |
|---|---:|---:|---:|---:|---:|---:|
| blog | 0.7 | 100% | 0% | 0% | 67% | 0% |
| campfire | 3.3 | 100% | 9% | 0% | 78% | 4% |
| fizzy | 29.9 | 100% | 51% | 47% | 88% | 2% |
| lobsters | 15.2 | 100% | 35% | 28% | 86% | 9% |
| mastodon | 14.2 | 95% | 12% | 11% | 81% | 1% |
| blog (CE2) | 1.7 | 100% | 0% | 0% | 100% | 0% |
| fizzy (CE2) | 53.3 | 100% | 68% | 64% | 89% | 1% |
| lobsters (CE2) | 9.0 | 100% | 0% | 0% | 100% | 0% |

Work per request (mean over workloads)

| | relation_copy | merge | where_hash | exec_scope | build_arel | compile_arel | find_target | association_scope |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 1.1 | 0.9 | 0.4 | 0.0 | 0.7 | 1.0 | 0.1 | 0.2 |
| campfire | 13.7 | 10.9 | 10.4 | 3.1 | 3.6 | 5.1 | 2.0 | 4.3 |
| fizzy | 64.6 | 49.8 | 34.9 | 9.5 | 27.2 | 32.9 | 7.2 | 14.8 |
| lobsters | 58.3 | 14.8 | 21.3 | 6.8 | 17.8 | 17.6 | 1.9 | 4.1 |
| mastodon | 66.9 | 24.8 | 41.1 | 23.0 | 15.0 | 14.8 | 4.0 | 10.7 |
| blog (CE2) | 3.0 | 0.0 | 0.7 | 0.0 | 1.7 | 1.8 | 0.0 | 0.0 |
| fizzy (CE2) | 80.0 | 45.3 | 32.0 | 12.0 | 30.7 | 53.3 | 3.7 | 13.0 |
| lobsters (CE2) | 88.8 | 6.0 | 11.2 | 4.5 | 10.5 | 11.2 | 0.8 | 1.5 |

