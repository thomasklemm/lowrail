# UR1 improvement review, raw data (fable, 2026-11-27)

Behind [../fable-b0f2bb7-2026-11-27.md](../fable-b0f2bb7-2026-11-27.md). ruby/uri head b0f2bb7 on master 48cda77.
The scripts name paths of the reviewing orb (`.amp/in/orb-backup/{uri,uri-base,v-*}` for the checkouts, `/tmp/rt`
for TruffleRuby 40.0.0 and JRuby 9.4.16.0); adjust them to rerun.

* `mkvariants.rb` builds the variants from the head; `variants/*-vs-b0f2bb7.diff` is each one as a diff.
  `v-native`: one check gates both decoders (the recommendation). `v-polish`: the optional changes on the head's
  shape. `v-respond`: `respond_to?` alone. `v-gsub`: `decode_uri_component` keeps its `gsub`.
* `runall.sh` runs ruby/uri's suite, `../diff.rb` and `../probe.rb` and a `ruby -w` load for the head and each
  variant: `logs/summary.txt`, with the TruffleRuby suites in `logs/suite-truffleruby-rerun.txt`.
* `mutants.rb`: `logs/mutants-v-native.txt`, `logs/mutants-v-polish.txt` (first failing assertion per test method).
* `j94.rb` and the suite on JRuby 9.4.16.0: `logs/jruby-9.4.16.0.txt`.
* `tbench.rb`, `ttable.sh`: ns per call. `truffle-time/run{1,2,3}-*` on TruffleRuby (run 1 has `v-respond` in the
  fourth column, runs 2 and 3 `v-native`), `mri-time/run1-*` on MRI 4.0.9. Wall time on an 8-core orb, one process
  per pair of cores; not a body cohort.
* `tpieces.rb`: the steps of cgi's Ruby `CGI.unescape` on TruffleRuby, `logs/truffleruby-cgi-unescape-steps.txt`;
  `logs/truffleruby-facts.txt`.
* `rfc2396_lead.rb`: `RFC2396_Parser#unescape` against `CGI.unescapeURIComponent`, `logs/rfc2396-unescape-lead.txt`.
* `logs/base-objects-and-cgi-gem.txt`: objects per call on master by number of escapes; what `require "cgi/escape"`
  activates on Ruby 4.0.9.
