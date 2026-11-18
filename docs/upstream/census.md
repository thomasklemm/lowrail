# Rails allocation census: `script/census`

One command runs the census of censuses 4 and 5: real apps on Rails main (SQLite, PostgreSQL, MySQL), 97
request, job and mailer workloads, interpreter and JIT modes, an A/A baseline, allocation sites attributed by file
and line, a breadth-first ranking, comparisons of patched Rails branches against the base with behavior controls,
and the open rails/rails PRs that touch the ranked lines. Rails ref, Ruby and mode are parameters. The same steps
therefore serve a Rails-main round, a Ruby 4.0.9 vs ruby-master comparison (`--ruby`) and a JIT vs interpreter
comparison (`--modes`, `LABEL:MODE`).

Results are allocation counts only. No timing is inferred from them. Speed claims need `lowrail bench`
([bench.md](../bench.md)).

`script/census watch` reruns the census daily at current rails/rails `main` against the last recorded `main`. It
attributes new allocations and SQL or behavior-control diffs to commits: [rails-main-watch](rails-main-watch/README.md).

## Run it on your own app

`script/census app DIR` runs the census on any Rails app checkout and writes one report: objects and instructions
per workload, each with its A/A pair, and the Rails, Ruby and gem lines that allocate and run the most, each with
the open rails/rails PRs and [ledger](contributions.md) entries that touch it. Registering the app (below) is only
needed to add it to the rounds we run ourselves. When to use it and when [`lowrail-profile`](../profile.md) instead:
[Your own app](../../README.md#your-own-app).

```sh
mise exec -- script/census app ~/src/myapp --init        # writes ~/src/myapp/lowrail/workloads.rb from the routes
mise exec -- script/census app ~/src/myapp               # measures lowrail/workloads.rb (else GET pages from the routes)
mise exec -- script/census app ~/src/myapp --rails main  # and what Rails main changes
mise exec -- script/census app ~/src/myapp --workloads other.rb --modes interp,yjit
```

**What it does.** DIR is only read. The app's tracked and untracked-but-not-ignored files (so uncommitted edits
count) and its `config/database.yml` are copied to `.corpus/census-app-NAME`; results go to
`.lowrail/private/census-app/NAME`, with the report in `report.md`. NAME is DIR's basename (`--name` picks another;
a checkout of a registered app becomes `NAME-own`). Setup, once per copy: bundle the app's own `Gemfile.lock`
(the `ruby` pin dropped, so the Ruby is a parameter), boot once in production to read its database configuration,
check its services, `db:create db:schema:load` (or `db:migrate` without a schema), `--build` commands,
`assets:precompile`, seed (`--prepare FILE`, else `db/seeds.rb`, with `srand(42)` and a fixed Faker seed), then
replay every workload three times. Later runs reuse the copy and any result already measured; `--fresh` starts over.
The workloads file is copied into the copy on every run, so an edit counts, and results measured with an earlier
version of it are measured again. `--init` is the one write to DIR: it writes `lowrail/workloads.rb` when there is
none (else next to the report), from the pages discovery finds.

