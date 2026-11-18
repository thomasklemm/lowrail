# RK3 simplified-guard confirmation

**Runtime verdict: nits under the requested strict severity bar. Candidate rejected by the coordinator because the silent SafeBuffer safety upgrade is an unacceptable trade. Do not move the live PR to this head.** The unchanged body is not approved for this candidate.

Reviewer `thermos-sol`, 2026-11-18, thread `T-01a1edfe-f82c-774b-b920-55710fa0d086`. Both Thermos correctness/security and maintainability rubrics were applied directly in this thread, as requested; no independent Task reviewers or other threads were created. This is not a claim of two independent reviews.

Reviewed `178bfa8392d5308357dcbb31794eb427b37e5c61` (escape), on `481175cd6e79d26ab29b68946c37b65a0abf8bd1` (decode), on Rack main `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`. Both rewritten commit trees equal their original `28be1918`/`3e96182245` counterparts. The final tree is `4444cfb9d43f092c460543d2036f56dd9c00e2ef`. Messages differ only by removed Amp trailers; both author/committer identities and dates are preserved. No trailers remain. Initial Ruby 4 checks ran on the tree-identical original before the rewrite; subsequent checks ran on the rewritten head. No result is attributed to a different code tree.

The live PR remains at `02087583dc`. At the coordinator's final direction, the body below RK3.md's frontmatter was left **byte-for-byte unchanged**. Only the note, pass and these review receipts were added. The proposed `-3` exact-class/ASCII-compatible variant, including its newly accepted BasicObject incompatibility, needs its own review; this pass neither reviews nor approves that contract.

## Findings and severity

### Native unescape can make an unsafe SafeBuffer HTML-safe

This is stronger than the builder's description of retaining an already-safe buffer. On Ruby 3.4.12 and 4.0.9 with ActiveSupport 8.1.4.1:

```ruby
input = "<img src=x onerror=alert(1)>".html_safe
input.gsub!("x", "x")
input.html_safe?                              # false
URI.decode_www_form_component(input).html_safe? # false
Rack::Utils.unescape(input).html_safe?         # true
```

With no `%` or `+`, native CGI returns a new instance of the subclass without its instance variables; it does not return the input object. Losing `@html_unsafe` makes the Rails 8.1 buffer safe again. `ERB::Util.html_escape` consequently emits the literal tag for the candidate output, versus `&lt;img ...&gt;` for URI. This is an observable direct-call rendering hazard, not merely a class-name difference. Frozen input and ordinary byte/encoding equality do not prevent it. With decoded content, native CGI allocates a plain unsafe String; pure Ruby CGI also returns a plain String in the exercised cases.

**Reachability checked:** modern Rack query/form/cookie parsing splits to plain Strings before unescape. This remains true with SafeBuffer query strings and cookie headers. Rack builders interpolate/join escaped leaves into plain strings. Rails 8.1 GET has its own URI decoder; POST uses Rack's query parser, request cookies use Rack, and `ActionDispatch::Response#cookies` also splits before decoding. Actual GET/POST/cookies/Set-Cookie results matched clean main. Direct SafeBuffer calls and Rails rendering demonstrably differ, but no standard request-processing path exposing the unsafe-to-safe upgrade was found. Under the explicitly requested caller/common-usage bar, I did not label this a demonstrated request-level vulnerability or a code must-fix. This does **not** assert that every application is safe: an application directly decoding a SafeBuffer and rendering the result can be affected.

The coordinator subsequently rejected the trade on safety grounds, irrespective of that runtime severity grade. That rejection, not an assertion of universal equivalence, is the delivery decision.

### Escape can retain a subclass even when it changes the bytes

`Rack::Utils.escape(Sub.new("~"))` returns a `Sub` containing `%7E`; URI returns a plain String containing the same bytes. `a~z` likewise remains a subclass. CGI itself leaves `~` alone and duplicates the subclass; Rack's later `gsub!` changes it without normalizing its class. Therefore “only when nothing needs escaping” is false. The criterion is no native-CGI escape before Rack's remapping, not no URI/Rack escape. The supplied exactness matrix lacks this particular subclass input.

