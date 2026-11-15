---
id: UA1
repo: gshutler/useragent
fork: thomasklemm/useragent
kind: perf
area: UserAgent.parse and Version, under Rails' allow_browser
reviewer: gshutler
branch: thomasklemm/faster-parse
head: "9332878ba5a181d9f38de3034e62c3dc7802b922"
base: master
built_on: "680915a"
depends_on: []
stacked_on:
alternative_of: AB1
impact: "allow_browser's check 1.44x faster under YJIT (41.1 -> 28.5 us per user agent over 21 real ones, best of 5, A/A +6.0%; ZJIT master 1.42x), -30.6% YJIT / -27.8% interpreter Callgrind instructions per check, -34 of 183 objects; about 0.9% of a Blog request, 0.4% Campfire, 0.15% Fizzy"
rank: 1
risky: false
state: held
pr:
note: "Not pushed, no fork: 1.44x is below the 2x bar for a gem whose only merger (gshutler) has merged nothing since 2024-12 and left nine 2026 PRs (#73-#81) unanswered. Patches: bench/upstream/ua1/patches/ (git am on 680915a). Send after gshutler answers #73 or otherwise becomes active. Record: docs/upstream/useragent.md."
passes: []
---

# Parse user agents with fewer regexp matches and allocations

Rails 8 generates an `ApplicationController` with `allow_browser versions: :modern`, which runs `UserAgent.parse` on
every request with a user agent. While profiling a few Rails apps, that check came to 0.5 to 3 percent of a request.
Most of it was `Version.new`, which ran two or three regexp matches, a scan and one more match per part for every
product in the string.

These commits make it cheaper without changing any result. A version made only of digits and dots takes one anchored
match and a split, `detect_product` downcases the wanted name once, `application` uses `detect` instead of
`reject { ... }.first`, and `Version#<=>` compares in a loop instead of zipping arrays. Each commit message says why
its results are unchanged.

Parsing 21 current browser, bot and in-app user agents, and running Rails' `allow_browser` check on each of them:

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
