# RK3 Thermos review, 2026-11-18

**Historical first pass.** The [amended-head review](6f48723a86/README.md) supersedes this verdict's P2 finding and clean-suite failure: `6f48723a86` fixes the UTF-16 fallback. It retains the two P3 coercion findings, with fresh suites, matrices, claim audit and receipts. The record below applies only to `a8a5d747d0`.

**Verdict: changes. Do not open this head as a PR yet.** Reviewed `rack/rack` base `da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f` through fork head `a8a5d747d0956efe7af5a0b36520f1d0a9698b40`, including `d85c4b9a42`. Reviewer: `thermos-sol`, thread `T-01a1ec13-3575-7694-b1c3-e0edd9abc152`. The Rack checkout was not modified or pushed. The title and body in the queue item remain the reviewed draft, not an approved submission.

## Must fix before opening

### 1. Preserve the ASCII-incompatible-input fallback

**Introduced compatibility regression, P2.** `lib/rack/utils.rb:5,43` uses `cgi/escape` directly. On MRI 3.4.12 with the supported ERB 6.0.7 that loads only `cgi/escape.so`, not `cgi/util.rb`. The C `escape` delegates non-ASCII-compatible input to `super`, but that Ruby implementation has not been loaded:

```ruby
require "rack/utils"
Rack::Utils.escape("a b~".encode("UTF-16LE"))
# main: "a%00+%00b%00%7E%00"
# head on 3.4.12: NoMethodError: super: no superclass method 'escape' for class CGI
```

Evidence: `suite-3.4.12.txt`, `builder-escape-3.4.12.txt`, and `exact-3.4.12.json`. The builder's own 300,000-case escape script gives **59,722 differences** on this clean 3.4.12 process. The new UTF-16 test fails in the regular suite: 1,292 runs, 6,269 assertions, 0 failures, **1 error**, 2 skips. Main passes (1,286 runs, 6,245 assertions, 0 errors); preloading `cgi/util` makes the head's full regular and separate-file suites pass (1,292 runs, 6,270 assertions). This establishes the missing fallback, not a general incompatibility between CGI and URI's byte escaping.

**Smallest fix:** retain URI for ASCII-incompatible escape inputs by extending the existing guard with `s.encoding.ascii_compatible?` (and the receiver-independent check in finding 3). This removes the accidental ERB initialization dependency without adding a version-sensitive loader. Loading `cgi/util` is another verified repair, but its Ruby 4 shim warns with `-w`; use that alternative only with a deliberate loader design. Keep both Rack files independently loadable and remove the now-redundant require in `escape_html`.

The old pure-Ruby test preload is not a test of this loader: it requires `cgi/util` before Rack, masking exactly the failure above. A require interceptor can demonstrate the new standalone-parser dependency on `cgi/escape`, but that does not establish a bug on supported alternate engines: the inspected JRuby and TruffleRuby distributions provide their own loaders, described below. No generic LoadError rescue is justified by this evidence.

### 2. Preserve once-only conversion of the encoding argument

**Introduced observable API regression, P3.** `utils.rb:63–67` and `query_parser.rb:263–267` pass `encoding` first to `CGI.unescape` and then to `String#force_encoding`. Both can invoke `to_str`; URI invokes it once, after decoding. A changing conversion changes the result encoding; a conversion which raises on its second call now makes a previously successful decode fail:

```ruby
def encoding
  calls = 0
  Object.new.tap do |object|
    object.define_singleton_method(:to_str) do
      calls += 1
      raise "converted twice" if calls > 1
      "UTF-8"
    end
  end
end
URI.decode_www_form_component("%41", encoding) # => "A"
Rack::Utils.unescape("%41", encoding)         # raises "converted twice"
```

