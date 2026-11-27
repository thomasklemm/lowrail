# L6 Astra confirmation, 2026-11-27

Verdict: **approve**. No remaining must-fixes or nits on the assembled title and body.

Rails head: `8b1c6428ea056b3c5983372d85b85615ae3d3f45`, unchanged and confirmed with
`git ls-remote https://github.com/thomasklemm/rails refs/heads/thomasklemm/indexed-set-inline-lookups`.
Lowrail body reviewed at `cbbdb9f1ef22bf66d096af10af556e2ed91a2594`.
The exact title/body snapshot is `reviewed-body.md`, SHA256
`c4c10132fe3c855442d317878739d227ee1cc36ad49e6165fca6cf8b73c67fea`.

The call-count sentence now has the previously approved scope, the measured update.
The title and remaining mechanism prose still describe the unchanged four-line Rails change.
The benchmark script uses the same schema, values, loaded record and serialization operation
as the retained `body-rerun/body_row.rb`, rather than the earlier multi-case benchmark.
It has no added explanatory code comments or internal references. The body contains no
unsupported allocation claim, prose speed-up claim, or ZJIT claim. Rails remains the only
project cited; the same-day relevance check in the original review still applies.

`python3 .../confirm/check.py` passed: the before/after output lines match
`body-rerun/raw/ips-r2-base.log` and `ips-r1-candidate.log` exactly. The selected rates are
the best of their respective three rounds, 50.195k and 52.253k i/s. All nine retained
IPS windows have present and unchanged compiled-ISEQ, compiled-block and invalidation
counters. The second base cohort and overlapping rounds are retained and disclosed in
the record. No speed-up is inferred from this noisy comparison.

The record and impact now explicitly mark ZJIT results ungated and say they neither
establish a gain nor rule out a regression. They also withdraw the update allocation claim.
`audit_numbers.py` was rerun; the unchanged Callgrind body cells still reproduce from the
archived totals. Its output is `callgrind-check.txt`; no new Callgrind benchmark was run.

The exact Ruby snippet was extracted by `check.py` and executed on both checked-out trees:

```sh
BUNDLE_GEMFILE="$PWD/.amp/in/orb-backup/l6-review/Gemfile-$side" \
  taskset -c 1 ruby --yjit -rbundler/setup \
  docs/upstream/data/rails-main-census-9/lead6/review-astra-2026-11-27/confirm/body-benchmark.rb
```

Ruby is the same 4.0.9 executable used in the original review. These two executions check
that the published snippet runs; they are not a new controlled performance comparison.
Outputs are retained as `snippet-base.log` and `snippet-head.log`.
Code exactness and suite coverage remain the original pass's; this short confirmation
did not repeat the differential probes or full suites. No queue-item or Rails file was edited.
