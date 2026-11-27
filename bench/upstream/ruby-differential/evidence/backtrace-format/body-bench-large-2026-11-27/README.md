# BT1 wall time on an a1.large orb (2026-11-27)

Second attempt at body wall numbers for BT1, after the 2-vCPU attempt in [body-bench-2026-11-27](../body-bench-2026-11-27/SUMMARY.txt)
was too noisy. Same plan ran on an a1.xxlarge in parallel; the body table comes from that run (Lowrail 85132249).
This record is for comparing orb sizes.

Rubies, all built from source here with the same configure (`--disable-install-doc`, default `-O3`): base
`274cfe719a`, head `e75b1f0109` (the PR branch tip when the runs started; it moved to `5fc1871eec` during them,
a test-only change, `vm_backtrace.c` and the yml identical; not measured), Ruby 4.0.9 `3e93b23afc`.
Machine: [machine.txt](machine.txt) (8 vCPUs, 4 cores × 2 SMT, Xeon @ 2.60GHz, KVM). Every timed run on vCPU 3,
its SMT sibling vCPU 2 left idle; drivers and vmstat on vCPUs 6 and 0.

## Method 1: `script/upstream-bench --wall 40`, interpreter

[backtrace_wall.rb](backtrace_wall.rb): depth 50 as in the yml, `Location#to_s` (the yml's case), `caller`, and
`Exception#backtrace` of a fresh raise. 40 rounds, `--wall-mode interp --core 3`.

| run | case | change [95% CI] | A/A [95% CI] | verdict |
| --- | --- | --- | --- | --- |
| [head vs base](wall-head-vs-base/table.md) | `Location#to_s` | −18.1% [−19.0%, −17.2%] | +0.4% [−0.3%, +1.6%] | claimed |
| | `caller` | −18.0% [−18.7%, −17.5%] | +0.1% [−0.8%, +1.1%] | claimed |
| | `Exception#backtrace` | −18.3% [−18.8%, −17.3%] | +0.4% [−0.5%, +1.5%] | claimed |
| [base vs copy of base](wall-aa-base-vs-basecopy/table.md) | `Location#to_s` | −2.0% [−2.9%, −0.4%] | −1.3% [−4.5%, −0.2%] | A/A excludes 0 |
| | `caller` | −0.8% [−1.8%, +1.5%] | −1.2% [−3.8%, −0.2%] | A/A excludes 0 |
| | `Exception#backtrace` | −1.8% [−2.9%, +0.4%] | −2.2% [−3.9%, −0.2%] | A/A excludes 0 |

The separate A/A run (candidate = a byte-identical copy of the base install) misses 0 by 0.2 points in every
in-run A/A and by 0.4 points in one change interval. Its per-process values cluster at about 28.5 µs and 32 µs
(13% apart). On this orb the cohort resolves about ±2–4%, not the ~1% of [wall_noise](../../../../wall_noise/README.md).
The −18% change is far outside that.

## Method 2: `make benchmark ITEM=vm_backtrace_to_s OPTS="--repeat-count 10"`, `taskset -c 3`

Raw output in [make-benchmark/](make-benchmark); every file's version lines show the exact SHAs. The A/A runs from
the base build tree against the base install, with the PR's yml copied unchanged into the base tree (base has no
such file; the first attempt failed, kept in `failed/`).

| comparison | runs | result (built-ruby against compare-ruby) |
| --- | ---: | --- |
| A/A, base vs base | 10 | 1.00x–1.04x either way (1.03, 0.98, 1.01, 0.98, 0.96, 1.01, 0.99, 0.96, 1.04, 1.00) |
| head vs base | 10 | 1.12x–1.33x, median 1.235x (1.25, 1.16, 1.33, 1.12, 1.18, 1.22, 1.20, 1.28, 1.29, 1.27) |
| head vs 4.0.9 | 5 | 0.93x–1.10x (1.01, 1.10, 1.08, 0.93, 0.97) |
| base vs 4.0.9 | 5 | 0.85x–0.88x (4.0.9 1.14x–1.18x faster) |

Base stays at 36.2k–40.1k i/s; head ranges 44.2k–50.7k, so the head spread comes from head's own runs. The A/A is
much tighter than on the 2-vCPU orb (up to 1.16x there). Master base is 1.14x–1.18x slower than 4.0.9 here and
head is back within noise of 4.0.9; why master regressed was not investigated.

Gaps: `head-vs-base-11` replaces a run terminated by a service restart (`failed/head-vs-base-2-terminated.txt`).
The orb service supervisor reran finished batch scripts, which overwrote four runs with later ones (every kept file
is one complete run) and truncated the vmstat logs of the wall and make runs. These runs went through
`amp orb service`, which reruns a script after it exits; one-shot batches should not use it.

## Host noise

Steal stays at 0 in every surviving vmstat sample (`make-benchmark/vmstat-*.log`, [host-probe-vmstat.log](host-probe-vmstat.log))
and over the session in `/proc/stat` (vCPU 3: 1.2 s steal in 67 min). Yet a fixed integer loop on vCPU 3
([host_probe.rb](host_probe.rb), [host-probe.txt](host-probe.txt), 120 samples, GC off) took 89.6–112.9 ms,
p90/min 1.14, with thread CPU time equal to wall time. The slowdowns don't show as steal: contention on the
host core (its other hyperthread or shared cache) is the likely source, not something the guest can idle.
