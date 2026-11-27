# UR1 detailed thermos-sol review — 2026-11-27

Verdict: **approve** c43954f and the outgoing body at Lowrail `5bfaa607`, with no open must-fix. The explicitly
accepted JRuby 9.4 class difference is accurately disclosed. The completed native benchmark and both wall
cohorts clear the interim publishing gate after independent raw-log and arithmetic checks.

Reviewer: thermos-sol. Orb: `T-01a21e96-739d-740a-b7cb-15145f86d1a8`.
Both Thermos rubrics were applied by this reviewer, without parallel reviewers, as explicitly requested.
No upstream post, comment or fork push was made.

## Scope and identity

Final head: `c43954fa4d2a7605e18ecc8968c1aa188eae549a`, one commit on
`48cda77031e343d35213c36fe164b2a46ffbefa7`. The final commit changes only its message from tested heads
`cecaed123f04e1704bccf4b1b3272c0b12e759c7` and `7da6979b27b2aba69c4076d8f01939e5a8c0f1f6`; all have tree
`b4d512787702911904b7ec8d51b0ec07744ec7c9`. The final message was fetched and read separately. Its author and
committer are Thomas Klemm; it has no trailers. The original assigned head was `a3b201f05b`.
The reviewed outgoing body (title and boundary whitespace included) has SHA256
`32bcb43281dca3befc826674bce6cc5ede2c37f973c10808c69f0e956aa5e04a`.

The final code validates percent escapes, calls `CGI.unescape(str.b, Encoding::BINARY)`, then force-encodes the
result. Unlike the original candidate, it keeps `String#b` and has no input-type/encoding fast-path guard.
`decode_uri_component` and its private helper remain unchanged.

## Verdict: approve

No open must-fix. Code, security, maintainability, added tests/comments, commit message, body and impact pass
within the explicitly accepted boundaries. No new guard or normalization is requested.

The interim text/evidence gate was real: the body at `4f0a4011` led with only counted work while native timing
was pending. Lowrail `5bfaa607` now leads with the completed benchmark-ips table and keeps the benchmark script
and raw output in the record. Its final sentence covers both independently checked JIT cohorts; it does not
turn instructions or allocations into time. This resolves the gate without an implementation change.

## Accepted JRuby 9.4 class difference

The ordinary String subclass result changes on JRuby 9.4.16.0. This maintenance release was published on
November 23, 2026, not an abandoned engine version. With no method overrides:

```ruby
class Component < String; end
URI.decode_www_form_component(Component.new("a")).class
# base: String; candidate: Component
```

Empty input also differs; `+` and `%41` do not. JRuby 9.4's `b` preserves the subclass, whereas base's `gsub`
normalizes it; CGI's no-escape path preserves it. The candidate's own new subclass assertion catches this
when run on 9.4 rather than latest JRuby 10.1. The independent probe has 1,905 differences in 42,264 cases;
an additional checker confirms every retained difference is class only, with bytes, encoding, validity,
frozen state, ownership, conversion events and mutation equal. This is not a custom-hook-only difference.

The coordinator explicitly accepted it and added the body sentence; c43954f also qualifies its commit's
same-class claim. That disclosure accurately describes the executed cases. Plain Rack/Rails request bytes
do not choose a String subclass. The branch's JRuby CI covers current 10.x, not this 9.4 maintenance series.
Do not describe JRuby 9.4 as unsupported or claim its suite passes: the new class assertion fails there.

I proposed `str.b.to_s` and confirmed zero differences in the same independent corpus on all five engines.
That proposal was incomplete: Astra demonstrated that real ActiveSupport::SafeBuffer returns itself from
`to_s` on JRuby 9.4, and overriding `to_s` could newly replace bytes or raise. The coordinator reverted it;
the final tree has no `to_s` call. Its five-engine probes and plain-input sweep are retained as abandoned
variant evidence, not used to price the restored tree. No new normalization or guard is requested.

## Findings resolved during this review

