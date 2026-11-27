---
id: UR1
repo: ruby/uri
fork: thomasklemm/uri
kind: perf
area: URI.decode_www_form_component
reviewer: hsbt
branch: thomasklemm/decode-www-form-component-cgi
head: "a3b201f05b2efd737af193bc45ebd0534b3b6a5c"
base: master
built_on: "48cda77031"
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/outside_leads/ur1/body/UR1-4010, docs/upstream/data/outside-leads-2026-11-27, bench/upstream/outside_leads/ur1/astra-2026-11-27.tar.gz]
impact: "Every Rails request with a query string or urlencoded form body decodes each key and value through URI.decode_www_form_component (ActionDispatch::QueryParser.each_pair, Rails 8.0+ and main), and released Rack (3.2.9) decodes query and cookie components with it. Per call -9% to -66% instructions, 4-8 objects down to 1-2 (4.0.10 interpreter; YJIT -21% to -73%). Whole requests as a method overlay on Rails main 2e299253f9: interpreter -3.1% blog PATCH, -1.2% blog POST comment, -0.8% pingcrm PUT, -0.35% blog GET article and codetriage GET repo; YJIT 4.0.10 -5.7% / -1.9% / -1.0%; ZJIT master -5.2% / -0.6% (JIT-flat). Path runs on Ruby master and Rails main."
rank: 2
risky: true
state: built
pr:
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
  requested on the decision and body; code head unchanged. ZJIT per-call cells on master: the first run (UR1-master-aborted) stopped when one
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
---

# Decode www-form components with cgi/escape

`URI.decode_www_form_component` copies the string with `b` and then runs `gsub` with a hash table, so every `+` and `%XX` builds a MatchData and looks up the hash. Rack decodes query strings and cookies with it ([Rack::QueryParser](https://github.com/rack/rack/blob/52941a02842fd956e3c5532147116354a0240149/lib/rack/query_parser.rb#L268) and [Rack::Utils.unescape](https://github.com/rack/rack/blob/52941a02842fd956e3c5532147116354a0240149/lib/rack/utils.rb#L59) in Rack 3.2.9), and Rails decodes every query string and form body key and value with it ([ActionDispatch::QueryParser, Rails 8.1.4.1](https://github.com/rails/rails/blob/3f290b759c8e2ffe7c257951b1255740751355e4/actionpack/lib/action_dispatch/http/query_parser.rb#L46-L47)).

This uses `CGI.unescape` from cgi/escape, which decodes `+` and `%XX` the same way in one pass in C, for plain ASCII-compatible strings. The check for an invalid `%` still runs first, and the result is still forced to the requested encoding, also when its bytes are invalid there. String subclasses and other objects keep the current path.

| Objects and instructions per call, Ruby 4.0.10 | Before | After |
| --- | ---: | ---: |
| `"hello"` | 4 objects, 4,486 | 2 objects, 4,083 |
| `"article%5Btitle%5D"` | 7, 13,114 | 1, 5,693 |
| `"Hello+world+from+Rack"` | 8, 15,322 | 1, 5,265 |
| a 248-byte cookie value | 7, 18,056 | 1, 10,154 |
