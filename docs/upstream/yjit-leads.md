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

## Leads not built

- **`super` from a module prepended to a singleton class** ([Action View CPU](actionview-cpu.md)).
  Every `ERB::Util.html_escape` goes through an alias plus `super` that YJIT never specializes
  (`invokesuper_singleton_class`, 97% of `super` calls on erubi-rails). #19487 covers Class/Module
  receivers; Rails C2 measured the possible gain at −4.8% YJIT instructions on erubi-rails (4.0.7).
- **`sendforward` with caller arguments** ([record](yjit-sendforward.md)): the 25–50% of sites
  #19671 leaves, counted as `send_forwarding_caller_args`. ZJIT's counterpart is #18326 (nozomemein).
- **`where!(opts, *rest)` with a splat** allocates 2 Arrays under YJIT vs 1 in the interpreter
  ([JIT parity census](jit-parity-census.md)).
