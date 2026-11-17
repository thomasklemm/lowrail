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
state: merged
pr: 444
note: "2026-11-17: opened as inertiajs/inertia-rails#444 (Thomas asked for a separate PR to get CI green; exception to the per-gem cap of 2 because it unblocks all open PRs there). Body: claude-code must-fix (not every open PR was red; seven specs compare the header, six fail) and the Precognition wording nit applied; commit-message nit (precognition_spec:129 not named) left, it would need a new head. 2026-11-17. Cause confirmed: the same 6 specs pass with Rails pinned to 8.0.5.1 and fail on 8.0.5.2, whose only Vary change is b58c107abe (backport of e38dd281d3, GHSA-r9jg-fmfx-2gv6; 8.1.4.1 has 7a955ca367). The library's Vary output is correct under the new Rails (X-Inertia once, after the app's values; Precognition last; no duplicates), so only the specs change. Full rspec (--tag ~type:generator) and rake test green on the whole CI matrix: Ruby 3.0/Rails 6.1.7.10, 3.1/7.0.10, 3.2/7.1.6, 3.3/7.2.4, 3.4/8.0.5.2, 3.4/8.1.4.1, 4.0.9/8.1.4.1, 4.0.9/main 4f00fbc; master fails exactly the 6 on 8.0/8.1/main. Six mutations of renderer.rb/middleware.rb are caught by the same specs on 8.1.4.1 and 7.2.4 as master's specs catch on 7.2.4. Rubocop clean. No CHANGELOG entry: specs only."
passes:
  - {reviewer: claude-code, orb: T-01a1e8e3-9cd4-74f1-ac1b-0f6598c1026d, head: "dc24da9980", date: 2026-11-17, verdict: changes, open: "Body only; code, specs and commit approved. Must-fix: 'now fail on every open PR' is not true as written. #402's Rails 8.0/8.1/main checks are green from 2026-10-12, before the 2026-11-03 releases, and #391 and #167 are docs-only and run no Testing workflow. Replace the sentence with 'Six specs that compare the whole header fail on these versions, so the Rails 8.0, 8.1 and main jobs have been red on every CI run since.' (this also fixes 'Six Vary specs compare the whole header': seven compare it, including precognition_spec:45, and six fail). Nits: 'The Precognition spec that appends to the Accept set by Rails' (the middleware appends, not the spec), e.g. 'The Precognition spec for appending to the Accept that Rails sets now checks …'; the commit message doesn't mention the precognition_spec:129 change. Checked: cause pinned (master specs pass on 8.0.5.1, fail exactly the 6 on 8.0.5.2, 8.1.4.1 and main 4f00fbc, pass on 7.2.4; the advisory patches only 8.0.5.2 and 8.1.4.1). Vary probe on 7.2.4, 8.0.5.1, 8.0.5.2, 8.1.4.1 and main across 23 scenarios (HTML, Inertia JSON, real client headers, an XHR without Accept, app Vary Accept-Language / 'accept, x-inertia' / 'X-Inertia, Accept' / '*' / Sec-Fetch-Site, a .json URL, Precognition 204/422/plain/Accept json, redirect 302/303/409, conditional GET 200/304, SSR HTML/JSON): X-Inertia once, right after the app's values with Rails' additions after it; Precognition last; case-insensitive dedup on both sides; nothing from Rails on head/redirect/304. No library change needed. Pre-existing and out of scope: app Vary '*' becomes '*, X-Inertia' on every Rails. Full rspec --tag ~type:generator and rake test green on 7.2.4/3.3, 8.0.5.1 and 8.0.5.2/3.4, 8.1.4.1/3.4 and 4.0.9, main/4.0.9, plus 7.1, 7.0 and 6.1 on Ruby 3.2.11 (mise has no prebuilt 3.0 or 3.1). RuboCop clean. 11 mutations of renderer.rb and middleware.rb: dropping, duplicating or prepending X-Inertia, overwriting Vary, and overwriting, prepending, dropping or always adding Precognition fail the same specs on 8.1.4.1 as master's specs on 7.2.4. The duplicated Precognition is now caught only by :45, not :129. Not caught: the renderer adding Accept itself (master's specs catch it on 7.2.4 only, and on 8.0.5.2+ the output is identical to the correct one) and case-sensitive X-Inertia dedup (not caught on master either). Acceptable. precognition_spec:129 start_with('Accept, ').and end_with(', Precognition') is the clearest form here: eq can't span old and new Rails, the helper strips Accept, and the separators would also catch a join without a comma; no simpler alternative. Helper comment says why and is kept. GHSA link resolves (published). Commit has no trailers and the Thomas identity."}
---

# Ignore the Vary values Rails adds itself in the specs

## Summary

Rails 8.0.5.2, 8.1.4.1 and main add `Accept` and `X-Requested-With` to `Vary` on rendered responses, also when `Vary` is already set (the fix for [GHSA-r9jg-fmfx-2gv6](https://github.com/rails/rails/security/advisories/GHSA-r9jg-fmfx-2gv6)). Six specs that compare the whole header fail on these versions, so the Rails 8.0, 8.1 and main jobs have been red on every CI run since. A plain Inertia visit, for example, now gets `Vary: X-Inertia, Accept, X-Requested-With`.

Inertia's own values are unchanged: `X-Inertia` is still added once after the app's values, and `Precognition` last. The spec helper that already ignores Rails 8.2's `Sec-Fetch-Site` now ignores these two as well. The Precognition spec for appending to the `Accept` that Rails sets now checks that the header still starts with `Accept` and ends with `Precognition`.

## Test plan

RSpec and Minitest pass on every Rails version in the CI matrix, including 8.0.5.2, 8.1.4.1 and main. Dropping, duplicating or prepending `X-Inertia`, or overwriting the header with `Precognition` or prepending it, fails the same specs as before.

## Checklist

- [x] Tests added or updated
- [ ] `CHANGELOG.md` updated (for user-facing changes)
