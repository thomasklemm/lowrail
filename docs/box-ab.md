# Bet B: Ruby::Box A/A harness probe

**2026-10-23 · NO-GO on Ruby 4.0.7.** The unmodified real-blog boots and
serves both GETs normally, but the first Optional Box crashes before boot
completes. Main alone with `RUBY_BOX=1` also crashes. Stopped at the requested
fundamental-feasibility boundary: no performance cohort, runtime changes,
gate changes, upstream issues or PRs. This rejects this pinned harness today,
not the paired-measurement idea on a future Ruby.

## Method and results

Read Carton's [Box internals](https://github.com/dtcristo/carton/blob/main/docs/internals/how-boxes-work.md)
first. Stock mise Ruby **4.0.7, revision 229531a6cf**, x86_64 Linux;
Bundler **4.0.20**, Rails **8.1.4**. Used the retained real-blog in
`fixtures/corpus/real-blog-r4-retained.tgz`, not a new generator run:

```text
archive SHA256 b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99
app source pin 86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf
lock SHA256    570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596
```

Installed the frozen bundle; `BlogProduction::Entropy.validate` passed.
All work used disposable app copies outside the source tree, no Lowrail load
hooks, `RAILS_ENV=RACK_ENV=production`, fatal logging, and
`SECRET_KEY_BASE_DUMMY=1`. Normal-process preparation loaded all four production
SQLite schemas and inserted the two article/comment YAML fixtures with IDs
1/2 and timestamps `2026-01-01 UTC`, without callbacks. Disconnected connections,
then copied the closed databases into separate A/B app directories. Boot was
sequential, each via `box.require` of a boot file requiring that app's
`config/environment.rb`; set its `BUNDLE_GEMFILE` and restored all of `ENV`
after each attempted boot. No main-Box Rails preload or shared framework.

Requests used `Rack::MockRequest.new(Rails.application).get`, full middleware,
host `localhost`, HTTPS on and fixed request ID `box-probe`; no HTTP server.

| Question / control | Observed result |
| --- | --- |
| Normal process, YJIT, `/articles` | **200**, 5,500 body bytes; `h1=Articles`, two article headings |
| Normal process, YJIT, `/articles/1` | **200**, 5,030 body bytes; expected fixture title, one comment |
| First Optional Box, YJIT, stock app | **SIGSEGV, exit 139**, during `Bundler.require`, loading Solid Cache; never reached READY or either request |
| Same, `DISABLE_BOOTSNAP=1` | Solid Queue autoload **LoadError**, then **SIGSEGV at cleanup**, exit 139 |
| Main only, `RUBY_BOX=1 --yjit`, stock app | **SIGSEGV**, exit 139, also before READY |
| YJIT in an empty new Box | `RubyVM::YJIT.enabled? == true` |
| Active Support / I18n isolated smoke | `require "active_support"; require "active_support/core_ext"` passed; store/translate `:box_probe` returned `"ok"` |
| Q1 byte-identical Box responses | **Unavailable**: zero Box responses; second app never booted |
| Q2 app/Rails method isolation and SQL-to-own-database proof | **Not reached**; distinct database files alone are not isolation proof |
| Q3 paired in-process A/A interval | **N/A — not measured**, feasibility failed |
| Q3 four fresh-process A/B/A blocks A/A interval | **N/A — not measured**, stopped before benchmark phase |
| Q3 order reversal, GC-position bias, small injected cost | **Not reached**; no tighter/unbiased claim |
| Q4 `RUBY_BOX=1` single-Box request speed vs disabled | **Unmeasurable here**: enabled Main failed to boot; no slowdown percentage inferred |

No normalization was applied to the normal responses and no Box equivalence
was claimed. Had boot worked, only the existing
[`blog-entropy-controls.json`](../fixtures/corpus/blog-entropy-controls.json)
companion's declared secret, CSRF/session/cookie random sites and Rack runtime
clock control would have been used for exact-response checks, not timing.
The intended next stage was unpatched A/A, adjacent alternating requests with
order reversal, YJIT-flat warmup/windows, compared with four fresh-process
A/B/A blocks on the same request. None ran; intervals cannot be borrowed from
another app, substituted with zero, or computed from failed boots.

## Reduced failures (not reported upstream)

