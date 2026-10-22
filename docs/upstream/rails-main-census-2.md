# Rails-main census continuation (bet U2)

2026-10-22. Continuation of [bet U](rails-main-census.md), not a new census
or a Lowrail runtime change. Ranks **16–60** were screened in order. The
explicit C2 cache lead was also investigated, including the decoder site
at original rank 352. Ranks after 60 otherwise remain untried. The ranked
pool includes default gems; those are identified rather than proposed to
rails/rails. **One allocation-only candidate qualifies: rank 52.** Its clean
[fork commit](https://github.com/thomasklemm/rails/commit/351e4c0599b8bcbfdfeab1622edadd71476dbf62)
is published for a separately owned PR review. No upstream PR, issue,
comment or main write was made here. The cache Range prototype is rejected.

## Pins and scope

* Original ranking: Lowrail
  [`aeb6f064445db51d418ab22d3f7ef36579307898`](https://github.com/thomasklemm/lowrail/commit/aeb6f064445db51d418ab22d3f7ef36579307898),
  Rails `33748f4f60e68eeeed0d48ac566d345415dc78f4`, four apps / twelve routes.
* Reproductions and drafts: refreshed Rails main
  [`ab5a78a7c221915cbf09c2824068c4479d144f91`](https://github.com/rails/rails/commit/ab5a78a7c221915cbf09c2824068c4479d144f91).
  The screened Rails source sites are unchanged between these two pins.
  #59270 is already merged at the new pin; this work does not alter it.
* Correctness: Ruby 4.0.7, revision `229531a6cf`. Three-mode experiment:
  Ruby master
  [`5f2bc22560e9063fb8dec736afbf378251cad3ec`](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec),
  built with YJIT and ZJIT. This is the same Ruby pin used in U, not a
  selectively newer compiler after observing a regression.
* These are source screens and method/helper reproductions on main. The
  original app receipts are reused for prioritization, **not relabeled as
  new whole-request measurements**. No app/config/schema change and no
  Lobsters access. No Lowrail support or request-speed claim.

## Ranked dispositions

The scores and app weights remain in the unchanged
[full ranking](rails-main-census-sites.tsv). “Rejected” below rejects the
named small shortcut, not every possible future algorithm. `AV`, `AS`, and
`AR` mean the corresponding Rails component's `lib` directory. URI and JSON
are the census-pinned default gems.

| Rank | Site / operation | Disposition |
| ---: | --- | --- |
| 16 | URI `common.rb:108`, scheme-name conversion | Outside Rails. Scheme-to-constant conversion; no Rails patch. |
| 17 | URI `rfc3986_parser.rb:85`, absolute match | Outside Rails. MatchData supplies the captured components; `match?` is not a replacement. |
| 18 | AS `core_ext/enumerable.rb:88`, `index_with` | Covered/rejected previously: #59108 was reverted by #59203 for Ruby 4.1 small-Hash spills. Not revived. |
| 19 | AV `helpers/asset_tag_helper.rb:715`, early hints | Reject sharing a single link String or Hash: the request callback receives mutable headers, while the later response-header path still uses the local links. The join is not a disposable copy of an immutable argument. |
| 20 | AV `helpers/asset_url_helper.rb:248`, `File.extname` | Reject replacing extension parsing with `end_with?`: dotfiles and arbitrary `:extname` strings differ. No small exact parser replacement. |
| 21 | AR `relation/delegation.rb:140`, relation construction | Fresh mutable relation, model-specific delegate class and state. No shared scope instance. |
| 22 | AR `arel/table.rb:91`, Attribute | Mutable table/name node is part of the caller's AST. No shared cached node. |
| 23 | AR `relation.rb:78`, default values Hash | Each relation owns mutable values. Sharing the default aliases independent scopes. |
| 24 | AV `helpers/tag_helper.rb:1597`, self-closing output | Fresh returned markup String/SafeBuffer, not an intermediate collection. Earlier SafeBuffer refusals apply. |
| 25 | AR `relation/where_clause.rb:117`, extracted attributes | The fresh mutable result Array escapes; a shared/frozen empty result changes ownership. Empty-merge retiming is excluded. |
| 26 | AV `helpers/tag_helper.rb:1741`, tag output | Fresh returned markup. No input/result sharing or SafeBuffer constructor shortcut. |
| 27 | AV `helpers/tag_helper.rb:1537`, content-tag output | Fresh returned markup. The tag-attribute rewrite is already covered by #59117/#59244. |
| 28 | AR `relation.rb:99`, values duplication | Copy-on-spawn ownership: later scope changes must not mutate the parent relation's Hash. |
| 29 | AS `core_ext/hash/keys.rb:14`, stringify_keys | Fresh mutable Hash, including when every key is already a String. Returning self aliases the source. Executed non-mutation witness. |
| 30 | URI `rfc3986_parser.rb:116`, path capture | Outside Rails; captured component String enters the public split/URI result. |
| 31 | URI `rfc3986_parser.rb:122`, component capture | Outside Rails; same component ownership boundary. |
| 32 | JSON `common.rb:297`, parse kwargs | Outside Rails. Keyword options Hash, not a Rails intermediate or cache-entry reconstruction pool. |
| 33 | URI `generic.rb:335`, lowercase scheme | Outside Rails. Scheme conversion and receiver state, not a Rails candidate. |
| 34 | URI `rfc3986_parser.rb:87`, scheme capture | Outside Rails; public component String. |
| 35 | URI `rfc3986_parser.rb:102`, authority capture | Outside Rails; public component String. |
| 36 | URI `rfc3986_parser.rb:104`, path capture | Outside Rails; public component String. |
| 37 | URI `rfc3986_parser.rb:107`, query capture | Outside Rails; public component String. |
| 38 | AR `arel/nodes/select_statement.rb:11`, cores | Mutable per-statement AST core/Array. Sharing across statements changes later query construction. |
| 39 | URI `common.rb:274`, join forwarding | Outside Rails. Variadic argument collection for URI joining. |
| 40 | URI `generic.rb:1029`, merge scratch | Outside Rails; mutating merge-path algorithm, not a Rails elision. |
| 41 | URI `generic.rb:1051`, merge scratch | Outside Rails; same algorithm, including dot/parent-segment handling. |
| 42 | URI `generic.rb:1063`, reduced path | Outside Rails; #242 already changed the loop before URI 1.1.2. |
| 43 | URI `generic.rb:1086`, joined path | Outside Rails; the returned path becomes observable URI state. |
| 44 | URI `generic.rb:1149`, URI duplication | Outside Rails; public non-destructive merge requires receiver isolation. |
| 45 | URI `http.rb:132`, origin | Outside Rails; fresh public result String. |
| 46 | AV `structured_event_subscriber.rb:73`, root stripping | Reject prefix-only replacement. Current `sub` also removes an interior occurrence of rails_root; executed asymmetric witness. A fresh String protects the event identifier from the subsequent `sub!`. |
| 47 | AS `notifications/fanout.rb:379`, group instances | Required per-event timing/subscriber state. Empty mapping is already covered by #59235; no handle/group reuse. |
| 48 | AR `relation/predicate_builder.rb:144`, flat_map | Fresh predicate collection across scalar, tuple, association and aggregation cases. No small exact elision established. |
| 49 | AR `relation.rb:1342`, values snapshot | Fresh mutable public snapshot. Returning the internal Hash exposes relation state. |
| 50 | AV `helpers/asset_url_helper.rb:219`, asset URL output | Fresh returned String after live path/host dispatch; returning a retained override result changes aliasing. Tail rescanning already covered by #58270. |
| 51 | AR `abstract/database_statements.rb:872`, empty intents | **Rejected with counterexample.** Early-returning the empty queue aliases the returned Array to live adapter state; main returns a detached Array. Details below. |
| 52 | AV `helpers/asset_tag_helper.rb:229`, uniq/map | **Qualifying allocation-only draft:** map in place over the fresh `sources.uniq` Array; same change in JavaScript sibling. One Array saved per helper in all cases/modes, no resolved timing regression. No preload-buffer operator change. Fork commit and caveats below. |
| 53 | AV `helpers/asset_tag_helper.rb:232`, preload String | Required link output used by both header paths. Do not conflate it with the extra concatenation copies. |
| 54 | AV `helpers/asset_tag_helper.rb:236`, nopush append | Prior U prototype is rejected for ZJIT regression. Not retimed or combined with rank 52. |
| 55 | AV `helpers/asset_tag_helper.rb:239`, tag options Hash | Mutable options passed to live tag helper overrides; sharing a template Hash changes ownership and mutation behavior. |
| 56 | AV `helpers/asset_url_helper.rb:351`, path options Hash | Fresh merged options preserve caller non-mutation and live `path_to_asset` override behavior. No shared/frozen Hash. |
| 57 | AS `core_ext/array/extract.rb:16`, extracted elements | Public fresh mutable result while the receiver retains nonmatching elements. Required output, not scratch. |
| 58 | AS `notifications/fanout.rb:378`, group Array | Active-event group instances need independent lifetimes; empty mapping already covered by #59235. |
| 59 | AS `notifications/fanout.rb:381`, Handle | Per-event state/payload and start/finish lifecycle; not reusable between nested or concurrent events. |
| 60 | AR `relation/query_methods.rb:1755`, WhereClause | Per-query predicate ownership. No memoized/shared mutable clause; existing empty-clause work is not revived. |

### Rank 51's return-ownership counterexample

The two-line prototype added `return intents if intents.empty?` before
replacing `@unfinalized_intents`. On a real SQLite connection:

```ruby
returned = connection.finalize_remaining_intents
returned << :caller_mutation
connection.finalize_remaining_intents
```

Clean main returns `[]`. The prototype raises `NoMethodError` for
`:caller_mutation.finalized?`. Returning nil changes the method's result;
returning a fresh Array still allocates. This rejects the simple guard, not
a larger redesign of the intent lifecycle. The rejected diff and executed
output are retained; no timing cohort or fork commit was made for it.

### Upstream overlap check

Read the recent history of both changed files and searched Rails open and
closed PRs/issues for Coder, byteslice, cache allocation, sources/uniq/map,
stylesheet_link_tag, string_fastpath, unfinalized_intents and fanout.
The nearby open #59225 and #51441 change `preload_link_tag` nonce/opt-out
behavior, not the two map sites. Open #58703 is Action Cable broadcasts,
not the cache-entry decoder. The returned diffs were inspected, not just
their titles. Merged #57502's malformed-frame handling is preserved.
#59235 covers empty notification groups, not active-event object reuse.
No covering open/merged proposal was found for either U2 prototype;
negative search results are bounded evidence, not universal absence.

Immediately before publication, the API still identifies `main` as Rails'
default branch. A fresh `pull --rebase upstream main` left the candidate's
base at `ab5a78a7c221915cbf09c2824068c4479d144f91`. Open/closed searches for
`sources uniq`, `stylesheet_link_tag allocation` and
`javascript_include_tag allocation` returned no duplicate. The unrelated
hits were #42095 (generated attributes), #58270 (asset-tail scanning), and
#30744 (the original Early Hints implementation); original nearby proposal
diff checks remain applicable. Raw searches are retained.

Read root `AGENTS.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`
and `guides/source/contributing_to_ruby_on_rails.md` at this pin. No
AI/LLM-contribution prohibition was found in those files; root AGENTS
explicitly addresses AI coding agents. This is a scoped policy check, not
a claim about every possible external policy. The template requests a
ready-for-review PR, not a GitHub Draft PR, and the guide asks for scripts,
representative cases and regression measurements. Any upstream PR is left
to the coordinator's separate review/submission thread.

## C2 lead: which objects can actually disappear?

C2 is pinned at
[`490aef80cf974e8632431a21fc02368c25aab7f4`](https://github.com/thomasklemm/lowrail/commit/490aef80cf974e8632431a21fc02368c25aab7f4).
Its CodeTriage 7/3/6 transient objects are **not seven removable Rails
wrappers**:

1. Dalli's encoded-entry String is an independently decoded network value.
   Rails #54996 already proposed bypassing Dalli serialization and was
   closed in favor of [Dalli #1041](https://github.com/petergoldstein/dalli/pull/1041).
   The maintainers explicitly rejected breaking old flagged entries with
   a no-op serializer. Rails #56652 later kept `serializer: Marshal` and
   noted the desired follow-up. No duplicate bypass PR is drafted here.
2. Dalli already offers **`string_fastpath: true`**. Its client-level option
   was fixed in 5.0.4; C2's 5.1.0 has that fix. Old SERIALIZED entries are
   still loaded normally; eligible new BINARY/UTF-8 Strings use flags.
   The option is currently opt-in. Enabling it as a new Rails default is
   a compatibility/defaults proposal, not the one-line exact elision sought
   here. No app was reconfigured to manufacture a gain.
3. Coder marshals non-UTF-8 versions, or versions beginning with Marshal's
   signature, to retain encoding and distinguish the format. `Entry#version`
   remains observable and mismatches must keep working. Forcing UTF-8 or
   stripping the Marshal envelope is not an exact format-compatible fix.
4. There **is** unrelated decoder scratch: every signed 7.1-format load
   creates an endless Range to slice the payload. Using
   `byteslice(offset, dumped.bytesize)` takes exactly the same remaining
   bytes (oversized lengths truncate), including empty/truncated frames,
   without a Range. It leaves the encoded String, version decoding,
   lazy Entry, serializer and compressor paths intact.

The Range is original **rank 352**, not a new top-60 discovery. U's raw
interpreter receipt shows 5/4/3 Ranges per Fizzy route and 1/1/0 per
Writebook route. The aggregate site also includes payload Strings, which
are **not saved**. MemoryStore's default DupCoder does not take this path;
FileStore, RedisCacheStore and MemCacheStore using the default 7.1 coder do.
These counts are exposure from the old receipts, not measured request
savings on the new patch. C2's 7/3/6 numbers likewise are not rescored.

### Fresh cross-store read/fetch reproduction

A synthetic, C2-shaped **hit batch** on clean main uses 3/1/4 HTML-string
entries with respectively 2/1/1 US-ASCII versions. Explicit cache format
7.1, Ruby 4.0.7, Dalli **5.0.6** (not C2's 5.1.0). Real disposable Redis
and Memcached servers are used. Both `read` and hit `fetch` return the
expected values and give the same attribution:

| Store | Home-shaped batch | What-shaped batch | Repository-shaped batch |
| --- | ---: | ---: | ---: |
| MemoryStore, default DupCoder | 0 | 0 | 0 |
| FileStore | 4 | 2 | 2 |
| RedisCacheStore | 4 | 2 | 2 |
| MemCacheStore, defaults | **7** | **3** | **6** |
| MemCacheStore, explicit `string_fastpath: true` control | 4 | 2 | 2 |

These count **only objects attributed to `<internal:marshal>`**, all
Strings, not total batch allocations. The fastpath control removes the
outer 3/1/4 entry Strings; two Strings per encoded version remain. This
reproduces the allocation mechanism, not CodeTriage requests, payloads or
the exact C2 dependency lock. The probe source and JSON are archived.

## Single-cohort results

Each prototype gets one independent cohort: **12 triplets per mode**,
fresh processes for clean A / clean B / prototype, the six predetermined
order permutations repeated twice, CPU 2, interpreter/YJIT/ZJIT on the same
pinned Ruby master. No builds, tests or other performance workers ran
alongside timing. The scripts are
[`census_2_pairs.rb`](../../bench/upstream/census_2_pairs.rb),
[`census_2_worker.rb`](../../bench/upstream/census_2_worker.rb), and U's
unchanged corrected [`preload_links.rb`](../../bench/upstream/preload_links.rb).

Coder: 30,000 warm operations, 5,000 GC-enabled allocation operations,
200,000 timed operations per case. Assets: 20,000 warm / 5,000 allocation /
20,000 timed operations per case. Process CPU time, paired log ratios,
10,000 percentile bootstrap resamples, seed 41231. Ratios are clean A CPU
divided by prototype CPU: below 1 means slower. This is not the fixed-heap,
Callgrind, three-window Lowrail request protocol. **Allocations are primary;
there is no admitted speed or instruction-count claim.** Every case, A/A
control and rejected window is retained, without a replacement cohort.

### Cache payload slice — rejected; do not submit

The one-line Range removal saves exactly one object per signed load in all
three modes. It leaves the legacy path unchanged. Nevertheless, ZJIT's
binary-version and compressed cases have resolved regressions, so **no
fork commit or qualifying draft exists**. The working source was restored;
the exact diff is retained in the archive.

| Case | Objects before → after | Interpreter CPU ratio [95% CI] | YJIT CPU ratio [95% CI] | ZJIT CPU ratio [95% CI] |
| --- | ---: | --- | --- | --- |
| Plain UTF-8 | 5 → 4 | 1.1195 [1.0972, 1.1414] | 1.0355 [1.0190, 1.0511] † | 0.9545 [0.9191, 1.0075] † |
| Binary version | 8 → 7 | 1.0585 [1.0405, 1.0788] | 1.0165 [1.0064, 1.0278] | **0.92486 [0.91345, 0.93726]** |
| Compressed object | 15 → 14 | 1.0154 [0.9935, 1.0365] | 0.9835 [0.9575, 1.0074] | **0.94612 [0.90274, 0.98272]** |
| Legacy control | 10 → 10 | 1.0016 [0.9785, 1.0258] | 1.0205 [0.9861, 1.0778] | 0.9519 [0.8808, 1.0050] |

† The first timed `times` loop still compiles one ISeq in **all 36 plain
windows in each JIT mode**, despite the operation warmup. Those plain JIT
ratios are diagnostic, **not JIT-flat speed evidence**. Binary-version,
compressed and legacy windows have zero recorded compilation/invalidation/
code-GC deltas. The worker is not fixed and retimed after observing this.
The nonflat first case does not explain away the later flat regressions.
The plain interpreter A/A ratio also excludes parity:
**0.98529 [0.97472, 0.99603]**; all other Coder A/A intervals include 1.
Thus an A/A-based speed admission would fail independently. Allocation
counts include a constant 0.0002/op observer overhead in the first case,
omitted in the rounded table but retained in raw data.

### Rank 52: reuse unique asset sources — qualifying allocation-only draft

Published branch: `thomasklemm/rails:thomasklemm/reuse-unique-asset-sources`.
Commit:
[`351e4c0599`](https://github.com/thomasklemm/rails/commit/351e4c0599b8bcbfdfeab1622edadd71476dbf62).
Exactly two changed lines, no helpers, caches, test rewrites or format
changes. Both asset-tag methods change `sources.uniq.map` to
`sources.uniq.map!`. The fresh local Array from `uniq` has not escaped;
mapping into it does not mutate caller-owned source arrays or elements.
Deduplication, source order and all path/tag/nonce dispatch remain intact.

| Case | Interpreter objects before → after | Interpreter CPU ratio [95% CI] | YJIT CPU ratio [95% CI] | ZJIT CPU ratio [95% CI] |
| --- | ---: | --- | --- | --- |
| Default stylesheet | 29 → 28 | 1.0121 [0.9934, 1.0363] | 0.9990 [0.9852, 1.0123] | 1.0232 [0.9968, 1.0512] |
| Stylesheet, all options | 37 → 36 | 1.0057 [0.9873, 1.0210] | 0.9999 [0.9910, 1.0084] | 1.0050 [0.9655, 1.0324] |
| Default JavaScript | 29 → 28 | 1.0052 [0.9999, 1.0099] | 0.9990 [0.9849, 1.0111] | 1.0191 [1.0121, 1.0275] |
| JavaScript, all options | 37 → 36 | 1.0125 [0.9878, 1.0345] | 1.0001 [0.9772, 1.0228] | 1.0063 [0.9964, 1.0153] |
| Module script | 31 → 30 | 1.0005 [0.9902, 1.0114] | 1.0094 [0.9955, 1.0272] | 1.0218 [1.0092, 1.0367] |
| Three stylesheets | 64 → 63 | 1.0072 [0.9882, 1.0284] | 0.9947 [0.9819, 1.0060] | 1.0054 [0.9928, 1.0161] |
| Nopush disabled | 28 → 27 | 1.0045 [0.9795, 1.0279] | 1.0107 [0.9897, 1.0357] | 1.0152 [1.0098, 1.0208] |
| Preload disabled | 22 → 21 | 0.9489 [0.8669, 1.0184] | 1.0113 [0.9963, 1.0277] | 1.0078 [1.0018, 1.0127] |
| Deferred JavaScript | 22 → 21 | 0.9988 [0.9631, 1.0304] | 1.0079 [0.9944, 1.0264] | 1.0522 [1.0027, 1.1360] |

One Array is saved in **every one of 27 case/mode cells**, in all 12
triplets. YJIT/ZJIT all-options cases have two additional objects in both
arms (39 → 38, not the interpreter's 37 → 36). First-case counts include
the same 0.0002/op observer overhead. A three-source call still saves only
one Array, not one per source. The last two cases disable preload work,
not the changed map operation, so also save an Array.

No A/draft 95% interval resolves a regression in any of the three modes.
All recorded compilation/invalidation/code-GC deltas are zero in all
measured asset windows. Nevertheless, two **ZJIT A/A** controls exclude
parity: nopush disabled **0.96794 [0.91416, 0.99958]** and preload disabled
**0.99213 [0.98709, 0.99667]**. They are retained, not rerun or dropped.
The other 25 A/A intervals include 1. Thus the candidate meets the
**fewer-allocations alternative**, with no resolved measured regression;
it is **not admitted as a speed gain**, including the apparent ZJIT wins.
Failure to resolve a regression is not a proof of equivalence or a tighter
non-inferiority bound. No whole-request saving or Ir claim is made.

## Validation and publication

The fork commit was published only after the single prospectively fixed
three-mode cohort and fresh upstream-main rebase/checks. No prototype is
admitted merely because tests pass or objects decrease. A resolved
interpreter/YJIT/ZJIT regression, including in a control, excludes it rather
than triggering another timing attempt. Thomas Klemm <github@tklemm.eu>
is both author and committer; the commit has no trailers. No PR was opened.

Correctness inputs are retained in
[`census_2_controls.rb`](../../bench/upstream/census_2_controls.rb). They
cover ordinary/binary/US-ASCII/non-UTF-8 payloads, nil/empty/binary versions,
Marshal-signature versions, compression, expiry, each byte truncation,
negative/oversized length fields and 250 fixed-seed frame mutations.
Public read/fetch/mismatch/expiry/non-aliasing controls use actual
MemoryStore/FileStore/RedisCacheStore/MemCacheStore. **900 snapshots match**
clean main and the Range draft on Ruby 4.0.7. These are bounded controls,
not universal arbitrary String-subclass override coverage. Direct Coder
controls use the 7.1 envelope; store controls keep standalone AS's default
7.0 format. The separate fresh store probe above explicitly uses 7.1.

The unchanged corrected U worker also covers returned HTML bytes,
encoding/class/safety/frozen state, Link response headers, early hints,
nonce calls, duplicate sources, caller non-mutation and header-size/error
boundaries. **165 snapshots match** for the map! prototype, including
ZJIT. They also match after rerunning both arms on the exact published
head. The original rejected preload-buffer patch is never applied.

Relevant unchanged suites, serial, `MT_CPU=1`, Ruby 4.0.7:

* All cache suites: **2,139 tests / 9,035 assertions**, no failures, errors
  or skips. Two clean off-only runs for **each** seed 41231 and 1729, then
  the Range draft at each seed, have identical sorted test identities,
  assertion counts and outcomes (not just identical totals).
* Full Action View: clean main and map! draft each **2,901 / 6,865;
  249 / 338; 173 / 334**, no failures, errors or skips, seed 41231. Repeated
  with the same results on the exact rebased/published fork commit.
* Rails RuboCop: changed framework files plus the three new reproduction
  scripts, **five files, no offenses** before timing. Exact-head check:
  asset helper plus three scripts, **four files, no offenses**, explicitly
  using Rails' `.rubocop.yml`. An initial exact-head invocation omitted
  `--config`, so the external Lowrail scripts were checked against default
  RuboCop rules (162 style offenses); the framework file itself was clean.
  Correcting config selection required no code changes. Both logs remain.
  No Rails test or assertion changed.

Setup diagnostics are not admitted gates: the first full AS run started
before disposable cache daemons existed (1,765 skips); an exploratory full
AR run for the later-rejected intent guard lacked the sqlite3 CLI (four
errors / 52 skips). The missing services/CLI were installed. No passing AR
gate is claimed or required for the AS/AV-only drafts. The ZJIT worker's
stats accessor was corrected during untimed smoke setup before the cohort.

## Reproduction and handoff

The [evidence archive](rails-main-census-2-evidence.tar.gz) contains both
complete cohorts (108 raw workers each), summaries, all A/A controls,
source hashes, snapshots, per-test receipts, suite/lint/setup logs,
synthetic store probe, rejected patches, the published patch, policy-file
snapshots and a checksum manifest. Its README describes setup and exact
entry points. Ruby source/build trees and binaries are excluded.

The asset helper's benchmarked source hash is identical to the published
fork source. After the prospective cohort, `pull --rebase upstream main`
made no source change. Full Action View was rerun on that exact commit:

```sh
# From the fork's actionview directory, with Ruby 4.0.7:
BUNDLE_ONLY=default:test:rubocop:cable:db PARALLEL_WORKERS=1 MT_CPU=1 SEED=41231 bundle exec rake test
# From the fork root:
BUNDLE_ONLY=default:test:rubocop:cable:db bundle exec rubocop --config .rubocop.yml actionview/lib/action_view/helpers/asset_tag_helper.rb
```

The one handoff candidate is **rails/rails**, branch
`thomasklemm/rails:thomasklemm/reuse-unique-asset-sources`, commit
[`351e4c0599`](https://github.com/thomasklemm/rails/commit/351e4c0599b8bcbfdfeab1622edadd71476dbf62).
It needs the coordinator's separate correctness/maintainability and
semantic reviews before an upstream PR. The scope is only the two map!
sites, not U's rejected preload concatenation or the rejected cache Range
change. No additional candidate was established in ranks 53–60; this
bounded continuation stops at 60 rather than implying the lower ranks
are exhausted. Lowrail evidence is published on
`thomasklemm/rails-main-census-2`, not main.
