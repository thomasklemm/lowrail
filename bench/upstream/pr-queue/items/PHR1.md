---
id: PHR1
repo: PostHog/posthog-ruby
fork: thomasklemm/posthog-ruby
kind: perf
area: posthog-rails, TracingHeaders.extract_header
reviewer: dustinbyrne
branch: thomasklemm/tracing-headers-allocations
head: "0404d1413a91c432c1bff2649de453ca86e0e085"
base: main
built_on: "27fbf08b5a"
introduced_by: 144
depends_on: []
stacked_on:
alternative_of:
impact: "A request without PostHog tracing headers, which is most server-rendered page requests, allocates 276 objects fewer in posthog-rails's RequestContext (369 to 93 with a Rails 8.1 app's 73 env keys), -39.1% instructions (interpreter) and -51.1% (YJIT, JIT-flat); on Dawarich's request specs the scan line goes from 341.8 to 28.9 objects per request, and the whole request from 60,947 to 60,643"
evidence: [bench/upstream/oss_profile_sweep_1/body/PHR1, bench/upstream/oss_profile_sweep_1/body/PHR1-ips, bench/upstream/oss_profile_sweep_1/phr1.patch, bench/upstream/oss_profile_sweep_1/body/PHR1-worst, bench/upstream/oss_profile_sweep_1/dawarich/phr1]
rank:
risky: false
state: draft
pr: 395
note: "2026-11-26 (signing set up): fork thomasklemm/posthog-ruby created; branch rebuilt on main 27fbf08b5a (unchanged since the build, so the spec/rubocop/public_api results stand) with git am phr1.patch and re-signed with script/commit (SSH key from GIT_SIGNING_KEY_SEED); head 35428f5, same tree 1225b5d as a58f8d2 and the benchmarked 7e9d743; GitHub verification verified: true, reason valid; author and committer Thomas, no trailers. thermos-sol pass 1 (T-01a217ab, on 35428f5) asked for changes: F1 changeset checkbox claimed pnpm changeset (relabelled), F2 no benchmark-ips (added: body/PHR1-ips, script/upstream-bench --modes yjit --ips 3 on the same code, YJIT best of 3 on core 1, RequestContext#call 15.2k to 33.6k i/s, A/A 3.39%, JIT-flat in 9 windows; Callgrind YJIT reproduced -51.2%), F3 'the same keys match' too broad (scoped to Rack env keys, the to_s-override / no-is_a? boundary stated in body and commit; changeset reworded), F4 Agent context says the session is private; N1 bytesize claim corrected. New head 0404d14 (signed, GitHub verified: true / valid): only the changeset text and commit message changed; lib and spec identical to 35428f5. thermos-sol confirm on 0404d14: nits (N2 applied in the body only). 2026-11-26: opened as draft PostHog/posthog-ruby#395 at 0404d14, maintainer edits on, no assignee: a maintainer must set the assignee (the template wants the directing human; a fork author can't). Nothing else posted. Report: https://ampcode.com/artifacts/phr1-thermos-review-b3b85c23-c46e-4494-b08e-6f1c43e4fea4. At opening, a maintainer must set the assignee (the template asks for the directing human; a fork author cannot set it). 2026-11-25: held until Thomas has a signing key; nothing pushed (no fork yet), nothing posted upstream; the commit is kept as bench/upstream/oss_profile_sweep_1/phr1.patch (git am, then re-sign). posthog-ruby needs signed PR commits: AGENTS.md ('Sign every commit; main rejects unsigned commits'), CONTRIBUTING 'Commit signing', and the PR template's checklist item; main has the repo ruleset 'main' (required_signatures, squash only, 1 approval, Gem build / RSpec 3.2-3.4 / RuboCop checks) and the org ruleset 'Require signed commits' (all branches); GitHub's ruleset docs say unsigned commits on the head branch can block a squash merge even though GitHub signs the squash commit. Every fork PR merged since the org ruleset (2026-08-05: #356, #331, #307, #253, #231, #230, #222) has only verified commits; the unsigned fork PRs #98 and #81 merged before it. AI_POLICY.md asks for the test strategy and the template's Agent context section; the PR title must be a Conventional Commit (lint-pr.yml). Changeset: .changeset/tracing-headers-allocations.md, posthog-rails patch (RELEASING: a Rails-only change needs only a posthog-rails changeset). Ownership: no PR or issue in PostHog/posthog-ruby names tracing_headers, normalize_header_name or extract_header; the file is unchanged since #144 (dustinbyrne, 2026-05-18) apart from #149 (docs) and identical in posthog-rails 3.18.6 (Dawarich's lock) and main 3.27.1; no open PR changes posthog-rails/lib. Built on main 27fbf08b5a: bundle exec rspec 2,598 examples, 0 failures, 49 pending (the OpenTelemetry-bundle specs CONTRIBUTING lists as pending without that bundle), rubocop 169 files no offenses, rake public_api:check passes, Ruby 4.0.9. The new spec passes on main and fails with a length filter without the ASCII check and with only the canonical name's length (with the ASCII check kept, bytesize is equivalent and passes, as thermos-sol confirmed). extract_header gives the same value or raises the same error on main and branch for 5,972 env/header cases (case, HTTP_ prefix, dashes/underscores, frozen, binary/ISO-8859-1/UTF-16, long s, dotless i, st/ff ligatures, sharp s, soft hyphen, symbols and other non-String keys) on Ruby 4.0.9 and 4.0.7; the control without the ASCII check differs in 184 (bench/upstream/oss_profile_sweep_1/phr1_diff.rb). Body numbers: script/upstream-bench body/PHR1 (base twice, A/A 0.01% / 0.04%, YJIT JIT-flat in 6 windows), run on 7e9d743, whose tree 1225b5d is a58f8d2's (only the commit message changed). Worst case (body/PHR1-worst, interpreter, A/A 0.00%): an env where all 73 keys have a target length (20 or 25) costs +22.5% instructions and 1 object more (the lengths array), all 73 keys non-ASCII +7.2%; no Rails env looks like that, so not in the body. The ownership hit #369 (marandaneto, flags in lib/posthog/client.rb) touches no posthog-rails file. Dawarich (f6b79c9b8, Ruby 4.0.9, Rails 8.1.4.1): lowrail-profile from Lowrail main ffb4c165 (gem sha256 e9ac10e6) on 16 request spec files (451 requests, RSWAG_GENERATING=1 to skip the nested rswag run), posthog-rails 3.18.6 as a path gem with only tracing_headers.rb swapped; 414 examples, 0 failures, outcomes identical in plain, base, aa and head; compare exit 0, 0 regressions, 45 improved actions (about -315 to -490 objects each), A/A identical on the line. Needs a skeptic pass and the Agent context before opening."
ownership: {date: 2026-11-26, checked: ["open PRs cross-referencing #144","open PRs naming extract_header that change .changeset/tracing-headers-allocations.md, posthog-rails/lib/posthog/rails/tracing_headers.rb"], hits: []}
passes:
  - {reviewer: thermos-sol, orb: T-01a217ab-6a5f-7383-9e30-a58156c90111, head: "35428f55b8432b8402c67d3b60f652b501c2a932", date: 2026-11-26, verdict: changes, open: "F1 pnpm changeset checkbox untrue; F2 no benchmark-ips; F3 equivalence claim too broad (custom to_s keys); F4 agent context lacks session note; N1 bytesize note. All fixed on 0404d14"}
  - {reviewer: thermos-sol, orb: T-01a217ab-6a5f-7383-9e30-a58156c90111, head: "0404d1413a91c432c1bff2649de453ca86e0e085", date: 2026-11-26, verdict: nits, open: "N2: drop 'Only' from the custom-key caveat (not exhaustive, e.g. a String subclass overriding length); applied in the body, the commit message keeps it to keep the reviewed head"}
