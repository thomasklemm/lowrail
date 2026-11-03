# Gem census: allocation sites outside Rails, by breadth

Lowrail bet G1. Our Rails PRs are mostly merged; the next broad source of avoidable allocations is the gems nearly
every Rails app runs. This census ranks every allocation site outside Rails and Ruby's standard library over census
6's corpus by breadth (apps reached) and objects per operation, classifies the top sites that reach at least five
apps, and builds exact candidates on forks. Nothing is opened or posted; the drafts are below.

**Result.** Over 23 configurations (20 apps, 251 workloads), the 162 gems outside Rails and the standard library allocate
19.6% of all objects; **i18n is the largest and broadest: 248 objects per workload, 2.45% of all allocations, in
19 of 20 apps**, almost all of it in `Backend::Fallbacks`, which every app with `config.i18n.fallbacks` runs (the
`production.rb` that `rails new` generates sets it). Two exact i18n candidates come out of that: **I1** removes **0.40%** of all
allocations (−40 objects per workload, 14 apps) and **I2** **0.32%** (−32, 9 apps), against an A/A of +0.3 on the
same lines; both are the same in the interpreter and YJIT, and Sure (a finance app with 1,322 translations per
dashboard request) carries most of the mean. **C1** in connection_pool removes four Hashes per `#with`: −4.6 objects per workload (0.06% of all) on the 18 configurations that lock
connection_pool 3.x, in 6 apps (Mastodon −27.6).
Every other top site is required work, already covered by an open PR (i18n#758, rack#2519, rack#2520, mail#1693),
or a lead. Allocation counts only; no timing is claimed.

| # | Repo, branch | Per call | Census (interpreter / YJIT) |
| --- | --- | --- | --- |
| I1 | [thomasklemm/i18n `thomasklemm/fallback-locale-identity`](https://github.com/thomasklemm/i18n/tree/thomasklemm/fallback-locale-identity) [`405f196476`](https://github.com/thomasklemm/i18n/commit/405f19647685c9be74637f7157806a4862a6f4d6) | −2 objects per translation that hits the requested locale (`I18n.t(:hello)` 13 → 11) | −40.3 / −40.4 objects per workload, 0.40% of all; 14 apps |
| I2 | [thomasklemm/i18n `thomasklemm/fallback-defaults-without-wrapper`](https://github.com/thomasklemm/i18n/tree/thomasklemm/fallback-defaults-without-wrapper) [`6a57b94bc1`](https://github.com/thomasklemm/i18n/commit/6a57b94bc1e854ab2d00cd16737c6b58ca37851c) (ruby-i18n/i18n#764) | −2 objects per translation with a non-Array `default:` (`default: 3` 14 → 12) | −32.2 / −32.3 objects per workload, 0.32% of all; 9 apps |
| C1 | [thomasklemm/connection_pool `thomasklemm/frozen-interrupt-masks`](https://github.com/thomasklemm/connection_pool/tree/thomasklemm/frozen-interrupt-masks) [`1533388d07`](https://github.com/thomasklemm/connection_pool/commit/1533388d0749bbc30d76021a47d95e4e2a6941de), open as [connection_pool#225](https://github.com/mperham/connection_pool/pull/225) | −4 objects per `#with` (14 → 10) | −4.6 / −4.6 objects per workload, 0.06% of all; 6 apps |

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`3bdc579090`](https://github.com/rails/rails/commit/3bdc57909066eb17dee70fea0b6266edaffa9ffc), census 6's pin.
* **Ruby 4.0.7**, interpreter and `--yjit`; production; services as disposable orb services (Redis, memcached,
  MySQL 8.4 on 3307, PostgreSQL 15 on the local socket).
* **Corpus:** census 6's 19 configurations (census 5's nine apps with Fizzy on SQLite and MySQL, the PG census's
  seven apps plus `mastodon-nops` and `lago-nops`) and the four L6 apps (Thinkroom, Hackatime, Flow, Chatwoot): 23
  configurations, 20 apps, 251 workloads per mode. Census 6's copies were set up on `5810776eec` and run at the pin;
  the L6 copies were set up on the pin.
* **Runs**, in this order, each in both modes: `g`, `g2` (the A/A pair), `i1`, `i2` on all 23 configurations, then
  `cpbase` and `cp` on the 18 configurations that lock connection_pool 3.x (Chatwoot, Discourse, Lago, `lago-nops` and
  Sure lock 2.5.5). [`runs.sh`](../../bench/upstream/gem_census/runs.sh) has the exact commands. A candidate run pins
  one gem to a git commit with `script/census run --gem NAME=OWNER/REPO@SHA`; the run's dependency control
  (`dependencies_outside_rails_match_base` in each run's `meta.json`) found no lock difference outside Rails and
  the pinned gem in any app.
* **Ranking:** `script/census rank --label g2 --gem all` (new): every site in a gem's files, keyed by gem, path and
  the line's source text, so different versions of a gem rank as one site. Excluded: Rails, Ruby's default and
  bundled gems except json, the census harness and its rack-test, and rack's `MockRequest`/`MockResponse`, which only
  the harness calls. [`site_callers.rb`](../../bench/upstream/gem_census/site_callers.rb) traced who calls a site, to
  tell harness work from app work. Per-gem totals:
  [`gem_summary.rb`](../../bench/upstream/gem_census/gem_summary.rb).
* **Candidate deltas:** [`gem_delta.rb`](../../bench/upstream/gem_census/gem_delta.rb): per app, the mean over
  workloads of the objects per operation in the candidate gem's own lines, before (`g2`), after, and the same for the
  A/A (`g` against `g2`). Restricting to the gem's lines removes the apps' own noise (single workloads in Sure,
  Thinkroom and Discourse move by hundreds of objects between identical runs); the change in all allocations is in the
  receipts and agrees within that noise. The share is the change over all allocations of all workloads.
* **Micros:** [`i18n_micro.rb`](../../bench/upstream/gem_census/i18n_micro.rb) and
  [`connection_pool_micro.rb`](../../bench/upstream/gem_census/connection_pool_micro.rb), objects per call with each
  gem's lib directory on the load path.
* **Receipts:** [`data/gem-census/receipts.tar.xz`](data/gem-census/receipts.tar.xz): the run summaries, rankings and
  delta tables; [`data/gem-census/receipts-rerun.tar.xz`](data/gem-census/receipts-rerun.tar.xz): the `i1b` and
  `i2b` reruns of the amended i18n commits, their delta tables and the I2 differential; [`data/gem-census/receipts-i2c.tar.xz`](data/gem-census/receipts-i2c.tar.xz): the `i2c` rerun
  of `7d205cd675` and the 36-case differential.

## Per gem

Interpreter; every gem's YJIT share is within 0.13 percentage points of it. Apps: apps with at least 0.5 objects per operation
in the gem's lines in some workload, of 20.

| Gem | Apps | Objects/workload | Share of all | Largest line (objects/workload) |
| --- | ---: | ---: | ---: | --- |
| i18n | 19 | 248.2 | 2.45% | `backend/fallbacks.rb:54` (42.6) |
| rack | 20 | 95.4 | 0.94% | `query_parser.rb:245` (11.3) |
| nokogiri | 12 | 88.8 | 0.87% | `xml/searchable.rb:270` (7.5) |
| mail | 5 | 74.5 | 0.73% | `encodings/8bit.rb:14` (12.4) |
| sqlite3 | 8 | 69.0 | 0.68% | `statement.rb:125` (41.4) |
| tzinfo | 20 | 66.8 | 0.66% | `timestamp.rb:208` (28.1) |
| json | 19 | 40.5 | 0.40% | `common.rb:364` (20.5) |
| useragent | 7 | 38.6 | 0.38% | `user_agent/version.rb:27` (7.4) |
| importmap-rails | 6 | 27.9 | 0.27% | `importmap_tags_helper.rb:34` (9.3) |
| redis-client | 10 | 24.4 | 0.24% | `ruby_connection/resp3.rb:54` (5.0) |
| jbuilder | 6 | 20.3 | 0.20% | `jbuilder.rb:314` (5.1) |
| globalid | 11 | 15.7 | 0.15% | `uri/gid.rb:159` (3.7) |
| pg | 12 | 15.5 | 0.15% | `connection.rb:403` (5.4) |
| connection_pool | 11 | 13.5 | 0.13% | `connection_pool.rb:110` (2.1) |
| propshaft | 12 | 12.3 | 0.12% | `resolver/static.rb:11` (5.9) |
| turbo-rails | 10 | 11.0 | 0.11% | `frames_helper.rb:42` (2.3) |
| warden | 6 | 10.5 | 0.10% | `proxy.rb:334` (1.8) |
| base64 | 17 | 5.8 | 0.06% | `base64.rb:283` (5.4) |
| devise | 6 | 4.4 | 0.04% | `controllers/helpers.rb:128` (1.0) |
| pagy | 5 | 1.5 | 0.01% | `shared_methods.rb:12` (0.1) |
| sidekiq | 3 | 1.9 | 0.02% | `sidekiq.rb:54` (0.4) |

All sites together: 10,150 objects per workload (interpreter), 10,232 (YJIT); 162 gems allocate 19.6% of them.
Kaminari (under 0.01%) and sprockets-rails (0.02%) are smaller still; turbo-rails, devise, warden, pagy and sidekiq
have no line above 2.3 objects per workload.

## Ranking

The top sites that reach at least five apps, by objects per workload (interpreter; YJIT ranks the same sites in nearly
the same order). Required: the object is the result or is needed by the caller. Covered: an open PR removes it. Lead:
avoidable, but not exact, small and broad together.
# is the site's rank in the full ranking; the missing ranks are further lines of a row's site and nokogiri
serialization (required).

| # | Site | Apps | Objects/workload | Disposition |
| --- | --- | ---: | ---: | --- |
| 1 | i18n `backend/fallbacks.rb:54` `options.merge(fallback_in_progress: true, …)` | 19 | 42.6 | Lead: the merged Hash is what `super` receives; avoiding it changes how the flag reaches the backend |
| 2 | sqlite3 `statement.rb:125` `step` | 8 | 41.9 | Required: the row values |
| 3 | i18n `backend/fallbacks.rb:60` `locale.to_s != fallback.to_s` | 19 | 41.0 | **I1** |
| 4 | i18n `backend/fallbacks.rb:98` `[options[:default]].flatten` | 18 | 33.5 | **I2** |
| 5 | tzinfo `timestamp.rb:208` `time.subsec` | 20 | 28.1 | Required: `Timestamp` keeps the sub-second as a Rational (public API); reached from Active Support's `TimeZone#utc_to_local` |
| 6 | i18n `utils.rb:8` `hash.except(*keys)` | 19 | 22.3 | Required: the interpolation values |
| 7 | i18n `i18n.rb:396` `normalize_keys` | 19 | 22.3 | Lead: the key Array is returned to callers |
| 8 | i18n `backend/base.rb:58` `Utils.except(options, *RESERVED_KEYS)` rest Array | 19 | 21.3 | Covered: open [i18n#758](https://github.com/ruby-i18n/i18n/pull/758) |
| 9 | json `common.rb:364` `Parser.parse` | 13 | 21.1 | Required: the parsed document |
| 10 | i18n `backend/fallbacks.rb:101` `defaults[0, index]` | 18 | 16.6 | **I2** (for Hash and String defaults) |
| 11 | tzinfo `timestamp.rb:193` `allocate` | 20 | 15.2 | Required: the Timestamp |
| 12 | pg `connection.rb:410` `sync_get_result` | 12 | 12.2 | Required: the result |
| 13 | i18n `backend/base.rb:49` `entry.dup` | 17 | 11.4 | Required: callers get their own String |
| 14 | rack `query_parser.rb:245` and `:229` | 18 | 21.2 | Mostly the harness (rack-test's cookie jar); the app part is covered by open [rack#2519](https://github.com/rack/rack/pull/2519) |
| 16 | useragent `browsers/base.rb:120` `product.to_s.downcase` | 7 | 8.7 | Lead: reached through Rails' `allow_browser`; `casecmp?` folds case differently from `downcase ==` outside ASCII |
| 17 | i18n `interpolate/ruby.rb:33` `gsub` | 17 | 7.6 | Required: the interpolated String |
| 18 | nokogiri `xml/searchable.rb:270` `evaluate` | 9 | 7.5 | Required: the node set (sanitizer paths) |
| 19 | useragent `version.rb:27` `scan` | 7 | 7.4 | Lead (as 16) |
| 20 | rack `request.rb:595` `base_url` | 9 | 7.2 | Lead: the String is returned |
| 21 | rack `utils.rb:693` `clean_path_info` `split` | 16 | 6.6 | Lead; open [rack#2302](https://github.com/rack/rack/pull/2302) changes the separator, not the allocation |
| 22 | propshaft `resolver/static.rb:11` `File.join` | 9 | 6.0 | Required: the asset path; unchanged on propshaft main `e7530a0` |
| 23 | redis-client `ruby_connection/resp3.rb:39`, `:67` | 8 | 11.1 | Required: the command buffer (the `capacity:` keyword Hash is a lead) |
| 25 | base64 `base64.rb:283` `pack` | 17 | 5.4 | Required: the output |
| 26 | json `common.rb:860` `generate` | 18 | 5.1 | Required: the output |
| 27 | rack `request.rb:607` `script_name + path_info` | 20 | 4.9 | Lead: the String is returned |
| 30 | rack `utils.rb:331`, `:333`, `:408` (cookies) | 18 | 11.1 | Required: cookie parsing and the `Set-Cookie` value |
| 31 | connection_pool `connection_pool.rb:64`, `:67` `handle_interrupt(Exception => …)` | 11 | 7.7 | **C1** (3.x; 2.5.5 has the same lines) |
| 33 | globalid `uri/gid.rb:159` `split` | 11 | 3.8 | Required: the parsed parts |
| 35 | rack `body_proxy.rb:12` `@block = block` | 20 | 3.4 | Required: the Proc |
| – | rack `response.rb:67` `method(:append)` | 20 | 1.5 | Covered: open [rack#2520](https://github.com/rack/rack/pull/2520) |
| – | mail `encodings/8bit.rb:14` `str.lines.find` | 5 | 12.4 | Covered: open [mail#1693](https://github.com/mikel/mail/pull/1693) |
| – | importmap-rails `importmap_tags_helper.rb:34` | 3 | 9.3 | Below five apps; our [importmap-rails#336](https://github.com/rails/importmap-rails/pull/336) is still open |

i18n main (`a0a416e570`) has only CI changes since 1.15.2, so none of the i18n sites is an upgrade note. Its open PRs
were checked: none touches `fallbacks.rb`; #758 (Utils.except) and #759 (localize formats) are the allocation ones.

## Candidates

All three are one commit on the gem's current main, pushed to `thomasklemm` forks, with the gem's own suite passing.
After Sol review, I1 and I2 were amended to be exact (first versions `a9de2f7071` and `568d730577`; see each section)
and rerun in the census as `i1b` and `i2b`; a second round of review made I2 exact for nil/false and Array defaults
(`7d205cd675`, rerun `i2c`).
The census rows below are i18n's (or connection_pool's) own lines: mean objects per workload, interpreter / YJIT.

### I1: compare fallback locales before converting them to Strings

`Backend::Fallbacks#translate` calls `on_fallback` only when the translation came from another locale, and checks
that with `locale.to_s != fallback.to_s`. The first fallback is the requested locale itself, so every translation
found there converted two Symbols to Strings. I1 adds `!locale.equal?(fallback) &&` in front: the same object always
gives the same String, so the result is unchanged, and different objects still go through the String comparison (a
String locale with its Symbol fallback still does not count as a fallback). Equal Symbols are the same object, so
the common case still skips the conversion.

The first version (`a9de2f7071`) used `locale != fallback`, which dispatches a custom `==`: a locale object whose
`to_s` is `"de"` and whose `==` returns true for `:en` skipped `on_fallback` where the base calls it once. `equal?`
is identity and is not meaningfully overridable. The added test (that locale, translated through the `:en`
fallback, records one `on_fallback`) fails on `a9de2f7071` and passes on master and on `405f196476`.

* Micro, objects per call, interpreter and YJIT: `I18n.t(:hello)` 13 → 11, `I18n.t(:greet, name:)` 21 → 19,
  `human_attribute_name` (hit) 21 → 19; unchanged from the first version.
* Suite: 1,608 runs, 0 failures (`bundle exec rake test`).
* Census rerun `i1b`: identical to the first version in every app, −40.3 / −40.4 objects per workload, 0.40% of all
  allocations, 14 apps.

### I2: extract fallback defaults without a wrapper Array

`extract_non_symbol_default!` runs for every translation with a `default:`. It started with
`[options[:default]].flatten`: a wrapper Array and its flattened copy, even for a single Symbol. Flattening a
one-element wrapper does exactly two things to the element (`flatten` in `array.c`): it converts it with
`rb_check_array_type`, which is `Array.try_convert`, and if that returns an Array it flattens that Array with
`Array#flatten`'s own C code, never the element's `flatten`. I2 does those two steps directly:

```ruby
if Array === default
  defaults = [default].flatten
elsif (converted = Array.try_convert(default))
  defaults = [converted].flatten
else
  if !default.is_a?(Symbol)
    options[:default] = [] if default
    return default
  end
  return
end
```

(Code as of `6a57b94bc1`, opened as ruby-i18n/i18n#764; the history of the versions follows.)

A default that does not convert is the wrapper's only element, so the old code returned it with
`options[:default] = []` unless it was a Symbol (the old `detect` uses the same `is_a?(Symbol)` call).

The first version (`568d730577`) returned a plain String or Hash as is and called `default.flatten` on an Array. Sol
found two differences: a String or Hash with a singleton `to_ary` (or a `method_missing` for it) was converted by the
old code, and an Array subclass's own `flatten` was called. `Array.try_convert` keeps both: it calls `to_ary`
through `rb_check_funcall` exactly as `flatten` does, including `respond_to_missing?`/`method_missing` (a plain
`respond_to?(:to_ary, true)` check would miss a `method_missing`-only conversion), and `bind_call` runs
`Array#flatten` on a subclass. A 26-case differential of master's method against the new one (Symbol, String, frozen
String, Hash, Proc, Integer, flat, nested, frozen, long and recursive Arrays, Array subclasses with their own
`flatten`, nested subclasses, Strings and Hashes with `to_ary` or `method_missing`, `respond_to?` that lies, private
`to_ary`, `to_ary` returning nil, a non-Array or nested convertibles, `is_a?` overrides on the default and on
elements) compares return value, identity, the options left behind, exceptions and the calls made: no differences
(the first version differs in four).

* Micro, objects per call, interpreter and YJIT: Array default 21 → 18, Array default that misses 36 → 33, String
  23 → 21, Symbol 29 → 27, Hash 22 → 20 (unchanged from the first version), Integer 14 → 12 (new).
* Tests added: a nested Array default is not mutated; a default that responds to `to_ary` still flattens; a String
  default with a singleton `to_ary` or a `method_missing` for it is still converted; an Array subclass default is
  flattened without calling its `flatten`. The last two fail on `568d730577` and pass on master and on `1d8c5793d2`.
  Suite: 1,611 runs, 0 failures.
* Census rerun `i2b`: −32.7 / −32.9 objects per workload, 0.32% of all allocations, 17 apps (the first version:
  −19.8 / −19.9, 0.20%, 14 apps). The exact version also skips the wrapper for an Integer `default:`, which the
  first version sent through `[default].flatten`: Docuseal (417 per run) and Discourse (117) translate with Integer
  defaults (−64.2 and −16.7 objects per workload). Micro: `I18n.t(key, default: 3)` 14 → 12 (hit), 21 → 19 (miss).
  Lock control clean in all 23 apps.

Second review round (Sol and Astra on `1d8c5793d2`), two more fixes, now in `7d205cd675`:

* **nil and false:** the old code left `options[:default]` alone (its `detect` returns the falsy default, so nothing
  is assigned); `1d8c5793d2` set it to `[]` and raised `FrozenError` on frozen options. They are now returned with
  the options untouched. `translate` only calls the method when the default is truthy, so this is reachable only
  from subclasses that call it directly.
* **Array defaults:** flattening the caller's Array directly reads its elements in a different order than
  flattening the wrapper, so a `to_ary` hook that changes an earlier element gave `"changed"` instead of
  `"original"`; a global `Array.prepend` of `flatten` was also bypassed. Every Array default (`Array === default`)
  now takes the old `[default].flatten`; the fast paths are for non-Array defaults only.
* **Accepted, no change:** a global `Array#flatten` redefinition is no longer called on the non-Array paths (the
  wrapper is what called it). With a prepended `flatten` that only logs, results match the old code in every case;
  only the call is skipped.

The differential now has 36 cases (adding nil, false, a default overriding `!`, and Arrays whose element `to_ary`
mutates, clears or extends them), run plain, with frozen options and with a prepended `flatten`: `7d205cd675` matches
master in all of them (with the prepend, apart from the skipped call); `1d8c5793d2` differs in three (nil, false, the
earlier-element mutation). The two new tests fail on `1d8c5793d2` and pass on master and `7d205cd675`; suite 1,613
runs, 0 failures. Micro: Array defaults no longer save (21 → 21, 36 → 36); String 23 → 21, Symbol 29 → 27, Hash
22 → 20, Integer 14 → 12. Census rerun `i2c`: −32.2 / −32.3 objects per workload, 0.32% of all allocations; 9 apps
(10 configurations) save at least 0.5 per workload. Sure (−722), Docuseal (−64), Lobsters (−24) and Discourse
(−17) keep their saving; Blog loses its −6 (Array defaults) and Casa drops from −8.1 to −7.2. Lock control clean.

Third review round (Sol and Astra on `7d205cd675`), now in `6a57b94bc1`: flattening a `to_ary`-converted default
directly copied the prefix at a different point than the wrapper walk (a hook setting `ary[0]` gave `"Changed"`
instead of `"Original"`), and branching on `is_a?(Symbol)` skipped the old `!` call on its result. A converted
default now takes `[converted].flatten`, which walks it as the wrapper did, so the `FLATTEN` constant and its
`bind_call` (and their reload warning) are gone; the scalar path evaluates `!default.is_a?(Symbol)` and assigns
`options[:default] = []` only for a truthy default, as `detect` with `if first_non_symbol_default` did. The two repros
are tests that fail on `7d205cd675`; suite 1,615 runs, 0 failures. Census and micro unchanged (−32.2 / −32.3 objects
per workload, 0.32%; the Integer, String, Hash and Symbol paths are the same). A fourth round found only a call
order for converted defaults under a globally prepended or redefined `Array#flatten`, which is the
core-method-redefinition class accepted above. Opened as ruby-i18n/i18n#764.

### Census, I1 and I2

i18n's own lines, objects per workload, interpreter / YJIT. Lago and `lago-nops` do not translate.

| App | Workloads | i18n objects/op | I1 | I2 | A/A | All objects/op |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 160.3 | −2.8 / −2.8 | +0.0 / +0.0 | +0.0 / +0.0 | 1519 |
| campfire | 9 | 1.1 | −0.2 / −0.2 | −0.2 / −0.2 | +0.0 / +0.0 | 5672 |
| casa | 10 | 248.9 | −33.2 / −33.2 | −7.2 / −7.2 | +0.0 / +0.0 | 12590 |
| chatwoot | 14 | 1.1 | −0.1 / −0.1 | +0.0 / +0.0 | +0.0 / +0.0 | 15404 |
| codetriage | 7 | 28.6 | −0.3 / −0.3 | −1.7 / −1.7 | +0.0 / +0.0 | 2554 |
| discourse | 14 | 321.5 | −45.0 / −45.0 | −16.7 / −16.7 | +0.0 / +0.0 | 11717 |
| docuseal | 13 | 497.7 | −65.5 / −65.5 | −64.2 / −64.2 | +0.0 / +0.0 | 7131 |
| fizzy | 14 | 10.6 | −1.0 / −1.0 | −0.4 / −0.4 | +0.0 / +0.0 | 9184 |
| fizzy-mysql | 14 | 10.6 | −1.0 / −1.0 | −0.4 / −0.4 | +0.0 / +0.0 | 9053 |
| flow | 10 | 27.8 | −0.4 / −0.4 | −0.2 / −0.2 | +0.0 / +0.0 | 9740 |
| hackatime | 12 | 42.2 | −2.0 / −2.0 | −0.2 / −0.2 | +0.0 / +0.0 | 7344 |
| lobsters | 11 | 122.9 | −23.6 / −23.6 | −23.6 / −23.6 | +0.0 / +0.0 | 10429 |
| loomio | 15 | 54.2 | −10.9 / −10.9 | −3.1 / −3.1 | +0.0 / +0.0 | 9083 |
| mastodon | 14 | 19.3 | −3.4 / −3.4 | −3.0 / −3.0 | +0.0 / +0.0 | 15743 |
| mastodon-nops | 14 | 19.3 | −3.4 / −3.4 | −3.0 / −3.0 | +0.0 / +0.0 | 15697 |
| pingcrm | 8 | 27.2 | −0.5 / −0.5 | +0.0 / +0.0 | +0.0 / +0.0 | 2689 |
| react-starter-kit | 8 | 13.6 | −0.2 / −0.2 | +0.0 / +0.0 | +0.0 / +0.0 | 1789 |
| redprints-cfp | 8 | 79.4 | −1.2 / −1.2 | +0.0 / +0.0 | +0.0 / +0.0 | 1872 |
| sure | 9 | 4655.6 | −849.4 / −854.4 | −722.3 / −727.3 | +7.0 / +0.0 | 52306 |
| thinkroom | 9 | 37.7 | −1.3 / −1.3 | −0.4 / −0.4 | +0.0 / +0.0 | 5215 |
| writebook | 8 | 3.8 | −0.8 / −0.8 | −0.8 / −0.8 | +0.0 / +0.0 | 4895 |
| **All (23 configurations)** | 251 | 248.2 | −40.3 / −40.4 | −32.2 / −32.3 | +0.3 / +0.0 | 10150 |

Rows are the reruns `i1b` and `i2c` of the amended commits. Sure dominates both means: without it, I1 removes about
10 objects per workload and I2 about 6.5. I1's apps are the ones that translate on most requests (Docuseal, Discourse,
Casa, Lobsters, Loomio); I2's are the ones that pass `default:` (Sure, Docuseal and Discourse with Integer defaults,
Lobsters, Casa). The change in all allocations agrees within the A/A noise: I1 −36.4 / −38.2 and I2 −22.3 /
−26.6 objects per workload, A/A −23.1 / −2.5 (the interpreter A/A is mostly Thinkroom, −535 per workload between
identical runs).

### C1: reuse constant interrupt masks in `ConnectionPool#with`

`#with` calls `Thread.handle_interrupt(Exception => :never)` and `(Exception => :immediate)`. A Hash literal passed as
keywords costs two objects per call: the Hash and the positional copy `handle_interrupt` receives. C1 passes two
frozen private constants instead. `handle_interrupt` reads the mask and keeps no reference to it.

* Micro: `pool.with {}` 14 → 10 objects, interpreter and YJIT.
* Suite: 87 runs, 0 failures; `standardrb` clean.

Census, against connection_pool main (`cpbase`, `mperham/connection_pool@5a3d762481`), on the 18 configurations
that lock 3.x; the A/A is `g`/`g2`, on the released 3.0.2. Configurations whose workloads never check out are left
out.

| App | Workloads | connection_pool objects/op, 3.0.2 → main | C1 | A/A (3.0.2) |
| --- | ---: | ---: | ---: | ---: |
| campfire | 9 | 4.7 → 8.0 | −2.7 / −2.7 | +0.0 / +0.0 |
| writebook | 8 | 4.4 → 7.5 | −2.5 / −2.5 | +0.0 / +0.0 |
| codetriage | 7 | 7.0 → 12.0 | −4.0 / −4.0 | +0.0 / +0.0 |
| docuseal | 13 | 1.6 → 2.8 | −0.9 / −0.9 | +0.0 / +0.0 |
| mastodon | 14 | 48.4 → 83.2 | −27.6 / −27.6 | +0.0 / +0.0 |
| mastodon-nops | 14 | 48.4 → 83.2 | −27.6 / −27.6 | +0.0 / +0.0 |
| loomio | 15 | 0.5 → 0.8 | −0.3 / −0.3 | +0.0 / +0.0 |
| flow | 10 | 6.3 → 10.9 | −3.7 / −3.4 | +0.0 / +0.0 |
| **All (18 configurations)** | 194 | 8.1 → 13.9 | −4.6 / −4.6 | +0.0 / +0.0 |

Mastodon checks out about seven times per workload, so C1 saves 4 per checkout there as in the micro.

**Upgrade note:** connection_pool main allocates more than 3.0.2 (8.1 → 13.9 objects per workload on the same apps,
about five more per checkout). Main forwards `**kwargs` through more methods than 3.0.2 (`checkout` → `pop` →
`try_fetch_connection` → `connection_stored?`/`fetch_connection`, and since #223 `push`/`store_connection` on checkin),
and each hop builds an empty keyword Hash. C1 does not touch that; it is a lead (below), worth raising before main is
released.

## Drafts

i18n has no contributing guide or PR template; its merged PRs are each one small change (#750, #729, #726, #701,
#699), and the open allocation PRs from one author are separate (#758, #759). With our one-PR-per-gem limit, I1 goes
first; I2 waits for it, as its own PR.

C1 is open as [connection_pool#225](https://github.com/mperham/connection_pool/pull/225) with the draft below as
written. Its CI waits for maintainer approval of a fork contributor's workflow (`action_required`).

Short, in each gem's PR style (i18n#758: Summary / Benchmark / Testing; connection_pool#223: Summary /
Verification). Allocation counts only.

### I1 (ruby-i18n/i18n, from `thomasklemm/fallback-locale-identity` `405f196476`)

**Title:** Skip the String comparison when a fallback hits the requested locale

#### Summary

`Backend::Fallbacks#translate` calls `on_fallback` only when the translation came from a different locale, and checks that with `locale.to_s != fallback.to_s`. Most lookups hit the first fallback, which is the requested locale itself, so every such translation converts both Symbols to new Strings just to find they are equal.

This skips the conversion when the locale is the fallback object itself (`equal?`), which it is for Symbol locales, and keeps the String comparison for everything else, so a String and a Symbol for the same locale still count as the same locale, and a locale object with its own `==` is still compared as a String. `on_fallback` is called in exactly the same cases as before.

#### Benchmark

Ruby 4.0.7, objects allocated per call with `I18n::Backend::Fallbacks` included (same with and without YJIT):

```
                                 before   after
I18n.t(:hello)                     13  ->  11
I18n.t(:greet, name:)              21  ->  19
human_attribute_name (hit)         21  ->  19
```

Across 20 open-source Rails apps (251 request, job and mailer workloads), this removes 0.4% of all allocated objects; 14 of the apps translate through this path.

#### Testing

Added a test with a locale whose `==` matches the fallback but whose String does not; `on_fallback` is still called for it. The test suite passes (1,608 runs).

### I2 (ruby-i18n/i18n#764, from `thomasklemm/fallback-defaults-without-wrapper` `6a57b94bc1`)

**Title:** Avoid wrapping the default in an Array in Fallbacks#extract_non_symbol_default!

#### Summary

`Backend::Fallbacks#translate` calls `extract_non_symbol_default!` for every translation that has a `default`. It starts with `[options[:default]].flatten`, which allocates a wrapper Array and a flattened copy even when the default is a single Symbol, String, Hash or Integer.

Flattening a one-element wrapper converts the element with `Array.try_convert` and flattens the result with `Array#flatten`. For a default that is not an Array, this does those two steps without the wrapper: a default that converts through `to_ary` (including through `method_missing`) is flattened as before, a Symbol default returns early, a nil or false default is returned with the options untouched, and any other default is returned as the non-Symbol default with `options[:default] = []`, as before. Array defaults keep `[default].flatten` unchanged.

#### Benchmark

Ruby 4.0.7, objects allocated per call with `I18n::Backend::Fallbacks` included (same with and without YJIT):

```
                                 before   after
Array default                      21  ->  21
String default                     23  ->  21
Symbol default                     29  ->  27
Hash default                       22  ->  20
Integer default                    14  ->  12
```

Across 20 open-source Rails apps (251 request, job and mailer workloads), this removes 0.3% of all allocated objects; most of it is in apps that pass Integer defaults or translate heavily on one dashboard.

#### Testing

Added tests that a nested Array default is not mutated, that a default (including a String) responding to `to_ary` still flattens, that an Array subclass's `flatten` is not called, that an Array default is flattened as given when an element's `to_ary` changes it, and that a nil or false default leaves the options untouched. The test suite passes (1,613 runs).

### C1 (mperham/connection_pool, from `thomasklemm/frozen-interrupt-masks`)

**Title:** Reuse frozen interrupt masks in ConnectionPool#with

#### Summary

- `#with` passes `Exception => :never` and `Exception => :immediate` to `Thread.handle_interrupt` as Hash literals, which build a new Hash (and its keyword copy) on every checkout
- keep both masks as frozen private constants and pass them positionally
- behavior is unchanged: `Thread.handle_interrupt` reads the mask and does not keep or mutate it

#### Verification

- `pool.with {}` allocates 14 objects before, 10 after (Ruby 4.0.7, with and without YJIT)
- across the 16 open-source Rails apps in our census that lock connection_pool 3.x, 4 objects fewer per checkout in every app that checks out (Mastodon: 28 fewer per request or job)
- full suite: 87 runs, 0 failures
- `standardrb lib/connection_pool.rb`

## Leads

* **i18n `fallback_options = options.merge(…)`** (19 apps, 42.6): the largest gem site. Passing the in-progress flag
  another way (a thread-local, or a keyword the backend strips) would remove a Hash per fallback step, but it changes
  what custom backends receive.
* **tzinfo `Timestamp.for_time`** (20 apps, 43 together): a Timestamp and a Rational per Active Support time-zone
  conversion. The Rational is part of tzinfo's API; avoiding it belongs in Active Support (caching the period) rather
  than tzinfo.
* **useragent** (7 apps, 38.6): parsing the User-Agent on every request through Rails' `allow_browser`. Caching the
  parsed agent per request string, in Rails, would remove almost all of it.
* **connection_pool main's keyword forwarding** (see the upgrade note under C1): about five keyword Hashes per
  checkout that 3.0.2 does not allocate. Forwarding keywords only when some were given might avoid it; not built or measured, and it touches
  #223's code, so it needs its author's view first.
* **connection_pool checkout leak under `Fiber#raise`** (adversarial review of C1): with a minimal fiber scheduler
  that delivers `Fiber#raise`, `#with` can leak a checkout or checkin; base (`5a3d762481`) does the same, so it is
  not part of #225. Not yet reduced to a reproduction here.
* **connection_pool 2.5.5**: Chatwoot, Discourse, Lago and Sure lock 2.5.5, which has the same `handle_interrupt`
  lines; C1 reaches them only once they upgrade.