### Native-load/GC crash: reproduced, existing-issue identity unconfirmed

No Rails, Bundler, app, database or Bootsnap is needed:

```sh
ulimit -c 0
RUBY_BOX=1 mise exec -- ruby --yjit -e \
  'Ruby::Box.new.eval(%q{require "nokogiri"; require "ruby-vips"; GC.start; puts "PASS"})'
```

Installed versions: Nokogiri **1.19.4-x86_64-linux-gnu**, ruby-vips **2.3.0**,
ffi **1.17.4-x86_64-linux-gnu**; Debian libvips **8.14.1**, libxml2 **2.9.14**.
Three finite repetitions with YJIT: **3/3 SIGSEGV (139)**, no PASS. Ruby locations
varied (`vips/source.rb:11`, `ffi/library.rb:179`, `<internal:array>:246`), but
all three C backtraces contained:

```text
libxml2.so.2(xmlCharEncCloseFunc+0x95)
ruby(rb_data_free+0x2e) gc.c:1216
ruby(rb_gc_obj_free) gc.c:1362
... GC sweep / heap_prepare ...
```

The original Rails crash has that same native/GC signature (Ruby location
`solid_cache/store/connections.rb`, Bootsnap `load_from_binary` on stack).
Disabling Bootsnap still crashed after the autoload exception, so its cache
is not a sufficient explanation. Controls for the reduced pair: **3/3 PASS**
with `--disable-yjit`; one PASS each with no Box support and with Box-enabled
Main under YJIT. Nokogiri alone and ruby-vips alone each passed a boxed YJIT
load/GC smoke. This does **not** establish YJIT as the cause: the separate
Solid Queue reduction below also crashed without YJIT. No ownership or
memory-corruption cause was established. Ruby [#22380](https://bugs.ruby-lang.org/issues/22380)
documents a different Box class-copy/GC crash on 4.0.7; similarity is not proof
that its fix addresses this failure. No confirmed matching issue was found.

### Autoload bypasses require hooks: known Ruby Box bug #21830

Run this as a Ruby file without Box support, then with `RUBY_BOX=1`:

```ruby
require "tmpdir"
Dir.mktmpdir do |dir|
  path = File.join(dir, "probe_value.rb")
  File.write(path, "ProbeValue = 42\n")
  code = <<~RUBY
    $probe_requires = []
    module ProbeHook
      def require(path)
        $probe_requires << path
        super
      end
    end
    Kernel.prepend(ProbeHook)
    autoload :ProbeValue, #{path.inspect}
    p value: ProbeValue, hook_ran: $probe_requires.include?(#{path.inspect})
  RUBY
  ENV["RUBY_BOX"] == "1" ? Ruby::Box.new.eval(code) : eval(code)
end
```

Observed `{value: 42, hook_ran: true}` normally, **`hook_ran: false`** in
the Box. Matches [Ruby #21830](https://bugs.ruby-lang.org/issues/21830), fixed
on master by [PR #18534](https://github.com/ruby/ruby/pull/18534), still present
in this 4.0.7 binary. Carton documents a per-Box require-routing workaround;
no workaround was adopted to turn this stock-app probe into a compatibility
project after the independent crash.

The corresponding smaller framework failure, with the blog's locked bundle:

```sh
BUNDLE_GEMFILE=/absolute/path/to/blog/Gemfile RUBY_BOX=1 mise exec -- ruby --disable-yjit -e \
  'Ruby::Box.new.eval(%q{require "bundler/setup"; require "rails/all"; require "solid_queue"; puts "PASS"})'
```

First exception: `solid_queue-1.7.0/lib/solid_queue/supervisor.rb:4`,
`Ruby::Box#require`: **cannot load such file -- .../solid_queue/processes**
(a directory Zeitwerk should handle). Then cleanup SIGSEGV; final exit **139**.
The same requires normally printed PASS, exit 0. An unbundled variant instead
crashed at RubyGems `specification.rb:1513` / `Array#flatten` while evaluating
`image_processing-1.14.0.gemspec:26`; not classified as a separate known bug.
Bundler setup itself completed in the full app's Box before `Bundler.require`
failed. No ENV isolation is claimed: ENV remains process-global. No independent
I18n or Active Support core-extension failure was observed; their smoke success
does not certify dual-Rails operation.
