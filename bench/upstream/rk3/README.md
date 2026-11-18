# RK3: rack decodes and escapes components with cgi/escape

Scripts behind the RK3 queue item ([item](../pr-queue/items/RK3.md), record in
[outside-rails-leads.md](../../../docs/upstream/outside-rails-leads.md#rk3-built-2026-11-18)). RACK is a rack checkout:
the branch `thomasklemm/unescape-cgi` or rack main.

* `diff_unescape.rb`, `diff_escape.rb`: `ruby -I RACK/lib diff_*.rb [N]` compares the branch's `Rack::Utils.unescape`,
  `QueryParser#unescape` and `Rack::Utils.escape` with `URI.decode_www_form_component` and
  `URI.encode_www_form_component` on N (default 300,000) random strings plus fixed odd inputs; `-r ./pure_cgi.rb`
  makes `CGI.escape` and `CGI.unescape` the Ruby fallback (as on JRuby and TruffleRuby). The `boundary` lines are
  the one known difference: a singleton `#b`, `#dup` or `#to_s` on the argument, which URI calls and the branch doesn't.
* `micro.sh MAIN_LIB BRANCH_LIB [yjit]`: Callgrind instructions per call of each line of `micro_exprs.txt`
  (setup `micro.rb`), main twice as the A/A.
* `ips.sh MAIN_LIB BRANCH_LIB OUTDIR [yjit]`: benchmark-ips of the same lines on one pinned core, main and branch
  alternating, `ROUNDS` rounds; `ips_table.rb OUTDIR...` prints best-of-rounds tables.
* `req/`: measurement patches for `bench/upstream/outside_leads/req/batch2.sh` (rack 3.2.7 in the census apps has
  the same three methods as main): `rk3.rb` is the first commit's methods verbatim, `rk34.rb` both commits,
  `none.rb` the A/A. Workload lists `wl-interp.txt`, `wl-yjit.txt`, `wl-yjit-pingcrm.txt` (run with `FLAT=40`).
* `body_ips.rb`, `body_ips.sh`: the benchmark in the item body, as run for its table.
