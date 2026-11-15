Query building by path (percent of server time)

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| built per query | 2.85 | 8.33 | 14.98 | 15.89 | 11.30 | 10.67 |
| statement cache | 0.33 | 0.10 | 0.34 | 0.46 | 0.40 | 0.32 |
| **total** | 3.18 | 8.43 | 15.32 | 16.34 | 11.70 | 10.99 |

Query building by stage

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| relation spawn/merge | 0.97 | 1.80 | 2.87 | 5.25 | 3.26 | 2.83 |
| association scope | 0.46 | 2.62 | 5.11 | 2.64 | 3.23 | 2.81 |
| build_arel | 0.32 | 1.90 | 3.68 | 3.93 | 2.76 | 2.52 |
| visitor (Arel to SQL) | 0.58 | 0.82 | 1.82 | 2.03 | 0.96 | 1.24 |
| other (load, finders, query cache, logs) | 0.57 | 0.89 | 1.28 | 1.87 | 1.12 | 1.15 |
| binds | 0.25 | 0.30 | 0.51 | 0.29 | 0.32 | 0.34 |
| where predicates | 0.03 | 0.10 | 0.05 | 0.33 | 0.04 | 0.11 |
| **total** | 3.18 | 8.43 | 15.32 | 16.34 | 11.70 | 10.99 |

Built per query, by stage

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| relation spawn/merge | 0.95 | 1.80 | 2.87 | 5.23 | 3.25 | 2.82 |
| association scope | 0.46 | 2.62 | 5.11 | 2.64 | 3.23 | 2.81 |
| build_arel | 0.32 | 1.90 | 3.68 | 3.93 | 2.76 | 2.52 |
| visitor (Arel to SQL) | 0.58 | 0.82 | 1.81 | 2.03 | 0.96 | 1.24 |
| other (load, finders, query cache, logs) | 0.47 | 0.83 | 1.13 | 1.61 | 0.89 | 0.99 |
| (statement cache) | 0.33 | 0.10 | 0.34 | 0.46 | 0.40 | 0.32 |
| binds | 0.04 | 0.26 | 0.33 | 0.11 | 0.17 | 0.18 |
| where predicates | 0.03 | 0.10 | 0.05 | 0.33 | 0.04 | 0.11 |
| **total** | 3.18 | 8.43 | 15.32 | 16.34 | 11.70 | 10.99 |

Query building by origin

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| relation | 0.94 | 2.15 | 2.87 | 6.12 | 4.53 | 3.32 |
| association collection | 0.81 | 2.92 | 5.01 | 3.64 | 1.86 | 2.85 |
| association reader | 0.22 | 1.77 | 3.21 | 1.20 | 2.83 | 1.85 |
| preload | 0.42 | 1.02 | 1.57 | 2.29 | 1.40 | 1.34 |
| count/exists?/pluck | 0.12 | 0.51 | 1.92 | 2.23 | 0.44 | 1.04 |
| Model.find/find_by | 0.68 | 0.06 | 0.74 | 0.86 | 0.64 | 0.60 |
| **total** | 3.18 | 8.43 | 15.32 | 16.34 | 11.70 | 10.99 |

Path × origin

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| built per query · relation | 0.94 | 2.15 | 2.87 | 6.12 | 4.53 | 3.32 |
| built per query · association collection | 0.81 | 2.92 | 5.01 | 3.64 | 1.86 | 2.85 |
| built per query · association reader | 0.21 | 1.68 | 2.93 | 1.08 | 2.69 | 1.72 |
| built per query · preload | 0.42 | 1.02 | 1.57 | 2.29 | 1.40 | 1.34 |
| built per query · count/exists?/pluck | 0.12 | 0.51 | 1.92 | 2.23 | 0.44 | 1.04 |
| built per query · Model.find/find_by | 0.36 | 0.04 | 0.68 | 0.53 | 0.38 | 0.40 |
| statement cache · Model.find/find_by | 0.32 | 0.01 | 0.06 | 0.33 | 0.26 | 0.20 |
| statement cache · association reader | 0.01 | 0.09 | 0.28 | 0.12 | 0.14 | 0.13 |
| **total** | 3.18 | 8.43 | 15.32 | 16.34 | 11.70 | 10.99 |

