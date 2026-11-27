# UR1 shared decoder rework — thermos-sol, 2026-11-27

Verdict: **changes — commit message only** for `d09ffb7376d111123e5d217510c150c87c0cdd99`. The code/tests pass correctness/security and maintainability within the previously accepted JRuby 9.4 and override boundaries. Remove the unsupported pure-Ruby speed assertion identified below; no code change is requested. This is **not a PR-body or timing-claim approval**; the replacement body is explicitly a later review.

Reviewer: **thermos-sol**, thread `T-01a21efb-a6a1-71b9-bfc9-7140f4b8f209`. Both Thermos rubrics were applied by this reviewer, without subagents or other reviewer threads, as requested. Rules read: root `AGENTS.md`, `docs/DECISIONS.md`, the UR1 item and previous detailed report. Author receipts were inspected but do not substitute for the runs below.

## Scope and identity

The fetched candidate is one commit on `48cda77031e343d35213c36fe164b2a46ffbefa7`, tree `fc6c87085ad1d32999da6ff7dd6f5abe4804d1b3`. Author and committer are Thomas Klemm, without trailers. The diff changes `lib/uri/common.rb` and `test/uri/test_common.rb`, 30 insertions and eight deletions. The original candidate checkout and separate base worktree remained clean.

The public form-component method converts plus to space; the URI-component method keeps literal plus; both decode percent bytes and reject malformed percent escapes. The existing private helper still validates before `str.b`, and force-encodes only after decoding. The decoder is now the caller's block, rather than a regexp parameter. The changed helper has exactly these two public consumers; `decode_www_form` does not call it.

Raw evidence and runnable probes: **`thermos-sol-d09ffb7-2026-11-27.tar.gz`**, adjacent to this report. Its README describes the original paths, commands, controls and harness corrections. No URI push, upstream comment, queue edit or PR-body edit was made.

## Findings and smallest fixes

1. **Commit-message-only must-fix: cut “is no faster”.** Paragraph four, lines 27–29 of archived `review/commit.txt`, asserts that CGI's pure-Ruby URI decoder “is no faster”. The retained author performance experiment compares native C against `gsub`, not that excluded Ruby decoder. My direct instruction-count comparison of the two Ruby decoder choices on MRI 4.0.10 gives the CGI alternative **52.085% fewer instructions** for percent-dense 16 KiB and **60.761% fewer** for percent-dense 1 MiB, with A/A **0.0642%** and **0%**, respectively. These are not elapsed-time measurements and do not prove a timing win; they demonstrate why the unqualified speed assertion cannot be certified from the available evidence. The TruffleRuby subclass result independently justifies keeping the fallback. Smallest fix: cut the speed clause, writing “cgi's pure-Ruby version on TruffleRuby returns the String subclass that its String#b keeps.” No runtime/code/test fix or new benchmark claim is needed.
2. **Nonblocking receipt correction:** the author's rework README assigns **24 versus 29 objects** to plain `page=2&per=20&sort=name`. My executed form replacement probe gives **19 versus 28**, with the two base runs agreeing apart from the disclosed one-time 0.001-object sampling artifact. Its 24/29 counts match the malformed/invalid-byte form row instead. Smallest fix: correct the plain-input receipt to **19 versus 28 objects**, not time. This is an internal evidence correction, not a requested upstream code change.

## Correctness/security: approve

### Executed engine matrix

Each cell below runs the independent retained `probe.rb` twice, once per changed public method, against a base body checked against the actual base source. It compares result bytes, class, encoding, validity, frozen status, identity, instance variables and singleton methods; input mutation; conversion events; and exception class/message. Error-highlight source excerpts and object addresses are normalized, not asserted as a public contract.

| Locally executed engine/backend | Cases **per method** | Differences | URI-component decoder selected |
| --- | ---: | ---: | --- |
| MRI 2.5.9, bundled CGI | 41,832 | 0 | old `gsub` |
| MRI 4.0.10, bundled native CGI | 42,264 | 0 | CGI C |
| MRI master `0d399335b733776187e43a783e5f950c18ad881c` | 42,264 | 0 | CGI C |
| MRI 4.0.10, shipped pure-Ruby CGI forced | 42,264 | 0 | old `gsub` |
| TruffleRuby 40.0.0, its actual pure-Ruby CGI | 41,349 | 0 | old `gsub` |
| JRuby 10.1.3.0, Temurin Java 21 | 42,264 | 0 | CGI Java |

