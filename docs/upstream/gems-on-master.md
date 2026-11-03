# Census gems on Ruby master (bet E2)

C8 found that only 10 of the 23 census configurations bundle on Ruby master
[`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb) with Rails main
[`1105756f42`](https://github.com/rails/rails/commit/1105756f426ee42834af5c87b4549ef709d631e5). This page records,
per gem, what makes the other 13 install, or why they still cannot.

**Result: 11 of the 13 now install and pass `script/census list` on master,** so 21 of 23 configurations can
run on master: Writebook, Lobsters, Thinkroom, Docuseal, Mastodon, Mastodon-nops, Lago, Lago-nops, Discourse,
Loomio and Sure (128 workloads). **Chatwoot and Flow stay blocked:** a maintainer declined the commonmarker 0.x
port that Chatwoot needs, and temporalio has no 4.1 build and no source gem that builds.

Every fix is a dependency change in the master overlays
([fixtures/corpus/frontier-master](../../fixtures/corpus/frontier-master/README.md)): a released version, a git
source at an existing upstream fix, or (two gems) a vendored gem. No app code changes. No new upstream PR or issue
was needed. Every failure already had a release, an upstream PR or commit, our own open PR or issue, or a
maintainer decision against the fix. Nothing was posted upstream.

## Pins and method

* **Ruby:** master `9aa0898240`, built here with `--enable-yjit --enable-zjit --disable-install-doc` into
  `~/rubies/master`. `ruby 4.1.0dev (2026-11-03T12:42:36Z HEAD 9aa0898240) +PRISM`, RubyGems 4.1.0.beta3.
* **Rails:** main `1105756f42`, C8's base.
* **Setup:** `script/census setup --corpus censuse2 --rails 1105756f42… --ruby ~/rubies/master --ruby-overlays
  fixtures/corpus/frontier-master --apps APP`, one fresh copy per app: bundle, database, JS build, assets, the
  harness `prepare` step, and `list` (every workload three times). For the `-nops` configurations, `script/census
  list --corpus censuse2 --ruby ~/rubies/master --apps mastodon-nops,lago-nops`.
* **Overlays:** F1 built master overlays for all 23 configurations in its orb and left them uncommitted
  ([F1 thread](https://ampcode.com/threads/T-01a19e58-1fef-7536-8634-062b91d84bd0)). They are committed here
  with `script/census --ruby-overlays`. F1's own patches of cbor, lago-expression, rinku and tiktoken_ruby are
  replaced by git sources at the upstream fixes, and the hunks that only dropped `RUBY VERSION` are gone, because
  census 8 moved the base overlays to 4.0.9. The overlays of the ten configurations that already bundled still
  apply (a dry run on fresh copies), but were not set up again here.
* **Rerun:** after all setups, one `list` over the 11 configurations passed again (127 workloads). The only
  difference is Discourse's `perform Jobs::UpdateGravatar`. `UserAvatar.refresh_for_user` enqueues it only while
  `last_gravatar_download_attempt` is nil, and the first replay sets it, so the job list of a Discourse copy shrinks
  after its first `list`. This is a property of the copy's data, not of Ruby master.
* **Environment:** PostgreSQL 15 with pgvector 0.8.1 and pg_partman, Redis; libidn-dev, liblept5, and pdfium for
  Docuseal (bblanchon `chromium/8125` as `libpdfium_real.so` behind a 9-symbol stub, as in census 7).

| Configuration | Workloads | What made it install |
| --- | ---: | --- |
| Writebook | 8 | redcarpet 3.6.1 |
| Lobsters | 11 | stackprof 0.2.28, commonmarker 2.10.1 |
| Thinkroom | 9 | commonmarker 2.10.1; its `.bundle/config` holding only `---` removed |
| Docuseal | 13 | numo-narray-alt 0.10.7 |
| Mastodon, Mastodon-nops | 14 + 14 | cbor from cabo/cbor-ruby#31; haml 7.5.2 |
| Lago, Lago-nops | 10 + 10 | lago-expression from getlago/lago-expression#91; datadog 2.45.0 |
| Discourse | 15 | cbor from #31; rinku from vmg/rinku#97; tiktoken_ruby main; tokenizers 0.6.4 vendored with magnus 0.8.4; google-protobuf from source |
| Loomio | 15 | cbor from #31; oga 3.5, ruby-ll 2.2.0; released prism 1.9.0 vendored |
| Sure | 9 | cbor from #31; stackprof 0.2.28, skylight 7.0.0 |
| Chatwoot | blocked | commonmarker 0.23.12 does not build; the other bumps bundle |
| Flow | blocked | temporalio 1.10.x |

## Per gem

| Gem (locked) | Configurations | Failure on master | Fix used | Upstream state |
| --- | --- | --- | --- | --- |
| redcarpet 3.6.0 | Writebook | `Data_Get_Struct` removed (Feature #21768) | 3.6.1 | released |
| commonmarker 2.6.3, 2.10.0 | Lobsters, Thinkroom | rb-sys < 0.9.128: incomplete `struct rb_matchext_struct` (oxidize-rb/rb-sys#741); magnus 0.8.2 lacks `handle_weak_references` | 2.10.1 | released |
| stackprof 0.2.25, 0.2.27 | Lobsters, Sure, Chatwoot | `rb_postponed_job_register_one` removed | 0.2.28 | released |
| numo-narray-alt 0.10.3 | Docuseal | `sort.h`: `rb_alloc_tmp_buffer` now takes three arguments | 0.10.7 (0.10.4–0.10.6 still fail) | released; 0.12.0 also builds |
| cbor 0.5.10.3 / 0.5.10.2 | Mastodon (+nops), Discourse, Loomio, Sure; Flow | `Data_Wrap_Struct`/`Data_Get_Struct` removed | git `nobu/cbor-ruby@08f34f5b9a`, nobu's open [cabo/cbor-ruby#31](https://github.com/cabo/cbor-ruby/pull/31) | unreleased; #31 open since 2026-06, issue cabo/cbor-ruby#42 open with no comments. Our duplicate #43 is closed. #31 is based on 0.5.10.2, so these apps run without 0.5.10.3's one preallocation change (`unpacker.c`, 3 lines) |
| lago-expression 0.2.0 @ `0b4fe83` | Lago (+nops) | gemspec `~> 4.0.2` refuses 4.1; rb-sys 0.9.130 has no 4.1 stable API | git `thomasklemm/lago-expression@d23823a03e`, our open [getlago/lago-expression#91](https://github.com/getlago/lago-expression/pull/91) | open, no review yet. Bundler builds the extension from the git source and replaces the committed prebuilt `.so` |
| datadog 2.33.0 | Lago (+nops) | profiler extension: `LIKELY`/`UNLIKELY` undeclared in its 4.1 core headers (rebuilt here) | 2.45.0 | released |
| msgpack 1.8.2 | Lago (+nops) | **none**: 1.8.2 to 1.8.7 build on master and Lago's bundle uses 1.8.2 | — | C8's "msgpack" entry is a misreading. cbor-ruby is derived from msgpack-ruby, so cbor's build errors name `msgpack_packer_t` and `msgpack_buffer_t`. Lago's failures were lago-expression and datadog |
| byebug 11.1.3, unf_ext 0.0.8.2 | Chatwoot | `Data_*_Struct` removed | byebug 13.0.0, unf_ext 0.0.9 | released (Chatwoot bundles; still blocked by commonmarker 0.23.12) |
| google-protobuf 4.36.2 | Discourse | "no build valid for all platforms": the locked platform gems cap `< 4.1.dev` | `force_ruby_platform` (source build) | normal before a release; the source gem builds |
| tiktoken_ruby 0.0.17 | Discourse | its Cargo.lock has magnus 0.8.2 | git `IAPark/tiktoken_ruby@e9f6f6093f` (main, magnus 0.9.0 from the merged IAPark/tiktoken_ruby#130) | fixed on main, unreleased. Our #132 is closed |
| tokenizers 0.6.4 | Discourse | rb-sys 0.9.124 and magnus 0.8.2 | vendored 0.6.4 with Cargo.lock magnus 0.8.4 (F1's patch) | fixed on ankane/tokenizers-ruby master (0.7.x), unreleased. discourse/discourse_ai-tokenizers requires `tokenizers ~> 0.6.3`, so even a 0.7.1 release needs a requirement change there |
| rinku 2.0.6 | Discourse | its extconf defines `RUBY_EXPORT`, which hides `ruby_abi_version`, and dev builds refuse an extension without it | git `maxprokopiev/rinku@8583fe1c05`, the open [vmg/rinku#97](https://github.com/vmg/rinku/pull/97) | open since 2024-02; the last release is from 2019. Release builds don't check the ABI version, so rinku works on 4.1.0 once it ships |
| prism 1.9.0 | Loomio | master's bundled prism is ruby/prism `0616b251`, labeled 1.9.0 (mame's a1efb9ae6b: prism became a bundled gem). Bundler treats the locked 1.9.0 as installed, and that copy has no `Prism::MissingNode`, which refract 1.1.0 needs | released 1.9.0 vendored as a path gem, unchanged | deliberate on master. It becomes a 4.1 problem only if 4.1.0 ships a prism revision under a released version number; recorded as a risk, nothing filed |
| haml 7.5.1 | Mastodon | master's bundled prism lexes nested hashes as `BRACE_LEFT_HASH` (haml#1224, from F1) | 7.5.2 | released 2026-11-03 |
| oga 3.4, ruby-ll 2.1.3; skylight 6.0.4 | Loomio; Sure | `Data_*_Struct` removed | oga 3.5, ruby-ll 2.2.0; skylight 7.0.0 | released |
| Bundler 4.0.20 | Thinkroom | RubyGems 4.1.0.beta3 `Gem::YAMLSerializer.load("---\n")` returns nil, and `Settings#load_config` calls `inject` on it. Thinkroom commits a `.bundle/config` that holds only `---` | the overlay deletes that file. It sets nothing, so no Bundler setting changes | our open [ruby/rubygems#10017](https://github.com/ruby/rubygems/issues/10017) (backport of `368fc29ce1` to 4.0.x), no reply yet |
| commonmarker 0.23.12 | Chatwoot | `Data_*_Struct` in 44 places and `RDATA(val)->dfree` toggling | **none** | gjtorikian declined both nobu's TypedData port gjtorikian/commonmarker#424 ("the version of the code you are targeting is years old") and a Ruby 4 cap lift for the C branch gjtorikian/commonmarker#430 ("I'm loathe to maintain the C-backed version"). #424's commit still toggles `dfree` and does not build on master either. Chatwoot `develop` still locks 0.23.12, so the fix is an app migration to commonmarker 2.x. Not built |
| temporalio 1.10.0 | Flow | the binaries cap `< 4.1.dev`; the source gem ships only `ext/Cargo.toml`, without the bridge or sdk-core sources; Cargo.lock has magnus 0.8.2 and rb-sys 0.9.128 | **none** | buildable source gems: open temporalio/sdk-ruby#218 (feature request, 2025-02). The maintainers add each Ruby in one PR after its release (temporalio/sdk-ruby#372 for 4.0 in 2026-01, with build matrix, rb-sys/magnus and RBS updates), so a 4.1 binary is expected after December. Not built |

## Leads, not acted on

* **Bundled prism and Bundler.** If 4.1.0 bundles a prism revision under the number of a released prism, every app
  that locks that release gets the bundled copy instead. Watch `gems/bundled_gems` before the release.
* **discourse_ai-tokenizers** pins `tokenizers ~> 0.6.3`. Once ankane/tokenizers-ruby releases a 0.7.x that builds
  on 4.1, Discourse needs that requirement widened before it installs on 4.1 without a patch.
* **Flow** stays out of master rounds until temporalio publishes a 4.1 build.
