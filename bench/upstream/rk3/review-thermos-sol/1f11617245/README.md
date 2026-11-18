# RK3 -3 guard confirmation

**Verdict: changes, text only. No runtime or security must-fix found under the requested contract.** The code fixes the rejected variant's SafeBuffer upgrade. Before replacing the live PR head, correct the compatibility wording in both commit messages and the draft body. No Rack code, commit, fork branch, PR or public comment was changed by this review.

Reviewer: `thermos-sol`, 2026-11-18, thread `T-01a1ee1c-61a8-758f-8355-a4f04b6c98e7`. Both Thermos correctness/security and maintainability rubrics were applied personally here, as requested. There were no delegated reviewers or other threads; this is not two independent reviews.

Pins: Rack base `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`, decode `d8bfe684c1db6b8b8818b9c5449a41f45ace195a`, escape/head `1f11617245ca3ef082c57f1bd11130931e0a5d78`, fork branch `unescape-cgi-3`. Parent links contain exactly these two commits above base. The live `thomasklemm/unescape-cgi` branch was independently checked and remains `02087583dc3685b9f805e3dd975aeb89d1444824`.

## Must-fixes: make the compatibility sentences true

### 1. Both commit messages omit the accepted exception

The decode message says to “pass anything that is not a plain String, including subclasses, to URI unchanged.” The escape message says “Anything that is not a plain String still goes through URI”. Neither is true for BasicObject: execution fails at `instance_of?` before reaching URI (`utils.rb:42/65`, `query_parser.rb:264`). This is the accepted behavior, not a request to restore the old guard.

Smallest repair: describe fallback for String subclasses and ASCII-incompatible Strings, and name the BasicObject guard failure explicitly. Alternatively qualify “anything” with “except BasicObject”. These are message changes, so they require new commit IDs, not a code repair. The draft body's next sentence supplies an exception to its similar blanket fallback clause, but putting the exception in the claim itself would be clearer.

### 2. “One thing changes” is not an exhaustive description

The new sentence correctly identifies the newly accepted BasicObject boundary, but its opening “One thing changes” overstates equivalence to main. Beyond the already disclosed singleton dispatch differences, escaping an ordinary exact String loses instance variables:

```ruby
s = "abc"
s.instance_variable_set(:@tag, true)
URI.encode_www_form_component(s).instance_variables # [:@tag]
Rack::Utils.escape(s).instance_variables             # []
```

This reproduces on every locally exercised MRI series, including 2.7.3, and with native and Ruby CGI. It also reproduces on live `02087583dc`: it is introduced by the overall optimization relative to main, not newly by -3. URI's `to_s.dup` preserves the variables; CGI's output does not. The input is unchanged. Subclass instance state is protected by the URI fallback. Rack query builders and cookie writers interpolate/join the output and do not preserve the escaped intermediate's ivars on main either, so this is not a demonstrated common Rack/Rails regression or a reason to make the guard more elaborate.

Smallest repair: remove “One thing changes”, qualify the BasicObject sentence to inputs URI could actually convert, and include plain-String ivar copying in the existing limitations sentence. For example: “A BasicObject that URI could convert now raises NoMethodError at the guard.” Plain BasicObject already failed on main, at a different method, so “instead of being converted” should not imply all BasicObjects used to succeed. A suitable additional caveat is “Escaping a plain String no longer copies its instance variables.” Do not advertise BasicObject as the only observable direct-call difference.

The draft body was left unchanged so the coordinator can apply the wording changes together with the rewritten commit messages. Its speed qualification is approved; its exhaustive compatibility wording is not.

## Runtime and security findings