TruffleRuby rejects 915 encoding/byte combinations during input construction on both sides. They are recorded as unconstructible, not successful decoder cases. MRI 2.5 has fewer registered encodings. Master was built locally from the exact pin with YJIT and ZJIT; its final version header, source identity, clean source diff and build logs are retained.

Also executed the same full differential on **actual CGI 0.3.2 and 0.3.3 installed into MRI 4.0.10**, and CGI 0.3.3 installed into **MRI 2.5.9**. Both methods again have zero differences in every run. This tests an upgraded CGI at the Ruby floor, not just the CGI bundled with that Ruby.

Separate `diff.rb` runs with `SINGLETON_B=1` compare **300,000 random plus 142 fixed cases per method** on MRI 4.0.10 and pinned master **with ZJIT enabled**: zero differences in all four runs. These supplement, rather than replace, the independent corpus.

`edge.rb` adds 30 size/shape cases per method on every requested engine/backend: 12 and 248 bytes, 16 KiB, 1 MiB and 8 MiB; plain, early/late percent escape, dense plus, dense percent and malformed percent at the end. Byte digests, result class/encoding/length/frozen state and exception-message digests agree. Eight concurrent threads pass everywhere, and Ractors pass on MRI 4.0.10 and master. Ruby 2.5 taint propagation, private encoding conversion and conversion call counts agree. The differential's encoding-conversion mutation and suspended-fiber cases agree too.

### Native decoder choice

The load-time feature check is correct for the implementations executed and the release thresholds inspected. `respond_to?` handles CGI versions without the URI decoder; `source_location` distinguishes native C/Java implementations from the Ruby fallback. It is a capability check, not a hard-coded Ruby-version guess. Binary input makes the native decoder's ASCII-compatible path applicable, and the final URI `force_encoding` preserves URI's contract even when decoded bytes are invalid in the requested encoding.

* MRI 2.5's bundled CGI lacks `unescapeURIComponent`; URI keeps `gsub`.
* Actual CGI 0.3.2 lacks it; 0.3.3 provides it natively. Tagged C sources were fetched and inspected. Ruby 3.1.2's `cgi.rb` says 0.3.1; Ruby 3.1.3's says 0.3.5, consistent with 3.1.3 being the first of those two releases to include the new API. The commit's parenthesis is a Ruby availability threshold, not a claim that Ruby 3.1.3 bundled exactly CGI 0.3.3.
* Tagged Java sources lack the method in CGI 0.4.0 and define it in 0.4.1; actual JRuby 10.1 reports a native method (`source_location == nil`) and selects it.
* Actual TruffleRuby 40 reports a Ruby source location and keeps `gsub`. Its `String#b` keeps the subclass; calling its pure-Ruby `CGI.unescapeURIComponent` directly therefore keeps that subclass. The URI fallback normalizes it as base did. Removing only the native check is caught by the new subclass assertion on that runtime.

Standalone `--disable-gems` runs cover URI-first, CGI-first, escape-first and CGI-autoload orders on the requested engines. MRI additionally exercises real old CGI versions, and the missing/native-looking Ruby decoder shims exercise fallback selection on current MRI, master, JRuby and TruffleRuby. All executed orders pass. The Ruby-defined method shim is rejected even though `respond_to?` is true. Loading URI eagerly loads CGI escape, as in the previous candidate; this is an assessed loading change, not unchanged lazy loading. It introduces no dependency shim or missing-library failure on the tested supported runtimes.

This does not claim exhaustive execution of every historical CGI/runtime combination. In particular, source inspection of CGI 0.4.1 is not a local execution of that old Java artifact. No unsupported global redefinition or runtime-specific behavior beyond these probes is certified.

### Exactness checklist and accepted boundaries

