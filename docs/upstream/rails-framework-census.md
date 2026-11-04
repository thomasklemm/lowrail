# Rails framework census (bet R2): Active Support, Action Pack, Action View and friends

Censuses 3–5 ranked every Rails line together, so Active Record dominated and the code every request or job runs in
the other frameworks (rendering, helpers, callbacks, instrumentation, middleware, params, routing, cookies/session,
Active Job, Action Mailer) was drowned out. This round reruns [`script/census`](census.md) on canonical Rails main,
ranks only `actionview/`, `actionpack/`, `activesupport/`, `activejob/`, `actionmailer/`, `railties/` and
`activemodel/` lines, separately per framework, and adds a call-count probe for per-request work that does not
allocate (method_missing, respond_to?, callback compilation, Hash merges).

**Result: two broad, exact candidates, both in Active Support, both under every request of almost every app.**

| # | Branch | Commit | Common pattern | Per call | Workloads moved (A/A 26 / 27) | Median per workload |
| --- | --- | --- | --- | ---: | ---: | ---: |
| R2-1 | [`thomasklemm/thread-mattr-key-literal`](https://github.com/thomasklemm/rails/tree/thomasklemm/thread-mattr-key-literal) | [`e367362490`](https://github.com/thomasklemm/rails/commit/e3673624906dd601fb747fc5f7a96813ecfee528) | every `thread_mattr_accessor` read/write: Turbo's per-request `Turbo.with_request_id`, Action Text's per-request renderer, query log tags per query | −2 objects; reader 364 → 198 ns (interp), 299 → 109 ns (YJIT) | 83 / 85 of 97 | −10.8 / −10.0 |
| R2-2 | [`thomasklemm/subscriber-event-method-names`](https://github.com/thomasklemm/rails/tree/thomasklemm/subscriber-event-method-names) | [`963c79fd75`](https://github.com/thomasklemm/rails/commit/963c79fd7575d31ec3e66b3bafeb0458925d1164) | every event delivered to a log subscriber or structured event subscriber (`ActiveSupport::Subscriber#call`) | −1 String; 424 → 217 ns (interp), 242 → 87 ns (YJIT) | 75 / 76 of 97 | −3.3 / −4.0 |

Interpreter / YJIT, Ruby 4.0.7. Allocation counts only; no request-time claim. Per-call times are micro timings.

Two more exact branches are **held, not recommended**: R2-3 (merge URL defaults in one pass) because its breadth in
the census is mostly an artifact of the harness setting route-set `default_url_options` in every app, and R2-4
(`OutputBuffer#capture` anonymous rest) because it saves nothing under YJIT on Ruby 4.0 until ruby/ruby#19655 lands.
Everything else ranked is required output, already covered by an open PR, or rejected below with the reason.

## Pins and method

* **Rails:** canonical `rails/rails` main [`5810776eec`](https://github.com/rails/rails/commit/5810776eecc5b2e50b58e81ee0c26c02c718fdf0)
  (merge of #59544), checked with `gh api repos/rails/rails/commits/main` on 2026-11-03 01:00 UTC. It is census 5's
  pin: nothing was merged to main after #59544 by then. All branches are one commit on it.
* **Ruby 4.0.7**, interpreter and `--yjit`; production, `RAILS_LOG_LEVEL=fatal`; services as disposable orb services
  (Redis, memcached, MySQL 8.4.10 on 3307, PostgreSQL 15).
* **Apps:** the ten configurations of `script/census` (Blog, Campfire, Writebook, Fizzy on SQLite and MySQL,
  CodeTriage, PingCRM, Redprints CFP, React starter kit, Lobsters), set up from scratch with
  `script/census setup --rails 5810776eec…`; all 97 workloads pass `list`.
* **Runs:** `script/census run --label base --aa --modes interp,yjit --jobs 10`, then one label per branch.
  Candidates are compared with `base2`; `compare --aa base` gives the noise floor.
* **New tooling (this round):**
  * [`bench/upstream/framework_census/rank.rb`](../../bench/upstream/framework_census/rank.rb): census ranking
    restricted to the seven frameworks, overall and per framework, keeping each line's overall rank.
  * [`bench/upstream/framework_census/probe.rb`](../../bench/upstream/framework_census/probe.rb) and
    [`script/framework-probe`](../../script/framework-probe): the census boot and workloads, then per workload after
    the 50 warmups, 5 traced operations counting calls of every Rails-defined method, `method_missing` calls by
    owner and caller line, Hash/Array/`respond_to?`/`send` C calls made from Rails lines, and
    `CallbackChain#compile`; `callers` mode prints caller locations of given methods.
    [`probe_rank.rb`](../../bench/upstream/framework_census/probe_rank.rb) ranks those counts breadth first like
    the allocation ranking.
  * Micros (`micro_*.rb`) and behavior controls
    ([`controls.rb`](../../bench/upstream/framework_census/controls.rb)) in the same directory.
* **Process note.** A first run of the thread-mattr and capture labels failed for Fizzy and Lobsters because a caller
  probe ran in those app copies while the census measured them (shared database). Both labels were discarded and rerun
  after a state control (`base3` on the four touched configurations: median +0.0 / +0.0, Lobsters' usual ±35–65
  object swing on three pages, the same as in the A/A). No probe ran while a census label was measuring after that.
  `origin/main` of this repository gained the PG census during the round; switching to it mid-queue made the first
  #58957 runs fail on its new app list (rerun with `--apps` naming the ten configurations). Its harness changes are
  env-gated and leave the nine apps' workloads unchanged; R2-2's YJIT pass ran with them.

### A/A

`base2 − base`: median +0.0 / −0.0; 26 / 27 workloads moved ≤ −1 and 17 / 17 moved ≥ +1 (interpreter / YJIT); SQL
changed for 6 / 4 workloads. Census 5's A/A moved 17 / 18 and 24 / 23. PingCRM's interpreter process shifts by about
−4 objects per workload between runs (7 of 8 moved in the A/A), so PingCRM interpreter cells below carry that shift.

## Ranking by framework

Lines are ranked as in the census: a line reaches a workload at ≥ 0.5 objects/op; tiers by apps reached (≥ 7, 5–6,
3–4, 2, 1); within a tier by mean objects per operation over all 97 workloads. Interpreter shown; the YJIT top 60
contains the same sites in the same order. "Rank" is the line's rank among all Rails lines (Active Record included).

### Active Support (317 lines, 87 reach ≥ 7 apps)

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 1, 5 | `output_safety.rb:245/73` SafeBuffers | 9 / 60% | 75.3, 37.3 | Output. Required. |
| 2 | `enumerable.rb:87` `index_with` | 9 / 93% | 70.9 | Open #59555 / #59557 (index_with on Ruby 4.1, separate thread). |
| 7, 14 | `time/calculations.rb:173/168` Rationals in `Time#change` | 9 / 53–56% | 36.6, 24.7 | From `apply_seconds_precision` (Active Model datetime cast) and `Time#advance` (`1.day.ago`). Building the fraction as one `Rational(nsec, 10**9)` instead of `Rational(Rational(nsec, 1000), 10**6)` is exact but saves 1 of 15 objects (`Integer + Rational` itself allocates 3). Rejected. |
| 10, 20, 21, 38–41 | `notifications/fanout.rb` groups, handles, events | 9 / 97–98% | 13–29 | Recently trimmed (#59095, #59238). What remains is per delivered event for subscribers that are listening. Required while subscribed; #58957 reduces the subscribers. |
| 22 | `hash/keys.rb:13` `stringify_keys` | 9 / 81% | 18.1 | Mostly asset tag helpers' option copies, mutated afterwards (census 4). Required. |
| **36** | `subscriber.rb:142` `event.name[0, index(".")]` | 9 / 97% | 13.8 | **R2-2.** All from `StructuredEventSubscriber#call` (and `LogSubscriber#call`) through `Subscriber#call`: 609 calls over Fizzy's 14 workloads, 107 on its board page. |
| 43 | `date_and_time/zones.rb:38` TimeWithZone | 9 / 71% | 13.0 | Result objects. Required. |
| 44 | `deep_dup.rb:18` | 7 / 70% | 12.7 | Sentry breadcrumbs, app payloads. Not Rails' own work. |
| 47, 48 | `event_reporter.rb:432/434` | 9 / 58% | 12.1 | Covered by open #58957 (as census 5). |
| 54 | `callbacks.rb:105` `Filters::Environment` | 9 / 100% | 11.2 | One per `run_callbacks` with callbacks; carries halting state. Required. |
| **57, 120** | `attribute_accessors_per_thread.rb:59/123` key Strings | 8 / 87%, 78% | 10.4, 5.2 | **R2-1.** Callers: `turbo-rails.rb:23/26` (`Turbo.with_request_id`, every request), `action_text/rendering.rb:20–24` (every request with Action Text), `query_logs.rb:217/286` (every query with query log tags; 204 reads over Lobsters' 11 workloads). |
| 68, 85 | `hash/keys.rb:32` `symbolize_keys`, `hash/slice.rb:29` `extract!` | 9 / 53%, 8 / 45% | 9.0, 7.0 | `stylesheet_link_tag`/`javascript_include_tag` path options (`extract!(…).symbolize_keys`, usually empty: rest Array + 2 Hashes), `image_tag`, form helpers. Only 1 object is removable exactly; open #59428 rewrites the neighbouring preload-link lines. Lead. |

### Action Pack (305 lines, 126 reach ≥ 7 apps)

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 13 | `http/url.rb:361` `host_with_port` | 9 / 45% | 25.3 | Mostly Campfire's own `inline_script_hashes.rb` (630 calls per request at this pin; once-campfire#374 fixes it; still open on 2026-11-04). Rails' own callers are the CSRF origin check (once per verified request) and `asset_url`. App code. |
| 55, 56 | `http/url.rb:169` path copy, `journey/visitors.rb:38` route buffer | 9 / 66% | 10.9 each | One String for the generated route path and one for `path_for`'s copy (`script_name.to_s.chomp("/") << path`). Removing the copy needs `path_for` to own `options[:path]`, which is public API (`ActionDispatch::Http::URL.path_for`). Lead. |
| **64, 65**, 66 | `routing/route_set.rb:230/233` merges, `:318` params | 9 / 64% | 9.1 each | **R2-3 (held)** for 233; 318 is the params Hash. Required. |
| 129, 199 | `abstract_controller/rendering.rb:64/61` `view_assigns` | 9 / 71–74% | 4.4, 2.1 | One String per ivar is the public key; `instance_variables - _protected_ivars` builds a result Array plus a hidden Hash (`Array#-` hashes more than 16 entries). Iterating with `include?` saves 2 objects per render. Lead (small). |
| 135, 197, 198 | `request_forgery_protection.rb:848/784/852` | 7 / 42% | 4.2, 2.1 | HMAC per masked token (per form). Required; #59106 merged. |
| 154 | `http/headers.rb:124` `env_name` | 9 / 80% | 3.4 | `key.upcase` per header lookup. Required without a cache. |
| 164, 219 | `request_forgery_protection.rb:582/584` Vary | 9 / 56% | 2.9, 1.7 | Open #59500. |
| 167 | `journey/gtg/transition_table.rb:58` | 8 / 49% | 2.8 | Route recognition states; #59160 (reuse arrays) was closed. |
| 203, 210, 216, 222 | `response.rb`, `http/cache.rb:272` | 8–9 / 67–82% | 1.7–2.0 | Per response objects (content type, buffer, headers, cache-control Hash mutated later). Required. |
| — | `middleware/cookies.rb:669`, `message_encryptor.rb`, `messages/rotator.rb`, `key_generator.rb` | 7–9 / 50–75% | 1.3–3.0 | Per-request verifier/encryptor construction: open #59086 (amatsuda) caches them. Excluded. |

### Action View (308 lines, 61 reach ≥ 7 apps)

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 4, 19, 37, 52 | `tag_helper.rb:1545/1540/1751/1605` | 7–9 / 33–55% | 11–45 | Tag and attribute output. Required; open #57999 works on attribute strings. |
| 24, 88–91, 107–110 | `asset_tag_helper.rb:723, 220–254` | 7 / 33% | 5.8–17.8 | Early-hints/Link header output and `stylesheet_link_tag` bookkeeping. Open #59428 (flavorjones) rewrites the preload-link `+=` lines (each `+=` is a new String); path options as in Active Support above. |
| 53 | `asset_url_helper.rb:221` `"#{source}#{tail}"` | 8 / 44% | 11.3 | Returning `source` when there is no tail changes ownership (census 5). Rejected. |
| **87** | `capture_helper.rb:59` | 7 / 39% | 6.9 | **R2-4 (held).** Census 5 could not explain this Array: it is `OutputBuffer#capture(*args)`'s empty rest Array, attributed to the caller's line. |
| 86, 114 | `buffers.rb:75/25` | 7–9 / 39–74% | 7.0, 5.6 | The captured buffer and each template's buffer. Required. |
| 92 | `output_safety_helper.rb:41` `safe_join` | 7 / 36% | 6.8 | `flatten` + joined String. Required. |
| 100 | `template_path.rb:24`, `path_set.rb:74/76` | 9 / 61% | 6.2 | Template lookup names (`"#{prefix}/#{name}"`); #58786 reworked this path. Required without a cache. |
| 130, 131, 132 | `template.rb:338`, `base.rb:317`, `abstract_renderer.rb:183` | 9 / 68–71% | 4.2–4.4 | Output buffer, `"@#{key}"` per assign, RenderedTemplate. `assign`'s String is unavoidable without changing `view_assigns`' String keys. Required. |

### Active Model (97 lines, 25 reach ≥ 7 apps)

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 11, 31, 32, 200 | `attribute_set/builder.rb:20`, `indexed_row.rb` | 9 / 93–96% | 2–28 | Open #59141 (tenderlove, Array-backed attributes). |
| 15 | `type/string.rb:40` | 9 / 91% | 24.1 | Defensive copy. Required. |
| 27, 95, 115 | `attribute.rb:10/14/18` | 8–9 / 46–71% | 5.5–15.3 | Attribute objects. Required. |
| 59, 158 | `attribute_set.rb:225/298` | 9 / 29–42% | 3.3–10.0 | Open #59141 / #58002. |
| 161, 176 | `type/helpers/time_value.rb:68/32` | 7–9 / 27–47% | 2.7–3.0 | Datetime casts; see `Time#change` above. |

### Active Job, Action Mailer, Railties

Nothing in these three reaches more than 6 apps at ≥ 0.5 objects/op except Railties' Rack logger.

* **Active Job (61 lines, none ≥ 7 apps):** top is `queue_adapter.rb:12`, 6 apps, 1.2/op: `ActiveJob.adapter_name`
  builds `"#{name.demodulize.delete_suffix("Adapter")}"`, a redundant interpolated copy, but only for structured
  event payloads (which #58957 skips when nothing consumes them). `instrumentation.rb:34`
  (`"#{operation}.active_job"`, 0.6/op), `enqueuing.rb:58/68`, `queue_name.rb:62` follow. Not worth a PR.
* **Action Mailer (28 lines, none ≥ 7 apps):** `base.rb:1015/959/642`, ≤ 0.22/op over 4 apps. Mail rendering
  allocations are in the `mail` gem (see the mikel/mail#1693 review).
* **Railties (8 lines, 7 reach ≥ 7 apps):** `rails/rack/logger.rb:22–84` and `engine.rb:852`, ≤ 0.8/op: the request
  object, tag Arrays and BodyProxy per request. `BroadcastLogger` has no `push_tags`/`pop_tags`/`flush`, so the
  three calls per request go through `method_missing`, which builds a `select` Array each time (3 objects per
  request, 8 apps). Defining the methods would change `respond_to?` when no broadcast logger supports tags. Lead
  (small).

## Per-request work that is not allocation

From the call-count probe (5 traced operations per workload after warmup), breadth first:

* **Callback chain compilation is not repeated.** `CallbackChain#compile` is called once per `run_callbacks`
  (11.2 per operation in all 97 workloads, the same as `Filters::Environment`) and always returns the memoized
  sequence: neither `compile_sequence` nor `CallbackSequence#initialize` ran after warmup in any app or mode.
* **`OrderedOptions#method_missing`, 39 calls per operation, 9 apps.** 22.6 per operation come from
  `asset_url_helper.rb:212/284` (`defined?(config.relative_url_root) && config.relative_url_root` and
  `config.asset_host if defined? config.asset_host`, once each per `asset_path`), 12 from the CSRF settings that
  `request_forgery_protection.rb` delegates to `config` (`allow_forgery_protection`,
  `forgery_protection_verification_strategy`, …), the rest from `abstract_controller/caching.rb`. A config read
  through `method_missing` costs ~235 ns more than `config[:key]` in the interpreter and ~170 ns under YJIT, and
  `defined?` adds a `respond_to?` call. Replacing them with `config[:key]` is not exact for objects whose `config`
  is not an `OrderedOptions`, and the total (~5–9 µs per page) is below the 0.1% bar. Lead.
* **`respond_to?` on the view, 51 per operation, 9 apps.** `ControllerHelper#respond_to?` checks
  `CONTROLLER_DELEGATES.include?(name.to_sym)` (a 10-element Array) before `super`, for every `respond_to?` on a view
  (asset helpers' `respond_to?(:request)`, `url_for`). Cheap per call; not pursued.
* **`Hash#merge` from Rails lines:** `route_set.rb:230/233` (9.1 each per operation, R2-3),
  `lookup_context.rb:213` (2.0, `detail_args_for` with options), `reverse_merge.rb:19` (1.9; Action Text
  `content.rb:40`, query logs).
* **`ActiveSupport::Ractors.[]`, 147 per operation:** Active Record's schema context and reflection lookups, outside
  this round's frameworks. Lead for an Active Record round.

## Candidates

### R2-1: `thread_mattr_accessor` keys as frozen literals

The generated reader and writer built `"attr_#{sym}_#{object_id}"` on every call: two Strings (the Integer's
`to_s` and the interpolation). For the module that defines the attribute the key never changes, so the generated
method now compares `object_id` with the definer's and uses a frozen literal; subclasses (which keep their own values)
still build their key. `"…".freeze` in the generated source compiles to a frozen literal, so no String is built, and
`Hash#[]=` stores a frozen key without copying it.

```diff
       # The following generated method concatenates `object_id` because we want
-      # subclasses to maintain independent values.
+      # subclasses to maintain independent values. The key for this module is
+      # a frozen literal, so reading or writing it doesn't build a String.
+      key = "attr_#{sym}_#{object_id}"
       if default.nil?
         class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
           def self.#{sym}
-            key = "attr_#{sym}_\#{object_id}"
+            key = object_id == #{object_id} ? "#{key}".freeze : "attr_#{sym}_\#{object_id}"
             ::ActiveSupport::IsolatedExecutionState[key]
```

(The same line changes in the reader with a default and in the writer.)

**Per-call micro** ([`micro_thread_mattr.rb`](../../bench/upstream/framework_census/micro_thread_mattr.rb)), objects
and ns per call, interpreter / YJIT:

| Call | Objects, main → branch | ns interpreter, main → branch | ns YJIT, main → branch |
| --- | ---: | ---: | ---: |
| `Current.request_id` (reader) | 2 → **0** | 364 → **198** | 299 → **109** |
| `Current.request_id = "a"` (writer) | 2 → **0** | 405 → **222** | 332 → **127** |
| reader with `default:` | 2 → **0** | 373 → **197** | 274 → **109** |
| `Current.new.request_id` (instance reader) | 3 → **1** | 462 → **294** | 318 → **150** |
| `SubCurrent.request_id` (subclass, control) | 2 → 2 | 396 → 402 | 293 → 291 |
| `SubCurrent.request_id = "b"` (subclass, control) | 2 → 2 | 416 → 452 | 321 → 338 |

Best of three runs of 2,000,000 calls on an idle orb; the instance reader's remaining object is the micro's
`Current.new`.

**Apps** (median objects per workload, branch − `base2`):

| App | A/A | R2-1 thread-mattr | R2-2 subscriber | R2-3 URL merge (held) | R2-4 capture (held) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Blog | +0.0 / +0.0 | −11.9 / −12.0 | −2.0 / −1.6 | −3.0 / −2.2 | +0.0 / +0.3 |
| Campfire | +0.0 / +0.0 | −12.0 / −12.0 | −2.0 / −2.8 | −1.0 / +0.0 | +0.0 / +0.0 |
| CodeTriage (PG) | +0.8 / −7.2 | −7.1 / −3.1 | −23.1 / −16.6 | −10.3 / −6.1 | −2.3 / −0.0 |
| Fizzy (SQLite) | +0.0 / +0.0 | −14.0 / −10.0 | −23.0 / −29.0 | −0.1 / +0.0 | +0.0 / +0.0 |
| Fizzy (MySQL) | +0.0 / +0.0 | −14.0 / −14.0 | −29.0 / −29.0 | +0.0 / +0.0 | −1.0 / +1.0 |
| Lobsters | −0.4 / +0.0 | −40.7 / −41.1 | −0.8 / −2.0 | −24.3 / −20.6 | −2.1 / +0.0 |
| PingCRM (PG) | −4.3 / +0.4 | +5.6 / −3.8 | +1.8 / −2.5 | +5.8 / +0.3 | +1.0 / −3.6 |
| React starter kit | +0.7 / −0.6 | −6.1 / −5.0 | −2.9 / −0.7 | +1.3 / +0.1 | +0.1 / +0.8 |
| Redprints CFP | +0.1 / +0.3 | −8.5 / −8.4 | −2.8 / −1.3 | +0.1 / −0.6 | −1.3 / +0.8 |
| Writebook | +0.0 / +0.0 | −10.5 / −11.0 | −3.0 / −1.0 | −1.9 / +0.0 | −3.7 / +1.1 |
| **All 97 workloads** | **+0.0 / +0.0** | **−10.8 / −10.0** | **−3.3 / −4.0** | **−1.0 / −1.1** | **−0.2 / +0.0** |
| Moved ≤ −1 / ≥ +1 | 26 / 17 · 27 / 17 | 83 / 8 · 85 / 5 | 75 / 14 · 76 / 8 | 52 / 17 · 54 / 17 | 46 / 15 · 24 / 28 |

Interpreter / YJIT. PingCRM's interpreter `base2` sits about 4–5 objects below `base`, so its interpreter cells
carry that process shift.

Campfire's room page saves exactly 12: four writes and two reads of two Strings each
(`attribute_accessors_per_thread.rb:123` −8, `:59` −4); Lobsters saves ~41 per request through query log tags.

**Exactness and boundaries.** Same keys, same values, same per-class and per-thread/fiber isolation. The literal is
used only when `object_id` equals the definer's, so subclasses, `dup`/`clone` of the module and anything else that
inherits the singleton method still build their own key. A frozen literal is Ractor-shareable, as #58108 needs.
**Boundary:** none observable; a class that overrides `object_id` gets the same key as before because the comparison
and the fallback both call it.

### R2-2: `Subscriber#call` without slicing the event name

`ActiveSupport::Subscriber#call` sliced the event name up to the first dot to find the handler (a new String per
event, then a String-to-Symbol lookup in `send`). `attach_to` knows the handler of each pattern it subscribes, so it
now records it in the subscriber's `@event_methods` ivar (no new method) and `detach_from` removes it. The recorded
name is taken from the pattern with the same first-dot rule as the slice. `call` looks the event name up there and
falls back to the slice for events from other subscriptions (a subscriber instance subscribed to a Regexp by hand).

**Codex review of `48d7ea10bf` (request changes, two P2s, both confirmed by failing tests):** the first version added
a public `event_methods` reader, which collided with a handler named `event_methods` (`attach_to` raised
ArgumentError, and that handler stopped receiving its events), and it recorded the full method name, so a handler
named `"open.party"` received `open.party.doodle`, which main sends to `open`. Amended to
[`661a404f18`](https://github.com/thomasklemm/rails/commit/661a404f18ea00719215ddb018ce13e636a76b2d): an ivar
written through `instance_variable_get(:@event_methods)&.store` (custom subscriber objects passed to `attach_to`
without the ivar keep working), the name derived from the pattern before its first dot, and two regression tests in
`subscriber_test.rb` that fail on `48d7ea10bf` and pass on main and `661a404f18`. Micro re-measured on the amended
commit: `Subscriber#call` 1 → 0 objects, 405 → 219 ns (interp), 237 → 93 ns (YJIT). The census was not rerun; the
dispatch path for attached events is the same Hash lookup.

**Second Codex re-review of `661a404f18` (request changes, one P2, confirmed):** the cache insert assumed
`prepare_pattern` returns a String. A subclass that overrides it to return a Regexp (the notifier accepts one)
attaches and dispatches on main, but `attach_to` raised NoMethodError (`Regexp#index`) on `661a404f18`. Amended to
[`963c79fd75`](https://github.com/thomasklemm/rails/commit/963c79fd7575d31ec3e66b3bafeb0458925d1164): only String
patterns with a dot are cached; everything else, Regexp subscriptions included, keeps main's slice in `#call`, and
detach deletes the (absent) cache entry as a no-op. A third test (attach, deliver, detach with a Regexp pattern) fails
on `661a404f18` and passes on main and `963c79fd75`. Micro on `963c79fd75`: 0 objects, 229 ns (interp), 92 ns
(YJIT); the Regexp control still 1 object. Active Support suite 6,871 runs (+3 tests), 0 F, 0 E, 60 skips; RuboCop
clean. The other suites were last run on `661a404f18`; the new change only affects `attach_to` for non-String
patterns.

```diff
     def call(event)
-      method = event.name[0, event.name.index(".")]
-      send(method, event)
+      name = event.name
+      send(@event_methods[name] || name[0, name.index(".")], event)
     end
```

**Per-call micro** ([`micro_subscriber.rb`](../../bench/upstream/framework_census/micro_subscriber.rb)):

| Call | Objects, main → branch | ns interpreter, main → branch | ns YJIT, main → branch |
| --- | ---: | ---: | ---: |
| `Subscriber#call(event)` (attached via `attach_to`) | 1 → **0** | 424 → **217** | 242 → **87** |
| `ActiveSupport::Notifications.instrument("render_template.bench") { }` | 7 → **6** | 5,346 → 4,986 | 2,692 → 2,509 |
| `Subscriber#call` from a Regexp subscription (control) | 1 → 1 | 431 → 444 | 286 → 251 |

The handler itself allocates nothing; the remaining object in the control is the slice. The `instrument` timings
include the whole notification and are within noise.

**Apps:** see the per-app table under R2-1 (R2-2 column). Fizzy's board page delivers 107 such events per request (−107
objects); CodeTriage −23 / −17 per workload.

**Overlap with open #58957** ("Skip structured event handlers whose event nobody consumes"): that PR silences
structured event handlers whose event no event reporter subscriber consumes, so `Subscriber#call` is not reached for
them at all.

| | Median per workload | Moved ≤ −1 / ≥ +1 |
| --- | ---: | ---: |
| #58957 alone vs `base2` | −16.6 / −16.1 | 87 / 8 · 87 / 7 |
| R2-2 vs `base2` | −3.3 / −4.0 | 75 / 14 · 76 / 8 |
| R2-2 on top of #58957 vs #58957 | −2.0 / −1.0 | 54 / 14 · 49 / 18 |

On top of #58957, R2-2 still saves in the apps whose structured events are consumed: Fizzy −27 / −27 (MySQL −20),
whose `config/application.rb` sets `Rails.event.debug_mode = true` (its board page still −105), and CodeTriage
−9 / −15. Blog, Campfire, Lobsters and the Inertia apps go flat, because #58957 skips their handlers entirely. Both
changes apply together (the combined branch is a clean cherry-pick); R2-2 also covers `LogSubscriber`s, which #58957
does not touch.

**Exactness and boundaries.** Same handler for every subscribed pattern: the recorded name is the pattern's prefix
before its first dot, which is what the slice computes for that event name (a dotted handler name such as
`"open.party"` still dispatches to `open`, as on main); same `method_added` and `detach_from` behavior; other
subscriptions take the old path. **Boundary:** a subclass that defines its own `@event_methods` ivar would collide with the new one.

### Behavior controls and suites

[`controls.rb`](../../bench/upstream/framework_census/controls.rb) prints 35 lines of observable results:
`thread_mattr_accessor` values per class, subclass, other class and module, defaults (frozen, `nil` override),
instance accessors, reader-/writer-only, another thread, fiber isolation, the state keys (object ids mapped back to
class names) and their frozenness, an invalid name; Subscriber dispatch for attached, dotted-namespace, LogSubscriber,
private, `method_added`, Regexp-subscribed (`sql.manual`, `sql.manual.extra`), detach and re-attach; 75 URL
generations over five route-set default sets × three `url_options` (host, port, script_name, trailing slash,
anchor, `only_path`, route defaults, optional scope, inner host/anchor, missing argument, `original_script_name`);
`capture`, nested capture, `content_for`, block tags, `OutputBuffer#capture` with arguments and with a raise.
Run with `script/census controls --script … base2 base threadmattr subscriber urlmerge capture`: **identical to base2
for every label in both modes.** Negative controls: dropping the subclass check (R2-1), the slice fallback (R2-2)
or merging the URL defaults after `url_options` (R2-3) changes 5, 22 and 5 lines.

SQL control: changed SQL on 5 / 5 (R2-1), 5 / 5 (R2-2), 5 / 4 (R2-3), 8 / 7 (R2-4) workloads, within the A/A's 6 / 4
(the same Lobsters/Fizzy write workloads).

Local suites, Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, `bundle exec rake test` in the framework:

| Suite | main `5810776eec` | R2-1 thread-mattr | R2-2 subscriber | R2-3 URL merge | R2-4 capture |
| --- | --- | --- | --- | --- | --- |
| Active Support | 6,868 runs, 0 F, 0 E, 60 skips | same | 6,871 runs (+3 new tests), 0 F, 0 E, 60 skips | — | — |
| Action Pack | 4,472 runs, 0 F, 0 E, 0 skips | same | same | same | — |
| Action View (3 groups) | 2,913 + 251 + 177 runs, 0 F, 0 E | same | same | — | same |
| Active Job (7 adapter groups) | 2,145 runs, 0 F, 0 E | same | same | — | — |
| Action Text | 373 runs, 0 F, 1 E | same | same | — | — |
| Active Record `query_logs_test`, `log_subscriber_test`, `structured_event_subscriber_test` (`ARCONN=sqlite3`) | 93 runs, 0 F, 0 E | same | same | — | — |

"Same" means identical run, assertion, failure, error and skip counts. R2-2's column is the amended `661a404f18` (Active Support: `963c79fd75`), except
Action Text, which was run on `48d7ea10bf` only. The one Action Text error is
`yarn` missing from this orb (a JS build step), on main as on the branches. Action Pack, Action View, Active Job,
Action Text and the Active Record tests were run for R2-1 and R2-2 because their changes are exercised there
(Action Text's renderer and query log tags use per-thread accessors; every log and structured event subscriber goes
through `Subscriber#call`).

RuboCop on each changed file: no offenses (R2-2 needed `@patterns  = {}` → `@patterns = {}` once its aligned
neighbour changed).

## PR description drafts (not published)

Pattern first, then the change, a compact table and the boundary, per [DECISIONS](../DECISIONS.md) (rails/rails
descriptions may be somewhat fuller than ruby/ruby's).

**R2-1 — Don't build the key String on every `thread_mattr_accessor` call**

> ### Motivation / Background
>
> `thread_mattr_accessor` (and `thread_cattr_*`) generates class methods that look the value up in
> `IsolatedExecutionState` under `"attr_#{name}_#{object_id}"`, and they build that key on every read and every
> write: two Strings per call. These accessors are on the request path in most apps: Turbo wraps every request in
> `Turbo.with_request_id`, Action Text sets its renderer around every request, and query log tags read their cached
> comment on every query.
>
> ### Detail
>
> For the module that defines the attribute the key never changes, so the generated methods now use it as a frozen
> literal. Subclasses keep their own values, so they still build their key (the method compares `object_id` with
> the definer's).
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | reader (`Current.request_id`) | 2 objects, 364 / 299 ns | 0 objects, 198 / 109 ns |
> | writer | 2 objects, 405 / 332 ns | 0 objects, 222 / 127 ns |
> | subclass reader (unchanged path) | 2 objects | 2 objects |
>
> Interpreter / YJIT, Ruby 4.0.7. Across nine open-source apps on Rails main, 83 of 97 request, job and mailer
> workloads allocate fewer objects (median −11 per request; −41 on Lobsters, which has query log tags on).
>
> Keys, values and per-thread/fiber isolation are unchanged; the literal is frozen, so it stays shareable for the
> Ractor support from #58108.

**R2-2 — Don't slice the event name on every `ActiveSupport::Subscriber#call`**

> ### Motivation / Background
>
> Log subscribers and structured event subscribers are `ActiveSupport::Subscriber`s. `Subscriber#call` finds the
> handler of each event by slicing the event name up to its first dot (`"render_template.action_view"` →
> `"render_template"`), a new String for every event delivered, which `send` then looks up as a Symbol. A page that
> renders a hundred partials delivers a hundred such events to each consuming subscriber.
>
> ### Detail
>
> `attach_to` knows the handler of each pattern it subscribes, so the subscriber now records it in an instance
> variable next to `@patterns` (taken from the pattern with the same first-dot rule), and `detach_from` removes it.
> No method is added, so handler names are unaffected. `call` looks the event name up there and keeps the slice for
> events from other subscriptions, such as a subscriber instance subscribed to a Regexp.
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | `Subscriber#call` | 1 object, 424 / 242 ns | 0 objects, 217 / 87 ns |
> | `instrument` delivering to one subscriber | 7 objects | 6 objects |
>
> Interpreter / YJIT, Ruby 4.0.7. Across nine apps, 75 of 97 workloads allocate fewer objects (median −3; Fizzy,
> which enables `Rails.event.debug_mode`, −23 to −29, its board page −107).
>
> This complements #58957, which skips structured handlers whose events nobody consumes: with both, apps whose
> events are consumed (and every `LogSubscriber`) still save one String per event.

## Held, rejected and excluded

* **R2-3, merge URL defaults in one pass — held.** Branch
  [`thomasklemm/url-helper-merge-defaults-once`](https://github.com/thomasklemm/rails/tree/thomasklemm/url-helper-merge-defaults-once)
  ([`299787dabb`](https://github.com/thomasklemm/rails/commit/299787dabbd5c18f21bcc3740f08f2c854d2148e)). When the
  route set has `default_url_options`, `OptimizedUrlHelper#call` built `url_options.merge(@options)` and then
  `defaults.merge(that)`; `defaults.merge(url_options, @options)` builds one Hash with the same keys, values and order
  (evaluation order kept). Micro: −1 Hash per optimized helper call with route-set defaults (`post_comment_url`
  13 → 12), unchanged without; all 15 generated URLs identical. Census: 52 / 54 moved, median −1.0 / −1.1
  (Lobsters −24 / −21). **Why held:** the harness sets route-set `default_url_options` in every app; of the nine,
  only Fizzy sets them itself, and Fizzy's median is 0. **Boundary:** a `url_options` that is a
  `HashWithIndifferentAccess` would now keep the route's option keys as Symbols. Action Pack suite 4,472 runs,
  0 failures (as main); controls identical.
* **R2-4, anonymous rest in `OutputBuffer#capture` — held.** Branch
  [`thomasklemm/output-buffer-capture-anonymous-rest`](https://github.com/thomasklemm/rails/tree/thomasklemm/output-buffer-capture-anonymous-rest)
  ([`bafe198616`](https://github.com/thomasklemm/rails/commit/bafe19861606a78af65f1199da3fd539556e88e9)).
  `def capture(*args) … yield(*args)` → `def capture(*) … yield(*)`. Every capture (`capture`, `content_for`, block
  `tag.*`/`content_tag`, form builders) allocated an empty rest Array; with an anonymous rest the interpreter passes
  its shared frozen empty Array (`tag.div { }` 8 → 7, `content_for` 7 → 6). This is census 5's unexplained
  `capture_helper.rb:59` Array (allocated on the callee's entry, attributed to the caller's line). **Why held:**
  YJIT on Ruby 4.0 allocates the anonymous rest itself, so YJIT saves nothing (24 moved vs A/A 27); the interpreter
  moves 46 workloads at median −0.2. It becomes a YJIT saving only with our open ruby/ruby#19655. Action View suite
  as main; controls identical.
* **`Time#change` Rationals (AS ranks 7, 14):** exact one-Rational fraction saves 1 of 15 objects per change.
  Rejected.
* **`OrderedOptions#method_missing` in asset helpers and CSRF settings:** `config[:key]` is not exact for a `config`
  that is not an `OrderedOptions`; ~5–9 µs per page. Rejected for now (lead below).
* **`stylesheet_link_tag` / `javascript_include_tag` preload-link `+=`:** open #59428 rewrites these lines. Excluded.
* **Path options `extract!(…).symbolize_keys`:** only the `symbolize_keys` copy (1 of 3 objects) is removable without
  changing the class of the Hash for `HashWithIndifferentAccess` options. Not worth a PR.
* **`ActiveJob.adapter_name` redundant interpolation:** 1 String per structured Active Job event, 6 apps, 1.2/op.
  Not worth a PR.
* **Covered by open PRs:** cookie verifiers/encryptors and key generator (#59086), Vary (#59500), structured events
  and `EventReporter#notify` (#58957), attribute sets and indexed rows (#59141, #58002), tag attribute strings
  (#57999), preload links (#59428), `index_with` (#59555, #59557).
* **Required work:** SafeBuffers and tag output, Notifications events for listening subscribers,
  `Filters::Environment`, TimeWithZone results, template lookup names, response objects, CSRF HMACs, header names.
* **App and gem code:** `url.rb:361` `host_with_port` (rank 13) is mostly Campfire's `inline_script_hashes.rb` at
  this pin (630 calls per request; once-campfire#374 fixes it; still open on 2026-11-04); Rails' own callers are the CSRF origin check
  (once per verified request) and `asset_url`. `deep_dup.rb:18` is Sentry breadcrumbs.

## Leads

Second pass (after #59561 and #59562 were opened), against the same bar: at least 7 apps, exact, a census delta
against the A/A, no overlap with open PRs. **None clears it.**

* **`view_assigns`** (`instance_variables - _protected_ivars`, 9 apps): tried as
  [`wip/view-assigns-without-subtraction`](https://github.com/thomasklemm/rails/tree/wip/view-assigns-without-subtraction)
  ([`aa4c92d413`](https://github.com/thomasklemm/rails/commit/aa4c92d41310a6d03962229293501d2ff5399d76)): skip
  protected names with `include?` while building the assigns instead of subtracting first. Exact (same keys, order
  and values; Symbol `==` and `eql?` agree). Census label `viewassigns`: 60 / 51 of 97 workloads moved ≤ −1 (A/A
  26 / 27), median −2.0 / −1.0; controls identical in both modes; Action Pack 4,472, Action Mailer 286, Action View
  2,913 + 251 + 177 runs, 0 F / 0 E (as main); RuboCop clean. **Rejected:** with a realistic controller (22 ivars,
  24 protected names; [`micro_view_assigns.rb`](../../bench/upstream/framework_census/micro_view_assigns.rb)) it
  saves 2 objects (10 → 8) but costs about 1 µs per render: 4,853 → 5,891 ns (interp), 4,266 → 4,975 ns (YJIT),
  because each ivar scans the protected Array. #38769 (merged 2020) chose the subtraction for exactly that speed;
  making the lookup cheap needs a Set or Hash of protected names, which changes the overridable `_protected_ivars`.
* **Generated URL path copy** (`url.rb:169` + `visitors.rb:38`, 9 apps, 10.9/op each): `path_for` must return a
  String distinct from `options[:path]`, so any saving needs the route set to signal that it owns the buffer (an
  internal option or a second `path_for`/`url_for` chain); `ActionDispatch::Http::URL.path_for` and `url_for` are
  public. Not exact without that design change. Not pursued; a maintainer question rather than a PR.
* **`BroadcastLogger#method_missing`** (8 apps, 3 Arrays per request): overlaps open #56650, which rewrites
  `method_missing` (block dispatch), and #53105 (tagged logging on `BroadcastLogger`). Excluded.
* **Config reads through `method_missing`** (39 calls/op, ~5–9 µs per page): `config[:key]` or a real reader is not
  exact for `config` objects that are not `OrderedOptions`. Rejected as before.
* **`ActiveSupport::Ractors.[]`** (147 calls/op): a one-line delegation to `Ractor.current[key]` with no allocation;
  removing the indirection would bypass the non-Ractor fallback the module exists for, for ~30 ns a call. Rejected.
* **R2-4** after ruby/ruby#19655.

## Limits

* Allocation counts from one process per app and mode; judged by the distribution against the A/A, not single cells.
* Local suites only; no hosted CI. The micro timings are from one orb, best of three, and support only per-call
  claims, not request time.
* The census harness sets route-set `default_url_options` and Action Mailer URL options in every app (shared
  control), which inflates R2-3's breadth (only Fizzy sets route-set defaults itself).
* Receipts: [data/rails-framework-census/receipts.tar.gz](data/rails-framework-census/receipts.tar.gz) holds the
  framework rankings (both modes), probe rankings, every compare output (`--detail`), the per-app table, micro,
  control and suite outputs, and each run's JSON trimmed to the top 200 sites per workload.
