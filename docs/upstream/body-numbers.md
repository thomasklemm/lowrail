# Body numbers: `script/upstream-bench`

Every number in an upstream PR body comes from one run of `script/upstream-bench`, and the run directory is kept
in the record. It compares a base and a candidate (two checkouts, or two Ruby builds) with the same benchmark
script. In every cell it measures base twice as an A/A, and it does not print a change that is inside that A/A.

```sh
bash script/bench-valgrind ~/w/valgrind-brk512        # once per orb; the pinned 3.19.0 with the 512 MiB brk
mise exec ruby@4.0.9 -- script/upstream-bench \
  --out bench/upstream/<topic>/body/<ID> \             # must not exist; commit it with the item
  --base ../rails-main --candidate ../rails-branch \   # worktrees at built_on and head
  --gems activesupport,activemodel,actionview \        # loaded from each tree by path (default: root gemspec)
  --ruby 4.0.9 --valgrind ~/w/valgrind-brk512 \
  --ips 3 --names main,branch \                        # optional benchmark-ips; column names
  bench/upstream/<topic>/<ID>_body.rb
```

For two Ruby builds use `--tree DIR` (or no tree, for plain Ruby) with `--base-ruby` and `--candidate-ruby`
(executables or mise versions). `--warmup N` sets the warm-up calls before each objects and Callgrind window
(default 3,000; an interpreter cell of a whole Rails request needs far fewer, and its Valgrind boot dominates).
`--preload SO` puts `LD_PRELOAD=SO` in every worker's environment and in `commands.sh`, as a control, such as
`fixrand.so` for a fixed hash seed; it is not for body numbers. For an app, whose bundle cannot be rebuilt from a gemspec, pass `--gems ""`: the
worker then gets its side's checkout in `UPSTREAM_BENCH_TREE` and the script boots the app from it
([cf352_body.rb](../../bench/upstream/campfire-rework/cf352_body.rb)); benchmark-ips needs its own Gemfile, so use
Callgrind only. `--modes interp,yjit` limits the modes, and `--modes ""` with `--ips` runs benchmark-ips alone (plus the objects pass
in the ips mode, which names the cases); by default it runs the interpreter, YJIT, and ZJIT when both
Rubies have it. `-n` sets the calls per Callgrind window (default 2000), `--core` the CPU for
benchmark-ips (default 1), `--with GEM` adds a third-party gem to both Gemfiles. `--wall ROUNDS` adds the wall-time
cohort below (`--modes "" --wall 30` runs it alone, without Valgrind).

## The benchmark script

