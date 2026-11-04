# Background census: Active Job, Action Mailer, Active Storage, Action Cable

The earlier censuses measured mostly web requests. This one covers the work Rails apps run outside them: enqueueing and
performing jobs, building and delivering mail, Active Storage reads and URLs, and Action Cable broadcasts and
subscriptions. It uses 12 census apps on Rails main and Ruby 4.0.9, with Callgrind instructions, stackprof and
allocations per operation in the interpreter and under YJIT, each with an A/A. AS-1 was opened as #59615; nothing else was opened or posted.

**Result.** 194 workloads ran in 12 apps. Where the CPU goes depends on the kind of work:

* **Mail:** gems take 79% (mail 38%, css_parser through premailer 16%, the rest in Mastodon's and Loomio's other
  gems); Rails takes 17%.
* **Active Storage:** Rails takes 82%.
* **Cable:** Rails takes 75%.
* **Jobs:** Rails takes 62%, and mostly in Active Record work the job does, not in Active Job.

Active Job's own bookkeeping is small: retry/discard/execution code at most 0.15% of a performed job, Continuations
0.5% of Fizzy's Continuable job.

The broadest Rails lines are the ones census 8 already covers (`_load_from_sql`, `where_clause`, `index_with`,
`IsolatedExecutionState.[]`, `column_types`). The new finding is in Active Storage:

* Since the filename-sanitizing security fix `0e6a6afe3c`, every `filename.base` and
  `filename.extension` re-sanitizes the whole name.
* `Representable#format` asks for the extension up to three times on every `variant` of a web image.

**One candidate passed every gate and is open as [#59615](https://github.com/rails/rails/pull/59615): AS-1**, which reads the extension once. It saves 22 objects and 33–40% of
instructions per `blob.variant(...)`. On the variant-path workload it saves 7–10% of instructions in all six storage
apps, against A/A noise of at most 1.5% on those workloads.

Nothing else was strong enough, and the reasons are below:

* The top mail lines are already in open mail PRs, and mail's maintainers haven't merged anything since 2026-07-01.
* The top job and event lines are code a maintainer reworked in October.
* The rest is native code or marginal.

## Pins and apps

* Rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed7b9e3557979704a0a7aaa825200317)
  (= `origin/main` on 2026-11-04). Ruby 4.0.9 for the census. ZJIT on Ruby master `9aa0898240`: the candidate's micro and exactness check, and an
  allocation pass over four apps (below).
* Apps (copies `.corpus/census-APP`): Blog, Campfire, Writebook, Fizzy (SQLite), Lobsters, Thinkroom, Mastodon,
  Discourse, Loomio, Chatwoot, Docuseal, CodeTriage. Services: PostgreSQL 15 with pgvector 0.8.1, Redis and
  Memcached, as orb services. Docuseal's pdfium is a stub library (`/usr/local/lib/libpdfium.so`); no workload
  renders a PDF.

| App | enqueue | job | mailer | storage | cable | total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Blog | 1 | 1 | – | – | 2 | 4 |
| Campfire | 2 | 2 | – | 14 | 5 | 23 |
| Chatwoot | 3 | 3 | – (gap) | 16 | 3 | 25 |
| CodeTriage | 1 | 1 | – (gap) | – | – | 2 |
| Discourse | – | 5 | 3 | – | – | 8 |
| Docuseal | 2 | 4 | 2 | 7 | – | 15 |
| Fizzy | 5 | 5 | 2 | 14 | 3 | 29 |
| Lobsters | 6 | 6 | 4 | – | – | 16 |
| Loomio | 8 | 8 | 2 | 15 | – | 33 |
| Mastodon | 5 | 9 | 5 | – | – | 19 |
| Thinkroom | – | – | – | – | 2 | 2 |
| Writebook | 1 | 1 | – | 14 | 2 | 18 |
| **Total** | **34** | **45** | **18** | **80** | **17** | **194** |

Gaps that can't be built on Rails main:

