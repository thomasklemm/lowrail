# Rails candidates on common paths, round 2 (2026-11-04)

A second round in the style of [round 1](rails-common-paths.md), after rails/rails#59596, #59597, #59598, #59583
and #59585 merged within hours: small, exact changes on paths every Rails app runs, with instruction or allocation
evidence from the census apps. Sources: the CPU ranking of [census 8](rails-main-census-8.md)
(`rank-cpu409-{interpreter,yjit}-{line,method}.tsv`; 20 apps, 251 workloads, Rails main `1105756f42`, Ruby 4.0.9),
[F1](frontier-census-f1.md) and the [ZJIT gap census](zjit-gap-census.md), excluding every site census 8, round 1,
[R6](rails-r6-leads.md) or an open PR already covers.

**Result.** Two candidates, held for Thomas per [DECISIONS](../DECISIONS.md#pull-requests) (nothing opened, nothing
posted). One more was built and rejected as not exact.

| # | Branch @ SHA | Change | Per call |
| --- | --- | --- | --- |
| CP-3 | `thomasklemm/resolve-attribute-name-lookup` @ `be7ab87287` | `resolve_attribute_name`: `fetch(name = super, name)` instead of `fetch(super, &:itself)` | `type_for_attribute`: −12% instructions interpreted, −22% YJIT, −29% ZJIT; a two-predicate `where`: −0.5% / −1.4% / −2.2% |
| CP-5 | `thomasklemm/uri-encoder-safe-match` @ `273cb63132` | `UriEncoder#escape`: anchored match on the safe characters instead of a search for an unsafe one | `escape_segment` of a slug: −42% / −46% / −45%; `post_path(post)`: −1.1% / −2.5% / −1.5% |