Plain Ruby that sets up the scenario and names each call. Use realistic sizes
([DECISIONS](../DECISIONS.md#realistic-sizes-upstream-thomas-2026-11-14)).

```ruby
require "active_support/all"
require "active_model"

class Post
  include ActiveModel::Model
  attr_accessor :title
  validates :title, presence: true
end

post = Post.new(title: "Hello")
post.valid?

UpstreamBench.report("errors[:title]") { post.errors[:title] }
```

## What it measures

Each process gets bench.md's fixed heap floors (`RUBY_GC_HEAP_0..4_INIT_SLOTS` 1,000,000 / 250,000 / 100,000 /
20,000 / 10,000), no `RUBYOPT`, and a Gemfile per side that loads the named gems from that tree. The run refuses
when the two sides resolve different third-party gems.

* **Objects per call:** 3,000 warm-up calls, `GC.start`, GC off, then windows of 1,000 and 2,000 calls; the
  difference divided by 1,000, so a one-time allocation cancels out. Per mode, because YJIT can allocate
  differently.
* **Callgrind instructions per call:** as `fb1_ir.sh`: 3,000 warm-up calls, `GC.start`, GC off, N calls inside
  `Array#cycle` with `--toggle-collect=rb_ary_cycle` (`--smc-check=all` under a JIT), minus the same run with
  N = 0, divided by N. One process per window; each count is the trailing `totals:` line of its dump in `raw/`
  ([bench.md](../bench.md)). A brk overflow in any Valgrind log stops the run.
* **benchmark-ips** (`--ips ROUNDS`): base, candidate, base again per round, each pinned with `taskset -c CORE`,
  5 s per report; the table takes the best round of each.
* **Wall-time cohort** (`--wall ROUNDS`, for ~1% differences under a JIT; [why](../bench.md#wall-time-under-a-jit-noise-sources-2026-11-27)):
  one process on base times `--warmup` calls and sets each case's calls per window to about `--wall-ms` (default
  50 ms). Then each round runs fresh base, candidate and base processes, in the six orders in turn, pinned with
  `taskset -c CORE`, in `--wall-mode` (default ZJIT when both Rubies have it, else YJIT). Each process warms up
  through the timing loop itself (100 one-call windows, then `--warmup` calls per case) and times `--wall-windows`
  windows per case (default 30), the cases taking turns window by window. Each window runs `GC.start`, then GC
  off, and reads the thread's CPU time (wall time is recorded next to it). A process's value is its
  10th-percentile window. The change is the median of every round's two ratios candidate / base and
  candidate / base₂ (a difference of two like process values is symmetric, so under skewed process noise its
  null median stays at zero; candidate over the mean of both bases doesn't), the A/A the median of base₂ / base.
  Seeded 95% percentile-bootstrap intervals resample whole rounds. A change counts only with at least 10 rounds, an A/A
  interval that contains 0 and a change interval that doesn't. JIT counters are read before and after every
  timed window; the sum of their absolute deltas goes through the JIT-flat gate, per process, so a counter reset
  can't hide a compile.
* **JIT-flat gate** (YJIT and ZJIT cells, [bench.md](../bench.md)): each measured window records
  `compiled_iseq_count`, `compiled_block_count` and `invalidation_count` from `RubyVM::YJIT.runtime_stats` (ZJIT:
  `compiled_iseq_count`, `failed_iseq_count`, `compiled_side_exit_count`, `invalidation_count` from
  `RubyVM::ZJIT.stats`) before and after: every Callgrind N and N = 0 run, and each benchmark-ips report from
  `running` to its last timed interval (read in `Timing.time_us`, outside the intervals). The warm-up runs
  through the measured block itself: 3,000 calls of the `cycle` block (yielded from C by `reverse_each`), and
  3,000 `call_times(1)` per report before benchmark-ips' own warm-up. Interpreter cells are unchanged.

Every cell has base, candidate and base again. In Callgrind and benchmark-ips cells the A/A is
|base₁ − base₂| / mean(base), and a change counts only when it is larger (wall cells use the rule above).
Otherwise the cell says "within noise" and the notes say "inside the A/A, no claim". A JIT cell where any
window compiled, invalidated or lacked a counter says "not JIT-flat, no claim", whatever its A/A, and the notes
name the windows and counters that moved. Ruby master no longer has ZJIT's `invalidation_count`; there the gate reads `invalidation_time_ns`, which rises whenever an invalidation runs.
Objects that differ between the two base runs are shown as "–".

## Output

`--out` holds `table.md` (also printed), `results.json` (every value, the A/A, Ruby descriptions and tree heads),
`commands.sh` (every command, with its environment, in order), `raw/` (each process's output and Valgrind log), a
copy of the script, both Gemfiles and locks, and `valgrind.json` from the pinned tool.

The tables follow DECISIONS' body format: a heading that says what was measured, short cells, no A/A. The A/A,
commands and tree heads are in the "Record" lines below the tables and stay in the record. For the body, take
the rows it needs; a single cell that is "within noise" is not claimed in prose either.

## Limits

* Callgrind instructions are not time. Before the gate (commit `2884604afe` up to the gate's commit), every YJIT
  Callgrind N window compiled the `cycle` block itself, which the 3,000 warm-up calls never ran: about 470
  instructions per call in AM1, whose gated rerun `bench/upstream/jit_flat_gate/am1` gives YJIT `errors[:title]`
  3,101 → 1,231 (−60.3%) where `body/am1` had 3,574 → 1,684 (−52.9%). A benchmark-ips report whose warm-up
  enters `call_times` fewer times than the call threshold compiled it in the timed loop (AM1 with a 1 s warm-up).
  Those runs' YJIT rows are uncertified; FB1's gated rerun is `form_helper_stack/body/fb1/gated`.
  `jit_flat_gate/redefine` shows refused cells: a method redefined in every window, +0.1% Callgrind and +1.8% ips
  above their A/A, both "not JIT-flat, no claim". The objects worker has no gate; its counts are deterministic
  and checked by their own A/A.
* The A/A is one pair per cell, not a confidence interval. For Callgrind with GC off it is usually under 1%; for
  benchmark-ips on an orb it is often several percent, so most wall-time changes come out as noise.
* Each case gets its own Callgrind processes, so many cases and modes take a while: FB1, with 4 cases, 2 modes and
  3 benchmark-ips rounds, took about 35 minutes.
* Numbers from another Valgrind or machine move by about the A/A: FB1's hand-run `fb1_ir.txt` (stock Valgrind
  3.24) gave `text_field` −3.1% / −5.3% where this tool gives −2.8% / −4.6%, with the branch counts equal and
  main's differing by up to 0.7%. A body states a figure to the precision the A/A allows.
* "Within noise" compares against one A/A pair, which is a floor, not a guarantee. Two AM1 runs gave benchmark-ips
  `text_field` −0.9% (A/A 3.1%, no claim) and then +7.9% (A/A 4.7%, printed), and interpreter Callgrind −2.3% and
  −2.8%. A change just above its A/A is no evidence; claim wall time only when it is several times the A/A
  (AM1's `errors[:title]`, +326% with A/A 0.5%), and round Callgrind figures to what a rerun reproduces.
* The wall cohort resolves about 1% on this workload, not less: in
  [wall_noise](../../bench/upstream/wall_noise/README.md) 30 rounds gave A/A intervals of about ±1% and caught a
  planted ~1% regression under ZJIT (+1.3% [+0.7%, +2.2%]) and YJIT (+1.2% [+0.3%, +2.0%]). It costs about
  22 s per round for a 0.7 ms call, so 30 rounds take about 11 minutes. It measures time with GC off; a change
  whose cost is mostly GC shows in the objects column, not here.
* `commands.sh` has absolute paths; rerunning it elsewhere needs the same layout or a fresh run.
* It does not run ruby-bench, the census or `make benchmark`; ruby/ruby bodies still use benchmark-driver
  ([DECISIONS](../DECISIONS.md#benchmark-tables-in-the-projects-own-format-thomas-2026-11-14)).