* **Chatwoot mail:** `DbResolverService` calls `_find_all`, which main removed.
* **CodeTriage mail:** maildown needs the removed `registered_template_handler`.

Discourse runs its jobs through `Jobs::*` (Sidekiq workers); Mastodon and Lobsters run some Sidekiq workers too. They
count as `job`, and their enqueue cost is Sidekiq's, so it isn't listed as Active Job enqueue.

## Method

* **Workloads:** [`background_workloads.rb`](../../bench/upstream/census/background_workloads.rb), loaded by
  [`harness.rb`](../../bench/upstream/census/harness.rb) when `CENSUS_SET=background`. Same op contract as the
  request census: each op does one ordinary operation and raises unless it succeeded.
  * **enqueue:** `perform_later` / `deliver_later` through the test adapter. ActiveJob serialization, GlobalID and
    callbacks; the adapter's own `job_to_hash` is harness cost.
  * **job:** performs each job class the app enqueues, from `JSON.parse` of the serialized payload. This covers
    deserialization, GlobalID locate, callbacks, `retry_on`/`discard_on` wrappers and Continuations (Fizzy's
    `Event::WebhookDispatchJob`).
  * **mailer:** `deliver_now` with `:test` delivery, then encoding the delivered message, which SMTP would do.
  * **storage:** a blob or attachment read on a fresh record, `rails_blob_path`, `url_for`, a variant
    representation path, the redirect and Disk-service GETs, and `download`. Docuseal runs in proxy mode.
  * **cable:** model broadcasts through a counting inline adapter delivered on the calling thread, plus channel
    subscribe/perform through `ActionCable::Server::Socket` with a WebSocket stand-in.
* **CPU:** `CENSUS_SET=background CENSUS_WARMUP=50 script/cpu-census run --label bgc --aa --modes interp,yjit` (labels
  `bgc`, `bgc2`), census 8's instruction-sampling Callgrind (`/opt/c8-valgrind`).
* **Allocations:** `script/census run --label bga --aa` (labels `bga`, `bga2`).
* **stackprof** CPU time, as a cross-check: [`stackprof_run.rb`](../../bench/upstream/background/stackprof_run.rb)
  `sp` (stackprof 0.2.28, 6 s windows).
* **Rankings:** [`rank.rb`](../../bench/upstream/background/rank.rb). `cpu` and `stackprof` rank lines breadth first,
  with ≥ 3 apps in tier 1; `REACH=1000` sets the minimum Ir per op; `KIND` filters to one kind; `gems` ranks gem
  lines by gem name. `kinds` gives the median Ir per operation by kind and app.
* **Call counts:** [`probe_calls.rb`](../../bench/upstream/background/probe_calls.rb) prepends a counter to the named
  methods and reports calls and distinct receivers per operation.
* **Outputs:** `.lowrail/private/background-cpu` (`bgc`, `bgc2`, `bgf`), `.lowrail/private/background-census` (`bga`,
  `bga2`), `.lowrail/private/background-stackprof/sp`. They stay in the orb and are not committed.

### A/A

| Measure | Interpreter | YJIT |
| --- | --- | --- |
| Allocations (`bga2 − bga`), 194 workloads | median +0.0 objects/op; moved ≤ −1: 14, ≥ +1: 6 | median +0.0; ≤ −1: 7, ≥ +1: 5 |
| Callgrind Ir (`bgc − bgc2`) | 194 workloads, median +0.02%, p90 of \|Δ\| 3.2% | 80 JIT-flat workloads, median +0.08%, p90 of \|Δ\| 0.8% |

* **YJIT gap:** under YJIT, 66 of 194 workloads aren't JIT-flat after 50 warmup operations (mostly the long mail and
  job workloads). They're left out of YJIT rankings and comparisons, as census 8 does. Mastodon's YJIT pair is
  missing from the CPU A/A because `bgc2`'s run didn't finish in time.
* **Interpreter outliers:** chatwoot's A/A outliers (−12.5%, +32%) are single workloads with very little work.

## Where the instructions go

