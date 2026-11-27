---
id: RUD1
repo: ruby/ruby
kind: fix
area: vm_method.c, resolve_refined_method (send, method, respond_to? ignore an undef in an active refinement)
reviewer: "shugo (refinements)"
branch:
head:
base: master
built_on: "0d399335b7"
depends_on: []
tracker: []
stacked_on:
alternative_of:
impact: "An undef_method in an active refinement is honored by direct calls only; send, public_send, method, respond_to? and &:foo find the original method; 3.4.13, 4.0.10 and master, all engines"
rank: 3
risky: true
state: held
pr:
note: "Path: Redmine ticket for Thomas, no PR (DECISIONS, A clear PR before a ticket): the intended behaviour is a maintainer question (no doc or test covers undef for these lookups) and honoring it changes reflection results in a lookup shared with method_defined?, alias and undef; no fix yet. Ticket draft: docs/upstream-drafts/ruby-bug-active-refinement-undef.md. No duplicate found. Related crash: RUC1. Found by the 2026-11-27 lead sweep."
evidence:
  - bench/upstream/ruby-bugs-2026-11-27
passes: []
---

# undef_method in an active refinement is ignored by send, method and respond_to?

Ticket path; see docs/upstream-drafts/ruby-bug-active-refinement-undef.md.
