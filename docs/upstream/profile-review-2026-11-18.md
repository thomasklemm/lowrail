# Lowrail profiling tooling: Thermos review, 2026-11-18

**Verdict: changes requested. Do not offer option B or the recorded-workloads workflow to other people yet.** The happy-path profile tests pass, and the gemspec/off path is passive, but focused probes change application outcomes, delete unrelated output-directory contents, and turn a recorded request format into executable Ruby. Comparison can also return a green CI result without valid comparable measurements.

This is a review, not a fix. No implementation, fixtures, existing documentation or tests were changed.

## Scope and review method

Reviewed `thomasklemm/lowrail` main at `baeaa850a52535849bdc66ea85dad70207bbc5c4`, with scoped base `38e03e5d58a197730a9adbcebc77b9de5ee91f3b` (`60d9c677^`). Read `AGENTS.md` and `docs/PLAN.md`; invariants 1, never change application behavior, and 7, preserve lazy loading, are the admission criteria.

`git log --stat` on the requested paths and related consumers found the named commits `60d9c677`, `738accc6`, `f8a0da28`, `c40618b3`, `baeaa850`, plus `11804786`, the own-app census/YAML predecessor needed for attribution. The scope also includes the initially omitted `profile_report.rb`, `profile_compare.rb`, `profile_workloads.rb`, the deleted `profile_paths.rb`, `gem/lowrail.gemspec`, `load_hooks.rb`, `bench/upstream/census/app.rb`, `app_report.rb`, the harness/client consumers, and the ledger index. No other feature-changing commit was found in that history. Unrelated intervening main commits are not reviewed here.

Thermos ran two independent read-only subagents in parallel, one loading `thermo-nuclear-review`, the other `thermo-nuclear-code-quality-review`. The coordinating reviewer read the implementation/history, ran the requested profile suite and additional adversarial probes, and synthesized the findings. No additional thread was created. Line references below refer to the pinned implementation, not to later fixes.

## Must-fix findings

### F1 — P1: recorded formats become executable Ruby

