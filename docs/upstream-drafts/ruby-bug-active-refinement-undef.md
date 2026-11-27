# Draft: undef in an active refinement is honored by direct calls only

Status, 2026-11-27: **draft, nothing posted.** Path: **Redmine ticket** (DECISIONS, A clear PR before a ticket).
Which behaviour is intended is a question for the maintainers: no doc or test settles how `send`, `method` and
`respond_to?` should treat an undef in an active refinement, and making them honor it changes reflection results
(`respond_to?`, `method`) and touches `resolve_refined_method`, which the method-defined, alias and undef lookups share.
There is no fix yet. Thomas posts the ticket (or approves posting).

No existing report found (bugs.ruby-lang.org search for "undef_method" refine, "undef" refinement send, refinement
respond_to? undef; GitHub issues and PRs in ruby/ruby). Related, closed: Bug #10578 (undef in refinements, direct calls
only), Feature #11476, #15326, #15327 and #15373 (send, public_send, respond_to? and method follow refinements; none of
them discusses undef).

The crash in the module shape (`send` after a direct call aborts with `[BUG]`) is a separate PR draft:
[ruby-pr-refined-undef-crash.md](ruby-pr-refined-undef-crash.md). Raw data:
[bench/upstream/ruby-bugs-2026-11-27](../../bench/upstream/ruby-bugs-2026-11-27/) (`active_undef_reflection.*`,
`active_refinement_honor.*`).

## Redmine report

**Title:** undef_method in an active refinement is ignored by send, method and respond_to?

**ruby -v:** ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux]

**Description:**

`undef_method` in an active refinement makes a direct call raise NoMethodError, since
[Bug #10578](https://bugs.ruby-lang.org/issues/10578). `send`, `public_send`, `method`, `respond_to?` and `&:foo`
ignore it and find the original method:

```ruby
class C; def foo = :c; end
using Module.new { refine(C) { undef_method :foo } }
c = C.new
p((c.foo rescue $!.class))
p((c.send(:foo) rescue $!.class))
p((c.method(:foo).call rescue $!.class))
p c.respond_to?(:foo)
```

Actual:

```
NoMethodError
:c
:c
true
```

When the refinement defines `foo` instead, all of these return the refined method
([Feature #11476](https://bugs.ruby-lang.org/issues/11476), [Feature #15326](https://bugs.ruby-lang.org/issues/15326),
[Feature #15327](https://bugs.ruby-lang.org/issues/15327), [Feature #15373](https://bugs.ruby-lang.org/issues/15373)).
If they should follow an undef the same way, the expected output is:

```
NoMethodError
NoMethodError
NameError
false
```

doc/syntax/refinements.rdoc does not mention undef, so I am not sure which behaviour is intended.

The direct call uses `search_refined_method` in vm_insnhelper.c, which stops when the refinement's lookup hits the
undef. The other lookups go through `resolve_refined_method` in vm_method.c, where `search_method_protect` turns the
undef into "not found" and the search falls back to the original method.

Same result on 3.4.13, 4.0.10 and master, in the interpreter and with `--yjit`, and with `--zjit` on 4.0.10 and master.

## Evidence (record only, not for the report)

* `active_undef_reflection_runs.txt`: the repro on 3.4.13 (interpreter, YJIT; no ZJIT in that build), 4.0.10 and
  master 0d399335b7 (interpreter, YJIT, ZJIT) and on the crash-fix head c79eac2cd3: `NoMethodError :c :c true`
  everywhere.
* `active_refinement_honor.txt`: a refinement that defines `foo` is followed by call, send, public_send, method,
  respond_to? and `&:foo` in the class, module and inherited shapes; an undef is followed only by the direct call
  (and, with the crash fix, by send in the module shape).
* gdb on master: send, public_send, method, respond_to? and `&:foo` all reach `resolve_refined_method` (the first four
  through `callable_method_entry_refinements0`, `&:foo` through `rb_resolve_refined_method_callable`).
  `search_method_protect` returns NULL for an undef entry; `search_refined_method` returns NULL when
  `rb_callable_method_entry(refinement, mid)` is NULL, which ends in method_missing.
