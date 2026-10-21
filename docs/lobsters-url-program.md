# Lobsters whole fixed URL programs — exploration

Branch-only follow-up to [the large-app profiles](hotspots-large-apps.md).
Bet G owns middleware/notifications/callbacks, not URL generation. This study
does not touch the quarantined `route/path` pass or install a production unit.
No Callgrind, app patches, configuration overlays or upstream posts.

## First result: allocation lead, not a speed win

**Promote only to a guarded follow-up.** The unguarded program saves objects
with exact output; it has not paid production guards. The coordinator approved
guarding it, probing mid-request mutations and rerunning this exact screen.
Only a retained allocation win on **both** routes permits one interpreter-Ir
cohort. Main and defaults remain untouched.

| Route | Median objects off-A / off-B / on | Saved/request | Native Δ (diagnostic) | Max A/A round spread |
|---|---:|---:|---:|---:|
| `/newest` | 14,306 / 14,306 / 14,141 | 165 (1.153%) | −3.006% [−7.572, −0.470] | 2.373% |
| `/hottest` | 14,739 / 14,739 / 13,939 | 800 (5.428%) | −5.612% [−9.237, −3.387] | 4.583% |

Both `clear_wall_win` flags are **false**; wall is neither a win nor a kill.
All 36 measured-worker seed/route responses match within their rounds across
off-A/off-B/on (12 off/on seed/route comparisons, plus off/off). Exact checks
include status, full body and all headers with zero declared-entropy errors.
Separate coverage shows **91 / 50 hits per request**, no fallbacks and zero
off-arm hits. `/hottest` is JSON but calls root URLs; it is not a no-hit control.

The 500/600 screen took 504.87 s. Natural per-request allocations are not
literally constant: `/newest` off-A range 14,297–14,325, on 14,132–14,160;
`/hottest` off-A 14,739–22,256, on 13,939–13,988. Keep those spikes; the median
savings are not fabricated fixed counts. GC time/request off-A/on was
0.696/0.676 ms and 0.823/0.766 ms, also diagnostic; on RSS was slightly higher
(170,090 vs 169,709 KiB and 172,132 vs 170,920 KiB). No hardware instruction
counter is available (`perf_event_open` ENOENT). No Callgrind was run.

