# Bet M: Lobsters cache reconstruction

Branch-only experiment, Ruby 4.0.7 / Rails 8.1.4, ruby-bench
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716).
Shipped SQLite SHA256 `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`,
restored into `:memory:` exactly as upstream. No app source/config changes.
**Parked on `thomasklemm/lobsters-cache`: allocation saving resolved, wall
unresolved, the one interpreter cohort rejected A/A. All raw Ir effects are
diagnostics only. No retry, replacement cohort, RPS or production promotion.**

## Discovery before implementation

It is **FileStore**, explicitly configured at `config/application.rb:48`,
not MemoryStore's duplication coder. Cache and AR marshalling formats are 7.1.
One Marshal load per warmed request:

| Route | Key | App caller | Value |
|---|---|---|---|
| `/` | `stories hottest=true page=1` | `HomeController#index:38 → get_from_cache:345` | `[25 stories, true]`; 121 records including cached association/inverse targets: Story26/User25/Domain24/Tagging26/Tag20 |
| `/s/enr7ye` | `story enr7ye` | `StoriesController#show:150 → get_arranged_comments_from_cache:391` | one-comment Array; Comment1/Story1/User2/Vote1 |

The live path is `FileStore#read_entry → Coder#load → LazyEntry#mismatched?`
(`coder.rb:115`) `→ LazyEntry#value:108 → Marshal71WithFallback#_load:110`
`→ SerializerWithFallback#marshal_load:40 → Marshal.load`.
The file is read for every fetch; expired/mismatched entries remain Rails' job.
Values are not cached query rows alone: AR `marshal_load:43` builds fresh
LazyAttributeSets, runs initialization, and restores associations.

The off-only census reproduces bet L's **1,517 / 143** objects at
`<internal:marshal>:34`. It traces only each load, disables GC during the
untimed census, and follows references from the returned root through newly
allocated objects (not through classes/global framework graphs).

| Marshal-site class / role | `/` | `/s/enr7ye` |
|---|---:|---:|
| Result Strings | 397 | 24 |
| Result Hashes (raw attribute dictionaries) | 121 | 5 |
| Result Arrays | 74 | 3 |
| Result Time / BigDecimal | 104 / 26 | 6 / 2 |
| Result AR objects | 121 | 5 |
| **Result graph subtotal** | **843** | **45** |
| Intermediate AR payload/association Arrays | 369 | 15 |
| Intermediate Strings | 201 | 77 |
| Intermediate Time::tm | 104 | 6 |
| **Intermediate subtotal** | **674** | **98** |

369 = 121 model state Arrays + 72 association-list Arrays + 176 association
pair Arrays; story 15 = 5 + 3 + 7. A second, explicitly instrumented native
argument census splits Strings into Time `_load` payloads **104/6**,
BigDecimal `_load` payloads **26/2**, and metadata/key/symbol-name Strings
**71/69**. That observer relocates native Time/Time::tm/BigDecimal source
attribution to its wrapper; its rows must not be mistaken for a reduction.
CRuby's `time.c:2434` allocates a Time::tm before asking the String timezone
for `utc_to_local`; it is not retained by the final Time.

These result objects count even if the HTML template never reads every field:
the caller receives the graph and can traverse/mutate its associations. A
shallow Array copy or reuse of AR records is not exact. Returning a whole
response does not mean the deserialized objects stay live after that request.
Outside the Marshal site, load-time Ruby allocations are **951/36**, of which
**879/34** are also in the result graph and **72/2** are temporary association
reset Arrays. Enumerable totals are **2,468/179**, not StackProf's different
inclusive 2,599/request attribution and not the complete GC counter budget.

## Two different ceilings

**Exact, independent mutable results:** at most the **674/98** Marshal-site
intermediates, **4.7505%/2.7613%** of L's 14,188/3,549 objects/request, before
any replacement/guard costs. Including the separately identified reset Arrays
gives an optimistic all-enumerable intermediate pool **746/100**
(5.2580%/2.8177%). These are bounds on observed avoidable scaffolding, not
achieved savings or a claim that every hook argument can disappear for free.
Fusing AR's actual stock reconstruction would be necessary to remove its
state Arrays; they cannot be removed while simply invoking stock marshal_load.

**Later opt-in deviation, NOT exact:** sharing a predecoded immutable result
could theoretically remove all **1,517/143** Marshal-site objects
(10.6921%/4.0293%), or **2,468/179** enumerable load objects
(17.3950%/5.0437%) if AR reconstruction effects are also abandoned. The extra
**843/45** result objects are not exact savings. Plain deep-freezing does not
make this app work: AR reads populate lazy attributes/associations, and mutable
strings/records and callbacks remain observable. No frozen-value opt-in was
implemented, verified or priced. These ceilings are not additive with exact
savings or GC CPU, and do not predict wall time.

