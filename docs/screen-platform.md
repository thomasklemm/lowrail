# Interpreter request screen

`script/screen APP ROUTE... --artifact DIR --output NEW_DIRECTORY` reuses
`RequestPairs.heap_instructions`, `HeapWindows`, the pinned
`script/bench-valgrind` tool and the earlier native screen's Rack/fixture adapters.
It measures instrumented synchronous warm requests, not native latency,
whole-app support or production admission. It never retries a counted run.

## Output and acceptance

- Six independent off-A/off-B/on rounds, seed 41231, serial shuffled arms,
  alternating total/no-GC order, warmup50 and N0/N50 by default. Each arm's
  own empty window is subtracted. Objects/request and interpreter Ir are
  paired by round, not treated as independent requests.
- Per-route total/no-GC Ir and allocations: medians, paired on-minus-off
  differences and percentage changes with 5,000-round bootstrap nominal
  95% intervals. Each route's total/no-GC A/A intervals must lie wholly
  within ±0.1%. Zero containment is not required. Historical benchmark
  callers retain their original default rule. Each summary records both
  its tolerance and whether zero containment was required.
- Exact status, body bytes and complete headers at seeds 0 and 1 before
  and after windows. Existing source-pinned companions control only their
  named entropy sites, never normalize responses. An app without a companion
  is compared literally and can reject for raw cookies/runtime headers.
- Every counted window records cache events with hashed keys, before/after
  cache byte-state hashes, newly loaded features, minor/major GC counts,
  connection-pool reap/flush calls and actual-dump native signatures for
  Marshal dump, deflate, binwrite, rename and require/load. Signatures are
  explanatory; their work is never retrospectively subtracted.
- Matching background/event/GC mix, unchanged cache state, available cache
  adapters, exact responses, all five heap ranges/exact pages, brk512,
  observed interpreter mode, unchanged input pins and no runtime refusal
  are required. Mismatches reject the whole cohort, with all windows retained.

`protocol.json` records settings, revision and file pins before workers;
`samples.json`, `summary.json` and `result.json` retain all samples, windows
and gate decisions. Existing output directories refuse before spawning.
Logs/configs can contain private app data: review before publishing.

## Cheap preparation, then a finite protocol

```sh
bash script/bench-valgrind /tmp/NEW-valgrind # once; keep its provenance JSON
export PATH="/tmp/NEW-valgrind/bin:$PATH"
export CPATH="/tmp/NEW-valgrind/include${CPATH:+:$CPATH}"
mise exec ruby@4.0.7 -- ruby script/screen --help
mise exec ruby@4.0.7 -- ruby script/screen .corpus/APP /path \
  --artifact .corpus/APP/.lowrail --output /tmp/NEW-budget --budget
# Preregister finite settings, gates and calibration criteria before counting.
mise exec ruby@4.0.7 -- ruby script/screen .corpus/APP /path \
  --artifact .corpus/APP/.lowrail --output /tmp/NEW-counted
```

`--budget` runs three tool=none workers, not Ir: exact responses, background
state, heap endpoints and enabled-path counters remain in `budget.json`.
Use it to diagnose fixture/control problems before freezing a counted
protocol. A budget is not a support certificate. No speed claim follows from
budget wall time. This command has only the interpreter contract: no native
wall/noise mode, YJIT artifact path or silently ignored native-only flags.

`--config JSON` accepts the existing corpus adapters' `workload`, `seed`,
`gemfile`, `exploration_setup`, `headers` and `entropy_policy`, plus
`storage_seed`, `reset_cache` and `epoch`. Existing input paths are resolved
against the caller's working directory and canonicalized before spawning;
command-line options override JSON. Use existing authenticated scenario
adapters, not app edits. `storage_seed` restores disposable storage before
each worker. Its directory must not overlap storage (including ancestors,
descendants or symlink aliases), and output must stay outside seed directories.
Output's existing parents are canonicalized too, including when several
child directories do not exist yet. These checks happen before any output
creation, storage deletion or worker boot.

## Explicit cache/time/background scope

`--reset-cache` clears the app's configured cache before warmup. It is
destructive: use only a dedicated disposable cache, never shared Redis or a
production cache. The command requires an app under this checkout's
`.corpus/`, but that path alone does not prove its services are disposable.

`--epoch INTEGER` (also an integer in JSON, never truncated from a float)
fixes `Time.now` before boot in every arm. Time objects and
timezone options remain ordinary; monotonic clocks stay real. Warm caches
then retain their original TTL checks without expiring during a long
counter window. This is an explicit **fixed-instant workload**, not a claim
about advancing time. Independent exactness companions use the same epoch.
An `entropy_policy` with a different wall-clock epoch refuses before boot
or output creation, rather than validating a different instant from counting.
No cache result or deserialized mutable graph is substituted by the harness.

FileStore snapshots hash actual file bytes. SolidCache snapshots select raw
serialized/encrypted rows in every configured shard outside endpoints, with
query caching disabled and no model deserialization or cache-read effects.
Only already-loaded constants are inspected. NullStore has no stored state;
unknown stores record byte-state unavailable and cannot produce an accepted
price. Equal response hashes alone do not prove equal cache state.

The screen holds already-created pools' existing Rails `reaper_lock` across
heap preparation/windows. Threads remain alive, pool config is unchanged,
and asynchronous maintenance is deferred outside the sequence identically
for all arms. New pools or synchronous reap/flush remain observed and reject
contamination. Workloads requiring cross-thread pool maintenance/reload are
outside this synchronous read-only scope. Event instrumentation is charged
equally; large cache/feature/coverage snapshots stay outside endpoints.
This is not a census of every possible application background thread.

Total and no-GC are separate executions; no-GC excludes GC instructions,
not allocations or collections. Report both rather than subtracting GC
savings. Calibrating against an older harness should primarily compare
absolute Ir saved/request: extra common work changes the denominator and
therefore percentages. Freeze tolerances before counting and keep rejected
cohorts rejected; never rerun until a favorable result appears.