1. **Original-head correctness blocker:** valid GB18030 bytes `82 33 E7 34` terminate released TruffleRuby 40.0.0
   with an internal Java `ArrayIndexOutOfBoundsException`. Base returns those bytes tagged UTF-8. The original
   fast path hands CGI the original encoding; its Ruby fallback calls `tr` before converting to binary.
   Smallest fix: give CGI the existing `str.b` copy. The revised code does this for every input, also removing
   the original type/encoding guard. The minimized repro now passes on all four locally executed runtimes.
2. **Original body/message mechanism claim:** `gsub` does not allocate one MatchData for every escape on the
   measured Ruby. An A/A allocation probe shows one for `a+b`, `a+b+c` and `a%41+b`, not one per match;
   `string.c` reuses its match object. Smallest fix: remove the per-escape MatchData claim. Done.
3. **Reach and evidence:** multipart form pairs bypass Rails' QueryParser; the initial wording covered too much.
   Current body/message say URL-encoded form fields. The original guarded overlay's request percentages are
   historical, replaced by `req-ur1b-*.txt`. The ZJIT request harness checks only compiled ISEQs and compiled
   side exits; the impact no longer calls that a full JIT-flat gate.
4. **Commit wording:** current JRuby uses Java `CGI::EscapeExt`, not its available Ruby fallback. The final
   message now says just “pure-Ruby fallback.”

## Correctness, security and exactness

Independent `probe.rb` compares the unchanged base helper against the public candidate method with separately
constructed inputs. It checks result bytes, class, encoding, validity, frozen state, instance variables,
singleton methods, identity, input mutation, conversion events, and exception class/message.

| Locally executed runtime | Differential cases | Differences |
| --- | ---: | ---: |
| Ruby 2.5.9 | 41,832 | 0 |
| Ruby 4.0.10 | 42,264 | 0 |
| TruffleRuby 40.0.0 | 41,349 | 0 |
| JRuby 10.1.3.0, Java 21 | 42,264 | 0 |
| JRuby 9.4.16.0, Java 21 | 42,264 | 1,905, including ordinary subclass results |

TruffleRuby rejected 915 encoding/byte combinations while constructing the input, equally for both calls;
these are counted separately, not as passing decoder cases. The earlier JRuby investigation also retained a
standalone StackOverflowError reproduced in both base and original head; it is not attributed to this change.

The corpus includes every registered input encoding, every `%00`–`%FF` byte, mixed literal/escaped bytes,
embedded NULs, malformed/truncated percents, deterministic random bytes, target Encoding objects/names,
invalid target names and nil, and frozen/plain/subclass inputs. Binary is important: CGI must not choose
another result encoding after finding invalid decoded bytes.

Exactness checklist:

1. **Singleton/private methods, extend/prepend and missing methods:** exercised input `b`, `encoding` and
   `instance_of?`, extended/prepended `b`, method-missing ducks and frozen intermediate strings. The revised
   code preserves the tested input-hook cases that differed on the original fast path. An intermediate
   returned by a custom `b` with its own `gsub` still differs: base invokes that hook; CGI does not. This
   requires caller-defined Ruby behavior, not request bytes. It is assessed as the same outside-contract
   custom-hook boundary, not a reason to rebuild a guarded decoder.
2. **Subclasses:** plain String subclasses, subclasses overriding `b`, and a subclass spoofing `instance_of?`
   were compared. Result normalization passes on the four initial engines, but fails on JRuby 9.4 as
   explicitly accepted and disclosed above. No Hash/Array iteration or accumulation was introduced.
3. **Conversions:** public/private encoding `to_str` and `method_missing` conversions run once with equal
   events; input ducks and invalid inputs have the same outcomes. `b` still runs after percent validation.
4. **Added/skipped calls:** no new calls on the original input; its `b` stays. The binary intermediate now
   goes through CGI instead of `gsub` and the private URI helper. CGI/private-helper overrides are not
   preserved. These are the explicitly assessed custom-code boundaries from the earlier Astra review,
   not an input-driven escaping failure. No additional guard is warranted.
