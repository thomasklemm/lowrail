---
id: PHR1
repo: PostHog/posthog-ruby
fork: thomasklemm/posthog-ruby
kind: perf
area: posthog-rails, TracingHeaders.extract_header
reviewer: dustinbyrne
branch: thomasklemm/tracing-headers-allocations
head: "a58f8d2022fd3679dfbc0a90d06dc31835fd3249"
base: main
built_on: "27fbf08b5a"
introduced_by: 144
depends_on: []
stacked_on:
alternative_of:
impact: "A request without PostHog tracing headers, which is most server-rendered page requests, allocates 276 objects fewer in posthog-rails's RequestContext (369 to 93 with a Rails 8.1 app's 73 env keys), -39.1% instructions (interpreter) and -51.1% (YJIT, JIT-flat); on Dawarich's request specs the scan line goes from 341.8 to 28.9 objects per request, and the whole request from 60,947 to 60,643"
evidence: [bench/upstream/oss_profile_sweep_1/body/PHR1, bench/upstream/oss_profile_sweep_1/phr1.patch, bench/upstream/oss_profile_sweep_1/body/PHR1-worst, bench/upstream/oss_profile_sweep_1/dawarich/phr1]
rank:
risky: false
state: held
pr:
note: "2026-11-25: held until Thomas has a signing key; nothing pushed (no fork yet), nothing posted upstream; the commit is kept as bench/upstream/oss_profile_sweep_1/phr1.patch (git am, then re-sign). posthog-ruby needs signed PR commits: AGENTS.md ('Sign every commit; main rejects unsigned commits'), CONTRIBUTING 'Commit signing', and the PR template's checklist item; main has the repo ruleset 'main' (required_signatures, squash only, 1 approval, Gem build / RSpec 3.2-3.4 / RuboCop checks) and the org ruleset 'Require signed commits' (all branches); GitHub's ruleset docs say unsigned commits on the head branch can block a squash merge even though GitHub signs the squash commit. Every fork PR merged since the org ruleset (2026-08-05: #356, #331, #307, #253, #231, #230, #222) has only verified commits; the unsigned fork PRs #98 and #81 merged before it. AI_POLICY.md asks for the test strategy and the template's Agent context section; the PR title must be a Conventional Commit (lint-pr.yml). Changeset: .changeset/tracing-headers-allocations.md, posthog-rails patch (RELEASING: a Rails-only change needs only a posthog-rails changeset). Ownership: no PR or issue in PostHog/posthog-ruby names tracing_headers, normalize_header_name or extract_header; the file is unchanged since #144 (dustinbyrne, 2026-05-18) apart from #149 (docs) and identical in posthog-rails 3.18.6 (Dawarich's lock) and main 3.27.1; no open PR changes posthog-rails/lib. Built on main 27fbf08b5a: bundle exec rspec 2,598 examples, 0 failures, 49 pending (the OpenTelemetry-bundle specs CONTRIBUTING lists as pending without that bundle), rubocop 169 files no offenses, rake public_api:check passes, Ruby 4.0.9. The new spec passes on main and fails with a length filter without the ASCII check, with bytesize, and with only the canonical name's length. extract_header gives the same value or raises the same error on main and branch for 5,972 env/header cases (case, HTTP_ prefix, dashes/underscores, frozen, binary/ISO-8859-1/UTF-16, long s, dotless i, st/ff ligatures, sharp s, soft hyphen, symbols and other non-String keys) on Ruby 4.0.9 and 4.0.7; the control without the ASCII check differs in 184 (bench/upstream/oss_profile_sweep_1/phr1_diff.rb). Body numbers: script/upstream-bench body/PHR1 (base twice, A/A 0.01% / 0.04%, YJIT JIT-flat in 6 windows), run on 7e9d743, whose tree 1225b5d is a58f8d2's (only the commit message changed). Worst case (body/PHR1-worst, interpreter, A/A 0.00%): an env where all 73 keys have a target length (20 or 25) costs +22.5% instructions and 1 object more (the lengths array), all 73 keys non-ASCII +7.2%; no Rails env looks like that, so not in the body. The ownership hit #369 (marandaneto, flags in lib/posthog/client.rb) touches no posthog-rails file. Dawarich (f6b79c9b8, Ruby 4.0.9, Rails 8.1.4.1): lowrail-profile from Lowrail main ffb4c165 (gem sha256 e9ac10e6) on 16 request spec files (451 requests, RSWAG_GENERATING=1 to skip the nested rswag run), posthog-rails 3.18.6 as a path gem with only tracing_headers.rb swapped; 414 examples, 0 failures, outcomes identical in plain, base, aa and head; compare exit 0, 0 regressions, 45 improved actions (about -315 to -490 objects each), A/A identical on the line. Needs a skeptic pass and the Agent context before opening."
ownership: {date: 2026-11-25, checked: ["open PRs cross-referencing #144","no branch diff (gh api repos/PostHog/posthog-ruby/compare/main...thomasklemm:thomasklemm/tracing)","open PRs naming clear, capture, capture_exception, enrich_capture_attrs_with_context, present_id?, property_key?, initialize, current, current=, with_context that change .changeset/hungry-hedgehogs-request-context.md, lib/posthog/client.rb, lib/posthog/internal/context.rb, posthog-rails/README.md, posthog-rails/examples/posthog.rb, posthog-rails/lib/generators/posthog/templates/posthog.rb, posthog-rails/lib/posthog/rails.rb, posthog-rails/lib/posthog/rails/capture_exceptions.rb, posthog-rails/lib/posthog/rails/configuration.rb, posthog-rails/lib/posthog/rails/railtie.rb, posthog-rails/lib/posthog/rails/request_context.rb, posthog-rails/lib/posthog/rails/request_metadata.rb, posthog-rails/lib/posthog/rails/tracing_headers.rb"], hits: ["names capture, changes its file (11 open PRs name it): PostHog/posthog-ruby#369 (PR, open, marandaneto): feat(flags): support known-absent property keys in local evaluation"]}
passes: []
---

