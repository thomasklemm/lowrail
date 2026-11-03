# Bet R6: census 6's two largest Rails leads

Pin: census 6's 3bdc579090 (A/A labels `c6`/`c62`, 23 configurations). rails/rails main b10c3acfe9 has the same
`scoping/named.rb` and `relation/delegation.rb`, so the candidate applies to main unchanged.

## Lead 1: generated relation delegators (`delegation.rb:81`)

**The census 6 explanation was wrong.** Forwarding `...` from inside a block allocates nothing on Ruby 4.0.7
(interpreter and YJIT; `getlocal "..."` + `sendforward`). The Array and Hash attributed to `delegation.rb:81` are the
**callee's** parameters: `scope` defines every scope method as `proc do |*args, **kwargs|` (since #58238 replaced
`ruby2_keywords`), and a method with named `*args, **kwargs` allocates an empty Array and Hash per call, with or
without arguments (micro: `def m(*args, **kwargs)` and the `define_method` equivalent, 2.0 objects/call; `*args` or
`**kwargs` alone, 1.0). The allocation shows at the caller's line, as R2-4's `capture` Array did.

**VM side: no lead.** Ruby already elides anonymous `*, **` (Feature #20066); named rest/kwrest are readable locals,
so eliding them needs escape analysis, and block parameters cannot be anonymous-forwarded (`proc { |*| m(*) }` is a
SyntaxError). Nothing to file.

**Candidate R6-1** `thomasklemm/scope-zero-arity-no-splat` @ `abd19e812b0ac5bedce2fc8cc0899a234c1e63dc`
(thomasklemm/rails, on 3bdc579090): when the scope body is a lambda with arity 0, define the scope method without
parameters. Such a lambda raises `ArgumentError` for any argument, so callers see the same error and message;
procs, lambdas with parameters and other callables keep the generic method. `Relation#scoping` and the delegator are
untouched, so overrides keep working.

Observable differences: `Model.method(:scope).arity`/`parameters` become `0`/`[]` instead of `-1`/`[[:rest, :args],
[:keyrest, :kwargs]]`, and the ArgumentError's backtrace starts at the scope method instead of inside the lambda.

Per call ([micro_scope.rb](../../bench/upstream/r6/micro_scope.rb), objects):

| call | interp base → head | YJIT base → head |
|---|---|---|
| `Post.published` (`-> { where(...) }`) | 19 → 17 | 21 → 19 |
| `relation.published` (generated delegator) | 20 → 18 | 21 → 19 |
| `Post.recent` (with extension block) | 43 → 41 | 44 → 42 |
| `Post.min_n(1)` (lambda with a parameter) | 16 → 16 | 18 → 18 |
| `Post.plain_proc` (proc body) | 19 → 19 | 21 → 21 |

Controls (same output on base and head): the SQL of each scope, the extension method, `plain_proc(9)` accepting
extra arguments, and `ArgumentError: wrong number of arguments (given 1, expected 0)` for `published(1)`,
`published(a: 1)`, `rel.published(1)` and `recent(2)`.

Census (`r6s` vs `c62`, A/A `c6`, all 23 configurations, interpreter and YJIT):

* `delegation.rb:81` Array+Hash, summed per op over the 21 configurations that reach it: 4429 → 304 (A/A 4428.6
  interpreter, 4429.0 YJIT). The remaining 304 are scopes with parameters or proc bodies (not attributed further).
* Workloads reaching line 81: 167; median total delta −13.0/op interpreter (−0.16%), −12.0 YJIT (−0.15%), A/A median
  0.0; 150 / 151 moved by ≤ −1. Apps with a moved workload: 20 interpreter, 19 YJIT (of 21 reached).
* Corpus-wide medians are +0.0 in both modes (most workloads don't call scopes); 13 / 7 SQL digests changed, the
  usual database-state drift.

Suites (RAILS_STRICT_WARNINGS=1, SEED=41231): AR `test:sqlite3` 10248 runs, 0 failures, 0 errors, 52 skips, no
warnings; AR `test:postgresql` 11167 runs, 0 failures, 0 errors, 31 skips. RuboCop: no offenses. The new test
`test_scope_arguments_follow_the_scope_body` passes on base and head and fails on a mutant that drops the `lambda?`
check (a proc body would then reject arguments).

Overlap: `gh search prs` on rails/rails (open) for "scope kwargs", "named scope allocation", "scope_method proc",
"_exec_scope", "scope arity": nothing on this code. Origin of the signature: #58238 (kamipo, `ruby2_keywords`
removal) and #57927 (Ractor-shareable scope methods).

Draft (short form):

> `scope :published, -> { where(published: true) }` defines `published` as a method taking `*args, **kwargs`, so
> every call allocates an empty Array and an empty Hash, also when reached through a relation
> (`author.posts.published`) via the generated delegator. Most scopes are lambdas without parameters.
>
> A lambda without parameters raises `ArgumentError` for any argument, so for such bodies the scope method now takes
> none: callers get the same error and message, while procs, lambdas with parameters and other callables keep the
> generic method.
>
> | call | objects before | after |
> |---|---|---|
> | `Post.published` | 19 | 17 |
> | `Post.where(n: 1).published` | 20 | 18 |
> | `Post.min_n(1)` (lambda with a parameter) | 16 | 16 |
>
> Across 20 of the 21 census configurations that call such scopes, the median workload allocates 13 fewer objects
> per request.

## Lead 2: `has_default_scope?` / `build_default_scope` (`method(:default_scope).owner`)

Checked, nothing to add beyond A1's [activerecord-cpu.md](activerecord-cpu.md): #59234 (kamipo, merged 2026-10-21)
made `method(:default_scope).owner` the single spelling, to fix private `self.default_scope` overrides that
`respond_to?` missed. Ruby has no allocation-free way to ask a resolved method's owner, and a per-class cache needs
`singleton_method_added` plus hooks for modules extended later (`extend` after `default_scope`, `prepend` on the
singleton class, `define_singleton_method`, `remove_method`, reloading), which is not exact. Caller counts for the
record (Lobsters probe): 161 `has_default_scope?` calls over 11 workloads, 105 from `named.rb:77`
`default_extensions`; `build_default_scope` 214 calls on Lobsters and 862 on Sure. Not built; A1's C2 touches
association scopes, so nothing was built there either.