## One exact-copy prototype; prospective screen

The chosen narrower change leaves the AR state Arrays, fresh raw dictionaries,
mutable strings/models/times, association alias/cycle graph, and actual Rails
`marshal_load` calls intact. It compiles a constructor/copy plan from the first
original decode, restricted to plain containers, scalars, UTC Time and stock
AR records with empty find/initialize callbacks. It avoids repeated symbol/key
decoding and copies the native UTC Time state without transient Time::tm/data
strings. BigDecimal still uses its real `_load` with a fresh payload String.
The candidate's source-enumerated pre-cost intermediate pool is **279/81**
objects (71+104+104 / 69+6+6), not all 674/98. This is not a complete
`GC.stat` prediction: internal, non-enumerable objects and replacement/guard
allocations are outside that subtotal. Do not infer an unexplained residual's
class or lifetime from the difference alone.

Reuse is keyed by **full String byte equality**, never key name, mtime or file
size. The seam is below FileStore/Coder/Entry: file reads, decompression,
expiry/version checks and notifications remain stock on every request.
Different bytes execute stock Marshal.load. There are at most two plans.
Live callback/allocator/marshal-load shape and timezone-hook checks refuse
changed supported shapes. No global Marshal replacement or app cache-policy
change. Off arms load the same observation seams and optional dependencies.

This is an **explicit sealed bench prototype**, not production admission:
it relies on the sealed no-code-mutation contract and the source-pinned fixture,
uses ObjSpace and runtime compilation for first-payload discovery, and is not
registered as a build/runtime pass. No general guardless-cache or all-app
exactness claim. A production version would need passive admission/source
certification and a retained-memory/cold-cost assessment; none is waived.

Before timing, contract controls require two real plan hits when checking
copies, exact re-marshaled graphs, and independent nested String mutations.
A forked **external writer** changes each entry, preserving its old mtime.
Both seeds' responses must change and match stock status/body/all headers,
with zero plan hits for changed bytes. Expired, version-mismatched,
version-matched and deleted-entry public reads must match stock separately.

Run **one** three-round off-A/on/off-B screen: 500 warmups, 600 samples per
route per worker; separate 10-request coverage workers. Both seeds' literal
status/body/all-header checks must pass. Advance only with allocation medians
below both controls in every round and a wall-effect 95% interval wholly below
**−3 × max(A/A CI envelope, largest absolute A/A round spread)**. No retries,
round exclusions or second variant. Otherwise kill; no Ir or RPS launch.
This was the original screen rule. The subsequent coordinator authorization
below changes advancement prospectively; it does not re-score this wall gate.

The dependency overlay, lock, entropy policy, validator, fixture-restoring
setup, `script/native-bench` and `script/screen` are byte-for-byte copies from
bet L's branch. An empty public-compiler YJIT artifact excludes other passes.
This in-process native YJIT screen is direction-finding, not a JIT-flat price,
Puma throughput, whole-app support or production-admission certificate.

## Completed screen: resolved allocation saving, wall unresolved

