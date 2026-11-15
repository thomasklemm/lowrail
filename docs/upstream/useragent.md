# UA1: allow_browser's check, one level down in the useragent gem

Bet UA1, 2026-11-15. fatkodima closed AB1 (rails/rails#59808, a per-user-agent verdict cache in `allow_browser`)
as added complexity for a small gain. Thomas asked whether to fix the same cost one level down instead, in the
useragent gem ([gshutler/useragent](https://github.com/gshutler/useragent) 0.16.11, which Action Pack depends on),
exactly and without a cache.

**Result: built locally and held, no fork, nothing opened.** Four small exact commits (18 lines added, 12 removed,
six files) make `allow_browser`'s whole check about 1.4× faster under YJIT (benchmark-ips over 21 real user agents:
1.44× against the first main run, 41.1 to 28.5 µs per user agent, and 1.36× against main's A/A run, which was 6%
faster; the two reviews measured 1.44× and 1.37×; 1.42× on ZJIT master). They cut 30.6% of the check's YJIT
instructions (27.8% in the interpreter) and 34 of its 183 objects. The differential probe over 20,402 user agents
is byte-identical to main. On the profiled apps that is about 0.9% of a Blog request, 0.4% of Campfire's and 0.15% of
Fizzy's, against AB1's 3.0, 1.3 and 0.5%; on a fresh app's bare page about 4% of the 12.9%. That is short of the
2× bar, and the gem's only merger hasn't merged anything since 2024-12 or answered any of the ten PRs opened in
2026. The commits are kept as `git am` patches in [`bench/upstream/ua1/patches/`](../../bench/upstream/ua1/patches/),
queue item [UA1](../../bench/upstream/pr-queue/items/UA1.md) (`held`). Two independent reviews asked only for text
fixes, which are applied ([Reviews](#reviews)).

## Where the time goes

`BrowserBlocker#blocked?` (Rails main [8217632](https://github.com/rails/rails/commit/8217632), identical to
50c54eed06 in `allow_browser.rb`) parses the user agent once and reads `version` once (memoized). For a guarded
browser it reads `browser` once, builds the minimum `Version` and compares. `bot?` runs only for a user agent below
the minimum. So Rails recomputes nothing per request; the repeated work is inside the gem.

21 real user agents ([`uas.rb`](../../bench/upstream/ua1/uas.rb)): Chrome on Windows, macOS, Android and iOS,
Safari on macOS and iOS, Firefox on Windows and Android, Edge and Opera on Windows and Android, Googlebot (desktop
and smartphone), Bingbot, Applebot, GPTBot, curl, and the Facebook, Instagram and WeChat in-app browsers. Per call
under YJIT (Ruby 4.0.9, [`breakdown.rb`](../../bench/upstream/ua1/breakdown.rb), one core of a noisy orb), the check
takes 9–104 µs, about 40 µs on average, and parse alone takes 8–69 µs. The Facebook in-app browser is the slowest:
`Webkit#version` falls back to the iOS version through `os` and `browser`.

Shares of the check, stackprof under YJIT (50 µs interval, 168,000 checks over the 21 user agents, 1,557 samples in
`blocked?`; GC is another 16% of all samples on top):

| Piece | Share of the check |
|---|---:|
| `Version.new` for every product in `UserAgent.parse` (two or three `=~`, a `scan`, a `=~` per part) | 42% |
| `Browsers.extend` trying each browser class | 11.5% |
| The product regexp (`MATCHER`) | 9.2% |
| Rest of the parse loop (slice and `strip` per product, comment split, `MatchData#[]`) | 12% |
| Rails: the minimum `Version.new` and `<` | 11.0% |
| Rails: `version` | 7.3% |
| Rails: `browser` | 6.0% |
| Rails: `bot?` (only below the minimum) | 0.3% |

Allocations ([`allocs.rb`](../../bench/upstream/ua1/allocs.rb)): 164 objects per check by allocation site (183 by
`GC.stat` in the Callgrind window). The largest sites are the parse loop (41: the match, its captures, the slice and
`strip` per product), `Version#initialize`'s scan tokens, arrays and `MatchData` (37), and `detect_product`'s
`downcase` per product (21.5).

The leads from the brief, checked:

* **The product scan regexp.** 9% of the check. It is anchored with `^` (line start), not `\A`, so a match can
  start after a newline, and the loop then slices `m[0].length` characters off the front. Slicing by offsets
  instead is exact but costs 3.2% more instructions, because `MatchData#begin` and `String#length` count
  characters. Nothing exact and cheaper was found.
* **`Browsers.extend`.** 11.5%, spread over the 14 `extend?` predicates (Internet Explorer's `comment.join` and
  regexp, WeChat's case-insensitive regexp per product, Webkit's regexp per comment). Its `return` from inside
  `all.each` is a throw under ZJIT, one `exit_exception_handler` per parse
  ([lead 17](zjit-iseq-leads.md#17-throw-unwinding-and-frame-materialization-taken)). Replacing it with `detect`
  removes the exits but loses on the pin, so it was dropped (below).
* **`version` and `browser` recomputed on every call.** Rails reads each once per request, so memoizing them saves
  nothing there. Memoizing on the parsed object also isn't exact: it is an `Array` subclass, every product's
  `comment` is a mutable `Array` and its strings are mutable, so any mutator changes the answer. The probe mutates
  parsed objects and reads everything again; a memoized `Chrome#application` mutant changes 3,979 of 20,621 lines.
* **`bot?`.** 0.3%, since Rails reaches it only for a guarded browser below the minimum.
* **Allocations.** The four commits remove 34 of 183 objects per check.

`Version` could also parse lazily, about 1.3× more on the check. That isn't exact: an unparsed `Version` has other
instance variables, which `instance_values`, `as_json` (Active Support renders the ivars) and `Marshal.dump` show. A
lazy-version mutant changes 222 of 20,621 probe lines. Not used.

## The changes

On useragent master [680915a](https://github.com/gshutler/useragent/commit/680915a) (0.16.11), local branch
`thomasklemm/faster-parse` at `ebafb56`: four commits, author and committer Thomas Klemm, no trailers (`git am
--committer-date-is-author-date` on the patches gives that SHA). Callgrind
instructions and objects per check, 21 user agents × 20 rounds, GC off in the window, every YJIT window JIT-flat (0
blocks compiled), cumulative from top to bottom ([raw](data/ua1/callgrind.txt)):

| # | Change | Interpreter Ir | YJIT Ir | Objects |
|---|---|---:|---:|---:|
| | main | 287,390 | 224,158 | 182.7 |
| | main again (A/A) | 287,208 (−0.06%) | 223,942 (−0.10%) | 182.7 |
| 1 | `Version#initialize`: a version of only digits and dots (`537.36`, `142.0.0.0`) takes one anchored `=~` and `split(".")` | 225,186 (−21.6%) | 168,535 (−24.8%) | 168.8 |
| 2 | `detect_product` downcases the wanted name once, at the first comparison | 220,106 (−2.3%) | 165,624 (−1.7%) | 161.0 |
| 3 | `application` (Chrome, Webkit, Vivaldi, AppleCoreMedia): `detect` instead of `reject { … }.first` | 213,301 (−3.1%) | 160,465 (−3.1%) | 158.4 |
| 4 | `Version#<=>`: a `while` loop over the six positions instead of `([0]*6).zip(...).each` | 207,471 (−2.7%) | 155,669 (−3.0%) | 148.8 |
| | all four against main | −27.8% | −30.6% | −33.9 |

AppleCoreMedia joined change 3 after the reviews (an optional point: it had the same code). None of the 21 user
agents is AppleCoreMedia, so the measurements stand; the probe and the specs were rerun on the final head, and the
probe gained an edge case that reaches AppleCoreMedia's `application` (a mutant returning `first` changes 1 line).

`UserAgent.parse` alone: 200,791 to 145,879 Ir in the interpreter (−27.3%, A/A −0.06%), 165,645 to 117,492 under
YJIT (−29.1%, A/A −0.05%); 126.1 to 114.0 objects.

Why each is exact (the commit messages say the same):

1. For a string matching `\A\d+(?:\.\d+)*\z`, the old branches give `@nil = false` and `@comparable = true`, and the
   scan's tokens are the digit runs between the dots, which `split(".")` returns; `\d` is ASCII in both. A string
   with a newline, a space or a letter fails `\z` and takes the old path, whose regexps are unchanged, so `"1.0\n"`,
   `"1."`, `".1"` and `"1..2"` behave as before.
2. The name is downcased lazily (`name ||= product.to_s.downcase`), so the calls happen in the old order and an empty
   result such as `UserAgent.parse("/")` still never downcases it. Hoisting it out of the block would make
   `respond_to?` with an invalid UTF-8 name raise `ArgumentError` on an empty result instead of returning `false`.
3. `reject` called the block on every product and returned a new Array; `detect` returns the same first element.
   The block only reads `comment`.
4. The same `to_a` calls in the same order, the same six positions with a missing part read as 0, the same
   branches.

Change 1 uses `=~` and not `match?`, because the gem's CI still tests Rubies before 2.4 (2.2, 2.3), which lack `match?`.
`match?` there would save another 2.7% of the check's interpreter instructions and 13 objects. The branch uses
nothing newer than Ruby 2.2 by reading, but it was run only on 4.0.9; Ruby 2.2, 2.3 and JRuby 9.4, which the gem's CI
lists, were not run.

Dropped:

* **`Browsers.extend` with `all.detect`** instead of `return` from `all.each`
  ([patch](../../bench/upstream/ua1/rejected-extend-detect.patch)). It removes ZJIT's `exit_exception_handler`
  (19,947 to 0 in 21,000 checks), but on the pin it is −0.2% in the interpreter and +1.1% under YJIT (155,669 to
  157,441 Ir), because `detect` calls the block from C while YJIT compiles `Array#each`'s block inline. Under ZJIT it
  bought no wall time either: the check is 1.42× with or without it (`ips5-zjit.txt` against `ips4-zjit.txt`).
  DECISIONS asks a Rails change made only for ZJIT to win on the pin, and the same holds here, so it stays out; making the throw cheap is ZJIT's job
  (lead 17, taken).
* Slicing by offsets in the parse loop: +3.2% (above).
* A constant for Chrome's `%w(Chrome CriOS)`: PR #73's frozen literals already remove those strings.

## Exactness

The differential probe ([`probe.rb`](../../bench/upstream/ua1/probe.rb), corpus by
[`corpus.rb`](../../bench/upstream/ua1/corpus.rb)) runs main, the branch and a second copy of main (A/A) over 20,380
unique user agents: the strings in useragent's own specs, ua-parser/uap-core's test_ua, test_os and test_device
fixtures (73e7340c3e), intoli/user-agents (8a2b6f229b) and monperrus/crawler-user-agents (a727b35790). It adds 22
edge cases: nil, blank, `/`, quotes, newlines, binary, invalid UTF-8, UTF-16LE, `ÇHRÖME`, `İ`, `Straße`,
chromeframe, `,gzip(gfe)` and an AppleCoreMedia product after another one. For each user agent it writes every public result:

* the class and every reader twice (`to_s`, `inspect`, `browser`, `version`, `platform`, `os`, `mobile?`, `bot?`,
  `to_h`, `application`, `build`, `security`, `localization`, `webkit`, and Internet Explorer's `real_version`,
  `trident_version`, `compatibility_view?` and `chromeframe`);
* every product's fields, and `Marshal.dump` and the ivars of every product and version;
* `extend?` of all 14 classes, comparisons with three other user agents and four versions;
* `respond_to?` and `method_missing` for every product name;
* `allow_browser`'s verdict for `:modern` and for a Hash;
* all readers again after three mutations (a comment pushed, a product appended, one prepended).

Then come 220 lines of `Version.new` over every version string seen and 32 odd ones: all pairs compared, and every
version read again after mutating the string it was given.

All three outputs are byte-identical: 20,622 lines, md5 `90d2620d4c89…` (20,621 lines, md5 `d6c196bc1124…`, before
the AppleCoreMedia edge case, which the reviews ran). Every browser class appears (8,013 `Base`,
5,226 Webkit, 3,979 Chrome, 1,694 Gecko, 763 Opera, 638 Internet Explorer, down to 2 Libavformat), and the two inputs
that raise (invalid UTF-8, UTF-16LE) raise the same error class and message.

The probe catches every mutant tried ([`mutants.sh`](../../bench/upstream/ua1/mutants.sh), on a checkout at change
1; [counts](data/ua1/mutants.txt), the same in both reviews): a fast path that accepts any digits and dots, one anchored per line, `casecmp?` in `detect_product` (caught only
by the `Straße` edge case), a memoized `application`, a lazy `Version`, and an `extend` that skips Internet Explorer.
The gem's 1,321 specs pass with `-w` on main and the branch, with no warning from the gem's code. They need
`ostruct` added outside the repo, because the specs `require "ostruct"`, which Ruby 4.0 no longer ships as a default
gem (gshutler/useragent#75 adds it).

[Checklist](../DECISIONS.md#exactness-checklist). Nothing differs for any string passed to `UserAgent.parse`. Both
reviews' own edge probes (UTF-16, UTF-32, Shift_JIS, non-ASCII digits, frozen strings, 400-digit and 40-part versions,
frozen parsed objects, odd `allow_browser` minimums) found no difference there. They found these differences, each
needing a user subclass, a singleton method or a foreign element, none reachable from a parsed user agent; all are
accepted:

* **A String subclass or singleton methods on the version string** (items 1 and 2): `Version.new` now calls `=~` once
  and `split` on the fast path where main called `=~` three times and `scan`, and four times on the old path; a
  subclass overriding `scan`, `split` or `=~` gets a different `to_a`.
* **A `Version` subclass** whose `to_a` returns an Enumerator, a Set or an object with `to_ary` compares on main and
  gives another result or raises `NoMethodError` on the branch (a Struct with `[]` gives `nil`); with `nil` the error is
  `NoMethodError` instead of `TypeError`; parts that define `!=` apart from `==` can give another result.
* **Foreign elements pushed after the application** (`ua << nil`, `Object.new`, a product with an Integer comment):
  on main `application` and everything that reads it raise `NoMethodError`, because `reject` reached them; the
  branch's `detect` stops at the application and returns it.
* **`respond_to?` with a name that is neither String nor Symbol**: its `to_s` is called once instead of once per
  product; the result and any `TypeError` are the same.

A user subclass of `Browsers::Chrome` (or Webkit, Vivaldi, AppleCoreMedia) overriding `reject` no longer sees it
called, and frozen parsed objects behave as before (nothing is stored on them).

## Wall time

benchmark-ips 2.15.1, [`ips.rb`](../../bench/upstream/ua1/ips.rb), core 1 of the 2-core orb, five interleaved rounds
of main, the branch and main again (A/A), best of 5 ([raw](data/ua1/)). "check" is `BrowserBlocker#blocked?` with
`versions: :modern` over the 21 user agents; "request" is AB1's bare controller request with Chrome on macOS.

| Ruby | Report | main | A/A | branch | change |
|---|---|---:|---:|---:|---:|
| 4.0.9 YJIT | parse ×21 | 595.95 µs | 600.24 µs (−0.7%) | 422.12 µs | 1.41× |
| 4.0.9 YJIT | check ×21 | 863.56 µs | 814.33 µs (+6.0%) | 599.16 µs | 1.44× |
| 4.0.9 YJIT | request | 98.48 µs | 105.63 µs (−6.8%) | 86.10 µs | 1.14× |
| master ZJIT | parse ×21 | 459.98 µs | 464.04 µs (−0.9%) | 327.87 µs | 1.40× |
| master ZJIT | check ×21 | 681.66 µs | 678.43 µs (+0.5%) | 481.23 µs | 1.42× |
| master ZJIT | request | 84.49 µs | 85.02 µs (−0.6%) | 69.31 µs | 1.22× |

Against main's A/A run instead of its first run, the YJIT check is 1.36× and parse 1.42×, so the change is about
1.4×. The YJIT A/A is up to 6.8% on this orb, so the request row says only that a bare request gets about 12 µs cheaper,
which matches the check's 12.6 µs per user agent. Change 1 alone (`ips-yjit-c1.txt`): parse 1.39× (A/A +0.5%),
check 1.28× (A/A −6.1%); its commit message quotes those lines.

## ZJIT (record only)

Ruby master 9aa0898240 (`--enable-zjit --enable-yjit`), stats for 21,000 checks
([`zjit_stats.rb`](../../bench/upstream/ua1/zjit_stats.rb)); main again matches main exactly; no OOM, no failed ISEQs.
The four commits change nothing that matters (`zjit-stats4.txt`):

```diff
-compiled_iseq_count          458
+compiled_iseq_count          459
-side_exit_count              20890
+side_exit_count              20900
-compiled_side_exit_count     10332
+compiled_side_exit_count     10364
```

`exit_exception_handler` stays at 19,947, one per parse. The dropped `extend` change takes it to 0 and
`side_exit_count` to 951 (`zjit-stats5.txt`), with no wall-time gain.

## Prior art and the maintainer

* **No issue or PR on parse speed.** The closest are issue #70 (tmaier, 2025-12, "Enable `# frozen_string_literal:
  true` to optimize string handling", no reply) and PR #73 (Edouard-chin, 2026-07, the same for Ractor use from
  Rails, pinged 2026-08-03, no reply). #73 alone: −2.3% of the check's interpreter instructions, −2.9% under YJIT,
  −23 objects. With the four commits on top: −30.1% and −33.6%, 121 objects. They apply together without conflicts.
* **Maintainer.** Garry Shutler (gshutler) merged all 25 merged PRs (2015–2024) and made every release. The last merge
  and release, 0.16.11, was on 2024-12-04. Ten PRs opened in 2026: #71 (closed by its author the same day) and #73–#81,
  which are open with no maintainer reply, as is issue #72 (BingPreview not a bot, so `allow_browser` answers 406).
  #69 (2025) was also closed by its author the day it opened. He is active on GitHub elsewhere (a review in cronofy/cronofy-ruby on 2026-11-09). RubyGems lists
  gshutler and qrush (Nick Quaranto) as owners, so qrush could publish a release, but he has merged nothing in the
  repo; nobody else is visible with merge rights (the collaborator list needs push access). 156.9 M downloads.

## Verdict

The gem-level fix is exact, small, needs no cache and helps every app on Rails' default `allow_browser`. But it is
about 1.4× for the check, not 2×. What remains is spread over the parse loop, the browser classes' predicates, GC and
Rails' own readers, with no single exact lever left (the largest, a lazy `Version`, isn't exact). It also needs a
merge and a release from a maintainer who hasn't answered a PR in almost two years. So it is held: no fork, no push.
If gshutler answers #73, or any new commit or release lands in the repo, this goes next as one PR with four commits
(draft body in the queue item). Before it opens, the body's benchmark-ips lines are rerun until the A/A is tight. Pushing the branch to a fork takes one command when Thomas wants it there.

## Reviews

Two independent review orbs on head `9332878` (before the text fixes and the AppleCoreMedia line), both on Ruby
4.0.9 and Rails main 8217632. Both verdicts were **changes, all text**; both called the code exact for every input
that comes through `UserAgent.parse` or Rails, and holding right.

* **claude-code** ([thread](https://ampcode.com/threads/T-01a1df56-3d92-727d-b974-39933e08ee00)): `git am` gives
  `9332878`; probe main, branch and A/A 20,621 lines each, md5 `d6c196bc…`; specs 1,321 green with -w; mutants all
  caught; Callgrind check −27.6% interpreter, −30.35% YJIT (A/A +0.05%, +0.06%), parse −27.1% and −29.3%, objects
  182.7 to 148.8; ips YJIT check 1.37× (A/A +1.7%), parse 1.32×, request 1.22×. Must-fixes: record the four
  non-parse boundaries and say "for any user agent" in the body; "the largest part", not "most"; "three to six"
  products (Firefox has three); give the speedup as a range, since 1.44× is against the slower main run; current
  mutant counts.
* **opus** ([thread](https://ampcode.com/threads/T-01a1df56-4eb5-73ac-af77-2d09288a5c81)): the same probe and spec
  results; its own edge probe found the same four boundaries; Callgrind check −27.6% and −30.4% (A/A +0.05%,
  −0.03%), parse −27.1% and −29.4%; ips YJIT check 1.44× (A/A +2.5%), parse 1.41×, request 1.21×. Must-fixes:
  the boundaries, the mutant counts, "three to six", "the largest part", and ten PRs opened in 2026 (not nine).
  Optional, applied: AppleCoreMedia in change 3, CI's old Rubies and JRuby named as not run, a second trigger.

The fixes went in as `3a0896a`. Both confirm passes on it (same threads) found the five fixes in, AppleCoreMedia
exact (their own AppleCoreMedia probes: 8 and 5 user agents, plain and mutated, identical), the probe identical and
the specs green, and one new must-fix: the rebuilt commits had picked up an `Amp-Thread-ID` trailer from a commit
hook. The final head `ebafb56` is the same four commits rebuilt with `git commit-tree`: the same tree, no trailers,
and the SHA both reviewers built when they tried the fix. Their nits are applied too (the record's Ruby 2.3 sentence,
the `to_ary` boundary, the AppleCoreMedia edge case in the probe).

## Scripts

All in [`bench/upstream/ua1/`](../../bench/upstream/ua1/):

* `uas.rb`: the 21 user agents. `breakdown.rb`: µs per piece and objects per user agent. `profile.rb`: stackprof or
  Vernier over the check. `allocs.rb`: objects by allocation site.
* `ir.rb` and `ir.sh`: Callgrind per call, `ir.sh RUBY_BIN GEMFILE_DIR interp|yjit check|parse N`.
* `ips.rb`: run by [`p_map/ab1_review.sh`](../../bench/upstream/p_map/ab1_review.sh), summarized by
  `p_map/ab1_best.rb` and `best_lines.rb` (the raw line of each best round).
* `zjit_stats.rb`; `corpus.rb`, `probe.rb`, `mutants.sh` with `mutant-lazy-version.patch`.
* `patches/`: the four commits, `git am`-able on useragent 680915a; `rejected-extend-detect.patch`: the dropped change.

Each Gemfile points `actionpack`, `actionview` and `activesupport` at a Rails main checkout and `useragent` at a
checkout of main or the branch.
