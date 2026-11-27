# Retained memory: Rails 8.1.4.1 vs main, Ruby 4.0.10 vs master (2026-11-27)

Where a Rails worker's memory goes after boot and while serving requests, on six census apps, Rails 8.1.4.1
(`3f290b759c`) against main (`2e299253f9`), and Ruby 4.0.10 (`a704b7cd95`) against master (`0d399335b7`), each
Ruby interpreted and under ZJIT. Nothing was opened or posted. Raw data: [`raw.tar.gz`](raw.tar.gz); tables
generated from it: [`tables.md`](tables.md) (levels, A/A, differences) and [`attribution.md`](attribution.md)
(owners, from heap dumps).

## Findings, ranked by bytes per worker

Numbers are per process. "Per worker" means what each forked worker holds; boot memory is shared between preforked
workers until written, so items 2, 4 and 5 cost each worker only in single-process or non-preloaded deployments,
while 1 and 5b are private to every worker. GC heap is `ObjectSpace.count_objects_size[:TOTAL]` after full GCs
(A/A ≤ 0.1 MB for every app); RssAnon is anonymous resident memory, whose A/A is several MB and up to 30 MB at boot
on two apps, so RSS differences below that are not claims.

| # | What | Bytes per worker | Owner | Regression? |
|---|---|---|---|---|
| 1 | ZJIT code and metadata | +26.6 to +62.4 MB RssAnon over the interpreter after 1,000 requests (master); ZJIT's own `total_mem_bytes` 22.9–81.0 MB | Ruby/ZJIT | Mixed: master's metadata is 36–66% smaller than 4.0.10's, its code region 43–83% larger, plus a new 3.7–13.3 MB JIT frame region |
| 2 | Instruction sequences (compiled Ruby code) | 34.8–92.8 MB, 40–50% of the GC heap; Rails' own 16.7–21.3 MB | Ruby (format), Rails and gems (amount) | Long-standing; Ruby master shrinks them by 6.1–17.8 MB |
| 3 | Ruby master vs 4.0.10 | −5.1 to −24.3 MB GC heap, −9.9 to −53.4 MB RssAnon at boot (interpreter, Rails main) | Ruby | Improvement |
| 4 | Gems that load everything at boot | stripe 18.4 MB (Sure), rouge 12.0–12.7 (Writebook, Sure), anthropic 10.2 (Sure), mail with net-imap 5.9, avo 4.3, prism 2.75, view_component 1.5–2.2, bundler 2.15, sorbet-runtime 1.9 | gems, Rails (prism via Action View, mail via Action Mailer) | Long-standing |
| 5 | Rails main vs 8.1.4.1 | +2.0 to +3.6 MB GC heap after boot and after 1,000 requests, in every app, Ruby and mode | Rails | Regression, diffuse: mostly more code (Active Record ISEQs +1.0 MB) |
| 5b | Warm-up after boot (first 1,000 requests) | +1.9 to +13.2 MB GC heap (Sure 13.2), private to each worker: method cache tables (0.5–0.9 MB), attribute methods and compiled templates (ISEQs), call caches, threads started on first use (Concurrent Ruby, Solid Cable; 1 MB VM stack each, mostly untouched) | Rails, Ruby | Long-standing |
| 6 | Ruby VM tables and method caches | VM tables 4.6–15.8 MB, method cache tables 2.6–11.0 MB | Ruby | Long-standing; master's cc tables 0.45–2.3 MB smaller |
| 7 | Duplicate Strings | 0.27–1.22 MB beyond one copy per content | spread | Long-standing, small |
| 8 | Growth per request (requests 1,000 to 5,000) | live heap flat (under 10 bytes per request); objects allocated after request 1,000 and alive at 5,000: 0.08–0.27 MB in total; RssAnon drifts 0.1–2.5 KB per request in every configuration, inside its A/A | malloc | None found |

### 1. ZJIT memory

After 1,000 requests on Rails main (MB; [tables.md](tables.md) has 8.1 and every app):

| app | 4.0.10 total | master total | master code | master metadata (`zjit_alloc_bytes`) | master JIT frames | master side exits (inside code) |
|---|---:|---:|---:|---:|---:|---:|
| blog | 34.3 | 30.0 | 10.2 | 15.0 | 4.7 | 3.6 |
| writebook | 37.1 | 38.6 | 14.2 | 18.3 | 6.1 | 4.5 |
| pingcrm | 33.5 | 29.0 | 9.9 | 14.5 | 4.6 | 3.4 |
| redprints-cfp | 50.1 | 31.7 | 11.2 | 15.5 | 5.0 | 3.7 |
| react-starter-kit | 29.4 | 22.9 | 8.0 | 11.2 | 3.7 | 2.8 |
| sure | 125.3 | 81.0 | 31.3 | 36.4 | 13.3 | 9.6 |