Verified on MRI **2.7.3, 2.7.8, 3.4.12, 4.0.9**, and the pure-Ruby CGI paths on 3.4 and 4.0. `review_exactness.rb` also returns UTF-8/invalid on main versus ASCII-8BIT/valid on head for `%FF` with an encoding duck returning those two names in succession. Both decoder entry points differ. If `to_str` mutates the original `%41` into `%ZZ`, main returns `A`, while head sees the mutation after validation and returns `%ZZ`. This requires an application callback, not remote query data alone; no remotely exploitable validation bypass was established.

**Smallest fix:** `CGI.unescape(s, Encoding::BINARY).force_encoding(encoding)` in both adapters. All decoded bytes are valid as binary; the final force_encoding performs the caller's conversion once, at URI's original boundary. The correctness reviewer proposed this shorter repair, and the integrated diagnostic probe verifies it. Sending non-Encoding arguments back through URI also works but needs another guard and is unnecessary. Do not normalize the encoding before validation or decoding. Combining this change with the other two repairs makes **all 17,897 checks pass** in the configurations below (`fix-probe-*.json`), without preloading `cgi/util`. That is a minimal-fix experiment, not approval of a new Rack commit.

### 3. Let BasicObject-based values reach URI's existing coercion

**Introduced observable API regression, P3.** All three new `instance_of?` guards call a method that BasicObject does not provide. A `Class.new(BasicObject) { def to_s; "a b"; end }.new` is accepted by URI.encode_www_form_component but raises at the new guard; `Rack::Utils.build_nested_query("x" => value)` changes from `x=a+b` to NoMethodError. A BasicObject implementing the original decoder's `to_str` and `b` also decoded successfully before and fails at the new predicate. The independent correctness reviewer found this; the matrix and direct public-caller reproduction confirm it.

**Smallest fix:** prepend the receiver-independent test `String === s && s.instance_of?(String)` to each fast-path guard. Non-Strings then reach URI without receiving the new predicate. Keep the exact-class exclusion of String subclasses. The diagnostic fix probe includes this repair.

### 4. Correct the claims and refresh evidence on the repaired head