# perf(rails): skip env keys that can't match a tracing header

## :bulb: Motivation and Context

When a request has no `X-POSTHOG-DISTINCT-ID` or `X-POSTHOG-SESSION-ID` header, as most server-rendered page requests don't, `TracingHeaders.extract_header` scans the Rack env and builds an upcased, translated copy of every key to compare it. That is two Strings per key for each of the two headers, on every request. While profiling a few Rails apps, this was the top posthog-rails line in Dawarich's request specs.

For an ASCII key, `upcase` and `tr` keep its length, so a key whose length matches none of the normalized names cannot match and is now skipped before it is copied. Non-ASCII keys, whose length `upcase` can change (`"ﬆ"` becomes `"ST"`), and non-String keys are normalized and compared as before, so the same keys match.

Objects and Callgrind instructions per `RequestContext#call` for a browser request without tracing headers in a Rails 8.1 app (73 env keys), Ruby 4.0.9:

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
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

- [x] Ran `pnpm changeset` to generate a changeset file

## 🤖 Agent context

**Autonomy:** Human-driven (agent-assisted)

Thomas Klemm directed the work; Amp (Claude) found the line with an allocation profiler on a few open-source Rails apps' test suites and prepared the change, the spec and the measurements. A plain length check was rejected because `upcase` can lengthen or shorten non-ASCII keys, so those keep the old comparison.

## For Thomas

The fix in one sentence: when the tracing headers are missing, the fallback loop upcased every env key just to compare it, and since upcasing an ASCII string never changes its length, a key with the wrong length can be skipped without copying it. The ASCII condition is what keeps it exact: `"ﬆ".upcase` is `"ST"`, so a non-ASCII key can match a target of a different length.

Before opening: commits must be signed, and the checklist's first box is only true once the re-signed commit is pushed. What Thomas would set up (no key exists yet): an ed25519 SSH key used only for signing (`ssh-keygen -t ed25519 -C "github@tklemm.eu signing" -f github_signing`, no passphrase, since orbs can't type one), its public half added on GitHub under Settings → SSH and GPG keys → New SSH key with key type "Signing Key", and the private half stored only as an Amp secret (for example `GIT_SIGNING_KEY`; the public half can be a plain environment variable). An orb then loads it into an agent without writing it to disk (`eval "$(ssh-agent -s)"; ssh-add - <<<"$GIT_SIGNING_KEY"`) and sets, in the fork clone only, `gpg.format ssh`, `user.signingkey "key::<public key>"` and `commit.gpgsign true`. `script/commit` runs `git commit-tree`, which honors `commit.gpgSign` according to git's docs (not tried here). Then `git am phr1.patch` on a fresh main, `script/commit --amend` to re-sign, check `git log --format=%G?` shows G (with `gpg.ssh.allowedSignersFile`) and that GitHub shows Verified after the push. Revoking is deleting the key on GitHub and the secret. The template asks to assign the human who directed the work as the PR's assignee, which a fork author can't set; say so in the Agent context if needed. The "Agent context" asks for a session link; none is given here, since the thread isn't public. The template's headings and checklist go against our body rules, but posthog-ruby's AI policy closes PRs that skip the template, so the body follows it with each section kept short.
