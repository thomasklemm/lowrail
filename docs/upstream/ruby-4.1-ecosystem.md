# Ruby 4.1 ecosystem readiness: the 20 census apps' gems on Ruby master

The F1 frontier census (20 apps on Rails main and Ruby master
[`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb)) had to overlay a set
of gems that do not build or run on master. This page checks, for each one, whether its latest release still
fails on master and whether the gem's tracker already knows. It drafts a fix where none exists, and sweeps all 20
apps' lockfiles for other native extensions that break. Nothing was posted or opened.

**Ranked by reach.** Two Bundler breaks reach every app that locks an older Bundler. cbor is the only C extension
still broken in its latest release.

| # | Finding | Still broken in latest release? | Reach (20 apps) | Existing report | Fix |
| ---: | --- | --- | --- | --- | --- |
| 1 | Bundler ≤ 4.0.23 crashes on Ruby 4.1 when `.bundle/config` is `---`, a file Bundler itself writes | yes: every released 4.0.x | any app, since `BUNDLED WITH 4.0.x` selects the old Bundler; 20 of 20 lock ≤ 4.0.23 | none for 4.0.x. The master change is ruby/rubygems#9379 | [draft issue](#draft-rubygemsrubygems-issue-bundler-40x-on-ruby-41-and-an-empty-bundleconfig); a clean cherry-pick of `368fc29ce1` to `4.0` |
| 2 | Bundler ≤ 4.0.11 cannot install a path or git gem on Ruby 4.1: `uninitialized constant Pathname::SEPARATOR_PAT` | fixed in Bundler 4.0.12; older locks break | Fizzy (2.5.21) and Writebook (2.5.18) lock old Bundlers and have git sources; 10 of 20 lock ≤ 4.0.11 | Bundler side fixed in ruby/rubygems#9529. Seen in the wild (suketa/ruby-duckdb#1347). No Redmine issue | [draft Redmine note](#draft-redmine-note-pathnameseparator_pat-and-locked-bundlers) |
| 3 | cbor 0.5.10.3 uses `Data_Wrap_Struct`/`Data_Get_Struct` | yes (HEAD = 0.5.10.3) | Discourse, Flow, Loomio, Mastodon (0.5.10.3), Sure (0.5.10.2): 5 apps, through webauthn → cose → cbor. 20 reverse deps | cabo/cbor-ruby#42 (open, 0 comments, no PR) | [`cbor-ruby-typeddata.patch`](../../fixtures/corpus/ruby-41-ecosystem/cbor-ruby-typeddata.patch); 170/170 specs on 4.0.7 and master |
| 4 | tiktoken_ruby 0.0.17 ships a Cargo.lock with magnus 0.8.2, which does not compile on 4.1 | yes (HEAD `d2c2625` too) | Discourse. 18 reverse deps | none | [`tiktoken_ruby-magnus-0.8.4.patch`](../../fixtures/corpus/ruby-41-ecosystem/tiktoken_ruby-magnus-0.8.4.patch); 72/72 specs on 4.0.7 and master |
| 5 | lago-expression caps `required_ruby_version ~> 4.0.2`; rb-sys has no 4.1 stable API | yes (main `0b4fe83`) | Lago | none (F1 checked) | F1's `lago-expression-0b4fe83-ruby41.patch` (20 specs pass, F1). [PR draft](#draft-getlagolago-expression-pr) |
| 6 | tokenizers 0.7.0 ships rb-sys 0.9.127 and magnus 0.8.2 | yes, but fixed on main (unreleased 0.7.1, magnus 0.9.3) | Discourse | not needed: fixed on main | none; wait for 0.7.1 |
| 7 | temporalio 1.10.1: binaries capped `< 4.1.dev`; the source gem has no Rust sources (`ext/` holds only `Cargo.toml`) | yes | Flow | none found | none. The source gem fails on 4.0.7 too, so it is a packaging bug, not a 4.1 one |

Gems that fail on master but are fixed in their latest release only need a bump in the app (F1 already did these):
byebug 11.1.3 → 13.0.0, numo-narray-alt 0.10.3 → 0.10.7, oga 3.4 → 3.5 with ruby-ll 2.1.3 → 2.2.0, redcarpet 3.6.0 →
3.6.1, skylight 6.0.4 → 7.x, stackprof ≤ 0.2.27 → 0.2.28, unf_ext 0.0.8.2 → 0.0.9, and commonmarker 2.6.3/2.10.0 → 2.10.1.

## Pins and method

* **Ruby:** 4.0.7 (mise) and master
  [`b51db981f6`](https://github.com/ruby/ruby/commit/b51db981f642115e0d77f4a926c7f0209f4871ab), the
  [regression-watch](ruby-4.1-regression-watch.md) build, GCC 12.2.0, rustc 1.99.1. Its `include/` is identical to
  F1's pin `9aa0898240`: `git log b51db981f6..9aa0898240 -- include` is empty.
* **Lockfiles:** each app's upstream `Gemfile.lock` at its `script/corpus` pin (19 apps), plus Blog's census 4 copy.
  1,787 gem versions, 1,011 names; 66 more come from git or path sources. Upstream lockfiles, not the master overlays,
  so the sweep shows what the apps lock today.
* **Build:** every locked gem whose gemspec declares extensions and the latest release of each such gem (86 gems, 208 versions;
  203 of them, all but the four gems skipped below) was built with `gem install --local --ignore-dependencies` on master and on 4.0.7. A gem
  counts as broken by 4.1 only when it builds on 4.0.7 and fails on master. libv8-node, mini_racer, grpc and
  sass-embedded were not built: they vendor toolchains, and a grep finds the removed API only in a grpc comment.
* **Link check:** each `.so` built on master (406 files, counting the gem-dir and extension-dir copies) was checked with `nm` for imported `rb_*`/`ruby_*`
  symbols that master's `ruby` does not export. None were missing, so every extension that compiled also links.
* **Receipts:** [`fixtures/corpus/ruby-41-ecosystem/`](../../fixtures/corpus/ruby-41-ecosystem):
  `sweep.sh` (lockfiles → downloads → builds → link check → header diff), `build-results.tsv` (exit status per gem
  and Ruby, with the apps that lock it), `removed-identifiers.txt`, both fix patches, and `repro/`.

## Bundler and RubyGems

Both breaks come from the same mechanism. RubyGems picks the Bundler version in `BUNDLED WITH` when that version is
installed, and offers to install it when it is not. So on Ruby 4.1 an app runs its locked Bundler 2.x or 4.0.x on
top of RubyGems 4.1 and Ruby 4.1's stdlib. The 20 apps lock Bundler 2.5.16 to 4.0.23. None lock 4.1.

### 1. `.bundle/config` containing `---` (Bundler ≤ 4.0.23)

[`repro/bundler-empty-config.sh`](../../fixtures/corpus/ruby-41-ecosystem/repro/bundler-empty-config.sh):

```text
$ bundle config set --local foo bar; bundle config unset --local foo   # Bundler 4.0.20 on 4.0.7
$ od -c .bundle/config
0000000   -   -   -  \n
$ ruby -e 'require "rubygems/yaml_serializer"; p Gem::YAMLSerializer.load("---\n")'   # master
nil                                                                                   # 4.0.7: {}
$ bundle config list                                                                  # master, BUNDLED WITH 4.0.20
bundler-4.0.20/lib/bundler/settings.rb:485:in 'block in Bundler::Settings#load_config': undefined method 'inject' for nil (NoMethodError)
```

`bundle install` fails the same way. The file needs no hand editing: Bundler writes `---\n` when the last local key
is unset, and the global `~/.bundle/config` behaves the same way.

* **Cause:** the change is deliberate. `Gem::YAMLSerializer.load` now returns nil for an empty document, as Psych
  does (ruby/rubygems [`c091444047`](https://github.com/ruby/rubygems/commit/c091444047acd62348446e89bffe3dfe483fc905),
  ruby/ruby `f7e6eae3d3`, ruby/rubygems#9379). The same PR made Bundler on master tolerate it
  ([`368fc29ce1`](https://github.com/ruby/rubygems/commit/368fc29ce1f318c80ec3bfa94149fc9f4e1df8b4),
  `(serializer_class.load(file.read) || {})`). That Bundler fix is not on the `4.0` branch, nor in any release
  through 4.0.23.
* **Bundler 4.0.x and 2.x call `Gem::YAMLSerializer` whenever it exists** (`Settings#serializer_class`), so every
  locked Bundler since RubyGems 3.4 is affected (checked: 2.6.9 and 4.0.20, local and global config). The plugin index uses Bundler's own serializer and is not affected.
* **The fix is cheap:** `368fc29ce1` cherry-picks cleanly onto `origin/4.0`, and that tree reads the file on both
  Rubies. Apps that lock an already-released Bundler stay exposed unless RubyGems keeps `{}` for a bare `---`.
* **Search:** ruby/rubygems issues and PRs for `inject nil settings`, `YAMLSerializer empty`, `bundle config ---`,
  `load_config`: nothing relevant.

### 2. `Pathname::SEPARATOR_PAT` (Bundler ≤ 4.0.11)

[`repro/bundler-separator-pat.sh`](../../fixtures/corpus/ruby-41-ecosystem/repro/bundler-separator-pat.sh), on master:

| Bundler | path gem | git gem | same Bundler on 4.0.7 |
| --- | --- | --- | --- |
| 2.6.9 | `NameError: uninitialized constant Pathname::SEPARATOR_PAT` | same | installs |
| 4.0.11 | same | same | installs |
| 4.0.12 | installs | installs | installs |

* **Ruby side:** ruby/ruby [`4e243c709e`](https://github.com/ruby/ruby/commit/4e243c709e45eb0d115b7875cae25dff86184b59)
  (nobu, 2026-05-08) fixed a typo (`private_constant :SEPARATOR_LIST, :SEPARATOR_LIST`). That made `SEPARATOR_PAT`
  private, which it was always meant to be. [`a5996718f3`](https://github.com/ruby/ruby/commit/a5996718f3517e29883cdb853608d452364de49a)
  then removed it. Through 4.0.7 the constant was public.
* **Bundler side:** `Source::Path#generate_bin` used `/\A#{Pathname::SEPARATOR_PAT}/o` (git sources inherit it).
  It was fixed by ruby/rubygems#9529 ("Use Pathname#absolute?", `008b41075`), first released in 4.0.12 on 2026-05-20.
  Every 2.x release and 4.0.0–4.0.11 still reference the constant.
* **Reach:** 10 of 20 apps lock ≤ 4.0.11. Fizzy and Writebook also have git sources (Rails), so both fail on
  `bundle install` with their own lockfiles. The gem repos we cloned hit it too: tiktoken_ruby locks Bundler 2.6.9 and
  uses `gemspec`, so plain `bundle install` there fails on master.
* **Compatibility check:** defining `Pathname::SEPARATOR_PAT` plus `deprecate_constant :SEPARATOR_PAT` (through
  `RUBYOPT=-r`) lets Bundler 2.6.9 install the path gem on master, with a deprecation warning at `source/path.rb:218`.
* **Search:** ruby/rubygems and GitHub-wide for `SEPARATOR_PAT`, and bugs.ruby-lang.org: only downstream CI
  workarounds (suketa/ruby-duckdb#1347, which closed it as fixed in Bundler; Autogenetica/agent-lens#27, which moved
  its lock to 4.0.21). No Redmine issue weighs locked Bundlers against the removal.

## C extensions and the removed API

Ruby master removes the long-deprecated untyped Data API, the old postponed-job functions, the taint macros,
`rb_gc_force_recycle`, `rb_iterate` and some internals (Feature #21768, NEWS "Removed APIs"). It also changes
`rb_alloc_tmp_buffer` to take a third argument (`bool mark`). The header diff between v4.0.7 and master lists 90
identifiers ([`removed-identifiers.txt`](../../fixtures/corpus/ruby-41-ecosystem/removed-identifiers.txt)). `struct
RData` and `RDATA()` are still there, marked deprecated.

Extensions in the 20 apps that build on 4.0.7 and fail on master:

| Gem (locked) | Cause on master | Latest release | Apps | Reverse deps |
| --- | --- | --- | --- | ---: |
| cbor 0.5.10.3 / 0.5.10.2 | `Data_Get_Struct`, `Data_Wrap_Struct` | **0.5.10.3, still fails** | Discourse, Flow, Loomio, Mastodon, Sure | 20 |
| tiktoken_ruby 0.0.17 | magnus 0.8.2: missing `handle_weak_references` | **0.0.17, still fails** | Discourse | 18 |
| tokenizers 0.6.4 | rb-sys 0.9.124: incomplete `struct rb_matchext_struct` | **0.7.0 still fails** (rb-sys 0.9.127); main fixed | Discourse | 23 |
| byebug 11.1.3 | `Data_*_Struct` | 13.0.0 builds | Chatwoot | 2,750 |
| commonmarker 2.6.3, 2.10.0 | rb-sys < 0.9.128 / magnus 0.8.2 | 2.10.1 builds | Lobsters, Thinkroom | 90 |
| numo-narray-alt 0.10.3 | `rb_alloc_tmp_buffer` arity | 0.12.0 builds (F1 used 0.10.7) | Docuseal | 46 |
| oga 3.4, ruby-ll 2.1.3 | `Data_*_Struct` | 3.5 / 2.2.0 build | Loomio | 121 / 2 |
| redcarpet 3.6.0 | `Data_Get_Struct` | 3.6.1 builds | Fizzy, Writebook | 1,896 |
| skylight 6.0.4 | `Data_*_Struct` | 7.1.1 builds | Sure | 6 |
| stackprof 0.2.25, 0.2.27 | `rb_postponed_job_register_one` | 0.2.28 builds | Chatwoot, Lobsters, Sure | 73 |
| unf_ext 0.0.8.2 | `Data_Make_Struct` | 0.0.9.1 builds | Chatwoot | 18 |

Reverse deps are rubygems.org reverse dependencies (gems that declare a runtime or development dependency on any
version).

**Rust extensions need rb-sys ≥ 0.9.128** (oxidize-rb/rb-sys#741, `rb_matchext_struct`) **and magnus ≥ 0.8.3 or ≥
0.9.0** (`rb_data_type_t.handle_weak_references`, magnus `7e0276a`/`1a2b3f8`). rb-sys 0.9.130, the latest, also
has no stable API for 4.1 (`stable_api/ruby_4_0.rs` is the newest). So a magnus gem builds on master only with
`stable-api-compiled-fallback` (commonmarker 2.10.1 and tiktoken_ruby enable it; lago-expression does not). That
is normal before a release, and it is why F1's lago patch adds the feature.

**Binary gems:** many precompiled platform gems cap `required_ruby_version < 4.1.dev` (nokogiri, ffi, sqlite3, pg,
google-protobuf, grpc, herb, y-rb, temporalio). That is the usual per-minor pattern, so F1 used `force_ruby_platform`.
Their source gems build on master here, except temporalio (item 7).

**Not 4.1 findings** (they fail on 4.0.7 too): cld3 3.7.0 and commonmarker 0.23.12 (Chatwoot) cap
`required_ruby_version` below 4.0. idn-ruby needs `libidn-dev` and rpam2 needs PAM headers, both missing in the orb
(F1 installed libidn-dev). llhttp-ffi needs ffi-compiler at build time, which `--ignore-dependencies` skips. Chatwoot's
vendored commonmarker 0.23.12 also uses `Data_*_Struct` 44 times, so it needs a real port. F1 records it as a gap,
and its gem line is superseded by 2.x.

**Rejected:** a Bundler `CorruptBundlerInstallError` on ruby-head with a locked non-default Bundler checksum,
reported in Autogenetica/agent-lens#27. It did not reproduce on master with a `bundler (4.0.20) sha256=` line in
`CHECKSUMS`: install and exec both work.

## Drafts (not posted)

### Draft: cabo/cbor-ruby PR "Use TypedData for Buffer, Packer and Unpacker"

> Fixes #42.
>
> Ruby 4.1 removes `Data_Wrap_Struct`/`Data_Get_Struct` (Feature #21768), so 0.5.10.3 no longer compiles on
> ruby-head. This converts the three wrapped structs to `rb_data_type_t`, as msgpack-ruby did. The buffer view that a
> Packer or Unpacker exposes keeps its NULL free function and gets `CBOR::Buffer` as its parent type, so Buffer
> methods still accept it. Five files, +34/−8.
>
> Tested with the gem's specs (rspec 3, 170 examples, 0 failures) on Ruby 4.0.7 and 4.1.0dev, plus an encode,
> decode, Unpacker#each and Packer#buffer loop under `GC.stress`. The specs pass unchanged on 4.0.7 without the
> patch.

The commit is [`cbor-ruby-typeddata.patch`](../../fixtures/corpus/ruby-41-ecosystem/cbor-ruby-typeddata.patch), based
on F1's overlay patch. Its repo's dev setup is old (rake 0.9, rspec 2, which uses `File.exists?`), so the specs ran
through a scratch Gemfile with rspec 3.13, json and ostruct. The PR should not touch the Gemfile.

### Draft: IAPark/tiktoken_ruby PR "Bump magnus from 0.8.2 to 0.8.4"

> tiktoken_ruby 0.0.17 and main do not compile against Ruby 4.1 (ruby-head): magnus 0.8.2 fails with
> `missing field handle_weak_references in initializer of rb_data_type_struct`. magnus 0.8.3 and later handle the
> new field. This updates Cargo.lock only (magnus 0.8.4, rb-sys-env 0.2.3). Specs: 72 examples, 0 failures on Ruby
> 4.0.7 and 4.1.0dev. Also, the `BUNDLED WITH 2.6.9` in Gemfile.lock makes `bundle install` fail on ruby-head
> (`Pathname::SEPARATOR_PAT`, fixed in Bundler 4.0.12), if you want to bump that too.

### Draft: getlago/lago-expression PR

> `required_ruby_version = '~> 4.0.2'` blocks installs on Ruby 4.1 (now in preview). This relaxes it to
> `>= 4.0.2` and enables rb-sys's `stable-api-compiled-fallback`, since rb-sys 0.9.130 has no 4.1 stable API yet.
> The gem's specs pass on 4.1.0dev.

Uses F1's patch (`fixtures/corpus/frontier-master/lago-expression-0b4fe83-ruby41.patch` on F1's branch). The cap
has followed each Ruby bump since #10, so the maintainers may prefer `'>= 4.0.2', '< 5'`.

### Draft: ruby/rubygems issue "Bundler 4.0.x on Ruby 4.1 and an empty .bundle/config"

> **Describe the problem.** On Ruby 4.1.0dev (RubyGems 4.1.0.beta3), an app whose Gemfile.lock says
> `BUNDLED WITH 4.0.20` runs Bundler 4.0.20. If its `.bundle/config` is `---\n`, every command fails:
>
> ```
> bundler-4.0.20/lib/bundler/settings.rb:485:in 'block in Bundler::Settings#load_config':
>   undefined method 'inject' for nil (NoMethodError)
> ```
>
> Bundler writes that file itself: `bundle config set --local foo bar` then `bundle config unset --local foo` leaves
> `---\n`, and the global config behaves the same way.
>
> **Cause.** #9379 made `Gem::YAMLSerializer.load("---\n")` return nil (c091444047) and made Bundler on master treat
> nil as `{}` (368fc29ce1). Bundler 4.0.x (and 2.x) uses `Gem::YAMLSerializer` when RubyGems provides it, and 4.0.23
> does not have 368fc29ce1.
>
> **Repro.** `ruby -e 'require "rubygems/yaml_serializer"; p Gem::YAMLSerializer.load("---\n")'` prints `{}` on 4.0.7
> and `nil` on 4.1.0dev. The full repro is the four commands above.
>
> 368fc29ce1 cherry-picks cleanly onto `4.0`. Apps that lock an already-released 4.0.x would stay affected on Ruby 4.1.

### Draft: Redmine note "Pathname::SEPARATOR_PAT and locked Bundlers"

> Since 4e243c709e and a5996718f3, `Pathname::SEPARATOR_PAT` is gone (it was public through 4.0 because of the
> `private_constant` typo). Bundler 2.x and 4.0.0–4.0.11 use it in `Source::Path#generate_bin`. RubyGems runs the
> Bundler in `BUNDLED WITH`, so on 4.1 those apps cannot `bundle install` a path or git gem:
> `NameError: uninitialized constant Pathname::SEPARATOR_PAT`. Bundler fixed this in 4.0.12 (ruby/rubygems#9529), but
> 10 of 20 Rails apps we checked lock an older Bundler. Defining the constant again with `deprecate_constant` for
> 4.1 makes Bundler 2.6.9 work with a deprecation warning.

## F1 overlap

F1 (frontier census thread) owns the overlays, the per-app patches and the tracker checks for cbor (#42),
RubyGems (#9379), lago-expression, haml, tiktoken_ruby and tokenizers. This page reuses those results and does not
repeat them. It adds the latest-release builds, the whole-lockfile sweep, the 4.0.7 controls, both fix commits, the
SEPARATOR_PAT break, and the finding that Bundler writes the `---` file itself.
