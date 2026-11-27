<!-- duel status=failed -->
## yjit

### 🔻 Duel: 4 benchmarks failed

Compared 6f5003a (merged with `duel-comment-test`) with b060244 (where HEAD left `origin/duel-comment-test`).

| Benchmark | Failure | Most extra CPU in |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | cpu +41.2% | `Hash#key?` +15.7% |
| `KeepOriginalKeys: read Symbol keys as methods` | cpu +33.7% | `Hash#key?` +10.3% |
| `KeepOriginalKeys: read String keys as methods` | cpu +53.5% | `Hash#key?` +24.8% |
| `Mash: read keys as methods` | cpu +52.3% | `Hash#key?` +22.9% |

<details>
<summary>Details: 27 benchmarks in 219s, 1 unsettled</summary>

**`Mash: read keys given as Symbols as methods`**: worse cpu in every measurement

```text
cpu: 922.8ns → 1.304µs an iteration (1.41x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +15.7%  +15.7%  Hash#key?
   +10.6%  +10.6%  Hashie::Mash#convert_key
    +7.9%  +31.6%  Hashie::Mash#key?
    +1.9%  +36.7%  Method#call
    +1.7%  +34.8%  block in <top (required)>
    +0.8%  +33.1%  Hashie::Mash#method_missing
    -1.3%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read Symbol keys as methods`**: worse cpu in every measurement

```text
cpu: 862.5ns → 1.162µs an iteration (1.34x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +10.3%  +10.3%  Hash#key?
    +6.0%  +15.4%  Hashie::Mash#key?
    +4.0%  +18.3%  Hashie::Mash#method_missing
    +3.6%  +22.8%  block in <top (required)>
    +0.7%   +0.9%  Duel::Context#once
    +0.5%   +0.5%  Hash#default_proc
    +0.2%   +5.3%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +0.2%   +0.2%  Duel::Harness#once
    -0.4%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read String keys as methods`**: worse cpu in every measurement

```text
cpu: 1.444µs → 2.214µs an iteration (1.53x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +24.8%  +24.8%  Hash#key?
    +7.2%   +7.2%  Hashie::Extensions::Mash::KeepOriginalKeys#_convert
    +4.6%  +40.8%  Hashie::Mash#key?
    +4.4%  +25.5%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +2.1%  +42.3%  Hashie::Mash#method_missing
    +0.4%  +40.0%  Duel::Harness#iterate
    +0.4%   +0.4%  Duel::Harness#once
    +0.2%   +0.6%  Duel::Context#once
    +0.2%          in garbage collection, apart from the code
```

**`Mash: read keys as methods`**: worse cpu in every measurement

```text
cpu: 1.139µs → 1.738µs an iteration (1.52x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +22.9%  +22.9%  Hash#key?
    +5.4%  +38.0%  Hashie::Mash#method_missing
    +4.3%  +31.8%  Hashie::Mash#key?
    +3.9%   +3.9%  Hashie::Mash#convert_key
    +1.7%   +1.7%  Hash#[]
    +0.4%   +0.0%  Duel::Context#once
    +4.3%          in garbage collection, apart from the code
```

