# Exception-aware observed returns on five Rails apps

2026-10-22. Advisory types/MCP only, continuing
[types-contracts](types-contracts.md) from main
[`6436f9c`](https://github.com/thomasklemm/lowrail/commit/6436f9c6d7354dbe654b63458f151e67d16209fd).
No lowering/runtime specialization, app patches, upstream activity or speed
claim. Lobsters is not rerun in this bet and remains unchanged/external-only.

**1,864 previously unknown return slots can be published as observed**, in
addition to the unchanged 843 observed arguments. These are sampled classes,
not static contracts or proofs. All nine previously diagnosed exception-unwind
flags disappear. Four compatible CASA relation/subtype flags are individually
classified and withheld; the published derivatives have **zero unexplained
conflicts**. No compatibility rule or static fact is weakened.

## Fixed-denominator ledger

Order: **proven / static / observed / unknown**. The same five frozen facts
contain **21,063 effective return/parameter slots**; inherited copies count as
effective receiver slots, not independent bodies. Ivars and runtime methods
outside this universe are excluded. The no-observation baselines byte-match
the prior contracts baselines. This table compares fresh argument-only samples
with those same samples plus accepted returns, not a new static-inference gain.

| App | Arguments only | Arguments + returns | Unknown returns before | Returns recovered | Tainted nil events omitted |
|---|---|---|---:|---:|---:|
| Blog | 2/99/0/195 | **2/99/7/188** | 98 | 7 | 0 |
| Fizzy | 14/953/86/1,574 | **14/953/314/1,346** | 713 | 228 | 3 |
| Campfire | 30/1,181/144/5,368 | **30/1,181/495/5,017** | 1,721 | 351 | 27 |
| CASA | 40/2,561/517/6,756 | **40/2,561/1,611/5,662** | 4,050 | 1,094 | 183 |
| Writebook | 19/499/96/929 | **19/499/280/745** | 496 | 184 | 11 |
| **Total** | **105/5,293/843/14,822** | **105/5,293/2,707/12,958** | **7,078** | **1,864** | **224** |

This recovers 26.34% of unknown returns, not 26.34% of all unknown slots.
**231 recovered returns still contain unknown generic members**, e.g.
`Array[untyped]`; the recorder never inspects collection contents. The historical
blog 2/99/7/188 already included these seven returns. The fix makes fresh
return publication defensible; it did not discover seven new blog slots.

[Machine ledger](types-returns-coverage.json) retains every recovered return's
type, evidence, histogram and provenance; raw/facts/argument/final hashes,
sample caps, omissions, commands, suite status and all withheld classifications.
Arguments retain their exact fact objects. Known proven/static names and
evidence are preserved; observed evidence is never upgraded.

## What the recorder can honestly distinguish

Ruby can emit nil `:return` events when unwinding an exception, after `$!` has
already been cleared. A method-targeted TracePoint does not see raises in
untraced callees. On the executed Ruby 4.0.7, targeting `:raise` itself also
does not provide the needed notifications.

One global `:raise` hook marks the active sampled activations in that fiber.
A tainted nil exit records **neither a return nor receiver ivars**. Non-nil
events remain usable: otherwise internally rescued framework calls would
erase genuine model/relation returns. Entry arguments remain useful, even
on a raised exit. Entries, including all-raising calls, exhaust the cap; hooks
retire only after their in-flight calls drain. Fiber-local activation stacks
separate recursion, threads and suspended fibers. Returned objects' own
reflection/predicate methods are never called by this decision.

This is deliberately conservative: a rescued exception followed by a genuine
normal nil can be omitted too. The 224 counter is **omissions, not 224 proven
unwinds**. A normal nil in an activation entered after an ambient rescue is
retained. Non-exception `throw` and other non-local exits remain an explicit
sampling limitation; this does not promise complete normal-exit certification.

New files attest `return_sampling: exception_tainted_nil_omitted_v1`. Merging
processes preserves that attestation only when every process supplied the same
policy. Legacy/mixed files remain readable but must be regenerated; old nils
cannot be retrospectively cleaned. No old observation is silently relabeled.

### Conflicts: retained and classified, not suppressed

The nine old nil flags were Campfire `Opengraph::Fetch#resolve_redirect` and
CASA `ContactTypeGroupsController#new`, `ContactTypesController#new`,
`CustomOrgLinksController#new`, `HearingTypesController#new`,
`JudgesController#new`, `OtherDutiesController#new`, `NotesController#edit`,
`VolunteersController#send_sms_to`. Fresh samples have no NilClass for those
methods. The last has no accepted return sample; its static String is not
replaced with a guessed nullable return. The other exercised normal-return
classes agree with their static facts.

The remaining four raw flags are the already source/runtime-verified
compatible subtypes in [the prior evidence](types-contracts-conflicts.json):
`CasaOrg#casa_admins`, `#supervisors`, `#volunteers`, and
`Volunteer#case_assignments_with_cases`. The reducer requires an exact
app/method/slot/static-name/observed-class classification with evidence. Their
return samples stay in the ledger but are withheld from the published alias;
their existing static types are neither replaced nor widened. An unexplained
flag aborts new publication. This is not a generic subtype-checker fix.

## Unchanged own-suite runs

Ruby **4.0.7**, seed **1379**, cap **16** per method/process, existing
`lowrail observe` with `LOWRAIL_OBSERVE_TYPES_ONLY=1`. Default Rails test scope
or CASA's default RSpec scope; no separately invoked system tests or app edits.

| App | Fresh own-suite result |
|---|---|
| Blog | 21 tests / 54 assertions, zero failures/errors/skips |
| Fizzy | 124 / 458, zero failures, **7 errors**, zero skips |
| Campfire | 234 / 671, zero failures/errors/skips |
| CASA | 3,761 examples, zero failures, **21 pending** |
| Writebook | 119 / 381, zero failures/errors/skips |

Fizzy is **partial**, not support proof. A fresh recorder-off control has the
same seven full test/error/source identities (`Current#reset_all` in
`test/test_helpers/session_test_helper.rb:22`), counts and outcome. CASA's
initial PostgreSQL preparation failed with the wrong local role; that failed
attempt and its raw observations remain retained separately. The corrected
run uses its existing disposable database and Node 24 assets. No retries to
hide a test failure. All Lowrail outputs and derived signatures are external
to the unchanged workload trees.

## Reproduction

Use the pinned facts/absolute source roots from the contracts experiment.
`ROOT/APP/static.json` and `contracts-static.json` are the same contracts
baseline, without observations. For each of the five apps:

```sh
LOWRAIL_OBSERVE_TYPES_ONLY=1 lowrail observe ROOT/APP --samples 16 -- \
  bash -c 'cd /absolute/app && export LOWRAIL_OBSERVE_ROOT="$PWD" && exec bundle exec bin/rails test --seed 1379'
# CASA uses bundle exec rspec --seed 1379 with its existing database/assets.
script/types-observed-arguments ROOT blog fizzy campfire casa writebook > arguments-ledger.json
script/types-observed-returns ROOT blog fizzy campfire casa writebook \
  --classifications docs/types-contracts-conflicts.json > returns-ledger.json
lowrail types ROOT/fizzy/returns --rbs EXTERNAL_RBS_DIR
rbs -I EXTERNAL_RBS_DIR validate
```

The return reducer checks fresh policy/root, matching argument observations,
fixed slot universe, unchanged argument facts and known types, and zero
unexplained conflicts. It never boots/patches an app or rewrites the raw file.
`candidate` is diagnostic only; `returns` is the classified publication alias.

## Review and validation

The retained before-fix fixture reproduces a fabricated `NilClass: 4` histogram
for an all-raising method. Focused regressions check untraced C/block raises,
rescue/ensure, recursion/caps, genuine nil, ambient rescue, hostile return
objects, and fiber/thread interleaving. An intermediate overbroad rejection
lost a genuine Widget return and an intermediate fixture assumed all ensure
returns are nil; both failed attempts are retained, not reported green.
Full independent Thermos and exact-head gate results are recorded with the
delivery report after review, not inferred from these focused checks.