Both are one commit on rails/rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed)
(unchanged at the end of the round), authored and committed by Thomas Klemm, revised after Sol's review
([below](#revision-after-sols-review-2026-11-04)), not pushed anywhere; the commits are in [`patches/`](../../bench/upstream/common_paths_2/patches/) (`git am` onto `9b116f1fed`).

## Pins and method

Same as round 1 ([pins and method](rails-common-paths.md#pins-and-method)), with these scripts in
[`bench/upstream/common_paths_2/`](../../bench/upstream/common_paths_2/):

* Worktrees `main` and `aa` (Rails main twice, for the A/A) and one per candidate; Ruby 4.0.9 interpreter and
  `--yjit`; Ruby master [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb)
  interpreter and `--zjit`.
* **Instructions per call:** [`ir.sh`](../../bench/upstream/common_paths_2/ir.sh) and
  [`ir_table.rb`](../../bench/upstream/common_paths_2/ir_table.rb): Callgrind with `--toggle-collect=rb_ary_cycle`,
  3,000 calls in `[0].cycle(1)` after 3,000 warmup calls, GC disabled, (Ir(3,000) − Ir(0)) / 3,000. Three runs per
  variant on 4.0.9 (medians), one on master. Cases: [`micro.rb`](../../bench/upstream/common_paths_2/micro.rb)
  (Active Record on SQLite in memory, schema in [`setup.rb`](../../bench/upstream/common_paths_2/setup.rb)) and
  [`micro_url.rb`](../../bench/upstream/common_paths_2/micro_url.rb) (a `RouteSet` with `resources :posts` and
  `get "/pages/:slug"`).
* **Wall time:** [`ns_pinned.sh`](../../bench/upstream/common_paths_2/ns_pinned.sh), one CPU, 15 rounds in rotating
  order, 30,000 calls after 5,000 warmup calls, GC disabled, medians.
* **Objects per call:** `GC.stat(:total_allocated_objects)` over 2,000 calls: unchanged for both candidates
  (`type_for_attribute` 1, `where_two` 102, `post_path` 11, `escape_segment` 1).
* **ruby-bench:** ruby/ruby-bench `73918b2` (Rails 8.1.1/8.1.2). [`lowrail_cp.rb`](../../bench/upstream/common_paths_2/lowrail_cp.rb)
  (copied into `ruby-bench/harness/`) redefines the method in every variant, main's body or the candidate's; for
  CP-5 the main body is main's, with the early return of rails/rails#59058 that 8.1 lacks. One iteration under
  Callgrind after warmup (interpreter 1, YJIT 10), `main1`/`main2` are the A/A
  ([`rb_cp.sh`](../../bench/upstream/common_paths_2/rb_cp.sh)). Calls per iteration were counted with a TracePoint.
* **Exactness:** a differential harness per candidate ([`diff_ran.rb`](../../bench/upstream/common_paths_2/diff_ran.rb),
  [`diff_esc.rb`](../../bench/upstream/common_paths_2/diff_esc.rb), [`diff_dtp.rb`](../../bench/upstream/common_paths_2/diff_dtp.rb)),
  run on 4.0.9 and on master with the interpreter, YJIT and ZJIT, against the eight-item checklist.
* **Suites:** Ruby 4.0.9. CP-3: Active Model (1250 runs, 0 failures) and Active Record `test:sqlite3` (10281 runs,
  0 failures; 5 errors from the orb: no `pg` gem for one multi-database test, no `sqlite3` CLI for four structure
  dump/load tests). CP-5: Action Pack with `RAILS_STRICT_WARNINGS=1` (4506 runs, 0 failures). RuboCop clean.
* **Reviews:** no codex or Sol in this orb and no new threads, so (as in round 1) each candidate got two independent
  subagent reviews: a primary on both rubrics with the L0–L3 rating and the exactness checklist, then an
  adversarial round that ran code to break identical behavior. A third subagent read both bodies against this page.
  Verdicts: both primaries "approve with notes" (CP-3 L0–L1, CP-5 L1); CP-3's note tightened the commit message,
  CP-5's (the safe and escaping classes could drift apart unseen) added the test. Both adversarial rounds found no
  difference outside the accepted override classes; CP-5's found the long-component timing below. Body check:
  "ready after small edits" for both, all numbers recomputed; its edits are applied, including a wrong
  "non-empty Strings" claim in CP-3 (an empty alias value is possible and truthy, so nothing changes).

## Revision after Sol's review (2026-11-04)

Sol reviewed both patches after the round was merged: CP-3 "approve with changes", CP-5 "reject as submitted".
Each finding was checked against the real code, both worktrees side by side, on Ruby 4.0.9.

**CP-3, confirmed, both findings.**

1. *Evaluation order.* Main evaluates `attribute_aliases` (the receiver of `fetch`) before `super` calls
   `name.to_s`; the `[] || name` form read it afterwards. With a name whose `to_s` calls
   `P1.alias_attribute(:headline, :title)` and returns `"headline"`, `type_for_attribute(name).type` is `nil` on
   main and `:string` with the old patch.
2. *Hash defaults.* With `attribute_aliases = Hash.new("title")` or `{ "title" => nil }`, main gives `nil` and the
   old patch `:string` (`fetch` ignores defaults and returns stored `nil`, `[] ||` doesn't). A raising default
   proc raised on both, through other `[]` lookups in Active Record.

Three exact replacements were measured with the same Callgrind and A/A setup (4.0.9, three runs each):

| Form | `type_for_attribute` interpreter | YJIT | two-condition `where` interpreter | YJIT | Readability (review) |
| --- | ---: | ---: | ---: | ---: | --- |
| `[] \|\| name` (round 2, not exact) | −14.8% | −23.7% | −0.56% | −1.75% | L0 |
| `fetch(super) { \|resolved_name\| resolved_name }` (Sol) | −3.2% | −11.4% | −0.05% (A/A 0.21%) | −0.52% | L1 |
| `aliases = attribute_aliases; name = super; aliases.fetch(name, name)` | −11.7% | −22.2% | −0.46% | −1.46% | L2: the order only shows from the local, so it reads as foldable |
| **`attribute_aliases.fetch(name = super, name)`** | **−12.2%** | **−22.4%** | **−0.47%** | **about −1.4%** | **L1, no comment needed** |

A literal block keeps the block call and only drops `Symbol#to_proc`, so Sol's form keeps a quarter of the
interpreter gain; passing the name as `fetch`'s default removes the block. The one-line form evaluates the
receiver first and then `super`, as main does (bytecode `send attribute_aliases`, `invokesuper`, `setlocal name`,
`send fetch, argc:2`; checked at runtime under the interpreter, YJIT and ZJIT), and it is still `fetch`, so
defaults and stored `nil` behave as on main. Rails already assigns inside a `fetch` argument
(`calculations.rb:636`, `attribute_types.fetch(name = result.columns[i])`). It is the committed version.
Remaining differences, none reachable through Rails: a Hash subclass assigned through `attribute_aliases=` whose
`fetch` override now receives a default argument instead of a block, and a `to_s` returning a non-String (main
called `itself` on it).

**CP-5.**

1. *`Regexp.timeout`:* confirmed (2–3× slower in wall time above about 600,000 characters; the body already said
   so). The commit message no longer claims equivalence unconditionally: it names valid strings in
   ASCII-compatible encodings and states the slowdown and its effect on a tight `Regexp.timeout`.
2. *A component that overrides `match?`:* main makes the same single `component.match?` call, so it is affected
   too, with the opposite polarity: for `s = +"a b"`, `def s.match?(*) = true` main escapes to `"a%20b"` and the
   patch returns `"a b"`; with `false`, main returns `"a b"` unescaped and the patch escapes it. No code change.
3. *Test gap:* confirmed. Narrowing `SAFE_SEGMENT` by dropping `a` passed the ASCII test (384 assertions, 0
   failures), and a frozen UTF-8 `"abc"` would then come back from `gsub` as a new, unfrozen US-ASCII String.
   The commit now also asserts `assert_same` for empty, frozen UTF-8 and SafeBuffer components made of every safe
   character of each class, an explicit unsafe output (`"café 1"` → `"caf%C3%A9%201"`, US-ASCII) and an invalid
   UTF-8 `ArgumentError`. A second review then showed `\A` → `^` and a non-ASCII widening (`é`) still survived, so
   the per-character test now also covers `é` and a no-break space, and a new test escapes `"a b\nc"` with all
   three escapers. Mutation matrix, each of the three classes: narrowing (drop `a`, `~`), widening (add space,
   `é`), `\A` → `^`, `\z` → `$`, `*` → `+`: 21 of 21 mutants fail; the reviewer's own 41-mutant matrix: all fail.

**Suites on the final commits** (Ruby 4.0.9): Active Model 1,250 runs and Active Record `test:sqlite3` 10,281
runs, 0 failures (the same 5 orb errors as before); Action Pack with `RAILS_STRICT_WARNINGS=1` 4,510 runs, 0
failures. RuboCop clean. Each amended diff got a separate subagent review: CP-3's one-line form "approve with
notes" (L1), CP-5 "approve" once the commit message's newline sentence was corrected (done).

## CP-3: resolve attribute aliases with a `fetch` default

`ActiveModel::AttributeMethods::ClassMethods#resolve_attribute_name` (private) is what `type_for_attribute` calls
first. Active Record calls `type_for_attribute` for every predicate in `where` (through `Arel::Table` and
`TypeCaster::Map`), on association reads, creates and updates: 8 calls for a two-predicate `where(...).to_a`, 4 for
a `belongs_to` read, 2 for a `create`, 4 for an `update` (counted with a TracePoint; `find` by id uses the statement
cache and makes none).

```diff
         def resolve_attribute_name(name)
-          attribute_aliases.fetch(super, &:itself)
+          attribute_aliases.fetch(name = super, name)
         end
```

For a name without an alias, the common case, `fetch` calls its block through `Symbol#to_proc`; that costs more
than the lookup itself. ZJIT doesn't optimize the block-to-C-method call either: the
[ZJIT gap census](zjit-gap-census.md) lists this site among its largest `complex_arg_pass` fallbacks. Passing the
resolved name as `fetch`'s default returns it without a block.

**Census.** `attribute_methods.rb:426` ran in all 20 apps: interpreter line rank 39, 0.18% of all instructions,
52% of them in C; YJIT rank 12, 0.39%.

**Exactness.** `super` is `AttributeRegistration#resolve_attribute_name`, `name.to_s`. Both forms read
`attribute_aliases` first, then run `super`, then call `fetch` once with the resolved name, so Hash defaults,
default procs and stored `nil` values are treated alike and an alias added inside `to_s` is seen on the next call
in both. Differences need a Hash subclass assigned through `attribute_aliases=` whose `fetch` override handles a
block but not a default argument (or the reverse), or a `to_s` that returns a non-String (main also called
`itself` on it). Differential: 135 outcomes (aliases, subclasses, late aliases, Active Model attributes, String
subclasses, `to_s` objects, `nil`, Integer) under the interpreter, YJIT and ZJIT, 0 differences; Sol's four probes
(the order case, `Hash.new("title")`, `{ "title" => nil }`, a raising default proc) give main's results. The
review of the final form reran the earlier adversarial set (order case, defaults, default proc, exceptions,
BasicObject and Symbol `to_s` results, Hash subclasses) on 4.0.9 with and without YJIT: identical except the
unreachable cases above. The round-2 adversarial round (1,510 probes: STI, abstract parents, late subclass
aliases, alias to alias, composite keys and `id_value`, `enum`, `store_accessor`, `serialize`, `normalizes`,
`ignored_columns`, `insert_all`/`upsert_all`, `where.not`, joined conditions, reloading, threads, fibers) ran
against the `[] ||` form; its findings outside the `attribute_aliases=` cases carry over, since the forms agree on
every Hash Rails builds. Checklist: 1–5, 7, 8 checked; 6 not applicable (frozen Hash replaced on write).
Readability: L1 (assignment inside a `fetch` argument, as `calculations.rb:636` does).

**Instructions per call** (Callgrind; 4.0.9 medians of three runs, master one run):

| Case | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `Post.type_for_attribute("title")` | interpreter 4.0.9 | 5,455 | −0.00% | 4,788 | −12.2% |
| | YJIT 4.0.9 | 3,769 | −0.13% | 2,925 | −22.4% |
| | interpreter master | 5,743 | −0.07% | 5,016 | −12.7% |
| | ZJIT master | 3,243 | +0.04% | 2,305 | −28.9% |
| `Post.where(title:, published:).to_a` | interpreter 4.0.9 | 558,493 | −0.01% | 555,842 | −0.47% |
| | YJIT 4.0.9 | 246,677 (pooled) | | 243,143 | −1.43% |
| | interpreter master | 580,656 | +0.00% | 577,825 | −0.49% |
| | ZJIT master | 258,978 | −0.75% | 253,320 | −2.18% |

YJIT `where` runs: main 246,500–249,441 and A/A 246,409–246,853 (median of the six 246,677) against the
candidate's 243,074–243,805. ZJIT `where` is one run with a 0.75% A/A.

**Wall time per call** (Ruby 4.0.9, medians of 15 pinned rounds):

| Case | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `Post.type_for_attribute("title")` | interpreter | 641 ns | +1.3% | 561 ns | −12.5% |
| | YJIT | 384 ns | +0.3% | 293 ns | −23.7% |
| `Post.where(title:, published:).to_a` | interpreter | 164,298 ns | −1.5% | 162,037 ns | −1.4% (not resolved) |
| | YJIT | 56,586 ns | +1.3% | 56,332 ns | −0.4% (not resolved) |

**ruby-bench** (Callgrind instructions for one iteration; calls per iteration counted with a TracePoint):

| App | Calls | Mode | main1 | main2 (A/A) | candidate | Δ |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| shipit | 21,596 | interpreter | 5,842,147,452 | −0.004% | 5,835,772,269 | −0.109% |
| lobsters | 8,968 | interpreter | 4,266,255,137 | +0.023% | 4,263,869,815 | −0.056% (not resolved) |
| railsbench | 0 | interpreter | 6,960,356,496 | +0.076% | 6,963,470,650 | +0.045% |
| (YJIT rows for the final form are running; added when done) | | | | | | |

railsbench never calls `resolve_attribute_name` during an iteration and still moves by up to 0.08% between
builds, so only shipit resolves: its −6.4M instructions interpreted are about 300 per call, against about 670 per
call in the micro. (The round-2 `[] ||` form had shipit −0.16% interpreted and −0.25% YJIT.)

## CP-5: check URL components with an anchored match

Every URL helper escapes each dynamic segment with `Journey::Router::Utils.escape_segment` (globs with
`escape_path`, anchors with `escape_fragment`), and since rails/rails#59058 (merged 2026-10-15) `UriEncoder#escape`
returns the component as is when nothing needs escaping, which is almost always (ids, slugs). It decided that by
searching for one unsafe character with the negated class (`/[^...]/`), which the regexp engine starts at every
position. The candidate matches the whole component against the safe characters, `/\A[...]*\z/` built from the
same character lists, as `xml_name_escape` does with `SAFE_XML_TAG_NAME_REGEXP`:

```diff
           SEGMENT  = /[^#{UNRESERVED}#{SUB_DELIMS}:@]/
           PATH     = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/]/
 
+          SAFE_FRAGMENT = /\A[#{UNRESERVED}#{SUB_DELIMS}:@\/?]*\z/
+          SAFE_SEGMENT  = /\A[#{UNRESERVED}#{SUB_DELIMS}:@]*\z/
+          SAFE_PATH     = /\A[#{UNRESERVED}#{SUB_DELIMS}:@\/]*\z/
+
           def escape_segment(segment)
-            escape(segment, SEGMENT)
+            escape(segment, SEGMENT, SAFE_SEGMENT)
           end
 ...
-            def escape(component, pattern)
-              return component unless component.match?(pattern)
+            def escape(component, pattern, safe_pattern)
+              return component if component.match?(safe_pattern)
```

The commit adds tests that pass on main and on the patch: every component made only of safe characters (empty,
frozen UTF-8, SafeBuffer) comes back as the same object; for every ASCII character plus `é` and a no-break space,
`escape_x("#{c}%")` equals `escape_x(c) + "%25"` (`%` is unsafe in all three classes, so the left side always takes
the `gsub` path); `"a b\nc"` is escaped by all three escapers; an unsafe component comes back as US-ASCII; invalid
UTF-8 raises `ArgumentError`. Narrowing, widening and anchor mutations of each safe class all fail them (see the
revision section).

**Census.** `utils.rb:81`, the `match?` line, ran in 12 of 20 apps: interpreter line rank 96, 0.10% of all
instructions, 94% of them in C (`match?`); YJIT rank 107 (8 apps, 0.09%).

**Exactness.** For a String in an ASCII-compatible encoding without invalid bytes, "no character outside the set"
and "every character inside the set" are the same statement, and `\z` (not `$`) anchors at the real end, so a
trailing `"\n"` still escapes. Invalid bytes and incompatible encodings raise the same `ArgumentError` or
`Encoding::CompatibilityError`, with the same message, in both. Both versions make exactly one `match?` call on
the component and return the same object when it is safe. Differentials: 1,436,445 pairs (every byte and
codepoint, every string up to length 3 over a mixed alphabet, random strings, String subclasses) here; 3,679,401
cases on each of 4.0.9 and master interpreter/YJIT/ZJIT in the primary review (every byte and byte pair, random
binary and mixed strings, each forced into all 103 encodings); 14,622 cases in the adversarial round (lengths up
to 100,000, one unsafe character at the start, middle or end, `\n`/`\r\n` endings, broken UTF-8), plus route
helpers, globs, anchors and `redirect` interpolation with String subclasses, frozen Strings, SafeBuffer, Symbols,
Integers and `to_param` objects, and Ractors (all constants shareable): 0 differences. Checklist: 2–5, 7, 8
checked; 6 not applicable; 1 differs only for a component whose own `match?` ignores its argument (main then fails
open for "always false", the candidate for "always true"), the accepted override class. Readability: L1 (three
constants that mirror the three existing ones).

**Long components.** Instructions aside, the anchored match is faster in wall time up to about 500,000
characters (0.33–0.45 of main's time from 1,000 to 260,000 characters, single match, best of seven) and slower
beyond about 600,000 (3.2× at 786,432, 2× at 10 million); a possessive `*+` doesn't change that. With a global
`Regexp.timeout` set, the input size at which escaping raises `Regexp::TimeoutError` therefore moves: lower for
components over a megabyte, higher for those under that. URL components that long don't occur in practice;
the body says so in one sentence.

**Instructions per call** (Callgrind; 4.0.9 medians of three runs for the slug, `post_path` and `page_path` rows, one run for the others and on master):

| Case | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `escape_segment("my-first-post-about-rails")` | interpreter 4.0.9 | 7,464 | +0.00% | 4,323 | −42.1% |
| | YJIT 4.0.9 | 6,872 | −0.02% | 3,686 | −46.4% |
| | interpreter master | 7,472 | +0.02% | 4,510 | −39.6% |
| | ZJIT master | 6,736 | +0.00% | 3,731 | −44.6% |
| `escape_segment("123")` | interpreter 4.0.9 | 3,171 | +0.00% | 2,824 | −10.9% |
| | YJIT 4.0.9 | 2,551 | −0.34% | 2,159 | −15.4% |
| | ZJIT master | 2,524 | +0.05% | 2,137 | −15.3% |
| `escape_segment("hello world")` (needs escaping) | interpreter 4.0.9 | 15,549 | +0.01% | 15,469 | −0.5% |
| | YJIT 4.0.9 | 14,252 | +0.01% | 14,117 | −0.9% |
| `post_path(post)` (`to_param` "123") | interpreter 4.0.9 | 32,846 | −0.13% | 32,500 | −1.05% |
| | YJIT 4.0.9 | 15,849 | −0.26% | 15,453 | −2.50% |
| | interpreter master | 36,107 | −0.09% | 35,714 | −1.09% |
| | ZJIT master | 22,215 | +0.23% | 21,874 | −1.54% |
| `page_path("my-first-post-about-rails")` | interpreter 4.0.9 | 37,570 | +0.10% | 34,465 | −8.26% |
| | YJIT 4.0.9 | 20,624 | −0.02% | 17,435 | −15.47% |
| | ZJIT master | 26,896 | −0.00% | 23,936 | −11.0% |

**Wall time per call** (Ruby 4.0.9, medians of 15 pinned rounds):

| Case | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `escape_segment("my-first-post-about-rails")` | interpreter | 608 ns | −0.7% | 378 ns | −37.8% |
| | YJIT | 541 ns | −0.1% | 317 ns | −41.4% |
| `escape_segment("123")` | interpreter | 313 ns | −0.0% | 283 ns | −9.6% |
| | YJIT | 249 ns | +0.7% | 216 ns | −13.2% |
| `page_path("my-first-post-about-rails")` | interpreter | 4,870 ns | +0.7% | 4,777 ns | −1.9% |
| | YJIT | 2,767 ns | +0.3% | 2,449 ns | −11.5% |
| `post_path(post)` | interpreter | 4,178 ns | +0.4% | 4,155 ns | −0.6% (not resolved) |
| | YJIT | 2,196 ns | +2.0% | 2,156 ns | −1.8% (not resolved) |

**ruby-bench** (Callgrind instructions for one iteration; `UriEncoder#escape` calls per iteration counted with a
TracePoint):

| App | Calls | Mode | main1 | main2 (A/A) | candidate | Δ |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| railsbench | 9,670 | interpreter | 6,950,191,700 | −0.025% | 6,948,265,307 | −0.028% |
| shipit | 2,442 | interpreter | 5,839,154,248 | −0.003% | 5,831,810,569 | −0.126% |
| lobsters | 737 | interpreter | 4,261,795,605 | +0.057% | 4,264,879,463 | +0.072% |
| railsbench | 9,670 | YJIT | 4,369,558,264 | +0.091% | 4,369,796,171 | +0.005% |
| shipit | 2,442 | YJIT | 3,159,457,849 | −0.021% | 3,149,747,378 | −0.307% |
| lobsters | 737 | YJIT | 3,031,921,235 | −0.106% | 3,025,897,376 | −0.199% (not resolved) |

All within the noise between variants (about ±0.07% interpreted, up to ±0.1% with YJIT, where lobsters' own A/A is −0.11%) except shipit, whose −7.3M instructions would fit 2,442
calls at about 3,000 each, the micro's saving for a slug. railsbench's
segments are mostly numeric ids (`/posts/:id`), which save about 350 each in the micro, about 3.4M per iteration,
below that noise.

## PR bodies (drafts, not opened)

Checked by a separate reviewer against this page and for an outsider's reading; its corrections are applied.

### CP-3: Resolve attribute aliases with a fetch default instead of a block

> Active Record looks up a column's type with `type_for_attribute` several times for each condition in `where`, and on association reads, creates and updates; `Post.where(title:, published:).to_a` calls it eight times. Each lookup first resolves an alias with `attribute_aliases.fetch(super, &:itself)`. For the usual name without an alias, `fetch` then calls its block, and `&:itself` makes that a `Symbol#to_proc` call, which costs more than the lookup itself.
>
> This passes the resolved name as `fetch`'s default instead: `attribute_aliases.fetch(name = super, name)`. It is still `fetch`, so a Hash default or a stored `nil` is treated as before, and the receiver is still read before `super` converts the name, so even a `to_s` that defines an alias sees the same table. Rails already assigns inside a `fetch` argument this way in `calculations.rb`.
>
> | `Post.type_for_attribute("title")`, per call | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: |
> | main | 641 ns | 384 ns | 5,455 | 3,769 | 3,243 |
> | this PR | 561 ns (−12.5%) | 293 ns (−23.7%) | 4,788 (−12.2%) | 2,925 (−22.4%) | 2,305 (−28.9%) |
> | main, run again (change from the first run) | +1.3% | +0.3% | −0.00% | −0.13% | +0.04% |
>
> Objects per call are unchanged. Ruby 4.0.9, SQLite in memory, GC disabled; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/common_paths_2/micro.rb)). Times are medians of 15 runs in rotating order on one CPU; instructions are Callgrind's count for 3,000 calls minus its count for none, divided by 3,000, median of three runs. The two-condition `where` above runs 0.47% fewer instructions interpreted and about 1.4% fewer with YJIT. On ruby-bench (Rails 8.1 with the method patched in), shipit (about 21,600 lookups per iteration) runs 0.11% fewer instructions per iteration with the interpreter; railsbench makes no lookups and still moves by up to 0.08% between two builds, so lobsters' 0.06% is not resolved. In a CPU census of 20 open-source Rails apps on Rails main, this lookup ran in all 20 and took 0.18% of interpreted instructions (0.39% with YJIT); I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-common-paths-2.md)).

### CP-5: Check URL components for unsafe characters with an anchored match

> Every URL helper escapes each dynamic segment through `UriEncoder#escape`, and since #59058 it returns a segment as is when nothing in it needs escaping, which is nearly always (ids, slugs). It finds that out by searching for an unsafe character with a negated class such as `/[^...]/`, which the regexp engine tries again from every position.
>
> This matches the whole component against the safe characters instead, with `/\A[...]*\z/` built from the same character lists, as `xml_name_escape` does with `SAFE_XML_TAG_NAME_REGEXP`. For every valid string in an ASCII-compatible encoding, one pattern matches exactly when the other doesn't; invalid bytes and incompatible encodings raise the same errors in both, and components that need escaping go through the same `gsub` as before. Measured in wall time, only components longer than about 600,000 characters take longer than before (2–3×), so with a global `Regexp.timeout` such components time out sooner; URL components that long don't occur in practice. The new tests check that safe components come back as the same object and that every ASCII character gives the same result through the early return as through escaping, so a safe pattern narrower or wider than its escaping pattern fails them. As before, a component that overrides `match?` itself can change the result, now in the opposite direction.
>
> | `page_path("my-first-post-about-rails")` (`get "/pages/:slug"`), per call | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: |
> | main | 4,870 ns | 2,767 ns | 37,570 | 20,624 | 26,896 |
> | this PR | 4,777 ns (−1.9%) | 2,449 ns (−11.5%) | 34,465 (−8.3%) | 17,435 (−15.5%) | 23,936 (−11.0%) |
> | main, run again (change from the first run) | +0.7% | +0.3% | +0.10% | −0.02% | −0.00% |
>
> Objects per call are unchanged. Ruby 4.0.9, GC disabled; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/common_paths_2/micro_url.rb)). Times are medians of 15 runs in rotating order on one CPU; instructions are Callgrind's count for 3,000 calls minus its count for none, divided by 3,000. `escape_segment` itself runs 42% fewer instructions for that slug and 11% fewer for `"123"` (interpreter), and `post_path(post)` with an id 1.1% fewer interpreted and 2.5% fewer with YJIT, against A/As of 0.13% and 0.26%. On ruby-bench (Rails 8.1 with the method patched in), only shipit moves clearly beyond the noise between two builds (up to 0.1% here): 0.13% fewer instructions per iteration with the interpreter and 0.31% fewer with YJIT. railsbench's 9,670 escapes per iteration are numeric ids, which save about 350 instructions each, about 0.05% of an iteration. In a CPU census of 20 open-source Rails apps on Rails main, this check ran in 12 and took 0.10% of interpreted instructions; I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-common-paths-2.md)).

