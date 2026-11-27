### L6 on the K1-merged main (2026-11-27)

K1 (#59800) merged on 2026-11-26, so L6 was rebuilt by hand on main `088fc0cf61` with
[L6-on-K1.diff](data/rails-main-census-9/lead6/L6-on-K1.diff), which applied cleanly: one commit `8b1c6428ea`, the same
message and the same four inlined lines. The base of every number below includes K1. Raw data, probes and suites:
[rebuild-2026-11-27](data/rails-main-census-9/lead6/rebuild-2026-11-27); body runs under `bench/upstream/lead6/body/`.

Interpreter Callgrind, `script/upstream-bench`, Ruby 4.0.9 ([L6-2026-11-27](../../bench/upstream/lead6/body/L6-2026-11-27/table.md),
[L6-w102-2026-11-27](../../bench/upstream/lead6/body/L6-w102-2026-11-27/table.md)):

| Case | 30 columns | A/A | 102 columns | A/A |
| --- | ---: | ---: | ---: | ---: |
| `update!` of one column | 1,456,136 → 1,395,418 (−4.2%) | 0.01% | 2,460,339 → 2,269,276 (−7.8%) | 0.01% |
| find, then `changed?` | 712,038 → 681,893 (−4.2%) | 0.04% | 1,832,522 → 1,731,697 (−5.5%) | 0.03% |
| `serializable_hash` | 191,400 → 178,771 (−6.6%) | 0.10% | 642,937 → 601,183 (−6.5%) | 0.03% |

Objects are unchanged (208 / 90 / 32 at 30 columns). YJIT, every window JIT-flat: `update!` −2.2% (A/A 0.21%), find then
`changed?` −2.4% (A/A 0.15%), `serializable_hash` −1.8% (A/A 1.23%, not claimed).

Ruby master `f3e180b5eb` × ZJIT ([L6-master-zjit-2026-11-27](../../bench/upstream/lead6/body/L6-master-zjit-2026-11-27/table.md)):
master's `RubyVM::ZJIT.stats` has no `invalidation_count`, so the gate prints "not JIT-flat" for every cell, while
compiled ISEQs, failed ISEQs and side exits stay flat in every window. `update!` −1.9% (A/A 0.02%), `changed?` −1.3%
(A/A 0.23%). `serializable_hash` read +1.4% (A/A 0.65%) with a 300-call warm-up: the candidate's dump has
`rb_ec_ary_new_from_values` called from a `vm_call_symbol` path that base's has not, so the two runs compiled
differently, while objects per call are equal (32). With the default 3,000-call warm-up and N = 1,000
([L6-master-zjit-serializable-hash-2026-11-27](../../bench/upstream/lead6/body/L6-master-zjit-serializable-hash-2026-11-27/table.md))
it is −1.0% (A/A 0.07%), and `--zjit-stats` over 10,000 warm calls shows 600,000 fewer sends and 12% fewer
`zjit_insn_count` on the candidate, the inlined `index_for_name` and `lookup` calls. No ZJIT loss.

Exactness and suites on `8b1c6428ea`: `bench/upstream/k1/keys_probe.rb` 6,959 lines identical on main and head;
TracePoint on `update!` of one column (30 columns): `#keys` 3 and `#[]` 41 calls on both, `index_for_name` 140 → 9,
`lookup` 133 → 2, all 38 `attribute_changed?` and the 3 `attr_names` callers as on main (`callers-main.txt`). Active Model
1,277 runs, Active Record SQLite 10,459 and PostgreSQL 17 11,391 runs, 0 failures (3 SQLite errors needed the
`sqlite3` CLI; `sqlite_rake_test.rb` green after installing it).
