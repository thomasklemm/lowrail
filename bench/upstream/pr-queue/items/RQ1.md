---
id: RQ1
repo: whomwah/rqrcode_core
fork: thomasklemm/rqrcode_core
kind: perf
area: QRUtil.rszf (right shift zero fill)
reviewer: whomwah
branch: thomasklemm/rszf-without-bignums
head: "16d8339f455d3a1e15fb5b6860f22ef5cf6b82da"
merged_head: "16d8339f455d3a1e15fb5b6860f22ef5cf6b82da"
base: main
built_on: "ca75f7a55a"
introduced_by: "5f6de842aa88085ce764f960316ef365bfeff72a"
tracker: [whomwah/rqrcode_core#27, whomwah/rqrcode_core#28, whomwah/rqrcode_core#51]
depends_on: []
stacked_on:
alternative_of:
impact: "One TOTP provisioning QR code allocates 45,453 objects at the default ARCH_BITS of a 64-bit Ruby and 6,055 with the branch (-86.7%, interpreter and YJIT), the same as RQRCODE_CORE_ARCH_BITS=32 without the env var; the top line outside the app on Dawarich (23% of request objects) and Redmine (1.8%)"
evidence: [bench/upstream/oss_profile_sweep_1/body/RQ1, bench/upstream/oss_profile_sweep_1/review/RQ1-thermos-sol.tar.gz]
rank:
risky: false
state: merged
pr: 57
note: "2026-11-26 13:34 UTC: approved and merged by whomwah as 3c5ef2202e. Earlier: 2026-11-25 (coordinator, Thomas OK to open the found fixes as drafts; no earlier or closed PR on rszf beyond #28, which introduced the current formula): opened as draft whomwah/rqrcode_core#57 at 16d8339f45 after thermos-sol approved (1ed0225c). 2026-11-25 (oss-profile-sweep-1): found by lowrail-profile on Dawarich and Redmine (docs/upstream/oss-profile-sweep-1.md). Ownership: no open PR or issue in whomwah/rqrcode_core; #28 (2021) added the ARCH_BITS env override instead of changing the default, #51 (2026) documented ARCH_BITS=32 as recommended and kept the default; not in the queue or the bundled ledger. Built on main ca75f7a55a: rake test 103 runs, 0 failures with ARCH_BITS 64 and 32, standardrb clean; the new test fails without the masked fallback. rszf equals the old formula on 261,495 (64) and 132,759 (32) cases across signs and sizes, and the QR text of 304 strings is identical on main and branch under both settings (orb backup sweep/rq_diff.rb). Body numbers: objects only (bench/upstream/oss_profile_sweep_1/body/RQ1, objects.sh, script/upstream-bench's own objects worker with the fixed heap, base twice, A/A identical); no Callgrind cell, because a 3,000-call warm-up at ~35 ms per call under Valgrind takes hours, so no instruction or time claim. Thermos-sol changes on this head: body scope/final-mask wording, two missing test boundaries, CHANGELOG; exact fixes and independent evidence below For Thomas. No upstream edits or publication. 2026-11-25 (R1-R3 applied): head 16d8339f45 amends 51c099c822 on the same main ca75f7a55a. R1: body replaced with Thermos-sol's exact text (mask construction allocates temporary Bignums, exclusive bound below 2**ARCH_BITS, equivalence scoped to QR generation's integer calls, one no-JIT table row, no repeated numbers); commit message scoped the same way; no guards added for fractional counts, duck types, huge shifts or ARCH_BITS. R2: rszf(1 << bits, 0) and rszf(1, bits) added to the test; both pass on base and head at widths 64 and 32, and the `<= RSZF_LIMIT` and `count % ARCH_BITS` mutants each fail at width 64 and 32 (test lines 176 and 177). R3: Unreleased CHANGELOG entry. rake test 103 runs, 2,857 assertions, 0 failures at ARCH_BITS 64 and 32; standardrb 31 files, no offenses; Thomas author/committer, no trailers, fork pre-push hook installed; lease-pushed over 51c099c822. Confirm pass by thermos-sol pending."
ownership: {date: 2026-11-25, checked: ["open PRs cross-referencing #28","open PRs naming rszf that change lib/rqrcode_core/qrcode/qr_util.rb","whomwah/rqrcode_core#27 and what references it","whomwah/rqrcode_core#28 and what references it","whomwah/rqrcode_core#51 and what references it"], hits: ["tracker: whomwah/rqrcode_core#27 (closed): Memory allocation issue","tracker: whomwah/rqrcode_core#28 (merged): Alternative ZFRS to improve memory allocation","tracker: whomwah/rqrcode_core#51 (merged): Using AI Assistant to identity (and fix) performance bottlenecks"]}
passes:
  - reviewer: thermos-sol
    head: "51c099c822bf9c98cec301a350b5b21b0a84960f"
    orb: "T-01a214c3-baff-7000-a8d1-372fff9f406c"
    date: 2026-11-25
    verdict: changes
    open: >-
      Both Thermos rubrics self-performed, no subagents or child threads. QR integer
      call sites are sound; not equivalent for arbitrary Ruby inputs or exceptional
      shifts. Must-fix: R1 body scope/final-mask wording and matching commit prose;
      R2 add exact-width and full-width-shift regression assertions; R3 add an
      Unreleased CHANGELOG entry. Smallest fixes, every body sentence, ownership,
      contribution rules, 3,624,517 integer comparisons, QR parity, suites, mutants,
      complexity metrics and bounded allocation replay are recorded below For Thomas.
      No upstream changes, PR, comment or push. Evidence metadata added in this pass.
  - reviewer: thermos-sol
    head: "16d8339f455d3a1e15fb5b6860f22ef5cf6b82da"
    orb: "T-01a214c3-baff-7000-a8d1-372fff9f406c"
    date: 2026-11-25
    verdict: approve
    open: >-
      Delta-only confirm under both rubrics against 51c099c822bf9c98cec301a350b5b21b0a84960f;
      no must-fix or nit remains. Same parent ca75f7a55a29ecb990fc70f1a372a5c9724ae02d,
      unchanged lib/ byte for byte, only two test assertions and the Unreleased
      CHANGELOG entry added. R1 body exactly equals the prior proposed replacement;
      commit prose now says mask construction allocates temporary Bignums, uses the
      exclusive bound below 2**ARCH_BITS, and scopes equivalence to QR integer calls.
      No speculative type guards, added comments or structural regression. R2 actual
      test passes all five assertions against the base formula at widths 32/64;
      inclusive-limit and modulo-width-count mutants are now killed at both widths.
      R3 changelog uses the requested one-line entry. Independently reran rake test:
      103 runs, 2,857 assertions, zero failures/errors/skips at each width; StandardRB
      32 files, no offenses. Thomas author/committer, empty trailers, diff --check
      clean, fork branch matches this full head. Previous runtime/QR and objects-only
      evidence carries because runtime is identical; no benchmark rerun or expanded
      claim, and prior non-QR boundaries remain accepted. No upstream writes.
---

# Skip the Bignum mask in rszf when it cannot change the result

While profiling TOTP setup pages, `QRUtil.rszf` stood out for allocating temporary Bignums while building its mask. On a 64-bit Ruby this happens for counts of 0, 1 and 2; they account for most allocations for this provisioning URI:

```ruby
RQRCodeCore::QRCode.new("otpauth://totp/Redmine:jsmith%40somenet.foo?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567&issuer=Redmine")
```

For the integer arguments used by QR generation, the shift already fits the mask when `0 <= num && num < 2**ARCH_BITS`, so those calls now skip it. Negative and larger integers keep the masked calculation. The default width and `RQRCODE_CORE_ARCH_BITS` override stay unchanged.

| Objects per `QRCode.new` (Ruby 4.0.9, no JIT) | main | branch |
| --- | ---: | ---: |
| TOTP provisioning URI | 45,453 | 6,055 |

## For Thomas

Seen in two apps' own suites: Dawarich's TOTP setup page (rqrcode_core's rszf line is 23% of all request objects of its request specs) and Redmine's two-factor activation (TwofaController#activate_confirm, 33,851 of 56,476 warm objects per request). The README and test/benchmarks/ARCH_BITS_ANALYSIS.md already recommend ARCH_BITS=32; this gives the same allocations without changing the documented default or the env var.

### Thermos-sol review, 2026-11-25 — changes

Reviewed `ca75f7a55a29ecb990fc70f1a372a5c9724ae02d..51c099c822bf9c98cec301a350b5b21b0a84960f`
in [this review orb](https://ampcode.com/threads/T-01a214c3-baff-7000-a8d1-372fff9f406c),
both rubrics personally and sequentially as requested. The fork branch and upstream main still match those pins.
No upstream source, branch, issue or PR was changed. The proposed body above remains unedited for its owner.

**R1 — must-fix, factual scope and PR prose** (`qr_util.rb:93–97`, body paragraphs 1–2, commit message).
For ordinary integer arguments the arithmetic is correct, including negative numbers, negative counts,
counts at/past 32 and 64, and values at/past `2**31`, `2**32` and `2**64`. But “every input” is false:

* With width 64, `rszf((1 << 63) | 3, 1.5)` returns `1` on base and `4611686018427387905` on head.
  `Rational(3, 2)` differs identically. A custom object implementing only `>>` returned `5` on base and now
  raises `NoMethodError` at `>=`. These are not used by QR generation; do not add speculative type guards.
* Even integer exception behavior is not universal: `rszf(0, -(1 << 100))` raises `RangeError` on base and
  returns `0` on head. An unsupported `RQRCODE_CORE_ARCH_BITS=18446744073709551616` loads on base but raises
  `NoMemoryError` at head's new eager constant. Documented widths are 32/64, not arbitrary huge settings.
* At count 2 on this 64-bit Ruby, `(1 << 62) - 1` is an immediate Integer, not a Bignum.
  `ObjectSpace.memsize_of(1 << 62)` is 40, but `ObjectSpace.memsize_of((1 << 62) - 1)` is 0:
  mask **construction** allocates the Bignum. Say “below”, not the ambiguous “up to”, at the exclusive limit.

Scope the equivalence claim to QR generation's integer calls. Do not imply that widths 32 and 64 return
identical results for arbitrary numbers: `rszf(-1, 1)` intentionally differs between those settings.
The smallest factual edits are “building that mask allocates temporary Bignums” and “for the integer
arguments used by QR generation, when `0 <= num && num < 2**ARCH_BITS`”. Apply that scope to the commit too.
The commit otherwise explains the reason, has Thomas as author/committer, and has no trailers; it is unsigned.

Sentence-by-sentence body audit:

1. “On a 64-bit Ruby…” — default width is 64 here; wrong final-mask claim at count 2, fixed above.
2. “One QR code…” — verified for the actual provisioning URI; not a claim about every possible QR code.
   The code example is the same URI used by the committed benchmark. Remove its repeated numeric comment;
   the one before/after table already carries those values.
3. “For a value from 0 up to…” — correct only with an exclusive bound and integer-call scope; negative/larger
   integer fallback is unchanged. The two guards are both necessary, as the mutants demonstrate.
4. “The results are the same…” — overbroad as written; the default/env declaration is unchanged and the
   QR results agree under each setting. Objects at width 64 match old width 32 for this URI, not all callers.
5. Table — rounded counts match raw data and independent replay. No instruction or time inference is allowed.
   Neither the objects worker nor the recorded files capture JIT-flat windows; drop the redundant YJIT row
   from the proposed body rather than imply the queue README's JIT-cell gate was exercised.

Exact shorter replacement body (keeps the existing title; no internal links, pins, test counts or process):

````markdown
While profiling TOTP setup pages, `QRUtil.rszf` stood out for allocating temporary Bignums while building its mask. On a 64-bit Ruby this happens for counts of 0, 1 and 2; they account for most allocations for this provisioning URI:

```ruby
RQRCodeCore::QRCode.new("otpauth://totp/Redmine:jsmith%40somenet.foo?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567&issuer=Redmine")
```

For the integer arguments used by QR generation, the shift already fits the mask when `0 <= num && num < 2**ARCH_BITS`, so those calls now skip it. Negative and larger integers keep the masked calculation. The default width and `RQRCODE_CORE_ARCH_BITS` override stay unchanged.

| Objects per `QRCode.new` (Ruby 4.0.9, no JIT) | main | branch |
| --- | ---: | ---: |
| TOTP provisioning URI | 45,453 | 6,055 |
````

**R2 — must-fix, two missing boundary assertions** (`test/rqrcode_core/rqrcode_test.rb:171–175`).
The new test kills a bare shift and either missing range/sign guard, and kills a fixed 32-bit mask at width 64.
But changing `< RSZF_LIMIT` to `<= RSZF_LIMIT` survives it, as does wrapping the shift count modulo the width.
Both change integer results and fit the apparent zero-fill contract. Add only these two observable checks
to the existing test (both pass on base and head; the first kills `<=`, the second kills modulo counts):

```ruby
assert_equal 0, RQRCodeCore::QRUtil.rszf(1 << bits, 0)
assert_equal 0, RQRCodeCore::QRUtil.rszf(1, bits)
```

**R3 — must-fix, contribution changelog** (`CHANGELOG.md`, empty `[Unreleased]`).
The file says all notable changes are documented there; recent performance changes include entries.
Smallest fix: add `- Reduce allocations during QR code generation on 64-bit Ruby.` under `[Unreleased]`.
The target's README/AGENTS and community profile have no separate CONTRIBUTING document and no published
signed-commit requirement; do not manufacture a signing blocker. StandardRB is required and passes.
The rendering repository's additional rules (backwards compatibility, no gemspec edit, no new renderers) are
also respected; its semantic-commit convention is not a requirement imposed on this separate core repository.

**Correctness and callers.** When `0 <= n < 2**b` and integer `c <= b`, the right shift (or left shift for
negative `c`) fits in `b-c` bits; the mask cannot change it. When `c > b`, the shift is zero and the mask is
`-1`, so both formulas return zero. Other integers take the unchanged formula; negative widths admit no fast path.
This is an arithmetic argument, not a promise to preserve resource-exhaustion exceptions.

`probe.rb` compared the actual base method with the actual head method: 517,570 pairs at width 32;
514,966 each at widths 64, 0, -1 and 1; 522,778 at 16; 524,305 at 128 (3,624,517 total).
Includes signed 4,096-bit values, exact limit neighbors, shifts -80..100 and much larger positive shifts,
plus 100,000 seeded random pairs per width. `qr_probe.rb` compares version, full modules and `to_s` bytes:
164 cases per documented width (all four error levels, empty/numeric/alphanumeric/binary/Unicode/multi-segment,
versions 1/2/7/10/20/40 and seeded strings), identical under base/head and between widths; combined SHA256
`c60038c1314bb3b9752481fbbda1f69863f003cbc466f513e820db12390b1bd7` in each width.

Only five library call sites exist: core 2.1.0's bit-buffer
[`get`, `put`, `put_bit`](https://github.com/whomwah/rqrcode_core/blob/c13e78d43459a12a8bf211e969bc4296b480d7bc/lib/rqrcode_core/qrcode/qr_bit_buffer.rb#L16-L38),
QRCode [`map_data`](https://github.com/whomwah/rqrcode_core/blob/c13e78d43459a12a8bf211e969bc4296b480d7bc/lib/rqrcode_core/qrcode/qr_code.rb#L382), and QRUtil
[`get_bch_digit`](https://github.com/whomwah/rqrcode_core/blob/c13e78d43459a12a8bf211e969bc4296b480d7bc/lib/rqrcode_core/qrcode/qr_util.rb#L104-L109).
They derive Integer values/counts from bytes, sizes and bit indexes. A traced provisioning QR
made 25,186 calls, all Integer/Integer, largest number 36,864 and count 7. No new mutable argument/container,
callback, frozen-object operation, conversion or lazy-loading dependency was introduced on these paths.
Singleton/duck behavior outside them differs as above; Integer subclasses cannot normally be instantiated.
ENV is still read at require time, and changing it afterward does not change either loaded width.

Latest released core **2.1.0** is `c13e78d43459a12a8bf211e969bc4296b480d7bc`; its entire `lib/` equals current
main. Core 2.0.1 uses the same formula. **1.2.0 is different**: it derives width from `num.size` and uses `2**`,
so this is not a universal historical/backport claim. Released **rqrcode 3.2.0**
([constructor](https://github.com/whomwah/rqrcode/blob/f0d65004f2b5ba595fd47b36104fc1a549c07def/lib/rqrcode/qrcode/qrcode.rb#L14-L16))
and its main both delegate QR generation to core; there is no second rszf implementation in that gem.
`render_probe.rb` additionally compared text, SVG, ANSI and actual PNG bytes on 16 cases for each width and each
of rqrcode 3.2.0/main: base/head identical within all four cells. Main and release have different SVG namespace
output already, so their aggregate hashes differ; that existing difference is not caused by RQ1.
Renderer ownership is separate.

**Ownership.** Listed every core issue/PR (56 entries) and both repositories' open lists and searched closed
shift/allocation work. No core PR or issue is open. Rendering PR
[whomwah/rqrcode#170](https://github.com/whomwah/rqrcode/pull/170) only changes PNG painting, its spec and changelog;
it does not overlap. Read core #27/#28/#51 and #36, including #28's inline discussion about not forcing 32 bits.
RQ1 preserves that decision; merged #51 documents the opt-in but leaves the formula. `script/ownership RQ1`
also checked #28 cross-references and the trackers; its only hits are those closed/merged records.
`introduced_by` identifies the current fixed-width/env formula from #28, not the first ever allocation cost.

**Verification and maintainability.** Ruby 4.0.9 x86_64 Linux, no native 32-bit runtime or other Ruby tested.
`bundle exec rake test` and `RQRCODE_CORE_ARCH_BITS=32 bundle exec rake test`: head 103 runs / 2,855 assertions,
base 102 / 2,852, all zero failures/errors/skips. Existing frozen-literal warning on both.
`bundle exec standardrb --format progress`: 32 files, no offenses; `git diff --check` clean.
No added comments, helpers or dependencies. Cold read: return the shift for a nonnegative value strictly below
the width limit; otherwise apply the original mask. Both guards protect real integer semantics. L0: one local
fast return, no structural regression or useful simpler exact deletion of the fallback. `flog` 7.2 → 10.6;
RuboCop ABC 5 → 7.21, cyclomatic/perceived 1 → 3, explained by the one fast-return condition and its two checks.

Independent objects replay first tried the unchanged worker; its GC-disabled 1,000/2,000-call windows OOM-killed
the process (exit 137, 4 GiB orb). A bounded replay used the same worker and fixed heap with 300 warmups and
100/200-call windows: width 64 base/head/base = 45,452.99 / 6,054.99 / 45,452.99 objects, interpreter and YJIT;
width 32 = 6,054.99 in every cell. This corroborates the rounded body counts and unchanged width-32 case, not
the full original protocol or any CPU/time/JIT-flat claim. Original raw data remains under `body/RQ1`; this
review's scripts, integer/QR/mutant logs, metrics and bounded replay output are in the `evidence:` archive.
Missing evidence metadata was repaired here. New upstream head and confirm review are still required after R1–R3.
