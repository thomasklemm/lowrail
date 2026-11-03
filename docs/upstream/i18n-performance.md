# i18n performance evaluation (bet I18N)

Ruby 4.0.7, i18n master [`a0a416e570`](https://github.com/ruby-i18n/i18n/commit/a0a416e570fd4998993bde1b5533d0a038bebaf7)
(1.15.2 plus CI changes), Rails main `5810776eec` for the Rails-side micros, and the census pin `3bdc579090` for the apps.
This builds on [gem-census.md](gem-census.md): i18n is the largest gem in the census, at 248 objects per workload,
2.45% of all allocations, in 19 of 20 apps. Almost all of that is in `Backend::Fallbacks`, which every app with
`config.i18n.fallbacks` runs.

**Result.** Here is what a translation costs on i18n master with `Backend::Fallbacks`: `I18n.t(:hello)` allocates 13 objects
and runs 54k instructions. `errors.full_messages` with two errors allocates 527 objects, nearly all in i18n.

* **CPU:** `I18n.config` is the largest single cost. It runs about five times per translation and makes up about 18% of
  the instructions. The other large costs are `normalize_keys` (14%), the available-locale check (11%) and interpolation
  (about a third of `I18n.t(:greet, name:)`).
* **Allocations:** they are all in the fallback, default and options-Hash plumbing; the lookup itself allocates
  nothing.

Four new exact candidates are on [thomasklemm/i18n](https://github.com/thomasklemm/i18n). None duplicates #763 (I1),
#764 (I2) or #758. They merge cleanly with each other, with those three and with #759. The suite passes on all of them
together: 1,628 runs.

| # | Branch @ SHA | Per call | Census (10 apps, interpreter / YJIT) |
| --- | --- | --- | --- |
| **C1** | [`thomasklemm/fallback-options-without-merge-kwargs`](https://github.com/thomasklemm/i18n/tree/thomasklemm/fallback-options-without-merge-kwargs) [`38dc6cff84`](https://github.com/thomasklemm/i18n/commit/38dc6cff841b81be46d6b4ccf29a25c7fc3b0824) | −1 object per translation (`t(:hello)` 13 → 12); −4.3% instructions | **−47.3 / −47.3 objects per workload, 0.38% of all allocations, 10 of 10 apps**; A/A −0.5 / +0.0 |
| C2 | [`thomasklemm/resolve-symbols-without-merge`](https://github.com/thomasklemm/i18n/tree/thomasklemm/resolve-symbols-without-merge) [`3bef11d6e3`](https://github.com/thomasklemm/i18n/commit/3bef11d6e3d174a1666fa5c73ed57b6159c08e25) | −2 per Symbol default, −5 per Symbol link; `full_messages` (2 errors) 527 → 499 | −2.5 / −2.0, 4 / 3 apps (Blog −17.2) |
| C3 | [`thomasklemm/lookup-symbol-miss`](https://github.com/thomasklemm/i18n/tree/thomasklemm/lookup-symbol-miss) [`b82af9eeae`](https://github.com/thomasklemm/i18n/commit/b82af9eeae49d8fd0d018c3494fca37fa5229bc7) | −1 String per missing key segment; `full_messages` 527 → 509 | −2.3 / −1.7, 5 apps (Blog −13.2) |
| **C4** | [`thomasklemm/fiber-storage-check-once`](https://github.com/thomasklemm/i18n/tree/thomasklemm/fiber-storage-check-once) [`dd3d1e05f6`](https://github.com/thomasklemm/i18n/commit/dd3d1e05f6f32fa29555881cd93c579e0bdab203) | CPU only: −4.1% instructions per `t(:hello)`, −2.9% to −3.6% on the other cases | no allocation change, as expected (i18n lines −0.5 / +0.0, the same as the A/A) |

C1 is the census lead `fallbacks.rb:54`, the largest gem site. C4 is the largest CPU item that can be made exact
cheaply. C2 and C3 are exact, but they only matter on paths that miss or resolve Symbols, such as validation messages,
`human_attribute_name` misses and Symbol links. The census apps rarely render those, so I'd queue C1 and C4 first.
With #763 and #764 open, the three-PR limit leaves one slot, so **C1 is next**.

## Method

* **Micros:**
  * [`bench/upstream/i18n/sites.rb`](../../bench/upstream/i18n/sites.rb): 22 `I18n` cases (keys, scopes,
    interpolation, pluralization, links, fallbacks, defaults, `exists?`, `l`, `locale`, `with_locale`), with and without
    `Backend::Fallbacks`. It prints objects and ns per call; `--sites` adds allocation sites and `--cpu` adds stackprof
    frames. `--calls=N` is for Callgrind.
  * [`bench/upstream/i18n/rails_sites.rb`](../../bench/upstream/i18n/rails_sites.rb): the Rails paths, which are view
    `t`/`l`, `number_to_currency`, `human_attribute_name`, `model_name.human`, `errors.full_messages` and `errors.add`.
* **Instructions:** [`ir.sh`](../../bench/upstream/i18n/ir.sh) with [`setup_fallbacks.rb`](../../bench/upstream/i18n/setup_fallbacks.rb). Callgrind `Ir` per call is `(Ir(N calls) − Ir(0 calls)) / N` after 500 warm-up calls, with N = 4,000
  or 5,000. The **A/A** is master against master in the same batch. It differs by at most 170 instructions per call
  (≤0.3%), so changes of 1% or more are real.
* **Census:** [`runs.sh`](../../bench/upstream/i18n/runs.sh), which runs `script/census run --gem i18n=…` on the ten apps that translate most: Sure, Docuseal, Discourse, Casa,
  Loomio, Mastodon, Lobsters, Blog, CodeTriage and PingCRM. Both modes ran, 111 workloads, on the census copies from
  the gem census (Rails `5810776eec`).
  * Base `ib` and its A/A twin `ib2` pin i18n master `a0a416e570`, and `c1`…`c4` pin the candidates.
  * Deltas use [`gem_delta.rb`](../../bench/upstream/gem_census/gem_delta.rb) on i18n's own lines.
  * The candidate runs were taken one after another on one orb, with the micros running at the same time, so the
    ns columns are indicative only. Instruction counts and allocations are not affected by load.

## Where a translation goes

### CPU (Callgrind, instructions per call, Fallbacks backend)

| Piece | Instructions | Share of `t(:hello)` (53.8k) |
| --- | ---: | ---: |
| `I18n.config` (each call; about 5 per translation) | 2.0k | ~18% |
| ⤷ of which `Fiber.respond_to?(:[])` | 0.4k | ~4% (C4) |
| `I18n.normalize_keys(:en, :hello, nil)` (cache hit) | 7.5k | 14% |
| `enforce_available_locales!` (`config` twice plus a Set lookup) | 6.1k | 11% |
| `I18n.fallbacks[:en]` | 2.7k | 5% |
| `I18n.locale` | 3.1k | – |

| Case | master | A/A | C1 | C2 | C3 | C4 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `t(:hello)` | 53,783 | 53,828 | 51,489 (−4.3%) | 53,819 | 53,848 | 51,569 (−4.1%) |
| `t(:greet, name:)` | 81,020 | 81,112 | 79,779 (−1.5%) | 81,121 | 81,004 | 78,529 (−3.1%) |
| `human_attribute_name` miss | 135,755 | 135,925 | 134,953 (−0.6%) | 134,678 (−0.8%) | 135,123 (−0.5%) | 131,746 (−3.0%) |
| `t(:link)` (Symbol link) | 111,562 | 111,628 | 109,069 (−2.2%) | 107,478 (−3.7%) | 111,706 | 107,522 (−3.6%) |
| String default, missing key | 73,731 | 73,796 | 72,676 (−1.4%) | 73,680 | 72,751 (−1.3%) | 71,595 (−2.9%) |

All four candidates together with I1, I2 and #758: `t(:hello)` 53,783 → 47,436 instructions (−11.8%) and
`t(:greet, name:)` 81,020 → 74,494 (−8.1%).

Wall time, median ns per call over 7 batches, two alternating rounds on the otherwise idle orb:

| Case | master | C1 | C4 | all + I1 + I2 + #758 |
| --- | --- | --- | --- | --- |
| `t(:hello)`, interpreter | 6257 / 6390 | 6242 / 6260 | 6068 / 6156 | 5776 / 5525 |
| `t(:hello)`, YJIT | 3325 / 3315 | 3167 / 3108 | 3532 / 3305 | 2857 / 2824 |
| `human_attribute_name` miss, interpreter | 19261 / 18265 | 17976 / 18420 | 17824 / 17389 | 16585 / 16395 |

A single candidate is within the round-to-round noise of about 5%, so the instruction counts above carry the per-call
claim. The combined set is 10% to 15% faster.

Stackprof, CPU mode at 20 µs, self time on `t(:hello)`:

| Frame | Self time |
| --- | ---: |
| `Base#translate` | 13% |
| `Fallbacks#translate` | 11% |
| `Simple#lookup` | 9% |
| sweeping | 5% |
| `Fallbacks#resolve_entry` | 4% |
| `normalize_keys` | 4% (11% total) |
| `config` | 3% (8% total) |

On `t(:greet, name:)`, `I18n.interpolate` makes up 36% of the total: the `reserved_keys_pattern` check, then `gsub`
with a block. A TracePoint shows 142 method calls for one `t(:hello)`: 17 `Hash#[]`, 11 `respond_to?`, 11 `is_a?`,
6 `Fiber[]`, 5 `config`, 5 `Fiber.current` and 5 `owned_by?`.

### Allocations (objects per call, interpreter = YJIT)

| Case | master | without Fallbacks | C1 | C2 | C3 | all 4 + I1 + I2 + #758 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `t(:hello)` | 13 | 6 | 12 | 13 | 13 | 9 |
| `t(:greet, name:)` | 21 | 16 | 20 | 21 | 21 | 17 |
| `t('inbox.messages', count: 3)` | 20 | 15 | 19 | 20 | 20 | 16 |
| `t(:link)` (Symbol link) | 32 | 20 | 30 | 27 | 32 | 19 |
| `t(:only_en, locale: :de)` (falls back) | 21 | 14 | 20 | 21 | 20 | 18 |
| String default, missing key | 23 | 11 | 22 | 23 | 22 | 18 |
| Symbol default, missing key | 29 | 21 | 28 | 27 | 28 | 19 |
| `human_attribute_name` hit | 21 | 11 | 20 | 21 | 21 | 17 |
| `human_attribute_name` miss | 36 | 26 | 35 | 34 | 35 | 28 |
| `l(date, format: :long)` | 37 | 27 | 35 | 37 | 37 | 29 |
| `l(time)` | 52 | 37 | 49 | 52 | 52 | 40 |
| Rails `errors.full_messages` (2 errors) | 527 | – | 515 | 499 | 509 | 441 |
| Rails `errors.add(:title, :blank)` | 181 | – | 177 | 169 | 174 | 148 |
| Rails view `t('.title')` | 19 | – | 18 | 19 | 19 | 13 |

`I18n.locale`, `with_locale` and `exists?` allocate nothing or close to nothing (0, 0 and 5). Fallbacks alone more than
doubles the cost of a plain hit, from 6 to 13 objects.

### Ranked sites

Census `ib` covers the ten apps, 111 workloads, interpreter, i18n's own lines. Apps is how many of the ten apps reach
the site.

| # | Site | Apps | Objects/workload | Disposition |
| --- | --- | ---: | ---: | --- |
| 1 | `backend/fallbacks.rb:54` `options.merge(:fallback_in_progress => true, …)` | 10 | 94.7 | **C1** removes half (the keyword Hash); the copy itself is what `super` receives |
| 2 | `backend/fallbacks.rb:60` `locale.to_s != fallback.to_s` | 10 | 91.8 | I1, #763 |
| 3 | `backend/fallbacks.rb:98` `[options[:default]].flatten` | 10 | 73.6 | I2, #764 |
| 4 | `utils.rb:8` `hash.except(*keys)` | 10 | 48.8 | Required: the interpolation values |
| 5 | `i18n.rb:396` `normalize_keys` | 10 | 48.3 | Lead (see below) |
| 6 | `backend/base.rb:58` rest Array | 10 | 47.3 | #758 |
| 7 | `backend/fallbacks.rb:101` `defaults[0, index]` | 10 | 36.6 | I2, #764 |
| 8 | `backend/base.rb:49` `entry.dup` | 10 | 25.1 | Required: the caller's String |
| 9 | `interpolate/ruby.rb:33`, `:39` `gsub` | 10 | 19.0 | Required: the result |
| 10 | `backend/base.rb:290` localize `gsub` | 4 | 17.0 | Required: the format |
| 11 | `backend/base.rb:87`, `:88`, `i18n.rb:261` localize options | 4 | 14.4 | #759 |
| 12 | `backend/base.rb:155`, `:157`, `simple.rb:104` (resolve a Symbol) | 4 | 3.0 | **C2** |
| 13 | `backend/simple.rb:100` `_key.to_s.to_sym` | 6 | 1.8 | **C3** |
| 14 | `exceptions.rb:53`, `base.rb:45`, `fallbacks.rb:71/72` (`MissingTranslation` on a miss) | 6 | 5.0 | Lead (see below) |

On the Rails side, i18n's callers are smaller:

| Site | Apps | Objects/workload |
| --- | ---: | ---: |
| `html_safe_translation.rb:26` `I18n.translate(key, **options)` | 6 | 13.8 |
| `translation_helper.rb:104` `**options, default:` | 6 | 12.8 |
| `active_model/translation.rb:40`, `:74`, `:75`, `:81` (`human_attribute_name`) | 3 | <1 |
| `errors.rb:127` (required) | – | – |

Each is one keyword Hash per hop, required by the keyword signatures.

## Candidates

### C1: build the fallback options without a keyword Hash

`Fallbacks#translate` copies the options with `options.merge(:fallback_in_progress => true, fallback_original_locale:
locale)`. The two keywords become a Hash, and `merge` copies the options into a second Hash. The candidate copies with
`options.merge` (no arguments) and then stores the two keys.

**Exactness.** I compared the old and new form on plain, frozen, empty, defaulted, `default_proc`, `compare_by_identity`,
instance-variable and subclass Hashes, and on Hashes that already have `false` flags. Class, contents, key order,
default, default proc, identity and frozenness are all the same. `options.dup` would also save the object, but it calls
`initialize_copy` on Hash subclasses, which `merge` does not. That is why the candidate uses `merge`.

**Test.** A recording module sits between `Fallbacks` and `Simple`. It checks four things: the first fallback receives
`{…, fallback_original_locale:, fallback_in_progress: true}` in the old key order, every fallback sees the requested
locale, and frozen caller options stay unchanged. The test is a guard, so it also passes on master.

Suite: 1,608 runs, 0 failures.

**Numbers.** −1 object on every translation that goes through Fallbacks, and −2 on `l`, which translates twice.
Instructions: −4.3% on `t(:hello)`. Census:

| App | i18n objects/op | C1 | A/A |
| --- | ---: | ---: | ---: |
| sure | 4662.9 | −429.7 / −429.0 | −6.7 / +0.0 |
| docuseal | 497.7 | −43.4 / −43.4 | +0.0 / +0.0 |
| discourse | 321.5 | −22.5 / −22.5 | +0.0 / +0.0 |
| casa | 259.8 | −18.8 / −18.8 | +0.0 / +0.0 |
| lobsters | 122.9 | −11.8 / −11.8 | +0.0 / +0.0 |
| blog | 160.3 | −6.0 / −6.0 | +0.0 / +0.0 |
| loomio | 54.2 | −5.7 / −5.7 | +0.0 / +0.0 |
| codetriage | 28.6 | −1.9 / −1.9 | +0.0 / +0.0 |
| mastodon | 19.3 | −1.7 / −1.7 | +0.0 / +0.0 |
| pingcrm | 27.2 | −1.0 / −1.0 | +0.0 / +0.0 |
| **All (10, 111 workloads)** | 540.5 | **−47.3 / −47.3** | −0.5 / +0.0 |

That is 0.38% of all allocations in these ten apps. The change in all allocations agrees: −64.2 / −43.4, against an
A/A of +1.4 / +3.2.

### C2: resolve Symbol defaults and links without merging the options

`Base#resolve` and `Fallbacks#resolve_entry` call `I18n.translate(subject, **options.merge(locale:, throw: true,
skip_interpolation: true))`, which builds a keyword Hash and a merged Hash and then splats them. The candidate passes
`**options, locale: …, throw: true, skip_interpolation: true`: the same keywords, with the explicit ones still winning.
Separately, `Simple#lookup` builds a link's options with `Utils.except(options.merge(:scope => nil), :count)`, and the
candidate replaces that with `options.except(:count)` followed by `[:scope] = nil`, which gives the same Hash and key
order.

**Exactness.** One difference is accepted. If the caller's options Hash is `compare_by_identity`, the nested
`I18n.translate` now receives a normal keyword Hash, because Ruby only passes an identity Hash through when it is the
only splat. The nested call reads only Symbol keys from it, and for Symbol keys identity and `eql?` agree. Everything
else is identical, including String keys and keys that override.

**Test.** A new shared API test for links (`lib/i18n/tests/link.rb`): a link with `count:` and `scope:` drops both and
keeps the interpolation values, including with frozen options. It runs on every backend. Suite: 1,615 runs, 0 failures.

**Numbers.** Per call: Symbol link 32 → 27, Symbol default miss 29 → 27, `human_attribute_name` miss 36 → 34, Rails
`errors.full_messages` (2 errors) 527 → 499, `errors.add` 181 → 169. Instructions: −3.7% on a link. In the census, only
Blog's invalid-form workloads gain (−17.2 per workload); the total is −2.5 / −2.0 in 4 / 3 apps, against an A/A of
−0.5 / +0.0. The census apps rarely render validation errors, so this is a smaller, path-specific win.

### C3: return early in `Simple#lookup` when a Symbol key is missing

When a key segment is missing, `lookup` retries with `_key.to_s.to_sym`, so that Integer and boolean segments (which
`normalize_key` produces from `"1"`, `"true"`) also find translations stored under `:"1"` and `:true`. For a Symbol, the
retry is the same key, and `to_s` allocates a String. The candidate returns `nil` first when the key is a Symbol.

**Exactness.** The second `has_key?` sees the same Symbol and gives the same answer. Translations stored with
`skip_symbolize_keys` (String keys) were never found by either form.

**Test.** `Simple` test: numeric and boolean segments still find `:"2"` and `:true`, and missing Symbol segments
(including one under a String leaf) return `nil` or a missing translation. Suite: 1,609 runs, 0 failures.

**Numbers.** −1 per missing segment: the fallback miss 21 → 20, String default 23 → 22, `full_messages` 527 → 509,
`errors.add` 181 → 174. Instructions: −1.3% on a String default miss. Census: −2.3 / −1.7 objects per workload in 5 apps (Blog −13.2, PingCRM −2.5, Casa −2.3, CodeTriage −0.9; Sure −7.8 in the interpreter is within its A/A of −6.7), against an A/A of −0.5 / +0.0.

### C4: check for Fiber storage once on Rubies that have it

Since #731 and #739, `I18n.config`, `writable_config`, `config=`, `I18n.fallbacks`, `fallbacks=` and the middleware
check `Fiber.respond_to?(:[])` on every call. That check keeps 1.15.2 working on Ruby 3.1 and JRuby 9.4, which lack
`Fiber[]`. A translation reads `config` about five times and `fallbacks` once. The candidate records `FIBER_STORAGE =
Fiber.respond_to?(:[])` when i18n loads, as a private constant, and tests `FIBER_STORAGE || Fiber.respond_to?(:[])`.

**Exactness.** On Ruby 3.2+, `Fiber[]` is core and stays defined. On Rubies without it, every call still checks, so a
`Fiber[]` that something defines later is used as before (for example the `fiber-storage` gem, if it is loaded after
i18n). The only difference would come from removing `Fiber.[]` at runtime on 3.2+.

**Test.** The test stubs `FIBER_STORAGE` to `false` on a Ruby with `Fiber[]` and checks that `I18n.locale=` still writes
to Fiber storage. It fails on the constant-only variant. Suite: 1,608 runs, 0 failures.

**Numbers.** No allocation change. Instructions: −4.1% on `t(:hello)`, −3.1% on interpolation, and −2.9% to −3.6% on
the default, link and miss cases, against an A/A of ≤0.3%. The census measures allocations only, so it can't show C4.
Its census run confirms that the allocations don't change: i18n's own lines move −0.5 / +0.0, the same as the A/A.
The total over all lines moves +14.6 / +26.6, which is the apps' own run-to-run swing (mostly Loomio, which also moves
+54 to +80 in C2 and C3).

## Leads and rejections

* **`normalize_keys`** (48 per workload, 14% of the instructions of a hit). It caches each part (locale, scope, key) and
  then concatenates the three cached Arrays into a new one on every call. A cache keyed by `(locale, scope, key,
  separator)` could return a frozen Array, but the result is public API (`I18n.normalize_keys`), and callers may mutate
  it (Rails' `missing_translation` only reads it). A new public cache also needs a size bound. Not built.
* **`I18n.config` called five times per translation.** Reading it once in `I18n.translate` saves one call (about 4%), but
  `enforce_available_locales!` and `locale_available?` are public and call `config` themselves. Inlining them would
  bypass overrides. C4 makes every call cheaper instead. The `owned_by?(Fiber.current)` copy-on-write check from #731
  makes up the rest of `config`'s cost and is required.
* **`MissingTranslation` on every miss** (`base.rb:45`, `exceptions.rb:53`, `fallbacks.rb:71/72`): about 5 per
  workload, but 2 objects per miss (the exception and its options Hash), and Active Model's error messages try several
  keys. The exception object is
  thrown and discarded by `resolve`. Avoiding it requires a sentinel through `throw :exception`, which custom backends
  and `handle_exception` observe. Not exact.
* **Interpolation:** `I18n.interpolate` scans each String twice. It first matches `reserved_keys_pattern`, then runs
  a `gsub` with a block that looks up the pattern through `config`. Translations without values still run
  `entry =~ I18n.reserved_keys_pattern` (`base.rb:65`). The scan and the `gsub` result are required, and merging the two
  scans would change which error is raised first. Lead, not built.
* **Rails side:** `HtmlSafeTranslation.translate(key, **options)` and `TranslationHelper#translate`'s
  `**options, default:` (13.8 and 12.8 per workload in 6 apps) are one keyword Hash per hop. Passing the options as a
  positional Hash would change a `:nodoc:` signature that other gems call. Rejected for now.
* **`exists?`, `I18n.locale`, `with_locale`:** 5, 0 and 0 objects. Nothing to do. #718 (`with_locale` early return)
  saves only a locale write.
* **`dup` for C1:** rejected in favour of `merge`, because `dup` calls `initialize_copy` on Hash subclasses.

## Upstream context

* i18n master has no performance changes since 1.15.2. Open performance PRs:
  * ours, #763 (I1) and #764 (I2);
  * sampokuokkanen's #758 (`Utils.except`) and #759 (`localize`);
  * czj's #757 (LazyLoadable file names);
  * lovro-bikic's #716 (`flatten_keys`);
  * aaronskiba's #718 (`with_locale`).

  None touches C1–C4's lines. `git merge-tree` finds no conflicts between any pair of C1–C4, #763, #764, #758 and #759.
* radar merges small, focused PRs with a short "Looks good to me" (#692, #699, #731). Most recent merges are fixes and
  CI; the last performance PRs were merged in 2024 (#692, #697). So each draft is one change, with a reproducible micro and a
  test.

## Drafts

### C1

#### Summary

`Backend::Fallbacks#translate` copies the options for the fallback lookups with
`options.merge(:fallback_in_progress => true, fallback_original_locale: locale)`. The two keywords are collected into a
Hash first, so every translation through Fallbacks allocates two Hashes here.

This copies the options with `options.merge` and stores the two keys. The copy is the same Hash as before: same class,
default, `compare_by_identity` and key order. It is one allocation less per translation (`dup` would call
`initialize_copy` on Hash subclasses, which `merge` does not).

#### Benchmark

Ruby 4.0.7, objects allocated per call with `I18n::Backend::Fallbacks` included (same with and without YJIT):

```
                                 before   after
I18n.t(:hello)                     13  ->  12
I18n.t(:greet, name:)              21  ->  20
I18n.l(time)                       52  ->  49
```

Instructions per `I18n.t(:hello)` (Callgrind): 53,783 → 51,489 (−4.3%; master against itself differs by under 0.3%).
Across 10 open-source Rails apps (111 request, job and mailer workloads), this removes 0.38% of all allocated objects,
and every app that translates gains.

#### Testing

Added a test that the fallback lookups receive the options with both keys, in the same order, without changing the
caller's options. The test suite passes (1,608 runs).

### C4

#### Summary

Since #731/#739, `I18n.config` and `I18n.fallbacks` check `Fiber.respond_to?(:[])` on every call, so that Rubies
without Fiber storage (3.1, JRuby 9.4) keep using thread variables. A translation reads the config about five times,
so this check is about 4% of the instructions of a simple `I18n.t`.

This records whether `Fiber[]` existed when i18n loaded and only checks again when it didn't. `Fiber[]` is core from
Ruby 3.2 and can't go away there. On Rubies without it, every call still checks, so a `Fiber[]` defined later (for
example by the fiber-storage gem) is still picked up.

#### Benchmark

Ruby 4.0.7, instructions per call (Callgrind, `I18n::Backend::Fallbacks` included):

```
                                before     after
I18n.t(:hello)                  53,783    51,569   (-4.1%)
I18n.t(:greet, name:)           81,020    78,529   (-3.1%)
I18n.t(:missing, default: "x")  73,731    71,595   (-2.9%)
```

#### Testing

Added a test that Fiber storage is still used when it becomes available after i18n is loaded. The test suite passes
(1,608 runs).

### C2

#### Summary

Resolving a Symbol, either a `default:` Symbol or a link in the Simple backend, calls `I18n.translate(subject,
**options.merge(locale: …, throw: true, skip_interpolation: true))`. That builds the keywords as a Hash, merges them
into a copy of the options and splats the copy. Passing `**options, locale: …, throw: true, skip_interpolation: true`
builds the same keyword arguments directly, and the explicit keys still override the caller's. The Simple backend's link
options use `options.except(:count)` and set `:scope` instead of merging first.

#### Benchmark

Ruby 4.0.7, objects allocated per call with `I18n::Backend::Fallbacks` included (same with and without YJIT):

```
                                              before   after
I18n.t(:link)  (a Symbol link)                  32  ->  27
I18n.t(:missing, default: :hello)               29  ->  27
Rails errors.full_messages (2 errors)          527  -> 499
```

#### Testing

Added a shared API test that a link drops `count` and `scope` and keeps the other options. The test suite passes
(1,615 runs).

### C3

#### Summary

When a key segment is missing, `Simple#lookup` retries it as `_key.to_s.to_sym`, so that numeric and boolean segments
also find translations stored under Symbols. For a Symbol segment, the retry is the same key again, and `to_s`
allocates a String on every miss: Symbol defaults, `human_attribute_name` and Active Model error messages each miss
several keys. This returns `nil` for a missing Symbol before converting.

#### Benchmark

Ruby 4.0.7, objects allocated per call:

```
                                              before   after
I18n.t(:missing, default: "x")                  23  ->  22
Rails errors.full_messages (2 errors)          527  -> 509
```

#### Testing

Added a test that numeric and boolean segments still find Symbol-stored translations and that missing Symbol segments
return nil. The test suite passes (1,609 runs).