1. **Singleton/private hooks, extend/prepend, missing methods:** differential cases cover hooked `b`, private `b`, hooked `encoding`/`instance_of?`, extended/prepended `b`, overriding/spoofing String subclasses, ducks and method-missing ducks. The original input still receives `b` after validation. No new type/encoding probe is sent to it.
2. **Subclasses:** checked across the engine matrix, frozen and mutable. A targeted actual JRuby 9.4.16.0 rerun confirms the accepted exception: empty/plain form-component subclasses return a subclass, while percent/plus inputs return String. URI-component results remain String in all six targeted shapes, including plain and literal-plus inputs. Bytes, encoding and frozen state agree throughout. Do not call 9.4 exact or claim the new form-component subclass assertion passes there.
3. **Conversions:** input ducks and public/private encoding `to_str`, error inputs and once-only conversion events are compared. No new conversion of the original input was introduced.
4. **Added/skipped calls:** the binary intermediate now enters CGI, except the URI Ruby fallback. Custom behavior on an intermediate returned by an overridden `b`, CGI overrides and overrides of the private URI helper remain the explicitly accepted boundaries. Changing the private helper's arguments/block contract is within that boundary. These are not reproduced request-bytes-only decoding failures.
5. **Ownership:** ordinary results are fresh and mutable; callers' inputs are not adopted or mutated. Frozen inputs/intermediates are covered. The JRuby 9.4 class exception remains explicitly scoped above.
6. **Mutation/fibers/concurrency:** conversion-induced mutation and suspension agree; no new user iteration or shared per-call accumulator was added. The executed threads/Ractors agree with that reading.
7. **Errors/frozen values:** lone, truncated and non-hex percent sequences retain validation and its message before `b`; invalid/incompatible source encodings and target encodings retain outcomes. Invalid decoded bytes are retained and tagged, not scrubbed or transcoded.
8. **Loading:** the executed require/autoload permutations and actual native/fallback selections are listed above. Load-time selection is intentionally stable; upgrading CGI or replacing core methods inside an already running process is not a supported hot-switch contract.

No new guard, subclass normalization or fallback framework is warranted. In particular, do not reintroduce the abandoned `to_s` normalization or hand a GB18030 string directly to CGI. The no-binary-copy mutant reproduces the real TruffleRuby internal `ArrayIndexOutOfBoundsException`; the exact candidate passes that case.

### Executed tests and mutation checks

The full candidate suite passes on MRI 2.5.9, MRI 4.0.10 native/pure CGI, master interpreter/ZJIT, JRuby 10.1 and TruffleRuby 40: **94 tests per run, zero failures/errors**. Assertions are 3,046 on 2.5, 3,070 on current MRI/master and 3,048 on JRuby/TruffleRuby. The non-current-MRI runs omit the existing CRuby-regexp-cache-specific test. The base MRI 4.0.10 suite passes 94 tests/3,058 assertions. The observed exact-head fork CI has 26 successful checks; that hosted observation is not counted as another local run.

I reran per-assertion mutation checks, not just the author's summary, on MRI 4.0.10 native/fallback, MRI 2.5.9 and actual TruffleRuby 40. Base code with the new assertions passes. Candidate passes. The relevant active mutants are caught:

* Mixed-case hex catches an uppercase-only fallback; the existing large vector alone would miss it.
* Binary `%FF` distinguishes final UTF-8 tagging from letting CGI fall back to the input's BINARY encoding; missing `force_encoding` is caught too.
* The GB18030-plus case catches loss of the BINARY copy on TruffleRuby and wrong plus handling. The URI expectation deliberately keeps the plus.
* Empty/subclass inputs catch `gsub!` returning nil on a no-match fallback and loss of subclass normalization.
* `%zz` catches treating `\w` as hex, alongside the existing malformed-percent cases.
* Removing the native-only check fails the new URI subclass assertion on TruffleRuby; it correctly survives on MRI, where that implementation difference does not change the result class.

Inactive backend mutations are not counted as killed. These tests assert output, encoding-sensitive bytes, result class and documented errors, not allocations, method-call counts or selection internals. Class preservation is part of the deliberately reviewed compatibility boundary, not an incidental helper detail. JRuby 9.4's known failed class assertion is not hidden by a skip.

## Leaving `decode_www_form` unchanged is right

This is not another consumer of the strict helper. It accepts lone/invalid percent sequences, handles separators/isindex/charset selection, and scrubs invalid output after tagging it. Routing its fields through either strict public component method would change those semantics.

