# Upstream findings

Profiling findings that are best fixed in the gem that causes them, so every
user of that gem benefits. Lowrail passes cover apps on older versions; the
upstream fix removes the cause.

| Finding | Measured | Gem / version | Proposed fix | Status |
|---|---|---|---|---|
| Cheap method-lookup assumption checks without suppressible Ruby hooks | Fizzy `/bubbles`: 20 global-epoch bumps/request, zero invalidations of 12 selected held tokens; reviewed token read/guard 184/202 interpreter, 103/106 YJIT Ir; C check 26 Ir | MRI master base `cfa50b0` | Experimental scoped method tokens; global epoch rejected for churn | Owner posted [Feature #22459](https://bugs.ruby-lang.org/issues/22459); [review fix](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5), 13 tests/97 assertions on interpreter and YJIT. [Evidence](upstream-drafts/ruby-method-token-evidence.md) and unposted correction/cost drafts; detached pinned cohort passed A/A, heap and JIT gates; first post-fix attempt remains INVALID for harness drift. No upstream PR |
| `InertiaRails::Configuration` binding re-extracts the option Hash and scans props on every render | Lowrail micro 4.5–5.6 → 2.1–2.3 µs/bind, 5 → 3 objects ([pass](passes/inertia-config.md)); PR's synthetic YJIT pairs −38.6 to −143.3 µs/request | `inertia_rails` 3.21–3.23 | Cheaper configuration binding and plain-data scans | [PR #437](https://github.com/inertiajs/inertia-rails/pull/437) open, upstream CI pending |
| `Manifest#digest` re-reads and MD5-hashes the Vite manifest on every call; with a lazy Inertia version proc that is every request | ~279 µs/call; 12.8–15.8 % self per Inertia JSON request (private app, aggregates only). Version computed once at boot: two pages −19 % and −23 %, one within noise (production mode, 5 interleaved pairs) | `rails_vite` 0.3.0 | Memoize the digest outside `Rails.env.local?` like `Manifest#data`; do not cache `"no-manifest"` | [issue #56](https://github.com/skryukov/rails_vite/issues/56), [PR #57](https://github.com/skryukov/rails_vite/pull/57) open; the private app sets the version once at boot meanwhile (merged) |
| CSP importmap processing (`InlineScriptHashes#script_locations`) on every cached page | M0: 34.8% inclusive; 90 joins / request for one location. Method micro: 1265.45 → 26.56 µs; instruction A/A failed, not an accepted request-speed claim | **Campfire app code**, not an uncached importmap-rails 2.2.2 / Propshaft 1.3.2 resolver | Parse the request base once, keep `URI.join` per import (180 → 91 parses); the earlier process-local cache draft was not published | [PR basecamp/once-campfire#374](https://github.com/basecamp/once-campfire/pull/374) open: method 1,682 → 678 µs/call (YJIT), 5,696 → 2,306 allocations; CSP/HTML byte-identical; request medians noisy, no request claim; hosted CI green. [Investigation](passes/importmap.md): whole-method Lowrail reuse refused under Rails' regexp timeout; no new pass or setup hook |
| `SchemaContext::Attributes#builder` builds a new `AttributeSet::Builder` and a primary-key defaults subset on every `attributes_builder` call (about 4 objects per loaded row) | Campfire `Message` load-only: 60.8 → 37.2 µs at 20 rows with a guarded per-model variant (`+ar_instantiate`) | Rails main at e3d5c569 (Campfire's pin) | none needed | **already fixed upstream**: [rails/rails@f126797d45](https://github.com/rails/rails/commit/f126797d45) (2026-10-15) builds the builder once. Campfire's pin predates it; the pass's alpha gain will disappear on current main |
| `MessagesHelper#message_fragment_cache_key` serializes live message/room/creator/body/boost dependencies and SHA-256 hashes them during collection cache-key construction | **14.08%** of uncached-room request raw-stack weight allocated exclusively to this helper's subtree (Lowrail absent, production Ruby 4.0.7 +YJIT, StackProf wall, 1,000 requests; response cache off, fragment caches warm). Cost share, not intrinsic self time or removable saving | **Campfire app code**, corpus pin, not an Action View/I18n defect | Investigation only: preserve content-based detection of foreign SQL edits and attachment/direct-room boundaries; timestamp-only memoization is not equivalent | Recorded privately in [the ERB profile](passes/erb.md); **no app change, pass, issue or PR**. No publication or speed claim |

## General Rails hotspot audit (2026-10-21)

Compared the [hotspot map](passes/hotspots.md), [allocation census](passes/allocations.md),
[tag component](passes/tag-options.md), [source sites](passes/tag-options-sites.md),
[blank audit](passes/string-blank.md), [lookup survey](passes/template-lookup.md),
[sealed form/token/collection prices](passes/sealed-form.md), and both backlog
tables in [DECISIONS.md](DECISIONS.md) with canonical Rails main
[`6e8d3903f8`](https://github.com/rails/rails/commit/6e8d3903f85dd948d726bee9495ea77bc8e50aaa).
GitHub searches covered open, closed and merged PRs; the important overlapping
patches were read, not inferred from their titles. Negative search results are
not proof that no related work exists.

**Admission rule:** an upstream change cannot use a boot certificate, freeze
application configuration, inline a replaceable Rails helper, cache subscriber
absence, or assume that a model/resolver/type stays unchanged. Retain live
method dispatch, default evaluation, callbacks, subscriptions, escaping,
encoding, HTML safety and output ownership. The isolated Lowrail −11.1% token
and −9.9% collection instruction prices are **not upstream benchmark results**.
No Callgrind slots were used by this audit.

### Candidate table

| Candidate / discovery pool | Unconditional version and upstream cross-check | Verdict |
|---|---|---|
| CSRF / hidden-token tags | The general option-copy, token-decoding and HMAC setup reductions are already in [#59106](https://github.com/rails/rails/pull/59106). The remaining sealed literal markup would bypass live `tag`, forgery/token overrides, autocomplete policy, escaping and safety. Keep fresh masking and per-form token computation. | Drop solved work; refuse literal-token fusion. |
| `tag_options`, attribute building, literal form/tag scaffolds | Attribute-buffer appends and Symbol names are already in [#59117](https://github.com/rails/rails/pull/59117) / [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b). Generic nested-Hash prefixes are a separate main behavior. Remaining literal-form elimination depends on replaceable builders, models, I18n and config. | Drop solved appends; no unconditional sealed scaffold. |
| Collection rendering / setup | Shared ERB buffer is already [#59118](https://github.com/rails/rails/pull/59118), with subclass [#59155](https://github.com/rails/rails/pull/59155) and handler [33fc52d0](https://github.com/rails/rails/commit/33fc52d0d9402fb62baff403c6d40ae45204779d) corrections. Keep caching, non-ERB handlers, layouts, subclass hooks, iteration and dynamic partial selection. | Drop; do not resubmit fusion or bypass the corrected boundaries. |
| `String#blank?` | Main already has the ASCII loop ([7234e94d](https://github.com/rails/rails/commit/7234e94d0b007055126a3fd55115db8e3beb8568), [7ef6a408](https://github.com/rails/rails/commit/7ef6a40816e3765e20e5ee8c5c1d586983935da4)). No new implementation. That upstream API change does not make an exact 8.1 backport: regexp timeouts, constants and subclass hooks differ. | Drop; already upstream. |
| Template lookup / template path prefix | First-match lookup and normalization reductions are [#57783](https://github.com/rails/rails/pull/57783) and [#58786](https://github.com/rails/rails/pull/58786). Directory indexing [#58532](https://github.com/rails/rails/pull/58532) is closed/unmerged; do not revive it. Final-template caching requires live resolver invalidation, details, paths and locals. Main also already memoizes `Template#short_identifier`. | Drop solved/closed designs; no new cache or root snapshot. |
| Notification template-root prefix | Main's [#58476](https://github.com/rails/rails/pull/58476) / [85127cd9](https://github.com/rails/rails/commit/85127cd9cee) already moves the interpolated prefix out of every event: the railtie assigns `StructuredEventSubscriber.rails_root` once, and `Utils#from_rails_root` reads that live accessor for every fresh result. | Drop; this census pool is also already solved on main. |
| Empty / silenced Notifications | [#59095](https://github.com/rails/rails/pull/59095) removes the rejected-subscriber array **inside `groups_for`**. `build_handle` still maps its empty result to a fresh Array on every direct instrumentation cycle. Test the live groups first, then map only nonempty groups. `Notifications.instrument`'s existing `listening?` shortcut is unchanged. | **Implement residual `build_handle` allocation**, not event elision or a duplicate `groups_for` patch. |
| Callback chains / flattened filters | Terminator thunk elimination is already [#59094](https://github.com/rails/rails/pull/59094). No saving resolved for the separately measured flattened filter stage. Folding conditions/chains would need a mutation invariant. | Drop solved work and unpriced flattening. |
| AttributeSet reads and key unions | Active [#58002](https://github.com/rails/rails/pull/58002) covers key materialization; [#59141](https://github.com/rails/rails/pull/59141) changes attribute storage/readers. Reader inlining [#59157](https://github.com/rails/rails/pull/59157) is closed/unmerged. Preserve casts, missing/cached-nil/default/dirty semantics; no direct-ivar shortcut. | Drop overlaps and closed reader proposal. |
| AttributeSet builder | [f126797d](https://github.com/rails/rails/commit/f126797d45) already retains the per-model builder. | Drop; already fixed (see historical row above). |
| SafeBuffer / OutputBuffer | General safety-flag reduction is already [#55352](https://github.com/rails/rails/pull/55352); collection buffer reuse above covers one concrete output pool. Active [#46893](https://github.com/rails/rails/pull/46893) covers arity and [#57762](https://github.com/rails/rails/pull/57762) mutation tests. No further exact candidate established without bypassing escape/capture/streaming hooks. | Defer; never substitute plain String appends based on boot facts. |
| CurrentAttributes default tuples | `resolve_defaults` still uses `each_with_object` with a destructured pair. Iterate `defaults.each` into a fresh local Hash instead, retaining live `!= NOT_SET`, `Proc#call` / value `dup`, order and reset callbacks. No matching optimization found. Active [#57821](https://github.com/rails/rails/pull/57821) touches the same method but proposes different nil-key semantics; this patch keeps nil keys. | **Implement tuple-allocation removal**, with no default/result memo. |
| Static miss / scalar `to_param` / Journey / URL options / scalar association keys | All census category-c commits are ancestors of inspected main: [bac124be](https://github.com/rails/rails/commit/bac124beceb2d899340647718f1eef68a9c9cbec), [ef95eda7](https://github.com/rails/rails/commit/ef95eda7b74a7888432ea36bff7e0bf9a7fa8d4e), [a3319707](https://github.com/rails/rails/commit/a331970705be25cc338854490fbd05144c810555), [938d6069](https://github.com/rails/rails/commit/938d6069a8c1ad03fe7baa6d86572b8e2e3852a5), [042e0851](https://github.com/rails/rails/commit/042e0851acbb17b375f23af58214139fdef637d8), [fafab17b](https://github.com/rails/rails/commit/fafab17bfc40812a794c2492845deb519ab1f387). | Drop; already upstream. |
| FrozenRecord scalar-ID shortcut | No `find_by` PR found in Shopify/frozen_record. The measured specimen bypasses Scope construction/matching and is certified for one unscoped scalar shape, not arbitrary scopes/indexes/comparison/reload behavior. | Defer; no unconditional public implementation established here. |
| StoreModel scalar-read forwarding | [store_model#229](https://github.com/DmitryTsepelev/store_model/pull/229) already skips parent assignment for scalar values. The remaining census Array is the wrapper's rest-argument forwarding, not Rails' generated reader. Bypassing that wrapper would skip overrides and non-scalar parent tracking. | Drop solved scalar check; defer a separately verified forwarding change. |
| Importmap preload iteration | Active [#334](https://github.com/rails/importmap-rails/pull/334), [#333](https://github.com/rails/importmap-rails/pull/333), [#279](https://github.com/rails/importmap-rails/pull/279) affect reachability, hints and map selection; [#329](https://github.com/rails/importmap-rails/pull/329) cache work is closed/unmerged. A literal compiled loop cannot assume unchanged resolver/nonce/URL/tag/safe-join behavior. | Defer; no static map/URL/body memo. |
| Net::HTTP setters / header capitalization | Live setter discovery must see added methods and current TLS/proxy options; no cached setter inventory. [ruby/net-http#140](https://github.com/ruby/net-http/pull/140) already changes header validation; [#146](https://github.com/ruby/net-http/pull/146) proposes case preservation. Direct capitalization still needs exact encoding/case and subclass behavior. | Defer; no unconditional replacement established, not a Rails defect. |
| Literal inflections / scalar DOM IDs / fixed-query shapes / PostgreSQL OID tuples / CanCan wrappers | Rules, `to_key`/`to_param`, schema, connection/type registry, query handlers and authorization remain mutable. Existing Lowrail specimens require certified call sites; no general rewrite follows from the allocation counts. Attribute/association/route overlaps are covered above. | Refuse the boot-plan versions; broader upstream algorithms need a separate investigation. |
| Inertia props/config/metadata/path scaffolding, Campfire, rails_vite | Explicitly out of scope; the historical records above are not new publication authorization. | Not changed or contacted. |

Only two candidates are implemented: the small allocation changes do not
replace any public Rails helper or callback body. Normal VM dispatch still
selects subclass/prepend/redefined framework methods. The framework's own
iteration implementation changes; no guarantee about private instruction
sequences or the exact internal Enumerable call trace is claimed.

### Prepared branches and measured results

The existing public `thomasklemm/rails` fork was verified as a fork of
`rails/rails` and reused; its main branch was not changed. Each fix has one
independent commit, authored and committed by Thomas Klemm
`<github@tklemm.eu>`. Later message-only replacements and upstream merges
are recorded in the delivery section below:

- [CurrentAttributes defaults](https://github.com/thomasklemm/rails/tree/thomasklemm/current-attributes-default-iteration)
  — [PR description draft](upstream/current-attributes-pr.md),
  [standalone benchmark](../bench/upstream/current_attributes.rb).
- [Empty notification handles](https://github.com/thomasklemm/rails/tree/thomasklemm/notifications-empty-handle)
  — [PR description draft](upstream/notifications-pr.md),
  [standalone benchmark](../bench/upstream/notifications.rb).

Both branches were rebased before publication onto refreshed canonical main
[`0f19d01ab9`](https://github.com/rails/rails/commit/0f19d01ab94a6a7d8d5021585aaa9a3a9a39e3f5).
That upstream integration changes only Active Record's private-default-scope
detection and its tests; the measured Active Support sources, Gemfile/lock,
test tools and Action View sources are identical to the measurement base.
No published history was rewritten. No pull request, issue, comment, review,
workflow rerun, release or deployment was created.

Ruby 4.0.7 x86_64 Linux, benchmark-ips 2.15.1, stock Rails without Lowrail.
Each scenario has one before and one after process per mode, 1 s warmup /
3 s measurement; allocation counts cover 20,000 warmed operations with GC
enabled. All six scenarios for each fix, both modes, including noisy and
within-error cases, are in the drafts. Their embedded scripts were checked
against the executed files. The first timing pass overlapped the end of a
dependency install; the complete eight-process measurement was replaced by
one serial pass with no concurrent installs or tests. No selected-case rerun
or application/request speed claim follows from these micros.

| Real operation | Objects before → after (both modes) | Interpreter i/s before → after | YJIT i/s before → after |
|---|---:|---:|---:|
| CurrentAttributes reset, ten mixed entries | 17 → 6 | 206,013 → 268,852 (1.31×) | 244,775 → 308,213 (1.26×) |
| Notification handle/start/finish, no subscribers | 2 → 0 | 2.711M → 4.301M (1.59×) | 4.373M → 10.742M (2.46×) |
| Notification handle/start/finish, one silenced subscriber | 2 → 0 | 1.802M → 2.407M (1.34×) | 3.149M → 5.584M (1.77×) |

Active timed / monotonic / Event-object notification subscribers retain
7 / 5 / 6 objects per cycle. All active-only and mixed timing differences
fall within benchmark-ips's reported error in both modes, including the
lower Event-object interpreter point estimate. CurrentAttributes avoids one
object for empty defaults and four objects for each three-entry scenario;
all six reset timing comparisons improve in this microbenchmark.

### Correctness and component verification

Each independent branch passes the complete Active Support suite:
**6,827 tests / 26,697 assertions, zero failures/errors, 60 conditional skips**.
No new tests were kept for these implementation-only refactors; existing
tests are unchanged. Additional untimed controls pass on clean and changed
sources for live default replacement, nil/false/unset keys, fresh mutable
values, mid-iteration changes by a default Proc, callback order, replaced
Procs, prepend overrides, and String/SafeBuffer bytes, encoding, HTML safety
and non-aliasing. Notification controls exercise empty → regexp subscribe →
unsilence → silence → unsubscribe, payload mutation, a handle held across
unsubscribe, and a Fanout subclass overriding `groups_for`.

The final combined tree on the refreshed main also passes Active Support
with the same counts, and all three Action View groups: **2,901 / 6,865**,
**249 / 338**, **173 / 334**, with zero failures/errors/skips.
Active Record's complete SQLite suite passes **10,131 / 36,120**, zero
failures/errors, **52 conditional skips**.
RuboCop reports **2 files inspected, no offenses detected** for the changed
framework files.

Use the Rails checkout's Gemfile/lock, Ruby 4.0.7 and
`BUNDLE_ONLY=default:test:rubocop:cable:db PARALLEL_WORKERS=1 SEED=41231`.
From each component directory run `bundle exec rake test` for Active Support
and Action View, and `bundle exec rake test:sqlite3` for Active Record.
Validation used local Redis and Memcached, SQLite CLI and the adapter gems.
Only the SQLite Active Record adapter suite is claimed, not the
PostgreSQL/MySQL/Ractor adapter matrices or hosted CI.

Retained diagnostics: the first AS bundle omitted Redis's `cable` group and
failed to load the deprecated Redis store; enabling that existing group fixed
setup. The first AR run had one missing-`pg` error and four missing-SQLite-CLI
errors; these are prerequisites, not assertions or optimization regressions.
The root Rakefile also requires the excluded documentation gem `sdoc`, so the
documented component-local tasks were used instead. Two AS backtrace-cleaner
assertions fail with parallel workers on **both untouched main and the changed
tree**, because framework worker frames remain in the cleaned backtrace.
The focused file passes 32 / 45 serially, and the full serial suites retain
every test. No assertion, skip policy, filter or framework source was changed
to obtain a passing run.

## Retroactive review gate and upstream delivery (2026-10-21)

Every future proposed PR gets its own Thermos correctness/security and
maintainability reviews, an independent oracle review of intent, semantics,
benchmark methodology and claims, and the project's contributing/style/commit
checks **before** it is sent to the coordinator to open. Confirmed findings
are fixed or explicitly explained. At most two of our PRs may be open in any
one repository. Only the coordinator opens PRs; review findings do not grant
permission to push to an open PR or publish comments.

### Delivered Rails fixes

| PR | Exact reviewed code / message-only replacement | Gate and delivery |
|---|---|---|
| [#59235 — notification handles](https://github.com/rails/rails/pull/59235) | Reviewed [161b372](https://github.com/thomasklemm/rails/commit/161b37229dc53460283ba56ac2db3634012ead91) against canonical main [0f19d01](https://github.com/rails/rails/commit/0f19d01ab94a6a7d8d5021585aaa9a3a9a39e3f5). Replacement [2cb58de](https://github.com/thomasklemm/rails/commit/2cb58de16d78d0eea6f2689ef7b1dc54d5341903) has the identical parent and tree. | Thermos: no supported-contract correctness/security or maintainability blocker. Oracle: no production-code blocker. **Merged by amatsuda at 12:33:51Z**, [206f2c9](https://github.com/rails/rails/commit/206f2c927a91226563af383df871aad745a36eb1), with parents [6c4743b](https://github.com/rails/rails/commit/6c4743b) and the original reviewed head. |
| [#59236 — CurrentAttributes defaults](https://github.com/rails/rails/pull/59236) | Reviewed [62a35b5](https://github.com/thomasklemm/rails/commit/62a35b53bb2c04353b89cc57383abf9e88b6e521) against the same main. Replacement [2de8815](https://github.com/thomasklemm/rails/commit/2de881564ae5f095579ffce20af30b1aed9f5293) has the identical parent and tree. | Thermos: no supported-contract correctness/security or maintainability blocker. Oracle: no production-code blocker. **Merged at 12:46:29Z**, [596da00](https://github.com/rails/rails/commit/596da00373ca9606a4d7741289203fe62d6ce12b), using the clean replacement head. |

The owner authorized exact-lease message-only pushes, which completed before
the subsequent withdrawal. No production-code review fix was included.
Both commits have Thomas Klemm `<github@tklemm.eu>` as author and committer,
with no attribution/tool trailers in their stored messages. GitHub's fork
refs and commit API confirm both replacements. `gh pr view --json
headRefOid,commits` confirms the replacement on #59236. #59235 had **already
merged** before its fork-branch update, so its PR metadata correctly retains
the original head; no attempt was made to change the merged PR or upstream
history. No comment, reopen, merge, or CI rerun was performed by this work.

Current canonical main at the final check was
[07dccb8](https://github.com/rails/rails/commit/07dccb80b11968ad58e0e16e17155179fb40e97e).
The two changed framework files match the accepted implementations. GitHub
reports successful checks/statuses for #59236's exact replacement head;
that rollup is not a claim that every database/toolchain matrix was run here.
Automatic follow-up subscriptions could not be installed because the
integration lacks access to `rails/rails`; read-only GitHub CLI inspection
was used instead. No ongoing automated monitoring is claimed.

### Findings, dispositions and evidence limits

- **Notification semantics:** `groups_for` is still invoked once per handle;
  silence checks and subscription-cache invalidation remain live. Group
  hashes are frozen cache results or call-local copies, so ordinary
  subscribe/unsubscribe does not mutate a returned grouping between its
  emptiness check and mapping. In-flight handles retain the same listeners
  and payload references. The correctness reviewer reproduced payload
  mutation, grouped exception isolation, `finish_with_values`, interleaved
  subscribe/unsubscribe, silence transitions, a subclass calling `super`,
  nested instrumentation and a bounded concurrency smoke test against both
  bodies. This is not a proof of every possible thread interleaving.
- **CurrentAttributes semantics:** the filter and live value operations are
  unchanged. The correctness reviewer reproduced all six allocation counts,
  nil/false/unset membership, mutable and SafeBuffer copies, callable and
  `dup` exceptions, callbacks, subclasses/prepend, existing-key mutation,
  in-iteration insertion errors and replacement of the defaults Hash.
  Ordinary Hash iteration order and mutation behavior remain unchanged.
  A default Proc replacing `defaults` affects the next reset, not the Hash
  already being traversed. Existing shared nested values/Proc results do not
  acquire new thread-safety or deep-copy guarantees.
- **Internal-override boundary, not a confirmed supported API regression:**
  a custom `groups_for` returning an Enumerator or lying about `empty?`
  can differ; its documented internal result is a Hash. A defaults object
  overriding `each_with_object`, making `each` private or branching on block
  arity can differ; framework-generated defaults are ordinary Hashes. These
  artificial iterator contracts are not preserved by the refactors. No
  first-party consumer requires them. Neither review recommended adding
  speculative compatibility branches or changing the accepted code.
- **Benchmark comparison dispute resolved:** two reviewers initially
  inferred that a single report label prevents cross-process comparison.
  This is incorrect for benchmark-ips **2.15.1**: `save!` with the same fresh
  prefix loads the saved earlier result before the later job runs. The
  executed logs contain both labels in their Comparison sections, and both
  oracle reviews independently checked the upstream implementation. There
  is no benchmark-script fix for that allegation.
- **Timing caveat:** benchmark-ips's default ± values are within-run standard
  deviations, not confidence intervals for treatment effects. Overlapping
  ranges do not prove equivalence or absence of regression. These short
  single-process-pair timings are illustrative helper measurements, not
  stable speedup guarantees, request measurements or JIT-flat certificates.
  SQL is a caller, but Active Record's RuntimeRegistry normally installs an
  active SQL subscriber; no claim that ordinary SQL hits the empty case.
- **Text clarification, not a code fix:** the notification draft now says
  the existing grouping caches/invalidation are unchanged, rather than
  suggesting subscriptions are uncached. Both local drafts explicitly label
  timings exploratory. These are local document changes only; published PR
  descriptions were not edited or commented on.
- **Conventions:** CONTRIBUTING and the guide's benchmark, style, changelog
  and commit sections were checked. RuboCop found no offenses in either
  changed source. One focused commit per fix and benchmark/motivation in
  the body match the project. Subjects exceeding the guide's *ideal* 50
  characters, and a few long body lines, are advisory style nits; neighboring
  commits also exceed that preference. No cosmetic rewrite is warranted.
  No new feature/behavior/changelog or permanent allocation assertion was
  added. Branch-specific AS and combined AS/AV/AR suite results above remain
  distinct; static review is not a new independent run of those suites.

Future commits use `/usr/bin/git -c core.hooksPath=/dev/null` with explicit
Thomas author/committer identity; inspect the real stored message and both
identities before publication. The orb's Git wrapper can append a trailer
even with hooks disabled. No already-published Lowrail history was rewritten.

## Falsy memo and additional gem follow-ups (2026-10-21)

| Candidate | Current upstream evidence | Gate / disposition |
|---|---|---|
| `query_constraints_list ||= nil` on models such as Bucket/Bubble | Main's `Persistence#query_constraints_list` uses the live explicit definition or `schema_context.query_constraints_list`. [#58767](https://github.com/rails/rails/pull/58767), merged as [3f51c57](https://github.com/rails/rails/commit/3f51c579b73a4be2f5e3e6eb4a20f353b26de0bd), moved derivation into `SchemaContext#load_schema!`, storing nil as well as Arrays. `primary_key=` and `query_constraints` invalidate loaded schema contexts. | **Already fixed upstream; no duplicate PR.** A nil memo backport without the invalidation path is not established as equivalent. |
| `SolidCache::Entry.connection_class ||= false` | Solid Cache main [da70ef4](https://github.com/rails/solid_cache/commit/da70ef4f8f9c5ad6490b3994cd4d67dcf5e3659a) does not define this getter in Entry or Record. It inherits `ActiveRecord::Core.connection_class`, whose false-write remains on Rails main. Searches of open/closed Rails and Solid Cache PRs found no matching fix. | This is a **Rails**, not Solid Cache, candidate. Do not open a Solid Cache duplicate. |
| Read-only flag, `@connection_class || false` | One-line local experiment based on canonical [206f2c9](https://github.com/rails/rails/commit/206f2c927a91226563af383df871aad745a36eb1). All sequential returned values, live setter changes and ordinary subclass/predicate dispatch agree, but absence/nil state and frozen-class errors differ. | **Fails the strict unconditional gate and performance admission; not published, no PR-ready draft.** Thermos maintainability passes; Thermos correctness does not recommend submission because of the interpreter regression. Oracle rejects the strict equivalence claim. |
| StoreModel `_read_attribute(*)` forwarding, revisited | Current master [c868dc0](https://github.com/DmitryTsepelev/store_model/commit/c868dc0f3edc15ff20d8b5305280742452cdc2b3) still uses the rest wrapper plus replaceable `tap`/parent assignment. [#229](https://github.com/DmitryTsepelev/store_model/pull/229) is merged. Replacing `*` with `...` changes keyword forwarding to a keyword-aware overridden super method; removing `tap` bypasses a returned value's override. | **No unconditional replacement established.** Concrete Ruby controls distinguish both proposed shortcuts; no StoreModel change or PR. |

### Reproduction and rejected flag measurements

[Minimal reproduction](../bench/upstream/falsy_memos.rb), Ruby 4.0.7:

```sh
ruby bench/upstream/falsy_memos.rb /path/to/rails-before
ruby bench/upstream/falsy_memos.rb /path/to/rails-experiment
```

On the real AR subclass, the old getter defines an absent ivar and changes
an explicit nil to false; the experiment does neither. Freezing the class
object with the built-in `Object#freeze` after setting false makes the old
getter raise `FrozenError`, but the experiment returns false. The oracle
also identified a changed non-main-Ractor write error; that additional
Ractor case was not executed here. These differences might be desirable
upstream design changes, but cannot be sold here as unconditional semantics
preservation. A `defined?` memo returning an explicit nil would additionally
change the boolean getter result; it is not an equivalent drop-in solution.

The same reproduction records the keyword/replaceable-`tap` counterexamples
for the StoreModel proposals. This establishes why those shortcuts were
refused, not a support/benchmark claim about a modified StoreModel release.

[Standalone flag benchmark](../bench/upstream/connection_class.rb): stock
Rails, benchmark-ips 2.15.1, Ruby 4.0.7, 2 s warmup / 5 s timing, 100,000
warmed GC-enabled operations for allocations. One serial idle pair per mode;
no repeated-until-green selection. The measurements used base
[0f19d01](https://github.com/rails/rails/commit/0f19d01ab94a6a7d8d5021585aaa9a3a9a39e3f5)
and that checkout with the one-line edit. The exact same `core.rb` base blob
is present in the later reviewed canonical base; the intervening five-file
upstream update is not represented as a fresh benchmark run.

| Operation | Objects/op, before → after | Interpreter i/s, before → after | YJIT i/s, before → after |
|---|---:|---:|---:|
| Explicit false flag | ~0 → ~0 | 13.860M ±1.2% → 15.674M ±1.9% | 24.657M ±4.7% → 30.093M ±1.0% |
| True flag control | 0 → 0 | 16.801M ±0.2% → 16.458M ±4.4% | 29.691M ±5.7% → 29.928M ±2.3% |
| Ancestor connection-class lookup | 0 → 0 | **1.963M ±0.2% → 1.765M ±2.3%** | 11.240M ±7.9% → 14.618M ±3.2% |
| Live true/false setter + predicate cycle | 0 → 0 | 5.540M ±2.0% → 6.042M ±0.5% | 13.457M ±0.9% → 14.666M ±0.6% |

The false-flag counter has one measurement-floor object per 100,000 calls
on both arms (0.00001/op), not an allocation saving. The actual ancestor
path is **about 10% slower in the interpreter**; direct-read gains do not
override that result. The intermediate class has an unset flag: the old
warmup materializes false while the experiment leaves it undefined. This is
a concrete hypothesis for the difference, not a demonstrated cause. No
further timing was selected to make it disappear, because the strict
semantic gate already fails. No application/request gain is claimed.

The reviewed local experiment is one clean commit on `206f2c9`, with Thomas
as author/committer and no tool/co-author trailer. The complete AR SQLite
suite ran on that head: **10,131 tests / 36,090 assertions, zero
failures/errors, 52 conditional skips**. RuboCop: **one file, no offenses**.
This is not the earlier 36,120-assertion combined-tree run, a hosted-CI claim,
or evidence against the reproduced semantic differences. No new fork branch
was pushed and no draft was offered as having passed the gate.
