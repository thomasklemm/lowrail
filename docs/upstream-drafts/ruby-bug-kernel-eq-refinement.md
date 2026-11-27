# Draft: unused module refinement hides a superclass method from `send` and C calls

Status, 2026-11-27: **draft, nothing posted. Approved by thermos-sol and Astra** (report, PR text, commit message and
head `151bebd34d`; Sol thread T-01a21eca-5c03-7779-b80e-e03aef7db05c, Astra T-01a21eca-63e1-76f7-b473-ee3433ea1051).
Both Sol passes were one reviewer applying both rubrics, not two parallel reviewers.
Thomas posts the report (or approves posting) and approves opening the
PR. The PR cites the Redmine ticket, so the ticket goes first; replace `NNNNN` with its number in the PR body and add
`[Bug #NNNNN]` to the commit subject before opening.

Fix head: [`151bebd34d`](https://github.com/thomasklemm/ruby/commit/151bebd34d) on
`thomasklemm/ruby:fix-unused-module-refinement-funcall`, one commit on ruby/ruby master `0d399335b7`. Raw data, repros
and probes: [bench/upstream/ruby-bugs-2026-11-27](../../bench/upstream/ruby-bugs-2026-11-27/).

## Redmine report

**Title:** Unused refinement of a module hides methods after the module from send, respond_to? and rb_funcall

**Description:**

A refinement of a module that is never activated with `using` makes some lookups skip the rest of the ancestors after
that module. A direct call still works:

```ruby
class C; def foo = :C; end
module M; end
class D < C; include M; end
Module.new { refine(M) { def foo = :M } }
p D.new.foo
p D.new.send(:foo)
```

Actual:

```
:C
test.rb:6:in '<main>': undefined method 'foo' for an instance of D (NoMethodError)
```

Expected:

```
:C
:C
```

`public_send` and calls from C with `rb_funcall` raise the same way, `method`, `alias_method` and `undef_method` raise
NameError, and `respond_to?` and `method_defined?` return false. Since `Kernel` is a module, an unused refinement of `Kernel#==` breaks `!=`, which calls `==` from C:

```ruby
Module.new { refine(Kernel) { def ==(other) = true } }
class Foo; end
p Foo.new != 1
```

This raises `undefined method '==' for an instance of Foo (NoMethodError)` in the interpreter and with `--yjit` on
3.4.13, 4.0.10 and master (0d399335b7). With `--zjit` on master it prints `true`, because ZJIT defines
`BasicObject#!=` in Ruby there, so `==` goes through the regular call path. Per doc/syntax/refinements.rdoc a
refinement only takes effect after `using`, and [Bug #14068](https://bugs.ruby-lang.org/issues/14068) fixed the same
case for direct calls, so `true` is the expected result.

When the refined entry has no original method, `resolve_refined_method` in vm_method.c continues the search from
`RCLASS_SUPER(me->owner)`, the superclass of the module itself, instead of after the class that includes it.
`search_refined_method` in vm_insnhelper.c, used for direct calls, already continues after the including class.

## Pull request

**Title:** Continue the method search after an unused module refinement in resolve_refined_method

**Body:**

[Bug #NNNNN](https://bugs.ruby-lang.org/issues/NNNNN)

When a module has an unused refinement for a method it does not define itself, lookups other than a direct call must
still find the method further up the receiver's ancestors. `resolve_refined_method` continued from the superclass of
the module itself, so they did not: `send` and C calls raised NoMethodError, `method`, `alias_method` and
`undef_method` raised NameError, and `respond_to?` and `method_defined?` returned false. For example, an unused
refinement of `Kernel#==` made `Object.new != 1` raise, since `BasicObject#!=` calls `==` from C.

This continues from the superclass of the class where the refined entry was found, as `search_refined_method` already
does for direct calls ([Bug #14068](https://bugs.ruby-lang.org/issues/14068)). The method-defined, alias and undef
lookups also pass that class. An undef in an active refinement keeps the existing fallback.

**Commit message** (subject gets `[Bug #NNNNN]` once the ticket exists):

```
Skip an unused module refinement from the include's superclass

When a refinement of a module M is not active, a lookup of a method that
M itself does not define has to continue after M in the receiver's
ancestors. resolve_refined_method continued from
RCLASS_SUPER(me->owner), the superclass of the module M itself, which is
usually empty, instead of from the iclass that includes M. Lookups that
resolve refinements this way did not find the method, while a direct
call did: send, public_send and calls from C via rb_funcall raised
NoMethodError, Kernel#method, alias_method and undef_method raised
NameError, and respond_to? and method_defined? returned false.

For example, an unused refinement of Kernel#== made `obj != 1` raise,
because BasicObject#!= calls #== with rb_funcall.

Continue from the superclass of the class where the refined entry was
found, as search_refined_method in vm_insnhelper.c already does for
direct calls. The method-defined, alias and undef lookups also pass that
class. An undef in an active refinement keeps the existing fallback.
```

**Diff:** `vm_method.c` (+12/-6: `resolve_refined_method` continues after the class the entry was found in instead of
`me->owner` when it is known, except after an undef in an active refinement, which resolves from the owner as before;
`method_entry_resolve_refinement`, `rb_undef` and `rb_add_alias` pass that class) and two tests in
`test/ruby/test_refinement.rb`, `test_unused_refinement_for_module_method_in_superclass` and
`test_undef_in_active_refinement_for_module_method_in_superclass`
([patch](../../bench/upstream/ruby-bugs-2026-11-27/151bebd34d.patch)).

## Evidence

**Reproduced** ([kernel_eq_refinement_runs.txt](../../bench/upstream/ruby-bugs-2026-11-27/kernel_eq_refinement_runs.txt)):

| Ruby | interpreter | `--yjit` | `--zjit` |
| --- | --- | --- | --- |
| 3.4.13 | NoMethodError | NoMethodError | no ZJIT |
| 4.0.10 | NoMethodError | NoMethodError | NoMethodError |
| master `0d399335b7` | NoMethodError | NoMethodError | `true` |
| head `151bebd34d` | `true` | `true` | `true` |

Ruby 3.4.13 is mise's build; 4.0.10 and master were built from source (`a704b7cd95` and `0d399335b7`) with
`--enable-yjit --enable-zjit`. On both, `RbConfig::CONFIG["ZJIT_SUPPORT"]` is `"yes"` and
`RubyVM::ZJIT.enabled?` is `true` under `--zjit` ([BUILDS.txt](../../bench/upstream/ruby-bugs-2026-11-27/BUILDS.txt)). 4.0.10 fails under ZJIT because `basic_object.rb` is not in 4.0.
The head row is the same build of master plus the fix. The `send(:foo)` repro raises NoMethodError on all of these except the head, including `--zjit` on master. With
error_highlight enabled (the default) the `!=` error prints only `NoMethodError` without a message; with
`--disable-error_highlight` it prints the message above. The draft quotes the message.

**Which side is right:** doc/syntax/refinements.rdoc: "Refinements are only active within a scope after the call to
+using+"; refinements that are never activated must not change behavior. test_refinement.rb has
`test_unused_refinement_for_module` (Bug #14068, unused module refinement must not break a direct call) and
`test_bind_module_method_with_unused_refinement` (Bug #22614, closed last week: "the never-activated refinement
shouldn't change the output"). So ZJIT's `true` is correct and the interpreter and YJIT are wrong. Thomas's reading
holds with one correction: the bug is not in `opt_neq` or in `!=` dispatch. The `!=` call itself resolves fine; it is
`rb_funcall(obj, ==)` inside the C `BasicObject#!=` that fails. ZJIT on master avoids it only because
`basic_object.rb` (81c5830a66) replaces `BasicObject#!=` with a Ruby method under ZJIT, so `==` is a VM
call. ZJIT needs no change.

**Cause, verified:** in `resolve_refined_method` (vm_method.c), a refined entry without `orig_me` (the module defines
no `==` itself) continues at `RCLASS_SUPER(me->owner)`. For a module, `me->owner` is the module, whose superclass is 0,
so the function returns NULL. `search_refined_method` (vm_insnhelper.c) uses `RCLASS_SUPER(refined_cme->defined_class)`,
the iclass, which is the Bug #14068 fix (r60931). The other callers in vm_method.c (`method_defined?` through
`method_entry_resolve_refinement`, `undef_method`, `alias_method`) passed no class at all, so they hit the same
fallback; the head has them pass the class they found the entry in. `instance_methods` (class.c) also passes none
but iterates each ancestor's own table, so it is unaffected and unchanged.

**Undef in an active refinement (found by thermos-sol on `4939c8c7f9`):** `search_method_protect` turns an undef in the
active refinement into NULL, so the lookup fell through to the fallback. On master that fallback found nothing for a
module owner, and `send` raised. With only the superclass fix it reached `P#foo` instead: `send`, `method` and
`respond_to?` returned `:parent`/`true` where master raises or returns false. The head looks the refinement up with
`search_method` and, after an undef, resolves from the owner as master does. Master is not consistent here either: a
direct call raises NoMethodError in all four shapes of
[active_undef_shapes.rb](../../bench/upstream/ruby-bugs-2026-11-27/active_undef_shapes.rb), but `send`, `method` and
`respond_to?` ignore the undef when the refined module defines the method itself or when a class is refined. The head
keeps master's result in all 16 cases (4 shapes, 4 lookups). After `remove_method` in an active refinement, `send`,
`method` and `respond_to?` now find the superclass method as a direct call does, where master raised or returned
false; honoring the undef everywhere would be a separate change
for active refinements, so it stays out of this PR.

**Fix probe** ([refine_probe.rb](../../bench/upstream/ruby-bugs-2026-11-27/refine_probe.rb), base and head outputs in
the same directory): 30 shapes (method in superclass, in a later module, in the class itself, behind a prepend, or
absent; refinement of an included module, of the class, of a prepended module; used in an eval scope or unused) times
10 lookups (`public_send` from `instance_eval`, send, public_send, method, Method#call, respond_to? with and without
private methods, instance_method, method_defined?, `&:sym`; real direct calls are covered by the repros and the
reviewers' probes), plus
refinements of Kernel and Comparable and alias/undef. All 349 lines are identical between base and head except the
unused-module-refinement rows that raised or returned false on base and now find the method, and the alias and undef
rows, which raised NameError and now succeed; active dispatch and refined-class rows in this probe are unchanged; `method_defined?` also becomes true in five
active-module rows. A script
with `method_defined?`, `public_method_defined?`, `private_method_defined?`, `alias_method` on the inherited method,
`undef_method`, and the same calls on a method nobody defines prints the same lines on the head with the unused
refinement as on master without it ([alias_undef_probe.rb](../../bench/upstream/ruby-bugs-2026-11-27/alias_undef_probe.rb)).

**Tests on the head** (build with `--enable-yjit --enable-zjit`; run on `07c745a4ab`, the same tree with an earlier
commit message):

* `test_unused_refinement_for_module_method_in_superclass` fails on master (`NoMethodError: undefined method 'foo' for
  an instance of D`) and with only the `resolve_refined_method` change (`Expected D.method_defined?(:foo) to return
  true`). `test_undef_in_active_refinement_for_module_method_in_superclass` passes on master and fails on `d852ad111c`
  (`NoMethodError expected but nothing was raised`). Both pass on the head.
* `make test-all TESTS=ruby -j8`: 11763 tests, 1 failure; with `RUN_OPTS=--zjit-call-threshold=1`: 11763 tests,
  1 failure. Both are `TestThread#test_handle_interrupt_masks_sigint`, which fails the same way on unmodified master
  in this orb.
* `test_refinement.rb test_method.rb test_module.rb test_object.rb test_alias.rb test_yjit.rb` with
  `--yjit-call-threshold=1`: 754 tests, 0 failures.
* `make btest`: PASS all 2148; with `--zjit-call-threshold=2`: PASS all 2148.
* ruby/spec core/refinement, module, main/using, kernel, basicobject: 3577 examples, 0 failures; core/refinement,
  module, kernel, basicobject with `-T --zjit-call-threshold=2 --repeat 2`: 7134 examples, 0 failures.
* Not run: `make zjit-check` (the Rust unit tests); the change touches no ZJIT code.

**Existing reports:** none for this. Searched bugs.ruby-lang.org (open issues titled "refinement", unused refinement
lookups) and GitHub ruby/ruby PRs (`resolve_refined_method`, `unused refinement`, `refinement send superclass`).
Closest: [Bug #14068](https://bugs.ruby-lang.org/issues/14068) (fixed the direct-call path in 2017),
[Bug #14232](https://bugs.ruby-lang.org/issues/14232) (super from a refined module, fixed),
[Bug #22614](https://bugs.ruby-lang.org/issues/22614) (unused refinements and `bind_call`, fixed 2026-11-21 by
2c15e9fe33, b870c03951, 380fa6ff3f; these touch `UnboundMethod#bind`, not this lookup),
[Bug #22071](https://bugs.ruby-lang.org/issues/22071) (super in a refined module method). Not fixed on master
`0d399335b7` (master tip at 2026-11-27 evening).

## Separate findings, not in this PR

* **`[BUG]` crash with an undef in an active module refinement:**
  [active_undef_send_crash.rb](../../bench/upstream/ruby-bugs-2026-11-27/active_undef_send_crash.rb) (a module that
  defines `foo`, an active refinement that undefs it, one direct call, then `send(:foo)`) aborts with
  `[BUG] vm_call_method: unsupported method type (7)` on 3.4.13, 4.0.10, master `0d399335b7` and this head. Not
  investigated further; a new lead, not reported.
* **Undef in an active refinement is ignored by `send`, `method` and `respond_to?`** in three of the four shapes
  above, while a direct call honors it. Unchanged by this PR; not reported.
