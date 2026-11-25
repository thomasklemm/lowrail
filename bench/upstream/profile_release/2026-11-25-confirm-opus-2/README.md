# lowrail-profile 0.1.0.rc1: confirm of 1618fc38..60387485 (thermos-opus, 2026-11-25)

Receipts for the confirm section of
[docs/upstream/profile-release-review-2026-11-25.md](../../../../docs/upstream/profile-release-review-2026-11-25.md).

* Gems built from `gem/` with `gem build lowrail-profile.gemspec` (Ruby 4.0.7): 7a5ee0b6 sha256
  `6a8078585a291277a5d9a85baf1a71c2c06089ea19ff1b2e256140693be94470`, 60387485 sha256
  `c4a3a7c3d7a7806e5a310fc23e2c006975ed4f20160508ab43caeda1d729df68`, both as stated.
* Floor Blog: `LOWRAIL_CORPUS_RUBY=3.3.14 LOWRAIL_RAILS=7.2.4 script/corpus real-blog`, the three `params.expect`
  rewrites, the 7a5ee0b6 gem installed into a `Gemfile.lowrail` copy.
* [mutants.txt](mutants.txt): [scripts/mutants.rb](scripts/mutants.rb) applied to a copy of `gem/` at 7a5ee0b6
  (`MUTANT_SRC`), and at 60387485 for its two mutants, running only the tests named per mutant.
* [stream.txt](stream.txt): one kept floor-Blog capture reported by the 1618fc38, 5cdc5669 and 7a5ee0b6 `exe` (sha256
  of report.md and report.json, time and peak RSS), then a 471 MB set made from it with
  `2026-11-25-stream/scripts/gen.rb blog big 16 40`.
* `env-*.txt`: what [scripts/child.rb](scripts/child.rb) prints when the Blog's integration test starts it plainly,
  through `Bundler.with_original_env` and through `with_unbundled_env` (separated by `--`). `off`/`prof`:
  `bundle exec bin/rails test` against `bundle exec lowrail-profile -- bin/rails test`. `be-off`/`be-prof`:
  lowrail-profile outside the bundle, `-- bundle exec bin/rails test`. `mut`: the same, with the `BUNDLER_ORIG_`
  branch of `leave_env` removed.
* `build-env-*.txt`: what extconf.rb saw when the counter was built under `bundle exec` on the Blog
  ([scripts/probe.rb](scripts/probe.rb) through the caller's RUBYOPT, with `CC`, `CFLAGS` and `MY_FLAG` set).
