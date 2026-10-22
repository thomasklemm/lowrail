# Bet L: sealed lowering on Lobsters

Branch-only exploration. The app is ruby/ruby-bench at
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
Ruby 4.0.7 / Rails 8.1.4, anonymous `GET /` and `GET /s/enr7ye`.
These are the front/story pair from bet H, not observed production traffic.
No app source/configuration patch, cache-policy change or upstream action.

## One bounded extension: prospective screen rule

The current-main tier screen is allocation-neutral on `/` and adds six
objects on the story. There are no warm form/token calls on either route.
The chosen extension removes collection's **blog-specific inventory**, not
its stock-body/source, exact-renderer-holder, epoch or no-layout conditions.
The view is opaque: it is passed to live `Template#render` unchanged.
Token/form and quarantined link/route lowering remain unchanged.

Run exactly one extension screen with the same three off-A/on/off-B rounds,
500 warmups and 600 samples/route/worker. Require both seeds' exact status,
whole body and **all** headers in every round. To advance the chosen front
page, require fewer median allocations than both off arms in every round and
an allocation-effect 95% interval wholly below the A/A noise envelope.
No retry, filtering or second variant. Otherwise stop with no Ir/RPS cohort.
Only a clear screen win could advance to one interpreter cohort, with both
total/no-GC A/A 95% intervals wholly within **±0.1%**, fixed before counting;
RPS would additionally require a clear win and the 44a33c4/544ad8d protocol,
A/A first. No counted instruction or RPS work has been launched.

## Reused fixture and tooling

The dependency-only Puma 8.0.2 Gemfile, lock and entropy policy, validation
adapter, `script/native-bench` and `script/screen` are copied from
[`6510cd2`](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8).
The only shared-driver change retains upstream's SQLite `:memory:` instead
of overriding `DATABASE_URL` to a disk copy. The external setup performs
the same SQLite backup as upstream `benchmark.rb` and bet H. Every worker
uses the shipped DB, SHA256
`d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
The overlay and policy bytes are unchanged. Untimed exact companions alone
control declared entropy/clocks; the timed screen retains live inputs.

The public build runs against a disposable disk copy of that same schema:
runtime-builder subprocesses intentionally strip RUBYOPT, so they cannot
receive a fixture-restoring preloader. A direct default-memory build produces
zero AR units because its new DB is empty. No app config is changed to evade
this. Runtime screening restores the original in-memory fixture after boot,
and proves actual AR/collection hits independently of build counts.

Both native screens are direction-finding YJIT diagnostics, not JIT-flat,
Ir, RPS, production admission, whole-app or own-suite certificates.

## Reproduction

From a checkout with `mise install ruby@4.0.7` and `cargo build --locked`:

```sh
git clone https://github.com/ruby/ruby-bench .corpus/ruby-bench
git -C .corpus/ruby-bench checkout 351a39b77e6c06f4f4fa03148639b10a6bb0c716
BUNDLE_GEMFILE="$PWD/fixtures/corpus/lobsters-rps.Gemfile" mise exec ruby@4.0.7 -- bundle install
(cd gem && mise exec ruby@4.0.7 -- rake compile)
mkdir -p .lowrail/lobsters/seed
cp .corpus/ruby-bench/benchmarks/lobsters/db/production.sqlite3 .lowrail/lobsters/seed/primary.sqlite3
BUNDLE_GEMFILE="$PWD/fixtures/corpus/lobsters-rps.Gemfile" \
  DATABASE_URL="sqlite3:$PWD/.lowrail/lobsters/seed/primary.sqlite3" \
  mise exec ruby@4.0.7 -- target/debug/lowrail build \
  "$PWD/.corpus/ruby-bench/benchmarks/lobsters" --sealed --env production --jit yjit
mise exec ruby@4.0.7 -- ruby script/screen "$PWD/.corpus/ruby-bench/benchmarks/lobsters" / /s/enr7ye \
  --config PRIVATE_CONFIG --output NEW_PRIVATE_DIRECTORY \
  --exploration-setup "$PWD/bench/experiments/lobsters_sealed_screen.rb" --warmup 500 --samples 600
```

Private config supplies `workload: "lobsters"`, absolute `app`, `seed`,
`artifact` (app's `.lowrail`), `gemfile`, `exploration_only: true`, headers
`{"HTTP_X_REQUEST_ID":"lowrail-lobsters-sealed"}`, and `exploration_sources`
containing `lobsters_native_validation.rb`, `lobsters-rps-entropy.json` and
`blog_entropy.rb`. All are source-pinned before workers launch.

The off-only CPU/allocation ranking uses
`bench/experiments/lobsters_sealed_profile.rb APP SEED NEW_JSON` with
`LOWRAIL=0 RAILS_ENV=production BUNDLE_GEMFILE=... ruby --yjit`.
It retains every StackProf frame and denominator, not just selected totals.