It measures on the app's own Rails and Ruby (`.ruby-version`, else the lock's `RUBY VERSION`; `--ruby` overrides),
in the interpreter (`--modes interp,yjit` adds YJIT), with the same harness, windows and controls as a round
([What a run measures](#what-a-run-measures)). Each label runs as an A/A pair: `own`/`own2`, and `main`/`main2`
with `--rails SPEC`, which swaps the Rails line exactly as `run --rails` does. Instructions come from
`script/cpu-census` when the patched Valgrind is built: `script/cpu-census build`, once, a long build. Until then
the census measures objects only and says so at the start of each run; `--cpu` requires instructions (and refuses
without the build), `--no-cpu` skips them silently.
A released Rails is attributed as `RAILS/COMPONENT/…`, the same keys as a rails/rails checkout.

**Refusals.** Each stops before anything is written to a database, with what to do next:

* any `*DATABASE_URL` in the environment;
* an app that does not boot in production (the last lines of its error, and `--env K=V` for throwaway secrets);
* a database adapter other than SQLite, PostgreSQL or MySQL, a database host that is not local, or a SQLite file
  outside the copy;
* a database server, Redis or memcached (when `redis`, `redis-client`, `sidekiq` or `dalli` is bundled) that is
  not reachable (`--assume-service redis` when the measured requests never use it);
* a server database that already exists, which may hold someone's data;
* a lock that does not install on the chosen Ruby, a failing asset build, seed or workload (`CENSUS_DEBUG=1`
  prints the exception behind a bare 500).

### Workloads file

`lowrail/workloads.rb` in the app (`--workloads FILE` for another), the same file
[`lowrail-profile --workloads`](../profile.md) replays. It is Ruby in `ActionDispatch::IntegrationTest`'s words, so
lines can be copied from the app's own tests, and it is evaluated only after the app has booted, so it loads
nothing earlier than the app would. Plain Ruby at the top looks records up; route helpers work. The Blog's file
([fixtures/census-app/blog.rb](../../fixtures/census-app/blog.rb)):

```ruby
article = Article.order(:id).first!
target = Article.order(:id).last!

setup do
  # Writes must not accumulate from run to run, or the A/A pair drifts.
  Comment.where(commenter: "Census").delete_all
  Article.where(title: ["Census title A", "Census title B"]).where.not(id: article.id).delete_all
end

csrf_from new_article_path

get articles_path, name: "GET articles"
get article_path(article), name: "GET article"
get edit_article_path(article), name: "GET article edit"
get articles_path(format: :json), as: :json, name: "GET articles.json"
get article_path(article, format: :json), as: :json, name: "GET article.json"

# Flip between two titles, so the record ends each run as it started.
titles = ["Census title A", "Census title B"].map { { params: { article: { title: _1, body: article.body } } } }
patch article_path(article), name: "PATCH article (redirect)", expect: 303, jobs: true, alternate: titles
post articles_path, name: "POST article invalid (422)", params: { article: { title: "", body: "short" } }, expect: 422
post article_comments_path(target), name: "POST comment (redirect)",
  params: { comment: { commenter: "Census", body: "A census comment" } }, expect: 302
patch article_path(article, format: :json), as: :json, name: "PATCH article.json", alternate: titles
```

| Call | What it does |
| --- | --- |
| `get`, `post`, `patch`, `put`, `delete PATH` | One request workload. As in an integration test: `params:`, `headers:` (`"Accept"` or `HTTP_ACCEPT`), `env:`, `xhr: true` (X-Requested-With and IntegrationTest's Accept), `as: :json` (JSON Accept and Content-Type, params sent as a JSON body; a GET with params becomes a POST with a method override). |
| `name:` | The workload's name (default `"GET /path"`). Names are the keys of every comparison, so keep them stable. |
| `expect:` | Allowed statuses (default 200 for GET, any of 200, 201, 202, 204, 302, 303 for writes). Anything else stops the run. |
| `alternate: [{ params: }, { path: }]` | Overrides used in turn, so a write flips between two states. Each request keeps its own turn. |
| a block, `do \|n\| { params: … } end` | The overrides for the n-th run (from 1), for writes that must differ each time. |
| `jobs: true` | The jobs this request enqueues become workloads of their own (`perform JobClass`); `skip_jobs "CachePageJob"` leaves some out. |
| `signed_in: false` | Send this request from a second, signed-out client. |
| `csrf: false` | Do not send the CSRF token (and do not fetch a page for it). Otherwise writes send the token of `csrf_from PATH` (default: the first HTML GET), as a param, or as X-CSRF-Token for `xhr:` and `as: :json`. |
| `setup { … }` | Runs once, where it stands in the file: resets and records the requests need. |
| `let(:name) { … }` | A value computed on first use and then kept, for records the requests create before a mail or job uses them. |
| `sign_in PATH, params:` | Signs the measuring client in once: GET `form:` (default PATH) for the token, then the request (`method:`, `expect:`, default 302/303); or `sign_in cookie: { name:, value:, signed: true }`. |
| `mail { Mailer.action(args) }` | A mail delivered with `deliver_now` (name `deliver Mailer#action`, or `mail("name") { … }`). |
| `job { SomeJob.new(args) }` | A job performed as a queue would run it (name `perform SomeJob`). |

Lobsters' file adds a signed-in member, XHR writes, a block, a job filter and a mail
([fixtures/census-app/lobsters.rb](../../fixtures/census-app/lobsters.rb)):

```ruby
sign_in "/login", params: { email: user.email, password: "census-password" }, expect: 302
post "/comments", xhr: true, name: "POST comment (XHR)", expect: 200, jobs: true do |n|
  { params: { story_id: target.short_id, comment: "Census comment #{n}" } }
end
skip_jobs "CachePageJob"
let(:reply) { Comment.where(story_id: target.id).order(:id).last! }
let(:recipient) { User.find(target.user_id) }
mail { EmailReplyMailer.reply(reply, recipient) }
```

The file is evaluated into a frozen manifest: per request its method, path, a digest of its params and body, the
header names and a digest of their values, expected statuses and options, the sign-in's settings (digests for its
params and a cookie's value), and the file's sha256. The census writes it to `workloads.json` next to the report and
into every receipt (`workloads_manifest`), `lowrail-profile` into its output directory, so two runs can be checked
for the same workloads without reading the Ruby again. Each request keeps frozen copies of the values the file
passed, so changing those objects later changes neither the requests nor the manifest. A block's overrides are not
in the manifest, only its source line: the line does not certify what the block returns on a given run (it may read
the database or the clock). `lowrail-profile --workloads` lists the variants it measured in its receipt; the
census's per-workload SQL control is what shows that two runs sent the same requests.

Both tools send the file's requests through one implementation, `Lowrail::Workloads::Replayer`: sign-in, the CSRF
token and where it goes, alternates and blocks, and which client (signed in or not) sends each. Their clients
differ only in transport (census 4's Rack::Test session, lowrail-profile's `Rack::MockRequest`) and send the same
browser headers (`Host`, `Origin`, `Accept`, `User-Agent`, `Sec-Fetch-Site`); a test
(`gem/test/workloads_test.rb`) runs both against one app and checks that the app sees the same requests. What
differs is the measurement: the census captures jobs and delivers mail to the test deliverer, lowrail-profile uses
the app's own adapters ([profile.md](../profile.md#run-it)).

Without a file, up to 20 GET routes are discovered: routes without parameters, and `:id` or `:NAME_id` filled with
the first record of the matching model; each must answer 200 three times. The chosen pages are cached in the copy
(`tmp/census-discovered.json`), so every run measures the same ones, and skipped routes are printed with the reason.
`--init` writes the same pages as a starter file, with route helpers. `lowrail-profile --record` writes the most
frequent request shapes of a test suite instead, writes commented out until they are made repeatable.

Each request keeps its own turn, so two requests that flip the same record (the Blog's PATCH and PATCH.json) can
each start by writing the value the other left, which the SQL control shows as a skipped UPDATE.

### The report

One page per app, plain counts, no speedup claims. Per workload: objects and instructions per operation and their
A/A difference, and SQL queries. Then where the objects come from (Rails, gems, Ruby's library, the app), and two
rankings of Rails, Ruby and gem lines, by mean objects and by mean sampled instructions over every workload, each
with the line's source, its A/A, how many workloads it reaches, its main class or method, and known work: open
rails/rails PRs whose diff covers the line (cached by `prs`, so `gh` is needed once; on a released Rails the line
numbers are main's, so a match is a hint) and ledger entries naming the line's file, or its method with its gem or
component. With `--rails`, a table of what the other Rails changes per workload, counted only beyond both A/A pairs,
and whether the SQL changed.

### Validation: Blog and Lobsters as outside apps (2026-11-17)

Both apps from plain checkouts outside `.corpus` (the Blog from its retained archive, Lobsters cloned at
`366e211`), with the files in [fixtures/census-app](../../fixtures/census-app), against the registered census of
the same apps and workloads (`run --aa` and `cpu-census run --aa`), Ruby 4.0.9, interpreter. To compare like with
like, `--rails` named the registered copies' commit: Rails main `4500a94c34` for the Blog, and for Lobsters
`c48c154e3f`, the parent of the merge that breaks activerecord-typedstore 1.6.0 (Lobsters does not boot on current
main; [ar-gems-after-59141](ar-gems-after-59141.md)). Outside, Bundler resolved Rails main from the app's own lock;
the registered overlays differ from those locks only in herb (0.11.1 against 0.11.2).

* **Workloads.** The same names (10 and 11) passed `list` on both sides. Every Lobsters workload and 8 of 10 Blog
  workloads ran the same masked SQL; the Blog's two PATCH workloads differ only in the SQL control (see
  [Workloads file](#workloads-file)).
* **Objects.** Traced objects per operation without the census client's own lines: Lobsters within −30 to +16 of
  7,000 to 24,000 (mail and job identical), the Blog within ±8 except its comment POST (−120, inside the 10–180
  that comment writes move between identical runs). The census values (medians of the GC-enabled windows) are 3 to
  13 objects lower outside for the Blog, which is the request client: the registered workloads build a headers
  Hash per call, the file builds them once. The Blog's job differs by +130 in the median because one of its three
  windows caught one-time allocations; its traced count is identical (607.1).
* **Rankings.** The top 15 lines by objects: 13 of 15 shared for the Blog with the top 10 in the same order, 15 of
  15 for Lobsters. By instructions, the Blog's top 15 are the same 15 lines, the first 8 in the same order.
* **Instructions.** The Blog per workload within ±0.30% of the registered run, against A/A differences up to 0.24%.
  Lobsters 0.06% to 0.45% lower outside (A/A up to 0.39%), comment preview 0.82% lower; its top 15 lines by
  instructions are the same 15, the first 10 in the same order.
* **The rounds themselves.** `rank` and `compare --detail` print byte-identical output from this tree and from the
  previous commit on both apps' receipts. A Blog A/A pair run by the previous commit's harness and one run by this
  tree's have the same receipt keys, workload names and SQL digests, and median +0.0 between them.

The default without a file found the Blog's five pages (`/`, `/articles`, `/articles/new`, edit and show) and
skipped Turbo's three `*_historical_location` routes as a gem's controller. Refusals were checked with a
`DATABASE_URL` set, a missing directory, a non-Rails directory, an initializer that needs a secret, PostgreSQL in
production without `pg` in the bundle, and (on constructed configurations) PostgreSQL, Redis and MySQL not
running.

### Validation: the workloads file replaces YAML (2026-11-18)

The Blog and Lobsters files were rewritten from YAML with ERB to the Ruby DSL (`blog.rb`, `lobsters.rb`) and run
against the YAML at the previous commit (`11804786`) from the same checkouts, Ruby 4.0.9, interpreter, objects
only: the Blog on its own Rails 8.1.4, Lobsters on its own Rails 8.1.3.1 and on Rails main `c48c154e3f`.

* **Names and SQL.** The same workload names (10 and 11), and every workload ran the same masked SQL in every pair,
  in both of Lobsters' Rails.
* **Blog.** Each workload's median within the spread of the YAML run's own three windows; the largest difference,
  the comment POST (+31), against windows of 2,267 to 2,433 in one YAML run.
* **Lobsters, reads, mail and job.** Within the A/A of the same copy (GET home −0.8, GET active +53 against
  windows that move by 20 to 70 between A/A runs of one copy; the mail and job identical).
* **Lobsters, XHR writes.** 30 to 47 objects more on both Rails, from one deliberate change: `xhr: true` sends
  IntegrationTest's `Accept` (`text/javascript, text/html, application/xml, text/xml, */*`), which Rails parses into
  more MIME types (`mime_type.rb:210–219`, +5 objects each); the YAML sent `text/html`. The same file with
  `headers: { accept: "text/html" }` on the three requests is back within the A/A (−3.0, −0.2, +8.2).
  This is the realistic default (it is what Rails' own `xhr: true` sends), so it stays. **Comparing receipts across
  this change**, Lobsters' three XHR writes (`POST story vote toggle`, `POST comment preview`, `POST comment (XHR)`)
  step up once by 30 to 47 objects from the header alone; that step is not a Rails or app change. Receipts written by
  `11804786` and earlier sent `text/html`.
* **YJIT.** `--modes interp,yjit` on the Blog: all ten workloads, A/A within ±4 objects.
* **`--init`** on the Blog wrote its five pages as route helpers and listed Turbo's three routes as left out; the
  file `lowrail-profile --record` wrote from the Blog's suite ran as four GET workloads, A/A within 1.3 objects.

### Registering an app

For the rounds we run ourselves, an app is registered in this repository instead.

**Requirements.** Git, network access, [mise](https://mise.jdx.dev) (the script runs under `mise exec --` or any Ruby on `PATH`;
it measures on Ruby 4.0.9 by default, installed on demand, and `--ruby` picks another), the app's own build tools
(bun, npm, yarn, pnpm), and its services as local disposable instances (see [Services and apps](#services-and-apps)).
`gh` is needed only for `prs`. Unset every `*DATABASE_URL` variable first; `script/census` refuses to run with one.
A `--corpus` name must start with `census`, because the harness only boots copies under `.corpus/census*-APP`.

**Try it on the Blog** (SQLite, no services; setup takes a few minutes, a run under a minute):

```sh
mise exec -- script/census setup --rails main --apps blog
mise exec -- script/census run --label base --aa --apps blog --modes interp,yjit
mise exec -- script/census rank --label base2
mise exec -- script/census compare --base base2 --aa base
```

`setup` fetches the app into `.corpus/census-blog`, applies its overlay, moves Rails to the resolved commit,
creates and seeds the database, builds assets and finishes with `list`, which runs every workload three times:

```text
html     GET articles                             ok (25 ms for 3)
...
job      perform Turbo::Streams::ActionBroadcastJob ok (5 ms for 3)
```

`run --aa` measures the same tree twice, as labels `base` and `base2`, writing `LABEL/APP-MODE.json` under
`.lowrail/private/census` (see [Outputs](#outputs)). For each workload, `gc_enabled_objects_per_op` holds the three
measured windows (the median is the census value) and `sites` lists the objects allocated per operation by file and
line (`RAILS/…`, `APP/…`, `GEM/…`, `RUBY/…`).

`rank` lists Rails lines, one per row: rank, file and line, the number of apps that reach the line, the share of
workloads it reaches, the mean objects per operation over every workload, the kinds of workload it runs in and its
main classes ([How ranking works](#how-ranking-works)). The full ranking goes to `rank-LABEL-MODE.tsv`. With one app
every line is in the same tier, so the order is by mean objects.

`compare` prints the A/A pair first. This output is from Rails main `1105756f42` on 2026-11-03:

```text
-- A/A control (base2 - base): the noise floor for every comparison below
== base2 vs base
blog-interpreter               moved  4/10 median   +0.0 min  -190.0 |
blog-yjit                      moved  1/10 median   +0.0 min    -3.2 |
ALL interpreter workloads  10  median  +0.0  moved<=-1:   4  moved>=+1:   1
ALL yjit        workloads  10  median  +0.0  moved<=-1:   1  moved>=+1:   2
SQL interpreter workloads  10  changed SQL:   0
SQL yjit        workloads  10  changed SQL:   0
```

`moved` counts workloads whose median objects per operation fell by at least one, `median` and `min` are the
per-workload deltas, and `SQL` counts workloads whose masked SQL digest changed. Two runs of the same tree are not
identical: here one Blog write workload moved by −190 objects. A change is judged against these A/A counts, never by
a single workload ([the A/A rule](#comparing-branches-and-the-aa-rule)). To measure a Rails branch, run it under a
new label and compare it against `base2`:

```sh
mise exec -- script/census run --label mine --apps blog --rails OWNER/rails@BRANCH
mise exec -- script/census compare --base base2 --aa base mine
```

**Adding an app.** Five pieces, each following an existing app. [Thinkroom](https://github.com/kieranklaassen/thinkroom)
(SQLite, one overlay, a short seed script) is the smallest example.

1. **Source:** a `case` entry in [`script/corpus`](../../script/corpus) with the repository and a pinned commit.
2. **Overlay:** a patch applied to that commit, for example in
   [fixtures/corpus/inertia-chatwoot-census](../../fixtures/corpus/inertia-chatwoot-census). It moves the Gemfile
   and lock to Rails main and `.ruby-version` to 4.0.9, plus any compatibility edit Rails main needs. The Gemfile
   must keep a `gem "rails", …` line (or its components): that line is what `setup` and `run` swap to another commit.
3. **Configuration:** an entry in `APPS` in [`script/census`](../../script/census): `source`, `overlay`,
   `services`, throwaway `env`, and optional `build`, `pre_db`, `db` and `assets: false`.
4. **Data:** a `prepare` case in [harness.rb](../../bench/upstream/census/harness.rb) that seeds the database
   deterministically (fixed `srand` and Faker seeds), with the app's own seeds or a seed script.
5. **Workloads:** a method named after the app (`-` becomes `_`) in `Census4Workloads`, for example in
   [inertia_chatwoot_workloads.rb](../../bench/upstream/census/inertia_chatwoot_workloads.rb). It returns the
   operations to measure: requests through the census client, and the jobs and mails they enqueue. Each operation
   must raise unless it succeeded. Writes must not accumulate state from run to run (the Blog deletes its census
   comments first and flips an article title between two values), or the A/A pair drifts.

Then `script/census setup --rails main --apps APP` builds the copy and runs `list`. `CENSUS_DEBUG=1` with
`script/census list --apps APP` prints the exceptions behind a bare 500.

## Run a round

```sh
# 1. App copies at a Rails ref (.corpus/census-APP), bundled, seeded, assets built, every workload smoke-tested.
script/census setup --rails main                     # or a commit, a tag, OWNER/REPO@BRANCH
# 2. The A/A pair: two full unpatched runs, base and base2.
script/census run --label base --aa --modes interp,yjit
# 3. Rank Rails lines by breadth on base2.
script/census rank --label base2 --mode interp       # and --mode yjit
# 4. Open rails/rails PRs on the ranked lines, so a candidate does not duplicate one.
script/census prs --label base2 --top 40
# 5. Each candidate is one commit on its own fork branch, based on the same commit.
script/census run --label extending --rails thomasklemm/rails@thomasklemm/merge-skip-empty-extending
script/census compare --base base2 --aa base extending              # add --markdown for the per-app table
script/census controls --script bench/upstream/census_5_controls.rb base2 extending
```

Common options: `--apps blog,campfire` (default: all 23 configurations), `--ruby 4.0.9` (the default; a mise version, installed
on demand, or a path to a `ruby` binary or its `bin` directory), `--corpus NAME` (copies in `.corpus/NAME-APP`, so
several bases can coexist), `--out DIR` (default `.lowrail/private/census`), `--jobs N` (apps measured in parallel
within one mode; counts are per process and unaffected). `script/census list` replays every workload three times
against the base, a smoke test after changing workloads. `script/census help` prints every option.

**Rails refs.** `SPEC` is `REF`, `OWNER/REPO@REF` or `/path/to/rails@REF`, where REF is a branch, tag or commit.
A commit may be abbreviated (`c48c154e3f`): it is resolved with `git rev-parse` in a commits-only bare clone of
the repository's branches (`.corpus/refs-OWNER-REPO.git`), and refused when it names more than one commit.
`setup` records the resolved commit as the base. `run --rails SPEC` measures another commit. A label's
commit and Ruby are fixed by its first run (`meta.json`), and a later run under that label must match them.

**How the Rails ref is swapped.** Each app keeps its own `Gemfile`. A variant `Gemfile.census-SHA12`, with its own
lock, differs in exactly one line: `gem "rails", github: "OWNER/REPO", ref: "SHA"` (`git: "PATH"` for a local
repository). The `ruby` pin is dropped, so the Ruby is a parameter. Every bundle is installed before measuring. No
`bundle` command runs during a run, and no shared gem checkout is patched in place (censuses 3 and 5 did patch it).
As a dependency control, `run` compares the variant lock with the base lock outside the Rails `GIT` block and
`RUBY VERSION`. It records the result in `meta.json` and warns when they differ. A dev build (Ruby master) gets its
own variant, `Gemfile.census-SHA12-ruby-REV10`: Bundler resolves gems whose binaries exclude 4.1 (ffi, nokogiri,
sqlite3, pg, herb) to their source builds there, and that must not change the release pin's lock.

**Ruby comparisons.** Give each Ruby its own labels and its own A/A pair, for example
`run --label m409 --aa --ruby 4.0.9` and `run --label master --aa --ruby ~/rubies/master`. Then run
`compare --base m4092 --aa m409 master`. Labels never mix Ruby pins: census 8 moved from 4.0.7 to 4.0.9
([decision](../DECISIONS.md#ruby-pin-409-41-measured-on-pinned-master-2026-11-03)), and 4.0.7 receipts are not compared with 4.0.9 runs. `compare` prints each label's Rails commit and `RUBY_DESCRIPTION` first.
**JIT comparisons:** `compare --base base2:interpreter base2:yjit` pairs the same app across modes. `--modes zjit`
needs a Ruby built with ZJIT. The mise build of 4.0.9 here has none (built without rustc); use a ZJIT build such
as Ruby master.

**Ruby master pins.** A master round uses one pin: one master SHA per week at most, a release build with
`--enable-zjit --enable-yjit`, installed as `~/rubies/master-SHA10`. `meta.json` records it (`ruby` is the pin's
`RUBY_DESCRIPTION`, which names the SHA), and every pin gets its own A/A pair; labels from two pins are compared only
with both pairs. ZJIT stats runs use `CENSUS_WARMUP=200` and `--zjit-exec-mem-size=512 --zjit-mem-size=1024`, and a
run with any `compile_error_out_of_memory` is not reported ([F1](frontier-census-f1.md)).

**Gems on Ruby master.** Master needs gem changes the release overlays do not have. Set a master corpus up with
`setup --ruby ~/rubies/master --ruby-overlays fixtures/corpus/frontier-master` ([README](../../fixtures/corpus/frontier-master/README.md)):
`setup` applies `DIR/<overlay basename>` after the base overlay, runs `DIR/<app>.sh` if present (it vendors a
patched path gem), and records `ruby_overlay` in `.census.json`. The overlays change only Gemfile and Gemfile.lock
(Thinkroom also drops a `.bundle/config` that holds only `---`). With them, 21 of 23 configurations install on
master `9aa0898240`. [gems-on-master](gems-on-master.md) has, per gem, what fixed it and what still blocks
Chatwoot and Flow.

## Services and apps

| App | Source (script/corpus) | Overlay | Needs |
| --- | --- | --- | --- |
| blog | `real-blog-r4` (retained archive) | `blog.patch` | |
| campfire | `campfire` (`af4dd9f`) | `campfire.patch` | Redis |
| writebook | `writebook-r82` source (`7478e2c`), without its own overlay | `writebook.patch` | Redis |
| fizzy | `fizzy-r82` source (`77eada1`), without its own overlay | `fizzy.patch` | |
| fizzy-mysql | same source | `fizzy.patch` | MySQL 8.4 on 127.0.0.1:3307, root without password |
| codetriage | `codetriage` (`d1868f8`, plus `fixtures/corpus/codetriage.patch`) | `codetriage.patch` | PostgreSQL (local socket), memcached, Redis |
| pingcrm | `pingcrm` | `pingcrm.patch` | PostgreSQL, bun |
| redprints-cfp | `redprints-cfp` | `redprints-cfp.patch` | bun |
| react-starter-kit | `react-starter-kit` | `react-starter-kit.patch` | npm |
| lobsters | `lobsters` (`366e211`) | `lobsters.patch` | |
| docuseal | `docuseal` (`6c416dd`) | `pg-census/docuseal.patch` | PostgreSQL, Redis, yarn, libvips, pdfium |
| mastodon | `mastodon` (`5ccbf0e`) | `pg-census/mastodon.patch` | PostgreSQL, Redis, corepack yarn |
| lago | `lago` (lago-api `b0007bf`) | `pg-census/lago.patch` | PostgreSQL, Redis |
| discourse | `discourse` (`0f52471`) | `pg-census/discourse.patch` | PostgreSQL with pgvector, Redis, pnpm |
| loomio | `loomio` (`407d4a8`) | `pg-census/loomio.patch` | PostgreSQL, Redis, npm 11 (installed into the copy) |
| sure | `sure` (`8d0d84d`) | `pg-census/sure.patch` | PostgreSQL, Redis |
| casa | `casa` (`b584d2e`, without its census-era overlay) | `pg-census/casa.patch` | PostgreSQL, Node 24 (mise) |
| mastodon-nops, lago-nops | mastodon's and lago's copies | | as above; `prepared_statements: false` |
| chatwoot | `chatwoot` (`ae66c97`, plus commonmarker 0.23.12 built as a path gem) | `inertia-chatwoot-census/chatwoot.patch` | PostgreSQL with pgvector, Redis, Node 24 and pnpm 10 |
| hackatime | `hackatime` (`74deec4`) | `inertia-chatwoot-census/hackatime.patch` | PostgreSQL (two databases), bun |
| flow | `flow` (`6a8b5fd`) | `inertia-chatwoot-census/flow.patch` | PostgreSQL, Redis, Node 24 with corepack yarn |
| thinkroom | `thinkroom` (`f7865d0`) | `inertia-chatwoot-census/thinkroom.patch` | Node 24 |

Overlays default to [fixtures/corpus/rails-main-census-4](../../fixtures/corpus/rails-main-census-4) (`--overlays`
picks another round's). They are dependency-only (Gemfile, lock, `.ruby-version`); setup then moves Rails to the
requested commit. `run` checks that the services are reachable and refuses to start otherwise. Use disposable local
services, for example `amp orb service start census-redis --command 'redis-server --save "" --appendonly no'`.
Database URLs in the environment are refused.

Setup per app: `db:create db:schema:load` in production, the app's JS build where it has one, `assets:precompile`,
then the harness `prepare` step. That step loads the Blog's seeds; test fixtures for Campfire, Writebook, Fizzy (with
its UUID fixture helper) and CodeTriage; PingCRM's seeds with `Faker::Config.random = Random.new(42)`; Redprints' and
the starter kit's seeds; Lobsters' seeds and `FakeDataGenerator` with `srand(42)` and
`Faker::Config.random = Random.new(42)`, under the app's own queue adapter (solid_queue). Last comes `list`. All ten
configurations have been set up and run through this command ([Validation](#validation-nine-apps-2026-11-03)),
and so have the seven PostgreSQL apps and two `-nops` variants ([PG census](pg-census.md)).

PostgreSQL and MySQL databases are named by the app's config, not by the copy, so every copy of an app shares them.
For those apps `setup` runs `db:create` on its own and stops if it reports `Database '…' already exists`, rather
than loading the schema over another copy's data. Drop the databases first when they are disposable (for example
`dropdb pingcrm_production`, or `DROP DATABASE fizzy_production…` on port 3307). `setup` also creates `log`, `tmp` and
`storage`, which Git does not keep and Lobsters' production boot needs.

The PostgreSQL apps ([PG census](pg-census.md)) take their overlays from
[fixtures/corpus/pg-census](../../fixtures/corpus/pg-census). Unlike census 4's, these are not dependency-only: they
also carry the small compatibility edits Rails main needs, each listed in the PG census. An app row may add `pre_db`
commands (run before the database step), replace `db:create db:schema:load` with its own `db` tasks (Discourse
migrates, to load its structure.sql with pgvector), skip `assets:precompile` (`assets: false`), and set throwaway
local `env`. `prepare` seeds them with the app's own generator where it has one (CASA's seeds with
`DB_SEEDS_RANDOM_SEED=42`, Lago's with `srand(42)`, Sure's `demo_data:default` with `SEED=42`), otherwise with a seed
script in `fixtures/corpus/pg-census/seeds` that writes through the app's own services. A row with `copy: APP`
(`mastodon-nops`, `lago-nops`) runs APP's copy and database with different settings; `run` never measures two
configurations of one copy at the same time.

Chatwoot and three more Inertia apps ([Inertia and Chatwoot census](inertia-chatwoot-census.md)) follow the same
pattern, with overlays and seeds in [fixtures/corpus/inertia-chatwoot-census](../../fixtures/corpus/inertia-chatwoot-census).
`run --gem NAME=SPEC` (repeatable) also pins a gem to a git ref, `OWNER/REPO@REF`, in every app whose Gemfile or
Gemfile.lock lists it (a gem only in the lock is added with `require: false`). The variant Gemfile is `Gemfile.census-RAILS12-NAME-GEM12`, and the dependency control ignores that gem's own
lock lines. `rank --gem NAME` ranks the gem's lines instead of Rails', keyed by their path inside the gem, so apps on
different releases or git checkouts of it share one key. `rank --gem all` ranks every gem outside Rails, Ruby's
default gems (json excepted) and the harness, keyed by gem, path and the line's source text
([gem census](gem-census.md)).

## What a run measures

The harness [bench/upstream/census/harness.rb](../../bench/upstream/census/harness.rb) boots each app in its own
process, in production, with no Lowrail preload. It uses census 4's request client, measurement and workload set
unchanged ([rails_main_census_4.rb](../../bench/upstream/rails_main_census_4.rb),
[census_4_workloads.rb](../../bench/upstream/census_4_workloads.rb)). What it generalizes is the round-specific
part:

* the expected Rails commit (`CENSUS_RAILS_SHA`), checked against the loaded railties;
* the mode, checked against `RubyVM::YJIT`/`RubyVM::ZJIT` after boot (Writebook's own `RubyVM::YJIT.enable` is
  hidden outside YJIT mode);
* preparation for every app;
* `GIT_REVISION=census` for every variant, so the app does not see the Rails commit.

Shared external controls, identical for every app: jobs are captured on the `:test` adapter and performed as their
own workloads, mail uses `:test` delivery, `config.hosts` is cleared, and URL options default to
`https://localhost`. Each response status is checked, and GET bodies must be non-empty. Apps that push native
Sidekiq jobs (`CENSUS_SIDEKIQ_FAKE=1`: Docuseal, Mastodon, Discourse) get the same control through
`Sidekiq::Testing.fake!`. Request throttles (Rack::Attack, Discourse's `RateLimiter`, Mastodon's posting limit) are
off or reset per run. `CENSUS_PREPARED_STATEMENTS=false` makes the harness check that the connection really runs
without prepared statements. `CENSUS_DEBUG=1` with `list` prints every exception raised while serving, for apps
that turn them into a bare 500.

Per workload: 50 warmup operations (`CENSUS_WARMUP`), then three GC-enabled windows of 20 operations (the median is
the reported value), then 10 traced operations with GC disabled (`CENSUS_REQUESTS`), attributed by file, line and
class. After every workload has been measured, a **SQL control** runs each workload twice more with an
`sql.active_record` subscriber on the measuring thread. It records `queries_per_op` and a digest of the statements,
with literals and numbers masked. The subscriber never runs during measurement. Since 2026-11-03 a leading minus sign
is masked too: SolidCache's signed `key_hash` changed sign between Rails commits and showed as a false SQL diff.
Digests in older receipts differ for statements with negative numbers.

## Outputs

Under `--out` (default `.lowrail/private/census`, not checked in):

| Path | Contents |
| --- | --- |
| `LABEL/APP-MODE.json` | One process: `app`, `ruby`, `mode`, `yjit`, `rails` (commit), `rails_dir`, `adapter`, `lock_sha256`, and per workload `gc_enabled_objects_per_op` (three windows), `traced_gc_objects`, `sites` (`file` as `RAILS/…`, `APP/…`, `GEM/…`, `RUBY/…`; `line`, `class`, `objects_per_op`) and `sql`. Same fields as census 4's receipts, plus `mode`, `rails_dir` and `sql`. |
| `LABEL/APP-MODE.log` | That process's output. |
| `LABEL/meta.json` | Rails spec and commit, Ruby description, and per run the apps, modes, `--only` and the dependency control. |
| `rank-LABEL-MODE.tsv` | Full ranking, written by `rank`. |
| `controls/SCRIPT-LABEL-MODE.txt` | Output of each controls run. |
| `open-rails-prs.json` | Cached open rails/rails PRs (`--refresh` refetches), with each PR's diff hunks once fetched. |

Receipts for a published round go to `docs/upstream/data/ROUND/receipts.tar.gz`, as in censuses 3 to 5.

## How ranking works

`rank` ([bench/upstream/census/rank.rb](../../bench/upstream/census/rank.rb)) is census 4's ranking. Only Rails
lines (`RAILS/…`) are ranked.

1. A line **reaches** a workload when it allocates at least 0.5 objects per operation there (traced window).
2. Apps reached counts distinct apps (`fizzy` and `fizzy-mysql` are one app).
3. Lines are **tiered by apps reached**: ≥ 7, 5–6, 3–4, 2, 1 by default (`--tiers 7,5,3,2`; with fewer apps, choose
   floors that fit).
4. Within a tier, lines are ordered by the **mean objects per operation over every workload of every app**. That is
   the per-call cost times how often an ordinary operation gets there. A line in more apps always ranks above a
   line in fewer, whatever its size, so single-app hotspots sink to the bottom.

Columns: apps, share (the fraction of all workloads reached), mean, workload kinds reached, and the two dominant
classes. Breadth across apps decides the order, and "workloads moved" in `compare` then decides whether a candidate
is worth a PR ([DECISIONS](../DECISIONS.md): prefer broad, idiomatic patterns over single-app hotspots).

`prs` matches the top `--top` ranked lines against open rails/rails PRs (via `gh`). It lists PRs whose diff hunks
cover the line (`line:`, approximate, because hunks are on each PR's own base) and counts the PRs that only touch
the same file (`file:`).

## Comparing branches, and the A/A rule

`compare --base B LABEL...` prints, per app and mode, the number of workloads whose median objects per operation
fell by at least one (`moved`), the median and the minimum delta (`--detail` lists every workload). The `ALL`
lines total each mode across apps. `SQL` lines count the workloads whose SQL digest differs from the base.
[compare.rb](../../bench/upstream/census/compare.rb) prints the same lines as census 4's `census_4_compare.rb`, and
`--markdown` prints census 5's per-app table.

**The A/A rule.**

* Every round runs two full unpatched runs, `base` and `base2`, with the same Rails, Ruby, apps and modes
  (`run --aa`). Candidates are measured against `base2`, and `compare --aa base` prints the `base2 − base` block
  first.
* The A/A pair is the noise floor. Single write workloads move by 10 to 180 objects in either direction between
  identical runs (cache, timestamp and job-payload effects). A candidate is therefore judged by the shift of the
  whole distribution: workloads moved ≤ −1 and the median, set against the A/A counts. Census 4's candidate 8 moved
  82 of 97 workloads against the A/A's 26. A single cell proves nothing.
* An A/A median that is not +0.0, or A/A counts that grow from round to round, mean state is accumulating between
  runs. Fix the workload reset first; do not rank or compare until then (census 4 reran everything for this).
* The SQL control follows the same rule. A candidate passes when its changed-SQL count does not exceed the A/A's, on
  the same workloads.
* `controls` runs a round's SQL-and-result snapshot script (for example
  [census_5_controls.rb](../../bench/upstream/census_5_controls.rb)) under each label's Rails, in one SQLite app's
  bundle (`--app`, default blog), for every mode. Every label's output must equal the first label's, otherwise the
  command exits 1.

## CPU census: `script/cpu-census`

[`script/cpu-census`](../../script/cpu-census) ranks the same corpus by instructions instead of objects (census 8,
[rails-main-census-8](rails-main-census-8.md)). It reuses `script/census`'s copies, bundles and workloads (set up
with `script/census setup`, same `--corpus`), and runs each app and mode once under a Callgrind with a sampling
request:

```sh
mise exec -- script/cpu-census build                    # patched Valgrind 3.19.0 into /opt/c8-valgrind (VALGRIND_PREFIX)
mise exec -- script/cpu-census run --label cpu --aa --modes interp,yjit --jobs 8
mise exec -- script/cpu-census rank --label cpu --mode interp --by line --objects ALLOC_LABEL
mise exec -- script/cpu-census compare --base cpu2 --aa cpu
mise exec -- script/cpu-census prs --label cpu
```

Per workload it reports the exact instructions per operation of the measuring thread, the share sampled inside GC
(apart, charged to no line), objects per operation, and sampled Ruby stacks with lines; a sample's instructions go to
its nearest Ruby frame, so C functions count for the Ruby line that called them. `rank --by method` ranks by self
instructions. `--objects` adds the objects column from a `script/census` label on the same pin. Under YJIT only
JIT-flat workloads are ranked (the gate is in the [census 8 method](rails-main-census-8.md#pins-and-method)).
Instruction counts follow invariant 4: a CPU ranking points at candidates, and a candidate's own claim is its
per-call Callgrind micro ([micro.rb](../../bench/upstream/census8/micro.rb), [ir.sh](../../bench/upstream/census8/ir.sh))
against an A/A.

Two runs must not use the same app copy at once: the workloads write to its database. Split `--apps` between
concurrent runs (`-nops` configurations share their app's copy).

## Validation (2026-11-02)

Blog and Campfire on Rails main `5810776eec` (census 5's pin), Ruby 4.0.7, interpreter and YJIT. The A/A pair
(`base`, `base2`) and census 5's candidate 12 (`thomasklemm/rails@thomasklemm/merge-skip-empty-extending`,
`2c301c33bf`) as the patched branch:

* `rank` output (text and TSV) is byte-identical to `rails_main_census_4_rank.rb` on all six label/mode runs. It is
  also identical on census 4's and 5's published receipts (`base2`, both modes). `compare` is identical to
  `census_4_compare.rb` (with `DETAIL=1`) on the same runs and on every census 4 receipt label. `--markdown` is
  identical to `census_5_table.rb` on census 5's receipts.
* A/A (`base2 − base`): median +0.0 in both modes. 0 / 2 of 19 workloads moved ≤ −1 (interpreter / YJIT), and one
  Blog YJIT write workload moved by −109. The SQL control changed for 0 workloads.
* Candidate 12: Campfire median −5.0 / −4.9 objects per workload, 6 of 9 workloads moved in both modes (A/A: 0).
  Census 5 recorded −5.8 / −4.3 for this app. Blog was flat, as in census 5. SQL changed for 0 workloads.
  `census_4_controls.rb` and `census_5_controls.rb` gave identical output for base, base2 and the branch in both
  modes. As a negative control, a script that prints the loaded Active Record path differs between labels and
  makes `controls` exit 1.
* A first pass recorded SQL from every thread. It showed 1–2 workloads drifting in the A/A pair. Recording only
  the measuring thread removed that drift.

## Validation, nine apps (2026-11-03)

All ten configurations on census 5's pin (Rails main `5810776eec`, Ruby 4.0.7), set up from scratch with
`script/census setup` and run with `run --label base --aa --modes interp,yjit --jobs 10`. Every copy passed `list`, with
97 workloads in total (blog 10, campfire 9, writebook 8, fizzy 14, fizzy-mysql 14, codetriage 7, pingcrm 8,
redprints-cfp 8, react-starter-kit 8, lobsters 11), the same names as census 5's receipts. Three fixes to the command
came out of the first full pass:

* **Server databases.** fizzy-mysql's `db:schema:load` failed on a foreign key because census 5's copies had left
  `fizzy_production*` on the shared MySQL server. `setup` now refuses when `db:create` reports an existing database
  (see [Services and apps](#services-and-apps)). It also creates `log`, `tmp` and `storage`; Lobsters' production
  boot opens `log/rails.log`. PingCRM's `prepare` requires `faker`, which its Gemfile marks `require: false`.
* **Lobsters data.** The first runs differed from census 5 on GET story (−3,282 objects) and GET tag (−936). Census
  5's recorded recipe (`db:prepare`, then `rails runner` with `srand(42)` and `Faker::Config.random =
  Random.new(42)`) reproduces census 5's stories exactly. The harness had omitted the Faker seed, and it generated
  under boot's `:test` queue adapter. Replaying census 5's recipe with only `queue_adapter = :test` added reproduces
  the harness's stories, so the generator's draws depend on the adapter. `prepare` now seeds Faker and generates under
  the app's adapter, and its stories match census 5's row for row. Two fresh setups give identical stories, users,
  tags and comments.
* **Job workloads.** fizzy-mysql under YJIT enumerated a 15th workload, `perform Turbo::Streams::BroadcastStreamJob`,
  in both A/A runs. Fizzy's `broadcasts_refreshes` enqueues that job from Turbo's debounce timer thread 0.5 s later,
  so census 4's `jobs_from` caught it only when the timer fired inside the capture. Census 5 never caught it. The
  harness now drops jobs enqueued on other threads. Only Fizzy uses refresh broadcasts; `list` still passes all 14
  Fizzy workloads.

Results, with the Lobsters and fizzy-mysql runs redone after the fixes:

* A/A (`base2 − base`): median +0.0 in both modes. 24 / 23 workloads moved ≤ −1 and 16 / 15 moved ≥ +1
  (interpreter / YJIT); census 5's A/A moved 17 / 18 and 24 / 23. SQL changed for 8 / 6 workloads. PingCRM moved 8
  of 8 interpreter workloads by a median −3.0, a uniform shift from one process to the next.
* Against census 5's `base2`: median 0.0 in both modes. Per-app medians are within ±2.2 objects, except PingCRM
  interpreter at −5.4, within its own A/A shift. Six workloads move more than 20 objects, all comment or message
  writes. Fizzy comment POST.json moves +81 (interpreter, A/A 35), −67 / −68 on MySQL (A/A 19 / 67), and Fizzy
  PATCH comment moves −82 under YJIT (A/A 81). The Blog's comment POST moves −60 under YJIT (A/A 59). Campfire's PATCH
  message moves −37 under YJIT, where both rounds' A/A is flat, and is flat in the interpreter; neither that nor
  fizzy-mysql's interpreter −67 is explained.
* `rank` on `base2`: the interpreter top 40 is identical to census 5's (same sites, ranks and app counts). YJIT
  shares 39 of 40 sites; `fanout.rb:263` (40th, now 41st) and `date_and_time/zones.rb:38` swap at the boundary.

## Older census scripts

Censuses 3 and 3b (`script/rails-main-census`, `bench/upstream/rails_main_census.rb`, `rails_main_rank.rb`,
`census_3_*`, `census_3b_*`), census 4 (`rails_main_census_4*.rb`, `census_4_*`) and census 5 (`census_5_*`) stay in
place. Their reports cite them as the way to reproduce those rounds, and this command builds on census 4's
harness and workloads. Per-call micros and probes (`census_N_allocs.rb`, `census_N_yjit_probe.rb`,
`census_4_callers.rb`) and controls scripts remain per round, because they target that round's candidates.
