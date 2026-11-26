---
id: CRSI1
repo: ruby-concurrency/concurrent-ruby
kind: perf
area: Synchronization::SafeInitialization#new
reviewer: eregon
branch:
head:
base: master
built_on: "aa56313"
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/hotline_candidates/README.md, bench/upstream/hotline_candidates/si_ir-4.0.9.txt, bench/upstream/hotline_candidates/si_objects-4.0.9.txt, bench/upstream/hotline_candidates/blog-articles]
impact: "Below the 2% bar. new(...) instead of new(*args, &block) saves one Array per object: -743 Ir per two-argument new, -570 per AtomicBoolean.new (Ruby 4.0.9 interpreter, A/A 8 and 1 Ir). Census apps create 5-7.5 such objects per request in 17 of 18 apps (0.01-0.23% of request objects); on the Blog (Rails 8.1.4) all six come from Active Record's AsynchronousQueriesTracker::Session. Blog GET /articles (Rails 8.1.4, Ruby 4.0.7 interpreter, lowrail bench's request driver, fixed-heap Callgrind, 6 rounds): -0.059% total instructions per request [-0.072, -0.035] (9,086,081 -> 9,080,791, about -5,300 Ir), -0.047% without GC, objects 2,358.5 -> 2,352.0 (-0.27%), A/A -0.008% [-0.041, +0.019], heap matched, 0 GCs; an unchanged copy of the app measures -0.012% [-0.042, +0.018] against the same baseline. On Rails main the Session is built only for async queries (rails/rails#59373, unreleased), so apps without load_async lose these objects with 8.2 anyway. The gem supports Ruby >= 2.3, where (...) does not exist."
rank:
risky: false
state: held
pr:
note: "2026-11-26: measured, not built (below the bar). Lead from bench/upstream/profile_hotlines_census (Suggested items 2). Not built: request-level effect -0.059% of a Blog request's instructions and -6.5 of 2,358 objects (bench/upstream/hotline_candidates, run 2), far under the ~2% bar; (...) needs Ruby 2.7 while the gemspec allows 2.3, so a PR would also need a version branch (L3) or a floor raise; and on Rails main the per-request source is gone (Sampo Kuokkanen's lazy session, 91f0f89aeb, merged 2026-10-31). Keyword behaviour would change too: new(*args) without ruby2_keywords hands keywords to initialize as a positional Hash, (...) passes them as keywords. Ownership: no open or closed PR or issue names SafeInitialization or safe_initialization.rb as a cost; #829, #416 and #462 touch it for other reasons; no open PR changes lib/concurrent-ruby/concurrent/synchronization. ZJIT side: SafeInitialization#new is already a recorded super-with-splat fallback lead (docs/upstream/zjit-gap-census.md, Shopify/ruby#1039 rows 45 and 46, partly). Reopen only if a measurement on an app that runs many safe-initialized objects per request (Promises-heavy code) clears the bar."
ownership: {date: 2026-11-26, checked: ["ruby-concurrency/concurrent-ruby PRs and issues naming SafeInitialization or safe_initialization, open and closed", "open PRs changing lib/concurrent-ruby/concurrent/synchronization", "git log of safe_initialization.rb (one commit, d824048, 2023)"], hits: []}
passes: []
---

# Forward SafeInitialization#new's arguments without a splat Array

Not built; below the bar.

## For Thomas

Every object of a concurrent-ruby class that is marked for safe initialization (locks, atomics, futures) is
created through `SafeInitialization#new(*args, &block)`, which gathers the arguments into a new Array just to pass
them on. `new(...)` would pass them on directly. It saves one small object per lock or atomic, but a Rails 8.1
request creates only six of them, all for the async-query session, and Rails main no longer creates that session
unless the request runs an async query. The gem also still supports Ruby versions without `...`.
