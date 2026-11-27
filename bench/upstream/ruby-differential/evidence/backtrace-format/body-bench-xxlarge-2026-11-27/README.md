# BT1 wall time on an a1.xxlarge orb (2026-11-27)

The question: does a bigger orb give a wall-time measurement clean enough for the body? The earlier attempt on a 2-vCPU orb
([body-bench-2026-11-27](../body-bench-2026-11-27/SUMMARY.txt)) had an A/A of 1.00x–1.16x. It does: on this orb
both methods show A/As within a few percent and the head well outside them.

Builds (`build.sh`: out-of-tree `configure --disable-install-doc --disable-yjit --disable-zjit`, `make -j6`, install):
base 274cfe719a, head e75b1f0109, new head 5fc1871eec (the branch moved during the run; it changes only
`test/ruby/test_backtrace.rb` by two lines, `vm_backtrace.c` and the benchmark are the same) and Ruby 4.0.9 3e93b23afc.
Every version line in the raw output names the expected SHA. Machine: [machine.txt](machine.txt) (16 vCPUs, 8 cores with
2 SMT threads each, Xeon @ 2.60GHz under KVM). Every timed process ran on `taskset -c 14`, and nothing ran on its sibling
cpu15. The host-speed probe (`probe.rb`, the wall_noise reference loop and float sort) showed no steal time before
or after the runs. The sort's 10th to 90th percentile spread was 0.97–1.05 of its median, and the integer loop's 0.86–1.11.

## 1. `script/upstream-bench --wall 30`, interpreter

`bt_wall.rb`: `caller`, `Exception#backtrace` and `locations.each(&:to_s)` 50 frames deep. The runs are `wall-head/`
(base against e75b1f0109) and `wall-head2/` (base against 5fc1871eec), each with `table.md`, `results.json` and
`commands.sh`; raw process logs are in `wall-raw.tar.gz`.

| run | case | change [95% CI] | A/A [95% CI] |
| --- | --- | --- | --- |
| e75b1f0109 | `caller` | −16.4% [−17.7%, −15.7%] | −0.0% [−1.0%, +0.8%] |
| e75b1f0109 | `Exception#backtrace` | −16.8% [−19.1%, −16.1%] | −0.2% [−0.7%, +0.4%] |
| e75b1f0109 | `locations.each(&:to_s)` | −17.4% [−18.5%, −16.8%] | −0.1% [−0.8%, +0.2%] |
| 5fc1871eec | `caller` | −19.1% [−20.1%, −18.4%] | +0.0% [−0.8%, +1.0%] |
| 5fc1871eec | `Exception#backtrace` | −20.4% [−21.5%, −19.0%] | +0.1% [−0.9%, +1.2%] |
| 5fc1871eec | `locations.each(&:to_s)` | −19.6% [−20.6%, −18.5%] | +0.2% [−0.6%, +0.6%] |

Every A/A contains 0 and every change excludes it, so all six changes are claimed. The two cohorts differ by about
3 points with the same `vm_backtrace.c` and intervals that don't overlap. Base itself was about 2% faster in the second
cohort (30.44 against 31.08 µs for `caller`). The intervals cover the noise within one cohort, not the spread between
builds and runs, so the effect is about 16–20% less time per call, not a precise figure.

## 2. `make benchmark ITEM=vm_backtrace_to_s COMPARE_RUBY=… OPTS="--repeat-count 10"`

Run as `taskset -c 14 make benchmark …` from each build tree, in interleaved rounds (`mb.sh`, then `mb2.sh`). Raw output is in
`make-benchmark/`. compare-ruby is the installed Ruby, and built-ruby is the build tree.

| set | compare-ruby / built-ruby | 10 runs: faster side's ratio | spread |
| --- | --- | --- | --- |
| `aa-*` | base / base | 1.00 1.00 1.01 1.01 1.06 1.00 1.00 1.01 1.01 1.00 | 1.00x–1.06x |
| `aa2-*` | base / base | 1.00 1.01 1.00 1.01 1.02 1.00 1.02 1.01 1.01 1.01 | 1.00x–1.02x |
| `hb-*` | base / e75b1f0109 | head 1.22 1.19 1.21 1.21 1.23 1.22 1.22 1.22 1.22 1.23 | 1.19x–1.23x |
| `hb2-*` | base / 5fc1871eec | head 1.23 1.21 1.20 1.18 1.22 1.20 1.19 1.22 1.18 1.22 | 1.18x–1.23x |
| `vh-*` | 4.0.9 / e75b1f0109 | head 1.05 1.01 1.03 1.02, 4.0.9 1.00, head 1.02, 4.0.9 1.01, head 1.01 1.01, 4.0.9 1.02 | 4.0.9 up to 1.02x faster, head up to 1.05x |

In 19 of the 20 A/A runs the two sides were within 2% (one was 1.06x). The head runs, all 20, were between 1.18x
and 1.23x faster. Base ran at 42.6k–45.9k i/s, the head at 53.2k–55.3k i/s and 4.0.9 at 52.0k–54.8k i/s. The head is about
as fast as 4.0.9: the ratios run from 4.0.9 1.02x faster to the head 1.05x faster, inside the A/A spread.

## Verdict

A bigger orb helps: the 2-vCPU orb's A/A of up to 1.16x came from host phases that one busy pair of vCPUs couldn't
escape. Here, with an idle SMT sibling, the A/A stays within 1.02x in 19 of 20 runs. The body table is trustworthy as
long as its caption claims about 1.2x, not a precise figure. A median run (`make-benchmark/hb2-6.txt`, base against 5fc1871eec):

```
compare-ruby: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
built-ruby: ruby 4.1.0dev (2026-11-27T17:45:37Z HEAD 5fc1871eec) +PRISM [x86_64-linux]
# Iteration per second (i/s)

|                   |compare-ruby|built-ruby|
|:------------------|-----------:|---------:|
|vm_backtrace_to_s  |     44.957k|   54.089k|
|                   |           -|     1.20x|
```

The `vm_backtrace_to_s` 4.0.9 sentence: Ruby 4.0.9 runs it at about the same speed as this change (within 2–5% either way).
