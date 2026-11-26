# inertia-rails round 2: after v3.24.0 (2026-11-26)

skryukov released [inertia-rails 3.24.0](https://github.com/inertiajs/inertia-rails/releases/tag/v3.24.0) on
2026-11-26 with our #435, #436, #437, #441, #442 and #444. This round looked for what is left on master
[`5102d8d`](https://github.com/inertiajs/inertia-rails/commit/5102d8dba7) (the 3.24.0 bump). It used the method of
#437 and #442: profile real apps, then measure the renderer and the props resolver directly. One lead clears the bar
(INRP1). Five do not; one of them is slower.

## Apps

Each app's own suite ran on 3.24.0 as a path gem, with lowrail-profile 0.1.0.rc1 from `gem/` (unchanged since
`644c99e4`), seed 1234, two runs. Captures and bundle paths are in
[bench/upstream/inertia_round2](../../bench/upstream/inertia_round2); `script/profile-hotlines @bench/upstream/inertia_round2/apps.txt`
ranks them.

| App | Ruby | Suite | Requests | Objects/request | inertia_rails objects/request |
| --- | --- | --- | ---: | ---: | ---: |
| Pingcrm `22464f8` | 4.0.7 | `bin/rails test:all -v`, 26 tests incl. system (Chrome for Testing 157) | 74 | 3,231 | 75.1 |
| React Starter Kit `f808193` | 4.0.9 | `rspec`, 36 examples | 54 | 2,180 | 26.6 |
| Redprints CFP `6080fc2` | 4.0.9 | `rspec`, 50 examples | 34 | 2,491 | 30.1 |
| Thinkroom `f7865d0` | 4.0.9 | `bin/rails test -v`, 833 tests, `PARALLEL_WORKERS=1` | 1,051 | 10,244 | 40.0 |

Thinkroom has 7 errors (`Slug has already been taken`, a fixture collision on its demo slug), the same without the gem;
its command exits 1. Pingcrm's system tests need Chrome 157: with 158 every test errors in teardown (`* is not a
valid URL` from Selenium's CDP reset).

The top inertia_rails line in every app is `renderer.rb:138` `extract_shared_keys` (Pingcrm 0.29% of request
objects, Redprints 0.19%, the others ≤ 0.08%). Every other inertia_rails line is ≤ 0.14% in every app, apart from
`ssr.rb:14` (React Starter Kit 0.28%, Thinkroom 0.07%), which reads `tmp/rails-vite.json` on every SSR render in
development and test only. Nothing in inertia-rails is a large share of a real request, so the leads were measured
on the renderer and resolver directly.

## Harness

[app.rb](../../bench/upstream/inertia_round2/app.rb) is a one-process Rails 8.1.4.1 app in production mode, with SSR
off. It shares `auth` and `flash` through lambdas, renders a 25-row contacts index with filters and links, and a
dashboard with a merge prop, two deferred groups and an optional prop next to plain props. Workloads: HTML visit,
Inertia XHR, partial reload, dashboard XHR and deferred reload, each as a whole request through the middleware stack
and as `action_*`, straight to the controller action with a loaded test session.
[alloc_lines.rb](../../bench/upstream/inertia_round2/alloc_lines.rb) lists objects per request by line.

**A/A control.** The whole-request workloads first replayed the boot request's session cookie and XSRF token. Their
instruction A/A was 1.0–1.4% with or without a fixed hash seed, and objects differed between processes. The cause
was the random encrypted cookie and token: each process decoded different bytes. The `action_*` workloads use a
constant header set, which brings the A/A to ≤ 0.08% with identical objects in every process. All numbers below are
`action_*` cells; the note is in [bench.md](../bench.md#control-request-inputs-captured-at-boot-2026-11-26).

## Leads

Interpreter instructions per request from `script/upstream-bench` (Ruby 4.0.9, `-n 200`, `--warmup 100`), base
3.24.0 measured twice. The run directories were scratch (`/tmp/ubH-*`, `/tmp/ubI-*`); INRP1's body run is kept.

| Lead | Change | `action_xhr` | `action_dashboard_xhr` | Objects (xhr / dashboard) | Result |
| --- | --- | ---: | ---: | --- | --- |
| prop-flags (INRP1) | the resolver asks prop types `deferred?`, `merge?`, `once?`, `fresh?`, `live?`, `rescue?` with `respond_to?` and a call instead of `Object#try` | −0.48% | −2.75% | 379 → 372 / 449 → 421 | built, [INRP1](../../bench/upstream/pr-queue/items/INRP1.md) |
| bound-config | `inertia_configuration` memoized per controller instance (the ivar joins `use_inertia_instance_props`' skip list) | −0.93% | −0.98% | 379 → 373 / 449 → 443 | below the bar |
| partial-headers | `parse_header` returns a frozen empty Array when the header is absent, instead of splitting `''` | −0.34% | not run | 379 → 375 / 449 → 445 | below the bar |
| shared-keys | `extract_shared_keys` uses `Symbol#name` and splits only dotted keys | −0.19% | −0.11% | 379 → 368 / 449 → 438 | below the bar |
| dotted-names | `DottedKeys#expand` uses `Symbol#name` to look for dots | −0.03% | −0.03% | 379 → 374 / 449 → 441 | below the bar |
| lazy-metadata | the resolver creates its nine metadata containers on first use | −0.21% | **+0.66%** | 379 → 370 / 449 → 445 | slower, dropped |
| all six together | | −1.86% | −4.12% | | |

A/A per cell was 0.00–0.08%. The bar is about 2% of a workload. Only prop-flags clears it, and only where a page has
several prop types. A page without any still resolves one when `errors` is sent: the renderer wraps it in an `always`
prop, which is the −0.48% of the contacts page. `errors` is sent only with `always_include_errors_hash = true` (as in
the harness) or after a redirect with errors; the default `nil` and `false` leave it out, so such a page resolves no
prop type at all (thermos-sol finding 2). Of the four profiled apps, only Thinkroom uses prop types (two
`optional`). Hackatime and Flow from the [Inertia and Chatwoot census](inertia-chatwoot-census.md) use `defer`,
`scroll` and `always`, so the dashboard workload stands in for them. The five others are not bundled: about 1.5% on
plain pages from four unrelated changes is still below the bar and would be hard to review (Thomas, 2026-11-26).

## Ownership (2026-11-26)

No open or closed PR or issue in inertiajs/inertia-rails names `extract_shared_keys`, `try(:deferred?)`,
`bind_controller`, `parse_header`, `build_metadata` or `DottedKeys`, or proposes these changes. Open PRs: #448
(skryukov, CI), #402 (bknoles, error flattening in `controller.rb`, not `inertia_configuration`), #391 and #167
(docs). #447 (skryukov, merged in 3.24.0) rewrote the resolver walk and kept the `try` calls; brodienguyen's #438 and
#439 changed JSON output and cached props. The maintainer branches pushed after 3.24.0 (`deenvelope-scaffolds`,
`fix/release-gem-propagation`) do not touch `props_resolver.rb`.

## INRP1

Branch `thomasklemm/prop-predicates-without-try` at
[`0362ffc`](https://github.com/thomasklemm/inertia-rails/commit/0362ffcb1fea17ce393c40b39efa940d28a1c875), one
commit on 3.24.0 (amends `f934e7c` after thermos-sol's first pass). Checks, differential and review are in
[the queue item](../../bench/upstream/pr-queue/items/INRP1.md).

The body's benchmark resolves a dashboard's props through `PropsResolver` alone
([INRP1_resolver.rb](../../bench/upstream/inertia_round2/INRP1_resolver.rb)): 118 → 90 objects, −13.8% interpreter and
−24.1% YJIT instructions (A/A ≤ 0.03%, JIT-flat; [body/INRP1-resolver](../../bench/upstream/inertia_round2/body/INRP1-resolver)),
44.1k → 54.0k i/s with YJIT (best of 9, A/A 0.40%, JIT-flat in 27 windows;
[body/INRP1-resolver-ips](../../bench/upstream/inertia_round2/body/INRP1-resolver-ips)). The whole-action numbers below,
measured on `f934e7c`, stay in the record; the amend changed only operand grouping in one predicate.

Body run [body/INRP1](../../bench/upstream/inertia_round2/body/INRP1) (`--warmup 3000 -n 200`, interpreter and YJIT):

| Workload | Objects | Interpreter | YJIT |
| --- | --- | ---: | ---: |
| `action_xhr` | 379 → 372 (YJIT 381 → 374) | inside the A/A (1.10%) | −0.7% (A/A 0.15%) |
| `action_dashboard_xhr` | 449 → 421 (YJIT 451 → 423) | −2.8% (A/A 0.01%) | −3.8% (A/A 0.44%) |

Every YJIT window was JIT-flat. With `--warmup 100` the same change measured −0.48% on `action_xhr` with a 0.07% A/A
(scratch run above). The 1.10% A/A at `--warmup 3000` is on `action_xhr` only; the dashboard's is 0.01% in the same
run. Live and old objects stay flat from 0 to 6,000 calls in one process, so nothing accumulates. 3,000 calls
allocate more than the 1,000,000-slot heap floor, so GC runs during the warm-up, and the measured window allocates into
a swept heap; that is a hypothesis, not checked.

The first benchmark-ips run ([body/INRP1-ips-loaded](../../bench/upstream/inertia_round2/body/INRP1-ips-loaded), 5
rounds) ran on core 1 while the Callgrind run used core 0. Rounds of one side differed by 15–25%, the dashboard's A/A
was 5.56% (no claim) and `action_xhr` showed +4.4% against a 0.48% instruction change. It is kept and not used. The
rerun with nothing else running is [body/INRP1-ips](../../bench/upstream/inertia_round2/body/INRP1-ips).

React Starter Kit's suite on the branch ([react-starter-kit/pp](../../bench/upstream/inertia_round2/react-starter-kit/pp),
A/A `base2` against `profiled`): inertia_rails lines 26.6 → 25.5 objects per request, out of 2,180; `lowrail-profile
compare` lists no change beyond its noise floor.
