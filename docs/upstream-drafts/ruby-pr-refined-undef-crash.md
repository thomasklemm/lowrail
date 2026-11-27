# Draft: `send` aborts after an active refinement undefines a module method

Status, 2026-11-27: **draft, nothing opened.** Path: **PR** (DECISIONS, A clear PR before a ticket). The expected
behaviour is settled: an undef in an active refinement makes the call raise NoMethodError since
[Bug #10578](https://bugs.ruby-lang.org/issues/10578), and `send` follows active refinements since
[Feature #11476](https://bugs.ruby-lang.org/issues/11476). The fix is three lines, one concern, verified, and
removes a `[BUG]` abort. No existing report or fix was found (bugs.ruby-lang.org search for "unsupported method
type", "undef_method" refine, "undef" refinement send; GitHub issues and PRs in ruby/ruby; master has no newer change
to vm_method.c, vm_insnhelper.c or vm_eval.c than 0d399335b7).

Fix head: [`c79eac2cd3`](https://github.com/thomasklemm/ruby/commit/c79eac2cd3) on
`thomasklemm/ruby:fix-refined-undef-defined-class`, one commit on ruby/ruby master `0d399335b7`. Raw data:
[bench/upstream/ruby-bugs-2026-11-27](../../bench/upstream/ruby-bugs-2026-11-27/) (`active_undef_*`,
`active_refinement_honor.*`, `c79eac2cd3.patch`, `tail-*-c79eac2cd3.txt`).

**Relation to the open unused-module-refinement PR (ruby/ruby#20267):** both change the same block of
`resolve_refined_method`, so whichever merges second conflicts. The verified resolution (that PR's undef branch, plus
publishing the refinement's class only on return; test_refinement 201 tests, 0 failures) is
`combined-URF1-plus-crash-fix-vm_method.diff`. Recommended: open after #20267 merges, rebased onto master with that
resolution, so the body needs no stacking line. If Thomas wants it sooner, open on master now; it is a separate bug and
concern, and the cause predates #20267 (present in 3.4.13).

Not combined with the reflection inconsistency (ruby-bug-active-refinement-undef.md): that is a maintainer question
about intended behaviour, this is a crash with settled behaviour.

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

This happens on 3.4.13, 4.0.10 and master, in the interpreter and with YJIT, and with ZJIT on 4.0.10 and master. With `send` called first, both
calls return `:m` instead. Both should raise NoMethodError, as an undef in a refinement does since
[Bug #10578](https://bugs.ruby-lang.org/issues/10578).

`resolve_refined_method` searched the refinement with the caller's `defined_class` pointer, so a search that stopped
at the undef still left the refinement's iclass there. The module's original method was then cached in that iclass,
under the same name as the undef entry the direct call had cached. This sets `defined_class` only when the
refinement's method is returned. `public_send`, `method` and `respond_to?` still ignore such an undef, before and
after this change.

## Commit message

```
Keep defined_class when an active refinement undefines the method

resolve_refined_method searched the refinement with the caller's
defined_class pointer, so a search that stopped at an undef in the
refinement left the refinement's iclass there even though its result
was discarded. The original method of a module, which has no
defined_class of its own, was then completed in that iclass's
callable method table, where a direct call had already cached the
undef entry under the same name. Kernel#send after such a direct call
got the undef entry and aborted with
"[BUG] vm_call_method: unsupported method type (7)"; with send first,
the original method was cached there instead and a later direct call
ignored the undef.

Write the class found in the refinement only when its entry is
returned.
```

## Evidence (record only, not for the body)

* Repros: `active_undef_send_crash.rb` (direct call, then send) and `active_undef_send_crash_reverse.rb` (send first),
  runs in `active_undef_runs.txt`. Master 0d399335b7, 4.0.10 and 3.4.13 abort with the `[BUG]` in the interpreter and
  with `--yjit`, master and 4.0.10 also with `--zjit` (3.4.13 has no ZJIT). Reverse order prints `:m :m` everywhere.
* Cause verified with temporary debug prints on master (the iclass written by the discarded search) and by applying
  the same change to v4.0.10 (`crash-fix-on-v4_0_10.diff`): the crash and the order dependence go away there too under
  all three engines.
* `active_refinement_honor.rb` matrix (`active_refinement_honor.txt`): on c79eac2cd3 the only change against master is
  the module shape with an undef: `send` now raises NoMethodError like the direct call; `public_send`, `method`,
  `respond_to?` and `&:foo` still find `:m`, as on master. Every shape where the refinement defines the method is
  unchanged.
* Test `test_undef_in_active_module_refinement_with_send` (two classes, both call orders) fails on master with the
  `[BUG]` and passes on the head.
* Suites on c79eac2cd3: test-all `ruby` 11762 tests, interpreter and `--zjit-call-threshold=1`, 1 failure each,
  `TestThread#test_handle_interrupt_masks_sigint`, which also fails on unmodified master in this orb; targeted YJIT
  (`--yjit-call-threshold=1`) rc=0; btest 2148/2148 with and without ZJIT; ruby/spec refinement, module, main/using,
  kernel and basicobject 3577/0, ZJIT repeat 7134/0.