After switching to the **shared** validator at
[`bfc682b`](https://github.com/thomasklemm/lowrail/commit/bfc682b97dbebdb1082d4f54e8ed426e7ff27c27),
a correctness-only rerun across `/newest`, `/active`, `/recent`, `/hottest`
passed all 72 measured-worker seed/route responses. This used 1 warmup and
1 sample: its timings are **not** performance evidence. A separate real-boot
probe passed 720 public path/URL-helper pairs (values/classes/encodings/frozen
state, errors, URL-options/predicate order), eight controlled page/trace pairs
and fresh-output mutation. These finite tests are not mutation certification.

[Machine export](lobsters-url-program-results.json) retains every screen
sample/worker, A/A and on/off interval, GC/JIT/boot/RSS observation and pin,
the shared-validator rerun and finite-check log. The original frozen screen's
now-removed local adapter/policy are archived there, not silently substituted
with the shared validator. The program source stayed unchanged across both.

## Question and specimen

Can a complete fixed-route URL program remove enough framework interpretation
to justify the eventual exactness certificate? Lobsters routing accounted for
6.18% of CPU samples and 8.74% of sampled allocations across the earlier six
GETs. Those are source-area ceilings, **not this specimen's removable budget**.

[`lobsters_url_program.rb`](../bench/experiments/lobsters_url_program.rb)
observes naturally invoked framework-generated helper objects with a temporary
TracePoint. Discovery runs in all arms before warmup. It replaces only
zero-required-segment, unconstrained literal-path programs. The dynamic,
constrained `tag_path` and `domain_path` programs remain stock. The original
public generated helpers still perform argument/option extraction.

The replacement allocates fresh paths, keeps live `url_options`, script-name
completion, trailing slashes and Rails' URL strategy. It removes parameter-Hash
construction/Journey formatting for zero-argument optimized paths, and the
generic generator/formatter for root URLs with only host/protocol options on
the empty-options helper proxy. Unknown options/arguments use the original
program. A false optimization predicate resumes the generic continuation
without evaluating the predicate again. Root-proxy refusals reuse the already
read controller options rather than calling `url_options` twice.

Both off arms discover/compile the same objects and then **remove** the
singleton override; normal class dispatch resumes. The on arm installs an
ordinary singleton method, not a per-call branch selecting off/on. Per-hit
counters exist only in separate coverage workers. Saved program references
and helper instance variables remain in all arms; this is not a zero-setup
baseline or production delivery design.

## Cheap screen protocol

The original measured screen used the shared, **unchanged** `script/screen` from
[`ff46f99`](https://github.com/thomasklemm/lowrail/commit/ff46f99517f6a1fcb9dfc3ab3e132616be100457),
in an isolated worktree. It is not merged into this branch. Ruby 4.0.7 startup
YJIT, Rails 8.1.4, production, CPU 2; natural GC and production logging remain
unchanged. Build a zero-unit artifact through `gem/exe/lowrail-compile` with
`rails_env: production`, `certification_jit: yjit`, empty files/units, and actual
startup YJIT; do not edit a manifest's mode field.

The first screen uses `/newest` and `/hottest`, three `off_a/on/off_b` rounds,
**500 warmups per route and 600 measured requests per route per worker**.
Three additional coverage workers use the same warmup and ten measured
requests per route. Keep all rounds, raw samples, JIT counters, allocations,
GC counts/time, boot/setup and RSS. The shared default 20/30 settings had
20–27% A/A spread in Bet A; they are not adequate for a small route lever.
An effect inside this run's A/A envelope is **inconclusive, not a win or kill**.
The screen's clear-wall-win rule requires the entire effect interval to beat
three times the largest A/A round spread or interval bound.

### Exact-output companion, not normalized output

[`lobsters_url_screen.rb`](../bench/experiments/lobsters_url_screen.rb) now
delegates to A's `bench/experiments/lobsters_native_validation.rb` and
`fixtures/corpus/lobsters-native-entropy.json` at bfc682b, loaded from the
shared tool's worktree. There is no duplicate policy on this branch. The
shared policy pins this app's source, original app lock, dependency overlay
and effective lock, Ruby and actual runtime sources (this bundle uses a
different Rack than the blog). It reuses the existing entropy implementation
and four declared request-random sites, without widening their definitions.
The original frozen screen used the same mechanism plus the blog's existing
unused job-ID site; its exact adapter/policy remain in the export.

Only untimed validation requests enter the companion: seeds 0/1, fixed
request-ID input, known CSRF/session/cookie entropy, the two Rack runtime
reads and a declared wall-clock epoch. Actual status, whole body and **all**
headers are hashed and compared across both off arms and on within each
round. Undeclared entropy rejects validation. The timed requests never enter
the companion and retain actual random inputs/clocks. Its inactive wrappers
remain installed symmetrically in all arms. This is not production security
certification or an assertion that raw entropy-bearing responses are equal.

## Fixture and reproduction

Use the dependency-only `fixtures/corpus/lobsters.Gemfile{,.lock}` from this
branch, ruby/ruby-bench
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
`benchmarks/lobsters`. The app/config files must stay unchanged. The external
Gemfile resolves Rails 8.1.4/minitest 5.27.0, not a code overlay. The shipped
database SHA256 is
`d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
Copy it to the private seed's `primary.sqlite3`; the previously boot-prepared
copy used here is
`b90816703504429b1926c97c50a960ce9a29235b7543f3159fbc441ed1e9406b`.
Do not transfer or commit the database. These are anonymous public lists,
not ruby-bench's historical authenticated benchmark vector.

The shared tool requires the app inside **its** `.corpus`; create a second
worktree of the exact ruby-bench pin there. Its source/lock bytes must match
the policy. For new runs use the shared tool at **bfc682b**. A private JSON
config supplies absolute `app`, `seed`, `artifact`, `gemfile`, headers
`{"HTTP_X_REQUEST_ID":"lowrail-url-screen"}`, and `exploration_sources`
containing this branch's program plus the shared validation helper, entropy
implementation and policy. The setup itself is pinned automatically. Then,
from this branch (always a new output directory):

```sh
mise exec ruby@4.0.7 -- ruby "$TOOLS/script/screen" "$APP" /newest /hottest \
  --config "$PRIVATE/config.json" --output "$PRIVATE/screen-v1" \
  --exploration-setup "$PWD/bench/experiments/lobsters_url_screen.rb" \
  --warmup 500 --samples 600
```

## Exactness boundary before a real pass

Finite matching outputs do **not** certify mid-request mutation, arbitrary
helper receivers or unsupported route shapes. No guard cost is included.
Promotion needs route/default/requirements/format generations, actual helper
and primitive method/body/visibility facts, and the live receiver's dispatch.
After `url_options` or another app-evaluating boundary, recertify everything
the remainder skips; a route formatter replaced there cannot be ignored.
Preserve already evaluated values on fallback, script/mount order, error
behavior, fresh mutable results and escaped Method handles. Dynamic arguments
add once-only `to_param`/constraint/default/escape continuations, not merely a
type guard at entry. Route reloads, singleton changes, suppressed hooks,
custom defaults/format/query/anchor/recall and unknown helper proxies must
deopt or refuse. The old quarantined implementation supplies counterexamples,
not an admission certificate.

An upstream Rails route-generation improvement remains a candidate only;
the owner has a separate Rails thread. No upstream PR is opened here.
