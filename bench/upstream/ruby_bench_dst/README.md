# DST lookups in lobsters ([record](../../../docs/upstream/ruby-bench-dst.md))

* `dst_micro.rb CASE N ir|obj|show`: one operation per case; `ir.sh OUT "variants" "cases" REPS` runs it under
  Callgrind (`--toggle-collect=rb_ary_cycle`, Ir(N) − Ir(0)) with `~/w/gf/<variant>/Gemfile` pointing at an Active
  Support checkout.
* `dst_harness.rb`: ruby-bench harness replacement (WARM passes, PASSES measured inside `[0].cycle`; `COUNT=1` counts
  tzinfo lookups, `FIX=file` redefines the two methods after boot). `lob.sh DATE FIX [env]` runs lobsters with it,
  libfaketime for DATE != real, fixed heap, `CG=1` for Callgrind.
* `dst_compare.rb SHARD/N`: differential over every zone and transition 1900–2045; compare the printed count and
  SHA-256 between checkouts.
* `twz-reuse-local-period.patch`: the Rails commit `4779066d80`. Raw outputs: `ir-*.txt`, `lobsters-callgrind.txt`,
  `differential-digests.txt`.

Which file holds which column: `ir-micro-final.txt` main vs the final head (`v2`), `ir-micro-81.txt` 8-1-stable vs
8-1 + fix (`s81fix`, the final `time_with_zone.rb` lines), `ir-micro-round1.txt` the first, rejected shape
(`periods.one?` checked first), `ir-tzinfo-shortcut.txt` tzinfo master vs `2b2f4b45`.
