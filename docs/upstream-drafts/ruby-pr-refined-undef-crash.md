# Draft: `send` aborts after an active refinement undefines a module method

Status, 2026-11-27: **draft, nothing opened.** Path: **PR** (DECISIONS, A clear PR before a ticket). A `[BUG]` abort
and a result that depends on call order are wrong whatever `send` should return; with this fix `send` matches the
direct call for module methods. Whether `send` and reflection should honor such an undef in general is RUD1's question
([ruby-bug-active-refinement-undef.md](ruby-bug-active-refinement-undef.md)). The fix is three lines, one concern and
verified. No existing report or fix was found (bugs.ruby-lang.org search for "unsupported method type",
"undef_method" refine, "undef" refinement send; GitHub issues and PRs in ruby/ruby; master has no newer change to
vm_method.c, vm_insnhelper.c or vm_eval.c than 0d399335b7).

Fix head: [`6bd87c87b9`](https://github.com/thomasklemm/ruby/commit/6bd87c87b9) on
`thomasklemm/ruby:fix-refined-undef-defined-class`, one commit on ruby/ruby master `0d399335b7`. Same tree as the
reviewed `c79eac2cd3`; only the commit message changed after review. Raw data:
[bench/upstream/ruby-bugs-2026-11-27](../../bench/upstream/ruby-bugs-2026-11-27/) (`active_undef_*`,
`active_refinement_honor.*`, `6bd87c87b9.patch`, `tail-*-c79eac2cd3.txt`).

**Order relative to ruby/ruby#20267 (URF1):** both change the same block of `resolve_refined_method`, and the ruby/ruby
pace rule allows the next PR only after a maintainer responds to #20267. Open RUC1 once a maintainer has responded
there, not necessarily after it merges: on master if #20267 is still open, or rebased with the verified resolution
(`combined-URF1-plus-crash-fix-vm_method.diff`) if it has merged. A rebased head needs its own review. Optional: post
RUD1 first, so the body's last sentence can end "; see [Bug #N]".

The body keeps the versions sentence: DECISIONS "A clear PR before a ticket" (2026-11-27) has a PR that replaces a
ticket carry the versions tested, as the open #20267 body does; the older PR-description rule against listing Rubies
predates it.

## Pull request

**Title:** Keep defined_class when an active refinement undefines a module method

**Body:**

An active refinement that undefines a method of an included module makes `send` abort after a direct call:

```ruby
module M; def foo = :m; end
class C; include M; end
using Module.new { refine(M) { undef_method :foo } }
p((C.new.foo rescue $!.class)) # NoMethodError
p C.new.send(:foo)             # [BUG] vm_call_method: unsupported method type (7)
```

With `send` called first, both calls return `:m` instead. This happens on 3.4.13, 4.0.10 and master, in the
interpreter and with YJIT, and with ZJIT on 4.0.10 and master.

`resolve_refined_method` searched the refinement with the caller's `defined_class` pointer, so a search that stopped
at the undef left the refinement's iclass there. Completing the module's method in that iclass then returned the undef
entry the direct call had cached there; with `send` first, the module's method was cached there instead. This sets
`defined_class` only when the refinement's method is returned, so `send` raises NoMethodError in either order, like
the direct call.

`public_send`, `method` and `respond_to?` still find the module's method, now in either order; after a direct call,
`public_send` and `method` used to find the undef entry. For a method of a class, `send` still finds the original
method.

## Commit message

```
Keep defined_class when an active refinement undefines a module method

resolve_refined_method searched the refinement with the caller's
defined_class pointer, so a search that stopped at an undef in the
refinement left the refinement's iclass there even though its result
was discarded. Completing the original method of a module then reused
the undef entry already cached in that iclass by a direct call.
Kernel#send after such a direct call got the undef entry and aborted
with "[BUG] vm_call_method: unsupported method type (7)"; with send
first, the original method was cached there instead and a later
direct call ignored the undef. Kernel#public_send and Kernel#method
after a direct call got the same undef entry.

Write the class found in the refinement only when its entry is
returned.
```

## Evidence (record only, not for the body)

* Repros: `active_undef_send_crash.rb` (direct call, then send) and `active_undef_send_crash_reverse.rb` (send first),
  runs in `active_undef_runs.txt`. Master 0d399335b7, 4.0.10 and 3.4.13 abort with the `[BUG]` in the interpreter and
  with `--yjit`, master and 4.0.10 also with `--zjit` (3.4.13 has no ZJIT). Reverse order prints `:m :m` everywhere.
* Cause verified with temporary debug prints on master (the iclass written by the discarded search) and by applying
  the same change to v4.0.10 (`crash-fix-on-v4_0_10.diff`): the crash and the order dependence go away there too under
  all three engines. In the crash order `prepare_callable_method_entry` returns the undef entry already in the
  iclass's callable table; in the reverse order the empty table receives the original method.
* `active_refinement_honor.rb` (`active_refinement_honor.txt`) confirms that refinements which define the method are
  unchanged. On the fixed head, an undef of an included module method makes direct calls and `send` raise
  NoMethodError, while `public_send`, `method`, `respond_to?` and `&:foo` still find the original method. Reflection
  results on master depend on prior calls: `active_undef_order_reflection.rb` (direct call, then public_send,
  method.call, respond_to?) prints `NoMethodError NoMethodError NameError true` on master and
  `NoMethodError :m :m true` on the head (`active_undef_order_reflection.txt`).
* Reviewer matrices (outside this repo): every head-versus-master difference is an undef in an active refinement of a
  module method; master's results there depend on call order (and with send first, a `super` in the module method ran
  it twice). Class shapes, defining, unused and removed refinements are unchanged. Interpreter, YJIT and ZJIT agree
  within each build.
* Test `test_undef_in_active_module_refinement_with_send` (two classes, both call orders) fails on master with the
  `[BUG]` and passes on the head.
* Suites on c79eac2cd3 (same tree as 6bd87c87b9): test-all `ruby` 11762 tests, interpreter and
  `--zjit-call-threshold=1`, 1 failure each, `TestThread#test_handle_interrupt_masks_sigint`, which also fails on
  unmodified master in this orb, so these runs are not green; targeted YJIT (`--yjit-call-threshold=1`) rc=0; btest
  2148/2148 with and without ZJIT. ruby/spec: core refinement, module, main/using_spec.rb, kernel and basicobject
  3577/0 in the interpreter; the ZJIT run (`-T --zjit-call-threshold=2 --repeat 2`) used the same selection without
  main/using_spec.rb, 3567 examples twice, 7134/0.
