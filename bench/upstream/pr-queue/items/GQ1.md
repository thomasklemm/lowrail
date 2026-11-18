---
id: GQ1
repo: rmosolgo/graphql-ruby
kind: perf
area: Schema::Warden type and field caches
reviewer: rmosolgo
branch: thomasklemm/warden-name-caches-by-value
head: "8af96ec046d5831a3031eadd400249c168be8b87"
base: master
built_on: "9c9f8f28cc6f297c6944b3cc6f567bf4ebcd98b6"
depends_on: []
stacked_on:
alternative_of:
impact: "every schema without `use GraphQL::Schema::Visibility` (the default; the install generator does not add it) validates through the Warden: rake bench:validate 1.09x-1.16x i/s on introspection, abstract fragments and big query (A/A within 3.9%), Callgrind -7.5% to -12.4% Ir; execution Ir within 1%; 5000-identical-field stress -43% Ir stays in the record"
rank: 1
risky: true
state: ready
pr: 5908
note: "2026-11-18 21:47 UTC: Thomas marked rmosolgo/graphql-ruby#5908 ready for review; 17 checks green on 8af96ec046. 2026-11-18 thermos-sol approves 8af96ec046 after applying both rubrics directly without delegation: no remaining must-fix; body and commit checked sentence by sentence, submitted spec and negative controls run, owner/encoding/exception boundaries checked, retained ips/Ir replayed. Astra also approves this exact head. Reviewed for Thomas's requested draft; opening remains with the coordinator, no fork push or upstream posting in this review. Details: docs/upstream/graphql-ruby.md#gq1-thermos-sol-review-2026-11-18. Earlier fix round after Astra (changes on 4a77cd59bf): test asserts returned fields/types plus a fresh-query control instead of hook call counts; body narrows the Visibility precedent to field lookups and the cache lifetime to the Warden (normally one query); body table is benchmark-ips on plausible workloads measured on 8af96ec046 with A/A, stress row only in the record; execution sentence says instruction counts. lib/ identical to 4a77cd59bf, so its Callgrind data stands. Lease-pushed over 4a77cd59bf (unopened). Mid-query hook changes can retain either a now-denied result or nil; this is the disclosed semantic change, not exact compatibility. Profile matches field-name caching but bypasses Schema.get_type overrides. Data: bench/upstream/graphql_ruby/gq1-pr/. Old branch thomasklemm/warden-name-caches 4337055468 (on 2e8473ea7d) remains superseded."
passes:
  - {reviewer: astra, head: "4a77cd59bfed27d21f2787c70603850e70853e3a", orb: T-01a1f036-3f72-70d5-b936-d1e3f63faddf, date: 2026-11-18, verdict: changes, open: "test counts hook calls (DECISIONS: no call counts); Profile equivalence and once-per-query lifetime overstated; 5000-field stress row in body and no current-head benchmark-ips; fixed in 8af96ec046 (docs/upstream/graphql-ruby.md#gq1-astra-review-2026-11-18)"}
  - {reviewer: skeptic, head: "5cb15cfdd1", date: 2026-11-05, verdict: changes, open: "context-dependent get_field overrides see one call per name per query; different execute result when a resolver mutates context (exprobe2.rb); comment reworded in 4337055468 (same code)"}
  - {reviewer: astra, head: "8af96ec046d5831a3031eadd400249c168be8b87", date: 2026-11-18, verdict: approve, orb: "T-01a1f036-3f72-70d5-b936-d1e3f63faddf", open: "Confirm completed: all three must-fixes resolved; no remaining must-fix. Public Warden return-value test passes in normal/FUTURE setup, fails on base and with either cache half reverted. lib/ byte-identical to prior review; retained boundary outputs match. Body and commit message checked sentence by sentence. Best-of-six ips and split-half A/A replay; round 2 abstract-fragment i/s rounds to a tie (printed per-iteration times favor head by 0.026%), not a significant individual win. Details: docs/upstream/graphql-ruby.md#gq1-astra-confirm-2026-11-18. No upstream action authorized by this pass."}
  - {reviewer: thermos-sol, head: "8af96ec046d5831a3031eadd400249c168be8b87", date: 2026-11-18, verdict: approve, orb: "T-01a1f055-2764-74cf-bd79-103bc7afb6da", open: "No must-fix on either rubric, applied directly without other reviewers. Body and commit checked sentence by sentence. Spec: 6 assertions pass normal/FUTURE; base and each half-revert fail. Additional owner, encoding and exception/retry probes pass on base/head; retained Astra boundary outputs reproduce. Independently replayed all 12 ips logs and 72 Ir totals; body rounding and execution sentence match. L0; no new guards or comments. Full suites/C parser/Sorbet not rerun; timing replay is not a new benchmark. Details: docs/upstream/graphql-ruby.md#gq1-thermos-sol-review-2026-11-18. No fork push, PR opening or upstream post."}
---

# Cache Warden type and field lookups by name

`Warden#get_type` and `Warden#get_field` cache lookups by name but compare names by identity. Each AST node has its own name String, so equal names in different selections miss the cache: validating `{ a: thing { name } b: thing { name } }` runs `Schema.get_field` and the visibility and reachability checks for `name` twice. Schemas use the Warden unless they add `use GraphQL::Schema::Visibility`.

This compares names by value, so a Warden, which normally lives for one query, keeps the first result for each name, as `Visibility::Profile` already does for a type's `.get_field`. A `.get_field` or `Schema.get_type` override that reads context a resolver changes mid-query now keeps its first answer, in line with the dynamic types guide's "caches schema elements for the duration of the operation".

`rake bench:validate` on Ruby 4.0, i/s:

| | master | this PR |
| --- | ---: | ---: |
| validate - introspection | 1.22k | 1.39k |
| validate - abstract fragments | 1.94k | 2.12k |
| validate - abstract fragments 2 | 1.28k | 1.41k |
| validate - big query | 149.8 | 173.3 |

Instruction counts for the execution benchmarks change by less than 1% either way.

## For Thomas

Die Warden von graphql-ruby (Standard für jedes Schema ohne `use GraphQL::Schema::Visibility`) merkt sich Typ- und Feld-Lookups pro Name, vergleicht den Namen aber nach Objektidentität. Jeder Knoten im Query-Dokument hat seinen eigenen String, also trifft der Cache bei gleichen Namen in verschiedenen Selections nie. Der PR vergleicht nach Wert: drei Zeilen Code plus ein Test. `rake bench:validate` wird auf normalen Queries 9–16% schneller (A/A unter 4%), Ausführung bewegt sich unter 1% Instruktionen.

Der Haken, offen im Body: Ein `.get_field`- oder `Schema.get_type`-Override, der Context liest, den ein Resolver mitten in der Query ändert, behält seine erste Antwort (auch `nil`). Der Guide sagt schon, Schema-Elemente würden für die Dauer der Operation gecacht, und `Visibility::Profile` cacht `.get_field` genauso. Der Test prüft jetzt Ergebnisse statt Aufrufzahlen (Astras Einwand).

Zu entscheiden: nur, ob der Draft nach der Bestätigung so aufgeht.
