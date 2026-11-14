---
id: VB1
repo: rails/rails
kind: perf
area: Active Model attributes
reviewer: "tenderlove (author of #59141)"
branch: thomasklemm/indexed-set-value-block
head: "59db98e25c"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "Unreleased since #59141: every first read of an attribute (generated readers via fetch_value_at!, id/read_attr/_read_attribute via value_at!) passes &:value! to cast_value, and every record dup maps &:deep_dup; YJIT and ZJIT make each such call a generic send. Block literals remove them (300 -> 0 generic calls for 10 records x 30 reads in both JITs). Callgrind, 30 columns, 10 records each read once: interpreter -2.5%, YJIT -7.5% (4.0.9), ZJIT -20.6% (master 674c477295); dup of a loaded record -1.9% / -5.7% / -12.3%; A/A <= 0.09% in those cells. railsbench-like request mix: ZJIT -0.58% (A/A 0.08%), interpreter within A/A, YJIT cell rejected. Load, #attributes and warm reads unchanged. Lifetime: Rails main only (8.1 has no LazyIndexedAttributeSet); runs on every Ruby."
rank: 6
risky: false
state: built
pr:
note: "ZJIT leads 3 and 7, lead 7c (docs/upstream/zjit-leads.md). Built and measured in thread T-01a1db12-4922-7731-840b-735d41b72d93; record in bench/upstream/vb1/README.md. Merges clean with K1 (#59800) and L3. Needs a claude-code pass and an opus (or Sol) pass on this head. Open nothing until Thomas has read it."
passes:
  - {reviewer: opus, head: "59db98e25cd4e2e55bc9023d9c5af896eab9de33", date: 2026-11-14, verdict: nits, orb: T-01a1db63-3cf3-726b-858d-e4cd657d6b35, open: "Independent review (Opus standing in for Sol); no must-fix. Head: one commit on rails/rails main 50c54eed06 (still main), +3/-3 in attribute_set.rb, author and committer Thomas Klemm <github@tklemm.eu>, no trailers, no added comments, diff --check clean; the block literals read like the existing cast_value(...) { |attribute| attribute.value(&block) } lines beside them. Exactness: cast_value yields once, only on the default path, with one Attribute; transform_attributes! yields one; value! and deep_dup are public; no using in the file. Own probe (vb1_opus_probe.rb in this orb's .amp/in/orb-backup, 954 lines: loaded, partial, SELECT AS, new, STI, becomes, Marshal, frozen records x 15 attributes x reader/[]/_read_attribute, plus id, attributes, dup, clone, read-write-dup, dup isolation, save, reload; types that raise, throw and Fiber.yield inside the cast; a prepended module on Attribute logging every value!/deep_dup with class, block_given?, argc and callers; objects allocated per operation): main and main2 byte-identical; main against the branch identical on the Ruby 4.0.9 interpreter (SQLite and PostgreSQL 17), 4.0.9 YJIT (SQLite) and ZJIT on master 674c477295 (SQLite) once the added block frame (412/534/444) is dropped, including call order and counts, block_given? false, argc 0 and interpreter allocation counts. A private value! raises the same NoMethodError on both; a refinement in the caller's file applies to neither; 8 threads racing first reads and dups on 50 shared records: 0 mismatches on both. Differences found, none reachable without patching internals: (1) a prepended cast_value or map capturing the block sees a proc of arity 1 instead of Symbol#to_proc's lambda of arity -2; (2) once anything in the process refines ActiveModel::Attribute#value! or #deep_dup (even unused), each block-literal call allocates one more object (2 first reads 52 -> 54 objects, dup of 6 attributes 23 -> 29), Symbol#to_proc doesn't; values unchanged; cause in the VM not traced; (3) under YJIT a few exception-path cells differ by +-1 object between trees in a fixed process, moving to other cells with more warmup (compile timing). Ractor not probed (Active Record doesn't run in non-main Ractors; no captured state added). Author's probe.rb rerun: 962 lines, probe_diff.sh prints nothing, 26 raw lines differ. Suites on the head, Ruby 4.0.9: Active Model 1,269 runs 0 failures (-w, no warnings); Active Record SQLite 10,375 runs 0 failures, 4 errors from the missing sqlite3 CLI, sqlite_rake_test 15/15 once installed; PostgreSQL 17 11,298 runs 0 failures 0 errors 31 skips; RuboCop 1.90.0 no offenses. git merge-tree with K1 (bbdd9945d3), L3 (52587b6f5d) and K1+L3: clean. Claims: #59141 is tenderlove's merged PR and both Symbol-block lines come from its commits (f547f565e4, f237130653, a1656e9f21), none on 8-1-stable; every Active Record record's set is LazyIndexedAttributeSet (ReindexedAttributeSet after becomes, which delegates deep_dup); YJIT exit_if_unsupported_block_arg_type and ZJIT hir.rs on master take only nil/proxy/Proc block args; counters per call: YJIT send_iseq_block_arg_type 300 -> 0 (10 records read once), 1 -> 0 and one side exit fewer (dup); ZJIT send_fallback_send_block_arg_not_nil 300 -> 0 (dynamic sends 322 -> 22), dup 1 -> 0, send_fallback_invokeblock_not_specialized 30 -> 0; footer link 200 and public. Callgrind rerun on this orb (pinned Valgrind rebuilt by script/bench-valgrind: same source and patch hashes, tool hash differs, fixed heap, N=200, all cases in one process, 0 GCs, objects equal on all trees): 10 records read once interp -2.50% (A/A -0.00%), YJIT -7.56% (+0.01%), ZJIT -20.60% (+0.02%); dup interp -1.88% (-0.01%), YJIT -5.58% (+0.08%), ZJIT -12.33% (+0.04%); every JIT window passes the gate. Body table and A/A line match within 0.15 points. Body: 123 words plus table and footer, clear to a Rails maintainer; no internal IDs, other branches, queue or process (Nothing internal upstream); title says what changes; commit message accurate. Optional: (a) impact says load, #attributes and warm reads unchanged: true in the interpreter and ZJIT, but YJIT find is +0.13% on this orb in 3 processes per tree with identical YJIT instruction and dynamic-send counts, #attributes +0.10% to +0.29%, warm reads +1.55% with all cases in one process and equal when run alone; say unchanged within 0.3% except YJIT compiled-state variance. (b) Record: read_all reads id and 29 others through slot readers at 30 columns, not 31. (c) Table rows might say instantiate 10 records from a result rather than load, since no query runs in the window."}