## Rejected and not built

| Site | Numbers | Why not |
| --- | --- | --- |
| CP-4: `apply_seconds_precision` (Active Model `time_value.rb`, every datetime cast and timestamp write) with `value.floor(precision)` for a `::Time` instead of `change(nsec:)` | cast −15% to −22% instructions, 18 → 14 objects; `create` −1.1% interpreted | **Not exact.** A 1.2M-pair differential found 6,656 differences, all on Ruby `Time` values whose zone is a TZInfo object (`getlocal(tz)`) near DST changes: 2,820 with a different `dst?`, 3,836 where main raises `TZInfo::AmbiguousTime` and the candidate returns a value. TimeWithZone, UTC, local and fixed-offset values showed none. Restricting it to those would need a type branch (L2) for a ~1% effect. |
| Correctness lead from CP-4 (not a performance candidate): on main, casting a `Time` in a TZInfo zone during the fall-back hour raises | `Time.at(...).getlocal(TZInfo::Timezone.get("Europe/Berlin"))` at 2026-10-25 02:30:00.001234567 +02:00: `change(nsec: 1234000)` raises `TZInfo::AmbiguousTime`; `floor(6)` returns 02:30:00.001234 +02:00 | Such values are rare in apps (Rails hands out TimeWithZone). Recorded; not filed (Thomas first). |
| `Tryable#try(*args, **kwargs, &block)` (Active Support) | 2 objects per call; `NilClass#try(*, &)` 1; a `(...)` signature 0 | Lead only, not built or measured on apps this round. |
| A second alias lookup in `where`: `Arel::Table#[]` resolves the alias, then `type_for_attribute` resolves it again | | Reviewer hypothesis, not measured; would change two files and a call contract. Not built. |
| QueryAttribute#hash, LazyAttributeSet#keys and attribute sets, ParameterFilter, structured events | | Covered by open PRs (rails/rails#59518, #59141, #58958, #58957). |
| `String#blank?` | | Optimized upstream recently. |
| `apply_inflections`, `IsolatedExecutionState`, `handler_for`, `view_assigns`, the `path_for` copy, Time#change Rationals, `xml_name_escape`, `ensure_valid_html5_tag_name`, C8-2 | census 8, round 1 | Unchanged dispositions. |