**Submission correctness.** The current body's universal exactness claim and its only-one-boundary sentence are false at the reviewed head because of findings 1–3. The queue note's four-version green-suite assertion is not reproducible on clean 3.4.12. The note's explanation for omitting a changelog is also false: [Rack's contribution guide](https://github.com/rack/rack/blob/da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f/CONTRIBUTING.md#update-changelog) asks for an entry, and the current [2550 diff](https://github.com/rack/rack/pull/2550.diff) contains a performance entry. Add one short Unreleased/Changed line.

**Smallest fix:** fix the three code defects, rerun clean-process suites and differentials, replace the unsupported sentences and update the head and evidence. Scope C-speed claims to MRI with the native accelerator. Say Rack's query/form parser and cookie helpers, not every Rails query parameter: ActionDispatch GET uses URI directly. Qualify the JSON performance control rather than calling it unchanged; the historical YJIT receipt is **+0.203%**, against **0.170%** base spread. Do not call synthetic Base64 data an actually encrypted cookie; it has the shape and 284-byte size of one. The draft also uses first-person verification prose where the repository's submission convention asks for impersonal wording.

## Runtime evidence and coverage

Commands below run from Lowrail's root unless stated otherwise. The test Ruby installations are under `~/.local/share/mise/installs/ruby/VERSION/bin`; set that directory first on PATH for Bundler. The Rack clone is `.amp/in/orb-backup/rack` at the head above; `.amp/in/orb-backup/rack-base` is a detached worktree at the base. Both use the same generated Gemfile.lock. It selected minitest 6.1.0 and rake 13.4.2 for the two suite Rubies; no CGI gem was added.

```sh
# In each Rack checkout, clean RUBYOPT, CI=spec:
CI=spec bundle exec rake
# Diagnostic only, in the head checkout:
CI=spec RUBYOPT=-rcgi/util bundle exec rake

ruby -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
ruby -r ./bench/upstream/rk3/pure_cgi.rb -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_exactness.rb
ruby -I .amp/in/orb-backup/rack/lib bench/upstream/rk3/review_fix_probe.rb
ruby bench/upstream/rk3/review_receipts.rb
```

* **4.0.9 full Rack suite:** 1,292 runs, 6,270 assertions, 0 failures/errors, 2 skips; all separate-file tests passed. `suite-4.0.9.txt`.
* **3.4.12 full Rack suite:** head fails as above; base passes; head with `cgi/util` preload passes all regular and separate-file tests. `suite-{main-3.4.12,3.4.12,3.4.12-preloaded}.txt`. The preloaded run is deliberately labeled, not represented as a clean pass.
* **2.7.3 and 2.7.8:** compiled locally; matrix probes ran on both, not full suites. `exact-2.7.*.json` and `load-2.7.8.txt`. Utils loads `cgi/util` incidentally through the old ERB, so UTF-16 escaping happens to work there. The encoding-argument and BasicObject defects remain. The correctness reviewer also checked standalone parser loading and ordinary inputs on the exact minimum, 2.7.3.
* **Own matrix:** 17,897 method comparisons per configuration. UTF-8, ASCII-8BIT, US-ASCII, ISO-8859-1, Shift_JIS, UTF-16/32 LE/BE and dummy encodings, ISO-2022-JP; invalid bytes; mutable and genuinely frozen inputs; a chilled literal; 13 ordinary encoding arguments plus stable/stateful/erroring/input-mutating conversion ducks; `+`, `%2B`, NUL, trailing/incomplete/mixed-case/doubled percent sequences; non-Strings with `to_s`/`to_str`, invalid `to_s` results, String subclasses and BasicObject; four roughly one-megabyte inputs. Compare result class, bytes, encoding, validity, frozen state and exception class/message. Native 4.0, native 2.7 and pure 3.4/4.0 differ at BasicObject and the encoding ducks; native clean 3.4 additionally has 3,458 matrix escape mismatches from the absent fallback. The diagnostic fixes give zero differences in every one of these six configurations. Native fix probes do not preload `cgi/util`; pure probes necessarily select the Ruby implementation explicitly.
* **Original differential scripts rerun:** native 4.0 both 300,000-case scripts give zero differences; native 3.4 decode gives zero and escape gives 59,722 differences. Their summary does not exit nonzero on differences. The decode script duplicates input after freezing it, so it does not actually exercise frozen decode inputs; own matrix does. These random cases contain only Encoding objects as targets, so cannot detect finding 2. The scripts' singleton `b`/`dup`/`to_s` differences are intentionally disclosed, not folded into the ordinary success count.
* **Chilled strings on 3.4:** returned strings from URI and Rack can all be appended to without deprecated-literal warnings. Mutating the original chilled input emits the expected warning. `chilled-3.4.12.txt`.
* **Rails 8.1.4.1 integration on Ruby 4.0.7:** `review_rails.rb`, `rails-{base,head}.jsonl`. ActionDispatch GET and POST, valid `+`/escaped-plus/multibyte/mixed-hex params, invalid bytes, lone/doubled percent, cookie parsing including invalid `%`, Set-Cookie `*`/`~` mapping: outputs and exception messages identical after the version/path receipt header. GET invokes no Rack decoder; POST invokes Rack's query parser (4 calls for the two-field case); three cookie values invoke Utils 3 times. Rails rejects invalid UTF-8 with BadRequest on both. This executes actual ActionDispatch, not a Rails-shaped mock.
* **Boundaries:** plain String singleton overrides of `b`, `dup`, `to_s`, or URI method instrumentation/prepends are no longer observed by the native path. String subclasses and ordinary non-Strings retain URI delegation. The exact-class check itself is a new Ruby method call; globally overriding fundamental predicates/encoding/String operations is not certified. The tested pure-Ruby CGI implementation still calls some String methods, so the blanket assertion that the branch calls nothing on its argument is not portable across implementations.

For Rails integration, `GEM_HOME` and `GEM_PATH` pointed at the existing `.lowrail/gate-gems/4.0.7-x86_64-linux-229531a6cfbf07e3caef30dbac24a2a3f3fed482` installation plus the 4.0.7 default gem directory. The first line of each receipt identifies the actual Action Pack version and Rack load path. The checked-out Rails source at `c3466ea00d7121798e3aa3144ffdf7174b81d8cb` has the same caller design: `action_dispatch/http/query_parser.rb:46–47`, `http/request.rb:444–453`, `middleware/cookies.rb:445`.

## Ruby version and engine support

The premise “Rack supports 2.4+” is historical, not true at these pins. Both base and head require **Ruby >=2.7.3** in `rack.gemspec:28`. Commit `ad27aed5` raised it from 2.4.0 on 2026-08-14. No Ruby 2.4 support claim is needed for this PR.

CGI was part of Ruby's standard library in 2.4; it was not a separately listed bundled gem in that release. [Ruby 2.7 NEWS](https://github.com/ruby/ruby/blob/v2_7_0/NEWS#L703-L707) lists CGI's promotion to a **default gem**. The actual 2.7.8 install reports `cgi-0.1.0.2`, default=true; 3.4.12 reports `cgi-0.4.2`, default=true. “Bundled with Ruby” in ordinary prose must not be confused with RubyGems' distinct “bundled gem” category. A default gem can be replaced by another installed version, so do not infer the CGI implementation only from RUBY_VERSION.

On pre-4 MRI, `cgi/escape` is the C extension, and `cgi/util` defines the Ruby implementations and attempts to load the accelerator. On the supplied 4.0.9 install, escaping remains in the standard library without an installed CGI gem specification: `cgi/escape.rb` defines the Ruby holder and methods and then attempts `cgi/escape.so`. Its `cgi/util.rb` is a compatibility shim, warning under verbose mode. Thus unconditional `cgi/escape` on MRI is not equivalent to loading both implementations on every supported version. The compatibility shim has changed independently of Rack.

The original record's “JRuby and TruffleRuby get the Ruby fallback” is too broad. [CGI 0.3.6's JRuby loader](https://github.com/ruby/cgi/blob/v0.3.6/ext/java/org/jruby/ext/cgi/escape/lib/cgi/escape.rb) loads `cgi/escape.jar` and `org.jruby.ext.cgi.escape.CGIEscape`, a **Java accelerator**, not the MRI C extension or necessarily the pure-Ruby method. [TruffleRuby 25's replacement](https://github.com/oracle/truffleruby/blob/vm-25.0.0/lib/truffle/cgi/escape.rb) requires `cgi/util`; its CGI utility code deliberately avoids the C extension. Both sources were fetched and read. Neither alternate engine was executed; simulating pure CGI on MRI is not engine coverage or a performance claim on either VM. Their direct `cgi/escape` loaders make speculative rescue machinery unnecessary absent a failing engine case.

## Performance claims: arithmetic verified, request experiments not rerun

`review_receipts.rb` independently recomputes every draft body table row and all historical whole-request deltas and A/A spreads. `receipt-audit.txt` retains its output. The original corpus copies and exact bundles for blog/pingcrm/codetriage are not in this orb, so no claim is made that those whole-request experiments were rerun. The existing receipts are aggregates, not raw Valgrind logs and app pins; they establish their arithmetic and reported JIT counters, not the complete experiment's provenance.

| Historical workload | Interpreter both / A/A | Accepted YJIT both / A/A |
| --- | ---: | ---: |
| blog PATCH article | −5.115% / 0.041% | −9.801% / 0.157% |
| pingcrm PUT contact | −2.952% / 0.012% | −5.451% / 0.201% |
| blog GET article | −1.541% / 0.082% | −2.832% / 0.249% |
| codetriage GET repo | −1.012% / 0.022% | not measured |
| blog JSON control | −0.024% / 0.032% | +0.203% / 0.170% |

Interpreter base is the mean of two none.rb runs; YJIT base is the mean of three. Every accepted YJIT row reports 0/0 compiled blocks/invalidations. The initial pingcrm cohort in `req-yjit.txt` compiled 14 blocks and is rejected as a whole; the accepted pingcrm row comes only from the explicitly changed `FLAT=40` protocol's separate `req-yjit-pingcrm-flat.txt`. The earlier no-flat cohort stays rejected. The arithmetic above does not salvage rejected cohorts. The headline ranges −1.0%…−5.1% and −2.8%…−9.8% and interpreter object savings 55.9…135.7 do match these aggregate receipts.

Object counts in `req.rb` bracket the entire workload and reset, unlike Callgrind's request-only toggle. They include rack-test/harness work. Do not describe the 56–136 saved objects as independently isolated inside `Rails.application#call`.

The body benchmark's historical best-of-three rates and ratios all agree with `body-ips/*.json`, as does its maximum main spread of 23%. Those data measure five form fields and a synthetic 284-byte encrypted-cookie-shaped input. The interpreter cookie micro counts 51,141/51,116 → 16,378 (decode) and 90,343/90,287 → 13,930 (escape) agree with the body's rounded values. The old micro YJIT script has no per-window JIT-flat check; its results are not certified here.

The exact body benchmark was also rerun for three alternating rounds per side in interpreter and YJIT mode on core 1 (`body-ips/`, `body-ips-table.txt`). This orb's load varied badly, including the old-Ruby build during part of the run: main spreads are **56–210%**. The entire wall-time rerun is **inconclusive**, not replacement speed evidence; it was not rerun until green. Historical table arithmetic is verified, but this pass does not independently reproduce its speed ratios. Before submission, use the repository's `script/upstream-bench` body-number protocol on the repaired head and retain exact app/bundle pins if continuing the request claims.

## Every commit-message and body claim

* Decode commit, sentence 1: URI's copy/gsub/hash lookup verified in the installed URI source (4.0 `uri/common.rb:430,476`); no full C implementation is implied for all engines.
* Decode commit, sentence 2: native CGI decodes `+` and valid `%XX` as claimed for ordinary inputs. Scope “in C” to native MRI; the Ruby fallback is not C.
* Decode commit, final sentence: invalid-percent validation/message and ordinary Object-based non-String fallback reproduce; BasicObject fallback does not (finding 3), and requested-encoding equivalence fails for stateful encoding ducks (finding 2). Subclasses are deliberately excluded too, although the sentence only says non-Strings.
* Escape commit, first sentence: URI uses `to_s.dup` and hash-based `gsub!` in the installed versions; a Base64 cookie often has escaped characters, but “a signed cookie value has dozens” is not universal. The deterministic benchmark's `=`/`+`/`/` population supports only this input, not all signed cookies.
* Escape commit, remaining sentences: `*`/`~` differences and `%2A` mapping are correct; literal `%2A` becomes `%252A`, so mapping cannot confuse literal percent input with an escaped star. “Does the same in C” needs the native-accelerator scope and a fallback for non-ASCII-compatible strings.
* Body paragraph 1, sentence 1: correctly identifies Rack's three entry points; avoid implying that every Rails GET query key passes through them. Cookie deletion also writes an empty escaped value; it is not specifically a session-cookie-only API.
* Paragraph 1, sentences 2–3: URI work verified; existing HTML fallback require verified on the base. ERB gem upgrades can supply `ERB::Escape` independent of the interpreter version, so “on Ruby before 3.2” is shorthand, not the actual feature test. CGI speed is native-path-only.
* Paragraph 2, sentences 1–2: decoder, invalid-percent guard, ordinary forced result encoding and parser error wrapping reproduce; finding 2 limits the equivalence claim.
* Paragraph 2, sentences 3–4: escape mappings and fallback dispatch reproduce for Object-based non-Strings and String subclasses, subject to finding 1's initialization dependency; not for BasicObject (finding 3).
* Benchmark code: five fields and 284 bytes verified by executing the script. The cookie is random Base64 in encrypted-cookie format, not produced by a Rails encryptor. Prefer a short “Rails-style cookie” description. No added production code comments appear in the Rack diff.
* Table and following two sentences: historical rates, round selection, 23% spread and rounded interpreter instruction counts agree with receipts. New wall-time run is inconclusive as explained above.
* Differential paragraph, first sentence: **false as written**, because clean 3.4 escape differs and frozen decode is not tested by that script. This pass did not install 3.2/3.3, so their historical reports are not independently certified. The claimed input union is broader than either one random generator: decode lacks random UTF-16 input (only fixed examples); escape has it. Pure 3.4 matches ordinary inputs only after manually preloading the fallback.
* Differential paragraph, “only difference”: **false**, findings 2 and 3 are additional boundaries and finding 1 is a real runtime failure. Native String-method hook changes themselves are acknowledged accurately.
* Differential paragraph, tests sentence: the tests do cover the listed mapping/result/subclass/error behaviors; the UTF-16 test usefully fails on clean 3.4. They do not cover encoding-duck conversion count or non-MRI loader behavior. The sentence is unnecessary submission narration but not independently a runtime defect.
* Last paragraph, request gains and object range: match aggregate receipts; not rerun against the original three apps here. Object counts have the wider measurement scope described above. JSON “unchanged” is too categorical for the YJIT control.

## Maintainer fit and one PR versus two

**One PR, keep the two commits.** Both migrate the same URI-compatible form-component boundary to CGI. One review can assess loading, coercion, encoding and native/fallback compatibility together, while the two small commits remain individually reviewable and revertible. Split only if a maintainer wants decode merged while debating the escape mapping; neither precedent requires that overhead in advance.

Thermos ran its two read-only Task reviews in parallel, with no additional threads or nested reviewers. The correctness reviewer loaded `thermo-nuclear-review` and returned changes for the three code findings above, independently reproduced before synthesis. No remotely exploitable security defect was confirmed. The maintainability reviewer loaded `thermo-nuclear-code-quality-review`, found no structural blocker and returned approve-with-nits, conditional on runtime verification. The unified verdict is changes, not their average.

Keep the two small decoder adapters; routing QueryParser back through Utils reverses the existing dependency (`Utils` already loads QueryParser), and a new file/module is disproportionate. Do not replace the exact-class check with `is_a?` alone, chain the `gsub!` calls (nil return), or use a block/hash substitution merely to save lines. Decoding to binary is shorter and more exact than adding encoding-argument normalization or another fallback guard. In tests, `"\xFF"` already has the source's UTF-8 encoding; its `.dup.force_encoding` can be shortened. Splitting the mixed malformed-percent assertion out of the parser encoding example is optional.

[2550](https://github.com/rack/rack/pull/2550) shows Jeremy approving a small local optimization, with no substantive inline style request, and includes a changelog entry. [2099](https://github.com/rack/rack/pull/2099) is especially relevant: Jeremy initially asked about guarding CGI loading, withdrew that concern after checking availability, and preferred the `define_method` alternative for direct method binding. The ordinary wrapper preference came from eregon, not Jeremy. Binding CGI directly cannot implement this adapter's validation, URI fallback and output normalization. Its later nil/non-String regression is a reason to retain coercion compatibility here, not a reason to trust delegation without tests. Do not infer a maintainer's universal style from one approval. GitHub authenticated API reads were rate-limited; public pages and diffs were used read-only. Nothing was posted.

## Scope limits

No assertion of exhaustive equivalence, native JRuby/TruffleRuby execution, old-version full-suite success, hosted CI coverage, full three-app rebenchmark, or a repaired Rack head follows from this pass. The review is pinned to the specified two commits. A new code head needs fresh evidence and review.
