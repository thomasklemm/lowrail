# Pre-release API regression audit: Rails 8-1-stable → main (2026-11-04)

This audit looks for breaking changes on rails/rails main that haven't been released yet, of the kind TH-1 (#59606, merged by amatsuda, "Good catch!") found. A breaking change here means a name or signature from 8.1 that main removed, renamed or made private without a deprecation, where gems or apps still use it. Items that C16 owns are excluded:

- `ActiveSupport::LogSubscriber.colorize_logging`
- the frozen `default_url_options`
- the frozen `ViewPaths#_prefixes`

`Arel::Table`'s positional name is already handled by our #59574.

## Method

1. **Surface dump.** [`surface.rb`](../../bench/upstream/api_regressions/surface.rb) requires every framework file on each tree; for 8-1-stable that is 87 files minus load failures. It then walks every constant under the framework namespaces and records:
   - each module or class with its superclass and ancestors;
   - its methods, own and inherited, both instance and singleton, with visibility, parameters and source;
   - its constants.

   The two trees were 8-1-stable `6e09124217` and main `aa236fc09b`, giving 22,941 and 24,289 entries.
2. **Diff.** [`surface_diff.py`](../../bench/upstream/api_regressions/surface_diff.py) takes the full method set, so a method that moved to an included module or a superclass doesn't count as removed. It reports:
   - 345 public or protected methods missing;
   - 9 methods made private;
   - 35 modules missing;
   - 43 constants missing;
   - 541 signature changes, of which 218 break callers that pass more arguments or other keywords.

   Delegator noise (`Time::Value`, `TypeMetadata`) and modules every includer still carries leave 252 method removals.
3. **Attribution.** [`surface_attr.py`](../../bench/upstream/api_regressions/surface_attr.py) finds the removing commit and PR with `git log -S` and checks for a deprecation in 8.1 or main. Separately, every missing constant was checked for a `deprecate_constant` on main.
4. **Usage.**
   - The latest releases of about 150 common Rails gems (devise, sidekiq, activeadmin, avo, rails_admin, lograge, rails_semantic_logger, sentry-rails, newrelic_rpm, honeybadger, jpmobile, rabl-rails, thredded, composite_primary_keys, the SQL Server, Oracle and PostGIS adapters, and others), grepped first by name and then by qualified pattern.
   - GitHub code search, giving counts and the repositories behind them.
   - The top 250 gems by downloads among all 34,012 reverse dependencies of the 13 framework gems ([`top_gems.tsv`](../../bench/upstream/api_regressions/top_gems.tsv), latest releases), grepped with qualified patterns; see the corpus check below.

## Confirmed, built (patches for Sol)

| ID | Name | Removed in | Breaks | Fix | Patch / body |
| --- | --- | --- | --- | --- | --- |
| AR-1 | `ActionView::LookupContext#find_template` | #57783 (`5ee0ba5c48`), split into `find`/`find!`; no alias, no deprecation | jpmobile (`FallbackViewSelector`), rabl-rails (`Library#fetch_source`), thredded (collection renderer): `NoMethodError` on main; about 800 code-search hits | `alias :find_template :find!` (raises like 8.1); one test | [patch](../../bench/upstream/api_regressions/patches/find-template.patch), [body](../../bench/upstream/api_regressions/bodies/find-template.md) |
| AR-2 | `ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED` | #56041 (`a18d246600`), moved to `BCryptPassword` | Spree's `maximum_password_length` default and open-build-service's `User` validation: `NameError` at load; about 470 code-search hits, mostly app `User` models | Public constant pointing at the BCrypt limit; one test | [patch](../../bench/upstream/api_regressions/patches/max-password-length.patch), [body](../../bench/upstream/api_regressions/bodies/max-password-length.md) |
| AR-4 | `ActiveRecord::QueryMethods#where!` and `#having!` bind values | #59579 (`401f146f413`, merged 2026-11-03), `(opts, *rest)` became `(opts, rest = FROZEN_EMPTY_ARRAY)`; no deprecation | Discourse `Permalink.filter_by` (named bind left in the SQL; `PG::SyntaxError` on PostgreSQL), Canvas's SIS exporter and crono_trigger's web UI (`?` binds: `NoMethodError`); overrides of `where!(opts, *rest)` (mobility, active_record-acts_as) receive nested binds; about 500 code-search hits for `where!("` | Splat signatures and the `merge` splat restored, as in 8.1; one test | [patch](../../bench/upstream/api_regressions/patches/where-bang-binds.patch), [body](../../bench/upstream/api_regressions/bodies/where-bang-binds.md) |

