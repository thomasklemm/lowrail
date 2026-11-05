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
