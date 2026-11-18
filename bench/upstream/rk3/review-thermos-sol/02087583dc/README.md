# RK3 final-head Thermos review

**Verdict: approve with nits on `02087583dc3685b9f805e3dd975aeb89d1444824`. Code approved; no remaining must-fix in the code or the qualified draft recorded with this pass.** All three earlier runtime findings are fixed. The remaining optional test improvement is to preserve late encoding conversion explicitly, not just once-only conversion. No confirmed security defect was found.

Reviewer `thermos-sol`, 2026-11-18, thread `T-01a1ec13-3575-7694-b1c3-e0edd9abc152`. Scope: rack main `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f` through decode `e347030309088f06f3ddb3148028f4e2b790c3cf` and escape head above, including the delta from `6f48723a862129d42e901d2baae16b1b826404bc`. The previous two reviews remain historical. No Rack files were edited, no fork push or public posting was made, and no additional threads were created.

The two independent, read-only Thermos Task reviewers resumed in parallel on this head. Correctness returned approve with nits, confirming all repairs and correcting the historical CGI date. Maintainability approved the code with nits but requested submission changes for provenance and benchmark disclosure. Their factual findings were checked against the code, executions and committed evidence below; this final synthesis approves the corrected Lowrail draft, not its superseded version at `cdfcd237` or `f2292ad6`.

## All runtime must-fixes are repaired

* **Older-MRI loader:** escape retains the ASCII-compatible guard, so UTF-16/32 continue through URI when standalone native CGI lacks its Ruby superclass fallback. On Ruby 3.4.12 + ERB 6.0.7, receipt metadata confirms `cgi/util` absent in clean runs. Ruby 4 supplies the fallback in `cgi/escape.rb` itself. No unconditional util require, version switch or rescue/retry is needed.
* **Encoding coercion:** both decoders use `CGI.unescape(s, Encoding::BINARY).force_encoding(encoding)`. A stateful encoding, a second-call-raising conversion and an input-mutating `to_str` now match URI. Conversion happens once after decoding, including in the actual Ruby CGI implementation.
* **BasicObject:** all guards start `String === s && s.instance_of?(String)`, so valid non-String URI conversions reach the original implementation without calling a new method on the argument. This fixes `build_nested_query` as well as the helpers. Escape also retains `s.encoding.ascii_compatible?`.

The new tests fail when the repaired behavior is removed: [`mutant-encoding.txt`](mutant-encoding.txt) raises `converted twice`; [`mutant-basicobject.txt`](mutant-basicobject.txt) raises for `instance_of?`. These are runtime prepend mutants, not edits to Rack. The final suite passes those assertions. **Optional nit:** add an encoding fixture whose `to_str` also replaces the input `%41` with `%ZZ`, then assert the decoded result is `A`; the existing assertion catches double conversion but would not catch a future once-only conversion moved before decoding. The independent matrix already checks this and the current code passes.

Arbitrary singleton overrides or global redefinitions of fundamental String methods remain outside the equivalence claim. Dispatch can be introduced as well as removed: escape now calls `encoding` on the original String, while URI's `b`/`dup`/`to_s` calls can disappear; Ruby CGI still performs String dispatch. This is now stated in the draft rather than calling the three removed methods the only boundary.

## Fresh exact-head runtime evidence

| Execution | Observed result |
| --- | --- |
| Ruby 3.4.12, native CGI, no preload and explicit `-rcgi/util` | Each full suite: 1,295 runs, 6,274 assertions, zero failures/errors, two skips; all separate-file tests pass |
| Ruby 4.0.9, native CGI, no preload and explicit `-rcgi/util` | Same full-suite result in both configurations |
| Expanded independent matrix | 17,897 comparisons × eight configurations = **143,176**, zero differences |
| Extended builder differential scripts, rerun independently | Each escape run: 300,000 random + 12 fixed; each decoder run: 300,000 random + 17 fixed; zero counted differences on 3.4/4.0 clean, util and pure CGI |
| Actual ActionDispatch 8.1.4.1, Ruby 4.0.7 | GET/POST/cookie values and errors match base; GET does not call Rack's decoder |

