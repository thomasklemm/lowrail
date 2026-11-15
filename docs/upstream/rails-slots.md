# rails/rails slots: ready PRs and waiting drafts (2026-11-15)

GitHub allows 15 non-draft PRs per author, and all 15 are in use. Six drafts wait for a slot: #59565 (back first, by an
earlier decision), K6 #59804, TE2 #59811, QL1 #59809, MB1 #59810, VB1 #59803. This page ranks all 21 by expected value
(chance of merge × impact) so Thomas can decide which ready PRs make room. Nothing was changed on GitHub.

Sources: `gh pr view` and the issue timelines of each PR (2026-11-15), `script/pr-queue status` (merge-tree against
rails/rails main `8217632cf8`), [contributions](contributions.md), the [queue items](../../bench/upstream/pr-queue/items)
and [DECISIONS](../DECISIONS.md). Chance and impact are judgment calls, explained below.

## Summary

- **Move five ready PRs back to draft:** E2 #59671, UG82 #59675, P1 #59621, TC-1 #59617, Arel #59574. Close none.
- **Fill the five freed slots in this order:** #59565, QL1 #59809, TE2 #59811, VB1 #59803, MB1 #59810.
- **K6 #59804 stays a draft** and takes the next slot that frees.
- Maintainers have been nearly silent on all 15 ready PRs. The only activity is seanpdoyle's question on #59675
  (11-06) and fatkodima asking tenderlove to review #59800 (11-14 23:55, one minute after he closed AB1).
- Since 11-05, three of our Rails PRs merged: kamipo's #59629 (`find_template` restore, 11-09), matthewd's #59676 (11-07)
  and skipkayhil's #59642 (11-13). Merges have slowed sharply since the first week, so slots turn over slowly.

## What the maintainers have signaled

- **Small performance wins need almost no added code.** fatkodima closed AB1 #59808 on 11-14: "this does not look like a
  place worth optimizing, also given the complexity it adds and a tiny improvement it makes. In real apps, there are
  definitely other parts of the request to look into." AB1 was 0.5–3% of a request and +38/−1. On #59577 he asked how
  candidates are chosen and whether the gain was worth the complexity. kamipo's #59590 then made #59577 moot. byroot
  reverted #59584 and closed #59557. What holds up: one-line or net-negative diffs, or a measurable share of every
  request. K6 (0.03% of a request) and MB1 (a new guard in `merger.rb`) are the closest to what was rejected.
- **Rails doesn't deprecate internal APIs** (matthewd on #59663). This counts against the Arel shim #59574. It applies
  less to #59644, which restores a private hook without a deprecation, as #59629 did, and kamipo merged #59629.
- **kamipo is reworking relation building and merging** (#59590 on order references, and three of his `merger.rb`
  commits 11-04 to 11-10). DECISIONS
  says to stay out of code a maintainer is reworking. That counts against MB1.
- **seanpdoyle owns the helper-module layout.** He closed DC1 #59667 in favor of #50312. On #59675 he quoted
  rafaelfranca: "I don't expect people to be cherry picking view helpers from Action View."

## Ready PRs (15)