**Location:** [`workloads.rb:242–249`](../../gem/lib/lowrail/workloads.rb#L242-L249), fed by [`profile.rb:145–147`](../../gem/lib/lowrail/profile.rb#L145-L147). Introduced by `738accc6`.

The renderer interpolates a request's `format` directly into Ruby source, including `format: :#{...}`. This value comes from request path parameters, not just a developer-written route definition. On Rails 8.1.4, a normal `/articles(.:format)` route recognizes the URL-encoded format `html); $profile_review_injected = true; #` unchanged. Rendering and evaluating that recorded shape produced:

```ruby
get articles_path(format: :html); $profile_review_injected = true; #), name: "GET /articles.html); $profile_review_injected = true; #"
```

The harmless marker became `true`; arbitrary Ruby could occupy its place. Generated GETs are enabled, and both A and B evaluate the generated file in the booted app. The unnamed-route branch also interpolates the format into a quoted Ruby string without escaping it.

**Smallest fix:** Serialize every request-derived literal with Ruby-safe quoting (`inspect`; convert the quoted format to a symbol only if needed), or refuse/comment the shape when it cannot be represented safely. Do not interpolate request text as syntax. Add a recorder-to-evaluation regression using an adversarial format and assert that it remains data.

### F2 — P1: recording exports credentials that the app filters

**Locations:** [`profile.rb:141–147`](../../gem/lib/lowrail/profile.rb#L141-L147), [`176–180`](../../gem/lib/lowrail/profile.rb#L176-L180), [`lowrail-profile:110–118`](../../gem/exe/lowrail-profile#L110-L118). Introduced by `738accc6`.

The recorder keeps raw request parameters, removing only top-level `authenticity_token`, and stores raw `ORIGINAL_FULLPATH` query text. A real routed POST with Rails' parameter filter set to `[:password, :api_token]` still exported synthetic password, nested API-token and query-token values. Both the per-process shapes JSON and the generated, potentially tracked `lowrail/workloads.rb` can contain them; commenting a write does not redact it.

**Smallest fix:** Apply the app's parameter filter recursively before retaining or exporting request/query data, use explicit placeholders for filtered values, and never fall back to an unfiltered full path. Warn that recording produces sensitive artifacts and leave any redacted request disabled until made replayable. The probe used synthetic secrets only.

### F3 — P1: `--out` recursively deletes files it does not own

**Location:** [`lowrail-profile:89`](../../gem/exe/lowrail-profile#L89). Introduced by `60d9c677`.

Every profiling invocation calls `FileUtils.rm_rf(out)` before running the command. `--out .`, an app directory, or an existing directory containing anything besides prior captures therefore deletes application files. In an isolated scratch directory, an unrelated `must-keep.txt` disappeared during a successful invocation. This was not tested against any real app data.

**Smallest fix:** Create a fresh capture directory or remove only profiler-owned files in a previously marked profile directory. Refuse an existing unmarked directory; do not recursively clear an arbitrary caller-supplied path.

### F4 — P1: recording breaks successful Action Cable subscriptions

**Location:** [`profile.rb:104–111`](../../gem/lib/lowrail/profile.rb#L104-L111). Introduced into Cable by `c40618b3`; blame follows the copied request cleanup to `738accc6`.

`subscribe_to_channel` calls `Profile.note(env)` from `ensure`, but neither its signature nor Rails 8.1.4's channel base supplies `env`. With recording enabled, the truthy shapes hash makes a successful subscription raise `NameError: undefined local variable or method 'env'`. The same cleanup can replace an application exception. Both independent module probes and inspection of the actual Rails channel API confirm the mismatch.

**Smallest fix:** Remove request-shape recording from this Cable wrapper. Keep recording on request boundaries that actually receive a Rack environment. Check unchanged subscription return values and exception identity with recording enabled.

### F5 — P1: instrumentation failures are not consistently a no-op

**Locations:** [`lowrail-profile:74–86`](../../gem/exe/lowrail-profile#L74-L86), [`profile.rb:35–111`](../../gem/lib/lowrail/profile.rb#L35-L111), [`profile.rb:189–220`](../../gem/lib/lowrail/profile.rb#L189-L220), and the native initialization methods. Cache policy originated in `60d9c677`; `c40618b3` changes the native API and adds the deferred framework wrappers.

The cache is keyed only by Ruby build and refreshed by mtimes, not by profiler source/API identity. Two Lowrail checkouts on the same Ruby can reuse an incompatible extension. A `60d9c677` extension built on Ruby 4.0.9 and placed in an isolated, newer-mtime cache was accepted by the current CLI. Current `Window#call` then raised `ArgumentError: wrong number of arguments (given 1, expected 0)` before the original method; attribution also reported missing `Profile.attribute`. The warning that profiling was off did not undo registered hooks.

The setup-level rescue does not protect future `on_load` callbacks. A real Rails control (`require action_controller/metal; ActionController::Metal.freeze; ActionController::Base`) succeeds plain and raises `FrozenError` with profiling because the deferred hook prepends into the frozen class. Separately, a Ractor-safe original job-shaped method becomes `Ractor::UnsafeError` under the actual job wrapper, because the C methods are not marked Ractor-safe. This does not establish that Active Job itself supports Ractors; it establishes that the instrumentation has no safe refusal boundary there.

**Smallest fix:** Include a digest of the native sources/build inputs in the cache key and validate the native API before registering any callbacks. Contain profiler-only installation/entry/label/cleanup failures at their actual execution boundaries; never wrap `super` in a rescue that would swallow or replay application work. On unsupported Ractors, skip instrumentation and cleanup before calling unsafe native methods. Do not simply mark these process-global native tables Ractor-safe. Add stale-extension, deferred-hook-failure and exception-preservation controls.

### F6 — P1: the documented CI pipeline masks `compare`'s failure

**Location:** [`docs/profile.md:229–230`](../profile.md#L229-L230). Introduced by `c40618b3`.

The example pipes `compare` into `tee` without selecting a pipefail shell. GitHub's unspecified Linux shell is `bash -e {0}`, not explicit `shell: bash`'s pipefail invocation ([GitHub shell reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell)). Executing the regression-producing CLI under those shell options returned 0 through `tee`; explicit Bash with pipefail returned 1. The advertised failing CI gate can therefore stay green for a real regression.

**Smallest fix:** Add `shell: bash` to the Compare step, or explicitly preserve the comparison exit code while appending its output. Test the complete documented pipeline, not only the standalone CLI.

### F7 — P2: `compare` treats missing or unmeasurable evidence as a measured zero

**Locations:** [`profile_compare.rb:27–58`](../../gem/lib/lowrail/profile_compare.rb#L27-L58), [`profile_report.rb:64–77`](../../gem/lib/lowrail/profile_report.rb#L64-L77), [`profile_report.rb:531–539`](../../gem/lib/lowrail/profile_report.rb#L531-L539). Comparison introduced by `c40618b3`; permissive partial-run ingestion dates to `60d9c677`.

Two JSON files containing `{}` exit 0 with no regressions. A measured base compared against `{}` reports improvement to zero and exits 0. Conversely, an action with baseline warm values `[nil, nil]` and head `[100.0, 100.0]` becomes a fabricated +100 regression, despite the documented exclusion of actions without warm measurements. Failed/missing captures, one-run data, dropped samples, and mismatched Ruby/environment/workload cohorts have no validated gate boundary; some needed metadata is discarded before comparison.

Floors also ignore intermediate observations when `--runs` exceeds two: `[10, 1000, 10]` against `[20, 1010, 20]` reports +10 against a floor of 1. This follows the documented first/last formula, but is not a sound floor for the full measured cohort. The default two-run strict `delta > floor` arithmetic itself matches the docs; the action minimum is an empirical Campfire heuristic, not a general confidence bound.

**Smallest fix:** Validate complete, compatible captures and finite values before using a report as a CI gate, with an explicit insufficient-evidence result. Keep absent, unmeasurable and measured-zero states distinct; exclude an action from both sides if either side has no eligible warm value. Require exactly two runs or use the full run range for noise. Preserve diagnostic reports, but do not silently promote them to valid comparisons.

### F8 — P2: native window state has the wrong owner and no thread-exit cleanup

**Locations:** [`lowrail_profile.c:19–25`](../../gem/ext/lowrail_profile/lowrail_profile.c#L19-L25), [`57–61`](../../gem/ext/lowrail_profile/lowrail_profile.c#L57-L61), [`285–294`](../../gem/ext/lowrail_profile/lowrail_profile.c#L285-L294), [`351–370`](../../gem/ext/lowrail_profile/lowrail_profile.c#L351-L370). Introduced by `60d9c677`, extended across kinds by `c40618b3`.

Site reach stores one process-global last window ID. Two deliberately alternating threads with one window each produced 20 String allocations and `windows_reached=20`, despite only two request windows: 1000% reach. An independent four-allocation probe reproduced 200%. This counts transitions, not distinct requests; a mutex would not fix it. Two independent, interleaved fibers, one request and one job, produced windows `[1, 0, 0, 0]`, because native-thread-local depth mistakes the suspended request for the job's parent.

With Ruby 4.0.9's `RUBY_MN_THREADS=1`, two overlapping Ruby threads also collapsed into one request window; without M:N they counted as two. `__thread` tracks OS threads, not Ruby execution contexts.

Attribution's thread-local pending buffers also have no termination cleanup ([`lowrail_profile.c:187–200`](../../gem/ext/lowrail_profile/lowrail_profile.c#L187-L200), [`331–348`](../../gem/ext/lowrail_profile/lowrail_profile.c#L331-L348), introduced by `c40618b3`). On 3,000 sequential short-lived threads, three string allocations per window and full GC afterward, counting-only RSS changed from 13,896 to 14,204 KiB; attribution RSS changed from 13,996 to 50,520 KiB. The C allocation survives after its thread-local pointer disappears, so a long-running server with thread churn grows without bound.

**Smallest fix:** Keep each active window's seen-site set and merge reach once on close. Give nesting and pending buffers an actual execution-context owner with termination cleanup or a bounded reuse pool; either support M:N/independent fibers or explicitly decline their profiling without affecting app work. Keep callback bookkeeping in C without Ruby allocation. Do not solve this by forcing a different scheduler on the application.

### F9 — P2: path-only overrides silently discard JSON bodies

**Location:** [`workloads.rb:74–87`](../../gem/lib/lowrail/workloads.rb#L74-L87). Introduced by `738accc6`.

For `post '/api/a', as: :json, params: { x: 1 }, alternate: [{ path: '/api/b' }]`, the base body is `{"x":1}`, but `at(1)` has body `nil`. `set` erased declaration params after encoding, and `copy` treats the empty transport params as the default declaration. A path-only block has the same problem. Both A and B replay the wrong request.

**Smallest fix:** Preserve the original params independently of the encoded body, or preserve the body when params were not overridden. Cover path-only JSON overrides through both forms.

### F10 — P2: A and B share parsing, but not request semantics

**Locations:** [`profile_workloads.rb:17–83`](../../gem/lib/lowrail/profile_workloads.rb#L17-L83), [`app_workloads.rb:27–79`](../../bench/upstream/census/app_workloads.rb#L27-L79), [`rails_main_census_4.rb:27–39`](../../bench/upstream/rails_main_census_4.rb#L27-L39). A's policy originates in `11804786`; the duplicated DSL consumers in `738accc6`, with signed-cookie changes in `f8a0da28`.

The same declared write with `csrf: false` and `csrf_from '/csrf'` sends `GET /csrf` then the write under A, but only the write under B. A sends `Origin: https://localhost`; B sends no Origin. These differences can change session initialization, CSRF/middleware behavior and allocations without changing the manifest. Authentication, browser defaults, token policy and cookie/session handling remain independent implementations, so sharing the DSL does not establish equivalent workloads.

**Smallest fix:** Put the common browser/authentication/CSRF request policy in one shared implementation, retaining separate transports and measurement orchestration. Add one A/B outgoing-request contract check with asymmetric headers, authentication and CSRF cases. If differences are intentional, encode them in provenance and narrow the equivalence claim instead of hiding them.

### F11 — P2: the frozen manifest can describe a different live workload

**Locations:** [`workloads.rb:59–68`](../../gem/lib/lowrail/workloads.rb#L59-L68), [`154–175`](../../gem/lib/lowrail/workloads.rb#L154-L175), [`198–212`](../../gem/lib/lowrail/workloads.rb#L198-L212). Introduced by `738accc6`.

The manifest itself is recursively frozen, which is correct, but requests retain mutable nested params and header values while the manifest is cached. After manifest creation, changing a nested param from `before` to `after` and `HTTP_ACCEPT` from HTML to JSON changed the live request while the serialized manifest remained byte-identical. Header values are omitted entirely, so requests evaluated from the same file with different environment-derived Accept values also have indistinguishable provenance. File SHA alone cannot describe runtime-derived values.

**Smallest fix:** Freeze defensive copies of the evaluated declaration values used for replay, while allowing blocks to return fresh overrides. Include deterministic digests of header/env values and relevant sign-in settings without publishing secrets. Do not claim the block's future outputs are certified by its source line; document that boundary or record resolved measured variants.

### F12 — P2: recorded output is not restricted to replayable requests

**Locations:** [`profile.rb:129–159`](../../gem/lib/lowrail/profile.rb#L129-L159), [`lowrail-profile:112–123`](../../gem/exe/lowrail-profile#L112-L123), [`workloads.rb:220–262`](../../gem/lib/lowrail/workloads.rb#L220-L262), and [`profile.rb:116–120`](../../gem/lib/lowrail/profile.rb#L116-L120). Recording introduced by `738accc6`; fork reset predates it.

The renderer emits executable `Model.first!` bindings even when only a commented-out write uses them. A collection GET plus a disabled DELETE can therefore fail immediately on `Comment.first!`, for a record the suite just deleted or a model the recorder only guessed. GET query params are not retained: a recorded `/search?q=needle` can become enabled `get search_path`, measuring a different request. Unresolved route parts may emit `get nil` when `ORIGINAL_FULLPATH` is absent; guessed models are not verified. Shape grouping omits format, so different formats can collapse into one entry. Truncating strings/arrays or replacing objects with class labels is lossy, not a replay serialization.

Fork reset clears native counts but not the Ruby shapes hash. A child inherited a parent's shape count of 7 while its native windows correctly reset to zero; merging per-process shape files then duplicates pre-fork request frequencies.

**Smallest fix:** Only enable shapes whose full request representation and dependencies can be replayed; comment unsupported/lossy shapes with a reason. Preserve safe query data, include format in grouping, and comment/defer bindings used exclusively by disabled writes. Clear shape state in forked children. These corrections should retain the documented refusal to enable arbitrary recorded writes automatically.

### F13 — P2: replay's exclusions hide real queue and delivery side effects

**Locations:** [`profile_workloads.rb:33`](../../gem/lib/lowrail/profile_workloads.rb#L33), [`86–95`](../../gem/lib/lowrail/profile_workloads.rb#L86-L95), and the Run it section of `docs/profile.md`. Introduced by `738accc6`.

The runner uses the app's real queue/delivery adapters, unlike the census. A request with `jobs: true` and an actual Active Job inline adapter executed its job 30 times across warmup and counted passes, while the receipt listed the request under `not_replayed.enqueued_by`. An external adapter instead enqueues real work that workers can execute. The warning to use a disposable database does not isolate queues, email or third-party services. The truthful distinction is that B does not schedule extra standalone mail/job workloads, not that requests' jobs are never run.

**Smallest fix:** Correct the receipt/docs and require disposable external services as well as a database. If the intended promise is to suppress request-enqueued work, implement explicit capture in the `--workloads` runner only. Do not change adapters during the user's ordinary profiled suite: that would itself violate invariant 1.

### F14 — P2: child options after `--` are still consumed by the profiler

**Location:** [`lowrail-profile:35–44`](../../gem/exe/lowrail-profile#L35-L44). Introduced by `738accc6`.

Unlike the value-option parser, the optional `--workloads`/`--record` flags and removed-`--paths` check scan all arguments, including the child command. `lowrail-profile -- ruby -e 'p ARGV' -- --workloads` aborts looking for Lowrail's workload file instead of launching Ruby. This contradicts the documented argument boundary and changes the requested command.

**Smallest fix:** Split profiler arguments from child arguments at the first delimiter before parsing any option or refusal. Pass the child portion through unchanged.

## Checks, positive findings and limits

The requested command ran on Ruby 4.0.9 via mise:

```text
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/profile_test.rb --verbose
2 runs, 38 assertions, 0 failures, 0 errors, 0 skips
```

The initial attempt skipped both tests because Rails/sqlite3/bcrypt were absent. After installing Rails 8.1.4, sqlite3 2.10.2 and bcrypt 3.1.22 into the orb's Ruby 4.0.9 environment, the unmodified tests exercised the feature and passed. No repository dependency files changed. The two tests do not cover the failing boundaries above.

Additional executed checks and bounded conclusions:

- The unchanged extension built on Ruby 4.0.9; the maintainability reviewer also built it on 4.0.7. Main-thread, ordinary nested windows preserve the outer kind as documented. A normal application exception survived request cleanup unchanged with recording off. Forked native counters reset independently of the parent.
- Repeated `GC.verify_compaction_references(double_heap: true, toward: :empty)` inside active windows survived with zero dropped samples, both counting-only and with app-frame attribution enabled. This is a bounded runtime check, not proof of all native memory-safety paths.
- The NEWOBJ callback uses C-owned copies of path text and libc allocation, not deliberate Ruby object creation. The correctness reviewer inspected the exact runtime source revision `3e93b23afcec3433f6aecc34b5d832799d754238`: [`rb_profile_frames`/`rb_profile_frame_path`](https://github.com/ruby/ruby/blob/3e93b23afcec3433f6aecc34b5d832799d754238/vm_backtrace.c#L1727-L1855) and [`get_path_and_lineno`](https://github.com/ruby/ruby/blob/3e93b23afcec3433f6aecc34b5d832799d754238/vm_trace.c#L809-L830) support the narrow no-Ruby-allocation claim for these operations. The path-cache VALUEs are compared, not dereferenced as retained objects, and the tracepoint is rooted. No demonstrated compaction use-after-free or allocation-recursion crash was found. No Ruby allocation is narrower than no allocation: the hook grows libc tables and has the lifetime leak in F8. No sanitizer/OOM campaign or unrestricted cross-Ractor native execution was performed.
- `Gem::Specification.load('gem/lowrail.gemspec')` loaded zero new features and did not define Lowrail. With `LOWRAIL_PROFILE` unset/empty, requiring `lowrail/profile` also left Lowrail undefined. Listing the gem with `require: false` is passive in these controls.
- Loading profiling after Active Support alone loaded none of Action Controller, Active Job, Action Mailer or Action Cable. Inspection shows the callbacks run at framework load boundaries where their target classes already exist. No new unconditional eager-framework load was substantiated. The deferred failure in F5 is nevertheless real and must be contained.
- The CLI intentionally writes diagnostic profiles even when the wrapped command exits nonzero: a command exiting 7 in both runs yielded CLI exit 0 and a warning. `docs/profile.md` explicitly says to check the suite in its own job; this was not classified as an undisclosed bug. A diagnostic profile is not proof of unchanged test outcomes or a valid CI comparison.
- The documented first/last line floors and action multipliers match the implementation for complete, eligible two-run data; the direct regression CLI exits 1. F6 and F7 prevent treating that arithmetic alone as a sound user-facing gate.

### YAML migration and documentation claims

Read the prior YAML/ERB builder and both fixture files at `11804786`, the current Ruby builders/fixtures, and the validation sections in `docs/upstream/census.md`. Workload names and declared request intents are preserved in the fixture translation; the Lobsters XHR Accept change is deliberate and explicitly disclosed as a one-time +30–47-object step, not represented as unchanged allocations. The docs also disclose the earlier Blog PATCH SQL-control difference.

The historical same-name/masked-SQL and allocation cohorts in the docs were **not independently rerun in this review**. The exact original disposable copies/bundles and services are not present here; existing corpus bundle failures are not evidence for or against the profiler. There is no new support or speed claim from this review. In particular, historical fixture parity does not establish arbitrary DSL parity in the presence of F9–F13.

README and the profile guide accurately label the tool a prototype, warn that requests are real, distinguish allocations from timing, and list the census's separate mail/job replay. Their broad safe-no-op, ready-to-run recording and CI-gate language needs the fixes above before promotion. The standalone profile guide and README also show a development/test-only Gemfile entry followed by production commands; production replay requires the gem to remain installed/available in that environment rather than being excluded by deployment Bundler settings.

The rest of the gem suite was not rerun. Known `pr_queue`, endpoint, form-scaffold and corpus-bundle environment failures were not attributed to these commits. No large-file-only decomposition or unrelated cleanup is requested.

## Re-review boundary

Apply the smallest fixes, rerun the profile tests plus the failing recording/cache/hook/concurrency/compare cases, and repeat per-test/load-order controls on the supported real-app matrix before making invariant-1/invariant-7 claims. This report applies only to the pinned code. Report publication commits, unrelated concurrent main changes and a later green check do not retroactively certify a fixed implementation.

## Resolution (2026-11-18)

Fixed on main after `850f8496`, for re-review; the findings above describe the pinned code and are left as written.
Each P1 has a regression test through the CLI or the DSL that fails on the pinned code (checked by running the new
tests against a worktree of `85e58dcf`): `gem/test/profile_test.rb` (7 new) and `gem/test/workloads_test.rb` (new,
3 tests).

| Finding | Change | Test |
| --- | --- | --- |
| F1 | The renderer writes every request-derived value as a quoted literal (`format: "…"`, escaped path segments, `inspect` for names and params); route helpers and model names are used only when they are identifiers. | `test_record_keeps_request_values_as_data_and_filters_secrets` evaluates a recording of `/widgets.html); $lowrail_injected = true; #`: the global stays nil and the format arrives as data. |
| F2 | Params, a GET's query and path values pass through the app's `ActiveSupport::ParameterFilter` (from `filter_parameters`) before anything is kept; filtered values are `[FILTERED]`; `ORIGINAL_FULLPATH` is never stored; no filter, no params kept. Filtered shapes are commented out; the file and stderr warn that recordings are sensitive. | Same test: a password, a nested `api_token` and two query tokens appear in no file under the output directory or in the workloads file. |
| F3 | `--out` takes a new or empty directory or one with lowrail-profile's `.lowrail-profile` marker, where it removes only `runN/`, `command.txt`, `report.*` and `workloads.json`; any other existing directory is refused before the command runs. | `test_out_never_clears_a_directory_it_did_not_create` (`--out mine` with a file in it, `--out .`, and a marked directory keeping a user's file). |
| F4 | The Cable wrapper no longer records request shapes; only `Rails::Engine#call`, which has the Rack env, does. | `test_recording_leaves_cable_subscriptions_and_exceptions_unchanged`: return value, transmissions, and the identity of a channel's and a job's exception, plain and in both `--record` runs. |
| F5 | The counter is cached under a digest of its sources and compiler settings, built aside and moved in whole; `lowrail/profile` checks `Lowrail::Profile::API` before hooking anything. Every wrapper calls the profiler through Ruby methods that rescue profiler failures at their own call (open, name, close, note), never around `super`; on_load installation is contained per framework with a warning. Non-main Ractors skip the counter (`Ractor.main?`) without marking the C methods Ractor-safe. | `test_an_unusable_counter_or_hook_leaves_the_app_alone` (an older counter's API: request 200, profiling off; frozen `ActionController::Metal`: the app loads Base in both runs). Ractor: a job-shaped method under the real Job wrapper returns its value from a non-main Ractor (probe). |
| F6 | `shell: bash` on the documented Compare step. | `test_documented_ci_compare_step_fails_on_a_regression` runs the step from `docs/profile.md` with GitHub's command for its shell. |
| F7 | `report.json` carries capture metadata (command, seed, exit statuses, runs, Ruby, environment, dropped samples, workloads manifest digest). `compare` exits 2 unless both are complete, comparable, finite, multi-run captures with every command exiting 0; compares a kind only when every run of both has windows; leaves out (and lists) actions without a warm value or run on one side; uses the full run range as the spread. | `test_compare_needs_complete_comparable_captures` (`{}`, half-empty, one run, failed run, `[10, 1000, 10]` against `[20, 1010, 20]`, a `[nil, nil]` action). |
| F8 | A window belongs to its fiber and Ruby thread (a slot owned by `rb_fiber_current()`, its owner marked while open); each window keeps its own seen sites and attribution pairs and merges them once on close, so reach counts windows; slots and their buffers are reused (buffers above 64 Ki entries freed). No `__thread` state is left. | Probes: alternating threads reach 2 (was 20); interleaved request and job fibers `[1, 1, 0, 0]` (was `[1, 0, 0, 0]`); overlapping threads under `RUBY_MN_THREADS=1` 2 windows (was 1); 3,000 short-lived threads with attribution 13,964 → 14,296 KiB (was 50,520); compaction inside windows with attribution, 0 dropped. Existing exact-count tests unchanged. |
| F9 | A request keeps its declared params apart from the encoded body, so a path-only override (alternate or block) keeps the JSON body. | `test_path_only_overrides_keep_a_json_body`. |
| F10 | Request policy in one place, `Lowrail::Workloads::Replayer` (sign-in, CSRF page and token placement, no token fetch for `csrf: false`, turns, signed-in vs anonymous client), used by both `script/census app` and `--workloads`; signed cookies through one `Workloads.signed_cookie`. B's client now sends census 4's `Host` and `Origin` and an empty form for a bodiless write (the contract test found both). | `test_census_and_profile_send_the_same_requests`: census 4's Rack::Test client and B's client against one app, recorded by a middleware (method, path, query, parsed params, media type, browser and CSRF headers, cookie names): identical, with sign-in, CSRF from a page, a header, XHR, JSON with an alternate, `csrf: false` first and a signed-out request. |
| F11 | Requests hold frozen copies of the file's values (the file's own objects are not frozen); the manifest (format 2) adds a digest of header and env values and the sign-in's form, expected statuses, cookie flag and value digest. Docs state that a block's source line does not certify its outputs; `--workloads` lists measured variants of alternates and blocks. | `test_requests_are_frozen_copies_and_the_manifest_covers_header_values`. |
| F12 | Only GETs that replay as recorded are enabled; writes, filtered, lossy (long/binary/upload values, optional path parts, a write's query) and unresolved shapes are commented out with the reason; GET queries are kept; format and a non-default Accept are part of the shape; model lookups only enabled entries use stay enabled; models are verified as loaded Active Record classes (never loaded for this). Forked children clear the recorded shapes. | The F1/F2 test (`params: {"q" => "needle"}` enabled, a commented-out lookup); fork probe: child shapes 0, parent 1. |
| F13 | Receipt and docs say requests use the app's own queue adapter and mail delivery (inline adapters run jobs in the request, others enqueue real work) and name both; the docs require disposable database, queue, mail and third-party services. No adapter is changed. | Blog replay receipt (`queue_adapter test, delivery_method test`). |
| F14 | Arguments are split at the first `--` before any option or refusal is parsed. | `test_arguments_after_the_separator_belong_to_the_command`. |

**Safety and equivalence rerun** (details in [profile.md](../profile.md#rechecked-after-the-review-fixes-2026-11-18)):

* Campfire (`bin/rails test -v`, 634 tests) and Lobsters (`rspec --seed 1234`, 927 examples), fresh
  `script/corpus` copies: per-test outcomes identical with no gem, gem listed but off, and both profiled runs; load
  order outside Lowrail, Bundler and RubyGems identical in every process, except Lobsters' first-ever plain run,
  whose two repeats match off and profiled exactly.
* `compare` on Campfire: an A/A pair of `bin/rails test` exits 0; the planted `20.times { ERB::Util.html_escape }`
  exits 1 with the action (+45.85, floor 26.47) and the two Active Support lines (+1.68, floor 1.0) and nothing
  else, against both A/A reports; a `-v` against a plain profile exits 2. The documented step fails the job with
  `shell: bash` and passes without it.
* A's YAML (`11804786`) against the DSL on the Blog, through the new shared policy: the same 10 workload names,
  every masked SQL digest identical in both pairs, and every DSL median inside the YAML runs' own windows (largest
  move: POST comment −30.8 against a YAML A/A of −124).
* The Blog suite under `--record` (21 tests) keeps per-test outcomes; its recording replays through `--workloads`.

**Deferred or narrowed, with the reason:**

* F8: allocations in another fiber a window starts (`Enumerator#next`) are no longer counted: per-fiber ownership
  is what makes independent fibers correct, and the docs say so. A fiber abandoned inside an open window keeps its
  slot (and stays marked) until the process exits; bounded by such fibers, not by requests.
* F10: transports still differ (Rack::Test's cookie jar against a plain cookie map). The equivalence claim is the
  contract test's: what the app sees for the covered cases. Cookie attributes (path, expiry) are not modeled.
* F11: the census does not list block variants (recording them would allocate inside its measured operations);
  its SQL control remains the behavior check, as documented.
* F13: request-enqueued work is not suppressed or captured in `--workloads` (an implementation choice left open by
  the review); the claim is corrected instead.
* F2: only what `filter_parameters` names is filtered; other secrets (unfiltered keys, path segments the filter does
  not name) can still appear, hence the warning. F7: the action floor's multipliers remain Campfire-derived.
* Not rerun: Writebook, Pingcrm and CodeTriage from the earlier matrix, the Lobsters YAML/DSL pair, and the
  earlier `--workloads` proof numbers, which predate B's `Host`/`Origin` headers (marked in profile.md).
  The matrix and the pair were rerun on main later the same day, with a `compare --aa` per app
  ([profile.md](../profile.md#rerun-on-main-2026-11-18)); that rerun found and fixed dropped samples for code
  evaluated from line −1 (CodeTriage), and found a +2 to +3 object offset, left as recorded, on Lobsters' mail
  between YAML and DSL.

## Confirm review of 76be8b58 (2026-11-18)

**Verdict: changes.** The original destructive-directory, Ruby-injection, Cable and stale-extension/hook failures
are fixed in the exercised cases. This is not confirmation that all fourteen findings are closed: F2 still exports
some values the app filters, F7 still accepts incomplete or different evidence, and F12 still enables a request
that does not replay as recorded. There are also new output-path comparison and concurrent warm-count regressions.
Do not offer B's recording or comparison as a generally safe workflow yet. A with hand-authored, reviewed workloads
can remain an explicitly constrained expert prototype, not a promise of arbitrary A/B equivalence; generated
workloads feed A too, so A does not bypass the recording problems.

### Method and executed checks

Loaded `thermos`, `thermo-nuclear-review` and `thermo-nuclear-code-quality-review`. At the requester's explicit
direction one reviewer performed both passes in this thread, without subagents or new threads; this is not a claim
of two independent reviewers. Used detached scratch worktrees at `85e58dcf` and `76be8b58`, inspected the fix's
fourteen-file diff and downstream consumers, and left implementation/tests unchanged in the main checkout.
The main checkout also contained the unrelated later `a9f0dab4`, which is not part of this review.

Ruby was mise **4.0.9**, revision `3e93b23afc`, Linux x86-64; installed Rails **8.1.4**, sqlite3 **2.10.2**, bcrypt
**3.1.22**, rack **3.2.8** and rack-test **2.3.0** into this orb, not repository dependency files. On the exact fix:

```text
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/profile_test.rb --verbose
9 runs, 89 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/workloads_test.rb --verbose
3 runs, 18 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/load_hooks_test.rb --verbose
2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Copied only the fix's two test files into the baseline scratch worktree and ran the same commands against its
implementation and documentation: profile **9 runs, 49 assertions, 7 failures**, workloads **3 runs, 3 assertions,
3 failures**, no errors or skips. Load hooks on the baseline: **2 runs, 4 assertions, all pass**. Every added
profile test fails there, including every P1 regression test. The combined F1/F2 test stops at its secret-export
assertion on the baseline; the separate recorder-to-evaluation marker probe below establishes F1 independently.
The new A/B contract test fails there because `Replayer` does not exist, not because it independently observes the
old policy divergence; the separate outgoing-request probe below establishes that divergence.

### F1–F14 confirmation ledger

The probes reconstructed the original report's inputs and controls. Synthetic secrets and disposable directories
only; no real application data or external services were used.

| Finding | Reproduced on 85e58dcf | Observed on 76be8b58 |
| --- | --- | --- |
| F1 | A routed format `html); $profile_review_injected = true; #`, URL-encoded in `/widgets.FORMAT`, makes the global `true` when the recording is evaluated. | Global stays `nil`; format arrives as data. Also evaluated an unnamed-route format containing a quote and Ruby text: still data. Fixed for these probes. |
| F2 | Record a POST password, nested `api_token`, GET query token and write-query token: raw synthetic values appear in exported files. | These original values do not appear; redacted requests/bindings are disabled. **Not closed:** filtered formats and an updated filter list leak, C1. |
| F3 | Run with `--out unowned` containing `must-keep.txt`: child runs and the file disappears, even when the child makes no report. | Refuses before the child, sentinel survives. The regression also checks `--out .` refusal and a user's file surviving reuse of a marked directory. |
| F4 | Actual Rails Cable subscription with `--record` raises `NameError` for `env`; only the non-recording second run completes. | Both runs preserve the successful return/transmission and the identity of the channel's and job's exceptions. |
| F5 | Built `60d9c677`'s actual C extension on this Ruby, put it in an isolated newer-mtime old cache: zero successful requests, wrong-arity and missing-attribute errors. A frozen Metal prevents Base loading. A job-shaped method under the actual wrapper changes plain `731` to `Ractor::UnsafeError`. | Old cache ignored, both requests return 200; the separate old-API regression refuses before hooks. Frozen Metal warns but Base loads twice. Ractor result is `731`, as plain. Frozen-only CLI exits 1 because no window/report exists; the application itself succeeds. |
| F6 | Execute the documented Compare step's actual `compare ... \| tee` under its selected GitHub shell: regression is green without pipefail. | The documented `shell: bash` makes the complete step fail on the regression. |
| F7 | `{}` versus `{}` exits 0; half-empty capture exits 0; `[nil,nil]` action versus `[100,100]` fabricates +100 and exits 1; three-run `[10,1000,10]` versus `[20,1010,20]` exits 1 with floor 1. | Those give 2, 2, 0 (explicitly not compared), and 0 respectively. One-run/failed captures are rejected by the suite. **Not closed:** C2 and C3. |
| F8 | Alternating two ten-allocation threads: 20 String objects, reach 20 for two windows. Interleaved request/job fibers: `[1,0,0,0]`. Overlapping Ruby threads with `RUBY_MN_THREADS=1`: one window; ordinary threading: two. | Reach 2 for 20 objects/two windows; fibers `[1,1,0,0]`; two windows with and without M:N. Attribution-enabled 3,000 sequential threads, three Strings each and GC: baseline RSS 14,404 → 48,652 KiB, fix 14,376 → 14,684 KiB. Counting-only controls: 14,408 → 14,748 and 14,472 → 14,696 KiB. All snapshots drop 0; 20 compaction-inside-window iterations with attribution also drop 0. **New first-window regression and retained-fiber limitation:** C5/C6. |
| F9 | Both path-only JSON override forms lose `{"x":1}` and yield nil bodies. | Both keep that body, covered through the DSL. |
| F10 | `csrf_from "/csrf"; post "/write", csrf: false`: A sends GET then POST with Origin/form type; B sends only POST, without Origin/form type. | Both send only POST with Origin/form type. The real-app contract test passes for form sign-in, anonymous requests, XHR, JSON alternates, tokens and asymmetric headers. Cookie policy is still not equivalent, C6. |
| F11 | After manifest creation mutate nested param `before` to `before after`: live request changes with old provenance. | Frozen copies/header digests pass the new test. **Measured block outputs still bypass comparison provenance**, C2; their presence in a receipt is not sufficient. |
| F12 | `/search?q=needle` renders without its query; a fork child inherits the parent's recorded shape while native windows reset. The recording test also exposes the unconditional record binding. | Query retained, disabled-only binding commented, child shapes 0/parent 1, native windows zero in child. The injection probe keeps distinct formats. **JSON query requests remain wrong**, C4. |
| F13 | Actual Active Job `:inline`, `post "/work", jobs: true, csrf: false`: job performs 30 times, receipt says `not_replayed.enqueued_by`. | Still 30 performances, correctly reports `queue_adapter: inline` and request side effects; no misleading `enqueued_by` exclusion. Adapter left unchanged. This is a valid narrowed promise, not side-effect isolation. |
| F14 | `-- ruby -e 'p ARGV' -- --workloads --out x` is intercepted as Lowrail options. | Child prints `["--workloads", "--out", "x"]` unchanged; no report is expected. |

### C1 — P1: the new filter boundary still leaks app-filtered values

**Locations:** `gem/lib/lowrail/profile.rb:190–200,227–242`. Remaining F2, including defects in the new filtering
implementation, not a claim that the baseline was safe.

Two real routed Rails probes contradict the resolution's “only unfiltered keys can still appear” boundary:

1. Configure `filter_parameters += [:format]`, record `GET /widgets.format-secret`. The literal `format-secret`
   appears in the shapes JSON and the enabled generated request. `format` is copied into flags/grouping before
   filtering, while only required path parts go through the filter. The same probe filtered passwords and tokens
   correctly, so this is not an absent filter configuration.
2. Record `/widgets` once to initialize the cached filter; then append `:credential` to
   `Rails.application.env_config["action_dispatch.parameter_filter"]` and request
   `/widgets/1?credential=changed-filter-secret`. On the exact same env, Rails' `filtered_parameters` contains
   `"credential" => "[FILTERED]"`; the retained shape contains `"credential" => "changed-filter-secret"`.
   The cache checks array identity, not contents. Distinct route shapes prevent first-shape reuse hiding the bug.

**Smallest fix:** filter all retained path values, including format, before making a retained grouping key/name;
mark affected shapes disabled. Build a fresh ParameterFilter outside the window, or cache an immutable snapshot
and invalidate on content changes, not just identity. Add both counterexamples to the recorder/export regression.
Also make the unavailable-filter branch actually discard raw params: inspection shows `params` is assigned before
the conditional and returned unchanged if filtering is unavailable. That branch was not reached in the real Rails
8.1.4 controls, which load ParameterFilter; do not represent it as an observed Rails leak.

### C2 — P2: the comparison validator still promotes insufficient/different evidence to green

**Locations:** `gem/lib/lowrail/profile_compare.rb:46–112`, `gem/lib/lowrail/profile_report.rb:534–546`, and
`gem/lib/lowrail/profile_workloads.rb:42–61`. Remaining F7/F11 and an incomplete new validation boundary.

Repros through the actual CLI, not just private helper calls:

* Start with the new test's `report([10.0,10.0])` fixture. Delete head's `ranked` key: exit **0**, fabricated
  improvement 10 → 0. A one-element warm array for a two-run capture also exits **0**. Delete command and seed
  from both metadata hashes: exit **0**. Metadata `format` is not checked either.
* Base summary has request windows in both runs, head has only job windows: exit **0**, `compared: []`, no
  regressions. This is no comparison, not evidence that allocations did not regress.
* More importantly, use the unchanged file below with a real Rails app serving `/one` and `/two` through the same
  action. Run two complete two-run captures into the same output location, copying each `report.json` aside;
  set `REPLAY_PATH=/one` for one capture and `/two` for the other:

  ```ruby
  get("/one", name: "variant") { |n| { path: ENV.fetch("REPLAY_PATH") } }
  ```

  Both commands exit 0, with 20 measured requests per run and no drops. Receipts correctly show `/one` versus
  `/two`, but report metadata has the same workload digest `f112f1be7092dff8` in this fixture, because it hashes
  only the declaration. `compare one.json two.json --json` exits **0**, `problems: []`. Thus even genuine,
  unedited captures of different workloads can be green; the synthetic missing-key cases are not the sole issue.

**Smallest fix:** validate the required report/version/metadata shape and every warm vector's run count, keeping
an absent collection distinct from an empty one; return 2 when no kind is comparable. Carry a digest of the
resolved measured workload sequence/counts for **each** run (and effective replay host/browser policy) into
capture metadata, or refuse to CI-compare dynamic blocks until it exists. A set of last-run variants alone does
not establish equal frequencies/order. Preserve the diagnostic report rather than pretending declarations certify
measurements. Per-process Ruby/environment conflicts must not be discarded by `load_run`'s first-value `||=`
before validation; this last point is a source-inspection limitation, not an executed mixed-Ruby capture.

### C3 — P2: output paths make equivalent workloads impossible to compare

**Locations:** `gem/exe/lowrail-profile:82,153`, `gem/lib/lowrail/profile_compare.rb:65–67`. Introduced by the new
command-compatibility check acting on the existing generated runner command.

On one unchanged minimal Rails app with `get "/widgets"`, run:

```sh
lowrail-profile --out base --workloads
lowrail-profile --out head --workloads
lowrail-profile compare base/report.json head/report.json --json
```

Both captures succeed, but comparison exits **2** solely because the commands end in `base/workloads.json`
versus `head/workloads.json`. The output receipt is not a workload input. Absolute installation/app paths also
prevent otherwise equivalent captures from different checkouts comparing.

**Smallest fix:** keep the actual argv for diagnostics, but record structured logical capture identity separately:
mode, workload manifest and meaningful command arguments, excluding generated output destinations. For ordinary
commands keep argv boundaries rather than the ambiguous `join(" ")`. Test the complete two-output invocation.

### C4 — P2: preserving a JSON GET query moves it into the body

**Locations:** `gem/lib/lowrail/profile.rb:195,221–222`, `gem/lib/lowrail/workloads.rb:408–411`, interacting with
the existing IntegrationTest-style `Request` conversion at line 42. Remaining F12 with a new wrong replay form.

A real `GET /lookup?q=needle` with `Accept: application/json`, recorded and evaluated, becomes
`get lookup_path, as: :json, params: {"q" => "needle"}`. On the baseline the query was lost outright. On the fix
the declared request has verb `post`, body `{"q":"needle"}` and no query. Replaying it through Rails returns:

```text
original: GET query={"q" => "needle"} body={}
replay:   GET query={} body={"q" => "needle"}
```

Rack's method override restores the effective GET inside Rails, but middleware sees a POST and the controller's
query/body distinction changed. A controller reading `query_parameters` now executes a different operation.

**Smallest fix:** do not infer JSON request-body encoding from response Accept for recorded GETs. Render the
actual Accept header and keep GET query params (or conservatively comment out this shape with a reason). Leave
the hand-written DSL's intentional IntegrationTest behavior alone. Assert method, raw query and body end to end.

### C5 — P2: native merging changes “first reached” to “first completed”

**Location:** `gem/ext/lowrail_profile/lowrail_profile.c:399–406`. Introduced by the F8 fix; independent of the
fixed reach multiplicity.

Use two ordinary Ruby threads and one allocating method `def allocate_at_one_site(n); n.times { String.new }; end`.
Thread A enters request kind 0, calls it with 10, then waits on a Queue. Thread B enters, calls it with 2 and
leaves; release A and join both. Start the real counter before this and inspect the String row after both close:

```text
85e58dcf: objects=12 windows_reached=2 first=10
76be8b58: objects=12 windows_reached=2 first=2
```

The documented warm count changes from **1 to 5 objects/request** for the same allocation sequence. In parallel
suites this keeps the slow first request's lazy initialization instead of removing it. Reach is now correct, but
the original warm definition regressed. Action first-completion bookkeeping already existed; this attribution is
specifically about the newly changed per-site first count.

**Smallest fix:** retain first-touch ownership/order independently of merge order (for example a site's first
touch reserves its window identity, with the count merged when that owner closes). Keep per-window seen sets for
reach. Add this asymmetric close-order probe as a native public-snapshot regression.

### C6 — P2: important deferrals are not narrowed in the user-facing promise

**Locations:** `docs/profile.md:52–55,123–144`, `docs/upstream/census.md:139–144`, `README.md:135–168`; native
owner marking at `gem/ext/lowrail_profile/lowrail_profile.c:528–534`. The Resolution states these limits honestly,
but readers following the README/profile guide do not get all of them.

* A fiber abandoned while a window is open is permanently rooted, along with its thread/stack and reachable app
  records. Executed `Fiber.new { Profile.enter(0); Fiber.yield }`, resumed once, dropped the only Ruby reference,
  then checked a WeakRef after three GCs: baseline **collected**, fix **retained**. The user guide still says
  “no retained records” and advertises fiber-scheduler requests without the abandoned-window restriction. This is
  potentially unbounded app-state retention, not merely a reusable C buffer. Either fix lifetime cleanup without
  Ruby allocation in NEWOBJ, or explicitly exclude abandoning/cancelling open fibers and long-running use with
  that behavior; do not call the broad never-change-app resource claim established.
* Cookie path/expiry semantics are not merely transport differences. With a response
  `Set-Cookie: auth=yes; Path=/private`, followed by GETs to `/public` and `/private/me`, the actual census client
  sends no auth cookie to `/public`; B sends `auth=yes` to both. This plain-cookie-map behavior predates the fix,
  but contradicts the newly broadened shared-policy/equivalence prose. Match cookie policy or explicitly restrict
  the equivalence claim to the contract test's cases/root-scoped non-expiring cookies. No need for a general
  browser emulator to make an honest restricted claim.
* Child-fiber undercounting, non-main Ractor exclusion, disposable services, and the Campfire-derived action
  multiplier are now disclosed in the guide; F13's narrowed promise is acceptable. The guide marks its earlier
  proof table as pre-fix, but the README still states an unqualified “same objects per line within about 1%” after
  the changed Host/Origin/form policy. Qualify that as historical, measured app/route evidence, not arbitrary DSL
  equivalence. The block-output boundary is in `census.md`; that does not make B's false-green gate in C2 sound.

### Maintainability and admission conclusion

The shared Replayer is a useful canonical boundary: policy is no longer duplicated and the tested outgoing
requests really agree. The small profiler failure boundaries are appropriate because they do not rescue or replay
application `super`. No production file crosses 1,000 lines (largest affected report: 565; counter: 626), and no
unrelated decomposition or generic adapter framework is requested. The structural miss is capture provenance:
transport/output argv, logical workload identity and measured variants are represented separately but validated as
though they were the same thing. Fix that boundary directly rather than adding per-example exclusions to compare.

Gemspec and off-path controls on both pins load zero new features/define no Lowrail; loading profiling and Active
Support alone defines none of Action Controller, Active Job, Action Mailer or Action Cable. The load-hook tests
pass. These are bounded invariant-1/invariant-7 checks, not proof for every app or scheduler. Preserve lazy loading
when repairing filters and ownership; declining an unsupported shape/window must not affect app execution.

This confirm review reran **no** Campfire/Lobsters/Writebook/Pingcrm/CodeTriage suite, corpus YAML/DSL cohort,
`lowrail verify`, `lowrail bench`, timing, instruction or speed experiment. The author's reported matrix and
historical numbers remain attributed evidence, not independently confirmed results. This commit records the
review only; C1–C6 are not implementation fixes. C1/C4 block promoting recording for either consumer; C2/C3 block
B's advertised CI workflow; C5 blocks trusting its concurrent warm measurements; C6 must be fixed or explicitly
scoped before offering general app/fiber/A/B safety claims.

## Resolution of the confirm review (2026-11-18)

Fixed on main after `76be8b58`, for re-review. Each finding has a regression test through the CLI or the DSL that
fails on `76be8b58` (checked by running the new tests in a worktree of it: 5 runs, 5 failures).

| Finding | Change | Test (and what it gives on 76be8b58) |
| --- | --- | --- |
| C1 | `note` filters all path parameters, the format included, before they name, group or are kept, and keeps no params or path values when the app's filter is unavailable. The filter is rebuilt whenever the list's contents change (compared by value, kept as a copy), not by array identity. A filtered format marks the shape filtered, so it is commented out. | `test_record_filters_every_value_and_keeps_json_gets_as_gets`: `filter_parameters += [:format]` and `/widgets.format-secret`, then `:credential` appended to the env's filter list after the first request and `/widgets/1?credential=…`; neither secret is in any file under the output directory or the workloads file (76be8b58: `format-secret` exported). |
| C2 | `compare` validates the report schema: metadata format 2, identity and seed present, every collection present for every kind (absent is not empty), every line's warm vector one finite value per run and every action's one value or nil per run. A kind some runs have and others lack, or no comparable kind, exits 2. `--workloads` records, per run, a digest of every counted request as sent (name, verb, signed-in client, path, params, body and header digests, host and browser headers) in `runN/measured.json`; the report's identity carries the manifest digest and these per-run digests, which must agree within and across reports. Ruby and environment are collected from every process, not the first. | `test_compare_needs_complete_comparable_captures` adds a missing `ranked`, a one-value warm vector, no identity/seed, and a head with only job windows (76be8b58: exit 0). `test_workloads_captures_compare_by_what_they_measured`: the same file with a block replaying `/widgets?v=1` against `?v=2` exits 2 with an identity difference (76be8b58: green). |
| C3 | `capture.json` records a structured identity: for commands the argv array, for `--workloads` the mode and replay host (with the manifest and measured digests added by the report), never the output paths; argv is kept apart for diagnostics. | Same test: `--out base` and `--out head` of the same file compare with exit 0 (76be8b58: exit 2). |
| C4 | A recorded GET never becomes `as: :json`: JSON is inferred only for writes, a GET's `application/json` Accept is kept as a header, and its query stays params. A GET with a body is marked lossy. `MockClient` passes a copy of a GET's params, because `Rack::MockRequest` merges the query into the Hash it gets: with the frozen request values every `--workloads` GET with params raised `FrozenError` on 76be8b58 (found by this test). | Same test as C1: the recorded `/lookup?q=needle` with JSON Accept is declared as `get`, params `{"q"=>"needle"}`, no body, Accept `application/json`, and the app sees `GET`, query `{"q"=>"needle"}`, body `{}`. |
| C5 | Each window gets an id; its first touch of a line reserves the line's first count for it (`owner`), merged when that window closes, so the first window to reach a line keeps the first count whichever closes first. Reach still comes from per-window seen sets. Lines reserved but not yet reached by a closed window are not snapshotted. | `test_first_window_is_first_reached_and_open_windows_are_bounded`: 10 then 2 Strings on two threads, the second closing first: snapshot `12 2 10` (76be8b58: `12 2 2`). |
| C6 | Abandoned open windows are bounded: past 1,024 open windows the oldest one off the current fiber is given up and counted in `dropped` (so `compare` refuses the capture), and its fiber can be collected; the guide says so next to the no-retained-records and fiber claims. Ruby 4.0 exports no weak marking to extensions, so up to 1,024 abandoned fibers are still retained. `MockClient` now keeps cookies as Rack::Test does (name and Path, default the request's directory; sent under the path; dropped after Expires; Domain and Max-Age not modeled). The census and guide narrow the A/B claim to the contract test's cases; the README's 1% is marked historical, one app and route set. | Same native test: 1,100 abandoned fibers leave at most 1,024 alive (76be8b58: 1,100). `test_census_and_profile_send_the_same_requests` adds `Set-Cookie: auth=yes; Path=/private`, then `/public` and `/private/me`: both clients send `auth` only under `/private` (76be8b58: B sends it to `/public`). |

The three suites (`profile_test`, `workloads_test`, `load_hooks_test`) pass: 17 runs, 137 assertions.

Rechecked on Campfire (`bin/rails test -v`, 634 tests, fresh copy): per-test outcomes identical with no gem, gem
listed but off, and both profiled runs (632 pass, 2 skip); all 18 processes load every feature outside Lowrail,
Bundler and RubyGems in the same order; no `[lowrail-profile]` warning; 666 requests at 19,493 objects per request.
A second `-v` profile compared against it **exits 1** with one line, `json/common.rb:364` +1.69 against a floor of
1.0: an A/A false regression. The line ranges 107.3–111.2 across six captures while each capture's two runs move
0.27–3.3. The 2-run line floor is unchanged by these fixes (and by 76be8b58); this is a new observation, recorded in
the guide, not fixed: choosing a floor measured between invocations is a decision, not a threshold to tune until green.
The capture from the first round is refused as having no capture metadata (exit 2), as intended.

## Second confirm review of a05d1dab (2026-11-18)

**Verdict: changes.** The reported C1–C6 corrections work on the narrow cases below, but their broader
boundaries are not all closed. Recording still exports values Rails filters and can enable a different GET;
comparison still accepts incomplete captures and indistinguishable identities for different workloads. The
first-touch correction and the overflow cap work in the exercised thread/fiber cases. This review requests the
bounded fixes below, not a floor-policy change, general browser emulation or a profiler redesign.

### Scope, method and executed checks

Loaded `thermos`, `thermo-nuclear-review` and `thermo-nuclear-code-quality-review`. At the requester's direction
one reviewer performed both passes here, without subagents or new threads; this is not two independent reviews.
Reviewed the thirteen-file `a05d1dab^..a05d1dab` diff, the relevant downstream readers and the original inputs
from the previous confirm thread. Its archived workspace could not transfer the old harness files, so the inputs
were reconstructed in new harnesses, not represented as recovered binaries/scripts. Before/after implementation
pins were detached `76be8b58e9a535b85622e9e5738ab14ca8b76eac` and clean main
`a05d1dab1d3d680ee91cc0e4b2fdeb1f33372164`. Unrelated intervening commits were excluded. No implementation or
permanent test was changed. The commit-associated GitHub pulls endpoint returned no PRs; nothing was posted there.

Used mise **Ruby 4.0.9**, revision `3e93b23afc`, Linux x86-64; Rails **8.1.4**, sqlite3 **2.10.2**, bcrypt
**3.1.22**, Rack **3.2.8**, rack-test **2.3.0**. Dependencies were installed in the orb, without changing repository
dependency files. These commands on the exact fix all passed, without skips:

```text
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/profile_test.rb --verbose
12 runs, 114 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/workloads_test.rb --verbose
3 runs, 19 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/load_hooks_test.rb --verbose
2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Total: **17 runs, 137 assertions**. Loading the fix's test files with the baseline's `gem/lib` and test helper,
the four relevant profile cases gave **4 runs, 16 assertions, 4 failures**, and the A/B contract case gave
**1 run, 2 assertions, 1 failure**, without errors/skips. The combined cases stop at their first failed assertion;
the independent probes below establish the other boundaries rather than claiming those assertions ran.

### C1–C6 before/after ledger

All requests used synthetic values and the repository's minimal Rails fixture, not corpus apps or real services.
Private scripts and generated inputs are under `.amp/in/orb-backup/confirm/`; its `base/` is the detached old
worktree, `native-base/` and `native-head/` are separately built extensions. For example, from the repo root:

```sh
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/confirm/rails_probe.rb .amp/in/orb-backup/confirm/base
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/confirm/rails_probe.rb .
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/confirm/compare_probe.rb .
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/confirm/native_probe.rb head threads
```

| Finding | Reproduced on 76be8b58 | Observed on a05d1dab |
| --- | --- | --- |
| C1 | `[:format]` plus `/widgets.format-secret` exports the format. After the first request, appending `:credential` to the same env filter array exports `changed-filter-secret`, although Rails masks it. | Both values absent from generated workloads and capture JSON; the filtered shapes are disabled. **Original cases fixed; other filters remain unsafe, D1.** |
| C2 | Missing `ranked`, short warm vector, no identity/seed/command, unknown format and no common kind all exit 0. Same-file block choosing `?which=one` versus `?which=two`, same output directory, gives two complete 20-request-per-run captures and compare 0. | Schema cases exit 2. The real block captures exit 2 for differing measured identities (`3bc0bdb47be0cb1e` versus `17c4067dd9c10bc4`); an action with `[nil,nil]` remains explicitly not compared, not fabricated as zero. **Original cases fixed; D3/D4/D6 remain.** |
| C3 | Identical workloads into `left/` and `right/`: both captures succeed, compare 2 because receipt output paths differ. | Same complete invocation pair compares 0. Workload identity excludes generated output/install paths; command identity preserves argv boundaries. **Fixed in these cases.** |
| C4 | Recorded JSON Accept plus `/lookup?q=needle` declares POST with JSON body; Rails sees GET, query `{}`, body `{"q"=>"needle"}`. Independently, MockClient given a frozen GET params hash raises `FrozenError`. | Declares GET, query params, nil body and JSON Accept; Rails sees GET, query `{"q"=>"needle"}`, body `{}`. Frozen GET params plus an existing `x=1` query gives `q=needle&x=1` without mutating the input. **Original cases fixed; other GET Accept values remain wrong, D2.** |
| C5 | First-touch thread A allocates 10 Strings; B allocates 2 and closes before A: public snapshot `count=12, reach=2, first=2`. Same failure with interleaved fibers. | `12,2,10` for threads, fibers, M:N threads (`RUBY_MN_THREADS=1`) and attribution-enabled threads. All drop 0. **Fixed in these completed-window cases.** |
| C6 | One abandoned fiber retained; 1,100 abandoned fibers all retained, dropped 0. `auth=yes; Path=/private` is sent to `/public`. | One fiber still retained, as disclosed; 1,024/1,025/1,100 opens leave 1,024/1,024/1,024 alive and drop 0/1/76. The first fiber is collectible after overflow, the last remains alive. A real two-run 1,100-open capture is refused (2) for `dropped=[76,76]`. Path-scoped cookie is absent on `/public`, present on `/private/me`, like Rack::Test. **Overflow and ordinary Path fixed; finalization gap D5.** |

The reconstructed original one-abandoned-fiber probe deliberately still reports retained on the fix: C6 chose a
documented cap, not immediate weak collection. It would be incorrect to claim that original lifetime changed to
collected. Twenty `GC.verify_compaction_references(double_heap: true, toward: :empty)` calls inside completed
windows, both counting-only and with attribution enabled on the fix, preserved counts and dropped 0. This is not
a sanitizer, OOM or unrestricted Ractor campaign.

### D1 — P1: Proc context and shallow filter snapshots still export app-filtered secrets

**Locations:** `gem/lib/lowrail/profile.rb:194,232,242–247`. Remaining C1/F2, not a claim that these were safe
on 76be8b58. Both failures were observed on both pins with Rails' own filtered parameters as the control.

1. A supported three-argument ParameterFilter Proc can depend on the complete original params. With:

   ```ruby
   filters.replace([/\Aformat\z/, ->(key, value, original) {
     value.replace("[FILTERED]") if key == "credential" && original["controller"] == "widgets"
   }])
   ```

   record `GET /widgets.proc-format-secret?credential=proc-secret`. On a05d1dab Rails' `filtered_parameters`
   masks both credential and format, but shapes JSON and the generated file contain `"credential"=>"proc-secret"`.
   The format regexp works; this is not a missing filter. Lowrail filters the path and query separately, so the
   query Proc never sees the controller that Rails passes in the merged original hash. Commenting this particular
   request out because its format was filtered does not prevent exporting the credential.
2. After an initial request builds the cache with `mutable = +"not_a_key"; filters.replace([mutable])`, run
   `mutable.replace("credential")`, then a distinct shape `/widgets.string-format?credential=string-secret`.
   Rails masks the credential; Lowrail exports it in an **enabled** workload. `filters.dup` aliases its String
   elements, so `@filter_source == filters` stays true and the already-compiled regexp is stale.

**Smallest fix:** construct a fresh ParameterFilter outside counting windows rather than maintaining a shallow
snapshot cache (or snapshot String values immutably). Do not pass split params as though they were Rails' complete
Proc context. Preserve the full original context and precedence without forcing unparsed input/framework loads;
if that cannot be done faithfully, keep no request values for such Procs and record the unsupported reason.
Ordinary two-argument masking Procs and regexp-list replacements/restoration passed explicit controls. This is
not a claim that all Procs or regexps fail, or that a regexp itself is mutable.

### D2 — P2: an XML GET still becomes an enabled HTML replay

**Locations:** `gem/lib/lowrail/profile.rb:198–200`, `PLAIN_ACCEPT` at line 48. Remaining F12 at the modified
Accept boundary; the JSON-specific C4 repro is fixed, not every GET Accept.

In the fixture, route `/lookup` to an action returning `request.get_header("HTTP_ACCEPT")`. Record
`GET /lookup?q=needle` with `HTTP_ACCEPT=application/xml`. Both profiled originals return `200 application/xml`.
The generated enabled request is:

```ruby
get lookup_path, name: "GET /lookup", params: {"q" => "needle"}
```

Load it and replay through MockClient: on a05d1dab it returns **`200 text/html`**. The original recording already
omits the header on 76be8b58; its frozen-GET-params failure prevents that unmodified client from completing this
replay there. The modified condition preserves `application/json` but continues treating XML (and other
`PLAIN_ACCEPT` values) as if the ordinary GET client sent it by default. It does not.

**Smallest fix:** retain the actual GET Accept unless it exactly equals what the selected replay flags/client
will send; retaining all present GET Accept values is simpler and correct. Extend the existing end-to-end recorder
case with asymmetric XML/default HTML, not just JSON. Do not change hand-authored `as: :json` semantics.

### D3 — P2: the initial measured receipt certifies a run that measured nothing

**Locations:** `gem/lib/lowrail/profile_workloads.rb:47–63,78–86`, `profile_compare.rb:76–82`. The initial
receipt existed on 76be8b58; the new per-run measured identity also publishes it as acceptable evidence.

Unchanged workload file:

```ruby
get("/widgets", name: "variant") { |n|
  exit(0) if n == 2
  { path: ENV.fetch("REPLAY_PATH") }
}
```

Use a successful `/widgets` action. Capture twice into the same `--out capture --workloads`, with
`REPLAY_PATH=/widgets?which=one` and `...which=two`, copying each report aside before the next capture. Each run
serves one warmup request and stops before any measured request. On a05d1dab both commands have `exit=[0,0]`,
both `measured.json` files contain `requests:0, sha256:a2c0a43afea3c8e0`, and **compare exits 0** with no problems.
The requests actually served differ, but the digest covers only the initial host/browser preamble. The old pin
also compares green; this is a remaining completeness failure, not evidence that the new digest is worse.

**Smallest fix:** publish the per-run comparable receipt only after all counted passes finish successfully, or
mark initial/final receipts explicitly incomplete/complete and validate that marker plus expected counted request
count. Keep any early receipt diagnostic-only. Checking merely for a truthy digest (or matching zero counts) cannot
establish completion. This is distinct from ordinary failed commands, which the new validator correctly refuses.

### D4 — P2: different supported Rack env values have the same measured identity

**Locations:** new `profile_workloads.rb:72` consuming `workloads.rb:77`. The lossy header/env digest predates
the fix; using it as the new measured request certificate does not close F11/C2 for these declarations.

Use this same file in two complete captures, with `FLAG=1` and `FLAG=2`:

```ruby
get "/widgets", env: { "app.flag" => ENV.fetch("FLAG").to_i }
```

The controller records `request.env["app.flag"]`: it sees integer **1 versus 2** on every corresponding request.
Both runs of each capture measure 20 requests, with successful exits and no drops. On a05d1dab the manifest digest
is `6332ec9fcf3e4856` and measured digest `d7a2005416fd8ece` on both sides; **compare exits 0**, `problems:[]`.
The baseline also exits 0. The DSL accepts `env:` and preserves these scalar values, but `Request#to_h` substitutes
the class name `Integer` for both values before hashing them. This is not a source-file change hidden from SHA.

**Smallest fix:** fix the canonical `Request#to_h` value digest to encode supported scalar/structured env values
deterministically. For arbitrary Rack objects whose identity cannot be certified, record that boundary and refuse
CI comparison instead of treating equal class names as equal requests. Do not add a second, divergent digest in
the profile runner.

### D5 — P2: unfinished windows below the cap still produce green, incomplete reports

**Locations:** `lowrail_profile.c:449–454,473,600–605`, `profile.rb:285–303`, and the new guarantee in
`docs/profile.md:150–154`. Remaining C6/F7; the overflow counter itself is correct.

Use a real fixture controller, not a mock window wrapper:

```ruby
def index
  Fiber.yield if params[:abandon]
  render(plain: "ok")
end
```

The command starts `Fiber.new { Rails.application.call(env_for("https://localhost/widgets?abandon=1")) }.resume`,
drops its reference, then makes three completed ordinary `/widgets` calls. Both plain and profiled commands
succeed. In each profiled run on a05d1dab, the summary counts **4 requests**, the action counts **3** completed
requests, and dropped is **0**. Comparing this report to itself **exits 0**, although the abandoned request's
site counts were never merged and the denominator includes it. The baseline has the same failure. The first-touch
reservation can also remain unresolved when its owner never closes; absence of overflow does not make that data
complete. The guide's statement that such a capture is invalid for compare is therefore too broad.

**Smallest fix:** make final export record/refuse still-open windows (the existing entered-window and closed
action-window counts already expose the mismatch), not just evicted windows. Do not change application fiber
execution or pretend the 1,024 cap detects every cancellation. Preserve non-final snapshot semantics if callers
need to inspect a running process. Keep the documented retention limit even after adding the finalization check.

### D6 — P2: the new schema check still accepts identity-less and key-less data

**Locations:** `profile_compare.rb:73–104,128–135`. Incomplete C2 validation at the newly expanded boundary;
these are CLI malformed-input probes, not claims that the normal writer emitted these particular reports.

Starting with the passing two-run `ProfileTest#report` fixture:

* Change both identities to `{"mode":"command"}`, with no argv: **exit 0**. `{"mode":"banana"}` also exits 0.
  Thus two reports with no usable logical command can still be called comparable.
* Set both `meta.ruby` and `meta.rails_env` to `[null]`: **exit 0**, despite having no known Ruby/environment.
* Set base ranked rows to `[{"warm":[10,10]},{"warm":[0,0]}]`, head to
  `[{"warm":[30,30]},{"warm":[0,0]}]`, omitting site keys: **exit 0**, no regression. The rows silently overwrite
  each other at the nil hash key. A collection and finite warm vectors alone are not a complete line identity.
* A window count `"ten"` or `outside_requests:"bad"` raises `TypeError` and exits **1** instead of a diagnostic
  **2**. These errors also existed on the baseline; the new schema boundary does not contain them.

**Smallest fix:** validate the discriminated identity (`command` with nonempty String argv, or the complete
workloads identity), known nonempty Ruby metadata, String env metadata, nonnegative integer window counts, nested
object types and unique required row keys before arithmetic, `dig` or `to_h`. Empty `RAILS_ENV` is legitimate for
non-Rails command windows; do not reject it merely for being empty. Keep malformed evidence separate from an
allocation regression and from a measured zero; no general schema framework is needed.

### Cookie Path check and non-blocking limit

The actual census client and MockClient now agree for explicit/default directory paths, same-name cookies on `/`
and `/private` (including their header order), expiry, and a login URL containing a query. Both send the
`Path=/private` cookie to `/privateish`, matching Rack::Test 2.3.0's prefix policy; that is **not** a new browser-RFC
guarantee. There is still one verified, low-priority normalization difference: with
`Set-Cookie: auth=yes; Path=/private,/other`, Rack::Test sends it on `/private/me`, MockClient does not. Rack::Test
takes the first comma-delimited path and strips whitespace; MockClient stores the path verbatim at
`workloads.rb:285–287`. Smallest matching fix: apply that same normalization. This is outside the now explicitly
test-bounded equivalence claim, so it is a **P3 nit**, not a demand to implement Domain/Max-Age or full browser
semantics before this prototype can be used.

### Maintainability, documentation and admission conclusion

The first-touch owner/id is a direct fix at the native source of truth, and the cap reuses the existing slot
lifetime rather than adding a second collector. Structured capture identity correctly separates output argv from
logical workload identity. No affected production file crosses 1,000 lines (counter 648, report 574). No broad
decomposition or generic validation/transport framework is warranted. The structural improvement still needed is
an explicit completed-capture boundary: initial receipts and live counters must not be indistinguishable from
final, comparable evidence. Fix header/env provenance in its canonical producer, not with comparison exceptions.

README's 1% statement is now correctly historical, specific to the Blog's five GETs before policy changes.
The census guide bounds equivalence to the contract test, and the request-side-effect/disposable-services warnings
are appropriate. The profile guide correctly retains child-fiber undercounting, non-main-Ractor exclusion and
up-to-1,024-fiber retention. Its blanket filtering, enabled-GET replay and incomplete-capture refusal claims need
D1–D6; an explicit prototype label or a warning to inspect secrets does not close a demonstrated export leak.
The guide allows nil warm actions later in the same section, although its new opening schema bullet says every
action has a finite number; the implementation correctly lists nil actions as not compared. That wording can be
made consistent when updating the validity claims.

The documented Campfire A/A line failure and warning that exit 1 is not a confidence bound are honest. **No floor
policy was chosen or tuned here.** A green comparison is not a general absence-of-regression guarantee, and the
current extra false greens are completeness/identity defects, not a reason to raise or lower `--min`.

Fresh-process gemspec controls load zero new features and define no Lowrail on both pins. Requiring the off
profiler defines no Lowrail and loads only that file; enabling profiling and then Active Support alone defines
none of Action Controller, Active Job, Action Mailer or Action Cable. Together with the three passing suites these
are bounded invariant-1/invariant-7 controls, not a claim that every app/scheduler is safe. Repairs must continue
to leave app returns/exceptions and lazy loading alone and record unsupported filters/env/capture states explicitly.

**Not rerun or claimed:** Campfire's 634 tests, any other corpus suite, historical YAML/DSL or A/B equivalence
cohorts, `lowrail verify`, `lowrail bench`, timing, instruction counts or speed. The author's Campfire results and
historical measurements above remain attributed evidence. This is a **review-document-only** change; D1–D6 are
not implementation fixes. C3/C5 and the original narrow repros are confirmed, not an approval of recording or
comparison as a generally safe workflow.

## Resolution of the second confirm review (2026-11-18)

Fixed on main after `a05d1dab`, preferring refusal over new machinery. Each finding has a regression test through
the CLI or the DSL that fails on `a05d1dab` (the new tests in a worktree of it: 16 runs, 5 failures, 1 error; D2
checked apart by restoring only its old Accept condition, which drops the XML Accept). The compare floor policy is
unchanged.

| Finding | Change | Test (and what it gives on a05d1dab) |
| --- | --- | --- |
| D1 | `parameter_filter` returns no filter unless every `filter_parameters` entry is a Symbol, String or Regexp: with a Proc, which may read Rails' merged params, no request values are kept and the shape is commented out as unfiltered (its own group, never merged with filtered shapes). The cache keeps frozen copies of String entries, so an in-place change rebuilds the filter. What filtering returns is copied and frozen, not the input. | `test_record_filters_every_value_and_keeps_json_gets_as_gets`: the review's three-argument Proc on `/widgets/1.proc-format-secret?credential=proc-secret` and the in-place `+"not_a_key"` → `"credential"` String on `/widgets.string-format?credential=string-secret`; neither secret is in any written file, and the Proc shape is commented out with its reason (a05d1dab: exported). |
| D2 | A recorded GET keeps its Accept as sent; the anyway-sent list now applies to writes only. | Same test: `/lookup?q=xml` with `application/xml` is declared with that Accept and the app sees it on replay through MockClient (a05d1dab: no Accept, `text/html`). |
| D3 | The receipt written before the passes is marked `complete: false` and writes no `runN/measured.json`; only the final write, after all counted passes, writes it with `complete: true`. `compare` requires every run's entry complete with at least one measured request. | `test_workloads_captures_compare_by_what_they_measured`: the same block with `exit(0) if n == 2` (one warmup, nothing measured), compared with itself, exits 2 (a05d1dab: exit 0). |
| D4 | `Request#to_h` digests header and `env:` values that are JSON values (String, Integer, finite Float, true, false, nil, Arrays and String-keyed Hashes of them) as values; any other object is listed in `headers_uncertified`, carried into each run's measured entry, and `compare` refuses that capture. | `test_requests_are_frozen_copies_and_the_manifest_covers_header_values`: `env: {"app.flag" => 1}` and `2` have different digests; an `Object.new` value is uncertified (a05d1dab: equal digests). Compare test: an `uncertified` measured entry exits 2. |
| D5 | The report's summary has, per run and kind, `completed` windows (the sum of its action windows) next to `windows`; the Markdown lists a run with unfinished windows, and `compare` refuses one where they differ. Non-final snapshots and the 1,024 cap are unchanged. | `test_unfinished_windows_are_not_comparable`: the review's `Fiber.yield` controller abandoned once, then three requests: summary 4 and completed 3 in each run, and comparing the report with itself exits 2 (a05d1dab: no `completed`, exit 0). |
| D6 | One strict schema check before any arithmetic: identity `command` with a nonempty String argv, or `workloads` with a String manifest and host and complete measured entries, otherwise exit 2; one nonempty String Ruby and one String environment (empty allowed); `exit`, `dropped` and `summary` one per run with nonnegative Integer counts for every kind; `outside_requests` a Hash; unique String `site` per line and unique `name` (nil allowed) per action. An unreadable JSON file is exit 2 too. | `test_compare_needs_complete_comparable_captures`: `{"mode":"command"}`, `{"mode":"banana"}`, `ruby`/`rails_env` `[null]`, window count `"ten"`, `outside_requests: "bad"`, key-less 10→30 rows, a duplicated site and unfinished windows all exit 2 (a05d1dab: 0, or 1 on the type errors). |
| P3 | MockClient takes a cookie's Path as Rack::Test does: the first comma-separated value, stripped. | `test_census_and_profile_send_the_same_requests` adds `Path=/private,/other`: both clients send it on `/private/me` (a05d1dab: A and B differ). |

`docs/profile.md` now states the Symbol/String/Regexp-only rule, that a GET keeps its Accept, the unfinished-window
refusal next to the fiber-retention limit, and the strict validity rule (which allows nil warm values for actions
that ran once per process, consistent with the not-compared list). `docs/upstream/census.md` notes uncertified
`env:` values and the Path normalization.

The three suites pass: 18 runs, 168 assertions. Rechecked on Campfire (`bin/rails test -v`, 634 tests): per-test
outcomes identical with no gem, gem listed but off, and both profiled runs (632 pass, 2 skip); all 18 processes
load every feature outside Lowrail, Bundler and RubyGems in the same order; no `[lowrail-profile]` warning; every
window finished (666 requests, 16 jobs, 19 Cable actions completed per run).

## Third confirm review of 10e646e4 (2026-11-18)

**Verdict: changes.** This fourth review round confirms the original D1–D6 repros and P3 are corrected, but
finds three must-fixes under the requested strict severity bar: preserving Accept introduces an export of a
value Rails filters; a complete workload receipt still certifies requests it did not cover; and the schema
check still returns green on malformed/identity-less reports. No floor-policy change or profiler redesign is
requested. This commit records the review only; it does not fix the findings.

### Scope and fresh checks

Loaded `thermos`, `thermo-nuclear-review` and `thermo-nuclear-code-quality-review`. One reviewer applied both
rubrics in this thread as requested, without subagents or other threads; this is not independent dual-reviewer
coverage. Read the fix author's resolution above, the eleven-file `10e646e4^..10e646e4` diff, the relevant
producers/readers, and Rails' ParameterFilter and request filtering code. The implementation pins are
`a05d1dab1d3d680ee91cc0e4b2fdeb1f33372164` and `10e646e403018de71f964660bb710cd6d93b6bd8`.
Unrelated intervening main changes are excluded. No implementation or permanent test was changed; nothing was
posted upstream. The fix's GitHub commit-to-pulls lookup returned no PRs to inspect.

The earlier scratch harnesses were not in this orb. Reconstructed their documented inputs using the repository's
minimal Rails fixture, synthetic values and disposable outputs, rather than claiming the old files were recovered.
Used mise Ruby **4.0.9**, revision `3e93b23afc`, Rails **8.1.4**, sqlite3 **2.10.2**, bcrypt **3.1.22**, Rack
**3.2.8**, rack-test **2.3.0**, Linux x86-64. Missing gems were installed in the orb; repository dependencies were
not changed. All three requested files passed on the exact head:

```text
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/profile_test.rb --verbose
13 runs, 142 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/workloads_test.rb --verbose
3 runs, 22 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/load_hooks_test.rb --verbose
2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Total: **18 runs, 168 assertions**, independently reproduced. Loading the head's profile/workloads tests with
only the baseline's library and test helper gives **16 runs, 123 assertions, 5 failures, 1 error, 0 skips**.
Those combined tests stop at the first assertion; the separate probes below establish the masked cases too.

### Original D1–D6 and P3 before/after ledger

| Finding | Reproduced on a05d1dab | Observed on 10e646e4 |
| --- | --- | --- |
| D1 | The three-argument Proc depending on `original["controller"]` and the in-place `"not_a_key"` → `"credential"` String mutation export `proc-secret` and `string-secret`, although Rails masks both. | Neither value occurs in recorded JSON or generated workloads. The Proc shape is disabled with its reason. Symbol, String and Regexp controls mask their values; the app's mutable String remains unfrozen. **Original param cases fixed; new header leak E1 below.** |
| D2 | Recording `/lookup?q=xml` with `application/xml` omits Accept; actual MockClient replay returns `text/html`. | The declaration and app both see `application/xml`; JSON and explicit HTML controls also retain their Accept and GET query. **Original XML case fixed.** |
| D3 | Same file, `exit(0) if n == 2`, different first paths `?which=one`/`?which=two`, same output directory with reports copied aside: both runs exit 0; measured requests 0, digest `a2c0a43afea3c8e0`; compare 0. | Initial receipt has `complete:false`, no `runN/measured.json`; comparing either the stopped capture to itself or the differing early-path captures exits 2. Complete ordinary runs have `complete:true` and 20 measured requests. **Original case fixed; coverage gap E2 remains.** |
| D4 | Complete captures using `env: {"app.flag" => 1}` versus `2` have identical manifest/measured digests and compare 0. A capture with `Object.new` also compares green to itself. | Integer values change manifest and measured digests; compare 2. `Object.new` is listed under `headers_uncertified`, propagated as a measured `uncertified` request, and compare 2. **Fixed in these cases.** |
| D5 | One yielded/abandoned request followed by three completed requests: summary windows 4, action windows 3, dropped 0; self-compare 0. | Each summary has windows 4 and completed 3, Markdown says unfinished, self-compare 2. **Original case fixed.** |
| D6 | No command argv, unknown mode, `[null]` Ruby/environment, duplicate site and key-less 10→30 rows compare 0; String windows and String `outside_requests` exit 1. | Each exits 2. Invalid/unreadable JSON also exits 2. Valid empty environment and a nil-name/nil-warm action are accepted; that action is explicitly not compared. **Named cases fixed; E3 remains.** |
| P3 | `auth=yes; Path=/private,/other` is sent to `/private/me` by Rack::Test but not MockClient. | Both send it there and neither sends it to `/public`. **Fixed for the requested Path normalization, not a broader browser claim.** |

Private probes and generated data are retained under `.amp/in/orb-backup/fourth/`: `repro.rb`, `edges.rb`,
`header_and_finalizer.rb`, `schema.rb`, `remaining.rb` and `invariants.rb`; `base/` is the detached old worktree.
Each takes a repository path first; the Rails probes use a separate disposable app/output path. For example:

```sh
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fourth/repro.rb . .amp/in/orb-backup/fourth/head
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fourth/schema.rb . .amp/in/orb-backup/fourth/schema-head
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fourth/edges.rb . .amp/in/orb-backup/fourth/head/app
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fourth/header_and_finalizer.rb . .amp/in/orb-backup/fourth/head/app
```

### E1 — Must-fix: GET Accept preservation newly exports a Rails-filtered value

**Locations:** `gem/lib/lowrail/profile.rb:196–204`, `shape_of` and generated request names/headers in
`gem/lib/lowrail/workloads.rb`. Introduced for these XML headers by the changed Accept condition in `10e646e4`.

Set `Rails.application.env_config["action_dispatch.parameter_filter"].replace([:accept])` and serve
`GET /lookup?q=safe` with `HTTP_ACCEPT=application/xml; token=accept-secret`. In the actual controller,
`request.filtered_env["HTTP_ACCEPT"]` is `[FILTERED]`; the request succeeds. On the fix both shapes JSON and the
generated enabled GET export the literal header, including the secret, in `accept`, the request name and
`headers: { "Accept" => ... }`. The baseline omits this XML Accept and exports neither synthetic header secret.

Replace the filter list with `[->(k, v) { v.replace("[FILTERED]") if k == "HTTP_ACCEPT" }]` and repeat with
`application/xml; token=proc-accept-secret`. Rails again masks the header. The fix refuses params and comments
the request out, yet still writes that secret into its name/header and JSON. The comment even says no request
values were kept. All four Rails filtering controls (both requests in both runs) returned true on both pins.
This is Rails' real filtered-env contract, not an assertion that `filtered_parameters` contains headers.

**Smallest fix:** apply the supported name/pattern filter to the `HTTP_ACCEPT` value before grouping or retaining
it, and disable a shape whose Accept was masked. With an unsupported filter/Proc, retain no raw Accept either;
the shape is already refused, so reproducing Proc env context is unnecessary. Redact/omit the value in names and
commented declarations as well as executable declarations. Keep unfiltered XML/JSON replay controls.

### E2 — Must-fix: a parent's final receipt certifies uncovered request windows

**Locations:** `gem/lib/lowrail/profile_workloads.rb:50–55,70–90`, `ProfileReport#meta`, and
`gem/lib/lowrail/profile_compare.rb:90–98,128–139`. Remaining completeness gap, present on both pins; the new
`complete` marker closes the single-process early-stop repro but does not establish coverage of the whole run.

Use the same workload file in both captures:

```ruby
parent = Process.pid
get("/widgets", name: "forked") do |n|
  if n == 11
    pid = fork
    Process.wait(pid) if pid
  end
  exit(0) if n == 12 && Process.pid != parent
  { path: Process.pid == parent ? "/widgets?which=parent" : "/widgets?which=#{ENV.fetch('CHILD')}" }
end
```

Capture with `CHILD=a` and `CHILD=b`. Every run exits 0, has **2 processes, 21 request windows, 21 completed,
0 dropped**, but its only `measured.json` describes **20** parent requests and digest `f3d637c3953295dd`.
The child exits after its first measured request and never writes a complete receipt. The fixture's per-PID
request log verifies the child serves `which=a` versus `which=b`. The parent receipt and manifest are identical;
**compare exits 0 with no problems or regressions on both pins**. Requiring one complete entry per run does not
require one for every process contributing data.

There is also a one-process control: register `at_exit { Rails.application.call(Rack::MockRequest.env_for(
"https://localhost/widgets?which=#{ENV.fetch('AFTER')}")) }` in an otherwise fixed workload file. `AFTER=a` versus
`b` again gives 21 completed windows against a 20-request receipt and compare 0. The complete receipt precedes
the app's exit work, while the profiler's later writer includes it.

**Smallest fix:** for workload comparisons, require each measured request count to equal its run's captured
request windows, and conservatively refuse contributing multiple processes unless all are covered by the
certificate. Refusing multi-process workload evidence needs no per-PID receipt framework. Leave ordinary
multi-process command profiling alone: a parent with 3 requests and children with 3 and 4 gave 3 processes,
10 windows and 10 completed on the fix, and valid self-compare 0. Do not change app fork/exit behavior to force
the counters to fit the receipt.

### E3 — Must-fix: the new strict schema still admits malformed evidence

**Locations:** `gem/lib/lowrail/profile_compare.rb:90–94,130–134,202–215`. Remaining D6 boundary, reproduced on
both pins, not an allegation that the normal writer emitted these edited reports.

Starting from the otherwise valid two-run fixture (10 windows/completed per run, complete collections, known
Ruby/environment and finite warm vectors):

* Set workload identity to `{"mode":"workloads","manifest":"","host":"","measured":[
  {"requests":10,"complete":true,"sha256":""},{"requests":10,"complete":true,"sha256":""}]}` in both reports.
  **Compare exits 0**, despite no manifest or request digest at all. The measured count matches the windows;
  E2's count check alone would not close this case.
* Keep a valid command identity but set each summary's `objects_per_request` to `"bad"`. **`--json` exits 0**
  with no problems, while default Markdown raises `NoMethodError` at `round` and exits **1**, not the promised
  diagnostic 2. That field is read after the purported all-keys schema boundary without checking its type.

**Smallest fix:** reject empty manifest/host/request-digest identities and validate the summary number before
the formatter consumes it, using the same finite-number rule as warm vectors. Keep valid empty `rails_env`
distinct from an unknown identity. These are small additions to the canonical validator, not a reason for a
generic schema framework. They are must-fixes here because they return green on invalid evidence and contradict
the documented strict-check guarantee; a mere false exit 2 or missing diagnostic would not meet that bar.

### Maintainability, invariants, nits and limits

**No independent maintainability blocker or separate nit.** Refusing Proc-based parameter recording is simpler
than recreating Rails' merged context; immutable String snapshots, JSON-value checks, and deriving completed
windows from existing action counts stay in their owning modules. No changed production file crosses 1,000
lines (largest: `profile_report.rb`, 582). The needed simplification remains a conservative admission boundary,
not another identity store or general transport/schema abstraction.

Fresh-process controls passed on both pins: gemspec evaluation loads zero features and defines no Lowrail;
requiring the unset/empty profiler defines no Lowrail; enabling it and loading Active Support defines none of
Action Controller, Active Job, Action Mailer or Action Cable. The passing request/Cable/job tests exercise
unchanged returns and exception identity. No app-outcome or lazy-loading regression was found in these bounded
controls, and none of the proposed refusals should alter app execution.

The docs accurately describe the original fixed repros, JSON env refusal, nil warm-action handling and bounded
cookie Path behavior. Their blanket "no request values"/filtered-value promise is false for E1, and complete
comparable-capture/strict-malformed-input claims remain too strong under E2/E3. The author's Campfire outcome,
process-load-order and completed-window results above remain attributed evidence: **Campfire's 634 tests were
not rerun here**, nor was another corpus, `lowrail verify`, `lowrail bench`, timing, instruction counting, speed,
unrestricted scheduler/Ractor or sanitizer/OOM coverage. The compare floor policy is deliberately unchanged.

## Resolution of the third confirm review (2026-11-18)

Fixed on main after `10e646e4`, by refusing rather than adding machinery; the floor policy is unchanged. Each
finding has a regression test that fails on `10e646e4` (the new tests in a worktree of it: 3 runs, 3 failures; the
cases behind each first failing assertion were checked apart and fail too).

| Finding | Change | Test (and what it gives on 10e646e4) |
| --- | --- | --- |
| E1 | `note` passes `HTTP_ACCEPT` through the app's (Symbol/String/Regexp-only) filter, as `filtered_env` does, before grouping or keeping it; a masked Accept marks the shape filtered, so it is commented out and its name and header say `[FILTERED]`. With an unsupported filter (a Proc) or none, no Accept is kept at all. | `test_record_filters_every_value_and_keeps_json_gets_as_gets`: `[:accept]` with `application/xml; token=accept-secret`, and the existing Proc list with `...token=proc-accept-secret`: neither secret is in any written file; the first shape is `# get lookup_path, name: "GET /lookup ([FILTERED])", headers: { "Accept" => "[FILTERED]" }, ...`. The unfiltered JSON and XML GET replays still keep their Accept (10e646e4: both secrets exported). |
| E2 | For `--workloads`, `compare` requires each run to be one process whose request windows equal its measured requests; ordinary command captures keep any number of processes. | `test_workloads_captures_compare_by_what_they_measured`: the review's fork at n=11 (2 processes, 21 windows, 20 measured) and an `at_exit` request (1 process, 21 windows, 20 measured), each compared with itself, exit 2 (10e646e4: exit 0). Compare test: 9 measured against 10 windows exits 2. |
| E3 | Empty manifest, host and measured digests are refused; every summary row must have an Integer `processes` and a finite `objects_per_request` before anything formats it. | `test_compare_needs_complete_comparable_captures`: the empty workloads identity exits 2 (10e646e4: 0); `objects_per_request: "bad"` with Markdown output exits 2 (10e646e4: `NoMethodError`, exit 1). |

`docs/profile.md` now says Accept is filtered and dropped with unsupported filters, and that workload evidence must
be one fully measured process with non-empty identity values.

The three suites pass: 18 runs, 183 assertions. Rechecked on Campfire (`bin/rails test -v`, 634 tests): per-test
outcomes identical with no gem, gem listed but off, and both profiled runs (632 pass, 2 skip); all 18 processes
load every feature outside Lowrail, Bundler and RubyGems in the same order; no `[lowrail-profile]` warning; each
run's 2 processes completed every window (666 requests, 16 jobs, 19 Cable actions), and that command capture
compared with itself exits 0, so multi-process command evidence is still accepted.

## Fourth confirm review of 4893b90e (2026-11-18)

**Verdict: nits. No must-fixes.** This fifth review round reproduces E1–E3 on `10e646e4` and confirms their
correction on `4893b90e`. No introduced export of a Rails-filtered value, app-outcome change, or false-green
comparison was found in the exercised cases. One documentation precision nit remains about helper processes;
it does not weaken the admission gate or require more profiling machinery. This commit records the review only.

### Scope and executed checks

Loaded `thermos`, `thermo-nuclear-review` and `thermo-nuclear-code-quality-review`. As requested, one reviewer
applied both rubrics here without subagents or other threads; this is not independent dual-reviewer coverage.
Read the fix author's resolution above, the five-file `4893b90e^..4893b90e` diff, its downstream producers and
readers, and Rails' `FilterParameters` and `ParameterFilter`. Compared detached
`10e646e403018de71f964660bb710cd6d93b6bd8` with `4893b90e8e9f9e29ece6a66029b0241393bc76da`;
unrelated intervening main changes were not attributed to this fix. The commit's GitHub pulls lookup returned
no PRs. Nothing was posted upstream, and no implementation or permanent test was changed.

The earlier scratch files were absent from this orb. Reconstructed the documented repro inputs rather than
claiming to have recovered those harnesses. Probes used synthetic values, the repository's minimal Rails fixture
and disposable outputs. Used mise **Ruby 4.0.9**, revision `3e93b23afc`, Linux x86-64; Rails **8.1.4**, sqlite3
**2.10.2**, bcrypt **3.1.22**, Rack **3.2.8**, rack-test **2.3.0**. Installed missing gems in the orb without changing
repository dependency files. The requested suites on the exact fix all pass:

```text
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/profile_test.rb --verbose
13 runs, 157 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/workloads_test.rb --verbose
3 runs, 22 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.9 -- ruby -Igem/lib -Igem/test gem/test/load_hooks_test.rb --verbose
2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Total: **18 runs, 183 assertions**, independently reproduced. Loading the fix's three changed profile test cases
with the baseline's library and test helper gives **3 runs, 41 assertions, 3 failures, 0 errors, 0 skips**. Those
combined tests stop at their first failure; separate probes below cover the later cases too.

### E1–E3 before/after ledger

| Finding and exact input | On 10e646e4 | On 4893b90e |
| --- | --- | --- |
| E1: GET `/lookup?q=safe`, filter `[:accept]`, Accept `application/xml; token=accept-secret`; repeat with a Proc masking the `HTTP_ACCEPT` key and `proc-accept-secret`. | The changed regression test exports both secrets. Independent requests with the same filters and distinct synthetic tokens also export both, while the actual controller's `request.filtered_env["HTTP_ACCEPT"]` is `[FILTERED]`. | Neither masked token occurs in any recording output. A masked name/header reads `[FILTERED]` and the declaration is commented out; a Proc shape has no Accept or params and is commented out. |
| E2: the preceding review's same-file fork at n=11, child exit at n=12, parent `/widgets?which=parent`, child `/widgets?which=a` versus `b`. | Per run: 2 processes, 21 request windows, 21 completed, 0 dropped; the sole complete receipt has 20 requests, digest `f3d637c3953295dd`. Child request logs confirm `a` versus `b`. Self-comparisons and `a` against `b` all exit 0. | Same counts, same receipts and actual child requests; all those comparisons exit 2 for uncovered windows/processes. App commands still exit 0. |
| E2: fixed workload with `at_exit { Rails.application.call(Rack::MockRequest.env_for("https://localhost/widgets?which=#{ENV.fetch('VARIANT')}")) }`, `VARIANT=a` versus `b`. | Per run: 1 process, 21 request windows/completed, 0 dropped, 20 measured. Actual final requests differ; self-comparisons and `a` against `b` all exit 0. | Same app behavior and counts, but all comparisons exit 2. The count check closes this gap without relying on the process check. |
| E3: otherwise valid two-run fixture, 10 request windows/completed per run; workloads identity with empty manifest, host and each measured sha256, complete=true and requests=10. | JSON and Markdown both exit 0. Empty each field separately also exits 0. | All four variants exit 2 in both output formats. |
| E3: valid command identity, summary `objects_per_request: "bad"`. | JSON exits 0; Markdown raises `NoMethodError` at `round`, exit 1. | Both formats give insufficient evidence, exit 2, without a formatter exception. |

The independent Accept matrix also checks `['cCeP']`, `['http_accept']`, `/ACCEP/`, `/accept/i`,
`/\AHTTP_ACCEPT\z/`, Rails-precompiled `['headers.accept', :accept]`, and an in-place String filter change
from `not_a_key` to `accept`. Rails masks each control; only the baseline exports its header. Conversely,
case-sensitive `/accept/`, nested `'headers.accept'` and `/headers\.accept/` do not mask the flat uppercase
`HTTP_ACCEPT` in Rails, and Lowrail correctly keeps those headers. Enabled declarations replay their actual
Accept and query through MockClient, including JSON and XML controls. A recorder probe before ParameterFilter
is available keeps no Accept and marks the shape unfiltered without forcing the class to load.

The schema probe independently rejects missing/null/string summary totals, nonfinite totals represented by
`1e999` and `-1e999`, and missing/null/string/float/negative process counts on the fix (the baseline accepts
them in JSON). Finite Integer, zero and fractional totals, empty `rails_env`, and a nil-name/nil-warm action
remain valid in both formats. A real jobs-only capture has 3 completed job windows, no requests and
`objects_per_request: 0.0` per run; self-compare exits 0. A real ordinary command with parent 3 requests and
children 3 and 4 has 3 processes and 10 completed request windows per run; self-compare still exits 0.

Private harnesses and outputs remain under `.amp/in/orb-backup/fifth/`: `review.rb`, `schema.rb`, `invariants.rb`,
detached `base/`, and separate `baseline/`, `fix/`, `schema-base/` and `schema-fix/` outputs. Reproduce from the
repository root (use fresh output paths for the request log):

```sh
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fifth/review.rb .amp/in/orb-backup/fifth/base .amp/in/orb-backup/fifth/baseline-new
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fifth/review.rb . .amp/in/orb-backup/fifth/fix-new
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fifth/schema.rb .amp/in/orb-backup/fifth/base .amp/in/orb-backup/fifth/schema-base-new
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fifth/schema.rb . .amp/in/orb-backup/fifth/schema-fix-new
mise exec ruby@4.0.9 -- ruby .amp/in/orb-backup/fifth/invariants.rb . .amp/in/orb-backup/fifth/fix-new/app
```

### N1 — Documentation precision: only contributing processes are counted

**Location:** `docs/profile.md:261–263`, “a workload that forks … is not CI evidence.” The preceding
one-process/count-equality rule is correct, but this shorthand is broader than the actual exclusion. Add this
before an otherwise ordinary workload declaration:

```ruby
pid = fork { String.new; exit(0) }
Process.wait(pid)
get "/widgets"
```

On both pins the helper opens no window and writes no TSV. Each run therefore has **1 contributing process,
20 request windows/completed and 20 measured requests**; self-compare exits **0**. A helper that instead performs
one Active Job writes its own TSV: **2 contributing processes, 20 request windows/completed, 1 completed job,
20 measured requests**; the baseline accepts it and the fix refuses it (2). That refusal is the requested
conservative policy, not an app-outcome regression or a reason to add per-PID certification.

**Smallest improvement:** say “more than one process contributes profiling windows, or the request-window
count differs from the measured count” instead of implying every fork is rejected. No code change is needed.
This is a nonblocking wording nit: the actual admission rule is documented immediately before it, and the
accepted no-window helper adds no uncovered data. No broader browser, process or scheduler guarantee is claimed.

### Maintainability, invariants and limits

No independent maintainability finding. The fix reuses the canonical ParameterFilter, the existing final
receipt and summary, and the existing validator. It adds no transport, per-PID identity store, wrapper or generic
schema framework. The affected production files remain 359 and 255 lines; no file crosses 1,000 lines. The
single-process restriction is scoped to workloads; checking the normal report producer shows that finite totals
and Integer process counts are its existing output contract, including jobs-only captures.

Fresh-process gemspec evaluation loads no features and defines no Lowrail; requiring the unset/empty profiler
defines no Lowrail. Enabling the counter and then loading Active Support forces none of Action Controller,
Active Job, Action Mailer or Action Cable. Fifteen synthetic requests have identical query, raw Accept and Rails
filtered-env results plain and profiled, and the app's mutable filter String remains unfrozen. The requested
suites also pass their existing return/exception-identity, incompatible-counter and frozen-hook controls. These
bounded checks found no app-outcome or lazy-loading regression. No lowering or specialization changed.

Apart from N1, the guide describes the exercised filtering, workload-coverage and summary-validation behavior
accurately. Previously confirmed findings were not reopened. The author's Campfire results remain attributed
evidence: **Campfire's 634 tests were not rerun here**. Neither another corpus nor `lowrail verify`, `lowrail bench`,
timing/instruction measurements, speed, unrestricted Ractor/scheduler or sanitizer/OOM coverage was run or is
claimed. The floor policy is unchanged; this approval of E1–E3 does not turn compare's heuristic into a confidence
bound or establish a new support claim.

## Floor between invocations (2026-11-18)

Thomas decided the open floor question recorded in the first confirm resolution: `compare BASE HEAD --aa BASE2`
takes an A/A pair, a second profile of the unchanged base, and a row's noise is the base's spread across all runs
of both base reports (so the pair's difference and each one's own spread) or head's own spread, whichever is larger;
the line and action floors keep their form and `--min`. Without `--aa`, compare lists what exceeds the spread inside
each capture, says it is not a gate, and exits 0 (2 without valid evidence). The A/A report passes the same strict
schema check as base and head and must match base in identity, seed, Ruby, environment and runs; workloads evidence
from more than one contributing process is still refused. The documented CI step profiles the base twice.

`test_compare_gates_on_the_floor_of_an_a_a_pair` covers a Campfire-shaped line and action (small spread inside each
capture, larger between them) passing, a planted regression beyond the pair's floor failing, a mismatched or invalid
pair exiting 2, and no pair not gating; it fails on the code before. On Campfire two unchanged `-v` captures whose
json line moved 0.22 and 0.12 inside each reproduce the false regression (`json/common.rb:364` +1.86 against 1.0,
exit 1 before); with any of three other unchanged captures as the A/A report they exit 0, and the planted
`html_escape` still exits 1 with its 3 regressions ([profile.md](../profile.md#compare-two-reports-in-ci)).

## Confirm review of the A/A floor, 16dbc027 (2026-11-18)

**Verdict: changes. One P2 must-fix, AA1; two nonblocking nits, AA-N1 and AA-N2.** A supplied A/A file containing
JSON `null` bypasses validation and disables the gate, so even the documented CI pipeline passes invalid evidence
with detected regressions. The floor arithmetic otherwise implements the chosen policy. Its sensitivity and
coverage limits are real, not a confidence guarantee, but are not additional correctness defects under that policy.
This is a review-document-only change; the finding is not fixed here.

### Scope and executed checks

Loaded `thermos`, `thermo-nuclear-review` and `thermo-nuclear-code-quality-review`. One reviewer applied both
rubrics in this thread, without subagents or other threads, as requested; this is not independent dual-reviewer
coverage. Read `AGENTS.md`, `docs/PLAN.md`, the earlier review/resolutions, the complete six-file
`9a944c8aa40b8e9a96ea7b7ea3ae9ab8291f45a8..16dbc027ed9b148d026ce9ea02252702e07fafb0` diff, the comparison
reader, report producer, workload receipts and CLI consumers. The checkout started at `cacec69e`; the relevant
implementation, tests, README and profile guide are identical to the requested commit. Unrelated main changes
are excluded. The reviewed commit's GitHub pulls lookup returned no PRs. Nothing was posted upstream.

Used mise **Ruby 4.0.7**, revision `229531a6cf`, Linux x86-64; Rails **8.1.4**, sqlite3 **2.10.2**, bcrypt
**3.1.22**, Rack **3.2.8**, rack-test **2.3.0**. Installed missing test gems in the orb without changing dependency
files. All three requested suites pass:

```text
mise exec ruby@4.0.7 -- ruby -Igem/lib -Igem/test gem/test/profile_test.rb --verbose
14 runs, 184 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.7 -- ruby -Igem/lib -Igem/test gem/test/workloads_test.rb --verbose
3 runs, 22 assertions, 0 failures, 0 errors, 0 skips
mise exec ruby@4.0.7 -- ruby -Igem/lib -Igem/test gem/test/load_hooks_test.rb --verbose
2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Total: **19 runs, 210 assertions**. A separate scratch harness exercises **44 comparison cases in both JSON and
Markdown**, plus three executions of the guide's actual Compare step under
`bash --noprofile --norc -eo pipefail`, with a local `bundle exec` shim to the real CLI. It supplies synthetic
reports, not Campfire data. Harness and outputs remain private under `.amp/in/orb-backup/aa-confirm/`:

```sh
mise exec ruby@4.0.7 -- ruby .amp/in/orb-backup/aa-confirm/probe.rb
```

### AA1 — P2 must-fix: JSON null in a supplied A/A file silently disables the gate

**Locations:** `gem/lib/lowrail/profile_compare.rb:52–53,166–174`, reached by
`gem/exe/lowrail-profile:69–75`. Introduced by the new optional A/A-report selection.

The constructor uses `nil` for an omitted filename, but `JSON.parse("null")` also returns `nil`. `gate?` tests
only that parsed value, so `reports` excludes the supplied file before the strict validator can reject it. A
readable, syntactically valid JSON file with no report thus takes the advisory path rather than exit 2.

With matching, otherwise complete two-run reports, base line `[100.0,100.0]`, head line `[130.0,130.0]`, base
action `[1000.0,1000.0]`, head action `[1100.0,1100.0]`:

| A/A input | CLI and explicit-pipefail CI exit | Result |
| --- | --- | --- |
| The valid base report | 1 | Two regressions: line +30 against 1; action +100 against 20. |
| A file containing `null` | **0** | JSON has `status:0`, `gate:false`, `problems:[]`, and both regressions. Markdown incorrectly says no A/A pair was supplied. |
| No `--aa` | 0 | Same advisory result, intentional only in this case. |

The null file also returns 0 against unchanged head data, so this is an invalid-evidence admission defect, not
just a difference in regression classification. Other tested non-report JSON values (`false`, `true`, `0`, an
Array, an object and a String) correctly exit 2; unreadable A/A evidence is covered by the passing profile suite.

**Smallest fix:** preserve the distinction between an omitted argument and an invalid parsed report. For example,
normalize a parsed null to the existing invalid-report sentinel when a filename was supplied, so it still reaches
`report_problems`; no new schema framework or CLI mode is needed. Keep the intentional no-argument advisory path.
Add a CLI regression for `--aa` pointing to a file containing `null`, with unchanged and regressing head controls,
requiring exit 2 and an A/A-specific problem in both output formats. This must be fixed because it produces green
CI on invalid evidence and contradicts the guide's strict A/A-validation promise, not because advisory mode is
inherently forbidden.

### Floor, missing-row and admission findings

The formula is correct for the documented heuristic: maximum minus minimum across **all** base and A/A runs,
or head's own spread if larger. It is not the spread of capture means, does not accidentally include the head's
mean shift in the base floor, and retains within-capture outliers. The same rule is applied separately to each
line/action and each window kind. Asymmetric three-run probes for request, job, mail and Cable data give line
delta 7, floor 6, and action delta 70, floor 60. Equality passes, an extra 0.1 fails, head's larger own spread wins,
and `--min 10` gives line/action minima of 10/200. The retained action 2× multiplier and 0.1% share are empirical
policy, not statistically derived confidence limits.

The requested adversarial cases have these concrete outcomes:

* **Unbounded noisy pair:** with the same stable base/head above and A/A line/action `[100000.0,100000.0]`,
  exit 0, `gate:true`, no problems or regressions. The line floor is 99,900 and action floor 198,000. There is no
  quality cutoff: selecting a worse pair can conceal an arbitrarily large finite planted increase. This is loss
  of detection power under the chosen floor, not proof that the change is harmless. Command identity does not
  certify that someone actually captured unchanged code; these files are trusted measurement inputs, not an
  attestation format. Clamping the floor would invent detection confidence, not repair it.
* **A line present in base/head but absent from the A/A ranked collection:** base 100, head 130, A/A absent
  becomes A/A zero, noise/floor 100, exit 0. An absent collection is rejected (2); an absent row in a complete
  collection is the documented measured-zero case. The report producer includes every ranked site, not only
  the displayed top N. Treating genuine absence as zero is consistent; it can still make the pair uninformative.
* **A missing, renamed or nil-warm A/A action:** a stable action increase of 100 is excluded, exit 0,
  `gate:true`, and explicitly listed in `not_compared` as absent/no warm A/A value. The matching-capture check
  concerns identity/seed/Ruby/environment/runs, not identical action sets. This implements the stated exclusion,
  rather than inventing zero or a floor. It is not coverage of that action and must not be advertised as such.

These cases are not promoted to must-fixes merely for lying below the declared floor or being explicitly outside
the compared action set. No universal detection claim is justified. Two nonblocking improvements would make the
limits harder to misread:

* **AA-N1 — Expose sensitivity/coverage on a passing gate.** At
  `profile_compare.rb:261–282`, accepted rows' deltas and floors are omitted from both formats, and Markdown
  summarizes skipped actions only by count/reason. Consider exposing those floors and the skipped names, or a
  clear warning about poor sensitivity/partial action coverage. Do not silently cap noise or reject normal action
  variation without a separately chosen policy. This is a diagnostic nit, not a demand for more machinery.
* **AA-N2 — CI omission is not fail-closed.** README lines 140–144, the guide's explicit advisory paragraph and
  its updated CI recipe agree with the intentional exit-0-without-a-pair decision. The exact published Compare
  step fails with the valid pair, but deleting `--aa tmp/base2/report.json` makes it pass the same two regressions;
  `pipefail` cannot detect a gate the command deliberately did not run. The summary does visibly say **Not a
  gate**, so it is not silent in the output, only green at job level. The guide already warns about this; do not
  claim omission resistance. If that stronger property is wanted, the CI integration must independently require
  `gate:true` (or a distinct required-gate interface). Add an omission-control test if that policy changes.

Beyond AA1, the A/A report correctly gets the existing strict schema and cohort checks. Both output formats
reject changed command/seed/Ruby/environment, failed runs, dropped samples, unfinished windows, short warm vectors,
missing collections, duplicate sites, mistyped summary totals and partially present window kinds with exit 2.
The new profile test also rejects a different run count. For workloads, the extra A/A input preserves refusal of
multiple contributing processes, fewer measured requests than windows, empty digests, incomplete receipts and
uncertified env values; a complete one-process workload control passes. No earlier settled admission rule was
found weakened apart from the null/omitted conflation.

### Maintainability, invariants and limits

No separate structural maintainability finding. Noise belongs in the comparator, the report registry reuses the
canonical validator, and the change adds no dependency or parallel identity model. The comparator grows from
255 to 285 lines; neither production file crosses 1,000 lines. The maintainability repair for AA1 is precisely
to keep option presence distinct from parsed content, not add another wrapper or validation layer.

The changed paths do not instrument the app, install lowering, alter fallbacks or force framework loads. The
requested suites exercise unchanged returns/exceptions, unusable counters, frozen hooks, lazy loading and real
workload replay. Fresh-process controls also show gemspec evaluation loads zero features and defines no Lowrail;
requiring the off profiler loads only its own file and defines no Lowrail. These are bounded invariant-1 and
invariant-7 checks, not general app-support certification. No specialization or guard claim is added, and gaps
are recorded rather than hidden. Repair AA1 in comparison admission without changing application execution.

**Not rerun or claimed:** Campfire or another corpus suite/capture, the author's five unchanged captures or planted
Campfire regression, `lowrail verify`, `lowrail bench`, timing, instruction counts, speed, sanitizer/OOM or broad
scheduler/Ractor coverage. Historical Campfire figures above and in the profile guide remain the builder's
attributed evidence, not results of this confirm review. The heuristic's implemented formula is confirmed; its
statistical power across apps is not.

## Resolution of the A/A floor review (2026-11-18)

* **AA1** fixed: whether `--aa` was given is kept apart from what the file parses to, so an A/A file that is `null`
  (or anything other than a report) is checked like any other report and exits 2 with `gate: true`.
* Also fixed, from the limits listed above: a line the A/A report lacks no longer counts as a zero there. That zero
  made the line's floor its own size, so 100 → 130 passed; the line now takes its floor from base and head alone and
  exits 1.
* AA-N1 and AA-N2 left as recorded: passing rows' floors are not listed, and a CI step that drops `--aa` is
  advisory by design (it prints "Not a gate").
* Both new assertions fail on 16dbc027, each on its own. profile_test 14 runs / 186 assertions, workloads_test 3/22,
  load_hooks_test 2/4, all passing on mise Ruby 4.0.7.