Inclusive, every layer (percent of server time)

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| bind type casting (all layers) | 0.71 | 0.68 | 2.18 | 0.27 | 0.41 | 0.85 |
| association scope built, then statement cache (all layers) | 0.27 | 1.71 | 3.67 | 1.40 | 3.03 | 2.01 |

Query building by entry point (top), percent of server time

| | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| Delegation#each | 0.41 | 0.12 | 0.20 | 0.82 | 0.93 | 0.49 |
| QueryMethods#where | 0.00 | 0.43 | 0.25 | 0.62 | 0.88 | 0.44 |
| Relation#to_ary | 0.00 | 0.00 | 0.00 | 1.63 | 0.37 | 0.40 |
| QueryMethods#order | 0.10 | 0.30 | 0.23 | 0.92 | 0.13 | 0.34 |
| FinderMethods#find_by | 0.00 | 0.64 | 0.73 | 0.25 | 0.03 | 0.33 |
| Relation#blank? | 0.30 | 0.01 | 1.30 | 0.00 | 0.00 | 0.32 |
| Querying#where | 0.00 | 0.00 | 0.05 | 1.16 | 0.15 | 0.27 |
| Relation#preload_associations | 0.09 | 0.97 | 0.24 | 0.00 | 0.00 | 0.26 |
| Core::ClassMethods#find_by | 0.00 | 0.05 | 0.38 | 0.65 | 0.20 | 0.26 |
| Relation#any? | 0.12 | 0.00 | 0.33 | 0.17 | 0.62 | 0.25 |
| Associations::Preloader#call | 0.00 | 0.00 | 0.00 | 0.00 | 1.18 | 0.24 |
| ConnectionAdapters::QueryCache#cache_sql | 0.16 | 0.16 | 0.32 | 0.30 | 0.19 | 0.23 |
| FinderMethods#find_by! | 0.00 | 0.27 | 0.77 | 0.00 | 0.00 | 0.21 |
| Calculations#count | 0.00 | 0.00 | 0.60 | 0.42 | 0.00 | 0.20 |
| FinderMethods#exists? | 0.00 | 0.10 | 0.34 | 0.00 | 0.55 | 0.20 |
| Delegation#length | 0.00 | 0.38 | 0.43 | 0.16 | 0.00 | 0.19 |
| Calculations#sum | 0.00 | 0.00 | 0.00 | 0.90 | 0.00 | 0.18 |
| Relation#load_async | 0.00 | 0.00 | 0.00 | 0.89 | 0.00 | 0.18 |
| Associations::CollectionProxy#where | 0.00 | 0.00 | 0.61 | 0.21 | 0.06 | 0.18 |
| Calculations#pick | 0.00 | 0.00 | 0.13 | 0.73 | 0.00 | 0.17 |
| Relation#many? | 0.00 | 0.00 | 0.85 | 0.00 | 0.00 | 0.17 |
| Core::ClassMethods#find | 0.50 | 0.00 | 0.00 | 0.04 | 0.28 | 0.17 |
| Associations::CollectionProxy#include? | 0.00 | 0.00 | 0.00 | 0.82 | 0.00 | 0.16 |
| User::GeneratedAssociationMethods#account | 0.00 | 0.00 | 0.26 | 0.00 | 0.53 | 0.16 |
| ActiveModel::EachValidator#validate | 0.00 | 0.12 | 0.00 | 0.53 | 0.08 | 0.14 |
| FinderMethods#take | 0.00 | 0.00 | 0.00 | 0.00 | 0.68 | 0.14 |
| Querying#exists? | 0.00 | 0.32 | 0.00 | 0.34 | 0.00 | 0.13 |
| Status::GeneratedAssociationMethods#build_status_stat | 0.00 | 0.00 | 0.00 | 0.00 | 0.63 | 0.13 |
| Delegation#as_json | 0.00 | 0.00 | 0.00 | 0.61 | 0.00 | 0.12 |
| SignedId::ClassMethods#find_signed | 0.00 | 0.00 | 0.58 | 0.00 | 0.00 | 0.12 |