Median Callgrind Ir per operation, interpreter (YJIT in parentheses, JIT-flat only):

| Kind | Median Ir/op by app (low – high) | Rails | Gems | App |
| --- | --- | ---: | ---: | ---: |
| enqueue | 0.30 M – 0.46 M (0.16 M – 0.26 M) | 64% | 28% | 0.1% |
| job | 2.7 M – 140 M (1.1 M – 25 M) | 62% | 34% (mail 9%) | 1.9% |
| mailer | 6.7 M – 169 M (3.9 M – 139 M) | 17% | 79% (mail 38%, css_parser 16%, premailer 2%) | 2.3% |
| storage | 0.46 M – 2.9 M (0.18 M – 0.35 M) | 82% | 14% | 0.4% |
| cable | 1.8 M – 10.4 M (1.0 M – 4.1 M) | 75% | 20% | 1.1% |

Allocations, median objects per operation (interpreter = YJIT within 1%):

| Kind | Median objects/op |
| --- | ---: |
| enqueue | 113 |
| job | 2,782 |
| mailer | 17,882 |
| storage | 144 |
| cable | 453 |

## Rankings

### Rails lines, all kinds (interpreter, 12 apps)

| # | Line | Apps | Share | Ir/op | Notes |
| ---: | --- | ---: | ---: | ---: | --- |
| 1 | `active_record/querying.rb:99` `_load_from_sql` | 12 | 45% | 101,155 | census 8 |
| 2 | `relation/query_methods.rb:193` `where_clause` | 12 | 46% | 97,951 | census 8 |
| 3 | `core_ext/enumerable.rb:317` `index_with` | 12 | 47% | 87,613 | census 8 |
| 4 | `result.rb:121` `column_types` | 12 | 45% | 69,358 | census 8 |
| 5 | `isolated_execution_state.rb:32` `[]` | 12 | 76% | 55,617 | census 8 |
| 6 | `type/hash_lookup_type_map.rb:67` | 6 | 27% | 37,296 | PG apps |
| 7 | `arel/collectors/plain_string.rb:15` | 12 | 45% | 36,473 | |

YJIT puts the same lines first (`index_with`, `_load_from_sql`, `column_types`, `where_clause`), then
`UriEncoder#escape` (CP-5, queued).

### By kind: lines that aren't census 8's (interpreter)

| Kind | Line | Apps | Share of the kind's Ir | Notes |
| --- | --- | ---: | ---: | --- |
| enqueue | `queue_adapters/test_adapter.rb:53` `job_to_hash` | 10 | 4.1% | harness (test adapter) |
| enqueue | `uri/generic.rb:606` `check_host` + `common.rb:90` `make_components_hash` | 8 | 4.1% | `URI::GID.build`, through uri |
| enqueue | `active_job/arguments.rb:61` `serialize_argument` | 10 | 2.2% | |
| enqueue | `globalid/uri/gid.rb:95` `URI::GID.build` | 8 | 1.4% | |
| enqueue | `event_reporter/log_subscriber.rb:49` `subscription_filter` proc | 10 | 1.1% | |
| storage | `journey/router/utils.rb:81` `UriEncoder#escape` | 6 | 1.3% | CP-5, queued |
| storage | `message_verifier.rb:368` `generate_digest` | 6 | 0.8% | OpenSSL HMAC, 97% native |
| storage | `active_storage/filename.rb:70` `Filename#sanitized` | 6 | 0.7% | **AS-1** |
| storage | `disk_service.rb:34` `download` | 6 | 0.4% | file read |
| cable | `json/encoding.rb:272` `escape!` | 4 | 3.7% | one native `gsub!` |
| cable | `erb/util.rb:160` `xml_name_escape` | 4 | 0.9% | Action View rounds |
| cable | `action_cable/server/socket.rb:77` `request` | 6 | 0.2% | |
| cable | `server/tagged_logger_proxy.rb:25` `tag` | 6 | 0.1% | 8.5 objects/op |
| mailer, job | `string/output_safety.rb:185` `SafeBuffer#gsub` | 6 | 0.2% | |

