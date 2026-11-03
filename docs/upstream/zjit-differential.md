# ZJIT differential run on master 90dbced795 (bet Z2)

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