Measured on unchanged
[`42d3e5a`](https://github.com/thomasklemm/lowrail/commit/42d3e5ade83922afc1ed39c632cc3c8ecee0dcd0).
All three rounds have the same allocation medians:

| Route | Off-A / off-B / on objects per request | Saved | Wall on/off Δ% [95% interval] | Wall A/A 95% interval |
|---|---:|---:|---:|---:|
| `/` | 14,188 / 14,188 / 13,821 | **367 (2.5867%)** | −9.2095 [−14.7546, −4.9024] | [−10.6132, +9.1380] |
| `/s/enr7ye` | 3,549 / 3,549 / 3,475 | **74 (2.0851%)** | −10.2441 [−16.1944, −6.9922] | [−9.1228, +6.7379] |

The original wall gate fails: floors are 10.6132% / 9.1228%, requiring an
upper effect bound below −31.8397% / −27.3684%. This screen cannot resolve
the smaller observed effects. **Wall is unresolved, not evidence of harm or
an accepted latency win.** RSS is higher on: approximately 262,021 / 263,403
KiB versus off-A 238,948 / 240,380 and off-B 239,783 / 241,365 KiB. Retain
that cost; its complete cause is not isolated.

All 36 measured and 12 coverage-companion seeded response records pass literal
status/body/all-header checks. Separate on coverage is 10 hits/10 requests per
route, zero compilation in those windows. External same-mtime rewrites change
both seeded responses exactly as stock, with **zero changed-byte plan hits**.
Expiry, matching/mismatching versions, deletion, re-marshaled alias graphs and
independent nested mutations also pass. No result sharing/frozen-value opt-in.
[Census, controls, every wall sample and source pins](lobsters-cache.json).

## One authorized interpreter price attempt: REJECTED A/A

Before any Callgrind counting, the coordinator explicitly authorized **one**
interpreter cohort because the allocation saving is resolved and the wall gate
is uninformative at this noise level. Both total and no-GC A/A nominal 95%
intervals must lie wholly within **±0.1%**, without zero-containment. This
does not relax the rule after seeing instruction results. No retries,
exclusions, second variant, RPS, or default/admission change.

The unchanged published prototype is priced with six rounds, **18 serial
workers**, seed 41231, N0/N50 for each of the two routes and each of total/no-GC,
warmup50, balanced phase order, and the existing `HeapWindows`/Callgrind seam.
Both routes share each worker boot; their prices and controls remain separate,
not a traffic-weighted whole-app claim. Historical floors are
`[1000000,250000,100000,20000,10000]`, with exact observed endpoint pages
`611/306/246/99/100`. Valgrind 3.19.0 uses the repository's source-pinned
brk512 patch; its rebuilt binary hash is retained, not assumed identical to
another orb's build. Measured statistics are off; guards, byte comparisons,
file reads, live clocks/expiry and original reconstruction remain charged.

**Rejected diagnostics only — no accepted Ir price:**

| Route / metric | Raw on/off Δ% [95% interval] | Off-B/A 95% interval | ±0.1% A/A |
|---|---:|---:|---|
| `/`, total | −5.199775 [−5.320928, −4.980411] | [−0.087059, +0.111227] | FAIL |
| `/`, no-GC | −5.284598 [−5.537796, −5.103409] | [−0.079688, +0.115340] | FAIL |
| `/s/enr7ye`, total | −1.600255 [−1.671044, −0.232293] | [−0.099690, +1.387998] | FAIL |
| `/s/enr7ye`, no-GC | −1.651904 [−2.342056, −1.597837] | [−0.763076, +0.776274] | FAIL |

The combined vector's controls also fail. Do not round the front-page bounds
into the acceptance band, discard story rounds, or attribute an unverified
cause to the A/A variation. No retry or re-score was run. Total and no-GC are
different executions; their difference is not a measured GC saving.

All worker before/after seeded responses are exact across arms; pre/post
interpreter external-writer, expiry/version/deletion and independent-copy
controls pass. Actual interpreter, all five heap-capacity/endpoint-page gates
and brk checks pass. Untimed `tool=none` companions have exactly 50 hits and
zero compilation in each full on-window. Independent reconciliation checks
**144 dump totals and self-cost sums, 72 N0 subtractions, 18 before/after
source certificates, 6,322 file pins**, every median and all 5,000-draw
bootstrap intervals. There is no peer-worker process/window overlap;
migration counts are unavailable. This is not an own-suite, cold-start,
concurrent-capture or production-admission certificate.

Untimed setup refusals are retained separately: first a relative provenance
path before app boot, then a comparator that incorrectly included the audit's
real pre-substitution clock timestamps. HTTP fields were already identical;
the comparator was corrected before counting, retaining all audit data. None
is a counted retry. [Complete rejected price export, worker and driver](lobsters-cache-ir.json).

### Bounded read-only story A/A diagnosis

Only existing dumps and their recorded window counters were inspected; no
workload, Callgrind worker or replacement cohort was run. Round numbers below
are **zero-based**, matching the exported worker/dump names.

| Round | Story off-B/A total Δ% | Story off-B/A no-GC Δ% | Extra regeneration signature |
|---|---:|---:|---|
| 0 | +1.397099 | +0.068874 | `0-off_b`, total (`.callgrind.6`) |
| 1 | −0.136170 | −1.465973 | `1-off_a`, no-GC (`.callgrind.6`) |
| 2 | +1.378897 | +0.027756 | `2-off_b`, total (`.callgrind.6`) |
| 3 | +0.129987 | +1.483673 | `3-off_b`, no-GC (`.callgrind.6`) |
| 4 | −0.063210 | −0.060180 | none |
| 5 | +0.007888 | +0.022343 | none |

The two high off-B total windows drive the **+1.387998%** upper bootstrap
bound. Each has exactly **one `marshal_dump`, one `rb_deflate_s_deflate`, one
`io_binwrite.part.0` and one `rb_file_s_rename`**; all other off-story total
windows have zero calls to these entries. Each also emits two YAML mappings
(44 scalar analyses) and two file unlinks. The no-GC outliers show the same
signature, with the costly window on off-A in round 1 and off-B in round 3.
Every one of the **24 off-story full windows records zero minor/major
collections and zero excluded GC segments**. GC phase therefore does not
explain these story outliers.

For example, round 0's off-B minus off-A contrast is **10,827,147 Ir/window**
(216,542.94/request). Its extra Marshal.dump inclusive arc costs 5,120,302
Ir and deflate entry costs 515,429 Ir; these are supporting call-tree costs,
not an additive attribution of the whole contrast. The same serialization,
compression and atomic-file replacement signatures recur in the other three
spikes. This is **real regeneration work mixed into stock controls**, not
just disk-read waiting, an N0 arithmetic artifact, or a copy-plan code effect:
both off arms have the prototype disabled.

The pinned `StoriesController#get_arranged_comments_from_cache:391` fetches
`story enr7ye` with **`expires_in: 60`**. Original Rails fetch deletes an
expired entry, generates the value and serializes/atomically writes it;
FileStore reads and expiry clocks are live during the instrumented workers,
which run the front-page windows before the story windows. A **live TTL/phase
crossing is the strongly supported explanation for the mismatched warm-hit
mix**. The dumps do not retain Ruby cache-event keys or entry expiry/read
timestamps, so the exact refresh request and expiry comparison are not
proven. The remaining smaller control differences are not fully attributed.
Do not silently promote that inference into a precise expiry trace.

The export retains all six contrasts, native call counts/costs, dump hashes,
GC counters and the read-only parser. No round is excluded, reweighted or
subtracted to manufacture a corrected price. Any separately authorized future
Lobsters price must first certify the per-window hit/regeneration mix and TTL
phase without changing app semantics. **M stays parked; this diagnosis is not
authorization for another run.**

## Reproduction

Prepare the pinned fixture and dependency overlay as above, copying the shipped
`db/production.sqlite3` to `.lowrail/lobsters-cache/seed/primary.sqlite3`.
The census command is:

```sh
LOWRAIL=0 RAILS_ENV=production BUNDLE_GEMFILE="$PWD/fixtures/corpus/lobsters-rps.Gemfile" \
  mise exec ruby@4.0.7 -- ruby --yjit bench/experiments/lobsters_cache_census.rb \
  "$PWD/.corpus/ruby-bench/benchmarks/lobsters" "$PWD/.lowrail/lobsters-cache/seed" NEW_JSON
```

Repeat the untimed census with `CACHE_CENSUS_NATIVE_ARGS=1` only to classify
native payload Strings; do not compare its shifted source rows as a saving.
The export corrects the earlier unwrapped report's overly broad metadata label
to **unclassified (native observer off)**; its counts and raw-input hashes are
preserved. Only the native-argument report supplies the finer String split.

The wall config uses the recorded absolute app/seed/Gemfile paths, an empty
YJIT artifact, `exploration_only: true`, and the copied validation source pins.
Its sole changed setup is `bench/experiments/lobsters_cache_screen.rb`:

```sh
mise exec ruby@4.0.7 -- ruby script/screen "$APP" / /s/enr7ye \
  --config PRIVATE_CONFIG --output NEW_PRIVATE_DIRECTORY \
  --exploration-setup "$PWD/bench/experiments/lobsters_cache_screen.rb" --warmup 500 --samples 600
```

For the interpreter attempt, extract the exact scratch driver/worker from the
JSON with `jq -rj '.driver.source'` / `jq -rj '.worker.source'` into
`.lowrail/lobsters-cache/ir-driver.rb` / `ir-worker.rb`. Use a clean checkout
at the measured revision, not the later docs publication. Compile an empty
interpreter artifact at `.lowrail/lobsters-cache/empty-ir` with the public
`Lowrail::Compiler.compile`, and build/verify `/tmp/lowrail-cache-valgrind-brk512`
with `script/bench-valgrind`. The frozen driver refuses changed source, reused
output, wrong mode, altered floors, seed, overlay or tool pins:

```sh
PATH="/tmp/lowrail-cache-valgrind-brk512/bin:$PATH" \
CPATH="/tmp/lowrail-cache-valgrind-brk512/include" \
BENCH_JOBS=1 BENCH_JIT=0 BENCH_ROUNDS=6 BENCH_SEED=41231 \
BENCH_REQUESTS=50 BENCH_WARMUP=50 BENCH_COUNTER=callgrind \
  mise exec ruby@4.0.7 -- ruby "$PWD/.lowrail/lobsters-cache/ir-driver.rb" "$PWD" NEW_PRIVATE_OUTPUT
```

This documents the one executed attempt, not authorization for another one.
The serial bench-only prototype is retained on its branch. Promoting it would
still require source-certified passive admission, safe cold/concurrent
discovery, and cold/retained-memory assessment; no such work is claimed here.
