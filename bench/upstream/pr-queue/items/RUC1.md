---
id: RUC1
repo: ruby/ruby
kind: fix
area: vm_method.c, resolve_refined_method (send after an active refinement undefines a module method)
reviewer: "shugo (refinements; Bug #10578)"
branch: fix-refined-undef-defined-class
head: "c79eac2cd3"
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
note: "Path: PR, not a ticket (DECISIONS, A clear PR before a ticket): expected NoMethodError is settled by Bug #10578 and Feature #11476, the fix is three lines, one concern, verified, and removes a [BUG]. Conflicts with URF1 (#20267) in the same resolve_refined_method block; verified resolution in bench/upstream/ruby-bugs-2026-11-27/combined-URF1-plus-crash-fix-vm_method.diff. Recommended: open after #20267 merges, rebased with that resolution; Thomas decides. introduced_by is where the defined_class_ptr pass-through dates from (2015), not bisected; the crash is present on 3.4.13. Not combined with RUD1 (ticket path). No duplicate on bugs.ruby-lang.org or GitHub. Draft and evidence: docs/upstream-drafts/ruby-pr-refined-undef-crash.md. Found by the 2026-11-27 lead sweep."
evidence:
  - bench/upstream/ruby-bugs-2026-11-27
ownership: {date: 2026-11-27, checked: ["open PRs naming 5e8a147480"], hits: []}
passes: []
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

This happens on 3.4.13, 4.0.10 and master, in the interpreter and with YJIT, and with ZJIT on 4.0.10 and master. With `send` called first, both calls return `:m` instead. Both should raise NoMethodError, as an undef in a refinement does since [Bug #10578](https://bugs.ruby-lang.org/issues/10578).

`resolve_refined_method` searched the refinement with the caller's `defined_class` pointer, so a search that stopped at the undef still left the refinement's iclass there. The module's original method was then cached in that iclass, under the same name as the undef entry the direct call had cached. This sets `defined_class` only when the refinement's method is returned. `public_send`, `method` and `respond_to?` still ignore such an undef, before and after this change.
