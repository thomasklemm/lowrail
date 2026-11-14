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
passes: []
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
