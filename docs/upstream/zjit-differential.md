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
