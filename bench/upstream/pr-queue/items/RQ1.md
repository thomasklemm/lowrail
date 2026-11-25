---
id: RQ1
repo: whomwah/rqrcode_core
fork: thomasklemm/rqrcode_core
kind: perf
area: QRUtil.rszf (right shift zero fill)
reviewer: whomwah
branch: thomasklemm/rszf-without-bignums
head: "51c099c822bf9c98cec301a350b5b21b0a84960f"
base: main
built_on: "ca75f7a55a"
depends_on: []
stacked_on:
alternative_of:
impact: "One TOTP provisioning QR code allocates 45,453 objects at the default ARCH_BITS of a 64-bit Ruby and 6,055 with the branch (-86.7%, interpreter and YJIT), the same as RQRCODE_CORE_ARCH_BITS=32 without the env var; the top line outside the app on Dawarich (23% of request objects) and Redmine (1.8%)"
rank:
risky: false
state: built
pr:
note: "2026-11-25 (oss-profile-sweep-1): found by lowrail-profile on Dawarich and Redmine (docs/upstream/oss-profile-sweep-1.md). Ownership: no open PR or issue in whomwah/rqrcode_core; #28 (2021) added the ARCH_BITS env override instead of changing the default, #51 (2026) documented ARCH_BITS=32 as recommended and kept the default; not in the queue or the bundled ledger. Built on main ca75f7a55a: rake test 103 runs, 0 failures with ARCH_BITS 64 and 32, standardrb clean; the new test fails without the masked fallback. rszf equals the old formula on 261,495 (64) and 132,759 (32) cases across signs and sizes, and the QR text of 304 strings is identical on main and branch under both settings (orb backup sweep/rq_diff.rb). Body numbers: objects only (bench/upstream/oss_profile_sweep_1/body/RQ1, objects.sh, script/upstream-bench's own objects worker with the fixed heap, base twice, A/A identical); no Callgrind cell, because a 3,000-call warm-up at ~35 ms per call under Valgrind takes hours, so no instruction or time claim. No pass yet."
passes: []
---

# Skip the Bignum mask in rszf when it cannot change the result

On a 64-bit Ruby, `QRUtil.rszf` builds `(1 << (64 - count)) - 1` on every call, and for a count of 0, 1 or 2 that mask is a Bignum. One QR code calls it often enough that these masks are most of what it allocates:

```ruby
RQRCodeCore::QRCode.new("otpauth://totp/Redmine:jsmith%40somenet.foo?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567&issuer=Redmine")
# 45,453 objects before, 6,055 after
```

For a value from 0 up to `2**ARCH_BITS`, `num >> count` already fits the mask, so `rszf` now returns it directly; negative and larger values still take the masked path. The results are the same as before under both `ARCH_BITS` settings, and the default now allocates what `RQRCODE_CORE_ARCH_BITS=32` did, without the environment variable.

| Objects per `QRCode.new` (Ruby 4.0.9) | main | branch |
| --- | ---: | ---: |
| no JIT | 45,453 | 6,055 |
| YJIT | 45,453 | 6,055 |

## For Thomas

Seen in two apps' own suites: Dawarich's TOTP setup page (rqrcode_core's rszf line is 23% of all request objects of its request specs) and Redmine's two-factor activation (TwofaController#activate_confirm, 33,851 of 56,476 warm objects per request). The README and test/benchmarks/ARCH_BITS_ANALYSIS.md already recommend ARCH_BITS=32; this gives the same allocations without changing the documented default or the env var.