| Benchmark | Verdict | Timings (ratio [interval]) |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | **regressed** | cpu 1.412 [1.403, 1.422] slower |
| `KeepOriginalKeys: read Symbol keys as methods` | **regressed** | cpu 1.337 [1.307, 1.361] slower |
| `KeepOriginalKeys: read String keys as methods` | **regressed** | cpu 1.535 [1.522, 1.548] slower |
| `Mash: read keys as methods` | **regressed** | cpu 1.523 [1.511, 1.534] slower |
| `Mash: read keys with suffixes` | unsettled | cpu 1.047 [1.045, 1.051] unsettled |
| `Dash.new: required properties and defaults` | same | cpu 0.996 [0.992, 1.004] |
| `Dash: read and write properties` | same | cpu 0.998 [0.988, 1.010] |
| `Trash.new: renamed and transformed properties` | same | cpu 1.001 [0.990, 1.011] |
| `Dash.new: coerced properties` | same | cpu 1.002 [0.998, 1.006] |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 0.998 [0.994, 1.002] |
| `Dash.new: coerced nested Dashes` | same | cpu 0.995 [0.990, 1.000] |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 1.002 [0.998, 1.008] |
| `Mash.new: a flat Hash` | same | cpu 1.007 [1.004, 1.012] |
| `PermissiveRespondTo: Mash.new` | same | cpu 1.000 [0.989, 1.011] |
| `PermissiveRespondTo: write a new key as a method` | same | cpu 0.999 [0.990, 1.010] |
| `PermissiveRespondTo: overwrite a key as a method` | same | cpu 1.004 [0.993, 1.012] |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 1.001 [0.997, 1.007] |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.008 [1.004, 1.013] |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 1.004 [0.997, 1.011] |
| `DeepFind and DeepFetch: nested keys` | same | cpu 1.012 [1.008, 1.015] |
| `Mash.new: a nested JSON response` | same | cpu 1.000 [0.997, 1.004] |
| `Mash: read keys with [] and dig` | same | cpu 1.001 [0.997, 1.006] |
| `Mash: write new keys as methods` | same | cpu 0.997 [0.994, 1.000] |
| `Mash: overwrite a key as a method` | same | cpu 0.996 [0.993, 1.000] |
| `Mash: respond_to? a key, a suffix and a missing name` | same | cpu 1.005 [1.000, 1.010] |
| `Mash#deep_merge: a nested update` | same | cpu 1.002 [0.999, 1.005] |
| `Mash#to_hash: a nested Mash` | same | cpu 1.010 [1.005, 1.015] |

An unsettled timing was too close to the limit to settle. It doesn't fail the run, but one that's unsettled in run after run is noisy.

Across the board:

- cpu 1.006 [1.004, 1.007] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>

## zjit

### 🔻 Duel: 4 benchmarks failed

Compared 6f5003a (merged with `duel-comment-test`) with b060244 (where HEAD left `origin/duel-comment-test`).

| Benchmark | Failure | Most extra CPU in |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | cpu +43.9% | `Hashie::Mash#key?` +18.2% |
| `KeepOriginalKeys: read Symbol keys as methods` | cpu +44.7% | `Hashie::Mash#key?` +22.4% |
| `KeepOriginalKeys: read String keys as methods` | cpu +58.5% | `Hash#key?` +22.2% |
| `Mash: read keys as methods` | cpu +45.5% | `Hash#key?` +20.3% |

<details>
<summary>Details: 27 benchmarks in 204s</summary>

**`Mash: read keys given as Symbols as methods`**: worse cpu in every measurement

```text
cpu: 873.5ns → 1.259µs an iteration (1.44x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +18.2%  +30.3%  Hashie::Mash#key?
    +7.0%   +7.0%  Hash#key?
    +4.9%   +4.9%  Hashie::Mash#convert_key
    +4.7%  +37.1%  Hashie::Mash#method_missing
    +2.0%   +2.0%  Hashie::Mash#custom_reader
    +1.1%  +37.3%  Method#call
    +1.1%  +36.2%  block in <top (required)>
    +0.7%   +0.7%  Duel::Harness#once
    -1.1%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read Symbol keys as methods`**: worse cpu in every measurement

```text
cpu: 978.3ns → 1.408µs an iteration (1.45x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +22.4%  +32.3%  Hashie::Mash#key?
    +6.2%   +6.2%  Hash#key?
    +4.7%  +36.0%  Hashie::Mash#method_missing
    +4.3%  +43.2%  block in <top (required)>
    +2.8%   +4.3%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +2.5%   +2.8%  Duel::Context#once
    +0.9%   +0.9%  Hash#default_proc
    +0.3%   +0.3%  Duel::Harness#once
    -3.1%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read String keys as methods`**: worse cpu in every measurement

