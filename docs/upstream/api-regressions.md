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
   - A ranked top-250 corpus is being built separately; it follows below once ready.

## Confirmed, built (patches for Sol)

| ID | Name | Removed in | Breaks | Fix | Patch / body |
| --- | --- | --- | --- | --- | --- |
| AR-1 | `ActionView::LookupContext#find_template` | #57783 (`5ee0ba5c48`), split into `find`/`find!`; no alias, no deprecation | jpmobile (`FallbackViewSelector`), rabl-rails (`Library#fetch_source`), thredded (collection renderer): `NoMethodError` on main; about 800 code-search hits | `alias :find_template :find!` (raises like 8.1); one test | [patch](../../bench/upstream/api_regressions/patches/find-template.patch), [body](../../bench/upstream/api_regressions/bodies/find-template.md) |
| AR-2 | `ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED` | #56041 (`a18d246600`), moved to `BCryptPassword` | Spree's `maximum_password_length` default and open-build-service's `User` validation: `NameError` at load; about 470 code-search hits, mostly app `User` models | Public constant pointing at the BCrypt limit; one test | [patch](../../bench/upstream/api_regressions/patches/max-password-length.patch), [body](../../bench/upstream/api_regressions/bodies/max-password-length.md) |

Each branch is one commit by Thomas on rails main `8b06b0eb98`:

- `thomasklemm/restore-find-template` @ `c814745459`
- `thomasklemm/restore-max-password-length` @ `08be5191db`

Neither is pushed yet. Each test fails without its fix. AR-1's test also fails against a mutant in which the alias points at the non-raising `find`.

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

## Held: AR-3, `ActionDispatch::Request::Session` and `Request::Utils`

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
| `AssociationReflection#join_primary_key`/`join_foreign_key` (#59120) | statesman guards with `respond_to?`; composite_primary_keys, avo and motor-admin patch internals, which is expected |
| `Column#fetch_cast_type` (#56484) | annotaterb guards with `respond_to?` |
| Unused internals removed (Journey `MatchData#named_captures`, `Route#required_keys`, `TransitionTable#states`, `FromClause#merge`, `WhereClause#referenced_columns`, and so on) | No caller in the gem sample; name hits were homonyms |
| `ActiveStorage::Downloader`, `ROTATIONS`, `EventBuffer`, `ignore_tables`, `default_charset`, `default_headers`, `tld_length` | Gem hits were the gems' own names, or gems that write a still-present API (`SchemaDumper.ignore_tables` is still a class accessor) |

## Leads not built yet

- **`Rails::BacktraceCleaner::APP_DIRS_PATTERN`**, removed in #56333. Foreman's `config/initializers/backtrace_silencers.rb` matches backtrace lines with this constant, and code search finds about 700 hits, many of them sentry-ruby's own constant. The class is `:nodoc:`, and the PR replaced the allow-list with an exclusion. Restoring the old regexp would satisfy Foreman, but would bring back a list of directories that Rails itself no longer uses. This is the next candidate if Sol thinks it is worth it.
- **`ActiveModel::Validations::NumericalityValidator#validate_each`** lost its `precision:`/`scale:` keywords in #59246. Overrides in subclasses still work: money-rails takes three arguments and calls `super` without keywords. It would only break a caller that passes the keywords; none was found.
- **`SpawnMethods#merge(other, *rest)` → `merge(other)`** (`79b6a77d3e`, "Remove unused parameter"). A second argument raised a deprecation in 7.1 and was ignored from 7.2 on. On main it raises `ArgumentError`. No caller was found.
