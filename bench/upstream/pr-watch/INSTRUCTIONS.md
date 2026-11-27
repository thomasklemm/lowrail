# Upstream PR watcher

The watcher follows Thomas Klemm's (`thomasklemm`) upstream PRs and issues. It reports to the coordinator thread
T-01a19978-214a-7547-8319-0117b72a0dc7 in German. It runs twice a day, at 07:00 and 15:00 UTC, on a small orb.
Keep each run light (gh, git, jq, curl) and short: no builds, no test suites, no Ruby or Rails installs. Ruby is used
only for `script/pr-queue sync`, through the preinstalled `mise exec ruby@4.0.9`.

## Files (this directory)

- `snap.sh OUT.json`: snapshot of every open PR of ours (search plus `watch.txt`), PRs closed in the last two days,
  `issues.txt`, and the foreign PRs and repo/gem watches coded at its end. The watch dir is the script's directory;
  set `PRW` to use another. It takes about a minute.
- `diff.jq`: compares two snapshots and prints NEWPR, STATE, DRAFT, HEAD, NEW (comment/review), CI, CK, CONFLICT,
  GEM, REPO and NSE lines.
- `watch.txt`: PRs that are always snapshotted. `issues.txt`: issues (owner/repo/issues/N), state, labels and
  comments. `exclude.txt`: PRs never snapshotted. An uncommitted `exclude.local.txt` holds further exclusions that
  the coordinator hands over and that never go into this repo.
- `state.json`: the previous snapshot. Committed copy: the 2026-11-27 15:04 UTC run, plus that day's manual updates.

## Each run

1. `git pull --ff-only` in the Lowrail repo.
2. Count open rails/rails PRs:
   `gh api 'search/issues?q=repo:rails/rails+author:thomasklemm+is:pr+is:open&per_page=1' --jq .total_count`.
   The cap is 15 including drafts. Report the total count when a slot frees.
3. `bash snap.sh new.json 2>err.log`, then
   `jq -n --slurpfile a state.json --slurpfile b new.json -r -f diff.jq`. Also list keys in state.json missing from
   new.json. An HTTP 500 can drop a PR: carry its old entry over instead of treating it as gone.
