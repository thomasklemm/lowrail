---
id: URF1
repo: ruby/ruby
kind: fix
area: vm_method.c, resolve_refined_method (send, respond_to?, method, rb_funcall with an unused module refinement)
reviewer: "shugo (refinements; Bug #14068 fix)"
branch: fix-unused-module-refinement-funcall
head: "151bebd34d0b5eb78aea88a849d8ba11177cfbf6"
base: master
built_on: "0d399335b7"
introduced_by: "a463ab1f05"
depends_on: []
tracker: []
stacked_on:
alternative_of:
impact: "An unused refinement of any included module (Kernel too) hides the methods after that module from send, public_send, respond_to?, method, method_defined?, alias_method, undef_method and every C call through rb_funcall; e.g. refining Kernel#== without using it makes `obj != 1` raise in the interpreter and YJIT on 3.4, 4.0 and master"
rank: 1
risky: true
state: reviewed
pr:
note: "2026-11-27 (Thomas, via coordinator): open directly on ruby/ruby without a Redmine ticket, as an exception to the ruby/ruby pace cap; body carries the report's repro, actual/expected output, versions and why true is right. Draft, cause, evidence and the earlier report text: docs/upstream-drafts/ruby-bug-kernel-eq-refinement.md; data: bench/upstream/ruby-bugs-2026-11-27. thermos-sol found an active-undef regression on 4939c8c7f9, fixed in 07c745a4ab (151bebd34d is the same tree, commit message only). Tests on 07c745a4ab: test-all ruby 11763 interpreter and --zjit-call-threshold=1, only TestThread#test_handle_interrupt_masks_sigint (fails on unmodified master in the orb; 0 failures in both reviewers' orbs); YJIT targeted 754/0; btest 2148 with and without ZJIT; ruby/spec 3577/0, ZJIT repeat 7134/0. Found by the 2026-11-27 lead sweep (row 26, ZNE1 lead 2)."
evidence:
  - bench/upstream/ruby-bugs-2026-11-27
ownership: {date: 2026-11-27, checked: ["open PRs naming a463ab1f05"], hits: []}
passes:
  - reviewer: thermos-sol
    orb: T-01a21eca-5c03-7779-b80e-e03aef7db05c
    head: "151bebd34d0b5eb78aea88a849d8ba11177cfbf6"
    date: 2026-11-27
    verdict: approve
    open: "Head, tests, commit message, report and PR text approved; earlier active-undef regression on 4939c8c7f9 fixed. One reviewer applied both thermos rubrics. Body delta confirmed below."
  - reviewer: astra
    orb: T-01a21eca-63e1-76f7-b473-ee3433ea1051
    head: "151bebd34d0b5eb78aea88a849d8ba11177cfbf6"
    date: 2026-11-27
    verdict: approve
    open: "Adversarial pass: 770 general, 182 Method-object and 896 active-mutation cases per engine, no case where master was right and the head differs. Body delta confirmed below."
  - reviewer: thermos-sol
    orb: T-01a21eca-5c03-7779-b80e-e03aef7db05c
    head: "151bebd34d0b5eb78aea88a849d8ba11177cfbf6"
    date: 2026-11-27
    verdict: approve
    open: "Delta confirm of the ticketless body at lowrail 62ee8953: every sentence checked against retained runs and source; no change requested."
  - reviewer: astra
    orb: T-01a21eca-63e1-76f7-b473-ee3433ea1051
    head: "151bebd34d0b5eb78aea88a849d8ba11177cfbf6"
    date: 2026-11-27
    verdict: approve
    open: "Delta confirm of the ticketless body at lowrail 62ee8953 after its three wording fixes (2134d778 review: changes); no remaining must-fix."
---

# Continue the method search after an unused module refinement in resolve_refined_method

An unused refinement of a method absent from an included module can hide the inherited method from `send` and other lookups:

```ruby
class C; def foo = :C; end
module M; end
class D < C; include M; end
Module.new { refine(M) { def foo = :M } }
p D.new.foo        # :C
p D.new.send(:foo) # expected :C, actual NoMethodError
```

Since `Kernel` is a module, an unused refinement of `Kernel#==` makes `Object.new != 1` raise, because `BasicObject#!=` calls `==` from C. This happens in the interpreter and with `--yjit` on 3.4.13, 4.0.10 and master; with `--zjit` master prints `true`, since ZJIT defines `BasicObject#!=` in Ruby. Per doc/syntax/refinements.rdoc a refinement only takes effect after `using`, and [Bug #14068](https://bugs.ruby-lang.org/issues/14068) fixed the same case for direct calls, so `true` is right.

`resolve_refined_method` continued from the superclass of the module itself, which is usually empty. This continues from the superclass of the class where the refined entry was found, as `search_refined_method` already does for direct calls. The method-defined, alias and undef lookups also pass that class. An undef in an active refinement keeps the existing fallback.
