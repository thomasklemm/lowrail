# Bet W: non-Rails gems on real request paths

2026-10-22. **Two candidates handed off: importmap-rails preload tags and
sqlite3's unused terminal row array.** Clean fork commits:
[importmap-rails](https://github.com/thomasklemm/importmap-rails/commit/cf3d93370011b00f90312d3290b571a7f7edb036)
on `thomasklemm/preload-tag-allocations`, and
[sqlite3-ruby](https://github.com/thomasklemm/sqlite3-ruby/commit/ca8a805f900ef174ee1e9722514f36539fc09803)
on `thomasklemm/statement-done-allocation`.
No upstream PR, issue or comment was opened. The coordinator owns the separate
review/PR thread. Useragent remains rejected; mini-profiler and Propshaft's
obvious shortcuts fail ownership/behavior boundaries. This is research and
an upstream implementation refactor, not a Lowrail support claim.

## Census and ranking

Reuses [bet U's allocation-generation method](https://github.com/thomasklemm/lowrail/commit/aeb6f064445db51d418ab22d3f7ef36579307898),
but measures fresh requests and filters by the **loaded gem that owns the
allocation's source file**, excluding Rails component gems and Rack mock
client files. Git/path gems retain their owning gem's version. Source-level
lines are aggregated across allocated classes, not counted twice as separate
candidates. There are **691 ranked sites, five apps, 15 routes, two modes**.

Every route gets 100 warm requests, three GC-enabled allocation totals of
20 requests each, and a separate ten-request GC-disabled ObjectSpace
allocation-generation census. Interpreter and YJIT are both observed, not
inferred from flags. The YJIT census is an allocation screen, not a JIT-flat
speed claim. The raw receipts retain total, enumerated and **unenumerated**
objects. Native/internal/unavailable-source residuals are not assigned to gems.

The **score** is the sum of per-app means, with equal route and mode weights
within each app. Versions stay separate; absent app/version cells contribute
zero. **Objects/request** below is the mean among apps with that site, not
the score and not a promised saving. This gives repeated cross-app work more
weight than one app's outlier. Only the two accepted experiments have request
Ir measurements; this is not an Ir attribution of all 691 sites.

| Rank | Owning gem/version | Site | Objects/request | Score | Current upstream status; verdict | Draft/fork |
|---:|---|---|---:|---:|---|---|
| 1 | useragent 0.16.11 | `browsers/base.rb:120`, `detect_product` | 96.67 | 290.00 | Still on master; `casecmp?` changes Unicode matching. Reject shortcut. | — |
| 2 | importmap-rails 2.2.2 | helper `:30`, tuple/options | 184.00 | 184.00 | Still on main; no duplicate found. Accepted refactor. | [fork](https://github.com/thomasklemm/importmap-rails/commit/cf3d93370011b00f90312d3290b571a7f7edb036) |
| 3 | importmap-rails 2.2.2 | helper `:44`, keyword forwarding/tag | 184.00 | 184.00 | Same candidate, not a second draft; tag strings still necessary. | same |
| 4 | rack-mini-profiler 5.0.0 | `railtie.rb:158`, `shorten_identifier` | 98.33 | 98.33 | Unchanged on master; array reuse changes retained subclass state. No exact simple patch. | — |
| 5 | importmap-rails 2.2.2 | helper `:42`, `Array`/collection | 93.50 | 93.50 | Same helper; collection and `Array(items)` behavior retained. Not all objects eliminated. | same |
| 6 | Propshaft 1.1.0 | `resolver/static.rb:11`, prefix join | 89.33 | 89.33 | Join remains on main; fresh result, live prefix and slash rules rule out memo/interpolation. | — |
| 7 | sqlite3 2.7.3 | `statement.rb:125`, native `step` | 89.33 | 89.33 | Still on main; fork removes only unused terminal array. Allocation-only admission; #743 is unrelated metadata. | [fork](https://github.com/thomasklemm/sqlite3-ruby/commit/ca8a805f900ef174ee1e9722514f36539fc09803) |
| 8 | importmap-rails 2.1.0 | helper `:34`, tag construction | 86.00 | 86.00 | Older pre-SRI implementation, not the new tuple/options regression. No separate patch. | — |
| 9 | useragent 0.16.11 | `version.rb:27`, scan/map | 28.28 | 84.83 | Still on master; `map!` passes suite but aliases retained scan result. Reject. | — |
| 10 | Propshaft 1.2.1 | `resolver/static.rb:11`, prefix join | 81.33 | 81.33 | Same boundary as rank 6, current main included. | — |
| 11 | sqlite3 2.5.0 | `statement.rb:125`, native `step` | 79.33 | 79.33 | Same terminal-array candidate as rank 7; not all attributed row objects eliminated. | same |
| 12 | URI 1.1.1 | `common.rb:456`, encoder copy | 25.21 | 50.42 | Copy remains on master; caller-owned strings must survive in-place encoding/gsub. No patch. | — |
| 13 | sprockets-rails 3.5.2 | `helper.rb:81`, asset prefix join | 24.00 | 48.00 | Join remains on master; live dispatch/prefix/debug path and fresh return required. No patch. | — |
| 14 | useragent 0.16.11 | `user_agent.rb:25`, parse products | 13.33 | 40.00 | Still on master; mutable parsed graph is public. No new exact small patch identified. | — |
| 15 | Hashie 5.1.0 | `mash.rb:374`, `convert_key` | 35.00 | 35.00 | [Open #613](https://github.com/hashie/hashie/pull/613) already proposes `Symbol#name`; no competing patch. | — |

The [full TSV](data/gem-census/ranking.tsv) and
[compressed ranking plus all ten raw profiles](data/gem-census/ranking.json.gz)
include every site, source marker, gem version, lock hash, route and residual.
The focused implementation pass covers the top 15; the next 15 received
the bounded triage below. Other sites are ranked, **not** silently claimed
audited or optimized.

### Workloads and scope

All run in dedicated `.corpus/gem-census-*` copies with frozen bundles, Ruby
4.0.7 and Rails 8.1.4. Existing corpus overlays are unchanged. PostgreSQL,
Redis and Memcached used dedicated disposable local services; no production
credentials or data. Fixtures/seeds and generated assets are outside app
implementation source. CASA uses the existing external throwaway-credentials
fixture pattern and a genuine Devise login, not a test-mode Warden bypass.

| App | Source pin | Requests |
|---|---|---|
| Retained blog | Roundhouse `bb90df2514f80817f98d89848dd0a6baa8df20a9` retained specimen | `/articles`, `/articles/1`, `/articles/1/edit` |
| Campfire-r81 | `02023b0f0cafc4d66e06e43be072cf4d6ca328fa` | authenticated `/rooms/486777696`, `/users/me/sidebar`, `/searches?q=coffee` |
| Fizzy | `6f1d200316ec3bae91d32c557d88647300807ee9` | authenticated `/buckets`, `/bubbles`, `/notifications` |
| CASA | `b584d2e6e6ebffe382f34c2ec202d20384d035ca` | authenticated `/`, `/volunteers`, `/casa_cases` |
| CodeTriage | `d1868f8634e97a111a7fca49d58cc776d206007e` | `/`, `/?language=Ruby`, `/privacy` |

Writebook is excluded per the known production boot failure; this bet does
not claim to resolve it. Lobsters is untouched and no proposal is offered to
it. Puma/network accept loops are outside this in-process Rack request
boundary; background job execution, login/password hashing, cold misses and
unexercised routes are not inferred from these warm HTML requests. Gems not
visible here are not claimed unimportant or allocation-free.

## Accepted handoff: importmap-rails

Current upstream main is
[`f255e554`](https://github.com/rails/importmap-rails/commit/f255e55482d9173d8f64db3bfa4317b64445eeb4).
Its helper is byte-identical to the tested 2.2.3 helper and Campfire's
2.2.2 git helper. It still makes `[path, { integrity: ... }]` and forwards
options through a keyword splat. The fork changes **one file, +8/−4**:
the existing private collector yields the item and once-read nonce; each
public helper builds its complete tag. It does not cache paths, packages,
nonces, rendered strings or caller data. `package.integrity` still evaluates
**before** dispatch to the overridable `tag` method.

Exact-head verification after `git pull --rebase origin main`:

```sh
PARALLEL_WORKERS=1 SEED=41231 mise exec ruby@4.0.7 -- bundle exec rake
# 104 runs, 350 assertions, 0 failures, 0 errors, 0 skips
```

Before and after full suites have those same results. The existing tests
are unchanged. An additional 30-case helper snapshot checks escaping, Unicode,
SafeBuffer class/encoding/safety/mutability, empty/duplicate paths, integrity,
nil/changing nonces and nonce call counts. Ownership probes independently
check frozen arrays/hashes/tuples, Array/Hash/String subclasses, `to_ary`
pair-like values, a retained `collect` result/block, repeated calls after
mutating a previous returned buffer, live paths/nonces, nil request, and an
overridable tag builder retaining keyword hashes and returned strings.
No input, keyword hash, string or returned buffer gains a new alias.
Snapshots match on stock 4.0.7 and on the tested Ruby master with interpreter,
YJIT and ZJIT enabled separately.

### Fixed-heap request result

Uses P's `RequestPairs.heap_instructions`, `HeapWindows`, `WindowAudit` and
`ScreenPlatform` exactness/background checks. **No Lowrail artifact or
activation**: the inactive runtime is required after app boot only because
the shared audit uses its already-loaded-constant lookup. All arms do this.
Only the candidate gem source file differs. A separate request trace confirms
seven preload packages and actual dispatch to each arm's source file.

Protocol: Ruby 4.0.7 interpreter; pinned Valgrind 3.19.0 **brk512**; six
independent serial shuffled off-A/off-B/on rounds, seed 41231; 100 warmups;
N0/N10 request windows with each arm's empty window subtracted; alternating
total/no-GC order; five exact heap page targets; 5,000 bootstrap resamples of
whole rounds. The retained blog entropy companions compare literal status,
body and complete header hashes at seeds 0/1 before and after windows, with
fixed disposable secret, declared fixed epoch and caller request ID. This
is a synchronous, warm, fixed-instant workload, not production latency.

| Metric | Before median | After median | Paired on−off, 95% interval |
|---|---:|---:|---|
| Objects/request | 2,564.50 | 2,549.15 | **−15.75 [−16.20, −13.90]**, −0.614% |
| Total Ir/request | 9,448,703.65 | 9,438,605.10 | **−9,419.75 [−12,029.90, −7,585.70]**; −0.09966% [−0.12733%, −0.08029%] |
| No-GC Ir/request | 9,446,908.75 | 9,440,919.30 | **−6,878.85 [−10,010.25, −4,161.05]**; −0.07279% [−0.10596%, −0.04406%] |

Paired deltas are medians of paired differences, not differences between
the two marginal medians. Request allocation differences include ordinary
request/harness variability; do not describe −15.75 as an exact invariant.

- Total Ir A/A interval: **[−0.06227%, +0.03416%]**.
- No-GC Ir A/A interval: **[−0.06683%, +0.03364%]**.
- Both wholly within preregistered **±0.1%**; zero containment not required.
- Exact responses, cache byte state, event/GC/background mix, no lazy loads
  or reaper contamination, interpreter mode, all heap pages and input pins
  **pass**. No worker/window was dropped or counted cohort retried.

### Native/JIT diagnostics and limits

One finite eight-round shuffled off-A/off-B/on operation cohort, pinned CPU
2, interpreter/YJIT/ZJIT separately, on Ruby master
[`5f2bc225`](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec):

| Operation | Objects before → after | Modes |
|---|---:|---|
| Eight packages, mixed integrity | 118 → 94 | interpreter, YJIT, ZJIT |
| Eight explicit paths | 104 → 80 | interpreter, YJIT, ZJIT |
| Empty control | 6 → 6 | all three |

All 72 importmap YJIT case windows have flat required counters and stable
warmup. ZJIT's available counters are flat in all 72 windows, but
`invalidation_count` is unavailable: **not a passed full ZJIT-flat gate**.
Native CPU A/A controls fail for every importmap case/mode, even at ±5%.
**No CPU, wall-time or JIT speed/no-regression proof is claimed.** There is
no resolved native slowdown; YJIT packages' paired CPU interval spans
−3.29% to +2.11%, and ZJIT packages spans −9.62% to +2.86%, both informational
because their A/A controls fail. All original results are retained.

An explanatory, unpaired stock-4.0.7 operation check gives **138 → 122**
objects for eight packages, **120 → 104** for eight paths, and **6 → 6**
empty. Thus the deterministic container saving is **2/module on 4.0.7**,
**3/module on tested master**, not universally three. This companion is not
a replacement request cohort or a native speed claim. The handoff satisfies
the coordinator's allocation/Ir rule, not a stronger JIT speed certificate.

### Duplicate and contribution checks

Read the current default branch (`main`), every file list for all 12 open
PRs, and closed-PR searches for preload, allocations and performance.
[#333](https://github.com/rails/importmap-rails/pull/333) adds Early Hints
above the helper; #103 changes old shim whitespace. Neither removes these
containers. #334 changes reachable-package selection, not tag construction.
Closed [#329](https://github.com/rails/importmap-rails/pull/329) concerns frozen
maps/cache warming, not this patch. No duplicate found in those checks.

No `AGENTS.md`, `CONTRIBUTING`, PR template, linter configuration or explicit
AI/LLM contribution ban was found in the current repository/community
profile. The repository **does** ship agent instructions in
`.github/prompts/fix-issue.prompt.md` and `generate-commit-message.prompt.md`;
both were read (minimal behavior-preserving changes, Ruby/Rails conventions,
no inline comments, existing full tests). Its default Rake/CI gate is tests,
not a separate configured linter. This is a report of the inspected policy,
not an inference that every Rails project accepts generated contributions.
Recheck current policy/head/duplicates in the separate PR thread.

## Accepted allocation-only handoff: sqlite3-ruby

The [clean fork commit](https://github.com/thomasklemm/sqlite3-ruby/commit/ca8a805f900ef174ee1e9722514f36539fc09803)
is based on current upstream default `main`
[`f465056e`](https://github.com/sparklemotion/sqlite3-ruby/commit/f465056e30bf13131d8b7fbd50beab81a0008b48)
(gem version 2.10.1, packaged SQLite 3.54.1). Both author and committer are
Thomas Klemm; no trailers. One C file, **+5/−4**, no Ruby API change:
`step` handles `SQLITE_DONE` by setting `done_p` and returning `nil` **after
the suppressed-callback exception check but before** `sqlite3_column_count`
and `rb_ary_new2`; the former `SQLITE_DONE` switch arm is removed. Row
conversion/freezing and error/reset handling remain unchanged. This saves
one discarded array per completed statement, not per row.

After `git pull --rebase origin main`, on the exact published head:

```sh
mise exec ruby@4.0.7 -- bundle exec rake
# RuboCop: 43 files, no offenses; compile; 379 tests / 772 assertions, green
SQLITE3_TEST_GC_LEVEL=verify mise exec ruby@4.0.7 -- bundle exec rake test
# 379 tests / 772 assertions, green; no failures/errors/skips in either suite
```

The baseline full suite also passes 379/772. Public probes compare retained
frozen rows and strings across reset, frozen String-subclass SQL, Unicode,
binary bytes, float/null, empty SELECT/UPDATE, repeated DONE, constraint
exceptions, raising user-defined callbacks and reference-verifying GC
compaction. Snapshots match on stock 4.0.7 and Ruby master
[`5f2bc225`](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec)
in interpreter/YJIT/ZJIT. Deterministic objects per operation: empty SELECT
2 → 1, one row 4 → 3, empty UPDATE 2 → 1, hundred rows 202 → 201;
already-DONE remains zero. Retained row/string identities remain distinct
between executions and frozen, with identical values.

### Fixed-heap request result

Same retained blog `/articles`, six-round N0/N10 protocol, fixed heap,
brk512 tool, exactness companions and preregistered ±0.1% Ir A/A gate as
importmap, but independently measured. Only the SQLite gem/native extension
differs; no importmap patch is enabled. All source files and actual native
binary paths/hashes are pinned. The result is **accepted for allocations
only**; neither Ir interval excludes zero.

| Metric | Before median | After median | Paired on−off, 95% interval |
|---|---:|---:|---|
| Objects/request | 2,563.75 | 2,560.70 | **−2.40 [−3.50, −1.70]** |
| Total Ir/request | 9,448,284.25 | 9,448,398.15 | +136.50 [−2,728.65, +3,327.00]; +0.00145% [−0.02887%, +0.03523%] |
| No-GC Ir/request | 9,451,417.40 | 9,447,820.00 | −3,584.20 [−5,219.30, +6,079.05]; −0.03792% [−0.05522%, +0.06436%] |

Total A/A **[−0.04762%, +0.08540%]**, no-GC A/A
**[−0.04409%, +0.05243%]**. Both pass ±0.1%; literal response hashes,
background/cache byte state, empty event/GC mix, no lazy loads/reaping,
interpreter mode, all five exact heap page targets and source pins pass.
The −2.40 request estimate includes request variability; the deterministic
saving is exactly one array per completed statement. No counted cohort was
retried or window omitted.

### Many-row native control and limits

One finite eight-round shuffled off-A/off-B/on cohort per mode includes
100-row queries, so the newly early DONE test is exercised predominantly
on row returns rather than only empty statements. Many-row CPU intervals:
interpreter **[−7.93%, +15.62%]**, YJIT **[−12.80%, +18.66%]**, ZJIT
**[−7.38%, +6.86%]**. No resolved slowdown; these intervals are too wide to
prove no regression. Only the interpreter many-row CPU A/A passes ±5%; the
other **11/12** CPU cells fail. CPU is informational, not admission evidence.
All **96 YJIT windows** have stable warmup and flat counters. All 96 ZJIT
windows have flat available counters, but `invalidation_count` is missing:
not a full ZJIT-flat certificate. No interpreter/JIT speed claim is made.

The first unbundled stock companion accidentally loaded an installed
platform extension rather than the built library; those receipts are
retained as **rejected preparation**, never used for gains. The corrected
library layout and explicit realpath/hash checks verify actual local
binaries before the accepted budget/counting and native probes. Bundled
own-suite runs already used the locally compiled extension.

### Duplicate and contribution checks

Rechecked current default `main`, all **11 open PR file lists** and their
`statement.c` patches, plus open/closed searches for allocations, step and
`SQLITE_DONE`. No duplicate found. #743 optimizes metadata, not native step;
#757 changes bindings, #749 Ractor state, #528 GVL release, #115 virtual
tables. `CONTRIBUTING.md` exists and was read: database/statement GC
ownership, compaction/reference verification, Valgrind/memcheck and build
guidance. Also read `.editorconfig`, RuboCop, formatter and CI configuration.
No `AGENTS.md`, PR template or explicit AI/LLM contribution restriction
found in the repository. Organization community `.github` returned 404,
not a positive claim about an unavailable policy. Recheck before opening.

## Rejected/deferred shortcuts

- **Useragent:** baseline and `scan.map!` each pass **1,321 examples**.
  A String subclass retaining the ordinary `scan` array disproves ownership
  equivalence: clearing that array leaves baseline Version `[140,2,31]`
  but candidate `[]`. Ordinary `Version#to_a` copy tests miss this. Separately,
  `"ß".downcase == "SS".downcase` is false but `"ß".casecmp?("SS")` true.
  No useragent fork/draft is offered. Current master is
  [`680915aa`](https://github.com/gshutler/useragent/commit/680915aa9e271592fac15d9853da1ff5e589da06);
  open #40 is unrelated Comparable work.
- **Mini-profiler:** current
  [`d95511f0`](https://github.com/MiniProfiler/rack-mini-profiler/commit/d95511f0b5fe0ae6d326c6ce7071157d829b9447)
  still does `split('/').last(2).join('/')`; no matching open PR found.
  Shifting the split array in place returns identical text but changes the
  array retained by a String subclass from five entries to two. Caching the
  mutable returned identifier also loses fresh-result behavior. Reject those
  shortcuts; no claim that all possible algorithms are impossible.
- **Propshaft:** current
  [`dc979db8`](https://github.com/rails/propshaft/commit/dc979db89cd07c72ee4d11d415ae1cb4fd072623)
  still joins the live prefix/digested path. Clearing one returned string
  must not affect the next resolution; mutating a retained prefix must change
  the next result. Plain interpolation gives `/assets///app.js` where
  `File.join('/assets/', '/app.js')` gives `/assets/app.js`. Frozen prefixes
  work. No matching open prefix-join optimization found; no exact simple patch.
- **sqlite3:** the ranked Ruby site calls native `step`, which creates row
  arrays/strings and an unused array on the first `SQLITE_DONE`. The latter
  is the accepted allocation-only candidate above, not covered by #743.
  Metadata allocation optimization is already in current
  [`f465056e`](https://github.com/sparklemotion/sqlite3-ruby/commit/f465056e30bf13131d8b7fbd50beab81a0008b48),
  merged #743. An earlier classification as duplicate metadata work was
  corrected by inspecting the actual source line and C implementation.
- **URI/Sprockets/Hashie:** current encoder copy/join/key-conversion sites
  remain in [URI](https://github.com/ruby/uri/commit/0d5ee6fed7c85775b6e110c71bbc3db5e3e8c8c3),
  [Sprockets](https://github.com/rails/sprockets-rails/commit/87ee2d241b5a19c414527c57d403af902942167d)
  and [Hashie](https://github.com/hashie/hashie/commit/578b0e43e5d3259f53dd203cdaa5ca2d9748943e).
  URI mutates/encodes its copy; Sprockets depends on live prefix/debug
  dispatch; Hashie's proposed symbol-key optimization already has open #613.
  No accepted patch here. Open PR checks are discovery, not blanket semantic
  audits of each dependency or all closed history.

### Continued triage: ranks 16–30

No third handoff emerged from the next 15. TZInfo 2.0.6's rank-16
`Timestamp.new!` allocation (11.56 objects/present-app request) constructs
the returned, potentially subclassed timestamp; current master retains the
factory. Base64 0.3.0's rank-20 `strict_encode64` (7.67) retains its existing
`[bin].pack("m0")` on master; removing the array needs a different native
encoding API, not a small Ruby refactor. SecureRandom's rank-26 native random
bytes are required output, not a reusable request cache.

Bugsnag 6.30.0's rank-24 `CircularBuffer#trim_buffer` (30.67) still calls
`shift(trim_size)` on master, including zero. Skipping the empty array looks
promising but changes the public setter's method return: two
`public_send(:max_items=, 3)` calls return distinct mutable empty arrays,
which a caller can retain without changing the buffer. The shortcut returns
nil. Validator/breadcrumb objects and SQL-bind metadata at ranks 19/21–23/28
are not automatically cacheable across live configuration and callbacks.
No exact, measured replacement was established.

Rack 3.2.7's rank-25 `Request#path` (7.00) already allocates just its fresh
result. Current main retains `script_name + path_info`; interpolation does
not eliminate that output and changes dispatch when a String subclass's
`to_s` preserves itself and `+` is overridden. The public `Request#path`
witness exercises that actual path. Open performance PR
[#2520](https://github.com/rack/rack/pull/2520) changes SSL/host parsing and
other components, not this method. Propshaft repeats the earlier boundary;
sqlite3 metadata ranks 29/30 are covered by merged #743. This is a quick
semantic triage, not own-suite/performance/closed-history coverage for a new
candidate. Raw boundary receipts are in the main evidence JSON.

## Evidence and reproduction

- [Evidence JSON](data/gem-census/evidence.json): suite logs, source hashes,
  rejected patch/witness, exact helper/ownership snapshots, native protocol,
  duplicate-check patches and preparation failures.
- [Native summary](data/gem-census/native-summary.json.gz): every paired
  diagnostic sample and JIT warmup/counter state, including failed A/A cells.
- [Request counter archive](data/gem-census/request-counter.tar.gz): frozen
  protocol/pins, raw samples, result, summary, Valgrind provenance and **all
  90 actual Callgrind dumps**, including empty windows/process-ending dumps.
  Retains failed setup history separately in evidence; no counted result was
  replaced. No cookies, secrets, response bodies or credential files exported.
- [SQLite evidence](data/gem-census/sqlite-evidence.json): exact fork patch,
  before/after suites, ownership/allocation probes, duplicate checks,
  rejected loader preparation and native protocol.
- [SQLite native summary](data/gem-census/sqlite-native-summary.json.gz): all
  diagnostic windows, failed CPU A/A controls and JIT observations.
- [SQLite request archive](data/gem-census/sqlite-request-counter.tar.gz):
  complete accepted protocol, samples, gates and all 90 Callgrind dumps.

Tooling lives in `bench/upstream/gem_census{,_rank}.rb`,
`gem_candidate{,_pairs}.rb`, `gem_request_screen.rb`,
`importmap_ownership.rb`, `sqlite_candidate.rb` and
`gem_ownership_boundaries.rb`. See
[testing](../development/testing.md) and [P's platform](../screen-platform.md)
for dependencies and the precise counter contract. Prepare dedicated copies
with `script/corpus APP gem-census-NAME --source-only`, frozen bundles and
the app's genuine fixture/schema/asset tasks. Run census helpers **from the
app directory**, with production service URLs supplied privately:

```sh
root=/absolute/path/to/lowrail
CENSUS_MODE=interpreter BUNDLE_FROZEN=true RUBYOPT=-rbundler/setup \
  mise exec ruby@4.0.7 -- ruby "$root/bench/upstream/gem_census.rb" profile blog NEW.json
# Repeat with CENSUS_MODE=yjit, same app/fixtures; retain both receipts.
# From root, rank all five pairs with gem_census_rank.rb NEW_RANKING.json RECEIPTS...

# Own-gem probes, from root; use distinct output files for before and after.
mise exec ruby@4.0.7 -- ruby bench/upstream/importmap_ownership.rb HELPER_SOURCE NEW.json

# Request config has absolute app/before/after paths and path: /articles.
# The app must be the unmodified retained production blog with prepared DB/assets.
bash script/bench-valgrind NEW_PREFIX
PATH="NEW_PREFIX/bin:$PATH" CPATH="NEW_PREFIX/include" BENCH_JIT=0 BENCH_JOBS=1 \
  mise exec ruby@4.0.7 -- ruby bench/upstream/gem_request_screen.rb CONFIG.json NEW_BUDGET --budget
# Freeze protocol, then same command with a new output and without --budget.
```

No runtime/compiler code or corpus implementation was changed. Targeted
`request_pairs_test.rb` and `screen_test.rb` run in strict mode at seed 1729;
all new Ruby harness files pass syntax checks. This is not a rerun of the
entire Lowrail compiler/runtime gate or hosted upstream CI.
