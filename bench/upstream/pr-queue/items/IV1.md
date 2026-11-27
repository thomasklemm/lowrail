---
id: IV1
repo: ruby/ruby
kind: perf
area: vm_insnhelper.c vm_setivar (interpreter)
reviewer: "byroot (author of a440f23c70 and e0083cffa3)"
branch:
head:
base: master
built_on: "f3e180b5eb"
depends_on: []
stacked_on:
alternative_of:
introduced_by: "e0083cffa3"
impact: "Ruby 4.1 interpreter regression: a cached `@ivar = v` takes 109-114 Callgrind instructions on master f3e180b5eb against 72-78 on 4.0.9 (+31 to +42); reads, YJIT and ZJIT unaffected. About 43k instructions of an interpreted Campfire GET sidebar request (15.2M, about 0.3%)."
rank: 4
risky: false
state: held
pr:
evidence:
  - bench/upstream/ruby-differential/evidence/ivar-write
note: "Parked (Thomas, 2026-11-27): not reported. Interpreter only, about 0.3% of an interpreted request, from deliberate refactors, no fix; YJIT and ZJIT unaffected. Revisit only with a fix that restores the write path without undoing the refactors. Found in the Ruby 4.1 differential (2026-11-27). Report draft, not a fix: both steps come from deliberate refactors, and the extra source work per write is one layout branch and a NULL check, so the cost is in how GCC compiles vm_setivar into the interpreter, not a logic bug. Removing the forced inline from rb_setivar_cache_revalidate on master changes nothing (111). Held for Thomas: posting needs his OK (new issue), and DECISIONS wants a benchmark/*.yml table from make benchmark on an a1.xxlarge orb first, which this a1.large orb cannot give. No existing report on bugs.ruby-lang.org or ruby/ruby (searched 2026-11-27). No reviews yet."
passes: []
---

# Interpreter: cached instance variable writes cost about 50% more instructions than on 4.0

On master, a cached `@a = v` in the interpreter takes about 110 instructions under Callgrind, against about 75 on Ruby 4.0.9. Reads are unchanged, and YJIT and ZJIT are not affected.

```ruby
class C
  def initialize = (@a = @b = @c = 1)
  def none(v) = v
  def set1(v) = (@a = v)
end
```

Counting `o.set1(1)` against `o.none(1)` under Callgrind, per write:

| Ruby | instructions |
|---|---:|
| 4.0.9 | 72–78 |
| master (f3e180b5eb) | 109–114 |

Bisecting with miniruby builds finds two steps:

* a440f23c70 (Always inline `revalidate_setivar_cache`): 56 → 86. The commits just before it had brought the write down from 76 to 56.
* e0083cffa3 (Refactor RObject to use T_IMEMO/fields_obj on overflow): 79 → 112.

In between, the count moves by a few instructions from unrelated commits. In an interpreted Rails request (Campfire's sidebar), the writes cost about 43k more instructions, about 0.3% of the request.

## For Thomas

Two refactors by byroot, both deliberate; the report asks whether the interpreter write path can get the May speedup back, not for a revert. Before posting: a `benchmark/vm_ivar_set.yml`-style `make benchmark` table on an a1.xxlarge orb, then thermos-sol and Astra on the exact text.
