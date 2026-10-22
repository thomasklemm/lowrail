# Default/bundled-gem census — bet V

2026-10-22. **No upstream PR opened.** One small ruby/time allocation
prototype is retained for the coordinator, with a resolved instruction-count
increase in an unchanged control explicitly preventing an unconditional
no-regression claim. No ordinary-request candidate qualified in this pass.
Lowrail runtime, app source and dependency locks are unchanged.

The coordinator opens any eventual PR in a separate medium orb thread,
after Thermos and independent semantic review. This thread does not waive
that process or the no-regression rule. The time patch is evidence, not an
approved PR. No upstream fork commit has been published for this held patch.

## Ranked investigation

Start point: [bet U's four-app, 12-route Rails-main census](https://github.com/thomasklemm/lowrail/blob/aeb6f064445db51d418ab22d3f7ef36579307898/docs/upstream/rails-main-census.md).
Its scores are sums of app means, **not removable objects/request**.
That census includes Rack mock-client work; the time investigation below
separates it from the actual server. No Lobsters tree was authored or changed.
Non-Rails third-party gems remain bet W's scope.

| Priority | Gem/site; census signal where available | Disposition |
| --- | --- | --- |
| 1 | URI `split_path`, score 760; userinfo/parser sites about 260 each | **Refused.** Fresh arrays/segments and trailing empty segments are required. Fresh userinfo pair returns and overridable parser/scheme dispatch are observable. Owner accepted the split-path refusal; not reopened. [#242](https://github.com/ruby/uri/pull/242) changes another merge loop. Unchanged suite: 93 tests / 3,039 assertions. |
| 2 | JSON parser result site 130.20 in one app; another version 61.93 in two apps; Coder output 39.67 | **No small exact elision established.** These sites include returned mutable graphs/strings, not merely wrappers. [#624](https://github.com/ruby/json/pull/624), [#673](https://github.com/ruby/json/pull/673), [#664](https://github.com/ruby/json/pull/664) already cover argument/parser/no-options allocations. Current generator options duplication was deliberately added by [strict options](https://github.com/ruby/json/commit/a8d7f6da6b67c6b378eab179753a6272cc47651c), with cross-engine consumers; not removed speculatively. |
| 3 | ERB escaping, ordinary rendering path | **Covered/no new measured patch.** No-escape early return and SIMD paths already upstream: [#87](https://github.com/ruby/erb/pull/87), [#151](https://github.com/ruby/erb/pull/151). Directly allocating the worst-case output buffer instead of the temporary would need capacity/shrinking and short-input performance work; not implemented or called a win. |
| 4 | CGI escaping, ordinary rendering/URL paths | **Overlap.** Open [#85](https://github.com/ruby/cgi/pull/85) owns the no-escape buffer optimization. [#110](https://github.com/ruby/cgi/pull/110) already fixes native escape aliases. No duplicate. |
| 5 | Base64 `strict_encode64`, score 32.67 across four apps | **No exact small elision established.** `[bin].pack("m0")` needs a result and dispatch Array; deleting the Array needs a different core API. URL-safe in-place translation already [#5](https://github.com/ruby/base64/pull/5). Skipping the decoder's copy can expose input/subclass `unpack1` overrides that currently run on a fresh core String. |
| 6 | SecureRandom byte result, score 20.67 across four apps | **Required output/ownership boundary.** Random bytes must remain fresh; no entropy reuse. Formatter/UUID methods moved to Ruby core in [#34](https://github.com/ruby/securerandom/pull/34); modern formatter changes are not owned by this gem. |
| 7 | Logger formatting | **No ordinary-path small patch found.** Fresh timestamp/formatted-message strings and live formatter dispatch remain. Missing-exception-backtrace allocations already removed by [#36](https://github.com/ruby/logger/pull/36). |
| 8 | Time RFC2822 repeated captures, much lower-ranked sites | **Held, parser-only.** Two objects saved with seconds, one without; full results below. Conditional GET only on measured server routes. Tiny resolved Ir control increase remains a caveat, not zero. |
| 9 | IPAddr compressed IPv6 segment concatenation | **Untried lead, not rejected or qualified.** Potential to reduce temporary arrays, but no ordinary-request frequency established in the inspected corpus ranking. No implementation/timing or PR claim. |
| 10 | Set / date | **Untried beyond ownership triage.** Modern Set implementation is core-owned; no counted default-gem allocation candidate identified here. No Date parser replacement implemented. |

Authoritative default-branch pins inspected:
[URI](https://github.com/ruby/uri/commit/0d5ee6fed7c85775b6e110c71bbc3db5e3e8c8c3),
[JSON](https://github.com/ruby/json/commit/c839870678fd7506eede270b24fbf3484053b361),
[ERB](https://github.com/ruby/erb/commit/34ce73a2b6d459721e50da489e108fbb761d6964),
[CGI](https://github.com/ruby/cgi/commit/46ea3512968dfe9686ffe4f20ea111ed148c997b),
[Base64](https://github.com/ruby/base64/commit/4d3c0be334d15e30250b98c0e5d258a5186b0130),
[SecureRandom](https://github.com/ruby/securerandom/commit/709f2500af356aecc107f3c92b5bbf5ba76ab3a5),
[Logger](https://github.com/ruby/logger/commit/c3ab8bce09eb074205aa2c4b2828d6804fc3bdd0),
[IPAddr](https://github.com/ruby/ipaddr/commit/5e66612f85a0f18202c2b7e3db0c0833b495285f).
Open and closed PR searches informed the dispositions above. These are
bounded search results, not proof that all possible algorithms are exhausted.

## Held ruby/time prototype

Base: [ruby/time master](https://github.com/ruby/time/commit/52e21ae8174dd29ba2aca0f23cc0b2516b9f0889),
unchanged on final fetch. [Exact patch](../../bench/upstream/time-rfc2822-captures.patch)
reads `$3` and `$6` once each instead of twice. Captured Strings are local
temporaries; no returned Time/input is cached or mutated. No grammar,
timezone, alias, regexp or method signature changes.

Base `lib/time.rb` SHA-256:
`50baad04e6bc544813fc1d503ae3decc73b6b7638c9d8944b6e007dda83a1c06`.
Candidate:
`f98dd53073a48ee63a1da153c5e4bb9147b3970f51df1a2b0bfbcfc98e7e33b4`.

### Duplicate and contribution-policy checks

All **82 PRs**, open and closed, were retrieved on 2026-10-22, with additional
`rfc2822`/`capture` searches. No covering change found. [#76](https://github.com/ruby/time/pull/76)
is documentation; [#66](https://github.com/ruby/time/pull/66) optimizes XML
parsing, not RFC2822. No CONTRIBUTING, AGENTS, AI/LLM policy or PR template
found in the gem or inherited ruby/.github community files. README welcomes
PRs and specifies `rake test`; the community profile reports no CONTRIBUTING
or PR template. This is a dated check, not a promise against future policy.

### Exactness and own-suite results

`bundle exec rake test`, unchanged tests:

| Source/runtime | Tests | Assertions | Failures/errors/omissions |
| --- | ---: | ---: | --- |
| Base, Ruby 4.0.7 | 53 | 915 | 0 / 0 / 0 |
| Candidate, Ruby 4.0.7 | 53 | 915 | 0 / 0 / 0 |
| Candidate, Ruby master interpreter | 53 | 915 | 0 / 0 / 0 |
| Candidate, Ruby master YJIT | 53 | 915 | 0 / 0 / 0 |
| Candidate, Ruby master ZJIT | 53 | 915 | 0 / 0 / 0 |

[Probe driver](../../bench/upstream/stdlib_time.rb): **2,160 identical
before/after snapshots on each Ruby version**. String and Time subclasses,
frozen/mutable input, UTF-8/US-ASCII/binary/ISO-8859-1/UTF-16LE, invalid bytes,
Unicode counterexamples, aliases, short-year 49/50 and 3-/4-digit boundaries,
missing seconds, asymmetric offsets, distinct mutable Time results, and
unchanged input bytes/encoding/frozen state. Additional independently
constructed UTC expectations check year completion, missing seconds and
offset arithmetic. Tests were not weakened or replaced.

### Finite native cohort: allocations primary

Pinned Ruby master [5f2bc22560e9063fb8dec736afbf378251cad3ec](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec),
4.1.0dev, x86_64 Linux, built with both JITs. Ten fresh-process rounds per
mode, seed 41231, serial shuffled off-A/off-B/on arms on CPU 2; 30,000 warm
calls, 10,000 GC-enabled allocation calls, 100,000 timed calls per case.
Process CPU time; paired-round median percentage changes, 5,000-resample
bootstrap nominal 95% intervals. No concurrent builds/tests during timing.
Every round retained; no retries. Native A/A interval gate is a preregistered
**±5% diagnostic**, not the ±0.1% Ir gate or a request-speed certificate.
All native controls passed it.

| Case | Objects/call, all modes | Interpreter CPU Δ% [95% CI] | YJIT CPU Δ% [95% CI] | ZJIT CPU Δ% [95% CI] |
| --- | --- | --- | --- | --- |
| HTTP-date | 16 → 14 | −2.343 [−2.999, −1.697] | −0.442 [−2.117, 0.510] | −3.508 [−4.492, −1.509] |
| RFC2822, numeric offset | 26 → 24 | −3.304 [−4.755, −1.608] | 0.043 [−1.326, 1.577] | −3.458 [−4.788, −2.087] |
| Short year, no seconds | 24 → 23 | −1.393 [−2.331, −0.542] | 0.267 [−0.884, 1.577] | −1.220 [−2.077, −0.546] |
| Obsolete HTTP-date control | 9 → 9 | −0.125 [−1.029, 0.693] | −0.379 [−1.107, 0.266] | 0.450 [−0.834, 1.052] |
| ISO control | 3 → 3 | 0.007 [−0.837, 1.853] | 0.087 [−2.889, 1.673] | 0.260 [−3.794, 1.299] |

The HTTP-date raw allocation count includes 0.0001/call observer overhead in
both arms. No resolved native CPU slowdown, but this does not prove
equivalence. JIT counters are retained: some ZJIT windows compiled and its
invalidation count is unavailable. **No JIT-flat speed certificate claimed.**

### Fixed-heap interpreter instructions

Ruby 4.0.7; pinned Valgrind 3.19.0/brk512. Existing `RequestPairs` /
`HeapWindows`, six serial shuffled off-A/off-B/on rounds, 100 warm calls/case,
N0/N500, alternating total/no-GC order. All five pool ranges and exact page
targets match, interpreter mode confirmed, no counted GC. Both A/A 95%
intervals lie wholly within ±0.1%, in aggregate and for each case. No zero-
containment requirement; no runs discarded.

| Case | Total Ir Δ% [95% CI] | No-GC Ir Δ% [95% CI] |
| --- | --- | --- |
| HTTP-date | −2.243 [−2.254, −2.240] | −2.245 [−2.253, −2.239] |
| No seconds | −0.964 [−0.971, −0.952] | −0.966 [−0.969, −0.946] |
| Unchanged obsolete-date control | **0.0247 [0.0225, 0.0291]** | **0.0268 [0.0227, 0.0291]** |
| Sum of one call to each of these three cases | −1.287 [−1.295, −1.281] | −1.289 [−1.293, −1.278] |

Aggregate objects for that three-call bundle: 50 → 47. Do not call this a
single parser call or a request. Ruby 4.0.7 HTTP-date costs 17 → 15 objects,
one more in both arms than the measured Ruby master; versions are not pooled.
Aggregate A/A total interval: [−0.00224%, 0.02466%]; no-GC
[−0.00224%, 0.02466%].

**Reservation:** the control increase is small but statistically resolved,
not zero and not erased by passing A/A. For round 0 no-GC, retained
Callgrind function totals locate 1,665 of 1,690 extra raw-window instructions
in glibc malloc/arena/unlink functions, while VM instruction-dispatch counts
match. Different earlier allocation history is a hypothesis, not a proven
cause or proof of a general regression's absence. Do not subtract it, rerun
until green, or treat this patch as satisfying an unconditional all-cases
no-regression rule. Coordinator decision required before an upstream PR handoff.

### Real request frequency: conditional GET only on measured server paths

[Untimed trace driver](../../bench/upstream/stdlib_time_calls.rb), Ruby 4.0.7,
Rails 8.1.4, retained blog and Campfire-r81 frozen bundles. Five warm then ten
requests per cell, genuine Campfire login outside tracing. Direct server
boundary covers `Rails.application.call`, body consumption and close;
separate cells deliberately include `Rack::MockResponse`. Counts are
method-entry counts, not time or measured request allocation savings.

`h/r` = `httpdate` / `rfc2822`; a delegated call appears in both counts,
so **do not add h+r as independent optimized parses**. `Time.parse` is zero
on every listed server route/variant. Campfire has two unaffected
`xmlschema` calls/request in all variants.

| Routes | Ordinary h/r | Stale If-Modified-Since h/r (status) | Future If-Modified-Since h/r (status) |
| --- | --- | --- | --- |
| Blog `/articles`, `/articles/1`, `/articles/1/edit` | 0 / 0 | 0 / 1 (200) | 0 / 1 (200) |
| Blog `/icon.svg` | 0 / 0 | 0 / 0 (200) | 0 / 0 (200) |
| Campfire `/rooms/486777696`, `/users/me/sidebar`, `/searches?q=coffee` | 0 / 0 | 0 / 1 (200) | 0 / 1 (200) |
| Campfire `/rooms/486777696/messages?before=2000060` | 0 / 0 | 4 / 6 (200) | 4 / 4 (304) |

Ordinary responses are 200. Single conditional calls come from
`Rack::ConditionalGet`; pagination also uses Rails freshness parsing.
Expected parser savings from counts: **zero** on ordinary server requests;
two objects on single-parse conditional requests; 12 on stale / 8 on fresh
pagination. These are count × parser-saving estimates, not request screens.
ETag/freshness paths without a date header did not call the affected parser.
Cookie expiry serialization is not parsing.

**MockResponse contamination:** mock-client response construction adds two
cookie-expiry `httpdate → rfc2822` calls per Campfire response, three on the
room route, including ordinary requests. These are harness work, not server
savings. The original census excluded direct mock file allocations but
still attributed nested cookie parsing to time.rb; those counts must not
be sold as ordinary request opportunities. Blog adds no such calls.
No equivalent frequency claim is made for Fizzy/CASA/CodeTriage/Lobsters.

## Evidence and reproduction

[Compressed receipt](stdlib-census.json.gz) retains all native worker data,
protocols, summary intervals, complete Ir windows/heap observations,
exactness snapshots/hashes, dated PR inventory, suite output and separated
call stacks. [Callgrind archive](stdlib-time-callgrind.tar.gz) retains the
actual counted dumps and Valgrind logs, including the control increase.
No cookies, credentials, database or authenticated scenario state is included.

Two early **untimed** request setup budgets remain recorded: the first
failed for missing storage-seed configuration; the configured budget still
failed exact header equality, including off-A/off-B. Background checks
passed. They are not accepted screens or a measured request result. No
counted request cohort followed; the owner explicitly chose parser scope.

Apply the patch to the base time checkout, save its clean source as BASE.rb,
then, from Lowrail:

```sh
TIME_SOURCE=/path/BASE.rb mise exec ruby@4.0.7 -- ruby bench/upstream/stdlib_time.rb probe
TIME_SOURCE=/path/time/lib/time.rb mise exec ruby@4.0.7 -- ruby bench/upstream/stdlib_time.rb probe
mise exec -- ruby bench/upstream/stdlib_time_study.rb native NEW_NATIVE_DIR \
  /path/BASE.rb /path/time/lib/time.rb /path/pinned-ruby/bin/ruby
PATH=/path/brk512/bin:$PATH CPATH=/path/brk512/include mise exec ruby@4.0.7 -- \
  ruby bench/upstream/stdlib_time_study.rb ir NEW_IR_DIR /path/BASE.rb /path/time/lib/time.rb
# In the time checkout, for each Ruby/mode (RUBYOPT selects JIT flags):
bundle exec rake test
```

Directories must be new: the study refuses replacement/retry output. Repeat
only as a newly disclosed independent study, never to replace these results.
No Lowrail lowering/support or request-level speed claim follows from this work.

Harness check: `LOWRAIL_STRICT_GATES=1 ruby bench/request_pairs_test.rb --seed=1729`
with the pinned Valgrind on PATH: **17 runs / 312 assertions / 0 failures /
0 errors / 0 skips**. All three new Ruby drivers pass `ruby -c`. Receipt
structure, cohort counts, probe equality, source/patch identity and archive
integrity were checked; no supplied token values occur in the receipt.