* Exact-class fallback restores subclass behavior, including `"~"`, `"*"`, empty strings, tagged subclasses, and subclasses overriding `to_s`, `b`, `dup`, `gsub`, `gsub!`, `force_encoding` or `encoding`. The shared `instance_of?` predicate is not a promise to support an object that overrides that predicate to lie about its class.
* ActiveSupport 8.1.4.1 safe, html-unsafe, dup'ed safe/unsafe, and frozen buffers match main in bytes, encoding, class, instance state, `html_safe?`, and ERB escaping. The unsafe `<img ...>` case remains escaped, not silently made safe. The old -2 probe still demonstrates the safety upgrade; the live head and -3 do not.
* Frozen exact Strings, ordinary tagged Strings, malformed escapes, invalid bytes, and non-ASCII-compatible encodings were exercised. No ordinary result/encoding/exception mismatch beyond the accepted BasicObject cases was found. Both UTF-16 decoders match main.
* Arbitrary singleton overrides on exact Strings are still observably different, as the body already says: native CGI bypasses `to_s`/`dup` on escape and `b` on decode; the new guards can add `encoding` dispatch; Ruby CGI dispatches differently again. These can change bytes, errors or side effects, not merely classes. They are not newly introduced by replacing the old combined exact-class guard with -3, apart from the decoder encoding check.
* Standard Rack call sites were traced through `each_query_pair`, cookies, query builders and `set_cookie_header`; Rails call sites through cookies, response cookie parsing, URL credentials and redirection. Ordinary callers match main. A BasicObject supplied by an application can still reach escape as a nested-query or cookie leaf and now fail: that is the expressly accepted contract change, not an unreachable case.
* Ruby 2.7 subclass-preserving `split` does not leak subclasses through the new decoders: the URI fallback returns the same ordinary Strings as main. Older Ruby's incidental ERB preload does not certify a no-util path; an additional standalone `rack/query_parser` check on 2.7.3 passed with util demonstrably absent.
* Actual ActionDispatch 8.1.4.1 GET, POST, malformed/invalid-encoding parameters, cookie reads and Set-Cookie writes matched main on Ruby 4.0.9. GET used Rails' decoder; POST hit QueryParser and cookies hit Utils, confirmed by TracePoint.

## Fresh execution evidence

| Check | Result |
| --- | --- |
| `CI=spec bundle exec rake`, 4.0.9, 3.4.12, 3.3.10, 3.2.9; each clean and `RUBYOPT=-rcgi/util` | All eight: 1,294 runs, 6,272 assertions, 0 failures, 0 errors, 2 skips; all separate files passed |
| `diff_unescape.rb` and `diff_escape.rb`, same four Rubies clean/util; pure CGI on 3.4/4.0 | Ten configurations per script, each 300,000 random cases; 4 decoder and 3 escape fixed-case differences, all BasicObject |
| `review_exactness.rb`, above ten configurations, plus 2.7.3, 2.7.8, 3.0.7, 3.1.7 clean/util | 18 × 17,897 = 322,146 comparisons; exactly 3 BasicObject differences per configuration |
| Additional adversarial harness against actual base lib | 5,424 observations per ordinary configuration; native has 40 plain-String escape-ivar differences and 748 singleton-dispatch/state differences; no differences for unmodified plain Strings, ordinary subclasses or ordinary caller outputs |
| ActiveSupport adversarial harness on 3.4.12/4.0.9, native clean/util and pure | 6,372 observations per configuration, including 948 extra buffer/caller observations; no SafeBuffer differences. Native differences are the same 788 non-buffer cases; pure has 948 non-buffer differences because singleton dispatch differs |
| `guard_subclass.rb`, 4.0.9 native | No differences |
| `guard_safebuffer.rb`, 3.4.12 clean/util/pure and 4.0.9; live/-2 controls | -3 and live match URI; -2 unsafe/safe upgrade reproduced |
| RuboCop, four touched Ruby files, head versus main | 61 offenses each; identical multisets of file/cop/message/severity, not merely equal totals |

The supplied random scripts exit zero even when their reported differences are nonzero. The exactness matrix exits one for the three accepted BasicObject differences. These are **not** zero-difference or all-green differential results. Singleton boundary examples are also printed separately by the supplied scripts. Its fresh fixed-case populations are 18 (decode) and 16 (escape), not the older 17/12 counts.

This locally covers MRI 2.7 through 4.0, including Rack's exact 2.7.3 minimum; it does not prove every patch release, ruby-head, JRuby or TruffleRuby. The latter engines and macOS have successful exact-head fork CI, inspected independently, but were not run locally. Pure MRI CGI is not an alternate-VM execution. Older 2.7/3.0/3.1 no-explicit-preload runs load util through their ERB; clean modern runs do not. The minimum/legacy probes used official ruby-builder binaries with `LD_LIBRARY_PATH` and `RUBYLIB` set for relocation; the modern suites used independent CI bundles. A stalled mise install of unused legacy copies was stopped after it had no child process or network activity; none of these results use an incomplete install.

