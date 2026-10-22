# Bet W: non-Rails gems on real request paths

2026-10-22. **One candidate handed off: importmap-rails preload tags.**
The clean [fork commit](https://github.com/thomasklemm/importmap-rails/commit/cf3d93370011b00f90312d3290b571a7f7edb036)
is on `thomasklemm/importmap-rails:thomasklemm/preload-tag-allocations`.
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
weight than one app's outlier. Only the accepted importmap experiment has a
request Ir price; this is not an Ir attribution of all 691 sites.

| Rank | Owning gem/version | Site | Objects/request | Score | Current upstream status; verdict | Draft/fork |
|---:|---|---|---:|---:|---|---|
| 1 | useragent 0.16.11 | `browsers/base.rb:120`, `detect_product` | 96.67 | 290.00 | Still on master; `casecmp?` changes Unicode matching. Reject shortcut. | — |
| 2 | importmap-rails 2.2.2 | helper `:30`, tuple/options | 184.00 | 184.00 | Still on main; no duplicate found. Accepted refactor. | [fork](https://github.com/thomasklemm/importmap-rails/commit/cf3d93370011b00f90312d3290b571a7f7edb036) |
| 3 | importmap-rails 2.2.2 | helper `:44`, keyword forwarding/tag | 184.00 | 184.00 | Same candidate, not a second draft; tag strings still necessary. | same |
| 4 | rack-mini-profiler 5.0.0 | `railtie.rb:158`, `shorten_identifier` | 98.33 | 98.33 | Unchanged on master; array reuse changes retained subclass state. No exact simple patch. | — |
| 5 | importmap-rails 2.2.2 | helper `:42`, `Array`/collection | 93.50 | 93.50 | Same helper; collection and `Array(items)` behavior retained. Not all objects eliminated. | same |
| 6 | Propshaft 1.1.0 | `resolver/static.rb:11`, prefix join | 89.33 | 89.33 | Join remains on main; fresh result, live prefix and slash rules rule out memo/interpolation. | — |
| 7 | sqlite3 2.7.3 | `statement.rb:125`, native `step` | 89.33 | 89.33 | Row materialization remains; unused terminal array under investigation. #743 is metadata, not this site. | pending |
| 8 | importmap-rails 2.1.0 | helper `:34`, tag construction | 86.00 | 86.00 | Older pre-SRI implementation, not the new tuple/options regression. No separate patch. | — |
| 9 | useragent 0.16.11 | `version.rb:27`, scan/map | 28.28 | 84.83 | Still on master; `map!` passes suite but aliases retained scan result. Reject. | — |
| 10 | Propshaft 1.2.1 | `resolver/static.rb:11`, prefix join | 81.33 | 81.33 | Same boundary as rank 6, current main included. | — |
| 11 | sqlite3 2.5.0 | `statement.rb:125`, native `step` | 79.33 | 79.33 | Same terminal-array candidate as rank 7. | pending |
| 12 | URI 1.1.1 | `common.rb:456`, encoder copy | 25.21 | 50.42 | Copy remains on master; caller-owned strings must survive in-place encoding/gsub. No patch. | — |
| 13 | sprockets-rails 3.5.2 | `helper.rb:81`, asset prefix join | 24.00 | 48.00 | Join remains on master; live dispatch/prefix/debug path and fresh return required. No patch. | — |
| 14 | useragent 0.16.11 | `user_agent.rb:25`, parse products | 13.33 | 40.00 | Still on master; mutable parsed graph is public. No new exact small patch identified. | — |
| 15 | Hashie 5.1.0 | `mash.rb:374`, `convert_key` | 35.00 | 35.00 | [Open #613](https://github.com/hashie/hashie/pull/613) already proposes `Symbol#name`; no competing patch. | — |

The [full TSV](data/gem-census/ranking.tsv) and
[compressed ranking plus all ten raw profiles](data/gem-census/ranking.json.gz)
include every site, source marker, gem version, lock hash, route and residual.
The focused implementation pass stops at the top 15; lower-ranked sites are
ranked, **not** silently claimed audited or optimized.

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
  is a separate candidate now under investigation, not covered by #743.
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

Tooling lives in `bench/upstream/gem_census{,_rank}.rb`,
`gem_candidate{,_pairs}.rb`, `gem_request_screen.rb`,
`importmap_ownership.rb` and `gem_ownership_boundaries.rb`. See
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