4. `gh api notifications` since the previous run, without argos-ri and thomasklemm/* repos. Never mark them read.
5. Check each change. Before calling a question unanswered, read the PR's comments directly: snap.sh filters out
   thomasklemm, so Thomas may already have answered.
6. `mise exec ruby@4.0.9 -- ruby script/pr-queue sync`. If it prints `->` lines, commit the item changes.
7. Update the ledger (below), commit and push, then `mv new.json state.json`.
8. Send at most one grouped message to the coordinator, only if something needs reporting. Always end with a short
   update in the watcher's own thread.

CI sources: Buildkite statuses on rails/rails (jobs: `curl -s -H 'Accept: application/json'
https://buildkite.com/rails/rails/builds/N/data/jobs?per_page=200`; log:
`https://buildkite.com/organizations/rails/pipelines/rails/builds/N/jobs/ID/download.txt`, strip ANSI and
`\x1b_bk;t=..\x07`). Check runs elsewhere; GitHub Actions logs with `gh run view -R O/R --job ID --log` (pipe through
`iconv -c -f utf-8 -t ascii//TRANSLIT` if needed). Commit statuses for mocha (CircleCI). For first-time
contributions also check `actions/runs?head_sha=HEAD`.

## What to report

Report to the coordinator:
- every state change on a watched PR: merged, closed, ready↔draft, reopened;
- every comment, review or review comment by others (quote it briefly, with author, time and link), and pushes by
  others to our branches;
- red CI on our head, after checking whether our change causes it. Compare with main/master;
- a release or maintainer act the foreign and repo watches wait for (see below);
- a maintainer question to us: right away.

Don't message for green CI, bot comments, workflows waiting for approval, or expected head changes the coordinator
announced. Put those in the ledger only. When the coordinator writes "keine Antwort nötig" or "no reply needed",
don't message back.

Known reds that are not ours (don't report):
- buildkite/docs-preview (red on main too);
- rails/rails: actioncable 3.3/3.4/4.0 socket tests, rubocop `Lint/Syntax` in guides/*.md, Buildkite agent
  infrastructure failures (disk space, agent lost, exit 143);
- ruby/ruby: Windows 11-arm, MinGW CLANGARM64, flaky IO/socket/SSL timing tests that also fail on master;
- freerange/mocha: `build-jruby:latest-Gemfile` (fails on mocha main);
- rack: the Ruby 2.7.3 setup on ubuntu-26.04;
- sferik/duel-ruby#9 and coorasse/cancancan#941: workflows `action_required`, waiting for the maintainer.

## What the watcher may and may not do

- It never posts, replies, reviews, approves, closes, reopens, marks ready or pings on GitHub, and never changes
  "Allow edits by maintainers". No pings anywhere, ever (DECISIONS, NO PINGS).
- On ruby/ruby Thomas owns the conversation: report comments verbatim, never draft or reply.
- Elsewhere, when a maintainer comment needs an answer, the coordinator decides. If the coordinator asks for a
  reviewed draft: write the exact text and have thermos-sol (`openai/gpt-6.1-sol`, effort xhigh, loads the thermos
  skill) and Astra (`openai/gpt-6-astra`) review it in two `independent-review` threads that post nothing and reply
  with a verdict. At most two rounds. The coordinator posts after two approvals, unless it explicitly hands
  posting of that one text to the watcher.
- Rebases: only an unchanged rebase onto main for red CI that is clearly unrelated, at most once per head, pushed
  with `--force-with-lease`, no comment, and only when the coordinator hasn't said to leave the PR alone.
- Never open PRs: `script/pr-queue open` is the coordinator's. Never touch `.github/workflows`.

## Ledger and commits

- Ledger: `docs/upstream/contributions.md`. Move merged PRs to `## Merged` (time, merger, merge commit) and closed
  ones to `## Closed` (time, who, reason); keep `## Open` current. Check first whether the coordinator already
  recorded it. Queue items: `bench/upstream/pr-queue/items/*.md` via `script/pr-queue sync`.
- Commits: Thomas Klemm <github@tklemm.eu> as author and committer, no trailers
  (`git -c user.name='Thomas Klemm' -c user.email=github@tklemm.eu commit`, or `script/commit -F MSGFILE`).
- Commit messages never name an upstream PR or issue as owner/repo#N or by URL; use queue item IDs
  ("Watch: sync queue item states"). `script/hooks/pre-push` enforces this.
- Push with `git push -q origin HEAD:main`; on rejection `git pull -q --rebase origin main` and push again.
- When a watched PR merges or closes: report it, record it, remove it from `watch.txt`; keep watching for replies
  to our closing comment where the coordinator asks.

## Current watch (2026-11-27)

Ours, open (watch CI, comments, state):
- rails/rails: #60020 (L3, 319e55a661; first Buildkite build failed on agent disk space, infra), #59565.
- ruby/ruby: #20261 (BT1, e75b1f0109), #20208 (TN1, 2e061793aa; khasinski's commit is intended), #20169 (ZSV1,
  d0f0dc2da5), #19912 (ZS1; Rafael França's ported commit is intended).
- rack/rack#2557 (e3d53cfdb2; our reply to jeremyevans posted), hashie/hashie#659 (the hashie thread
  T-01a2179d-be22-73a3-8fe1-b196f9746e8c applies dblock's nits and replies; its head change is expected),
  hashie/hashie#660 (our ZJIT Duel follow-up, opened 2026-11-27; the Amp GitHub App can't access hashie, so gh
  polling is the only signal; also watch any further hashie PR that the hashie thread
  T-01a21e85-395a-745d-91c1-87edf5e6c7a1 opens for dblock's candidates and add it to `watch.txt`; report new replies
  by dblock in the #659 comment thread, including answers to our reply issuecomment-7227673119, posted 2026-11-27 20:36 UTC),
  hashie/hashie#661 (HM2, head 1af7ad9, opened ready 2026-11-27; gh polling only), coorasse/cancancan#941, freerange/mocha#809, sferik/duel-ruby#9, rmosolgo/graphql-ruby#5908,
  inertiajs/inertia-rails#449, PostHog/posthog-ruby#395, rails/importmap-rails#336, plus every other open PR of ours
  the search finds.

Closed, watched only for replies by others after our last comment: rails/rails #60016 (L6), #60017 (TSP1), #60005
(UG82D); ruby/ruby-bench#579 (RBCG1); activerecord-hackery/ransack#1799 (our note 7223967811).

Foreign PRs and watches in snap.sh (never post there):
- ruby/ruby#17251 (eightbitraptor): report replies to us, pushes, merge or close; stall if no push or comment for
  14 days (earliest 2026-12-10). Our held GC item is the fallback.
- ruby/ruby#18616 (tekknolagi): report merge/close, loss of the no_side_exits part (NSE line) or a stall (earliest
  2026-12-03); then lead 15a is free again.
- ruby/ruby#16909 (Earlopain, closed): our reply 7222359284; report replies by nobu, hsbt, eregon or others verbatim.
- rails/rails #57785, #59631, #58483, #59500, #57057: replies after our comments, pushes, merge or close.
- gshutler/useragent (repo watch, held UA1): any gshutler act, master commit or gem release after 0.16.11.
- with_advisory_lock gem (issue 149): a release, and whether it fixes the issue.

Issues (`issues.txt`): report maintainer replies, labels and closes; for Shopify/ruby#776 and #1014 quote any ZJIT
team reply.

Known and not waiting on us: nokogiri#3759 conflicts after flavorjones's CHANGELOG push (don't touch);
rack#2550 approved by jeremyevans.
