<!-- duel status=failed -->
## yjit

### 🔻 Duel: 4 benchmarks failed

Compared a2f1493 (merged with `duel-matrix-test`) with 62f869a (where HEAD left `origin/duel-matrix-test`).

| Benchmark | Failure | Most extra CPU in |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | cpu +41.2% | `Hash#key?` +16.5% |
| `KeepOriginalKeys: read Symbol keys as methods` | cpu +31.5% | `Hash#key?` +7.3% |
| `KeepOriginalKeys: read String keys as methods` | cpu +53.9% | `Hash#key?` +21.6% |
| `Mash: read keys as methods` | cpu +50.8% | `Hash#key?` +25.0% |

<details>
<summary>Details: 27 benchmarks in 215s</summary>

**`Mash: read keys given as Symbols as methods`**: worse cpu in every measurement

```text
cpu: 893.6ns → 1.262µs an iteration (1.41x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +16.5%  +16.5%  Hash#key?
    +7.9%   +7.9%  Hashie::Mash#convert_key
    +5.4%  +28.1%  Hashie::Mash#key?
    +3.4%  +32.6%  Hashie::Mash#method_missing
    +2.4%  +34.7%  block in <top (required)>
    +1.9%  +36.6%  Method#call
    +0.8%  +37.3%  Duel::Harness#iterate
    +0.8%   +1.1%  Hashie::Mash#custom_reader
    -0.9%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read Symbol keys as methods`**: worse cpu in every measurement

```text
cpu: 832.2ns → 1.089µs an iteration (1.31x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
    +7.3%   +7.3%  Hash#key?
    +5.5%  +13.9%  Hashie::Mash#key?
    +4.4%  +18.4%  Hashie::Mash#method_missing
    +1.1%  +19.2%  Method#call
    +0.5%   +3.3%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +0.4%  +19.5%  Duel::Harness#iterate
    +0.4%  +18.1%  block in <top (required)>
    +0.4%   +0.2%  Hashie::Mash#custom_reader
```

**`KeepOriginalKeys: read String keys as methods`**: worse cpu in every measurement

```text
cpu: 1.396µs → 2.146µs an iteration (1.54x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +21.6%  +21.6%  Hash#key?
    +7.9%   +7.9%  Hashie::Extensions::Mash::KeepOriginalKeys#_convert
    +4.0%  +37.1%  Hashie::Mash#key?
    +2.2%  +21.6%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +2.0%  +41.8%  block in <top (required)>
    +1.6%   +1.6%  Hash#[]
    +1.1%  +39.3%  Hashie::Mash#method_missing
    +0.7%   +1.1%  Hashie::Mash#custom_reader
    +2.5%          in garbage collection, apart from the code
```

**`Mash: read keys as methods`**: worse cpu in every measurement

```text
cpu: 1.115µs → 1.68µs an iteration (1.51x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +25.0%  +25.0%  Hash#key?
    +8.7%  +49.2%  block in <top (required)>
    +5.7%  +35.2%  Hashie::Mash#key?
    +4.9%   +4.9%  Hash#[]
    +3.1%   +3.1%  Hashie::Mash#convert_key
    +2.2%  +40.7%  Hashie::Mash#method_missing
    +2.0%  +51.2%  Method#call
    +0.2%   +0.2%  Hash#default_proc
   -12.6%          in garbage collection, apart from the code
```

