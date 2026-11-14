# CE2: heavier pages for profiling Rails

Ordinary pages that real apps have, heavier than the census's: index pages of 50 and 100 records with their
associations, JSON responses of 100 records, a form page and a save flow. They run in three census apps, in separate
copies (`--corpus censusce2`), so the census's own workloads and data never change. Sizes follow DECISIONS "Realistic
sizes upstream".

| App | Workload | What it is |
| --- | --- | --- |
| blog | `GET articles (50)`, `GET articles (100)` | the app's own index (`includes(:comments)`, the scaffold `_article` partial with a `button_to` per row), `?per_page=` |
| blog | `GET articles.json (100, jbuilder)` | the app's own `index.json.jbuilder` (`json.array!` with a partial) |
| blog | `GET api/articles.json (100, as_json)` | `render json: articles.as_json(include: :comments)`, 100 articles, about 200 comments |
| blog | `GET customer edit (form)` | edit page of a 31-column `Customer`: 22 fields (text, email, tel, url, date, number, selects, check boxes, textarea) and 3 `button_to` |
| blog | `PATCH customer (save)` | the form's 22 params through `update` (validations, normalizes, uniqueness), 303 redirect; two fields alternate between two values |
| lobsters | `GET newest (50)`, `GET newest (100)` | the newest page for a logged-in user (story list, votes, hidden and saved stories), `?per_page=` |
| lobsters | `GET newest.json (100, as_json)` | the app's `render json: @stories` (`Story#as_json`) |
| lobsters | `GET settings (form)` | the settings page: three forms, about 30 fields |
| fizzy | `GET cards (50)`, `GET cards (100)` | the cards index, geared pagination pages 3 and 4 (cards with board, column, assignees, tags) |
| fizzy | `GET cards.json (100, jbuilder)` | page 4 as JSON through the app's jbuilder views (`json.cache!` per card) |

[workloads.rb](workloads.rb) defines them, [seed.rb](seed.rb) adds their data, and [overlays/](overlays/) adds what
the apps lack: `?per_page=` (at most 100), blog's `Api::ArticlesController` and `Customer`, and the Rails-main fixes
for Fizzy's uuid initializer and Lobsters' activerecord-typedstore. Lobsters' settings save is not a workload: the
form's blank password fields roll the session token and log the user out.

## Set up

From the Lowrail root, on an orb (Git, mise, bun/npm, network; the three apps use SQLite):

```sh
CENSUS_SET=ce2 mise exec -- script/census setup --corpus censusce2 --rails main \
  --apps blog,lobsters,fizzy --ruby-overlays bench/upstream/ce2/overlays
```

`setup` ends with `list`, which runs every workload three times. `--rails` takes any ref (`main`, a commit,
`OWNER/REPO@BRANCH`, `/path/to/rails@REF`).

## Profile

Allocations and Callgrind Ir go through the census tools on these copies (`CENSUS_SET=ce2` selects the workloads).
[heap.sh](heap.sh) sets the fixed heap floors from [docs/bench.md](../../../docs/bench.md):

```sh
. bench/upstream/ce2/heap.sh
CENSUS_SET=ce2 mise exec -- script/census run --corpus censusce2 --label ce2 --rails main --aa --modes interp,yjit
CENSUS_SET=ce2 mise exec -- script/cpu-census run --corpus censusce2 --label ce2cpu --aa --modes interp,yjit
```

## Wall time

Run on an otherwise idle orb (no setup, census or Callgrind jobs; `uptime` near 0):

```sh
mise exec -- bench/upstream/ce2/walltime --trees main=main,branch=OWNER/rails@BRANCH --rounds 10 --out .lowrail/private/ce2-walltime
mise exec -- ruby bench/upstream/ce2/walltime_summary.rb .lowrail/private/ce2-walltime main
```

* **One pinned core:** every process runs under `taskset` on one CPU (`--cpu N`, default the last one).
* **Best of N:** a process ([walltime_harness.rb](walltime_harness.rb)) boots the app in production and per workload
  runs `CE2_WARMUP` operations (100), then `CE2_WINDOWS` windows (7) of `CE2_OPS` operations (20), GC on. The summary
  takes each process's fastest window; under YJIT only windows that compiled no block count.
* **A/A:** each round runs every app and mode as two processes per tree, in a palindromic order rotated by round, and
  reports each tree's second process against its first. A difference smaller than the A/A is not a result. One tree
  (`--trees main=main`) gives its timings and A/A alone.

The JSONs keep every window (ms, objects and GC runs per operation, YJIT blocks compiled).
