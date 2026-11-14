---
id: AB1
repo: rails/rails
kind: perf
area: Action Controller, allow_browser
reviewer: byroot
branch: thomasklemm/allow-browser-verdict-cache
head: "8dc5af212729c73d2424ac2cb4d03608af8fef6c"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "allow_browser is 0.5-3% of a request in the 3 of 5 profiled apps that use it (Rails 8 default); benchmark-ips 1.96x on a bare controller request (YJIT 94.35 -> 48.08 us, best of 5, A/A +1.9%; ZJIT master 82.6 -> 42.9 us); Callgrind -9.5%/-12.1% Ir on a small JSON request, -2.7%/-3.6% on an HTML page"
rank: 13
risky: false
state: in-review
pr:
note: "8dc5af2127: review fixes on 207a7827a7 (one-line comment, unbacked hit-rate sentence cut from the commit message; test kept by coordinator decision, DECISIONS tests check behaviour). P-MAP top candidate (docs/upstream/p-map.md). ips raw: docs/upstream/data/p-map/ab1-ips.txt (core 3, best of 5; interp best 4,836 -> 7,646 i/s, A/A -3.4%). Callgrind A/A within 0.21%; Fizzy card -0.35% interp; Fizzy YJIT cohort rejected (not JIT-flat)"
passes:
  - {reviewer: claude-code, head: "207a7827a76c3f653662e67072c67a261c7071ba", orb: T-01a1dc09-25b7-74b5-9264-707532942014, date: 2026-11-14, verdict: changes, open: "Must-fix: (1) the new test fails on no wrong cache the existing modern test misses: no cache, no 512-byte bound and no 1,000 bound all pass the branch's tests; replace it with a parse-count test (UserAgent.stub as in the read-once test, stub_const VERDICTS_LIMIT 3), which fails on all three and on a UA-ignoring key, 0.14 s, -w and RuboCop clean. (2) code comment to one line: '# The user agent comes from the client, so the kept verdicts are bounded.' (3) commit message: cut unverified 'Browsers send few distinct user agents, so nearly every request is a hit.' (4) body: 'on every request' -> 'on every request with a user agent' (nil/blank UA never parses). Code is exact: useragent 0.16.11 parse is pure (frozen constants, no config), Rails reads only request.user_agent and frozen EXPANDED_SETS; key is per Symbol set, Hash/String versions and >512-byte UAs bypass; differential probe base vs branch identical over 1,200 lines (6 controllers incl. subclass only/except, Hash, frozen Hash, String, unknown Symbol, method block; 25 UAs incl. nil, blank, binary, invalid UTF-8, 512/513 bytes; 3 passes; status, event count, error class); mutated version Hash still seen. Bounded (MRI Hash dup-freezes keys; 8 threads x 3,000 mixed UAs: no wrong verdict, map bounded); limit is soft by concurrent inserters, fine. Ractor: map works per Ractor, useragent itself is not Ractor-safe (pre-existing). Reload-safe (no app constants cached). Prior art: no rails/rails issue or PR on caching allow_browser (only #59472, #59597 per-check cuts), none rejected; useragent has no parse cache and none proposed. ips (2-core orb, core 1, best of 5, interleaved A/A): YJIT 10,894 -> 21,434 i/s (1.97x, A/A -3.7%), interp 5,482 -> 8,929 (1.63x, A/A +0.3%); body's 2.11x reproduces as ~2x. Callgrind blog GET article.json N=50: interp 2,619,050 -> 2,367,909 (-9.59%, A/A +0.05%), YJIT 1,490,533 -> 1,308,674 (-12.20%, A/A +0.12%, JIT-flat), objects 643 -> 482 (-161): body line true. 0.5-3% checked against the P-MAP record and consistent with Callgrind, not re-profiled. Body: nothing internal, realistic sizes, ips script in Rails' format; author/committer Thomas, no trailers, diff --check clean. Fix patch verified locally, not pushed."}
  - {reviewer: opus, head: "207a7827a76c3f653662e67072c67a261c7071ba", orb: T-01a1dc09-308b-77dd-9150-38db2d788136, date: 2026-11-14, verdict: changes, open: "Code exact, approach is the one to send. Must-fix, all text: (1) code comment to one line (DECISIONS one short line), e.g. '# The user agent comes from the client, so the kept verdicts are bounded.'; (2) commit message: cut 'Browsers send few distinct user agents, so nearly every request is a hit.' (measured 80-85% with a long tail, 0% for a crawler flood, so 'nearly every' overstates); (3) body: 'on every request' -> 'on every request with a user agent' (nil/blank UA never parses). Optional: one body sentence for ZJIT, e.g. 'On Ruby master (9aa0898240) with ZJIT it is 82.6 -> 42.9 us per request.'; the 4.0.9 pin is named by the version line. Disagree with claude-code must-fix 1: keep the branch's test; it is the only test that fails when a hit returns the wrong verdict (set_verdicts[ua] = !verdict) or when long UAs skip the check (return false over 512 bytes), both pass the other 11 tests; a parse-count test is a call-count assertion (DECISIONS: tests check behaviour), though this file's read-once test is upstream precedent. Evidence (details and raw: docs/upstream/p-map.md 'AB1 review numbers', data/p-map/ab1-review-*.txt). Differential probe main vs branch identical: 4 sets (Symbol, Hash, String, unknown Symbol) x 16 UAs incl. nil, blank, 512/513 bytes, binary, invalid UTF-8, each twice; 28 browser_block events on both. Tests 12 runs green on 4.0.9. Body micro, core 1, best of 5, interleaved A/A: 4.0.9 YJIT 94.36 -> 48.08 us (1.96x, A/A +1.9%); master 9aa0898240 ZJIT 82.60 -> 42.93 us (1.92x, A/A -0.2%). ZJIT stats, 20,000 requests, A/A identical to base: compiled_iseq_count 630 -> 603, side_exit_count 21,596 -> 1,635 (exit_exception_handler 19,947 -> 0: useragent's Browsers.extend returns from all.each, lead 17, taken), compiled_side_exit_count 14,326 -> 13,439, zjit_alloc_bytes 2,077,950 -> 1,934,655, OOM 0, failed 0; no ZJIT loss. UA mixes, 20,000 checks, verdicts equal to main's for every request: one UA 100% hits, YJIT 35.6 -> 0.26 us, ZJIT 29.1 -> 0.31 us; 20 browsers 100%, 43.4 -> 0.27 / 32.5 -> 0.34; 20 browsers + 20% unique 79.6%, 40.2 -> 2.6 / 28.9 -> 2.4; Zipf over 5,000 UAs 85.0%, 39.5 -> 5.9 / 31.1 -> 5.7; all unique 0%, 37.8 -> 37.6 / 30.5 -> 32.7 (rerun 34.2 -> 35.0, A/A -5.2%). Miss cost, Callgrind 4.0.9: interp 287,034 -> 296,777 Ir (+3.4%, A/A -0.01%), YJIT 220,315 -> 225,637 (+2.4%, A/A +0.06%), +1 object (Hash dups the unfrozen key); wall within A/A. Memory at the 1,000 bound: 232 KB (long-tail UAs, mean 149 B), 652 KB worst (near 512 B). Shares rebuilt (share x hit rate, minus miss x 3.4%): Blog 3.0% -> -3.0 / -2.4 / -2.5 / +0.10% for browsers / 20% unique / Zipf / crawler flood; Campfire -1.3 / -1.0 / -1.1 / +0.04%; Fizzy -0.5 / -0.4 / -0.4 / +0.02%. Alternatives: per-request memo saves nothing (already memoized per BrowserBlocker, one check per request); a useragent parse cache would land in a gem without a release since 2024-12, must freeze the mutable Array result and still leaves Rails' version/browser work (parse alone is 17.7 of 29.3 us ZJIT, 21.8 of 32.7 us YJIT); caching only the comparison keeps the parse, about 60% of the cost. This change follows Rails' own per-Ractor Concurrent::Map pattern (Request#controller_class_for), so it is the one maintainers are most likely to take. Body 129 words, nothing internal, realistic sizes, ips script and output in Rails' format; output numbers match the record's raw best of 5."}
  - {reviewer: opus, head: "8dc5af212729c73d2424ac2cb4d03608af8fef6c", orb: T-01a1dc09-308b-77dd-9150-38db2d788136, date: 2026-11-14, verdict: nits, open: "Confirm pass: all three must-fixes from the 207a7827a7 pass applied. Branch diff vs 207a7827a7 is the one-line comment only; parent 50c54eed06; author and committer Thomas, no trailers; commit message drops the hit-rate sentence; diff --check clean. allow_browser_test 12 runs, 27 assertions green with -w on 4.0.9; differential probe main vs branch identical (4 sets x 16 UAs, twice each). Body: 'on every request with a user agent' in; ips lines are verbatim from data/p-map/ab1-review-ips-yjit.txt (base round 4, 94.35 us/i; candidate round 3, 48.08 us/i; the record's 94.36 is 1e6/i/s rounding); pins named (4.0.9 version line, master 9aa0898240); footer after --- links p-map.md at a075c18 (200, has 'AB1 review numbers'); 154 words with footer, nothing internal, realistic sizes. Nit, no must-fix: the ZJIT sentence uses an arrow (DECISIONS PR descriptions: no arrows); suggest 'With ZJIT on Ruby master 9aa0898240, it goes from 82.6 to 42.9 µs per request.'"}
