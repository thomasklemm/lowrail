# UA1: allow_browser's check, one level down in the useragent gem

Bet UA1, 2026-11-15. fatkodima closed AB1 (rails/rails#59808, a per-user-agent verdict cache in `allow_browser`)
as added complexity for a small gain. Thomas asked whether to fix the same cost one level down instead, in the
useragent gem ([gshutler/useragent](https://github.com/gshutler/useragent) 0.16.11, which Action Pack depends on),
exactly and without a cache.

**Result: built locally and held, no fork, nothing opened.** Four small exact commits (17 lines added, 11 removed,
five files) make `allow_browser`'s whole check 1.44× faster under YJIT (benchmark-ips, 41.1 to 28.5 µs per user agent
over 21 real ones; 1.42× on ZJIT master) and `UserAgent.parse` 1.41× faster. They cut 30.6% of the check's YJIT
instructions (27.8% in the interpreter) and 34 of its 183 objects. The differential probe over 20,401 user agents
is byte-identical to main. On the profiled apps that is about 0.9% of a Blog request, 0.4% of Campfire's and 0.15% of
Fizzy's, against AB1's 3.0, 1.3 and 0.5%; on a fresh app's bare page about 4% of the 12.9%. That is short of the
2× bar, and the gem's only merger hasn't merged anything since 2024-12 or answered any of the nine PRs opened in
2026. The commits are kept as `git am` patches in [`bench/upstream/ua1/patches/`](../../bench/upstream/ua1/patches/),
queue item [UA1](../../bench/upstream/pr-queue/items/UA1.md) (`held`).

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
  parsed objects and reads everything again; a memoized `Chrome#application` mutant changes 594 of 3,103 lines.
* **`bot?`.** 0.3%, since Rails reaches it only for a guarded browser below the minimum.
* **Allocations.** The four commits remove 34 of 183 objects per check.

`Version` could also parse lazily, about 1.3× more on the check. That isn't exact: an unparsed `Version` has other
instance variables, which `instance_values`, `as_json` (Active Support renders the ivars) and `Marshal.dump` show. A
lazy-version mutant changes 85 of 3,103 probe lines. Not used.

## The changes

On useragent master [680915a](https://github.com/gshutler/useragent/commit/680915a) (0.16.11), local branch
`thomasklemm/faster-parse` at `9332878`: four commits, author and committer Thomas Klemm, no trailers. Callgrind
instructions and objects per check, 21 user agents × 20 rounds, GC off in the window, every YJIT window JIT-flat (0
blocks compiled), cumulative from top to bottom ([raw](data/ua1/callgrind.txt)):

| # | Change | Interpreter Ir | YJIT Ir | Objects |
|---|---|---:|---:|---:|
| | main | 287,390 | 224,158 | 182.7 |
| | main again (A/A) | 287,208 (−0.06%) | 223,942 (−0.10%) | 182.7 |
| 1 | `Version#initialize`: a version of only digits and dots (`537.36`, `142.0.0.0`) takes one anchored `=~` and `split(".")` | 225,186 (−21.6%) | 168,535 (−24.8%) | 168.8 |
| 2 | `detect_product` downcases the wanted name once, at the first comparison | 220,106 (−2.3%) | 165,624 (−1.7%) | 161.0 |
| 3 | `application` (Chrome, Webkit, Vivaldi): `detect` instead of `reject { … }.first` | 213,301 (−3.1%) | 160,465 (−3.1%) | 158.4 |
| 4 | `Version#<=>`: a `while` loop over the six positions instead of `([0]*6).zip(...).each` | 207,471 (−2.7%) | 155,669 (−3.0%) | 148.8 |
| | all four against main | −27.8% | −30.6% | −33.9 |

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

Change 1 uses `=~` and not `match?`, because Ruby 2.3 is still in the gem's CI matrix and `match?` needs 2.4.
`match?` there would save another 2.7% of the check's interpreter instructions and 13 objects. The branch uses
nothing newer than Ruby 2.3 by reading; it was not run on 2.3.

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
fixtures (73e7340c3e), intoli/user-agents (8a2b6f229b) and monperrus/crawler-user-agents (a727b35790). It adds 21
edge cases: nil, blank, `/`, quotes, newlines, binary, invalid UTF-8, UTF-16LE, `ÇHRÖME`, `İ`, `Straße`,
chromeframe and `,gzip(gfe)`. For each user agent it writes every public result:

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

All three outputs are byte-identical: 20,621 lines, md5 `d6c196bc1124…`. Every browser class appears (8,013 `Base`,
5,226 Webkit, 3,979 Chrome, 1,694 Gecko, 763 Opera, 638 Internet Explorer, down to 2 Libavformat), and the two inputs
that raise (invalid UTF-8, UTF-16LE) raise the same error class and message.

The probe catches every mutant tried ([`mutants.sh`](../../bench/upstream/ua1/mutants.sh), on a checkout at change
1): a fast path that accepts any digits and dots, one anchored per line, `casecmp?` in `detect_product` (caught only
by the `Straße` edge case), a memoized `application`, a lazy `Version`, and an `extend` that skips Internet Explorer.
The gem's 1,321 specs pass with `-w` on main and the branch, with no warning from the gem's code. They need
`ostruct` added outside the repo, because the specs `require "ostruct"`, which Ruby 4.0 no longer ships as a default
gem (gshutler/useragent#75 adds it).

[Checklist](../DECISIONS.md#exactness-checklist): the only new call on an object the gem doesn't create is `split`
and the anchored `=~` on the version string, which a String subclass with its own `=~` or `split` would see; that's
a global redefinition, accepted. `detect` instead of `reject` on the gem's own `Array` subclasses would differ only
for a user subclass of `Browsers::Chrome` (or Webkit, Vivaldi) overriding `reject`, which is the gem's internals,
accepted. Frozen parsed objects behave as before (nothing is stored on them).

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

The YJIT A/A is up to 6.8% on this orb, so the request row says only that a bare request gets about 12 µs cheaper,
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
  and release, 0.16.11, was on 2024-12-04. The nine PRs opened since July 2026 (#73–#81) and issue #72 (BingPreview
  not a bot, so `allow_browser` answers 406) have no maintainer reply; #71 and #69 were closed by their authors the
  day they opened. He is active on GitHub elsewhere (a review in cronofy/cronofy-ruby on 2026-11-09). RubyGems lists
  gshutler and qrush (Nick Quaranto) as owners, so qrush could publish a release, but he has merged nothing in the
  repo; nobody else is visible with merge rights (the collaborator list needs push access). 156.9 M downloads.

## Verdict

The gem-level fix is exact, small, needs no cache and helps every app on Rails' default `allow_browser`. But it is
1.44× for the check, not 2×. What remains is spread over the parse loop, the browser classes' predicates, GC and
Rails' own readers, with no single exact lever left (the largest, a lazy `Version`, isn't exact). It also needs a
merge and a release from a maintainer who hasn't answered a PR in almost two years. So it is held: no fork, no push.
If gshutler answers #73 or becomes active again, this goes next as one PR with four commits (draft body in the queue
item). Pushing the branch to a fork takes one command when Thomas wants it there.

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
