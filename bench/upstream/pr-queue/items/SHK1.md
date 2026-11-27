---
id: SHK1
repo: ruby/ruby
kind: fix
area: prism_compile.c, pm_compile_hash_elements (hash literals under shareable_constant_value)
reviewer: "kddnewton (author of 391b6746cd)"
branch: fix-prism-shareable-hash-merge
head: "2bda3f18fa443e82d3172db13deeede7c567734a"
base: master
built_on: "0d399335b7"
introduced_by: "391b6746cd"
depends_on: []
tracker: []
stacked_on:
alternative_of:
impact: "With prism, every hash literal with a pair after `**` (or with more than 128 non-static pairs) in a constant under shareable_constant_value literal, experimental_everything or experimental_copy raises NoMethodError for an internal method, on 3.4.0 and later; two-line compiler fix, results then match parse.y"
rank: 1
risky: true
state: reviewed
pr:
note: "2026-11-27 (Thomas, via coordinator): open directly on ruby/ruby without a Redmine ticket, as an exception to the ruby/ruby pace cap; body carries the report's repro, actual/expected output and versions. Draft, cause, evidence and the earlier report text: docs/upstream-drafts/ruby-bug-shareable-kwsplat.md; data: bench/upstream/ruby-bugs-2026-11-27. Tests on 9b8a037535 (same tree): parser tests 778/0, parse.y 190/0, btest 2148, test-all ruby 11761 with only TestThread#test_handle_interrupt_masks_sigint (fails on unmodified master in the orb; 0 failures in both reviewers' orbs). Found by the 2026-11-27 lead sweep (row 337)."
evidence:
  - bench/upstream/ruby-bugs-2026-11-27
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #12417"], hits: []}
passes:
  - reviewer: thermos-sol
    orb: T-01a21eca-5c03-7779-b80e-e03aef7db05c
    head: "2bda3f18fa443e82d3172db13deeede7c567734a"
    date: 2026-11-27
    verdict: approve
    open: "Head, test and commit message approved; report and PR text approved after mode qualifications. One reviewer applied both thermos rubrics. Body delta confirmed below."
  - reviewer: astra
    orb: T-01a21eca-63e1-76f7-b473-ee3433ea1051
    head: "2bda3f18fa443e82d3172db13deeede7c567734a"
    date: 2026-11-27
    verdict: approve
    open: "Head approved after adversarial hash-shape probes in all modes and both parsers; mode-qualified texts approved. Body delta confirmed below."
  - reviewer: thermos-sol
    orb: T-01a21eca-5c03-7779-b80e-e03aef7db05c
    head: "2bda3f18fa443e82d3172db13deeede7c567734a"
    date: 2026-11-27
    verdict: approve
    open: "Delta confirm of the ticketless body at lowrail 62ee8953: every sentence checked against retained runs and source; no change requested."
  - reviewer: astra
    orb: T-01a21eca-63e1-76f7-b473-ee3433ea1051
    head: "2bda3f18fa443e82d3172db13deeede7c567734a"
    date: 2026-11-27
    verdict: approve
    open: "Delta confirm of the ticketless body at lowrail 62ee8953 after its three wording fixes (2134d778 review: changes); no remaining must-fix."
---

# Fix shareable constant hash literals with keys after `**` in prism

On master with prism, a hash literal in a shareable constant raises NoMethodError for an internal method when a key follows a double splat:

```ruby
# shareable_constant_value: experimental_everything
H = { b: 2 }
X = { **H, a: 1 }
p X
# expected, as with --parser=parse.y: {b: 2, a: 1}
# actual: undefined method 'core#hash_merge_bang_ptr' for an instance of Hash (NoMethodError)
```

The same happens under `experimental_copy`, and for hash literals with more than 128 pairs that are not all static literals. Ruby 3.4.13 and 4.0.10 fail the same way with `core#hash_merge_ptr`; parse.y returns the hash on all three.

For shareable constants, `pm_compile_hash_elements` compiled each key and value into `ret` instead of `anchor`, so every chunk after the first had its pairs below the receiver of the merge call. This came with 391b6746cd. This compiles them into `anchor`, as the non-shareable path does. The elements are still evaluated in source order, and the results now match parse.y in the `experimental_everything` and `experimental_copy` modes.