I executed a hypothetical replacement of just its two `gsub!` calls with permissive `CGI.unescape`, keeping the rest of the actual method, and compared results/allocations base/variant/base on MRI 4.0.10. Plain `page=2&per=20&sort=name` gives approximately **19 / 28 / 19 objects per call**; `a&b=&=c&&d=e` gives **31 / 46 / 31**. The escaped `article%5Btitle%5D=Hello+world` instead improves **17 / 12 / 17**. Lone `%`/`%zz` remain literal in the permissive variant, while invalid UTF-8 is scrubbed as before. The first plain-base count is 18.999 from a one-time GC.stat allocation; the retained second base is exactly 19, not a fabricated exact A/A.

Thus replacing it is not an unconditional allocation win, and reusing the strict helper is wrong. The author's README's **24 versus 29 for the plain form** is not the count I reproduce; those counts instead match my malformed/invalid-byte form row. Smallest record-only correction: use the kept **19 versus 28** plain-form result and identify this as allocation evidence, not time. That receipt discrepancy does not invalidate the unchanged code or commit's qualitative reason.

## Maintainability: approve

Cold read: validate once in the existing helper; copy the bytes once with `b`; let the public caller select plus semantics; force the output encoding once. At load, use the native URI decoder if present, otherwise retain the old hash-replacement operation. Each branch has one purpose. Compared with special-casing only the form-component caller, this puts validation/copy/tagging back in their canonical shared helper.

The block is a coherent decoding operation, not a generic callback layer. There is no new helper name, public configuration, rescue shim, input-type guard or copied CGI implementation. Replacing the feature check with an unconditional CGI URI decoder breaks the TruffleRuby subclass contract; adding a decoder constant/proc or checking availability per call would add state/indirection or recurring work without simplifying the contract. A Ruby-version branch would be less correct than the capability check with upgraded CGI at Ruby 2.5.

`common.rb` grows **922 → 930 lines**, below the rubric's 1,000-line boundary. Flog: existing shared helper **6.3 → 6.1**, form-component forwarder **1.6 → 2.8**, URI-component **1.6 → 6.0** (the latter score is its last, fallback definition; Flog does not separately list both definitions). File total **316.0 → 327.9**. The extra public-method score reflects the now explicit decoder block/fallback, not a new responsibility. RuboCop Metrics reports the same **15 existing offenses** on base and head, with no new metric offense. This is a small capability-dependent fallback, not a new version-policy framework or a reason to split the file.

Every added comment line was read. The one-line native-decoder note explains the otherwise non-obvious source-location gate; the public plus-preservation RDoc was moved with its method; the existing private-helper description was updated to its block contract. No measurement narrative, implementation essay or internal project text was added. A real RDoc parse retains `decode_uri_component` as documented with its plus-preservation text; the `:nodoc:` fallback does not erase the public documentation.

## Commit message

The retained full message was checked sentence by sentence against the code, source and executed cases. Apart from finding 1, the validation/copy/encoding description, native-versus-Ruby fallback distinction, accepted JRuby 9.4 class exception and `decode_www_form` allocation reason are accurate. The native C and Java availability thresholds were checked in tagged CGI sources and by real C gem installations. The Ruby-release parenthesis has the availability interpretation explained above. No measured timing number, false per-escape MatchData claim or internal review/queue material is present.

Fetched the exact Rack 3.2.9 query-parser/utils files and Rails 8.1.4.1 query-parser file used in the existing record. Rack's query parser and `Utils.unescape` call the form-component method; cookies use `Utils.unescape`. Rails' query parser calls that same method. These back the message's collective query/URL-encoded-field/cookie claim, not a claim that every Rails form or request takes this path. Current reach/currency and replacement PR-body wording will be rechecked in the separate body review rather than silently approved here.

Finding 1 is resolved by cutting the unverified speed claim, not by interpreting “no faster” more narrowly than the message says. `pure-alternative{,-sweep}.rb` directly compares the candidate fallback against its hypothetical CGI Ruby decoder block, retaining validation, BINARY input and final tagging on both sides. Percent-dense outputs were independently checked. The archive keeps every command, raw dump and the base/alternative/base controls. This does not propose removing the necessary TruffleRuby class boundary or certify a pure-Ruby timing improvement/loss. The forthcoming body must scope native timing claims to the measured backend.

