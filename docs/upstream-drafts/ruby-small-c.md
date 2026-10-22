# Small Ruby C improvements: owner-review drafts

2026-10-22. This follow-up uses the owner's revised rule: a small library win
is useful even if it cannot produce a large Lowrail request win. **Nothing
here has been submitted upstream.** The large-win verdict in the
[original scout](../ruby-internals-scout.md) is unchanged.

## Ranked readout — no qualifying upstream PR

**Neither prototype passes the owner's no-regression rule. Do not submit
either draft upstream.** Both are correct on the relevant suites, but a
safe-input allocation saving does not excuse slower escaping, and faster
subclass initialization does not excuse slower control cases. Two versions
of each candidate were screened; stop here rather than tuning until a
favorable interval appears. The candidates are independent; neither depends
on method tokens, a new Lowrail API, GC tuning, or the other patch.

| Rank | Candidate | Request relevance | Decision |
|---|---|---|---|
| 1 | `CGI.escapeHTML`: avoid the scratch allocation/copy when no byte needs escaping | **0 calls** on all three measured request paths. A small library candidate, **not a Rails request speedup** | **Rejected.** Long safe inputs save one temporary object. V1 regresses early escaping on master; V2 still regresses dense escaping **+15.84% interpreter / +15.88% YJIT** |
| 2 | `String#initialize`: fast-path zero arguments or one positional argument without keywords | `rb_str_init` self is 0.06% / 0.03% / no sampled self time in blog/Fizzy/Lobsters YJIT profiles. SafeBuffer construction is one caller | **Rejected.** No allocation saving. V1 YJIT no-arg **+2.88%**; V2 no-arg **+2.56% interpreter / +4.29% YJIT**, YJIT short subclass **+3.13%** |
| Rails handoff | `String#blank?`, XML names and tag validation | Blog 196 `blank?` calls / 194 actual regexp matches; **0 allocated objects**. XML 95 checks / 55 Symbol conversions; tag validation 26 checks | Route to Rails; not a new CRuby boolean-regexp primitive |
| Screened out | ERB escaping | The original `optimized_escape_html` self samples are ERB, **not CGI**: 0.17% / 0.24% / 0.07% on B/F/L | ERB already allocates lazily; current master also has vectorized search. Do not transplant an optimization it already has |
| Screened out | Regexp match setup / frozen strings | `match_at` 2.87% / 2.81% / 1.80%; preparation 0.51% / 0.52% / 0.30%. Boolean matches allocate no MatchData in this workload | No proven redundant allocation/copy. Encoding validity, backrefs, mutation and timeouts prohibit a naive cached answer or skipped setup |
| Screened out | Hash/options, Time/Marshal, shapes, barriers | Hash work is distributed; Lobsters `time_load` self 0.04%; shapes have zero complex AR objects or warm transitions | No small exact hot-path change established. Allocator/mark/sweep/barrier findings stay with bet J |

## Attribution: who actually calls CGI?

The `cgi` mode of `bench/experiments/ruby_internals_scout.rb` runs **untimed**
after 100 warm requests. It prepends the three CGI HTML-escape names to record
callers and input **lengths/encodings only**, and independently counts native
`CGI::EscapeExt#escapeHTML` entries with TracePoint. Ten more real requests
return HTTP 200 for each app. Each worker then counts two explicit positive
controls (safe and escaping 200-byte inputs); all controls report two entries.

| App / route | Rack | CGI entries / 10 requests | Typical observed CGI input length |
|---|---|---:|---|
| Blog `/articles/1` | 3.2.7 | 0 | None observed |
| Fizzy `/buckets` | 3.2.7 | 0 | None observed |
| Lobsters `/s/enr7ye` | 2.2.24 | 0 | None observed |

There is no CGI call-site or typical length distribution to claim on these
requests. This is not a claim that every route/error path in these apps is
CGI-free. The microbench's 13-byte attribute-like string and 2048-byte safe
text are **synthetic library inputs**, not a measured Rails CGI distribution.

The installed source resolves the likely callers:

* Rails 8.1.4 ActiveSupport's `CoreExt::ERBUtil` calls `super` into ERB's native
  escape implementation for unsafe strings, not CGI.
* Rack 3.2.7 `lib/rack/utils.rb:242–254` uses
  `define_method(:escape_html, ERB::Escape.instance_method(:html_escape))`
  when modern ERB is present, as it is here. `CGI.escapeHTML(string.to_s)`
  exists only in its compatibility fallback. Rack's directory/error/status
  pages calling `Rack::Utils.escape_html` do not change this choice.
* Rack 2.2.24 `lib/rack/utils.rb:185–187` uses its own `gsub` table, escaping
  apostrophes/slashes differently; it does not delegate to CGI.
