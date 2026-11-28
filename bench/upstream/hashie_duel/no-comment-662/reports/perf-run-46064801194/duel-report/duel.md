### 🟢 Duel: 100% of benchmarks passed

Compared 1af7ad9 (merged with `master`) with 9e313f3 (where HEAD left `origin/master`).

<details>
<summary>Details: 27 benchmarks in 110s</summary>

| Benchmark | Verdict | Timings (ratio [interval]) | Counts an iteration |
|---|---|---|---|
| `PermissiveRespondTo: write a new key as a method` | changed | cpu 0.998 [0.993, 1.001] | allocations 5 → 4 |
| `PermissiveRespondTo: overwrite a key as a method` | changed | cpu 1.005 [1.001, 1.008] | allocations 5 → 4 |
| `Mash: read keys with suffixes` | changed | cpu 1.014 [1.011, 1.017] | allocations 16 → 13 |
| `Mash: write new keys as methods` | changed | cpu 0.994 [0.990, 0.997] | allocations 5 → 4 |
| `Mash: overwrite a key as a method` | changed | cpu 1.009 [1.006, 1.013] | allocations 6 → 5 |
| `Dash.new: required properties and defaults` | same | cpu 0.989 [0.982, 0.995] |  |
| `Dash: read and write properties` | same | cpu 1.008 [1.002, 1.014] |  |
| `Trash.new: renamed and transformed properties` | same | cpu 0.993 [0.983, 0.999] |  |
| `Dash.new: coerced properties` | same | cpu 1.002 [0.996, 1.010] |  |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 1.002 [0.996, 1.011] |  |
| `Dash.new: coerced nested Dashes` | same | cpu 0.995 [0.989, 1.001] |  |
| `Mash: read keys given as Symbols as methods` | same | cpu 1.005 [0.999, 1.013] |  |
| `KeepOriginalKeys: read Symbol keys as methods` | same | cpu 0.998 [0.989, 1.008] |  |
| `KeepOriginalKeys: read String keys as methods` | same | cpu 0.997 [0.990, 1.005] |  |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 1.001 [0.995, 1.006] |  |
| `Mash.new: a flat Hash` | same | cpu 1.011 [1.003, 1.018] |  |
| `PermissiveRespondTo: Mash.new` | same | cpu 0.998 [0.984, 1.010] |  |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 1.002 [0.998, 1.007] |  |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.001 [0.993, 1.008] |  |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 1.001 [0.990, 1.013] |  |
| `DeepFind and DeepFetch: nested keys` | same | cpu 1.001 [0.995, 1.005] |  |
| `Mash.new: a nested JSON response` | same | cpu 1.003 [0.998, 1.008] |  |
| `Mash: read keys as methods` | same | cpu 1.007 [0.998, 1.016] |  |
| `Mash: read keys with [] and dig` | same | cpu 1.016 [1.004, 1.026] |  |
| `Mash: respond_to? a key, a suffix and a missing name` | same | cpu 0.994 [0.987, 1.001] |  |
| `Mash#deep_merge: a nested update` | same | cpu 1.002 [0.997, 1.006] |  |
| `Mash#to_hash: a nested Mash` | same | cpu 1.002 [0.996, 1.009] |  |

Across the board:

- cpu 1.001 [1.000, 1.003] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>
