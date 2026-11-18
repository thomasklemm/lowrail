# RK3 request runs on head 02087583dc: invocations and evidence

All runs: Ruby 4.0.9, census copies of blog (Rails `4500a94c34`), pingcrm and codetriage (Rails `50c54eed06`), rack
3.2.7 from each app's bundle with the head's method bodies loaded after boot: [`../rk3.rb`](../rk3.rb) (decode
commit) and [`../rk34.rb`](../rk34.rb) (both commits), verbatim copies of `Rack::Utils.unescape`,
`Rack::QueryParser#unescape` and `Rack::Utils.escape` at `02087583dc` (checked with `diff` against the rack
checkout). Rack 3.2.7's versions of these three methods equal rack main `da90464e3f`'s. [`../none.rb`](../none.rb) is
the unchanged control. Not the full head checkout.

Each line of a cohort is one process: `reqrun.rb APP WORKLOAD 20 MODE PATCH` under Callgrind, counting only
`Rails.application#call`, GC off for the 20 measured requests (`NOGC=1`). Order per workload: none, none, rk3, rk34,
none, so every workload has three unchanged runs; A/A = (max − min) / mean of those three.

Superseded for the body by the exact-head, full-checkout cohorts in [`../../head/`](../../head/README.md); kept as
the record of these runs.

## Cohorts

Run from `bench/upstream/rk3/req`:

| Cohort | Invocation | Receipt | Status |
| --- | --- | --- | --- |
| interp 1 | `NOGC=1 WL=$PWD/wl-interp.txt ../../outside_leads/req/batch2.sh /tmp/fh-interp.txt interp ../../rk3/req/none.rb ../../rk3/req/none.rb ../../rk3/req/rk3.rb ../../rk3/req/rk34.rb ../../rk3/req/none.rb` | [`fh-interp.txt`](../../../../../docs/upstream/data/rk3/final-head/fh-interp.txt) | rejected: blog GET article A/A 0.97%; JSON control 4.24M / 4.31M |
| yjit | `NOGC=1 WARM=1000 FLAT=40 WL=$PWD/wl-yjit.txt ../../outside_leads/req/batch2.sh /tmp/fh-yjit.txt yjit` + same five patches | [`fh-yjit.txt`](../../../../../docs/upstream/data/rk3/final-head/fh-yjit.txt) | accepted: every window `jit 0/0`, A/A ≤ 0.51% |
| interp 2 | as interp 1, output `/tmp/fh-interp2.txt` | [`fh-interp2.txt`](../../../../../docs/upstream/data/rk3/final-head/fh-interp2.txt) | rejected: JSON control 4.24M / 4.31M again |
| interp 3 | `GLIBC_TUNABLES=glibc.malloc.mxfast=0 NOGC=1 WL=$PWD/wl-interp.txt ../../outside_leads/req/batch2.sh /tmp/fh-interp3.txt interp` + same five patches | [`fh-interp3.txt`](../../../../../docs/upstream/data/rk3/final-head/fh-interp3.txt) | accepted: A/A ≤ 0.18% |

The YJIT and interp 2 cohorts ran from [`rk3-chain.sh`](rk3-chain.sh) (copy of the script that sequenced them); interp
1 and 3 were started directly with the lines above. Tables: [`../table.rb`](../table.rb) on each receipt.

**How mxfast=0 was applied.** `GLIBC_TUNABLES` was set once on the `batch2.sh` command line of cohort interp 3.
`batch2.sh` runs every `reqrun.rb` (all 25 processes: base, rk3, rk34, base) in that environment, and `reqrun.rb`
starts Valgrind with `system(env, ...)`, which adds the census variables from `Census.env_for` (`script/census`
line 245) to the inherited environment and does not clear it, so the tunable reached every measured Ruby, base and
candidate alike. The YJIT cohort ran without it; its A/A passed.

## Why interp 1 and 2 were rejected

Two unchanged runs of the same workload differed by 1.0–1.6%, far above the 0.1% these runs usually show. Callgrind's
per-function difference between the outlier and its pair ([`attribute.sh`](attribute.sh), dumps in
[`callgrind-dumps.tar.xz`](callgrind-dumps.tar.xz), totals over the 20 measured requests):

* [`malloc-cohort1-103216-103308.txt`](malloc-cohort1-103216-103308.txt), blog GET article, none vs none:
  +1,625,300 Ir, of which `malloc_consolidate` +818,128, `_int_malloc` +440,063, `unlink_chunk` +272,571.
* [`malloc-cohort1-104170-104250.txt`](malloc-cohort1-104170-104250.txt), JSON control, none vs rk3 (rk3 does not
  touch this request): +1,359,749, `malloc_consolidate` +745,309.
* [`malloc-cohort2-108839-108878.txt`](malloc-cohort2-108839-108878.txt), JSON control, none vs none: +1,348,676,
  `malloc_consolidate` +757,651.

So the difference is glibc consolidating fastbins in some processes and not others, not Rack. Turning fastbins off
(`mxfast=0`) removes that path; cohort 3's spreads are 0.03–0.18%. The rejected cohorts' deltas point the same way
(blog PATCH both commits −4.9% / −5.6%) but are not used.
