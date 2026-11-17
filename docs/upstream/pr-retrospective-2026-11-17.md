# Upstream PR retrospective, second round (2026-11-17)

Follows [the first retrospective](pr-retrospective.md) (2026-11-04, 111 PRs) and uses its method and columns. It
covers every upstream PR by thomasklemm that was opened, merged, closed, reopened or marked ready from 2026-11-04 10:30
UTC (the cut of the first round) to 2026-11-17 22:30 UTC: 105 PRs (61 rails/rails, 13 ruby/ruby, 12 ruby/ruby-bench,
19 gems). 34 PRs were updated in the window without a state change, such as rebases or a comment, and are left out.
Also left out, as in the first round: argos-ri, roundhouse-rb, Campfire, rubycdp and personal repos. Sources: GitHub
GraphQL (state, timeline, reviews, commits; read only), the [ledger](contributions.md) and
[DECISIONS](../DECISIONS.md). Nothing was posted.

The columns are counted as in the first round. *First maintainer response* is the first comment, review, merge or
close by someone other than us or a bot. For a PR opened as a draft and later marked ready it is counted from ready.
*Pushes* are our force-pushes plus our commits dated after opening, one per minute. A *review round* is maintainer
feedback (not a plain approval) followed by a push of ours before the next feedback. *Kind*: perf, fix, restore (bring
back or bridge something main removed), docs, test (test or CI only), and for ruby-bench *tooling* (new harness
features). Body length is counted in words, code blocks included.

The German summary and the recommendations are at the end of the analysis, before the appendix with every PR.

## Numbers by repository

| | PRs | Merged | Closed by a maintainer | Closed by us | Open (draft) | Median first response | Median open → merge | Median diff, merged / closed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| rails/rails | 61 | 23 | 10 | 9 | 19 (5) | 1.9 h (39 answered) | 1.5 h | 8 / 39 lines |
| ruby/ruby | 13 | 6 | 1 | 5 | 1 | 13.6 h (8 answered) | 32.2 h | 66 / 76 lines |
| ruby/ruby-bench | 12 | 5 | 0 | 0 | 7 (1) | 9.6 h (5 answered) | 9.6 h | 8 lines |
| gems | 19 | 11 | 1 | 0 | 7 (2) | 2.6 d (15 answered) | 2.6 d | 21 / 54 lines |

Compared with the first round (Rails 39 of 47 merged, ruby/ruby 7 of 34, gems 4 of 30), the merge rate fell on Rails,
rose sharply on ruby/ruby and on the gems, and ruby-bench went from one open PR to five merged and seven waiting.

**The Rails split by opening date.** Opened on 2026-11-04: 24 PRs, 16 merged, most within two hours. Opened on
2026-11-05: 19 PRs, 4 merged, 9 closed. Opened from 2026-11-06 on: 13 PRs, 1 merged (#59809), 3 closed by maintainers,
7 open. Rails' own merge pace did not drop: 133 PRs by everyone merged on rails/rails from 2026-11-04 on (amatsuda 35,
kamipo 28, byroot 16, yahonda 15, skipkayhil 10). What changed is who merges, and that our cap and drafts rule
(2026-11-05) held most new Rails PRs back.

## What kind of PR merges where

| Repo, kind | PRs | Merged | Closed by a maintainer | Closed by us | Open |
| --- | --- | --- | --- | --- | --- |
| Rails perf | 26 | 14 | 4 | 3 | 5 |
| Rails fix | 19 | 5 | 4 | 2 | 8 |
| Rails restore | 10 | 3 | 2 | 3 | 2 |
| Rails docs | 4 | 0 | 0 | 1 | 3 |
| Rails test | 2 | 1 | 0 | 0 | 1 |
| ruby/ruby perf (ZJIT) | 9 | 3 | 0 | 5 | 1 |
| ruby/ruby fix | 3 | 2 | 1 | 0 | 0 |
| ruby/ruby test | 1 | 1 | 0 | 0 | 0 |
| ruby-bench fix and test | 9 | 5 | 0 | 0 | 4 |
| ruby-bench tooling | 3 | 0 | 0 | 0 | 3 |
| gems fix | 10 | 5 | 1 | 0 | 4 |
| gems perf | 7 | 4 | 0 | 0 | 3 |
| gems test (their red CI) | 2 | 2 | 0 | 0 | 0 |

* **Rails perf merges only as amatsuda's series.** 13 of the 14 merged perf PRs were opened by 2026-11-04 and merged
  by amatsuda (median 1.4 h, median diff 5 lines). His last merge of ours was #59640 on 2026-11-05 08:20; his last
  Rails merge of anyone's was on 2026-11-11. Of the 9 perf PRs opened since 2026-11-06, one merged: #59809, a
  one-line log-string change that fatkodima merged without comment. Three were closed by maintainers: #59803 and
  #59811 (skipkayhil: "Let's fix this in the JITs?") and #59808 (fatkodima: "does not look like a place worth
  optimizing, also given the complexity it adds and a tiny improvement it makes"). Two of amatsuda's 17 merges in
  the window were later reworked by byroot: #59584 reverted (#59713, measured only on small documents) and #59640
  simplified (#59714).
* **Rails fixes merge when they fix an unreleased regression with a small repro**, and the area's maintainer decides
  the shape. Merged: #59625 and #59626 (amatsuda, under an hour), #59640, #59676 (matthewd, after he asked for a
  conditional instead of raising the minimum), #59642 (skipkayhil, after 7.9 days and a rebase request). kamipo did
  not merge #59609 and #59621; he folded both into his own #59816, authored by him alone, 11 days later. yahonda
  closed #59637 because Dalli's patch release fixes it, and skipkayhil closed #59623 because the caller was wrong
  (fixed in ransack#1792, merged). #59565 (opened 11-03) and #59611 (11-04) have had no response in two weeks.
* **Rails restores merge only for public or documented API.** Merged: #59606 (public template handler methods,
  "Good catch!"), #59629 (seanpdoyle: documented on api.rubyonrails.org) and #59634 (`where!` bind values; kamipo
  added his own commit and wrote "overriding private APIs is at the gem's own risk"). Closed by maintainers: #59663
  (matthewd: "We don't deprecate internal APIs. That's what internal means.") and #59667 (seanpdoyle approved it,
  then closed it for the merged #50312). Closed by us: #59660 after seanpdoyle's "Depending on private methods and
  API is discouraged", and #59628 and #59630 after matthewd's rule.
