# UR1 delta confirmation — thermos-sol, 2026-11-27

Verdict: **approve** the code, tests, comments and full commit message of
[e2d2e21](https://github.com/thomasklemm/uri/commit/e2d2e21a570516424a3a935e5ab2a67db0ac53d0), and the
non-numerical PR-body prose in the archived Lowrail snapshot. **No open finding or requested code fix.** The PR
table, its elapsed-time percentages and its final objects range still need their separate exact-head numbers
confirmation; they are not approved by this pass.

Reviewer: **thermos-sol**, thread `T-01a21efb-a6a1-71b9-bfc9-7140f4b8f209`. I applied both Thermos rubrics
myself, without delegating. I read the current root `AGENTS.md`, the requested sections of `docs/DECISIONS.md`,
the earlier UR1 reviews, Fable's improvement review and the author's rework receipts. The receipts are not
counted as my executions.

## Identity and scope

The candidate is one commit on
[48cda77031](https://github.com/ruby/uri/commit/48cda77031e343d35213c36fe164b2a46ffbefa7). I fetched the review
branch, read the full base diff and the delta from
[d09ffb7](https://github.com/thomasklemm/uri/commit/d09ffb7376d111123e5d217510c150c87c0cdd99), and ran the code
checks in a clean worktree at [d4ce0b0](https://github.com/thomasklemm/uri/commit/d4ce0b0376d0b1bbbf853c87ad0dd506ef6dc70c).
I then fetched both message amendments and verified that d4ce0b0 and e2d2e21 have the identical tree
`3621b78834d9d699a0d8266887720d8ba6ffdfc8`; `git diff --exit-code` is empty. The code evidence therefore applies
to e2d2e21. Its full message was reviewed separately after the last amendment.

Both component methods now share one load-time capability check. A native `CGI.unescapeURIComponent` selects
CGI for both methods; otherwise both retain master's `gsub`. The helper still validates before `str.b`, gives
the binary intermediate to the caller's decoder, and force-encodes only after decoding. `ASCII_8BIT` and
`BINARY` name the same Encoding object. `decode_www_form` is not a consumer of this helper and is unchanged.

Own runnable probes and raw data are in the adjacent **`thermos-sol-e2d2e21-2026-11-27.tar.gz`**. Its README
records paths, commands, controls and harness corrections. No URI change or push, upstream post, or queue edit
was made.

## Resolved message findings

* The intermediate message attributed TruffleRuby's retained subclass to `CGI.unescape`. Astra identified the
  wrong method; the author corrected it to `CGI.unescapeURIComponent`. I independently ran four direct cases
  on TruffleRuby 40: empty, plain, literal-plus and percent-escaped subclass inputs. `String#b` and
  `CGI.unescapeURIComponent` keep the subclass; `CGI.unescape` returns String. The final clause is accurate.
* I requested removal of the remaining unqualified “CGI.unescape is slower than the `gsub`” clause. Fable's
  retained results include a percent-dense counterexample and explicitly require a proper timing cohort or
  removal. The author removed the clause in e2d2e21, leaving the independently verified subclass reason. No
  new speed claim or runtime guard is needed.

These are resolved text findings, not outstanding defects. The earlier plain-form receipt correction is also
present: my new execution again gives about **19 / 28 / 19 objects**, not 24 / 29, for the plain form below.

## Correctness and security: approve

### Own executed matrix

`run-matrix.sh` runs the independent differential for each public method, the large/edge/concurrency probe,
the full candidate suite through its real `test/lib/helper.rb`, and six standalone/load-order checks. Each
differential compares bytes, result class, encoding, validity, frozen state, identity, instance variables and
singleton methods; input mutation; conversion events; and exception class/message. Error-highlight excerpts
and object addresses are normalized, not treated as an API contract.

| Engine/backend | Cases per method | Differences | Decoder for both methods | Full suite |
| --- | ---: | ---: | --- | --- |
| MRI 2.5.9, bundled CGI | 41,832 | 0 | `gsub` | 94 tests, 0 failures/errors |
| MRI 4.0.10, native CGI | 42,264 | 0 | CGI C | 94, 0/0 |
| Pinned master, interpreter | 42,264 | 0 | CGI C | 94, 0/0 |
| Same master, ZJIT | 42,264 | 0 | CGI C | 94, 0/0 |
| MRI 4.0.10, shipped Ruby CGI forced | 42,264 | 0 | `gsub` | 94, 0/0 |
| TruffleRuby 40.0.0 | 41,349 | 0 | `gsub` | 94, 0/0 |
| JRuby 10.1.3.0, Temurin 21 | 42,264 | 0 | CGI Java | 94, 0/0 |
| JRuby 9.4.16.0, Temurin 21 | 42,264 | 0 | `gsub` | 94, 0/0 |

Master is [0d399335b7](https://github.com/ruby/ruby/commit/0d399335b733776187e43a783e5f950c18ad881c), the
same locally built pin as the earlier pass. TruffleRuby refuses 915 encoding/byte combinations during input
construction on both sides; they are recorded as unconstructible, not decoder successes. Ruby 2.5 has fewer
registered encodings. The existing CRuby-regexp-cache test is omitted by the suite itself on 2.5/JRuby/Truffle;
no new skip was added. Assertions are 3,046 on 2.5, 3,070 on current MRI/master and 3,048 on JRuby/Truffle.

**The old JRuby 9.4 class difference is gone.** Both complete differentials have zero differences, the new
`assert_instance_of` assertions pass, and the direct plain/empty/plus/percent subclass checks return String.
The previous accepted exception must not be carried forward as a limitation of this head.

I also executed both differentials and the full suite with real CGI **0.3.2 and 0.3.3 on MRI 2.5.9**: zero
differences and 94 tests/3,046 assertions/zero failures or errors in both. The former selects `gsub`, the latter
the native C methods. MRI 4.0.10 with actual CGI 0.3.3 also selects C and passes both differentials. This checks
an upgraded CGI at the Ruby floor instead of inferring selection from the Ruby version.

Four further `SINGLETON_B=1` runs, both methods on MRI 4.0.10 and master with ZJIT, each compare **300,000 random
plus 142 fixed cases**: zero differences. `edge.rb` compares 30 size/shape cases per method per matrix cell,
through 8 MiB, including malformed percent at the end. It checks digests, lengths, encoding/class and errors;
private encoding conversion, Ruby 2.5 taint, eight concurrent threads and current-MRI Ractors pass too.

### Selection, loading and exactness boundaries

The native test is correct on every executed implementation. Missing methods and Ruby-defined URI decoders
select the fallback even when `CGI.unescape` itself is native. In particular JRuby 9.4's native escape module
lacks the URI method; loading all of CGI can add a Ruby URI method, which is still rejected. TruffleRuby's
actual Ruby URI decoder is rejected. Source inspection confirms the C threshold at CGI 0.3.3 and Java at
0.4.1; actual JRuby 10.1 reports a native method and takes the Java path. I do not claim execution of every
historical Java artifact or every possible CGI/runtime combination.

The six per-engine load checks cover URI-first, CGI-first, escape-first, CGI autoload, a missing native URI
decoder, and a Ruby-defined URI decoder. Both methods' selected bodies and subclass outputs are checked.
Ordinary `ruby -w` loading is clean. The new top-level require still defines CGI/loads escape earlier; that is
the already assessed loading boundary, not unchanged lazy loading.

One exploratory **MRI 4.0.10 plus old CGI 0.3.2** suite is not green: its Ractor subprocess rejects method-
redefinition warnings from mixing the old extension with Ruby 4's shipped `cgi/escape.rb`. The archive keeps
the failure, and I reproduced the same warnings by requiring CGI escape **without loading URI at all**. I did
not suppress warnings or claim that hybrid suite passed. The genuine old-CGI boundary was additionally run
on 2.5.9, where both versions' complete suites pass. This is a disclosed legacy loading limitation, not a
new decoder-output finding or evidence that all historical mixtures are clean.

All eight exactness checklist categories were applied: singleton/private/extended/prepended hooks and ducks;
String subclasses; public/private conversions and call counts; added/skipped calls; copied ownership; mutation
and suspended fibers; frozen inputs/results and exact errors; standalone/load order. The retained `b` still
runs after validation, and decoded invalid bytes are tagged rather than scrubbed/transcoded. Ordinary outputs
are fresh mutable Strings. Custom behavior on an intermediate returned by an overridden `b`, CGI overrides
and overrides of the private helper remain the explicitly assessed custom-code boundaries from the earlier
review, not request-byte-only escaping failures. No new guard or normalization is requested.

### Tests distinguish plausible wrong implementations

All **26** isolated assertion strings were checked byte-for-byte against the actual candidate test source,
then executed against base, head and **14** faulty variants. Base and head pass. Native and fallback mutations
are counted only where their branch runs; backend-inactive survivors are not described as kills.

* Existing vectors distinguish the methods' opposite literal-plus contracts.
* The new mixed-case input uniquely catches upper-case-only fallback decoding for each method.
* Binary `%FF` catches lost final encoding/tagging and CGI selecting an inappropriate result encoding.
* Empty and subclass cases catch replacing non-mutating `gsub` with `gsub!`, and the URI subclass assertion
  catches removing the native-only gate on actual TruffleRuby.
* GB18030-plus preserves the non-UTF-8 source contract and the two different plus results. The old Truffle CGI
  crash path is no longer selected by this head; I do not claim this test currently traverses that path.
* `%zz` catches broadening hex validation to word characters, together with the existing malformed cases.

The tests assert observable strings, classes and documented errors, not call counts, allocations, branch
selection or helper internals. The class check is a compatibility invariant this implementation deliberately
preserves on all executed engines, not a demand that a particular helper run. Some assertions overlap, but
that does not justify a test rewrite in this small delta.

## `decode_www_form` stays unchanged for good reasons

I reran the hypothetical replacement of only its two `gsub!` calls with permissive CGI decoding. It agrees on
the sampled values but allocates more on ordinary forms: `page=2&per=20&sort=name` gives **18.999 / 28 / 19**
objects per call in base/variant/base; the first sample's 0.001 difference is a one-time GC-stat artifact.
`a&b=&=c&&d=e` gives **31 / 46 / 31**, while the escaped `article%5Btitle%5D=Hello+world` gives **17 / 12 / 17**.
Raw windows are retained. These are objects, not time. Both permissive form decoders keep lone/bad `%` and
scrub invalid decoded text; the strict component methods reject malformed percent. Reusing the strict helper
would be a semantic regression, and permissive CGI replacement is not an unconditional allocation win.

## Maintainability, comments and message: approve

Cold read: select native or hash decoding once at load; in either case keep validation, binary copying and
final encoding in the one existing helper; let each public method choose whether plus is space. The shared
capability check removes the old asymmetry without per-call feature checks or new decoder objects.

The duplicated two-line definitions were weighed explicitly against a decoder module/constant/proc layer,
metaprogramming and per-call dispatch. None is simpler. This is the same bounded capability-definition shape
used by Ruby's shipped `ERB::Util`, not a Ruby-version policy branch or a reason to extract this cohesive file.
It is a conscious narrow use of duplicated capability definitions, not a general waiver of the L3 rule.
The helper remains the canonical owner; the delta adds no new name, rescue shim or duplicated validation.

`common.rb` grows **922 → 933 lines**, staying below 1,000. Flog total is **316.0 → 332.1**; helper **6.3 → 6.1**;
the public methods are **1.6 → 6.5** each. Flog merges each pair under the last definition, so those scores are
not separate measures of both native/fallback bodies. RuboCop Metrics has the same **15** offenses; its existing
module-length size increases **408 → 417**, and no new metric offense appears. That bounded definition/callback
cost is justified by the native work avoided, not a new responsibility or sprawling control flow.

Every added/moved comment line was checked. Public RDoc stays with the first definitions; a real RDoc parse
produces identical docs/parameters for both decoders and the moved encoder on base and candidate. The `else`
note explains the non-native compatibility case. The helper's existing description was updated to its block
contract. There is no benchmark narration or internal review material in the source.

The complete final message matches the implementation and the independently executed subclass/form probes.
“Substring” describes the match key used for the Hash lookup, not a promised per-escape Ruby heap allocation;
MRI's current `gsub` fast-map path can use a stack string view. It no longer says the Hash loop runs in Ruby
or makes an unqualified claim about excluded Ruby-decoder speed. The native availability thresholds were
checked in the retained tagged C/Java sources. No further comment or message change is needed.

## Body prose: approve; numbers still separate

The archived body snapshot names the shared helper, native C/Java decoding, both fallbacks, preserved
class/bytes/encoding and the new eager require. These agree with the executed paths. The Rack/Rails call claims
were checked by fetching the exact linked release files and tracing query/form/cookie callers. Current main
still calls the same method. Annotated release tags resolve to the exact permalinks' commits.

I independently checked current reach/currency: Rack **3.2.9**, **5,136 stars**, about **1.401 billion** downloads,
released **2026-11-20**; Rails **8.1.4.1**, **59,159 stars**, about **823 million** downloads, released **2026-11-04**.
Neither is archived; their recorded last pushes are November 21 and November 27 respectively. Rack-first is
reasonable by download reach. The prose is **146 words** with link targets/table/title excluded, within the
outer length limit; no extra qualifications are needed. The last time/objects sentence was included in the
word count but its numbers are reserved for the later confirmation, as requested.

## Performance evidence

### Own size sweep: instructions, not elapsed time

I ran **128** new base/candidate/base rows on one MRI 4.0.10 pin, half native and half with shipped Ruby CGI
forced. Each side has its own zero-call subtraction, fixed five-pool heap, warm-up outside collection and GC
off. Sizes are empty, 3, 12 and 248 bytes, 16 KiB, 1 MiB, 8 MiB and **64 MiB**, beyond the measured **54 MiB**
L3. Plain/absent, early and late escapes extend through 64 MiB; dense plus/percent shapes through 1 MiB. The
common `URI.public_send` wrapper is included on both sides. Actual percent-dense length is 3 × floor(size / 3).

The table gives the **largest observed candidate/base instruction ratio in this valid-input grid**, not a
globally worst input, elapsed-time loss, or a performance estimate for TruffleRuby/JRuby:

| Backend/method | Highest-ratio input | Base1 / candidate / base2 instructions per call | Change from base mean | A/A spread |
| --- | --- | ---: | ---: | ---: |
| Native CGI, form component | Empty | 5,192.48 / 4,864.74 / 5,144.48 | −5.8768% | 0.9287% |
| Native CGI, URI component | 1 MiB literal plus | 23,075,423 / 22,026,440 / 23,075,455 | −4.5460% | 0.000139% |
| Ruby-CGI fallback, form component | 12 plain `a` bytes | 5,711.24 / 6,058.23 / 5,711.24 | **+6.0756%** | 0% |
| Ruby-CGI fallback, URI component | Empty | 5,134.24 / 5,449.23 / 5,182.24 | **+5.6413%** | 0.9305% |

The URI fallback's 12-byte literal-plus row is close: **+5.5346%**, exact A/A. Do not overinterpret its ordering
against empty. Maximum A/A across the entire retained grid is **2.8599% native** and **1.5814% fallback**;
these spreads are disclosed, not silently replaced by favorable reruns. Every row and control is retained.

The old repeated-CGI-scan cost is absent from the form fallback. Plain 16 KiB is now **366,263 / 366,577.75 /
366,263** instructions (**+0.08594%**, exact A/A), instead of the earlier head's large pure-CGI cost. At
64 MiB plain, form-component native counts are **1,476,401,823 / 1,275,074,775 / 1,476,401,807**, **−13.63633%**,
A/A **0.00000108%**; fallback counts are **1,476,401,777 / 1,476,402,091 / 1,476,401,777**, **+0.00002127%**,
exact A/A. The fallback retains the old work plus dispatch overhead; it is not advertised as a win on all
backends. Using one native capability gate deliberately leaves old-CGI form-only acceleration unused rather
than restoring asymmetric policy or JRuby 9.4's class change.

### Pinned master × ZJIT

Own `script/upstream-bench`, same pinned build on both sides, native CGI, base/candidate/base, 1,000 calls after
3,000 warm-up calls. Instructions change **−17.8807%, −63.7302%, −72.2855%, −51.5811%** for the four form cases
(hello, key, value, cookie), and **−17.8693%, −58.0625%** for URI hello/user. Maximum A/A is **0.5817%**. All four
required counters stay unchanged in every one of the **36** measured windows; I checked the raw logs, not just
the aggregate flag. Object counts are independently kept in that record.

`audit.rb --complete` reconstructs **all 128 rows** from their raw dumps and checks every master-ZJIT window's
counts/counters. `verify-results.rb` separately validates the ten successful full-suite/differential cohorts,
all mutation controls and the combined worst-row calculations. Both pass, including after extracting the
archive. No new wall timing was run here. The coordinator's exact-head xxlarge timing and final table remain
the separately requested numbers confirmation.

## Delivery limits

This approval is for the final exact tree/message and the non-numerical body prose, within the already
assessed custom-code/loading boundaries. It does not certify all historical CGI mixtures or approve an
unreviewed timing table. The report and raw archive are the only intended Lowrail changes; the queue remains
the coordinator's responsibility.
