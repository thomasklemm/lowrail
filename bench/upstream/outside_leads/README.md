# Leads outside rails/rails (2026-11-17)

Scripts behind [docs/upstream/outside-rails-leads.md](../../../docs/upstream/outside-rails-leads.md).

* `stdrun.rb OUTDIR LABEL APPS [MODES]` runs `stdprof.rb` (the gem request census profiler, but Ruby's standard
  library and default gems are owned by `std:<lib>` instead of folding into their callers, and each sample also
  records the nearest frame with another owner) in census copies; `stdrank.rb DIR MODE KIND [REGEX] [LIMIT]` ranks
  the result (`owncallers`, `callers`, `methods`, `incl`, `inclown`, `cfuncs`).
* `req/reqrun.rb APP WORKLOAD N MODE PATCH` counts Callgrind instructions and objects per request of one census
  workload, only inside `Rails.application#call`, with a measurement patch loaded after boot (`none.rb` for base
  and A/A); `req/batch2.sh OUT MODE PATCH...` loops over a workload list. Each line ends with
  `jit B/I settle S`: YJIT blocks compiled and invalidations in the measured window (a YJIT number counts only at
  `0/0`) and the extra warm-up windows `FLAT=K` needed to get there. `req/countrun.rb APP` counts calls per
  request of the methods the leads touch.
* `micro/` has the per-call Callgrind setups (run with `bench/upstream/gem_request_census/ir.sh`) and the
  differentials for the rack decode and escape variants.

The measurement patches in `req/` are not upstream branches.
