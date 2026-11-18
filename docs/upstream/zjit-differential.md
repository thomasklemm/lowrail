# ZJIT differential run on master 90dbced795 (bet Z2)

The [2026-11-18 rerun on `7919a47d46`](#rerun-on-master-7919a47d46-2026-11-18) is at the end.

Bet Z2 reran the [JIT differential run](contributions.md) (which found
[#19648](https://github.com/ruby/ruby/pull/19648) on `e83592ba14`) for ZJIT only, on ruby/ruby master
[`90dbced795`](https://github.com/ruby/ruby/commit/90dbced795), the tip on 2026-11-03.

**Result: no new ZJIT divergence.** The run executed 351 suite runs with 620,279 test executions over 16
suites and 13 ZJIT modes. Every per-test difference from the interpreter is one of these:

- the known Shopify/ruby#976, still open; its fix, ruby/ruby#18960, is also still open;
- a timing flake that passes when rerun alone;
- a crash that also happens without the JIT.

There is no candidate fix branch.

## Scope: what changed since the last run

Only 11 commits landed between `e83592ba14` and `90dbced795`. Four touch ZJIT:

- `13c3f56bb8`: Proc block arguments for `&block` callees ([GH-19484](https://github.com/ruby/ruby/pull/19484), ours)
- `b51db981f6`: bitstream encoding for stack-map unwind code (GH-19570)
- `15314737dd` and `36ba2601b1`: clippy `useless_conversion` cleanups

`2bc6f9a60e` rewrote `Array#each_index` in Ruby, which the JIT now compiles. #19538 (`461085c2c7`) was already
in `e83592ba14`. To compensate for the small delta, this run adds four ZJIT modes the earlier run did not use,
and runs targeted probes of `13c3f56` and `2bc6f9a6`.

## Pins and method

- **Ruby:** `90dbced795`, a release build (`--enable-zjit --enable-yjit`) and a debug build
  (`--enable-zjit=dev --enable-yjit=dev optflags=-O1`). Rust 1.99.1.
- **Corpus:** the same as the previous run.
  - Rails main [`36e0f96b9d`](https://github.com/rails/rails/commit/36e0f96b9d): Active Record (SQLite in memory),
    Active Support, Action Pack, Action View, Active Model, Active Job and Action Mailer.
  - Rails 8.1.4: Action Cable, Action Mailbox and Action Text.
  - App suites:
    - Campfire on Rails 8.1 (`02023b0`) and 8.2 (`af4dd9f`)
    - Fizzy on Rails 8.1 (`6f1d200`) and 8.2 (`77eada1`)
    - Writebook on Rails 8.1 (`be1f8fc`) and 8.2 (`7478e2c`)
- **Harness:** [bench/upstream/jit-differential](../../bench/upstream/jit-differential), the scripts of the
  previous run, now committed.
  - `outcomes.rb` records each test's result through a Minitest reporter. `compare.rb` diffs each mode
    against `interp-0` and marks tests whose result already differs between `interp-0` and `interp-1`.
  - Settings: seed 41231, `PARALLEL_WORKERS=1`, and five suites running concurrently on 8 cores.
  - The queue is [`queue-z2.txt`](../../bench/upstream/jit-differential/queue-z2.txt).
- **Modes** (`run.sh`):

| Mode | Options | New this run |
| --- | --- | --- |
| `interp` (×2), `ic` | none; `ic` adds `GC.auto_compact = true` | |
| `z1` | `--zjit --zjit-call-threshold=1` | |
| `z1ni` | `z1` + `--zjit-inline-threshold=0` | |
| `zinl` | `z1` + `--zjit-inline-threshold=500` | |
| `zinb` | `zinl` + `--zjit-inline-budget=2000` | yes |
| `zmem` | `z1` + `--zjit-mem-size=4` | |
| `zcm` | `zmem` + auto-compaction | yes |
| `zinv` | threshold 2, one profile, `--zjit-num-exits-until-invalidate=1` | |
| `zc` | threshold 3, two profiles, auto-compaction | |
| `z2i` | threshold 3, two profiles, `--zjit-inline-threshold=200` | |
| `z3` | threshold 3, two profiles | |
| `z30` | `--zjit` (defaults) | |
| `zdh` | `z1` + `--zjit-disable-hir-opt` | yes |
| `zmv` | threshold 2, one profile, `--zjit-max-versions=1` | yes |

  Some details:
  - The release build ran every mode.
  - The debug build ran `interp`, `z1`, `z1ni`, `zinl`, `zmem` and `zc`.
  - `zinb` started with `--zjit-inline-budget=0` (unlimited). That made Active Record and some app suites run
    for many minutes without finishing, so I changed the budget to 2000 for the remaining runs. That is a
    compile-time cost of a setting that removes the inlining limit by design, not a correctness issue. Some
    app `zinb` runs had already finished with the unlimited budget.
- **Extra coverage:**
  - Ruby's own `test/ruby` (11,509 tests) under `zinb` with unlimited budget, and under `zmv` with
    `--zjit-mem-size=8`. Neither mode is in ruby/ruby CI.
  - Targeted probes, run under the interpreter, five ZJIT modes and the debug build:
    - [`probe_proc_block_arg.rb`](../../bench/upstream/jit-differential/probe_proc_block_arg.rb)
      exercises `13c3f56` with Proc, lambda, Symbol, Method, `to_proc` and nil block arguments to `&b`
      callees with optional, rest and keyword parameters, reassignment, `block_given?` and polymorphic call sites.
    - [`probe_each_index.rb`](../../bench/upstream/jit-differential/probe_each_index.rb) exercises the Ruby
      `Array#each_index`: mutation during iteration, `break`/`next`/`redo`, enumerators, subclasses, frozen arrays.

## Coverage

| Suite | Tests | Release modes | Debug modes |
| --- | ---: | ---: | ---: |
| activerecord (main) | 9,860 | 15 | 6 |
| activesupport (main) | 6,794 | 15 | 6 |
| actionpack (main) | 4,563 | 15 | 6 |
| actionview (main) | 2,898 | 15 | 6 |
| activemodel (main) | 1,237 | 15 | 6 |
| actionmailer (main) | 286 | 15 | 6 |
| activejob (main) | 234 | 15 | 6 |
| actioncable (8.1.4) | 231 | 15 | 6 |
| actiontext (8.1.4) | 126 | 15 | 6 |
| actionmailbox (8.1.4) | 106 | 15 | 6 |
| Fizzy r82 | 1,787 | 15 | 6 |
| Campfire r82 | 634 | 15 | 6 |
| Writebook r82 | 310 | 15 | 6 |
| Campfire r81 | 234 | 15 | 6 |
| Fizzy r81 | 124 | 14 (`zcm` aborted, see below) | 6 |
| Writebook r81 | 119 | 15 | 6 |

The release modes are `interp-0`, `ic` and the 13 ZJIT modes. The second interpreter run `interp-1` adds
16 more runs. One run has no outcomes: Fizzy r81 under `zcm` aborted in redcarpet, explained below.

## Differences from the interpreter

| Where | Modes | Test | Verdict |
| --- | --- | --- | --- |
| activesupport (main) | `z1`, `z1ni`, `zinl`, release and debug | `ObjectTryTest#test_try_only_block_nil` | **Known, still on master.** Shopify/ruby#976 (stale local after inlining a send-ish instruction). Repro below; ruby/ruby#18960 (open) fixes it. Not resubmitted. |
| Campfire r82 | `z2i`, `zinb`; debug `z1`, `zinl`, `zc` | `SqliteWalCheckpointTest` (2 tests), "condition not met within 1s" | **Timing flake.** A 1-second wait on another process under parallel load. The file passes 3/3 under the interpreter and 3/3 under `z2i` when run alone. |
| activemodel (main) | `zc`, once | 5 `RailtieTest` isolation subprocesses: SIGSEGV | **JIT-independent crash, not reproduced.** See below. |
| Fizzy r81 | `zcm` (2 of 3 runs), **`ic` (1 of 2)** | whole run aborts | **Not ZJIT:** it also happens under the interpreter with auto-compaction. See below. |

Two `[BUG]` reports appear in every mode, the interpreter included. They also appeared in the previous run's
`rel-main` logs, so they are pre-existing and not JIT-related:

- `rb_objspace_reachable_objects_from_local: set is owned by another Ractor`, in subprocesses of the Action View
  and Action Pack Ractor tests (`render_test.rb:1216` via `ractors_assertions.rb`). The suite still reports
  the tests as passing.
- The same message from `active_job/arguments.rb:184`.

`test/ruby` under `zinb` and `zmv` had two errors, `TestIO#test_seek` and `TestIO#test_seek_symwhence`
(`Errno::ENOENT` from `IO#seek`). They fail the same way under the interpreter in this orb, so they are an
environment issue. The probes matched the interpreter in every mode, and the debug build raised no assertions.

### Known: Shopify/ruby#976

```ruby
class NilClass
  def try(*, &) = nil
end
def t
  ran = false
  nil.try { ran = true }
  ran
end
p t, t, t
```

The interpreter prints `false` three times; `--zjit --zjit-call-threshold=1` on `90dbced795` prints `nil` three
times. A build of ruby/ruby#18960 prints `false`.

### Active Model `zc`: SIGSEGV in a forked child closing a `Ractor::Port`

The crash happened in one `zc` run. Five `RailtieTest` isolation subprocesses died in the `_fork` hook of the
ractor-dispatch gem (`Ractor::Dispatch.reset_main!` → `Executor#shutdown` → `Ractor::Port#close`). The C stack
is `ractor_port_close` → `ractor_close_port` → `ractor_wakeup_all` → `rb_ractor_sched_wakeup` →
`thread_sched_lock_`, a segfault at `0x158`. No JIT frames are involved.

A plausible mechanism, which I did not confirm: the executor thread waits in `Port#receive` with a stack-allocated
`ractor_waiter` on the main Ractor's `sync.waiters`. `rb_thread_atfork` does not clear the main Ractor's
waiters; `ractor_sync_terminate_atfork` only runs for non-main Ractors. So the forked child may wake a thread
that no longer exists.

It did not reproduce in 7 more full-suite runs under `zc` or 6 under `ic`. It also did not reproduce in
[`probe_ractor_port_fork.rb`](../../bench/upstream/jit-differential/probe_ractor_port_fork.rb) or variants with
GC, compaction and memory reuse in the child, on the release build, the debug build or 4.0.7. Not reported.
It belongs to the Ractor and fork code, not to ZJIT.

### Fizzy: redcarpet assertion under auto-compaction

`markdown.c:2928: sd_markdown_render: Assertion 'md->work_bufs[BUFFER_BLOCK].size == 0' failed`, raised from
`Redcarpet::Markdown#render` (Fizzy `lib/rails_ext/action_text_markdown.rb:24`). It also happened under `ic`,
the interpreter with auto-compaction. That makes it a redcarpet 3.6.1 or compaction issue, not ZJIT. Not
investigated further.

## Watch on #19660–#19663

The hourly watch continued during this run. See [contributions.md](contributions.md) for the PRs.

## Not run

- The nine census apps. They are not set up in this orb and need MySQL, PostgreSQL, Redis and memcached.
- Active Storage, which needs service credentials, and Railties, as in the previous run.
- YJIT modes, by request.

## Rerun on master 7919a47d46 (2026-11-18)

Z2's method, repeated on ruby/ruby master [`7919a47d46`](https://github.com/ruby/ruby/commit/7919a47d46), the tip
on 2026-11-18. It covers 562 commits since `90dbced795`, 49 of them in `zjit/`:

- locals in stack maps instead of spills before calls, and side exits that read locals from the stack map;
- an env-escape fix for `GetBlockParam` in an inlined callee;
- polymorphic-class getivar with a monomorphic shape;
- polymorphic `opt_neq` (ours, #19909);
- `gen_new_hash` with String keys;
- folds of `Integer#==`/`Float#==` against `nil`, `true` and `false`;
- `super` from a method that got a block (ours, #19682);
- Integer and Module interpolation without `to_s` (ours, #19678);
- `expandarray` of a profiled `nil`;
- inlined `Integer#pred`, `anybits?` and `IO::Buffer#get_value`;
- the `opt_new` refinement fix for Bug #22539.

Our Symbol block-argument PR ruby/ruby#19912 is still open and not in this build. ruby/ruby#18960 has merged since
Z2, so Shopify/ruby#976 no longer reproduces.

**Result: one real divergence, already known and still open: Shopify/ruby#1128.** `super` in a refined method
calls a second refinement of the same method once the method is compiled. It is wrong at the default `--zjit`.
The first bad commit is `4a21b83693` (ruby/ruby#15816, January 2026). A small fix, mirroring the existing YJIT
check, is on [thomasklemm/ruby `zjit-super-from-refinement`](https://github.com/thomasklemm/ruby/tree/zjit-super-from-refinement)
(`be791c1fb8`); no PR is open. Every other difference from the interpreter is a timing flake, a test name that
contains the date, or an orb environment failure that also happens without the JIT. No `[BUG]` report, Rust panic
or C assertion failure appeared in any run, debug build included. The Ractor-owned-set `[BUG]` that Z2 saw in
every mode did not appear.

### Pins and method

- **Ruby:** `7919a47d46`. A release build (`--enable-zjit --enable-yjit`) and a debug build
  (`--enable-zjit=dev --enable-yjit=dev optflags=-O1`). Rust 1.100.0. Two cores, two runs at a time.
- **Corpus:**
  - Rails main [`36e0f96b9d`](https://github.com/rails/rails/commit/36e0f96b9d), as in Z2: Active Record (SQLite
    in memory), Active Support, Action Pack, Action View, Active Model, Active Job and Action Mailer.
  - Rails 8.1.4: Action Cable, Action Mailbox and Action Text.
  - App suites on Rails 8.2: Campfire `af4dd9f`, Fizzy `77eada1` and Writebook `7478e2c`.
  - Ruby's own suites: btest, test-all, the spec suite and test-bundled-gems.
- **Harness:** [bench/upstream/jit-differential](../../bench/upstream/jit-differential) with Z2's
  `outcomes.rb`/`compare.rb` for the Minitest suites.
  - [`rsuite.sh`](../../bench/upstream/jit-differential/rsuite.sh) runs Ruby's own suites through `make`, and
    [`rcompare.rb`](../../bench/upstream/jit-differential/rcompare.rb) compares them per test from their logs.
  - [`qrun.sh`](../../bench/upstream/jit-differential/qrun.sh) runs two queues.
  - [`runs-2026-11-18.txt`](../../bench/upstream/jit-differential/runs-2026-11-18.txt) lists every run with its
    exit code and time. Where a run is listed twice, the later line counts.
  - Seed 41231, `PARALLEL_WORKERS=1`.
- **Modes:** Z2's 15 release modes (`interp` ×2, `ic` and the 13 ZJIT modes, with `zinb` at
  `--zjit-inline-budget=2000` from the start). The debug build ran `interp`, `z1`, `z1ni`, `zinl`, `zmem` and `zc`.
  `test-all` and `test-bundled-gems` ran on the release build only.
- **Harness lesson:** the spec suite ignores `RUN_OPTS`. mspec runs the build's `miniruby` with its own flags, so
  `make test-spec RUN_OPTS=--zjit` runs the interpreter. ZJIT CI passes the options as `SPECOPTS="-T --zjit …"`.
  `rsuite.sh` does the same, and a probe spec confirmed `RubyVM::ZJIT.enabled?` and `GC.auto_compact` in the
  workers. The first spec wave, which passed `RUN_OPTS`, was discarded and rerun. Unlike ZJIT CI, the spec runs did
  not use `--repeat 2`.
- **Workarounds, the same in every mode:**
  - `BUNDLED WITH` was dropped from the lockfiles, because bundler 2.7.2 fails on `Pathname::SEPARATOR_PAT` and
    master's bundler is 4.1.0.
  - Fizzy's and Writebook's `ruby file: ".ruby-version"` was removed.
  - Writebook got redcarpet 3.6.0 → 3.6.1 (3.6.0 does not compile on master) and `gem "benchmark"` (mini_magick
    4.13 needs it).
  - The Rails main bundle skips the `rubocop`, `mdl`, `doc`, `storage` and `db` groups.
  - The apps run with `TZ=UTC CI=1 CI_PROGRESS_BAR=0`.

### Coverage

| Suite | Tests | Release modes | Debug modes |
| --- | ---: | ---: | ---: |
| test-all (`make test-all`) | 39,155 | 16 | |
| spec (`make test-spec`) | 33,753 examples | 16 | 6 |
| btest | 2,147 | 16 | 6 |
| test-bundled-gems | 35 gems | 6 (`interp` ×2, `z1`, `z1ni`, `zinl`, `z30`) | |
| activerecord (main) | 9,860 | 16 | 6 |
| activesupport (main) | 6,794 | 16 | 6 |
| actionpack (main) | 4,563 | 16 | 6 |
| actionview (main) | 2,898 | 16 | 6 |
| activemodel (main) | 1,237 | 16 | 6 |
| actionmailer (main) | 286 | 16 | 6 |
| activejob (main) | 234 | 16 | 6 |
| actioncable (8.1.4) | 231 | 16 | 6 |
| actiontext (8.1.4) | 126 | 16 | 6 |
| actionmailbox (8.1.4) | 106 | 16 | 6 |
| Fizzy r82 | 1,787 | 16 | 6 |
| Campfire r82 | 634 | 16 | 6 |
| Writebook r82 | 310 | 16 | 6 |

In total there were 346 suite runs with 2,055,623 test executions, plus six test-bundled-gems runs. Every run
produced outcomes. The interpreter baselines have failures that come from the orb, not from Ruby: no `EST` or
`US/Eastern` zone data (most of Active Support's 56), no `sqlite3` CLI, Action Cable's JavaScript package
test, and `TestIO#test_seek`/`test_seek_symwhence` (`ENOENT` in `IO#seek`, as in Z2). They
fail the same way in every mode.

### Differences from the interpreter

| Where | Modes | Test | Verdict |
| --- | --- | --- | --- |
| test-all | `zmv` | `TestRefinement#test_module_inclusion2`: `"FooExt2#y FooExt#y Foo#y"` instead of `"FooExt2#y Foo#y"` | **Real, known: Shopify/ruby#1128.** Run alone, `test_refinement.rb` fails 3 of 3 seeds under `zmv` (as `test_super_not_chained`; which test fails depends on order) and passes 3 of 3 on the interpreter and at the default `--zjit`, because the test calls the method only once. The standalone repro is wrong at the default threshold. See below. |
| Campfire r82 | release `z1`, `z1ni`, `zinl`, `zinb`, `z2i`, `zinv`, `zc`; debug `z1`, `z1ni`, `zinl`, `zmem` | `SqliteWalCheckpointTest` (one or both tests), "condition not met within 1s" | **Timing flake**, as in Z2 and Z11: a 1-second wait on a child process that inherits the JIT options. Same tests, same message, varying from run to run. |
| activejob (main) | `z1ni` | `ArgumentSerializationTest#test_serializes_Range_…Date…` | **Artifact:** the test name contains the Julian day, and the run crossed midnight. `compare.rb` now normalizes it. |
| test-all, spec | one log each | `TestIO#test_seek*`; `Process.clock_gettime … CLOCK_*_ALARM` | **Environment:** they fail on the interpreter too; they only show as differences where a log was read before its summary was written. |

test-bundled-gems passed all 35 gems in every mode. The probes
([`probe_zjit_since_z2.rb`](../../bench/upstream/jit-differential/probe_zjit_since_z2.rb)) cover locals across
side exits, calls, `eval` and blocks; `GetBlockParam` with an escaping env; polymorphic getivar with singleton
classes; polymorphic `!=` with custom `==`/`!=`; String-key hash literals with a mutated key; `expandarray` of
`nil`; the `==` folds; `super` with and without a block; interpolation after redefining `Integer#to_s`;
`Integer#pred`, `anybits?` and `IO::Buffer#get_value` with Bignum, Float and out-of-range inputs;
`String.new(capacity:)`; `opt_new` with a refined `initialize`; and Symbol block arguments. They matched the
interpreter in 7 release modes and 4 debug modes, with no debug assertion.

### Shopify/ruby#1128: `super` in a refined method

```ruby
class Foo
  def y = "Foo#y"
end
module FooExt
  refine(Foo) { def y = "FooExt#y " + super }
end
module FooExt2
  refine(Foo) { def y = "FooExt2#y " + super }
end
module Client
  using FooExt
  using FooExt2
  def self.invoke_y_on(foo) = foo.y
end
foo = Foo.new
puts Array.new(Integer(ARGV[0] || 4)) { Client.invoke_y_on(foo) }.tally
```

On `7919a47d46`, the interpreter returns `"FooExt2#y Foo#y"` for all 100 calls of `ruby refined_super.rb 100`.
`--zjit` returns `"FooExt2#y FooExt#y Foo#y"` for 71 of them, and `--zjit-call-threshold=2` for 99.
`--zjit-call-threshold=1` (no profile yet) and `--zjit-disable-hir-opt` are correct, and so is
`--zjit-inline-threshold=0` at threshold 2, so the cause is in the `invokesuper` specialization, not in inlining.

**Cause.** The specialization in `type_specialize` takes the profiled CME's `defined_class` and looks up
`RCLASS_SUPER(RCLASS_ORIGIN(defined_class))`. For a method reached through `using`, `defined_class` is the
refinement's iclass in the caller's chain of activated refinements (FooExt2 iclass → FooExt iclass → Foo), so the
"superclass" is FooExt's iclass, and the HIR inlines `FooExt#y` as the super target. The interpreter's
`vm_search_normal_superclass` skips refinement iclasses, and YJIT's `gen_invokesuper` already gives up on them
(`invokesuper_refinement`).

**First bad commit:** `4a21b83693` "ZJIT: Optimize common `invokesuper` cases" (ruby/ruby#15816). `miniruby`
built at its parent `cdb2b0eed5` returns the right answer for all 20 calls at threshold 2; at `4a21b83693` it is
wrong for 19 of 20.

**Fix branch:** `be791c1fb8` on `zjit-super-from-refinement`. When the CME's `defined_class` is an iclass of a
refinement, the specialization falls back to the generic `InvokeSuper`, with a new fallback reason
`SuperFromRefinement` (counter `send_fallback_super_from_refinement`). That is +15 lines in `hir.rs` and
`stats.rs`, plus a codegen test with two refinements and a client that uses both. The test fails without the fix
(`"R2 R1 A"`) and passes with it. On a dev build of the branch:

- the repro is correct at the default, threshold 1, threshold 2 and `zmv`;
- `test_refinement.rb` and `test_super.rb` pass under the interpreter, threshold 1, threshold 2 and `zmv`
  (245 tests each);
- `make zjit-test` passes 2,014 of 2,015.

The one failure, `test_profile_frames_during_direct_jit_to_jit_entry` ("rb_profile_frames was not called from
SIGPROF handler"), also fails on master in this orb.

Status: Shopify/ruby#1128 is open, filed by us on 2026-11-15, with no assignee and no PR, so it is free to take.
The fork has no CI for the branch. Nothing has been posted. Under the ruby/ruby moratorium in
[DECISIONS](../DECISIONS.md#pull-requests), it waits for Thomas, after the "Thomas can explain it first" step.

### ZRS1 follow-up review of 7a1eed11f4 (2026-11-18)

**Verdict: nits, no source must-fixes.** Reviewer `thermos-sol`, thread
`T-01a1f051-e70d-74df-8d5a-51990dfd4dbf`. Both Thermos rubrics were loaded and applied directly by this reviewer,
without subagents, other reviewers or threads, as requested. No contact with the parallel Opus reviewer.
The earlier status above is historical: ruby/ruby#19976 is now open and ready, still at
`1d86986033707d121a0a3a514bf15bd6afdfe203`. Nothing was posted or pushed to Ruby in this review.

**Pins and method.** `git ls-remote` verified `thomasklemm/ruby:zjit-super-from-refinement-3` at
`7a1eed11f443881206906acf4efc95ee7f8b7715`. Its parent is canonical master
`7db0202722a286011518bd291f51a15fb652dc02` (`gh api repos/ruby/ruby/commits/7db0202722…` checked).
`git rev-list --count BASE..HEAD` is 1. Thomas is author and committer, with no trailers. The diff adds 89 lines
in seven files: 20 implementation/binding lines and 69 test lines. x86_64 Linux orb, bootstrap Ruby 4.0.7,
Rust 1.100.0, cargo-nextest 0.9.152, libclang 19; `./autogen.sh`,
`./configure --enable-zjit=dev --disable-install-doc`, `make -j2`.
Source and raw logs are under `.amp/in/orb-backup/zrs1-review/` in this review thread.

**Correctness/security.** Cold read: if the profiled method was defined through a refinement iclass, keep the
original `InvokeSuper` and let the VM resolve it at runtime; otherwise use the existing specialization.
`profile_invokesuper` records the live frame CME. `rb_using_refinement` constructs the caller's iclass chain,
and `rb_method_entry_complement_defined_class` supplies the iclass in the CME. The new refusal precedes
`RCLASS_SUPER(RCLASS_ORIGIN(defined_class))` and both ISeq and C-function target lookups. It preserves the
instruction's arguments and FrameState and sets its existing dynamic-send reason field. `InvokeSuper` retains
`effects::Any`; codegen prepares the live frame and calls `rb_vm_invokesuper`. No cached target, new user-object
call, allocation, runtime state or invalidation assumption is introduced by the predicate wrapper. Previously
specialized non-refinement calls retain their existing CME guards and invalidation. Forwarding, blocks and
unsupported argument patterns keep their existing generic boundaries. Class/module lexical-refinement controls
confirm that the fix does not mean that `super` can never call another refinement.

**Maintainability and helper shape.** `internal/class.h:680–686` defines `RICLASS_FOR_REFINEMENT_P` as a
`static inline bool` function, not a macro. It checks `T_ICLASS`, then `T_MODULE`, then the refinement flag.
The six-line `rb_zjit_iclass_for_refinement_p(VALUE iclass)` wrapper sits immediately after
`rb_zjit_singleton_class_p`, before the Ruby primitives section. Its name, return type and placement follow that
existing wrapper; `git log -S rb_zjit_singleton_class_p` and `git show ef95e5ba3d` checked the maintainer precedent.
Bindgen reads `zjit.c` directly, so a new header declaration is unnecessary. The allowlist gains one line beside
the singleton helper, and generated bindings gain one declaration. After installing the missing rustfmt
component, `make -s zjit-bindgen` succeeded and reproduced the checked-in file byte for byte:
SHA-256 `a2767c2ccefa288dcfd6551521bde985a85360e4cb0550c9437f0d9ab9493623` before and after, with an empty
`git diff -- zjit/src/cruby_bindings.inc.rs`. This verifies reproducible generated content, not the author's
historical editing actions. There is no duplicated ZJIT predicate or extra lookup implementation to remove.
No file crosses 1,000 lines; larger files were already above it. The added branch is beside the existing super
refusals and uses their normal instruction/reason pattern. The exhaustive reason/counter mappings are complete.
The one-line guard comment explains the wrong-target hazard; the enum documentation follows its neighbors;
the two warmup comments match the neighboring codegen test and explain the otherwise duplicate calls.

YJIT's `gen_invokesuper_specialized` already performs the same three checks and refuses specialization with
`invokesuper_refinement`; its caller uses VM dispatch. Its inline copy is correct and need not change to fix ZJIT.
Sharing a new cross-JIT API would enlarge this PR without fixing another bug. Leaving it alone is appropriate.

**HIR request and negative control.** The new test is immediately after
`test_invokesuper_to_iseq_optimizes`. The existing test snapshots ordinary `super` specializing to an inlined
parent. The new test profiles two calls through both refinements, obtains `R2`'s actual method ISeq and uses the
normal `hir_string_proc` optimizer/snapshot harness. It snapshots optimized HIR, not separate unoptimized and
optimized dumps. Toggling the guard gives the requested old/new optimizer output and a regression-sensitive test:

- Exact head: generic `InvokeSuper`, reason `super: call from a refined method`.
- Removed only the seven-line guard in `hir.rs`, retaining both tests, helper and reason mappings:
  `make -s zjit-test ZJIT_TESTS=from_refined_method` runs two tests and both fail. Codegen produces `"R2 R1 A"`
  instead of `"R2 A"`. The HIR diff replaces the expected refusal with method-entry guards,
  `PushInlineFrame :foo`, an inner `InvokeSuper` marked polymorphic, and `PopInlineFrame`: it is inlining the
  caller's `R1#foo` into `R2#foo`. This is not an interpreter-only test. Log: `no-guard-tests.log`.

**Executed checks.** Ruby suites used
`make -s test-all TESTS='test/ruby/test_refinement.rb test/ruby/test_super.rb'`
with `TESTOPTS='-q --tty=no --seed=41231'`. Each mode passes 245 tests, 4,139 assertions, no failures, errors or
skips: interpreter; `--zjit --zjit-call-threshold=1`; threshold 2; threshold 2 plus
`--zjit-num-profiles=1 --zjit-max-versions=1` (`zmv`). The zmv run was restarted sequentially after concurrent
make processes briefly raced while relinking miniruby; its completed test run is green, not a suppressed failure.

| Full `make -s zjit-test` | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| Exact candidate | 2,015 | 1 | 15 |
| Unmodified exact parent/master | 2,013 | 1 | 15 |

Both full runs fail only `test_profile_frames_during_direct_jit_to_jit_entry`, at the same zero-samples assertion:
`rb_profile_frames was not called from SIGPROF handler`, followed by SIGABRT. For the base control the scratch
checkout was switched to the parent, with no retained candidate tests or implementation; miniruby,
libminiruby.a and the Rust tests were rebuilt. Six further bounded standalone base runs of that test all pass
here. Thus the failure really is pre-existing on master, but the builder's five-of-six standalone failures are
not a universal property. No root cause for this sampling flake is claimed. Logs: `head-zjit-test.log`,
`base-zjit-test.log`, `base-profile-{1..6}.log`.

The 100-call example returns `R2 A` 100/100 in interp/default/z1/z2/zmv on head. On base: interp and z1 are
correct; default has 71 wrong calls; z2 and zmv have 99 wrong calls. Head z2 records 99
`send_fallback_super_from_refinement` hits. `probe.rb` adds 41 deterministic scenarios, each with 100 calls:
class, inherited class, included module, prepended class and Array-subclass receivers; caller-only and lexical
refinement activation; asymmetric simple arguments, explicit keywords/blocks, modified-local zsuper,
duck-typed splat conversion and its call counts; plus a refined C-function target. Exact head has zero differences
from its interpreter in default/z1/z2/zmv; base has 6/5/6/6 divergent scenarios respectively. Base/head interpreter
outputs are byte-identical. The block/complex-argument cases are controls for existing refusals, not proof that
the new guard is reached there. Logs: `{head,base}-{repro,probe}-{interp,default,z1,z2,zmv}.log`.

**Sentence-by-sentence text audit.** Read the candidate commit with `git show --format=fuller HEAD`, the item's
entire public body and both reply drafts. After the source audit, read the live PR body, inline comments, reviews
and conversation through `gh api`; only tekknolagi's two quoted requests were present. Opened Shopify/ruby#1128
through `gh api`; it contains the same repro and observed wrong result. `git show 4a21b83693` confirms the named
subject, PR number and introduction of the wrong lookup; the historical first-bad build was not repeated here.

- Body opening: issue attribution and introducing commit match those sources. The next three sentences about
  `using`, CME, superclass lookup and `R2 R1 A` match the traced code and head/base repro.
- The fallback and `SuperFromRefinement` sentences match both dispatch paths, enum, Display and counter mapping.
  The new helper sentence is accurate. The final sentence of that paragraph is accurate for VM lookup, including
  the class/module distinction, but say **"The VM's lookup"** instead of **"The VM helper"** so it cannot be
  mistaken for the new boolean predicate wrapper.
- Every sentence of the final test paragraph is confirmed by the checks above. It nevertheless conflicts with
  DECISIONS' body rule against suite counts and test-run reports: recommend deleting that paragraph and keeping
  the evidence here. This is text cleanup, not a source blocker or a claim that the full suite passes.
- Commit message: each causal sentence matches the CME/lookup path and repro; its embedded Client snippet is
  the caller from the test; the VM/YJIT and helper sentences match source; the introduction/fixes lines match
  history and the issue. No unsupported speed claim or extra code comment.
- First reply: both sentences are accurate, including test placement, ordinary-super comparison and the
  guard-removal HIR result. No wording change is needed.
- Second reply: the first sentence is accurate. In the second, replace **"that macro"** with **"that
  predicate"**: the uppercase VM helper is a static inline function. The singleton-wrapper analogy and
  single-call claim are accurate. Its last sentence correctly describes the PR's ZJIT-only scope.
- The internal German explanation has the same macro/function nit. Replace **"es gibt nur noch eine
  Definition der Regel"** with **"ZJIT dupliziert die Bedingung damit nicht mehr"**; YJIT still has its inline
  copy, so there is not one global definition. Say the PR stays scoped to ZJIT rather than presenting the local
  one-concern rule as an absolute upstream prohibition.

The minimally corrected second reply, for Thomas to read before posting:

> YJIT has the same check inline in `gen_invokesuper_specialized`, and the interpreter uses
> `RICLASS_FOR_REFINEMENT_P` in `vm_search_normal_superclass`. ZJIT now calls that predicate through
> `rb_zjit_iclass_for_refinement_p` in `zjit.c`, like `rb_zjit_singleton_class_p`, so the condition is a single
> call. I left YJIT's copy alone to keep this PR to ZJIT.

Drafts remain unchanged in the item; nothing is approved for posting by this review. The scratch checkout was
restored to the exact candidate and rebuilt: final `make -s zjit-test ZJIT_TESTS=invokesuper` passes 48/48,
the generated-binding hash matches again, and its tracked worktree is clean. Log: `final-invokesuper.log`.
Not run here: full Ruby test-all, btest, hosted CI, arm64, benchmarks. No speed claim. The pass records review
evidence, not permission to push the Ruby PR branch or publish replies.

### ZRS1 Opus review of 7a1eed11f4 (2026-11-18)

**Verdict: changes.** Reviewer `thermos-opus`, thread `T-01a1f051-f32b-7206-936f-08a375829cc1`. Both Thermos
rubrics applied directly in this thread, no subagents or other threads, no contact with the Sol reviewer (its
pass above landed first; read only after this review's evidence was collected). The source is correct; the two
must-fixes are about how the PR answers tekknolagi. Nothing pushed to Ruby, nothing posted.

**Pins.** `git ls-remote` on thomasklemm/ruby: `zjit-super-from-refinement-3` at `7a1eed11f4…`, PR branch
`-2` still at `1d86986033`; `gh api` shows the PR at `1d86986033`, open, ready, the live body without the helper
sentence. One commit on `7db0202722`, Thomas author and committer, empty `%(trailers:only)`. x86_64 orb,
bootstrap Ruby 4.0.7, Rust 1.100.0, cargo-nextest 0.9.152, libclang 19; `configure --enable-zjit=dev
--disable-install-doc`, `make -j2`. Probe and logs: `.amp/in/orb-backup/zrs1-opus/` in this thread.

**Guard exactness.** `vm_search_normal_superclass` (vm_insnhelper.c) is `RCLASS_SUPER(RCLASS_ORIGIN(klass))`
whenever `RICLASS_FOR_REFINEMENT_P(klass)` is false, which is exactly ZJIT's existing computation, so the
refusal covers precisely the cases where the VM and ZJIT disagree, and nothing else. The new helper returns
`RICLASS_FOR_REFINEMENT_P` itself, so the T_ICLASS / T_MODULE / RMODULE_IS_REFINEMENT order cannot drift from
the VM's. Refined modules: `add_activated_refinement` builds an iclass of the refinement module, so the same
predicate fires; the VM's class/module distinction only matters for what super resolves to, and the generic
path delegates that to the VM. Prepended/included modules of an ordinary class are iclasses of non-refinement
modules (predicate false), unchanged.

Probe `probe.rb`, 14 scenarios × 100 calls with asymmetric arguments so each layer leaves a distinct number:

| scenario | interp (= head, every mode) | master ZJIT |
|---|---|---|
| refined class, caller-only `using R1; using R2` | `R2 A6` | z1 95, default 71, z2/zmv 99 calls `R2 R1 A7` |
| refined module (included into a class) | `R2 M6` | same pattern, `R2 R1 M7` |
| refined class with prepended P and included I below | `R2 PABI148` | `R2 R1 PABI151` |
| `send(:foo)` / `method(:foo).call` through `using` | `R2 A6` | 100/100 `R2 R1 A7` |
| caller with only R2, then the two-refinement caller again, then mixed callers | `R2 A6` | again 100 wrong; mixed 50/50 |
| lexical chain (`using R4a` inside R4b) | `R4b R4a A7` | unchanged |
| plain `super` with a refinement active at the super site | `B R5 A7` | unchanged |
| `bind_call` of the refinement's UnboundMethod | `R6 A4` | unchanged |
| prepend-class, prepended-singleton, include controls | `PBA8`, `SA8`, `DI2` | unchanged |

Head output is byte-identical to the interpreter in default, z1, z2 and zmv. Master diverges in 7 of 14 in
every ZJIT mode, z1 included. Head z2 `--zjit-stats`: `super_from_refinement` 1,094.

**HIR test.** Removing only the seven-line guard from head: both new tests fail. The HIR snapshot becomes
`PatchPoint MethodRedefined(Unknown@…)`, the CME/specval guards, `PushInlineFrame :foo` (R1#foo inlined) and an
inner `InvokeSuper … polymorphic call site`; the codegen test returns `"R2 R1 A"`. Restored head: `ZJIT_TESTS=
invokesuper` 48/48.

**Must-fix 1: the PR does not show before/after HIR.** tekknolagi asked to "see before/after hir output". The
single commit adds only the after snapshot; the before exists only in our notes. His own ZJIT PRs do this with a
baseline commit: ruby/ruby#19770 (`47557025d5` "Add baseline tests for Float#== nil, true, false", then
`f4e44fad2d` the fold), #19594 (`3b150a90ff` "Add before tests for equality with nil"), #19585 (`9982455489`
"Add tests demonstrating current IsBitEqual behavior"). Smallest fix: two commits on `7db0202722`.
Commit 1, e.g. "ZJIT: Add a test for super from a refined method", adds only the opt_tests.rs test with master's
snapshot (`baseline-hir-test-on-7db0202722.patch`); commit 2 is today's tree, whose opt_tests.rs diff is then the
before/after (`fix-commit-opt_tests-diff.patch`). Checked: the baseline test passes on master 7db0202722, and
the head tree passes. The codegen test stays in commit 2. Reply 1 then names the commits.

**Must-fix 2: body.** "The new HIR and codegen tests fail without the fix…" and the 245-test / SIGPROF sentences
are suite counts and test-run results, which [DECISIONS](../DECISIONS.md#pull-requests) lists under Leave out.
Cut the paragraph when the body is patched (the Sol pass made the same point as a nit).

**Helper shape.** Name, `bool` return, location right after `rb_zjit_singleton_class_p` and the bindgen
allowlist line beside it match the precedent. `make zjit-bindgen` (after `rustup component add rustfmt`) left the
tree clean. Not a macro: `RICLASS_FOR_REFINEMENT_P` is a `static inline` function in `internal/class.h`, which
bindgen cannot bind without wrap-static support (no `wrap_static_fns` in the bindgen config, absent from
`cruby_bindings.inc.rs`). That is the honest answer to "is there a better api?": the predicate exists, but a
non-exported C wrapper in zjit.c is how ZJIT reaches static inline helpers. No `jit.c` (shared) placement: YJIT
is not touched and one concern per PR rules it out. zjit.c compiles without warnings.

**YJIT.** `gen_invokesuper_specialized` has the same three checks inline and counts `invokesuper_refinement`; it
is correct. Moving it onto a shared `rb_jit_` helper would touch YJIT in a ZJIT PR, so leaving it is right;
the reply can offer it as a follow-up if he wants.

**Profiling-test failure.** `make -s zjit-test`: head 2,015 passed, 1 failed, 15 skipped; master 7db0202722
2,013 passed, 1 failed, 15 skipped; both `test_profile_frames_during_direct_jit_to_jit_entry` SIGABRT. Run alone,
6/6 pass on master and 6/6 on head. Pre-existing and load-dependent; the item note's "fails 5 of 6 completed
runs" when run alone did not reproduce here.

**Text, sentence by sentence.**
- Commit message: accurate. Optional: "When a refined method is called" — elsewhere in ZJIT "refined" means
  `VM_METHOD_TYPE_REFINED` (`cruby_methods.rs`, the super-target stat `refined`), and Ruby's refinements doc says
  "refinement method"; the reason string "super: call from a refined method" has the same ambiguity. Not blocking.
- Body: "The check is the interpreter's own `RICLASS_FOR_REFINEMENT_P`, exposed through a small helper in
  `zjit.c`." accurate. The next sentence, "The VM helper preserves…", now reads as if it meant the zjit.c helper;
  say "The VM's super lookup preserves…".
- Reply 1: accurate about content; must point at the baseline commit after must-fix 1.
- Reply 2: "the interpreter uses `RICLASS_FOR_REFINEMENT_P` in `vm_search_normal_superclass`" true. "ZJIT now
  calls that macro" false: function. Suggested wording below.
- For Thomas (German): "es gibt nur noch eine Definition der Regel" is false while YJIT keeps its copy; say ZJIT
  nutzt jetzt dieselbe Prüfung wie der Interpreter, statt sie nachzubauen. "C-Makro" → C-Funktion.

Suggested replies:

> Added `test_invokesuper_from_refined_method_remains_invokesuper` in `hir/opt_tests.rs` as a separate first
> commit with the current HIR, so the fix commit shows the change: before, `R2#foo` inlines `R1#foo`
> (`PushInlineFrame`); after, it stays `InvokeSuper` with `SuperFromRefinement`.

> YJIT has the same three checks inline in `gen_invokesuper_specialized`. The interpreter's version is
> `RICLASS_FOR_REFINEMENT_P` in `internal/class.h`, which `vm_search_normal_superclass` uses, but it is
> `static inline`, so bindgen can't reach it. ZJIT now calls it through `rb_zjit_iclass_for_refinement_p` in
> `zjit.c`, like `rb_zjit_singleton_class_p`. I left YJIT's copy alone to keep this PR to ZJIT.

Not run: full test-all, btest, hosted CI, arm64.

### ZRS1 Sol confirm of a5ac62d1a2 (2026-11-18)

**Verdict: approve; no must-fixes or remaining body/reply wording changes.** `thermos-sol`, orb
`T-01a1f051-e70d-74df-8d5a-51990dfd4dbf`. Both Thermos rubrics applied directly, with no delegated reviewer,
subagent, new thread or coordination with the independent reviewer. This is the requested short confirm of
`thomasklemm/ruby:zjit-super-from-refinement-4`, exact head
`a5ac62d1a22e8ffa9a2cc8e5ac4720ea5b191482`, against `7db0202722a286011518bd291f51a15fb652dc02`.

**Commit partition and executed checks.** The branch has exactly two commits. First,
`61f275c7e5e3aea346f6291be2678dca2b5796ef` adds only 50 lines in `zjit/src/hir/opt_tests.rs`: the new test
with master's snapshot. Checked out alone, `make -j2 miniruby` succeeds and
`make -s zjit-test ZJIT_TESTS=invokesuper` reports **47 passed**, including the new baseline test. The binary
banner names `61f275c7e5`. The fix commit then shows the requested before/after directly: remove the method
entry/frame guards, `PushInlineFrame`, inner polymorphic `InvokeSuper` and `PopInlineFrame`; retain a generic
`InvokeSuper` with the refined-method reason. No failing intermediate commit is required.

`git rev-parse a5ac62d1a2^{tree} 7a1eed11f4^{tree}` returns
`3052f43db83164971aebc405ddd609446e0bb40b` twice; `git diff --exit-code 7a1eed11f4 a5ac62d1a2` is empty.
Rebuilt exact head: the same invokesuper command reports **48 passed**, including both new tests. Six fixed
standalone runs of `test_profile_frames_during_direct_jit_to_jit_entry` pass **6/6**. The 100-call repro at
threshold 2 returns `{"R2 A"=>100}`. Scratch source worktree restored clean at exact head. Logs are under
`.amp/in/orb-backup/zrs1-review/round4-{baseline,head}-*.log` in this orb.

Both commits use Thomas as author and committer and have no trailers. The baseline message accurately
describes its sole test addition. The fix-message prose is unchanged from the reviewed `7a1eed11f4` message;
all causal, lookup, helper and regression-attribution sentences retain the earlier evidence. A precision
correction to the builder note: raw messages are **946 versus 947 bytes**, not byte-identical; the new message
has one extra terminal LF. No content difference or Ruby history rewrite is needed.

**Body, sentence by sentence.** The issue and introducing-commit attribution retain the earlier historical
repro evidence. The next three sentences accurately describe a caller-specific refinement iclass, the wrong
origin-super target and `"R2 R1 A"` versus `"R2 A"`. The fallback sentence agrees with the generic VM path and
YJIT's existing refusal. `InvokeSuper`/`SuperFromRefinement` and the canonical predicate/wrapper sentences
match the head. The final sentence now says **"The VM's super lookup preserves…"**, correctly attributing
class/module and definition-site refinement handling to lookup, not the predicate. The suite-count/SIGPROF
paragraph is gone. No further body edit is required.

**Reply 1, its single sentence.** The named test exists in the named file; commit 1 carries the current/base
HIR and passes alone. Its `R2#foo` snapshot inlines `R1#foo` via `PushInlineFrame`; commit 2 changes that same
snapshot to generic `InvokeSuper` with the displayed reason mapped from `SuperFromRefinement`. Every clause
is accurate, and the two-commit presentation now supplies the requested before/after.

**Reply 2, all four sentences.** (1) YJIT's `gen_invokesuper_specialized` has the same three checks inline.
(2) `RICLASS_FOR_REFINEMENT_P` is `static inline bool` in `internal/class.h` and is used by
`vm_search_normal_superclass`. "bindgen can't reach it" is accurate for this project's configuration:
`zjit/bindgen/src/main.rs` enables neither inline-function emission nor static-function wrapping, and the
predicate has no direct binding. (3) The new `zjit.c` wrapper calls that predicate, immediately beside the
existing singleton predicate wrapper, and HIR calls its generated binding. (4) No YJIT file changes; leaving
its correct copy alone keeps this a ZJIT fix. No reply wording change remains; drafts stay unposted for Thomas.

**Both rubrics.** The identical final tree retains the earlier correctness/security and maintainability
findings: canonical C predicate behind the established FFI boundary, idiomatic wrapper and generated binding,
one conservative refusal at the existing specialization boundary, no new lookup implementation or unrelated
YJIT refactor. The partition adds no runtime changes beyond that already-reviewed tree. No new source finding.
The earlier guard-removal controls and full-suite evidence still apply; the profiling failure was reproduced
on unmodified master and was not a deterministic standalone failure. Full ZJIT/Ruby suites, btest, hosted CI
and arm64 were not rerun in this short confirm; this is not a claim of wholly green full suites. No Ruby push
or external post.

### Z11 on three census apps

Campfire, Fizzy and Writebook are census apps. Their own suites above are Z11's comparison (interpreter against
`--zjit --zjit-call-threshold=1` on the same build) plus 12 more modes and the debug build, on Rails 8.2 instead
of F1's overlays. Result: no divergence beyond the Campfire flake that Z11 also found. The service-backed
census apps (Sure, Mastodon, Loomio, CASA, Lobsters, Hackatime, CodeTriage and Discourse) were not run, because
PostgreSQL, Redis and memcached are not set up in this orb.

### Not run

- The Rails 8.1 app variants (Campfire `02023b0`, Fizzy `6f1d200`, Writebook `be1f8fc`). Without them, Z2's
  redcarpet abort under auto-compaction in Fizzy r81 was not retried; Fizzy r82 under `zcm` and `ic` finished.
- test-all on the debug build, Active Storage, Railties, and YJIT modes.
