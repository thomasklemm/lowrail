# YJIT leads (parked)

Since 2026-11-03, new JIT performance work goes to ZJIT. k0kubun asked for this on
[ruby#19671](https://github.com/ruby/ruby/pull/19671#issuecomment-6596469897): the team wants ZJIT faster
than YJIT in Ruby 4.1 and has no bandwidth for a stream of YJIT performance PRs. Thomas agreed.
YJIT still gets correctness fixes. This page keeps the YJIT findings, so they can be picked up later
if YJIT performance work becomes relevant again. Before building one, check whether ZJIT has the same
gap; if it does, the ZJIT fix comes first.

## Open YJIT performance and parity PRs

These were submitted before the policy. Each has a full record in [contributions.md](contributions.md).

| PR | What | Evidence |
| --- | --- | --- |
| [#19487](https://github.com/ruby/ruby/pull/19487) | `super` on Class/Module receivers | singleton-super fallbacks/request 141 → 13 blog, 300 → 16 Fizzy |
| [#19664](https://github.com/ruby/ruby/pull/19664) | no splat dup before slicing into a rest parameter (`where!(*args)`) | ruby-bench objects −0.07 to −0.13% |
| [#19665](https://github.com/ruby/ruby/pull/19665) | interpolate Integers and Modules without `to_s` | `"#{klass} Update"` 2 → 1 object; shipit −0.21% |
| [#19666](https://github.com/ruby/ruby/pull/19666) | reuse a splat array as the rest parameter (`rest_dupped` parity) | `process_action(*) = super` 5 → 3 objects |
| [#19671](https://github.com/ruby/ruby/pull/19671) | specialize `sendforward` when the caller passed no arguments | `send_forwarding` 75,134 → 0 per railsbench iteration; Ir −0.47% / −1.08% shipit ([record](yjit-sendforward.md)) |

## Correctness leads (parked)

### `super` in a block rebound with `instance_exec` skips the receiver check

**Parked 2026-11-10 by Thomas; pick up from 2026-11-17.** Not filed. Target: an issue on
[bugs.ruby-lang.org](https://bugs.ruby-lang.org/) (Ruby's Redmine), not GitHub; a fix PR on ruby/ruby can follow.
Found during the 2026-11-10 recheck of [#19487](https://github.com/ruby/ruby/pull/19487)
([record](contributions.md)). It is not caused by #19487, and that PR's `4f8f7fe7e7` keeps it out of the new
Class/Module exemption.

* **Versions:** Ruby master `f6a88fafb2` (`ruby 4.1.0dev (2026-11-10T20:46:27Z HEAD f6a88fafb2) +PRISM
  [x86_64-linux]`), release build with `--enable-yjit --enable-zjit`. YJIT prints `:base` at the default call
  threshold and at `--yjit-call-threshold=1`; the interpreter, `--zjit` and `--zjit --zjit-call-threshold=1` raise
  TypeError. Released versions are not tested yet: the orb's system Ruby 3.3.13 has no YJIT.
* **Cause:** `gen_invokesuper_specialized` (`yjit/src/codegen.rs`) checks
  `rb_obj_is_kind_of(comptime_recv, current_defined_class)` only at compile time. At run time it guards only the
  frame's method entry (`guard_invokesuper_me_changed`), and a rebound block keeps that method entry. So the
  compiled code calls `Base#m` with an `Other` receiver.
* **Existing reports:** none found on 2026-11-10 (Shopify/ruby issues and ruby/ruby PRs searched for `super`
  with `instance_exec` / rebind).

Minimal repro:

```ruby
class Base; def m(x = nil) = :base; end
class Child < Base
  def m(x = nil) = (x ? super() : proc { super() })
end
class Other; def m = :other; end

b = Child.new.m
100.times { b.call }
p(begin; Other.new.instance_exec(&b); rescue TypeError; :type_error; end)
```

Issue draft (verbatim, written 2026-11-10 for GitHub Markdown; adapt the formatting for Redmine when filing):

````markdown
YJIT: `super` in a block rebound with `instance_exec` skips the receiver check

```ruby
class Base; def m(x = nil) = :base; end
class Child < Base
  def m(x = nil) = (x ? super() : proc { super() })
end
class Other; def m = :other; end

b = Child.new.m
100.times { b.call }
p(begin; Other.new.instance_exec(&b); rescue TypeError; :type_error; end)
```

The interpreter and ZJIT print `:type_error` ("self has wrong type to call super in this context: Other (expected Child)"). YJIT on master (f6a88fafb2) prints `:base`, at the default call threshold and at `--yjit-call-threshold=1`.

`gen_invokesuper_specialized` checks `rb_obj_is_kind_of(comptime_recv, current_defined_class)` only at compile time, and guards only the frame's method entry at run time. A rebound block keeps that method entry, so the compiled code calls `Base#m` with an `Other` receiver.
````

## Leads not built

- **`super` from a module prepended to a singleton class** ([Action View CPU](actionview-cpu.md)).
  Every `ERB::Util.html_escape` goes through an alias plus `super` that YJIT never specializes
  (`invokesuper_singleton_class`, 97% of `super` calls on erubi-rails). #19487 covers Class/Module
  receivers; Rails C2 measured the possible gain at −4.8% YJIT instructions on erubi-rails (4.0.7).
- **`sendforward` with caller arguments** ([record](yjit-sendforward.md)): the 25–50% of sites
  #19671 leaves, counted as `send_forwarding_caller_args`. ZJIT's counterpart is #18326 (nozomemein).
- **`where!(opts, *rest)` with a splat** allocates 2 Arrays under YJIT vs 1 in the interpreter
  ([JIT parity census](jit-parity-census.md)).
