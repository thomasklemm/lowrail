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
(executables or mise versions). `--modes interp,yjit` limits the modes; by default it runs the interpreter, YJIT,
and ZJIT when both Rubies have it. `-n` sets the calls per Callgrind window (default 2000), `--core` the CPU for
benchmark-ips (default 1), `--with GEM` adds a third-party gem to both Gemfiles.

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
  N = 0, divided by N. One process per window. A brk overflow in any Valgrind log stops the run.
* **benchmark-ips** (`--ips ROUNDS`): base, candidate, base again per round, each pinned with `taskset -c CORE`,
  5 s per report; the table takes the best round of each.

Every cell has base, candidate and base again. The A/A is |base₁ − base₂| / mean(base), and a change counts only
when it is larger. Otherwise the cell says "within noise" and the notes say "inside the A/A, no claim". Objects
that differ between the two base runs are shown as "–".

## Output

`--out` holds `table.md` (also printed), `results.json` (every value, the A/A, Ruby descriptions and tree heads),
`commands.sh` (every command, with its environment, in order), `raw/` (each process's output and Valgrind log), a
copy of the script, both Gemfiles and locks, and `valgrind.json` from the pinned tool.

The tables follow DECISIONS' body format: a heading that says what was measured, short cells, no A/A. The A/A,
commands and tree heads are in the "Record" lines below the tables and stay in the record. For the body, take
the rows it needs; a single cell that is "within noise" is not claimed in prose either.

## Limits

* Callgrind instructions are not time. YJIT and ZJIT instruction counts include compilation that falls into the
  window; with 3,000 warm-up calls it usually does not.
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
* `commands.sh` has absolute paths; rerunning it elsewhere needs the same layout or a fresh run.
* It does not run ruby-bench, the census or `make benchmark`; ruby/ruby bodies still use benchmark-driver
  ([DECISIONS](../DECISIONS.md#benchmark-tables-in-the-projects-own-format-thomas-2026-11-14)).
