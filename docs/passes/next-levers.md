# Next levers: price the hotspot, not its source share

2026-10-20. **Pricing only; no default promotion.** The request specimens use
the freshly built, opt-in config pass at
[`7947298`](https://github.com/thomasklemm/lowrail/commit/794729817a266b85ce94aa765dcf8108fd397521),
including its post-`initialize!` activation. These measurements do not certify
later runtime changes. The [hotspot addendum](hotspots.md) identifies owners;
it does not say their entire self share can be removed.

## One price table

Ir is client instructions, not latency. Request rows show
**off / default / default+inertia_config**. Micro rows show
**8.1.4 / upstream specimen**, averaged over the actual captured calls.
Negative deltas are improvements. Intervals are paired bootstrap 95% CIs,
not ratios of the displayed medians. Component extrapolations exclude
unimplemented guard/certificate costs and are **not measured request wins**.
Per-call micro prices include the same driver traversal on both arms; their
paired difference is the useful budget. Order is practical net opportunity:
upstream blank first, blocked sealed config research next, tag fusion last.

| Lever / workload / mode | Ir/request or Ir/call | Objects/request or objects/call | Incremental price / request implication |
|---|---:|---:|---|
| String blank, blog show, interpreter | 2,124 / 1,509 | 0 / 0 | 193 calls → **−118,626 Ir/request** [−118,626, −118,592] before a certificate; ≈1.36% of the interpreter show envelope |
| String blank, blog index, interpreter | 2,082 / 1,492 | 0 / 0 | 156 calls → −92,037 Ir/request [−92,037, −92,036] before a certificate |
| String blank, blog show, YJIT | 1,690 / 885 | 0 / 0 | 193 calls → −155,248 Ir/request [−155,440, −155,218]; accepted flat micro, not a request cohort |
| String blank, blog index, YJIT | 1,646 / 885 | 0 / 0 | 156 calls → −118,671 Ir/request [−118,827, −118,671]; accepted flat micro |
| Config bind, Starter JSON, interpreter | 5,124,960 / 5,123,938 / 4,768,652 | 1,238.64 / 1,238.51 / 1,216.18 | −6.928% [−6.968, −6.893] vs default; −6.947% [−7.003, −6.875] vs off; 11 hits/request |
| Config bind, Starter HTML, interpreter | 8,495,343 / 8,494,679 / 8,472,716 | 1,969.39 / 1,969.53 / 1,959.51 | −0.253% [−0.274, −0.246] vs default; −0.275% [−0.316, −0.254] vs off; 5 hits/request |
| Config bind, Starter JSON, YJIT | 3,270,221 / 3,270,710 / 3,804,167 | 1,242.62 / 1,242.63 / 1,219.43 | **+16.310%** [16.147, 16.403] vs default; +16.339% [16.179, 16.470] vs off; accepted flat windows |
| Config bind, Starter HTML, YJIT | 6,186,107 / 6,183,136 / 7,203,554 | 1,975.54 / 1,975.65 / 1,964.14 | **+16.509%** [16.479, 16.545] vs default; +16.459% [16.386, 16.515] vs off; accepted flat windows |
| Tag options, blog show, interpreter | 31,510 / 32,655 | 5.528 / 1.361 | 36 calls → **+41,521 Ir** [40,377, 42,071], −150 objects/request; ≈+0.47% before guards |
| Tag options, blog index, interpreter | 28,100 / 29,003 | 5.027 / 1.270 | 37 calls → +34,495 Ir [32,791, 34,868], −139 objects/request |
| Tag options, blog show, YJIT | 19,081 / 19,721 | 5.528 / 1.361 | 36 calls → +23,098 Ir [22,750, 23,409], −150 objects/request |
| Tag options, blog index, YJIT | 16,968 / 17,475 | 5.027 / 1.270 | 37 calls → +18,793 Ir [18,485, 19,143], −139 objects/request |
| Tag option alone, blog show, interpreter | 8,674 / 9,668 | 1.600 / 1.021 | 95 calls → +94,390 Ir [94,351, 94,643], −55 objects/request; overlaps options |
| Tag option alone, blog index, interpreter | 8,694 / 9,634 | 1.609 / 1.012 | 87 calls → +81,750 Ir [78,395, 85,219], −52 objects/request; overlaps options |
| Tag option alone, blog show, YJIT | 5,112 / 5,195 | 1.600 / 1.021 | 95 calls → +7,820 Ir [7,562, 7,999], −55 objects/request; overlaps options |
| Tag option alone, blog index, YJIT | 5,134 / 5,233 | 1.609 / 1.011 | 87 calls → +8,650 Ir [8,449, 8,787], −52 objects/request; overlaps options |

All four request cohorts and both corrected micro cohorts pass total/no-GC
A/A, all five heaps, brk, actual mode, and every per-operation control.
Both corrected YJIT micros and both YJIT request cohorts pass **every** flat
window. The leaf rows overlap `tag_options`: never add them. Show's percentage
extrapolations use the accepted hotspot off baseline **8,745,964 Ir** and the
same lock hash; no YJIT request percentage is invented from that interpreter
denominator. Lower allocations may help a production GC workload, but that
is unpriced here; do not turn an accepted instruction loss into a speed win.

## What config binding actually removes

The old constructor builds a keyword Hash, walks every `OPTION_NAMES` entry
with `extract!`, deletes present keys into a new result Hash and checks that
the remainder has no unknown keys. The pass recognizes the canonical ordered
schema, allocates a fresh Configuration and shallow-copies its current options.
It does not freeze values, cache controller-bound configurations or evaluate
configuration Procs early.

An independent untimed census sees **11 JSON / 5 HTML bindings**, all with the
canonical 24-key schema; their **11 / 5 `extract!` invocations disappear**,
with zero fallback or warm guard revalidation. This is not “only some extract
calls optimized.” What remains is the required fresh object/storage and live
option values, plus Lowrail's class/constant/schema/default-policy checks and
reflection/dispatch. Unrelated extraction, option evaluation and request work
remain unchanged. The 11.60% self share includes work now replaced by copying
and checking; the 15.05% inclusive binding envelope includes required work.
Neither is a net removable budget. No instruction-level decomposition of
that difference is claimed. In particular, the accepted YJIT loss cannot be
explained away by instruction collection during compilation: every measured
window is flat. Its internal cause was not separately isolated.

Read-only upstream inspection on 2026-10-20: [inertia-rails#437](https://github.com/inertiajs/inertia-rails/pull/437)
is **open, not merged**. The latest release is
[v3.23.0](https://github.com/inertiajs/inertia-rails/releases/tag/v3.23.0)
(2026-10-16), whose constructor/binder still extract options. No released
version contains this PR's fix. The PR proposes `dup` plus `initialize_dup`,
not this Lowrail guard. The existing pass audits exactly 3.21.2, 3.22.0 and
3.23.0 and exact source hashes. A future fixed version, an unknown version or
changed sources must refuse, not stack an unnecessary replacement on the fix.
No PR, comment or other upstream write was made for this study.

### Promotion is blocked, not merely awaiting a default flag

The ordinary five-app `default,+inertia_config` verification has identical
per-test outcomes and own-thread SQL: blog **21 / 125 queries**, Campfire
**634 (2 skips) / 15,109**, PingCRM **26 / 809**, Redprints **50 / 692** plus
system **12 / 260**, Starter **36 / 264**. Config hits are respectively
**0, 0, 218, 36 + 216, 44**, with zero config fallbacks. Other-thread SQL
differences remain advisory (Campfire 1, PingCRM 9). The first Redprints
browser setup lacked Chrome; its symmetric failures are not a passing gate;
the correctly configured real-browser run supplies the 12-test result.

Blog and Campfire refuse `gem_absent`: no config unit, no installer, no wrapper
and no per-request config guard. Its runtime cost there is structurally zero,
not a tiny no-op wrapper. That is not a fresh route benchmark on those apps.
The builds' default set remains empty. These outcome/SQL results do not
override Redprints' separately documented strict loader incompatibility in
[compat.md](../compat.md#still-refused-require-hooksbootsnap-load-behavior).

A warmed suppressed-hook probe defeats config's method facts: suppress
`Hash.method_added`, replace `Hash#extract!`, and the original binder returns
the replacement's version while the fast path returns the old value. The
state stays true and no fallback occurs. This is the same quarantine class
as `link_to`, not permission to promote after ordinary app tests pass.
Config is the **second sealed candidate after link_to**, coordinated with
the generic sealed registry owner; it is not a newly exact guarded pass.
Even without that bug, the accepted YJIT regressions fail the promotion rule.

## Tag component: exactness needs a boundary, not a copied method

The isolated upstream body is Rails
[`49580d1d`](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b),
not a locally invented appender. Its appenders and returning compatibility
wrappers live only in disposable TagBuilder subclasses. Every actual show
and index input agrees on bytes, class, encoding, frozen status and HTML
safety. Actual counts are **36/95 show**, **37/87 index** for options/leaves;
the older [tag survey](tag-options.md)'s 30/69 index counts describe a different
fixture. This census uses the hotspot lock hash, not that older fixture.

**Do not install main wholesale on 8.1.4.** It also expands generic nested
Hash prefixes, a behavior change from 8.1.4's data/aria-only expansion. The
observed input set does not exercise that disagreement. A compatible component
must retain 8.1.4 semantics or restrict/refuse that shape, not label the entire
main implementation an exact backport.

For a **sealed** component, SEAL001 forbids changing certified methods and
visibility, SEAL005 covers live configuration assumptions, SEAL008 the mutable
tag/framework tables, and SEAL009 delivery observations. None proves the
actual receiver or value's provenance. The certificate still needs the exact
TagBuilder/view/escaping/token/JSON methods, native key/value operations,
supported version/source hashes and tables, ordinary eligible container/value
shapes, no hidden singleton/refinement dispatch, original key/order/conversion
and exception behavior, and fresh mutable buffers with correct safety/encoding.
Values, CSRF, form/model state, I18n and configuration Procs stay live. Arbitrary
`to_s`/`to_json`/token callbacks can mutate the next dependency mid-call; a
contract covering those calls or a conservative refusal remains necessary.

For a **guarded** component, cached method-added hooks are insufficient. Check
effective actual-receiver method/visibility/primitive/table facts at every
boundary after arbitrary conversion/app code, and resume a once-only local
continuation on failure. An entry check cannot certify later `safe_join`,
escaping or JSON dispatch. Price those complete checks before implementation.
Both tiers require the Rails 8.1.4 tag/form helper files as an **L4 installed
replacement gate**, plus corpus response/ordered-SQL/form-state/encoding gates.
This study installs no replacement and claims no L4 pass.

## Who calls String#blank?

Blog show makes **193 calls/request**: XML attribute-name escaping **95**,
outer tag keys **44** plus **1** nested key, `content_tag_string` **13**, and
**40** elsewhere. The last group is form names/IDs/labels **10**, route
formatting **6**, CSRF action normalization **4**, capture/content-for **3**,
translation **4**, asset helpers **4**, SQL sanitization **2**, cookies **4**,
and logging/strong-parameters/Turbo **1 each**. Receivers are **184 String /
9 SafeBuffer**; **189** start with printable ASCII, **2** start with whitespace,
**2** are empty. Index has **156** calls. The sanitized census records every
caller; actual strings, CSRF values and authenticated headers remain private.

ActiveSupport is in the Rails repository: there is not a second, faster
independent “ActiveSupport main.” The specimen is main at
[`3f0b6751`](https://github.com/rails/rails/commit/3f0b675158e8284241bb1213c00375bc1fb9c52f), including
[`7234e94d`](https://github.com/rails/rails/commit/7234e94d0b007055126a3fd55115db8e3beb8568)
and [`7ef6a408`](https://github.com/rails/rails/commit/7ef6a40816e3765e20e5ee8c5c1d586983935da4)
use an ASCII printable-first-byte exit / whitespace byte loop, keeping the
existing regexp and per-encoding fallback for non-ASCII strings. The specimen
matches actual captured results and **24,568** single-byte/whitespace/Unicode/
encoding/error boundary cases. That is finite semantic evidence, not proof
against arbitrary String subclass overrides or tracing. A Lowrail replacement
would additionally certify `empty?`, `ascii_only?`, `getbyte`, regexp and
encoding-map behavior, including callbacks and observational boundaries.

### Sealed candidate #3, not a guardless backport

The [design/fuzzer follow-up](string-blank.md) stops a guardless guarded-tier
backport: 236,416 ordinary cases per Ruby target and Rails' 433 assertions
agree, yet subclass primitive overrides, constant replacement and regexp
observation differ. Normal VM dispatch correctly handles a later `blank?`
redefinition; that one fact does not close the rest of the certificate.

Owner decision: **third sealed candidate**, after link_to and config bind,
with a micro budget of **−118,626 interpreter / −155,248 YJIT Ir** on show,
zero objects (roughly 1.4% of the interpreter request, not a measured sealed
request win). SEAL001 covers post-seal method/visibility/refinement changes;
SEAL001/008 cover rebinding `BLANK_RE` and mutation of the encoding map, whose
legitimate cache population needs an explicit live-policy boundary. SEAL009
must accept edited ISeq/trace observations. Existing overrides are **not**
excused as post-seal mutations: certify seal-time native String/Regexp/Integer
dependencies and enumerate String subclasses with effective method owners
for `ascii_only?`, `getbyte`, `match?` and `empty?`; refuse if overridden.
Also inventory already-existing String-instance singleton overrides: a
subclass-only scan misses those. No eigenclass creation is needed to inspect
an existing effective method through captured native reflection. New unknown
receivers must stay original unless the contract/certificate covers them.

Build only **after** the central production TracePoint fix, the six additional
sealed-only quarantines, and the sealed owner's published generic eligibility
boundary. Reuse that tier/manifest mechanism; do not invent a third delivery
path or a test-certificate override. Complete seal-time/actual-input refusal,
installed framework and app/compat gates precede fresh finite show request
cohorts. No runtime implementation or default change is in this design step.

## Protocol, invalid attempt, and retained evidence

The [numeric export](next-levers-results.json) carries all finite verdicts,
per-round scalar prices, paired CIs, actual JIT state, source/build/lock
fingerprints and per-operation controls. Its `method_sources` includes the
exact census, request driver, corrected specimen and micro driver as text;
extract these into `/tmp/next-levers/` to reproduce, then fetch the two pinned
Rails source files and run the private census against the prepared production
blog before the micro driver. The files' hashes are retained in `sources`.
Saved config/default builds are separate per VM mode; never reuse test builds
or turn on counters in timed requests. Pinned Valgrind is rebuilt with
`bash script/bench-valgrind /tmp/vg` from the unchanged
[`d7d62ba`](https://github.com/thomasklemm/lowrail/commit/d7d62ba)
script; use `PATH=/tmp/vg/bin:$PATH CPATH=/tmp/vg/include` and
`ulimit -d unlimited`. The shared
[`c9d2397`](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0)
protocol supplies six randomized fresh rounds, seed 41231, fixed five pool
floors, N=0 subtraction, total/no-GC windows, enabled GC, A/A ±0.5% with zero
inside each interval, actual capacity matching and overflow refusal. No more
than four Callgrind workers ran concurrently. Requests use N=50; micros use
N=1,000 repetitions of a captured whole-request call bundle. Allocation price
subtracts the N=0 total window. YJIT must pass every warm/measured window.

The **first interpreter tag/blank attempt is invalid in its entirety**.
Extracting method bodies into eval lost `frozen_string_literal: true`; it
therefore priced allocated literal strings instead of upstream code. The
blank specimen also used `UnboundMethod#bind_call`, adding **three objects
per blank call** absent from real dispatch. Some A/A controls failed too.
No arm, favorable result or request extrapolation is salvaged. The owner
explicitly authorized **one corrected cohort per mode**, not retry-until-green.
The correction uses frozen-source eval and direct dispatch on String
subclasses with old/main bodies. Before either cohort starts, an unchanged
8.1.4 specimen must match the real method's objects/call exactly: show bundle
options/leaves/blank **199/152/0**, index **186/140/0**, in both modes. Every
worker repeats that refusal check and compares actual outputs. Observer-loop
warmup removes its one-time allocation; the equality threshold was not widened.

## Recommendation

1. **Prefer the upstream blank implementation when a suitable Rails release
   contains it.** It wins both modes on actual inputs, without adding a
   Lowrail guard. The interpreter show opportunity is about 1.36% before a
   hypothetical Lowrail certificate, not the entire 2.88% self share. Keep
   the guarded Lowrail budget at zero until the full certificate is priced;
   the guardless design is refused. Candidate #3 may proceed only under the
   sealed prerequisites and seal-time override refusals above.
2. **Config bind is the second sealed candidate, but hold promotion and
   deployment.** Its measured interpreter benefit already includes the
   existing checks; the missing suppressed-hook certificate would add cost
   or require SEAL001. Its accepted +16.3/+16.5% YJIT request losses are a
   separate stop. Reuse the generic sealed path and require fresh correctness
   and guard-included JIT-aware pricing for any changed implementation.
   Do not retry these unchanged cohorts or treat the old 0.5–2.8% estimate
   as a cap: this actual JSON workload is larger, but not currently safe.
3. **Do not build a tag component now.** The upstream body reduces objects
   substantially, yet loses Ir in both modes before any certificate. Any
   positive guard cost worsens that price. This is stronger evidence to
   keep it parked than the old percentage estimate. A future upstream release
   or allocation/GC-motivated component can be evaluated on its own merits;
   the existing upstream code/tests make L4 cheap, not exactness free.

Thus **no guarded/default Lowrail request saving is credited** from this
study. The ranking is expected usable saving after checking costs, not an
additive 11.60% + 7.06% + 2.88% opportunity or a traffic-weighted speed claim.

Outside these levers, blog show's **ETag digest 4.83%**, **HMAC 2.26%** and
cookie/signature/crypto work remain live. These are current response bytes,
keys, sessions and request/security policy, not boot-fixed computations.
Recommend app-level conditional GET/ETag policy and payload/cookie size review,
or upstream digest/cookie implementation improvements with security and HTTP
tests. Do not disable validation/encryption, cache digests across changing
bodies/keys, elide middleware or claim those percentages as Lowrail savings.
