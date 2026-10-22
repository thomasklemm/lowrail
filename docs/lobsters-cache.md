# Bet M: Lobsters cache reconstruction

Branch-only experiment, Ruby 4.0.7 / Rails 8.1.4, ruby-bench
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716).
Shipped SQLite SHA256 `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`,
restored into `:memory:` exactly as upstream. No app source/config changes.

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
The candidate's pre-cost intermediate budget is therefore **279/81** objects
(71+104+104 / 69+6+6), not all 674/98.

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

The dependency overlay, lock, entropy policy, validator, fixture-restoring
setup, `script/native-bench` and `script/screen` are byte-for-byte copies from
bet L's branch. An empty public-compiler YJIT artifact excludes other passes.
This in-process native YJIT screen is direction-finding, not a JIT-flat price,
Puma throughput, whole-app support or production-admission certificate.
