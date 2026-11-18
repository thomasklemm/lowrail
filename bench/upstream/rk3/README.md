# RK3: rack decodes and escapes components with cgi/escape

Scripts behind the RK3 queue item ([item](../pr-queue/items/RK3.md), record in
[outside-rails-leads.md](../../../docs/upstream/outside-rails-leads.md#rk3-built-2026-11-18)). RACK is a rack checkout:
the branch `thomasklemm/unescape-cgi` or rack main.

**Review update:** [Thermos, 2026-11-18](review-thermos-sol/02087583dc/README.md) approves `02087583dc` with nits.
All three runtime findings are fixed. Eight matrices total 143,176 comparisons with zero differences; full suites
on 3.4.12/4.0.9 with and without `cgi/util` pass 1,295 runs each, as do the extended 300k differentials in
clean/util/pure configurations. The qualified draft is approved: request figures are head-method overlays on
Rack 3.2.7, interpreter results use glibc fastbins off, and two rejected cohorts remain rejected. Ungated YJIT
micro figures are diagnostic only; request YJIT windows are flat. Earlier review records remain historical.

* `diff_unescape.rb`, `diff_escape.rb`: `ruby -I RACK/lib diff_*.rb [N]` compares the branch's `Rack::Utils.unescape`,
  `QueryParser#unescape` and `Rack::Utils.escape` with `URI.decode_www_form_component` and
  `URI.encode_www_form_component` on N (default 300,000) random strings plus fixed odd inputs; `-r ./pure_cgi.rb`
  selects the Ruby fallback on 3.4, not actual JRuby/TruffleRuby execution. The `boundary` lines disclose native
  singleton `#b`, `#dup` or `#to_s` dispatch differences; arbitrary core-String overrides are not certified.
* `micro.sh MAIN_LIB BRANCH_LIB [yjit]`: Callgrind instructions per call of each line of `micro_exprs.txt`
  (setup `micro.rb`), main twice as the A/A.
* `ips.sh MAIN_LIB BRANCH_LIB OUTDIR [yjit]`: benchmark-ips of the same lines on one pinned core, main and branch
  alternating, `ROUNDS` rounds; `ips_table.rb OUTDIR...` prints best-of-rounds tables.
* `req/`: measurement patches for `bench/upstream/outside_leads/req/batch2.sh` (rack 3.2.7 in the census apps has
  the same three methods as main): `rk3.rb` is the first commit's methods verbatim, `rk34.rb` both commits,
  `none.rb` the A/A. Workload lists `wl-interp.txt`, `wl-yjit.txt`, `wl-yjit-pingcrm.txt` (run with `FLAT=40`).
* `body_ips.rb`, `body_ips.sh`: the benchmark in the item body, as run for its table.
* `review_exactness.rb`: deterministic 17,897-comparison matrix including genuinely frozen/chilled inputs,
  encodings and encoding-coercion callbacks, BasicObject, String subclasses and megabyte inputs; exits nonzero
  on differences. `review_fix_probe.rb` diagnostically checks the proposed minimal repairs without changing Rack.
* `review_rails.rb`: actual ActionDispatch query/form/cookie results and errors with Rack decoder-call counts.
* `review_receipts.rb`: independent arithmetic and JIT-counter audit of the historical request and body receipts.
  Review receipts, suite logs, the inconclusive old-head wall-time rerun and limitations are in `review-thermos-sol/`;
  `review-thermos-sol/6f48723a86/` contains the amended-head executions and confirmed hosted 2.7.3 setup failure.
* `review_final_receipts.rb`: independent raw N=0/N=2000, objects, rate and accepted/rejected request arithmetic
  for the final head. `review-thermos-sol/02087583dc/` contains the final pass, suite/differential executions,
  matrix outputs, head-method overlay comparison and independent malloc-dump audit. [`req/evidence/`](req/evidence/README.md)
  retains cohort invocations, environment propagation and the raw attribution archive.
