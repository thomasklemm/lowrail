# Open ruby/ruby PRs, fresh pass (2026-11-10)

Scripts behind the 2026-11-10 rechecks of ruby/ruby #19492, #19487, #19659 and #19681 in
[contributions.md](../../../docs/upstream/contributions.md). Ruby master `f6a88fafb2`, release builds
(`--enable-yjit --enable-zjit`), plus an `--enable-zjit=dev` build for the ZJIT test suites. ruby-bench is at
`ad63bf8`. A/A is a second run of the master build.

* `win.rb` + `rb.sh`: ruby-bench reach windows. `win.rb` is preloaded and replaces `run_benchmark`: it runs
  `WIN_WARM` warmup iterations, then `WIN_N` windows of `WIN_LEN` iterations, each after `GC.start`. It reports
  the per-iteration deltas of the `WIN_KEYS` counters and whether the window was JIT-flat. For YJIT that means
  compiled ISEQs, compiled blocks and invalidations unchanged. For ZJIT it means compiled ISEQs, compiled exit
  stubs, invalidation time and the OOM counter unchanged; ZJIT exposes no invalidation count.
* Micro scripts print a `flat=` check for their measured loop. Each is measured as the Callgrind (cachegrind,
  no cache simulation, `--smc-check=all-non-file`) difference between two loop sizes, so boot and warmup cancel.
* `19681_app_callgrind.sh`: full callgrind of railsbench and lobsters (boot plus 3 iterations), read with
  `callgrind_annotate --inclusive=yes` for `rb_zjit_iseq_gen_entry_point`, `function_stub_hit` and
  `handle_caller_saved_regs`.
