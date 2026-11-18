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