### Mutation check and the equivalence qualification

`guard_mutants.sh` was rerun unmodified on 4.0.9 and 3.4.12. Both controls run 80 tests / 364 assertions. Every reported killed mutant was killed: removing any individual guard, either decoder guard alone, both decoder guards, using `String ===` in any method, using `is_a?` throughout, and removing escape's ASCII check on clean 3.4.12. The rejected -2 lib fails three subclass tests; live and main libs pass the new tests.

Survivors: escape without the ASCII predicate on 4.0.9; either decoder without it on both versions. They are equivalent for the original matrix's ordinary String result attributes, not universally equivalent Ruby programs. Removing all three ASCII checks reproduces only the three BasicObject differences in the original 4.0.9 matrix, and 3,458 additional escape errors on clean 3.4.12.

There is a concrete counterexample even without singleton overrides to escape's claimed universal equivalence on Ruby 4:

```ruby
s = "abc".encode("UTF-16LE")
s.instance_variable_set(:@tag, true)
Rack::Utils.escape(s).instance_variables # [:@tag], URI fallback
# With escape's ascii_compatible? clause removed:
Rack::Utils.escape(s).instance_variables # [], CGI fallback
```

The decoder survivors can also alter `encoding` dispatch on overridden exact Strings. These are outside the already qualified result contract; no extra guard or test is required by the requested severity bar. But the builder note's unrestricted “survivors are equivalent” is false: read it with this qualification. Keeping one common guard is deliberate, understandable and not evidence of a missing abstraction.

## Commit, CHANGELOG and body sentence audit

Both commits have Thomas Klemm `<github@tklemm.eu>` as author and committer and no trailers. Original author dates match `e3470303` / `02087583dc`: 2026-11-18 01:07:56Z (decode), 01:08:08Z (escape). Committer dates are 09:46:38Z and 09:48:11Z respectively, after author dates and before this review. Neither message contains owner/repo issue references or PR URLs. The two CHANGELOG entries are in Unreleased / Changed, one per commit, describe the actual decode/escape paths and identify Thomas; neither is a new exact-head numerical speed claim.

Decode message: the URI copy/gsub/hash description, CGI packaging/native-MRI qualifier, percent-error check, binary intermediate and once-only late encoding conversion are supported by source and execution. Its final blanket non-plain-String fallback assertion needs the BasicObject exception (finding 1). Escape message: the URI duplication/hash cost, CGI mapping, literal-percent provenance and older-MRI fallback explanation are supported; its blanket fallback assertion has the same problem. No trailer, identity or date repair is needed.

Body audit, in reading order:

