---
id: RUC1
repo: ruby/ruby
kind: fix
area: vm_method.c, resolve_refined_method (send after an active refinement undefines a module method)
reviewer: "shugo (refinements; Bug #10578)"
branch: fix-refined-undef-defined-class
head: "6bd87c87b9"
base: master
built_on: "0d399335b7"
introduced_by: "5e8a147480"
depends_on: []
tracker: []
stacked_on:
alternative_of:
impact: "An active refinement that undefines a method of an included module makes Kernel#send abort with [BUG] vm_call_method: unsupported method type (7) after a direct call, and with send first both calls ignore the undef; 3.4.13, 4.0.10 and master, interpreter, YJIT and ZJIT"
rank: 2
risky: true
state: built
pr:
note: "Path: PR, not a ticket (DECISIONS, A clear PR before a ticket): a [BUG] abort and an order-dependent result are wrong whatever send should return; the fix is three lines, one concern, verified. Whether send and reflection should honor such an undef in general is RUD1's ticket question. Conflicts with URF1 (#20267) in the same resolve_refined_method block; verified resolution in bench/upstream/ruby-bugs-2026-11-27/combined-URF1-plus-crash-fix-vm_method.diff. Order: open once a maintainer has responded to #20267 (pace rule), on master if it is still open or rebased with that resolution if merged (a rebased head needs its own review); Thomas decides. 6bd87c87b9 is c79eac2cd3 with the reviewed commit message corrected, same tree. introduced_by is where the defined_class_ptr pass-through dates from (2015), not bisected; the crash is present on 3.4.13. Not combined with RUD1 (ticket path). No duplicate on bugs.ruby-lang.org or GitHub. Draft and evidence: docs/upstream-drafts/ruby-pr-refined-undef-crash.md. Found by the 2026-11-27 lead sweep."
evidence:
  - bench/upstream/ruby-bugs-2026-11-27
ownership: {date: 2026-11-27, checked: ["open PRs naming 5e8a147480"], hits: []}
passes:
  - reviewer: thermos-sol
    orb: T-01a21eca-5c03-7779-b80e-e03aef7db05c
    head: "c79eac2cd31a9d60606ed67fde22aefe475307e7"
    date: 2026-11-27
    verdict: changes
    open: "Code and behavioural test approved; PR body, commit message and evidence wording corrected in 6bd87c87b9 (same tree). Version sentence kept per DECISIONS, A clear PR before a ticket; asked to confirm. One reviewer applied both rubrics."
  - reviewer: opus
    orb: T-01a21f16-f8a9-775c-b419-4f621451d698
    head: "c79eac2cd31a9d60606ed67fde22aefe475307e7"
    date: 2026-11-27
    verdict: changes
    open: "Stands in for Astra (OpenAI safety check stopped T-01a21eca-63e1-76f7-b473-ee3433ea1051; brief's fallback). Code and test approved, 1900-case matrix per build and engine; body replaced with its text, order changed to after a maintainer responds to #20267."
  - reviewer: opus
    orb: T-01a21f16-f8a9-775c-b419-4f621451d698
    head: "6bd87c87b9"
    date: 2026-11-27
    verdict: approve
    open: "Re-check at lowrail f52c3bc8: head, title, body, RUC1.md body, commit message, status and order approved; RUD1 report approved (fill or drop ruby/ruby#NNNNN). One record-only evidence wording fix applied. Optional body polish (three 'there') not applied, to keep the approved text."
---

# Keep defined_class when an active refinement undefines a module method

An active refinement that undefines a method of an included module makes `send` abort after a direct call:

```ruby
module M; def foo = :m; end
class C; include M; end
using Module.new { refine(M) { undef_method :foo } }
p((C.new.foo rescue $!.class)) # NoMethodError
p C.new.send(:foo)             # [BUG] vm_call_method: unsupported method type (7)
```

With `send` called first, both calls return `:m` instead. This happens on 3.4.13, 4.0.10 and master, in the interpreter and with YJIT, and with ZJIT on 4.0.10 and master.

`resolve_refined_method` searched the refinement with the caller's `defined_class` pointer, so a search that stopped at the undef left the refinement's iclass there. Completing the module's method in that iclass then returned the undef entry the direct call had cached there; with `send` first, the module's method was cached there instead. This sets `defined_class` only when the refinement's method is returned, so `send` raises NoMethodError in either order, like the direct call.

`public_send`, `method` and `respond_to?` still find the module's method, now in either order; after a direct call, `public_send` and `method` used to find the undef entry. For a method of a class, `send` still finds the original method.
