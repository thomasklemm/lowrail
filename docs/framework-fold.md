# Bet G: framework folding

Exploration branch `thomasklemm/framework-fold`; Ruby 4.0.7 / Rails 8.1.4.
No production pass, application/configuration patch, default change, or
Callgrind run. Exactness is the first screen; a failed exactness screen does
not advance to allocations or native wall time.

## Scope and ownership

G owns middleware/no-op folding, Notifications, generic ActiveSupport callback
mechanics, and request-entry invalidation. Bet C owns Lobsters fixed URL
generation. Bet E owns action-specific filter selection and per-action spine;
it must use stock callback execution rather than depend on an unbuilt G API.

The profiles at `origin/thomasklemm/profile-guided-hotspots` (07558fd) are
selection evidence, not removable budgets. In Fizzy / Campfire r81 / Lobsters:

| Candidate | CPU share before (%) | Allocations saved/request | Native YJIT wall delta | Exactness / verdict |
|---|---:|---:|---:|---|
| Middleware/request work | 4.30 / 8.94 / 8.30 | Not measured | Not measured | Boot-nil policy elision fails; kill that elision, park general composition |
| Notifications/instrumentation | 1.46 / 1.26 / 0.56 | Not measured | Not measured | Entry-only absent-event folding fails temporary subscriptions; kill |
| Generic callback machinery | 0.38 / 0.78 / 0.39 | Not measured | Not measured | Park; small entire-engine budget, not controller-only removable work |
| Parameter handling | 0.18 / 0.07 / 0.13 | Not measured | Not measured | Park; live input parsing is not boot-fixed |
| Journey route recognition | Not isolated | Not measured | Not measured | Park; routing bucket includes URL generation, not a recognition budget |
| CurrentAttributes / executor / reloader | Not isolated | Not measured | Not measured | Park; reset bodies/default Procs and completion hooks remain live |

ETag digest updates alone occupy 1.37 / 5.76 / 3.24% CPU respectively.
Those are live response bytes; composing the booted stack cannot remove their
hashing. Do not call all middleware self time a dispatch opportunity.

## First exactness screen

[`framework_fold.rb`](../bench/experiments/framework_fold.rb) tests two
optimistic request-entry-only specimens against stock Rails with independent
off-A/off-B controls. It is never installed in the corpus app.

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

Corpus boot screens and source/lock pins are recorded below when complete.
No wall or allocation saving is inferred from a specimen that fails exactness.
