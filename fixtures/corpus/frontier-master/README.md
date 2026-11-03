# Ruby master overlays

Dependency-only overlays that let the census apps install on Ruby master. They apply **after** each app's census
overlay (`script/census setup --ruby ~/rubies/master --ruby-overlays fixtures/corpus/frontier-master`), so the
Rails-side overlay stays shared with 4.0.9 rounds. Pin: ruby/ruby master `9aa0898240` (2026-11-03); set up on Rails
main `1105756f42`. Built by the F1 frontier census; the git sources below replaced F1's patched gems (bet E2).
Per gem, what fixed it and what is still blocked: [gems-on-master.md](../../../docs/upstream/gems-on-master.md).

* `APP.patch`: Gemfile and Gemfile.lock only (Thinkroom also deletes its `.bundle/config`, which holds only `---`;
  Bundler 4.0.20 crashes on that file on master, ruby/rubygems#10017). It is built from the
  [ruby-41-watch](../ruby-41-watch) seed where one exists, then:
  * `force_ruby_platform` for every gem whose locked `x86_64-linux` binary caps Ruby below 4.1.dev (ffi, herb,
    nokogiri, sqlite3, pg, google-protobuf, grpc, commonmarker, y-rb, as each app locks them), plus
    `mini_portile2`, which the source builds need;
  * the **smallest released version that builds on the pin** for gems whose locked version does not;
  * a **git source** where the fix exists upstream but is not released.
  `fizzy.patch` also serves fizzy-mysql, and `mastodon.patch` / `lago.patch` serve the `-nops` configurations,
  which share the copy.
* `APP.sh`: runs in the app copy with the target Ruby first on PATH. It vendors a gem as a path gem in
  `vendor/f1/NAME` and points the Gemfile at it (the overlay already contains that Gemfile line and lock entry).
  Two remain: `vendor-cargo-gem.sh tokenizers 0.6.4` (Discourse) and `vendor-c-gem.sh prism 1.9.0` (Loomio).

## Released versions

| App | Bump | Why the locked version fails on master |
| --- | --- | --- |
| Writebook | redcarpet 3.6.0 → 3.6.1 | `Data_Get_Struct` (untyped data objects removed) |
| Lobsters | stackprof 0.2.27 → 0.2.28, commonmarker 2.6.3 → 2.10.1 | old postponed-job API removed; rb-sys < 0.9.128 (`rb_matchext_struct`) |
| Sure | stackprof 0.2.27 → 0.2.28, skylight 6.0.4 → 7.0.0 | postponed-job API; skylight's `Data_Get_Struct` |
| Docuseal | numo-narray-alt 0.10.3 → 0.10.7 | `rb_alloc_tmp_buffer` takes a third argument (0.10.4–0.10.6 fail too) |
| Thinkroom | commonmarker 2.10.0 → 2.10.1 | 2.10.0's magnus lacks `handle_weak_references` in `rb_data_type_t` |
| Lago | datadog 2.33.0 → 2.45.0 (datadog-ruby_core_source 3.5.6, libdatadog 45.0.0.1.0) | profiler headers (`LIKELY` undeclared, `rb_control_frame_t.iseq`); 2.40–2.44 fail |
| Loomio | oga 3.4 → 3.5, ruby-ll 2.1.3 → 2.2.0 | `Data_Make_Struct`/`Data_Get_Struct` (2.1.4 still fails) |
| Mastodon | haml 7.5.1 → 7.5.2 | master's bundled prism lexes nested hashes as `BRACE_LEFT_HASH` |
| Chatwoot (blocked) | bootsnap 1.16.0 → 1.17.1, byebug 11.1.3 → 13.0.0, stackprof 0.2.25 → 0.2.28, unf_ext 0.0.8.2 → 0.0.9 | bundles, but its vendored commonmarker 0.23.12 does not build (below) |

## Git sources (fix upstream, not released)

| Gem | Apps | Source | Upstream state |
| --- | --- | --- | --- |
| cbor 0.5.10.2 + TypedData | Discourse, Loomio, Mastodon, Sure (via webauthn → cose) | `nobu/cbor-ruby` @ `08f34f5b9a` | nobu's open cabo/cbor-ruby#31, for cabo/cbor-ruby#42. Based on 0.5.10.2, so the four apps run without 0.5.10.3's preallocation change |
| lago-expression 0.2.0 | Lago | `thomasklemm/lago-expression` @ `d23823a03e` | our open getlago/lago-expression#91 (cap `~> 4.0.2` → `>= 4.0.2`, rb-sys `stable-api-compiled-fallback`) |
| rinku 2.0.6 | Discourse | `maxprokopiev/rinku` @ `8583fe1c05` | open vmg/rinku#97 (`RUBY_EXPORT` → `RUBY_FUNC_EXPORTED`; defining `RUBY_EXPORT` hides `ruby_abi_version`, which a dev build checks) |
| tiktoken_ruby 0.0.17 | Discourse | `IAPark/tiktoken_ruby` @ `e9f6f6093f` (main) | magnus 0.9.0 from the merged IAPark/tiktoken_ruby#130; 0.0.17 ships magnus 0.8.2 |

## Vendored

| Gem | Apps | Change | Why |
| --- | --- | --- | --- |
| tokenizers 0.6.4 | Discourse | `tokenizers-0.6.4-magnus-0.8.4.patch`: Cargo.lock magnus 0.8.2 → 0.8.4, rb-sys 0.9.130 with the fallback feature | discourse_ai-tokenizers requires `~> 0.6.3`; ankane/tokenizers-ruby master (0.7.x, magnus 0.9) builds but is unreleased and outside that requirement |
| prism 1.9.0 (released, unchanged) | Loomio | none | master bundles ruby/prism `0616b251` as "1.9.0" (a1efb9ae6b), so Bundler treats the lock's 1.9.0 as installed; that copy has no `Prism::MissingNode`, which refract 1.1.0 needs |

## Not installable on this pin

* **Flow:** temporalio 1.10.0/1.10.1 binaries cap `< 4.1.dev`, and the source gem has no Rust sources
  (temporalio/sdk-ruby#218); its Cargo.lock also has magnus 0.8.2 and rb-sys 0.9.128. No overlay.
* **Chatwoot:** commonmarker 0.23.12 (its last 0.x release, vendored by `script/corpus`) uses untyped data in 44
  places and toggles `RDATA(val)->dfree`. The maintainer declined both nobu's TypedData port
  (gjtorikian/commonmarker#424, which still toggles `dfree` and does not build on master) and a Ruby 4 cap lift
  (gjtorikian/commonmarker#430) for the C branch.

System packages for master source builds: libidn-dev (idn-ruby), liblept5 (Docuseal's OCR), pdfium as for 4.0.9.
