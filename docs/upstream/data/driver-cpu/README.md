# P-DRV receipts

Ruby 4.0.9, sources and protocol in [driver-cpu.md](../../driver-cpu.md).
This checkpoint contains the complete interpreter census and the completed
candidate cohorts, including rejected observations. The broad YJIT baseline
census is still running; it is not silently treated as complete here.

* `summary.json`: per-case gates, three paired process observations,
  instructions/objects, compilation counters, warmup history and five-pool
  heap capacities. `accepted` admits the control, not necessarily a candidate
  gain; the candidate interval must also exclude zero in the right direction.
  The original 30-operation SQLite census and five-operation `-v2` are
  distinct keys and are not pooled.
* `profile-totals.json`: every completed cohort's per-window Callgrind total
  and original file SHA256. These totals are the raw counter input to the
  summary, not the dump's incremental `summary:` field.
* `provenance.json`: full source heads, native-extension hashes, Ruby build
  flags and benchmark-source hashes. Versioned and unversioned SQLite native
  binaries match within each tree. The two candidate heads are independent.
* `receipts.tar.gz`: raw worker JSONL/logs, complete Callgrind window profiles
  for the selected two candidates' interpreter/YJIT cohorts, three native
  driver-attribution profiles, native YJIT allocation runs, original-tool
  percall runs, suite logs, exactness receipts and resolved bundle locks.
  Other exploratory/baseline full call graphs are not duplicated in this
  archive; their totals and hashes remain in `profile-totals.json`.
* `sqlite-exact.json.gz`: the common, expanded 651-observation output from
  the corrected multi-column/thread-local differential probe. All six
  base/head/mode runs produce byte-identical files. The result digest is of
  the serialized `observations` array, not of the enclosing JSON document.

The end-to-end Active Record validation script and its twelve digest receipts
are inside the archive. It retains results through compaction and repeats 24
API operations. It is a validation probe, not another benchmark framework.
It uses the orb's `/home/user/workspace/repo` path; run it from that checkout
or adjust the one `load` path when reproducing elsewhere.

All fixture data is synthetic. CPU-time fields in raw worker receipts are
retained for transparency; no elapsed-time or request-speed claim is made.
Neither fork has hosted CI checks, and the pg experimental suite's unrelated
local-service failures are not presented as passing tests.