## Performance evidence

### Size sweep: instructions, not time

Own MRI 4.0.10 sweep, base/candidate/base on the same pin, fixed five-pool heap, GC off after warm-up, with a separate zero-call subtraction for each cell. The common wrapper is `URI.public_send`, so absolute counts include that dispatch on both sides. Inputs cover empty, 3 and 12 bytes, typical 248 bytes, 16 KiB, 1 MiB, 8 MiB and **64 MiB**. Plain/absent, early and late escapes are swept across the nonempty sizes; dense plus and percent shapes are additionally checked through 1 MiB. The actual percent-dense length is three times floor(requested size / 3). The last size exceeds this orb's reported **54 MiB L3 cache**, whose raw topology is retained.

“Worst” below means the largest candidate/base instruction ratio in the measured grid, not a claim of a globally worst input or measured latency:

| Backend and method | Worst measured input | Base1 / candidate / base2 instructions per call | Change from base mean | A/A spread |
| --- | --- | ---: | ---: | ---: |
| Native CGI, form component | Empty | 5,176.48 / 4,928.87 / 5,144.48 | −4.4881% | 0.6201% |
| Native CGI, URI component | 1 MiB literal plus | 23,075,455 / 22,026,442 / 23,075,423 | −4.5459% | 0.000139% |
| Pure-Ruby CGI, form component | 16 KiB plain `a` | 366,295 / 692,479 / 366,263 | **+89.0578%** | 0.00874% |
| Pure-Ruby CGI, URI component | 12 plain `a` bytes | 5,707.24 / 6,070.23 / 5,723.24 | **+6.2113%** | 0.2800% |

The fallback costs are real counted work, not noise and not a claim of elapsed-time loss. The form-component's CGI Ruby path scans/copies plain input more than the old `gsub`; the URI fallback keeps that `gsub` but adds the shared helper's block. Do not advertise an all-runtime or all-input performance win. The form-component switch is already present in c43954f; its whole native-to-pure effect is not newly introduced by extending the helper to the URI component. `review/previous-head-diff.patch` retains that attribution.

The past-cache **64 MiB plain** row is also explicit: native form-component instructions **1,476,401,871 / 1,275,074,804 / 1,476,401,807**, **−13.6363%**, A/A **0.00000434%**. Forced-pure form-component instructions are **1,476,401,777 / 2,293,290,233 / 1,476,401,793**, **+55.3297%**, A/A **0.00000109%**. Thus the extra plain-input passes remain visible at large size. These rows must not be silently replaced with only escaped-input wins.

### Pinned master × ZJIT

Own `script/upstream-bench` micro on master `0d399335b733776187e43a783e5f950c18ad881c`, native CGI, base/candidate/base, fixed heap, 1,000 calls after 3,000 warm-up calls. The four form-component cases (hello, encoded form key, form value, 248-byte cookie) change instructions by **−17.9674%, −63.8872%, −72.2246%, −51.6823%**; URI-component hello and encoded user change by **−18.0212%, −58.1397%**. Maximum A/A is **0.6784%**. All six cases pass the four-counter gate in all **36 measured windows**; the raw window logs were checked, not just the aggregate `flat` flag.

No new wall timing was run in this smaller orb. The coordinator's xxlarge timing and replacement PR body remain separate evidence to confirm; this pass does not carry the former form-only head's elapsed-time numbers onto the new tree. `audit.rb --complete` is the final raw-dump/count/counter gate; its output is retained as `perf/audit.txt`.

The completed final audit reconstructs **all 128 sweep rows**, all **three** pure-decoder alternative rows and all **36** master-ZJIT windows from their raw files. The combined native/native-tail and pure/pure-tail maxima agree with the four worst rows above. Maximum sweep A/A is **0.8802% native** and **1.1795% forced-pure**; no cohort or adverse row was discarded.

## Delivery and limits

This pass reviews the exact code/tests/message above. It does not authorize a fork push, approve an unseen PR body, certify every historical CGI build or turn instruction counts into elapsed-time claims. The raw archive is committed with this report. The queue item was left untouched as requested; the coordinator owns recording this pass there.
