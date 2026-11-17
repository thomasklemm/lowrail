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

**Filed 2026-11-17 as [Shopify/ruby#1131](https://github.com/Shopify/ruby/issues/1131)** (Thomas's approved task of 2026-11-14, the draft below with the recheck added). Rechecked first on the ruby/ruby-dev-builder ruby-head of 2026-11-16 (`3eb1f25fc5`): the interpreter and `--zjit` print `:type_error`, `--yjit` and `--yjit --yjit-call-threshold=1` print `:base`. No duplicate found in Shopify/ruby issues. Parked 2026-11-10 by Thomas; a fix PR on ruby/ruby can follow.
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
- **`invokeblock` keeps the first block-handler type of a non-inlined builtin** ([VM1](vm-share.md#ranked-sites)).
  `gen_invokeblock_specialized` returns `None` for a Symbol handler, and the generic version of `Array#each` (the
  one C Enumerables call) keeps that for every later block: after 60 `a.each(&:to_s)`, 2,000 `each_with_index`
  and `group_by` over 20 elements count 80,000 `invokeblock_symbol` instead of 0. 258–11,728 per request in the
  VM1 apps (preloader `group_by`/`each_with_object`, `Result::RowLayout`).
  **Prototyped 2026-11-17 as YIB1, then parked** (Thomas: YJIT parked, focus on ZJIT; queue item `held`), see
  [below](#yib1-guard-the-block-handler-type-before-a-generic-invokeblock).
- **`BasicObject#!=` for receivers whose `==` is `BasicObject#==`** ([VM1](vm-share.md#ranked-sites)).
  `jit_rb_obj_not_equal` specializes only Integer and String pairs, so `nil != :sym` calls `rb_obj_not_equal`,
  which calls `==` through `rb_funcall` (about 20 ns per comparison on 4.0.9; `!(a == b)` is inlined). TE2 removes the
  hottest Rails caller (`tag_options`, 0.5–0.6% of Blog and Lobsters samples).

## YIB1: guard the block handler type before a generic `invokeblock`

Built 2026-11-17 on Thomas's Mac (arm64, release builds `--enable-yjit`) on master `ba43f8fa9b`, branch
`thomasklemm/yjit-invokeblock-guard-symbol-proc` on the fork, head `db9cf0f449`. No issue or PR found first in
ruby/ruby or Shopify/ruby (searched `invokeblock symbol`, `invokeblock_symbol`, `gen_invokeblock_specialized`,
`invokeblock block handler`, `invokeblock polymorphic`; only ZJIT's merged #18211 and the lobsters burndown
Shopify/ruby#1039 came up, neither about this).

* **Cause.** `gen_invokeblock_specialized` guards the handler tag on its ISEQ and IFUNC paths with
  `jit_chain_guard`, but for a Symbol or Proc handler it returns `None` before any guard, so that version of the
  yield is `rb_vm_invokeblock` for every later handler. The non-inlined version of `Array#each` (the one C
  Enumerables reach through `rb_block_call`) has one such yield for all callers.
* **Change** (one file, +22/−5 in `yjit/src/codegen.rs`): on the Symbol/Proc path, load the handler and
  `test` its low two bits; non-zero (ISEQ `0x1` or IFUNC `0x3`) chains with `guard_invokeblock_tag_changed`, the
  same counter and depth limit as the other two paths. Zero covers static and dynamic Symbols, Procs and no block,
  all of which the following generic call handles as before. The other order (ISEQ or IFUNC first, Symbol later)
  already chained and is unchanged.
* **ZJIT.** No such gap. On the ZJIT build here (master `52d41cc992`, `--zjit-stats`) only the Symbol yields
  themselves stay generic (`invokeblock_not_specialized`, `rb_vm_invokeblock`), as with the YJIT fix: repro 620
  (1,200 at `--zjit-call-threshold=1`), Rails-like 20,000 iterations 620, with the later IFUNC yields specialized.

Counters, `--yjit --yjit-stats`, release builds of `ba43f8fa9b` and the branch:

| run | `invokeblock_symbol` base | branch | `num_send_dynamic` base | branch |
| --- | ---: | ---: | ---: | ---: |
| repro (60 `each(&:to_s)`, then 2,000 × `each_with_index` + `group_by` over 20) | 80,620 | 620 | 80,651 | 651 |
| same, `--yjit-call-threshold=1` | 81,200 | 1,200 | 81,260 | 1,260 |
| Rails-like, 20,000 iterations (`group_by(&:post_id)`, `each_with_object`, `each_with_index` over 20 Struct records after 60 `each(&:to_s)`) | 1,200,620 | 620 | | |
| mixed handlers (Symbol, Proc, lambda, `to_proc`, ISEQ, IFUNC, no block, `break`, errors; threshold 1) | 20,400 | 6,150 | 29,895 | 17,895 |

In the mixed file 2,100 of the former `invokeblock_symbol` yields now count as `invokeblock_iseq_not_inlined`:
ISEQ blocks passed straight to the non-inlined `Array#each` stay generic by YJIT's design (the
`BUILTIN_ATTR_INLINE_BLOCK` check, to keep that yield from going megamorphic). C callers pass IFUNCs, which are the
case this fixes. `guard_invokeblock_tag_changed` and `invokeblock_megamorphic` stay 0 everywhere.

Wall time, YJIT default threshold, 15 rounds interleaved base / branch / base again (the A/A), median seconds. Thomas's
Mac in use, so a sanity check only (DECISIONS: wall time on orbs):

| case | base | base again | branch | branch/base | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| repro, 300,000 × `each_with_index` + `group_by` | 0.541 | 0.543 | 0.473 | −12.6% | 0.4% |
| Rails-like, 200,000 iterations, poisoned site | 0.636 | 0.634 | 0.564 | −11.2% | 0.3% |
| Rails-like with one `each(&:to_s)` (below the call threshold, site not poisoned) | 0.554 | 0.556 | 0.559 | +0.7% | 0.4% |

The unpoisoned row is generated code that the change doesn't touch, so its +0.7% is noise. Still needed on x86: a
Callgrind instruction count of the repro and the Rails-like case with A/A, and ruby-bench railsbench/lobsters
(YJIT counters and Ir) to see what the 258–11,728 generic yields per request are worth in an app; the micro wins
above are a ceiling per yield, not a request number.

Verification on the branch build: `make btest RUN_OPTS=--yjit-call-threshold=1` passes all 2,145; `test_yjit.rb`
and `test_yjit_exit_locations.rb` (`RUN_OPTS=--yjit-call-threshold=1`) 157 tests, 0 failures, 1 skip;
`cargo test` in `yjit/` 376 passed. Differential: the repro and the mixed-handler file print the same output on
both builds under the interpreter, `--yjit`, and `--yjit-call-threshold=1` and `=2` (md5 identical across all 16
runs). No test added: the generic path is correct on base too, so a result test fails on neither, and DECISIONS
rules out counter assertions. Scripts in `~/Code/lowrail-bench/.amp/in/yib1`.

**Parked 2026-11-17** (Thomas: YJIT work is only recorded for now, the focus is ZJIT). Stopped here: no full
`make check`, no x86 build or Callgrind, no ruby-bench, no review rounds. The fork branch stays as pushed; YIB1 is
`held`. To pick it up: x86 Callgrind of the repro and the Rails-like case with A/A, railsbench/lobsters counters
and Ir, then Thermos and Astra (VM/JIT code is critical).