---

# Pass block literals instead of Symbol blocks in `LazyIndexedAttributeSet`

Since #59141, the first read of each attribute of a loaded record goes through `cast_value(name, index, &:value!)` in `LazyIndexedAttributeSet#fetch_value_at!` or `#value_at!`, and every `dup` of a record runs `map(&:deep_dup)`. YJIT and ZJIT don't specialize a call whose block argument is a Symbol, so each of these calls falls back to a generic send.

This passes block literals that call the same methods. They run at the same moments on the same attributes, so values and exceptions are the same; an exception raised inside the block has one more frame in its backtrace.

Callgrind instructions per call against main, 30-column records, Ruby 4.0.9 without JIT and with YJIT, ZJIT on Ruby master 674c477295:

| | no JIT | YJIT | ZJIT |
|---|---:|---:|---:|
| load 10 records, read each attribute once | −2.5% | −7.5% | −20.6% |
| `dup` of a loaded record | −1.9% | −5.7% | −12.3% |

A second checkout of main moved by at most 0.09%.

---

<sub>Found while looking at ZJIT fallbacks on Rails main ([record](https://github.com/thomasklemm/lowrail/blob/0f5be21ef3f327f52820fabdd9edd835a33cbff6/bench/upstream/vb1/README.md)), part of my research project Lowrail.</sub>
