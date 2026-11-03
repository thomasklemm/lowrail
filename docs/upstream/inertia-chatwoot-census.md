# Inertia and Chatwoot census: inertia-rails sites, and what Chatwoot adds

Lowrail bet L6. The census corpus gains Chatwoot (PostgreSQL, Redis, Sidekiq) and three more open-source Inertia
Rails apps, run with the existing three Inertia apps on canonical Rails main, Ruby 4.0.7, interpreter and YJIT, with an
A/A pair. The new `--gem` option ranks a gem's own lines, here inertia-rails, by breadth across the Inertia apps.
Result: four inertia-rails candidates (one a bug fix), one Rails candidate found through Chatwoot, and several Rails-main
compatibility breaks recorded from the new apps. Nothing was opened or commented on; each branch waits for a Codex
review.

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`bd77235be5`](https://github.com/rails/rails/commit/bd77235be534f5a2103cb2f33f6bb356ab6e535f) for setup, base,
  A/A and the inertia-rails candidates. Main moved to
  [`e64b660612`](https://github.com/rails/rails/commit/e64b660612fa582a4a89a91bc002269b29426e76) (merge of #59552)
  during the round; the Rails candidate is based on it and measured against it.
* **inertia-rails:** `master`
  [`3e1330a33d`](https://github.com/inertiajs/inertia-rails/commit/3e1330a33d9e4ae3a7ec52800d4d18d4179d5401) (latest
  release v3.23.0, plus #440). Every Inertia app runs that commit (`--gem inertia_rails=…@3e1330a33d`), whatever its
  own lock says (3.21.2–3.23.0).
* **Ruby 4.0.7**, production environment, PostgreSQL 15 with pgvector 0.8.1 on the local socket, Redis, memcached.
* **Command:** [`script/census`](../../script/census): `setup`, `run --aa --gem`, `compare`, `rank --gem`. Census 4's
  measurement: 50 warmups, three GC-enabled windows of 20, 10 traced operations. Workloads are in
  [`inertia_chatwoot_workloads.rb`](../../bench/upstream/census/inertia_chatwoot_workloads.rb).
* **A/A:** `ic` and `ic2`, both unpatched; candidates are compared with `ic2`. Over the six Inertia apps (55
  workloads) the median is +0.01% / −0.00% objects per workload (interpreter / YJIT), with 17 / 22 workloads moving
  ≤ −1. Chatwoot's A/A is `icw` / `icw2`: median +0.6 / +0.5 objects, 4 / 2 of 14 moving ≤ −1.
* **Allocation counts only.** Per-call times below come from same-process micros, not from application latency.
* **Receipts:** [data/inertia-chatwoot-census/receipts.tar.gz](data/inertia-chatwoot-census/receipts.tar.gz) holds
  every run JSON and log for `ic`, `ic2`, `ip1` (IR-1), `ip2` (IR-2), `ih` (IR-3), `ie` (IR-4), `iall`, `icw`,
  `icw2`, `cwm` and `cwj` (R-1), plus the full Rails and inertia-rails rankings of `ic2`.

## Apps

| App | Source (script/corpus) | DB | Front end | Workloads |
| --- | --- | --- | --- | ---: |
| chatwoot | [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) `ae66c979` (develop) | PostgreSQL + pgvector, Redis, Sidekiq | Vue (Vite) | 14 |
| hackatime | [hackclub/hackatime](https://github.com/hackclub/hackatime) `74deec42` | PostgreSQL (+ Solid Cache DB) | Svelte (Inertia) | 12 |
| flow | [AixleHQ/flow](https://github.com/AixleHQ/flow) `6a8b5fda` (develop) | PostgreSQL, Redis | React (Inertia) | 10 |
| thinkroom | [kieranklaassen/thinkroom](https://github.com/kieranklaassen/thinkroom) `f7865d01` | SQLite | React (Inertia) | 9 |
| pingcrm, redprints-cfp, react-starter-kit | as in [census.md](census.md) | PG / SQLite / SQLite | Vue / React / React | 8 each |

Overlays are in [fixtures/corpus/inertia-chatwoot-census](../../fixtures/corpus/inertia-chatwoot-census), and the
seeds, which write through each app's own models and services, are in its `seeds/` directory. As with the PG census,
the overlays carry the compatibility edits Rails main and Ruby 4.0 need.

**Workloads.**

* **Chatwoot:** the dashboard HTML shell and widget, then the JSON APIs the Vue dashboard calls (conversations list,
  meta, conversation, messages, inboxes, contacts, profile). It also measures toggle_status, an agent reply
  (`POST messages`), and three jobs that reply enqueues (`ActionCableBroadcastJob`, `EventDispatcherJob`,
  `SendReplyJob`). Requests authenticate with devise_token_auth headers, as the dashboard does.
* **Inertia apps:** a full HTML visit, an Inertia XHR visit (`X-Inertia`, `X-Inertia-Version`), and a partial reload
  (`X-Inertia-Partial-Component`/`-Data`). Where the app uses them, they also cover deferred props (Flow: board
  activities; Hackatime: dashboard stats, leaderboard entries), optional props (Thinkroom: archived), a form redirect
  and a form error (302 with session errors, or Hackatime's 422). Flow also uses `always`, `scroll` and a camelizing
  `prop_transformer`.

### What each app needed, and what failed

* **Chatwoot:**
  * Ruby 4.0 pin.
  * cld3 dropped. It is archived, caps Ruby < 3.5, and only an enterprise LLM service uses it.
  * administrate-field-belongs_to_search dropped (it caps Rails < 8 and administrate < 1.0). Its dashboard uses
    `Field::BelongsTo`, and administrate moves to 1.0.
  * Newer acts-as-taggable-on, audited, devise-two-factor, devise_token_auth, rails-i18n 8, redis-client and
    ruby-vips 2.3.
  * benchmark and readline added (they left Ruby 4's default gems), and sprockets-rails added (the rails gem no
    longer depends on it).
  * Sidekiq loads its own Active Job adapter, because main removed Rails' Sidekiq adapter.
  * 40 `enum name: {…}` calls rewritten positionally; the keyword form was removed in Rails 8.
  * `resource :app, only: [:index]` changed to `only: []`.
  * The administrate SCSS removed (there is no sassc).
  * commonmarker 0.23.12 caps Ruby < 4.0. script/corpus builds its v0.23.12 tag as a path gem with the cap lifted; a
    port to commonmarker 2 would have changed the measured app.
  * At runtime Chatwoot pays a deprecation on every request: Rails main deprecated
    `skip_before_action :verify_authenticity_token` in
    [`4f2ee07b8e`](https://github.com/rails/rails/commit/4f2ee07b8e), and under `deprecation = :notify` each warning
    builds a backtrace (52 objects per operation). The fix is the app's (`skip_forgery_protection`), not Rails'.
* **Flow:**
  * marcel ~> 2.0.
  * scimitar 2.15 mutates `ActionDispatch::Request.parameter_parsers`, which Rails main now freezes
    ([`ac98c112f4`](https://github.com/rails/rails/commit/ac98c112f4), #57952, with no CHANGELOG entry). The overlay
    requires scimitar against an unfrozen copy. **A Rails-main break for apps; a CHANGELOG note would help.**
  * Its `default_order` scope clashes with the new `default_order` query method on main, so the overlay renames it
    to `membership_order`.
  * Runs as `DEPLOYMENT_MODE=self_hosted`, skipping the SaaS billing and legal gates.
* **Hackatime:**
  * Dependencies only, plus one initializer: blind_index 2.8.1 memoizes into `TableMetadata`, which main freezes
    since [`3ba8970f4a`](https://github.com/rails/rails/commit/3ba8970f4a) (Ractor-safe PredicateBuilder).
    **Another Rails-main break for a gem.**
  * Its build generates js_from_routes helpers before the Vite build, as its Dockerfile does.
* **Thinkroom:** dependencies only. Its `rate_limit` stores counts in `Rails.cache` (a file store shared by all runs),
  so the first base run hit HTTP 429 after 60 comments. The harness now keeps Rails' counting path but reports a count
  of 1 for `rate-limit:` keys.
* **Chatwoot A/A drift (fixed):** devise_token_auth appends one token per sign-in to `users.tokens` (up to 25) and
  parses them on every request, which added about 11 objects to every workload per run (A/A median +10.8). Setup now
  clears the census admin's tokens; the A/A after that is +0.6.
* **Not attempted:** Fallout (no license), Gumroad (MySQL and very large).

## Ranking

### (a) inertia-rails lines by breadth (`rank --gem inertia_rails`, `ic2`)

Six Inertia apps and 69 workloads (Chatwoot's 14 count in the mean and reach nothing). Every line below reaches all
six apps; ordered by mean objects per operation. YJIT gives the same order (rank 6: 8.25; ranks 1–3 within 3%).

| Rank | Site (master `3e1330a`) | Share | Objects/op | What it is | Disposition |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `props_resolver.rb:120` `prop.try(:rescue?)` | 54% | 37.8 | `Object#try` on every resolved value: an args Array and a kwargs Hash | **IR-1** |
| 2 | `props_resolver.rb:285` `try(:once?)` in `excluded_by_once_cache?` | 54% | 37.6 | same, from `keep_prop?` | **IR-1** |
| 3 | `props_resolver.rb:279` `try(:deferred?)` in `keep_prop?` | 49% | 35.2 | same | **IR-1** |
| 4 | `props_resolver.rb:89` `each_with_object({}) do \|(key, prop), …\|` | 54% | 27.7 | the result Hash (required) and a `[key, value]` pair Array per entry | **IR-4** (pairs) |
| 5 | `props_resolver.rb:90` `"#{prefix}.#{key}"` | 54% | 24.4 | a dotted path String per key, plain data included | **IR-2** |
| 6 | `renderer.rb:129` `extract_shared_keys` | 54% | 8.8 | `key.to_s.split('.', 2).first` per shared key (`expose_shared_prop_keys`) | Lead: about 1 µs per render; below the bar alone |
| 7, 9 | `configuration.rb:138/130` `bind_controller` | 68% | 6.1, 3.0 | `Configuration.new(**@options)` several times per request | **Covered by open #437** |
| 8 | `props_resolver.rb:48` `key.to_s` in `expand_dot_notation` | 54% | 5.7 | one String per top-level prop | Lead (`Symbol#name`); below the bar alone |
| 10–12 | `props_resolver.rb:229/236/262` `try` in `collect_*_metadata` | 54% | 2.8 each | on prop types only | Required (`try` on BaseProps; small) |
| 13 | `renderer.rb:242` `parse_header` | 54% | 2.3 | `split(',')` of five headers | Required output; the header lookup itself is **IR-3** |
| 14 | `renderer.rb:57` Vary header | 54% | 1.6 | `split/map/reject/join` | Small; lead |

Not visible as gem lines but caught by tracing callers: Rails `Headers#env_name`
(`action_dispatch/http/headers.rb:124`) reaches all seven apps (90% of workloads, 6.6 objects/op). In the Inertia
apps, nine of those lookups per render come from the inertia-rails renderer (**IR-3**). The rest come from
turbo-rails, devise_token_auth and Rails' own `Sec-Fetch-Site` lookup.

### (b) Rails lines newly visible in Chatwoot

Chatwoot's Rails lines (`icw2`) that reach fewer than three apps in the PG census's `base2` ranking, ordered by mean
objects per operation over Chatwoot's 14 workloads.

| Rank | Site | Chatwoot workloads | Objects/op | PG census apps | Disposition |
| ---: | --- | ---: | ---: | ---: | --- |
| 1 | AS `deprecation/reporting.rb:23` `caller_locations` | 9 / 14 | 52.4 | 0 | The per-request `verify_authenticity_token` deprecation (above). App migration; rejected. |
| 2 | AJ `arguments.rb:164` `serialize_hash` `each_with_object` | 2 / 14 (199 of 17,936 objects per `POST toggle_status`) | 20.9 | 2 (CodeTriage, Lago) | **R-1** |
| 3 | AR `store.rb:334` `as_indifferent_hash` | 7 / 14 | 18.7 | 0 | `IndifferentCoder#load`: one HWIA per `Message#content_attributes` load (`store … coder: JSON`). Required. |
| 4, 5 | AR `relation/merger.rb:67/162` `public_send(bang_method, *value)`, `order!(*order_values)` | 11 / 14 | 15.6, 10.0 | 0 | The bang methods take `*args`, so each merged value list is copied. Avoiding it means non-splat internal variants of each bang method: not small. Lead. |
| 6 | AP `http/headers.rb:122/124` `env_name` | 9 / 14 | 7.6 | 0 | devise_token_auth reads five dashed headers per request. Rails precedent #49853 moved Rails' own hot lookups to env keys; Rails' only remaining one is `Sec-Fetch-Site` (one String per verified write, below the bar). Lead. |
| 7 | AR `querying.rb:110` STI `indexed_rows` | 10 / 14 | 4.7 | 1 | Required. |
| 8 | AS `time_with_zone.rb:567` `to_datetime` | 9 / 14 | 4.5 | 1 | Memoized `DateTime`/`Rational`. Required. |
| — | AR `core.rb:481` `Relation.create(self)` (YJIT only, 78/op) | 13 / 14 | — | — | Known YJIT parity gap (empty anonymous rest), open [ruby/ruby#19655](https://github.com/ruby/ruby/pull/19655); see [jit-parity-census](jit-parity-census.md). |

Chatwoot's largest non-Rails cost is Psych: `GET dashboard conversation` parses YAML on every request (15,401 Strings
per operation). That is app code, not Rails.

## Candidates

Each candidate is one commit, by Thomas Klemm as author and committer, with no trailers. inertia-rails branches are
on [thomasklemm/inertia-rails](https://github.com/thomasklemm/inertia-rails), based on master `3e1330a33d`, except
IR-2, which is stacked on IR-1. The Rails branch is on [thomasklemm/rails](https://github.com/thomasklemm/rails),
based on main `e64b660612`.

| # | Branch | Commit | Pattern | Per call (interp / YJIT) | Workloads moved (A/A 17 / 22 of 55) | Median per workload | Median % |
| --- | --- | --- | --- | --- | ---: | ---: | ---: |
| IR-1 | [`thomasklemm/plain-prop-predicates`](https://github.com/thomasklemm/inertia-rails/tree/thomasklemm/plain-prop-predicates) | [`1eea7579be`](https://github.com/thomasklemm/inertia-rails/commit/1eea7579be4994f5fefa2dc0d1e6d1297e42a686) | every resolved prop value (**also a bug fix**) | 23-value page: 165 → 99 objects, 72 → 58 µs / 24 → 21 µs | 45 / 42 | −54 / −53 | −1.0% / −1.1% |
| IR-2 | [`thomasklemm/plain-prop-leaves`](https://github.com/thomasklemm/inertia-rails/tree/thomasklemm/plain-prop-leaves) (on IR-1) | [`df89cd5761`](https://github.com/thomasklemm/inertia-rails/commit/df89cd5761300dae3c668af6acf8b63de2a2c960) | every plain value in a props hash | on IR-1: 99 → 78, 58 → 41 µs / 21 → 17.6 µs | 35 / 39 (vs IR-1) | −6.3 / −5.9 (vs IR-1) | −0.14% / −0.12% |
| IR-3 | [`thomasklemm/inertia-header-env-keys`](https://github.com/thomasklemm/inertia-rails/tree/thomasklemm/inertia-header-env-keys) | [`ec00f768ee`](https://github.com/thomasklemm/inertia-rails/commit/ec00f768ee3d48e2e975e35c79f2be5a6f0a68c3) | every Inertia render: 9 header lookups | 10 → 0 objects, 7.1 → 0.8 µs / 5.1 → 0.4 µs | 42 / 43 | −6.8 / −5.8 | −0.08% / −0.09% |
| IR-4 | [`thomasklemm/prop-hash-each`](https://github.com/thomasklemm/inertia-rails/tree/thomasklemm/prop-hash-each) | [`4729be645b`](https://github.com/thomasklemm/inertia-rails/commit/4729be645b1963231978df3a7e4b1adbac04dc1d) | every props hash entry | 165 → 127, 72 → 67.5 µs / 25.5 → 21.3 µs | 42 / 42 | −15.3 / −15.9 | −0.43% / −0.46% |
| all | [`wip/inertia-combined`](https://github.com/thomasklemm/inertia-rails/tree/wip/inertia-combined) (measurement only) | [`f53c26e387`](https://github.com/thomasklemm/inertia-rails/commit/f53c26e38736967a9c927fe41994b81dfdfd8e39) | IR-1 to IR-4 | 165 → 40, 71.5 → 37.8 µs / 23.9 → 14.0 µs | 44 / 44 | −84 / −83 | −2.1% / −2.2% |
| R-1 | [`thomasklemm/active-job-hash-pairs`](https://github.com/thomasklemm/rails/tree/thomasklemm/active-job-hash-pairs) | [`b05ca528f6`](https://github.com/thomasklemm/rails/commit/b05ca528f6887676ec5a38c9a010fd3d57c2507b) | every enqueue with hash or keyword arguments | typical kwargs 13 → 6 objects, 5.1 → 4.2 µs / 3.1 → 2.4 µs | Chatwoot: the 2 enqueuing workloads (A/A 2–4 of 14) | toggle_status −238 / −242, message −58 / −51 | −1.3%, −0.7% |

**Per app** (median objects per workload against `ic2`, interpreter / YJIT):

| App | Workloads | A/A | IR-1 | IR-2 (vs IR-1) | IR-3 | IR-4 | all |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| hackatime | 12 | +0 / +0 | −198 / −182 | −17 / −18 | −6 / −6 | −59 / −61 | −303 / −289 |
| pingcrm | 8 | +2 / −1 | −85 / −76 | −11 / −9 | −9 / −4 | −30 / −31 | −135 / −132 |
| react-starter-kit | 8 | +0 / +0 | −51 / −53 | −7 / −4 | −6 / −6 | −12 / −15 | −82 / −82 |
| thinkroom | 9 | −2 / +1 | −36 / −33 | −4 / −10 | −7 / −6 | −13 / −14 | −63 / −55 |
| redprints-cfp | 8 | +1 / −1 | −35 / −34 | −3 / −3 | −7 / −5 | −9 / −10 | −55 / −54 |
| flow | 10 | −0 / −1 | −52 / −44 | −5 / −6 | −7 / −6 | −25 / −25 | −89 / −83 |

The largest single workloads: Hackatime's `GET dashboard stats (deferred)` −10.7% with IR-1 (10,972 → 9,797), and its
`GET dashboard (Inertia XHR)` −14.2% with all four (13,114 → 11,247).

**Micros.** Scratch scripts, not committed, run on Ruby 4.0.7 with the gem's bundle; each figure is the best of 5 ×
20,000 calls. The resolver micro resolves one page: shared `auth`/`flash`, a project hash with a nested owner and
settings, 20 task hashes in an array, and `errors: {}` (23 values outside arrays). The header micro does the
renderer's eight `X-Inertia-*` reads on an Inertia request.

### Why each one is exact

* **IR-1** changes behavior for one case, and the change is a bug fix. `keep_prop?`, `excluded_by_once_cache?` and the
  rescue check asked every value for `deferred?`, `once?` and `rescue?` through `Object#try`. Only `BaseProp`
  subclasses mean those predicates. A plain value that answers one, such as a record with a `deferred` or `once`
  column, was dropped from the first load or raised `NoMethodError: once_key`. The new spec (three objects, one per
  predicate) fails on master with that `NoMethodError` and passes on the branch. Prop types are checked exactly as
  before.
* **IR-2** applies only when no partial reload filters the props (or the parent was already resolved) and no DevTools
  recorder is active. In that case, for a value that is not a Hash, Array, Proc, prop type or `to_inertia`
  serializer, the old path ends in `transformed_props[key] = value` with no observable step in between:
  `collect_metadata` and `record_prop` do nothing, `keep_prop?` is true (given IR-1), the evaluator returns the value,
  and `rescue?` is false. IR-2 relies on IR-1 for that, so it is stacked on it. A differential check resolved 3,000
  random props trees (plain values, nested hashes and arrays, closures, optional, defer, always and merge props,
  serializers, with `only` and `except` partial reloads), and the master, IR-1 and IR-2 output digests were
  identical. A deliberately broken IR-2 that ignored partial filtering changed the digest.
* **IR-3:** `request.headers[name]` is `get_header(env_name(name))`, so reading the env key returns the same value.
  The middleware already reads `X-Inertia-Version` this way. Every header IR-3 touches is covered by request specs
  that send real headers.
* **IR-4:** `Hash#each` with two block parameters yields the same keys and values in the same order. The same
  differential check gave the same digest.
* **R-1:** same as IR-4, in Active Job's `serialize_hash`. This is the pattern of merged
  [#59236](https://github.com/rails/rails/pull/59236). In
  [#55544](https://github.com/rails/rails/pull/55544), byroot asked for a pass over the remaining low-hanging fruit in
  Active Job argument serialization, and this pair Array is still there on main.

### Suites

* **inertia-rails** (each branch, and `wip/inertia-combined`): `bundle exec rspec --tag ~type:generator` passes
  1076 examples, 1077 with IR-1's spec (master: 1076), 0 failures. `bundle exec rake test` (minitest): 61 runs, 0
  failures. `bundle exec rubocop`: 197 files, no offenses. The generator specs were not run, as on master.
* **Rails R-1:** `cd activejob && RAILS_STRICT_WARNINGS=1 bundle exec rake test` passes on all seven adapters (async,
  inline, queue_classic, resque, sneakers, backburner, test), 0 failures and 0 errors. RuboCop on the file is clean.

### R-1 in numbers

| Arguments | Objects | Interpreter | YJIT |
| --- | ---: | ---: | ---: |
| `foo: 1, bar: 2, baz: { egg: 1, spam: 3 }` (byroot's typical case in #55544) | 13 → 6 | 5.1 → 4.2 µs | 3.1 → 2.4 µs |
| a Chatwoot-style event hash (10 keys, nested) | 37 → 15 | 14.3 → 11.8 µs | 7.9 → 5.6 µs |

Chatwoot against main `e64b660612` (`cwm` → `cwj`, interpreter / YJIT): the two workloads that enqueue jobs with
hash arguments move. `POST toggle_status` drops by 238 / 242 objects (17,936 per operation, −1.3%) and `POST message`
by 58 / 51 (−0.7%). The other 12 workloads stay within ±4 objects (one interpreter outlier, `GET conversations` +39,
is in Chatwoot's A/A range), and SQL is unchanged. Separately, moving Rails main from `bd77235be5` to `e64b660612`
(`icw2` → `cwm`, which includes our merged #59551–#59554) lowered Chatwoot's median workload by 24 / 23 objects,
with 12 of 14 workloads moving.

### Overlaps checked

* inertia-rails open PRs: #437 (ours: config binding via `dup`, `needs_transform?` loops) touches neither the
  `try` calls, nor the hash walk, nor the header reads. #438 (escape_json_responses) and #439 (`JSON::Fragment` for
  cached props) are JSON encoding; #435 and #436 are ours, a DevTools fix and nested serializers. None overlaps.
* inertia-rails history: `7915f3b` ("Optimize array transformation", skryukov) added the `needs_transform?` shortcut
  for plain arrays. IR-2 does the same for plain hash values, but keeps the copy of each hash. Closed #422 (as_json
  in the resolver) is unrelated.
* rails/rails: no open PR touches `serialize_hash`. #55544 (merged) changed `serialize_hash_key`, not the hash walk.
* Branch interactions: IR-4 conflicts textually with IR-2 in `deep_transform_props` (one line), and every branch
  adds a CHANGELOG line. Whichever lands second needs a trivial rebase. `wip/inertia-combined` shows the resolution.

### Submission (2026-11-03)

* **R-1** opened as [rails/rails#59563](https://github.com/rails/rails/pull/59563) and **IR-3** as
  [inertiajs/inertia-rails#441](https://github.com/inertiajs/inertia-rails/pull/441). Thomas opened both after Sol
  approved each on both rubrics. Sol counted 8 → 0 objects for IR-3's eight header reads (the micro above counts
  10, including two objects of its own), so #441 says 8.
* **No stacked PRs** ([DECISIONS](../DECISIONS.md)), so IR-1, IR-4 and IR-2 go as one PR, in that order and one commit
  each, on [`thomasklemm/props-resolver-plain-values`](https://github.com/thomasklemm/inertia-rails/tree/thomasklemm/props-resolver-plain-values)
  [`3886d49e82`](https://github.com/thomasklemm/inertia-rails/commit/3886d49e824dd0b134fdef62d9d07799d590d1f3) on
  master `3e1330a33d` (census `ipr` measured `56739a92b3`, which differs only in the spec). After Sol's P3, the IR-1
  spec also covers a partial reload (`only`) and a DevTools recorder. Reverting any one of the three `BaseProp`
  guards now fails at least one of its two examples, and both examples fail on master. The IR-2/IR-4 line is resolved once (the resolver is byte-identical to `wip/inertia-combined`'s),
  and the PR has a single CHANGELOG entry. rspec 1078 examples, 0 failures; rake test 61 runs, 0 failures; rubocop
  197 files clean. The 3,000-tree differential digest is identical on master and the branch. Micro (23-value page):
  165 → 40 objects, 73 → 38 µs interpreter, 24.7 → 14.6 µs YJIT. Census `ipr` against `ic2`: median −75.3 / −74.6
  objects per workload (−1.8% / −1.9%), 41 / 41 of 55 workloads moved (A/A 17 / 22). Hackatime's Inertia XHR dashboard
  is −14.2% (13,114 → 11,258).
* Flow's Rack::Attack `login/combo` throttle (10 logins per hour) began returning 429 for the `ipr` run. Flow's setup
  now calls `Rack::Attack.reset!`, which clears the counters but keeps Rack::Attack in every measured request.

**Combined draft — Treat plain prop values as data in the props resolver**

> The props resolver asks every resolved value whether it is deferred, once or rescued, through `Object#try`. A plain
> value that answers one of those predicates is treated as a prop type. A record with a `deferred` column is dropped
> from the first load, and one with a `once` column raises `NoMethodError` (`once_key`). This PR asks only prop types;
> the added spec fails on master.
>
> The plain-data path also gets cheaper. The first commit skips the three `try` calls per value (each allocates an
> args Array and a kwargs Hash). The second walks props hashes with `Hash#each` instead of `each_with_object` pairs.
> The third copies plain values as is when no partial reload or DevTools recording needs their paths, as `7915f3b`
> did for plain arrays.
>
> | Resolving a page with 23 plain values | Before | After |
> | --- | ---: | ---: |
> | objects | 165 | 40 |
> | µs, interpreter / YJIT | 73 / 24.7 | 38 / 14.6 |
>
> Across six open-source Inertia apps (PingCRM, Hackatime, Flow, Thinkroom, Redprints CFP, the React starter kit),
> 41 of 55 requests allocate fewer objects, median −1.8%, with no change in the resolved props.

### PR description drafts (not published)

**IR-1 — Treat plain prop values as data in the props resolver**

> The props resolver asks every resolved value whether it is deferred, once or rescued, through `Object#try`. Each
> `try` allocates an args Array and a kwargs Hash, so a typical page pays three of each per value. A plain value that
> happens to answer one of those predicates, such as a record with a `deferred` or `once` column, is also treated as a
> prop type: it is dropped from the first load, or raises `NoMethodError` for `once_key`.
>
> Ask only prop types (`BaseProp`). The added spec fails on master.
>
> | Page with 23 plain values | Before | After |
> | --- | ---: | ---: |
> | objects per resolve | 165 | 99 |
> | µs per resolve (interpreter / YJIT) | 72 / 24 | 58 / 21 |
> | six open-source Inertia apps, median objects per request | — | −1.0% (45 of 55 requests fewer) |

**IR-2 — Copy plain prop values without building their paths** (on IR-1)

> `deep_transform_props` builds a dotted path String for every key and runs the serializer, metadata, partial-reload
> and evaluation checks on it, even for strings, numbers and nil in a nested hash. When no partial reload filters the
> props and DevTools is not recording, none of those steps can change a plain value, so copy it as is, as commit `7915f3b`
> did for plain arrays.
>
> | Same page | Before (IR-1) | After |
> | --- | ---: | ---: |
> | objects per resolve | 99 | 78 |
> | µs per resolve (interpreter / YJIT) | 58 / 21 | 41 / 17.6 |

**IR-3 — Read Inertia request headers by their Rack env keys**

> The renderer reads the partial-reload, reset, once and scroll headers with `request.headers['X-Inertia-…']`.
> Each read turns the name into an env key (a regexp match and a new String), nine times per render.
> `request.get_header('HTTP_X_INERTIA_…')` returns the same values, as the middleware already does for
> `X-Inertia-Version`.
>
> | Eight header reads | Before | After |
> | --- | ---: | ---: |
> | objects | 10 | 0 |
> | µs (interpreter / YJIT) | 7.1 / 5.1 | 0.8 / 0.4 |

**IR-4 — Iterate prop hashes without a pair Array per entry**

> `each_with_object({}) do |(key, prop), acc|` yields each entry as a new `[key, value]` Array before destructuring
> it. `Hash#each` with two block parameters yields key and value directly.
>
> | Page with 23 plain values | Before | After |
> | --- | ---: | ---: |
> | objects per resolve | 165 | 127 |
> | µs per resolve (interpreter / YJIT) | 72 / 25.5 | 67.5 / 21.3 |

**R-1 — Serialize Active Job hash arguments without pair arrays**

> `ActiveJob::Arguments#serialize_hash` walks every hash argument (keyword arguments included) with
> `each_with_object({}) do |(key, value), hash|`, which allocates a `[key, value]` Array per entry before
> destructuring it. Walking it with `each` yields key and value directly; output and key checks are unchanged.
>
> | `perform_later` arguments | Objects | Interpreter | YJIT |
> | --- | ---: | ---: | ---: |
> | `foo: 1, bar: 2, baz: { egg: 1, spam: 3 }` | 13 → 6 | 5.1 → 4.2 µs | 3.1 → 2.4 µs |
> | 10-key nested event hash | 37 → 15 | 14.3 → 11.8 µs | 7.9 → 5.6 µs |
>
> In Chatwoot (Rails main, PostgreSQL, Sidekiq), the agent actions that enqueue event jobs allocate 0.7–1.3% fewer
> objects per request. Same-process serialization micro; not an end-to-end enqueue benchmark.

## Rejected, covered elsewhere, and leads

* **`Configuration#bind_controller`** (rank 7/9): covered by our open #437.
* **`extract_shared_keys`** and **`expand_dot_notation`'s `key.to_s`** (ranks 6 and 8): `Symbol#name` (as
  `ActiveRecord::Store` does) would save about 14 objects and about 1 µs per render. That is below the 0.1% bar
  alone; a lead to fold into a later resolver PR if a maintainer wants more.
* **`try` on prop types** (ranks 10–12): runs only for prop types, a few per page. Not worth the churn.
* **Vary header rebuild** (`renderer.rb:57`) and **`parse_header`'s `split`**: small, and the output is required.
* **JSON encoding** and **cached props**: open #438 and #439 (brodienguyen); not duplicated.
* **Rails `Sec-Fetch-Site` via `request.headers`** (`request_forgery_protection.rb:704`): one String per verified
  write. It follows #49853's precedent but is below the bar.
* **Rails `Relation::Merger` splats** (Chatwoot rank 4/5): not small; lead.
* **Rails `IndifferentCoder#load`**, **`to_datetime`**, **STI instantiation:** required.
* **The `verify_authenticity_token` deprecation per request:** intentional (4f2ee07b8e); the fix is in the app.
* **Rails-main breaks found** (notes only; they belong to the gems and apps, not to a Lowrail PR): `parameter_parsers` frozen (ac98c112f4) breaks scimitar 2.15;
  `TableMetadata` frozen (3ba8970f4a) breaks blind_index 2.8.1; new `default_order` query method clashes with an app
  scope of that name. The first two are worth a CHANGELOG note upstream if a maintainer agrees.

## script/census: what it needed

* App rows for chatwoot, flow, hackatime and thinkroom (`IC_OVERLAYS`); script/corpus pins, plus commonmarker's
  path-gem build for Chatwoot.
* `run --gem NAME=SPEC` pins a gem to a git ref in every app whose Gemfile lists it. The variant Gemfile gets a
  `-NAME-sha12` suffix, and the dependency control ignores the pinned gem's own lock lines. `rank --gem NAME` ranks
  that gem's lines by their path inside the gem, so apps on different releases share keys.
* `bases.uniq` compares Rails bases by commit.
* Harness: prepare cases for the four apps; the thinkroom rate-limit control and the Chatwoot token reset described
  above.

## Limits

* Allocation counts and same-process micros only. No `lowrail bench` instruction counts or end-to-end latency were
  measured, so no app speed claim is made.
* Three of the six Inertia apps are small (PingCRM, Redprints, the starter kit). Hackatime and Flow carry the larger
  props.
* R-1's evidence is one app in this census, with two more (CodeTriage, Lago) reaching the line in the PG census.
