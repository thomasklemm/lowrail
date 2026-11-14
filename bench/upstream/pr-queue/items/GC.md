---
id: GC
repo: ruby/ruby
kind: fix
area: GC lazy sweep
reviewer: "author of ruby/ruby#16632"
branch: thomasklemm/gc-pool-budget
head: "7bc813e025"
base: master
built_on: "b7e8fad022"
depends_on: []
stacked_on:
alternative_of:
impact: "master vs master+fix (2026-11-14): census YJIT 35 workloads majors -82.5%, GC time -27.4%; shipit 23 -> 5 (interp), 25 -> 5 (YJIT) majors; RSS +1.2-1.8 MB per workload"
rank: 1
risky: true
state: held
pr:
note: "ruby/ruby#17251 head 41c689571a (draft, 2026-11-13) now removes the same majors at the same app RSS (census majors -95%); drop this if #17251 lands, keep as fallback otherwise. Round 2: docs/upstream/ruby-master-round-2.md section 5"
passes: []
---

# Restore the slot-count pool budget for incremental sweeping

On master, heaps with large slots (640 and 768 bytes) run many more full major GCs than on Ruby 4.0. I traced it to ruby/ruby#16632, which made both lazy-sweep budgets a number of bytes divided by the slot size. For the pool that each sweep step sets aside, this means 64 slots for 640-byte slots and 53 for 768-byte slots, less than one page. These heaps then stay small, sweeping finds too few free slots in them, and the GC runs a major GC with reason `nofree` instead of growing them. The script below keeps 70-element arrays (640-byte slots) alive across a few minor GCs. In 40,000 iterations it runs 1 or 2 major GCs on Ruby 4.0.9 and 24 to 31 on master.

This PR keeps the byte budget for sweeping and pools 1,024 slots per step in every heap, as Ruby 4.0 did. The script then runs 3 major GCs.

I measured it in three open-source Rails apps on Rails main with YJIT, over 35 workloads of 500 operations each, master against this branch in two alternating rounds. Major GCs went from 25 and 15 to 3 and 4, and total GC time fell 27%. In ruby-bench, shipit went from a median of 23 to 5 major GCs with the interpreter (five rounds, one of which inverted: 7 against 14) and from 24–26 to 5–9 with YJIT, with 21% and 29% less GC time. Railsbench and lobsters run at most one major GC on either build and barely change.

There are two costs. Memory: the 640-byte heap in the script ends with 30 to 32 pages instead of 4 to 7. The apps' resident memory grew 1.2 to 1.8 MB more per workload, and shipit's peak RSS rose 10 to 15 MB. Sweep steps: a single step in a large-slot heap takes longer, about three times as long at the 99th percentile in the apps (0.58 → 1.7 ms) and 40–80% longer on shipit. The sweep pause an allocation sees did not grow in the apps (99th percentile 2.2–3.1 ms on both, longest about 20 ms).

ruby/ruby#17251 also changes when these heaps force a major GC. Its current head, cherry-picked onto the same master, removes these majors too (the script: 1 to 5; the apps: 1 per round; shipit: 4 to 5) at about the same memory cost in the apps, while keeping the script's 640-byte heap at 4 to 5 pages. If #17251 lands, this PR is not needed.

<details><summary>Script</summary>

```ruby
# RING=200 BIG=70 N=40000 ruby bigslot.rb
keep = Array.new(300_000) { |i| i.even? ? "k#{i}" : [i] }
big = Integer(ENV.fetch("BIG", "90"))
ring = Array.new(Integer(ENV.fetch("RING", "300"))); pos = 0
iter = -> { 2000.times { |i| "s#{i}"; [i, i] }; ring[pos] = Array.new(big, 0); pos = (pos + 1) % ring.size }
2000.times { iter.() }; GC.start
heap_of = -> { GC.stat_heap.values.find { |h| h[:slot_size] >= big * 8 + 16 } }
m0 = GC.stat(:major_gc_count)
by = Hash.new(0)
Integer(ENV.fetch("N", "20000")).times do
  m = GC.stat(:major_gc_count)
  iter.()
  by[GC.latest_gc_info(:major_by)] += 1 if GC.stat(:major_gc_count) != m
end
heap = heap_of.()
puts format("%s: %d major %p; %d B heap: %d pages", RUBY_VERSION, GC.stat(:major_gc_count) - m0, by,
  heap[:slot_size], heap[:heap_eden_pages])
```

</details>
