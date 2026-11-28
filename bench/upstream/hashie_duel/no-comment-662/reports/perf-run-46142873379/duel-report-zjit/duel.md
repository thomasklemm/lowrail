### 🟢 Duel: 100% of benchmarks passed

Compared 6b6f67b (merged with `master`) with 277e88e (where HEAD left `origin/master`).

<details>
<summary>Details: 27 benchmarks in 111s</summary>

| Benchmark | Verdict | Timings (ratio [interval]) |
|---|---|---|
| `Mash#to_hash: a nested Mash` | faster | cpu 0.689 [0.681, 0.697] faster |
| `Dash.new: required properties and defaults` | same | cpu 1.005 [0.998, 1.011] |
| `Dash: read and write properties` | same | cpu 0.998 [0.989, 1.007] |
| `Trash.new: renamed and transformed properties` | same | cpu 0.999 [0.991, 1.009] |
| `Dash.new: coerced properties` | same | cpu 1.006 [0.999, 1.012] |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 1.004 [0.995, 1.011] |
| `Dash.new: coerced nested Dashes` | same | cpu 1.005 [0.998, 1.011] |
| `Mash: read keys given as Symbols as methods` | same | cpu 1.022 [1.016, 1.027] |
| `KeepOriginalKeys: read Symbol keys as methods` | same | cpu 1.008 [0.993, 1.024] |
| `KeepOriginalKeys: read String keys as methods` | same | cpu 1.009 [0.995, 1.022] |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 1.002 [1.000, 1.004] |
| `Mash.new: a flat Hash` | same | cpu 1.005 [0.998, 1.013] |
| `PermissiveRespondTo: Mash.new` | same | cpu 0.993 [0.986, 1.001] |
| `PermissiveRespondTo: write a new key as a method` | same | cpu 0.999 [0.988, 1.006] |
| `PermissiveRespondTo: overwrite a key as a method` | same | cpu 0.996 [0.989, 1.002] |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 0.999 [0.994, 1.004] |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.016 [1.008, 1.023] |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 0.997 [0.985, 1.010] |
| `DeepFind and DeepFetch: nested keys` | same | cpu 1.016 [1.006, 1.024] |
| `Mash.new: a nested JSON response` | same | cpu 0.992 [0.987, 0.999] |
| `Mash: read keys as methods` | same | cpu 1.029 [1.021, 1.037] |
| `Mash: read keys with suffixes` | same | cpu 0.993 [0.988, 0.997] |
| `Mash: read keys with [] and dig` | same | cpu 1.002 [0.996, 1.007] |
| `Mash: write new keys as methods` | same | cpu 1.009 [1.005, 1.013] |
| `Mash: overwrite a key as a method` | same | cpu 0.996 [0.991, 1.000] |
| `Mash: respond_to? a key, a suffix and a missing name` | same | cpu 0.959 [0.950, 0.966] |
| `Mash#deep_merge: a nested update` | same | cpu 0.996 [0.991, 1.002] |

Across the board:

- cpu 1.001 [0.999, 1.003] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>