* RssAnon under ZJIT exceeds the interpreter's by more than ZJIT's own counters (blog +35.9 MB against 30.0 MB):
  the GC heap is 0.8–1.0 MB larger and compilation leaves malloc arenas larger.
* 4.0.10 keeps 13–108 MB of metadata already at boot (redprints-cfp 42–69 MB, Sure 98–108 MB, varying between
  runs); master keeps 4–7 MB at boot on the small apps. Master's per-ISEQ code is larger (inlining, lightweight frames) and side exits are about a third of
  its code, as in the ZJIT team's own lobsters numbers. After request 1,000 ZJIT memory is flat.
* Owner: Ruby/ZJIT, reported only. The metadata work is on k0kubun's lobsters branch (Shopify/ruby#1039 rows 66–81:
  `zjit_alloc_bytes` by subsystem, exact profile sizes, freeing profiles with the ISEQ, no over-reserved vectors),
  so it is taken; these app numbers are added to the [lead queue](../../../docs/upstream/zjit-iseq-leads.md).

### 2–3. Code, and what Ruby master changes

Rails' ISEQs are 17 MB in the five small apps (eager loading loads all frameworks) and 21 MB in Sure; the gems' share
is 14.4–23.9 MB, 44 MB in Sure, whose own code adds 23 MB. Sure's GC heap after boot is 236 MB on master (261 MB on
4.0.10); 17 MB of it are Strings and Hashes allocated at bootsnap's YAML cache (`compile_cache/yaml.rb:173`), i.e.
YAML files the app loads at boot through bootsnap (likely its locale files; not traced further).
Ruby master against 4.0.10, Rails main, interpreter, after boot ([attribution.md](attribution.md)):
ISEQs −6.1 to −8.0 MB (Sure −17.8), Strings −0.9 to −1.1 (Sure −4.5), Arrays −0.9 to −1.1, method cache tables
−0.45 to −0.65 (Sure −2.3), Hashes −0.4 to −0.7 (Sure −5.5), Classes −0.4. Two increases are accounting, not memory: method entries +2.8 to +3.6 MB because master's
`rb_imemo_memsize` counts the method definition struct (4.0.10 counted a pointer), and +0.6 MB for the symbol table
now reported as a T_DATA object. The real reduction is therefore larger than the GC-heap delta shows, and RssAnon
agrees (−9.9 to −17.5 MB at boot, Sure −53 MB).

### 4. Gems that load everything at boot

All measured on master, Rails main, after boot:

* **rouge** (Writebook): 12.7 MB (Regexps 4.9, ISEQs 4.5, Strings 1.8). `require "rouge"` loads every lexer (239
  files). The current release behaves the same: a bare `require "rouge"` retains 14.6 MB of heap and 17.6 MB
  RssAnon with 5.1.0 on master and 16.0 / 18.1 MB on 4.0.10 (4.5.1: 14.7 / 17.7 MB; [`rouge-*.jsonl`](raw.tar.gz),
  two runs each, identical heap). Lazy lexer loading needs a registry of every lexer's tags, aliases, filenames and
  mimetypes, a design change for rouge's maintainers rather than a small exact fix: recorded as a lead.
* **mail + net-imap** (every app): 4.8 + 1.1 MB, because Action Mailer's `eager_load!` calls
  `Mail.eager_autoload!`. 3.2 MB of it are the Ragel parser tables, kept as Arrays of Integers (8 bytes per
  entry). Lead for mail: packed tables.
* **prism** (every app): 2.75 MB, 2.1 MB of it ISEQs from `prism/node.rb`. Action View eager-loads
  `ActionView::RenderParser`, which requires prism, on 8.1 and main alike. Loading it lazily saves the memory in
  apps that never compute a template digest but costs each worker its own copy in apps that do (fragment caching,
  `fresh_when`); not a clear win, no candidate.
* **bundler** (every app): 2.15 MB of ISEQs that stay loaded after `Bundler.require`, including a vendored copy of
  FileUtils next to the stdlib one (0.26 MB each).

### 5. Rails main against 8.1.4.1

| app | GC heap after boot, master | after boot, 4.0.10 | after 1,000 requests, master |
|---|---:|---:|---:|
| blog | +2.5 | +3.0 | +2.2 |
| writebook | +2.1 | +2.5 | +2.1 |
| pingcrm | +2.0 | +2.3 | +2.1 |
| redprints-cfp | +3.3 | +3.5 | +3.4 |
| react-starter-kit | +2.8 | +3.2 | +2.7 |
| sure | +2.1 | +2.7 | +2.2 |

