# Bet G: framework folding

Exploration branch `thomasklemm/framework-fold`; Ruby 4.0.7 / Rails 8.1.4.
No production pass, application/configuration patch, default change, or
Callgrind run. Exactness is the first screen; a failed exactness screen does
not advance to allocations or native wall time.

## Scope and ownership

G owns middleware/no-op folding, Notifications, generic ActiveSupport callback
mechanics, and request-entry invalidation. Bet C owns Lobsters fixed URL
generation. Bet E owns action-specific filter selection and per-action spine;
its first screen uses stock callback execution, not an unbuilt G API.

The profiles at `origin/thomasklemm/profile-guided-hotspots`
([07558fd](https://github.com/thomasklemm/lowrail/commit/07558fd64c64904ba97cd61a622ff9feddd56c63)) are
selection evidence, not removable budgets. In Fizzy / Campfire r81 / Lobsters:

| Candidate | CPU share before (%) | Allocations saved/request | Native YJIT wall delta | Exactness / verdict |
|---|---:|---:|---:|---|
| Middleware/request work | 4.30 / 8.94 / 8.30 | Not measured | Not measured | Boot-nil policy elision fails; kill that elision, park general composition |
| Notifications/instrumentation | 1.46 / 1.26 / 0.56 | Not measured | Not measured | Entry-only absent-event folding fails temporary subscriptions; kill |
| Generic callback machinery | 0.38 / 0.78 / 0.39 | Not measured | Not measured | Park; small entire-engine budget, not controller-only removable work |
| Parameter handling | 0.18 / 0.07 / 0.13 | Not measured | Not measured | Park; live input parsing is not boot-fixed |
| Request/response object setup | Not isolated from middleware | Not measured | Not measured | Park; live environment/response state is not a boot constant |
| Journey route recognition | Not isolated | Not measured | Not measured | Park; routing bucket includes URL generation, not a recognition budget |
| CurrentAttributes / executor / reloader | Not isolated | Not measured | Not measured | Park; reset bodies/default Procs and completion hooks remain live |

The large-app export does not include blog; no new blog CPU share is invented.
“Not measured” is **not zero**. These candidates failed or were parked before
the allocation/wall stage, as accepted by the coordinator. The table is not
a four-app throughput comparison.

ETag digest updates alone occupy 1.37 / 5.76 / 3.24% CPU respectively.
Those are live response bytes; composing the booted stack cannot remove their
hashing. Do not call all middleware self time a dispatch opportunity.

## First exactness screen

[`framework_fold.rb`](../bench/experiments/framework_fold.rb) tests two
optimistic request-entry-only specimens against stock Rails with independent
off-A/off-B controls. It is never installed in the corpus app. Each arm uses
a fresh real Fanout, temporarily selected through the public notifier setter,
and an isolated real CSP middleware with a downstream Rack callable. The
original application notifier is restored. These are concrete admissible
framework inputs, **not a claim that any corpus route currently uses them**.

1. The actual notifier has no listeners for a name at entry. A normal
   `Notifications.subscribed` block temporarily subscribes before that event
   is instrumented. Stock returns the body result **and delivers payload 37**;
   direct yield returns the same result but drops the event. After the
   request the subscription is gone: even an exit fingerprint would miss it.
2. A policy middleware's methods, downstream object, boot policy and entry
   environment are unchanged. Downstream code sets the normal request-local
   CSP. Stock adds `content-security-policy: default-src 'none'`; skipping
   the supposedly inert middleware loses this security header. No method,
   callback or global configuration mutation is needed.

These do not prove all framework specialization impossible. They disprove
the specific assumption that one request-entry snapshot authorizes removing
later dynamic observations. A subscriber epoch checked only at entry cannot
repair a current request. Immediate deoptimization at every mutation, live
boundary checks, or a separately accepted sealed contract are different bets.
Request-local policy selection remains live even in sealed mode.

```sh
mise exec ruby@4.0.7 -- ruby --yjit \
  bench/experiments/framework_fold.rb --framework-only
```

## Four pinned production boots

All four booted with startup YJIT, Rails 8.1.4 and Lowrail off. The probe then
ran the same isolated framework inputs after each boot: **8 witnesses,
8 identical off-A/off-B controls, 8 divergent on results**. All 24 arms keep
the body result; all 12 notification arms evaluate the body exactly once.
Both middleware methods/downstream facts still match in every CSP arm.

| App | Source / dependency input | Rack | Result |
|---|---|---:|---|
| Blog | Retained original archive SHA256 `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`; existing production entropy policy validates source + lock | 3.2.7 | Both kills reproduced |
| Campfire r81 | `script/corpus campfire-r81`; [02023b0](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa) + checked-in dependency-only overlay | 3.2.0 | Both kills reproduced |
| Fizzy | `script/corpus fizzy`; [6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9) + checked-in dependency-only overlay | 3.2.7 | Both kills reproduced |
| Lobsters | [ruby-bench 351a39b](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716), C's external Rails 8.1.4 wrapper/lock at 07558fd; original shipped DB | 2.2.24 | Both kills reproduced |

Source and effective lock digests match before/after every final boot.
Lobsters' shipped database still hashes to
`d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
No fixture preparation, DB query, login, real app request or own suite is
needed by these isolated probes; no DB-state equivalence or app-support claim
follows. Source/lock hashes, observed modes, all arms and actual differences
are in [the machine-readable export](framework-fold-results.json).

To repeat after the normal frozen bundle install, run from each app directory:

```sh
RAILS_ENV=production RACK_ENV=production LOWRAIL=0 \
  SECRET_KEY_BASE_DUMMY=1 SKIP_TELEMETRY=1 RAILS_LOG_LEVEL=fatal \
  mise exec ruby@4.0.7 -- bundle exec ruby --yjit \
  /absolute/lowrail/bench/experiments/framework_fold.rb --boot /absolute/result.json
```

For Lobsters also set `BUNDLE_GEMFILE` to the external wrapper from C, not its
historical app Gemfile. The first Lobsters probe refused its own stock-header
assertion because the probe assumed lowercase Rack 3 header names. Using
Rails' actual `CONTENT_SECURITY_POLICY` constant fixes the observer for Rack 2;
no application/framework behavior or header normalization was changed. All
four final boots use that same corrected probe hash.

## Bounded close-out: no further eligible slice found

The coordinator accepted both exactness kills and limited further work to
at most one remaining framework slice with roughly **≥2% CPU** in C and no
epoch/boot-state-immutability assumption. Grouping the in-scope middleware,
notifications, callbacks and params CPU leaves by source file finds just
**Rack ETag** above that threshold: **5.9453% Campfire / 3.3722% Lobsters**.
The corresponding digest-update native leaves alone are 5.7607 / 3.2425%.
Rack hashes live nonempty response parts; the body, iteration and digest
operations are not boot-invariant work. Eliminating it would change ETags;
memoizing it would be a response-cache bet, not this framework-fold bet.
The residual Ruby scaffold is not an independently established ≥2% budget.

No qualifying next slice was found; **stop**, rather than relabel live hashing
as removable work or add another speculative epoch. URL generation and
action-specific callback work remain with C/E. There is no fixed-chain API
from G. General middleware composition, request setup and resets stay parked,
not proven impossible. No wins, no production pass, no main changes.

The shared `script/screen` hook became available at
[ff46f99](https://github.com/thomasklemm/lowrail/commit/ff46f99517f6a1fcb9dfc3ab3e132616be100457).
It was not invoked: the coordinator explicitly stopped both specimens at
exactness. Allocations, native wall/A/A, GC/RSS and Callgrind prices were not
run, and no apparent speed from incorrect code is credited. Any future
correct candidate should use its `exploration_setup`/`validation_request`
hooks rather than another measurement harness.