```text
cpu: 1.611µs → 2.565µs an iteration (1.59x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +22.2%  +22.2%  Hash#key?
   +12.3%  +40.5%  Hashie::Mash#key?
    +4.6%   +4.6%  Hashie::Extensions::Mash::KeepOriginalKeys#_convert
    +3.2%  +40.8%  Hashie::Mash#method_missing
    +2.5%  +44.4%  block in <top (required)>
    +1.4%   +1.1%  Duel::Context#once
    +1.4%   +1.4%  Hash#default_proc
    +0.4%  +18.7%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +3.2%          in garbage collection, apart from the code
```

**`Mash: read keys as methods`**: worse cpu in every measurement

```text
cpu: 1.119µs → 1.633µs an iteration (1.46x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +20.3%  +20.3%  Hash#key?
   +13.3%  +45.4%  Hashie::Mash#key?
   +13.1%  +12.9%  Hashie::Mash#convert_key
    +4.1%  +53.1%  Hashie::Mash#method_missing
    +2.9%   +2.9%  Hash#[]
    +0.5%  +46.9%  Method#call
    +0.2%   +3.6%  Hashie::Mash#custom_reader
    -0.9%          in garbage collection, apart from the code
```

| Benchmark | Verdict | Timings (ratio [interval]) |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | **regressed** | cpu 1.439 [1.424, 1.454] slower |
| `KeepOriginalKeys: read Symbol keys as methods` | **regressed** | cpu 1.447 [1.429, 1.467] slower |
| `KeepOriginalKeys: read String keys as methods` | **regressed** | cpu 1.585 [1.566, 1.606] slower |
| `Mash: read keys as methods` | **regressed** | cpu 1.455 [1.438, 1.475] slower |
| `Dash.new: required properties and defaults` | same | cpu 1.005 [0.993, 1.018] |
| `Dash: read and write properties` | same | cpu 1.000 [0.988, 1.014] |
| `Trash.new: renamed and transformed properties` | same | cpu 0.999 [0.988, 1.010] |
| `Dash.new: coerced properties` | same | cpu 1.001 [0.995, 1.008] |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 1.000 [0.992, 1.006] |
| `Dash.new: coerced nested Dashes` | same | cpu 1.004 [0.997, 1.012] |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 0.995 [0.985, 1.003] |
| `Mash.new: a flat Hash` | same | cpu 0.994 [0.987, 1.002] |
| `PermissiveRespondTo: Mash.new` | same | cpu 1.001 [0.989, 1.013] |
| `PermissiveRespondTo: write a new key as a method` | same | cpu 0.999 [0.988, 1.010] |
| `PermissiveRespondTo: overwrite a key as a method` | same | cpu 1.002 [0.987, 1.015] |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 1.008 [1.003, 1.014] |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.062 [1.051, 1.072] slower |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 0.978 [0.968, 0.986] |
| `DeepFind and DeepFetch: nested keys` | same | cpu 1.004 [0.991, 1.013] |
| `Mash.new: a nested JSON response` | same | cpu 0.998 [0.988, 1.006] |
| `Mash: read keys with suffixes` | same | cpu 1.031 [1.021, 1.043] |
| `Mash: read keys with [] and dig` | same | cpu 1.002 [0.993, 1.010] |
| `Mash: write new keys as methods` | same | cpu 0.996 [0.986, 1.005] |
| `Mash: overwrite a key as a method` | same | cpu 0.990 [0.986, 0.995] |
| `Mash: respond_to? a key, a suffix and a missing name` | same | cpu 1.002 [0.989, 1.015] |
| `Mash#deep_merge: a nested update` | same | cpu 0.994 [0.987, 1.000] |
| `Mash#to_hash: a nested Mash` | same | cpu 0.998 [0.990, 1.006] |

Across the board:

- cpu 1.005 [1.002, 1.008] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>

