# Lead sweep 2026-11-27: probes and raw data

Record: [docs/upstream/lead-sweep-2026-11-27.md](../../../docs/upstream/lead-sweep-2026-11-27.md). Rails main
`2e299253f9`, Ruby 4.0.10 and Ruby master `0d399335b7` (ZJIT), on an a1.large orb.

* `to1-zjit/`: `script/upstream-bench` run of `to1_zjit.rb`, main against TO1 (fork commit `7f1f0dce45`
  cherry-picked onto main), interpreter and ZJIT on master; dumps in `raw/callgrind.tar.gz`.
  `results/to1_zjit_fn_diff.txt` and `results/to1_zjit_stats_diff.txt` (`to1_zjit_stats.rb`) explain the
  `f.text_field` loss.
* `unscope_probe.rb` + `lead8.diff` (census-9 lead 8), `a2_probe.rb` (census-10 A2), `builder_probe.rb`
  (per-row `attributes_builder`), `accept_probe.rb` (`Mime::Type.parse`), `index_with_micro.rb` (IWC): run as
  `ruby PROBE RAILS_TREE`, outputs with a second run as A/A in `results/`.
* `repros/`: `shareable_kwsplat.rb` (new correctness repro), `svar_refined_lambda.rb` (a failed reconstruction),
  `bigslot.rb` (from item GC); outputs in `results/repros.txt` and `results/bigslot-2026-11-27.txt`.
* `results/upstream-refs-2026-11-27.json`: the 176 issues and PRs named in the lead records, as GitHub returned them.
