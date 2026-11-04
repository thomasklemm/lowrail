# Action Pack request path: route formats and renderers (C13)

This round looked for small, exact rails/rails changes on the Action Pack / Action Dispatch request path: route
recognition and generation, parameters, request/response, cookies and session, middleware, Metal dispatch,
callbacks, rescue, instrumentation, MIME lookup and flash. It used census 8's CPU ranking
([rails-main-census-8](rails-main-census-8.md)) to pick sites. `UriEncoder#escape` was left to C9.

**Result: two candidates, opened and merged 2026-11-04 by amatsuda: [#59619](https://github.com/rails/rails/pull/59619)
(AP-1, merge `32c132d134`) and [#59620](https://github.com/rails/rails/pull/59620) (AP-2, merge `fa03095c6f`).** A test-fixture
gap found from AP-2's CI run merged as [#59624](https://github.com/rails/rails/pull/59624) (merge `d09361d7cf`). AP-1 was reworked after opening ([below](#ap-1-rework-after-opening)).

| # | Branch | Per call, main → candidate (Ir, interp / YJIT / ZJIT) | Readability |
| --- | --- | --- | --- |
| AP-1 | [`thomasklemm/journey-format-join-literals`](https://github.com/thomasklemm/rails/tree/thomasklemm/journey-format-join-literals) [`b86b5887b3`](https://github.com/thomasklemm/rails/commit/b86b5887b3bb81f6666eb3b7f72fdeee79149de3) (#59619) | `post_path(post)` 34,472 → 31,855 (−7.6%) / 15,571 → 14,840 (−4.7%) / 19,843 → 17,634 (−11.1%); 7 → 6 objects | L1 |
| AP-2 | [`thomasklemm/all-renderers-without-union`](https://github.com/thomasklemm/rails/tree/thomasklemm/all-renderers-without-union) [`670e0c390f`](https://github.com/thomasklemm/rails/commit/670e0c390f848f178bc211fc0c6ad0dd086253de) (#59620) | renderer check of a template render 11,497 → 7,568 (−34%) / 9,237 → 5,314 (−42%) / 9,443 → 5,396 (−43%) | L0/L1 |

Both are one commit on rails/rails main `9b116f1fed`, which was still main at the last fetch (2026-11-04), with no
later commits to either file. Neither changes a public method or any output. Searches of open and closed PRs and
issues (`Journey::Format`, `Format#evaluate`, `journey format`, `_all_renderers`, `renderers`, `use_renderers`)
found nothing overlapping. amatsuda's "Reduce allocations across URL generation" (#59058, merged 2026-10-15) made
`evaluate` append into one buffer; AP-1 builds on that by giving it fewer, longer literals to append. #57830 (merged
2026-07-07, unreleased) introduced the per-render union that AP-2 skips.

## Pins and method

* **Rails:** `rails/rails` main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed); a second
  worktree of the same commit (`aa`) is the A/A.
* **Ruby 4.0.9** (interpreter, `--yjit`) and **Ruby master `9aa0898240`** (interpreter, `--zjit`), as in census 8.
* **Micros:** [`micro_ap.rb`](../../bench/upstream/actionpack_request_path/micro_ap.rb) loads Action Pack from a
  worktree and builds a small app (resources routes, a controller); case files
  [`cases_format.rb`](../../bench/upstream/actionpack_request_path/cases_format.rb),
  [`cases_render.rb`](../../bench/upstream/actionpack_request_path/cases_render.rb). Instructions (Ir) per call with
  Callgrind, toggled on the timed loop, median of 3 runs per variant
  ([`irtab.sh`](../../bench/upstream/actionpack_request_path/irtab.sh),
  [`irsum.py`](../../bench/upstream/actionpack_request_path/irsum.py)). Objects per call with GC disabled. Wall
  time: [`nsround.sh`](../../bench/upstream/actionpack_request_path/nsround.sh), 15 rotated rounds of main, A/A and
  candidate, pinned to one CPU, median ([`nssum.py`](../../bench/upstream/actionpack_request_path/nssum.py)).
* **ruby-bench** `73918b2` railsbench, lobsters, shipit (the bench-local setup of earlier rounds). Rails 8.1 is
  what ruby-bench bundles, so [`lowrail_ap.rb`](../../bench/upstream/actionpack_request_path/lowrail_ap.rb)
  redefines the touched methods with main's body (variants `main1`, `main2`) or the candidate's (`cand`), and
  [`rb_ap.sh`](../../bench/upstream/actionpack_request_path/rb_ap.sh) counts Ir per benchmark iteration
  ([`rbsum.py`](../../bench/upstream/actionpack_request_path/rbsum.py)).
* **Differentials:** [`diff_fmt.rb`](../../bench/upstream/actionpack_request_path/diff_fmt.rb) and
  [`diff_rend.rb`](../../bench/upstream/actionpack_request_path/diff_rend.rb) print every observable result
  (bytes, encoding, frozen state, class, exception class and message) and are compared byte for byte, main vs
  candidate, in six modes: 4.0.9 interpreter, YJIT, YJIT with call threshold 1, master interpreter, ZJIT, ZJIT
  with call threshold 1 ([`difrun.sh`](../../bench/upstream/actionpack_request_path/difrun.sh)).
* **Suites:** Action Pack (4505 runs) on both final commits and Action View (3384 runs) on AP-1, 0 failures,
  `RAILS_STRICT_WARNINGS=1`; RuboCop clean on both files.

## AP-1: join adjacent literals when building a route's format

**Site.** `Journey::Format#evaluate` walks the parts of a route's path and appends each one to a buffer. The parser
gives one part per token, so `/posts/:id(.:format)` yields `"/"`, `"posts"`, `"/"`, `:id` and the optional group:
three literal appends, and one per segment for nested resources. Census 8: `Format#add_to` is interpreter method
rank 30 (0.26% of interpreted instructions, 19 apps), YJIT rank 130 (0.07%); its loop line `visitors.rb:53` is
line rank 207 (14 apps). `Format#evaluate` runs 10,357 times per railsbench iteration, 3,612 in lobsters, 2,840 in
shipit (TracePoint).

**Change.**

```ruby
@parts = parts.chunk { |part| String === part }.flat_map { |literal, run| literal ? [-run.join] : run }
```

and the index loop walks `@parts`, so `@children` and `@parameters` index the joined array. The Ir table was
measured on an earlier commit that builds the same parts (only unfrozen); rerun on the final commit (median of 3, 4.0.9),
`post_path` is 34,528 → 32,586 interpreted (A/A 0.00%) and 15,565 → 14,994 with YJIT (A/A +0.23%), `posts_path`
26,338 → 25,367 (A/A −0.12%) and 12,018 → 11,689 (A/A −0.22%), the same within the spread. The PR body uses these.

**Out loud.** Group the parts into runs of literal strings and runs of everything else. Join each run of literals
into one frozen, deduplicated string, and keep the other runs as they are. Then note where the parameters and
nested groups sit in that list.

**Shape and metrics.** One expression, no new names, no ternary beyond one short line. `Format#initialize`: flog
6.5 → 12.8, ABC 6.56 → 12.73, cyclomatic 4 → 7, perceived 3 → 6. The rise is the two blocks of
`chunk`/`flat_map`, counted as branches; it is construction code that runs once per route at boot, and the cold
read understood it on the first read. RuboCop (Rails config) clean.

**Per call** (Ir, median of 3; A/A is the second main worktree):

| Call | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `post_path(post)` | interp 4.0.9 | 34,526 | −0.11% | 32,587 | −5.6% |
| | YJIT 4.0.9 | 15,567 | +0.26% | 14,985 | −3.7% |
| | interp master | 35,590 | +0.10% | 33,644 | −5.5% |
| | ZJIT master | 19,840 | +0.02% | 18,595 | −6.3% |
| `posts_path` | interp 4.0.9 | 26,308 | +0.11% | 25,369 | −3.6% |
| | YJIT 4.0.9 | 12,004 | −0.02% | 11,680 | −2.7% |
| | interp master | 27,211 | −0.23% | 26,201 | −3.7% |
| | ZJIT master | 14,643 | −0.10% | 14,050 | −4.1% |
| `post_comment_path(post, 7)` | interp 4.0.9 | 44,843 | +0.00% | 41,005 | −8.6% |
| | YJIT 4.0.9 | 20,290 | +0.17% | 19,151 | −5.6% |
| | interp master | 46,641 | −0.02% | 42,700 | −8.5% |
| | ZJIT master | 26,715 | +0.00% | 24,259 | −9.2% |
| `url_for(controller:, action:, id:, only_path: true)` | interp 4.0.9 | 166,394 | −0.17% | 164,141 | −1.4% |
| | YJIT 4.0.9 | 119,180 | +0.05% | 118,643 | −0.5% |
| | interp master | 175,492 | +0.12% | 173,546 | −1.1% |
| | ZJIT master | 132,788 | +0.17% | 131,730 | −0.8% |

Objects per call are unchanged (7, 6 and 8): `evaluate` already appends into one buffer. Wall time (`post_path`, 15 rotated pinned rounds,
median): interpreter 4,440 → 4,226 ns (−4.8%, A/A −1.4%), YJIT 2,037 → 1,955 ns (−4.1%, A/A +2.4%). The smallest common input with a gain is a collection path such as `posts_path` (−3.6% interpreted);
a route that is a single literal (`root_path`) is unchanged. Memory: the joined strings are new per distinct
literal run, while the parser's pieces were shared interned strings, so formats retain about 49 bytes more per
route (1,500 resources-style routes: 709,832 → 782,752 bytes after GC).

**ruby-bench** (Ir per iteration; candidate against the mean of `main1` and `main2`):

| App | Mode | main1 | main2 (A/A) | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | interp | 6,957,399,342 | 6,966,571,862 (+0.13%) | 6,939,169,152 | −0.33% |
| railsbench | YJIT | 4,342,021,005 | 4,343,393,420 (+0.03%) | 4,338,228,888 | −0.10% |
| lobsters | interp | 4,268,530,416 | 4,266,758,889 (−0.04%) | 4,259,617,535 | −0.19% |
| lobsters | YJIT | 3,020,793,392 | 3,022,786,759 (+0.07%) | 3,023,381,934 | +0.05% |
| shipit | interp | 5,846,087,755 | 5,846,608,625 (+0.01%) | 5,845,336,939 | −0.02% |
| shipit | YJIT | 3,154,901,277 | 3,157,523,770 (+0.08%) | 3,154,233,140 | −0.06% |

Interpreted railsbench and lobsters move by more than their A/A; the YJIT runs and shipit are within noise.

**Exactness.**

* `diff_fmt.rb` (16 route specs × every pair of 10 parameter values, paths in BINARY, ISO-8859-1,
  Windows-1252, US-ASCII and broken UTF-8, escaped `\:`/`\(`, nested optional groups, globs, `(/:locale)`, named
  helpers on the optimized and general path, constraint failures, `url_for`, polymorphic, `direct`, `resolve`, an
  engine, redirects, `Ractor.make_shareable`): identical in all six modes (1,401 lines each).
* Why it is equivalent: the only literals in a format are the parser's frozen UTF-8 `"/"` and `"."` and slices of
  the route path, which share the path's encoding; parameter output is ASCII-only (escaped or unchanged). Joining
  them first gives the same buffer contents and encoding as appending them one by one. Route paths in encodings
  that aren't ASCII-compatible raise in `Parser.parse`, before the format is built, on both.
* `Format` is built only by `FormatBuilder` and read only through `Route#format`; `@parts` is read nowhere else in
  Action Pack, Action View or Railties.
* Checklist: no user object is reached (parts are plain Strings from `byteslice`, Parameters or Formats);
  `Array#join` on Strings calls nothing on them; the `String ===` guard keeps `join` away from Parameters, so no
  `to_s`/`to_ary` is called; no constants, load order or Ractor state change.

**Reviews.**

* Primary review (correctness and maintainability): approve-with-nits, L1. Its one finding, that the joined
  strings were unfrozen and not deduplicated, is fixed with `-`. A second note (an encoding error moving from
  `evaluate` to build time) applies only to hand-built `Format.new` arrays the parser can't produce.
* Adversarial round (parsing): no difference. 2 seeds × 20,000 random paths over 6 encodings with invalid bytes, a
  7 × 14 encoding matrix, and a full app (shallow and nested resources, scopes with optional locale, engines
  mounted at dynamic paths, redirects, `direct`/`resolve`, `recognize_path`, redraws under 4 threads, formatters
  shared into a Ractor), on 4.0.9 interpreter, YJIT and master ZJIT.
* Cold read: the first form (`chunk_while { … }.map { … }`) was L2 and needed a second read; rewritten as
  `chunk`/`flat_map`, the second cold read was L1 on the first read, and its one suggestion (make both branches
  arrays) was taken.

### AP-1 rework after opening

Sol's review (open after fixes) asked for tests, the block form, a narrower exactness claim and a shorter body;
those went into head `5bce8c7450`, opened as #59619. Thomas then found the `chunk`/`flat_map` line hard to read and
asked for a plainer `Format` overall; he set the PR to draft. His shape, measured against the each/return variant:

```ruby
def initialize(parts)
  @parts      = join_adjacent_literals(parts)
  @parameters = @parts.grep(Parameter)
end

protected def add_to(buffer, hash)
  return if @parameters.any? { |parameter| hash[parameter.name].nil? }
  # @parts loop unchanged
end

private
  # Joins adjacent literals, so "/", "posts", "/" is appended as one "/posts/".
  def join_adjacent_literals(parts)
    parts.each_with_object([]) do |part, joined|
      if String === part && String === joined.last
        joined[-1] = -(joined.last + part)
      else
        joined << part
      end
    end
  end
```

* `@children` was assigned and never read (the `children` readers in `nodes/node.rb` belong to the AST nodes);
  no `instance_variable_get` of it in Action Pack, Action View or Railties.
* `@parameters` holds the Parameter objects instead of indexes into `@parts` (`grep` uses `===`, as the old
  `when Parameter` did; same order, same nil checks in the same order).
* A lone literal is now kept as the parser's own (already interned) string, as on main.

**Out loud.** Join neighbouring literals into one; remember which parts are parameters. When generating, give up
if any parameter has no value; otherwise append each part.

Generation, Ir per call (median of 3, A/A ≤ 0.2%; `cur` is the opened `5bce8c7450`, `loop` keeps
`@parameters.each { return if … }` over the objects):

| Call | Mode | main | cur | loop | `any?` (final) |
| --- | --- | ---: | ---: | ---: | ---: |
| `post_path` | interp 4.0.9 | 34,472 | 32,553 | 32,354 | 31,855 (−7.6%) |
| | YJIT 4.0.9 | 15,571 | 14,987 | 14,908 | 14,840 (−4.7%) |
| | ZJIT master | 19,843 | 18,608 | 18,515 | 17,634 (−11.1%) |
| `posts_path` | interp 4.0.9 | 26,305 | 25,332 | 25,218 | 24,707 (−6.1%) |
| | YJIT 4.0.9 | 11,959 | 11,683 | 11,633 | 11,258 (−5.9%) |
| | ZJIT master | 14,638 | 14,002 | 13,979 | 13,023 (−11.0%) |
| `post_comment_path` | interp 4.0.9 | 44,851 | 40,931 | 40,650 | 40,122 (−10.5%) |
| | YJIT 4.0.9 | 20,254 | 19,127 | 19,000 | 19,273 (−4.8%) |
| | ZJIT master | 26,717 | 24,211 | | 23,254 (−13.0%) |
| `root_path` | interp / YJIT 4.0.9 | 22,218 / 10,390 | | | 22,165 / 10,334 (−0.2% / −0.5%) |

`any?` is faster than the loop because the loop's `return` from inside the `each` block is a non-local return,
which allocates whenever it is taken: on main and `loop`, every skipped optional group (here `(.:format)`) costs one
object. Objects per call: `post_path` 7 → 6, `posts_path` 6 → 5, `post_comment_path` 8 → 7. Wall time
(`post_path`, 15 rotated pinned rounds, median): 4,336 → 3,988 ns interpreted (−8.0%, A/A +0.1%), 2,005 → 1,880 ns
with YJIT (−6.2%, A/A −0.5%). The only regression against `loop` is YJIT `post_comment_path` (+1.4%); kept for the
clearer form and the gain everywhere else.

Construction ([`fmt_build.rb`](../../bench/upstream/actionpack_request_path/fmt_build.rb), 1,500 resources-style
paths): Ir per route 63,754 (main) → 123,622 (`cur`) → 75,792 (final, +19%); about 8 → 10 µs per route, so about
3 ms of boot for 1,500 routes; objects per route 25 → 83 → 34. Bytes reachable from the formats (arrays, formats,
strings; shared objects once) 536 → 554 → 344 per route: the index arrays are gone and `@parts` is shorter.

Checks: `diff_fmt.rb` identical to main in all six modes (1,401 lines); the new route tests, the Journey tests
(201 runs), Action Pack (4,508 runs) and Action View (3,390 runs) green; RuboCop clean. Metrics: `initialize` flog
6.5 → 2.8, ABC 6.56 → 2.83; `add_to` flog 20.2 → 18.4, ABC 13.15 → 12.25; new `join_adjacent_literals` flog 10.8,
ABC 9.7, cyclomatic 4, perceived 5 (the two-way branch is the change itself). Cold read L1 on the first read; its
two pauses (`@children` gone, lone literals not re-interned) are answered above. No new Sol round: the code is
Thomas's shape.

Unrelated, noted only: the commented-out `class String` visitor further down `visitors.rb` is dead code; a possible
separate cleanup.

## AP-2: no Set union on every render

**Site.** Since #57830, `ActionController::Renderers::All#_all_renderers` returns `_renderers + Renderers.all`,
and `render_to_body` iterates it on every render to find a renderer option (`json:`, `xml:`, …), template renders
included. In a controller that never calls `use_renderers`, `_renderers` is the empty default Set, so each render
copies the built-in renderers into a new Set. Census 8 (Rails main): `renderers.rb:67` is interpreter line rank 652
(0.018%, 19 apps), YJIT rank 222 (0.040%, 16 apps). `render_to_body` runs 2,000 times per railsbench iteration, 115
in lobsters, 57 in shipit.

**Change.**

```ruby
def _all_renderers # :nodoc:
  if _renderers.empty?
    Renderers.all
  else
    _renderers + Renderers.all
  end
end
```

**Out loud.** If the controller has no renderers of its own, use the built-in renderers as they are; otherwise put
its renderers in front of them.

**Shape and metrics.** One branch per case, no new names. `_all_renderers`: flog 3.4 → 7.1, ABC 3 → 6.32,
cyclomatic 1 → 2, perceived 1 → 3; the rise is the `if`, which is the change itself.

**Per call:**

| Call | Mode | main | A/A | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| `_render_to_body_with_renderer(template: "x")` (the check on every template render) | interp 4.0.9 | 11,497 | +0.18% | 7,568 | −34.2% |
| | YJIT 4.0.9 | 9,237 | −0.30% | 5,314 | −42.5% |
| | interp master | 12,155 | −0.32% | 7,930 | −34.8% |
| | ZJIT master | 9,443 | −0.23% | 5,396 | −42.9% |
| `render_to_body(json: { id: 1, title: "x" })` | interp 4.0.9 | 26,379 | −0.12% | 22,369 | −15.2% |
| | YJIT 4.0.9 | 16,905 | −0.36% | 12,914 | −23.6% |
| | interp master | 28,382 | −0.12% | 24,178 | −14.8% |
| | ZJIT master | 19,746 | −0.30% | 15,534 | −21.3% |
| Whole JSON request through the app ([`app_req.rb`](../../bench/upstream/actionpack_request_path/app_req.rb) `json`, n=2) | interp 4.0.9 | 980,948 | −0.03% | 976,936 | −0.41% |
| | YJIT 4.0.9 | 568,761 | +0.07% | 563,694 | −0.89% |
| | interp master | 1,006,549 | −0.01% | 1,002,930 | −0.36% |
| | ZJIT master | 581,762 | +0.19% | 577,174 | −0.79% |

Objects: 3 → 2 for the check, 9 → 8 for `render json:` (the Set; Set is a core class on Ruby 4, one object).
Wall time (15 rotated pinned rounds, median): the check 1,354 → 801 ns interpreted (−41%, A/A +1.8%) and
1,165 → 552 ns with YJIT (−53%, A/A −1.2%); `render json:` 3,928 → 3,274 ns (−17%, A/A −0.9%) and 2,658 → 2,001 ns
(−25%, A/A −0.8%). The smallest common input is any render in a controller without `use_renderers`; every one
saves about 3,900 instructions, which is 0.4% (interpreter) to 0.9% (YJIT) of a minimal JSON request.

**ruby-bench:** the touched methods are patched to main's bodies, since ruby-bench bundles Rails 8.1 (Ir per iteration):

| App | Mode | main1 | main2 (A/A) | candidate | Δ |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | interp | 6,968,630,732 | 6,965,458,276 (−0.05%) | 6,960,310,538 | −0.10% |
| railsbench | YJIT | 4,393,814,577 | 4,387,017,993 (−0.16%) | 4,376,026,569 | −0.33% |
| lobsters | interp | 4,266,814,903 | 4,267,290,633 (+0.01%) | 4,267,671,658 | +0.02% |
| lobsters | YJIT | 3,029,744,569 | 3,028,554,294 (−0.04%) | 3,028,521,272 | −0.02% |
| shipit | interp | 5,842,291,772 | 5,844,421,403 (+0.04%) | 5,842,752,273 | −0.01% |
| shipit | YJIT | 3,163,590,157 | 3,162,485,670 (−0.04%) | 3,160,601,066 | −0.08% |

railsbench (2,000 renders per iteration) moves by about the expected 2,000 × 3,900 instructions, just outside its
A/A interpreted and about twice it with YJIT; lobsters (115 renders) and shipit (57) are within noise.

**Exactness.**

* `diff_rend.rb` (Base and API controllers, `use_renderers`, custom renderers added and removed at runtime,
  several renderer keys at once, media types, precedence): identical in all modes except the intended difference,
  that the returned collection is now `Renderers.all` itself (frozen, `Ractor.shareable?`).
* When `_renderers` is empty, the union has the same elements in the same order as `Renderers.all`, and
  `Renderers.add`/`remove` replace that frozen Set rather than mutate it, so returning it can't observe a later
  change mid-iteration (a renderer that adds one while rendering, and a fiber suspended in `each`, behave the same).
* `_all_renderers` is nodoc, defined and called only in `renderers.rb`, and unreleased; a code search found no
  outside callers.

**Reviews.**

* Primary review: approve-with-nits, L0. All nits come from assigning non-Set values to the nodoc writer
  `_renderers=`: the deprecated `RENDERERS` proxy warns twice per render instead of once; `[]` now renders where
  main raised `TypeError`; `nil` names `empty?` instead of `+` in its `NoMethodError`; an empty Set subclass with
  its own `each` is bypassed. The reviewer's stricter alternative (an identity check against a frozen default)
  was judged not clearly better and would need a comment under the shape checklist; kept as is.
* Cold read: L1, understood on the first read. Its question (does a caller mutate the result?) is answered by the
  frozen Set: a caller that tried would raise rather than change the shared renderers.

## Rejected and leads

| Site | Reason |
| --- | --- |
| Cache `t._routes` in `OptimizedUrlHelper#call` | −1.9% on `post_path`; small |
| Early return for empty `default_url_options` in `optimizable_default_url_options?` | −1.2%; marginal |
| `@parameters.any?` pre-check in `Format#add_to` | −1.5%; marginal |
| `view_assigns` String keys | public API (rejected in R2) |
| `URL.path_for` copy | public API; maintainer question (backlog #9) |
| `env_name` | required work |
| `xor_byte_strings` / `csrf_token_hmac` | optimized upstream recently (#59197) |
| `flag_cookies_as_secure!` | small |
| `LookupContext#formats=` `uniq!` | Action View, outside this round |
| `UriEncoder#escape` | owned by C9 |

**Lead, not built:** `Mime::Type.parse` for a Firefox `Accept` header costs about 97k Ir (12 µs), 5.4% of a full
request in the micro app. Worth a round of its own; it touches parsing and needs the adversarial path.

**Side finding (Ruby master, not filed; Thomas decides).** On Ruby master `9aa0898240` (strscan 3.1.9.dev),
`StringScanner#skip` returns nil for a position that starts inside an invalid or misaligned character in a
non-UTF-8 encoding, where strscan 3.1.6 (Ruby 4.0.9) raises. Minimal repro:

```ruby
require "strscan"
[["/\xFF".dup.force_encoding("Shift_JIS"), "Shift_JIS"], ["/a".encode("UTF-16LE"), "UTF-16LE"]].each do |str, name|
  s = StringScanner.new(str); s.pos = 1
  p [name, (s.skip(/./) rescue $!.class)]
end
# master 9aa0898240 (strscan 3.1.9.dev): ["Shift_JIS", nil]            ["UTF-16LE", nil]
# 4.0.9 (strscan 3.1.6):                 ["Shift_JIS", ArgumentError]  ["UTF-16LE", Encoding::CompatibilityError]
```

The same input in UTF-8 (`"/\xFF"`, pos 1) raises `ArgumentError` on both. Journey's scanner
(`journey/scanner.rb`) advances past a static token with `pos += 1` and then relies on `skip(/./)` matching or
raising, so `until token = scan || @scanner.eos?; end` spins forever: `Journey::Parser.parse` hangs on master for
route paths such as `"/\xFF|bc"` in Shift_JIS or `"/a"` in UTF-16LE. Rails main and both candidates are equally
affected. Open questions before filing: whether nil is intended (strscan treats "no match" as nil), and whether
Rails should guard its loop instead.

## PR bodies

As posted (AP-1 after the rework); the reviewed history of both is in [contributions](contributions.md).

### AP-1

`Journey::Format` now joins each run of adjacent literals once, when the route is built, so generating `/posts/:id` appends `"/posts/"` instead of `"/"`, `"posts"` and `"/"`. It also keeps its parameters themselves instead of their indexes and checks them with `any?`: on main, returning from the `each` block allocated an object whenever an optional group like `(.:format)` was skipped. The unused `@children` is gone.

URLs generated from Rails-built routes are unchanged: the parser's literals are its ASCII `/` and `.` or slices of the route path, so the joined string has the same bytes and encoding. Hand-built `Format.new` arrays could notice the new internal `@parts` (mutating the input afterwards, mixed-encoding literals failing at construction, String subclasses normalised). Building a format costs about 19% more instructions (2 µs per route); formats retain less memory than before.

`post_path(post)` per call, Ruby 4.0.9:

| | main | this |
| --- | ---: | ---: |
| objects | 7 | 6 |
| interpreter | 4,336 ns, 34,472 instructions | 3,988 ns (−8.0%), 31,855 (−7.6%) |
| YJIT | 2,005 ns, 15,571 instructions | 1,880 ns (−6.2%), 14,840 (−4.7%) |

`posts_path` saves 6.1% / 5.9% of instructions; `root_path` (one literal) is unchanged. Measured with Lowrail, my research project ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/actionpack-request-path.md#ap-1-join-adjacent-literals-when-building-a-routes-format)).

### AP-2

When a controller has no local renderers, `_all_renderers` now returns `Renderers.all` itself instead of building `_renderers + Renderers.all`, an identical copy, on each render. Controllers with `use_renderers`, and their subclasses, still get the union with their renderers first.

#57830 worked toward Ractor safety by replacing the registry with a new frozen Set on every `add` and `remove`, so the result has the same renderers in the same order and stays a snapshot while it is iterated. One contract changes: on this path the internal method returns the shared frozen registry rather than a fresh Set, so an override calling `super.delete(:json)` would raise `FrozenError`. Rails only iterates the result, and the union is unreleased.

Per call in a controller without local renderers, Ruby 4.0.9:

| | main | this |
| --- | ---: | ---: |
| renderer check of a template render, interpreter / YJIT | 1,354 / 1,165 ns | 801 / 552 ns |
| `render json:`, interpreter / YJIT | 3,928 / 2,658 ns | 3,274 / 2,001 ns |
| objects, check / `render json:` | 3 / 9 | 2 / 8 |

Tests cover Base and API without local renderers, inherited local renderers, and renderers added or removed between renders. Measured with Lowrail, my research project ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/actionpack-request-path.md#ap-2-no-set-union-on-every-render)).
