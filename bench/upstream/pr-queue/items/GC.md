---
id: GC
repo: ruby/ruby
kind: fix
area: GC lazy sweep
reviewer: "author of ruby/ruby#16632"
branch: thomasklemm/gc-pool-budget
head: "4b02fa55cb"
base: master
built_on: "9b30fd207f"
depends_on: []
stacked_on:
alternative_of:
impact: "master vs master+fix, 97 workloads: major GCs 86 -> 13 (interp), 98 -> 26 (YJIT); GC time -15% / -23%; RSS +1.7-3.3 MB"
rank: 1
risky: true
state: held
pr:
note: "no new ruby/ruby PRs for now (DECISIONS 2026-11-03); title not drafted yet; no reply on ruby/ruby#17251"
passes: []
---

# Restore the slot-count pool budget for incremental sweeping

On master, heaps with large slots (640 and 768 bytes) run many more full major GCs than on Ruby 4.0. I traced it to ruby/ruby#16632, which made both lazy-sweep budgets a number of bytes divided by the slot size. For the pool that each sweep step sets aside, this means 64 slots for 640-byte slots and 53 for 768-byte slots, less than one page. These heaps then stay small, sweeping finds too few free slots in them, and the GC runs a major GC with reason `nofree` instead of growing them. The script below keeps 70-element arrays (640-byte slots) alive across a few minor GCs. In 40,000 iterations it runs 2 major GCs on Ruby 4.0.7 and 27 to 28 on master.

This PR keeps the byte budget for sweeping and pools 1,024 slots per step in every heap, as Ruby 4.0 did. The script then runs 3 major GCs.

I measured it in ten open-source Rails apps on Rails main, over 97 workloads of 1,000 requests each, master against this branch. Major GCs went from 86 to 13 with the interpreter and from 98 to 26 with YJIT. Total GC time fell 15% and 23%. In ruby-bench, shipit went from 25 to 6 major GCs (interpreter) and 27 to 5 (YJIT), with 20% and 31% less GC time. Railsbench and lobsters run at most one major GC on either build and barely change.

There are two costs. Memory: the 640-byte heap in the script ends with 24 to 29 pages instead of 5 or 6. The apps' resident memory grew 1.7 to 3.3 MB more per workload, and shipit's peak RSS rose 12 to 17 MB. Sweep steps: a single step in a large-slot heap takes longer, 19% (interpreter) and 53% (YJIT) at the 99th percentile, and up to 0.3 → 1.7 ms in one app. The sweep pause an allocation sees grew 4% and 12% at the 99th percentile, and the longest pause stayed at 23 to 25 ms. In ruby-bench that pause grew by at most 0.3 ms at the 99th percentile.

ruby/ruby#17251 also changes when these heaps force a major GC. Rebased onto master, it reduces the majors in the script but does not remove them.

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
