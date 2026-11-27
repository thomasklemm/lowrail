---
id: INRP1
repo: inertiajs/inertia-rails
fork: thomasklemm/inertia-rails
kind: perf
area: Inertia props resolver, prop-type flags
reviewer: "skryukov (wrote the resolver walk in #447 and merged #442, which limited these questions to prop types)"
branch: thomasklemm/prop-predicates-without-try
head: "0362ffcb1fea17ce393c40b39efa940d28a1c875"
base: master
built_on: "5102d8dba7"
depends_on: []
stacked_on:
alternative_of:
impact: "Each try call on a prop type allocates one Array; how many a prop type gets depends on its kind and the visit (optional 4, once 8 on a full visit). A dashboard's props (errors, plain stats, merge, two deferred groups, optional) through PropsResolver: 118 to 90 objects, 44.1k to 54.0k i/s (benchmark-ips, YJIT, best of 9, A/A 0.40%), -13.8% interpreter and -24.1% YJIT instructions (JIT-flat). Whole dashboard XHR action: 451 to 423 objects, -2.8% interpreter, -3.8% YJIT instructions, +3.1% i/s. A page whose only prop type is the wrapped errors prop (sent with always_include_errors_hash true or after a redirect with errors): 7 objects, inside the A/A in time"
evidence: [bench/upstream/inertia_round2/INRP1-thermos-sol-confirm.tar.gz, bench/upstream/inertia_round2/INRP1-astra-evidence.tar.gz, bench/upstream/inertia_round2/body/INRP1-resolver, bench/upstream/inertia_round2/body/INRP1-resolver-ips, bench/upstream/inertia_round2/INRP1_resolver.rb, bench/upstream/inertia_round2/body/INRP1, bench/upstream/inertia_round2/body/INRP1-ips, bench/upstream/inertia_round2/body/INRP1-ips-loaded, bench/upstream/inertia_round2/pp_diff.rb, bench/upstream/inertia_round2/react-starter-kit/pp]
rank:
risky: false
state: ready
pr: 449
note: "2026-11-27 (revision for ready, T-01a21d28): head and master 5102d8dba7 unchanged, upstream CI green on all nine jobs. Astra nits applied verbatim to the body: the posted benchmark gets the archived script's frozen_string_literal line (without it the snippet allocates the charts group string per resolve, 119 to 91), and the ranking sentence becomes 'Pages with more prop types avoid more of these allocations.' Astra's one demonstrated difference needs a custom prop that overrides try or public_send itself; no documented hook or real consumer, no guard. thermos-sol approved the revised body on the same head; PR body updated to the text below and marked ready. 2026-11-26 (thermos-sol pass 1 applied, head 0362ffcb1f amends f934e7c3b2 on the same 5102d8dba7): F1 waits_for_partial_reload? keeps master's expression order (only try replaced), so a custom prop whose deferred? has side effects sees the same calls on a partial visit; the reviewer's stateful probe gives checked:2 on both trees. F2 body no longer says every render resolves a prop type (errors is shared automatically only with always_include_errors_hash true or session errors; explicit errors props also send it); same fix in inertia-round-2.md. F3 no per-prop-type count in body, commit message or impact. F4 Test plan limited to built-in prop types. F5 body shows the runnable resolver benchmark (INRP1_resolver.rb, bundler/inline), measured on its own: body/INRP1-resolver (Callgrind, objects) and body/INRP1-resolver-ips. Rechecked on 0362ffcb1f: CI matrix green on all eight cells again (/tmp/mx-pp2), rspec/rake test/rubocop green, pp_diff.rb byte-identical on 4,000 cases. 2026-11-26 (inertia round 2, docs/upstream/inertia-round-2.md): one commit on master 5102d8dba7 (v3.24.0), Thomas author and committer, no trailers, signed; pushed to the fork (no fork CI runs). Checks: rspec --tag ~type:generator and rake test green on Ruby 3.2.11/Rails 6.1, 7.0, 7.1; 3.3.14/7.2; 3.4.13/8.0 and 8.1; 4.0.9/8.1 and main 5a161379f5 (1211-1218 examples, 64 runs; 3.0 and 3.1 have no prebuilt Ruby in mise, so 6.1 and 7.0 ran on 3.2.11, as for INRV1); rubocop clean. Differential (pp_diff.rb): 4,000 generated prop sets, every prop type and option, plain values answering the flags, a custom BaseProp subclass with and without them, under full, partial only/except/reset, except_once and scroll-intent visits: output byte-identical on v3.24.0 and the branch (3,795 distinct outputs; every metadata kind present). No spec added: behaviour is unchanged and the existing specs fail when a flag is called without respond_to? (OptionalProp, AlwaysProp and the DottedKeys wrapper lack deferred?/once?/merge?). Objects in an app: React Starter Kit's suite, inertia_rails lines 26.6 to 25.5 objects per request (2,180 per request; lowrail-profile compare exit 0, no change beyond noise)."
ownership: {date: 2026-11-26, checked: ["open PRs naming resolve_prop_type, collect_deferred_metadata, collect_merge_metadata, collect_live_metadata, collect_once_metadata, waits_for_partial_reload?, excluded_by_once_cache? that change CHANGELOG.md, lib/inertia_rails/props_resolver.rb"], hits: []}
passes:
  - {reviewer: thermos-sol, orb: T-01a21829-c61f-721c-bfe1-1a5b23c67f4c, head: "f934e7c3b2dcd22404c62aa33fd613c9ea9be249", date: 2026-11-26, verdict: changes, open: "F1 reordered waits_for_partial_reload? (custom stateful deferred? differs on partial visits); F2 'every Inertia render' false (errors omitted by default); F3 five-to-seven Arrays false (optional 4, once 8); F4 Test plan overstates spec coverage (fresh? guard mutant passes all specs); F5 no runnable benchmark-ips script in body. All addressed on 0362ffcb1f. Artifact: https://ampcode.com/artifacts/inrp1-thermos-review-1c4add94-eb53-4288-8c06-1316316bcf18"}
  - {reviewer: thermos-sol, orb: T-01a21829-c61f-721c-bfe1-1a5b23c67f4c, head: "0362ffcb1fea17ce393c40b39efa940d28a1c875", date: 2026-11-26, verdict: nits, open: "Confirm pass: F1-F5 resolved; no must-fix. Optional local-record nit (explicit errors props also send errors) applied to the note and inertia-round-2.md. Reviewer reran rspec 1218/0, rake test 64/110, rubocop 214 files clean on Ruby 4.0.9/Rails 8.1.4.1; pp_diff byte-identical; 678 boundary cases and traces match; posted benchmark runs on both trees; raw resolver evidence verified (+22.66% i/s, A/A 0.40%, 118 to 90 objects, -13.84%/-24.06% instructions, 33 YJIT windows flat). Eight-cell matrix and timing cohorts not independently rerun. Artifact: https://ampcode.com/artifacts/inrp1-thermos-review-1c4add94-eb53-4288-8c06-1316316bcf18"}
  - {reviewer: astra, head: "0362ffcb1fea17ce393c40b39efa940d28a1c875", date: 2026-11-27, orb: T-01a21d34-2642-7263-916b-f103367b92cc, verdict: nits, open: "Both applied verbatim: frozen_string_literal restored in the posted benchmark (posted 119/91 versus archived 118/90 objects); ranking sentence replaced with 'Pages with more prop types avoid more of these allocations.' No code blocker; prior Thermos findings resolved. Custom try/public_send interception changes behaviour, but no documented hook or actual consumer was found; flag overrides/delegation/stateful visits match. Both trees pass RSpec 1218/0, rake test 64/110, rubocop 214 clean on Ruby 4.0.10/Rails 8.1.4.1; 4000 builder and 10894 non-interception adversarial cases match. inertia_rails 1,251 stars, 2.76M downloads, 3.24.0 on 2026-11-26. Receipts: inertia_round2/INRP1-astra-evidence.tar.gz"}
  - {reviewer: thermos-sol, head: "0362ffcb1fea17ce393c40b39efa940d28a1c875", date: 2026-11-27, orb: "T-01a21d34-07d6-72b5-adf5-2542f9808e5b", verdict: approve, open: "none; text-only whole-body confirm after both Astra edits. Posted snippet runs on master/head; replayed 118/90 objects in interpreter and YJIT with base A/A; removing the magic comment reproduces 119/91. Archived 44.1k/54.0k ips (+22.66%, A/A 0.40%) and body claims verified; no new suite or controlled timing cohort. Receipts: inertia_round2/INRP1-thermos-sol-confirm.tar.gz"}