The eight matrix configurations are MRI 2.7.3/3.4.12/4.0.9, each without explicit preload and with util, plus pure CGI on 3.4/4.0. On 2.7.3 old ERB loads util incidentally, so its no-preload run is **not** a no-util result. On 3.4/4.0 the clean native receipts explicitly show util absent. Pure 3.4 uses util's Ruby methods; pure 4 prevents `escape.so` loading and verifies source locations in `cgi/escape.rb` with util absent. Neither is a JRuby or TruffleRuby execution.

The matrix includes UTF-8, ASCII-8BIT, US-ASCII, ISO-8859-1, Shift_JIS, UTF-16/32 LE/BE, dummy encodings, ISO-2022-JP, invalid bytes, frozen/chilled strings, `+`/`%2B`, incomplete/trailing/mixed-case/lone/doubled percent sequences, non-Strings, subclasses, BasicObject, encoding ducks and roughly megabyte inputs. Comparisons include result class, bytes, encoding, validity and frozenness, plus exception class and message. The random scripts separately print intentionally excluded singleton-String boundary examples with `DIFF`; their final zero applies to the counted population, not those disclosed examples. Their exit code alone is not the oracle.

The builder's Ruby 3.2/3.3 executions remain attributed to its retained [`final-head`](../../../../../docs/upstream/data/rk3/final-head/) receipts; this reviewer did not independently run those two versions. No full 2.7.3 suite is claimed. The actual 2.7.3 matrix ran locally.

### Reproduction

Put the selected mise Ruby `bin` first on PATH and remove inherited RUBYOPT. From the Rack checkout, on 3.4.12 and 4.0.9:

```sh
CI=spec bundle exec rake
CI=spec RUBYOPT=-rcgi/util bundle exec rake
```

From Lowrail root, with `.amp/in/orb-backup/rack` at the pinned head:

```sh
ruby -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
ruby -rcgi/util -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
# Pure 3.4:
ruby -r ./bench/upstream/rk3/pure_cgi.rb -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
# Pure 4.0:
ruby -rrbconfig -I .amp/in/orb-backup/rack/lib -e '$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so"); load ARGV.fetch(0)' bench/upstream/rk3/review_exactness.rb
ruby bench/upstream/rk3/review_final_receipts.rb
```

The extended differentials ran from Rack under `CI=spec bundle exec ruby -I lib`, loading each script after shifting its path out of ARGV so it retained the real 300,000 default. The receipts include case counts and util state. The suite files end with the separate-process tests too, not only the aggregate line. [`rails-head.jsonl`](rails-head.jsonl), except its source-location header, matches the base execution retained in the first review.

## The committed request evidence supports a qualified experiment

The builder committed [`req/evidence`](../../req/evidence/README.md) at Lowrail `f2292ad6`: per-cohort invocation records, the sequencing script, raw measured-window Callgrind dumps, and function attribution. I inspected `batch2.sh`, `reqrun.rb` and `Census.env_for` directly. Ruby `system(env, ...)` merges the supplied hash into the inherited environment; none of those layers clears `GLIBC_TUNABLES`. Setting it once on the recorded cohort-3 batch invocation therefore applies it to baseline and candidate alike. This conclusion uses the committed invocation record plus the runner implementation; it is **not** a contemporaneous per-process environment capture or a fresh execution of the app experiments.

[`overlay-audit.txt`](overlay-audit.txt) compares all three methods: Rack 3.2.7's method bodies equal the pinned Rack base, and `rk3.rb`/`rk34.rb` equal the final head's method bodies. The real-request runs are consequently **exact-head method overlays over Rack 3.2.7**, not full-head-checkout integration tests. The separate microbenchmark does load the clean complete base/head trees, as its `results.json` records.

I extracted the committed archive under `.amp/in/orb-backup/rk3-malloc` and reran `callgrind_annotate --inclusive=no --auto=no --threshold=100` on each `.1` measured-window dump. [`malloc-audit.txt`](malloc-audit.txt) independently reproduces total gaps of **1,625,300 / 1,359,749 / 1,348,676 Ir**. `malloc_consolidate` accounts for **818,128 / 745,309 / 757,651**, with `_int_malloc` and `unlink_chunk` accounting for most of the rest. This supports allocator work as the main source of the observed outlier gap, including unchanged-versus-unchanged controls. It does not establish that allocation behavior cannot interact with the treatment.

