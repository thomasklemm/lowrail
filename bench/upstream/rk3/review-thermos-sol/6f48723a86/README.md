# RK3 amended-head Thermos review

**Verdict: changes on `6f48723a862129d42e901d2baae16b1b826404bc`.** The restored ASCII-compatible escape guard fixes the earlier P2 loader failure. Two P3 coercion regressions remain. They are low-practicality compatibility edges, not confirmed security vulnerabilities, but they contradict this submission's exactness contract and have small fixes. Do not open with the current universal-equivalence prose.

Reviewer `thermos-sol`, 2026-11-18, thread `T-01a1ec13-3575-7694-b1c3-e0edd9abc152`. Scope: base `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`, unchanged decoder `d85c4b9a42c526490185e0207da2a5b0aaa66de7`, amended escape head above. The [first pass](../README.md) and old-head receipts remain historical. No Rack files were changed or published.

## Two minimal compatibility repairs

1. **Coerce the encoding argument once, after decoding.** `lib/rack/utils.rb:67` and `lib/rack/query_parser.rb:267` pass the encoding to both CGI and `force_encoding`. A duck whose `to_str` returns UTF-8 then ASCII-8BIT changes `%FF` from invalid UTF-8 on base to valid binary on head. A duck which raises on its second conversion changes success into failure. An encoding callback that changes the original `%41` to `%ZZ` also runs before native decoding rather than after it. Both decoder entry points reproduce this. **Smallest fix:** `CGI.unescape(s, Encoding::BINARY).force_encoding(encoding)`. It preserves decoding and performs the caller's conversion only at the original boundary. Do not add another argument guard or pre-coerce the encoding.
2. **Let valid BasicObject coercions reach URI.** `utils.rb:41,64` and `query_parser.rb:264` call `instance_of?` on arbitrary inputs. A BasicObject with `to_s` returning `a b` previously worked through `Rack::Utils.build_nested_query("x" => value)`, producing `x=a+b`; now it raises NoMethodError. BasicObject with the decoder's `b`/`to_str` methods likewise differs. **Smallest fix:** `String === s && s.instance_of?(String)` before each fast path, keeping the escape encoding predicate too. This preserves the intended String-subclass fallback without calling a new predicate on non-Strings.

The changed dispatch on ordinary Strings with singleton `b`/`dup`/`to_s` remains the explicitly accepted boundary, not a newly discovered remote-input vulnerability. The extra predicate itself can also be customized; arbitrary global redefinition of fundamental String methods is not certified. The pure implementation still invokes some String methods, so do not claim that all engines now call nothing on the argument.

## Exact-head runtime evidence

| Execution | Result |
| --- | --- |
| Ruby 3.4.12, ERB 6.0.7, no preload | Full Rack suite: 1,292 runs, 6,270 assertions, 0 failures/errors, 2 skips; all separate-file tests pass |
| Ruby 3.4.12, `-rcgi/util` | Same full-suite result |
| Ruby 4.0.9, ERB 6.0.7, no preload | Same full-suite result |
| Ruby 4.0.9, `-rcgi/util` | Same full-suite result |
| Original escape and unescape differential scripts | 300,000 random cases + 9 fixed each, zero ordinary differences in all four configurations above, under `CI=spec bundle exec` |
| Expanded deterministic matrix | 17,897 comparisons in each of eight configurations; only the two coercion finding families differ |
| Diagnostic repairs, not a Rack commit | Zero differences in all eight expanded matrices |
| Real ActionDispatch 8.1.4.1, Ruby 4.0.7 | GET/POST/cookie results and errors match the pinned base after the receipt header |

Eight matrix configurations: MRI 2.7.3, 3.4.12 and 4.0.9 each with and without explicit `cgi/util` preloading, plus pure-Ruby CGI on 3.4 and 4.0. The 2.7 no-preload process still loads util incidentally through old ERB; it is **not** a no-util result. On 3.4/4.0, receipt metadata confirms util absent in clean native runs and present with the preload. Pure 3.4 loads util deliberately; pure 4 defines the Ruby implementation in `cgi/escape.rb` without util. Native runs have nine matrix differences (three BasicObject calls, six encoding-duck calls); pure runs have seven, because Ruby's CGI decodes before its encoding conversion, removing the mutation-timing difference but not double conversion.

The matrix covers UTF-8, ASCII-8BIT, US-ASCII, ISO-8859-1, Shift_JIS, UTF-16/32 LE/BE and dummy encodings, ISO-2022-JP, invalid bytes, thirteen ordinary encoding arguments plus conversion ducks, genuinely frozen and chilled strings, `+` versus `%2B`, trailing/incomplete/mixed-case/doubled percent sequences, non-Strings with `to_s`/`to_str`, subclasses, BasicObject, roughly megabyte inputs, result class/bytes/encoding/validity/frozenness and exception class/message. Old-head chilled-mutation checks remain applicable to the unchanged decoder; the current matrix reruns chilled result comparisons. The builder's decode generator calls `dup` after freezing, so its frozen-input claim relies on this independent matrix instead.