| Benchmark | Verdict | Timings (ratio [interval]) |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | **regressed** | cpu 1.412 [1.397, 1.424] slower |
| `KeepOriginalKeys: read Symbol keys as methods` | **regressed** | cpu 1.315 [1.299, 1.343] slower |
| `KeepOriginalKeys: read String keys as methods` | **regressed** | cpu 1.539 [1.524, 1.556] slower |
| `Mash: read keys as methods` | **regressed** | cpu 1.508 [1.499, 1.520] slower |
| `Dash.new: required properties and defaults` | same | cpu 0.994 [0.989, 1.000] |
| `Dash: read and write properties` | same | cpu 0.997 [0.980, 1.004] |
| `Trash.new: renamed and transformed properties` | same | cpu 0.999 [0.990, 1.007] |
| `Dash.new: coerced properties` | same | cpu 1.003 [1.000, 1.006] |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 1.000 [0.995, 1.005] |
| `Dash.new: coerced nested Dashes` | same | cpu 0.995 [0.991, 0.998] |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 1.002 [0.998, 1.005] |
| `Mash.new: a flat Hash` | same | cpu 1.006 [1.003, 1.009] |
| `PermissiveRespondTo: Mash.new` | same | cpu 0.990 [0.977, 1.005] |
| `PermissiveRespondTo: write a new key as a method` | same | cpu 0.999 [0.988, 1.010] |
| `PermissiveRespondTo: overwrite a key as a method` | same | cpu 1.001 [0.995, 1.008] |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 1.002 [0.998, 1.005] |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.006 [1.000, 1.012] |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 1.001 [0.997, 1.006] |
| `DeepFind and DeepFetch: nested keys` | same | cpu 1.008 [1.002, 1.013] |
| `Mash.new: a nested JSON response` | same | cpu 1.000 [0.997, 1.003] |
| `Mash: read keys with suffixes` | same | cpu 1.047 [1.045, 1.049] |
| `Mash: read keys with [] and dig` | same | cpu 1.000 [0.995, 1.005] |
| `Mash: write new keys as methods` | same | cpu 0.998 [0.994, 1.002] |
| `Mash: overwrite a key as a method` | same | cpu 0.997 [0.994, 1.000] |
| `Mash: respond_to? a key, a suffix and a missing name` | same | cpu 1.005 [0.998, 1.009] |
| `Mash#deep_merge: a nested update` | same | cpu 1.002 [0.998, 1.005] |
| `Mash#to_hash: a nested Mash` | same | cpu 1.005 [0.999, 1.010] |

Across the board:

- cpu 1.004 [1.002, 1.006] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>

## zjit

### 🔻 Duel: 4 benchmarks failed

Compared a2f1493 (merged with `duel-matrix-test`) with 62f869a (where HEAD left `origin/duel-matrix-test`).

| Benchmark | Failure | Most extra CPU in |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | cpu +44.0% | `Hashie::Mash#key?` +17.6% |
| `KeepOriginalKeys: read Symbol keys as methods` | cpu +45.1% | `Hashie::Mash#key?` +16.4% |
| `KeepOriginalKeys: read String keys as methods` | cpu +60.2% | `Hash#key?` +12.7% |
| `Mash: read keys as methods` | cpu +50.9% | `Hashie::Mash#key?` +19.3% |

<details>
<summary>Details: 27 benchmarks in 209s, 1 unsettled</summary>

**`Mash: read keys given as Symbols as methods`**: worse cpu in every measurement

```text
cpu: 1.394µs → 2.007µs an iteration (1.44x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +17.6%  +29.4%  Hashie::Mash#key?
    +8.7%   +8.7%  Hash#key?
    +5.6%  +40.6%  Hashie::Mash#method_missing
    +4.3%   +4.3%  Hashie::Mash#convert_key
    +2.7%   +5.6%  Hashie::Mash#custom_reader
    +1.9%   +1.9%  Hash#[]
    +1.2%  +43.5%  Method#call
    +1.2%   +1.4%  Duel::Context#once
    -8.3%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read Symbol keys as methods`**: worse cpu in every measurement

```text
cpu: 1.566µs → 2.279µs an iteration (1.45x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +16.4%  +23.4%  Hashie::Mash#key?
    +6.6%   +6.6%  Hash#key?
    +5.2%  +29.9%  Hashie::Mash#method_missing
    +4.1%  +33.6%  block in <top (required)>
    +1.3%   +1.3%  Hashie::Mash#custom_reader
    +0.9%   +3.3%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    -0.4%          in garbage collection, apart from the code
```

**`KeepOriginalKeys: read String keys as methods`**: worse cpu in every measurement

```text
cpu: 2.27µs → 3.657µs an iteration (1.60x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +12.7%  +12.7%  Hash#key?
   +12.2%  +38.4%  Hashie::Mash#key?
    +7.3%   +7.3%  Hashie::Extensions::Mash::KeepOriginalKeys#_convert
    +4.3%  +39.7%  Hashie::Mash#method_missing
    +3.2%  +18.4%  Hashie::Extensions::Mash::KeepOriginalKeys#convert_key
    +2.2%  +42.7%  block in <top (required)>
    +0.8%  +43.5%  Method#call
    +0.8%   +0.8%  Hash#[]
    +2.4%          in garbage collection, apart from the code
```