For an ordinary subclass with no overrides, an additional exhaustive Ruby 4 check of every binary string of length zero, one and two made **131,586** escape/unescape comparisons. Differences were 4,423 escape classes and 64,771 unescape classes; no bytes, encoding, validity, frozenness or exception differences were found. That is a different population from the 17,897-check matrix and does not inspect subclass instance state or replace the SafeBuffer probe.

Subclass `to_s`, `b`, `dup` and `gsub` overrides can be bypassed; the old singleton/core-redefinition caveat does not completely describe the newly admitted subclasses. Conversely, later operations such as `force_encoding`/`gsub!` can dispatch on a retained subclass. This matters to claims of equivalence, not just style.

### Remaining tests do not cover every guard independently

Runtime mutants were evaluated against the existing `spec_utils.rb` and `spec_query_parser.rb` (79 tests). No Rack files were edited. Each mutant reconstructed only the affected method definitions and retained the real implementations otherwise.

| Mutant | Ruby 4.0.9 | Interpretation |
| --- | --- | --- |
| Remove all three URI-fallback guards | 3 errors | Symbol, BasicObject and integer builder inputs catch escape regression |
| Replace predicates with standalone `instance_of?` | 1 error | BasicObject escape assertion catches it |
| Replace predicates with standalone `is_a?` | 1 error | Same BasicObject assertion catches it; unlike `instance_of?`, `is_a?` still admits subclasses |
| Remove only `ascii_compatible?` | All 79 pass | Ruby 4 supplies its own fallback |
| Remove only the two decoder guards | All 79 pass | Removing the BasicObject decoder test left this gap |
| Restore combined `String === s && s.instance_of?(String)` | All 79 pass | Expected: this is the prior compatible behavior, not a wrong output |

On **clean Ruby 3.4.12 with util absent**, removing `ascii_compatible?` fails the UTF-16 assertion with `NoMethodError: super: no superclass method 'escape' for class CGI`. Thus the retained test catches the loader regression on the relevant runtime, but Ruby 4 or preloaded util alone cannot certify it. The escape BasicObject test does not independently certify either decoder's guard. An optional decoder coercion test would close that gap; no new Rack test was authorized or added here.

## Fresh execution evidence

| Execution | Observed result |
| --- | --- |
| Full `CI=spec bundle exec rake`, 3.4.12 and 4.0.9, each clean/util | Each: 1,293 runs, 6,270 assertions, 0 failures, 0 errors, 2 skips; all separate files passed |
| `review_exactness.rb`, 2.7.8/3.2.9/3.3.10/3.4.12/4.0.9, each native clean/util | Each: 17,897 checks; 2 escape, 6 unescape, 6 query-unescape subclass-class differences |
| Same matrix, pure CGI on 3.4.12/4.0.9 | Each: 17,897 checks, zero differences |
| Total matrix execution | 214,764 comparisons across 12 configurations; not a zero-difference result |
| `diff_unescape.rb`, all four 3.2-4.0 versions clean/util, plus pure3.4/4.0 | Each: 300,000 random + 17 fixed; native has 1 counted subclass difference, pure has 0 |
| `diff_escape.rb`, same configurations | Each: 300,000 random + 12 fixed; native has 1 counted subclass difference, pure has 0 |
| Ruby 2.7.8 callers versus clean main | Subclass query/nested-query arguments and cookie headers retain subclass values; Rack Request GET coerces to String |
| ActionDispatch 8.1.4.1, Ruby 4.0.9, candidate versus clean main | GET/POST, malformed/invalid encodings, cookies and Set-Cookie output match |

The random scripts print disclosed singleton-boundary `DIFF` examples separately and exit zero even with counted subclass differences. Their final counts, not exit status alone, are recorded. The exactness matrices exit one for the 14 expected class differences. Ruby 2.7's no-explicit-preload run incidentally loads util through ERB, so it is not a clean-no-util execution. Pure CGI runs are not JRuby or TruffleRuby executions. No local alternate-VM suite or full Ruby 2.7 suite is claimed.

