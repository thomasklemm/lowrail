---
id: ZWB1
repo: ruby/ruby
kind: perf
area: ZJIT, compile time (iseq_may_write_block_code)
reviewer: "k0kubun (asked for IseqPayload on #19962 and for a per-compile cache on #19680), tekknolagi (asked on #19962 to reopen #19680)"
branch: thomasklemm/zjit-cache-may-write-block-code-2
head: "82c529aa2e"
base: master
built_on: "7919a47d46"
depends_on: []
stacked_on:
alternative_of: "tenderlove's open #19962 (same cache in the ISEQ params bit field); only one of them should land"
impact: "a 4,000-call method compiles in 3.53 s instead of 11.64 s (compile_lir_time 11.59 s -> 3.49 s); IseqPayload stays 152 bytes; app compile time within A/A"
rank: 1
risky: false
state: built
pr:
note: "Built 2026-11-17 night; not opened (ZS1 waits for a response; Thomas decides between reopening #19680 with this head, offering it on #19962, or leaving it to tenderlove). Comment draft in docs/upstream/zjit-shortlist.md. No review passes yet."
passes: []
---

# ZJIT: Cache iseq_may_write_block_code() on the ISEQ payload

`iseq_may_write_block_code()` scans an ISEQ's whole bytecode, and since stack maps (#18960) every JITFrame calls it: once per CCall with a frame and once per side exit. In one large method that makes compilation quadratic in method size, which #19962 measures on its 4,000-call example.

This keeps the answer in `IseqPayload`, as k0kubun suggested on #19962, instead of the ISEQ's params bits. Profiling and tracing rewrite instructions only into variants of the same opcode, which `rb_iseq_bare_opcode_at_pc()` normalizes, so the cached answer stays valid. The `Option<bool>` fits in the payload's padding: `size_of::<IseqPayload>()` is 152 bytes before and after.

Fixes Shopify/ruby#1064

#19962's program (`n = 4000`, `--zjit-call-threshold=2`, `--zjit-stats-quiet`):

```
master:  compile_time_ns: 11,640,744,647  compile_lir_time_ns: 11,592,179,366  zjit_alloc_bytes: 5,190,720
branch:  compile_time_ns:  3,532,881,700  compile_lir_time_ns:  3,485,295,016  zjit_alloc_bytes: 5,190,720
```

On ruby-bench (3 iterations, two rounds, `master-aa` a second build of master), `compile_time_ns` and `zjit_alloc_bytes` stay within the difference between the two master builds on railsbench, lobsters and shipit.