---

# Ask prop types for their flags without `try`

## Summary

The props resolver asks each prop type it reaches whether it is deferred, merges, is a once prop (and fresh), is live or rescues errors, through `Object#try`, and each `try` call allocates an Array for its arguments. Since #442 only prop types are asked, so `respond_to?` followed by the call gives the same answers, including for prop types that don't define a flag, such as `OptionalProp`, which has no `deferred?`.

Pages with more prop types avoid more of these allocations. Resolving a dashboard's props with Ruby 4.0 and YJIT, with the script below:

| | master | this PR |
| --- | ---: | ---: |
| Iterations per second (benchmark-ips) | 44.1k | 54.0k |
| Objects per resolve | 118 | 90 |

<details>
<summary>Benchmark</summary>

Run with `ruby --yjit bench.rb` in an inertia-rails checkout.

```ruby
# frozen_string_literal: true

require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "rails"
  gem "inertia_rails", path: "."
  gem "benchmark-ips"
end
require "rails"
require "action_controller/railtie"
require "inertia_rails"

rows = Array.new(10) { |i| { id: i, name: "Contact #{i}" } }
evaluator = InertiaRails::PropEvaluator.new(Object.new)
props = -> {
  {
    errors: InertiaRails.always { {} },
    stats: { users: 1200, revenue: 34_500, orders: 87 },
    recent: InertiaRails.merge { rows },
    activity: InertiaRails.defer { rows },
    chart: InertiaRails.defer(group: "charts") { [1, 2, 3] },
    archived: InertiaRails.optional { [] },
  }
}

Benchmark.ips do |x|
  x.report("dashboard props") { InertiaRails::PropsResolver.new(props.(), evaluator: evaluator).resolve }
end
```

</details>

## Test plan

The existing specs cover each flag on the built-in prop types, including the ones that don't define it. The resolved props and metadata are the same as on master.

## Checklist

- [ ] Tests added or updated
- [x] `CHANGELOG.md` updated (for user-facing changes)

## For Thomas

Body numbers: bench/upstream/inertia_round2/body/INRP1-resolver-ips (benchmark-ips, best base 43,971 / 44,146, candidate 54,042, A/A 0.40%) and body/INRP1-resolver (objects 118 to 90 in interpreter and YJIT; instructions -13.8% / -24.1%). The body script is INRP1_resolver.rb without its UpstreamBench branch and with INERTIA_RAILS fixed to ".". Whole-action numbers (body/INRP1, body/INRP1-ips) stay in the record; the leads table and the below-bar leads are in docs/upstream/inertia-round-2.md.