* **Rails docs got no response.** The four upgrade-guide notes (#59675, #59734, #59735, and #59659 closed by us)
  have one review comment between them, on #59675.
* **ruby/ruby merges ZJIT work that a maintainer asked for, and correctness.** The three merged ZJIT perf PRs all
  answer an explicit ask: #19678 (Shopify/ruby#1091), #19682 (Shopify/ruby#1100, "I'd like to land a fix for the
  permanent exit") and #19909 (skipkayhil's "Let's fix this in the JITs?" on rails#59811; tekknolagi: "Nice", merged
  in 23 hours). The five closed by us (#19483, #19655, #19685, #19670, #19899) had no maintainer response; three had
  no `run_benchmarks.rb` effect beyond A/A, #19670 was superseded by Kevin Newton's commits on master, and #19899
  by byroot's #19905 (same check, merged the next day). The one open, #19912 (+595/−77 in 13 files, 534 words), has
  no response after two days. Fixes: #19648 (YJIT, merged by XrXr after he narrowed it) and the 3.4 backport #19620
  (nagachika) merged; #19919 was closed by hsbt because the behavior it restored was removed on purpose.
* **ruby-bench merges small fixes k0kubun needs, at once.** #564–#568 (cache, ANALYZE, nokogiri, Rails bump,
  Windows CI) merged within 7–18 hours, all by k0kubun. The seven opened since 2026-11-05 evening (#569–#575, #579:
  GC harness output, a fixed clock for lobsters in two variants, a `--runs` significance test, a 3,657-line blog
  benchmark, a Callgrind summary fix) have no response at all.
