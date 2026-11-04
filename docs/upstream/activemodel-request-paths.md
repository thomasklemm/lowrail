# Active Model on the per-request paths (2026-11-04)

A round looking for small, exact rails/rails candidates in the Active Model code that census apps run on every
request:
* validations (`validates_with`, presence/length/format/uniqueness setup and run);
* attribute assignment and type casting (`assign_attributes`, `AttributeSet`/`LazyAttributeSet`, `Attribute#value`);
* dirty tracking (`changes_applied`, `*_changed?`, the mutation tracker);
* serialization (`serializable_hash`, `as_json`).

These were left alone because other work covers them: #54812 (`body_changed?`), #59607 (`resolve_attribute_name`, ours), C11 (Active Record write path, Arel) and C13 (Active Support, Callbacks). Nothing was opened or posted.

**Result: no candidate.** The one lead built, `Type::String#cast_value` with `dup`, was rejected after measuring. With a frozen
source, which is how sqlite3 returns database values, it uses more memory and is slower for long values. Every other site is
covered by an open PR, below 0.04% of census 8's interpreted instructions, or not exact.

## Pins and method

* Rails main [`9cf3693a0a`](https://github.com/rails/rails/commit/9cf3693a0a). Since `9b116f1fed` only one file
  under `activemodel`, `activerecord` or `activesupport` changed: the SQLite statements file. Ruby 4.0.9 (interpreter and YJIT) and ruby-master
  `9aa0898240` (interpreter and ZJIT).
* CPU ranking: census 8 (20 apps, Rails `1105756f42`), `rank-cpu409-{interpreter,yjit}-line.tsv`.
* Overlap: the 19 open rails/rails PRs that touch `activemodel/lib`, as of 2026-11-04, and `git log` on each file in scope.

## Where Active Model's time goes

| Census 8 line(s) | Apps | % of all Ir, interp / YJIT | Disposition |
| --- | ---: | ---: | --- |
| `LazyAttributeSet#keys` (attribute_set.rb:225–226) | 20 | 0.78 / 1.13 | Open #58002 and #59141. |
| `IndexedRow::Mutable#fetch`/`#[]`/`#[]=`, `IndexedRow#fetch`, `AttributeSet#[]`, `fetch_value!`, `default_attribute`, `Builder#build_from_database` | 18–20 | about 2.4 together | Open #59141 (tenderlove, last updated 2026-11-03) rewrites these files. Not touched. |
| `Attribute#hash`, `Type::Value#hash` (attribute.rb:149, type/value.rb:131) | 18–19 | 0.21 + 0.19 / 0.20 + 0.15 | Query cache keys, which is open #59518. `[...].hash` already allocates nothing (`opt_newarray_send`). Memoizing would assume type objects never change, but `Integer` sets `@max` lazily. |
| `Type::String#cast_value` (type/string.rb:40) | 20 | 0.149 / 0.184 | CS-1 below. Rejected. |
| `Attribute#value`, `Type::Value#cast`, `Attribute.from_database`, `Integer#out_of_range?` | 16–20 | 0.06–0.10 each | Each is already a single guard plus a call; nothing to remove. |
| `AttributeMethodPatternSet#matching`, `AttributeMethods#respond_to?` | 12 / 20 | 0.047 / 0.044 | `end_with?(*@suffixes)` allocates nothing. `respond_to?` already returns early on `super`. |
| `ForbiddenAttributesProtection#sanitize_for_mass_assignment` (:27) | 17 | 0.038 / 0.010 | Runs on every `where(hash)` and `find_by`. A `Hash` fast path before `respond_to?(:permitted?)` would skip a `permitted?` on a Hash subclass or singleton (checklist 1, 2). Not exact, and it would save at most about 0.025%. |
| Mutation tracker (`attribute_changed?`, `changed_attribute_names`, `any_changes?`, `changed?`) | 17–20 | 0.012–0.028 each | Recently reworked: d8309ec333 (forced changes, 2026-10-22), b17a800e91 (`Symbol#name`, amatsuda 2026-10-25). `attr_names` is `LazyAttributeSet#keys` (open #58002/#59141). |
| `Validations#context_for_validation`, `#errors`, `EachValidator#validate`, `Clusivity#include?` | 3–15 | ≤ 0.020 | Per-record state, not waste. Below the bar. |
| `AttributeAssignment#_assign_attribute` (`:"#{k}="`, :72) | 18 | 0.013 / 0.023 | The dynamic Symbol needs a cache to avoid it (L2), for at most about 0.02%. |
| `Serialization#read_attribute_for_serialization`, `serializable_hash` | 2–7 | 0.03 / 0.06 | Rejected before ([serialization-cpu](serialization-cpu.md)). |

## CS-1: `Type::String#cast_value` with `dup` (rejected)

Every string attribute, whether read from the database or assigned, is cast here with `::String.new(value)`. The copy is the
defensive copy that dirty tracking needs. In 2014 the code chose `String.new` because "String.new is slightly faster than dup"
(c7802dccba). On 4.0.9 that no longer holds for an unfrozen source: `+"hello world title"` takes 229 ns with
`String.new` and 80 ns with `dup`, and 2 objects instead of 1. The candidate was
`value.instance_of?(::String) ? value.dup : ::String.new(value)`, so subclasses such as SafeBuffer still come out
as plain Strings.

It was rejected for two reasons:

* **Frozen sources.** sqlite3 returns frozen result strings. For those, `String.new` shares the source's buffer: one 40-byte
  object, about 179 ns, at any length. `dup` copies the bytes into a new slot, so long values take more memory and time
  ([`string_copy_micro.rb`](../../bench/upstream/activemodel_am/string_copy_micro.rb), 4.0.9, interpreter, fresh
  source per call):

  | Source | `String.new` | `dup` |
  | --- | --- | --- |
  | 19 chars, unfrozen | 3 objects, 40 B, 289 ns | 1 object, 80 B, 98 ns |
  | 19 chars, frozen | 1 object, 40 B, 177 ns | 1 object, 80 B, 113 ns |
  | 60 chars, frozen | 1 object, 40 B, 179 ns | 1 object, 160 B, 176 ns |
  | 300 chars, frozen | 1 object, 40 B, 179 ns | 1 object, 640 B, 309 ns |

  The SQLite micro confirms it: loading 20 posts and reading `title` and `body` made 332 objects with both forms. Keeping the
  sharing for frozen sources would need a second branch on `frozen?`, plus a comment explaining why (L3).
* **Instance variables.** `dup` copies a String's instance variables and `String.new` doesn't
  ([`string_copy_probe.rb`](../../bench/upstream/activemodel_am/string_copy_probe.rb); the same on 4.0.9 and master,
  and every other probe case matched). That is a reachable difference for user-assigned values (checklist 1).

Other numbers, for the record:
* ruby-bench calls per iteration: railsbench 9,940, shipit 8,682, lobsters 3,484, all with String arguments and no subclasses.
* flog 5.3 → 8.0; RuboCop ABC 3.61 → 5.66, cyclomatic 4 → 5, perceived 3 → 4.

No Callgrind round was finished, because the memory result already decides the lead.

## Limits

* The table's shares come from census 8 on Rails `1105756f42`. Files changed since then were read on `9cf3693a0a`.
* Only CS-1 was built and measured, and only with wall time and allocation counts. No reviewer round, since nothing goes forward.
* PostgreSQL's `pg` returns unfrozen strings, where `dup` would win. Census 8 mixes adapters, and an adapter-dependent
  memory regression is still a regression.
