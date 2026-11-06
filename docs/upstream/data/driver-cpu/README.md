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
  Original measured heads/hashes stay unchanged; `followups` identifies the
  test-only DRV1 head and the corrected DRV2 head, whose completed ordinary
  model-load cohorts pass the relevance gate in interpreter and YJIT.
* `native-memory.json`: base/resize/replacement results for 18 widths on
  Ruby 3.2.9, 3.3.10 and 3.4.8, plus runtime archive/native binary hashes.
  Retained Array/native-buffer memory and embedding are compared exactly;
  `malloc_increase` is only an allocator-sensitive diagnostic.
* `receipts.tar.gz`: raw worker JSONL/logs, complete Callgrind window profiles
  for the selected two candidates' interpreter/YJIT cohorts, three native
  driver-attribution profiles, native YJIT allocation runs, original-tool
  percall runs, suite logs, exactness receipts and resolved bundle locks.
  Both corrected-head `candidate-*-sqlite-fill-store` cohorts include all
  108 window profiles and the workload source used for `relation.spawn.to_a`.
  The TruffleRuby-guard follow-up adds its build/suite logs and byte-identical
  before/after CRuby preprocessing receipts; measured-head hashes stay intact.
  Review-follow-up suite logs, the standalone older-Ruby memory probe and
  its raw/build receipts are included too. That probe uses ordinary
  compaction; its initial repeated-double-heap draft exhausted memory on base
  and produced no accepted observation.
  Other exploratory/baseline full call graphs are not duplicated in this
  archive; their totals and hashes remain in `profile-totals.json`.
* `sqlite-exact.json.gz`: the common, expanded 651-observation output from
  the corrected multi-column/thread-local differential probe. All six
  base/head/mode runs produce byte-identical files. The result digest is of
  the serialized `observations` array, not of the enclosing JSON document.

The end-to-end Active Record validation script and its twelve digest receipts
are inside the archive. It retains results through compaction and repeats 24
API operations. It is a validation probe, not another benchmark framework.
Four further corrected-row-head receipts cover both prepared settings and
interpreter/YJIT, matching the same 24-operation digest.
It uses the orb's `/home/user/workspace/repo` path; run it from that checkout
or adjust the one `load` path when reproducing elsewhere.

All fixture data is synthetic. CPU-time fields in raw worker receipts are
retained for transparency; no elapsed-time or request-speed claim is made.
Neither fork has hosted CI checks, and the pg experimental suite's unrelated
local-service failures are not presented as passing tests.