* **Gems merge where a maintainer is active.** graphql-ruby merged three in 2.1–2.7 hours (rmosolgo, with ydah
  reviewing after the merge). inertia-rails merged three on 2026-11-17 within 36 minutes, right after our #444 fixed
  its red CI: #435 had waited 28 days and #441 14 days. sqlite3-ruby merged #773 (its own red CI) and answered #769
  and #770 with "I'll review" after about a week. ransack merged two (#1792 in 30 h, #1795 in 2.6 d), ruby/date merged
  #199 after jeremyevans corrected a wrong sentence in the body, and rails_vite#57 merged after 24 days. ankane
  closed blind_index#62 by fixing it in his own commit 23 minutes after it opened. Of the 24 unanswered gem PRs from
  the first round, three merged (inertia-rails #435 and #441, rails_vite#57); the other 21 show no state change.

## Which maintainers merge which kinds

| Maintainer | Merged ours in the window | What he merges | What he pushes back on |
| --- | --- | --- | --- |
| amatsuda (Rails) | 17 | one-site allocation and CPU wins, small regression fixes; no rounds in 12 of 17 | the small common input (#59584); inactive since 2026-11-11 |
| kamipo (Rails AR) | 2, plus 2 folded into his own PR | public API restores; rewrites AR fixes himself (#59816) | overrides of private API |
| byroot (Rails, Ruby VM) | 1 (#59570, a one-line change after his nit) | — | closes or reverts what he would write differently (#59557 closed, #59584 reverted, #59640 simplified); does the same check himself on ruby (#19905) |
| skipkayhil (Rails) | 1 (#59642, after 7.9 days) | correctness | JIT workarounds (#59803, #59811), caller-side mistakes (#59623) |
| matthewd (Rails) | 1 (#59676) | narrow compatibility fixes | deprecating internal API (#59663) |
| fatkodima (Rails) | 1 (#59809) | obviously simpler code | complexity for small wins (#59808), more code than needed (#59832: "Won't just `return [] if @errors.empty?` be enough?") |
| seanpdoyle (Rails AV) | 0 (reviews, approved #59667) | — | private API (#59660); reimplementing at the call site instead of fixing the helper (#59804) |
| yahonda (Rails) | 0 | — | workarounds for fixed dependency bugs (#59637); two concerns in one PR (#59812) |
| k0kubun (ZJIT, ruby-bench) | 2 ruby, 5 ruby-bench | issue-first ZJIT perf, ruby-bench fixes | memory per profile entry (#19682), function shape (#19678) |
| XrXr (YJIT/ZJIT) | 2 | YJIT correctness, test fixes | a PR that changes what it is about (#19648, request-changes) |
| tekknolagi (ZJIT) | 1 (#19909) | the JIT side of a Rails closure | test names and snapshot shape (#19699, #19909) |
| hsbt (Ruby, Bundler) | 0 | — | restoring behavior removed on purpose (#19919) |

## Where review rounds came from

19 review rounds on 14 PRs; 91 of 105 PRs had none. By cause:

| Cause | Rounds | PRs |
| --- | --- | --- |
| Code shape: a simpler or more idiomatic form, placement, test names | 8 | rails #59570, #59642, #59804; ruby #19648, #19678 (2), #19699, #19909 |
| Body numbers and claims: a wrong claim or the wrong input measured | 4 | rails #59584 (3); ruby/date#199 |
| Scope: split, narrow, or a different fix | 4 | rails #59675, #59676, #59812; ruby #19648 |
| Design: memory and storage of new state | 1 | ruby #19682 |
| Mechanical: rebase or CI rerun | 2 | rails #59614, #59642 |

Body numbers caused few rounds but the costliest outcome: #59584 went through three rounds of amatsuda's own
measurements and was reverted by byroot four days after merge for the input none of them measured. Shape rounds were
cheap and usually ended in a merge within a day (#19678, #19699, #19909, #59570). Scope rounds came from bundling
(#59812) or a heavier fix than needed (#59676). Body length did not separate outcomes on Rails: the median body is 198
words for merged PRs and 197 for PRs closed by a maintainer, both above the 50–120 words DECISIONS asks for.

## Repos worth more or fewer bets

* **More: ruby/ruby ZJIT with a stated ask.** 3 of 3 merged within 1–1.5 days. Every ZJIT PR without an ask closed.
  The pace rule held (four new ruby/ruby PRs in 13 days), and the team's tone changed from the first round's
  "deluge" to approvals with short notes.
* **More: Rails correctness fixes for unreleased regressions**, kept small, in the shape the area's owner would
  write (5 merged of 19, and the closures said where the fix belongs, not that it was unwelcome).
* **More, while they are active: graphql-ruby, inertia-rails, sqlite3-ruby, ransack.** Fixing a maintainer's red CI
  helped: inertia-rails#444 unlocked two PRs that had waited two and four weeks, within 36 minutes.
* **Fewer: Rails perf micro-wins.** Without amatsuda, 1 of 9 merged, and the closures named complexity and JIT
  workarounds. Rails now needs an interpreter or allocation win that moves a request on its own.
* **Fewer: Rails restores of private API and upgrade-guide notes.** None of the private restores merged; none of the
  docs PRs got a decision.
* **Hold: ruby-bench.** Five quick merges, then seven PRs with no response for 12 days. The cap exemption led to a
  backlog, including two variants of the same lobsters fix (#571, #572).
* **Fewer: gems without recent outside merges.** 21 of the first round's gem PRs are still unanswered.

## Did the rules added since 2026-11-04 show up?

* **One detailed review instead of two** (2026-11-17 07:52 UTC). Too new to judge: two PRs opened after it. On one of
  them, #59832, fatkodima asked within 1.6 hours for a simpler form (`return [] if @errors.empty?`) that the review
  had not asked for. That is one data point for adding "is there a shorter form?" to the single review.
* **Realistic sizes** (2026-11-14). No reviewer questioned a size afterwards, and #59804's body was cut before it was
  marked ready. Its one round was about code shape. The rule's sibling from 2026-11-10, the size sweep, came from
  #59584, whose revert in this window is the clearest case of numbers that measured only where the change wins.
* **No pings** (2026-11-17 09:10 UTC). The only ping in the window, on inertia-rails#435 at 07:04, came before the
  rule. That PR merged 3.7 hours later, but only after #444 fixed the maintainer's CI, together with #441, which had
  no ping. The data doesn't show that a ping helps. sqlite3-ruby and ruby-bench answered or merged without one.
* **A/A for benchmark claims.** On ruby/ruby it works as a filter and as evidence. Three ZJIT PRs were closed by us
  because nothing moved beyond A/A, which avoided a maintainer closing them. #19909's body showed master, master-aa and
  branch in `run_benchmarks.rb` format plus a stats diff, and merged in 23 hours with no question about the numbers.
  On Rails no closure in the window was about numbers. They were about where the fix belongs (JIT, Dalli, the gem)
  and complexity. A/A is necessary there but doesn't decide.
* **Earlier rules that did show up.** Pace and issue-first on ruby/ruby: all three merged ZJIT PRs answered an ask.
  Search before building: two of our PRs were overtaken by a maintainer's work on the same code (#19899 by #19905,
  #59609/#59621 by #59816), and ruby #19670 by commits on master. The search did not include the maintainers' open work in
  progress at that moment. Drafts and the Rails cap: fewer Rails PRs opened (13 after 2026-11-06 compared with 43 on
  11-04 and 11-05), and their median time from draft to ready was 16 hours.

## Zusammenfassung für Thomas

**Rails hat sich gedreht.** Am 4.11. geöffnet: 24 PRs, 16 gemergt, fast alle von amatsuda in unter zwei Stunden. Seit
dem 6.11. geöffnet: 13 PRs, einer gemergt (#59809, eine Zeile). amatsudas Serie ist vorbei; seit dem 11.11. hat er gar
nichts mehr gemergt, und zwei seiner Merges von uns hat byroot danach zurückgebaut (#59584 revertiert, #59640
vereinfacht). Die anderen Rails-Maintainer antworten schnell, aber mit Gegenwind: „Let's fix this in the JITs?“
(skipkayhil, zwei PRs), „not worth optimizing … given the complexity“ (fatkodima), „We don't deprecate internal APIs“
(matthewd). kamipo hat zwei unserer Fixes in seinen eigenen PR übernommen. Was bei Rails noch merged: Fixes für
unveröffentlichte Regressionen mit kleinem Repro (5) und Restores öffentlicher API (3). Private Restores und
Upgrade-Guide-Notizen: nichts.

**ruby/ruby läuft jetzt.** 6 von 13 gemergt, und alle drei ZJIT-Performance-PRs, die gemergt wurden, beantworten eine
ausdrückliche Bitte (#19678, #19682 aus dem Tracker, #19909 aus skipkayhils „fix it in the JITs“, nach 23 Stunden
gemergt mit „Nice“). Was ohne Bitte kam, haben wir selbst geschlossen, meist weil nichts über A/A ging. Tempo-Regel,
Issue-first und A/A im Format der Tools haben gewirkt.

**ruby-bench und Gems.** ruby-bench hat fünf kleine Fixes sofort gemergt, aber auf die sieben seit dem 5.11. geöffneten
PRs gibt es keine Antwort. Bei Gems wurden 11 von 19 gemergt, dort, wo ein Maintainer aktiv ist (graphql-ruby in 2–3
Stunden, inertia-rails sofort, nachdem wir sein rotes CI repariert hatten).

**Die neuen Regeln.** „Ein detailliertes Review“ und „keine Pings“ sind zu neu, um sie an Ergebnissen zu messen. Der
einzige Ping (inertia-rails#435) hat nicht nachweisbar geholfen: gemergt wurde nach dem CI-Fix, zusammen mit einem PR
ohne Ping. „Realistische Größen“ hat keine Rückfragen erzeugt. A/A wirkt bei ruby/ruby als Filter und als Beleg; bei
Rails ging es in keiner Ablehnung um die Zahlen, sondern darum, wo der Fix hingehört.

## Recommendations: where to bet next

1. **ZJIT patterns with a stated ask.** Each Rails PR closed with "fix it in the JITs" and each Shopify/ruby idea that
   is free to take is a candidate, at the existing pace of two a week, with #19909's evidence format (master,
   master-aa and branch, then a stats diff). Wait for #19912 to get a response before opening the next one, and keep
   new ones well under its 672 lines.
2. **Rails: correctness of unreleased regressions, small, in the owner's shape.** Before building, read the last two
   weeks of the area owner's commits and open PRs (kamipo for Active Record, seanpdoyle for Action View) and fix in
   the helper they would change. Open no more Rails perf micro-wins unless the interpreter or allocations move a
   whole request on their own. That is the bar the cap already sets, and the closures since 2026-11-06 confirm it.
3. **Private-API breakage goes to the gem, never to a Rails restore.** ransack (#1792, #1795) and blind_index (fixed
   by ankane) show that route works. No new upgrade-guide PRs while the four open ones have no decision.
4. **ruby-bench: no new PRs until the open ones are answered.** Withdraw one of the two lobsters fixed-clock
   variants (#571 or #572) so the maintainer sees one choice, and check whether #575 (3,657 lines) is better as a
   tracker question first.
5. **Gems: bet on the four active ones (graphql-ruby, inertia-rails, sqlite3-ruby, ransack), and fix their red CI
   first when it blocks our PRs.** Add one sentence to the single review: "Is there a shorter form a maintainer would
   suggest?" (#59832, #59804, #59570 each got that question from the maintainer).

## Appendix: every PR

Kind, outcome and the maintainer's words for each of the 105 PRs. "Merged, no comment" means the merge was the only
response. For drafts marked ready, the first response is counted from ready when it came after.

### rails/rails (61)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes | Rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [rails#59557](https://github.com/rails/rails/pull/59557) | perf | closed (byroot) | 2.7 d byroot (close) | 2.7 d | +72/−7, 2f | 2 | 0 | closed by byroot without comment (opened 11-03; Ruby-version branch and a duplicated method, L3 by our own gate) |
| [rails#59564](https://github.com/rails/rails/pull/59564) | perf | closed (us) | 5.6 d tenderlove (commented) | 7.8 d | +10/−6, 2f | 3 | 0 | tenderlove: "I don't like this. It implicitly encodes the expectation that `immediate_future_classes` returns a un-shared mutable array"; closed by us after the safe rework stayed within A/A |
| [rails#59565](https://github.com/rails/rails/pull/59565) | fix | open | — | open | +107/−0, 2f | 0 | 0 | no response |
| [rails#59570](https://github.com/rails/rails/pull/59570) | perf | merged (byroot) | 2.1 d byroot (commented) | 2.1 d | +1/−1, 1f | 1 | 1 | byroot: "This is redundant, we already called `to_s`."; fixed, merged by byroot |
| [rails#59584](https://github.com/rails/rails/pull/59584) | perf | merged (amatsuda) | 7.3 h amatsuda (comment) | 32.1 h | +17/−1, 2f | 3 | 3 | amatsuda measured small documents slower and proposed direct checks, then asked for single-character tests; merged. byroot reverted it on 11-09 (#59713): "Your benchmark only include small documents … you're now scanning the string 3 times"; on 4.1 the path is gone |
| [rails#59603](https://github.com/rails/rails/pull/59603) | perf | merged (amatsuda) | 1.9 h amatsuda (merge) | 1.9 h | +2/−0, 1f | 0 | 0 | merged, no comment |
| [rails#59605](https://github.com/rails/rails/pull/59605) | perf | merged (amatsuda) | 1.3 h amatsuda (merge) | 1.3 h | +2/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59606](https://github.com/rails/rails/pull/59606) | restore | merged (amatsuda) | 1.4 h amatsuda (merge) | 1.4 h | +52/−0, 2f | 0 | 0 | amatsuda: "Good catch!" |
| [rails#59607](https://github.com/rails/rails/pull/59607) | perf | merged (amatsuda) | 1.4 h amatsuda (merge) | 1.4 h | +1/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59608](https://github.com/rails/rails/pull/59608) | perf | merged (amatsuda) | 1.5 h amatsuda (merge) | 1.5 h | +22/−1, 2f | 1 | 0 | merged, no comment |
| [rails#59609](https://github.com/rails/rails/pull/59609) | fix | closed (kamipo) | 11.6 d kamipo (close) | 11.6 d | +58/−4, 3f | 7 | 0 | kamipo folded it and #59621 into his own #59816 ("Closes #59609. Closes #59621."), authored by him alone |
| [rails#59611](https://github.com/rails/rails/pull/59611) | fix | open | — | open | +4/−0, 3f | 0 | 0 | no response |
| [rails#59613](https://github.com/rails/rails/pull/59613) | perf | merged (amatsuda) | 0.7 h amatsuda (merge) | 0.7 h | +3/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59614](https://github.com/rails/rails/pull/59614) | perf | merged (amatsuda) | 1.4 h amatsuda (comment) | 2.1 h | +5/−1, 1f | 1 | 1 | amatsuda: CI failure unrelated, "could you rerun it by rebasing" |
| [rails#59615](https://github.com/rails/rails/pull/59615) | perf | merged (amatsuda) | 0.9 h amatsuda (merge) | 0.9 h | +3/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59616](https://github.com/rails/rails/pull/59616) | perf | merged (amatsuda) | 1.1 h amatsuda (merge) | 1.1 h | +36/−1, 2f | 0 | 0 | merged, no comment |
| [rails#59617](https://github.com/rails/rails/pull/59617) | fix | draft | — | open | +80/−15, 4f | 5 | 0 | no response |
| [rails#59618](https://github.com/rails/rails/pull/59618) | perf | merged (amatsuda) | 1.5 h amatsuda (merge) | 1.5 h | +1/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59619](https://github.com/rails/rails/pull/59619) | perf | merged (amatsuda) | 0.7 h after ready, amatsuda (merge) | 1.4 h | +44/−15, 2f | 2 | 0 | merged, no comment |
| [rails#59620](https://github.com/rails/rails/pull/59620) | perf | merged (amatsuda) | 1.3 h amatsuda (merge) | 1.3 h | +49/−1, 3f | 1 | 0 | merged, no comment |
| [rails#59621](https://github.com/rails/rails/pull/59621) | fix | closed (kamipo) | 11.5 d kamipo (close) | 11.5 d | +47/−1, 3f | 4 | 0 | closed by kamipo's #59816, as #59609 |
| [rails#59623](https://github.com/rails/rails/pull/59623) | fix | closed (skipkayhil) | 0.4 h skipkayhil (comment) | 0.4 h | +2/−0, 1f | 0 | 0 | skipkayhil: "You must require active_support before cherry picking core extensions"; fixed in ransack#1792 instead |
| [rails#59624](https://github.com/rails/rails/pull/59624) | test | merged (amatsuda) | 0.6 h amatsuda (merge) | 0.6 h | +1/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59625](https://github.com/rails/rails/pull/59625) | fix | merged (amatsuda) | 0.7 h amatsuda (merge) | 0.7 h | +12/−3, 2f | 0 | 0 | merged, no comment |
| [rails#59626](https://github.com/rails/rails/pull/59626) | fix | merged (amatsuda) | 0.4 h after ready, amatsuda (merge) | 0.8 h | +14/−2, 2f | 0 | 0 | merged, no comment |
| [rails#59627](https://github.com/rails/rails/pull/59627) | restore | open | — | open | +8/−0, 2f | 0 | 0 | no response |
| [rails#59628](https://github.com/rails/rails/pull/59628) | restore | closed (us) | — | 6.2 d | +41/−0, 3f | 2 | 0 | no response; closed by us (few callers left) |
| [rails#59629](https://github.com/rails/rails/pull/59629) | restore | merged (kamipo) | 2.0 d seanpdoyle (comment) | 4.8 d | +6/−0, 2f | 0 | 0 | seanpdoyle: documented public method; etiennebarrie: aliasing `find!` "is correct"; merged by kamipo |
| [rails#59630](https://github.com/rails/rails/pull/59630) | restore | closed (us) | — | 41.5 h | +32/−0, 3f | 0 | 0 | no response; closed by us after matthewd's rule on #59663 |
| [rails#59634](https://github.com/rails/rails/pull/59634) | restore | merged (kamipo) | 1.5 h kamipo (comment) | 1.5 h | +48/−24, 15f | 0 | 0 | kamipo added his own commit; "overriding private APIs is at the gem's own risk" |
| [rails#59637](https://github.com/rails/rails/pull/59637) | fix | closed (yahonda) | 2.8 h yahonda (comment) | 2.8 h | +3/−2, 2f | 0 | 0 | yahonda: fixed in a Dalli patch release, main unreleased; "I'd prefer not to add a version gate" |
| [rails#59640](https://github.com/rails/rails/pull/59640) | fix | merged (amatsuda) | 1.5 h amatsuda (approved) | 1.5 h | +10/−1, 2f | 0 | 0 | amatsuda: "Looks good."; byroot after merge: "why even bother with the class name when `object_id` guarantee unicity?" and simplified it himself (#59714) |
| [rails#59642](https://github.com/rails/rails/pull/59642) | fix | merged (skipkayhil) | 16.9 h skipkayhil (commented) | 7.9 d | +48/−3, 5f | 8 | 2 | skipkayhil: "should this be something like `if opts.empty? parts = []`?", later asked for a rebase; merged by him |
| [rails#59644](https://github.com/rails/rails/pull/59644) | restore | open | — | open | +80/−1, 2f | 0 | 0 | no response |
| [rails#59659](https://github.com/rails/rails/pull/59659) | docs | closed (us) | — | 0.1 h | +0/−3, 1f | 1 | 0 | closed by us: byroot had already fixed the comment on main |
| [rails#59660](https://github.com/rails/rails/pull/59660) | restore | closed (us) | 22.8 h seanpdoyle (comment) | 24.1 h | +21/−0, 2f | 0 | 0 | seanpdoyle: "Depending on private methods and API is discouraged … reconsider this proposal in the context of adding a public method"; closed by us |
| [rails#59661](https://github.com/rails/rails/pull/59661) | fix | open | — | open | +109/−2, 4f | 0 | 0 | no response |
| [rails#59662](https://github.com/rails/rails/pull/59662) | fix | open | — | open | +68/−1, 5f | 3 | 0 | no response |
| [rails#59663](https://github.com/rails/rails/pull/59663) | restore | closed (matthewd) | 14.3 h matthewd (comment) | 14.3 h | +75/−0, 3f | 0 | 0 | matthewd: "We don't deprecate internal APIs. That's what internal means." |
| [rails#59667](https://github.com/rails/rails/pull/59667) | restore | closed (seanpdoyle) | 20.8 h seanpdoyle (comment) | 3.7 d | +50/−18, 3f | 0 | 0 | seanpdoyle approved, then closed it in favor of the merged #50312 |
| [rails#59668](https://github.com/rails/rails/pull/59668) | fix | open | — | open | +67/−0, 2f | 4 | 0 | no response |
| [rails#59671](https://github.com/rails/rails/pull/59671) | fix | draft | 2.9 d scarroll32 (comment) | open | +149/−8, 3f | 0 | 0 | scarroll32 (ransack, not a Rails maintainer) asked to be told when it merges; no Rails response |
| [rails#59672](https://github.com/rails/rails/pull/59672) | fix | closed (us) | — | 1.1 h | +194/−22, 3f | 0 | 0 | closed by us (rare case, parked) |
| [rails#59673](https://github.com/rails/rails/pull/59673) | fix | closed (us) | 11.1 h matthewd (comment) | 1.1 h | +38/−14, 2f | 0 | 0 | closed by us; matthewd afterwards: address it by consolidating the Ractor proxy's QueryRequest instead |
| [rails#59674](https://github.com/rails/rails/pull/59674) | perf | closed (us) | — | 1.1 h | +71/−3, 2f | 0 | 0 | closed by us (too small to move a request) |
| [rails#59675](https://github.com/rails/rails/pull/59675) | docs | draft | 18.5 h seanpdoyle (commented) | open | +19/−0, 1f | 4 | 1 | seanpdoyle cites rafaelfranca: moving view helpers is "Not really" a breaking change |
| [rails#59676](https://github.com/rails/rails/pull/59676) | fix | merged (matthewd) | 10.5 h matthewd (comment) | 36.6 h | +7/−1, 2f | 4 | 1 | matthewd: "that's a bug. We should probably fix it by adding a conditional"; reworked, merged by matthewd |
| [rails#59677](https://github.com/rails/rails/pull/59677) | perf | closed (us) | — | 0.2 h | +6/−6, 1f | 0 | 0 | closed by us (too small to move a request) |
| [rails#59734](https://github.com/rails/rails/pull/59734) | docs | open | — | open | +28/−0, 1f | 0 | 0 | no response |
| [rails#59735](https://github.com/rails/rails/pull/59735) | docs | open | — | open | +33/−0, 1f | 1 | 0 | no response |
| [rails#59800](https://github.com/rails/rails/pull/59800) | perf | open | — | open | +2/−15, 2f | 0 | 0 | no response |
| [rails#59803](https://github.com/rails/rails/pull/59803) | perf | closed (skipkayhil) | 2.8 h after ready, skipkayhil (comment) | 18.9 h | +3/−3, 1f | 2 | 0 | skipkayhil: "Let's fix this in the JITs?" |
| [rails#59804](https://github.com/rails/rails/pull/59804) | perf | open | 21.6 h after ready, seanpdoyle (commented) | open | +6/−3, 2f | 2 | 1 | seanpdoyle: change `text_field_tag` to skip `sanitize_to_id` for `id: nil` instead of re-implementing it at the call site |
| [rails#59808](https://github.com/rails/rails/pull/59808) | perf | closed (fatkodima) | 0.9 h fatkodima (comment) | 0.9 h | +38/−1, 2f | 0 | 0 | fatkodima: "does not look like a place worth optimizing, also given the complexity it adds and a tiny improvement it makes"; closed the draft |
| [rails#59809](https://github.com/rails/rails/pull/59809) | perf | merged (fatkodima) | 5.7 h after ready, fatkodima (merge) | 16.2 h | +1/−1, 1f | 0 | 0 | merged by fatkodima, no comment |
| [rails#59810](https://github.com/rails/rails/pull/59810) | perf | open | — | open | +14/−0, 2f | 0 | 0 | no response |
| [rails#59811](https://github.com/rails/rails/pull/59811) | perf | closed (skipkayhil) | 3.2 h after ready, skipkayhil (comment) | 9.9 h | +1/−1, 1f | 0 | 0 | skipkayhil: "Let's fix this in the JITs?" (became ruby#19909) |
| [rails#59812](https://github.com/rails/rails/pull/59812) | test | open | 14.5 h after ready, yahonda (comment) | open | +18/−12, 1f | 1 | 1 | yahonda: two independent issues, "split them into two separate pull requests"; split into #59817 |
| [rails#59817](https://github.com/rails/rails/pull/59817) | fix | open | — | open | +51/−8, 3f | 0 | 0 | no response |
| [rails#59824](https://github.com/rails/rails/pull/59824) | perf | draft | — | open | +7/−4, 2f | 1 | 0 | no response |
| [rails#59832](https://github.com/rails/rails/pull/59832) | perf | draft | 1.6 h fatkodima (commented) | open | +2/−0, 1f | 0 | 0 | fatkodima: "Won't just `return [] if @errors.empty?` be enough?" |

### ruby/ruby (13)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes | Rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [ruby#19483](https://github.com/ruby/ruby/pull/19483) | perf | closed (us) | — | 12.8 d | +264/−12, 4f | 2 | 0 | no response; closed by us (no `run_benchmarks.rb` effect beyond master A/A) |
| [ruby#19620](https://github.com/ruby/ruby/pull/19620) | fix | merged (nagachika) | 7.2 d nagachika (approved) | 7.2 d | +22/−0, 3f | 1 | 0 | merged by nagachika (3.4 backport), no comment |
| [ruby#19648](https://github.com/ruby/ruby/pull/19648) | fix | merged (XrXr) | 2.0 h after ready, k0kubun (commented) | 3.3 d | +9/−4, 4f | 4 | 2 | k0kubun: move it to `yjit.c`; XrXr prefers #19740 for the Ractor failure, request-changes for "shifting what this PR is"; reduced to the helper, merged by XrXr |
| [ruby#19655](https://github.com/ruby/ruby/pull/19655) | perf | closed (us) | — | 37.2 h | +55/−2, 4f | 2 | 0 | no response; closed by us (no ruby-bench effect) |
| [ruby#19670](https://github.com/ruby/ruby/pull/19670) | perf | closed (us) | — | 7.7 d | +159/−22, 6f | 2 | 0 | no response; closed by us after Kevin Newton's commits on master fixed the same regression |
| [ruby#19678](https://github.com/ruby/ruby/pull/19678) | perf | merged (k0kubun) | 0.1 h tekknolagi (commented) | 33.8 h | +262/−5, 8f | 4 | 2 | tekknolagi: raw strings, call `fix_to_s` directly, "makes it look like it's calling the actual method"; k0kubun: one if-else chain; merged by k0kubun |
| [ruby#19682](https://github.com/ruby/ruby/pull/19682) | perf | merged (k0kubun) | 7.4 h k0kubun (commented) | 30.7 h | +90/−19, 4f | 2 | 1 | k0kubun approve: memory of the profile slot, skip explicit block args, "I'd like to land a fix for the permanent exit"; merged by k0kubun |
| [ruby#19685](https://github.com/ruby/ruby/pull/19685) | perf | closed (us) | 45.3 h tekknolagi (comment) | 15.6 h | +80/−14, 3f | 0 | 0 | closed by us (no `run_benchmarks.rb` result); tekknolagi afterwards: "interesting and we should try to measure GC time" |
| [ruby#19699](https://github.com/ruby/ruby/pull/19699) | test | merged (XrXr) | 10.5 h tekknolagi (comment) | 17.8 h | +8/−4, 1f | 1 | 1 | tekknolagi: "Bucket them into one (concatenated) snapshot"; merged by XrXr |
| [ruby#19899](https://github.com/ruby/ruby/pull/19899) | perf | closed (us) | — | 26.9 h | +23/−11, 1f | 0 | 0 | no response; closed by us for byroot's #19905, which does the same check |
| [ruby#19909](https://github.com/ruby/ruby/pull/19909) | perf | merged (tekknolagi) | 17.5 h after ready, tekknolagi (commented) | 23.0 h | +233/−26, 3f | 1 | 1 | tekknolagi: name tests "condition+subject+outcome", approve "Nice"; merged by him |
| [ruby#19912](https://github.com/ruby/ruby/pull/19912) | perf | open | — | open | +595/−77, 13f | 2 | 0 | no response yet |
| [ruby#19919](https://github.com/ruby/ruby/pull/19919) | fix | closed (hsbt) | 16.7 h hsbt (comment) | 16.7 h | +11/−19, 3f | 0 | 0 | hsbt: not running `bundler/setup` in the prelude "is intentional"; use `-rbundler/setup` first; closed |

### ruby/ruby-bench (12)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes | Rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [ruby-bench#564](https://github.com/ruby/ruby-bench/pull/564) | fix | merged (k0kubun) | 17.8 h k0kubun (approved) | 17.8 h | +2/−3, 2f | 1 | 0 | k0kubun: "makes sense, thanks!" |
| [ruby-bench#565](https://github.com/ruby/ruby-bench/pull/565) | fix | merged (k0kubun) | 10.8 h k0kubun (approved) | 10.8 h | +3/−0, 1f | 0 | 0 | merged, no comment |
| [ruby-bench#566](https://github.com/ruby/ruby-bench/pull/566) | fix | merged (k0kubun) | 9.6 h k0kubun (approved) | 9.6 h | +4/−4, 1f | 0 | 0 | k0kubun merged #567 first, so #566 became empty: "it's my bad, you did nothing wrong" |
| [ruby-bench#567](https://github.com/ruby/ruby-bench/pull/567) | fix | merged (k0kubun) | 8.8 h k0kubun (approved) | 8.8 h | +204/−204, 4f | 0 | 0 | merged, no comment |
| [ruby-bench#568](https://github.com/ruby/ruby-bench/pull/568) | test | merged (k0kubun) | 6.7 h k0kubun (approved) | 6.7 h | +212/−217, 8f | 1 | 0 | merged, no comment |
| [ruby-bench#569](https://github.com/ruby/ruby-bench/pull/569) | tooling | open | — | open | +188/−0, 7f | 2 | 0 | no response |
| [ruby-bench#570](https://github.com/ruby/ruby-bench/pull/570) | fix | open | — | open | +34/−2, 2f | 2 | 0 | no response |
| [ruby-bench#571](https://github.com/ruby/ruby-bench/pull/571) | fix | open | — | open | +32/−19, 1f | 4 | 0 | no response |
| [ruby-bench#572](https://github.com/ruby/ruby-bench/pull/572) | fix | open | — | open | +34/−21, 2f | 4 | 0 | no response |
| [ruby-bench#574](https://github.com/ruby/ruby-bench/pull/574) | tooling | open | — | open | +335/−26, 9f | 2 | 0 | no response |
| [ruby-bench#575](https://github.com/ruby/ruby-bench/pull/575) | tooling | draft | — | open | +3657/−0, 133f | 2 | 0 | no response |
| [ruby-bench#579](https://github.com/ruby/ruby-bench/pull/579) | fix | open | — | open | +17/−12, 3f | 0 | 0 | no response |

### Gems (19)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes | Rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [ClosureTree/with_advisory_lock#150](https://github.com/ClosureTree/with_advisory_lock/pull/150) | fix | draft | — | open | +48/−1, 2f | 0 | 0 | no response |
| [activerecord-hackery/ransack#1792](https://github.com/activerecord-hackery/ransack/pull/1792) | fix | merged (scarroll32) | 29.6 h scarroll32 (merge) | 29.6 h | +1/−0, 1f | 0 | 0 | merged, no comment |
| [activerecord-hackery/ransack#1795](https://github.com/activerecord-hackery/ransack/pull/1795) | fix | merged (scarroll32) | 2.6 d after ready, scarroll32 (comment) | 2.6 d | +1/−1, 1f | 0 | 0 | merged; scarroll32 linked his follow-ups |
| [ankane/blind_index#62](https://github.com/ankane/blind_index/pull/62) | fix | closed (ankane) | 0.4 h ankane (close) | 0.4 h | +49/−5, 3f | 0 | 0 | ankane: "It should be fine to include this now." and fixed it in his own commit |
| [discourse/discourse#45658](https://github.com/discourse/discourse/pull/45658) | fix | open | — | open | +23/−2, 2f | 0 | 0 | no response |
| [inertiajs/inertia-rails#435](https://github.com/inertiajs/inertia-rails/pull/435) | fix | merged (skryukov) | 27.9 d skryukov (approved) | 27.9 d | +82/−17, 7f | 0 | 0 | our ping 11-17 07:04; merged 3.7 h later by skryukov with two commits of his, right after #444 fixed his CI |
| [inertiajs/inertia-rails#441](https://github.com/inertiajs/inertia-rails/pull/441) | perf | merged (skryukov) | 14.3 d skryukov (approved) | 14.3 d | +11/−8, 2f | 0 | 0 | merged by skryukov after merging master, right after #444 |
| [inertiajs/inertia-rails#444](https://github.com/inertiajs/inertia-rails/pull/444) | test | merged (skryukov) | 0.2 h skryukov (approved) | 0.2 h | +11/−10, 4f | 0 | 0 | skryukov: "Thanks @thomasklemm!" |
| [pond/scimitar#172](https://github.com/pond/scimitar/pull/172) | fix | draft | — | open | +29/−1, 2f | 0 | 0 | no response |
| [rmosolgo/graphql-ruby#5877](https://github.com/rmosolgo/graphql-ruby/pull/5877) | fix | merged (rmosolgo) | 2.1 h rmosolgo (merge) | 2.1 h | +235/−223, 4f | 0 | 0 | rmosolgo: "Thanks for this improvement! I just shipped this change" |
| [rmosolgo/graphql-ruby#5880](https://github.com/rmosolgo/graphql-ruby/pull/5880) | perf | merged (rmosolgo) | 2.6 h rmosolgo (comment) | 2.6 h | +9/−11, 1f | 0 | 0 | rmosolgo merged, asked ydah to look; ydah: "doesn't alter the behavior. Looks good to me!" |
| [rmosolgo/graphql-ruby#5881](https://github.com/rmosolgo/graphql-ruby/pull/5881) | perf | merged (rmosolgo) | 2.7 h rmosolgo (merge) | 2.7 h | +821/−867, 2f | 0 | 0 | rmosolgo merged; ydah: "valid optimization", one duplication nit he followed up himself |
| [ruby/date#199](https://github.com/ruby/date/pull/199) | fix | merged (jeremyevans) | 9.4 d jeremyevans (comment) | 12.4 d | +28/−6, 2f | 2 | 1 | jeremyevans: the body's "as for Integer" was wrong (`1 < Float::NAN` is false); body fixed and code reworked, merged |
| [skryukov/rails_vite#57](https://github.com/skryukov/rails_vite/pull/57) | perf | merged (skryukov) | 23.6 d skryukov (merge) | 23.6 d | +68/−1, 3f | 0 | 0 | merged by skryukov after 23.6 days, no comment |
| [sparklemotion/sqlite3-ruby#769](https://github.com/sparklemotion/sqlite3-ruby/pull/769) | perf | open | 7.0 d after ready, flavorjones (comment) | open | +21/−1, 2f | 4 | 0 | flavorjones (agent-tagged comment): "Thanks, I'll review!" |
| [sparklemotion/sqlite3-ruby#770](https://github.com/sparklemotion/sqlite3-ruby/pull/770) | perf | open | 6.1 d after ready, flavorjones (comment) | open | +10/−1, 1f | 5 | 0 | flavorjones: "Thanks, I'll review!" |
| [sparklemotion/sqlite3-ruby#773](https://github.com/sparklemotion/sqlite3-ruby/pull/773) | test | merged (flavorjones) | 6.1 d flavorjones (comment) | 6.1 d | +5/−4, 3f | 0 | 0 | flavorjones: "Thanks, I'll review!", merged 4 h later |
| [trailblazer/cells-rails#75](https://github.com/trailblazer/cells-rails/pull/75) | fix | open | 0.2 h apotonick (comment) | open | +9/−0, 2f | 0 | 0 | apotonick: "what is Lowrail?" (body had the old footer) |
| [tzinfo/tzinfo#175](https://github.com/tzinfo/tzinfo/pull/175) | perf | open | — | open | +1/−0, 1f | 0 | 0 | no response |
