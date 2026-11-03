# Request-path CPU time in Action Pack and Rack (bet P1)

Census R2 ([rails-framework-census.md](rails-framework-census.md)) counted allocations; this round measures where
the **CPU time** of a request goes between the server and the action, and around it, outside view rendering (bet V1)
and Active Record, and whether exact Rails changes make it measurably faster.

**Result: the hunch does not hold at the 0.1% bar.** Request scaffolding (middleware, routing, request/response,
params, callbacks, instrumentation, cookies/session, CSRF, ETag) is 2–9% of request time in lobsters, shipit and the
four census apps, and is spread over many frames, none above 1.3% in any app but railsbench. Only railsbench (tiny
pages, ~40%) and the census Blog (~22%) give it a large share. The largest single frames are required work (body
digest for the ETag, Rack header handling, the 30-key `env.merge!` of boot config, the static-file `stat`). Two exact
branches came out of the hypotheses; both are correct and small, and both are **held below the bar**, with their
numbers below. Nothing is recommended for submission.

| # | Branch | Commit | Per call (interp / YJIT) | Per request share | Status |
| --- | --- | --- | --- | --- | --- |
| P1-1 | [`thomasklemm/csrf-config-without-copy`](https://github.com/thomasklemm/rails/tree/thomasklemm/csrf-config-without-copy) | [`e7c7b65aa4`](https://github.com/thomasklemm/rails/commit/e7c7b65aa4bd9080be3a7a8c37306045d03e7deb) | 4 → 0 objects; −80 / −220 ns | ≤ 0.03% of a railsbench request | Held |
| P1-2 | [`thomasklemm/allow-browser-expanded-sets`](https://github.com/thomasklemm/rails/tree/thomasklemm/allow-browser-expanded-sets) | [`6f7ee34182`](https://github.com/thomasklemm/rails/commit/6f7ee34182a43b5180d611f10ba58d9f4bce9d84) | 1,580 → 236 / 723 → 89 ns | ≈ 0.06–0.08% of a Blog request | Held |

Interpreter / YJIT, Ruby 4.0.7. ruby-bench with an interleaved A/A shows P1-1 as a **tie** (every variant ratio inside
the A/A spread of −7% … +20% per round); the allocation census moves P1-1 nowhere and P1-2 by −1 object per request in
the three `:modern` apps.

## Pins and method

* **Rails:** canonical `rails/rails` main [`e64b660612`](https://github.com/rails/rails/commit/e64b660612fa582a4a89a91bc002269b29426e76)
  (merge of #59552), fetched 2026-11-03 03:00 UTC. Both branches are one commit on it.
* **Ruby 4.0.7**, interpreter and `--yjit`, production, on one 8-core orb with nothing else running during timing.
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2) `railsbench`, `lobsters`, `shipit`,
  with the bench-local compatibility changes of [index-with-capacity](index-with-capacity.md#bench-local-compatibility-changes-same-for-every-variant)
  (Rails path gems, `prism`, lobsters' CSRF strategy and erubi, shipit's erubi and vendored shipit-engine 0.45.0 with
  the `ReviewStack.model_name` override). The Rails path is a symlink switched per variant.
* **Census apps:** Blog, Campfire, Writebook, Fizzy (SQLite) set up with `script/census setup --rails e64b660612…`;
  their request workloads (census 4's client: Firefox 140 user agent, HTTPS, `Sec-Fetch-Site: same-origin`).
  Redis as a disposable orb service. The PostgreSQL/MySQL apps were not set up this round.
* **Profiles:** stackprof 0.2.28, wall mode, 200 µs interval, raw stacks.
  * ruby-bench: [`harness_prof.rb`](../../bench/upstream/actionpack_cpu/harness_prof.rb) (10 warmup iterations,
    then 15 profiled), run for all six app/mode pairs by [`profile.sh`](../../bench/upstream/actionpack_cpu/profile.sh).
  * Census apps: new `script/framework-probe prof` mode ([`probe.rb`](../../bench/upstream/framework_census/probe.rb)
    `prof`): every request workload 50 warmups, then 100 operations per workload, sampled.
  * [`analyze.rb`](../../bench/upstream/actionpack_cpu/analyze.rb) splits each sample under `Rails::Engine#call` into
    **render** (under a controller/view `render`, `render_to_body`, `default_render`, …), **action** (under
    `send_action`), **app/AR** (the nearest non-Ruby, non-Active Support library frame from the leaf is the app,
    Active Record/Model or an app gem) and **scaffold** (the rest), then ranks scaffold frames by self (C frames folded
    into their Ruby caller) and total, and buckets them by the leafmost file that matches a component.
    [`rank.rb`](../../bench/upstream/actionpack_cpu/rank.rb) ranks across apps breadth first (apps reached at ≥ 0.05%,
    then mean share).
  * Call counts: [`harness_calls.rb`](../../bench/upstream/actionpack_cpu/harness_calls.rb) (TracePoint, outside
    `send_action` and Active Record, per request).
* **Micros:** `micro_csrf_allow_browser.rb` and `micro_expanded_sets.rb` in the same directory, best of 3–5 runs,
  each variant loaded from its worktree under the same Ruby.
* **Wall time:** [`interleave.sh`](../../bench/upstream/actionpack_cpu/interleave.sh) runs ruby-bench's default
  harness (10 warmup, 20 timed iterations) per round in rotated order `mainA`, variant, `mainB` (`mainB` is a second
  worktree of the same commit), 3 rounds; [`wall.rb`](../../bench/upstream/actionpack_cpu/wall.rb) reports each run's
  median iteration and the variant against the mean of the round's two mains.

## Where a request's time goes

Share of samples under `Rails::Engine#call` (GC is the share of all samples):

| App / mode | render | action | app/AR | scaffold | GC |
| --- | ---: | ---: | ---: | ---: | ---: |
| railsbench interp | 37.6% | 0.3% | 22.8% | **39.3%** | 4.2% |
| railsbench YJIT | 34.9% | 0.3% | 22.9% | **41.9%** | 10.4% |
| lobsters interp | 54.4% | 31.4% | 6.4% | 7.8% | 2.3% |
| lobsters YJIT | 52.9% | 31.7% | 6.8% | 8.5% | 4.4% |
| shipit interp | 87.2% | 9.5% | 1.2% | 2.2% | 3.2% |
| shipit YJIT | 85.7% | 10.5% | 1.5% | 2.4% | 7.0% |
| Blog interp | 55.3% | 17.1% | 5.4% | **22.2%** | 3.8% |
| Blog YJIT | 52.7% | 20.2% | 4.0% | **23.0%** | 5.6% |
| Campfire interp | 62.7% | 17.6% | 13.9% | 5.8% | 4.9% |
| Campfire YJIT | 64.6% | 16.7% | 13.3% | 5.4% | 8.9% |
| Fizzy interp | 56.7% | 24.8% | 14.3% | 4.2% | 2.8% |
| Fizzy YJIT | 57.5% | 24.0% | 14.5% | 4.1% | 4.5% |
| Writebook interp | 91.8% | 2.5% | 3.8% | 1.9% | 3.4% |
| Writebook YJIT | 91.6% | 2.6% | 3.7% | 2.1% | 5.5% |

railsbench's action is a single `before_action` lookup (app/AR) and its pages are tiny, so the scaffold share is
the largest anywhere. Per request: railsbench 1.6 ms (interp) / 0.64 ms (YJIT) in the profiled runs.

### Scaffold by component (YJIT, share of request samples)

| Component | Apps ≥ 0.05% | Mean | lobsters | railsbench | shipit | Blog | Campfire | Fizzy | Writebook |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| request (Rack/AD request, env, headers, mime) | 7 | 1.84% | 1.50% | 6.00% | 0.43% | 3.11% | 1.02% | 0.53% | 0.31% |
| response (Response, Rack::Headers, BodyProxy) | 7 | 1.53% | 0.52% | 6.74% | 0.20% | 2.21% | 0.50% | 0.38% | 0.15% |
| instrumentation (Notifications, subscribers, event reporter) | 7 | 1.26% | 0.80% | 5.22% | 0.20% | 1.99% | 0.30% | 0.18% | 0.10% |
| cookies/session/flash (incl. message verifier/encryptor) | 7 | 1.16% | 1.88% | 1.06% | 0.43% | 2.38% | 0.96% | 0.91% | 0.51% |
| params (parsing, HWIA, filtering, strong params) | 7 | 1.05% | 0.33% | 3.55% | 0.12% | 2.57% | 0.35% | 0.31% | 0.10% |
| callbacks (Active Support, controller filters) | 7 | 1.01% | 0.53% | 3.64% | 0.15% | 1.79% | 0.45% | 0.30% | 0.23% |
| ETag / conditional GET | 7 | 0.79% | 1.27% | 2.66% | 0.14% | 0.75% | 0.18% | 0.39% | 0.15% |
| controller dispatch (incl. `allow_browser`) | 7 | 0.74% | 0.14% | 0.64% | 0.05% | 3.17% | 0.56% | 0.42% | 0.17% |
| routing (Journey recognition, route set) | 7 | 0.53% | 0.14% | 2.32% | 0.23% | 0.63% | 0.21% | 0.10% | 0.06% |
| logger (Rails::Rack::Logger, tagged/broadcast) | 7 | 0.46% | 0.21% | 2.06% | 0.08% | 0.67% | 0.11% | 0.07% | 0.05% |
| lookup context (per-request LookupContext, I18n proxy) | 6 | 0.44% | 0.24% | 1.74% | 0.07% | 0.77% | 0.12% | 0.08% | 0.04% |
| static files (`stat` of the public root) | 4 | 0.44% | 0.19% | 1.76% | 0.05% | 0.95% | 0.05% | 0.05% | 0.02% |
| executor/reloader | 4 | 0.31% | 0.10% | 1.38% | 0.04% | 0.50% | 0.08% | 0.05% | 0.03% |
| request id (UUID) | 3 | 0.25% | 0.11% | 1.08% | 0.03% | 0.43% | 0.04% | 0.03% | 0.01% |
| CSRF | 5 | 0.16% | 0.10% | 0.26% | 0.03% | 0.57% | 0.07% | 0.06% | 0.03% |
| remote IP / SSL / host | 6 | 0.14% | 0.28% | 0.31% | 0.07% | 0.06% | 0.16% | 0.05% | 0.06% |
| CSP / permissions policy | 3 | 0.06% | 0.01% | 0.09% | 0.00% | 0.01% | 0.14% | 0.13% | 0.05% |
| show/debug exceptions | 0 | 0.01% | 0.01% | 0.03% | 0.00% | 0.02% | 0.01% | 0.00% | 0.00% |

The interpreter ranking has the same order within ±0.2 points.

### Top scaffold frames by self time (YJIT, mean over seven apps)

| Frame | Apps ≥ 0.05% | Mean | railsbench | Blog | What it is |
| --- | ---: | ---: | ---: | ---: | --- |
| `Rack::ETag#digest_body` | 7 | 0.67% | 2.10% | 0.68% | SHA-256 of the body. Required for the ETag. |
| `ActionDispatch::FileHandler#root_entry?` | 3 | 0.33% | 1.22% | 0.82% | One `stat(2)` of the public root's first segment; already reduced by #59504 and ef95eda7b7. |
| `Callbacks#run_callbacks` | 5 | 0.27% | 1.08% | 0.54% | Spread over the block lines of the compiled sequence; compilation is memoized (census R2). |
| `Rails::Engine#build_request` | 3 | 0.25% | 1.30% | 0.28% | `env.merge!(env_config)`, 30 boot keys into every env. Required: apps and middleware read them from env. |
| `Rack::Runtime#call` | 3 | 0.20% | 0.91% | 0.29% | Clock reads and the `X-Runtime` header. |
| `Rack::Headers#[]=` | 3 | 0.19% | 0.87% | 0.36% | Default security headers merged into each response. |
| `ActionDispatch::Response#parse_content_type` | 2 | 0.17% | 0.89% | 0.16% | Once per response (cached since #58966). |
| `URI._encode_uri_component` | 3 | 0.17% | 0.00% | 0.64% | Cookie value escaping (Rack). |
| `UserAgent::Version#initialize`, `UserAgent.parse` | 3 | 0.26% | 0.00% | 1.40% | `allow_browser`; most of it inside the `useragent` gem. **P1-2** removes the Rails part. |
| `EventReporter#emitting?` | 3 | 0.16% | 0.65% | 0.31% | Structured events; the open #58957 changes this path. |
| `Callbacks::CallTemplate::MethodCall#make_lambda` | 5 | 0.11% | 0.40% | 0.15% | Callback dispatch. |
| `Random::Formatter#uuid` | 2 | 0.13% | 0.59% | 0.22% | Request id. Required. |
| `MessageEncryptor#new_cipher`, `OpenSSL::Cipher#random_iv` | 3 | 0.15% | 0.00% | 0.59% | Encrypted cookie/session writes; open #59086 caches the encryptors. |

## Hypotheses

Per-request work that is fixed after boot, slow generic paths for common requests, avoidable dispatch:

| Hypothesis | Measured | Outcome |
| --- | --- | --- |
| CSRF settings read through `config` build the controller's `InheritableOptions` copy on every page that renders `csrf_meta_tags` or a form (railsbench: the only reason the copy is built; 0.37% of request samples in `inheritable_copy`). | 4 objects, 650 → 431 ns (YJIT), ~80 ns (interp, noisy) | **P1-1, held** |
| `allow_browser versions: :modern` (the generated `ApplicationController`) converts the frozen `:modern` set with `with_indifferent_access` on every request. | 1,580 → 236 ns (interp), 723 → 89 ns (YJIT) | **P1-2, held** |
| `env.merge!(env_config)` in `Rails::Engine#build_request` (1.3% self on railsbench YJIT) | 30 Hash inserts plus env table growth per request | Rejected: the keys must be in env (read by cookies, session, exceptions, CSP, apps); a default proc or lazy merge changes `env.key?`/`each`. |
| `Rack::ETag#digest_body` (largest frame in every app) | SHA-256 of the body | Rejected: required for the ETag value; a different digest changes ETags. |
| Static file probe (`root_entry?`, 0.6–1.2% railsbench) | one `File.exist?` per GET | Rejected: a negative cache misses files added to `public/` at runtime. Already reduced upstream. |
| `run_callbacks` self time | spread across block lines; no compile after warmup | Rejected: no single avoidable step. |
| `UserAgent.parse` per request (16–20 µs per check) | most of `allow_browser`'s 22–34 µs | Not exact without a cache keyed by user agent (unbounded or LRU: a design change). Gem work. |
| Structured event `emitting?`/subscriber checks | 0.65% railsbench YJIT | Excluded: open #58957. |
| Encrypted cookie/session ciphers | 0.6% Blog YJIT | Excluded: open #59086. |
| Request id UUID, `Rack::Runtime`, security headers | 0.2–1.1% railsbench | Required output. |

## P1-1: CSRF settings without the controller's config copy

`RequestForgeryProtection` delegates its instance readers (`allow_forgery_protection`,
`forgery_protection_verification_strategy`, …) to `config`, and `AbstractController::Base#config` builds the
instance's `InheritableOptions` copy on first use. `protect_against_forgery?` (from `csrf_meta_tags`, forms and
`verify_request_for_forgery_protection`) therefore built that copy only to read a class-level setting. The readers
now read `(defined?(@_config) && @_config) || self.class.config`, the pattern #59105 (merged) used for the logger;
writers still go to `config`, so a value assigned on the instance is read back from its copy.

```diff
-      delegate :allow_forgery_protection, :allow_forgery_protection=, to: :config
+      delegate :allow_forgery_protection, to: :forgery_protection_config
+      delegate :allow_forgery_protection=, to: :config
 …
+      def forgery_protection_config
+        (defined?(@_config) && @_config) || self.class.config
+      end
```

(The same split for the ten CSRF settings.)

| Per call | main | branch |
| --- | ---: | ---: |
| `protect_against_forgery?` on a fresh controller, objects | 4 | 0 |
| ns, interpreter | 1,055 | 974 |
| ns, YJIT (two runs) | 679, 630 | 430, 432 |

**Boundary:** a controller that overrides the instance method `config` is bypassed by the readers until something
calls it. Any page that reads the view's config (asset helpers) still builds both copies, so census apps that link
assets don't move.

**ruby-bench** (interleaved, `mainA`/`csrf`/`mainB`, 3 rounds; railsbench interpreter has 2 complete rounds because
the round-1 `mainA` log was overwritten when the bench service restarted after finishing):

| app | mode | rounds | mainA ms | mainB ms | variant | variant ms | variant / main (median, range) | A/A mainB / mainA (median, range) |
|---|---|---:|---:|---:|---|---:|---|---|
| lobsters | interp | 3 | 1034.0 | 1039.5 | csrf | 1037.0 | +0.0% (-3.7% … +1.4%) | +0.5% (-2.0% … +6.8%) |
| lobsters | yjit | 3 | 614.5 | 630.5 | csrf | 630.0 | +1.6% (-1.0% … +1.7%) | +2.6% (-3.8% … +4.1%) |
| railsbench | interp | 2 | 2016.0 | 1978.25 | csrf | 1936.75 | -3.0% (-5.9% … +0.0%) | -1.9% (-2.0% … -1.7%) |
| railsbench | yjit | 3 | 752.5 | 773.5 | csrf | 755.0 | -5.9% (-8.2% … +5.7%) | -3.3% (-7.2% … +20.3%) |
| shipit | interp | 3 | 1962.5 | 1974.5 | csrf | 1933.0 | -1.4% (-3.0% … +0.7%) | -0.4% (-1.7% … +2.9%) |
| shipit | yjit | 3 | 892.0 | 923.0 | csrf | 919.5 | -1.2% (-4.4% … +5.5%) | +3.4% (-1.7% … +10.7%) |

Every ratio is inside its A/A range; the expected effect (≤ 0.03% of a railsbench request) is two orders of magnitude
below this noise. **Tie.**

**Census** (`p1base`/`p1base2` A/A, then one label per branch, 4 apps, 41 workloads, median objects per workload,
interpreter / YJIT):

| App | A/A | P1-1 csrf | P1-2 allow_browser |
| --- | ---: | ---: | ---: |
| Blog | +0.0 / +0.0 | +0.0 / −1.4 | −1.0 / −1.0 |
| Campfire | +0.0 / +0.0 | +0.1 / +0.0 | +0.0 / +0.0 |
| Fizzy | +0.0 / −0.0 | +0.0 / +0.0 | −0.8 / −0.6 |
| Writebook | +0.3 / +0.6 | +0.0 / +0.8 | −0.3 / −2.9 |
| **All workloads** | **+0.0 / +0.0** | **+0.0 / +0.0** | **−0.3 / −0.6** |
| Moved ≤ −1 / ≥ +1 | 4 / 7 · 7 / 6 | 7 / 6 · 9 / 8 | 16 / 4 · 20 / 6 |

P1-1 does not move the census apps: their layouts read the view's config (asset helpers), which builds the
controller's copy anyway. P1-2 saves one object on the checked requests of the three `:modern` apps; Campfire passes
its own version hash.

## P1-2: `allow_browser`'s named sets built once

`BrowserBlocker#expanded_versions` called `(SETS[versions] || versions).with_indifferent_access` per check. The
named sets are frozen constants, so their indifferent-access copies are now built when the class loads
(`EXPANDED_SETS`, frozen and `Ractor.shareable?`); custom version hashes are still converted per check, so later
mutations of them are seen as before.

| Per call | main | branch |
| --- | ---: | ---: |
| `expanded_versions["firefox"]` for `:modern`, interpreter | 1,580 ns | 236 ns |
| same, YJIT | 723 ns | 89 ns |
| whole `blocked?` (Firefox 140), interpreter | 34.4 µs | 30.1 µs |
| whole `blocked?`, YJIT | 22.1–22.4 µs | 21.0–22.2 µs (within noise) |

No ruby-bench wall time was run for P1-2 because ruby-bench cannot show it: shipit, the only app with `allow_browser`, sends no user agent, so the check returns
before the lookup. In the census apps (Blog, Fizzy, Writebook use `:modern`; Campfire its own hash) the saving is
~1.3 µs / ~0.6 µs per request against ~1 ms Blog requests.

## Drafts (not published, held)

Short form from [DECISIONS](../DECISIONS.md); kept for the record, not for submission at this size.

**P1-1 — Read CSRF settings without building the controller's config copy**

> Every page that renders `csrf_meta_tags` or a form calls `protect_against_forgery?`, which reads
> `allow_forgery_protection` through the controller's `config`. That builds the controller's per-instance
> `InheritableOptions` copy (four objects) just to read a class-level setting; in railsbench it is the only thing
> that builds the copy.
>
> The CSRF readers now read through the class config until the controller has its own copy, as the logger has
> since #59105. Writers still go to `config`, so a setting assigned on an instance is read back from its copy.
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | `protect_against_forgery?`, first call | 4 objects, 1,055 / 650 ns | 0 objects, 974 / 431 ns |
>
> Interpreter / YJIT, Ruby 4.0.7. Apps that read the view's config (asset helpers) still build the copy, so
> the saving is limited to pages that don't.

**P1-2 — Build allow_browser's named version sets once**

> The generated `ApplicationController` calls `allow_browser versions: :modern`, and every checked request
> converted the frozen `:modern` set to a `HashWithIndifferentAccess` to look up the browser's minimum version.
>
> The named sets are now converted once when the class loads (frozen, Ractor-shareable). Version hashes passed by
> the app are still converted on each check, so changes to them are seen as before.
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | minimum version lookup for `:modern` | 1,580 / 723 ns | 236 / 89 ns |
>
> Interpreter / YJIT, Ruby 4.0.7. Every request of an app using `:modern` with a versioned user agent saves it;
> the user agent parse itself (~20 µs) is in the `useragent` gem and unchanged.

## Suites and checks

Local, Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, the branch's `lib` verified as loaded:

| Suite | main `e64b660612` | P1-1 | P1-2 |
| --- | --- | --- | --- |
| Action Pack (`rake test`) | 4,463 runs, 21,484 assertions, 0 F, 0 E, 0 skips | same | same |
| Action View (`rake test:template`) | 2,913 runs, 6,939 assertions, 0 F, 0 E | same | — |

RuboCop on each changed file: no offenses. Behavior controls
([`controls.rb`](../../bench/upstream/actionpack_cpu/controls.rb), 12 lines: default, instance write read back, other
instances unaffected, subclass override, class change after a read, write through `config`, token name; `blocked?`
for five user agents × `:modern`, Symbol- and String-keyed custom hashes, and a custom hash mutated between checks):
identical on main and both branches. No hosted CI; no Thermos review (nothing is proposed for submission).

## Limits

* Wall-clock sampling at 200 µs; shares below ~0.05% are not resolved. The bucket assignment is by file and is an
  approximation (an Active Support frame under an app callback counts as app/AR).
* Four SQLite census apps only this round; lobsters/shipit/railsbench from ruby-bench.
* Micros are best-of on one orb; wall time is ruby-bench on the same orb with an A/A control, 3 rounds.
* Receipts: [data/actionpack-cpu/receipts.tar.gz](data/actionpack-cpu/receipts.tar.gz) holds the analyze/rank
  outputs (JSON and text), call counts, wall-time logs and census compare output; the raw dumps (large) stay in the orb under `.lowrail/private/census/prof-main/` and
  `work/prof/main/`; the rankings above are reproduced by `analyze.rb` and `rank.rb`.
