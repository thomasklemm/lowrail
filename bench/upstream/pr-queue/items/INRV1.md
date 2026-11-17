---
id: INRV1
repo: inertiajs/inertia-rails
kind: fix
area: CI, Vary header specs
reviewer: "skryukov (wrote the Precognition Vary spec in #427 and maintains the suite)"
branch: thomasklemm/vary-negotiation-headers
head: "dc24da9980e790d06bc8c541c522c9f603d6d945"
base: master
built_on: "3e1330a33d9e4ae3a7ec52800d4d18d4179d5401"
depends_on: []
stacked_on:
alternative_of:
impact: "Rails 8.0, 8.1 and main CI jobs green again on master and every open PR (6 Vary specs fail since Rails 8.0.5.2 and 8.1.4.1); specs only"
rank:
risky: false
state: built
pr:
note: "2026-11-17. Cause confirmed: the same 6 specs pass with Rails pinned to 8.0.5.1 and fail on 8.0.5.2, whose only Vary change is b58c107abe (backport of e38dd281d3, GHSA-r9jg-fmfx-2gv6; 8.1.4.1 has 7a955ca367). The library's Vary output is correct under the new Rails (X-Inertia once, after the app's values; Precognition last; no duplicates), so only the specs change. Full rspec (--tag ~type:generator) and rake test green on the whole CI matrix: Ruby 3.0/Rails 6.1.7.10, 3.1/7.0.10, 3.2/7.1.6, 3.3/7.2.4, 3.4/8.0.5.2, 3.4/8.1.4.1, 4.0.9/8.1.4.1, 4.0.9/main 4f00fbc; master fails exactly the 6 on 8.0/8.1/main. Six mutations of renderer.rb/middleware.rb are caught by the same specs on 8.1.4.1 and 7.2.4 as master's specs catch on 7.2.4. Rubocop clean. No CHANGELOG entry: specs only."
passes: []
---

# Ignore the Vary values Rails adds itself in the specs

## Summary

Rails 8.0.5.2, 8.1.4.1 and main add `Accept` and `X-Requested-With` to `Vary` on rendered responses, also when `Vary` is already set (the fix for [GHSA-r9jg-fmfx-2gv6](https://github.com/rails/rails/security/advisories/GHSA-r9jg-fmfx-2gv6)). Six Vary specs compare the whole header, so the Rails 8.0, 8.1 and main jobs now fail on every open PR. A plain Inertia visit, for example, now gets `Vary: X-Inertia, Accept, X-Requested-With`.

Inertia's own values are unchanged: `X-Inertia` is still added once after the app's values, and `Precognition` last. The spec helper that already ignores Rails 8.2's `Sec-Fetch-Site` now ignores these two as well. The Precognition spec that appends to the `Accept` set by Rails now checks that the header still starts with `Accept` and ends with `Precognition`.

## Test plan

RSpec and Minitest pass on every Rails version in the CI matrix, including 8.0.5.2, 8.1.4.1 and main. Dropping, duplicating or prepending `X-Inertia`, or overwriting the header with `Precognition` or prepending it, fails the same specs as before.

## Checklist

- [x] Tests added or updated
- [ ] `CHANGELOG.md` updated (for user-facing changes)
