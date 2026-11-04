# Upstream PR retrospective (2026-11-04)

Every upstream PR by thomasklemm opened from 2026-10-15 to 2026-11-04 in rails/rails, ruby/ruby, ruby/ruby-bench and
the gems: 111 PRs (47 Rails, 34 Ruby, 30 gems and ruby-bench). Not included: argos-ri, roundhouse-rb, Campfire,
matz/spinel, rubycdp and personal repos. GitHub state, comments, reviews and timeline as of 2026-11-04 10:30 UTC
(GraphQL, read only), plus the [ledger](contributions.md). Others' recent ruby/ruby ZJIT PRs and the ZJIT
contributing guide were read for comparison. Nothing was posted.

How the columns are counted: *first maintainer response* is the first comment, review, merge or close by someone
other than us or a bot; *pushes* are force-pushes plus commits dated after opening, one per minute; a *review round*
is maintainer feedback (not a plain approval) followed by a push of ours before the next feedback. For a closed PR
the diff is its last head.

## Zusammenfassung für Thomas

**Rails läuft, ruby/ruby nicht.** Von 47 Rails-PRs sind 39 gemergt, im Median 1,9 Stunden nach dem Öffnen, 34 davon ohne
einen Push danach; ein gemergter PR ändert im Median 9 Zeilen in einer Datei. Von 34 ruby/ruby-PRs sind 7
gemergt, 14 geschlossen und 13 offen. Die Maintainer antworten schnell (Median 4 Stunden), am Tempo der Antworten
liegt es also nicht. Gemergt wird fast nur Korrektheit: 6 der 7 sind Bugfixes, Diagnose oder ein Backport, mit
Repro und kleinem Test. Von 23 Performance-PRs ist einer gemergt (#19484), zwei sind approved, 14 geschlossen.

**Was bei Rails anders ist.** Ein Maintainer (amatsuda) macht gerade selbst eine Serie von Mikro-Optimierungen und
hat fatkodimas Einwand „nicht jeder Code muss optimiert werden“ auf #59236 mit 15 % Gewinn über die ganze Serie
beantwortet. Unsere PRs passen genau in seine Serie: eine Stelle, ein paar Zeilen, gleiches Verhalten, eine
Messtabelle. #59596–#59598 sind das Muster: von dir vorher gelesen, 2–9 Zeilen, nach 1,3–1,5 Stunden gemergt. Ärger
gab es nur, wo der Code komplizierter wurde (#59577: fatkodima „komplexer und hässlicher für fraglichen Nutzen“,
danach hat kamipo dieselbe Stelle strukturell gelöst, #59590) oder wo die Messung den häufigen kleinen Fall
übersehen hat (#59584: amatsuda hat gemessen, dass es auf kleinen Dokumenten langsamer wird). Das Risiko: der Erfolg
hängt an einem Maintainer.

**Was bei ruby/ruby schiefging, in der Reihenfolge des Schadens.**

1. *Menge.* Am 22.10. haben wir 7 PRs an einem Tag geöffnet, und am 23.10. schrieb tekknolagi auf #19488, dass er
   „walls of AI-generated text“ nicht schätzt und dass sie „the deluge of your PRs“ nicht schnell reviewen können.
   Danach kamen am 2./3.11. 18 PRs in 28 Stunden, acht davon zu `Hash.new`/`opt_new` innerhalb von zwei Stunden.
   k0kubun schrieb dazu auf #19671: keine Kapazität für „five YJIT performance improvement PRs per day“. Von diesen
   18 ist bis heute einer gemergt (#19660).
2. *Nutzen unter dem Rauschen.* #19478, #19488, #19558, #19625, #19662, #19667 und #19680 hatten auf ruby-bench
   keinen Effekt über A/A. Weniger Fallbacks, weniger Exits oder Mikro-Benchmarks allein überzeugen dort nicht.
3. *Eingriffe ins Design ohne Absprache.* #19555 hat die Bedeutung von `no_side_exits` erweitert; XrXr fand das
   falsch, und auf einem fremden PR (#19658) führt er es inzwischen als Beispiel an, wie „an LLM agent“ falsch
   entscheidet. Die ZJIT-Doku sagt ausdrücklich: größere Änderungen erst im Zulip-Chat oder in einem Shopify/ruby-Issue
   besprechen.
4. *Zu enge Fixes in Code, den ein Maintainer gerade umbaut.* byroot nannte #19660 „too narrow“ und #19661 „a good
   catch, but the patch ain't very good“ und hat es dann in einer Stunde selbst gemacht (#19703). Damit waren #19661
   und #19663 erledigt.
5. *YJIT.* Sechs YJIT-Performance-PRs, bevor klar war, dass YJIT im Wartungsmodus ist. Diese Regel haben wir jetzt.

**Was die ruby/ruby-Leute wollen.** k0kubun: echte Benchmarks statt synthetischer, wenig zusätzliche Komplexität,
Asserts, wo Code sich auf eine andere Funktion verlässt, kein dauerhafter Speicher für kleinen Gewinn, Belege im
Format der eigenen Tools. byroot: die allgemeine Lösung am richtigen Ort statt eines Spezialfalls; schreibt es
lieber selbst. XrXr: Tests, die genau eine Sache prüfen; bei YJIT nur noch Bugfixes; Spekulations-Design ist
Absicht, nicht anfassen ohne Rücksprache. tekknolagi: kurze, lesbare Texte, ruby-bench-Zahlen, eine JIT pro PR, HIR,
die zeigt, was wirklich passiert, und Namen, die nicht täuschen. jhawthorn: nichts in `vm_exec_core` für Randfälle.
Für das ganze ZJIT-Team (tekknolagi auf Shopify/ruby#1085 und #19633): LLM-Nutzung nicht vermerken, aber „you must
stand behind your contribution as if unaided, and be able to explain every last detail of it.“

**Wann ein Issue besser war.** Wo wir zuerst im Tracker gefragt haben (Shopify/ruby#1091, #1064, #1065, #1100),
kamen ein „go for it“, oft mit einer Design-Vorgabe, und danach schnellere und freundlichere Reviews (#19682 nach 7
Stunden approved, #19678 nach wenigen Minuten im Review). Ohne vorherige Frage wurden Design-Änderungen geschlossen
(#19555, #19558, #19488). Ein Issue ohne konkrete Bitte (#1099) half dagegen auch nicht.

**Der unbequeme Punkt.** Die ZJIT-Leute erkennen Agentenarbeit, auch ohne Hinweis, und erwarten, dass du jede
Review-Frage selbst beantworten kannst. Die Regel, dass du es vorher erklären kannst, reicht dafür nicht: es muss
auch für das Review-Gespräch gelten. Das ist die wichtigste Entscheidung, bevor der ruby/ruby-Stopp aufgehoben wird.

**Gems.** 24 Gem-PRs sind offen, und keiner hat eine Antwort; viele warten auf die Freigabe der Workflows für
Erstbeitragende. Gemergt wurden die vier, bei denen der Maintainer aktiv war (connection_pool, caxlsx, sqlite3-ruby,
Prism), meist nach einer kleinen Stilfrage. Zwei waren Duplikate, die wir übersehen hatten.

Die Regel-Vorschläge stehen unten auf Englisch, jeweils mit den PRs als Beleg.

## Numbers by repository

| | PRs | Merged | Closed | Open | Median first maintainer response | Median open → merge | Median diff, merged / closed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| rails/rails | 47 | 39 (all by amatsuda) | 1 | 7 | 1.7 h (mostly the merge itself) | 1.9 h | 9 / 19 lines |
| ruby/ruby | 34 | 7 | 14 | 13 (4 approved) | 4.1 h | 2.4 d | 70 / 116 lines |
| gems and ruby-bench | 30 | 4 | 2 | 24 (none answered) | 6.3 h (6 PRs answered) | 2.4 d | 35 / 25 lines |

ruby/ruby by kind: 11 correctness, diagnostics, backport or test PRs, of which 6 merged and 2 approved; 23 performance
PRs (fallbacks, exits, allocations, compile time), of which 1 merged, 2 approved and 14 closed. Of the 14 closed, 10
were closed by us after a maintainer's objection, a missing effect or byroot's rework, 3 after the YJIT
maintenance-mode decision, and 1 by tekknolagi (#19671).

Pushes after opening: 34 of 39 merged Rails PRs needed none. The ruby/ruby PRs with the most pushes were #19484 (6,
merged after 11 days), #19488 (5, closed), #19661 (5 in 32 hours, closed) and #19678 (4, open).

## What separated fast landings from closures

| | Landed fast | Closed, superseded or criticized |
| --- | --- | --- |
| Size | Rails 1–9 lines in one file (#59596 +8/−1, #59597 +8/−1, #59598 +1/−1); ruby #19554 +22, #19660 +23 | #19662 +937/−62 in 18 files, #19667 +343/−39 in 22 files, #19488 +242/−28 |
| Kind | a correctness bug with a repro (#19538, #19554, #19586, #19660), or one exact allocation at one Rails site | performance below the ruby-bench A/A (#19478, #19488, #19558, #19625, #19680) |
| Design | uses guards and structures that already exist (k0kubun on #19484: "we already added appropriate guards") | changes policy: `no_side_exits` (#19555), profile classification (#19558), `vm_exec_core` (#19667) |
| Timing | one PR per finding | 8 PRs on one finding in two hours (#19660–#19667), 18 PRs in 28 hours |
| Area | nobody else is working there | the maintainer is reworking it: byroot's `String.new` (#19674) and #19703; kamipo's #59590 |
| Text | short body; for Rails one table; replies under 200 characters (#59270, #59562, caxlsx#550) | long replies: #19488 (two tables, a menu of options), #19680 (1,949 characters), #19682 (2,985 characters, a 25-column table); #19682 has no reply yet |
| Response to review | does what was asked (#19586, #19648, #59270, caxlsx#550) | asks the maintainer to pick between options (#19663, #19488); neither question was answered |

The four cases named in the request:

* **#19661 → byroot's #19703.** #19660 (the redefinition bug) merged, but byroot had already called its fix too
  narrow, because the same problem comes back with `String.new` in his open #19674. We opened #19661–#19667 on the
  same mechanism two hours after #19660, before any review. byroot: "As with the other issues, it's a good catch, but
  the patch ain't very good", then #19703 (+66/−64), which he opened and merged within an hour. Our closing comment
  pointed out that `String` and `Array` have the same issue, which jhawthorn had already turned down on #19667;
  byroot: "I know, it's being worked on."
* **#19680.** It came out of the issue process (tekknolagi: "Go for it"). k0kubun asked for a compile-time-only cache
  (no permanent memory "just to speed up compilation time by a small amount") and for evidence in the tools' own
  format, not "your comparison table in markdown showing only %". Reworked, it saved 1.2% of compile instructions
  with no `run_benchmarks.rb` effect, so we closed it.
* **YJIT #19663–#19666, #19671.** These were opened on 2026-11-03, before XrXr's "YJIT is mainly in maintenance mode
  for bug fixes" (#19664) and k0kubun's "Could you send performance improvement patches mainly to ZJIT?" (#19671).
  None was a correctness fix. tekknolagi closed #19671 the same day ("Closing.").
* **rails #59577 → #59590.** Its first version needed four internal review rounds for exactness (to_ary,
  singleton methods, live Hash iteration), a sign that the code had become hard to read.
  fatkodima asked how sites are chosen and whether the complexity is worth it; we shrank it to +16/−3 and answered in
  1,678 characters. kamipo then rewrote `column_references` from the built nodes (#59590, +65/−52), which covered
  ours.
* **Evidence format and readability.** k0kubun's request on #19680 is above. tekknolagi's complaint about Shopify/ruby#1058
  ("LLM shorthand") had a predecessor ten days earlier on #19488: "I do not appreciate the walls of AI-generated
  text; don't do that". The plain-language rule came after the second complaint, not the first.

## ruby/ruby: what each maintainer values and dislikes

From their comments on our PRs and on others' recent ZJIT PRs (#19479, #19501, #19508, #19603, #19633, #19658).

**k0kubun** (most reviews; approves fast when the fix is real)

* Values: real benchmarks ("We're not necessarily interested in fixing a synthesized benchmark with a narrowly-scoped
  fix … check … `--headline` benchmarks", #19478); asserts where code relies on another function's invariant
  (#19478, #19485 `is_send()`); simple data structures (#19485: a `HashMap` from the start instead of rebuilding a
  `HashSet` on every send); permanent exits fixed ("I'd like to land a fix for the permanent exit", #19682);
  incremental commits ("the separation in commits are helpful", #19488); his model for evidence is #19603: one sentence
  per commit, then a ZJIT stats diff in diff format per benchmark.
* Dislikes: complexity for things that don't need optimizing (#19488); permanent memory for small gains (#19680,
  #19682); markdown tables of percentages (#19680); code structure where one case looks special (#19678); a shared
  `jit.c` helper used by only one JIT (#19648); `with_jit` Ruby rewrites before checking the interpreter (#19501);
  YJIT performance work (#19671).

**byroot** (VM core, `opt_new`, Hash/String)

* Values: the general fix at the right layer ("the fix is too narrow IMO, because the problem is the same for
  `String.new`", #19660); thinking in contracts ("the contract is `.new`", #19663); less invasive over faster (#19703:
  "slightly slower, but less invasive"). He writes the fix himself when he sees it.
* Dislikes: patches that work but sit at the wrong place (#19661); being told what he already knows (#19661).

**XrXr** (YJIT and ZJIT; merges most ZJIT PRs)

* Values: tests that test one thing ("Please split into two tests … get rid of the stuff about inlining … off topic
  IMO: it's language behavior", #19586; disable inlining so it doesn't distract, #19484); a high bar of verification
  in risky YJIT code (#19664).
* Dislikes: YJIT performance PRs (#19664); changing what a policy flag means to get a result (#19555: "muddies what
  `no_side_exits` means"). On #19658 he says the speculation aggressiveness is intentional and calls this "the
  second time an LLM agent decided that `self.policy.no_side_exits` should guide decision to put a patchpoint",
  linking our #19555.

**tekknolagi** (ZJIT; tracker owner, quick and direct)

* Values: ruby-bench numbers ("we rely a lot on benchmark numbers for changes", #19488); one JIT per PR (#19661);
  checking the mechanism ("Are you sure this is ever being inlined … Look at the HIR", #19625); HIR and code that
  say what they do ("This makes it look like it's calling the actual method, which we no longer are", #19678); turns
  a good observation into a tracker issue himself (#19625 → Shopify/ruby#1094).
* Dislikes: AI-generated walls of text (#19488, Shopify/ruby#1058); PR volume ("the deluge of your PRs", #19488);
  very specific fixes where a general mechanism is planned (#19555); LLM attribution in ZJIT work, with the rule
  "You must stand behind your contribution as if unaided, and be able to explain every last detail of it"
  (Shopify/ruby#1085, #19633).

**jhawthorn**: no added complexity in `vm_exec_core` for edge cases, answered within 30 minutes (#19667).

**The ZJIT team in general** ([doc/jit/zjit.md, Contributing](https://github.com/ruby/ruby/blob/master/doc/jit/zjit.md#contributing)):
bug reports with a small repro are "very valuable"; for a large patch, "chat on Zulip … and then open an issue on
the Shopify/ruby repository so that we can have a technical discussion", because large unannounced PRs often "do
not fit within the design". Small PRs that close a tracker issue and show the stats diff merge without fuss
(femto's #19479 +28, nozomemein's #19508). An outside contributor's well-researched design change (#19658, Mastodon
data) was closed the same way as our #19555.

## When an issue was better than a PR

* **Better as an issue first:** #19555 (recompile policy; the team had its own plan, k0kubun's #19617), #19558
  (profile classification; dak2 proposed a simpler design in review), #19488 (k0kubun preferred work on a different
  fallback), #19661–#19663 (byroot was reworking `opt_new`; one bug report on #19660 would have had the same result),
  #19662 (+937 lines). In each case the maintainer's answer was about direction, not code, and could have come
  before the code.
* **Issue first worked:** Shopify/ruby#1091 → #19678 (tekknolagi: "Sure, that is fine"), #1064/#1065 → #19680/#19681
  ("Go for it", with the constraint of no Vec per CCall, which #19681 follows), #1100 → #19682 (k0kubun: "It's free
  to take"; approved within 7 hours). tekknolagi's own #1094 → #19659.
* **Issue did not help:** Shopify/ruby#1099 (data without one concrete ask; closed by us), #1058 (unreadable reply).
* **A PR was right:** correctness fixes with a repro (#19538, #19554, #19586, #19660); the team merges them in 1–3
  days without discussion.

## Rule proposals for DECISIONS

Status: **New**, **Sharpen** (an existing rule, named) or **Exists** (no change needed). Proposals that change one of
Thomas's decisions are marked *(Thomas)*.

1. **Pace of ruby/ruby PRs.** *New.* When the stop is lifted: at most two new ruby/ruby PRs a week; the next one
   opens only after the previous one has a maintainer response; never more than one open PR from the same finding.
   Evidence: 7 PRs on 2026-10-22, followed by tekknolagi's "deluge" warning (#19488); 18 PRs in 28 hours on
   2026-11-02/03, followed by k0kubun's bandwidth comment (#19671), with one of the 18 merged; 8 PRs on `opt_new`
   within two hours (#19660–#19667).
2. **Thomas owns the review conversation.** *Sharpen "Thomas can explain it first"* *(Thomas)*. The rule covers the
   reviews too: Thomas can answer every review question on a ruby/ruby PR himself, in his own words. For ZJIT work we
   follow the team's rule: no LLM attribution, and only a contribution he can "stand behind … as if unaided" and
   explain "every last detail" of. This replaces "where it matters (as on #1058) we say so plainly" for ZJIT threads.
   Evidence: tekknolagi on Shopify/ruby#1085 and #19633; XrXr naming #19555 an LLM agent's decision on #19658;
   "walls of AI-generated text" on #19488.
3. **Ask before changing ZJIT design.** *Sharpen "Well-reviewed PRs over issue discussions" and "Performance leads
   never become issues on their own"* *(Thomas)*. A ZJIT change that alters profiling, speculation, invalidation or
   recompile policy, adds per-ISEQ or per-profile state or new HIR instructions, or exceeds about 150 lines opens
   only after the team agreed to the approach on the tracker: a short comment on the existing Shopify/ruby issue, or,
   with Thomas's OK, a new issue that states the measured effect and the planned approach in a few sentences.
   Implementing an issue the team filed or answered ("free to take") needs no extra step. Evidence: the ZJIT
   contributing guide; #1091, #1064, #1065 and #1100 compared with #19555, #19558, #19488 and #19662.
4. **The ruby-bench effect comes first.** *Sharpen the readability gate's ruby/ruby sentence.* Fewer fallbacks,
   exits, allocations or compile instructions don't count on their own. A ruby/ruby performance PR needs a
   `run_benchmarks.rb` effect outside A/A, unless the team asked for the change on the tracker or it removes a
   permanent side exit. Evidence: #19478, #19488, #19558, #19625, #19662, #19667, #19680 closed; #19682 approved
   (permanent exit, asked for on #1100).
5. **One comparison, short text.** *Sharpen "ZJIT evidence in the tools' own format" and "Plain language
   upstream".* One base, one A/A and one head in `run_benchmarks.rb` output; a stats diff with only the counters that
   move; at most one such block per comment; under about 120 words of prose, with the answer in the first sentence.
   Alternatives we tried go in our docs, not in the thread. Evidence: k0kubun on #19680; our #19682 reply (2,985
   characters, five builds, a 25-column table) still unanswered; short replies on #19586, #19648, #59270, #59562 and
   caxlsx#550 led straight to approval or merge.
6. **Show the mechanism on the real shape.** *New.* Before opening, the evidence shows that the fast path fires at
   the real site: HIR or disassembly for JIT changes, and a micro built from the shape the app or ruby-bench actually
   uses, including the smallest common input. Evidence: #19625 (nothing was inlined, and the `{ |i| }` micro hid the
   parameterless blocks optcarrot uses); #59584 (amatsuda found it slower on small documents); #19665 was relayed as
   a correctness fix and isn't one.
7. **Don't build on a fix a maintainer called narrow.** *Sharpen "Search before building".* Search also covers the
   last two weeks of commits and open PRs by the maintainers on the same functions. When a maintainer is reworking
   the code, or calls our fix too narrow, land only the minimal correctness fix, report what else we saw in our docs,
   and open no follow-ups. Evidence: #19660 ("too narrow", byroot's #19674 open) followed by #19661–#19667 and
   then #19703; rails #59577 and kamipo's #59590.
8. **Do what the reviewer asked, or name one blocker.** *New.* Implement a maintainer's suggestion, or state in one
   sentence the one concrete reason it doesn't work, with the measurement. Don't hand the maintainer a menu.
   Evidence: our two-option questions on #19663 and #19488 went unanswered; #19586, #19648, #59270, #59562, caxlsx#550
   and connection_pool#225 merged or were approved within hours of doing what was asked.
9. **Closing comments don't reopen decisions.** *Sharpen "Closing comments".* The one neutral fact must not repeat a
   point a maintainer already turned down or tell them about their own work in progress. Evidence: the #19661
   closing comment repeated #19667's point (declined by jhawthorn); byroot: "I know, it's being worked on."
10. **Tests test one thing.** *New.* ruby/ruby tests check exactly the changed behavior and fail without the fix: one
    test per case, no unrelated settings (inlining) and no language-semantics checks; an assert wherever the change
    relies on another function's invariant. Evidence: XrXr on #19586 (changes requested) and #19484; k0kubun on
    #19478 and #19485.
11. **Report ZJIT memory.** *New.* A ZJIT change that adds state per ISEQ, profile entry or compile reports
    `zjit_alloc_bytes` against base with an A/A, and prefers state that is dropped after compile. Evidence: k0kubun
    on #19680 (permanent memory) and #19682 (where to store the flag); on #19682 we measured three layouts and chose
    the free one.
12. **YJIT in maintenance mode, one concern per PR, no stacking.** *Exists.* Evidence: #19664, #19671, #19661,
    #19662. The YJIT PRs were opened before these rules; they need no change.
13. **Rails: keep the pattern.** *Exists (rails/rails body, readability gate).* Small exact diffs at one site, read
    by Thomas, with one table. Add one sentence: an L2 candidate, or one that needs more than two exactness review
    rounds, is rewritten more simply or dropped instead of opened. Evidence: 39 merged at a median of 9 lines; #59577
    went through four exactness rounds and drew the only Rails "is it worth it" objection of this cycle; #59584's
    full variant needed six rounds and was replaced by the simple one before it opened.
14. **Gems: at most two unanswered PRs per repository.** *New* *(Thomas; changes "no per-gem limit")*. Before
    opening, check that the maintainers merged an outside PR recently, and follow the repository's idioms (`is_a?`
    in caxlsx, no extracted constants for mperham). Evidence: 24 open gem PRs with no maintainer response, 4 in i18n
    since 2026-11-03 and 3 in rubocop-performance since 2026-10-22; the merged ones (connection_pool, caxlsx, sqlite3-ruby, Prism)
    came from active maintainers, two after a style request; the duplicates cbor-ruby#43 and tiktoken_ruby#132 were
    already covered by "Search before building".

## Appendix: every PR

Kind, outcome and the maintainer's words for each of the 111 PRs. "Merged, no comment" means the merge was the only
response.

### ruby/ruby (34)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes after opening | Review rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [ruby#19478](https://github.com/ruby/ruby/pull/19478) | ZJIT perf | closed (us) | 10.8 h k0kubun (commented) | 12.5 h | +68/−12, 3f | 1 | 1 | k0kubun: wants an assertion for the coupling; "not necessarily interested in fixing a synthesized benchmark"; fold into #19488 |
| [ruby#19483](https://github.com/ruby/ruby/pull/19483) | ZJIT perf | open | — | open | +264/−12, 4f | 2 | 0 | no maintainer response in 13 days |
| [ruby#19484](https://github.com/ruby/ruby/pull/19484) | ZJIT perf (fallbacks) | merged (XrXr) | 10.3 h k0kubun (approved) | 11.3 d | +85/−18, 4f | 6 | 0 | k0kubun approve ("we already added appropriate guards"); XrXr: disable inlining in the recompile test |
| [ruby#19485](https://github.com/ruby/ruby/pull/19485) | ZJIT stats fix | merged (XrXr) | 21.7 h k0kubun (commented) | 7.1 d | +79/−33, 2f | 3 | 1 | k0kubun: test in Rust, use a HashMap instead of rebuilding a HashSet, add `is_send()` assert |
| [ruby#19487](https://github.com/ruby/ruby/pull/19487) | YJIT perf | open | 3.9 h k0kubun (approved) | open | +83/−2, 2f | 3 | 0 | k0kubun approve ("I care about its performance too"); unmerged since 10-22 |
| [ruby#19488](https://github.com/ruby/ruby/pull/19488) | ZJIT perf | closed (us) | 4.1 h k0kubun (comment) | 3.9 d | +242/−28, 5f | 5 | 1 | k0kubun: "we don't necessarily want to build up the complexity"; tekknolagi: "do not appreciate the walls of AI-generated text", "deluge of your PRs" |
| [ruby#19492](https://github.com/ruby/ruby/pull/19492) | YJIT diagnostics | open | 3.0 h k0kubun (approved) | open | +35/−2, 2f | 2 | 0 | k0kubun approve ("sure."); unmerged since 10-22 |
| [ruby#19538](https://github.com/ruby/ruby/pull/19538) | ZJIT correctness | merged (XrXr) | 6.3 h k0kubun (approved) | 3.1 d | +59/−11, 3f | 1 | 0 | k0kubun approve: "I'm not sure how you found it, but thanks for catching it." |
| [ruby#19554](https://github.com/ruby/ruby/pull/19554) | YJIT correctness | merged (XrXr) | 2.9 h XrXr (approved) | 2.4 d | +22/−0, 3f | 0 | 0 | XrXr approve; k0kubun: backport |
| [ruby#19555](https://github.com/ruby/ruby/pull/19555) | ZJIT perf (recompile policy) | closed (us) | 3.0 h XrXr (commented) | 2.9 d | +195/−27, 7f | 2 | 2 | XrXr: "doesn't feel like the right change", muddies `no_side_exits`; tekknolagi: hold, "very specific"; later cited by XrXr on #19658 as an LLM-agent mistake |
| [ruby#19558](https://github.com/ruby/ruby/pull/19558) | ZJIT perf (profiling) | closed (us) | 1.8 h dak2 (commented) | 7.8 d | +94/−22, 4f | 1 | 1 | dak2 (contributor) proposed a simpler classification; closed by us, no timing effect |
| [ruby#19586](https://github.com/ruby/ruby/pull/19586) | ZJIT correctness | merged (XrXr) | 1.8 h XrXr (changes_requested) | 26.6 h | +74/−12, 2f | 1 | 1 | XrXr request-changes: split tests, drop the inlining and language-behavior parts; then approve |
| [ruby#19619](https://github.com/ruby/ruby/pull/19619) | backport | merged (k0kubun) | 7.8 h k0kubun (approved) | 7.8 h | +22/−0, 3f | 0 | 0 | k0kubun approve and merge |
| [ruby#19620](https://github.com/ruby/ruby/pull/19620) | backport | open | — | open | +22/−0, 3f | 0 | 0 | no response |
| [ruby#19625](https://github.com/ruby/ruby/pull/19625) | ZJIT perf | closed (us) | 3.1 h tekknolagi (comment) | 3.0 d | +71/−12, 6f | 1 | 0 | tekknolagi: "Are you sure this is ever being inlined? … Look at the HIR"; no benchmark difference, not worth merging |
| [ruby#19648](https://github.com/ruby/ruby/pull/19648) | YJIT correctness | open | 2.3 h k0kubun (commented) | open | +22/−3, 5f | 2 | 0 | k0kubun: move the helper to yjit.c; approve |
| [ruby#19655](https://github.com/ruby/ruby/pull/19655) | ZJIT parity | open | — | open | +55/−2, 4f | 2 | 0 | no response |
| [ruby#19659](https://github.com/ruby/ruby/pull/19659) | ZJIT perf | open | — | open | +259/−14, 4f | 0 | 0 | no response (follows tekknolagi's Shopify/ruby#1094) |
| [ruby#19660](https://github.com/ruby/ruby/pull/19660) | VM correctness | merged (byroot) | 15.7 h byroot (commented) | 16.6 h | +23/−0, 2f | 1 | 1 | byroot: "good catch but the fix is too narrow" (String.new in #19674); merged with his change |
| [ruby#19661](https://github.com/ruby/ruby/pull/19661) | VM perf | closed (us) | 14.3 h tekknolagi (comment) | 32.0 h | +18/−2, 4f | 5 | 2 | tekknolagi: "Please don't mix YJIT and ZJIT PRs"; byroot: "good catch, but the patch ain't very good", rewrote it as #19703 |
| [ruby#19662](https://github.com/ruby/ruby/pull/19662) | ZJIT perf | closed (us) | — | 20.6 h | +937/−62, 18f | 2 | 0 | +937/−62 in 18 files, stacked; closed by us before review |
| [ruby#19663](https://github.com/ruby/ruby/pull/19663) | YJIT perf | closed (us) | 12.5 h byroot (comment) | 32.9 h | +98/−18, 4f | 3 | 1 | byroot: call `rb_hash_s_new` instead of `#initialize`; our either/or question unanswered; obsolete after #19703 |
| [ruby#19664](https://github.com/ruby/ruby/pull/19664) | YJIT perf | closed (us) | 12.4 h XrXr (commented) | 32.8 h | +56/−6, 2f | 0 | 0 | XrXr: "YJIT is mainly in maintenance mode … unlikely to take it for the next release" |
| [ruby#19665](https://github.com/ruby/ruby/pull/19665) | YJIT perf | closed (us) | — | 32.5 h | +116/−0, 5f | 0 | 0 | no response; closed under maintenance mode |
| [ruby#19666](https://github.com/ruby/ruby/pull/19666) | YJIT perf | closed (us) | — | 32.4 h | +123/−6, 6f | 0 | 0 | no response; closed under maintenance mode |
| [ruby#19667](https://github.com/ruby/ruby/pull/19667) | VM perf | closed (us) | 0.5 h jhawthorn (comment) | 0.9 h | +343/−39, 22f | 3 | 0 | jhawthorn after 30 min: "I don't think we should do this" (cost of complexity in `vm_exec_core`) |
| [ruby#19670](https://github.com/ruby/ruby/pull/19670) | VM 4.1 regression fix | open | — | open | +55/−9, 7f | 0 | 0 | no response |
| [ruby#19671](https://github.com/ruby/ruby/pull/19671) | YJIT perf | closed (tekknolagi) | 0.7 h k0kubun (comment) | 12.4 h | +165/−7, 4f | 0 | 0 | k0kubun: "Could you send performance improvement patches mainly to ZJIT?", no bandwidth for "five YJIT performance improvement PRs per day"; tekknolagi: "Closing." |
| [ruby#19678](https://github.com/ruby/ruby/pull/19678) | ZJIT alloc (issue-first) | open | 0.1 h tekknolagi (commented) | open | +262/−5, 8f | 4 | 2 | tekknolagi: four readability points (raw strings, call `fix_to_s` directly, HIR name misleads); k0kubun: restructure as one if-else chain |
| [ruby#19680](https://github.com/ruby/ruby/pull/19680) | ZJIT compile time (issue-first) | closed (us) | 10.6 h k0kubun (comment) | 14.4 h | +25/−1, 3f | 0 | 0 | k0kubun: compile-time cache only, no permanent memory; "haven't appreciated your comparison table in markdown showing only %" |
| [ruby#19681](https://github.com/ruby/ruby/pull/19681) | ZJIT compile time (issue-first) | open | — | open | +116/−19, 1f | 0 | 0 | no response |
| [ruby#19682](https://github.com/ruby/ruby/pull/19682) | ZJIT side exits (issue-first) | open | 7.4 h k0kubun (commented) | open | +90/−19, 4f | 2 | 0 | k0kubun approve with two points (memory of the profile slot, skip explicit block args): "I'd like to land a fix for the permanent exit" |
| [ruby#19685](https://github.com/ruby/ruby/pull/19685) | ZJIT GC | draft | — | open | +80/−14, 3f | 0 | 0 | draft |
| [ruby#19699](https://github.com/ruby/ruby/pull/19699) | test fix | open | — | open | +6/−4, 1f | 0 | 0 | no response |

### rails/rails (47)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes after opening | Review rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [rails#59235](https://github.com/rails/rails/pull/59235) | alloc | merged (amatsuda) | 0.8 h amatsuda (merge) | 0.8 h | +5/−4, 1f | 0 | 0 | merged, no comment |
| [rails#59236](https://github.com/rails/rails/pull/59236) | alloc | merged (amatsuda) | 1.0 h amatsuda (merge) | 1.0 h | +3/−1, 1f | 2 | 0 | fatkodima: "Not all the code needs to be optimized"; amatsuda explains his micro-optimization series (15% end to end) |
| [rails#59244](https://github.com/rails/rails/pull/59244) | alloc | merged (amatsuda) | 0.4 h amatsuda (merge) | 0.4 h | +1/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59252](https://github.com/rails/rails/pull/59252) | alloc | merged (amatsuda) | 1.1 h amatsuda (merge) | 1.1 h | +19/−3, 2f | 0 | 0 | merged, no comment |
| [rails#59270](https://github.com/rails/rails/pull/59270) | alloc | merged (amatsuda) | 0.3 h amatsuda (comment) | 5.5 h | +30/−2, 2f | 4 | 2 | amatsuda: reuse `role_class` two lines below too; asked to rebase |
| [rails#59274](https://github.com/rails/rails/pull/59274) | alloc | merged (amatsuda) | 3.0 h amatsuda (merge) | 3.0 h | +2/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59278](https://github.com/rails/rails/pull/59278) | alloc | merged (amatsuda) | 1.4 h amatsuda (merge) | 1.4 h | +1/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59316](https://github.com/rails/rails/pull/59316) | alloc | merged (amatsuda) | 0.3 h amatsuda (commented) | 15.8 h | +95/−13, 3f | 2 | 1 | amatsuda: `include?` instead of regexp, drop a `dup` (we kept both, with reasons) |
| [rails#59329](https://github.com/rails/rails/pull/59329) | alloc | merged (amatsuda) | 4.2 h amatsuda (merge) | 4.2 h | +8/−5, 2f | 0 | 0 | merged, no comment |
| [rails#59533](https://github.com/rails/rails/pull/59533) | alloc | merged (amatsuda) | 0.5 h amatsuda (merge) | 0.5 h | +6/−7, 1f | 0 | 0 | merged, no comment |
| [rails#59534](https://github.com/rails/rails/pull/59534) | alloc | merged (amatsuda) | 3.5 h amatsuda (merge) | 3.5 h | +4/−4, 2f | 0 | 0 | merged, no comment |
| [rails#59535](https://github.com/rails/rails/pull/59535) | alloc | merged (amatsuda) | 1.3 h amatsuda (merge) | 1.3 h | +28/−2, 2f | 1 | 0 | merged, no comment |
| [rails#59536](https://github.com/rails/rails/pull/59536) | alloc | merged (amatsuda) | 1.4 h amatsuda (merge) | 1.4 h | +7/−2, 3f | 0 | 0 | merged, no comment |
| [rails#59537](https://github.com/rails/rails/pull/59537) | alloc | merged (amatsuda) | 1.5 h amatsuda (merge) | 1.5 h | +4/−4, 1f | 0 | 0 | merged, no comment |
| [rails#59538](https://github.com/rails/rails/pull/59538) | alloc | merged (amatsuda) | 1.7 h amatsuda (merge) | 1.7 h | +2/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59539](https://github.com/rails/rails/pull/59539) | alloc | merged (amatsuda) | 1.9 h amatsuda (merge) | 1.9 h | +1/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59541](https://github.com/rails/rails/pull/59541) | alloc | merged (amatsuda) | 0.6 h amatsuda (merge) | 0.6 h | +4/−4, 1f | 0 | 0 | merged, no comment |
| [rails#59542](https://github.com/rails/rails/pull/59542) | alloc | merged (amatsuda) | 0.7 h amatsuda (merge) | 0.7 h | +2/−0, 1f | 0 | 0 | merged, no comment |
| [rails#59543](https://github.com/rails/rails/pull/59543) | alloc | merged (amatsuda) | 0.9 h amatsuda (merge) | 0.9 h | +2/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59544](https://github.com/rails/rails/pull/59544) | alloc | merged (amatsuda) | 1.0 h amatsuda (merge) | 1.0 h | +2/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59551](https://github.com/rails/rails/pull/59551) | alloc | merged (amatsuda) | 3.1 h amatsuda (merge) | 3.1 h | +1/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59552](https://github.com/rails/rails/pull/59552) | alloc | merged (amatsuda) | 3.3 h amatsuda (merge) | 3.3 h | +5/−0, 1f | 0 | 0 | merged, no comment |
| [rails#59553](https://github.com/rails/rails/pull/59553) | alloc | merged (amatsuda) | 2.5 h amatsuda (merge) | 2.5 h | +2/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59554](https://github.com/rails/rails/pull/59554) | alloc | merged (amatsuda) | 1.9 h amatsuda (merge) | 1.9 h | +3/−2, 1f | 0 | 0 | merged, no comment |
| [rails#59555](https://github.com/rails/rails/pull/59555) | regression fix | merged (amatsuda) | 1.7 h amatsuda (merge) | 1.7 h | +32/−2, 2f | 0 | 0 | merged, no comment |
| [rails#59556](https://github.com/rails/rails/pull/59556) | alloc | merged (amatsuda) | 2.4 h amatsuda (merge) | 2.4 h | +36/−2, 4f | 0 | 0 | merged, no comment |
| [rails#59557](https://github.com/rails/rails/pull/59557) | alloc (4.1 only) | open | — | open | +72/−7, 2f | 2 | 0 | no response; stacked earlier, ZJIT loss noted in our docs |
| [rails#59558](https://github.com/rails/rails/pull/59558) | alloc | merged (amatsuda) | 2.9 h amatsuda (merge) | 2.9 h | +5/−7, 1f | 0 | 0 | merged, no comment |
| [rails#59560](https://github.com/rails/rails/pull/59560) | alloc | merged (amatsuda) | 2.6 h amatsuda (merge) | 2.6 h | +111/−1, 4f | 0 | 0 | merged, no comment |
| [rails#59561](https://github.com/rails/rails/pull/59561) | alloc | merged (amatsuda) | 2.8 h amatsuda (merge) | 2.8 h | +9/−5, 1f | 0 | 0 | merged, no comment |
| [rails#59562](https://github.com/rails/rails/pull/59562) | alloc | merged (amatsuda) | 3.1 h amatsuda (comment) | 13.1 h | +91/−2, 2f | 3 | 2 | amatsuda found a regression (subclass without `super`); fatkodima: no `instance_variable_get` |
| [rails#59563](https://github.com/rails/rails/pull/59563) | alloc | merged (amatsuda) | 5.1 h amatsuda (merge) | 5.1 h | +3/−1, 1f | 0 | 0 | merged, no comment |
| [rails#59564](https://github.com/rails/rails/pull/59564) | alloc | open | — | open | +10/−6, 2f | 3 | 0 | no response; switched to the simple variant |
| [rails#59565](https://github.com/rails/rails/pull/59565) | error message | open | — | open | +107/−0, 2f | 0 | 0 | no response |
| [rails#59568](https://github.com/rails/rails/pull/59568) | CPU | merged (amatsuda) | 1.2 h amatsuda (merge) | 1.2 h | +1/−0, 1f | 0 | 0 | merged, no comment |
| [rails#59569](https://github.com/rails/rails/pull/59569) | CPU | open | — | open | +5/−3, 2f | 0 | 0 | no response |
| [rails#59570](https://github.com/rails/rails/pull/59570) | CPU | open | — | open | +29/−1, 2f | 0 | 0 | no response |
| [rails#59571](https://github.com/rails/rails/pull/59571) | alloc | merged (amatsuda) | 6.0 h amatsuda (merge) | 6.0 h | +33/−4, 2f | 0 | 0 | merged, no comment |
| [rails#59574](https://github.com/rails/rails/pull/59574) | compat | open | — | open | +82/−1, 4f | 3 | 0 | no response |
| [rails#59576](https://github.com/rails/rails/pull/59576) | alloc | merged (amatsuda) | 3.4 h amatsuda (merge) | 3.4 h | +23/−7, 2f | 0 | 0 | merged, no comment |
| [rails#59577](https://github.com/rails/rails/pull/59577) | alloc | closed (us) | 2.5 h fatkodima (comment) | 21.6 h | +16/−3, 1f | 2 | 1 | fatkodima: "How do you decide which code needs optimizations … more complex and uglier for questionable benefits"; kamipo did it structurally in #59590 |
| [rails#59583](https://github.com/rails/rails/pull/59583) | alloc | merged (amatsuda) | 7.1 h amatsuda (merge) | 7.1 h | +28/−3, 2f | 0 | 0 | merged, no comment |
| [rails#59584](https://github.com/rails/rails/pull/59584) | CPU | open | 7.3 h amatsuda (comment) | open | +14/−1, 2f | 3 | 2 | amatsuda measured it slower on small documents, proposed direct `include?` checks; then the same for JS separators |
| [rails#59585](https://github.com/rails/rails/pull/59585) | CPU | merged (amatsuda) | 7.5 h amatsuda (merge) | 7.5 h | +47/−2, 4f | 0 | 0 | merged, no comment |
| [rails#59596](https://github.com/rails/rails/pull/59596) | alloc/CPU | merged (amatsuda) | 1.3 h amatsuda (merge) | 1.3 h | +8/−1, 2f | 0 | 0 | merged in 1.3 h, no comment |
| [rails#59597](https://github.com/rails/rails/pull/59597) | alloc/CPU | merged (amatsuda) | 1.4 h amatsuda (merge) | 1.4 h | +8/−1, 2f | 0 | 0 | merged in 1.4 h, no comment |
| [rails#59598](https://github.com/rails/rails/pull/59598) | CPU | merged (amatsuda) | 1.5 h amatsuda (merge) | 1.5 h | +1/−1, 1f | 0 | 0 | merged in 1.5 h, no comment |

### Gems and ruby-bench (30)

| PR | Kind | Outcome | First maintainer response | Opened → end | Diff | Pushes after opening | Review rounds | What the maintainer said |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [IAPark/tiktoken_ruby#132](https://github.com/IAPark/tiktoken_ruby/pull/132) | compat | closed (gjtorikian) | 0.3 h gjtorikian (merge) | 0.3 h | +4/−4, 1f | 0 | 0 | gjtorikian: already done in #130 (we missed it) |
| [MiniProfiler/rack-mini-profiler#670](https://github.com/MiniProfiler/rack-mini-profiler/pull/670) | CPU | open | — | open | +4/−0, 1f | 0 | 0 | no response |
| [Shopify/tapioca#2748](https://github.com/Shopify/tapioca/pull/2748) | compat | open | — | open | +55/−0, 2f | 2 | 0 | no response |
| [cabo/cbor-ruby#43](https://github.com/cabo/cbor-ruby/pull/43) | compat | closed (us) | 0.1 h cabo (comment) | 0.5 h | +34/−8, 5f | 0 | 0 | cabo: "Can you relate this to PR #31?" (we missed it) |
| [caxlsx/caxlsx#550](https://github.com/caxlsx/caxlsx/pull/550) | alloc | merged (kiskoza) | 11.8 d kiskoza (changes_requested) | 11.9 d | +51/−2, 4f | 2 | 2 | kiskoza: "we're using `.is_a?` all over the codebase, please follow this pattern" |
| [getlago/lago-expression#91](https://github.com/getlago/lago-expression/pull/91) | compat | open | — | open | +3/−1, 3f | 0 | 0 | no response |
| [inertiajs/inertia-rails#435](https://github.com/inertiajs/inertia-rails/pull/435) | correctness | open | — | open | +86/−13, 7f | 0 | 0 | no response |
| [inertiajs/inertia-rails#436](https://github.com/inertiajs/inertia-rails/pull/436) | correctness | open | — | open | +250/−17, 6f | 0 | 0 | no response |
| [inertiajs/inertia-rails#437](https://github.com/inertiajs/inertia-rails/pull/437) | CPU/alloc | open | — | open | +40/−4, 4f | 0 | 0 | no response |
| [inertiajs/inertia-rails#441](https://github.com/inertiajs/inertia-rails/pull/441) | alloc | open | — | open | +11/−8, 2f | 0 | 0 | no response |
| [inertiajs/inertia-rails#442](https://github.com/inertiajs/inertia-rails/pull/442) | alloc + bug fix | open | — | open | +73/−4, 3f | 0 | 0 | no response |
| [mperham/connection_pool#225](https://github.com/mperham/connection_pool/pull/225) | alloc | merged (mperham) | 7.6 h mperham (comment) | 9.0 h | +7/−2, 1f | 0 | 0 | mperham: "I don't particularly care for the extracted constants"; merged after our measurement |
| [rack/rack#2550](https://github.com/rack/rack/pull/2550) | alloc | open | — | open | +5/−2, 3f | 2 | 0 | no response |
| [rails/importmap-rails#336](https://github.com/rails/importmap-rails/pull/336) | alloc | open | — | open | +8/−4, 1f | 0 | 0 | no response |
| [rails/propshaft#289](https://github.com/rails/propshaft/pull/289) | CPU | open | — | open | +3/−2, 1f | 0 | 0 | no response |
| [rubocop/rubocop-performance#550](https://github.com/rubocop/rubocop-performance/pull/550) | lint safety | open | — | open | +104/−8, 5f | 0 | 0 | no response |
| [rubocop/rubocop-performance#551](https://github.com/rubocop/rubocop-performance/pull/551) | lint safety | open | — | open | +133/−25, 6f | 0 | 0 | no response |
| [rubocop/rubocop-performance#552](https://github.com/rubocop/rubocop-performance/pull/552) | docs | open | — | open | +39/−12, 3f | 0 | 0 | no response |
| [rubocop/rubocop-rails#1670](https://github.com/rubocop/rubocop-rails/pull/1670) | lint safety | open | — | open | +48/−0, 3f | 1 | 0 | no response |
| [ruby-i18n/i18n#763](https://github.com/ruby-i18n/i18n/pull/763) | alloc | open | — | open | +11/−1, 2f | 0 | 0 | no response |
| [ruby-i18n/i18n#764](https://github.com/ruby-i18n/i18n/pull/764) | alloc | open | — | open | +74/−1, 2f | 0 | 0 | no response |
| [ruby-i18n/i18n#765](https://github.com/ruby-i18n/i18n/pull/765) | alloc | open | — | open | +42/−1, 2f | 0 | 0 | no response |
| [ruby-i18n/i18n#766](https://github.com/ruby-i18n/i18n/pull/766) | CPU | open | — | open | +29/−3, 2f | 0 | 0 | no response |
| [ruby/bigdecimal#562](https://github.com/ruby/bigdecimal/pull/562) | alloc | open | — | open | +70/−1, 3f | 0 | 0 | no response |
| [ruby/prism#4298](https://github.com/ruby/prism/pull/4298) | compat | merged (kddnewton) | 5.1 h kddnewton (approved) | 20.3 h | +39/−3, 2f | 0 | 0 | kddnewton approve |
| [ruby/ruby-bench#564](https://github.com/ruby/ruby-bench/pull/564) | benchmark fix | open | — | open | +2/−3, 2f | 1 | 0 | no response |
| [skryukov/rails_vite#57](https://github.com/skryukov/rails_vite/pull/57) | CPU | open | — | open | +61/−1, 2f | 0 | 0 | no response |
| [sparklemotion/nokogiri#3759](https://github.com/sparklemotion/nokogiri/pull/3759) | alloc | open | — | open | +3/−2, 1f | 0 | 0 | no response |
| [sparklemotion/sqlite3-ruby#758](https://github.com/sparklemotion/sqlite3-ruby/pull/758) | alloc | merged (flavorjones) | 4.0 d flavorjones (comment) | 4.0 d | +24/−4, 3f | 1 | 0 | flavorjones: "If it goes green, I'll merge it." |
| [tzinfo/tzinfo#171](https://github.com/tzinfo/tzinfo/pull/171) | alloc | open | — | open | +1/−14, 1f | 0 | 0 | no response |
