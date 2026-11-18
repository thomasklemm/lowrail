---
id: GQ1
repo: rmosolgo/graphql-ruby
kind: perf
area: Schema::Warden type and field caches
reviewer: rmosolgo
branch: thomasklemm/warden-name-caches-by-value
head: "4a77cd59bfed27d21f2787c70603850e70853e3a"
base: master
built_on: "9c9f8f28cc6f297c6944b3cc6f567bf4ebcd98b6"
depends_on: []
stacked_on:
alternative_of:
impact: "every schema without `use GraphQL::Schema::Visibility` (the default; the install generator doesn't add it) validates through the Warden: tracked validate benchmarks -7.5% (big query), -7.9% (abstract fragments), -43.0% (fields will merge) Callgrind Ir; execution within 1%; Zammad replay -0.64% (2026-11-05, earlier master)"
rank: 1
risky: true
state: in-review
pr:
note: "2026-11-18 Astra: changes required before opening. Production shape is L0 and normal multiplex queries remain isolated. Mid-query hook changes can retain either a now-denied result or nil; this is the disclosed semantic change, not exact compatibility. Profile matches field-name caching but bypasses Schema.get_type overrides, so the builder's equivalence claim is too broad. Replace hook-count assertions with observable-result coverage, correct scope/equivalence claims, and supply current-head benchmark-ips evidence on plausible workloads (the leading 5000-identical-field row belongs only in the record). Raw Ir/A/A arithmetic replays. No fork push or PR opening in this review. Record: docs/upstream/graphql-ruby.md#gq1-astra-review-2026-11-18; data bench/upstream/graphql_ruby/gq1-pr/. Old branch thomasklemm/warden-name-caches 4337055468 (on 2e8473ea7d) remains superseded."
passes:
  - {reviewer: skeptic, head: "5cb15cfdd1", date: 2026-11-05, verdict: changes, open: "context-dependent get_field overrides see one call per name per query; different execute result when a resolver mutates context (exprobe2.rb); comment reworded in 4337055468 (same code)"}
  - {reviewer: astra, head: "4a77cd59bfed27d21f2787c70603850e70853e3a", date: 2026-11-18, verdict: changes, orb: "T-01a1f036-3f72-70d5-b936-d1e3f63faddf", open: "Both Thermos rubrics applied directly. Replace call-count test with returned-value/query-isolation coverage; narrow Profile equivalence and per-query wording; remove pathological headline row and add exact-head benchmark-ips with A/A. No additional production-code blocker under per-operation-stable schema semantics; contextual hook result changes reproduced and must remain disclosed."}
---

# Cache Warden type and field lookups by name

`Warden#get_type` and `Warden#get_field` cache lookups by name but compare names by identity. Each AST node has its own name String, so the cache misses on every node: validating `{ a: thing { name } b: thing { name } }` runs `Schema.get_field` and the visibility checks for `name` twice. This is the default path for schemas without `use GraphQL::Schema::Visibility`.

This compares names by value. A type's `.get_field` override and `Schema.get_type` now run once per name per query, as `.get_field` overrides already do with `Visibility`, so an override that reads context a resolver changes mid-query keeps its first answer.

Callgrind instructions per call, Ruby 4.0, no JIT:

| | master | this PR |
| --- | ---: | ---: |
| validate - fields will merge | 226.8M | 129.2M |
| validate - big query | 35.3M | 32.6M |
| validate - abstract fragments | 2.38M | 2.20M |

The execution benchmarks move by less than 1% either way.

## For Thomas

Die Warden von graphql-ruby (Standard für jedes Schema ohne `use GraphQL::Schema::Visibility`, also die meisten Apps) merkt sich Typ- und Feld-Lookups pro Name, vergleicht den Namen aber nach Objektidentität. Jeder Knoten im Query-Dokument hat seinen eigenen String, also trifft der Cache nie, und jedes `name` im Dokument fragt das Schema erneut. Der PR vergleicht nach Wert: drei Zeilen Code plus ein Test. Validierung wird 7,5–43% billiger (Callgrind), Ausführung bewegt sich unter 1%.

Der Haken, offen im Body: Wer `.get_field` auf einem Typ oder `Schema.get_type` überschreibt (dokumentierter Hook), sieht diesen Aufruf jetzt einmal pro Name und Query statt einmal pro Vorkommen. Liest der Override Context, den ein Resolver mitten in der Query ändert, bleibt die erste Antwort. Genau so verhält sich `Visibility::Profile` heute schon (geprüft auf master), und rmosolgo hat dort selbst ein Name-Caching gemergt (#5586). Darum keine Sonderbehandlung für überschriebene Hooks: das wäre ein Guard, den er nicht schreiben würde.

Zu entscheiden: nur, ob der Draft nach dem Astra-Review so aufgeht.
