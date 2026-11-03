# Schema-context access cost (bet AT)

Since [#58437](https://github.com/rails/rails/pull/58437) and [#58578](https://github.com/rails/rails/pull/58578),
every `attribute_types`, `_default_attributes`, `attributes_builder` and `columns_hash` read goes through
`schema_context` → `SchemaContext#attributes`. That has a fast path (`@attributes`, built with the schema) only when
the model's default attributes are read-only and Ractor-shareable. Otherwise every call looks the attributes up in
Ractor-local storage (`ActiveSupport::Ractors[@attributes_key]`). This bet asks how many models take the slow path,
what it costs, and whether it can be fixed at the source or at the call sites. Rails main
[`c042aee23a`](https://github.com/rails/rails/commit/c042aee23a), which includes #59568 (C3); Ruby 4.0.7,
interpreter and YJIT. Same method as [activerecord-cpu](activerecord-cpu.md): Callgrind instruction counts with
an A/A control, census allocations, **no wall-time claim**.

**Result.** 294 of 312 loaded models in eleven census apps take the slow path. The cause is almost never a
user-provided default. It's two Active Record type wrappers that are never frozen: `TimeZoneConverter`, which
wraps every datetime column under `time_zone_aware_attributes` (on in every Rails app), and `EnumType`. Freezing
them when what they wrap is already frozen moves 176 models (AT1) and 223 models (AT1+AT2) to the fast path. Per
call that removes the slow-path lookup entirely, and per-call counts return to the non-time-zone-aware numbers.

| # | Branch | Commit | What | Per call (interpreter / YJIT) | ruby-bench, interpreter (lobsters / railsbench / shipit) | Census (56 workloads) |
| --- | --- | --- | --- | --- | --- | --- |
| AT1 | [`thomasklemm/time-zone-converter-shareable`](https://github.com/thomasklemm/rails/tree/thomasklemm/time-zone-converter-shareable) | [`9ac3833d1c`](https://github.com/thomasklemm/rails/commit/9ac3833d1c) | Freeze `TimeZoneConverter` when its subtype is frozen | `attribute_types` −40% / −45%; `Post.new` −8.6% / −14%; loading 10 rows −4.2% / −5.7% | −0.10% / −0.16% / −0.15% (A/A −0.04% / +0.01% / −0.02%) | within A/A, no SQL changes |
| AT2 | [`thomasklemm/enum-type-shareable`](https://github.com/thomasklemm/rails/tree/thomasklemm/enum-type-shareable) | [`363fee003d`](https://github.com/thomasklemm/rails/commit/363fee003d) | Freeze `EnumType` when its mapping and subtype are frozen | model with an enum, on top of AT1: `attribute_types` −40% / −45%; `Post.new` −8.6% / −14%; 10 rows −4.1% / −4.9%; nothing without AT1 | within A/A alone; AT1+AT2 −0.13% / −0.15% / −0.23% | within A/A, no SQL changes |

Not opened. Drafts in the short form are at the end.

**ruby-bench** (Callgrind, one measured iteration after warmup; A/A = same commit in a second worktree):

| | lobsters | railsbench | shipit |
| --- | ---: | ---: | ---: |
| interpreter A/A / AT1 / AT1+AT2 | −0.04% / −0.10% / −0.13% | +0.01% / −0.16% / −0.15% | −0.02% / −0.15% / −0.23% |
| YJIT A/A / AT1 / AT1+AT2 | +0.41% / +0.12% / −0.01% | +0.11% / −0.26% / −0.13% | −0.09% / −0.19% / −0.23% |
| ZJIT (Ruby master) A/A / AT1 / AT1+AT2 | +0.11% / −0.13% / −0.20% | −0.03% / −0.15% / −0.07% | not run |

Under ZJIT both apps clear their A/A with AT1. Under YJIT only railsbench and shipit clear their A/A, by about 0.1 to 0.2 points; lobsters' YJIT A/A (+0.41%) is
larger than the effect, as in [activerecord-cpu](activerecord-cpu.md) (lobsters is not fully deterministic).

**Ruby master × ZJIT** ([`9aa0898240`](https://github.com/ruby/ruby/commit/9aa0898240), built in this orb, `--zjit`;
per call, 1,000 to 3,000 calls after 1,000 warmup, A/A within 0.3%): for the time-zone-aware `Post`, AT1 gives
`attribute_types` −8.7%, `has_attribute?` −9.6%, `Post.new` −7.6%, `instantiate` −6.8%, loading 10 rows −2.3%,
`where.to_a` −0.3%. For a `Post` with an enum, AT1+AT2 gives `attribute_types` −9.5% and `Post.new` −6.6%.

**One ZJIT loss, explained.** With AT1 alone, the enum `Post` (still on the slow path) is **+4.6%** on
`attribute_types` and **+3.8%** on `Post.new` (3,000 calls, A/A 0.0%); the interpreter and YJIT show +0.0% and +0.2%.
`--zjit-stats` shows two more dynamic ivar reads per call (`rb_ivar_get` 160,890 → 201,212 over 20,000 calls) and
as many more `no_profile_missing_ic`. With AT1, `Author` and `Comment` take the fast path, so while ZJIT profiles
`SchemaContext#attributes` the slow branch (`ActiveSupport::Ractors[@attributes_key] ||= …`) never runs, and ZJIT
compiles it without inline caches. Keeping `Author` and `Comment` slow (`ALLSLOW=1`, a Proc default) makes the
counters identical to main (204,385 / 76,485) and the instructions equal (`attribute_types` −0.2%, `Post.new` +0.0%).
So the loss is not in the frozen converter: models that remain on the slow path in an app where others moved to the
fast path pay about 80 instructions more per schema read under ZJIT, while the moved models save about 300. Moving
the slow branch into its own method would give it its own profile; that touches `schema_context.rb`, which open
#59530 rewrites, so it is noted, not built. The app-level ZJIT result is the ruby-bench row above.

## Census: who takes the slow path, and how often

[census_probe.rb](../../bench/upstream/schema_context/census_probe.rb) (results in [probe/](data/schema-context/probe)), run in each census copy through
[census_run.rb](../../bench/upstream/schema_context/census_run.rb): after warming every workload, it runs each one
once more with a TracePoint that counts `schema_context` and `SchemaContext#attributes` calls by caller, and
whether `#attributes` took the fast path. Then it classifies every loaded model and lists, per attribute, what
blocks the fast path.

| App | Loaded models | Slow path | Fast with AT1 | Fast with AT1+AT2 | Workloads | `schema_context` / request | `attributes` / request (slow) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 3 | 3 | 3 | 3 | 10 | 44 | 21 (21) |
| campfire | 15 | 15 | 12 | 13 | 9 | 245 | 164 (164) |
| chatwoot | 44 | 43 | 23 | 37 | 14 | 394 | 242 (241) |
| codetriage | 6 | 6 | 6 | 6 | 7 | 103 | 89 (89) |
| discourse | 77 | 70 | 61 | 70 | 14 | 177 | 114 (109) |
| fizzy | 41 | 39 | 3 | 3 | 14 | 394 | 302 (301) |
| lago | 60 | 60 | 31 | 48 | 10 | 193 | 133 (133) |
| lobsters | 19 | 16 | 14 | 14 | 11 | 203 | 133 (118) |
| mastodon | 39 | 34 | 17 | 21 | 14 | 280 | 147 (136) |
| pingcrm | 4 | 4 | 4 | 4 | 8 | 106 | 99 (99) |
| redprints-cfp | 4 | 4 | 2 | 4 | 8 | 56 | 51 (51) |
| **all** | **312** | **294** | **176** | **223** | **119** | | |

The census copies are on [`e64b660612`](https://github.com/rails/rails/commit/e64b660612), before C3, so
`_load_from_sql`'s calls are counted per column there; C3 halves them.

**Why models are slow** (blockers per slow model, one model can have several): `TimeZoneConverter` 290,
`EnumType` 68, `UserProvidedDefault` with a Proc 34, `NormalizedValueType` 20, `Serialized` 7,
`UserProvidedDefault` with a Symbol 7 or `false` 6, `EncryptedAttributeType` 4, `LockingType` 2, others 1 each.
176 slow models are blocked by `TimeZoneConverter` alone, 47 more by it and `EnumType`, and 14 more by those two and
`NormalizedValueType`. Fizzy is the exception: 33 of its models have Proc defaults (UUID primary keys).

**Where `#attributes` is called** (all apps, base): `type_for_attribute` 47% (`TypeCaster::Map`, predicate
building), `_load_from_sql` 33% (`attribute_types` per column key, halved by C3), `attributes_builder` in
`instantiate_instance_of` 19% (once per row), `Base.new` 2%, `has_attribute?` under 1%.

**Cost per call** (Callgrind, [micro.rb](../../bench/upstream/schema_context/micro.rb) with `TZA=1` for a
time-zone-aware model, as in an app; `TZA=0` takes the fast path):

| Case | fast (`TZA=0`) | slow (`TZA=1`) | slow − fast |
| --- | ---: | ---: | ---: |
| `Post.attribute_types`, interpreter / YJIT | 1,672 / 781 | 2,790 / 1,412 | 1,118 / 631 |
| `Post.has_attribute?(:title)` | 3,767 | 4,881 | 1,114 |
| `Post.new` | 23,764 | 25,992 | 2,228 (two reads) |
| `Post.instantiate(attrs)` | 17,076 | 18,188 | 1,112 |
| loading 10 rows | 281,188 | 293,346 | 12,158 |

The slow path costs about 1,100 instructions per `#attributes` call in the interpreter and 630 under YJIT, which is
`Ractor.current`, the Ractor-local Hash lookup and the `||=`. With 100 to 300 slow calls per request, that's about
0.1 M to 0.35 M instructions per request.

## Source fixes

* **(a) A cheaper `schema_context`.** Not built. Open [#59530](https://github.com/rails/rails/pull/59530) (matthewd,
  updated 2026-11-02, reviewed by tenderlove and adrianna-chang-shopify) rewrites `SchemaContext#attributes` into
  `mapped_table.attributes || initialize_attributes` and the reader chain around it. A1 already measured inlining
  `schema_loaded?` below the bar once C3 landed.
* **(b) A faster slow path.** Not built, for the same overlap: #59530 replaces the Ractor-local key with a
  `WeakKeyMap` in Ractor storage. A main-Ractor memo would need a mutable holder outside the context, since the
  context itself is made shareable (frozen) after loading. With AT1+AT2, 71 of 312 models are left on the slow path.
* **(c) More models on the fast path.** This is AT1 and AT2: the blockers are type wrappers, not defaults. Making
  `UserProvidedDefault` with a frozen non-Proc value freezable would move only about 11 more models, and it isn't
  exact: the default is cast lazily and memoized (`@value`), so freezing would cast it at schema load, which moves
  cast errors and is the laziness #58578 kept deliberately (gmcgibbon: "Defaults and attribute serialization errors
  need to happen lazily"). Rejected.
  * **Exactness of AT1/AT2.** Freezing a `Delegator` also freezes the object it wraps, so AT1 freezes the converter
    only when its subtype is already frozen, and AT2 only when `enum_values` and the subtype are. Neither type has
    a memoizing ivar or a writer (`rg '@\w+ \|\|=|instance_variable_set'` over both files, `Type::Value` and the
    type helpers). Both are built only in `hook_attribute_type` and `_enum`'s `decorate_attributes`.
    `reload_schema_from_cache` and `reset_column_information` rebuild the types, so a reloaded model gets new frozen
    instances. No gem in the 448 bundled gem paths of the census apps reopens either class (store_model has an
    unrelated `StoreModel::Types::EnumType`). The schema context's own Ractor test (`attribute type is available
    in a Ractor`) and the full suite pass.
  * **Boundary.** Code that sets an ivar on a `TimeZoneConverter` or `EnumType` after the schema loads would now
    raise `FrozenError`. No Rails path or census gem does.

## Call-site fixes

* **Per-row `attributes_builder`** in `_load_from_sql` → `instantiate_instance_of`. Hoisting it per result set (on
  top of AT1) gives 10 rows −5.7%, one row −0.5%, `where.to_a` −1.0%, `includes` −1.1% (interpreter, A/A +0.1%).
  Not built as a candidate: open [#59141](https://github.com/rails/rails/pull/59141) rewrites this block
  (`result_set.map_rows(attributes_builder.indexes) { … instantiate_instance_of(…) }`) and still reads
  `klass.attributes_builder` once per row there. It's a data point for #59141's author rather than a competing
  change.
* **Per-predicate and per-attribute checks** (`has_attribute?`, `columns_hash.key?` in `TableMetadata`,
  `find_by` keys). They're under 1% of `#attributes` calls in the census, and `columns_hash` doesn't go through
  `#attributes`. With AT1 they're fast-path reads. Not pursued.

## Overlap checked

`gh search prs` on rails/rails (2026-11-03): `TimeZoneConverter`, `TimeZoneConversion`, `EnumType`, `enum
shareable`, `freeze type`, `default attributes shareable`, `schema_context`, `instantiate_instance_of`,
`attributes_builder`, `shareable` (open). Open: #59530 (SchemaContext/MappedTable split, touches
`SchemaContext#attributes` but not the shareability condition: still `defaults.read_only? &&
Ractors.shareable?(defaults)`), #58591 (joshuay03, touches `schema_context.rb`), #59141 and #58002 (attribute
sets). None touches the two type wrappers. Closed #56167 (hmcguire-shopify, replace TimeZoneConversion's
DelegateClass) was not merged. #58578's review discussed freezing the default attributes (byroot); this change
makes that possible for most models without moving any cast.

## Method

* **Census probe.** As above; `RAILS=SHA` in `census_run.rb` runs a variant installed by `script/census run`.
* **Per call.** [irmicro.rb](../../bench/upstream/schema_context/irmicro.rb) on micro.rb cases, 200 calls with GC
  off after warmup, `TZA`/`ENUM` passed through; `aa` is a second worktree of the same commit. YJIT loading 10 rows
  was rerun with 1,000 calls after a 200-call run showed an A/A of −3.4%; the rerun's A/A is −0.3%.
* **ruby-bench.** [`irab.rb`](../../bench/upstream/arcpu/irab.rb) (`--zjit` with Ruby master first in `PATH`), one measured iteration after warmup;
  variants `atbase`, `atbase2` (A/A), `at1`, `at2`, `at12` (AT1+AT2).
* **Allocations.** `script/census run --out census-out/at --label at-base --aa` on `c042aee23a`, then `at1` and
  `at12`, on Blog, Campfire, Fizzy, PingCRM, Redprints CFP, CodeTriage, interpreter and YJIT;
  `compare --base at-base2 --aa at-base`. As expected, nothing moves beyond the A/A: a Ractor-local lookup doesn't
  allocate.
* **Suites.** Each branch: `rake test:sqlite3` in `activerecord` with `RAILS_STRICT_WARNINGS=1` (AT1 10,266 runs,
  AT2 10,265 runs, 0 failures, 0 errors), RuboCop on the changed files. Each new test fails on main.

## Drafts

### AT1: Freeze TimeZoneConverter when its subtype is frozen

> A model's default attributes are shared through its schema context only when they're Ractor-shareable;
> otherwise every `attribute_types`, `attributes_builder` and `_default_attributes` read looks them up in
> Ractor-local storage. Time zone aware attributes wrap their column type in a `TimeZoneConverter` that is never
> frozen, so every model with a datetime column takes that path under `time_zone_aware_attributes`, which apps
> enable by default.
>
> This freezes the converter when the type it wraps is already frozen. An unfrozen subtype stays as it is, since
> freezing a Delegator also freezes the object it wraps.
>
> | Per call, interpreter / YJIT | Before | After |
> | --- | ---: | ---: |
> | `Post.attribute_types` | 2,790 / 1,412 instructions | 1,672 / 781 (−40% / −45%) |
> | `Post.new` | 25,992 / 8,935 | 23,762 / 7,675 (−8.6% / −14%) |
> | loading 10 rows | 293,673 / 131,856 | 281,238 / 124,385 (−4.2% / −5.7%) |
>
> In eleven apps, 176 of 312 models move to the shared path; ruby-bench runs 0.10% to 0.16% fewer instructions.

### AT2: Freeze EnumType when its mapping and subtype are frozen

> Like time zone aware attributes, enum attributes are typed with an `EnumType` that is never frozen, so a
> model with an enum reads its default attributes from Ractor-local storage on every `attribute_types`,
> `attributes_builder` and `_default_attributes` call instead of from its schema context.
>
> This freezes the `EnumType` when its mapping and the type it wraps are already frozen, which they are once `enum`
> has returned.
>
> | Per call, model with an enum and timestamps, with AT1, interpreter / YJIT | Before | After |
> | --- | ---: | ---: |
> | `Post.attribute_types` | 2,790 / 1,411 instructions | 1,672 / 781 (−40% / −45%) |
> | `Post.new` | 25,905 / 8,936 | 23,679 / 7,688 (−8.6% / −14%) |
> | loading 10 rows | 298,083 / 135,396 | 285,985 / 128,709 (−4.1% / −4.9%) |
>
> With the change to `TimeZoneConverter`, 47 more of 312 models in eleven apps move to the shared path.
