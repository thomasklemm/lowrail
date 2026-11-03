# ruby-bench setup for docs/upstream/index-with-capacity.md

Applied to `ruby/ruby-bench` at byroot's `heap-harness` branch (`bf1afb2`, from https://github.com/byroot/ruby-bench):

* `ruby-bench.patch`: points lobsters, railsbench and shipit at a local Rails checkout, adds `prism`, and the two
  config changes Rails 8.2 defaults need there (lobsters: `:header_or_legacy_token`, erubi; shipit: erubi). The lock
  files in it are the ones the measurements ran with. The Rails path in the Gemfiles is
  `/home/user/workspace/rails-wt/iw-bench` (canonical main `5810776eec`, with `enumerable.rb` swapped per variant).
* `shipit-engine-review_stack.patch`: shipit-engine 0.45.0 copied to `benchmarks/shipit/vendor/shipit-engine`
  (the Gemfile uses that path), with `ReviewStack.model_name` overridden on a dup, because Rails main freezes
  `ActiveModel::Name`.
* `harness-iw.rb`: goes to `harness-iw/harness.rb`. byroot's heap report plus a JSON summary of totals and every
  object allocated in `core_ext/enumerable.rb`. Run as `IW_OUT=out.json ruby -Iharness-iw benchmarks/APP/benchmark.rb`.
