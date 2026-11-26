# Two candidates from the census hot-lines run (2026-11-26)

Suggested items 1 and 2 of [profile_hotlines_census](../profile_hotlines_census/README.md): queue items
[XNE1](../pr-queue/items/XNE1.md) (superseded) and [CRSI1](../pr-queue/items/CRSI1.md) (held, below the bar). Neither
was built; nothing was opened or posted.

## XNE1: `ERB::Util.xml_name_escape` for Symbol keys

The census captures ran Rails 8.1.x, where `tag_option` passed each Symbol attribute key to `xml_name_escape`, whose
`name = name.to_s` copied it. On Rails main (`521bd1cf3f`) that copy is already gone: amatsuda's
[rails/rails#59117](https://github.com/rails/rails/pull/59117) (`49580d1d04`, merged 2026-10-15, unreleased) reads the
key with `Symbol#name` in `append_tag_option` before the escape, and `append_prefix_tag_option` builds a String key.
That is the only Rails caller, so on main `xml_name_escape` gets only Strings, and `to_s` returns them unchanged.

[xne_probe.rb](xne_probe.rb) (`ruby xne_probe.rb RAILS_TREE`), Ruby 4.0.9, objects per call after 3 warm calls,
[output](xne_probe-4.0.9.txt):

| | v8.1.4 | main `521bd1cf3f` |
| --- | ---: | ---: |
| `tag.div("x", class: "card")` | 8 | 4 |
| `tag.input(type: "text", name: "q", value: "v")` | 11 | 4 |
| `content_tag(:a, "x", href: "/a", class: "b", id: "c")` | 11 | 4 |
| Strings allocated at `util.rb:143`, 10 `tag.div` with 3 Symbol keys | 30 | 0 |

Changing `xml_name_escape` itself to `Symbol#name` would therefore save nothing on main. It would only change
what direct Symbol callers get back, a frozen shared String instead of a new one. None were found: none in the 17
census app repositories (gh code search) or the Blog, and no outside caller of `ERB::Util.xml_name_escape` in
GitHub code search. The other hits are vendored Rails copies or reimplementations of their own (roundhouse, ree,
eskimo, zigapagos). No request-level run, because main has no change left to measure. The census reach (16 apps,
0.22% of request objects, Sure 0.86%) goes away with Rails 8.2.

## CRSI1: concurrent-ruby `SafeInitialization#new`

`def new(*args, &block); super(*args, &block)` collects the arguments into an Array for every safe-initialized object
(locks, atomics, futures). `new(...)` forwards them without it.

**Where the objects come from.** Census reports, `SafeInitialization#new` calls per request (`warm`), all from the
same line in every app that has it:

| App | per request | objects per request | share |
| --- | ---: | ---: | ---: |
| blog | 5.5 | 6,530 | 0.08% |
| campfire | 5.99 | 19,902 | 0.03% |
| lobsters | 5.99 | 4,505 | 0.13% |
| mastodon | 6.0 | 8,176 | 0.07% |
| redprints-cfp | 5.82 | 2,540 | 0.23% |
| sure | 6.0 | 40,250 | 0.01% |

17 of 18 apps (all but Chatwoot), 4.97 (Writebook) to 7.51 (Fizzy) per request. On the Blog in production (Rails
8.1.4), [si_count.rb](si_count.rb) and [si_callers.rb](si_callers.rb) show all six come from Active Record's
`AsynchronousQueriesTracker::Session#initialize`: an `AtomicBoolean` and a `ReadWriteLock`, which creates an
`AtomicFixnum`, an `AtomicReference` and two `Synchronization::Lock`s. Rails 8.1 builds that session at the start of
every executor run. On main, Sampo Kuokkanen's [rails/rails#59373](https://github.com/rails/rails/pull/59373)
(`91f0f89aeb`, merged 2026-10-31, unreleased) builds it only when an async query needs it
(`AsynchronousQueriesTracker#current_session`, called only from `async_schedule!`). So apps that don't use
`load_async` stop creating these objects with 8.2.

**Micro.** [si_micro.rb](si_micro.rb) and [si_ir.sh](si_ir.sh): concurrent-ruby master `aa56313` against the same
tree with `new(...)`/`super`, Ruby 4.0.9 without JIT. Instructions are total Ir of 20,000 calls minus a 0-call run,
per call, each tree run twice ([Ir](si_ir-4.0.9.txt), [objects](si_objects-4.0.9.txt)):

| per call | master | master again | `(...)` | `(...)` again | objects |
| --- | ---: | ---: | ---: | ---: | --- |
| `Klass.new(1, 2)` | 4,575 | 4,567 | 3,827 | 3,830 | 2 → 1 |
| `AtomicBoolean.new(false)` | 5,149 | 5,148 | 4,580 | 4,577 | 3 → 2 |
| `Promises.resolvable_future` | | | | | 17 → 11 |

**Request.** Blog `GET /articles` (a scaffold index with a form, links and buttons per article), Rails 8.1.4,
concurrent-ruby 1.3.8, Ruby 4.0.7 interpreter, production. `lowrail bench` refuses a build with no units (`no units
for selection`), and today's default build lowers nothing. So these runs call its request driver directly, with the
settings `lowrail bench` passes it: `BENCH_COUNTER=callgrind BENCH_HEAP_MODE=fixed bench/request_pairs.rb APP OUT
GET:/articles`, with `BENCH_VARIANT_APP` as the `app_fix` layer, `BENCH_JOBS=2`, and otherwise the defaults (6 rounds,
50 warm-up requests, N=0/N=50 windows, fixed heap). Valgrind is the pinned 3.19.0 with the 512 MiB brk
([valgrind.json](blog-articles/valgrind.json)). Each app is a `script/corpus real-blog-r4` copy whose Gemfile
adds `gem "concurrent-ruby", path: …` pointing at a v1.3.8 worktree. The `app_fix` copy's worktree has only the
`new(...)`/`super` change ([concurrent-ruby-1.3.8-fwd.diff](blog-articles/concurrent-ruby-1.3.8-fwd.diff)), so the
locks differ only in that path. Instructions and objects are per request; A/A is off_b against off_a, and the delta
is against off_a.

| Run | Baseline, `app_fix` | A/A total | `app_fix` total Ir | Δ total | Δ without GC | objects |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | `si-blog` (`cr138`), `si-blog-fwd` (`cr138-fwd`) | −0.018% [−0.055, +0.037] | 9,077,260 → 9,081,016 | +0.039% [+0.026, +0.047] | +0.032% | 2,358.05 → 2,352.15 |
| 2 | `si-blog-ref` (`cr138-ref`), `si-blog-fwd` | −0.008% [−0.041, +0.019] | 9,086,081 → 9,080,791 | **−0.059% [−0.072, −0.035]** | −0.047% [−0.075, −0.026] | 2,358.54 → 2,352.03 |
| 3 | `si-blog-ref`, `si-blog-aaa` (`cr138-aaa`, unchanged) | −0.002% [−0.025, +0.036] | 9,084,465 → 9,084,445 | −0.012% [−0.042, +0.018] | −0.019% [−0.057, +0.001] | 2,358.39 → 2,358.19 |

Every run passed the A/A gate (±0.5%, zero inside), the heap-capacity match and the interpreter check, and had no
GC in any window. Run 2's A/A also meets the stricter ±0.1% rule for both metrics. Run 1's baseline paths are four
characters shorter than the `app_fix` copy's (app directory and gem path). Its baseline costs 8,821 Ir less than
run 2's, which had equal lengths, and that is enough to flip the sign. Runs 2 and 3 therefore use a baseline whose
paths match the variant's length. Run 3 is the control for that: an unchanged copy with paths of the same length measures −0.012% [−0.042, +0.018] against the baseline, with zero inside and the same objects. So run 2's −0.059% comes from the change, not from the copy.

So the change saves about 5,300 instructions (0.06%) and 6.5 objects (0.27%) per Blog request on Rails 8.1, and its interval
(3,200–6,500 Ir) contains what the micro predicts (570–750 Ir per object, six objects: 3,400–4,500). It is about a
thirty-fourth of the 2% bar. A request of
another app that runs the same six objects saves the same absolute amount, and a larger request a smaller share.
No YJIT run: the interpreter result is already 34 times under the bar.

**Not built.** The request effect is far under the ~2% bar. In addition, `(...)` needs Ruby 2.7 while the gemspec
allows 2.3, so a PR would also need a version branch or a raised floor. And keywords would change meaning:
`new(*args)` without `ruby2_keywords` hands keywords to `initialize` as a positional Hash. With an
`initialize(a: 0)`, master raises `ArgumentError` for `new(a: 1)` and `(...)` returns 1. With
`initialize(h = {}, **kw)`, master gives `h = {x: 1}` and `(...)` gives `kw = {x: 1}` (checked on 4.0.9).

**Ownership.** No open or closed PR or issue names `SafeInitialization` or `safe_initialization.rb` as a cost.
Search hits #829, #416 and #462 touch it for other reasons, and no open PR changes `concurrent/synchronization`. The
file has one commit (`d824048`, eregon, 2023). On the ZJIT side, `SafeInitialization#new`'s `super(*args, &block)` is
already a recorded fallback ([zjit-gap-census](../../../docs/upstream/zjit-gap-census.md), super complex args).