* ERB's C wrapper can delegate to CGI for **ASCII-incompatible encodings**.
  That is a real potential library caller, but none was observed here, and
  those inputs take CGI's unchanged Ruby fallback rather than this C fast path.

`perf report --stdio --no-children -g none -s dso,symbol -v` disambiguates the
otherwise identical static function names by full shared-object path: blog
and Lobsters use erb-6.0.7's `lib/erb/escape.so`, Fizzy the installed core
`erb/escape.so`. No named sample is attributed to `cgi/escape.so`.

## Protocol and evidence

`bench/experiments/ruby_c_micro_screen.rb` uses fresh processes, normal GC,
50,000 warmup calls, paired ABBA/BAAB rounds, and both interpreter and YJIT.
Full screens have 16 rounds; CGI V2's decisive three-case kill screen has
eight. CPU and wall clocks bracket only the call loop; allocation counters
are outside that interval. Confidence intervals are paired percentile
bootstrap intervals with 20,000 resamples and fixed seed 22459. Positive
time deltas mean slower. No multiple-comparison adjustment, preregistered
request-price protocol or request/RPS claim is made. A/A compares two
unchanged arms, not separate hardware. The negative controls are retained,
including noisy A/A intervals; absence of a resolved regression would not
prove a zero regression of arbitrary size.

The first 4.0.7 CGI screen used unpinned short windows. Its short-input CPU
intervals/A/A are too wide for a no-regression conclusion, so its complete
data is retained, not pooled into the longer pinned confirmation. The latter
uses CPU 2 and eight times as many iterations for the empty/short/dense
controls. Master and String screens are pinned to the same CPU. No heap
floors, allocator configuration, fixture substitutions or disabled GC.

Master is built from canonical
[`5f2bc22560e9063fb8dec736afbf378251cad3ec`](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec),
with GCC 12 `-O3`, native YJIT, and identical flags within each comparison.
CGI extensions are rebuilt against **each runtime's own headers**; a 4.0.7
extension is not loaded into master. The String comparison copies the same
master build before/after changing only the initialization fast path.

[Complete numeric evidence](../ruby-small-c.json) retains the separate raw
arms, binary hashes, rounds, CPU/wall intervals, allocations and A/A for all
six cohorts, plus sanitized CGI caller counts. Never pool versions or pool
4.0.7 with master. The Ruby version string was generated at configuration
time; the candidate commit and measured executable/extension hash identify
the actual patch, not that string alone.

Example reproductions after separately building unchanged/patched binaries
and CGI extensions with the same compiler/configure flags:

```sh
# CGI V1: master runtime with each master-built extension directory.
SCREEN_RUBY=/path/to/master-baseline \
SCREEN_RUBYLIB=/path/to/build/.ext/x86_64-linux \
  taskset -c 2 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/ruby_c_micro_screen.rb BASE_LIB V1_LIB cgi-v1.json 16

# CGI V2: bounded kill screen; it is not the full nine-case screen.
SCREEN_RUBY=/path/to/master-baseline \
SCREEN_RUBYLIB=/path/to/build/.ext/x86_64-linux \
SCREEN_CASES=escape_early,escape_late,dense \
  taskset -c 2 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/ruby_c_micro_screen.rb BASE_LIB V2_LIB cgi-v2.json 8

# String V2: the arguments are executables, not extension directories.
SCREEN_KIND=string_init SCREEN_RUBYLIB=/path/to/build/.ext/x86_64-linux \
  taskset -c 2 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/ruby_c_micro_screen.rb MASTER_BASE MASTER_STRING_V2 string-v2.json 16
```

The driver/controller runs under 4.0.7 in these commands; the actual timed
children use the explicitly selected master executable and verify their
execution mode. The pinned 4.0.7 CGI confirmation additionally uses
`SCREEN_SCALE=8 SCREEN_CASES=empty,safe_short,dense` with its own extensions.

## Rejected draft 1: CGI safe-input fast path

**Proposed target:** ruby/ruby (`ext/cgi/escape` is core in current Ruby;
the old CGI gem split does not make this a ruby/cgi-only change).

**Title:** Avoid CGI.escapeHTML's temporary buffer for already-safe strings