## Upstream search

Searched rails/rails PRs and issues (open and closed) for `resolve_attribute_name`, `attribute_aliases fetch`,
`type_for_attribute alias`, `escape_segment`, `UriEncoder`, `match? escape journey`, `apply_seconds_precision`,
and checked every file our seven open PRs touch. Related only: #59058 (merged, added the early return CP-5 builds
on), #58176 (merged, removed unused `UriEncoder` constants), #58512 (open, `redirection.rb` only), #16416 (closed,
2014); for CP-4 #27185, #20317, #40151 (merged, older behavior fixes) and issues #41316, #48802. Nothing on
either candidate's line.

## Limits

* Per-call instruction counts on micro cases and SQLite in memory, not request time. ruby-bench runs Rails 8.1 with
  the method patched in by the harness.
* Wall time is from one orb, with Callgrind runs on other CPUs during part of it; it supports per-call claims only.
* Reviews were subagents, not the Sol/Astra reviews DECISIONS names.
* MySQL, Trilogy and PostgreSQL suites were not run for CP-3 (no server in this orb); the change is in Active Model
  and adapter-independent.
* Receipts: [data/rails-common-paths-2/receipts.tar.gz](data/rails-common-paths-2/receipts.tar.gz) (every Callgrind
  log, `ns.tsv`, ruby-bench logs, suite logs, review and adversarial probe scripts and outputs, the CP-4 runs).
  [`dtp_dst_repro.rb`](../../bench/upstream/common_paths_2/dtp_dst_repro.rb) is the CP-4 DST repro;
  [`lowrail_count.rb`](../../bench/upstream/common_paths_2/lowrail_count.rb) counts calls per ruby-bench iteration.
