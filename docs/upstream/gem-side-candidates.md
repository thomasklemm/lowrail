# Gem-side candidates, refreshed 2026-11-05

Three small **correctness** fixes are prepared on Thomas's forks, not submitted upstream. They repair observed
Rails-main failures rather than claiming speedups. Queue items: [BI1](../../bench/upstream/pr-queue/items/BI1.md),
[SC1](../../bench/upstream/pr-queue/items/SC1.md), [RA1](../../bench/upstream/pr-queue/items/RA1.md). Sol and Astra
belong to the coordinator; these items remain `in-review` until those exact-head passes exist.

## Selection and current capacity

Read the [ecosystem leads](ecosystem-tests.md#gem-side-leads-not-filed), [gem census](gem-census.md), both
[request](gem-request-census.md) [censuses](gem-request-census-2.md), [Inertia/Chatwoot](inertia-chatwoot-census.md),
[background census](background-census.md) and [contribution ledger](contributions.md). Ran `script/pr-queue status`
and searched GitHub directly. The queue only reports repositories represented by item files; it is not a complete
list of our gem PRs.

At the initial check, Rails had 20 open (15 non-draft). Our existing gem PRs included rack 2550, nokogiri 3759,
Propshaft 289, rack-mini-profiler 670, importmap-rails 336, i18n 763–766 and several inertia-rails PRs. These are
not fresh candidates. graphql-ruby and tzinfo were excluded as owned elsewhere, i18n as held. No ruby/ruby work.

Ransack 1792 **merged during this investigation**, at 21:52 UTC on November 5. A fresh GitHub query found **zero**
open Thomas PRs across ransack, blind_index and scimitar. Listing each repository's open PRs also found no overlap:
ransack has the maintainer's LIKE-predicate change 1794 and release PR 1758; blind_index and scimitar have none.
All three therefore have both unanswered slots available, not just a nominal open-count allowance.

Ranking: BI1 affects ordinary as well as indexed queries; SC1 prevents boot entirely; RA1 is narrower, fixing a
returned subquery manager's direct `to_sql` rather than normal `Search#result`. Ransack has the most active
maintainer and the broadest general Rails audience of these three. Scimitar and blind_index are slower-maintained
specialist gems, but both failures are concrete and the patches are tiny.

| Repository | Current upstream base used | Maintainer conventions and recent activity |
| --- | --- | --- |
| ankane/blind_index | `ddbf0240fe600b589ce1cacdc4a2277533b20c66`, master | README asks for `bundle exec rake test`; double quotes, small direct fixes. Andrew Kane's last release/fix was June 29; June's Mongoid fix responds to issue 61. The latest merged external PR is old (2021), so do not predict a fast review. No CONTRIBUTING or PR template. |
| pond/scimitar | `a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d`, main | Existing single-quoted engine style and lambda preserved. CI uses PostgreSQL and `bundle exec rspec`; last release March 6, external PRs 167/168 merged February 15. No CONTRIBUTING or PR template. |
| activerecord-hackery/ransack | `9bbadf13fc165ee5f195cd5b210e61ca37ffceed`, main | CONTRIBUTING asks for idiomatic two-space Ruby and passing specs; default SQLite plus PostgreSQL/MySQL adapters. Sean Carroll merged our one-line require fix today; external feature 1789 merged October 25. CHANGELOG now explicitly directs new entries to release notes, so historical entries are not edited. |

Re-fetched all three upstreams after the initial tests; bases were unchanged. During the review revision,
Ransack advanced to `1a4ad324fd5f9484caadcd5628a998d9211b9fea` (LIKE-predicate PR 1794); its subquery patch
is still built on the recorded base and checked for a clean merge. blind_index and Scimitar bases are unchanged.
Before building, searched **all states**, not
only open PRs, for `SelectManager`/`arel_table`, frozen metadata/Rails 8.2, and `parameter_parsers`/frozen. No
existing fix found. Search used `gh api -X GET search/issues -f q='repo:OWNER/REPO TERM'` (includes issues and PRs).

## Test environment and commands

Ruby **4.0.9** throughout. Rails main **`1e235cee11b0a7aecb189d8837534807626287aa`**, unchanged; Ransack's stable
control is the retained Rails **8.1.4** tree `c3466ea00d7121798e3aa3144ffdf7174b81d8cb`.
Other released controls are Active Record/Rails **8.1.4.1**, installed from RubyGems. PostgreSQL
**15.19**, SQLite gem **2.10.2**. Test pins are recorded, not compared across versions for a speed claim.

Local trees are under `.lowrail/gem-side/`. `Gemfile.main` in blind_index replaces its `~> 8.1.0` Active Record
development dependency with path gems `activerecord`, `activemodel`, `activesupport` from `../rails`, retaining
the other development dependencies (Minitest < 6). Scimitar's wrapper evaluates its Gemfile then adds path entries
for Rails and all its components. These are **harness-only**, never changes to upstream dependency policy.

```
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
# In blind_index:
BUNDLE_GEMFILE=Gemfile.main bundle exec rake test
bundle exec rake test
# In scimitar, after RAILS_ENV=test bundle exec rake db:schema:load in spec/apps/dummy:
BUNDLE_GEMFILE=Gemfile.main bundle exec rspec --no-color
bundle exec rspec --no-color
# In ransack (bundle install with the same RAILS path when switching controls):
RAILS=/absolute/path/to/rails-main bundle exec rake spec
RAILS=/absolute/path/to/rails-main bundle exec rspec spec/ransack/active_record/negative_collection_spec.rb
DB=pg DATABASE_USERNAME=user DATABASE_HOST=/var/run/postgresql RAILS=/absolute/path/to/rails-main bundle exec rake spec
RAILS=/absolute/path/to/rails-8.1.4 bundle exec rake spec
```

## BI1: blind_index frozen table metadata

Head **`b7d3502ea98aee5b8f1d9153828df88728d5b6fe`**, branch
[`thomasklemm/frozen-table-metadata`](https://github.com/thomasklemm/blind_index/tree/thomasklemm/frozen-table-metadata).
Library +5/−5, two focused tests and their table fixture added. On Ruby 4.0.9 with the pinned Rails main,
the model predicate builder's `TableMetadata` is frozen; the first ordinary `User.find_by(id: 1)` and indexed
lookup both try to memoize on it and raise `FrozenError` on base.

Read aloud: **Keep an existing capability memo; only skip creating it on frozen metadata.** No new helper,
cache, version branch or eager model load. Index derivation, normalization, predicate handling after the
capability check and uniqueness validation are unchanged. Mutable metadata keeps cached false across a late
`blind_index` declaration, including when a subclass is warmed before its parent declares. Freezing an already
warmed object retains its memo too. The helper extends Rails' internal `TableMetadata`: private `klass` and
model `respond_to?` overrides see more calls only when metadata is frozen without a cached value.

| Stack | Base | Head |
| --- | --- | --- |
| Rails main, SQLite, entire gem suite | original 50 runs, 46 assertions, **28 errors**, 1 skip | **52 runs, 92 assertions, 0F/0E, 2 skips** |
| AR 8.1.4.1, SQLite, entire gem suite | original 50 runs, 89 assertions, 0F/0E, 1 skip | **52 runs, 98 assertions, 0F/0E, 1 skip** |

The existing dynamic-finder test skips on AR ≥ 8.1; the mutable-metadata-only regression additionally skips
on main, where metadata starts frozen. The new query regression seeds plain-text row **7** and indexed row
**19**: a warmed query must still return `[7]`, not `[19]`, after declaring the index and after freezing its
metadata. Both direct-model and warmed-subclass/late-parent cases pass on base and the revised head; the
original candidate fails with `[19]`. The initially frozen test seeds **31** with a blind index for `frozen`
but different plaintext, and **47** with plaintext `frozen` but a different blind index. It raises `FrozenError`
on base, passes on head, and rejects an in-memory mutant returning false on frozen metadata (`[47]` versus
expected `[31]`). The final change from the preceding head only strengthens this test; library code and the
cost-control workload are unchanged.
Tests assert query results, not helper calls. The separate
[`blind_index_probe.rb`](../../bench/upstream/gem_side/blind_index_probe.rb) uses record IDs **7, 19, 31** and
distinct email values, matching/missing ordinary and indexed queries, a frozen hash with a frozen mixed
matching/nonmatching array, negation, NULL and string keys. Expected IDs are literal, independently derived
from those seeded rows. Base and head on released AR and head on main produced byte-identical JSON:

```json
{"ordinary":"first","missing":null,"indexed":19,"array":[19],"negated":[19],"null":[31],"string_key":[7]}
```

Run it in the gem bundle with `bundle exec ruby /path/to/Lowrail/bench/upstream/gem_side/blind_index_probe.rb`.
For the base control, extract the exact base `lib/blind_index/extensions.rb` with `git show` and set
`BASE_EXTENSIONS=/absolute/path/to/extracted.rb`; the probe loads that method definition after loading the gem.

### Cost control, not a speed claim

Changing the memo guard is on the query path, so checked `GemSideUser.where(id: 7).to_sql` on **AR 8.1.4.1**, where both
base and head run. Ruby 4.0.9 interpreter, existing `gem_request_census/ir_region.sh`, 500 warm calls and 2,000
measured calls; `(Ir(N) − Ir(0)) / N`, GC disabled after warmup, fixed heap floors **1,000,000 / 250,000 /
100,000 / 20,000 / 10,000** for pools 0–4 in all processes. One base / A/A / head cohort:

| Base Ir/call | A/A Ir/call | Head Ir/call | A/A | Head/base |
| ---: | ---: | ---: | ---: | ---: |
| 212,807 | 212,870 | 212,734 | +0.030% | −0.034% |

This is a cost control on the revised head, **not a speed claim**: a 0.034% delta on this micro is negligible.
The original candidate's separate cohort was 213,092 / 213,375 / 212,923 Ir/call (+0.133% A/A, −0.079% head),
rejected as speed evidence and not rerun until green. It does not price the revised code. No YJIT/ZJIT or
application-level claim. Numbers stay out of the correctness PR.

```
export RUBY_BIN="$HOME/.local/share/mise/installs/ruby/4.0.9/bin"
export BUNDLE_GEMFILE=/absolute/path/to/blind_index/Gemfile RUBYOPT=-rbundler/setup
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000
export RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
# BASE_EXTENSIONS set for base and A/A; unset for head:
bash bench/upstream/gem_request_census/ir_region.sh "$PWD/bench/upstream/gem_side/blind_index_probe.rb" \
  'GemSideUser.where(id: 7).to_sql' 2000 500
```

## SC1: Scimitar parser registration

Head **`a302bc09b8555d6da525adb51f64df26eb9651da`**, branch
[`thomasklemm/register-parser-with-writer`](https://github.com/thomasklemm/scimitar/tree/thomasklemm/register-parser-with-writer).
Engine registration +4/−1, two subprocess request regressions added. The pinned Rails main returns a frozen
parameter-parser registry; Scimitar mutates it during require, so boot fails before a request. Read aloud:
**Keep in-place registration on mutable registries; copy and use Rails' writer only for frozen registries.**
Lambda input, `JSON.parse`, MIME lookup and registration order are unchanged. On Rails 8.1.4.1 a registry
reference retained before loading Scimitar still configures the active parser afterward, just as on base.

| Stack, PostgreSQL, entire gem suite | Base | Head |
| --- | --- | --- |
| Rails main | require-time `FrozenError`, no examples load | **532 examples, 0 failures, 1 pending** |
| Rails 8.1.4.1 | original 530 examples, 0 failures | **532 examples, 0 failures** |

The existing request specs decode plain/nested/case-insensitive SCIM JSON and fail to load without the fix on
main. The new mutable-registry example is pending only on main, where the public registry is already frozen.
On released Rails, it returns `configured` on base and revised head, versus `original` on the first candidate.
The new frozen-registry example fails on base even on released Rails and passes on revised head. Both use a
fresh Ruby process and `ActionDispatch::Request#request_parameters`, without reloading an engine in place.
[`scimitar_probe.rb`](../../bench/upstream/gem_side/scimitar_probe.rb) additionally registers a custom
MIME parser **before** loading Scimitar, freezes the registry (also on released Rails), then sends requests
through `ActionDispatch::Request#request_parameters`. Checks: existing parser Proc identities preserved,
original registry not mutated, standard JSON still parses, custom MIME parser still runs, SCIM false/zero/
nested arrays and hashes intact, truncated JSON still raises `ActionDispatch::Http::Parameters::ParseError`
caused by `JSON::ParserError`. Released Rails and main outputs compare byte-for-byte. No request-path change
or performance claim. No private-method override is bypassed by the patch.

## RA1: Ransack direct subquery rendering

Head **`1290b01fcb9a78717365968c791e75fa28a1016d`**, branch
[`thomasklemm/correlated-subquery-arel-table`](https://github.com/thomasklemm/ransack/tree/thomasklemm/correlated-subquery-arel-table).
Library +1/−1. `Context#build_correlated_subquery` publicly returns an Arel manager. On Rails main,
`manager.to_sql` obtains its connection from the input table's `klass`; a model class does not have that
method. Read aloud: **Give the subquery manager the association model's Arel table, then build the same query.**
The existing `from(join_root.left)` still controls aliases and FROM. No query results are changed intentionally;
normal `Search#result` already uses a connection supplied through `subquery_sql` and was not generally broken.
An override of the internal join association's `base_klass` returning something other than a model now also
needs `arel_table`; model overrides of that undocumented hook affect this path too. No direct argument
conversions or collection operations are changed.

| Stack | Base | Head |
| --- | --- | --- |
| Rails main, SQLite, whole suite | 1,145 examples, 2 failures | 1,145 examples, **1 unchanged failure** |
| Rails main, PostgreSQL, whole suite | direct-render failure demonstrated in SQLite before the fix | **1,146 examples, 0 failures** |
| Rails 8.1.4, SQLite, whole suite | baseline covered by the ecosystem census | **1,145 examples, 0 failures** |
| Rails main, SQLite, negative collection specs | existing direct-render example fails | **76 examples, 0 failures** |

The remaining SQLite failure is `context_spec.rb:80`, `a table whose name differs only in case / can be searched
like Active Record queries it`, the uppercase/lowercase `Widgets`/`widgets` schema-cache case
already covered by queued Rails item E2. It fails on unchanged gem main, so was neither suppressed nor repaired
in this patch. Existing negative/correlated collection specs cover STI, polymorphic associations, aliases,
through joins, default scopes, empty collections, repeated evaluation and asymmetric matching rows. The
existing regression, `keeps the subquery buildable after an evaluation` in `negative_collection_spec.rb:578`,
calls `.to_sql` directly before and after evaluation. Targeted RuboCop: **1 file, 0 offenses**.

## Readability and reviews

These remain small correctness patches, with no new helper or code comment. BI1 now preserves the memo, and
SC1 branches only on registry mutability. Correctness fixes are judged by readability, not the performance
L0–L3 bars. The original reviewer called all three L0; the revised heads have fresh skeptical approval.
Measured with flog 4.9.4 and RuboCop 1.92.2 (`Metrics/AbcSize`, `CyclomaticComplexity`, `PerceivedComplexity`,
zero thresholds to expose the numeric values, not a claimed lint pass):

| Site | flog | ABC | Cyclomatic / perceived |
| --- | --- | --- | --- |
| BI1 `has_blind_indexes?` | 2.8 → 4.3 | 2.45 → 4.12 | 2/2 → 3/3 |
| RA1 `correlated_subquery` | 28.5 → 30.0 | 23.75 → 24.68 | 5/5 → 5/5 |
| SC1 class-body registration (`Engine#none` in flog) | 11.6 → 16.1 | not a method | not a method |

RA1's one extra `arel_table` send explains its score rise; it replaces an invalid Arel input with the same
model's table. BI1 adds a frozen guard to the memo write; SC1 conditionally copies and uses the documented
writer. No runtime request branch is added in SC1.

The first skeptical pass approved the original heads and bodies, but coordinator-run Sol and Astra both
requested changes for BI1 and SC1. Their public-API counterexamples were reproduced, not accepted merely as
private override boundaries: the first BI1 candidate changed a warmed query from plain to indexed results,
and the first SC1 candidate detached a mutable registry reference that apps can configure later. Both fixes
now preserve those released-Rails behaviors; the new tests fail on the original candidates and pass on the
revised heads. Old passes and findings remain in the queue history and do not count on the new heads.

Both reviewers gave RA1 nits, not code findings. Its body now pins Rails main, discloses the `arel_table`
override boundary, gives commands, and names the unchanged SQLite failure and existing direct-render test.
Its code/head is unchanged. The fresh skeptic approved SC1 and RA1 and gave BI1 only a nonblocking test-strength
nit, now addressed by the asymmetric frozen fixture above. It approved the final BI1 exact head and unchanged
body with no remaining nits. It reran BI's targeted tests/probe and additional exception/cached-value cases,
SC's engine specs/probe, and RA's direct-render file (76/0) plus its disclosed SQLite failure; it read, rather
than reran, the retained full-suite logs and Callgrind evidence. The coordinator will rerun Sol and Astra.
The deliberately frozen Scimitar probe is a negative control on base
even on released Rails, not a claim that base passed it.

GitHub reported **no hosted CI checks** on the original three pushed fork heads or the revised BI1/SC1 heads.
Local tests above are the evidence; absence of hosted checks is not a CI pass. No upstream submission was attempted.

## Rejected, covered or deferred leads

Fresh open-PR lists and current source, not just the old census, informed these decisions:

| Lead | Current check and reason not built |
| --- | --- |
| ViewComponent `with_request_url` host memos | Fixed on main `05b5c98b` via merged 2777 (November 4); existing tests now cover warmed URLs, nested errors and nondefault ports. No duplicate fix. |
| ViewComponent repeated digest reads | Main changed again in merged 2775 and commit `cef283f0` after census 2769. Active maintainer optimization work, no new cache layered onto it. |
| ViewComponent `Requested#locale` error path | Still calls the removed detail readers in `MissingTemplateError` on current main; Rails now exposes the index maps, not the original ordered detail arrays. Kept as an unbuilt compatibility lead, not described as already fixed; a cross-version error-formatting design/test is needed. |
| css_parser / premailer mailer CPU | css_parser main `1aa7d0a`; just merged substantial allocation/CPU work 193/194/195 (October 26–29) into declarations and shorthands. Open 184 owns selector splitting. Old mailer counts cannot price remaining work on that new parser; defer rather than guess or duplicate the recent tuning. |
| connection_pool keyword forwarding / Fiber leak | Current main `17c1eef` still forwards keywords; our interrupt-mask fix merged. The keyword path comes from the author's 223 and the Fiber lead still lacks a reduced public scheduler repro. Thread/fiber semantics, no small verified new finding; not built. No open PRs currently. |
| useragent `=~`, slices | Master `680915aa`, no pushes since December 2024; current Version still uses `=~`. Open 73 and a long list of external fixes remain. Tiny local substitutions do not solve repeated request parsing; defer to the recorded Rails-side decision-cache lead. |
| Rack query/scheme/ETag work | Main `da90464e`; open 2519/2520/2522 still cover it, and our 2550 already covers single cookie values. |
| Rack `clean_path_info` | Current main still splits and joins; 2302 and 2458 remain open in path handling. Security boundary plus overlap, not a fresh candidate. |
| Rack cookie key `match?` | Main still uses `=~`. Conversion and exception differences recorded in the census still apply; no public-API-compatible blind substitution. |
| Nokogiri reverse params / CSS cache | Main `2e0d3295`, our 3759 open; `extract_params` still makes the temporary hashes array. Census gain was near A/A, and a new CSS cache is a mechanism, not an obvious exact cleanup. No fresh effect measured; deferred. |
| GlobalID reparse / reject | Main `01a1a1cf` still splits and rejects blank model-id components; reparse validates, and the allocation-only reject change was too small. No change to validation for a speculative gain. |
| Jbuilder `_key` Symbol conversion | **Already fixed on current main**: the Symbol branch uses `key.name`. The old census lead is stale. |
| Turbo header env keys | Main `37530c08` still reads `request.headers["Turbo-Frame"]`; last push July 1, many unanswered external PRs; one String per read is a weak candidate. |
| importmap-rails preload helpers | Main last pushed October 9; our 336 still open. Existing work, no second overlapping performance PR. |
| AMS Minitest development pin | Default master `c6c38105` is the development skeleton; maintained `0-10-stable` at `6934c8bd` still pins `< 5.11`. Development-tool migration with many unanswered PRs, not runtime CPU or a proved public Rails-main bug. |
| cancancan Bundler pin / ostruct | Main `4362b39b` still has development `bundler ~> 2.0`; no open PRs. Harness/development compatibility is below the selected runtime failures, not a request-CPU candidate. |
| paper_trail Active Record cap | Master `86ce1b83` **does not cap installation**: gemspec deliberately has no upper bound. `Compatibility::ACTIVERECORD_LT = "< 8.2"` is a warning pending tested compatibility, not a dependency-resolution bug. Do not remove the warning to claim support. |
| Appraisal `eval_gemfile` | Main `602cdd9b` still has its own `BundlerDSL`; open 247 covers another DSL addition. Harness integration issue, not a gem runtime fix. |

No upstream issue, PR, comment, ready-state change or deployment was made by this worker. New forks created
only for blind_index and scimitar. Existing Ransack fork reused. Commit author and committer are Thomas Klemm
`<github@tklemm.eu>`; no Amp or co-author trailers.