---

# perf(rails): skip env keys that can't match a tracing header

## :bulb: Motivation and Context

When a request has no `X-POSTHOG-DISTINCT-ID` or `X-POSTHOG-SESSION-ID` header, as most server-rendered page requests don't, `TracingHeaders.extract_header` scans the Rack env and builds an upcased, translated copy of every key to compare it. That is two Strings per key for each of the two headers, on every request. While profiling a few Rails apps, this was the top posthog-rails line in Dawarich's request specs.

For an ASCII key, `upcase` and `tr` keep its length, so a key whose length matches none of the normalized names cannot match and is now skipped before it is copied. Non-ASCII keys, whose length `upcase` can change (`"ﬆ"` becomes `"ST"`), and non-String keys are normalized and compared as before, so Rack env keys match as before. A key object that overrides core methods, such as a `to_s` that returns something other than its own content, could now be judged differently.

`RequestContext#call` for a browser request without tracing headers, with the 73-key env a minimal Rails 8.1 app passes to it:

```ruby
context = PostHog::Rails::RequestContext.new(->(_env) { [200, {}, ["ok"]] })
Benchmark.ips { |x| x.report("RequestContext#call") { context.call(env) } }
```

| benchmark-ips, Ruby 4.0.9, YJIT, one core, best of 3 | main | branch |
| --- | ---: | ---: |
| `RequestContext#call` | 15.2k i/s | 33.6k i/s |

