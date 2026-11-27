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
evidence: [bench/upstream/outside_leads/ur1/body/UR1-4010, docs/upstream/data/outside-leads-2026-11-27]
impact: "Every Rails request with a query string or urlencoded form body decodes each key and value through URI.decode_www_form_component (ActionDispatch::QueryParser.each_pair, Rails 8.0+ and main), and released Rack (3.2.9) decodes query and cookie components with it. Per call -9% to -66% instructions, 4-8 objects down to 1-2 (4.0.10 interpreter; YJIT -21% to -73%). Whole requests as a method overlay on Rails main 2e299253f9: interpreter -3.1% blog PATCH, -1.2% blog POST comment, -0.8% pingcrm PUT, -0.35% blog GET article and codetriage GET repo; YJIT 4.0.10 -5.7% / -1.9% / -1.0%; ZJIT master -5.2% / -0.6% (JIT-flat). Path runs on Ruby master and Rails main."
rank: 2
risky: false
state: built
pr:
ownership: {date: 2026-11-27, checked: ["open ruby/uri PRs touching lib/uri/common.rb decode/encode (none change the method; #253 and #264 only change MailTo callers of it, #269 is URI.for/parse, #274 a WHATWG parser)", "ruby/uri commits on common.rb since 2025 (none on _decode_uri_component)", "rack/rack#2557 (ours) moves Rack off this method; Rails' QueryParser still calls it"], hits: []}
note: >-
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
  body's ips table comes from it. ZJIT per-call cells on master: the first run (UR1-master-aborted) lost one process
  when the orb ran out of memory with four Valgrind batches in parallel; rerun as UR1-master.
passes: []
---

# Decode www-form components with cgi/escape

`URI.decode_www_form_component` copies the string with `b` and then runs `gsub` with a hash table, so every `+` and `%XX` builds a MatchData and looks up the hash. Rails decodes every query string and form body key and value with it ([ActionDispatch::QueryParser, Rails 8.1.4.1](https://github.com/rails/rails/blob/3f290b759c8e2ffe7c257951b1255740751355e4/actionpack/lib/action_dispatch/http/query_parser.rb#L46-L47)), and Rack decodes query strings and cookies with it ([Rack 3.2.9](https://github.com/rack/rack/blob/52941a02842fd956e3c5532147116354a0240149/lib/rack/utils.rb#L59)).

This uses `CGI.unescape` from cgi/escape, which decodes `+` and `%XX` the same way in one pass in C, for plain ASCII-compatible strings. The check for an invalid `%` still runs first, and the result is still forced to the requested encoding, also when its bytes are invalid there. String subclasses and other objects keep the current path.

| Objects and instructions per call, Ruby 4.0.10 | Before | After |
| --- | ---: | ---: |
| `"hello"` | 4 objects, 4,486 | 2 objects, 4,083 |
| `"article%5Btitle%5D"` | 7, 13,114 | 1, 5,693 |
| `"Hello+world+from+Rack"` | 8, 15,322 | 1, 5,265 |
| a 248-byte cookie value | 7, 18,056 | 1, 10,154 |
