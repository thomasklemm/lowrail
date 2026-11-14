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
note: "Ir: fields-will-merge -43.2%, big query -7.5%, abstract fragments -8.7%, execute_next introspection -1.2%, legacy big-schema introspection +0.56%, Zammad replay -0.64%; tests green except dataloader timing flakes, srb tc and rubocop clean; held: behaviour change, not exact: .get_field/Schema.get_type overrides run once per name per query, not per AST node (exec/exprobe2.rb); opens only if Thomas wants it posted as that"
passes:
  - {reviewer: skeptic, head: "5cb15cfdd1", date: 2026-11-05, verdict: changes, open: "context-dependent get_field overrides see one call per name per query; different execute result when a resolver mutates context (exprobe2.rb); comment reworded in 4337055468 (same code)"}
---

# Cache Warden type and field lookups by name

Warden caches `get_type` and `get_field` by name, but compares names by identity. Every AST node carries its own name String, so the cache misses on every node, and validating a field repeats `Schema.get_field` and its visibility checks each time the field appears.

This compares names by value, as `Visibility::Profile` already does. Results and `visible?` calls stay the same. One thing changes: a type's `.get_field` override, or `Schema.get_type`, now runs once per name per query instead of once per node, so it sees the context of the first lookup.

| `rake bench:validate` | master | this PR |
| --- | ---: | ---: |
| fields will merge | 36–37 i/s | 70–72 i/s |
| big query | 136–137 i/s | 156–161 i/s |
| introspection | 1.12–1.13k i/s | 1.34k i/s |

---

<sub>Found while profiling graphql-ruby for ruby/ruby-bench ([record](https://github.com/thomasklemm/lowrail/blob/8e699a82a8888c0ab0480402fca100a70438d4b6/docs/upstream/graphql-ruby.md#gq1-warden-name-caches-compare-by-value-held)).</sub>
