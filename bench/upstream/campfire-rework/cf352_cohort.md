# #352 body numbers: declared cohort (2026-11-18, before the run)

`script/upstream-bench` with [cf352_body.rb](cf352_body.rb), Ruby 4.0.9, the pinned Valgrind 3.19.0 (brk 512 MiB):

* base `basecamp/once-campfire` main `7b80988`, candidate `claude/project-thread-1ks0h3-2` at `59f8a80bf6`, each
  booted from its own checkout and test database (`--gems ""`, `UPSTREAM_BENCH_TREE`);
* four cases (plain, mention + link, formatted list, Lexxy paragraphs), `-n 500`, objects and Callgrind `totals:`;
* two invocations run side by side, `--modes interp` → `body/CF352-interp` and `--modes yjit` → `body/CF352-yjit`;
* no benchmark-ips (its Gemfile would replace the app's bundle); ZJIT not measured.

Addendum (declared mid-run, after the confirm reported superlinear time on dense input): wall time of one
`TextMessagePresentationFilters.apply` on `"<span>x</span>" × n` for n = 3,000, 12,000 and 90,000, with
[cf352_dense.rb](cf352_dense.rb) under `bin/rails runner` (test, no JIT), main, `-2`, `-3`, main again, after the
first cohort's YJIT run, with one Callgrind process on the other CPU → [cf352_dense.txt](cf352_dense.txt). Too slow
for Callgrind; one call per size, so read it for scaling, not percentages.

Second cohort, for `claude/project-thread-1ks0h3-3` at `015240e9e2` (the confirm's fix, `source.xpath(".//*")`;
declared before it runs): the same command against the same main, candidate `015240e9e2` (fixtures loaded into its
test database) → `body/CF352-3-interp` and `body/CF352-3-yjit`, each mode started when the first cohort's run of
that mode ends. The first cohort, on `59f8a80bf6`, is diagnostic for `-2` only; the body number comes from this one.

Each run is reported as it comes out, including cells that are within noise or not JIT-flat; neither is rerun.