| Sentence / claim | Assessment |
| --- | --- |
| Utils/QueryParser decode query/form/cookie values; Utils escapes Set-Cookie values | Supported by traced Rack callers; ordinary Rack-generated cookie headers, not raw headers an app constructs itself |
| URI copies and gsubs with a Hash | Supported by installed URI source and Rack 3.2.7's identical baseline method definitions |
| CGI does the conversion in C on MRI | Supported for native byte conversion, not arbitrary object-state equivalence |
| Ships on supported Ruby, minimum 2.7.3, C methods since 2.4, default gem since 2.7, Ruby 4 library | Minimum checked in gemspec; local 2.7.3–4.0 loaders work; 2.4/2.3 CGI C source and 2.7 CGI gemspec checked through GitHub; Ruby 4 source installed |
| Rack already requires CGI before 3.2 for escape_html | Supported by base's existing require in the ERB-version fallback |
| TruffleRuby Ruby / JRuby Java implementations | Current upstream loader source selects the Ruby implementation and `org.jruby.ext.cgi.escape.CGIEscape` respectively; successful exact-head CI, not local engine measurements |
| First commit uses CGI.unescape | Supported |
| Preserves malformed-percent error and once-only late encoding conversion | Supported by suite/matrices, including stateful, second-call-raising and input-mutating encoding objects |
| Escape mappings and `%2A` provenance | Supported by source, fixed cases and random differentials |
| Non-plain-String / non-ASCII-compatible fallback | Subclasses/encodings supported; BasicObject exception appears immediately after the blanket claim; explicitly qualifying the claim would be clearer |
| “One thing changes” / BasicObject conversion | Needs finding 2's qualification; BasicObject is not literally the only direct-call difference, and plain BasicObject did not previously convert successfully |
| Synthetic cookie fixture comment and code | Executed; 284 bytes before escaping, synthetic rather than an actual encrypted session |
| Micro table | Raw logs recomputed: 182,980.3 → 119,032.0 Ir, 71,070.7 → 36,151.1, 103,901.6 → 28,841.2; rounded numbers and allocation counts match |
| Interpreter instructions, two main runs differ <0.25% | Recomputed A/A 0.0260%, 0.2308%, 0.0155% |
| All figures from an earlier revision, executable methods differ only in guards | Accurate and plain: receipts identify `02087583dc`; executable-body diff has only guard changes (plus a shortened why-comment). Not a -3 benchmark |
| 300,000 random strings and listed strings/encodings/frozen cases | Fresh reruns support population and scoped output attributes |
| Fixed input and encoding-duck list | Present in the supplied scripts and exercised |
| Ruby versions / util / Ruby-CGI modes | Rerun as stated; pure CGI specifically on 3.4/4.0 |
| Listed result fields and exceptions match except BasicObject | Supported for that population; does not include ivar preservation or arbitrary overridden methods |
| Singleton/core redefinitions caveat | Accurate; add the plain-String escape-ivar caveat rather than broadening this into an exhaustive-equivalence claim |
| Tests cover mappings, encoding, subclasses, encoding argument and errors | Supported by the changed tests and the killed mutants |
| Rails cookies/forms use Rack; query uses Rails parser | Source plus actual ActionDispatch trace support it |
| Three-app request ranges, method overlays over Rack 3.2.7, objects | Existing raw receipts recomputed; interpreter −0.8942% to −5.3468%, YJIT −2.9439% to −10.1360%; 59.6–135.6 objects; prior-revision qualifier applies |
| JSON +0.01% / +0.04%, inside three-run spread | Recomputed +0.0123% / +0.0404%; A/A 0.0303% / 0.2172% |
| Mean of three unchanged runs and JIT-flat measured windows | Raw cohort rows and runner counters support this for the historical experiment |
| mxfast=0 after rejected cohorts, allocator attribution, not default allocator | Recorded invocation, inherited-env runner and retained allocator attribution support this; not a fresh process-environment capture or rerun |
| Fork minimum setup failure / other jobs pass | Exact-head API shows 14 successful checks and one failure; annotation is unavailable Ruby 2.7.3 on Ubuntu 26.04, and rake was skipped |

The performance qualification therefore resolves the old exact-head attribution problem. No fresh speed measurement or universal Ruby-equivalence claim is made by this review. Existing rejected allocator cohorts stay rejected.

## Rack-maintainer guard and comment audit

The coordinator added Thomas's stricter guard/comment rule during this review. I fetched and read Lowrail `9fa887a3` and its preceding guard rule in DECISIONS before applying it. This is an explicit assessment of each addition, not approval merely because the tests pass. None fails the bar; the smallest code/comment change is therefore **none**.