* **Action Mailer and Action View:** rendering lines are below 0.02% each in mail; the mail gem and CSS inlining
  dominate.
* **Allocations by kind:** `filename.rb:70` allocates 10.9 objects per storage op (6 apps) and 10.3 per cable op (3
  apps, attachment URLs in broadcasts). `tagged_logger_proxy.rb:25` allocates 8.5 per cable op (6 apps).

### Gem lines (interpreter; YJIT has the same top seven)

| # | Line | Apps | Ir/op | Notes |
| ---: | --- | ---: | ---: | --- |
| 1 | mail `utilities.rb:248` `binary_unsafe_to_crlf` | 6 | 300,173 | 2.0% of mail Ir; one native `gsub` per body encode (6 per Fizzy mail) |
| 2 | mail `field.rb:251` `responsible_for?` | 6 | 197,253 | 1,041 calls per Fizzy magic-link mail |
| 3 | mail `utilities.rb:238` `binary_unsafe_to_lf` | 6 | 145,202 | native `gsub` |
| 4 | concurrent-ruby `non_concurrent_map_backend.rb:111` | 12 | 128,730 | I18n and Action View caches |
| 5 | mail `parameter_hash.rb:22` `[]` | 6 | 110,462 | Regexp per lookup |
| 6 | mail `field_list.rb:71` `select_fields` | 6 | 107,473 | 311 calls per mail |
| 7 | mail `encodings/8bit.rb:14` `compatible_input?` | 6 | 102,394 | `str.lines` allocates every line |
| – | css_parser `parser.rb:407` `parse_block_into_rule_sets!` | 2 | 1.9 M (mailer tier 2) | premailer in Mastodon and Loomio |

**stackprof** agrees on the top lines: mail's CRLF conversion, css_parser and PG decoding. The orb's CPU-time timer
fires every few milliseconds, so stackprof saw too few samples per line to rank beyond the top five. It is a
cross-check, not a price.

## Candidate AS-1: read the blob filename's extension once when choosing a variant format

