---
id: GQ1
repo: rmosolgo/graphql-ruby
kind: perf
area: Schema::Warden type and field caches
reviewer: rmosolgo
branch: thomasklemm/warden-name-caches
head: "4337055468"
base: master
built_on: "2e8473ea7d"
depends_on: []
stacked_on:
alternative_of:
impact: "validate - fields will merge -43% Ir, big query -7.5%, abstract fragments -8.7%; Zammad replay -0.6%"
rank: 1
risky: false
state: held
pr:
note: "behaviour change, not exact: .get_field/Schema.get_type overrides run once per name per query, not per AST node (exec/exprobe2.rb); opens only if Thomas wants it posted as that"
passes:
  - {reviewer: skeptic, head: "5cb15cfdd1", date: 2026-11-05, verdict: changes, open: "context-dependent get_field overrides see one call per name per query; different execute result when a resolver mutates context (exprobe2.rb); comment reworded in 4337055468 (same code)"}
---

# Cache Warden type and field lookups by field name

`Schema.validate` takes up to 43% fewer instructions on graphql-ruby's tracked validation benchmarks. Warden caches `get_type` and `get_field` by name, but compares the names by identity, and every AST node carries its own name String. So the cache misses on every node, and each field node repeats `Schema.get_field` and the visibility checks. This compares names by value, as `Visibility::Profile` already does.

Behaviour change: a type's `.get_field` override and `Schema.get_type` now run once per name per query, not once per AST node. Results only differ when an override reads context that a resolver changes during the query.

| Cachegrind, instructions per iteration | master | this PR |
| --- | ---: | ---: |
| validate - fields will merge | 227.4M | 129.1M (−43.2%) |
| validate - big query | 35.07M | 32.43M (−7.5%) |
| validate - abstract fragments | 2.356M | 2.150M (−8.7%) |
| execute - introspection | 52.07M | 51.46M (−1.2%) |
| execute - large result | 285.8M | 286.0M (+0.1%) |

| `rake bench:validate`, two rounds | master | this PR |
| --- | ---: | ---: |
| fields will merge | 36–37 i/s | 70–72 i/s |
| big query | 136–137 i/s | 156–161 i/s |
| introspection | 1.12–1.13k i/s | 1.34k i/s |

Ruby 4.0.9 without JIT, fixed heap, two processes per revision (they differ by at most 1.7%). With the classic interpreter, introspection of `benchmark/big_schema.graphql` takes 0.56% more, because there the identity cache already hit for repeated nodes. Replaying eight of Zammad's desktop queries takes 0.6% fewer instructions. Results, errors, warnings and `visible?` calls are unchanged on the benchmark documents, Zammad's queries and a probe with hidden fields and types, with both parsers. Tests pass with and without `GRAPHQL_CPARSER=1`.

---

<sub>Found while profiling graphql-ruby for ruby/ruby-bench, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/8e699a82a8888c0ab0480402fca100a70438d4b6/docs/upstream/graphql-ruby.md#gq1-warden-name-caches-compare-by-value-held), my research project.</sub>