| Objects and Callgrind instructions per call, Ruby 4.0.9 | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| no JIT | 369 | 93 | 746,853 | 455,123 | −39.1% |
| YJIT | 369 | 93 | 543,683 | 265,749 | −51.1% |

## :green_heart: How did you test it?

The new spec covers the two kinds of key only the scan finds: a lowercase Rack-style name, and one with a non-ASCII character that `upcase` turns into two ASCII letters. It fails with a length check that ignores the encoding or forgets the `HTTP_` name. I also compared the old and new `extract_header` on several thousand env shapes (case, `HTTP_` prefix, dashes and underscores, frozen, binary and UTF-16 strings, non-ASCII and non-String keys): both return the same value or raise the same error. In Dawarich's request specs, the normalizing line went from 342 to 29 objects per request, with the same test results.

## :pencil: Checklist

- [x] All commits are signed (see [Commit signing](https://github.com/PostHog/posthog-ruby/blob/main/CONTRIBUTING.md#commit-signing))
- [x] I reviewed the submitted code.
- [x] I added tests to verify the changes.
- [x] I updated the docs if needed.
- [x] No breaking change or entry added to the changelog.

### If releasing new changes

- [x] Added a changeset file (`.changeset/tracing-headers-allocations.md`, posthog-rails patch)

## 🤖 Agent context

**Autonomy:** Human-driven (agent-assisted)

Thomas Klemm directed the work; Amp (Claude) found the line with an allocation profiler on a few open-source Rails apps' test suites and prepared the change, the spec and the measurements. A plain length check was rejected because `upcase` can lengthen or shorten non-ASCII keys, so those keep the old comparison. The agent session is private and can't be linked.

## For Thomas

The fix in one sentence: when the tracing headers are missing, the fallback loop upcased every env key just to compare it, and since upcasing an ASCII string never changes its length, a key with the wrong length can be skipped without copying it. The ASCII condition is what keeps it exact: `"ﬆ".upcase` is `"ST"`, so a non-ASCII key can match a target of a different length.

Commits are signed (script/commit with GIT_SIGNING_KEY_SEED, verified on GitHub). The template asks to assign the human who directed the work as the PR's assignee, which a fork author can't set; say so in the Agent context if needed. The "Agent context" asks for a session link; none is given here, since the thread isn't public. The template's headings and checklist go against our body rules, but posthog-ruby's AI policy closes PRs that skip the template, so the body follows it with each section kept short.