Reproduction uses the existing `bench/upstream/rk3/diff_all.sh RACK OUTDIR`, `review_exactness.rb`, `guard_callers_27.rb`, `guard_safebuffer.rb` and `review_rails.rb`; select the mise Ruby's bin directory first on PATH. The new scratch probes remain in `.amp/in/orb-backup/rk3-confirm/` (`mutant.rb`, `safety.rb`, `exhaustive.rb`). Decisive differential/suite/mutation output and native/pure SafeBuffer observations are retained alongside this report.

## Commit and body sentence audit

Both commit messages were read in full. The decode message's copy/substitution cost description, native-MRI qualifier, malformed-percent check, binary intermediate, once-only late encoding coercion and non-String fallback match the methods and executions. The escape message's duplication/substitution cost, `*`/`~` difference, literal `%` argument, non-String/ASCII-incompatible fallback and older-MRI loader explanation are accurate descriptions of byte conversion. Neither message asserts exact subclass normalization. Thomas author/committer identities, original dates and trailer removal were verified against Git objects.

The following audits concern applicability to **178bfa8392**, not an instruction to change the retained live-PR body:

| Body sentence(s), in order | Verdict against candidate |
| --- | --- |
| Opening caller sentence; URI copy/gsub explanation | Supported by query/parser/cookie/build call sites and URI source |
| CGI byte conversions in C on MRI | Supported for native path; not universal object/state equivalence |
| Shipping/minimum/version packaging; existing HTML require; alternate engines | Prior review's packaging/source audit remains applicable; installed 2.7-4.0 layouts checked, alternate VMs not locally executed |
| First commit; malformed percent and InvalidParameterError; once-only late encoding | Supported, including stateful/raising/input-mutating encodings in rerun matrices |
| Second commit; `*`/`~` mappings and `%2A` provenance | Supported |
| “Anything that isn't a plain String (subclasses...) still goes through URI” | **False for candidate**, true for retained live head; String subclasses enter CGI |
| Proposed “when nothing needed ... escaping” subclass sentence in builder note | **False/incomplete**: `~` changes bytes while retaining subclass; SafeBuffer instance-state/safety loss also matters |
| Synthetic cookie comment and code example | Fixture is synthetic, not actual encryption; 284 bytes, matching retained workload |
| Micro table and interpreter/A/A sentence | Numbers match retained `body/RK3/results.json`; its candidate is **02087583dc**, not this head |
| Differential input populations/version sentence | Supported by fresh runs; pure CGI only on 3.4/4.0, not every version |
| “result's class ... are the same” | **False for candidate**: counted native subclass differences; unchanged attributes in tested plain-subclass population do not certify SafeBuffer state |
| Singleton/core-redefinition caveat | Must also cover subclass overrides and instance-state loss if adapted to candidate |
| New tests sentence including String subclasses | **False for candidate's kept tests**: subclass assertions were removed; BasicObject escape/build_nested_query test remains |
| Rails parser/cookie sentence | Supported by actual ActionDispatch request probes and traced source |
| Whole-request “these three methods from this branch” and speed ranges | Retained overlays still have **previous guards**; cannot call them exact-candidate measurements |
| JSON control, three-run mean, flat YJIT windows, fastbins and rejected cohorts | Retained arithmetic recomputed by `review_final_receipts.rb`; ranges/control/allocator qualification supported for that older experiment, not a rebenchmark |
| Fork 2.7.3 setup failure and other jobs passing | Confirmed on rewritten head: 14 successful checks and one setup failure; annotations say unavailable on ubuntu-26.04, rake skipped |

The body was deliberately **not adapted or published**, per the final instruction. Its inaccurate candidate claims are recorded here, not silently approved. No fresh speed claim is made: simplifying a check is not itself a benchmark.

## Maintainability

The three short direct adapters add no new wrapper or abstraction, no unrelated module dependencies and no spaghetti growth. Sharing decoder code through Utils would create avoidable QueryParser coupling; abstracting the tiny guards would add indirection. The one why-comment on escape correctly explains why its ASCII-compatible guard cannot simply be deleted on older MRI. The simpler guard is locally legible and consistent with Rack style, but that structural benefit does not erase the documented safety trade. Keeping one PR with separate decode/escape commits remains coherent; this rejected candidate does not authorize any PR update.