**Patch:**
V1 [`1dd0dcf15a8b9415d0158b432a0a2f154621b90d`](https://github.com/thomasklemm/ruby/commit/1dd0dcf15a8b9415d0158b432a0a2f154621b90d);
V2/head [`d9e1fca98038033e139b3261978ff99c2b11efd5`](https://github.com/thomasklemm/ruby/commit/d9e1fca98038033e139b3261978ff99c2b11efd5),
branch `thomasklemm/cgi-html-escape-fast-path`. **Rejected research branch,
not a PR ready for approval.**

**Draft body**

`CGI.escapeHTML` currently allocates a scratch buffer sized for six times the
input length and writes each input byte into it. If no escaping was needed,
it discards that buffer and returns `rb_str_dup(str)` instead.

Scan the safe prefix first. Return the same duplicate operation immediately
if the entire input is safe. Otherwise allocate the existing worst-case
buffer. V1 copies the prefix once and retains byte-at-a-time writes for the
remainder; V2 copies all safe segments in bulk. Both retain the overflow
check, byte-oriented behavior (including NUL and invalid bytes), encoding,
no-escape subclass behavior and a distinct mutable return. Reacquire input
pointers after the potentially allocating `ALLOCV_N`; do not hold a prefix
pointer across it.

For long safe inputs this removes **one temporary Ruby object per call**
(the `ALLOCV_N` heap buffer); the result duplicate is still allocated.
Short inputs whose temporary buffer was on the stack remain one object/call.
Long escaping inputs retain the existing two objects/call; short escaping
inputs, including the 80-byte dense control, retain one. The buffer threshold
on this build is 171 input bytes (six times the length reaches 1024 bytes).

This is a **small library improvement**, not a Rails request optimization.
The tested Rails paths call ERB rather than CGI; the standalone measurements
below are not attributed to request throughput.

**Rejected first version:** copying only the initial safe prefix in bulk and
retaining the byte-at-a-time remainder loop saved allocations, but master
showed long early-escaping CPU **+13.72% [12.62, 14.72] interpreter /
+16.38% [15.37, 17.50] YJIT**. Dense input also regressed **+7.36% /
+5.44%**. That version fails the no-regression rule, regardless of the
4.0.7 wins. Master safe-long CPU improved **−11.18% [−11.38, −10.95] /
−10.80% [−11.99, −9.22]**, with objects **2→1**; those gains do not override
the regressions on other inputs.

**Rejected second version:** copying safe segments fixes the early-escaping
case, but loses badly on dense input and still loses on late escaping.
All are master; CPU deltas are percent [95% interval].

| Input | Interpreter V2 / baseline | YJIT V2 / baseline |
|---|---:|---:|
| 2048 bytes, first byte escaped | −15.03 [−15.94, −14.23] | −14.46 [−15.05, −13.80] |
| 2048 bytes, last byte escaped | +2.83 [+1.27, +4.82] | +2.26 [+1.55, +3.24] |
| 80 bytes, every byte escaped | **+15.84 [+15.05, +16.72]** | **+15.88 [+15.25, +16.40]** |

Dense A/A is **−0.73 [−2.55, +0.74] / +0.98 [+0.29, +1.69]**; its small
YJIT bias is retained, not a reason to erase a roughly 16% regression.
The two versions' escaping regressions are independently decisive. **Kill;
no upstream submission and no third performance-tuning iteration.**

**Tests run**

* Ruby 4.0.7 + rebuilt extension: `ruby --disable-yjit -I<patch-lib>
  test/runner.rb test/cgi`, and `--yjit`: each **435 tests, 1415 assertions,
  0 failures, 0 errors, 0 skips**.
* Built master: `make test-all TESTS='cgi erb'`, and with
  `RUN_OPTS=--yjit`: each **534 tests, 14062 assertions, 0 failures,
  0 errors, 0 skips**.
* A public-interface test exercises safe prefixes of multiple lengths with
  multibyte text/NUL, mutable distinct results, preserved encoding, and all
  five escaped bytes after the prefix. Existing tests cover frozen inputs,
  coercion, encodings, aliases, overflow and pure-Ruby fallback behavior.
* V2 differential/oracle validation: **32,033 encoding/input combinations
  per arm**, including String subclasses, frozen inputs, invalid bytes,
  NUL and the 170/171-byte buffer boundary. An independent byte/entity oracle
  checks ASCII-compatible results; baseline/V2 results and fallback errors
  compare identically for all 103 installed encodings. Each arm also runs
  **40 calls under GC stress and automatic compaction**. All pass on 4.0.7
  and master, each with interpreter and YJIT. These are scratch validation,
  not a claim that every encoding's full API has been exhaustively tested.

## Rejected draft 2: String initialization argument fast path

**Title:** Fast-path common String initializer argument shapes

**Patch:**
V1 [`7161de1298b52a09ad2850685bf868a6db902e40`](https://github.com/thomasklemm/ruby/commit/7161de1298b52a09ad2850685bf868a6db902e40);
V2/head [`0835c424fa76a87722ed4d71840b4d0aa339ede2`](https://github.com/thomasklemm/ruby/commit/0835c424fa76a87722ed4d71840b4d0aa339ede2),
branch `thomasklemm/string-init-one-arg`. **Rejected research branch,
not a PR ready for approval.** Master only; not patched into 4.0.7.

**Draft body**

When `String#initialize` receives exactly one positional argument and the VM
reports no keyword arguments, the existing path eventually calls
`rb_str_replace(str, orig)`. Return that same operation before initializing
keyword IDs and scanning optional arguments. Keep the full existing parser
for every other argument shape. V2 also returns the existing no-argument
no-op directly, rather than scanning arguments before doing nothing.

The short fast path does not bypass `to_str`, frozen checks, encoding or
shared-root/COW handling: `rb_str_replace` still owns them. It removes no
objects. The no-keyword guard matters because a keyword-only call also has
`argc == 1`. No subclass override is bypassed.

This is generic initialization work, not a SafeBuffer pooling or allocation
elimination patch. The blog has 54 `html_safe` calls; after the existing
sealed tier, 48 remain. Even eliminating all sampled `rb_str_init` self time
would cover only its tiny baseline share, not the whole 0.84% `html_safe`
replay budget. Do not claim a request price from the microbenchmark.

**Rejected V1:** small initialization micro wins of approximately 1–4% did
not survive the controls: YJIT no-argument construction slowed **+2.88%
[+1.45, +4.53]**. Do not promote it from the winning rows alone.

**Rejected V2:** even after explicitly fast-pathing zero arguments, the
complete paired screen retains regressions. Representative master CPU
deltas are percent [95% interval]; all rows remain in the numeric export.

| Case | Mode | V2 / baseline | A/A |
|---|---|---:|---:|
| Long subclass initializer | Interpreter | −2.68 [−4.23, −0.77] | −0.20 [−2.20, +1.76] |
| No-argument subclass constructor | Interpreter | **+2.56 [+1.51, +3.98]** | −0.81 [−2.48, +0.29] |
| Short subclass initializer | YJIT | **+3.13 [+2.21, +4.49]** | −0.01 [−0.66, +0.64] |
| No-argument subclass constructor | YJIT | **+4.29 [+2.55, +6.45]** | −0.40 [−1.61, +0.94] |

The source shortcut alone does not establish a runtime win. There is no
allocation reduction to weigh against these regressions; **kill**, without
claiming a diagnosed compiler/code-layout cause or trying more variants.

**Tests run:** built master `make test-all TEST_EXCLUDES=
TESTS='ruby/test_string.rb ruby/test_stringchar.rb'`, interpreter and
`RUN_OPTS=--yjit`: each **513 tests, 28950 assertions, 0 failures, 0 errors,
0 skips**. Clearing `TEST_EXCLUDES` includes memory-leak tests rather than
using the makefile's default exclusion. The existing suites cover arity,
coercion, frozen receivers, kwargs/capacity, sharing, subclass behavior,
wide encodings and terminators. A standard benchmark YAML accompanies the
prototype; the paired screen adds a forwarding subclass and no-arg controls.

## Rails handoff (no Rails changes here)

Rails 8.1.4 `active_support/core_ext/object/blank.rb:136–162` defines
`BLANK_RE = /\A[[:space:]]*\z/`; `String#blank?` performs `empty? ||
BLANK_RE.match?(self)`, rescuing encoding incompatibility through
`ENCODED_BLANKS`. Blog: **196 calls / 194 matches / zero allocated objects**,
fresh-process inclusive replay **0.99% CPU**, falling to **121 calls/matches
and 0.66%** after the existing sealed form/token/collection tier. Fizzy and
Lobsters have **487 and 114 actual blank-regexp matches** respectively.

Blog callers: XML attribute-name escaping 95, tag-option keys 45,
content-tag content 13, form/model/translation naming 14, CSRF/Journey paths
10, capture/content slots 3, asset helpers 4, cookie crypto configuration
4, request/log/browser checks 4, strong-params/SQL 3, Turbo stream name 1.
Two empty translation defaults skip matching. Mutable/frozen/SafeBuffer
receiver counts are **102/85/9**. Frozen headers are still live inputs.

XML names cost 95 escape calls and 55 Symbol-to-String objects before the
tier, **62/43 after** (inclusive CPU replay **1.30%→1.08%**). Tag-name
validation falls **26→16** checks (**0.16%→0.11%**, zero objects). Most of
the blankness signal overlaps XML/key validation. Candidate Rails work is
to avoid repeated conversion/validation of certified literal/schema keys,
not globally memoize mutable strings or duplicate the same savings in three
rows. Global `Regexp.timeout` was **1.0** in all three apps; Unicode,
invalid encoding, subclass dispatch and timeout behavior still matter.

## Owner decision

Only the owner may approve/subsequently post an upstream PR. Fork branches
and these documents are research drafts, not upstream submissions, merged
Ruby changes, Lowrail production changes, or whole-Ruby CI certification.