5. **Ownership/results:** returned strings are fresh and mutable, not the input or an adopted caller
   accumulator. Their exact class has the accepted JRuby 9.4 difference above. Frozen input and frozen binary-copy
   cases succeed as before. Ruby 2.5 taint is retained for plain, plus and percent cases, independently executed.
6. **Mutation/fibers:** encoding-conversion mutation and suspension/resumption produce the same result and
   mutated input. There is no new user-object iteration. Eight concurrent threads and a Ractor pass on MRI.
7. **Errors/frozen state:** invalid-percent validation is unchanged and still precedes conversion. Invalid
   encodings, incompatible source encodings and malformed values were compared with exact exception
   class/message. New regression assertions cover binary input's default UTF-8 result, subclass normalization
   and the GB18030 bytes.
8. **Loading:** `require "uri"`, CGI-first, escape-first and CGI-autoload permutations work with
   `--disable-gems` on all four runtimes. This is not unchanged loading: requiring URI now eagerly defines CGI,
   loads its escape implementation, and can consume an existing CGI autoload. No failure was found in those
   permutations. No lazy-require wrapper or dependency shim is needed on the tested supported runtimes.

The final tree's URI suite passes locally on MRI: 94 tests, 3,061 assertions, no failures/errors.
TruffleRuby 40 and JRuby 10.1 each pass 94 tests, 3,039 assertions, one expected CRuby-regexp-cache omission,
no failures/errors. JRuby 9.4's targeted method test has one failure in five assertions: the accepted class
difference. The added GB18030 input passes on Ruby 2.5.9 as well. Same-tree 7da6979 CI run `46063108286`
succeeds; cecaed1 runs `46062113962` and `46062111986` also succeed. Final message-only c43954f CI run
`46065543758` has now succeeded, including every listed job; its exact head was verified. Hosted results
are not represented as additional local runs.

`large-inputs.rb` independently compares 1 MiB and 8 MiB plain, early escape, late escape, percent-dense,
plus-dense, and malformed-at-end inputs on all four runtimes. Result byte digests, lengths/classes/encodings,
and error-message digests match. This includes TruffleRuby's real Ruby fallback, not only an MRI emulation.
That large-input check uses base Strings; it does not make the accepted JRuby 9.4 subclass difference disappear.
Standalone URI-first loading and decoding also work on 9.4; its failure is not a missing `cgi/escape`.

## Maintainability and comments

The simplified implementation is the right boundary: existing validation, an existing binary copy, the
stdlib decoder, and existing final encoding. The original guard chain and dual implementation are gone.
No new abstraction, compatibility shim, rescue fallback or dispatch machinery is justified. The private helper
must remain for `decode_uri_component`, which preserves plus signs. Duplicating its one-line error check here
is less complex than adding a mode parameter or callback to it.

`common.rb` grows from 922 to 924 lines, below the rubric's 1,000-line boundary. Flog scores the changed
method at 6.4, versus 13.4 for the original guarded candidate; its base forwarding method was 1.6. The selected
RuboCop Metrics check reports the same 15 existing offenses on base/final, none added in this method.
There are no added upstream code comments. RDoc is unchanged from base and accurately retains `String#b`.
The three new assertions cover observable behavior, not allocation counts or helper-call order.

## Body, message, callers and reach

The final message's validation/copy/encoding statements match the code and the differential. The body names
the real callers, no longer promises that other input types keep an old branch, and removes the false
MatchData mechanism. Both body and message qualify the same-class claim for JRuby 9.4. The final body is short
and understandable without this review record. Arbitrary
overrides of CGI, a private URI helper, or a custom intermediate's `gsub` are separate assessed boundaries.

Fetched exact released-version files and tag resolutions; also checked each default branch:

| Project | Latest release checked | Direct caller verified | Default branch checked |
| --- | --- | --- | --- |
| Rack | 3.2.9, `52941a02842fd956e3c5532147116354a0240149` | `query_parser.rb:268`, `utils.rb:59`; cookies call Utils.unescape | `b432304e8ddc23cc98564d2a8365827b59a835bd`, still calls URI |
| Rails | 8.1.4.1, `3f290b759c8e2ffe7c257951b1255740751355e4` | `query_parser.rb:46–47`; request/param builder checked | `2e299253f942ab94041cc6f210ac9d33884c210d`, still calls URI |

Rails 8.0.0 (`dd8f7185faeca6ee968a6e9367f6d8601a83b8db`) already has the direct caller at lines 44–45.
Rails' `request.rb:442–455` distinguishes multipart pairs from URL-encoded pairs, supporting the narrowed
wording rather than “every form body.” Parameter parsing is lazy; a request need not materialize params.

At the recorded API lookup, Rack has 1,401,245,429 total downloads, 5,136 stars, a November 20 release and
November 21 push; Rails has 823,285,328 downloads, 59,158 stars, a November 4 release and November 27 push.
Neither is archived. Rack-first order follows download reach; both are relevant and current. URLs, exact
files, tag resolutions and API output are retained in the archive's `links/` directory. Ruby master relevance
is additionally demonstrated by the current benchmark records and final-head CI, not a local master run.

## Timing and counted-work evidence

Independently audited the completed a1.xxlarge run retained in `body/UR1-cecaed1-{4010,master}-time`.
The measured candidate pin is cecaed1, tree-identical to c43954f, clean on both sides; the benchmark has the
same four literal inputs, and its cookie is 248 bytes. These are the existing worker's measurements, not
new timing runs in this smaller orb.

`audit-timing.rb` reads the nine native benchmark-ips logs and all 180 wall process logs. It recomputes best
of three for each side, the two-base mean, percentage changes and A/A; every outgoing ips cell rounds
correctly. Native interpreter throughput improves 40.2979%, 232.8091%, 321.1963% and 117.6888%, with A/A
at most 3.0892%. The body shows rates, not these internal percentages.

For each wall cohort it independently reconstructs every raw round/window array, the selected per-process
thread-CPU quantile, geometric ratios/medians and all seeded 5,000-resample bootstrap intervals. All eight
changes and intervals match the record; all A/A intervals contain zero and all change intervals exclude it.
YJIT per-call time changes are −35.1098%, −72.6524%, −80.3878%, −57.3392%; pinned master ZJIT changes are
−25.0447%, −69.6246%, −78.6627%, −54.1093%. The body rounds their full range correctly to 25–80%.

Every raw process has all required unchanged counters: YJIT compiled ISEQs/blocks and invalidations; ZJIT
compiled ISEQs, failed ISEQs, compiled side exits and invalidation time. Each case has 90 JIT-flat processes,
with 30 timed windows each. This is stronger than the request harness's two-counter ZJIT check below.
Both wall cohorts use GC-off windows and the same Ruby pin within a comparison; master is
`0d399335b733776187e43a783e5f950c18ad881c`. Nothing here claims GC-on elapsed request timing.

Recomputed every Callgrind N-minus-0 cell in `body/UR1-cecaed1-{4010,master}` from its raw dumps with
`check-claims.rb`. The four original counted-work rows match the 4.0.10 interpreter record: objects 4/7/8/7 to 3/2/2/2;
instructions 4,486/13,101/15,320/18,059 to 3,553/4,973/4,548/9,283. Candidate trees are identical.
The interpreter/YJIT/master-ZJIT ranges in impact match their records. All reported changes exceed their
own A/A; master ZJIT's micro records retain the full upstream-bench gate, not the request harness's two counters.

Also independently reran the complete four-case micro through `script/upstream-bench` on Ruby 4.0.10,
interpreter and YJIT, base/head/base, fixed heap, 1,000 calls. All eight rows reduce instructions outside
their own A/A and retain the reported object counts. Own A/A is up to 1.93%; this rerun does not replace the
body's lower-noise 2,000-call cohort or silently discard that noise. Raw dumps, manifests and commands are kept.