Disabling fastbins changes allocator work and can change the effect of a patch that changes allocations. Thus interpreter cohort 3 is a **new allocator-specific experiment**, not a repair/rescoring of cohorts 1/2 or confirmation under the default allocator. The two rejected cohorts remain wholly rejected, separately retained, and excluded from the published range. No extra cohort was run in this confirmation review. The retained record does not establish a preregistered universal numerical stopping threshold; A/A spreads are reported observations, not confidence intervals or formal Lowrail production admission.

[`receipt-audit.txt`](receipt-audit.txt) independently recomputes all raw microbenchmark N=0/N=2000 counts, allocation rows, rate arithmetic and accepted/rejected request rows. The retained final request values are:

| Both-commit overlay | Interpreter delta / three-run A/A | Flat YJIT delta / three-run A/A |
| --- | ---: | ---: |
| blog PATCH article | −5.3468% / 0.0885% | −10.1360% / 0.0601% |
| pingcrm PUT contact | −3.1263% / 0.1827% | −5.6596% / 0.5063% |
| blog GET article | −1.6092% / 0.1481% | −2.9439% / 0.2789% |
| codetriage GET repo | −0.8942% / 0.0292% | not measured |
| blog JSON control | +0.0123% / 0.0303% | +0.0404% / 0.2172% |

Interpreter values use `mxfast=0`; YJIT did not set it and used WARM=1000, FLAT=40. Every recorded accepted request YJIT window reports zero compiled blocks and invalidations. Baselines are the mean of three unchanged processes; A/A is (max − min) / mean. The JSON changes are inside their spreads, not evidence of mathematically zero change. Object savings across affected requests range **59.6–135.6**, supporting “about 60 to 140”; objects count the workload/reset/harness as well as the request, whereas instruction collection encloses `Rails.application#call` only. Exact app copies/bundles were unavailable here, so these request numbers were audited, not rebenchmarked.

## Sentence audit of revised messages and body

Both commit messages were read in full and compared with the previous head:

* **Decode message:** URI copies/binary-normalizes and uses a substitution Hash; CGI's native path decodes `+`/hex; availability covers Rack's actual minimum; malformed-percent check/message, binary intermediate, once-only late encoding conversion and all non-plain-String fallbacks match the code and executed cases. “In C” is qualified to MRI, not claimed for alternate engines.
* **Escape message:** URI duplicates and substitutes; native MRI CGI differs for `*`/`~`; `%2A` cannot originate from a literal input percent because that becomes `%25`. All non-plain Strings go to URI. The non-ASCII-compatible fallback and **MRI before 4.0** explanation now match the inspected layouts. No message amendment remains required.

The draft title remains appropriately narrow. Every changed body claim was checked as follows:

