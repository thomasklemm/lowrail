# ZJIT shortlist: where we can help (2026-11-03)

Triage of the 102 open "ZJIT" issues on Shopify/ruby, the tracking issues (#1021, #1030, #1039, #995, #1074)
and open ZJIT PRs on ruby/ruby. Claim status comes from assignees and comments only.

## What is already owned

* All three "good first issue" items are claimed (#1083, #1084, #1086). No issue carries "help wanted" or "easy".
* k0kubun's lobsters burndown (#1039) is an 83-row list of his own `zjit-lobsters7` commits. Polymorphic and
  megamorphic sends, ivar shape tables and yield dispatch (rows 5–10, 24–27, 35, 38, 52–56, 77–78) collide with it.
* Correctness bugs #970, #976, #988 (XrXr #18960), #1092 (nozomemein #19607), #1032 (k0kubun branch) are owned.
* Big projects (#1021): stack maps, adaptive compilation, minimize SSA, global load-store, inline frames,
  exceptions, perf comments: all owned.

## Shortlist, ranked

| # | Issue | What | Size | Rails relevance | Bet |
| --- | --- | --- | --- | --- | --- |
| 1 | [#1091](https://github.com/Shopify/ruby/issues/1091) | Integer/Module `to_s` in objtostring (cruby_methods pattern of #19587) | S–M | medium: allocation parity, −0.10% / −0.22% objects on lobsters / shipit ([Z5](zjit-objtostring.md)) | Z5: claimed with a data comment 2026-11-03 |
| 2 | [#1059](https://github.com/Shopify/ruby/issues/1059) | `String#match?` via Ruby builtin (nirvdrum's TruffleRuby design) | M | low: ≤ 0.05% Ir, Onigmo dominates ([Z7](zjit-cfunc-paths.md)) | Z7: not taken |
| 3 | [#1058](https://github.com/Shopify/ruby/issues/1058) | `Kernel#dup` beyond immediates | M | high: −0.50% to −0.90% Ir in a prototype ([Z7](zjit-cfunc-paths.md)) | Z7: claimed 2026-11-03; tekknolagi asked for a Ruby-level design, measured in [zjit-cfunc-paths](zjit-cfunc-paths.md#kerneldup-in-ruby-tekknolagis-question) |
| 4 | [#1065](https://github.com/Shopify/ruby/issues/1065)/[#1075](https://github.com/Shopify/ruby/issues/1075) | quadratic `handle_caller_saved_regs`, stopgap | S–M | compile time of large apps | Z6 |
| 5 | [#993](https://github.com/Shopify/ruby/issues/993) | InvokeSuper from a block | M | `synchronize { super }`; ask k0kubun first (rows 45–46) | held |
| 6 | [#1064](https://github.com/Shopify/ruby/issues/1064) | cache `iseq_may_write_block_code` | S | compile time | Z6 |
| 7 | [#746](https://github.com/Shopify/ruby/issues/746) + #995 | per-ISEQ stats; `IncrCounter` double-counting across optimize passes | S then M | our own counters depend on it | Z8 (L2) |
| 8 | [#808](https://github.com/Shopify/ruby/issues/808) | `Hash#size`, single-byte `String#length` inline loads | S | low: `Hash#size` ≤ 2,000 calls/itr, already a leaf `CCall` | dropped from Z5 |
| 9 | [#1049](https://github.com/Shopify/ruby/issues/1049) | FxHash | S | only with compile-time data | Z6 add-on |
| 10 | [#1042](https://github.com/Shopify/ruby/issues/1042) | less GC work for ProfiledType | M | high (GC per request), but near k0kubun's memdiet rows | data only |

## How we take an item

1. Measure the Rails effect first (census apps, ruby-bench counters, Callgrind with A/A).
2. Before writing a PR, comment on the issue with that data and say we would like to take it. That comment is
   the substance; it gives the owner a chance to say "already on my branch". Wait for no objection.
3. Then build, review (Astra, plus the adversarial Sol round), and open through the queue: at most two new ZJIT
   PRs open at once. Prefer finishing our open ones (#19483, #19558, #19655, #19659, #19662) over new ones.

Not taken (until 2026-11-03, see DECISIONS "ZJIT ideas are free to take"): anything in k0kubun's #1039 rows, tekknolagi's backend redesign area (#1077), core-semantics changes
without a ZJIT reviewer's interest.
