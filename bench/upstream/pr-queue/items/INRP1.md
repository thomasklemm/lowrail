---
id: INRP1
repo: inertiajs/inertia-rails
fork: thomasklemm/inertia-rails
kind: perf
area: Inertia props resolver, prop-type flags
reviewer: "skryukov (wrote the resolver walk in #447 and merged #442, which limited these questions to prop types)"
branch: thomasklemm/prop-predicates-without-try
head: "f934e7c3b2dcd22404c62aa33fd613c9ea9be249"
base: master
built_on: "5102d8dba7"
depends_on: []
stacked_on:
alternative_of:
impact: "Every prop type the resolver reaches saves one Array per flag question (5-7 per prop type). Dashboard XHR action with five prop types: 451 to 423 objects, +3.1% benchmark-ips (YJIT, best of 9, A/A 1.50%), -3.8% YJIT and -2.8% interpreter instructions (JIT-flat; A/A 0.44%, 0.01%). A page whose only prop type is the wrapped errors prop: 7 objects, -0.7% YJIT instructions, time and interpreter instructions inside the A/A (-0.48% at --warmup 100, A/A 0.07%)"
evidence: [bench/upstream/inertia_round2/body/INRP1, bench/upstream/inertia_round2/body/INRP1-ips, bench/upstream/inertia_round2/body/INRP1-ips-loaded, bench/upstream/inertia_round2/pp_diff.rb, bench/upstream/inertia_round2/react-starter-kit/pp]
rank:
risky: false
state: built
pr:
note: "2026-11-26 (inertia round 2, docs/upstream/inertia-round-2.md): one commit on master 5102d8dba7 (v3.24.0), Thomas author and committer, no trailers, signed; pushed to the fork (no fork CI runs). Checks: rspec --tag ~type:generator and rake test green on Ruby 3.2.11/Rails 6.1, 7.0, 7.1; 3.3.14/7.2; 3.4.13/8.0 and 8.1; 4.0.9/8.1 and main 5a161379f5 (1211-1218 examples, 64 runs; 3.0 and 3.1 have no prebuilt Ruby in mise, so 6.1 and 7.0 ran on 3.2.11, as for INRV1); rubocop clean. Differential (pp_diff.rb): 4,000 generated prop sets, every prop type and option, plain values answering the flags, a custom BaseProp subclass with and without them, under full, partial only/except/reset, except_once and scroll-intent visits: output byte-identical on v3.24.0 and the branch (3,795 distinct outputs; every metadata kind present). No spec added: behaviour is unchanged and the existing specs fail when a flag is called without respond_to? (OptionalProp, AlwaysProp and the DottedKeys wrapper lack deferred?/once?/merge?). Objects in an app: React Starter Kit's suite, inertia_rails lines 26.6 to 25.5 objects per request (2,180 per request; lowrail-profile compare exit 0, no change beyond noise)."
ownership: {date: 2026-11-26, checked: ["PRs and issues in any state naming try(:deferred?), the resolver's flag predicates, props_resolver.rb", "open PRs #448, #402, #391, #167", "maintainer branches pushed after 3.24.0"], hits: []}
passes: []
---

# Ask prop types for their flags without `try`

## Summary

The props resolver asks each prop type it reaches whether it is deferred, merges, is a once prop (and fresh), is live or rescues errors, through `Object#try`. Each `try` call allocates an Array for its arguments, so a prop type costs five to seven Arrays. Since #442 only prop types are asked, and `respond_to?` followed by the call gives the same answers, including for prop types without a given flag, such as `OptionalProp`, which has no `deferred?`.

Every Inertia render resolves at least one prop type, the `errors` prop that the renderer wraps in `InertiaRails.always`, which saves 7 objects per render. Pages with deferred, merge or optional props save more. An Inertia visit to a dashboard action with a merge prop, two deferred groups and an optional prop, with Ruby 4.0 and YJIT:

| | master | this PR |
| --- | ---: | ---: |
| Iterations per second (benchmark-ips) | 3,723 | 3,840 |
| Objects per request | 451 | 423 |

## Test plan

The existing specs cover each flag on each prop type, including the ones that don't define it. The resolved props and metadata are the same as on master.

## Checklist

- [ ] Tests added or updated
- [x] `CHANGELOG.md` updated (for user-facing changes)

## For Thomas

Numbers come from bench/upstream/inertia_round2/body/INRP1 (Callgrind and objects) and INRP1-ips (benchmark-ips); the leads table and the below-bar leads are in docs/upstream/inertia-round-2.md.
