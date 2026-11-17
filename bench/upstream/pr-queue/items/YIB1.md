---
id: YIB1
repo: ruby/ruby
kind: perf
area: YJIT, invokeblock
reviewer: k0kubun
branch: thomasklemm/yjit-invokeblock-guard-symbol-proc
head: "db9cf0f449"
base: master
built_on: "ba43f8fa9b"
depends_on: []
stacked_on:
alternative_of:
impact: "Once any code runs each(&:sym), the yield in the non-inlined Array#each stays generic for every C Enumerable (group_by, each_with_object, each_with_index); 258–11,728 such yields per request in the VM1 apps. Repro 80,620 to 620 invokeblock_symbol; micro wall −11 to −13% on the Mac (A/A ≤ 0.4%), Callgrind on x86 still to run"
rank:
risky: true
state: held
pr:
note: "YJIT parked, Thomas 2026-11-17: focus on ZJIT. Prototype of the yjit-leads lead (record: docs/upstream/yjit-leads.md#yib1-guard-the-block-handler-type-before-a-generic-invokeblock); built on Thomas's Mac (arm64), btest at threshold 1, test_yjit.rb, test_yjit_exit_locations.rb, cargo test and the interpreter/YJIT differential pass; no x86 Callgrind, ruby-bench or review rounds. ZJIT has no such gap. No CI on the fork."
passes: []
---

# YJIT: Guard the block handler type before a generic invokeblock

When `invokeblock` is first compiled with a Symbol or Proc block handler, YJIT falls back to `rb_vm_invokeblock` without guarding the handler type, so that version of the yield stays generic for every later block. This hits the non-inlined `Array#each`, which C methods such as `group_by` and `each_with_index` call: once some code runs `each(&:sym)`, their yields take the generic path too, although YJIT specializes the IFUNC blocks they pass.

```ruby
a = (1..20).to_a
60.times { a.each(&:to_s) }
2_000.times { a.each_with_index { |x, i| }; a.group_by { |x| x % 3 } }
```

This change guards that the handler is neither an ISEQ block nor an IFUNC before falling back, as the ISEQ and IFUNC paths already guard their tags, so other handler types chain to their own versions. Symbols, Procs and no block still take the generic call, as before.

Generic yields for the snippet above, `--yjit-stats`:

| | master | this branch |
| --- | ---: | ---: |
| `invokeblock_symbol` | 80,620 | 620 |
