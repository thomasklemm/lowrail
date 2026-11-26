---
id: HD1
repo: hashie/hashie
fork: thomasklemm/hashie
kind: feature
area: CI, Duel performance regression guards (.duel.rb, duel/, perf.yml, perf-comment.yml, gemfiles/duel.gemfile)
reviewer: dblock
branch: thomasklemm/duel
head: "9c3009161ec0e259e7863d9b3b92864da5589bd0"
base: master
built_on: "e1adebc3de"
tracker: [hashie/hashie#658]
depends_on: []
stacked_on:
alternative_of:
impact: "Every hashie PR that touches lib/ gets a Duel check (Ruby 4.0, YJIT) of 13 benchmarks on Mash, Dash and Trash hot paths, as dblock asked in #658. Calibrated on the fork: 0 false alarms in 25 runs on identical code, both planted regressions failed, #656 reported faster on 3-6 benchmarks and never slower; a passing run takes about a minute."
evidence: [bench/upstream/hashie_duel]
rank:
risky: false
state: built
pr:
note: "2026-11-26 built: one commit 9c30091 on master e1adebc (fork master fast-forwarded to e1adebc), Thomas Klemm author and committer, no trailers, fork pre-push hook installed. Requested by dblock in #658 (he wrote it for us on #656; Thomas agreed publicly there). Calibration on fork PRs #1-#8 against duel-calibration (= 9c30091), see bench/upstream/hashie_duel/README.md. Local: Ruby 4.0.9 rake spec 1,075 examples 0 failures, rake rubocop clean, duel --force A/A 0 regressed. Benchmarks chosen from profile-hotlines (Mash in Huginn 6.2% of job objects, Forem 0.9%), HM1 and dblock's benchmarks/mash_new_keys.rb; fixture is the octocat repository payload of HM1's body. README badge: Duel's own static badge (README.md 'Without the job, use Duel's own badge'), which needs no duel/badge branch or push job, as in Grape. Kind feature added to script/pr-queue KINDS for this item. Manual ownership check 2026-11-26, open and closed: no hashie PR or issue names Duel, a perf workflow or regression benchmarks except #658; #658 has no assignee or comments, labels chore and 'you can help!', only cross-reference #656 (ours); latest 15 PRs are dblock release tooling (#643-#657), dependabot and #656."
ownership: {date: 2026-11-26, checked: ["open PRs naming repository_attributes that change .duel.rb, .github/workflows/perf-comment.yml, .github/workflows/perf.yml, .gitignore, .rubocop.yml, .spellcheck.txt, CHANGELOG.md, CONTRIBUTING.md, README.md, duel/dash_duel.rb, duel/duel_helper.rb, duel/fixtures/repository.json, duel/mash_duel.rb, gemfiles/duel.gemfile","hashie/hashie#658 and what references it"], hits: ["tracker: hashie/hashie#658 (open): Add Duel performance regression guards","references hashie/hashie#658: hashie/hashie#656 (PR, open, thomasklemm): Write new Mash keys without allocating in respond_to_missing?"]}
passes: []
---

# Add Duel performance regression guards

Closes #658.

This ports ruby-grape/grape#3077 to Hashie. On each pull request that changes `lib/`, the Perf workflow runs the benchmarks in `duel/` with [Duel](https://github.com/sferik/duel-ruby) against the target branch and the pull request side by side, on Ruby 4.0 with YJIT, and fails if the branch is slower or allocates more. The Perf comment workflow posts Duel's report from a second workflow that runs none of the pull request's code, and a `duel: accept` label lets an intentional slowdown through. Both call Duel's reusable workflows pinned to the v0.3.1 commit. Duel needs Ruby 3.4 or later, so it has its own bundle in `gemfiles/duel.gemfile` and stays out of the main one.

The 13 benchmarks are the paths API clients run on every response, built from one fixture, the GitHub repository response that #656's benchmark uses, parsed with Ruby's JSON so both versions get the same Hash:

* `Mash.new` from that nested response, `deep_merge` of a nested update and `to_hash` of the result: the conversion every client pays for.
* Reading keys as methods, with suffixes (`?`, `!`, `_`) and through `[]` and `dig`; writing a new key and overwriting one as methods; `respond_to?` for a key, a suffix and a missing name. These go through `method_missing`, `convert_key` and the collision check on every write, where #410 and #656 were.
* `Dash.new` with required properties and defaults, Dash property reads and writes, `Trash.new` with renamed and transformed properties, and a Dash with coercion.

Before opening, I ran the workflows on my fork, with pull requests against a branch that has this commit:

* Five pull requests that change only a comment in `lib/`, run five times each: 25 runs, none failed. In one run Duel measured one Dash benchmark again before passing it.
* Changing `convert_key` back to `Symbol#to_s` failed 8 benchmarks (`Mash.new` went from 106 to 144 objects), and a `method_missing` that checks `key?` three times failed method reads at 1.5x.
* #656's change came out faster on 3 to 6 benchmarks in each of three runs and slower on none.
* A run with nothing slower takes about a minute; one that finds a regression takes two to four, because Duel measures again before failing. GitHub's runners don't expose instruction counts, so CPU time and allocation counts decide.

[Runs on the fork](https://github.com/thomasklemm/hashie/pulls?q=is%3Apr+%5Bcalibration%5D).

The Perf workflow needs a maintainer to approve this pull request's runs before it runs here; it compares the code with itself on this pull request, since only `duel/` and the configuration change. Perf comment runs once it is on `master`.

## For Thomas

What it is: a CI job that, for each PR, benchmarks hashie's master against the PR in parallel worker processes and fails when the PR is slower or allocates more, plus a job that comments the result. dblock asked for exactly this in #658 as a copy of what sferik did for Grape.

Calibration in one sentence: on GitHub runners, 25 runs of identical code never failed, both deliberate regressions failed, and #656 shows as faster, so the gate keeps Duel's defaults (limit 1.02, YJIT). The one caveat is the thin margin: identical code shows medians up to about 1.03 on some runners for a few benchmarks, which Duel's rule of measuring again in fresh processes absorbed in every run; `c.measure("cpu", limit: 1.03)` in `.duel.rb` is the one-line fallback if dblock ever sees a false alarm.

Not in the port: Grape's Rakefile task for Duel (not asked for in #658), and the badge job (the static badge needs none).
