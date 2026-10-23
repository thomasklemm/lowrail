# M0 — Private Rails app with Inertia Rails

An internal B2B operations/monitoring app with authenticated Inertia (React)
pages, dashboards/analytics views, background jobs and mail. No product,
customer or data details are included.

This anonymized historical study was measured on 2026-10-19 and 2026-10-20
in its own orb. No application source is checked in here. Application names,
dependency inventories, domain-specific page names and structural/test
counts are omitted; the aggregate engineering findings are retained.

**Historical evidence, not current admission.** These experiments predate
the stricter guard audit. Guarded digest artifacts are now refused; see
[the digest pass's current status](../passes/digest-memo.md) and
[the suppressed-hooks audit](../passes/suppressed-hooks.md). The timing
observations below are exploratory, not accepted current benchmark prices.

## Baseline: where time goes

The baseline ran without Lowrail. Wall profiling with YJIT found database
execution at **24% self**, GC at approximately **8%**, Active Record's Ruby
side at **18%**, and application/library code at **3.6%**. In authenticated
JSON requests, native digest update accounted for **12.8% self**: an
asset-version callback recomputed a file digest on every request.

Eager loading alone missed many framework-generated methods. Loading schema
and defining attribute methods exposed substantially more of the method
table. This motivated the facts dumper's schema/attribute-method capture.

### Conclusions for Lowrail

1. Data access dominates; lowering cannot remove SQL. Active Record
   attribute/type/reflection dispatch is the framework target, consistent
   with uncached Campfire measurements.
2. Repeated work on fixed inputs is a candidate, not an automatic memo:
   asset contents must be proved equal before reusing a digest. Arbitrary
   version callbacks are not assumed pure, and files can change mid-process.
3. Serialization plans from fixed descriptors are a later candidate;
   values and partial/deferred-property semantics stay dynamic.
4. Stubs, singleton-method replacement and time travel are equivalence
   risks. Guards must account for lookup, singleton, ancestor, schema and
   configuration changes; a successful boot check alone is insufficient.

## First Lowrail iteration (2026-10-20)

The checkout was unchanged. Runtime integration used only
`RUBYOPT=-I<lowrail>/gem/lib -rlowrail/setup`; the application's Gemfile and
lockfile were unchanged. No application source, class/file/test names,
payloads or credentials are included here.

### Build and differential gates

Facts capture completed without errors, explicitly skipping an absent
cache table. The build lowered eligible route sites in Ruby and templates.
Options hashes, explicit receivers, direct/resolve helpers, route
requirements/globs and class/module-body calls were refused deliberately.
There were no eligible `link_to` sites. The known-regressing preload pass
was not enabled.

The initial unit/request verification was identical but vacuous: **zero
guard hits**, with every attempted fast path falling back. An unrelated
mounted engine's singleton script-name method disabled every unit through
a global route-set fact. The fix leaves script-name resolution and URL
finishing dynamic, after argument conversion and path formatting, rather
than disabling the guard or caching engine state. Public emitted-Ruby
fixtures cover path and URL helpers, defaults, URL-option mutation and
observable evaluation order.

Final unit/request and browser suites ran sequentially with external
recording disabled, fixed seeds and `lowrail verify APP --bisect -- …`.
Every test identity/outcome matched its fresh off control, including the
same skip. Both suites exercised route fast paths with **zero guard
fallbacks**. There were no outcome differences to bisect and no denylist.
Suite durations are not performance benchmarks: parallel scheduling and
browser load differ. These counters record guard acceptance/rejection;
inner runtime-condition fallbacks were not counted separately by that
emitter. Some unreachable redirect paths remained unexercised, not stuck
behind failed guards.

Generic fixes were published as
[`9fa9bd1`](https://github.com/thomasklemm/lowrail/commit/9fa9bd13313ad0314f606d37e221b66616751b8f)
(dynamic route finishing) and
[`698f738`](https://github.com/thomasklemm/lowrail/commit/698f738c7279494ac929a78a15ec04213b57bbcc)
(template source classification for types). Local Rust/gem checks passed
with explicit optional-dependency/corpus skips; that is not full corpus
coverage.

### Types and MCP

`lowrail types APP` succeeded, but only **about 20.7%** of signatures had
non-`untyped` returns: emitting signatures is not precise inference of all
methods. The first run misclassified raw template sources as invalid Ruby.
The generic fix excludes known template locations from the Ruby-body
walker; a public fixture retains a genuine malformed-Ruby negative control.
Template return inference remains unsupported, not fabricated.

The stdio MCP smoke initialized, listed six tools and answered `type_of`
and `diagnostics` without protocol/tool errors. Final source diagnostics
were zero.

### Interleaved request and boot measurements

Five fresh-process off/on pairs alternated order with YJIT enabled. Three
authenticated JSON pages, labeled A/B/C to avoid domain details, each got
100 warmups and 200 measured requests per process. Authentication, frozen
time, fixtures, matching version headers and query-cache clearing reproduced
the baseline recipe. Every response had the expected component and status.
Stats and profiling were off; off loaded setup but set `LOWRAIL=0`.

Numbers are medians of five process medians; parentheses give their min–max,
**not confidence intervals** or a production-load simulation.

| Page | Off, ms | On, ms | Median change |
|---|---:|---:|---:|
| A | 17.650 (16.658–19.248) | 17.712 (17.543–18.796) | +0.35% |
| B | 8.111 (7.952–8.373) | 8.416 (7.988–8.990) | +3.76% |
| C | 6.448 (5.933–6.575) | 6.555 (6.365–6.868) | +1.67% |

All differences are **within observed run-to-run noise**, not demonstrated
speedups or slowdowns. Request allocations were unchanged to rounding and
SQL counts were unchanged. A separate stats run confirmed **zero reached
route units** on these pages despite delivered lowered files: suite hits
do not imply request coverage.

Five alternating fresh-process eager-boot pairs with YJIT and no stats gave
**2.89 s off (2.68–3.27) vs 2.95 s on (2.84–3.35)**, +2.1%, also within
noise. Unlike request controls, boot-off had no Lowrail setup in `RUBYOPT`.
This was warm-filesystem startup, not cold OS-cache boot.

### Profile and next candidates

A separate on/profile run used 200 requests per page after 100 warmups,
StackProf wall at 1 ms. Inclusive areas count each sample once even when
a frame recurs; categories overlap and must not be added. SQL execution
alone was **30.5% self**, not removable by Ruby lowering.

1. **Asset-version digest:** digest update **15.8% self**, manifest digest
   **17.3% inclusive**. Page-level digest self shares were
   **9.6% / 21.7% / 27.2%**, versus 12.8% combined in the older baseline.
2. **Query-shape/Arel planning:** `build_arel` and visitors
   **5.4% inclusive, 1.5% self**. Keep binds, scopes, rows and execution live.
3. **Attribute/type dispatch:** **2.7% inclusive, 0.84% self**. A descriptor
   plan must not cache values, time-zone results or custom conversion effects.

Serializer code was only **0.84% inclusive / 0.11% self**. Property/render
traversal was **30.2% inclusive but 0.40% self**: it includes dynamic values
and SQL, not removable planning overhead. None of these shares promises a
speedup.

### Exactness and cost of the digest guard

A standalone YJIT microbenchmark used five alternating rounds, 100 warmups
and 2,000 calls per alternative on one asset manifest. Every warmup result
equaled the original digest. Values are µs/call, median and min–max round
means, not request-level gains:

| Operation | Time, µs | Objects/call |
|---|---:|---:|
| Original file MD5 + hex | 278.89 (274.75–298.56) | 8 |
| `stat` tuple + cached digest duplicate | 3.53 (1.64–5.26) | 5 |
| Read bytes, exact compare + cached digest duplicate | 84.67 (67.38–108.13) | 3 |

A device/inode/size/mtime/ctime tuple is cheap but **not an exact content
proof**. Byte equality retains a full read and transient file-sized string,
saving about 194 µs per digest in this microbenchmark only. Returning a
duplicate preserves mutability. A pass also needs method/path guards,
fallback on changes/errors and an explicit concurrent-file-change contract.
No digest pass was enabled in this first iteration.

## Second iteration: exact digest memo (2026-10-20, historical)

The then-opt-in `--passes default,+digest_memo` added one gem digest site.
Existing route refusals remained visible. Integration still used only
`RUBYOPT`, without Gemfile/lockfile changes; `memo` and `preload_plans` were
not selected. **That guarded build command is now refused**, as noted above.

Every invocation fully rereads the bytes. Only exact byte equality can save
hashing: no stat-only proof, arbitrary version-proc memo or second open
after comparison. Original errors and globs remain live. The
[pass note](../passes/digest-memo.md) defines stream semantics for rename,
overwrite and removal between reads. Its public fixture verified **7/7
identical outcomes, 71 assertions/mode, 65 hits, zero fallbacks**, including
composition with `memo`; arbitrary lazy callbacks remained refused by the
memo purity check.

### Differential gates and SQL-trace limitation

Unit/request and browser suites again ran sequentially on the same checkout
with fixed seed and `--bisect`. Every test identity/outcome matched, with
the same skip, nonzero route/digest hits, zero guard fallbacks and no new
denylist. Suite runtimes are not speed evidence. Local Rust/gem checks
passed with named optional-dependency/corpus skips. The built/unpacked gem
also passed the public fixture with 65 hits and zero fallbacks, checking
that the runtime came from the package.

**Full SQL identity is not claimed.** The additional advisory tracer found
differences, including in serial controls with **all units disabled**, zero
hits and identical test outcomes. Those serial verification commands exited
1. One confirmed cause was small sequence IDs in SQL literals: the tracer
normalized only six-digit numbers, and database sequences are not reset by
test rollbacks. This does not explain every warning. The tracer was not
disabled and broader number masking was not introduced.

### Five interleaved YJIT pairs

Ten fresh processes alternated off/on order using the same three pages,
100 warmups and 200 measured requests per page, frozen time and cleared
query caches. Responses were checked for status/component/version; stats
and profiling were off. Both modes loaded setup; off used `LOWRAIL=0`.
Again these are five process medians and their min–max, **not confidence
intervals or production-load measurements**.

| Page | Off, ms (min–max) | On, ms (min–max) | Median change |
|---|---:|---:|---:|
| A | 19.064 (18.169–21.568) | 17.905 (17.004–20.157) | −6.1% |
| B | 8.793 (8.395–10.284) | 7.640 (7.388–9.550) | −13.1% |
| C | 7.096 (6.775–7.421) | 6.082 (5.704–6.739) | **−14.3%** |

Page C's ranges were narrowly separated and all five pairs improved
(−5.0 to −19.0%). A/B had overlapping ranges and some slower on pairs:
their median changes are **not clearly separated from noise**. Better
medians did not guarantee better tails: p95 ranges off/on were
A **27.26–30.85 / 19.99–31.38 ms**, B **10.81–12.57 / 12.11–15.72 ms**,
C **8.17–9.80 / 8.63–13.62 ms**.

Allocations consistently rose by approximately **21 objects/request**.
SQL counts were unchanged; the newer count excluded schema/transaction
events and cache hits, so it is not directly comparable with older absolute
counts. A separate stats run recorded **6,300 actual digest reuses**, seven
per request over 900 requests including warmups, **zero route hits and zero
fallbacks**. The request observations were not inferred merely from suite hits.

### Costs and remaining candidates

Five alternating same-process YJIT micro rounds, 100 warmups and 2,000 calls
per alternative, on the same manifest (median/min–max round means):

| Operation | µs/call | Objects/call |
|---|---:|---:|
| Original file MD5 with Pathname | 298.40 (297.34–312.24) | 10 |
| Final guard + chunk read + byte memo | **129.81 (97.47–176.06)** | 13 |

The full pass cost more than the unguarded `binread` prototype's 84.67 µs:
guards, equivalent chunk/stream semantics, path checks and content indexing
are included. The 3.53 µs stat-only alternative remained **inexact** and was
not implemented.

A separate on/StackProf wall run (1 ms, 200 requests/page after 100 warmups)
found **zero native digest-update self samples**, versus 15.8% in the prior
cohort. Manifest/memo read/compare remained **6.48% inclusive**; SQL execution
was **33.90% self**, not eliminated by this pass. Remaining candidates:

1. **Arel/query planning:** **6.08% inclusive, 1.64% self**, not implemented.
2. **Attribute/type dispatch:** **4.34% inclusive, 2.00% self**; values and
   user conversions were not memoized.
3. **Exact-byte content index:** `String#hash` **2.48% self**, reads
   **1.10% self**. A cheaper index still needs full byte equality, not stat
   substitution.

Limits remain: more transient allocations, full file IO, bounded cache,
call-site guard gaps and no cold-cache or concurrent-production-load claim.
Temporary private integration/harness changes were removed; no application
changes were committed or transferred into Lowrail. See the current-status
warning above rather than treating this historical experiment as admission.
