Query building by path (percent of server time)

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| built per query | 2.69 | 9.01 | 6.42 | 6.04 |
| statement cache | 0.06 | 0.09 | 0.17 | 0.11 |
| **total** | 2.75 | 9.11 | 6.58 | 6.15 |

Query building by stage

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| relation spawn/merge | 1.39 | 1.72 | 2.88 | 1.99 |
| build_arel | 0.40 | 2.39 | 0.97 | 1.25 |
| association scope | 0.14 | 2.49 | 0.79 | 1.14 |
| visitor (Arel to SQL) | 0.51 | 1.69 | 0.63 | 0.94 |
| other (load, finders, query cache, logs) | 0.25 | 0.60 | 0.60 | 0.48 |
| where predicates | 0.03 | 0.03 | 0.64 | 0.23 |
| binds | 0.03 | 0.20 | 0.08 | 0.10 |
| **total** | 2.75 | 9.11 | 6.58 | 6.15 |

Built per query, by stage

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| relation spawn/merge | 1.39 | 1.72 | 2.88 | 1.99 |
| build_arel | 0.40 | 2.39 | 0.97 | 1.25 |
| association scope | 0.14 | 2.49 | 0.79 | 1.14 |
| visitor (Arel to SQL) | 0.51 | 1.69 | 0.63 | 0.94 |
| other (load, finders, query cache, logs) | 0.22 | 0.56 | 0.47 | 0.42 |
| where predicates | 0.03 | 0.03 | 0.64 | 0.23 |
| (statement cache) | 0.06 | 0.09 | 0.17 | 0.11 |
| binds | 0.00 | 0.15 | 0.04 | 0.06 |
| **total** | 2.75 | 9.11 | 6.58 | 6.15 |

Query building by origin

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| association collection | 0.67 | 2.58 | 3.01 | 2.08 |
| relation | 1.07 | 2.34 | 1.50 | 1.64 |
| preload | 0.80 | 1.47 | 1.16 | 1.14 |
| count/exists?/pluck | 0.12 | 1.69 | 0.51 | 0.77 |
| association reader | 0.00 | 0.72 | 0.23 | 0.32 |
| Model.find/find_by | 0.10 | 0.30 | 0.18 | 0.19 |
| **total** | 2.75 | 9.11 | 6.58 | 6.15 |

Path × origin

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| built per query · association collection | 0.67 | 2.58 | 3.01 | 2.08 |
| built per query · relation | 1.07 | 2.34 | 1.50 | 1.64 |
| built per query · preload | 0.80 | 1.47 | 1.16 | 1.14 |
| built per query · count/exists?/pluck | 0.12 | 1.69 | 0.51 | 0.77 |
| built per query · association reader | 0.00 | 0.67 | 0.21 | 0.29 |
| built per query · Model.find/find_by | 0.03 | 0.27 | 0.04 | 0.11 |
| statement cache · Model.find/find_by | 0.06 | 0.04 | 0.14 | 0.08 |
| statement cache · association reader | 0.00 | 0.06 | 0.02 | 0.03 |
| **total** | 2.75 | 9.11 | 6.58 | 6.15 |

Inclusive, every layer (percent of server time)

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| bind type casting (all layers) | 0.19 | 0.80 | 0.02 | 0.34 |
| association scope built, then statement cache (all layers) | 0.00 | 0.91 | 0.29 | 0.40 |

Query building by entry point (top), percent of server time

| | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| QueryMethods#order | 0.12 | 0.21 | 1.84 | 0.72 |
| Relation#blank? | 0.31 | 1.29 | 0.00 | 0.54 |
| Relation#to_ary | 0.00 | 0.00 | 1.20 | 0.40 |
| Delegation#each | 0.43 | 0.21 | 0.48 | 0.37 |
| Relation#many? | 0.00 | 0.89 | 0.00 | 0.30 |
| Calculations#count | 0.00 | 0.57 | 0.28 | 0.28 |
| Associations::CollectionProxy#where | 0.00 | 0.34 | 0.44 | 0.26 |
| Story::GeneratedAssociationMethods#tags | 0.00 | 0.00 | 0.70 | 0.23 |
| ConnectionAdapters::QueryCache#select_all | 0.00 | 0.64 | 0.00 | 0.21 |
| Delegation#length | 0.01 | 0.62 | 0.00 | 0.21 |
| Querying#where | 0.00 | 0.00 | 0.49 | 0.16 |
| Relation#one? | 0.00 | 0.47 | 0.00 | 0.16 |
| Relation#preload_associations | 0.15 | 0.28 | 0.00 | 0.14 |
| ActiveModel::Serializers::JSON#as_json | 0.36 | 0.00 | 0.00 | 0.12 |
| Batches#find_each | 0.00 | 0.00 | 0.33 | 0.11 |