ActionDispatch GET uses its URI decoder directly, POST uses Rack's query parser, and cookies use Utils. Invalid `%` and invalid UTF-8 retain the same wrapping/messages. These ordinary request paths do not supply the custom objects that expose the two findings. `rails-head.jsonl` is the amended-head execution; its non-header lines equal `../rails-base.jsonl` byte for byte.

### Reproduction commands

From Lowrail root, with the selected Ruby's `bin` first on PATH and no inherited RUBYOPT:

```sh
# Run inside .amp/in/orb-backup/rack; repeat on 3.4.12 and 4.0.9:
CI=spec bundle exec rake
CI=spec RUBYOPT=-rcgi/util bundle exec rake

# From Lowrail root; native, explicit util, and diagnostic fixed implementation:
ruby -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
ruby -rcgi/util -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
ruby -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_fix_probe.rb

# Pure 3.4:
ruby -r ./bench/upstream/rk3/pure_cgi.rb -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
# Pure 4.0, whose escape.rb supplies Ruby methods before optionally loading the extension:
ruby -rrbconfig -I .amp/in/orb-backup/rack/lib -e '$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so"); load ARGV.fetch(0)' bench/upstream/rk3/review_exactness.rb
```

The random scripts were run from the Rack checkout with `CI=spec bundle exec ruby -I lib`, loading each script after shifting its path out of ARGV so it retains the actual 300,000 default. Each receipt explicitly reports both its case count and util load state. These scripts print mismatches without failing their exit status; the expanded matrix does fail. The initial Bundler attempt omitted CI=spec and requested an uninstalled external-test dependency; matching the suite's Gemfile selection fixed that harness invocation, not Rack.

## Minimum Ruby and alternate engines

The pinned gemspec requires **>=2.7.3**, not 2.4. CGI was stdlib in 2.4 and became a **default gem** in 2.7; do not call it a RubyGems bundled gem. The actual MRI 2.7.3 was compiled and its matrix executed locally. No full 2.7.3 suite is claimed.

Pre-4 MRI `cgi/escape` may load only the extension, whose ASCII-incompatible path calls `super` into util's Ruby fallback. The restored guard correctly avoids that dependency. Ruby 4.0.9's `cgi/escape.rb` defines the fallback itself before loading the extension, and util is a compatibility shim. Thus the amended commit's “not loaded unless cgi/util is” sentence needs **older MRI** qualification, not a different guard.