Branch [`thomasklemm/variant-format-extension-once`](https://github.com/thomasklemm/rails/tree/thomasklemm/variant-format-extension-once)
[`efbf8cdbcd`](https://github.com/thomasklemm/rails/commit/efbf8cdbcd6eaa1499924b727b10557cb9023d4e) on main
`9b116f1fed` ([patch](../../bench/upstream/background/patches/as1-variant-format-extension-once.patch)).
Readability **L0**: one local variable, three lines.

```ruby
def format
  extension = filename.extension
  if extension.present? && Marcel::MimeType.for(extension: extension) == content_type
    extension
  else
    Marcel::Magic.new(content_type.to_s).extensions.first
  end
end
```

**Mechanism.**

* `blob.variant(t)` merges `default_variant_transformations` into every variation, and that calls
  `default_variant_format`. For a web image (`image/png`, `image/jpeg`, `image/gif` by default) it then calls
  `format`, which called `filename.extension` up to three times.
* Each call builds a new `ActiveStorage::Filename` and runs `sanitized`: `encode` with replacement, `strip`, and a
  17-character `tr`, about 1.5 µs for a 30-byte name. Since `0e6a6afe3c` (GHSA-p2pm-g2h6-7j5j) `extension` and
  `base` sanitize too.
* `probe_calls.rb` counts 4 `sanitized` calls per variant path in Campfire, Fizzy and the others: 3 from `format` and
  1 from `to_param`.

**History and overlap.**

* `format`'s last change was `3d414f3986` (2023, marcel).
* Open #51115 (default variant format PNG → WebP) touches `default_variant_format`, not these lines.
* PR searches for "representable format", "filename.extension", "variant format extension", "default_variant_format"
  and "Filename sanitized performance" found nothing similar.
* The security commit changed `filename.rb`, not this caller. AS-1 leaves `sanitized` alone.

**Exactness.**

* [`exact_format.rb`](../../bench/upstream/background/exact_format.rb) checks `format` (value, class, frozen,
  encoding) and the resulting variant format for 160 filename × content type pairs. The pairs include invalid UTF-8,
  binary names, the RLO character, unsafe characters, no extension, upper-case extensions, mismatched, empty and nil
  types, and non-web images.
* Output was identical between main and the branch on the interpreter, YJIT and ZJIT (`--zjit-call-threshold=1`).
  ZJIT also matches the interpreter.
* `Marcel::Magic.by_extension` rebinds rather than mutating its argument (`ext = ext.downcase`). The old code
  returned a fresh unfrozen String from its third call; the new code returns the first, which Marcel only read.
* A nil filename raises the same `NoMethodError` at the same point.
* `format` has one caller (`default_variant_format`), and `extension` shadows no method.
* Active Storage `test/{models,controllers}`: 439 runs, the same 19 errors on main and the branch. All 19 are PDF
  previews; the orb has no previewer.

**Micro** ([`micro.rb`](../../bench/upstream/background/micro.rb), [`ir.sh`](../../bench/upstream/background/ir.sh),
[`ns.sh`](../../bench/upstream/background/ns.sh)). Instructions: Callgrind for 3,000 calls minus none. Time: best of 5
rotating rounds pinned to one CPU. ZJIT on master `9aa0898240`.

| Per call | Objects | Ir interp | Ir YJIT | Ir ZJIT | ns interp | ns YJIT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `blob.variant(resize_to_limit: [100, 100])`, PNG, main | 61 | 110,680 | 72,939 | 80,254 | 16,310 | 10,369 |
| branch | 39 | 73,739 (−33.4%) | 43,841 (−39.9%) | 50,305 (−37.3%) | 11,350 (−30%) | 6,710 (−35%) |
| main again (A/A) | 61 | −0.12% | −0.07% | −0.07% | +0.1% | −1.8% |
| `format`, PNG, main → branch | 49 → 27 | −47.3% | −49.7% | −49.7% | −46% | −48% |
| `format`, `scan.png` as `image/jpeg` | 42 → 31 | −28.3% | −30.6% | −30.7% | | |

The A/A for `format` is ≤ 0.06% in all three modes. ZJIT objects are the same as YJIT's.

**Apps:** `cpu-census` label `bgf`, the branch pinned from the fork, on every storage workload of the six storage
apps.

* **Interpreter:** `AS variant path` runs 7.2–9.9% fewer instructions in all 12 workloads of all 6 apps, and
  allocates 22 fewer objects in 11 of them (143.7 → 121.7 in Campfire; 9 fewer in Fizzy's avatar variant). Those workloads' own A/A is −1.1% to +1.5%:

  | App | Variant path Ir, branch vs main | A/A |
  | --- | --- | --- |
  | Campfire | −7.8%, −7.9% | +0.7%, −0.1% |
  | Fizzy | −9.9%, −9.1% | −1.1%, −0.0% |
  | Writebook | −7.5%, −8.4% | +0.5%, −0.1% |
  | Loomio | −8.8%, −8.7% | +0.0%, +0.1% |
  | Chatwoot | −7.6%, −7.7% | +1.5%, +1.5% |
  | Docuseal | −7.2% | +0.0% |

  Other storage workloads (reads, blob paths, downloads) don't reach `format`, and stay within their A/A.
* **YJIT:** the JIT-flat variant paths run 8.1–8.7% fewer instructions (Fizzy, Writebook, Loomio ×2, Docuseal),
  against an A/A of −0.3% to +0.2%.

**Reviewer** (separate subagent): ship. It confirmed:

* No behavior change: Marcel only reads its argument; callers don't mutate the returned String; the nil path raises
  the same error.
* `format`'s only caller runs once per `variant`.
* The commit message's claim holds.
* No overlapping PR.

It asked for numbers in the body (done) and suggested "up to three times" (in the body).

**Opened** ready for review as [#59615](https://github.com/rails/rails/pull/59615) on 2026-11-04 after Sol's body fixes (allocation claim scoped to the measured representation-path workloads, "preserves format selection with the standard filename implementation", no age for `0e6a6afe3c`, the suite reported as same runs and errors on both). Preflight: main refreshed to `9cf3693a0a`, no commits on `representable.rb`, `filename.rb` or `blob.rb` since `9b116f1fed`, rebased head `fa58e6094c`, `git merge-tree` clean, overlap search repeated (adjacent, not duplicate: #51115, #58615, #57597, #57731; #58398 touches transformers, not `format`); targeted variant/representation/filename tests 58 runs with the same two PDF-previewer errors. Watched every 2 hours, report-only.

**Body as opened:**

> Every `variant` of a web image (PNG, JPEG, GIF) picks its default `format:` in `Representable#format`, which called `filename.extension` up to three times. Each call builds a new `ActiveStorage::Filename` and, since 0e6a6afe3c sanitizes the filename parts, re-encodes and sanitizes the whole name. This reads the extension once into a local, as `tempfile_extension` already does. Marcel only reads it and the returned String is an equal fresh copy, so this preserves format selection with the standard filename implementation.
>
> | Variant construction, `blob.variant(resize_to_limit: [100, 100])` on a PNG, per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter / YJIT / ZJIT |
> | --- | ---: | ---: | ---: | ---: |
> | main (9b116f1fed) | 61 | 16.3 µs | 10.4 µs | 110,680 / 72,939 / 80,254 |
> | this PR | 39 | 11.4 µs (−30%) | 6.7 µs (−35%) | −33% / −40% / −37% |
> | main, run again | 61 | +0.1% | −1.8% | −0.1% / −0.1% / −0.1% |
>
> Ruby 4.0.9; ZJIT on Ruby master 9aa0898240; instructions from Callgrind ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/background/micro.rb)). The Active Storage model and controller tests give the same 439 runs and the same 19 PDF-previewer errors on main and the branch (no previewer installed). In six open-source apps on Rails main (Campfire, Fizzy, Writebook, Loomio, Chatwoot, Docuseal), the measured variant-representation-path workloads ran 7–10% fewer interpreter instructions, with A/A differences of at most 1.5%. Most saved 22 allocations; Fizzy's avatar variant saved nine. I found it with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/background-census.md)).

## Rejected and left alone

| Line or lead | Why not |
| --- | --- |
| `_load_from_sql`, `where_clause`, `index_with`, `IsolatedExecutionState.[]`, `column_types`, `UriEncoder#escape`, `xml_name_escape` | Covered by census 8, CP-5 and the Action View rounds. |
| `test_adapter.rb:52–53` `job_to_hash` | Test adapter, harness cost; production adapters serialize differently. |
| `EventReporter#notify`, `LogSubscriber.subscription_filter`, `ActiveJob.adapter_name` in the structured subscriber | Code a maintainer is reworking: `81d95a3f74` (Akira Matsuda, 2026-10-13, "Don't build structured events that no subscriber will consume") and `98d80d5bdb` (2026-10-06). Playbook: nothing in code a maintainer is reworking. |
| `Filename#sanitized` itself (memoize, ASCII fast path for `tr`) | Security code from `0e6a6afe3c` (GHSA-p2pm-g2h6-7j5j). Memoizing on a non-frozen wrapper of a caller's String isn't exact. AS-1 removes the repeats at the caller instead. |
| `arguments.rb:61` `serialize_argument` | The `case` already tests cheap immediate types first; no small exact change. |
| `URI::GID.build`, uri `check_host`/`make_components_hash` (~5.5% of enqueue together) | The cost is uri's `Generic.build` (component `clone`s and host regexp), so the change belongs in ruby/uri, with a different owner and review path. globalid has five open PRs. Recorded as a lead, not built. |
| `MessageVerifier#generate_digest` | OpenSSL HMAC, 97% native. |
| `json/encoding.rb:272` `escape!` | One native `gsub!` over the payload; already looked at in [serialization-cpu](serialization-cpu.md). |
| `TaggedLoggerProxy#tag` (`tags - current_tags`) | 8.5 objects but 0.1% of cable Ir; marginal, and `12fdf3363a` recently changed how current tags are read. |
| mail `compatible_input?` (`str.lines`) | Open mikel/mail#1693 (krzyczak, 2026-10-29) does exactly this. |
| mail `ParameterHash#[]` (Regexp per lookup) | Open mikel/mail#1673 ("Compile the MIME parameter matcher once per lookup"). |
| mail `responsible_for?` / `select_fields` / `dasherize` | Field lookups by linear scan; a real fix (an index by name) isn't small. Open mikel/mail#1672 touches the same accessors. mail has merged nothing since 2026-07-01 and has at least 15 open PRs. |
| mail `binary_unsafe_to_crlf` / `_lf` | One native `gsub` per body encode with an already tuned regexp; the repeats are in `Body#encoded`'s decode-then-encode, which isn't a small change. |
| css_parser / premailer (16% of mail CPU in Mastodon, Loomio, CodeTriage) | Outside Rails and mail; recorded as a gem lead, not examined. |
| Continuations, retry/discard bookkeeping | 0.5% of Fizzy's Continuable `Event::WebhookDispatchJob`; `execution`/`exceptions`/`callbacks` ≤ 0.15% of any job. Nothing to fix. |

## Ruby master: interpreter and ZJIT (allocations)

After the nokogiri fix in [`frontier-master`](../../fixtures/corpus/frontier-master/README.md) (pins 1.19.4 → 1.19.7 in nine
overlays; Rails main needs nokogiri ≥ 1.19.5 through rails-html-sanitizer 1.7.2 and loofah 2.25.3), `script/census setup
--corpus census-master --ruby ~/rubies/master-9aa0898240 --ruby-overlays fixtures/corpus/frontier-master` sets up Blog,
Campfire, Fizzy and Lobsters, and `script/census run --label bgm --aa --modes interp,zjit` measured their 72 background
workloads (labels `bgm`, `bgm2`, `.lowrail/private/background-master`). A/A: median +0.0 in both modes, moved ≥ +1 on
2 / 3 workloads, none ≤ −1, SQL changed on 0.

| Kind | Workloads | Master − 4.0.9, interpreter, median objects/op (min, max) | ZJIT − interpreter on master, median (min, max) |
| --- | ---: | --- | --- |
| enqueue | 14 | −2 (−3, +0) | +0 (+0, +0) |
| job | 14 | −26 (−309, +151) | +4 (+1, +11) |
| cable | 10 | −3 (−43, +16) | +2 (+0, +12) |
| storage | 28 | −2 (−24, +5) | +0 (+0, +12) |
| mailer | 6 | −134 (−369, −110) | +0 (−1, +16) |

Master − 4.0.9 also includes the overlays' gem bumps (Lobsters' commonmarker and stackprof), so it is not a pure Ruby
difference. Under ZJIT the result Arrays of master's JIT-only Ruby `Array#map`/`#select` are attributed to
`<internal:array>:289/315` (+20 and +22 per workload) instead of their callers, which is why mail's
`field_list.rb:71` drops by about as much (−19); that is attribution, not extra work. No new ZJIT lead from this pass.

## Limits

* **Coverage:** mail from Chatwoot and CodeTriage can't run on Rails main (gaps above). Discourse, Mastodon and
  Lobsters run several jobs as Sidekiq workers.
* **Controls:** cable delivery is inline and in process, and storage uses the Disk service; S3 or GCS client cost
  isn't measured.
* **YJIT:** 66 of 194 workloads aren't JIT-flat after 50 warmup operations, and Mastodon's YJIT CPU A/A is
  incomplete.
* **stackprof** is a cross-check only (sparse samples).
* **Ruby master:** Blog, Campfire, Fizzy and Lobsters only (below). Writebook's master copy sets up but its background workloads miss a leaf they look up (data preparation, not the overlay); the other apps were not tried. No Callgrind or ZJIT stats pass ran on master.