---

# Keep allow_browser's verdict per user agent for named version sets

`allow_browser versions: :modern`, which the generated `ApplicationController` calls, parses the user agent with
UserAgent on every request with a user agent. In real apps that use it, that is 0.5 to 3 percent of a request.

For a named set the verdict depends only on the user agent string, so it is now kept per user agent and set, in a
per-Ractor `Concurrent::Map`. The user agent comes from the client, so the map holds at most 1,000 user agents of at
most 512 bytes and is cleared when full. Longer user agents and version Hashes are checked on every request as
before, and a blocked request still instruments and runs the block.

```ruby
require "action_controller"
require "benchmark/ips"

class PagesController < ActionController::Base
  allow_browser versions: :modern

  def show = head(:ok)
end

app = PagesController.action(:show)
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

Benchmark.ips do |x|
  x.report("request with allow_browser") { app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => user_agent)) }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before: request with allow_browser     10.598k (± 5.6%) i/s   (94.35 μs/i) -     54.048k in   5.099630s
after:  request with allow_browser     20.799k (± 8.5%) i/s   (48.08 μs/i) -    106.032k in   5.097817s
```

With ZJIT on Ruby master 9aa0898240, it goes from 82.6 to 42.9 µs per request.

In a small blog app's full request (`GET /articles/:id.json`), it is 161 fewer objects and 9 to 12 percent fewer
instructions.

---

<sub>Found while profiling where Rails apps spend their request time ([record](https://github.com/thomasklemm/lowrail/blob/a075c18e8e7b600b74c54e9dc6480bd1751da278/docs/upstream/p-map.md)).</sub>
