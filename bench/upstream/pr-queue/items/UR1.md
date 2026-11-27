---
id: UR1
repo: ruby/uri
fork: thomasklemm/uri
kind: perf
area: URI.decode_www_form_component
reviewer: hsbt
branch: thomasklemm/decode-www-form-component-cgi
head: "e2d2e21a570516424a3a935e5ab2a67db0ac53d0"
base: master
built_on: "48cda77031"
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/outside_leads/ur1/body/UR1-cecaed1-4010-time, bench/upstream/outside_leads/ur1/body/UR1-cecaed1-master-time, bench/upstream/outside_leads/ur1/body/UR1-cecaed1-4010, bench/upstream/outside_leads/ur1/body/UR1-cecaed1-master, bench/upstream/outside_leads/ur1/body/UR1-4010, docs/upstream/data/outside-leads-2026-11-27, bench/upstream/outside_leads/ur1/astra-2026-11-27.tar.gz, bench/upstream/outside_leads/ur1/astra-cecaed1-2026-11-27.tar.gz, bench/upstream/outside_leads/ur1/astra-final-7da6979-2026-11-27.tar.gz, bench/upstream/outside_leads/ur1/astra-545506a-2026-11-27.tar.gz, bench/upstream/outside_leads/ur1/astra-c43954f-2026-11-27.tar.gz, bench/upstream/outside_leads/ur1/astra-timing-body-2026-11-27.tar.gz, bench/upstream/outside_leads/ur1/thermos-sol-2026-11-27.tar.gz]
impact: "Rack (3.2.9) decodes query strings and cookies, and Rails (8.0+, main) every query parameter and URL-encoded form field key and value, through URI.decode_www_form_component. Per call (body/UR1-cecaed1-*): 4.0.10 interpreter -21% to -70% instructions, YJIT -24% to -75%; master ZJIT -20% to -73%; 4-8 objects down to 2-3. Whole requests, head method body as an overlay on Rails main 2e299253f9 (req-ur1b-*.txt): interpreter -2.9% blog PATCH, -1.0% pingcrm PUT, -0.5% blog GET article; YJIT 4.0.10 -5.6% / -1.0% blog PATCH / GET article (JIT-flat); ZJIT master -4.5% / -0.9% (no ISEQ or side exit compiled in any window; master has no invalidation_count). JSON control within 0.06%. The path runs on Ruby master and Rails main."
rank: 2
risky: true
state: draft
pr: 276
ownership: {date: 2026-11-27, checked: ["open ruby/uri PRs touching lib/uri/common.rb decode/encode (none change the method; #253 and #264 only change MailTo callers of it, #269 is URI.for/parse, #274 a WHATWG parser)", "ruby/uri commits on common.rb since 2025 (none on _decode_uri_component)", "rack/rack#2557 (ours) moves Rack off this method; Rails' QueryParser still calls it"], hits: []}
note: >-
  2026-11-27 Astra requested changes on a3b201f05b: new input hooks can mutate input after validation; additional
  singleton, duck, subclass and CGI/URI override differences reproduced. This supersedes the builder's boundary
  acceptance below. Full repros, citation audit and limits: bench/upstream/outside_leads/ur1/astra-2026-11-27.md;
  raw probes and outputs retained in the adjacent archive. No upstream action.
  2026-11-27 built on ruby/uri master 48cda77031 (fork branch pushed, no PR). ruby/uri is a ruby-org repository and
  parked in DECISIONS (Bets): Thomas decides whether this opens. ruby/uri's merges since 2026-03-16 are maintainers' own
  (hsbt, mame, olleolleolle) and Dependabot; the last outside merge was y-yagi's #209 on 2026-03-16; about 30 outside PRs
  are open, the OskarEichler batch since 2026-08-27 and czj's #268/#269 since 2026-11-10 without a merge.
  The one-copy variant (str.b then gsub!) is dropped: within the A/A on every request (req-ur1-*.txt, ur1_copy.rb).
  Exactness: bench/upstream/outside_leads/ur1/diff.rb, 300,000 random + 142 fixed cases on 4.0.10 and master
  0d399335b7: 1 difference, a BasicObject with to_str (NoMethodError either way, message names `instance_of?` instead
  of `b`). With SINGLETON_B=1 a singleton #b on the input is no longer called (accepted boundary, checklist 1).
  Checklist: 1 singleton/extend (b not called; others unchanged), 2 String subclasses keep the old path (tested),
  3 conversions: encoding argument converted once by force_encoding as before (EncDuck call count equal), str not
  converted on either path for Strings, 4 added calls on the input: instance_of?, encoding, CGI.unescape reads it;
  skipped: b, gsub, 5 results are new Strings, 6 no iteration over user objects, 7 frozen/chilled inputs untouched,
  same exceptions and messages for invalid %-encoding and bad encoding names, 8 cgi/escape is required by
  common.rb (default gem in every Ruby uri supports: 2.5+; JRuby/TruffleRuby ship a Ruby fallback that decodes the
  same way, CI green on both). Tests: two assertions (BINARY input decoded to UTF-8 by default; subclass input returns
  a String); each fails on its mutant (CGI.unescape(str, enc); String === str). Suite 94 tests green on 4.0.10 and
  master; fork CI run 46058985448 green on 2.5-4.0, head, JRuby, TruffleRuby, ubuntu and macOS.
  Timing (benchmark-ips, wall cohort) delegated to an a1.xxlarge orb (T-01a21e8f-2651-73ed-9ab5-9406bb545fe2); the
  body's ips table comes from it.
  2026-11-27 (after Astra changes on a3b201f05b): every demonstrated difference needs Ruby code hooked onto the
  input or onto CGI/URI: a singleton or private `encoding`, `b`, `instance_of?` or `tr` on the input String
  (`tr` only in the pure-Ruby fallback), a subclass that spoofs `instance_of?(String)`, a BasicObject with
  `to_str` and `b`, a prepend on `CGI.unescape` or on the private `URI._decode_uri_component`. For ordinary values,
  47,653 cases per backend showed no difference. Decision (coordinator, DECISIONS Guards in the target repository's idiom):
  accepted as boundaries outside the contract, no new guard. Request bytes cannot reach any of them; the
  method documents decoding a String; cgi/escape's own C functions and rack#2557 (approved by its maintainer) skip
  the same input methods; guarding against hooked `encoding` or `instance_of?` would take more calls on the
  input, not fewer. Not named in the body, since users can't hit them through any caller. Body: Rack before Rails by
  reach (1.40B vs 823M downloads), with Rack::QueryParser's own call (query_parser.rb:268) linked. Astra confirm
  requested on the decision and body; code head unchanged.
  2026-11-27 (Astra confirm: changes, text only): the RDoc of decode_www_form_component no longer says the string
  is converted with String#b ("The bytes of the given string are decoded (as below), and the result is
  force-encoded to the given encoding +enc+."); commit amended to 33c17e6 (same message, code identical), fork
  branch moved with a lease from a3b201f05b. Suite 94 tests green on 4.0.10. Body: one sentence that singleton
  methods on a plain string, such as its own `b`, are no longer called. Measurements on a3b201f05b apply (comment-only change).
  2026-11-27 (thermos-sol, interim, on a3b201f05b): released TruffleRuby 40.0.0 crashes (internal
  ArrayIndexOutOfBoundsException) on valid GB18030 input, because CGI's pure-Ruby unescape runs `tr` in the caller's
  encoding before `b`; also, `gsub` reuses one MatchData, so the commit's per-escape MatchData claim was false.
  Rebuilt as cecaed1: the method keeps the lone-% check and `str.b` and replaces only the gsub,
  `CGI.unescape(str.b, Encoding::BINARY).force_encoding(enc)`, no guard; RDoc unchanged from base (String#b stays
  true), so 33c17e6's doc edit is dropped; commit message rewritten; test adds a GB18030 string decoding to its
  bytes. This also removes Astra's hook boundaries on `b`, `encoding` and `instance_of?`: diff.rb 300,000 + 142
  cases, 0 differences on 4.0.10 and master, also with SINGLETON_B=1; 100,000 on 3.4.12 with pure_cgi.rb: 0. Suite
  94 tests green on 4.0.10, master, 3.4.12 and 3.4.12 with the pure-Ruby CGI. Remaining boundary: a prepend on
  `CGI.unescape` now sees these calls. Fork branch moved with a lease from 33c17e6. Body numbers rerun as
  body/UR1-cecaed1-{4010,master}, requests as req-ur1b-*.txt (req/ur1_cgib.rb).
  2026-11-27 (thermos-sol interim on cecaed1: zero differences on Ruby 2.5.9, 4.0.10, TruffleRuby 40.0.0 and JRuby
  10.1.3.0; text only): commit message says "pure-Ruby fallback" (JRuby uses CGI::EscapeExt in Java) and
  "URL-encoded form fields"; amended to 7da6979 with the same tree as cecaed1, fork branch moved with a lease.
  Body says query parameters and URL-encoded form fields (Rails sends multipart pairs around QueryParser). Body
  table and impact from cecaed1's runs (body/UR1-cecaed1-4010, A/A <= 0.33%; master A/A <= 0.62%, ZJIT JIT-flat by
  upstream-bench's gate) and req-ur1b-*.txt; the earlier req-ur1-*.txt receipts price the guarded a3b201f05b
  overlay and are historical. req.rb's ZJIT check reads compiled ISEQs and side exits only.
  2026-11-27 (thermos-sol on 7da6979: changes): on JRuby 9.4.16.0 (current 9.4 maintenance release, 11-23) String#b
  keeps a subclass and CGI's no-escape branch dups it, so a subclass with nothing to decode returned the subclass
  (1,905 of 42,264 cases); `gsub` had normalized it. Fix as the reviewer tested it: `CGI.unescape(str.b.to_s,
  Encoding::BINARY)`, no new guard and no allocation for a String. Head 545506a (commit message adds one paragraph
  on it), fork branch moved with a lease from 7da6979. diff.rb with SINGLETON_B=1: 0 differences on 4.0.10 and master
  (300k), 3.4.12 pure CGI (100k); suite 94 green on 4.0.10. Not run here: JRuby 9.4 (reviewer's probe). Per-call
  rerun on the exact tree: body/UR1-052cf07-{4010,master} (052cf07 = 545506a's tree). Astra's approval on 7da6979
  predates this change. Reviewer's worst size-sweep row: 8 MiB plain, -13.6% instructions.
  2026-11-27 (Astra confirm on 545506a: changes): `.to_s` does not normalize ActiveSupport::SafeBuffer (its to_s
  returns self) on JRuby 9.4.16.0, and on that runtime a subclass overriding to_s could newly change the bytes or
  raise. Decision (coordinator): back to 7da6979 (cecaed1's tree), fork branch moved back with a lease from 545506a;
  the 052cf07 benchmark runs were stopped and deleted. Every variant differs only on JRuby 9.4 and only for String
  subclass inputs with nothing to decode: JRuby 9.4's String#b keeps the subclass, unlike MRI's since 2.x (the
  Ruby 3.0 String-subclass change JRuby 9.4 claims), and CGI's no-escape branch dups it. The bytes and encoding
  stay the same, and an html-unsafe SafeBuffer stays unsafe (Astra: html_safe? nil, ERB still escapes). JRuby 9.4
  is not in ruby/uri's CI ("jruby" is 10.x). Request input reaches the method as plain Strings from Rack and
  Rails. `String.new(str, encoding: BINARY)` would fix the class but changes the exceptions for nil, Symbols and
  Integers and skips `b`. So: accepted, one sentence in the body. Both reviewers are asked for a confirm on
  7da6979 with this sentence.
  2026-11-27 (Astra confirm on 7da6979: boundary and body accepted; commit text only): the commit message now says
  the result has the same bytes and encoding, and the same class except on JRuby 9.4. Amended to c43954f, same
  tree as cecaed1 and 7da6979, and the fork branch moved with a lease.
  2026-11-27 timing (a1.xxlarge, T-01a21e8f-2651-73ed-9ab5-9406bb545fe2, Lowrail 23a938b5) on cecaed1's tree:
  interpreter ips +40% / +233% / +321% / +118% (A/A <= 3.1%); YJIT wall -35.1% / -72.7% / -80.4% / -57.3%; ZJIT
  master wall -25.0% / -69.6% / -78.7% / -54.1%. Every A/A interval contains 0, and the runs
  are JIT-flat in 90 processes per cell. On a3b201f05b, YJIT cookie failed its A/A (no claim, recorded). Body now
  leads with the ips table; the JIT sentence covers the 25-80% range of both wall cohorts; the instruction table
  stays in the record.
  2026-11-27 final: thermos-sol and Astra both approve c43954f with the timing-led body (5bfaa607), no open
  findings. Accepted boundaries: JRuby 9.4 subclass class (disclosed in body and commit; the subclass assertion fails
  there, and ruby/uri's CI runs JRuby 10), prepends on CGI.unescape or the private URI._decode_uri_component, a
  frozen singleton CGI result, and cgi/escape loading when uri loads (CGI defined earlier). Worst size-sweep row: 8 MiB
  unescaped, -13.6% instructions. Fork CI green on the exact head. Not opened: ruby/uri is a ruby-org repository
  and parked (DECISIONS, Bets); Thomas decides whether to open it. ZJIT per-call cells on master: the first run (UR1-master-aborted) stopped when one
  ZJIT process wrote an empty log (cause not established; four Valgrind batches ran beside it); rerun as UR1-master.
passes:
  - reviewer: astra
    head: "a3b201f05b2efd737af193bc45ebd0534b3b6a5c"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: changes
    open: >-
      Demonstrated on Ruby 4.0.9 with native CGI and the shipped pure-Ruby fallback: an input singleton encoding
      that replaces the input with %zz runs after validation only on head (base returns aA b unchanged; head returns
      %zz and mutates input). Singleton/private b errors are skipped; singleton/private encoding and instance_of?
      errors are newly raised. Extended/prepended b and a frozen result from b are ignored. A String subclass
      spoofing instance_of?(String) bypasses its b; BasicObject with to_str and b succeeds on base but raises on head.
      CGI unescape prepend changes only head's result; a frozen singleton CGI result raises FrozenError only on head;
      a private URI _decode_uri_component prepend is bypassed. Fallback also newly invokes singleton/private tr.
      These are Ruby-hook boundaries, not a demonstrated request-bytes-only exploit; resolve them before approval
      under the escaping exception to normal boundary allowances. Independent 47,653 value cases per backend have
      no differences; native/fallback suites, threads, Ractors, encoding ducks, fibers and load orders pass.
      Rails 8.1.4.1 and Rack 3.2.9 are current, their cited SHAs/lines verified, and main still calls this method.
      Put Rack before Rails by reach (1.401B versus 823M total gem downloads; 5,136 versus 59,158 stars);
      Rack query_parser.rb:268 is the direct query caller in addition to the cited utils.rb:59.
      Body counts checked against retained raw logs/A/A, not remeasured. Details and limitations in
      bench/upstream/outside_leads/ur1/astra-2026-11-27.md. No new benchmark or Ruby master/ZJIT/JRuby/TruffleRuby run.
  - reviewer: astra
    head: "a3b201f05b2efd737af193bc45ebd0534b3b6a5c"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: changes
    open: >-
      Short confirm of Lowrail 7214d649; fork head and local reviewed checkout still match a3b201f05b.
      Rack-first order and the added query_parser.rb:268 permalink pass (fetched the exact file again).
      No new guard requested: the hook-only differences do not demonstrate a request-bytes-only failure, and
      the prior native/fallback evidence still applies. The escaping exception removes the automatic exemption
      for core/private overrides; the explicit, evidence-based boundary assessment is appropriate instead.
      Two text issues remain. The guard rule also requires one body sentence for an accepted outside-contract
      difference. The note's claim that users cannot hit these through any caller is too broad: direct public
      calls with hooked Strings are the retained repros. Replace the body's blanket statement that subclasses
      and other objects keep the current path with a scoped statement that custom String hooks are not preserved
      on the optimized path and ordinary subclasses retain the Ruby path; no private-helper detail is needed.
      Also update lib/uri/common.rb:404-405: its public documentation still explicitly says conversion uses
      String#b, which the native fast path skips. Describe decoding bytes and tagging the result instead.
      Existing guards protect invalid-percent errors, ordinary subclass result class, and ASCII compatibility;
      no additional defensive machinery is justified by this confirm. No new runtime or performance runs.
      Reviewed body SHA256 including title and boundary whitespace:
      eb6acef7c20379247214908e6b6c861512b30a731cc6edadee39ca460fab680c.
  - reviewer: astra
    head: "cecaed123f04e1704bccf4b1b3272c0b12e759c7"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: changes
    open: >-
      Code rerun passes; only the replacement body and measurements are pending. This verdict does not request
      a code fix or another guard. The item at Lowrail cad5d6b3 still describes the superseded implementation;
      final text/numbers need confirmation before this pass can approve the complete candidate.
      Reran all original hook/value/concurrency probes on Ruby 4.0.9, native CGI and its shipped Ruby fallback.
      All input-hook cases now match base, including encoding mutation, private methods, extended/prepended b,
      frozen b results, subclass type spoofing and BasicObject; the retained str.b makes the base RDoc accurate.
      Three original differences remain, not two: CGI prepend changes head's result, frozen singleton CGI result
      raises FrozenError on head, and private URI _decode_uri_component prepend is bypassed on head.
      These are the explicitly assessed CGI/private-URI override boundaries, not request-bytes-only failures;
      no added guard is warranted. Public URI wrapping, threads, Ractors, fibers and reload pass.
      Each backend has zero differences in 47,653 independent value cases and in builder diff.rb with
      SINGLETON_B=1 (300,000 random plus 142 fixed). URI suite on each is 94 tests, 3,061 assertions, zero
      failures/errors, including the new GB18030 assertion. Actual TruffleRuby 40 was not run here; MRI fallback
      success does not reproduce that runtime-specific failure. No fresh benchmarks/master/ZJIT runs.
      Full results in bench/upstream/outside_leads/ur1/astra-2026-11-27.md; raw reruns and sources in
      bench/upstream/outside_leads/ur1/astra-cecaed1-2026-11-27.tar.gz.
  - reviewer: astra
    head: "7da6979b27b2aba69c4076d8f01939e5a8c0f1f6"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: approve
    open: >-
      None. Final body confirm at Lowrail bd73cb73; UR1 body unchanged since 4d8669b6. Parsed outgoing body
      SHA256 21c8b7f7a9adbb754d0023fb96471c43959418a5c703b77df4f421ec77cdb83f.
      Verified 7da6979 and tested cecaed1 have identical tree b4d512787702911904b7ec8d51b0ec07744ec7c9 and parent
      48cda77031e343d35213c36fe164b2a46ffbefa7. Only commit-message wording changed: pure-Ruby fallback and
      URL-encoded form fields are accurate; prior code probes and suite evidence apply without rerunning.
      The body now describes the retained b copy, drops the false per-escape MatchData claim and obsolete
      input-hook boundary, and limits form claims to URL-encoded fields. Remaining CGI/private-URI override
      boundaries retain the explicit assessment from the preceding code pass; no new guard requested.
      Independently recalculated all four body rows from raw object logs and Callgrind N-minus-zero totals,
      plus A/A averages/spreads and rounding. Also checked all 16 micro cells across the two pins and unchanged
      counters in all 48 measured YJIT/ZJIT windows. Every body number matches, including the 248-byte cookie.
      Live-rechecked Rails 8.1.4.1 and Rack 3.2.9 currency/reach and all three exact caller permalinks;
      Rack-first order remains appropriate. Added current measurement directories to evidence, retaining old runs.
      This was a text/evidence confirm, not a fresh benchmark or new engine run. Checker, output, exact body,
      commit/tree receipts and citation snapshot: bench/upstream/outside_leads/ur1/astra-final-7da6979-2026-11-27.tar.gz.
  - reviewer: astra
    head: "545506abb5d4e12b5d148c3dd5e3814762120d2d"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: changes
    open: >-
      Actual JRuby 9.4.16.0 plus ActiveSupport 7.2.4: decoding SafeBuffer.new('hello') or an empty SafeBuffer
      returns String on master 48cda77031 but ActiveSupport::SafeBuffer on head. SafeBuffer#to_s returns self,
      so str.b.to_s does not guarantee normalization. Escaped SafeBuffers return String on both. This is a
      real-library subclass case, not merely a hypothetical override; the body's same-class claim is false.
      Synthetic identity-to_s subclasses also keep their class; replacing or raising to_s hooks newly change
      bytes or raise. The tested script-tag SafeBuffer has html_safe? nil on head and ERB still escapes it:
      no XSS or request-bytes-only exploit demonstrated. Ordinary subclasses are fixed by this head.
      A targeted JRuby check shows b.to_str returns String for SafeBuffer and CGI returns String thereafter;
      that alternative has not received a full differential or measurement pass here. No guard requested.
      MRI 4.0.9 native and shipped pure CGI each have zero differences in 47,653 values and 34 original object
      cases; both full URI suites pass 94 tests and 3,061 assertions. MRI custom-to_s subclass cases also match.
      Prior CGI/private-URI boundary assessment stands. No new benchmark, master/ZJIT or TruffleRuby run.
      At Lowrail 72be858b, revised exact-tree body data had not arrived; old cecaed1 numbers are not approved
      for this head. Existing same-day citation audit remains applicable to the unchanged links/order.
      Repros, base/head output, suites and reviewed snapshot: bench/upstream/outside_leads/ur1/astra-545506a-2026-11-27.tar.gz.
  - reviewer: astra
    head: "c43954fa4d2a7605e18ecc8968c1aa188eae549a"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: approve
    open: >-
      None. Confirmed the remote head, matching tree b4d512787702911904b7ec8d51b0ec07744ec7c9 and parent for
      c43954f, 7da6979 and tested/measured cecaed1. The added JRuby 9.4 exception in the body and qualified
      commit message accurately disclose the accepted subclass identity boundary. No new guard requested.
      Actual JRuby 9.4.16.0 probes on this tree give 24 differences in 40 synthetic subclass cases, all return
      class only for unescaped subclasses; bytes, encoding and frozen status match. The removed to_s hook
      no longer changes bytes or raises. Reran ActiveSupport 7.2.4 SafeBuffer cases on the restored tree:
      empty/plain inputs return SafeBuffer; percent/plus inputs return String. The script-tag case still has
      html_safe? nil and ERB escapes it. No XSS or request-bytes-only exploit demonstrated; this explicit
      boundary decision is accepted, alongside the earlier CGI/private-URI boundary assessment.
      Rechecked all four body rows and all 16 micro cells from retained raw data/A/A and the 48 JIT windows;
      all match. Prior native/pure differential, suites, concurrency and unchanged caller citation audit
      apply to this identical tree. This confirm adds no new performance, master/ZJIT or TruffleRuby run.
      Outgoing body SHA256 27c9301a17648b0a7f954db85187d9a505e2c0b904a05e92bf8df07cee469566 at Lowrail 4f0a4011.
      Sources, outputs, body and commit/tree receipts: bench/upstream/outside_leads/ur1/astra-c43954f-2026-11-27.tar.gz.
  - reviewer: astra
    head: "c43954fa4d2a7605e18ecc8968c1aa188eae549a"
    orb: T-01a21e96-8207-76d7-8f64-404eb741d298
    date: 2026-11-27
    verdict: approve
    open: >-
      None. Body-only confirm of 5bfaa607, unchanged at Lowrail 25ef284a; remote head remains c43954f.
      Outgoing body SHA256 ee24e4611e2772bb5aa0eb84e1ca3036f47ba38279226270851a5f72e30be738.
      All eight benchmark-ips cells match raw best-of-three logs in UR1-cecaed1-4010-time, averaging the two
      base maxima; A/A is 0.15%-3.09%, below each claimed gain. Recomputed the eight YJIT/ZJIT 30-round point
      estimates from raw samples in UR1-cecaed1-{4010,master}-time; reductions span 25.045%-80.388%, correctly
      rounded to 25%-80%. Raw samples match stored rounds, all stored A/A intervals include zero and change
      intervals exclude zero; all 720 case/process JIT counter reports are flat. These cohorts use thread CPU
      time with GC off, as the tool documents; the body says time per call, not request latency or GC-on time.
      Raw object logs confirm 4/7/8/7 to 3/2/2/2 for the four inputs. Each comparison uses one Ruby pin and
      measured cecaed1's tree is identical to the approved head. Code, exception sentence, caller links and
      order are unchanged; no new runtime tests or measurements were run. Checker, output and exact body:
      bench/upstream/outside_leads/ur1/astra-timing-body-2026-11-27.tar.gz.
  - reviewer: thermos-sol
    head: "c43954fa4d2a7605e18ecc8968c1aa188eae549a"
    orb: T-01a21e96-739d-740a-b7cb-15145f86d1a8
    date: 2026-11-27
    verdict: approve
    open: >-
      None. Detailed correctness/security, maintainability, body, comments, commit and eight-item exactness
      pass; both rubrics applied by this reviewer as requested, without delegation. Verified c43954f is one
      commit on 48cda77031 and tree-identical to tested/measured cecaed1/7da6979. Final body at Lowrail 5bfaa607
      and corrected message accurately disclose the accepted JRuby 9.4 subclass-class boundary; no new guard
      or normalization requested. Own differential: MRI 2.5.9 41,832/0 differences, MRI 4.0.10 42,264/0,
      TruffleRuby 40 41,349/0 (915 inputs unconstructible), JRuby 10.1.3.0 42,264/0, JRuby 9.4.16.0 42,264/1,905.
      Independently checked all 1,905 differences are class only; not claimed exact or a passing 9.4 suite
      (the new subclass assertion fails there). Original TruffleRuby GB18030 crash fixed by retained str.b.
      Standalone require and load-order permutations pass on four primary engines; 9.4 URI-first works too.
      Loading is observably earlier: URI defines CGI/loads escape and may consume CGI autoload. Custom
      intermediate and CGI/private-URI override differences are explicitly assessed boundaries, not byte exploits.
      Reran interpreter/YJIT micros and a 21-row size sweep with A/A. Worst: 8 MiB unescaped,
      184,555,089 / 159,388,176 / 184,555,089 instructions, -13.6365%, exact A/A; dense plus/percent improve more.
      Raw-log audit independently recomputes all body/impact counts, nine native ips logs and both 30-round
      wall cohorts (180 process logs), including seeded bootstrap intervals and required JIT counters.
      Native rates match all four cells; all eight wall A/A intervals contain zero, changes exclude zero,
      each case JIT-flat in 90 processes. The final 25-80% sentence and object range match; timing gate cleared.
      Exact Rack/Rails release permalinks, main callers, relevance/currency/reach checked; Rack-first justified.
      No added comments or structural regression. Report: bench/upstream/outside_leads/ur1/thermos-sol-2026-11-27.md;
      probes and raw measurements in adjacent archive. No upstream action.
---

# Decode URI components with cgi/escape

`URI.decode_www_form_component` and `URI.decode_uri_component` copy the string with `b` and then run `gsub` with a regexp and a Hash, which costs a match, a substring and a Hash lookup for every `+` and `%XX`. Rack decodes query strings and cookies with `decode_www_form_component` ([Rack::QueryParser](https://github.com/rack/rack/blob/52941a02842fd956e3c5532147116354a0240149/lib/rack/query_parser.rb#L268) and [Rack::Utils.unescape](https://github.com/rack/rack/blob/52941a02842fd956e3c5532147116354a0240149/lib/rack/utils.rb#L59) in Rack 3.2.9), and Rails decodes query parameters and URL-encoded form fields with it ([ActionDispatch::QueryParser, Rails 8.1.4.1](https://github.com/rails/rails/blob/3f290b759c8e2ffe7c257951b1255740751355e4/actionpack/lib/action_dispatch/http/query_parser.rb#L46-L47)).

The shared helper now yields the checked copy to `CGI.unescape` or `CGI.unescapeURIComponent`, which decode in one pass in C (in Java on JRuby). Results have the same class, bytes and encoding as before. Where cgi/escape has no native `unescapeURIComponent` (cgi before 0.3.3, TruffleRuby), both methods keep the `gsub`. uri now requires cgi/escape, which every supported Ruby ships.

| benchmark-ips, Ruby 4.0.10 | Before | After |
| --- | ---: | ---: |
| `decode_www_form_component("hello")` | 2.68M i/s | 3.50M i/s |
| `decode_www_form_component("article%5Btitle%5D")` | 869.5k i/s | 2.54M i/s |
| `decode_www_form_component("Hello+world+from+Rack")` | 720.2k i/s | 2.82M i/s |
| `decode_www_form_component` on a 248-byte cookie value | 489.0k i/s | 1.06M i/s |
| `decode_uri_component("hello")` | 2.73M i/s | 3.39M i/s |
| `decode_uri_component("user%40example.com")` | 1.13M i/s | 2.82M i/s |

With YJIT, and with ZJIT on Ruby master, time per call drops by 23% to 80%. Each call allocates 2 or 3 objects instead of 4 to 8.