| Addition | Rack-maintainer bar and reason |
| --- | --- |
| `Utils.escape` URI-fallback guard, `utils.rb:42` | **Keep.** `instance_of?(String)` excludes real String subclasses/SafeBuffer whose class/state/method behavior must not be silently changed, while non-String values such as the existing Symbol case still use URI. `ascii_compatible?` prevents a real supported-runtime failure: clean 3.4.12 has no util loaded, `CGI.escape(UTF16)` raises NoMethodError, but the guard preserves the documented String conversion. One direct `return ... unless` is Rack's existing form, e.g. `get_byte_ranges` and QueryParser's `params_hash_has_key?`; a BasicObject-specific extra predicate or wrapper would not earn its keep. |
| `Utils.unescape` URI-fallback guard, `utils.rb:65` | **Keep as the common guard.** Exact class protects SafeBuffer's security-relevant safety flag on a real direct call, not just arbitrary objects. The ASCII clause is not independently required for ordinary decoder bytes (the mutant survives); it gives the three adapters the single, explicit fast-path domain Thomas requested. Keeping the same short domain check is preferable here to three subtly different eligibility rules or a helper. This does not justify adding more hypothetical-object checks. |
| `QueryParser#unescape` URI-fallback guard, `query_parser.rb:264` | **Keep as the same common guard.** Exact class protects the decoder's String result contract, including actual Ruby 2.7 subclass-preserving parser splits, and keeps subclass state/overrides on URI. The ASCII clause has the same deliberate common-domain justification and the same non-necessity for ordinary decoded bytes as Utils.unescape; I do not claim the mutant demonstrates an independent decoder bug. |
| `Utils.unescape` malformed-percent guard, `utils.rb:67` | **Keep.** CGI accepts malformed `%` sequences that URI rejects. Ordinary incoming query/form/cookie data reaches this boundary; preserving ArgumentError and its exact message is existing API behavior. The inline `raise ... if` copies URI's established check rather than inventing a new validator or exception layer. |
| `QueryParser#unescape` malformed-percent guard, `query_parser.rb:266` | **Keep.** Same real input boundary; `each_query_pair` translates it into Rack's existing InvalidParameterError instead of silently accepting malformed request parameters. No delegation through Utils or new shared helper is needed for this tiny local check. |
| Test encoding object's `raise "converted twice" if @converted`, `test/spec_utils.rb` | **Keep.** This is the small fixture that makes the public once-only encoding conversion test fail on the actual prior double-conversion regression; it does not guard production against a hypothetical internal state. |
| `# On MRI before 4.0, CGI.escape needs cgi/util for ASCII-incompatible strings.`, `utils.rb:41` | **Keep unchanged.** One line, why rather than what: the guard itself cannot explain an older native extension's missing Ruby fallback. A reader testing only Ruby 4 can remove the ASCII clause and see every kept test pass, so the reason for retaining it is genuinely easy to miss. Clean 3.4.12 independently reproduced the missing-superclass-method error. The file already has maintainer-kept Ruby/ERB-version compatibility explanations by its HTML-escape branch; this is a shorter explanation in the same style, not an implementation diary. |

There are no other added code comments in either commit or its tests. Existing method documentation, coverage markers and ERB compatibility comments in the diff context are unchanged; deleting the now-redundant inner require does not require rewriting them. The two remapping statements and the binary-then-force-encoding call do not get extra comments: their rationale belongs in the messages/body and the tests make the mappings observable. This audit adds no new guard/comment must-fix to the text-only verdict.

## Maintainability

No structural must-fix. The production files grow 713→722 and 270→274 lines; the test files remain below 1,000 lines. The three short adapters stay in their owning modules, preserve signatures/visibility, add no wrapper layer, and need no shared helper just to avoid two small decoder bodies. Extracting Utils into QueryParser would introduce coupling instead of deleting meaningful complexity. The short older-MRI comment explains the otherwise surprising escape guard; a common guard across all three methods is a reasonable deliberate choice. The kept tests kill the real subclass and old-MRI regressions without encoding private call order.

## Reproduction and retained evidence

`validation.txt`, `mutants-*.txt`, `review_exactness-*.json`, and the SafeBuffer/Rails receipts next to this file are fresh outputs, not builder receipts. `adversarial.rb` is the added probe used against both actual base and head libs. Source and full suite/random outputs remain under `.amp/in/orb-backup/rk3-confirm-3/` in this thread; this directory also holds `run-version.sh` and the `no-ascii.rb` diagnostic mutant.

Modern checks use the matching mise Ruby first on PATH and `CI=spec bundle exec`; `run-version.sh VERSION` clones the pinned checkout for an independent bundle, runs both full suites, then the supplied three differential scripts in clean/util/pure modes. Old-version exactness uses the same `review_exactness.rb` without the modern bundle. For the new harness use `ruby -I BASE_OR_HEAD/lib adversarial.rb`, add `SAFE=1` with ActiveSupport 8.1.4.1 installed, and use `pure_cgi.rb` on 3.4 or skip loading `cgi/escape.so` on Ruby 4. Compare parsed JSON by input label, including result/input state and events. The report separates the non-contract differences rather than suppressing them to make a green result.
