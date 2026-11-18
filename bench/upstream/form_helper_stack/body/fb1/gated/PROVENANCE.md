# FB1 body bench, rerun with the JIT-flat gate (2026-11-18)

`body/fb1` ran before the gate, so its YJIT rows are uncertified: the Callgrind warm-up never ran the measured
`cycle` block, which then compiled inside every YJIT window ([body-numbers](../../../../../../docs/upstream/body-numbers.md#limits)).
This directory reruns the same benchmark with the gated `script/upstream-bench` (Lowrail `a05d1dab`, gate from
`15bf35e5`), changing nothing else.

* Script: `fb1_body.rb`, byte-identical to `body/fb1/fb1_body.rb` and `form_helper_stack/fb1_body.rb`.
* Trees: the same as `body/fb1`. Base `rails-fb1-main` is rails/rails at `a5203b3d4d` (`built_on`); candidate
  `rails-fb1` is a worktree at `a2a13fc793`, fetched from the PR head, which still pointed there (`head`). Both
  clean (`dirty: false` in `results.json`).
* Ruby: mise 4.0.7, `ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]`, the same description
  as `body/fb1`.
* Valgrind: rebuilt in this orb with `script/bench-valgrind`. Source, patch, compiler and glibc hashes match
  `body/fb1/valgrind.json`; the tool binary's sha256 differs, as it does between every build (the build directory
  is a fresh `mktemp`; `jit_flat_gate/am1` and `body/am1` differ the same way).
* Flags as in `body/fb1`: `--gems activesupport,activemodel,actionview --modes interp,yjit --ips 3 --names
  main,branch`, n = 2000, core 1, fixed heap. Every command is in `commands.sh`.

```sh
mise exec ruby@4.0.7 -- script/upstream-bench \
  --out bench/upstream/form_helper_stack/body/fb1/gated \
  --base ~/workspace/rails-fb1-main --candidate ~/workspace/rails-fb1 \
  --gems activesupport,activemodel,actionview \
  --ruby 4.0.7 --valgrind ~/workspace/valgrind-brk512 \
  --modes interp,yjit --ips 3 --names main,branch \
  bench/upstream/form_helper_stack/fb1_body.rb
```

Gate: compiled_iseq_count, compiled_block_count and invalidation_count did not move in any of the 24 YJIT
Callgrind windows or the 36 benchmark-ips windows. No Valgrind log reports a brk overflow.

| Callgrind change | `body/fb1` (pre-gate) | gated | gated A/A |
| --- | ---: | ---: | ---: |
| interp `text_field` | −2.8% | −3.3% | 0.13% |
| interp `checkbox` | −2.1% | −2.2% | 0.03% |
| interp `text_field, persisted` | −2.8% | −2.9% | 0.17% |
| interp `checkbox, persisted` | −2.2% | −2.2% | 0.12% |
| YJIT `text_field` | −4.6% | −5.4% | 0.59% |
| YJIT `checkbox` | −3.8% | −3.6% | 0.06% |
| YJIT `text_field, persisted` | −4.3% | −4.4% | 0.15% |
| YJIT `checkbox, persisted` | −3.6% | −4.0% | 0.29% |

Every cell is JIT-flat (YJIT) and outside its A/A. The plain and persisted cases run the same field path, yet
differ by up to 0.4 points in the interpreter and 1.0 point under YJIT, more than their A/A, so the body rounds
to whole percent: `text_field` about 3% / 5%, `checkbox` about 2% / 4%. benchmark-ips (best of 3, YJIT):
+8.5%, +5.4%, +5.1%, +3.6%, all outside their A/A (0.94–4.05%) but not several times it, so no wall-time claim.