Attributed (master, MB, the same in every app): Active Record ISEQs +0.95 to +1.07, Active Model ISEQs +0.26,
Active Support ISEQs +0.20 and objects +0.33, Active Record objects +0.18 to +0.30, method caches +0.13 to +0.21,
marcel 2 +0.15, rack +0.11. Offsets: main no longer loads rake at production boot (−0.29; 8.1 loads it through
`rails/test_unit/railtie`). `useragent` now loads when `allow_browser` is declared instead of on the first request
(+0.24 at boot, the same after a request). psych and msgpack/bootsnap move between owners without changing the total.
No file adds more than 0.13 MB, so there is no exact fix to propose; it is the cost of new code (IndexedRow,
QueryIntent, association routes and the rest), recorded here.

### 8. Growth per request

On these request mixes nothing grows: after a full GC the live heap at request 5,000 equals the one at request 1,000
(three 4.0.10 apps show −217 to −261 bytes per request because a thread's 1 MB VM stack is released in between;
pingcrm's is the Active Record pool reaper's), and the objects allocated after request 1,000 that are alive at 5,000
total 0.08–0.27 MB, mostly the measurement's own bookkeeping and the last response. RssAnon rises by 0.1–2.5 KB per request (4–10 MB over 4,000 requests) in
every configuration, with A/A spreads of the same size and no consistent sign between Rails or Ruby versions:
malloc fragmentation, not a retained object. The census workloads repeat the same URLs, so caches keyed by URL or
parameters would not show here.

## Candidates

None. Rails' increase is spread over new code with no shared helper to improve (the 2026-11-27 helper rule finds
nothing to apply); the large items are long-standing gem costs that need design changes
(rouge, mail tables) or a trade-off maintainers have chosen (prism and mail eager loading for copy-on-write), and
Ruby/ZJIT memory is reported, not opened. Leads, with their numbers above: rouge lazy lexers, mail packed parser
tables, prism `node.rb` size, ZJIT JIT-frame and side-exit memory on real apps.

## Method

* Apps: blog, writebook, pingcrm, redprints-cfp and react-starter-kit (SQLite or PostgreSQL), and sure (PostgreSQL), as
  census copies (`script/census setup --corpus census-mem --ruby 4.0.10 --rails 2e299253f942…`) with the default
  overlays plus `fixtures/corpus/frontier-master`'s Ruby-master overlay, so all four Ruby configurations share one
  dependency set. The overlay's `ffi`, `herb`, `nokogiri` and (Sure) `google-protobuf` lines only force source builds;
  they got `require: false` so `Bundler.require` loads only what the apps list. CodeTriage was dropped: bluecloth
  2.2.0 does not build on master.
* Rubies: release builds of the v4.0.10 tag and master `0d399335b7`, both `--enable-yjit --enable-zjit`, so 4.0.10
  runs ZJIT too. ZJIT runs use the defaults (`--zjit-mem-size=128`).
* [`mem.rb`](mem.rb) boots in production through the census harness (eager loading on), takes a snapshot after full
  GCs at boot, after 1,000 and after 5,000 requests, and samples RSS every 250. Requests cycle through the app's
  census request workloads (jobs and mailers out, and the two that create rows a measured page lists:
  Writebook's `POST page`, Sure's `POST api transaction`), in process through Rack::Test, not Puma.
* [`run.rb`](run.rb) runs each configuration twice per Rails tree in ABBA order (the A/A pair), then once more with
  allocation tracing and `ObjectSpace.dump_all` per snapshot; [`dump.rb`](dump.rb) aggregates each dump by owner
  (`rails/COMPONENT`, `gem/NAME`, `app`, `ruby/stdlib`), site, type and duplicate Strings, and charges ISEQs to the file
  they were compiled from. VM tables (fstring and symbol sets, cc tables) go to `ruby/vm` and `ruby/method-cache`,
  since their allocation site is whatever line grew them. Detail runs' RSS is not used (tracing adds a 34 MB table).
  Sure's four configurations ran side by side on their own database clones (`--env POSTGRES_DB=…`), since its
  workloads reset an API key at start.
* [`run_all.sh`](run_all.sh) is the round; [`summarize.rb`](summarize.rb), [`attribute.rb`](attribute.rb),
  [`types.rb`](types.rb) and [`diff.rb`](diff.rb) read the outputs; [`require_cost.rb`](require_cost.rb) is the bare
  `require` probe.
* Orb: 8 vCPUs, up to 4 measured processes at a time.