**`Mash: read keys as methods`**: worse cpu in every measurement

```text
cpu: 1.586µs → 2.411µs an iteration (1.51x)
where the extra CPU went (as a share of the baseline's: in each frame itself, and with what it called):
   +19.3%  +49.1%  Hashie::Mash#key?
   +13.1%  +13.1%  Hash#key?
   +12.6%  +15.2%  Hashie::Mash#convert_key
    +2.6%   +2.6%  Kernel#is_a?
    +1.9%  +49.5%  Hashie::Mash#method_missing
    +0.7%   -1.6%  Hashie::Mash#custom_reader
    +0.3%  +48.6%  Method#call
    +0.2%  +48.3%  block in <top (required)>
```

| Benchmark | Verdict | Timings (ratio [interval]) |
|---|---|---|
| `Mash: read keys given as Symbols as methods` | **regressed** | cpu 1.440 [1.408, 1.459] slower |
| `KeepOriginalKeys: read Symbol keys as methods` | **regressed** | cpu 1.451 [1.426, 1.474] slower |
| `KeepOriginalKeys: read String keys as methods` | **regressed** | cpu 1.602 [1.550, 1.648] slower |
| `Mash: read keys as methods` | **regressed** | cpu 1.509 [1.485, 1.539] slower |
| `Mash: read keys with suffixes` | unsettled | cpu 1.059 [1.044, 1.072] unsettled |
| `Dash.new: required properties and defaults` | same | cpu 0.986 [0.964, 1.004] |
| `Dash: read and write properties` | same | cpu 0.996 [0.978, 1.016] |
| `Trash.new: renamed and transformed properties` | same | cpu 0.996 [0.979, 1.013] |
| `Dash.new: coerced properties` | same | cpu 0.992 [0.977, 1.005] |
| `Dash.new: String keys with IndifferentAccess` | same | cpu 1.002 [0.989, 1.014] |
| `Dash.new: coerced nested Dashes` | same | cpu 1.011 [0.998, 1.023] |
| `PermissiveRespondTo: include in a Mash subclass` | same | cpu 1.002 [0.980, 1.024] |
| `Mash.new: a flat Hash` | same | cpu 1.004 [0.988, 1.023] |
| `PermissiveRespondTo: Mash.new` | same | cpu 1.009 [0.983, 1.034] |
| `PermissiveRespondTo: write a new key as a method` | same | cpu 1.003 [0.987, 1.023] |
| `PermissiveRespondTo: overwrite a key as a method` | same | cpu 0.999 [0.980, 1.022] |
| `IndifferentAccess: new from a nested JSON response` | same | cpu 1.005 [0.997, 1.017] |
| `IndifferentAccess: read String and Symbol keys` | same | cpu 1.006 [0.993, 1.023] |
| `IndifferentAccess: write String and Symbol keys` | same | cpu 0.983 [0.966, 0.993] |
| `DeepFind and DeepFetch: nested keys` | same | cpu 1.007 [0.990, 1.027] |
| `Mash.new: a nested JSON response` | same | cpu 0.996 [0.986, 1.007] |
| `Mash: read keys with [] and dig` | same | cpu 1.000 [0.991, 1.010] |
| `Mash: write new keys as methods` | same | cpu 1.003 [0.998, 1.020] |
| `Mash: overwrite a key as a method` | same | cpu 1.010 [0.997, 1.025] |
| `Mash: respond_to? a key, a suffix and a missing name` | same | cpu 0.985 [0.973, 1.001] |
| `Mash#deep_merge: a nested update` | same | cpu 0.996 [0.984, 1.007] |
| `Mash#to_hash: a nested Mash` | same | cpu 0.996 [0.977, 1.015] |

An unsettled timing was too close to the limit to settle. It doesn't fail the run, but one that's unsettled in run after run is noisy.

Across the board:

- cpu 1.008 [1.004, 1.012] same (limit 1.0125, 27 benchmarks)

A timing is slower when a 99.0% confidence interval for its ratio, the candidate's to the baseline's, is above 1.02. [How Duel decides](https://github.com/sferik/duel-ruby/blob/main/docs/how-it-works.md#how-duel-tells-a-regression-from-noise)

</details>

