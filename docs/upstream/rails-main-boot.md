# Rails-main boot check: `script/rails-main-boot`

A weekly check, until the 8.2 beta, of which census apps break on rails/rails `main` compared with the latest 8.1
release. Boots like these found the breaks behind the Sidekiq, Rack::Sendfile and Action Mailer upgrade-guide notes
(UG82K, UG82S, UG82M). The allocation and CPU census ([census.md](census.md)) measures costs. This check only asks
whether an app still starts, and it is cheap enough to run every week.

```sh
mise exec ruby@4.0.9 -- script/rails-main-boot services        # fresh orb: packages, PostgreSQL, Redis, memcached
mise exec ruby@4.0.9 -- script/rails-main-boot                 # every census app, newest v8.1.* tag vs main
mise exec ruby@4.0.9 -- script/rails-main-boot --apps blog,sure --tests --bisect 5
```

Each run writes `docs/upstream/rails-main-boot-DATE.md` (the record), `bench/upstream/rails-main-boot/DATE/`
(`results.json` and every probe receipt), and logs to `.lowrail/private/rails-main-boot/DATE/`. Its last line is
`BOOT: quiet` or `BOOT: N new breaks`.

## What it checks

Per app and per tree, in order, stopping at the first failure:

1. **bundle**: the census variant Gemfile with Rails swapped to the tree's commit resolves and installs. Only Rails
   moves; every other gem keeps its lock (`script/census`'s `variant`). All installs run one after another before the
   parallel boots start, because the copies share one gem directory.
2. **boot**: [`probe.rb`](../../bench/upstream/rails_main_boot/probe.rb) requires `config/application`, holds
   `config.eager_load` off, and requires `config/environment` in production.
3. **eager_load**: the same process then eager-loads as Rails' finisher does (`before_eager_load` hooks,
   `Zeitwerk::Loader.eager_load_all`, the eager-load namespaces, `Rails.application.eager_load!`).
4. **runner**: `rails runner 'puts Rails.version'`, the app's own entry point with production's eager loading on.
5. **tests** (`--tests`): the app's suite in the test environment with Lowrail's outcome recorder (`LOWRAIL=0`,
   `LOWRAIL_OUTCOMES`), so per-test results are compared as `lowrail verify` compares them.

A failure records its class, message, first app frame, first Rails frame, first gem frame and backtrace.

## What counts as a break

* **8.1 passes, main fails.** For tests, each test that passes on 8.1 and fails or errors on main, grouped by failure.
* **For apps that already target 8.2** (campfire and fizzy set `load_defaults 8.2`, so 8.1 cannot boot them), the
  previous run's main is the base: the check failed now and passed on the previous run's main.
* **New** means the previous record (the newest `bench/upstream/rails-main-boot/*/results.json` before DATE) did not
  have the same app and signature. A signature is the check, the error class and the first message line, with paths,
  line numbers and addresses masked. Breaks that disappear are listed as fixed.

## Attribution and ownership

* **Range:** the previous run's main when that check passed there, else the merge base of 8.1 and main.
* **Bisect** (`--bisect N`, default 3 groups, in severity order): first parent over main in that range, cheapest app
  of the group, only the failing check. A step is bad when it fails with the same signature, good when it passes,
  and skipped otherwise. The range start must pass, or the bisect stops and says so. The first bad merge names the PR.
* **Ownership**, the way `script/ownership` does it: rails/rails issues and PRs that name the error's constant or
  method, open and closed PRs that cross-reference the introducing PR, our queue items with `introduced_by` that
  PR, and whether the upgrade guide on main mentions the term. These are search hits to read, not verdicts. The
  record's ranking and ownership column is checked by hand before anything is built.

Severity order: boot, eager load and runner (the app does not start in production) before bundle (a dependency
blocks the upgrade) before tests. Within a severity, more apps first.

Nothing goes upstream from this command: no PR, comment or issue. A new break becomes a queue item only through the
normal [submission queue](../DECISIONS.md#submission-queue-2026-11-03) rules.

## Setup and limits

* Copies are `.corpus/boot-APP` (`--corpus`), fetched with census setup's overlays and reused across runs. The
  first run creates each database on the 8.1 tree (`db:create db:schema:load`, marker `tmp/.boot-db`). No assets,
  JavaScript build or seeds: boot needs none.
* Services as in [census.md](census.md): PostgreSQL (pgvector for Chatwoot and Discourse, pg_partman for Lago),
  Redis and memcached as disposable orb services. fizzy-mysql needs MySQL and is left out unless one runs. On a
  fresh orb run `script/rails-main-boot services` first. It installs the missing packages and starts what is not
  already listening, so it is a no-op on a prepared orb. It stays out of `.agents/setup`, because most threads of
  the project need none of it (Thomas, 2026-11-25). What it does:

  ```sh
  sudo apt-get install -y redis-server memcached postgresql-17-pgvector postgresql-17-partman libidn-dev libleptonica-dev
  sudo mkdir -p /var/run/postgresql && sudo chown $USER /var/run/postgresql
  /usr/lib/postgresql/17/bin/initdb -D ~/pgdata -U $USER --auth=trust
  amp orb service start census-pg --command "/usr/lib/postgresql/17/bin/postgres -D $HOME/pgdata -k /var/run/postgresql -c listen_addresses=127.0.0.1 -c fsync=off"
  amp orb service start census-redis --command 'redis-server --save "" --appendonly no'
  amp orb service start census-memcached --command 'memcached -u nobody -p 11211'
  ```

  Mastodon needs `libidn-dev` to bundle. Docuseal eager-loads only with its own pdfium fork, which is released for
  musl only, so on glibc it is checked up to boot.
* **Apps that already target 8.2** cannot be compared with 8.1: campfire and fizzy set `load_defaults 8.2`, and
  flow's lock needs marcel 2 (Active Storage on main). Their schema loads on main, and from the second run on they
  are compared with the previous run's main.
* **Runtime** (2026-11-25, 2 vCPU, 3 GB): a cold orb takes about 33 minutes, almost all of it in bundling (Chatwoot's
  grpc and Lago's Rust extension are built from source). With warm copies and bundles a run takes about 3 minutes,
  including a 13-step bisect.
* Production boot with census environment values (throwaway secrets, `SECRET_KEY_BASE_DUMMY`). Code that only runs
  per request, per job, or in development is not covered. That is what `--tests` and the census are for.

## Schedule

Weekly, Mondays 07:00 Tallinn time (05:00 UTC), on this thread's orb in existing mode, so runs reuse the warm
copies and bundles (about 3 minutes; a cold 2 vCPU orb takes about 33). Set by Thomas on 2026-11-25.