`audit-receipts.rb` recomputes each complete new request comparison: interpreter blog PATCH −2.882%, pingcrm
PUT −1.023%, blog GET article −0.491%; YJIT blog PATCH −5.579%, GET article −0.947%; ZJIT −4.459% and −0.943%.
The JSON controls are −0.0598% interpreter and −0.0103% ZJIT. The interpreter control is outside its narrow
0.0061% A/A, not noise; its objects are unchanged. These support the literal “within 0.06%” impact wording,
not a claim of no interpreter instruction effect. The partial
YJIT pingcrm row has no complete comparison and is not claimed. Inspected `req/ur1_cgib.rb`: the overlay is the
final method body. These are whole-request instruction counts, not time; I audited receipts rather than
rerunning the Rails apps. The earlier `req-ur1-*` guarded-overlay results remain historical.

### Worst-input sweep

The independent Callgrind sweep runs absent/early/late escapes, all-percent and all-plus shapes at 12 bytes,
248 bytes, 16 KiB and 1 MiB, plus 8 MiB unescaped. It uses Ruby 4.0.10, fixed heaps, base/head/base and a zero-call
control for every cell; the archive contains the script, complete TSV and all raw dumps. Percent rows use
whole `%41` triplets, so their actual size can be one or two bytes below the requested size.

Worst relative row: **8 MiB with no escapes**, 184,555,089 / 159,388,176 / 184,555,089 instructions
(base/head/base), **13.6365% fewer instructions, exact A/A**. Long unescaped input, not dense escapes, gives
the smallest measured gain. Selected rows below use the mean of the two base measurements:

| Input | Base instructions | Head instructions | Change | A/A spread |
| --- | ---: | ---: | ---: | ---: |
| 1 MiB plain | 23,074,385 | 19,927,568 | −13.6377% | 0% |
| 1 MiB early escape | 25,281,862 | 21,344,352 | −15.5744% | 0.0023% |
| 1 MiB percent-dense, actual 1,048,575 bytes | 1,104,145,415 | 208,229,500 | −81.1411% | 0.5381% |
| 1 MiB plus-dense | 2,776,523,718 | 159,755,817 | −94.2462% | 0.7175% |
| 8 MiB plain | 184,555,089 | 159,388,176 | −13.6365% | 0% |

All 21 rows reduce instructions outside their A/A; maximum A/A spread is 1.3431%. These are not wall-time
results. The full original-head sweep is also retained, separately named, rather than silently discarded.

## Retention and limits

Raw evidence and runnable probes are in `thermos-sol-2026-11-27.tar.gz` beside this report. Runtime binaries and
fork checkouts are not bundled; their versions/pins, the patch and CGI implementations inspected are retained.
This orb performs allocation/instruction measurements and audits retained xxlarge timing; it produces no new
wall measurements. Final-head and same-tree CI passed. A review here is not authorization to open the parked
ruby/uri candidate.

Key executed commands (runtime executables are explicitly pinned in the retained outputs):

* `<ruby> -I <candidate>/lib probe.rb` on MRI 2.5.9/4.0.10, TruffleRuby 40, JRuby 10.1 and 9.4.
* `<ruby> -I <candidate>/lib large-inputs.rb`, `edge-probe.rb`, and the load-order permutations.
* MRI 4.0.10 `script/upstream-bench` for interpreter/YJIT with base/head/base; exact commands in
  `body-cecaed1/commands.sh`, pinned Valgrind manifest and raw dumps adjacent.
* `run-cecaed1-sweep.sh`: all 21 Callgrind size/shape cells, with N-minus-zero and A/A.
* `check-claims.rb`, `audit-receipts.rb`, `confirm-boundary.rb`: retained raw-log arithmetic and boundary audit.
* `audit-timing.rb body/UR1-cecaed1-{4010,master}-time`: native rates, raw windows, ratios, intervals and gates.
* `gh api` commit/tree/CI/repository/tag endpoints and `curl` of each exact caller URL in `links/urls.txt`.
