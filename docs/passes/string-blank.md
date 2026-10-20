# String blank backport: stop at the guardless design gate

2026-10-20. **No pass implemented, no request cohort started.** The positive
[micro price](next-levers.md) prompted a proposed guarded-tier
`backport/string_blank`: deliver the Rails-main body as the original
`String#blank?` definition in Active Support 8.1.4's `object/blank.rb` ISeq,
through the existing `load_iseq` seam, with no Lowrail wrapper or hot guard.
The exact candidate is Rails
[`3f0b6751`](https://github.com/rails/rails/commit/3f0b675158e8284241bb1213c00375bc1fb9c52f),
including the ASCII fast paths from
[`7234e94d`](https://github.com/rails/rails/commit/7234e94d0b007055126a3fd55115db8e3beb8568)
and [`7ef6a408`](https://github.com/rails/rails/commit/7ef6a40816e3765e20e5ee8c5c1d586983935da4).

This would preserve ordinary VM dispatch after **redefining `blank?`
itself**. It does not preserve the dependencies and observations of the old
body. An upstream API implementation change can be appropriate for a Rails
upgrade without being an exact Lowrail replacement relative to 8.1.4.

## Fact inventory before implementation

| Fact / boundary | Exact without another check? |
|---|---|
| Installed gem/version/body, original compiler options, actual input ISeq and delivery source | Build/source allowlists and the existing loader fingerprint can certify this finite body. They cannot certify its future callees. Missing/stale/unknown build must remain a no-op. |
| Later replacement/removal/prepend of `String#blank?`, including suppressed hooks | Yes for ordinary dispatch: VM method lookup selects the app's new method. Warmed direct-redefinition probe passes. Saved old handles and tracing remain separate delivery observations, not removed by a source allowlist. |
| `empty?` | Both bodies call it first and preserve its truthiness/early return. It may run app code before any later check; do not assume it is native or nonmutating. |
| Actual receiver `ascii_only?` and `getbyte` | **No.** Newly observable dynamic calls, including subclasses/singletons/private methods and exceptions. Replacing the containing method's ISeq does not make these native. Captured native calls would instead bypass overrides; that is another behavior change. |
| `String::BLANK_RE` | **No.** The regexp literal is frozen, but its constant binding is not. Both definitions resolve it live; only the old body does so for nonempty ASCII. Delivering it in the same file does not prohibit later replacement. |
| `Regexp#match?` and regexp policy | **No.** A frozen regexp does not freeze its class method table. The old ASCII path invokes it; the new path does not. Wrappers/events and exceptions are observable. Global/per-regexp timeout policy also needs consideration; the probe does not claim a quantified timeout difference. |
| `String::ENCODED_BLANKS`, `Concurrent::Map#[]`, default block | Mutable map, not a frozen constant value. Non-ASCII fallback retains the live lookup; it depends on current `encoding` dispatch and encoding compatibility errors. No certificate may replace it by a boot snapshot. |
| `Regexp.new`, `BLANK_RE.source/options`, String `encode`, `Regexp::FIXEDENCODING`, `Encoding::CompatibilityError` | Live dependencies of the retained map/default/rescue path. Same source establishes the initial definitions, not immutability. Callback changes before/during that path must remain observable. |
| Integer comparisons, equality and `+` in the new byte loop | New Ruby method-dispatch dependencies. Native results alone do not certify unmodified Integer operations. |
| Invalid encodings, Unicode whitespace and String storage | Finite native-value differential evidence is green below; it does not close overrides, callbacks, tracing or the mutable facts above. |

An entry-only native-method or constant check is insufficient if `empty?`
or another callback changes a later fact. A full guard/continuation design
would be a different candidate and must first pay for all these boundaries.
There is **no guardless exact price** to take to request measurement here.

## Executed differential gate

The reproducible [audit/fuzzer](../../bench/string_blank_backport_audit.rb)
reads the two SHA-256-allowlisted sources, substitutes **only** the method
definition in the old file, then compiles/evaluates that complete ISeq in a
disposable process. The old UnboundMethod and new definition therefore share
the real String lexical constants. This is not a production installer or a
subclass-only specimen. `bind_call` is used for comparison, not pricing.

On **Ruby 4.0.7 and Ruby 4.1.0-preview1**, each run compares **236,416** cases
with seed 41231: 105,472 single-byte cases, 7,300 Unicode/boundary cases,
123,600 seeded byte strings and 44 long cases. All **103** bundled encodings,
including dummy encodings and invalid sequences, are considered; transcode
failures are not silently turned into another encoding. Each case tests
frozen/unfrozen String and an ordinary String subclass. Long cases include
one million ASCII bytes and 100,000 Unicode spaces. **Zero ordinary-value
or exception differences** occur on either target.

The installed-body Rails 8.1.4 ActiveSupport
`test/core_ext/object/blank_test.rb` also passes old/new: **4 tests / 433
assertions / 0 failures / 0 errors / 0 skips** per arm on 4.0.7. These tests
do not exercise the failing extension boundaries:

| Warmed public probe | 8.1.4 | Main body |
|---|---|---|
| Suppress subclass `method_added`, define `ascii_only? = true`, Unicode space | true | false |
| Suppress subclass `method_added`, define `getbyte(*) = 120`, ASCII space | true | false |
| New `ascii_only?` dispatch raises on `"x"` | false | RuntimeError |
| Replace `String::BLANK_RE` with `/\Anever\z/`, ASCII space | false | true |
| Suppress `Regexp.method_added`, observe `Regexp#match?`, `"x"` | false + one event | false + zero events |
| Suppress `String.method_added`, redefine `blank?` after two warm calls | new method's sentinel | identical sentinel |

The first five differences reproduce on **both** Ruby targets. The last
control validates the proposed dispatch argument, but cannot certify the
other five. Decision: **refuse the guardless backport**, retain the upstream
upgrade recommendation, and do not run its conditionally authorized app
verify/request cohorts. No default or runtime selection changes follow.

## Subsequent decision: sealed candidate #3

The owner separately authorized a sealed design, **after** the six additional
sealed-only quarantines, the central production TracePoint fix and publication
of generic sealed eligibility. Its show micro budget is −118,626 interpreter /
−155,248 YJIT Ir, zero objects, approximately 1.4% of interpreter request work.
This is neither a request measurement nor a default promotion.

Post-seal method mutation is SEAL001; constant rebinding and mutable framework
tables are SEAL001/008; delivery/trace observations require SEAL009 acceptance.
Existing subclass overrides are not violations that can be excused by that
contract. At seal time inventory effective owners/bodies/visibility of
`empty?`, `ascii_only?`, `getbyte` and `match?` across String subclasses and
existing instance singleton overrides, as well as the native String/Regexp/
Integer dependencies and original constants. Refuse on an existing override
or an unproved receiver boundary. An ObjectSpace/subclass scan alone must not
be described as proving unseen future instances; preserve an original-only
input path unless the contract actually certifies them. Encoding-map cache
population remains live and needs an explicit policy, not an indiscriminate
freeze of that working framework cache. The [main report](next-levers.md#sealed-candidate-3-not-a-guardless-backport)
records the sequence; no new delivery tier is proposed.

Reproduce with the pinned main file downloaded to a scratch path:

```sh
mise exec -- ruby bench/string_blank_backport_audit.rb /tmp/upstream-blank.rb
mise exec ruby@4.1.0-preview1 -- ruby bench/string_blank_backport_audit.rb /tmp/upstream-blank.rb
# Prepared by script/rails-suite --prepare; set its actual Gemfile path:
BUNDLE_GEMFILE=/tmp/next-levers/rails-l3/Gemfile mise exec -- bundle exec ruby \
  -I.corpus/rails/activesupport/test .corpus/rails/activesupport/test/core_ext/object/blank_test.rb
BLANK_FRAMEWORK_TEST="$PWD/.corpus/rails/activesupport/test/core_ext/object/blank_test.rb" \
  BUNDLE_GEMFILE=/tmp/next-levers/rails-l3/Gemfile mise exec -- bundle exec ruby \
  -I.corpus/rails/activesupport/test bench/string_blank_backport_audit.rb /tmp/upstream-blank.rb
```

The script prints `guardless_exact: false`; successful execution is not a
passing exactness certificate. The [pricing report](next-levers.md) remains
a positive native-input micro, not an exact guarded/default request win.
