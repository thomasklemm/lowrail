
### interp

| width | case | main Ir | A/A | value! only (fix) | branch (fixb) | objects main/fixb | gate main/main2/fix/fixb |
|---|---|---:|---:|---:|---:|---|---|
| 30 | dup_warm | 466056 | -0.02% | - | -1.62% | 82.02/82.44 | n/a/n/a/-/n/a |
| 30 | load1 | 402970 | -0.29% | - | -0.24% | 68.44/68.02 | n/a/n/a/-/n/a |
| 30 | load1_attributes | 621786 | -0.07% | - | -0.03% | 83.02/83.02 | n/a/n/a/-/n/a |
| 30 | load1_dup | 1115477 | -0.04% | - | -0.73% | 182.02/182.02 | n/a/n/a/-/n/a |
| 30 | load1_read_all | 550299 | -0.05% | - | -0.79% | 82.02/82.02 | n/a/n/a/-/n/a |
| 30 | load1_serializable_hash | 787474 | +0.00% | - | -0.68% | 120.02/120.02 | n/a/n/a/-/n/a |
| 30 | rows10_read_all | 1709928 | -0.00% | - | -2.49% | 182.02/182.02 | n/a/n/a/-/n/a |
| req | requests | 1047245 | -0.42% | - | +1.47% | 372.76/372.51 | n/a/n/a/-/n/a |

### yjit

| width | case | main Ir | A/A | value! only (fix) | branch (fixb) | objects main/fixb | gate main/main2/fix/fixb |
|---|---|---:|---:|---:|---:|---|---|
| 30 | dup_warm | 256410 | +0.19% | - | -5.10% | 82.05/82.05 | pass/pass/-/pass |
| 30 | load1 | 200759 | +5.94% | - | -0.19% | 68.05/68.05 | pass/fail/-/pass |
| 30 | load1_attributes | 310141 | -1.27% | - | -0.24% | 83.05/83.05 | pass/pass/-/pass |
| 30 | load1_dup | 592741 | -0.26% | - | -2.24% | 182.05/182.05 | pass/pass/-/pass |
| 30 | load1_read_all | 267589 | +5.10% | - | -2.34% | 82.05/82.05 | pass/fail/-/pass |
| 30 | load1_serializable_hash | 515084 | -1.43% | - | -1.81% | 120.05/120.05 | pass/pass/-/pass |
| 30 | rows10_read_all | 751708 | -0.01% | - | -7.26% | 182.05/182.47 | pass/pass/-/fail |

### zjit

| width | case | main Ir | A/A | value! only (fix) | branch (fixb) | objects main/fixb | gate main/main2/fix/fixb |
|---|---|---:|---:|---:|---:|---|---|
| 30 | dup_warm | 225523 | -0.03% | - | -9.84% | 82.05/82.05 | pass/pass/-/pass |
| 30 | load1 | 202413 | -0.09% | - | +0.19% | 66.05/66.35 | pass/pass/-/pass |
| 30 | load1_attributes | 284941 | +2.16% | - | -0.26% | 81.05/81.05 | pass/fail/-/pass |
| 30 | load1_dup | 523186 | -0.31% | - | -5.02% | 180.05/180.05 | pass/pass/-/pass |
| 30 | load1_read_all | 250611 | -0.37% | - | -4.36% | 80.05/80.05 | fail/pass/-/pass |
| 30 | load1_serializable_hash | 430525 | -0.42% | - | -3.44% | 118.05/118.05 | pass/pass/-/pass |
| 30 | rows10_read_all | 656403 | -11.69% | - | -32.10% | 182.05/182.05 | pass/fail/-/pass |
| req | requests | 1073579 | +0.00% | - | -0.39% | 366.79/366.49 | pass/pass/-/pass |
