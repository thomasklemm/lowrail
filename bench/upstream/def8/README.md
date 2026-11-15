# DEF8 tooling

Record: [docs/upstream/rails8-defaults.md](../../../docs/upstream/rails8-defaults.md).

**Apps.** In a directory with a Gemfile holding only `gem "rails", path: RAILS_MAIN`, Ruby 4.0.9:

```
bundle exec rails new ../blog --dev
bundle exec rails new ../blogapi --dev --api
bundle exec rails new ../blogtw --dev --css tailwind
F="title:string body:text summary:text author_name:string author_email:string slug:string category:string tags:string status:string published:boolean featured:boolean published_at:datetime views_count:integer rating:decimal word_count:integer reading_time:integer cover_url:string language:string location:string notes:text"
bin/rails g scaffold Post $F && bin/rails g scaffold Comment post:references commenter:string body:text
```

Then in each app: `has_many :comments, dependent: :destroy` on `Post`, `root "posts#index"`, `get "home" => "pages#home"`
with an empty `PagesController#home` (the API app renders `{ status: "ok" }`), `<%= render @post.comments %>` under
the post on its show page (API: `render json: @post.as_json(include: :comments)`), the seeds from the record (30
posts, 5 comments each), `gem "vernier", "1.12.0"` and `gem "benchmark-ips"` with `require: false`, then with
`RAILS_ENV=production SECRET_KEY_BASE=...`: `bin/rails db:prepare`, keep 30 posts, `bin/rails assets:precompile`.

**Measurements** (run from the app directory with the same environment):

* `harness.rb check` lists the stack, callbacks and subscribers; `DEF8_OFF=piece,...` switches pieces off,
  `DEF8_ON=csp` turns on the commented-out CSP initializer.
* `matrix.sh APP OUT.tsv interp|yjit 20 JOBS PIECE...` runs the Callgrind ablations (base twice, then one piece off
  per run) through `ir.sh`; `table.rb OUT.tsv [yjit]` prints the cost table. `BUNDLE_GEMFILE` selects a branch.
* `harness.rb profile OUT.json [WORKLOAD...]` profiles through Puma with Vernier; `shares.rb OUT.json` charges each
  sample to one piece, `under.rb OUT.json WORKLOAD REGEX` lists the frames under a piece.
* `micro.sh APP helpers_micro.rb|snippets_micro.rb N CASE...` prices one helper call or snippet.
* Prototypes: `ql_ips.rb` and `im1_ips.rb` (benchmark-ips for the PR bodies, run with `taskset -c 3`, best of 5,
  interleaved with an A/A), `im1_probe.rb` (differential output probe for IM1).
* IMP336 (IM1 folded into importmap-rails#336, 2026-11-15): `imp336_ips.rb` (the body's benchmark, `NONCE=1` for a
  CSP nonce) through `imp336_run_ips.sh` (core 1, five interleaved rounds of main, its A/A, IM1 alone and the
  combined head, apps with 7 and 50 preloaded modules) and `imp336_table.rb`; `imp336_run_ir.sh` and `imp336_ir.rb`
  (Callgrind per call with a nonce), `imp336_allocs.rb`, `imp336_probe.rb` (integrity and nonce differential) and
  `imp336_ci_matrix.sh` (the upstream CI matrix replayed locally).