Each branch is one commit by Thomas on rails main `8b06b0eb98`:

- `thomasklemm/restore-find-template` @ `c814745459`
- `thomasklemm/restore-max-password-length` @ `08be5191db`

AR-2 opened as [#59627](https://github.com/rails/rails/pull/59627) on 2026-11-04; AR-1 opened as [#59629](https://github.com/rails/rails/pull/59629) the same day. Both are pushed to the fork after Sol's "open with nits" round, and are waiting for the coordinator to open them. Each test fails without its fix. AR-1's test also fails against a mutant in which the alias points at the non-raising `find`.

Differentials against 8-1-stable ([`ft_diff.rb`](../../bench/upstream/api_regressions/ft_diff.rb), [`mp.rb`](../../bench/upstream/api_regressions/mp.rb), [`rs_diff.rb`](../../bench/upstream/api_regressions/rs_diff.rb)):

- **AR-1 and AR-2:** identical on the 4.0.9 interpreter, on YJIT and on master with ZJIT.
- **AR-3:** identical apart from the warning and the class name (`Http::Session`). `defined?` now returns `nil`, as for every `deprecate_constant`.

Suites:

| Suite | Runs | Result |
| --- | --- | --- |
| Active Model `cases/**` | 1,251 | green |
| Action View `template/**` + `actionpack/**` | 3,203 | 1 failure, `test_compiling_with_erubi_does_not_load_herb`; it fails on main too, because the herb gem is in this bundle |
| Action Pack `dispatch`/`controller`/`journey` | 4,433 | 5 errors, all msgpack missing from this bundle; the same tests error on unpatched code |

Plain-sentence descriptions (readability gate):

- AR-1: "`find_template` is another name for `find!`."
- AR-2: "`SecurePassword` publishes BCrypt's 72-byte limit under its old name."
- AR-3: "Each old name warns and returns its `Http` replacement."

All three are L0. Measurement only rules out a slowdown: the patches add no code to any call path except the deprecated constant lookup.

Separate review (subagent, both rubrics): AR-1 and AR-2 pass correctness on the interpreter, YJIT and ZJIT, and maintainability at L0. The reviewer's extra probes are identical to 8.1:

- AR-1: `nil` prefixes, a Symbol name, `rescue ActionViewError`, and the parameter list.
- AR-2: `defined?`, `constants`, Ractor-shareable; the bcrypt gem is still not loaded.

Neither PR discussed these names, and none of the removing commits is in a release tag. Caveat for AR-1: `LookupContext` is `:nodoc:` in 8.1. The gem callers are the argument. props_template also calls `find_template`, as a fallback.

Sol round (coordinator): open with nits, no deprecation or CHANGELOG entry needed, since the removals are unreleased. Changes made:

- Both bodies now say "The removal is unreleased".
- AR-1's body no longer includes the VM comparison.
- AR-2's body drops the code-search count and says the constant "preserves the BCrypt byte limit".

Load order for AR-2 is verified with [`mp_load.rb`](../../bench/upstream/api_regressions/mp_load.rb). Touching `SecurePassword` loads the same 228 files on main and on the patch. `SecurePassword` stays autoloaded, and the bcrypt gem is not loaded.

## AR-4: `where!` and `having!` with bind values (built 2026-11-04, not opened)

Branch `thomasklemm/where-bang-binds` @ `e4852e04bb` on rails main `d7875e3fb1` (merges cleanly onto `7a78da5a55`), one commit by Thomas. The change it fixes landed the day before the audit and is in no release.

Observed with [`where_bang.rb`](../../bench/upstream/api_regressions/where_bang.rb) (sqlite3, 8-1-stable vs main vs patch):

| Call | 8.1 and patch | main |
| --- | --- | --- |
| `where!("n = ?", 2)` | `WHERE (n = 2)` | `NoMethodError: undefined method 'empty?' for an instance of Integer` |
| `where!("n = ? OR n = ?", 1, 2)` | `WHERE (n = 1 OR n = 2)` | `ArgumentError (given 3, expected 1..2)` |
| `where!("n IN (?)", [1, 2])` | `WHERE (n IN (1, 2))` | `PreparedStatementInvalid` |
| `where!("url LIKE :u", u: "%x%")` | `WHERE (url LIKE '%x%')` | `WHERE ((url LIKE :u))`: no rows on SQLite; on PostgreSQL 15, Discourse's `Permalink.filter_by` call raises `PG::SyntaxError` at `:` ([`where_bang_pg.rb`](../../bench/upstream/api_regressions/where_bang_pg.rb)) |
| `where!("at >= ?", time)` | `WHERE (at >= '2026-03-01 00:00:00')` | `NoMethodError` (`Time#empty?`) |
| `having!("n > ?", 1)` | `HAVING (n > 1)` | `NoMethodError` |
| override `where!(opts, *rest)` sees, for `where("n = ?", 2)` | `["n = ?", [2]]` | `["n = ?", [[2]]]` |

Public `where`, `having`, `merge` and the array form `where!(["n = ?", 1])` are unchanged on main. The patch output is identical to 8.1 on the 4.0.9 interpreter, on YJIT and on master with ZJIT.

Readability gate: L0. In one sentence, "`where!` and `having!` take their binds as a splat again, as in 8.1". It undoes the signatures and the `merger.rb` line of `401f146f413`; only the frozen default in `build_where_clause` stays. The separate reviewer found that keeping the merger line broke `merge(where: [cond, bind])` for overrides (mobility's `QueryBuilder` only translates a Hash) and checked permitted params after destructuring, so `merge(where: [permitted_params])` raised `ArgumentError`; the amended patch reverts it and the test covers `merge(where: [...])`. A wrapper (`where!(opts, *rest) = _where!(opts, rest)`, with `where` calling `_where!`) would keep the allocation saving but makes `Relation#where` skip overrides of `where!`, which mobility and active_record-acts_as rely on, so it was rejected. Measured only to rule out a slowdown: one more Array per `where`/`having`/`none` call than main, the same count as before `401f146f413`.

Tests (after Sol's nits, split): `where!` binds, `having!` binds (`?`, named, Array), an override of `where!` that calls `super`, and `merge(where: [permitted params])` in `where_test.rb`. All four fail or error on main and pass with the patch; relation, scoping, inheritance, null-relation and finder tests: 1,685 runs, green. Sol: open with nits (applied); queued after D1 in `bench/upstream/pr-queue`. Relation, scoping, inheritance and null-relation tests after the amend: 1,334 runs, green. Before the amend, the whole Active Record sqlite3 suite: 10,269 runs, the 1 failure and 5 errors are environment only (no `sqlite3` CLI, no `pg` gem, `require "arel"` with `-I` paths).

## Not opened: AR-3, `ActionDispatch::Request::Session` and `Request::Utils` (coordinator decision)

This patch is built: [patch](../../bench/upstream/api_regressions/patches/request-session-utils.patch), [body](../../bench/upstream/api_regressions/bodies/request-session-utils.md), branch `thomasklemm/request-session-utils-constants` @ `e18bd83c4d`. It fixes `NameError` in json_tagged_logger and ManageIQ.

It is held because #57856 says the removal is deliberate: "This class (and Utils) are no doced, so I don't think we need to keep it at `Request::Session`". gmcgibbon approved and merged it. Under the audit rule that makes it a removal maintainers accepted.

If the coordinator wants to make the case anyway, the reviewer's fixes are:

- a CHANGELOG entry, as for `Cookies::HTTP_HEADER`;
- drop or cite the "application specs" claim in the commit;
- rename the test away from "aliases".

Known gaps compared with 8.1, the same for any `deprecate_constant`:

- `defined?`/`const_defined?` are false;
- `class ActionDispatch::Request::Session; end` defines a new class;
- a bare `Session` inside `class Request` resolves to the middleware namespace.

## Skipped: deprecated, discussed and accepted, owned elsewhere, or not used

| Item | Why skipped |
| --- | --- |
| `ActionController::InvalidAuthenticityToken`, `Cookies::HTTP_HEADER`, `ActiveRecord::Validations::NumericalityValidator`, `ActiveRecord::Callbacks::CALLBACKS` | Already `deprecate_constant` on main |
| `ActiveSupport::Multibyte::Chars`, `Multibyte.proxy_class`, sidekiq adapter, `exec_insert` | Deprecated in 8.1, removed on schedule |
| `UrlHelper#link_to`/`button_to`/`current_page?` (#55410, `NavigationHelper`) | Only breaks code that includes `UrlHelper` alone. rafaelfranca asked for exactly this ("I don't expect people to be cherry picking view helpers"), and avo already includes `NavigationHelper` |
| Log subscribers on structured events (#55900): `process_action`, `start_processing`, `attach_to`, `LogSubscriber::Start`, colour constants | Discussed in the PR as private API (nodoc since #55755). rails_semantic_logger, lograge and amazing_print already adapted. `colorize_logging` is C16's |
| `CommandRecorder#record`/`#inverse_of`/`invert_*` (#58254, #58239) | Made private and reshaped deliberately; the PR body explains it, with a CHANGELOG entry |
| `ActionCable::Connection::{TaggedLoggerProxy, Stream, WebSocket, ClientSocket, …}`, `Server::Configuration` (#50979, #57847) | Large refactors. `Server::Configuration` is aliased. rails_semantic_logger already resolves the new `TaggedLoggerProxy`. cable_ready and stimulus_reflex only mention the names in comments or their own config |
| Action Cable test helpers after #50979: `stub_connection` with a positional Hash (`ArgumentError`; dobase, cias-api), undeclared identifiers (`NoMethodError`), `connection.transmissions` (about 280 code-search hits), `ActionCable::Channel::ConnectionStub` (about 230; appsignal, activity_notification, motion) | Covered upstream by czj's open #59532, which documents each change; palkan and matthewd are discussing a shim versus documentation there |
| `AssociationReflection#join_primary_key`/`join_foreign_key` (#59120) | statesman guards with `respond_to?`; composite_primary_keys, avo and motor-admin patch internals, which is expected |
| `Column#fetch_cast_type` (#56484) | annotaterb guards with `respond_to?` |
| Unused internals removed (Journey `MatchData#named_captures`, `Route#required_keys`, `TransitionTable#states`, `FromClause#merge`, `WhereClause#referenced_columns`, and so on) | No caller in the gem sample; name hits were homonyms |
| `ActiveStorage::Downloader`, `ROTATIONS`, `EventBuffer`, `ignore_tables`, `default_charset`, `default_headers`, `tld_length` | Gem hits were the gems' own names, or gems that write a still-present API (`SchemaDumper.ignore_tables` is still a class accessor) |

## Top-250 corpus check

The 238 non-framework gems among the top 250 add one new real break and no new candidates:

- **redmine_crm** 0.0.63 (rank 201, 30M downloads) includes only `ActionView::Helpers::UrlHelper` in its Liquid drops and calls `link_to` there. On main this raises `NoMethodError`, the same break avo already worked around. It comes from #55410's move into `NavigationHelper`, which rafaelfranca asked for. It stays in the skipped table; coordinator: record only, the S2 upgrade-guide note covers it.
- with_advisory_lock checks `respond_to?(:internal_exec_query, true)` and already uses `query_all` on 8.2.
- activerecord-nulldb-adapter defines its own `internal_exec_query`.
- composite_primary_keys patches the reflection internals, as it does on every release.
- view_component's `find_template` is its own method.
- None of the 238 references `find_template` on a lookup context or `MAX_PASSWORD_LENGTH_ALLOWED`, so AR-1 and AR-2 rest on jpmobile, rabl-rails and thredded, and on Spree and open-build-service.

## Leads not built yet

- **`Rails::BacktraceCleaner::APP_DIRS_PATTERN`**, removed in #56333. Foreman's `config/initializers/backtrace_silencers.rb` matches backtrace lines with this constant, and code search finds about 700 hits, many of them sentry-ruby's own constant. The class is `:nodoc:`, and the PR replaced the allow-list with an exclusion. Restoring the old regexp would satisfy Foreman, but would bring back a list of directories that Rails itself no longer uses. Coordinator: record only (`:nodoc:`, and the pattern's meaning changed).
- **`ActiveModel::Validations::NumericalityValidator#validate_each`** lost its `precision:`/`scale:` keywords in #59246. Overrides in subclasses still work: money-rails takes three arguments and calls `super` without keywords. It would only break a caller that passes the keywords; none was found.
- **`SpawnMethods#merge(other, *rest)` → `merge(other)`** (`79b6a77d3e`, "Remove unused parameter"). A second argument raised a deprecation in 7.1 and was ignored from 7.2 on. On main it raises `ArgumentError`. No caller was found.
