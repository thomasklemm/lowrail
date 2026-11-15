---
id: UA1
repo: gshutler/useragent
fork: thomasklemm/useragent
kind: perf
area: UserAgent.parse and Version, under Rails' allow_browser
reviewer: gshutler
branch: thomasklemm/faster-parse
head: "3a0896a4d428d126d423fbf154354be92830c0e8"
base: master
built_on: "680915a"
depends_on: []
stacked_on:
alternative_of: AB1
impact: "allow_browser's check about 1.4x faster under YJIT (1.36-1.44x over 21 real user agents, best of 5, A/A +6.0%; reviews 1.37x and 1.44x; ZJIT master 1.42x), -30.6% YJIT / -27.8% interpreter Callgrind instructions per check, -34 of 183 objects; about 0.9% of a Blog request, 0.4% Campfire, 0.15% Fizzy"
rank: 1
risky: false
state: held
pr:
note: "Not pushed, no fork: about 1.4x is below the 2x bar for a gem whose only merger (gshutler) has merged nothing since 2024-12 and left nine 2026 PRs (#73-#81) unanswered. Patches: bench/upstream/ua1/patches/ (git am on 680915a). Send after gshutler answers #73 or any new commit or release lands; rerun the body's ips lines with a tight A/A first. Record: docs/upstream/useragent.md."
passes:
  - {reviewer: claude-code, head: "9332878ba5a181d9f38de3034e62c3dc7802b922", orb: T-01a1df56-3d92-727d-b974-39933e08ee00, date: 2026-11-15, verdict: changes, open: "All text, code exact for every input through UserAgent.parse or Rails; holding is right. Must-fix: (1) record four non-parse boundaries as accepted (commit 3: foreign elements after the application no longer raise; commit 4: Version subclass whose to_a returns an Enumerator/Set/to_ary raises, nil gives NoMethodError not TypeError; commit 2: name's to_s called once; commit 1: String subclass overriding scan/split/=~) and body 'without changing the result for any user agent'; (2) body 'The largest part was Version.new' (42%, not most); (3) commit 1 'three to six' products (Firefox has 3); (4) 1.44x is against the slower main run (1.36x against A/A run; own rerun 1.37x, A/A +1.7%): say about 1.4x (1.36-1.44x), rerun body ips with a tight A/A before opening; (5) mutant counts 3,979 and 222 of 20,621, not 594/85 of 3,103. Optional: commit 1 app-share wording, name the 21 UAs in commits 2-4, ten PRs opened in 2026, body script reads user_agents.txt, JRuby not run. Evidence: git am on 680915a = 9332878, Thomas/Thomas, no trailers; corpus 20,380 (md5 335427a9); probe main/branch/A/A 20,621 lines md5 d6c196bc each; specs 1,321/0 with -w both, no warnings; mutants 3/2/1/3979/222/638 of 20,621; Callgrind 4.0.9 check interp 287,342 A/A +0.05% -> 208,044 (-27.6%), YJIT 223,335 A/A +0.06% -> 155,544 (-30.35%), parse -27.1%/-29.3%, objects 182.7->148.8, 126.1->114.0, 0 blocks; ips YJIT core 1 best of 5 check 505.82 -> 367.92 us (1.37x, A/A +1.7%), parse 1.32x (A/A -2.3%), request 1.22x (A/A -0.6%); all record/commit numbers match raw; body 138 words, no footer/link/internal, script runs; maintainer facts checked (25 merges by gshutler, last 2024-12-04; #72-#81 no maintainer comment; owners qrush, gshutler)."}
  - {reviewer: opus, head: "9332878ba5a181d9f38de3034e62c3dc7802b922", orb: T-01a1df56-4eb5-73ac-af77-2d09288a5c81, date: 2026-11-15, verdict: changes, open: "All text, no problem in the patch code; exact for every input through UserAgent.parse or Rails; holding is right. Must-fix: (1) checklist paragraph misses four boundaries (String subclass/singleton on the version string: split vs scan, =~ count; Version subclass with Enumerator to_a or own !=; foreign elements after the application: main raises, branch returns; respond_to? with a non-String/Symbol name: to_s once), list them as accepted; (2) mutant counts 3,979 and 222 of 20,621, keep mutants output in data/ua1; (3) commit 1 'three to six' (new head, update record and item); (4) body 'The largest part was Version.new'; (5) 'ten PRs opened in 2026' / 'nine open'. Optional: AppleCoreMedia#application has the same reject.first, add to commit 3; commit 1's Ruby 2.3 wording vs CI's 2.2 and JRuby 9.4 (not run); body names the 21 UAs; second trigger: any new commit or release. Evidence: git am = 9332878, Thomas/Thomas, no trailers, 5 files +17 -11; corpus 20,380 md5 335427a9; probe 20,621 lines md5 d6c196bc on main/branch/A/A, empty stderr; own edge probe (UTF-16/32, Shift_JIS, EUC-JP, non-ASCII digits, frozen, CR/LF/NUL, 400-digit and 40-part versions, frozen parsed objects, invalid UTF-8 respond_to?, odd minimums): only the four boundaries differ; specs 1,321/0, no warnings, both; mutants 3/2/1/3979/222/638; Callgrind check interp 287,256 A/A +0.05% -> 207,848 (-27.6%), YJIT 223,367 A/A -0.03% -> 155,463 (-30.4%), parse -27.1%/-29.4%, objects 182.7->148.8; ips YJIT core 1 best of 5 check 472.51 -> 327.56 us (1.44x, A/A +2.5%), parse 1.41x (A/A +4.5%), request 1.21x (A/A +2.4%); every commit/body/record number matches raw except the mutant counts. ZJIT not rerun."}
---

# Parse user agents with fewer regexp matches and allocations

Rails 8 generates an `ApplicationController` with `allow_browser versions: :modern`, which runs `UserAgent.parse` on
every request with a user agent. While profiling a few Rails apps, that check came to 0.5 to 3 percent of a request.
The largest part was `Version.new`, which ran two or three regexp matches, a scan and one more match per part for
every product in the string.

These commits make it cheaper without changing the result for any user agent. A version made only of digits and dots
takes one anchored match and a split, `detect_product` downcases the wanted name once, `application` uses `detect`
instead of `reject { ... }.first`, and `Version#<=>` compares in a loop instead of zipping arrays. Each commit message
says why.

Parsing 21 current browser, bot and in-app user agents (one per line in `user_agents.txt`), and running Rails'
`allow_browser` check on each of them:

```ruby
require "action_controller"
require "benchmark/ips"
require "useragent"

Request = Struct.new(:user_agent)
user_agents = File.readlines("user_agents.txt", chomp: true)
requests = user_agents.map { |user_agent| Request.new(user_agent) }

Benchmark.ips do |x|
  x.report("parse x21") { user_agents.each { |user_agent| UserAgent.parse(user_agent) } }
  x.report("check x21") { requests.each { |request| ActionController::AllowBrowser::BrowserBlocker.new(request, versions: :modern).blocked? } }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before:  parse x21      1.678k (± 7.9%) i/s  (595.93 μs/i) -      8.528k in   5.082086s
after:   parse x21      2.369k (± 8.2%) i/s  (422.08 μs/i) -     11.990k in   5.060724s
before:  check x21      1.158k (± 7.9%) i/s  (863.67 μs/i) -      5.829k in   5.034353s
after:   check x21      1.669k (± 8.2%) i/s  (599.06 μs/i) -      8.350k in   5.002191s
```
