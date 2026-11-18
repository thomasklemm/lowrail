# RK3: rack decodes and escapes components with cgi/escape

Scripts behind the RK3 queue item ([item](../pr-queue/items/RK3.md), record in
[outside-rails-leads.md](../../../docs/upstream/outside-rails-leads.md#rk3-built-2026-11-18)). RACK is a rack checkout:
the branch `thomasklemm/unescape-cgi` or rack main.

**Review update:** [Thermos, 2026-11-18](review-thermos-sol/6f48723a86/README.md) requests changes on `6f48723a86`.
The amended escape guard fixes the old-head UTF-16 failure. Full suites and the original 300k scripts pass on
3.4.12/4.0.9 both with and without `cgi/util`; expanded matrices still find encoding-duck and BasicObject
regressions on 2.7.3/3.4.12/4.0.9 and pure CGI. Diagnostic fixes pass all eight configurations. The reviewed
draft stays unapproved; whole-request receipts predate the guard amendment. Old-head results remain historical.

* `diff_unescape.rb`, `diff_escape.rb`: `ruby -I RACK/lib diff_*.rb [N]` compares the branch's `Rack::Utils.unescape`,
  `QueryParser#unescape` and `Rack::Utils.escape` with `URI.decode_www_form_component` and
  `URI.encode_www_form_component` on N (default 300,000) random strings plus fixed odd inputs; `-r ./pure_cgi.rb`
  selects the Ruby fallback on 3.4, not actual JRuby/TruffleRuby execution. The `boundary` lines disclose native
  singleton `#b`, `#dup` or `#to_s` dispatch differences; they are not the only differences found in review.
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
