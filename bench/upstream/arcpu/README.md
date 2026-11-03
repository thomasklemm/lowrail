# Active Record CPU tools (docs/upstream/activerecord-cpu.md)

Paths are those of the orb that ran bet A1: ruby-bench in `/home/user/workspace/ruby-bench` (byroot's heap-harness
`bf1afb2` plus [../index_with_ruby_bench](../index_with_ruby_bench), Gemfiles pointing at
`/home/user/workspace/rails-wt/bench`), Rails worktrees in `/home/user/workspace/rails-wt/NAME`, pinned Valgrind in
`/tmp/vg` (`script/bench-valgrind /tmp/vg`).

* `ruby-bench/harness-*`: copy to `ruby-bench/harness-*`. `harness-arprof` profiles after warmup (stackprof wall
  mode, raw); `harness-ir` runs one measured iteration inside `Array#cycle` for Callgrind's
  `--toggle-collect=rb_ary_cycle`, GC off; `harness-cpu` records wall and process CPU time per iteration.
* `rank.rb DUMP...`: Active Record / Active Model / Arel frames by self (C functions charged to the calling Ruby
  frame) and inclusive time, and self time by area. `callers.rb PATTERN DUMP...`: direct callers and callees of a
  frame. `incl.rb DUMP...`: inclusive time of named subsystems.
* `census_prof.sh OUT APP...` / `census_prof.rb`: the same profiles over a census app's workloads.
* `micro.rb RAILS_DIR CASES [ITERS] [ROUNDS]`: per-call cases on a 12-column SQLite model, loading Active Record from
  a worktree; `IR=1` for Callgrind, `CLOCK=cpu` for process CPU time. `ab.rb` interleaves it across worktrees
  (time), `irmicro.rb` runs it under Callgrind (instructions per call).
* `irab.rb --out DIR [--yjit] NAME=DIR...`: ruby-bench instruction counts per variant (a Gemfile copy per variant;
  apps in parallel, variants of an app in sequence, because railsbench reseeds its database at start).
* `rbab.rb --out DIR [--harness harness-cpu] NAME=DIR...`: interleaved ruby-bench wall-time rounds through the
  `rails-wt/bench` symlink.