The independent maintainability reviewer checked current engine sources as well as the earlier CGI sources: [JRuby at 6cba11e7](https://github.com/jruby/jruby/blob/6cba11e7ed149423b686a73c4a6d5d35736f43a6/lib/ruby/stdlib/cgi/escape.rb#L169-L179) selects Java; [TruffleRuby at 6f82eb3a](https://github.com/truffleruby/truffleruby/blob/6f82eb3ab986c1c98ae45092410ab87da067ffb5/lib/mri/cgi/escape.rb#L169-L175) skips the C extension. Neither VM was executed here. The builder reports green head-engine CI, which is not a version-wide execution guarantee or a speed claim. The scripts' “as on JRuby and TruffleRuby” pure-CGI comment is too broad for JRuby.

### The hosted 2.7.3 failure is provisioning, not tests

The [new-head job](https://github.com/thomasklemm/rack/actions/runs/44209391097/job/134483564156) fails in five seconds in `ruby/setup-ruby@v1`; `bundle exec rake` is skipped. Public annotations explicitly state:

> Unavailable version 2.7.3 for ruby on ubuntu-26.04. Only the latest patch release of each series is built for newer runner images. ruby-2.7.8 is available on ubuntu-26.04. Cause: Unexpected HTTP response: 404.

The correctness reviewer found the same annotation on the [previous-head job](https://github.com/thomasklemm/rack/actions/runs/44203060694/job/134461843792). Full log downloads returned 403; no claim of reading the full logs. This pass independently fetched the new job metadata and check annotations into `ci-2.7.3-*.json`. This range does not change the workflow. If hosted verification of the exact minimum is required, use an image/source build that supplies 2.7.3; substituting 2.7.8 does not test the floor.

## Claim and benchmark audit on the amendment

The first pass audits every sentence of the then-current messages/body. This section replaces the parts changed in Lowrail a9f0b8c2 and the amended escape commit:

* **New escape message:** the restored fallback is correct; qualify “in C” to native MRI, and “not loaded unless cgi/util is” to older MRI layouts. The existing claim that a signed cookie has dozens of escapes is not universal; it describes the selected Base64-shaped input. The `*`/`~` explanation and `%2A` argument remain correct.
* **Body implementation paragraph:** the new non-ASCII-compatible fallback sentence describes the guard correctly but needs the same older-MRI qualification for why util is required. Ordinary Symbols/objects/subclasses do reach URI, but the blanket “anything that isn't a String” claim remains false for BasicObject. Decoder requested-encoding behavior still needs finding 1's repair. C/native and Rails GET caveats from the first audit remain.
* **Updated body table:** independent arithmetic from `docs/upstream/data/rk3/body-ips/` gives interpreter 1.766x / 2.112x / 3.106x and YJIT 1.997x / 2.193x / 3.525x, matching rounded draft rates. Maximum main spread is **9.124%**; “up to 9%” is reasonable whole-percent rounding, “about 9%” is clearer. This is the builder's new-head cohort, not my noisy old-head rerun. That old 56–210% cohort stays inconclusive and is not rerun until green.
* **Cookie micro figure:** a fresh interpreter main/main/head execution gives **90,311 / 90,303 -> 14,369 Ir/op**, supporting the rounded **90.3k -> 14.4k** in the amended draft, with A/A spread about 0.009%. `micro-escape-interp-aa.txt` records the actual paths. The unchanged decoder's 51.1k ->16.4k is historical arithmetic, not a new experiment. Micro YJIT is not certified by the old harness's missing per-window JIT-flat check.
* **New exactness paragraph:** original-script zero-difference results independently reproduce on 3.4/4.0 with and without util. I did not execute 3.2/3.3. The claimed frozen decode coverage is absent from that generator; the independent matrix supplies it. “The only difference” is still false because of the two coercion findings. Scope the sentence to the tested input population even after repair, rather than claiming exhaustive equivalence from fuzzing. Use impersonal rather than first-person submission prose.
* **Whole-request paragraph:** interpreter and accepted-flat YJIT deltas/A/A still recompute as below. These are **historical pre-restored-guard receipts**, not exact-head whole-request runs. App copies and exact bundles are absent in this orb, so the three-app experiment was not rerun. The guard's 430-instruction/call increment and “at most 900/request, under 0.02%” are estimates, not a measured bound over every request or YJIT. Do not label those exact-head measurements. Update through `script/upstream-bench` on the submission head or explicitly label the historical/estimated scope. Objects include workload/reset/harness work, unlike request-only instruction windows.
* **JSON control:** interpreter −0.024% is inside 0.032% A/A; accepted-flat YJIT **+0.203%** exceeds its **0.170%** A/A. Replace “unchanged” with those qualified results; this audit does not explain that small difference.
* **Changelog/style:** the queue note's “no perf entries; 2550 has none” is false. The [2550 diff](https://github.com/rack/rack/pull/2550.diff) includes an entry; CONTRIBUTING asks for one. Add a short Unreleased/Changed line. In [2099](https://github.com/rack/rack/pull/2099), Jeremy withdrew a speculative loader concern and preferred direct define_method binding, while eregon preferred a wrapper. No direct binding can replace this compatibility adapter. The later nil regression there supports testing coercion, not deleting these guards.

| Historical workload | Interpreter both / A/A | Accepted-flat YJIT both / A/A |
| --- | ---: | ---: |
| blog PATCH article | −5.115% / 0.041% | −9.801% / 0.157% |
| pingcrm PUT contact | −2.952% / 0.012% | −5.451% / 0.201% |
| blog GET article | −1.541% / 0.082% | −2.832% / 0.249% |
| codetriage GET repo | −1.012% / 0.022% | not measured |

`receipt-audit.txt` recomputes these figures, JSON, object savings and the new table. Accepted YJIT windows report 0/0 blocks/invalidations. The original pingcrm cohort with 14 new blocks remains rejected; the FLAT=40 cohort is separately labeled, not a silent retry. Aggregate receipts and counters do not prove missing raw app pins or rerun the experiment.

## Maintainer fit, independent reviews and PR shape

**One PR retaining both commits.** They implement the same URI-compatible component conversion migration, so maintainers can review the shared loader/coercion/encoding contract once; two commits remain independently reviewable and revertible. Split only if a maintainer asks to merge decode while discussing escape. Neither cited precedent establishes a general split preference.

Keep the direct small adapters. A QueryParser-to-Utils call reverses the current dependency, a new shared module is disproportionate, chaining `gsub!` is incorrect because either can return nil, and a replacement block/hash adds work rather than clarity. Keep both explicit top-level requires, remove the redundant inner `escape_html` require, and add only short why-comments for the compatibility boundaries. Focused test descriptions and `escape(nil)` coverage are nits, not structural blockers.

Both original read-only Task reviewers resumed on the amended range, with no new threads or nested reviewers. Correctness independently confirmed the fix, retained the two P3 findings as nonblocking under an ordinary-input contract, and returned **approve with nits**. Maintainability returned **approve with nits**, withdrew its earlier advice against the encoding guard and identified the new message qualification. Neither ran suites or benchmarks; those are the executions above. Synthesis deliberately remains **changes** for the user-specified exactness goal, not because the P3 cases are a security blocker. Fixing the two small behavioral differences and the overstated submission claims is preferable to silently narrowing the compatibility contract.
