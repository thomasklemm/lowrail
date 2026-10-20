# Guard cost, unsafe ceilings and exact speculation

Rails 8.1 is primary; Campfire's Rails 8.2 alpha is supplementary. Experiments
use Ruby 4.0.7. Unsafe measurements are not support claims or permission to
deploy an unchecked specialization. Exact semantics or refusal remains the
contract; passing a finite suite does not close an invalidation hole.

## Monomorphic receiver slot

The receiver cache already validates method facts lazily after invalidation.
The historical approximately 663 Ir/check is cached dispatch, **not** walking
all facts on every call. `K[id]` adds a monomorphic receiver-class slot before
the existing polymorphic `V[id]` hash:

```ruby
self.class.equal?(::Lowrail::K[id]) || ::Lowrail.ok?(id, self.class)
```

`ok?` publishes only successful validations. Every existing method invalidation
withdraws K together with V. Installation initializes slots through the largest
unit ID, including gaps, to a private frozen non-class sentinel. An overridden
`self.class` returning nil therefore cannot match an unchecked slot. Statistics
mode withdraws all slots, including on late activation, and never publishes a
class: every counted call still goes through the existing counting path.
The regression also covers a different validated class returned by `self.class`,
invalidation, fallback, restoration and late statistics.

This is a dispatch optimization with **the same known invalidation limitations
as V**, not a claim that today's hooks cover arbitrary Ruby mutation.

### Integration gates

Before/after `lowrail verify`, all opt-ins, fixed suite seed 41231, serial test
workers and full SQL tracing: per-test outcomes and both complete per-unit maps
are identical on all five apps. Each verify also compares its on/off SQL trace.

| App | Outcomes | Hits | Fallbacks |
|---|---:|---:|---:|
| real-blog-r4 | 21 | 99 | 0 |
| PingCRM | 26 | 451 | 0 |
| React Starter Kit | 36 | 149 | 0 |
| Redprints CFP | 50 | 288 | 0 |
| Campfire (supplementary) | 634 | 10,918 | 3,496 |

Rails 8.1.4 L3, archived/current runtime: Active Record **9,240 outcomes**
(9,238 identities, including parameterized multiplicities), Action View
**2,747 + 242 + 173**. All outcomes and per-unit hit/fallback maps match.
AR completes 68,857 hits / 11,616 fallbacks; AV/AR integration completes 118
hits. The other two AV groups have zero installed-pass hits, not coverage of
a source route/view lowering. Gem tests: 91 tests / 1,557 assertions, no
failures/errors, six optional skips. Rust: 31 unit and three integration tests.

`lowrail bench real-blog-r4 --pass default --path /articles`, six independent
fixed-heap interpreter rounds, 50 warmups, N=0/50 total and GC-excluded windows,
unchanged app and production default builds:

| Runtime | Default total Ir/request | Versus no setup, % [95% CI] | A/A |
|---|---:|---:|---|
| Before K | 8,586,225 | −5.880 [−5.903, −5.825] | pass |
| K | 8,574,492 | −6.011 [−6.033, −5.967] | **reject** |

K's total off/off CI is **[+0.002, +0.064]%**, GC-excluded
**[+0.003, +0.053]%**: neither includes zero. Both heap controls pass. The
roughly 0.13 percentage-point difference is descriptive only; **no accepted
request improvement or native YJIT speed claim** follows. No retry or widened
tolerance was used. Both coverage probes complete ten routes/request.
Private raw evidence: `/tmp/speculation-k-blog-{before,after}`,
`.lowrail/speculation-{before,after}` and `.lowrail/k-rails-{before,after}`.

The unsafe ceiling, break attribution, micro-cost breakdown and residual
invalidation work are separate experiments, not part of the K change.
