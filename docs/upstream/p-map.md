# P-MAP: where a real request spends its time, by layer

Bet P-MAP, 2026-11-14. Five census apps (Blog, Campfire, Fizzy, Lobsters, Mastodon) on Rails main
[50c54eed06](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b), Ruby 4.0.9 with
YJIT, production mode, 48 workloads, including index pages with 100 records, JSON lists with 40 to 100 records,
forms (one rejected with 422) and writes. The goal was to rank performance candidates by their share of real
request time instead of by micro effect size.

**Result.** There's no big lever left in Rails that a single patch would pull. The largest layers are Active Record
query building (10.9% of server time on average), the database driver's C code (7.3%) and GC (7.6%). All three are
spread over hundreds of methods: apart from the instrumentation CPU clock (1.2%, mostly covered upstream), no Rails
method's own time is above 0.9% of a request on average.
What stands out is `allow_browser` (the Rails 8 default in `ApplicationController`): it parses the user agent on
every request, 0.5–3% of a request in the three apps that use it. A verdict cache doubles the throughput of a bare
controller request with `allow_browser` (benchmark-ips, 2.1× under YJIT) and cuts 9.5–12% of the Callgrind
instructions of a small JSON request and 2.7–3.6% of an HTML page. It is built as **AB1**. Everything else in the top
10 is inherent, the app's own code or config, or already in flight upstream.

## Method

* **Server.** Puma 8.0.2 runs in the measured process, with one worker thread. A raw-socket keep-alive client in
  a second thread sends each workload 60 times as warmup and then 200 times. Puma, Rack, every middleware and the
  response write run as in production. Log level is fatal (the census default). One extra run at info shows what
  logging adds.
* **Profiler.** Vernier 1.12 in wall mode samples every 500 µs, and only Puma's threads are mapped. Server time
  is the worker's running samples, plus the worker's samples blocked inside a request with the GVL released (DB
  wait), plus Puma's reactor, plus `GC.total_time` (Vernier doesn't sample GC). Each sample is charged to the
  layer of its innermost Ruby frame (self time, including the core C methods it calls), except that a leaf C
  method of a driver, JSON, OpenSSL and similar extensions is charged to that extension's layer. Shares are the mean over an app's workloads, and the across-app mean weights each app
  the same.
* **A/A.** The whole profile was run twice per app. Absolute times moved by −14% to +86% per workload between the
  two runs (the orb is noisy), but layer shares moved by at most 0.72 pp, except GC in Campfire (+2.46 pp) and DB wait in Mastodon
  (+2.12 pp), which both depend on timing. A share below about 0.7 pp is not a finding by itself.
* **Native.** `perf record` with `--yjit-perf`, around the same windows, puts each Puma thread's CPU into a native
  bucket (JIT code, interpreter, core C, malloc, GC, drivers).
* **Prototypes.** A benchmark-ips script for the PR body (`ab1_ips.rb`, one pinned core, best of 5, A/A), and
  Callgrind instructions per request through the full Rack stack (`request_ir.sh`): GC is turned
  off after `GC.start`, collection is toggled around 50 requests, the base runs twice as A/A, and both interpreter
  and YJIT are measured. A YJIT cell counts only when its window compiled 0 blocks (JIT-flat). Raw cells:
  [`data/p-map/callgrind.txt`](data/p-map/callgrind.txt).

