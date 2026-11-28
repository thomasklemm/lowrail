### 🟢 Duel: 100% of benchmarks passed

Compared 6b6f67b (merged with `master`) with 277e88e (where HEAD left `origin/master`).

<details>
<summary>Details: 27 benchmarks in 110s, 1 unsettled</summary>

| Benchmark | Verdict | Timings (ratio [interval]) |
|---|---|---|
| `Mash: respond_to? a key, a suffix and a missing name` | unsettled | cpu 1.042 [1.032, 1.055] unsettled |
| `Mash#to_hash: a nested Mash` | faster | cpu 0.855 [0.850, 0.861] faster |
| `Dash.new: required properties and defaults` | same | cpu 1.005 [0.994, 1.019] |
| `Dash: read and write properties` | same | cpu 1.010 [0.999, 1.023] |
| `Trash.new: renamed and transformed properties` | same | cpu 1.005 [0.990, 1.013] |
| `Dash.new: coerced properties` | same | cpu 1.011 [1.002, 1.017] |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 1.005 [1.001, 1.008] |
| `Dash.new: coerced nested Dashes` | same | cpu 1.001 [0.996, 1.007] |
| `Mash: read keys given as Symbols as methods` | same | cpu 1.000 [0.982, 1.015] |
| `KeepOriginalKeys: read Symbol keys as methods` | same | cpu 1.027 [1.005, 1.047] |
| `KeepOriginalKeys: read String keys as methods` | same | cpu 0.993 [0.985, 1.003] |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 0.999 [0.996, 1.002] |
| `Mash.new: a flat Hash` | same | cpu 1.024 [1.014, 1.032] |
| `PermissiveRespondTo: Mash.new` | same | cpu 0.995 [0.982, 1.008] |
| `PermissiveRespondTo: write a new key as a method` | same | cpu 1.002 [0.988, 1.015] |
| `PermissiveRespondTo: overwrite a key as a method` | same | cpu 0.998 [0.984, 1.012] |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 0.999 [0.990, 1.004] |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.002 [0.994, 1.010] |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 0.999 [0.968, 1.025] |
| `DeepFind and DeepFetch: nested keys` | same | cpu 0.999 [0.994, 1.005] |
| `Mash.new: a nested JSON response` | same | cpu 1.006 [0.998, 1.016] |
| `Mash: read keys as methods` | same | cpu 1.028 [1.016, 1.041] |
| `Mash: read keys with suffixes` | same | cpu 1.004 [0.996, 1.014] |
| `Mash: read keys with [] and dig` | same | cpu 0.995 [0.988, 0.999] |
| `Mash: write new keys as methods` | same | cpu 1.011 [1.006, 1.016] |
| `Mash: overwrite a key as a method` | same | cpu 0.998 [0.990, 1.006] |
| `Mash#deep_merge: a nested update` | same | cpu 1.004 [0.995, 1.014] |

An unsettled timing was too close to the limit to settle. It doesn't fail the run, but one that's unsettled in run after run is noisy.

Across the board:

- cpu 1.003 [1.000, 1.005] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>