* **Opening caller/cost/native sentences:** match Rack's call sites, URI's implementations and native MRI source. Rack parses its own query inputs; this does not claim Rails delegates GET query parsing to Rack.
* **Availability sentence:** corrected **2.3 → 2.4** by the builder. Ruby 2.3's C extension exports only HTML escaping; 2.4 exports form escape/unescape. CGI became a **default gem** in 2.7, not a RubyGems bundled gem. I additionally replaced the ongoing-default-gem implication: installed 2.7.3/3.4.12 report default cgi 0.1.0/0.4.2; installed 4.0.9 has no cgi gem spec but supplies `cgi/escape.rb` and the native extension in stdlib. Ruby 4's `cgi.rb` explicitly says the full CGI library was removed and escape remains. The final sentence states these layouts, not unchanged packaging forever. Rack's gemspec minimum is **≥2.7.3**, not the original request's 2.4.
* **Existing require/engine sentences:** the pre-3.2 HTML fallback already requires escape; both new files keep explicit top-level dependencies and the now-redundant inner require is removed. Pinned JRuby source selects Java; TruffleRuby uses Ruby/skips C. Neither VM was executed locally. The fork's passing engine checks are not a universal version guarantee or engine performance evidence.
* **Decode/escape explanation sentences:** validation preserves ArgumentError and parser wrapping; binary decoding preserves conversion order; substitutions restore `*`/`~`; literal-percent explanation is sound. Plain/non-plain/ASCII-incompatible fallbacks match the repaired guards. The older-MRI qualifier is accurate.
* **Fixture comment and snippet:** the random Base64/IV/tag-shaped string is synthetic, **not actual encrypted output**; its joined length is 284 bytes. The calls correspond to the three table cases. The snippet sets up/calls the workload; complete measurement commands and the actual `UpstreamBench.report` wrapper remain in `RK3_body.rb` and `body/RK3`, rather than pretending the snippet alone times it.
* **Micro table and methodology:** interpreter reductions independently recompute to −34.9482%, −49.1336%, −72.2418%; A/A is at most 0.2308%. Rounded instructions/objects agree. The builder removed the YJIT i/s row; I also removed the remaining **YJIT instruction** sentence because the same worker records no per-window JIT-flat counters. Both sets of raw values remain diagnostic receipts, not certified speed claims. Fixed-heap floors, no-GC windows, clean base/head pins and matching third-party bundles are recorded for these micro runs.
* **Removed rate wording:** actual candidate rates were best-of-three; baseline was the mean of two independently selected best-of-three rates. Their maxima differ by up to 5.3510%, while raw baseline rounds span up to 11.4961%. The old “main varied by up to 5.4% between rounds” was false. Removing the ungated rates also removes this misleading sentence; no replacement rate claim is made.
* **Differential population sentences:** fixed and generated cases cover the listed bytes, encodings and coercions; the independent matrix supplies genuine frozen/chilled coverage absent from the old decoder generator's freeze-then-dup path. Builder receipts supply 3.2/3.3 and this review supplies 2.7.3/3.4/4.0. Pure CGI execution is on 3.4/4.0, not every Ruby/engine. Result/exception equivalence is explicitly scoped to the tested population, not proved for all Ruby objects. The draft caveat now covers added/removed String dispatch across implementations. New tests cover the named adapter differences.
* **Rails request sentences:** actual ActionDispatch probes distinguish GET's own decoder from Rack-backed POST and cookies. Overlay scope, three-run mean/A/A, allocator condition and discarded cohorts are now explicit. Ranges, rounded objects, JSON control and recorded 0/0 request YJIT counters recompute as above. This is instruction/allocation evidence, not latency, production capacity, full-checkout request integration or default-allocator interpreter evidence.
* **Hosted-CI sentences:** final-head check data show **14 successes and one failure**. The [2.7.3 job](https://github.com/thomasklemm/rack/actions/runs/44221113695/job/134522906104) fails setup before rake; prior-head public annotations explicitly say 2.7.3 is unavailable on ubuntu-26.04, latest 2.7.8 is available and download returned 404. The workflow is unchanged; full log access was forbidden in the independent review. Local minimum-version probes are separate from an unexecuted hosted 2.7.3 suite.

The exact final replacements for unsupported/overbroad prose are recorded in the draft:

> Instructions are interpreter Callgrind counts per call; two runs of main differ by less than 0.25%.

> These interpreter results apply to that allocator setting, not the default allocator.

> The optimized paths do not preserve arbitrary singleton overrides or redefinitions of core String methods: dispatch can be removed or added, and differs between native and Ruby CGI.

These qualifications resolve the submission findings; no favorable number was fabricated, substituted from a rejected cohort or rerun until green. The background retains ungated YJIT micro figures only as diagnostics. The historical `commands.sh` formatter puts `env -u` after assignments and is not directly replayable as GNU env syntax; the recorded runner's actual `system(env, ...)` execution is separate. This unrelated helper issue was not changed here.

## One PR, two commits

Keep both commits in **one PR**: they migrate the same URI-compatible conversion boundary, so maintainers review the loading, encodings and coercion contract once. Separate commits keep decode and escape independently reviewable/revertible; they do not need two PR discussions. Split only if a maintainer wants to merge one while discussing the other.

The adapters remain direct and short. A shared module, capability dispatcher or QueryParser-to-Utils reverse dependency would add more machinery than it removes. Jeremy Evans's feedback in Rack 2550 and the earlier 2099 HTML migration supports a small direct implementation with justified compatibility handling; 2550 also has a changelog entry, now added here. Nothing in those precedents requires a new abstraction or a two-PR split. Queue room and any separately requested review remain outside this pass's approval.