Fizzy needs one measurement-only change to run on main (its UUID primary key initializer recursed after
rails#59530), and Lobsters needs activerecord-typedstore from master. Tooling: [`bench/upstream/p_map/`](../../bench/upstream/p_map/).
Shares per workload: [`data/p-map/`](data/p-map/) (`shares-aa.json`, the A/A twin `shares-a2.json`, and `shares-info.json` at
log level info).

## Layer shares per app

Percent of server time, mean over each app's workloads, YJIT, log level fatal.

| Layer | Blog | Campfire | Fizzy | Lobsters | Mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| Puma | 11.0 | 4.5 | 1.5 | 2.5 | 2.4 | 4.4 |
| Rack | 2.9 | 2.1 | 0.6 | 1.0 | 0.8 | 1.5 |
| Middleware | 4.0 | 2.6 | 1.4 | 1.8 | 1.8 | 2.3 |
| Request/response | 3.6 | 2.2 | 0.8 | 1.6 | 1.5 | 2.0 |
| Routing | 3.3 | 0.9 | 0.7 | 3.5 | 1.4 | 1.9 |
| Controller | 3.4 | 1.9 | 1.0 | 1.3 | 1.0 | 1.7 |
| Callbacks | 2.3 | 1.7 | 1.2 | 1.6 | 0.9 | 1.5 |
| AR: query building | 2.8 | 7.9 | 16.0 | 16.5 | 11.5 | 10.9 |
| AR: adapter (Ruby) | 4.1 | 2.7 | 4.3 | 3.8 | 3.3 | 3.6 |
| AR: driver (C) | 4.0 | 4.8 | 10.0 | 12.7 | 4.8 | 7.3 |
| DB wait (GVL released) | 0.3 | 0.6 | 1.8 | 0.4 | 15.9 | 3.8 |
| AR: instantiate | 3.0 | 2.1 | 4.1 | 4.4 | 4.0 | 3.5 |
| AR: attributes/casting | 2.7 | 1.7 | 3.2 | 4.4 | 3.2 | 3.0 |
| AR: associations | 2.5 | 2.7 | 4.4 | 5.4 | 3.5 | 3.7 |
| AR: write path | 1.1 | 0.6 | 0.9 | 0.8 | 0.3 | 0.8 |
| AR: other | 1.7 | 2.0 | 5.1 | 3.5 | 2.7 | 3.0 |
| AV: lookup | 0.7 | 0.3 | 0.3 | 0.2 | 0.1 | 0.3 |
| AV: render | 2.9 | 1.3 | 1.6 | 1.0 | 0.3 | 1.4 |
| AV: helpers | 4.9 | 0.9 | 4.0 | 4.0 | 1.9 | 3.1 |
| AV: escaping | 1.5 | 0.2 | 1.1 | 0.9 | 0.7 | 0.9 |
| App templates | 1.2 | 0.2 | 0.5 | 0.6 | 0.2 | 0.5 |
| Serializers (gems) | 0.8 | 0.2 | 0.1 | 0.0 | 8.7 | 2.0 |
| JSON | 1.1 | 1.7 | 0.5 | 0.9 | 0.5 | 0.9 |
| i18n | 4.1 | 0.2 | 0.1 | 0.5 | 0.3 | 1.0 |
| Logging/instrumentation | 4.2 | 2.6 | 6.5 | 1.9 | 1.8 | 3.4 |
| Cache | 0.1 | 1.4 | 3.0 | 0.5 | 2.6 | 1.5 |
| Time/TZ | 1.0 | 1.2 | 0.8 | 4.1 | 0.4 | 1.5 |
| concurrent-ruby | 1.4 | 0.6 | 1.1 | 1.0 | 1.4 | 1.1 |
| Digest/crypto | 3.8 | 2.3 | 2.3 | 2.6 | 0.4 | 2.3 |
| AS: other | 5.4 | 3.2 | 4.0 | 5.2 | 5.2 | 4.6 |
| App code | 0.2 | 3.1 | 4.2 | 3.0 | 4.4 | 3.0 |
| Other gems | 7.2 | 24.2 | 4.4 | 3.8 | 3.8 | 8.7 |
| Ruby stdlib | 1.3 | 2.5 | 0.8 | 0.8 | 0.4 | 1.1 |
| GC | 5.5 | 13.0 | 7.6 | 4.0 | 8.0 | 7.6 |

Grouped, the mean request spends 36% in Active Record (Ruby and driver) plus 3.8% waiting on the database, 15% in
the stack around the action (Puma to callbacks), 6.2% in Action View, 7.6% in GC, and 3.4% in logging and
instrumentation. At log level info, logging and instrumentation rise to 4.5% (Blog 5.7, Fizzy 7.3).

The apps differ more than the layers. Blog's requests are small (1.4–19 ms), so Puma, Rack, middleware and request/response
take 21% of them. Fizzy and Lobsters are query-heavy (AR is 48–51%). Mastodon waits on PostgreSQL (16%) and serializes with
ActiveModel::Serializers (8.7%). Campfire spends 24% in "other gems", mostly under its own `InlineScriptHashes` concern
(18% inclusive), which parses every HTML response with Nokogiri and every script URL with `URI`.

Per workload, the heaviest single layers are i18n in Blog's rejected form (25.6% of that request, error messages),
AR query building in Fizzy's board (23.2%) and Lobsters' vote (21.9%), Time/TZ on Lobsters' home page (8.8%, the
app's `User#is_new?`), and Puma on Blog's JSON show (23.4% of a 1.4 ms request).

### Native CPU (perf, YJIT)

Share of the Puma threads' CPU samples.

| Bucket | Blog | Campfire | Fizzy | Lobsters | Mastodon |
|---|---:|---:|---:|---:|---:|
| Ruby core C (String, Hash, Array, Regexp, …) | 30.8 | 25.5 | 28.5 | 29.9 | 27.9 |
| VM dispatch and interpreter | 18.1 | 19.1 | 26.9 | 24.9 | 31.5 |
| JIT code (YJIT) | 15.2 | 19.7 | 8.8 | 13.5 | 10.7 |
| GC (mark, sweep, compact) | 7.9 | 5.8 | 9.5 | 4.6 | 7.9 |
| malloc/free | 7.1 | 8.3 | 7.5 | 5.7 | 8.1 |
| Object allocation | 6.2 | 6.1 | 6.2 | 6.3 | 6.4 |
| libc other (memcpy, …) | 3.4 | 2.8 | 3.9 | 3.0 | 2.7 |
| Kernel (syscalls, scheduling) | 4.4 | 4.4 | 1.9 | 1.9 | 3.0 |
| Database engine and driver | 1.6 | 4.1 | 2.7 | 6.6 | 0.9 |
| OpenSSL | 2.5 | 1.0 | 0.4 | 1.6 | — |
| Other C extensions | 2.5 | 2.9 | 3.6 | 1.7 | 0.6 |
| JSON (C) | 0.2 | 0.3 | 0.3 | 0.1 | 0.3 |

Only 9–20% of CPU is in YJIT's own code, and 18–32% is in VM dispatch and the interpreter (calls YJIT hands back to
the VM, side exits, and code it didn't compile). Allocation, malloc and GC together are 17–23%, so allocations cut
anywhere pay twice. SQLite itself is small except in Lobsters, where query log tags turn prepared statements off
(Rails does that when `query_log_tags_enabled` is set and `disable_prepared_statements` is left unset), so every
query is compiled again.

## Mechanisms

Inclusive share (a sample counts for every matching method on its stack), so rows overlap.

| Mechanism | Blog | Campfire | Fizzy | Lobsters | Mastodon | mean |
|---|---:|---:|---:|---:|---:|---:|
| Partial/collection render | 11.3 | 7.7 | 29.1 | 9.3 | 5.3 | 12.5 |
| Query cache (wraps every SELECT) | 5.3 | 5.3 | 20.5 | 16.9 | 10.4 | 11.7 |
| Transactions and commit callbacks | 13.1 | 11.7 | 9.8 | 6.8 | 1.2 | 8.5 |
| JSON encode | 0.8 | 0.7 | 0.3 | 5.9 | 32.1 | 8.0 |
| Association preloading | 5.4 | 4.1 | 9.2 | 12.8 | 5.6 | 7.4 |
| Tag helpers | 3.8 | 7.1 | 20.7 | 3.2 | 1.1 | 7.2 |
| Jbuilder | 9.4 | 8.5 | 15.2 | — | — | 6.6 |
| SQLite step and rows | 2.9 | 3.1 | 7.6 | 6.2 | — | 3.9 |
| Relation building (spawn, where, merge) | 0.4 | 2.2 | 4.7 | 6.1 | 3.8 | 3.4 |
| Cache store read/write | — | 1.3 | 8.2 | 1.9 | 2.4 | 2.8 |
| Validations | 0.8 | 2.4 | 2.3 | 6.0 | 0.5 | 2.4 |
| URL helpers | 3.3 | 1.0 | 0.7 | 4.5 | 1.6 | 2.2 |
| Arel to SQL | 0.6 | 0.9 | 3.7 | 3.0 | 1.2 | 1.9 |
| SQLite prepare of an uncached statement | 0.7 | 1.1 | 1.9 | 5.1 | — | 1.8 |
| Cookie encrypt/sign | 2.0 | 2.1 | 1.3 | 1.2 | — | 1.3 |
| TimeWithZone conversion | 0.8 | 1.2 | 0.7 | 3.6 | 0.3 | 1.3 |
| Notifications `Event` CPU, GC and allocation clocks | 1.4 | 0.9 | 3.3 | 0.3 | 0.2 | 1.2 |
| CSRF token mask and HMAC | 4.2 | — | — | 1.6 | — | 1.2 |
| Structured events to log subscribers | 0.7 | 0.6 | 3.1 | 0.3 | 0.2 | 1.0 |
| i18n translate | 4.0 | 0.1 | 0.1 | 0.4 | 0.2 | 1.0 |
| `allow_browser` | 3.0 | 1.3 | 0.5 | — | — | 0.9 |
| `Rack::ETag` body digest | 1.1 | 0.2 | 1.5 | 0.9 | 0.4 | 0.8 |
| Template and partial lookup | 1.6 | 0.5 | 0.7 | 0.3 | 0.3 | 0.7 |

## Ranked hotspots

Ranked by mean share across the five apps, which already weighs reach (an app that never hits it counts 0).
"Share" is what the hotspot costs now, and "would bring" is the share of a request an exact fix could remove.

| # | Hotspot | Share (mean; apps) | Verdict | Would bring |
|---|---|---|---|---|
| 1 | AR query building: relations, scoping, Arel, predicate builder | 10.9%; 5 | inherent: flat, the largest method (`Delegation::ClassMethods#create`) is 0.42% and nothing else is above 0.35% | — |
| 2 | GC (plus allocation and malloc in native) | 7.6%; 5 | inherent; the lever is fewer objects, as in AB1 (−161 objects per request) | via allocation cuts such as AB1 |
| 3 | Database driver (C) and SQLite step/compile | 7.3%; 5 | covered for row decoding (sqlite3-ruby #769, #770 open); Lobsters' 5.1% compile is its own config (query log tags without `disable_prepared_statements = false`) | Lobsters: up to 5% by app config |
| 4 | Puma request parse and response write | 4.4%; 5 (Blog 11) | inherent: socket syscalls, header formatting; no method above 0.6% | — |
| 5 | Campfire's `InlineScriptHashes` (Nokogiri parse, `URI` split) | 3.7% mean (Campfire 18%); 1 | app code | — |
| 6 | Logging and instrumentation: `Event` clocks (1.2), structured-event handlers (1.0) | 3.4%; 5 | covered: rails#58957 (silence Action Controller and Active Job handlers nobody consumes) and rails#59717 (skip `source_location`) are open; Fizzy's 3% are SQL events it consumes on purpose (`Rails.event.debug_mode`) | 0.5–1.4% in Blog, Campfire |
| 7 | Digest/crypto: CSRF per-form tokens (1.2), cookie encryption (1.3), `Rack::ETag` (0.8) | 2.3%; 5 | CSRF inherent (one HMAC and mask per form, by design); ETag covered (rack#2522 open); `MessageEncryptor.key_len` builds an `OpenSSL::Cipher` per request: **MK1**, built and held | MK1: below noise (≈0.03%) |
| 8 | ActiveModel::Serializers 0.10 in Mastodon | 1.7% mean (Mastodon 8.7%); 1 | outside the central gems; a lead for AMS, not pursued | — |
| 9 | i18n (Blog's 422 form: 25.6% of that request) | 1.0%; 1 | covered: ruby-i18n/i18n#763–#766 open | — |
| 10 | `allow_browser` user agent parsing | 0.9%; 3 (Blog 3.0, Campfire 1.3, Fizzy 0.5) | **candidate, built: AB1** | Blog 3.0%, Campfire 1.3%, Fizzy 0.5% |

Below the top 10: Time/TZ in Lobsters (4.1%, the app's `Time#advance` per story), tag helpers (`tag_options` and
`append_tag_option`, 1.1% self, already trimmed by earlier PRs, nothing exact left), and the query cache's
`compute_if_absent` (0.42% self).

## Prototypes

Both are on [thomasklemm/rails](https://github.com/thomasklemm/rails), built on 50c54eed06, with queue items AB1
(`built`) and MK1 (`held`). No third prototype: nothing else in the top 10 is both a Rails or central-gem cost and
not already in flight.

**AB1, [`thomasklemm/allow-browser-verdict-cache`](https://github.com/thomasklemm/rails/tree/thomasklemm/allow-browser-verdict-cache).**
`BrowserBlocker` parses the user agent with the useragent gem on every request (22 µs for the parse, 37–53 µs per
request for the whole check under YJIT). The verdict depends only on the user agent string and the named version
set, so it is kept per user agent for Symbol sets (`:modern`), at most 1,000 user agents of at most 512 bytes per
set, and cleared when full. A Hash of versions and long user agents take the uncached path. Blocked requests still
instrument and run the block.

benchmark-ips on a bare controller request with `allow_browser versions: :modern` (the body's script), core 3,
best of 5, interleaved with an A/A ([raw](data/p-map/ab1-ips.txt)):

| Mode | base | A/A | AB1 | change |
|---|---:|---:|---:|---:|
| YJIT | 10,032 i/s | 10,207 (+1.7%) | 21,214 i/s | 2.11× |
| interpreter | 4,836 i/s | 4,671 (−3.4%) | 7,646 i/s | 1.58× |

Callgrind instructions and objects per request through the full Rack stack of the census apps:

| Workload | Mode | base | A/A | AB1 | change |
|---|---|---:|---:|---:|---:|
| Blog GET article.json | interpreter | 2,612,439 | +0.03% | 2,364,907 | −9.48% |
| Blog GET article.json | YJIT | 1,488,644 | +0.08% | 1,307,833 | −12.15% |
| Blog GET article (HTML) | interpreter | 8,874,838 | +0.21% | 8,633,518 | −2.72% |
| Blog GET article (HTML) | YJIT | 5,169,158 | −0.03% | 4,984,840 | −3.57% |
| Fizzy GET card | interpreter | 78,505,914 | +0.02% | 78,227,320 | −0.35% |

Objects per request drop by 161–170 (643 → 482 on the JSON request). Fizzy's card page under YJIT is rejected, not
rerun: its base and A/A windows compiled 19 and 25 blocks, so they aren't JIT-flat.

**MK1, [`thomasklemm/message-encryptor-key-len`](https://github.com/thomasklemm/rails/tree/thomasklemm/message-encryptor-key-len).**
`MessageEncryptor.key_len` builds an `OpenSSL::Cipher` each time it is called, and the encrypted cookie jar calls
it once per request that reads or writes an encrypted cookie. The length depends only on the cipher name, so it is
kept per cipher name. Per call that saves 2,447 instructions and 2 objects (5,833 → 3,386, interpreter). On a Blog
article request it is inside the Callgrind A/A noise (interpreter: base 8,874,970, A/A +0.08%, MK1 +0.11%; YJIT: base 5,164,117, A/A
−0.18%, MK1 −0.19%; −2 objects), so the
item is `held`, not `built`: not worth a reviewer's time on its own.

## What it means for the next bets

* The real-world lever in Rails isn't a method, it's allocation volume and the VM share under YJIT: 18–32% of
  CPU is in VM dispatch and the interpreter, and allocation plus GC are about a fifth. Splitting that bucket on
  the Fizzy and Mastodon request paths (which calls go back to the VM, and why) is the next map to draw.
* Query building is flat at the method level. Further work there needs a structural change (fewer relation
  copies per query, or caching the built Arel for repeated association scopes), not micro patches.
* App-level findings worth telling the apps, not Rails: Lobsters' query log tags cost about 5% in SQLite compiles,
  and Campfire's response parsing costs about a fifth of each HTML request.