Ages are counted to 2026-11-15. "Bot" means only the labeler acted. "Merge" is GitHub's state. The conflicting PRs
conflict only in the CHANGELOG (merge-tree). The other orb, [T-01a1dece](https://ampcode.com/threads/T-01a1dece-53a8-7468-8584-f41260c76be1),
is rebasing the red and conflicting PRs. As of this writing it has pushed nothing and found no causes.

| PR | Title (short) | Age | Last maintainer activity | Merge / CI | Value | Deadline before 8.2 beta | Recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [#59662](https://github.com/rails/rails/pull/59662) OP8 | Mutable defaults off the frozen defaults | 10 d | none (bot) | clean / green | Correctness, regression in unreleased #59083: `PG::NotNullViolation` on save (OpenProject), nested JSON defaults shared between records | yes | **Keep ready**: the most valuable fix we have open, and it must land before 8.2 ships. |
| [#59800](https://github.com/rails/rails/pull/59800) K1 | `LazyIndexedAttributeSet#keys` without rebuilding | 1 d | fatkodima asked tenderlove to review, 11-14 | clean / green | Perf, regression in unreleased #59141: `changed?` −37%, `update!` −18% (30 columns); +2/−15 | yes | **Keep ready**: removes code, and a maintainer has already routed it to its author. |
| [#59627](https://github.com/rails/rails/pull/59627) AR-2 | Restore `MAX_PASSWORD_LENGTH_ALLOWED` | 11 d | none | clean / green | Compatibility, public constant removed in unreleased #56041; Spree 6.0.2 and open-build-service raise `NameError` at load; +8 | yes | **Keep ready**: a public constant removed without a deprecation is the strongest restore case, and it's 8 lines. |
| [#59611](https://github.com/rails/rails/pull/59611) R1 | Declare Prism in Action View and Railties | 11 d | none | clean / green | Correctness: `LoadError` on Ruby 4.1, where prism becomes a bundled gem, if no other gem pulls it in; +4 | yes (Ruby 4.1 at Christmas) | **Keep ready**: trivial, and main still doesn't declare prism. |
| [#59735](https://github.com/rails/rails/pull/59735) UG82P | Guide: PG 18.4+ fixture locks | 5 d (ready 1 d) | none | clean / green | Docs: `out of shared memory` with parallel fixture loading (#57378) | yes | **Keep ready**: an upgrade-guide note is only useful before 8.2 ships, and it was verified on PG 18.7. |
| [#59734](https://github.com/rails/rails/pull/59734) UG82H | Guide: close elements in the opening branch | 5 d | none | clean / green | Docs: Herb no longer compiles templates that open and close an element in different branches (lobsters, Discourse, Redmine); the guide's Herb section doesn't say so | yes | **Keep ready**: it extends an existing guide section with a break that real apps hit. |
| [#59644](https://github.com/rails/rails/pull/59644) CW2 | Call a custom resolver's `_find_all` again | 10 d | none | clean / green | Compatibility, unreleased #58279: 121 Chatwoot mailer specs fail (Chatwoot develop still calls `_find_all`), view_component-cache_digest | yes | **Keep ready**: it has the same shape as #59629, which kamipo merged. |
| [#59609](https://github.com/rails/rails/pull/59609) I1 | Cast grouped keys of unknown columns | 11 d | none | CHANGELOG conflict / red (Buildkite 136476, cause unknown) | Correctness, fixes issue #48420 (PG range keys as Strings since 7.0.5) | no | **Keep ready** after the rebase: it closes a real issue. |
| [#59569](https://github.com/rails/rails/pull/59569) | Alias tracker only for through chains | 12 d | none | clean / green | Perf: `post.author` −6.5%/−5.3% instructions, ruby-bench shipit −2.6%/−1.8% (interp/YJIT); +5/−3 | no | **Keep ready**: a small diff with a whole-benchmark effect, which passes the AB1 test. |
| [#59668](https://github.com/rails/rails/pull/59668) E2b | Temporary SQLite table hides permanent | 10 d | none | clean / green | Correctness, unreleased 2cb3daba96 (#58498): duplicated columns and a composite primary key when a temp table shadows a permanent one (rare); base of E2 | yes | **Keep ready**: E2 can't merge before it. |
| [#59671](https://github.com/rails/rails/pull/59671) E2 | SQLite tables by any ASCII case | 10 d | none from Rails maintainers; scarroll32 (ransack) asked for a ping on merge, 11-08 | clean / green | Correctness, same unreleased regression: `Widgets` vs `widgets` fails (ransack spec); +149/−8 | yes | **Back to draft**: stacked on #59668, so it can't merge first; return it when #59668 merges, and the ransack ping stays on the thread. |
| [#59675](https://github.com/rails/rails/pull/59675) UG82 | Guide: `link_to`/`button_to` in NavigationHelper | 10 d | seanpdoyle review comment, 11-06 (questions the note, quoting rafaelfranca); our reply 11-06 is unanswered | clean / red (Buildkite 136474 on a docs-only diff, so probably unrelated) | Docs: classes that include `UrlHelper` alone lose `link_to` (Redmine hook listeners, avo) | yes | **Back to draft**: the owner doubts the guidance is wanted, and it ranks lowest of the guide notes. |
| [#59621](https://github.com/rails/rails/pull/59621) P1 | Cast plucked unknown columns | 11 d | none | CHANGELOG conflict / green | Correctness, not a regression (same on 7.0); follow-up to #59609, conflicts with it | no | **Back to draft**: the same idea as #59609, so it should follow that PR rather than take a second slot. |
| [#59617](https://github.com/rails/rails/pull/59617) TC-1 | `Time#change` keeps the UTC offset | 11 d | none | CHANGELOG conflict / red (Buildkite 136478, cause unknown) | Correctness, niche: `AmbiguousTime` in the repeated DST hour for Times with a zone object; costs +16–22% under YJIT on that path; +100/−15 | no | **Back to draft**: a rare bug with a measurable cost and no deadline, so it can come back after the beta. |
| [#59574](https://github.com/rails/rails/pull/59574) | Deprecate positional `Arel::Table.new` | 12 d | none (our comment 11-10 pointing to byroot's suggestion in #57829) | CHANGELOG conflict / green | Compatibility for internal API: flipper-active_record 1.4.2 (fixed on flipper main in flipper#1003, unreleased), Discourse, Docuseal | only before 8.2 | **Back to draft**: matthewd's rule on internal deprecations and 12 silent days make it the weakest ready PR; close it once flipper releases its fix. |

## Waiting drafts (6)

| PR | Title (short) | Age | Last maintainer activity | Merge / CI | Value | Deadline before 8.2 beta | Recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [#59565](https://github.com/rails/rails/pull/59565) | PG cast hint after a type name or `IS` | 12 d | none (byroot invited such a hint in #55439) | clean / green | Error message for `DATE $1`, which #58427 extended to `find_by_sql` on main; +107 | soft | **Ready, slot 1**: the earlier decision, and byroot invited it, though it adds 107 lines for a hint. |
| [#59809](https://github.com/rails/rails/pull/59809) QL1 | Spell out "query"/"queries" in the log line | 0 d | none | clean / green | Perf on every request of every app: bare JSON request −3.8%, show −1.0% instructions; 3.2× on the log line; +1/−1 | no | **Ready, slot 2**: a one-line change to every request, exactly what fatkodima asked for on AB1. |
| [#59811](https://github.com/rails/rails/pull/59811) TE2 | `==` in `tag_options` | 0 d | none | clean / green | Perf on every tag helper attribute: YJIT whole pages −1.5% to −2.3% (Callgrind; two A/A cells failed), `tag.a` +8.9% ips; +1/−1 | no | **Ready, slot 3**: one line with broad reach, though it can read as a YJIT workaround. |
| [#59803](https://github.com/rails/rails/pull/59803) VB1 | Block literals in `LazyIndexedAttributeSet` | 1 d | none | clean / red (Buildkite 136623, reported as a railties server-test timeout, not verified) | Perf, unreleased #59141: first attribute reads −7.5% YJIT (Callgrind), ips 1.05–1.08×; request mix within A/A except ZJIT −0.58%; +3/−3 | soft | **Ready, slot 4**: three lines in tenderlove's new code next to K1, with a modest gain; needs green CI first. |
| [#59810](https://github.com/rails/rails/pull/59810) MB1 | Skip merging a blank relation | 0 d | none | clean / green | Perf: −0.4% to −1.4% on association-heavy pages; +14 with a three-part guard | no | **Ready, slot 5**: a real per-page gain, but it adds a guard in kamipo's active merger code, the pattern behind #59577 and AB1. |
| [#59804](https://github.com/rails/rails/pull/59804) K6 | `button_to` params with `tag` | 1 d | none | clean / green | Perf, unreleased #50312: −12% for one param, −29% for 20 params per call; about 0.03% of a request; +12/−1 | soft | **Stay draft (next free slot)**: correct, but at 0.03% of a request it is closest to what fatkodima closed as a "tiny improvement". |

Not in the slot order: OP1 [#59661](https://github.com/rails/rails/pull/59661) (draft) stays a draft until the 8.2 beta
([ractor-freezes](ractor-freezes.md)).

## Ranking by expected value

Chance is the estimated chance of a merge within weeks, given the signals above. Impact runs from 1 (niche or
sub-percent) to 5 (data correctness in a default path). EV = chance × impact.

| # | PR | Chance | Impact | EV | Now | Recommendation |
| ---: | --- | ---: | ---: | ---: | --- | --- |
| 1 | #59662 OP8 | 50% | 5 | 2.5 | ready | keep ready |
| 2 | #59800 K1 | 60% | 4 | 2.4 | ready | keep ready |
| 3 | #59627 AR-2 | 55% | 3.5 | 1.9 | ready | keep ready |
| 4 | #59809 QL1 | 50% | 3.5 | 1.75 | draft | ready (slot 2) |
| 5 | #59611 R1 | 50% | 3 | 1.5 | ready | keep ready |
| 6 | #59735 UG82P | 45% | 3 | 1.35 | ready | keep ready |
| 7 | #59734 UG82H | 45% | 3 | 1.35 | ready | keep ready |
| 8 | #59644 CW2 | 40% | 3 | 1.2 | ready | keep ready |
| 9 | #59811 TE2 | 40% | 3 | 1.2 | draft | ready (slot 3) |
| 10 | #59609 I1 | 35% | 3 | 1.05 | ready | keep ready (after rebase) |
| 11 | #59569 | 30% | 3 | 0.9 | ready | keep ready |
| 12 | #59565 | 35% | 2.5 | 0.9 | draft | ready (slot 1) |
| 13 | #59803 VB1 | 35% | 2.5 | 0.9 | draft | ready (slot 4) |
| 14 | #59810 MB1 | 30% | 2.5 | 0.75 | draft | ready (slot 5) |
| 15 | #59668 E2b | 30% | 2.5 | 0.75 | ready | keep ready (E2 depends on it) |
| 16 | #59671 E2 | 25% | 3 | 0.75 | ready | back to draft until #59668 merges |
| 17 | #59675 UG82 | 20% | 2.5 | 0.5 | ready | back to draft |
| 18 | #59621 P1 | 25% | 2 | 0.5 | ready | back to draft until #59609 merges |
| 19 | #59804 K6 | 20% | 1.5 | 0.3 | draft | stay draft, next free slot |
| 20 | #59617 TC-1 | 15% | 2 | 0.3 | ready | back to draft |
| 21 | #59574 | 15% | 2 | 0.3 | ready | back to draft; close once flipper releases #1003 |

Ranks 1–15 fill the 15 slots. E2 (16) ties MB1 and E2b on EV but can't merge before E2b, so it gives up its slot.

## Slot order for the drafts

1. #59565: the earlier decision. On EV alone, QL1 would go first. If Thomas makes all five swaps at once, the order
   doesn't matter.
2. QL1 #59809
3. TE2 #59811
4. VB1 #59803, once Buildkite is green on it
5. MB1 #59810
6. K6 #59804, at the next merge or close

Returning drafts later: E2 #59671 when #59668 merges, P1 #59621 when #59609 merges, and UG82 #59675 if seanpdoyle
answers.

## Notes for the rebasing orb

- Keeping open PRs mergeable still applies, but every force-push notifies reviewers. #59609 stays ready and is worth
  rebasing now.
- #59617, #59621 and #59574 are proposed for draft. Their CHANGELOG-only conflicts can wait until they return.
- #59675's red Buildkite run is on a docs-only diff.
- Side finding: the queue item CW1 still says `ready`, but #59642 merged on 11-13 (skipkayhil). `script/pr-queue sync`
  will update it.
