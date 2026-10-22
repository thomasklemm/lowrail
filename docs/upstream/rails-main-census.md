# Rails-main cross-app allocation census (bet U)

2026-10-22. **Four apps, 12 routes, interpreter and YJIT. No qualifying PR
draft, no Rails fork commit pushed, and no upstream PR, issue or comment.**
The one measured preload-buffer prototype is rejected, not retimed. The
top 15 sites below are covered or have a concrete behavior/ownership reason
not to apply the small proposed elision. Lower-ranked, unreviewed sites remain
**untried**, not implicitly rejected. This is a census, not a Lowrail support
claim or a request-speed benchmark.

## Pins, workloads and method

Rails main observed at the start is pinned to
[`33748f4f60e68eeeed0d48ac566d345415dc78f4`](https://github.com/rails/rails/commit/33748f4f60e68eeeed0d48ac566d345415dc78f4).
All profiles use stock Ruby **4.0.7**, revision `229531a6cf`, with Lowrail
absent. App implementation, configuration, schema, tests and assets are
unmodified. The [incremental dependency overlays](../../fixtures/corpus/rails-main-census/)
follow the existing `script/corpus` r82 overlays; only `Gemfile` and
`Gemfile.lock` change at this additional step. Locks were resolved with
`bundle update rails --conservative`, then used frozen. Original r82 pins,
defaults and compatibility findings in [rails-8.2.md](../rails-8.2.md) remain
unchanged.

| App source | Routes, using upstream seeds/fixtures | Interpreter objects/request | YJIT objects/request |
| --- | --- | ---: | ---: |
| [Retained blog archive](../../fixtures/corpus/real-blog-r4-retained.tgz), SHA-256 `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99` | `/articles`; `/articles/1`; `/articles/1/edit` | 2031.85; 1967.35; 1621.40 | 2048.60; 1974.05; 1623.85 |
| [Campfire af4dd9f](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5) | All Talk `/rooms/486777696`; `/users/me/sidebar`; `/searches?q=coffee` | 5300.55; 5125.45; 5133.45 | 5300.50; 5126.75; 5134.65 |
| [Fizzy 77eada1](https://github.com/basecamp/fizzy/commit/77eada1c8ead75c39f7fda5c80f322bcf5a9adb5) | Account `897362094`: Writebook board `/boards/03ayv6mp60xg3aqes0m9sa68w`; `/cards`; `/notifications` | 31956.00; 16028.95; 8155.55 | 32234.45; 16115.80; 8198.80 |
| [Writebook 7478e2c](https://github.com/basecamp/writebook/commit/7478e2c7b109e688a6fa4745bac123e72b5cef84) | `/`; `/1057022143/handbook`; `/1057022143/handbook/271580430/welcome-to-the-handbook` | 4229.75; 5892.65; 8527.25 | 4246.95; 5931.45; 8595.15 |

These are medians of three GC-enabled 20-request allocation batches after
100 warm requests per route. A separate ten-request, GC-disabled ObjectSpace
allocation trace attributes objects to file:line and class. Only objects
from that GC generation are counted. The raw receipt separately records
the GC allocation total (`traced_gc_objects`), enumerable objects, and the unenumerated residual;
the latter is **not** assigned to a guessed site or called zero. It can
include VM/invisible objects. This is object count, not bytes, retained heap,
instruction count, latency or a claim that every allocation can be removed.

Requests use the app's Rack stack, genuine signed fixture sessions, HTTPS,
HTML Accept and a Firefox 140 user agent. Each must return HTTP 200 with a
nonempty body. Authentication is outside the counted window. Direct
`rack/mock_request.rb` and `mock_response.rb` client sites are excluded from
ranking; Rack-stack totals still include client harness overhead. Other
dependencies stay visible in raw receipts but the ranked pool is **Rails,
Rack/rack-session, Ruby library files, and Ruby-shipped URI, JSON, base64,
OpenSSL and SecureRandom**. App/importmap/Propshaft/useragent/sqlite3 sites
are not presented as Rails/default-gem candidates.

Writebook explicitly enables YJIT independently of `config.yjit`. For its
interpreter boot only, the external harness temporarily hides
`RubyVM::YJIT.enable` and restores it immediately after boot. All processes
assert their actual mode. This execution-policy control is disclosed rather
than calling Writebook's unmodified default boot an interpreter boot.

Lobsters is untouched and excluded with the coordinator's agreement: its
repository guidance forbids LLM-generated contributions. No fixture, overlay,
source or workaround was added there.

## Ranked sites and dispositions

The [full 1,274-site ranking](rails-main-census-sites.tsv) includes all app
weights. [Compressed JSON](rails-main-census.json.gz) contains that ranking
and all eight original detailed app/mode receipts, including all routes,
classes, lock hashes and trace residuals. Each app has equal weight across its
three routes and two modes. A site's **score multiplies its present-app count
by its mean objects/request among those apps**, equivalently the sum of their app
means. Thus frequency is not multiplied twice. These are traced site counts,
not the GC-enabled totals in the preceding table. Different sites can be
parts of the same operation and must not be added as independent savings.

`AS` = `activesupport/lib/active_support`, `AV` = `actionview/lib/action_view`,
`AP` = `actionpack/lib/action_dispatch`, `AR` = `activerecord/lib/active_record`.
URI paths are under `uri-1.1.2/lib/uri`; Rack is `rack-3.2.7/lib/rack`.

| Rank | Allocation site (file:line) | Apps | Mean objects/present-app request | Score | Disposition of the small allocation-elision proposal |
| ---: | --- | ---: | ---: | ---: | --- |
| 1 | URI `generic.rb:1007`, `split_path` | 2 | 380.00 | 760.00 | **Rejected: behavior/ownership.** `merge_path` mutates the fresh segment arrays; `split("/", -1)` preserves trailing empty segments. Dropping the limit loses the trailing slash; sharing segments changes ownership. No small exact replacement established. |
| 2 | AS `core_ext/string/output_safety.rb:243`, `String#html_safe` | 3 | 232.78 | 698.33 | **Rejected: behavior.** A fresh SafeBuffer with its own safety and mutation state is the return value; returning/caching the input is not equivalent. Earlier SafeBuffer shortcuts remain rejected. |
| 3 | AS `core_ext/string/output_safety.rb:72`, `SafeBuffer#initialize` | 3 | 221.22 | 663.67 | **Rejected: behavior/ownership.** Constructor/super work is not a disposable wrapper that may be shared or bypassed. No new safety-flag or receiver-ownership shortcut. |
| 4 | AV `helpers/tag_helper.rb:1542`, `tag_options` output | 3 | 142.33 | 427.00 | **Covered:** merged [#59117](https://github.com/rails/rails/pull/59117); open overlapping [#57999](https://github.com/rails/rails/pull/57999). The residual local output buffer is still needed; do not resubmit the attribute rewrite. |
| 5 | AP `http/url.rb:348`, `host_with_port` | 3 | 115.33 | 346.00 | **Rejected: behavior/ownership.** One fresh result String. Returning `host` or memoizing aliases caller mutation and skips live `host`/`port_string` evaluation. |
| 6 | AR `relation/where_clause.rb:32`, `merge` | 3 | 102.67 | 308.00 | **Rejected: prior resolved regression.** The already investigated empty-merge skip measured YJIT 0.95–0.96×. Not revived or retimed here. Other shapes still require predicates and a result. |
| 7 | AS `inflector/methods.rb:259`, `dasherize` | 3 | 102.00 | 306.00 | **Rejected: behavior/ownership.** `tr` returns a fresh String even when no underscore exists. Returning the input changes aliasing; `tr!` mutates input. Adjacent Symbol conversion was already fixed in [#59244](https://github.com/rails/rails/pull/59244). |
| 8 | AV `helpers/tag_helper.rb:1650`, composite prefix key | 3 | 98.44 | 295.33 | **Covered:** [#59244](https://github.com/rails/rails/pull/59244), [#59117](https://github.com/rails/rails/pull/59117), overlapping open [#57999](https://github.com/rails/rails/pull/57999). Keep live dasherization/escaping of the remaining composite key. |
| 9 | URI `generic.rb:516`, `set_userinfo` | 4 | 65.33 | 261.33 | **Rejected: return contract.** The protected method returns a fresh mutable `[user, password]`; replacing it with nil or a shared pair changes that result even though normal initializer callers discard it. |
| 10 | URI `generic.rb:543`, nil `split_userinfo` | 4 | 65.33 | 261.33 | **Rejected: return contract.** `return nil, nil` returns an Array, not nil. Destructuring happens to accept both, but the documented private method result/overrides differ. |
| 11 | URI `rfc3986_parser.rb:115`, relative match/captures | 4 | 65.00 | 260.00 | **Rejected: behavior.** MatchData and captured component Strings are used to build the public split result. `match?` cannot provide them; caching parsed objects changes mutation/extension behavior. No small exact algorithm found. |
| 12 | AV `helpers/tag_helper.rb:1809`, token splitting | 1 | 259.33 | 259.33 | **Covered:** merged [#59114](https://github.com/rails/rails/pull/59114) already uses block-form split and flat escaping. Residual String/MatchData token work is not the removed intermediate Array. |
| 13 | URI `common.rb:194`, `URI.for` construction | 4 | 64.33 | 257.33 | **Rejected: behavior/ownership.** These are fresh URI::Generic/HTTPS return objects, not disposable argument arrays. Shared parsed results would expose mutable components; scheme lookup remains live. |
| 14 | URI `rfc3986_parser.rb:135`, parse forwarding Array | 4 | 64.33 | 257.33 | **Rejected: extension behavior for the proposed inline.** Removing public `split`/`URI.for` dispatch to bypass the argument Array changes custom parser/scheme behavior. No small exact forwarding rewrite established. |
| 15 | Rack `request.rb:595`, `base_url` | 3 | 85.00 | 255.00 | **Rejected: behavior/ownership.** One fresh result String with live scheme/host dispatch. Memoization or returning a component is not equivalent. |

“Rejected” here rejects the named small proposal, **not** every possible
future algorithm at that site. No untried, plausible exact small fix remains
in these top 15 after this screen, so there is no second timing cohort.
Lower ranks remain an exploration pool, not an exhaustive optimization audit.

Additional exclusions: `index_with` is rank 18, score 219, but
[#59108](https://github.com/rails/rails/pull/59108) was deliberately reverted
by [#59203](https://github.com/rails/rails/pull/59203): Ruby 4.1 small-hash
spills outweighed tuple removal. Do not revive it. Previously covered
Journey, blank?, enum, callback, defaults and translation work is not new
opportunity. Delegated-type [#59270](https://github.com/rails/rails/pull/59270)
and Ruby [#19478](https://github.com/ruby/ruby/pull/19478) are separately owned
and were not changed.

### Upstream cross-check and concrete boundary controls

GitHub Rails PR **and issue** searches covered `host_with_port`, `SafeBuffer
allocation`, `dasherize`, `token_list`, `append_prefix_tag_option`,
`preload_link`, and `preload allocation`; relevant PR bodies/diffs and the tag
helper history were read. Preload-related [#51441](https://github.com/rails/rails/pull/51441)
is an opt-out API, [#48405](https://github.com/rails/rails/pull/48405) the header
limit, not this append proposal. Negative search results are bounded evidence,
not proof of universal absence of overlap.

URI 1.1.2 and authoritative ruby/uri master were also cross-checked: master
contains the release plus a CI change; [#242](https://github.com/ruby/uri/pull/242)
rewrote a `merge_path` loop, not the counted `split_path`. No covering open or
recent merged allocation proposal was found. The relevant contracts are
[split_path](https://github.com/ruby/uri/blob/v1.1.2/lib/uri/generic.rb#L1003-L1009),
[userinfo setters/splitting](https://github.com/ruby/uri/blob/v1.1.2/lib/uri/generic.rb#L509-L548),
[split/parse](https://github.com/ruby/uri/blob/v1.1.2/lib/uri/rfc3986_parser.rb#L77-L136),
and [URI.for](https://github.com/ruby/uri/blob/v1.1.2/lib/uri/common.rb#L187-L195).

Executed boundary controls confirm that mutating a `host_with_port` result
does not mutate the next result; dasherization preserves the source and
returns a distinct String for a no-underscore input; userinfo methods return
fresh mutable pairs. A URI subclass replacing only `path.split("/", -1)`
with `path.split("/")` changes merging `https://example.test/a/b` with
`../c/` from **`https://example.test/c/` to `https://example.test/c`**. These
are counterexamples to the proposed shortcuts, not a benchmark of an admitted
replacement. Their output is in the evidence archive.

## Experimental draft #1 — rejected; do not submit

**Proposed title:** Append to local preload-link buffers.

`javascript_include_tag` and `stylesheet_link_tag` build a fresh local String
then copy it for each optional suffix. The [eight-line prototype](../../bench/upstream/preload-link-buffers.patch)
uses `<<` instead of `+=` for crossorigin, integrity, nonce and nopush. No
cache, escaping shortcut, helper inlining or nonce-order change. The
stylesheet buffer/copy sites score 94 each across three apps (blog 2,
Fizzy 65, Writebook 27 objects/app-average request), well below the top 15.
These counts locate the work; they are not measured request savings.

### Single paired cohort: allocation win, admission failure

Built stock Ruby master only after selecting this candidate, pinned to
[`5f2bc22560e9063fb8dec736afbf378251cad3ec`](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec)
(4.1.0dev, x86_64 Linux), with YJIT and ZJIT enabled. One complete cohort:
10 fresh-process pairs per mode, fixed balanced AB/BA order, `taskset -c 2`,
20,000 warm operations, 5,000 GC-enabled allocation operations, then 20,000
operations timed with process CPU time. No concurrent build/test/review was
run during timing. Bootstrap: 10,000 resamples of paired log ratios,
seed 41231, percentile 95% interval. All cases and controls are retained.

The original worker had an observer defect: its view lacked a controller,
so `respond_to?(:response)` was false. It exercised **early hints without
response-header writing**, not the intended full response-header path. Its
exact source is retained as `preload_links-original.rb` (SHA-256
`47758ca0745c8e1f569424acd5ddada66992cb0af3c2424683063c396788c12c`)
in the archive. The table describes that original workload only. The final
worker corrects the controller/response setup; **no replacement timing
cohort was run** and the original rejection is not rescored.

Ratios are before CPU/op ÷ after CPU/op: below 1 means slower. Intervals
include 1 except the bold ZJIT default-JS regression. Raw counts have a
constant 0.0002/op observer overhead on the default stylesheet case, omitted
below but retained in [all 27 results](preload-links-rejected.json).

| Case | Objects/op before → after (interpreter; JIT if different) | Interpreter ratio [95% CI] | YJIT ratio [95% CI] | ZJIT ratio [95% CI] |
| --- | --- | --- | --- | --- |
| Default stylesheet | 28 → 27 | 0.989 [0.953, 1.036] | 0.968 [0.932, 1.009] | 1.002 [0.979, 1.025] |
| Stylesheet, all options | 36 → 32; JIT 38 → 34 | 1.004 [0.969, 1.033] | 1.010 [0.982, 1.039] | 1.015 [0.985, 1.046] |
| Default JavaScript | 28 → 27 | 0.994 [0.954, 1.036] | 0.991 [0.972, 1.015] | **0.9744 [0.94997, 0.99952]** |
| JavaScript, all options | 36 → 32; JIT 38 → 34 | 1.016 [0.972, 1.058] | 1.027 [0.993, 1.061] | 1.004 [0.981, 1.021] |
| Module JavaScript | 30 → 28 | 1.022 [0.957, 1.104] | 0.978 [0.945, 1.013] | 0.986 [0.958, 1.008] |
| Three stylesheets | 63 → 54 | 0.984 [0.965, 1.006] | 0.970 [0.935, 1.003] | 0.974 [0.943, 1.003] |
| nopush off, control | 27 → 27 | 1.022 [0.967, 1.087] | 0.998 [0.970, 1.035] | 1.000 [0.962, 1.044] |
| Preload disabled, control | 22 → 22 | 0.997 [0.966, 1.026] | 0.965 [0.931, 1.00025] | 1.003 [0.971, 1.032] |
| Deferred script, control | 22 → 22 | 0.975 [0.943, 1.008] | 1.018 [0.992, 1.057] | 0.988 [0.955, 1.020] |

All measured JIT windows show zero compilation/invalidation/code-GC counter
deltas. This limited counter check is **not** Lowrail's fixed-heap,
three-window JIT-flat/A/A/Callgrind protocol. There is no accepted speed,
instruction-count or whole-request claim. The owner's no-resolved-regression
rule fails on ZJIT even though the upper interval bound is close to one.
No case was dropped, no interpreter/YJIT/ZJIT rerun was used to improve the
result, and a stylesheet-only post-hoc subset was not published.

### Tests and Thermos

Both clean base and the exact prototype pass the complete Action View suites
on Ruby 4.0.7: **2,901 tests / 6,865 assertions; 249 / 338; 173 / 334**,
zero failures, errors or skips. Final logs bind the Rails HEAD, helper SHA-256,
working directory and Ruby version to each execution. From each checkout's
`actionview/` directory:

```sh
BUNDLE_ONLY=default:test:rubocop:cable:db PARALLEL_WORKERS=1 SEED=41231 \
  mise exec ruby@4.0.7 -- bundle exec rake test
```

After correcting the response observer, **165 identical snapshots in each
of interpreter/YJIT/ZJIT on pinned master** cover returned bytes, encoding,
class/safety/frozen state, response Link header, early hints, nonce calls,
caller non-mutation, duplicate sources, data/defer/disabled controls and the
header-size boundary. In each mode there are 163 successful cases (159 with
nonnil Link headers) and two matching encoding exceptions. The final
formatter-edited worker was compared again to the clean-base snapshots.
This is bounded equivalence evidence, not universal override coverage.

Independent **Thermos correctness/security and maintainability reviews**
found no introduced Rails behavior defect. Both found the missing header
observer and challenged any speed claim; both concerns are reflected above.
The correctness reviewer independently exercised a larger 586-case header,
encoding and nonce matrix with identical results, but that separate scratch
probe is not substituted for the retained 165-case evidence. The other
reviewer's suggestion to extract an append helper was not adopted: the
eight-line operator change does not justify another abstraction. Final
source-bound suite logs address the reviewers' initial log-provenance gap.
Rails RuboCop with its explicit configuration passes the prototype and all
five retained Ruby scripts: **6 files, no offenses**. No Rails test, skip or
assertion was changed. Hosted CI and the app own-suites were not run for this
rejected upstream prototype.

## Reproduction and delivered evidence

From a fresh disposable checkout with Ruby 4.0.7, system build dependencies,
libvips and Redis available, start an **owned empty local Redis** for the
corpus's default connection, then:

```sh
mise exec ruby@4.0.7 -- ruby script/rails-main-census prepare
CENSUS_OUTPUT="$PWD/.lowrail/private/census-new" \
  mise exec ruby@4.0.7 -- ruby script/rails-main-census profile
mise exec ruby@4.0.7 -- ruby bench/upstream/rails_main_rank.rb \
  .lowrail/private/ranking-new.json .lowrail/private/census-new/*.json
```

`prepare` refuses existing `.corpus/census-*` copies and database-URL
overrides. It fetches the pinned sources, applies the existing r82 overlay
and then the incremental one, installs frozen bundles, prepares disposable
production SQLite databases/assets, and loads upstream fixtures/seeds.
`profile` refuses existing receipt paths. The final orchestrator was replayed
from four fresh sources end to end: all 24 app/route/mode requests passed,
and all four lock hashes matched the original census. This setup-validation
replay did not replace the ranked original receipts or the timing cohort.
Syntax checks pass for all five Ruby scripts; reaggregation after formatting
produces byte-identical ranking JSON. Incremental patches were replayed
against the old dependency overlays and compared byte-for-byte to the
profiled Gemfiles/locks.

[Evidence archive](rails-main-census-evidence.tar.gz): all 60 timing workers,
their logs and summary; the original timing worker source; six corrected
before/after snapshot files; final source-bound Action View suite logs;
boundary-control output; and successful fresh orchestration logs. No session
cookies, credentials, request bodies or fixture database contents are exported.

| File | SHA-256 |
| --- | --- |
| `rails-main-census.json.gz` | `f9495ceb0ea2e73ed0c140acb81c2143a2866dd142751c045dfff78d8c9da695` |
| `rails-main-census-evidence.tar.gz` | `b92ad425a6235d11d242419876a957c0ef79c85fbc99725bfeac4d91b76ff868` |
| `preload-links-rejected.json` | `b747ea67546c7c640a02a910ceb9d072448b15d4c8b3dffd47b629f4ddf5dad2` |

Initial setup diagnostics are retained privately: root-directory Rails
commands printed help before component/app cwd was corrected; Fizzy's board
index returned 406 for HTML and was replaced with its real board-show route;
an initial anonymous URI test subclass needed explicit constructor components.
These are setup failures, not excluded measured pairs. Ruby master needed an
explicit Ruby 4.0.7 baseruby and the correct ZJIT stats flag; the completed pinned
build was reused across all three modes.

**Ranked publication queue:** empty. The only experimental draft above is
rejected, no qualifying Rails commit exists, and no upstream action is
authorized by this report. The census, scripts, patches and report belong to
Lowrail branch `thomasklemm/rails-main-census`; fork main and the two separately
owned open PRs are untouched.
