| Mechanism (inclusive) | blog | campfire | fizzy | lobsters | mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| Association reader: scope built before the statement cache (#59212's lever) | 0.27 | 1.71 | 3.67 | 1.40 | 3.03 | 2.01 |
| Association#scope (any caller) | 0.66 | 4.02 | 8.45 | 3.40 | 5.15 | 4.34 |
| AssociationScope.scope (per owner record) | 0.29 | 2.48 | 4.31 | 1.76 | 2.71 | 2.31 |
| CollectionProxy#scope (has_many chains, count, exists?) | 0.02 | 1.96 | 4.29 | 1.32 | 0.56 | 1.63 |
| Preloader scope building (LoaderQuery, reflection_scope) | 0.17 | 0.61 | 0.75 | 0.93 | 0.49 | 0.59 |
| Named scope bodies (_exec_scope) | 0.00 | 1.50 | 0.89 | 1.00 | 1.42 | 0.96 |
| default_scope evaluation | 0.11 | 0.24 | 0.49 | 0.51 | 1.23 | 0.52 |
| Relation::Merger#merge | 0.13 | 0.86 | 2.10 | 0.90 | 1.20 | 1.04 |
| Relation copies (spawn, initialize_copy) | 0.57 | 0.72 | 1.02 | 1.39 | 0.82 | 0.91 |
| build_arel | 0.15 | 0.94 | 1.86 | 2.27 | 1.40 | 1.32 |
| Arel visitor compile | 0.61 | 0.93 | 3.75 | 2.94 | 1.17 | 1.88 |
| to_sql_and_binds | 0.80 | 1.10 | 3.93 | 3.11 | 1.35 | 2.06 |
| StatementCache#execute (all of it, incl. DB) | 4.23 | 1.12 | 5.78 | 4.46 | 5.83 | 4.28 |
| StatementCache.create (first use) | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| Query cache lookup (cache_sql) | 6.68 | 4.87 | 17.64 | 14.93 | 10.85 | 11.00 |
| QueryLogs | 0.00 | 0.00 | 0.00 | 0.45 | 0.00 | 0.09 |

| Mechanism (inclusive) | blog | fizzy | lobsters | mean |
|---|---:|---:|---:|---:|
| Association reader: scope built before the statement cache (#59212's lever) | 0.00 | 0.91 | 0.29 | 0.40 |
| Association#scope (any caller) | 0.00 | 3.86 | 0.74 | 1.53 |
| AssociationScope.scope (per owner record) | 0.00 | 2.09 | 0.45 | 0.84 |
| CollectionProxy#scope (has_many chains, count, exists?) | 0.00 | 2.96 | 0.45 | 1.14 |
| Preloader scope building (LoaderQuery, reflection_scope) | 0.28 | 0.76 | 0.53 | 0.53 |
| Named scope bodies (_exec_scope) | 0.00 | 0.74 | 0.25 | 0.33 |
| default_scope evaluation | 0.11 | 0.27 | 0.13 | 0.17 |
| Relation::Merger#merge | 0.00 | 0.88 | 0.22 | 0.37 |
| Relation copies (spawn, initialize_copy) | 0.46 | 0.68 | 1.10 | 0.75 |
| build_arel | 0.16 | 1.02 | 0.34 | 0.51 |
| Arel visitor compile | 0.66 | 5.01 | 1.18 | 2.28 |
| to_sql_and_binds | 0.72 | 5.21 | 1.26 | 2.40 |
| StatementCache#execute (all of it, incl. DB) | 0.80 | 1.61 | 1.64 | 1.35 |
| StatementCache.create (first use) | 0.00 | 0.00 | 0.00 | 0.00 |
| Query cache lookup (cache_sql) | 7.17 | 12.41 | 6.45 | 8.68 |
| QueryLogs | 0.00 | 0.00 | 0.23 | 0.08 |
