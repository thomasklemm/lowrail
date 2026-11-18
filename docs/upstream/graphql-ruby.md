# graphql-ruby parser cost (2026-11-05)

ruby-bench's graphql-native moved from graphql-c_parser 1.1.3 to 1.2.0 in #568 (see
[ruby-bench-improvements.md, round 3](ruby-bench-improvements.md#graphql-native-on-windows-graphql-c_parser-120-in-568))
and got about 2% more interpreter instructions per iteration. This page splits that cost by commit, checks the
pure-Ruby parser that most apps use (graphql without c_parser) the same way, and records the two exact speedups
I found, plus what I rejected.

Setup for every number: Ruby 4.0.9 interpreter (no JIT), Cachegrind `--cache-sim=no`, fixed heap
(`RUBY_GC_HEAP_0..4_INIT_SLOTS` = 1000000/250000/100000/20000/10000). Each number comes from two processes with
different iteration counts subtracted, so boot and warm-up cancel out. Every revision ran in two separate processes
(A/A). Scripts and raw outputs are in [bench/upstream/graphql_ruby](../../bench/upstream/graphql_ruby).

## C parser: 1.1.3 → master, per commit

Document: ruby-bench's `negotiate.gql`, 100 parses per iteration. Per-iteration Ir = (Ir(6 iterations) − Ir(1)) / 5,
then the mean of two processes. Each revision builds only the extension (`build.sh`) and runs against the same
graphql 2.5.11. Every non-merge commit that touched `graphql-c_parser/ext` was measured, each against its own parent
(the history has branches, so the previous commit in the list is not always the parent; `cparents.txt`).

| commit | change | Ir / iteration (parent → commit) | vs parent |
| --- | --- | ---: | ---: |
| f794520ccd | `YYSTACK_USE_ALLOCA 1` (1.1.4) | 2,601,880,291 → 2,600,384,730 | −0.06% |
| 76d24488ba | short braced Unicode escapes | 2,600,384,730 → 2,600,719,186 | +0.01% |
| 002e47351f | exponent-only floats | 2,600,719,186 → 2,600,629,240 | −0.00% |
| eca210d141 | `(void)` prototypes, `NORETURN(yyerror)` | 2,603,668,408 → 2,609,845,090 | +0.24% |
| **a679c9dff8** | **byte order marks (#5849)** | 2,609,884,144 → 2,653,273,536 | **+1.66%** |
| fa4a459f92 | numeric token boundaries | 2,654,429,130 → 2,657,310,350 | +0.11% |
| d0410c693e | no variables in default values | 2,654,429,130 → 2,653,994,316 | −0.02% |
| 115a3c84e5 | Windows renames (#5877) | 2,660,388,252 → 2,656,735,471 | −0.14% |

1.1.3 → master is +2.11% (2,601,880,291 → 2,656,735,471). a679c9dff8 is the only step clearly above noise. The
rest is spread over merges and steps of ±0.2%, which is the A/A spread of these runs (1.1.3 −0.002%, but up to 0.19%
for the merge parents).

- **a679c9dff8, +1.66% (+44M Ir per iteration, all in `tokenize`).** `BLANK = ([, \t] | 0xEF 0xBB 0xBF)+` puts the
  three-byte BOM inside the blank repetition. The char-class table then starts at −69 instead of 9, and every blank
  byte becomes a state the scanner may back up to, so it stores the token end on each one. The growth is on
  `lexer.c` lines 1031/1046/2064 (char-class lookup, action switch, EOF check). Not inherent: see candidate B.
- **eca210d141, +0.24% (+6.2M per iteration).** A per-function profile against 002e47351f puts the growth in `yyparse`. The diff only adds `(void)` prototypes and `NORETURN` on
  `yyerror`. The extra instructions come from GCC laying out `yyparse` differently, not from new work (my reading of
  the per-line profile). No source-level fix; recorded only.
- **fa4a459f92, +0.11%.** The number-boundary check in `emit` runs on every number token. It is a correctness fix and
  already a single lookahead, so I left it alone.
- **f794520ccd (alloca), 1.1.4.** Deliberate for deep documents, and flat here. Not touched.
- The Bison regeneration itself (rules 185 → 191) shows up only as the steps above; there is no separate cost.

## Ruby parser: 2.5.11 → master, per commit

Four documents per process: `negotiate.gql`, graphql-ruby's `big_query`, the introspection query and a mutation
with variables. Per-iteration Ir = (Ir(3) − Ir(1)) / 2. I measured 38 commits between 2.5.11 and master
(`rbrevs.txt`, `rbtable.txt`), then measured each commit with a step against its own parent, because the list
mixes branches. Master needs **+23.98%** more Ir than 2.5.11 (per document: negotiate +21.4%, big_query +22.8%,
introspection +22.1%, mutation +27.4%).

| commit | change | Ir vs its parent |
| --- | --- | ---: |
| **2a8d95680b** | count comments toward `max_tokens` (security fix, 2.6.1) | 649,837,166 → 797,611,358, **+22.74%** |
| a679c9dff8 | `\uFEFF` added to `IGNORE_REGEXP` (#5849) | 796,360,369 → 804,492,560, +1.02% |
| everything else | | within ±0.16% (list order) |

1.2274 × 1.0102 = 1.2399, which is the whole +23.98%. In `rbtable.txt`'s list order, 0aea1c2f11 shows −1.09% and
ba827bb272 +1.01%: that's an ordering artifact. Against their own parents they are +0.01% and −0.01%.

- **2a8d95680b.** Before it, comments were part of one `IGNORE_REGEXP`. It made `Lexer#advance`
  `loop do; skip(IGNORE); if skip(COMMENT) … next; end; break; end`. Two costs per token: `loop` runs its body as a
  block and `break` leaves it by throwing through the VM (master's profile: `vm_exec_handle_exception` 93.0M Ir,
  `vm_invoke_iseq_block` 37.8M, `vm_throw_start` 30.7M; `loop`'s `rescue StopIteration` costs nothing unless
  raised), and a failing `COMMENT_REGEXP` match on every token. The counting itself is the security fix and stays.
  Not inherent: see candidate A.
- **a679c9dff8, `\uFEFF` in `IGNORE_REGEXP` (+1.02%).** A multibyte character in the class makes Onigmo match
  it more slowly. It is part of the BOM fix. Variant V3 below tried a different regexp and saved nothing on top of
  V2, so I didn't pursue it further.

## Candidates

### A. Ruby lexer: `loop` in `advance`

Branch [`thomasklemm/lexer-advance-without-loop`](https://github.com/thomasklemm/graphql-ruby/tree/thomasklemm/lexer-advance-without-loop)
@ `dd6632b412`, one commit on master `095162a3e4`:

```ruby
@scanner.skip(IGNORE_REGEXP)
while @scanner.skip("#")
  @scanner.skip(COMMENT_BODY_REGEXP)   # /[^\n\r]*/
  @tokens_count += 1
  ... same limit check ...
  @scanner.skip(IGNORE_REGEXP)
end
```

- **Ir:** master 805,533,361 / 805,576,870, branch 673,055,728 / 673,031,475, so **−16.45%** (A/A ≤0.01%). That takes
  back about 90% of 2a8d95680b's +147.8M. Per document −14.6% / −16.0% / −15.6% / −17.9%.
- **Wall, my script** (`wall-S.txt`, four alternating pairs, pinned CPU): faster in all 12 pairs; medians
  introspection 221.0 → 180.8 µs, big_query 1347 → 1088 µs, mutation 168.6 → 136.9 µs (−18 to −19%).
- **Wall, graphql-ruby's `rake bench:parse`** (`bench-parse-S.txt`, two alternating rounds): introspection 4.35–4.42k →
  5.39–5.45k i/s, fragments 5.88–5.99k → 7.31–7.34k, big query 726–736 → 923.
- **Exactness:** `rbprobe.rb` (34 inputs: comments, BOMs, CR, EOF, the four documents with and without comments ×
  `max_tokens` nil/3/5/12/40) is byte-identical to master. A failed String-pattern `skip` clears the match register
  like a failed regexp `skip` (strscan `strscan_do_scan` calls `CLEAR_MATCH_STATUS` first, in 1.0.3 shipped with Ruby
  2.7 and in 3.1.6), so the state at end of input matches master. Only the last match *inside* a comment differs
  (`#`, then the body), and nothing reads it. `rake test` 2,715 tests, 0 failures; `SERIAL=1 GRAPHQL_CPARSER=1 rake
  test` 2,705 tests, 0 failures (the parallel C run hit the two known `async_dataloader_spec.rb:300` timing flakes).
  rubocop and `srb tc` clean. `language.rb:69/76` already use `scanner.skip("\n")`, so String patterns are established.
- **First version V1** (`while skip(COMMENT_REGEXP)`, no String check): −9.58%. The reviewer found the String check;
  V1 is superseded.
- **Rejected V2** (V1 plus a `getbyte(pos) == ?#` guard): −14.78%, but the guard skips the failed match, so
  StringScanner's last match at end of input differs and `parser_spec.rb:446` fails (`UNKNOWN_CHAR (" ~")`).
- **Rejected V3** (V2 plus a different `IGNORE_REGEXP`): −12.9%, same failure.

### B. C lexer: byte order marks in `BLANK`

Branch [`thomasklemm/c-lexer-bom-scanner-rule`](https://github.com/thomasklemm/graphql-ruby/tree/thomasklemm/c-lexer-bom-scanner-rule)
@ `097c2461d0`, one commit on master `095162a3e4`: `BLANK = [, \t]+; BOM = 0xEF 0xBB 0xBF;` and a `BOM` action
identical to BLANK's.

- **Ir (committed build):** master 2,656,140,128 / 2,656,962,829, branch 2,621,101,129 / 2,621,105,286, so
  **−1.33%** (A/A 0.03%). That takes back most of a679c9dff8's +1.66%. The char-class table still starts at −69
  (the BOM bytes are still in the alphabet), which likely explains the part not recovered.
- **Exactness:** `bomprobe.rb` (34 inputs with BOMs in and around tokens, numbers, strings, comments, truncated BOMs,
  the four documents with BOMs between words, each with and without `reject_numbers_followed_by_names`; tokens,
  positions, ASTs, errors): 17,362 lines, byte-identical to master. `GRAPHQL_CPARSER=1 rake test` on its own:
  2,705 tests, 0 failures, 4 skips. The reviewer also ran a seeded differential fuzz of 200,000 strings (BOM fragments,
  blanks, numbers, names, quotes, `#`, CR/LF) through the lexer with reject on/off, `max_tokens` 2^29 and 3, and the
  parser: all 600,000 output lines identical.
- **Mechanism, from `ragel -V`:** on master, BLANK's state has `SP / te, store41` on each blank byte
  (`te = p+1; act = 41`); on the branch the blank bytes are bare self-loops and `{act = 41;}` is gone.
- **`lexer.c`:** Ragel 7.0.4 on the new `lexer.rl`, applied with `apply_ragel_diff.py` the same way as #5877: content
  equals Ragel's output, `lexer.rl` `#line` numbers match Ragel's, `lexer.c` self-references follow the file's
  existing rule (line + 1).

## graphql-ruby's own benchmarks

`rake bench:parse` and `bench:scan` (benchmark/run.rb, benchmark-ips) parse/scan the introspection query, a fragment
query and the big query. benchmark/track.rb tracks "parse - introspection" and "parse - big query" on every master
push (`.github/workflows/benchmarks.yaml`, Ruby 3.4) and charts them at rmosolgo.github.io/graphql-ruby-benchmarks.
I used `bench:parse` for candidate A's wall time above. It doesn't load the C parser, so it can't show B.

## Review

A skeptical reviewer subagent checked both patches, bodies and this page. Applied: the String-pattern comment check
(−16.4% instead of V1's −9.6%), the corrected mechanism (`break`'s throw, not a `rescue`), how much A takes back,
B's "token end and rule" wording and trim. Confirmed: both patches exact (probes, fuzz for B, StringScanner call
sequence for A including the limit hit exactly on a comment), B's `lexer.c` equals Ragel 7.0.4's output modulo
whitespace and `#line`, the `#line` rules, all numbers and references.

Unrelated, already on master: `CParser.tokenize_with_c` (`graphql-c_parser/lib/graphql/c_parser.rb:20`) calls the
4-argument C function with 3 arguments, so it would raise `ArgumentError`. Not reported upstream.

## Bodies and state

Neither PR is open; both wait for a go. Bodies:
[ruby-lexer-body.md](../../bench/upstream/graphql_ruby/ruby-lexer-body.md),
[c-lexer-bom-body.md](../../bench/upstream/graphql_ruby/c-lexer-bom-body.md).

# graphql-ruby execution and validation (2026-11-05, round 2)

After #5880 and #5881 merged (master `2e8473ea7d`), I profiled what graphql-ruby does beyond parsing: static
validation, schema and type lookup, and execution with both engines (the classic `Execution::Interpreter` and
`Execution::Next`), plus a realistic app workload (Zammad). Outcome: one candidate, GQ1, which is **held**. It is a
behaviour change, not an exact speedup. Nothing else cleared the bar. Scripts and raw outputs are in
[bench/upstream/graphql_ruby/exec](../../bench/upstream/graphql_ruby/exec) and
[apps](../../bench/upstream/graphql_ruby/apps).

Setup: the same as round 1. Ruby 4.0.9 interpreter, Cachegrind `--cache-sim=no`, fixed heap, two process counts
subtracted, every revision in two processes (A/A).

Workloads:
- `exec/ex.rb` runs the scenarios graphql-ruby tracks on every master push (`benchmark/track.rb`: validate abstract
  fragments, big query and fields-will-merge; `execute_next` introspection, small query on the large schema and
  large result), the same documents with the legacy interpreter, and `rake bench:validate`'s documents.
- `exec/ver.rb` runs version-portable workloads on graphql-ruby's benchmark schemas plus a small 500-object schema.
  It loads any `lib` directory (2.5.11 … master).
- The Zammad replay is described below.

## Profile (master)

Inclusive Ir per iteration, with self time from callgrind and stackprof wall mode:

| scenario | Ir / iteration | where |
| --- | ---: | --- |
| validate - fields will merge (5000 × `hello`) | 227.3M | `Warden#get_field` 51% incl., `FieldsWillMerge#collect_fields_inner`, `Schema.use_visibility_profile?`, `Module#ancestors`, `respond_to?` |
| validate - big query | 35.1M | `on_field` 63% incl.; `Warden#read_through` blocks 39%, `ObjectMethods#get_field`, `visible_and_reachable_type?`, `FieldsWillMerge` |
| validate - abstract fragments (1/2) | 2.3M / 3.5M | the same Warden lookups; `Schema.default_logger` builds a `Logger.new($stdout)` per query (3% wall) |
| execute_next - introspection | 52.0M | spread over the steps (Execution::Next, ydah's open #5696 works here) |
| execute_next - small query on large schema | 0.82M | query setup, validation pipeline, `default_logger` (10% of wall on this orb, `File.exist?` in `Logger::LogDevice`) |
| execute_next - large result | 286M | `FieldResolveStep`, result hashes; no single hot spot |
| interpreter - large result | 1,136M | `continue_field`, `after_lazy`, `Lazy#initialize` (the benchmark's `lazy_resolve Proc`) |
| Zammad replay, 8 desktop queries | 374M / round | ActiveRecord 27%, graphql 24%, Psych 4% (Zammad's YAML); graphql's share is `evaluate_selection*`, `Field#resolve`, extensions; `Warden#get_field` 3% |

The finding: `Warden#get_type` and the inner hash of `Warden#get_field` cache by name with
`compare_by_identity` (since 1c51c36031, 2023, which made every `read_through` identity-keyed). Each AST node
carries its own name String, so these caches miss on every node, and every field node repeats
`Schema.get_field` plus the visibility checks. `exec/probe_cache.rb`: `{ hello hello hello }` calls
`Schema.get_field` 3 times, and once with GQ1. `Visibility::Profile` (profile.rb L120–153) already caches names
by value.

## 2.5.11 → master, validation and execution

`exec/versions.txt`, per-iteration Ir, change against 2.5.11:

| | v2.6.0 | v2.6.14 | master |
| --- | ---: | ---: | ---: |
| validate big query | −30.5% | −26.8% | −27.5% |
| validate introspection | −16.2% | −15.6% | −17.8% |
| validate abstract fragments (1/2) | −6.9% / −6.0% | −5.4% / −4.3% | −6.7% / −5.3% |
| execute, big schema introspection (interpreter) | +1.52% | +1.14% | +1.15% |
| execute, 500-object result (interpreter) | +0.57% | +1.03% | +0.95% |
| execute, small query (interpreter) | −6.2% | −6.3% | −7.8% |

Validation got much cheaper. The only increases are about 1% in execution. I bisected the big-schema
introspection along the 82 first-parent commits that touch `lib` between 2.5.11 and 2.6.0 (`exec/bisect-execution.txt`,
one process each; the noise between neighbours is about ±0.3%):

- **#5509 (12f70632df, "New Execution Module"), +2.41%.** It gives the built-in introspection fields `resolve_each:`
  class methods for Execution::Next, and the instance methods now delegate to them (`def kind =
  self.class.resolve_kind(object, context)`). The extra call per introspection field is the cost on the legacy
  interpreter. Undoing it means duplicating each method body (L3). Not pursued.
- #5491 (215e7fa464), −2.20%, a speedup.
- #5425 (gmac, cardinal runtime shim), +0.68%. Everything else is ±0.5%.

## GQ1: Warden name caches compare by value (held)

Branch [`thomasklemm/warden-name-caches`](https://github.com/thomasklemm/graphql-ruby/tree/thomasklemm/warden-name-caches)
@ `4337055468`, one commit on master `2e8473ea7d` (measured as `6a147b445e`, which differs only in the helper's comment). The `@visible_types` cache and the inner per-type hash of
`@visible_parent_fields` use a `read_through_by_name` helper, the same Hash without `compare_by_identity`. Described
out loud: "look up a type by its name; look up a field by its owner type, then by its name; a name is compared by
its characters, as in Visibility::Profile; owner types are still compared by identity."

Ir per iteration, master → GQ1 (each revision A/A ≤ 1.7%, `exec/candidate-tracked.txt`, `candidate-ver.txt`):

| tracked scenario | master | GQ1 | |
| --- | ---: | ---: | ---: |
| validate - fields will merge | 227,437,348 | 129,124,527 | **−43.2%** |
| validate - big query | 35,072,813 | 32,434,907 | **−7.5%** |
| validate - abstract fragments | 2,355,532 | 2,149,616 | **−8.7%** |
| execute - introspection (Next) | 52,073,540 | 51,455,744 | −1.2% |
| execute - small query on large schema | 812,372 | 810,841 | −0.2% (A/A 1.7%) |
| execute - large result | 285,771,223 | 285,995,762 | +0.08% |

- Legacy interpreter: Jazz introspection +0.11% (A/A 0.08%). Big-schema introspection (`ver.rb`) is **+0.56%**
  (A/A 0.13%): during execution the identity cache already hit for repeated nodes, and hashing the String costs more.
- Zammad replay: 374.2M → 371.8M Ir per round, **−0.64%** (master A/A 0.32%, GQ1 0.05%).
- Rejected variant c2: a value cache behind an identity cache (`read_through { |name| by_value[name] }`). It removes
  the +0.56%, but keeps only −40.6% / −5.7% / −5.4% on validation and costs +1.7% on the small query (two more
  Hashes per Warden), and it is harder to read.

**Why held.** The skeptic pass found a real difference. Overriding `.get_field` on a type is a documented hook
(guides/schema/dynamic_types.md), and the Warden is the default. With GQ1, `.get_field` and `Schema.get_type`
overrides run once per name per query instead of once per AST node. When a resolver changes the context that such an
override reads, a field selected through an interface in two places resolves differently (`exec/exprobe2.rb`):
master `{"a":{"staffName":"staff"},"dropStaff":true,"b":{"staffName":"alt"}}`, GQ1 `… "b":{"staffName":"staff"}`.
`exec/hookprobe.rb`: three `thing { name }` aliases call `Thing.get_field` 3 times on master and once on GQ1.
Everything else is identical: the probe `exec/wprobe.rb` (7 documents × 4 visibility contexts: results, validation
errors, 52 deprecation warnings, `visible?` hook counts) is byte-identical on master and GQ1 with both parsers, because
`@visibility_cache` stays identity-keyed. Encodings, Symbols, frozen and mutated keys behave as on master (the
skeptic checked each). The guide's statement "GraphQL-Ruby caches schema elements for the duration of the operation"
and Visibility::Profile's caches have GQ1's semantics, so rmosolgo may well want it, but it needs his call as a
behaviour change, not an exact performance PR.

Tests: `rake test` 2,715 tests, 4 failures, all dataloader timing asserts (`async_dataloader_spec.rb:300` twice,
`nonblocking_dataloader_spec.rb:174/209`) under a loaded orb; `SERIAL=1 GRAPHQL_CPARSER=1 rake test` 2,705 tests,
1 failure (`async_dataloader_spec.rb:300`). rubocop and `srb tc` clean.

### Draft issue for rmosolgo (2026-11-18, not posted)

Checked first: master `9c9f8f2` (2026-11-17) and the released 2.6.16 still have the identity-keyed `read_through`
in `Warden#get_type`/`#get_field`; no open or closed issue or PR raises it (the nearest is rmosolgo's own
[#5035](https://github.com/rmosolgo/graphql-ruby/issues/5035), "Audit `compare_by_identity` usage", closed; open PRs
touching warden/visibility are #5905, #5865, #5821, all unrelated).

Draft: [gq1-issue/issue.md](../../bench/upstream/graphql_ruby/gq1-issue/issue.md) (171 words of prose plus the
script). The probe [probe.rb](../../bench/upstream/graphql_ruby/gq1-issue/probe.rb) runs against the released gem
(`gem install graphql -v 2.6.16`), patches the Warden with GQ1's lookup and prints
([probe.txt](../../bench/upstream/graphql_ruby/gq1-issue/probe.txt), Ruby 4.0.9; the ms are one wall-clock run):

```
graphql 2.6.16, Ruby 4.0.9
as released:
  validate 5000 x alt: Thing.get_field called 5000 times, 26.8 ms
  {"a":{"staffName":"staff"},"dropStaff":true,"b":{"staffName":"alt"}}
  Thing.get_field("staffName") called 2 times
names cached by value:
  validate 5000 x alt: Thing.get_field called 1 times, 9.9 ms
  {"a":{"staffName":"staff"},"dropStaff":true,"b":{"staffName":"staff"}}
  Thing.get_field("staffName") called 1 times
```

The difference needs the field selected through the interface (`node { staffName }`); with `... on Thing` both
revisions answer `staff`.

**For Thomas.** Die Warden von graphql-ruby merkt sich Typ- und Feld-Lookups pro Name, vergleicht den Namen aber nach
Objektidentität. Jeder Knoten im Query-Dokument hat seinen eigenen String, also trifft der Cache nie, und jedes
`hello` im Dokument fragt das Schema erneut. Nach Wert verglichen wird Validierung 7,5–43% billiger. Der Haken: Apps
dürfen `.get_field(name, context)` auf einem Typ überschreiben (dokumentierter Hook), und der liefe dann nur noch
einmal pro Name und Query statt einmal pro Knoten. Ändert ein Resolver mitten in der Query den Context, sieht der
Hook die Änderung nicht mehr (im Skript: `b` liefert `staff` statt `alt`). Die Frage an rmosolgo: Ist „einmal pro
Name und Query“ der gewollte Hook-Vertrag (der Guide sagt schon, Schema-Elemente würden pro Operation gecacht) und
nimmt er dann den PR, oder will er die Aufrufe pro Knoten behalten oder eine andere Form? Zu entscheiden: ob das Issue
so gepostet wird. Ein neues Issue braucht dein OK (DECISIONS, Upstream etiquette).

Superseded the same day by the PR below (Thomas wants a PR, not an issue); the issue is not posted.

### GQ1 as a pull request (2026-11-18)

Branch [`thomasklemm/warden-name-caches-by-value`](https://github.com/thomasklemm/graphql-ruby/tree/thomasklemm/warden-name-caches-by-value)
@ `4a77cd59bf`, one commit on master `9c9f8f28cc` (2026-11-17), queue item
[GQ1](../../bench/upstream/pr-queue/items/GQ1.md) (`in-review`, `risky`; Astra requires changes below). Not
opened. Data: [gq1-pr](../../bench/upstream/graphql_ruby/gq1-pr).

The builder's rationale and original verification follow. The [Astra review](#gq1-astra-review-2026-11-18)
corrects its Profile-equivalence and test-policy conclusions; those original claims are not approval evidence.

**Who it reaches.** Master still validates and executes through the Warden by default: `Schema.use_visibility_profile?`
is false unless the schema has `use GraphQL::Schema::Visibility` (schema.rb L857–865; `Query#prepare_ast` builds
`schema.warden_class.new`, query.rb L599), and the install generator's schema template doesn't add
it. `Visibility::Profile` replaces the Warden only for schemas that opt in. So the change reaches every schema that
hasn't migrated to `Visibility`. The body says so in one sentence.

**Shape.** I looked for an exact variant a maintainer would accept, such as keeping per-selection calls when a type
overrides `.get_field` or the schema overrides `get_type`. It would need an override check on every type's method
owner (and on app base classes that include their own modules), which is a guard rmosolgo wouldn't write
(DECISIONS, guards in the target repository's idiom). His own code sets the precedent for fields only:
master's `Visibility::Profile#@cached_parent_fields` calls `type.get_field(field_name, @context)` once per name per
profile, by value (profile.rb L119–123), and #5586 (merged by rmosolgo 2026-03-25) added by-value type and field
result caches. Profile does not call `Schema.get_type` overrides at all (`compute_type` goes through
`Visibility#get_type`), so it is no precedent for that hook; `gm-visibility.hookprobe.txt` shows no `Schema.get_type`
call where the head shows one. *Corrected after Astra: an earlier version of this paragraph said master with
Visibility gives exactly the head's answers and call counts, which the retained logs contradict.* So the plain by-value cache stays, and the body states the hook contract change in one sentence.
The helper is `read_through_by_name`, next to `read_through`, without a comment (the test protects it); the earlier
branch's one-line comment is gone. Described out loud: "look up a type by its name; look up a field by its owner
type, then by its name; names are compared by their characters, owner types by identity."

**Test (first head `4a77cd59bf`, replaced in the fix round below).** `warden_spec.rb`, `describe "#get_type and #get_field"`, beside rmosolgo's own `#loadable_possible_types`
spec (42f9fab995) and in its style: a schema with `self.use_visibility_profile = false`, a type overriding
`.get_field` and a schema overriding `.get_type`, both recording the names they are asked for in the query context;
validating `{ a: thing { ... on Thing { name } } b: thing { ... on Thing { name } } }` must ask for `name` once and
`Thing` once. On master it fails with `["name", "name"]`; with only the `get_type` half reverted it fails with
`["Thing", "Thing", "Thing", "Thing"]`, so each half is covered. It counts calls of the two documented hooks, which
is the contract this changes, not internal state (DECISIONS, tests check behaviour).

**Tests on the first head.** `SERIAL=1 rake test`: 2,735 tests, 0 failures, 13 skips. `SERIAL=1 GRAPHQL_CPARSER=1`: 2,783,
0 failures. `SERIAL=1 GRAPHQL_FUTURE=1`: 2,735, 0 failures. rubocop on both files and `srb tc` clean. Ruby 4.0.9.

**Differential probes** (`gq1-pr/probes/`, master vs head): `exec/wprobe.rb` (results, validation errors,
deprecation warnings, `visible?` hook counts; 3,199 lines) byte-identical with the Ruby and the C parser.
`exec/exprobe2.rb` and `exec/hookprobe.rb` differ only as expected: `.get_field`/`Schema.get_type` run once per name
per query, and in exprobe2 `b` answers `staff` instead of `alt`. master with `Visibility` answers like the head.

**Callgrind on the exact head** (`gq1-pr/table.txt`, raw per-process totals in `raw.txt`, top functions of
val_merge and exe_intro_big in `annotate-*`). Ruby 4.0.9 interpreter, fixed heap, per-iteration Ir from two
iteration counts, two processes per revision (A/A):

| scenario | master (A/A) | head (A/A) | change |
| --- | ---: | ---: | ---: |
| validate - fields will merge (tracked) | 226,793,625 (0.10%) | 129,171,347 (0.11%) | **−43.04%** |
| validate - big query (tracked) | 35,254,826 (0.05%) | 32,607,049 (0.06%) | **−7.51%** |
| validate - abstract fragments (tracked) | 2,382,214 (0.99%) | 2,195,050 (0.28%) | **−7.86%** |
| validate - introspection (`bench:validate`) | 3,741,024 (0.19%) | 3,276,698 (1.11%) | −12.41% |
| execute - introspection (tracked, Next) | 51,788,972 (0.09%) | 51,300,579 (0.04%) | −0.94% |
| execute - small query on large schema (tracked) | 807,912 (1.43%) | 810,357 (1.19%) | +0.30%, within A/A |
| execute - large result (tracked) | 284,291,331 (0.11%) | 284,146,022 (0.17%) | −0.05%, within A/A |
| legacy interpreter, Jazz introspection | 189,694,071 (0.10%) | 190,298,386 (0.15%) | +0.32% |
| legacy interpreter, big-schema introspection | 1,320,018,223 (0.09%) | 1,325,653,362 (0.08%) | +0.43% |

The same picture as round 2 on `2e8473ea7d`. The legacy-interpreter introspection rows cost a little more because
there the identity cache already hit for the repeated nodes of one document, and hashing the String costs more; the
body covers them with "the execution benchmarks move by less than 1% either way". No wall-time claim. The Zammad
replay (−0.64%) was not rerun on this master and is not in the body.

### GQ1 fix round after Astra (2026-11-18)

New head [`8af96ec046`](https://github.com/thomasklemm/graphql-ruby/commit/8af96ec046d5831a3031eadd400249c168be8b87),
one commit on `9c9f8f28cc`, lease-pushed over the unopened `4a77cd59bf`; `lib/` is byte-identical to `4a77cd59bf`, so
the Callgrind table above stands for it. Thomas author and committer, no trailers.

1. **Test asserts results, not hook calls.** Same anonymous schema; the `.get_field` and `Schema.get_type` overrides
   return nil while `context[:hidden]` is set. A Warden that looked up `name` and `Thing` before `hidden` was set
   still returns the same field and type afterwards; a fresh query whose context starts hidden gets nil for both, so
   the cache isn't shared between queries. On master the first re-lookup returns nil
   (`expected Thing.name, actual nil`); with only `get_type` reverted, `Thing` comes back nil; with only `get_field`
   reverted, the field does. Passes with the Ruby parser, the C parser and `GRAPHQL_FUTURE`. A first draft executed
   `__type` around a context-changing root field, but under `GRAPHQL_FUTURE` (Execution::Next) the root object is
   nil and the resolver can't run, so the test calls the Warden directly.
2. **Claims.** The body names `Visibility::Profile` as precedent for `.get_field` only and says the cache lives as
   long as the Warden, "which normally lives for one query" (an explicitly passed `warden:` keeps its entries). The
   commit message says equal names in distinct Strings missed, and that nil results are kept too.
3. **Numbers.** The body's table is now `rake bench:validate` (benchmark-ips, Ruby 4.0.9, no JIT, pinned to one
   CPU, master and head alternating, six rounds, nothing else running; `gq1-pr/ips/`, scripts `ips.sh`,
   `ipstab.rb`). Best of six, i/s, with A/A as best of rounds 1–3 against best of rounds 4–6 per revision:

   | scenario | master | head | head/master | master A/A | head A/A |
   | --- | ---: | ---: | ---: | ---: | ---: |
   | validate - introspection | 1,216 | 1,394 | 1.15x | +2.2% | −1.1% |
   | validate - abstract fragments | 1,942 | 2,122 | 1.09x | −3.8% | −1.6% |
   | validate - abstract fragments 2 | 1,282 | 1,412 | 1.10x | −0.1% | −1.0% |
   | validate - big query | 149.8 | 173.3 | 1.16x | +3.9% | −1.6% |
   | validate - fields will merge (5000 × `hello`, record only) | 38.2 | 74.8 | 1.96x | +2.2% | +0.2% |

   Head is ahead in all 24 round pairs of the four body rows (lowest 1.00x, abstract fragments, round 2;
   `ips/pairs.txt`). The stress row stays here, as DECISIONS' realistic-size rule asks. The body's execution
   sentence now says "instruction counts".

Suites on `8af96ec046`, Ruby 4.0.9: `SERIAL=1 rake test` 2,735 tests, 0 failures; `GRAPHQL_CPARSER=1` 2,783, 0;
`GRAPHQL_FUTURE=1` 2,735, 0. rubocop and `srb tc` clean.

### GQ1 Astra review (2026-11-18)

**Verdict: changes, do not open this head/body yet.** Reviewed
[`4a77cd59bfed27d21f2787c70603850e70853e3a`](https://github.com/thomasklemm/graphql-ruby/commit/4a77cd59bfed27d21f2787c70603850e70853e3a),
whose sole parent is `9c9f8f28cc6f297c6944b3cc6f567bf4ebcd98b6`; fetching canonical master during review returned
that same base. Both Thermos rubrics applied directly by Astra, without other reviewers or delegation, in
[the review thread](https://ampcode.com/threads/T-01a1f036-3f72-70d5-b936-d1e3f63faddf).
The production implementation is L0. The blockers are the test, overstated contract reasoning, and presentation
and measurement requirements, not a demand for an override-detection guard.

**Required changes, smallest fixes:**

1. **Test observable results, not hook invocation counts.** `warden_spec.rb:1156–1157` asserts arrays whose only
   purpose is to count `.get_field` and `.get_type` invocations. These are observable public hooks, so this is more
   meaningful than counting private helper calls, but DECISIONS explicitly says no call-count assertions; it does
   not grant an exception for documented hooks. The guide documents dynamic definitions and operation-duration
   caching, not an exact invocation count. Replace those assertions with returned-field/type or execution-result
   assertions that distinguish the changed semantics, plus a fresh-query control proving the cache is not shared.
   The retained boundary probe below supplies both directions (present→denied and denied→present). Keep hook
   counters in benchmark/review instrumentation, outside the upstream suite. The submitted test itself was run
   unchanged in isolation: head passes 1 test/3 assertions; base fails with `["name", "name"]` versus `["name"]`.
2. **Narrow the equivalence and cache-lifetime claims.** Profile already caches field lookups by `(owner, name)`
   and type results by name, but `Profile#compute_type` calls `Visibility#get_type`, not `Schema.get_type`.
   The retained `gm-visibility.hookprobe.txt` already contradicts “exactly the branch's answers and call counts”:
   the fragment query logs no `Schema.get_type` call there, versus one on head. New probes confirm a denying
   `Schema.get_type` override returns nil on head but is bypassed by Profile. State only the field-cache precedent;
   do not claim equivalent hooks or proof of compatibility. Describe first-result reuse in a Warden (normally one
   query), including nil, rather than an unconditional once-per-query hook guarantee. An explicitly reused
   `warden:` retains its entries across queries. The commit message's “every selection missed” also needs “distinct
   equal name Strings”: repeated visits to one AST node already hit. Keep the mid-query behavior warning.
3. **Use plausible workloads and current-head benchmark-ips evidence in the body.** The headline 43% row is
   `Array.new(5000, "hello")`, not a representative application query. Keep that stress result in this record,
   as DECISIONS' realistic-size rule requires. Lead with a short benchmark-ips script/output on the existing big
   query and abstract-fragment workloads (or another realistic repeated-selection query), with exact-base/head
   raw runs and A/A retained. The older wall-time section is not evidence for this exact head. Instructions are
   correctly labeled, but an Ir-only body does not meet the later “Benchmark tables in the project's own format”
   rule; omitting the word “speed” does not waive it. Say “execution instruction counts” rather than the ambiguous
   “execution benchmarks move”. Distinguish repeated visibility traversal from repeated `visible?` hooks: those
   hooks were already cached by member identity. No extra paragraphs about review process belong upstream.

**Correctness/security findings.** The behavior change is real and can return either more or less than a later
hook would allow. Rerunning `exec/exprobe2.rb` on base/head gives `b.staffName = "alt"` / `"staff"` after
`dropStaff`. In the new probe, `{ a: __type(name: "Thing") { name } hideType b: __type(name: "Thing") { name } }`
gives `b = nil` on base and `b = {name: "Thing"}` on head. Both type and field lookup also retain an initial nil
after the context starts allowing the name. This must not be described as unchanged authorization behavior.
However, the [dynamic-types guide](https://github.com/rmosolgo/graphql-ruby/blob/9c9f8f28cc6f297c6944b3cc6f567bf4ebcd98b6/guides/schema/dynamic_types.md#L3-L10)
already describes schema-element caching for the duration of an operation, and `.visible?` itself is already
memoized on base. No new production-code blocker was demonstrated for a schema whose definitions are stable
within an operation. The intended change is acceptable to propose explicitly; Profile's existence alone is not
evidence that every existing Warden app is compatible. Authorization that must change during execution belongs
in runtime authorization/resolution, not in a once-cached schema lookup.

The exact-name partition remains `(parent identity, field-name value)` / `type-name value`. The visibility and
reachability checks on the first lookup are unchanged; duplicate-definition detection is still on that path.
Unchanged-context results, validation errors and `visible?` hook tallies in `exec/wprobe.rb` are byte-identical
on base/head (2,523 output lines in this run). Ordinary multiplex executes allowed/denied/allowed contexts with
distinct Wardens and returns the same data/error/data sequence on both revisions. The cache is not newly global
or multiplex-scoped. Passing the same Warden explicitly to two queries keeps the first answer on head; its context
and other caches were already instance-bound, so sharing one across changing principals was never a safe isolation
mechanism. Named Visibility profiles are deliberately shared; `preload: true` alone does not make every dynamic
profile shared (`Visibility#profile_for` still constructs a profile for an ordinary query context).

Mutable/frozen plain Strings and an unmodified String subclass work; no caller String is frozen. A mutable name
changed from `name` to `other` returns `Thing.other` on head, whereas base's identity cache returns stale
`Thing.name`; similarly `Thing`→`String` selects the new type on head. Fresh `name`/`Thing` Strings still retrieve
the original definitions. Ruby's ordinary Hash retains the original String key value rather than following the
caller's mutation. Symbols and Strings remain distinct (`:name`/`:Thing` return nil, the Strings find definitions),
and a duck-typed `to_str` object is not implicitly converted on either revision. No new coercion or frozen-input
failure was found. Custom hash/equality semantics and in-place schema mutation are not reasons to add guards to
this small name-cache change; they are not a stable GraphQL name/definition contract.

**Default path and upstream overlap.** `ruby -Ilib -rgraphql -e 'p GraphQL::Schema.use_visibility_profile?'` prints
`false`; `Query#prepare_ast` creates a Warden, and the install generator omits Visibility. This verifies the default,
not a claim about what fraction of real apps have migrated. `AlwaysVisible` internally enables Visibility too.
Read all 26 current open PR titles and searched issues/PRs for `Warden`, `visibility cache`, `get_field cache`,
`compare_by_identity`, and recent cache work. No direct duplicate of these two Warden changes was found.
[5586](https://github.com/rmosolgo/graphql-ruby/pull/5586) is the merged Profile precedent (rmosolgo,
2026-03-25); its parent experiment [5578](https://github.com/rmosolgo/graphql-ruby/pull/5578) is closed and also
describes 5,000 identical fields as pathological. [5814](https://github.com/rmosolgo/graphql-ruby/pull/5814)
is already in base and fixes different Warden loadability behavior. Open
[5821](https://github.com/rmosolgo/graphql-ruby/pull/5821) changes migration comparison, not these caches;
[5696](https://github.com/rmosolgo/graphql-ruby/pull/5696) changes execution steps;
[5724](https://github.com/rmosolgo/graphql-ruby/pull/5724) caches fragment complexity; and
[5905](https://github.com/rmosolgo/graphql-ruby/pull/5905) documents `extra_types`.
[5761](https://github.com/rmosolgo/graphql-ruby/issues/5761) concerns shared Visibility traversal state, not a
query-local Warden cache. [4778](https://github.com/rmosolgo/graphql-ruby/issues/4778) plans Warden removal in 3.0,
so this is an optimization of the current legacy default, not the future architecture.
[5035](https://github.com/rmosolgo/graphql-ruby/issues/5035) was about `compare_by_identity` returning self,
not an earlier rejection of value keys; [4443](https://github.com/rmosolgo/graphql-ruby/pull/4443) motivates identity
keys for class objects, which this patch preserves. All inspection was read-only; nothing was posted upstream.

**Maintainability.** Cold read: cache a type by its name; cache a field by owner identity and name value; on a miss
run the existing visibility logic. No new branch, guard, comment, dependency, or lifecycle state. The small helper
has two meaningful uses and makes the key distinction explicit beside the existing helper; no larger abstraction
or owner-inspection fallback is warranted. The surrounding anonymous-schema test style matches rmosolgo's
`42f9fab99` changes. Warden grows 729→733 lines; the spec was already 1,192 lines and becomes 1,225, not a new
1,000-line crossing. Flog 4.9.4: `get_type` 6.6→6.6, `get_field` 9.5→9.5, new helper 2.8. RuboCop 1.92.3 metrics,
using zero thresholds to print scores: `get_type` ABC 6.40 / cyclomatic 4 / perceived 5 unchanged; `get_field`
8.25 / 4 / 5 unchanged; new helper 4.24 / 1 / 1. Existing identity helper unchanged. The call-count test is the
only required source-shape change; no speculative refactor is requested.

**Measurement replay and adverse input.** Independently parsed all 72 totals in `gq1-pr/raw.txt`, calculated
`(Ir(N2) - Ir(N1)) / (N2 - N1)` separately for each process pair, then averaged a/b. All nine table deltas and A/A
values reproduce. Body rows round to 226.8M→129.2M (−43.0445%, A/A 0.1019%/0.1096%), 35.3M→32.6M (−7.5104%,
0.0484%/0.0576%), and 2.38M→2.20M (−7.8567%, 0.9914%/0.2764%). Execution deltas range −0.9430% to +0.4269%; the
small and large-result rows are within their A/A, not wins. These are arithmetic replays, not new Callgrind runs;
the retained totals do not independently prove all runtime/heap conditions. `table.rb` truncates per-process slopes
to integers, explaining sub-instruction differences in the record without affecting any published rounding.

The adverse case is an already-hit name, especially a long one: value hashing scans bytes while identity lookup
does not. `astra-size.rb` tests cached missing fields with the same String, 1,000 lookups twice, Ruby 4.0.9 without
JIT. Base stays about 0.10 ms at 8 B, 64 B, 1 KiB and 1 MiB; head is about 0.12, 0.14, 0.37 and 279 ms. These
diagnostic wall samples are not pinned-core performance claims or application regressions. They confirm the
expected length-dependent tradeoff; the 1 MiB stress row belongs here, never in the body. Ordinary name lengths
and the retained legacy-execution Ir regressions are small; no defensive guard is justified by that stress case.

**Reproduction and limits.** Retained new source/output: `gq1-pr/astra-boundaries.rb`, `astra-size.rb`, and
`gq1-pr/probes/astra-{master,head,profile,size-master,size-head}.txt`. With `BASE` and `HEAD` set to checkouts of the
two reviewed revisions, run `ruby -I"$BASE/lib" bench/upstream/graphql_ruby/gq1-pr/astra-boundaries.rb`, repeat
with `HEAD`, and run the base with `PROFILE=1`. The earlier `exec/{wprobe,hookprobe,exprobe2}.rb` also ran against
both revisions. The submitted spec block was extracted unchanged from head and evaluated with
`-rgraphql -rminitest/autorun` against each library. This review did not rerun the full suite, C-parser build or
Sorbet; the builder's suite counts above remain builder evidence, not new verification. No fork modifications,
fork push, PR opening, or upstream comments were made.

## Rejected

- **`Schema.default_logger` memoization.** Without Rails, every query builds `Logger.new($stdout)`, and the
  `File.exist?` syscall in `LogDevice` takes 10% of small-query wall time on this orb. Memoizing it saves only 1.4%
  Ir on the small query and 0.5% on validation, and it changes behaviour: one shared, mutable logger, and a later
  `$stdout` reassignment is ignored. Rails apps get `Rails.logger` and never pay this.
- **#5509's introspection delegation (+2.4% on the legacy interpreter).** Inherent to Execution::Next sharing the
  resolvers; undoing it duplicates methods.
- **Execution::Next step overhead.** Open work by ydah (#5696, "Reduce Execution::Next lookup and step overhead",
  plus #5805, #5727); not touched.
- **`FieldsWillMerge`** (`legacy_mutually_exclusive?` `Array#&`, `field_selection_signature`): already cached per
  type pair; what remains after GQ1 is the 5000-field benchmark's own quadratic shape.
- **Legacy interpreter `Lazy`** (`Lazy#initialize`, `after_lazy` in the large result): the benchmark's
  `lazy_resolve Proc`; no exact change found.

## Zammad replay

`apps/zammad-replay.rb` replays eight GraphQL queries that Zammad's new desktop UI sends: `session`, `currentUser`,
`applicationConfig`, `userCurrentTicketOverviews`, `ticketsCachedByOverview`, `ticket`, `ticketArticles` and
`userCurrentTaskbarItemList`. It runs them in-process through `Gql::ZammadSchema.execute`, as an agent, with the
context `GraphqlController` builds. Query texts come from `app/frontend/**/*.graphql`, with the fragments each one
spreads.

Setup (Zammad `64e70ff`, with the readiness runner's setup from
[app-suites.md#zammad](app-suites.md#zammad): Ruby line, `database.yml`, readline, jemalloc,
PostgreSQL/Redis/memcached as `readiness-*` orb services):

```
bundle exec rake zammad:db:init                       # RAILS_ENV=test, env from apps/zenv.sh
createdb -h 127.0.0.1 -U postgres -T zammad_test zammad_replay
DATABASE_URL=postgres://postgres@127.0.0.1/zammad_replay bundle exec rails runner zammad-replay.rb seed
... zammad-replay.rb dump      # DUMP=out.json: results, to compare revisions
... zammad-replay.rb wall 20   # ms per round
... zammad-replay.rb stackprof 30 [STACKPROF_LIB=..., STACKPROF_METHOD=...]
apps/zcg.sh GEMFILE TAG N      # Cachegrind of N rounds: fresh DB copy, own memcached (11212) and Redis db 3
```

The seed adds an Admin+Agent user and 20 tickets with 5 notes each. Point graphql at a checkout with a copy of the
Gemfile (`gem 'graphql', path: …`) and of the lock. Two pitfalls broke my first two Cachegrind pairs:

- `ticketsCachedByOverview` needs `cacheTtl` long enough to outlive Valgrind's slowdown (the script uses 3600).
- The replay must not share memcached or Redis with a running Zammad spec suite, which flushes them.

Per-round Ir then has an A/A of 0.05–0.32%. The results (`dump`) are identical on 2.6.14, master and GQ1.

## Zammad and Decidim GraphQL specs, master vs 2.6.14

The aim was to catch regressions from #5880/#5881 or anything else on master before the release. graphql master
`2e8473ea7d` against the released 2.6.14, each with the Ruby parser and with the C parser
(graphql-c_parser 1.2.0 from rubygems for 2.6.14, the master checkout's `graphql-c_parser` built for master), seed
4242. The apps are the readiness runner's checkouts and bundles (Rails 8.1.4.1, as locked).

- **Zammad** `spec/graphql` (278 files, 2,007 examples, `-t ~searchindex -t ~integration -t ~required_envs`).
  Zammad has no C parser, so the C runs add `gem 'graphql-c_parser', require: 'graphql/c_parser'`, checked with
  `GraphQL.default_parser == GraphQL::CParser`. Results: 2,007 passed, 0 failed in all four runs (2.6.14 and master,
  Ruby and C parser), with the same example IDs. 7–9 minutes each.
- **Decidim**, 152 files: every module's `spec/types`, all of `decidim-api` except system specs, the
  `query_extensions` specs and `decidim-core/spec/lib/api`, run from each module directory as its CI does, 2,389 examples (the C runs used parallel-test databases 2 and 3).
  Ruby parser: 2,387 passed, 2 pending on both. C parser: 11 failed on both, the same example IDs. Master versus
  2.6.14 differs in 0 examples with either parser.
  - **All 11 C failures have one cause, present before master.** `meeting_mutation_type_spec.rb` (3) and
    `withdraw_proposal_type_spec.rb` (8) send `mutation() { … }`, and the C parser rejects the empty variable
    definitions: `syntax error, unexpected RPAREN (")"), expecting VAR_SIGN at [1, 10]`.
  - **The Ruby parser accepts `()`** (`exec/emptyvars.rb`; the same on graphql 2.5.11 and master, and with
    c_parser 1.2.0 and master). The GraphQL spec requires at least one variable inside the parentheses, so the C
    parser is the strict one.
  - Not reported upstream: no matching issue found, and it is not a regression.

**No failure on master that 2.6.14 doesn't also have**, in either app or parser.

**GitLab** (graphql 2.6.10, Rails 7.2.4) has 954 spec files in `spec/graphql` and 549 in
`spec/requests/api/graphql` (gitlabhq FOSS mirror; EE adds its own). It isn't cheap. `spec/graphql` mostly needs only PostgreSQL and
Redis, but the bundle (Ruby 3.3, about 500 gems) and DB setup take an estimated 2–3 hours on an a1.large, and
then about 30–45 minutes per graphql revision and parser. The request specs need Gitaly as well. Not built.

## Wall time

graphql-ruby's `rake bench:validate` (benchmark-ips), master and GQ1 alternating, two rounds each, pinned to one CPU
with nothing else running (`exec/wall-validate.txt`). i/s, master → GQ1:

| | round 1 | round 2 |
| --- | ---: | ---: |
| validate - introspection | 1.117k → 1.342k | 1.128k → 1.340k |
| validate - abstract fragments | 1.707k → 2.023k | 1.780k → 2.036k |
| validate - abstract fragments 2 | 1.211k → 1.350k | 1.255k → 1.304k |
| validate - big query | 137.1 → 160.7 | 136.2 → 156.2 |
| validate - fields will merge | 36.2 → 71.9 | 37.3 → 69.8 |

The direction is the same in every pair. The wall gain is larger than the Ir gain because most of the skipped work
is method calls and Hash lookups with many cache misses.
