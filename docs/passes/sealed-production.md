# Passive production token and collection units

**Correctness work, not a speed result.** `sealed/token_tag` and
`sealed/collection_render` now have public build/runtime certificates. They
are separate from the rejected [combined pricing specimen](sealed-combined.md).
That specimen stays rejected and is not measured again. No default-tier,
quarantine or guarded-pass behavior changes.

## What is certified

Both units use a first **natural original operation** as their witness. The
observation seams are installed identically in explicit sealed off/on arms;
only an admitted on arm takes the fast path. Admission has one try-lock
attempt, checks actual native holders, stock method/body/visibility and source
fingerprints, and rechecks the seal epoch before publishing. Failure is
terminal with a reason in stats/explain. There is no runtime objspace,
materialization, view construction, template lookup, compilation, schema
probing or on-only prepend. Build-only inventory remains build-only.

- **Token:** retain live protection policy, token generation/masking, name
  conversion and autocomplete policy. Literal tag output requires plain
  String name/value, the exact cached view/tag-builder context and the known
  action/method options. Unknown inputs or epoch changes after generation
  continue at stock `tag` with the already generated/converted values; they
  do not replay generation or conversion. SafeBuffer, Array, Regexp and nil
  values are original tag continuations, not forced into a String shortcut.
- **Collection:** specialize only stock `collection_with_template` with a
  nonnil template and no layout. Keep live collection derivation/loading,
  lookup, iterator/preloading, local-name/cache-key effects, `Template#render`,
  events and rendered-result objects. This removes fewer branches than the
  old pricing adapter: **there is no cached-template lookup shortcut** and
  no transfer of its isolated or request prices.
- **Form composition:** unwrap only the exact source/body-certified symmetric
  token observer when checking the original helper beneath it. Arbitrary
  helper overrides still refuse. Existing form admission is otherwise intact.

The first production domain deliberately inherits the existing narrow
Ruby 4.0.7 / Rails 8.1.4 stock-blog build inventory. This is not a general
token/collection support claim, a lazy-app certificate, or a test-environment
certificate. The known broader all-sealed Template/Preloader ancestry failure
is not repaired or normalized by these units.

## Explicit fixture boundary

[`BlogShowGetOnly`](../../fixtures/corpus/blog_show_get_only.rb) is a separately
named, tracked fixture, **not a hidden BlogProduction variant**. It creates
fresh schemas and inserts three literal articles and three comments, with
comment counts 2/1/0 and a fixed timestamp, without callbacks/jobs. Preparation
refuses existing SQLite storage. Parent-only read-only validation checks all
rows and absence of queued jobs before cold workers start. The fixture digest
is a required pin in the [numeric gate export](sealed-production-results.json).

The old `db/seeds.rb` snapshot is retained as the named failure
**`historical_seed_six_unfinished_turbo_jobs`**. Both entropy companions reject
`rejected_async_completion` in all three restored arms: six ready
`Turbo::Streams::ActionBroadcastJob` jobs, no supervisor, no completed snapshot.
Its cold equality does not waive async completion. Raw capture digests and
the actual refusal records are retained in the export; the dedicated terminal
completion regression continues to exercise pending work and a held Cable
writer. No jobs were deleted from that seed to make it pass.

Any future price uses **only the new fixture** for all candidate/control arms.
It must not be compared with −17.86%, older form prices or any older cohort.

## Executed gates

The public CLI regression builds an isolated artifact containing exactly
form/token/collection, with no delivered files/templates. The reusable
[`sealed_production_check.rb`](../../bench/experiments/sealed_production_check.rb)
then runs restored production workers, not a pricing installer:

1. Raw off/off/on remains `rejected_off_control` for real entropy/clock fields.
   Both declared entropy seeds pass exact off/off/on comparisons of full cold
   ancestry, feature/load order, hooks, ordered SQL, events, response and
   parent-read exit effects, including the async completion boundary. No
   `Templates::CompiledSource` or `PreloadPlans::Hook` occurs in any arm; no
   census field is dropped.
2. **192 ordinary + 192 header-writing render-subscriber pairs** have identical
   status/body/all headers, SQL, events and assigns. Each on arm records
   **form104/token398/collection87** hits and **62 collection fallbacks**.
   The latter remain visible; the nonnil-template/no-layout domain does not
   cover all negative/alternate rendering cases. Off hit counters are zero.
3. After natural admission, **50 native show requests** give
   **form50/token200/collection50**, zero fallbacks/refusals. Epoch deopt gives
   original-path fallback counts **1/4/1**, with no further hits.
4. Public regression additionally compares literal and unsupported live token
   values against the stock continuation, including output class/encoding and
   once-only generation/name conversion. Tampered observer certificates leave
   three successful original requests, zero token/collection hits and explicit
   terminal refusals. No wrong-answer special cases are added.

Reproduce the self-contained build/fixture/gate regression under the repository
Ruby with an available `real-blog-r4` corpus:

```sh
LOWRAIL_TEST_CORPUS_ROOT=/absolute/corpus/root \
  ruby -Igem/test gem/test/form_scaffold_test.rb --name /passive_production/
# For an already prepared, isolated app and the unchanged fixture snapshot:
ruby bench/experiments/sealed_production_check.rb APP SEED_STORAGE NEW_OUTPUT
```

The scheduling/counter prerequisite is separate: the actual Callgrind
`gc_exclusion` regression executes the native counter, rather than only its
stub, outside slots/cohorts. Affinity/CPU/overlap observations remain symmetric
and outside window endpoints; unavailable migration counters remain null.

## One proposed production cohort — awaiting authorization

**Not started; no slots used or reserved.** After publication and the final
published-head gate, propose one finite interpreter cohort of the real
production form/token/collection units on **BlogShowGetOnly**. No pricing
adapter is loaded. The exact artifact, fixture, runtime, harness, app, lock,
native primitive and gate hashes must match the published export before and
after execution; any source change requires fresh correctness gates and
review before counters.

Use the shared `RequestPairs.heap_instructions` worker with three arms
(off-A/off-B/production), six randomized rounds, seed 41231, N=0/50 subtraction,
at most two separately granted slots, actual interpreter, real entropy and
the unchanged five fixed heap floors / 512-MiB-brk tool. Keep total **and**
GC-excluded A/A (including zero in the interval), heap/brk/JIT/idle checks,
untimed independent hit/fallback/refusal counts, and placement envelopes.
Reject and retain the whole cohort on any failed control; no retry, excluded
round, rescore or comparison with old fixtures. This is a new candidate, not
a retry of the rejected specimen and not a request for immediate execution.
